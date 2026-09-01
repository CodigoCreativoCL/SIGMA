/* ============================================================================
   SIGMA — Bloque 86
   QUEDARSE EN CERO NO ES LO MISMO QUE ESTAR BAJO EL MINIMO
   ----------------------------------------------------------------------------

   EL PROBLEMA

     GEN_ALERTA_INVENTARIO marcaba ALTA todo lo que estuviera bajo su minimo,
     tuviera nueve de diez o cero. Y no es lo mismo:

       Nueve de diez  -> hay que reponer, se puede planificar.
       Cero           -> la proxima orden que lo pida se detiene.

     Con la misma severidad, las dos se ven igual en la bandeja y el bodeguero
     tiene que leer cada linea para saber cual lo va a dejar parado. La
     severidad existe justamente para no tener que leerlas todas.

   LO QUE CAMBIA

     Sin existencia            -> CRITICA
     Bajo el minimo, con algo  -> ALTA
     Sobre el maximo           -> ADVERTENCIA   (no cambia)

   EL LOTE VENCIDO TAMBIEN SUBE

     Un lote vencido con existencia no es "hay que revisarlo": es material que
     NO se puede usar y que alguien puede tomar del estante sin mirar la fecha.
     Pasa a CRITICA. El que esta por vencer se queda en ADVERTENCIA, que es
     exactamente lo que es: un aviso para planificar.

   SE VUELVEN A EVALUAR LAS ABIERTAS

     Cambiar el criterio sin tocar lo ya detectado dejaria las alertas viejas
     con la severidad antigua y las nuevas con la nueva, conviviendo en la
     misma lista. Al final se recalcula lo que sigue abierto.
   ============================================================================ */

SET NOCOUNT ON
GO

DECLARE @SQL NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.GEN_ALERTA_INVENTARIO'))

IF @SQL IS NULL
BEGIN
    RAISERROR('GEN_ALERTA_INVENTARIO no existe. Ejecute antes el bloque 81.', 16, 1)
    RETURN
END

IF @SQL LIKE '%SEV_CRITICA%'
    PRINT '--- GEN_ALERTA_INVENTARIO ya distinguia el quiebre'
ELSE
BEGIN
    /* Una variable mas, junto a las que ya declara. */
    SET @SQL = REPLACE(@SQL,
        'DECLARE @SEV_ALTA INT, @SEV_ADV INT',
        'DECLARE @SEV_ALTA INT, @SEV_ADV INT, @SEV_CRITICA INT')

    SET @SQL = REPLACE(@SQL,
        'SELECT @SEV_ADV  = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = ''ADVERTENCIA''',
        'SELECT @SEV_ADV  = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = ''ADVERTENCIA''
SELECT @SEV_CRITICA = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = ''CRITICA''')

    /* Bajo el minimo: critica si no queda nada. */
    SET @SQL = REPLACE(@SQL,
        'ISNULL(sa.CANT, 0), st.rbs_stock_minimo, r.rep_unidad_medida, @SEV_ALTA',
        'ISNULL(sa.CANT, 0), st.rbs_stock_minimo, r.rep_unidad_medida,
        CASE WHEN ISNULL(sa.CANT, 0) <= 0 THEN @SEV_CRITICA ELSE @SEV_ALTA END')

    /* Y el titulo lo dice, porque el titulo es lo que se lee primero. */
    SET @SQL = REPLACE(@SQL,
        'r.rep_codigo + N'' bajo el mínimo en '' + b.bod_nombre',
        'CASE WHEN ISNULL(sa.CANT, 0) <= 0
              THEN r.rep_codigo + N'' SIN EXISTENCIA en '' + b.bod_nombre
              ELSE r.rep_codigo + N'' bajo el mínimo en '' + b.bod_nombre END')

    /* Lote vencido con existencia: material que no se puede usar y que alguien
       puede tomar del estante sin mirar la fecha. */
    SET @SQL = REPLACE(@SQL,
        'CASE WHEN l.rlo_fecha_vencimiento < CAST(GETDATE() AS DATE) THEN @SEV_ALTA ELSE @SEV_ADV END',
        'CASE WHEN l.rlo_fecha_vencimiento < CAST(GETDATE() AS DATE) THEN @SEV_CRITICA ELSE @SEV_ADV END')

    SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')

    EXEC sp_executesql @SQL
    PRINT '--- GEN_ALERTA_INVENTARIO distingue el quiebre'
END
GO


/* ========================================================================
   RECALCULAR LO QUE SIGUE ABIERTO

      Sin esto, las alertas viejas conservarian la severidad antigua y
      conviviendo con las nuevas en la misma lista: dos criterios a la vez es
      peor que un criterio malo.
   ======================================================================== */
DECLARE @CRIT INT, @ALTA INT

SELECT @CRIT = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'CRITICA'
SELECT @ALTA = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'ALTA'

;WITH SALDO AS (
    SELECT isa_cliente, isa_repuesto, isa_bodega, SUM(isa_cantidad) AS CANT
    FROM   [dbo].[Inventario_Saldo]
    GROUP BY isa_cliente, isa_repuesto, isa_bodega
)
UPDATE  a
SET     a.ale_severidad = CASE WHEN ISNULL(s.CANT, 0) <= 0 THEN @CRIT ELSE @ALTA END
FROM    [dbo].[Alerta] a
JOIN    [dbo].[Alerta_Tipo] t   ON t.alt_id = a.ale_alerta_tipo
JOIN    [dbo].[Alerta_Estado] e ON e.aet_id = a.ale_alerta_estado
LEFT JOIN SALDO s ON s.isa_cliente = a.ale_cliente
                 AND s.isa_repuesto = a.ale_repuesto
                 AND s.isa_bodega = a.ale_bodega
WHERE   t.alt_codigo = 'STOCK MINIMO'
  AND   e.aet_codigo NOT IN ('RESUELTA', 'DESCARTADA')
  AND   a.ale_habilitado = 1

PRINT '--- Alertas de stock reevaluadas: ' + LTRIM(STR(@@ROWCOUNT))

UPDATE  a
SET     a.ale_severidad = @CRIT
FROM    [dbo].[Alerta] a
JOIN    [dbo].[Alerta_Tipo] t   ON t.alt_id = a.ale_alerta_tipo
JOIN    [dbo].[Alerta_Estado] e ON e.aet_id = a.ale_alerta_estado
WHERE   t.alt_codigo = 'LOTE VENCIDO'
  AND   e.aet_codigo NOT IN ('RESUELTA', 'DESCARTADA')
  AND   a.ale_habilitado = 1

PRINT '--- Alertas de lote vencido reevaluadas: ' + LTRIM(STR(@@ROWCOUNT))
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
SELECT  a.ale_titulo, t.alt_nombre, s.sev_nombre
FROM    [dbo].[Alerta] a
JOIN    [dbo].[Alerta_Tipo] t ON t.alt_id = a.ale_alerta_tipo
LEFT JOIN [dbo].[Severidad] s ON s.sev_id = a.ale_severidad
WHERE   a.ale_cliente = 1 AND a.ale_habilitado = 1
ORDER BY ISNULL(s.sev_id, 0) DESC
GO
