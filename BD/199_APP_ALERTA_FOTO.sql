USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     LA ALERTA TRAE LA FOTO DE LO QUE LE PASA.
-- =============================================
-- LA BANDEJA DE ALERTAS SE VEIA IGUAL PARA TODO
--
--   Diez filas con el mismo icono de campana. Para saber de que equipo habla
--   cada una hay que leerlas, y en una bandeja se mira, no se lee.
--
--   El SP ya devolvia ACTIVO_CODIGO, ACTIVO_NOMBRE y REPUESTO_CODIGO -eso
--   funcionaba- pero AlertaDto no declaraba esas propiedades, y Datos.Listar
--   mapea por nombre y descarta en silencio lo que el DTO no tiene. Asi que la
--   identidad viajaba desde la base y se tiraba en el camino. Se corrige en el
--   DTO; aca se agrega lo que de verdad faltaba: la foto.
--
-- DE DONDE SALE LA FOTO
--
--   De Archivo_Vinculo, igual que API_SEL_ACTIVO_FOTO, y con su misma
--   precaucion: solo imagenes -un PDF de manual no se puede dibujar en una
--   miniatura- y solo del cliente de la alerta.
--
--   El orden importa: primero la marcada como referencia -la portada que
--   eligio alguien-, despues por avi_orden. Si no hay portada, la primera que
--   se subio hace de portada: mejor una foto del equipo que ninguna.
--
-- UN COMPONENTE NO TIENE FOTO PROPIA
--
--   Archivo_Vinculo no tiene columna de componente: no es un olvido de este
--   script, es como esta el modelo. Para una alerta de componente se usa la
--   foto de su ACTIVO PADRE, que es donde esta montado, y la app dice de que
--   componente habla. Mostrar el equipo completo cuando la alerta es de una de
--   sus piezas es correcto: es donde hay que ir a mirar.
--
-- Y SI NO HAY NINGUNA
--
--   Se devuelve NULL y la app pinta el icono del tipo -equipo, repuesto,
--   bodega-. Un marco de imagen vacio se lee como «esto no cargo» y hace dudar
--   del resto de la pantalla; un icono dice lo que hay.
--
-- DE PASO SE REPARA UN DAÑO QUE YA TENIA
--
--   El comentario de @GRUPO decia «ACTIVAS ï¿½ GESTION ï¿½ RESUELTAS»: dos
--   puntos medios que alguien aplico con sqlcmd leyendo ANSI antes de esta
--   sesion. Se comprobo con colacion binaria que el daño esta en la BASE y no
--   en el volcado. Se arregla ahora porque el SP se reescribe igual, y dejarlo
--   seria repetir el error a proposito.
--
-- Se aplica con -f 65001: el SP lleva acentos en sus comentarios.
-- =============================================
SET NOCOUNT ON
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

-- ---------------------------------------------------------------------------
-- Verificacion
-- ---------------------------------------------------------------------------
SELECT CASE WHEN OBJECT_DEFINITION(OBJECT_ID('SEL_ALERTA')) LIKE '%FOTO_RUTA%'
             AND OBJECT_DEFINITION(OBJECT_ID('SEL_ALERTA')) LIKE '%COMPONENTE_NOMBRE%'
            THEN 'SEL_ALERTA devuelve foto e identidad'
            ELSE 'FALTA algo' END AS RESULTADO
GO
