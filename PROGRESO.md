# Progreso — Finance Analytics España

## Estado actual
**Fase:** 3 (Power BI) — **CERRADA ✅** · Siguiente: Fase 4 (análisis Python) ·
**Última sesión:** 2026-08-07
**Repo:** https://github.com/Merygonzalezisasa/finance-analytics-es

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
  — renombrado a **`finance-analytics-es`** el 2026-08-09 al adoptar convención de nombres

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
Authoring + Management) vía `/plugin marketplace add microsoft/skills-for-fabric`.

**Intento 1 (2026-08-04):** no es posible desde la extensión de Claude Code para VS Code —
`/plugin` no existe en ese entorno, ni hay `~/.claude/skills/` local para poblar a mano.

**Intento 2 (2026-08-05):** Rosmary instaló el Claude Code CLI real en una terminal aparte
(`irm https://claude.ai/install.ps1 | iex`), lo actualizó a la última versión (2.1.222), y
SÍ pudo agregar el marketplace (`/plugin marketplace add microsoft/skills-for-fabric` → OK).
Pero `/plugin install fabric-skills@fabric-collection` falla con:
`"Failed to install: This plugin uses a source type your Claude Code version does not support."`
Es un **bug conocido de Claude Code** (no de Microsoft ni nuestro): varios issues abiertos en
github.com/anthropics/claude-code describen el mismo mensaje —engañoso, no existe versión que
lo arregle— para marketplaces cuyo manifiesto declara la fuente de cierta forma (ej. `"source":
"."`) que el validador de plugins todavía no reconoce, incluso en la última versión.

**Intento 3 (2026-08-05, más tarde): ÉXITO.** `powerbi-authoring@fabric-collection` quedó
instalado (v0.3.10, 16:15 UTC). Verificado en sesión posterior:
- `~/.claude/plugins/installed_plugins.json` lista `powerbi-authoring@fabric-collection` v0.3.10.
- `~/.claude/plugins/known_marketplaces.json` tiene `fabric-collection` apuntando a
  `github.com/microsoft/skills-for-fabric.git`.
- Las 6 skills están en disco (`.../powerbi-authoring/0.3.10/skills/`) y disponibles para
  invocar en el chat: `check-updates`, `semantic-model-authoring`, `powerbi-report-planning`,
  `powerbi-report-design`, `powerbi-report-authoring`, `powerbi-report-management`.
- El MCP server asociado (`powerbi-modeling-mcp`) también carga correctamente.

**CAUSA RAÍZ del bug (encontrada el 2026-08-05, al instalar los 4 plugins restantes).** El
mensaje *"source type your Claude Code version does not support"* es **engañoso**: no tiene
nada que ver con el `source`. `claude plugin validate` da la pista real: `mcpServers: Invalid
input`. Claude Code 2.1.222 **no acepta servidores MCP de tipo `http` incrustados** en el
manifiesto del plugin. Por eso `powerbi-authoring` (MCP `stdio` vía npx) instalaba bien y los
otros cuatro (MCP `http` hacia api.fabric.microsoft.com) fallaban. **Solución:** cambiar
`mcpServers` de objeto inline a la ruta `"./.mcp.json"`, archivo que cada plugin ya traía.

**Estado de los plugins:** los 5 instalados. Activos `powerbi-authoring` y `fabric-skills`
(bundle de 33). Desactivados a propósito `fabric-authoring`, `fabric-consumption` y
`fabric-operations`: sus skills son 100 % subconjunto de `fabric-skills` y duplicaban contexto
(69 skills cargadas → 37 únicas). El arreglo del `mcpServers` es **local** sobre el clon en
`~/.claude/plugins/marketplaces/fabric-collection/`; si se actualiza el marketplace se pierde
y hay que rehacerlo (backup en `marketplace.json.bak`). Las copias sueltas de
`~/.claude/skills/` se movieron a `~/.claude/skills-backup-20260805/` porque duplicaban lo que
ya entregan los plugins; esa carpeta queda vacía a propósito.

**Decisión final:** se usa la skill formal de Microsoft de acá en adelante para Power BI
(reemplaza el enfoque manual de leer Microsoft Learn a mano).

### Fase 3 — Power BI ✅ (2026-08-05 / 2026-08-07)

**Reinicio del reporte.** Rosmary borró a propósito las 2 páginas anteriores (20 visuales) para
empezar de cero. Siguen recuperables desde `60457ff`.

**Herramientas incorporadas:** Node.js 24.19.0 + las CLIs oficiales
`@microsoft/powerbi-report-authoring-cli` y `@microsoft/powerbi-desktop-bridge-cli`. Flujo de
trabajo: generar el PBIR con scripts Node deterministas → `powerbi-report-author validate` →
`powerbi-desktop reload` → captura → revisar la captura y corregir. **Varios defectos solo
aparecieron en la captura, nunca en la validación.**

**6 páginas** (`pageOrder`: portada, 1, 2, 3, 4, 5), más una barra de navegación de 6 botones
en las 5 páginas de contenido con la página actual resaltada:

| # | Página | Arquetipo | Pregunta de FICHA §4 |
|---|---|---|---|
| 0 | Portada navegable | — | 3 KPIs + 5 botones |
| 1 | Impacto financiero | Executive · KPI-Strip | #5 (Euríbor) |
| 2 | Riesgo de cobro | Analytical · Inline-Slicers | #4 (aging/DSO) |
| 3 | Precio y margen | Narrative · 7/5 Split | #5 (IPC) |
| 4 | Concentración Pareto/ABC | Analytical | **#1** |
| 5 | Inteligencia de tiempo | Analytical | YoY, YTD, media móvil |

**Diseño:** tema propio navy/durazno/coral. Firma visual = *"la brecha"*: cada página mide una
distancia entre dos series y la nombra. Contrato de color constante en todas: pyme coral,
corporate azul, vencido rojo, Euríbor ámbar.

**3 medidas nuevas** (aditivas, carpeta 03 Plazos): `Retraso pyme`, `Retraso corporate`,
`Brecha pyme-corporate`.

## Hallazgos de la Fase 3 (verificados con DAX sobre el modelo vivo)

**1. La correlación Euríbor↔retraso se invierte — el agregado es espurio.**

| Periodo | r |
|---|---|
| 2024 (Euríbor baja 3,7 → 2,4) | **+0,91** |
| 2025-26 (Euríbor sube 2,1 → 2,8) | **−0,53** |
| 29 meses completos | +0,88 ← **engañoso** |

El +0,88 global lo produce enteramente el desplome de 2024; cuando el Euríbor volvió a subir el
retraso no reaccionó. La correlación #1 de FICHA.md **solo se sostiene en un tramo**. El título
de la página lo declara con los tres coeficientes a la vista.

**2. Dos riesgos distintos que un indicador único de morosidad confundiría.** Construcción:
11,8 % de su facturación vencida (4,3× la media), concentra el 44 % de la deuda vencida con el
15 % de la facturación → **riesgo de crédito**. Sector público: el 100 % de sus facturas se
pagan tarde (+25,3 días) pero solo 0,94 % vencido, el más bajo de los 8 sectores → **riesgo de
liquidez**. Piden acciones opuestas de Finanzas.

**3. El aging tiene forma de barra, no de rampa.** De 5,47 M€ vencidos, 4,71 M€ (86 %) superan
los 90 días; los tramos 1-30, 31-60 y 61-90 suman 0,76 M€. La deuda no se desliza: o está al
día o está muy vencida.

**4. 🔴 La cláusula de revisión por IPC no llega al precio.** Los servicios indexados son todos
recurrentes (sin contaminación de mix): ticket 5.068 € (2024) → 5.104 € (2026), +0,7 % con IPC
acumulado +5,6 %. Debería estar en 5.348 €. Son −244 € por factura (−4,6 %) y **~0,95 M€ no
facturados** (478 K€ en 2025 + 476 K€ en el S1 2026). **La correlación #3 de FICHA.md no se
sostiene** — hallazgo negativo, más valioso que forzar el gráfico.

**5. No se cumple el 80/20.** Hacen falta **58 de 120 clientes (48 % de la cartera)** para
llegar al 80 % de la facturación; el mayor pesa solo 4,1 %. Cartera atomizada: poco riesgo de
dependencia, más coste de gestión de cobro.

**6. El vencido es proporcional a la facturación en las 5 líneas de servicio** (3,2 %–4,4 %,
media 3,96 %): el riesgo está en el cliente, no en el producto.

**7. Estacionalidad confirmada:** agosto factura un 86 % menos que un mes normal.

## Notas técnicas de la Fase 3
- **Power BI Desktop NO serializa al TMDL las medidas creadas vía TOM externo (MCP).** Ctrl+S
  reescribe `_Medidas.tmdl` con su propia vista y git lo ve idéntico. Hay que exportar el TMDL
  de cada medida (`measure_operations` → `ExportTMDL`, **una llamada por medida**) y pegarlo a
  mano conservando el `lineageTag`. Si no, se commitea un modelo roto y el fallo es silencioso.
- **`ComparisonKind`**: `0`=Equal, `1`=GreaterThan, **`2`=GreaterThanOrEqual**, `3`=LessThan,
  `4`=LessThanOrEqual. Usar el 3 para "mayor o igual" invierte el filtro y vacía la página.
- **Objetos con `_selectorHint`** (fill/outline/text del `actionButton`) exigen el **patrón de
  doble entrada**: entrada estática sin selector + las de selector. Sin la estática el texto del
  botón no renderiza (y valida igual).
- **`referenceLine.value`** necesita sufijo de tipo: `5348D`, no `5348`.
- En un combo, el color de las **columnas** va por `dataPoint.defaultColor`; el selector
  `metadata` solo alcanza a la línea del eje secundario (Y2).
- **`stylePreset`** de `tableEx` va en `visualContainerObjects`, no en `objects`.
- **Censura por la derecha:** los datos cortan el 30/06/2026. Sin filtrar, jul-dic 2026 muestra
  `Var % AA` = −100 % (hay año anterior pero no facturación).
- **Medidas que solo significan algo en contexto mensual:** `DSO` da 152 días a nivel total
  (divide por los días de todo el periodo) y `Var % AA` da +69,6 % (compara periodos de distinta
  longitud). Se quitó esa tarjeta; la comparación honesta es YTD vs YTD AA = **+8,4 %**.

## Pendientes de la Fase 3
- Deltas YoY en las tarjetas de la página 1 (FICHA §6 pedía "KPIs, YoY"): `Var % AA` como
  reference label.
- Los 2 gráficos de línea de la página 5 conservan scrollbar horizontal (30 meses en 608 px).
  Fallaron `zoom.show=false` y `preferredCategoryWidth`. Se arregla ensanchando (uno por fila) o
  agrupando por trimestre.
- `definition.pbir` sin `$schema`: el validador lo marca error y **Fabric rechaza** PBIR sin él.
  No afecta a Desktop. El URL correcto no está en las referencias de la skill; un intento de
  adivinarlo lo empeoró y se revirtió.
- Las tarjetas de días (`Retraso medio`, `Brecha pyme-corporate`) no muestran unidad. Requiere
  tocar el `formatString` de una medida preexistente.
- No se verificó por clic que los botones de navegación salten (los `visualLink` validan).

## Convención de nombres para los repos del portfolio (2026-08-09)

Regla adoptada para **todos** los proyectos que se publiquen en GitHub:

> **`<dominio>-<entregable>-<mercado>`** · minúsculas, guiones, en inglés, sin números ni
> abreviaturas crípticas. El sufijo de mercado (`-es`) solo cuando el análisis dependa del país.

| Proyecto | Repo |
|---|---|
| Este (facturación y cobros B2B en España) | `finance-analytics-es` |
| *(ejemplos de cómo escala)* | `retail-demand-forecast-es` |
| | `hr-attrition-analysis-es` |

**Por qué esta y no otras.** Se descartó el prefijo agrupador (`analytics-…`) porque repite
espacio útil en cada nombre, y el esquema numerado (`portfolio-01-…`) porque los números se leen
como ejercicios de bootcamp y obligan a renombrar todo si cambia el orden.

**El orden en GitHub no lo da el nombre.** Lo dan los **repos fijados** (hasta 6), los **topics** y
el **README de perfil** (repo `Merygonzalezisasa/Merygonzalezisasa`). El nombre solo hace que la
serie se lea como deliberada.

**Un repo por proyecto, no un monorepo.** La estructura de este repo (`00_setup`, `01_etl`,
`02_sql`, `03_powerbi`, `04_analysis`, `05_docs`) es la de *un* proyecto: meter un segundo dentro
obligaría a anidar todo bajo `proyecto-2/`. Cada proyecto va en su repo, con su README y su
historial, y el portfolio es el perfil.

## Dudas abiertas
- ¿El forward fill del fin de semana (EUR/USD) puede sesgar la correlación? → revisar en la Fase 4
  y declararlo en el notebook.
