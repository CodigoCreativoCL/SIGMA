USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  22-09-2026
-- DESCRIPTION:     SPRINT 4 (HU-103) Ejecutar una tarea en terreno.
--                  T-4238 SEL_TAREA_EJECUCION (lo que baja al telefono).
--                  T-4240 datos de prueba en Tarea_Ejecucion.
--
-- LO QUE YA ESTABA (verificado, no se toca)
--   T-4237 Modelo/indices: Tarea_Ejecucion existe. Su clave natural es el UUID
--          del telefono (UX_TEJ_UUID), no un codigo por cliente; ese indice
--          unico hace idempotente la recepcion. La tabla no tiene columna de
--          cliente: el cliente sale por tej_tarea_ocurrencia -> Tarea_Ocurrencia.
--   T-4239 API_UPS_TAREA_EJECUCION existe y es idempotente por UUID (busca la
--          ejecucion por uuid ANTES de mirar el estado; el reenvio de un cierre
--          ya grabado devuelve lo mismo en vez de un error falso).
--
-- SEGURIDAD (T-4248), A NIVEL DE DATOS
--   "Su planta": no basta con ser del cliente; el usuario tiene que estar
--   asignado a la instalacion (planta) de la tarea. Se comprueba con
--   Cliente_Instalacion_Usuario, el mismo join que usa el upsert. Asi un
--   usuario no baja ejecuciones de una planta a la que no pertenece.
--
-- REAPLICABLE (CREATE OR ALTER + datos idempotentes por UUID).
-- =============================================

SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- T-4238) SEL_TAREA_EJECUCION - descarga para el dispositivo: las ejecuciones
--         del usuario, en su cliente y en las plantas donde esta asignado.
--         @DESDE trae solo lo posterior (sincronizacion incremental).
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_TAREA_EJECUCION]
    @USUARIO INT,
    @CLIENTE INT,
    @DESDE   DATETIME = NULL
AS
SET NOCOUNT ON

SELECT  tej.tej_id                     AS ID,
        tej.tej_uuid                   AS UUID,
        tej.tej_tarea_ocurrencia       AS TAREA_OCURRENCIA,
        toc.toc_tarea                  AS TAREA,
        tar.tar_codigo                 AS TAREA_CODIGO,
        tej.tej_usuario_ejecutor       AS USUARIO_EJECUTOR,
        tej.tej_fecha_inicio_utc       AS FECHA_INICIO_UTC,
        tej.tej_fecha_fin_utc          AS FECHA_FIN_UTC,
        tej.tej_duracion_minuto        AS DURACION_MINUTO,
        tej.tej_resultado              AS RESULTADO,
        tej.tej_conforme               AS CONFORME,
        tej.tej_latitud                AS LATITUD,
        tej.tej_longitud               AS LONGITUD,
        tej.tej_dispositivo            AS DISPOSITIVO,
        tej.tej_offline_creado         AS OFFLINE_CREADO,
        tej.tej_fecha_sincronizacion_utc AS FECHA_SINCRONIZACION_UTC,
        tej.tej_fecha_creacion         AS FECHA_CREACION
FROM    [dbo].[Tarea_Ejecucion]  tej
JOIN    [dbo].[Tarea_Ocurrencia] toc ON toc.toc_id = tej.tej_tarea_ocurrencia
JOIN    [dbo].[Tarea]            tar ON tar.tar_id = toc.toc_tarea
LEFT JOIN [dbo].[Activo]         act ON act.act_id = tar.tar_activo
WHERE   toc.toc_cliente = @CLIENTE
  AND   tej.tej_habilitado = 1
  AND   tej.tej_usuario_ejecutor = @USUARIO
  AND   EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                 WHERE ciu.ciu_id_instalacion = ISNULL(tar.tar_cliente_instalacion, act.act_cliente_instalacion)
                   AND ciu.ciu_id_usuario = @USUARIO
                   AND ISNULL(ciu.ciu_habilitado, 0) = 1)
  AND   (@DESDE IS NULL OR tej.tej_fecha_creacion > @DESDE)
ORDER BY tej.tej_fecha_creacion
GO

-- ---------------------------------------------------------------------------
-- T-4240) Datos de prueba: una ejecucion cerrada del usuario 7 sobre la
--         ocurrencia 1 (planta autorizada), con UUID fijo. Idempotente.
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Ejecucion] WHERE tej_uuid = 'E1111111-1111-1111-1111-111111111111')
   AND EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia] WHERE toc_id = 1 AND toc_cliente = 1)
BEGIN
    INSERT INTO [dbo].[Tarea_Ejecucion]
        ([tej_uuid], [tej_tarea_ocurrencia], [tej_usuario_ejecutor],
         [tej_fecha_inicio_utc], [tej_fecha_fin_utc], [tej_duracion_minuto],
         [tej_resultado], [tej_conforme], [tej_dispositivo], [tej_offline_creado],
         [tej_fecha_sincronizacion_utc],
         [tej_usuario_creacion], [tej_fecha_creacion], [tej_habilitado])
    VALUES
        ('E1111111-1111-1111-1111-111111111111', 1, 7,
         DATEADD(HOUR, -2, GETUTCDATE()), DATEADD(HOUR, -1, GETUTCDATE()), 60,
         N'Tarea ejecutada en terreno (prueba HU-103): equipo revisado sin observaciones.', 1,
         N'Dispositivo de prueba', 1,
         GETUTCDATE(),
         7, [dbo].[FNC_AHORA](), 1)
END
GO

SELECT 'ejecuciones del usuario 7 (cliente 1)' AS control, COUNT(*) AS valor
FROM   [dbo].[Tarea_Ejecucion] tej
JOIN   [dbo].[Tarea_Ocurrencia] toc ON toc.toc_id = tej.tej_tarea_ocurrencia
WHERE  toc.toc_cliente = 1 AND tej.tej_usuario_ejecutor = 7
GO

PRINT '204_SPRINT4_TAREA_EJECUCION aplicado (SEL + datos).'
GO
