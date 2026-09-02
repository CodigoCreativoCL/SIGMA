/* ============================================================================
   SIGMA - Bloque 89
   EL INSERT FUNCIONABA Y EL PROCEDIMIENTO LO DESHACIA
   ----------------------------------------------------------------------------

   EL SINTOMA

     Guardar un grupo de trabajo respondia

       4.- NO FUE POSIBLE INSERTAR EL GRUPO DE TRABAJO.. Error ID: 56

     y no quedaba nada. Lo mismo en areas, especialidades, centros de costo,
     plantas, activos y planes comerciales: siete pantallas de alta rotas.

   LA CAUSA, Y ES DEL BLOQUE 77

     El bloque 77 metio el codigo automatico DENTRO del INSERT, entre la
     insercion y su comprobacion:

         INSERT ...
         SET @ID = SCOPE_IDENTITY()
         IF (@CODIGO = 'AUTO') UPDATE ... SET codigo = FNC_CODIGO_AUTOMATICO(...)
         IF @@ROWCOUNT = 0 -> ROLLBACK

     @@ROWCOUNT es de la ULTIMA sentencia ejecutada, no del INSERT. Cuando el
     codigo NO es 'AUTO' el IF no se cumple, un IF que no se cumple deja
     @@ROWCOUNT en 0, y el procedimiento concluye que el INSERT no inserto
     nada. Deshace una insercion que habia funcionado y reporta un error que
     no ocurrio.

     Con 'AUTO' funcionaba de casualidad: el UPDATE se ejecutaba y dejaba
     @@ROWCOUNT en 1. Por eso el defecto no se vio al escribir el bloque 77 y
     aparecio recien cuando alguien escribio un codigo a mano.

   LA CORRECCION

     @@ROWCOUNT se guarda en el instante en que todavia significa lo que se
     quiere preguntar, y la comprobacion mira esa variable:

         INSERT ...
         DECLARE @FILAS_INS INT = @@ROWCOUNT      <- aca vale lo del INSERT
         SET @ID = SCOPE_IDENTITY()
         IF (...) UPDATE ...
         IF @FILAS_INS = 0 -> ROLLBACK

   LA REGLA QUE QUEDA

     @@ROWCOUNT y @@ERROR se leen en la linea siguiente o no se leen. Cualquier
     sentencia intermedia -incluido un IF que no se cumple, o un SET- los
     reescribe. Si hace falta consultarlos mas abajo, se capturan primero.

   ORDEN: despues de 88_USUARIO_LISTA_PERFIL.sql
   ============================================================================ */

SET NOCOUNT ON
GO

IF OBJECT_ID('dbo.INS_ACTIVO') IS NOT NULL DROP PROCEDURE [dbo].[INS_ACTIVO]
GO



/* ========================================================================
   T-2003 - INS_ACTIVO
      Alta de un activo dentro de transaccion. Valida el codigo unico por
      cliente ANTES de la transaccion y sella las fechas con la hora local
      del pais del cliente (FNC_PAIS_HORA), no con GETDATE(): SIGMA opera en
      cinco paises y un activo creado en Panama no puede fecharse con la hora
      de Chile.
   ======================================================================== */

CREATE PROCEDURE [dbo].[INS_ACTIVO]
@ID                     INT = NULL OUTPUT,
@CLIENTE                INT,
@CLIENTE_INSTALACION    INT,
@INSTALACION_AREA       INT = NULL,
@ACTIVO_TIPO            INT,
@ACTIVO_MODELO          INT = NULL,
@ACTIVO_ESTADO          INT,
@ACTIVO_PADRE           INT = NULL,
@CENTRO_COSTO           INT = NULL,
@CRITICIDAD_NIVEL       INT,
@CODIGO                 NVARCHAR(50),
@NOMBRE                 NVARCHAR(200),
@NUMERO_SERIE           NVARCHAR(100) = NULL,
@FABRICANTE             NVARCHAR(200) = NULL,
@ANIO_FABRICACION       INT = NULL,
@FECHA_PUESTA_MARCHA    DATE = NULL,
@DESCRIPCION            NVARCHAR(500) = NULL,
@REGISTRO_ORIGEN        INT = NULL,
@USUARIO                INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

-- Origen por defecto: creado en la web (Registro_Origen id 2 = PLANIFICADOR WEB).
SET @REGISTRO_ORIGEN = ISNULL(@REGISTRO_ORIGEN, 2)

BEGIN
    -- Codigo unico por cliente (HU-035 escenario 2).
    IF EXISTS (SELECT 1 FROM [dbo].[Activo]
                WHERE act_cliente = @CLIENTE AND act_codigo = @CODIGO)
    BEGIN
        RAISERROR('1.- YA EXISTE UN ACTIVO CON EL CODIGO "%s" EN ESTE CLIENTE.', 16, 1, @CODIGO)
        RETURN -1
    END

    -- La planta tiene que ser del mismo cliente: un activo no puede colgar
    -- de la instalacion de otra empresa.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                    WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('2.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- El activo padre, si se indica, tambien es del mismo cliente.
    IF @ACTIVO_PADRE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo]
                        WHERE act_id = @ACTIVO_PADRE AND act_cliente = @CLIENTE)
    BEGIN
        RAISERROR('3.- EL ACTIVO SUPERIOR NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Activo]
        (
            act_cliente,
            act_cliente_instalacion,
            act_instalacion_area,
            act_activo_tipo,
            act_activo_modelo,
            act_activo_estado,
            act_activo_padre,
            act_centro_costo,
            act_criticidad_nivel,
            act_codigo,
            act_nombre,
            act_numero_serie,
            act_fabricante,
            act_anio_fabricacion,
            act_fecha_puesta_marcha,
            act_descripcion,
            act_registro_origen,
            act_usuario_creacion,
            act_fecha_creacion,
            act_usuario_actualizacion,
            act_fecha_actualizacion,
            act_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @CLIENTE_INSTALACION,
            @INSTALACION_AREA,
            @ACTIVO_TIPO,
            @ACTIVO_MODELO,
            @ACTIVO_ESTADO,
            @ACTIVO_PADRE,
            @CENTRO_COSTO,
            @CRITICIDAD_NIVEL,
            @CODIGO,
            @NOMBRE,
            @NUMERO_SERIE,
            @FABRICANTE,
            @ANIO_FABRICACION,
            @FECHA_PUESTA_MARCHA,
            @DESCRIPCION,
            @REGISTRO_ORIGEN,
            @USUARIO,
            @DATE_NOW,
            @USUARIO,
            @DATE_NOW,
            1
        )

    DECLARE @FILAS_INS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()
    /* ---- CODIGO AUTOMATICO ----
       El codigo depende del ID, y el ID no existe hasta esta linea.
       La ficha manda 'AUTO': ese valor satisface el NOT NULL, pasa
       por el INSERT y nunca queda guardado. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = 'AUTO')
        UPDATE [dbo].[Activo]
        SET    [act_codigo] = [dbo].[FNC_CODIGO_AUTOMATICO]('ACT', @ID)
        WHERE  [act_id] = @ID


    IF @FILAS_INS = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_ACTIVO @CLIENTE = ' + LTRIM(STR(@CLIENTE)) +
                                          ',@CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '4.- NO FUE POSIBLE INSERTAR EL ACTIVO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

PRINT '--- INS_ACTIVO corregido.'
GO

IF OBJECT_ID('dbo.INS_CENTRO_COSTO') IS NOT NULL DROP PROCEDURE [dbo].[INS_CENTRO_COSTO]
GO


/* ########################################################################
   HU-013 - CENTRO_COSTO
   ######################################################################## */

CREATE PROCEDURE [dbo].[INS_CENTRO_COSTO]
@ID                  INT = NULL OUTPUT,
@CLIENTE             INT,
@CENTRO_COSTO_PADRE  INT = NULL,
@CODIGO              NVARCHAR(100),
@NOMBRE              NVARCHAR(400),
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    -- Codigo unico por cliente (HU-013 escenario 2)
    IF EXISTS (SELECT 1 FROM [dbo].[Centro_Costo]
                WHERE cco_cliente = @CLIENTE AND cco_codigo = @CODIGO)
    BEGIN
        RAISERROR('1.- YA EXISTE UN CENTRO DE COSTO CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @CENTRO_COSTO_PADRE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Centro_Costo]
                        WHERE cco_id = @CENTRO_COSTO_PADRE AND cco_cliente = @CLIENTE)
    BEGIN
        RAISERROR('2.- EL CENTRO DE COSTO SUPERIOR NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Centro_Costo]
        (
            cco_cliente,
            cco_centro_costo_padre,
            cco_codigo,
            cco_nombre,
            cco_usuario_creacion,
            cco_fecha_creacion,
            cco_usuario_actualizacion,
            cco_fecha_actualizacion,
            cco_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @CENTRO_COSTO_PADRE,
            @CODIGO,
            @NOMBRE,
            @USUARIO,
            @DATE_NOW,
            @USUARIO,
            @DATE_NOW,
            1
        )

    DECLARE @FILAS_INS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()
    /* ---- CODIGO AUTOMATICO ----
       El codigo depende del ID, y el ID no existe hasta esta linea.
       La ficha manda 'AUTO': ese valor satisface el NOT NULL, pasa
       por el INSERT y nunca queda guardado. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = 'AUTO')
        UPDATE [dbo].[Centro_Costo]
        SET    [cco_codigo] = [dbo].[FNC_CODIGO_AUTOMATICO]('CCO', @ID)
        WHERE  [cco_id] = @ID


    IF @FILAS_INS = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_CENTRO_COSTO @CLIENTE = ' + LTRIM(STR(@CLIENTE)) +
                                          ',@CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE INSERTAR EL CENTRO DE COSTO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

PRINT '--- INS_CENTRO_COSTO corregido.'
GO

IF OBJECT_ID('dbo.INS_CLIENTE_INSTALACION') IS NOT NULL DROP PROCEDURE [dbo].[INS_CLIENTE_INSTALACION]
GO


/* ========================================================================
   7. LA GUARDA EN LAS PLANTAS                                       HU-193
   ======================================================================== */

CREATE PROCEDURE [dbo].[INS_CLIENTE_INSTALACION]
@ID            INT = NULL OUTPUT,
@CLIENTE       INT = NULL,
@NOMBRE        VARCHAR(200),
@DESCRIPCION   VARCHAR(200) = NULL,
@DIRECCION     VARCHAR(200) = NULL,
@CODIGO        NVARCHAR(100) = NULL,
@ZONA_HORARIA  INT = NULL,
@LATITUD       DECIMAL(9,6) = NULL,
@LONGITUD      DECIMAL(9,6) = NULL,
@HABILITADO    BIT,
@USUARIO       INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
DECLARE @TOPE DECIMAL(18,2), @MENSAJE NVARCHAR(400)

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL
    SET @CODIGO = UPPER(REPLACE(LTRIM(RTRIM(@CODIGO)), ' ', ''))

BEGIN
    /* HU-193. El tope del plan, antes de crear.
       El mensaje dice cuantas tiene y cuantas permite: "no puede crear mas
       plantas" sin el numero obliga a ir a buscarlo. */
    IF [dbo].[FNC_CLIENTE_PUEDE_CREAR](@CLIENTE, N'LIMITE PLANTAS') = 0
    BEGIN
        SET @TOPE = [dbo].[FNC_CLIENTE_LIMITE](@CLIENTE, N'LIMITE PLANTAS')
        SET @MENSAJE = N'1.- EL PLAN CONTRATADO PERMITE ' + LTRIM(STR(CAST(ISNULL(@TOPE,0) AS INT))) +
                       N' PLANTA(S) Y YA HAY ' +
                       LTRIM(STR(CAST([dbo].[FNC_CLIENTE_CONSUMO](@CLIENTE, N'LIMITE PLANTAS') AS INT))) +
                       N'. DESHABILITE UNA O CAMBIE DE PLAN.'
        RAISERROR(@MENSAJE, 16, 1)
        RETURN -1
    END

    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                    WHERE cin_cliente = @CLIENTE AND cin_codigo = @CODIGO)
    BEGIN
        RAISERROR('2.- YA EXISTE UNA PLANTA CON EL CÓDIGO "%s" EN ESTE CLIENTE.', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @LATITUD IS NOT NULL AND (@LATITUD < -90 OR @LATITUD > 90)
    BEGIN
        RAISERROR('3.- LA LATITUD DEBE ESTAR ENTRE -90 Y 90.', 16, 1)
        RETURN -1
    END

    IF @LONGITUD IS NOT NULL AND (@LONGITUD < -180 OR @LONGITUD > 180)
    BEGIN
        RAISERROR('4.- LA LONGITUD DEBE ESTAR ENTRE -180 Y 180.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Cliente_Instalacion]
        (cin_cliente, cin_nombre, cin_descripcion, cin_direccion, cin_codigo,
         cin_zona_horaria, cin_latitud, cin_longitud, cin_habilitado,
         cin_usuario_creacion, cin_fecha_creacion,
         cin_usuario_actualizacion, cin_fecha_actualizacion)
    VALUES
        (@CLIENTE, @NOMBRE, @DESCRIPCION, @DIRECCION, @CODIGO,
         @ZONA_HORARIA, @LATITUD, @LONGITUD, @HABILITADO,
         @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW)

    DECLARE @FILAS_INS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()
    /* ---- CODIGO AUTOMATICO ----
       El codigo depende del ID, y el ID no existe hasta esta linea.
       La ficha manda 'AUTO': ese valor satisface el NOT NULL, pasa
       por el INSERT y nunca queda guardado. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = 'AUTO')
        UPDATE [dbo].[Cliente_Instalacion]
        SET    [cin_codigo] = [dbo].[FNC_CODIGO_AUTOMATICO]('PLA', @ID)
        WHERE  [cin_id] = @ID


    IF @FILAS_INS = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_CLIENTE_INSTALACION ' + ISNULL(@NOMBRE, '')
        EXEC [dbo].[INS_EXCEPCION] @MSG = '5.- NO FUE POSIBLE INSERTAR LA PLANTA.', @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

PRINT '--- INS_CLIENTE_INSTALACION corregido.'
GO

IF OBJECT_ID('dbo.INS_ESPECIALIDAD') IS NOT NULL DROP PROCEDURE [dbo].[INS_ESPECIALIDAD]
GO


/* ########################################################################
   HU-017 - ESPECIALIDAD (catalogo ampliable del cliente)
   ######################################################################## */

/* ========================================================================
   INS_ESPECIALIDAD

   esp_cliente NULL = especialidad del sistema, visible para todos.
   esp_cliente informado = especialidad propia de ese cliente.
   Es el mismo mecanismo de HU-021 para los catalogos ampliables.
   ======================================================================== */
CREATE PROCEDURE [dbo].[INS_ESPECIALIDAD]
@ID       INT = NULL OUTPUT,
@CLIENTE  INT = NULL,
@CODIGO   NVARCHAR(100),
@NOMBRE   NVARCHAR(200),
@ORDEN    INT = NULL,
@USUARIO  INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    /* Unico por cliente. El indice UX_ESP_CLIENTE_CODIGO ya lo garantiza,
       pero se comprueba aqui para devolver un mensaje legible en vez del
       error 2601 de SQL Server. */
    IF EXISTS (SELECT 1 FROM [dbo].[Especialidad]
                WHERE esp_codigo = @CODIGO
                  AND ISNULL(esp_cliente, 0) = ISNULL(@CLIENTE, 0))
    BEGIN
        RAISERROR('1.- YA EXISTE UNA ESPECIALIDAD CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    /* Tampoco puede chocar con una del sistema: el usuario final las ve
       juntas en la misma lista y dos "MEC" serian indistinguibles. */
    IF @CLIENTE IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Especialidad]
                    WHERE esp_codigo = @CODIGO AND esp_cliente IS NULL)
    BEGIN
        RAISERROR('2.- YA EXISTE UNA ESPECIALIDAD DEL SISTEMA CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Especialidad]
        (
            esp_cliente,
            esp_codigo,
            esp_nombre,
            esp_orden,
            esp_usuario_creacion,
            esp_fecha_creacion,
            esp_usuario_actualizacion,
            esp_fecha_actualizacion,
            esp_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @CODIGO,
            @NOMBRE,
            @ORDEN,
            @USUARIO,
            @DATE_NOW,
            @USUARIO,
            @DATE_NOW,
            1
        )

    DECLARE @FILAS_INS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()
    /* ---- CODIGO AUTOMATICO ----
       El codigo depende del ID, y el ID no existe hasta esta linea.
       La ficha manda 'AUTO': ese valor satisface el NOT NULL, pasa
       por el INSERT y nunca queda guardado. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = 'AUTO')
        UPDATE [dbo].[Especialidad]
        SET    [esp_codigo] = [dbo].[FNC_CODIGO_AUTOMATICO]('ESP', @ID)
        WHERE  [esp_id] = @ID


    IF @FILAS_INS = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_ESPECIALIDAD @CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE INSERTAR LA ESPECIALIDAD.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

PRINT '--- INS_ESPECIALIDAD corregido.'
GO

IF OBJECT_ID('dbo.INS_GRUPO_TRABAJO') IS NOT NULL DROP PROCEDURE [dbo].[INS_GRUPO_TRABAJO]
GO


/* ########################################################################
   HU-016 - GRUPO_TRABAJO
   ######################################################################## */

CREATE PROCEDURE [dbo].[INS_GRUPO_TRABAJO]
@ID                   INT = NULL OUTPUT,
@CLIENTE              INT,
@CLIENTE_INSTALACION  INT = NULL,
@CODIGO               NVARCHAR(100),
@NOMBRE               NVARCHAR(400),
@ESPECIALIDAD         INT = NULL,
@DESCRIPCION          NVARCHAR(1000) = NULL,
@USUARIO              INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    IF EXISTS (SELECT 1 FROM [dbo].[Grupo_Trabajo]
                WHERE gtr_cliente = @CLIENTE AND gtr_codigo = @CODIGO)
    BEGIN
        RAISERROR('1.- YA EXISTE UN GRUPO CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    /* La planta es opcional: vacia significa grupo transversal al cliente.
       Pero si viene, tiene que ser del cliente. */
    IF @CLIENTE_INSTALACION IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                        WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('2.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF @ESPECIALIDAD IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Especialidad]
                        WHERE esp_id = @ESPECIALIDAD
                          AND (esp_cliente IS NULL OR esp_cliente = @CLIENTE))
    BEGIN
        RAISERROR('3.- LA ESPECIALIDAD NO ESTÁ DISPONIBLE PARA ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Grupo_Trabajo]
        (
            gtr_cliente,
            gtr_cliente_instalacion,
            gtr_codigo,
            gtr_nombre,
            gtr_especialidad,
            gtr_descripcion,
            gtr_usuario_creacion,
            gtr_fecha_creacion,
            gtr_usuario_actualizacion,
            gtr_fecha_actualizacion,
            gtr_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @CLIENTE_INSTALACION,
            @CODIGO,
            @NOMBRE,
            @ESPECIALIDAD,
            @DESCRIPCION,
            @USUARIO,
            @DATE_NOW,
            @USUARIO,
            @DATE_NOW,
            1
        )

    DECLARE @FILAS_INS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()
    /* ---- CODIGO AUTOMATICO ----
       El codigo depende del ID, y el ID no existe hasta esta linea.
       La ficha manda 'AUTO': ese valor satisface el NOT NULL, pasa
       por el INSERT y nunca queda guardado. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = 'AUTO')
        UPDATE [dbo].[Grupo_Trabajo]
        SET    [gtr_codigo] = [dbo].[FNC_CODIGO_AUTOMATICO]('GRU', @ID)
        WHERE  [gtr_id] = @ID


    IF @FILAS_INS = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_GRUPO_TRABAJO @CLIENTE = ' + LTRIM(STR(@CLIENTE)) +
                                          ',@CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '4.- NO FUE POSIBLE INSERTAR EL GRUPO DE TRABAJO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

PRINT '--- INS_GRUPO_TRABAJO corregido.'
GO

IF OBJECT_ID('dbo.INS_INSTALACION_AREA') IS NOT NULL DROP PROCEDURE [dbo].[INS_INSTALACION_AREA]
GO


/* ########################################################################
   HU-012 - INSTALACION_AREA
   ######################################################################## */

/* ========================================================================
   INS_INSTALACION_AREA
   ======================================================================== */
CREATE PROCEDURE [dbo].[INS_INSTALACION_AREA]
@ID                     INT = NULL OUTPUT,
@CLIENTE                INT,
@CLIENTE_INSTALACION    INT,
@AREA_PADRE             INT = NULL,
@INSTALACION_AREA_TIPO  INT = NULL,
@CODIGO                 NVARCHAR(100),
@NOMBRE                 NVARCHAR(400),
@DESCRIPCION            NVARCHAR(1000) = NULL,
@USUARIO                INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

/* El codigo viaja en mayusculas y sin espacios, como pide la HU. Se
   normaliza aqui y no solo en la pantalla: la API tambien va a insertar. */
SET @CODIGO = UPPER(REPLACE(LTRIM(RTRIM(@CODIGO)), ' ', ''))

BEGIN
    -- 1. La planta debe ser del cliente
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                    WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- 2. Codigo unico dentro de la planta
    IF EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area]
                WHERE iar_cliente_instalacion = @CLIENTE_INSTALACION AND iar_codigo = @CODIGO)
    BEGIN
        RAISERROR('2.- YA EXISTE UN ÁREA CON EL CÓDIGO "%s" EN ESTA PLANTA.', 16, 1, @CODIGO)
        RETURN -1
    END

    -- 3. El area superior debe estar en la misma planta
    IF @AREA_PADRE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area]
                        WHERE iar_id = @AREA_PADRE AND iar_cliente_instalacion = @CLIENTE_INSTALACION)
    BEGIN
        RAISERROR('3.- EL ÁREA SUPERIOR NO PERTENECE A ESTA PLANTA.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Instalacion_Area]
        (
            iar_cliente,
            iar_cliente_instalacion,
            iar_area_padre,
            iar_instalacion_area_tipo,
            iar_codigo,
            iar_nombre,
            iar_descripcion,
            iar_usuario_creacion,
            iar_fecha_creacion,
            iar_usuario_actualizacion,
            iar_fecha_actualizacion,
            iar_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @CLIENTE_INSTALACION,
            @AREA_PADRE,
            @INSTALACION_AREA_TIPO,
            @CODIGO,
            @NOMBRE,
            @DESCRIPCION,
            @USUARIO,
            @DATE_NOW,
            @USUARIO,
            @DATE_NOW,
            1
        )

    DECLARE @FILAS_INS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()
    /* ---- CODIGO AUTOMATICO ----
       El codigo depende del ID, y el ID no existe hasta esta linea.
       La ficha manda 'AUTO': ese valor satisface el NOT NULL, pasa
       por el INSERT y nunca queda guardado. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = 'AUTO')
        UPDATE [dbo].[Instalacion_Area]
        SET    [iar_codigo] = [dbo].[FNC_CODIGO_AUTOMATICO]('ARE', @ID)
        WHERE  [iar_id] = @ID


    IF @FILAS_INS = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_INSTALACION_AREA ' +
              '@CLIENTE_INSTALACION = ' + LTRIM(STR(@CLIENTE_INSTALACION)) + ',' +
              '@CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '4.- NO FUE POSIBLE INSERTAR EL ÁREA.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

PRINT '--- INS_INSTALACION_AREA corregido.'
GO

IF OBJECT_ID('dbo.INS_PLAN_COMERCIAL') IS NOT NULL DROP PROCEDURE [dbo].[INS_PLAN_COMERCIAL]
GO


/* ========================================================================
   1. INS_PLAN_COMERCIAL

      El plan nace SIN precio. Es deliberado: un plan sin fila en
      Plan_Comercial_Precio simplemente no se vende -asi lo definio el
      modelo, la ausencia de precio es la regla- y eso permite dejarlo
      preparado mientras se acuerda cuanto va a costar.
   ======================================================================== */

CREATE PROCEDURE [dbo].[INS_PLAN_COMERCIAL]
@ID           INT = NULL OUTPUT,
@CODIGO       NVARCHAR(50),
@NOMBRE       NVARCHAR(100),
@DESCRIPCION  NVARCHAR(500) = NULL,
@ORDEN        INT,
@DIAS_GRACIA  INT = 5,
@PUBLICO      BIT = 1,
@USUARIO      INT

AS
SET NOCOUNT ON

BEGIN
    IF @CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0
    BEGIN
        RAISERROR('1.- EL CÓDIGO DEL PLAN ES OBLIGATORIO.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial]
                WHERE plc_codigo = @CODIGO COLLATE DATABASE_DEFAULT)
    BEGIN
        RAISERROR('2.- YA EXISTE UN PLAN CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    /* El orden decide que es subir y que es bajar de plan (8). Dos planes
       con el mismo orden dejan a UPS_SUSCRIPCION_PLAN sin criterio: la
       comparacion da falso en ambos sentidos y todo cambio entre ellos se
       trata como downgrade, sin que nadie entienda por que. */
    IF @ORDEN IS NULL
    BEGIN
        RAISERROR('3.- EL ORDEN ES OBLIGATORIO: DEFINE QUÉ ES SUBIR Y QUÉ ES BAJAR DE PLAN.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE plc_orden = @ORDEN)
    BEGIN
        RAISERROR('4.- YA HAY UN PLAN CON EL ORDEN %d. EL ORDEN DEBE SER ÚNICO.', 16, 1, @ORDEN)
        RETURN -1
    END

    IF @DIAS_GRACIA IS NULL OR @DIAS_GRACIA < 0
    BEGIN
        RAISERROR('5.- LOS DÍAS DE GRACIA NO PUEDEN SER NEGATIVOS.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Plan_Comercial]
        (plc_codigo, plc_nombre, plc_descripcion, plc_orden, plc_dias_gracia, plc_publico,
         plc_usuario_creacion, plc_fecha_creacion,
         plc_usuario_actualizacion, plc_fecha_actualizacion, plc_habilitado)
    VALUES
        (@CODIGO, @NOMBRE, @DESCRIPCION, @ORDEN, @DIAS_GRACIA, @PUBLICO,
         @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)

    DECLARE @FILAS_INS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()
    /* ---- CODIGO AUTOMATICO ----
       El codigo depende del ID, y el ID no existe hasta esta linea.
       La ficha manda 'AUTO': ese valor satisface el NOT NULL, pasa
       por el INSERT y nunca queda guardado. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = 'AUTO')
        UPDATE [dbo].[Plan_Comercial]
        SET    [plc_codigo] = [dbo].[FNC_CODIGO_AUTOMATICO]('PLC', @ID)
        WHERE  [plc_id] = @ID


    IF @FILAS_INS = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_PLAN_COMERCIAL @CODIGO = ' + ISNULL(@CODIGO, '')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '6.- NO FUE POSIBLE CREAR EL PLAN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

PRINT '--- INS_PLAN_COMERCIAL corregido.'
GO

PRINT '89_ROWCOUNT_CODIGO_AUTOMATICO aplicado: 7 procedimientos.'
GO
