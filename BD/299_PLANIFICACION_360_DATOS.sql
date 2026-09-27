USE [db_acd593_sigma]
GO
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
GO
-- Planificación 360: lo que exige cada hito (personas, repuestos, permiso)
-- y el detalle de los borradores, para llenar con datos reales las columnas
-- "Requerimientos" de la Bandeja y "Cambios / Última edición" del Resumen.

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLANIFICACION_HITO_REQUISITO]
    @CLIENTE INT
AS
BEGIN
    SET NOCOUNT ON
    SELECT h.pmh_id AS HITO_ID,
           ISNULL((SELECT SUM(e.pae_cantidad_persona)
                     FROM Plan_Actividad_Especialidad e
                     JOIN Plan_Mantenimiento_Actividad a ON a.paa_id=e.pae_plan_mantenimiento_actividad AND a.paa_habilitado=1
                    WHERE a.paa_plan_mantenimiento_hito=h.pmh_id),0) AS PERSONAS,
           ISNULL((SELECT COUNT(*)
                     FROM Plan_Actividad_Repuesto r
                     JOIN Plan_Mantenimiento_Actividad a ON a.paa_id=r.pra_plan_mantenimiento_actividad AND a.paa_habilitado=1
                    WHERE a.paa_plan_mantenimiento_hito=h.pmh_id),0) AS REPUESTOS,
           (SELECT TOP 1 rp.rep_nombre
              FROM Plan_Actividad_Repuesto r
              JOIN Plan_Mantenimiento_Actividad a ON a.paa_id=r.pra_plan_mantenimiento_actividad AND a.paa_habilitado=1
              JOIN Repuesto rp ON rp.rep_id=r.pra_repuesto
             WHERE a.paa_plan_mantenimiento_hito=h.pmh_id
             ORDER BY r.pra_obligatorio DESC, r.pra_id) AS REPUESTO_PRINCIPAL,
           CAST(CASE WHEN EXISTS(SELECT 1 FROM Plan_Mantenimiento_Actividad a
                                  WHERE a.paa_plan_mantenimiento_hito=h.pmh_id AND a.paa_habilitado=1 AND a.paa_requiere_permiso=1)
                     THEN 1 ELSE 0 END AS BIT) AS PERMISO
      FROM Plan_Mantenimiento_Hito h
      JOIN Plan_Mantenimiento_Version v ON v.pmv_id=h.pmh_plan_mantenimiento_version
      JOIN Plan_Mantenimiento p ON p.pma_id=v.pmv_plan_mantenimiento AND p.pma_cliente=@CLIENTE
     WHERE h.pmh_habilitado=1
END
GO

-- Borradores abiertos: cuándo se tocó por última vez y cuántos elementos
-- (hitos, actividades, equipos) se crearon o editaron después de abrirlo.
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLANIFICACION_BORRADOR]
    @CLIENTE INT,
    @INSTALACION INT = NULL
AS
BEGIN
    SET NOCOUNT ON
    ;WITH b AS (
        SELECT p.pma_id, p.pma_codigo, p.pma_nombre, t.ati_nombre, v.pmv_id, v.pmv_numero, v.pmv_fecha_creacion,
               ISNULL(v.pmv_usuario_actualizacion, v.pmv_usuario_creacion) AS USUARIO_VERSION,
               p.pma_usuario_planificador
          FROM Plan_Mantenimiento_Version v
          JOIN Plan_Mantenimiento p ON p.pma_id=v.pmv_plan_mantenimiento AND p.pma_cliente=@CLIENTE AND p.pma_habilitado=1
          LEFT JOIN Activo_Tipo t ON t.ati_id=p.pma_activo_tipo
         WHERE v.pmv_plan_version_estado=1 AND v.pmv_habilitado=1
           AND (@INSTALACION IS NULL OR p.pma_cliente_instalacion IS NULL OR p.pma_cliente_instalacion=@INSTALACION)
    ), cambios AS (
        SELECT b.pmv_id, x.FECHA, x.USUARIO
          FROM b
         CROSS APPLY (
            SELECT ISNULL(h.pmh_fecha_actualizacion,h.pmh_fecha_creacion) AS FECHA, ISNULL(h.pmh_usuario_actualizacion,h.pmh_usuario_creacion) AS USUARIO
              FROM Plan_Mantenimiento_Hito h WHERE h.pmh_plan_mantenimiento_version=b.pmv_id
            UNION ALL
            SELECT ISNULL(a.paa_fecha_actualizacion,a.paa_fecha_creacion), ISNULL(a.paa_usuario_actualizacion,a.paa_usuario_creacion)
              FROM Plan_Mantenimiento_Actividad a JOIN Plan_Mantenimiento_Hito h ON h.pmh_id=a.paa_plan_mantenimiento_hito
             WHERE h.pmh_plan_mantenimiento_version=b.pmv_id
            UNION ALL
            SELECT pa.pac_fecha_creacion, pa.pac_usuario_creacion
              FROM Plan_Mantenimiento_Activo pa WHERE pa.pac_plan_mantenimiento_version=b.pmv_id
         ) x
         WHERE x.FECHA > DATEADD(MINUTE,1,b.pmv_fecha_creacion)
    )
    SELECT b.pma_id AS PLAN_ID, b.pma_codigo AS CODIGO, b.pma_nombre AS NOMBRE, b.ati_nombre AS FAMILIA,
           b.pmv_numero AS VERSION_NUMERO,
           (SELECT COUNT(*) FROM cambios c WHERE c.pmv_id=b.pmv_id) AS CAMBIOS,
           ISNULL((SELECT MAX(c.FECHA) FROM cambios c WHERE c.pmv_id=b.pmv_id), b.pmv_fecha_creacion) AS ULTIMA_EDICION,
           ISNULL(u.usu_nombre + ISNULL(' ' + u.usu_apellido_paterno,''), '') AS RESPONSABLE
      FROM b
      LEFT JOIN Usuario u ON u.usu_id = ISNULL((SELECT TOP 1 c.USUARIO FROM cambios c WHERE c.pmv_id=b.pmv_id ORDER BY c.FECHA DESC),
                                               ISNULL(b.pma_usuario_planificador, b.USUARIO_VERSION))
     ORDER BY ULTIMA_EDICION DESC
END
GO

PRINT '299_PLANIFICACION_360_DATOS aplicado.'
GO
