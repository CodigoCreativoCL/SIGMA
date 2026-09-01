USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     T-2057 REGISTRA LA PANTALLA ACTIVO_FICHA EN MENUS.
-- =============================================
-- Va DESPUES de 91_SPRINT2_ACTIVO_FICHA_DEMO.
--
-- La ficha e historial es SOLO LECTURA: reutiliza el permiso VER ACTIVOS
-- (quien puede ver activos puede consultar su historia). No lleva
-- Menu_Funcion porque no tiene accion de escritura. Cuelga del nodo Activos
-- como una pantalla mas.
--
-- La seguridad de datos la hace el SP y el controller: filtran por el cliente
-- en sesion, asi que no se ve la historia de otra empresa.
--
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @RAIZ INT
SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = 'Activos' AND mnu_nivel = 2

IF @RAIZ IS NULL
BEGIN
    RAISERROR('No existe el nodo Activos. Ejecute antes el bloque 76.', 16, 1)
    RETURN
END

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT  N'Ficha e historial', N'Ficha e historial de un activo (solo lectura)', 3, @RAIZ, 4,
        N'~/View/Activos/Ficha/ActivoFicha.aspx', 1, N'mdi mdi-timeline-clock-outline',
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER ACTIVOS'), 1
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x
                   WHERE x.mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Ficha/ActivoFicha.aspx')
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'pantalla ficha e historial' AS control, COUNT(*) AS valor, 1 AS esperado
FROM   [dbo].[Menus]
WHERE  mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Ficha/ActivoFicha.aspx'
GO

PRINT '92_SPRINT2_ACTIVO_FICHA_MENU aplicado.'
GO
