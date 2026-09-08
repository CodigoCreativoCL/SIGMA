USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     EL TELEFONO NO SE BORRA CUANDO NO VIENE.
-- =============================================
-- HU-005. El SP asignaba usu_telefono = @TELEFONO sin ISNULL, mientras que la
-- linea de abajo si protege el idioma con ISNULL(@IDIOMA, usu_idioma). Esa
-- diferencia no era una decision: era un descuido, y convierte cualquier
-- llamada parcial en un borrado.
--
-- PUT /mi-perfil acepta los dos campos como opcionales. Cambiar solo el idioma
-- -o mandar el nombre de propiedad equivocado, que es como se detecto- dejaba
-- @TELEFONO en NULL y borraba el numero de contacto de la persona. Y el
-- telefono es por donde se le avisa cuando algo se cae en su turno: perderlo
-- en silencio significa que el aviso no llega y nadie sabe por que.
--
-- Con ISNULL, quien manda un telefono lo guarda igual que antes; quien no lo
-- manda, deja el que estaba. La web llama siempre con el valor del formulario,
-- asi que para ella no cambia nada.
--
-- Se pierde poder BORRAR el telefono mandando NULL. Ninguna pantalla lo hace
-- -ni la web ni la app tienen ese boton-, y una cadena vacia sigue sirviendo
-- para dejarlo en blanco a proposito.
-- =============================================
SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_USUARIO_MI_PERFIL]
@USUARIO   INT,
@TELEFONO  VARCHAR(50) = NULL,
@IDIOMA    INT = NULL,
@FOTO      VARBINARY(MAX) = NULL,
@CAMBIA_FOTO BIT = 0

AS
SET NOCOUNT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Usuario]
    SET     usu_telefono   = ISNULL(@TELEFONO, usu_telefono)
           ,usu_idioma     = ISNULL(@IDIOMA, usu_idioma)
           ,usu_foto       = CASE WHEN @CAMBIA_FOTO = 1 THEN @FOTO ELSE usu_foto END
           ,usu_usuario_act = @USUARIO
           ,usu_fecha_act   = GETDATE()
    WHERE   usu_id = @USUARIO

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_USUARIO_MI_PERFIL @USUARIO = ' + LTRIM(STR(@USUARIO))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '1.- NO FUE POSIBLE ACTUALIZAR EL PERFIL.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO
