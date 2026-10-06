USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     NIVELES POR RACK Y SIGUIENTE CODIGO DE RACK (MAPA POR UBICACION DINAMICO).
-- =============================================
-- POR QUE
--   El mapa por ubicacion del Centro de repuestos deja crear racks y niveles al
--   momento: antes un rack tenia siempre 4 niveles (la altura del mapa 3D) y
--   el codigo habia que escribirlo a mano.
--
--   bub_niveles: cuantos niveles tiene el rack (1 a 10; NULL = los 4 de siempre).
--   El planograma (Bodega_Ubicacion_Posicion) ya admitia hasta 10 niveles.
--   SEL_RACK_SIGUIENTE da el codigo con la misma regla de la carga masiva y del
--   mapa 3D: <prefijo>-<pasillo>-R<nn>, desde el siguiente numero libre del pasillo.
-- TODO IDEMPOTENTE.
-- =============================================

IF COL_LENGTH('dbo.Bodega_Ubicacion', 'bub_niveles') IS NULL
    ALTER TABLE [dbo].[Bodega_Ubicacion] ADD bub_niveles TINYINT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_BUB_NIVELES')
    ALTER TABLE [dbo].[Bodega_Ubicacion] ADD CONSTRAINT CK_BUB_NIVELES CHECK (bub_niveles IS NULL OR bub_niveles BETWEEN 1 AND 10)
GO

/* Los niveles de cada rack de la planta (o de todas). */
CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_UBICACION_NIVELES]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
SELECT  u.bub_id AS BUB_ID, CAST(ISNULL(u.bub_niveles, 4) AS INT) AS NIVELES
FROM    [dbo].[Bodega_Ubicacion] u
JOIN    [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
WHERE   b.bod_cliente = @CLIENTE
  AND   (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
GO

/* Cambia los niveles de un rack. No deja quitar niveles que tengan repuestos ubicados. */
CREATE OR ALTER PROCEDURE [dbo].[UPD_UBICACION_NIVELES]
    @CLIENTE   INT,
    @UBICACION INT,
    @NIVELES   INT,
    @USUARIO   INT
AS
SET NOCOUNT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion] u JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
               WHERE u.bub_id = @UBICACION AND b.bod_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA UBICACION NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF @NIVELES IS NULL OR @NIVELES < 1 OR @NIVELES > 10
BEGIN
    RAISERROR('2.- UN RACK TIENE DE 1 A 10 NIVELES.', 16, 1)
    RETURN -1
END
IF EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion_Posicion] WHERE bup_ubicacion = @UBICACION AND bup_nivel > @NIVELES)
BEGIN
    RAISERROR('3.- HAY REPUESTOS UBICADOS EN LOS NIVELES QUE SE QUIEREN QUITAR: MUEVELOS ANTES.', 16, 1)
    RETURN -1
END
UPDATE [dbo].[Bodega_Ubicacion]
   SET bub_niveles = @NIVELES, bub_usuario_actualizacion = @USUARIO, bub_fecha_actualizacion = [dbo].[FNC_AHORA]()
 WHERE bub_id = @UBICACION
SELECT @UBICACION AS ID, '200' AS CODE, 'Niveles guardados.' AS MENSAJE
GO

/* El siguiente rack libre del pasillo: codigo, nombre y numero. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_RACK_SIGUIENTE]
    @CLIENTE INT,
    @BODEGA  INT,
    @PASILLO NVARCHAR(10)
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
    RAISERROR('2.- EL PASILLO SON DE 1 A 3 LETRAS (A, B, AB).', 16, 1)
    RETURN -1
END
DECLARE @PRE NVARCHAR(200) = [dbo].[FNC_BODEGA_PREFIJO_RACK](@BODEGA)
DECLARE @N INT = ISNULL((SELECT MAX([dbo].[FNC_RACK_NUMERO](u.bub_codigo)) FROM [dbo].[Bodega_Ubicacion] u
                         WHERE u.bub_bodega = @BODEGA AND [dbo].[FNC_RACK_PASILLO](u.bub_codigo) = @PASILLO), 0) + 1
DECLARE @NN NVARCHAR(10) = RIGHT(N'0' + CAST(@N AS NVARCHAR(10)), CASE WHEN @N < 100 THEN 2 ELSE 3 END)
SELECT @PRE + N'-' + @PASILLO + N'-R' + @NN AS CODIGO,
       N'Pasillo ' + @PASILLO + N' · Rack ' + @NN AS NOMBRE,
       @N AS NUMERO
GO

PRINT '372_RACK_NIVELES aplicado.'
GO
