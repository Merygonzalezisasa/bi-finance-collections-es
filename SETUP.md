# SETUP — Finance Analytics España

Qué se instaló en esta máquina (Windows 11 Pro), con qué comando, y qué errores
aparecieron en el camino. Regla de oro de la Fase 0.5: cada error resuelto se anota,
porque va a volver a pasar en otra máquina dentro de tres semanas.

## Inventario inicial (2026-07-17)

Ya estaban instalados:
- **Power BI Desktop** v2.155 (Microsoft Store)
- **VS Code**

Faltaban: Python, Git, PostgreSQL.

## Lo que se instaló y cómo

### Python 3.12.10 (por usuario, sin admin)

El plan A era winget (`winget install Python.Python.3.12`), pero **se colgó dos veces
sin producir salida** en la terminal no interactiva. Plan B — instalador oficial directo:

```powershell
# Descargar de python.org y correr en silencio (instala en %LOCALAPPDATA%\Programs\Python\Python312)
Invoke-WebRequest "https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe" -OutFile python-3.12.10-amd64.exe
Start-Process .\python-3.12.10-amd64.exe -ArgumentList "/quiet","InstallAllUsers=0","PrependPath=1","Include_launcher=1" -Wait
```

Verificado: `python --version` → `Python 3.12.10`.

### Entorno virtual + dependencias

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Git 2.55 (instalador oficial de git-for-windows, GitHub Releases)

```powershell
# La URL exacta se obtiene de https://api.github.com/repos/git-for-windows/git/releases/latest
Start-Process .\Git-2.55.0.3-64-bit.exe -ArgumentList "/VERYSILENT","/NORESTART","/NOCANCEL","/CURRENTUSER" -Wait
git config --global user.name  "Rosmary González Isasa"
git config --global user.email "isasamery@gmail.com"
git config --global init.defaultBranch main
```

Quedó en `C:\Program Files\Git\cmd` (el instalador eligió instalación de sistema pese
al flag `/CURRENTUSER`). Verificado: `git --version` → `git version 2.55.0.windows.3`.

### PostgreSQL 16.12 (nativo, decisión de FICHA.md §7) + pgAdmin 4

Instalador oficial de EDB, en modo desatendido (pide UAC). pgAdmin 4 viene incluido;
se excluyó solo StackBuilder:

```powershell
# URL vigente detectada por sondeo: get.enterprisedb.com/postgresql/postgresql-16.12-1-windows-x64.exe
Start-Process .\postgresql-16.12-1-windows-x64.exe -ArgumentList "--mode","unattended","--unattendedmodeui","none","--superpassword","<LA_DE_TU_.env>","--serverport","5432","--disable-components","stackbuilder" -Verb RunAs -Wait
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -h localhost -c "CREATE DATABASE finance_analytics;"
```

Servicio: `postgresql-x64-16` (arranca solo con Windows). Contraseña del superusuario:
en `.env` (no versionado). Verificado: conexión y permisos de escritura desde Python ✓.

### Azure CLI (opcional — no requerido para el flujo local del proyecto)

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

## Errores encontrados y su solución

| Síntoma | Causa | Solución |
|---|---|---|
| `python` en la terminal "responde" pero pide instalar desde la Store | Es el **alias stub** de Microsoft Store, no un Python real | Desactivar el alias o instalar Python de verdad; verificar con `Get-Command python` que apunte a `...\Programs\Python\...` |
| `curl.exe` a APIs HTTPS falla con exit code 35 | Windows PowerShell 5.1 negocia TLS viejo | `[Net.ServicePointManager]::SecurityProtocol = Tls12` antes de llamar; en Python `requests` no hace falta |
| `winget install` se cuelga sin salida en terminal no interactiva | winget espera algo que no puede mostrar (elevación/acuerdos) | Descargar el instalador oficial y correrlo con flags silenciosos (`/quiet`, `/VERYSILENT`) |
| `winget list`/`install` piden aceptar términos de la fuente `msstore` y se cuelgan | Prompt interactivo de `[Y] Sí [N] No` sin stdin disponible | Agregar `--accept-source-agreements` y apuntar `--source winget` explícitamente |
| `winget install Microsoft.AzureCLI` → "No se ha encontrado ningún instalador aplicable" | El manifiesto de winget para ese paquete no matcheó esta máquina | Instalador MSI oficial directo desde `https://aka.ms/installazurecliwindows` |
| La API del BCE responde en PowerShell pero en Python da `CERTIFICATE_VERIFY_FAILED` | Hay inspección TLS (antivirus/proxy): PowerShell confía en los certificados de Windows, Python solo en `certifi` | `pip install truststore` + `truststore.inject_into_ssl()` antes de las peticiones (es lo que usa pip) |
| Acentos rotos ("GonzÃ¡lez") al capturar salida de git desde Python | git emite UTF-8, `subprocess` decodifica con cp1252 | `subprocess.run(..., encoding="utf-8")` |
