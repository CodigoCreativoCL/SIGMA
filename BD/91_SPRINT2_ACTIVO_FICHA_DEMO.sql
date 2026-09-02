USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     T-2052 DATOS DE PRUEBA DEL HISTORIAL DE UN ACTIVO PARA EJERCITAR HU-037.
-- =============================================
-- Va DESPUES de 90_SPRINT2_ACTIVO_FICHA.
--
-- Siembra la linea de tiempo del activo MOT-001 de Hamburgo: tres cambios de
-- estado y tres mediciones de su horometro. Asi SEL_ACTIVO_FICHA devuelve
-- eventos reales para probar los filtros, el orden y la paginacion. La
-- posicion no se siembra porque no hay Activo_Posicion cargada todavia.
--
-- ES IDEMPOTENTE: no re-siembra si el activo ya tiene historial.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1, @USUARIO INT = 1
DECLARE @ACT INT, @HOR INT, @NOW DATETIME = GETUTCDATE()

SELECT @ACT = act_id FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_codigo = N'MOT-001'
SELECT @HOR = ame_id FROM [dbo].[Activo_Medidor] WHERE ame_activo = @ACT AND ame_codigo = N'HOROMETRO'

IF @ACT IS NULL
BEGIN
    PRINT '--- No esta el activo MOT-001 (falta el bloque 75). No se carga historial.'
    RETURN
END


/* ---- Cambios de estado ---- */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Estado_Historial] WHERE aeh_activo = @ACT)
BEGIN
    INSERT INTO [dbo].[Activo_Estado_Historial]
        (aeh_cliente, aeh_activo, aeh_activo_estado, aeh_fecha_inicio_utc, aeh_fecha_fin_utc,
         aeh_motivo, aeh_usuario_creacion, aeh_fecha_creacion)
    VALUES
        (@CLIENTE, @ACT, 1, DATEADD(DAY, -60, @NOW), DATEADD(DAY, -20, @NOW),
         N'Puesta en marcha inicial', @USUARIO, DATEADD(DAY, -60, @NOW)),
        (@CLIENTE, @ACT, 4, DATEADD(DAY, -20, @NOW), DATEADD(DAY, -5, @NOW),
         N'Mantenimiento preventivo programado', @USUARIO, DATEADD(DAY, -20, @NOW)),
        (@CLIENTE, @ACT, 1, DATEADD(DAY, -5, @NOW), NULL,
         N'Vuelve a operación tras el mantenimiento', @USUARIO, DATEADD(DAY, -5, @NOW))
    PRINT '--- 3 cambios de estado sembrados en MOT-001.'
END
ELSE PRINT '--- MOT-001 ya tiene historial de estado. No se re-siembra.'


/* ---- Mediciones del horometro ---- */
IF @HOR IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor_Lectura] WHERE aml_activo_medidor = @HOR)
BEGIN
    -- aml_dato_origen 3 = Ingreso manual ; aml_medicion_calidad 1 = Valida
    INSERT INTO [dbo].[Activo_Medidor_Lectura]
        (aml_uuid, aml_cliente, aml_activo_medidor, aml_fecha_lectura_utc, aml_valor_acumulado,
         aml_es_reinicio, aml_dato_origen, aml_medicion_calidad, aml_observacion,
         aml_usuario_creacion, aml_fecha_creacion)
    VALUES
        (NEWID(), @CLIENTE, @HOR, DATEADD(DAY, -40, @NOW), 12000.00, 0, 3, 1, N'Lectura mensual', @USUARIO, DATEADD(DAY, -40, @NOW)),
        (NEWID(), @CLIENTE, @HOR, DATEADD(DAY, -20, @NOW), 12250.00, 0, 3, 1, N'Lectura antes del mantenimiento', @USUARIO, DATEADD(DAY, -20, @NOW)),
        (NEWID(), @CLIENTE, @HOR, DATEADD(DAY,  -2, @NOW), 12500.50, 0, 3, 1, N'Lectura de la semana', @USUARIO, DATEADD(DAY, -2, @NOW))
    PRINT '--- 3 mediciones sembradas en el horometro de MOT-001.'
END
ELSE PRINT '--- El horometro de MOT-001 ya tiene lecturas o no existe. No se re-siembra.'
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

DECLARE @ACT INT, @TOTAL INT
SELECT @ACT = act_id FROM [dbo].[Activo] WHERE act_cliente = 1 AND act_codigo = N'MOT-001'
EXEC [dbo].[SEL_ACTIVO_FICHA] @ACTIVO = @ACT, @CLIENTE = 1, @TOTAL = @TOTAL OUTPUT
PRINT '--- Eventos en la linea de tiempo de MOT-001: ' + LTRIM(STR(@TOTAL)) + ' (esperado 6)'
GO

PRINT '91_SPRINT2_ACTIVO_FICHA_DEMO aplicado.'
GO
