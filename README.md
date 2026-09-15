# Finance Analytics España

Análisis de facturación y cobros de una empresa B2B de servicios, cruzado con el
entorno macroeconómico español. La pregunta de partida fue concreta: **¿el Euríbor y
el IPC mueven de verdad lo que facturamos y cuándo lo cobramos?**

La respuesta corta es que sí, pero no como esperaba, y esa diferencia es lo más
interesante que encontré.

**[Ver el dashboard interactivo](https://app.powerbi.com/view?r=eyJrIjoiMWFhMGM3MGUtNzFmOC00NmY4LTkwMWItODYzMGE2MDNmODU4IiwidCI6IjhkYWIyOTY1LTkwZjUtNDM1NC1iODZhLTdkZDk2MmNhMGM1NSJ9)**
· [Portada del proyecto](https://merygonzalezisasa.github.io/bi-finance-collections-es/)
· [Cuaderno de análisis](04_analysis/01_eda.ipynb)

---

## Qué encontré

**La relación entre el Euríbor y el retraso de cobro cambia de signo.** Sobre los 29
meses completos la correlación sale en +0,88, que invita a concluir que cuando sube el
precio del dinero los clientes estiran los plazos. Pero al partirla por tramos, en 2024
es +0,91 y en 2025-2026 es **−0,53**. El número global es espurio: lo produce un único
episodio, el desplome de 2024, y no una relación estable. El retraso siguió al Euríbor
mientras bajaba y dejó de hacerlo cuando volvió a subir.

**Hay dos riesgos de cobro distintos que un solo indicador de morosidad confundiría.**
Construcción tiene el 11,8 % de su facturación vencida, cuatro veces la media, y
concentra el 44 % de toda la deuda vencida con solo el 15 % de la facturación: eso es
riesgo de crédito. El sector público paga tarde el 100 % de sus facturas, con 25 días
de retraso medio, pero apenas deja impagos: eso es riesgo de liquidez. Piden decisiones
opuestas, y meterlos en la misma métrica lleva a equivocarse con los dos.

**La cláusula de revisión por IPC está en el contrato pero no llega a la factura.** Los
servicios indexados subieron un 0,7 % de precio en dos años y medio mientras el IPC
acumulaba un 5,6 %. Son unos 244 € menos por factura y alrededor de **0,95 M€ que no se
han facturado**. Este era el hallazgo que el generador de datos *no* debía producir, y
aparecer como ausencia es precisamente lo que le da valor.

**La deuda vencida no se desliza, se atasca.** De los 5,47 M€ vencidos, el 86 % supera
los 90 días y los tramos intermedios están casi vacíos. El problema no está en la
gestión temprana de cobro: hay clientes que directamente no pagan.

**No se cumple el 80/20.** Hacen falta 58 de 120 clientes para llegar al 80 % de la
facturación, y el mayor pesa solo un 4,1 %. La cartera está mucho más atomizada de lo
habitual, lo que reduce el riesgo de dependencia pero encarece la gestión.

## Cómo está construido

```
APIs públicas ─┐
               ├─► Python ──► PostgreSQL ──┬──► Power BI (6 páginas, 39 medidas DAX)
Generador ─────┘   (ETL)     (estrella)    └──► Cuaderno de EDA (pandas)
```

| Carpeta | Qué hay |
|---|---|
| [`01_etl/`](01_etl/) | Extracción de cuatro APIs con reintentos y validación de rangos, generador de datos sintéticos y carga idempotente en Postgres |
| [`02_sql/`](02_sql/) | Esquema estrella con claves foráneas e índices, cinco vistas analíticas y procedimientos almacenados |
| [`03_powerbi/`](03_powerbi/) | Proyecto PBIP: modelo semántico, 39 medidas DAX y las seis páginas del informe |
| [`04_analysis/`](04_analysis/) | Cuaderno de análisis exploratorio, calidad de datos y valores extremos |
| [`05_docs/`](05_docs/) | Caso de negocio, diccionario de datos y conclusiones |
| [`docs/`](docs/) | La portada del proyecto que se publica en GitHub Pages |

**Stack:** Python 3.12 (pandas, SQLAlchemy, matplotlib, seaborn, SciPy) · PostgreSQL 16
· Power BI Desktop con formato PBIP y control de versiones en Git.

## Sobre los datos

La facturación es **sintética**: la generé con Faker y NumPy usando `SEED=42`, e
inyecté cinco correlaciones a propósito. Prefiero decirlo desde el principio, porque
cambia cómo hay que leer los resultados. Este proyecto no descubre una verdad sobre una
empresa real; demuestra que el pipeline detecta y cuantifica bien una señal conocida de
antemano, y que cuando la señal no está, el análisis lo dice en vez de forzarla.

Las series macroeconómicas sí son reales y vienen de fuentes públicas:

| Serie | Fuente |
|---|---|
| Euríbor 12M, mensual | Banco Central Europeo (ECB Data Portal) |
| IPC, variación anual | INE, serie IPC251856 |
| Tipo de cambio EUR/USD | Frankfurter |
| Festivos nacionales y autonómicos | Nager.Date |

Los datos cubren de enero de 2024 a junio de 2026: 15.000 facturas, 120 clientes
empresa, 8 sectores y 10 comunidades autónomas. La fecha de corte es el 30/06/2026 y
todo lo que se calcula «a hoy» usa esa fecha, no la del sistema.

## Reproducirlo

```bash
python -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env          # y rellenar las credenciales de PostgreSQL

python 01_etl/generate_facturas_data.py      # 15.000 facturas, SEED=42
python 01_etl/extract_contexto_macro.py      # las cuatro APIs
python 01_etl/load_to_postgres.py            # carga idempotente
python 01_etl/verificar_carga.py             # cuatro chequeos de integridad
```

El cuaderno de `04_analysis/` lee directamente de PostgreSQL, así que necesita el
servicio levantado y el `.env` configurado.

## Tres decisiones que condicionan todo lo demás

**El retraso se mide contra el vencimiento, nunca contra la emisión.** El plazo pactado
varía mucho entre segmentos —unos 30 días en pyme frente a 60-90 en corporate—, así que
mirar los días brutos hasta el cobro invierte la conclusión: parece que el corporate
paga peor cuando en realidad es quien más cumple lo acordado.

**`importe_total` es bimodal y hay que segmentar siempre por tipo de facturación.** Los
servicios recurrentes y los proyectos son dos negocios distintos dentro de la misma
tabla, con tickets de 5.000 € y 14.000 €. Al separarlos, los valores atípicos del
recurrente desaparecen por completo: eran el artefacto de mezclar dos poblaciones.

**Hay medidas que solo significan algo en contexto mensual.** El DSO calculado sobre
todo el periodo da 152 días, que no quiere decir nada porque divide entre los días de
dos años y medio. Lo mismo pasa con la variación interanual a nivel total. Están en el
informe, pero solo donde el contexto las hace interpretables.

## Licencia

MIT. Los datos de facturación son sintéticos y la empresa es ficticia.
