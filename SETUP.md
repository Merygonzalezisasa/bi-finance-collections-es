# SETUP — Finance Analytics España

Dos cosas en un documento: el procedimiento para montar el proyecto en un
ordenador nuevo, y el registro de lo que se instaló en el original con los
errores que aparecieron. Lo segundo no es historia: varios de esos errores
vuelven a salir en cualquier máquina con Windows.

- [Montarlo en otro ordenador](#montarlo-en-otro-ordenador)
- [Errores que van a repetirse](#errores-que-van-a-repetirse)
- [Registro de la máquina original](#registro-de-la-máquina-original)

---

# Montarlo en otro ordenador

Tres cosas no viajan en el repositorio: la contraseña de la base de datos, el
entorno de Python y la base de datos en sí. Todo lo demás se clona.

El orden importa poco, salvo que el entorno de Python tiene que existir antes de
registrar el kernel de Jupyter.

## 1. Lo que hace falta instalar

| | Versión | Nota |
|---|---|---|
| Python | 3.12 | Desde python.org, no desde la Microsoft Store — la de la Store instala un ejecutable intermedio que rompe los kernels de Jupyter |
| PostgreSQL | 16 | Al instalarlo pregunta la contraseña del usuario `postgres`; apúntala, es la que va en `.env` |
| Power BI Desktop | último | Solo para abrir y editar el informe |
| Git | cualquiera | |
| Node.js | 20 o superior | Opcional, solo para las CLI de Power BI |

## 2. Clonar

```bash
git clone https://github.com/Merygonzalezisasa/bi-finance-collections-es.git
cd bi-finance-collections-es
```

## 3. La contraseña

`.env` no está en el repositorio a propósito: es la única credencial del
proyecto. Hay que crearlo a mano a partir de la plantilla.

```bash
cp .env.example .env
```

Y editar `DB_PASSWORD` con la contraseña de `postgres` del ordenador nuevo. El
resto de valores sirven tal cual si PostgreSQL está en local y en el puerto por
defecto.

No hace falta que la contraseña sea la misma que en el ordenador viejo: la base
se restaura con la credencial local, sea la que sea.

## 4. Entorno de Python

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements-lock.txt
```

`requirements-lock.txt` fija las versiones exactas con las que está construido
el proyecto: pandas 3.0.3, numpy 2.5.1, matplotlib 3.11.0. Úsalo si quieres que
el notebook dé los mismos resultados sin sorpresas.

`requirements.txt` tiene la misma lista sin versiones, para una instalación
flexible. Sirve si no te importa que una versión nueva cambie algún detalle.

## 5. Restaurar la base de datos

El volcado está en el repositorio, comprimido y con las cinco vistas y los tres
procedimientos almacenados dentro.

```bash
createdb -U postgres finance_analytics
pg_restore -U postgres -d finance_analytics 02_sql/dump/finance_analytics.dump
```

Si `createdb` y `pg_restore` no se encuentran, están en
`C:\Program Files\PostgreSQL\16\bin` y hay que llamarlos por su ruta completa o
añadir esa carpeta al PATH.

Para comprobar que ha entrado todo:

```bash
psql -U postgres -d finance_analytics -c "select count(*) from finance.fact_facturas;"
```

Tienen que salir **15.000** facturas. Si sale eso, el resto está bien.

### Por qué un volcado y no regenerar los datos

Los scripts de `01_etl/` reconstruyen los datos, y la facturación sintética
saldría idéntica porque el generador usa `SEED=42`. Pero el contexto
macroeconómico se descarga de cuatro APIs públicas en vivo, y esas series
crecen: ejecutar hoy `extract_contexto_macro.py` traería Euríbor e IPC de meses
posteriores al cierre del proyecto. Las cifras del informe dejarían de cuadrar.

El volcado congela el dataset exacto que describen el dashboard y el notebook.
Regenerar tiene sentido si lo que quieres es precisamente actualizar el periodo.

## 6. Kernel de Jupyter

Sin este paso VS Code abre el notebook con el Python del sistema y falla con
`ModuleNotFoundError: No module named 'matplotlib'`, aunque el paquete esté
instalado en el entorno.

```bash
.venv\Scripts\python -m ipykernel install --user --name finance-analytics --display-name "Finance Analytics (.venv)"
```

Después, en VS Code, elegir ese kernel arriba a la derecha del notebook.

## 7. Power BI

El informe está en formato PBIP, es decir, carpetas de JSON y TMDL en lugar de
un binario. Se abre con:

```
03_powerbi\Portfolio - Rosmary.pbip
```

**Abre el `.pbip`, no el `.pbix`.** Los dos tienen el mismo nombre y están en la
misma carpeta. El `.pbix` es la versión compilada: si editas ahí, los cambios no
llegan al TMDL ni al control de versiones.

El informe trae los datos importados, así que se abre y se ve sin conectar nada.
Para refrescar contra la base restaurada hay que actualizar las credenciales en
*Archivo → Opciones → Configuración del origen de datos*.

## 8. Comprobación final

| Qué | Dónde | Resultado esperado |
|---|---|---|
| Base de datos | `select count(*) from finance.fact_facturas` | 15.000 |
| Notebook | Ejecutar `04_analysis/01_eda.ipynb` completo | 27 celdas sin error, 6 gráficos |
| Informe | Abrir el `.pbip` | 6 páginas, 102 medidas en el panel |
| Sitio | `docs/index.html` en el navegador | La portada con las 6 tarjetas |

## Lo que no hace falta transferir

- `.venv/` — 796 MB que se reconstruyen con un comando
- `data/raw/fact_facturas.csv` — lo regenera el generador, y además ya está
  cargado en la base
- `logs/` — registros de ejecuciones viejas
- `**/.pbi/localSettings.json` y `cache.abf` — guardan rutas de la máquina
  anterior; Power BI los recrea

---

# Errores que van a repetirse

La tabla está al final, en el registro de la máquina original. Estos cuatro son
los que con más probabilidad vuelven a aparecer:

| Síntoma | Solución |
|---|---|
| `ModuleNotFoundError: No module named 'matplotlib'` en VS Code, con el paquete instalado | Falta registrar el kernel — paso 6 de arriba |
| `python` abre la Microsoft Store en vez de ejecutarse | Es el alias de la Store. Instalar Python de python.org y comprobar con `Get-Command python` que apunta a `...\Programs\Python\...` |
| `CERTIFICATE_VERIFY_FAILED` al llamar a las APIs desde Python | Hay inspección TLS en la red. `pip install truststore` y `truststore.inject_into_ssl()` antes de las peticiones |
| `winget install` se queda colgado sin decir nada | Está esperando una confirmación que no puede mostrar. Descargar el instalador oficial y usar los flags silenciosos |

---

# Registro de la máquina original

Qué se instaló en esta máquina (Windows 11 Pro), con qué comando, y qué errores
aparecieron en el camino. Regla de oro de la Fase 0.5: cada error resuelto se anota,
porque va a volver a pasar en otra máquina dentro de tres semanas.

### Inventario inicial (2026-07-17)

Ya estaban instalados:
- **Power BI Desktop** v2.155 (Microsoft Store)
- **VS Code**

Faltaban: Python, Git, PostgreSQL.

### Lo que se instaló y cómo

#### Python 3.12.10 (por usuario, sin admin)

El plan A era winget (`winget install Python.Python.3.12`), pero **se colgó dos veces
sin producir salida** en la terminal no interactiva. Plan B — instalador oficial directo:

```powershell
# Descargar de python.org y correr en silencio (instala en %LOCALAPPDATA%\Programs\Python\Python312)
Invoke-WebRequest "https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe" -OutFile python-3.12.10-amd64.exe
Start-Process .\python-3.12.10-amd64.exe -ArgumentList "/quiet","InstallAllUsers=0","PrependPath=1","Include_launcher=1" -Wait
```

Verificado: `python --version` → `Python 3.12.10`.

#### Entorno virtual + dependencias

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

#### Git 2.55 (instalador oficial de git-for-windows, GitHub Releases)

```powershell
# La URL exacta se obtiene de https://api.github.com/repos/git-for-windows/git/releases/latest
Start-Process .\Git-2.55.0.3-64-bit.exe -ArgumentList "/VERYSILENT","/NORESTART","/NOCANCEL","/CURRENTUSER" -Wait
git config --global user.name  "Rosmary González Isasa"
git config --global user.email "isasamery@gmail.com"
git config --global init.defaultBranch main
```

Quedó en `C:\Program Files\Git\cmd` (el instalador eligió instalación de sistema pese
al flag `/CURRENTUSER`). Verificado: `git --version` → `git version 2.55.0.windows.3`.

#### PostgreSQL 16.12 (nativo, decisión de FICHA.md §7) + pgAdmin 4

Instalador oficial de EDB, en modo desatendido (pide UAC). pgAdmin 4 viene incluido;
se excluyó solo StackBuilder:

```powershell
# URL vigente detectada por sondeo: get.enterprisedb.com/postgresql/postgresql-16.12-1-windows-x64.exe
Start-Process .\postgresql-16.12-1-windows-x64.exe -ArgumentList "--mode","unattended","--unattendedmodeui","none","--superpassword","<LA_DE_TU_.env>","--serverport","5432","--disable-components","stackbuilder" -Verb RunAs -Wait
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -h localhost -c "CREATE DATABASE finance_analytics;"
```

Servicio: `postgresql-x64-16` (arranca solo con Windows). Contraseña del superusuario:
en `.env` (no versionado). Verificado: conexión y permisos de escritura desde Python ✓.

#### Azure CLI (opcional — no requerido para el flujo local del proyecto)

Se instaló a pedido de Rosmary, aunque no es necesario para trabajar con Power BI Desktop
local. `winget install Microsoft.AzureCLI` falló dos veces ("No se ha encontrado ningún
instalador aplicable"). Instalador MSI oficial directo:

```powershell
Invoke-WebRequest "https://aka.ms/installazurecliwindows" -OutFile AzureCLI.msi
Start-Process msiexec.exe -ArgumentList "/i","AzureCLI.msi","/qn","/norestart" -Verb RunAs -Wait
```

Quedó en `C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin\az.cmd` (no en `Program Files`
sin `(x86)`, aunque Windows es de 64 bits). Verificado: `az --version` → `azure-cli 2.89.0`.
**Hace falta cerrar y reabrir la terminal** para que tome el PATH actualizado.

### Errores encontrados y su solución

| Síntoma | Causa | Solución |
|---|---|---|
| `python` en la terminal "responde" pero pide instalar desde la Store | Es el **alias stub** de Microsoft Store, no un Python real | Desactivar el alias o instalar Python de verdad; verificar con `Get-Command python` que apunte a `...\Programs\Python\...` |
| `curl.exe` a APIs HTTPS falla con exit code 35 | Windows PowerShell 5.1 negocia TLS viejo | `[Net.ServicePointManager]::SecurityProtocol = Tls12` antes de llamar; en Python `requests` no hace falta |
| `winget install` se cuelga sin salida en terminal no interactiva | winget espera algo que no puede mostrar (elevación/acuerdos) | Descargar el instalador oficial y correrlo con flags silenciosos (`/quiet`, `/VERYSILENT`) |
| `winget list`/`install` piden aceptar términos de la fuente `msstore` y se cuelgan | Prompt interactivo de `[Y] Sí [N] No` sin stdin disponible | Agregar `--accept-source-agreements` y apuntar `--source winget` explícitamente |
| `winget install Microsoft.AzureCLI` → "No se ha encontrado ningún instalador aplicable" | El manifiesto de winget para ese paquete no matcheó esta máquina | Instalador MSI oficial directo desde `https://aka.ms/installazurecliwindows` |
| La API del BCE responde en PowerShell pero en Python da `CERTIFICATE_VERIFY_FAILED` | Hay inspección TLS (antivirus/proxy): PowerShell confía en los certificados de Windows, Python solo en `certifi` | `pip install truststore` + `truststore.inject_into_ssl()` antes de las peticiones (es lo que usa pip) |
| Acentos rotos ("GonzÃ¡lez") al capturar salida de git desde Python | git emite UTF-8, `subprocess` decodifica con cp1252 | `subprocess.run(..., encoding="utf-8")` |
