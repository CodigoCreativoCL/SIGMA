USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     EL MODULO DE ACTIVOS SE LLAMA "CONTROL DE ACTIVOS".
-- =============================================
-- "Centro de Activos" repetia la palabra centro con la pantalla que contiene
-- -el centro 360 de UN activo- y se leia como si fueran lo mismo. "Control
-- de activos" nombra el modulo por lo que hace: controlar el parque, no
-- mirar un equipo.
--
-- El nombre no cabe en una linea del menu -son 18 caracteres para un hueco
-- de 105px- y por eso el sidebar deja envolver en dos lineas los nodos de
-- primer nivel. Va en el CSS, no recortando el nombre: acortarlo hasta que
-- quepa fue lo que produjo "Activos" y "Centro del activo", que era el
-- problema original.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

UPDATE [dbo].[Menus]
   SET mnu_nombre = 'Control de activos'
 WHERE mnu_id = 2123

PRINT '--- Modulo renombrado a "Control de activos".'
GO

SELECT  mnu_id, mnu_nombre, mnu_orden, mnu_visible
  FROM  [dbo].[Menus]
 WHERE  mnu_id = 2123 OR (mnu_padre = 2123 AND mnu_visible = 1)
 ORDER  BY mnu_nivel, mnu_orden
GO

PRINT '287_MENU_CONTROL_ACTIVOS aplicado.'
GO
