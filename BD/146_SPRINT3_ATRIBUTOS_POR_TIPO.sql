USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  05-09-2026
-- DESCRIPTION:     SPRINT 3 - ATRIBUTOS TECNICOS POR TIPO DE EQUIPO (Hamburgo).
-- =============================================
-- 1) Borra los atributos del Motorreductor (tipo 30) que quedaron INACTIVOS
--    cuando el motor paso a ser componente (ya no aplican como tipo de equipo).
-- 2) Carga la ficha tecnica (atributos) de cada tipo de equipo. El nivel es el
--    TIPO ESPECIFICO, porque los datos de un horno no son los de una modeladora.
--    Unidad va en el nombre; tipo de dato: 1 TEXTO, 2 ENTERO, 3 DECIMAL.
--    Codigo automatico (ATR-<id>).
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1, @USUARIO INT = 9, @NEW INT = NULL;

-- 1) Limpieza de los atributos de Motorreductor (tipo 30). Sin valores
--    capturados (Activo_Atributo), asi que se pueden borrar.
DELETE FROM [dbo].[Activo_Atributo]  WHERE aat_atributo_tecnico IN
    (SELECT ate_id FROM [dbo].[Atributo_Tecnico] WHERE ate_cliente = @CLIENTE AND ate_activo_tipo = 30);
DELETE FROM [dbo].[Atributo_Tecnico] WHERE ate_cliente = @CLIENTE AND ate_activo_tipo = 30;
PRINT '--- Atributos del Motorreductor eliminados.';

-- 2) Atributos por tipo.  tipos: Modeladora 34, Amasadora 35, Horno 36,
--    Camara BT 37, Camara MT 38, Dosificacion 28, Envasado 39.
DECLARE @a TABLE (orden INT IDENTITY(1,1), tipo INT, nombre NVARCHAR(200), td INT);
INSERT INTO @a (tipo, nombre, td) VALUES
    -- Modeladora
    (34, N'Capacidad (kg/h)',        3),
    (34, N'Velocidad (m/min)',       3),
    (34, N'Espesor de masa (mm)',    3),
    (34, N'Potencia (kW)',           3),
    (34, N'Tension (V)',             1),
    -- Amasadora
    (35, N'Capacidad de tazon (kg)', 3),
    (35, N'Velocidad (rpm)',         2),
    (35, N'N de velocidades',        2),
    (35, N'Potencia (kW)',           3),
    (35, N'Tension (V)',             1),
    -- Horno
    (36, N'Capacidad (coches/bandejas)', 2),
    (36, N'Temperatura maxima (C)',      2),
    (36, N'Tipo de calentamiento',       1),
    (36, N'Potencia (kW)',               3),
    (36, N'Consumo',                     1),
    -- Camara BT
    (37, N'Rango de temperatura (C)',    1),
    (37, N'Volumen (m3)',                3),
    (37, N'Potencia frigorifica (kW)',   3),
    (37, N'Refrigerante',                1),
    (37, N'Tension (V)',                 1),
    -- Camara MT
    (38, N'Rango de temperatura (C)',    1),
    (38, N'Volumen (m3)',                3),
    (38, N'Potencia frigorifica (kW)',   3),
    (38, N'Refrigerante',                1),
    (38, N'Tension (V)',                 1),
    -- Dosificacion
    (28, N'Caudal (kg/h)',           3),
    (28, N'N de tolvas',             2),
    (28, N'Precision (%)',           3),
    (28, N'Potencia (kW)',           3),
    -- Envasado
    (39, N'Velocidad (envases/min)', 2),
    (39, N'Formato',                 1),
    (39, N'Potencia (kW)',           3),
    (39, N'Tension (V)',             1);

DECLARE @i INT = 1, @tot INT = (SELECT COUNT(*) FROM @a), @tipo INT, @nom NVARCHAR(200), @td INT;
WHILE @i <= @tot
BEGIN
    SELECT @tipo = tipo, @nom = nombre, @td = td FROM @a WHERE orden = @i;
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Atributo_Tecnico]
                   WHERE ate_cliente = @CLIENTE AND ate_activo_tipo = @tipo AND ate_nombre = @nom)
    BEGIN
        EXEC [dbo].[INS_ATRIBUTO_TECNICO]
             @ID = @NEW OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO_TIPO = @tipo,
             @TIPO_DATO = @td, @UNIDAD_MEDIDA = NULL,
             @CODIGO = N'AUTO', @NOMBRE = @nom, @ORDEN = @i, @USUARIO = @USUARIO;
    END
    SET @i = @i + 1;
END
PRINT '--- Atributos por tipo cargados.';
GO

/* ========================================================================
   COMPROBACION - atributos por tipo
   ======================================================================== */
SELECT t.ati_nombre AS tipo, a.ate_codigo, a.ate_nombre
FROM   [dbo].[Atributo_Tecnico] a
JOIN   [dbo].[Activo_Tipo] t ON t.ati_id = a.ate_activo_tipo
WHERE  a.ate_cliente = 1 AND a.ate_habilitado = 1
ORDER  BY t.ati_nombre, a.ate_id;
GO

PRINT '146_SPRINT3_ATRIBUTOS_POR_TIPO aplicado.';
GO
