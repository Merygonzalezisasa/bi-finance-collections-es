-- Consultas de ejemplo — responden las 6 preguntas de negocio de FICHA.md §4

-- ═══════════════════════════════════════════════════════════════════════
-- 1) ¿Qué clientes concentran el 80% de la facturación? (Pareto ABC)
-- ═══════════════════════════════════════════════════════════════════════
SELECT nombre, sector, segmento, importe_total, pct_acumulado, clase_abc
FROM finance.v_pareto_clientes
WHERE clase_abc = 'A'
ORDER BY ranking;

-- ═══════════════════════════════════════════════════════════════════════
-- 2) ¿Cómo se segmenta la cartera según compra y comportamiento de pago?
-- ═══════════════════════════════════════════════════════════════════════
SELECT nombre, segmento, r_score, f_score, m_score, segmento_pago, pct_facturas_impagas
FROM finance.v_rfm_pago
ORDER BY (r_score + f_score + m_score) DESC;

-- ═══════════════════════════════════════════════════════════════════════
-- 3) ¿Qué clientes dejaron de facturar, y hace cuánto? (proxy de cohortes/churn)
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    cliente, MAX(fecha_emision) AS ultima_factura,
    (SELECT MAX(fecha_emision) FROM finance.fact_facturas) - MAX(fecha_emision) AS dias_sin_facturar
FROM finance.v_facturas_enriquecida
GROUP BY cliente
HAVING (SELECT MAX(fecha_emision) FROM finance.fact_facturas) - MAX(fecha_emision) > 90
ORDER BY dias_sin_facturar DESC;

-- ═══════════════════════════════════════════════════════════════════════
-- 4a) DSO real (Days Sales Outstanding) por segmento, sobre facturas cobradas
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    c.segmento,
    ROUND(AVG(f.fecha_cobro - f.fecha_emision), 1) AS dso_dias,
    COUNT(*) AS facturas_cobradas
FROM finance.fact_facturas f
JOIN finance.dim_cliente c ON f.cliente_id = c.cliente_id
WHERE f.estado = 'cobrada'
GROUP BY c.segmento;

-- 4b) Caja esperada por mes de vencimiento (facturas aún pendientes de cobro)
SELECT
    date_trunc('month', fecha_vencimiento)::date AS mes_vencimiento,
    SUM(importe_total) AS importe_esperado,
    COUNT(*) AS n_facturas
FROM finance.fact_facturas
WHERE estado = 'pendiente'
GROUP BY 1
ORDER BY 1;

-- ═══════════════════════════════════════════════════════════════════════
-- 5) ¿La subida del Euríbor alarga los plazos de pago? (correlación con contexto)
-- Postgres trae corr() como función de agregación nativa (Pearson).
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    ROUND(corr(retraso_dias, euribor_12m)::NUMERIC, 3) AS corr_retraso_euribor,
    ROUND(corr(importe_total, ipc_var_anual)::NUMERIC, 3) AS corr_importe_ipc,
    COUNT(*) FILTER (WHERE retraso_dias IS NOT NULL) AS facturas_consideradas
FROM finance.v_facturas_enriquecida;

-- ═══════════════════════════════════════════════════════════════════════
-- 6) ¿Qué facturas tienen datos imposibles? (calidad y outliers)
-- ═══════════════════════════════════════════════════════════════════════
SELECT factura_id, importe_neto, importe_total, fecha_emision, fecha_vencimiento, fecha_cobro
FROM finance.fact_facturas
WHERE importe_neto <= 0
   OR importe_total < importe_neto
   OR fecha_vencimiento < fecha_emision
   OR fecha_cobro < fecha_emision;

-- ═══════════════════════════════════════════════════════════════════════
-- 7) Bonus — aging de deuda vencida (morosidad real) por bucket
-- ═══════════════════════════════════════════════════════════════════════
SELECT bucket_aging, COUNT(*) AS n_facturas, SUM(importe_total) AS importe
FROM finance.v_aging_dso
WHERE bucket_aging LIKE '%vencida%' AND bucket_aging != 'no vencida'
GROUP BY bucket_aging
ORDER BY bucket_aging;

-- ═══════════════════════════════════════════════════════════════════════
-- 8) Bonus — morosidad por sector (confirma la correlación #5 de FICHA.md)
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    sector,
    COUNT(*) AS total_facturas,
    ROUND(100.0 * COUNT(*) FILTER (WHERE estado = 'vencida') / COUNT(*), 1) AS pct_impago
FROM finance.v_facturas_enriquecida
GROUP BY sector
ORDER BY pct_impago DESC;
