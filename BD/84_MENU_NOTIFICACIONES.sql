/* ============================================================================
   SIGMA — Bloque 84
   LA PANTALLA DE NOTIFICACIONES
   ----------------------------------------------------------------------------

   NO CUELGA DE INVENTARIO

     Las notificaciones son transversales: hoy avisan de stock y de lotes, pero
     los tipos de activos, ordenes y checklists ya estan declarados desde el
     diseno original. Meterla dentro de Inventario la ataria a un modulo que en
     unas semanas seria uno de varios.

     Va al primer nivel, junto a los modulos, y visible: es lo que uno quiere
     mirar al llegar en la manana.

   EL PERMISO ES EL MAS BASICO QUE HAY

     Cualquiera que entre al sistema puede tener notificaciones; lo que ve
     dentro ya lo filtra el permiso de cada TIPO de alerta. Exigir un permiso
     propio para abrir la bandeja dejaria a alguien con alertas que no puede
     mirar.

     Por eso el menu usa el mismo permiso del modulo de inventario -que es el
     que hoy genera alertas- y la pantalla no exige nada mas: si esa persona no
     puede ver nada, la lista sale vacia y lo dice.
   ============================================================================ */

SET NOCOUNT ON
GO

DECLARE @PRM INT, @MNU INT, @ORDEN INT

SELECT @PRM = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER EXISTENCIAS'

/* Detras del ultimo modulo de primer nivel, para no empujar el menu que la
   gente ya tiene memorizado. */
SELECT @ORDEN = ISNULL(MAX(mnu_orden), 0) + 1
FROM   [dbo].[Menus] WHERE mnu_nivel = 2 AND mnu_visible = 1

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Comun/Notificaciones/Notificaciones.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Notificaciones', 'Lo que el sistema encontró y nadie resolvió',
            2, 1, @ORDEN, '~/View/Comun/Notificaciones/Notificaciones.aspx',
            1, 'mdi mdi-bell-outline', @PRM, 3)   /* AMBOS: la app tambien avisa */

SELECT @MNU = mnu_id FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Comun/Notificaciones/Notificaciones.aspx'

/* Menu_Funcion siempre que nace un menu: sin la fila, Token.PuedeFuncion
   devuelve false para todos -Root incluido- y el boton no aparece, sin error
   que lo explique. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Marcar como leído')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Marcar como leído', @MNU, @PRM)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Revisar ahora')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Revisar ahora', @MNU, @PRM)

PRINT '--- Menu de notificaciones listo'
GO

SELECT  mnu_id, mnu_nombre, mnu_nivel, mnu_orden, mnu_link, mnu_visible,
        CASE mnu_ambito WHEN 1 THEN 'WEB' WHEN 2 THEN 'APP' ELSE 'AMBOS' END AS AMBITO,
        (SELECT COUNT(*) FROM [dbo].[Menu_Funcion] f WHERE f.mfu_menu = m.mnu_id) AS FUNCIONES
FROM    [dbo].[Menus] m
WHERE   mnu_link = '~/View/Comun/Notificaciones/Notificaciones.aspx'
GO
