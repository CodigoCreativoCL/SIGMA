# SIGMA en contenedores

Levanta la Intranet y la API de SIGMA en Docker, con la configuración
inyectada por variables de entorno y sin ninguna credencial dentro de la
imagen.

---

## Lo primero que hay que saber

**Requiere contenedores Windows.** SIGMA es ASP.NET WebForms y Web API 2 sobre
.NET Framework 4.8, que solo corre sobre Windows con IIS. No es una
preferencia: no existe forma de llevarlo a un contenedor Linux.

Antes de poder cambiar de modo, el equipo necesita la característica
**Containers** de Windows. Si falta, Docker Desktop responde *«windows
containers have been disabled for this installation»* y el servicio `cexecsvc`
no existe. Se habilita una sola vez, en PowerShell **como administrador**, y
pide reiniciar:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All
```

Después, en Docker Desktop, *Switch to Windows containers*. Para comprobarlo:

```powershell
docker info --format '{{.OSType}}'   # debe decir: windows
```

**La base de datos no se contenedoriza, y es deliberado.** Microsoft no
publica imagen de SQL Server para contenedores Windows —la oficial es Linux— y
Docker no corre contenedores Linux y Windows bajo el mismo demonio a la vez.
Además, en producción la base la administra el hosting: meterla acá haría que
el contenedor se pareciera *menos* al ambiente real, que es lo único que lo
hace útil. La cadena de conexión entra por variable y apunta a donde
corresponda.

**Las imágenes base pesan.** `mcr.microsoft.com/dotnet/framework/aspnet:4.8`
y su SDK rondan varios GB cada una. La primera construcción se demora; las
siguientes reutilizan las capas.

---

## Puesta en marcha

```powershell
copy .env.example .env
# completar .env con los valores del ambiente
docker compose up -d --build
```

| Servicio | URL |
|---|---|
| Intranet | http://localhost:8080 |
| API (Swagger) | http://localhost:8081/swagger/ui/index |

Los puertos se cambian con `PUERTO_INTRANET` y `PUERTO_API` en el `.env`.

---

## Qué hay en cada archivo

| Archivo | Para qué |
|---|---|
| `docker-compose.yml` (raíz) | Define los dos servicios, la red, los puertos y las variables. El contexto de construcción es la raíz del repositorio |
| `intranet.Dockerfile` | Imagen de la Intranet |
| `api.Dockerfile` | Imagen de la API |
| `entrypoint-intranet.ps1` | Escribe `data.config` y los `appSettings` desde las variables, al arrancar |
| `entrypoint-api.ps1` | Escribe la conexión y los `appSettings` de la API, al arrancar |
| `.env.example` (raíz) | Describe cada variable. Se copia a `.env`, que **no se versiona** |
| `.dockerignore` (raíz) | Lo que no entra al contexto: `.git`, `bin`, `obj`, `data.config`, la documentación |

---

## Decisiones de construcción

**Se compila dentro de la imagen; no se copia un `bin` armado a mano.**
`bin/` está en `.gitignore`, así que en un clon limpio no existe. Si la imagen
copiara un `bin` local, lo que corre en el contenedor dependería del equipo de
quien la construyó. Las dependencias de terceros (Telerik, EPPlus,
AjaxControlToolkit) sí están versionadas en `Librerias/Library/Lib`, y al
compilar `Library` quedan en su `bin/Release` junto a `Library.dll`: **esa
carpeta es, archivo por archivo, el `Bin` de la Intranet**.

**Las páginas no se precompilan.** La Intranet es un proyecto *Web Site*:
`App_Code` y los `.aspx` los compila ASP.NET en tiempo de ejecución, igual que
en el hosting. Precompilar acá cambiaría la forma de desplegar respecto de
producción, y lo que se prueba en el contenedor dejaría de ser lo que corre en
SmarterASP.

**Dos imágenes, no una.** En producción la Intranet y la API son dos sitios
con su propio app pool, para que un problema en una no arrastre a la otra.
Juntarlas en un contenedor contradiría esa decisión.

**Ninguna credencial viaja en la imagen.** Una imagen con la cadena de
conexión adentro es una credencial que queda en el historial de capas para
siempre y viaja en cada copia del registro. La imagen se construye una vez y
sirve para cualquier ambiente; lo que cambia entre ambientes son las
variables.

**Si falta una variable obligatoria, el contenedor no arranca.** Son dos:
`SIGMA_DB_CONNECTION` y `SIGMA_JWT_SECRET`. Levantar con la configuración a
medias produce un sitio que responde y falla recién cuando alguien entra; es
preferible que no parta. `SIGMA_JWT_SECRET` no tiene valor por defecto a
propósito: una firma por defecto significa que cualquiera que conozca el
proyecto puede emitir un token válido contra cualquier despliegue.

---

## Trampas conocidas

**La primera línea de los Dockerfile es `# escape=\``, y no se puede borrar.**
Cambia el carácter de escape de Docker de `\` a backtick. Sin eso, en un
Dockerfile de Windows cada ruta `C:\inetpub` se interpreta como escape y el
backtick de continuación de línea de PowerShell revienta el análisis con
`unknown instruction`. Es la trampa clásica de los contenedores Windows, y se
detecta con `docker build --check` sin necesidad de construir.

**Los paquetes de NuGet se restauran en `Solucion\SIGMA\packages`, no en
`Solucion\packages`.** El `HintPath` del csproj los busca en `..\packages`
*relativo al proyecto*. Restaurar a otra carpeta no da un error de
restauración: compila igual de mal, con cientos de errores de tipo porque
MSBuild no encuentra ninguna referencia.


**`localhost` dentro del contenedor es el propio contenedor.** La Intranet
llega a la API por el nombre del servicio de compose: `http://api/`. Es el
valor por defecto de `SIGMA_API_URL`; cambiarlo a `localhost` rompe los
archivos y SIGMA AI.

**`SIGMA_API_KEY` tiene que ser la misma en los dos servicios.** Es con lo que
la Intranet se identifica ante la API para las operaciones de servicio. Si no
coinciden, la web levanta bien y las subidas de archivos fallan con 401.

**Sin `SIGMA_BLOB_SAS` el sistema funciona pero no se suben archivos.** El
entrypoint de la API lo avisa en el log al arrancar, en vez de dejar que se
descubra cuando alguien intente subir una foto.

**El healthcheck tarda en ponerse verde.** IIS más la compilación en tiempo
de ejecución de ASP.NET hacen que el primer arranque demore; por eso
`start_period` es de 90 s en la API y 120 s en la Intranet.

---

## Comandos útiles

```powershell
docker compose logs -f intranet      # ver el log del sitio
docker compose logs -f api
docker compose ps                    # estado y salud de los servicios
docker compose up -d --build api     # reconstruir solo la API
docker compose down                  # bajar todo
docker compose down --rmi local      # bajar y borrar las imágenes construidas
```

Para entrar a un contenedor:

```powershell
docker exec -it sigma-intranet powershell
```
