/* ============================================================================
   428 · Lo ejecutado de una inspección o tarea, dentro de su cajón en Planificación (10-10-2026)
   El cliente: «Ver lo ejecutado» debe verse en el mismo drawer, no en otra pantalla.
     · SEL_PLAN_EJECUTADAS(@CLIENTE, @TIPO 'INS'|'TAR', @ID): las últimas 30 ocurrencias ya hechas,
       en curso u omitidas (las que tienen algo que mostrar), con activo, quién la hizo, cuándo,
       hallazgos (inspección) o conforme (tarea). El detalle sale de WsOperacion.Inspeccion/Tarea (BD/425, 427).
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_EJECUTADAS]
    @CLIENTE INT,
    @TIPO    VARCHAR(4),
    @ID      INT
AS
SET NOCOUNT ON
DECLARE @MIN INT = DATEDIFF(MINUTE, GETUTCDATE(), [dbo].[FNC_AHORA]())
IF @TIPO = 'INS'
    SELECT TOP 30 c.coc_id AS OCURRENCIA, c.coc_fecha_programada_utc AS FECHA, oe.coe_nombre AS ESTADO, c.coc_checklist_ocurrencia_estado AS ESTADO_ID,
           a.act_codigo AS ACTIVO_CODIGO, a.act_nombre AS ACTIVO,
           [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](e.cej_usuario_ejecutor) AS QUIEN, DATEADD(MINUTE, @MIN, e.cej_fecha_fin_utc) AS HECHA_EL, e.cej_dispositivo AS DISPOSITIVO,
           (SELECT COUNT(*) FROM [dbo].[Checklist_Hallazgo] h WHERE h.cha_checklist_ejecucion = e.cej_id AND h.cha_habilitado = 1) AS HALLAZGOS,
           (SELECT COUNT(*) FROM [dbo].[Archivo_Vinculo] av JOIN [dbo].[Checklist_Ejecucion_Respuesta] r ON r.cer_id = av.avi_checklist_ejecucion_respuesta WHERE r.cer_checklist_ejecucion = e.cej_id AND av.avi_habilitado = 1) AS FOTOS,
           CAST(NULL AS BIT) AS CONFORME
    FROM   [dbo].[Checklist_Ocurrencia] c
    JOIN   [dbo].[Checklist_Programacion] p ON p.cpr_id = c.coc_checklist_programacion
    JOIN   [dbo].[Checklist_Ocurrencia_Estado] oe ON oe.coe_id = c.coc_checklist_ocurrencia_estado
    LEFT JOIN [dbo].[Activo] a ON a.act_id = c.coc_activo
    OUTER APPLY (SELECT TOP 1 * FROM [dbo].[Checklist_Ejecucion] x WHERE x.cej_checklist_ocurrencia = c.coc_id AND x.cej_habilitado = 1 ORDER BY x.cej_id DESC) e
    WHERE  p.cpr_inspeccion = @ID AND c.coc_cliente = @CLIENTE AND c.coc_habilitado = 1 AND (c.coc_checklist_ocurrencia_estado IN (3, 4, 5) OR e.cej_id IS NOT NULL)
    ORDER BY c.coc_fecha_programada_utc DESC
ELSE
    SELECT TOP 30 o.toc_id AS OCURRENCIA, o.toc_fecha_programada_utc AS FECHA, oe.toe_nombre AS ESTADO, o.toc_tarea_ocurrencia_estado AS ESTADO_ID,
           a.act_codigo AS ACTIVO_CODIGO, a.act_nombre AS ACTIVO,
           [dbo].[FNC_NOMBRE_USUARIO_SIMPLE](e.tej_usuario_ejecutor) AS QUIEN, DATEADD(MINUTE, @MIN, e.tej_fecha_fin_utc) AS HECHA_EL, e.tej_dispositivo AS DISPOSITIVO,
           0 AS HALLAZGOS,
           (SELECT COUNT(*) FROM [dbo].[Archivo_Vinculo] av WHERE av.avi_tarea_ejecucion = e.tej_id AND av.avi_habilitado = 1) AS FOTOS,
           e.tej_conforme AS CONFORME
    FROM   [dbo].[Tarea_Ocurrencia] o
    JOIN   [dbo].[Tarea] t ON t.tar_id = o.toc_tarea
    JOIN   [dbo].[Tarea_Ocurrencia_Estado] oe ON oe.toe_id = o.toc_tarea_ocurrencia_estado
    LEFT JOIN [dbo].[Activo] a ON a.act_id = t.tar_activo
    OUTER APPLY (SELECT TOP 1 * FROM [dbo].[Tarea_Ejecucion] x WHERE x.tej_tarea_ocurrencia = o.toc_id AND x.tej_habilitado = 1 ORDER BY x.tej_id DESC) e
    WHERE  o.toc_tarea = @ID AND o.toc_cliente = @CLIENTE AND o.toc_habilitado = 1 AND (o.toc_tarea_ocurrencia_estado IN (3, 4, 5) OR e.tej_id IS NOT NULL)
    ORDER BY o.toc_fecha_programada_utc DESC
RETURN 0
GO
PRINT '428_PLAN_EJECUTADAS aplicado.'
GO
