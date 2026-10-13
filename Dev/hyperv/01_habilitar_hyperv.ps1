# =============================================================================
# SIGMA · Paso 1 — habilitar Hyper-V en el equipo anfitrion
#
# QUIEN LO CORRE: tu, en PowerShell COMO ADMINISTRADOR (cambia una caracteristica
# de Windows y pide reiniciar; por eso no se automatiza desde Claude).
# =============================================================================
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

# "Habilitado" no basta: hasta reiniciar no existe el servicio vmms ni el cmdlet New-VM.
$listo = (Get-Service vmms -ErrorAction SilentlyContinue) -and (Get-Command New-VM -ErrorAction SilentlyContinue)
if ($listo) {
    Write-Host 'Hyper-V esta habilitado y funcionando. Sigue con 02_crear_vm.ps1.' -ForegroundColor Green
    exit 0
}

# Ojo: "Microsoft-Hyper-V-All" puede figurar Enabled mientras sus piezas reales
# (hipervisor, servicios, herramientas de PowerShell) siguen deshabilitadas. Se
# habilita cada pieza por nombre.
$piezas = 'Microsoft-Hyper-V', 'Microsoft-Hyper-V-Hypervisor', 'Microsoft-Hyper-V-Services',
          'Microsoft-Hyper-V-Management-Clients', 'Microsoft-Hyper-V-Management-PowerShell'
foreach ($n in $piezas) {
    $f = Get-WindowsOptionalFeature -Online -FeatureName $n -ErrorAction SilentlyContinue
    if ($f -and $f.State -ne 'Enabled') {
        Write-Host "Habilitando $n ..."
        Enable-WindowsOptionalFeature -Online -FeatureName $n -All -NoRestart | Out-Null
    }
}
Write-Host ''
Write-Host 'Hyper-V esta habilitado pero FALTA REINICIAR para que funcione.' -ForegroundColor Yellow
Write-Host 'Reinicia el equipo:  shutdown /r /t 0   (guarda antes lo que tengas abierto)'
Write-Host 'Despues del reinicio, corre 02_crear_vm.ps1 (tambien como administrador).'
