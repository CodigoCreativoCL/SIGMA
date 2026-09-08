USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  07-09-2026
-- DESCRIPTION:     LOS CLIENTES A LOS QUE PERTENECE LA PERSONA, CON SU LOGO.
-- =============================================
-- POR QUE HIZO FALTA
--
--   `GET /cliente-usuarios/mis-clientes` resolvia con `SEL_CLIENTE @USUARIO`,
--   y ese filtro NO filtra: llamandolo con el usuario de Jonathan
--   —que pertenece solo a Hamburgo— devuelve tambien CCU. La pantalla de
--   contexto de la app ofrecia entrar a la empresa de otro.
--
--   No es un agujero de seguridad —`POST /cliente-usuarios/seleccionar`
--   revalida la pertenencia contra la base antes de emitir el token, asi que
--   elegir CCU habria fallado— pero si es una fuga de informacion: la lista
--   dice que empresas existen en el sistema. Y en pantalla se ve como un
--   error grave.
--
--   Es el mismo defecto que tenia `SEL_CLIENTE_INSTALACION` con las plantas
--   (ver BD/175): un SP heredado de la web cuyo @USUARIO cuelga de un LEFT
--   JOIN, asi que no restringe nada.
--
-- EL LOGO VA EN LA MISMA CONSULTA
--
--   La pantalla de contexto muestra el logo de la empresa. Pedirlo aparte
--   serian dos viajes de red para dibujar una lista de dos elementos, y el
--   logo llegaria despues de las tarjetas: se veria saltar.
--
--   Va la RUTA del blob, no los bytes: la app la pide por
--   `GET /archivo/ver?ruta=` y la cachea en disco.
--
-- ES IDEMPOTENTE: CREATE OR ALTER.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[API_SEL_APP_CLIENTE]
@USUARIO INT
AS
SET NOCOUNT ON

    SELECT      CLI.cli_id       AS cli_id,
                CLI.cli_nombre   AS cli_nombre,
                ARC.arc_ruta     AS LOGO_RUTA
    FROM        [dbo].[Cliente] CLI
    /* INNER, y este es el punto: sin fila en Cliente_Usuario el cliente no
       sale. Con LEFT JOIN volveriamos al defecto que se esta corrigiendo. */
    JOIN        [dbo].[Cliente_Usuario] UCL
            ON  UCL.ucl_id_cliente = CLI.cli_id
            AND UCL.ucl_id_usuario = @USUARIO
            AND ISNULL(UCL.ucl_habilitado, 0) = 1
    LEFT JOIN   [dbo].[Archivo] ARC
            ON  ARC.arc_id = CLI.cli_archivo_logo
            AND ARC.arc_habilitado = 1
    WHERE       CLI.cli_habilitado = 1
    ORDER BY    CLI.cli_nombre
GO
