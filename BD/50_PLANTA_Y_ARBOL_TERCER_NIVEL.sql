/* ============================================================================
   SIGMA — Bloque 50
   ORGANIZACION VUELVE A SER UN GRUPO · "PLANTA", NO "INSTALACION"
   ----------------------------------------------------------------------------

   Tres cosas, en orden de importancia:

     1. Dos bugs en DEL_USUARIO_ASOCIACION, que aparecieron al revisar los
        rotulos. Van primero porque son los unicos que pierden datos.
     2. El arbol: Organizacion vuelve como grupo, con sus pantallas en un
        tercer nivel bajo Cliente.
     3. Los rotulos: en SIGMA se llaman PLANTAS. "Instalacion" es el nombre
        de la tabla, no lo que lee la persona.

   SOBRE EL PUNTO 3: no se renombra nada del esquema. Cliente_Instalacion,
   cin_*, INS_CLIENTE_INSTALACION y los ids siguen igual. Renombrar tablas y
   SPs para cambiar una palabra que solo se ve en pantalla seria mucho riesgo
   por ninguna ganancia. Lo que cambia es lo que el usuario lee.

   Y una excepcion que NO se toca: en Suscripcion.aspx, "su instalacion" se
   refiere al software del cliente -su integracion contra la API-, no a una
   planta. Ahi la palabra esta bien usada.
   ============================================================================ */


/* ========================================================================
   1. DEL_USUARIO_ASOCIACION

      a) COMPARABA EL ID EQUIVOCADO. Buscaba en Cliente_Instalacion_Usuario
         por CIU_ID_USUARIO = @CLIENTE_USUARIO, que es el ucl_id de
         Cliente_Usuario. Pero ahi va el usu_id: el bloque 47 corrigio
         INS_CLIENTE_USUARIO_ASOCIAR, que escribia el ucl_id, y agrego la FK
         que lo obliga. Este SP quedo del lado viejo.

         La consecuencia es doble y silenciosa. El guard "no puedo eliminar,
         tiene plantas asignadas" no encontraba nada y dejaba pasar; y el
         DELETE de la planta borraba por un id que no existe, o -peor- el
         de otra persona cuyo usu_id coincidiera con este ucl_id. Con los
         datos de hoy los ucl_id van del 11 al 17 y los usu_id del 7 al 13:
         se pisan.

      b) NO LIMPIABA USUARIO_PERFIL. Desde el bloque 49 esa tabla es el
         espejo de Cliente_Usuario_Perfil. Al desafiliar a alguien se
         borraba su perfil del cliente pero le quedaba el global, y con eso
         seguia pasando el control de SEL_LOGIN: una persona sacada del
         sistema podia entrar igual.

      Se limpia igual que en UPS_CLIENTE_USUARIO_PERFIL: solo lo que ya no
      tiene en NINGUN cliente, para no romper a quien trabaja para dos.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_USUARIO_ASOCIACION]
@ID             INT = NULL OUTPUT,
@CLIENTE        INT,
@ID_USUARIO     INT,
@ID_INSTALACION INT = NULL,
@USUARIO        INT
AS
SET NOCOUNT ON

DECLARE @CLIENTE_USUARIO INT

SELECT  @CLIENTE_USUARIO = UCL_ID
FROM    [dbo].[Cliente_Usuario]
WHERE   UCL_ID_CLIENTE = @CLIENTE
  AND   UCL_ID_USUARIO = @ID_USUARIO

/* Quitar a la persona del cliente entero exige que antes la hayan sacado de
   sus plantas. No es burocracia: la autorizacion por planta es lo que
   habilita a firmar y cerrar trabajo, y borrarla de refilon dejaria ordenes
   con un responsable que ya no existe. */
IF (@ID_INSTALACION IS NULL)
BEGIN
    IF EXISTS (SELECT TOP 1 1
                 FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                 JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = ciu.ciu_id_instalacion
                WHERE ci.cin_cliente     = @CLIENTE
                  AND ciu.ciu_id_usuario = @ID_USUARIO)
    BEGIN
        RAISERROR('1. No es posible eliminar, el usuario está asociado a una planta', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    IF @ID_INSTALACION IS NOT NULL
    BEGIN
        DELETE  [dbo].[Cliente_Instalacion_Usuario]
        WHERE   CIU_ID_USUARIO     = @ID_USUARIO
          AND   CIU_ID_INSTALACION = @ID_INSTALACION

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION
            DECLARE @VARIABLES VARCHAR(MAX)
            SET @VARIABLES = 'DEL_USUARIO_ASOCIACION @ID_USUARIO = ' + LTRIM(STR(@ID_USUARIO))
                           + ', @ID_INSTALACION = ' + LTRIM(STR(@ID_INSTALACION))
            EXEC [dbo].[INS_EXCEPCION]
                 @MSG       = '1.- NO FUE POSIBLE QUITAR AL USUARIO DE LA PLANTA.',
                 @VARIABLES = @VARIABLES
            RETURN -1
        END
    END
    ELSE
    BEGIN
        DELETE  [dbo].[Cliente_Usuario_Perfil]
        WHERE   CUP_ID_CLIENTE_USUARIO IN (SELECT UCL_ID
                                             FROM [dbo].[Cliente_Usuario]
                                            WHERE UCL_ID_CLIENTE = @CLIENTE
                                              AND UCL_ID_USUARIO = @ID_USUARIO)

        DELETE  [dbo].[Cliente_Usuario]
        WHERE   UCL_ID_CLIENTE = @CLIENTE
          AND   UCL_ID_USUARIO = @ID_USUARIO

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION
            DECLARE @VARS VARCHAR(MAX)
            SET @VARS = 'DEL_USUARIO_ASOCIACION @ID_USUARIO = ' + LTRIM(STR(@ID_USUARIO))
                      + ', @CLIENTE = ' + LTRIM(STR(@CLIENTE))
            EXEC [dbo].[INS_EXCEPCION]
                 @MSG       = '2.- NO FUE POSIBLE ELIMINAR EL CLIENTE_USUARIO.',
                 @VARIABLES = @VARS
            RETURN -1
        END

        /* El espejo. Sin esto la persona conserva su perfil global y sigue
           pasando el control "sin perfil no se entra" de SEL_LOGIN. */
        DELETE  up
        FROM    [dbo].[Usuario_Perfil] up
        WHERE   up.upe_usuario = @ID_USUARIO
          AND   NOT EXISTS (SELECT 1
                              FROM [dbo].[Cliente_Usuario] cu
                              JOIN [dbo].[Cliente_Usuario_Perfil] cup
                                ON cup.cup_id_cliente_usuario = cu.ucl_id
                             WHERE cu.ucl_id_usuario = @ID_USUARIO
                               AND cup.cup_id_perfil = up.upe_perfil)
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   2. DEL_CLIENTE: el mensaje

      Mismo SP, solo cambia lo que lee la persona.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_CLIENTE]
 @ID      INT
,@USUARIO INT
AS
SET NOCOUNT ON

    -- Unico guard: si el cliente tiene plantas, no se borra.
    -- Todo lo demas del modelo cuelga de la planta.
    IF (EXISTS(SELECT TOP 1 1 FROM [dbo].[Cliente_Instalacion] WHERE CIN_CLIENTE = @ID))
    BEGIN
        RAISERROR('1. No es posible eliminar, el cliente posee plantas', 16, 1);
        RETURN -1;
    END

    BEGIN TRANSACTION

        DELETE  [dbo].[Cliente_Usuario_Perfil]
        WHERE   CUP_ID_CLIENTE_USUARIO IN (SELECT UCL_ID
                                           FROM   [dbo].[Cliente_Usuario]
                                           WHERE  UCL_ID_CLIENTE = @ID)

        DELETE  [dbo].[Cliente_Usuario]
        WHERE   UCL_ID_CLIENTE = @ID

        DELETE  [dbo].[Cliente]
        WHERE   CLI_ID = @ID

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION
            DECLARE @VARIABLES VARCHAR(MAX)
            SET @VARIABLES = 'DEL_CLIENTE ' + LTRIM(STR(@ID))
            EXEC [dbo].[INS_EXCEPCION]
                 @MSG       = '1.- No fue posible Eliminar el Cliente.',
                 @VARIABLES = @VARIABLES
            RETURN -1
        END

    COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   3. EL ARBOL: ORGANIZACION VUELVE, AHORA ADENTRO

      El bloque 49 colgo las cinco pantallas de Organizacion planas bajo
      Cliente, porque el menu lateral marcaba todos los submenus como
      nav-second-level y un tercer nivel salia con la misma sangria que el
      segundo: se veia como una lista de nueve cosas sueltas.

      Eso ya esta arreglado en la web -MenusLateral emite nav-third-level y
      sigma-layout.css le da sangria y una linea que marca de donde cuelga-,
      asi que el grupo puede volver, que es como se lee mejor:

          Cliente
            Identidad
            Usuarios
            Organizacion
              Plantas · Areas · Centros de Costo · Grupos · Especialidades
            Catalogos
            Permisos por usuario
   ======================================================================== */

DECLARE @ORG INT

SELECT @ORG = mnu_id FROM [dbo].[Menus]
 WHERE mnu_padre = 32 AND mnu_nombre = N'Organización' COLLATE DATABASE_DEFAULT

IF @ORG IS NULL
BEGIN
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso)
    VALUES
        (N'Organización', N'Como se ordena la empresa: plantas, areas, centros de costo, grupos y especialidades',
         3, 32, 3, '#', 1, 'mdi mdi-sitemap', NULL)

    SET @ORG = SCOPE_IDENTITY()
END

/* Las cinco pantallas pasan a colgar del grupo. */
UPDATE [dbo].[Menus] SET mnu_padre = @ORG, mnu_nivel = 4, mnu_orden = 1 WHERE mnu_id = 2080  -- Plantas
UPDATE [dbo].[Menus] SET mnu_padre = @ORG, mnu_nivel = 4, mnu_orden = 2 WHERE mnu_id = 2081  -- Areas
UPDATE [dbo].[Menus] SET mnu_padre = @ORG, mnu_nivel = 4, mnu_orden = 3 WHERE mnu_id = 2082  -- Centros de Costo
UPDATE [dbo].[Menus] SET mnu_padre = @ORG, mnu_nivel = 4, mnu_orden = 4 WHERE mnu_id = 2083  -- Grupos de Trabajo
UPDATE [dbo].[Menus] SET mnu_padre = @ORG, mnu_nivel = 4, mnu_orden = 5 WHERE mnu_id = 2088  -- Especialidades

/* Y sus fichas, que no se ven pero deben quedar donde corresponde: el
   mantenedor de menus las muestra en arbol, y una ficha colgando del nodo
   equivocado se lee como un error. */
UPDATE [dbo].[Menus] SET mnu_padre = @ORG, mnu_nivel = 5 WHERE mnu_id IN (2084, 2085, 2086, 2087, 2095)

/* Nueva planta es la ficha de Plantas: va con ellas, no suelta bajo Cliente. */
UPDATE [dbo].[Menus] SET mnu_padre = @ORG, mnu_nivel = 5 WHERE mnu_id = 2075

/* Catalogos y Permisos por usuario corren un lugar: Organizacion tomo el 3. */
UPDATE [dbo].[Menus] SET mnu_orden = 4 WHERE mnu_id = 2089
UPDATE [dbo].[Menus] SET mnu_orden = 5 WHERE mnu_id = 2090
GO


/* ========================================================================
   4. LOS ROTULOS: PLANTA
   ======================================================================== */

UPDATE [dbo].[Menus]
SET    mnu_nombre      = N'Nueva planta',
       mnu_descripcion = N'Ficha de la planta'
WHERE  mnu_id = 2075

UPDATE [dbo].[Menus]
SET    mnu_descripcion = N'Plantas del cliente'
WHERE  mnu_id = 2080

UPDATE [dbo].[Menus]
SET    mnu_nombre = REPLACE(REPLACE(mnu_nombre, N'Instalación', N'Planta'), N'instalación', N'planta')
WHERE  mnu_nombre LIKE N'%nstalación%'

UPDATE [dbo].[Permiso]
SET    prm_nombre = REPLACE(REPLACE(prm_nombre, N'Instalación', N'Planta'), N'instalación', N'planta')
WHERE  prm_nombre LIKE N'%nstalación%'
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */

DECLARE @ORG2 INT = (SELECT mnu_id FROM [dbo].[Menus]
                      WHERE mnu_padre = 32 AND mnu_nombre = N'Organización' COLLATE DATABASE_DEFAULT)

SELECT  'grupo Organizacion bajo Cliente' AS OBJETO,
        (SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_id = @ORG2) AS HAY, 1 AS ESPERADO
UNION ALL
SELECT  'pantallas visibles dentro de Organizacion',
        (SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_padre = @ORG2 AND mnu_visible = 1), 5
UNION ALL
SELECT  'items visibles directos bajo Cliente',
        (SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_padre = 32 AND mnu_visible = 1), 5
UNION ALL
SELECT  'menus que todavia dicen Instalacion',
        (SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_nombre LIKE N'%nstalaci%'), 0
UNION ALL
/* Se busca el uso CORRECTO, no la ausencia del incorrecto: el texto del bug
   viejo sigue estando -en el comentario que lo explica- y un NOT LIKE lo
   encontraba ahi. Y va con ESCAPE porque en LIKE el guion bajo es comodin:
   sin el, CIU_ID_USUARIO tambien casa con CIUxIDxUSUARIO. */
SELECT  'DEL_USUARIO_ASOCIACION compara contra el usu_id',
        (SELECT COUNT(*) FROM sys.sql_modules
          WHERE object_id = OBJECT_ID('DEL_USUARIO_ASOCIACION')
            AND definition LIKE '%CIU!_ID!_USUARIO     = @ID!_USUARIO%' ESCAPE '!'), 1
UNION ALL
SELECT  'DEL_USUARIO_ASOCIACION limpia el espejo',
        (SELECT COUNT(*) FROM sys.sql_modules
          WHERE object_id = OBJECT_ID('DEL_USUARIO_ASOCIACION')
            AND definition LIKE '%Usuario_Perfil%'), 1
GO
