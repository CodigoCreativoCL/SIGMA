USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          CATALINA PESCIO
-- FECHA:           29-09-2026
-- DESCRIPTION:     SPRINT 4 (HU-097) SEL_CHECKLIST_HISTORIAL (T-4297) + índice (T-4298).
--
--   El historial de una pauta es por EJECUCIÓN, no por ocurrencia: incluye las
--   ejecuciones ad-hoc (sin programación) que SEL_CHECKLIST_OCURRENCIA no ve.
--   Lista las ejecuciones de una plantilla con fecha, ejecutor, activo, versión
--   y cantidad de no conformidades (CA-1). El detalle (CA-2) lo dan
--   SEL_CHECKLIST_EJECUCION_RESPUESTA y SEL_CHECKLIST_EJECUCION_ARCHIVO.
-- =============================================
GO

-- Índice de apoyo: la consulta filtra por cliente + versión de plantilla y
-- ordena por fecha; sin él la tabla se escanea cuando crece.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Checklist_Ejecucion_Cliente_Version'
              AND object_id = OBJECT_ID('dbo.Checklist_Ejecucion'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_Checklist_Ejecucion_Cliente_Version]
        ON [dbo].[Checklist_Ejecucion] (cej_cliente, cej_checklist_plantilla_version)
        INCLUDE (cej_activo, cej_usuario_ejecutor, cej_checklist_ejecucion_estado,
                 cej_fecha_inicio_utc, cej_fecha_fin_utc, cej_item_total,
                 cej_item_respondido, cej_item_no_conforme, cej_habilitado)
END
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_CHECKLIST_HISTORIAL]
@CLIENTE    INT,
@PLANTILLA  INT,
@ESTADO     INT = NULL,
@DESDE      DATE = NULL,
@HASTA      DATE = NULL
AS
SET NOCOUNT ON

SELECT  e.cej_id                              AS EJECUCION_ID,
        e.cej_checklist_plantilla_version     AS VERSION_ID,
        v.cpv_numero                          AS VERSION_NUMERO,
        v.cpv_checklist_plantilla             AS PLANTILLA_ID,
        p.cpl_nombre                          AS PLANTILLA_NOMBRE,
        e.cej_activo                          AS ACTIVO_ID,
        ISNULL(a.act_codigo, '')              AS ACTIVO_CODIGO,
        ISNULL(a.act_nombre, '')              AS ACTIVO_NOMBRE,
        e.cej_usuario_ejecutor                AS EJECUTOR_ID,
        LTRIM(RTRIM(ISNULL(u.usu_nombre,'') + ' ' + ISNULL(u.usu_apellido_paterno,''))) AS EJECUTOR_NOMBRE,
        e.cej_checklist_ejecucion_estado      AS ESTADO_ID,
        ee.cee_codigo                         AS ESTADO_CODIGO,
        ee.cee_nombre                         AS ESTADO_NOMBRE,
        e.cej_item_total                      AS ITEM_TOTAL,
        e.cej_item_respondido                 AS ITEM_RESPONDIDO,
        e.cej_item_no_conforme                AS ITEM_NO_CONFORME,
        e.cej_fecha_inicio_utc                AS EJECUCION_INICIO,
        e.cej_fecha_fin_utc                   AS EJECUCION_FIN,
        e.cej_duracion_minuto                 AS EJECUCION_MINUTOS,
        ISNULL(e.cej_observacion, '')         AS EJECUCION_OBSERVACION
FROM    [dbo].[Checklist_Ejecucion]          e
JOIN    [dbo].[Checklist_Plantilla_Version]  v  ON v.cpv_id = e.cej_checklist_plantilla_version
JOIN    [dbo].[Checklist_Plantilla]          p  ON p.cpl_id = v.cpv_checklist_plantilla
LEFT JOIN [dbo].[Activo]                     a  ON a.act_id = e.cej_activo
LEFT JOIN [dbo].[Usuario]                    u  ON u.usu_id = e.cej_usuario_ejecutor
LEFT JOIN [dbo].[Checklist_Ejecucion_Estado] ee ON ee.cee_id = e.cej_checklist_ejecucion_estado
WHERE   e.cej_cliente = @CLIENTE
  AND   e.cej_habilitado = 1
  AND   p.cpl_id = @PLANTILLA
  -- Sin filtro de estado se excluyen las anuladas (6); con filtro, ese estado.
  AND   ((@ESTADO IS NULL AND e.cej_checklist_ejecucion_estado <> 6) OR e.cej_checklist_ejecucion_estado = @ESTADO)
  AND   (@DESDE IS NULL OR ISNULL(e.cej_fecha_fin_utc, e.cej_fecha_inicio_utc) >= @DESDE)
  AND   (@HASTA IS NULL OR ISNULL(e.cej_fecha_fin_utc, e.cej_fecha_inicio_utc) < DATEADD(DAY, 1, @HASTA))
ORDER BY ISNULL(e.cej_fecha_fin_utc, ISNULL(e.cej_fecha_inicio_utc, e.cej_fecha_creacion)) DESC, e.cej_id DESC
GO

PRINT '306_SEL_CHECKLIST_HISTORIAL aplicado.'
GO
