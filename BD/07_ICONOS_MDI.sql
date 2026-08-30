USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  28-08-2026
-- DESCRIPTION:     LOS ICONOS DEL MENU PASAN A MATERIAL DESIGN ICONS.
-- =============================================
-- Va DESPUES de 06_ASIGNACION_PERFIL.
--
-- POR QUE
--   El sitio mezclaba tres familias de iconos: Font Awesome en la
--   tabla Menus ('fa fa-cogs', 'fas fa-users'), Feather en el markup
--   ('fe-menu', 'fe-bell') y MDI en unos pocos lugares sueltos.
--   Tres fuentes cargadas para lo mismo, con estilos de trazo
--   distintos, es ruido visual y peso de mas.
--
--   Se unifica en Material Design Icons, que es la familia que Adminto
--   ya trae empaquetada en icons.min.css. El markup se migro aparte;
--   este bloque hace la parte que vive en base de datos.
--
-- CRITERIO DE LOS ICONOS
--   Se usan las variantes -outline en la navegacion: el trazo pesa
--   menos sobre el fondo oscuro del sidebar y deja que el item activo
--   sea lo unico solido de la lista.
--
-- LOS MENUS SIN ICONO
--   Las hojas de nivel 4 no llevaban icono y se mantienen asi: en el
--   arbol cuelgan de un padre que si lo tiene, y agregarles uno
--   competiria con el. El menu 41 tenia '*', que no es una clase:
--   se corrige.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO

DECLARE @I TABLE (id INT, icono NVARCHAR(100))
INSERT INTO @I VALUES
 (   2, N'mdi mdi-cog-outline'),              -- Sistema
 (  24, N'mdi mdi-briefcase-outline'),        -- Comercial
 (  32, N'mdi mdi-account-group-outline'),    -- Clientes
 (   3, N'mdi mdi-shield-account-outline'),   -- Acceso
 (   7, N'mdi mdi-earth'),                    -- Zona Geografica
 (1061, N'mdi mdi-puzzle-outline'),           -- Mantenedores
 (  27, N'mdi mdi-account-tie-outline'),      -- Cliente
 (  31, N'mdi mdi-swap-horizontal'),          -- Reasignacion Clientes
 (  40, N'mdi mdi-card-account-details-outline'), -- Identidad
 (  41, N'mdi mdi-account-multiple-outline'), -- Usuarios del cliente ('*' no era una clase)
 (2078, N'mdi mdi-flask-outline')             -- PRUEBA

UPDATE m
   SET m.mnu_icon = i.icono
FROM   [dbo].[Menus] m
JOIN   @I i ON i.id = m.mnu_id
WHERE  ISNULL(m.mnu_icon, '') COLLATE DATABASE_DEFAULT <> i.icono COLLATE DATABASE_DEFAULT
GO

/* ========================================================================
   RED DE SEGURIDAD
   Si quedo cualquier clase de Font Awesome o Feather sin migrar -- por
   ejemplo un menu creado a mano despues -- se limpia. Es preferible sin
   icono que con uno de una familia que ya no se carga: esa clase no
   pinta nada y deja un hueco.
   ======================================================================== */

UPDATE [dbo].[Menus]
   SET mnu_icon = NULL
 WHERE mnu_icon IS NOT NULL
   AND mnu_icon NOT LIKE 'mdi %'
   AND LTRIM(RTRIM(mnu_icon)) <> ''
GO


/* ========================================================================
   COMPROBACION
   'iconos fuera de MDI' debe ser 0.
   ======================================================================== */

SELECT 'iconos MDI'          AS control, COUNT(*) AS valor FROM [dbo].[Menus] WHERE mnu_icon LIKE 'mdi %'
UNION ALL SELECT 'sin icono (correcto en hojas)', COUNT(*) FROM [dbo].[Menus] WHERE ISNULL(mnu_icon,'') = ''
UNION ALL SELECT 'iconos fuera de MDI',           COUNT(*) FROM [dbo].[Menus] WHERE ISNULL(mnu_icon,'') <> '' AND mnu_icon NOT LIKE 'mdi %'
GO

SELECT mnu_id, mnu_nombre, mnu_nivel, ISNULL(mnu_icon,'(sin icono)') AS mnu_icon
FROM   [dbo].[Menus]
WHERE  mnu_visible = 1
ORDER BY mnu_nivel, mnu_padre, mnu_orden
GO
