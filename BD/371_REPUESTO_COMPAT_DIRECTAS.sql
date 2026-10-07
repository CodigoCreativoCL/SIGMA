USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     LOS VINCULOS DIRECTOS DE UN REPUESTO (A UN ACTIVO O A UN COMPONENTE).
-- =============================================
-- POR QUE
--   La ficha del repuesto (asistente de 6 pasos) trae el paso «Compatibilidades»:
--   a que activo, subactivo o componente le sirve. Para editarlo hay que leer los
--   vinculos que ya existen CON SU ID de activo o de componente.
--   SEL_REPUESTO_COMPATIBILIDAD no devuelve rco_activo (solo el nombre), y los
--   vinculos por tipo o modelo viven aparte: aqui solo van los directos.
-- TODO IDEMPOTENTE.
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO_COMPAT_DIRECTAS]
    @CLIENTE   INT,
    @REPUESTO  INT
AS
SET NOCOUNT ON

SELECT  c.rco_id,
        c.rco_activo,
        c.rco_activo_componente,
        ISNULL(c.rco_observacion, '') AS rco_observacion
FROM    [dbo].[Repuesto_Compatibilidad] c
JOIN    [dbo].[Repuesto] r ON r.rep_id = c.rco_repuesto
WHERE   r.rep_cliente = @CLIENTE
  AND   c.rco_repuesto = @REPUESTO
  AND   (c.rco_activo IS NOT NULL OR c.rco_activo_componente IS NOT NULL)
ORDER BY c.rco_id
GO

PRINT '371_REPUESTO_COMPAT_DIRECTAS aplicado.'
GO
