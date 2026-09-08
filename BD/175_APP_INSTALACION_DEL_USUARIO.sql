USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  07-09-2026
-- DESCRIPTION:     LAS PLANTAS DEL CLIENTE A LAS QUE LA PERSONA ESTA ASIGNADA.
-- =============================================
-- POR QUE HIZO FALTA
--
--   `GET /cliente-instalaciones` usaba `SEL_CLIENTE_INSTALACION`, que es el
--   listado de la web y **no filtra por persona**: devolvia todas las plantas
--   del cliente. En la app eso significa que un tecnico asignado a Renca veria
--   tambien Quilicura y Maipu, y elegiria contexto en una planta en la que no
--   trabaja. Hoy Hamburgo tiene una sola planta y no se nota; el dia que tenga
--   dos, se nota en todos los usuarios a la vez.
--
--   Aquel SP si declara @USUARIO, pero filtra por `USUARIO_INSTALACION`, que
--   esta VACIA. Las asignaciones reales viven en `Cliente_Instalacion_Usuario`
--   (7 filas al 07-09-2026). Pasarle @USUARIO no habria filtrado: habria
--   devuelto cero para todo el mundo, que es peor que devolver de mas.
--
-- LA REGLA ES LA MISMA QUE LA DE LA SABANA
--
--   `API_SEL_APP_SABANA_DATOS` ya resuelve `@PLANTAS` con este mismo JOIN. Que
--   los dos caminos usen la misma regla es lo que evita que la pantalla de
--   contexto ofrezca una planta cuyos activos la sincronizacion nunca baja.
--
--   Sin asignacion no se devuelve nada. Es deliberado: pertenecer al cliente
--   no es estar asignado a una planta, y en terreno esa diferencia es la que
--   decide que activos se pueden intervenir.
--
-- ES IDEMPOTENTE: CREATE OR ALTER.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[API_SEL_APP_INSTALACION]
@CLIENTE INT,
@USUARIO INT,
@ID      INT = NULL,
@FILTRO  VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    SELECT      CIN.cin_id            AS cin_id,
                CIN.cin_cliente       AS cin_cliente,
                CIN.cin_codigo        AS cin_codigo,
                CIN.cin_nombre        AS cin_nombre,
                CIN.cin_descripcion   AS cin_descripcion,
                CIN.cin_direccion     AS cin_direccion,
                CIN.cin_zona_horaria  AS cin_zona_horaria,
                CIN.cin_latitud       AS cin_latitud,
                CIN.cin_longitud      AS cin_longitud,
                CIN.cin_habilitado    AS cin_habilitado
    FROM        [dbo].[Cliente_Instalacion] CIN
    /* INNER, no LEFT: sin fila de asignacion la planta no sale. */
    JOIN        [dbo].[Cliente_Instalacion_Usuario] CIU
            ON  CIU.ciu_id_instalacion = CIN.cin_id
            AND CIU.ciu_id_usuario     = @USUARIO
            AND ISNULL(CIU.ciu_habilitado, 0) = 1
            /* La asignacion puede tener vigencia: un reemplazo por turno no
               deja ver la planta para siempre. NULL = sin limite. */
            AND (CIU.ciu_fecha_inicio IS NULL OR CIU.ciu_fecha_inicio <= GETDATE())
            AND (CIU.ciu_fecha_fin    IS NULL OR CIU.ciu_fecha_fin    >= GETDATE())
    WHERE       CIN.cin_cliente    = @CLIENTE
      AND       CIN.cin_habilitado = 1
      AND       (@ID IS NULL OR CIN.cin_id = @ID)
      AND       (@FILTRO IS NULL OR @FILTRO = ''
                 OR CIN.cin_nombre   LIKE '%' + @FILTRO + '%'
                 OR CIN.cin_codigo   LIKE '%' + @FILTRO + '%'
                 OR CIN.cin_direccion LIKE '%' + @FILTRO + '%')
    ORDER BY    CIN.cin_nombre
GO
