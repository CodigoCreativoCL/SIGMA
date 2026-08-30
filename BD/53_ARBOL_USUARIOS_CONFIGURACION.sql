/* ============================================================================
   SIGMA — Bloque 53
   EL ARBOL DEL CLIENTE, POR TEMA
   ----------------------------------------------------------------------------

   Bajo Cliente convivian cosas de tres naturalezas distintas al mismo nivel:
   la identidad de la empresa, su gente, donde ocurre el trabajo, y los
   catalogos de apoyo. Con Organizacion agrupada (bloque 50) quedaban todavia
   Usuarios, Permisos por usuario y Catalogos sueltos, y las fichas de usuario
   colgando directamente de Cliente.

   Queda asi:

     Cliente
       Identidad
       Usuarios
         Usuarios · Permisos por usuario · Especialidades · Grupos de Trabajo
       Organizacion
         Plantas · Areas · Centros de Costo
       Configuracion
         Catalogos

   POR QUE ESPECIALIDADES Y GRUPOS SE MUEVEN A USUARIOS

   Estaban en Organizacion, y es defendible: son estructura. Pero las dos
   hablan de PERSONAS -que sabe hacer cada una, en que cuadrilla esta- y no
   de lugares. Organizacion queda con lo que responde "donde": planta, area,
   centro de costo. Usuarios con lo que responde "quien".

   Quien busca "como le doy permiso de firmar a Fulano" no piensa en
   organizacion; piensa en usuarios. El arbol tiene que seguir esa pregunta.

   POR QUE UN NODO "CONFIGURACION" CON UNA SOLA COSA ADENTRO

   Porque los catalogos no son ni gente ni lugares: son los valores que el
   cliente ajusta para que el sistema hable su idioma -tipos de area, niveles
   de especialidad-. Ponerlos junto a Usuarios o a Plantas obliga a buscarlos
   en el lugar equivocado. Y el nodo va a crecer: todo mantenedor de apoyo al
   cliente que venga entra aqui y no vuelve a discutirse donde ponerlo.
   ============================================================================ */


/* ========================================================================
   1. LOS DOS NODOS NUEVOS
   ======================================================================== */

DECLARE @USU INT, @CFG INT

SELECT @USU = mnu_id FROM [dbo].[Menus]
 WHERE mnu_padre = 32 AND mnu_link = '#' AND mnu_nombre = N'Usuarios' COLLATE DATABASE_DEFAULT

IF @USU IS NULL
BEGIN
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso)
    VALUES
        (N'Usuarios', N'Las personas de la empresa: quienes son, que pueden hacer y en que equipo estan',
         3, 32, 2, '#', 1, 'mdi mdi-account-group', NULL)

    SET @USU = SCOPE_IDENTITY()
END

SELECT @CFG = mnu_id FROM [dbo].[Menus]
 WHERE mnu_padre = 32 AND mnu_link = '#' AND mnu_nombre = N'Configuración' COLLATE DATABASE_DEFAULT

IF @CFG IS NULL
BEGIN
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso)
    VALUES
        (N'Configuración', N'Los valores que la empresa ajusta para que el sistema hable su idioma',
         3, 32, 4, '#', 1, 'mdi mdi-tune', NULL)

    SET @CFG = SCOPE_IDENTITY()
END


/* ========================================================================
   2. LO QUE ES DE PERSONAS, BAJO USUARIOS
   ======================================================================== */

UPDATE [dbo].[Menus] SET mnu_padre = @USU, mnu_nivel = 4, mnu_orden = 1 WHERE mnu_id = 41    -- Usuarios
UPDATE [dbo].[Menus] SET mnu_padre = @USU, mnu_nivel = 4, mnu_orden = 2 WHERE mnu_id = 2090  -- Permisos por usuario
UPDATE [dbo].[Menus] SET mnu_padre = @USU, mnu_nivel = 4, mnu_orden = 3 WHERE mnu_id = 2088  -- Especialidades del usuario
UPDATE [dbo].[Menus] SET mnu_padre = @USU, mnu_nivel = 4, mnu_orden = 4 WHERE mnu_id = 2083  -- Grupos de Trabajo

/* Las fichas que abre cada una. No se ven en el arbol, pero el mantenedor de
   menus si las muestra, y una ficha colgada del nodo equivocado se lee como
   un error. */
UPDATE [dbo].[Menus] SET mnu_padre = @USU, mnu_nivel = 5
 WHERE mnu_id IN (2071,   -- Asociar usuario
                  2072,   -- Carga masiva de usuarios
                  2073,   -- Foto de marcacion
                  2074,   -- Nuevo usuario del cliente
                  2091,   -- Permiso de usuario (detalle)
                  2095,   -- Especialidad de usuario (detalle)
                  2087)   -- Grupo de trabajo (detalle)


/* ========================================================================
   3. LO QUE ES DE APOYO, BAJO CONFIGURACION
   ======================================================================== */

UPDATE [dbo].[Menus] SET mnu_padre = @CFG, mnu_nivel = 4, mnu_orden = 1 WHERE mnu_id = 2089  -- Catalogos
UPDATE [dbo].[Menus] SET mnu_padre = @CFG, mnu_nivel = 5 WHERE mnu_id = 2094                 -- Valor de catalogo (detalle)


/* ========================================================================
   4. ORGANIZACION QUEDA CON LOS LUGARES
   ======================================================================== */

DECLARE @ORG INT = (SELECT mnu_id FROM [dbo].[Menus]
                     WHERE mnu_padre = 32 AND mnu_nombre = N'Organización' COLLATE DATABASE_DEFAULT)

UPDATE [dbo].[Menus] SET mnu_orden = 1 WHERE mnu_id = 2080   -- Plantas
UPDATE [dbo].[Menus] SET mnu_orden = 2 WHERE mnu_id = 2081   -- Areas
UPDATE [dbo].[Menus] SET mnu_orden = 3 WHERE mnu_id = 2082   -- Centros de Costo

UPDATE [dbo].[Menus]
SET    mnu_descripcion = N'Donde ocurre el trabajo: plantas, areas y centros de costo',
       mnu_orden       = 3
WHERE  mnu_id = @ORG

UPDATE [dbo].[Menus] SET mnu_orden = 1 WHERE mnu_id = 40     -- Identidad
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */

DECLARE @USU2 INT = (SELECT mnu_id FROM [dbo].[Menus]
                      WHERE mnu_padre = 32 AND mnu_link = '#' AND mnu_nombre = N'Usuarios' COLLATE DATABASE_DEFAULT)
DECLARE @CFG2 INT = (SELECT mnu_id FROM [dbo].[Menus]
                      WHERE mnu_padre = 32 AND mnu_link = '#' AND mnu_nombre = N'Configuración' COLLATE DATABASE_DEFAULT)
DECLARE @ORG2 INT = (SELECT mnu_id FROM [dbo].[Menus]
                      WHERE mnu_padre = 32 AND mnu_nombre = N'Organización' COLLATE DATABASE_DEFAULT)

SELECT  'grupos directos bajo Cliente' AS OBJETO,
        (SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_padre = 32 AND mnu_visible = 1) AS HAY,
        4 AS ESPERADO   -- Identidad, Usuarios, Organizacion, Configuracion
UNION ALL
SELECT  'pantallas visibles bajo Usuarios',
        (SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_padre = @USU2 AND mnu_visible = 1), 4
UNION ALL
SELECT  'fichas ocultas bajo Usuarios',
        (SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_padre = @USU2 AND mnu_visible = 0), 7
UNION ALL
SELECT  'pantallas visibles bajo Organizacion',
        (SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_padre = @ORG2 AND mnu_visible = 1), 3
UNION ALL
SELECT  'pantallas visibles bajo Configuracion',
        (SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_padre = @CFG2 AND mnu_visible = 1), 1
UNION ALL
SELECT  'nada quedo colgando suelto de Cliente',
        (SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_padre = 32 AND mnu_link <> '#' AND mnu_link <> N'~/View/Clientes/Cliente/Identidad.aspx' COLLATE DATABASE_DEFAULT), 0
GO
