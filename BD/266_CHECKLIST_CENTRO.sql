USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  23-09-2026
-- DESCRIPTION:     EL CENTRO DE LA PAUTA DE INSPECCION: LO QUE PASO EN TERRENO.
--                  1. SEL_CHECKLIST_OCURRENCIA           (rondas generadas)
--                  2. SEL_CHECKLIST_EJECUCION_RESPUESTA  (que respondio cada item)
--                  3. SEL_CHECKLIST_EJECUCION_ARCHIVO    (las fotos de la respuesta)
-- =============================================
-- La pauta tenia pantallas para disenarla -plantilla, version, programacion- y
-- una bandeja de hallazgos, pero lo del medio no se veia desde el escritorio:
-- que rondas genero la programacion, cuales estan pendientes o vencidas, quien
-- ejecuto, que respondio item por item y con que foto. Eso solo lo leia el
-- telefono (API_SEL_CHECKLIST), que filtra por usuario y por planta asignada:
-- correcto para descargar al dispositivo, inutil para revisar una pauta.
--
-- Los tres SP leen por PAUTA (plantilla) y por cliente. Como en el resto del
-- sistema, los archivos devuelven la RUTA del blob y no los bytes: la imagen
-- se pide despues por VerArchivo.aspx, que es quien la baja del Blob Storage.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* ========================================================================
   1. SEL_CHECKLIST_OCURRENCIA

   Una ocurrencia es una ronda con fecha: la programacion la genero y
   alguien tiene que hacerla. Se devuelve con su ejecucion -si ya paso- y
   con los tres numeros que la ejecucion ya lleva contados: items totales,
   respondidos y no conformes. Contarlos aca de nuevo seria recorrer las
   respuestas de todas las rondas para mostrar una lista.

   La ejecucion se trae con OUTER APPLY y no con JOIN: una ocurrencia puede
   tener varias -un intento que se corto y el bueno- y aca interesa la
   ultima.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_OCURRENCIA]
    @CLIENTE    INT,
    @PLANTILLA  INT,
    @DESDE      DATETIME = NULL,
    @HASTA      DATETIME = NULL,
    @ESTADO     INT = NULL
AS
SET NOCOUNT ON

    SELECT  coc.coc_id,
            coc.coc_checklist_programacion,
            coc.coc_checklist_plantilla_version,
            cpv.cpv_numero                            AS VERSION_NUMERO,
            coc.coc_fecha_programada_utc,
            coc.coc_fecha_limite_utc,
            coc.coc_checklist_ocurrencia_estado,
            ISNULL(coe.coe_codigo, '')                AS ESTADO_CODIGO,
            ISNULL(coe.coe_nombre, '')                AS ESTADO_NOMBRE,

            coc.coc_activo,
            ISNULL(act.act_codigo, '')                AS ACTIVO_CODIGO,
            ISNULL(act.act_nombre, '')                AS ACTIVO_NOMBRE,
            ISNULL(are.iar_nombre, '')                AS AREA_NOMBRE,
            ISNULL(pro.pro_nombre, '')                AS PROGRAMACION_NOMBRE,
            ISNULL(cpr.cpr_nombre, '')                AS PROGRAMACION_TITULO,
            cpr.cpr_usuario_responsable               AS RESPONSABLE_ID,
            ISNULL(res.usu_nombre + ' ' + ISNULL(res.usu_apellido_paterno, ''), '') AS RESPONSABLE_NOMBRE,

            eje.cej_id                                AS EJECUCION_ID,
            ISNULL(exe.usu_nombre + ' ' + ISNULL(exe.usu_apellido_paterno, ''), '') AS EJECUTOR_NOMBRE,
            eje.cej_fecha_inicio_utc                  AS EJECUCION_INICIO,
            eje.cej_fecha_fin_utc                     AS EJECUCION_FIN,
            eje.cej_duracion_minuto                   AS EJECUCION_MINUTOS,
            ISNULL(eje.cej_item_total, 0)             AS ITEM_TOTAL,
            ISNULL(eje.cej_item_respondido, 0)        AS ITEM_RESPONDIDO,
            ISNULL(eje.cej_item_no_conforme, 0)       AS ITEM_NO_CONFORME,
            ISNULL(eje.cej_observacion, '')           AS EJECUCION_OBSERVACION,
            ISNULL(eje.cej_dispositivo, '')           AS EJECUCION_DISPOSITIVO,

            /* Los hallazgos de la ronda: es la pregunta que se hace al mirar
               la lista -cual de estas rondas encontro algo-. */
            (SELECT COUNT(*) FROM [dbo].[Checklist_Hallazgo] cha
              WHERE cha.cha_checklist_ejecucion = eje.cej_id)   AS HALLAZGOS

    FROM    [dbo].[Checklist_Ocurrencia] coc
    JOIN    [dbo].[Checklist_Plantilla_Version] cpv ON cpv.cpv_id = coc.coc_checklist_plantilla_version
    LEFT JOIN [dbo].[Checklist_Ocurrencia_Estado] coe ON coe.coe_id = coc.coc_checklist_ocurrencia_estado
    LEFT JOIN [dbo].[Checklist_Programacion] cpr    ON cpr.cpr_id = coc.coc_checklist_programacion
    LEFT JOIN [dbo].[Programacion] pro              ON pro.pro_id = cpr.cpr_programacion
    LEFT JOIN [dbo].[Usuario] res                   ON res.usu_id = cpr.cpr_usuario_responsable
    LEFT JOIN [dbo].[Activo] act                    ON act.act_id = coc.coc_activo
    LEFT JOIN [dbo].[Instalacion_Area] are          ON are.iar_id = coc.coc_instalacion_area

    OUTER APPLY (SELECT TOP 1 *
                   FROM [dbo].[Checklist_Ejecucion] e
                  WHERE e.cej_checklist_ocurrencia = coc.coc_id
                    AND ISNULL(e.cej_habilitado, 1) = 1
                  ORDER BY ISNULL(e.cej_fecha_fin_utc, e.cej_fecha_creacion) DESC, e.cej_id DESC) eje

    LEFT JOIN [dbo].[Usuario] exe ON exe.usu_id = eje.cej_usuario_ejecutor

    WHERE   coc.coc_cliente = @CLIENTE
      AND   cpv.cpv_checklist_plantilla = @PLANTILLA
      AND   ISNULL(coc.coc_habilitado, 1) = 1
      AND   (@DESDE  IS NULL OR coc.coc_fecha_programada_utc >= @DESDE)
      AND   (@HASTA  IS NULL OR coc.coc_fecha_programada_utc <  @HASTA)
      AND   (@ESTADO IS NULL OR coc.coc_checklist_ocurrencia_estado = @ESTADO)

    ORDER BY coc.coc_fecha_programada_utc, coc.coc_id
GO
PRINT '--- SEL_CHECKLIST_OCURRENCIA creado.'
GO


/* ========================================================================
   2. SEL_CHECKLIST_EJECUCION_RESPUESTA

   Lo que el tecnico respondio, item por item y en el orden de la pauta.
   Se devuelven TODOS los items de la version, no solo los respondidos: un
   item sin respuesta tambien dice algo -quedo pendiente- y si se omitiera,
   la ronda se veria completa cuando no lo esta.

   El valor viene en cuatro columnas segun el tipo (texto, numero, fecha,
   si/no). Se arma una sola columna legible aca y no en la pantalla: la
   misma regla la necesitan la ficha, el informe y el correo.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_EJECUCION_RESPUESTA]
    @CLIENTE    INT,
    @EJECUCION  INT
AS
SET NOCOUNT ON

DECLARE @VERSION INT, @CLI INT

SELECT @VERSION = cej_checklist_plantilla_version, @CLI = cej_cliente
FROM   [dbo].[Checklist_Ejecucion]
WHERE  cej_id = @EJECUCION

IF @CLI IS NULL OR @CLI <> @CLIENTE RETURN

    SELECT  cpi.cpi_id,
            cpi.cpi_orden,
            cpi.cpi_texto,
            ISNULL(cpi.cpi_ayuda, '')                 AS ITEM_AYUDA,
            cpi.cpi_obligatorio,
            cpi.cpi_requiere_evidencia,
            ISNULL(cps.cps_nombre, '')                AS SECCION_NOMBRE,
            ISNULL(cps.cps_orden, 0)                  AS SECCION_ORDEN,
            ISNULL(cit.cit_codigo, '')                AS TIPO_CODIGO,
            ISNULL(cit.cit_nombre, '')                AS TIPO_NOMBRE,
            ISNULL(ume.ume_simbolo, '')               AS UNIDAD,

            cer.cer_id                                AS RESPUESTA_ID,
            cer.cer_fuera_rango,
            cer.cer_no_aplica,
            ISNULL(cer.cer_comentario, '')            AS COMENTARIO,
            cer.cer_fecha_respuesta_utc,

            /* El valor legible, elegido segun donde vino. El booleano se
               escribe Si/No y no 1/0: la ficha la lee una persona. */
            CASE
                WHEN cer.cer_id IS NULL THEN ''
                WHEN cer.cer_no_aplica = 1 THEN 'No aplica'
                WHEN cer.cer_valor_numero IS NOT NULL
                    THEN CONVERT(VARCHAR(40), CAST(cer.cer_valor_numero AS DECIMAL(18, 2))) + ISNULL(' ' + ume.ume_simbolo, '')
                WHEN cer.cer_valor_booleano IS NOT NULL
                    THEN CASE WHEN cer.cer_valor_booleano = 1 THEN 'Sí' ELSE 'No' END
                WHEN cer.cer_valor_fecha IS NOT NULL
                    THEN CONVERT(VARCHAR(16), cer.cer_valor_fecha, 120)
                ELSE ISNULL(cer.cer_valor_texto, '')
            END                                       AS VALOR,

            (SELECT COUNT(*)
               FROM [dbo].[Archivo_Vinculo] avi
               JOIN [dbo].[Archivo] arc ON arc.arc_id = avi.avi_archivo
              WHERE avi.avi_checklist_ejecucion_respuesta = cer.cer_id
                AND ISNULL(avi.avi_habilitado, 1) = 1
                AND ISNULL(arc.arc_habilitado, 1) = 1) AS EVIDENCIAS

    FROM    [dbo].[Checklist_Plantilla_Item] cpi
    LEFT JOIN [dbo].[Checklist_Plantilla_Seccion] cps ON cps.cps_id = cpi.cpi_checklist_plantilla_seccion
    LEFT JOIN [dbo].[Checklist_Item_Tipo] cit         ON cit.cit_id = cpi.cpi_checklist_item_tipo
    LEFT JOIN [dbo].[Unidad_Medida] ume               ON ume.ume_id = cpi.cpi_unidad_medida
    LEFT JOIN [dbo].[Checklist_Ejecucion_Respuesta] cer
           ON cer.cer_checklist_plantilla_item = cpi.cpi_id
          AND cer.cer_checklist_ejecucion = @EJECUCION
          AND ISNULL(cer.cer_habilitado, 1) = 1

    WHERE   cpi.cpi_checklist_plantilla_version = @VERSION
      AND   ISNULL(cpi.cpi_habilitado, 1) = 1

    ORDER BY ISNULL(cps.cps_orden, 0), cpi.cpi_orden, cpi.cpi_id
GO
PRINT '--- SEL_CHECKLIST_EJECUCION_RESPUESTA creado.'
GO


/* ========================================================================
   3. SEL_CHECKLIST_EJECUCION_ARCHIVO

   Las fotos de la ronda. Cuelgan de la RESPUESTA -avi_checklist_ejecucion_
   respuesta-, no de la ejecucion: la foto es de un item, y perder cual es
   deja una galeria de fotos sueltas que no prueban nada.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_EJECUCION_ARCHIVO]
    @CLIENTE    INT,
    @EJECUCION  INT
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

            cer.cer_id                                AS RESPUESTA_ID,
            ISNULL(cpi.cpi_texto, '')                 AS ITEM_TEXTO,
            ISNULL(cps.cps_nombre, '')                AS SECCION_NOMBRE,

            CAST(CASE WHEN ISNULL(arc.arc_mime, '') LIKE 'image/%' THEN 1 ELSE 0 END AS INT) AS ES_IMAGEN,
            CAST(CASE WHEN ISNULL(arc.arc_mime, '') LIKE 'video/%' THEN 1 ELSE 0 END AS INT) AS ES_VIDEO,
            CAST(CASE WHEN ISNULL(arc.arc_mime, '') LIKE 'audio/%' THEN 1 ELSE 0 END AS INT) AS ES_AUDIO

    FROM    [dbo].[Archivo_Vinculo] avi
    JOIN    [dbo].[Archivo] arc ON arc.arc_id = avi.avi_archivo
    JOIN    [dbo].[Checklist_Ejecucion_Respuesta] cer ON cer.cer_id = avi.avi_checklist_ejecucion_respuesta
    LEFT JOIN [dbo].[Checklist_Plantilla_Item] cpi    ON cpi.cpi_id = cer.cer_checklist_plantilla_item
    LEFT JOIN [dbo].[Checklist_Plantilla_Seccion] cps ON cps.cps_id = cpi.cpi_checklist_plantilla_seccion
    LEFT JOIN [dbo].[Usuario] usr                     ON usr.usu_id = arc.arc_usuario_creacion

    WHERE   cer.cer_checklist_ejecucion = @EJECUCION
      AND   arc.arc_cliente = @CLIENTE
      AND   ISNULL(arc.arc_habilitado, 1) = 1
      AND   ISNULL(avi.avi_habilitado, 1) = 1

    ORDER BY ISNULL(cps.cps_orden, 0), cpi.cpi_orden, avi.avi_orden, arc.arc_id
GO
PRINT '--- SEL_CHECKLIST_EJECUCION_ARCHIVO creado.'
GO

PRINT '266_CHECKLIST_CENTRO aplicado.'
GO
