/* ============================================================================
   SIGMA — Bloque 74
   ETIQUETAS IMPRIMIBLES Y ESCANEO
   ----------------------------------------------------------------------------

   UN SOLO SP PARA TODAS LAS ETIQUETAS

     SEL_ETIQUETA recibe @ORIGEN y devuelve SIEMPRE las mismas columnas:
     TOKEN, CODIGO, TITULO, SUBTITULO, DETALLE, PIE. La pantalla que imprime
     no sabe -ni tiene por que saber- si esta imprimiendo una bodega, un
     estante o un repuesto: recibe filas normalizadas y las maqueta.

     Agregar un origen nuevo -un activo, una orden de trabajo- es agregar una
     rama aca y una entrada en el diccionario del controlador. No se toca la
     pantalla ni el CSS de impresion.

   EL TOKEN VA EN CLARO Y NO CIFRADO

     El proyecto usa querystrings cifrados, y esta es una excepcion
     deliberada. Dos razones:

       Una etiqueta pegada en un estante dura anos. El cifrado depende de una
       clave; el dia que esa clave cambie, todas las etiquetas impresas
       quedan apuntando a algo que ya no se puede descifrar. Habria que
       reimprimir la bodega entera.

       El id no es un secreto. Lo que protege el dato es la pagina: exige
       permiso y filtra por cliente. Un token de otra empresa escaneado aca
       no devuelve nada, porque SEL_UBICACION_DESGLOSE pide @CLIENTE. Cifrar
       el id solo lo haria ilegible, no seguro.

     El token es corto a proposito -UBI-123- porque tambien se teclea a mano
     cuando la etiqueta esta rayada y la pistola no la lee.

   LA PISTOLA ES UN TECLADO

     Un lector inalambrico no "se conecta" a nada: escribe lo que leyo donde
     este el cursor y manda Enter. Por eso la pantalla de escaneo es un campo
     de texto enfocado que acepta las dos formas: la URL completa -que es lo
     que lee un telefono desde el QR- o el token pelado.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. EL PERMISO
   ======================================================================== */
DECLARE @AMBITO INT, @PRM INT

/* Se copia el ambito de VER BODEGAS en vez de escribir un numero: si
   manana cambia la convencion de ambitos, este permiso la sigue. */
SELECT @AMBITO = prm_permiso_ambito FROM [dbo].[Permiso] WHERE prm_codigo = 'VER BODEGAS'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'IMPRIMIR ETIQUETAS')
BEGIN
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    VALUES ('IMPRIMIR ETIQUETAS', 'Imprimir etiquetas', 'INVENTARIO', @AMBITO,
            'Generar e imprimir etiquetas con código QR de bodegas, ubicaciones y repuestos.',
            1, GETDATE(), 1, 1)

    PRINT '--- Permiso IMPRIMIR ETIQUETAS creado'
END
ELSE PRINT '--- Permiso IMPRIMIR ETIQUETAS ya existia'

SELECT @PRM = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'IMPRIMIR ETIQUETAS'

/* Quien imprime: quien administra la bodega y quien la opera.
   Soporte NO entra: su alcance es mirar, y una etiqueta es algo que se
   produce y se pega en el mundo real. */
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT p.per_id, @PRM, 1, GETDATE()
FROM   [dbo].[Perfiles] p
WHERE  p.per_id IN (1, 4, 5, 10, 12)
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso]
                    WHERE ppe_perfil = p.per_id AND ppe_permiso = @PRM)

PRINT '--- Perfiles con permiso de impresion: ' + LTRIM(STR(@@ROWCOUNT)) + ' agregado(s)'
GO


/* ========================================================================
   2. LOS MENUS

      Etiquetas es invisible: se llega desde la ficha de la bodega o desde
      el listado de repuestos, nunca desde el menu -imprimir es el final de
      una tarea, no el comienzo de una-.

      Escanear SI es visible, y va al final del modulo: es lo ultimo en la
      cadena de dependencias. Primero existe la bodega, luego el repuesto,
      luego la existencia, luego el movimiento, y solo entonces tiene
      sentido pararse frente a un estante con la pistola.
   ======================================================================== */
DECLARE @PADRE INT = 2112, @PRM INT, @VER INT, @MNU_ETI INT, @MNU_ESC INT

SELECT @PRM = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'IMPRIMIR ETIQUETAS'
SELECT @VER = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER EXISTENCIAS'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Comun/Impresion/Etiquetas.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Etiquetas (impresión)', 'Generación de etiquetas con QR', 3, @PADRE, 99,
            '~/View/Comun/Impresion/Etiquetas.aspx', 0, NULL, @PRM, 1)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Comun/Impresion/Escanear.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Escanear', 'Leer una etiqueta y ver qué hay ahí', 3, @PADRE, 5,
            '~/View/Comun/Impresion/Escanear.aspx', 1, 'mdi mdi-qrcode-scan', @VER, 1)

SELECT @MNU_ETI = mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Comun/Impresion/Etiquetas.aspx'
SELECT @MNU_ESC = mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Comun/Impresion/Escanear.aspx'

/* Menu_Funcion SIEMPRE que nace un menu. Sin la fila, Token.PuedeFuncion
   devuelve false para todo el mundo -Root incluido- y el boton simplemente
   no aparece, sin error que lo explique. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @MNU_ETI AND mfu_nombre = 'Imprimir etiquetas')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Imprimir etiquetas', @MNU_ETI, @PRM)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @MNU_ESC AND mfu_nombre = 'Ver desglose')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Ver desglose', @MNU_ESC, @VER)

/* Y el boton de imprimir en la ficha de la bodega y en el listado de
   repuestos, que es desde donde se llega. */
DECLARE @MNU_BOD INT, @MNU_REP INT

SELECT @MNU_BOD = mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Inventario/Bodegas/Bodega.aspx'
SELECT @MNU_REP = mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Inventario/Repuestos/Repuestos.aspx'

IF @MNU_BOD IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                                         WHERE mfu_menu = @MNU_BOD AND mfu_nombre = 'Imprimir etiquetas')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Imprimir etiquetas', @MNU_BOD, @PRM)

IF @MNU_REP IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                                         WHERE mfu_menu = @MNU_REP AND mfu_nombre = 'Imprimir etiquetas')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Imprimir etiquetas', @MNU_REP, @PRM)

PRINT '--- Menus y Menu_Funcion listos'
GO


/* ========================================================================
   3. SEL_ETIQUETA

      @ORIGEN dice QUE se imprime. @IDS es una lista separada por comas:
      imprimir de a una etiqueta obliga a entrar y salir de la pantalla por
      cada estante, y una bodega tiene decenas.

      @IDS vacio significa "todas las de esa bodega", que es el caso normal:
      se rotula la estanteria completa de una vez.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_ETIQUETA') IS NOT NULL DROP PROCEDURE [dbo].[SEL_ETIQUETA]
GO

CREATE PROCEDURE [dbo].[SEL_ETIQUETA]
    @CLIENTE INT,
    @ORIGEN  NVARCHAR(40),
    @IDS     NVARCHAR(MAX) = NULL,
    @BODEGA  INT = NULL
AS
SET NOCOUNT ON

DECLARE @LISTA TABLE (ID INT PRIMARY KEY)

IF (@IDS IS NOT NULL AND LEN(LTRIM(@IDS)) > 0)
    INSERT INTO @LISTA (ID)
    SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(value)) AS INT)
    FROM   STRING_SPLIT(@IDS, ',')
    WHERE  TRY_CAST(LTRIM(RTRIM(value)) AS INT) IS NOT NULL

DECLARE @HAY BIT = CASE WHEN EXISTS (SELECT 1 FROM @LISTA) THEN 1 ELSE 0 END


/* ---- Una bodega ---- */
IF (@ORIGEN = 'BODEGA')
    SELECT  'BOD-' + LTRIM(STR(b.bod_id))    AS TOKEN,
            b.bod_id                          AS ID,
            b.bod_codigo                      AS CODIGO,
            b.bod_nombre                      AS TITULO,
            ISNULL(ci.cin_nombre, '')         AS SUBTITULO,
            ''                                AS DETALLE,
            'Bodega'                          AS PIE
    FROM    [dbo].[Bodega] b
    LEFT JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = b.bod_cliente_instalacion
    WHERE   b.bod_cliente = @CLIENTE
      AND   b.bod_habilitado = 1
      AND   (@HAY = 0 OR b.bod_id IN (SELECT ID FROM @LISTA))
    ORDER BY b.bod_codigo


/* ---- Un estante ----
   La etiqueta del estante NO nombra un repuesto: el estante sigue siendo el
   mismo cuando lo que guarda cambia, y una etiqueta que menciona el
   repuesto habria que reimprimirla cada vez que se reorganiza la bodega. */
ELSE IF (@ORIGEN = 'UBICACION')
    SELECT  'UBI-' + LTRIM(STR(u.bub_id))    AS TOKEN,
            u.bub_id                          AS ID,
            u.bub_codigo                      AS CODIGO,
            u.bub_nombre                      AS TITULO,
            b.bod_codigo + ' · ' + b.bod_nombre AS SUBTITULO,
            ''                                AS DETALLE,
            ISNULL(ci.cin_nombre, 'Ubicación') AS PIE
    FROM    [dbo].[Bodega_Ubicacion] u
    JOIN    [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
    LEFT JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = b.bod_cliente_instalacion
    WHERE   b.bod_cliente = @CLIENTE
      AND   u.bub_habilitado = 1
      AND   (@BODEGA IS NULL OR u.bub_bodega = @BODEGA)
      AND   (@HAY = 0 OR u.bub_id IN (SELECT ID FROM @LISTA))
    ORDER BY u.bub_codigo


/* ---- El estante CON lo que tiene hoy ----
   Esta es la que pidio el bodeguero: codigo de ubicacion y nombre del
   repuesto. Sirve para rotular la cara del estante donde ya hay algo
   asignado, y se reimprime cuando cambia. Un estante con tres repuestos
   distintos da tres etiquetas: cada una rotula su casillero. */
ELSE IF (@ORIGEN = 'UBICACION_REPUESTO')
    SELECT  'UBI-' + LTRIM(STR(u.bub_id))    AS TOKEN,
            u.bub_id                          AS ID,
            u.bub_codigo                      AS CODIGO,
            r.rep_nombre                      AS TITULO,
            r.rep_codigo                      AS SUBTITULO,
            LTRIM(STR(CAST(s.isa_cantidad AS DECIMAL(18,2)), 18, 2)) + ' ' + ume.ume_simbolo AS DETALLE,
            b.bod_codigo                      AS PIE
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Bodega_Ubicacion] u ON u.bub_id = s.isa_bodega_ubicacion
    JOIN    [dbo].[Bodega] b           ON b.bod_id = s.isa_bodega
    JOIN    [dbo].[Repuesto] r         ON r.rep_id = s.isa_repuesto
    JOIN    [dbo].[Unidad_Medida] ume  ON ume.ume_id = r.rep_unidad_medida
    WHERE   s.isa_cliente = @CLIENTE
      AND   s.isa_cantidad <> 0
      AND   (@BODEGA IS NULL OR s.isa_bodega = @BODEGA)
      AND   (@HAY = 0 OR u.bub_id IN (SELECT ID FROM @LISTA))
    ORDER BY u.bub_codigo, r.rep_codigo


/* ---- Un repuesto ---- */
ELSE IF (@ORIGEN = 'REPUESTO')
    SELECT  'REP-' + LTRIM(STR(r.rep_id))    AS TOKEN,
            r.rep_id                          AS ID,
            r.rep_codigo                      AS CODIGO,
            r.rep_nombre                      AS TITULO,
            LTRIM(RTRIM(ISNULL(r.rep_fabricante, '') + ' ' + ISNULL(r.rep_modelo, ''))) AS SUBTITULO,
            ume.ume_nombre                    AS DETALLE,
            'Repuesto'                        AS PIE
    FROM    [dbo].[Repuesto] r
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    WHERE   r.rep_cliente = @CLIENTE
      AND   r.rep_habilitado = 1
      AND   r.rep_fusionado_en IS NULL
      AND   (@HAY = 0 OR r.rep_id IN (SELECT ID FROM @LISTA))
    ORDER BY r.rep_codigo

ELSE
BEGIN
    RAISERROR('1.- ORIGEN DE ETIQUETA DESCONOCIDO.', 16, 1)
    RETURN -1
END

RETURN 0
GO


/* ========================================================================
   4. VERIFICACION
   ======================================================================== */
PRINT '--- Etiquetas de ubicacion ---'
EXEC [dbo].[SEL_ETIQUETA] @CLIENTE = 1, @ORIGEN = 'UBICACION'

PRINT '--- Etiquetas de ubicacion con su repuesto ---'
EXEC [dbo].[SEL_ETIQUETA] @CLIENTE = 1, @ORIGEN = 'UBICACION_REPUESTO'
GO
