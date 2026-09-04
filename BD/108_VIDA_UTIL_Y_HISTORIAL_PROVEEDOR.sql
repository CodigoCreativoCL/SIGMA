/* ============================================================================
   SIGMA — Bloque 108
   VIDA UTIL DEL REPUESTO E HISTORIAL DEL PROVEEDOR          HU-058 · HU-065
   ----------------------------------------------------------------------------

   Las dos historias que quedaron sin dueño en el Daily del 01-09. Son las
   unicas del Sprint 3 que estaban enteras por hacer y sin nada que las
   bloquee.

   LAS DOS SON DE CONSULTA, NO DE MANTENEDOR

     Nadie "crea" una vida util ni un historial: son la lectura de algo que ya
     paso. Por eso no llevan INS_, UPD_ ni DEL_: llevan un SEL_ que calcula.

   HU-058 — LO QUE EL MODELO YA RESOLVIA

     `Componente_Repuesto_Instalacion` ya traia las cuatro columnas que la
     historia necesita: fecha e lectura de instalacion, fecha y lectura de
     retiro. Las lecturas son NULLABLE, que es exactamente el criterio 2
     -"si no registro horometro, solo la vida util en dias"-. No hubo que
     tocar el modelo.

     EL PROMEDIO VA POR VENTANA, NO EN UN SEGUNDO RESULTADO
       El criterio 3 pide promedio, minimo y maximo de las instalaciones de un
       mismo repuesto. Se resuelven con funciones de ventana sobre la particion
       del repuesto, asi que cada fila trae su propio agregado y la consulta
       sigue siendo UNA. Un segundo conjunto de resultados obligaria a la
       pantalla y a la API a saber leer dos, y a mantener sincronizados dos
       filtros.

     SOLO LAS CERRADAS PROMEDIAN
       Una pieza todavia instalada no tiene vida util: tiene tiempo
       transcurrido. Meterla en el promedio lo tira hacia abajo y hace parecer
       que las piezas duran menos de lo que duran. El agregado usa CASE WHEN
       fecha_retiro IS NOT NULL.

   HU-065 — LAS MONEDAS NO SE SUMAN

     El criterio 2 dice que el total se presenta separado por moneda y que no
     se suman montos de monedas distintas. Un total unico seria un numero que
     no significa nada: 500.000 pesos mas 12 UF no son 500.012 de nada.

     Se resuelve con SUM() OVER (PARTITION BY moneda). Los servicios sin
     moneda declarada -`ots_moneda` es nullable- caen en su propio grupo y se
     rotulan, en vez de mezclarse con los pesos.

     LA FECHA EFECTIVA
       Hay tres fechas posibles y las tres son nullable: la del servicio, la
       del documento y la de creacion. El filtro por rango usa la primera que
       exista, en ese orden. Sin eso, un servicio al que no le cargaron fecha
       de servicio desapareceria de todos los rangos.

   EL CLIENTE NO ESTA EN Orden_Trabajo_Servicio

     La tabla no tiene columna de cliente: cuelga de `Orden_Trabajo`. El filtro
     va por ahi, y ademas por `Proveedor.prv_cliente`. Los dos, no uno: son
     dos caminos distintos hacia la misma fila y basta que uno falte para
     mostrar el gasto de otra empresa.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. INDICES DE APOYO                                    T-3193 · T-3301

      Los dos son sobre la columna por la que la pantalla filtra. No se
      agregan indices "por si acaso": cada uno se paga en cada INSERT.
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE object_id = OBJECT_ID('dbo.Componente_Repuesto_Instalacion')
                  AND name = 'IX_CRI_CLIENTE_REPUESTO')
BEGIN
    CREATE INDEX IX_CRI_CLIENTE_REPUESTO
        ON [dbo].[Componente_Repuesto_Instalacion] (cri_cliente, cri_repuesto)
        INCLUDE (cri_fecha_instalacion_utc, cri_fecha_retiro_utc,
                 cri_lectura_inicial, cri_lectura_final)
    PRINT '--- IX_CRI_CLIENTE_REPUESTO creado.'
END
ELSE PRINT '--- IX_CRI_CLIENTE_REPUESTO ya existia.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE object_id = OBJECT_ID('dbo.Orden_Trabajo_Servicio')
                  AND name = 'IX_OTS_PROVEEDOR')
BEGIN
    CREATE INDEX IX_OTS_PROVEEDOR
        ON [dbo].[Orden_Trabajo_Servicio] (ots_proveedor, ots_habilitado)
        INCLUDE (ots_orden_trabajo, ots_monto, ots_moneda, ots_fecha_servicio_utc)
    PRINT '--- IX_OTS_PROVEEDOR creado.'
END
ELSE PRINT '--- IX_OTS_PROVEEDOR ya existia.'
GO


/* ========================================================================
   2. SEL_REPUESTO_VIDA_UTIL                                        HU-058
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_REPUESTO_VIDA_UTIL') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_REPUESTO_VIDA_UTIL]
GO

CREATE PROCEDURE [dbo].[SEL_REPUESTO_VIDA_UTIL]
    @CLIENTE            INT,
    @REPUESTO           INT = NULL,
    @ACTIVO             INT = NULL,
    @SOLO_RETIRADOS     BIT = NULL,
    @FILTRO             VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    ;WITH BASE AS (
        SELECT  i.cri_id,
                i.cri_cliente,
                i.cri_repuesto,
                i.cri_activo_componente,
                i.cri_activo_medidor,
                i.cri_cantidad,
                i.cri_fecha_instalacion_utc,
                i.cri_fecha_retiro_utc,
                i.cri_lectura_inicial,
                i.cri_lectura_final,
                i.cri_fallo,
                i.cri_repuesto_retiro_motivo,
                i.cri_repuesto_estado_final,
                i.cri_observacion,

                r.rep_codigo,
                r.rep_nombre,
                co.aco_codigo                       AS COMPONENTE_CODIGO,
                co.aco_nombre                       AS COMPONENTE_NOMBRE,
                a.act_id                            AS ACTIVO_ID,
                a.act_codigo                        AS ACTIVO_CODIGO,
                a.act_nombre                        AS ACTIVO_NOMBRE,
                ISNULL(m.ame_nombre, '')            AS MEDIDOR_NOMBRE,
                ISNULL(um.ume_codigo, '')           AS MEDIDOR_UNIDAD,
                ISNULL(mo.rrm_nombre, '')           AS MOTIVO_RETIRO,
                ISNULL(ef.ref_nombre, '')           AS ESTADO_FINAL,
                ISNULL(ut.usu_nombre + ' ' + ut.usu_apellido_paterno, '') AS TECNICO_NOMBRE,

                /* Criterio 1: la vida util en HORAS es la diferencia de
                   lecturas del medidor. Criterio 2: si falta cualquiera de
                   las dos, no hay dato -y eso es distinto de que sea cero-. */
                CASE WHEN i.cri_lectura_inicial IS NOT NULL
                      AND i.cri_lectura_final   IS NOT NULL
                     THEN i.cri_lectura_final - i.cri_lectura_inicial
                END                                 AS VIDA_UTIL_HORAS,

                /* La vida util en DIAS siempre se puede calcular: la fecha de
                   instalacion es obligatoria. Mientras la pieza sigue puesta
                   se mide contra hoy, y la columna INSTALADA avisa que ese
                   numero todavia esta corriendo. */
                DATEDIFF(DAY, i.cri_fecha_instalacion_utc,
                         ISNULL(i.cri_fecha_retiro_utc, GETUTCDATE()))
                                                    AS VIDA_UTIL_DIAS,

                CAST(CASE WHEN i.cri_lectura_inicial IS NOT NULL
                           AND i.cri_lectura_final   IS NOT NULL
                          THEN 1 ELSE 0 END AS BIT) AS TIENE_HORAS,

                CAST(CASE WHEN i.cri_fecha_retiro_utc IS NULL
                          THEN 1 ELSE 0 END AS BIT) AS INSTALADA

        FROM    [dbo].[Componente_Repuesto_Instalacion] i
        JOIN    [dbo].[Repuesto] r ON r.rep_id = i.cri_repuesto
        JOIN    [dbo].[Activo_Componente] co ON co.aco_id = i.cri_activo_componente
        JOIN    [dbo].[Activo] a ON a.act_id = co.aco_activo
        LEFT JOIN [dbo].[Activo_Medidor] m ON m.ame_id = i.cri_activo_medidor
        LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = m.ame_unidad_medida
        LEFT JOIN [dbo].[Repuesto_Retiro_Motivo] mo ON mo.rrm_id = i.cri_repuesto_retiro_motivo
        LEFT JOIN [dbo].[Repuesto_Estado_Final] ef ON ef.ref_id = i.cri_repuesto_estado_final
        LEFT JOIN [dbo].[Usuario] ut ON ut.usu_id = i.cri_usuario_tecnico
        WHERE   i.cri_cliente = @CLIENTE
          AND   (@REPUESTO IS NULL OR i.cri_repuesto = @REPUESTO)
          AND   (@ACTIVO IS NULL OR a.act_id = @ACTIVO)
          AND   (@SOLO_RETIRADOS IS NULL
                 OR (@SOLO_RETIRADOS = 1 AND i.cri_fecha_retiro_utc IS NOT NULL)
                 OR (@SOLO_RETIRADOS = 0 AND i.cri_fecha_retiro_utc IS NULL))
          AND   (@FILTRO IS NULL
                 OR r.rep_codigo   LIKE '%' + @FILTRO + '%'
                 OR r.rep_nombre   LIKE '%' + @FILTRO + '%'
                 OR a.act_codigo   LIKE '%' + @FILTRO + '%'
                 OR a.act_nombre   LIKE '%' + @FILTRO + '%'
                 OR co.aco_nombre  LIKE '%' + @FILTRO + '%')
    )
    SELECT  b.*,

            /* Criterio 3: promedio, minimo y maximo de las instalaciones del
               MISMO repuesto. Por ventana, para que cada fila traiga su
               comparacion sin una segunda consulta.

               Solo entran las CERRADAS: una pieza todavia puesta no tiene
               vida util, tiene tiempo transcurrido, y meterla en el promedio
               hace parecer que las piezas duran menos de lo que duran. */
            AVG(CASE WHEN b.INSTALADA = 0 THEN b.VIDA_UTIL_HORAS END)
                OVER (PARTITION BY b.cri_repuesto)  AS PROMEDIO_HORAS,
            MIN(CASE WHEN b.INSTALADA = 0 THEN b.VIDA_UTIL_HORAS END)
                OVER (PARTITION BY b.cri_repuesto)  AS MINIMO_HORAS,
            MAX(CASE WHEN b.INSTALADA = 0 THEN b.VIDA_UTIL_HORAS END)
                OVER (PARTITION BY b.cri_repuesto)  AS MAXIMO_HORAS,

            AVG(CASE WHEN b.INSTALADA = 0 THEN b.VIDA_UTIL_DIAS END)
                OVER (PARTITION BY b.cri_repuesto)  AS PROMEDIO_DIAS,
            MIN(CASE WHEN b.INSTALADA = 0 THEN b.VIDA_UTIL_DIAS END)
                OVER (PARTITION BY b.cri_repuesto)  AS MINIMO_DIAS,
            MAX(CASE WHEN b.INSTALADA = 0 THEN b.VIDA_UTIL_DIAS END)
                OVER (PARTITION BY b.cri_repuesto)  AS MAXIMO_DIAS,

            SUM(CASE WHEN b.INSTALADA = 0 THEN 1 ELSE 0 END)
                OVER (PARTITION BY b.cri_repuesto)  AS INSTALACIONES_CERRADAS,
            COUNT(*)
                OVER (PARTITION BY b.cri_repuesto)  AS INSTALACIONES_TOTAL

    FROM    BASE b
    /* Lo ultimo retirado primero: es lo que se acaba de romper y por lo que
       alguien entra a esta pantalla. Desempate por id para que la paginacion
       no repita filas. */
    ORDER BY ISNULL(b.cri_fecha_retiro_utc, b.cri_fecha_instalacion_utc) DESC, b.cri_id DESC
GO

PRINT '--- SEL_REPUESTO_VIDA_UTIL creado.'
GO


/* ========================================================================
   3. SEL_PROVEEDOR_HISTORIAL                                       HU-065
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PROVEEDOR_HISTORIAL') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_PROVEEDOR_HISTORIAL]
GO

CREATE PROCEDURE [dbo].[SEL_PROVEEDOR_HISTORIAL]
    @CLIENTE        INT,
    @PROVEEDOR      INT = NULL,
    @DESDE          DATE = NULL,
    @HASTA          DATE = NULL,
    @SERVICIO_TIPO  INT = NULL,
    @FILTRO         VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    ;WITH BASE AS (
        SELECT  s.ots_id,
                s.ots_orden_trabajo,
                s.ots_proveedor,
                s.ots_servicio_tipo,
                s.ots_descripcion,
                s.ots_cantidad,
                s.ots_monto_unitario,
                s.ots_monto,
                s.ots_moneda,
                s.ots_documento_referencia,
                s.ots_fecha_servicio_utc,
                s.ots_fecha_documento,

                p.prv_rut,
                p.prv_razon_social,
                ISNULL(p.prv_nombre_fantasia, '')   AS PROVEEDOR_FANTASIA,
                st.sti_nombre                       AS SERVICIO_TIPO_NOMBRE,
                o.otr_correlativo,
                o.otr_titulo                        AS ORDEN_TITULO,
                ISNULL(oe.ote_nombre, '')           AS ORDEN_ESTADO,

                /* Los servicios sin moneda declarada no se mezclan con los
                   pesos: caen en su propio grupo y se rotulan. Sumarlos con
                   el resto seria inventar la moneda que nadie escribio. */
                ISNULL(mn.mon_codigo, 'SIN MONEDA') AS MONEDA_CODIGO,
                ISNULL(mn.mon_nombre, 'Sin moneda declarada') AS MONEDA_NOMBRE,
                ISNULL(s.ots_moneda, 0)             AS MONEDA_GRUPO,

                /* Tres fechas posibles y las tres nullable. Se usa la primera
                   que exista: sin esto, un servicio al que no le cargaron
                   fecha de servicio desaparece de todos los rangos. */
                CAST(COALESCE(s.ots_fecha_servicio_utc,
                              CAST(s.ots_fecha_documento AS DATETIME),
                              s.ots_fecha_creacion) AS DATE) AS FECHA_EFECTIVA

        FROM    [dbo].[Orden_Trabajo_Servicio] s
        JOIN    [dbo].[Orden_Trabajo] o ON o.otr_id = s.ots_orden_trabajo
        JOIN    [dbo].[Proveedor] p ON p.prv_id = s.ots_proveedor
        JOIN    [dbo].[Servicio_Tipo] st ON st.sti_id = s.ots_servicio_tipo
        LEFT JOIN [dbo].[Moneda] mn ON mn.mon_id = s.ots_moneda
        LEFT JOIN [dbo].[Orden_Trabajo_Estado] oe ON oe.ote_id = o.otr_orden_trabajo_estado
        /* Los DOS caminos hacia el cliente, no uno: la orden y el proveedor.
           Basta que falte uno para mostrar el gasto de otra empresa. */
        WHERE   o.otr_cliente = @CLIENTE
          AND   p.prv_cliente = @CLIENTE
          AND   s.ots_habilitado = 1
          AND   (@PROVEEDOR IS NULL OR s.ots_proveedor = @PROVEEDOR)
          AND   (@SERVICIO_TIPO IS NULL OR s.ots_servicio_tipo = @SERVICIO_TIPO)
          AND   (@FILTRO IS NULL
                 OR s.ots_descripcion          LIKE '%' + @FILTRO + '%'
                 OR s.ots_documento_referencia LIKE '%' + @FILTRO + '%'
                 OR o.otr_titulo               LIKE '%' + @FILTRO + '%'
                 OR p.prv_razon_social         LIKE '%' + @FILTRO + '%')
    )
    SELECT  b.*,

            /* Criterio 2: el total va por moneda. Un total unico seria un
               numero sin significado: 500.000 pesos mas 12 UF no son
               500.012 de nada. */
            SUM(b.ots_monto) OVER (PARTITION BY b.ots_proveedor, b.MONEDA_GRUPO)
                                                    AS TOTAL_MONEDA,
            COUNT(*)         OVER (PARTITION BY b.ots_proveedor, b.MONEDA_GRUPO)
                                                    AS SERVICIOS_MONEDA,

            /* En cuantas ordenes distintas participo el proveedor. Va como
               subconsulta y no como ventana porque SQL Server no admite
               COUNT(DISTINCT) OVER: es de las cosas que compilan en la
               cabeza y no en el motor. */
            (SELECT COUNT(DISTINCT b2.ots_orden_trabajo)
               FROM BASE b2 WHERE b2.ots_proveedor = b.ots_proveedor)
                                                    AS ORDENES_PROVEEDOR

    FROM    BASE b
    WHERE   (@DESDE IS NULL OR b.FECHA_EFECTIVA >= @DESDE)
      AND   (@HASTA IS NULL OR b.FECHA_EFECTIVA <= @HASTA)
    ORDER BY b.FECHA_EFECTIVA DESC, b.ots_id DESC
GO

PRINT '--- SEL_PROVEEDOR_HISTORIAL creado.'
GO
