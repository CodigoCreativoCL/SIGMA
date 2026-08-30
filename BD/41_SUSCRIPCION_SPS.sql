USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     BLOQUE B. SPs DE SUSCRIPCION, PERIODOS Y PAGOS.
-- =============================================
-- Va DESPUES de 40_SUSCRIPCION_UF.
--
-- LAS REGLAS QUE ESTE BLOQUE HACE CUMPLIR (ANEXO F)
--
--   §4.3  El valor de UF usado en una transaccion SE CONGELA en la
--         transaccion. Suscripcion_Periodo guarda el numero, no una
--         referencia: abrir un comprobante de hace dos anos tiene que
--         mostrar el monto que se cobro, no uno recalculado con la UF de
--         hoy.
--
--   §6.1  VENCIDA y EN GRACIA NO se guardan: se calculan. Un estado que
--         cambia solo porque paso el tiempo no puede depender de que un
--         job haya corrido anoche. Aqui se consulta siempre por
--         FNC_SUSCRIPCION_VIGENTE, que ya existe.
--
--   §8    Upgrade inmediato con prorrateo; downgrade al cierre del
--         periodo, sin devolucion.
--
-- DOS DECISIONES QUE SE TOMAN AQUI
--
--   1. La suscripcion NO nace dentro de INS_CLIENTE. Un cliente puede
--      existir antes de que se cierre el trato comercial, y obligar a
--      elegir plan en el alta impediria registrarlo mientras se negocia.
--      Es un paso aparte: INS_SUSCRIPCION.
--
--   2. La implantacion se soporta como un periodo mas, marcado con
--      spe_es_implantacion = 1 y con su propio monto en UF. No se cobra
--      por defecto porque no hay ningun precio de implantacion definido en
--      el modelo comercial: inventar uno seria facturar un numero que
--      nadie acordo.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. SEL_PLAN_COMERCIAL

      Los planes con su precio VIGENTE por periodicidad. El precio es
      versionado (§3.3): se elige el que corresponde a la fecha, no el
      ultimo que se cargo, para que cambiar la lista de precios no altere
      lo ya cotizado.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_COMERCIAL]
@ID             INT = NULL,
@PERIODICIDAD   INT = NULL,
@FECHA          DATE = NULL,
@SOLO_PUBLICOS  BIT = NULL,
@HABILITADO     BIT = NULL

AS
SET NOCOUNT ON

SET @FECHA = ISNULL(@FECHA, CAST(GETDATE() AS DATE))

    SELECT  p.plc_id                      AS PLC_ID,
            p.plc_codigo                  AS PLC_CODIGO,
            p.plc_nombre                  AS PLC_NOMBRE,
            p.plc_descripcion             AS PLC_DESCRIPCION,
            p.plc_dias_gracia             AS PLC_DIAS_GRACIA,
            p.plc_publico                 AS PLC_PUBLICO,
            p.plc_orden                   AS PLC_ORDEN,
            p.plc_habilitado              AS PLC_HABILITADO,
            pc.pcb_id                     AS PCB_ID,
            pc.pcb_codigo                 AS PCB_CODIGO,
            pc.pcb_nombre                 AS PCB_NOMBRE,
            pr.pcp_id                     AS PCP_ID,
            pr.pcp_valor_uf               AS PCP_VALOR_UF,
            pr.pcp_descuento_porcentaje   AS PCP_DESCUENTO_PORCENTAJE,
            -- Lo que costaria hoy, para mostrarlo en pantalla. NO es lo que
            -- se cobra: eso se congela recien al emitir el periodo.
            CAST(ROUND(pr.pcp_valor_uf * ISNULL([dbo].[FNC_VALOR_UF](@FECHA), 0), 0) AS DECIMAL(18,0))
                                          AS MONTO_CLP_REFERENCIAL,
            [dbo].[FNC_VALOR_UF](@FECHA)  AS VALOR_UF_DIA
    FROM    [dbo].[Plan_Comercial] p
    INNER JOIN [dbo].[Plan_Comercial_Precio] pr ON pr.pcp_plan_comercial = p.plc_id
    INNER JOIN [dbo].[Periodicidad_Cobro] pc    ON pc.pcb_id = pr.pcp_periodicidad_cobro
    WHERE   (@ID IS NULL OR p.plc_id = @ID)
      AND   (@PERIODICIDAD IS NULL OR pr.pcp_periodicidad_cobro = @PERIODICIDAD)
      AND   (@SOLO_PUBLICOS IS NULL OR @SOLO_PUBLICOS = 0 OR p.plc_publico = 1)
      AND   (@HABILITADO IS NULL OR p.plc_habilitado = @HABILITADO)
      AND   pr.pcp_habilitado = 1
      AND   pr.pcp_vigencia_desde <= @FECHA
      AND   (pr.pcp_vigencia_hasta IS NULL OR pr.pcp_vigencia_hasta >= @FECHA)
    ORDER BY p.plc_orden, pc.pcb_orden

RETURN(0)
GO


/* ========================================================================
   2. SEL_SUSCRIPCION

      El estado NO se calcula aqui: se pide a FNC_SUSCRIPCION_VIGENTE, que
      es la unica fuente de verdad y la misma que usa la API y el armado
      del token. Duplicar la regla aqui garantizaria que algun dia la web y
      la app dijeran cosas distintas sobre el mismo cliente.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_SUSCRIPCION]
@ID       INT = NULL,
@CLIENTE  INT = NULL

AS
SET NOCOUNT ON

    SELECT  s.sus_id                    AS SUS_ID,
            s.sus_cliente               AS SUS_CLIENTE,
            c.cli_nombre                AS CLI_NOMBRE,
            s.sus_key_prefijo           AS SUS_KEY_PREFIJO,
            s.sus_suscripcion_estado    AS SUS_SUSCRIPCION_ESTADO,
            e.sue_nombre                AS SUE_NOMBRE,
            s.sus_plan_comercial        AS SUS_PLAN_COMERCIAL,
            p.plc_codigo                AS PLC_CODIGO,
            p.plc_nombre                AS PLC_NOMBRE,
            s.sus_fecha_inicio          AS SUS_FECHA_INICIO,
            s.sus_fecha_fin             AS SUS_FECHA_FIN,
            s.sus_dias_gracia           AS SUS_DIAS_GRACIA,
            s.sus_contacto_nombre       AS SUS_CONTACTO_NOMBRE,
            s.sus_contacto_email        AS SUS_CONTACTO_EMAIL,
            s.sus_contacto_telefono     AS SUS_CONTACTO_TELEFONO,
            s.sus_observacion           AS SUS_OBSERVACION,
            s.sus_habilitado            AS SUS_HABILITADO,
            v.ESTADO                    AS ESTADO,
            v.DIAS_RESTANTES            AS DIAS_RESTANTES,
            v.PUEDE_OPERAR              AS PUEDE_OPERAR
    FROM    [dbo].[Suscripcion] s
    INNER JOIN [dbo].[Cliente] c              ON c.cli_id  = s.sus_cliente
    INNER JOIN [dbo].[Suscripcion_Estado] e   ON e.sue_id  = s.sus_suscripcion_estado
    LEFT  JOIN [dbo].[Plan_Comercial] p       ON p.plc_id  = s.sus_plan_comercial
    OUTER APPLY [dbo].[FNC_SUSCRIPCION_VIGENTE](s.sus_key_hash) v
    WHERE   (@ID IS NULL OR s.sus_id = @ID)
      AND   (@CLIENTE IS NULL OR s.sus_cliente = @CLIENTE)
    ORDER BY c.cli_nombre

RETURN(0)
GO


/* ========================================================================
   3. INS_SUSCRIPCION

      Una por cliente, para siempre (§5.1). La clave la genera la
      aplicacion y llega partida: el prefijo se guarda visible para poder
      identificarla en soporte, y del resto solo se guarda el hash.

      sus_fecha_fin nace NULL: todavia no se ha emitido ningun periodo, asi
      que la suscripcion existe pero no habilita nada. Es correcto -y
      FNC_SUSCRIPCION_VIGENTE ya lo trata como VENCIDA- porque cobrar es lo
      que la pone en marcha.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_SUSCRIPCION]
@ID                INT = NULL OUTPUT,
@CLIENTE           INT,
@PLAN_COMERCIAL    INT,
@KEY_PREFIJO       NVARCHAR(20),
@KEY_TEXTO         VARCHAR(200),
@CONTACTO_NOMBRE   NVARCHAR(200) = NULL,
@CONTACTO_EMAIL    NVARCHAR(200) = NULL,
@CONTACTO_TELEFONO NVARCHAR(50) = NULL,
@OBSERVACION       NVARCHAR(1000) = NULL,
@USUARIO           INT

AS
SET NOCOUNT ON

DECLARE @DIAS_GRACIA INT

BEGIN
    IF EXISTS (SELECT 1 FROM [dbo].[Suscripcion] WHERE sus_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- ESTE CLIENTE YA TIENE UNA SUSCRIPCIÓN. USE EL CAMBIO DE PLAN O LA RENOVACIÓN.', 16, 1)
        RETURN -1
    END

    SELECT @DIAS_GRACIA = plc_dias_gracia
      FROM [dbo].[Plan_Comercial]
     WHERE plc_id = @PLAN_COMERCIAL AND plc_habilitado = 1

    IF @DIAS_GRACIA IS NULL
    BEGIN
        RAISERROR('2.- EL PLAN COMERCIAL NO EXISTE O ESTÁ DESHABILITADO.', 16, 1)
        RETURN -1
    END

    IF @KEY_TEXTO IS NULL OR LEN(@KEY_TEXTO) < 16
    BEGIN
        RAISERROR('3.- LA CLAVE DE SUSCRIPCIÓN NO ES VÁLIDA.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Suscripcion]
        (sus_cliente, sus_key_prefijo, sus_key_hash, sus_suscripcion_estado,
         sus_plan_comercial, sus_fecha_inicio, sus_fecha_fin, sus_dias_gracia,
         sus_fecha_emision_key_utc, sus_contacto_nombre, sus_contacto_email,
         sus_contacto_telefono, sus_observacion,
         sus_usuario_creacion, sus_fecha_creacion,
         sus_usuario_actualizacion, sus_fecha_actualizacion, sus_habilitado)
    VALUES
        (@CLIENTE, @KEY_PREFIJO, HASHBYTES('SHA2_256', @KEY_TEXTO), 1,
         @PLAN_COMERCIAL, CAST(GETDATE() AS DATE), NULL, @DIAS_GRACIA,
         GETUTCDATE(), @CONTACTO_NOMBRE, @CONTACTO_EMAIL,
         @CONTACTO_TELEFONO, @OBSERVACION,
         @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_SUSCRIPCION @CLIENTE = ' + LTRIM(STR(@CLIENTE))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '4.- NO FUE POSIBLE CREAR LA SUSCRIPCIÓN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   4. UPD_SUSCRIPCION

      Suspender, reactivar, cancelar y mantener el contacto. El plan NO se
      cambia por aqui: eso tiene consecuencias de cobro y va por
      UPS_SUSCRIPCION_PLAN.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_SUSCRIPCION]
@ID                INT,
@ESTADO            INT = NULL,
@CONTACTO_NOMBRE   NVARCHAR(200) = NULL,
@CONTACTO_EMAIL    NVARCHAR(200) = NULL,
@CONTACTO_TELEFONO NVARCHAR(50) = NULL,
@OBSERVACION       NVARCHAR(1000) = NULL,
@HABILITADO        BIT = NULL,
@USUARIO           INT

AS
SET NOCOUNT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Suscripcion]
    SET     sus_suscripcion_estado    = ISNULL(@ESTADO, sus_suscripcion_estado),
            sus_contacto_nombre       = @CONTACTO_NOMBRE,
            sus_contacto_email        = @CONTACTO_EMAIL,
            sus_contacto_telefono     = @CONTACTO_TELEFONO,
            sus_observacion           = @OBSERVACION,
            sus_habilitado            = ISNULL(@HABILITADO, sus_habilitado),
            sus_usuario_actualizacion = @USUARIO,
            sus_fecha_actualizacion   = GETDATE()
    WHERE   sus_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_SUSCRIPCION @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '1.- NO FUE POSIBLE ACTUALIZAR LA SUSCRIPCIÓN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   5. INS_SUSCRIPCION_PERIODO                                        §4.3

      EMITIR ES CONGELAR. Se guardan tres numeros y no una referencia:

        spe_valor_uf_plan  cuantas UF cuesta el periodo
        spe_valor_uf_dia   cuantos pesos valia una UF ese dia
        spe_monto_clp      el producto, que es lo que se cobra

      Si en vez de eso se guardara una FK a Valor_Uf, abrir el comprobante
      dentro de dos anos recalcularia con la UF de entonces y mostraria un
      monto que nadie pago nunca.

      El periodo arranca donde termina el anterior, no en la fecha de hoy:
      pagar con tres dias de atraso no debe regalar ni quitar dias.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_SUSCRIPCION_PERIODO]
@ID                INT = NULL OUTPUT,
@SUSCRIPCION       INT,
@PERIODICIDAD      INT,
@PLAN_COMERCIAL    INT = NULL,
@FECHA_INICIO      DATE = NULL,
@ES_IMPLANTACION   BIT = 0,
@VALOR_UF_MANUAL   DECIMAL(18,4) = NULL,
@OBSERVACION       NVARCHAR(1000) = NULL,
@USUARIO           INT

AS
SET NOCOUNT ON

DECLARE @CLIENTE      INT,
        @FIN_ANTERIOR DATE,
        @UF_PLAN      DECIMAL(18,4),
        @UF_DIA       DECIMAL(18,4),
        @FECHA_UF     DATE = CAST(GETDATE() AS DATE),
        @FECHA_FIN    DATE,
        @MESES        INT,
        @MONTO        DECIMAL(18,2)

BEGIN
    SELECT @CLIENTE = sus_cliente,
           @PLAN_COMERCIAL = ISNULL(@PLAN_COMERCIAL, sus_plan_comercial),
           @FIN_ANTERIOR = sus_fecha_fin
      FROM [dbo].[Suscripcion]
     WHERE sus_id = @SUSCRIPCION

    IF @CLIENTE IS NULL
    BEGIN
        RAISERROR('1.- LA SUSCRIPCIÓN NO EXISTE.', 16, 1)
        RETURN -1
    END

    SELECT @MESES = CASE pcb_codigo
                        WHEN N'MENSUAL'    THEN 1
                        WHEN N'TRIMESTRAL' THEN 3
                        WHEN N'ANUAL'      THEN 12
                    END
      FROM [dbo].[Periodicidad_Cobro]
     WHERE pcb_id = @PERIODICIDAD AND pcb_habilitado = 1

    IF @MESES IS NULL
    BEGIN
        RAISERROR('2.- LA PERIODICIDAD DE COBRO NO ES VÁLIDA.', 16, 1)
        RETURN -1
    END

    /* El periodo continua donde termino el anterior. Solo cuando no hay
       ninguno -o el anterior quedo muy atras- se parte de hoy. */
    SET @FECHA_INICIO = ISNULL(@FECHA_INICIO,
                               CASE WHEN @FIN_ANTERIOR IS NULL OR @FIN_ANTERIOR < CAST(GETDATE() AS DATE)
                                    THEN CAST(GETDATE() AS DATE)
                                    ELSE DATEADD(DAY, 1, @FIN_ANTERIOR) END)

    SET @FECHA_FIN = DATEADD(DAY, -1, DATEADD(MONTH, @MESES, @FECHA_INICIO))

    -- El precio VIGENTE del plan para esa periodicidad.
    IF @VALOR_UF_MANUAL IS NOT NULL
        SET @UF_PLAN = @VALOR_UF_MANUAL
    ELSE
        SELECT TOP 1 @UF_PLAN = pcp_valor_uf
          FROM [dbo].[Plan_Comercial_Precio]
         WHERE pcp_plan_comercial = @PLAN_COMERCIAL
           AND pcp_periodicidad_cobro = @PERIODICIDAD
           AND pcp_habilitado = 1
           AND pcp_vigencia_desde <= @FECHA_UF
           AND (pcp_vigencia_hasta IS NULL OR pcp_vigencia_hasta >= @FECHA_UF)
         ORDER BY pcp_vigencia_desde DESC

    /* La implantacion no tiene precio definido en el modelo comercial. Sin
       un valor explicito se emite en cero en vez de inventar uno: un cobro
       con un numero que nadie acordo es peor que un cobro en cero. */
    IF @ES_IMPLANTACION = 1 AND @VALOR_UF_MANUAL IS NULL
        SET @UF_PLAN = 0

    IF @UF_PLAN IS NULL
    BEGIN
        RAISERROR('3.- EL PLAN NO TIENE PRECIO VIGENTE PARA ESA PERIODICIDAD.', 16, 1)
        RETURN -1
    END

    SET @UF_DIA = [dbo].[FNC_VALOR_UF](@FECHA_UF)

    IF @UF_DIA IS NULL OR @UF_DIA <= 0
    BEGIN
        RAISERROR('4.- NO HAY VALOR DE UF CARGADO. NO SE PUEDE EMITIR UN PERÍODO SIN ÉL.', 16, 1)
        RETURN -1
    END

    SET @MONTO = ROUND(@UF_PLAN * @UF_DIA, 0)
END

BEGIN TRANSACTION

    INSERT [dbo].[Suscripcion_Periodo]
        (spe_suscripcion, spe_plan_comercial, spe_periodicidad_cobro,
         spe_fecha_inicio, spe_fecha_fin,
         spe_valor_uf_plan, spe_valor_uf_dia, spe_fecha_valor_uf,
         spe_monto_clp, spe_monto_pagado_clp, spe_suscripcion_periodo_estado,
         spe_es_implantacion, spe_observacion,
         spe_usuario_creacion, spe_fecha_creacion,
         spe_usuario_actualizacion, spe_fecha_actualizacion, spe_habilitado)
    VALUES
        (@SUSCRIPCION, @PLAN_COMERCIAL, @PERIODICIDAD,
         @FECHA_INICIO, @FECHA_FIN,
         @UF_PLAN, @UF_DIA, @FECHA_UF,
         @MONTO, 0, 1,                       -- 1 = PENDIENTE PAGO
         @ES_IMPLANTACION, @OBSERVACION,
         @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_SUSCRIPCION_PERIODO @SUSCRIPCION = ' + LTRIM(STR(@SUSCRIPCION))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '5.- NO FUE POSIBLE EMITIR EL PERÍODO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   6. SEL_SUSCRIPCION_PERIODO
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_SUSCRIPCION_PERIODO]
@ID           INT = NULL,
@SUSCRIPCION  INT = NULL,
@CLIENTE      INT = NULL,
@ESTADO       INT = NULL,
@SOLO_IMPAGOS BIT = NULL

AS
SET NOCOUNT ON

    SELECT  sp.spe_id                      AS SPE_ID,
            sp.spe_suscripcion             AS SPE_SUSCRIPCION,
            s.sus_cliente                  AS SUS_CLIENTE,
            c.cli_nombre                   AS CLI_NOMBRE,
            sp.spe_plan_comercial          AS SPE_PLAN_COMERCIAL,
            p.plc_nombre                   AS PLC_NOMBRE,
            pc.pcb_nombre                  AS PCB_NOMBRE,
            sp.spe_fecha_inicio            AS SPE_FECHA_INICIO,
            sp.spe_fecha_fin               AS SPE_FECHA_FIN,
            sp.spe_valor_uf_plan           AS SPE_VALOR_UF_PLAN,
            sp.spe_valor_uf_dia            AS SPE_VALOR_UF_DIA,
            sp.spe_fecha_valor_uf          AS SPE_FECHA_VALOR_UF,
            sp.spe_monto_clp               AS SPE_MONTO_CLP,
            sp.spe_monto_pagado_clp        AS SPE_MONTO_PAGADO_CLP,
            sp.spe_monto_clp - sp.spe_monto_pagado_clp AS SALDO_CLP,
            sp.spe_suscripcion_periodo_estado AS SPE_ESTADO,
            pe.spd_nombre                  AS SPD_NOMBRE,
            sp.spe_es_implantacion         AS SPE_ES_IMPLANTACION,
            sp.spe_observacion             AS SPE_OBSERVACION,
            sp.spe_habilitado              AS SPE_HABILITADO
    FROM    [dbo].[Suscripcion_Periodo] sp
    INNER JOIN [dbo].[Suscripcion] s                  ON s.sus_id  = sp.spe_suscripcion
    INNER JOIN [dbo].[Cliente] c                      ON c.cli_id  = s.sus_cliente
    LEFT  JOIN [dbo].[Plan_Comercial] p               ON p.plc_id  = sp.spe_plan_comercial
    LEFT  JOIN [dbo].[Periodicidad_Cobro] pc          ON pc.pcb_id = sp.spe_periodicidad_cobro
    INNER JOIN [dbo].[Suscripcion_Periodo_Estado] pe  ON pe.spd_id = sp.spe_suscripcion_periodo_estado
    WHERE   (@ID IS NULL OR sp.spe_id = @ID)
      AND   (@SUSCRIPCION IS NULL OR sp.spe_suscripcion = @SUSCRIPCION)
      AND   (@CLIENTE IS NULL OR s.sus_cliente = @CLIENTE)
      AND   (@ESTADO IS NULL OR sp.spe_suscripcion_periodo_estado = @ESTADO)
      AND   (@SOLO_IMPAGOS IS NULL OR @SOLO_IMPAGOS = 0
             OR sp.spe_monto_pagado_clp < sp.spe_monto_clp)
    ORDER BY sp.spe_fecha_inicio DESC

RETURN(0)
GO


/* ========================================================================
   7. INS_SUSCRIPCION_PAGO

      El cliente declara una transferencia y adjunta el comprobante. NO se
      da por pagado: nace DECLARADO y alguien lo verifica contra la cartola
      (§5.4). Un abono que se aceptara solo porque el cliente lo escribio
      seria una factura pagada por decreto.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_SUSCRIPCION_PAGO]
@ID                 INT = NULL OUTPUT,
@PERIODO            INT,
@MONTO_DECLARADO    DECIMAL(18,2),
@FECHA_TRANSFERENCIA DATE,
@BANCO              NVARCHAR(100) = NULL,
@NUMERO_OPERACION   NVARCHAR(100) = NULL,
@ARCHIVO            INT,
@USUARIO            INT

AS
SET NOCOUNT ON

BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Periodo]
                    WHERE spe_id = @PERIODO AND spe_habilitado = 1)
    BEGIN
        RAISERROR('1.- EL PERÍODO NO EXISTE O ESTÁ ANULADO.', 16, 1)
        RETURN -1
    END

    /* El comprobante es OBLIGATORIO: spa_archivo es NOT NULL en el modelo.
       No es un descuido de la tabla, es la regla — §5.3 llama a esto "el
       abono con comprobante" y §5.4 describe cómo se analiza. Un abono sin
       respaldo no se puede verificar contra la cartola, que es justamente
       lo que convierte una declaración en un pago. */
    IF @ARCHIVO IS NULL
    BEGIN
        RAISERROR('2.- DEBE ADJUNTAR EL COMPROBANTE DE LA TRANSFERENCIA.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo] WHERE arc_id = @ARCHIVO)
    BEGIN
        RAISERROR('3.- EL COMPROBANTE INDICADO NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @MONTO_DECLARADO IS NULL OR @MONTO_DECLARADO <= 0
    BEGIN
        RAISERROR('4.- EL MONTO DECLARADO DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END

    /* El numero de operacion se repite = el mismo comprobante cargado dos
       veces. Sin esto, un doble clic duplica el abono y el periodo queda
       pagado dos veces. */
    IF @NUMERO_OPERACION IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Pago]
                    WHERE spa_numero_operacion = @NUMERO_OPERACION
                      AND spa_habilitado = 1)
    BEGIN
        RAISERROR('5.- YA EXISTE UN PAGO REGISTRADO CON EL NÚMERO DE OPERACIÓN "%s".', 16, 1, @NUMERO_OPERACION)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Suscripcion_Pago]
        (spa_suscripcion_periodo, spa_monto_declarado_clp, spa_monto_verificado_clp,
         spa_fecha_transferencia, spa_banco, spa_numero_operacion, spa_archivo,
         spa_suscripcion_pago_estado, spa_usuario_creacion, spa_fecha_creacion,
         spa_usuario_actualizacion, spa_fecha_actualizacion, spa_habilitado)
    VALUES
        (@PERIODO, @MONTO_DECLARADO, NULL,
         @FECHA_TRANSFERENCIA, @BANCO, @NUMERO_OPERACION, @ARCHIVO,
         1, @USUARIO, GETDATE(),          -- 1 = DECLARADO
         @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_SUSCRIPCION_PAGO @PERIODO = ' + LTRIM(STR(@PERIODO))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '4.- NO FUE POSIBLE REGISTRAR EL PAGO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   8. UPD_SUSCRIPCION_PAGO_VERIFICAR

      Aqui es donde un pago se vuelve real. Hace cuatro cosas en una sola
      transaccion, porque a medias dejarian la cuenta descuadrada:

        1. Marca el pago verificado o rechazado.
        2. Recalcula lo pagado del periodo sumando SOLO los verificados.
        3. Mueve el estado del periodo segun ese total.
        4. Si quedo cubierto, extiende sus_fecha_fin de la suscripcion.

      LA TOLERANCIA. Una transferencia rara vez calza al peso: hay
      comisiones y redondeos. Sys_Parametros define cuanto se acepta de
      diferencia, en pesos y en porcentaje, y se toma la mayor de las dos.
      Sin esto, un periodo de $370.000 pagado con $369.998 quedaria
      eternamente impago por dos pesos.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_SUSCRIPCION_PAGO_VERIFICAR]
@ID               INT,
@VERIFICADO       BIT,
@MONTO_VERIFICADO DECIMAL(18,2) = NULL,
@MOTIVO_RECHAZO   NVARCHAR(500) = NULL,
@USUARIO          INT

AS
SET NOCOUNT ON

DECLARE @PERIODO INT, @SUSCRIPCION INT, @FECHA_FIN DATE,
        @MONTO DECIMAL(18,2), @PAGADO DECIMAL(18,2),
        @TOL_CLP DECIMAL(18,2), @TOL_PCT DECIMAL(18,4), @TOLERANCIA DECIMAL(18,2)

BEGIN
    SELECT @PERIODO = spa_suscripcion_periodo
      FROM [dbo].[Suscripcion_Pago] WHERE spa_id = @ID

    IF @PERIODO IS NULL
    BEGIN
        RAISERROR('1.- EL PAGO NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @VERIFICADO = 0 AND (@MOTIVO_RECHAZO IS NULL OR LEN(LTRIM(@MOTIVO_RECHAZO)) < 5)
    BEGIN
        RAISERROR('2.- INDIQUE EL MOTIVO DEL RECHAZO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    -- 1. El pago
    UPDATE  [dbo].[Suscripcion_Pago]
    SET     spa_suscripcion_pago_estado = CASE WHEN @VERIFICADO = 1 THEN 3 ELSE 4 END,
            spa_monto_verificado_clp    = CASE WHEN @VERIFICADO = 1
                                               THEN ISNULL(@MONTO_VERIFICADO, spa_monto_declarado_clp)
                                               ELSE NULL END,
            spa_usuario_verificador     = @USUARIO,
            spa_fecha_verificacion_utc  = GETUTCDATE(),
            spa_motivo_rechazo          = @MOTIVO_RECHAZO,
            spa_usuario_actualizacion   = @USUARIO,
            spa_fecha_actualizacion     = GETDATE()
    WHERE   spa_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_SUSCRIPCION_PAGO_VERIFICAR @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '3.- NO FUE POSIBLE VERIFICAR EL PAGO.'
        RETURN -1
    END

    /* 2. Lo pagado se RECALCULA sumando los verificados, no se incrementa.
          Sumar sobre lo que ya habia dejaria el total mal en cuanto
          alguien corrija o revierta una verificacion. */
    SELECT @PAGADO = ISNULL(SUM(ISNULL(spa_monto_verificado_clp, 0)), 0)
      FROM [dbo].[Suscripcion_Pago]
     WHERE spa_suscripcion_periodo = @PERIODO
       AND spa_suscripcion_pago_estado = 3
       AND spa_habilitado = 1

    SELECT @MONTO = spe_monto_clp, @SUSCRIPCION = spe_suscripcion, @FECHA_FIN = spe_fecha_fin
      FROM [dbo].[Suscripcion_Periodo] WHERE spe_id = @PERIODO

    -- Tolerancia: la mayor entre el monto fijo y el porcentaje.
    SELECT @TOL_CLP = TRY_CAST(par_valor AS DECIMAL(18,2))
      FROM [dbo].[Sys_Parametros] WHERE par_codigo = 'SUSCRIPCION_TOLERANCIA_CLP'
    SELECT @TOL_PCT = TRY_CAST(par_valor AS DECIMAL(18,4))
      FROM [dbo].[Sys_Parametros] WHERE par_codigo = 'SUSCRIPCION_TOLERANCIA_PORCENTAJE'

    SET @TOLERANCIA = CASE
        WHEN ISNULL(@TOL_CLP, 0) > (@MONTO * ISNULL(@TOL_PCT, 0) / 100.0)
        THEN ISNULL(@TOL_CLP, 0)
        ELSE (@MONTO * ISNULL(@TOL_PCT, 0) / 100.0) END

    DECLARE @CUBIERTO BIT = CASE WHEN @PAGADO >= (@MONTO - @TOLERANCIA) THEN 1 ELSE 0 END

    -- 3. El estado del periodo
    UPDATE  [dbo].[Suscripcion_Periodo]
    SET     spe_monto_pagado_clp          = @PAGADO,
            spe_suscripcion_periodo_estado = CASE
                                                WHEN @CUBIERTO = 1  THEN 3   -- VIGENTE
                                                WHEN @PAGADO > 0    THEN 2   -- PAGO PARCIAL
                                                ELSE 1                       -- PENDIENTE PAGO
                                             END,
            spe_usuario_actualizacion     = @USUARIO,
            spe_fecha_actualizacion       = GETDATE()
    WHERE   spe_id = @PERIODO

    /* 4. Recien con el periodo cubierto la suscripcion se extiende.
          Se toma la fecha mayor entre la que ya tenia y la del periodo:
          verificar un pago atrasado no debe ACORTAR una vigencia. */
    IF @CUBIERTO = 1
        UPDATE  [dbo].[Suscripcion]
        SET     sus_fecha_fin             = CASE WHEN sus_fecha_fin IS NULL OR sus_fecha_fin < @FECHA_FIN
                                                 THEN @FECHA_FIN ELSE sus_fecha_fin END,
                sus_usuario_actualizacion = @USUARIO,
                sus_fecha_actualizacion   = GETDATE()
        WHERE   sus_id = @SUSCRIPCION

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   9. SEL_SUSCRIPCION_PAGO

      Alimenta la bandeja de verificacion. @SOLO_PENDIENTES trae lo que
      espera revision.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_SUSCRIPCION_PAGO]
@ID               INT = NULL,
@PERIODO          INT = NULL,
@CLIENTE          INT = NULL,
@SOLO_PENDIENTES  BIT = NULL

AS
SET NOCOUNT ON

    SELECT  pg.spa_id                     AS SPA_ID,
            pg.spa_suscripcion_periodo    AS SPA_PERIODO,
            s.sus_cliente                 AS SUS_CLIENTE,
            c.cli_nombre                  AS CLI_NOMBRE,
            pg.spa_monto_declarado_clp    AS SPA_MONTO_DECLARADO_CLP,
            pg.spa_monto_verificado_clp   AS SPA_MONTO_VERIFICADO_CLP,
            pg.spa_fecha_transferencia    AS SPA_FECHA_TRANSFERENCIA,
            pg.spa_banco                  AS SPA_BANCO,
            pg.spa_numero_operacion       AS SPA_NUMERO_OPERACION,
            pg.spa_archivo                AS SPA_ARCHIVO,
            pg.spa_suscripcion_pago_estado AS SPA_ESTADO,
            pe.spo_nombre                 AS SPO_NOMBRE,
            pe.spo_codigo                 AS SPO_CODIGO,
            pg.spa_motivo_rechazo         AS SPA_MOTIVO_RECHAZO,
            pg.spa_fecha_verificacion_utc AS SPA_FECHA_VERIFICACION_UTC,
            v.usu_nombre + SPACE(1) + v.usu_apellido_paterno AS VERIFICADO_POR,
            sp.spe_monto_clp              AS SPE_MONTO_CLP,
            sp.spe_fecha_inicio           AS SPE_FECHA_INICIO,
            sp.spe_fecha_fin              AS SPE_FECHA_FIN
    FROM    [dbo].[Suscripcion_Pago] pg
    INNER JOIN [dbo].[Suscripcion_Periodo] sp        ON sp.spe_id = pg.spa_suscripcion_periodo
    INNER JOIN [dbo].[Suscripcion] s                 ON s.sus_id  = sp.spe_suscripcion
    INNER JOIN [dbo].[Cliente] c                     ON c.cli_id  = s.sus_cliente
    INNER JOIN [dbo].[Suscripcion_Pago_Estado] pe    ON pe.spo_id = pg.spa_suscripcion_pago_estado
    LEFT  JOIN [dbo].[Usuario] v                     ON v.usu_id  = pg.spa_usuario_verificador
    WHERE   (@ID IS NULL OR pg.spa_id = @ID)
      AND   (@PERIODO IS NULL OR pg.spa_suscripcion_periodo = @PERIODO)
      AND   (@CLIENTE IS NULL OR s.sus_cliente = @CLIENTE)
      AND   (@SOLO_PENDIENTES IS NULL OR @SOLO_PENDIENTES = 0
             OR pg.spa_suscripcion_pago_estado IN (1, 2))
      AND   pg.spa_habilitado = 1
    ORDER BY pg.spa_fecha_transferencia DESC

RETURN(0)
GO


/* ========================================================================
   10. UPS_SUSCRIPCION_PLAN                                          §8

       Upgrade  -> inmediato. Se cierra el periodo actual y se emite uno
                   nuevo por los dias que faltaban, cobrando la DIFERENCIA
                   prorrateada. El cliente usa lo nuevo el mismo dia.

       Downgrade -> al cierre. No hay devolucion: evita el ciclo de subir
                   un mes, usar el predictivo y bajar.

       Lo que excede los limites del plan nuevo NO se borra (§8): queda en
       solo lectura. Este SP no borra nada; de mostrarlo se encarga la
       pantalla leyendo FNC_CLIENTE_LIMITE.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPS_SUSCRIPCION_PLAN]
@SUSCRIPCION     INT,
@PLAN_NUEVO      INT,
@PERIODICIDAD    INT = NULL,
@USUARIO         INT,
@PERIODO_NUEVO   INT = NULL OUTPUT,
@MOVIMIENTO      NVARCHAR(20) = NULL OUTPUT

AS
SET NOCOUNT ON

DECLARE @PLAN_ACTUAL INT, @UF_ACTUAL DECIMAL(18,4), @UF_NUEVO DECIMAL(18,4),
        @PERIODO INT, @INICIO DATE, @FIN DATE, @PERIODICIDAD_ACTUAL INT,
        @HOY DATE = CAST(GETDATE() AS DATE),
        @DIAS_TOTAL INT, @DIAS_RESTAN INT,
        @UF_DIA DECIMAL(18,4), @UF_DIFERENCIA DECIMAL(18,4), @MONTO DECIMAL(18,2)

SET @PERIODO_NUEVO = NULL

BEGIN
    SELECT @PLAN_ACTUAL = sus_plan_comercial FROM [dbo].[Suscripcion] WHERE sus_id = @SUSCRIPCION

    IF @PLAN_ACTUAL IS NULL
    BEGIN
        RAISERROR('1.- LA SUSCRIPCIÓN NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @PLAN_ACTUAL = @PLAN_NUEVO
    BEGIN
        RAISERROR('2.- LA SUSCRIPCIÓN YA ESTÁ EN ESE PLAN.', 16, 1)
        RETURN -1
    END

    -- El periodo vigente: el que contiene el dia de hoy y esta pagado.
    SELECT TOP 1 @PERIODO = spe_id, @INICIO = spe_fecha_inicio, @FIN = spe_fecha_fin,
                 @PERIODICIDAD_ACTUAL = spe_periodicidad_cobro
      FROM [dbo].[Suscripcion_Periodo]
     WHERE spe_suscripcion = @SUSCRIPCION
       AND spe_habilitado = 1
       AND spe_fecha_inicio <= @HOY AND spe_fecha_fin >= @HOY
     ORDER BY spe_fecha_inicio DESC

    SET @PERIODICIDAD = ISNULL(@PERIODICIDAD, ISNULL(@PERIODICIDAD_ACTUAL, 1))

    /* El orden del plan define que es subir y que es bajar. Se compara por
       plc_orden y no por precio: el orden es la escalera declarada del
       modelo comercial. */
    IF (SELECT plc_orden FROM [dbo].[Plan_Comercial] WHERE plc_id = @PLAN_NUEVO) >
       (SELECT plc_orden FROM [dbo].[Plan_Comercial] WHERE plc_id = @PLAN_ACTUAL)
        SET @MOVIMIENTO = N'UPGRADE'
    ELSE
        SET @MOVIMIENTO = N'DOWNGRADE'
END

/* ---- DOWNGRADE: se anota y se aplica cuando termine el periodo ----
   No se toca el periodo vigente ni se devuelve nada. */
IF @MOVIMIENTO = N'DOWNGRADE'
BEGIN
    BEGIN TRANSACTION

        UPDATE  [dbo].[Suscripcion]
        SET     sus_observacion           = ISNULL(sus_observacion + N' | ', N'') +
                                            N'Downgrade a plan ' + LTRIM(STR(@PLAN_NUEVO)) +
                                            N' solicitado el ' + CONVERT(NVARCHAR(10), @HOY, 103) +
                                            N'; se aplica al cierre del período.',
                sus_usuario_actualizacion = @USUARIO,
                sus_fecha_actualizacion   = GETDATE()
        WHERE   sus_id = @SUSCRIPCION

    COMMIT TRANSACTION

    RETURN(0)
END

/* ---- UPGRADE: inmediato, cobrando la diferencia prorrateada ---- */
IF @PERIODO IS NULL
BEGIN
    -- Sin periodo vigente no hay nada que prorratear: se cambia el plan y
    -- el proximo periodo se emite ya con el nuevo.
    BEGIN TRANSACTION
        UPDATE  [dbo].[Suscripcion]
        SET     sus_plan_comercial        = @PLAN_NUEVO,
                sus_dias_gracia           = (SELECT plc_dias_gracia FROM [dbo].[Plan_Comercial] WHERE plc_id = @PLAN_NUEVO),
                sus_usuario_actualizacion = @USUARIO,
                sus_fecha_actualizacion   = GETDATE()
        WHERE   sus_id = @SUSCRIPCION
    COMMIT TRANSACTION

    RETURN(0)
END

SELECT TOP 1 @UF_ACTUAL = pcp_valor_uf FROM [dbo].[Plan_Comercial_Precio]
 WHERE pcp_plan_comercial = @PLAN_ACTUAL AND pcp_periodicidad_cobro = @PERIODICIDAD
   AND pcp_habilitado = 1 AND pcp_vigencia_desde <= @HOY
   AND (pcp_vigencia_hasta IS NULL OR pcp_vigencia_hasta >= @HOY)
 ORDER BY pcp_vigencia_desde DESC

SELECT TOP 1 @UF_NUEVO = pcp_valor_uf FROM [dbo].[Plan_Comercial_Precio]
 WHERE pcp_plan_comercial = @PLAN_NUEVO AND pcp_periodicidad_cobro = @PERIODICIDAD
   AND pcp_habilitado = 1 AND pcp_vigencia_desde <= @HOY
   AND (pcp_vigencia_hasta IS NULL OR pcp_vigencia_hasta >= @HOY)
 ORDER BY pcp_vigencia_desde DESC

IF @UF_NUEVO IS NULL OR @UF_ACTUAL IS NULL
BEGIN
    RAISERROR('3.- FALTA EL PRECIO VIGENTE DE ALGUNO DE LOS DOS PLANES PARA ESA PERIODICIDAD.', 16, 1)
    RETURN -1
END

SET @DIAS_TOTAL  = DATEDIFF(DAY, @INICIO, @FIN) + 1
SET @DIAS_RESTAN = DATEDIFF(DAY, @HOY, @FIN) + 1
SET @UF_DIA      = [dbo].[FNC_VALOR_UF](@HOY)

IF @UF_DIA IS NULL OR @UF_DIA <= 0
BEGIN
    RAISERROR('4.- NO HAY VALOR DE UF CARGADO. NO SE PUEDE PRORRATEAR EL CAMBIO DE PLAN.', 16, 1)
    RETURN -1
END

-- Solo los dias que faltaban, y solo la diferencia entre ambos planes.
SET @UF_DIFERENCIA = (@UF_NUEVO - @UF_ACTUAL) * (CAST(@DIAS_RESTAN AS DECIMAL(18,6)) / @DIAS_TOTAL)
SET @MONTO         = ROUND(@UF_DIFERENCIA * @UF_DIA, 0)

BEGIN TRANSACTION

    -- El periodo anterior se cierra hoy: deja de cubrir lo que viene.
    UPDATE  [dbo].[Suscripcion_Periodo]
    SET     spe_fecha_fin                  = @HOY,
            spe_suscripcion_periodo_estado = 4,          -- CERRADO
            spe_observacion                = ISNULL(spe_observacion + N' | ', N'') +
                                             N'Cerrado por upgrade de plan el ' + CONVERT(NVARCHAR(10), @HOY, 103) + N'.',
            spe_usuario_actualizacion      = @USUARIO,
            spe_fecha_actualizacion        = GETDATE()
    WHERE   spe_id = @PERIODO

    -- El periodo nuevo cubre los dias que quedaban, con la diferencia.
    INSERT [dbo].[Suscripcion_Periodo]
        (spe_suscripcion, spe_plan_comercial, spe_periodicidad_cobro,
         spe_fecha_inicio, spe_fecha_fin,
         spe_valor_uf_plan, spe_valor_uf_dia, spe_fecha_valor_uf,
         spe_monto_clp, spe_monto_pagado_clp, spe_suscripcion_periodo_estado,
         spe_es_implantacion, spe_observacion,
         spe_usuario_creacion, spe_fecha_creacion,
         spe_usuario_actualizacion, spe_fecha_actualizacion, spe_habilitado)
    VALUES
        (@SUSCRIPCION, @PLAN_NUEVO, @PERIODICIDAD,
         DATEADD(DAY, 1, @HOY), @FIN,
         @UF_DIFERENCIA, @UF_DIA, @HOY,
         @MONTO, 0,
         CASE WHEN @MONTO <= 0 THEN 3 ELSE 1 END,        -- sin diferencia, ya vigente
         0,
         N'Diferencia prorrateada por upgrade: ' + LTRIM(STR(@DIAS_RESTAN)) + N' de ' +
         LTRIM(STR(@DIAS_TOTAL)) + N' días.',
         @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)

    SET @PERIODO_NUEVO = SCOPE_IDENTITY()

    UPDATE  [dbo].[Suscripcion]
    SET     sus_plan_comercial        = @PLAN_NUEVO,
            sus_dias_gracia           = (SELECT plc_dias_gracia FROM [dbo].[Plan_Comercial] WHERE plc_id = @PLAN_NUEVO),
            sus_usuario_actualizacion = @USUARIO,
            sus_fecha_actualizacion   = GETDATE()
    WHERE   sus_id = @SUSCRIPCION

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'SPs del bloque B' AS control, COUNT(*) AS valor, 9 AS esperado
FROM   sys.procedures
WHERE  name IN ('SEL_PLAN_COMERCIAL','SEL_SUSCRIPCION','INS_SUSCRIPCION','UPD_SUSCRIPCION',
                'INS_SUSCRIPCION_PERIODO','SEL_SUSCRIPCION_PERIODO','INS_SUSCRIPCION_PAGO',
                'UPD_SUSCRIPCION_PAGO_VERIFICAR','SEL_SUSCRIPCION_PAGO')
UNION ALL
SELECT 'UPS_SUSCRIPCION_PLAN', COUNT(*), 1
FROM   sys.procedures WHERE name = 'UPS_SUSCRIPCION_PLAN'
GO

-- Los planes con su precio de hoy.
EXEC [dbo].[SEL_PLAN_COMERCIAL] @HABILITADO = 1
GO
