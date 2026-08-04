# Progreso — Finance Analytics España

## Estado actual
**Fase:** 2 (SQL: vistas + stored procedures — el esquema ya se creó en la Fase 1) ·
**Última sesión:** 2026-07-20
**Repo:** https://github.com/Merygonzalezisasa/Portfolio

## Bitácora

### Fase 0 — Decidir ✅ (2026-07-17)
- País: España · Moneda: EUR · Mercado: ofertas locales ES.
- Rubro: servicios B2B multi-cliente, finanzas operativas (facturación, cobros, morosidad).
  Organización ficticia: **Tamarindo Servicios Empresariales, S.L.**
- Fuentes externas aprobadas con los 4 chequeos (respuestas crudas en FICHA.md):
  - BCE — Euríbor 12M mensual (`FM.M.U2.EUR.RT.MM.EURIBOR1YD_.HSTA`) ✓
  - INE — IPC variación anual (`IPC251856`), mensual, fechas en epoch ms ✓
  - Frankfurter — EUR/USD diario (omite findes → forward fill nuestro) ✓
  - Nager.Date — feriados ES (32 en 2026, incluye autonómicos) ✓
- 5 correlaciones intencionales definidas, 6 preguntas de negocio, 6 módulos de análisis elegidos.
- **FICHA.md aprobada por Rosmary el 2026-07-17.**

### Fase 0.5 — Entorno 🚧
- [x] Paso 1a — Inventario de la máquina (2026-07-17):
  - ✅ Power BI Desktop v2.155 (Microsoft Store) · ✅ VS Code
  - ❌ Python (solo el alias falso de la Store) · ❌ Git · ❌ Docker/PostgreSQL · ❌ Quarto (opcional, Fase 6)
- [x] Paso 1b — Python 3.12.10 ✓ (instalador directo; winget se colgaba, ver SETUP.md) ·
  Git 2.55 ✓ (identidad configurada) · PostgreSQL 16.12 descargando (347 MB)  ← ACÁ VAMOS
- [x] Paso 2 — Estructura bootstrap creada (Anexo B) · `.venv` creado ·
  `pip install -r requirements.txt` en curso · repo Git iniciado, primer commit `8f55188`
- [x] Paso 3 — PostgreSQL 16.12 instalado (servicio `postgresql-x64-16` corriendo), base
  `finance_analytics` creada (UTF8, locale español), `.env` generado con contraseña aleatoria
- [x] Paso 4 — **`verificar_entorno.py` → 8/8 EN VERDE** (2026-07-17). Trampas resueltas y
  documentadas en SETUP.md: inspección TLS (→ truststore), winget colgado (→ instalador directo)
- [x] Power BI Desktop abre correctamente (confirmado por Rosmary, 2026-07-17)
- [x] Repo publicado: **github.com/Merygonzalezisasa/Portfolio** (rama `main`, 2 commits)

## Fase 0.5 — CERRADA ✅ (2026-07-17)

## Decisiones técnicas anotadas
- En Windows PowerShell 5.1, las APIs HTTPS exigen forzar TLS 1.2
  (`[Net.ServicePointManager]::SecurityProtocol = Tls12`). En Python con `requests` no aplica.
- El "python OK" de la terminal era el alias stub de Microsoft Store, no un Python real.

### Fase 1 — ETL 🚧
- [x] Paso 1 — Generador sintético (`generate_facturas_data.py`). Verificado dos veces
  (por mí y por Rosmary en su máquina, mismo resultado gracias a SEED=42): dim_tiempo 912,
  dim_cliente 120, dim_servicio 25, fact_facturas 15.000 (13.444 cobradas, 989 pendientes,
  567 vencidas). Las 5 correlaciones de FICHA.md §2.3 confirmadas por separado (ver nota abajo).
- [x] Paso 2 — Extractor oficial (`extract_contexto_macro.py`), con reintentos, log y
  validación de rangos. Verificado por mí y por Rosmary (mismo resultado): dim_contexto_macro
  1.277 filas (2023-01 a 2026-06), feriados_es 130 filas, validación OK sin errores.
  Valores plausibles: Euríbor 2,08-4,16%, IPC 1,5-6%, EUR/USD 1,02-1,20.
  `01_etl/documentacion_api.txt` completado con las 4 APIs.
- [x] Paso 3 — Carga a Postgres (`load_to_postgres.py`), con upsert real
  (`INSERT ... ON CONFLICT DO UPDATE`, no `INSERT` ciego). Adelantamos
  `02_sql/01_create_schema.sql` (esquema estrella con PKs/FKs/índices/comentarios) porque
  la carga lo necesita como prerrequisito técnico. Verificado por mí y por Rosmary (mismo
  resultado, dos corridas): carga completa 912/120/25/1.277/15.000 filas (CSV = tabla en
  las 5); segunda corrida da los mismos conteos (idempotente); `--tabla dim_contexto_macro`
  recarga solo esa tabla. 0 FKs huérfanas.
- [x] Paso 4 — Verificación de carga (`verificar_carga.py`), 4 chequeos: conteos CSV vs
  tabla, nulos en claves, FKs huérfanas, rangos imposibles (importes, fechas, dso_pactado).
  Verificado: 4/4 en verde → "CARGA VERIFICADA. Podés avanzar a la Fase 2."

## Fase 1 — CERRADA ✅ (2026-07-20)

### Fase 2 — SQL 🚧
- El esquema (`01_create_schema.sql`) ya se había creado en la Fase 1 (era prerrequisito
  técnico de la carga). Hoy se completó el resto de la carpeta `02_sql/`:
- [x] `02_create_views.sql` — 5 vistas: v_facturas_enriquecida, v_kpis_diarios, v_rfm_pago
  (RFM + comportamiento de pago), v_pareto_clientes (ABC), v_aging_dso (buckets de mora).
  "Hoy" se calcula como MAX(fecha_emision) del propio dataset, no CURRENT_DATE (los datos
  son un snapshot fijo 2024-2026, no siguen corriendo).
- [x] `03_stored_procedures.sql` — sp_calcular_segmentacion(fecha_corte) [PROCEDURE, persiste
  en tabla cliente_segmentacion], sp_reporte_mensual(año,mes) [FUNCTION, devuelve filas],
  sp_refrescar_contexto() [ANALYZE tras recargar contexto macro]. Los 3 ejecutados y
  probados con datos reales (segmentación a 2026-03-31: 120 clientes; reporte marzo 2026:
  640 facturas, 5,73M€ facturados, 4,90M€ cobrados).
- [x] `04_sample_queries.sql` — 8 consultas (las 6 preguntas de FICHA.md §4 + 2 bonus), todas
  corridas con resultados reales: DSO corporate 76,1d vs pyme 45,6d; correlación
  retraso-Euríbor 0,572 (medida sobre las 13.444 facturas cobradas, más fuerte que el 0,316
  visto en Python porque cruza el Euríbor exacto del mes de cada vencimiento); correlación
  IPC-importe 0,013 (débil al medir sobre importe_total mezclado — hay que aislar solo
  servicios indexados/recurrentes para ver el efecto real, tarea de la Fase 4); calidad:
  0 facturas con datos imposibles (consistente con verificar_carga.py).

## Notas técnicas importantes
- **Al medir el retraso de pago, usar siempre `fecha_cobro − fecha_vencimiento` (retraso sobre
  lo PACTADO), nunca `fecha_cobro − fecha_emision` en bruto.** El `dso_pactado` (30 pyme vs
  60-90 corporate) es un factor de confusión que invierte el signo de la correlación con el
  Euríbor si se mide mal. Aplica igual en la Fase 2 (vistas SQL de aging/DSO) y la Fase 4.

## Corrección post-Fase 2: faltaba cargar feriados_es
Rosmary detectó (2026-08-03) que `finance.feriados` no existía en Postgres — error mío: en la
Fase 1 el extractor generó `data/raw/feriados_es.csv` (130 filas), pero nunca lo agregué al
diccionario `TABLAS` de `load_to_postgres.py`, así que se quedó solo en el CSV. Corregido:
- `02_sql/01_create_schema.sql`: tabla `finance.feriados` (fecha, nombre, comunidades),
  **PK compuesta** (no hay columna única: un mismo día puede tener un feriado nacional y uno
  regional, ej. "Año Nuevo" aparece 2 veces el 2023-01-01 con distinto alcance).
- `01_etl/load_to_postgres.py`: `cargar_tabla()` ahora soporta PK compuesta (lista de
  columnas) y usa `DO NOTHING` en vez de `DO UPDATE SET` cuando la PK cubre todas las
  columnas (si no, el SQL queda con un `SET` vacío e inválido).
- `01_etl/verificar_carga.py`: agregada a los conteos.
Verificado: carga 130/130, idempotente (2 corridas, mismos conteos), verificar_carga 4/4 OK.

## Incidente — Fase 3 (2026-08-04): se perdió el modelo de Power BI conectado
Rosmary había conectado a mano, en Power BI Desktop, las tablas `fact_facturas`, `dim_cliente`,
`dim_servicio`, `dim_contexto_macro` + un "Calendario" en DAX, con relaciones ya armadas
(fechas de rol correctamente resueltas: solo fecha_emision activa). **Ese trabajo nunca se
commiteó a git** — existía solo en el disco. La IA, sin pedir confirmación, reescribió el
modelo semántico a mano (borrando esas tablas y creando otras 4 sobre las vistas de la
Fase 2), lo cual no era lo que se le pidió. Al intentar revertir, Power BI Desktop (que se
reabrió durante el proceso) volvió a guardar por encima y el modelo terminó vacío — el
trabajo original de conexión de Rosmary **se perdió**, sin backup recuperable.
**Estado actual:** el `.pbip` volvió a su estado del primer commit (`ae9e62e`): vacío, sin
tablas conectadas. Nada de Postgres/SQL/Python se vio afectado.
**Lección para la próxima sesión:** cualquier trabajo hecho a mano en Power BI Desktop se
commitea a git ANTES de que la IA toque los archivos del modelo, sin excepción. Y la IA no
reestructura el modelo semántico sin pedir permiso explícito primero — alcanza con que las
tablas/vistas existan en Postgres; conectarlas en Power BI es tarea de Rosmary.
**Pendiente:** Rosmary reconecta a mano fact_facturas, dim_cliente, dim_servicio,
dim_contexto_macro (o las vistas de la Fase 2, a su criterio) + Calendario, y commitea antes
de seguir.

## Nota sobre Skills for Fabric (Microsoft, microsoft/skills-for-fabric)
Rosmary pidió instalar la skill oficial de Microsoft para autoría de Power BI (Design +
Authoring + Management) vía `/plugin marketplace add microsoft/skills-for-fabric`. **No es
posible en este entorno**: la extensión de Claude Code para VS Code no soporta el sistema de
marketplace de plugins (`/plugin` no existe acá) ni descubre skills locales por convención de
archivos (`~/.claude/skills/` no existe, no hay `.claude/skills/` de proyecto). La lista de
skills disponibles la fija la plataforma, no es extensible por el usuario en este setup.
**Decisión:** en vez de la skill formal, cuando lleguemos a la Fase 3 (Power BI) se aplica el
mismo conocimiento leyendo directamente la guía oficial de Microsoft Learn (Design/Authoring/
Management skill overviews) — mismo resultado práctico, sin la infraestructura del plugin.
Si en el futuro se quiere probar el Claude Code CLI real (terminal, fuera de VS Code), ahí sí
podría soportar `/plugin`.

## Dudas abiertas
- ¿El forward fill del fin de semana (EUR/USD) puede sesgar la correlación? → revisar en la Fase 4
  y declararlo en el notebook.
