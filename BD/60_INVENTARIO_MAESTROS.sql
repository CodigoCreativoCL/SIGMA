/* ============================================================================
   SIGMA — Bloque 60
   EL MODULO DEL BODEGUERO (1 de 2): FUNDACIONES Y MAESTROS
   ----------------------------------------------------------------------------

   Sprint 3. Siete historias, todas del bodeguero salvo HU-056 que la usa
   cualquiera de mantenimiento:

     HU-050  maestro de repuestos                    Web
     HU-052  bodegas y ubicaciones                   Web
     HU-053  stock minimo y maximo                   Web
     HU-054  ingreso de repuestos a bodega           Web y App
     HU-055  entrega contra una orden de trabajo     Web y App
     HU-056  consultar la existencia                 Web y App
     HU-057  ajuste de inventario                    Web y App

   LO QUE HABIA Y LO QUE NO

     Las 16 tablas del modulo estan creadas desde las fundaciones, con sus
     indices unicos y sus FK. Lo que no habia era **un solo procedimiento**:
     cero SPs de inventario. El modelo estaba listo y nadie lo habia tocado.

   ESTE BLOQUE Y EL 61

     60 (este): unidades, la columna que faltaba, permisos, menus y los
                maestros -bodegas, ubicaciones, repuestos, umbrales-.
     61:        el movimiento de inventario, que es donde vive la dificultad
                de verdad: mantener Inventario_Saldo sin que se despegue de
                Inventario_Movimiento.

   DOS COSAS QUE FALTABAN EN EL MODELO

     1. Unidad_Medida esta VACIA, y rep_unidad_medida es NOT NULL. Sin
        unidades no se puede crear ni un repuesto. Se carga un minimo. La
        mantencion es HU-040 (Sprint 2, del Administrador del Cliente), que
        todavia no se construye: esto es carga inicial, no su mantenedor.

     2. El criterio 2 de HU-054 dice "dado un repuesto que controla lote".
        No habia con que saberlo: existe Repuesto_Lote, pero ninguna columna
        que diga si ESE repuesto lo exige. Se agrega rep_controla_lote.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. UNIDADES DE MEDIDA — CARGA INICIAL

      Solo lo que un inventario necesita para arrancar: contar, pesar,
      medir y envasar. No es el catalogo completo de HU-040.

      ume_factor y ume_offset convierten a la unidad base de su magnitud.
      Para la unidad base el factor es 1 y el offset 0.

      UNA SOLA BASE POR MAGNITUD
        El modelo lo obliga con un indice unico filtrado:
        UX_UME_MAGNITUD_BASE sobre ume_magnitud WHERE ume_unidad_base IS
        NULL. O sea que ume_unidad_base NULL no significa "no aplica": es
        la marca de "esta ES la unidad base", y solo puede haber una.

        Por eso se cargan en dos pasadas: primero las cuatro bases, despues
        las derivadas apuntando a la suya. Cargarlas todas con NULL revienta
        el indice —y asi reviento el primer intento—.

      "CAJA" NO ENTRA
        No es una unidad de una magnitud: una caja de pernos no tiene un
        factor fijo contra la unidad. Eso es empaque, y el empaque es del
        ingreso, no del repuesto.
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida])
BEGIN
    -- 1) Las bases: una por magnitud.
    INSERT INTO [dbo].[Unidad_Medida]
        (ume_magnitud, ume_unidad_base, ume_codigo, ume_nombre, ume_simbolo,
         ume_factor, ume_offset, ume_usuario_creacion, ume_fecha_creacion, ume_habilitado)
    VALUES
        (10, NULL, N'UNIDAD',    N'Unidad',    N'un', 1, 0, 1, GETDATE(), 1),
        (11, NULL, N'METRO',     N'Metro',     N'm',  1, 0, 1, GETDATE(), 1),
        (12, NULL, N'KILOGRAMO', N'Kilogramo', N'kg', 1, 0, 1, GETDATE(), 1),
        (13, NULL, N'LITRO',     N'Litro',     N'L',  1, 0, 1, GETDATE(), 1)

    -- 2) Las derivadas, contra la base de su magnitud.
    INSERT INTO [dbo].[Unidad_Medida]
        (ume_magnitud, ume_unidad_base, ume_codigo, ume_nombre, ume_simbolo,
         ume_factor, ume_offset, ume_usuario_creacion, ume_fecha_creacion, ume_habilitado)
    SELECT 10, (SELECT ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'UNIDAD'),
           N'PAR', N'Par', N'par', 2, 0, 1, GETDATE(), 1
    UNION ALL
    SELECT 11, (SELECT ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'METRO'),
           N'CENTIMETRO', N'Centímetro', N'cm', 0.01, 0, 1, GETDATE(), 1
    UNION ALL
    SELECT 12, (SELECT ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'KILOGRAMO'),
           N'GRAMO', N'Gramo', N'g', 0.001, 0, 1, GETDATE(), 1
    UNION ALL
    SELECT 13, (SELECT ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'LITRO'),
           N'MILILITRO', N'Mililitro', N'mL', 0.001, 0, 1, GETDATE(), 1

    PRINT '--- 8 unidades de medida cargadas: 4 bases y 4 derivadas'
END
ELSE
    PRINT '--- Unidad_Medida ya tenia filas'
GO


/* ========================================================================
   2. Repuesto.rep_controla_lote

      DF 0: la mayoria de los repuestos no lleva lote -un rodamiento es un
      rodamiento-. Lo llevan los que vencen o los que hay que poder
      rastrear: aceites, filtros, sellos, adhesivos.

      Cuando esta en 1, el ingreso EXIGE el lote y el consumo descuenta del
      lote indicado (bloque 61).
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.Repuesto') AND name = 'rep_controla_lote')
BEGIN
    ALTER TABLE [dbo].[Repuesto]
        ADD rep_controla_lote BIT NOT NULL CONSTRAINT DF_REP_CONTROLA_LOTE DEFAULT (0)
    PRINT '--- Repuesto.rep_controla_lote creada'
END
ELSE
    PRINT '--- Repuesto.rep_controla_lote ya existia'
GO


/* ========================================================================
   3. PERMISOS DEL MODULO

      El AMBITO importa (bloque 58): los de la app son los cuatro que el
      bodeguero usa caminando por el pasillo. Los maestros -bodegas,
      repuestos, umbrales- son de escritorio y quedan WEB.

      GESTIONAR STOCK ya existia (id 15) y lo tiene el bodeguero: se
      reutiliza para los umbrales de HU-053 en vez de crear uno igual con
      otro nombre (CONVENCIONES.md §6: buscar antes de crear).
   ======================================================================== */
/* COLLATE DATABASE_DEFAULT en toda columna de texto: una variable de tabla
   nace con la collation de tempdb (SQL_Latin1_General_CP1_CI_AS), no con la
   de la base (Modern_Spanish_CI_AS), y compararlas revienta. */
DECLARE @P TABLE (codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  modulo NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  ambito INT)

INSERT INTO @P VALUES
    -- AMBOS: la app necesita la lista de bodegas para poder registrar un
    -- ingreso o una entrega. Crearlas y editarlas si es de escritorio.
    (N'VER BODEGAS',              N'Ver bodegas y ubicaciones',        N'INVENTARIO', 3),
    (N'CREAR EDITAR BODEGAS',     N'Crear y editar bodegas',           N'INVENTARIO', 1),
    (N'VER REPUESTOS',            N'Ver el maestro de repuestos',      N'REPUESTOS',  3),
    (N'CREAR EDITAR REPUESTOS',   N'Crear y editar repuestos',         N'REPUESTOS',  1),
    (N'VER EXISTENCIAS',          N'Consultar la existencia',          N'INVENTARIO', 3),
    (N'REGISTRAR INGRESO REPUESTO', N'Registrar ingreso a bodega',     N'INVENTARIO', 3),
    (N'ENTREGAR REPUESTO',        N'Entregar repuestos y devolverlos', N'INVENTARIO', 3),
    (N'AJUSTAR INVENTARIO',       N'Registrar ajustes de inventario',  N'INVENTARIO', 3)

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
SELECT  p.codigo, p.nombre, p.modulo, p.ambito, p.nombre, 1, GETDATE(), 1, 0
FROM    @P p
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] x WHERE x.prm_codigo = p.codigo)

/* PRINT no acepta subconsultas: solo expresiones escalares. */
DECLARE @N_PERM INT
SELECT @N_PERM = COUNT(*) FROM [dbo].[Permiso]
 WHERE prm_codigo IN (SELECT codigo FROM @P)
PRINT '--- Permisos del modulo: ' + LTRIM(STR(@N_PERM))
GO


/* ========================================================================
   4. MENUS

      Inventario nace como nodo de nivel 2, al lado de Sistema, Comercial y
      Cliente: no es configuracion del cliente, es operacion.

      Las fichas van con orden 99 y sin aparecer en el arbol -mnu_visible 0-
      pero CON su fila: sin fila en Menus la pantalla no se abre
      (Token.ExigirPagina niega por omision). Es el patron del resto del
      sitio.
   ======================================================================== */
DECLARE @RAIZ INT, @PERM INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = 'Inventario' AND mnu_nivel = 2)
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                               mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Inventario', 'Bodegas, repuestos y existencias', 2, 1, 4, '#', 1,
            'mdi mdi-warehouse', NULL, 1)

SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = 'Inventario' AND mnu_nivel = 2

DECLARE @M TABLE (nombre  NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  link    NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  orden   INT,
                  visible BIT,
                  icono   NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)

INSERT INTO @M VALUES
    (N'Repuestos',    N'~/View/Inventario/Repuestos/Repuestos.aspx',      1, 1, N'mdi mdi-package-variant-closed', N'VER REPUESTOS'),
    (N'Bodegas',      N'~/View/Inventario/Bodegas/Bodegas.aspx',          2, 1, N'mdi mdi-warehouse',              N'VER BODEGAS'),
    (N'Existencias',  N'~/View/Inventario/Existencias/Existencias.aspx',  3, 1, N'mdi mdi-clipboard-list-outline', N'VER EXISTENCIAS'),
    (N'Movimientos',  N'~/View/Inventario/Movimientos/Movimientos.aspx',  4, 1, N'mdi mdi-swap-vertical',          N'VER EXISTENCIAS'),
    (N'Repuesto (detalle)',   N'~/View/Inventario/Repuestos/Repuesto.aspx',     99, 0, NULL, N'VER REPUESTOS'),
    (N'Bodega (detalle)',     N'~/View/Inventario/Bodegas/Bodega.aspx',         99, 0, NULL, N'VER BODEGAS'),
    (N'Existencia (detalle)', N'~/View/Inventario/Existencias/Existencia.aspx', 99, 0, NULL, N'VER EXISTENCIAS'),
    (N'Movimiento (detalle)', N'~/View/Inventario/Movimientos/Movimiento.aspx', 99, 0, NULL, N'VER EXISTENCIAS')

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT  m.nombre, m.nombre, 3, @RAIZ, m.orden, m.link, m.visible, m.icono,
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = m.permiso), 1
FROM    @M m
/* Menus viene de FacilityGes y sus columnas de texto son
   Modern_Spanish_CI_AS, mientras que la base es SQL_Latin1_General_CP1_CI_AS.
   Comparar mnu_link contra cualquier texto nuestro conflictua: hay que
   coercionar la columna heredada, no la nuestra. */
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x
                     WHERE x.mnu_link COLLATE DATABASE_DEFAULT = m.link)

DECLARE @N_MENU INT
SELECT @N_MENU = COUNT(*) FROM [dbo].[Menus] WHERE mnu_padre = @RAIZ
PRINT '--- Menus del modulo: ' + LTRIM(STR(@N_MENU))
GO


/* ========================================================================
   5. QUIEN PUEDE QUE

      El bodeguero es el duenno del modulo. El jefe y el planificador ven y
      pueden mover -en una planta chica el bodeguero no esta a las 3 AM-.
      El supervisor y el tecnico solo consultan: el consumo real lo
      registran contra su orden de trabajo, no entrando a la bodega.

      Root no se toca: SEL_USUARIO_PERMISOS le devuelve todo por regla.
   ======================================================================== */
DECLARE @PP TABLE (perfil INT, codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT)

INSERT INTO @PP VALUES
    -- Bodeguero (4): todo
    (4, N'VER BODEGAS'), (4, N'CREAR EDITAR BODEGAS'),
    (4, N'VER REPUESTOS'), (4, N'CREAR EDITAR REPUESTOS'),
    (4, N'VER EXISTENCIAS'), (4, N'REGISTRAR INGRESO REPUESTO'),
    (4, N'ENTREGAR REPUESTO'), (4, N'AJUSTAR INVENTARIO'),
    -- Jefe de Mantenimiento (5)
    (5, N'VER BODEGAS'), (5, N'VER REPUESTOS'), (5, N'CREAR EDITAR REPUESTOS'),
    (5, N'VER EXISTENCIAS'), (5, N'REGISTRAR INGRESO REPUESTO'),
    (5, N'ENTREGAR REPUESTO'), (5, N'AJUSTAR INVENTARIO'),
    -- Planificador (11)
    (11, N'VER BODEGAS'), (11, N'VER REPUESTOS'), (11, N'CREAR EDITAR REPUESTOS'),
    (11, N'VER EXISTENCIAS'), (11, N'ENTREGAR REPUESTO'),
    -- Supervisor (12) y Tecnico (13): consulta
    (12, N'VER REPUESTOS'), (12, N'VER EXISTENCIAS'),
    (13, N'VER REPUESTOS'), (13, N'VER EXISTENCIAS'),
    -- Administrador del Cliente (10): ve, no opera
    (10, N'VER BODEGAS'), (10, N'VER REPUESTOS'), (10, N'VER EXISTENCIAS')

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  pp.perfil, p.prm_id, 1, GETDATE()
FROM    @PP pp
JOIN    [dbo].[Permiso] p ON p.prm_codigo = pp.codigo
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x
                     WHERE x.ppe_perfil = pp.perfil AND x.ppe_permiso = p.prm_id)
GO


/* ========================================================================
   6. BODEGA  (HU-052)
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_BODEGA') IS NOT NULL DROP PROCEDURE [dbo].[SEL_BODEGA]
GO
CREATE PROCEDURE [dbo].[SEL_BODEGA]
    @ID          INT = NULL,
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @FILTRO      NVARCHAR(200) = NULL,
    @HABILITADO  BIT = NULL
AS
SET NOCOUNT ON

    SELECT  b.bod_id, b.bod_cliente, b.bod_cliente_instalacion,
            b.bod_codigo, b.bod_nombre, b.bod_descripcion, b.bod_habilitado,
            cin.cin_nombre AS PLANTA_NOMBRE,
            (SELECT COUNT(*) FROM [dbo].[Bodega_Ubicacion] u
              WHERE u.bub_bodega = b.bod_id AND u.bub_habilitado = 1) AS UBICACIONES,
            (SELECT COUNT(*) FROM [dbo].[Inventario_Saldo] s
              WHERE s.isa_bodega = b.bod_id AND s.isa_cantidad > 0) AS REPUESTOS_CON_SALDO
    FROM    [dbo].[Bodega] b
    JOIN    [dbo].[Cliente_Instalacion] cin ON cin.cin_id = b.bod_cliente_instalacion
    WHERE   b.bod_cliente = @CLIENTE
      AND   (@ID IS NULL OR b.bod_id = @ID)
      AND   (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
      AND   (@HABILITADO IS NULL OR b.bod_habilitado = @HABILITADO)
      -- El filtro va PARAMETRIZADO. En SEL_CLIENTE_USUARIO se concatenaba y
      -- era inyeccion SQL desde el buscador (bloque 49).
      AND   (@FILTRO IS NULL OR b.bod_codigo LIKE '%' + @FILTRO + '%'
                             OR b.bod_nombre LIKE '%' + @FILTRO + '%')
    ORDER BY cin.cin_nombre, b.bod_codigo
GO


IF OBJECT_ID('dbo.INS_BODEGA') IS NOT NULL DROP PROCEDURE [dbo].[INS_BODEGA]
GO
CREATE PROCEDURE [dbo].[INS_BODEGA]
    @ID          INT OUTPUT,
    @CLIENTE     INT,
    @INSTALACION INT,
    @CODIGO      NVARCHAR(100),
    @NOMBRE      NVARCHAR(400),
    @DESCRIPCION NVARCHAR(1000) = NULL,
    @USUARIO     INT
AS
SET NOCOUNT ON

    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0)
    BEGIN
        RAISERROR('1.- INDIQUE EL CODIGO DE LA BODEGA.', 16, 1)
        RETURN -1
    END

    /* La planta tiene que ser del cliente. Sin esto, un id de otra empresa
       en el combo crearia una bodega dentro de la planta ajena. */
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                    WHERE cin_id = @INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('2.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Bodega]
                WHERE bod_cliente = @CLIENTE AND bod_codigo = @CODIGO)
    BEGIN
        RAISERROR('3.- YA EXISTE UNA BODEGA CON ESE CODIGO.', 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    INSERT INTO [dbo].[Bodega]
        (bod_cliente, bod_cliente_instalacion, bod_codigo, bod_nombre, bod_descripcion,
         bod_usuario_creacion, bod_fecha_creacion, bod_habilitado)
    VALUES (@CLIENTE, @INSTALACION, LTRIM(RTRIM(@CODIGO)), @NOMBRE, @DESCRIPCION,
            @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

COMMIT TRANSACTION
RETURN 0
GO


IF OBJECT_ID('dbo.UPD_BODEGA') IS NOT NULL DROP PROCEDURE [dbo].[UPD_BODEGA]
GO
CREATE PROCEDURE [dbo].[UPD_BODEGA]
    @ID          INT,
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @NOMBRE      NVARCHAR(400) = NULL,
    @DESCRIPCION NVARCHAR(1000) = NULL,
    @HABILITADO  BIT = NULL,
    @USUARIO     INT
AS
SET NOCOUNT ON

    /* El CODIGO no viaja: no se edita. Es con lo que se identifica la
       bodega en cualquier carga de datos, y renombrarlo desde un formulario
       rompe en silencio lo que lo referencie. */

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega] WHERE bod_id = @ID AND bod_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- LA BODEGA NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF (@INSTALACION IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                         WHERE cin_id = @INSTALACION AND cin_cliente = @CLIENTE))
    BEGIN
        RAISERROR('2.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    /* Deshabilitar una bodega con saldo esconderia existencia real: el
       repuesto sigue en la estanteria y deja de verse en las consultas. */
    IF (@HABILITADO = 0
        AND EXISTS (SELECT 1 FROM [dbo].[Inventario_Saldo]
                     WHERE isa_bodega = @ID AND isa_cantidad > 0))
    BEGIN
        DECLARE @MSG_BOD NVARCHAR(400) =
            '3.- NO SE PUEDE DESHABILITAR UNA BODEGA CON EXISTENCIA. '
          + 'TRASLADE O AJUSTE SUS REPUESTOS PRIMERO.'
        RAISERROR(@MSG_BOD, 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    -- ISNULL en todo lo opcional: lo que no viaja no se borra (bloque 51).
    UPDATE  [dbo].[Bodega]
    SET     bod_cliente_instalacion    = ISNULL(@INSTALACION, bod_cliente_instalacion)
           ,bod_nombre                 = ISNULL(@NOMBRE,      bod_nombre)
           ,bod_descripcion            = ISNULL(@DESCRIPCION, bod_descripcion)
           ,bod_habilitado             = ISNULL(@HABILITADO,  bod_habilitado)
           ,bod_usuario_actualizacion  = @USUARIO
           ,bod_fecha_actualizacion    = GETDATE()
    WHERE   bod_id = @ID

COMMIT TRANSACTION
RETURN 0
GO


IF OBJECT_ID('dbo.DEL_BODEGA') IS NOT NULL DROP PROCEDURE [dbo].[DEL_BODEGA]
GO
CREATE PROCEDURE [dbo].[DEL_BODEGA]
    @ID      INT,
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON

DECLARE @HAB BIT, @SALDO INT

SELECT @HAB = bod_habilitado FROM [dbo].[Bodega] WHERE bod_id = @ID AND bod_cliente = @CLIENTE

IF (@HAB IS NULL)
BEGIN
    RAISERROR('1.- LA BODEGA NO EXISTE.', 16, 1)
    RETURN -1
END

IF (@HAB = 0)
BEGIN
    SELECT @ID [ID], '200' [CODE], 'La bodega ya estaba dada de baja.' [MENSAJE]
    RETURN 0
END

SELECT @SALDO = COUNT(*) FROM [dbo].[Inventario_Saldo]
 WHERE isa_bodega = @ID AND isa_cantidad > 0

IF (@SALDO > 0)
BEGIN
    DECLARE @MSG NVARCHAR(400) =
        '2.- NO SE PUEDE DAR DE BAJA: LA BODEGA TIENE ' + LTRIM(STR(@SALDO))
      + ' REPUESTO(S) CON EXISTENCIA. TRASLADELOS O AJUSTELOS PRIMERO.'
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    UPDATE [dbo].[Bodega]
    SET    bod_habilitado = 0, bod_usuario_actualizacion = @USUARIO,
           bod_fecha_actualizacion = GETDATE()
    WHERE  bod_id = @ID

    -- Las ubicaciones son partes de la bodega: se van con ella.
    UPDATE [dbo].[Bodega_Ubicacion]
    SET    bub_habilitado = 0, bub_usuario_actualizacion = @USUARIO,
           bub_fecha_actualizacion = GETDATE()
    WHERE  bub_bodega = @ID AND bub_habilitado = 1

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Bodega dada de baja.' [MENSAJE]
RETURN 0
GO


/* ========================================================================
   7. BODEGA_UBICACION  (HU-052, criterio 2)

      "Pasillo A - Estante 3 - Nivel 2". Plana, no jerarquica: la jerarquia
      la escribe el propio codigo y no hay nada que se gane con tres niveles
      de tabla para algo que el bodeguero lee como una etiqueta.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_BODEGA_UBICACION') IS NOT NULL DROP PROCEDURE [dbo].[SEL_BODEGA_UBICACION]
GO
CREATE PROCEDURE [dbo].[SEL_BODEGA_UBICACION]
    @ID         INT = NULL,
    @BODEGA     INT = NULL,
    @CLIENTE    INT,
    @FILTRO     NVARCHAR(200) = NULL,
    @HABILITADO BIT = NULL
AS
SET NOCOUNT ON

    SELECT  u.bub_id, u.bub_bodega, u.bub_codigo, u.bub_nombre, u.bub_habilitado,
            b.bod_codigo AS BODEGA_CODIGO, b.bod_nombre AS BODEGA_NOMBRE
    FROM    [dbo].[Bodega_Ubicacion] u
    JOIN    [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
    WHERE   b.bod_cliente = @CLIENTE
      AND   (@ID IS NULL OR u.bub_id = @ID)
      AND   (@BODEGA IS NULL OR u.bub_bodega = @BODEGA)
      AND   (@HABILITADO IS NULL OR u.bub_habilitado = @HABILITADO)
      AND   (@FILTRO IS NULL OR u.bub_codigo LIKE '%' + @FILTRO + '%'
                             OR u.bub_nombre LIKE '%' + @FILTRO + '%')
    ORDER BY b.bod_codigo, u.bub_codigo
GO


IF OBJECT_ID('dbo.INS_BODEGA_UBICACION') IS NOT NULL DROP PROCEDURE [dbo].[INS_BODEGA_UBICACION]
GO
CREATE PROCEDURE [dbo].[INS_BODEGA_UBICACION]
    @ID      INT OUTPUT,
    @BODEGA  INT,
    @CLIENTE INT,
    @CODIGO  NVARCHAR(100),
    @NOMBRE  NVARCHAR(400),
    @USUARIO INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega] WHERE bod_id = @BODEGA AND bod_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- LA BODEGA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0)
    BEGIN
        RAISERROR('2.- INDIQUE EL CODIGO DE LA UBICACION.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion]
                WHERE bub_bodega = @BODEGA AND bub_codigo = @CODIGO)
    BEGIN
        RAISERROR('3.- YA EXISTE UNA UBICACION CON ESE CODIGO EN LA BODEGA.', 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    INSERT INTO [dbo].[Bodega_Ubicacion]
        (bub_bodega, bub_codigo, bub_nombre, bub_usuario_creacion, bub_fecha_creacion, bub_habilitado)
    VALUES (@BODEGA, LTRIM(RTRIM(@CODIGO)), @NOMBRE, @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

COMMIT TRANSACTION
RETURN 0
GO


IF OBJECT_ID('dbo.UPD_BODEGA_UBICACION') IS NOT NULL DROP PROCEDURE [dbo].[UPD_BODEGA_UBICACION]
GO
CREATE PROCEDURE [dbo].[UPD_BODEGA_UBICACION]
    @ID         INT,
    @CLIENTE    INT,
    @NOMBRE     NVARCHAR(400) = NULL,
    @HABILITADO BIT = NULL,
    @USUARIO    INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion] u
                    JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
                   WHERE u.bub_id = @ID AND b.bod_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- LA UBICACION NO EXISTE.', 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Bodega_Ubicacion]
    SET     bub_nombre                = ISNULL(@NOMBRE,     bub_nombre)
           ,bub_habilitado            = ISNULL(@HABILITADO, bub_habilitado)
           ,bub_usuario_actualizacion = @USUARIO
           ,bub_fecha_actualizacion   = GETDATE()
    WHERE   bub_id = @ID

COMMIT TRANSACTION
RETURN 0
GO


IF OBJECT_ID('dbo.DEL_BODEGA_UBICACION') IS NOT NULL DROP PROCEDURE [dbo].[DEL_BODEGA_UBICACION]
GO
CREATE PROCEDURE [dbo].[DEL_BODEGA_UBICACION]
    @ID      INT,
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion] u
                    JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
                   WHERE u.bub_id = @ID AND b.bod_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- LA UBICACION NO EXISTE.', 16, 1)
        RETURN -1
    END

    /* Los movimientos guardan la ubicacion en la que ocurrieron. Es
       historia: la ubicacion se deshabilita, no se borra, y el movimiento
       viejo sigue diciendo de que estante salio. */

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    UPDATE [dbo].[Bodega_Ubicacion]
    SET    bub_habilitado = 0, bub_usuario_actualizacion = @USUARIO,
           bub_fecha_actualizacion = GETDATE()
    WHERE  bub_id = @ID

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Ubicación dada de baja.' [MENSAJE]
RETURN 0
GO


/* ========================================================================
   8. REPUESTO  (HU-050)

      El criterio 2 pide buscar por el codigo del fabricante ademas del
      interno. No hay una columna con ese nombre: la que cumple ese papel es
      rep_modelo -"el codigo con el que el fabricante lo vende"-. El filtro
      busca en codigo, nombre, fabricante Y modelo, que es lo que el
      criterio pide de verdad: escribo lo que tengo a mano y lo encuentro.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_REPUESTO') IS NOT NULL DROP PROCEDURE [dbo].[SEL_REPUESTO]
GO
CREATE PROCEDURE [dbo].[SEL_REPUESTO]
    @ID         INT = NULL,
    @CLIENTE    INT,
    @FILTRO     NVARCHAR(200) = NULL,
    @HABILITADO BIT = NULL
AS
SET NOCOUNT ON

    SELECT  r.rep_id, r.rep_cliente, r.rep_codigo, r.rep_nombre,
            r.rep_fabricante, r.rep_modelo, r.rep_descripcion,
            r.rep_unidad_medida, r.rep_es_reparable, r.rep_es_consumible,
            r.rep_controla_lote, r.rep_costo_referencia, r.rep_moneda,
            r.rep_vida_util_hora, r.rep_vida_util_dia, r.rep_vida_util_ciclo,
            r.rep_habilitado,
            ume.ume_nombre  AS UNIDAD_NOMBRE,
            ume.ume_simbolo AS UNIDAD_SIMBOLO,
            mon.mon_codigo  AS MONEDA_CODIGO,
            ISNULL((SELECT SUM(s.isa_cantidad) FROM [dbo].[Inventario_Saldo] s
                     WHERE s.isa_repuesto = r.rep_id), 0) AS EXISTENCIA_TOTAL,
            (SELECT COUNT(*) FROM [dbo].[Inventario_Saldo] s
              WHERE s.isa_repuesto = r.rep_id AND s.isa_cantidad > 0) AS BODEGAS_CON_SALDO
    FROM    [dbo].[Repuesto] r
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Moneda] mon      ON mon.mon_id = r.rep_moneda
    WHERE   r.rep_cliente = @CLIENTE
      AND   r.rep_fusionado_en IS NULL      -- un repuesto fusionado ya no se ofrece
      AND   (@ID IS NULL OR r.rep_id = @ID)
      AND   (@HABILITADO IS NULL OR r.rep_habilitado = @HABILITADO)
      AND   (@FILTRO IS NULL OR r.rep_codigo     LIKE '%' + @FILTRO + '%'
                             OR r.rep_nombre     LIKE '%' + @FILTRO + '%'
                             OR r.rep_fabricante LIKE '%' + @FILTRO + '%'
                             OR r.rep_modelo     LIKE '%' + @FILTRO + '%')
    ORDER BY r.rep_codigo
GO


IF OBJECT_ID('dbo.INS_REPUESTO') IS NOT NULL DROP PROCEDURE [dbo].[INS_REPUESTO]
GO
CREATE PROCEDURE [dbo].[INS_REPUESTO]
    @ID               INT OUTPUT,
    @CLIENTE          INT,
    @CODIGO           NVARCHAR(100),
    @NOMBRE           NVARCHAR(400),
    @UNIDAD_MEDIDA    INT,
    @FABRICANTE       NVARCHAR(400) = NULL,
    @MODELO           NVARCHAR(400) = NULL,
    @DESCRIPCION      NVARCHAR(1000) = NULL,
    @ES_REPARABLE     BIT = 0,
    @ES_CONSUMIBLE    BIT = 0,
    @CONTROLA_LOTE    BIT = 0,
    @COSTO_REFERENCIA DECIMAL(18,4) = NULL,
    @MONEDA           INT = NULL,
    @USUARIO          INT
AS
SET NOCOUNT ON

    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0)
    BEGIN
        RAISERROR('1.- INDIQUE EL CODIGO DEL REPUESTO.', 16, 1)
        RETURN -1
    END

    IF (@NOMBRE IS NULL OR LEN(LTRIM(@NOMBRE)) = 0)
    BEGIN
        RAISERROR('2.- INDIQUE EL NOMBRE DEL REPUESTO.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida]
                    WHERE ume_id = @UNIDAD_MEDIDA AND ume_habilitado = 1)
    BEGIN
        RAISERROR('3.- LA UNIDAD DE MEDIDA NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Repuesto]
                WHERE rep_cliente = @CLIENTE AND rep_codigo = @CODIGO)
    BEGIN
        RAISERROR('4.- YA EXISTE UN REPUESTO CON ESE CODIGO.', 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    INSERT INTO [dbo].[Repuesto]
        (rep_uuid, rep_cliente, rep_unidad_medida, rep_codigo, rep_nombre,
         rep_fabricante, rep_modelo, rep_descripcion, rep_es_reparable,
         rep_es_consumible, rep_controla_lote, rep_costo_referencia, rep_moneda,
         rep_usuario_creacion, rep_fecha_creacion, rep_habilitado)
    VALUES (NEWID(), @CLIENTE, @UNIDAD_MEDIDA, LTRIM(RTRIM(@CODIGO)), @NOMBRE,
            @FABRICANTE, @MODELO, @DESCRIPCION, ISNULL(@ES_REPARABLE, 0),
            ISNULL(@ES_CONSUMIBLE, 0), ISNULL(@CONTROLA_LOTE, 0),
            @COSTO_REFERENCIA, @MONEDA, @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

COMMIT TRANSACTION
RETURN 0
GO


IF OBJECT_ID('dbo.UPD_REPUESTO') IS NOT NULL DROP PROCEDURE [dbo].[UPD_REPUESTO]
GO
CREATE PROCEDURE [dbo].[UPD_REPUESTO]
    @ID               INT,
    @CLIENTE          INT,
    @NOMBRE           NVARCHAR(400) = NULL,
    @UNIDAD_MEDIDA    INT = NULL,
    @FABRICANTE       NVARCHAR(400) = NULL,
    @MODELO           NVARCHAR(400) = NULL,
    @DESCRIPCION      NVARCHAR(1000) = NULL,
    @ES_REPARABLE     BIT = NULL,
    @ES_CONSUMIBLE    BIT = NULL,
    @CONTROLA_LOTE    BIT = NULL,
    @COSTO_REFERENCIA DECIMAL(18,4) = NULL,
    @MONEDA           INT = NULL,
    @HABILITADO       BIT = NULL,
    @USUARIO          INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto] WHERE rep_id = @ID AND rep_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- EL REPUESTO NO EXISTE.', 16, 1)
        RETURN -1
    END

    /* Cambiar la unidad de medida con existencia cargada convierte el saldo
       en otra cosa sin tocarlo: 40 litros pasan a ser 40 unidades. */
    IF (@UNIDAD_MEDIDA IS NOT NULL
        AND @UNIDAD_MEDIDA <> (SELECT rep_unidad_medida FROM [dbo].[Repuesto] WHERE rep_id = @ID)
        AND EXISTS (SELECT 1 FROM [dbo].[Inventario_Saldo]
                     WHERE isa_repuesto = @ID AND isa_cantidad <> 0))
    BEGIN
        DECLARE @MSG_UME NVARCHAR(400) =
            '2.- NO SE PUEDE CAMBIAR LA UNIDAD DE MEDIDA: EL REPUESTO TIENE EXISTENCIA. '
          + 'EL SALDO PASARIA A ESTAR EN OTRA UNIDAD SIN QUE NADIE LO CONVIRTIERA.'
        RAISERROR(@MSG_UME, 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Repuesto]
    SET     rep_nombre                = ISNULL(@NOMBRE,           rep_nombre)
           ,rep_unidad_medida         = ISNULL(@UNIDAD_MEDIDA,    rep_unidad_medida)
           ,rep_fabricante            = ISNULL(@FABRICANTE,       rep_fabricante)
           ,rep_modelo                = ISNULL(@MODELO,           rep_modelo)
           ,rep_descripcion           = ISNULL(@DESCRIPCION,      rep_descripcion)
           ,rep_es_reparable          = ISNULL(@ES_REPARABLE,     rep_es_reparable)
           ,rep_es_consumible         = ISNULL(@ES_CONSUMIBLE,    rep_es_consumible)
           ,rep_controla_lote         = ISNULL(@CONTROLA_LOTE,    rep_controla_lote)
           ,rep_costo_referencia      = ISNULL(@COSTO_REFERENCIA, rep_costo_referencia)
           ,rep_moneda                = ISNULL(@MONEDA,           rep_moneda)
           ,rep_habilitado            = ISNULL(@HABILITADO,       rep_habilitado)
           ,rep_usuario_actualizacion = @USUARIO
           ,rep_fecha_actualizacion   = GETDATE()
    WHERE   rep_id = @ID

COMMIT TRANSACTION
RETURN 0
GO


IF OBJECT_ID('dbo.DEL_REPUESTO') IS NOT NULL DROP PROCEDURE [dbo].[DEL_REPUESTO]
GO
CREATE PROCEDURE [dbo].[DEL_REPUESTO]
    @ID      INT,
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON

DECLARE @HAB BIT, @EXIST DECIMAL(18,4)

SELECT @HAB = rep_habilitado FROM [dbo].[Repuesto] WHERE rep_id = @ID AND rep_cliente = @CLIENTE

IF (@HAB IS NULL)
BEGIN
    RAISERROR('1.- EL REPUESTO NO EXISTE.', 16, 1)
    RETURN -1
END

IF (@HAB = 0)
BEGIN
    SELECT @ID [ID], '200' [CODE], 'El repuesto ya estaba dado de baja.' [MENSAJE]
    RETURN 0
END

SELECT @EXIST = ISNULL(SUM(isa_cantidad), 0) FROM [dbo].[Inventario_Saldo] WHERE isa_repuesto = @ID

IF (@EXIST > 0)
BEGIN
    DECLARE @MSG NVARCHAR(400) =
        '2.- NO SE PUEDE DAR DE BAJA: QUEDAN ' + LTRIM(STR(CAST(@EXIST AS INT)))
      + ' UNIDAD(ES) EN BODEGA. AJUSTE LA EXISTENCIA A CERO PRIMERO.'
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    UPDATE [dbo].[Repuesto]
    SET    rep_habilitado = 0, rep_usuario_actualizacion = @USUARIO,
           rep_fecha_actualizacion = GETDATE()
    WHERE  rep_id = @ID

    -- Los umbrales de un repuesto que ya no se usa dejarian alertas vivas.
    UPDATE [dbo].[Repuesto_Bodega_Stock]
    SET    rbs_habilitado = 0, rbs_usuario_actualizacion = @USUARIO,
           rbs_fecha_actualizacion = GETDATE()
    WHERE  rbs_repuesto = @ID AND rbs_habilitado = 1

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Repuesto dado de baja.' [MENSAJE]
RETURN 0
GO


/* ========================================================================
   9. UMBRALES DE STOCK  (HU-053)

      UPS y no INS+UPD: la fila es "los umbrales de este repuesto en esta
      bodega", con indice unico sobre el par. Dos procedimientos obligarian
      a la pantalla a preguntar antes si existe, y esa pregunta se contesta
      mejor aca, en una sola ida a la base.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_REPUESTO_BODEGA_STOCK') IS NOT NULL DROP PROCEDURE [dbo].[SEL_REPUESTO_BODEGA_STOCK]
GO
CREATE PROCEDURE [dbo].[SEL_REPUESTO_BODEGA_STOCK]
    @ID       INT = NULL,
    @CLIENTE  INT,
    @REPUESTO INT = NULL,
    @BODEGA   INT = NULL
AS
SET NOCOUNT ON

    SELECT  s.rbs_id, s.rbs_repuesto, s.rbs_bodega,
            s.rbs_stock_minimo, s.rbs_stock_maximo, s.rbs_punto_reposicion,
            s.rbs_observacion, s.rbs_habilitado,
            r.rep_codigo AS REPUESTO_CODIGO, r.rep_nombre AS REPUESTO_NOMBRE,
            b.bod_codigo AS BODEGA_CODIGO,   b.bod_nombre AS BODEGA_NOMBRE,
            ISNULL(sal.isa_cantidad, 0) AS EXISTENCIA,
            CASE WHEN ISNULL(sal.isa_cantidad, 0) < s.rbs_stock_minimo THEN 1 ELSE 0 END AS BAJO_MINIMO,
            CASE WHEN s.rbs_stock_maximo IS NOT NULL
                  AND ISNULL(sal.isa_cantidad, 0) > s.rbs_stock_maximo THEN 1 ELSE 0 END AS SOBRE_MAXIMO
    FROM    [dbo].[Repuesto_Bodega_Stock] s
    JOIN    [dbo].[Repuesto] r ON r.rep_id = s.rbs_repuesto
    JOIN    [dbo].[Bodega]   b ON b.bod_id = s.rbs_bodega
    LEFT JOIN [dbo].[Inventario_Saldo] sal
           ON sal.isa_repuesto = s.rbs_repuesto AND sal.isa_bodega = s.rbs_bodega
    WHERE   s.rbs_cliente = @CLIENTE
      AND   s.rbs_habilitado = 1
      AND   (@ID IS NULL OR s.rbs_id = @ID)
      AND   (@REPUESTO IS NULL OR s.rbs_repuesto = @REPUESTO)
      AND   (@BODEGA IS NULL OR s.rbs_bodega = @BODEGA)
    ORDER BY r.rep_codigo, b.bod_codigo
GO


IF OBJECT_ID('dbo.UPS_REPUESTO_BODEGA_STOCK') IS NOT NULL DROP PROCEDURE [dbo].[UPS_REPUESTO_BODEGA_STOCK]
GO
CREATE PROCEDURE [dbo].[UPS_REPUESTO_BODEGA_STOCK]
    @ID                INT OUTPUT,
    @CLIENTE           INT,
    @REPUESTO          INT,
    @BODEGA            INT,
    @STOCK_MINIMO      DECIMAL(18,4),
    @STOCK_MAXIMO      DECIMAL(18,4) = NULL,
    @PUNTO_REPOSICION  DECIMAL(18,4) = NULL,
    @OBSERVACION       NVARCHAR(1000) = NULL,
    @USUARIO           INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto] WHERE rep_id = @REPUESTO AND rep_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- EL REPUESTO NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega] WHERE bod_id = @BODEGA AND bod_cliente = @CLIENTE)
    BEGIN
        RAISERROR('2.- LA BODEGA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF (@STOCK_MINIMO IS NULL OR @STOCK_MINIMO < 0)
    BEGIN
        RAISERROR('3.- EL STOCK MINIMO NO PUEDE SER NEGATIVO.', 16, 1)
        RETURN -1
    END

    -- Criterio 1 de HU-053, textual.
    IF (@STOCK_MAXIMO IS NOT NULL AND @STOCK_MAXIMO < @STOCK_MINIMO)
    BEGIN
        RAISERROR('4.- EL STOCK MAXIMO NO PUEDE SER MENOR QUE EL MINIMO.', 16, 1)
        RETURN -1
    END

    /* El punto de reposicion es "cuando pedir": tiene que caer entre el
       minimo y el maximo. Bajo el minimo se avisaria cuando ya es tarde;
       sobre el maximo se pediria siempre. */
    IF (@PUNTO_REPOSICION IS NOT NULL AND @PUNTO_REPOSICION < @STOCK_MINIMO)
    BEGIN
        RAISERROR('5.- EL PUNTO DE REPOSICION NO PUEDE SER MENOR QUE EL STOCK MINIMO.', 16, 1)
        RETURN -1
    END

    IF (@PUNTO_REPOSICION IS NOT NULL AND @STOCK_MAXIMO IS NOT NULL
        AND @PUNTO_REPOSICION > @STOCK_MAXIMO)
    BEGIN
        RAISERROR('6.- EL PUNTO DE REPOSICION NO PUEDE SER MAYOR QUE EL STOCK MAXIMO.', 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    SELECT @ID = rbs_id FROM [dbo].[Repuesto_Bodega_Stock]
     WHERE rbs_repuesto = @REPUESTO AND rbs_bodega = @BODEGA

    IF (@ID IS NULL)
    BEGIN
        INSERT INTO [dbo].[Repuesto_Bodega_Stock]
            (rbs_cliente, rbs_repuesto, rbs_bodega, rbs_stock_minimo, rbs_stock_maximo,
             rbs_punto_reposicion, rbs_observacion, rbs_usuario_creacion,
             rbs_fecha_creacion, rbs_habilitado)
        VALUES (@CLIENTE, @REPUESTO, @BODEGA, @STOCK_MINIMO, @STOCK_MAXIMO,
                @PUNTO_REPOSICION, @OBSERVACION, @USUARIO, GETDATE(), 1)

        SET @ID = SCOPE_IDENTITY()
    END
    ELSE
    BEGIN
        UPDATE  [dbo].[Repuesto_Bodega_Stock]
        SET     rbs_stock_minimo          = @STOCK_MINIMO
               ,rbs_stock_maximo          = @STOCK_MAXIMO
               ,rbs_punto_reposicion      = @PUNTO_REPOSICION
               ,rbs_observacion           = ISNULL(@OBSERVACION, rbs_observacion)
               ,rbs_habilitado            = 1
               ,rbs_usuario_actualizacion = @USUARIO
               ,rbs_fecha_actualizacion   = GETDATE()
        WHERE   rbs_id = @ID
    END

COMMIT TRANSACTION
RETURN 0
GO


IF OBJECT_ID('dbo.DEL_REPUESTO_BODEGA_STOCK') IS NOT NULL DROP PROCEDURE [dbo].[DEL_REPUESTO_BODEGA_STOCK]
GO
CREATE PROCEDURE [dbo].[DEL_REPUESTO_BODEGA_STOCK]
    @ID      INT,
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Bodega_Stock]
                    WHERE rbs_id = @ID AND rbs_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- LOS UMBRALES NO EXISTEN.', 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    UPDATE [dbo].[Repuesto_Bodega_Stock]
    SET    rbs_habilitado = 0, rbs_usuario_actualizacion = @USUARIO,
           rbs_fecha_actualizacion = GETDATE()
    WHERE  rbs_id = @ID

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Umbrales retirados.' [MENSAJE]
RETURN 0
GO


/* ========================================================================
   9b. SEL_UNIDAD_MEDIDA

      Lo minimo para llenar el combo de la ficha de repuesto. El mantenedor
      completo es HU-040 (Sprint 2) y no se adelanta aca: esto es una
      consulta, no su administracion.

      La etiqueta se arma en la consulta -"Unidad (un)"- porque es lo que se
      ve en el combo, y armarla en C# obligaria a repetirla en la web y en
      la app.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_UNIDAD_MEDIDA') IS NOT NULL DROP PROCEDURE [dbo].[SEL_UNIDAD_MEDIDA]
GO

CREATE PROCEDURE [dbo].[SEL_UNIDAD_MEDIDA]
    @ID         INT = NULL,
    @HABILITADO BIT = 1
AS
SET NOCOUNT ON

    SELECT  u.ume_id, u.ume_codigo, u.ume_nombre, u.ume_simbolo,
            u.ume_magnitud, u.ume_habilitado,
            m.mag_nombre AS MAGNITUD_NOMBRE,
            u.ume_nombre + ' (' + ISNULL(u.ume_simbolo, u.ume_codigo) + ')' AS ETIQUETA
    FROM    [dbo].[Unidad_Medida] u
    JOIN    [dbo].[Magnitud] m ON m.mag_id = u.ume_magnitud
    WHERE   (@ID IS NULL OR u.ume_id = @ID)
      AND   (@HABILITADO IS NULL OR u.ume_habilitado = @HABILITADO)
    ORDER BY m.mag_orden, u.ume_nombre
GO


/* ========================================================================
   10. VERIFICACION
   ======================================================================== */
PRINT '--- SPs del bloque 60 ---'
SELECT name FROM sys.objects
WHERE type = 'P' AND (name LIKE '%_BODEGA%' OR name LIKE '%_REPUESTO%')
ORDER BY name

PRINT '--- Permisos y menus ---'
SELECT (SELECT COUNT(*) FROM [dbo].[Permiso] WHERE prm_modulo IN ('INVENTARIO','REPUESTOS')) AS permisos,
       (SELECT COUNT(*) FROM [dbo].[Menus] m
         JOIN [dbo].[Menus] p ON p.mnu_id = m.mnu_padre
        WHERE p.mnu_nombre COLLATE DATABASE_DEFAULT = 'Inventario')                                  AS menus,
       (SELECT COUNT(*) FROM [dbo].[Unidad_Medida])                         AS unidades
GO
