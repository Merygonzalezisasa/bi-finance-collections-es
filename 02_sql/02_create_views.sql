-- Vistas — Finance Analytics España (FICHA.md §6)
-- Consumidas por Power BI (Import, sobre las vistas, no las tablas crudas) y por el notebook.

-- ═══════════════════════════════════════════════════════════════════════
-- v_facturas_enriquecida: el hecho + todas las dimensiones + contexto macro
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW finance.v_facturas_enriquecida AS
SELECT
    f.factura_id,
    f.fecha_emision,
    f.fecha_vencimiento,
    f.fecha_cobro,
    f.importe_neto,
    f.iva,
    f.importe_total,
    f.estado,
    c.cliente_id,
    c.nombre AS cliente,
    c.sector,
    c.segmento,
    c.comunidad_autonoma,
    c.dso_pactado,
    c.sensibilidad_euribor,
    s.servicio_id,
    s.linea_servicio,
    s.servicio,
    s.tipo_facturacion,
    s.indexado_ipc,
    t.anio,
    t.trimestre,
    t.mes,
    t.dia_semana,
    t.es_feriado,
    t.es_cierre_trimestre,
    m.euribor_12m,
    m.ipc_var_anual,
    m.eur_usd,
    -- Retraso sobre lo PACTADO, no días crudos desde la emisión: comparar
    -- contra fecha_vencimiento evita que el propio dso_pactado (30 pyme vs
    -- 60-90 corporate) confunda la métrica (ver PROGRESO.md).
    CASE WHEN f.fecha_cobro IS NOT NULL
         THEN f.fecha_cobro - f.fecha_vencimiento END AS retraso_dias
FROM finance.fact_facturas f
JOIN finance.dim_cliente c             ON f.cliente_id = c.cliente_id
JOIN finance.dim_servicio s            ON f.servicio_id = s.servicio_id
JOIN finance.dim_tiempo t              ON f.fecha_emision = t.fecha
LEFT JOIN finance.dim_contexto_macro m ON f.fecha_emision = m.fecha;

-- ═══════════════════════════════════════════════════════════════════════
-- v_kpis_diarios: agregado por día, para el gráfico de evolución temporal
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW finance.v_kpis_diarios AS
SELECT
    f.fecha_emision AS fecha,
    COUNT(*) AS n_facturas,
    SUM(f.importe_total) AS importe_total,
    ROUND(AVG(f.importe_total), 2) AS ticket_promedio,
    COUNT(DISTINCT f.cliente_id) AS clientes_unicos,
    m.euribor_12m,
    m.ipc_var_anual,
    m.eur_usd
FROM finance.fact_facturas f
LEFT JOIN finance.dim_contexto_macro m ON f.fecha_emision = m.fecha
GROUP BY f.fecha_emision, m.euribor_12m, m.ipc_var_anual, m.eur_usd;

-- ═══════════════════════════════════════════════════════════════════════
-- v_rfm_pago: RFM clásico + comportamiento de pago (el giro propio del proyecto)
-- "hoy" = la última fecha de emisión del propio dataset, no CURRENT_DATE:
-- los datos son un snapshot fijo (2024-01 a 2026-06), no siguen corriendo.
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW finance.v_rfm_pago AS
WITH fecha_corte AS (
    SELECT MAX(fecha_emision) AS hoy FROM finance.fact_facturas
),
base AS (
    SELECT
        c.cliente_id,
        c.nombre,
        c.segmento,
        c.sector,
        fc.hoy - MAX(f.fecha_emision) AS recencia_dias,
        COUNT(*) AS frecuencia,
        SUM(f.importe_total) AS monetario,
        ROUND(AVG(f.fecha_cobro - f.fecha_vencimiento)
              FILTER (WHERE f.fecha_cobro IS NOT NULL), 1) AS retraso_medio_dias,
        ROUND(100.0 * COUNT(*) FILTER (WHERE f.estado = 'vencida') / COUNT(*), 1) AS pct_facturas_impagas
    FROM finance.fact_facturas f
    JOIN finance.dim_cliente c ON f.cliente_id = c.cliente_id
    CROSS JOIN fecha_corte fc
    GROUP BY c.cliente_id, c.nombre, c.segmento, c.sector, fc.hoy
)
SELECT
    *,
    NTILE(5) OVER (ORDER BY recencia_dias DESC) AS r_score,  -- 5 = compró/facturó más recientemente
    NTILE(5) OVER (ORDER BY frecuencia ASC)     AS f_score,  -- 5 = más facturas
    NTILE(5) OVER (ORDER BY monetario ASC)      AS m_score,  -- 5 = más importe
    CASE
        WHEN retraso_medio_dias IS NULL THEN 'sin cobros aún'
        WHEN retraso_medio_dias <= 0    THEN 'paga en plazo'
        WHEN retraso_medio_dias <= 15   THEN 'retraso leve'
        ELSE 'retraso alto'
    END AS segmento_pago
FROM base;

-- ═══════════════════════════════════════════════════════════════════════
-- v_pareto_clientes: ranking + % acumulado + clasificación ABC
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW finance.v_pareto_clientes AS
WITH totales AS (
    SELECT
        c.cliente_id, c.nombre, c.sector, c.segmento,
        SUM(f.importe_total) AS importe_total
    FROM finance.fact_facturas f
    JOIN finance.dim_cliente c ON f.cliente_id = c.cliente_id
    GROUP BY c.cliente_id, c.nombre, c.sector, c.segmento
),
acumulado AS (
    SELECT
        *,
        RANK() OVER (ORDER BY importe_total DESC) AS ranking,
        ROUND(100.0 * SUM(importe_total) OVER (ORDER BY importe_total DESC
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
              / SUM(importe_total) OVER (), 1) AS pct_acumulado
    FROM totales
)
SELECT
    *,
    CASE WHEN pct_acumulado <= 80 THEN 'A'
         WHEN pct_acumulado <= 95 THEN 'B'
         ELSE 'C' END AS clase_abc
FROM acumulado
ORDER BY ranking;

-- ═══════════════════════════════════════════════════════════════════════
-- v_aging_dso: bucket de morosidad por factura, base para calcular el DSO
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW finance.v_aging_dso AS
SELECT
    c.cliente_id,
    c.nombre,
    c.segmento,
    c.sector,
    c.dso_pactado,
    f.factura_id,
    f.importe_total,
    f.fecha_emision,
    f.fecha_vencimiento,
    f.fecha_cobro,
    f.estado,
    CASE
        WHEN f.estado = 'cobrada'                     THEN 'cobrada'
        WHEN f.estado = 'pendiente'                    THEN 'no vencida'
        WHEN fc.hoy - f.fecha_vencimiento <= 30        THEN '0-30 días vencida'
        WHEN fc.hoy - f.fecha_vencimiento <= 60        THEN '31-60 días vencida'
        WHEN fc.hoy - f.fecha_vencimiento <= 90        THEN '61-90 días vencida'
        ELSE '+90 días vencida'
    END AS bucket_aging
FROM finance.fact_facturas f
JOIN finance.dim_cliente c ON f.cliente_id = c.cliente_id
CROSS JOIN (SELECT MAX(fecha_emision) AS hoy FROM finance.fact_facturas) fc;
