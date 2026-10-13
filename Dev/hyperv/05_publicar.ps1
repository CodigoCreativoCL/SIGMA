# =============================================================================
# SIGMA · Paso 5 — compilar y publicar la web y la API en la VM
#
# QUIEN LO CORRE: tu, en PowerShell COMO ADMINISTRADOR en tu PC (PowerShell Direct
# habla con la VM por el bus de Hyper-V, sin red ni puertos). Repetible: es el
# "desplegar" de cada vez que quieras ver tus cambios en el servidor.
#
# QUE HACE
#   1. Compila la libreria y la API (Release), como en el Dockerfile.
#   2. Arma la web (sitio tal cual + Library en Bin) y la API (bin, Web.config, ...).
#   3. Las copia a C:\inetpub\SIGMA\ de la VM (sin data.config de tu PC).
#   4. Escribe en la VM la conexion al SQL LOCAL de la VM (usuario sigma_app) y las
#      URLs del sitio y de la API. Pide las claves ocultas; no se guardan en el repo.
#
#   .\05_publicar.ps1                       # todo
#   .\05_publicar.ps1 -SoloConfigurar       # solo reescribe la conexion
#   .\05_publicar.ps1 -SinCompilar          # reutiliza lo compilado
# =============================================================================
#Requires -RunAsAdministrator
param(
    [string]$Usuario = 'Administrador',
    [string]$Nombre = 'SIGMA-SRV',
    [string]$VmIp = '192.168.77.10',
    [string]$Base = 'SIGMA',
    [string]$Staging = 'C:\HyperV\staging',
    [switch]$SoloConfigurar,
    [switch]$SinCompilar
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$msbuild = (Get-ChildItem "C:\Program Files\Microsoft Visual Studio\*\*\MSBuild\Current\Bin\MSBuild.exe" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
if (-not $msbuild -and -not $SoloConfigurar -and -not $SinCompilar) { throw 'No encuentro MSBuild (Visual Studio).' }

if (-not $SoloConfigurar) {
    if (-not $SinCompilar) {
        Write-Host 'Compilando Library y API (Release)...'
        & $msbuild (Join-Path $repo 'Librerias\Library\Library.csproj') /t:Build /p:Configuration=Release /m /nologo /v:minimal
        if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion de Library.' }
        & $msbuild (Join-Path $repo 'Solucion\SIGMA\API\API.csproj') /t:Build /p:Configuration=Release /p:DeployOnBuild=false /m /nologo /v:minimal
        if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion de la API.' }
    }
    # ------------------------------------------------------------ armar lo que se copia
    Remove-Item -Recurse -Force $Staging -ErrorAction SilentlyContinue
    $web = Join-Path $Staging 'Intranet'; $api = Join-Path $Staging 'API'
    robocopy (Join-Path $repo 'Web\Intranet') $web /E /XD .git .vs node_modules /XF data.config azure.config *.user /NFL /NDL /NJH /NJS /NP | Out-Null
    robocopy (Join-Path $repo 'Librerias\Library\bin\Release') (Join-Path $web 'Bin') /E /NFL /NDL /NJH /NJS /NP | Out-Null
    $apiSrc = Join-Path $repo 'Solucion\SIGMA\API'
    foreach ($d in 'bin', 'Areas', 'Content', 'Scripts', 'Views') {
        if (Test-Path (Join-Path $apiSrc $d)) { robocopy (Join-Path $apiSrc $d) (Join-Path $api $d) /E /NFL /NDL /NJH /NJS /NP | Out-Null }
    }
    foreach ($f in 'Web.config', 'Global.asax') { Copy-Item (Join-Path $apiSrc $f) $api -Force }

    # ------------------------------------------------------------ copiar a la VM
    $cred = Get-Credential -UserName "$Nombre\$Usuario" -Message 'Administrador de la VM (el de la instalacion de Windows Server)'
    $s = New-PSSession -VMName $Nombre -Credential $cred
    Write-Host 'Copiando a la VM...'
    Invoke-Command -Session $s { Remove-Item 'C:\inetpub\SIGMA\Intranet\*', 'C:\inetpub\SIGMA\Servicio\API\*' -Recurse -Force -ErrorAction SilentlyContinue }
    Copy-Item -Path "$web\*" -Destination 'C:\inetpub\SIGMA\Intranet' -ToSession $s -Recurse -Force
    Copy-Item -Path "$api\*" -Destination 'C:\inetpub\SIGMA\Servicio\API' -ToSession $s -Recurse -Force
} else {
    $cred = Get-Credential -UserName "$Nombre\$Usuario" -Message 'Administrador de la VM'
    $s = New-PSSession -VMName $Nombre -Credential $cred
}

# ---------------------------------------------------------------- configuracion en la VM
$clave = Read-Host 'Clave del usuario sigma_app (la del paso 4)' -AsSecureString
$plano = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($clave))
$cadena = "Data Source=localhost;Initial Catalog=$Base;User Id=sigma_app;Password=$plano;TrustServerCertificate=True;MultipleActiveResultSets=True;Min Pool Size=20;"
$urlSitio = "http://$VmIp/SIGMA/Intranet"
$urlApi = "http://$VmIp/SIGMA/Servicio/API"
Invoke-Command -Session $s -ArgumentList $cadena, $urlSitio, $urlApi {
    param($cadena, $urlSitio, $urlApi)
    # Intranet: data.config esta referenciado desde Web.config por configSource.
    $xml = "<?xml version=`"1.0`"?>`r`n<connectionStrings>`r`n  <add name=`"SIGMA`" connectionString=`"$([Security.SecurityElement]::Escape($cadena))`" />`r`n</connectionStrings>"
    Set-Content -Path 'C:\inetpub\SIGMA\Intranet\data.config' -Value $xml -Encoding UTF8
    # Web.config de la Intranet: URL del sitio y de la API.
    $ruta = 'C:\inetpub\SIGMA\Intranet\Web.config'
    $doc = New-Object System.Xml.XmlDocument; $doc.PreserveWhitespace = $true; $doc.Load($ruta)
    foreach ($par in @(@('UrlSitio', $urlSitio), @('ServiciosApiUrl', $urlApi))) {
        $n = $doc.SelectSingleNode("//appSettings/add[@key='$($par[0])']")
        if ($n) { $n.SetAttribute('value', $par[1]) }
    }
    $doc.Save($ruta)
    # API: la cadena SIGMA de su Web.config.
    $ra = 'C:\inetpub\SIGMA\Servicio\API\Web.config'
    $d2 = New-Object System.Xml.XmlDocument; $d2.PreserveWhitespace = $true; $d2.Load($ra)
    $cs = $d2.SelectSingleNode("//connectionStrings/add[@name='SIGMA']")
    if (-not $cs) { throw 'La API no tiene una cadena de conexion SIGMA en su Web.config.' }
    $cs.SetAttribute('connectionString', $cadena)
    $d2.Save($ra)
    iisreset /restart | Out-Null
}
$plano = $null; $cadena = $null
Remove-PSSession $s

Write-Host ''
Write-Host "Publicado. Intranet: $urlSitio   API: $urlApi" -ForegroundColor Green
Write-Host 'Desde tu PC deberia abrir; para Emilio y Catalina instala Tailscale dentro de la VM y usa su IP 100.x.'
