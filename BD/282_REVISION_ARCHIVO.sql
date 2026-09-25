USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     LOS ARCHIVOS DE CADA INSPECCION Y TAREA DEL ACTIVO.
-- =============================================
-- POR QUE
--   El centro decia "1 archivo adjunto". Ese archivo es la foto del filtro
--   saturado: es LA razon por la que la tarea quedo con observacion, y para
--   verla habia que salir a otra pantalla.
--
--   SEL_ACTIVO_INSPECCION_TAREA solo los cuenta. Este los devuelve, para
--   todas las revisiones del equipo de una vez: pedirlos por fila serian
--   veinte consultas al abrir la pestaña.
--
--   Las fotos de una inspeccion cuelgan de la RESPUESTA -se fotografia un
--   item, no el recorrido-; las de una tarea, de la ejecucion. Por eso los
--   dos caminos.
--
--   Viajan los metadatos, no los bytes: el MIME es lo que le dice a la
--   pantalla si eso se mira, se reproduce o se descarga.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_REVISION_ARCHIVO]
    @CLIENTE INT,
    @ACTIVO  INT
AS
SET NOCOUNT ON

    /* ---- inspecciones: por la respuesta del item ---- */
    SELECT  'INSPECCION'                          AS TIPO,
            eje.cej_id                            AS EJECUCION_ID,
            arc.arc_id                            AS ARC_ID,
            ISNULL(arc.arc_nombre_original, '')   AS NOMBRE,
            ISNULL(arc.arc_mime, '')              AS MIME,
            ISNULL(arc.arc_byte, 0)               AS BYTES,
            avi.avi_fecha_creacion                AS FECHA,
            ISNULL(avi.avi_titulo, '')            AS TITULO,
            ISNULL(cpi.cpi_texto, '')             AS ORIGEN,
            ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '') AS USUARIO

    FROM    [dbo].[Checklist_Ocurrencia] coc
    JOIN    [dbo].[Checklist_Ejecucion] eje       ON eje.cej_checklist_ocurrencia = coc.coc_id
    JOIN    [dbo].[Checklist_Ejecucion_Respuesta] cer ON cer.cer_checklist_ejecucion = eje.cej_id
    JOIN    [dbo].[Archivo_Vinculo] avi           ON avi.avi_checklist_ejecucion_respuesta = cer.cer_id
    JOIN    [dbo].[Archivo] arc                   ON arc.arc_id = avi.avi_archivo
    LEFT JOIN [dbo].[Checklist_Plantilla_Item] cpi ON cpi.cpi_id = cer.cer_checklist_plantilla_item
    LEFT JOIN [dbo].[Usuario] usr                 ON usr.usu_id = avi.avi_usuario_creacion

    WHERE   coc.coc_cliente = @CLIENTE
      AND   coc.coc_activo  = @ACTIVO
      AND   ISNULL(coc.coc_habilitado, 1) = 1
      AND   ISNULL(eje.cej_habilitado, 1) = 1
      AND   ISNULL(avi.avi_habilitado, 1) = 1
      AND   ISNULL(arc.arc_habilitado, 1) = 1

    UNION ALL

    /* ---- tareas: por la ejecucion ---- */
    SELECT  'TAREA'                               AS TIPO,
            tej.tej_id                            AS EJECUCION_ID,
            arc.arc_id                            AS ARC_ID,
            ISNULL(arc.arc_nombre_original, '')   AS NOMBRE,
            ISNULL(arc.arc_mime, '')              AS MIME,
            ISNULL(arc.arc_byte, 0)               AS BYTES,
            avi.avi_fecha_creacion                AS FECHA,
            ISNULL(avi.avi_titulo, '')            AS TITULO,
            ''                                    AS ORIGEN,
            ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '') AS USUARIO

    FROM    [dbo].[Tarea_Ocurrencia] toc
    JOIN    [dbo].[Tarea] tar                     ON tar.tar_id = toc.toc_tarea
    JOIN    [dbo].[Tarea_Ejecucion] tej           ON tej.tej_tarea_ocurrencia = toc.toc_id
    JOIN    [dbo].[Archivo_Vinculo] avi           ON avi.avi_tarea_ejecucion = tej.tej_id
    JOIN    [dbo].[Archivo] arc                   ON arc.arc_id = avi.avi_archivo
    LEFT JOIN [dbo].[Usuario] usr                 ON usr.usu_id = avi.avi_usuario_creacion

    WHERE   toc.toc_cliente = @CLIENTE

      /* La ocurrencia no guarda el activo: lo guarda la tarea. */
      AND   tar.tar_activo  = @ACTIVO
      AND   ISNULL(toc.toc_habilitado, 1) = 1
      AND   ISNULL(avi.avi_habilitado, 1) = 1
      AND   ISNULL(arc.arc_habilitado, 1) = 1

    ORDER BY TIPO, EJECUCION_ID, ARC_ID
GO
PRINT '--- SEL_ACTIVO_REVISION_ARCHIVO creado.'
GO

PRINT '282_REVISION_ARCHIVO aplicado.'
GO
