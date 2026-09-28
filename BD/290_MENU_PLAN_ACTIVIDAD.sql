USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  25-09-2026
-- DESCRIPTION:     LAS DOS PANTALLAS DE ACTIVIDADES DE UN HITO (HU-082).
-- =============================================
-- EN SIGMA UNA PANTALLA EXISTE PORQUE TIENE FILA EN Menus
--   No hay Paginas.cs ni lista de rutas en codigo: el master resuelve el
--   acceso con Token.ExigirPagina() contra esta tabla. Un .aspx sin su fila
--   aca no se puede abrir, y una fila con el permiso equivocado lo abre a
--   quien no corresponde. Por eso registrar la pantalla es un INSERT y no un
--   despliegue.
--
-- POR QUE LAS DOS VAN INVISIBLES
--   Se entra a las actividades DESDE un hito, apretandolo en el centro del
--   plan. Un item de menu propio abriria la grilla sin hito elegido, o sea
--   todas las actividades de todos los planes del cliente: una lista larga
--   que no responde ninguna pregunta. Es el mismo criterio con el que ya
--   estan invisibles la ficha del plan, la del hito y la del equipo.
--
-- POR QUE EL PERMISO 116 Y NO UNO NUEVO
--   116 es VER PLANES MANTENIMIENTO, el que ya gobierna todo el modulo. Una
--   actividad no es un dato mas sensible que el hito del que cuelga: quien
--   puede ver el plan puede ver que se hace en el. Un permiso aparte solo
--   agregaria una fila que habria que recordar asignar, y el dia que alguien
--   se olvide el sintoma seria una pantalla en blanco sin explicacion.
--
--   La escritura la sigue pidiendo la funcion "Crear y editar" del mismo
--   permiso, que es lo que consultan la ficha y el listado antes de guardar
--   o eliminar.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* mnu_id es IDENTITY: no se fuerza. La llave real para no duplicar es el
   link, que es lo unico que identifica a una pantalla. */

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanActividades.aspx')
BEGIN
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Actividades del hito (detalle)',
         'Actividades de un hito de plan: que se hace cuando al hito le toca',
         4, 2222, 99, '~/View/Mantenimiento/Planes/PlanActividades.aspx', 0, NULL, 116, 1)

    PRINT '--- Menu de PlanActividades.aspx creado.'
END
ELSE
BEGIN
    /* Ya existia: se corrige lo que importa para el acceso y se deja el
       resto. Reaplicar el bloque no puede cambiar el nombre que alguien
       ajusto a mano, pero si tiene que garantizar el permiso. */
    UPDATE [dbo].[Menus]
       SET mnu_padre = 2222, mnu_nivel = 4, mnu_permiso = 116, mnu_ambito = 1
     WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanActividades.aspx'

    PRINT '--- Menu de PlanActividades.aspx ya existia: permiso verificado.'
END
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanActividad.aspx')
BEGIN
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        ('Actividad de hito (detalle)',
         'Ficha de una actividad de un hito de plan',
         4, 2222, 99, '~/View/Mantenimiento/Planes/PlanActividad.aspx', 0, NULL, 116, 1)

    PRINT '--- Menu de PlanActividad.aspx creado.'
END
ELSE
BEGIN
    UPDATE [dbo].[Menus]
       SET mnu_padre = 2222, mnu_nivel = 4, mnu_permiso = 116, mnu_ambito = 1
     WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanActividad.aspx'

    PRINT '--- Menu de PlanActividad.aspx ya existia: permiso verificado.'
END
GO

/* ========================================================================
   LAS FUNCIONES DE LA PANTALLA, QUE NO SON LO MISMO QUE SU PERMISO

   `mnu_permiso` dice quien ENTRA. `Menu_Funcion` dice quien puede hacer cada
   cosa adentro, y es lo que consulta `Token.PuedeFuncion`. Sin estas filas la
   funcion no existe en el mapa, `PuedeFuncion` devuelve false y la barra de
   comandos de la grilla NO SE DIBUJA: ni "Nueva" ni "Eliminar". El sintoma es
   el peor de todos -el usuario tiene el permiso y concluye que no lo tiene-,
   asi que registrar la pantalla incluye registrar sus funciones.

   Van contra el permiso 117 CREAR EDITAR PLANES MANTENIMIENTO, no contra el
   116: ver el plan y cambiarlo son dos cosas distintas y el modulo ya las
   separa asi -- 2183 y 2184 apuntan al 117 en sus funciones.

   La ficha (PlanActividad.aspx) no lleva funciones: pregunta directo con
   Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO"), igual que PlanHito.aspx.
   ======================================================================== */

DECLARE @MENU_LISTADO INT = (SELECT mnu_id FROM [dbo].[Menus]
                              WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanActividades.aspx')

IF @MENU_LISTADO IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                    WHERE mfu_menu = @MENU_LISTADO AND mfu_nombre = 'Crear y editar')
        INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
        VALUES ('Crear y editar', @MENU_LISTADO, 117)

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                    WHERE mfu_menu = @MENU_LISTADO AND mfu_nombre = 'Eliminar')
        INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
        VALUES ('Eliminar', @MENU_LISTADO, 117)

    PRINT '--- Funciones de PlanActividades.aspx verificadas.'
END
GO

SELECT  f.mfu_id, f.mfu_nombre, f.mfu_menu, f.mfu_permiso, m.mnu_link
  FROM  [dbo].[Menu_Funcion] f
  JOIN  [dbo].[Menus] m ON m.mnu_id = f.mfu_menu
 WHERE  m.mnu_link LIKE '%PlanActividad%'
 ORDER  BY f.mfu_id
GO

SELECT  mnu_id, mnu_padre, mnu_orden, mnu_visible, mnu_permiso, mnu_nombre, mnu_link
  FROM  [dbo].[Menus]
 WHERE  mnu_padre = 2222
 ORDER  BY mnu_visible DESC, mnu_orden, mnu_id
GO

PRINT '290_MENU_PLAN_ACTIVIDAD aplicado.'
GO
