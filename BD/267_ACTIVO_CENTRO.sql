USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  23-09-2026
-- DESCRIPTION:     LO QUE LE FALTABA AL CENTRO DEL ACTIVO 360.
--                  1. SEL_ACTIVO_INSPECCION_TAREA  (que se le reviso)
--                  2. SEL_ACTIVO_REPUESTO_CONSUMO  (que se le cambio)
--                  3. SEL_ACTIVO_COSTO_RESUMEN     (cuanto costo)
--                  4. SEL_ACTIVO_BITACORA          (que se anoto de el)
-- =============================================
-- Las consultas que ya existian son por plantilla, por tarea o por orden.
-- El centro del activo pregunta al reves: dado UN equipo, que se le hizo.
-- Resolverlo desde la pantalla obligaria a recorrer las ordenes una por una
-- -una llamada por orden- y el equipo con mas historia seria justamente el
-- mas lento de abrir. Por eso los cuatro reciben el activo y devuelven la
-- respuesta completa en una sola vuelta.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* ========================================================================
   1. SEL_ACTIVO_INSPECCION_TAREA

   Inspecciones -checklists- y tareas del equipo en una sola lista. Van
   juntas porque para quien opera la planta son lo mismo: algo que hay que
   pasar a revisar y que deja un resultado.

   Se devuelven DOS estados distintos y no conviene mezclarlos:
     ESTADO     es el avance    (pendiente / en ejecucion / completada)
     RESULTADO  es la evaluacion (sin evaluar / conforme / con observacion)
   Una inspeccion completada con hallazgos esta terminada y mal; son dos
   preguntas distintas y la pantalla las muestra en columnas distintas.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_INSPECCION_TAREA]
    @CLIENTE  INT,
    @ACTIVO   INT,
    @DESDE    DATETIME = NULL,
    @HASTA    DATETIME = NULL
AS
SET NOCOUNT ON

    SELECT  *
    FROM   (
        /* ---- inspecciones (checklist) ---- */
        SELECT  'INSPECCION'                          AS TIPO,
                coc.coc_id                            AS OCURRENCIA_ID,
                eje.cej_id                            AS EJECUCION_ID,
                ISNULL(cpl.cpl_nombre, '')            AS NOMBRE,
                ISNULL(cpl.cpl_descripcion, '')       AS DESCRIPCION,
                ISNULL(cpl.cpl_codigo, '')            AS CODIGO,
                ISNULL(eje.cej_fecha_fin_utc, coc.coc_fecha_programada_utc) AS FECHA,
                coc.coc_fecha_programada_utc          AS FECHA_PROGRAMADA,
                ISNULL(coe.coe_codigo, '')            AS ESTADO_CODIGO,
                ISNULL(coe.coe_nombre, '')            AS ESTADO_NOMBRE,

                /* Sin ejecucion no hay nada que evaluar; con items no
                   conformes hay hallazgo; lo demas esta conforme. */
                CASE WHEN eje.cej_id IS NULL                  THEN 'SIN_EVALUAR'
                     WHEN ISNULL(eje.cej_item_no_conforme, 0) > 0 THEN 'CON_OBSERVACION'
                     ELSE 'CONFORME' END              AS RESULTADO_CODIGO,

                ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '') AS RESPONSABLE_NOMBRE,
                ISNULL(eje.cej_item_total, 0)         AS ITEM_TOTAL,
                ISNULL(eje.cej_item_respondido, 0)    AS ITEM_RESPONDIDO,
                ISNULL(eje.cej_item_no_conforme, 0)   AS ITEM_NO_CONFORME,
                ISNULL(eje.cej_observacion, '')       AS OBSERVACION,
                ISNULL(eje.cej_dispositivo, '')       AS DISPOSITIVO,

                /* Las fotos de una inspeccion cuelgan de la RESPUESTA, no
                   de la ejecucion: se fotografia un item, no el recorrido. */
                (SELECT COUNT(*) FROM [dbo].[Archivo_Vinculo] avi
                  JOIN [dbo].[Archivo] arc ON arc.arc_id = avi.avi_archivo
                  JOIN [dbo].[Checklist_Ejecucion_Respuesta] cer ON cer.cer_id = avi.avi_checklist_ejecucion_respuesta
                  WHERE cer.cer_checklist_ejecucion = eje.cej_id
                    AND ISNULL(avi.avi_habilitado, 1) = 1
                    AND ISNULL(arc.arc_habilitado, 1) = 1)   AS EVIDENCIAS

        FROM    [dbo].[Checklist_Ocurrencia] coc
        LEFT JOIN [dbo].[Checklist_Plantilla_Version] cpv ON cpv.cpv_id = coc.coc_checklist_plantilla_version
        LEFT JOIN [dbo].[Checklist_Plantilla] cpl         ON cpl.cpl_id = cpv.cpv_checklist_plantilla
        LEFT JOIN [dbo].[Checklist_Ocurrencia_Estado] coe ON coe.coe_id = coc.coc_checklist_ocurrencia_estado

        OUTER APPLY (SELECT TOP 1 *
                       FROM [dbo].[Checklist_Ejecucion] e
                      WHERE e.cej_checklist_ocurrencia = coc.coc_id
                        AND ISNULL(e.cej_habilitado, 1) = 1
                      ORDER BY ISNULL(e.cej_fecha_fin_utc, e.cej_fecha_creacion) DESC, e.cej_id DESC) eje

        LEFT JOIN [dbo].[Usuario] usr ON usr.usu_id = eje.cej_usuario_ejecutor

        WHERE   coc.coc_cliente = @CLIENTE
          AND   coc.coc_activo  = @ACTIVO
          AND   ISNULL(coc.coc_habilitado, 1) = 1

        UNION ALL

        /* ---- tareas ---- */
        SELECT  'TAREA'                               AS TIPO,
                toc.toc_id                            AS OCURRENCIA_ID,
                tej.tej_id                            AS EJECUCION_ID,
                ISNULL(tar.tar_titulo, '')            AS NOMBRE,
                ISNULL(tar.tar_descripcion, '')       AS DESCRIPCION,
                ISNULL(tar.tar_codigo, '')            AS CODIGO,
                ISNULL(tej.tej_fecha_fin_utc, toc.toc_fecha_programada_utc) AS FECHA,
                toc.toc_fecha_programada_utc          AS FECHA_PROGRAMADA,
                ISNULL(toe.toe_codigo, '')            AS ESTADO_CODIGO,
                ISNULL(toe.toe_nombre, '')            AS ESTADO_NOMBRE,

                CASE WHEN tej.tej_id IS NULL        THEN 'SIN_EVALUAR'
                     WHEN tej.tej_conforme = 0      THEN 'CON_OBSERVACION'
                     ELSE 'CONFORME' END             AS RESULTADO_CODIGO,

                ISNULL(exe.usu_nombre + ' ' + ISNULL(exe.usu_apellido_paterno, ''),
                       ISNULL(res.usu_nombre + ' ' + ISNULL(res.usu_apellido_paterno, ''), '')) AS RESPONSABLE_NOMBRE,
                0                                     AS ITEM_TOTAL,
                0                                     AS ITEM_RESPONDIDO,
                CASE WHEN tej.tej_conforme = 0 THEN 1 ELSE 0 END AS ITEM_NO_CONFORME,

                /* Lo que el tecnico escribio en la app manda sobre lo que
                   quedo anotado al programar la ocurrencia. */
                CASE WHEN ISNULL(tej.tej_resultado, '') <> '' THEN tej.tej_resultado
                     ELSE ISNULL(toc.toc_observacion, '') END AS OBSERVACION,
                ISNULL(tej.tej_dispositivo, '')       AS DISPOSITIVO,

                (SELECT COUNT(*) FROM [dbo].[Archivo_Vinculo] avi
                  JOIN [dbo].[Archivo] arc ON arc.arc_id = avi.avi_archivo
                  WHERE avi.avi_tarea_ejecucion = tej.tej_id
                    AND ISNULL(avi.avi_habilitado, 1) = 1
                    AND ISNULL(arc.arc_habilitado, 1) = 1)   AS EVIDENCIAS

        FROM    [dbo].[Tarea_Ocurrencia] toc
        JOIN    [dbo].[Tarea] tar                       ON tar.tar_id = toc.toc_tarea
        LEFT JOIN [dbo].[Tarea_Ocurrencia_Estado] toe   ON toe.toe_id = toc.toc_tarea_ocurrencia_estado
        LEFT JOIN [dbo].[Tarea_Programacion] tpr        ON tpr.tpr_id = toc.toc_tarea_programacion
        LEFT JOIN [dbo].[Usuario] res                   ON res.usu_id = tpr.tpr_usuario_responsable

        OUTER APPLY (SELECT TOP 1 *
                       FROM [dbo].[Tarea_Ejecucion] e
                      WHERE e.tej_tarea_ocurrencia = toc.toc_id
                        AND ISNULL(e.tej_habilitado, 1) = 1
                      ORDER BY ISNULL(e.tej_fecha_fin_utc, e.tej_fecha_creacion) DESC, e.tej_id DESC) tej

        LEFT JOIN [dbo].[Usuario] exe ON exe.usu_id = tej.tej_usuario_ejecutor

        WHERE   toc.toc_cliente = @CLIENTE
          AND   tar.tar_activo  = @ACTIVO
          AND   ISNULL(toc.toc_habilitado, 1) = 1
    ) u

    WHERE   (@DESDE IS NULL OR u.FECHA >= @DESDE)
      AND   (@HASTA IS NULL OR u.FECHA <  @HASTA)

    ORDER BY u.FECHA DESC, u.OCURRENCIA_ID DESC
GO
PRINT '--- SEL_ACTIVO_INSPECCION_TAREA creado.'
GO


/* ========================================================================
   2. SEL_ACTIVO_REPUESTO_CONSUMO

   Todo lo que salio de bodega para este equipo, sin importar en que orden
   se gasto. Es la pregunta que hace mantenimiento antes de decidir si
   conviene reparar otra vez: cuantos sellos lleva este ano esta bomba.

   El costo sigue la misma regla del bloque 263 -consumido menos devuelto-
   para que la ficha del activo y la de la orden no digan cosas distintas.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_REPUESTO_CONSUMO]
    @CLIENTE  INT,
    @ACTIVO   INT,
    @DESDE    DATETIME = NULL,
    @HASTA    DATETIME = NULL
AS
SET NOCOUNT ON

    SELECT  r.ore_id,
            r.ore_repuesto,
            ISNULL(rep.rep_codigo, '')                AS REPUESTO_CODIGO,
            ISNULL(rep.rep_nombre, '')                AS REPUESTO_NOMBRE,
            ISNULL(ume.ume_codigo, '')                AS UNIDAD,
            ISNULL(com.aco_nombre, '')                AS COMPONENTE,

            ISNULL(r.ore_cantidad_consumida, 0) - ISNULL(r.ore_cantidad_devuelta, 0) AS CANTIDAD,
            ISNULL(r.ore_cantidad_devuelta, 0)        AS DEVUELTA,
            ISNULL(r.ore_costo_unitario, 0)           AS COSTO_UNITARIO,
            ISNULL(mon.mon_codigo, '')                AS MONEDA,

            CAST(ISNULL(r.ore_costo_unitario, 0) *
                 (ISNULL(r.ore_cantidad_consumida, 0) - ISNULL(r.ore_cantidad_devuelta, 0)) AS DECIMAL(18, 2)) AS COSTO,

            o.otr_id                                  AS ORDEN_ID,
            ISNULL(o.otr_correlativo, 0)              AS ORDEN_CORRELATIVO,
            ISNULL(o.otr_titulo, '')                  AS ORDEN_TITULO,
            ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_evento_utc) AS FECHA,
            ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '') AS USUARIO_NOMBRE

    FROM    [dbo].[Orden_Trabajo_Repuesto] r
    JOIN    [dbo].[Orden_Trabajo] o            ON o.otr_id = r.ore_orden_trabajo
    LEFT JOIN [dbo].[Repuesto] rep             ON rep.rep_id = r.ore_repuesto
    LEFT JOIN [dbo].[Unidad_Medida] ume        ON ume.ume_id = rep.rep_unidad_medida
    LEFT JOIN [dbo].[Activo_Componente] com    ON com.aco_id = r.ore_activo_componente
    LEFT JOIN [dbo].[Moneda] mon               ON mon.mon_id = r.ore_moneda
    LEFT JOIN [dbo].[Usuario] usr              ON usr.usu_id = r.ore_usuario_creacion

    WHERE   o.otr_cliente = @CLIENTE
      AND   o.otr_activo  = @ACTIVO
      AND   ISNULL(r.ore_habilitado, 1) = 1

      /* Una linea reservada y nunca consumida no es un consumo: no se
         muestra para que el total no cuente lo que sigue en bodega. */
      AND   ISNULL(r.ore_cantidad_consumida, 0) > 0

      AND   (@DESDE IS NULL OR ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_evento_utc) >= @DESDE)
      AND   (@HASTA IS NULL OR ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_evento_utc) <  @HASTA)

    ORDER BY ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_evento_utc) DESC, r.ore_id DESC
GO
PRINT '--- SEL_ACTIVO_REPUESTO_CONSUMO creado.'
GO


/* ========================================================================
   3. SEL_ACTIVO_COSTO_RESUMEN

   Una fila con los tres totales del equipo en el periodo: materiales,
   mano de obra y servicios contratados.

   Es lo unico REGISTRADO, no lo que costo de verdad: si nadie cargo las
   horas del tecnico, la mano de obra sale en cero. La pantalla lo dice
   con todas sus letras en vez de mostrar un total que invita a concluir
   que mantener este equipo salio barato.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_COSTO_RESUMEN]
    @CLIENTE  INT,
    @ACTIVO   INT,
    @DESDE    DATETIME = NULL,
    @HASTA    DATETIME = NULL
AS
SET NOCOUNT ON

    ;WITH ot AS (
        SELECT  o.otr_id
        FROM    [dbo].[Orden_Trabajo] o
        WHERE   o.otr_cliente = @CLIENTE
          AND   o.otr_activo  = @ACTIVO
          AND   (@DESDE IS NULL OR ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_evento_utc) >= @DESDE)
          AND   (@HASTA IS NULL OR ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_evento_utc) <  @HASTA)
    )
    SELECT
        (SELECT COUNT(*) FROM ot)                                     AS ORDENES,

        ISNULL((SELECT SUM(CAST(ISNULL(r.ore_costo_unitario, 0) *
                    (ISNULL(r.ore_cantidad_consumida, 0) - ISNULL(r.ore_cantidad_devuelta, 0)) AS DECIMAL(18, 2)))
                  FROM [dbo].[Orden_Trabajo_Repuesto] r
                  JOIN ot ON ot.otr_id = r.ore_orden_trabajo
                 WHERE ISNULL(r.ore_habilitado, 1) = 1), 0)           AS COSTO_MATERIAL,

        ISNULL((SELECT COUNT(*)
                  FROM [dbo].[Orden_Trabajo_Repuesto] r
                  JOIN ot ON ot.otr_id = r.ore_orden_trabajo
                 WHERE ISNULL(r.ore_habilitado, 1) = 1
                   AND ISNULL(r.ore_cantidad_consumida, 0) > 0), 0)   AS LINEAS_MATERIAL,

        ISNULL((SELECT SUM(CAST(ISNULL(m.omo_costo_hora, 0) * ISNULL(m.omo_minuto, 0) / 60.0 AS DECIMAL(18, 2)))
                  FROM [dbo].[Orden_Trabajo_Mano_Obra] m
                  JOIN ot ON ot.otr_id = m.omo_orden_trabajo), 0)     AS COSTO_MANO_OBRA,

        ISNULL((SELECT SUM(ISNULL(m.omo_minuto, 0))
                  FROM [dbo].[Orden_Trabajo_Mano_Obra] m
                  JOIN ot ON ot.otr_id = m.omo_orden_trabajo), 0)     AS MINUTOS_MANO_OBRA,

        ISNULL((SELECT SUM(CAST(ISNULL(s.ots_monto,
                    ISNULL(s.ots_monto_unitario, 0) * ISNULL(s.ots_cantidad, 0)) AS DECIMAL(18, 2)))
                  FROM [dbo].[Orden_Trabajo_Servicio] s
                  JOIN ot ON ot.otr_id = s.ots_orden_trabajo
                 WHERE ISNULL(s.ots_habilitado, 1) = 1), 0)           AS COSTO_SERVICIO,

        ISNULL((SELECT COUNT(*)
                  FROM [dbo].[Orden_Trabajo_Servicio] s
                  JOIN ot ON ot.otr_id = s.ots_orden_trabajo
                 WHERE ISNULL(s.ots_habilitado, 1) = 1), 0)           AS LINEAS_SERVICIO
GO
PRINT '--- SEL_ACTIVO_COSTO_RESUMEN creado.'
GO


/* ========================================================================
   4. SEL_ACTIVO_BITACORA

   Lo que la gente anoto del equipo: turnos, traslados, observaciones que
   no alcanzaron a ser una orden. Se devuelve con su tipo y su severidad
   porque una nota de turno y un "se escucha un golpe" no pesan igual.

   La bitacora no se edita. Una correccion entra como un registro nuevo y
   por eso esta consulta solo lee: la trazabilidad se pierde el dia que
   alguien puede arreglar lo que escribio ayer.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_BITACORA]
    @CLIENTE  INT,
    @ACTIVO   INT,
    @DESDE    DATETIME = NULL,
    @HASTA    DATETIME = NULL
AS
SET NOCOUNT ON

    SELECT  b.bit_id,
            ISNULL(bti.bti_codigo, '')                AS TIPO_CODIGO,
            ISNULL(bti.bti_nombre, 'Registro')        AS TIPO_NOMBRE,
            ISNULL(bti.bti_icono, 'mdi-note-text-outline') AS TIPO_ICONO,
            ISNULL(b.bit_titulo, '')                  AS TITULO,
            ISNULL(b.bit_texto, '')                   AS TEXTO,
            b.bit_fecha_evento_utc                    AS FECHA,
            ISNULL(b.bit_turno, '')                   AS TURNO,
            ISNULL(b.bit_requiere_atencion, 0)        AS REQUIERE_ATENCION,
            ISNULL(sev.sev_codigo, '')                AS SEVERIDAD_CODIGO,
            ISNULL(sev.sev_nombre, '')                AS SEVERIDAD_NOMBRE,
            ISNULL(com.aco_nombre, '')                AS COMPONENTE,
            b.bit_orden_trabajo                       AS ORDEN_ID,
            ISNULL(o.otr_correlativo, 0)              AS ORDEN_CORRELATIVO,

            /* Web o app: importa para auditar. Un registro creado sin
               conexion y sincronizado despues no llego cuando dice su
               fecha, y esa diferencia es justo lo que se revisa. */
            CASE WHEN ISNULL(b.bit_entrada_modo, 0) = 0 THEN 'Web' ELSE 'App movil' END AS ORIGEN,
            ISNULL(b.bit_offline_creado, 0)           AS OFFLINE,
            b.bit_fecha_sincronizacion_utc            AS FECHA_SINCRONIZACION,
            ISNULL(b.bit_dictado_voz, 0)              AS DICTADO,

            ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '') AS USUARIO_NOMBRE,
            b.bit_fecha_creacion                      AS FECHA_REGISTRO

    FROM    [dbo].[Bitacora] b
    LEFT JOIN [dbo].[Bitacora_Tipo] bti        ON bti.bti_id = b.bit_bitacora_tipo
    LEFT JOIN [dbo].[Severidad] sev            ON sev.sev_id = b.bit_severidad
    LEFT JOIN [dbo].[Activo_Componente] com    ON com.aco_id = b.bit_activo_componente
    LEFT JOIN [dbo].[Orden_Trabajo] o          ON o.otr_id = b.bit_orden_trabajo
    LEFT JOIN [dbo].[Usuario] usr              ON usr.usu_id = b.bit_usuario_creacion

    WHERE   b.bit_cliente = @CLIENTE
      AND   b.bit_activo  = @ACTIVO
      AND   (@DESDE IS NULL OR b.bit_fecha_evento_utc >= @DESDE)
      AND   (@HASTA IS NULL OR b.bit_fecha_evento_utc <  @HASTA)

    ORDER BY b.bit_fecha_evento_utc DESC, b.bit_id DESC
GO
PRINT '--- SEL_ACTIVO_BITACORA creado.'
GO

PRINT '267_ACTIVO_CENTRO aplicado.'
GO
