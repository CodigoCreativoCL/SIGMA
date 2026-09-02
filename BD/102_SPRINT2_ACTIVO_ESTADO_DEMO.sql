USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     T-2150 DATOS DE PRUEBA DEL CAMBIO DE ESTADO PARA EJERCITAR HU-038.
-- =============================================
-- Va DESPUES de 101_SPRINT2_ACTIVO_ESTADO.
--
-- Ejercita el propio proceso ACTIVO_ESTADO sobre BMB-001 (Hamburgo): lo
-- detiene con motivo y lo vuelve a operacion. Asi quedan tramos reales en
-- Activo_Estado_Historial y de paso se prueba el proceso. MOT-001 ya tenia
-- historial sembrado (bloque 91), asi que se usa otro activo.
--
-- ES IDEMPOTENTE: solo corre si BMB-001 no tiene historial de estado todavia.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1, @USUARIO INT = 1
DECLARE @ACT INT, @NEW INT

SELECT @ACT = act_id FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_codigo = N'BMB-001'

IF @ACT IS NULL
BEGIN
    PRINT '--- No esta BMB-001 (falta el bloque 75). No se cargan cambios de estado.'
    RETURN
END

IF EXISTS (SELECT 1 FROM [dbo].[Activo_Estado_Historial] WHERE aeh_activo = @ACT)
BEGIN
    PRINT '--- BMB-001 ya tiene historial de estado. No se re-siembra.'
    RETURN
END

-- Estado inicial: se abre el primer tramo con el estado actual del activo,
-- para que la historia arranque desde su puesta en marcha.
DECLARE @EST_ACTUAL INT
SELECT @EST_ACTUAL = act_activo_estado FROM [dbo].[Activo] WHERE act_id = @ACT

INSERT INTO [dbo].[Activo_Estado_Historial]
    (aeh_cliente, aeh_activo, aeh_activo_estado, aeh_fecha_inicio_utc, aeh_fecha_fin_utc,
     aeh_motivo, aeh_usuario_creacion, aeh_fecha_creacion)
VALUES
    (@CLIENTE, @ACT, @EST_ACTUAL, DATEADD(DAY, -45, GETUTCDATE()), NULL,
     N'Puesta en marcha', @USUARIO, DATEADD(DAY, -45, GETDATE()))

-- Cambio 1: a EN MANTENIMIENTO (4) con motivo.
EXEC [dbo].[ACTIVO_CAMBIAR_ESTADO] @ID = @NEW OUTPUT, @ACTIVO = @ACT, @CLIENTE = @CLIENTE,
     @NUEVO_ESTADO = 4, @MOTIVO = N'Ruido anormal en el rodamiento', @USUARIO = @USUARIO

-- Cambio 2: de vuelta a OPERATIVO (1).
EXEC [dbo].[ACTIVO_CAMBIAR_ESTADO] @ID = @NEW OUTPUT, @ACTIVO = @ACT, @CLIENTE = @CLIENTE,
     @NUEVO_ESTADO = 1, @MOTIVO = N'Rodamiento reemplazado', @USUARIO = @USUARIO

PRINT '--- Historial de estado sembrado en BMB-001 (proceso ejercitado).'
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

DECLARE @ACT INT
SELECT @ACT = act_id FROM [dbo].[Activo] WHERE act_cliente = 1 AND act_codigo = N'BMB-001'
SELECT 'tramos de estado de BMB-001' AS control, COUNT(*) AS valor
FROM   [dbo].[Activo_Estado_Historial] WHERE aeh_activo = @ACT
GO

PRINT '102_SPRINT2_ACTIVO_ESTADO_DEMO aplicado.'
GO
