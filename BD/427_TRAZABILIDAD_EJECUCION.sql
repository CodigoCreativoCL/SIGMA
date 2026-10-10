/* ============================================================================
   427 · Trazabilidad completa de una inspección o tarea (10-10-2026)

   El cliente: «debe verse la trazabilidad completa» de lo ejecutado en terreno. Una línea de tiempo
   por ocurrencia, de lo más antiguo a lo más nuevo:
     programada → reprogramaciones y cambios de estado (con motivo) → asignada / aceptada en la app →
     iniciada (dispositivo, sin señal) → sincronizada → enviada / hecha (resultado) →
     hallazgos (severidad) → descartados o con OT → OT creada, iniciada y cerrada.
     · SEL_TRAZA_EJECUCION(@CLIENTE, @TIPO 'INS'|'TAR', @OCURRENCIA)
       FECHA, CLASE (prog|estado|asig|acepta|inicio|sync|fin|hallazgo|descarte|ot|otini|otfin),
       TITULO, DETALLE, QUIEN, OT_ID, SEVERIDAD. Fechas en hora de planta.
   Aplicar DESPUÉS de 425. Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER FUNCTION [dbo].[FNC_NOMBRE_USUARIO_SIMPLE] (@USUARIO INT)
RETURNS NVARCHAR(300)
AS
BEGIN
    RETURN (SELECT NULLIF(LTRIM(RTRIM(ISNULL(usu_nombre, N'') + N' ' + ISNULL(usu_apellido_paterno, N''))), N'') FROM [dbo].[Usuario] WHERE usu_id = @USUARIO)
END
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_TRAZA_EJECUCION]
    @CLIENTE    INT,
    @TIPO       VARCHAR(4),
    @OCURRENCIA INT
AS
SET NOCOUNT ON
DECLARE @MIN INT = DATEDIFF(MINUTE, GETUTCDATE(), [dbo].[FNC_AHORA]())
DECLARE @T TABLE (FECHA DATETIME, ORDEN INT, CLASE VARCHAR(12), TITULO NVARCHAR(300), DETALLE NVARCHAR(600), QUIEN NVARCHAR(300), OT_ID INT, SEVERIDAD INT)
DECLARE @OTS TABLE (OT INT)

IF @TIPO = 'INS'
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ocurrencia] WHERE coc_id = @OCURRENCIA AND coc_cliente = @CLIENTE) RETURN 0
    INSERT @T SELECT c.coc_fecha_creacion, 1, 'prog', N'Programada', N'Para el ' + CONVERT(NVARCHAR(16), c.coc_fecha_programada_utc, 103) + N' ' + LEFT(CONVERT(NVARCHAR(8), c.coc_fecha_programada_utc, 108), 5) + ISNULL(N' · ' + NULLIF(p.cpr_nombre, N''), N''), [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](c.coc_usuario_creacion), NULL, NULL
    FROM [dbo].[Checklist_Ocurrencia] c LEFT JOIN [dbo].[Checklist_Programacion] p ON p.cpr_id = c.coc_checklist_programacion WHERE c.coc_id = @OCURRENCIA
    INSERT @T SELECT h.coh_fecha_creacion, 2, 'estado', ISNULL(N'Pasó a ' + LOWER(en.coe_nombre), N'Cambio'),
           ISNULL(N'De ' + LOWER(ea.coe_nombre), N'') + CASE WHEN h.coh_fecha_nueva_utc IS NOT NULL AND ISNULL(h.coh_fecha_anterior_utc, 0) <> h.coh_fecha_nueva_utc THEN N' · nueva fecha ' + CONVERT(NVARCHAR(16), h.coh_fecha_nueva_utc, 103) ELSE N'' END + ISNULL(N' · ' + h.coh_motivo, N''),
           [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](h.coh_usuario_creacion), NULL, NULL
    FROM [dbo].[Checklist_Ocurrencia_Historial] h
    LEFT JOIN [dbo].[Checklist_Ocurrencia_Estado] en ON en.coe_id = h.coh_estado_nuevo
    LEFT JOIN [dbo].[Checklist_Ocurrencia_Estado] ea ON ea.coe_id = h.coh_estado_anterior
    WHERE h.coh_checklist_ocurrencia = @OCURRENCIA
    INSERT @T SELECT ISNULL(DATEADD(MINUTE, @MIN, a.coa_fecha_asignacion_utc), a.coa_fecha_creacion), 3, 'asig', CASE WHEN a.coa_es_responsable = 1 THEN N'Asignada como responsable' ELSE N'Asignada de apoyo' END,
           COALESCE([dbo].[FNC_NOMBRE_USUARIO_SIMPLE](a.coa_usuario), N'Grupo ' + g.gtr_nombre, N'Empresa ' + pr.prv_razon_social), [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](a.coa_usuario_creacion), NULL, NULL
    FROM [dbo].[Checklist_Ocurrencia_Asignacion] a LEFT JOIN [dbo].[Grupo_Trabajo] g ON g.gtr_id = a.coa_grupo_trabajo LEFT JOIN [dbo].[Proveedor] pr ON pr.prv_id = a.coa_proveedor
    WHERE a.coa_checklist_ocurrencia = @OCURRENCIA
    INSERT @T SELECT DATEADD(MINUTE, @MIN, a.coa_fecha_aceptacion_utc), 4, 'acepta', N'La tomó en la app', NULL, [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](a.coa_usuario), NULL, NULL
    FROM [dbo].[Checklist_Ocurrencia_Asignacion] a WHERE a.coa_checklist_ocurrencia = @OCURRENCIA AND a.coa_fecha_aceptacion_utc IS NOT NULL
    INSERT @T SELECT DATEADD(MINUTE, @MIN, e.cej_fecha_inicio_utc), 5, 'inicio', N'Iniciada', ISNULL(e.cej_dispositivo, N'App') + CASE WHEN e.cej_offline_creado = 1 THEN N' · sin señal' ELSE N'' END, [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](e.cej_usuario_ejecutor), NULL, NULL
    FROM [dbo].[Checklist_Ejecucion] e WHERE e.cej_checklist_ocurrencia = @OCURRENCIA AND e.cej_habilitado = 1
    INSERT @T SELECT DATEADD(MINUTE, @MIN, e.cej_fecha_sincronizacion_utc), 7, 'sync', N'Llegó al servidor', N'Sincronizada desde ' + ISNULL(e.cej_dispositivo, N'la app'), NULL, NULL, NULL
    FROM [dbo].[Checklist_Ejecucion] e WHERE e.cej_checklist_ocurrencia = @OCURRENCIA AND e.cej_habilitado = 1 AND e.cej_fecha_sincronizacion_utc IS NOT NULL AND e.cej_offline_creado = 1
    INSERT @T SELECT DATEADD(MINUTE, @MIN, e.cej_fecha_fin_utc), 6, 'fin', N'Enviada', CAST(ISNULL(e.cej_item_respondido, 0) AS NVARCHAR(10)) + N' de ' + CAST(ISNULL(e.cej_item_total, 0) AS NVARCHAR(10)) + N' ítems · ' + CASE WHEN ISNULL(e.cej_item_no_conforme, 0) > 0 THEN CAST(e.cej_item_no_conforme AS NVARCHAR(10)) + N' no conformes' ELSE N'todo conforme' END + ISNULL(N' · «' + e.cej_observacion + N'»', N''),
           [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](e.cej_usuario_ejecutor), NULL, NULL
    FROM [dbo].[Checklist_Ejecucion] e WHERE e.cej_checklist_ocurrencia = @OCURRENCIA AND e.cej_habilitado = 1 AND e.cej_fecha_fin_utc IS NOT NULL
    INSERT @T SELECT hz.cha_fecha_creacion, 8, 'hallazgo', N'Hallazgo: ' + hz.cha_titulo, N'Pasó a Avisos', NULL, NULL, hz.cha_severidad
    FROM [dbo].[Checklist_Hallazgo] hz JOIN [dbo].[Checklist_Ejecucion] e ON e.cej_id = hz.cha_checklist_ejecucion WHERE e.cej_checklist_ocurrencia = @OCURRENCIA AND hz.cha_habilitado = 1
    INSERT @T SELECT ISNULL(hz.cha_fecha_actualizacion, hz.cha_fecha_creacion), 9, 'descarte', N'Hallazgo descartado: ' + hz.cha_titulo, hz.cha_motivo_descarte, [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](hz.cha_usuario_actualizacion), NULL, NULL
    FROM [dbo].[Checklist_Hallazgo] hz JOIN [dbo].[Checklist_Ejecucion] e ON e.cej_id = hz.cha_checklist_ejecucion WHERE e.cej_checklist_ocurrencia = @OCURRENCIA AND hz.cha_habilitado = 1 AND hz.cha_motivo_descarte IS NOT NULL
    INSERT @OTS SELECT DISTINCT o.otr_id FROM [dbo].[Orden_Trabajo] o JOIN [dbo].[Checklist_Hallazgo] hz ON (hz.cha_orden_trabajo = o.otr_id OR o.otr_checklist_hallazgo = hz.cha_id)
    JOIN [dbo].[Checklist_Ejecucion] e ON e.cej_id = hz.cha_checklist_ejecucion WHERE e.cej_checklist_ocurrencia = @OCURRENCIA AND o.otr_habilitado = 1
END
ELSE
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia] WHERE toc_id = @OCURRENCIA AND toc_cliente = @CLIENTE) RETURN 0
    INSERT @T SELECT o.toc_fecha_creacion, 1, 'prog', N'Programada', N'Para el ' + CONVERT(NVARCHAR(16), o.toc_fecha_programada_utc, 103) + N' ' + LEFT(CONVERT(NVARCHAR(8), o.toc_fecha_programada_utc, 108), 5) + N' · ' + t.tar_codigo + N' ' + t.tar_titulo, [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](o.toc_usuario_creacion), NULL, NULL
    FROM [dbo].[Tarea_Ocurrencia] o JOIN [dbo].[Tarea] t ON t.tar_id = o.toc_tarea WHERE o.toc_id = @OCURRENCIA
    INSERT @T SELECT h.thi_fecha_creacion, 2, 'estado', ISNULL(N'Pasó a ' + LOWER(en.toe_nombre), N'Cambio'),
           ISNULL(N'De ' + LOWER(ea.toe_nombre), N'') + CASE WHEN h.thi_fecha_nueva_utc IS NOT NULL AND ISNULL(h.thi_fecha_anterior_utc, 0) <> h.thi_fecha_nueva_utc THEN N' · nueva fecha ' + CONVERT(NVARCHAR(16), h.thi_fecha_nueva_utc, 103) ELSE N'' END + ISNULL(N' · ' + h.thi_motivo, N''),
           [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](h.thi_usuario_creacion), NULL, NULL
    FROM [dbo].[Tarea_Historial] h LEFT JOIN [dbo].[Tarea_Ocurrencia_Estado] en ON en.toe_id = h.thi_estado_nuevo LEFT JOIN [dbo].[Tarea_Ocurrencia_Estado] ea ON ea.toe_id = h.thi_estado_anterior
    WHERE h.thi_tarea_ocurrencia = @OCURRENCIA
    INSERT @T SELECT ISNULL(DATEADD(MINUTE, @MIN, a.toa_fecha_asignacion_utc), a.toa_fecha_creacion), 3, 'asig', CASE WHEN a.toa_es_responsable = 1 THEN N'Asignada como responsable' ELSE N'Asignada de apoyo' END,
           COALESCE([dbo].[FNC_NOMBRE_USUARIO_SIMPLE](a.toa_usuario), N'Grupo ' + g.gtr_nombre, N'Empresa ' + pr.prv_razon_social), [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](a.toa_usuario_creacion), NULL, NULL
    FROM [dbo].[Tarea_Ocurrencia_Asignacion] a LEFT JOIN [dbo].[Grupo_Trabajo] g ON g.gtr_id = a.toa_grupo_trabajo LEFT JOIN [dbo].[Proveedor] pr ON pr.prv_id = a.toa_proveedor
    WHERE a.toa_tarea_ocurrencia = @OCURRENCIA
    INSERT @T SELECT DATEADD(MINUTE, @MIN, a.toa_fecha_aceptacion_utc), 4, 'acepta', N'La tomó en la app', NULL, [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](a.toa_usuario), NULL, NULL
    FROM [dbo].[Tarea_Ocurrencia_Asignacion] a WHERE a.toa_tarea_ocurrencia = @OCURRENCIA AND a.toa_fecha_aceptacion_utc IS NOT NULL
    INSERT @T SELECT DATEADD(MINUTE, @MIN, e.tej_fecha_inicio_utc), 5, 'inicio', N'Iniciada', ISNULL(e.tej_dispositivo, N'App') + CASE WHEN e.tej_offline_creado = 1 THEN N' · sin señal' ELSE N'' END, [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](e.tej_usuario_ejecutor), NULL, NULL
    FROM [dbo].[Tarea_Ejecucion] e WHERE e.tej_tarea_ocurrencia = @OCURRENCIA AND e.tej_habilitado = 1
    INSERT @T SELECT DATEADD(MINUTE, @MIN, e.tej_fecha_sincronizacion_utc), 7, 'sync', N'Llegó al servidor', N'Sincronizada desde ' + ISNULL(e.tej_dispositivo, N'la app'), NULL, NULL, NULL
    FROM [dbo].[Tarea_Ejecucion] e WHERE e.tej_tarea_ocurrencia = @OCURRENCIA AND e.tej_habilitado = 1 AND e.tej_fecha_sincronizacion_utc IS NOT NULL AND e.tej_offline_creado = 1
    INSERT @T SELECT DATEADD(MINUTE, @MIN, e.tej_fecha_fin_utc), 6, 'fin', N'Hecha · ' + CASE WHEN e.tej_conforme = 0 THEN N'no conforme' WHEN e.tej_conforme = 1 THEN N'conforme' ELSE N'sin calificar' END, e.tej_resultado, [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](e.tej_usuario_ejecutor), NULL, NULL
    FROM [dbo].[Tarea_Ejecucion] e WHERE e.tej_tarea_ocurrencia = @OCURRENCIA AND e.tej_habilitado = 1 AND e.tej_fecha_fin_utc IS NOT NULL
    INSERT @OTS SELECT toc_orden_trabajo FROM [dbo].[Tarea_Ocurrencia] WHERE toc_id = @OCURRENCIA AND toc_orden_trabajo IS NOT NULL
END

/* La OT que nació de esto: creada, iniciada y cerrada. */
INSERT @T SELECT o.otr_fecha_creacion, 10, 'ot', N'OT-' + CAST(o.otr_correlativo AS NVARCHAR(12)) + N' creada', o.otr_titulo + N' · ' + LOWER(es.ote_nombre), [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](o.otr_usuario_creacion), o.otr_id, NULL
FROM @OTS x JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = x.OT JOIN [dbo].[Orden_Trabajo_Estado] es ON es.ote_id = o.otr_orden_trabajo_estado
INSERT @T SELECT DATEADD(MINUTE, @MIN, o.otr_fecha_inicio_real_utc), 11, 'otini', N'OT-' + CAST(o.otr_correlativo AS NVARCHAR(12)) + N' en ejecución', NULL, NULL, o.otr_id, NULL
FROM @OTS x JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = x.OT WHERE o.otr_fecha_inicio_real_utc IS NOT NULL
INSERT @T SELECT o.otr_fecha_cierre, 12, 'otfin', N'OT-' + CAST(o.otr_correlativo AS NVARCHAR(12)) + N' cerrada', NULL, NULL, o.otr_id, NULL
FROM @OTS x JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = x.OT WHERE o.otr_fecha_cierre IS NOT NULL

SELECT FECHA, CLASE, TITULO, DETALLE, NULLIF(QUIEN, N'') AS QUIEN, OT_ID, SEVERIDAD FROM @T WHERE FECHA IS NOT NULL ORDER BY FECHA, ORDEN
RETURN 0
GO
PRINT '427_TRAZABILIDAD_EJECUCION aplicado.'
GO
