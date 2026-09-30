USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  29-09-2026
-- DESCRIPTION:     SIGMA-Pautas-360. Consolidación del menú: bajo inspección
--                  deben quedar SOLO "Pautas de inspección" y "Hallazgos de
--                  inspección" (mockup 01). Las siguientes ya viven dentro del
--                  centro de la pauta, así que salen del sidebar (mnu_visible=0,
--                  NO se borran; siguen sirviéndose y accesibles desde el centro):
--                    - Umbrales de ítems  -> pestaña/acción Estructura
--                    - Dependencias de ítems -> pestaña/acción Estructura
--                    - Historial de ejecuciones -> pestaña Ocurrencias y ejecuciones
--                  (Programación de pautas ya se ocultó en BD/312.)
--                  ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

UPDATE [dbo].[Menus] SET mnu_visible = 0
 WHERE mnu_visible = 1
   AND mnu_link COLLATE DATABASE_DEFAULT IN (
        N'~/View/Mantenimiento/Checklist/ChecklistItemValidacions.aspx',
        N'~/View/Mantenimiento/Checklist/ChecklistItemDependencias.aspx',
        N'~/View/Mantenimiento/Checklist/ChecklistHistorial.aspx')
GO

SELECT mnu_nombre, mnu_visible
FROM   [dbo].[Menus]
WHERE  mnu_link COLLATE DATABASE_DEFAULT IN (
        N'~/View/Mantenimiento/Checklist/ChecklistPlantillas.aspx',
        N'~/View/Mantenimiento/Checklist/ChecklistCentro.aspx',
        N'~/View/Mantenimiento/Checklist/ChecklistProgramacions.aspx',
        N'~/View/Mantenimiento/Checklist/ChecklistItemValidacions.aspx',
        N'~/View/Mantenimiento/Checklist/ChecklistItemDependencias.aspx',
        N'~/View/Mantenimiento/Checklist/ChecklistHistorial.aspx',
        N'~/View/Mantenimiento/Hallazgos/ChecklistHallazgos.aspx')
ORDER BY mnu_visible DESC, mnu_nombre
GO

PRINT '313_PAUTAS360_MENU_CONSOLIDAR aplicado.'
GO
