/* ============================================================================
   SIGMA — Bloque 119
   LOS CATALOGOS DE ALCANCE Y ASIGNACION
   ----------------------------------------------------------------------------

   POR QUE UN SP APARTE Y NO UNA RAMA MAS EN EL DE SIEMPRE

     `SEL_PROGRAMACION_CATALOGO` no recibe cliente, y no lo necesita: tipos de
     frecuencia, unidades de tiempo y dias de la semana son los mismos para
     todo el mundo.

     Estos cinco NO. Instalaciones, areas, activos, usuarios y perfiles son de
     un cliente. Mezclarlos en el mismo UNION significa que el dia que alguien
     agregue una rama nueva y se olvide del `WHERE cliente`, la lista le
     muestra a una empresa las instalaciones de otra. Separarlos hace que el
     parametro @CLIENTE sea obligatorio y que olvidarlo no compile.

   EN CASCADA

     El area depende de la instalacion y el activo de las dos. Se filtra con
     @PADRE, asi que la pantalla pide "las areas de ESTA instalacion" y no
     recibe nunca una lista que no puede usar.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.SEL_PROGRAMACION_CATALOGO_ALCANCE') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_PROGRAMACION_CATALOGO_ALCANCE]
GO

CREATE PROCEDURE [dbo].[SEL_PROGRAMACION_CATALOGO_ALCANCE]
    @CATALOGO   VARCHAR(40),
    @CLIENTE    INT,
    @PADRE      INT = NULL
AS
SET NOCOUNT ON

/* Lista blanca explicita. Un nombre que no este aca no devuelve nada, y no
   hay SQL dinamico por donde colar otra cosa. */
IF (@CATALOGO NOT IN ('INSTALACION', 'AREA', 'ACTIVO', 'RESPONSABLE', 'PERFIL'))
BEGIN
    SELECT ID = CAST(NULL AS INT), CODIGO = CAST(NULL AS NVARCHAR(100)),
           NOMBRE = CAST(NULL AS NVARCHAR(400)), ORDEN = CAST(NULL AS INT)
    WHERE 1 = 0
    RETURN
END

IF (@CATALOGO = 'INSTALACION')
    SELECT  ID = i.cin_id,
            CODIGO = CAST(i.cin_id AS NVARCHAR(100)),
            NOMBRE = i.cin_nombre,
            ORDEN = 0
    FROM    [dbo].[Cliente_Instalacion] i
    WHERE   i.cin_cliente = @CLIENTE
      AND   i.cin_habilitado = 1
    ORDER BY i.cin_nombre

ELSE IF (@CATALOGO = 'AREA')
    /* Sin instalacion no hay areas que mostrar: devolver todas invitaria a
       elegir un area de otra planta. */
    SELECT  ID = a.iar_id,
            CODIGO = CAST(a.iar_id AS NVARCHAR(100)),
            NOMBRE = a.iar_nombre,
            ORDEN = 0
    FROM    [dbo].[Instalacion_Area] a
    JOIN    [dbo].[Cliente_Instalacion] i ON i.cin_id = a.iar_cliente_instalacion
    WHERE   i.cin_cliente = @CLIENTE
      AND   a.iar_habilitado = 1
      AND   (@PADRE IS NOT NULL AND a.iar_cliente_instalacion = @PADRE)
    ORDER BY a.iar_nombre

ELSE IF (@CATALOGO = 'ACTIVO')
    SELECT  ID = ac.act_id,
            CODIGO = ac.act_codigo,
            NOMBRE = ac.act_codigo + N' · ' + ac.act_nombre,
            ORDEN = 0
    FROM    [dbo].[Activo] ac
    JOIN    [dbo].[Cliente_Instalacion] i ON i.cin_id = ac.act_cliente_instalacion
    WHERE   i.cin_cliente = @CLIENTE
      AND   ac.act_habilitado = 1
      AND   (@PADRE IS NULL OR ac.act_cliente_instalacion = @PADRE)
    ORDER BY ac.act_codigo

ELSE IF (@CATALOGO = 'RESPONSABLE')
    /* Los usuarios de este cliente. El nombre lleva el perfil pegado porque
       "Juan Perez" no dice si es quien debe hacer la ronda o quien la aprueba. */
    /* El perfil va PEGADO al nombre. "Rodrigo Quezada" no dice si es quien
       hace la ronda o quien la aprueba, y elegir mal al responsable de una
       programacion se descubre recien cuando la actividad lleva un mes sin
       ejecutarse. Una persona con varios perfiles los muestra todos. */
    SELECT  ID = u.usu_id,
            /* El CODIGO lleva la foto y las iniciales, separadas por |. Es lo
               que la ficha necesita para dibujar el avatar del chip sin tener
               que consultar por cada persona elegida.

               La foto es el ID DEL ARCHIVO, no la imagen: mandar el binario de
               cada usuario dentro de un combo serian cientos de kilobytes para
               una lista que casi siempre se mira y se cierra. */
            CODIGO = CAST(ISNULL(u.usu_archivo_foto, 0) AS NVARCHAR(20)) + N'|' +
                     UPPER(LEFT(u.usu_nombre, 1) + LEFT(u.usu_apellido_paterno, 1)),
            NOMBRE = u.usu_nombre + N' ' + u.usu_apellido_paterno
                   + ISNULL(N'  ·  ' + NULLIF(x.PERFILES, N''), N''),
            ORDEN = 0
    FROM    [dbo].[Usuario] u
    JOIN    [dbo].[Cliente_Usuario] cu ON cu.ucl_id_usuario = u.usu_id
                                      AND cu.ucl_id_cliente = @CLIENTE
                                      AND cu.ucl_habilitado = 1
    OUTER APPLY (
        SELECT PERFILES = STUFF((
            SELECT N', ' + pf.per_nombre
            FROM   [dbo].[Cliente_Usuario_Perfil] up
            JOIN   [dbo].[Perfiles] pf ON pf.per_id = up.cup_id_perfil
            WHERE  up.cup_id_cliente_usuario = cu.ucl_id
              AND  pf.per_habilitado = 1
            ORDER BY pf.per_nombre
            FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'')
    ) x
    WHERE   u.usu_habilitado = 1
    ORDER BY u.usu_nombre, u.usu_apellido_paterno

ELSE IF (@CATALOGO = 'PERFIL')
    SELECT  ID = p.per_id,
            CODIGO = CAST(p.per_id AS NVARCHAR(100)),
            NOMBRE = p.per_nombre,
            ORDEN = 0
    FROM    [dbo].[Perfiles] p
    WHERE   p.per_habilitado = 1
    ORDER BY p.per_nombre
GO

PRINT '--- SEL_PROGRAMACION_CATALOGO_ALCANCE creado.'
GO

/* Verificacion: cada uno tiene que responder. Una lista vacia deja un combo
   en blanco en la ficha y nadie sabe si es que no hay o si es que fallo. */
EXEC [dbo].[SEL_PROGRAMACION_CATALOGO_ALCANCE] @CATALOGO = 'INSTALACION', @CLIENTE = 1
EXEC [dbo].[SEL_PROGRAMACION_CATALOGO_ALCANCE] @CATALOGO = 'ACTIVO',      @CLIENTE = 1
EXEC [dbo].[SEL_PROGRAMACION_CATALOGO_ALCANCE] @CATALOGO = 'RESPONSABLE', @CLIENTE = 1
EXEC [dbo].[SEL_PROGRAMACION_CATALOGO_ALCANCE] @CATALOGO = 'PERFIL',      @CLIENTE = 1
GO

PRINT '119_PROGRAMACION_CATALOGO_ALCANCE aplicado.'
GO
