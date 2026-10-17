/* ============================================================================
   476 · Carga de datos: avisar que la planilla ya se procesó (HU-200, escenario 2) · 17-10-2026
   Se guarda la huella SHA-256 del archivo en cada carga. Al subir una planilla con la misma huella
   (mismo módulo y cliente) se avisa cuándo se procesó y quién, sin impedir volver a hacerlo:
   volver a cargar es seguro (el mismo código actualiza u omite, no duplica). Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF COL_LENGTH('dbo.Carga_Masiva', 'cma_hash') IS NULL
    ALTER TABLE [dbo].[Carga_Masiva] ADD cma_hash CHAR(64) NULL
GO
CREATE OR ALTER PROCEDURE [dbo].[UPD_CARGA_MASIVA_HASH]
    @CLIENTE INT, @ID INT, @HASH CHAR(64)
AS
SET NOCOUNT ON
UPDATE [dbo].[Carga_Masiva] SET cma_hash = @HASH WHERE cma_id = @ID AND cma_cliente = @CLIENTE
GO
CREATE OR ALTER PROCEDURE [dbo].[SEL_CARGA_MASIVA_REPETIDA]
    @CLIENTE INT, @MODULO VARCHAR(30), @HASH CHAR(64), @EXCEPTO INT = 0
AS
SET NOCOUNT ON
SELECT TOP 1 c.cma_id AS ID, c.cma_inicio AS FECHA, c.cma_modo AS MODO, c.cma_archivo AS ARCHIVO,
       LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS USUARIO
FROM   [dbo].[Carga_Masiva] c
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = c.cma_usuario
WHERE  c.cma_cliente = @CLIENTE AND c.cma_modulo = UPPER(@MODULO) AND c.cma_hash = @HASH AND c.cma_id <> @EXCEPTO
ORDER BY c.cma_inicio DESC
GO
PRINT '476_CARGA_ARCHIVO_REPETIDO aplicado.'
GO
