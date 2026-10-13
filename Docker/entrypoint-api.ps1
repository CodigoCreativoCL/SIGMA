# =============================================================================
# SIGMA · API — configuracion en el arranque del contenedor
#
# Mismo criterio que la Intranet: la imagen no lleva credenciales. Todo lo
# sensible —la base, la firma del token, las claves de Azure— entra por
# variable de entorno y se escribe en Web.config al arrancar.
#
# JWT_SECRET_KEY es obligatoria y no tiene valor por defecto a proposito:
# una firma por defecto significa que cualquiera que conozca el proyecto
# puede emitir un token valido contra cualquier despliegue.
# =============================================================================
$ErrorActionPreference = 'Stop'
$ruta = 'C:\inetpub\wwwroot\Web.config'

function Requerida($nombre) {
    $v = [Environment]::GetEnvironmentVariable($nombre)
    if ([string]::IsNullOrWhiteSpace($v)) {
        Write-Error "Falta la variable de entorno obligatoria: $nombre"
    }
    return $v
}

function Opcional($nombre) { return [Environment]::GetEnvironmentVariable($nombre) }

$doc = New-Object System.Xml.XmlDocument
$doc.PreserveWhitespace = $true
$doc.Load($ruta)

# ----------------------------------------------- cadena de conexion
$conexion = Requerida 'SIGMA_DB_CONNECTION'
$cs = $doc.SelectSingleNode("//connectionStrings/add[@name='SIGMA']")
if ($cs -eq $null) {
    $padre = $doc.SelectSingleNode('//connectionStrings')
    if ($padre -eq $null) {
        $padre = $doc.CreateElement('connectionStrings')
        $doc.DocumentElement.AppendChild($padre) | Out-Null
    }
    $cs = $doc.CreateElement('add')
    $cs.SetAttribute('name', 'SIGMA')
    $padre.AppendChild($cs) | Out-Null
}
$cs.SetAttribute('connectionString', $conexion)
$cs.SetAttribute('providerName', 'System.Data.SqlClient')

# ----------------------------------------------- appSettings
$obligatorias = @{
    'JWT_SECRET_KEY' = 'SIGMA_JWT_SECRET'
}
$opcionales = @{
    'JWT_EXPIRE_MINUTES'              = 'SIGMA_JWT_EXPIRE_MINUTES'
    'JWT_AUDIENCE_TOKEN'              = 'SIGMA_JWT_AUDIENCE'
    'JWT_ISSUER_TOKEN'                = 'SIGMA_JWT_ISSUER'
    'ServiciosApiKey'                 = 'SIGMA_API_KEY'
    'AzureBlobEndpoint'               = 'SIGMA_BLOB_ENDPOINT'
    'AzureBlobSas'                    = 'SIGMA_BLOB_SAS'
    'AzureBlobContenedor'             = 'SIGMA_BLOB_CONTENEDOR'
    'AzureML.TenantId'                = 'SIGMA_AML_TENANT'
    'AzureML.ClientId'                = 'SIGMA_AML_CLIENT_ID'
    'AzureML.ClientSecret'            = 'SIGMA_AML_CLIENT_SECRET'
    'AzureML.SubscriptionId'          = 'SIGMA_AML_SUBSCRIPTION'
    'AzureML.ResourceGroup'           = 'SIGMA_AML_RESOURCE_GROUP'
    'AzureML.Workspace'               = 'SIGMA_AML_WORKSPACE'
    'AzureML.Region'                  = 'SIGMA_AML_REGION'
    'AzureML.ContenedorArtefactos'    = 'SIGMA_AML_CONTENEDOR'
    'CustomVision.PredictionEndpoint' = 'SIGMA_CV_ENDPOINT'
    'CustomVision.PredictionKey'      = 'SIGMA_CV_KEY'
    'CustomVision.ProjectId'          = 'SIGMA_CV_PROJECT'
    'CustomVision.IterationName'      = 'SIGMA_CV_ITERATION'
}

function Aplicar($clave, $valor) {
    $nodo = $doc.SelectSingleNode("//appSettings/add[@key='$clave']")
    if ($nodo -eq $null) {
        $nodo = $doc.CreateElement('add')
        $nodo.SetAttribute('key', $clave)
        $doc.SelectSingleNode('//appSettings').AppendChild($nodo) | Out-Null
    }
    $nodo.SetAttribute('value', $valor)
}

foreach ($clave in $obligatorias.Keys) { Aplicar $clave (Requerida $obligatorias[$clave]) }

$n = 0
foreach ($clave in $opcionales.Keys) {
    $valor = Opcional $opcionales[$clave]
    if (-not [string]::IsNullOrWhiteSpace($valor)) { Aplicar $clave $valor; $n++ }
}

$doc.Save($ruta)

Write-Host "SIGMA API lista. Conexion y firma del token configuradas; $n valores opcionales aplicados."
if ([string]::IsNullOrWhiteSpace((Opcional 'SIGMA_BLOB_SAS'))) {
    Write-Host "Aviso: sin SIGMA_BLOB_SAS, las subidas de archivos van a fallar (el resto funciona)."
}

C:\ServiceMonitor.exe w3svc
