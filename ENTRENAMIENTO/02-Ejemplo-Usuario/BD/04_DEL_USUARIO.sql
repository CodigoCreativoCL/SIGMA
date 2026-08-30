USE [SIGMA]
GO
/****** Objeto:  StoredProcedure [dbo].[DEL_USUARIO]    Fecha de script: 14-08-2026 10:00:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO CODIGO CREATIVO
-- FECHA CREACION:  14-08-2026
-- DESCRIPTION:     ELIMINA FISICAMENTE UN USUARIO. USO EXCEPCIONAL.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[DEL_USUARIO]
    @ID INT

AS
SET NOCOUNT ON

-- ---------------------------------------------------------------------------
-- REGLAS DEL PATRON (ver PATRON_SP.md seccion 6):
--
--  1. El DEL_ recibe SOLO @ID.
--  2. IMPORTANTE PARA EL EQUIPO: USUARIO es una tabla MAESTRO.
--     En tablas maestro NO se borra fisico: se da de baja logica con
--     UPD_USUARIO @HABILITADO = 0. Por eso el boton del grid llama a
--     DeshabilitarUsuario(), no a DeleteUsuario().
--     El borrado fisico se reserva para tablas de DETALLE o RELACION
--     (ej. USUARIO_INSTALACION) y para limpiar datos de prueba.
--  3. Mismo manejo de error que INSERT/UPDATE.
-- ---------------------------------------------------------------------------

BEGIN TRANSACTION

    DELETE  USUARIO
    WHERE   USU_ID = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION

        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'DEL_USUARIO ' + LTRIM(STR(@ID))

        EXEC INS_EXCEPCION
            @MSG = '1.- NO FUE POSIBLE ELIMINAR EL USUARIO.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO
