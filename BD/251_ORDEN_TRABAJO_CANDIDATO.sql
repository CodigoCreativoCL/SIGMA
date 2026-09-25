/* ============================================================================
   SIGMA — Bloque 251
   QUIEN ES CANDIDATO PARA UNA ORDEN                                  HU-017 #1
   ----------------------------------------------------------------------------

   "Cuando asigno una especialidad a un tecnico, esa persona aparece como
   candidata cuando una orden requiere esa especialidad." El modal de
   asignacion listaba a todos los usuarios del cliente con su perfil, sin
   decir quien tiene lo que la orden pide. Este SP entrega la lista ORDENADA
   por candidatura: primero quienes tienen todas las especialidades que la
   orden exige (con su certificacion vigente), despues los que las tienen
   vencidas, al final el resto; cada fila dice sus especialidades y, si
   corresponde, la fecha en que vencio la certificacion. La pantalla lo
   pinta; la regla vive aqui.

   Se apoya en SEL_USUARIO_CLIENTE_LISTA (bloque 47) y en
   Orden_Trabajo_Especialidad. IDEMPOTENTE.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ORDEN_TRABAJO_CANDIDATO]
     @CLIENTE INT
    ,@ORDEN   INT
AS
SET NOCOUNT ON
    DECLARE @HOY DATE = CAST([dbo].[FNC_PAIS_HORA]((SELECT cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE)) AS DATE)
    DECLARE @REQUERIDAS INT = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Especialidad] WHERE oep_orden_trabajo = @ORDEN)

    SELECT  u.usu_id                                            AS USU_ID
           ,u.usu_nombre + SPACE(1) + u.usu_apellido_paterno    AS USU_NOMBRE
           ,ISNULL(pf.PERFILES, '')                             AS PERFILES
           ,ISNULL(es.ESPECIALIDADES, '')                       AS ESPECIALIDADES
           ,@REQUERIDAS                                         AS REQUERIDAS
           ,ISNULL(cu.CUBIERTAS, 0)                             AS CUBIERTAS
           ,CASE WHEN @REQUERIDAS > 0 AND ISNULL(cu.CUBIERTAS, 0) = @REQUERIDAS THEN 1 ELSE 0 END AS CANDIDATO
           ,cu.VENCIDAS                                         AS CERTIFICACION_VENCIDA
    FROM    [dbo].[Cliente_Usuario] cuu
    JOIN    [dbo].[Usuario] u ON u.usu_id = cuu.ucl_id_usuario
    OUTER APPLY (SELECT STRING_AGG(p.per_nombre, ', ') WITHIN GROUP (ORDER BY p.per_nombre) AS PERFILES
                   FROM [dbo].[Cliente_Usuario_Perfil] cup JOIN [dbo].[Perfiles] p ON p.per_id = cup.cup_id_perfil
                  WHERE cup.cup_id_cliente_usuario = cuu.ucl_id AND p.per_habilitado = 1) pf
    OUTER APPLY (SELECT STRING_AGG(e2.esp_nombre + CASE WHEN ue.ues_fecha_vencimiento IS NOT NULL AND ue.ues_fecha_vencimiento < @HOY
                                                         THEN N' (cert. vencida ' + CONVERT(NVARCHAR(10), ue.ues_fecha_vencimiento, 103) + N')' ELSE N'' END, ', ')
                        WITHIN GROUP (ORDER BY e2.esp_nombre) AS ESPECIALIDADES
                   FROM [dbo].[Usuario_Especialidad] ue JOIN [dbo].[Especialidad] e2 ON e2.esp_id = ue.ues_especialidad
                  WHERE ue.ues_usuario = u.usu_id AND ue.ues_cliente = @CLIENTE AND ue.ues_habilitado = 1 AND e2.esp_habilitado = 1) es
    OUTER APPLY (SELECT COUNT(*) AS CUBIERTAS
                       ,STRING_AGG(CASE WHEN ue.ues_fecha_vencimiento IS NOT NULL AND ue.ues_fecha_vencimiento < @HOY
                                        THEN e.esp_nombre + N' vencida el ' + CONVERT(NVARCHAR(10), ue.ues_fecha_vencimiento, 103) END, ', ') AS VENCIDAS
                   FROM [dbo].[Orden_Trabajo_Especialidad] oe
                   JOIN [dbo].[Especialidad] e ON e.esp_id = oe.oep_especialidad
                   JOIN [dbo].[Usuario_Especialidad] ue ON ue.ues_usuario = u.usu_id AND ue.ues_especialidad = oe.oep_especialidad
                                                        AND ue.ues_cliente = @CLIENTE AND ue.ues_habilitado = 1
                  WHERE oe.oep_orden_trabajo = @ORDEN) cu
    WHERE   cuu.ucl_id_cliente = @CLIENTE
      AND   ISNULL(cuu.ucl_habilitado, 0) = 1
      AND   u.usu_habilitado = 1
    ORDER BY CASE WHEN @REQUERIDAS > 0 AND ISNULL(cu.CUBIERTAS, 0) = @REQUERIDAS AND cu.VENCIDAS IS NULL THEN 0
                  WHEN @REQUERIDAS > 0 AND ISNULL(cu.CUBIERTAS, 0) = @REQUERIDAS THEN 1
                  WHEN ISNULL(cu.CUBIERTAS, 0) > 0 THEN 2 ELSE 3 END,
             u.usu_apellido_paterno, u.usu_nombre
GO
PRINT '--- SEL_ORDEN_TRABAJO_CANDIDATO creado (bloque 251).'
GO
