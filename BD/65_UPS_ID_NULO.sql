/* ============================================================================
   SIGMA — Bloque 65
   EL SELECT QUE NO ENCUENTRA NADA Y NO TOCA LA VARIABLE
   ----------------------------------------------------------------------------

   LA TRAMPA

     En SQL Server, esto NO deja @ID en NULL cuando no hay filas:

         SELECT @ID = rbs_id FROM Repuesto_Bodega_Stock WHERE ...

     Si la consulta no devuelve nada, @ID **conserva el valor que ya tenia**.
     Es una de las diferencias mas silenciosas del lenguaje: uno lee la linea
     y asume "si no existe, queda NULL", y no es asi.

   POR QUE IMPORTA ACA

     Los controllers de la web crean el parametro de salida asi:

         int id = 0;
         cmd.Parameters.AddWithValue("@ID", id).Direction = Output;

     O sea que @ID entra valiendo **0**, no NULL. Entonces:

       UPS_REPUESTO_BODEGA_STOCK
         SELECT no encuentra -> @ID sigue en 0 -> no es NULL -> se va por la
         rama del UPDATE ... WHERE rbs_id = 0 -> **cero filas afectadas**.
         Guardar los umbrales desde la ficha del repuesto no hacia NADA, y
         no mostraba ningun error.

       INS_REPUESTO_LOTE
         SELECT no encuentra -> @ID sigue en 0 -> "El lote ya existia" y
         devuelve id 0. El movimiento posterior apuntaria al lote 0 y
         reventaria por clave foranea.

       INS_INVENTARIO_MOVIMIENTO
         La idempotencia por uuid: @ID en 0 -> "El movimiento ya estaba
         registrado" -> **no se guarda nada y nadie se entera**. Hoy no
         explota porque la web no manda uuid y Datos.Ejecutar de la API crea
         el parametro sin valor -manda NULL-, pero es una mina: basta que
         alguien llame con uuid y con @ID en 0.

   COMO APARECIO

     Sembrando los datos de prueba del inventario (bloque 64). Las ocho
     llamadas a UPS_REPUESTO_BODEGA_STOCK dejaron **una sola fila**, con los
     valores de la ultima. Ocho llamadas, un resultado: la senal de que
     todas escribieron en el mismo id.

   EL ARREGLO

     Una linea por procedimiento: SET @ID = NULL antes del SELECT. No se
     confia en lo que mande el llamador, porque el llamador ya demostro que
     manda 0.

   LA REGLA

     Todo parametro OUTPUT que se use para decidir "existe o no existe" se
     inicializa en NULL dentro del procedimiento. Queda en
     PATRONES/ASP/CONVENCIONES.md.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. UPS_REPUESTO_BODEGA_STOCK
   ======================================================================== */
DECLARE @SQL NVARCHAR(MAX)

SET @SQL = OBJECT_DEFINITION(OBJECT_ID('dbo.UPS_REPUESTO_BODEGA_STOCK'))

IF @SQL IS NOT NULL AND @SQL NOT LIKE '%el llamador manda 0%'
BEGIN
    SET @SQL = REPLACE(@SQL,
        'SELECT @ID = rbs_id FROM [dbo].[Repuesto_Bodega_Stock]',
        '/* NULL a la fuerza: un SELECT que no encuentra filas NO toca la
           variable, y el llamador manda 0. Sin esta linea, el ELSE de mas
           abajo hace UPDATE ... WHERE rbs_id = 0 y no guarda nada. */
        SET @ID = NULL

        SELECT @ID = rbs_id FROM [dbo].[Repuesto_Bodega_Stock]')

    SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
    EXEC sp_executesql @SQL
    PRINT '--- UPS_REPUESTO_BODEGA_STOCK corregido'
END
ELSE
    PRINT '--- UPS_REPUESTO_BODEGA_STOCK ya estaba corregido'
GO


/* ========================================================================
   2. INS_REPUESTO_LOTE
   ======================================================================== */
DECLARE @SQL NVARCHAR(MAX)

SET @SQL = OBJECT_DEFINITION(OBJECT_ID('dbo.INS_REPUESTO_LOTE'))

IF @SQL IS NOT NULL AND @SQL NOT LIKE '%el llamador manda 0%'
BEGIN
    SET @SQL = REPLACE(@SQL,
        'SELECT @ID = rlo_id FROM [dbo].[Repuesto_Lote]',
        '/* NULL a la fuerza: el llamador manda 0 y sin esto el SP responde
           "el lote ya existia" para un lote que no existe. */
        SET @ID = NULL

        SELECT @ID = rlo_id FROM [dbo].[Repuesto_Lote]')

    SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
    EXEC sp_executesql @SQL
    PRINT '--- INS_REPUESTO_LOTE corregido'
END
ELSE
    PRINT '--- INS_REPUESTO_LOTE ya estaba corregido'
GO


/* ========================================================================
   3. INS_INVENTARIO_MOVIMIENTO

      Hoy no falla, pero la idempotencia por uuid es justo lo que sostiene
      que el telefono pueda reintentar sin descontar dos veces. Una mina en
      ese camino no se deja armada.
   ======================================================================== */
DECLARE @SQL NVARCHAR(MAX)

SET @SQL = OBJECT_DEFINITION(OBJECT_ID('dbo.INS_INVENTARIO_MOVIMIENTO'))

IF @SQL IS NOT NULL AND @SQL NOT LIKE '%el llamador manda 0%'
BEGIN
    SET @SQL = REPLACE(@SQL,
        'IF (@UUID IS NOT NULL)
BEGIN
    SELECT @ID = imo_id FROM [dbo].[Inventario_Movimiento] WHERE imo_uuid = @UUID',
        'IF (@UUID IS NOT NULL)
BEGIN
    /* NULL a la fuerza: un SELECT sin filas NO toca la variable, y el
       llamador manda 0. Sin esto, TODO movimiento con uuid responderia
       "ya estaba registrado" y no se guardaria nada. */
    SET @ID = NULL

    SELECT @ID = imo_id FROM [dbo].[Inventario_Movimiento] WHERE imo_uuid = @UUID')

    SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
    EXEC sp_executesql @SQL
    PRINT '--- INS_INVENTARIO_MOVIMIENTO corregido'
END
ELSE
    PRINT '--- INS_INVENTARIO_MOVIMIENTO ya estaba corregido'
GO


/* ========================================================================
   4. VERIFICACION
   ======================================================================== */
SELECT  o.name AS procedimiento,
        CASE WHEN m.definition LIKE '%el llamador manda 0%' THEN 'corregido'
             ELSE 'PENDIENTE' END AS estado
FROM    sys.sql_modules m
JOIN    sys.objects o ON o.object_id = m.object_id
WHERE   o.name IN ('UPS_REPUESTO_BODEGA_STOCK', 'INS_REPUESTO_LOTE',
                   'INS_INVENTARIO_MOVIMIENTO')
ORDER BY o.name
GO
