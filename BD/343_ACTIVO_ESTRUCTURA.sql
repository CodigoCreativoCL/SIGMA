/* ============================================================================
   SIGMA - Bloque 343
   EL ACTIVO SE ENTIENDE DE UN VISTAZO
   ----------------------------------------------------------------------------
   Revisión del cliente (04-10-2026): "necesito entender a simple vista la
   diferencia entre un activo con componentes y un activo con subactivos".

     1. SEL_ACTIVO_ESTRUCTURA: en UNA llamada, todo lo que cuelga de un activo
        -su máquina principal si es subactivo, sus subactivos, sus componentes
        y los repuestos que le calzan con su stock-. Lo dibuja la pestaña
        "Estructura" del centro 360.
     2. SEL_ACTIVO_ARBOL_LISTA: para el listado como árbol. Cuántos
        subactivos, componentes y repuestos tiene cada activo, y el área con su
        padre ("Refrigeración › Línea 1": había cinco "Línea 1" iguales).
     3. FNC_NOMBRE_PROPIO: una marca nueva escrita toda en minúscula o toda en
        mayúscula queda con mayúscula inicial («cleaver brooks» → «Cleaver
        Brooks»). Lo que viene mezclado (iPhone, SKF) se respeta.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
GO

-- ---------------------------------------------------------------------------
-- 3) Nombre propio para marcas nuevas
-- ---------------------------------------------------------------------------
CREATE OR ALTER FUNCTION [dbo].[FNC_NOMBRE_PROPIO] (@T NVARCHAR(400))
RETURNS NVARCHAR(400)
AS
BEGIN
    IF @T IS NULL OR @T = N'' RETURN @T
    -- mezcla de mayusculas y minusculas: alguien lo escribio a proposito
    IF @T COLLATE Latin1_General_BIN <> LOWER(@T) COLLATE Latin1_General_BIN
       AND @T COLLATE Latin1_General_BIN <> UPPER(@T) COLLATE Latin1_General_BIN RETURN @T
    -- siglas cortas en mayuscula (SKF, ABB, WEG) se quedan asi
    IF @T COLLATE Latin1_General_BIN = UPPER(@T) COLLATE Latin1_General_BIN AND LEN(@T) <= 4 AND CHARINDEX(N' ', @T) = 0 RETURN @T

    DECLARE @R NVARCHAR(400) = LOWER(@T), @I INT = 1, @PREV NCHAR(1) = N' '
    WHILE @I <= LEN(@R)
    BEGIN
        IF @PREV IN (N' ', N'-', N'/', N'.', N'(')
            SET @R = STUFF(@R, @I, 1, UPPER(SUBSTRING(@R, @I, 1)))
        SET @PREV = SUBSTRING(@R, @I, 1)
        SET @I += 1
    END
    RETURN @R
END
GO

CREATE OR ALTER TRIGGER [dbo].[TRG_ACTIVO_FABRICANTE]
ON [dbo].[Activo]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON
    IF NOT UPDATE(act_fabricante) RETURN

    DECLARE @I TABLE (id INT PRIMARY KEY, cli INT, fab NVARCHAR(400) COLLATE Latin1_General_CI_AI)
    INSERT INTO @I
    SELECT act_id, act_cliente, [dbo].[FNC_TEXTO_LIMPIO](act_fabricante)
    FROM   inserted

    INSERT INTO [dbo].[Fabricante] (fab_cliente, fab_nombre)
    SELECT cli, [dbo].[FNC_NOMBRE_PROPIO](MIN(fab COLLATE Latin1_General_BIN))
    FROM   @I i
    WHERE  fab IS NOT NULL
      AND  NOT EXISTS (SELECT 1 FROM [dbo].[Fabricante] x WHERE x.fab_cliente = i.cli AND x.fab_nombre = i.fab)
    GROUP BY cli, fab

    UPDATE a SET a.act_fabricante = fa.fab_nombre
    FROM   [dbo].[Activo] a
    JOIN   @I i ON i.id = a.act_id
    JOIN   [dbo].[Fabricante] fa ON fa.fab_cliente = i.cli AND fa.fab_nombre = i.fab
    WHERE  ISNULL(a.act_fabricante, N'') COLLATE Latin1_General_BIN <> fa.fab_nombre COLLATE Latin1_General_BIN
END
GO

-- las marcas que llegaron solo por activos y quedaron en minuscula; las de
-- repuestos no se tocan: su forma ya la fijo el bloque 333
UPDATE f SET fab_nombre = [dbo].[FNC_NOMBRE_PROPIO](fab_nombre)
FROM   [dbo].[Fabricante] f
WHERE  fab_nombre COLLATE Latin1_General_BIN <> [dbo].[FNC_NOMBRE_PROPIO](fab_nombre) COLLATE Latin1_General_BIN
  AND  EXISTS (SELECT 1 FROM [dbo].[Activo] a WHERE a.act_cliente = f.fab_cliente
               AND a.act_fabricante COLLATE Latin1_General_CI_AI = f.fab_nombre COLLATE Latin1_General_CI_AI)
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto] r WHERE r.rep_cliente = f.fab_cliente
               AND r.rep_fabricante COLLATE Latin1_General_CI_AI = f.fab_nombre COLLATE Latin1_General_CI_AI)
GO
UPDATE a SET act_fabricante = f.fab_nombre
FROM   [dbo].[Activo] a JOIN [dbo].[Fabricante] f ON f.fab_cliente = a.act_cliente
       AND f.fab_nombre COLLATE Latin1_General_CI_AI = a.act_fabricante COLLATE Latin1_General_CI_AI
WHERE  a.act_fabricante COLLATE Latin1_General_BIN <> f.fab_nombre COLLATE Latin1_General_BIN
UPDATE m SET amo_fabricante = f.fab_nombre
FROM   [dbo].[Activo_Modelo] m JOIN [dbo].[Fabricante] f ON f.fab_cliente = m.amo_cliente
       AND f.fab_nombre COLLATE Latin1_General_CI_AI = m.amo_fabricante COLLATE Latin1_General_CI_AI
WHERE  m.amo_fabricante COLLATE Latin1_General_BIN <> f.fab_nombre COLLATE Latin1_General_BIN
GO

-- ---------------------------------------------------------------------------
-- 1) La estructura de un activo, en una llamada
-- ---------------------------------------------------------------------------
-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  04-10-2026
-- DESCRIPTION:     SELECT ESTRUCTURA DE UN ACTIVO: 1 PADRE, 2 SUBACTIVOS,
--                  3 COMPONENTES, 4 REPUESTOS COMPATIBLES CON SU STOCK
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_ESTRUCTURA]
    @CLIENTE INT,
    @ACTIVO  INT
AS
SET NOCOUNT ON

    DECLARE @TIPO INT, @MODELO INT, @PADRE INT
    SELECT @TIPO = act_activo_tipo, @MODELO = act_activo_modelo, @PADRE = act_activo_padre
    FROM   [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE

    -- 1. su maquina principal (si es subactivo)
    SELECT p.act_id AS ID, p.act_codigo AS CODIGO, p.act_nombre AS NOMBRE
    FROM   [dbo].[Activo] p WHERE p.act_id = @PADRE AND p.act_cliente = @CLIENTE

    -- 2. subactivos
    SELECT s.act_id AS ID, s.act_codigo AS CODIGO, s.act_nombre AS NOMBRE,
           ISNULL(e.aes_nombre, '') AS ESTADO, ISNULL(e.aes_codigo, '') AS ESTADO_CODIGO,
           ISNULL(t.ati_nombre, '') AS TIPO, ISNULL(c.crn_nombre, '') AS CRITICIDAD,
           (SELECT COUNT(*) FROM [dbo].[Activo_Componente] x WHERE x.aco_activo = s.act_id AND x.aco_habilitado = 1) AS COMPONENTES,
           (SELECT COUNT(*) FROM [dbo].[Activo] x WHERE x.act_activo_padre = s.act_id AND x.act_habilitado = 1) AS SUBACTIVOS
    FROM   [dbo].[Activo] s
    LEFT JOIN [dbo].[Activo_Estado] e ON e.aes_id = s.act_activo_estado
    LEFT JOIN [dbo].[Activo_Tipo] t ON t.ati_id = s.act_activo_tipo
    LEFT JOIN [dbo].[Criticidad_Nivel] c ON c.crn_id = s.act_criticidad_nivel
    WHERE  s.act_activo_padre = @ACTIVO AND s.act_cliente = @CLIENTE AND s.act_habilitado = 1 AND s.act_fusionado_en IS NULL
    ORDER BY s.act_nombre

    -- 3. componentes (con su padre, para armar el arbol)
    SELECT c.aco_id AS ID, c.aco_componente_padre AS PADRE, c.aco_codigo AS CODIGO, c.aco_nombre AS NOMBRE,
           ISNULL(t.cto_nombre, '') AS TIPO, ISNULL(p.cpn_nombre, '') AS LADO,
           ISNULL(e.ace_nombre, '') AS ESTADO, ISNULL(e.ace_codigo, '') AS ESTADO_CODIGO
    FROM   [dbo].[Activo_Componente] c
    LEFT JOIN [dbo].[Componente_Tipo] t ON t.cto_id = c.aco_componente_tipo
    LEFT JOIN [dbo].[Componente_Posicion] p ON p.cpn_id = c.aco_componente_posicion
    LEFT JOIN [dbo].[Activo_Componente_Estado] e ON e.ace_id = c.aco_activo_componente_estado
    WHERE  c.aco_activo = @ACTIVO AND c.aco_cliente = @CLIENTE AND c.aco_habilitado = 1 AND c.aco_fusionado_en IS NULL
    ORDER BY c.aco_componente_padre, c.aco_nombre

    -- 4. repuestos que le calzan: por su modelo, su tipo o alguno de sus componentes
    SELECT r.rep_id AS ID, r.rep_codigo AS CODIGO, r.rep_nombre AS NOMBRE,
           MIN(CASE WHEN rc.rco_activo_componente IS NOT NULL THEN 'COMPONENTE'
                    WHEN rc.rco_activo_modelo IS NOT NULL THEN 'MODELO' ELSE 'TIPO' END) AS ALCANCE,
           ISNULL((SELECT SUM(s.isa_cantidad) FROM [dbo].[Inventario_Saldo] s WHERE s.isa_repuesto = r.rep_id), 0) AS EXISTENCIA,
           ISNULL((SELECT SUM(u.rbs_stock_minimo) FROM [dbo].[Repuesto_Bodega_Stock] u WHERE u.rbs_repuesto = r.rep_id), 0) AS MINIMO,
           ISNULL(MAX(um.ume_simbolo), '') AS UNIDAD
    FROM   [dbo].[Repuesto_Compatibilidad] rc
    JOIN   [dbo].[Repuesto] r ON r.rep_id = rc.rco_repuesto AND r.rep_cliente = @CLIENTE AND r.rep_habilitado = 1
    LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = r.rep_unidad_medida
    WHERE  rc.rco_activo_tipo = @TIPO
       OR (@MODELO IS NOT NULL AND rc.rco_activo_modelo = @MODELO)
       OR  rc.rco_activo_componente IN (SELECT aco_id FROM [dbo].[Activo_Componente] WHERE aco_activo = @ACTIVO)
    GROUP BY r.rep_id, r.rep_codigo, r.rep_nombre
    ORDER BY r.rep_nombre
GO

-- ---------------------------------------------------------------------------
-- 2) El listado como arbol
-- ---------------------------------------------------------------------------
-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  04-10-2026
-- DESCRIPTION:     SELECT PADRE, CONTADORES Y AREA CON SU PADRE DE CADA ACTIVO
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_ARBOL_LISTA]
    @CLIENTE INT
AS
SET NOCOUNT ON

    SELECT a.act_id AS ID, a.act_activo_padre AS PADRE,
           (SELECT COUNT(*) FROM [dbo].[Activo] x WHERE x.act_activo_padre = a.act_id AND x.act_habilitado = 1 AND x.act_fusionado_en IS NULL) AS SUBACTIVOS,
           (SELECT COUNT(*) FROM [dbo].[Activo_Componente] x WHERE x.aco_activo = a.act_id AND x.aco_habilitado = 1) AS COMPONENTES,
           (SELECT COUNT(DISTINCT rc.rco_repuesto) FROM [dbo].[Repuesto_Compatibilidad] rc
             WHERE rc.rco_activo_tipo = a.act_activo_tipo
                OR (a.act_activo_modelo IS NOT NULL AND rc.rco_activo_modelo = a.act_activo_modelo)
                OR rc.rco_activo_componente IN (SELECT aco_id FROM [dbo].[Activo_Componente] WHERE aco_activo = a.act_id)) AS REPUESTOS,
           ISNULL(ap.iar_nombre + N' › ', N'') + ISNULL(ar.iar_nombre, N'') AS AREA_RUTA
    FROM   [dbo].[Activo] a
    LEFT JOIN [dbo].[Instalacion_Area] ar ON ar.iar_id = a.act_instalacion_area
    LEFT JOIN [dbo].[Instalacion_Area] ap ON ap.iar_id = ar.iar_area_padre
    WHERE  a.act_cliente = @CLIENTE
GO

-- ---------------------------------------------------------------------------
-- 4) Tipo de componente escrito en la ficha: buscar o crear (propio del cliente)
-- ---------------------------------------------------------------------------
-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  04-10-2026
-- DESCRIPTION:     BUSCA EL TIPO DE COMPONENTE POR NOMBRE (COMUN O DEL CLIENTE)
--                  Y SI NO EXISTE LO CREA COMO PROPIO DEL CLIENTE
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPS_COMPONENTE_TIPO_NOMBRE]
    @ID      INT = NULL OUTPUT,
    @CLIENTE INT,
    @NOMBRE  NVARCHAR(200),
    @USUARIO INT
AS
SET NOCOUNT ON
    SET @ID = NULL
    SET @NOMBRE = NULLIF([dbo].[FNC_TEXTO_LIMPIO](@NOMBRE), N'')
    IF @NOMBRE IS NULL BEGIN RAISERROR('1.- ESCRIBA QUE ES EL COMPONENTE.', 16, 1) RETURN -1 END

    SELECT TOP 1 @ID = cto_id FROM [dbo].[Componente_Tipo]
    WHERE  (cto_cliente IS NULL OR cto_cliente = @CLIENTE)
      AND  cto_nombre COLLATE Latin1_General_CI_AI = @NOMBRE COLLATE Latin1_General_CI_AI
    ORDER BY CASE WHEN cto_cliente IS NULL THEN 0 ELSE 1 END, cto_habilitado DESC

    IF @ID IS NOT NULL RETURN 0

    DECLARE @CODIGO NVARCHAR(100) = LEFT(UPPER([dbo].[FNC_NOMBRE_PROPIO](@NOMBRE)), 90), @N INT = 1
    WHILE EXISTS (SELECT 1 FROM [dbo].[Componente_Tipo] WHERE cto_cliente = @CLIENTE AND cto_codigo = @CODIGO)
    BEGIN SET @N += 1; SET @CODIGO = LEFT(UPPER(@NOMBRE), 85) + N'-' + LTRIM(@N) END

    INSERT INTO [dbo].[Componente_Tipo] (cto_cliente, cto_codigo, cto_nombre, cto_orden, cto_usuario_creacion, cto_fecha_creacion,
                                         cto_usuario_actualizacion, cto_fecha_actualizacion, cto_habilitado)
    VALUES (@CLIENTE, @CODIGO, [dbo].[FNC_NOMBRE_PROPIO](@NOMBRE), 100, @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)
    SET @ID = SCOPE_IDENTITY()
RETURN 0
GO

EXEC [dbo].[SEL_ACTIVO_ARBOL_LISTA] @CLIENTE = 1
GO
