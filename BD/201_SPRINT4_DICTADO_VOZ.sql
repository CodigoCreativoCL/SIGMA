USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  22-09-2026
-- DESCRIPTION:     SPRINT 4 (HU-160) Dictar texto en cualquier campo.
--                  T-4153 API_SEL_DICTADO_VOZ  (lo que baja al telefono).
--                  T-4155 datos de prueba en Dictado_Voz.
--                  Ademas: API_SEL_SUSCRIPCION_VIGENTE, el envoltorio SP que el
--                  middleware de la API (T-4158) usa para consultar
--                  FNC_SUSCRIPCION_VIGENTE (la API ejecuta SPs, no texto suelto).
--
-- LO QUE YA ESTABA (verificado, no se toca)
--   T-4152 Modelo/indices: la tabla Dictado_Voz existe. Su clave natural NO es
--          un codigo por cliente sino el UUID que genera el telefono al dictar;
--          el indice unico UX_DVO_UUID es el que hace idempotente la recepcion.
--   T-4154 API_INS_DICTADO_VOZ existe y es idempotente por UUID (si el UUID ya
--          esta, devuelve el mismo id y no inserta un segundo dictado).
--
-- ACOTADO AL USUARIO
--   El dictado es del usuario que hablo. Dictado_Voz no tiene dimension de
--   planta -un dictado no pertenece a una instalacion sino a la persona-, asi
--   que "su planta" se resuelve por el cliente en contexto: se baja lo del
--   usuario dentro de su cliente, nunca lo de otro.
--
-- REAPLICABLE (CREATE OR ALTER + datos idempotentes por UUID).
-- =============================================

SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- T-4153) API_SEL_DICTADO_VOZ - descarga para el dispositivo, del usuario y su
--         cliente. @DESDE trae solo lo posterior (sincronizacion incremental).
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_DICTADO_VOZ]
    @USUARIO INT,
    @CLIENTE INT,
    @DESDE   DATETIME = NULL
AS
SET NOCOUNT ON

SELECT  dvo.dvo_id                   AS ID,
        dvo.dvo_uuid                 AS UUID,
        dvo.dvo_texto                AS TEXTO,
        idi.idi_codigo               AS IDIOMA,
        dvo.dvo_voz_motor            AS MOTOR,
        dvo.dvo_modelo_version       AS MODELO,
        dvo.dvo_confianza            AS CONFIANZA,
        dvo.dvo_duracion_segundo     AS SEGUNDOS,
        dvo.dvo_intentos             AS INTENTOS,
        dvo.dvo_confirmado           AS CONFIRMADO,
        dvo.dvo_confirmado_por_voz   AS CONFIRMADO_VOZ,
        dvo.dvo_fecha_utc            AS FECHA_UTC,
        dvo.dvo_fecha_creacion       AS FECHA_CREACION,
        dvo.dvo_proceso_estado       AS PROCESO_ESTADO,
        dvo.dvo_dispositivo_uuid     AS DISPOSITIVO_UUID
FROM    [dbo].[Dictado_Voz] dvo
LEFT JOIN [dbo].[Idioma]    idi ON idi.idi_id = dvo.dvo_idioma
WHERE   dvo.dvo_cliente = @CLIENTE
  AND   dvo.dvo_usuario = @USUARIO
  AND   (@DESDE IS NULL OR dvo.dvo_fecha_creacion > @DESDE)
ORDER BY dvo.dvo_fecha_creacion
GO

-- ---------------------------------------------------------------------------
-- API_SEL_SUSCRIPCION_VIGENTE - lo consume el middleware (T-4158). Envuelve la
-- funcion FNC_SUSCRIPCION_VIGENTE porque la API ejecuta SPs, no SELECT sueltos.
-- Devuelve una fila si la KEY corresponde a una suscripcion; PUEDE_OPERAR dice
-- si la suscripcion permite trabajar (vigente o en gracia).
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_SUSCRIPCION_VIGENTE]
    @KEY_HASH VARBINARY(32)
AS
SET NOCOUNT ON

SELECT CLIENTE, SUSCRIPCION, PLAN_COMERCIAL, ESTADO, FECHA_FIN, DIAS_RESTANTES, PUEDE_OPERAR
FROM   [dbo].[FNC_SUSCRIPCION_VIGENTE](@KEY_HASH)
GO

-- ---------------------------------------------------------------------------
-- T-4155) Datos de prueba. Dos dictados del primer usuario del cliente 1, con
--         UUID fijos: reaplicar el script no duplica (API_INS es idempotente).
-- ---------------------------------------------------------------------------
DECLARE @U INT = (SELECT TOP 1 ucl_id_usuario FROM [dbo].[Cliente_Usuario] WHERE ucl_id_cliente = 1 ORDER BY ucl_id_usuario)
DECLARE @C INT = 1

IF @U IS NOT NULL
BEGIN
    DECLARE @ID INT

    EXEC [dbo].[API_INS_DICTADO_VOZ]
        @UUID = 'A1111111-1111-1111-1111-111111111111', @USUARIO = @U, @CLIENTE = @C,
        @TEXTO = N'Se revisa rodamiento del motor, presenta ruido anormal.',
        @IDIOMA = N'es-CL', @CONFIANZA = 0.9250, @SEGUNDOS = 6, @INTENTOS = 1,
        @DISPOSITIVO = 'D0000000-0000-0000-0000-000000000001', @ID = @ID OUTPUT

    EXEC [dbo].[API_INS_DICTADO_VOZ]
        @UUID = 'A2222222-2222-2222-2222-222222222222', @USUARIO = @U, @CLIENTE = @C,
        @TEXTO = N'Falta ajustar pernos de la tapa; se deja pendiente en la orden.',
        @IDIOMA = N'es-CL', @CONFIANZA = 0.8100, @SEGUNDOS = 5, @INTENTOS = 2,
        @DISPOSITIVO = 'D0000000-0000-0000-0000-000000000001', @ID = @ID OUTPUT
END
GO

SELECT 'dictados del cliente 1' AS control, COUNT(*) AS valor
FROM [dbo].[Dictado_Voz] WHERE dvo_cliente = 1
GO

PRINT '201_SPRINT4_DICTADO_VOZ aplicado (SEL + wrapper suscripcion + datos).'
GO
