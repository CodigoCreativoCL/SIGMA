/* ============================================================================
   477 · Ejecutivos comerciales y aviso de LEAD nuevo por la campana · 17-10-2026
   ----------------------------------------------------------------------------
   · Quién puede ser ejecutivo de un lead: las personas con el perfil «Gerente Comercial» o «Ejecutivo Comercial»
     (con el permiso GESTIONAR LEADS). Antes entraba cualquiera que tuviera el permiso por otro perfil (Root, etc.).
     El combo del Centro Comercial muestra su foto y su perfil.
   · Cuando llega un lead por el formulario web, cada una de esas personas recibe un aviso en la campana
     («Nuevo lead LEAD-0012 · Empresa (País)») que abre la ficha del lead. El aviso es dirigido: la persona lo ve
     aunque tenga abierto otro cliente (SEL_ALERTA ya sigue al destinatario, BD/363).
   · Alerta.ale_lead + tipo de alerta «LEAD NUEVO»; SEL_ALERTA resuelve FICHA_ID con la columna nueva.
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF COL_LENGTH('dbo.Alerta', 'ale_lead') IS NULL
    ALTER TABLE [dbo].[Alerta] ADD ale_lead INT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ALE_LEAD')
    ALTER TABLE [dbo].[Alerta] ADD CONSTRAINT FK_ALE_LEAD FOREIGN KEY (ale_lead) REFERENCES [dbo].[Lead] (lea_id)
GO

/* ---- quiénes son los ejecutivos comerciales ---- */
CREATE OR ALTER FUNCTION [dbo].[FNC_LEAD_EJECUTIVOS] ()
RETURNS TABLE
AS
RETURN
SELECT  u.usu_id AS ID,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))) AS NOMBRE,
        u.usu_correo AS CORREO,
        STUFF((SELECT DISTINCT N' · ' + p2.per_nombre
               FROM [dbo].[Usuario_Perfil] up2 JOIN [dbo].[Perfiles] p2 ON p2.per_id = up2.upe_perfil
               WHERE up2.upe_usuario = u.usu_id AND p2.per_habilitado = 1 AND p2.per_nombre IN (N'Gerente Comercial', N'Ejecutivo Comercial')
               FOR XML PATH(N'')), 1, 3, N'') AS PERFIL,
        ISNULL(u.usu_archivo_foto, 0) AS FOTO_ID
FROM    [dbo].[Usuario] u
WHERE   u.usu_habilitado = 1
  AND   EXISTS (SELECT 1
                FROM [dbo].[Usuario_Perfil] up
                JOIN [dbo].[Perfiles] p ON p.per_id = up.upe_perfil AND p.per_habilitado = 1 AND p.per_nombre IN (N'Gerente Comercial', N'Ejecutivo Comercial')
                JOIN [dbo].[Perfil_Permiso] pp ON pp.ppe_perfil = p.per_id
                JOIN [dbo].[Permiso] pr ON pr.prm_id = pp.ppe_permiso AND pr.prm_codigo = N'GESTIONAR LEADS'
                WHERE up.upe_usuario = u.usu_id)
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_LEAD_EJECUTIVOS]
AS
SET NOCOUNT ON
SELECT ID, NOMBRE, CORREO, ISNULL(PERFIL, N'') AS PERFIL, FOTO_ID FROM [dbo].[FNC_LEAD_EJECUTIVOS]() ORDER BY NOMBRE
GO

/* ---- el tipo de aviso ---- */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'LEAD NUEVO')
    INSERT INTO [dbo].[Alerta_Tipo] (alt_codigo, alt_nombre, alt_orden, alt_habilitado)
    VALUES ('LEAD NUEVO', 'Lead nuevo', (SELECT ISNULL(MAX(alt_orden), 0) + 1 FROM [dbo].[Alerta_Tipo]), 1)
UPDATE [dbo].[Alerta_Tipo]
   SET alt_icono = 'mdi mdi-account-plus-outline', alt_menu_link = '~/View/Comercial/CentroComercial.aspx',
       alt_ficha_link = '~/View/Comercial/CentroComercial.aspx', alt_ficha_id_columna = 'ale_lead'
 WHERE alt_codigo = 'LEAD NUEVO'
GO

/* ---- el aviso: uno por ejecutivo comercial ---- */
CREATE OR ALTER PROCEDURE [dbo].[INS_LEAD_AVISO]
    @LEAD INT
AS
SET NOCOUNT ON
BEGIN TRY
    DECLARE @TIPO INT = (SELECT alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'LEAD NUEVO')
    DECLARE @ESTADO INT = (SELECT aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'NUEVA')
    IF @TIPO IS NULL OR @ESTADO IS NULL RETURN 0
    DECLARE @TITULO NVARCHAR(400), @DESC NVARCHAR(1000)
    SELECT @TITULO = N'Nuevo lead ' + lea_codigo + N' · ' + lea_empresa + CASE WHEN lea_pais IS NULL THEN N'' ELSE N' (' + lea_pais + N')' END,
           @DESC = lea_contacto_nombre + CASE WHEN lea_contacto_cargo IS NULL THEN N'' ELSE N', ' + lea_contacto_cargo END + N' · ' + lea_correo
                   + CASE WHEN lea_telefono IS NULL THEN N'' ELSE N' · ' + lea_telefono END
      FROM [dbo].[Lead] WHERE lea_id = @LEAD
    IF @TITULO IS NULL RETURN 0

    INSERT INTO [dbo].[Alerta] (ale_cliente, ale_alerta_tipo, ale_alerta_estado, ale_titulo, ale_descripcion, ale_usuario_destinatario, ale_lead,
                                ale_usuario_creacion, ale_fecha_primera_ocurrencia_utc, ale_fecha_ultima_ocurrencia_utc)
    SELECT  ISNULL((SELECT TOP 1 cu.ucl_id_cliente FROM [dbo].[Cliente_Usuario] cu WHERE cu.ucl_id_usuario = e.ID AND cu.ucl_habilitado = 1 ORDER BY cu.ucl_id),
                   (SELECT MIN(cli_id) FROM [dbo].[Cliente])),
            @TIPO, @ESTADO, @TITULO, @DESC, e.ID, @LEAD, 1, GETUTCDATE(), GETUTCDATE()
    FROM    [dbo].[FNC_LEAD_EJECUTIVOS]() e
    WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Alerta] a WHERE a.ale_lead = @LEAD AND a.ale_usuario_destinatario = e.ID AND a.ale_alerta_tipo = @TIPO)
END TRY
BEGIN CATCH
    /* un fallo del aviso nunca debe impedir que el lead quede registrado */
    RETURN 0
END CATCH
RETURN 0
GO

/* 382 — El aviso de una campana (formato notificacion) aparece primero en el panel de alertas mientras no se lea y durante 7 dias.

   Antes SEL_ALERTA ordenaba solo por severidad y el aviso (sin severidad) quedaba al final, fuera de lo que muestra la campana. IDEMPOTENTE. */

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
                 WHEN 'ale_lead'           THEN a.ale_lead

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



    ORDER BY CASE WHEN a.ale_campana IS NOT NULL AND e.aet_codigo NOT IN ('RESUELTA', 'DESCARTADA') AND (l.alr_alerta IS NULL OR a.ale_fecha_deteccion_utc >= DATEADD(DAY, -7, GETUTCDATE())) THEN 0 ELSE 1 END,

             CASE WHEN e.aet_codigo IN ('RESUELTA', 'DESCARTADA') THEN 9

                  WHEN ISNULL(s.sev_id, 1) = 5 AND a.ale_usuario_responsable IS NULL THEN 1

                  WHEN ISNULL(s.sev_id, 1) = 5 THEN 2

                  WHEN ISNULL(s.sev_id, 1) = 4 THEN 3

                  WHEN ISNULL(s.sev_id, 1) = 3 THEN 4

                  ELSE 5 END,

             a.ale_fecha_deteccion_utc DESC,

             a.ale_id DESC
GO



CREATE OR ALTER PROCEDURE [dbo].[INS_LEAD_PUBLICO]

@ID             INT = NULL OUTPUT,

@CODIGO         VARCHAR(20) = NULL OUTPUT,

@EMPRESA        NVARCHAR(200),

@CONTACTO       NVARCHAR(200),

@CARGO          NVARCHAR(200) = NULL,

@CORREO         NVARCHAR(200),

@TELEFONO       NVARCHAR(50) = NULL,

@PAIS           NVARCHAR(80) = NULL,

@PAIS_ID        INT = NULL,

@IDENTIFICADOR  NVARCHAR(30) = NULL,

@N_ACTIVOS      NVARCHAR(40) = NULL,

@PLAN_INTERES   NVARCHAR(80) = NULL,

@INTERESES      NVARCHAR(500) = NULL,

@MENSAJE        NVARCHAR(2000) = NULL,

@CONSENTIMIENTO BIT,

@IP             VARCHAR(64) = NULL,

@ORIGEN         VARCHAR(20) = 'FORM_WEB',

@USUARIO        INT = NULL

AS

SET NOCOUNT ON

DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()

DECLARE @TOPE INT = TRY_CAST((SELECT par_valor FROM [dbo].[Sys_Parametros] WHERE par_codigo = 'COMERCIAL_LEADS_POR_IP') AS INT)



IF @ORIGEN = 'FORM_WEB' AND ISNULL(@CONSENTIMIENTO, 0) = 0

BEGIN RAISERROR('1.- DEBES ACEPTAR EL TRATAMIENTO DE TUS DATOS PARA QUE TE CONTACTEMOS.', 16, 1) RETURN -1 END

IF LEN(LTRIM(RTRIM(ISNULL(@EMPRESA, N'')))) < 2 OR LEN(LTRIM(RTRIM(ISNULL(@CONTACTO, N'')))) < 2

BEGIN RAISERROR('2.- INDICA TU NOMBRE Y TU EMPRESA.', 16, 1) RETURN -1 END

IF @CORREO IS NULL OR @CORREO NOT LIKE N'%_@_%._%' OR CHARINDEX(N' ', @CORREO) > 0

BEGIN RAISERROR('3.- EL CORREO NO ES VÁLIDO.', 16, 1) RETURN -1 END

-- País: por id, o por nombre si solo llegó el texto; Chile por defecto. La moneda sale del país.

IF @PAIS_ID IS NULL AND NULLIF(LTRIM(RTRIM(@PAIS)), N'') IS NOT NULL

    SET @PAIS_ID = (SELECT TOP 1 pai_id FROM [dbo].[Paises] WHERE pai_nombre = LTRIM(RTRIM(@PAIS)) AND pai_habilItado = 1)

-- Un país que no está en el catálogo («Otro…») queda sin id: se cotiza en USD y el ejecutivo lo precisa en la ficha.

IF @PAIS_ID IS NULL AND NULLIF(LTRIM(RTRIM(@PAIS)), N'') IS NULL SET @PAIS_ID = 1

IF @PAIS_ID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Paises] WHERE pai_id = @PAIS_ID AND pai_habilItado = 1)

BEGIN RAISERROR('5.- EL PAÍS NO ES VÁLIDO.', 16, 1) RETURN -1 END

SET @IDENTIFICADOR = NULLIF(UPPER(LTRIM(RTRIM(@IDENTIFICADOR))), N'')

IF @PAIS_ID IS NOT NULL AND @IDENTIFICADOR IS NOT NULL AND [dbo].[FNC_IDENTIFICADOR_VALIDO](@PAIS_ID, @IDENTIFICADOR) = 0

BEGIN RAISERROR('6.- EL IDENTIFICADOR TRIBUTARIO NO ES VÁLIDO PARA ESE PAÍS.', 16, 1) RETURN -1 END

IF @PAIS_ID IS NOT NULL SET @PAIS = (SELECT pai_nombre FROM [dbo].[Paises] WHERE pai_id = @PAIS_ID)

IF @ORIGEN = 'FORM_WEB' AND @IP IS NOT NULL AND ISNULL(@TOPE, 5) > 0

   AND (SELECT COUNT(*) FROM [dbo].[Lead] WHERE lea_ip = @IP AND lea_fecha_creacion > DATEADD(HOUR, -1, @AHORA)) >= ISNULL(@TOPE, 5)

BEGIN RAISERROR('4.- RECIBIMOS VARIAS SOLICITUDES DESDE ESTA CONEXIÓN. INTÉNTALO EN UNA HORA O ESCRÍBENOS A COMERCIAL@CODIGOCREATIVO.TECH.', 16, 1) RETURN -1 END



BEGIN TRANSACTION

    INSERT [dbo].[Lead] (lea_empresa, lea_contacto_nombre, lea_contacto_cargo, lea_correo, lea_telefono, lea_pais,

                         lea_pais_id, lea_identificador, lea_rut, lea_moneda, lea_n_activos, lea_plan_interes, lea_intereses, lea_mensaje, lea_origen, lea_consentimiento,

                         lea_consentimiento_fecha, lea_ip, lea_estado, lea_fecha_estado, lea_usuario_creacion, lea_fecha_creacion)

    VALUES (LTRIM(RTRIM(@EMPRESA)), LTRIM(RTRIM(@CONTACTO)), NULLIF(LTRIM(RTRIM(@CARGO)), N''), LOWER(LTRIM(RTRIM(@CORREO))),

            NULLIF(LTRIM(RTRIM(@TELEFONO)), N''), @PAIS,

            @PAIS_ID, @IDENTIFICADOR, CASE WHEN @PAIS_ID = 1 THEN CAST(@IDENTIFICADOR AS VARCHAR(20)) END,

            CASE WHEN @PAIS_ID = 1 THEN 'UF' ELSE 'USD' END, @N_ACTIVOS, @PLAN_INTERES, @INTERESES, @MENSAJE, @ORIGEN,

            ISNULL(@CONSENTIMIENTO, 0), CASE WHEN @CONSENTIMIENTO = 1 THEN @AHORA END, @IP,

            CASE WHEN @ORIGEN = 'MANUAL' THEN 'CONTACTADO' ELSE 'NUEVO' END, @AHORA, @USUARIO, @AHORA)

    SET @ID = SCOPE_IDENTITY()

    SET @CODIGO = 'LEAD-' + RIGHT('0000' + CAST(@ID AS VARCHAR(10)), 4)

    UPDATE [dbo].[Lead] SET lea_codigo = @CODIGO,

                            lea_ejecutivo = CASE WHEN @ORIGEN = 'MANUAL' THEN @USUARIO END

     WHERE lea_id = @ID



    INSERT [dbo].[Lead_Actividad] (lac_lead, lac_tipo, lac_icono, lac_titulo, lac_detalle, lac_usuario, lac_fecha)

    VALUES (@ID, 'SISTEMA', 'web',

            CASE WHEN @ORIGEN = 'MANUAL' THEN N'Lead creado a mano' ELSE N'Lead recibido' END,

            CASE WHEN @ORIGEN = 'MANUAL' THEN N'Registrado desde el Centro Comercial' ELSE N'Formulario web · inicio.aspx' END,

            @USUARIO, @AHORA)

COMMIT TRANSACTION

-- 477: avisa por la campana a los ejecutivos comerciales (el lead creado a mano no avisa: quien lo crea ya lo sabe)
IF @ORIGEN <> 'MANUAL' EXEC [dbo].[INS_LEAD_AVISO] @LEAD = @ID
RETURN 0

GO
PRINT '477_LEAD_EJECUTIVOS_Y_AVISO aplicado.'
GO
