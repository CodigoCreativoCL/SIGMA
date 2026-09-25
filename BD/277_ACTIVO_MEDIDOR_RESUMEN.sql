USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     EL RESUMEN DE LOS CONTADORES DE UN ACTIVO.
-- =============================================
-- QUE FALTABA
--   La tarjeta del contador tiene que decir tres cosas que no estaban en
--   Activo_Medidor: de donde vino la ultima lectura -app o manual-, a que
--   valor esta citado el proximo mantenimiento, y cuanto falta para llegar.
--
--   El objetivo vive en la OCURRENCIA del plan -pmo_valor_medidor_objetivo-,
--   y la ocurrencia se ata al contador por el activo del plan
--   -Plan_Mantenimiento_Activo.pac_activo_medidor-, no por si misma. De ahi
--   el rodeo por hito y version.
--
--   Un contador sin plan por uso devuelve NULL en el objetivo: la tarjeta
--   dice "sin mantenimiento asociado" y no inventa una cuenta regresiva.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_MEDIDOR_RESUMEN]
    @CLIENTE INT,
    @ACTIVO  INT
AS
SET NOCOUNT ON

SELECT  m.ame_id                                            AS ID,
        m.ame_codigo                                        AS CODIGO,
        m.ame_nombre                                        AS NOMBRE,
        m.ame_valor_actual                                  AS VALOR,
        u.ume_simbolo                                       AS UNIDAD,
        c.aco_nombre                                        AS COMPONENTE,

        /* La ultima lectura de verdad: la fecha del medidor es la del valor
           actual, pero el ORIGEN solo lo sabe la lectura. */
        l.aml_fecha_lectura_utc                             AS FECHA,
        dor.dor_nombre                                      AS ORIGEN,

        p.OBJETIVO                                          AS OBJETIVO,
        CASE WHEN p.OBJETIVO IS NULL THEN NULL
             ELSE p.OBJETIVO - m.ame_valor_actual END       AS FALTA,
        p.PLAN_NOMBRE                                       AS PLAN_NOMBRE

FROM    [dbo].[Activo_Medidor] m

        INNER JOIN [dbo].[Unidad_Medida] u
            ON u.ume_id = m.ame_unidad_medida

        LEFT JOIN [dbo].[Activo_Componente] c
            ON c.aco_id = m.ame_activo_componente

        /* La ultima lectura cargada, sea de la app o de la web. */
        OUTER APPLY (
            SELECT  TOP 1 x.aml_fecha_lectura_utc, x.aml_dato_origen
              FROM  [dbo].[Activo_Medidor_Lectura] x
             WHERE  x.aml_activo_medidor = m.ame_id
             ORDER  BY x.aml_fecha_lectura_utc DESC, x.aml_id DESC
        ) l

        LEFT JOIN [dbo].[Dato_Origen] dor
            ON dor.dor_id = l.aml_dato_origen

        /* El proximo hito citado por uso: el objetivo mas bajo que todavia no
           se cumple. Uno ya pasado no es el proximo. */
        OUTER APPLY (
            SELECT  TOP 1 o.pmo_valor_medidor_objetivo AS OBJETIVO,
                          pm.pma_nombre               AS PLAN_NOMBRE
              FROM  [dbo].[Plan_Mantenimiento_Ocurrencia] o
                    INNER JOIN [dbo].[Plan_Mantenimiento_Hito] h
                        ON h.pmh_id = o.pmo_plan_mantenimiento_hito
                    INNER JOIN [dbo].[Plan_Mantenimiento_Version] v
                        ON v.pmv_id = h.pmh_plan_mantenimiento_version
                    INNER JOIN [dbo].[Plan_Mantenimiento] pm
                        ON pm.pma_id = v.pmv_plan_mantenimiento
                    INNER JOIN [dbo].[Plan_Mantenimiento_Activo] pa
                        ON  pa.pac_plan_mantenimiento_version = v.pmv_id
                        AND pa.pac_activo = o.pmo_activo
                        AND pa.pac_activo_medidor = m.ame_id
             WHERE  o.pmo_activo = m.ame_activo
               AND  ISNULL(o.pmo_habilitado, 1) = 1
               AND  o.pmo_plan_ocurrencia_estado IN (1, 2, 3)   -- PENDIENTE, DISPONIBLE, EN EJECUCION
               AND  o.pmo_valor_medidor_objetivo IS NOT NULL
               AND  o.pmo_valor_medidor_objetivo >= m.ame_valor_actual
             ORDER  BY o.pmo_valor_medidor_objetivo
        ) p

WHERE   m.ame_cliente = @CLIENTE
  AND   m.ame_activo  = @ACTIVO
  AND   ISNULL(m.ame_habilitado, 1) = 1

ORDER BY m.ame_nombre
GO
PRINT '--- SEL_ACTIVO_MEDIDOR_RESUMEN creado.'
GO

PRINT '277_ACTIVO_MEDIDOR_RESUMEN aplicado.'
GO
