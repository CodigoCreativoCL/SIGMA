USE [SIGMA]
GO
/****** Objeto:  StoredProcedure [dbo].[INS_CLIENTE]    Fecha de script: 14-08-2026 19:47:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO CODIGO CREATIVO
-- FECHA CREACION:  14-08-2026
-- DESCRIPTION:     INSERTA EL CLIENTE Y DEVUELVE EL ID GENERADO.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[INS_CLIENTE]
    @ID         INT           = NULL OUTPUT,
    @NOMBRE     NVARCHAR(200) = NULL,
    @HABILITADO BIT           = 1,
    @USUARIO    INT

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

BEGIN TRANSACTION

    INSERT CLIENTE
        (
            CLI_NOMBRE,
            CLI_HABILITADO,
            CLI_USUARIO_CREACION,
            CLI_FECHA_CREACION,
            CLI_USUARIO_ACT,
            CLI_FECHA_ACT
        )
    VALUES
        (
            @NOMBRE,
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
        SET @VARIABLES = 'INS_CLIENTE ' +
                         '@HABILITADO = ' + LTRIM(STR(CONVERT(INT, @HABILITADO)))

        EXEC INS_EXCEPCION
            @MSG = '1.- NO FUE POSIBLE INSERTAR EL CLIENTE.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO
