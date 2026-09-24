USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     DE QUE BODEGA SALIO EL REPUESTO, Y SI HAY DE LOS COMPATIBLES.
-- =============================================
-- LO QUE FALTABA EN REPUESTOS Y COSTOS
--   1. El consumo decia que salio y cuanto costo, pero no DE DONDE: la bodega
--      no esta en Orden_Trabajo_Repuesto, vive en el movimiento de inventario
--      que se genero al consumir. Sin ella no se puede ir al movimiento para
--      ver quien lo entrego.
--
--   2. Los repuestos compatibles eran una lista de nombres. La pregunta real
--      es "¿hay?" y "¿donde?": un compatible sin existencia no sirve para
--      resolver la falla de esta noche, y hoy habia que salir a inventario
--      para saberlo.
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

            (SELECT TOP 1 v.avi_archivo
               FROM [dbo].[Archivo_Vinculo] v
               JOIN [dbo].[Archivo] arc ON arc.arc_id = v.avi_archivo
              WHERE v.avi_repuesto = r.ore_repuesto
                AND v.avi_es_referencia = 1
                AND ISNULL(v.avi_habilitado, 1) = 1
                AND ISNULL(arc.arc_habilitado, 1) = 1
              ORDER BY v.avi_id DESC)                 AS IMAGEN_ID,

            /* De donde salio. La bodega no esta en la linea de la orden: vive
               en el movimiento de inventario que se genero al consumir. */
            ISNULL(mov.BODEGA, '')                    AS BODEGA,
            ISNULL(mov.UBICACION, '')                 AS UBICACION,
            mov.MOVIMIENTO_ID                         AS MOVIMIENTO_ID

    FROM    [dbo].[Orden_Trabajo_Repuesto] r
    JOIN    [dbo].[Orden_Trabajo] o            ON o.otr_id = r.ore_orden_trabajo
    LEFT JOIN [dbo].[Repuesto] rep             ON rep.rep_id = r.ore_repuesto
    LEFT JOIN [dbo].[Unidad_Medida] ume        ON ume.ume_id = rep.rep_unidad_medida
    LEFT JOIN [dbo].[Activo_Componente] com    ON com.aco_id = r.ore_activo_componente
    LEFT JOIN [dbo].[Moneda] mon               ON mon.mon_id = r.ore_moneda
    LEFT JOIN [dbo].[Usuario] usr              ON usr.usu_id = r.ore_usuario_creacion

    /* La salida por consumo de ESTE repuesto en ESTA orden. Si hubo varias
       -se consumio en dos tandas- se toma la ultima, que es la que deja el
       saldo como quedo. */
    OUTER APPLY (
        SELECT  TOP 1
                bod.bod_nombre                        AS BODEGA,
                ISNULL(ubi.bub_codigo, '')            AS UBICACION,
                m.imo_id                              AS MOVIMIENTO_ID
          FROM  [dbo].[Inventario_Movimiento] m
                LEFT JOIN [dbo].[Bodega] bod            ON bod.bod_id = m.imo_bodega
                LEFT JOIN [dbo].[Bodega_Ubicacion] ubi  ON ubi.bub_id = m.imo_bodega_ubicacion
         WHERE  m.imo_orden_trabajo = r.ore_orden_trabajo
           AND  m.imo_repuesto = r.ore_repuesto
           AND  m.imo_inventario_movimiento_tipo = 2   -- SALIDA CONSUMO
         ORDER  BY m.imo_fecha_movimiento_utc DESC, m.imo_id DESC
    ) mov

    WHERE   o.otr_cliente = @CLIENTE
      AND   o.otr_activo  = @ACTIVO
      AND   ISNULL(r.ore_habilitado, 1) = 1
      AND   ISNULL(r.ore_cantidad_consumida, 0) > 0
      AND   (@DESDE IS NULL OR ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_evento_utc) >= @DESDE)
      AND   (@HASTA IS NULL OR ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_evento_utc) <  @HASTA)

    ORDER BY ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_evento_utc) DESC, r.ore_id DESC
GO
PRINT '--- SEL_ACTIVO_REPUESTO_CONSUMO actualizado con bodega y movimiento.'
GO

/* ========================================================================
   Los compatibles, con la respuesta a "¿hay?" y "¿donde?".

   Una lista de nombres no sirve para resolver la falla de esta noche: hay
   que salir a inventario a preguntar si queda alguno. La existencia se suma
   sobre Inventario_Saldo, que es la tabla que el bodeguero mantiene cuadrada
   con sus movimientos.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_REPUESTO_COMPATIBLE]
    @CLIENTE INT,
    @ACTIVO  INT
AS
SET NOCOUNT ON

    SELECT  rep.rep_id                                AS REPUESTO_ID,
            ISNULL(rep.rep_codigo, '')                AS CODIGO,
            ISNULL(rep.rep_nombre, '')                AS NOMBRE,
            ISNULL(rep.rep_descripcion, '')           AS DESCRIPCION,
            ISNULL(rep.rep_fabricante, '')            AS FABRICANTE,
            ISNULL(rep.rep_modelo, '')                AS MODELO,
            ISNULL(ume.ume_codigo, '')                AS UNIDAD,

            ISNULL(sal.EXISTENCIA, 0)                 AS EXISTENCIA,
            ISNULL(sal.BODEGAS, 0)                    AS BODEGAS,
            ISNULL(sal.DONDE, '')                     AS DONDE,

            (SELECT TOP 1 v.avi_archivo
               FROM [dbo].[Archivo_Vinculo] v
               JOIN [dbo].[Archivo] arc ON arc.arc_id = v.avi_archivo
              WHERE v.avi_repuesto = rep.rep_id
                AND v.avi_es_referencia = 1
                AND ISNULL(v.avi_habilitado, 1) = 1
                AND ISNULL(arc.arc_habilitado, 1) = 1
              ORDER BY v.avi_id DESC)                 AS IMAGEN_ID

    FROM    [dbo].[Repuesto_Compatibilidad] cmp
    JOIN    [dbo].[Repuesto] rep               ON rep.rep_id = cmp.rco_repuesto
    LEFT JOIN [dbo].[Unidad_Medida] ume        ON ume.ume_id = rep.rep_unidad_medida
    JOIN    [dbo].[Activo] act                 ON act.act_id = @ACTIVO

    /* Cuanto hay y en que bodega. Se nombra UNA -la que mas tiene- y se dice
       cuantas mas: "Bodega central +2" cabe en una celda y "hay en tres
       bodegas" no dice a cual ir. */
    OUTER APPLY (
        SELECT  SUM(s.isa_cantidad)                   AS EXISTENCIA,
                COUNT(DISTINCT s.isa_bodega)          AS BODEGAS,
                MAX(s.PRIMERA)                        AS DONDE
          FROM (
                SELECT  s2.isa_cantidad,
                        s2.isa_bodega,
                        CASE WHEN ROW_NUMBER() OVER (ORDER BY s2.isa_cantidad DESC) = 1
                             THEN b.bod_nombre + ISNULL(' · ' + u.bub_codigo, '')
                             ELSE NULL END            AS PRIMERA
                  FROM  [dbo].[Inventario_Saldo] s2
                        LEFT JOIN [dbo].[Bodega] b           ON b.bod_id = s2.isa_bodega
                        LEFT JOIN [dbo].[Bodega_Ubicacion] u ON u.bub_id = s2.isa_bodega_ubicacion
                 WHERE  s2.isa_repuesto = rep.rep_id
                   AND  s2.isa_cliente = @CLIENTE
                   AND  s2.isa_cantidad > 0
               ) s
    ) sal

    WHERE   rep.rep_cliente = @CLIENTE
      AND   ISNULL(rep.rep_habilitado, 1) = 1
      /* Repuesto_Compatibilidad no tiene baja logica: la fila existe o
         no existe. Se filtra por el repuesto, que si la tiene. */

      /* La compatibilidad se declara por TIPO o por MODELO del activo: el
         mismo rodamiento sirve para todas las bombas de ese modelo. */
      AND   (cmp.rco_activo_tipo = act.act_activo_tipo
             OR (cmp.rco_activo_modelo IS NOT NULL AND cmp.rco_activo_modelo = act.act_activo_modelo))

    ORDER BY ISNULL(sal.EXISTENCIA, 0) DESC, rep.rep_codigo
GO
PRINT '--- SEL_ACTIVO_REPUESTO_COMPATIBLE creado.'
GO

PRINT '284_REPUESTO_BODEGA aplicado.'
GO
