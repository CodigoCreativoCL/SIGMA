/* ============================================================================
   SIGMA — Bloque 76
   CENTRO DE ETIQUETAS
   ----------------------------------------------------------------------------

   EL CATALOGO DE LO IMPRIMIBLE ES UNA TABLA, NO UNA LISTA EN C#

     Hasta ahora las etiquetas se pedian desde la ficha de la bodega, que
     sabia de memoria sus tres origenes. Con mas modulos imprimibles eso se
     vuelve una lista repetida en cada pantalla que quiera imprimir.

     Etiqueta_Origen es el catalogo. La pantalla que centraliza lee la tabla
     y dibuja lo que haya: agregar un origen nuevo es un INSERT aca y una
     rama en SEL_ETIQUETA, y no se toca ninguna vista.

     Es la misma idea que ya gobierna el menu y los permisos: SIGMA decide
     por datos, no por codigo repartido.

   CADA ORIGEN LLEVA SU PERMISO

     No basta con poder IMPRIMIR ETIQUETAS. Una etiqueta de repuesto lleva
     su nombre y su fabricante; una de bodega, donde esta. El centro muestra
     solo los origenes cuyo permiso tiene quien mira, y no una reja que
     aparece recien al apretar.

   LOS ACTIVOS QUEDAN REGISTRADOS PERO APAGADOS

     La tabla Activo existe y tiene datos, asi que tecnicamente se podrian
     imprimir sus etiquetas hoy. No se hace: no hay modulo de activos: ni
     listado, ni ficha, ni menu. Una etiqueta que se escanea y no lleva a
     ninguna parte es peor que no tenerla, porque se pega en una maquina y
     ahi se queda.

     Se deja la fila con eto_habilitado = 0 y el motivo escrito, para que el
     centro lo muestre como lo que es -algo que viene, no algo roto- y para
     que el dia que exista el modulo sea un UPDATE de una fila.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. EL CATALOGO
   ======================================================================== */
IF OBJECT_ID('dbo.Etiqueta_Origen') IS NULL
BEGIN
    CREATE TABLE [dbo].[Etiqueta_Origen] (
        [eto_id]           INT IDENTITY(1,1) NOT NULL,
        [eto_codigo]       NVARCHAR(40)   NOT NULL,
        [eto_nombre]       NVARCHAR(200)  NOT NULL,
        [eto_descripcion]  NVARCHAR(500)  NULL,
        [eto_icono]        NVARCHAR(80)   NULL,
        [eto_permiso]      INT            NOT NULL,
        [eto_orden]        INT            NOT NULL DEFAULT 0,
        /* Si el origen se puede acotar a una bodega. Un repuesto no: existe
           en el catalogo del cliente, no dentro de una bodega. */
        [eto_por_bodega]   BIT            NOT NULL DEFAULT 0,
        [eto_habilitado]   BIT            NOT NULL DEFAULT 1,
        /* Por que esta apagado, para poder decirlo en pantalla en vez de
           mostrar una tarjeta gris sin explicacion. */
        [eto_motivo_baja]  NVARCHAR(300)  NULL,
        CONSTRAINT [PK_Etiqueta_Origen] PRIMARY KEY CLUSTERED ([eto_id]),
        CONSTRAINT [UX_Etiqueta_Origen_Codigo] UNIQUE ([eto_codigo]),
        CONSTRAINT [FK_Etiqueta_Origen_Permiso]
            FOREIGN KEY ([eto_permiso]) REFERENCES [dbo].[Permiso]([prm_id])
    )

    PRINT '--- Tabla Etiqueta_Origen creada'
END
ELSE PRINT '--- Tabla Etiqueta_Origen ya existia'
GO


/* ========================================================================
   2. LOS ORIGENES
   ======================================================================== */
DECLARE @VER_BOD INT, @VER_REP INT, @VER_ACT INT

SELECT @VER_BOD = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER BODEGAS'
SELECT @VER_REP = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER REPUESTOS'
SELECT @VER_ACT = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER ACTIVOS'

MERGE [dbo].[Etiqueta_Origen] AS d
USING (VALUES
    ('BODEGA', 'Bodegas', 'Una etiqueta por bodega, para la puerta o el acceso.',
     'mdi mdi-warehouse', @VER_BOD, 1, 0, 1, NULL),

    ('UBICACION', 'Ubicaciones', 'Una por estante. No cambian aunque cambie lo que guardan, así que se imprimen una sola vez.',
     'mdi mdi-view-grid-outline', @VER_BOD, 2, 1, 1, NULL),

    ('UBICACION_REPUESTO', 'Ubicación con su repuesto', 'Rotula el casillero con lo que hay hoy. Se reimprime cuando se reorganiza la bodega.',
     'mdi mdi-package-variant-closed', @VER_BOD, 3, 1, 1, NULL),

    ('REPUESTO', 'Repuestos', 'Una por repuesto del catálogo, con su código y su fabricante.',
     'mdi mdi-cog-outline', @VER_REP, 4, 0, 1, NULL),

    ('ACTIVO', 'Activos', 'Una por equipo, para pegar en la máquina.',
     'mdi mdi-engine-outline', @VER_ACT, 5, 0, 0,
     'El módulo de activos todavía no está construido: la etiqueta se podría imprimir, pero al escanearla no habría ninguna pantalla que mostrar.')
) AS o (cod, nom, des, ico, per, ord, bod, hab, mot)
    ON d.eto_codigo = o.cod
WHEN MATCHED THEN UPDATE SET
    d.eto_nombre = o.nom, d.eto_descripcion = o.des, d.eto_icono = o.ico,
    d.eto_permiso = o.per, d.eto_orden = o.ord, d.eto_por_bodega = o.bod,
    d.eto_habilitado = o.hab, d.eto_motivo_baja = o.mot
WHEN NOT MATCHED THEN
    INSERT (eto_codigo, eto_nombre, eto_descripcion, eto_icono, eto_permiso,
            eto_orden, eto_por_bodega, eto_habilitado, eto_motivo_baja)
    VALUES (o.cod, o.nom, o.des, o.ico, o.per, o.ord, o.bod, o.hab, o.mot);

PRINT '--- Origenes al dia: ' + LTRIM(STR(@@ROWCOUNT))
GO


IF OBJECT_ID('dbo.SEL_ETIQUETA_ORIGEN') IS NOT NULL DROP PROCEDURE [dbo].[SEL_ETIQUETA_ORIGEN]
GO

CREATE PROCEDURE [dbo].[SEL_ETIQUETA_ORIGEN]
AS
SET NOCOUNT ON

    /* Se devuelven TODOS, apagados incluidos. Quien filtra por permiso es la
       pantalla, que es la que conoce al usuario; y los apagados se muestran
       con su motivo en vez de esconderse, para que se vea que el sistema
       sabe que existen. */
    SELECT  o.eto_id, o.eto_codigo, o.eto_nombre, o.eto_descripcion,
            o.eto_icono, o.eto_orden, o.eto_por_bodega, o.eto_habilitado,
            ISNULL(o.eto_motivo_baja, '') AS eto_motivo_baja,
            p.prm_codigo AS PERMISO
    FROM    [dbo].[Etiqueta_Origen] o
    JOIN    [dbo].[Permiso] p ON p.prm_id = o.eto_permiso
    ORDER BY o.eto_orden
GO


/* ========================================================================
   3. EL MENU

      Etiquetas va ANTES que Escanear: primero se imprime, despues se lee.
      Escanear pasa del 5 al 6.
   ======================================================================== */
DECLARE @PADRE INT = 2112, @PRM INT, @MNU INT

SELECT @PRM = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'IMPRIMIR ETIQUETAS'

UPDATE [dbo].[Menus] SET mnu_orden = 6
 WHERE mnu_link = '~/View/Comun/Impresion/Escanear.aspx'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Comun/Impresion/CentroEtiquetas.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Etiquetas', 'Imprimir etiquetas con QR de todo lo identificable', 3, @PADRE, 5,
            '~/View/Comun/Impresion/CentroEtiquetas.aspx', 1, 'mdi mdi-tag-multiple-outline', @PRM, 1)

SELECT @MNU = mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Comun/Impresion/CentroEtiquetas.aspx'

/* Menu_Funcion siempre que nace un menu: sin la fila, Token.PuedeFuncion
   devuelve false para todos -Root incluido- y el boton no aparece, sin
   error que lo explique. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Imprimir etiquetas')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Imprimir etiquetas', @MNU, @PRM)

PRINT '--- Menu Etiquetas listo'
GO


/* ========================================================================
   4. SEL_ETIQUETA aprende a imprimir activos

      Se agrega la rama aunque el origen este apagado: el dia que exista el
      modulo, encenderlo es un UPDATE y no volver a tocar el SP.
   ======================================================================== */
DECLARE @SQL NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.SEL_ETIQUETA'))

IF @SQL IS NOT NULL AND @SQL NOT LIKE '%ACT-%'
BEGIN
    SET @SQL = REPLACE(@SQL,
'ELSE
BEGIN
    RAISERROR(''1.- ORIGEN DE ETIQUETA DESCONOCIDO.'', 16, 1)',
'/* ---- Un equipo ---- */
ELSE IF (@ORIGEN = ''ACTIVO'')
    SELECT  ''ACT-'' + LTRIM(STR(a.act_id))  AS TOKEN,
            a.act_id                          AS ID,
            a.act_codigo                      AS CODIGO,
            a.act_nombre                      AS TITULO,
            LTRIM(RTRIM(ISNULL(a.act_fabricante, '''') + '' '' + ISNULL(a.act_numero_serie, ''''))) AS SUBTITULO,
            ISNULL(t.atp_nombre, '''')          AS DETALLE,
            ISNULL(ci.cin_nombre, ''Activo'')   AS PIE
    FROM    [dbo].[Activo] a
    LEFT JOIN [dbo].[Activo_Tipo] t ON t.atp_id = a.act_activo_tipo
    LEFT JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = a.act_cliente_instalacion
    WHERE   a.act_cliente = @CLIENTE
      AND   a.act_habilitado = 1
      AND   a.act_fusionado_en IS NULL
      AND   (@HAY = 0 OR a.act_id IN (SELECT ID FROM @LISTA))
    ORDER BY a.act_codigo

ELSE
BEGIN
    RAISERROR(''1.- ORIGEN DE ETIQUETA DESCONOCIDO.'', 16, 1)')

    SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
    EXEC sp_executesql @SQL
    PRINT '--- SEL_ETIQUETA aprende el origen ACTIVO'
END
ELSE PRINT '--- SEL_ETIQUETA ya conocia ACTIVO'
GO


/* ========================================================================
   5. VERIFICACION
   ======================================================================== */
PRINT '--- Catalogo de origenes ---'
EXEC [dbo].[SEL_ETIQUETA_ORIGEN]
GO
