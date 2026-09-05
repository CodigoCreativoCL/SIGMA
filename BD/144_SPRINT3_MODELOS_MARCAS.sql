USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  04-09-2026
-- DESCRIPTION:     SPRINT 3 - MARCAS COMO MODELOS DE ACTIVO (panaderia Hamburgo).
-- =============================================
-- En Hamburgo los equipos NO tienen designacion de modelo (una linea entera es
-- la misma marca), asi que se registra SOLO LA MARCA. Cada modelo se guarda con
-- amo_fabricante = <marca> y amo_nombre = '' (vacio): la etiqueta del combo
-- (fabricante + ' ' + nombre, con LTRIM) queda como "Fritsch", "Diosna", etc.
-- Al elegirlo en el alta del activo, hereda el fabricante.
--
-- Cada marca va bajo el TIPO que fabrica (para que aparezca al crear ese tipo):
--   Fritsch    -> Modeladora (34)
--   Diosna     -> Amasadora  (35)
--   Escher     -> Amasadora  (35)
--   Alitech    -> Horno      (36)
--   ASA        -> Envasado   (tipo nuevo, se crea aqui)
--   Tecnopool  -> Camara BT (37) y Camara MT (38)
--   Zeppelin   -> Dosificacion (28)
--   Lesaffre   -> Dosificacion (28)
--
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1, @USUARIO INT = 9, @NEW INT = NULL, @ENVASADO INT = NULL;

-- Tipo nuevo "Envasado" bajo Panificacion (26), para ASA.
SELECT @ENVASADO = ati_id FROM [dbo].[Activo_Tipo] WHERE ati_cliente = @CLIENTE AND ati_nombre = N'Envasado';
IF @ENVASADO IS NULL
BEGIN
    EXEC [dbo].[INS_ACTIVO_TIPO] @ID = @NEW OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO_TIPO_PADRE = 26,
         @CODIGO = N'AUTO', @NOMBRE = N'Envasado', @DESCRIPCION = N'Equipos de envasado / empaque.',
         @ORDEN = 4, @USUARIO = @USUARIO;
    SET @ENVASADO = @NEW;
    PRINT '--- Tipo "Envasado" creado bajo Panificacion.';
END

-- (fabricante, tipo). nombre = '' (solo marca).
DECLARE @m TABLE (orden INT IDENTITY(1,1), fabricante NVARCHAR(200), tipo INT);
INSERT INTO @m (fabricante, tipo) VALUES
    (N'Fritsch',   34),
    (N'Diosna',    35),
    (N'Escher',    35),
    (N'Alitech',   36),
    (N'ASA',       @ENVASADO),
    (N'Tecnopool', 37),
    (N'Tecnopool', 38),
    (N'Zeppelin',  28),
    (N'Lesaffre',  28);

DECLARE @i INT = 1, @tot INT = (SELECT COUNT(*) FROM @m), @fab NVARCHAR(200), @tipo INT;
WHILE @i <= @tot
BEGIN
    SELECT @fab = fabricante, @tipo = tipo FROM @m WHERE orden = @i;

    IF @tipo IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM [dbo].[Activo_Modelo]
        WHERE amo_cliente = @CLIENTE AND amo_activo_tipo = @tipo
          AND amo_fabricante = @fab AND (amo_nombre = N'' OR amo_nombre IS NULL))
    BEGIN
        EXEC [dbo].[INS_ACTIVO_MODELO]
             @ID = @NEW OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO_TIPO = @tipo,
             @FABRICANTE = @fab, @NOMBRE = N'', @DESCRIPCION = NULL, @USUARIO = @USUARIO;
    END
    SET @i = @i + 1;
END
PRINT '--- Marcas registradas como modelos (solo marca).';
GO

/* ========================================================================
   COMPROBACION - como se vera en el combo "Modelo" por tipo
   ======================================================================== */
SELECT t.ati_nombre AS tipo,
       LTRIM(ISNULL(m.amo_fabricante + ' ', '') + m.amo_nombre) AS se_ve_en_el_combo
FROM   [dbo].[Activo_Modelo] m
JOIN   [dbo].[Activo_Tipo] t ON t.ati_id = m.amo_activo_tipo
WHERE  m.amo_cliente = 1 AND m.amo_habilitado = 1
ORDER  BY t.ati_nombre, m.amo_fabricante;
GO

PRINT '144_SPRINT3_MODELOS_MARCAS aplicado.';
GO
