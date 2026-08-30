USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     EP-02. USUARIOS DEL CLIENTE Y PERFILES. HU-014 Y HU-015.
-- =============================================
-- Va DESPUES de 29_SPRINT1_CLIENTE_PLANTA.
--
-- QUE CUBRE
--   HU-014  Usuarios del cliente: RUT valido, correo unico, perfil y AL
--           MENOS UNA PLANTA, con vigencia.
--   HU-015  Perfiles del cliente y sus permisos, con las tres reglas de
--           sus escenarios.
--
-- UN HUECO DE MODELO QUE HABIA QUE CERRAR
--   HU-015 habla de "perfiles del cliente" y de nombre "unico por cliente",
--   pero la tabla Perfiles no tenia a que cliente pertenece cada perfil:
--   solo per_tipo (1 Sistema / 2 Cliente). Con eso, dos clientes distintos
--   no podian tener cada uno su perfil "Supervisor", y el de uno lo veia el
--   otro. Se agrega per_cliente con la misma convencion que ya usa el resto
--   del modelo: NULL = perfil del sistema, informado = propio del cliente.
--
-- UN RIESGO QUE INTRODUJO EL HASH
--   UPD_USUARIO escribia USU_PASSWORD = @PASSWORD SIEMPRE, y el mantenedor
--   de usuarios manda ese parametro en cada guardado. Con las contrasenas
--   ya en hash (bloque 26), guardar la ficha de un usuario le habria
--   sobrescrito el hash con lo que trajera el formulario -y si el campo va
--   vacio, se la habria borrado-. Ahora la contrasena solo se toca cuando
--   viene informada, y en ese caso se guarda hasheada.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. Perfiles: dueno y facultad de cierre
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Perfiles]') AND name = 'per_cliente')
BEGIN
    ALTER TABLE [dbo].[Perfiles] ADD [per_cliente] INT NULL
    PRINT 'Columna per_cliente agregada a Perfiles.'
END
ELSE PRINT 'Columna per_cliente ya existe en Perfiles.'
GO

/* HU-015 escenario 3: hay perfiles que ejecutan pero no cierran.

   Se resuelve con una BANDERA y no comparando el nombre del perfil con la
   cadena "Tecnico de mantenimiento". El cliente que llame distinto a sus
   cargos -y cada planta los llama distinto- seguiria necesitando la misma
   regla. Es la misma decision que ya toma FNC_USUARIO_PUEDE_CERRAR_OT, que
   pregunta por permiso y no por nombre de perfil. */
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Perfiles]') AND name = 'per_solo_ejecucion')
BEGIN
    ALTER TABLE [dbo].[Perfiles]
        ADD [per_solo_ejecucion] BIT NOT NULL CONSTRAINT DF_PER_SOLO_EJECUCION DEFAULT 0
    PRINT 'Columna per_solo_ejecucion agregada a Perfiles.'
END
ELSE PRINT 'Columna per_solo_ejecucion ya existe en Perfiles.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_PER_CLIENTE')
    ALTER TABLE [dbo].[Perfiles] WITH CHECK ADD CONSTRAINT FK_PER_CLIENTE
        FOREIGN KEY ([per_cliente]) REFERENCES [dbo].[Cliente] ([cli_id])
GO

/* Nombre unico por cliente. Un UNIQUE normal trata todos los NULL como
   iguales, que es justo lo que se quiere aqui: dos perfiles del SISTEMA
   (ambos con per_cliente NULL) tampoco pueden llamarse igual. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_PER_CLIENTE_NOMBRE' AND object_id = OBJECT_ID(N'[dbo].[Perfiles]'))
BEGIN
    IF EXISTS (SELECT per_nombre FROM [dbo].[Perfiles]
               GROUP BY per_cliente, per_nombre HAVING COUNT(*) > 1)
        PRINT 'AVISO: hay perfiles con nombre duplicado. UX_PER_CLIENTE_NOMBRE no se creo. Depurar antes.'
    ELSE
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX UX_PER_CLIENTE_NOMBRE
            ON [dbo].[Perfiles] ([per_cliente], [per_nombre])
        PRINT 'Indice UX_PER_CLIENTE_NOMBRE creado.'
    END
END
ELSE PRINT 'Indice UX_PER_CLIENTE_NOMBRE ya existe.'
GO


/* ========================================================================
   2. INS_PERFIL                                                    HU-015
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_PERFIL]
@ID               INT = NULL OUTPUT,
@NOMBRE           VARCHAR(200),
@DESCRIPCION      VARCHAR(8000) = NULL,
@TIPO             INT,
@CLIENTE          INT = NULL,
@SOLO_EJECUCION   BIT = 0,
@HABILITADO       BIT,
@USUARIO          INT

AS
SET NOCOUNT ON

BEGIN
    /* Antes el nombre era unico en TODA la base. Con multicliente eso
       impedia que dos empresas tuvieran cada una su "Supervisor". Ahora la
       unicidad es dentro del mismo dueno. */
    IF EXISTS (SELECT 1 FROM [dbo].[Perfiles]
                WHERE per_nombre = @NOMBRE
                  AND ISNULL(per_cliente, 0) = ISNULL(@CLIENTE, 0))
    BEGIN
        RAISERROR('1.- El perfil con el nombre "%s" ya existe.', 16, 1, @NOMBRE)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Perfiles]
        (
            per_nombre,
            per_descripcion,
            per_tipo,
            per_cliente,
            per_solo_ejecucion,
            per_habilitado,
            per_usuario_creacion,
            per_fecha_creacion,
            per_usuario_act,
            per_fecha_act
        )
    VALUES
        (
            @NOMBRE,
            @DESCRIPCION,
            @TIPO,
            @CLIENTE,
            @SOLO_EJECUCION,
            @HABILITADO,
            @USUARIO,
            GETDATE(),
            @USUARIO,
            GETDATE()
        )

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'INS_PERFIL ' + ISNULL(@NOMBRE, '')

        EXEC [dbo].[INS_EXCEPCION]
            @MSG = '2.- NO FUE POSIBLE CREAR EL PERFIL.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   3. UPD_PERFIL                                                    HU-015
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_PERFIL]
@ID               INT,
@NOMBRE           VARCHAR(200),
@TIPO             INT,
@DESCRIPCION      VARCHAR(8000) = NULL,
@CLIENTE          INT = NULL,
@SOLO_EJECUCION   BIT = NULL,
@HABILITADO       BIT,
@USUARIO          INT

AS
SET NOCOUNT ON

BEGIN
    IF EXISTS (SELECT 1 FROM [dbo].[Perfiles]
                WHERE per_nombre = @NOMBRE
                  AND ISNULL(per_cliente, 0) = ISNULL(@CLIENTE, 0)
                  AND per_id <> @ID)
    BEGIN
        RAISERROR('1.- El perfil con el nombre "%s" ya existe.', 16, 1, @NOMBRE)
        RETURN -1
    END

    /* Marcar un perfil como "solo ejecucion" cuando ya tiene el permiso de
       cerrar OT dejaria un estado contradictorio: la bandera diria que no
       puede y Perfil_Permiso diria que si. Se obliga a quitar el permiso
       primero, para que el cambio sea explicito y quede a la vista. */
    IF @SOLO_EJECUCION = 1
       AND EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                   INNER JOIN [dbo].[Permiso] p ON p.prm_id = pp.ppe_permiso
                   WHERE pp.ppe_perfil = @ID AND p.prm_codigo = N'CERRAR OT')
    BEGIN
        RAISERROR('2.- ESTE PERFIL TIENE EL PERMISO DE CERRAR ÓRDENES. QUÍTESELO ANTES DE MARCARLO COMO SÓLO EJECUCIÓN.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Perfiles]
    SET     per_nombre         = @NOMBRE,
            per_tipo           = @TIPO,
            per_descripcion    = @DESCRIPCION,
            per_cliente        = @CLIENTE,
            per_solo_ejecucion = ISNULL(@SOLO_EJECUCION, per_solo_ejecucion),
            per_habilitado     = @HABILITADO,
            per_usuario_act    = @USUARIO,
            per_fecha_act      = GETDATE()
    WHERE   per_id = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'UPD_PERFIL ' + LTRIM(STR(@ID)) + ',' + ISNULL(@NOMBRE, '')

        EXEC [dbo].[INS_EXCEPCION]
            @MSG = '3.- NO FUE POSIBLE ACTUALIZAR EL PERFIL.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   4. SEL_PERFILES                                                  HU-015

      USUARIOS cuenta cuantas personas tienen el perfil. Es lo que el
      escenario 2 necesita mostrar cuando se intenta eliminar uno en uso,
      y evita una consulta por fila en la grilla.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_PERFILES]
@ID          INT = NULL,
@FILTRO      VARCHAR(1000) = NULL,
@HABILITADO  BIT = NULL,
@TIPO        INT = NULL,
@PERFILES    VARCHAR(200) = NULL,
@CLIENTE     INT = NULL,
@SOLO_CLIENTE BIT = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)

    SET @SELECT = 'SELECT   PER_ID
                            ,PER_NOMBRE
                            ,PER_TIPO
                            ,PER_DESCRIPCION
                            ,PER_CLIENTE
                            ,PER_SOLO_EJECUCION
                            ,PER_HABILITADO
                            ,(CASE  WHEN PER_TIPO = 1 THEN
                                    ''Sistema''
                                WHEN PER_TIPO = 2 THEN
                                    ''Cliente''
                            END)                                [TIPO]
                            ,(CASE WHEN PER_CLIENTE IS NULL THEN ''Sistema''
                                   ELSE ''Propio'' END)         [ORIGEN]
                            ,(SELECT COUNT(*) FROM CLIENTE_USUARIO_PERFIL
                               WHERE CUP_ID_PERFIL = PER_ID)    [USUARIOS]
                  '
END
--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)

    SET @FROM = ' FROM  PERFILES
                '
END
--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1 = 1'

    IF(@ID IS NOT NULL)BEGIN
        SET @WHERE = @WHERE +  ' AND PER_ID = ' + LTRIM(@ID)
    END

    IF(@FILTRO IS NOT NULL)BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE +  ' AND (PER_NOMBRE LIKE ''%' + @FILTRO + '%''
                                   OR PER_DESCRIPCION LIKE ''%' + @FILTRO + '%'')
                                '
    END
    IF(@HABILITADO IS NOT NULL)BEGIN
        SET @WHERE = @WHERE +  ' AND PER_HABILITADO = ' + LTRIM(@HABILITADO)
    END
    IF(@TIPO IS NOT NULL)BEGIN
        SET @WHERE = @WHERE +  ' AND PER_TIPO = ' + LTRIM(@TIPO)
    END

    IF(@PERFILES IS NOT NULL)BEGIN
        SET @WHERE = @WHERE + ' AND PER_ID IN(' + @PERFILES + ')'
    END

    /* Sin @CLIENTE se ven todos, que es lo que necesita el mantenedor de
       plataforma. Con @CLIENTE se ven los del sistema mas los propios, que
       es lo que necesita el administrador de un cliente. */
    IF(@CLIENTE IS NOT NULL)BEGIN
        IF(@SOLO_CLIENTE = 1)
            SET @WHERE = @WHERE + ' AND PER_CLIENTE = ' + LTRIM(@CLIENTE)
        ELSE
            SET @WHERE = @WHERE + ' AND (PER_CLIENTE IS NULL OR PER_CLIENTE = ' + LTRIM(@CLIENTE) + ')'
    END

END

--ORDER BY
BEGIN
    DECLARE @ORDER_BY VARCHAR(MAX)
    SET @ORDER_BY = ' ORDER BY PER_ID ASC '
END

--PRINT(@SELECT + @FROM + @WHERE + @ORDER_BY)
EXEC(@SELECT + @FROM + @WHERE + @ORDER_BY)
GO


/* ========================================================================
   5. DEL_PERFILES                                                  HU-015

      Dos correcciones sobre la version anterior:

      a) La comprobacion de usuarios asociados hacia
             INNER JOIN CLIENTE_USUARIO_PERFIL ON UPE_ID = CUP_ID_PERFIL
         que une el id de la FILA de Usuario_Perfil con un id de PERFIL. Son
         cosas distintas y la comparacion daba resultados arbitrarios: podia
         dejar borrar un perfil en uso o impedir borrar uno libre.

      b) Bloqueaba el borrado si el perfil aparecia en MENU_PERFIL. Esa tabla
         quedo fuera de uso en el bloque 06, cuando los permisos pasaron a
         Perfil_Permiso. Un perfil con filas viejas ahi no se podia eliminar
         nunca, sin motivo real.

      Y se agrega lo que pide el escenario 2: decir CUANTOS usuarios lo
      tienen, no solo que los tiene.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_PERFILES]
@ID       INT,
@USUARIO  INT,
@PAIS     VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

DECLARE @USUARIOS INT
DECLARE @MENSAJE  NVARCHAR(500)

BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Perfiles] WHERE per_id = @ID)
    BEGIN
        RAISERROR('1.- EL PERFIL NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @ID = 1
    BEGIN
        RAISERROR('2.- NO SE PUEDE ELIMINAR EL PERFIL ROOT.', 16, 1)
        RETURN -1
    END

    SELECT @USUARIOS =
           (SELECT COUNT(*) FROM [dbo].[Cliente_Usuario_Perfil] WHERE cup_id_perfil = @ID)
         + (SELECT COUNT(*) FROM [dbo].[Usuario_Perfil]         WHERE upe_perfil    = @ID)

    IF @USUARIOS > 0
    BEGIN
        SET @MENSAJE = N'3.- NO PUEDE ELIMINAR EL PERFIL: LO TIENEN ' +
                       LTRIM(STR(@USUARIOS)) + N' USUARIO(S). QUÍTESELO PRIMERO.'
        RAISERROR(@MENSAJE, 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    -- Los permisos del perfil se van con el perfil
    DELETE  [dbo].[Perfil_Permiso]
    WHERE   ppe_perfil = @ID

    DELETE  [dbo].[Perfiles]
    WHERE   per_id = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'DEL_PERFILES ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @MSG = '4.- NO FUE POSIBLE ELIMINAR EL PERFIL.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   6. UPS_PERFIL_PERMISO                                            HU-015

      Se agrega el escenario 3: a un perfil marcado como solo ejecucion no
      se le puede activar el permiso de cerrar ordenes, y el mensaje explica
      a quien corresponde esa facultad.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPS_PERFIL_PERMISO]
    @PERFIL   INT,
    @MENU     INT = 0,
    @FUNCION  INT = 0,
    @OTORGADO BIT,
    @USUARIO  INT
AS
SET NOCOUNT ON

    DECLARE @PERMISO INT
    DECLARE @CODIGO  NVARCHAR(200)

    IF @FUNCION > 0
        SELECT @PERMISO = mfu_permiso FROM [dbo].[Menu_Funcion] WHERE mfu_id = @FUNCION
    ELSE
        SELECT @PERMISO = mnu_permiso FROM [dbo].[Menus] WHERE mnu_id = @MENU

    IF @PERMISO IS NULL
    BEGIN
        RAISERROR('1.- ESE MENU O FUNCION NO TIENE UN PERMISO ASOCIADO. Asignelo en el mantenedor de menus.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Perfiles] WHERE per_id = @PERFIL)
    BEGIN
        RAISERROR('2.- EL PERFIL NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @OTORGADO = 1
    BEGIN
        SELECT @CODIGO = prm_codigo FROM [dbo].[Permiso] WHERE prm_id = @PERMISO

        /* HU-015 escenario 3. El tecnico finaliza la orden; cerrarla es de
           jefatura, supervision o planificacion. */
        IF @CODIGO = N'CERRAR OT'
           AND EXISTS (SELECT 1 FROM [dbo].[Perfiles]
                        WHERE per_id = @PERFIL AND per_solo_ejecucion = 1)
        BEGIN
            RAISERROR('4.- ESTE PERFIL SÓLO EJECUTA TRABAJO. CERRAR UNA ORDEN CORRESPONDE A JEFATURA, SUPERVISIÓN O PLANIFICACIÓN.', 16, 1)
            RETURN -1
        END

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso]
                        WHERE ppe_perfil = @PERFIL AND ppe_permiso = @PERMISO)
            INSERT INTO [dbo].[Perfil_Permiso] ([ppe_perfil],[ppe_permiso],[ppe_usuario_creacion])
            VALUES (@PERFIL, @PERMISO, @USUARIO)
    END
    ELSE
    BEGIN
        -- Root no se puede quedar sin permisos: seria perder el acceso.
        IF @PERFIL = 1
        BEGIN
            RAISERROR('3.- NO SE PUEDEN QUITAR PERMISOS AL PERFIL ROOT.', 16, 1)
            RETURN -1
        END

        DELETE FROM [dbo].[Perfil_Permiso]
         WHERE ppe_perfil = @PERFIL AND ppe_permiso = @PERMISO
    END

RETURN 0
GO


/* ========================================================================
   7. INS_USUARIO                                                   HU-014

      Se agrega la validacion del digito verificador (solo para clientes
      chilenos) y la contrasena entra hasheada desde el primer dia.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_USUARIO]
@ID                INT = NULL OUTPUT,
@IDENTIFICADOR     VARCHAR(100),
@CLIENTE           INT = NULL,
@LOGIN             VARCHAR(100),
@PASSWORD          VARCHAR(100),
@NOMBRES           VARCHAR(200),
@APELLIDO_PATERNO  VARCHAR(100),
@APELLIDO_MATERNO  VARCHAR(100) = NULL,
@FONO1             VARCHAR(50) = NULL,
@CORREO            VARCHAR(200),
@FOTO              VARBINARY(MAX) = NULL,
@EXTENSION         VARCHAR(10) = NULL,
@IDIOMA            INT = NULL,
@USUARIO           INT,
@HABILITADO        BIT

AS
SET NOCOUNT ON

DECLARE @PAIS_CHILE INT
DECLARE @PAIS_CLIENTE INT
DECLARE @SALT VARCHAR(50) = REPLACE(CONVERT(VARCHAR(50), NEWID()), '-', '')

SELECT @PAIS_CHILE = pai_id FROM [dbo].[Paises] WHERE pai_nombre = 'Chile'

IF @CLIENTE IS NOT NULL
    SELECT @PAIS_CLIENTE = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE

--VALIDACIONES
BEGIN
    IF EXISTS(SELECT 1 FROM [dbo].[Usuario] WHERE usu_identificador = LTRIM(RTRIM(@IDENTIFICADOR)))
    BEGIN
        RAISERROR('1. Ya existe un usuario registrado con el identificador indicado.', 16, 1)
        RETURN -1
    END

    IF EXISTS(SELECT 1 FROM [dbo].[Usuario] WHERE usu_login = LTRIM(RTRIM(@LOGIN)))
    BEGIN
        RAISERROR('2. Ya existe un usuario registrado con el login indicado.', 16, 1)
        RETURN -2
    END

    IF EXISTS(SELECT 1 FROM [dbo].[Usuario] WHERE usu_correo = LTRIM(RTRIM(@CORREO)))
    BEGIN
        RAISERROR('3. Ya existe un usuario registrado con el correo indicado.', 16, 1)
        RETURN -3
    END

    /* El digito verificador se exige solo cuando el cliente es chileno. En
       Peru, Argentina, Ecuador o Panama el identificador tiene otro formato
       y esta comprobacion lo rechazaria sin razon. */
    IF @PAIS_CLIENTE = @PAIS_CHILE AND [dbo].[FNC_RUT_VALIDO](@IDENTIFICADOR) = 0
    BEGIN
        RAISERROR('4. El RUT "%s" no es válido.', 16, 1, @IDENTIFICADOR)
        RETURN -4
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Usuario]
        (
            usu_identificador,
            usu_login,
            usu_password,
            usu_password_salt,
            usu_nombre,
            usu_apellido_paterno,
            usu_apellido_materno,
            usu_telefono,
            usu_correo,
            usu_idioma,
            usu_usuario_creacion,
            usu_fecha_creacion,
            usu_usuario_act,
            usu_fecha_act,
            usu_foto,
            usu_habilitado
        )
    VALUES
        (
            @IDENTIFICADOR,
            @LOGIN,
            [dbo].[FNC_PASSWORD_HASH](@PASSWORD, @SALT),
            @SALT,
            @NOMBRES,
            @APELLIDO_PATERNO,
            /* usu_apellido_materno es NOT NULL en la tabla. El parametro es
               opcional porque no todo el mundo lo tiene, asi que se guarda
               vacio en vez de NULL. */
            ISNULL(@APELLIDO_MATERNO, ''),
            @FONO1,
            @CORREO,
            @IDIOMA,
            @USUARIO,
            GETDATE(),
            @USUARIO,
            GETDATE(),
            @FOTO,
            @HABILITADO
        )

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'INS_USUARIO ' + ISNULL(@IDENTIFICADOR, '') + ',' + ISNULL(@LOGIN, '')

        EXEC [dbo].[INS_EXCEPCION]
            @MSG = '5.- NO FUE POSIBLE INSERTAR EL USUARIO.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

    -- El historial arranca con la contrasena inicial
    INSERT [dbo].[Usuario_Password_Historial]
        (uph_usuario, uph_password, uph_usuario_creacion, uph_fecha_creacion)
    VALUES
        (@ID, [dbo].[FNC_PASSWORD_HASH](@PASSWORD, @SALT), @USUARIO, GETDATE())

    IF(@FOTO IS NOT NULL)BEGIN
        INSERT INTO [dbo].[Usuario_Foto]
            (uft_usuario, uft_binario, uft_extension, uft_fecha_creacion)
        VALUES
            (@ID, @FOTO, @EXTENSION, GETDATE())
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   8. UPD_USUARIO                                                   HU-014

      LA CONTRASENA SOLO SE TOCA CUANDO VIENE INFORMADA. Ver la nota del
      encabezado: el mantenedor manda @PASSWORD en cada guardado, asi que
      escribirla siempre destruiria el hash del usuario.

      Se agrega ademas la validacion de unicidad de correo, RUT y login
      contra OTROS usuarios, que la version anterior no hacia en absoluto:
      se podia dejar a dos personas con el mismo correo editando la ficha.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_USUARIO]
@ID                INT,
@IDENTIFICADOR     VARCHAR(100),
@CLIENTE           INT = NULL,
@LOGIN             VARCHAR(200),
@PASSWORD          VARCHAR(100) = NULL,
@NOMBRES           VARCHAR(200),
@APELLIDO_PATERNO  VARCHAR(200),
@APELLIDO_MATERNO  VARCHAR(200) = NULL,
@FONO1             VARCHAR(50) = NULL,
@CORREO            VARCHAR(200),
@FOTO              VARBINARY(MAX) = NULL,
@EXTENSION         VARCHAR(10) = NULL,
@IDIOMA            INT = NULL,
@USUARIO           INT,
@HABILITADO        BIT

AS
SET NOCOUNT ON

DECLARE @PAIS_CHILE   INT
DECLARE @PAIS_CLIENTE INT
DECLARE @SALT         VARCHAR(50)
DECLARE @HASH_NUEVO   VARCHAR(500) = NULL

SELECT @PAIS_CHILE = pai_id FROM [dbo].[Paises] WHERE pai_nombre = 'Chile'

IF @CLIENTE IS NOT NULL
    SELECT @PAIS_CLIENTE = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE

--VALIDACIONES
BEGIN
    IF EXISTS(SELECT 1 FROM [dbo].[Usuario]
               WHERE usu_identificador = LTRIM(RTRIM(@IDENTIFICADOR)) AND usu_id <> @ID)
    BEGIN
        RAISERROR('1. Ya existe otro usuario registrado con el identificador indicado.', 16, 1)
        RETURN -1
    END

    IF EXISTS(SELECT 1 FROM [dbo].[Usuario]
               WHERE usu_login = LTRIM(RTRIM(@LOGIN)) AND usu_id <> @ID)
    BEGIN
        RAISERROR('2. Ya existe otro usuario registrado con el login indicado.', 16, 1)
        RETURN -2
    END

    IF EXISTS(SELECT 1 FROM [dbo].[Usuario]
               WHERE usu_correo = LTRIM(RTRIM(@CORREO)) AND usu_id <> @ID)
    BEGIN
        RAISERROR('3. Ya existe otro usuario registrado con el correo indicado.', 16, 1)
        RETURN -3
    END

    IF @PAIS_CLIENTE = @PAIS_CHILE AND [dbo].[FNC_RUT_VALIDO](@IDENTIFICADOR) = 0
    BEGIN
        RAISERROR('4. El RUT "%s" no es válido.', 16, 1, @IDENTIFICADOR)
        RETURN -4
    END
END

/* Solo si el formulario mando una contrasena se prepara el hash nuevo. */
IF @PASSWORD IS NOT NULL AND LTRIM(RTRIM(@PASSWORD)) <> ''
BEGIN
    SELECT @SALT = usu_password_salt FROM [dbo].[Usuario] WHERE usu_id = @ID

    IF @SALT IS NULL
        SET @SALT = REPLACE(CONVERT(VARCHAR(50), NEWID()), '-', '')

    SET @HASH_NUEVO = [dbo].[FNC_PASSWORD_HASH](@PASSWORD, @SALT)
END

BEGIN TRANSACTION

-- 1.- USUARIO
BEGIN
    UPDATE  [dbo].[Usuario]
    SET     usu_identificador    = @IDENTIFICADOR,
            usu_login            = @LOGIN,
            usu_password         = ISNULL(@HASH_NUEVO, usu_password),
            usu_password_salt    = CASE WHEN @HASH_NUEVO IS NULL THEN usu_password_salt ELSE @SALT END,
            usu_nombre           = @NOMBRES,
            usu_apellido_paterno = @APELLIDO_PATERNO,
            usu_apellido_materno = ISNULL(@APELLIDO_MATERNO, ''),
            usu_telefono         = @FONO1,
            usu_correo           = @CORREO,
            usu_idioma           = ISNULL(@IDIOMA, usu_idioma),
            usu_usuario_act      = @USUARIO,
            usu_fecha_act        = GETDATE(),
            /* La foto tampoco se borra por guardar la ficha sin adjuntar
               una nueva: antes se asignaba @FOTO siempre. */
            usu_foto             = CASE WHEN @FOTO IS NULL THEN usu_foto ELSE @FOTO END,
            usu_habilitado       = @HABILITADO
    WHERE   usu_id = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'UPD_USUARIO ' + LTRIM(STR(@ID)) + ',' + ISNULL(@LOGIN, '')

        EXEC [dbo].[INS_EXCEPCION]
            @MSG = '5.- NO FUE POSIBLE ACTUALIZAR EL USUARIO.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END
END

-- 2.- HISTORIAL DE CONTRASENA
IF @HASH_NUEVO IS NOT NULL
BEGIN
    INSERT [dbo].[Usuario_Password_Historial]
        (uph_usuario, uph_password, uph_usuario_creacion, uph_fecha_creacion)
    VALUES
        (@ID, @HASH_NUEVO, @USUARIO, GETDATE())
END

-- 3.- FOTOGRAFIA
BEGIN
    IF(@FOTO IS NOT NULL)BEGIN
        DELETE FROM [dbo].[Usuario_Foto] WHERE uft_usuario = @ID

        INSERT INTO [dbo].[Usuario_Foto]
            (uft_usuario, uft_binario, uft_extension, uft_fecha_creacion)
        VALUES
            (@ID, @FOTO, @EXTENSION, GETDATE())
    END
END

-- 4.- AL DESHABILITAR AL USUARIO SE DESHABILITAN SUS AFILIACIONES
BEGIN
    IF(@HABILITADO = 0) BEGIN
        UPDATE  [dbo].[Cliente_Usuario]
        SET     ucl_habilitado  = 0,
                ucl_usuario_act = @USUARIO,
                ucl_fecha_act   = GETDATE()
        WHERE   ucl_id_usuario = @ID
    END
END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   9. UPS_CLIENTE_USUARIO_PLANTA                                    HU-014

      "Debe asignar al menos una planta" (escenario 2) es una regla sobre el
      CONJUNTO de plantas, no sobre una fila. Un INS_ por planta no puede
      comprobarla: cada llamada individual es valida y solo el resultado
      final esta mal. Por eso este SP recibe la lista completa y la deja
      exactamente asi, en una transaccion.

      @PLANTAS es un CSV de ids. Se parte con STRING_SPLIT, sin construir
      SQL dinamico: la lista nunca se concatena a una consulta.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPS_CLIENTE_USUARIO_PLANTA]
@USUARIO_DESTINO  INT,
@CLIENTE          INT,
@PLANTAS          VARCHAR(MAX),
@FECHA_INICIO     DATE = NULL,
@FECHA_FIN        DATE = NULL,
@USUARIO          INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
DECLARE @IDS TABLE (id INT PRIMARY KEY)

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @FECHA_INICIO = ISNULL(@FECHA_INICIO, CAST(@DATE_NOW AS DATE))

INSERT INTO @IDS (id)
SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(value)) AS INT)
FROM   STRING_SPLIT(ISNULL(@PLANTAS, ''), ',')
WHERE  LTRIM(RTRIM(value)) <> ''
  AND  TRY_CAST(LTRIM(RTRIM(value)) AS INT) IS NOT NULL

BEGIN
    -- 1. Al menos una planta
    IF NOT EXISTS (SELECT 1 FROM @IDS)
    BEGIN
        RAISERROR('1.- Debe asignar al menos una planta.', 16, 1)
        RETURN -1
    END

    -- 2. Todas las plantas deben ser del cliente
    IF EXISTS (SELECT 1 FROM @IDS i
                WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                                   WHERE cin_id = i.id AND cin_cliente = @CLIENTE))
    BEGIN
        RAISERROR('2.- ALGUNA DE LAS PLANTAS NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- 3. El usuario debe estar afiliado al cliente
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario]
                    WHERE ucl_id_usuario = @USUARIO_DESTINO AND ucl_id_cliente = @CLIENTE)
    BEGIN
        RAISERROR('3.- EL USUARIO NO ESTÁ AFILIADO A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF @FECHA_FIN IS NOT NULL AND @FECHA_FIN < @FECHA_INICIO
    BEGIN
        RAISERROR('4.- LA FECHA DE TÉRMINO NO PUEDE SER ANTERIOR A LA DE INICIO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    /* Las que ya no estan en la lista se DESHABILITAN, no se borran: hay
       ordenes y checklists historicos que se apoyan en que esa persona
       estuvo autorizada en esa planta. */
    UPDATE  ciu
    SET     ciu.ciu_habilitado = 0
    FROM    [dbo].[Cliente_Instalacion_Usuario] ciu
    INNER JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = ciu.ciu_id_instalacion
    WHERE   ciu.ciu_id_usuario = @USUARIO_DESTINO
      AND   ci.cin_cliente     = @CLIENTE
      AND   ciu.ciu_habilitado = 1
      AND   ciu.ciu_id_instalacion NOT IN (SELECT id FROM @IDS)

    -- Las que ya existian y vuelven a estar: se reactivan y se les fija vigencia
    UPDATE  ciu
    SET     ciu.ciu_habilitado   = 1,
            ciu.ciu_fecha_inicio = @FECHA_INICIO,
            ciu.ciu_fecha_fin    = @FECHA_FIN
    FROM    [dbo].[Cliente_Instalacion_Usuario] ciu
    WHERE   ciu.ciu_id_usuario = @USUARIO_DESTINO
      AND   ciu.ciu_id_instalacion IN (SELECT id FROM @IDS)

    -- Las nuevas
    INSERT [dbo].[Cliente_Instalacion_Usuario]
        (ciu_id_instalacion, ciu_id_usuario, ciu_usuario_creacion, ciu_fecha_creacion,
         ciu_habilitado, ciu_fecha_inicio, ciu_fecha_fin)
    SELECT  i.id, @USUARIO_DESTINO, @USUARIO, @DATE_NOW, 1, @FECHA_INICIO, @FECHA_FIN
    FROM    @IDS i
    WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario]
                         WHERE ciu_id_usuario = @USUARIO_DESTINO
                           AND ciu_id_instalacion = i.id)

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   10. SEL_CLIENTE_USUARIO_PLANTA                                   HU-014

       Las plantas de una persona dentro de un cliente, con su estado de
       vigencia. VIGENTE es lo que evalua FNC_USUARIO_TIENE_PERMISO en su
       paso 4, asi que esta vista y el motor de permisos dicen lo mismo.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_USUARIO_PLANTA]
@USUARIO_DESTINO INT = NULL,
@CLIENTE         INT = NULL,
@INSTALACION     INT = NULL,
@SOLO_VIGENTES   BIT = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT ciu.ciu_id             AS CIU_ID
                                 ,ciu.ciu_id_instalacion  AS CIU_ID_INSTALACION
                                 ,ciu.ciu_id_usuario      AS CIU_ID_USUARIO
                                 ,ciu.ciu_habilitado      AS CIU_HABILITADO
                                 ,ciu.ciu_fecha_inicio    AS CIU_FECHA_INICIO
                                 ,ciu.ciu_fecha_fin       AS CIU_FECHA_FIN
                                 ,ci.cin_cliente          AS CIN_CLIENTE
                                 ,ci.cin_codigo           AS CIN_CODIGO
                                 ,ci.cin_nombre           AS CIN_NOMBRE
                                 ,u.usu_nombre + SPACE(1) + u.usu_apellido_paterno AS USU_NOMBRE
                                 ,CASE WHEN ciu.ciu_habilitado = 0 THEN ''REVOCADA''
                                       WHEN ciu.ciu_fecha_inicio IS NOT NULL
                                        AND ciu.ciu_fecha_inicio > CAST(GETDATE() AS DATE) THEN ''PENDIENTE''
                                       WHEN ciu.ciu_fecha_fin IS NOT NULL
                                        AND ciu.ciu_fecha_fin < CAST(GETDATE() AS DATE) THEN ''VENCIDA''
                                       ELSE ''VIGENTE'' END AS ESTADO
                  '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM Cliente_Instalacion_Usuario ciu
                       INNER JOIN Cliente_Instalacion ci ON ci.cin_id = ciu.ciu_id_instalacion
                       INNER JOIN Usuario u              ON u.usu_id = ciu.ciu_id_usuario
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@USUARIO_DESTINO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ciu.ciu_id_usuario = ' + LTRIM(@USUARIO_DESTINO)
    END

    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ci.cin_cliente = ' + LTRIM(@CLIENTE)
    END

    IF (@INSTALACION IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ciu.ciu_id_instalacion = ' + LTRIM(@INSTALACION)
    END

    IF (@SOLO_VIGENTES = 1) BEGIN
        SET @WHERE = @WHERE + ' AND ciu.ciu_habilitado = 1
                                AND (ciu.ciu_fecha_inicio IS NULL OR ciu.ciu_fecha_inicio <= CAST(GETDATE() AS DATE))
                                AND (ciu.ciu_fecha_fin    IS NULL OR ciu.ciu_fecha_fin    >= CAST(GETDATE() AS DATE)) '
    END

    SET @WHERE = @WHERE + ' ORDER BY ci.cin_nombre '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO


/* ========================================================================
   11. UPS_CLIENTE_USUARIO_PERFIL                                   HU-014

       El perfil de una persona DENTRO de un cliente. La misma persona puede
       ser supervisora en una empresa y tecnico en otra, por eso el perfil
       cuelga de Cliente_Usuario y no del Usuario.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPS_CLIENTE_USUARIO_PERFIL]
@USUARIO_DESTINO INT,
@CLIENTE         INT,
@PERFIL          INT,
@USUARIO         INT

AS
SET NOCOUNT ON

DECLARE @CLIENTE_USUARIO INT
DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN
    SELECT @CLIENTE_USUARIO = ucl_id
      FROM [dbo].[Cliente_Usuario]
     WHERE ucl_id_usuario = @USUARIO_DESTINO AND ucl_id_cliente = @CLIENTE

    IF @CLIENTE_USUARIO IS NULL
    BEGIN
        RAISERROR('1.- EL USUARIO NO ESTÁ AFILIADO A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- El perfil debe ser del sistema o de este cliente
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Perfiles]
                    WHERE per_id = @PERFIL
                      AND per_habilitado = 1
                      AND (per_cliente IS NULL OR per_cliente = @CLIENTE))
    BEGIN
        RAISERROR('2.- EL PERFIL NO ESTÁ DISPONIBLE PARA ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    DELETE  [dbo].[Cliente_Usuario_Perfil]
    WHERE   cup_id_cliente_usuario = @CLIENTE_USUARIO

    INSERT  [dbo].[Cliente_Usuario_Perfil]
        (cup_id_cliente_usuario, cup_id_perfil, cup_usuario_creacion, cup_fecha_creacion)
    VALUES
        (@CLIENTE_USUARIO, @PERFIL, @USUARIO, @DATE_NOW)

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPS_CLIENTE_USUARIO_PERFIL @USUARIO_DESTINO = ' +
              LTRIM(STR(@USUARIO_DESTINO)) + ',@PERFIL = ' + LTRIM(STR(@PERFIL))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE ASIGNAR EL PERFIL.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'columnas nuevas en Perfiles' AS control, COUNT(*) AS valor, 2 AS esperado
FROM   sys.columns
WHERE  object_id = OBJECT_ID(N'[dbo].[Perfiles]') AND name IN ('per_cliente','per_solo_ejecucion')
UNION ALL
SELECT 'SPs HU-014 / HU-015', COUNT(*), 9
FROM   sys.procedures
WHERE  name IN ('INS_PERFIL','UPD_PERFIL','SEL_PERFILES','DEL_PERFILES','UPS_PERFIL_PERMISO',
                'INS_USUARIO','UPD_USUARIO','UPS_CLIENTE_USUARIO_PLANTA','UPS_CLIENTE_USUARIO_PERFIL')
UNION ALL
SELECT 'SEL_CLIENTE_USUARIO_PLANTA', COUNT(*), 1
FROM   sys.procedures WHERE name = 'SEL_CLIENTE_USUARIO_PLANTA'
GO
