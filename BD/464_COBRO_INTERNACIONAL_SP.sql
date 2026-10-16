/* ============================================================================
   SIGMA — Bloque 464
   CAPA INTERNACIONAL · PROCEDIMIENTOS DE PRECIO, EMISIÓN Y PAGO POR MONEDA
   ----------------------------------------------------------------------------
   Va después de 463. Regla: la moneda del período sale de Cliente.cli_moneda_cobro
   (UF -> se cobra en CLP con la UF del día; USD -> se cobra en USD, sin UF).
   Un período ya emitido conserva su moneda aunque el cliente cambie después.
   Los SP existentes siguen funcionando igual para clientes en UF: los
   parámetros nuevos son opcionales y toman UF por defecto.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

/* ---- Precio versionado: fija el precio de UNA moneda, sin tocar la otra ---- */
CREATE OR ALTER PROCEDURE [dbo].[UPS_PLAN_COMERCIAL_PRECIO]
@ID           INT = NULL OUTPUT,
@PLAN         INT,
@PERIODICIDAD INT,
@VALOR_UF     DECIMAL(18,4),
@DESCUENTO    DECIMAL(18,2) = NULL,
@DESDE        DATE = NULL,
@USUARIO      INT,
@MONEDA       VARCHAR(3) = 'UF'
AS
SET NOCOUNT ON
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE),
        @VIGENTE INT,
        @VALOR_VIGENTE DECIMAL(18,4),
        @DESDE_VIGENTE DATE
SET @DESDE = ISNULL(@DESDE, @HOY)
SET @MONEDA = UPPER(ISNULL(@MONEDA, 'UF'))
BEGIN
    IF @MONEDA NOT IN ('UF', 'USD')
    BEGIN
        RAISERROR('7.- LA MONEDA DEBE SER UF O USD.', 16, 1)
        RETURN -1
    END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE plc_id = @PLAN)
    BEGIN
        RAISERROR('1.- EL PLAN NO EXISTE.', 16, 1)
        RETURN -1
    END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Periodicidad_Cobro]
                    WHERE pcb_id = @PERIODICIDAD AND pcb_habilitado = 1)
    BEGIN
        RAISERROR('2.- LA PERIODICIDAD DE COBRO NO ES VÁLIDA.', 16, 1)
        RETURN -1
    END
    IF @VALOR_UF IS NULL OR @VALOR_UF <= 0
    BEGIN
        RAISERROR('3.- EL VALOR DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END
    IF @DESCUENTO IS NOT NULL AND (@DESCUENTO < 0 OR @DESCUENTO > 100)
    BEGIN
        RAISERROR('4.- EL DESCUENTO DEBE ESTAR ENTRE 0 Y 100.', 16, 1)
        RETURN -1
    END
    IF @DESDE < @HOY
    BEGIN
        RAISERROR('5.- NO SE PUEDE FIJAR UN PRECIO CON FECHA PASADA: ALTERARÍA LO YA COTIZADO.', 16, 1)
        RETURN -1
    END
    SELECT  @VIGENTE = pcp_id,
            @VALOR_VIGENTE = pcp_valor_uf,
            @DESDE_VIGENTE = pcp_vigencia_desde
    FROM    [dbo].[Plan_Comercial_Precio]
    WHERE   pcp_plan_comercial = @PLAN
      AND   pcp_periodicidad_cobro = @PERIODICIDAD
      AND   pcp_moneda = @MONEDA
      AND   pcp_vigencia_hasta IS NULL
      AND   pcp_habilitado = 1
    -- Mismo numero: no se versiona nada.
    IF @VIGENTE IS NOT NULL AND @VALOR_VIGENTE = @VALOR_UF
    BEGIN
        SET @ID = @VIGENTE
        RETURN(0)
    END
    -- El vigente empezó hoy o después: todavía no cubrió ningún día, se corrige la fila.
    IF @VIGENTE IS NOT NULL AND @DESDE_VIGENTE >= @DESDE
    BEGIN
        BEGIN TRANSACTION
            UPDATE  [dbo].[Plan_Comercial_Precio]
            SET     pcp_valor_uf               = @VALOR_UF,
                    pcp_descuento_porcentaje   = @DESCUENTO,
                    pcp_vigencia_desde         = @DESDE,
                    pcp_usuario_actualizacion  = @USUARIO,
                    pcp_fecha_actualizacion    = [dbo].[FNC_AHORA]()
            WHERE   pcp_id = @VIGENTE
        COMMIT TRANSACTION
        SET @ID = @VIGENTE
        RETURN(0)
    END
END
BEGIN TRANSACTION
    IF @VIGENTE IS NOT NULL
        UPDATE  [dbo].[Plan_Comercial_Precio]
        SET     pcp_vigencia_hasta        = DATEADD(DAY, -1, @DESDE),
                pcp_usuario_actualizacion = @USUARIO,
                pcp_fecha_actualizacion   = [dbo].[FNC_AHORA]()
        WHERE   pcp_id = @VIGENTE
    INSERT [dbo].[Plan_Comercial_Precio]
        (pcp_plan_comercial, pcp_periodicidad_cobro, pcp_moneda, pcp_valor_uf,
         pcp_vigencia_desde, pcp_vigencia_hasta, pcp_descuento_porcentaje,
         pcp_usuario_creacion, pcp_fecha_creacion,
         pcp_usuario_actualizacion, pcp_fecha_actualizacion, pcp_habilitado)
    VALUES
        (@PLAN, @PERIODICIDAD, @MONEDA, @VALOR_UF,
         @DESDE, NULL, @DESCUENTO,
         @USUARIO, [dbo].[FNC_AHORA](), @USUARIO, [dbo].[FNC_AHORA](), 1)
    SET @ID = SCOPE_IDENTITY()
    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPS_PLAN_COMERCIAL_PRECIO @PLAN = ' + LTRIM(STR(@PLAN))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '6.- NO FUE POSIBLE FIJAR EL PRECIO.'
        RETURN -1
    END
COMMIT TRANSACTION
RETURN(0)
GO

/* ---- Historial de precios: ahora con la moneda de cada fila ---- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_COMERCIAL_PRECIO]
@ID            INT = NULL,
@PLAN          INT = NULL,
@PERIODICIDAD  INT = NULL,
@SOLO_VIGENTES BIT = NULL,
@MONEDA        VARCHAR(3) = NULL
AS
SET NOCOUNT ON
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
    SELECT  pr.pcp_id                     AS PCP_ID,
            pr.pcp_plan_comercial         AS PCP_PLAN_COMERCIAL,
            p.plc_codigo                  AS PLC_CODIGO,
            p.plc_nombre                  AS PLC_NOMBRE,
            pr.pcp_periodicidad_cobro     AS PCP_PERIODICIDAD_COBRO,
            pc.pcb_codigo                 AS PCB_CODIGO,
            pc.pcb_nombre                 AS PCB_NOMBRE,
            pr.pcp_moneda                 AS PCP_MONEDA,
            pr.pcp_valor_uf               AS PCP_VALOR_UF,
            pr.pcp_descuento_porcentaje   AS PCP_DESCUENTO_PORCENTAJE,
            pr.pcp_vigencia_desde         AS PCP_VIGENCIA_DESDE,
            pr.pcp_vigencia_hasta         AS PCP_VIGENCIA_HASTA,
            pr.pcp_habilitado             AS PCP_HABILITADO,
            -- Solo tiene equivalente en pesos el precio en UF.
            CASE WHEN pr.pcp_moneda = 'UF'
                 THEN CAST(ROUND(pr.pcp_valor_uf * ISNULL([dbo].[FNC_VALOR_UF](@HOY), 0), 0) AS DECIMAL(18,0)) END
                                          AS MONTO_CLP_REFERENCIAL,
            CASE WHEN pr.pcp_habilitado = 0 THEN N'RETIRADO'
                 WHEN pr.pcp_vigencia_desde > @HOY THEN N'PROGRAMADO'
                 WHEN pr.pcp_vigencia_hasta IS NULL OR pr.pcp_vigencia_hasta >= @HOY THEN N'VIGENTE'
                 ELSE N'HISTÓRICO' END    AS ESTADO
    FROM    [dbo].[Plan_Comercial_Precio] pr
    INNER JOIN [dbo].[Plan_Comercial] p       ON p.plc_id  = pr.pcp_plan_comercial
    INNER JOIN [dbo].[Periodicidad_Cobro] pc  ON pc.pcb_id = pr.pcp_periodicidad_cobro
    WHERE   (@ID IS NULL OR pr.pcp_id = @ID)
      AND   (@PLAN IS NULL OR pr.pcp_plan_comercial = @PLAN)
      AND   (@PERIODICIDAD IS NULL OR pr.pcp_periodicidad_cobro = @PERIODICIDAD)
      AND   (@MONEDA IS NULL OR pr.pcp_moneda = @MONEDA)
      AND   (@SOLO_VIGENTES IS NULL OR @SOLO_VIGENTES = 0
             OR (pr.pcp_habilitado = 1
                 AND pr.pcp_vigencia_desde <= @HOY
                 AND (pr.pcp_vigencia_hasta IS NULL OR pr.pcp_vigencia_hasta >= @HOY)))
    ORDER BY pr.pcp_moneda DESC, pc.pcb_orden, pr.pcp_vigencia_desde DESC
RETURN(0)
GO

/* ---- Precio vigente por plan: UF por defecto, así no cambia a los llamadores actuales ---- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_COMERCIAL]
@ID             INT = NULL,
@PERIODICIDAD   INT = NULL,
@FECHA          DATE = NULL,
@SOLO_PUBLICOS  BIT = NULL,
@HABILITADO     BIT = NULL,
@MONEDA         VARCHAR(3) = 'UF'
AS
SET NOCOUNT ON
SET @FECHA = ISNULL(@FECHA, CAST([dbo].[FNC_AHORA]() AS DATE))
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
            pr.pcp_moneda                 AS PCP_MONEDA,
            pr.pcp_valor_uf               AS PCP_VALOR_UF,
            pr.pcp_descuento_porcentaje   AS PCP_DESCUENTO_PORCENTAJE,
            CASE WHEN pr.pcp_moneda = 'UF'
                 THEN CAST(ROUND(pr.pcp_valor_uf * ISNULL([dbo].[FNC_VALOR_UF](@FECHA), 0), 0) AS DECIMAL(18,0)) END
                                          AS MONTO_CLP_REFERENCIAL,
            [dbo].[FNC_VALOR_UF](@FECHA)  AS VALOR_UF_DIA
    FROM    [dbo].[Plan_Comercial] p
    INNER JOIN [dbo].[Plan_Comercial_Precio] pr ON pr.pcp_plan_comercial = p.plc_id
    INNER JOIN [dbo].[Periodicidad_Cobro] pc    ON pc.pcb_id = pr.pcp_periodicidad_cobro
    WHERE   (@ID IS NULL OR p.plc_id = @ID)
      AND   (@PERIODICIDAD IS NULL OR pr.pcp_periodicidad_cobro = @PERIODICIDAD)
      AND   (@SOLO_PUBLICOS IS NULL OR @SOLO_PUBLICOS = 0 OR p.plc_publico = 1)
      AND   (@HABILITADO IS NULL OR p.plc_habilitado = @HABILITADO)
      AND   (@MONEDA IS NULL OR pr.pcp_moneda = @MONEDA)
      AND   pr.pcp_habilitado = 1
      AND   pr.pcp_vigencia_desde <= @FECHA
      AND   (pr.pcp_vigencia_hasta IS NULL OR pr.pcp_vigencia_hasta >= @FECHA)
    ORDER BY p.plc_orden, pc.pcb_orden
RETURN(0)
GO

/* ---- Emitir un período: en UF congela la UF del día; en USD, no hay conversión ---- */
CREATE OR ALTER PROCEDURE [dbo].[INS_SUSCRIPCION_PERIODO]
@ID                INT = NULL OUTPUT,
@SUSCRIPCION       INT,
@PERIODICIDAD      INT,
@PLAN_COMERCIAL    INT = NULL,
@FECHA_INICIO      DATE = NULL,
@ES_IMPLANTACION   BIT = 0,
@VALOR_UF_MANUAL   DECIMAL(18,4) = NULL,   -- valor manual en la moneda del cliente (UF o USD)
@OBSERVACION       NVARCHAR(1000) = NULL,
@USUARIO           INT,
@MONEDA            VARCHAR(3) = NULL       -- por defecto, la moneda de cobro del cliente
AS
SET NOCOUNT ON
DECLARE @CLIENTE      INT,
        @FIN_ANTERIOR DATE,
        @VALOR_PLAN   DECIMAL(18,4),
        @UF_DIA       DECIMAL(18,4),
        @FECHA_UF     DATE = CAST([dbo].[FNC_AHORA]() AS DATE),
        @FECHA_FIN    DATE,
        @MESES        INT,
        @MONTO        DECIMAL(18,2)
BEGIN
    SELECT @CLIENTE = s.sus_cliente,
           @PLAN_COMERCIAL = ISNULL(@PLAN_COMERCIAL, s.sus_plan_comercial),
           @FIN_ANTERIOR = s.sus_fecha_fin,
           @MONEDA = UPPER(ISNULL(@MONEDA, c.cli_moneda_cobro))
      FROM [dbo].[Suscripcion] s
      JOIN [dbo].[Cliente] c ON c.cli_id = s.sus_cliente
     WHERE s.sus_id = @SUSCRIPCION
    IF @CLIENTE IS NULL
    BEGIN
        RAISERROR('1.- LA SUSCRIPCIÓN NO EXISTE.', 16, 1)
        RETURN -1
    END
    IF @MONEDA NOT IN ('UF', 'USD')
    BEGIN
        RAISERROR('6.- LA MONEDA DE COBRO DEBE SER UF O USD.', 16, 1)
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
    SET @FECHA_INICIO = ISNULL(@FECHA_INICIO,
                               CASE WHEN @FIN_ANTERIOR IS NULL OR @FIN_ANTERIOR < CAST([dbo].[FNC_AHORA]() AS DATE)
                                    THEN CAST([dbo].[FNC_AHORA]() AS DATE)
                                    ELSE DATEADD(DAY, 1, @FIN_ANTERIOR) END)
    SET @FECHA_FIN = DATEADD(DAY, -1, DATEADD(MONTH, @MESES, @FECHA_INICIO))
    -- El precio VIGENTE del plan para esa periodicidad y esa moneda.
    IF @VALOR_UF_MANUAL IS NOT NULL
        SET @VALOR_PLAN = @VALOR_UF_MANUAL
    ELSE
        SELECT TOP 1 @VALOR_PLAN = pcp_valor_uf
          FROM [dbo].[Plan_Comercial_Precio]
         WHERE pcp_plan_comercial = @PLAN_COMERCIAL
           AND pcp_periodicidad_cobro = @PERIODICIDAD
           AND pcp_moneda = @MONEDA
           AND pcp_habilitado = 1
           AND pcp_vigencia_desde <= @FECHA_UF
           AND (pcp_vigencia_hasta IS NULL OR pcp_vigencia_hasta >= @FECHA_UF)
         ORDER BY pcp_vigencia_desde DESC
    IF @ES_IMPLANTACION = 1 AND @VALOR_UF_MANUAL IS NULL
        SET @VALOR_PLAN = 0
    IF @VALOR_PLAN IS NULL
    BEGIN
        IF @MONEDA = 'USD'
            RAISERROR('3.- EL PLAN NO TIENE PRECIO VIGENTE EN USD PARA ESA PERIODICIDAD.', 16, 1)
        ELSE
            RAISERROR('3.- EL PLAN NO TIENE PRECIO VIGENTE PARA ESA PERIODICIDAD.', 16, 1)
        RETURN -1
    END
    IF @MONEDA = 'UF'
    BEGIN
        SET @UF_DIA = [dbo].[FNC_VALOR_UF](@FECHA_UF)
        IF @UF_DIA IS NULL OR @UF_DIA <= 0
        BEGIN
            RAISERROR('4.- NO HAY VALOR DE UF CARGADO. NO SE PUEDE EMITIR UN PERÍODO SIN ÉL.', 16, 1)
            RETURN -1
        END
        SET @MONTO = ROUND(@VALOR_PLAN * @UF_DIA, 0)      -- CLP, sin decimales
    END
    ELSE
    BEGIN
        SET @UF_DIA = NULL
        SET @FECHA_UF = NULL
        SET @MONTO = ROUND(@VALOR_PLAN, 2)                 -- USD, sin conversión
    END
END
BEGIN TRANSACTION
    INSERT [dbo].[Suscripcion_Periodo]
        (spe_suscripcion, spe_plan_comercial, spe_periodicidad_cobro, spe_moneda,
         spe_fecha_inicio, spe_fecha_fin,
         spe_valor_uf_plan, spe_valor_uf_dia, spe_fecha_valor_uf,
         spe_monto_clp, spe_monto_pagado_clp, spe_suscripcion_periodo_estado,
         spe_es_implantacion, spe_observacion,
         spe_usuario_creacion, spe_fecha_creacion,
         spe_usuario_actualizacion, spe_fecha_actualizacion, spe_habilitado)
    VALUES
        (@SUSCRIPCION, @PLAN_COMERCIAL, @PERIODICIDAD, @MONEDA,
         @FECHA_INICIO, @FECHA_FIN,
         @VALOR_PLAN, @UF_DIA, @FECHA_UF,
         @MONTO, 0, 1,                       -- 1 = PENDIENTE PAGO
         @ES_IMPLANTACION, @OBSERVACION,
         @USUARIO, [dbo].[FNC_AHORA](), @USUARIO, [dbo].[FNC_AHORA](), 1)
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

/* ---- Informar un pago: la moneda sale del período; el medio por defecto, de la moneda ---- */
CREATE OR ALTER PROCEDURE [dbo].[INS_SUSCRIPCION_PAGO]
@ID                  INT = NULL OUTPUT,
@PERIODO             INT,
@MONTO_DECLARADO     DECIMAL(18,2),
@FECHA_TRANSFERENCIA DATE,
@BANCO               NVARCHAR(100) = NULL,
@NUMERO_OPERACION    NVARCHAR(100) = NULL,
@ARCHIVO             INT,
@USUARIO             INT,
@MEDIO               VARCHAR(30) = NULL
AS
SET NOCOUNT ON
DECLARE @MONEDA_PERIODO VARCHAR(3), @MONEDA VARCHAR(3)
BEGIN
    SELECT @MONEDA_PERIODO = spe_moneda FROM [dbo].[Suscripcion_Periodo]
     WHERE spe_id = @PERIODO AND spe_habilitado = 1
    IF @MONEDA_PERIODO IS NULL
    BEGIN
        RAISERROR('1.- EL PERÍODO NO EXISTE O ESTÁ ANULADO.', 16, 1)
        RETURN -1
    END
    SET @MONEDA = CASE WHEN @MONEDA_PERIODO = 'USD' THEN 'USD' ELSE 'CLP' END
    SET @MEDIO = UPPER(ISNULL(@MEDIO, CASE WHEN @MONEDA = 'USD' THEN 'TRANSFERENCIA_INTERNACIONAL' ELSE 'TRANSFERENCIA_NACIONAL' END))
    IF @MEDIO NOT IN ('WEBPAY', 'TRANSFERENCIA_NACIONAL', 'TRANSFERENCIA_INTERNACIONAL')
    BEGIN
        RAISERROR('6.- EL MEDIO DE PAGO NO ES VÁLIDO.', 16, 1)
        RETURN -1
    END
    IF @MONEDA = 'USD' AND @MEDIO <> 'TRANSFERENCIA_INTERNACIONAL'
    BEGIN
        RAISERROR('7.- UN COBRO EN USD SOLO SE PAGA POR TRANSFERENCIA INTERNACIONAL.', 16, 1)
        RETURN -1
    END
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
         spa_moneda, spa_medio,
         spa_fecha_transferencia, spa_banco, spa_numero_operacion, spa_archivo,
         spa_suscripcion_pago_estado, spa_usuario_creacion, spa_fecha_creacion,
         spa_usuario_actualizacion, spa_fecha_actualizacion, spa_habilitado)
    VALUES
        (@PERIODO, @MONTO_DECLARADO, NULL,
         @MONEDA, @MEDIO,
         @FECHA_TRANSFERENCIA, @BANCO, @NUMERO_OPERACION, @ARCHIVO,
         1, @USUARIO, [dbo].[FNC_AHORA](),          -- 1 = DECLARADO
         @USUARIO, [dbo].[FNC_AHORA](), 1)
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

/* ---- Verificar: en USD no rige la tolerancia en pesos, solo el porcentaje ---- */
DECLARE @DEF NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.UPD_SUSCRIPCION_PAGO_VERIFICAR'))
IF @DEF IS NOT NULL AND CHARINDEX('spe_moneda', @DEF) = 0 AND CHARINDEX('SET @TOLERANCIA = CASE', @DEF) > 0
BEGIN
    SET @DEF = REPLACE(@DEF, 'SET @TOLERANCIA = CASE',
        'IF EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Periodo] WHERE spe_id = @PERIODO AND spe_moneda = ''USD'') SET @TOL_CLP = 0' + CHAR(13) + CHAR(10) + '    SET @TOLERANCIA = CASE')
    SET @DEF = REPLACE(@DEF, 'CREATE   PROCEDURE', 'CREATE OR ALTER PROCEDURE')
    SET @DEF = REPLACE(@DEF, 'CREATE PROCEDURE', 'CREATE OR ALTER PROCEDURE')
    EXEC sp_executesql @DEF
    PRINT 'UPD_SUSCRIPCION_PAGO_VERIFICAR: sin tolerancia en pesos para cobros en USD.'
END
GO

/* ---- Listas: agregan la moneda (y el medio) como columnas nuevas al final ---- */
DECLARE @DEF NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.SEL_SUSCRIPCION_PERIODO'))
IF @DEF IS NOT NULL AND CHARINDEX('SPE_MONEDA', @DEF) = 0 AND CHARINDEX('AS SPE_HABILITADO', @DEF) > 0
BEGIN
    SET @DEF = REPLACE(@DEF, 'AS SPE_HABILITADO', 'AS SPE_HABILITADO, sp.spe_moneda AS SPE_MONEDA')
    SET @DEF = REPLACE(@DEF, 'CREATE   PROCEDURE', 'CREATE OR ALTER PROCEDURE')
    SET @DEF = REPLACE(@DEF, 'CREATE PROCEDURE', 'CREATE OR ALTER PROCEDURE')
    EXEC sp_executesql @DEF
    PRINT 'SEL_SUSCRIPCION_PERIODO: con SPE_MONEDA.'
END
GO
DECLARE @DEF NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.SEL_SUSCRIPCION_PAGO'))
IF @DEF IS NOT NULL AND CHARINDEX('SPA_MEDIO', @DEF) = 0 AND CHARINDEX('AS SPE_FECHA_FIN', @DEF) > 0
BEGIN
    SET @DEF = REPLACE(@DEF, 'AS SPE_FECHA_FIN', 'AS SPE_FECHA_FIN, pg.spa_moneda AS SPA_MONEDA, pg.spa_medio AS SPA_MEDIO, sp.spe_moneda AS SPE_MONEDA')
    SET @DEF = REPLACE(@DEF, 'CREATE   PROCEDURE', 'CREATE OR ALTER PROCEDURE')
    SET @DEF = REPLACE(@DEF, 'CREATE PROCEDURE', 'CREATE OR ALTER PROCEDURE')
    EXEC sp_executesql @DEF
    PRINT 'SEL_SUSCRIPCION_PAGO: con SPA_MONEDA, SPA_MEDIO y SPE_MONEDA.'
END
GO

/* ---- Catálogo del Centro Comercial: mensualidad en UF y en USD ---- */
DECLARE @DEF NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.SEL_COMERCIAL_CATALOGO'))
IF @DEF IS NOT NULL AND CHARINDEX('MENSUAL_USD', @DEF) = 0 AND CHARINDEX('AS MENSUAL_UF,', @DEF) > 0
BEGIN
    SET @DEF = REPLACE(@DEF, 'AS MENSUAL_UF,',
        'AS MENSUAL_UF,' + CHAR(13) + CHAR(10) +
        '        (SELECT TOP 1 pcp_valor_uf FROM [dbo].[Plan_Comercial_Precio] Z' + CHAR(13) + CHAR(10) +
        '          WHERE Z.pcp_plan_comercial = P.plc_id AND Z.pcp_periodicidad_cobro = 1 AND Z.pcp_habilitado = 1 AND Z.pcp_moneda = ''USD''' + CHAR(13) + CHAR(10) +
        '            AND Z.pcp_vigencia_desde <= @HOY AND (Z.pcp_vigencia_hasta IS NULL OR Z.pcp_vigencia_hasta >= @HOY)' + CHAR(13) + CHAR(10) +
        '          ORDER BY Z.pcp_vigencia_desde DESC) AS MENSUAL_USD,')
    -- el precio en UF no debe confundirse con el de USD
    SET @DEF = REPLACE(@DEF, 'X.pcp_periodicidad_cobro = 1 AND X.pcp_habilitado = 1', 'X.pcp_periodicidad_cobro = 1 AND X.pcp_habilitado = 1 AND X.pcp_moneda = ''UF''')
    SET @DEF = REPLACE(@DEF, 'CREATE   PROCEDURE', 'CREATE OR ALTER PROCEDURE')
    SET @DEF = REPLACE(@DEF, 'CREATE PROCEDURE', 'CREATE OR ALTER PROCEDURE')
    EXEC sp_executesql @DEF
    PRINT 'SEL_COMERCIAL_CATALOGO: con MENSUAL_USD.'
END
GO

/* ---- Vista y cobro: la moneda viaja con la suscripción ---- */
CREATE OR ALTER VIEW [dbo].[VW_SUSCRIPCION_COMERCIAL]
AS
SELECT  S.sus_id, S.sus_cliente, C.cli_nombre, S.sus_plan_comercial, PC.plc_nombre, S.sus_fecha_inicio, S.sus_fecha_fin,
        S.sus_suscripcion_estado, S.sus_habilitado,
        ISNULL(S.sus_contacto_email, L.lea_correo) AS contacto_correo, ISNULL(S.sus_contacto_nombre, L.lea_contacto_nombre) AS contacto_nombre,
        L.lea_id, L.lea_codigo,
        LTRIM(RTRIM(ISNULL(U.usu_nombre, '') + ' ' + ISNULL(U.usu_apellido_paterno, ''))) AS ejecutivo_nombre, U.usu_correo AS ejecutivo_correo,
        P.ppt_id, ROUND(P.ppt_mensual_uf * (100 - P.ppt_descuento_pct) / 100, 2) AS mensual_uf, P.ppt_implementacion_uf AS implementacion_uf,
        P.ppt_vigencia_meses, CAST(K.ctt_firmado_fecha AS DATE) AS firmado,
        DATEADD(DAY, -1, DATEADD(MONTH, P.ppt_vigencia_meses, CAST(K.ctt_firmado_fecha AS DATE))) AS fin_contrato,
        C.cli_moneda_cobro AS moneda
FROM    [dbo].[Suscripcion] S
JOIN    [dbo].[Cliente] C ON C.cli_id = S.sus_cliente
LEFT JOIN [dbo].[Plan_Comercial] PC ON PC.plc_id = S.sus_plan_comercial
JOIN    [dbo].[Lead] L ON L.lea_cliente = S.sus_cliente AND L.lea_estado = 'CONCRETADO'
OUTER APPLY (SELECT TOP 1 * FROM [dbo].[Contrato] X WHERE X.ctt_lead = L.lea_id AND X.ctt_estado = 'FIRMADO' ORDER BY X.ctt_version DESC) K
LEFT JOIN [dbo].[Propuesta] P ON P.ppt_id = K.ctt_propuesta
LEFT JOIN [dbo].[Usuario] U ON U.usu_id = L.lea_ejecutivo
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_COBRO_SUSCRIPCION]
@SUSCRIPCION INT
AS
SET NOCOUNT ON
-- 0 · la suscripción y a quién se le escribe
SELECT sus_id AS SUSCRIPCION, sus_cliente AS CLIENTE, cli_nombre AS EMPRESA, plc_nombre AS PLAN_NOMBRE, contacto_correo AS CORREO,
       contacto_nombre AS CONTACTO, ejecutivo_nombre AS EJECUTIVO, ejecutivo_correo AS EJECUTIVO_CORREO, lea_id AS LEAD,
       mensual_uf AS MENSUAL_UF, CONVERT(VARCHAR(10), fin_contrato, 120) AS FIN_CONTRATO, moneda AS MONEDA
  FROM [dbo].[VW_SUSCRIPCION_COMERCIAL] WHERE sus_id = @SUSCRIPCION
-- 1 · lo pendiente de pago
SELECT spe_id AS ID, CONVERT(VARCHAR(10), spe_fecha_inicio, 120) AS DESDE, CONVERT(VARCHAR(10), spe_fecha_fin, 120) AS HASTA,
       spe_valor_uf_plan AS UF, spe_monto_clp AS MONTO, spe_monto_pagado_clp AS PAGADO, spe_monto_clp - spe_monto_pagado_clp AS SALDO,
       spe_es_implantacion AS IMPLANTACION, spe_observacion AS OBSERVACION, spe_moneda AS MONEDA
  FROM [dbo].[Suscripcion_Periodo]
 WHERE spe_suscripcion = @SUSCRIPCION AND spe_habilitado = 1 AND spe_suscripcion_periodo_estado IN (1, 2)
   AND spe_monto_clp - spe_monto_pagado_clp > 0
 ORDER BY spe_es_implantacion DESC, spe_fecha_inicio
GO

/* ---- Datos bancarios (Configuración): lectura y edición ---- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CONFIG_COMERCIAL]
@GRUPO VARCHAR(30) = NULL
AS
SET NOCOUNT ON
SELECT ccm_clave AS CLAVE, ccm_grupo AS GRUPO, ccm_etiqueta AS ETIQUETA, ccm_valor AS VALOR
  FROM [dbo].[Config_Comercial]
 WHERE @GRUPO IS NULL OR ccm_grupo = @GRUPO
 ORDER BY ccm_grupo, ccm_orden
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_CONFIG_COMERCIAL]
@CLAVE VARCHAR(60), @VALOR NVARCHAR(300) = NULL, @USUARIO INT
AS
SET NOCOUNT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Config_Comercial] WHERE ccm_clave = @CLAVE)
BEGIN RAISERROR('1.- EL DATO NO EXISTE.', 16, 1) RETURN -1 END
UPDATE [dbo].[Config_Comercial]
   SET ccm_valor = NULLIF(LTRIM(RTRIM(@VALOR)), N''), ccm_usuario_actualizacion = @USUARIO, ccm_fecha_actualizacion = [dbo].[FNC_AHORA]()
 WHERE ccm_clave = @CLAVE
RETURN 0
GO

PRINT '464_COBRO_INTERNACIONAL_SP aplicado.'
GO
