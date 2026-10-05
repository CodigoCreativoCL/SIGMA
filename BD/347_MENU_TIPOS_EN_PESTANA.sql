/* ============================================================================
   SIGMA - Bloque 347
   «TIPOS DE ACTIVO» VIVE EN SU PESTAÑA, NO EN EL MENU LATERAL
   ----------------------------------------------------------------------------
   Rediseño del módulo de Activos (05-10-2026): el Centro de activos trae las
   pestañas Activos · Componentes · Variables · Medidores · Tipos de activo ·
   Modelos. El menú lateral vuelve a ocultar «Tipos de activo» y su nodo
   «Configuración de activos» (el bloque 345 los había mostrado). Nunca se
   borra un menú: solo mnu_visible. La pantalla sigue permitida.
   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
GO

UPDATE p SET mnu_visible = 0
FROM   [dbo].[Menus] p
WHERE  p.mnu_id IN (SELECT m.mnu_padre FROM [dbo].[Menus] m
                    WHERE m.mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Tipos/ActivoTipos.aspx')

UPDATE m SET mnu_visible = 0
FROM   [dbo].[Menus] m
WHERE  m.mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Activos/Tipos/ActivoTipos.aspx'
GO

SELECT mnu_nombre, mnu_link, mnu_visible FROM [dbo].[Menus]
WHERE  mnu_link = N'~/View/Activos/Tipos/ActivoTipos.aspx'
   OR  mnu_id IN (SELECT mnu_padre FROM [dbo].[Menus] WHERE mnu_link = N'~/View/Activos/Tipos/ActivoTipos.aspx')
GO
