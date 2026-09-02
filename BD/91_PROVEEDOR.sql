/* ============================================================================
   SIGMA — Bloque 91
   PROVEEDORES Y CONTRATISTAS                                          HU-060
   ----------------------------------------------------------------------------

   QUE ES ESTO

     El registro de las empresas que le prestan servicios a la planta. La
     historia lo pide para poder sumar al cierre del año cuánto se gastó en
     cada contratista, así que no es un catálogo decorativo: es el eje por el
     que después se agrupa gasto (HU-065).

   ES DE EP-07, NO DE INVENTARIO

     La tabla ya existía desde las fundaciones y `Repuesto_Lote` apunta a
     ella, así que era tentador colgarla del menú de Inventario junto a
     Repuestos y Bodegas.

     Pero la historia es de EP-07 —"Terceros, procedimientos y permisos de
     trabajo"— y habla de contratistas, no de quién vende los repuestos. Tres
     de las cuatro tablas que dependen de Proveedor son de órdenes de
     trabajo. Colgarla de Inventario obligaría a mudarla en cuanto llegue
     HU-063, y un menú que cambia de sitio es un menú que la gente deja de
     encontrar.

     Se crea el módulo **Terceros**, que es donde van a vivir también los
     permisos de trabajo y el historial del proveedor.

   NO LLEVA CODIGO AUTOMATICO, Y ES CORRECTO

     El bloque 77 le puso código `XXX-<id>` a los módulos que tienen columna
     de código. Proveedor **no la tiene**, y no se le agrega: una empresa ya
     tiene un identificador único y universal, que es su RUT. Inventar un
     `PRV-12` al lado sería un segundo nombre para lo mismo, y el día que
     alguien busque por uno no va a encontrar el otro.

     `UX_PRV_CLIENTE_RUT` ya garantiza que no haya dos veces la misma empresa
     dentro de un cliente. Esa es la unicidad que importa.

   EL RUT SE VALIDA SEGUN EL PAIS DEL CLIENTE

     SIGMA opera en cinco países y el documento no se llama ni se valida
     igual (bloque 39). Se reutiliza `FNC_IDENTIFICADOR_VALIDO`, que ya
     despacha por país, en vez de escribir acá una comprobación de RUT
     chileno que sería incorrecta para cuatro de los cinco.

   ORDEN: despues de 90_REUBICACION_SIN_ORIGEN.sql
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. INDICES DE APOYO                                              T-3143

      El listado filtra por cliente y por habilitado, y ordena por razón
      social. Sin este índice la consulta recorre la tabla entera y ordena
      en memoria; con pocos proveedores da igual, con dos mil no.

      La unicidad del RUT por cliente ya la cubre UX_PRV_CLIENTE_RUT, que
      viene de las fundaciones: no se toca.
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'IX_PRV_CLIENTE_HABILITADO'
                  AND object_id = OBJECT_ID('dbo.Proveedor'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_PRV_CLIENTE_HABILITADO
        ON [dbo].[Proveedor] ([prv_cliente], [prv_habilitado])
        INCLUDE ([prv_razon_social], [prv_rut], [prv_es_contratista], [prv_es_proveedor_repuesto])

    PRINT '--- Indice IX_PRV_CLIENTE_HABILITADO creado.'
END
ELSE PRINT '--- Indice IX_PRV_CLIENTE_HABILITADO ya existe.'
GO


/* ========================================================================
   2. SEL_PROVEEDOR                                                 T-3144

      Un solo SP para la grilla y para la ficha: con @ID devuelve uno, sin
      @ID devuelve la lista. Dos procedimientos casi iguales son dos sitios
      donde arreglar la misma columna olvidada.

      @FILTRO va PARAMETRIZADO, nunca concatenado. En SEL_CLIENTE_USUARIO
      eso fue inyección SQL desde el propio buscador (bloque 49).
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PROVEEDOR') IS NOT NULL DROP PROCEDURE [dbo].[SEL_PROVEEDOR]
GO

CREATE PROCEDURE [dbo].[SEL_PROVEEDOR]
    @CLIENTE            INT,
    @ID                 INT = NULL,
    @FILTRO             VARCHAR(200) = NULL,
    @HABILITADO         BIT = NULL,
    @ES_CONTRATISTA     BIT = NULL,
    @ES_PROV_REPUESTO   BIT = NULL
AS
SET NOCOUNT ON

    SELECT  p.prv_id,
            p.prv_cliente,
            p.prv_rut,
            p.prv_razon_social,
            p.prv_nombre_fantasia,
            p.prv_giro,
            p.prv_contacto,
            p.prv_email,
            p.prv_telefono,
            p.prv_direccion,
            p.prv_es_contratista,
            p.prv_es_proveedor_repuesto,
            p.prv_observacion,
            p.prv_habilitado,
            p.prv_usuario_creacion,
            p.prv_fecha_creacion,
            p.prv_usuario_actualizacion,
            p.prv_fecha_actualizacion,
            /* El nombre y no el id: una auditoría que obliga a ir a buscar
               quién es el 7 no sirve para lo que se hizo. */
            ISNULL(uc.usu_nombre + ' ' + uc.usu_apellido_paterno, '') AS USUARIO_CREACION_NOMBRE,
            ISNULL(ua.usu_nombre + ' ' + ua.usu_apellido_paterno, '') AS USUARIO_ACTUALIZACION_NOMBRE,
            /* Lo que se muestra en la lista sin tener que abrir la ficha. */
            (SELECT COUNT(*) FROM [dbo].[Repuesto_Lote] l
              WHERE l.rlo_proveedor = p.prv_id)                       AS LOTES,
            (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Servicio] s
              WHERE s.ots_proveedor = p.prv_id)                       AS SERVICIOS
    FROM    [dbo].[Proveedor] p
    LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = p.prv_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = p.prv_usuario_actualizacion
    WHERE   p.prv_cliente = @CLIENTE
      AND   (@ID IS NULL OR p.prv_id = @ID)
      AND   (@HABILITADO IS NULL OR p.prv_habilitado = @HABILITADO)
      AND   (@ES_CONTRATISTA IS NULL OR p.prv_es_contratista = @ES_CONTRATISTA)
      AND   (@ES_PROV_REPUESTO IS NULL OR p.prv_es_proveedor_repuesto = @ES_PROV_REPUESTO)
      AND   (@FILTRO IS NULL
             OR p.prv_rut             LIKE '%' + @FILTRO + '%'
             OR p.prv_razon_social    LIKE '%' + @FILTRO + '%'
             OR p.prv_nombre_fantasia LIKE '%' + @FILTRO + '%'
             OR p.prv_contacto        LIKE '%' + @FILTRO + '%'
             OR p.prv_email           LIKE '%' + @FILTRO + '%')
    /* Orden estable: la razón social puede repetirse entre dos sucursales,
       y sin el desempate por id la paginación puede mostrar dos veces la
       misma fila y saltarse otra. */
    ORDER BY p.prv_razon_social, p.prv_id
GO

PRINT '--- SEL_PROVEEDOR creado.'
GO


/* ========================================================================
   3. INS_PROVEEDOR                                                 T-3145
   ======================================================================== */
IF OBJECT_ID('dbo.INS_PROVEEDOR') IS NOT NULL DROP PROCEDURE [dbo].[INS_PROVEEDOR]
GO

CREATE PROCEDURE [dbo].[INS_PROVEEDOR]
    @ID                 INT OUTPUT,
    @CLIENTE            INT,
    @RUT                NVARCHAR(40),
    @RAZON_SOCIAL       NVARCHAR(400),
    @NOMBRE_FANTASIA    NVARCHAR(400) = NULL,
    @GIRO               NVARCHAR(400) = NULL,
    @CONTACTO           NVARCHAR(400) = NULL,
    @EMAIL              NVARCHAR(400) = NULL,
    @TELEFONO           NVARCHAR(100) = NULL,
    @DIRECCION          NVARCHAR(600) = NULL,
    @ES_CONTRATISTA     BIT = 0,
    @ES_PROV_REPUESTO   BIT = 0,
    @OBSERVACION        NVARCHAR(1000) = NULL,
    @USUARIO            INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @AHORA DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @RUT = UPPER(LTRIM(RTRIM(@RUT)))
SET @RAZON_SOCIAL = LTRIM(RTRIM(@RAZON_SOCIAL))

IF (@RUT IS NULL OR LEN(@RUT) = 0)
BEGIN
    RAISERROR('1.- INDIQUE EL IDENTIFICADOR TRIBUTARIO DEL PROVEEDOR.', 16, 1)
    RETURN -1
END

IF (@RAZON_SOCIAL IS NULL OR LEN(@RAZON_SOCIAL) = 0)
BEGIN
    RAISERROR('2.- INDIQUE LA RAZON SOCIAL.', 16, 1)
    RETURN -1
END

/* Se valida contra el país del CLIENTE, no contra Chile: el mismo sistema
   opera con RUT, RUC y CUIT, y una comprobación de módulo 11 aplicada a un
   RUC peruano rechaza documentos correctos. */
IF ([dbo].[FNC_IDENTIFICADOR_VALIDO](@PAIS, @RUT) = 0)
BEGIN
    RAISERROR('3.- EL IDENTIFICADOR TRIBUTARIO NO ES VALIDO PARA EL PAIS DEL CLIENTE.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Proveedor]
            WHERE prv_cliente = @CLIENTE AND prv_rut = @RUT)
BEGIN
    RAISERROR('4.- YA EXISTE UN PROVEEDOR CON EL IDENTIFICADOR "%s".', 16, 1, @RUT)
    RETURN -1
END

/* Un proveedor que no es ni contratista ni vendedor de repuestos no se
   puede elegir en ninguna pantalla: quedaría registrado y sería inalcanzable. */
IF (@ES_CONTRATISTA = 0 AND @ES_PROV_REPUESTO = 0)
BEGIN
    RAISERROR('5.- INDIQUE AL MENOS UN TIPO: CONTRATISTA O PROVEEDOR DE REPUESTOS.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    INSERT INTO [dbo].[Proveedor]
        (prv_cliente, prv_rut, prv_razon_social, prv_nombre_fantasia, prv_giro,
         prv_contacto, prv_email, prv_telefono, prv_direccion,
         prv_es_contratista, prv_es_proveedor_repuesto, prv_observacion,
         prv_usuario_creacion, prv_fecha_creacion,
         prv_usuario_actualizacion, prv_fecha_actualizacion, prv_habilitado)
    VALUES
        (@CLIENTE, @RUT, @RAZON_SOCIAL, @NOMBRE_FANTASIA, @GIRO,
         @CONTACTO, @EMAIL, @TELEFONO, @DIRECCION,
         @ES_CONTRATISTA, @ES_PROV_REPUESTO, @OBSERVACION,
         @USUARIO, @AHORA, @USUARIO, @AHORA, 1)

    /* @@ROWCOUNT se lee ACA y no despues: cualquier sentencia intermedia lo
       reescribe. El bloque 89 existe por haberlo leido tres lineas mas
       abajo en siete procedimientos. */
    DECLARE @FILAS_INS INT = @@ROWCOUNT

    SET @ID = SCOPE_IDENTITY()

    IF @FILAS_INS = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('6.- NO FUE POSIBLE INSERTAR EL PROVEEDOR.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Proveedor creado con éxito.' AS MENSAJE
GO

PRINT '--- INS_PROVEEDOR creado.'
GO


/* ========================================================================
   4. UPD_PROVEEDOR                                                 T-3146

      Los campos que la ficha no muestre se conservan con ISNULL(@X, columna):
      un formulario parcial no puede borrar en silencio lo que no enseñó.

      El RUT SI se puede corregir —se teclea mal el primer día— pero vuelve
      a pasar por la validación y por la unicidad.
   ======================================================================== */
IF OBJECT_ID('dbo.UPD_PROVEEDOR') IS NOT NULL DROP PROCEDURE [dbo].[UPD_PROVEEDOR]
GO

CREATE PROCEDURE [dbo].[UPD_PROVEEDOR]
    @ID                 INT,
    @RUT                NVARCHAR(40) = NULL,
    @RAZON_SOCIAL       NVARCHAR(400) = NULL,
    @NOMBRE_FANTASIA    NVARCHAR(400) = NULL,
    @GIRO               NVARCHAR(400) = NULL,
    @CONTACTO           NVARCHAR(400) = NULL,
    @EMAIL              NVARCHAR(400) = NULL,
    @TELEFONO           NVARCHAR(100) = NULL,
    @DIRECCION          NVARCHAR(600) = NULL,
    @ES_CONTRATISTA     BIT = NULL,
    @ES_PROV_REPUESTO   BIT = NULL,
    @OBSERVACION        NVARCHAR(1000) = NULL,
    @HABILITADO         BIT = NULL,
    @USUARIO            INT
AS
SET NOCOUNT ON

DECLARE @CLIENTE INT, @PAIS INT, @AHORA DATETIME

SELECT @CLIENTE = prv_cliente FROM [dbo].[Proveedor] WHERE prv_id = @ID

IF (@CLIENTE IS NULL)
BEGIN
    RAISERROR('7.- EL PROVEEDOR NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

IF (@RUT IS NOT NULL)
BEGIN
    SET @RUT = UPPER(LTRIM(RTRIM(@RUT)))

    IF ([dbo].[FNC_IDENTIFICADOR_VALIDO](@PAIS, @RUT) = 0)
    BEGIN
        RAISERROR('3.- EL IDENTIFICADOR TRIBUTARIO NO ES VALIDO PARA EL PAIS DEL CLIENTE.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Proveedor]
                WHERE prv_cliente = @CLIENTE AND prv_rut = @RUT AND prv_id <> @ID)
    BEGIN
        RAISERROR('4.- YA EXISTE UN PROVEEDOR CON EL IDENTIFICADOR "%s".', 16, 1, @RUT)
        RETURN -1
    END
END

/* La misma regla que en el alta, pero mirando lo que va a QUEDAR: se puede
   estar apagando el único tipo que tenía. */
IF (ISNULL(@ES_CONTRATISTA,   (SELECT prv_es_contratista        FROM [dbo].[Proveedor] WHERE prv_id = @ID)) = 0
AND ISNULL(@ES_PROV_REPUESTO, (SELECT prv_es_proveedor_repuesto FROM [dbo].[Proveedor] WHERE prv_id = @ID)) = 0)
BEGIN
    RAISERROR('5.- INDIQUE AL MENOS UN TIPO: CONTRATISTA O PROVEEDOR DE REPUESTOS.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Proveedor]
    SET     prv_rut                   = ISNULL(@RUT, prv_rut)
           ,prv_razon_social           = ISNULL(NULLIF(LTRIM(RTRIM(@RAZON_SOCIAL)), ''), prv_razon_social)
           ,prv_nombre_fantasia        = ISNULL(@NOMBRE_FANTASIA, prv_nombre_fantasia)
           ,prv_giro                   = ISNULL(@GIRO, prv_giro)
           ,prv_contacto               = ISNULL(@CONTACTO, prv_contacto)
           ,prv_email                  = ISNULL(@EMAIL, prv_email)
           ,prv_telefono               = ISNULL(@TELEFONO, prv_telefono)
           ,prv_direccion              = ISNULL(@DIRECCION, prv_direccion)
           ,prv_es_contratista         = ISNULL(@ES_CONTRATISTA, prv_es_contratista)
           ,prv_es_proveedor_repuesto  = ISNULL(@ES_PROV_REPUESTO, prv_es_proveedor_repuesto)
           ,prv_observacion            = ISNULL(@OBSERVACION, prv_observacion)
           ,prv_habilitado             = ISNULL(@HABILITADO, prv_habilitado)
           ,prv_usuario_actualizacion  = @USUARIO
           ,prv_fecha_actualizacion    = @AHORA
    WHERE   prv_id = @ID

    DECLARE @FILAS_UPD INT = @@ROWCOUNT

    IF @FILAS_UPD = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('8.- NO FUE POSIBLE ACTUALIZAR EL PROVEEDOR.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Proveedor actualizado con éxito.' AS MENSAJE
GO

PRINT '--- UPD_PROVEEDOR creado.'
GO


/* ========================================================================
   5. DEL_PROVEEDOR                                                 T-3147

      BAJA LOGICA, Y RECHAZO EXPLICADO

        Un proveedor con lotes recibidos o servicios contratados NO se borra
        ni se apaga en silencio: su nombre aparece en el historial de compra
        y en el gasto del año. Borrarlo dejaría lotes apuntando a un
        proveedor que ya no está, que es justo lo que HU-065 necesita leer.

        El mensaje dice CUANTOS dependientes hay. Un "no se puede" a secas
        obliga a salir a buscar por qué.
   ======================================================================== */
IF OBJECT_ID('dbo.DEL_PROVEEDOR') IS NOT NULL DROP PROCEDURE [dbo].[DEL_PROVEEDOR]
GO

CREATE PROCEDURE [dbo].[DEL_PROVEEDOR]
    @ID      INT,
    @USUARIO INT
AS
SET NOCOUNT ON

DECLARE @CLIENTE INT, @PAIS INT, @AHORA DATETIME, @DEP INT, @MSG NVARCHAR(400)

SELECT @CLIENTE = prv_cliente FROM [dbo].[Proveedor] WHERE prv_id = @ID

IF (@CLIENTE IS NULL)
BEGIN
    RAISERROR('7.- EL PROVEEDOR NO EXISTE.', 16, 1)
    RETURN -1
END

SET @DEP = (SELECT COUNT(*) FROM [dbo].[Repuesto_Lote]            WHERE rlo_proveedor = @ID)
         + (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Servicio]   WHERE ots_proveedor = @ID)
         + (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Mano_Obra]  WHERE omo_proveedor = @ID)
         + (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Asignacion] WHERE ota_proveedor = @ID)

IF (@DEP > 0)
BEGIN
    SET @MSG = '9.- EL PROVEEDOR TIENE ' + LTRIM(STR(@DEP)) +
               ' REGISTRO(S) ASOCIADO(S) Y NO SE PUEDE ELIMINAR. ' +
               'DESHABILITELO PARA QUE DEJE DE OFRECERSE SIN PERDER SU HISTORIAL.'
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    UPDATE  [dbo].[Proveedor]
    SET     prv_habilitado            = 0
           ,prv_usuario_actualizacion = @USUARIO
           ,prv_fecha_actualizacion   = @AHORA
    WHERE   prv_id = @ID

    DECLARE @FILAS_DEL INT = @@ROWCOUNT

    IF @FILAS_DEL = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('10.- NO FUE POSIBLE ELIMINAR EL PROVEEDOR.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Proveedor eliminado con éxito.' AS MENSAJE
GO

PRINT '--- DEL_PROVEEDOR creado.'
GO


/* ========================================================================
   6. PERMISOS Y MENU                                        T-3155 · T-3156

      La seguridad de SIGMA es por datos: sin fila en Menus la pantalla no
      abre, aunque el archivo exista y el usuario sea Root.
   ======================================================================== */
DECLARE @VER INT, @EDITAR INT, @PADRE INT, @MNU INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PROVEEDORES')
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    VALUES ('VER PROVEEDORES', 'Ver proveedores y contratistas', 'TERCEROS', 3,
            'Consultar el registro de empresas que prestan servicios', 1, GETDATE(), 1, 0)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR PROVEEDORES')
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    VALUES ('CREAR EDITAR PROVEEDORES', 'Crear y editar proveedores', 'TERCEROS', 1,
            'Dar de alta y mantener proveedores y contratistas', 1, GETDATE(), 1, 0)

SELECT @VER    = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PROVEEDORES'
SELECT @EDITAR = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR PROVEEDORES'

/* El módulo Terceros, hermano de Inventario y Activos. Acá van a colgar
   después los permisos de trabajo (HU-063, HU-064) y el historial del
   proveedor (HU-065). */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_nombre = 'Terceros' AND mnu_nivel = 2)
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Terceros', 'Proveedores, contratistas y permisos de trabajo',
            2, 1, 6, '#', 1, 'mdi mdi-handshake-outline', @VER, 1)

SELECT @PADRE = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre = 'Terceros' AND mnu_nivel = 2

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Terceros/Proveedores/Proveedores.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Proveedores', 'Empresas que prestan servicios o venden repuestos',
            3, @PADRE, 1, '~/View/Terceros/Proveedores/Proveedores.aspx',
            1, NULL, @VER, 1)

/* La ficha va invisible pero CON fila: se llega desde el listado, y sin su
   registro Token.ExigirPagina la cierra. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Terceros/Proveedores/Proveedor.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Proveedor (detalle)', 'Ficha del proveedor',
            3, @PADRE, 99, '~/View/Terceros/Proveedores/Proveedor.aspx',
            0, NULL, @VER, 1)

/* Menu_Funcion SIEMPRE que nace un menú: sin la fila, Token.PuedeFuncion
   devuelve false para todos —Root incluido— y el botón no aparece, sin
   ningún error que lo explique. */
SELECT @MNU = mnu_id FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Terceros/Proveedores/Proveedores.aspx'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Crear y editar', @MNU, @EDITAR)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Eliminar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Eliminar', @MNU, @EDITAR)

SELECT @MNU = mnu_id FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Terceros/Proveedores/Proveedor.aspx'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Crear y editar', @MNU, @EDITAR)

PRINT '--- Permisos y menu de Terceros/Proveedores listos.'
GO


/* ========================================================================
   7. LOS DOS PERFILES QUE LO NECESITAN

      Sin esto el menú existe y no lo ve nadie salvo Root.
   ======================================================================== */
DECLARE @VER INT, @EDITAR INT

SELECT @VER    = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PROVEEDORES'
SELECT @EDITAR = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR PROVEEDORES'

/* Jefe de Mantenimiento (5) es quien negocia con los contratistas: es el
   protagonista de la historia. Administrador del Cliente (10) mantiene los
   maestros de su empresa. El Bodeguero (4) los ve porque elige proveedor al
   recibir un lote, pero no los crea. */
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT p.per_id, x.prm, 1, GETDATE()
FROM   (VALUES (5), (10)) AS p(per_id)
CROSS JOIN (VALUES (@VER), (@EDITAR)) AS x(prm)
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso]
                    WHERE ppe_perfil = p.per_id AND ppe_permiso = x.prm)

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT 4, @VER, 1, GETDATE()
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso]
                    WHERE ppe_perfil = 4 AND ppe_permiso = @VER)

PRINT '--- Perfiles con acceso a proveedores listos.'
GO


/* ========================================================================
   8. DATOS DE PRUEBA                                               T-3148

      RUT chilenos VALIDOS por módulo 11: con inválidos el propio
      INS_PROVEEDOR los rechazaría, y unos datos de demo que no se pueden
      cargar no sirven para ejercitar nada.
   ======================================================================== */
DECLARE @ID INT, @N INT = 0

IF NOT EXISTS (SELECT 1 FROM [dbo].[Proveedor] WHERE prv_cliente = 1)
BEGIN
    EXEC [dbo].[INS_PROVEEDOR] @ID OUTPUT, 1, N'76.124.351-9', N'Servicios Industriales Antuco SpA',
         N'Antuco Servicios', N'Mantenimiento industrial y montaje',
         N'Hernán Villalobos', N'contacto@antuco.cl', N'+56 43 221 4478',
         N'Camino a Coronel 1420, Los Ángeles', 1, 0,
         N'Contratista habitual de montaje mecánico.', 1
    SET @N = @N + 1

    EXEC [dbo].[INS_PROVEEDOR] @ID OUTPUT, 1, N'96.874.230-2', N'Rodamientos del Sur Limitada',
         N'Rodasur', N'Venta de rodamientos y transmisión',
         N'Paulina Cárdenas', N'ventas@rodasur.cl', N'+56 41 274 9910',
         N'Av. Manuel Rodríguez 880, Concepción', 0, 1,
         N'Proveedor de rodamientos SKF y NSK.', 1
    SET @N = @N + 1

    EXEC [dbo].[INS_PROVEEDOR] @ID OUTPUT, 1, N'77.045.982-6', N'Eléctrica Bío Bío SpA',
         N'Elebio', N'Montaje eléctrico y tableros',
         N'Marco Sandoval', N'marco.sandoval@elebio.cl', N'+56 41 233 5567',
         N'Los Carrera 2310, Talcahuano', 1, 1,
         N'Presta servicio eléctrico y además vende fusibles y protecciones.', 1
    SET @N = @N + 1

    PRINT '--- Proveedores de prueba creados: ' + LTRIM(STR(@N))
END
ELSE PRINT '--- El cliente ya tiene proveedores: no se cargan los de prueba.'
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
EXEC [dbo].[SEL_PROVEEDOR] @CLIENTE = 1
GO

SELECT  m.mnu_id, m.mnu_nivel, m.mnu_nombre, m.mnu_link, m.mnu_visible,
        (SELECT COUNT(*) FROM [dbo].[Menu_Funcion] f WHERE f.mfu_menu = m.mnu_id) AS FUNCIONES
FROM    [dbo].[Menus] m
WHERE   m.mnu_nombre = 'Terceros' OR m.mnu_link LIKE '%Proveedor%'
ORDER BY m.mnu_nivel, m.mnu_orden
GO

PRINT '91_PROVEEDOR aplicado.'
GO
