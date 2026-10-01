# escape=`
# =============================================================================
# SIGMA · Intranet (ASP.NET WebForms 4.8)
#
# LA PRIMERA LINEA NO ES UN COMENTARIO CUALQUIERA
#   "# escape=`" cambia el caracter de escape de Docker de \ a backtick. Sin
#   eso, en un Dockerfile de Windows cada ruta "C:\inetpub" se interpreta como
#   escape y el backtick de continuacion de linea de PowerShell rompe el
#   analisis con "unknown instruction".
#
# POR QUE UN CONTENEDOR WINDOWS Y NO LINUX
#   La Intranet es ASP.NET WebForms sobre .NET Framework 4.8, que solo corre
#   sobre Windows con IIS. No existe forma de llevarlo a un contenedor Linux:
#   no es una decision de preferencia, es la plataforma.
#
# POR QUE SE COMPILA LA LIBRERIA Y NO SE COPIA EL BIN
#   La carpeta Bin/ esta en .gitignore, asi que en un clon limpio no existe.
#   Las dependencias de terceros (Telerik, EPPlus, AjaxControlToolkit) si
#   estan versionadas en Librerias\Library\Lib, y al compilar Library quedan
#   en su bin\Release junto a Library.dll: esa carpeta ES el Bin de la
#   Intranet, archivo por archivo (43 archivos, verificado). Compilar es lo
#   unico que garantiza que la imagen se construya desde el repositorio solo.
#
# LAS PAGINAS NO SE PRECOMPILAN
#   Es un proyecto Web Site: App_Code y los .aspx los compila ASP.NET en
#   tiempo de ejecucion, igual que en el hosting. Precompilar aqui cambiaria
#   la forma de desplegar respecto de produccion, y lo que se prueba en el
#   contenedor dejaria de ser lo que corre en SmarterASP.
#
# El contexto de construccion es la RAIZ del repositorio.
# =============================================================================

# ---------------------------------------------------------------- compilacion
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2022 AS build
SHELL ["powershell", "-Command", "$ErrorActionPreference='Stop';"]

WORKDIR C:\src

# Solo la libreria: si no cambia, esta capa se reutiliza y la construccion
# siguiente se salta la compilacion entera.
COPY Librerias\Library Librerias\Library

RUN msbuild Librerias\Library\Library.csproj `
      /t:Build /p:Configuration=Release /m /nologo /v:minimal

# ------------------------------------------------------------------ ejecucion
FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2022
SHELL ["powershell", "-Command", "$ErrorActionPreference='Stop';"]

WORKDIR C:\inetpub\wwwroot
RUN Remove-Item -Recurse -Force C:\inetpub\wwwroot\* -ErrorAction SilentlyContinue

# El sitio tal cual se despliega hoy por FTP.
COPY Web\Intranet\ C:\inetpub\wwwroot\

# Bin = la salida de Library (Library.dll + las 42 dependencias de terceros).
COPY --from=build C:\src\Librerias\Library\bin\Release\ C:\inetpub\wwwroot\Bin\

# La identidad del app pool necesita escribir las subidas temporales y la
# cache de compilacion de ASP.NET.
RUN $acl = Get-Acl 'C:\inetpub\wwwroot'; `
    $regla = New-Object System.Security.AccessControl.FileSystemAccessRule( `
             'IIS_IUSRS','Modify','ContainerInherit,ObjectInherit','None','Allow'); `
    $acl.AddAccessRule($regla); `
    Set-Acl 'C:\inetpub\wwwroot' $acl

COPY INFRAESTRUCTURA\docker\entrypoint-intranet.ps1 C:\entrypoint.ps1

EXPOSE 80

# Ninguna credencial viaja dentro de la imagen: el entrypoint escribe la
# configuracion desde las variables de entorno en cada arranque.
ENTRYPOINT ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "C:\\entrypoint.ps1"]
