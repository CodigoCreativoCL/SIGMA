USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  31-08-2026
-- DESCRIPTION:     T-2006 DATOS DE PRUEBA DE ACTIVO PARA EJERCITAR HU-035.
-- =============================================
-- Va DESPUES de 74_SPRINT2_ACTIVO.
--
-- QUE HACE
--   Deja un par de tipos de activo globales y unos activos de ejemplo en
--   Hamburgo (cli_id 1), su primera planta, para poder listar, filtrar,
--   editar y dar de baja sin tener que cargarlos a mano.
--
-- POR QUE RESUELVE LOS IDS EN TIEMPO DE EJECUCION
--   Las plantas, areas y centros de costo son IDENTITY: no se fuerzan sus
--   ids. Si esta demo asumiera "la planta es la 1" se rompe en cuanto la base
--   se rearma en otro orden. Por eso busca la primera planta del cliente y
--   solo inserta si existe; si el cliente todavia no tiene planta, avisa y no
--   hace nada, en vez de fallar.
--
-- ES IDEMPOTENTE
--   Cada activo se inserta por su codigo (unico por cliente): re-ejecutar no
--   duplica.
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. TIPOS DE ACTIVO GLOBALES
      ati_cliente NULL = tipo de SIGMA, visible para todos los clientes.
      Sirven de clasificacion base mientras cada cliente arma la suya.
   ======================================================================== */

DECLARE @T TABLE (codigo NVARCHAR(50), nombre NVARCHAR(200), descripcion NVARCHAR(500), orden INT)

INSERT INTO @T VALUES
    (N'MOTOR',      N'Motor eléctrico',    N'Motores eléctricos de inducción y sincrónicos', 1),
    (N'BOMBA',      N'Bomba',              N'Bombas centrífugas y de desplazamiento positivo', 2),
    (N'COMPRESOR',  N'Compresor',          N'Compresores de aire y de proceso',               3),
    (N'REDUCTOR',   N'Reductor',           N'Reductores y cajas de engranajes',               4)

INSERT INTO [dbo].[Activo_Tipo]
    (ati_cliente, ati_codigo, ati_nombre, ati_descripcion, ati_orden,
     ati_usuario_creacion, ati_fecha_creacion, ati_habilitado)
SELECT  NULL, t.codigo, t.nombre, t.descripcion, t.orden, 1, GETDATE(), 1
FROM    @T t
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo]
                     WHERE ati_cliente IS NULL AND ati_codigo = t.codigo)
GO


/* ========================================================================
   2. ACTIVOS DE EJEMPLO EN HAMBURGO (cli_id 1)
   ======================================================================== */

DECLARE @CLIENTE INT = 1
DECLARE @INST INT, @AREA INT, @TIPO_MOTOR INT, @TIPO_BOMBA INT, @USUARIO INT = 1

-- Primera planta del cliente (la que exista, no una fija).
SELECT TOP 1 @INST = cin_id
FROM   [dbo].[Cliente_Instalacion]
WHERE  cin_cliente = @CLIENTE
ORDER BY cin_id

IF @INST IS NULL
BEGIN
    PRINT '--- Hamburgo aun no tiene planta. No se cargan activos demo (correcto).'
    RETURN
END

-- Primera area de esa planta, si hay (es opcional en el activo).
SELECT TOP 1 @AREA = iar_id
FROM   [dbo].[Instalacion_Area]
WHERE  iar_cliente = @CLIENTE AND iar_cliente_instalacion = @INST
ORDER BY iar_id

SELECT @TIPO_MOTOR = ati_id FROM [dbo].[Activo_Tipo] WHERE ati_cliente IS NULL AND ati_codigo = N'MOTOR'
SELECT @TIPO_BOMBA = ati_id FROM [dbo].[Activo_Tipo] WHERE ati_cliente IS NULL AND ati_codigo = N'BOMBA'

-- Estados y criticidades son catalogos de ids fijos (bloque 04):
--   Activo_Estado: 1 OPERATIVO, 4 EN MANTENIMIENTO
--   Criticidad_Nivel: 2 MEDIA, 3 ALTA, 4 CRITICA

DECLARE @A TABLE
(
    codigo      NVARCHAR(50),
    nombre      NVARCHAR(200),
    tipo        INT,
    estado      INT,
    criticidad  INT,
    serie       NVARCHAR(100),
    fabricante  NVARCHAR(200),
    anio        INT
)

INSERT INTO @A VALUES
    (N'MOT-001', N'Motor bomba de agua principal',   @TIPO_MOTOR, 1, 3, N'SIEM-2019-4471', N'Siemens',       2019),
    (N'BMB-001', N'Bomba centrífuga línea 1',        @TIPO_BOMBA, 1, 4, N'KSB-88213',      N'KSB',           2020),
    (N'MOT-002', N'Motor ventilador extracción',     @TIPO_MOTOR, 4, 2, N'WEG-2021-1120',  N'WEG',           2021),
    (N'BMB-002', N'Bomba de respaldo línea 1',       @TIPO_BOMBA, 1, 2, N'KSB-88999',      N'KSB',           2022)

INSERT INTO [dbo].[Activo]
    (act_cliente, act_cliente_instalacion, act_instalacion_area, act_activo_tipo,
     act_activo_estado, act_criticidad_nivel, act_codigo, act_nombre,
     act_numero_serie, act_fabricante, act_anio_fabricacion, act_registro_origen,
     act_usuario_creacion, act_fecha_creacion, act_usuario_actualizacion,
     act_fecha_actualizacion, act_habilitado)
SELECT  @CLIENTE, @INST, @AREA, a.tipo,
        a.estado, a.criticidad, a.codigo, a.nombre,
        a.serie, a.fabricante, a.anio, 1,   -- 1 = CARGA INICIAL
        @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1
FROM    @A a
WHERE   a.tipo IS NOT NULL
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Activo]
                     WHERE act_cliente = @CLIENTE AND act_codigo = a.codigo)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'tipos de activo globales' AS control, COUNT(*) AS valor
FROM   [dbo].[Activo_Tipo] WHERE ati_cliente IS NULL
UNION ALL
SELECT 'activos demo en Hamburgo', COUNT(*)
FROM   [dbo].[Activo] WHERE act_cliente = 1
GO

PRINT '75_SPRINT2_ACTIVO_DEMO aplicado.'
GO
