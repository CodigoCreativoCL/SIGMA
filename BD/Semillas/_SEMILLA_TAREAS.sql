USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     DATOS DE PRUEBA PARA TAREAS PROGRAMADAS (T-4287).
-- =============================================
-- ESTO NO ES UNA MIGRACION. Corre despues de _SEMILLA_PLAN_HITOS (usa sus
-- programaciones). Las tareas TAR-001..005 y sus ocurrencias con
-- comentarios ya vienen del bloque 160/161 (demo de la app); aqui solo se
-- les cuelga el «cada cuanto y quien». Idempotente: el INS rechaza la
-- repetida y aca se pregunta antes.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1
DECLARE @USUARIO INT = (SELECT TOP 1 usu_id FROM [dbo].[Usuario] WHERE usu_login = 'rodrigo.quezada@hamburgo.cl')
DECLARE @MENSUAL INT = (SELECT TOP 1 pro_id FROM [dbo].[Programacion] WHERE pro_cliente = @CLIENTE AND pro_nombre = N'Mensual (semilla)')
DECLARE @SEMESTRAL INT = (SELECT TOP 1 pro_id FROM [dbo].[Programacion] WHERE pro_cliente = @CLIENTE AND pro_nombre = N'Semestral (semilla)')
DECLARE @ID INT, @T INT

IF (@USUARIO IS NULL OR @MENSUAL IS NULL)
BEGIN
    RAISERROR('1.- CORRA _SEMILLA_PLAN_HITOS.sql ANTES.', 16, 1)
    RETURN
END

-- TAR-001 revisar nivel de aceite: mensual, responsable Rodrigo
SET @T = (SELECT tar_id FROM [dbo].[Tarea] WHERE tar_cliente = @CLIENTE AND tar_codigo = 'TAR-001')
IF @T IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Programacion] WHERE tpr_tarea = @T AND tpr_programacion = @MENSUAL AND tpr_habilitado = 1)
    EXEC [dbo].[INS_TAREA_PROGRAMACION] @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @TAREA = @T, @PROGRAMACION = @MENSUAL, @USUARIO_RESPONSABLE = @USUARIO, @USUARIO = @USUARIO

-- TAR-005 purgar condensado: semestral, sin responsable fijo (la toma quien este)
SET @T = (SELECT tar_id FROM [dbo].[Tarea] WHERE tar_cliente = @CLIENTE AND tar_codigo = 'TAR-005')
IF @T IS NOT NULL AND @SEMESTRAL IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Programacion] WHERE tpr_tarea = @T AND tpr_programacion = @SEMESTRAL AND tpr_habilitado = 1)
    EXEC [dbo].[INS_TAREA_PROGRAMACION] @ID = @ID OUTPUT, @CLIENTE = @CLIENTE, @TAREA = @T, @PROGRAMACION = @SEMESTRAL, @USUARIO = @USUARIO
GO

SELECT TAREA_CODIGO COLLATE DATABASE_DEFAULT + ' · ' + PROGRAMACION_NOMBRE COLLATE DATABASE_DEFAULT + ' · ' + ISNULL(NULLIF(RESPONSABLE_NOMBRE, ''), 'sin responsable') COLLATE DATABASE_DEFAULT AS RESULTADO
FROM (SELECT tar.tar_codigo AS TAREA_CODIGO, pro.pro_nombre AS PROGRAMACION_NOMBRE,
             LTRIM(RTRIM(ISNULL(u.usu_nombre,'') + ' ' + ISNULL(u.usu_apellido_paterno,''))) AS RESPONSABLE_NOMBRE
      FROM [dbo].[Tarea_Programacion] tpr
      JOIN [dbo].[Tarea] tar ON tar.tar_id = tpr.tpr_tarea
      JOIN [dbo].[Programacion] pro ON pro.pro_id = tpr.tpr_programacion
      LEFT JOIN [dbo].[Usuario] u ON u.usu_id = tpr.tpr_usuario_responsable
      WHERE tpr.tpr_habilitado = 1 AND tar.tar_cliente = 1) x
ORDER BY 1
GO
