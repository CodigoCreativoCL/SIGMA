USE [SIGMA]
GO
/****** Objeto:  StoredProcedure [dbo].[INS_USUARIO]    Fecha de script: 14-08-2026 19:31:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO CODIGO CREATIVO
-- FECHA CREACION:  14-08-2026
-- DESCRIPTION:     INSERTA EL USUARIO Y DEVUELVE EL ID GENERADO.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[INS_USUARIO]
    @ID         INT           = NULL OUTPUT,
    @RUT        NVARCHAR(12),
    @NOMBRES    NVARCHAR(200),
    @APELLIDOS  NVARCHAR(200),
    @EMAIL      NVARCHAR(200),
    @TELEFONO   NVARCHAR(20)  = NULL,
    @PASSWORD   NVARCHAR(200),
    @PERFIL     INT,
    @PAIS       INT,
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

-- Validaciones
BEGIN
    IF EXISTS (SELECT 1 FROM USUARIO WHERE USU_RUT = @RUT)
    BEGIN
        RAISERROR('1.- Ya existe un usuario con rut "%s".', 16, 1, @RUT)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM USUARIO WHERE USU_EMAIL = @EMAIL)
    BEGIN
        RAISERROR('2.- Ya existe un usuario con email "%s".', 16, 1, @EMAIL)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT USUARIO
        (
            USU_RUT,
            USU_NOMBRES,
            USU_APELLIDOS,
            USU_EMAIL,
            USU_TELEFONO,
            USU_PASSWORD,
            USU_PERFIL,
            USU_PAIS,
            USU_HABILITADO,
            USU_USUARIO_CREACION,
            USU_FECHA_CREACION,
            USU_USUARIO_ACT,
            USU_FECHA_ACT
        )
    VALUES
        (
            @RUT,
            @NOMBRES,
            @APELLIDOS,
            @EMAIL,
            @TELEFONO,
            @PASSWORD,
            @PERFIL,
            @PAIS,
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
        SET @VARIABLES = 'INS_USUARIO ' +
                         '@RUT = ' + ISNULL(@RUT, '') + ',' +
                         '@NOMBRES = ' + ISNULL(@NOMBRES, '') + ',' +
                         '@APELLIDOS = ' + ISNULL(@APELLIDOS, '')

        EXEC INS_EXCEPCION
            @MSG = '3.- NO FUE POSIBLE INSERTAR EL USUARIO.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO
