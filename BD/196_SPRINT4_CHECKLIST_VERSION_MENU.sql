USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  21-09-2026
-- DESCRIPTION:     SPRINT 4 (HU-093) T-4196 REGISTRA LA PANTALLA DE VERSIONES/PUBLICACION EN MENUS.
-- =============================================
-- ChecklistVersion.aspx se abre desde el listado de Pautas (columna de versiones).
-- Sin fila en Menus no se abre (Token.ExigirPagina niega por omision). Va oculta
-- (mnu_orden 99, mnu_visible 0) con el permiso VER PAUTAS. El disparo de publicar
-- lo valida en el codigo Token.Puede('CREAR EDITAR PAUTAS'), y el SP filtra por
-- cliente. ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @RAIZ INT
SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT='Mantenimiento' AND mnu_nivel=2
IF @RAIZ IS NULL
BEGIN RAISERROR('No existe el nodo Mantenimiento.', 16, 1) RETURN END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
               WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Mantenimiento/Checklist/ChecklistVersion.aspx')
BEGIN
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                               mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Versiones de la pauta', N'Versiones de la pauta', 3, @RAIZ, 99,
            N'~/View/Mantenimiento/Checklist/ChecklistVersion.aspx', 0, NULL,
            (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER PAUTAS'), 1)
END
GO

SELECT 'versiones de pauta en Menus' AS control, COUNT(*) AS valor, 1 AS esperado
FROM   [dbo].[Menus]
WHERE  mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Mantenimiento/Checklist/ChecklistVersion.aspx'
GO

PRINT '196_SPRINT4_CHECKLIST_VERSION_MENU aplicado.'
GO
