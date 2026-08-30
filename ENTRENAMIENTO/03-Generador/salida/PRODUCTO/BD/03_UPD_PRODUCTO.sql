USE [SIGMA]
GO
/****** Objeto:  StoredProcedure [dbo].[UPD_PRODUCTO]    Fecha de script: 14-08-2026 19:31:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO CODIGO CREATIVO
-- FECHA CREACION:  14-08-2026
-- DESCRIPTION:     ACTUALIZA EL PRODUCTO EXISTENTE.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPD_PRODUCTO]
    @ID          INT,
    @CODIGO      NVARCHAR(20)  = NULL,
    @NOMBRE      NVARCHAR(200) = NULL,
    @DESCRIPCION NVARCHAR(MAX) = NULL,
    @CATEGORIA   INT           = NULL,
    @PROVEEDOR   INT           = NULL,
    @PRECIO      DECIMAL(18,2) = NULL,
    @STOCK       INT           = NULL,
    @VENCIMIENTO DATETIME      = NULL,
    @HABILITADO  BIT           = NULL,
    @USUARIO     INT

AS
SET NOCOUNT ON

-- ---------------------------------------------------------------------------
-- PATRON: PATRON_SP.md seccion 5.
--  1. @ID y @USUARIO son OBLIGATORIOS. El resto es opcional.
--  2. Cada columna se actualiza con ISNULL(@PARAM, columna_actual):
--     eso permite updates PARCIALES con un solo SP (ej: solo @HABILITADO).
--  3. La auditoria de actualizacion se pisa siempre; la de creacion nunca.
-- ---------------------------------------------------------------------------

-- Validaciones: los campos unicos siguen siendo unicos,
-- excluyendo al propio registro que se esta editando.
BEGIN
    IF EXISTS (SELECT 1 FROM PRODUCTO WHERE PRO_CODIGO = @CODIGO AND PRO_ID <> @ID)
    BEGIN
        RAISERROR('1.- Ya existe otro producto con codigo "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM PRODUCTO WHERE PRO_NOMBRE = @NOMBRE AND PRO_ID <> @ID)
    BEGIN
        RAISERROR('2.- Ya existe otro producto con nombre "%s".', 16, 1, @NOMBRE)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  PRODUCTO
    SET     PRO_CODIGO      = ISNULL(@CODIGO,      PRO_CODIGO)
           ,PRO_NOMBRE      = ISNULL(@NOMBRE,      PRO_NOMBRE)
           ,PRO_DESCRIPCION = ISNULL(@DESCRIPCION, PRO_DESCRIPCION)
           ,PRO_CATEGORIA   = ISNULL(@CATEGORIA,   PRO_CATEGORIA)
           ,PRO_PROVEEDOR   = ISNULL(@PROVEEDOR,   PRO_PROVEEDOR)
           ,PRO_PRECIO      = ISNULL(@PRECIO,      PRO_PRECIO)
           ,PRO_STOCK       = ISNULL(@STOCK,       PRO_STOCK)
           ,PRO_VENCIMIENTO = ISNULL(@VENCIMIENTO, PRO_VENCIMIENTO)
           ,PRO_HABILITADO  = ISNULL(@HABILITADO,  PRO_HABILITADO)
           ,PRO_USUARIO_ACT = @USUARIO
           ,PRO_FECHA_ACT   = GETDATE()
    WHERE   PRO_ID = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION

        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'UPD_PRODUCTO ' +
                         '@ID = ' + LTRIM(STR(@ID)) + ',' +
                         '@CODIGO = ' + ISNULL(@CODIGO, '') + ',' +
                         '@NOMBRE = ' + ISNULL(@NOMBRE, '')

        EXEC INS_EXCEPCION
            @MSG = '3.- NO FUE POSIBLE ACTUALIZAR EL PRODUCTO.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO
