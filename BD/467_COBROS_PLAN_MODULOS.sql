/* ============================================================================
   SIGMA — Bloque 467
   Plan en drawer: funcionalidades agrupadas por módulo comercial.
   Expone FNC_COMERCIAL_MODULO_FUNCIONALIDAD como SP (el servicio solo llama SP).
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_COMERCIAL_MODULO_FUNCIONALIDAD]
AS
SET NOCOUNT ON
SELECT M.modulo AS MODULO, M.fun_codigo AS FUN_CODIGO FROM [dbo].[FNC_COMERCIAL_MODULO_FUNCIONALIDAD]() M
RETURN 0
GO

PRINT '467_COBROS_PLAN_MODULOS aplicado.'
GO
