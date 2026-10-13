# Despliegue automático a producción (GitHub Actions → HostChile)

Cada push a `master` (que no sea solo documentación) ejecuta `.github/workflows/desplegar-produccion.yml`. Es el mismo esquema del pipeline anterior (rama `PRODUCCION`, MonsterASP), apuntado a HostChile:

1. Restaura paquetes y compila `Library` (todas sus DLL van al `bin` de la web), **precompila la web** y compila la API. Si no compila, **no se sube nada**.
2. Aplica la **configuración de producción** a la copia que se publica (`Dev/ci/configurar_produccion.ps1`).
3. Publica por **Web Deploy** (`msdeploy`) con `AppOffline` (IIS pone `app_offline.htm` solo mientras copia): web en `sigma.codigocreativo.tech`, API en `sigma-api.codigocreativo.tech`.
4. Comprueba que `…/Login.aspx` y la API responden 200.

**Migraciones SQL: no hay etapa automática.** Desarrollo y producción comparten la base de HostChile (decisión del 12-10-2026), así que una migración se aplica una vez, a mano (`Dev/sql_aplicar.py`), y vale para ambos.

## Una sola vez: configurar GitHub
**Settings → Secrets and variables → Actions.** Hasta que exista la variable `HC_SERVER`, el job no corre (los push a `master` no intentan desplegar).

**Secrets** (los escribe una persona; nunca por chat ni en el repo):

| Secreto | Qué es |
|---|---|
| `HC_WEB_DEPLOY_PASSWORD` | Contraseña de *Publicación de despliegue web* del subdominio `sigma` (Plesk) |
| `HC_API_DEPLOY_PASSWORD` | Lo mismo para `sigma-api` |
| `DB_CONNECTION_PROD` | Cadena de conexión de la base `sigma` de HostChile |
| `MACHINE_VALIDATION_KEY` | 128 caracteres hex aleatorios |
| `MACHINE_DECRYPTION_KEY` | 64 caracteres hex aleatorios |
| `INTRANET_APPSETTINGS_JSON` | (opcional) `{"ServiciosApiKey":"…","Crypto":"…"}` con valores de producción |
| `API_APPSETTINGS_JSON` | (opcional) `{"JWT_SECRET_KEY":"…","ServiciosApiKey":"…"}` con valores de producción |

Generar una clave: `python -c "import secrets;print(secrets.token_hex(64).upper())"` (usar 32 para la de cifrado).

**Variables** (no son secretas):

| Variable | Valor hoy |
|---|---|
| `HC_SERVER` | IP del hosting (`173.248.133.222`) |
| `HC_WEB_SITE` / `HC_WEB_USER` | Nombre del sitio y usuario de Web Deploy del subdominio `sigma` (los muestra Plesk al activar la publicación) |
| `HC_API_SITE` / `HC_API_USER` | Lo mismo para `sigma-api` |
| `URL_SITIO` | `https://sigma.codigocreativo.tech` |
| `URL_API` | `https://sigma-api.codigocreativo.tech` |

**En Plesk:** en cada subdominio, activar *Publicación de despliegue web* (Web Deploy Publishing). Genera el usuario y la contraseña que van arriba. El puerto 8172 del servidor está abierto.

Los secretos `WEB_DEPLOY_PASSWORD` y `API_DEPLOY_PASSWORD` que ya existen son de **MonsterASP** (sitios `site96410` y `site96413`) y no sirven aquí; se dejan mientras MonsterASP siga de respaldo.

## Por qué la configuración de producción va en el pipeline
Producción necesita valores distintos a desarrollo: `validateIntegratedModeConfiguration=false` (500.22 en modo Integrado), sesión `InProc` (el hosting no tiene el servicio ASP.NET State), `machineKey` fija (si no, «Validation of viewstate MAC failed») y las URL públicas. El script los aplica **solo a la copia publicada**, no al `Web.config` del repo.

## Deshacer un despliegue
Volver a ejecutar el workflow sobre el commit bueno (Actions → *Run workflow*, o revertir en `master`).

## Cuidados
- `master` debe protegerse (Settings → Branches): solo Pull Request con revisión. Todo lo que entra se publica.
- La rama por defecto del repositorio es `main` (historia huérfana, no se usa): el botón *Run workflow* solo aparece si el archivo existe ahí.
- Si alguien guarda la pantalla «Configuración de ASP.NET» de Plesk, ese panel reescribe el `Web.config`; el siguiente despliegue lo deja como debe.
- **Desarrollo y producción comparten base de datos**: lo que se prueba en local afecta a lo que ven los usuarios reales. Evitar pruebas destructivas y borrados masivos.
