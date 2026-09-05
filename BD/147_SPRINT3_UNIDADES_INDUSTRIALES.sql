USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  05-09-2026
-- DESCRIPTION:     SPRINT 3 - UNIDADES DE MEDIDA INDUSTRIALES (catalogo base).
-- =============================================
-- Las MAGNITUDES ya existen (Potencia, Voltaje, Corriente, Presion, Caudal,
-- Velocidad de rotacion...), pero faltaban las UNIDADES. Se agregan al catalogo
-- GLOBAL (Unidad_Medida no tiene cliente): asi cualquier cliente, al definir un
-- atributo tecnico, elige la unidad (kW, V, rpm...) en vez de escribirla en el
-- nombre.
--
-- Ademas se BORRAN los atributos demo cargados en Hamburgo (bloque 146): los
-- atributos los define el CLIENTE en la pantalla, no vienen precargados.
--
-- Magnitudes: 3 Presion, 4 Vel.rotacion, 5 Corriente, 6 Voltaje, 7 Caudal,
--             11 Longitud, 13 Volumen, 14 Potencia.
-- ES IDEMPOTENTE (por ume_codigo).
-- =============================================

SET NOCOUNT ON
GO

DECLARE @USR INT = 9, @new INT = NULL;

-- (codigo, magnitud, base_codigo, nombre, simbolo, factor). Las BASE
-- (base_codigo NULL) van primero para que las derivadas las encuentren.
DECLARE @u TABLE (orden INT IDENTITY(1,1), codigo NVARCHAR(20), magnitud INT,
                  base_codigo NVARCHAR(20), nombre NVARCHAR(100), simbolo NVARCHAR(20), factor DECIMAL(18,6));
INSERT INTO @u (codigo, magnitud, base_codigo, nombre, simbolo, factor) VALUES
    -- Bases nuevas (una por magnitud sin unidades)
    (N'KW',   14, NULL, N'Kilovatio',                    N'kW',   1),
    (N'V',     6, NULL, N'Voltio',                        N'V',    1),
    (N'A',     5, NULL, N'Amperio',                       N'A',    1),
    (N'RPM',   4, NULL, N'Revoluciones por minuto',       N'rpm',  1),
    (N'BAR',   3, NULL, N'Bar',                           N'bar',  1),
    (N'LMIN',  7, NULL, N'Litro por minuto',              N'L/min',1),
    -- Derivadas (referencian una base por su codigo)
    (N'W',    14, N'KW',    N'Vatio',                     N'W',    0.001000),
    (N'HP',   14, N'KW',    N'Caballo de fuerza',         N'HP',   0.745700),
    (N'CV',   14, N'KW',    N'Caballo de vapor',          N'CV',   0.735500),
    (N'KV',    6, N'V',     N'Kilovoltio',                N'kV',   1000),
    (N'MV',    6, N'V',     N'Milivoltio',                N'mV',   0.001000),
    (N'MA',    5, N'A',     N'Miliamperio',               N'mA',   0.001000),
    (N'KPA',   3, N'BAR',   N'Kilopascal',                N'kPa',  0.010000),
    (N'PSI',   3, N'BAR',   N'Libra por pulgada cuadrada',N'psi',  0.068948),
    (N'M3H',   7, N'LMIN',  N'Metro cubico por hora',     N'm3/h', 16.666667),
    (N'LH',    7, N'LMIN',  N'Litro por hora',            N'L/h',  0.016667),
    (N'M3',   13, N'LITRO', N'Metro cubico',              N'm3',   1000),
    (N'MM',   11, N'METRO', N'Milimetro',                 N'mm',   0.001000);

DECLARE @i INT = 1, @tot INT = (SELECT COUNT(*) FROM @u);
DECLARE @cod NVARCHAR(20), @mag INT, @bcod NVARCHAR(20), @nom NVARCHAR(100), @sim NVARCHAR(20), @fac DECIMAL(18,6), @baseId INT;
WHILE @i <= @tot
BEGIN
    SELECT @cod = codigo, @mag = magnitud, @bcod = base_codigo, @nom = nombre, @sim = simbolo, @fac = factor
    FROM @u WHERE orden = @i;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_codigo = @cod)
    BEGIN
        SET @baseId = NULL;
        IF @bcod IS NOT NULL SELECT @baseId = ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = @bcod;

        EXEC [dbo].[INS_UNIDAD_MEDIDA]
             @ID = @new OUTPUT, @MAGNITUD = @mag, @UNIDAD_BASE = @baseId,
             @CODIGO = @cod, @NOMBRE = @nom, @SIMBOLO = @sim,
             @FACTOR = @fac, @OFFSET = 0, @USUARIO = @USR;
    END
    SET @i = @i + 1;
END
PRINT '--- Unidades industriales agregadas al catalogo base.';
GO

-- ---------- Borrar atributos demo de Hamburgo (los define el cliente) ----------
DELETE FROM [dbo].[Activo_Atributo]
WHERE aat_atributo_tecnico IN (SELECT ate_id FROM [dbo].[Atributo_Tecnico] WHERE ate_cliente = 1);
DELETE FROM [dbo].[Atributo_Tecnico] WHERE ate_cliente = 1;
PRINT '--- Atributos demo de Hamburgo eliminados (los definira el cliente).';
GO

/* ========================================================================
   COMPROBACION - unidades por magnitud
   ======================================================================== */
SELECT u.ume_magnitud, u.ume_codigo, u.ume_nombre, u.ume_simbolo,
       ISNULL(CONVERT(VARCHAR(20), u.ume_unidad_base), 'BASE') AS base
FROM   [dbo].[Unidad_Medida] u
ORDER  BY u.ume_magnitud, u.ume_id;
GO

PRINT '147_SPRINT3_UNIDADES_INDUSTRIALES aplicado.';
GO
