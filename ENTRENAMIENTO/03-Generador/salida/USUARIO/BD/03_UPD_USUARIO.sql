USE [SIGMA]
GO
/****** Objeto:  StoredProcedure [dbo].[UPD_USUARIO]    Fecha de script: 14-08-2026 19:31:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO CODIGO CREATIVO
-- FECHA CREACION:  14-08-2026
-- DESCRIPTION:     ACTUALIZA EL USUARIO EXISTENTE.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPD_USUARIO]
    @ID         INT,
    @RUT        NVARCHAR(12)  = NULL,
    @NOMBRES    NVARCHAR(200) = NULL,
    @APELLIDOS  NVARCHAR(200) = NULL,
    @EMAIL      NVARCHAR(200) = NULL,
    @TELEFONO   NVARCHAR(20)  = NULL,
    @PASSWORD   NVARCHAR(200) = NULL,
    @PERFIL     INT           = NULL,
    @PAIS       INT           = NULL,
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

-- Validaciones: los campos unicos siguen siendo unicos,
-- excluyendo al propio registro que se esta editando.
BEGIN
    IF EXISTS (SELECT 1 FROM USUARIO WHERE USU_RUT = @RUT AND USU_ID <> @ID)
    BEGIN
        RAISERROR('1.- Ya existe otro usuario con rut "%s".', 16, 1, @RUT)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM USUARIO WHERE USU_EMAIL = @EMAIL AND USU_ID <> @ID)
    BEGIN
        RAISERROR('2.- Ya existe otro usuario con email "%s".', 16, 1, @EMAIL)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  USUARIO
    SET     USU_RUT         = ISNULL(@RUT,        USU_RUT)
           ,USU_NOMBRES     = ISNULL(@NOMBRES,    USU_NOMBRES)
           ,USU_APELLIDOS   = ISNULL(@APELLIDOS,  USU_APELLIDOS)
           ,USU_EMAIL       = ISNULL(@EMAIL,      USU_EMAIL)
           ,USU_TELEFONO    = ISNULL(@TELEFONO,   USU_TELEFONO)
           ,USU_PASSWORD    = ISNULL(@PASSWORD,   USU_PASSWORD)
           ,USU_PERFIL      = ISNULL(@PERFIL,     USU_PERFIL)
           ,USU_PAIS        = ISNULL(@PAIS,       USU_PAIS)
           ,USU_HABILITADO  = ISNULL(@HABILITADO, USU_HABILITADO)
           ,USU_USUARIO_ACT = @USUARIO
           ,USU_FECHA_ACT   = GETDATE()
    WHERE   USU_ID = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION

        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'UPD_USUARIO ' +
                         '@ID = ' + LTRIM(STR(@ID)) + ',' +
                         '@RUT = ' + ISNULL(@RUT, '') + ',' +
                         '@NOMBRES = ' + ISNULL(@NOMBRES, '')

        EXEC INS_EXCEPCION
            @MSG = '3.- NO FUE POSIBLE ACTUALIZAR EL USUARIO.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO
