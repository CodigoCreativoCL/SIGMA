/* ============================================================================
   SIGMA - Bloque 348
   UNA SOLA PORTADA POR ACTIVO, Y LA MISMA EN TODAS PARTES
   ----------------------------------------------------------------------------
   Antes del bloque 346 un activo podía quedar con varias fotos marcadas como
   referencia (avi_es_referencia = 1): la tarjeta mostraba una y la galería
   ponía la estrella en otra. Se deja como portada la primera (por orden y
   después por id, igual que SEL_ACTIVO_FOTOS) y las demás pasan a ser fotos
   del activo (avi_es_foto = 1). SEL_ACTIVO_PLANTA elige la portada con ese
   mismo orden.
   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
GO

;WITH r AS (
    SELECT avi_id, ROW_NUMBER() OVER (PARTITION BY avi_activo ORDER BY ISNULL(avi_orden, 0), avi_id) AS n
    FROM   [dbo].[Archivo_Vinculo]
    WHERE  avi_activo IS NOT NULL AND avi_es_referencia = 1 AND avi_habilitado = 1)
UPDATE v SET avi_es_referencia = 0, avi_es_foto = 1
FROM   [dbo].[Archivo_Vinculo] v JOIN r ON r.avi_id = v.avi_id
WHERE  r.n > 1
GO

-- La portada en la lectura de la planta: el mismo orden que la galería.
DECLARE @sql NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_PLANTA'))
SET @sql = REPLACE(@sql, N'WHERE v.avi_activo = a.act_id AND v.avi_es_referencia = 1 AND v.avi_habilitado = 1 ORDER BY v.avi_id DESC) AS PORTADA',
                         N'WHERE v.avi_activo = a.act_id AND v.avi_es_referencia = 1 AND v.avi_habilitado = 1 ORDER BY ISNULL(v.avi_orden, 0), v.avi_id) AS PORTADA')
SET @sql = REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE')
SET @sql = REPLACE(@sql, N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
EXEC (@sql)
GO

SELECT avi_activo, COUNT(*) AS portadas FROM [dbo].[Archivo_Vinculo]
WHERE  avi_activo IS NOT NULL AND avi_es_referencia = 1 AND avi_habilitado = 1
GROUP BY avi_activo HAVING COUNT(*) > 1
GO
