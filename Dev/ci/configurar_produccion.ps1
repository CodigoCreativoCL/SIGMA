# =============================================================================
# SIGMA · CI — aplica la CONFIGURACION DE PRODUCCION a los paquetes ya compilados
#
# Lo corre el pipeline (.github/workflows/desplegar-produccion.yml) despues de precompilar la web y
# compilar la API, SOBRE LA COPIA que se publica (_publicar\web y _publicar\api). El Web.config del
# repositorio no se toca: sigue sirviendo para desarrollo.
#
# Lo que aplica (lo que a mano hicimos el 12-10-2026 para que HostChile funcionara):
#   - validateIntegratedModeConfiguration="false"  (sin esto, 500.22 en modo Integrado)
#   - sesion InProc  (el hosting compartido no tiene el servicio ASP.NET State)
#   - machineKey fija (sin ella: "Validation of viewstate MAC failed" al iniciar sesion)
#   - URLs publicas de la web y la API, y la cadena de conexion (data.config y API)
# Todo valor sensible llega por variables de entorno (GitHub Secrets). NO se imprime ninguno.
#
# Requeridas : URL_SITIO, URL_API, DB_CONNECTION_PROD, MACHINE_VALIDATION_KEY, MACHINE_DECRYPTION_KEY
# Opcionales : INTRANET_APPSETTINGS_JSON, API_APPSETTINGS_JSON  ->  {"Clave":"valor", ...}
# =============================================================================
param(
    [Parameter(Mandatory = $true)][string]$Web,
    [Parameter(Mandatory = $true)][string]$Api
)
$ErrorActionPreference = 'Stop'

function Requerida([string]$n) {
    $v = [Environment]::GetEnvironmentVariable($n)
    if ([string]::IsNullOrWhiteSpace($v)) { throw "Falta el secreto o variable $n" }
    return $v.Trim()
}
$urlSitio = (Requerida 'URL_SITIO').TrimEnd('/')
$urlApi = (Requerida 'URL_API').TrimEnd('/')
$db = Requerida 'DB_CONNECTION_PROD'
$vk = Requerida 'MACHINE_VALIDATION_KEY'
$dk = Requerida 'MACHINE_DECRYPTION_KEY'

function AjustesJson([string]$nombre) {
    $t = [Environment]::GetEnvironmentVariable($nombre)
    $h = @{}
    if (-not [string]::IsNullOrWhiteSpace($t)) { ($t | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $h[$_.Name] = [string]$_.Value } }
    return $h
}
$extraWeb = AjustesJson 'INTRANET_APPSETTINGS_JSON'
$extraApi = AjustesJson 'API_APPSETTINGS_JSON'
# La clave de los jobs sale del MISMO secreto JOBS_CLAVE que usa jobs-sigma.yml para llamar a Jobs.aspx: asi nunca discrepan
# (y no hay que copiarla dentro de INTRANET_APPSETTINGS_JSON). Si el JSON ya trae JobsClave, manda el JSON.
$jobsClave = [Environment]::GetEnvironmentVariable('JOBS_CLAVE')
if (-not [string]::IsNullOrWhiteSpace($jobsClave) -and -not $extraWeb.ContainsKey('JobsClave')) { $extraWeb['JobsClave'] = $jobsClave.Trim() }

function PonerAjuste($doc, [string]$clave, [string]$valor) {
    $apps = $doc.SelectSingleNode('/configuration/appSettings')
    if (-not $apps) { throw 'El Web.config no tiene <appSettings>.' }
    $n = $apps.SelectSingleNode("add[@key='$clave']")
    if (-not $n) { $n = $doc.CreateElement('add'); $n.SetAttribute('key', $clave); [void]$apps.AppendChild($n) }
    $n.SetAttribute('value', $valor)
}
function GuardarXml($doc, [string]$ruta) {
    $w = New-Object System.IO.StreamWriter($ruta, $false, (New-Object System.Text.UTF8Encoding($true)))
    $doc.Save($w); $w.Close()
}

# ---------------------------------------------------------------- Intranet
$ruta = Join-Path $Web 'Web.config'
if (-not (Test-Path $ruta)) { throw "No existe $ruta (¿fallo la precompilacion?)" }
$doc = New-Object System.Xml.XmlDocument; $doc.PreserveWhitespace = $true; $doc.Load($ruta)
$sw = $doc.SelectSingleNode('/configuration/system.web')
$ss = $sw.SelectSingleNode('sessionState')
if ($ss) { $ss.SetAttribute('mode', 'InProc'); [void]$ss.RemoveAttribute('sqlConnectionString'); [void]$ss.RemoveAttribute('stateConnectionString') }
$mk = $sw.SelectSingleNode('machineKey')
if (-not $mk) { $mk = $doc.CreateElement('machineKey'); [void]$sw.PrependChild($mk) }
$mk.SetAttribute('validationKey', $vk); $mk.SetAttribute('decryptionKey', $dk)
$mk.SetAttribute('validation', 'HMACSHA256'); $mk.SetAttribute('decryption', 'AES')
$ws = $doc.SelectSingleNode('/configuration/system.webServer')
if (-not $ws) { $ws = $doc.CreateElement('system.webServer'); [void]$doc.DocumentElement.AppendChild($ws) }
$val = $ws.SelectSingleNode('validation')
if (-not $val) { $val = $doc.CreateElement('validation'); [void]$ws.PrependChild($val) }
$val.SetAttribute('validateIntegratedModeConfiguration', 'false')
PonerAjuste $doc 'UrlSitio' $urlSitio
PonerAjuste $doc 'PdfUrlLocal' $urlSitio
PonerAjuste $doc 'ServiciosApiUrl' $urlApi
PonerAjuste $doc 'AlmacenamientoApiUrl' $urlApi
foreach ($k in $extraWeb.Keys) { PonerAjuste $doc $k $extraWeb[$k] }
GuardarXml $doc $ruta

$escapada = [System.Security.SecurityElement]::Escape($db)
$dc = "<?xml version=`"1.0`"?>`r`n<connectionStrings>`r`n  <add name=`"SIGMA`" connectionString=`"$escapada`" />`r`n</connectionStrings>`r`n"
[IO.File]::WriteAllText((Join-Path $Web 'data.config'), $dc, (New-Object System.Text.UTF8Encoding($true)))

# ---------------------------------------------------------------- API
$ruta = Join-Path $Api 'Web.config'
if (-not (Test-Path $ruta)) { throw "No existe $ruta" }
$doc = New-Object System.Xml.XmlDocument; $doc.PreserveWhitespace = $true; $doc.Load($ruta)
PonerAjuste $doc 'DefaultConnectionStringName' $db
foreach ($k in $extraApi.Keys) { PonerAjuste $doc $k $extraApi[$k] }
GuardarXml $doc $ruta
Remove-Item (Join-Path $Api 'bin\API.dll.config') -Force -ErrorAction SilentlyContinue   # copia del Web.config de desarrollo

# ---------------------------------------------------------------- verificacion: ningun servidor de desarrollo antiguo en los paquetes
$malos = @()
foreach ($dir in $Web, $Api) {
    Get-ChildItem $dir -Recurse -File -Include *.config, *.json | Where-Object { $_.Length -lt 3MB } | ForEach-Object {
        if ([IO.File]::ReadAllText($_.FullName) -match 'databaseasp\.net') { $malos += $_.FullName }
    }
}
if ($malos.Count -gt 0) { throw ("Quedan referencias al servidor de desarrollo antiguo (MonsterASP) en: " + ($malos -join ', ')) }
"Configuracion de produccion aplicada: web ($((Get-ChildItem $Web -Recurse -File).Count) archivos) y API ($((Get-ChildItem $Api -Recurse -File).Count) archivos)."
