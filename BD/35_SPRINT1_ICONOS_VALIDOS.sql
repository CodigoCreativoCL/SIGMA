USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     CORRIGE ICONOS QUE NO EXISTEN EN LA VERSION DE MDI INSTALADA.
-- =============================================
-- Va DESPUES de 34_SPRINT1_MENUS_WEB.
--
-- QUE PASO
--   El bloque 32 asigno iconos a las pantallas nuevas siguiendo el criterio
--   del bloque 07: usar las variantes -outline en la navegacion. El criterio
--   es correcto, pero se aplico sin comprobar que esos nombres existieran en
--   la version de Material Design Icons que trae Adminto.
--
--   Adminto empaqueta MDI 5.0.45. En esa version todavia no existen
--   mdi-sitemap-outline, mdi-file-tree-outline ni
--   mdi-account-hard-hat-outline: son posteriores.
--
--   Una clase MDI inexistente NO da error. Simplemente no pinta nada, y el
--   menu queda con un hueco donde deberia ir el icono. Por eso paso
--   inadvertido: no hay nada que falle, solo algo que no aparece.
--
-- POR QUE NO SE ACTUALIZA MDI
--   Subir la fuente tocaria los 37 iconos ya migrados en el markup y los
--   que usa el propio Adminto. Es un cambio de riesgo desproporcionado
--   frente a elegir tres nombres que si existen en 5.0.45 y que significan
--   exactamente lo mismo.
--
-- COMO COMPROBARLO
--   Las clases de la tabla Menus se contrastan contra
--   Css/Adminto/assets/css/icons.min.css. El listado del final de este
--   script deja a la vista que quedo asignado.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO

DECLARE @I TABLE (id INT, icono NVARCHAR(100), motivo NVARCHAR(200))

INSERT INTO @I VALUES
 (2079, N'mdi mdi-sitemap',           N'mdi-sitemap-outline no existe en MDI 5.0.45'),
 (2081, N'mdi mdi-file-tree',         N'mdi-file-tree-outline no existe en MDI 5.0.45'),
 (2083, N'mdi mdi-account-hard-hat',  N'mdi-account-hard-hat-outline no existe en MDI 5.0.45')

UPDATE m
   SET m.mnu_icon = i.icono
FROM   [dbo].[Menus] m
JOIN   @I i ON i.id = m.mnu_id
WHERE  ISNULL(m.mnu_icon, '') COLLATE DATABASE_DEFAULT <> i.icono COLLATE DATABASE_DEFAULT
GO

PRINT 'Iconos corregidos a nombres validos en MDI 5.0.45.'
GO


/* ========================================================================
   COMPROBACION

   Los tres corregidos deben aparecer SIN el sufijo -outline. El resto de
   los -outline de la lista si existen en 5.0.45 y se dejan como estan.
   ======================================================================== */

SELECT mnu_id, mnu_nombre, mnu_icon
FROM   [dbo].[Menus]
WHERE  ISNULL(mnu_icon, '') <> ''
ORDER BY mnu_id
GO

SELECT 'iconos fuera de MDI' AS control, COUNT(*) AS valor, 0 AS esperado
FROM   [dbo].[Menus]
WHERE  ISNULL(mnu_icon, '') <> '' AND mnu_icon NOT LIKE 'mdi %'
UNION ALL
SELECT 'los tres corregidos', COUNT(*), 3
FROM   [dbo].[Menus]
WHERE  mnu_id IN (2079, 2081, 2083)
  AND  mnu_icon IN (N'mdi mdi-sitemap', N'mdi mdi-file-tree', N'mdi mdi-account-hard-hat')
GO
