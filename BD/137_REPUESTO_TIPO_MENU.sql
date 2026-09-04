/* ============================================================================
   SIGMA - Bloque 137
   LAS PANTALLAS DE TIPOS DE REPUESTO
   ----------------------------------------------------------------------------

   Registrar una pantalla en SIGMA es un INSERT en `Menus`, no codigo: la
   seguridad y la navegacion salen de los datos.

   PERMISOS QUE REUTILIZA

     No se crean permisos nuevos. Un tipo de repuesto es parte del maestro de
     repuestos, no otro modulo: quien puede ver repuestos puede ver sus
     categorias -66-, y quien puede crearlos puede crear categorias -67-.

     Inventar "VER TIPOS REPUESTO" obligaria a asignarselo a cada perfil
     existente antes de que la pantalla sirviera, y dejaria a los perfiles que
     ya administran repuestos sin poder clasificarlos.

   LA FICHA VA CON ORDEN 99

     Es la convencion del proyecto para lo que se abre desde otra pantalla y
     no desde el menu. `mnu_visible = 0` la mantiene fuera de la barra
     lateral, pero registrada -y por lo tanto protegida por su permiso-.

   ES IDEMPOTENTE
   ============================================================================ */

SET NOCOUNT ON
GO

/* --------------------------------------------------------------- listado */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Inventario/Repuestos/RepuestoTipos.aspx')
BEGIN
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
         mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    SELECT 'Tipos de repuesto',
           'Las categorias con que el cliente clasifica sus repuestos.',
           4, 2130, 4,
           '~/View/Inventario/Repuestos/RepuestoTipos.aspx',
           1, 'mdi mdi-shape-outline', 66, m.mnu_ambito
    FROM   [dbo].[Menus] m
    WHERE  m.mnu_id = 2113

    PRINT 'Menu "Tipos de repuesto" registrado.'
END
ELSE
    PRINT 'Menu "Tipos de repuesto" ya existe.'
GO

/* ----------------------------------------------------------------- ficha */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Inventario/Repuestos/RepuestoTipo.aspx')
BEGIN
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
         mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    SELECT 'Tipo de repuesto (detalle)',
           'Ficha de una categoria de repuesto.',
           4, 2130, 99,
           '~/View/Inventario/Repuestos/RepuestoTipo.aspx',
           0, 'mdi mdi-shape-outline', 67, m.mnu_ambito
    FROM   [dbo].[Menus] m
    WHERE  m.mnu_id = 2113

    PRINT 'Menu "Tipo de repuesto (detalle)" registrado.'
END
ELSE
    PRINT 'Menu "Tipo de repuesto (detalle)" ya existe.'
GO

SELECT mnu_id, mnu_nombre, mnu_orden, mnu_link, mnu_visible, mnu_permiso
FROM   [dbo].[Menus]
WHERE  mnu_padre = 2130
ORDER BY mnu_orden
GO

PRINT '137_REPUESTO_TIPO_MENU aplicado.'
GO
