USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  23-09-2026
-- DESCRIPTION:     LO QUE CONSUMIO UNA ORDEN DE TRABAJO, PARA LA WEB.
--                  1. SEL_ORDEN_TRABAJO_REPUESTO   (que se gasto de bodega)
--                  2. SEL_ORDEN_TRABAJO_MANO_OBRA  (quien trabajo y cuanto)
--                  3. SEL_ORDEN_TRABAJO_SERVICIO   (que se contrato afuera)
-- =============================================
-- Las tres tablas existen desde el Sprint 5 y la app ya escribe en dos de
-- ellas (API_INS_ORDEN_TRABAJO_REPUESTO y API_INS_ORDEN_TRABAJO_MANO_OBRA),
-- pero la web no tenia como leerlas: la orden mostraba pasos, evidencias y
-- cierre, y lo que costo el trabajo no aparecia en ninguna parte. Una orden
-- sin sus consumos no sirve para costear un equipo ni para decidir si conviene
-- repararlo otra vez.
--
-- Los tres devuelven el costo YA CALCULADO. Repartir la multiplicacion entre
-- la pantalla, el informe y la app termina en tres numeros distintos para la
-- misma orden; el que manda es este.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* ========================================================================
   1. SEL_ORDEN_TRABAJO_REPUESTO

   Lo planificado, lo reservado, lo consumido y lo devuelto. Los cuatro
   importan: un repuesto reservado y no consumido sigue comprometido en
   bodega, y uno devuelto explica por que la orden costo menos de lo que
   decia su plan.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ORDEN_TRABAJO_REPUESTO]
    @CLIENTE  INT,
    @ORDEN    INT
AS
SET NOCOUNT ON

    SELECT  r.ore_id,
            r.ore_repuesto,
            ISNULL(rep.rep_codigo, '')                AS REPUESTO_CODIGO,
            ISNULL(rep.rep_nombre, '')                AS REPUESTO_NOMBRE,
            ISNULL(ume.ume_codigo, '')                AS UNIDAD,
            ISNULL(lot.rlo_codigo, '')                AS LOTE,
            ISNULL(com.aco_nombre, '')                AS COMPONENTE,
            ISNULL(r.ore_cantidad_planificada, 0)     AS PLANIFICADA,
            ISNULL(r.ore_cantidad_reservada, 0)       AS RESERVADA,
            ISNULL(r.ore_cantidad_consumida, 0)       AS CONSUMIDA,
            ISNULL(r.ore_cantidad_devuelta, 0)        AS DEVUELTA,
            ISNULL(r.ore_costo_unitario, 0)           AS COSTO_UNITARIO,
            ISNULL(mon.mon_codigo, '')                AS MONEDA,

            /* El costo de la orden es lo que SE GASTO, no lo que se pidio:
               se cuenta lo consumido menos lo devuelto. */
            CAST(ISNULL(r.ore_costo_unitario, 0) *
                 (ISNULL(r.ore_cantidad_consumida, 0) - ISNULL(r.ore_cantidad_devuelta, 0)) AS DECIMAL(18, 2)) AS COSTO,

            ISNULL(r.ore_observacion, '')             AS OBSERVACION,
            r.ore_fecha_creacion,
            ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '') AS USUARIO_NOMBRE

    FROM    [dbo].[Orden_Trabajo_Repuesto] r
    JOIN    [dbo].[Orden_Trabajo] o            ON o.otr_id = r.ore_orden_trabajo
    LEFT JOIN [dbo].[Repuesto] rep             ON rep.rep_id = r.ore_repuesto
    LEFT JOIN [dbo].[Unidad_Medida] ume        ON ume.ume_id = rep.rep_unidad_medida
    LEFT JOIN [dbo].[Repuesto_Lote] lot        ON lot.rlo_id = r.ore_repuesto_lote
    LEFT JOIN [dbo].[Activo_Componente] com    ON com.aco_id = r.ore_activo_componente
    LEFT JOIN [dbo].[Moneda] mon               ON mon.mon_id = r.ore_moneda
    LEFT JOIN [dbo].[Usuario] usr              ON usr.usu_id = r.ore_usuario_creacion

    WHERE   r.ore_orden_trabajo = @ORDEN
      AND   o.otr_cliente       = @CLIENTE
      AND   ISNULL(r.ore_habilitado, 1) = 1

    ORDER BY rep.rep_codigo, r.ore_id
GO
PRINT '--- SEL_ORDEN_TRABAJO_REPUESTO creado.'
GO


/* ========================================================================
   2. SEL_ORDEN_TRABAJO_MANO_OBRA

   Quien trabajo, cuanto rato y a que costo. La linea puede ser de una
   persona o de una empresa externa: se devuelven las dos y la pantalla
   muestra la que venga.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ORDEN_TRABAJO_MANO_OBRA]
    @CLIENTE  INT,
    @ORDEN    INT
AS
SET NOCOUNT ON

    SELECT  m.omo_id,
            ISNULL(usr.usu_nombre + ' ' + ISNULL(usr.usu_apellido_paterno, ''), '') AS USUARIO_NOMBRE,
            ISNULL(prv.prv_razon_social, '')          AS PROVEEDOR_NOMBRE,
            ISNULL(esp.esp_nombre, '')                AS ESPECIALIDAD,
            m.omo_fecha_inicio_utc,
            m.omo_fecha_fin_utc,
            ISNULL(m.omo_minuto, 0)                   AS MINUTOS,
            ISNULL(m.omo_es_hora_extra, 0)            AS HORA_EXTRA,
            ISNULL(m.omo_costo_hora, 0)               AS COSTO_HORA,
            ISNULL(mon.mon_codigo, '')                AS MONEDA,

            /* Los minutos se cobran por hora: la division va aca y no en la
               pantalla, para que el informe y la ficha digan lo mismo. */
            CAST(ISNULL(m.omo_costo_hora, 0) * ISNULL(m.omo_minuto, 0) / 60.0 AS DECIMAL(18, 2)) AS COSTO,

            ISNULL(m.omo_observacion, '')             AS OBSERVACION

    FROM    [dbo].[Orden_Trabajo_Mano_Obra] m
    JOIN    [dbo].[Orden_Trabajo] o    ON o.otr_id = m.omo_orden_trabajo
    LEFT JOIN [dbo].[Usuario] usr      ON usr.usu_id = m.omo_usuario
    LEFT JOIN [dbo].[Proveedor] prv    ON prv.prv_id = m.omo_proveedor
    LEFT JOIN [dbo].[Especialidad] esp ON esp.esp_id = m.omo_especialidad
    LEFT JOIN [dbo].[Moneda] mon       ON mon.mon_id = m.omo_moneda

    WHERE   m.omo_orden_trabajo = @ORDEN
      AND   o.otr_cliente       = @CLIENTE

    ORDER BY m.omo_fecha_inicio_utc, m.omo_id
GO
PRINT '--- SEL_ORDEN_TRABAJO_MANO_OBRA creado.'
GO


/* ========================================================================
   3. SEL_ORDEN_TRABAJO_SERVICIO

   Lo que se contrato afuera: quien, que, cuanto y con que documento.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ORDEN_TRABAJO_SERVICIO]
    @CLIENTE  INT,
    @ORDEN    INT
AS
SET NOCOUNT ON

    SELECT  s.ots_id,
            ISNULL(prv.prv_razon_social, '')          AS PROVEEDOR_NOMBRE,
            ISNULL(sti.sti_nombre, '')                AS TIPO,
            ISNULL(s.ots_descripcion, '')             AS DESCRIPCION,
            ISNULL(s.ots_cantidad, 0)                 AS CANTIDAD,
            ISNULL(s.ots_monto_unitario, 0)           AS MONTO_UNITARIO,

            /* El monto de la linea viene grabado, pero puede venir nulo si se
               cargo solo el unitario: ahi se calcula. */
            CAST(ISNULL(s.ots_monto, ISNULL(s.ots_monto_unitario, 0) * ISNULL(s.ots_cantidad, 0)) AS DECIMAL(18, 2)) AS COSTO,

            ISNULL(mon.mon_codigo, '')                AS MONEDA,
            ISNULL(s.ots_documento_referencia, '')    AS DOCUMENTO,
            s.ots_fecha_servicio_utc,
            s.ots_fecha_documento

    FROM    [dbo].[Orden_Trabajo_Servicio] s
    JOIN    [dbo].[Orden_Trabajo] o      ON o.otr_id = s.ots_orden_trabajo
    LEFT JOIN [dbo].[Proveedor] prv      ON prv.prv_id = s.ots_proveedor
    LEFT JOIN [dbo].[Servicio_Tipo] sti  ON sti.sti_id = s.ots_servicio_tipo
    LEFT JOIN [dbo].[Moneda] mon         ON mon.mon_id = s.ots_moneda

    WHERE   s.ots_orden_trabajo = @ORDEN
      AND   o.otr_cliente       = @CLIENTE
      AND   ISNULL(s.ots_habilitado, 1) = 1

    ORDER BY s.ots_fecha_servicio_utc, s.ots_id
GO
PRINT '--- SEL_ORDEN_TRABAJO_SERVICIO creado.'
GO

PRINT '263_ORDEN_TRABAJO_RECURSO aplicado.'
GO
