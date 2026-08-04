"""
Verificación de carga — Finance Analytics España (Fase 1, Paso 4).

Chequea que lo cargado en PostgreSQL cuadre con el origen: conteos de filas,
nulos en las claves, FKs huérfanas y rangos imposibles (regla de calidad
transversal #4 de la plantilla). Es el último checkpoint de la Fase 1 — si
esto no queda en verde, no se avanza a la Fase 2.

Uso:  python 01_etl/verificar_carga.py
"""

import os
import sys
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

RAIZ = Path(__file__).resolve().parent.parent
DATOS = RAIZ / "data" / "raw"
ESQUEMA = "finance"

TABLAS_CSV = {
    "dim_tiempo": "dim_tiempo.csv",
    "dim_cliente": "dim_cliente.csv",
    "dim_servicio": "dim_servicio.csv",
    "dim_contexto_macro": "dim_contexto_macro.csv",
    "feriados": "feriados_es.csv",
    "fact_facturas": "fact_facturas.csv",
}

resultados = []


def chequeo(etiqueta):
    def envoltura(funcion):
        def ejecutar(*args, **kwargs):
            try:
                detalle = funcion(*args, **kwargs)
                resultados.append((True, etiqueta, detalle))
            except AssertionError as error:
                resultados.append((False, etiqueta, str(error)))
        return ejecutar
    return envoltura


def conectar():
    load_dotenv(RAIZ / ".env")
    url = (f"postgresql+psycopg2://{os.environ['DB_USER']}:{os.environ['DB_PASSWORD']}"
           f"@{os.environ['DB_HOST']}:{os.environ['DB_PORT']}/{os.environ['DB_NAME']}")
    return create_engine(url)


@chequeo("Conteos CSV vs tabla")
def check_conteos(engine):
    discrepancias = []
    for tabla, csv in TABLAS_CSV.items():
        origen = len(pd.read_csv(DATOS / csv))
        with engine.connect() as conn:
            destino = conn.execute(text(f"SELECT COUNT(*) FROM {ESQUEMA}.{tabla}")).scalar()
        if origen != destino:
            discrepancias.append(f"{tabla}: CSV={origen} tabla={destino}")
    assert not discrepancias, "; ".join(discrepancias)
    return f"{len(TABLAS_CSV)}/{len(TABLAS_CSV)} tablas cuadran"


@chequeo("Nulos en claves")
def check_nulos_claves(engine):
    consultas = {
        "dim_cliente.cliente_id": f"SELECT COUNT(*) FROM {ESQUEMA}.dim_cliente WHERE cliente_id IS NULL",
        "dim_servicio.servicio_id": f"SELECT COUNT(*) FROM {ESQUEMA}.dim_servicio WHERE servicio_id IS NULL",
        "dim_tiempo.fecha": f"SELECT COUNT(*) FROM {ESQUEMA}.dim_tiempo WHERE fecha IS NULL",
        "fact_facturas.cliente_id": f"SELECT COUNT(*) FROM {ESQUEMA}.fact_facturas WHERE cliente_id IS NULL",
        "fact_facturas.servicio_id": f"SELECT COUNT(*) FROM {ESQUEMA}.fact_facturas WHERE servicio_id IS NULL",
        "fact_facturas.fecha_emision": f"SELECT COUNT(*) FROM {ESQUEMA}.fact_facturas WHERE fecha_emision IS NULL",
    }
    con_nulos = []
    with engine.connect() as conn:
        for columna, sql in consultas.items():
            n = conn.execute(text(sql)).scalar()
            if n:
                con_nulos.append(f"{columna}: {n} nulos")
    assert not con_nulos, "; ".join(con_nulos)
    return f"{len(consultas)} claves revisadas, 0 nulos"


@chequeo("FKs huérfanas en fact_facturas")
def check_fks(engine):
    consultas = {
        "cliente_id": f"""SELECT COUNT(*) FROM {ESQUEMA}.fact_facturas f
                          LEFT JOIN {ESQUEMA}.dim_cliente d ON f.cliente_id = d.cliente_id
                          WHERE d.cliente_id IS NULL""",
        "servicio_id": f"""SELECT COUNT(*) FROM {ESQUEMA}.fact_facturas f
                           LEFT JOIN {ESQUEMA}.dim_servicio d ON f.servicio_id = d.servicio_id
                           WHERE d.servicio_id IS NULL""",
        "fecha_emision": f"""SELECT COUNT(*) FROM {ESQUEMA}.fact_facturas f
                             LEFT JOIN {ESQUEMA}.dim_tiempo d ON f.fecha_emision = d.fecha
                             WHERE d.fecha IS NULL""",
    }
    huerfanas = []
    with engine.connect() as conn:
        for fk, sql in consultas.items():
            n = conn.execute(text(sql)).scalar()
            if n:
                huerfanas.append(f"{fk}: {n} huérfanas")
    assert not huerfanas, "; ".join(huerfanas)
    return "0 FKs huérfanas (cliente_id, servicio_id, fecha_emision)"


@chequeo("Rangos imposibles")
def check_rangos(engine):
    consultas = {
        "importe_neto <= 0": f"SELECT COUNT(*) FROM {ESQUEMA}.fact_facturas WHERE importe_neto <= 0",
        "importe_total < importe_neto": f"SELECT COUNT(*) FROM {ESQUEMA}.fact_facturas WHERE importe_total < importe_neto",
        "fecha_vencimiento < fecha_emision": f"SELECT COUNT(*) FROM {ESQUEMA}.fact_facturas WHERE fecha_vencimiento < fecha_emision",
        "fecha_cobro < fecha_emision": f"SELECT COUNT(*) FROM {ESQUEMA}.fact_facturas WHERE fecha_cobro < fecha_emision",
        "dso_pactado fuera de {30,60,90}": f"SELECT COUNT(*) FROM {ESQUEMA}.dim_cliente WHERE dso_pactado NOT IN (30,60,90)",
    }
    imposibles = []
    with engine.connect() as conn:
        for descripcion, sql in consultas.items():
            n = conn.execute(text(sql)).scalar()
            if n:
                imposibles.append(f"{descripcion}: {n} filas")
    assert not imposibles, "; ".join(imposibles)
    return f"{len(consultas)} reglas revisadas, 0 valores imposibles"


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    print("Verificando la carga — Finance Analytics España\n")
    engine = conectar()

    for chequear in (check_conteos, check_nulos_claves, check_fks, check_rangos):
        chequear(engine)

    print()
    for ok, etiqueta, detalle in resultados:
        print(f"  {'✅' if ok else '❌'} {etiqueta:<30} {detalle}")
    print()

    if all(ok for ok, _, _ in resultados):
        print("→ CARGA VERIFICADA. Podés avanzar a la Fase 2.")
    else:
        print(f"→ {sum(1 for ok, _, _ in resultados if not ok)} chequeo(s) en rojo.")
        sys.exit(1)


if __name__ == "__main__":
    main()
