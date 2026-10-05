/* ============================================================================
   SIGMA - Bloque 350
   «ACTIVO», NO «EQUIPO», EN EL ORIGEN DE LOS ARCHIVOS
   ----------------------------------------------------------------------------
   SEL_ACTIVO_ARCHIVO_TODO (bloque 272) rotulaba el origen como «Imagen del
   equipo» / «Documento del equipo». El modulo dice «activo», y desde el
   bloque 346 un activo tiene portada (avi_es_referencia) y otras fotos
   (avi_es_foto): se rotulan «Foto de portada», «Foto del activo» y
   «Documento del activo».
   Idempotente: si ya esta cambiado, el REPLACE no encuentra nada.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
GO

DECLARE @sql NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_ARCHIVO_TODO'))
SET @sql = REPLACE(@sql,
    N'CASE WHEN ISNULL(v.avi_es_referencia, 0) = 1 THEN ''Imagen del equipo'' ELSE ''Documento del equipo'' END AS ORIGEN_NOMBRE',
    N'CASE WHEN ISNULL(v.avi_es_referencia, 0) = 1 THEN ''Foto de portada'' WHEN ISNULL(v.avi_es_foto, 0) = 1 THEN ''Foto del activo'' ELSE ''Documento del activo'' END AS ORIGEN_NOMBRE')
SET @sql = REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE')
SET @sql = REPLACE(@sql, N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
EXEC (@sql)
GO

SELECT CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_ARCHIVO_TODO')) LIKE N'%''Imagen del equipo''%' THEN 'QUEDA EQUIPO' ELSE 'OK' END AS RESULTADO
GO
