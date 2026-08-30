/* ============================================================================
   SIGMA — Bloque 48
   QUIEN PUEDE RENOVAR Y QUIEN NI SIQUIERA ENTRA
   ANEXO F §6.6 · HU-193
   ----------------------------------------------------------------------------

   El bloque 47 dejó el bloqueo funcionando, pero trataba igual a todo el
   mundo: con la suscripción caída, cualquiera del cliente terminaba en la
   pantalla de renovación. Eso está mal por dos motivos.

   El primero es de negocio: renovar no es tarea de un técnico ni de un
   supervisor. Ver el saldo, los períodos impagos y el contacto comercial de
   la empresa es cosa del Administrador del Cliente. A un técnico esa
   pantalla no le sirve de nada y además le muestra plata que no le
   corresponde ver.

   El segundo es de costo: dejar entrar a cien personas para que las cien
   choquen contra la misma pantalla es gastar sesión, consultas y tiempo en
   un sistema al que no van a poder usar. Si no hay nada que puedan hacer
   adentro, el lugar donde se les dice es la puerta.

   Entonces:

     · Administrador del Cliente  →  entra, y cae en Renovar.aspx.
     · Todos los demás           →  no entran. SEL_LOGIN los rechaza con un
                                    mensaje que los manda donde corresponde:
                                    a su propio administrador.

   COMO SE DECIDE QUIEN ES "ADMINISTRADOR"

   No por el nombre del perfil ni por un IF en C#. Se decide con el mismo
   mecanismo que todo lo demás del sistema: un permiso, RENOVAR SUSCRIPCION,
   colgado de la pantalla ~/Renovar.aspx en Menus. Mañana un cliente quiere
   que su jefe de mantenimiento también pueda renovar: es un INSERT en
   Perfil_Permiso, no un cambio de código ni un despliegue.

   Objetos:
     1. Permiso RENOVAR SUSCRIPCION + la pantalla en Menus
     2. Quien lo tiene, por perfil
     3. FNC_CLIENTE_PUEDE_OPERAR   — un cliente, un BIT, usable en un WHERE
     4. FNC_USUARIO_PUEDE_RENOVAR  — ¿este usuario administra algun cliente?
     5. SEL_LOGIN                  — el rechazo en la puerta
   ============================================================================ */


/* ========================================================================
   1. EL PERMISO Y LA PANTALLA

      La pantalla va con mnu_visible = 0. No es un item de menu: se llega a
      ella por el aviso del encabezado o porque la compuerta te mandó. Un
      item "Mi suscripcion" colgando del arbol obligaria a decidir de que
      nodo cuelga, y el nodo natural -Comercial- es del equipo de SIGMA, no
      del cliente.

      prm_asignable_usuario = 1 a proposito: asi un administrador puede
      dárselo a una persona concreta desde Permisos de Usuario, sin tener
      que cambiarle el perfil entero.
   ======================================================================== */

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_usuario_actualizacion, prm_fecha_actualizacion,
     prm_habilitado, prm_asignable_usuario)
SELECT  N'RENOVAR SUSCRIPCION', N'Ver y renovar la suscripcion de su empresa', N'COMERCIAL',
        (SELECT pam_id FROM [dbo].[Permiso_Ambito] WHERE pam_codigo = N'WEB'),
        N'Quien lo tiene puede entrar aunque la suscripcion este vencida, y ve el saldo y los periodos impagos de su empresa.',
        1, GETDATE(), 1, GETDATE(), 1, 1
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = N'RENOVAR SUSCRIPCION')
GO

DECLARE @COM INT = (SELECT MIN(mnu_id) FROM [dbo].[Menus] WHERE mnu_nombre = N'Comercial' AND mnu_nivel = 2)

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso)
SELECT  N'Mi suscripcion', N'Estado del plan, saldo y renovacion', 4, ISNULL(@COM, 1), 99,
        N'~/Renovar.aspx', 0, NULL,
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'RENOVAR SUSCRIPCION')
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                    WHERE LOWER(mnu_link) = N'~/renovar.aspx' COLLATE DATABASE_DEFAULT)
GO


/* ========================================================================
   2. QUIEN LO TIENE

      Administrador del Cliente, que es de quien se trata todo esto.

      Root y Gerente Comercial tambien, pero por otro motivo: son cuentas de
      plataforma y, cuando entran a configurar un cliente, tienen que poder
      ver en que estado esta su suscripcion. Sin esto, el unico que podria
      mirar la suscripcion de un cliente vencido seria el cliente mismo.

      Nadie mas. Un tecnico, un supervisor o un planificador no ven esta
      pantalla ni entran con la suscripcion caida.
   ======================================================================== */

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  p.per_id,
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'RENOVAR SUSCRIPCION'),
        1, GETDATE()
FROM    [dbo].[Perfiles] p
WHERE   p.per_nombre COLLATE DATABASE_DEFAULT IN (N'Root', N'Gerente Comercial', N'Administrador del Cliente')
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                    WHERE pp.ppe_perfil  = p.per_id
                      AND pp.ppe_permiso = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'RENOVAR SUSCRIPCION'))
GO


/* ========================================================================
   3. FNC_CLIENTE_PUEDE_OPERAR

      El PUEDE_OPERAR de un cliente, en un BIT y sin pasar por un
      procedimiento, para poder preguntarlo dentro de un WHERE o un EXISTS.

      No reimplementa la regla: busca la clave y se la pasa a
      FNC_SUSCRIPCION_VIGENTE, igual que hace SEL_SUSCRIPCION_ESTADO_CLIENTE.
      Que la vigencia se calcule en un solo lugar es lo que evita que la
      web, el login y la API opinen distinto del mismo cliente.

      Sin suscripcion devuelve 1: el cliente que todavia se esta
      configurando no es un moroso.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_CLIENTE_PUEDE_OPERAR] (@CLIENTE INT)
RETURNS BIT
AS
BEGIN
    DECLARE @KEY VARBINARY(32)

    SELECT TOP 1 @KEY = sus_key_hash
      FROM [dbo].[Suscripcion]
     WHERE sus_cliente = @CLIENTE AND sus_habilitado = 1

    IF @KEY IS NULL RETURN 1

    DECLARE @PUEDE BIT

    SELECT @PUEDE = v.PUEDE_OPERAR
      FROM [dbo].[FNC_SUSCRIPCION_VIGENTE](@KEY) v

    /* Un NULL aqui seria una clave que no resuelve a ninguna suscripcion.
       Ante la duda se deja operar: un dato raro no puede dejar afuera a un
       cliente que pago. */
    RETURN ISNULL(@PUEDE, 1)
END
GO


/* ========================================================================
   4. FNC_USUARIO_PUEDE_RENOVAR

      ¿Esta persona administra la suscripcion de alguno de sus clientes?

      Pregunta por CUALQUIERA de sus clientes, no por uno en particular,
      porque en el login todavia no se eligio cliente. El filtro fino -este
      cliente si, aquel no- lo hace despues la compuerta de la web, que si
      sabe con cual se esta trabajando.

      Se apoya en FNC_USUARIO_TIENE_PERMISO, asi que respeta tanto el perfil
      como las excepciones por usuario: si a alguien se le quito el permiso
      a mano, aqui tampoco lo tiene.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_USUARIO_PUEDE_RENOVAR] (@USUARIO INT)
RETURNS BIT
AS
BEGIN
    IF EXISTS (SELECT 1
                 FROM [dbo].[Cliente_Usuario] cu
                WHERE cu.ucl_id_usuario = @USUARIO
                  AND ISNULL(cu.ucl_habilitado, 0) = 1
                  AND [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, cu.ucl_id_cliente, NULL, N'RENOVAR SUSCRIPCION') = 1)
        RETURN 1

    RETURN 0
END
GO


/* ========================================================================
   5. SEL_LOGIN

      Se agrega UN bloque, despues de validar la contrasena y antes de
      sellar el ultimo acceso.

      El orden importa:

      · Va DESPUES de la contrasena porque el estado comercial de una
        empresa no se le cuenta a quien no probo ser de la empresa. Antes,
        seria un oraculo para averiguar que clientes estan vencidos
        probando correos.

      · Va DESPUES de limpiar la racha de intentos fallidos, porque la
        contrasena estuvo bien y castigar por eso seria un error.

      · Va ANTES de usu_ultimo_acceso, porque este acceso no ocurrio.
        Sellarlo ensuciaria el dato justo para el caso en que interesa
        saber que la persona NO pudo entrar.

      Las cuentas de plataforma (@AFILIACIONES = 0) no pasan por aqui: no
      tienen suscripcion propia, y si se las bloqueara no quedaria nadie
      capaz de arreglar la de nadie.
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


/* ---- La contrasena estuvo bien ----
   Se limpia la racha y, si la cuenta venia sin sal, se migra a hash
   aprovechando que aqui tenemos la clave en claro. Ambas cosas pasan aunque
   despues la suscripcion no lo deje entrar: acerto la clave. */
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


/* ---- Suscripcion de la empresa (ANEXO F §6.6) ----

   Si ninguno de sus clientes puede operar, entrar no le sirve de nada:
   cada pantalla lo devolveria a la renovacion. Se le dice aca, en la
   puerta, salvo que sea quien puede hacer algo al respecto.

   Con varios clientes basta que UNO este al dia para entrar. El vencido lo
   atajara la compuerta de la web cuando lo elija, no antes: bloquear todo
   por un cliente moroso dejaria sin sistema a quien trabaja para otros dos
   que si pagan. */
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


/* ---- Acceso concedido ---- */
UPDATE  [dbo].[Usuario]
SET     usu_ultimo_acceso = @AHORA
WHERE   usu_id = @ID

SELECT @ID [ID], '200' [CODE], 'OK' [MENSAJE]
RETURN 0
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */

SELECT  'permiso RENOVAR SUSCRIPCION' AS OBJETO,
        (SELECT COUNT(*) FROM [dbo].[Permiso] WHERE prm_codigo = N'RENOVAR SUSCRIPCION') AS HAY,
        1 AS ESPERADO
UNION ALL
SELECT  'pantalla ~/Renovar.aspx en Menus',
        (SELECT COUNT(*) FROM [dbo].[Menus] WHERE LOWER(mnu_link) = N'~/renovar.aspx' COLLATE DATABASE_DEFAULT),
        1
UNION ALL
SELECT  'perfiles que pueden renovar',
        (SELECT COUNT(*) FROM [dbo].[Perfil_Permiso]
          WHERE ppe_permiso = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'RENOVAR SUSCRIPCION')),
        3
UNION ALL
SELECT  'funciones del bloque 48',
        (SELECT COUNT(*) FROM sys.objects
          WHERE name IN ('FNC_CLIENTE_PUEDE_OPERAR','FNC_USUARIO_PUEDE_RENOVAR')),
        2
UNION ALL
SELECT  'SEL_LOGIN consulta la suscripcion',
        (SELECT COUNT(*) FROM sys.sql_modules
          WHERE object_id = OBJECT_ID('SEL_LOGIN')
            AND definition LIKE '%FNC_CLIENTE_PUEDE_OPERAR%'),
        1
GO
