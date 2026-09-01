/* ============================================================================
   SIGMA — Bloque 80
   EL MENU DE INVENTARIO GANA UN NIVEL, Y EL ESCANEO SE VA A LA APP
   ----------------------------------------------------------------------------

   POR QUE AGRUPAR

     Inventario tenia seis items planos —Bodegas, Repuestos, Existencias,
     Movimientos, Etiquetas, Escanear— y no todos son la misma clase de cosa.
     Los dos primeros se crean UNA vez y despues casi no se tocan; los dos
     siguientes son el dia a dia. Mezclados, el bodeguero recorre la lista
     entera cada vez para llegar a Movimientos, que es lo que usa a diario.

     Se agrupan como ya lo hace el resto del sitio -Organizacion tiene sus
     Plantas, Areas y Centros de costo colgando de un nodo con link '#'-:

       Inventario
         Configuracion   Bodegas, Repuestos
         Operacion       Existencias, Movimientos
         Etiquetas
         Escanear

     Etiquetas y Escanear NO se agrupan: dos carpetas de un solo elemento
     agregan un clic y no organizan nada.

   EL ESCANEO ES DE LA APP

     Se construyo en la web y ahi se nota que no es su sitio: el navegador de
     escritorio no tiene camara util, y la pantalla queda con un boton grande
     que casi siempre responde "este navegador no puede".

     Su lugar es la APP, que el bodeguero lleva encima cuando esta frente al
     estante. Pasa a ambito AMBOS y no APP a secas, porque la web sigue
     sirviendo para dos cosas reales: teclear un codigo cuando la etiqueta
     esta rayada, y recibir el enlace del QR si alguien lo abre en un
     computador.

   LAS ETIQUETAS SE QUEDAN EN LA WEB

     Imprimir es una tarea de escritorio: se hace una vez, sentado, con la
     impresora al lado. Ponerlo en la APP seria ofrecer algo que el telefono
     no puede terminar.
   ============================================================================ */

SET NOCOUNT ON
GO

DECLARE @INV INT = 2112, @PRM INT, @CONF INT, @OPER INT

/* El nodo agrupador no abre nada, asi que hereda el permiso del modulo: sin
   permiso de inventario no deberia verse ni la carpeta. */
SELECT @PRM = mnu_permiso FROM [dbo].[Menus] WHERE mnu_id = @INV

IF @PRM IS NULL SELECT @PRM = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER BODEGAS'


/* ---- 1. Los dos nodos ---- */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_padre = @INV AND mnu_nombre = 'Configuración')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Configuración', 'Lo que se define una vez', 3, @INV, 1, '#',
            1, 'mdi mdi-cog-outline', @PRM, 1)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_padre = @INV AND mnu_nombre = 'Operación')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Operación', 'El día a día de la bodega', 3, @INV, 2, '#',
            1, 'mdi mdi-swap-horizontal', @PRM, 1)

SELECT @CONF = mnu_id FROM [dbo].[Menus] WHERE mnu_padre = @INV AND mnu_nombre = 'Configuración'
SELECT @OPER = mnu_id FROM [dbo].[Menus] WHERE mnu_padre = @INV AND mnu_nombre = 'Operación'


/* ---- 2. Las hojas se cuelgan, conservando el orden por dependencia ----
   Primero existe la bodega, despues el repuesto; primero hay existencia,
   despues movimientos que la cambien. */
UPDATE [dbo].[Menus] SET mnu_padre = @CONF, mnu_nivel = 4, mnu_orden = 1
 WHERE mnu_link = '~/View/Inventario/Bodegas/Bodegas.aspx'

UPDATE [dbo].[Menus] SET mnu_padre = @CONF, mnu_nivel = 4, mnu_orden = 2
 WHERE mnu_link = '~/View/Inventario/Repuestos/Repuestos.aspx'

UPDATE [dbo].[Menus] SET mnu_padre = @OPER, mnu_nivel = 4, mnu_orden = 1
 WHERE mnu_link = '~/View/Inventario/Existencias/Existencias.aspx'

UPDATE [dbo].[Menus] SET mnu_padre = @OPER, mnu_nivel = 4, mnu_orden = 2
 WHERE mnu_link = '~/View/Inventario/Movimientos/Movimientos.aspx'

/* Etiquetas y Escanear quedan al nivel del modulo: agrupar de a uno no
   organiza, solo esconde. */
UPDATE [dbo].[Menus] SET mnu_orden = 3 WHERE mnu_link = '~/View/Comun/Impresion/CentroEtiquetas.aspx'
UPDATE [dbo].[Menus] SET mnu_orden = 4 WHERE mnu_link = '~/View/Comun/Impresion/Escanear.aspx'

/* Las fichas invisibles siguen a su listado: no se ven en el menu, pero un
   padre que ya no corresponde confunde a quien lea la tabla. */
UPDATE [dbo].[Menus] SET mnu_padre = @CONF, mnu_nivel = 4
 WHERE mnu_link IN ('~/View/Inventario/Bodegas/Bodega.aspx',
                    '~/View/Inventario/Repuestos/Repuesto.aspx',
                    '~/View/Inventario/Repuestos/CargaMasivaRepuestos.aspx')

UPDATE [dbo].[Menus] SET mnu_padre = @OPER, mnu_nivel = 4
 WHERE mnu_link IN ('~/View/Inventario/Existencias/Existencia.aspx',
                    '~/View/Inventario/Movimientos/Movimiento.aspx')


/* ---- 3. El escaneo, a la APP ---- */
UPDATE [dbo].[Menus] SET mnu_ambito = 3   /* AMBOS */
 WHERE mnu_link = '~/View/Comun/Impresion/Escanear.aspx'

/* Y el permiso que lo gobierna tiene que existir en la APP: si el permiso es
   solo WEB, el menu de ambito AMBOS no aparece igual. */
UPDATE [dbo].[Permiso] SET prm_permiso_ambito = 3
 WHERE prm_codigo = 'VER EXISTENCIAS' AND prm_permiso_ambito = 1

/* El bodeguero es quien va a escanear. Si no tenia el permiso, se le da. */
DECLARE @VER INT, @BODEGUERO INT = 4

SELECT @VER = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER EXISTENCIAS'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso]
                WHERE ppe_perfil = @BODEGUERO AND ppe_permiso = @VER)
    INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
    VALUES (@BODEGUERO, @VER, 1, GETDATE())

/* Imprimir es de escritorio: se hace sentado, con la impresora al lado. El
   permiso nacio con ambito AMBOS -copiado de VER BODEGAS- y eso lo ofrecia en
   la APP, donde ninguna pantalla lo usa. Inerte, pero confunde a quien lea la
   tabla buscando que puede hacer el telefono. */
UPDATE [dbo].[Permiso] SET prm_permiso_ambito = 1
 WHERE prm_codigo = 'IMPRIMIR ETIQUETAS'

PRINT '--- Menu reorganizado y escaneo habilitado en la APP'
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
;WITH ARBOL AS (
    SELECT mnu_id, mnu_nombre, mnu_nivel, mnu_padre, mnu_orden, mnu_ambito,
           CAST(mnu_nombre AS NVARCHAR(400)) AS RUTA
    FROM   [dbo].[Menus] WHERE mnu_id = 2112

    UNION ALL

    SELECT h.mnu_id, h.mnu_nombre, h.mnu_nivel, h.mnu_padre, h.mnu_orden, h.mnu_ambito,
           CAST(a.RUTA + N' > ' + h.mnu_nombre AS NVARCHAR(400))
    FROM   [dbo].[Menus] h
    JOIN   ARBOL a ON a.mnu_id = h.mnu_padre
    WHERE  h.mnu_visible = 1
)
SELECT  RUTA, mnu_nivel AS NIVEL, mnu_orden AS ORDEN,
        CASE mnu_ambito WHEN 1 THEN 'WEB' WHEN 2 THEN 'APP' ELSE 'AMBOS' END AS AMBITO
FROM    ARBOL
ORDER BY RUTA
GO
