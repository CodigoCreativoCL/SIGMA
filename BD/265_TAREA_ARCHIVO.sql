USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  23-09-2026
-- DESCRIPTION:     TODAS LAS EVIDENCIAS DE UNA TAREA RECURRENTE.
-- =============================================
-- SEL_TAREA_OCURRENCIA_ARCHIVO (bloque 264) devuelve las fotos de UNA
-- ocurrencia, que es lo que necesita el panel de detalle. La galeria de la
-- tarea necesita lo contrario: todo lo que llego desde el telefono a lo largo
-- de las ejecuciones, con la ocurrencia de la que vino para poder filtrar.
--
-- Como en el resto del sistema, se devuelve la RUTA del blob y no los bytes:
-- el binario vive en el Blob Storage y la imagen se pide despues por
-- VerArchivo.aspx, que es quien sabe bajarla. TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_TAREA_ARCHIVO]
    @CLIENTE  INT,
    @TAREA    INT
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

            toc.toc_id                                AS OCURRENCIA_ID,
            toc.toc_fecha_programada_utc              AS OCURRENCIA_FECHA,

            CAST(CASE WHEN ISNULL(arc.arc_mime, '') LIKE 'image/%' THEN 1 ELSE 0 END AS INT) AS ES_IMAGEN,
            CAST(CASE WHEN ISNULL(arc.arc_mime, '') LIKE 'video/%' THEN 1 ELSE 0 END AS INT) AS ES_VIDEO,
            CAST(CASE WHEN ISNULL(arc.arc_mime, '') LIKE 'audio/%' THEN 1 ELSE 0 END AS INT) AS ES_AUDIO

    FROM    [dbo].[Archivo_Vinculo] avi
    JOIN    [dbo].[Archivo] arc          ON arc.arc_id = avi.avi_archivo
    JOIN    [dbo].[Tarea_Ejecucion] eje  ON eje.tej_id = avi.avi_tarea_ejecucion
    JOIN    [dbo].[Tarea_Ocurrencia] toc ON toc.toc_id = eje.tej_tarea_ocurrencia
    LEFT JOIN [dbo].[Usuario] usr        ON usr.usu_id = arc.arc_usuario_creacion

    WHERE   toc.toc_tarea   = @TAREA
      AND   toc.toc_cliente = @CLIENTE
      AND   arc.arc_cliente = @CLIENTE
      AND   ISNULL(arc.arc_habilitado, 1) = 1
      AND   ISNULL(avi.avi_habilitado, 1) = 1

    ORDER BY toc.toc_fecha_programada_utc DESC, avi.avi_orden, arc.arc_id
GO
PRINT '--- SEL_TAREA_ARCHIVO creado.'
GO

PRINT '265_TAREA_ARCHIVO aplicado.'
GO
