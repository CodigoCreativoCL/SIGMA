# =============================================================================
# SIGMA · Paso 1 — habilitar Hyper-V en el equipo anfitrion
#
# QUIEN LO CORRE: tu, en PowerShell COMO ADMINISTRADOR (cambia una caracteristica
# de Windows y pide reiniciar; por eso no se automatiza desde Claude).
# =============================================================================
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$f = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
if ($f.State -eq 'Enabled') {
    Write-Host 'Hyper-V ya esta habilitado. Sigue con 02_crear_vm.ps1.' -ForegroundColor Green
    exit 0
}

Write-Host 'Habilitando Hyper-V (puede tardar un par de minutos)...'
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart | Out-Null
Write-Host ''
Write-Host 'Listo. REINICIA el equipo para terminar:  shutdown /r /t 0' -ForegroundColor Yellow
Write-Host 'Despues del reinicio, corre 02_crear_vm.ps1 (tambien como administrador).'
