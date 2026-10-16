/* ============================================================================
   SIGMA — Bloque 469
   Nuevo lead: aviso cuando el dominio del correo ya existe en otro lead o cliente.
   Es un aviso, no un bloqueo. Los dominios de correo gratuito no cuentan.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_LEAD_DOMINIO]
@CORREO NVARCHAR(200)
AS
SET NOCOUNT ON
DECLARE @DOM NVARCHAR(200) = LOWER(LTRIM(RTRIM(SUBSTRING(@CORREO, CHARINDEX('@', @CORREO) + 1, 200))))
IF CHARINDEX('@', @CORREO) = 0 OR @DOM = N'' OR @DOM IN (N'gmail.com', N'hotmail.com', N'outlook.com', N'outlook.es', N'live.com', N'yahoo.com', N'yahoo.es', N'icloud.com', N'protonmail.com', N'msn.com')
BEGIN
    SELECT TOP 0 CAST(NULL AS INT) AS ID, CAST(NULL AS NVARCHAR(200)) AS EMPRESA, CAST(NULL AS VARCHAR(20)) AS CODIGO, CAST(NULL AS VARCHAR(20)) AS ESTADO, CAST(NULL AS NVARCHAR(10)) AS TIPO
    RETURN 0
END
SELECT L.lea_id AS ID, L.lea_empresa AS EMPRESA, L.lea_codigo AS CODIGO, L.lea_estado AS ESTADO,
       CASE WHEN L.lea_cliente IS NOT NULL THEN N'CLIENTE' ELSE N'LEAD' END AS TIPO
  FROM [dbo].[Lead] L
 WHERE L.lea_habilitado = 1 AND LOWER(L.lea_correo) LIKE N'%@' + @DOM
 ORDER BY L.lea_fecha_creacion DESC
RETURN 0
GO

PRINT '469_LEAD_DOMINIO aplicado.'
GO
