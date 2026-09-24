USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     EL DETALLE DETRAS DE LOS NUMEROS DE LA LISTA DE ACTIVOS.
-- =============================================
-- POR QUE
--   La lista dice "3" en OT abiertas y "12 oct 2026" en la proxima
--   mantencion. Los dos son ciertos y los dos obligan a entrar al centro del
--   activo para saber de QUE se trata: cual orden, quien la tiene, que se
--   programo para ese dia.
--
--   Estos dos devuelven ese detalle para TODOS los activos del cliente de
--   una vez. Pedirlo por fila serian veintidos consultas para armar una
--   pantalla, y la lista se abre siempre.
--
--   Cinco por activo: el popover es un adelanto, no la pantalla. Quien
--   necesita las diez entra al centro.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_LISTA_ORDENES]
    @CLIENTE INT
AS
SET NOCOUNT ON

;WITH ordenadas AS (
    SELECT  o.otr_activo                                       AS ACTIVO_ID,
            o.otr_id                                           AS OT_ID,
            o.otr_correlativo                                  AS CORRELATIVO,
            o.otr_titulo                                       AS TITULO,
            e.ote_nombre                                       AS ESTADO,
            e.ote_codigo                                       AS ESTADO_CODIGO,
            o.otr_fecha_programada_utc                          AS FECHA,

            LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' ' +
                        ISNULL(u.usu_apellido_paterno, '')))    AS RESPONSABLE,

            ROW_NUMBER() OVER (PARTITION BY o.otr_activo
                               ORDER BY o.otr_fecha_programada_utc, o.otr_id) AS N

      FROM  [dbo].[Orden_Trabajo] o

            INNER JOIN [dbo].[Orden_Trabajo_Estado] e
                ON e.ote_id = o.otr_orden_trabajo_estado

            LEFT JOIN [dbo].[Usuario] u
                ON u.usu_id = o.otr_usuario_responsable

     WHERE  o.otr_cliente = @CLIENTE
       AND  o.otr_activo IS NOT NULL

       /* Abierta es cualquier estado que no sea cerrada, igual que el
          contador de la lista: los dos numeros tienen que cuadrar. */
       AND  ISNULL(o.otr_orden_trabajo_estado, 0) <> 4
)
SELECT  ACTIVO_ID, OT_ID, CORRELATIVO, TITULO, ESTADO, ESTADO_CODIGO, FECHA, RESPONSABLE
  FROM  ordenadas
 WHERE  N <= 5
 ORDER  BY ACTIVO_ID, N
GO
PRINT '--- SEL_ACTIVO_LISTA_ORDENES creado.'
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_LISTA_AGENDA]
    @CLIENTE INT
AS
SET NOCOUNT ON

DECLARE @HOY DATETIME = [dbo].[FNC_AHORA]()

;WITH proximas AS (
    SELECT  o.pmo_activo                                       AS ACTIVO_ID,
            o.pmo_id                                           AS OCURRENCIA_ID,
            o.pmo_fecha_programada_utc                          AS FECHA,
            h.pmh_nombre                                       AS TITULO,
            pm.pma_nombre                                      AS PLAN_NOMBRE,
            e.poe_nombre                                       AS ESTADO,

            /* Ya tiene orden: el dia esta comprometido, no solo programado. */
            CASE WHEN o.pmo_orden_trabajo IS NULL THEN 0 ELSE 1 END AS CON_ORDEN,
            o.pmo_orden_trabajo                                AS OT_ID,

            ROW_NUMBER() OVER (PARTITION BY o.pmo_activo
                               ORDER BY o.pmo_fecha_programada_utc, o.pmo_id) AS N

      FROM  [dbo].[Plan_Mantenimiento_Ocurrencia] o

            INNER JOIN [dbo].[Plan_Mantenimiento_Hito] h
                ON h.pmh_id = o.pmo_plan_mantenimiento_hito

            INNER JOIN [dbo].[Plan_Mantenimiento_Version] v
                ON v.pmv_id = h.pmh_plan_mantenimiento_version

            INNER JOIN [dbo].[Plan_Mantenimiento] pm
                ON pm.pma_id = v.pmv_plan_mantenimiento

            LEFT JOIN [dbo].[Plan_Ocurrencia_Estado] e
                ON e.poe_id = o.pmo_plan_ocurrencia_estado

     WHERE  o.pmo_cliente = @CLIENTE
       AND  ISNULL(o.pmo_habilitado, 1) = 1

       /* Lo mismo que cuenta la columna "proximo mantenimiento": ni
          completada, ni omitida, ni cancelada, y de hoy en adelante. */
       AND  ISNULL(o.pmo_plan_ocurrencia_estado, 1) NOT IN (4, 5, 6)
       AND  o.pmo_fecha_programada_utc >= @HOY
)
SELECT  ACTIVO_ID, OCURRENCIA_ID, FECHA, TITULO, PLAN_NOMBRE, ESTADO, CON_ORDEN, OT_ID
  FROM  proximas
 WHERE  N <= 5
 ORDER  BY ACTIVO_ID, N
GO
PRINT '--- SEL_ACTIVO_LISTA_AGENDA creado.'
GO

PRINT '279_ACTIVO_LISTA_POPOVER aplicado.'
GO
