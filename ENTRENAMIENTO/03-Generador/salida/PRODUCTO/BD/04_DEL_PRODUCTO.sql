USE [SIGMA]
GO
/****** Objeto:  StoredProcedure [dbo].[DEL_PRODUCTO]    Fecha de script: 14-08-2026 19:31:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO CODIGO CREATIVO
-- FECHA CREACION:  14-08-2026
-- DESCRIPTION:     ELIMINA FISICAMENTE EL PRODUCTO.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[DEL_PRODUCTO]
    @ID INT

AS
SET NOCOUNT ON

-- ---------------------------------------------------------------------------
-- PATRON: PATRON_SP.md seccion 6.
--  1. El DEL_ recibe SOLO @ID.
--  2. IMPORTANTE: PRODUCTO es una tabla MAESTRO. En tablas maestro NO se
--     borra fisico: se da de baja logica con UPD_PRODUCTO @HABILITADO = 0.
--     Por eso el boton del grid llama a DeshabilitarProducto(), no a DeleteProducto().
--     Este SP queda para casos excepcionales y limpieza de datos de prueba.
-- ---------------------------------------------------------------------------

BEGIN TRANSACTION

    DELETE  PRODUCTO
    WHERE   PRO_ID = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION

        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'DEL_PRODUCTO ' + LTRIM(STR(@ID))

        EXEC INS_EXCEPCION
            @MSG = '1.- NO FUE POSIBLE ELIMINAR EL PRODUCTO.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO
