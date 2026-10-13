# =============================================================================
# SIGMA · Paso 4b — sacar un .bak (SQL Server 2022) de la base SIGMA que esta en la VM
#
# POR QUE: el SQL Server de HostChile es 2022 y la base de desarrollo usa funciones de 2022
# (por ejemplo STRING_SPLIT con 3 argumentos), asi que no se puede restaurar en un SQL 2019.
# La VM tiene SQL Server 2022 Express: ahi se importa el .bacpac (paso 4) y de ahi sale este .bak,
# que Plesk puede restaurar ("Importar volcado").
#
# QUIEN LO CORRE: tu, en PowerShell COMO ADMINISTRADOR, con la VM encendida.
# Pide la clave de sa (SQL de la VM) y la del Administrador de Windows de la VM, ocultas; no se guardan.
#   .\04b_respaldo_desde_vm.ps1
# =============================================================================
#Requires -RunAsAdministrator
param(
    [string]$Usuario = 'Administrador',
    [string]$Nombre = 'SIGMA-SRV',
    [string]$VmIp = '192.168.77.10',
    [string]$Base = 'SIGMA',
    [string]$Salida = 'C:\HyperV\export'
)
$ErrorActionPreference = 'Stop'

function Plano([Security.SecureString]$s) {
    [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
}
function Sql($cadena, $texto) {
    $cn = New-Object System.Data.SqlClient.SqlConnection $cadena
    $cn.Open(); $cm = $cn.CreateCommand(); $cm.CommandText = $texto; $cm.CommandTimeout = 900
    $r = $cm.ExecuteScalar(); $cn.Close(); return $r
}

$sa = Plano (Read-Host "Clave de sa del SQL Server de la VM" -AsSecureString)
$cs = "Server=$VmIp;Database=master;User Id=sa;Password=$sa;TrustServerCertificate=True;Connect Timeout=15"

Write-Host '1) Comprobando la base en la VM...'
$ver = Sql $cs "SELECT CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(40))"
Write-Host "   SQL Server $ver"
$cuenta = Sql $cs "SELECT CAST(COUNT(*) AS varchar) + ' tablas, ' + CAST((SELECT COUNT(*) FROM [$Base].sys.procedures) AS varchar) + ' procedimientos, ' + CAST((SELECT COUNT(*) FROM [$Base].sys.views) AS varchar) + ' vistas, ' + CAST((SELECT COUNT(*) FROM [$Base].sys.objects WHERE type IN ('FN','IF','TF')) AS varchar) + ' funciones' FROM [$Base].sys.tables"
Write-Host "   En la VM: $cuenta"
Write-Host '   Meta (desarrollo): 298 tablas, 2345 procedimientos, 641 vistas, 203 funciones.' -ForegroundColor Yellow

Write-Host '2) Generando el respaldo (.bak) completo, con datos...'
$dir = Sql $cs "SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(400))"
$archivo = (Join-Path $dir 'SIGMA_hostchile.bak')
[void](Sql $cs "BACKUP DATABASE [$Base] TO DISK = N'$archivo' WITH INIT, FORMAT, CHECKSUM, STATS = 25")
[void](Sql $cs "RESTORE VERIFYONLY FROM DISK = N'$archivo' WITH CHECKSUM")
Write-Host "   Respaldo creado y verificado en la VM: $archivo" -ForegroundColor Green

Write-Host '3) Trayendo el .bak a tu PC (PowerShell Direct)...'
$cred = Get-Credential -UserName "$Nombre\$Usuario" -Message 'Administrador de la VM (el de la instalacion de Windows Server)'
$s = New-PSSession -VMName $Nombre -Credential $cred
New-Item -ItemType Directory -Force -Path $Salida | Out-Null
Copy-Item -FromSession $s -Path $archivo -Destination (Join-Path $Salida 'SIGMA_hostchile.bak') -Force
Remove-PSSession $s
$sa = $null
$f = Get-Item (Join-Path $Salida 'SIGMA_hostchile.bak')
Write-Host ("LISTO: {0}  ({1:N1} MB)" -f $f.FullName, ($f.Length / 1MB)) -ForegroundColor Green
Write-Host 'Siguiente: en Plesk, Bases de datos > sigma > Importar volcado, y sube ese archivo.'
