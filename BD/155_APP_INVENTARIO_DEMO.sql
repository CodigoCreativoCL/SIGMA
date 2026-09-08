USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     REPUESTOS Y SALDO INICIAL, PARA QUE EL INVENTARIO DE LA
--                  APP DEJE DE ESTAR VACIO.
-- =============================================
-- QUE DESBLOQUEA
--
--   Habia 0 repuestos y 0 saldos. Eso dejaba sin nada que mostrar a:
--
--     * HU-056 (Sprint 3) - consultar la existencia de un repuesto,
--     * HU-116 (Sprint 5) - registrar el consumo en una orden,
--     * y la alerta de stock bajo minimo, que no tenia sobre que dispararse.
--
--   Las tres se veian como "la API no devuelve nada", que es el sintoma mas
--   caro de diagnosticar porque parece un fallo y es una tabla vacia.
--
-- SE CREA EJERCITANDO LOS PROPIOS SP
--
--   Los repuestos con INS_REPUESTO y el saldo con INS_INVENTARIO_MOVIMIENTO
--   tipo 1 (INGRESO COMPRA). Nada se inserta a mano: asi la siembra prueba de
--   paso el calculo de saldo y el costo promedio, en vez de dejar filas que el
--   codigo real nunca habria producido.
--
-- EL STOCK MINIMO ES LO QUE HACE UTIL LA ALERTA
--
--   Un saldo sin umbral no dispara nada. Se fija con UPS_REPUESTO_BODEGA_STOCK
--   y se deja UNO de los repuestos deliberadamente bajo el minimo, para que la
--   pantalla de existencias tenga su caso rojo y se pueda ver que el semaforo
--   funciona.
--
-- ES REEJECUTABLE
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE     INT = 1
DECLARE @ROOT        INT = 1
DECLARE @INSTALACION INT = (SELECT TOP 1 [cin_id] FROM [dbo].[Cliente_Instalacion]
                             WHERE [cin_cliente] = @CLIENTE AND [cin_habilitado] = 1
                             ORDER BY [cin_id])
DECLARE @BODEGA      INT = (SELECT TOP 1 [bod_id] FROM [dbo].[Bodega]
                             WHERE [bod_cliente_instalacion] = @INSTALACION
                               AND [bod_habilitado] = 1
                             ORDER BY [bod_id])
DECLARE @UNIDAD      INT = (SELECT TOP 1 [ume_id] FROM [dbo].[Unidad_Medida]
                             WHERE [ume_codigo] IN ('UN', 'C/U', 'UNIDAD')
                                OR [ume_simbolo] = 'un'
                             ORDER BY [ume_id])

IF @UNIDAD IS NULL SET @UNIDAD = (SELECT TOP 1 [ume_id] FROM [dbo].[Unidad_Medida] ORDER BY [ume_id])

IF @BODEGA IS NULL
BEGIN
    RAISERROR('No hay bodega habilitada en la instalacion. Revisa el bloque de bodegas.', 16, 1)
    RETURN
END


-- ---------------------------------------------------------------------------
-- 1 - LOS REPUESTOS
-- ---------------------------------------------------------------------------
DECLARE @REPUESTOS TABLE (
     [codigo]  NVARCHAR(100)
    ,[nombre]  NVARCHAR(400)
    ,[fab]     NVARCHAR(400)
    ,[modelo]  NVARCHAR(400)
    ,[minimo]  DECIMAL(18,4)
    ,[maximo]  DECIMAL(18,4)
    ,[ingreso] DECIMAL(18,4)
    ,[costo]   DECIMAL(18,4)
)

INSERT INTO @REPUESTOS VALUES
     (N'REP-6205', N'Rodamiento rigido de bolas 6205', N'SKF',       N'6205-2RS',  10, 40,  2, 8500)
    ,(N'REP-SELLO', N'Sello mecanico 35 mm',           N'Burgmann',  N'MG1-35',     4, 20, 12, 42000)
    ,(N'REP-CORREA', N'Correa trapecial B-58',         N'Optibelt',  N'B-58',       6, 30, 18, 12500)
    ,(N'REP-GRASA', N'Grasa de litio EP2 (kg)',        N'Shell',     N'Gadus S2',   5, 25, 20, 6900)

DECLARE @cod NVARCHAR(100), @nom NVARCHAR(400), @fab NVARCHAR(400),
        @mod NVARCHAR(400), @min DECIMAL(18,4), @max DECIMAL(18,4),
        @ing DECIMAL(18,4), @cos DECIMAL(18,4)

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT [codigo], [nombre], [fab], [modelo], [minimo], [maximo], [ingreso], [costo]
      FROM @REPUESTOS

OPEN cur
FETCH NEXT FROM cur INTO @cod, @nom, @fab, @mod, @min, @max, @ing, @cos

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @REP INT = (SELECT [rep_id] FROM [dbo].[Repuesto]
                         WHERE [rep_cliente] = @CLIENTE AND [rep_codigo] = @cod)

    IF @REP IS NULL
    BEGIN
        EXEC [dbo].[INS_REPUESTO]
             @ID               = @REP OUTPUT
            ,@CLIENTE          = @CLIENTE
            ,@CODIGO           = @cod
            ,@NOMBRE           = @nom
            ,@UNIDAD_MEDIDA    = @UNIDAD
            ,@FABRICANTE       = @fab
            ,@MODELO           = @mod
            ,@ES_CONSUMIBLE    = 1
            ,@COSTO_REFERENCIA = @cos
            ,@USUARIO          = @ROOT
    END

    /* El umbral por bodega: sin el, la alerta de stock no tiene contra que
       comparar y el semaforo de la app queda siempre en verde. */
    EXEC [dbo].[UPS_REPUESTO_BODEGA_STOCK]
         @CLIENTE       = @CLIENTE
        ,@REPUESTO      = @REP
        ,@BODEGA        = @BODEGA
        ,@STOCK_MINIMO  = @min
        ,@STOCK_MAXIMO  = @max
        ,@USUARIO       = @ROOT

    /* El ingreso, con uuid derivado del codigo para que reejecutar no sume
       dos veces el mismo saldo. */
    DECLARE @UUID UNIQUEIDENTIFIER =
        CAST(HASHBYTES('MD5', N'SIEMBRA-' + @cod) AS UNIQUEIDENTIFIER)
    DECLARE @IMO INT

    EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO]
         @ID             = @IMO OUTPUT
        ,@CLIENTE        = @CLIENTE
        ,@REPUESTO       = @REP
        ,@BODEGA         = @BODEGA
        ,@TIPO           = 1                -- INGRESO COMPRA
        ,@CANTIDAD       = @ing
        ,@COSTO_UNITARIO = @cos
        ,@OBSERVACION    = N'Saldo inicial de puesta en marcha'
        ,@UUID           = @UUID
        ,@USUARIO        = @ROOT

    FETCH NEXT FROM cur INTO @cod, @nom, @fab, @mod, @min, @max, @ing, @cos
END

CLOSE cur
DEALLOCATE cur


-- ---------------------------------------------------------------------------
-- 2 - VERIFICACION
-- ---------------------------------------------------------------------------
--   REP-6205 entra con 2 unidades contra un minimo de 10: es el caso rojo, y
--   esta puesto a proposito para que la pantalla de existencias tenga algo
--   fuera de umbral que mostrar.
-- ---------------------------------------------------------------------------
SELECT   rep.[rep_codigo]              AS [REPUESTO]
        ,rep.[rep_nombre]              AS [NOMBRE]
        ,isa.[isa_cantidad_disponible] AS [SALDO]
        ,rbs.[rbs_stock_minimo]        AS [MINIMO]
        ,CASE WHEN isa.[isa_cantidad_disponible] < rbs.[rbs_stock_minimo]
              THEN N'BAJO MINIMO' ELSE N'OK' END AS [SEMAFORO]
FROM     [dbo].[Inventario_Saldo] isa
JOIN     [dbo].[Repuesto]         rep ON rep.[rep_id] = isa.[isa_repuesto]
LEFT JOIN [dbo].[Repuesto_Bodega_Stock] rbs
       ON  rbs.[rbs_repuesto] = isa.[isa_repuesto]
       AND rbs.[rbs_bodega]   = isa.[isa_bodega]
WHERE    rep.[rep_cliente] = 1
ORDER BY rep.[rep_codigo]
GO
