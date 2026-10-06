/* ============================================================================
   SIGMA - Bloque 354
   LA GALERIA DEL ACTIVO DICE DE QUE COMPONENTE ES CADA FOTO
   ----------------------------------------------------------------------------
   El bloque 353 rotulo «Foto de un componente»; se dice cual:
   «Foto de Motor Principal». Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

DECLARE @sql NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_ARCHIVO_TODO'))
IF @sql LIKE N'%THEN ''Foto de un componente''%'
BEGIN
    SET @sql = REPLACE(@sql, N'THEN ''Foto de un componente''',
        N'THEN N''Foto de '' + ISNULL((SELECT k.aco_nombre FROM [dbo].[Activo_Componente] k WHERE k.aco_id = v.avi_activo_componente), N''un componente'')')
    SET @sql = REPLACE(REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE'), N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
    EXEC (@sql)
END
GO

SELECT CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_ARCHIVO_TODO')) LIKE N'%k.aco_nombre FROM%' THEN 'OK' ELSE 'FALTA' END AS ROTULO
GO
