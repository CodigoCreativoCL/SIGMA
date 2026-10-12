# =============================================================================
# SIGMA · Intranet — configuracion en el arranque del contenedor
#
# POR QUE SE ESCRIBE LA CONFIGURACION ACA Y NO EN LA IMAGEN
#   Una imagen con la cadena de conexion adentro es una credencial que viaja
#   en cada copia del registro y queda en el historial de capas para siempre.
#   La imagen se construye una vez y sirve para cualquier ambiente; lo que
#   cambia entre ambientes son las variables de entorno.
#
# SI FALTA UNA VARIABLE OBLIGATORIA, EL CONTENEDOR NO ARRANCA
#   Levantar con una configuracion a medias produce un sitio que responde y
#   falla recien cuando alguien entra. Es preferible que no parta.
# =============================================================================
$ErrorActionPreference = 'Stop'
$raiz = 'C:\inetpub\wwwroot'

function Requerida($nombre) {
    $v = [Environment]::GetEnvironmentVariable($nombre)
    if ([string]::IsNullOrWhiteSpace($v)) {
        Write-Error "Falta la variable de entorno obligatoria: $nombre"
    }
    return $v
}

function Opcional($nombre) { return [Environment]::GetEnvironmentVariable($nombre) }

# ----------------------------------------------- cadena de conexion
# data.config esta referenciado por Web.config con configSource, asi que
# basta con reescribir ese archivo.
$conexion = Requerida 'SIGMA_DB_CONNECTION'
$xml = @"
<?xml version="1.0"?>
<connectionStrings>
  <add name="SIGMA" connectionString="$([System.Security.SecurityElement]::Escape($conexion))" />
</connectionStrings>
"@
Set-Content -Path (Join-Path $raiz 'data.config') -Value $xml -Encoding UTF8

# ----------------------------------------------- appSettings
$ruta = Join-Path $raiz 'Web.config'
$doc = New-Object System.Xml.XmlDocument
$doc.PreserveWhitespace = $true
$doc.Load($ruta)

$mapa = @{
    'Crypto'                 = 'SIGMA_CRYPTO_KEY'
    'Ambiente'               = 'SIGMA_AMBIENTE'
    'UrlSitio'               = 'SIGMA_URL_SITIO'
    'ServiciosApiUrl'        = 'SIGMA_API_URL'
    'ServiciosApiKey'        = 'SIGMA_API_KEY'
    'AlmacenamientoApiUrl'   = 'SIGMA_ALMACENAMIENTO_URL'
    'AlmacenamientoApiKey'   = 'SIGMA_ALMACENAMIENTO_KEY'
    'AlmacenamientoContenedor' = 'SIGMA_ALMACENAMIENTO_CONTENEDOR'
    'GoogleMapsApiKey'       = 'SIGMA_GOOGLE_MAPS_KEY'
    'CorreoRemitente'        = 'SIGMA_CORREO_REMITENTE'
    'CorreoRemitenteNombre'  = 'SIGMA_CORREO_REMITENTE_NOMBRE'
    'PdfUrlLocal'            = 'SIGMA_PDF_URL'
}

$cambios = 0
foreach ($clave in $mapa.Keys) {
    $valor = Opcional $mapa[$clave]
    if ([string]::IsNullOrWhiteSpace($valor)) { continue }
    $nodo = $doc.SelectSingleNode("//appSettings/add[@key='$clave']")
    if ($nodo -eq $null) {
        $nodo = $doc.CreateElement('add')
        $nodo.SetAttribute('key', $clave)
        $doc.SelectSingleNode('//appSettings').AppendChild($nodo) | Out-Null
    }
    $nodo.SetAttribute('value', $valor)
    $cambios++
}
$doc.Save($ruta)

Write-Host "SIGMA Intranet lista. Conexion configurada y $cambios valores de appSettings aplicados."
Write-Host "Ambiente: $(Opcional 'SIGMA_AMBIENTE')"

# Entrega el control al arranque de IIS de la imagen base, que es quien
# mantiene vivo el contenedor y vuelca el log del sitio.
C:\ServiceMonitor.exe w3svc
