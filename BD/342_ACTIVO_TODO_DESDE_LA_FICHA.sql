/* ============================================================================
   SIGMA - Bloque 342
   EL ACTIVO SE ARMA DESDE SU PROPIA FICHA
   ----------------------------------------------------------------------------
   Revisión del cliente (04-10-2026): crear un activo obligaba a pasar antes
   por cinco menús de "Configuración de activos" (tipos, modelos, atributos,
   variables, posiciones). "Lo lento no es el servidor: son los menús y
   tras menús". Lo que se busca como producto es facilidad y rapidez.

     1. Los cinco menús se ocultan (mnu_visible = 0, nunca se borran): las
        páginas siguen existiendo y se puede volver atrás con un UPDATE.
     2. TRG_ACTIVO_FABRICANTE: el fabricante del activo usa el MISMO catálogo
        que los repuestos (bloque 333). «grundfos » y «GRUNDFOS» quedan como
        «Grundfos», y una marca nueva se agrega sola. Una lista de marcas, no
        dos.
     3. UPS_ACTIVO_CATALOGO: busca o crea, en UNA llamada, el tipo y el modelo
        que la persona escribió en la ficha. Sin mayúsculas ni acentos de por
        medio: «Hornos» y «hornos» son el mismo tipo.

   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
GO

-- ---------------------------------------------------------------------------
-- 1) Menús de configuración fuera de la vista
-- ---------------------------------------------------------------------------
UPDATE m SET mnu_visible = 0
FROM   [dbo].[Menus] m
WHERE  m.mnu_link COLLATE DATABASE_DEFAULT IN (
           N'~/View/Activos/Tipos/ActivoTipos.aspx',
           N'~/View/Activos/Modelos/ActivoModelos.aspx',
           N'~/View/Activos/Atributos/AtributoTecnicos.aspx',
           N'~/View/Activos/Variables/ActivoVariables.aspx',
           N'~/View/Activos/Posiciones/Posiciones.aspx')
   OR (m.mnu_nombre COLLATE DATABASE_DEFAULT = N'Configuración de activos' AND m.mnu_link = N'#')
GO

-- ---------------------------------------------------------------------------
-- 2) El fabricante del activo, al catálogo compartido
-- ---------------------------------------------------------------------------
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
    SELECT cli, MIN(fab COLLATE Latin1_General_BIN)
    FROM   @I i
    WHERE  fab IS NOT NULL
      AND  NOT EXISTS (SELECT 1 FROM [dbo].[Fabricante] x WHERE x.fab_cliente = i.cli AND x.fab_nombre = i.fab)
    GROUP BY cli, fab

    -- la forma canónica, solo donde difiere
    UPDATE a SET a.act_fabricante = fa.fab_nombre
    FROM   [dbo].[Activo] a
    JOIN   @I i ON i.id = a.act_id
    JOIN   [dbo].[Fabricante] fa ON fa.fab_cliente = i.cli AND fa.fab_nombre = i.fab
    WHERE  ISNULL(a.act_fabricante, N'') COLLATE Latin1_General_BIN <> fa.fab_nombre COLLATE Latin1_General_BIN
END
GO

-- los activos que ya existen pasan por la misma regla
UPDATE [dbo].[Activo] SET act_fabricante = act_fabricante WHERE act_fabricante IS NOT NULL
GO

-- ---------------------------------------------------------------------------
-- 3) Tipo y modelo escritos en la ficha: buscar o crear
-- ---------------------------------------------------------------------------
-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  04-10-2026
-- DESCRIPTION:     BUSCA O CREA EL TIPO Y EL MODELO ESCRITOS EN LA FICHA DEL ACTIVO
--                  @TIPO / @MODELO: SI VIENEN CON ID SE RESPETAN; SI VIENE SOLO
--                  EL TEXTO, SE BUSCA POR NOMBRE (SIN MAYUSCULAS NI ACENTOS) Y SI
--                  NO EXISTE SE CREA. DEVUELVE LOS IDS.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPS_ACTIVO_CATALOGO]
    @CLIENTE       INT,
    @TIPO          INT = NULL OUTPUT,
    @TIPO_TEXTO    NVARCHAR(200) = NULL,
    @MODELO        INT = NULL OUTPUT,
    @MODELO_TEXTO  NVARCHAR(200) = NULL,
    @FABRICANTE    NVARCHAR(200) = NULL,
    @USUARIO       INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

    SET @TIPO_TEXTO   = NULLIF([dbo].[FNC_TEXTO_LIMPIO](@TIPO_TEXTO), N'')
    SET @MODELO_TEXTO = NULLIF([dbo].[FNC_TEXTO_LIMPIO](@MODELO_TEXTO), N'')
    SET @FABRICANTE   = NULLIF([dbo].[FNC_TEXTO_LIMPIO](@FABRICANTE), N'')
    IF @TIPO = 0 SET @TIPO = NULL
    IF @MODELO = 0 SET @MODELO = NULL

    -- el tipo
    IF @TIPO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo] WHERE ati_id = @TIPO AND ati_cliente = @CLIENTE)
    BEGIN RAISERROR('1.- ESE TIPO NO ES DE SU EMPRESA.', 16, 1) RETURN -1 END

    IF @TIPO IS NULL AND @TIPO_TEXTO IS NULL
    BEGIN RAISERROR('2.- ELIJA O ESCRIBA EL TIPO DE ACTIVO.', 16, 1) RETURN -1 END

BEGIN TRANSACTION

    IF @TIPO IS NULL
    BEGIN
        SELECT TOP 1 @TIPO = ati_id FROM [dbo].[Activo_Tipo]
        WHERE  ati_cliente = @CLIENTE AND ati_nombre COLLATE Latin1_General_CI_AI = @TIPO_TEXTO COLLATE Latin1_General_CI_AI
        ORDER BY ati_habilitado DESC, ati_id

        IF @TIPO IS NULL
        BEGIN
            EXEC [dbo].[INS_ACTIVO_TIPO] @ID = @TIPO OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO_TIPO_PADRE = NULL,
                 @CODIGO = N'AUTO', @NOMBRE = @TIPO_TEXTO, @DESCRIPCION = N'Creado desde la ficha del activo.',
                 @ORDEN = NULL, @USUARIO = @USUARIO
        END
        ELSE
            UPDATE [dbo].[Activo_Tipo] SET ati_habilitado = 1 WHERE ati_id = @TIPO AND ati_habilitado = 0
    END

    -- el modelo (opcional): siempre colgado del tipo
    IF @MODELO IS NULL AND @MODELO_TEXTO IS NOT NULL
    BEGIN
        SELECT TOP 1 @MODELO = amo_id FROM [dbo].[Activo_Modelo]
        WHERE  amo_cliente = @CLIENTE AND amo_activo_tipo = @TIPO
          AND  amo_nombre COLLATE Latin1_General_CI_AI = @MODELO_TEXTO COLLATE Latin1_General_CI_AI
          AND  (@FABRICANTE IS NULL OR ISNULL(amo_fabricante, N'') COLLATE Latin1_General_CI_AI = @FABRICANTE COLLATE Latin1_General_CI_AI)
        ORDER BY amo_habilitado DESC, amo_id

        IF @MODELO IS NULL
            EXEC [dbo].[INS_ACTIVO_MODELO] @ID = @MODELO OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO_TIPO = @TIPO,
                 @FABRICANTE = @FABRICANTE, @NOMBRE = @MODELO_TEXTO, @DESCRIPCION = N'Creado desde la ficha del activo.',
                 @USUARIO = @USUARIO
    END

    IF @TIPO IS NULL BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPS_ACTIVO_CATALOGO @CLIENTE=' + LTRIM(STR(@CLIENTE)) + ',@TIPO_TEXTO=' + ISNULL(@TIPO_TEXTO, '')
        EXEC [dbo].[INS_EXCEPCION] @MSG = '3.- NO FUE POSIBLE CREAR EL TIPO.', @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO

-- verificacion
SELECT mnu_nombre, mnu_visible FROM [dbo].[Menus]
WHERE  mnu_padre = (SELECT TOP 1 mnu_id FROM [dbo].[Menus] WHERE mnu_nombre = N'Control de activos') AND mnu_link = N'#'
GO
