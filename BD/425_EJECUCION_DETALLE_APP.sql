/* ============================================================================
   425 · Ver lo que se ejecutó en terreno (app) desde la web (09-10-2026)

   El cliente: «¿dónde veo la inspección o tarea que ejecutó el usuario en la APP?». Las pantallas
   antiguas (ChecklistHistorial, Tareas) lo mostraban; el rediseño solo dejaba «Sin hallazgos».
     · SEL_OPERACION_INSPECCION (BD/418) + conjuntos:
         3 · respuestas de la ejecución: ítem, valor legible, fuera de rango, N/A, comentario, voz
         4 · fotos de la ejecución (Archivo_Vinculo por respuesta) → la URL la arma el WS
         5 · datos de la ejecución: inicio, fin, duración, dispositivo, sin señal, ubicación, observación
     · SEL_OPERACION_TAREA(@CLIENTE, @OCURRENCIA): la ocurrencia de la tarea con sus ejecuciones
       (quién, cuándo, cuánto duró, resultado, conforme) y sus fotos.
   Aplicar DESPUÉS de 418. Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_OPERACION_INSPECCION]
    @CLIENTE    INT,
    @OCURRENCIA INT
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA](), @VER INT, @CEJ INT, @MIN INT = DATEDIFF(MINUTE, GETUTCDATE(), [dbo].[FNC_AHORA]())
SELECT @VER = coc_checklist_plantilla_version FROM [dbo].[Checklist_Ocurrencia] WHERE coc_id = @OCURRENCIA AND coc_cliente = @CLIENTE AND coc_habilitado = 1
SELECT TOP 1 @CEJ = cej_id FROM [dbo].[Checklist_Ejecucion]
WHERE cej_checklist_ocurrencia = @OCURRENCIA AND cej_habilitado = 1 AND cej_checklist_ejecucion_estado IN (2, 3, 4)
ORDER BY cej_id DESC
/* La versión con que se ejecutó manda (pudo publicarse otra después). */
SELECT @VER = ISNULL((SELECT cej_checklist_plantilla_version FROM [dbo].[Checklist_Ejecucion] WHERE cej_id = @CEJ), @VER)

SELECT  c.coc_id AS OCURRENCIA, ISNULL(NULLIF(p.cpr_nombre, N''), N'Inspección') AS NOMBRE,
        c.coc_fecha_programada_utc AS FECHA, c.coc_fecha_limite_utc AS LIMITE, c.coc_fecha_disponible_utc AS DISPONIBLE,
        c.coc_checklist_ocurrencia_estado AS ESTADO_ID, oe.coe_nombre AS ESTADO,
        CAST(CASE WHEN c.coc_checklist_ocurrencia_estado IN (1, 2, 3) AND ISNULL(c.coc_fecha_disponible_utc, c.coc_fecha_programada_utc) <= @AHORA AND @CEJ IS NULL THEN 1 ELSE 0 END AS BIT) AS PUEDE,
        CAST(CASE WHEN c.coc_fecha_limite_utc IS NOT NULL AND c.coc_fecha_limite_utc < @AHORA AND c.coc_checklist_ocurrencia_estado IN (1, 2, 3) THEN 1 ELSE 0 END AS BIT) AS VENCIDA,
        cpl.cpl_id AS PAUTA_ID, cpl.cpl_codigo AS PAUTA_CODIGO, cpl.cpl_nombre AS PAUTA, v.cpv_numero AS PAUTA_VERSION,
        CAST(CASE WHEN v.cpv_checklist_version_estado = 2 THEN 1 ELSE 0 END AS BIT) AS PUBLICADA,
        a.act_codigo AS ACTIVO_CODIGO, a.act_nombre AS ACTIVO,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE,
        @CEJ AS EJECUCION, DATEADD(MINUTE, @MIN, ej.cej_fecha_fin_utc) AS HECHA_EL,
        LTRIM(RTRIM(ISNULL(ue.usu_nombre, N'') + N' ' + ISNULL(ue.usu_apellido_paterno, N''))) AS HECHA_POR
FROM    [dbo].[Checklist_Ocurrencia] c
JOIN    [dbo].[Checklist_Ocurrencia_Estado] oe ON oe.coe_id = c.coc_checklist_ocurrencia_estado
JOIN    [dbo].[Checklist_Plantilla_Version] v ON v.cpv_id = @VER
JOIN    [dbo].[Checklist_Plantilla] cpl ON cpl.cpl_id = v.cpv_checklist_plantilla
LEFT JOIN [dbo].[Checklist_Programacion] p ON p.cpr_id = c.coc_checklist_programacion
LEFT JOIN [dbo].[Activo] a ON a.act_id = c.coc_activo
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = p.cpr_usuario_responsable
LEFT JOIN [dbo].[Checklist_Ejecucion] ej ON ej.cej_id = @CEJ
LEFT JOIN [dbo].[Usuario] ue ON ue.usu_id = ej.cej_usuario_ejecutor
WHERE   c.coc_id = @OCURRENCIA AND c.coc_cliente = @CLIENTE AND c.coc_habilitado = 1

SELECT  i.cpi_id AS ID, ISNULL(s.cps_nombre, N'General') AS SECCION, i.cpi_texto AS TEXTO, i.cpi_checklist_item_tipo AS TIPO,
        cv.civ_valor_minimo AS MINIMO, cv.civ_valor_maximo AS MAXIMO, ISNULL(um.ume_simbolo, N'') AS UNIDAD,
        ISNULL(i.cpi_critico, 0) AS CRITICO, i.cpi_obligatorio AS OBLIGATORIO
FROM    [dbo].[Checklist_Plantilla_Item] i
LEFT JOIN [dbo].[Checklist_Plantilla_Seccion] s ON s.cps_id = i.cpi_checklist_plantilla_seccion
LEFT JOIN [dbo].[Checklist_Item_Validacion] cv ON cv.civ_checklist_plantilla_item = i.cpi_id AND cv.civ_habilitado = 1
LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = i.cpi_unidad_medida
WHERE   i.cpi_checklist_plantilla_version = @VER AND i.cpi_habilitado = 1
ORDER BY ISNULL(s.cps_orden, 0), i.cpi_orden

SELECT  hz.cha_id AS ID, hz.cha_titulo AS ITEM, hz.cha_severidad AS SEVERIDAD
FROM    [dbo].[Checklist_Hallazgo] hz
WHERE   hz.cha_checklist_ejecucion = @CEJ AND hz.cha_habilitado = 1

/* 3 · respuestas */
SELECT  r.cer_id AS ID, r.cer_checklist_plantilla_item AS ITEM,
        CASE WHEN r.cer_no_aplica = 1 THEN N'No aplica'
             WHEN r.cer_valor_booleano IS NOT NULL THEN CASE WHEN r.cer_valor_booleano = 1 THEN N'Cumple' ELSE N'No cumple' END
             WHEN r.cer_valor_numero IS NOT NULL THEN CAST(CAST(r.cer_valor_numero AS DECIMAL(18,2)) AS NVARCHAR(30)) + ISNULL(N' ' + um.ume_simbolo, N'')
             WHEN r.cer_valor_fecha IS NOT NULL THEN CONVERT(NVARCHAR(16), r.cer_valor_fecha, 120)
             WHEN o.cio_texto IS NOT NULL THEN o.cio_texto
             ELSE r.cer_valor_texto END AS VALOR,
        CAST(ISNULL(r.cer_fuera_rango, 0) AS BIT) AS FUERA, CAST(ISNULL(r.cer_no_aplica, 0) AS BIT) AS NA,
        r.cer_comentario AS COMENTARIO, CAST(ISNULL(r.cer_dictado_voz, 0) AS BIT) AS VOZ
FROM    [dbo].[Checklist_Ejecucion_Respuesta] r
LEFT JOIN [dbo].[Checklist_Plantilla_Item] i ON i.cpi_id = r.cer_checklist_plantilla_item
LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = ISNULL(r.cer_unidad_medida, i.cpi_unidad_medida)
LEFT JOIN [dbo].[Checklist_Item_Opcion] o ON o.cio_checklist_plantilla_item = r.cer_checklist_plantilla_item AND o.cio_codigo = r.cer_valor_texto AND o.cio_habilitado = 1
WHERE   r.cer_checklist_ejecucion = @CEJ AND r.cer_habilitado = 1

/* 4 · fotos */
SELECT  av.avi_archivo AS ARCHIVO, r.cer_checklist_plantilla_item AS ITEM, av.avi_titulo AS TITULO
FROM    [dbo].[Archivo_Vinculo] av
JOIN    [dbo].[Checklist_Ejecucion_Respuesta] r ON r.cer_id = av.avi_checklist_ejecucion_respuesta
WHERE   r.cer_checklist_ejecucion = @CEJ AND av.avi_habilitado = 1

/* 5 · datos de la ejecución */
SELECT  DATEADD(MINUTE, @MIN, e.cej_fecha_inicio_utc) AS INICIO, DATEADD(MINUTE, @MIN, e.cej_fecha_fin_utc) AS FIN, e.cej_duracion_minuto AS DURACION,
        e.cej_dispositivo AS DISPOSITIVO, CAST(ISNULL(e.cej_offline_creado, 0) AS BIT) AS SIN_SENAL, e.cej_latitud AS LAT, e.cej_longitud AS LNG,
        e.cej_observacion AS OBSERVACION, e.cej_item_total AS TOTAL, e.cej_item_respondido AS RESPONDIDOS, e.cej_item_no_conforme AS NO_CONFORMES,
        ee.cee_nombre AS ESTADO
FROM    [dbo].[Checklist_Ejecucion] e
JOIN    [dbo].[Checklist_Ejecucion_Estado] ee ON ee.cee_id = e.cej_checklist_ejecucion_estado
WHERE   e.cej_id = @CEJ
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_OPERACION_TAREA]
    @CLIENTE    INT,
    @OCURRENCIA INT
AS
SET NOCOUNT ON
DECLARE @MIN INT = DATEDIFF(MINUTE, GETUTCDATE(), [dbo].[FNC_AHORA]())
SELECT  o.toc_id AS OCURRENCIA, t.tar_codigo AS CODIGO, t.tar_titulo AS NOMBRE, t.tar_descripcion AS DESCRIPCION,
        o.toc_fecha_programada_utc AS FECHA, o.toc_fecha_limite_utc AS LIMITE, o.toc_tarea_ocurrencia_estado AS ESTADO_ID, oe.toe_nombre AS ESTADO,
        a.act_codigo AS ACTIVO_CODIGO, a.act_nombre AS ACTIVO, o.toc_observacion AS OBSERVACION, o.toc_orden_trabajo AS OT_ID,
        STUFF((SELECT N', ' + LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N'')))
               FROM [dbo].[Tarea_Ocurrencia_Asignacion] x JOIN [dbo].[Usuario] u ON u.usu_id = x.toa_usuario
               WHERE x.toa_tarea_ocurrencia = o.toc_id FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'') AS ASIGNADOS
FROM    [dbo].[Tarea_Ocurrencia] o
JOIN    [dbo].[Tarea] t ON t.tar_id = o.toc_tarea
JOIN    [dbo].[Tarea_Ocurrencia_Estado] oe ON oe.toe_id = o.toc_tarea_ocurrencia_estado
LEFT JOIN [dbo].[Activo] a ON a.act_id = t.tar_activo
WHERE   o.toc_id = @OCURRENCIA AND o.toc_cliente = @CLIENTE AND o.toc_habilitado = 1

SELECT  e.tej_id AS ID, LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS QUIEN,
        DATEADD(MINUTE, @MIN, e.tej_fecha_inicio_utc) AS INICIO, DATEADD(MINUTE, @MIN, e.tej_fecha_fin_utc) AS FIN, e.tej_duracion_minuto AS DURACION,
        e.tej_resultado AS RESULTADO, e.tej_conforme AS CONFORME, e.tej_dispositivo AS DISPOSITIVO, CAST(ISNULL(e.tej_offline_creado, 0) AS BIT) AS SIN_SENAL,
        e.tej_latitud AS LAT, e.tej_longitud AS LNG
FROM    [dbo].[Tarea_Ejecucion] e
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = e.tej_usuario_ejecutor
WHERE   e.tej_tarea_ocurrencia = @OCURRENCIA AND e.tej_habilitado = 1
ORDER BY e.tej_fecha_inicio_utc DESC

SELECT  av.avi_archivo AS ARCHIVO, av.avi_tarea_ejecucion AS EJECUCION, av.avi_titulo AS TITULO
FROM    [dbo].[Archivo_Vinculo] av
JOIN    [dbo].[Tarea_Ejecucion] e ON e.tej_id = av.avi_tarea_ejecucion
WHERE   e.tej_tarea_ocurrencia = @OCURRENCIA AND av.avi_habilitado = 1
RETURN 0
GO
PRINT '425_EJECUCION_DETALLE_APP aplicado.'
GO
