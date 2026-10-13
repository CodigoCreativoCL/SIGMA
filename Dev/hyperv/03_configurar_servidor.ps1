# =============================================================================
# SIGMA · Paso 3 — configurar el servidor DENTRO de la VM
#
# QUIEN LO CORRE: tu, dentro de la VM, en PowerShell COMO ADMINISTRADOR.
# Para copiarlo a la VM desde el anfitrion:
#   Copy-VMFile -Name SIGMA-SRV -SourcePath .\03_configurar_servidor.ps1 `
#               -DestinationPath C:\Temp\03_configurar_servidor.ps1 -CreateFullPath -FileSource Host
#
# QUE HACE
#   - Red fija 192.168.77.10 (la del switch NAT), zona horaria de Chile.
#   - IIS + ASP.NET 4.x, un pool "SIGMA" que no se duerme, y las aplicaciones
#     /SIGMA/Intranet y /SIGMA/Servicio/API (las mismas rutas que en desarrollo).
#   - Firewall: 80/443/1433 solo desde la red de la VM y desde Tailscale (100.64.0.0/10).
#   - SQL Server Express si le pasas el instalador (tu lo descargas y aceptas la
#     licencia con -AceptoLicenciaSql). Express limita cada base a 10 GB.
#   NO descarga nada ni guarda claves.
#
#   .\03_configurar_servidor.ps1 -InstaladorSql 'C:\Temp\SQLEXPR_x64_ENU.exe' -AceptoLicenciaSql
# =============================================================================
#Requires -RunAsAdministrator
param(
    [string]$Ip = '192.168.77.10',
    [string]$Gateway = '192.168.77.1',
    [string]$InstaladorSql,
    [switch]$AceptoLicenciaSql,
    [int]$SqlMaxMemMB = 2048,
    [string]$RutaSitios = 'C:\inetpub\SIGMA'
)
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- red y hora
$nic = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
if (-not (Get-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress $Ip -ErrorAction SilentlyContinue)) {
    Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute -InterfaceIndex $nic.ifIndex -DestinationPrefix '0.0.0.0/0' -Confirm:$false -ErrorAction SilentlyContinue
    New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress $Ip -PrefixLength 24 -DefaultGateway $Gateway | Out-Null
}
Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses '1.1.1.1', '8.8.8.8'
Set-TimeZone -Id 'Pacific SA Standard Time'
Write-Host "Red lista: $Ip" -ForegroundColor Green

# ---------------------------------------------------------------- IIS
Install-WindowsFeature Web-Server, Web-Asp-Net45, Web-Net-Ext45, Web-ISAPI-Ext, Web-ISAPI-Filter, `
    Web-Mgmt-Console, Web-Stat-Compression, Web-Dyn-Compression, Web-Http-Logging -IncludeManagementTools | Out-Null
Import-Module WebAdministration

if (-not (Test-Path 'IIS:\AppPools\SIGMA')) { New-WebAppPool -Name 'SIGMA' | Out-Null }
Set-ItemProperty 'IIS:\AppPools\SIGMA' -Name managedRuntimeVersion -Value 'v4.0'
Set-ItemProperty 'IIS:\AppPools\SIGMA' -Name managedPipelineMode -Value 'Integrated'
Set-ItemProperty 'IIS:\AppPools\SIGMA' -Name startMode -Value 'AlwaysRunning'
Set-ItemProperty 'IIS:\AppPools\SIGMA' -Name processModel.idleTimeout -Value ([TimeSpan]::Zero)
Set-ItemProperty 'IIS:\AppPools\SIGMA' -Name recycling.periodicRestart.time -Value ([TimeSpan]::Zero)

foreach ($d in @("$RutaSitios\Intranet", "$RutaSitios\Servicio\API")) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
$sitio = 'Default Web Site'
foreach ($v in @(@('SIGMA', $RutaSitios), @('SIGMA/Servicio', "$RutaSitios\Servicio"))) {
    if (-not (Get-WebVirtualDirectory -Site $sitio -Name $v[0] -ErrorAction SilentlyContinue)) {
        New-WebVirtualDirectory -Site $sitio -Name $v[0] -PhysicalPath $v[1] | Out-Null
    }
}
foreach ($a in @(@('SIGMA/Intranet', "$RutaSitios\Intranet"), @('SIGMA/Servicio/API', "$RutaSitios\Servicio\API"))) {
    if (-not (Get-WebApplication -Site $sitio -Name $a[0] -ErrorAction SilentlyContinue)) {
        New-WebApplication -Site $sitio -Name $a[0] -PhysicalPath $a[1] -ApplicationPool 'SIGMA' | Out-Null
    }
}
# La identidad del pool escribe las subidas temporales y la cache de compilacion de ASP.NET.
icacls $RutaSitios /grant 'IIS AppPool\SIGMA:(OI)(CI)M' /T | Out-Null
Write-Host 'IIS listo: /SIGMA/Intranet y /SIGMA/Servicio/API' -ForegroundColor Green

# ---------------------------------------------------------------- firewall
foreach ($p in @(@('SIGMA HTTP/HTTPS', '80,443'), @('SIGMA SQL Server', '1433'))) {
    if (-not (Get-NetFirewallRule -DisplayName $p[0] -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $p[0] -Direction Inbound -Protocol TCP -LocalPort ($p[1] -split ',') `
            -RemoteAddress '192.168.77.0/24', '100.64.0.0/10' -Action Allow | Out-Null
    }
}
Write-Host 'Firewall: solo la red de la VM y Tailscale entran a 80/443/1433.' -ForegroundColor Green

# ---------------------------------------------------------------- SQL Server Express
if ($InstaladorSql) {
    if (-not $AceptoLicenciaSql) { throw 'Para instalar SQL Server debes pasar -AceptoLicenciaSql (aceptas la licencia tu).' }
    if (-not (Test-Path -LiteralPath $InstaladorSql)) { throw "No existe el instalador: $InstaladorSql" }
    $s1 = Read-Host 'Clave para el usuario sa de SQL Server (minimo 12 caracteres)' -AsSecureString
    $s2 = Read-Host 'Repitela' -AsSecureString
    $c1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s1))
    $c2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s2))
    if ($c1 -ne $c2 -or $c1.Length -lt 12) { throw 'Las claves no coinciden o son muy cortas.' }
    Write-Host 'Instalando SQL Server (varios minutos)...'
    & $InstaladorSql /Q /ACTION=Install /FEATURES=SQLENGINE /INSTANCENAME=MSSQLSERVER /SECURITYMODE=SQL "/SAPWD=$c1" `
        '/SQLSYSADMINACCOUNTS=BUILTIN\Administrators' /TCPENABLED=1 /IACCEPTSQLSERVERLICENSETERMS | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "El instalador de SQL Server termino con codigo $LASTEXITCODE (revisa C:\Program Files\Microsoft SQL Server\*\Setup Bootstrap\Log)." }
    # Tope de memoria para que no se coma la de la VM (y la de tu PC).
    $cn = New-Object System.Data.SqlClient.SqlConnection "Server=localhost;User Id=sa;Password=$c1;TrustServerCertificate=True"
    $cn.Open()
    foreach ($q in @("EXEC sp_configure 'show advanced options',1; RECONFIGURE;", "EXEC sp_configure 'max server memory (MB)',$SqlMaxMemMB; RECONFIGURE;")) {
        $cm = $cn.CreateCommand(); $cm.CommandText = $q; [void]$cm.ExecuteNonQuery()
    }
    $cn.Close()
    $c1 = $null; $c2 = $null
    Write-Host "SQL Server listo (memoria maxima $SqlMaxMemMB MB)." -ForegroundColor Green
} else {
    Write-Host 'SQL Server no se instalo: vuelve a correr con -InstaladorSql <ruta> -AceptoLicenciaSql cuando tengas el instalador.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Siguiente: instala Tailscale dentro de la VM (para que Emilio y Catalina entren) y corre 04_exportar_bd.ps1 en tu PC.' -ForegroundColor Yellow
