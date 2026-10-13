# =============================================================================
# SIGMA · Migracion por fases de la base (VM -> HostChile)
#
# ORIGEN : la base SIGMA del SQL Server de la VM (rapida: misma maquina, sin latencia).
# DESTINO: la base "sigma" de HostChile (usuario sigma, que puede crear objetos).
#
# QUIEN LO CORRE: tu, en tu PC, SIN administrador, con la VM encendida.
# Pide dos claves ocultas (sa de la VM y la del usuario sigma de HostChile). No se guardan.
#
# CARGA UNICA:  -Fase Todo  (hace las 8 etapas en orden, pidiendo las claves una sola vez)
# ORDEN RECOMENDADO: Funciones, Tablas, Funciones (otra vez), Datos, Vistas, Procedimientos, Llaves, Verificar.
#   (los DEFAULT de varias tablas llaman funciones, y algunas funciones leen tablas: por eso se repite Funciones)
# FASES (cada una se puede repetir: salta lo que ya existe)
#   Tablas          esquemas, tipos y tablas (con PK, unicos, defaults, checks e indices; SIN llaves foraneas)
#   Datos           copia las filas con SqlBulkCopy (conserva identidades); salta tablas que ya tienen filas
#   Funciones       funciones escalares y de tabla
#   Vistas          vistas (varias pasadas: algunas dependen de otras)
#   Procedimientos  procedimientos almacenados (varias pasadas)
#   Llaves          llaves foraneas y triggers
#   Verificar       compara conteos contra la base de la VM
# Si algo falla por dependencias (p. ej. una tabla cuyo DEFAULT usa una funcion), repite esa fase
# despues de crear las funciones.
#
#   powershell -ExecutionPolicy Bypass -File .\06_migrar_a_hostchile.ps1 -Fase Tablas
# =============================================================================
param(
    [Parameter(Mandatory = $true)][ValidateSet('Todo', 'Tablas', 'Datos', 'Funciones', 'Vistas', 'Procedimientos', 'Llaves', 'Verificar')][string]$Fase,
    [string]$VmIp = '192.168.77.10',
    [string]$BaseOrigen = 'SIGMA',
    [string]$Servidor = '173.248.133.222,1533',
    [string]$BaseDestino = 'sigma',
    [string]$UsuarioDestino = 'sigma',
    [string]$Registro = 'C:\HyperV\export'
)
$ErrorActionPreference = 'Stop'
$v = 'Version=15.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91'
foreach ($a in 'Microsoft.SqlServer.Smo', 'Microsoft.SqlServer.ConnectionInfo', 'Microsoft.SqlServer.SqlEnum', 'Microsoft.SqlServer.Management.Sdk.Sfc') { Add-Type -AssemblyName "$a, $v" }

function Plano([Security.SecureString]$s) { [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)) }

$sa = Plano (Read-Host 'Clave de sa del SQL Server de la VM' -AsSecureString)
$dest = Plano (Read-Host "Clave del usuario '$UsuarioDestino' de HostChile" -AsSecureString)
New-Item -ItemType Directory -Force -Path $Registro | Out-Null
$logPath = Join-Path $Registro ("migracion_{0}_{1}.log" -f $Fase, (Get-Date -Format 'yyyyMMdd_HHmm'))
function Log($m) { Add-Content -Path $logPath -Value $m -Encoding UTF8 }

# ---- origen (SMO) y origen (SqlClient)
$conn = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
$conn.ServerInstance = $VmIp; $conn.LoginSecure = $false; $conn.Login = 'sa'; $conn.Password = $sa
$conn.EncryptConnection = $true; $conn.TrustServerCertificate = $true; $conn.StatementTimeout = 600
$srv = New-Object Microsoft.SqlServer.Management.Smo.Server $conn
$db = $srv.Databases[$BaseOrigen]
if (-not $db) { throw "No encuentro la base $BaseOrigen en la VM." }
$csOrigen = "Server=$VmIp;Database=$BaseOrigen;User Id=sa;Password=$sa;TrustServerCertificate=True;Encrypt=True;Connect Timeout=30"

# ---- destino (SqlClient)
$csDestino = "Server=$Servidor;Database=$BaseDestino;User Id=$UsuarioDestino;Password=$dest;TrustServerCertificate=True;Encrypt=True;Connect Timeout=30"
$cnDest = New-Object System.Data.SqlClient.SqlConnection $csDestino
$cnDest.Open()
function EjecutarDestino($sql) {
    try { $cm = $cnDest.CreateCommand(); $cm.CommandText = $sql; $cm.CommandTimeout = 300; [void]$cm.ExecuteNonQuery(); return $null }
    catch { return ($_.Exception.Message -split "`n")[0].Trim() }
}
function EscalarDestino($sql) { $cm = $cnDest.CreateCommand(); $cm.CommandText = $sql; $cm.CommandTimeout = 300; return $cm.ExecuteScalar() }
function ExistentesDestino() {
    $h = New-Object 'System.Collections.Generic.HashSet[string]'
    $cm = $cnDest.CreateCommand(); $cm.CommandText = "SELECT LOWER(s.name + '.' + o.name) FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id WHERE o.is_ms_shipped = 0 AND o.parent_object_id = 0"
    $r = $cm.ExecuteReader(); while ($r.Read()) { [void]$h.Add($r.GetString(0)) }; $r.Close(); return $h
}

function NuevoScripter($conFks) {
    $s = New-Object Microsoft.SqlServer.Management.Smo.Scripter $srv
    $o = $s.Options
    $o.TargetServerVersion = [Microsoft.SqlServer.Management.Smo.SqlServerVersion]::Version150
    $o.ScriptSchema = $true; $o.ScriptData = $false; $o.ScriptDrops = $false; $o.IncludeIfNotExists = $false
    $o.SchemaQualify = $true; $o.ScriptBatchTerminator = $false; $o.AnsiPadding = $true; $o.WithDependencies = $false
    $o.ScriptOwner = $false; $o.Permissions = $false; $o.ExtendedProperties = $false
    $o.NoFileGroup = $true; $o.NoTablePartitioningSchemes = $true; $o.NoIndexPartitioningSchemes = $true
    $o.DriPrimaryKey = $true; $o.DriUniqueKeys = $true; $o.DriDefaults = $true; $o.DriChecks = $true; $o.DriForeignKeys = $conFks
    $o.Indexes = $true; $o.ClusteredIndexes = $true; $o.NonClusteredIndexes = $true; $o.Triggers = $false
    $o.NoCollation = $false
    return $s
}

# Crea un grupo de objetos con varias pasadas. Devuelve @{ Creados; Existian; Fallaron }
# Si una TABLA falla a medias (p. ej. su DEFAULT usa una funcion que aun no existe), se borra para
# que la proxima pasada o fase la cree completa desde cero.
function CrearObjetos($objetos, $etiqueta, $conFks, $pasadas) {
    $scr = NuevoScripter $conFks
    $existen = ExistentesDestino
    $pend = New-Object System.Collections.Generic.List[object]
    $existian = 0
    foreach ($o in $objetos) {
        if ($existen.Contains(("{0}.{1}" -f $o.Schema, $o.Name).ToLower())) { $existian++ } else { $pend.Add($o) }
    }
    $creados = 0
    $errores = @{}
    for ($p = 1; $p -le $pasadas -and $pend.Count -gt 0; $p++) {
        $siguen = New-Object System.Collections.Generic.List[object]
        $antes = $creados
        $n = 0
        foreach ($o in $pend) {
            $n++
            if ($n % 100 -eq 0) { Write-Host ("   pasada {0}: {1}/{2}" -f $p, $n, $pend.Count) }
            $clave = "{0}.{1}" -f $o.Schema, $o.Name
            $err = $null
            [void](EjecutarDestino 'SET ANSI_PADDING ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF')
            try {
                foreach ($lote in $scr.EnumScript([Microsoft.SqlServer.Management.Sdk.Sfc.Urn[]]@($o.Urn))) {
                    if ([string]::IsNullOrWhiteSpace($lote)) { continue }
                    # Indices sobre columnas calculadas o filtrados exigen ANSI_PADDING ON: SMO a veces lo apaga.
                    $lote = [regex]::Replace($lote, '(?i)SET\s+ANSI_PADDING\s+OFF', 'SET ANSI_PADDING ON')
                    $e = EjecutarDestino $lote
                    if ($e) { $err = $e; break }
                }
            } catch { $err = ($_.Exception.Message -split "`n")[0].Trim() }
            if ($err) {
                if ($o -is [Microsoft.SqlServer.Management.Smo.Table]) { [void](EjecutarDestino ("IF OBJECT_ID(N'[{0}].[{1}]') IS NOT NULL DROP TABLE [{0}].[{1}]" -f $o.Schema, $o.Name)) }
                $errores[$clave] = $err; $siguen.Add($o)
            } else { $creados++; $errores.Remove($clave) }
        }
        Write-Host ("   {0} pasada {1}: {2} creados, {3} con error" -f $etiqueta, $p, ($creados - $antes), $siguen.Count)
        $pend = $siguen
        if ($creados -eq $antes) { break }
    }
    foreach ($o in $pend) { $k = "{0}.{1}" -f $o.Schema, $o.Name; Log ("[{0}] {1}: {2}" -f $etiqueta, $k, $errores[$k]) }
    return @{ Creados = $creados; Existian = $existian; Fallaron = $pend.Count }
}

function Resumen($etiqueta, $r) {
    Write-Host ("RESULTADO {0}: {1} creados | {2} ya existian | {3} con error" -f $etiqueta, $r.Creados, $r.Existian, $r.Fallaron) -ForegroundColor $(if ($r.Fallaron -eq 0) { 'Green' } else { 'Yellow' })
    if ($r.Fallaron -gt 0) { Write-Host "   Los errores estan en: $logPath" -ForegroundColor Yellow }
}

function EjecutarFase([string]$FaseActual) {
Write-Host ("=== Fase: {0}  ({1}) ===" -f $FaseActual, (Get-Date -Format 'HH:mm:ss')) -ForegroundColor Cyan
switch ($FaseActual) {
    'Tablas' {
        Write-Host 'Esquemas, sinonimos de tipos y tipos de tabla...'
        $extra = New-Object System.Collections.Generic.List[object]
        foreach ($c in $db.Schemas) { if (-not $c.IsSystemObject -and $c.Name -ne 'dbo') { $esq = EjecutarDestino ("IF SCHEMA_ID(N'{0}') IS NULL EXEC('CREATE SCHEMA [{0}]')" -f $c.Name); if ($esq) { Log "[esquema] $($c.Name): $esq" } } }
        $scr0 = NuevoScripter $false
        foreach ($t in $db.UserDefinedDataTypes) { foreach ($l in $scr0.EnumScript([Microsoft.SqlServer.Management.Sdk.Sfc.Urn[]]@($t.Urn))) { $e = EjecutarDestino $l; if ($e -and $e -notmatch 'already|ya existe') { Log "[tipo] $($t.Name): $e" } } }
        foreach ($t in $db.UserDefinedTableTypes) { foreach ($l in $scr0.EnumScript([Microsoft.SqlServer.Management.Sdk.Sfc.Urn[]]@($t.Urn))) { $e = EjecutarDestino $l; if ($e -and $e -notmatch 'already|ya existe') { Log "[tipo tabla] $($t.Name): $e" } } }
        Write-Host ("Tablas en el origen: {0}" -f ($db.Tables | Where-Object { -not $_.IsSystemObject }).Count)
        $tablas = $db.Tables | Where-Object { -not $_.IsSystemObject }
        Resumen 'Tablas' (CrearObjetos $tablas 'tabla' $false 3)
    }
    'Datos' {
        # 0) Quitar las llaves foraneas existentes: asi se puede recargar sin conflictos. La fase Llaves las recrea.
        $cm = $cnDest.CreateCommand()
        $cm.CommandText = "SELECT 'ALTER TABLE [' + s.name + '].[' + o.name + '] DROP CONSTRAINT [' + f.name + ']' FROM sys.foreign_keys f JOIN sys.objects o ON o.object_id = f.parent_object_id JOIN sys.schemas s ON s.schema_id = o.schema_id"
        $drops = New-Object System.Collections.Generic.List[string]; $rd0 = $cm.ExecuteReader(); while ($rd0.Read()) { $drops.Add($rd0.GetString(0)) }; $rd0.Close()
        foreach ($d in $drops) { [void](EjecutarDestino $d) }
        Write-Host ("Llaves foraneas quitadas temporalmente: {0} (la fase Llaves las recrea)" -f $drops.Count)

        $tablas = $db.Tables | Where-Object { -not $_.IsSystemObject }
        $copiadas = 0; $vacias = 0; $saltadas = 0; $parciales = 0; $fallas = 0; $filas = 0
        $cnOrigen = New-Object System.Data.SqlClient.SqlConnection $csOrigen; $cnOrigen.Open()
        foreach ($t in $tablas) {
            $nombre = "[{0}].[{1}]" -f $t.Schema, $t.Name
            $rd = $null; $cnT = $null
            try {
                $cm = $cnOrigen.CreateCommand(); $cm.CommandText = "SELECT COUNT_BIG(*) FROM $nombre"; $nOrigen = [int64]$cm.ExecuteScalar()
                if ($nOrigen -eq 0) { $vacias++; continue }
                $nDest = [int64](EscalarDestino "SELECT COUNT_BIG(*) FROM $nombre")
                if ($nDest -eq $nOrigen) { $saltadas++; continue }
                if ($nDest -gt 0) {
                    $e = EjecutarDestino "DELETE FROM $nombre"
                    if ($e) { throw "no pude vaciar la carga parcial: $e" }
                    $parciales++
                }
                $cm.CommandText = "SELECT c.name FROM sys.columns c JOIN sys.types ty ON ty.user_type_id = c.user_type_id WHERE c.object_id = OBJECT_ID(N'$nombre') AND c.is_computed = 0 AND ty.name <> 'timestamp' ORDER BY c.column_id"
                $cols = New-Object System.Collections.Generic.List[string]; $r1 = $cm.ExecuteReader(); while ($r1.Read()) { $cols.Add($r1.GetString(0)) }; $r1.Close()
                $lista = ($cols | ForEach-Object { "[$_]" }) -join ','
                $cm.CommandText = "SELECT $lista FROM $nombre"; $cm.CommandTimeout = 0
                $rd = $cm.ExecuteReader([System.Data.CommandBehavior]::SequentialAccess)
                # Conexion NUEVA por tabla: si una carga se corta, no deja IDENTITY_INSERT encendido para las demas.
                $cnT = New-Object System.Data.SqlClient.SqlConnection $csDestino; $cnT.Open()
                $opt = [System.Data.SqlClient.SqlBulkCopyOptions]::KeepIdentity -bor [System.Data.SqlClient.SqlBulkCopyOptions]::KeepNulls
                $bc = New-Object System.Data.SqlClient.SqlBulkCopy($cnT, $opt, $null)
                $bc.DestinationTableName = $nombre; $bc.BatchSize = 2000; $bc.BulkCopyTimeout = 0; $bc.EnableStreaming = $true
                foreach ($c in $cols) { [void]$bc.ColumnMappings.Add($c, $c) }
                $bc.WriteToServer($rd); $rd.Close(); $cnT.Close()
                $copiadas++; $filas += $nOrigen
                if ($copiadas % 25 -eq 0) { Write-Host ("   {0} tablas copiadas ({1} filas)..." -f $copiadas, $filas) }
            } catch {
                $fallas++
                Log ("[datos] {0}: {1}" -f $nombre, ($_.Exception.Message -split "`n")[0].Trim())
                try { if ($rd) { $rd.Close() } } catch { }
                try { if ($cnT) { $cnT.Close() } } catch { }
            }
        }
        $cnOrigen.Close()
        Write-Host ("RESULTADO Datos: {0} tablas copiadas ({1} filas, {2} eran cargas parciales rehechas) | {3} vacias | {4} ya estaban completas | {5} con error" -f $copiadas, $filas, $parciales, $vacias, $saltadas, $fallas) -ForegroundColor $(if ($fallas -eq 0) { 'Green' } else { 'Yellow' })
        if ($fallas -gt 0) { Write-Host "   Errores en: $logPath" -ForegroundColor Yellow }
        Write-Host 'Siguiente: fase Llaves y luego Verificar.'
    }
    'Funciones' { Resumen 'Funciones' (CrearObjetos ($db.UserDefinedFunctions | Where-Object { -not $_.IsSystemObject }) 'funcion' $false 4) }
    'Vistas' { Resumen 'Vistas' (CrearObjetos ($db.Views | Where-Object { -not $_.IsSystemObject }) 'vista' $false 5) }
    'Procedimientos' { Resumen 'Procedimientos' (CrearObjetos ($db.StoredProcedures | Where-Object { -not $_.IsSystemObject }) 'procedimiento' $false 4) }
    'Llaves' {
        $nfk = 0; $err = 0; $ntr = 0
        $existentes = New-Object 'System.Collections.Generic.HashSet[string]'
        $cm = $cnDest.CreateCommand(); $cm.CommandText = 'SELECT LOWER(name) FROM sys.foreign_keys'; $r = $cm.ExecuteReader(); while ($r.Read()) { [void]$existentes.Add($r.GetString(0)) }; $r.Close()
        foreach ($t in ($db.Tables | Where-Object { -not $_.IsSystemObject })) {
            foreach ($fk in $t.ForeignKeys) {
                if ($existentes.Contains($fk.Name.ToLower())) { continue }
                $ok = $true
                foreach ($l in $fk.Script()) { $e = EjecutarDestino $l; if ($e) { $ok = $false; Log ("[fk] {0}.{1} {2}: {3}" -f $t.Schema, $t.Name, $fk.Name, $e); break } }
                if ($ok) { $nfk++ } else { $err++ }
            }
        }
        Write-Host ("Llaves foraneas: {0} creadas | {1} con error" -f $nfk, $err) -ForegroundColor $(if ($err -eq 0) { 'Green' } else { 'Yellow' })
        $scr = NuevoScripter $false; $scr.Options.Triggers = $false
        foreach ($t in ($db.Tables | Where-Object { -not $_.IsSystemObject })) {
            foreach ($tr in $t.Triggers) {
                $ya = EscalarDestino ("SELECT COUNT(*) FROM sys.triggers WHERE name = N'{0}'" -f $tr.Name.Replace("'", "''"))
                if ($ya -gt 0) { continue }
                foreach ($l in $tr.Script()) { if ([string]::IsNullOrWhiteSpace($l)) { continue }; $e = EjecutarDestino $l; if ($e) { Log ("[trigger] {0}.{1} {2}: {3}" -f $t.Schema, $t.Name, $tr.Name, $e) } }
                $ntr++
            }
        }
        Write-Host ("Triggers creados: {0}" -f $ntr) -ForegroundColor Green
        if (Test-Path $logPath) { Write-Host "   Errores en: $logPath" -ForegroundColor Yellow }
    }
    'Verificar' {
        $consulta = "SELECT (SELECT COUNT(*) FROM sys.tables) AS tablas, (SELECT COUNT(*) FROM sys.procedures) AS procedimientos, (SELECT COUNT(*) FROM sys.views) AS vistas, (SELECT COUNT(*) FROM sys.objects WHERE type IN ('FN','IF','TF')) AS funciones, (SELECT COUNT(*) FROM sys.foreign_keys) AS fks, (SELECT COUNT(*) FROM sys.triggers WHERE parent_class = 1) AS triggers"
        $o = New-Object System.Data.SqlClient.SqlConnection $csOrigen; $o.Open()
        function Fila($cn) { $cm = $cn.CreateCommand(); $cm.CommandText = $consulta; $dt = New-Object System.Data.DataTable; $dt.Load($cm.ExecuteReader()); return $dt.Rows[0] }
        $a = Fila $o; $b = Fila $cnDest; $o.Close()
        foreach ($c in 'tablas', 'procedimientos', 'vistas', 'funciones', 'fks', 'triggers') {
            $col = if ($a[$c] -eq $b[$c]) { 'Green' } else { 'Yellow' }
            Write-Host ("  {0,-15} origen {1,5} | HostChile {2,5}" -f $c, $a[$c], $b[$c]) -ForegroundColor $col
        }
        $sqlFilas = "SELECT SUM(p.rows) FROM sys.partitions p JOIN sys.tables t ON t.object_id = p.object_id WHERE p.index_id IN (0,1)"
        $o = New-Object System.Data.SqlClient.SqlConnection $csOrigen; $o.Open()
        $cm = $o.CreateCommand(); $cm.CommandText = $sqlFilas; $fo = $cm.ExecuteScalar(); $o.Close()
        $fd = EscalarDestino $sqlFilas
        Write-Host ("  {0,-15} origen {1,5} | HostChile {2,5}" -f 'filas', $fo, $fd) -ForegroundColor $(if ($fo -eq $fd) { 'Green' } else { 'Yellow' })
        # comparacion tabla por tabla
        $porTabla = "SELECT s.name + '.' + t.name AS n, SUM(p.rows) AS f FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1) GROUP BY s.name, t.name"
        function Mapa($cn) { $h = @{}; $cm = $cn.CreateCommand(); $cm.CommandText = $porTabla; $cm.CommandTimeout = 300; $r = $cm.ExecuteReader(); while ($r.Read()) { $h[$r.GetString(0).ToLower()] = [int64]$r.GetInt64(1) }; $r.Close(); return $h }
        $o = New-Object System.Data.SqlClient.SqlConnection $csOrigen; $o.Open(); $mo = Mapa $o; $o.Close()
        $md = Mapa $cnDest
        $dif = New-Object System.Collections.Generic.List[string]
        foreach ($k in ($mo.Keys | Sort-Object)) {
            $x = $mo[$k]; $y = if ($md.ContainsKey($k)) { $md[$k] } else { -1 }
            if ($x -ne $y) { $dif.Add(("{0}: origen {1} | HostChile {2}" -f $k, $x, $(if ($y -lt 0) { 'NO EXISTE' } else { $y }))) }
        }
        if ($dif.Count -eq 0) { Write-Host '  Todas las tablas tienen exactamente las mismas filas que el origen.' -ForegroundColor Green }
        else {
            Write-Host ("  {0} tablas con diferencias (primeras 40):" -f $dif.Count) -ForegroundColor Yellow
            $dif | Select-Object -First 40 | ForEach-Object { Write-Host "    $_" }
            $dif | ForEach-Object { Log "[verificar] $_" }
        }
    }
}
}

# ---- ejecucion: una fase, o TODO en el orden correcto con una sola carga
if ($Fase -eq 'Todo') { $orden = 'Funciones', 'Tablas', 'Funciones', 'Datos', 'Vistas', 'Procedimientos', 'Llaves', 'Verificar' } else { $orden = @($Fase) }
foreach ($f in $orden) { EjecutarFase $f }
$cnDest.Close(); $sa = $null; $dest = $null
Write-Host "Registro de errores (si hubo): $logPath"
