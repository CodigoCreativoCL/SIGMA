USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  22-09-2026
-- DESCRIPTION:     SPRINT 4 (HU-100) Administrar categorias de tarea.
--                  T-4306 modelo/indices, T-4307 SEL, T-4308 INS, T-4309 UPD,
--                  T-4310 DEL (baja logica), T-4311 datos de prueba.
--
-- T-4306 MODELO: EL CODIGO ES UNICO DENTRO DEL CLIENTE
--   La tabla traia DOS indices unicos: UX_TCA_CLIENTE_CODIGO (cliente+codigo,
--   el correcto) y UX_TCA_GLOBAL_CODIGO (solo codigo, global). El segundo
--   contradice el criterio -impediria que dos empresas usaran el mismo codigo,
--   p.ej. "PREVENTIVO"-, asi que se elimina. Queda la unicidad POR CLIENTE.
--   (La tabla esta vacia: quitarlo no afecta datos.)
--
-- REAPLICABLE (CREATE OR ALTER; drop de indice guardado; datos idempotentes).
-- =============================================

SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- T-4306) Alinear el modelo: fuera el unico global; queda el unico por cliente.
-- ---------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_TCA_GLOBAL_CODIGO' AND object_id = OBJECT_ID('Tarea_Categoria'))
    DROP INDEX [UX_TCA_GLOBAL_CODIGO] ON [dbo].[Tarea_Categoria]
GO

-- ---------------------------------------------------------------------------
-- T-4307) SEL_TAREA_CATEGORIA - un solo SP para la grilla y para la ficha.
--   Filtros opcionales (@ID, @FILTRO, @HABILITADO) y SIEMPRE acotado al cliente.
--   Reescrito: el anterior referia columnas inexistentes (TCA_USUARIO_ACT/
--   TCA_FECHA_ACT), no filtraba por cliente y no escapaba el filtro.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_TAREA_CATEGORIA]
    @ID         INT          = NULL,
    @CLIENTE    INT          = NULL,
    @FILTRO     VARCHAR(MAX) = NULL,
    @HABILITADO BIT          = NULL
AS
SET NOCOUNT ON

DECLARE @SELECT VARCHAR(MAX) = '
    SELECT  TCA_ID
           ,TCA_CLIENTE
           ,TCA_CODIGO
           ,TCA_NOMBRE
           ,ISNULL(TCA_COLOR, '''') AS TCA_COLOR
           ,ISNULL(TCA_ORDEN, 0)    AS TCA_ORDEN
           ,TCA_USUARIO_CREACION
           ,TCA_FECHA_CREACION
           ,TCA_USUARIO_ACTUALIZACION
           ,TCA_FECHA_ACTUALIZACION
           ,TCA_HABILITADO '

DECLARE @FROM VARCHAR(MAX) = ' FROM [dbo].[Tarea_Categoria] '

DECLARE @WHERE VARCHAR(MAX) = ' WHERE 1=1 '

IF (@ID IS NOT NULL)        SET @WHERE = @WHERE + ' AND TCA_ID = ' + LTRIM(STR(@ID))
IF (@CLIENTE IS NOT NULL)   SET @WHERE = @WHERE + ' AND TCA_CLIENTE = ' + LTRIM(STR(@CLIENTE))
IF (@HABILITADO IS NOT NULL) SET @WHERE = @WHERE + ' AND TCA_HABILITADO = ' + LTRIM(STR(@HABILITADO))

-- El filtro libre se escapa: la comilla simple se duplica para que no cierre
-- la cadena dinamica (patron PATRON_SP).
IF (@FILTRO IS NOT NULL AND LTRIM(RTRIM(@FILTRO)) <> '')
BEGIN
    DECLARE @F VARCHAR(MAX) = REPLACE(@FILTRO, '''', '''''')
    SET @WHERE = @WHERE + ' AND (TCA_CODIGO LIKE ''%' + @F + '%''
                              OR TCA_NOMBRE LIKE ''%' + @F + '%''
                              OR ISNULL(TCA_COLOR,'''') LIKE ''%' + @F + '%'') '
END

-- ORDER BY estable: por orden y, a igualdad, por codigo (no por un campo que
-- pueda repetirse, o la grilla "salta" entre cargas).
DECLARE @ORDER VARCHAR(MAX) = ' ORDER BY ISNULL(TCA_ORDEN, 0), TCA_CODIGO '

EXEC (@SELECT + @FROM + @WHERE + @ORDER)
GO

-- ---------------------------------------------------------------------------
-- T-4308) INS_TAREA_CATEGORIA - alta en transaccion. Codigo unico por cliente,
--   fecha sellada con FNC_PAIS_HORA.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_TAREA_CATEGORIA]
    @ID       INT = NULL OUTPUT,
    @CLIENTE  INT,
    @CODIGO   NVARCHAR(50),
    @NOMBRE   NVARCHAR(200),
    @COLOR    NVARCHAR(20) = NULL,
    @ORDEN    INT = NULL,
    @USUARIO  INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

IF (@CODIGO IS NULL OR LEN(@CODIGO) = 0)
BEGIN
    RAISERROR('1.- INDIQUE EL CODIGO DE LA CATEGORIA.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Tarea_Categoria]
            WHERE tca_cliente = @CLIENTE AND tca_codigo = @CODIGO)
BEGIN
    RAISERROR('2.- YA EXISTE UNA CATEGORIA CON EL CODIGO "%s".', 16, 1, @CODIGO)
    RETURN -1
END

BEGIN TRANSACTION

    INSERT [dbo].[Tarea_Categoria]
        (tca_cliente, tca_codigo, tca_nombre, tca_color, tca_orden,
         tca_usuario_creacion, tca_fecha_creacion,
         tca_usuario_actualizacion, tca_fecha_actualizacion, tca_habilitado)
    VALUES
        (@CLIENTE, @CODIGO, @NOMBRE, @COLOR, @ORDEN,
         @USUARIO, @DATE_NOW, @USUARIO, @DATE_NOW, 1)

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @V VARCHAR(MAX) = 'INS_TAREA_CATEGORIA ' + ISNULL(@CODIGO,'')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @V, @MSG = '3.- NO FUE POSIBLE CREAR LA CATEGORIA.'
        RETURN -1
    END

    SET @ID = SCOPE_IDENTITY()

COMMIT TRANSACTION
RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- T-4309) UPD_TAREA_CATEGORIA - edicion. Lo que la ficha no manda se conserva
--   con ISNULL(@X, columna). Codigo unico por cliente (excluyendo el propio).
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_TAREA_CATEGORIA]
    @ID         INT,
    @CODIGO     NVARCHAR(50) = NULL,
    @NOMBRE     NVARCHAR(200) = NULL,
    @COLOR      NVARCHAR(20) = NULL,
    @ORDEN      INT = NULL,
    @HABILITADO BIT = NULL,
    @USUARIO    INT
AS
SET NOCOUNT ON

DECLARE @CLIENTE INT, @PAIS INT, @DATE_NOW DATETIME
SELECT @CLIENTE = tca_cliente FROM [dbo].[Tarea_Categoria] WHERE tca_id = @ID

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- LA CATEGORIA NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF @CODIGO IS NOT NULL
BEGIN
    SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
    IF EXISTS (SELECT 1 FROM [dbo].[Tarea_Categoria]
                WHERE tca_cliente = @CLIENTE AND tca_codigo = @CODIGO AND tca_id <> @ID)
    BEGIN
        RAISERROR('2.- YA EXISTE OTRA CATEGORIA CON EL CODIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE [dbo].[Tarea_Categoria]
       SET tca_codigo     = ISNULL(@CODIGO, tca_codigo),
           tca_nombre     = ISNULL(@NOMBRE, tca_nombre),
           tca_color      = ISNULL(@COLOR, tca_color),
           tca_orden      = ISNULL(@ORDEN, tca_orden),
           tca_habilitado = ISNULL(@HABILITADO, tca_habilitado),
           tca_usuario_actualizacion = @USUARIO,
           tca_fecha_actualizacion   = @DATE_NOW
     WHERE tca_id = @ID

COMMIT TRANSACTION
RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- T-4310) DEL_TAREA_CATEGORIA - baja logica. Rechaza si hay tareas que la usan,
--   en vez de dejarlas huerfanas.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[DEL_TAREA_CATEGORIA]
    @ID INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Categoria] WHERE tca_id = @ID)
BEGIN
    RAISERROR('1.- LA CATEGORIA NO EXISTE.', 16, 1)
    RETURN -1
END

-- Con tareas asociadas se rechaza y NO se toca nada: darla de baja dejaria
-- esas tareas apuntando a una categoria fuera de uso (huerfanas). Quien quiera
-- retirarla, primero reasigna o deshabilita sus tareas.
IF EXISTS (SELECT 1 FROM [dbo].[Tarea] WHERE tar_tarea_categoria = @ID)
BEGIN
    RAISERROR('2.- LA CATEGORIA TIENE TAREAS ASOCIADAS: REASIGNELAS ANTES DE ELIMINARLA.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION
    -- Baja logica: no se borra la fila (podria estar referida en historico),
    -- se marca deshabilitada.
    UPDATE [dbo].[Tarea_Categoria] SET tca_habilitado = 0 WHERE tca_id = @ID
COMMIT TRANSACTION
RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- T-4311) Datos de prueba: categorias del cliente 1. Idempotente por codigo.
-- ---------------------------------------------------------------------------
DECLARE @U INT = (SELECT TOP 1 ucl_id_usuario FROM [dbo].[Cliente_Usuario] WHERE ucl_id_cliente = 1 ORDER BY ucl_id_usuario)
IF @U IS NOT NULL
BEGIN
    DECLARE @NID INT
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Categoria] WHERE tca_cliente=1 AND tca_codigo='PREVENTIVO')
        EXEC [dbo].[INS_TAREA_CATEGORIA] @CLIENTE=1,@CODIGO=N'PREVENTIVO',@NOMBRE=N'Mantenimiento preventivo',@COLOR=N'#22c55e',@ORDEN=1,@USUARIO=@U,@ID=@NID OUTPUT
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Categoria] WHERE tca_cliente=1 AND tca_codigo='CORRECTIVO')
        EXEC [dbo].[INS_TAREA_CATEGORIA] @CLIENTE=1,@CODIGO=N'CORRECTIVO',@NOMBRE=N'Mantenimiento correctivo',@COLOR=N'#ef4444',@ORDEN=2,@USUARIO=@U,@ID=@NID OUTPUT
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Categoria] WHERE tca_cliente=1 AND tca_codigo='INSPECCION')
        EXEC [dbo].[INS_TAREA_CATEGORIA] @CLIENTE=1,@CODIGO=N'INSPECCION',@NOMBRE=N'Inspeccion y ronda',@COLOR=N'#3b82f6',@ORDEN=3,@USUARIO=@U,@ID=@NID OUTPUT
END
GO

SELECT 'categorias del cliente 1' AS control, COUNT(*) AS valor
FROM [dbo].[Tarea_Categoria] WHERE tca_cliente = 1
GO

PRINT '205_SPRINT4_TAREA_CATEGORIA aplicado (modelo + SEL/INS/UPD/DEL + datos).'
GO
