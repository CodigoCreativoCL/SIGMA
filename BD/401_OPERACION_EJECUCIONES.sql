SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ============================================================================
   401 · Operación › Ejecuciones (lista única) · 09-10-2026  (parte d)

   SEL_OPERACION_EJECUCIONES une lo programado de los tres tipos de trabajo:
     PLAN ........ Plan_Mantenimiento_Ocurrencia   (acción: Generar OT)
     INSPECCION .. Checklist_Ocurrencia            (acción: Registrar)
     TAREA ....... Tarea_Ocurrencia                (acción: Hecha, con Deshacer)
   Filtros opcionales: planta, área, responsable, criticidad del activo; rango de fechas.
   Las fechas están en HORA DE LA PLANTA (FNC_AHORA).
   SITUACION: CERRADA (hecha, omitida o con OT cerrada) · CANCELADA · ENCURSO (con OT en
   ejecución o completada, o en curso) · VENCIDA (pasó el límite) · ATRASADA (pasó la fecha) ·
   DISPONIBLE (ya se puede ejecutar) · FUTURA.

   UPD_OPERACION_TAREA_HECHA marca una tarea como hecha (o la deja pendiente: el «Deshacer»).
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET NOCOUNT ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_OPERACION_EJECUCIONES]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @AREA        INT = NULL,
    @RESPONSABLE INT = NULL,
    @CRITICIDAD  INT = NULL,
    @DESDE       DATE = NULL,
    @HASTA       DATE = NULL
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
IF @DESDE IS NULL SET @DESDE = DATEADD(DAY, -60, CAST(@AHORA AS DATE))
IF @HASTA IS NULL SET @HASTA = DATEADD(DAY, 60, CAST(@AHORA AS DATE))
DECLARE @D DATETIME = CAST(@DESDE AS DATETIME), @H DATETIME = DATEADD(DAY, 1, CAST(@HASTA AS DATETIME))

CREATE TABLE #E (TIPO VARCHAR(10), ID INT, FECHA DATETIME, LIMITE DATETIME, DISPONIBLE DATETIME, ESTADO_ID INT, ACTIVO_ID INT, TITULO NVARCHAR(300), REF NVARCHAR(60), REF_NOMBRE NVARCHAR(300),
                 ACTIVIDADES INT, PARADA BIT, OT_ID INT, OT_NUMERO INT, OT_ESTADO INT, RESP_ID INT, HALLAZGOS INT)

INSERT INTO #E
SELECT 'PLAN', o.pmo_id, o.pmo_fecha_programada_utc, o.pmo_fecha_limite_utc, o.pmo_fecha_disponible_utc, o.pmo_plan_ocurrencia_estado, o.pmo_activo,
       h.pmh_nombre, pma.pma_codigo, pma.pma_nombre,
       (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Actividad] x WHERE x.paa_plan_mantenimiento_hito = h.pmh_id AND x.paa_habilitado = 1),
       ISNULL(h.pmh_requiere_parada, 0), o.pmo_orden_trabajo, ot.otr_correlativo, ot.otr_orden_trabajo_estado, h.pmh_usuario_responsable, 0
FROM   [dbo].[Plan_Mantenimiento_Ocurrencia] o
JOIN   [dbo].[Plan_Mantenimiento_Hito] h ON h.pmh_id = o.pmo_plan_mantenimiento_hito
JOIN   [dbo].[Plan_Mantenimiento_Version] v ON v.pmv_id = h.pmh_plan_mantenimiento_version
JOIN   [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = v.pmv_plan_mantenimiento
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = o.pmo_orden_trabajo
WHERE  o.pmo_cliente = @CLIENTE AND o.pmo_habilitado = 1 AND o.pmo_plan_ocurrencia_estado <> 7
  AND  o.pmo_fecha_programada_utc >= @D AND o.pmo_fecha_programada_utc < @H

INSERT INTO #E
SELECT 'INSPECCION', c.coc_id, c.coc_fecha_programada_utc, c.coc_fecha_limite_utc, c.coc_fecha_disponible_utc, c.coc_checklist_ocurrencia_estado, c.coc_activo,
       ISNULL(p.cpr_nombre, N'Inspección'), N'', N'', 0, 0, NULL, NULL, NULL, p.cpr_usuario_responsable,
       (SELECT COUNT(*) FROM [dbo].[Checklist_Hallazgo] hz JOIN [dbo].[Checklist_Ejecucion] ej ON ej.cej_id = hz.cha_checklist_ejecucion WHERE ej.cej_checklist_ocurrencia = c.coc_id AND hz.cha_habilitado = 1)
FROM   [dbo].[Checklist_Ocurrencia] c
LEFT JOIN [dbo].[Checklist_Programacion] p ON p.cpr_id = c.coc_checklist_programacion
WHERE  c.coc_cliente = @CLIENTE AND c.coc_habilitado = 1 AND c.coc_checklist_ocurrencia_estado <> 7
  AND  c.coc_fecha_programada_utc >= @D AND c.coc_fecha_programada_utc < @H

INSERT INTO #E
SELECT 'TAREA', t.toc_id, t.toc_fecha_programada_utc, t.toc_fecha_limite_utc, t.toc_fecha_disponible_utc, t.toc_tarea_ocurrencia_estado, tr.tar_activo,
       tr.tar_titulo, tr.tar_codigo, tr.tar_titulo, 0, 0, t.toc_orden_trabajo, ot.otr_correlativo, ot.otr_orden_trabajo_estado, NULL, 0
FROM   [dbo].[Tarea_Ocurrencia] t
JOIN   [dbo].[Tarea] tr ON tr.tar_id = t.toc_tarea
LEFT JOIN [dbo].[Orden_Trabajo] ot ON ot.otr_id = t.toc_orden_trabajo
WHERE  t.toc_cliente = @CLIENTE AND t.toc_habilitado = 1 AND t.toc_tarea_ocurrencia_estado <> 7
  AND  t.toc_fecha_programada_utc >= @D AND t.toc_fecha_programada_utc < @H

IF @RESPONSABLE IS NOT NULL DELETE FROM #E WHERE ISNULL(RESP_ID, 0) <> @RESPONSABLE

SELECT  e.TIPO, e.ID, e.FECHA, e.LIMITE, e.ESTADO_ID,
        CASE WHEN e.ESTADO_ID IN (4, 5) OR e.OT_ESTADO = 4 THEN 'CERRADA'
             WHEN e.ESTADO_ID = 6 THEN 'CANCELADA'
             WHEN e.OT_ESTADO IN (2, 3) OR e.ESTADO_ID = 3 THEN 'ENCURSO'
             WHEN e.LIMITE IS NOT NULL AND e.LIMITE < @AHORA THEN 'VENCIDA'
             WHEN e.FECHA < @AHORA THEN 'ATRASADA'
             WHEN e.DISPONIBLE IS NOT NULL AND e.DISPONIBLE <= @AHORA THEN 'DISPONIBLE'
             ELSE 'FUTURA' END AS SITUACION,
        a.act_id AS ACTIVO_ID, a.act_codigo AS ACTIVO_CODIGO, a.act_nombre AS ACTIVO, iar.iar_nombre AS AREA, ISNULL(a.act_criticidad_nivel, 1) AS CRITICIDAD,
        e.TITULO, e.REF, e.REF_NOMBRE, e.ACTIVIDADES, e.PARADA, e.OT_ID, e.OT_NUMERO, e.OT_ESTADO, e.HALLAZGOS,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS RESPONSABLE
FROM    #E e
JOIN    [dbo].[Activo] a ON a.act_id = e.ACTIVO_ID AND a.act_cliente = @CLIENTE AND a.act_habilitado = 1
LEFT JOIN [dbo].[Instalacion_Area] iar ON iar.iar_id = a.act_instalacion_area
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = e.RESP_ID
WHERE   (@INSTALACION IS NULL OR a.act_cliente_instalacion = @INSTALACION)
  AND   (@AREA IS NULL OR a.act_instalacion_area = @AREA)
  AND   (@CRITICIDAD IS NULL OR ISNULL(a.act_criticidad_nivel, 1) = @CRITICIDAD)
ORDER BY e.FECHA, a.act_codigo
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_OPERACION_TAREA_HECHA]
    @CLIENTE INT,
    @ID      INT,
    @HECHA   BIT,
    @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @ESTADO INT, @OT INT
SELECT @ESTADO = toc_tarea_ocurrencia_estado, @OT = toc_orden_trabajo FROM [dbo].[Tarea_Ocurrencia] WHERE toc_id = @ID AND toc_cliente = @CLIENTE AND toc_habilitado = 1
IF @ESTADO IS NULL
BEGIN
    RAISERROR('1.- LA TAREA NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF @ESTADO IN (6, 7)
BEGIN
    RAISERROR('2.- LA TAREA ESTÁ CANCELADA O REPROGRAMADA.', 16, 1)
    RETURN -1
END
IF @HECHA = 1 AND @ESTADO = 4 RETURN 0
UPDATE [dbo].[Tarea_Ocurrencia]
SET    toc_tarea_ocurrencia_estado = CASE WHEN @HECHA = 1 THEN 4 ELSE 1 END,
       toc_usuario_actualizacion = @USUARIO, toc_fecha_actualizacion = [dbo].[FNC_AHORA]()
WHERE  toc_id = @ID
RETURN 0
GO
PRINT '401_OPERACION_EJECUCIONES aplicado.'
GO
