USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     CENTRALIZA EL MENU DE ACTIVOS: la Ficha 360 es el hub y los
--                  catalogos quedan en un submenu "Configuracion de activos".
-- =============================================
-- Va DESPUES de 132_SPRINT3_ACTIVO_IMAGEN.
--
-- OBJETIVO
--   El menu Activos tenia 8 items. Se reduce a lo operativo y se separan los
--   catalogos:
--     Activos (lista)
--     Ficha e historial (hub con pestañas: componentes, medidores, atributos…)
--     Configuracion de activos ▸
--         Tipos de activo
--         Modelos de activo
--         Atributos tecnicos
--
--   Medidores, Componentes y Cambiar estado DEJAN de estar en el menu: ahora
--   viven como pestañas/acciones dentro de la ficha. Sus pantallas NO se borran
--   (siguen accesibles): solo se ocultan del menu (mnu_visible = 0).
--
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @RAIZ INT
SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT='Activos' AND mnu_nivel=2
IF @RAIZ IS NULL
BEGIN
    RAISERROR('No existe el nodo Activos (nivel 2).', 16, 1)
    RETURN
END

/* 1) Submenu "Configuracion de activos" (nivel 3, bajo Activos). */
DECLARE @CFG INT
SELECT @CFG = mnu_id FROM [dbo].[Menus]
WHERE  mnu_nombre COLLATE DATABASE_DEFAULT='Configuración de activos' AND mnu_padre=@RAIZ

IF @CFG IS NULL
BEGIN
    INSERT [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                          mnu_link, mnu_visible, mnu_icon, mnu_ambito)
    VALUES (N'Configuración de activos', N'Catálogos de configuración de activos', 3, @RAIZ, 9,
            N'#', 1, N'mdi mdi-tune-variant', 1)
    SET @CFG = SCOPE_IDENTITY()
END

/* 2) Mover los CATALOGOS bajo "Configuracion de activos" (nivel 4). Incluye
      sus fichas de detalle (mnu_visible 0). */
UPDATE [dbo].[Menus]
SET    mnu_padre = @CFG, mnu_nivel = 4
WHERE  mnu_link COLLATE DATABASE_DEFAULT IN (
        N'~/View/Activos/Tipos/ActivoTipos.aspx',
        N'~/View/Activos/Tipos/ActivoTipo.aspx',
        N'~/View/Activos/Modelos/ActivoModelos.aspx',
        N'~/View/Activos/Modelos/ActivoModelo.aspx',
        N'~/View/Activos/Atributos/AtributoTecnicos.aspx',
        N'~/View/Activos/Atributos/AtributoTecnico.aspx')

/* Orden de los catalogos dentro del submenu. */
UPDATE [dbo].[Menus] SET mnu_orden = 1 WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Tipos/ActivoTipos.aspx'
UPDATE [dbo].[Menus] SET mnu_orden = 2 WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Modelos/ActivoModelos.aspx'
UPDATE [dbo].[Menus] SET mnu_orden = 3 WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Atributos/AtributoTecnicos.aspx'

/* 3) OCULTAR del menu lo que pasa a ser pestaña/accion de la ficha (no se
      borran: siguen accesibles desde la ficha). */
UPDATE [dbo].[Menus]
SET    mnu_visible = 0
WHERE  mnu_link COLLATE DATABASE_DEFAULT IN (
        N'~/View/Activos/Medidores/ActivoMedidores.aspx',
        N'~/View/Activos/Componentes/ActivoComponentes.aspx',
        N'~/View/Activos/Estado/ActivoEstado.aspx')

/* 4) Asegurar orden de lo que queda visible directo bajo Activos. */
UPDATE [dbo].[Menus] SET mnu_orden = 1 WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Activos/Activos.aspx'
UPDATE [dbo].[Menus] SET mnu_orden = 2 WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Ficha/ActivoFicha.aspx'
GO


/* ========================================================================
   VERIFICACION — como queda el arbol de Activos
   ======================================================================== */
DECLARE @RAIZ INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT='Activos' AND mnu_nivel=2)
SELECT  n3.mnu_orden AS ORD, n3.mnu_nombre AS NIVEL3, n3.mnu_visible AS VIS,
        n4.mnu_nombre AS NIVEL4, n4.mnu_visible AS VIS4
FROM    [dbo].[Menus] n3
LEFT JOIN [dbo].[Menus] n4 ON n4.mnu_padre = n3.mnu_id AND n4.mnu_visible = 1
WHERE   n3.mnu_padre = @RAIZ
ORDER BY n3.mnu_orden, n4.mnu_orden
GO

PRINT '133_SPRINT3_ACTIVOS_MENU_TABS aplicado.'
GO
