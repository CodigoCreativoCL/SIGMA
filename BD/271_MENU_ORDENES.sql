USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     EL MODULO CORRECTIVO SE LLAMA COMO LO BUSCA LA GENTE.
-- =============================================
-- El bloque 270 lo llamo "Ordenes de trabajo y fallas", que enumera su
-- contenido en vez de nombrarlo. Se llama "Ordenes de trabajo": es lo que la
-- gente busca en el menu, y la falla es su origen -se llega a ella desde ahi
-- y desde el centro del activo-.
--
-- La agrupacion no cambia: adentro siguen Ordenes de trabajo y Fallas, con
-- sus fichas de detalle.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @MANTENIMIENTO INT = 2154
DECLARE @MODULO INT

SELECT  @MODULO = [mnu_id]
  FROM  [dbo].[Menus]
 WHERE  [mnu_padre] = @MANTENIMIENTO
   AND  [mnu_nombre] = N'Órdenes de trabajo y fallas'

IF @MODULO IS NULL
BEGIN
    PRINT '--- el menu ya tiene su nombre nuevo o no existe: nada que hacer.'
    RETURN
END

/* La carpeta toma el nombre; la pantalla que ya se llamaba igual pasa a
   "Listado" para que el menu no diga dos veces lo mismo. */
UPDATE  [dbo].[Menus]
   SET  [mnu_nombre] = N'Órdenes de trabajo'
 WHERE  [mnu_id] = @MODULO

UPDATE  [dbo].[Menus]
   SET  [mnu_nombre] = N'Listado de órdenes'
 WHERE  [mnu_id] = 2196
GO

PRINT '271_MENU_ORDENES aplicado.'
GO
