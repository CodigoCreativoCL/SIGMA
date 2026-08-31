/* ============================================================================
   SIGMA — Bloque 58
   DONDE OPERA CADA PERFIL · EL MENU DE LA APP
   ----------------------------------------------------------------------------

   EL PROBLEMA, EN UNA CONSULTA

     SELECT ... FROM Perfil_Permiso WHERE ppe_perfil = 13   -- Tecnico

     El Tecnico de Mantenimiento tiene hoy VER PLANTAS, VER AREAS,
     VER CATALOGOS y VER GRUPOS TRABAJO. Esos cuatro permisos abren OCHO
     filas de Menus, y las ocho apuntan a paginas .aspx. Es decir: hoy un
     tecnico entra a la web y navega la organizacion del cliente.

     Eso contradice como se decidio que funciona SIGMA: el tecnico trabaja
     desde la app, el Administrador del Cliente configura desde la web. No
     es una preferencia de interfaz, es donde vive cada rol.

   POR QUE NO SE ARREGLA QUITANDOLE PERMISOS AL TECNICO

     Porque los necesita. La app tambien tiene que saber en que plantas
     trabaja, que areas hay y que dice cada catalogo: son los mismos datos,
     leidos desde otro lado. Quitarle VER PLANTAS lo dejaria sin poder
     elegir donde esta parado.

     El permiso dice QUE puede ver. Lo que falta es decir DONDE opera la
     persona. Son dos preguntas distintas y hasta ahora solo existia la
     primera.

   LA COLUMNA QUE FALTABA

     Permiso_Ambito (WEB / APP / AMBOS) ya existe desde el Anexo D, pero
     colgaba solo del permiso. Se agrega donde de verdad decide:

       Perfiles.per_ambito  -> donde puede operar quien tiene ese perfil
       Menus.mnu_ambito     -> en que superficie vive esa opcion

     Con eso:
       · Tecnico = APP   -> SEL_LOGIN lo rechaza en la web, con 403.
       · Administrador del Cliente = WEB -> no entra a la app.
       · Bodeguero, Jefe, Planificador, Supervisor y Prevencionista = AMBOS.

     Y el arbol de la app se resuelve con el MISMO modelo que el de la web:
     una opcion sin fila en Menus no existe. No se cablea en Flutter.

   LO QUE ESTE BLOQUE **NO** HACE

     No inventa menus de app para pantallas que no existen. Hoy la app tiene
     dos: inicio y mi perfil. Las de ordenes, repuestos, checklists y
     permisos de trabajo nacen en el sprint donde se construye la pantalla,
     igual que paso con la web. Un menu que apunta a una pantalla inexistente
     es exactamente el bug que costo tres correcciones en agosto.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. Perfiles.per_ambito

      DF 1 (WEB) a proposito: si manana alguien agrega un perfil y se olvida
      de esta columna, el perfil nace web-only. Equivocarse hacia el lado de
      "no entra a la app" es recuperable; hacia el otro lado es dar acceso
      movil a quien no debia tenerlo.
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.Perfiles') AND name = 'per_ambito')
BEGIN
    ALTER TABLE [dbo].[Perfiles]
        ADD per_ambito INT NOT NULL CONSTRAINT DF_PER_AMBITO DEFAULT (1)
    PRINT 'Perfiles.per_ambito creada'
END
ELSE
    PRINT 'Perfiles.per_ambito ya existia'
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_PER_AMBITO')
BEGIN
    ALTER TABLE [dbo].[Perfiles] WITH CHECK
        ADD CONSTRAINT FK_PER_AMBITO FOREIGN KEY (per_ambito)
            REFERENCES [dbo].[Permiso_Ambito] (pam_id)
    PRINT 'FK_PER_AMBITO creada'
END
GO


/* ========================================================================
   2. Menus.mnu_ambito
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.Menus') AND name = 'mnu_ambito')
BEGIN
    ALTER TABLE [dbo].[Menus]
        ADD mnu_ambito INT NOT NULL CONSTRAINT DF_MNU_AMBITO DEFAULT (1)
    PRINT 'Menus.mnu_ambito creada'
END
ELSE
    PRINT 'Menus.mnu_ambito ya existia'
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_MNU_AMBITO')
BEGIN
    ALTER TABLE [dbo].[Menus] WITH CHECK
        ADD CONSTRAINT FK_MNU_AMBITO FOREIGN KEY (mnu_ambito)
            REFERENCES [dbo].[Permiso_Ambito] (pam_id)
    PRINT 'FK_MNU_AMBITO creada'
END
GO


/* ========================================================================
   3. DONDE OPERA CADA PERFIL

      Root queda en AMBOS porque es la cuenta con la que se prueba todo; si
      no pudiera entrar a la app no habria como verificarla.

      Soporte y Gerente Comercial son WEB: miran y acompanan, no ejecutan
      mantenimiento en terreno.

      Administrador del Cliente es WEB por definicion del modelo: hace la
      configuracion base para que los seis perfiles de terreno operen.
   ======================================================================== */
UPDATE [dbo].[Perfiles] SET per_ambito = 3 WHERE per_id = 1    -- Root
UPDATE [dbo].[Perfiles] SET per_ambito = 1 WHERE per_id = 2    -- Soporte
UPDATE [dbo].[Perfiles] SET per_ambito = 1 WHERE per_id = 3    -- Gerente Comercial
UPDATE [dbo].[Perfiles] SET per_ambito = 1 WHERE per_id = 10   -- Administrador del Cliente

UPDATE [dbo].[Perfiles] SET per_ambito = 3 WHERE per_id = 4    -- Bodeguero
UPDATE [dbo].[Perfiles] SET per_ambito = 3 WHERE per_id = 5    -- Jefe de Mantenimiento
UPDATE [dbo].[Perfiles] SET per_ambito = 3 WHERE per_id = 11   -- Planificador
UPDATE [dbo].[Perfiles] SET per_ambito = 3 WHERE per_id = 12   -- Supervisor
UPDATE [dbo].[Perfiles] SET per_ambito = 3 WHERE per_id = 16   -- Prevencionista

UPDATE [dbo].[Perfiles] SET per_ambito = 2 WHERE per_id = 13   -- Tecnico: SOLO APP
GO

-- Todo lo que ya existe en Menus es web.
UPDATE [dbo].[Menus] SET mnu_ambito = 1 WHERE mnu_ambito IS NULL OR mnu_ambito = 0
GO


/* ========================================================================
   4. FNC_USUARIO_OPERA_AMBITO

      Devuelve 1 si ALGUNO de los perfiles del usuario -globales o del
      cliente- opera en el ambito pedido.

      "Alguno" y no "todos": una persona puede ser Supervisor (AMBOS) y
      ademas Tecnico (APP). Exigir que todos sus perfiles sirvan en la web
      la dejaria fuera por el mas restrictivo, que no es lo que significa
      tener dos roles.
   ======================================================================== */
IF OBJECT_ID('dbo.FNC_USUARIO_OPERA_AMBITO') IS NOT NULL
    DROP FUNCTION [dbo].[FNC_USUARIO_OPERA_AMBITO]
GO

CREATE FUNCTION [dbo].[FNC_USUARIO_OPERA_AMBITO]
(
    @USUARIO INT,
    @AMBITO  INT          -- 1 WEB · 2 APP
)
RETURNS BIT
AS
BEGIN
    DECLARE @R BIT = 0

    IF EXISTS (SELECT 1
                 FROM [dbo].[Usuario_Perfil] upe
                 JOIN [dbo].[Perfiles]       per ON per.per_id = upe.upe_perfil
                WHERE upe.upe_usuario = @USUARIO
                  AND ISNULL(per.per_habilitado, 0) = 1
                  AND per.per_ambito IN (@AMBITO, 3))
        SET @R = 1

    IF (@R = 0 AND EXISTS (SELECT 1
                             FROM [dbo].[Cliente_Usuario]        ucl
                             JOIN [dbo].[Cliente_Usuario_Perfil] cup ON cup.cup_id_cliente_usuario = ucl.ucl_id
                             JOIN [dbo].[Perfiles]               per ON per.per_id = cup.cup_id_perfil
                            WHERE ucl.ucl_id_usuario = @USUARIO
                              AND ISNULL(ucl.ucl_habilitado, 0) = 1
                              AND ISNULL(per.per_habilitado, 0) = 1
                              AND per.per_ambito IN (@AMBITO, 3)))
        SET @R = 1

    RETURN @R
END
GO


/* ========================================================================
   5. SEL_MENU_APP

      El arbol de la app, resuelto por permiso, para un usuario dentro de un
      cliente. Misma semantica que el mapa de la web:

        · Solo filas con mnu_ambito APP o AMBOS.
        · Con permiso, se compara contra los permisos vigentes del usuario
          -perfil + regla puntual, con revocacion- reutilizando
          SEL_USUARIO_PERMISOS a traves de FNC_USUARIO_TIENE_PERMISO.
        · Sin permiso (mnu_permiso NULL) la opcion es visible para quien
          entro. Es el mismo trato que reciben RecuperarClave.aspx y
          SeleccionarCliente.aspx en la web, y aplica solo a pantallas que
          no muestran datos de nadie mas: inicio y mi perfil.

      NO devuelve nodos padre vacios: si a alguien no le quedo ninguna hoja
      debajo de un grupo, el grupo no aparece. Un menu que se abre y no
      tiene nada adentro es peor que no tenerlo.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_MENU_APP') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_MENU_APP]
GO

CREATE PROCEDURE [dbo].[SEL_MENU_APP]
    @USUARIO INT,
    @CLIENTE INT = NULL
AS
SET NOCOUNT ON

    DECLARE @VISIBLES TABLE (mnu_id INT PRIMARY KEY)

    INSERT INTO @VISIBLES (mnu_id)
    SELECT m.mnu_id
    FROM   [dbo].[Menus] m
    WHERE  m.mnu_ambito IN (2, 3)
      AND  ISNULL(m.mnu_visible, 1) = 1
      AND  m.mnu_link IS NOT NULL
      AND  m.mnu_link <> '#'
      AND  ( m.mnu_permiso IS NULL
             OR EXISTS (SELECT 1
                          FROM [dbo].[Permiso] p
                         WHERE p.prm_id = m.mnu_permiso
                           AND [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, p.prm_codigo) = 1) )

    -- Los grupos suben solos: aparecen porque tienen hijos visibles.
    ;WITH padres AS (
        SELECT m.mnu_padre AS mnu_id
        FROM   [dbo].[Menus] m
        JOIN   @VISIBLES v ON v.mnu_id = m.mnu_id
        WHERE  m.mnu_padre IS NOT NULL AND m.mnu_padre > 0
    )
    INSERT INTO @VISIBLES (mnu_id)
    SELECT DISTINCT p.mnu_id
    FROM   padres p
    JOIN   [dbo].[Menus] m ON m.mnu_id = p.mnu_id
    WHERE  m.mnu_ambito IN (2, 3)
      AND  NOT EXISTS (SELECT 1 FROM @VISIBLES x WHERE x.mnu_id = p.mnu_id)

    SELECT  m.mnu_id
           ,m.mnu_nombre
           ,m.mnu_descripcion
           ,m.mnu_nivel
           ,m.mnu_padre
           ,m.mnu_orden
           ,m.mnu_link
           ,m.mnu_icon
           ,pam.pam_codigo AS mnu_ambito
    FROM    [dbo].[Menus] m
    JOIN    @VISIBLES v            ON v.mnu_id  = m.mnu_id
    JOIN    [dbo].[Permiso_Ambito] pam ON pam.pam_id = m.mnu_ambito
    ORDER BY m.mnu_nivel, m.mnu_orden, m.mnu_nombre
GO


/* ========================================================================
   6. LAS DOS OPCIONES QUE LA APP TIENE HOY

      mnu_link no es una ruta de archivo: es el nombre de la ruta en Flutter.
      Se usa el esquema app:// para que quede claro de un vistazo que esa
      fila no apunta a ningun .aspx y que ExigirPagina de la web nunca la va
      a encontrar.
   ======================================================================== */
DECLARE @RAIZ INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_nombre = 'App' AND mnu_nivel = 1)
BEGIN
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre,
                               mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('App', 'Raiz del arbol de la aplicacion movil', 1, 0, 2, '#', 1,
            'mdi mdi-cellphone', NULL, 2)
END

SELECT @RAIZ = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre = 'App' AND mnu_nivel = 1

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = 'app://inicio')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre,
                               mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Inicio', 'Pantalla de entrada de la app', 2, @RAIZ, 1, 'app://inicio', 1,
            'mdi mdi-home-outline', NULL, 2)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = 'app://mi-perfil')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre,
                               mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Mi perfil', 'Datos propios y cambio de contrasena', 2, @RAIZ, 99, 'app://mi-perfil', 1,
            'mdi mdi-account-circle-outline', NULL, 2)
GO


/* ========================================================================
   7. SEL_LOGIN: EL AMBITO SE VALIDA EN LA PUERTA

      @AMBITO llega con DF 1 (WEB) para que la web siga llamando igual y no
      haya que tocar AccesoController. La API pasa 2.

      El chequeo va DESPUES del de perfil y ANTES del de suscripcion: si la
      persona no puede estar en esta superficie, el estado comercial de su
      empresa no viene al caso.

      El mensaje dice donde SI puede entrar. "Acceso denegado" a secas
      manda al tecnico a llamar al administrador por algo que no es un
      problema.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_LOGIN') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_LOGIN]
GO

CREATE PROCEDURE [dbo].[SEL_LOGIN]
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

SET @TIENE_CLIENTE = CASE
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


/* ========================================================================
   8. VERIFICACION
   ======================================================================== */
PRINT '--- Ambito por perfil ---'
SELECT  p.per_id, p.per_nombre, a.pam_codigo AS ambito
FROM    [dbo].[Perfiles] p
JOIN    [dbo].[Permiso_Ambito] a ON a.pam_id = p.per_ambito
ORDER BY p.per_id

PRINT '--- Menus por ambito ---'
SELECT  a.pam_codigo AS ambito, COUNT(*) AS menus
FROM    [dbo].[Menus] m
JOIN    [dbo].[Permiso_Ambito] a ON a.pam_id = m.mnu_ambito
GROUP BY a.pam_codigo

PRINT '--- Quien entra a la web y quien a la app ---'
SELECT  u.usu_id, u.usu_correo
       ,[dbo].[FNC_USUARIO_OPERA_AMBITO](u.usu_id, 1) AS web
       ,[dbo].[FNC_USUARIO_OPERA_AMBITO](u.usu_id, 2) AS app
FROM    [dbo].[Usuario] u
WHERE   ISNULL(u.usu_habilitado, 0) = 1
ORDER BY u.usu_id
GO
