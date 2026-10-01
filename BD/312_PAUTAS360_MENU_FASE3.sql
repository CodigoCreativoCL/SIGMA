USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  29-09-2026
-- DESCRIPTION:     SIGMA-Pautas-360 (Fase 3). La pestaña "Programaciones" del
--                  centro ya cubre el alta/edición y el listado, asi que
--                  "Programación de pautas" (2213) deja de ser entrada suelta
--                  del menu. NO se borra: mnu_visible=0 (regla del proyecto).
--                  La pantalla sigue existiendo y sirviendo el modal desde el
--                  centro. ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

UPDATE [dbo].[Menus] SET mnu_visible = 0
 WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Mantenimiento/Checklist/ChecklistProgramacions.aspx'
   AND mnu_visible = 1
GO

SELECT 'Programacion de pautas visible' AS control, mnu_visible AS valor
FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Mantenimiento/Checklist/ChecklistProgramacions.aspx'
GO

PRINT '312_PAUTAS360_MENU_FASE3 aplicado.'
GO
