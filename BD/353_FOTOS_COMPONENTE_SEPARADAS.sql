/* ============================================================================
   SIGMA - Bloque 353
   LA FOTO DE UN COMPONENTE NO ES FOTO DE SU ACTIVO
   ----------------------------------------------------------------------------
   VIN_ACTIVO_COMPONENTE_IMAGEN guarda la foto de un componente con
   avi_activo (el activo del componente) Y avi_activo_componente. Los bloques
   346 y 348 leian «toda fila con avi_activo» como foto del activo:
     - el 348 dejo las fotos de componentes como fotos comunes del activo
       (avi_es_referencia 0, avi_es_foto 1): el componente perdio su imagen;
     - una foto de componente nueva aparecia como portada del activo.
   Se repara:
     1. datos: la foto de cada componente vuelve a ser su referencia (la mas
        reciente; las otras se apagan, como hace VIN_ACTIVO_COMPONENTE_IMAGEN),
        y un activo que quedo sin portada propia toma su primera foto;
     2. las lecturas y escrituras de fotos del ACTIVO excluyen las filas de
        componentes (avi_activo_componente IS NULL);
     3. SEL_ACTIVO_IMAGENES_LISTA (349) clasifica por avi_activo_componente, y
        SEL_ACTIVO_ARCHIVO_TODO rotula «Foto de un componente».
   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

-- 1a. la foto de cada componente vuelve a ser su referencia
UPDATE [dbo].[Archivo_Vinculo]
   SET avi_es_referencia = 1, avi_es_foto = 0
 WHERE avi_activo_componente IS NOT NULL AND ISNULL(avi_es_foto, 0) = 1
GO
-- 1b. una sola referencia habilitada por componente: la mas reciente
;WITH r AS (
    SELECT avi_id, ROW_NUMBER() OVER (PARTITION BY avi_activo_componente ORDER BY avi_id DESC) AS n
    FROM   [dbo].[Archivo_Vinculo]
    WHERE  avi_activo_componente IS NOT NULL AND avi_es_referencia = 1 AND ISNULL(avi_habilitado, 1) = 1)
UPDATE v SET avi_habilitado = 0
FROM   [dbo].[Archivo_Vinculo] v JOIN r ON r.avi_id = v.avi_id
WHERE  r.n > 1
GO
-- 1c. un activo con fotos propias pero sin portada propia: la primera queda de portada
;WITH sinPortada AS (
    SELECT v.avi_activo
    FROM   [dbo].[Archivo_Vinculo] v
    WHERE  v.avi_activo IS NOT NULL AND v.avi_activo_componente IS NULL AND v.avi_habilitado = 1 AND ISNULL(v.avi_es_foto, 0) = 1
      AND  NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Vinculo] p
                        WHERE p.avi_activo = v.avi_activo AND p.avi_activo_componente IS NULL
                          AND p.avi_es_referencia = 1 AND p.avi_habilitado = 1)
    GROUP BY v.avi_activo),
primera AS (
    SELECT v.avi_id, ROW_NUMBER() OVER (PARTITION BY v.avi_activo ORDER BY ISNULL(v.avi_orden, 0), v.avi_id) AS n
    FROM   [dbo].[Archivo_Vinculo] v JOIN sinPortada s ON s.avi_activo = v.avi_activo
    WHERE  v.avi_activo_componente IS NULL AND v.avi_habilitado = 1 AND ISNULL(v.avi_es_foto, 0) = 1)
UPDATE v SET avi_es_referencia = 1, avi_es_foto = 0
FROM   [dbo].[Archivo_Vinculo] v JOIN primera p ON p.avi_id = v.avi_id
WHERE  p.n = 1
GO

-- 2. las fotos del activo, sin las de sus componentes
DECLARE @sp SYSNAME, @sql NVARCHAR(MAX)
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.procedures
    WHERE  name IN ('DEL_ACTIVO_FOTO', 'DEL_ACTIVO_IMAGEN', 'INS_ACTIVO_FOTO', 'UPD_ACTIVO_PORTADA')
OPEN c
FETCH NEXT FROM c INTO @sp
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = OBJECT_DEFINITION(OBJECT_ID(N'dbo.' + @sp))
    IF @sql NOT LIKE N'%avi_activo = @ACTIVO AND avi_activo_componente IS NULL%'
    BEGIN
        SET @sql = REPLACE(@sql, N'avi_activo = @ACTIVO AND', N'avi_activo = @ACTIVO AND avi_activo_componente IS NULL AND')
        SET @sql = REPLACE(REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE'), N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
        EXEC (@sql)
    END
    FETCH NEXT FROM c INTO @sp
END
CLOSE c; DEALLOCATE c

SET @sql = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_FOTOS'))
IF @sql NOT LIKE N'%v.avi_activo_componente IS NULL%'
BEGIN
    SET @sql = REPLACE(@sql, N'v.avi_activo = @ACTIVO AND', N'v.avi_activo = @ACTIVO AND v.avi_activo_componente IS NULL AND')
    SET @sql = REPLACE(REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE'), N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
    EXEC (@sql)
END

SET @sql = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_IMAGEN'))
IF @sql NOT LIKE N'%v.avi_activo_componente IS NULL%'
BEGIN
    SET @sql = REPLACE(@sql, N'WHERE   v.avi_activo = @ACTIVO', N'WHERE   v.avi_activo = @ACTIVO AND v.avi_activo_componente IS NULL')
    SET @sql = REPLACE(REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE'), N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
    EXEC (@sql)
END

SET @sql = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_PLANTA'))
IF @sql NOT LIKE N'%v.avi_activo_componente IS NULL%'
BEGIN
    SET @sql = REPLACE(@sql, N'WHERE v.avi_activo = a.act_id AND v.avi_es_referencia = 1',
                             N'WHERE v.avi_activo = a.act_id AND v.avi_activo_componente IS NULL AND v.avi_es_referencia = 1')
    SET @sql = REPLACE(@sql, N'WHERE  v.avi_habilitado = 1 AND (v.avi_es_referencia = 1 OR v.avi_es_foto = 1)',
                             N'WHERE  v.avi_habilitado = 1 AND v.avi_activo_componente IS NULL AND (v.avi_es_referencia = 1 OR v.avi_es_foto = 1)')
    SET @sql = REPLACE(REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE'), N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
    EXEC (@sql)
END

SET @sql = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_ARCHIVO_TODO'))
IF @sql NOT LIKE N'%Foto de un componente%'
BEGIN
    SET @sql = REPLACE(@sql, N'CASE WHEN ISNULL(v.avi_es_referencia, 0) = 1 THEN ''Foto de portada''',
                             N'CASE WHEN v.avi_activo_componente IS NOT NULL THEN ''Foto de un componente'' WHEN ISNULL(v.avi_es_referencia, 0) = 1 THEN ''Foto de portada''')
    SET @sql = REPLACE(REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE'), N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
    EXEC (@sql)
END
GO

-- 3. la lista de imagenes (349): componente si la fila es de un componente
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_IMAGENES_LISTA]
    @CLIENTE INT
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH r AS (
        SELECT CASE WHEN v.avi_activo_componente IS NOT NULL THEN 'C' ELSE 'A' END AS TIPO,
               ISNULL(v.avi_activo_componente, v.avi_activo) AS ID,
               a.arc_id AS ARC_ID,
               ROW_NUMBER() OVER (PARTITION BY CASE WHEN v.avi_activo_componente IS NOT NULL THEN 'C' ELSE 'A' END,
                                               ISNULL(v.avi_activo_componente, v.avi_activo)
                                  ORDER BY ISNULL(v.avi_orden, 0), v.avi_id DESC) AS n
        FROM   [dbo].[Archivo_Vinculo] v
        JOIN   [dbo].[Archivo] a ON a.arc_id = v.avi_archivo
        WHERE  (v.avi_activo IS NOT NULL OR v.avi_activo_componente IS NOT NULL)
          AND  v.avi_es_referencia = 1
          AND  ISNULL(v.avi_habilitado, 1) = 1
          AND  ISNULL(a.arc_habilitado, 1) = 1
          AND  a.arc_cliente = @CLIENTE)
    SELECT TIPO, ID, ARC_ID FROM r WHERE n = 1;
END
GO

SELECT 'componentes con foto' AS QUE, COUNT(DISTINCT avi_activo_componente) AS N FROM [dbo].[Archivo_Vinculo]
WHERE  avi_activo_componente IS NOT NULL AND avi_es_referencia = 1 AND ISNULL(avi_habilitado, 1) = 1
UNION ALL
SELECT 'activos con mas de una portada', COUNT(*) FROM (
    SELECT avi_activo FROM [dbo].[Archivo_Vinculo]
    WHERE  avi_activo IS NOT NULL AND avi_activo_componente IS NULL AND avi_es_referencia = 1 AND avi_habilitado = 1
    GROUP BY avi_activo HAVING COUNT(*) > 1) x
GO
