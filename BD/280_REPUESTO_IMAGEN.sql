USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     LA IMAGEN DEL REPUESTO Y LA DEL COMPONENTE EN EL CENTRO.
-- =============================================
-- POR QUE
--   "RE-0041 · Rodamiento 6205 2RS" identifica la pieza para quien la compra.
--   Para el tecnico que mira que se le cambio al equipo, la foto es lo que la
--   reconoce. Las dos listas -consumos y repuestos compatibles- la tenian en
--   la base y no la mostraban.
--
--   La imagen sale de Archivo_Vinculo con avi_es_referencia = 1: la misma
--   regla que usa la foto del activo. Un vinculo sin esa marca es una
--   evidencia, no el retrato de la pieza.
--
--   Solo viaja el ID. Los bytes viven en el blob y la pantalla los pide por
--   VerArchivo.aspx; devolverlos aca haria que abrir el centro de un equipo
--   con veinte consumos costara veinte megas.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_REPUESTO_CONSUMO]
    @CLIENTE  INT,
    @ACTIVO   INT,
    @DESDE    DATETIME = NULL,
    @HASTA    DATETIME = NULL
AS
SET NOCOUNT ON

    SELECT  r.ore_id,
            r.ore_repuesto,
            ISNULL(rep.rep_codigo, '')                AS REPUESTO_CODIGO,
            ISNULL(rep.rep_nombre, '')                AS REPUESTO_NOMBRE,
            ISNULL(ume.ume_codigo, '')                AS UNIDAD,
            ISNULL(com.aco_nombre, '')                AS COMPONENTE,
            r.ore_activo_componente                   AS COMPONENTE_ID,

            ISNULL(r.ore_cantidad_consumida, 0) - ISNULL(r.ore_cantidad_devuelta, 0) AS CANTIDAD,
            ISNULL(r.ore_cantidad_devuelta, 0)        AS DEVUELTA,
            ISNULL(r.ore_costo_unitario, 0)           AS COSTO_UNITARIO,
            ISNULL(mon.mon_codigo, '')                AS MONEDA,

            CAST(ISNULL(r.ore_costo_unitario, 0) *
                 (ISNULL(r.ore_cantidad_consumida, 0) - ISNULL(r.ore_cantidad_devuelta, 0)) AS DECIMAL(18, 2)) AS COSTO,

            o.otr_id                                  AS ORDEN_ID,
            ISNULL(o.otr_correlativo, 0)              AS ORDEN_CORRELATIVO,
            ISNULL(o.otr_titulo, '')                  AS ORDEN_TITULO,
            ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_evento_utc) AS FECHA,
            ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '') AS USUARIO_NOMBRE,

            /* La foto de la pieza. Solo el id: los bytes viven en el blob. */
            (SELECT TOP 1 v.avi_archivo
               FROM [dbo].[Archivo_Vinculo] v
               JOIN [dbo].[Archivo] arc ON arc.arc_id = v.avi_archivo
              WHERE v.avi_repuesto = r.ore_repuesto
                AND v.avi_es_referencia = 1
                AND ISNULL(v.avi_habilitado, 1) = 1
                AND ISNULL(arc.arc_habilitado, 1) = 1
              ORDER BY v.avi_id DESC)                 AS IMAGEN_ID

    FROM    [dbo].[Orden_Trabajo_Repuesto] r
    JOIN    [dbo].[Orden_Trabajo] o            ON o.otr_id = r.ore_orden_trabajo
    LEFT JOIN [dbo].[Repuesto] rep             ON rep.rep_id = r.ore_repuesto
    LEFT JOIN [dbo].[Unidad_Medida] ume        ON ume.ume_id = rep.rep_unidad_medida
    LEFT JOIN [dbo].[Activo_Componente] com    ON com.aco_id = r.ore_activo_componente
    LEFT JOIN [dbo].[Moneda] mon               ON mon.mon_id = r.ore_moneda
    LEFT JOIN [dbo].[Usuario] usr              ON usr.usu_id = r.ore_usuario_creacion

    WHERE   o.otr_cliente = @CLIENTE
      AND   o.otr_activo  = @ACTIVO
      AND   ISNULL(r.ore_habilitado, 1) = 1
      AND   ISNULL(r.ore_cantidad_consumida, 0) > 0
      AND   (@DESDE IS NULL OR ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_evento_utc) >= @DESDE)
      AND   (@HASTA IS NULL OR ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_evento_utc) <  @HASTA)

    ORDER BY ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_evento_utc) DESC, r.ore_id DESC
GO
PRINT '--- SEL_ACTIVO_REPUESTO_CONSUMO actualizado con IMAGEN_ID.'
GO

PRINT '280_REPUESTO_IMAGEN aplicado.'
GO
