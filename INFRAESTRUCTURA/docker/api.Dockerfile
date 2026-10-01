# escape=`
# =============================================================================
# SIGMA · API (ASP.NET Web API 2 sobre .NET Framework 4.8)
#
# LA PRIMERA LINEA NO ES UN COMENTARIO CUALQUIERA
#   "# escape=`" cambia el caracter de escape de Docker de \ a backtick. Sin
#   eso, en un Dockerfile de Windows cada ruta "C:\inetpub" se interpreta como
#   escape y el backtick de continuacion de linea de PowerShell rompe el
#   analisis con "unknown instruction". Es la trampa clasica de los
#   contenedores Windows.
#
# POR QUE UNA IMAGEN SEPARADA Y NO LA MISMA QUE LA INTRANET
#   En produccion la Intranet y la API son dos sitios con su propio app pool,
#   justamente para que un problema en una no se lleve a la otra. Meterlas en
#   un solo contenedor contradiria esa decision y haria que el contenedor se
#   pareciera menos a produccion, que es lo unico que lo hace util.
#
# POR QUE SE COMPILA DENTRO DE LA IMAGEN
#   bin/ esta en .gitignore. Si la imagen copiara un bin construido a mano,
#   lo que corre en el contenedor dependeria del equipo de quien la construyo.
#   Se compila desde el codigo, con restauracion de NuGet, para que la imagen
#   sea reproducible desde el repositorio.
#
# El contexto de construccion es la RAIZ del repositorio.
# =============================================================================

# ---------------------------------------------------------------- compilacion
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2022 AS build
SHELL ["powershell", "-Command", "$ErrorActionPreference='Stop';"]

WORKDIR C:\src

# La libreria compartida es dependencia de la API.
COPY Librerias\Library Librerias\Library
COPY Solucion\SIGMA\API Solucion\SIGMA\API

# Los 45 paquetes de packages.config NO estan versionados, y el csproj los
# busca con HintPath en "..\packages" relativo al proyecto, o sea en
# Solucion\SIGMA\packages. Restaurar a otra carpeta compila igual de mal:
# MSBuild no encuentra las referencias y falla con cientos de errores de tipo.
RUN nuget restore Solucion\SIGMA\API\packages.config `
      -PackagesDirectory Solucion\SIGMA\packages -NonInteractive

RUN msbuild Solucion\SIGMA\API\API.csproj `
      /t:Build /p:Configuration=Release /p:DeployOnBuild=false /m /nologo /v:minimal

# ------------------------------------------------------------------ ejecucion
FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2022
SHELL ["powershell", "-Command", "$ErrorActionPreference='Stop';"]

WORKDIR C:\inetpub\wwwroot
RUN Remove-Item -Recurse -Force C:\inetpub\wwwroot\* -ErrorAction SilentlyContinue

# Solo lo que la API necesita servir: nada de codigo fuente en la imagen.
COPY --from=build C:\src\Solucion\SIGMA\API\bin\       C:\inetpub\wwwroot\bin\
COPY --from=build C:\src\Solucion\SIGMA\API\Web.config  C:\inetpub\wwwroot\Web.config
COPY --from=build C:\src\Solucion\SIGMA\API\Global.asax C:\inetpub\wwwroot\Global.asax
COPY --from=build C:\src\Solucion\SIGMA\API\Areas\      C:\inetpub\wwwroot\Areas\
COPY --from=build C:\src\Solucion\SIGMA\API\Content\    C:\inetpub\wwwroot\Content\
COPY --from=build C:\src\Solucion\SIGMA\API\Scripts\    C:\inetpub\wwwroot\Scripts\
COPY --from=build C:\src\Solucion\SIGMA\API\Views\      C:\inetpub\wwwroot\Views\

COPY INFRAESTRUCTURA\docker\entrypoint-api.ps1 C:\entrypoint.ps1

EXPOSE 80

ENTRYPOINT ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "C:\\entrypoint.ps1"]
