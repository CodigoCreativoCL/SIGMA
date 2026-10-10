/* ============================================================================
   387 · Tipos de OT creables desde el Centro de Planificación (08-10-2026)

   Orden_Trabajo_Tipo es un catálogo global: no tiene cliente ni SP propio.
   INS_ORDEN_TRABAJO_TIPO crea uno nuevo (o devuelve el que ya existe con ese
   nombre, sin distinguir mayúsculas ni tildes) para que el combo de la
   intervención permita «Crear "…"» sin pasar por la base a mano.
   ============================================================================ */
CREATE OR ALTER PROCEDURE [dbo].[INS_ORDEN_TRABAJO_TIPO]
    @ID      INT = NULL OUTPUT,
    @NOMBRE  NVARCHAR(100),
    @USUARIO INT = NULL
AS
SET NOCOUNT ON
SET XACT_ABORT ON

SET @NOMBRE = LTRIM(RTRIM(ISNULL(@NOMBRE, N'')))
IF LEN(@NOMBRE) < 3
BEGIN
    RAISERROR('1.- EL NOMBRE DEL TIPO DE OT DEBE TENER AL MENOS 3 LETRAS.', 16, 1)
    RETURN -1
END

SELECT TOP 1 @ID = ott_id FROM [dbo].[Orden_Trabajo_Tipo]
 WHERE ott_nombre = @NOMBRE COLLATE Latin1_General_CI_AI
 ORDER BY ott_habilitado DESC, ott_id

IF @ID IS NOT NULL
BEGIN
    UPDATE [dbo].[Orden_Trabajo_Tipo] SET ott_habilitado = 1 WHERE ott_id = @ID AND ott_habilitado = 0
    SELECT @ID AS ID
    RETURN 0
END

DECLARE @COD NVARCHAR(100) = UPPER(@NOMBRE COLLATE Latin1_General_CI_AI)
SET @COD = REPLACE(@COD, N' ', N'_')
IF EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Tipo] WHERE ott_codigo = @COD) SET @COD = LEFT(@COD, 90) + N'_' + CAST(ABS(CHECKSUM(NEWID())) % 1000 AS NVARCHAR(10))

INSERT INTO [dbo].[Orden_Trabajo_Tipo] (ott_codigo, ott_nombre, ott_orden, ott_habilitado)
VALUES (LEFT(@COD, 100), @NOMBRE, ISNULL((SELECT MAX(ott_orden) FROM [dbo].[Orden_Trabajo_Tipo]), 0) + 1, 1)
SET @ID = SCOPE_IDENTITY()
SELECT @ID AS ID
RETURN 0
GO
PRINT '387_OT_TIPO aplicado.'
GO
