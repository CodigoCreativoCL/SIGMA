USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  05-09-2026
-- DESCRIPTION:     SPRINT 3 - 4 ATRIBUTOS TECNICOS DE EJEMPLO (Hamburgo).
-- =============================================
-- Ejemplos para que se vea el uso: nombre + tipo de dato + UNIDAD del catalogo.
-- Tipos: Modeladora 34, Amasadora 35, Horno 36, Camara BT 37.
-- Tipo de dato: 2 ENTERO, 3 DECIMAL. Unidad: se resuelve por su codigo.
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1, @USR INT = 9, @new INT = NULL;
DECLARE @CELSIUS INT, @M3 INT, @KG INT, @MM INT;
SELECT @CELSIUS = ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'CELSIUS';
SELECT @M3      = ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'M3';
SELECT @KG      = ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'KILOGRAMO';
SELECT @MM      = ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'MM';

DECLARE @a TABLE (orden INT IDENTITY(1,1), tipo INT, nombre NVARCHAR(200), td INT, unidad INT);
INSERT INTO @a (tipo, nombre, td, unidad) VALUES
    (36, N'Temperatura maxima',  2, @CELSIUS),   -- Horno / entero / C
    (37, N'Volumen',             3, @M3),         -- Camara BT / decimal / m3
    (35, N'Capacidad de tazon',  3, @KG),         -- Amasadora / decimal / kg
    (34, N'Espesor de masa',     3, @MM);         -- Modeladora / decimal / mm

DECLARE @i INT = 1, @tot INT = (SELECT COUNT(*) FROM @a), @tipo INT, @nom NVARCHAR(200), @td INT, @uni INT;
WHILE @i <= @tot
BEGIN
    SELECT @tipo = tipo, @nom = nombre, @td = td, @uni = unidad FROM @a WHERE orden = @i;
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Atributo_Tecnico]
                   WHERE ate_cliente = @CLIENTE AND ate_activo_tipo = @tipo AND ate_nombre = @nom)
    BEGIN
        EXEC [dbo].[INS_ATRIBUTO_TECNICO]
             @ID = @new OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO_TIPO = @tipo,
             @TIPO_DATO = @td, @UNIDAD_MEDIDA = @uni,
             @CODIGO = N'AUTO', @NOMBRE = @nom, @ORDEN = @i, @USUARIO = @USR;
    END
    SET @i = @i + 1;
END
PRINT '--- 4 atributos de ejemplo cargados.';
GO

/* COMPROBACION */
SELECT t.ati_nombre AS tipo, a.ate_codigo, a.ate_nombre, a.ate_tipo_dato, ISNULL(u.ume_simbolo,'-') AS unidad
FROM   [dbo].[Atributo_Tecnico] a
JOIN   [dbo].[Activo_Tipo] t ON t.ati_id = a.ate_activo_tipo
LEFT  JOIN [dbo].[Unidad_Medida] u ON u.ume_id = a.ate_unidad_medida
WHERE  a.ate_cliente = 1 AND a.ate_habilitado = 1
ORDER  BY t.ati_nombre;
GO

PRINT '148_SPRINT3_ATRIBUTOS_EJEMPLO aplicado.';
GO
