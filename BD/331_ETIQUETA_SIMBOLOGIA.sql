/* ============================================================================
   SIGMA - Bloque 331
   SIMBOLOGIA DE LAS ETIQUETAS: QR o codigo de barras
   ----------------------------------------------------------------------------

   Hasta aqui toda etiqueta llevaba un QR. Hay bodegas que ya trabajan con
   pistolas lectoras lineales (solo leen barras) y otras con el telefono
   (lee los dos). La empresa elige: la hoja de impresion la ofrece en cada
   tirada y lo elegido queda como predeterminado del cliente, que es tambien
   lo que dibuja el mapa 3D en las cajas y en las vigas.

   El contenido no cambia: es el mismo token (REP-17, UBI-4, BOD-1) en QR o
   en Code 128, asi que las etiquetas ya pegadas siguen sirviendo y
   Interpretar() no distingue de donde vino.

     Cliente.cli_etiqueta_simbolo   'QR' (por defecto) | 'BARRAS'
     SEL_CLIENTE_ETIQUETA_SIMBOLO
     UPD_CLIENTE_ETIQUETA_SIMBOLO
   ============================================================================ */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF COL_LENGTH('dbo.Cliente', 'cli_etiqueta_simbolo') IS NULL
BEGIN
    ALTER TABLE [dbo].[Cliente] ADD [cli_etiqueta_simbolo] VARCHAR(6) NOT NULL
        CONSTRAINT [DF_Cliente_etiqueta_simbolo] DEFAULT ('QR')
        CONSTRAINT [CK_Cliente_etiqueta_simbolo] CHECK ([cli_etiqueta_simbolo] IN ('QR', 'BARRAS'))
END
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_ETIQUETA_SIMBOLO]
    @CLIENTE INT
AS
SET NOCOUNT ON
    SELECT ISNULL((SELECT cli_etiqueta_simbolo FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE), 'QR') AS SIMBOLO
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_CLIENTE_ETIQUETA_SIMBOLO]
    @CLIENTE INT,
    @SIMBOLO VARCHAR(6),
    @USUARIO INT
AS
SET NOCOUNT ON

SET @SIMBOLO = UPPER(LTRIM(RTRIM(ISNULL(@SIMBOLO, ''))))
IF (@SIMBOLO NOT IN ('QR', 'BARRAS'))
BEGIN
    RAISERROR('1.- LA SIMBOLOGIA DEBE SER QR O BARRAS.', 16, 1)
    RETURN -1
END

UPDATE [dbo].[Cliente] SET cli_etiqueta_simbolo = @SIMBOLO WHERE cli_id = @CLIENTE

IF (@@ROWCOUNT = 0)
BEGIN
    RAISERROR('2.- EL CLIENTE NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @CLIENTE [ID], '200' [CODE],
       CASE @SIMBOLO WHEN 'QR' THEN 'Las etiquetas llevan QR.' ELSE 'Las etiquetas llevan código de barras.' END [MENSAJE]
GO
