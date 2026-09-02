/* ============================================================================
   SIGMA — Bloque 82
   LEER Y MARCAR LAS NOTIFICACIONES
   ----------------------------------------------------------------------------

   EL FILTRO ES EL PERMISO DEL USUARIO, NO UNA LISTA DE DESTINATARIOS

     Cada consulta recibe @USUARIO y devuelve solo las alertas cuyo tipo exige
     un permiso que esa persona tiene. Asi, cuando alguien cambia de perfil, su
     bandeja cambia sola: no hay que reasignar nada.

   EL RESUMEN DEVUELVE DOS COSAS EN UNA LLAMADA

     El numero de la campana y el numero de cada menu. La cabecera del sitio se
     dibuja en TODAS las paginas: pedirlos por separado seria duplicar el costo
     en cada carga del sitio entero.

   NO LEIDA NO ES LO MISMO QUE ABIERTA

     Una alerta puede estar abierta y ya vista -el bodeguero la leyo y esta
     pidiendo el repuesto-. El punto rojo cuenta lo NO VISTO; la bandeja
     muestra lo abierto, visto o no. Confundirlos haria que el contador nunca
     baje y la gente deje de mirarlo.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. LA BANDEJA
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
            e.aet_codigo,
            e.aet_nombre,
            ISNULL(s.sev_codigo, 'NORMAL')     AS sev_codigo,
            ISNULL(s.sev_nombre, 'Normal')     AS sev_nombre,
            a.ale_repuesto, a.ale_bodega, a.ale_repuesto_lote,
            a.ale_valor_observado, a.ale_valor_umbral,

            /* Lo que decide el punto: sin fila en Alerta_Lectura, no leida. */
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
   2. LOS NUMEROS: la campana y cada menu
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_ALERTA_RESUMEN') IS NOT NULL DROP PROCEDURE [dbo].[SEL_ALERTA_RESUMEN]
GO

CREATE PROCEDURE [dbo].[SEL_ALERTA_RESUMEN]
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON

    /* Tabla temporal y no CTE: un CTE solo vive para la sentencia que le
       sigue, y aca hacen falta DOS lecturas -el total y el desglose por
       menu-. La segunda no lo veria y fallaria con "Invalid object name". */
    IF OBJECT_ID('tempdb..#VISIBLES') IS NOT NULL DROP TABLE #VISIBLES

    SELECT  a.ale_id, t.alt_menu_link,
            CASE WHEN l.alr_id IS NULL THEN 1 ELSE 0 END AS NO_LEIDA
    INTO    #VISIBLES
    FROM    [dbo].[Alerta] a
    JOIN    [dbo].[Alerta_Tipo] t   ON t.alt_id = a.ale_alerta_tipo
    JOIN    [dbo].[Alerta_Estado] e ON e.aet_id = a.ale_alerta_estado
    LEFT JOIN [dbo].[Permiso] pm    ON pm.prm_id = t.alt_permiso
    LEFT JOIN [dbo].[Alerta_Lectura] l ON l.alr_alerta = a.ale_id AND l.alr_usuario = @USUARIO
    WHERE   a.ale_cliente = @CLIENTE
      AND   a.ale_habilitado = 1
      AND   e.aet_codigo NOT IN ('RESUELTA', 'DESCARTADA')
      AND   (t.alt_permiso IS NULL
             OR [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, pm.prm_codigo) = 1)
    SELECT  COUNT(*)      AS ABIERTAS,
            SUM(NO_LEIDA) AS NO_LEIDAS
    FROM    #VISIBLES

    /* El numero de cada menu. Va por LINK y no por id de menu porque el mismo
       hallazgo puede resolverse desde mas de una pantalla segun el modulo, y
       el link es lo que la cabecera ya conoce cuando dibuja el menu. */
    SELECT  alt_menu_link AS MENU_LINK,
            COUNT(*)      AS ABIERTAS,
            SUM(NO_LEIDA) AS NO_LEIDAS
    FROM    #VISIBLES
    WHERE   alt_menu_link IS NOT NULL AND LEN(alt_menu_link) > 0
    GROUP BY alt_menu_link
GO


/* ========================================================================
   3. MARCAR LEIDAS

      @ALERTA nulo marca TODAS las visibles: es el "marcar todo como leido"
      del panel, y tiene que respetar el mismo filtro de permiso que la
      bandeja -si no, marcaria como leidas alertas que la persona nunca vio-.
   ======================================================================== */
IF OBJECT_ID('dbo.UPD_ALERTA_LEER') IS NOT NULL DROP PROCEDURE [dbo].[UPD_ALERTA_LEER]
GO

CREATE PROCEDURE [dbo].[UPD_ALERTA_LEER]
    @CLIENTE INT,
    @USUARIO INT,
    @ALERTA  INT = NULL
AS
SET NOCOUNT ON

    INSERT INTO [dbo].[Alerta_Lectura] (alr_alerta, alr_usuario, alr_fecha)
    SELECT  a.ale_id, @USUARIO, GETDATE()
    FROM    [dbo].[Alerta] a
    JOIN    [dbo].[Alerta_Tipo] t   ON t.alt_id = a.ale_alerta_tipo
    JOIN    [dbo].[Alerta_Estado] e ON e.aet_id = a.ale_alerta_estado
    LEFT JOIN [dbo].[Permiso] pm    ON pm.prm_id = t.alt_permiso
    WHERE   a.ale_cliente = @CLIENTE
      AND   a.ale_habilitado = 1
      AND   (@ALERTA IS NULL OR a.ale_id = @ALERTA)
      AND   e.aet_codigo NOT IN ('RESUELTA', 'DESCARTADA')
      AND   (t.alt_permiso IS NULL
             OR [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, pm.prm_codigo) = 1)
      /* Sin esto el UNIQUE reventaria al marcar dos veces, y marcar dos veces
         es lo normal: se abre el panel, se cierra y se vuelve a abrir. */
      AND   NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Lectura] l
                         WHERE l.alr_alerta = a.ale_id AND l.alr_usuario = @USUARIO)

    SELECT @@ROWCOUNT AS MARCADAS
GO
