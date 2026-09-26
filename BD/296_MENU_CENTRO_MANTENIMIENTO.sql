USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  26-09-2026
-- DESCRIPTION:     EL MODULO SE LLAMA CENTRO DE MANTENIMIENTO, Y
--                  PLANIFICACION PASA A SER EL PUNTO DE ENTRADA UNICO A
--                  PROGRAMACIONES, PLAN DE MANTENIMIENTO Y BANDEJA.
-- =============================================
-- SPRINT 1 DEL ANALISIS DE VIABILIDAD, EJECUTADO
--
--   El analisis de unificacion de "Programaciones + Plan de mantenimiento +
--   Bandeja de mantenciones" concluyo que fusionar las tres en un solo
--   controlador/ViewState no conviene -Programaciones sola pesa 80 KB de
--   ViewState con el listado vacio, y el Centro del plan 25 KB mas- pero que
--   unificar el PUNTO DE ENTRADA si es seguro y de bajo costo: es una fila
--   de menu, no un refactor de las paginas pesadas.
--
--   Este bloque hace exactamente eso, nada mas: registra la pantalla nueva
--   (Planificacion.aspx, sin RadGrid ni UpdatePanel, solo literales y
--   enlaces a las tres pantallas reales) reusando el nodo "Planificacion"
--   -no una fila aparte, para no dejar dos filas de menu apuntando al mismo
--   lugar-, y esconde del arbol lateral los tres accesos directos que ahora
--   se alcanzan desde ahi.
--
-- POR QUE EL NODO PADRE (2222) NO SE QUEDA COMO "#" CON HIJOS VISIBLES
--
--   MenusLateral.ascx.cs resuelve un nodo por UNA sola rama: si
--   mnu_link = '#' se dibuja como carpeta que expande a sus hijos (linea
--   164); si no, se dibuja como enlace de pagina y sigue agregando los
--   <li> de sus hijos SIN envolverlos en un <ul> (linea 226) -codigo que
--   nunca se ejercito porque hoy ningun nodo del sistema tiene link real Y
--   whijos visibles a la vez-. Combinar las dos cosas producira HTML
--   invalido en el sidebar (<li> sueltos fuera de cualquier <ul>).
--
--   La solucion es la misma que ya usa el resto del sitio para pantallas a
--   las que se entra desde su padre: los hijos pasan a mnu_visible = 0,
--   igual que las ocho fichas satelite que ya cuelgan de este mismo nodo
--   (Plan de mantenimiento detalle, Hito, Actividad, etc). Su PERMISO no
--   cambia -nadie pierde ni gana acceso-, solo dejan de tener su propia fila
--   en el sidebar porque ahora se llega a ellas desde Planificacion.
--
-- EL PERMISO DEL HUB: 116, NO UNO NUEVO
--
--   El hub muestra datos de los tres modulos, pero solo dos exigen permiso
--   116 (Planes, Bandeja) y uno exige 92 (Programaciones). Inventar un
--   permiso "Centro de Mantenimiento" es, segun el propio analisis de
--   viabilidad, un proyecto de migracion aparte (reasignar
--   Cliente_Usuario_Permiso a quien hoy tiene 92 o 116 por separado) que no
--   corresponde decidir de forma implicita en un bloque de menu. Se usa 116
--   -el permiso de quien planifica, que es la audiencia natural de un hub
--   que junta plan + programacion + bandeja- y se deja constancia aqui: un
--   usuario con SOLO el permiso 92 (ve Programaciones pero no Planes) se
--   queda sin el hub, y sigue entrando a Programaciones por su URL directa
--   -sigue registrada, solo que sin fila visible en el sidebar-. Si Producto
--   pide que ese usuario tambien vea el hub, es la migracion de permisos que
--   el Sprint 6 del analisis ya senala como decision aparte.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* El nodo "Planificacion" (2222) se convierte en el punto de entrada: cambia
   de nombre, deja de ser carpeta ('#') y pasa a apuntar al hub. No se toca
   su mnu_padre ni su mnu_orden -sigue bajo "Mantenimiento", en el mismo
   lugar del sidebar-, asi que la posicion no cambia, solo el contenido de
   la fila. Es UNA fila reusada, no una fila nueva: dos filas con el mismo
   mnu_link confundirian a Token.CargarMapa(), que indexa por link. */
UPDATE [dbo].[Menus]
   SET mnu_nombre  = 'Planificación',
       mnu_link    = '~/View/Mantenimiento/Planificacion.aspx',
       mnu_permiso = 116,
       mnu_ambito  = 1
 WHERE mnu_id = 2222

PRINT '--- Nodo 2222 "Planificacion": de carpeta a pagina (el hub).'
GO

/* El MODULO completo es el que se llama Centro de Mantenimiento: el nodo
   padre (2154), que ademas de Planificacion agrupa Procedimientos, Pautas,
   Tareas, Hallazgos y Ordenes de trabajo. Sigue siendo carpeta ('#'); solo
   cambia su nombre. Poner ese nombre en el hub -como se hizo en la primera
   version de este bloque- dejaba al modulo entero con un nombre generico y
   a una de sus partes con el nombre del todo. */
UPDATE [dbo].[Menus]
   SET mnu_nombre = 'Centro de Mantenimiento'
 WHERE mnu_id = 2154

PRINT '--- Nodo 2154 (antes "Mantenimiento") ahora es "Centro de Mantenimiento".'
GO

/* Los tres accesos directos salen del sidebar. Su permiso NO cambia: siguen
   siendo las mismas pantallas, con la misma fila de Menu_Funcion,
   alcanzables por su URL directa o -ahora- desde las tarjetas del hub. */
UPDATE [dbo].[Menus]
   SET mnu_visible = 0,
       mnu_orden   = 50 + (mnu_id % 50)   -- mismo criterio que las fichas satelite del bloque 286
 WHERE mnu_id IN (2155, 2183, 2229)   -- Programaciones, Planes de mantenimiento, Bandeja de mantenciones
GO
PRINT '--- Programaciones, Planes y Bandeja: ocultos del sidebar, alcanzables desde el hub.'
GO

SELECT  mnu_id, mnu_padre, mnu_orden, mnu_visible, mnu_permiso, mnu_nombre, mnu_link
  FROM  [dbo].[Menus]
 WHERE  mnu_id IN (2154, 2222) OR mnu_padre = 2222
 ORDER  BY mnu_visible DESC, mnu_orden, mnu_id
GO

PRINT '296_MENU_CENTRO_MANTENIMIENTO aplicado.'
GO
