USE [db_acd593_sigma]
GO
SET NOCOUNT ON
GO
-- Planificación 360: consultas de lectura que no existían en las pantallas
-- anteriores. Todas se acotan al cliente de la sesión desde el Controller.

-- El centro exige VER PLANES MANTENIMIENTO. Quien solo tiene VER
-- PROGRAMACIONES conserva la entrada directa que ya tenía; el endpoint de
-- esa pestaña vuelve a validar el permiso 92.
UPDATE Menus SET mnu_visible=1 WHERE mnu_id=2155
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLANIFICACION_ACTIVIDAD]
    @CLIENTE INT, @INSTALACION INT=NULL, @DESDE DATETIME, @TOP INT=5
AS
BEGIN
    SET NOCOUNT ON
    SELECT TOP (@TOP) o.otr_correlativo AS ORDEN_CORRELATIVO,a.act_codigo AS ACTIVO_CODIGO,
           a.act_nombre AS ACTIVO_NOMBRE,h.pmh_nombre AS HITO_NOMBRE,o.otr_fecha_creacion AS FECHA
      FROM Orden_Trabajo o
      JOIN Plan_Mantenimiento_Ocurrencia po ON po.pmo_id=o.otr_plan_mantenimiento_ocurrencia
      JOIN Plan_Mantenimiento_Hito h ON h.pmh_id=po.pmo_plan_mantenimiento_hito
      JOIN Activo a ON a.act_id=po.pmo_activo
     WHERE o.otr_cliente=@CLIENTE AND o.otr_habilitado=1 AND o.otr_fecha_creacion>=@DESDE
       AND (@INSTALACION IS NULL OR a.act_cliente_instalacion=@INSTALACION)
     ORDER BY o.otr_fecha_creacion DESC,o.otr_id DESC
END
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLANIFICACION_PROGRAMACION_USO]
    @CLIENTE INT
AS
BEGIN
    SET NOCOUNT ON
    SELECT DISTINCT h.pmh_programacion AS PROGRAMACION_ID, 'Plan' AS ORIGEN,
           p.pma_codigo AS CODIGO, p.pma_nombre AS NOMBRE
      FROM Plan_Mantenimiento_Hito h
      JOIN Plan_Mantenimiento_Version v ON v.pmv_id=h.pmh_plan_mantenimiento_version AND v.pmv_habilitado=1
      JOIN Plan_Mantenimiento p ON p.pma_id=v.pmv_plan_mantenimiento AND p.pma_cliente=@CLIENTE AND p.pma_habilitado=1
     WHERE h.pmh_habilitado=1
    UNION ALL
    SELECT tp.tpr_programacion, 'Tarea', t.tar_codigo, t.tar_titulo
      FROM Tarea_Programacion tp JOIN Tarea t ON t.tar_id=tp.tpr_tarea
     WHERE t.tar_cliente=@CLIENTE AND t.tar_habilitado=1 AND tp.tpr_habilitado=1
    UNION ALL
    SELECT cp.cpr_programacion, 'Pauta', '', cp.cpr_nombre
      FROM Checklist_Programacion cp
     WHERE cp.cpr_cliente=@CLIENTE AND cp.cpr_habilitado=1
    ORDER BY PROGRAMACION_ID, ORIGEN, CODIGO
END
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLANIFICACION_COBERTURA]
    @CLIENTE INT,
    @INSTALACION INT = NULL,
    @DUPLICADOS BIT = 0
AS
BEGIN
    SET NOCOUNT ON
    ;WITH cobertura AS (
        SELECT a.act_id, a.act_codigo, a.act_nombre, atp.ati_nombre, ci.cin_nombre,
               COUNT(DISTINCT p.pma_id) AS PLANES,
               STUFF((SELECT DISTINCT N'; ' + p2.pma_codigo + N' · ' + p2.pma_nombre
                        FROM Plan_Mantenimiento_Activo pa2
                        JOIN Plan_Mantenimiento_Version v2 ON v2.pmv_id=pa2.pac_plan_mantenimiento_version
                                                           AND v2.pmv_plan_version_estado=2 AND v2.pmv_habilitado=1
                        JOIN Plan_Mantenimiento p2 ON p2.pma_id=v2.pmv_plan_mantenimiento
                                                   AND p2.pma_cliente=@CLIENTE AND p2.pma_habilitado=1
                       WHERE pa2.pac_activo=a.act_id
                         FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,2,N'') AS PLANES_NOMBRES
          FROM Activo a
          LEFT JOIN Activo_Tipo atp ON atp.ati_id=a.act_activo_tipo
          LEFT JOIN Cliente_Instalacion ci ON ci.cin_id=a.act_cliente_instalacion
          LEFT JOIN Plan_Mantenimiento_Activo pa ON pa.pac_activo=a.act_id
          LEFT JOIN Plan_Mantenimiento_Version v ON v.pmv_id=pa.pac_plan_mantenimiento_version
                                                    AND v.pmv_plan_version_estado=2 AND v.pmv_habilitado=1
          LEFT JOIN Plan_Mantenimiento p ON p.pma_id=v.pmv_plan_mantenimiento
                                           AND p.pma_cliente=@CLIENTE AND p.pma_habilitado=1
         WHERE a.act_cliente=@CLIENTE AND a.act_habilitado=1
           AND (@INSTALACION IS NULL OR a.act_cliente_instalacion=@INSTALACION)
         GROUP BY a.act_id,a.act_codigo,a.act_nombre,atp.ati_nombre,ci.cin_nombre
    )
    SELECT act_id AS ACTIVO_ID, act_codigo AS ACTIVO_CODIGO, act_nombre AS ACTIVO_NOMBRE,
           ati_nombre AS TIPO_NOMBRE, cin_nombre AS PLANTA_NOMBRE, PLANES,
           ISNULL(PLANES_NOMBRES,'') AS PLANES_NOMBRES
      FROM cobertura
     WHERE (@DUPLICADOS=0 AND PLANES=0) OR (@DUPLICADOS=1 AND PLANES>=2)
     ORDER BY cin_nombre, act_codigo
END
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLANIFICACION_CUMPLIMIENTO_EQUIPO]
    @CLIENTE INT,
    @INSTALACION INT = NULL,
    @DESDE DATE,
    @HASTA DATE
AS
BEGIN
    SET NOCOUNT ON
    DECLARE @HOY DATETIME=GETUTCDATE()
    ;WITH base AS (
        SELECT a.act_id,a.act_codigo,a.act_nombre,ci.cin_nombre,
               o.pmo_plan_ocurrencia_estado AS ESTADO,
               ISNULL(o.pmo_fecha_programada_original_utc,o.pmo_fecha_programada_utc) AS ORIGINAL,
               o.pmo_fecha_programada_utc AS PROGRAMADA,o.pmo_fecha_limite_utc AS LIMITE,
               CASE WHEN o.pmo_ocurrencia_origen IS NULL THEN 0 ELSE 1 END AS REPROGRAMADA,
               COALESCE(ot.otr_fecha_fin_real_utc,ot.otr_fecha_cierre,o.pmo_fecha_actualizacion) AS CUMPLIDA_EN,
               CASE WHEN o.pmo_fecha_limite_utc IS NULL THEN 0 ELSE DATEDIFF(DAY,o.pmo_fecha_programada_utc,o.pmo_fecha_limite_utc) END AS TOLERANCIA
          FROM Plan_Mantenimiento_Ocurrencia o
          JOIN Activo a ON a.act_id=o.pmo_activo
          LEFT JOIN Cliente_Instalacion ci ON ci.cin_id=a.act_cliente_instalacion
          LEFT JOIN Orden_Trabajo ot ON ot.otr_id=o.pmo_orden_trabajo
         WHERE o.pmo_cliente=@CLIENTE AND o.pmo_habilitado=1
           AND o.pmo_plan_ocurrencia_estado NOT IN (6,7)
           AND (@INSTALACION IS NULL OR a.act_cliente_instalacion=@INSTALACION)
           AND ISNULL(o.pmo_fecha_programada_original_utc,o.pmo_fecha_programada_utc)>=CAST(@DESDE AS DATETIME)
           AND ISNULL(o.pmo_fecha_programada_original_utc,o.pmo_fecha_programada_utc)<DATEADD(DAY,1,CAST(@HASTA AS DATETIME))
    )
    SELECT act_id AS ACTIVO_ID,act_codigo AS ACTIVO_CODIGO,act_nombre AS ACTIVO_NOMBRE,cin_nombre AS PLANTA_NOMBRE,
           COUNT(*) AS PROGRAMADAS,SUM(CASE WHEN ESTADO=4 THEN 1 ELSE 0 END) AS CUMPLIDAS,
           SUM(CASE WHEN ESTADO=4 AND CUMPLIDA_EN<=DATEADD(DAY,TOLERANCIA,ORIGINAL) THEN 1 ELSE 0 END) AS A_TIEMPO,
           SUM(CASE WHEN ESTADO=4 AND CUMPLIDA_EN<=ISNULL(LIMITE,PROGRAMADA) THEN 1 ELSE 0 END) AS A_TIEMPO_VIGENTE,
           SUM(CASE WHEN ESTADO<>4 AND ISNULL(LIMITE,PROGRAMADA)<@HOY THEN 1 ELSE 0 END) AS VENCIDAS,
           SUM(REPROGRAMADA) AS REPROGRAMADAS,
           CAST(100.0*SUM(CASE WHEN ESTADO=4 AND CUMPLIDA_EN<=DATEADD(DAY,TOLERANCIA,ORIGINAL) THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS DECIMAL(5,1)) AS CUMPLIMIENTO
      FROM base GROUP BY act_id,act_codigo,act_nombre,cin_nombre
     ORDER BY CUMPLIMIENTO,cin_nombre,act_codigo
END
GO

PRINT '297_PLANIFICACION_360 aplicado.'
GO
