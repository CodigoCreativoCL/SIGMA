USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     T-3206 DATOS DE PRUEBA PARA PROCEDIMIENTOS REUTILIZABLES (HU-061).
-- =============================================
-- Va DESPUES de 101_PROCEDIMIENTO (los SP ya estan desplegados).
--
-- Ejercita el propio INS_PROCEDIMIENTO (no INSERT directo): la carga de prueba
-- pasa por las mismas reglas que la pantalla. Es IDEMPOTENTE: solo siembra si
-- el cliente todavia no tiene procedimientos propios.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1, @USUARIO INT, @TIPO INT, @PERMISO INT, @NEW INT

SELECT TOP 1 @USUARIO = usu_id FROM [dbo].[Usuario] ORDER BY usu_id
SELECT TOP 1 @TIPO = ati_id FROM [dbo].[Activo_Tipo] WHERE ati_cliente = @CLIENTE AND ati_habilitado = 1 ORDER BY ati_id
SELECT @PERMISO = ptt_id FROM [dbo].[Permiso_Trabajo_Tipo] WHERE ptt_codigo = 'ALTURA'
IF @PERMISO IS NULL SELECT TOP 1 @PERMISO = ptt_id FROM [dbo].[Permiso_Trabajo_Tipo] ORDER BY ptt_id

IF @USUARIO IS NULL
BEGIN
    PRINT '--- No hay usuario para sembrar. Se omite la demo.'
    RETURN
END

IF EXISTS (SELECT 1 FROM [dbo].[Procedimiento] WHERE prc_cliente = @CLIENTE)
BEGIN
    PRINT '--- El cliente ya tiene procedimientos. Se omite la demo.'
    RETURN
END

EXEC [dbo].[INS_PROCEDIMIENTO] @ID=@NEW OUTPUT, @CLIENTE=@CLIENTE,
     @CODIGO=N'CAMBIO-RODAMIENTOS', @NOMBRE=N'Cambio de rodamientos de motor',
     @VERSION=1, @ACTIVO_TIPO=@TIPO, @DESCRIPCION=N'Receta estándar para reemplazo de rodamientos.',
     @DURACION=120, @REQUIERE_PERMISO=0, @PERMISO_TIPO=NULL, @USUARIO=@USUARIO

EXEC [dbo].[INS_PROCEDIMIENTO] @ID=@NEW OUTPUT, @CLIENTE=@CLIENTE,
     @CODIGO=N'LUBRICACION-GENERAL', @NOMBRE=N'Lubricación general programada',
     @VERSION=1, @ACTIVO_TIPO=NULL, @DESCRIPCION=N'Lubricación de puntos según carta.',
     @DURACION=45, @REQUIERE_PERMISO=0, @PERMISO_TIPO=NULL, @USUARIO=@USUARIO

EXEC [dbo].[INS_PROCEDIMIENTO] @ID=@NEW OUTPUT, @CLIENTE=@CLIENTE,
     @CODIGO=N'INSPECCION-ALTURA', @NOMBRE=N'Inspección de estructura en altura',
     @VERSION=1, @ACTIVO_TIPO=NULL, @DESCRIPCION=N'Requiere permiso de trabajo en altura.',
     @DURACION=90, @REQUIERE_PERMISO=1, @PERMISO_TIPO=@PERMISO, @USUARIO=@USUARIO

PRINT '--- Procedimientos sembrados para el cliente ' + LTRIM(STR(@CLIENTE)) + ' (proceso ejercitado).'
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */
SELECT prc_id, prc_cliente, prc_codigo, prc_version, prc_nombre, prc_requiere_permiso, prc_habilitado
FROM   [dbo].[Procedimiento]
ORDER  BY prc_id
GO

PRINT '130_SPRINT3_PROCEDIMIENTO_DEMO aplicado.'
GO
