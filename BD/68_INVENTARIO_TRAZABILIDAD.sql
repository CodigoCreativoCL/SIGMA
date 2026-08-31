/* ============================================================================
   SIGMA — Bloque 68
   TRAZABILIDAD: QUIEN LO CREO, QUIEN LO TOCO Y CUANDO
   ----------------------------------------------------------------------------

   EL HUECO

     Las seis tablas del inventario llevan sus cuatro columnas de auditoria
     desde las fundaciones —usuario y fecha de creacion, usuario y fecha de
     actualizacion— y los SP las escriben en cada alta y en cada edicion.

     Pero ningun SEL_ las devuelve. O sea que el dato existe, se escribe
     religiosamente, y **no hay forma de verlo desde la aplicacion**. Una
     auditoria que solo se puede leer con acceso a la base no es una
     auditoria: es una tabla con columnas de mas.

   EL ID NO SIRVE, EL NOMBRE SI

     Devolver usu_id = 7 obliga a quien mira a ir a buscar quien es 7. Se
     devuelve el nombre armado, que es lo que va a la pantalla, y de paso el
     id por si alguien necesita enlazar.

     El JOIN es LEFT: las filas de la carga inicial pueden apuntar a un
     usuario que ya no esta habilitado, y perder la fila entera por eso
     seria peor que mostrar el nombre vacio.

   TAMBIEN: UPD_REPUESTO_LOTE

     No existia. Un lote mal cargado —una fecha de vencimiento equivocada al
     recibir la mercaderia— no se podia corregir desde ninguna parte. El
     codigo NO se edita: es con lo que se identifica el lote en el envase y
     en los movimientos que ya lo referencian.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. LA TRAZABILIDAD EN LOS SEL_

      Se inyectan las columnas y los JOIN sobre la definicion que ya existe,
      en vez de reescribir cada procedimiento entero: lo que hay adentro
      esta probado y no hay motivo para volver a escribirlo.
   ======================================================================== */
DECLARE @SQL NVARCHAR(MAX)

/* ---- SEL_BODEGA ---- */
SET @SQL = OBJECT_DEFINITION(OBJECT_ID('dbo.SEL_BODEGA'))

IF @SQL IS NOT NULL AND @SQL NOT LIKE '%USUARIO_CREACION_NOMBRE%'
BEGIN
    SET @SQL = REPLACE(@SQL,
        '            b.bod_codigo, b.bod_nombre, b.bod_descripcion, b.bod_habilitado,',
        '            b.bod_codigo, b.bod_nombre, b.bod_descripcion, b.bod_habilitado,
            b.bod_usuario_creacion, b.bod_fecha_creacion,
            b.bod_usuario_actualizacion, b.bod_fecha_actualizacion,
            LTRIM(RTRIM(ISNULL(uc.usu_nombre,'''') + '' '' + ISNULL(uc.usu_apellido_paterno,''''))) AS USUARIO_CREACION_NOMBRE,
            LTRIM(RTRIM(ISNULL(ua.usu_nombre,'''') + '' '' + ISNULL(ua.usu_apellido_paterno,''''))) AS USUARIO_ACTUALIZACION_NOMBRE,')

    SET @SQL = REPLACE(@SQL,
        '    JOIN    [dbo].[Cliente_Instalacion] cin ON cin.cin_id = b.bod_cliente_instalacion',
        '    JOIN    [dbo].[Cliente_Instalacion] cin ON cin.cin_id = b.bod_cliente_instalacion
    LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = b.bod_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = b.bod_usuario_actualizacion')

    SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
    EXEC sp_executesql @SQL
    PRINT '--- SEL_BODEGA con trazabilidad'
END
GO


/* ---- SEL_BODEGA_UBICACION ---- */
DECLARE @SQL NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.SEL_BODEGA_UBICACION'))

IF @SQL IS NOT NULL AND @SQL NOT LIKE '%USUARIO_CREACION_NOMBRE%'
BEGIN
    SET @SQL = REPLACE(@SQL,
        'SELECT  u.bub_id, u.bub_bodega, u.bub_codigo, u.bub_nombre, u.bub_habilitado,',
        'SELECT  u.bub_id, u.bub_bodega, u.bub_codigo, u.bub_nombre, u.bub_habilitado,
            u.bub_usuario_creacion, u.bub_fecha_creacion,
            u.bub_usuario_actualizacion, u.bub_fecha_actualizacion,
            LTRIM(RTRIM(ISNULL(uc.usu_nombre,'''') + '' '' + ISNULL(uc.usu_apellido_paterno,''''))) AS USUARIO_CREACION_NOMBRE,
            LTRIM(RTRIM(ISNULL(ua.usu_nombre,'''') + '' '' + ISNULL(ua.usu_apellido_paterno,''''))) AS USUARIO_ACTUALIZACION_NOMBRE,')

    SET @SQL = REPLACE(@SQL,
        '    JOIN    [dbo].[Bodega] b ON b.bod_id = u.bub_bodega',
        '    JOIN    [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
    LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = u.bub_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = u.bub_usuario_actualizacion')

    SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
    EXEC sp_executesql @SQL
    PRINT '--- SEL_BODEGA_UBICACION con trazabilidad'
END
GO


/* ---- SEL_REPUESTO ---- */
DECLARE @SQL NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.SEL_REPUESTO'))

IF @SQL IS NOT NULL AND @SQL NOT LIKE '%USUARIO_CREACION_NOMBRE%'
BEGIN
    SET @SQL = REPLACE(@SQL,
        '            r.rep_habilitado,',
        '            r.rep_habilitado,
            r.rep_usuario_creacion, r.rep_fecha_creacion,
            r.rep_usuario_actualizacion, r.rep_fecha_actualizacion,
            LTRIM(RTRIM(ISNULL(uc.usu_nombre,'''') + '' '' + ISNULL(uc.usu_apellido_paterno,''''))) AS USUARIO_CREACION_NOMBRE,
            LTRIM(RTRIM(ISNULL(ua.usu_nombre,'''') + '' '' + ISNULL(ua.usu_apellido_paterno,''''))) AS USUARIO_ACTUALIZACION_NOMBRE,')

    SET @SQL = REPLACE(@SQL,
        '    LEFT JOIN [dbo].[Moneda] mon      ON mon.mon_id = r.rep_moneda',
        '    LEFT JOIN [dbo].[Moneda] mon      ON mon.mon_id = r.rep_moneda
    LEFT JOIN [dbo].[Usuario] uc      ON uc.usu_id = r.rep_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua      ON ua.usu_id = r.rep_usuario_actualizacion')

    SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
    EXEC sp_executesql @SQL
    PRINT '--- SEL_REPUESTO con trazabilidad'
END
GO


/* ---- SEL_REPUESTO_BODEGA_STOCK ---- */
DECLARE @SQL NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.SEL_REPUESTO_BODEGA_STOCK'))

IF @SQL IS NOT NULL AND @SQL NOT LIKE '%USUARIO_CREACION_NOMBRE%'
BEGIN
    SET @SQL = REPLACE(@SQL,
        '            s.rbs_observacion, s.rbs_habilitado,',
        '            s.rbs_observacion, s.rbs_habilitado,
            s.rbs_usuario_creacion, s.rbs_fecha_creacion,
            s.rbs_usuario_actualizacion, s.rbs_fecha_actualizacion,
            LTRIM(RTRIM(ISNULL(uc.usu_nombre,'''') + '' '' + ISNULL(uc.usu_apellido_paterno,''''))) AS USUARIO_CREACION_NOMBRE,
            LTRIM(RTRIM(ISNULL(ua.usu_nombre,'''') + '' '' + ISNULL(ua.usu_apellido_paterno,''''))) AS USUARIO_ACTUALIZACION_NOMBRE,')

    SET @SQL = REPLACE(@SQL,
        '    JOIN    [dbo].[Bodega]   b ON b.bod_id = s.rbs_bodega',
        '    JOIN    [dbo].[Bodega]   b ON b.bod_id = s.rbs_bodega
    LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = s.rbs_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = s.rbs_usuario_actualizacion')

    SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
    EXEC sp_executesql @SQL
    PRINT '--- SEL_REPUESTO_BODEGA_STOCK con trazabilidad'
END
GO


/* ---- SEL_REPUESTO_LOTE ---- */
DECLARE @SQL NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.SEL_REPUESTO_LOTE'))

IF @SQL IS NOT NULL AND @SQL NOT LIKE '%USUARIO_CREACION_NOMBRE%'
BEGIN
    SET @SQL = REPLACE(@SQL,
        '            l.rlo_moneda, l.rlo_observacion, l.rlo_habilitado,',
        '            l.rlo_moneda, l.rlo_observacion, l.rlo_habilitado,
            l.rlo_usuario_creacion, l.rlo_fecha_creacion,
            l.rlo_usuario_actualizacion, l.rlo_fecha_actualizacion,
            LTRIM(RTRIM(ISNULL(uc.usu_nombre,'''') + '' '' + ISNULL(uc.usu_apellido_paterno,''''))) AS USUARIO_CREACION_NOMBRE,
            LTRIM(RTRIM(ISNULL(ua.usu_nombre,'''') + '' '' + ISNULL(ua.usu_apellido_paterno,''''))) AS USUARIO_ACTUALIZACION_NOMBRE,')

    SET @SQL = REPLACE(@SQL,
        '    JOIN    [dbo].[Repuesto] r ON r.rep_id = l.rlo_repuesto',
        '    JOIN    [dbo].[Repuesto] r ON r.rep_id = l.rlo_repuesto
    LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = l.rlo_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = l.rlo_usuario_actualizacion')

    SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
    EXEC sp_executesql @SQL
    PRINT '--- SEL_REPUESTO_LOTE con trazabilidad'
END
GO


/* ========================================================================
   2. UPD_REPUESTO_LOTE

      EL CODIGO NO SE EDITA
        Es el numero impreso en el envase y el que citan los movimientos que
        ya salieron de ese lote. Renombrarlo desde un formulario rompe en
        silencio la trazabilidad que el lote existe para dar. Si el codigo
        esta mal, se crea el lote correcto y el equivocado se deshabilita.

      LA FECHA DE VENCIMIENTO SI
        Es el caso que motiva este procedimiento: se recibe la mercaderia,
        se anota mal la fecha, y hoy no habia forma de corregirla.
   ======================================================================== */
IF OBJECT_ID('dbo.UPD_REPUESTO_LOTE') IS NOT NULL DROP PROCEDURE [dbo].[UPD_REPUESTO_LOTE]
GO

CREATE PROCEDURE [dbo].[UPD_REPUESTO_LOTE]
    @ID                INT,
    @CLIENTE           INT,
    @FECHA_INGRESO     DATE = NULL,
    @FECHA_VENCIMIENTO DATE = NULL,
    @LIMPIA_VENCIMIENTO BIT = 0,
    @PROVEEDOR         INT = NULL,
    @COSTO_UNITARIO    DECIMAL(18,4) = NULL,
    @OBSERVACION       NVARCHAR(1000) = NULL,
    @HABILITADO        BIT = NULL,
    @USUARIO           INT
AS
SET NOCOUNT ON

DECLARE @INGRESO DATE

SELECT @INGRESO = rlo_fecha_ingreso
FROM   [dbo].[Repuesto_Lote]
WHERE  rlo_id = @ID AND rlo_cliente = @CLIENTE

IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Lote] WHERE rlo_id = @ID AND rlo_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL LOTE NO EXISTE.', 16, 1)
    RETURN -1
END

/* Vencer antes de haber llegado no es un lote, es un error de tipeo. */
IF (@FECHA_VENCIMIENTO IS NOT NULL
    AND ISNULL(@FECHA_INGRESO, @INGRESO) IS NOT NULL
    AND @FECHA_VENCIMIENTO < ISNULL(@FECHA_INGRESO, @INGRESO))
BEGIN
    RAISERROR('2.- LA FECHA DE VENCIMIENTO NO PUEDE SER ANTERIOR A LA DE INGRESO.', 16, 1)
    RETURN -1
END

/* Deshabilitar un lote con existencia esconderia unidades que siguen en la
   estanteria. Los movimientos guardan el lote del que salieron, asi que
   basta mirar si alguno sigue sumando. */
IF (@HABILITADO = 0)
BEGIN
    DECLARE @SALDO DECIMAL(18,4)

    SELECT @SALDO = ISNULL(SUM(CASE WHEN imo_inventario_movimiento_tipo IN (1,3,4,7)
                                    THEN imo_cantidad ELSE -imo_cantidad END), 0)
    FROM   [dbo].[Inventario_Movimiento]
    WHERE  imo_repuesto_lote = @ID

    IF (@SALDO > 0)
    BEGIN
        DECLARE @MSG NVARCHAR(400) =
            '3.- NO SE PUEDE DESHABILITAR EL LOTE: QUEDAN '
          + LTRIM(STR(CAST(@SALDO AS DECIMAL(18,2)), 18, 2)) + ' UNIDAD(ES) SUYAS EN BODEGA.'
        RAISERROR(@MSG, 16, 1)
        RETURN -1
    END
END

/* XACT_ABORT aca y no arriba: un rechazo de validacion no tiene por que
   condenar la transaccion de quien llama (bloque 61). */
SET XACT_ABORT ON

BEGIN TRANSACTION

    /* @LIMPIA_VENCIMIENTO: con ISNULL, un campo vacio significa "no lo
       toques", y eso hace imposible BORRAR una fecha mal puesta. La bandera
       separa "no lo mande" de "quiero borrarlo" (bloque 63). */
    UPDATE  [dbo].[Repuesto_Lote]
    SET     rlo_fecha_ingreso        = ISNULL(@FECHA_INGRESO, rlo_fecha_ingreso)
           ,rlo_fecha_vencimiento    = CASE WHEN @LIMPIA_VENCIMIENTO = 1 THEN @FECHA_VENCIMIENTO
                                            ELSE ISNULL(@FECHA_VENCIMIENTO, rlo_fecha_vencimiento) END
           ,rlo_proveedor            = ISNULL(@PROVEEDOR,      rlo_proveedor)
           ,rlo_costo_unitario       = ISNULL(@COSTO_UNITARIO, rlo_costo_unitario)
           ,rlo_observacion          = ISNULL(@OBSERVACION,    rlo_observacion)
           ,rlo_habilitado           = ISNULL(@HABILITADO,     rlo_habilitado)
           ,rlo_usuario_actualizacion = @USUARIO
           ,rlo_fecha_actualizacion   = GETDATE()
    WHERE   rlo_id = @ID

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Lote actualizado.' [MENSAJE]
RETURN 0
GO


/* ========================================================================
   3. VERIFICACION
   ======================================================================== */
PRINT '--- SEL_ con trazabilidad ---'
SELECT  o.name AS procedimiento,
        CASE WHEN m.definition LIKE '%USUARIO_CREACION_NOMBRE%' THEN 'si' ELSE 'NO' END AS trazabilidad
FROM    sys.sql_modules m
JOIN    sys.objects o ON o.object_id = m.object_id
WHERE   o.name IN ('SEL_BODEGA', 'SEL_BODEGA_UBICACION', 'SEL_REPUESTO',
                   'SEL_REPUESTO_BODEGA_STOCK', 'SEL_REPUESTO_LOTE')
ORDER BY o.name

PRINT '--- Prueba: quien creo cada bodega ---'
EXEC [dbo].[SEL_BODEGA] @CLIENTE = 1
GO
