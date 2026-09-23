USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  22-09-2026
-- DESCRIPTION:     SPRINT 4 (HU-094) T-4209 REGISTRA LAS PANTALLAS DE PROGRAMACION DE PAUTAS EN MENUS.
-- =============================================
-- Listado y ficha cuelgan del nodo Mantenimiento. Reusan los permisos de pautas
-- (VER PAUTAS / CREAR EDITAR PAUTAS): quien administra pautas administra su
-- programacion. La ficha va oculta (mnu_orden 99, mnu_visible 0). Sin fila en
-- Menus no se abren; el boton Nuevo lo habilita Menu_Funcion. La seguridad de
-- datos la hace el filtro por cliente. ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @RAIZ INT
SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT='Mantenimiento' AND mnu_nivel=2
IF @RAIZ IS NULL
BEGIN RAISERROR('No existe el nodo Mantenimiento.', 16, 1) RETURN END

DECLARE @M TABLE (nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT, link NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  orden INT, visible BIT, icono NVARCHAR(100) COLLATE DATABASE_DEFAULT, permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @M VALUES
    (N'Programación de pautas',           N'~/View/Mantenimiento/Checklist/ChecklistProgramacions.aspx', 5, 1, N'mdi mdi-calendar-clock', N'VER PAUTAS'),
    (N'Programación de pauta (detalle)',  N'~/View/Mantenimiento/Checklist/ChecklistProgramacion.aspx',  99, 0, NULL,                    N'VER PAUTAS')

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT m.nombre, m.nombre, 3, @RAIZ, m.orden, m.link, m.visible, m.icono,
       (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = m.permiso), 1
FROM   @M m
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x WHERE x.mnu_link COLLATE DATABASE_DEFAULT = m.link)

DECLARE @F TABLE (link NVARCHAR(500) COLLATE DATABASE_DEFAULT, funcion NVARCHAR(200) COLLATE DATABASE_DEFAULT, permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @F VALUES (N'~/View/Mantenimiento/Checklist/ChecklistProgramacions.aspx', N'Crear y editar', N'CREAR EDITAR PAUTAS')

INSERT INTO [dbo].[Menu_Funcion] (mfu_menu, mfu_nombre, mfu_permiso)
SELECT m.mnu_id, f.funcion, p.prm_id
FROM   @F f
JOIN   [dbo].[Menus] m ON m.mnu_link COLLATE DATABASE_DEFAULT = f.link
JOIN   [dbo].[Permiso] p ON p.prm_codigo = f.permiso
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] x WHERE x.mfu_menu=m.mnu_id AND x.mfu_nombre COLLATE DATABASE_DEFAULT=f.funcion)
GO

SELECT 'pantallas de Programacion' AS control, COUNT(*) AS valor, 2 AS esperado
FROM   [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Mantenimiento/Checklist/ChecklistProgramacion%'
GO

PRINT '198_SPRINT4_CHECKLIST_PROGRAMACION_MENU aplicado.'
GO
