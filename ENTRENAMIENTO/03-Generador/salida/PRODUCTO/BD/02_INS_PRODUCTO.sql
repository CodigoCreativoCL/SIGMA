USE [SIGMA]
GO
/****** Objeto:  StoredProcedure [dbo].[INS_PRODUCTO]    Fecha de script: 14-08-2026 19:31:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO CODIGO CREATIVO
-- FECHA CREACION:  14-08-2026
-- DESCRIPTION:     INSERTA EL PRODUCTO Y DEVUELVE EL ID GENERADO.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[INS_PRODUCTO]
    @ID          INT           = NULL OUTPUT,
    @CODIGO      NVARCHAR(20),
    @NOMBRE      NVARCHAR(200),
    @DESCRIPCION NVARCHAR(MAX) = NULL,
    @CATEGORIA   INT,
    @PROVEEDOR   INT           = NULL,
    @PRECIO      DECIMAL(18,2),
    @STOCK       INT           = NULL,
    @VENCIMIENTO DATETIME      = NULL,
    @HABILITADO  BIT           = 1,
    @USUARIO     INT

AS
SET NOCOUNT ON

-- ---------------------------------------------------------------------------
-- PATRON: PATRON_SP.md seccion 3.
--  1. @ID INT = NULL OUTPUT primero: devuelve SCOPE_IDENTITY() al C#.
--  2. Validaciones de negocio ANTES del BEGIN TRANSACTION (RAISERROR + RETURN -1).
--     Ese texto es el que ve el usuario final en el ClientAlert.
--  3. Si @@ROWCOUNT = 0 -> ROLLBACK + EXEC INS_EXCEPCION.
--  4. @USUARIO NUNCA lo manda la pantalla: sale de Session.UsuarioId().
-- ---------------------------------------------------------------------------

-- Validaciones
BEGIN
    IF EXISTS (SELECT 1 FROM PRODUCTO WHERE PRO_CODIGO = @CODIGO)
    BEGIN
        RAISERROR('1.- Ya existe un producto con codigo "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM PRODUCTO WHERE PRO_NOMBRE = @NOMBRE)
    BEGIN
        RAISERROR('2.- Ya existe un producto con nombre "%s".', 16, 1, @NOMBRE)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT PRODUCTO
        (
            PRO_CODIGO,
            PRO_NOMBRE,
            PRO_DESCRIPCION,
            PRO_CATEGORIA,
            PRO_PROVEEDOR,
            PRO_PRECIO,
            PRO_STOCK,
            PRO_VENCIMIENTO,
            PRO_HABILITADO,
            PRO_USUARIO_CREACION,
            PRO_FECHA_CREACION,
            PRO_USUARIO_ACT,
            PRO_FECHA_ACT
        )
    VALUES
        (
            @CODIGO,
            @NOMBRE,
            @DESCRIPCION,
            @CATEGORIA,
            @PROVEEDOR,
            @PRECIO,
            @STOCK,
            @VENCIMIENTO,
            @HABILITADO,
            @USUARIO,
            GETDATE(),
            @USUARIO,
            GETDATE()
        )

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION

        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'INS_PRODUCTO ' +
                         '@CODIGO = ' + ISNULL(@CODIGO, '') + ',' +
                         '@NOMBRE = ' + ISNULL(@NOMBRE, '') + ',' +
                         '@CATEGORIA = ' + LTRIM(STR(@CATEGORIA))

        EXEC INS_EXCEPCION
            @MSG = '3.- NO FUE POSIBLE INSERTAR EL PRODUCTO.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO
