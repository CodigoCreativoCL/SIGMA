USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  15-09-2026
-- DESCRIPTION:     SEL_LOGIN NO APAGA A LAS CUENTAS DE PLATAFORMA CUANDO
--                  SU UNICO CLIENTE AFILIADO ESTA DESHABILITADO.
-- =============================================
-- DEFECTO (encontrado en la evidencia de HU-010 #2, 15-09-2026)
--   INS_CLIENTE (bloque 39) afilia en Cliente_Usuario a quien crea el
--   cliente. Catalina (Root) creo un cliente de prueba, lo deshabilito
--   (baja logica) y al volver a entrar SEL_LOGIN respondio «Su cuenta no
--   esta habilitada. Contacte al administrador»: tenia UNA afiliacion y era
--   a un cliente apagado, y la regla de @TIENE_CLIENTE solo eximia a quien
--   no tiene ninguna. Es decir: dar de baja a un cliente dejaba fuera a la
--   persona que administra la plataforma.
--
-- LO QUE CAMBIA
--   @TIENE_CLIENTE es 1 para quien tenga algun perfil de tipo Sistema
--   (Perfiles.per_tipo = 1). El resto de SEL_LOGIN (bloque 58) queda igual:
--   ambito, bloqueo por intentos, suscripcion.
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[SEL_LOGIN]
@LOGIN    VARCHAR(2000),
@PASSWORD VARCHAR(500),
@AMBITO   INT = 1

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


IF (@ID IS NULL)
BEGIN
    INSERT [dbo].[Sis_Excepcion] (LGE_TEXTO, LGE_ERROR, LGE_FECHA_ACT)
    VALUES ('SEL_LOGIN @LOGIN = ' + ISNULL(@LOGIN, ''), 'INTENTO DE ACCESO CON CUENTA INEXISTENTE.', @AHORA)

    SELECT 0 [ID], '404' [CODE], @MENSAJE_GENERICO [MENSAJE]
    RETURN -1
END


IF (@BLOQUEADO_HASTA IS NOT NULL AND @BLOQUEADO_HASTA > @AHORA)
BEGIN
    SET @MINUTOS_RESTANTES = DATEDIFF(MINUTE, @AHORA, @BLOQUEADO_HASTA) + 1

    SELECT 0     [ID]
          ,'423' [CODE]
          ,'Su cuenta está bloqueada por intentos fallidos. Vuelva a intentar en '
           + LTRIM(STR(@MINUTOS_RESTANTES)) + ' minuto(s).' [MENSAJE]
    RETURN -5
END


DECLARE @AFILIACIONES INT

SELECT  @AFILIACIONES = COUNT(*)
FROM    [dbo].[Cliente_Usuario]
WHERE   ucl_id_usuario = @ID

/* Las cuentas de plataforma (algun perfil de tipo Sistema: Root, Gerente
   Comercial) no dependen de ningun cliente para entrar. INS_CLIENTE afilia
   a quien crea el cliente, asi que un Root que da de alta una empresa y
   despues la deshabilita quedaba con una sola afiliacion, a un cliente
   apagado, y SEL_LOGIN lo rechazaba con «Su cuenta no esta habilitada»
   (visto en las pruebas de HU-010 #2, 15-09-2026). La baja logica es del
   cliente; quien administra la plataforma no se apaga con el. */
DECLARE @ES_PLATAFORMA BIT = CASE
    WHEN EXISTS (SELECT 1
                 FROM   [dbo].[Usuario_Perfil] up
                 INNER JOIN [dbo].[Perfiles] p ON p.per_id = up.upe_perfil
                 WHERE  up.upe_usuario = @ID
                   AND  p.per_tipo = 1) THEN 1
    ELSE 0 END

SET @TIENE_CLIENTE = CASE
    WHEN @ES_PLATAFORMA = 1 THEN 1
    WHEN @AFILIACIONES = 0 THEN 1
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
WHERE   usu_id = @ID


/* ---- Sin perfil no se entra ---- */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil] WHERE upe_usuario = @ID)
   AND NOT EXISTS (SELECT 1
                     FROM [dbo].[Cliente_Usuario] cu
                     JOIN [dbo].[Cliente_Usuario_Perfil] cup ON cup.cup_id_cliente_usuario = cu.ucl_id
                    WHERE cu.ucl_id_usuario = @ID)
BEGIN
    INSERT [dbo].[Sis_Excepcion] (LGE_TEXTO, LGE_ERROR, LGE_FECHA_ACT)
    VALUES ('SEL_LOGIN @LOGIN = ' + ISNULL(@LOGIN, ''), 'ACCESO DENEGADO: CUENTA SIN PERFIL.', @AHORA)

    SELECT 0     [ID]
          ,'403' [CODE]
          ,'Tu cuenta todavía no tiene un perfil asignado. '
         + 'Contacta al administrador de tu empresa.' [MENSAJE]
    RETURN -7
END


/* ---- Ambito: web o app (bloque 58) ---- */
IF ([dbo].[FNC_USUARIO_OPERA_AMBITO](@ID, @AMBITO) = 0)
BEGIN
    INSERT [dbo].[Sis_Excepcion] (LGE_TEXTO, LGE_ERROR, LGE_FECHA_ACT)
    VALUES ('SEL_LOGIN @LOGIN = ' + ISNULL(@LOGIN, '') + ', AMBITO ' + LTRIM(STR(@AMBITO)),
            'ACCESO DENEGADO POR AMBITO DEL PERFIL.', @AHORA)

    SELECT 0     [ID]
          ,'403' [CODE]
          ,CASE WHEN @AMBITO = 1
                THEN 'Tu perfil trabaja desde la aplicación móvil de SIGMA, no desde la web. '
                   + 'Ingresa desde la app.'
                ELSE 'Tu perfil trabaja desde la web de SIGMA, no desde la aplicación móvil.'
           END [MENSAJE]
    RETURN -8
END


/* ---- Suscripcion de la empresa (ANEXO F §6.6) ---- */
IF (@AFILIACIONES > 0)
BEGIN
    IF NOT EXISTS (SELECT 1
                     FROM [dbo].[Cliente_Usuario] cu
                    WHERE cu.ucl_id_usuario = @ID
                      AND ISNULL(cu.ucl_habilitado, 0) = 1
                      AND [dbo].[FNC_CLIENTE_PUEDE_OPERAR](cu.ucl_id_cliente) = 1)
    BEGIN
        IF ([dbo].[FNC_USUARIO_PUEDE_RENOVAR](@ID) = 0)
        BEGIN
            INSERT [dbo].[Sis_Excepcion] (LGE_TEXTO, LGE_ERROR, LGE_FECHA_ACT)
            VALUES ('SEL_LOGIN @LOGIN = ' + ISNULL(@LOGIN, ''),
                    'ACCESO DENEGADO POR SUSCRIPCION NO VIGENTE.', @AHORA)

            SELECT 0     [ID]
                  ,'402' [CODE]
                  ,'La suscripción de tu empresa no está vigente. '
                 + 'Contacta al administrador de tu empresa para regularizarla.' [MENSAJE]
            RETURN -6
        END
    END
END


UPDATE  [dbo].[Usuario]
SET     usu_ultimo_acceso = @AHORA
WHERE   usu_id = @ID

SELECT @ID [ID], '200' [CODE], 'OK' [MENSAJE]
RETURN 0
GO
GO
