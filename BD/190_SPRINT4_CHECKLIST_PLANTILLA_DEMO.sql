USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  11-09-2026
-- DESCRIPTION:     SPRINT 4 - T-4072 DATOS DE PRUEBA PARA PLANTILLAS DE CHECKLIST (HU-090).
-- =============================================
-- Va DESPUES de 189_SPRINT4_CHECKLIST_PLANTILLA (los SP ya estan desplegados).
--
-- Ejercita el propio INS_CHECKLIST_PLANTILLA (no INSERT directo): la carga de
-- prueba pasa por las mismas reglas que la pantalla. Es IDEMPOTENTE: solo
-- siembra si el cliente todavia no tiene plantillas propias. Los ids (planta,
-- tipo de asignacion, tipo de activo) se resuelven en runtime para no asumir
-- "la planta es la 1".
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1, @USUARIO INT, @PLANTA INT, @ASIG INT, @TIPO INT, @NEW INT

SELECT TOP 1 @USUARIO = usu_id FROM [dbo].[Usuario] ORDER BY usu_id
SELECT TOP 1 @PLANTA  = cin_id FROM [dbo].[Cliente_Instalacion] WHERE cin_cliente = @CLIENTE AND cin_habilitado = 1 ORDER BY cin_id
SELECT @ASIG = cat_id FROM [dbo].[Checklist_Asignacion_Tipo] WHERE cat_codigo = 'CUALQUIERA PLANTA'
SELECT TOP 1 @TIPO = ati_id FROM [dbo].[Activo_Tipo] WHERE ati_cliente = @CLIENTE AND ati_habilitado = 1 ORDER BY ati_id

IF @USUARIO IS NULL
BEGIN
    PRINT '--- No hay usuario para sembrar. Se omite la demo.'
    RETURN
END

IF EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla] WHERE cpl_cliente = @CLIENTE)
BEGIN
    PRINT '--- El cliente ya tiene plantillas. Se omite la demo.'
    RETURN
END

EXEC [dbo].[INS_CHECKLIST_PLANTILLA] @ID=@NEW OUTPUT, @CLIENTE=@CLIENTE,
     @CLIENTE_INSTALACION=@PLANTA, @CHECKLIST_ASIGNACION_TIPO=@ASIG, @ACTIVO_TIPO=@TIPO,
     @CODIGO=N'RONDA-BLOWERS', @NOMBRE=N'Ronda diaria sala blowers',
     @DESCRIPCION=N'Recorrido diario de inspeccion visual de la sala de blowers.', @USUARIO=@USUARIO

EXEC [dbo].[INS_CHECKLIST_PLANTILLA] @ID=@NEW OUTPUT, @CLIENTE=@CLIENTE,
     @CLIENTE_INSTALACION=@PLANTA, @CHECKLIST_ASIGNACION_TIPO=@ASIG, @ACTIVO_TIPO=NULL,
     @CODIGO=N'ARRANQUE-LINEA', @NOMBRE=N'Checklist de arranque de linea',
     @DESCRIPCION=N'Verificaciones antes de poner en marcha la linea al inicio del turno.', @USUARIO=@USUARIO

EXEC [dbo].[INS_CHECKLIST_PLANTILLA] @ID=@NEW OUTPUT, @CLIENTE=@CLIENTE,
     @CLIENTE_INSTALACION=NULL, @CHECKLIST_ASIGNACION_TIPO=NULL, @ACTIVO_TIPO=NULL,
     @CODIGO=N'SEGURIDAD-LOTO', @NOMBRE=N'Verificacion de bloqueo de energia (LOTO)',
     @DESCRIPCION=N'Confirmacion de aislamiento y bloqueo antes de intervenir un equipo.', @USUARIO=@USUARIO

PRINT '--- Plantillas de checklist sembradas para el cliente ' + LTRIM(STR(@CLIENTE)) + ' (proceso ejercitado).'
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */
SELECT cpl_id, cpl_cliente, cpl_codigo, cpl_nombre, cpl_habilitado
FROM   [dbo].[Checklist_Plantilla]
WHERE  cpl_cliente = 1
ORDER  BY cpl_id
GO

PRINT '190_SPRINT4_CHECKLIST_PLANTILLA_DEMO aplicado.'
GO
