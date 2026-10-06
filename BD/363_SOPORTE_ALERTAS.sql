USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     MODULO SOPORTE: los avisos van por la campana que ya
--                  existe. SEL_ALERTA, SEL_ALERTA_RESUMEN y UPD_ALERTA_LEER
--                  reconocen los avisos dirigidos.
-- =============================================
-- Va DESPUES de 362_SOPORTE_CAMPANAS_SP. Generado por _scratch/gen_363.py
-- desde la definicion que estaba en la base: solo cambia lo marcado.
--
--   1. Un aviso con destinatario sigue a esa persona aunque tenga abierto
--      otro cliente: el agente de soporte atiende a todos los clientes y su
--      «te asignaron SUP-000123» no puede depender de cual eligio al entrar.
--   2. SEL_ALERTA_RESUMEN y UPD_ALERTA_LEER no filtraban por destinatario
--      (SEL_ALERTA si): el punto rojo contaba avisos ajenos. Se iguala.
--   3. La ficha de un aviso de soporte abre el ticket (ale_soporte_ticket)
--      o el contenido de ayuda (ale_ayuda_contenido).
-- =============================================
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ALERTA]
    @CLIENTE            INT,
    @USUARIO            INT,
    @SOLO_ABIERTAS      BIT = 1,
    @TOPE               INT = 50,
    @GRUPO              VARCHAR(20) = NULL,   /* ACTIVAS · GESTION · RESUELTAS */
    @SEVERIDAD          VARCHAR(50) = NULL,
    @TIPO               VARCHAR(100) = NULL,
    @SIN_RESPONSABLE    BIT = NULL,
    @FILTRO             VARCHAR(200) = NULL
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

            CASE t.alt_ficha_id_columna
                 WHEN 'ale_repuesto'       THEN a.ale_repuesto
                 WHEN 'ale_bodega'         THEN a.ale_bodega
                 WHEN 'ale_repuesto_lote'  THEN a.ale_repuesto_lote
                 WHEN 'ale_activo'         THEN a.ale_activo
                 WHEN 'ale_orden_trabajo'  THEN a.ale_orden_trabajo
                 WHEN 'ale_soporte_ticket'  THEN a.ale_soporte_ticket
                 WHEN 'ale_ayuda_contenido' THEN a.ale_ayuda_contenido
                 ELSE NULL
            END                                AS FICHA_ID,

            e.aet_codigo,
            e.aet_nombre,
            ISNULL(s.sev_codigo, 'NORMAL')     AS sev_codigo,
            ISNULL(s.sev_nombre, 'Normal')     AS sev_nombre,
            a.ale_repuesto, a.ale_bodega, a.ale_repuesto_lote,
            a.ale_valor_observado, a.ale_valor_umbral,

            CASE WHEN l.alr_id IS NULL THEN 0 ELSE 1 END AS LEIDA,
            DATEDIFF(MINUTE, a.ale_fecha_deteccion_utc, GETUTCDATE()) AS MINUTOS,

            /* ---- lo que agrega el Centro de Accion Operacional ---- */

            a.ale_usuario_responsable,
            ISNULL(ur.usu_nombre + ' ' + ur.usu_apellido_paterno, '') AS RESPONSABLE_NOMBRE,
            a.ale_cliente_instalacion,
            ISNULL(ci.cin_nombre, '')          AS INSTALACION_NOMBRE,
            a.ale_activo,
            ISNULL(ac.act_codigo, '')          AS ACTIVO_CODIGO,
            ISNULL(ac.act_nombre, '')          AS ACTIVO_NOMBRE,
            ISNULL(rp.rep_codigo, '')          AS REPUESTO_CODIGO,
            ISNULL(rp.rep_nombre, '')          AS REPUESTO_NOMBRE,
            ISNULL(bo.bod_nombre, '')          AS BODEGA_NOMBRE,

            /* De que componente habla, si habla de uno. */
            a.ale_activo_componente,
            ISNULL(co.aco_codigo, '')          AS COMPONENTE_CODIGO,
            ISNULL(co.aco_nombre, '')          AS COMPONENTE_NOMBRE,

            /* LA FOTO DE LO QUE LE PASA

               Del activo si la alerta es de un activo; del activo PADRE si es
               de un componente -Archivo_Vinculo no tiene columna de
               componente-; y del repuesto si es de inventario.

               Solo imagenes y solo del cliente de la alerta, la misma
               precaucion de API_SEL_ACTIVO_FOTO. La portada primero; si no hay
               ninguna marcada, la primera que se subio. */
            (SELECT TOP 1 img.arc_ruta
               FROM [dbo].[Archivo_Vinculo] vin
               JOIN [dbo].[Archivo]         img ON img.arc_id = vin.avi_archivo
              WHERE vin.avi_habilitado = 1
                AND img.arc_habilitado = 1
                AND img.arc_cliente    = a.ale_cliente
                AND img.arc_mime LIKE 'image/%'
                AND LTRIM(RTRIM(ISNULL(img.arc_ruta, ''))) <> ''
                AND (   (a.ale_activo IS NOT NULL
                         AND vin.avi_activo = a.ale_activo)
                     OR (a.ale_activo IS NULL
                         AND a.ale_activo_componente IS NOT NULL
                         AND vin.avi_activo = co.aco_activo)
                     OR (a.ale_activo IS NULL
                         AND a.ale_activo_componente IS NULL
                         AND a.ale_repuesto IS NOT NULL
                         AND vin.avi_repuesto = a.ale_repuesto))
              ORDER BY vin.avi_es_referencia DESC,
                       ISNULL(vin.avi_orden, 0),
                       img.arc_id)          AS FOTO_RUTA,
            a.ale_ocurrencias,
            a.ale_fecha_primera_ocurrencia_utc,
            a.ale_fecha_ultima_ocurrencia_utc,

            /* Alerta nacida del modelo predictivo. La pantalla la marca con
               el distintivo de SIGMA AI y solo a ella: rotular como IA una
               alerta de stock bajo el minimo -que es una resta- seria
               atribuirle al modelo un trabajo que no hizo. */
            CAST(CASE WHEN t.alt_codigo = 'PREDICCION RIESGO' AND a.ale_prediccion IS NOT NULL
                      THEN 1 ELSE 0 END AS BIT) AS ES_PREDICCION,
            a.ale_prediccion,

            /* El grupo con el que la pantalla arma sus pesta·as. */
            CASE WHEN e.aet_codigo IN ('RESUELTA', 'DESCARTADA') THEN 'RESUELTAS'
                 WHEN e.aet_codigo = 'EN GESTION' THEN 'GESTION'
                 ELSE 'ACTIVAS' END            AS GRUPO,

            /* La prioridad de la cola. Una critica sin responsable va antes
               que una critica que ya tiene a alguien encima: la segunda se
               esta resolviendo, la primera no la ha visto nadie. */
            CASE WHEN e.aet_codigo IN ('RESUELTA', 'DESCARTADA') THEN 9
                 WHEN ISNULL(s.sev_id, 1) = 5 AND a.ale_usuario_responsable IS NULL THEN 1
                 WHEN ISNULL(s.sev_id, 1) = 5 THEN 2
                 WHEN ISNULL(s.sev_id, 1) = 4 THEN 3
                 WHEN ISNULL(s.sev_id, 1) = 3 THEN 4
                 ELSE 5 END                    AS ORDEN_PRIORIDAD

    FROM    [dbo].[Alerta] a
    JOIN    [dbo].[Alerta_Tipo] t   ON t.alt_id = a.ale_alerta_tipo
    JOIN    [dbo].[Alerta_Estado] e ON e.aet_id = a.ale_alerta_estado
    LEFT JOIN [dbo].[Permiso] pm    ON pm.prm_id = t.alt_permiso
    LEFT JOIN [dbo].[Severidad] s   ON s.sev_id = a.ale_severidad
    LEFT JOIN [dbo].[Alerta_Lectura] l ON l.alr_alerta = a.ale_id AND l.alr_usuario = @USUARIO
    LEFT JOIN [dbo].[Usuario] ur    ON ur.usu_id = a.ale_usuario_responsable
    LEFT JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = a.ale_cliente_instalacion
    LEFT JOIN [dbo].[Activo] ac     ON ac.act_id = a.ale_activo
    LEFT JOIN [dbo].[Repuesto] rp   ON rp.rep_id = a.ale_repuesto
    LEFT JOIN [dbo].[Bodega] bo     ON bo.bod_id = a.ale_bodega
    LEFT JOIN [dbo].[Activo_Componente] co ON co.aco_id = a.ale_activo_componente
    WHERE   (a.ale_cliente = @CLIENTE
             /* Bloque 363: un aviso dirigido (soporte, campanas) sigue a su
                destinatario en cualquier cliente que tenga abierto. */
             OR a.ale_usuario_destinatario = @USUARIO)
      AND   a.ale_habilitado = 1
      AND   (@SOLO_ABIERTAS = 0 OR e.aet_codigo NOT IN ('RESUELTA', 'DESCARTADA'))
      /* El permiso del TIPO decide quien ve la alerta. Se valida aca y no en
         la pantalla: la app consume el mismo SP. */
      AND   (t.alt_permiso IS NULL
             OR [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, pm.prm_codigo) = 1)

      /* UNA ALERTA DIRIGIDA ES SOLO DE SU DESTINATARIO

         Las alertas que detecta el sistema no tienen destinatario y las ve
         quien tenga el permiso: eso no cambia. Compartir un trabajo, en
         cambio, va dirigido a UNA persona, y sin este filtro el aviso de
         Â«Jonathan te compartio OT-2Â» le apareceria a toda la planta â€”incluido
         quien lo mandoâ€”, que es justo lo contrario de lo que significa. */
      AND   (a.ale_usuario_destinatario IS NULL
             OR a.ale_usuario_destinatario = @USUARIO)
      AND   (@GRUPO IS NULL
             OR (@GRUPO = 'ACTIVAS'   AND e.aet_codigo IN ('NUEVA', 'RECONOCIDA', 'EN GESTION'))
             OR (@GRUPO = 'GESTION'   AND e.aet_codigo = 'EN GESTION')
             OR (@GRUPO = 'RESUELTAS' AND e.aet_codigo IN ('RESUELTA', 'DESCARTADA')))
      AND   (@SEVERIDAD IS NULL OR s.sev_codigo = @SEVERIDAD)
      AND   (@TIPO IS NULL OR t.alt_codigo = @TIPO)
      AND   (@SIN_RESPONSABLE IS NULL
             OR (@SIN_RESPONSABLE = 1 AND a.ale_usuario_responsable IS NULL)
             OR (@SIN_RESPONSABLE = 0 AND a.ale_usuario_responsable IS NOT NULL))
      AND   (@FILTRO IS NULL
             OR a.ale_titulo      LIKE '%' + @FILTRO + '%'
             OR a.ale_descripcion LIKE '%' + @FILTRO + '%'
             OR ac.act_codigo     LIKE '%' + @FILTRO + '%'
             OR ac.act_nombre     LIKE '%' + @FILTRO + '%'
             OR rp.rep_codigo     LIKE '%' + @FILTRO + '%')

    ORDER BY CASE WHEN e.aet_codigo IN ('RESUELTA', 'DESCARTADA') THEN 9
                  WHEN ISNULL(s.sev_id, 1) = 5 AND a.ale_usuario_responsable IS NULL THEN 1
                  WHEN ISNULL(s.sev_id, 1) = 5 THEN 2
                  WHEN ISNULL(s.sev_id, 1) = 4 THEN 3
                  WHEN ISNULL(s.sev_id, 1) = 3 THEN 4
                  ELSE 5 END,
             a.ale_fecha_deteccion_utc DESC,
             a.ale_id DESC

GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ALERTA_RESUMEN]
    @CLIENTE    INT,
    @USUARIO    INT
AS
SET NOCOUNT ON

/* Variable de tabla y no un CTE: un CTE solo alcanza a la sentencia que va
   inmediatamente despues, y aca hacen falta DOS resultados -los indicadores y
   el desglose por menu- sobre el mismo conjunto. Con un CTE el segundo
   SELECT no lo encuentra. */
DECLARE @VISIBLES TABLE (
    ale_id                  INT,
    ale_usuario_responsable INT,
    ale_prediccion          INT,
    aet_codigo              NVARCHAR(100),
    alt_codigo              NVARCHAR(100),
    alt_menu_link           NVARCHAR(800),
    sev_codigo              NVARCHAR(50),
    LEIDA                   BIT)

INSERT INTO @VISIBLES
    SELECT  a.ale_id,
            a.ale_usuario_responsable,
            a.ale_prediccion,
            e.aet_codigo,
            t.alt_codigo,
            t.alt_menu_link,
            ISNULL(s.sev_codigo, 'NORMAL'),
            CASE WHEN l.alr_id IS NULL THEN 0 ELSE 1 END
    FROM    [dbo].[Alerta] a
    JOIN    [dbo].[Alerta_Tipo] t   ON t.alt_id = a.ale_alerta_tipo
    JOIN    [dbo].[Alerta_Estado] e ON e.aet_id = a.ale_alerta_estado
    LEFT JOIN [dbo].[Permiso] pm    ON pm.prm_id = t.alt_permiso
    LEFT JOIN [dbo].[Severidad] s   ON s.sev_id = a.ale_severidad
    LEFT JOIN [dbo].[Alerta_Lectura] l ON l.alr_alerta = a.ale_id AND l.alr_usuario = @USUARIO
    WHERE   (a.ale_cliente = @CLIENTE
             /* Bloque 363: un aviso dirigido (soporte, campanas) sigue a su
                destinatario en cualquier cliente que tenga abierto. */
             OR a.ale_usuario_destinatario = @USUARIO)
      AND   a.ale_habilitado = 1
      AND   (t.alt_permiso IS NULL
             OR [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, pm.prm_codigo) = 1)
      AND   (a.ale_usuario_destinatario IS NULL
             OR a.ale_usuario_destinatario = @USUARIO)

    SELECT
        ABIERTAS      = SUM(CASE WHEN aet_codigo IN ('NUEVA','RECONOCIDA','EN GESTION') THEN 1 ELSE 0 END),
        NO_LEIDAS     = SUM(CASE WHEN aet_codigo IN ('NUEVA','RECONOCIDA','EN GESTION') AND LEIDA = 0 THEN 1 ELSE 0 END),
        CRITICAS      = SUM(CASE WHEN aet_codigo IN ('NUEVA','RECONOCIDA','EN GESTION') AND sev_codigo = 'CRITICA' THEN 1 ELSE 0 END),
        EN_GESTION    = SUM(CASE WHEN aet_codigo = 'EN GESTION' THEN 1 ELSE 0 END),
        SIN_RESPONSABLE = SUM(CASE WHEN aet_codigo IN ('NUEVA','RECONOCIDA','EN GESTION')
                                    AND ale_usuario_responsable IS NULL THEN 1 ELSE 0 END),
        /* Solo las que REALMENTE salieron del modelo: tipo PREDICCION RIESGO
           y con su fila en Prediccion. Contar aca cualquier alerta seria
           atribuirle a SIGMA AI trabajo que no hizo. */
        PREDICCIONES  = SUM(CASE WHEN aet_codigo IN ('NUEVA','RECONOCIDA','EN GESTION')
                                  AND alt_codigo = 'PREDICCION RIESGO'
                                  AND ale_prediccion IS NOT NULL THEN 1 ELSE 0 END)
    FROM @VISIBLES

    /* Segundo resultado: cuantas por pantalla, para el punto del menu
       lateral.

       LOS NOMBRES DE COLUMNA SE CONSERVAN -MENU_LINK y ABIERTAS-. El
       AlertaController los lee asi, y su catch se traga cualquier fallo para
       que un contador no tumbe la cabecera: renombrarlos no habria dado
       error, habria dejado los badges del menu en blanco sin decir nada. */
    SELECT  MENU_LINK = alt_menu_link,
            ABIERTAS  = COUNT(*)
    FROM    @VISIBLES
    WHERE   aet_codigo IN ('NUEVA','RECONOCIDA','EN GESTION')
      AND   alt_menu_link IS NOT NULL
    GROUP BY alt_menu_link

GO

-- ---------- UPD_ALERTA_LEER (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_ALERTA_LEER (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[UPD_ALERTA_LEER]
    @CLIENTE INT,
    @USUARIO INT,
    @ALERTA  INT = NULL
AS
SET NOCOUNT ON

    INSERT INTO [dbo].[Alerta_Lectura] (alr_alerta, alr_usuario, alr_fecha)
    SELECT  a.ale_id, @USUARIO, [dbo].[FNC_AHORA]()
    FROM    [dbo].[Alerta] a
    JOIN    [dbo].[Alerta_Tipo] t   ON t.alt_id = a.ale_alerta_tipo
    JOIN    [dbo].[Alerta_Estado] e ON e.aet_id = a.ale_alerta_estado
    LEFT JOIN [dbo].[Permiso] pm    ON pm.prm_id = t.alt_permiso
    WHERE   (a.ale_cliente = @CLIENTE
             /* Bloque 363: un aviso dirigido (soporte, campanas) sigue a su
                destinatario en cualquier cliente que tenga abierto. */
             OR a.ale_usuario_destinatario = @USUARIO)
      AND   a.ale_habilitado = 1
      AND   (@ALERTA IS NULL OR a.ale_id = @ALERTA)
      AND   e.aet_codigo NOT IN ('RESUELTA', 'DESCARTADA')
      AND   (t.alt_permiso IS NULL
             OR [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, pm.prm_codigo) = 1)
      AND   (a.ale_usuario_destinatario IS NULL
             OR a.ale_usuario_destinatario = @USUARIO)
      /* Sin esto el UNIQUE reventaria al marcar dos veces, y marcar dos veces
         es lo normal: se abre el panel, se cierra y se vuelve a abrir. */
      AND   NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Lectura] l
                         WHERE l.alr_alerta = a.ale_id AND l.alr_usuario = @USUARIO)

    SELECT @@ROWCOUNT AS MARCADAS

GO
