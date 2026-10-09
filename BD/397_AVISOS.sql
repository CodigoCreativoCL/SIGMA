SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ============================================================================
   397 · Avisos: la bandeja única de lo detectado · 09-10-2026  (parte b)

   Un AVISO es algo detectado que todavía no es trabajo. Se une, sin tabla
   nueva, lo que ya existe:
     7 Falla ............................. Falla
     4 Hallazgo de inspección ............ Checklist_Hallazgo (de una pauta)
     9 Hallazgo en OT .................... Checklist_Hallazgo cuya ejecución es la de una OT
     5 SIGMA AI .......................... Alerta con predicción (PREDICCION RIESGO)
     6 Alerta de medidor ................. Alerta de medidor (fuera de rango, sin lectura,
                                           próximo mantenimiento, lectura a revisar)
   El número es el de Orden_Trabajo_Origen: es el origen de la OT que nace del aviso.
   Estados: NUEVO (sin tratar) · OT (ya tiene OT) · DESCARTADO · RESUELTO (se
   resolvió sin OT; solo se ve en «Todos»).

   Cambios de datos mínimos:
     · Falla: fal_orden_trabajo y el descarte (motivo, quién, cuándo).
     · Aviso_Motivo_Descarte: los atajos de motivo (Recursos › Ajustes los administra).
   Procedimientos: VW_AVISOS, SEL_AVISOS, SEL_AVISO_OT_ABIERTAS,
   UPS_AVISO_GENERAR_OT, UPS_AVISO_VINCULAR, UPD_AVISO_DESCARTAR,
   UPD_AVISO_REABRIR, SEL_MENU_CONTADORES (+ AVISOS).
   Las fechas del aviso salen en HORA DE LA PLANTA (FNC_AHORA).
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET NOCOUNT ON
GO

/* ---- 1 · Falla: enlace a la OT y descarte ---- */
IF COL_LENGTH('dbo.Falla', 'fal_orden_trabajo') IS NULL ALTER TABLE [dbo].[Falla] ADD fal_orden_trabajo INT NULL
IF COL_LENGTH('dbo.Falla', 'fal_motivo_descarte') IS NULL ALTER TABLE [dbo].[Falla] ADD fal_motivo_descarte NVARCHAR(1000) NULL
IF COL_LENGTH('dbo.Falla', 'fal_usuario_descarte') IS NULL ALTER TABLE [dbo].[Falla] ADD fal_usuario_descarte INT NULL
IF COL_LENGTH('dbo.Falla', 'fal_fecha_descarte_utc') IS NULL ALTER TABLE [dbo].[Falla] ADD fal_fecha_descarte_utc DATETIME NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FAL_ORDEN_TRABAJO')
    ALTER TABLE [dbo].[Falla] ADD CONSTRAINT FK_FAL_ORDEN_TRABAJO FOREIGN KEY (fal_orden_trabajo) REFERENCES [dbo].[Orden_Trabajo] (otr_id)
GO

/* ---- 2 · Atajos de motivo de descarte ---- */
IF OBJECT_ID('dbo.Aviso_Motivo_Descarte', 'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Aviso_Motivo_Descarte]
    (
        amd_id                  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Aviso_Motivo_Descarte PRIMARY KEY,
        amd_nombre              NVARCHAR(200) NOT NULL,
        amd_orden               INT NOT NULL CONSTRAINT DF_AMD_ORDEN DEFAULT (0),
        amd_usuario_creacion    INT NULL,
        amd_fecha_creacion      DATETIME NULL CONSTRAINT DF_AMD_FECHA DEFAULT (GETDATE()),
        amd_habilitado          BIT NOT NULL CONSTRAINT DF_AMD_HAB DEFAULT (1)
    )
END
GO
INSERT INTO [dbo].[Aviso_Motivo_Descarte] (amd_nombre, amd_orden)
SELECT v.n, v.o FROM (VALUES
    (N'Duplicado de otro aviso', 1),
    (N'Valor normal para la condición de operación', 2),
    (N'Ya se corrigió en terreno', 3),
    (N'Falsa alarma del sensor', 4)) v(n, o)
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Aviso_Motivo_Descarte] x WHERE x.amd_nombre = v.n)
GO

/* ---- 3 · La vista ---- */
CREATE OR ALTER VIEW [dbo].[VW_AVISOS]
AS
WITH D AS (SELECT DATEDIFF(MINUTE, GETUTCDATE(), [dbo].[FNC_AHORA]()) AS MIN_PLANTA)
/* Fallas */
SELECT  CAST('FAL-' + CAST(f.fal_id AS VARCHAR(12)) AS VARCHAR(20)) AS AVISO,
        CAST(7 AS INT) AS ORIGEN, f.fal_id AS REF, f.fal_cliente AS CLIENTE,
        act.act_cliente_instalacion AS PLANTA_ID, act.act_instalacion_area AS AREA_ID,
        f.fal_activo AS ACTIVO_ID, f.fal_activo_componente AS COMPONENTE_ID,
        f.fal_titulo AS TITULO, f.fal_descripcion AS DETALLE,
        CAST(f.fal_criticidad_nivel AS INT) AS SEVERIDAD,
        DATEADD(MINUTE, D.MIN_PLANTA, f.fal_fecha_deteccion_utc) AS FECHA,
        LTRIM(RTRIM(ISNULL(ur.usu_nombre, N'') + N' ' + ISNULL(ur.usu_apellido_paterno, N''))) AS QUIEN,
        f.fal_detuvo_produccion AS DETUVO, aes.aes_nombre AS ESTADO_ACTIVO, CAST(NULL AS INT) AS CONFIANZA, CAST(NULL AS INT) AS OT_ORIGEN,
        CASE WHEN f.fal_motivo_descarte IS NOT NULL THEN 'DESCARTADO'
             WHEN ISNULL(f.fal_orden_trabajo, ot.otr_id) IS NOT NULL THEN 'OT'
             WHEN f.fal_fecha_solucion_utc IS NOT NULL THEN 'RESUELTO'
             ELSE 'NUEVO' END AS ESTADO,
        ISNULL(f.fal_orden_trabajo, ot.otr_id) AS OT_ID,
        f.fal_motivo_descarte AS MOTIVO,
        (SELECT LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) FROM [dbo].[Usuario] u WHERE u.usu_id = f.fal_usuario_descarte) AS DESCARTA
FROM    [dbo].[Falla] f CROSS JOIN D
JOIN    [dbo].[Activo] act ON act.act_id = f.fal_activo
LEFT JOIN [dbo].[Usuario] ur ON ur.usu_id = f.fal_usuario_reporta
LEFT JOIN [dbo].[Activo_Estado] aes ON aes.aes_id = f.fal_activo_estado_posterior
OUTER APPLY (SELECT TOP 1 o.otr_id FROM [dbo].[Orden_Trabajo] o WHERE o.otr_falla = f.fal_id AND o.otr_habilitado = 1 ORDER BY o.otr_id DESC) ot
WHERE   f.fal_habilitado = 1

UNION ALL
/* Hallazgos de inspección y hallazgos al ejecutar una OT */
SELECT  CAST('HAL-' + CAST(h.cha_id AS VARCHAR(12)) AS VARCHAR(20)),
        CASE WHEN oc.otc_orden_trabajo IS NOT NULL THEN 9 ELSE 4 END, h.cha_id, h.cha_cliente,
        act.act_cliente_instalacion, act.act_instalacion_area,
        h.cha_activo, h.cha_activo_componente,
        h.cha_titulo, h.cha_descripcion,
        CASE h.cha_severidad WHEN 5 THEN 4 WHEN 4 THEN 3 WHEN 3 THEN 2 ELSE 1 END,
        h.cha_fecha_creacion,
        LTRIM(RTRIM(ISNULL(ur.usu_nombre, N'') + N' ' + ISNULL(ur.usu_apellido_paterno, N''))),
        CAST(0 AS BIT), CAST(NULL AS NVARCHAR(100)), CAST(NULL AS INT), oc.otc_orden_trabajo,
        CASE WHEN h.cha_proceso_estado = 5 THEN 'DESCARTADO'
             WHEN h.cha_proceso_estado = 3 OR h.cha_orden_trabajo IS NOT NULL THEN 'OT'
             WHEN h.cha_proceso_estado IN (1, 2) THEN 'NUEVO'
             ELSE 'RESUELTO' END,
        h.cha_orden_trabajo, h.cha_motivo_descarte,
        (SELECT LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) FROM [dbo].[Usuario] u WHERE u.usu_id = h.cha_usuario_confirmacion AND h.cha_proceso_estado = 5)
FROM    [dbo].[Checklist_Hallazgo] h
JOIN    [dbo].[Activo] act ON act.act_id = h.cha_activo
LEFT JOIN [dbo].[Usuario] ur ON ur.usu_id = h.cha_usuario_creacion
OUTER APPLY (SELECT TOP 1 c.otc_orden_trabajo FROM [dbo].[Orden_Trabajo_Checklist] c WHERE c.otc_checklist_ejecucion = h.cha_checklist_ejecucion) oc
WHERE   h.cha_habilitado = 1 AND h.cha_proceso_estado <> 4

UNION ALL
/* SIGMA AI (predicciones con alerta) y alertas de medidor */
SELECT  CAST('ALE-' + CAST(a.ale_id AS VARCHAR(12)) AS VARCHAR(20)),
        CASE WHEN a.ale_prediccion IS NOT NULL THEN 5 ELSE 6 END, a.ale_id, a.ale_cliente,
        act.act_cliente_instalacion, act.act_instalacion_area,
        a.ale_activo, a.ale_activo_componente,
        a.ale_titulo, a.ale_descripcion,
        CASE a.ale_severidad WHEN 5 THEN 4 WHEN 4 THEN 3 WHEN 3 THEN 2 ELSE 1 END,
        DATEADD(MINUTE, D.MIN_PLANTA, a.ale_fecha_deteccion_utc),
        CASE WHEN a.ale_prediccion IS NOT NULL THEN N'SIGMA AI' ELSE N'Medidor' END,
        CAST(0 AS BIT), CAST(NULL AS NVARCHAR(100)),
        CASE WHEN p.pre_confianza IS NULL THEN NULL WHEN p.pre_confianza <= 1 THEN CAST(ROUND(p.pre_confianza * 100, 0) AS INT) ELSE CAST(ROUND(p.pre_confianza, 0) AS INT) END,
        CAST(NULL AS INT),
        CASE WHEN a.ale_alerta_estado = 5 THEN 'DESCARTADO'
             WHEN a.ale_orden_trabajo IS NOT NULL THEN 'OT'
             WHEN a.ale_alerta_estado = 4 THEN 'RESUELTO'
             ELSE 'NUEVO' END,
        a.ale_orden_trabajo, a.ale_motivo_descarte,
        (SELECT LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) FROM [dbo].[Usuario] u WHERE u.usu_id = a.ale_usuario_atencion AND a.ale_alerta_estado = 5)
FROM    [dbo].[Alerta] a CROSS JOIN D
JOIN    [dbo].[Alerta_Tipo] t ON t.alt_id = a.ale_alerta_tipo
JOIN    [dbo].[Activo] act ON act.act_id = a.ale_activo
LEFT JOIN [dbo].[Prediccion] p ON p.pre_id = a.ale_prediccion
WHERE   a.ale_habilitado = 1 AND a.ale_activo IS NOT NULL
  AND   (a.ale_prediccion IS NOT NULL AND t.alt_codigo = N'PREDICCION RIESGO'
         OR a.ale_prediccion IS NULL AND t.alt_codigo IN (N'MEDICION FUERA RANGO', N'MEDIDOR SIN LECTURA', N'MEDIDOR PROXIMO MANTENIMIENTO', N'LECTURA A REVISAR'))
GO

/* ---- 4 · La bandeja ---- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AVISOS]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
SELECT  v.AVISO, v.ORIGEN, v.REF, v.PLANTA_ID, cin.cin_nombre AS PLANTA, v.AREA_ID, iar.iar_nombre AS AREA,
        v.ACTIVO_ID, act.act_codigo AS ACTIVO_CODIGO, act.act_nombre AS ACTIVO, v.COMPONENTE_ID, aco.aco_nombre AS COMPONENTE,
        v.TITULO, v.DETALLE, v.SEVERIDAD, v.FECHA, v.QUIEN, v.DETUVO, v.ESTADO_ACTIVO, v.CONFIANZA,
        v.OT_ORIGEN, otx.otr_correlativo AS OT_ORIGEN_NUMERO,
        v.ESTADO, v.OT_ID, ot.otr_correlativo AS OT_NUMERO, ot.otr_orden_trabajo_estado AS OT_ESTADO, v.MOTIVO, v.DESCARTA
FROM    [dbo].[VW_AVISOS] v
JOIN    [dbo].[Activo] act ON act.act_id = v.ACTIVO_ID
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = v.PLANTA_ID
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = v.AREA_ID
LEFT JOIN [dbo].[Activo_Componente] aco ON aco.aco_id = v.COMPONENTE_ID
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = v.OT_ID
LEFT JOIN [dbo].[Orden_Trabajo] otx ON otx.otr_id = v.OT_ORIGEN
WHERE   v.CLIENTE = @CLIENTE AND (@INSTALACION IS NULL OR v.PLANTA_ID = @INSTALACION)
  AND   (v.ESTADO <> 'DESCARTADO' OR v.FECHA >= DATEADD(DAY, -90, GETDATE()))
ORDER BY CASE v.ESTADO WHEN 'NUEVO' THEN 0 ELSE 1 END, v.SEVERIDAD DESC, v.FECHA DESC

SELECT amd_id AS ID, amd_nombre AS NOMBRE FROM [dbo].[Aviso_Motivo_Descarte] WHERE amd_habilitado = 1 ORDER BY amd_orden, amd_id
RETURN 0
GO

/* ---- 5 · OT abiertas del activo y de su área (anti-duplicado y «Vincular») ---- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AVISO_OT_ABIERTAS]
    @CLIENTE INT,
    @ACTIVO  INT
AS
SET NOCOUNT ON
DECLARE @PLANTA INT, @AREA INT
SELECT @PLANTA = act_cliente_instalacion, @AREA = act_instalacion_area FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE
SELECT  o.otr_id AS OT_ID, o.otr_correlativo AS OT_NUMERO, o.otr_titulo AS TITULO, o.otr_orden_trabajo_estado AS ESTADO,
        o.otr_activo AS ACTIVO_ID, act.act_codigo AS ACTIVO_CODIGO, act.act_nombre AS ACTIVO, aco.aco_nombre AS COMPONENTE,
        CAST(CASE WHEN o.otr_activo = @ACTIVO THEN 1 ELSE 0 END AS BIT) AS MISMO_ACTIVO, iar.iar_nombre AS AREA
FROM    [dbo].[Orden_Trabajo] o
JOIN    [dbo].[Activo] act ON act.act_id = o.otr_activo
LEFT JOIN [dbo].[Activo_Componente] aco ON aco.aco_id = o.otr_activo_componente
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = act.act_instalacion_area
WHERE   o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1 AND o.otr_orden_trabajo_estado < 4
  AND   (o.otr_activo = @ACTIVO OR (act.act_instalacion_area = @AREA AND act.act_cliente_instalacion = @PLANTA))
ORDER BY CASE WHEN o.otr_activo = @ACTIVO THEN 0 ELSE 1 END, o.otr_correlativo DESC
RETURN 0
GO

/* ---- 6 · Generar la OT desde un aviso ---- */
CREATE OR ALTER PROCEDURE [dbo].[UPS_AVISO_GENERAR_OT]
    @CLIENTE INT,
    @ORIGEN  INT,
    @REF     INT,
    @USUARIO INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
DECLARE @PAIS INT, @DATE_NOW DATETIME, @ID INT
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

DECLARE @ESTADO VARCHAR(12), @OT INT
SELECT @ESTADO = ESTADO, @OT = OT_ID FROM [dbo].[VW_AVISOS] WHERE CLIENTE = @CLIENTE AND REF = @REF AND ((@ORIGEN IN (4, 9) AND ORIGEN IN (4, 9)) OR (@ORIGEN IN (5, 6) AND ORIGEN IN (5, 6) AND AVISO LIKE 'ALE-%') OR (@ORIGEN = 7 AND ORIGEN = 7))
IF @ESTADO IS NULL
BEGIN
    RAISERROR('1.- EL AVISO NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF @OT IS NOT NULL
BEGIN
    SELECT otr_id AS OTR_ID, otr_correlativo AS OTR_CORRELATIVO, CAST(1 AS BIT) AS YA_EXISTIA FROM [dbo].[Orden_Trabajo] WHERE otr_id = @OT
    RETURN 0
END
IF @ESTADO <> 'NUEVO'
BEGIN
    RAISERROR('2.- EL AVISO YA FUE TRATADO: NO SE GENERA UNA OT DESDE UNO DESCARTADO O RESUELTO.', 16, 1)
    RETURN -1
END

/* Hallazgos: el SP de siempre (queda enlazado y PROCESADO). */
IF @ORIGEN IN (4, 9)
BEGIN
    EXEC [dbo].[INS_ORDEN_TRABAJO_HALLAZGO] @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @HALLAZGO = @REF, @USUARIO = @USUARIO
    RETURN 0
END
/* SIGMA AI: el SP de la alerta predictiva (también la pasa a EN GESTIÓN). */
IF @ORIGEN = 5
BEGIN
    EXEC [dbo].[INS_ORDEN_TRABAJO_DESDE_PREDICCION] @ALERTA = @REF, @CLIENTE = @CLIENTE, @USUARIO = @USUARIO, @ID = @ID OUTPUT
    RETURN 0
END

/* Falla (7) y alerta de medidor (6): la OT correctiva nace aquí, con el mismo patrón de los hallazgos. */
DECLARE @ACTIVO INT, @COMP INT, @TITULO NVARCHAR(400), @DESC NVARCHAR(MAX), @SEV INT, @DETUVO BIT, @INST INT, @AREA INT
IF @ORIGEN = 7
    SELECT @ACTIVO = f.fal_activo, @COMP = f.fal_activo_componente, @TITULO = f.fal_titulo, @DESC = f.fal_descripcion, @SEV = f.fal_criticidad_nivel, @DETUVO = f.fal_detuvo_produccion,
           @INST = a.act_cliente_instalacion, @AREA = a.act_instalacion_area
    FROM   [dbo].[Falla] f JOIN [dbo].[Activo] a ON a.act_id = f.fal_activo WHERE f.fal_id = @REF AND f.fal_cliente = @CLIENTE
ELSE
    SELECT @ACTIVO = x.ale_activo, @COMP = x.ale_activo_componente, @TITULO = x.ale_titulo, @DESC = x.ale_descripcion,
           @SEV = CASE x.ale_severidad WHEN 5 THEN 4 WHEN 4 THEN 3 WHEN 3 THEN 2 ELSE 1 END, @DETUVO = 0,
           @INST = a.act_cliente_instalacion, @AREA = a.act_instalacion_area
    FROM   [dbo].[Alerta] x JOIN [dbo].[Activo] a ON a.act_id = x.ale_activo WHERE x.ale_id = @REF AND x.ale_cliente = @CLIENTE
IF @INST IS NULL
BEGIN
    RAISERROR('3.- EL ACTIVO NO TIENE PLANTA: NO SE PUEDE GENERAR LA ORDEN.', 16, 1)
    RETURN -1
END
DECLARE @CUERPO NVARCHAR(MAX) = ISNULL(@DESC, N'') + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
    + CASE WHEN @ORIGEN = 7 THEN N'Generada desde un aviso de falla.' ELSE N'Generada desde una alerta de medidor.' END
BEGIN TRY
    BEGIN TRANSACTION
    DECLARE @CORR INT
    SELECT @CORR = ISNULL(MAX(otr_correlativo), 0) + 1 FROM [dbo].[Orden_Trabajo] WITH (UPDLOCK, HOLDLOCK) WHERE otr_cliente = @CLIENTE
    INSERT INTO [dbo].[Orden_Trabajo]
        (otr_cliente, otr_cliente_instalacion, otr_instalacion_area, otr_correlativo, otr_activo, otr_activo_componente,
         otr_orden_trabajo_tipo, otr_orden_trabajo_estrategia, otr_orden_trabajo_origen, otr_orden_trabajo_estado, otr_orden_trabajo_prioridad,
         otr_usuario_generador, otr_titulo, otr_descripcion, otr_falla, otr_usuario_creacion, otr_fecha_creacion)
    VALUES
        (@CLIENTE, @INST, @AREA, @CORR, @ACTIVO, @COMP,
         2, 1, @ORIGEN, 1, @SEV,          -- CORRECTIVA · RUTINARIO · origen del aviso · ABIERTA · prioridad = severidad
         @USUARIO, LEFT(@TITULO, 400), @CUERPO, CASE WHEN @ORIGEN = 7 THEN @REF END, @USUARIO, @DATE_NOW)
    SET @ID = SCOPE_IDENTITY()
    INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
        (oeh_orden_trabajo, oeh_estado_anterior, oeh_estado_nuevo, oeh_motivo, oeh_fecha_cambio_utc, oeh_usuario_creacion, oeh_fecha_creacion)
    VALUES (@ID, NULL, 1, CASE WHEN @ORIGEN = 7 THEN N'Generada desde un aviso de falla' ELSE N'Generada desde una alerta de medidor' END, GETUTCDATE(), @USUARIO, @DATE_NOW)
    INSERT INTO [dbo].[Orden_Trabajo_Paso]
        (otp_orden_trabajo, otp_orden, otp_nombre, otp_descripcion, otp_obligatorio, otp_resultado_paso, otp_usuario_creacion, otp_fecha_creacion, otp_habilitado)
    VALUES (@ID, 1, LEFT(N'Atender: ' + @TITULO, 400), @DESC, 1, 4, @USUARIO, @DATE_NOW, 1)
    IF @ORIGEN = 7
        UPDATE [dbo].[Falla] SET fal_orden_trabajo = @ID, fal_usuario_actualizacion = @USUARIO, fal_fecha_actualizacion = @DATE_NOW WHERE fal_id = @REF
    ELSE
    BEGIN
        UPDATE [dbo].[Alerta] SET ale_orden_trabajo = @ID WHERE ale_id = @REF
        EXEC [dbo].[UPD_ALERTA_ESTADO] @ALERTA = @REF, @CLIENTE = @CLIENTE, @USUARIO = @USUARIO, @ESTADO = 'EN GESTION',
             @MOTIVO = N'Se generó la orden de trabajo desde el aviso.', @RESPONSABLE = NULL
    END
    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'UPS_AVISO_GENERAR_OT', @MSG = @MSG
    RAISERROR('4.- NO FUE POSIBLE GENERAR LA ORDEN: %s', 16, 1, @MSG)
    RETURN -1
END CATCH
SELECT otr_id AS OTR_ID, otr_correlativo AS OTR_CORRELATIVO, CAST(0 AS BIT) AS YA_EXISTIA FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ID
RETURN 0
GO

/* ---- 7 · Vincular el aviso a una OT que ya está abierta (no se crea otra) ---- */
CREATE OR ALTER PROCEDURE [dbo].[UPS_AVISO_VINCULAR]
    @CLIENTE INT,
    @ORIGEN  INT,
    @REF     INT,
    @OT      INT,
    @USUARIO INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] WHERE otr_id = @OT AND otr_cliente = @CLIENTE AND otr_habilitado = 1 AND otr_orden_trabajo_estado < 4)
BEGIN
    RAISERROR('1.- LA OT NO EXISTE O YA ESTÁ CERRADA: ELIGE UNA OT ABIERTA.', 16, 1)
    RETURN -1
END
DECLARE @ESTADO VARCHAR(12)
SELECT @ESTADO = ESTADO FROM [dbo].[VW_AVISOS] WHERE CLIENTE = @CLIENTE AND REF = @REF AND ((@ORIGEN IN (4, 9) AND ORIGEN IN (4, 9)) OR (@ORIGEN IN (5, 6) AND AVISO LIKE 'ALE-%') OR (@ORIGEN = 7 AND ORIGEN = 7))
IF @ESTADO IS NULL
BEGIN
    RAISERROR('2.- EL AVISO NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF @ESTADO <> 'NUEVO'
BEGIN
    RAISERROR('3.- EL AVISO YA FUE TRATADO.', 16, 1)
    RETURN -1
END
BEGIN TRY
    BEGIN TRANSACTION
    IF @ORIGEN IN (4, 9)
        UPDATE [dbo].[Checklist_Hallazgo]
        SET    cha_orden_trabajo = @OT, cha_proceso_estado = 3, cha_usuario_confirmacion = @USUARIO, cha_fecha_confirmacion_utc = GETUTCDATE(),
               cha_usuario_actualizacion = @USUARIO, cha_fecha_actualizacion = @DATE_NOW
        WHERE  cha_id = @REF AND cha_cliente = @CLIENTE
    ELSE IF @ORIGEN = 7
        UPDATE [dbo].[Falla] SET fal_orden_trabajo = @OT, fal_usuario_actualizacion = @USUARIO, fal_fecha_actualizacion = @DATE_NOW WHERE fal_id = @REF AND fal_cliente = @CLIENTE
    ELSE
    BEGIN
        UPDATE [dbo].[Alerta] SET ale_orden_trabajo = @OT WHERE ale_id = @REF AND ale_cliente = @CLIENTE
        EXEC [dbo].[UPD_ALERTA_ESTADO] @ALERTA = @REF, @CLIENTE = @CLIENTE, @USUARIO = @USUARIO, @ESTADO = 'EN GESTION',
             @MOTIVO = N'El aviso se vinculó a una orden de trabajo abierta.', @RESPONSABLE = NULL
    END
    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'UPS_AVISO_VINCULAR', @MSG = @MSG
    RAISERROR('4.- NO FUE POSIBLE VINCULAR EL AVISO: %s', 16, 1, @MSG)
    RETURN -1
END CATCH
SELECT otr_id AS OTR_ID, otr_correlativo AS OTR_CORRELATIVO FROM [dbo].[Orden_Trabajo] WHERE otr_id = @OT
RETURN 0
GO

/* ---- 8 · Descartar con motivo (mínimo 10 caracteres) ---- */
CREATE OR ALTER PROCEDURE [dbo].[UPD_AVISO_DESCARTAR]
    @CLIENTE INT,
    @ORIGEN  INT,
    @REF     INT,
    @MOTIVO  NVARCHAR(1000),
    @USUARIO INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @MOTIVO = LTRIM(RTRIM(ISNULL(@MOTIVO, N'')))
IF LEN(@MOTIVO) < 10
BEGIN
    RAISERROR('1.- INDIQUE EL MOTIVO DEL DESCARTE (AL MENOS 10 CARACTERES).', 16, 1)
    RETURN -1
END
DECLARE @ESTADO VARCHAR(12)
SELECT @ESTADO = ESTADO FROM [dbo].[VW_AVISOS] WHERE CLIENTE = @CLIENTE AND REF = @REF AND ((@ORIGEN IN (4, 9) AND ORIGEN IN (4, 9)) OR (@ORIGEN IN (5, 6) AND AVISO LIKE 'ALE-%') OR (@ORIGEN = 7 AND ORIGEN = 7))
IF @ESTADO IS NULL
BEGIN
    RAISERROR('2.- EL AVISO NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF @ESTADO <> 'NUEVO'
BEGIN
    RAISERROR('3.- EL AVISO YA FUE TRATADO: NO SE PUEDE DESCARTAR.', 16, 1)
    RETURN -1
END
IF @ORIGEN IN (4, 9)
    EXEC [dbo].[UPD_CHECKLIST_HALLAZGO_DESCARTAR] @ID = @REF, @CLIENTE = @CLIENTE, @MOTIVO = @MOTIVO, @USUARIO = @USUARIO
ELSE IF @ORIGEN = 7
    UPDATE [dbo].[Falla]
    SET    fal_motivo_descarte = @MOTIVO, fal_usuario_descarte = @USUARIO, fal_fecha_descarte_utc = GETUTCDATE(),
           fal_usuario_actualizacion = @USUARIO, fal_fecha_actualizacion = @DATE_NOW
    WHERE  fal_id = @REF AND fal_cliente = @CLIENTE
ELSE
    EXEC [dbo].[UPD_ALERTA_ESTADO] @ALERTA = @REF, @CLIENTE = @CLIENTE, @USUARIO = @USUARIO, @ESTADO = 'DESCARTADA', @MOTIVO = @MOTIVO, @RESPONSABLE = NULL
RETURN 0
GO

/* ---- 9 · Deshacer el descarte ---- */
CREATE OR ALTER PROCEDURE [dbo].[UPD_AVISO_REABRIR]
    @CLIENTE INT,
    @ORIGEN  INT,
    @REF     INT,
    @USUARIO INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
DECLARE @ESTADO VARCHAR(12)
SELECT @ESTADO = ESTADO FROM [dbo].[VW_AVISOS] WHERE CLIENTE = @CLIENTE AND REF = @REF AND ((@ORIGEN IN (4, 9) AND ORIGEN IN (4, 9)) OR (@ORIGEN IN (5, 6) AND AVISO LIKE 'ALE-%') OR (@ORIGEN = 7 AND ORIGEN = 7))
IF @ESTADO IS NULL
BEGIN
    RAISERROR('1.- EL AVISO NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF @ESTADO <> 'DESCARTADO'
BEGIN
    RAISERROR('2.- SOLO SE REABRE UN AVISO DESCARTADO.', 16, 1)
    RETURN -1
END
IF @ORIGEN IN (4, 9)
    UPDATE [dbo].[Checklist_Hallazgo]
    SET    cha_proceso_estado = 1, cha_motivo_descarte = NULL, cha_usuario_confirmacion = NULL, cha_fecha_confirmacion_utc = NULL,
           cha_usuario_actualizacion = @USUARIO, cha_fecha_actualizacion = @DATE_NOW
    WHERE  cha_id = @REF AND cha_cliente = @CLIENTE AND cha_proceso_estado = 5
ELSE IF @ORIGEN = 7
    UPDATE [dbo].[Falla]
    SET    fal_motivo_descarte = NULL, fal_usuario_descarte = NULL, fal_fecha_descarte_utc = NULL,
           fal_usuario_actualizacion = @USUARIO, fal_fecha_actualizacion = @DATE_NOW
    WHERE  fal_id = @REF AND fal_cliente = @CLIENTE
ELSE
    UPDATE [dbo].[Alerta]
    SET    ale_alerta_estado = 1, ale_motivo_descarte = NULL, ale_usuario_atencion = NULL, ale_fecha_atencion_utc = NULL,
           ale_usuario_actualizacion = @USUARIO, ale_fecha_actualizacion = @DATE_NOW
    WHERE  ale_id = @REF AND ale_cliente = @CLIENTE AND ale_alerta_estado = 5
RETURN 0
GO

/* ---- 10 · El contador del menú: avisos sin tratar ---- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_MENU_CONTADORES]
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @UTC DATETIME = GETUTCDATE()
SELECT
    OT      = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLIENTE AND otr_habilitado = 1 AND otr_orden_trabajo_estado < 4 AND otr_fecha_programada_utc < @UTC),
    STOCK   = (SELECT COUNT(*) FROM [dbo].[Alerta] a JOIN [dbo].[Alerta_Tipo] t ON t.alt_id = a.ale_alerta_tipo
                WHERE a.ale_cliente = @CLIENTE AND a.ale_habilitado = 1 AND t.alt_codigo IN (N'STOCK MINIMO', N'STOCK MAXIMO') AND a.ale_alerta_estado IN (1, 2, 3)),
    AI      = (SELECT COUNT(*) FROM [dbo].[Prediccion] WHERE pre_cliente = @CLIENTE AND pre_habilitado = 1 AND pre_usuario_revision IS NULL AND pre_fecha_calculo_utc >= DATEADD(HOUR, -24, @UTC)),
    SOPORTE = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] t JOIN [dbo].[Soporte_Estado] e ON e.ses_codigo = t.stk_estado
                WHERE t.stk_cliente = @CLIENTE AND t.stk_usuario = @USUARIO AND t.stk_habilitado = 1 AND e.ses_abierto = 1),
    AVISOS  = (SELECT COUNT(*) FROM [dbo].[VW_AVISOS] WHERE CLIENTE = @CLIENTE AND ESTADO = 'NUEVO')
GO

/* ---- 11 · Catálogo para «Reportar falla»: activos con su área y sus componentes ---- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AVISO_CATALOGO]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
SELECT  a.act_id AS ID, a.act_codigo AS CODIGO, a.act_nombre AS NOMBRE, a.act_cliente_instalacion AS PLANTA_ID,
        ISNULL(iar.iar_nombre, N'Sin área') AS AREA, ISNULL(iar.iar_orden, 9999) AS AREA_ORDEN
FROM    [dbo].[Activo] a
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = a.act_instalacion_area
WHERE   a.act_cliente = @CLIENTE AND a.act_habilitado = 1 AND (@INSTALACION IS NULL OR a.act_cliente_instalacion = @INSTALACION)
ORDER BY ISNULL(iar.iar_orden, 9999), iar.iar_nombre, a.act_codigo
SELECT  c.aco_id AS ID, c.aco_activo AS ACTIVO_ID, c.aco_nombre AS NOMBRE
FROM    [dbo].[Activo_Componente] c
JOIN    [dbo].[Activo] a ON a.act_id = c.aco_activo
WHERE   a.act_cliente = @CLIENTE AND a.act_habilitado = 1 AND c.aco_habilitado = 1 AND (@INSTALACION IS NULL OR a.act_cliente_instalacion = @INSTALACION)
ORDER BY c.aco_activo, c.aco_nombre
RETURN 0
GO

/* ---- 12 · Reportar una falla (y, si se pide, generar su OT de inmediato) ---- */
CREATE OR ALTER PROCEDURE [dbo].[UPS_AVISO_REPORTAR_FALLA]
    @CLIENTE          INT,
    @ACTIVO           INT,
    @COMPONENTE       INT = NULL,
    @TITULO           NVARCHAR(400),
    @DETALLE          NVARCHAR(MAX) = NULL,
    @CRITICIDAD       INT,
    @ESTADO_POSTERIOR INT = NULL,
    @DETUVO           BIT = 0,
    @GENERAR          BIT = 0,
    @USUARIO          INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
SET @TITULO = LTRIM(RTRIM(ISNULL(@TITULO, N'')))
IF LEN(@TITULO) < 5
BEGIN
    RAISERROR('1.- DESCRIBA LA FALLA EN POCAS PALABRAS (AL MENOS 5 CARACTERES).', 16, 1)
    RETURN -1
END
DECLARE @FAL INT
EXEC [dbo].[INS_FALLA] @ID = @FAL OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO = @ACTIVO, @ACTIVO_COMPONENTE = @COMPONENTE,
     @CRITICIDAD_NIVEL = @CRITICIDAD, @TITULO = @TITULO, @DESCRIPCION = @DETALLE, @ESTADO_POSTERIOR = @ESTADO_POSTERIOR,
     @DETUVO_PRODUCCION = @DETUVO, @USUARIO = @USUARIO
IF @FAL IS NULL RETURN -1
DECLARE @OT INT = NULL, @NUM INT = NULL
IF @GENERAR = 1
BEGIN
    CREATE TABLE #R (OTR_ID INT, OTR_CORRELATIVO INT, YA_EXISTIA BIT)
    INSERT INTO #R EXEC [dbo].[UPS_AVISO_GENERAR_OT] @CLIENTE = @CLIENTE, @ORIGEN = 7, @REF = @FAL, @USUARIO = @USUARIO
    SELECT @OT = OTR_ID, @NUM = OTR_CORRELATIVO FROM #R
    DROP TABLE #R
END
SELECT @FAL AS FAL_ID, @OT AS OTR_ID, @NUM AS OTR_CORRELATIVO
RETURN 0
GO
PRINT '397_AVISOS aplicado.'
GO
