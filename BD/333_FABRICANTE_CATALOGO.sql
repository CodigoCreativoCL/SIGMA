/* ============================================================================
   SIGMA - Bloque 333
   FABRICANTES Y MODELOS ESTANDARIZADOS
   ----------------------------------------------------------------------------

   Fabricante y modelo del repuesto eran texto libre: "Fleetguard",
   "fleetguard" y "FLEETGUARD " terminaban siendo tres fabricantes distintos
   en filtros, reportes y en la busqueda del mapa. Ahora hay un catalogo por
   cliente, con el modelo colgando de su fabricante (cascada), y los combos
   de la ficha del repuesto (web y mapa 3D) ofrecen lo que existe y crean lo
   nuevo en el mismo campo.

   POR QUE UN TRIGGER Y NO SOLO EL COMBO
     Los repuestos entran por la ficha web, el mapa 3D, la carga masiva y la
     API de la app. El trigger es el unico lugar por donde pasan todos: sea
     cual sea la puerta, el texto se limpia (espacios), se compara sin
     mayusculas ni acentos contra el catalogo y se guarda con la forma
     canonica; si no existe, se agrega. Las columnas rep_fabricante y
     rep_modelo siguen siendo texto, asi que etiquetas, busquedas, API y
     reportes no cambian.

     Fabricante         fab_nombre unico por cliente (CI_AI: sin mayusculas
                        ni acentos).
     Fabricante_Modelo  fmo_nombre unico por fabricante (CI_AI).
     TRG_REPUESTO_FABRICANTE  normaliza y registra en cada INSERT/UPDATE.
     SEL_FABRICANTE_CATALOGO  fabricante, modelo y cuantos repuestos lo usan.
   ============================================================================ */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.Fabricante') IS NULL
BEGIN
    CREATE TABLE [dbo].[Fabricante] (
        fab_id          INT IDENTITY(1,1) NOT NULL,
        fab_cliente     INT            NOT NULL,
        fab_nombre      NVARCHAR(400)  COLLATE Latin1_General_CI_AI NOT NULL,
        fab_fecha       DATETIME       NOT NULL CONSTRAINT DF_FAB_FECHA DEFAULT ([dbo].[FNC_AHORA]()),
        CONSTRAINT PK_FABRICANTE PRIMARY KEY CLUSTERED (fab_id),
        CONSTRAINT FK_FAB_CLIENTE FOREIGN KEY (fab_cliente) REFERENCES [dbo].[Cliente] (cli_id)
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_FABRICANTE_NOMBRE ON [dbo].[Fabricante] (fab_cliente, fab_nombre)
END
GO

IF OBJECT_ID('dbo.Fabricante_Modelo') IS NULL
BEGIN
    CREATE TABLE [dbo].[Fabricante_Modelo] (
        fmo_id          INT IDENTITY(1,1) NOT NULL,
        fmo_fabricante  INT            NOT NULL,
        fmo_nombre      NVARCHAR(400)  COLLATE Latin1_General_CI_AI NOT NULL,
        fmo_fecha       DATETIME       NOT NULL CONSTRAINT DF_FMO_FECHA DEFAULT ([dbo].[FNC_AHORA]()),
        CONSTRAINT PK_FABRICANTE_MODELO PRIMARY KEY CLUSTERED (fmo_id),
        CONSTRAINT FK_FMO_FABRICANTE FOREIGN KEY (fmo_fabricante) REFERENCES [dbo].[Fabricante] (fab_id)
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_FABRICANTE_MODELO_NOMBRE ON [dbo].[Fabricante_Modelo] (fmo_fabricante, fmo_nombre)
END
GO

/* Sin espacios al borde ni dobles en medio: "  Fleet  guard " -> "Fleet guard".
   Vacio -> NULL. */
CREATE OR ALTER FUNCTION [dbo].[FNC_TEXTO_LIMPIO] (@T NVARCHAR(400))
RETURNS NVARCHAR(400)
AS
BEGIN
    SET @T = LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(ISNULL(@T, N''), CHAR(9), N' '), CHAR(13), N' '), CHAR(10), N' ')))
    WHILE CHARINDEX(N'  ', @T) > 0 SET @T = REPLACE(@T, N'  ', N' ')
    RETURN NULLIF(@T, N'')
END
GO

/* ---------------------------------------------------------------- siembra
   Lo que ya hay en los repuestos. Entre variantes de la misma palabra gana
   la mas usada (y, a igualdad, la que tiene mas mayusculas: "SKF" sobre
   "Skf"). */
;WITH f AS (
    SELECT rep_cliente AS cli, [dbo].[FNC_TEXTO_LIMPIO](rep_fabricante) AS nom, COUNT(*) AS n
    FROM   [dbo].[Repuesto]
    WHERE  [dbo].[FNC_TEXTO_LIMPIO](rep_fabricante) IS NOT NULL
    GROUP BY rep_cliente, [dbo].[FNC_TEXTO_LIMPIO](rep_fabricante)
), g AS (
    SELECT cli, nom, ROW_NUMBER() OVER (PARTITION BY cli, nom COLLATE Latin1_General_CI_AI
                                        ORDER BY n DESC, nom COLLATE Latin1_General_BIN) AS k
    FROM f
)
INSERT INTO [dbo].[Fabricante] (fab_cliente, fab_nombre)
SELECT g.cli, g.nom FROM g
WHERE  g.k = 1
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Fabricante] x WHERE x.fab_cliente = g.cli AND x.fab_nombre = g.nom)
GO

;WITH m AS (
    SELECT fa.fab_id AS fab, [dbo].[FNC_TEXTO_LIMPIO](r.rep_modelo) AS nom, COUNT(*) AS n
    FROM   [dbo].[Repuesto] r
    JOIN   [dbo].[Fabricante] fa ON fa.fab_cliente = r.rep_cliente AND fa.fab_nombre = [dbo].[FNC_TEXTO_LIMPIO](r.rep_fabricante)
    WHERE  [dbo].[FNC_TEXTO_LIMPIO](r.rep_modelo) IS NOT NULL
    GROUP BY fa.fab_id, [dbo].[FNC_TEXTO_LIMPIO](r.rep_modelo)
), g AS (
    SELECT fab, nom, ROW_NUMBER() OVER (PARTITION BY fab, nom COLLATE Latin1_General_CI_AI
                                        ORDER BY n DESC, nom COLLATE Latin1_General_BIN) AS k
    FROM m
)
INSERT INTO [dbo].[Fabricante_Modelo] (fmo_fabricante, fmo_nombre)
SELECT g.fab, g.nom FROM g
WHERE  g.k = 1
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Fabricante_Modelo] x WHERE x.fmo_fabricante = g.fab AND x.fmo_nombre = g.nom)
GO

/* ---------------------------------------------------------------- trigger */
CREATE OR ALTER TRIGGER [dbo].[TRG_REPUESTO_FABRICANTE]
ON [dbo].[Repuesto]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON
    IF NOT (UPDATE(rep_fabricante) OR UPDATE(rep_modelo)) RETURN

    DECLARE @I TABLE (id INT PRIMARY KEY, cli INT, fab NVARCHAR(400) COLLATE Latin1_General_CI_AI, modelo NVARCHAR(400) COLLATE Latin1_General_CI_AI)
    INSERT INTO @I
    SELECT rep_id, rep_cliente, [dbo].[FNC_TEXTO_LIMPIO](rep_fabricante), [dbo].[FNC_TEXTO_LIMPIO](rep_modelo)
    FROM   inserted

    -- fabricantes nuevos (uno por palabra, aunque vengan dos variantes en la misma carga)
    INSERT INTO [dbo].[Fabricante] (fab_cliente, fab_nombre)
    SELECT cli, MIN(fab COLLATE Latin1_General_BIN)
    FROM   @I i
    WHERE  fab IS NOT NULL
      AND  NOT EXISTS (SELECT 1 FROM [dbo].[Fabricante] x WHERE x.fab_cliente = i.cli AND x.fab_nombre = i.fab)
    GROUP BY cli, fab

    -- modelos nuevos bajo su fabricante
    INSERT INTO [dbo].[Fabricante_Modelo] (fmo_fabricante, fmo_nombre)
    SELECT fa.fab_id, MIN(i.modelo COLLATE Latin1_General_BIN)
    FROM   @I i
    JOIN   [dbo].[Fabricante] fa ON fa.fab_cliente = i.cli AND fa.fab_nombre = i.fab
    WHERE  i.modelo IS NOT NULL
      AND  NOT EXISTS (SELECT 1 FROM [dbo].[Fabricante_Modelo] x WHERE x.fmo_fabricante = fa.fab_id AND x.fmo_nombre = i.modelo)
    GROUP BY fa.fab_id, i.modelo

    /* La forma canonica, solo donde difiere (comparacion binaria): sin cambios
       no se toca la fila. RECURSIVE_TRIGGERS esta apagado, asi que este UPDATE
       no vuelve a disparar el trigger. */
    UPDATE r
    SET    r.rep_fabricante = fa.fab_nombre,
           r.rep_modelo     = ISNULL(mo.fmo_nombre, i.modelo)
    FROM   [dbo].[Repuesto] r
    JOIN   @I i ON i.id = r.rep_id
    JOIN   [dbo].[Fabricante] fa ON fa.fab_cliente = i.cli AND fa.fab_nombre = i.fab
    LEFT JOIN [dbo].[Fabricante_Modelo] mo ON mo.fmo_fabricante = fa.fab_id AND mo.fmo_nombre = i.modelo
    WHERE  ISNULL(r.rep_fabricante, N'') COLLATE Latin1_General_BIN <> fa.fab_nombre COLLATE Latin1_General_BIN
       OR  ISNULL(r.rep_modelo, N'') COLLATE Latin1_General_BIN <> ISNULL(ISNULL(mo.fmo_nombre, i.modelo), N'') COLLATE Latin1_General_BIN
END
GO

/* Lo existente queda en su forma canonica (dispara el trigger una vez). */
UPDATE [dbo].[Repuesto] SET rep_fabricante = rep_fabricante WHERE rep_fabricante IS NOT NULL
GO

/* ---------------------------------------------------------------- lectura */
CREATE OR ALTER PROCEDURE [dbo].[SEL_FABRICANTE_CATALOGO]
    @CLIENTE INT
AS
SET NOCOUNT ON
    SELECT  fa.fab_id AS FAB_ID, fa.fab_nombre AS FABRICANTE,
            mo.fmo_nombre AS MODELO,
            (SELECT COUNT(*) FROM [dbo].[Repuesto] r
              WHERE r.rep_cliente = @CLIENTE AND r.rep_fabricante COLLATE Latin1_General_CI_AI = fa.fab_nombre
                AND (mo.fmo_id IS NULL OR r.rep_modelo COLLATE Latin1_General_CI_AI = mo.fmo_nombre)) AS REPUESTOS
    FROM    [dbo].[Fabricante] fa
    LEFT JOIN [dbo].[Fabricante_Modelo] mo ON mo.fmo_fabricante = fa.fab_id
    WHERE   fa.fab_cliente = @CLIENTE
    ORDER BY fa.fab_nombre, mo.fmo_nombre
GO
