/* ============================================================================
   SIGMA — Bloque 466
   CENTRO COMERCIAL V2 · LECTURAS PARA LOS DRAWERS DE COBROS
   ----------------------------------------------------------------------------
   SEL_COBRO_ESTADO_SUSCRIPCION  una fila por suscripción con su situación de
                                 cobro (pendiente, mora, por verificar, último
                                 medio con que pagó). Alimenta la lista y los
                                 chips «Pagado en línea / Transferencia verificada
                                 / Pendiente / En mora».
   SEL_COBRO_CONSUMO             uso contra topes de un cliente.
   SEL_COBRO_ATENCION            lo que pide acción en el Resumen: transferencias
                                 por verificar, cobros en mora y suscripciones a
                                 punto de suspenderse.
   Mora = período impago cuyo primer día pasó hace 3 días o más (la misma regla
   del recordatorio MORA de COBROS_RECORDATORIOS).
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_COBRO_ESTADO_SUSCRIPCION]
AS
SET NOCOUNT ON
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
SELECT  S.sus_id                            AS ID,
        C.cli_pais                          AS PAIS_ID,
        PA.pai_nombre                       AS PAIS,
        C.cli_moneda_cobro                  AS MONEDA,
        ISNULL(X.pendientes, 0)             AS PERIODOS_PENDIENTES,
        ISNULL(X.saldo, 0)                  AS SALDO,
        CONVERT(VARCHAR(10), X.vence, 120)  AS PROXIMO_VENCE,
        CASE WHEN ISNULL(X.mora, 0) > 0 THEN 1 ELSE 0 END AS EN_MORA,
        ISNULL(PV.n, 0)                     AS POR_VERIFICAR,
        U.medio                             AS ULTIMO_MEDIO,
        DATEDIFF(DAY, @HOY, DATEADD(DAY, ISNULL(S.sus_dias_gracia, 0), S.sus_fecha_fin)) AS DIAS_PARA_SUSPENDER
FROM    [dbo].[Suscripcion] S
JOIN    [dbo].[Cliente] C   ON C.cli_id = S.sus_cliente
LEFT JOIN [dbo].[Paises] PA ON PA.pai_id = C.cli_pais
OUTER APPLY (SELECT COUNT(*) AS pendientes,
                    SUM(E.spe_monto_clp - E.spe_monto_pagado_clp) AS saldo,
                    MIN(E.spe_fecha_inicio) AS vence,
                    SUM(CASE WHEN DATEDIFF(DAY, E.spe_fecha_inicio, @HOY) >= 3 THEN 1 ELSE 0 END) AS mora
               FROM [dbo].[Suscripcion_Periodo] E
              WHERE E.spe_suscripcion = S.sus_id AND E.spe_habilitado = 1
                AND E.spe_suscripcion_periodo_estado IN (1, 2)
                AND E.spe_monto_clp - E.spe_monto_pagado_clp > 0) X
OUTER APPLY (SELECT COUNT(*) AS n
               FROM [dbo].[Suscripcion_Pago] G
               JOIN [dbo].[Suscripcion_Periodo] E ON E.spe_id = G.spa_suscripcion_periodo
              WHERE E.spe_suscripcion = S.sus_id AND G.spa_habilitado = 1
                AND G.spa_suscripcion_pago_estado IN (1, 2)) PV
OUTER APPLY (SELECT TOP 1 G.spa_medio AS medio
               FROM [dbo].[Suscripcion_Pago] G
               JOIN [dbo].[Suscripcion_Periodo] E ON E.spe_id = G.spa_suscripcion_periodo
              WHERE E.spe_suscripcion = S.sus_id AND G.spa_habilitado = 1
                AND G.spa_suscripcion_pago_estado = 3
              ORDER BY G.spa_fecha_verificacion_utc DESC, G.spa_id DESC) U
WHERE   S.sus_habilitado = 1
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_COBRO_CONSUMO]
@CLIENTE INT
AS
SET NOCOUNT ON
SELECT t.codigo AS CODIGO, t.nombre AS NOMBRE,
       CAST([dbo].[FNC_CLIENTE_CONSUMO](@CLIENTE, t.codigo) AS DECIMAL(18,2)) AS USO,
       CAST([dbo].[FNC_CLIENTE_LIMITE](@CLIENTE, t.codigo) AS DECIMAL(18,2)) AS TOPE
  FROM (VALUES (N'LIMITE USUARIOS', N'Usuarios'), (N'LIMITE ACTIVOS', N'Activos'),
               (N'LIMITE PLANTAS', N'Plantas'), (N'LIMITE ALMACENAMIENTO', N'GB')) t(codigo, nombre)
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_COBRO_ATENCION]
AS
SET NOCOUNT ON
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
-- 0 · transferencias por verificar
SELECT G.spa_id AS ID, C.cli_nombre AS CLIENTE, S.sus_id AS SUSCRIPCION, G.spa_monto_declarado_clp AS MONTO, G.spa_moneda AS MONEDA,
       G.spa_medio AS MEDIO, CONVERT(VARCHAR(10), G.spa_fecha_transferencia, 120) AS FECHA, G.spa_banco AS BANCO
  FROM [dbo].[Suscripcion_Pago] G
  JOIN [dbo].[Suscripcion_Periodo] E ON E.spe_id = G.spa_suscripcion_periodo
  JOIN [dbo].[Suscripcion] S ON S.sus_id = E.spe_suscripcion
  JOIN [dbo].[Cliente] C ON C.cli_id = S.sus_cliente
 WHERE G.spa_habilitado = 1 AND G.spa_suscripcion_pago_estado IN (1, 2)
 ORDER BY G.spa_fecha_transferencia
-- 1 · cobros en mora, con los días que le quedan antes de suspenderse
SELECT S.sus_id AS SUSCRIPCION, C.cli_nombre AS CLIENTE, C.cli_moneda_cobro AS MONEDA,
       SUM(E.spe_monto_clp - E.spe_monto_pagado_clp) AS SALDO,
       MIN(DATEDIFF(DAY, E.spe_fecha_inicio, @HOY)) AS DIAS_MORA,
       DATEDIFF(DAY, @HOY, DATEADD(DAY, ISNULL(S.sus_dias_gracia, 0), S.sus_fecha_fin)) AS DIAS_PARA_SUSPENDER
  FROM [dbo].[Suscripcion] S
  JOIN [dbo].[Cliente] C ON C.cli_id = S.sus_cliente
  JOIN [dbo].[Suscripcion_Periodo] E ON E.spe_suscripcion = S.sus_id AND E.spe_habilitado = 1
   AND E.spe_suscripcion_periodo_estado IN (1, 2) AND E.spe_monto_clp - E.spe_monto_pagado_clp > 0
   AND DATEDIFF(DAY, E.spe_fecha_inicio, @HOY) >= 3
 WHERE S.sus_habilitado = 1
 GROUP BY S.sus_id, C.cli_nombre, C.cli_moneda_cobro, S.sus_dias_gracia, S.sus_fecha_fin
 ORDER BY MIN(E.spe_fecha_inicio)
RETURN 0
GO

PRINT '466_COBROS_DRAWERS_SP aplicado.'
GO
