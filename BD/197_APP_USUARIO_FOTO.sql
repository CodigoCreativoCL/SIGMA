USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     LA RUTA DE LA FOTO DE UN USUARIO, PARA EL AVATAR.
-- =============================================
-- POR QUE UN SP APARTE Y NO UNA COLUMNA MAS EN SEL_USUARIO
--
--   SEL_USUARIO lo usan los mantenedores de la web y arma su consulta con SQL
--   dinamico. Un JOIN mas a Archivo le costaria a toda pantalla que liste
--   usuarios, para un dato que solo mira el avatar. Es el mismo razonamiento
--   por el que API_SEL_ACTIVO_FOTO existe separado de SEL_ACTIVO.
--
--   Ademas SEL_USUARIO ya tiene @DEVUELVE_FOTO, que devuelve el BINARIO. Eso
--   sirve en la web, donde la imagen se pinta en la misma pagina; en la app no,
--   porque el binario dentro del JSON de la sesion son cientos de kilobytes en
--   cada arranque. La app quiere la RUTA y la baja por /archivo/ver, que ya
--   cachea y deduplica.
--
-- HOY NO HAY NINGUNA FOTO CARGADA
--
--   0 usuarios con usu_archivo_foto. El SP devuelve una fila sin ruta y la app
--   pinta las iniciales, que es el respaldo previsto y lo que se va a ver hasta
--   que alguien suba fotos desde la web. No es un fallo: es el estado del dato.
-- =============================================
SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[API_SEL_APP_USUARIO_FOTO]
@USUARIO INT,
@CLIENTE INT
AS
SET NOCOUNT ON

    SELECT  USU.usu_id                AS usu_id,
            ARC.arc_ruta              AS FOTO_RUTA
    FROM    [dbo].[Usuario] USU
    LEFT JOIN [dbo].[Archivo] ARC ON ARC.arc_id = USU.usu_archivo_foto
                                 AND ARC.arc_cliente = @CLIENTE
    WHERE   USU.usu_id = @USUARIO
GO

-- Verificacion
EXEC [dbo].[API_SEL_APP_USUARIO_FOTO] @USUARIO = 8, @CLIENTE = 1
GO
