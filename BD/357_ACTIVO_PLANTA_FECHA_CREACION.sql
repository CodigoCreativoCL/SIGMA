/* ============================================================================
   SIGMA - Bloque 357
   ORDENAR LOS ACTIVOS DE LA PLANTA POR FECHA DE CREACION
   ----------------------------------------------------------------------------
   La planta (Tarjetas y Lista) ordenaba por atencion, nombre o criticidad.
   Se suma "mas nuevos primero" y "mas antiguos primero": SEL_ACTIVO_PLANTA
   devuelve act_fecha_creacion como CREADO en el resultado 3 (activos).
   Se parcha la definicion viva (como los bloques 353 y 356), porque el SP
   ya tiene cambios posteriores al 346. Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

DECLARE @sql NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_PLANTA'))
IF @sql NOT LIKE N'%AS CREADO%' AND @sql LIKE N'%a.act_orden_area AS ORDEN,%'
BEGIN
    SET @sql = REPLACE(@sql, N'a.act_orden_area AS ORDEN,', N'a.act_orden_area AS ORDEN, a.act_fecha_creacion AS CREADO,')
    SET @sql = REPLACE(REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE'), N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
    EXEC (@sql)
END
GO

SELECT CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_PLANTA')) LIKE N'%a.act_fecha_creacion AS CREADO%' THEN 'OK' ELSE 'FALTA' END AS PLANTA
GO
