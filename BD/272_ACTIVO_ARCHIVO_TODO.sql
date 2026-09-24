USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     TODOS LOS ARCHIVOS DE UN EQUIPO, VENGAN DE DONDE VENGAN.
-- =============================================
-- SEL_ACTIVO_ARCHIVO devuelve solo los documentos colgados del activo, y a
-- proposito deja fuera su imagen -avi_es_referencia = 1-. Para el centro eso
-- se lee como "este equipo no tiene archivos", cuando en realidad tiene su
-- foto, y ademas tiene todo lo que el terreno fotografio: las evidencias de
-- sus ordenes, de sus inspecciones y de sus tareas.
--
-- Este devuelve las cuatro fuentes en una lista, cada una con su ORIGEN, para
-- que la pantalla pueda separarlas en Documentos, Fotografias y Evidencias y
-- para que cada archivo sepa volver a su registro.
--
-- Los bytes NO viajan: el archivo vive en Blob Storage y la pantalla lo pide
-- por VerArchivo.aspx con el id cifrado.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_ARCHIVO_TODO]
    @CLIENTE  INT,
    @ACTIVO   INT
AS
SET NOCOUNT ON

    ;WITH ot AS (
        SELECT  o.otr_id, o.otr_correlativo, o.otr_titulo
        FROM    [dbo].[Orden_Trabajo] o
        WHERE   o.otr_cliente = @CLIENTE AND o.otr_activo = @ACTIVO
    )
    SELECT  u.*
    FROM   (
        /* ---- 1. lo que cuelga del activo: documentos y su foto ---- */
        SELECT  a.arc_id                                  AS ARC_ID,
                ISNULL(a.arc_nombre_original, '')         AS NOMBRE,
                ISNULL(a.arc_mime, '')                    AS MIME,
                ISNULL(a.arc_byte, 0)                     AS BYTES,
                a.arc_fecha_creacion                      AS FECHA,
                CASE WHEN ISNULL(v.avi_es_referencia, 0) = 1 THEN 'FOTO' ELSE 'DOCUMENTO' END AS ORIGEN,
                CASE WHEN ISNULL(v.avi_es_referencia, 0) = 1 THEN 'Imagen del equipo' ELSE 'Documento del equipo' END AS ORIGEN_NOMBRE,
                ''                                        AS ORIGEN_CODIGO,
                CAST(NULL AS INT)                         AS ORDEN_ID,
                ISNULL(v.avi_titulo, '')                  AS TITULO,
                ISNULL(v.avi_descripcion, '')             AS DESCRIPCION,
                ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '') AS USUARIO_NOMBRE
        FROM    [dbo].[Archivo_Vinculo] v
        JOIN    [dbo].[Archivo] a   ON a.arc_id = v.avi_archivo
        LEFT JOIN [dbo].[Usuario] usr ON usr.usu_id = a.arc_usuario_creacion
        WHERE   v.avi_activo = @ACTIVO
          AND   a.arc_cliente = @CLIENTE
          AND   ISNULL(v.avi_habilitado, 1) = 1
          AND   ISNULL(a.arc_habilitado, 1) = 1

        UNION ALL

        /* ---- 2. lo que el terreno fotografio en sus ordenes ---- */
        SELECT  a.arc_id,
                ISNULL(a.arc_nombre_original, ''),
                ISNULL(a.arc_mime, ''),
                ISNULL(a.arc_byte, 0),
                a.arc_fecha_creacion,
                'ORDEN',
                'Orden de trabajo',
                'OT-' + CAST(ot.otr_correlativo AS VARCHAR(20)),
                ot.otr_id,
                ISNULL(v.avi_titulo, ''),
                ISNULL(v.avi_descripcion, ''),
                ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '')
        FROM    [dbo].[Archivo_Vinculo] v
        JOIN    [dbo].[Archivo] a  ON a.arc_id = v.avi_archivo
        JOIN    ot                 ON ot.otr_id = v.avi_orden_trabajo
        LEFT JOIN [dbo].[Usuario] usr ON usr.usu_id = a.arc_usuario_creacion
        WHERE   ISNULL(v.avi_habilitado, 1) = 1
          AND   ISNULL(a.arc_habilitado, 1) = 1

        UNION ALL

        /* ---- 3. lo que se fotografio respondiendo una inspeccion ---- */
        SELECT  a.arc_id,
                ISNULL(a.arc_nombre_original, ''),
                ISNULL(a.arc_mime, ''),
                ISNULL(a.arc_byte, 0),
                a.arc_fecha_creacion,
                'INSPECCION',
                'Inspección',
                ISNULL(cpl.cpl_codigo, ''),
                CAST(NULL AS INT),
                ISNULL(v.avi_titulo, ''),
                ISNULL(v.avi_descripcion, ''),
                ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '')
        FROM    [dbo].[Archivo_Vinculo] v
        JOIN    [dbo].[Archivo] a  ON a.arc_id = v.avi_archivo
        JOIN    [dbo].[Checklist_Ejecucion_Respuesta] cer ON cer.cer_id = v.avi_checklist_ejecucion_respuesta
        JOIN    [dbo].[Checklist_Ejecucion] cej ON cej.cej_id = cer.cer_checklist_ejecucion
        LEFT JOIN [dbo].[Checklist_Plantilla_Version] cpv ON cpv.cpv_id = cej.cej_checklist_plantilla_version
        LEFT JOIN [dbo].[Checklist_Plantilla] cpl ON cpl.cpl_id = cpv.cpv_checklist_plantilla
        LEFT JOIN [dbo].[Usuario] usr ON usr.usu_id = a.arc_usuario_creacion
        WHERE   cej.cej_activo = @ACTIVO
          AND   cej.cej_cliente = @CLIENTE
          AND   ISNULL(v.avi_habilitado, 1) = 1
          AND   ISNULL(a.arc_habilitado, 1) = 1

        UNION ALL

        /* ---- 4. lo que se fotografio ejecutando una tarea del equipo ---- */
        SELECT  a.arc_id,
                ISNULL(a.arc_nombre_original, ''),
                ISNULL(a.arc_mime, ''),
                ISNULL(a.arc_byte, 0),
                a.arc_fecha_creacion,
                'TAREA',
                'Tarea',
                ISNULL(tar.tar_codigo, ''),
                CAST(NULL AS INT),
                ISNULL(v.avi_titulo, ''),
                ISNULL(v.avi_descripcion, ''),
                ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '')
        FROM    [dbo].[Archivo_Vinculo] v
        JOIN    [dbo].[Archivo] a  ON a.arc_id = v.avi_archivo
        JOIN    [dbo].[Tarea_Ejecucion] tej ON tej.tej_id = v.avi_tarea_ejecucion
        JOIN    [dbo].[Tarea_Ocurrencia] toc ON toc.toc_id = tej.tej_tarea_ocurrencia
        JOIN    [dbo].[Tarea] tar ON tar.tar_id = toc.toc_tarea
        LEFT JOIN [dbo].[Usuario] usr ON usr.usu_id = a.arc_usuario_creacion
        WHERE   tar.tar_activo = @ACTIVO
          AND   tar.tar_cliente = @CLIENTE
          AND   ISNULL(v.avi_habilitado, 1) = 1
          AND   ISNULL(a.arc_habilitado, 1) = 1
    ) u

    ORDER BY u.FECHA DESC, u.ARC_ID DESC
GO
PRINT '--- SEL_ACTIVO_ARCHIVO_TODO creado.'
GO

PRINT '272_ACTIVO_ARCHIVO_TODO aplicado.'
GO
