/* ============================================================================
   SIGMA — Bloque 250
   LAS TRES CONTRASENAS ANTERIORES SON TRES, NO DOS                    HU-005 #1
   ----------------------------------------------------------------------------

   UPD_USUARIO_PASSWORD comparaba la nueva contrasena con las TOP 3 filas del
   historial, pero el historial guarda tambien la vigente (se inserta en cada
   cambio): en la practica solo se rechazaban las dos anteriores y la tercera
   volvia a aceptarse. Se detecto el 22-09-2026 al evidenciar HU-005 #1
   (A -> B -> C -> D y de vuelta a A: aceptada). Ahora se miran TOP 4 (la
   vigente y las tres anteriores). SP completo desde la definicion vigente.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_USUARIO_PASSWORD]
@USUARIO          INT,
@PASSWORD_ACTUAL  VARCHAR(500) = NULL,
@PASSWORD_NUEVO   VARCHAR(500),
@EXIGE_ACTUAL     BIT = 1

AS
SET NOCOUNT ON

DECLARE @SALT              VARCHAR(50)
       ,@PASSWORD_GUARDADA VARCHAR(500)
       ,@HASH_NUEVO        VARCHAR(500)

BEGIN
    SELECT  @SALT              = usu_password_salt
           ,@PASSWORD_GUARDADA = usu_password
    FROM    [dbo].[Usuario]
    WHERE   usu_id = @USUARIO

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('1.- EL USUARIO NO EXISTE.', 16, 1)
        RETURN -1
    END

    /* Cuenta que aun no se migro: se le genera sal ahora. */
    IF @SALT IS NULL
    BEGIN
        SET @SALT = REPLACE(CONVERT(VARCHAR(50), NEWID()), '-', '')

        UPDATE  [dbo].[Usuario]
        SET     usu_password_salt = @SALT
               ,usu_password      = [dbo].[FNC_PASSWORD_HASH](@PASSWORD_GUARDADA, @SALT)
        WHERE   usu_id = @USUARIO

        SET @PASSWORD_GUARDADA = [dbo].[FNC_PASSWORD_HASH](@PASSWORD_GUARDADA, @SALT)
    END

    -- Contrasena actual
    IF @EXIGE_ACTUAL = 1
    BEGIN
        IF @PASSWORD_ACTUAL IS NULL
            OR [dbo].[FNC_PASSWORD_HASH](@PASSWORD_ACTUAL, @SALT) <> @PASSWORD_GUARDADA
        BEGIN
            RAISERROR('2.- LA CONTRASEÑA ACTUAL NO ES CORRECTA.', 16, 1)
            RETURN -1
        END
    END

    -- Largo minimo
    IF LEN(ISNULL(@PASSWORD_NUEVO, '')) < 8
    BEGIN
        RAISERROR('3.- LA CONTRASEÑA DEBE TENER AL MENOS 8 CARACTERES.', 16, 1)
        RETURN -1
    END

    /* Al menos una letra y un numero (HU-004). El BIN fuerza que el rango
       [A-Za-z] signifique letras inglesas y no dependa de la intercalacion
       de la base, que en Modern_Spanish incluiria acentuadas. */
    IF PATINDEX('%[0-9]%', @PASSWORD_NUEVO) = 0
       OR PATINDEX('%[A-Za-z]%', @PASSWORD_NUEVO COLLATE Latin1_General_BIN) = 0
    BEGIN
        RAISERROR('4.- LA CONTRASEÑA DEBE INCLUIR AL MENOS UNA LETRA Y UN NÚMERO.', 16, 1)
        RETURN -1
    END

    SET @HASH_NUEVO = [dbo].[FNC_PASSWORD_HASH](@PASSWORD_NUEVO, @SALT)

    -- Distinta de la vigente y de las tres anteriores.
    -- El historial guarda TAMBIEN la vigente (se inserta al cambiar), asi
    -- que "las tres anteriores" son las filas 2 a 4: TOP 4. Con TOP 3 la
    -- cuarta hacia atras volvia a aceptarse (defecto visto el 22-09-2026,
    -- HU-005 #1).
    IF @HASH_NUEVO = @PASSWORD_GUARDADA
       OR EXISTS (SELECT 1
                    FROM (SELECT TOP 4 uph_password
                            FROM [dbo].[Usuario_Password_Historial]
                           WHERE uph_usuario = @USUARIO
                           ORDER BY uph_fecha_creacion DESC, uph_id DESC) h
                   WHERE h.uph_password = @HASH_NUEVO)
    BEGIN
        RAISERROR('5.- LA CONTRASEÑA NO PUEDE SER IGUAL A NINGUNA DE LAS TRES ANTERIORES.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Usuario]
    SET     usu_password              = @HASH_NUEVO
           ,usu_intentos_fallidos     = 0
           ,usu_primer_intento_fallido = NULL
           ,usu_bloqueado_hasta       = NULL
           ,usu_usuario_act           = @USUARIO
           ,usu_fecha_act             = [dbo].[FNC_AHORA]()
    WHERE   usu_id = @USUARIO

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_USUARIO_PASSWORD @USUARIO = ' + LTRIM(STR(@USUARIO))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '6.- NO FUE POSIBLE ACTUALIZAR LA CONTRASEÑA.'
        RETURN -1
    END

    INSERT [dbo].[Usuario_Password_Historial]
        (uph_usuario, uph_password, uph_usuario_creacion, uph_fecha_creacion)
    VALUES
        (@USUARIO, @HASH_NUEVO, @USUARIO, [dbo].[FNC_AHORA]())

COMMIT TRANSACTION

RETURN(0)
GO

PRINT '--- UPD_USUARIO_PASSWORD rechaza las tres contrasenas anteriores (bloque 250).'
GO
