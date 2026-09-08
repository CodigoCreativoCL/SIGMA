USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     LA BANDEJA RESPETA EL DESTINATARIO DE UNA ALERTA DIRIGIDA.
-- =============================================
-- Va DESPUES de BD/182, que agrega `ale_usuario_destinatario`.
--
-- Sin este filtro, el aviso de «Fulano te compartio OT-2» le apareceria a toda
-- la planta, incluido quien lo mando. Las alertas que detecta el sistema no
-- llevan destinatario y siguen resolviendose por permiso, exactamente igual.
-- =============================================
SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_ALERTA]
    @CLIENTE            INT,
    @USUARIO            INT,
    @SOLO_ABIERTAS      BIT = 1,
    @TOPE               INT = 50,
    @GRUPO              VARCHAR(20) = NULL,   /* ACTIVAS � GESTION � RESUELTAS */
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
            ISNULL(bo.bod_nombre, '')          AS BODEGA_NOMBRE,
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

            /* El grupo con el que la pantalla arma sus pesta�as. */
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
    WHERE   a.ale_cliente = @CLIENTE
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
         «Jonathan te compartio OT-2» le apareceria a toda la planta —incluido
         quien lo mando—, que es justo lo contrario de lo que significa. */
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
