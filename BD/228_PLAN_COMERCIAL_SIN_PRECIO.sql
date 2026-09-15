USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  14-09-2026
-- DESCRIPTION:     UN PLAN COMERCIAL RECIEN CREADO, SIN PRECIO, TIENE QUE
--                  VERSE EN EL LISTADO PARA PODER FIJARLE EL PRECIO.
-- =============================================
-- DEFECTO (encontrado en la evidencia de HU-190 #1, 14-09-2026)
--   SEL_PLAN_COMERCIAL unia Plan_Comercial con Plan_Comercial_Precio por
--   INNER JOIN: una fila por plan y periodicidad CON precio vigente. Un plan
--   recien creado no tiene precio, asi que no aparecia en Planes.aspx, y
--   como la ficha cierra al guardar, no habia camino para fijarle el
--   precio: el plan quedaba invisible para siempre.
--
-- LO QUE CAMBIA
--   LEFT JOIN a precio y periodicidad, con la condicion de vigencia dentro
--   del JOIN (en el WHERE anularia el LEFT). Un plan sin precio sale con
--   una fila y PCB/PCP en NULL; la pantalla lo muestra como «sin precio».
--   El filtro @PERIODICIDAD sigue exigiendo el precio, porque esa pregunta
--   («que se vende mensual») solo tiene sentido con precio.
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_COMERCIAL]
@ID             INT = NULL,
@PERIODICIDAD   INT = NULL,
@FECHA          DATE = NULL,
@SOLO_PUBLICOS  BIT = NULL,
@HABILITADO     BIT = NULL

AS
SET NOCOUNT ON

SET @FECHA = ISNULL(@FECHA, CAST(GETDATE() AS DATE))

    SELECT  p.plc_id                      AS PLC_ID,
            p.plc_codigo                  AS PLC_CODIGO,
            p.plc_nombre                  AS PLC_NOMBRE,
            p.plc_descripcion             AS PLC_DESCRIPCION,
            p.plc_dias_gracia             AS PLC_DIAS_GRACIA,
            p.plc_publico                 AS PLC_PUBLICO,
            p.plc_orden                   AS PLC_ORDEN,
            p.plc_habilitado              AS PLC_HABILITADO,
            pc.pcb_id                     AS PCB_ID,
            pc.pcb_codigo                 AS PCB_CODIGO,
            pc.pcb_nombre                 AS PCB_NOMBRE,
            pr.pcp_id                     AS PCP_ID,
            pr.pcp_valor_uf               AS PCP_VALOR_UF,
            pr.pcp_descuento_porcentaje   AS PCP_DESCUENTO_PORCENTAJE,
            -- Lo que costaria hoy, para mostrarlo en pantalla. NO es lo que
            -- se cobra: eso se congela recien al emitir el periodo.
            CAST(ROUND(pr.pcp_valor_uf * ISNULL([dbo].[FNC_VALOR_UF](@FECHA), 0), 0) AS DECIMAL(18,0))
                                          AS MONTO_CLP_REFERENCIAL,
            [dbo].[FNC_VALOR_UF](@FECHA)  AS VALOR_UF_DIA
    FROM    [dbo].[Plan_Comercial] p
    LEFT JOIN [dbo].[Plan_Comercial_Precio] pr
           ON pr.pcp_plan_comercial = p.plc_id
          AND pr.pcp_habilitado = 1
          AND pr.pcp_vigencia_desde <= @FECHA
          AND (pr.pcp_vigencia_hasta IS NULL OR pr.pcp_vigencia_hasta >= @FECHA)
    LEFT JOIN [dbo].[Periodicidad_Cobro] pc ON pc.pcb_id = pr.pcp_periodicidad_cobro
    WHERE   (@ID IS NULL OR p.plc_id = @ID)
      AND   (@PERIODICIDAD IS NULL OR pr.pcp_periodicidad_cobro = @PERIODICIDAD)
      AND   (@SOLO_PUBLICOS IS NULL OR @SOLO_PUBLICOS = 0 OR p.plc_publico = 1)
      AND   (@HABILITADO IS NULL OR p.plc_habilitado = @HABILITADO)
    ORDER BY p.plc_orden, pc.pcb_orden

RETURN(0)
GO
