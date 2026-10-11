/* ============================================================================
   431 · La galería del activo con las fotos de los pasos y las referencias (10-10-2026)
   HU-142 criterio 2 y HU-143 criterio 3. Autora: Catalina Pescio.

   SEL_ACTIVO_ARCHIVO_TODO alimenta «Documentos y galería» de la ficha del activo.
   Tenía dos huecos para el criterio 2 («las fotografías de todas sus órdenes»):
     · Leía solo lo colgado de la ORDEN (avi_orden_trabajo). La app guarda casi todo
       en el PASO (avi_orden_trabajo_paso): con la semilla de HU-142, ACT-10 mostraba
       3 archivos de órdenes en vez de 9.
     · Mostraba la FIRMA del cierre como si fuera evidencia.
   Y para HU-143 criterio 3 le faltaban las imágenes de REFERENCIA, separadas de lo
   que llegó del terreno.

   VERSIÓN COMPLETA. Hasta aquí el SP no tenía su texto entero en ningún archivo: el
   último CREATE era el de BD/272 y lo parchaban 350, 353 y 354 con REPLACE sobre
   OBJECT_DEFINITION. Este archivo parte de la definición viva en db71936 (con esos
   tres parches) y es desde ahora la fuente; un parche nuevo se hace aquí.

   Cambios respecto de la versión viva:
     2. Órdenes: lo de la orden Y lo de sus pasos; ORIGEN_CODIGO dice el paso
        («OT-1 · Paso 2»); sin la categoría FIRMA.
     5. Nuevo: las referencias de la actividad del plan de la que nacen los pasos de
        sus órdenes (ORIGEN 'REFERENCIA', una vez por vínculo). Se reconocen por el
        destino avi_plan_mantenimiento_actividad, no por avi_es_referencia (BD/429).
   1, 3 y 4 quedan iguales. Mismas columnas y mismo orden (FECHA DESC): la ficha no
   cambia de contrato. Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
                CASE WHEN v.avi_activo_componente IS NOT NULL THEN N'Foto de ' + ISNULL((SELECT k.aco_nombre FROM [dbo].[Activo_Componente] k WHERE k.aco_id = v.avi_activo_componente), N'un componente') WHEN ISNULL(v.avi_es_referencia, 0) = 1 THEN 'Foto de portada' WHEN ISNULL(v.avi_es_foto, 0) = 1 THEN 'Foto del activo' ELSE 'Documento del activo' END AS ORIGEN_NOMBRE,
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

        /* ---- 2. lo que el terreno fotografio en sus ordenes: en la orden y en sus pasos ---- */
        SELECT  a.arc_id,
                ISNULL(a.arc_nombre_original, ''),
                ISNULL(a.arc_mime, ''),
                ISNULL(a.arc_byte, 0),
                a.arc_fecha_creacion,
                'ORDEN',
                'Orden de trabajo',
                'OT-' + CAST(ot.otr_correlativo AS VARCHAR(20))
                    + ISNULL(N' · Paso ' + CAST(otp.otp_orden AS NVARCHAR(10)), N''),
                ot.otr_id,
                ISNULL(v.avi_titulo, ''),
                ISNULL(v.avi_descripcion, ''),
                ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '')
        FROM    [dbo].[Archivo_Vinculo] v
        JOIN    [dbo].[Archivo] a  ON a.arc_id = v.avi_archivo
        LEFT JOIN [dbo].[Orden_Trabajo_Paso] otp ON otp.otp_id = v.avi_orden_trabajo_paso
        JOIN    ot                 ON ot.otr_id = ISNULL(v.avi_orden_trabajo, otp.otp_orden_trabajo)
        LEFT JOIN [dbo].[Archivo_Categoria] aca ON aca.aca_id = a.arc_archivo_categoria
        LEFT JOIN [dbo].[Usuario] usr ON usr.usu_id = a.arc_usuario_creacion
        WHERE   (v.avi_orden_trabajo IS NOT NULL OR v.avi_orden_trabajo_paso IS NOT NULL)
          AND   ISNULL(aca.aca_codigo, '') <> 'FIRMA'
          AND   ISNULL(v.avi_habilitado, 1) = 1
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

        UNION ALL

        /* ---- 5. las imagenes de referencia (HU-143): como debe quedar el trabajo ----
           Las de la actividad del plan de la que nacen los pasos de sus ordenes. Son
           de la actividad, no del paso: una vez por vinculo. */
        SELECT  a.arc_id,
                ISNULL(a.arc_nombre_original, ''),
                ISNULL(a.arc_mime, ''),
                ISNULL(a.arc_byte, 0),
                a.arc_fecha_creacion,
                'REFERENCIA',
                'Imagen de referencia',
                ISNULL(paa.paa_nombre, N''),
                CAST(NULL AS INT),
                ISNULL(v.avi_titulo, ''),
                ISNULL(v.avi_descripcion, ''),
                ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '')
        FROM    [dbo].[Archivo_Vinculo] v
        JOIN    [dbo].[Archivo] a  ON a.arc_id = v.avi_archivo
        LEFT JOIN [dbo].[Plan_Mantenimiento_Actividad] paa ON paa.paa_id = v.avi_plan_mantenimiento_actividad
        LEFT JOIN [dbo].[Usuario] usr ON usr.usu_id = a.arc_usuario_creacion
        WHERE   v.avi_plan_mantenimiento_actividad IN
                (SELECT otp.otp_plan_mantenimiento_actividad FROM [dbo].[Orden_Trabajo_Paso] otp
                  JOIN ot ON ot.otr_id = otp.otp_orden_trabajo WHERE otp.otp_habilitado = 1)
          AND   a.arc_cliente = @CLIENTE
          AND   ISNULL(v.avi_habilitado, 1) = 1
          AND   ISNULL(a.arc_habilitado, 1) = 1
    ) u

    ORDER BY u.FECHA DESC, u.ARC_ID DESC
GO
PRINT '431_ACTIVO_GALERIA_PASOS_REFERENCIAS aplicado.'
GO
