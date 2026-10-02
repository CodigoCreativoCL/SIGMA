/* =============================================================================
   Centro de repuestos 360 · reordenar Inventario · nuevo menu Utilidades

   QUE CAMBIA Y POR QUE
     La informacion de un repuesto estaba repartida en cinco pantallas -maestro,
     compatibilidades, existencias, movimientos y vida util-. Para responder
     "¿me conviene seguir comprando este rodamiento?" habia que abrir cinco
     menus y cruzarlos a mano. Ahora hay un Centro de repuestos que lo reune,
     con el mismo patron del centro del activo y del centro de la pauta.

     Inventario queda con tres entradas visibles, en el orden en que se usan:
       1. Bodegas            (donde se guarda)
       2. Tipos de repuesto  (como se clasifica)
       3. Centro de repuestos (el repuesto completo)

     Etiquetas y Escanear salen de Inventario: no son inventario, son
     herramientas que sirven a varios modulos. Pasan a un menu Utilidades.

   LOS MENUS NO SE BORRAN
     Las pantallas absorbidas por el centro quedan con mnu_visible = 0, no se
     eliminan. Siguen siendo URL validas -el centro las abre como ficha modal-
     y los permisos que las referencian siguen apuntando a algo. Borrar la fila
     romperia los permisos asignados a los perfiles.
   ============================================================================= */

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

DECLARE @INVENTARIO INT, @CONFIG INT, @OPERACION INT, @RAIZ INT
DECLARE @PERM_VER INT, @PERM_ETIQUETA INT, @PERM_EXISTENCIA INT
DECLARE @UTILIDADES INT, @CENTRO INT

SELECT @INVENTARIO = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre = N'Inventario' AND mnu_nivel = 2
SELECT @CONFIG     = mnu_id FROM [dbo].[Menus] WHERE mnu_padre = @INVENTARIO AND mnu_nombre = N'Configuración'
SELECT @OPERACION  = mnu_id FROM [dbo].[Menus] WHERE mnu_padre = @INVENTARIO AND mnu_nombre = N'Operación'
SELECT @RAIZ       = mnu_padre FROM [dbo].[Menus] WHERE mnu_id = @INVENTARIO

SELECT @PERM_VER        = prm_id FROM [dbo].[Permiso] WHERE prm_nombre = N'Ver el maestro de repuestos'
SELECT @PERM_ETIQUETA   = prm_id FROM [dbo].[Permiso] WHERE prm_nombre = N'Imprimir etiquetas'
SELECT @PERM_EXISTENCIA = prm_id FROM [dbo].[Permiso] WHERE prm_nombre = N'Ver existencias de bodega'

IF @INVENTARIO IS NULL
BEGIN RAISERROR('No se encontro el menu Inventario.', 16, 1) RETURN END

/* -----------------------------------------------------------------------------
   1. El centro de repuestos. Cuelga de Inventario directamente: ya no hay
      submenus de Configuracion y Operacion, porque el centro los reemplaza.
   ----------------------------------------------------------------------------- */
SELECT @CENTRO = mnu_id FROM [dbo].[Menus]
WHERE  mnu_link = N'~/View/Inventario/Repuestos/RepuestoCentro.aspx'

IF @CENTRO IS NULL
BEGIN
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        (N'Centro de repuestos',
         N'El repuesto completo: compatibilidades, existencias, movimientos, vida útil y evidencia.',
         3, @INVENTARIO, 3, N'~/View/Inventario/Repuestos/RepuestoCentro.aspx',
         1, N'mdi mdi-package-variant-closed', @PERM_VER, 1)
    SET @CENTRO = SCOPE_IDENTITY()
END
ELSE
    UPDATE [dbo].[Menus]
    SET    mnu_padre = @INVENTARIO, mnu_nivel = 3, mnu_orden = 3, mnu_visible = 1,
           mnu_permiso = @PERM_VER, mnu_icon = N'mdi mdi-package-variant-closed'
    WHERE  mnu_id = @CENTRO

/* -----------------------------------------------------------------------------
   2. Bodegas y Tipos de repuesto suben a Inventario, en ese orden.
   ----------------------------------------------------------------------------- */
UPDATE [dbo].[Menus] SET mnu_padre = @INVENTARIO, mnu_nivel = 3, mnu_orden = 1, mnu_visible = 1
WHERE  mnu_link = N'~/View/Inventario/Bodegas/Bodegas.aspx'

UPDATE [dbo].[Menus] SET mnu_padre = @INVENTARIO, mnu_nivel = 3, mnu_orden = 2, mnu_visible = 1
WHERE  mnu_link = N'~/View/Inventario/Repuestos/RepuestoTipos.aspx'

/* -----------------------------------------------------------------------------
   3. Las pantallas que el centro absorbe quedan ocultas, no borradas: el centro
      las abre como ficha modal y los permisos las siguen referenciando.
   ----------------------------------------------------------------------------- */
UPDATE [dbo].[Menus] SET mnu_visible = 0, mnu_padre = @INVENTARIO, mnu_nivel = 3, mnu_orden = 99
WHERE  mnu_link IN (
    N'~/View/Inventario/Repuestos/Repuestos.aspx',
    N'~/View/Inventario/Compatibilidades/RepuestoCompatibilidades.aspx',
    N'~/View/Inventario/Existencias/Existencias.aspx',
    N'~/View/Inventario/Movimientos/Movimientos.aspx',
    N'~/View/Inventario/Repuestos/RepuestoVidaUtil.aspx')

/* Las fichas de detalle ya estaban ocultas; solo se recuelgan de Inventario
   para que los dos agrupadores queden vacios y se puedan ocultar. */
UPDATE [dbo].[Menus] SET mnu_padre = @INVENTARIO, mnu_nivel = 3, mnu_orden = 99
WHERE  mnu_padre IN (@CONFIG, @OPERACION)

UPDATE [dbo].[Menus] SET mnu_visible = 0 WHERE mnu_id IN (@CONFIG, @OPERACION)

/* -----------------------------------------------------------------------------
   4. Utilidades: Etiquetas y Escanear no son inventario. Son herramientas que
      sirven a varios modulos -se etiqueta un activo, un repuesto o una
      posicion-, asi que tenerlas colgando de Inventario obligaba a entrar al
      menu equivocado para usarlas.
   ----------------------------------------------------------------------------- */
SELECT @UTILIDADES = mnu_id FROM [dbo].[Menus]
WHERE  mnu_nombre = N'Utilidades' AND mnu_nivel = 2

IF @UTILIDADES IS NULL
BEGIN
    DECLARE @ORDEN INT
    SELECT @ORDEN = ISNULL(MAX(mnu_orden), 0) + 1 FROM [dbo].[Menus]
    WHERE  mnu_padre = @RAIZ AND mnu_nivel = 2 AND mnu_orden < 90

    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        (N'Utilidades', N'Herramientas transversales: etiquetas y escaneo.',
         2, @RAIZ, @ORDEN, N'#', 1, N'mdi mdi-tools', NULL, 1)
    SET @UTILIDADES = SCOPE_IDENTITY()
END

UPDATE [dbo].[Menus] SET mnu_padre = @UTILIDADES, mnu_nivel = 3, mnu_orden = 1, mnu_visible = 1,
                         mnu_icon = N'mdi mdi-qrcode-scan', mnu_permiso = @PERM_EXISTENCIA
WHERE  mnu_link = N'~/View/Comun/Impresion/Escanear.aspx'

UPDATE [dbo].[Menus] SET mnu_padre = @UTILIDADES, mnu_nivel = 3, mnu_orden = 2, mnu_visible = 1,
                         mnu_icon = N'mdi mdi-label-outline', mnu_permiso = @PERM_ETIQUETA
WHERE  mnu_link = N'~/View/Comun/Impresion/CentroEtiquetas.aspx'

UPDATE [dbo].[Menus] SET mnu_padre = @UTILIDADES, mnu_nivel = 3, mnu_orden = 99, mnu_visible = 0
WHERE  mnu_link = N'~/View/Comun/Impresion/Etiquetas.aspx'

/* -----------------------------------------------------------------------------
   5. Verificacion: como queda el menu
   ----------------------------------------------------------------------------- */
SELECT p.mnu_nombre AS modulo, m.mnu_orden AS orden, m.mnu_nombre AS pantalla,
       m.mnu_link AS link, m.mnu_visible AS visible
FROM   [dbo].[Menus] m JOIN [dbo].[Menus] p ON p.mnu_id = m.mnu_padre
WHERE  m.mnu_padre IN (@INVENTARIO, @UTILIDADES)
ORDER  BY p.mnu_nombre, m.mnu_orden, m.mnu_nombre
GO
