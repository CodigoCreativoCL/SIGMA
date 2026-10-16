/* ============================================================================
   SIGMA — Bloque 462
   COBROS AUTOMÁTICOS Y PAGO EN LÍNEA (WEBPAY PLUS, MODO DE PRUEBA)
   ----------------------------------------------------------------------------
   EL FLUJO
     1. Al firmar el contrato se emiten los primeros cobros (implementación y
        primera mensualidad) y la página de firma ofrece «Pagar ahora».
     2. Cada día, el job COBROS_EMITIR emite el período siguiente de cada
        suscripción unos días antes de que empiece, hasta el fin del contrato,
        y envía el correo de cobro con el enlace de pago.
     3. COBROS_RECORDATORIOS avisa 3 días antes, el día del vencimiento y al
        entrar en mora; una sola vez cada aviso.
     4. Pagar con Webpay registra el pago y lo verifica solo, por el mismo
        camino que un pago informado (INS_SUSCRIPCION_PAGO +
        UPD_SUSCRIPCION_PAGO_VERIFICAR), y eso extiende sus_fecha_fin.

   EL ACCESO SE MANTIENE MIENTRAS HAYA PERÍODOS PAGADOS
     Verificar un pago lleva sus_fecha_fin al fin de ese período. Por eso la
     firma ya no deja la suscripción con 12 meses de vigencia de una vez: la
     deja «al día» (vence ayer + días de gracia del plan), y cada mes pagado la
     extiende. La vigencia del contrato solo dice hasta cuándo se emiten cobros.

   EL ENLACE DE PAGO
     Uno por suscripción, de 32 bytes al azar; en la base solo su SHA-256, como
     el de firma. Sirve para pagar TODO lo pendiente de esa suscripción.

   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Pago_Enlace]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Pago_Enlace]
    (
        [pen_id]             INT            NOT NULL IDENTITY(1,1),
        [pen_suscripcion]    INT            NOT NULL,
        [pen_token_hash]     VARBINARY(32)  NOT NULL,
        [pen_expira]         DATETIME       NOT NULL,
        [pen_fecha_creacion] DATETIME       NOT NULL CONSTRAINT DF_PEN_FECHA_CREACION DEFAULT GETDATE(),
        CONSTRAINT PK_PAGO_ENLACE PRIMARY KEY CLUSTERED ([pen_id] ASC),
        CONSTRAINT FK_PEN_SUSCRIPCION FOREIGN KEY ([pen_suscripcion]) REFERENCES [dbo].[Suscripcion] ([sus_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_PEN_TOKEN ON [dbo].[Pago_Enlace] ([pen_token_hash])
    PRINT 'Tabla Pago_Enlace creada.'
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Pago_Webpay]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Pago_Webpay]
    (
        [pwb_id]                  INT            NOT NULL IDENTITY(1,1),
        [pwb_suscripcion]         INT            NOT NULL,
        [pwb_buy_order]           VARCHAR(26)    NOT NULL,
        [pwb_session_id]          VARCHAR(61)    NOT NULL,
        [pwb_token_tbk]           VARCHAR(64)    NULL,
        [pwb_monto_clp]           DECIMAL(18,0)  NOT NULL,
        [pwb_periodos]            VARCHAR(400)   NOT NULL,        -- spe_id separados por coma
        [pwb_ambiente]            VARCHAR(15)    NOT NULL,        -- INTEGRACION | PRODUCCION
        [pwb_estado]              VARCHAR(15)    NOT NULL CONSTRAINT DF_PWB_ESTADO DEFAULT 'CREADA',
        [pwb_codigo_autorizacion] VARCHAR(20)    NULL,
        [pwb_tarjeta]             VARCHAR(8)     NULL,            -- últimos 4 dígitos
        [pwb_tipo_pago]           VARCHAR(4)     NULL,            -- VD, VN, VC…
        [pwb_cuotas]              INT            NULL,
        [pwb_respuesta]           NVARCHAR(MAX)  NULL,            -- JSON de Transbank, para auditoría
        [pwb_fecha_creacion]      DATETIME       NOT NULL CONSTRAINT DF_PWB_FECHA_CREACION DEFAULT GETDATE(),
        [pwb_fecha_confirmacion]  DATETIME       NULL,
        CONSTRAINT PK_PAGO_WEBPAY PRIMARY KEY CLUSTERED ([pwb_id] ASC),
        CONSTRAINT FK_PWB_SUSCRIPCION FOREIGN KEY ([pwb_suscripcion]) REFERENCES [dbo].[Suscripcion] ([sus_id]),
        CONSTRAINT CK_PWB_ESTADO CHECK ([pwb_estado] IN ('CREADA', 'AUTORIZADA', 'RECHAZADA', 'ANULADA', 'ERROR'))
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_PWB_BUY_ORDER ON [dbo].[Pago_Webpay] ([pwb_buy_order])
    CREATE UNIQUE NONCLUSTERED INDEX UX_PWB_TOKEN ON [dbo].[Pago_Webpay] ([pwb_token_tbk]) WHERE [pwb_token_tbk] IS NOT NULL
    PRINT 'Tabla Pago_Webpay creada.'
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Cobro_Recordatorio]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Cobro_Recordatorio]
    (
        [cre_id]      INT          NOT NULL IDENTITY(1,1),
        [cre_periodo] INT          NOT NULL,
        [cre_tipo]    VARCHAR(10)  NOT NULL,     -- COBRO | PREVIO | VENCE | MORA
        [cre_enviado] BIT          NOT NULL,
        [cre_fecha]   DATETIME     NOT NULL CONSTRAINT DF_CRE_FECHA DEFAULT GETDATE(),
        CONSTRAINT PK_COBRO_RECORDATORIO PRIMARY KEY CLUSTERED ([cre_id] ASC),
        CONSTRAINT FK_CRE_PERIODO FOREIGN KEY ([cre_periodo]) REFERENCES [dbo].[Suscripcion_Periodo] ([spe_id]),
        CONSTRAINT CK_CRE_TIPO CHECK ([cre_tipo] IN ('COBRO', 'PREVIO', 'VENCE', 'MORA'))
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_CRE_PERIODO_TIPO ON [dbo].[Cobro_Recordatorio] ([cre_periodo], [cre_tipo])
    PRINT 'Tabla Cobro_Recordatorio creada.'
END
GO

MERGE [dbo].[Sys_Parametros] AS D
USING (VALUES
  ('COBROS_DIAS_ANTICIPACION', 'Días de anticipación del cobro', 'Con cuántos días de anticipación se emite y se envía el cobro del período siguiente.', '5'),
  ('COBROS_ENLACE_DIAS',       'Vigencia del enlace de pago (días)', 'Días que sirve el enlace de pago de un correo de cobro.', '30'),
  ('COBROS_DATOS_TRANSFERENCIA','Datos para transferir', 'Datos bancarios de Código Creativo que se muestran en el cobro para quien prefiera transferir. Vacío = no se muestran.', '')
) AS O (codigo, nombre, descripcion, valor)
   ON D.par_codigo = O.codigo
WHEN NOT MATCHED THEN INSERT (par_codigo, par_nombre, par_descripcion, par_valor) VALUES (O.codigo, O.nombre, O.descripcion, O.valor);
GO

/* ---------------------------------------------------------------- datos del cobro */

/* Contacto del cliente y ejecutivo a cargo (el del lead que se convirtió en
   este cliente), y lo que se le cobra: la propuesta aceptada del contrato
   firmado. Lo usan el cobro inicial, el job y los correos. */
CREATE OR ALTER VIEW [dbo].[VW_SUSCRIPCION_COMERCIAL]
AS
SELECT  S.sus_id, S.sus_cliente, C.cli_nombre, S.sus_plan_comercial, PC.plc_nombre, S.sus_fecha_inicio, S.sus_fecha_fin,
        S.sus_suscripcion_estado, S.sus_habilitado,
        ISNULL(S.sus_contacto_email, L.lea_correo) AS contacto_correo, ISNULL(S.sus_contacto_nombre, L.lea_contacto_nombre) AS contacto_nombre,
        L.lea_id, L.lea_codigo,
        LTRIM(RTRIM(ISNULL(U.usu_nombre, '') + ' ' + ISNULL(U.usu_apellido_paterno, ''))) AS ejecutivo_nombre, U.usu_correo AS ejecutivo_correo,
        P.ppt_id, ROUND(P.ppt_mensual_uf * (100 - P.ppt_descuento_pct) / 100, 2) AS mensual_uf, P.ppt_implementacion_uf AS implementacion_uf,
        P.ppt_vigencia_meses, CAST(K.ctt_firmado_fecha AS DATE) AS firmado,
        DATEADD(DAY, -1, DATEADD(MONTH, P.ppt_vigencia_meses, CAST(K.ctt_firmado_fecha AS DATE))) AS fin_contrato
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
       mensual_uf AS MENSUAL_UF, CONVERT(VARCHAR(10), fin_contrato, 120) AS FIN_CONTRATO
  FROM [dbo].[VW_SUSCRIPCION_COMERCIAL] WHERE sus_id = @SUSCRIPCION
-- 1 · lo pendiente de pago
SELECT spe_id AS ID, CONVERT(VARCHAR(10), spe_fecha_inicio, 120) AS DESDE, CONVERT(VARCHAR(10), spe_fecha_fin, 120) AS HASTA,
       spe_valor_uf_plan AS UF, spe_monto_clp AS MONTO, spe_monto_pagado_clp AS PAGADO, spe_monto_clp - spe_monto_pagado_clp AS SALDO,
       spe_es_implantacion AS IMPLANTACION, spe_observacion AS OBSERVACION
  FROM [dbo].[Suscripcion_Periodo]
 WHERE spe_suscripcion = @SUSCRIPCION AND spe_habilitado = 1 AND spe_suscripcion_periodo_estado IN (1, 2)
   AND spe_monto_clp - spe_monto_pagado_clp > 0
 ORDER BY spe_es_implantacion DESC, spe_fecha_inicio
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_PAGO_ENLACE]
@SUSCRIPCION INT, @TOKEN_HASH VARBINARY(32), @EXPIRA DATETIME
AS
SET NOCOUNT ON
INSERT [dbo].[Pago_Enlace] (pen_suscripcion, pen_token_hash, pen_expira) VALUES (@SUSCRIPCION, @TOKEN_HASH, @EXPIRA)
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PAGO_ENLACE]
@TOKEN_HASH VARBINARY(32)
AS
SET NOCOUNT ON
SELECT pen_suscripcion AS SUSCRIPCION, CASE WHEN pen_expira < [dbo].[FNC_AHORA]() THEN 1 ELSE 0 END AS VENCIDO,
       CONVERT(VARCHAR(16), pen_expira, 120) AS EXPIRA
  FROM [dbo].[Pago_Enlace] WHERE pen_token_hash = @TOKEN_HASH
GO

/* ---------------------------------------------------------------- emisión */

/* Emite el cobro siguiente de una suscripción: la mensualidad con descuento de
   la propuesta aceptada (o la implementación si @IMPLANTACION = 1). Usa
   INS_SUSCRIPCION_PERIODO, el mismo de la pantalla de períodos. */
CREATE OR ALTER PROCEDURE [dbo].[INS_COBRO_SUSCRIPCION]
@ID INT = NULL OUTPUT, @SUSCRIPCION INT, @IMPLANTACION BIT = 0, @FECHA_INICIO DATE = NULL, @USUARIO INT = 1
AS
SET NOCOUNT ON
DECLARE @MENSUAL DECIMAL(18,4), @IMPL DECIMAL(18,4), @PLAN INT
SELECT @MENSUAL = mensual_uf, @IMPL = implementacion_uf, @PLAN = sus_plan_comercial FROM [dbo].[VW_SUSCRIPCION_COMERCIAL] WHERE sus_id = @SUSCRIPCION
IF @PLAN IS NULL BEGIN RAISERROR('1.- LA SUSCRIPCIÓN NO TIENE UN CONTRATO FIRMADO DEL CENTRO COMERCIAL.', 16, 1) RETURN -1 END
IF @IMPLANTACION = 1 AND ISNULL(@IMPL, 0) <= 0 RETURN 0
DECLARE @OBS NVARCHAR(200) = CASE WHEN @IMPLANTACION = 1 THEN N'Implementación (cobro automático)' ELSE N'Mensualidad (cobro automático)' END
DECLARE @VAL DECIMAL(18,4) = CASE WHEN @IMPLANTACION = 1 THEN @IMPL ELSE @MENSUAL END
EXEC [dbo].[INS_SUSCRIPCION_PERIODO] @ID = @ID OUTPUT, @SUSCRIPCION = @SUSCRIPCION, @PERIODICIDAD = 1, @PLAN_COMERCIAL = @PLAN,
     @FECHA_INICIO = @FECHA_INICIO, @ES_IMPLANTACION = @IMPLANTACION, @VALOR_UF_MANUAL = @VAL, @OBSERVACION = @OBS, @USUARIO = @USUARIO
RETURN 0
GO

/* Las suscripciones a las que les toca emitir el período siguiente: el
   próximo empieza dentro de COBROS_DIAS_ANTICIPACION días, no hay un período
   posterior ya emitido y sigue dentro del contrato. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_COBROS_POR_EMITIR]
AS
SET NOCOUNT ON
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
DECLARE @ANT INT = ISNULL(TRY_CAST((SELECT par_valor FROM [dbo].[Sys_Parametros] WHERE par_codigo = 'COBROS_DIAS_ANTICIPACION') AS INT), 5)
SELECT V.sus_id AS SUSCRIPCION, CONVERT(VARCHAR(10), X.proximo, 120) AS DESDE
  FROM [dbo].[VW_SUSCRIPCION_COMERCIAL] V
 CROSS APPLY (SELECT DATEADD(DAY, 1, MAX(spe_fecha_fin)) AS proximo FROM [dbo].[Suscripcion_Periodo]
               WHERE spe_suscripcion = V.sus_id AND spe_habilitado = 1 AND spe_es_implantacion = 0 AND spe_suscripcion_periodo_estado <> 5) X
 WHERE V.sus_habilitado = 1 AND V.sus_suscripcion_estado = 1 AND V.mensual_uf > 0
   AND X.proximo IS NOT NULL AND X.proximo <= DATEADD(DAY, @ANT, @HOY) AND X.proximo <= V.fin_contrato
GO

/* Avisos que tocan hoy. El vencimiento de un período es su primer día (se paga
   por adelantado). Cada aviso sale una sola vez. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_COBROS_RECORDATORIO]
AS
SET NOCOUNT ON
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
SELECT P.spe_id AS PERIODO, P.spe_suscripcion AS SUSCRIPCION, T.tipo AS TIPO, CONVERT(VARCHAR(10), P.spe_fecha_inicio, 120) AS VENCE
  FROM [dbo].[Suscripcion_Periodo] P
  JOIN [dbo].[VW_SUSCRIPCION_COMERCIAL] V ON V.sus_id = P.spe_suscripcion
 CROSS APPLY (SELECT CASE WHEN DATEDIFF(DAY, @HOY, P.spe_fecha_inicio) = 3 THEN 'PREVIO'
                          WHEN P.spe_fecha_inicio = @HOY THEN 'VENCE'
                          WHEN DATEDIFF(DAY, P.spe_fecha_inicio, @HOY) >= 3 THEN 'MORA' END AS tipo) T
 WHERE P.spe_habilitado = 1 AND P.spe_suscripcion_periodo_estado IN (1, 2) AND P.spe_monto_clp - P.spe_monto_pagado_clp > 0
   AND T.tipo IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Cobro_Recordatorio] R WHERE R.cre_periodo = P.spe_id AND R.cre_tipo = T.tipo)
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_COBRO_RECORDATORIO]
@PERIODO INT, @TIPO VARCHAR(10), @ENVIADO BIT
AS
SET NOCOUNT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Cobro_Recordatorio] WHERE cre_periodo = @PERIODO AND cre_tipo = @TIPO)
    INSERT [dbo].[Cobro_Recordatorio] (cre_periodo, cre_tipo, cre_enviado) VALUES (@PERIODO, @TIPO, @ENVIADO)
RETURN 0
GO

/* ---------------------------------------------------------------- Webpay */

CREATE OR ALTER PROCEDURE [dbo].[INS_PAGO_WEBPAY]
@ID INT = NULL OUTPUT, @SUSCRIPCION INT, @BUY_ORDER VARCHAR(26), @SESSION_ID VARCHAR(61), @MONTO DECIMAL(18,0), @PERIODOS VARCHAR(400), @AMBIENTE VARCHAR(15)
AS
SET NOCOUNT ON
INSERT [dbo].[Pago_Webpay] (pwb_suscripcion, pwb_buy_order, pwb_session_id, pwb_monto_clp, pwb_periodos, pwb_ambiente)
VALUES (@SUSCRIPCION, @BUY_ORDER, @SESSION_ID, @MONTO, @PERIODOS, @AMBIENTE)
SET @ID = SCOPE_IDENTITY()
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_PAGO_WEBPAY_TOKEN]
@ID INT, @TOKEN VARCHAR(64)
AS
SET NOCOUNT ON
UPDATE [dbo].[Pago_Webpay] SET pwb_token_tbk = @TOKEN WHERE pwb_id = @ID
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PAGO_WEBPAY]
@TOKEN VARCHAR(64) = NULL, @BUY_ORDER VARCHAR(26) = NULL
AS
SET NOCOUNT ON
SELECT pwb_id AS ID, pwb_suscripcion AS SUSCRIPCION, pwb_buy_order AS BUY_ORDER, pwb_monto_clp AS MONTO, pwb_periodos AS PERIODOS,
       pwb_estado AS ESTADO, pwb_ambiente AS AMBIENTE, pwb_codigo_autorizacion AS AUTORIZACION, pwb_tarjeta AS TARJETA,
       pwb_tipo_pago AS TIPO_PAGO, pwb_cuotas AS CUOTAS, CONVERT(VARCHAR(16), pwb_fecha_confirmacion, 120) AS CONFIRMADO
  FROM [dbo].[Pago_Webpay]
 WHERE (@TOKEN IS NOT NULL AND pwb_token_tbk = @TOKEN) OR (@BUY_ORDER IS NOT NULL AND pwb_buy_order = @BUY_ORDER)
GO

/* Deja el resultado de Transbank. Solo cambia una transacción CREADA: volver
   a la página de retorno (recargar) no registra el pago dos veces. Devuelve
   CAMBIO = 1 cuando esta llamada fue la que lo cerró. */
CREATE OR ALTER PROCEDURE [dbo].[UPD_PAGO_WEBPAY_RESULTADO]
@ID INT, @ESTADO VARCHAR(15), @AUTORIZACION VARCHAR(20) = NULL, @TARJETA VARCHAR(8) = NULL, @TIPO_PAGO VARCHAR(4) = NULL,
@CUOTAS INT = NULL, @RESPUESTA NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON
UPDATE [dbo].[Pago_Webpay]
   SET pwb_estado = @ESTADO, pwb_codigo_autorizacion = @AUTORIZACION, pwb_tarjeta = @TARJETA, pwb_tipo_pago = @TIPO_PAGO,
       pwb_cuotas = @CUOTAS, pwb_respuesta = @RESPUESTA, pwb_fecha_confirmacion = [dbo].[FNC_AHORA]()
 WHERE pwb_id = @ID AND pwb_estado = 'CREADA'
SELECT @@ROWCOUNT AS CAMBIO
GO

/* ---------------------------------------------------------------- firma
   La firma deja la suscripción «al día» y no con 12 meses de golpe (ver
   encabezado). Se reemplaza solo esa línea del SP del bloque 456. */
DECLARE @DEF NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.UPD_CONTRATO_FIRMAR'))
IF @DEF IS NOT NULL AND CHARINDEX('sus_fecha_inicio = @HOY, sus_fecha_fin = @FIN,', @DEF) > 0
BEGIN
    SET @DEF = REPLACE(@DEF, 'sus_fecha_inicio = @HOY, sus_fecha_fin = @FIN,', 'sus_fecha_inicio = @HOY, sus_fecha_fin = DATEADD(DAY, -1, @HOY),')
    SET @DEF = REPLACE(@DEF, 'UPDATE [dbo].[Suscripcion] SET sus_fecha_fin = @FIN WHERE sus_id = @SUS', 'UPDATE [dbo].[Suscripcion] SET sus_fecha_fin = DATEADD(DAY, -1, @HOY) WHERE sus_id = @SUS')
    SET @DEF = REPLACE(@DEF, 'CREATE   PROCEDURE', 'CREATE OR ALTER PROCEDURE')
    SET @DEF = REPLACE(@DEF, 'CREATE PROCEDURE', 'CREATE OR ALTER PROCEDURE')
    EXEC sp_executesql @DEF
    PRINT 'UPD_CONTRATO_FIRMAR: la suscripción queda al día y la extienden los pagos.'
END
GO


/* Si Transbank autorizó pero el registro en SIGMA falló (correo, archivo,
   corte), el pago queda AUTORIZADA y sin registrar: se completa en la
   siguiente visita a la página de retorno o con el job de cobros. */
IF COL_LENGTH('dbo.Pago_Webpay', 'pwb_registrado') IS NULL
    ALTER TABLE [dbo].[Pago_Webpay] ADD [pwb_registrado] BIT NOT NULL CONSTRAINT DF_PWB_REGISTRADO DEFAULT 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_PAGO_WEBPAY_REGISTRADO]
@ID INT
AS
SET NOCOUNT ON
UPDATE [dbo].[Pago_Webpay] SET pwb_registrado = 1 WHERE pwb_id = @ID AND pwb_registrado = 0
SELECT @@ROWCOUNT AS CAMBIO
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PAGO_WEBPAY]
@TOKEN VARCHAR(64) = NULL, @BUY_ORDER VARCHAR(26) = NULL
AS
SET NOCOUNT ON
SELECT pwb_id AS ID, pwb_suscripcion AS SUSCRIPCION, pwb_buy_order AS BUY_ORDER, pwb_monto_clp AS MONTO, pwb_periodos AS PERIODOS,
       pwb_estado AS ESTADO, pwb_ambiente AS AMBIENTE, pwb_codigo_autorizacion AS AUTORIZACION, pwb_tarjeta AS TARJETA,
       pwb_tipo_pago AS TIPO_PAGO, pwb_cuotas AS CUOTAS, CONVERT(VARCHAR(16), pwb_fecha_confirmacion, 120) AS CONFIRMADO,
       pwb_registrado AS REGISTRADO
  FROM [dbo].[Pago_Webpay]
 WHERE (@TOKEN IS NOT NULL AND pwb_token_tbk = @TOKEN) OR (@BUY_ORDER IS NOT NULL AND pwb_buy_order = @BUY_ORDER)
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PAGO_WEBPAY_SIN_REGISTRAR]
AS
SET NOCOUNT ON
SELECT pwb_token_tbk AS TOKEN FROM [dbo].[Pago_Webpay] WHERE pwb_estado = 'AUTORIZADA' AND pwb_registrado = 0 AND pwb_token_tbk IS NOT NULL
GO

PRINT '462_COBROS_WEBPAY aplicado.'
GO
