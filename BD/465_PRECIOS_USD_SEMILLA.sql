/* ============================================================================
   SIGMA — Bloque 465
   PRECIOS EN USD DE LOS PLANES ESTÁNDAR (semilla; se ajustan en el drawer Plan)
   ----------------------------------------------------------------------------
   Mensual: Básico 650, Medio 1.300, Full 1.950 USD (valores de diseño del prompt
   V2). Trimestral con ~5 % y anual con ~17 % menos que doce mensualidades, como
   en las listas en UF. Solo se siembra donde el plan aún no tiene precio en USD.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

DECLARE @P TABLE (codigo NVARCHAR(50), mensual DECIMAL(18,4))
INSERT @P VALUES (N'BASICO', 650), (N'MEDIO', 1300), (N'FULL', 1950)

DECLARE @PLAN INT, @MEN DECIMAL(18,4), @ID INT
DECLARE C CURSOR LOCAL FAST_FORWARD FOR
    SELECT pl.plc_id, p.mensual FROM @P p JOIN [dbo].[Plan_Comercial] pl ON pl.plc_codigo = p.codigo
OPEN C
FETCH NEXT FROM C INTO @PLAN, @MEN
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Precio] WHERE pcp_plan_comercial = @PLAN AND pcp_moneda = 'USD' AND pcp_habilitado = 1)
    BEGIN
        EXEC [dbo].[UPS_PLAN_COMERCIAL_PRECIO] @ID = @ID OUTPUT, @PLAN = @PLAN, @PERIODICIDAD = 1, @VALOR_UF = @MEN, @USUARIO = 1, @MONEDA = 'USD'
        DECLARE @TRI DECIMAL(18,4) = ROUND(@MEN * 3 * 0.95, 0), @ANU DECIMAL(18,4) = ROUND(@MEN * 12 * 0.83, 0)
        EXEC [dbo].[UPS_PLAN_COMERCIAL_PRECIO] @ID = @ID OUTPUT, @PLAN = @PLAN, @PERIODICIDAD = 2, @VALOR_UF = @TRI, @USUARIO = 1, @MONEDA = 'USD'
        EXEC [dbo].[UPS_PLAN_COMERCIAL_PRECIO] @ID = @ID OUTPUT, @PLAN = @PLAN, @PERIODICIDAD = 3, @VALOR_UF = @ANU, @USUARIO = 1, @MONEDA = 'USD'
    END
    FETCH NEXT FROM C INTO @PLAN, @MEN
END
CLOSE C
DEALLOCATE C
GO
PRINT '465_PRECIOS_USD_SEMILLA aplicado.'
GO
