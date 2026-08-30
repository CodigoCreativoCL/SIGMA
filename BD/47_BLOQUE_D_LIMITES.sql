USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  30-08-2026
-- DESCRIPTION:     BLOQUE D. LOS LIMITES DEL PLAN SE HACEN CUMPLIR.  HU-193
-- =============================================
-- Va DESPUES de 46_PLAN_FUNCIONALIDADES.
--
-- QUE RESUELVE
--   FNC_CLIENTE_LIMITE y FNC_SUSCRIPCION_VIGENTE existen desde el bloque 08
--   y responden bien, pero hasta hoy NADIE las consultaba antes de crear:
--   un cliente en BASICO podia dar de alta diez plantas aunque su plan diga
--   una. El plan era una etiqueta, no una regla.
--
--   Se comprobo: FNC_CLIENTE_LIMITE solo aparecia en UPS_SUSCRIPCION_PLAN,
--   y FNC_SUSCRIPCION_VIGENTE solo en SEL_ e INS_SUSCRIPCION. Las dos
--   servian para MOSTRAR, ninguna para IMPEDIR.
--
-- LO QUE NO SE HACE, A PROPOSITO
--   Nada se borra ni se deshabilita al pasarse del plan. El ANEXO F §8 es
--   explicito: lo que excede queda en solo lectura. Un cliente que baja de
--   750 a 150 activos conserva los 750; simplemente no puede crear mas.
--   Por eso este bloque solo agrega guardas en los INS_, y ningun UPDATE
--   masivo.
--
-- TRES DEFECTOS QUE APARECIERON AL LLEGAR AQUI
--   Se corrigen porque estan justo en el camino de lo que este bloque va a
--   contar: si los datos de afiliacion estan mal escritos, contar usuarios
--   o plantas por cliente da cualquier cosa.
--
--   a) INS_CLIENTE_USUARIO insertaba UPE_ID en CUP_ID_PERFIL. Es el mismo
--      error que ya se corrigio en INS_CLIENTE (bloque 29). Ahora ademas
--      REVIENTA, porque el bloque 38 puso la FK correcta apuntando a
--      Perfiles: el SP quedo roto y nadie lo habia ejercitado.
--
--   b) INS_CLIENTE_USUARIO_ASOCIAR insertaba UCL_ID -el id de la fila de
--      Cliente_Usuario- en CIU_ID_USUARIO, que en todo el resto del sistema
--      es un id de USUARIO. FNC_USUARIO_TIENE_PERMISO lee esa columna como
--      usu_id en su paso 4, asi que la autorizacion en planta quedaba
--      evaluada contra la persona equivocada.
--
--   c) Cliente_Instalacion_Usuario NO TENIA NI UNA CLAVE FORANEA. Por eso
--      (b) pasaba inadvertido. Se agregan.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. LAS CLAVES FORANEAS QUE FALTABAN

      Sin ellas, escribir un id de otra tabla en ciu_id_usuario no falla:
      simplemente queda mal y se descubre cuando alguien no puede entrar a
      una planta y nadie entiende por que.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CIU_USUARIO')
BEGIN
    IF EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Usuario] WHERE usu_id = ciu.ciu_id_usuario))
        PRINT 'AVISO: hay filas de Cliente_Instalacion_Usuario con usuario inexistente. FK_CIU_USUARIO no se creo.'
    ELSE
    BEGIN
        ALTER TABLE [dbo].[Cliente_Instalacion_Usuario] WITH CHECK
            ADD CONSTRAINT [FK_CIU_USUARIO] FOREIGN KEY ([ciu_id_usuario])
                REFERENCES [dbo].[Usuario] ([usu_id])
        PRINT 'FK_CIU_USUARIO creada.'
    END
END
ELSE PRINT 'FK_CIU_USUARIO ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CIU_INSTALACION')
BEGIN
    IF EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion] WHERE cin_id = ciu.ciu_id_instalacion))
        PRINT 'AVISO: hay filas con planta inexistente. FK_CIU_INSTALACION no se creo.'
    ELSE
    BEGIN
        ALTER TABLE [dbo].[Cliente_Instalacion_Usuario] WITH CHECK
            ADD CONSTRAINT [FK_CIU_INSTALACION] FOREIGN KEY ([ciu_id_instalacion])
                REFERENCES [dbo].[Cliente_Instalacion] ([cin_id])
        PRINT 'FK_CIU_INSTALACION creada.'
    END
END
ELSE PRINT 'FK_CIU_INSTALACION ya existe.'
GO


/* ========================================================================
   2. FNC_CLIENTE_CONSUMO

      Cuanto lleva usado el cliente de una funcionalidad con tope.

      Se cuenta lo HABILITADO, no lo existente: una planta deshabilitada no
      ocupa cupo. Si contara todo, un cliente que da de baja una planta para
      crear otra seguiria bloqueado, y la unica salida seria borrar datos,
      que es justo lo que §8 prohibe.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_CLIENTE_CONSUMO]
(
    @CLIENTE              INT,
    @FUNCIONALIDAD_CODIGO NVARCHAR(50)
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @N DECIMAL(18,2) = 0

    IF @FUNCIONALIDAD_CODIGO = N'LIMITE PLANTAS'
        SELECT @N = COUNT(*) FROM [dbo].[Cliente_Instalacion]
         WHERE cin_cliente = @CLIENTE AND ISNULL(cin_habilitado, 0) = 1

    ELSE IF @FUNCIONALIDAD_CODIGO = N'LIMITE USUARIOS'
        SELECT @N = COUNT(*) FROM [dbo].[Cliente_Usuario]
         WHERE ucl_id_cliente = @CLIENTE AND ISNULL(ucl_habilitado, 0) = 1

    ELSE IF @FUNCIONALIDAD_CODIGO = N'LIMITE ACTIVOS'
        SELECT @N = COUNT(*) FROM [dbo].[Activo]
         WHERE act_cliente = @CLIENTE AND ISNULL(act_habilitado, 0) = 1

    ELSE IF @FUNCIONALIDAD_CODIGO = N'LIMITE ALMACENAMIENTO'
        -- En GB, que es la unidad en que esta expresado el tope.
        SELECT @N = ISNULL(SUM(CAST(arc_byte AS DECIMAL(18,2))), 0) / 1073741824.0
          FROM [dbo].[Archivo]
         WHERE arc_cliente = @CLIENTE AND ISNULL(arc_habilitado, 0) = 1

    RETURN @N
END
GO


/* ========================================================================
   3. FNC_CLIENTE_PUEDE_CREAR

      La pregunta que hacen los INS_: ¿cabe uno mas?

      TRES CASOS QUE NO SON LO MISMO, y que FNC_CLIENTE_LIMITE por si sola
      no distingue porque devuelve 0 tanto para "sin plan" como para "no
      incluida":

        Sin suscripcion   -> SE PERMITE. No hay plan, luego no hay limite
                             que aplicar. Un cliente se da de alta y se
                             configura ANTES de cerrar el trato comercial
                             (esa fue la decision del bloque 41); bloquearlo
                             aqui impediria justamente el alta.
        Funcionalidad no incluida -> se niega.
        Tope NULL         -> SE PERMITE. NULL es "sin tope", que es como
                             esta cargado FULL. Cero es otra cosa: cero es
                             no poder crear ninguno.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_CLIENTE_PUEDE_CREAR]
(
    @CLIENTE              INT,
    @FUNCIONALIDAD_CODIGO NVARCHAR(50)
)
RETURNS BIT
AS
BEGIN
    IF @CLIENTE IS NULL OR @CLIENTE = 0 RETURN 1

    -- Sin suscripcion no hay plan, y sin plan no hay tope que hacer cumplir.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion]
                    WHERE sus_cliente = @CLIENTE AND sus_habilitado = 1)
        RETURN 1

    IF [dbo].[FNC_CLIENTE_TIENE_FUNCIONALIDAD](@CLIENTE, @FUNCIONALIDAD_CODIGO) = 0
        RETURN 0

    DECLARE @LIMITE  DECIMAL(18,2) = [dbo].[FNC_CLIENTE_LIMITE](@CLIENTE, @FUNCIONALIDAD_CODIGO)
    DECLARE @CONSUMO DECIMAL(18,2)

    IF @LIMITE IS NULL RETURN 1          -- sin tope

    SET @CONSUMO = [dbo].[FNC_CLIENTE_CONSUMO](@CLIENTE, @FUNCIONALIDAD_CODIGO)

    IF @CONSUMO < @LIMITE RETURN 1
    RETURN 0
END
GO


/* ========================================================================
   4. SEL_CLIENTE_LIMITE

      Los cuatro topes con su consumo, para la pantalla. Que alguien vea
      "4 de 5 usuarios" ANTES de intentar crear el sexto es la diferencia
      entre entender el plan y chocar con un mensaje de error.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_LIMITE]
@CLIENTE INT
AS
SET NOCOUNT ON

DECLARE @HAY_SUSCRIPCION BIT =
    CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Suscripcion]
                       WHERE sus_cliente = @CLIENTE AND sus_habilitado = 1)
         THEN 1 ELSE 0 END;

/* Las funciones se evalúan UNA vez por fila en el CTE y después se usan.
   Llamarlas siete veces en el SELECT no solo era caro: hacía difícil ver
   que TOPE y DISPONIBLE necesitaban tratarse distinto cuando no hay plan. */
WITH base AS (
    SELECT  f.fun_codigo,
            f.fun_nombre,
            f.fun_orden,
            [dbo].[FNC_CLIENTE_TIENE_FUNCIONALIDAD](@CLIENTE, f.fun_codigo) AS incluida,
            [dbo].[FNC_CLIENTE_LIMITE](@CLIENTE, f.fun_codigo)              AS tope,
            [dbo].[FNC_CLIENTE_CONSUMO](@CLIENTE, f.fun_codigo)             AS consumo,
            [dbo].[FNC_CLIENTE_PUEDE_CREAR](@CLIENTE, f.fun_codigo)         AS puede
    FROM    [dbo].[Funcionalidad] f
    WHERE   f.fun_codigo LIKE N'LIMITE %'
      AND   f.fun_habilitado = 1
)
SELECT  b.fun_codigo    AS FUN_CODIGO,
        b.fun_nombre    AS FUN_NOMBRE,
        b.incluida      AS INCLUIDA,

        /* Sin suscripción el tope no es cero: es que NO HAY tope todavía.
           FNC_CLIENTE_LIMITE devuelve 0 en ese caso porque no encuentra
           plan, y mostrarlo tal cual daba "tope 0, disponible -7", que se
           lee como un error del sistema y no como un cliente sin plan. */
        CASE WHEN @HAY_SUSCRIPCION = 0 THEN NULL ELSE b.tope END    AS TOPE,
        b.consumo       AS CONSUMO,
        b.puede         AS PUEDE_CREAR,
        CASE WHEN @HAY_SUSCRIPCION = 0 OR b.tope IS NULL THEN NULL
             ELSE b.tope - b.consumo END                            AS DISPONIBLE,

        CASE WHEN @HAY_SUSCRIPCION = 0            THEN N'SIN SUSCRIPCION'
             WHEN b.incluida = 0                  THEN N'NO INCLUIDA'
             WHEN b.tope IS NULL                  THEN N'SIN TOPE'
             WHEN b.consumo >= b.tope             THEN N'AL LIMITE'
             ELSE N'DISPONIBLE'
        END                                                         AS ESTADO
FROM    base b
ORDER BY b.fun_orden

RETURN(0)
GO


/* ========================================================================
   5. SEL_SUSCRIPCION_ESTADO_CLIENTE

      El estado de la suscripcion PARA LA WEB, que conoce el cliente en
      sesion pero no la clave.

      No reimplementa la regla: busca la clave del cliente y se la pasa a
      FNC_SUSCRIPCION_VIGENTE, que es la unica fuente de verdad y la misma
      que usa la API. Copiar el CASE aqui garantizaria que algun dia la web
      y la app dijeran cosas distintas del mismo cliente.

      Un cliente SIN suscripcion devuelve estado SIN SUSCRIPCION y
      PUEDE_OPERAR = 1: es el cliente que todavia se esta configurando, y no
      corresponde bloquearlo por algo que aun no se le vendio.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_SUSCRIPCION_ESTADO_CLIENTE]
@CLIENTE INT
AS
SET NOCOUNT ON

DECLARE @KEY VARBINARY(32)

SELECT TOP 1 @KEY = sus_key_hash
  FROM [dbo].[Suscripcion]
 WHERE sus_cliente = @CLIENTE AND sus_habilitado = 1

IF @KEY IS NULL
BEGIN
    SELECT  @CLIENTE            AS CLIENTE,
            CAST(0 AS INT)      AS SUSCRIPCION,
            CAST(NULL AS INT)   AS PLAN_COMERCIAL,
            N'SIN SUSCRIPCION'  AS ESTADO,
            CAST(NULL AS DATE)  AS FECHA_FIN,
            CAST(NULL AS INT)   AS DIAS_RESTANTES,
            CAST(1 AS BIT)      AS PUEDE_OPERAR,
            CAST(0 AS BIT)      AS AVISAR
    RETURN(0)
END

DECLARE @DIAS_AVISO INT

SELECT @DIAS_AVISO = TRY_CAST(par_valor AS INT)
  FROM [dbo].[Sys_Parametros] WHERE par_codigo = 'SUSCRIPCION_DIAS_AVISO'

SET @DIAS_AVISO = ISNULL(@DIAS_AVISO, 10)

SELECT  v.CLIENTE,
        v.SUSCRIPCION,
        v.PLAN_COMERCIAL,
        v.ESTADO,
        v.FECHA_FIN,
        v.DIAS_RESTANTES,
        v.PUEDE_OPERAR,
        /* AVISAR se calcula aqui y no en la pagina: cuantos dias antes se
           avisa es un parametro del negocio, no una constante del codigo. */
        /* El CAST no es adorno: la rama de "sin suscripcion" de mas
           arriba devuelve AVISAR como BIT, y sin el, esta rama lo
           devolveria como INT. La misma columna con dos tipos segun el
           camino obliga a cada consumidor -la web hoy, la API despues- a
           adivinar como leerla. */
        CAST(CASE WHEN v.ESTADO = N'EN GRACIA' THEN 1
                  WHEN v.ESTADO = N'VIGENTE' AND v.DIAS_RESTANTES <= @DIAS_AVISO THEN 1
                  ELSE 0 END AS BIT) AS AVISAR
FROM    [dbo].[FNC_SUSCRIPCION_VIGENTE](@KEY) v

RETURN(0)
GO


/* ========================================================================
   6. INS_SUSCRIPCION_BLOQUEO_LOG                                    §6.7

      Append-only. Cada rechazo por suscripcion queda registrado.

      No es paranoia: es lo que permite responder "¿desde cuando no puede
      entrar este cliente?" cuando llama enojado, en vez de adivinar.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_SUSCRIPCION_BLOQUEO_LOG]
@CLIENTE   INT = NULL,
@ESTADO    NVARCHAR(20),
@ORIGEN    NVARCHAR(20) = N'WEB',
@ENDPOINT  NVARCHAR(200) = NULL,
@IP        NVARCHAR(50) = NULL,
@USUARIO   INT = NULL

AS
SET NOCOUNT ON

DECLARE @SUSCRIPCION INT, @PREFIJO NVARCHAR(20)

SELECT TOP 1 @SUSCRIPCION = sus_id, @PREFIJO = sus_key_prefijo
  FROM [dbo].[Suscripcion]
 WHERE sus_cliente = @CLIENTE AND sus_habilitado = 1

INSERT [dbo].[Suscripcion_Bloqueo_Log]
    (sbl_suscripcion, sbl_key_prefijo, sbl_estado, sbl_origen,
     sbl_endpoint, sbl_ip, sbl_fecha_utc, sbl_usuario_creacion, sbl_fecha_creacion)
VALUES
    (@SUSCRIPCION, @PREFIJO, @ESTADO, @ORIGEN,
     @ENDPOINT, @IP, GETUTCDATE(), @USUARIO, GETDATE())

RETURN(0)
GO


/* ========================================================================
   7. LA GUARDA EN LAS PLANTAS                                       HU-193
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_CLIENTE_INSTALACION]
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

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_CLIENTE_INSTALACION ' + ISNULL(@NOMBRE, '')
        EXEC [dbo].[INS_EXCEPCION] @MSG = '5.- NO FUE POSIBLE INSERTAR LA PLANTA.', @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   8. LA GUARDA EN LOS USUARIOS + LOS DOS DEFECTOS DEL SP

      Se reescribe INS_CLIENTE_USUARIO conservando lo que hacia -crear el
      usuario, su pais, sus perfiles y su afiliacion- y corrigiendo:

        · UPE_PERFIL en vez de UPE_ID en Cliente_Usuario_Perfil. Con la FK
          del bloque 38 este SP ya no funcionaba en absoluto.
        · La contrasena entra HASHEADA. Escribia @PASSWORD tal cual, asi que
          todo usuario creado por aqui quedaba en texto plano y no podia
          entrar: SEL_LOGIN compara contra el hash.
        · Se restauran las validaciones de unicidad, que estaban comentadas.
        · El tope de usuarios del plan.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_CLIENTE_USUARIO]
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
@PERFILES          VARCHAR(MAX),
@USUARIO           INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
DECLARE @SALT VARCHAR(50) = REPLACE(CONVERT(VARCHAR(50), NEWID()), '-', '')
DECLARE @ID_CLIENTE_USUARIO INT
DECLARE @TOPE DECIMAL(18,2), @MENSAJE NVARCHAR(400)

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN
    -- HU-193. El tope de usuarios del plan.
    IF [dbo].[FNC_CLIENTE_PUEDE_CREAR](@CLIENTE, N'LIMITE USUARIOS') = 0
    BEGIN
        SET @TOPE = [dbo].[FNC_CLIENTE_LIMITE](@CLIENTE, N'LIMITE USUARIOS')
        SET @MENSAJE = N'1.- EL PLAN CONTRATADO PERMITE ' + LTRIM(STR(CAST(ISNULL(@TOPE,0) AS INT))) +
                       N' USUARIO(S) Y YA HAY ' +
                       LTRIM(STR(CAST([dbo].[FNC_CLIENTE_CONSUMO](@CLIENTE, N'LIMITE USUARIOS') AS INT))) +
                       N'. DESHABILITE UNO O CAMBIE DE PLAN.'
        RAISERROR(@MENSAJE, 16, 1)
        RETURN -1
    END

    -- Validaciones que estaban comentadas en el SP original.
    IF EXISTS (SELECT 1 FROM [dbo].[Usuario] WHERE usu_login = LTRIM(RTRIM(@LOGIN)))
    BEGIN
        RAISERROR('2.- Ya existe un usuario registrado con el login indicado.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Usuario] WHERE usu_identificador = LTRIM(RTRIM(@IDENTIFICADOR)))
    BEGIN
        RAISERROR('3.- Ya existe un usuario registrado con el identificador indicado.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Usuario] WHERE usu_correo = LTRIM(RTRIM(@CORREO)))
    BEGIN
        RAISERROR('4.- Ya existe un usuario registrado con el correo indicado.', 16, 1)
        RETURN -1
    END

    IF @CLIENTE IS NOT NULL AND [dbo].[FNC_IDENTIFICADOR_VALIDO](@PAIS, @IDENTIFICADOR) = 0
    BEGIN
        RAISERROR('5.- El identificador "%s" no es válido para el país del cliente.', 16, 1, @IDENTIFICADOR)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Usuario]
        (usu_identificador, usu_login, usu_password, usu_password_salt,
         usu_nombre, usu_apellido_paterno, usu_apellido_materno,
         usu_telefono, usu_correo,
         usu_usuario_creacion, usu_fecha_creacion, usu_usuario_act, usu_fecha_act,
         usu_habilitado)
    VALUES
        (@IDENTIFICADOR, @LOGIN,
         [dbo].[FNC_PASSWORD_HASH](@PASSWORD, @SALT), @SALT,
         @NOMBRES, @APELLIDO_PATERNO, ISNULL(@APELLIDO_MATERNO, ''),
         @FONO1, @CORREO,
         @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_CLIENTE_USUARIO ' + ISNULL(@LOGIN, '')
        EXEC [dbo].[INS_EXCEPCION] @MSG = '6.- NO FUE POSIBLE INSERTAR EL USUARIO.', @VARIABLES = @VARIABLES
        RETURN -1
    END

    -- El historial de contrasenas arranca con la inicial.
    INSERT [dbo].[Usuario_Password_Historial]
        (uph_usuario, uph_password, uph_usuario_creacion, uph_fecha_creacion)
    VALUES (@ID, [dbo].[FNC_PASSWORD_HASH](@PASSWORD, @SALT), @USUARIO, @DATE_NOW)

    -- Pais
    IF @PAIS IS NOT NULL
        INSERT INTO [dbo].[Usuario_Paises]
            (upa_id_usuario, upa_id_pais, upa_usuario_creacion, upa_fecha_creacion,
             upa_usuario_act, upa_fecha_act)
        VALUES (@ID, @PAIS, @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW)

    -- Perfiles globales
    INSERT [dbo].[Usuario_Perfil] (upe_usuario, upe_perfil)
    SELECT @ID, VALUE FROM [dbo].[SPLIT](@PERFILES, ',')
     WHERE EXISTS (SELECT 1 FROM [dbo].[Perfiles] WHERE per_id = VALUE)

    -- Afiliacion al cliente
    IF @CLIENTE IS NOT NULL
    BEGIN
        INSERT INTO [dbo].[Cliente_Usuario]
            (ucl_id_usuario, ucl_id_cliente, ucl_habilitado,
             ucl_usuario_creacion, ucl_fecha_creacion, ucl_usuario_act, ucl_fecha_act)
        VALUES (@ID, @CLIENTE, 1, @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW)

        SET @ID_CLIENTE_USUARIO = SCOPE_IDENTITY()

        /* UPE_PERFIL, no UPE_ID. Cliente_Usuario_Perfil.cup_id_perfil
           referencia Perfiles.per_id desde el bloque 38; con UPE_ID esto
           violaba la FK y el SP entero fallaba. */
        INSERT [dbo].[Cliente_Usuario_Perfil]
            (cup_id_cliente_usuario, cup_id_perfil, cup_usuario_creacion, cup_fecha_creacion)
        SELECT DISTINCT @ID_CLIENTE_USUARIO, upe.upe_perfil, @USUARIO, @DATE_NOW
        FROM   [dbo].[Usuario_Perfil] upe
        WHERE  upe.upe_usuario = @ID
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   9. INS_CLIENTE_USUARIO_ASOCIAR

      Corrige el id equivocado y agrega la vigencia.

      Escribia @CLIENTE_USUARIO -un ucl_id- en CIU_ID_USUARIO. Esa columna
      es un usu_id: asi la lee FNC_USUARIO_TIENE_PERMISO en su paso 4, y asi
      la escribe UPS_CLIENTE_USUARIO_PLANTA. Con el valor equivocado, la
      autorizacion en planta se evaluaba contra otra persona, y como la
      tabla no tenia FK nada lo delataba.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_CLIENTE_USUARIO_ASOCIAR]
@ID              INT = NULL OUTPUT,
@CLIENTE         INT,
@ID_USUARIO      INT,
@ID_INSTALACION  INT = NULL,
@USUARIO         INT,
@PERFIL          VARCHAR(200) = NULL

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN
    IF @ID_INSTALACION IS NULL
    BEGIN
        RAISERROR('1.- DEBE INDICAR LA PLANTA.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                    WHERE cin_id = @ID_INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('2.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- Ya autorizado en esa planta: no se duplica.
    IF EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario]
                WHERE ciu_id_usuario = @ID_USUARIO AND ciu_id_instalacion = @ID_INSTALACION)
    BEGIN
        UPDATE [dbo].[Cliente_Instalacion_Usuario]
           SET ciu_habilitado = 1
         WHERE ciu_id_usuario = @ID_USUARIO AND ciu_id_instalacion = @ID_INSTALACION

        SELECT @ID = ciu_id FROM [dbo].[Cliente_Instalacion_Usuario]
         WHERE ciu_id_usuario = @ID_USUARIO AND ciu_id_instalacion = @ID_INSTALACION

        RETURN(0)
    END
END

BEGIN TRANSACTION

    INSERT INTO [dbo].[Cliente_Instalacion_Usuario]
        (ciu_id_instalacion, ciu_id_usuario, ciu_usuario_creacion, ciu_fecha_creacion,
         ciu_habilitado, ciu_fecha_inicio, ciu_fecha_fin)
    VALUES
        (@ID_INSTALACION, @ID_USUARIO, @USUARIO, @DATE_NOW,
         1, CAST(@DATE_NOW AS DATE), NULL)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_CLIENTE_USUARIO_ASOCIAR @ID_USUARIO = ' + LTRIM(STR(@ID_USUARIO))
        EXEC [dbo].[INS_EXCEPCION] @MSG = '3.- NO FUE POSIBLE ASOCIAR EL USUARIO A LA PLANTA.', @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'objetos del bloque D' AS control, COUNT(*) AS valor, 5 AS esperado
FROM   sys.objects
WHERE  name IN ('FNC_CLIENTE_CONSUMO','FNC_CLIENTE_PUEDE_CREAR','SEL_CLIENTE_LIMITE',
                'SEL_SUSCRIPCION_ESTADO_CLIENTE','INS_SUSCRIPCION_BLOQUEO_LOG')
UNION ALL
SELECT 'FKs de Cliente_Instalacion_Usuario', COUNT(*), 2
FROM   sys.foreign_keys WHERE name IN ('FK_CIU_USUARIO','FK_CIU_INSTALACION')
UNION ALL
SELECT 'INS_ que consultan el tope', COUNT(*), 2
FROM   sys.sql_modules
WHERE  definition LIKE '%FNC_CLIENTE_PUEDE_CREAR%'
  AND  OBJECT_NAME(object_id) LIKE 'INS_%'
GO

-- Los cuatro topes del cliente 1 con su consumo real.
EXEC [dbo].[SEL_CLIENTE_LIMITE] @CLIENTE = 1
GO

EXEC [dbo].[SEL_SUSCRIPCION_ESTADO_CLIENTE] @CLIENTE = 1
GO
