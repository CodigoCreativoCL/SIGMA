USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  23-09-2026
-- DESCRIPTION:     EL MENU DE ACTIVOS SE UNIFICA EN EL CENTRO DEL ACTIVO.
-- =============================================
-- El menu tenia cinco entradas para un mismo equipo: Activos, Ficha e
-- historial, Posiciones, Configuracion y Variables de condicion. Las dos
-- primeras muestran lo mismo desde que el centro 360 lista y abre; las otras
-- son configuracion, no operacion diaria.
--
-- Queda:
--     Activos
--       - Centro del activo           (listar, abrir y crear equipos)
--       - Configuracion de activos    (tipos, modelos, atributos, posiciones
--                                      y variables de condicion)
--
-- NADA SE BORRA, SE ESCONDE
--   En SIGMA una pantalla existe porque tiene fila en Menus: borrar la fila
--   de Activos.aspx le quitaria el permiso a quien entre por una alerta o por
--   un enlace guardado. Se deja la fila con mnu_visible = 0.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @ACTIVOS       INT = 2123   -- rama Activos
DECLARE @CENTRO        INT = 2135   -- Ficha e historial -> Centro del activo
DECLARE @LISTADO       INT = 2124   -- Activos.aspx
DECLARE @CONFIG        INT = 2163   -- Configuracion de activos
DECLARE @POSICIONES    INT = 2203
DECLARE @VARIABLES     INT = 2194

/* ---- 1. la ficha pasa a ser LA entrada de la rama ---- */
UPDATE  [dbo].[Menus]
   SET  [mnu_nombre] = 'Centro del activo',
        [mnu_descripcion] = 'Toda la vida de un equipo en una sola pantalla.',
        [mnu_orden] = 1,
        [mnu_visible] = 1
 WHERE  [mnu_id] = @CENTRO
GO

/* ---- 2. el listado suelto se esconde, no se borra ---- */
UPDATE  [dbo].[Menus] SET [mnu_visible] = 0 WHERE [mnu_id] = 2124
GO

/* ---- 3. posiciones y variables son configuracion ---- */
UPDATE  [dbo].[Menus]
   SET  [mnu_padre] = 2163, [mnu_nivel] = 4, [mnu_orden] = 4
 WHERE  [mnu_id] = 2203

UPDATE  [dbo].[Menus]
   SET  [mnu_padre] = 2163, [mnu_nivel] = 4, [mnu_orden] = 5
 WHERE  [mnu_id] = 2194

/* El detalle de cada una viaja con su madre para que la rama quede pareja:
   son pantallas de modal, invisibles, pero su permiso cuelga de aqui. */
UPDATE  [dbo].[Menus]
   SET  [mnu_padre] = 2163, [mnu_nivel] = 4
 WHERE  [mnu_id] IN (2204, 2195, 2205)

UPDATE  [dbo].[Menus] SET [mnu_orden] = 9 WHERE [mnu_id] = 2163
GO

/* ---- 4. el numero del menu apunta a donde se resuelve ----

   El badge del menu es la alerta abierta de esa pantalla. Las siete alertas
   de equipos apuntaban al listado; se resuelven en el centro, que es donde
   se ve la medicion, la prediccion y la orden que sale de ellas. */
UPDATE  [dbo].[Alerta_Tipo]
   SET  [alt_menu_link] = '~/View/Activos/Ficha/ActivoFicha.aspx'
 WHERE  ISNULL([alt_menu_link], '') = '~/View/Activos/Activos/Activos.aspx'
GO

PRINT '268_MENU_ACTIVOS_CENTRO aplicado.'
GO
