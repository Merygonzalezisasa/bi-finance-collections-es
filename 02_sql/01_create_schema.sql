-- Esquema estrella — Finance Analytics España (FICHA.md §3)
-- Idempotente: se puede correr contra una base vacía o ya cargada sin romper nada.

CREATE SCHEMA IF NOT EXISTS finance;

CREATE TABLE IF NOT EXISTS finance.dim_tiempo (
    fecha                DATE PRIMARY KEY,
    anio                 SMALLINT NOT NULL,
    trimestre            SMALLINT NOT NULL,
    mes                  SMALLINT NOT NULL,
    dia_semana           TEXT NOT NULL,
    es_fin_de_semana     BOOLEAN NOT NULL,
    es_feriado           BOOLEAN NOT NULL,
    nombre_feriado       TEXT,
    es_cierre_trimestre  BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS finance.dim_cliente (
    cliente_id             INTEGER PRIMARY KEY,
    nombre                  TEXT NOT NULL,
    sector                  TEXT NOT NULL,
    segmento                TEXT NOT NULL,
    comunidad_autonoma      TEXT NOT NULL,
    fecha_alta              DATE NOT NULL,
    canal_captacion         TEXT NOT NULL,
    dso_pactado              SMALLINT NOT NULL,
    sensibilidad_euribor    NUMERIC(4, 2) NOT NULL
);

CREATE TABLE IF NOT EXISTS finance.dim_servicio (
    servicio_id       INTEGER PRIMARY KEY,
    linea_servicio    TEXT NOT NULL,
    servicio          TEXT NOT NULL,
    tarifa_base       NUMERIC(10, 2) NOT NULL,
    tipo_facturacion  TEXT NOT NULL,
    indexado_ipc      BOOLEAN NOT NULL
);

-- Serie de contexto independiente: cubre más rango (2023+) que dim_tiempo
-- (2024+), a propósito, para dar margen de "antes y después" en el análisis.
-- Por eso NO lleva FK hacia dim_tiempo.
CREATE TABLE IF NOT EXISTS finance.dim_contexto_macro (
    fecha           DATE PRIMARY KEY,
    euribor_12m     NUMERIC(5, 3) NOT NULL,
    ipc_var_anual   NUMERIC(5, 2) NOT NULL,
    eur_usd         NUMERIC(6, 4) NOT NULL
);

CREATE TABLE IF NOT EXISTS finance.fact_facturas (
    factura_id          INTEGER PRIMARY KEY,
    cliente_id          INTEGER NOT NULL REFERENCES finance.dim_cliente(cliente_id),
    servicio_id         INTEGER NOT NULL REFERENCES finance.dim_servicio(servicio_id),
    fecha_emision       DATE NOT NULL REFERENCES finance.dim_tiempo(fecha),
    -- fecha_vencimiento SIN FK: con plazos de hasta 90 días, el vencimiento de
    -- una factura emitida cerca del cierre del proyecto cae después del último
    -- día de dim_tiempo. Ponerle la FK rompería la carga en esos casos.
    fecha_vencimiento   DATE NOT NULL,
    fecha_cobro         DATE,
    importe_neto        NUMERIC(12, 2) NOT NULL,
    iva                 NUMERIC(12, 2) NOT NULL,
    importe_total       NUMERIC(12, 2) NOT NULL,
    estado              TEXT NOT NULL CHECK (estado IN ('cobrada', 'pendiente', 'vencida'))
);

CREATE INDEX IF NOT EXISTS idx_facturas_cliente        ON finance.fact_facturas(cliente_id);
CREATE INDEX IF NOT EXISTS idx_facturas_servicio       ON finance.fact_facturas(servicio_id);
CREATE INDEX IF NOT EXISTS idx_facturas_fecha_emision  ON finance.fact_facturas(fecha_emision);
CREATE INDEX IF NOT EXISTS idx_facturas_estado         ON finance.fact_facturas(estado);

COMMENT ON TABLE  finance.fact_facturas IS
    'Hecho: una fila por factura emitida a un cliente por un servicio.';
COMMENT ON COLUMN finance.fact_facturas.estado IS
    'cobrada = tiene fecha_cobro; pendiente = aún no vence; vencida = venció sin cobrarse (impago real).';
COMMENT ON TABLE  finance.dim_cliente IS
    'Quién: cartera de clientes B2B de Tamarindo Servicios Empresariales.';
COMMENT ON COLUMN finance.dim_cliente.dso_pactado IS
    'Plazo de pago pactado en el contrato (días). Para medir retraso real, comparar '
    'fecha_cobro - fecha_vencimiento, nunca fecha_cobro - fecha_emision en bruto '
    '(ver PROGRESO.md: el dso_pactado distinto por cliente confunde esa métrica).';
COMMENT ON TABLE  finance.dim_contexto_macro IS
    'Contexto externo real: Euríbor 12M (BCE), IPC (INE), EUR/USD (Frankfurter), a diario.';

-- Detalle de feriados (Nager.Date). dim_tiempo.es_feriado/nombre_feriado ya trae un
-- resumen (1 nombre por día); esta tabla trae el detalle completo, con varias filas
-- por fecha cuando coinciden un feriado nacional y uno regional el mismo día. Sin PK
-- de una sola columna porque justamente eso puede repetirse por fecha.
CREATE TABLE IF NOT EXISTS finance.feriados (
    fecha        DATE NOT NULL,
    nombre       TEXT NOT NULL,
    comunidades  TEXT NOT NULL,
    PRIMARY KEY (fecha, nombre, comunidades)
);

COMMENT ON TABLE finance.feriados IS
    'Feriados de España (Nager.Date) con detalle de alcance nacional/autonómico.';
