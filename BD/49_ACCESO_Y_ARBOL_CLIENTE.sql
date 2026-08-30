/* ============================================================================
   SIGMA — Bloque 49
   EL ACCESO DEL USUARIO DE CLIENTE
   ----------------------------------------------------------------------------

   Este bloque cierra la ultima capa de FacilityGes que quedaba sin migrar: la
   del perfil.

   EL PROBLEMA DE FONDO

   En FacilityGes el perfil era del USUARIO: una fila en Usuario_Perfil y
   listo. En SIGMA el perfil es del usuario EN CADA CLIENTE
   (Cliente_Usuario_Perfil), porque la misma persona puede ser supervisora en
   una empresa y tecnica en otra.

   La migracion se hizo en la mitad de escritura pero no en la de lectura. Por
   eso los siete usuarios de Hamburgo, que tienen perfil y planta asignada,
   aparecian en pantalla como "no asociados a nada": SEL_CLIENTE_USUARIO
   arrancaba con un EXISTS contra Usuario_Perfil, donde no tenian ninguna fila.

   QUE SE HACE

     1. Se separan dos ideas que hoy viven en un mismo permiso: "ver el modulo
        comercial" y "ver TODOS los clientes en el selector".
     2. Se puebla Usuario_Perfil en espejo, y se deja sincronizado.
     3. Se reescribe SEL_CLIENTE_USUARIO: lee el perfil del cliente y deja de
        armar el WHERE concatenando texto.
     4. SEL_LOGIN rechaza al usuario sin ningun perfil.
     5. El arbol de menus se reordena: lo que es del cliente cuelga de Cliente.

   EL ORDEN NO ES CASUAL. El paso 1 va PRIMERO porque el paso 2 lo requiere:
   poblar Usuario_Perfil sin separar antes los permisos convertiria a cada
   usuario de cliente en "cuenta de plataforma" a ojos del selector, y todos
   verian todas las empresas. Es el bug que estamos arreglando, no uno nuevo.
   ============================================================================ */


/* ========================================================================
   1. "VER CLIENTES" NO PUEDE SEGUIR SIGNIFICANDO DOS COSAS

      SEL_CLIENTE_USUARIO_ELEGIBLE decide quien ve todas las empresas en el
      selector mirando si la persona tiene VER CLIENTES por su perfil global.
      Pero VER CLIENTES es tambien lo que abre el listado del modulo
      Comercial. Son dos cosas distintas metidas en un permiso.

      Mientras nadie de cliente tuviera perfil global, no se notaba. En el
      momento en que poblemos Usuario_Perfil -que es lo que sigue- cualquier
      permiso de mas ahi se convierte en un agujero.

      VER TODO CLIENTES ya existia sin usarse. Pasa a ser el que manda en el
      selector, y se le da a los tres perfiles de plataforma.
   ======================================================================== */

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  p.per_id,
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER TODO CLIENTES'),
        1, GETDATE()
FROM    [dbo].[Perfiles] p
WHERE   p.per_nombre COLLATE DATABASE_DEFAULT IN (N'Root', N'Soporte', N'Gerente Comercial')
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                    WHERE pp.ppe_perfil  = p.per_id
                      AND pp.ppe_permiso = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER TODO CLIENTES'))
GO


CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_USUARIO_ELEGIBLE]
@USUARIO INT
AS
SET NOCOUNT ON

DECLARE @VE_TODOS BIT = 0

/* Se mira el permiso por los perfiles GLOBALES de la persona
   (Usuario_Perfil), no por los de un cliente: justamente estamos
   resolviendo a que cliente puede entrar, asi que todavia no hay uno.

   El permiso es VER TODO CLIENTES, no VER CLIENTES. La diferencia importa:
   un Administrador del Cliente puede necesitar el segundo para administrar
   SU empresa, y eso no debe darle la lista de todas las demas. */
IF EXISTS (SELECT 1
             FROM [dbo].[Usuario_Perfil] up
             JOIN [dbo].[Perfil_Permiso] pp ON pp.ppe_perfil = up.upe_perfil
             JOIN [dbo].[Permiso] p         ON p.prm_id      = pp.ppe_permiso
            WHERE up.upe_usuario = @USUARIO
              AND p.prm_codigo   = N'VER TODO CLIENTES'
              AND p.prm_habilitado = 1)
    SET @VE_TODOS = 1

IF @VE_TODOS = 1
BEGIN
    SELECT  c.cli_id                              AS CLI_ID,
            c.cli_nombre                          AS CLI_NOMBRE,
            c.cli_razon_social                    AS CLI_RAZON_SOCIAL,
            c.cli_identificador                   AS CLI_IDENTIFICADOR,
            ISNULL(c.cli_nombre_fantasia, c.cli_nombre) AS CLI_ETIQUETA
    FROM    [dbo].[Cliente] c
    WHERE   ISNULL(c.cli_habilitado, 0) = 1
    ORDER BY c.cli_nombre

    RETURN(0)
END

SELECT  c.cli_id                              AS CLI_ID,
        c.cli_nombre                          AS CLI_NOMBRE,
        c.cli_razon_social                    AS CLI_RAZON_SOCIAL,
        c.cli_identificador                   AS CLI_IDENTIFICADOR,
        ISNULL(c.cli_nombre_fantasia, c.cli_nombre) AS CLI_ETIQUETA
FROM    [dbo].[Cliente_Usuario] cu
INNER JOIN [dbo].[Cliente] c ON c.cli_id = cu.ucl_id_cliente
WHERE   cu.ucl_id_usuario = @USUARIO
  AND   ISNULL(cu.ucl_habilitado, 0) = 1
  AND   ISNULL(c.cli_habilitado, 0)  = 1
ORDER BY c.cli_nombre

RETURN(0)
GO


/* ========================================================================
   2. USUARIO_PERFIL, EN ESPEJO

      Cliente_Usuario_Perfil es la fuente de verdad. Usuario_Perfil queda como
      su reflejo, porque hay pantallas heredadas que todavia lo consultan y
      reescribirlas todas de una vez es mas riesgo que beneficio.

      INS_CLIENTE_USUARIO ya escribia en las dos (bloque 47). Falta poblar lo
      que nacio antes -los usuarios demo del bloque 38- y hacer que
      UPS_CLIENTE_USUARIO_PERFIL mantenga el espejo cuando alguien cambia de
      perfil desde la pantalla.
   ======================================================================== */

INSERT INTO [dbo].[Usuario_Perfil] (upe_usuario, upe_perfil)
SELECT  DISTINCT cu.ucl_id_usuario, cup.cup_id_perfil
FROM    [dbo].[Cliente_Usuario] cu
JOIN    [dbo].[Cliente_Usuario_Perfil] cup ON cup.cup_id_cliente_usuario = cu.ucl_id
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil] up
                    WHERE up.upe_usuario = cu.ucl_id_usuario
                      AND up.upe_perfil  = cup.cup_id_perfil)
GO


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

    /* El espejo en Usuario_Perfil.

       Se limpia lo que la persona ya no tiene en NINGUN cliente y se agrega
       lo nuevo. La condicion "en ningun cliente" es la que evita el error
       obvio: si es tecnica en Hamburgo y supervisora en otra empresa,
       cambiarle el perfil aqui no puede borrarle el de alla. */
    DELETE  up
    FROM    [dbo].[Usuario_Perfil] up
    WHERE   up.upe_usuario = @USUARIO_DESTINO
      AND   NOT EXISTS (SELECT 1
                          FROM [dbo].[Cliente_Usuario] cu
                          JOIN [dbo].[Cliente_Usuario_Perfil] cup
                            ON cup.cup_id_cliente_usuario = cu.ucl_id
                         WHERE cu.ucl_id_usuario = @USUARIO_DESTINO
                           AND cup.cup_id_perfil = up.upe_perfil)

    INSERT  [dbo].[Usuario_Perfil] (upe_usuario, upe_perfil)
    SELECT  @USUARIO_DESTINO, @PERFIL
    WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil]
                        WHERE upe_usuario = @USUARIO_DESTINO AND upe_perfil = @PERFIL)

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   3. SEL_CLIENTE_USUARIO

      El SP que alimenta la grilla de usuarios del cliente. Heredado de 2011,
      se reescribe entero por tres motivos, en orden de gravedad:

      a) INYECCION SQL. Armaba el WHERE concatenando @FILTRO, que viene del
         cuadro de busqueda de la pantalla. Cualquiera que escriba ahi manda
         SQL a la base. Ahora todo va por parametros.

      b) LEIA LA TABLA EQUIVOCADA. Exigia un perfil en Usuario_Perfil, que es
         el modelo viejo, y unia con CUP_ID_PERFIL = UPE_ID -el mismo bug del
         upe_id que ya se corrigio en la FK y en INS_CLIENTE_USUARIO-. Con un
         cliente en contexto, el perfil sale de Cliente_Usuario_Perfil.

      c) @TIPO_PERFIL FILTRABA POR USUARIO_PERFIL. Por eso el filtro "perfiles
         de tipo Cliente" que se arreglo en la web no podia funcionar: la
         pantalla pedia bien y el SP resolvia contra la tabla que no era.

      Las plantas tambien cambian de origen: USUARIO_INSTALACION es del
      modelo viejo, las autorizaciones vigentes estan en
      Cliente_Instalacion_Usuario.

      Se conservan todas las columnas de salida y la firma, porque hay dos
      metodos del controller y varias pantallas leyendo de aqui. Esto es una
      reparacion, no un rediseño.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_USUARIO]
@ID            INT          = NULL,
@IDENTIFICADOR VARCHAR(MAX) = NULL,
@DEVUELVE_FOTO BIT          = NULL,
@TIPO_PERFIL   INT          = NULL,
@PERFILES      VARCHAR(MAX) = NULL,
@PAISES        VARCHAR(MAX) = NULL,
@CLIENTE       INT          = NULL,
@INSTALACION   INT          = NULL,
@FILTRO        VARCHAR(MAX) = NULL,
@HABILITADO    BIT          = NULL
AS
SET NOCOUNT ON

/* Las listas separadas por coma llegan como texto desde la pantalla. Se
   parten aqui, una vez, en vez de incrustarlas en un IN(...) de texto. */
DECLARE @LISTA_PERFILES TABLE (ID INT PRIMARY KEY)
DECLARE @LISTA_PAISES   TABLE (ID INT PRIMARY KEY)

IF (@PERFILES IS NOT NULL AND LTRIM(RTRIM(@PERFILES)) <> '')
    INSERT @LISTA_PERFILES (ID)
    SELECT DISTINCT TRY_CAST(VALUE AS INT)
      FROM [dbo].[SPLIT](@PERFILES, ',')
     WHERE TRY_CAST(VALUE AS INT) IS NOT NULL

IF (@PAISES IS NOT NULL AND LTRIM(RTRIM(@PAISES)) <> '')
    INSERT @LISTA_PAISES (ID)
    SELECT DISTINCT TRY_CAST(VALUE AS INT)
      FROM [dbo].[SPLIT](@PAISES, ',')
     WHERE TRY_CAST(VALUE AS INT) IS NOT NULL

DECLARE @HAY_PERFILES BIT = CASE WHEN EXISTS (SELECT 1 FROM @LISTA_PERFILES) THEN 1 ELSE 0 END
DECLARE @HAY_PAISES   BIT = CASE WHEN EXISTS (SELECT 1 FROM @LISTA_PAISES)   THEN 1 ELSE 0 END

/* LIKE: los comodines del usuario se escapan para que un '%' escrito en el
   buscador filtre por el caracter '%' y no por "todo". */
DECLARE @LIKE VARCHAR(MAX) =
    CASE WHEN @FILTRO IS NULL THEN NULL
         ELSE '%' + REPLACE(REPLACE(REPLACE(@FILTRO, '[', '[[]'), '%', '[%]'), '_', '[_]') + '%'
    END

;WITH BASE AS
(
    SELECT  u.usu_id,
            u.usu_login,
            u.usu_password,
            u.usu_nombre,
            u.usu_apellido_paterno,
            u.usu_apellido_materno,
            u.usu_identificador,
            u.usu_correo,
            u.usu_telefono,
            u.usu_usuario_creacion,
            u.usu_fecha_creacion,
            u.usu_usuario_act,
            u.usu_fecha_act,
            u.usu_foto,

            /* Habilitado significa cosas distintas segun el contexto: dentro
               de un cliente es la afiliacion la que vale, no la cuenta. */
            USU_HABILITADO = CASE WHEN @CLIENTE IS NULL THEN ISNULL(u.usu_habilitado, 0)
                                  ELSE ISNULL((SELECT TOP 1 cu.ucl_habilitado
                                                 FROM [dbo].[Cliente_Usuario] cu
                                                WHERE cu.ucl_id_usuario = u.usu_id
                                                  AND cu.ucl_id_cliente = @CLIENTE), 0)
                             END,

            /* Los perfiles. Con cliente en contexto son los de ESE cliente;
               sin cliente, los globales. */
            ID_PERFILES = STUFF((SELECT DISTINCT ',' + LTRIM(STR(p.per_id))
                                   FROM [dbo].[Perfiles] p
                                  WHERE (@CLIENTE IS NULL
                                         AND EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil] up
                                                      WHERE up.upe_usuario = u.usu_id
                                                        AND up.upe_perfil  = p.per_id))
                                     OR (@CLIENTE IS NOT NULL
                                         AND EXISTS (SELECT 1
                                                       FROM [dbo].[Cliente_Usuario] cu
                                                       JOIN [dbo].[Cliente_Usuario_Perfil] cup
                                                         ON cup.cup_id_cliente_usuario = cu.ucl_id
                                                      WHERE cu.ucl_id_usuario = u.usu_id
                                                        AND cu.ucl_id_cliente = @CLIENTE
                                                        AND cup.cup_id_perfil = p.per_id))
                                  FOR XML PATH('')), 1, 1, ''),

            PERFILES = STUFF((SELECT DISTINCT ',' + p.per_nombre
                                FROM [dbo].[Perfiles] p
                               WHERE (@CLIENTE IS NULL
                                      AND EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil] up
                                                   WHERE up.upe_usuario = u.usu_id
                                                     AND up.upe_perfil  = p.per_id))
                                  OR (@CLIENTE IS NOT NULL
                                      AND EXISTS (SELECT 1
                                                    FROM [dbo].[Cliente_Usuario] cu
                                                    JOIN [dbo].[Cliente_Usuario_Perfil] cup
                                                      ON cup.cup_id_cliente_usuario = cu.ucl_id
                                                   WHERE cu.ucl_id_usuario = u.usu_id
                                                     AND cu.ucl_id_cliente = @CLIENTE
                                                     AND cup.cup_id_perfil = p.per_id))
                               FOR XML PATH('')), 1, 1, ''),

            ID_PAISES = STUFF((SELECT DISTINCT ',' + LTRIM(STR(pa.pai_id))
                                 FROM [dbo].[Usuario_Paises] upa
                                 JOIN [dbo].[Paises] pa ON pa.pai_id = upa.upa_id_pais
                                WHERE upa.upa_id_usuario = u.usu_id
                                FOR XML PATH('')), 1, 1, ''),

            PAISES = STUFF((SELECT DISTINCT ',' + pa.pai_nombre
                              FROM [dbo].[Usuario_Paises] upa
                              JOIN [dbo].[Paises] pa ON pa.pai_id = upa.upa_id_pais
                             WHERE upa.upa_id_usuario = u.usu_id
                             FOR XML PATH('')), 1, 1, ''),

            ID_CLIENTES = STUFF((SELECT DISTINCT ',' + LTRIM(STR(c.cli_id))
                                   FROM [dbo].[Cliente_Usuario] cu
                                   JOIN [dbo].[Cliente] c ON c.cli_id = cu.ucl_id_cliente
                                  WHERE cu.ucl_id_usuario = u.usu_id
                                  FOR XML PATH('')), 1, 1, ''),

            CLIENTES = STUFF((SELECT DISTINCT ',' + c.cli_nombre
                                FROM [dbo].[Cliente_Usuario] cu
                                JOIN [dbo].[Cliente] c ON c.cli_id = cu.ucl_id_cliente
                               WHERE cu.ucl_id_usuario = u.usu_id
                               FOR XML PATH('')), 1, 1, ''),

            /* Las plantas salen de Cliente_Instalacion_Usuario, que es donde
               vive la autorizacion con su ventana de fechas. */
            ID_INSTALACION = STUFF((SELECT DISTINCT ',' + LTRIM(STR(ci.cin_id))
                                      FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                                      JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = ciu.ciu_id_instalacion
                                     WHERE ciu.ciu_id_usuario = u.usu_id
                                       AND ISNULL(ciu.ciu_habilitado, 0) = 1
                                     FOR XML PATH('')), 1, 1, ''),

            INSTALACION = STUFF((SELECT DISTINCT ',' + ci.cin_nombre
                                   FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                                   JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = ciu.ciu_id_instalacion
                                  WHERE ciu.ciu_id_usuario = u.usu_id
                                    AND ISNULL(ciu.ciu_habilitado, 0) = 1
                                  FOR XML PATH('')), 1, 1, '')

    FROM    [dbo].[Usuario] u

    WHERE   (@ID IS NULL OR u.usu_id = @ID)
      AND   (@IDENTIFICADOR IS NULL OR u.usu_identificador = @IDENTIFICADOR)

      /* Tiene que tener algun perfil en alguna parte. Un usuario sin ningun
         perfil no es un usuario operativo: no puede hacer nada y ensucia la
         grilla. Los perfiles 1 y 2 -Root y Soporte- se excluyen porque son
         cuentas del equipo de SIGMA, no gente del cliente. */
      AND   ( EXISTS (SELECT 1
                        FROM [dbo].[Cliente_Usuario] cu
                        JOIN [dbo].[Cliente_Usuario_Perfil] cup ON cup.cup_id_cliente_usuario = cu.ucl_id
                       WHERE cu.ucl_id_usuario = u.usu_id
                         AND cup.cup_id_perfil NOT IN (1, 2))
              OR EXISTS (SELECT 1
                           FROM [dbo].[Usuario_Perfil] up
                          WHERE up.upe_usuario = u.usu_id
                            AND up.upe_perfil NOT IN (1, 2)) )

      /* El tipo de perfil se resuelve donde corresponda: con cliente en
         contexto, contra el perfil de ese cliente. */
      AND   ( @TIPO_PERFIL IS NULL
              OR ( @CLIENTE IS NOT NULL
                   AND EXISTS (SELECT 1
                                 FROM [dbo].[Cliente_Usuario] cu
                                 JOIN [dbo].[Cliente_Usuario_Perfil] cup ON cup.cup_id_cliente_usuario = cu.ucl_id
                                 JOIN [dbo].[Perfiles] p ON p.per_id = cup.cup_id_perfil
                                WHERE cu.ucl_id_usuario = u.usu_id
                                  AND cu.ucl_id_cliente = @CLIENTE
                                  AND p.per_tipo        = @TIPO_PERFIL) )
              OR ( @CLIENTE IS NULL
                   AND EXISTS (SELECT 1
                                 FROM [dbo].[Usuario_Perfil] up
                                 JOIN [dbo].[Perfiles] p ON p.per_id = up.upe_perfil
                                WHERE up.upe_usuario = u.usu_id
                                  AND p.per_tipo     = @TIPO_PERFIL) ) )

      AND   ( @HAY_PERFILES = 0
              OR ( @CLIENTE IS NOT NULL
                   AND EXISTS (SELECT 1
                                 FROM [dbo].[Cliente_Usuario] cu
                                 JOIN [dbo].[Cliente_Usuario_Perfil] cup ON cup.cup_id_cliente_usuario = cu.ucl_id
                                WHERE cu.ucl_id_usuario = u.usu_id
                                  AND cu.ucl_id_cliente = @CLIENTE
                                  AND cup.cup_id_perfil IN (SELECT ID FROM @LISTA_PERFILES)) )
              OR ( @CLIENTE IS NULL
                   AND EXISTS (SELECT 1
                                 FROM [dbo].[Usuario_Perfil] up
                                WHERE up.upe_usuario = u.usu_id
                                  AND up.upe_perfil IN (SELECT ID FROM @LISTA_PERFILES)) ) )

      AND   ( @HAY_PAISES = 0
              OR EXISTS (SELECT 1 FROM [dbo].[Usuario_Paises] upa
                          WHERE upa.upa_id_usuario = u.usu_id
                            AND upa.upa_id_pais IN (SELECT ID FROM @LISTA_PAISES)) )

      AND   ( @CLIENTE IS NULL
              OR EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario] cu
                          WHERE cu.ucl_id_usuario = u.usu_id
                            AND cu.ucl_id_cliente = @CLIENTE) )

      AND   ( @INSTALACION IS NULL
              OR EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                          WHERE ciu.ciu_id_usuario     = u.usu_id
                            AND ciu.ciu_id_instalacion = @INSTALACION) )

      AND   ( @LIKE IS NULL
              OR u.usu_nombre            LIKE @LIKE
              OR u.usu_apellido_paterno  LIKE @LIKE
              OR u.usu_apellido_materno  LIKE @LIKE
              OR u.usu_identificador     LIKE @LIKE
              OR u.usu_login             LIKE @LIKE
              OR LTRIM(STR(u.usu_id))    LIKE @LIKE )

      AND   ( @HABILITADO IS NULL
              OR EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario] cu
                          WHERE cu.ucl_id_usuario = u.usu_id
                            AND cu.ucl_habilitado = @HABILITADO) )
)

/* La foto es binaria y traerla para cada fila de una grilla de cientos de
   usuarios es caro: solo se paga cuando se pide. */
SELECT  b.usu_id                 AS USU_ID,
        b.usu_login              AS USU_LOGIN,
        /* El hash solo viaja cuando se pide UNA persona: la ficha lo
           reenvia al guardar. En la grilla no lo lee nadie, y mandar el
           hash de cada usuario del cliente en cada refresco de pantalla es
           regalar material para atacar sin ninguna contrapartida. */
        CASE WHEN @ID IS NOT NULL THEN b.usu_password END AS USU_PASSWORD,
        b.usu_nombre             AS USU_NOMBRE,
        b.usu_apellido_paterno   AS USU_APELLIDO_PATERNO,
        b.usu_apellido_materno   AS USU_APELLIDO_MATERNO,
        b.usu_identificador      AS USU_IDENTIFICADOR,
        b.usu_correo             AS USU_CORREO,
        b.usu_telefono           AS USU_TELEFONO,
        b.usu_usuario_creacion   AS USU_USUARIO_CREACION,
        b.usu_fecha_creacion     AS USU_FECHA_CREACION,
        b.usu_usuario_act        AS USU_USUARIO_ACT,
        b.usu_fecha_act          AS USU_FECHA_ACT,
        b.USU_HABILITADO,
        b.ID_PERFILES, b.PERFILES,
        b.ID_PAISES,   b.PAISES,
        b.ID_CLIENTES, b.CLIENTES,
        b.ID_INSTALACION, b.INSTALACION,
        CASE WHEN @DEVUELVE_FOTO = 1 THEN b.usu_foto END       AS USU_FOTO,
        CASE WHEN @DEVUELVE_FOTO = 1 THEN uft.uft_binario END  AS UFT_BINARIO,
        CASE WHEN @DEVUELVE_FOTO = 1 THEN uft.uft_extension END AS UFT_EXTENSION
FROM    BASE b
LEFT JOIN [dbo].[Usuario_Foto] uft
       ON @DEVUELVE_FOTO = 1 AND uft.uft_usuario = b.usu_id
ORDER BY CASE WHEN @CLIENTE IS NULL THEN b.USU_HABILITADO END DESC,
         b.usu_id DESC

RETURN(0)
GO


/* ========================================================================
   4. SEL_LOGIN: SIN PERFIL NO SE ENTRA

      Un usuario de cliente sin ningun perfil no puede hacer nada: resuelve
      cero permisos, el menu le queda vacio y cada pantalla que pida lo
      devuelve al tablero. Dejarlo entrar es dejarlo dando vueltas por un
      sistema donde no hay nada para el.

      Va junto al chequeo de suscripcion, con la misma logica de ubicacion:
      despues de la contrasena, antes de sellar el ultimo acceso.
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
   alta al primer cliente en HU-010. */
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
   despues no lo dejen entrar: acerto la clave. */
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


/* ---- Suscripcion de la empresa (ANEXO F §6.6) ----

   Si ninguno de sus clientes puede operar, entrar no le sirve de nada:
   cada pantalla lo devolveria a la renovacion. Se le dice aca, en la
   puerta, salvo que sea quien puede hacer algo al respecto.

   Con varios clientes basta que UNO este al dia para entrar. El vencido lo
   atajara la compuerta de la web cuando lo elija, no antes. */
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
   5. EL ARBOL: LO QUE ES DEL CLIENTE CUELGA DE CLIENTE

      Un usuario de Hamburgo veia los nodos "Sistema" y "Comercial", que son
      del sitio de la plataforma. No era un bug del menu -el menu dibuja un
      contenedor cuando algun hijo se ve, y eso esta bien- sino de donde
      estaban colgadas las pantallas: Organizacion, Catalogos y Permisos por
      usuario son del cliente, pero vivian fuera.

      El nodo pasa a llamarse en singular porque es TU empresa, no el listado
      de empresas. El listado se queda en Comercial, que es donde SIGMA da de
      alta clientes.

      Las pantallas se cuelgan PLANAS y no dentro de un sub-nodo
      "Organizacion": el menu lateral solo emite una clase de anidamiento
      (nav-second-level) y un tercer nivel quedaria sin estilo. Nueve items
      en un nivel se leen bien; un tercer nivel sin CSS, no. Cuando se
      verifique el tercer nivel en navegador se puede volver a agrupar.
   ======================================================================== */

UPDATE [dbo].[Menus] SET mnu_nombre = N'Cliente' WHERE mnu_id = 32
GO

/* Las cinco pantallas de Organizacion y sus fichas. */
UPDATE [dbo].[Menus] SET mnu_padre = 32, mnu_nivel = 3, mnu_orden = 3  WHERE mnu_id = 2080  -- Plantas
UPDATE [dbo].[Menus] SET mnu_padre = 32, mnu_nivel = 3, mnu_orden = 4  WHERE mnu_id = 2081  -- Areas
UPDATE [dbo].[Menus] SET mnu_padre = 32, mnu_nivel = 3, mnu_orden = 5  WHERE mnu_id = 2082  -- Centros de Costo
UPDATE [dbo].[Menus] SET mnu_padre = 32, mnu_nivel = 3, mnu_orden = 6  WHERE mnu_id = 2083  -- Grupos de Trabajo
UPDATE [dbo].[Menus] SET mnu_padre = 32, mnu_nivel = 3, mnu_orden = 7  WHERE mnu_id = 2088  -- Especialidades
UPDATE [dbo].[Menus] SET mnu_padre = 32, mnu_nivel = 4 WHERE mnu_id IN (2084, 2085, 2086, 2087, 2095)
GO

/* Catalogos: son los catalogos DEL CLIENTE, no los del sistema. */
UPDATE [dbo].[Menus] SET mnu_padre = 32, mnu_nivel = 3, mnu_orden = 8 WHERE mnu_id = 2089
UPDATE [dbo].[Menus] SET mnu_padre = 32, mnu_nivel = 4 WHERE mnu_id = 2094
GO

/* Permisos por usuario: es como un administrador ajusta a UNA persona de su
   empresa. La tabla que hay detras, Cliente_Usuario_Permiso, ya es por
   cliente; el menu estaba en el lugar equivocado. */
UPDATE [dbo].[Menus] SET mnu_padre = 32, mnu_nivel = 3, mnu_orden = 9 WHERE mnu_id = 2090
UPDATE [dbo].[Menus] SET mnu_padre = 32, mnu_nivel = 4 WHERE mnu_id = 2091
GO

/* El contenedor Organizacion queda sin hijos: se retira. */
DELETE FROM [dbo].[Menus]
WHERE  mnu_id = 2079
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Menus] h WHERE h.mnu_padre = 2079)
GO

/* Nodo de pruebas que quedo del armado inicial y no lleva a ninguna parte. */
DELETE FROM [dbo].[Menus]
WHERE  mnu_id = 2078
  AND  mnu_link = '#'
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Menus] h WHERE h.mnu_padre = 2078)
GO

/* Reasignacion Clientes estaba en nivel 2 colgando de otro nivel 2. */
UPDATE [dbo].[Menus] SET mnu_nivel = 3 WHERE mnu_id = 31 AND mnu_padre = 24
GO


/* ========================================================================
   5b. LA MATRIZ: UN PERFIL DE CLIENTE NO ADMINISTRA LA PLATAFORMA

      Se le quitan a TODO perfil de tipo Cliente los permisos cuyas pantallas
      viven en el sitio de la plataforma:

        VER USUARIOS, VER PERFILES, VER ACCESOS
            son los mantenedores globales. El administrador del cliente
            gestiona a su gente por Cliente > Usuarios, que solo ve la suya.

        VER PLANES COMERCIALES, VER SUSCRIPCIONES, VER PAGOS SUSCRIPCION
            son la vista de TODAS las suscripciones. Lo que el cliente
            necesita -su plan, su saldo, sus periodos impagos- lo tiene en
            Renovar.aspx, que es suyo y solo muestra lo suyo.

      Se conservan RENOVAR SUSCRIPCION y DECLARAR PAGO SUSCRIPCION: el
      primero abre Renovar.aspx; el segundo es la funcion de declarar el
      pago, que hoy vive en Pagos.aspx y debe mudarse a Renovar.aspx cuando
      exista la API de almacenamiento (sin comprobante no se puede declarar).
   ======================================================================== */

DELETE  pp
FROM    [dbo].[Perfil_Permiso] pp
JOIN    [dbo].[Perfiles] p  ON p.per_id  = pp.ppe_perfil
JOIN    [dbo].[Permiso]  pr ON pr.prm_id = pp.ppe_permiso
WHERE   p.per_tipo = 2
  AND   pr.prm_codigo COLLATE DATABASE_DEFAULT IN
        (N'VER USUARIOS', N'VER PERFILES', N'VER ACCESOS',
         N'VER PLANES COMERCIALES', N'VER SUSCRIPCIONES', N'VER PAGOS SUSCRIPCION')
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */

SELECT  'VER TODO CLIENTES asignado' AS OBJETO,
        (SELECT COUNT(*) FROM [dbo].[Perfil_Permiso]
          WHERE ppe_permiso = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER TODO CLIENTES')) AS HAY,
        3 AS ESPERADO
UNION ALL
SELECT  'el selector usa VER TODO CLIENTES',
        (SELECT COUNT(*) FROM sys.sql_modules
          WHERE object_id = OBJECT_ID('SEL_CLIENTE_USUARIO_ELEGIBLE')
            AND definition LIKE '%VER TODO CLIENTES%'), 1
UNION ALL
SELECT  'usuarios de cliente sin espejo en Usuario_Perfil',
        (SELECT COUNT(*)
           FROM [dbo].[Cliente_Usuario] cu
           JOIN [dbo].[Cliente_Usuario_Perfil] cup ON cup.cup_id_cliente_usuario = cu.ucl_id
          WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil] up
                            WHERE up.upe_usuario = cu.ucl_id_usuario
                              AND up.upe_perfil  = cup.cup_id_perfil)), 0
UNION ALL
SELECT  'SEL_CLIENTE_USUARIO sin SQL concatenado',
        (SELECT COUNT(*) FROM sys.sql_modules
          WHERE object_id = OBJECT_ID('SEL_CLIENTE_USUARIO')
            AND definition NOT LIKE '%EXEC(@SELECT%'), 1
UNION ALL
SELECT  'SEL_LOGIN rechaza sin perfil',
        (SELECT COUNT(*) FROM sys.sql_modules
          WHERE object_id = OBJECT_ID('SEL_LOGIN')
            AND definition LIKE '%CUENTA SIN PERFIL%'), 1
UNION ALL
SELECT  'pantallas visibles bajo el nodo Cliente',
        (SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_padre = 32 AND mnu_visible = 1), 9
UNION ALL
SELECT  'nodo Organizacion retirado',
        (SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_id = 2079), 0
UNION ALL
SELECT  'permisos de plataforma en perfiles de cliente',
        (SELECT COUNT(*)
           FROM [dbo].[Perfil_Permiso] pp
           JOIN [dbo].[Perfiles] p  ON p.per_id  = pp.ppe_perfil
           JOIN [dbo].[Permiso]  pr ON pr.prm_id = pp.ppe_permiso
          WHERE p.per_tipo = 2
            AND pr.prm_codigo COLLATE DATABASE_DEFAULT IN
                (N'VER USUARIOS', N'VER PERFILES', N'VER ACCESOS',
                 N'VER PLANES COMERCIALES', N'VER SUSCRIPCIONES', N'VER PAGOS SUSCRIPCION')), 0
GO
