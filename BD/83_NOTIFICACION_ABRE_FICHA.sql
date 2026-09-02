/* ============================================================================
   SIGMA — Bloque 83
   LA NOTIFICACION ABRE EL REGISTRO, NO EL LISTADO
   ----------------------------------------------------------------------------

   EL PROBLEMA CON LLEVAR AL LISTADO

     Hasta ahora cada tipo de alerta declaraba alt_menu_link: la pantalla donde
     se resuelve. Tocar "DEMO-ROD-6205 bajo el minimo" abria Existencias, con
     sus cuarenta filas, y la persona tenia que volver a buscar el repuesto que
     la notificacion acababa de nombrarle.

     Avisar y despues hacer buscar es la mitad del trabajo.

   DOS DESTINOS, NO UNO

     alt_menu_link  ->  donde vive el tema. Sirve para el numero del menu
                        lateral: "las tres alertas son de Existencias".
     alt_ficha_link ->  el registro concreto, que es lo que se abre al tocar.

     Son distintos a proposito. El badge del menu apunta a una PANTALLA; la
     notificacion apunta a UNA FILA.

   QUE ID SE LE PASA A LA FICHA

     La tabla Alerta cuelga el hallazgo de columnas distintas segun el tipo
     -ale_repuesto, ale_bodega, ale_activo, ale_orden_trabajo-. En vez de un
     CASE en cada consulta, el TIPO declara de que columna sale su id.

     Asi, agregar un tipo nuevo es una fila con su ficha y su columna, y
     ninguna consulta cambia.
   ============================================================================ */

SET NOCOUNT ON
GO

IF COL_LENGTH('dbo.Alerta_Tipo', 'alt_ficha_link') IS NULL
    ALTER TABLE [dbo].[Alerta_Tipo] ADD [alt_ficha_link] NVARCHAR(400) NULL
GO

/* Que columna de Alerta lleva el id que la ficha necesita. */
IF COL_LENGTH('dbo.Alerta_Tipo', 'alt_ficha_id_columna') IS NULL
    ALTER TABLE [dbo].[Alerta_Tipo] ADD [alt_ficha_id_columna] NVARCHAR(60) NULL
GO


UPDATE t
SET    t.alt_ficha_link       = v.ficha,
       t.alt_ficha_id_columna = v.col
FROM   [dbo].[Alerta_Tipo] t
JOIN   (VALUES
    /* La existencia se mira por repuesto: la ficha muestra en que bodegas
       esta y cuanto hay en cada una, que es exactamente lo que hace falta
       para decidir que reponer. */
    ('STOCK MINIMO',    '~/View/Inventario/Existencias/Existencia.aspx', 'ale_repuesto'),
    ('STOCK MAXIMO',    '~/View/Inventario/Existencias/Existencia.aspx', 'ale_repuesto'),

    /* El lote se corrige desde la ficha del repuesto, que es donde vive su
       pestana de lotes. */
    ('LOTE VENCIDO',    '~/View/Inventario/Repuestos/Repuesto.aspx',     'ale_repuesto'),
    ('LOTE POR VENCER', '~/View/Inventario/Repuestos/Repuesto.aspx',     'ale_repuesto')
) AS v (cod, ficha, col) ON v.cod = t.alt_codigo

PRINT '--- Tipos con ficha: ' + LTRIM(STR(@@ROWCOUNT))
GO


/* ========================================================================
   SEL_ALERTA devuelve tambien a donde ir

      FICHA_ID se resuelve aca y no en la pantalla: la columna de la que sale
      la sabe el TIPO, y hacer que cada consumidor -web, app- repita ese CASE
      seria copiar la misma regla en dos idiomas.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_ALERTA') IS NOT NULL DROP PROCEDURE [dbo].[SEL_ALERTA]
GO

CREATE PROCEDURE [dbo].[SEL_ALERTA]
    @CLIENTE    INT,
    @USUARIO    INT,
    @SOLO_ABIERTAS BIT = 1,
    @TOPE       INT = 50
AS
SET NOCOUNT ON

    SELECT  TOP (@TOPE)
            a.ale_id,
            a.ale_titulo,
            ISNULL(a.ale_descripcion, '')      AS ale_descripcion,
            a.ale_fecha_deteccion_utc,
            t.alt_codigo,
            t.alt_nombre,
            ISNULL(t.alt_icono, 'mdi mdi-bell-outline')  AS alt_icono,
            ISNULL(t.alt_menu_link, '')        AS alt_menu_link,
            ISNULL(t.alt_ficha_link, '')       AS FICHA_LINK,

            /* El id que la ficha espera, sacado de la columna que el tipo
               declara. Cero significa "no hay registro que abrir". */
            CASE t.alt_ficha_id_columna
                 WHEN 'ale_repuesto'       THEN a.ale_repuesto
                 WHEN 'ale_bodega'         THEN a.ale_bodega
                 WHEN 'ale_repuesto_lote'  THEN a.ale_repuesto_lote
                 WHEN 'ale_activo'         THEN a.ale_activo
                 WHEN 'ale_orden_trabajo'  THEN a.ale_orden_trabajo
                 ELSE NULL
            END                                AS FICHA_ID,

            e.aet_codigo,
            e.aet_nombre,
            ISNULL(s.sev_codigo, 'NORMAL')     AS sev_codigo,
            ISNULL(s.sev_nombre, 'Normal')     AS sev_nombre,
            a.ale_repuesto, a.ale_bodega, a.ale_repuesto_lote,
            a.ale_valor_observado, a.ale_valor_umbral,

            /* Sin fila en Alerta_Lectura, no leida. */
            CASE WHEN l.alr_id IS NULL THEN 0 ELSE 1 END AS LEIDA,

            /* Cuanto hace. Se calcula aca y no en la pantalla porque la app y
               la web tienen que decir lo mismo. */
            DATEDIFF(MINUTE, a.ale_fecha_deteccion_utc, GETUTCDATE()) AS MINUTOS
    FROM    [dbo].[Alerta] a
    JOIN    [dbo].[Alerta_Tipo] t   ON t.alt_id = a.ale_alerta_tipo
    JOIN    [dbo].[Alerta_Estado] e ON e.aet_id = a.ale_alerta_estado
    LEFT JOIN [dbo].[Permiso] pm    ON pm.prm_id = t.alt_permiso
    LEFT JOIN [dbo].[Severidad] s   ON s.sev_id = a.ale_severidad
    LEFT JOIN [dbo].[Alerta_Lectura] l ON l.alr_alerta = a.ale_id AND l.alr_usuario = @USUARIO
    WHERE   a.ale_cliente = @CLIENTE
      AND   a.ale_habilitado = 1
      AND   (@SOLO_ABIERTAS = 0 OR e.aet_codigo NOT IN ('RESUELTA', 'DESCARTADA'))
      AND   (t.alt_permiso IS NULL
             OR [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, pm.prm_codigo) = 1)
    ORDER BY CASE WHEN l.alr_id IS NULL THEN 0 ELSE 1 END,   /* lo no leido primero */
             ISNULL(s.sev_id, 0) DESC,                        /* lo mas grave antes */
             a.ale_fecha_deteccion_utc DESC
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
EXEC [dbo].[SEL_ALERTA] @CLIENTE = 1, @USUARIO = 1, @TOPE = 5
GO
