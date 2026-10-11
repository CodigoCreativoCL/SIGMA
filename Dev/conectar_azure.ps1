# =====================================================================
#  SIGMA · Conecta el ambiente de DESARROLLO a la base Azure SQL
#  (codigocreativo.database.windows.net / SIGMA, oferta gratuita).
#
#  - Pide la contraseña en esta terminal (no se escribe en el chat ni en git).
#  - Respalda data.config y el Web.config de la API en C:\Capstone\_scratch.
#  - Escribe la cadena en Web/Intranet/data.config y en la API.
#  - Opcional: guarda la credencial de solo lectura de Azure Monitor en
#    Web/Intranet/azure.config, que alimenta el indicador del cupo gratuito.
#  - Marca los dos archivos versionados con --skip-worktree para que la
#    contraseña no se suba por accidente.
#
#  Uso:   powershell -ExecutionPolicy Bypass -File Dev\conectar_azure.ps1
#  Volver a MonsterASP: copiar de vuelta los respaldos de _scratch.
# =====================================================================
$ErrorActionPreference = 'Stop'
$raiz    = Split-Path -Parent $PSScriptRoot
$data    = Join-Path $raiz 'Web\Intranet\data.config'
$apiCfg  = Join-Path $raiz 'Solucion\SIGMA\API\Web.config'
$azure   = Join-Path $raiz 'Web\Intranet\azure.config'
$resp    = 'C:\Capstone\_scratch'
$sello   = Get-Date -Format 'yyyyMMdd_HHmm'

function Plano([Security.SecureString]$s) {
    $p = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($p) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($p) }
}
function Xml([string]$s) { [Security.SecurityElement]::Escape($s) }

Write-Host ''
Write-Host 'SIGMA · desarrollo contra Azure SQL (codigocreativo / SIGMA)' -ForegroundColor Cyan
Write-Host 'OJO: segun data.config esta base es PRODUCCION desde el 08-10-2026.' -ForegroundColor Yellow
$ok = Read-Host 'Escribe SI para continuar'
if ($ok -ne 'SI') { Write-Host 'Cancelado.'; exit 1 }

$clave = Plano (Read-Host 'Contrasena del usuario sigma' -AsSecureString)
if ([string]::IsNullOrEmpty($clave)) { throw 'La contrasena no puede ir vacia.' }

# MARS queda en True: la Intranet abre lectores anidados en algunas pantallas.
$cad = "Server=tcp:codigocreativo.database.windows.net,1433;Initial Catalog=SIGMA;Persist Security Info=False;User ID=sigma;Password=$clave;MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;"

New-Item -ItemType Directory -Force $resp | Out-Null
Copy-Item $data   (Join-Path $resp "data.config.BACKUP_$sello")
Copy-Item $apiCfg (Join-Path $resp "API_Web.config.BACKUP_$sello")

# Intranet
$xml = @"
<?xml version="1.0"?>
<connectionStrings>
	<!--Desarrollo apuntando a Azure SQL (oferta gratuita). Escrito por Dev\conectar_azure.ps1 el $sello. No versionar.-->
	<add name="SIGMA" connectionString="$(Xml $cad)" />
</connectionStrings>
"@
[IO.File]::WriteAllText($data, $xml, (New-Object Text.UTF8Encoding($true)))

# API: la clave DefaultConnectionStringName de appSettings
$api = [IO.File]::ReadAllText($apiCfg)
$api = [Text.RegularExpressions.Regex]::Replace($api, '(<add key="DefaultConnectionStringName" value=")[^"]*(")', ('${1}' + (Xml $cad).Replace('$', '$$') + '${2}'))
[IO.File]::WriteAllText($apiCfg, $api, (New-Object Text.UTF8Encoding($true)))

# Que git no se lleve la contrasena
Push-Location $raiz
git update-index --skip-worktree 'Web/Intranet/data.config' 'Solucion/SIGMA/API/Web.config'
Pop-Location

Write-Host ''
Write-Host 'Indicador del cupo gratuito (opcional).' -ForegroundColor Cyan
Write-Host 'Necesita una App registration con el rol "Monitoring Reader" sobre la base SIGMA.'
$conf = Read-Host 'Configurarlo ahora? (s/n)'
if ($conf -eq 's') {
    $tenant = Read-Host 'Tenant ID (Directory ID)'
    $client = Read-Host 'Client ID (Application ID)'
    $secret = Plano (Read-Host 'Client secret' -AsSecureString)
    $res = '/subscriptions/af092419-a7e8-453a-b29a-8ef889109f66/resourceGroups/SIGMA/providers/Microsoft.Sql/servers/codigocreativo/databases/SIGMA'
    $cfg = @"
<?xml version="1.0"?>
<!-- Credencial de SOLO LECTURA para el indicador del cupo de Azure SQL. No versionar (.gitignore). -->
<azure tenant="$(Xml $tenant)" client="$(Xml $client)" secret="$(Xml $secret)" recurso="$(Xml $res)" limite="100000" />
"@
    [IO.File]::WriteAllText($azure, $cfg, (New-Object Text.UTF8Encoding($true)))
    Write-Host 'azure.config escrito.' -ForegroundColor Green
}

Write-Host ''
Write-Host "Listo. Respaldos en $resp (sello $sello)." -ForegroundColor Green
Write-Host 'Reinicia IIS Express para que tome la conexion nueva.'
