/* ============================================================================
   SIGMA — Bloque 59
   LA BAJA DEL PLAN · LA CORRECCION DE UN PAGO
   ----------------------------------------------------------------------------

   Cierra las tres tareas que quedaron abiertas del modulo de suscripcion al
   revisarlo contra la base el 31-08-2026:

     T-2196  DEL_PLAN_COMERCIAL no existia. Lo que habia era
             DEL_PLAN_COMERCIAL_PRECIO, que cierra un precio y no da de baja
             el plan. Planes.aspx tampoco tenia boton Eliminar.

     T-2211  UPD_SUSCRIPCION_PAGO no existia. Lo que habia era
             UPD_SUSCRIPCION_PAGO_VERIFICAR, que marca un pago como
             verificado o rechazado. Corregir un pago mal declarado -monto,
             banco, fecha, numero de operacion- es otra operacion.

     T-2212  Suscripcion_Pago tenia 0 filas.

   Los nombres se parecen lo suficiente como para que un cierre en bloque
   pasara sin que nadie lo notara.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. DEL_PLAN_COMERCIAL

      QUE BLOQUEA LA BAJA Y QUE NO

      Bloquea:
        · Suscripcion viva apuntando al plan. Dar de baja el plan que un
          cliente esta pagando lo deja apuntando a algo deshabilitado, y la
          proxima emision de periodo no sabria que cobrar.

      NO bloquea:
        · Suscripcion_Periodo. Un periodo emitido es HISTORIA: dice cuanto
          se cobro y bajo que plan. Si la historia bloqueara, un plan que
          alguna vez se vendio seria indeleble para siempre —y eso es
          justamente lo que la baja logica existe para evitar—. La fila
          sigue ahi, apuntando a un plan deshabilitado, que es correcto.

        · Plan_Comercial_Precio y Plan_Comercial_Funcionalidad. No son
          dependientes: son PARTES del plan. Se deshabilitan con el, en la
          misma transaccion. Dejarlas habilitadas colgando de un plan que ya
          no existe es basura que despues alguien lee como si valiera.

      COMO SE VUELVE ATRAS
        No hay un UN-DELETE. UPD_PLAN_COMERCIAL recibe @HABILITADO, asi que
        reactivar es editar el plan. Ojo: eso NO revive los precios ni las
        funcionalidades, hay que volver a habilitarlos. Es a proposito:
        reactivar un plan de hace un anno con su tarifa vieja intacta es mas
        peligroso que obligar a revisarla.
   ======================================================================== */
IF OBJECT_ID('dbo.DEL_PLAN_COMERCIAL') IS NOT NULL
    DROP PROCEDURE [dbo].[DEL_PLAN_COMERCIAL]
GO

CREATE PROCEDURE [dbo].[DEL_PLAN_COMERCIAL]
@ID      INT,
@USUARIO INT

AS
SET NOCOUNT ON

DECLARE @EXISTE      BIT = 0
       ,@HABILITADO  BIT
       ,@NOMBRE      NVARCHAR(100)
       ,@VIVAS       INT

SELECT  @EXISTE     = 1
       ,@HABILITADO = plc_habilitado
       ,@NOMBRE     = plc_nombre
FROM    [dbo].[Plan_Comercial]
WHERE   plc_id = @ID

IF (@EXISTE = 0)
BEGIN
    RAISERROR('1.- EL PLAN COMERCIAL NO EXISTE.', 16, 1)
    RETURN -1
END

/* Ya deshabilitado: no es un error, es que alguien apreto dos veces o dos
   personas hicieron lo mismo. Devolver un error obligaria a la pantalla a
   distinguir "fallo" de "ya estaba", y termina mostrando un rojo por algo
   que salio bien. */
IF (@HABILITADO = 0)
BEGIN
    SELECT @ID [ID], '200' [CODE], 'El plan ya estaba dado de baja.' [MENSAJE]
    RETURN 0
END

SELECT  @VIVAS = COUNT(*)
FROM    [dbo].[Suscripcion]
WHERE   sus_plan_comercial = @ID
  AND   ISNULL(sus_habilitado, 0) = 1

IF (@VIVAS > 0)
BEGIN
    DECLARE @MSG NVARCHAR(400) =
        '2.- NO SE PUEDE DAR DE BAJA EL PLAN ' + ISNULL(@NOMBRE, '') + ': HAY '
      + LTRIM(STR(@VIVAS)) + ' SUSCRIPCION(ES) VIGENTE(S) USANDOLO. '
      + 'CAMBIE ESOS CLIENTES DE PLAN PRIMERO.'

    RAISERROR(@MSG, 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Comercial]
    SET     plc_habilitado            = 0
           ,plc_publico               = 0      -- deja de ofrecerse, ademas
           ,plc_usuario_actualizacion = @USUARIO
           ,plc_fecha_actualizacion   = GETDATE()
    WHERE   plc_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION

        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_PLAN_COMERCIAL @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '3.- NO FUE POSIBLE DAR DE BAJA EL PLAN.'
        RETURN -1
    END

    -- Las partes del plan se van con el.
    UPDATE  [dbo].[Plan_Comercial_Precio]
    SET     pcp_habilitado            = 0
           ,pcp_usuario_actualizacion = @USUARIO
           ,pcp_fecha_actualizacion   = GETDATE()
    WHERE   pcp_plan_comercial = @ID
      AND   ISNULL(pcp_habilitado, 0) = 1

    UPDATE  [dbo].[Plan_Comercial_Funcionalidad]
    SET     pcf_habilitado            = 0
           ,pcf_usuario_actualizacion = @USUARIO
           ,pcf_fecha_actualizacion   = GETDATE()
    WHERE   pcf_plan_comercial = @ID
      AND   ISNULL(pcf_habilitado, 0) = 1

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Plan dado de baja.' [MENSAJE]
RETURN 0
GO


/* ========================================================================
   2. UPD_SUSCRIPCION_PAGO

      Corregir lo que el cliente declaro mal. NO es verificar: eso es
      UPD_SUSCRIPCION_PAGO_VERIFICAR y toca cuatro tablas.

      EL ESTADO DECIDE SI SE PUEDE

        DECLARADO / EN REVISION -> se corrige y se queda donde estaba.

        RECHAZADO -> se corrige y VUELVE A DECLARADO, limpiando el motivo
          del rechazo y quien lo reviso. Es el flujo real: el cliente
          declaro mal, se le rechazo, corrige y vuelve a la cola. Dejarlo en
          RECHAZADO con datos nuevos daria un pago corregido que nadie
          vuelve a mirar.

        VERIFICADO -> se rechaza. Ese pago ya sumo en
          spe_monto_pagado_clp y pudo haber extendido sus_fecha_fin.
          Cambiarle el monto aca dejaria el periodo descuadrado y la
          vigencia apoyada en una cifra que ya no existe. Para eso hay que
          revertir la verificacion primero —y eso todavia no existe: ver el
          MD de estado—.

      EL PERIODO NO SE CAMBIA
        @PERIODO no es parametro. Mover un pago de un periodo a otro
        descuadra los DOS: el que lo pierde y el que lo recibe. Es una
        operacion aparte, con su propio recalculo.

      ISNULL(@X, columna) EN TODO LO OPCIONAL
        La ficha de pago no muestra todas las columnas. Escribir la fila
        entera con lo que llega borraria lo que no viajo —que es exactamente
        como UPD_CLIENTE_INSTALACION borro la zona horaria y las coordenadas
        de las plantas (bloque 51)—.
   ======================================================================== */
IF OBJECT_ID('dbo.UPD_SUSCRIPCION_PAGO') IS NOT NULL
    DROP PROCEDURE [dbo].[UPD_SUSCRIPCION_PAGO]
GO

CREATE PROCEDURE [dbo].[UPD_SUSCRIPCION_PAGO]
@ID                  INT,
@MONTO_DECLARADO     DECIMAL(18,2) = NULL,
@FECHA_TRANSFERENCIA DATE          = NULL,
@BANCO               NVARCHAR(200) = NULL,
@NUMERO_OPERACION    NVARCHAR(200) = NULL,
@ARCHIVO             INT           = NULL,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @ESTADO INT
       ,@HOY    DATE = CAST(GETDATE() AS DATE)

SELECT  @ESTADO = spa_suscripcion_pago_estado
FROM    [dbo].[Suscripcion_Pago]
WHERE   spa_id = @ID
  AND   ISNULL(spa_habilitado, 0) = 1

IF (@ESTADO IS NULL)
BEGIN
    RAISERROR('1.- EL PAGO NO EXISTE.', 16, 1)
    RETURN -1
END

IF (@ESTADO = 3)
BEGIN
    /* RAISERROR no acepta una expresion como mensaje: solo un literal o una
       variable. Concatenar ahi mismo es un error de sintaxis. */
    DECLARE @MSG_VERIFICADO NVARCHAR(400) =
        '2.- EL PAGO YA ESTA VERIFICADO Y NO SE PUEDE CORREGIR. '
      + 'SU MONTO YA SUMO AL PERIODO Y PUDO EXTENDER LA VIGENCIA DE LA SUSCRIPCION.'

    RAISERROR(@MSG_VERIFICADO, 16, 1)
    RETURN -1
END

/* Un monto en cero o negativo no es una correccion, es un dato roto: la
   suma del periodo lo tomaria igual. */
IF (@MONTO_DECLARADO IS NOT NULL AND @MONTO_DECLARADO <= 0)
BEGIN
    RAISERROR('3.- EL MONTO DECLARADO DEBE SER MAYOR QUE CERO.', 16, 1)
    RETURN -1
END

/* Una transferencia con fecha futura no ocurrio. */
IF (@FECHA_TRANSFERENCIA IS NOT NULL AND @FECHA_TRANSFERENCIA > @HOY)
BEGIN
    RAISERROR('4.- LA FECHA DE TRANSFERENCIA NO PUEDE SER FUTURA.', 16, 1)
    RETURN -1
END

IF (@ARCHIVO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Archivo]
                     WHERE arc_id = @ARCHIVO AND ISNULL(arc_habilitado, 0) = 1))
BEGIN
    RAISERROR('5.- EL COMPROBANTE INDICADO NO EXISTE.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Suscripcion_Pago]
    SET     spa_monto_declarado_clp    = ISNULL(@MONTO_DECLARADO,     spa_monto_declarado_clp)
           ,spa_fecha_transferencia    = ISNULL(@FECHA_TRANSFERENCIA, spa_fecha_transferencia)
           ,spa_banco                  = ISNULL(@BANCO,               spa_banco)
           ,spa_numero_operacion       = ISNULL(@NUMERO_OPERACION,    spa_numero_operacion)
           ,spa_archivo                = ISNULL(@ARCHIVO,             spa_archivo)

            -- Un rechazado corregido vuelve a la cola. El resto no se mueve.
           ,spa_suscripcion_pago_estado = CASE WHEN @ESTADO = 4 THEN 1 ELSE spa_suscripcion_pago_estado END
           ,spa_motivo_rechazo          = CASE WHEN @ESTADO = 4 THEN NULL ELSE spa_motivo_rechazo END
           ,spa_usuario_verificador     = CASE WHEN @ESTADO = 4 THEN NULL ELSE spa_usuario_verificador END
           ,spa_fecha_verificacion_utc  = CASE WHEN @ESTADO = 4 THEN NULL ELSE spa_fecha_verificacion_utc END

           ,spa_usuario_actualizacion  = @USUARIO
           ,spa_fecha_actualizacion    = GETDATE()
    WHERE   spa_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION

        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_SUSCRIPCION_PAGO @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '6.- NO FUE POSIBLE CORREGIR EL PAGO.'
        RETURN -1
    END

COMMIT TRANSACTION

SELECT  @ID [ID], '200' [CODE]
       ,CASE WHEN @ESTADO = 4
             THEN 'Pago corregido. Vuelve a quedar declarado, a la espera de verificación.'
             ELSE 'Pago corregido.' END [MENSAJE]
RETURN 0
GO


/* ========================================================================
   3. DATOS DE PRUEBA EN Suscripcion_Pago  (T-2212)

      NO CREA LA SUSCRIPCION. El 29-08 se elimino la de Hamburgo a peticion
      expresa: "la quiero hacer yo desde la web". Sembrarla aca desharia esa
      decision por la puerta de atras.

      Este bloque busca un periodo existente y siembra sobre el. Si no hay
      ninguno, no hace nada y lo dice: primero se crea la suscripcion desde
      la web, despues se corre esto.

      Los tres pagos cubren los tres casos que hay que poder ejercitar:
        · uno DECLARADO, para verificarlo;
        · uno RECHAZADO, para corregirlo y ver que vuelve a DECLARADO;
        · uno parcial DECLARADO, para ver el periodo en PAGO PARCIAL.
   ======================================================================== */
DECLARE @PERIODO INT, @CLIENTE INT, @MONTO DECIMAL(18,2), @ARCHIVO INT, @ROOT INT = 1

SELECT TOP 1 @PERIODO = spe.spe_id
            ,@MONTO   = spe.spe_monto_clp
            ,@CLIENTE = sus.sus_cliente
FROM   [dbo].[Suscripcion_Periodo] spe
JOIN   [dbo].[Suscripcion]         sus ON sus.sus_id = spe.spe_suscripcion
ORDER BY spe.spe_id

IF (@PERIODO IS NULL)
BEGIN
    PRINT '--- T-2212: NO HAY PERIODOS EMITIDOS. No se sembro ningun pago.'
    PRINT '    Cree la suscripcion y emita un periodo desde la web, y vuelva'
    PRINT '    a ejecutar SOLO esta seccion del bloque 59.'
END
ELSE IF EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Pago]
                 WHERE spa_numero_operacion LIKE 'DEMO-%')
BEGIN
    PRINT '--- T-2212: los pagos de prueba ya estaban cargados.'
END
ELSE
BEGIN
    -- El comprobante: se reutiliza el archivo demo si existe, si no se crea.
    SELECT TOP 1 @ARCHIVO = arc_id
    FROM   [dbo].[Archivo]
    WHERE  arc_archivo_categoria = 12
      AND  arc_cliente = @CLIENTE
      AND  ISNULL(arc_habilitado, 0) = 1

    IF (@ARCHIVO IS NULL)
    BEGIN
        INSERT INTO [dbo].[Archivo]
            (arc_uuid, arc_cliente, arc_archivo_categoria, arc_nombre_original,
             arc_nombre_almacenado, arc_ruta, arc_mime, arc_extension, arc_byte,
             arc_archivo_antivirus_estado, arc_usuario_creacion, arc_fecha_creacion,
             arc_habilitado)
        VALUES
            (NEWID(), @CLIENTE, 12, 'comprobante-demo.pdf',
             'comprobante-demo.pdf', '/archivos/demo/', 'application/pdf', '.pdf', 45821,
             /* PENDIENTE, no LIMPIO: nadie lo escaneo. */ 1, @ROOT, GETDATE(), 1)

        SET @ARCHIVO = SCOPE_IDENTITY()
    END

    DECLARE @P1 INT, @P2 INT, @P3 INT

    EXEC [dbo].[INS_SUSCRIPCION_PAGO]
         @ID = @P1 OUTPUT, @PERIODO = @PERIODO,
         @MONTO_DECLARADO = @MONTO, @FECHA_TRANSFERENCIA = '2026-08-20',
         @BANCO = N'Banco de Chile', @NUMERO_OPERACION = N'DEMO-000001',
         @ARCHIVO = @ARCHIVO, @USUARIO = @ROOT

    EXEC [dbo].[INS_SUSCRIPCION_PAGO]
         @ID = @P2 OUTPUT, @PERIODO = @PERIODO,
         @MONTO_DECLARADO = @MONTO, @FECHA_TRANSFERENCIA = '2026-08-21',
         @BANCO = N'Banco Estado', @NUMERO_OPERACION = N'DEMO-000002',
         @ARCHIVO = @ARCHIVO, @USUARIO = @ROOT

    EXEC [dbo].[INS_SUSCRIPCION_PAGO]
         @ID = @P3 OUTPUT, @PERIODO = @PERIODO,
         @MONTO_DECLARADO = 1000.00, @FECHA_TRANSFERENCIA = '2026-08-22',
         @BANCO = N'Banco Santander', @NUMERO_OPERACION = N'DEMO-000003',
         @ARCHIVO = @ARCHIVO, @USUARIO = @ROOT

    -- El segundo nace rechazado, para tener que corregir.
    EXEC [dbo].[UPD_SUSCRIPCION_PAGO_VERIFICAR]
         @ID = @P2, @VERIFICADO = 0,
         @MOTIVO_RECHAZO = N'El numero de operacion no aparece en la cartola del banco.',
         @USUARIO = @ROOT

    PRINT '--- T-2212: 3 pagos de prueba cargados sobre el periodo indicado.'
END
GO


/* ========================================================================
   4. VERIFICACION
   ======================================================================== */
PRINT '--- Los dos SPs que faltaban ---'
SELECT  name, create_date
FROM    sys.objects
WHERE   name IN ('DEL_PLAN_COMERCIAL', 'UPD_SUSCRIPCION_PAGO')

PRINT '--- Pagos cargados ---'
SELECT  spa.spa_id, spa.spa_suscripcion_periodo, spa.spa_monto_declarado_clp,
        spa.spa_numero_operacion, spo.spo_codigo AS estado, spa.spa_motivo_rechazo
FROM    [dbo].[Suscripcion_Pago] spa
JOIN    [dbo].[Suscripcion_Pago_Estado] spo ON spo.spo_id = spa.spa_suscripcion_pago_estado
ORDER BY spa.spa_id
GO
