/* ============================================================================
   SIGMA — Bloque 56
   GUARDAR UN USUARIO, BIEN
   ----------------------------------------------------------------------------

   UPD_CLIENTE_USUARIO -el SP que guarda la ficha de usuario- tenia cuatro
   problemas, y los cuatro se manifestaron el mismo dia al probar la pantalla:

     1. Guardaba la contrasena EN TEXTO PLANO y sin sal. Es la unica ruta del
        sistema que quedaba asi, y explica por que a Ximena se le puso la
        clave en "1" y despues no podia entrar: SEL_LOGIN compara el hash
        contra lo guardado, y lo guardado era la palabra "1".

     2. Metia UPE_ID -el id de la FILA de Usuario_Perfil- en CUP_ID_PERFIL,
        que desde el bloque 38 tiene FK contra Perfiles.per_id. Cambiarle el
        perfil a alguien violaba la FK y el guardado se caia entero. Es el
        mismo bug del upe_id que ya se corrigio en la FK, en
        INS_CLIENTE_USUARIO y en DEL_USUARIO_ASOCIACION; esta era la ultima
        copia viva.

     3. Borraba los Usuario_Perfil "huerfanos" comparando esos mismos dos ids
        entre si, asi que borraba filas que no correspondian y dejaba otras.

     4. Terminaba con un IF @@ROWCOUNT = 0 -> ROLLBACK justo despues del
        INSERT de perfiles. Guardar un usuario sin tocarle el perfil daba
        cero filas insertadas y revertia todo con "No fue posible guardar la
        informacion", cuando en realidad no habia nada que insertar.

   Se reescribe entero. La firma no cambia: hay una pantalla y un controller
   llamandolo con trece parametros.
   ============================================================================ */

CREATE OR ALTER PROCEDURE [dbo].[UPD_CLIENTE_USUARIO]
@ID               INT,
@IDENTIFICADOR    VARCHAR(100),
@CLIENTE          INT = NULL,
@LOGIN            VARCHAR(200),
@PASSWORD         VARCHAR(100) = NULL,
@NOMBRES          VARCHAR(200),
@APELLIDO_PATERNO VARCHAR(200),
@APELLIDO_MATERNO VARCHAR(200),
@FONO1            VARCHAR(50)  = NULL,
@CORREO           VARCHAR(200),
@USUARIO          INT,
@PERFILES         VARCHAR(MAX) = NULL,
@CLINTE_NUEVO     BIT = 0
AS
SET NOCOUNT ON
SET XACT_ABORT ON   -- cualquier error revierte; no se dejan transacciones a medias

DECLARE @PAIS INT, @DATE_NOW DATETIME, @ID_CLIENTE_USUARIO INT, @SALT VARCHAR(50)

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Usuario] WHERE usu_id = @ID)
BEGIN
    RAISERROR('1.- El usuario no existe.', 16, 1)
    RETURN -1
END

IF (SELECT usu_habilitado FROM [dbo].[Usuario] WHERE usu_id = @ID) = 0
BEGIN
    RAISERROR('2.- El usuario está deshabilitado. Habilítelo antes de editarlo.', 16, 1)
    RETURN -2
END

/* El login tiene que seguir siendo unico: si no, dos personas compiten por
   la misma fila en SEL_LOGIN y entra la que el ORDER BY deje primero. */
IF EXISTS (SELECT 1 FROM [dbo].[Usuario]
            WHERE usu_login COLLATE DATABASE_DEFAULT = @LOGIN COLLATE DATABASE_DEFAULT
              AND usu_id <> @ID)
BEGIN
    RAISERROR('3.- Ese correo ya está en uso por otra persona.', 16, 1)
    RETURN -3
END


BEGIN TRANSACTION

    /* ---- Los datos de la persona ----

       La contrasena NO se toca cuando llega vacia. La ficha ya no arrastra
       la guardada -no puede: es un hash- asi que el campo vacio significa
       "dejala como esta", y con algo escrito significa "cambiala a esto".

       Cuando cambia, se guarda HASHEADA con la sal de la cuenta. Si la
       cuenta todavia no tenia sal -viene de antes de la migracion- se le
       genera una aqui. Esta era la ultima puerta por la que entraba una
       contrasena en claro a la tabla. */
    IF (@PASSWORD IS NOT NULL AND LTRIM(RTRIM(@PASSWORD)) <> '')
    BEGIN
        SELECT @SALT = usu_password_salt FROM [dbo].[Usuario] WHERE usu_id = @ID

        IF @SALT IS NULL
            SET @SALT = REPLACE(CONVERT(VARCHAR(50), NEWID()), '-', '')

        UPDATE  [dbo].[Usuario]
        SET     usu_password_salt = @SALT,
                usu_password      = [dbo].[FNC_PASSWORD_HASH](@PASSWORD, @SALT),

                /* Un cambio de clave hecho por un administrador desbloquea
                   la cuenta: si quedo bloqueada por intentos fallidos y solo
                   se le cambia la clave, la persona sigue sin poder entrar y
                   nadie entiende por que. */
                usu_intentos_fallidos      = 0,
                usu_primer_intento_fallido = NULL,
                usu_bloqueado_hasta        = NULL
        WHERE   usu_id = @ID
    END

    UPDATE  [dbo].[Usuario]
    SET     usu_identificador    = @IDENTIFICADOR,
            usu_login            = @LOGIN,
            usu_nombre           = @NOMBRES,
            usu_apellido_paterno = @APELLIDO_PATERNO,
            usu_apellido_materno = ISNULL(@APELLIDO_MATERNO, ''),
            usu_telefono         = @FONO1,
            usu_correo           = @CORREO,
            usu_usuario_act      = @USUARIO,
            usu_fecha_act        = @DATE_NOW
    WHERE   usu_id = @ID


    /* ---- La afiliacion al cliente ---- */
    IF @CLIENTE IS NOT NULL
    BEGIN
        SELECT @ID_CLIENTE_USUARIO = ucl_id
          FROM [dbo].[Cliente_Usuario]
         WHERE ucl_id_usuario = @ID AND ucl_id_cliente = @CLIENTE

        IF @ID_CLIENTE_USUARIO IS NULL
        BEGIN
            INSERT INTO [dbo].[Cliente_Usuario]
                (ucl_id_usuario, ucl_id_cliente, ucl_usuario_creacion, ucl_fecha_creacion,
                 ucl_usuario_act, ucl_fecha_act, ucl_habilitado)
            VALUES
                (@ID, @CLIENTE, @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)

            SET @ID_CLIENTE_USUARIO = SCOPE_IDENTITY()
        END
    END


    /* ---- Los perfiles ----

       @PERFILES es un CSV de ids de Perfiles. Vacio significa "no cambies
       nada": la ficha puede guardarse para corregir un telefono sin que eso
       implique dejar a la persona sin perfil.

       Solo se reemplazan los de ESTE cliente. Lo que la persona sea en otra
       empresa no se toca desde aqui. */
    IF (@PERFILES IS NOT NULL AND LTRIM(RTRIM(@PERFILES)) <> '' AND @ID_CLIENTE_USUARIO IS NOT NULL)
    BEGIN
        DELETE  [dbo].[Cliente_Usuario_Perfil]
        WHERE   cup_id_cliente_usuario = @ID_CLIENTE_USUARIO

        /* CUP_ID_PERFIL lleva el PER_ID, no el UPE_ID. Aqui estaba el bug
           que impedia cambiar de perfil: metia el id de la fila de
           Usuario_Perfil y la FK contra Perfiles lo rechazaba. */
        INSERT INTO [dbo].[Cliente_Usuario_Perfil]
            (cup_id_cliente_usuario, cup_id_perfil, cup_usuario_creacion, cup_fecha_creacion)
        SELECT  @ID_CLIENTE_USUARIO, p.per_id, @USUARIO, @DATE_NOW
        FROM    [dbo].[Perfiles] p
        WHERE   p.per_id IN (SELECT TRY_CAST(VALUE AS INT) FROM [dbo].[SPLIT](@PERFILES, ','))
          AND   p.per_habilitado = 1
          AND   (p.per_cliente IS NULL OR p.per_cliente = @CLIENTE)

        /* El espejo en Usuario_Perfil (bloque 49). Se agrega lo nuevo y se
           saca lo que la persona ya no tiene EN NINGUN cliente: quien es
           tecnica aqui y supervisora en otra empresa no puede perder el
           segundo perfil por haber cambiado el primero. */
        INSERT INTO [dbo].[Usuario_Perfil] (upe_usuario, upe_perfil)
        SELECT  DISTINCT @ID, cup.cup_id_perfil
        FROM    [dbo].[Cliente_Usuario] cu
        JOIN    [dbo].[Cliente_Usuario_Perfil] cup ON cup.cup_id_cliente_usuario = cu.ucl_id
        WHERE   cu.ucl_id_usuario = @ID
          AND   NOT EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil] up
                            WHERE up.upe_usuario = @ID AND up.upe_perfil = cup.cup_id_perfil)

        DELETE  up
        FROM    [dbo].[Usuario_Perfil] up
        WHERE   up.upe_usuario = @ID
          AND   NOT EXISTS (SELECT 1
                              FROM [dbo].[Cliente_Usuario] cu
                              JOIN [dbo].[Cliente_Usuario_Perfil] cup
                                ON cup.cup_id_cliente_usuario = cu.ucl_id
                             WHERE cu.ucl_id_usuario = @ID
                               AND cup.cup_id_perfil = up.upe_perfil)
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   REPARACION: las cuentas que quedaron con la clave en texto plano

      Mientras UPD_CLIENTE_USUARIO guardaba en claro, cada persona editada
      desde la ficha quedo sin poder entrar. Se detectan porque su
      usu_password no mide 64 caracteres, que es lo que ocupa un SHA2-256 en
      hexadecimal.

      Se les vuelve a hashear lo que tengan guardado, que es su contrasena
      real en claro. Asi entran con la misma que les pusieron, sin que nadie
      tenga que avisarles nada.
   ======================================================================== */

UPDATE  [dbo].[Usuario]
SET     usu_password_salt = ISNULL(usu_password_salt, REPLACE(CONVERT(VARCHAR(50), NEWID()), '-', ''))
WHERE   usu_password_salt IS NULL
  AND   LEN(usu_password) <> 64
GO

UPDATE  [dbo].[Usuario]
SET     usu_password = [dbo].[FNC_PASSWORD_HASH](usu_password, usu_password_salt),
        usu_intentos_fallidos      = 0,
        usu_primer_intento_fallido = NULL,
        usu_bloqueado_hasta        = NULL
WHERE   LEN(usu_password) <> 64
  AND   usu_password_salt IS NOT NULL
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */

SELECT  'UPD_CLIENTE_USUARIO hashea la contrasena' AS OBJETO,
        (SELECT COUNT(*) FROM sys.sql_modules
          WHERE object_id = OBJECT_ID('UPD_CLIENTE_USUARIO')
            AND definition LIKE '%FNC_PASSWORD_HASH%') AS HAY, 1 AS ESPERADO
UNION ALL
SELECT  'UPD_CLIENTE_USUARIO ya no usa UPE_ID como perfil',
        (SELECT COUNT(*) FROM sys.sql_modules
          WHERE object_id = OBJECT_ID('UPD_CLIENTE_USUARIO')
            AND definition LIKE '%p.per_id, @USUARIO, @DATE_NOW%'), 1
UNION ALL
SELECT  'cuentas con la contrasena en claro',
        (SELECT COUNT(*) FROM [dbo].[Usuario] WHERE LEN(usu_password) <> 64), 0
UNION ALL
SELECT  'cuentas sin sal',
        (SELECT COUNT(*) FROM [dbo].[Usuario] WHERE usu_password_salt IS NULL), 0
GO
