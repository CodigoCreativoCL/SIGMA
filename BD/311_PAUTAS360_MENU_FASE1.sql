USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  29-09-2026
-- DESCRIPTION:     SIGMA-Pautas-360 (Fase 1). La entrada de menu "Pautas de
--                  inspeccion" (2180) pasa a abrir el CENTRO nuevo
--                  (ChecklistCentro.aspx) en vez del listado viejo. El listado
--                  viejo (ChecklistPlantillas.aspx) NO se borra: queda como
--                  fila oculta (mnu_visible=0) para que el servidor lo siga
--                  sirviendo si algun enlace historico lo pide.
--
-- POR QUE SOLO ESTO EN FASE 1
--   Las demas entradas de pauta (Programacion de pautas, Umbrales,
--   Dependencias, Historial, Versiones) se ocultan CADA UNA cuando su pestaña
--   equivalente exista en el centro (fases 2-4). Ocultarlas ahora dejaria sin
--   acceso a funciones que todavia no tienen pestaña. Regla del proyecto:
--   ocultar (mnu_visible=0), nunca borrar. ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CENTRO NVARCHAR(200) = N'~/View/Mantenimiento/Checklist/ChecklistCentro.aspx'
DECLARE @VIEJO  NVARCHAR(200) = N'~/View/Mantenimiento/Checklist/ChecklistPlantillas.aspx'

-- 1) "Pautas de inspeccion" (2180) ahora abre el centro. Conserva su permiso.
UPDATE [dbo].[Menus] SET mnu_link = @CENTRO
 WHERE mnu_id = 2180 AND mnu_link COLLATE DATABASE_DEFAULT <> @CENTRO

-- 2) El listado viejo queda registrado oculto (para no dejarlo sin servir).
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = @VIEJO)
BEGIN
    DECLARE @RAIZ INT, @PERM INT
    SELECT @RAIZ = mnu_padre, @PERM = mnu_permiso FROM [dbo].[Menus] WHERE mnu_id = 2180
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                               mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Pauta de inspección (listado antiguo)', N'Pauta de inspección (listado antiguo)', 3, @RAIZ, 98,
            @VIEJO, 0, NULL, @PERM, 1)
END
GO

SELECT 'Pautas de inspeccion -> centro' AS control, mnu_link AS valor
FROM [dbo].[Menus] WHERE mnu_id = 2180
GO

PRINT '311_PAUTAS360_MENU_FASE1 aplicado.'
GO
