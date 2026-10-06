USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     SESION PERSISTENTE: la sesion dura hasta que la persona
--                  la cierra.
-- =============================================
-- La sesion del servidor se pierde al reciclar la aplicacion (InProc en el
-- hosting) o tras 30 minutos sin uso. La web guarda una cookie firmada con
-- usuario y cliente y, cuando la sesion se pierde, la reconstruye. Este SP
-- dice con que cliente rearmarla: el nombre, y solo si la persona sigue
-- perteneciendo a el (o es de plataforma, que entra a cualquiera).
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[SEL_SESION_RESTAURAR]
    @USUARIO INT,
    @CLIENTE INT
AS
SET NOCOUNT ON
    SELECT  cl.cli_id, cl.cli_nombre
    FROM    [dbo].[Cliente] cl
    WHERE   cl.cli_id = @CLIENTE
      AND   (EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario] cu
                      WHERE cu.ucl_id_cliente = cl.cli_id AND cu.ucl_id_usuario = @USUARIO AND ISNULL(cu.ucl_habilitado, 0) = 1)
             OR EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil] up JOIN [dbo].[Perfiles] pe ON pe.per_id = up.upe_perfil AND pe.per_tipo = 1
                         WHERE up.upe_usuario = @USUARIO))
GO
