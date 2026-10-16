/* ============================================================================
   SIGMA — Bloque 470
   Página pública de pago: transferencias ya informadas y por verificar.
   SEL_COBRO_SUSCRIPCION suma un tercer conjunto (lo ya informado y esperando
   verificación) para que Pagar.aspx muestre el estado «informado» y no pida
   pagar dos veces lo mismo. Los dos primeros conjuntos no cambian.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_COBRO_SUSCRIPCION]
@SUSCRIPCION INT
AS
SET NOCOUNT ON
-- 0 · la suscripción y a quién se le escribe
SELECT sus_id AS SUSCRIPCION, sus_cliente AS CLIENTE, cli_nombre AS EMPRESA, plc_nombre AS PLAN_NOMBRE, contacto_correo AS CORREO,
       contacto_nombre AS CONTACTO, ejecutivo_nombre AS EJECUTIVO, ejecutivo_correo AS EJECUTIVO_CORREO, lea_id AS LEAD,
       mensual_uf AS MENSUAL_UF, CONVERT(VARCHAR(10), fin_contrato, 120) AS FIN_CONTRATO, moneda AS MONEDA
  FROM [dbo].[VW_SUSCRIPCION_COMERCIAL] WHERE sus_id = @SUSCRIPCION
-- 1 · lo pendiente de pago
SELECT spe_id AS ID, CONVERT(VARCHAR(10), spe_fecha_inicio, 120) AS DESDE, CONVERT(VARCHAR(10), spe_fecha_fin, 120) AS HASTA,
       spe_valor_uf_plan AS UF, spe_monto_clp AS MONTO, spe_monto_pagado_clp AS PAGADO, spe_monto_clp - spe_monto_pagado_clp AS SALDO,
       spe_es_implantacion AS IMPLANTACION, spe_observacion AS OBSERVACION, spe_moneda AS MONEDA
  FROM [dbo].[Suscripcion_Periodo]
 WHERE spe_suscripcion = @SUSCRIPCION AND spe_habilitado = 1 AND spe_suscripcion_periodo_estado IN (1, 2)
   AND spe_monto_clp - spe_monto_pagado_clp > 0
 ORDER BY spe_es_implantacion DESC, spe_fecha_inicio
-- 2 · transferencias ya informadas que esperan verificación
SELECT COUNT(*) AS N, ISNULL(SUM(G.spa_monto_declarado_clp), 0) AS MONTO
  FROM [dbo].[Suscripcion_Pago] G
  JOIN [dbo].[Suscripcion_Periodo] E ON E.spe_id = G.spa_suscripcion_periodo
 WHERE E.spe_suscripcion = @SUSCRIPCION AND G.spa_habilitado = 1 AND G.spa_suscripcion_pago_estado IN (1, 2)
GO

PRINT '470_COBRO_PUBLICO aplicado.'
GO
