USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     MODULO SOPORTE: consultas auxiliares de las pantallas.
-- =============================================
-- Va DESPUES de 363_SOPORTE_ALERTAS.
-- =============================================

SET NOCOUNT ON
GO

/* ¿Puede esta persona tocar este ticket? Sin efectos: el 360 marca leido y
   esto lo usa la subida de adjuntos. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_SOPORTE_TICKET_ACCESO]
    @TICKET  INT,
    @USUARIO INT
AS
SET NOCOUNT ON
    SELECT  t.stk_id, t.stk_cliente, t.stk_estado
    FROM    [dbo].[Soporte_Ticket] t
    WHERE   t.stk_id = @TICKET AND t.stk_habilitado = 1
      AND   (t.stk_usuario = @USUARIO OR [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO) = 1)
GO

/* Para «Nuevo problema» de soporte: en nombre de quien. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_SOPORTE_USUARIOS_CLIENTE]
    @USUARIO INT,
    @CLIENTE INT
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO) = 0
    BEGIN RAISERROR(N'Solo soporte puede registrar problemas en nombre de otra persona.', 16, 1) RETURN END

    SELECT  u.usu_id, [dbo].[FNC_SOPORTE_NOMBRE](u.usu_id) AS NOMBRE,
            PERFIL = (SELECT STRING_AGG(CAST(pe.per_nombre AS NVARCHAR(200)), ', ')
                        FROM [dbo].[Cliente_Usuario_Perfil] cup JOIN [dbo].[Perfiles] pe ON pe.per_id = cup.cup_id_perfil
                       WHERE cup.cup_id_cliente_usuario = cu.ucl_id)
    FROM    [dbo].[Cliente_Usuario] cu
    JOIN    [dbo].[Usuario] u ON u.usu_id = cu.ucl_id_usuario
    WHERE   cu.ucl_id_cliente = @CLIENTE AND ISNULL(cu.ucl_habilitado, 0) = 1 AND ISNULL(u.usu_habilitado, 0) = 1
    ORDER BY NOMBRE
GO

/* Lo que el master necesita para la cabecera: la planta de la persona (la
   primera vigente en este cliente) y su perfil, para el contexto del
   reporte, y cuantos problemas suyos esperan algo de ella. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_SOPORTE_CABECERA]
    @USUARIO INT,
    @CLIENTE INT
AS
SET NOCOUNT ON
    SELECT  PLANTA_ID = (SELECT TOP 1 cin.cin_id FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                           JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = ciu.ciu_id_instalacion
                          WHERE ciu.ciu_id_usuario = @USUARIO AND cin.cin_cliente = @CLIENTE AND ISNULL(ciu.ciu_habilitado, 0) = 1
                          ORDER BY cin.cin_id),
            PLANTA = (SELECT TOP 1 cin.cin_nombre COLLATE DATABASE_DEFAULT FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                        JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = ciu.ciu_id_instalacion
                       WHERE ciu.ciu_id_usuario = @USUARIO AND cin.cin_cliente = @CLIENTE AND ISNULL(ciu.ciu_habilitado, 0) = 1
                       ORDER BY cin.cin_id),
            PERFIL = ISNULL((SELECT STRING_AGG(CAST(pe.per_nombre AS NVARCHAR(200)), ', ')
                               FROM [dbo].[Cliente_Usuario] cu
                               JOIN [dbo].[Cliente_Usuario_Perfil] cup ON cup.cup_id_cliente_usuario = cu.ucl_id
                               JOIN [dbo].[Perfiles] pe ON pe.per_id = cup.cup_id_perfil
                              WHERE cu.ucl_id_usuario = @USUARIO AND cu.ucl_id_cliente = @CLIENTE),
                            (SELECT TOP 1 pe.per_nombre COLLATE DATABASE_DEFAULT FROM [dbo].[Usuario_Perfil] up
                               JOIN [dbo].[Perfiles] pe ON pe.per_id = up.upe_perfil AND pe.per_tipo = 1
                              WHERE up.upe_usuario = @USUARIO)),
            ESPERAN = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] t
                        WHERE t.stk_usuario = @USUARIO AND t.stk_habilitado = 1
                          AND (t.stk_estado = 'esp'
                               OR (t.stk_estado = 'res' AND NOT EXISTS (SELECT 1 FROM [dbo].[Soporte_Encuesta] s
                                                                        WHERE s.sen_ticket = t.stk_id AND s.sen_fecha >= t.stk_fecha_resolucion))))
GO
