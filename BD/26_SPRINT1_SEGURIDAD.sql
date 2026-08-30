USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     EP-01. ACCESO, SEGURIDAD Y MULTICLIENTE. HU-001 A HU-007.
-- =============================================
-- Va DESPUES de 25_SPRINT1_MODELO.
--
-- QUE CUBRE
--   HU-001  Iniciar sesion: ultimo acceso, mensaje que no delata el campo,
--           cuenta deshabilitada, bloqueo por cinco intentos en quince minutos.
--   HU-003  Cerrar sesion y expirar la inactiva (la parte de servidor).
--   HU-004  Recuperar contrasena con enlace de un solo uso.
--   HU-005  Editar mi perfil y cambiar mi contrasena.
--   HU-006  Aplicar permisos (ya resuelto por FNC_USUARIO_TIENE_PERMISO).
--   HU-007  Permiso puntual a un usuario: consultar, revocar, ambito de area.
--
-- LA CONTRASENA
--   Hoy la contrasena se guarda y se compara en TEXTO PLANO: SEL_LOGIN hace
--   'IF @PASSWORD_RETURN != @PASSWORD'. Cualquiera con lectura sobre Usuario
--   ve la clave de todos.
--
--   HU-005 obliga a guardar las tres contrasenas anteriores de cada persona.
--   Guardar un historial en texto plano seria multiplicar el problema, asi
--   que aqui se pasa a hash SHA2-256 con sal por usuario.
--
--   LA MIGRACION NO PUEDE DEJAR A NADIE FUERA. Por eso es progresiva: si el
--   usuario todavia no tiene sal, se compara en plano como siempre y, si
--   acierta, en esa misma llamada se le genera sal y se guarda el hash. La
--   segunda vez que entra ya va por hash. Nadie tiene que cambiar su clave y
--   no hay ventana en que el login falle.
--
--   El C# no cambia: sigue mandando la contrasena tal cual y es el SP el que
--   decide como compararla.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. Sal por usuario

      Sal POR USUARIO, no global: sin ella dos personas con la misma clave
      tendrian el mismo hash, y quien lea la tabla sabria que coinciden.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Usuario]') AND name = 'usu_password_salt')
BEGIN
    ALTER TABLE [dbo].[Usuario] ADD [usu_password_salt] VARCHAR(50) NULL
    PRINT 'Columna usu_password_salt agregada a Usuario.'
END
ELSE PRINT 'Columna usu_password_salt ya existe en Usuario.'
GO


/* ========================================================================
   2. FNC_PASSWORD_HASH

      Devuelve el hash en hexadecimal (64 caracteres) para que quepa en la
      columna VARCHAR(500) que ya existe, sin cambiarle el tipo.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_PASSWORD_HASH]
(
    @PASSWORD VARCHAR(500),
    @SALT     VARCHAR(50)
)
RETURNS VARCHAR(500)
AS
BEGIN
    IF @PASSWORD IS NULL OR @SALT IS NULL RETURN NULL

    RETURN CONVERT(VARCHAR(500), HASHBYTES('SHA2_256', @SALT + @PASSWORD), 2)
END
GO


/* ========================================================================
   3. SEL_LOGIN                                                     HU-001

      Cambios respecto de la version anterior:

      a) Entra por correo O por login. HU-001 dice correo; los usuarios
         historicos entran con su login ('Root'). Se aceptan ambos para no
         dejar fuera a nadie.

      b) "Cuenta No Existe" y "Contrasena Incorrecta" eran dos mensajes
         distintos: eso le permite a cualquiera averiguar que correos estan
         registrados probandolos de a uno. El escenario 2 pide explicitamente
         que el mensaje no indique cual de los dos campos fallo.

      c) Bloqueo por cinco intentos en quince minutos, contados desde el
         PRIMER fallo de la racha. Si se contaran desde el ultimo, cinco
         fallos espaciados dieciseis minutos no bloquearian nunca.

      d) El intento fallido queda registrado en Sis_Excepcion. Se inserta
         directo y no via INS_EXCEPCION: ese SP termina en RAISERROR, que
         abortaria el login en vez de responderle al usuario.

      e) El cliente deshabilitado se evaluaba con un SELECT escalar sobre
         Cliente_Usuario, que devuelve una fila cualquiera cuando la persona
         pertenece a varios clientes. Ahora se exige que tenga AL MENOS UNA
         afiliacion vigente.

      Contrato de salida: ID / CODE / MENSAJE, igual que antes. El
      UsuarioController no cambia.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_LOGIN]
@LOGIN    VARCHAR(2000),
@PASSWORD VARCHAR(500)

AS
SET NOCOUNT ON

DECLARE @ID                 INT
       ,@PASSWORD_GUARDADA  VARCHAR(500)
       ,@SALT               VARCHAR(50)
       ,@HABILITADO         BIT
       ,@BLOQUEADO_HASTA    DATETIME
       ,@INTENTOS           INT
       ,@PRIMER_FALLO       DATETIME
       ,@TIENE_CLIENTE      BIT
       ,@AHORA              DATETIME = GETDATE()
       ,@MINUTOS_RESTANTES  INT
       ,@MENSAJE_GENERICO   VARCHAR(200) = 'Correo o contraseña incorrectos.'

/* Los intentos fallidos se cuentan por CUENTA, no por sesion, para que
   cerrar el navegador no reinicie el contador. */
DECLARE @MAX_INTENTOS   INT = 5
       ,@VENTANA_MIN    INT = 15
       ,@BLOQUEO_MIN    INT = 15

SELECT  TOP 1
        @ID                = usu_id
       ,@PASSWORD_GUARDADA = usu_password
       ,@SALT              = usu_password_salt
       ,@HABILITADO        = usu_habilitado
       ,@BLOQUEADO_HASTA   = usu_bloqueado_hasta
       ,@INTENTOS          = ISNULL(usu_intentos_fallidos, 0)
       ,@PRIMER_FALLO      = usu_primer_intento_fallido
FROM    [dbo].[Usuario]
WHERE   usu_login = @LOGIN
   OR   usu_correo = @LOGIN
ORDER BY CASE WHEN usu_correo = @LOGIN THEN 0 ELSE 1 END


/* ---- Cuenta inexistente ----
   Mismo mensaje y mismo codigo que una contrasena mala. */
IF (@ID IS NULL)
BEGIN
    INSERT [dbo].[Sis_Excepcion] (LGE_TEXTO, LGE_ERROR, LGE_FECHA_ACT)
    VALUES ('SEL_LOGIN @LOGIN = ' + ISNULL(@LOGIN, ''), 'INTENTO DE ACCESO CON CUENTA INEXISTENTE.', @AHORA)

    SELECT 0 [ID], '404' [CODE], @MENSAJE_GENERICO [MENSAJE]
    RETURN -1
END


/* ---- Cuenta bloqueada ----
   Se informa el tiempo restante, como pide el escenario 4. */
IF (@BLOQUEADO_HASTA IS NOT NULL AND @BLOQUEADO_HASTA > @AHORA)
BEGIN
    SET @MINUTOS_RESTANTES = DATEDIFF(MINUTE, @AHORA, @BLOQUEADO_HASTA) + 1

    SELECT 0     [ID]
          ,'423' [CODE]
          ,'Su cuenta está bloqueada por intentos fallidos. Vuelva a intentar en '
           + LTRIM(STR(@MINUTOS_RESTANTES)) + ' minuto(s).' [MENSAJE]
    RETURN -5
END


/* ---- Cuenta o afiliacion deshabilitada ----

   La regla se aplica SOLO a quien tiene afiliaciones. Un usuario sin
   ninguna fila en Cliente_Usuario es un administrador de la plataforma, no
   un usuario de cliente, y debe poder entrar: es justamente quien da de
   alta al primer cliente en HU-010.

   Exigirle una afiliacion a todo el mundo dejaria fuera a las cuentas de
   plataforma y nadie podria configurar el sistema. */
DECLARE @AFILIACIONES INT

SELECT  @AFILIACIONES = COUNT(*)
FROM    [dbo].[Cliente_Usuario]
WHERE   ucl_id_usuario = @ID

SET @TIENE_CLIENTE = CASE
    WHEN @AFILIACIONES = 0 THEN 1   -- cuenta de plataforma
    WHEN EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario] cu
                 INNER JOIN [dbo].[Cliente] c ON c.cli_id = cu.ucl_id_cliente
                 WHERE cu.ucl_id_usuario = @ID
                   AND ISNULL(cu.ucl_habilitado, 0) = 1
                   AND ISNULL(c.cli_habilitado, 0) = 1) THEN 1
    ELSE 0 END

IF (@HABILITADO = 0 OR @TIENE_CLIENTE = 0)
BEGIN
    SELECT 0     [ID]
          ,'401' [CODE]
          ,'Su cuenta no está habilitada. Contacte al administrador.' [MENSAJE]
    RETURN -2
END


/* ---- Contrasena ----
   Con sal se compara el hash. Sin sal, esta cuenta todavia no fue migrada:
   se compara en plano y, si acierta, se migra abajo. */
DECLARE @CLAVE_OK BIT = 0

IF (@SALT IS NULL)
BEGIN
    IF (@PASSWORD_GUARDADA = @PASSWORD) SET @CLAVE_OK = 1
END
ELSE
BEGIN
    IF (@PASSWORD_GUARDADA = [dbo].[FNC_PASSWORD_HASH](@PASSWORD, @SALT)) SET @CLAVE_OK = 1
END


IF (@CLAVE_OK = 0)
BEGIN
    /* Racha nueva si es el primer fallo o si la ventana ya vencio. */
    IF (@PRIMER_FALLO IS NULL OR DATEDIFF(MINUTE, @PRIMER_FALLO, @AHORA) > @VENTANA_MIN)
    BEGIN
        SET @INTENTOS     = 1
        SET @PRIMER_FALLO = @AHORA
    END
    ELSE
        SET @INTENTOS = @INTENTOS + 1

    UPDATE  [dbo].[Usuario]
    SET     usu_intentos_fallidos      = @INTENTOS
           ,usu_primer_intento_fallido = @PRIMER_FALLO
           ,usu_bloqueado_hasta        = CASE WHEN @INTENTOS >= @MAX_INTENTOS
                                              THEN DATEADD(MINUTE, @BLOQUEO_MIN, @AHORA)
                                              ELSE usu_bloqueado_hasta END
    WHERE   usu_id = @ID

    INSERT [dbo].[Sis_Excepcion] (LGE_TEXTO, LGE_ERROR, LGE_FECHA_ACT)
    VALUES ('SEL_LOGIN @LOGIN = ' + ISNULL(@LOGIN, '') + ', INTENTO ' + LTRIM(STR(@INTENTOS)),
            'CONTRASEÑA INCORRECTA.', @AHORA)

    IF (@INTENTOS >= @MAX_INTENTOS)
    BEGIN
        SELECT 0     [ID]
              ,'423' [CODE]
              ,'Su cuenta está bloqueada por intentos fallidos. Vuelva a intentar en '
               + LTRIM(STR(@BLOQUEO_MIN)) + ' minuto(s).' [MENSAJE]
        RETURN -5
    END

    SELECT 0 [ID], '404' [CODE], @MENSAJE_GENERICO [MENSAJE]
    RETURN -3
END


/* ---- Acceso concedido ----
   Se limpia la racha, se sella el ultimo acceso y, si la cuenta venia sin
   sal, se migra a hash aprovechando que aqui tenemos la clave en claro. */
IF (@SALT IS NULL)
BEGIN
    SET @SALT = REPLACE(CONVERT(VARCHAR(50), NEWID()), '-', '')

    UPDATE  [dbo].[Usuario]
    SET     usu_password_salt = @SALT
           ,usu_password      = [dbo].[FNC_PASSWORD_HASH](@PASSWORD, @SALT)
    WHERE   usu_id = @ID
END

UPDATE  [dbo].[Usuario]
SET     usu_intentos_fallidos      = 0
       ,usu_primer_intento_fallido = NULL
       ,usu_bloqueado_hasta        = NULL
       ,usu_ultimo_acceso          = @AHORA
WHERE   usu_id = @ID

SELECT @ID [ID], '200' [CODE], 'OK' [MENSAJE]
RETURN 0
GO


/* ========================================================================
   4. UPD_USUARIO_PASSWORD                                   HU-004, HU-005

      Un solo SP para los dos caminos, porque las reglas de la contrasena
      nueva son las mismas venga de donde venga:

        @EXIGE_ACTUAL = 1  el usuario cambia su clave estando dentro y debe
                           escribir la vigente (HU-005 escenario 1).
        @EXIGE_ACTUAL = 0  viene de un enlace de recuperacion ya validado,
                           donde por definicion no sabe la anterior.

      Las tres anteriores: el historial guarda cada clave que se fija, asi
      que las tres ultimas filas del historial SON las tres anteriores.
   ======================================================================== */

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

    -- Distinta de la vigente y de las tres anteriores
    IF @HASH_NUEVO = @PASSWORD_GUARDADA
       OR EXISTS (SELECT 1
                    FROM (SELECT TOP 3 uph_password
                            FROM [dbo].[Usuario_Password_Historial]
                           WHERE uph_usuario = @USUARIO
                           ORDER BY uph_fecha_creacion DESC) h
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
           ,usu_fecha_act             = GETDATE()
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
        (@USUARIO, @HASH_NUEVO, @USUARIO, GETDATE())

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   5. INS_USUARIO_RECUPERACION                                      HU-004

      Genera el enlace de un solo uso.

      EL MENSAJE ES EL MISMO EXISTA O NO EL CORREO (escenario 1). Por eso
      este SP devuelve 0 siempre y nunca RAISERROR: si fallara cuando el
      correo no existe, la pantalla delataria que cuentas hay registradas.

      Devuelve @ENVIAR: 1 si hay que mandar el correo, 0 si no hay a quien.
      El C# manda el correo solo cuando vale 1 y muestra el mismo texto en
      los dos casos.

      Se guarda el HASH del token. El token en claro lo genera el C# y viaja
      una sola vez, en el correo.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_USUARIO_RECUPERACION]
@ID          INT = NULL OUTPUT,
@CORREO      VARCHAR(200),
@TOKEN       VARCHAR(200),
@IP          NVARCHAR(50) = NULL,
@ENVIAR      BIT = 0 OUTPUT,
@USUARIO_ID  INT = 0 OUTPUT

AS
SET NOCOUNT ON

DECLARE @MINUTOS_VIGENCIA INT = 60

SET @ENVIAR     = 0
SET @USUARIO_ID = 0

SELECT  TOP 1 @USUARIO_ID = usu_id
FROM    [dbo].[Usuario]
WHERE   usu_correo = @CORREO
  AND   usu_habilitado = 1

IF @USUARIO_ID IS NULL OR @USUARIO_ID = 0
BEGIN
    SET @USUARIO_ID = 0
    RETURN(0)
END

BEGIN TRANSACTION

    /* Los enlaces anteriores que siguen vivos se anulan: pedir uno nuevo
       invalida el anterior, si no habria varios validos a la vez. */
    UPDATE  [dbo].[Usuario_Recuperacion]
    SET     ure_fecha_uso = GETDATE()
    WHERE   ure_usuario = @USUARIO_ID
      AND   ure_fecha_uso IS NULL
      AND   ure_fecha_expiracion > GETDATE()

    INSERT [dbo].[Usuario_Recuperacion]
        (ure_usuario, ure_token_hash, ure_fecha_expiracion, ure_ip_solicitud,
         ure_usuario_creacion, ure_fecha_creacion)
    VALUES
        (@USUARIO_ID,
         HASHBYTES('SHA2_256', @TOKEN),
         DATEADD(MINUTE, @MINUTOS_VIGENCIA, GETDATE()),
         @IP,
         @USUARIO_ID,
         GETDATE())

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RETURN(0)
    END

COMMIT TRANSACTION

SET @ENVIAR = 1
RETURN(0)
GO


/* ========================================================================
   6. SEL_USUARIO_RECUPERACION                                      HU-004

      Responde si el enlace sirve, sin consumirlo: la pantalla que pide la
      contrasena nueva necesita saberlo ANTES de mostrar el formulario.

      ESTADO:  VIGENTE / USADO / VENCIDO / INVALIDO
      El escenario 3 distingue vencido de invalido, por eso no se colapsan.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_USUARIO_RECUPERACION]
@TOKEN VARCHAR(200)

AS
SET NOCOUNT ON

SELECT  TOP 1
        ure.ure_id                                          AS URE_ID
       ,ure.ure_usuario                                     AS URE_USUARIO
       ,u.usu_correo                                        AS USU_CORREO
       ,ure.ure_fecha_expiracion                            AS URE_FECHA_EXPIRACION
       ,CASE WHEN ure.ure_fecha_uso IS NOT NULL          THEN 'USADO'
             WHEN ure.ure_fecha_expiracion <= GETDATE()  THEN 'VENCIDO'
             ELSE 'VIGENTE' END                            AS ESTADO
FROM    [dbo].[Usuario_Recuperacion] ure
INNER JOIN [dbo].[Usuario] u ON u.usu_id = ure.ure_usuario
WHERE   ure.ure_token_hash = HASHBYTES('SHA2_256', @TOKEN)

/* Sin filas: el token no existe. Se devuelve una fila sintetica para que el
   C# tenga siempre la misma forma de respuesta que leer. */
IF @@ROWCOUNT = 0
    SELECT 0 AS URE_ID, 0 AS URE_USUARIO, CAST(NULL AS VARCHAR(200)) AS USU_CORREO,
           CAST(NULL AS DATETIME) AS URE_FECHA_EXPIRACION, 'INVALIDO' AS ESTADO

RETURN(0)
GO


/* ========================================================================
   7. UPD_USUARIO_RECUPERACION_USAR                                 HU-004

      Consume el enlace y fija la contrasena nueva.

      EL ORDEN IMPORTA. Primero se cambia la contrasena y solo despues se
      marca el enlace como usado.

      No se envuelve todo en una transaccion que abarque el EXEC:
      UPD_USUARIO_PASSWORD abre y cierra la suya, y sus rutas de error hacen
      ROLLBACK. Como SQL Server no tiene transacciones anidadas de verdad,
      ese ROLLBACK del SP interno desharia tambien la transaccion externa y
      el COMMIT posterior fallaria con "no corresponding BEGIN TRANSACTION".

      Ademas RAISERROR de severidad 16 NO aborta el lote: la ejecucion
      vuelve aqui. Por eso se lee el codigo de retorno con EXEC @RC = ...;
      sin esa comprobacion el enlace se marcaria como usado aunque la
      contrasena hubiera sido rechazada, y la persona se quedaria sin enlace
      y sin clave nueva.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_USUARIO_RECUPERACION_USAR]
@TOKEN           VARCHAR(200),
@PASSWORD_NUEVO  VARCHAR(500)

AS
SET NOCOUNT ON

DECLARE @URE_ID  INT
       ,@USUARIO INT
       ,@RC      INT

BEGIN
    SELECT  TOP 1 @URE_ID = ure_id, @USUARIO = ure_usuario
    FROM    [dbo].[Usuario_Recuperacion]
    WHERE   ure_token_hash = HASHBYTES('SHA2_256', @TOKEN)
      AND   ure_fecha_uso IS NULL
      AND   ure_fecha_expiracion > GETDATE()

    IF @URE_ID IS NULL
    BEGIN
        RAISERROR('1.- EL ENLACE NO ES VÁLIDO O YA EXPIRÓ. SOLICITE UNO NUEVO.', 16, 1)
        RETURN -1
    END
END

EXEC @RC = [dbo].[UPD_USUARIO_PASSWORD]
     @USUARIO        = @USUARIO,
     @PASSWORD_NUEVO = @PASSWORD_NUEVO,
     @EXIGE_ACTUAL   = 0

/* La contrasena fue rechazada. El enlace NO se consume: la persona corrige
   y vuelve a intentar con el mismo correo. */
IF (@RC <> 0) RETURN -1

BEGIN TRANSACTION

    UPDATE  [dbo].[Usuario_Recuperacion]
    SET     ure_fecha_uso = GETDATE()
    WHERE   ure_id = @URE_ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_USUARIO_RECUPERACION_USAR @URE_ID = ' + LTRIM(STR(@URE_ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '2.- NO FUE POSIBLE INVALIDAR EL ENLACE DE RECUPERACIÓN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   8. UPD_USUARIO_MI_PERFIL                                         HU-005

      Acotado a proposito: solo telefono, foto e idioma. El nombre, el RUT,
      el correo y el estado de la cuenta los mantiene el administrador
      (HU-014), no la propia persona. Un UPD_USUARIO general aqui dejaria
      que cualquiera se cambiara el correo, que es la llave de la cuenta.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_USUARIO_MI_PERFIL]
@USUARIO   INT,
@TELEFONO  VARCHAR(50) = NULL,
@IDIOMA    INT = NULL,
@FOTO      VARBINARY(MAX) = NULL,
@CAMBIA_FOTO BIT = 0

AS
SET NOCOUNT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Usuario]
    SET     usu_telefono   = @TELEFONO
           ,usu_idioma     = ISNULL(@IDIOMA, usu_idioma)
           ,usu_foto       = CASE WHEN @CAMBIA_FOTO = 1 THEN @FOTO ELSE usu_foto END
           ,usu_usuario_act = @USUARIO
           ,usu_fecha_act   = GETDATE()
    WHERE   usu_id = @USUARIO

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_USUARIO_MI_PERFIL @USUARIO = ' + LTRIM(STR(@USUARIO))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '1.- NO FUE POSIBLE ACTUALIZAR EL PERFIL.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   9. FNC_USUARIO_TIENE_PERMISO                                     HU-007

      Se agrega una sola condicion: ignorar las excepciones de ambito AREA.

      POR QUE. Un permiso acotado a un area guarda tambien su planta, porque
      el area cuelga de una planta. Sin este filtro, la consulta lo tomaria
      como una excepcion de PLANTA y le daria a la persona el permiso en
      toda la planta cuando solo se le concedio en un area. Se ampliaria el
      alcance en silencio, que es exactamente lo contrario de lo que pide
      HU-007 escenario 1.

      Las excepciones por area se evaluan con FNC_USUARIO_TIENE_PERMISO_AREA.
      La firma de esta funcion no cambia: sus llamadores siguen igual.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_USUARIO_TIENE_PERMISO]
(
    @USUARIO        INT,
    @CLIENTE        INT,
    @INSTALACION    INT,
    @PERMISO_CODIGO NVARCHAR(50)
)
RETURNS BIT
AS
BEGIN
    DECLARE @PERMISO         INT
    DECLARE @CLIENTE_USUARIO INT
    DECLARE @HOY             DATE = CAST(GETDATE() AS DATE)
    DECLARE @POR_PERFIL      BIT  = 0
    DECLARE @OTORGADO        BIT
    DECLARE @RESULTADO       BIT  = 0

    SELECT @PERMISO = prm_id
      FROM [dbo].[Permiso]
     WHERE prm_codigo = @PERMISO_CODIGO AND prm_habilitado = 1
    IF @PERMISO IS NULL RETURN 0

    SELECT @CLIENTE_USUARIO = ucl_id
      FROM [dbo].[Cliente_Usuario]
     WHERE ucl_id_usuario = @USUARIO
       AND ucl_id_cliente = @CLIENTE
       AND ISNULL(ucl_habilitado, 0) = 1
    IF @CLIENTE_USUARIO IS NULL RETURN 0

    -- 1. Lo que entrega el perfil dentro de ese cliente
    IF EXISTS (SELECT 1
                 FROM [dbo].[Cliente_Usuario_Perfil] cup
                 JOIN [dbo].[Perfil_Permiso]         ppe ON ppe.ppe_perfil = cup.cup_id_perfil
                WHERE cup.cup_id_cliente_usuario = @CLIENTE_USUARIO
                  AND ppe.ppe_permiso            = @PERMISO)
        SET @POR_PERFIL = 1

    -- 2. La regla de usuario mas especifica: la de la planta gana sobre la global
    SELECT TOP 1 @OTORGADO = cpm.cpm_otorgado
      FROM [dbo].[Cliente_Usuario_Permiso] cpm
     WHERE cpm.cpm_cliente_usuario = @CLIENTE_USUARIO
       AND cpm.cpm_permiso         = @PERMISO
       AND cpm.cpm_habilitado      = 1
       AND cpm.cpm_instalacion_area IS NULL
       AND (cpm.cpm_cliente_instalacion IS NULL OR cpm.cpm_cliente_instalacion = @INSTALACION)
       AND (cpm.cpm_fecha_inicio IS NULL OR cpm.cpm_fecha_inicio <= @HOY)
       AND (cpm.cpm_fecha_fin    IS NULL OR cpm.cpm_fecha_fin    >= @HOY)
     ORDER BY CASE WHEN cpm.cpm_cliente_instalacion IS NULL THEN 1 ELSE 0 END

    -- 3. La regla de usuario manda sobre el perfil, exista o no
    SET @RESULTADO = CASE WHEN @OTORGADO IS NOT NULL THEN @OTORGADO ELSE @POR_PERFIL END

    -- 4. Sin autorizacion vigente en la planta no hay permiso que valga
    IF @RESULTADO = 1 AND @INSTALACION IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1
                         FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                        WHERE ciu.ciu_id_usuario     = @USUARIO
                          AND ciu.ciu_id_instalacion = @INSTALACION
                          AND ciu.ciu_habilitado     = 1
                          AND (ciu.ciu_fecha_inicio IS NULL OR ciu.ciu_fecha_inicio <= @HOY)
                          AND (ciu.ciu_fecha_fin    IS NULL OR ciu.ciu_fecha_fin    >= @HOY))
            SET @RESULTADO = 0
    END

    RETURN @RESULTADO
END
GO


/* ========================================================================
   10. FNC_USUARIO_TIENE_PERMISO_AREA                               HU-007

       El mismo criterio, un escalon mas fino. Orden de especificidad:
       area gana sobre planta, y planta gana sobre cliente.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_USUARIO_TIENE_PERMISO_AREA]
(
    @USUARIO        INT,
    @CLIENTE        INT,
    @INSTALACION    INT,
    @AREA           INT,
    @PERMISO_CODIGO NVARCHAR(50)
)
RETURNS BIT
AS
BEGIN
    DECLARE @PERMISO         INT
    DECLARE @CLIENTE_USUARIO INT
    DECLARE @HOY             DATE = CAST(GETDATE() AS DATE)
    DECLARE @OTORGADO        BIT

    /* Sin area, la pregunta es la de siempre. */
    IF @AREA IS NULL
        RETURN [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, @INSTALACION, @PERMISO_CODIGO)

    SELECT @PERMISO = prm_id
      FROM [dbo].[Permiso]
     WHERE prm_codigo = @PERMISO_CODIGO AND prm_habilitado = 1
    IF @PERMISO IS NULL RETURN 0

    SELECT @CLIENTE_USUARIO = ucl_id
      FROM [dbo].[Cliente_Usuario]
     WHERE ucl_id_usuario = @USUARIO
       AND ucl_id_cliente = @CLIENTE
       AND ISNULL(ucl_habilitado, 0) = 1
    IF @CLIENTE_USUARIO IS NULL RETURN 0

    -- Excepcion escrita para ESTA area
    SELECT TOP 1 @OTORGADO = cpm.cpm_otorgado
      FROM [dbo].[Cliente_Usuario_Permiso] cpm
     WHERE cpm.cpm_cliente_usuario  = @CLIENTE_USUARIO
       AND cpm.cpm_permiso          = @PERMISO
       AND cpm.cpm_habilitado       = 1
       AND cpm.cpm_instalacion_area = @AREA
       AND (cpm.cpm_fecha_inicio IS NULL OR cpm.cpm_fecha_inicio <= @HOY)
       AND (cpm.cpm_fecha_fin    IS NULL OR cpm.cpm_fecha_fin    >= @HOY)

    IF @OTORGADO IS NOT NULL
    BEGIN
        /* Aun concedido en el area, la autorizacion vigente en la planta
           sigue siendo condicion necesaria. */
        IF @OTORGADO = 1 AND @INSTALACION IS NOT NULL
           AND NOT EXISTS (SELECT 1
                             FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                            WHERE ciu.ciu_id_usuario     = @USUARIO
                              AND ciu.ciu_id_instalacion = @INSTALACION
                              AND ciu.ciu_habilitado     = 1
                              AND (ciu.ciu_fecha_inicio IS NULL OR ciu.ciu_fecha_inicio <= @HOY)
                              AND (ciu.ciu_fecha_fin    IS NULL OR ciu.ciu_fecha_fin    >= @HOY))
            RETURN 0

        RETURN @OTORGADO
    END

    -- Sin excepcion de area, decide el nivel de planta
    RETURN [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, @INSTALACION, @PERMISO_CODIGO)
END
GO


/* ========================================================================
   11. INS_CLIENTE_USUARIO_PERMISO                                  HU-007

       Se agrega el ambito de AREA y se corrige la llamada a INS_EXCEPCION.

       LA CORRECCION: la version anterior llamaba
           EXEC INS_EXCEPCION '6.- ...', @CLIENTE_USUARIO, @PERMISO
       por posicion. El primer parametro de INS_EXCEPCION es @CODIGO INT,
       asi que ese texto se intentaba convertir a entero y reventaba con un
       error de conversion en vez de registrar el mensaje. Ahora va por
       nombre, como manda PATRON_SP §7.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_CLIENTE_USUARIO_PERMISO]
    @ID                     INT = NULL OUTPUT,
    @CLIENTE_USUARIO        INT,
    @PERMISO                INT,
    @CLIENTE_INSTALACION    INT = NULL,
    @INSTALACION_AREA       INT = NULL,
    @OTORGADO               BIT = 1,
    @FECHA_INICIO           DATE = NULL,
    @FECHA_FIN              DATE = NULL,
    @MOTIVO                 NVARCHAR(500) = NULL,
    @CLIENTE                INT,
    @USUARIO                INT
AS
SET NOCOUNT ON

DECLARE @USUARIO_DESTINO INT

BEGIN
    -- 1. Quien otorga debe tener la facultad en ese cliente
    IF [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, N'ASIGNAR PERMISO TERRENO') = 0
    BEGIN
        RAISERROR('1.- NO TIENE LA FACULTAD DE ASIGNAR PERMISOS DE TERRENO.', 16, 1)
        RETURN -1
    END

    -- 2. El permiso debe ser asignable a una persona
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso]
                    WHERE prm_id = @PERMISO AND prm_asignable_usuario = 1 AND prm_habilitado = 1)
    BEGIN
        RAISERROR('2.- ESE PERMISO NO PUEDE ASIGNARSE A UN USUARIO.', 16, 1)
        RETURN -1
    END

    -- 3. El usuario destino debe estar afiliado a ese cliente
    SELECT @USUARIO_DESTINO = ucl_id_usuario
      FROM [dbo].[Cliente_Usuario]
     WHERE ucl_id = @CLIENTE_USUARIO AND ucl_id_cliente = @CLIENTE AND ISNULL(ucl_habilitado, 0) = 1
    IF @USUARIO_DESTINO IS NULL
    BEGIN
        RAISERROR('3.- EL USUARIO NO ESTA AFILIADO Y VIGENTE EN ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- 4. Si se acota a una planta, el usuario debe estar autorizado en ella
    IF @CLIENTE_INSTALACION IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario]
                        WHERE ciu_id_usuario = @USUARIO_DESTINO
                          AND ciu_id_instalacion = @CLIENTE_INSTALACION
                          AND ciu_habilitado = 1)
    BEGIN
        RAISERROR('4.- EL USUARIO NO ESTA AUTORIZADO EN ESA PLANTA.', 16, 1)
        RETURN -1
    END

    -- 5. Nadie se otorga permisos a si mismo
    IF @USUARIO_DESTINO = @USUARIO
    BEGIN
        RAISERROR('5.- NO PUEDE ASIGNARSE PERMISOS A SI MISMO.', 16, 1)
        RETURN -1
    END

    /* 6. El area tiene que pertenecer a la planta indicada. Sin esto se
          podria acotar un permiso a un area de OTRA planta, y la excepcion
          quedaria escrita en un lugar donde nadie la va a evaluar. */
    IF @INSTALACION_AREA IS NOT NULL
    BEGIN
        IF @CLIENTE_INSTALACION IS NULL
        BEGIN
            RAISERROR('6.- PARA ACOTAR A UN ÁREA DEBE INDICAR TAMBIÉN LA PLANTA.', 16, 1)
            RETURN -1
        END

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area]
                        WHERE iar_id = @INSTALACION_AREA
                          AND iar_cliente_instalacion = @CLIENTE_INSTALACION
                          AND iar_cliente = @CLIENTE)
        BEGIN
            RAISERROR('7.- EL ÁREA NO PERTENECE A ESA PLANTA.', 16, 1)
            RETURN -1
        END
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Cliente_Usuario_Permiso]
        (cpm_cliente_usuario, cpm_permiso, cpm_cliente_instalacion, cpm_instalacion_area, cpm_otorgado,
         cpm_fecha_inicio, cpm_fecha_fin, cpm_motivo,
         cpm_usuario_creacion, cpm_fecha_creacion,
         cpm_usuario_actualizacion, cpm_fecha_actualizacion, cpm_habilitado)
    VALUES
        (@CLIENTE_USUARIO, @PERMISO, @CLIENTE_INSTALACION, @INSTALACION_AREA, @OTORGADO,
         @FECHA_INICIO, @FECHA_FIN, @MOTIVO,
         @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_CLIENTE_USUARIO_PERMISO ' +
                                          '@CLIENTE_USUARIO = ' + LTRIM(STR(@CLIENTE_USUARIO)) + ',' +
                                          '@PERMISO = ' + LTRIM(STR(@PERMISO))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '8.- NO FUE POSIBLE ASIGNAR EL PERMISO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   12. SEL_CLIENTE_USUARIO_PERMISO                                  HU-007

       El listado de excepciones vigentes e historicas de un cliente.
       Trae quien la concedio y cuando, que es lo que el escenario 1 pide
       que quede registrado.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_USUARIO_PERMISO]
@ID                  INT = NULL,
@CLIENTE             INT = NULL,
@CLIENTE_USUARIO     INT = NULL,
@USUARIO             INT = NULL,
@CLIENTE_INSTALACION INT = NULL,
@SOLO_VIGENTES       BIT = NULL,
@HABILITADO          BIT = NULL,
@FILTRO              VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT cpm.cpm_id                   AS CPM_ID
                                 ,cpm.cpm_cliente_usuario       AS CPM_CLIENTE_USUARIO
                                 ,cpm.cpm_permiso               AS CPM_PERMISO
                                 ,cpm.cpm_cliente_instalacion   AS CPM_CLIENTE_INSTALACION
                                 ,cpm.cpm_instalacion_area      AS CPM_INSTALACION_AREA
                                 ,cpm.cpm_otorgado              AS CPM_OTORGADO
                                 ,cpm.cpm_fecha_inicio          AS CPM_FECHA_INICIO
                                 ,cpm.cpm_fecha_fin             AS CPM_FECHA_FIN
                                 ,cpm.cpm_motivo                AS CPM_MOTIVO
                                 ,cpm.cpm_habilitado            AS CPM_HABILITADO
                                 ,cpm.cpm_usuario_creacion      AS CPM_USUARIO_CREACION
                                 ,cpm.cpm_fecha_creacion        AS CPM_FECHA_CREACION
                                 ,cu.ucl_id_usuario             AS USU_ID
                                 ,dest.usu_nombre + SPACE(1) + dest.usu_apellido_paterno AS USU_NOMBRE
                                 ,dest.usu_correo               AS USU_CORREO
                                 ,p.prm_codigo                  AS PRM_CODIGO
                                 ,p.prm_nombre                  AS PRM_NOMBRE
                                 ,p.prm_modulo                  AS PRM_MODULO
                                 ,ci.cin_nombre                 AS CIN_NOMBRE
                                 ,ia.iar_nombre                 AS IAR_NOMBRE
                                 ,otor.usu_nombre + SPACE(1) + otor.usu_apellido_paterno AS OTORGADO_POR
                                 ,CASE WHEN cpm.cpm_habilitado = 0 THEN ''REVOCADO''
                                       WHEN cpm.cpm_fecha_fin IS NOT NULL
                                        AND cpm.cpm_fecha_fin < CAST(GETDATE() AS DATE) THEN ''VENCIDO''
                                       WHEN cpm.cpm_fecha_inicio IS NOT NULL
                                        AND cpm.cpm_fecha_inicio > CAST(GETDATE() AS DATE) THEN ''PENDIENTE''
                                       ELSE ''VIGENTE'' END     AS ESTADO
                                 ,CASE WHEN cpm.cpm_instalacion_area IS NOT NULL THEN ''Área''
                                       WHEN cpm.cpm_cliente_instalacion IS NOT NULL THEN ''Planta''
                                       ELSE ''Cliente'' END      AS AMBITO
                  '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM Cliente_Usuario_Permiso cpm
                       INNER JOIN Cliente_Usuario cu   ON cu.ucl_id = cpm.cpm_cliente_usuario
                       INNER JOIN Usuario dest         ON dest.usu_id = cu.ucl_id_usuario
                       INNER JOIN Permiso p            ON p.prm_id = cpm.cpm_permiso
                       LEFT  JOIN Cliente_Instalacion ci ON ci.cin_id = cpm.cpm_cliente_instalacion
                       LEFT  JOIN Instalacion_Area ia  ON ia.iar_id = cpm.cpm_instalacion_area
                       LEFT  JOIN Usuario otor         ON otor.usu_id = cpm.cpm_usuario_creacion
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cpm.cpm_id = ' + LTRIM(@ID)
    END

    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cu.ucl_id_cliente = ' + LTRIM(@CLIENTE)
    END

    IF (@CLIENTE_USUARIO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cpm.cpm_cliente_usuario = ' + LTRIM(@CLIENTE_USUARIO)
    END

    IF (@USUARIO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cu.ucl_id_usuario = ' + LTRIM(@USUARIO)
    END

    IF (@CLIENTE_INSTALACION IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cpm.cpm_cliente_instalacion = ' + LTRIM(@CLIENTE_INSTALACION)
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cpm.cpm_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@SOLO_VIGENTES = 1) BEGIN
        SET @WHERE = @WHERE + ' AND cpm.cpm_habilitado = 1
                                AND (cpm.cpm_fecha_inicio IS NULL OR cpm.cpm_fecha_inicio <= CAST(GETDATE() AS DATE))
                                AND (cpm.cpm_fecha_fin    IS NULL OR cpm.cpm_fecha_fin    >= CAST(GETDATE() AS DATE)) '
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (dest.usu_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR dest.usu_apellido_paterno LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR dest.usu_correo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR p.prm_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY cpm.cpm_fecha_creacion DESC '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO


/* ========================================================================
   13. UPD_CLIENTE_USUARIO_PERMISO                                  HU-007

       Revocar es baja LOGICA, no borrado: el escenario 2 pide que la
       revocacion quede registrada, y una fila borrada no registra nada.
       Al quedar cpm_habilitado = 0 la funcion deja de verla y la persona
       vuelve a lo que dice su perfil, que es justo lo pedido.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_CLIENTE_USUARIO_PERMISO]
@ID            INT,
@OTORGADO      BIT = NULL,
@FECHA_INICIO  DATE = NULL,
@FECHA_FIN     DATE = NULL,
@MOTIVO        NVARCHAR(500) = NULL,
@HABILITADO    BIT = NULL,
@USUARIO       INT

AS
SET NOCOUNT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Cliente_Usuario_Permiso]
    SET     cpm_otorgado     = ISNULL(@OTORGADO, cpm_otorgado)
           ,cpm_fecha_inicio = @FECHA_INICIO
           ,cpm_fecha_fin    = @FECHA_FIN
           ,cpm_motivo       = ISNULL(@MOTIVO, cpm_motivo)
           ,cpm_habilitado   = ISNULL(@HABILITADO, cpm_habilitado)
           ,cpm_usuario_actualizacion = @USUARIO
           ,cpm_fecha_actualizacion   = GETDATE()
    WHERE   cpm_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_CLIENTE_USUARIO_PERMISO @ID = ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '1.- NO FUE POSIBLE ACTUALIZAR EL PERMISO DEL USUARIO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'objetos EP-01 creados' AS control, COUNT(*) AS valor, 11 AS esperado
FROM   sys.objects
WHERE  name IN ('FNC_PASSWORD_HASH','SEL_LOGIN','UPD_USUARIO_PASSWORD',
                'INS_USUARIO_RECUPERACION','SEL_USUARIO_RECUPERACION',
                'UPD_USUARIO_RECUPERACION_USAR','UPD_USUARIO_MI_PERFIL',
                'FNC_USUARIO_TIENE_PERMISO','FNC_USUARIO_TIENE_PERMISO_AREA',
                'INS_CLIENTE_USUARIO_PERMISO','SEL_CLIENTE_USUARIO_PERMISO')
UNION ALL
SELECT 'UPD_CLIENTE_USUARIO_PERMISO', COUNT(*), 1
FROM   sys.procedures WHERE name = 'UPD_CLIENTE_USUARIO_PERMISO'
UNION ALL
SELECT 'usuarios ya migrados a hash', COUNT(*), NULL
FROM   [dbo].[Usuario] WHERE usu_password_salt IS NOT NULL
GO
