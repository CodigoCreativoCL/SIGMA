SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ============================================================================
   405 · Planificación › Inspecciones y Tareas · 09-10-2026  (parte e)
   Las listas de las pestañas «Inspecciones» y «Tareas» del Centro de Planificación (mockup):
     SEL_PLAN_INSPECCIONES  una fila por programación de inspección: pauta, dónde, frecuencia,
                            responsable, próxima y cumplimiento de los últimos 30 días.
     SEL_PLAN_TAREAS        una fila por tarea recurrente: categoría, dónde, frecuencia, etc.
   Fechas en hora de la planta (FNC_AHORA). Aplicar con -I. Idempotente.
   ============================================================================ */
SET NOCOUNT ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_INSPECCIONES]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @D30 DATETIME = DATEADD(DAY, -30, @AHORA)

SELECT  p.cpr_id AS ID,
        p.cpr_nombre AS NOMBRE,
        N'INS-' + RIGHT(N'000' + CAST(p.cpr_id AS NVARCHAR(10)), 3) AS CODIGO,
        cin.cin_nombre AS PLANTA,
        pl.cpl_codigo + N' v' + CAST(ISNULL(v.cpv_numero, 1) AS NVARCHAR(5)) AS PAUTA,
        pl.cpl_nombre AS PAUTA_NOMBRE,
        (SELECT COUNT(*) FROM [dbo].[Checklist_Plantilla_Item] i WHERE i.cpi_checklist_plantilla_version = v.cpv_id AND i.cpi_habilitado = 1) AS ITEMS,
        ISNULL(a.act_nombre, ISNULL(iar.iar_nombre, N'Sin ubicación')) AS DONDE,
        ISNULL(a.act_codigo, N'') AS DONDE_CODIGO,
        ISNULL(pt.pti_nombre, N'Sin frecuencia') AS FRECUENCIA,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE,
        px.fecha AS PROXIMA,
        ISNULL(h.hechas, 0) AS HECHAS, ISNULL(h.total, 0) AS TOTAL
FROM    [dbo].[Checklist_Programacion] p
JOIN    [dbo].[Checklist_Plantilla_Version] v ON v.cpv_id = p.cpr_checklist_plantilla_version
JOIN    [dbo].[Checklist_Plantilla] pl ON pl.cpl_id = v.cpv_checklist_plantilla
LEFT JOIN [dbo].[Activo] a ON a.act_id = p.cpr_activo
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = p.cpr_instalacion_area
LEFT JOIN [dbo].[Programacion] g ON g.pro_id = p.cpr_programacion
LEFT JOIN [dbo].[Programacion_Tipo] pt ON pt.pti_id = g.pro_programacion_tipo
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = ISNULL(g.pro_cliente_instalacion, ISNULL(a.act_cliente_instalacion, iar.iar_cliente_instalacion))
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = p.cpr_usuario_responsable
OUTER APPLY (SELECT TOP 1 c.coc_fecha_programada_utc AS fecha FROM [dbo].[Checklist_Ocurrencia] c
              WHERE c.coc_checklist_programacion = p.cpr_id AND c.coc_habilitado = 1 AND c.coc_checklist_ocurrencia_estado IN (1, 2, 3) AND c.coc_fecha_programada_utc >= CAST(@AHORA AS DATE)
              ORDER BY c.coc_fecha_programada_utc) px
OUTER APPLY (SELECT SUM(CASE WHEN c.coc_checklist_ocurrencia_estado = 4 THEN 1 ELSE 0 END) AS hechas, COUNT(*) AS total FROM [dbo].[Checklist_Ocurrencia] c
              WHERE c.coc_checklist_programacion = p.cpr_id AND c.coc_habilitado = 1 AND c.coc_checklist_ocurrencia_estado NOT IN (6, 7)
                AND c.coc_fecha_programada_utc >= @D30 AND c.coc_fecha_programada_utc < @AHORA) h
WHERE   p.cpr_cliente = @CLIENTE AND p.cpr_habilitado = 1
  AND   (@INSTALACION IS NULL OR cin.cin_id = @INSTALACION)
ORDER BY p.cpr_nombre
RETURN 0
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_TAREAS]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @D30 DATETIME = DATEADD(DAY, -30, @AHORA)

SELECT  t.tar_id AS ID, t.tar_codigo AS CODIGO, t.tar_titulo AS NOMBRE,
        ISNULL(c.tca_nombre, N'Sin categoría') AS CATEGORIA, ISNULL(c.tca_color, N'#68738A') AS COLOR,
        cin.cin_nombre AS PLANTA,
        ISNULL(a.act_nombre, ISNULL(iar.iar_nombre, N'Sin ubicación')) AS DONDE,
        ISNULL(a.act_codigo, N'') AS DONDE_CODIGO,
        ISNULL((SELECT TOP 1 pt.pti_nombre FROM [dbo].[Tarea_Programacion] tp JOIN [dbo].[Programacion] g ON g.pro_id = tp.tpr_programacion JOIN [dbo].[Programacion_Tipo] pt ON pt.pti_id = g.pro_programacion_tipo
                 WHERE tp.tpr_tarea = t.tar_id AND tp.tpr_habilitado = 1 ORDER BY tp.tpr_id), N'Sin frecuencia') AS FRECUENCIA,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE,
        px.fecha AS PROXIMA,
        ISNULL(h.hechas, 0) AS HECHAS, ISNULL(h.total, 0) AS TOTAL,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] o JOIN [dbo].[Tarea_Ocurrencia] x ON x.toc_id = o.otr_tarea_ocurrencia WHERE x.toc_tarea = t.tar_id AND o.otr_habilitado = 1) AS ESCALADAS
FROM    [dbo].[Tarea] t
LEFT JOIN [dbo].[Tarea_Categoria] c ON c.tca_id = t.tar_tarea_categoria
LEFT JOIN [dbo].[Activo] a ON a.act_id = t.tar_activo
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = t.tar_instalacion_area
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = ISNULL(t.tar_cliente_instalacion, ISNULL(a.act_cliente_instalacion, iar.iar_cliente_instalacion))
OUTER APPLY (SELECT TOP 1 tp.tpr_usuario_responsable AS usu FROM [dbo].[Tarea_Programacion] tp WHERE tp.tpr_tarea = t.tar_id AND tp.tpr_habilitado = 1 ORDER BY tp.tpr_id) r
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = r.usu
OUTER APPLY (SELECT TOP 1 o.toc_fecha_programada_utc AS fecha FROM [dbo].[Tarea_Ocurrencia] o
              WHERE o.toc_tarea = t.tar_id AND o.toc_habilitado = 1 AND o.toc_tarea_ocurrencia_estado IN (1, 2, 3) AND o.toc_fecha_programada_utc >= CAST(@AHORA AS DATE)
              ORDER BY o.toc_fecha_programada_utc) px
OUTER APPLY (SELECT SUM(CASE WHEN o.toc_tarea_ocurrencia_estado = 4 THEN 1 ELSE 0 END) AS hechas, COUNT(*) AS total FROM [dbo].[Tarea_Ocurrencia] o
              WHERE o.toc_tarea = t.tar_id AND o.toc_habilitado = 1 AND o.toc_tarea_ocurrencia_estado NOT IN (6, 7)
                AND o.toc_fecha_programada_utc >= @D30 AND o.toc_fecha_programada_utc < @AHORA) h
WHERE   t.tar_cliente = @CLIENTE AND t.tar_habilitado = 1
  AND   (@INSTALACION IS NULL OR cin.cin_id = @INSTALACION)
ORDER BY t.tar_titulo
RETURN 0
GO
PRINT '405_PLAN_INSPECCIONES_TAREAS aplicado.'
GO
