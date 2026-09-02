USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     T-2284 DATOS DE PRUEBA DE UNIDAD_MEDIDA PARA EJERCITAR HU-040.
-- =============================================
-- Va DESPUES de 93_SPRINT2_UNIDAD_MEDIDA.
--
-- Ya hay unidades sembradas (inventario: metro, kg, litro...; medidores:
-- hora, ciclo, kilometro). Aqui se agrega TEMPERATURA para ejercitar el
-- caso del OFFSET, que ninguna unidad previa usaba: Kelvin es la base y el
-- grado Celsius cuelga de ella con offset 273.15 (0 C = 273.15 K).
--
-- Magnitud 1 = TEMPERATURA (bloque 04). Defensivo: si TEMPERATURA ya tuviera
-- una base, Kelvin cuelga de ella; si no, Kelvin es la base.
--
-- ES IDEMPOTENTE: cada unidad por su codigo.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @USUARIO INT = 1
DECLARE @BASE_TEMP INT

SELECT @BASE_TEMP = ume_id FROM [dbo].[Unidad_Medida]
 WHERE ume_magnitud = 1 AND ume_unidad_base IS NULL

IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'KELVIN')
    INSERT INTO [dbo].[Unidad_Medida]
        (ume_magnitud, ume_unidad_base, ume_codigo, ume_nombre, ume_simbolo,
         ume_factor, ume_offset, ume_usuario_creacion, ume_fecha_creacion, ume_habilitado)
    VALUES (1, @BASE_TEMP, N'KELVIN', N'Kelvin', N'K', 1, 0, @USUARIO, GETDATE(), 1)

DECLARE @KELVIN INT
SELECT @KELVIN = ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'KELVIN'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'CELSIUS')
    INSERT INTO [dbo].[Unidad_Medida]
        (ume_magnitud, ume_unidad_base, ume_codigo, ume_nombre, ume_simbolo,
         ume_factor, ume_offset, ume_usuario_creacion, ume_fecha_creacion, ume_habilitado)
    VALUES (1, @KELVIN, N'CELSIUS', N'Grado Celsius', N'°C', 1, 273.15, @USUARIO, GETDATE(), 1)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'total unidades'      AS control, COUNT(*) AS valor FROM [dbo].[Unidad_Medida]
UNION ALL
SELECT 'unidades temperatura', COUNT(*) FROM [dbo].[Unidad_Medida] WHERE ume_magnitud = 1
GO

PRINT '94_SPRINT2_UNIDAD_MEDIDA_DEMO aplicado.'
GO
