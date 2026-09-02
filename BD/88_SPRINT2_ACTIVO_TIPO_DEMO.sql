USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  31-08-2026
-- DESCRIPTION:     T-2226 DATOS DE PRUEBA DE ACTIVO_TIPO PARA EJERCITAR HU-030.
-- =============================================
-- Va DESPUES de 87_SPRINT2_ACTIVO_TIPO.
--
-- Los 4 tipos globales (MOTOR, BOMBA, COMPRESOR, REDUCTOR) los sembro el
-- bloque 75. Aqui se agregan tipos DEL CLIENTE Hamburgo (cli_id 1) con dos
-- niveles, para ejercitar el arbol y el filtro por cliente.
--
-- ES IDEMPOTENTE: cada tipo por (cliente, codigo).
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1, @USUARIO INT = 1

/* ---- Raices del cliente ---- */
DECLARE @R TABLE (codigo NVARCHAR(50), nombre NVARCHAR(200), descripcion NVARCHAR(500), orden INT)
INSERT INTO @R VALUES
    (N'ROTATIVO', N'Equipo rotativo', N'Máquinas con partes que giran',       1),
    (N'ESTATICO', N'Equipo estático', N'Recipientes, líneas e intercambiadores', 2)

INSERT INTO [dbo].[Activo_Tipo]
    (ati_cliente, ati_activo_tipo_padre, ati_codigo, ati_nombre, ati_descripcion, ati_orden,
     ati_usuario_creacion, ati_fecha_creacion, ati_usuario_actualizacion, ati_fecha_actualizacion, ati_habilitado)
SELECT  @CLIENTE, NULL, r.codigo, r.nombre, r.descripcion, r.orden,
        @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1
FROM    @R r
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo]
                     WHERE ISNULL(ati_cliente,0) = @CLIENTE AND ati_codigo = r.codigo)
GO

DECLARE @CLIENTE INT = 1, @USUARIO INT = 1
DECLARE @ROT INT, @EST INT
SELECT @ROT = ati_id FROM [dbo].[Activo_Tipo] WHERE ISNULL(ati_cliente,0)=@CLIENTE AND ati_codigo=N'ROTATIVO'
SELECT @EST = ati_id FROM [dbo].[Activo_Tipo] WHERE ISNULL(ati_cliente,0)=@CLIENTE AND ati_codigo=N'ESTATICO'

/* ---- Hijos ---- */
DECLARE @H TABLE (padre INT, codigo NVARCHAR(50), nombre NVARCHAR(200), orden INT)
INSERT INTO @H VALUES
    (@ROT, N'MOTOR ELECTRICO',  N'Motor eléctrico',        1),
    (@ROT, N'BOMBA CENTRIFUGA', N'Bomba centrífuga',       2),
    (@ROT, N'VENTILADOR',       N'Ventilador industrial',  3),
    (@EST, N'INTERCAMBIADOR',   N'Intercambiador de calor', 1),
    (@EST, N'ESTANQUE',         N'Estanque de almacenamiento', 2)

INSERT INTO [dbo].[Activo_Tipo]
    (ati_cliente, ati_activo_tipo_padre, ati_codigo, ati_nombre, ati_orden,
     ati_usuario_creacion, ati_fecha_creacion, ati_usuario_actualizacion, ati_fecha_actualizacion, ati_habilitado)
SELECT  @CLIENTE, h.padre, h.codigo, h.nombre, h.orden,
        @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1
FROM    @H h
WHERE   h.padre IS NOT NULL
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo]
                     WHERE ISNULL(ati_cliente,0) = @CLIENTE AND ati_codigo = h.codigo)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'tipos globales'         AS control, COUNT(*) AS valor FROM [dbo].[Activo_Tipo] WHERE ati_cliente IS NULL
UNION ALL
SELECT 'tipos del cliente 1',   COUNT(*) FROM [dbo].[Activo_Tipo] WHERE ati_cliente = 1
GO

PRINT '88_SPRINT2_ACTIVO_TIPO_DEMO aplicado.'
GO
