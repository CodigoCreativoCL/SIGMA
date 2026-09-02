USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     T-2109 DATOS DE PRUEBA DE ACTIVO_COMPONENTE PARA EJERCITAR HU-036.
-- =============================================
-- Va DESPUES de 96_SPRINT2_ACTIVO_COMPONENTE.
--
-- Siembra 3 componentes en el activo MOT-001 de Hamburgo, cada uno de un tipo
-- distinto (el indice UX_ACO_ACTIVO_TIPO_POSICION no deja dos del mismo tipo
-- en la misma posicion). Los ids de tipo/estado se resuelven en tiempo de
-- ejecucion tomando los primeros del catalogo, para no depender de codigos.
--
-- ES IDEMPOTENTE: cada componente por (activo, codigo).
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1, @USUARIO INT = 1
DECLARE @ACT INT, @EST INT, @CRI INT
DECLARE @T1 INT, @T2 INT, @T3 INT

SELECT @ACT = act_id FROM [dbo].[Activo] WHERE act_cliente=@CLIENTE AND act_codigo=N'MOT-001'

IF @ACT IS NULL
BEGIN
    PRINT '--- No esta MOT-001 (falta el bloque 75). No se cargan componentes.'
    RETURN
END

SELECT TOP 1 @EST = ace_id FROM [dbo].[Activo_Componente_Estado] WHERE ace_habilitado=1 ORDER BY ace_orden, ace_id
SELECT TOP 1 @CRI = crn_id FROM [dbo].[Criticidad_Nivel] WHERE crn_codigo=N'MEDIA'
IF @CRI IS NULL SELECT TOP 1 @CRI = crn_id FROM [dbo].[Criticidad_Nivel] WHERE crn_habilitado=1 ORDER BY crn_orden

;WITH t AS (
    SELECT cto_id, ROW_NUMBER() OVER (ORDER BY cto_orden, cto_id) rn
    FROM [dbo].[Componente_Tipo]
    WHERE cto_habilitado=1 AND (cto_cliente=@CLIENTE OR cto_cliente IS NULL)
)
SELECT @T1 = MAX(CASE WHEN rn=1 THEN cto_id END),
       @T2 = MAX(CASE WHEN rn=2 THEN cto_id END),
       @T3 = MAX(CASE WHEN rn=3 THEN cto_id END)
FROM t

DECLARE @C TABLE (codigo NVARCHAR(50), nombre NVARCHAR(200), tipo INT)
INSERT INTO @C VALUES
    (N'ROD-01',   N'Rodamiento lado acople',   @T1),
    (N'SELLO-01', N'Sello mecánico',           @T2),
    (N'EJE-01',   N'Eje principal',            @T3)

INSERT INTO [dbo].[Activo_Componente]
    (aco_cliente, aco_activo, aco_componente_tipo, aco_criticidad_nivel,
     aco_activo_componente_estado, aco_codigo, aco_nombre, aco_fecha_instalacion,
     aco_registro_origen, aco_usuario_creacion, aco_fecha_creacion,
     aco_usuario_actualizacion, aco_fecha_actualizacion, aco_habilitado)
SELECT  @CLIENTE, @ACT, c.tipo, @CRI, @EST, c.codigo, c.nombre,
        CAST(DATEADD(DAY,-30,GETDATE()) AS DATE), 1, @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1
FROM    @C c
WHERE   c.tipo IS NOT NULL
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_activo=@ACT AND aco_codigo=c.codigo)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

DECLARE @ACT INT
SELECT @ACT = act_id FROM [dbo].[Activo] WHERE act_cliente=1 AND act_codigo=N'MOT-001'
SELECT 'componentes de MOT-001' AS control, COUNT(*) AS valor
FROM   [dbo].[Activo_Componente] WHERE aco_activo=@ACT
GO

PRINT '97_SPRINT2_ACTIVO_COMPONENTE_DEMO aplicado.'
GO
