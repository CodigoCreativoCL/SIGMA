USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     PRESENCIA DE USUARIOS Y «QUIEN ESTA CONECTADO» AL PUBLICAR UNA CAMPANA.
-- =============================================
-- POR QUE
--   Al publicar una campana hay que ver quien esta conectado ahora y que le llegue
--   sin recargar. La pantalla de cada persona consulta sus campanas pendientes cada
--   ~30 s (SEL_CAMPANA_PENDIENTES) y en esa misma llamada deja su presencia:
--   Usuario_Presencia guarda la ultima vez que cada persona estuvo en SIGMA.
--   «Conectado» = presencia de los ultimos 2 minutos.
--   SEL_CAMPANA_CONECTADOS(@CAMPANA, @CLIENTE) responde: de la audiencia de la
--   campana, quien esta conectado y a quien ya le llego (cen_veces > 0).
-- TODO IDEMPOTENTE.
-- =============================================

IF OBJECT_ID('dbo.Usuario_Presencia', 'U') IS NULL
CREATE TABLE [dbo].[Usuario_Presencia](
    upr_usuario INT      NOT NULL,
    upr_cliente INT      NOT NULL,
    upr_ultima  DATETIME NOT NULL,
    CONSTRAINT PK_Usuario_Presencia PRIMARY KEY (upr_usuario, upr_cliente)
)
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_PRESENCIA]
    @USUARIO INT,
    @CLIENTE INT
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
UPDATE [dbo].[Usuario_Presencia] SET upr_ultima = @AHORA WHERE upr_usuario = @USUARIO AND upr_cliente = @CLIENTE
IF @@ROWCOUNT = 0
    INSERT INTO [dbo].[Usuario_Presencia] (upr_usuario, upr_cliente, upr_ultima) VALUES (@USUARIO, @CLIENTE, @AHORA)
GO

/* 1) resumen · 2) los conectados de la audiencia, con si ya la vieron. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CAMPANA_CONECTADOS]
    @CAMPANA INT,
    @CLIENTE INT
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @UNION VARCHAR(3) = (SELECT cam_union FROM [dbo].[Campana] WHERE cam_id = @CAMPANA)
DECLARE @A TABLE (usuario INT PRIMARY KEY)
INSERT INTO @A SELECT a.usuario
  FROM [dbo].[FNC_CAMPANA_AUDIENCIA]([dbo].[FNC_CAMPANA_CONDICIONES](@CAMPANA), @UNION, NULL) a WHERE a.cliente = @CLIENTE

SELECT  AUDIENCIA = (SELECT COUNT(*) FROM @A),
        CONECTADOS = (SELECT COUNT(*) FROM @A a JOIN [dbo].[Usuario_Presencia] p ON p.upr_usuario = a.usuario AND p.upr_cliente = @CLIENTE AND p.upr_ultima >= DATEADD(MINUTE, -2, @AHORA)),
        VIERON = (SELECT COUNT(*) FROM [dbo].[Campana_Entrega] e JOIN @A a ON a.usuario = e.cen_usuario WHERE e.cen_campana = @CAMPANA AND e.cen_cliente = @CLIENTE AND e.cen_veces > 0)

SELECT  TOP 60 u.usu_id AS ID,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS NOMBRE,
        DATEDIFF(SECOND, p.upr_ultima, @AHORA) AS HACE_SEG,
        CAST(CASE WHEN ISNULL(e.cen_veces, 0) > 0 THEN 1 ELSE 0 END AS BIT) AS VIO
FROM    @A a
JOIN    [dbo].[Usuario_Presencia] p ON p.upr_usuario = a.usuario AND p.upr_cliente = @CLIENTE AND p.upr_ultima >= DATEADD(MINUTE, -2, @AHORA)
JOIN    [dbo].[Usuario] u ON u.usu_id = a.usuario
LEFT JOIN [dbo].[Campana_Entrega] e ON e.cen_campana = @CAMPANA AND e.cen_usuario = a.usuario AND e.cen_cliente = @CLIENTE
ORDER BY VIO, p.upr_ultima DESC
GO

PRINT '373_CAMPANA_PRESENCIA aplicado.'
GO
