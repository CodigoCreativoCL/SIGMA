USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     LO QUE LA LISTA DE EQUIPOS NECESITA SABER DE CADA UNO.
-- =============================================
-- La lista del centro no muestra solo el nombre del equipo: muestra cuantas
-- ordenes abiertas tiene, si le queda una falla sin resolver, cuando le toca
-- la proxima mantencion y su foto.
--
-- Todo eso existe, pero repartido: una consulta por activo para las ordenes,
-- otra para las fallas, otra para la ocurrencia y otra para la imagen. Con
-- cuarenta y siete equipos son casi doscientas consultas para pintar una
-- pantalla, y el cliente con mas equipos seria el mas lento.
--
-- Este devuelve UNA fila por activo con todo junto. La lista sigue saliendo
-- de SEL_ACTIVO -que ya sabe filtrar por planta, area y texto-; esto solo le
-- agrega los numeros.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_LISTA_RESUMEN]
    @CLIENTE INT
AS
SET NOCOUNT ON

DECLARE @HOY DATETIME = [dbo].[FNC_AHORA]()

    SELECT  a.act_id                                  AS ACTIVO_ID,

            /* Abierta es cualquier estado que no sea cerrada (4): lo que
               todavia le debe trabajo a este equipo. */
            (SELECT COUNT(*)
               FROM [dbo].[Orden_Trabajo] o
              WHERE o.otr_activo = a.act_id
                AND o.otr_cliente = @CLIENTE
                AND ISNULL(o.otr_orden_trabajo_estado, 0) <> 4)        AS OT_ABIERTAS,

            (SELECT COUNT(*)
               FROM [dbo].[Falla] f
              WHERE f.fal_activo = a.act_id
                AND ISNULL(f.fal_habilitado, 1) = 1
                AND f.fal_fecha_solucion_utc IS NULL)                  AS FALLAS_ABIERTAS,

            /* Una detencion sin fecha de fin es una detencion AHORA: el
               equipo figura parado en este momento. */
            (SELECT COUNT(*)
               FROM [dbo].[Activo_Indisponibilidad] i
              WHERE i.ain_activo = a.act_id
                AND ISNULL(i.ain_habilitado, 1) = 1
                AND i.ain_fecha_fin_utc IS NULL)                       AS DETENCION_ABIERTA,

            /* La proxima que le toca: la primera ocurrencia que todavia no
               se cerro ni se omitio. */
            (SELECT MIN(o.pmo_fecha_programada_utc)
               FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
              WHERE o.pmo_activo = a.act_id
                AND ISNULL(o.pmo_habilitado, 1) = 1
                AND ISNULL(o.pmo_plan_ocurrencia_estado, 1) NOT IN (4, 5, 6)
                AND o.pmo_fecha_programada_utc >= @HOY)                AS PROXIMA_MANTENCION,

            /* La foto, en la misma vuelta: pedirla por activo era una
               consulta mas por fila. */
            (SELECT TOP 1 v.avi_archivo
               FROM [dbo].[Archivo_Vinculo] v
               JOIN [dbo].[Archivo] arc ON arc.arc_id = v.avi_archivo
              WHERE v.avi_activo = a.act_id
                AND v.avi_es_referencia = 1
                AND ISNULL(v.avi_habilitado, 1) = 1
                AND ISNULL(arc.arc_habilitado, 1) = 1
              ORDER BY v.avi_id DESC)                                  AS IMAGEN_ID

    FROM    [dbo].[Activo] a
    WHERE   a.act_cliente = @CLIENTE
GO
PRINT '--- SEL_ACTIVO_LISTA_RESUMEN creado.'
GO

PRINT '275_ACTIVO_LISTA_RESUMEN aplicado.'
GO
