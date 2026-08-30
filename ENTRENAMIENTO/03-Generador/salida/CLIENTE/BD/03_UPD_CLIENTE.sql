USE [SIGMA]
GO
/****** Objeto:  StoredProcedure [dbo].[UPD_CLIENTE]    Fecha de script: 14-08-2026 19:47:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO CODIGO CREATIVO
-- FECHA CREACION:  14-08-2026
-- DESCRIPTION:     ACTUALIZA EL CLIENTE EXISTENTE.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPD_CLIENTE]
    @ID         INT,
    @NOMBRE     NVARCHAR(200) = NULL,
    @HABILITADO BIT           = NULL,
    @USUARIO    INT

AS
SET NOCOUNT ON

-- ---------------------------------------------------------------------------
-- PATRON: PATRON_SP.md seccion 5.
--  1. @ID y @USUARIO son OBLIGATORIOS. El resto es opcional.
--  2. Cada columna se actualiza con ISNULL(@PARAM, columna_actual):
--     eso permite updates PARCIALES con un solo SP (ej: solo @HABILITADO).
--  3. La auditoria de actualizacion se pisa siempre; la de creacion nunca.
-- ---------------------------------------------------------------------------

BEGIN TRANSACTION

    UPDATE  CLIENTE
    SET     CLI_NOMBRE      = ISNULL(@NOMBRE,     CLI_NOMBRE)
           ,CLI_HABILITADO  = ISNULL(@HABILITADO, CLI_HABILITADO)
           ,CLI_USUARIO_ACT = @USUARIO
           ,CLI_FECHA_ACT   = GETDATE()
    WHERE   CLI_ID = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION

        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'UPD_CLIENTE ' +
                         '@ID = ' + LTRIM(STR(@ID)) + ',' +
                         '@HABILITADO = ' + LTRIM(STR(CONVERT(INT, @HABILITADO)))

        EXEC INS_EXCEPCION
            @MSG = '1.- NO FUE POSIBLE ACTUALIZAR EL CLIENTE.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO
