/* ============================================================================
   SIGMA — Bloque 69
   FILTRAR LOS MOVIMIENTOS POR QUIEN LOS REGISTRO
   ----------------------------------------------------------------------------

   SEL_INVENTARIO_MOVIMIENTO ya filtraba por repuesto, bodega, tipo y rango
   de fechas. Faltaba por PERSONA, que es la pregunta de auditoria mas comun
   despues de "que paso con este repuesto": **quien hizo estos ajustes**.

   POR QUE UN SP APARTE PARA LA LISTA DE USUARIOS

     El combo podria llenarse con todos los usuarios del cliente. Serian
     decenas, y de esas casi ninguna toco nunca el inventario: el
     planificador, el prevencionista, los tecnicos que no son bodegueros.
     Un combo con cuarenta nombres donde solo tres sirven es un combo que
     nadie usa.

     SEL_INVENTARIO_MOVIMIENTO_USUARIO devuelve **solo quienes registraron
     al menos un movimiento**, con cuantos lleva cada uno. La lista se arma
     sola y se mantiene sola.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. @USUARIO en SEL_INVENTARIO_MOVIMIENTO
   ======================================================================== */
DECLARE @SQL NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.SEL_INVENTARIO_MOVIMIENTO'))

IF @SQL IS NOT NULL AND @SQL NOT LIKE '%@USUARIO%'
BEGIN
    SET @SQL = REPLACE(@SQL,
        '    @FILTRO      NVARCHAR(200) = NULL
AS',
        '    @FILTRO      NVARCHAR(200) = NULL,
    @USUARIO     INT = NULL
AS')

    SET @SQL = REPLACE(@SQL,
        '      AND   (@FILTRO IS NULL OR r.rep_codigo LIKE ''%'' + @FILTRO + ''%''',
        '      AND   (@USUARIO IS NULL OR m.imo_usuario_creacion = @USUARIO)
      AND   (@FILTRO IS NULL OR r.rep_codigo LIKE ''%'' + @FILTRO + ''%''')

    SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
    EXEC sp_executesql @SQL
    PRINT '--- SEL_INVENTARIO_MOVIMIENTO acepta @USUARIO'
END
ELSE
    PRINT '--- SEL_INVENTARIO_MOVIMIENTO ya aceptaba @USUARIO'
GO


/* ========================================================================
   2. QUIENES HAN REGISTRADO MOVIMIENTOS

      Se ordena por cantidad y no alfabeticamente: quien mas movimientos
      registra es el bodeguero, y es el que se va a buscar nueve de cada
      diez veces. Ponerlo primero ahorra recorrer la lista.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_INVENTARIO_MOVIMIENTO_USUARIO') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_INVENTARIO_MOVIMIENTO_USUARIO]
GO

CREATE PROCEDURE [dbo].[SEL_INVENTARIO_MOVIMIENTO_USUARIO]
    @CLIENTE INT
AS
SET NOCOUNT ON

    SELECT  u.usu_id,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' ' + ISNULL(u.usu_apellido_paterno, ''))) AS USUARIO_NOMBRE,
            COUNT(*) AS MOVIMIENTOS,
            MAX(m.imo_fecha_movimiento_utc) AS ULTIMO
    FROM    [dbo].[Inventario_Movimiento] m
    JOIN    [dbo].[Usuario] u ON u.usu_id = m.imo_usuario_creacion
    WHERE   m.imo_cliente = @CLIENTE
    GROUP BY u.usu_id, u.usu_nombre, u.usu_apellido_paterno
    ORDER BY COUNT(*) DESC, USUARIO_NOMBRE
GO


/* ========================================================================
   3. VERIFICACION
   ======================================================================== */
PRINT '--- Quienes registraron movimientos ---'
EXEC [dbo].[SEL_INVENTARIO_MOVIMIENTO_USUARIO] @CLIENTE = 1
GO
