# =============================================================================
# SIGMA · Paso 2 — crear la maquina virtual (Windows Server)
#
# QUIEN LO CORRE: tu, como ADMINISTRADOR, despues de habilitar Hyper-V y reiniciar.
# NECESITA: la ISO de Windows Server 2022 (evaluacion de 180 dias, la descargas
# tu desde el Centro de Evaluacion de Microsoft; aceptas tu la licencia).
#
#   .\02_crear_vm.ps1 -Iso 'C:\ISO\SERVER_EVAL_x64FRE_es-es.iso'
#
# QUE CREA
#   - Un switch interno con NAT (192.168.77.0/24): la VM sale a internet por tu
#     PC y NO queda expuesta a la red de la casa/oficina. Funciona igual con
#     WiFi (un switch externo sobre WiFi da problemas).
#   - VM Generacion 2: 4 vCPU, memoria dinamica 2-6 GB (inicia en 4), disco
#     dinamico de 120 GB, sin checkpoints, arranca sola con Windows.
# =============================================================================
#Requires -RunAsAdministrator
param(
    [Parameter(Mandatory = $true)][string]$Iso,
    [string]$Nombre = 'SIGMA-SRV',
    [string]$Ruta = 'C:\HyperV',
    [int]$MemInicioGB = 4,
    [int]$MemMaxGB = 6,
    [int]$Cpu = 4,
    [int]$DiscoGB = 120,
    [string]$Red = '192.168.77'
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Iso)) { throw "No existe la ISO: $Iso" }
if (-not (Get-Command New-VM -ErrorAction SilentlyContinue)) {
    throw 'Hyper-V no esta habilitado todavia: corre 01_habilitar_hyperv.ps1 y reinicia.'
}
if (Get-VM -Name $Nombre -ErrorAction SilentlyContinue) { throw "Ya existe una VM llamada $Nombre." }

# ---------------------------------------------------------------- red interna + NAT
$sw = 'SIGMA-NAT'
if (-not (Get-VMSwitch -Name $sw -ErrorAction SilentlyContinue)) {
    New-VMSwitch -Name $sw -SwitchType Internal | Out-Null
}
$nic = Get-NetAdapter | Where-Object { $_.Name -like "*($sw)*" } | Select-Object -First 1
if (-not (Get-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress "$Red.1" -ErrorAction SilentlyContinue)) {
    New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress "$Red.1" -PrefixLength 24 | Out-Null
}
if (-not (Get-NetNat -Name $sw -ErrorAction SilentlyContinue)) {
    New-NetNat -Name $sw -InternalIPInterfaceAddressPrefix "$Red.0/24" | Out-Null
}

# ---------------------------------------------------------------- la VM
New-Item -ItemType Directory -Force -Path (Join-Path $Ruta $Nombre) | Out-Null
$vhd = Join-Path (Join-Path $Ruta $Nombre) "$Nombre.vhdx"
New-VHD -Path $vhd -SizeBytes ($DiscoGB * 1GB) -Dynamic | Out-Null
New-VM -Name $Nombre -Generation 2 -MemoryStartupBytes ($MemInicioGB * 1GB) -VHDPath $vhd -SwitchName $sw -Path $Ruta | Out-Null
Set-VMMemory -VMName $Nombre -DynamicMemoryEnabled $true -MinimumBytes 2GB -StartupBytes ($MemInicioGB * 1GB) -MaximumBytes ($MemMaxGB * 1GB)
Set-VMProcessor -VMName $Nombre -Count $Cpu
Set-VM -Name $Nombre -CheckpointType Disabled -AutomaticStopAction ShutDown -AutomaticStartAction Start -AutomaticStartDelay 30
# Por Id, no por nombre: en Windows en espanol el servicio se llama distinto.
Get-VMIntegrationService -VMName $Nombre | Where-Object { $_.Id -match '6C09BB55-D683-4DA0-8931-C9BF705F6480' } | Enable-VMIntegrationService
Add-VMDvdDrive -VMName $Nombre -Path $Iso
Set-VMFirmware -VMName $Nombre -FirstBootDevice (Get-VMDvdDrive -VMName $Nombre)
Start-VM -Name $Nombre

Write-Host ''
Write-Host "VM $Nombre creada y encendida." -ForegroundColor Green
Write-Host 'AHORA, en la consola de la VM (se abre sola; si no: vmconnect localhost ' $Nombre ')' -ForegroundColor Yellow
Write-Host '  1. Pulsa una tecla cuando diga "Press any key to boot from CD or DVD".'
Write-Host '  2. Instala "Windows Server 2022 Standard (Experiencia de escritorio)".'
Write-Host '  3. Define la clave de Administrador (guardala tu; no la compartas por chat).'
Write-Host "  4. Dentro de la VM corre 03_configurar_servidor.ps1 (como administrador)."
Start-Process vmconnect.exe -ArgumentList 'localhost', $Nombre
