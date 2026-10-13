# Servidor SIGMA en una VM Hyper-V (web, API y SQL Server en tu PC)

Cinco scripts, en orden. Los que dicen **administrador** se abren con «Ejecutar como administrador». Ninguno descarga nada, guarda claves ni las muestra: las que se piden, se escriben ocultas.

| # | Script | Dónde | Qué hace |
|---|---|---|---|
| 1 | `01_habilitar_hyperv.ps1` | PC · **admin** | Habilita Hyper-V. **Reiniciar** después |
| 2 | `02_crear_vm.ps1 -Iso <ruta>` | PC · **admin** | Crea la VM (4 vCPU, RAM 2–6 GB dinámica, disco 120 GB, red NAT interna) y la enciende |
| – | (instalar Windows Server) | consola de la VM | Standard con experiencia de escritorio; defines tú la clave de Administrador |
| 3 | `03_configurar_servidor.ps1` | **dentro de la VM** · admin | IP fija 192.168.77.10, IIS + ASP.NET, apps `/SIGMA/Intranet` y `/SIGMA/Servicio/API`, firewall, SQL Server Express |
| 4 | `04_migrar_bd.ps1` | PC | Exporta la base de desarrollo (.bacpac), la importa en la VM y crea el usuario `sigma_app` |
| 5 | `05_publicar.ps1` | PC · **admin** | Compila y copia web + API a la VM (PowerShell Direct) y configura la conexión local |

Repetir el paso 5 es el «desplegar» de cada vez.

## Lo que tienes que hacer tú (yo no puedo)
- Correr 1 y 2 como administrador y reiniciar.
- Descargar la **ISO de Windows Server 2022 (evaluación 180 días)** del Centro de Evaluación de Microsoft y aceptar su licencia.
- Descargar **SQL Server Express** (el instalador `SQLEXPR_x64_ENU.exe`) y pasarlo al paso 3 con `-AceptoLicenciaSql`. Express limita cada base a **10 GB**; Developer no se debe usar en producción.
- Definir las claves (Administrador de la VM, `sa`, `sigma_app`). No las compartas por chat.
- Instalar **Tailscale** dentro de la VM para que Emilio y Catalina entren (la VM sale a internet por NAT).

## Memoria (el punto justo de tu PC: 15,6 GB)
La VM inicia con 4 GB y puede subir a 6. Tu PC ya corre un SQL Server propio: **detenlo mientras la VM trabaja** (`Stop-Service MSSQLSERVER`) o limita su memoria. SQL de la VM queda con tope de 2 GB.

## Disponibilidad
Es un laptop: tiene que estar **enchufado y sin suspender** (Configuración → Energía → Suspender: Nunca). Si se apaga, cae el servidor para los tres. La VM arranca sola con Windows (retraso de 30 s).

## Después de publicar
- En tu PC: `http://192.168.77.10/SIGMA/Intranet` (API: `.../SIGMA/Servicio/API`).
- Para el equipo: con Tailscale, `http://<ip 100.x de la VM>/SIGMA/Intranet`. Si el sitio arma enlaces absolutos con `UrlSitio`, ajústalo a esa IP en el `Web.config` de la VM.
- Migraciones nuevas: aplícalas a la base de la VM (`Dev/sql_aplicar.py` usa la conexión de `Web.config`, que apunta a desarrollo; para la VM usa `sqlcmd -S 192.168.77.10 -d SIGMA -U sigma_app`).

## Probado
Los scripts **no se han ejecutado todavía** (requieren administrador, reinicio y la ISO). Se verificó solo su sintaxis. Si un paso falla, deja el mensaje en el chat (sin claves) y se corrige.
