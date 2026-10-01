USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  30-09-2026
-- DESCRIPTION:     SIGMA-Pautas-360. Agrupa las dos entradas de inspección bajo
--                  un menú desplegable "Inspección" (igual que "Tareas"): un
--                  nodo grupo (nivel 3, link '#', sin permiso) con
--                  "Pautas de inspección" y "Hallazgos de inspección" como
--                  hijos (nivel 4). No se borra ni se cambia ningún permiso.
--                  ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

-- Centro de Mantenimiento = el padre del grupo "Tareas" (nivel 3).
DECLARE @RAIZ INT = (SELECT TOP 1 mnu_padre FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = 'Tareas' AND mnu_nivel = 3)
IF @RAIZ IS NULL SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = 'Centro de Mantenimiento' AND mnu_nivel = 2

DECLARE @PAUTAS INT = (SELECT TOP 1 mnu_id FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Mantenimiento/Checklist/ChecklistCentro.aspx')
DECLARE @HALL   INT = (SELECT TOP 1 mnu_id FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Mantenimiento/Hallazgos/ChecklistHallazgos.aspx' AND mnu_visible = 1)

-- 1) Crear el grupo "Inspección" si no existe.
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = N'Inspección' AND mnu_padre = @RAIZ AND mnu_nivel = 3)
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                               mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Inspección', N'Inspección', 3, @RAIZ, 4, N'#', 1, N'mdi mdi-clipboard-check-outline', NULL, 1)

DECLARE @INSP INT = (SELECT TOP 1 mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = N'Inspección' AND mnu_padre = @RAIZ AND mnu_nivel = 3)

-- 2) Mover las dos entradas como hijas del grupo.
IF @PAUTAS IS NOT NULL UPDATE [dbo].[Menus] SET mnu_padre = @INSP, mnu_nivel = 4, mnu_orden = 1 WHERE mnu_id = @PAUTAS
IF @HALL   IS NOT NULL UPDATE [dbo].[Menus] SET mnu_padre = @INSP, mnu_nivel = 4, mnu_orden = 2 WHERE mnu_id = @HALL
GO

SELECT m.mnu_nombre, m.mnu_nivel, m.mnu_orden, m.mnu_visible, ISNULL(m.mnu_link,'(grupo)') link
FROM [dbo].[Menus] m
WHERE m.mnu_nombre COLLATE DATABASE_DEFAULT = N'Inspección'
   OR m.mnu_link COLLATE DATABASE_DEFAULT IN (N'~/View/Mantenimiento/Checklist/ChecklistCentro.aspx', N'~/View/Mantenimiento/Hallazgos/ChecklistHallazgos.aspx')
ORDER BY m.mnu_nivel, m.mnu_orden
GO

PRINT '314_PAUTAS360_MENU_GRUPO_INSPECCION aplicado.'
GO
