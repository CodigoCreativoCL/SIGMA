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

$f = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
if ($f.State -ne 'Enabled') {
    Write-Host 'Habilitando Hyper-V (puede tardar un par de minutos)...'
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart | Out-Null
}
Write-Host ''
Write-Host 'Hyper-V esta habilitado pero FALTA REINICIAR para que funcione.' -ForegroundColor Yellow
Write-Host 'Reinicia el equipo:  shutdown /r /t 0   (guarda antes lo que tengas abierto)'
Write-Host 'Despues del reinicio, corre 02_crear_vm.ps1 (tambien como administrador).'
