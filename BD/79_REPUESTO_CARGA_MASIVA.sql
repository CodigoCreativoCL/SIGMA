/* ============================================================================
   SIGMA — Bloque 79
   CARGA Y DESCARGA MASIVA DE REPUESTOS
   ----------------------------------------------------------------------------

   LA PANTALLA ES INVISIBLE EN EL MENU

     Se llega desde el listado de repuestos, que es donde alguien esta cuando
     se le ocurre cargar cien de una vez. Un item de menu propio la pondria al
     mismo nivel que Repuestos, y no es un lugar: es una accion sobre ellos.

     Invisible NO quiere decir sin fila: sin su registro en Menus la pagina
     no abre, porque la seguridad del proyecto es por datos.

   DOS FUNCIONES, DOS PERMISOS DISTINTOS

     Descargar es leer: basta VER REPUESTOS. Cargar es crear: exige CREAR
     EDITAR REPUESTOS. Son la misma pantalla pero no la misma potestad, y
     mezclarlas dejaria a quien solo consulta con un boton que le va a decir
     que no despues de haber elegido el archivo.
   ============================================================================ */

SET NOCOUNT ON
GO

DECLARE @PADRE INT, @VER INT, @EDITAR INT, @MNU INT, @MNU_LISTADO INT

SELECT @PADRE  = mnu_padre FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Inventario/Repuestos/Repuestos.aspx'

SELECT @MNU_LISTADO = mnu_id FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Inventario/Repuestos/Repuestos.aspx'

SELECT @VER    = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER REPUESTOS'
SELECT @EDITAR = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR REPUESTOS'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Inventario/Repuestos/CargaMasivaRepuestos.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Carga masiva de repuestos', 'Alta de repuestos desde una planilla',
            3, @PADRE, 99, '~/View/Inventario/Repuestos/CargaMasivaRepuestos.aspx',
            0, NULL, @EDITAR, 1)

SELECT @MNU = mnu_id FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Inventario/Repuestos/CargaMasivaRepuestos.aspx'

/* Menu_Funcion siempre que nace un menu: sin la fila, Token.PuedeFuncion
   devuelve false para todos -Root incluido- y el boton no aparece, sin error
   que lo explique. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Cargar repuestos')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Cargar repuestos', @MNU, @EDITAR)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Descargar plantilla')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Descargar plantilla', @MNU, @VER)

/* Y los dos botones del listado, que es de donde se llega. */
IF @MNU_LISTADO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                                             WHERE mfu_menu = @MNU_LISTADO
                                               AND mfu_nombre = 'Descargar repuestos')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Descargar repuestos', @MNU_LISTADO, @VER)

IF @MNU_LISTADO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                                             WHERE mfu_menu = @MNU_LISTADO
                                               AND mfu_nombre = 'Carga masiva')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Carga masiva', @MNU_LISTADO, @EDITAR)

PRINT '--- Menu y funciones de carga masiva listos'
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
SELECT  m.mnu_id, m.mnu_nombre, m.mnu_link, m.mnu_visible,
        (SELECT COUNT(*) FROM [dbo].[Menu_Funcion] f WHERE f.mfu_menu = m.mnu_id) AS FUNCIONES
FROM    [dbo].[Menus] m
WHERE   m.mnu_link LIKE '%Repuestos%'
ORDER BY m.mnu_orden
GO
