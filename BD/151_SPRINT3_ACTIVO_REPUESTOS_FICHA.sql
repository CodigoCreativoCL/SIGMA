USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  05-09-2026
-- DESCRIPTION:     SPRINT 3 - REPUESTOS DE UN ACTIVO (para la Ficha 360).
-- =============================================
-- En la Ficha e historial, donde estaba "Componentes", ahora se muestran los
-- REPUESTOS del activo: los que le sirven segun su compatibilidad
-- (Repuesto_Compatibilidad -> por tipo o por modelo del activo).
--
-- Ademas se borran los componentes demo (COM-6..9) de Hamburgo: el despiece
-- pasa a manejarse como repuestos.
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* 1) SEL_ACTIVO_REPUESTO - repuestos compatibles con el activo (por tipo/modelo). */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_REPUESTO]
@ACTIVO INT, @CLIENTE INT
AS
SET NOCOUNT ON
    DECLARE @TIPO INT, @MODELO INT
    SELECT @TIPO = act_activo_tipo, @MODELO = act_activo_modelo
    FROM   [dbo].[Activo] WHERE act_id = @ACTIVO

    SELECT DISTINCT
           r.rep_id                    AS REP_ID,
           r.rep_codigo                AS REP_CODIGO,
           r.rep_nombre                AS REP_NOMBRE,
           ISNULL(r.rep_fabricante,'') AS REP_FABRICANTE,
           ISNULL(r.rep_modelo,'')     AS REP_MODELO
    FROM   [dbo].[Repuesto_Compatibilidad] c
    INNER JOIN [dbo].[Repuesto] r
        ON  r.rep_id = c.rco_repuesto
        AND r.rep_habilitado = 1
        AND r.rep_cliente = @CLIENTE
    WHERE  (c.rco_activo_tipo = @TIPO)
        OR (@MODELO IS NOT NULL AND c.rco_activo_modelo = @MODELO)
    ORDER BY r.rep_nombre
GO

/* 2) Limpieza de componentes demo de Hamburgo (el despiece va como repuestos). */
DELETE FROM [dbo].[Activo_Componente] WHERE aco_cliente = 1;
PRINT '--- Componentes demo eliminados; SEL_ACTIVO_REPUESTO creado.';
GO

PRINT '151_SPRINT3_ACTIVO_REPUESTOS_FICHA aplicado.';
GO
