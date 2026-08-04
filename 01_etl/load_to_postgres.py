"""
Carga a PostgreSQL — Finance Analytics España (Fase 1, Paso 3).

Aplica primero 02_sql/01_create_schema.sql (idempotente) y después hace
upsert de los 5 CSV de data/raw/ en orden: las dimensiones antes que el
hecho, porque fact_facturas tiene FKs hacia ellas.

Uso:
    python 01_etl/load_to_postgres.py                    # carga todo
    python 01_etl/load_to_postgres.py --tabla fact_facturas   # solo una
"""

import argparse
import datetime as dt
import os
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from dotenv import load_dotenv
from psycopg2.extras import execute_values
from sqlalchemy import create_engine, text

RAIZ = Path(__file__).resolve().parent.parent
DATOS = RAIZ / "data" / "raw"
LOGS = RAIZ / "logs"
ESQUEMA = "finance"

# Orden de carga: dimensiones antes que el hecho (respeta las FKs).
TABLAS = {
    "dim_tiempo": {"csv": "dim_tiempo.csv", "pk": "fecha", "fechas": ["fecha"]},
    "dim_cliente": {"csv": "dim_cliente.csv", "pk": "cliente_id", "fechas": ["fecha_alta"]},
    "dim_servicio": {"csv": "dim_servicio.csv", "pk": "servicio_id", "fechas": []},
    "dim_contexto_macro": {"csv": "dim_contexto_macro.csv", "pk": "fecha", "fechas": ["fecha"]},
    "feriados": {"csv": "feriados_es.csv", "pk": ["fecha", "nombre", "comunidades"], "fechas": ["fecha"]},
    "fact_facturas": {
        "csv": "fact_facturas.csv", "pk": "factura_id",
        "fechas": ["fecha_emision", "fecha_vencimiento", "fecha_cobro"],
        "validar_fks": True,
    },
}

incidencias = []


def _valor_sql(v):
    """Convierte tipos de pandas/numpy a tipos nativos que psycopg2 sabe adaptar."""
    if pd.isna(v):
        return None
    if isinstance(v, pd.Timestamp):
        return v.date()
    if isinstance(v, np.bool_):
        return bool(v)
    if isinstance(v, np.integer):
        return int(v)
    if isinstance(v, np.floating):
        return float(v)
    return v


def conectar():
    load_dotenv(RAIZ / ".env")
    url = (f"postgresql+psycopg2://{os.environ['DB_USER']}:{os.environ['DB_PASSWORD']}"
           f"@{os.environ['DB_HOST']}:{os.environ['DB_PORT']}/{os.environ['DB_NAME']}")
    return create_engine(url)


def crear_esquema(engine):
    sql_schema = (RAIZ / "02_sql" / "01_create_schema.sql").read_text(encoding="utf-8")
    raw = engine.raw_connection()
    try:
        with raw.cursor() as cur:
            cur.execute(sql_schema)
        raw.commit()
    finally:
        raw.close()


def filtrar_fks_validas(engine, df):
    """Descarta (y reporta) facturas cuya FK no existe en la dimensión ya cargada."""
    with engine.connect() as conn:
        clientes = {r[0] for r in conn.execute(text(f"SELECT cliente_id FROM {ESQUEMA}.dim_cliente"))}
        servicios = {r[0] for r in conn.execute(text(f"SELECT servicio_id FROM {ESQUEMA}.dim_servicio"))}
        fechas = {r[0] for r in conn.execute(text(f"SELECT fecha FROM {ESQUEMA}.dim_tiempo"))}

    validas = (
        df["cliente_id"].isin(clientes)
        & df["servicio_id"].isin(servicios)
        & df["fecha_emision"].dt.date.isin(fechas)
    )
    descartadas = int((~validas).sum())
    if descartadas:
        incidencias.append(f"fact_facturas: {descartadas} filas descartadas por FK huérfana")
        print(f"  ⚠ {descartadas} facturas descartadas por FK huérfana (ver log)")
    return df[validas]


def cargar_tabla(engine, nombre, config):
    ruta_csv = DATOS / config["csv"]
    if not ruta_csv.exists():
        raise FileNotFoundError(
            f"No existe {ruta_csv} — corré antes generate_facturas_data.py / extract_contexto_macro.py."
        )

    df = pd.read_csv(ruta_csv, parse_dates=config["fechas"])
    if config.get("validar_fks"):
        df = filtrar_fks_validas(engine, df)

    # La PK puede ser una sola columna ("cliente_id") o compuesta (feriados: una
    # fecha puede tener varias filas si coincide un feriado nacional y uno regional).
    pk_cols = config["pk"] if isinstance(config["pk"], list) else [config["pk"]]
    columnas = list(df.columns)
    actualizables = [c for c in columnas if c not in pk_cols]
    # Si la PK cubre todas las columnas (como en feriados) no queda nada que
    # actualizar: un "duplicado" es literalmente la misma fila, se ignora.
    accion_conflicto = (
        "DO NOTHING" if not actualizables
        else "DO UPDATE SET " + ", ".join(f"{c} = EXCLUDED.{c}" for c in actualizables)
    )
    sql = (
        f"INSERT INTO {ESQUEMA}.{nombre} ({', '.join(columnas)}) VALUES %s "
        f"ON CONFLICT ({', '.join(pk_cols)}) {accion_conflicto}"
    )
    filas = [tuple(_valor_sql(v) for v in fila) for fila in df.itertuples(index=False, name=None)]

    raw = engine.raw_connection()
    try:
        with raw.cursor() as cur:
            execute_values(cur, sql, filas, page_size=1000)
        raw.commit()
    finally:
        raw.close()

    with engine.connect() as conn:
        conteo_destino = conn.execute(text(f"SELECT COUNT(*) FROM {ESQUEMA}.{nombre}")).scalar()

    incidencias.append(f"{nombre}: {len(df)} filas en el CSV -> {conteo_destino} filas en la tabla")
    return len(df), conteo_destino


def escribir_log(resumen):
    LOGS.mkdir(exist_ok=True)
    marca = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    contenido = resumen + "\n\nDetalle:\n" + "\n".join(incidencias)
    (LOGS / f"load_to_postgres_{marca}.log").write_text(contenido, encoding="utf-8")


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    parser = argparse.ArgumentParser()
    parser.add_argument("--tabla", choices=list(TABLAS), help="cargar solo esta tabla")
    args = parser.parse_args()

    print("Cargando a PostgreSQL — Finance Analytics España\n")
    engine = conectar()

    print("· Aplicando 02_sql/01_create_schema.sql (idempotente)...")
    crear_esquema(engine)

    tablas_a_cargar = {args.tabla: TABLAS[args.tabla]} if args.tabla else TABLAS

    resultados = []
    for nombre, config in tablas_a_cargar.items():
        print(f"· Cargando {nombre}...")
        origen, destino = cargar_tabla(engine, nombre, config)
        resultados.append((nombre, origen, destino))

    print("\nConteos origen (CSV) vs destino (tabla):")
    lineas_resumen = []
    for nombre, origen, destino in resultados:
        estado = "✅" if destino == origen else "⚠️ revisar"
        linea = f"  {nombre:<20} CSV: {origen:>7,}   tabla: {destino:>7,}   {estado}"
        print(linea)
        lineas_resumen.append(linea)

    resumen = f"Carga: {dt.datetime.now().isoformat(timespec='seconds')}\n" + "\n".join(lineas_resumen)
    escribir_log(resumen)
    print("\n→ Corré este script una segunda vez: los conteos no deberían cambiar (upsert, no duplica).")


if __name__ == "__main__":
    main()
