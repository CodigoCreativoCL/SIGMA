USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     EL MENU DE ACTIVOS, EN ORDEN DE CICLO DE VIDA.
-- =============================================
-- EL MENU DECIA "ACTIVOS > CENTRO DEL ACTIVO"
--   Dos problemas. El primero: el padre y su hijo se llamaban casi igual
--   -"Activos" y "Centro del activo"-, asi que la pantalla donde se trabaja
--   todos los dias quedaba escondida detras de una palabra repetida.
--
--   El segundo: el orden. Configurar viene ANTES de operar -tipos, modelos,
--   variables y medidores se definen una vez y despues se usan-, y la lista
--   arrancaba al revés, ofreciendo el centro de un activo que todavia no
--   tiene como estar clasificado.
--
--   Queda: "Centro de Activos" como modulo, con "Configuracion de activos"
--   primero y "Activos" -antes "Centro del activo"- al final, que es el
--   orden en que se usan.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* El modulo pasa a llamarse por lo que es: el centro de los activos. */
UPDATE [dbo].[Menus]
   SET mnu_nombre = 'Centro de Activos'
 WHERE mnu_id = 2123

/* La pantalla de trabajo se llama "Activos" y va al final: se entra a ella
   cuando el catalogo ya esta configurado. */
UPDATE [dbo].[Menus]
   SET mnu_nombre = 'Activos',
       mnu_orden  = 20
 WHERE mnu_id = 2135

/* Configurar primero: es lo que hay que tener listo para que el resto sirva. */
UPDATE [dbo].[Menus]
   SET mnu_orden = 1
 WHERE mnu_id = 2163

/* Las pantallas ocultas -detalles y modales- se van al fondo. No se ven,
   pero comparten la numeracion y un dia alguien las hace visibles. */
UPDATE [dbo].[Menus]
   SET mnu_orden = 50 + mnu_id % 50
 WHERE mnu_padre = 2123
   AND mnu_visible = 0
   AND mnu_orden < 50

PRINT '--- Menu de activos reordenado.'
GO

SELECT  mnu_id, mnu_nombre, mnu_orden, mnu_visible
  FROM  [dbo].[Menus]
 WHERE  mnu_id = 2123 OR mnu_padre = 2123
 ORDER  BY mnu_visible DESC, mnu_orden
GO

PRINT '286_MENU_ACTIVOS_ORDEN aplicado.'
GO
