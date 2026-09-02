/* ============================================================================
   SIGMA — Bloque 88
   EL COMBO DE PERSONAS DICE QUÉ ES CADA UNA
   ----------------------------------------------------------------------------

   EL PROBLEMA

     Tres pantallas eligen una persona de un combo: Grupo de Trabajo,
     Permisos de Usuario y Especialidad de la Persona. Las tres mostraban

       Rodrigo Quezada · rodrigo.quezada@hamburgo.cl

     y con eso hay que decidir si esa persona va al grupo de mantenimiento
     eléctrico, si le corresponde un permiso de bodega, o si tiene sentido
     asignarle una especialidad.

     El correo no ayuda a decidir nada de eso: es un identificador, no una
     descripción. Lo que hace falta saber es **qué hace la persona**, y eso
     es el perfil.

   POR QUE UNA LISTA DE PERFILES Y NO UNO

     `Cliente_Usuario_Perfil` es una tabla puente: una persona puede tener
     más de un perfil. Devolver "el" perfil obligaría a elegir uno con algún
     criterio inventado —el primero, el de menor id— y esconder los demás
     justo en la pantalla donde se está decidiendo por ellos.

     Se devuelven todos, separados por coma. Con dos o tres cabe; con más,
     el combo se lee largo, y eso es información honesta: una persona con
     cinco perfiles ES un caso que hay que mirar.

   POR QUE LEFT JOIN

     Una persona recién afiliada todavía no tiene perfil. Con INNER JOIN
     desaparecería del combo, y desaparecer de una lista es peor que
     aparecer sin perfil: quien la busca concluye que no está afiliada.
     Sale con la etiqueta vacía y la pantalla escribe "sin perfil".

   ORDEN: despues de 87_MOVIMIENTO_ORIGEN.sql
   ============================================================================ */

SET NOCOUNT ON
GO


IF OBJECT_ID('dbo.SEL_USUARIO_CLIENTE_LISTA') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_USUARIO_CLIENTE_LISTA]
GO

CREATE PROCEDURE [dbo].[SEL_USUARIO_CLIENTE_LISTA]
    @CLIENTE INT,
    @FILTRO  VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    SELECT  u.usu_id                                          AS USU_ID,
            u.usu_nombre + SPACE(1) + u.usu_apellido_paterno  AS USU_NOMBRE,
            u.usu_correo                                      AS USU_CORREO,
            u.usu_identificador                               AS USU_IDENTIFICADOR,
            cu.ucl_id                                         AS UCL_ID,
            ISNULL(pf.PERFILES, '')                           AS PERFILES
    FROM    [dbo].[Cliente_Usuario] cu
    INNER JOIN [dbo].[Usuario] u
            ON  u.usu_id = cu.ucl_id_usuario
    /* OUTER APPLY y no un JOIN con GROUP BY: la persona sin perfil tiene que
       seguir apareciendo, y agrupar toda la consulta por seis columnas para
       concatenar una sola es más caro y más difícil de leer. */
    OUTER APPLY (
        SELECT  STRING_AGG(p.per_nombre, ', ')
                    WITHIN GROUP (ORDER BY p.per_nombre) AS PERFILES
        FROM    [dbo].[Cliente_Usuario_Perfil] cup
        JOIN    [dbo].[Perfiles] p
                ON  p.per_id = cup.cup_id_perfil
        WHERE   cup.cup_id_cliente_usuario = cu.ucl_id
          AND   p.per_habilitado = 1
    ) pf
    WHERE   cu.ucl_id_cliente = @CLIENTE
      AND   ISNULL(cu.ucl_habilitado, 0) = 1
      AND   u.usu_habilitado = 1
      AND   (@FILTRO IS NULL
             OR u.usu_nombre LIKE '%' + @FILTRO + '%'
             OR u.usu_apellido_paterno LIKE '%' + @FILTRO + '%'
             OR u.usu_correo LIKE '%' + @FILTRO + '%')
    ORDER BY u.usu_apellido_paterno, u.usu_nombre
GO

PRINT '--- SEL_USUARIO_CLIENTE_LISTA actualizado: ahora devuelve PERFILES.'
GO


/* ========================================================================
   CONTROL: que la columna nueva venga poblada.

   Si sale todo vacío es que la afiliación no tiene perfiles cargados, no
   que la consulta esté mal: se mira antes de culpar al SP.
   ======================================================================== */
EXEC [dbo].[SEL_USUARIO_CLIENTE_LISTA] @CLIENTE = 1
GO


PRINT '88_USUARIO_LISTA_PERFIL aplicado.'
GO
