USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     TIPOS DE AREA DE LA BODEGA (PASILLO, SALA, ZONA...) PARA QUE LA PALABRA «PASILLO» SEA DINAMICA.
-- =============================================
-- POR QUE
--   Una bodega no siempre se ordena en pasillos: hay salas, zonas, naves, camaras. El
--   «pasillo» del codigo de rack (PREFIJO-A-R01) pasa a llamarse AREA y cada rack dice de
--   que TIPO de area es. El catalogo es por cliente (y trae unos globales de partida); se
--   crean nuevos desde el combo de SIGMA («Crear "Sala fria"»). El codigo del rack no cambia:
--   solo la etiqueta y el nombre («Sala A · Rack 01»).
--
--   Bodega_Area_Tipo ............ catalogo (bat_cliente NULL = global).
--   Bodega_Ubicacion.bub_area_tipo  tipo de area de cada rack (NULL = Pasillo).
-- TODO IDEMPOTENTE.
-- =============================================

IF OBJECT_ID('dbo.Bodega_Area_Tipo', 'U') IS NULL
CREATE TABLE [dbo].[Bodega_Area_Tipo](
    bat_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Bodega_Area_Tipo PRIMARY KEY,
    bat_cliente    INT NULL,
    bat_nombre     NVARCHAR(60) NOT NULL,
    bat_habilitado BIT NOT NULL CONSTRAINT DF_BAT_HAB DEFAULT 1
)
GO
IF COL_LENGTH('dbo.Bodega_Ubicacion', 'bub_area_tipo') IS NULL
    ALTER TABLE [dbo].[Bodega_Ubicacion] ADD bub_area_tipo INT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_BUB_AREA_TIPO')
    ALTER TABLE [dbo].[Bodega_Ubicacion] ADD CONSTRAINT FK_BUB_AREA_TIPO FOREIGN KEY (bub_area_tipo) REFERENCES [dbo].[Bodega_Area_Tipo](bat_id)
GO

INSERT INTO [dbo].[Bodega_Area_Tipo] (bat_cliente, bat_nombre)
SELECT NULL, v.n FROM (VALUES (N'Pasillo'), (N'Sala'), (N'Zona'), (N'Sector'), (N'Nave'), (N'Patio'), (N'Cámara')) v (n)
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Bodega_Area_Tipo] t WHERE t.bat_cliente IS NULL AND t.bat_nombre = v.n)
GO

/* El catalogo visible para un cliente: los globales y los suyos. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_AREA_TIPOS]
    @CLIENTE INT
AS
SET NOCOUNT ON
SELECT t.bat_id AS ID, t.bat_nombre AS NOMBRE
FROM   [dbo].[Bodega_Area_Tipo] t
WHERE  t.bat_habilitado = 1 AND (t.bat_cliente IS NULL OR t.bat_cliente = @CLIENTE)
ORDER BY CASE WHEN t.bat_nombre = N'Pasillo' THEN 0 ELSE 1 END, t.bat_nombre
GO

/* Crea el tipo si no existe (sin distinguir mayusculas) y devuelve su id. */
CREATE OR ALTER PROCEDURE [dbo].[INS_AREA_TIPO]
    @CLIENTE INT,
    @NOMBRE  NVARCHAR(60)
AS
SET NOCOUNT ON
SET @NOMBRE = LTRIM(RTRIM(ISNULL(@NOMBRE, N'')))
IF LEN(@NOMBRE) = 0
BEGIN
    RAISERROR('1.- ESCRIBA EL TIPO DE AREA (PASILLO, SALA, ZONA...).', 16, 1)
    RETURN -1
END
DECLARE @ID INT = (SELECT TOP 1 bat_id FROM [dbo].[Bodega_Area_Tipo]
                    WHERE bat_nombre = @NOMBRE AND (bat_cliente IS NULL OR bat_cliente = @CLIENTE) ORDER BY bat_cliente DESC)
IF @ID IS NULL
BEGIN
    INSERT INTO [dbo].[Bodega_Area_Tipo] (bat_cliente, bat_nombre) VALUES (@CLIENTE, @NOMBRE)
    SET @ID = SCOPE_IDENTITY()
END
SELECT @ID AS ID, @NOMBRE AS NOMBRE
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_UBICACION_AREA_TIPO]
    @CLIENTE   INT,
    @UBICACION INT,
    @TIPO      INT
AS
SET NOCOUNT ON
UPDATE u SET bub_area_tipo = @TIPO
FROM   [dbo].[Bodega_Ubicacion] u JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
WHERE  u.bub_id = @UBICACION AND b.bod_cliente = @CLIENTE
GO

/* Niveles y tipo de area de cada rack. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_UBICACION_NIVELES]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
SELECT  u.bub_id AS BUB_ID, CAST(ISNULL(u.bub_niveles, 4) AS INT) AS NIVELES, ISNULL(t.bat_nombre, N'Pasillo') AS AREA_TIPO
FROM    [dbo].[Bodega_Ubicacion] u
JOIN    [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
LEFT JOIN [dbo].[Bodega_Area_Tipo] t ON t.bat_id = u.bub_area_tipo
WHERE   b.bod_cliente = @CLIENTE
  AND   (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
GO

/* El siguiente rack libre del area: codigo, nombre (con el tipo de area) y numero. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_RACK_SIGUIENTE]
    @CLIENTE INT,
    @BODEGA  INT,
    @PASILLO NVARCHAR(10),
    @TIPO    NVARCHAR(60) = N'Pasillo'
AS
SET NOCOUNT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega] WHERE bod_id = @BODEGA AND bod_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA BODEGA NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END
SET @PASILLO = UPPER(LTRIM(RTRIM(ISNULL(@PASILLO, N''))))
IF LEN(@PASILLO) NOT BETWEEN 1 AND 3 OR @PASILLO LIKE N'%[^A-Z]%'
BEGIN
    RAISERROR('2.- EL CODIGO DEL AREA SON DE 1 A 3 LETRAS (A, B, AB).', 16, 1)
    RETURN -1
END
SET @TIPO = LTRIM(RTRIM(ISNULL(NULLIF(@TIPO, N''), N'Pasillo')))
DECLARE @PRE NVARCHAR(200) = [dbo].[FNC_BODEGA_PREFIJO_RACK](@BODEGA)
DECLARE @N INT = ISNULL((SELECT MAX([dbo].[FNC_RACK_NUMERO](u.bub_codigo)) FROM [dbo].[Bodega_Ubicacion] u
                         WHERE u.bub_bodega = @BODEGA AND [dbo].[FNC_RACK_PASILLO](u.bub_codigo) = @PASILLO), 0) + 1
DECLARE @NN NVARCHAR(10) = RIGHT(N'0' + CAST(@N AS NVARCHAR(10)), CASE WHEN @N < 100 THEN 2 ELSE 3 END)
SELECT @PRE + N'-' + @PASILLO + N'-R' + @NN AS CODIGO,
       @TIPO + N' ' + @PASILLO + N' · Rack ' + @NN AS NOMBRE,
       @N AS NUMERO
GO

PRINT '375_BODEGA_AREA_TIPO aplicado.'
GO
