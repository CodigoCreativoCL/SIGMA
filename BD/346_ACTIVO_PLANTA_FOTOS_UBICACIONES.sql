/* ============================================================================
   SIGMA - Bloque 346
   LA PLANTA DE UN VISTAZO: FOTOS CON PORTADA, LUGARES LIBRES Y UNA LECTURA
   ----------------------------------------------------------------------------
   Rediseño del módulo de Activos (05-10-2026, docs/rediseno-activos):

     1. FOTOS DEL ACTIVO CON PORTADA. Un activo tiene varias fotos y UNA
        portada (la que se ve en tarjetas, mapa, 3D, explorador y cabecera).
        La portada sigue siendo el vinculo con avi_es_referencia = 1 -asi la
        lee la app desde el bloque 174 (ES_PORTADA)-; las demas fotos llevan
        la marca nueva avi_es_foto = 1. Los documentos siguen siendo
        avi_es_referencia = 0 y avi_es_foto = 0.
        VIN_ACTIVO_IMAGEN ya no apaga la foto anterior: la deja como foto mas.
     2. LUGARES EN ARBOL LIBRE. Instalacion_Area ya es un arbol con tipo; se
        agrega su orden, tipos de lugar propios de la empresa con su plural
        («Pasillo» / «Pasillos») y un tope de 5 niveles.
     3. ORDEN DEL ACTIVO DENTRO DE SU LUGAR (act_orden_area). Sin lugar =
        «Por ubicar».
     4. SEL_ACTIVO_PLANTA: toda la planta en una llamada (lugares, activos con
        su portada, componentes y repuestos con stock) para las vistas Lista,
        Tarjetas, Mapa, 3D y el explorador.
   Idempotente. No borra nada.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

-- ---------------------------------------------------------------------------
-- 0) Columnas nuevas
-- ---------------------------------------------------------------------------
IF COL_LENGTH('dbo.Archivo_Vinculo', 'avi_es_foto') IS NULL
    ALTER TABLE [dbo].[Archivo_Vinculo] ADD [avi_es_foto] BIT NOT NULL CONSTRAINT DF_AVI_ES_FOTO DEFAULT 0
GO
IF COL_LENGTH('dbo.Instalacion_Area', 'iar_orden') IS NULL
    ALTER TABLE [dbo].[Instalacion_Area] ADD [iar_orden] INT NULL
GO
IF COL_LENGTH('dbo.Instalacion_Area_Tipo', 'iat_cliente') IS NULL
    ALTER TABLE [dbo].[Instalacion_Area_Tipo] ADD [iat_cliente] INT NULL
GO
IF COL_LENGTH('dbo.Instalacion_Area_Tipo', 'iat_plural') IS NULL
    ALTER TABLE [dbo].[Instalacion_Area_Tipo] ADD [iat_plural] NVARCHAR(100) NULL
GO
IF COL_LENGTH('dbo.Activo', 'act_orden_area') IS NULL
    ALTER TABLE [dbo].[Activo] ADD [act_orden_area] INT NULL
GO

-- Plurales de los tipos comunes y tipos nuevos de SIGMA (Linea, Pasillo, Edificio, Piso...)
UPDATE [dbo].[Instalacion_Area_Tipo] SET iat_plural = N'Áreas'                WHERE iat_codigo = N'AREA'             AND iat_plural IS NULL
UPDATE [dbo].[Instalacion_Area_Tipo] SET iat_plural = N'Subáreas'             WHERE iat_codigo = N'SUBAREA'          AND iat_plural IS NULL
UPDATE [dbo].[Instalacion_Area_Tipo] SET iat_plural = N'Líneas de producción' WHERE iat_codigo = N'LINEA PRODUCCION' AND iat_plural IS NULL
UPDATE [dbo].[Instalacion_Area_Tipo] SET iat_plural = N'Salas'                WHERE iat_codigo = N'SALA'             AND iat_plural IS NULL
UPDATE [dbo].[Instalacion_Area_Tipo] SET iat_plural = N'Zonas exteriores'     WHERE iat_codigo = N'ZONA EXTERIOR'    AND iat_plural IS NULL
GO
DECLARE @T TABLE (cod NVARCHAR(50), nom NVARCHAR(100), plu NVARCHAR(100), ord INT)
INSERT INTO @T VALUES (N'LINEA', N'Línea', N'Líneas', 6), (N'PASILLO', N'Pasillo', N'Pasillos', 7), (N'EDIFICIO', N'Edificio', N'Edificios', 8),
                      (N'PISO', N'Piso', N'Pisos', 9), (N'ZONA', N'Zona', N'Zonas', 10), (N'SECTOR', N'Sector', N'Sectores', 11), (N'NAVE', N'Nave', N'Naves', 12)
INSERT INTO [dbo].[Instalacion_Area_Tipo] (iat_codigo, iat_nombre, iat_orden, iat_habilitado, iat_plural)
SELECT t.cod, t.nom, t.ord, 1, t.plu FROM @T t
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area_Tipo] x WHERE x.iat_codigo = t.cod)
GO

-- Las portadas de hoy siguen siendo portada; las fotos anteriores que se
-- apagaron al cambiar de imagen no se reviven (no se sabe si se querian).
-- Orden inicial de los lugares: por nombre dentro de su padre.
;WITH o AS (SELECT iar_id, ROW_NUMBER() OVER (PARTITION BY iar_cliente_instalacion, ISNULL(iar_area_padre, 0) ORDER BY iar_nombre) AS n
            FROM [dbo].[Instalacion_Area] WHERE iar_orden IS NULL)
UPDATE a SET iar_orden = o.n FROM [dbo].[Instalacion_Area] a JOIN o ON o.iar_id = a.iar_id
GO

-- ---------------------------------------------------------------------------
-- 1) Fotos del activo
-- ---------------------------------------------------------------------------
-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  05-10-2026
-- DESCRIPTION:     SELECT FOTOS DEL ACTIVO, LA PORTADA PRIMERO
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_FOTOS]
    @ACTIVO  INT,
    @CLIENTE INT
AS
SET NOCOUNT ON
    SELECT a.arc_id AS ARC_ID, a.arc_nombre_original AS NOMBRE, a.arc_mime AS MIME,
           CAST(v.avi_es_referencia AS BIT) AS ES_PORTADA, v.avi_fecha_creacion AS FECHA
    FROM   [dbo].[Archivo_Vinculo] v
    JOIN   [dbo].[Archivo] a ON a.arc_id = v.avi_archivo AND a.arc_habilitado = 1 AND a.arc_cliente = @CLIENTE
    WHERE  v.avi_activo = @ACTIVO AND v.avi_habilitado = 1 AND (v.avi_es_referencia = 1 OR v.avi_es_foto = 1)
    ORDER BY v.avi_es_referencia DESC, ISNULL(v.avi_orden, 0), v.avi_id
GO

-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  05-10-2026
-- DESCRIPTION:     AGREGA UNA FOTO AL ACTIVO. SI NO TIENE PORTADA, O SE
--                  PIDE, QUEDA COMO PORTADA (LA ANTERIOR PASA A FOTO)
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[INS_ACTIVO_FOTO]
    @ID       INT = NULL OUTPUT,
    @ACTIVO   INT,
    @ARCHIVO  INT,
    @PORTADA  BIT = 0,
    @USUARIO  INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
    DECLARE @CLIENTE INT, @NOW DATETIME
    SELECT @CLIENTE = act_cliente FROM [dbo].[Activo] WHERE act_id = @ACTIVO
    IF @CLIENTE IS NULL BEGIN RAISERROR('1.- EL ACTIVO NO EXISTE.', 16, 1) RETURN -1 END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo] WHERE arc_id = @ARCHIVO AND arc_cliente = @CLIENTE)
    BEGIN RAISERROR('2.- LA FOTO NO EXISTE.', 16, 1) RETURN -1 END
    SET @NOW = [dbo].[FNC_PAIS_HORA]((SELECT cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE))

    DECLARE @HAY BIT = CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Archivo_Vinculo]
                                         WHERE avi_activo = @ACTIVO AND avi_es_referencia = 1 AND avi_habilitado = 1) THEN 1 ELSE 0 END
    DECLARE @ES_PORTADA BIT = CASE WHEN @HAY = 0 OR ISNULL(@PORTADA, 0) = 1 THEN 1 ELSE 0 END

    BEGIN TRANSACTION
        IF @ES_PORTADA = 1
            UPDATE [dbo].[Archivo_Vinculo]
            SET    avi_es_referencia = 0, avi_es_foto = 1, avi_usuario_actualizacion = @USUARIO, avi_fecha_actualizacion = @NOW
            WHERE  avi_activo = @ACTIVO AND avi_es_referencia = 1 AND avi_habilitado = 1

        INSERT [dbo].[Archivo_Vinculo] (avi_archivo, avi_activo, avi_es_referencia, avi_es_foto, avi_orden,
                                        avi_usuario_creacion, avi_fecha_creacion, avi_habilitado)
        VALUES (@ARCHIVO, @ACTIVO, @ES_PORTADA, CASE WHEN @ES_PORTADA = 1 THEN 0 ELSE 1 END,
                (SELECT ISNULL(MAX(avi_orden), 0) + 1 FROM [dbo].[Archivo_Vinculo] WHERE avi_activo = @ACTIVO),
                @USUARIO, @NOW, 1)
        SET @ID = SCOPE_IDENTITY()
    COMMIT TRANSACTION
RETURN 0
GO

-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  05-10-2026
-- DESCRIPTION:     DEJA UNA FOTO DEL ACTIVO COMO SU PORTADA (UNA SOLA)
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO_PORTADA]
    @ACTIVO   INT,
    @ARCHIVO  INT,
    @USUARIO  INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Vinculo] WHERE avi_activo = @ACTIVO AND avi_archivo = @ARCHIVO
                   AND avi_habilitado = 1 AND (avi_es_referencia = 1 OR avi_es_foto = 1))
    BEGIN RAISERROR('1.- ESA FOTO NO ES DE ESTE ACTIVO.', 16, 1) RETURN -1 END
    DECLARE @NOW DATETIME = [dbo].[FNC_PAIS_HORA]((SELECT c.cli_pais FROM [dbo].[Activo] a JOIN [dbo].[Cliente] c ON c.cli_id = a.act_cliente WHERE a.act_id = @ACTIVO))
    BEGIN TRANSACTION
        UPDATE [dbo].[Archivo_Vinculo]
        SET    avi_es_referencia = CASE WHEN avi_archivo = @ARCHIVO THEN 1 ELSE 0 END,
               avi_es_foto       = CASE WHEN avi_archivo = @ARCHIVO THEN 0 ELSE 1 END,
               avi_usuario_actualizacion = @USUARIO, avi_fecha_actualizacion = @NOW
        WHERE  avi_activo = @ACTIVO AND avi_habilitado = 1 AND (avi_es_referencia = 1 OR avi_es_foto = 1)
    COMMIT TRANSACTION
RETURN 0
GO

-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  05-10-2026
-- DESCRIPTION:     QUITA UNA FOTO DEL ACTIVO (APAGA EL VINCULO, EL ARCHIVO
--                  QUEDA). SI ERA LA PORTADA, LA SIGUIENTE PASA A PORTADA
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[DEL_ACTIVO_FOTO]
    @ACTIVO   INT,
    @ARCHIVO  INT,
    @USUARIO  INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
    DECLARE @NOW DATETIME = [dbo].[FNC_PAIS_HORA]((SELECT c.cli_pais FROM [dbo].[Activo] a JOIN [dbo].[Cliente] c ON c.cli_id = a.act_cliente WHERE a.act_id = @ACTIVO))
    DECLARE @ERA BIT = (SELECT MAX(CAST(avi_es_referencia AS INT)) FROM [dbo].[Archivo_Vinculo]
                        WHERE avi_activo = @ACTIVO AND avi_archivo = @ARCHIVO AND avi_habilitado = 1)
    BEGIN TRANSACTION
        UPDATE [dbo].[Archivo_Vinculo]
        SET    avi_habilitado = 0, avi_usuario_actualizacion = @USUARIO, avi_fecha_actualizacion = @NOW
        WHERE  avi_activo = @ACTIVO AND avi_archivo = @ARCHIVO AND avi_habilitado = 1 AND (avi_es_referencia = 1 OR avi_es_foto = 1)

        IF ISNULL(@ERA, 0) = 1
            UPDATE TOP (1) [dbo].[Archivo_Vinculo]
            SET    avi_es_referencia = 1, avi_es_foto = 0
            WHERE  avi_id = (SELECT TOP 1 avi_id FROM [dbo].[Archivo_Vinculo]
                             WHERE avi_activo = @ACTIVO AND avi_es_foto = 1 AND avi_habilitado = 1
                             ORDER BY ISNULL(avi_orden, 0), avi_id)
    COMMIT TRANSACTION
RETURN 0
GO

-- La ficha sigue llamando a VIN/DEL_ACTIVO_IMAGEN: ahora la imagen nueva queda
-- de portada SIN borrar las demas, y quitar la imagen quita solo la portada.
CREATE OR ALTER PROCEDURE [dbo].[VIN_ACTIVO_IMAGEN]
@ID       INT = NULL OUTPUT,
@ACTIVO   INT,
@ARCHIVO  INT,
@USUARIO  INT
AS
SET NOCOUNT ON
    EXEC [dbo].[INS_ACTIVO_FOTO] @ID = @ID OUTPUT, @ACTIVO = @ACTIVO, @ARCHIVO = @ARCHIVO, @PORTADA = 1, @USUARIO = @USUARIO
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[DEL_ACTIVO_IMAGEN]
@ACTIVO   INT,
@USUARIO  INT
AS
SET NOCOUNT ON
    DECLARE @ARCHIVO INT = (SELECT TOP 1 avi_archivo FROM [dbo].[Archivo_Vinculo]
                            WHERE avi_activo = @ACTIVO AND avi_es_referencia = 1 AND avi_habilitado = 1)
    IF @ARCHIVO IS NOT NULL
        EXEC [dbo].[DEL_ACTIVO_FOTO] @ACTIVO = @ACTIVO, @ARCHIVO = @ARCHIVO, @USUARIO = @USUARIO
RETURN 0
GO

-- Los documentos del activo no incluyen sus fotos.
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_ARCHIVO]
@ACTIVO INT, @CLIENTE INT
AS
SET NOCOUNT ON
    SELECT  a.arc_id              AS ARC_ID,
            a.arc_nombre_original AS ARC_NOMBRE,
            a.arc_mime            AS ARC_MIME,
            v.avi_fecha_creacion  AS FECHA
    FROM    [dbo].[Archivo_Vinculo] v
    INNER JOIN [dbo].[Archivo] a ON a.arc_id = v.avi_archivo
    WHERE   v.avi_activo = @ACTIVO
      AND   v.avi_es_referencia = 0        -- 1 = portada; 0 = documentos
      AND   v.avi_es_foto = 0              -- las fotos de la galeria no son documentos
      AND   v.avi_habilitado = 1
      AND   a.arc_habilitado = 1
      AND   a.arc_cliente = @CLIENTE
    ORDER BY v.avi_fecha_creacion DESC, a.arc_id DESC
GO

-- ---------------------------------------------------------------------------
-- 2) Lugares: tipos propios, crear, renombrar, ordenar y quitar
-- ---------------------------------------------------------------------------
-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  05-10-2026
-- DESCRIPTION:     BUSCA O CREA UN TIPO DE LUGAR DE LA EMPRESA (SINGULAR Y PLURAL)
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPS_LUGAR_TIPO]
    @ID       INT = NULL OUTPUT,
    @CLIENTE  INT,
    @SINGULAR NVARCHAR(100),
    @PLURAL   NVARCHAR(100) = NULL
AS
SET NOCOUNT ON
    SET @SINGULAR = NULLIF(LTRIM(RTRIM(@SINGULAR)), N'')
    IF @SINGULAR IS NULL BEGIN RAISERROR('1.- ESCRIBA EL NOMBRE DEL TIPO DE LUGAR.', 16, 1) RETURN -1 END
    SELECT TOP 1 @ID = iat_id FROM [dbo].[Instalacion_Area_Tipo]
    WHERE  (iat_cliente IS NULL OR iat_cliente = @CLIENTE)
      AND  iat_nombre COLLATE Latin1_General_CI_AI = @SINGULAR COLLATE Latin1_General_CI_AI
    ORDER BY CASE WHEN iat_cliente IS NULL THEN 0 ELSE 1 END
    IF @ID IS NOT NULL
    BEGIN
        IF NULLIF(@PLURAL, N'') IS NOT NULL
            UPDATE [dbo].[Instalacion_Area_Tipo] SET iat_plural = @PLURAL WHERE iat_id = @ID AND iat_cliente = @CLIENTE
        RETURN 0
    END
    DECLARE @COD NVARCHAR(50) = LEFT(UPPER(@SINGULAR), 38) + N'-' + LTRIM(@CLIENTE), @N INT = 1
    WHILE EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area_Tipo] WHERE iat_codigo = @COD)
    BEGIN SET @N += 1; SET @COD = LEFT(UPPER(@SINGULAR), 34) + N'-' + LTRIM(@CLIENTE) + N'-' + LTRIM(@N) END
    INSERT INTO [dbo].[Instalacion_Area_Tipo] (iat_codigo, iat_nombre, iat_orden, iat_habilitado, iat_cliente, iat_plural)
    VALUES (@COD, @SINGULAR, 100, 1, @CLIENTE, ISNULL(NULLIF(@PLURAL, N''), @SINGULAR + N's'))
    SET @ID = SCOPE_IDENTITY()
RETURN 0
GO

-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  05-10-2026
-- DESCRIPTION:     CREA O RENOMBRA UN LUGAR (HASTA 5 NIVELES). EL CODIGO
--                  SE ARMA SOLO. @ORDEN NULL = AL FINAL DE SUS HERMANOS
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPS_LUGAR]
    @ID       INT = NULL OUTPUT,
    @CLIENTE  INT,
    @PLANTA   INT,
    @PADRE    INT = NULL,
    @TIPO     INT,
    @NOMBRE   NVARCHAR(200),
    @USUARIO  INT
AS
SET NOCOUNT ON
    SET @NOMBRE = NULLIF(LTRIM(RTRIM(@NOMBRE)), N'')
    IF @NOMBRE IS NULL BEGIN RAISERROR('1.- ESCRIBA EL NOMBRE DEL LUGAR.', 16, 1) RETURN -1 END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion] WHERE cin_id = @PLANTA AND cin_cliente = @CLIENTE)
    BEGIN RAISERROR('2.- LA PLANTA NO EXISTE.', 16, 1) RETURN -1 END
    IF @PADRE IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area] WHERE iar_id = @PADRE AND iar_cliente = @CLIENTE AND iar_habilitado = 1)
    BEGIN RAISERROR('3.- EL LUGAR DE ARRIBA NO EXISTE.', 16, 1) RETURN -1 END

    IF ISNULL(@ID, 0) > 0
    BEGIN
        UPDATE [dbo].[Instalacion_Area]
        SET    iar_nombre = @NOMBRE, iar_instalacion_area_tipo = ISNULL(@TIPO, iar_instalacion_area_tipo),
               iar_usuario_actualizacion = @USUARIO, iar_fecha_actualizacion = GETDATE()
        WHERE  iar_id = @ID AND iar_cliente = @CLIENTE
        RETURN 0
    END

    -- tope de 5 niveles
    DECLARE @NIVEL INT = 1, @P INT = @PADRE
    WHILE @P IS NOT NULL BEGIN SET @NIVEL += 1; SELECT @P = iar_area_padre FROM [dbo].[Instalacion_Area] WHERE iar_id = @P END
    IF @NIVEL > 5 BEGIN RAISERROR('4.- UN LUGAR SE PUEDE DIVIDIR HASTA EN 5 NIVELES.', 16, 1) RETURN -1 END

    DECLARE @COD NVARCHAR(50) = N'LUG-' + LTRIM(ABS(CHECKSUM(NEWID())) % 1000000)
    WHILE EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area] WHERE iar_cliente = @CLIENTE AND iar_codigo = @COD)
        SET @COD = N'LUG-' + LTRIM(ABS(CHECKSUM(NEWID())) % 1000000)

    INSERT INTO [dbo].[Instalacion_Area] (iar_cliente, iar_cliente_instalacion, iar_area_padre, iar_instalacion_area_tipo, iar_codigo, iar_nombre,
                                          iar_orden, iar_usuario_creacion, iar_fecha_creacion, iar_habilitado)
    VALUES (@CLIENTE, @PLANTA, @PADRE, @TIPO, @COD, @NOMBRE,
            (SELECT ISNULL(MAX(iar_orden), 0) + 1 FROM [dbo].[Instalacion_Area]
             WHERE iar_cliente_instalacion = @PLANTA AND ISNULL(iar_area_padre, 0) = ISNULL(@PADRE, 0) AND iar_habilitado = 1),
            @USUARIO, GETDATE(), 1)
    SET @ID = SCOPE_IDENTITY()
RETURN 0
GO

-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  05-10-2026
-- DESCRIPTION:     SUBE O BAJA UN LUGAR ENTRE SUS HERMANOS (@DELTA -1 / +1)
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPD_LUGAR_ORDEN]
    @ID      INT,
    @CLIENTE INT,
    @DELTA   INT
AS
SET NOCOUNT ON
    DECLARE @PLANTA INT, @PADRE INT
    SELECT @PLANTA = iar_cliente_instalacion, @PADRE = iar_area_padre FROM [dbo].[Instalacion_Area] WHERE iar_id = @ID AND iar_cliente = @CLIENTE
    IF @PLANTA IS NULL RETURN 0
    ;WITH h AS (SELECT iar_id, ROW_NUMBER() OVER (ORDER BY ISNULL(iar_orden, 999), iar_nombre) AS n
                FROM [dbo].[Instalacion_Area]
                WHERE iar_cliente_instalacion = @PLANTA AND ISNULL(iar_area_padre, 0) = ISNULL(@PADRE, 0) AND iar_habilitado = 1)
    UPDATE a SET iar_orden = h.n * 10 FROM [dbo].[Instalacion_Area] a JOIN h ON h.iar_id = a.iar_id
    UPDATE [dbo].[Instalacion_Area] SET iar_orden = iar_orden + (CASE WHEN @DELTA < 0 THEN -15 ELSE 15 END) WHERE iar_id = @ID
    ;WITH h AS (SELECT iar_id, ROW_NUMBER() OVER (ORDER BY iar_orden, iar_nombre) AS n
                FROM [dbo].[Instalacion_Area]
                WHERE iar_cliente_instalacion = @PLANTA AND ISNULL(iar_area_padre, 0) = ISNULL(@PADRE, 0) AND iar_habilitado = 1)
    UPDATE a SET iar_orden = h.n FROM [dbo].[Instalacion_Area] a JOIN h ON h.iar_id = a.iar_id
RETURN 0
GO

-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  05-10-2026
-- DESCRIPTION:     QUITA UN LUGAR Y TODO LO QUE TIENE ADENTRO (mnu: nunca se
--                  borra, se deshabilita). SUS ACTIVOS QUEDAN «POR UBICAR»
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[DEL_LUGAR]
    @ID       INT,
    @CLIENTE  INT,
    @USUARIO  INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
    DECLARE @L TABLE (id INT PRIMARY KEY)
    ;WITH r AS (SELECT iar_id FROM [dbo].[Instalacion_Area] WHERE iar_id = @ID AND iar_cliente = @CLIENTE
                UNION ALL
                SELECT h.iar_id FROM [dbo].[Instalacion_Area] h JOIN r ON h.iar_area_padre = r.iar_id)
    INSERT INTO @L SELECT iar_id FROM r
    BEGIN TRANSACTION
        UPDATE [dbo].[Activo] SET act_instalacion_area = NULL, act_orden_area = NULL
        WHERE  act_cliente = @CLIENTE AND act_instalacion_area IN (SELECT id FROM @L)
        UPDATE [dbo].[Instalacion_Area] SET iar_habilitado = 0, iar_usuario_actualizacion = @USUARIO, iar_fecha_actualizacion = GETDATE()
        WHERE  iar_id IN (SELECT id FROM @L)
    COMMIT TRANSACTION
RETURN 0
GO

-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  05-10-2026
-- DESCRIPTION:     DEJA UN ACTIVO EN UN LUGAR (NULL = POR UBICAR) Y EN UNA
--                  POSICION DENTRO DE ESE LUGAR; REORDENA A LOS DEMAS
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO_UBICACION]
    @ACTIVO   INT,
    @CLIENTE  INT,
    @AREA     INT = NULL,
    @POSICION INT = NULL,
    @USUARIO  INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE)
    BEGIN RAISERROR('1.- EL ACTIVO NO EXISTE.', 16, 1) RETURN -1 END
    IF @AREA IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area] WHERE iar_id = @AREA AND iar_cliente = @CLIENTE AND iar_habilitado = 1)
    BEGIN RAISERROR('2.- EL LUGAR NO EXISTE.', 16, 1) RETURN -1 END
    BEGIN TRANSACTION
        UPDATE [dbo].[Activo]
        SET    act_instalacion_area = @AREA, act_orden_area = NULL,
               act_cliente_instalacion = ISNULL((SELECT iar_cliente_instalacion FROM [dbo].[Instalacion_Area] WHERE iar_id = @AREA), act_cliente_instalacion),
               act_usuario_actualizacion = @USUARIO, act_fecha_actualizacion = GETDATE()
        WHERE  act_id = @ACTIVO
        IF @AREA IS NOT NULL
        BEGIN
            ;WITH o AS (SELECT act_id, ROW_NUMBER() OVER (ORDER BY ISNULL(act_orden_area, 9999), act_nombre) AS n
                        FROM [dbo].[Activo] WHERE act_instalacion_area = @AREA AND act_id <> @ACTIVO AND act_habilitado = 1)
            UPDATE a SET act_orden_area = CASE WHEN o.n >= ISNULL(@POSICION, 9999) + 1 THEN o.n + 1 ELSE o.n END
            FROM [dbo].[Activo] a JOIN o ON o.act_id = a.act_id
            UPDATE [dbo].[Activo] SET act_orden_area = CASE WHEN @POSICION IS NULL THEN 9999 ELSE @POSICION + 1 END WHERE act_id = @ACTIVO
        END
    COMMIT TRANSACTION
RETURN 0
GO

-- ---------------------------------------------------------------------------
-- 3) La planta en una lectura
-- ---------------------------------------------------------------------------
-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  05-10-2026
-- DESCRIPTION:     SELECT PLANTA: 1 TIPOS DE LUGAR, 2 LUGARES, 3 ACTIVOS,
--                  4 COMPONENTES, 5 REPUESTOS QUE LES SIRVEN CON STOCK,
--                  6 CUANTAS FOTOS TIENE CADA ACTIVO
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_PLANTA]
    @CLIENTE INT,
    @PLANTA  INT
AS
SET NOCOUNT ON
    -- 1. tipos de lugar (comunes y de la empresa)
    SELECT iat_id AS ID, iat_nombre AS SINGULAR, ISNULL(iat_plural, iat_nombre + N's') AS PLURAL, iat_cliente AS CLIENTE
    FROM   [dbo].[Instalacion_Area_Tipo]
    WHERE  iat_habilitado = 1 AND (iat_cliente IS NULL OR iat_cliente = @CLIENTE)
    ORDER BY ISNULL(iat_orden, 100), iat_nombre

    -- 2. lugares de la planta
    SELECT iar_id AS ID, iar_area_padre AS PADRE, ISNULL(iar_instalacion_area_tipo, 1) AS TIPO, iar_nombre AS NOMBRE, ISNULL(iar_orden, 999) AS ORDEN
    FROM   [dbo].[Instalacion_Area]
    WHERE  iar_cliente = @CLIENTE AND iar_cliente_instalacion = @PLANTA AND iar_habilitado = 1
    ORDER BY ISNULL(iar_area_padre, 0), ISNULL(iar_orden, 999), iar_nombre

    -- 3. activos de la planta
    SELECT a.act_id AS ID, a.act_activo_padre AS PADRE, a.act_codigo AS CODIGO, a.act_nombre AS NOMBRE,
           ISNULL(t.ati_nombre, N'') AS TIPO, a.act_activo_tipo AS TIPO_ID,
           ISNULL(e.aes_nombre, N'') AS ESTADO, ISNULL(e.aes_codigo, N'') AS ESTADO_CODIGO,
           ISNULL(c.crn_nombre, N'') AS CRITICIDAD,
           a.act_instalacion_area AS AREA, a.act_orden_area AS ORDEN,
           ISNULL(m.amo_nombre, N'') AS MODELO,
           (SELECT TOP 1 v.avi_archivo FROM [dbo].[Archivo_Vinculo] v JOIN [dbo].[Archivo] f ON f.arc_id = v.avi_archivo AND f.arc_habilitado = 1
            WHERE v.avi_activo = a.act_id AND v.avi_es_referencia = 1 AND v.avi_habilitado = 1 ORDER BY ISNULL(v.avi_orden, 0), v.avi_id) AS PORTADA
    FROM   [dbo].[Activo] a
    LEFT JOIN [dbo].[Activo_Tipo] t ON t.ati_id = a.act_activo_tipo
    LEFT JOIN [dbo].[Activo_Estado] e ON e.aes_id = a.act_activo_estado
    LEFT JOIN [dbo].[Criticidad_Nivel] c ON c.crn_id = a.act_criticidad_nivel
    LEFT JOIN [dbo].[Activo_Modelo] m ON m.amo_id = a.act_activo_modelo
    WHERE  a.act_cliente = @CLIENTE AND a.act_cliente_instalacion = @PLANTA AND a.act_habilitado = 1 AND a.act_fusionado_en IS NULL
    ORDER BY ISNULL(a.act_orden_area, 9999), a.act_nombre

    -- 4. componentes de esos activos
    SELECT k.aco_id AS ID, k.aco_activo AS ACTIVO, k.aco_componente_padre AS PADRE, k.aco_codigo AS CODIGO, k.aco_nombre AS NOMBRE,
           ISNULL(ct.cto_nombre, N'') AS TIPO, ISNULL(cp.cpn_nombre, N'') AS LADO,
           ISNULL(ce.ace_nombre, N'') AS ESTADO, ISNULL(ce.ace_codigo, N'') AS ESTADO_CODIGO, k.aco_descripcion AS MOTIVO
    FROM   [dbo].[Activo_Componente] k
    JOIN   [dbo].[Activo] a ON a.act_id = k.aco_activo AND a.act_cliente = @CLIENTE AND a.act_cliente_instalacion = @PLANTA AND a.act_habilitado = 1
    LEFT JOIN [dbo].[Componente_Tipo] ct ON ct.cto_id = k.aco_componente_tipo
    LEFT JOIN [dbo].[Componente_Posicion] cp ON cp.cpn_id = k.aco_componente_posicion
    LEFT JOIN [dbo].[Activo_Componente_Estado] ce ON ce.ace_id = k.aco_activo_componente_estado
    WHERE  k.aco_cliente = @CLIENTE AND k.aco_habilitado = 1 AND k.aco_fusionado_en IS NULL
    ORDER BY k.aco_activo, k.aco_nombre

    -- 5. repuestos que les sirven (por tipo, modelo o componente), con stock
    ;WITH comp AS (
        SELECT DISTINCT a.act_id AS ACTIVO, rc.rco_repuesto AS REP, k.aco_id AS PARA_ID, k.aco_nombre AS PARA
        FROM   [dbo].[Activo] a
        JOIN   [dbo].[Repuesto_Compatibilidad] rc
               ON rc.rco_activo_tipo = a.act_activo_tipo
               OR (a.act_activo_modelo IS NOT NULL AND rc.rco_activo_modelo = a.act_activo_modelo)
               OR rc.rco_activo_componente IN (SELECT x.aco_id FROM [dbo].[Activo_Componente] x WHERE x.aco_activo = a.act_id)
        LEFT JOIN [dbo].[Activo_Componente] k ON k.aco_id = rc.rco_activo_componente AND k.aco_activo = a.act_id
        WHERE  a.act_cliente = @CLIENTE AND a.act_cliente_instalacion = @PLANTA AND a.act_habilitado = 1)
    SELECT c.ACTIVO, r.rep_id AS ID, r.rep_codigo AS CODIGO, r.rep_nombre AS NOMBRE,
           ISNULL((SELECT SUM(s.isa_cantidad) FROM [dbo].[Inventario_Saldo] s WHERE s.isa_repuesto = r.rep_id), 0) AS EXISTENCIA,
           ISNULL((SELECT SUM(u.rbs_stock_minimo) FROM [dbo].[Repuesto_Bodega_Stock] u WHERE u.rbs_repuesto = r.rep_id), 0) AS MINIMO,
           ISNULL(MAX(um.ume_simbolo), N'') AS UNIDAD, MAX(c.PARA_ID) AS PARA_ID, MAX(c.PARA) AS PARA
    FROM   comp c
    JOIN   [dbo].[Repuesto] r ON r.rep_id = c.REP AND r.rep_cliente = @CLIENTE AND r.rep_habilitado = 1
    LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = r.rep_unidad_medida
    GROUP BY c.ACTIVO, r.rep_id, r.rep_codigo, r.rep_nombre
    ORDER BY c.ACTIVO, r.rep_nombre

    -- 6. cuantas fotos tiene cada activo
    SELECT v.avi_activo AS ACTIVO, COUNT(*) AS FOTOS
    FROM   [dbo].[Archivo_Vinculo] v
    JOIN   [dbo].[Activo] a ON a.act_id = v.avi_activo AND a.act_cliente = @CLIENTE AND a.act_cliente_instalacion = @PLANTA
    WHERE  v.avi_habilitado = 1 AND (v.avi_es_referencia = 1 OR v.avi_es_foto = 1)
    GROUP BY v.avi_activo
GO

EXEC [dbo].[SEL_ACTIVO_PLANTA] @CLIENTE = 1, @PLANTA = 1
GO
