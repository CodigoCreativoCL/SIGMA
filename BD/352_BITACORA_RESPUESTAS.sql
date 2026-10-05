/* ============================================================================
   SIGMA - Bloque 352
   LA BITACORA SE CONVERSA: RESPUESTAS ANIDADAS
   ----------------------------------------------------------------------------
   Una nota de la bitacora del activo («el motor suena raro») se responde en
   su mismo hilo («revisado, era la correa»), y a una respuesta tambien se le
   responde. La bitacora sigue sin editarse ni borrarse: responder es agregar.
     - Bitacora.bit_padre (FK a si misma): de que nota es respuesta.
     - INS_ACTIVO_BITACORA_RESPUESTA: la respuesta hereda el contexto de la
       nota que responde (planta, area, activo, componente, OT y tipo).
     - SEL_ACTIVO_BITACORA devuelve PADRE para armar el hilo.
   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

IF COL_LENGTH('dbo.Bitacora', 'bit_padre') IS NULL
    ALTER TABLE [dbo].[Bitacora] ADD [bit_padre] INT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_BIT_PADRE')
    ALTER TABLE [dbo].[Bitacora] WITH CHECK
        ADD CONSTRAINT [FK_BIT_PADRE] FOREIGN KEY ([bit_padre]) REFERENCES [dbo].[Bitacora] ([bit_id])
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BIT_PADRE' AND object_id = OBJECT_ID('dbo.Bitacora'))
    CREATE NONCLUSTERED INDEX [IX_BIT_PADRE] ON [dbo].[Bitacora] ([bit_padre]) WHERE [bit_padre] IS NOT NULL
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_ACTIVO_BITACORA_RESPUESTA]
    @ID      INT OUTPUT,
    @CLIENTE INT,
    @USUARIO INT,
    @PADRE   INT,
    @TEXTO   NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    IF (LTRIM(RTRIM(ISNULL(@TEXTO, N''))) = N'')
    BEGIN RAISERROR('Escribe la respuesta.', 16, 1); RETURN -1; END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bitacora] WHERE bit_id = @PADRE AND bit_cliente = @CLIENTE)
    BEGIN RAISERROR('La nota que respondes no existe.', 16, 1); RETURN -1; END

    INSERT INTO [dbo].[Bitacora]
           (bit_cliente, bit_cliente_instalacion, bit_instalacion_area, bit_bitacora_tipo, bit_activo,
            bit_activo_componente, bit_orden_trabajo, bit_titulo, bit_texto, bit_fecha_evento_utc,
            bit_requiere_atencion, bit_entrada_modo, bit_offline_creado, bit_usuario_creacion, bit_padre)
    SELECT  p.bit_cliente, p.bit_cliente_instalacion, p.bit_instalacion_area, p.bit_bitacora_tipo, p.bit_activo,
            p.bit_activo_componente, p.bit_orden_trabajo, NULL, LTRIM(RTRIM(@TEXTO)), GETUTCDATE(),
            0, 1, 0, @USUARIO, p.bit_id
    FROM    [dbo].[Bitacora] p
    WHERE   p.bit_id = @PADRE;

    SET @ID = SCOPE_IDENTITY();
    RETURN 0;
END
GO

DECLARE @sql NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_BITACORA'))
IF @sql NOT LIKE N'%bit_padre%'
BEGIN
    SET @sql = REPLACE(@sql, N'SELECT  b.bit_id,', N'SELECT  b.bit_id, b.bit_padre AS PADRE,')
    SET @sql = REPLACE(REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE'), N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
    EXEC (@sql)
END
GO

SELECT CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_BITACORA')) LIKE N'%bit_padre AS PADRE%' THEN 'OK' ELSE 'FALTA' END AS SEL_BITACORA,
       CASE WHEN COL_LENGTH('dbo.Bitacora', 'bit_padre') IS NOT NULL THEN 'OK' ELSE 'FALTA' END AS COLUMNA
GO
