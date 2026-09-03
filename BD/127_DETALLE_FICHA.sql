/* ============================================================================
   SIGMA — Bloque 127
   LA FICHA DEL PANEL LATERAL
   ----------------------------------------------------------------------------

   QUE RESUELVE

     El panel lateral se armaba leyendo las celdas de la fila de la grilla.
     Eso significa que solo podia mostrar lo que ya estaba a la vista: abrirlo
     no aportaba nada que no se leyera dos centimetros mas a la izquierda.

     Aca esta lo que NO cabe en la grilla y es lo que la gente necesita para
     decidir sin abrir la ficha completa: donde esta el activo, de que modelo
     es, desde cuando opera, cuanto stock tiene el repuesto, con que esta
     comprometido el proveedor.

   UN SOLO PROCEDIMIENTO Y UNA LISTA BLANCA

     `@ENTIDAD` va contra una lista cerrada. Un nombre que no este ahi no
     devuelve nada, y no hay SQL dinamico por donde colar otra cosa.

     Devuelve pares SECCION / ETIQUETA / VALOR en vez de columnas fijas. Asi
     el panel dibuja lo que venga sin saber de que entidad se trata, y agregar
     una quinta entidad manana es una rama mas aca y cero lineas de
     JavaScript.

   LO QUE NO SE SABE, NO SE INVENTA

     Cada valor sale con ISNULL a cadena vacia y el panel no dibuja la fila
     cuando esta vacia. Es preferible una ficha corta y cierta a una completa
     a medias inventar.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.SEL_DETALLE_FICHA') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_DETALLE_FICHA]
GO

CREATE PROCEDURE [dbo].[SEL_DETALLE_FICHA]
    @ENTIDAD    VARCHAR(40),
    @ID         INT,
    @CLIENTE    INT
AS
SET NOCOUNT ON

DECLARE @R TABLE (SECCION NVARCHAR(60), ETIQUETA NVARCHAR(80),
                  VALOR NVARCHAR(400), ORDEN INT)

/* ========================================================================
   ACTIVO
   ======================================================================== */
IF (@ENTIDAD = 'ACTIVO')
BEGIN
    INSERT INTO @R (SECCION, ETIQUETA, VALOR, ORDEN)
    SELECT x.SECCION, x.ETIQUETA, x.VALOR, x.ORDEN
    FROM (
        SELECT 'Ubicación' AS SECCION, 'Instalación' AS ETIQUETA,
               ISNULL(i.cin_nombre, '') AS VALOR, 1 AS ORDEN
          FROM [dbo].[Activo] a
          LEFT JOIN [dbo].[Cliente_Instalacion] i ON i.cin_id = a.act_cliente_instalacion
         WHERE a.act_id = @ID AND a.act_cliente = @CLIENTE

        UNION ALL
        SELECT 'Ubicación', 'Área', ISNULL(ar.iar_nombre, ''), 2
          FROM [dbo].[Activo] a
          LEFT JOIN [dbo].[Instalacion_Area] ar ON ar.iar_id = a.act_instalacion_area
         WHERE a.act_id = @ID AND a.act_cliente = @CLIENTE

        UNION ALL
        SELECT 'Ubicación', 'Posición', ISNULL(p.apo_nombre, ''), 3
          FROM [dbo].[Activo] a
          LEFT JOIN [dbo].[Activo_Posicion] p ON p.apo_id = a.act_activo_posicion
         WHERE a.act_id = @ID AND a.act_cliente = @CLIENTE

        UNION ALL
        SELECT 'Ubicación', 'Centro de costo', ISNULL(cc.cco_nombre, ''), 4
          FROM [dbo].[Activo] a
          LEFT JOIN [dbo].[Centro_Costo] cc ON cc.cco_id = a.act_centro_costo
         WHERE a.act_id = @ID AND a.act_cliente = @CLIENTE

        /* ---- ficha tecnica ---- */
        UNION ALL
        SELECT 'Ficha técnica', 'Tipo', ISNULL(t.ati_nombre, ''), 10
          FROM [dbo].[Activo] a
          LEFT JOIN [dbo].[Activo_Tipo] t ON t.ati_id = a.act_activo_tipo
         WHERE a.act_id = @ID AND a.act_cliente = @CLIENTE

        UNION ALL
        SELECT 'Ficha técnica', 'Modelo',
               LTRIM(RTRIM(ISNULL(m.amo_fabricante, '') + ' ' + ISNULL(m.amo_nombre, ''))), 11
          FROM [dbo].[Activo] a
          LEFT JOIN [dbo].[Activo_Modelo] m ON m.amo_id = a.act_activo_modelo
         WHERE a.act_id = @ID AND a.act_cliente = @CLIENTE

        UNION ALL
        SELECT 'Ficha técnica', 'Fabricante', ISNULL(a.act_fabricante, ''), 12
          FROM [dbo].[Activo] a WHERE a.act_id = @ID AND a.act_cliente = @CLIENTE

        UNION ALL
        SELECT 'Ficha técnica', 'N° de serie', ISNULL(a.act_numero_serie, ''), 13
          FROM [dbo].[Activo] a WHERE a.act_id = @ID AND a.act_cliente = @CLIENTE

        UNION ALL
        SELECT 'Ficha técnica', 'Año de fabricación',
               ISNULL(CAST(NULLIF(a.act_anio_fabricacion, 0) AS VARCHAR(10)), ''), 14
          FROM [dbo].[Activo] a WHERE a.act_id = @ID AND a.act_cliente = @CLIENTE

        /* ---- operacion ---- */
        UNION ALL
        SELECT 'Operación', 'Criticidad', ISNULL(cr.crn_nombre, ''), 20
          FROM [dbo].[Activo] a
          LEFT JOIN [dbo].[Criticidad_Nivel] cr ON cr.crn_id = a.act_criticidad_nivel
         WHERE a.act_id = @ID AND a.act_cliente = @CLIENTE

        UNION ALL
        SELECT 'Operación', 'Puesta en marcha',
               ISNULL(CONVERT(VARCHAR(10), a.act_fecha_puesta_marcha, 103), ''), 21
          FROM [dbo].[Activo] a WHERE a.act_id = @ID AND a.act_cliente = @CLIENTE

        /* Cuantos medidores tiene y cuantos componentes cuelgan de el: dos
           numeros que dicen si es un equipo simple o uno que arrastra media
           linea. */
        UNION ALL
        SELECT 'Operación', 'Medidores',
               CAST((SELECT COUNT(*) FROM [dbo].[Activo_Medidor] am
                      WHERE am.ame_activo = @ID AND am.ame_habilitado = 1) AS VARCHAR(10)), 22
          FROM [dbo].[Activo] a WHERE a.act_id = @ID AND a.act_cliente = @CLIENTE

        UNION ALL
        SELECT 'Operación', 'Componentes',
               CAST((SELECT COUNT(*) FROM [dbo].[Activo] h
                      WHERE h.act_activo_padre = @ID AND h.act_habilitado = 1) AS VARCHAR(10)), 23
          FROM [dbo].[Activo] a WHERE a.act_id = @ID AND a.act_cliente = @CLIENTE
    ) x
    WHERE ISNULL(x.VALOR, '') <> '' AND x.VALOR <> '0'
END

/* ========================================================================
   PROVEEDOR
   ======================================================================== */
ELSE IF (@ENTIDAD = 'PROVEEDOR')
BEGIN
    INSERT INTO @R (SECCION, ETIQUETA, VALOR, ORDEN)
    SELECT x.SECCION, x.ETIQUETA, x.VALOR, x.ORDEN
    FROM (
        SELECT 'Contacto' AS SECCION, 'Persona' AS ETIQUETA,
               ISNULL(p.prv_contacto, '') AS VALOR, 1 AS ORDEN
          FROM [dbo].[Proveedor] p WHERE p.prv_id = @ID AND p.prv_cliente = @CLIENTE
        UNION ALL SELECT 'Contacto', 'Correo', ISNULL(p.prv_email, ''), 2
          FROM [dbo].[Proveedor] p WHERE p.prv_id = @ID AND p.prv_cliente = @CLIENTE
        UNION ALL SELECT 'Contacto', 'Teléfono', ISNULL(p.prv_telefono, ''), 3
          FROM [dbo].[Proveedor] p WHERE p.prv_id = @ID AND p.prv_cliente = @CLIENTE
        UNION ALL SELECT 'Contacto', 'Dirección', ISNULL(p.prv_direccion, ''), 4
          FROM [dbo].[Proveedor] p WHERE p.prv_id = @ID AND p.prv_cliente = @CLIENTE

        UNION ALL SELECT 'Identificación', 'Giro', ISNULL(p.prv_giro, ''), 10
          FROM [dbo].[Proveedor] p WHERE p.prv_id = @ID AND p.prv_cliente = @CLIENTE
        UNION ALL SELECT 'Identificación', 'Razón social', ISNULL(p.prv_razon_social, ''), 11
          FROM [dbo].[Proveedor] p WHERE p.prv_id = @ID AND p.prv_cliente = @CLIENTE

        /* Con que esta comprometido: es lo que decide si se puede dar de baja
           y si conviene seguir comprandole. */
        UNION ALL SELECT 'Relación comercial', 'Servicios prestados',
               CAST((SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Servicio] s
                      WHERE s.ots_proveedor = @ID AND s.ots_habilitado = 1) AS VARCHAR(10)), 20
          FROM [dbo].[Proveedor] p WHERE p.prv_id = @ID AND p.prv_cliente = @CLIENTE

        UNION ALL SELECT 'Relación comercial', 'Lotes entregados',
               CAST((SELECT COUNT(*) FROM [dbo].[Repuesto_Lote] l
                      WHERE l.rlo_proveedor = @ID) AS VARCHAR(10)), 21
          FROM [dbo].[Proveedor] p WHERE p.prv_id = @ID AND p.prv_cliente = @CLIENTE

        UNION ALL SELECT 'Relación comercial', 'Último servicio',
               ISNULL(CONVERT(VARCHAR(10),
                     (SELECT MAX(s.ots_fecha_servicio_utc) FROM [dbo].[Orden_Trabajo_Servicio] s
                       WHERE s.ots_proveedor = @ID AND s.ots_habilitado = 1), 103), ''), 22
          FROM [dbo].[Proveedor] p WHERE p.prv_id = @ID AND p.prv_cliente = @CLIENTE
    ) x
    WHERE ISNULL(x.VALOR, '') <> '' AND x.VALOR <> '0'
END

/* ========================================================================
   BODEGA
   ======================================================================== */
ELSE IF (@ENTIDAD = 'BODEGA')
BEGIN
    INSERT INTO @R (SECCION, ETIQUETA, VALOR, ORDEN)
    SELECT x.SECCION, x.ETIQUETA, x.VALOR, x.ORDEN
    FROM (
        SELECT 'Ubicación' AS SECCION, 'Instalación' AS ETIQUETA,
               ISNULL(i.cin_nombre, '') AS VALOR, 1 AS ORDEN
          FROM [dbo].[Bodega] b
          LEFT JOIN [dbo].[Cliente_Instalacion] i ON i.cin_id = b.bod_cliente_instalacion
         WHERE b.bod_id = @ID AND b.bod_cliente = @CLIENTE

        UNION ALL SELECT 'Ubicación', 'Descripción', ISNULL(b.bod_descripcion, ''), 2
          FROM [dbo].[Bodega] b WHERE b.bod_id = @ID AND b.bod_cliente = @CLIENTE

        /* Lo que de verdad se quiere saber de una bodega: cuanto guarda y
           cuanto de eso esta bajo el minimo. */
        /* OJO: la CANTIDAD actual no es una columna de ninguna tabla —se
           deriva de los movimientos—, asi que aca no se muestra. Poner un
           numero inventado en una ficha de bodega es peor que no ponerlo.

           Lo que si esta guardado es que repuestos tiene configurados y con
           que politica de reposicion. */
        UNION ALL SELECT 'Inventario', 'Repuestos configurados',
               CAST((SELECT COUNT(*) FROM [dbo].[Repuesto_Bodega_Stock] e
                      WHERE e.rbs_bodega = @ID AND e.rbs_habilitado = 1) AS VARCHAR(10)), 10
          FROM [dbo].[Bodega] b WHERE b.bod_id = @ID AND b.bod_cliente = @CLIENTE

        UNION ALL SELECT 'Inventario', 'Con stock mínimo definido',
               CAST((SELECT COUNT(*) FROM [dbo].[Repuesto_Bodega_Stock] e
                      WHERE e.rbs_bodega = @ID AND e.rbs_habilitado = 1
                        AND e.rbs_stock_minimo IS NOT NULL) AS VARCHAR(10)), 11
          FROM [dbo].[Bodega] b WHERE b.bod_id = @ID AND b.bod_cliente = @CLIENTE
    ) x
    WHERE ISNULL(x.VALOR, '') <> ''
END

/* ========================================================================
   REPUESTO
   ======================================================================== */
ELSE IF (@ENTIDAD = 'REPUESTO')
BEGIN
    INSERT INTO @R (SECCION, ETIQUETA, VALOR, ORDEN)
    SELECT x.SECCION, x.ETIQUETA, x.VALOR, x.ORDEN
    FROM (
        SELECT 'Ficha técnica' AS SECCION, 'Fabricante' AS ETIQUETA,
               ISNULL(r.rep_fabricante, '') AS VALOR, 1 AS ORDEN
          FROM [dbo].[Repuesto] r WHERE r.rep_id = @ID AND r.rep_cliente = @CLIENTE
        UNION ALL SELECT 'Ficha técnica', 'Modelo', ISNULL(r.rep_modelo, ''), 2
          FROM [dbo].[Repuesto] r WHERE r.rep_id = @ID AND r.rep_cliente = @CLIENTE
        UNION ALL SELECT 'Ficha técnica', 'Unidad', ISNULL(u.ume_nombre, ''), 3
          FROM [dbo].[Repuesto] r
          LEFT JOIN [dbo].[Unidad_Medida] u ON u.ume_id = r.rep_unidad_medida
         WHERE r.rep_id = @ID AND r.rep_cliente = @CLIENTE

        UNION ALL SELECT 'Ficha técnica', 'Vida útil',
               CASE WHEN ISNULL(r.rep_vida_util_hora, 0) > 0
                         THEN CAST(r.rep_vida_util_hora AS VARCHAR(10)) + ' h'
                    WHEN ISNULL(r.rep_vida_util_dia, 0) > 0
                         THEN CAST(r.rep_vida_util_dia AS VARCHAR(10)) + ' días'
                    WHEN ISNULL(r.rep_vida_util_ciclo, 0) > 0
                         THEN CAST(r.rep_vida_util_ciclo AS VARCHAR(10)) + ' ciclos'
                    ELSE '' END, 4
          FROM [dbo].[Repuesto] r WHERE r.rep_id = @ID AND r.rep_cliente = @CLIENTE

        UNION ALL SELECT 'Ficha técnica', 'Tipo',
               LTRIM(CASE WHEN r.rep_es_reparable = 1 THEN 'Reparable ' ELSE '' END +
                     CASE WHEN r.rep_es_consumible = 1 THEN 'Consumible ' ELSE '' END +
                     CASE WHEN r.rep_controla_lote = 1 THEN '· Controla lote' ELSE '' END), 5
          FROM [dbo].[Repuesto] r WHERE r.rep_id = @ID AND r.rep_cliente = @CLIENTE

        /* Cuanto hay y donde: es lo primero que se pregunta al mirar un
           repuesto, y la grilla no lo muestra por bodega. */
        /* La cantidad actual se deriva de los movimientos, no es columna: no
           se muestra en vez de inventarla. Si se ve en que bodegas esta
           configurado y con que minimo, que es lo que decide si hay que
           reponer. */
        UNION ALL SELECT 'Inventario', 'Bodegas donde está configurado',
               CAST((SELECT COUNT(*) FROM [dbo].[Repuesto_Bodega_Stock] e
                      WHERE e.rbs_repuesto = @ID AND e.rbs_habilitado = 1) AS VARCHAR(10)), 10
          FROM [dbo].[Repuesto] r WHERE r.rep_id = @ID AND r.rep_cliente = @CLIENTE

        UNION ALL SELECT 'Inventario', 'Stock mínimo',
               ISNULL(CAST((SELECT CAST(MIN(e.rbs_stock_minimo) AS DECIMAL(18,0))
                            FROM [dbo].[Repuesto_Bodega_Stock] e
                           WHERE e.rbs_repuesto = @ID AND e.rbs_habilitado = 1) AS VARCHAR(20)), ''), 11
          FROM [dbo].[Repuesto] r WHERE r.rep_id = @ID AND r.rep_cliente = @CLIENTE

        UNION ALL SELECT 'Inventario', 'Costo de referencia',
               CASE WHEN ISNULL(r.rep_costo_referencia, 0) > 0
                    THEN CAST(CAST(r.rep_costo_referencia AS DECIMAL(18,0)) AS VARCHAR(20)) +
                         ISNULL(' ' + m.mon_nombre, '')
                    ELSE '' END, 12
          FROM [dbo].[Repuesto] r
          LEFT JOIN [dbo].[Moneda] m ON m.mon_id = r.rep_moneda
         WHERE r.rep_id = @ID AND r.rep_cliente = @CLIENTE

        UNION ALL SELECT 'Compatibilidad', 'Activos compatibles',
               CAST((SELECT COUNT(*) FROM [dbo].[Repuesto_Compatibilidad] c
                      WHERE c.rco_repuesto = @ID) AS VARCHAR(10)), 20
          FROM [dbo].[Repuesto] r WHERE r.rep_id = @ID AND r.rep_cliente = @CLIENTE
    ) x
    WHERE ISNULL(x.VALOR, '') <> '' AND x.VALOR <> '0'
END

SELECT SECCION, ETIQUETA, VALOR, ORDEN FROM @R ORDER BY ORDEN
GO

PRINT '--- SEL_DETALLE_FICHA creado.'
GO

EXEC [dbo].[SEL_DETALLE_FICHA] @ENTIDAD = 'ACTIVO',    @ID = 1, @CLIENTE = 1
EXEC [dbo].[SEL_DETALLE_FICHA] @ENTIDAD = 'PROVEEDOR', @ID = 3, @CLIENTE = 1
GO

PRINT '127_DETALLE_FICHA aplicado.'
GO
