USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  04-09-2026
-- DESCRIPTION:     SPRINT 3 - PLANTA COMPLETA DE HAMBURGO (tipos + lineas + equipos).
-- =============================================
-- Va DESPUES de 140_SPRINT3_ALINEAR_DOC_MODELO.
--
-- Construye la estructura real de la planta, respetando la doc:
--   FAMILIAS (Activo_Tipo padre) -> TIPOS (Activo_Tipo hijo) -> ACTIVOS (equipos).
--
--   Panificacion -> Modeladora | Amasadora | Horno
--   Refrigeracion -> Camara BT (baja temp) | Camara MT (media temp)
--
--   Ubicacion: Hamburgo S.A. -> Panaderia -> Linea 1..4.
--
--   Equipos (marca en act_fabricante; codigo automatico ACT-<id>):
--     Modeladora  (Fritsch)   L1 (ya existe, ACT-33) + L2, L3
--     Horno       (Alitech AA) L1, L2, L3, L4
--     Amasadora   (Escher)     "Revolvedora" L1, L2, L3, L4
--     Camara BT   (Anaconda)   L1, L2, L3, L4
--     Camara MT   (Anaconda)   L1, L2, L3, L4
--
-- ES IDEMPOTENTE (cada tipo/area/activo se salta si ya existe por nombre).
-- =============================================

SET NOCOUNT ON
GO

/* ========================================================================
   1) TIPOS DE MAQUINA (hijos de las familias existentes).
      Panificacion = 26, Refrigeracion = 27. Modeladora (34) ya existe.
   ======================================================================== */
DECLARE @CLIENTE INT = 1, @USUARIO INT = 9, @NEW INT = NULL;

DECLARE @tipos TABLE (orden INT IDENTITY(1,1), nombre NVARCHAR(200), padre INT, descr NVARCHAR(500));
INSERT INTO @tipos (nombre, padre, descr) VALUES
    (N'Amasadora', 26, N'Amasadora / revolvedora de masa.'),
    (N'Horno',     26, N'Horno de coccion.'),
    (N'Camara BT', 27, N'Camara de refrigeracion de baja temperatura.'),
    (N'Camara MT', 27, N'Camara de refrigeracion de media temperatura.');

DECLARE @i INT = 1, @tot INT = (SELECT COUNT(*) FROM @tipos), @nom NVARCHAR(200), @pad INT, @des NVARCHAR(500);
WHILE @i <= @tot
BEGIN
    SELECT @nom = nombre, @pad = padre, @des = descr FROM @tipos WHERE orden = @i;
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo] WHERE ati_cliente = @CLIENTE AND ati_nombre = @nom)
        EXEC [dbo].[INS_ACTIVO_TIPO] @ID = @NEW OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO_TIPO_PADRE = @pad,
             @CODIGO = N'AUTO', @NOMBRE = @nom, @DESCRIPCION = @des, @ORDEN = @i, @USUARIO = @USUARIO;
    SET @i = @i + 1;
END
PRINT '--- Tipos de maquina listos (Amasadora, Horno, Camara BT, Camara MT).';
GO

/* ========================================================================
   2) LINEAS 2, 3, 4 (sub-areas de Panaderia). Linea 1 ya existe.
   ======================================================================== */
DECLARE @CLIENTE INT = 1, @USUARIO INT = 9, @PLANTA INT, @PANADERIA INT, @NEW INT = NULL;

SELECT TOP 1 @PLANTA = cin_id FROM [dbo].[Cliente_Instalacion] WHERE cin_cliente = @CLIENTE ORDER BY cin_id;
SELECT @PANADERIA = iar_id FROM [dbo].[Instalacion_Area]
WHERE  iar_cliente_instalacion = @PLANTA AND iar_nombre = N'Panaderia' AND iar_area_padre IS NULL;

DECLARE @n INT = 2, @nom_a NVARCHAR(20), @cod_a NVARCHAR(20), @des_a NVARCHAR(100);
WHILE @n <= 4
BEGIN
    SET @nom_a = N'Linea ' + CAST(@n AS NVARCHAR(2));
    SET @cod_a = N'LN-' + CAST(@n AS NVARCHAR(2));
    SET @des_a = N'Linea de produccion ' + CAST(@n AS NVARCHAR(2)) + N'.';
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area]
                   WHERE iar_cliente_instalacion = @PLANTA AND iar_nombre = @nom_a)
        EXEC [dbo].[INS_INSTALACION_AREA] @ID = @NEW OUTPUT, @CLIENTE = @CLIENTE, @CLIENTE_INSTALACION = @PLANTA,
             @AREA_PADRE = @PANADERIA, @INSTALACION_AREA_TIPO = 3,
             @CODIGO = @cod_a, @NOMBRE = @nom_a, @DESCRIPCION = @des_a, @USUARIO = @USUARIO;
    SET @n = @n + 1;
END
PRINT '--- Lineas 2, 3, 4 listas.';
GO

/* ========================================================================
   3) La Modeladora existente (ACT-33) pasa a llamarse "Modeladora L1".
   ======================================================================== */
UPDATE [dbo].[Activo] SET act_nombre = N'Modeladora L1'
WHERE  act_codigo = 'ACT-33' AND act_cliente = 1 AND act_nombre = N'Modeladora';
PRINT '--- ACT-33 renombrada a Modeladora L1.';
GO

/* ========================================================================
   4) LOS EQUIPOS. Marca en act_fabricante; codigo automatico.
      Se resuelven tipo y area por nombre. Idempotente por nombre de activo.
   ======================================================================== */
DECLARE @CLIENTE INT = 1, @USUARIO INT = 9, @PLANTA INT, @NEW INT = NULL;
SELECT TOP 1 @PLANTA = cin_id FROM [dbo].[Cliente_Instalacion] WHERE cin_cliente = @CLIENTE ORDER BY cin_id;

-- Helpers para resolver ids por nombre.
DECLARE @T_MOD INT = (SELECT ati_id FROM Activo_Tipo WHERE ati_cliente=1 AND ati_nombre=N'Modeladora');
DECLARE @T_AMA INT = (SELECT ati_id FROM Activo_Tipo WHERE ati_cliente=1 AND ati_nombre=N'Amasadora');
DECLARE @T_HOR INT = (SELECT ati_id FROM Activo_Tipo WHERE ati_cliente=1 AND ati_nombre=N'Horno');
DECLARE @T_BT  INT = (SELECT ati_id FROM Activo_Tipo WHERE ati_cliente=1 AND ati_nombre=N'Camara BT');
DECLARE @T_MT  INT = (SELECT ati_id FROM Activo_Tipo WHERE ati_cliente=1 AND ati_nombre=N'Camara MT');

DECLARE @A1 INT = (SELECT iar_id FROM Instalacion_Area WHERE iar_cliente_instalacion=@PLANTA AND iar_nombre=N'Linea 1');
DECLARE @A2 INT = (SELECT iar_id FROM Instalacion_Area WHERE iar_cliente_instalacion=@PLANTA AND iar_nombre=N'Linea 2');
DECLARE @A3 INT = (SELECT iar_id FROM Instalacion_Area WHERE iar_cliente_instalacion=@PLANTA AND iar_nombre=N'Linea 3');
DECLARE @A4 INT = (SELECT iar_id FROM Instalacion_Area WHERE iar_cliente_instalacion=@PLANTA AND iar_nombre=N'Linea 4');

-- La "Revolvedora L1" creada en la corrida parcial se reconvierte en
-- "Revolvedora 1" ubicada en Linea 3 (las revolvedoras se numeran 1-4).
UPDATE [dbo].[Activo] SET act_nombre = N'Revolvedora 1', act_instalacion_area = @A3
WHERE  act_cliente = @CLIENTE AND act_nombre = N'Revolvedora L1';

-- Los hornos quedan solo con marca Alitech (se quita "Modelo AA").
UPDATE [dbo].[Activo] SET act_descripcion = NULL
WHERE  act_cliente = @CLIENTE AND act_nombre LIKE N'Horno L%' AND act_descripcion = N'Modelo AA.';

-- Lista de equipos a sembrar (la Modeladora L1 ya existe, no va aqui).
DECLARE @eq TABLE (orden INT IDENTITY(1,1), nombre NVARCHAR(200), tipo INT, fab NVARCHAR(200), descr NVARCHAR(500), area INT);
INSERT INTO @eq (nombre, tipo, fab, descr, area) VALUES
    -- Modeladoras (Fritsch)
    (N'Modeladora L2', @T_MOD, N'Fritsch', NULL, @A2),
    (N'Modeladora L3', @T_MOD, N'Fritsch', NULL, @A3),
    -- Hornos (Alitech)
    (N'Horno L1', @T_HOR, N'Alitech', NULL, @A1),
    (N'Horno L2', @T_HOR, N'Alitech', NULL, @A2),
    (N'Horno L3', @T_HOR, N'Alitech', NULL, @A3),
    (N'Horno L4', @T_HOR, N'Alitech', NULL, @A4),
    -- Amasadoras / revolvedoras (Escher): numeradas 1-4; 1 y 2 en L3, 3 y 4 en L4
    (N'Revolvedora 2', @T_AMA, N'Escher', N'Amasadora / revolvedora.', @A3),
    (N'Revolvedora 3', @T_AMA, N'Escher', N'Amasadora / revolvedora.', @A4),
    (N'Revolvedora 4', @T_AMA, N'Escher', N'Amasadora / revolvedora.', @A4),
    -- Camaras BT (Anaconda, baja temperatura)
    (N'Camara BT L1', @T_BT, N'Anaconda', N'Baja temperatura.', @A1),
    (N'Camara BT L2', @T_BT, N'Anaconda', N'Baja temperatura.', @A2),
    (N'Camara BT L3', @T_BT, N'Anaconda', N'Baja temperatura.', @A3),
    (N'Camara BT L4', @T_BT, N'Anaconda', N'Baja temperatura.', @A4),
    -- Camaras MT (Anaconda, media temperatura)
    (N'Camara MT L1', @T_MT, N'Anaconda', N'Media temperatura.', @A1),
    (N'Camara MT L2', @T_MT, N'Anaconda', N'Media temperatura.', @A2),
    (N'Camara MT L3', @T_MT, N'Anaconda', N'Media temperatura.', @A3),
    (N'Camara MT L4', @T_MT, N'Anaconda', N'Media temperatura.', @A4);

DECLARE @i INT = 1, @tot INT = (SELECT COUNT(*) FROM @eq);
DECLARE @nom NVARCHAR(200), @tipo INT, @fab NVARCHAR(200), @descr NVARCHAR(500), @area INT;
WHILE @i <= @tot
BEGIN
    SELECT @nom = nombre, @tipo = tipo, @fab = fab, @descr = descr, @area = area FROM @eq WHERE orden = @i;
    IF @tipo IS NOT NULL AND @area IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_cliente = @CLIENTE AND act_nombre = @nom)
    BEGIN
        EXEC [dbo].[INS_ACTIVO]
             @ID = @NEW OUTPUT, @CLIENTE = @CLIENTE, @CLIENTE_INSTALACION = @PLANTA,
             @INSTALACION_AREA = @area, @ACTIVO_TIPO = @tipo, @ACTIVO_ESTADO = 1,
             @CRITICIDAD_NIVEL = 2, @CODIGO = N'AUTO', @NOMBRE = @nom,
             @FABRICANTE = @fab, @DESCRIPCION = @descr, @USUARIO = @USUARIO;
    END
    SET @i = @i + 1;
END
PRINT '--- Equipos sembrados (modeladoras, hornos, revolvedoras, camaras BT y MT).';
GO

/* ========================================================================
   COMPROBACION - la planta completa por familia / tipo / linea.
   ======================================================================== */
PRINT '=== ESTRUCTURA DE TIPOS (familias y tipos de maquina) ===';
SELECT fam.ati_nombre AS familia, hijo.ati_nombre AS tipo_maquina
FROM   [dbo].[Activo_Tipo] hijo
JOIN   [dbo].[Activo_Tipo] fam ON fam.ati_id = hijo.ati_activo_tipo_padre
WHERE  hijo.ati_cliente = 1 AND hijo.ati_habilitado = 1
ORDER  BY fam.ati_nombre, hijo.ati_nombre;

PRINT '=== EQUIPOS POR LINEA ===';
SELECT ia.iar_nombre AS linea, t.ati_nombre AS tipo, a.act_codigo, a.act_nombre, a.act_fabricante
FROM   [dbo].[Activo] a
JOIN   [dbo].[Activo_Tipo] t ON t.ati_id = a.act_activo_tipo
LEFT  JOIN [dbo].[Instalacion_Area] ia ON ia.iar_id = a.act_instalacion_area
WHERE  a.act_cliente = 1 AND a.act_habilitado = 1
ORDER  BY ia.iar_nombre, t.ati_nombre, a.act_nombre;

PRINT '=== TOTAL DE EQUIPOS ===';
SELECT COUNT(*) AS total_activos FROM [dbo].[Activo] WHERE act_cliente = 1 AND act_habilitado = 1;
GO

PRINT '141_SPRINT3_PLANTA_COMPLETA aplicado.';
GO
