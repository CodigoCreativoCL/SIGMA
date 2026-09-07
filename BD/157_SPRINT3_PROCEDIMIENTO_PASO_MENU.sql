USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     SPRINT 3 (HU-062) T-3295 REGISTRA LAS PANTALLAS DE PASOS EN MENUS.
-- =============================================
-- Va DESPUES de 156_SPRINT3_PROCEDIMIENTO_PASO_SP.
--
-- Los pasos son parte de los procedimientos, asi que REUSAN sus permisos
-- (VER PROCEDIMIENTOS / CREAR EDITAR PROCEDIMIENTOS): quien administra
-- procedimientos administra sus pasos. Cuelgan del nodo "Mantenimiento". La
-- ficha va con mnu_orden 99 y mnu_visible 0. Sin fila en Menus no se abren.
-- La seguridad de datos la hace el filtro por cliente en el SP, no esconder el
-- boton. ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @RAIZ INT
SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT='Mantenimiento' AND mnu_nivel=2
IF @RAIZ IS NULL
BEGIN
    RAISERROR('No existe el nodo Mantenimiento.', 16, 1)
    RETURN
END

DECLARE @M TABLE (nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT, link NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  orden INT, visible BIT, icono NVARCHAR(100) COLLATE DATABASE_DEFAULT, permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @M VALUES
    (N'Pasos de procedimiento',   N'~/View/Mantenimiento/Procedimientos/ProcedimientoPasos.aspx', 3, 1, N'mdi mdi-format-list-numbered', N'VER PROCEDIMIENTOS'),
    (N'Paso de procedimiento (detalle)', N'~/View/Mantenimiento/Procedimientos/ProcedimientoPaso.aspx', 99, 0, NULL,             N'VER PROCEDIMIENTOS')

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT m.nombre, m.nombre, 3, @RAIZ, m.orden, m.link, m.visible, m.icono,
       (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = m.permiso), 1
FROM   @M m
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x WHERE x.mnu_link COLLATE DATABASE_DEFAULT = m.link)

DECLARE @N_MENU INT
SELECT @N_MENU = COUNT(*) FROM [dbo].[Menus]
WHERE  mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Mantenimiento/Procedimientos/ProcedimientoPaso%'
PRINT '--- Menus de Pasos de procedimiento: ' + LTRIM(STR(@N_MENU)) + ' (esperado 2)'
GO

-- Funcion de escritura del listado (reusa el permiso de procedimientos).
DECLARE @F TABLE (link NVARCHAR(500) COLLATE DATABASE_DEFAULT, funcion NVARCHAR(200) COLLATE DATABASE_DEFAULT, permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @F VALUES (N'~/View/Mantenimiento/Procedimientos/ProcedimientoPasos.aspx', N'Crear y editar', N'CREAR EDITAR PROCEDIMIENTOS')

INSERT INTO [dbo].[Menu_Funcion] (mfu_menu, mfu_nombre, mfu_permiso)
SELECT m.mnu_id, f.funcion, p.prm_id
FROM   @F f
JOIN   [dbo].[Menus] m ON m.mnu_link COLLATE DATABASE_DEFAULT = f.link
JOIN   [dbo].[Permiso] p ON p.prm_codigo = f.permiso
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] x WHERE x.mfu_menu=m.mnu_id AND x.mfu_nombre COLLATE DATABASE_DEFAULT=f.funcion)
GO

SELECT 'pantallas de Pasos' AS control, COUNT(*) AS valor, 2 AS esperado
FROM   [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Mantenimiento/Procedimientos/ProcedimientoPaso%'
UNION ALL
SELECT 'funcion del listado de Pasos', COUNT(*), 1
FROM   [dbo].[Menu_Funcion] mf JOIN [dbo].[Menus] m ON m.mnu_id=mf.mfu_menu
WHERE  m.mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Mantenimiento/Procedimientos/ProcedimientoPasos.aspx'
GO

PRINT '157_SPRINT3_PROCEDIMIENTO_PASO_MENU aplicado.'
GO
