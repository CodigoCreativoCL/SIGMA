/* ============================================================================
   SIGMA — Bloque 457
   CENTRO COMERCIAL · CATÁLOGO PARA LA PANTALLA
   ----------------------------------------------------------------------------
   Lo que el Centro Comercial pide una vez al abrir: los planes estándar con su
   mensualidad vigente y sus topes (para «Propuesta estándar»), y la UF del día
   para mostrar el equivalente en pesos. Va después de 456.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_COMERCIAL_CATALOGO]
AS
SET NOCOUNT ON
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

-- 0 · planes estándar (públicos) con la mensualidad vigente
SELECT  P.plc_id AS ID, P.plc_codigo AS CODIGO, P.plc_nombre AS NOMBRE, P.plc_descripcion AS DESCRIPCION,
        (SELECT TOP 1 pcp_valor_uf FROM [dbo].[Plan_Comercial_Precio] X
          WHERE X.pcp_plan_comercial = P.plc_id AND X.pcp_periodicidad_cobro = 1 AND X.pcp_habilitado = 1
            AND X.pcp_vigencia_desde <= @HOY AND (X.pcp_vigencia_hasta IS NULL OR X.pcp_vigencia_hasta >= @HOY)
          ORDER BY X.pcp_vigencia_desde DESC) AS MENSUAL_UF,
        (SELECT pcf_limite FROM [dbo].[Plan_Comercial_Funcionalidad] F JOIN [dbo].[Funcionalidad] U ON U.fun_id = F.pcf_funcionalidad
          WHERE F.pcf_plan_comercial = P.plc_id AND F.pcf_cliente IS NULL AND F.pcf_habilitado = 1 AND U.fun_codigo = N'LIMITE USUARIOS') AS LIM_USUARIOS,
        (SELECT pcf_limite FROM [dbo].[Plan_Comercial_Funcionalidad] F JOIN [dbo].[Funcionalidad] U ON U.fun_id = F.pcf_funcionalidad
          WHERE F.pcf_plan_comercial = P.plc_id AND F.pcf_cliente IS NULL AND F.pcf_habilitado = 1 AND U.fun_codigo = N'LIMITE ACTIVOS') AS LIM_ACTIVOS,
        (SELECT pcf_limite FROM [dbo].[Plan_Comercial_Funcionalidad] F JOIN [dbo].[Funcionalidad] U ON U.fun_id = F.pcf_funcionalidad
          WHERE F.pcf_plan_comercial = P.plc_id AND F.pcf_cliente IS NULL AND F.pcf_habilitado = 1 AND U.fun_codigo = N'LIMITE PLANTAS') AS LIM_PLANTAS,
        (SELECT pcf_limite FROM [dbo].[Plan_Comercial_Funcionalidad] F JOIN [dbo].[Funcionalidad] U ON U.fun_id = F.pcf_funcionalidad
          WHERE F.pcf_plan_comercial = P.plc_id AND F.pcf_cliente IS NULL AND F.pcf_habilitado = 1 AND U.fun_codigo = N'LIMITE ALMACENAMIENTO') AS LIM_GB,
        -- Módulos comerciales que el plan incluye (al menos una funcionalidad del módulo incluida)
        (SELECT STRING_AGG(m.modulo, ',') FROM (
            SELECT DISTINCT M.modulo FROM [dbo].[FNC_COMERCIAL_MODULO_FUNCIONALIDAD]() M
              JOIN [dbo].[Funcionalidad] U ON U.fun_codigo = M.fun_codigo
              JOIN [dbo].[Plan_Comercial_Funcionalidad] F ON F.pcf_funcionalidad = U.fun_id
             WHERE F.pcf_plan_comercial = P.plc_id AND F.pcf_cliente IS NULL AND F.pcf_habilitado = 1 AND F.pcf_incluida = 1) m) AS MODULOS
FROM    [dbo].[Plan_Comercial] P
WHERE   P.plc_publico = 1 AND P.plc_habilitado = 1
ORDER BY P.plc_orden, P.plc_id

-- 1 · la UF del día (la última conocida)
SELECT [dbo].[FNC_VALOR_UF](@HOY) AS UF
GO

/* Un parámetro por código. No existía un SP de lectura de Sys_Parametros. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_SYS_PARAMETROS_CODIGO]
@CODIGO VARCHAR(50)
AS
SET NOCOUNT ON
SELECT par_codigo AS CODIGO, par_valor AS VALOR FROM [dbo].[Sys_Parametros] WHERE par_codigo = @CODIGO
GO

PRINT '457_CENTRO_COMERCIAL_CATALOGO aplicado.'
GO
