-- Stored procedures — Finance Analytics España (FICHA.md §6)

-- ═══════════════════════════════════════════════════════════════════════
-- Tabla donde sp_calcular_segmentacion PERSISTE su resultado (a diferencia
-- de v_rfm_pago, que es un cálculo al vuelo con "hoy" fijo en el máximo del
-- dataset). Esta tabla, en cambio, guarda una foto a la fecha de corte que
-- se le pida, para poder comparar cómo cambió la segmentación en el tiempo.
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS finance.cliente_segmentacion (
    cliente_id      INTEGER PRIMARY KEY REFERENCES finance.dim_cliente(cliente_id),
    fecha_corte     DATE NOT NULL,
    recencia_dias   INTEGER,
    frecuencia      INTEGER,
    monetario       NUMERIC(14, 2),
    r_score         INTEGER,
    f_score         INTEGER,
    m_score         INTEGER,
    segmento_pago   TEXT,
    calculado_en    TIMESTAMP NOT NULL DEFAULT now()
);

-- ═══════════════════════════════════════════════════════════════════════
-- sp_calcular_segmentacion(fecha_corte): recalcula la segmentación RFM+pago
-- usando SOLO facturas emitidas hasta esa fecha (no todo el histórico) —
-- así se puede preguntar "¿cómo estaba segmentada la cartera en marzo?".
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE PROCEDURE finance.sp_calcular_segmentacion(p_fecha_corte DATE)
LANGUAGE plpgsql AS $$
DECLARE
    v_clientes INTEGER;
BEGIN
    DELETE FROM finance.cliente_segmentacion;

    INSERT INTO finance.cliente_segmentacion
        (cliente_id, fecha_corte, recencia_dias, frecuencia, monetario,
         r_score, f_score, m_score, segmento_pago)
    WITH base AS (
        SELECT
            c.cliente_id,
            p_fecha_corte - MAX(f.fecha_emision) AS recencia_dias,
            COUNT(*) AS frecuencia,
            SUM(f.importe_total) AS monetario,
            ROUND(AVG(f.fecha_cobro - f.fecha_vencimiento)
                  FILTER (WHERE f.fecha_cobro IS NOT NULL), 1) AS retraso_medio_dias
        FROM finance.fact_facturas f
        JOIN finance.dim_cliente c ON f.cliente_id = c.cliente_id
        WHERE f.fecha_emision <= p_fecha_corte
        GROUP BY c.cliente_id
    )
    SELECT
        cliente_id, p_fecha_corte, recencia_dias, frecuencia, monetario,
        NTILE(5) OVER (ORDER BY recencia_dias DESC),
        NTILE(5) OVER (ORDER BY frecuencia ASC),
        NTILE(5) OVER (ORDER BY monetario ASC),
        CASE
            WHEN retraso_medio_dias IS NULL THEN 'sin cobros aún'
            WHEN retraso_medio_dias <= 0    THEN 'paga en plazo'
            WHEN retraso_medio_dias <= 15   THEN 'retraso leve'
            ELSE 'retraso alto'
        END
    FROM base;

    GET DIAGNOSTICS v_clientes = ROW_COUNT;
    RAISE NOTICE 'Segmentación recalculada a fecha %: % clientes', p_fecha_corte, v_clientes;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════
-- sp_reporte_mensual(año, mes): el reporte ejecutivo de un período — cinco
-- métricas clave en una sola llamada. FUNCTION (no PROCEDURE) porque en
-- Postgres solo las funciones pueden devolver un conjunto de filas.
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION finance.sp_reporte_mensual(p_anio INT, p_mes INT)
RETURNS TABLE (metrica TEXT, valor NUMERIC)
LANGUAGE sql AS $$
    SELECT 'facturas_emitidas', COUNT(*)::NUMERIC
    FROM finance.fact_facturas
    WHERE EXTRACT(YEAR FROM fecha_emision) = p_anio
      AND EXTRACT(MONTH FROM fecha_emision) = p_mes

    UNION ALL
    SELECT 'importe_facturado', COALESCE(SUM(importe_total), 0)
    FROM finance.fact_facturas
    WHERE EXTRACT(YEAR FROM fecha_emision) = p_anio
      AND EXTRACT(MONTH FROM fecha_emision) = p_mes

    UNION ALL
    SELECT 'importe_cobrado', COALESCE(SUM(importe_total), 0)
    FROM finance.fact_facturas
    WHERE estado = 'cobrada'
      AND EXTRACT(YEAR FROM fecha_cobro) = p_anio
      AND EXTRACT(MONTH FROM fecha_cobro) = p_mes

    UNION ALL
    SELECT 'clientes_activos', COUNT(DISTINCT cliente_id)::NUMERIC
    FROM finance.fact_facturas
    WHERE EXTRACT(YEAR FROM fecha_emision) = p_anio
      AND EXTRACT(MONTH FROM fecha_emision) = p_mes

    UNION ALL
    SELECT 'facturas_vencidas_sin_cobrar', COUNT(*)::NUMERIC
    FROM finance.fact_facturas
    WHERE estado = 'vencida'
      AND EXTRACT(YEAR FROM fecha_vencimiento) = p_anio
      AND EXTRACT(MONTH FROM fecha_vencimiento) = p_mes;
$$;

-- ═══════════════════════════════════════════════════════════════════════
-- sp_refrescar_contexto(): se llama después de recargar dim_contexto_macro
-- (extract_contexto_macro.py + load --tabla dim_contexto_macro). No hace
-- falta refrescar las vistas (se recalculan solas en cada consulta), pero
-- sí conviene refrescar las estadísticas del planificador de consultas.
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE PROCEDURE finance.sp_refrescar_contexto()
LANGUAGE plpgsql AS $$
BEGIN
    ANALYZE finance.dim_contexto_macro;
    RAISE NOTICE 'Estadísticas de dim_contexto_macro actualizadas';
END;
$$;
