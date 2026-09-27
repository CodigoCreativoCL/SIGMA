USE [db_acd593_sigma]
GO
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
GO
-- Planificación 360, entrega de Diseño: las columnas que los mockups piden
-- y que las consultas de 297 no traían. Solo lectura; nada nuevo se guarda.

-- Actividad reciente: la OT se abre por su id y muestra su estado.
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLANIFICACION_ACTIVIDAD]
    @CLIENTE INT, @INSTALACION INT=NULL, @DESDE DATETIME, @TOP INT=5
AS
BEGIN
    SET NOCOUNT ON
    SELECT TOP (@TOP) o.otr_id AS ORDEN_ID, o.otr_correlativo AS ORDEN_CORRELATIVO,
           a.act_codigo AS ACTIVO_CODIGO, a.act_nombre AS ACTIVO_NOMBRE, h.pmh_nombre AS HITO_NOMBRE,
           o.otr_fecha_creacion AS FECHA, e.ote_codigo AS ESTADO_CODIGO, e.ote_nombre AS ESTADO_NOMBRE
      FROM Orden_Trabajo o
      JOIN Plan_Mantenimiento_Ocurrencia po ON po.pmo_id=o.otr_plan_mantenimiento_ocurrencia
      JOIN Plan_Mantenimiento_Hito h ON h.pmh_id=po.pmo_plan_mantenimiento_hito
      JOIN Activo a ON a.act_id=po.pmo_activo
      LEFT JOIN Orden_Trabajo_Estado e ON e.ote_id=o.otr_orden_trabajo_estado
     WHERE o.otr_cliente=@CLIENTE AND o.otr_habilitado=1 AND o.otr_fecha_creacion>=@DESDE
       AND (@INSTALACION IS NULL OR a.act_cliente_instalacion=@INSTALACION)
     ORDER BY o.otr_fecha_creacion DESC,o.otr_id DESC
END
GO

-- Dónde se usa: con el id del consumidor, para poder enlazarlo.
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLANIFICACION_PROGRAMACION_USO]
    @CLIENTE INT
AS
BEGIN
    SET NOCOUNT ON
    SELECT DISTINCT h.pmh_programacion AS PROGRAMACION_ID, 'Plan' AS ORIGEN, p.pma_id AS ID,
           p.pma_codigo AS CODIGO, p.pma_nombre AS NOMBRE
      FROM Plan_Mantenimiento_Hito h
      JOIN Plan_Mantenimiento_Version v ON v.pmv_id=h.pmh_plan_mantenimiento_version AND v.pmv_habilitado=1
      JOIN Plan_Mantenimiento p ON p.pma_id=v.pmv_plan_mantenimiento AND p.pma_cliente=@CLIENTE AND p.pma_habilitado=1
     WHERE h.pmh_habilitado=1
    UNION ALL
    SELECT tp.tpr_programacion, 'Tarea', t.tar_id, t.tar_codigo, t.tar_titulo
      FROM Tarea_Programacion tp JOIN Tarea t ON t.tar_id=tp.tpr_tarea
     WHERE t.tar_cliente=@CLIENTE AND t.tar_habilitado=1 AND tp.tpr_habilitado=1
    UNION ALL
    SELECT cp.cpr_programacion, 'Pauta', cp.cpr_id, '', cp.cpr_nombre
      FROM Checklist_Programacion cp
     WHERE cp.cpr_cliente=@CLIENTE AND cp.cpr_habilitado=1
    ORDER BY PROGRAMACION_ID, ORIGEN, CODIGO
END
GO

-- Cobertura: una fila por equipo habilitado con cuántos planes PUBLICADOS lo
-- cubren. Filtra en servidor por tipo, área y criticidad; @VISTA elige
-- 'SIN' (ningún plan) o 'VARIOS' (dos o más).
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLANIFICACION_COBERTURA]
    @CLIENTE INT,
    @INSTALACION INT = NULL,
    @DUPLICADOS BIT = 0,
    @TIPO INT = NULL,
    @AREA INT = NULL,
    @CRITICIDAD INT = NULL
AS
BEGIN
    SET NOCOUNT ON
    ;WITH planes AS (
        SELECT pa.pac_activo, p.pma_id, p.pma_codigo, p.pma_nombre
          FROM Plan_Mantenimiento_Activo pa
          JOIN Plan_Mantenimiento_Version v ON v.pmv_id=pa.pac_plan_mantenimiento_version
                                           AND v.pmv_plan_version_estado=2 AND v.pmv_habilitado=1
          JOIN Plan_Mantenimiento p ON p.pma_id=v.pmv_plan_mantenimiento
                                   AND p.pma_cliente=@CLIENTE AND p.pma_habilitado=1
         GROUP BY pa.pac_activo, p.pma_id, p.pma_codigo, p.pma_nombre
    ), cobertura AS (
        SELECT a.act_id, a.act_codigo, a.act_nombre, atp.ati_id, atp.ati_nombre, ci.cin_nombre,
               ar.iar_id, ar.iar_nombre, cr.crn_id, cr.crn_codigo, cr.crn_nombre,
               (SELECT COUNT(*) FROM planes x WHERE x.pac_activo=a.act_id) AS PLANES,
               STUFF((SELECT N'; ' + x.pma_codigo + N' · ' + x.pma_nombre FROM planes x
                       WHERE x.pac_activo=a.act_id ORDER BY x.pma_codigo
                         FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,2,N'') AS PLANES_NOMBRES
          FROM Activo a
          LEFT JOIN Activo_Tipo atp ON atp.ati_id=a.act_activo_tipo
          LEFT JOIN Cliente_Instalacion ci ON ci.cin_id=a.act_cliente_instalacion
          LEFT JOIN Instalacion_Area ar ON ar.iar_id=a.act_instalacion_area
          LEFT JOIN Criticidad_Nivel cr ON cr.crn_id=a.act_criticidad_nivel
         WHERE a.act_cliente=@CLIENTE AND a.act_habilitado=1
           AND (@INSTALACION IS NULL OR a.act_cliente_instalacion=@INSTALACION)
           AND (@TIPO IS NULL OR a.act_activo_tipo=@TIPO)
           AND (@AREA IS NULL OR a.act_instalacion_area=@AREA)
           AND (@CRITICIDAD IS NULL OR a.act_criticidad_nivel=@CRITICIDAD)
    )
    SELECT act_id AS ACTIVO_ID, act_codigo AS ACTIVO_CODIGO, act_nombre AS ACTIVO_NOMBRE,
           ati_id AS TIPO_ID, ati_nombre AS TIPO_NOMBRE, cin_nombre AS PLANTA_NOMBRE,
           iar_id AS AREA_ID, iar_nombre AS AREA_NOMBRE,
           crn_id AS CRITICIDAD_ID, crn_codigo AS CRITICIDAD_CODIGO, crn_nombre AS CRITICIDAD_NOMBRE,
           PLANES, ISNULL(PLANES_NOMBRES,'') AS PLANES_NOMBRES
      FROM cobertura
     WHERE (@DUPLICADOS=0 AND PLANES=0) OR (@DUPLICADOS=1 AND PLANES>=2)
     ORDER BY ISNULL(crn_id,0) DESC, cin_nombre, act_codigo
END
GO

-- Los cuatro números de la cabecera de Cobertura. "En varios planes" es un
-- subconjunto de los cubiertos: no se suma.
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLANIFICACION_COBERTURA_RESUMEN]
    @CLIENTE INT,
    @INSTALACION INT = NULL
AS
BEGIN
    SET NOCOUNT ON
    ;WITH conteo AS (
        SELECT a.act_id,
               (SELECT COUNT(DISTINCT p.pma_id)
                  FROM Plan_Mantenimiento_Activo pa
                  JOIN Plan_Mantenimiento_Version v ON v.pmv_id=pa.pac_plan_mantenimiento_version
                                                   AND v.pmv_plan_version_estado=2 AND v.pmv_habilitado=1
                  JOIN Plan_Mantenimiento p ON p.pma_id=v.pmv_plan_mantenimiento
                                           AND p.pma_cliente=@CLIENTE AND p.pma_habilitado=1
                 WHERE pa.pac_activo=a.act_id) AS PLANES
          FROM Activo a
         WHERE a.act_cliente=@CLIENTE AND a.act_habilitado=1
           AND (@INSTALACION IS NULL OR a.act_cliente_instalacion=@INSTALACION)
    )
    SELECT COUNT(*) AS HABILITADOS,
           SUM(CASE WHEN PLANES>0 THEN 1 ELSE 0 END) AS CUBIERTOS,
           SUM(CASE WHEN PLANES=0 THEN 1 ELSE 0 END) AS SIN_PLAN,
           SUM(CASE WHEN PLANES>1 THEN 1 ELSE 0 END) AS VARIOS
      FROM conteo
END
GO

-- Cumplimiento por equipo: se agregan atrasadas y omitidas para que el
-- desglose salga del mismo cálculo y no de leer todas las ocurrencias.
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
           SUM(CASE WHEN ESTADO NOT IN (4,5) AND ISNULL(LIMITE,PROGRAMADA)<@HOY THEN 1 ELSE 0 END) AS VENCIDAS,
           SUM(CASE WHEN ESTADO NOT IN (4,5) AND PROGRAMADA<@HOY AND ISNULL(LIMITE,PROGRAMADA)>=@HOY THEN 1 ELSE 0 END) AS ATRASADAS,
           SUM(CASE WHEN ESTADO=5 THEN 1 ELSE 0 END) AS OMITIDAS,
           SUM(REPROGRAMADA) AS REPROGRAMADAS,
           CAST(100.0*SUM(CASE WHEN ESTADO=4 AND CUMPLIDA_EN<=DATEADD(DAY,TOLERANCIA,ORIGINAL) THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS DECIMAL(5,1)) AS CUMPLIMIENTO
      FROM base GROUP BY act_id,act_codigo,act_nombre,cin_nombre
     ORDER BY CUMPLIMIENTO,cin_nombre,act_codigo
END
GO

PRINT '298_PLANIFICACION_360_DISENO aplicado.'
GO
