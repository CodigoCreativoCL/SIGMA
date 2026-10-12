# =====================================================================
#  SIGMA · Ejecuta SQL contra la base de Web/Intranet/data.config con
#  System.Data.SqlClient (lo mismo que usa la Intranet). No necesita sqlcmd
#  ni muestra la contraseña.
#
#  Uso:
#    powershell -File Dev\sql.ps1 -Consulta "SELECT DB_NAME()"
#    powershell -File Dev\sql.ps1 -Archivo BD\432_OT_FICHA_V8.sql
#  El archivo se parte en lotes por las líneas «GO» (como sqlcmd).
# =====================================================================
param([string]$Consulta, [string]$Archivo, [int]$Espera = 180)
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
[xml]$cfg = [IO.File]::ReadAllText((Join-Path $raiz 'Web\Intranet\data.config'))
$cadena = ($cfg.connectionStrings.add | Where-Object { $_.name -eq 'SIGMA' }).connectionString
$b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder($cadena)
$b['Connect Timeout'] = $Espera   # una base sin servidor en pausa tarda en despertar
$cn = New-Object System.Data.SqlClient.SqlConnection($b.ConnectionString)
$cn.add_InfoMessage({ param($s, $e) Write-Host $e.Message })
$cn.Open()
Write-Host ("Conectado a " + $b.DataSource + " / " + $b.InitialCatalog)

function Lote([string]$sql) {
    if ([string]::IsNullOrWhiteSpace($sql)) { return }
    $cmd = $cn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 600
    $rd = $cmd.ExecuteReader()
    do {
        if ($rd.FieldCount -gt 0) {
            $cols = 0..($rd.FieldCount - 1) | ForEach-Object { $rd.GetName($_) }
            Write-Host ($cols -join ' | ')
            while ($rd.Read()) { Write-Host ((0..($rd.FieldCount - 1) | ForEach-Object { $rd.GetValue($_) }) -join ' | ') }
        }
    } while ($rd.NextResult())
    $rd.Close()
}

try {
    if ($Consulta) { Lote $Consulta }
    if ($Archivo) {
        $txt = [IO.File]::ReadAllText((Resolve-Path $Archivo))
        $lotes = [Text.RegularExpressions.Regex]::Split($txt, '^\s*GO\s*;?\s*$', 'Multiline, IgnoreCase')
        $n = 0
        foreach ($l in $lotes) {
            $sql = [Text.RegularExpressions.Regex]::Replace($l, '^\s*USE\s+\[?[\w]+\]?\s*;?\s*$', '', 'Multiline, IgnoreCase')
            if ($sql.Trim().Length -eq 0) { continue }
            $n++
            try { Lote $sql } catch { Write-Host ("ERROR en el lote " + $n + ": " + $_.Exception.InnerException.Message + $_.Exception.Message) -ForegroundColor Red; exit 1 }
        }
        Write-Host ("OK " + (Split-Path -Leaf $Archivo) + " · " + $n + " lotes") -ForegroundColor Green
    }
} finally { $cn.Close() }
