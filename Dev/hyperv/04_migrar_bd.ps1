# =============================================================================
# SIGMA · Paso 4 — llevar la base de datos de desarrollo a la VM
#
# QUIEN LO CORRE: tu, en tu PC (anfitrion). No hace falta ser administrador.
# NECESITA: sqlpackage (ya lo tienes: dotnet tool) y la VM con SQL Server listo (paso 3).
#
# QUE HACE
#   1. Exporta la base actual (la de MonsterASP, tomando la conexion de
#      Web\Intranet\data.config sin mostrarla) a un .bacpac.
#   2. La importa en el SQL Server de la VM, base "SIGMA", desde tu PC por la red NAT.
#   3. Crea el usuario de aplicacion sigma_app (db_owner de SIGMA) para que la web y la
#      API NO usen "sa".
#   Las claves las escribes aqui (se piden ocultas); nada se guarda ni se muestra.
#
#   .\04_migrar_bd.ps1                 # todo
#   .\04_migrar_bd.ps1 -SoloExportar   # solo el .bacpac
# NOTA: sqlpackage recibe las claves como argumento: durante unos minutos son visibles
# para otros procesos de TU sesion. Es tu equipo, pero no lo dejes corriendo desatendido.
# =============================================================================
param(
    [string]$VmIp = '192.168.77.10',
    [string]$Salida = 'C:\HyperV\export',
    [string]$BaseDestino = 'SIGMA',
    [switch]$SoloExportar,
    [string]$Bacpac
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Plano([Security.SecureString]$s) {
    [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
}
function Sql($cadena, $texto) {
    $cn = New-Object System.Data.SqlClient.SqlConnection $cadena
    $cn.Open(); $cm = $cn.CreateCommand(); $cm.CommandText = $texto; $cm.CommandTimeout = 120
    [void]$cm.ExecuteNonQuery(); $cn.Close()
}

$sqlpackage = (Get-Command sqlpackage -ErrorAction SilentlyContinue).Source
if (-not $sqlpackage) { throw 'No encuentro sqlpackage (dotnet tool install -g microsoft.sqlpackage).' }

# ---------------------------------------------------------------- 1. exportar (o usar un .bacpac ya hecho con -Bacpac)
if ($Bacpac) {
    if (-not (Test-Path $Bacpac)) { throw "No existe $Bacpac" }
    $bacpac = $Bacpac
    Write-Host "Usando el .bacpac existente: $bacpac"
} else {
    $xml = [xml](Get-Content (Join-Path $repo 'Web\Intranet\data.config') -Raw)
    $origen = ($xml.connectionStrings.add | Where-Object name -eq 'SIGMA').connectionString
    New-Item -ItemType Directory -Force -Path $Salida | Out-Null
    $bacpac = Join-Path $Salida ('SIGMA-' + (Get-Date -Format 'yyyyMMdd-HHmm') + '.bacpac')
    Write-Host 'Exportando la base de desarrollo (puede tardar; depende del tamano y de la distancia)...'
    & $sqlpackage /Action:Export "/SourceConnectionString:$origen" "/TargetFile:$bacpac" /p:VerifyExtraction=False | Select-Object -Last 3
    if ($LASTEXITCODE -ne 0) { throw "La exportacion fallo (codigo $LASTEXITCODE)." }
    Write-Host ("Exportado: {0} ({1:N0} MB)" -f $bacpac, ((Get-Item $bacpac).Length / 1MB)) -ForegroundColor Green
    if ($SoloExportar) { exit 0 }
}

# ---------------------------------------------------------------- 2. importar en la VM
$sa = Plano (Read-Host 'Clave de sa del SQL Server de la VM' -AsSecureString)
$admin = "Server=$VmIp;Database=master;User Id=sa;Password=$sa;TrustServerCertificate=True;Connect Timeout=15"
Sql $admin 'SELECT 1'   # falla rapido si la VM o el firewall no responden
Write-Host 'Importando en la VM...'
& $sqlpackage /Action:Import "/SourceFile:$bacpac" "/TargetConnectionString:Server=$VmIp;Database=$BaseDestino;User Id=sa;Password=$sa;TrustServerCertificate=True" | Select-Object -Last 3
if ($LASTEXITCODE -ne 0) { throw "La importacion fallo (codigo $LASTEXITCODE). Express limita cada base a 10 GB." }

# ---------------------------------------------------------------- 3. usuario de aplicacion
$app = Plano (Read-Host 'Clave para el usuario de aplicacion sigma_app (la usaras en el paso 5)' -AsSecureString)
$q = @"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'sigma_app')
    CREATE LOGIN [sigma_app] WITH PASSWORD = N'$($app.Replace("'", "''"))', CHECK_POLICY = OFF;
ELSE
    ALTER LOGIN [sigma_app] WITH PASSWORD = N'$($app.Replace("'", "''"))';
"@
Sql $admin $q
Sql "Server=$VmIp;Database=$BaseDestino;User Id=sa;Password=$sa;TrustServerCertificate=True" @"
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'sigma_app') CREATE USER [sigma_app] FOR LOGIN [sigma_app];
ALTER ROLE db_owner ADD MEMBER [sigma_app];
"@
$sa = $null; $app = $null
Write-Host "Base $BaseDestino lista en la VM con el usuario sigma_app." -ForegroundColor Green
Write-Host 'Siguiente: 05_publicar.ps1'
