USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  23-09-2026
-- DESCRIPTION:     LAS OCURRENCIAS DE UNA TAREA RECURRENTE, EN LA WEB.
--                  1. SEL_TAREA_OCURRENCIA         (historial y proximas)
--                  2. SEL_TAREA_OCURRENCIA_ARCHIVO (las fotos de la ejecucion)
-- =============================================
-- La tarea recurrente ya tenia sus programaciones y sus comentarios en la web,
-- pero las OCURRENCIAS -lo que la programacion genero, lo que se ejecuto y lo
-- que viene- solo se leian desde el telefono: SEL_TAREA_EJECUCION filtra por
-- usuario y por planta asignada, que es lo correcto para descargar al
-- dispositivo y lo inutil para revisar una tarea desde el escritorio.
--
-- Estos dos SP leen por TAREA. El primero trae la ocurrencia con su
-- programacion, su responsable y -si ya paso- quien la ejecuto, cuando y que
-- dejo escrito. TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* ========================================================================
   1. SEL_TAREA_OCURRENCIA

   Los filtros son opcionales y se combinan: periodo, estado y responsable.
   El responsable sale de la PROGRAMACION -es quien tiene que hacerla-, y
   el ejecutor de la EJECUCION -quien la hizo-: no siempre son el mismo, y
   esa diferencia es justo lo que se mira al revisar una tarea.

   La ejecucion se trae con OUTER APPLY y no con JOIN: una ocurrencia puede
   tener varias -un intento fallido y el bueno- y aca interesa la ultima.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_TAREA_OCURRENCIA]
    @CLIENTE      INT,
    @TAREA        INT,
    @DESDE        DATETIME = NULL,
    @HASTA        DATETIME = NULL,
    @ESTADO       INT = NULL,
    @RESPONSABLE  INT = NULL
AS
SET NOCOUNT ON

    SELECT  toc.toc_id,
            toc.toc_tarea,
            toc.toc_tarea_programacion,
            toc.toc_fecha_programada_utc,
            toc.toc_fecha_limite_utc,
            toc.toc_tarea_ocurrencia_estado,
            ISNULL(toe.toe_codigo, '')                AS ESTADO_CODIGO,
            ISNULL(toe.toe_nombre, '')                AS ESTADO_NOMBRE,
            ISNULL(toc.toc_observacion, '')           AS OBSERVACION,
            toc.toc_orden_trabajo,

            ISNULL(pro.pro_nombre, '')                AS PROGRAMACION_NOMBRE,
            tpr.tpr_usuario_responsable               AS RESPONSABLE_ID,
            ISNULL(res.usu_nombre + ' ' + ISNULL(res.usu_apellido_paterno, ''), '') AS RESPONSABLE_NOMBRE,
            ISNULL(gru.gtr_nombre, '')                AS GRUPO_NOMBRE,

            eje.tej_id                                AS EJECUCION_ID,
            ISNULL(exe.usu_nombre + ' ' + ISNULL(exe.usu_apellido_paterno, ''), '') AS EJECUTOR_NOMBRE,
            eje.tej_fecha_inicio_utc                  AS EJECUCION_INICIO,
            eje.tej_fecha_fin_utc                     AS EJECUCION_FIN,
            eje.tej_duracion_minuto                   AS EJECUCION_MINUTOS,
            ISNULL(eje.tej_resultado, '')             AS EJECUCION_RESULTADO,
            eje.tej_conforme                          AS EJECUCION_CONFORME,
            ISNULL(eje.tej_dispositivo, '')           AS EJECUCION_DISPOSITIVO,

            /* Dos numeros que la pantalla muestra en la fila sin tener que
               pedir dos consultas mas por ocurrencia. */
            /* Tarea_Comentario no tiene baja logica a proposito: un
               comentario no se borra, se responde. */
            (SELECT COUNT(*) FROM [dbo].[Tarea_Comentario] tco
              WHERE tco.tco_tarea_ocurrencia = toc.toc_id)      AS COMENTARIOS,

            (SELECT COUNT(*) FROM [dbo].[Archivo_Vinculo] avi
              JOIN [dbo].[Archivo] arc ON arc.arc_id = avi.avi_archivo
              WHERE avi.avi_tarea_ejecucion = eje.tej_id
                AND ISNULL(avi.avi_habilitado, 1) = 1
                AND ISNULL(arc.arc_habilitado, 1) = 1)          AS EVIDENCIAS

    FROM    [dbo].[Tarea_Ocurrencia] toc
    JOIN    [dbo].[Tarea] tar                       ON tar.tar_id = toc.toc_tarea
    LEFT JOIN [dbo].[Tarea_Ocurrencia_Estado] toe   ON toe.toe_id = toc.toc_tarea_ocurrencia_estado
    LEFT JOIN [dbo].[Tarea_Programacion] tpr        ON tpr.tpr_id = toc.toc_tarea_programacion
    LEFT JOIN [dbo].[Programacion] pro              ON pro.pro_id = tpr.tpr_programacion
    LEFT JOIN [dbo].[Usuario] res                   ON res.usu_id = tpr.tpr_usuario_responsable
    LEFT JOIN [dbo].[Grupo_Trabajo] gru             ON gru.gtr_id = tpr.tpr_grupo_trabajo

    OUTER APPLY (SELECT TOP 1 *
                   FROM [dbo].[Tarea_Ejecucion] e
                  WHERE e.tej_tarea_ocurrencia = toc.toc_id
                    AND ISNULL(e.tej_habilitado, 1) = 1
                  ORDER BY ISNULL(e.tej_fecha_fin_utc, e.tej_fecha_creacion) DESC, e.tej_id DESC) eje

    LEFT JOIN [dbo].[Usuario] exe ON exe.usu_id = eje.tej_usuario_ejecutor

    WHERE   toc.toc_cliente = @CLIENTE
      AND   toc.toc_tarea   = @TAREA
      AND   ISNULL(toc.toc_habilitado, 1) = 1
      AND   (@DESDE  IS NULL OR toc.toc_fecha_programada_utc >= @DESDE)
      AND   (@HASTA  IS NULL OR toc.toc_fecha_programada_utc <  @HASTA)
      AND   (@ESTADO IS NULL OR toc.toc_tarea_ocurrencia_estado = @ESTADO)
      AND   (@RESPONSABLE IS NULL OR tpr.tpr_usuario_responsable = @RESPONSABLE)

    ORDER BY toc.toc_fecha_programada_utc, toc.toc_id
GO
PRINT '--- SEL_TAREA_OCURRENCIA creado.'
GO


/* ========================================================================
   2. SEL_TAREA_OCURRENCIA_ARCHIVO

   Las fotos que el tecnico adjunto al ejecutar. Cuelgan de la EJECUCION
   (avi_tarea_ejecucion), no de la ocurrencia: la evidencia es de lo que se
   hizo, no de lo que estaba programado.

   Devuelve metadatos, no bytes: la imagen se pide despues por
   VerArchivo.aspx y el navegador la cachea.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_TAREA_OCURRENCIA_ARCHIVO]
    @CLIENTE     INT,
    @OCURRENCIA  INT
AS
SET NOCOUNT ON

    SELECT  arc.arc_id,
            arc.arc_nombre_original,
            ISNULL(arc.arc_mime, '')                  AS arc_mime,
            ISNULL(arc.arc_byte, 0)                   AS arc_byte,
            arc.arc_fecha_creacion,
            ISNULL(avi.avi_titulo, '')                AS AVI_TITULO,
            ISNULL(avi.avi_descripcion, '')           AS AVI_DESCRIPCION,
            ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '') AS USUARIO_NOMBRE,
            CAST(CASE WHEN ISNULL(arc.arc_mime, '') LIKE 'image/%' THEN 1 ELSE 0 END AS INT) AS ES_IMAGEN

    FROM    [dbo].[Archivo_Vinculo] avi
    JOIN    [dbo].[Archivo] arc              ON arc.arc_id = avi.avi_archivo
    JOIN    [dbo].[Tarea_Ejecucion] eje      ON eje.tej_id = avi.avi_tarea_ejecucion
    JOIN    [dbo].[Tarea_Ocurrencia] toc     ON toc.toc_id = eje.tej_tarea_ocurrencia
    LEFT JOIN [dbo].[Usuario] usr            ON usr.usu_id = arc.arc_usuario_creacion

    WHERE   toc.toc_id      = @OCURRENCIA
      AND   toc.toc_cliente = @CLIENTE
      AND   arc.arc_cliente = @CLIENTE
      AND   ISNULL(arc.arc_habilitado, 1) = 1
      AND   ISNULL(avi.avi_habilitado, 1) = 1

    ORDER BY avi.avi_orden, arc.arc_id
GO
PRINT '--- SEL_TAREA_OCURRENCIA_ARCHIVO creado.'
GO

PRINT '264_TAREA_OCURRENCIA_WEB aplicado.'
GO
