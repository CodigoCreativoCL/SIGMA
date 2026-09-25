/* ============================================================================
   SIGMA — Bloque 236
   VIDA UTIL REAL E HISTORIAL DEL PROVEEDOR: LO QUE FALTABA        HU-058 · HU-065
   ----------------------------------------------------------------------------

   El bloque 108 dejó los dos SP de consulta y el 109 una siembra que hoy no
   engancha con nada: buscaba repuestos DEMO-ROD-6205 y componentes ROD-01
   que ya no existen (el catálogo se volvió a sembrar con REP-6205 y
   CMP-33-xx). Resultado: las dos tablas están en CERO filas y ninguna
   pantalla las lee. Este bloque cierra lo que quedó abierto:

   1. SEL_REPUESTO_VIDA_UTIL gana lo que la pantalla necesita y el SP no
      daba: las fechas en hora de Santiago (las columnas son UTC), la vida
      útil ESPERADA del repuesto (bloque 63) para ponerla al lado de la real
      —que es exactamente para lo que el planificador entra a esta pantalla—
      y los correlativos de las órdenes de instalación y retiro.

   2. SEL_PROVEEDOR_HISTORIAL tenía un defecto: el rango de fechas se
      aplicaba DESPUÉS de contar las órdenes, así que "órdenes en que
      participó" ignoraba el filtro mientras los totales sí lo respetaban.
      Ahora el rango entra en la base y todo lo que se muestra responde a la
      misma pregunta.

   3. Datos de prueba sobre el catálogo real (T-3194, T-3302), con los
      mismos números que el bloque 109 eligió a propósito: 300 → 8.712 son
      8.412 horas (criterio 1); una instalación sin horómetro (criterio 2);
      dos cerradas y una abierta del mismo repuesto para el promedio
      (criterio 3); 730.000 CLP y 12,5 UF por separado (HU-065 #2).

   4. Los menús de las dos pantallas. Sin permisos nuevos: la vida útil es un
      dato del repuesto (VER REPUESTOS) y el historial es un dato del
      proveedor (VER PROVEEDORES). Inventar "VER VIDA UTIL" sería un permiso
      que nadie va a administrar distinto del que ya tiene.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. SEL_REPUESTO_VIDA_UTIL                                        HU-058
   ======================================================================== */
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACIÓN:  01-09-2026 (bloque 108) · 16-09-2026 (bloque 236)
-- DESCRIPTION:     VIDA UTIL REAL DE CADA INSTALACION DE REPUESTO, CON EL
--                  PROMEDIO / MINIMO / MAXIMO DEL MISMO REPUESTO POR VENTANA
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO_VIDA_UTIL]
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

                /* Para leerlas: las columnas son UTC y la pantalla habla en
                   hora de Santiago. */
                CAST(i.cri_fecha_instalacion_utc AT TIME ZONE 'UTC'
                     AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME) AS FECHA_INSTALACION,
                CAST(i.cri_fecha_retiro_utc AT TIME ZONE 'UTC'
                     AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME) AS FECHA_RETIRO,

                r.rep_codigo,
                r.rep_nombre,
                /* La vida util ESPERADA (bloque 63) al lado de la real: la
                   comparacion es el motivo de la pantalla. */
                r.rep_vida_util_hora                AS ESPERADA_HORAS,
                r.rep_vida_util_dia                 AS ESPERADA_DIAS,
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
                oi.otr_correlativo                  AS OT_INSTALACION,
                orr.otr_correlativo                 AS OT_RETIRO,

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
        LEFT JOIN [dbo].[Orden_Trabajo] oi  ON oi.otr_id  = i.cri_orden_trabajo_instalacion
        LEFT JOIN [dbo].[Orden_Trabajo] orr ON orr.otr_id = i.cri_orden_trabajo_retiro
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

PRINT '--- SEL_REPUESTO_VIDA_UTIL actualizado (bloque 236).'
GO


/* ========================================================================
   2. SEL_PROVEEDOR_HISTORIAL                                       HU-065
   ======================================================================== */
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACIÓN:  01-09-2026 (bloque 108) · 16-09-2026 (bloque 236)
-- DESCRIPTION:     SERVICIOS CONTRATADOS A UN PROVEEDOR CON EL TOTAL POR
--                  MONEDA Y LAS ORDENES EN QUE PARTICIPO, DENTRO DEL RANGO
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEL_PROVEEDOR_HISTORIAL]
    @CLIENTE        INT,
    @PROVEEDOR      INT = NULL,
    @DESDE          DATE = NULL,
    @HASTA          DATE = NULL,
    @SERVICIO_TIPO  INT = NULL,
    @FILTRO         VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    ;WITH FILAS AS (
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

                p.prv_id                            AS PROVEEDOR_ID,
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
    ),
    /* El rango de fechas entra AQUI y no al final: en el bloque 108 se
       aplicaba despues de contar las ordenes, y "ordenes en que participo"
       ignoraba el filtro mientras los totales si lo respetaban. Dos numeros
       de la misma pantalla respondiendo a preguntas distintas. */
    BASE AS (
        SELECT  f.*
        FROM    FILAS f
        WHERE   (@DESDE IS NULL OR f.FECHA_EFECTIVA >= @DESDE)
          AND   (@HASTA IS NULL OR f.FECHA_EFECTIVA <= @HASTA)
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
               COUNT(DISTINCT) OVER. */
            (SELECT COUNT(DISTINCT b2.ots_orden_trabajo)
               FROM BASE b2 WHERE b2.ots_proveedor = b.ots_proveedor)
                                                    AS ORDENES_PROVEEDOR

    FROM    BASE b
    ORDER BY b.FECHA_EFECTIVA DESC, b.ots_id DESC
GO

PRINT '--- SEL_PROVEEDOR_HISTORIAL actualizado (bloque 236).'
GO


/* ========================================================================
   3. DATOS DE PRUEBA                                     T-3194 · T-3302

      Sobre el catalogo real de Hamburgo (cliente 1): el rodamiento REP-6205
      en el componente CMP-33-03 "Rodamiento lado motor" de la Modeladora L1
      (ACT-33), medido por su horometro MED-33-H. Idempotente: se reconoce
      por el prefijo DEMO- de la observacion / del documento.
   ======================================================================== */
DECLARE @CLI INT = 1, @USU INT = 1
DECLARE @REP_ROD INT, @REP_CORREA INT, @COMP_ROD INT, @COMP_RED INT, @MED INT
DECLARE @OT_A INT, @OT_B INT
DECLARE @M_DESGASTE INT, @M_FALLA INT, @M_PREVENTIVO INT
DECLARE @E_DESGASTE_SEVERO INT, @E_ROTO INT, @E_DESGASTE_LEVE INT

SELECT @REP_ROD    = rep_id FROM [dbo].[Repuesto] WHERE rep_cliente = @CLI AND rep_codigo = 'REP-6205'
SELECT @REP_CORREA = rep_id FROM [dbo].[Repuesto] WHERE rep_cliente = @CLI AND rep_codigo = 'REP-CORREA'
SELECT @COMP_ROD   = aco_id FROM [dbo].[Activo_Componente] WHERE aco_codigo = 'CMP-33-03'
SELECT @COMP_RED   = aco_id FROM [dbo].[Activo_Componente] WHERE aco_codigo = 'CMP-33-02'
SELECT @MED        = ame_id FROM [dbo].[Activo_Medidor] WHERE ame_codigo = 'MED-33-H' AND ame_activo = 33

SELECT @M_DESGASTE   = rrm_id FROM [dbo].[Repuesto_Retiro_Motivo] WHERE rrm_codigo = 'DESGASTE'   AND rrm_cliente IS NULL
SELECT @M_FALLA      = rrm_id FROM [dbo].[Repuesto_Retiro_Motivo] WHERE rrm_codigo = 'FALLA'      AND rrm_cliente IS NULL
SELECT @M_PREVENTIVO = rrm_id FROM [dbo].[Repuesto_Retiro_Motivo] WHERE rrm_codigo = 'PREVENTIVO' AND rrm_cliente IS NULL
SELECT @E_DESGASTE_SEVERO = ref_id FROM [dbo].[Repuesto_Estado_Final] WHERE ref_codigo = 'DESGASTE SEVERO' AND ref_cliente IS NULL
SELECT @E_ROTO            = ref_id FROM [dbo].[Repuesto_Estado_Final] WHERE ref_codigo = 'ROTO'            AND ref_cliente IS NULL
SELECT @E_DESGASTE_LEVE   = ref_id FROM [dbo].[Repuesto_Estado_Final] WHERE ref_codigo = 'DESGASTE LEVE'   AND ref_cliente IS NULL

/* Ordenes CERRADAS que ya existen: las instalaciones y los retiros cuelgan
   de trabajo terminado. */
SELECT @OT_A = otr_id FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLI AND otr_correlativo = 3
SELECT @OT_B = otr_id FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLI AND otr_correlativo = 4

IF (@REP_ROD IS NULL OR @COMP_ROD IS NULL OR @MED IS NULL)
    PRINT '--- FALTAN el repuesto, el componente o el horometro: no se siembran instalaciones.'
ELSE IF EXISTS (SELECT 1 FROM [dbo].[Componente_Repuesto_Instalacion]
                 WHERE cri_cliente = @CLI AND cri_observacion LIKE 'DEMO-058%')
    PRINT '--- Las instalaciones de prueba ya existian.'
ELSE
BEGIN
    INSERT INTO [dbo].[Componente_Repuesto_Instalacion]
        (cri_cliente, cri_activo_componente, cri_repuesto, cri_activo_medidor,
         cri_cantidad, cri_fecha_instalacion_utc, cri_lectura_inicial,
         cri_fecha_retiro_utc, cri_lectura_final,
         cri_repuesto_retiro_motivo, cri_repuesto_estado_final, cri_fallo,
         cri_usuario_tecnico, cri_orden_trabajo_instalacion, cri_orden_trabajo_retiro,
         cri_observacion, cri_usuario_creacion, cri_fecha_creacion)
    VALUES
        /* CRITERIO 1, textual: 8712 - 300 = 8412 horas. 522 dias corridos. */
        (@CLI, @COMP_ROD, @REP_ROD, @MED, 1, '2024-01-15 12:00', 300,
         '2025-06-20 12:00', 8712, @M_DESGASTE, @E_DESGASTE_SEVERO, 0, @USU, @OT_A, @OT_B,
         'DEMO-058-1 · el caso del criterio 1: 300 a 8712 son 8412 horas',
         @USU, [dbo].[FNC_AHORA]()),

        /* La segunda del mismo repuesto: 12100 - 8712 = 3388 horas.
           Con la anterior dan promedio 5900, minimo 3388, maximo 8412. */
        (@CLI, @COMP_ROD, @REP_ROD, @MED, 1, '2025-06-20 12:00', 8712,
         '2026-02-10 12:00', 12100, @M_FALLA, @E_ROTO, 1, @USU, @OT_B, NULL,
         'DEMO-058-2 · fallo antes de tiempo: 3388 horas',
         @USU, [dbo].[FNC_AHORA]()),

        /* Todavia instalada. NO debe entrar en el promedio del criterio 3. */
        (@CLI, @COMP_ROD, @REP_ROD, @MED, 1, '2026-02-10 12:00', 12100,
         NULL, NULL, NULL, NULL, 0, @USU, NULL, NULL,
         'DEMO-058-3 · sigue puesta: no tiene vida util, tiene tiempo corriendo',
         @USU, [dbo].[FNC_AHORA]()),

        /* CRITERIO 2: sin medidor y sin lecturas. Solo vida util en dias. */
        (@CLI, ISNULL(@COMP_RED, @COMP_ROD), ISNULL(@REP_CORREA, @REP_ROD), NULL, 1,
         '2025-03-01 12:00', NULL, '2025-09-01 12:00', NULL, @M_PREVENTIVO, @E_DESGASTE_LEVE, 0, @USU, NULL, NULL,
         'DEMO-058-4 · el caso del criterio 2: nadie anoto el horometro',
         @USU, [dbo].[FNC_AHORA]())

    PRINT '--- 4 instalaciones de prueba creadas.'
END
GO

DECLARE @CLI INT = 1, @USU INT = 1
DECLARE @OT1 INT, @OT2 INT, @OT3 INT
DECLARE @PRV_A INT, @PRV_B INT
DECLARE @ST_SERVICIO INT, @ST_MONTAJE INT, @ST_TRANSPORTE INT
DECLARE @CLP INT, @UF INT

/* Tres ordenes CERRADAS del cliente: un servicio facturado cuelga de trabajo
   terminado. */
SELECT @OT1 = otr_id FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLI AND otr_correlativo = 3
SELECT @OT2 = otr_id FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLI AND otr_correlativo = 34
SELECT @OT3 = otr_id FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLI AND otr_correlativo = 35

/* El contratista y el proveedor de repuestos que ya existen. */
SELECT TOP 1 @PRV_A = prv_id FROM [dbo].[Proveedor] WHERE prv_cliente = @CLI AND prv_es_contratista = 1 AND prv_habilitado = 1 ORDER BY prv_id
SELECT TOP 1 @PRV_B = prv_id FROM [dbo].[Proveedor] WHERE prv_cliente = @CLI AND prv_id <> @PRV_A AND prv_habilitado = 1 ORDER BY prv_id

SELECT @ST_SERVICIO   = sti_id FROM [dbo].[Servicio_Tipo] WHERE sti_codigo = 'SERVICIO TECNICO' AND sti_cliente IS NULL
SELECT @ST_MONTAJE    = sti_id FROM [dbo].[Servicio_Tipo] WHERE sti_codigo = 'MONTAJE'          AND sti_cliente IS NULL
SELECT @ST_TRANSPORTE = sti_id FROM [dbo].[Servicio_Tipo] WHERE sti_codigo = 'TRANSPORTE'       AND sti_cliente IS NULL

SELECT @CLP = mon_id FROM [dbo].[Moneda] WHERE mon_codigo = 'CLP'
SELECT @UF  = mon_id FROM [dbo].[Moneda] WHERE mon_codigo = 'UF'

IF (@OT1 IS NULL OR @OT2 IS NULL OR @OT3 IS NULL OR @PRV_A IS NULL OR @ST_SERVICIO IS NULL)
    PRINT '--- FALTAN las ordenes cerradas o el proveedor: no se siembra el historial.'
ELSE IF EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Servicio] s
                  JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = s.ots_orden_trabajo
                 WHERE o.otr_cliente = @CLI AND s.ots_documento_referencia LIKE 'DEMO-%')
    PRINT '--- Los servicios de prueba ya existian.'
ELSE
BEGIN
    INSERT INTO [dbo].[Orden_Trabajo_Servicio]
        (ots_orden_trabajo, ots_proveedor, ots_servicio_tipo, ots_descripcion,
         ots_cantidad, ots_monto_unitario, ots_monto, ots_moneda,
         ots_documento_referencia, ots_fecha_servicio_utc, ots_fecha_documento,
         ots_usuario_creacion, ots_fecha_creacion, ots_habilitado)
    VALUES
        /* HU-065 #2: el contratista suma 730.000 en pesos... */
        (@OT1, @PRV_A, @ST_SERVICIO, 'Desmontaje y montaje de rodamientos',
         1, 450000, 450000, @CLP, 'DEMO-F-1042', '2025-06-20', '2025-06-25', @USU, [dbo].[FNC_AHORA](), 1),
        (@OT2, @PRV_A, ISNULL(@ST_MONTAJE, @ST_SERVICIO), 'Alineación láser del conjunto motor-bomba',
         1, 280000, 280000, @CLP, 'DEMO-F-1078', '2025-08-14', '2025-08-20', @USU, [dbo].[FNC_AHORA](), 1),

        /* ...y 12,5 UF, que NO se suman con los pesos. */
        (@OT1, @PRV_A, @ST_SERVICIO, 'Contrato de mantenimiento trimestral',
         1, 12.5, 12.5, @UF, 'DEMO-F-1099', '2025-09-30', '2025-10-05', @USU, [dbo].[FNC_AHORA](), 1),

        /* Sin moneda declarada: su propio grupo, no se mezcla con los pesos.
           Sin fecha de servicio ni de documento: cae por la de creacion. */
        (@OT3, @PRV_A, ISNULL(@ST_TRANSPORTE, @ST_SERVICIO), 'Flete de equipo a taller (sin moneda cargada)',
         1, NULL, 90000, NULL, 'DEMO-SIN-DOC', NULL, NULL, @USU, [dbo].[FNC_AHORA](), 1)

    /* Otro proveedor, para que el filtro por proveedor tenga algo que dejar
       afuera. */
    IF (@PRV_B IS NOT NULL)
        INSERT INTO [dbo].[Orden_Trabajo_Servicio]
            (ots_orden_trabajo, ots_proveedor, ots_servicio_tipo, ots_descripcion,
             ots_cantidad, ots_monto_unitario, ots_monto, ots_moneda,
             ots_documento_referencia, ots_fecha_servicio_utc, ots_fecha_documento,
             ots_usuario_creacion, ots_fecha_creacion, ots_habilitado)
        VALUES (@OT3, @PRV_B, @ST_SERVICIO, 'Revisión y ajuste de protecciones',
                1, 150000, 150000, @CLP, 'DEMO-F-2210', '2025-11-03', '2025-11-08', @USU, [dbo].[FNC_AHORA](), 1)

    DECLARE @SRV INT
    SELECT @SRV = COUNT(*) FROM [dbo].[Orden_Trabajo_Servicio] WHERE ots_documento_referencia LIKE 'DEMO-%'
    PRINT '--- servicios de prueba: ' + LTRIM(STR(@SRV))
END
GO


/* ========================================================================
   4. MENUS (patron del bloque 76)

      Vida util → Inventario › Operacion, junto a Existencias y Movimientos:
      es una lectura de lo que paso con las piezas.
      Historial → Terceros, junto a Proveedores.
   ======================================================================== */
DECLARE @OPERACION INT, @TERCEROS INT
SELECT @OPERACION = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = N'Operación' AND mnu_padre = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = N'Inventario' AND mnu_nivel = 2)
SELECT @TERCEROS  = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = N'Terceros' AND mnu_nivel = 2

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Inventario/Repuestos/RepuestoVidaUtil.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                               mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Vida útil de repuestos', N'Cuánto duró de verdad cada pieza instalada, contra lo que se esperaba',
            4, @OPERACION, 3, N'~/View/Inventario/Repuestos/RepuestoVidaUtil.aspx', 1, N'mdi mdi-timer-sand',
            (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER REPUESTOS'), 1)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT = N'~/View/Terceros/Proveedores/ProveedorHistorial.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                               mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Historial de servicios', N'Todo lo contratado a cada proveedor, con el gasto por moneda',
            3, @TERCEROS, 4, N'~/View/Terceros/Proveedores/ProveedorHistorial.aspx', 1, N'mdi mdi-history',
            (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER PROVEEDORES'), 1)
GO

/* El planificador es el actor de HU-058 y hoy no ve proveedores; el jefe si.
   Nada que agregar en VER REPUESTOS: ya lo tiene. */
PRINT '--- Vida util e historial de proveedor: SP, datos de prueba y menus listos (bloque 236).'
GO
