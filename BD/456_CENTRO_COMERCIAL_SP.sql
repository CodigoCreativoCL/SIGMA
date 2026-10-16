/* ============================================================================
   SIGMA — Bloque 456
   CENTRO COMERCIAL · PROCEDIMIENTOS
   ----------------------------------------------------------------------------
   Va después de 455 (modelo). Lo llama WsComercial.asmx; cada método valida
   sesión y permiso antes de llegar aquí, salvo los tres públicos (formulario,
   lectura del contrato por token y firma), que validan aquí lo suyo.

   LECTURAS
     SEL_LEAD_CENTRO            todos los leads con lo que pinta el pipeline
     SEL_LEAD_FICHA             la ficha completa (6 conjuntos)
     SEL_LEAD_EJECUTIVOS        quién puede ser ejecutivo
     SEL_LEAD_DEMO_USO          consumo real de la empresa demo
     SEL_COMERCIAL_CLIENTES     concretados con su suscripción
     SEL_CONTRATO_TOKEN         el contrato detrás de un enlace de firma
     SEL_PROPUESTA_PDF / SEL_CONTRATO_PDF

   ESCRITURAS
     INS_LEAD_PUBLICO, INS_LEAD_ACTIVIDAD, UPD_LEAD_DATOS, UPD_LEAD_EJECUTIVO,
     UPD_LEAD_ESTADO, UPD_LEAD_PROXIMA_ACCION
     INS_LEAD_DEMO, UPD_LEAD_DEMO_EXTENDER, UPD_LEAD_DEMO_CLAVE, UPD_LEAD_DEMO_VENCER
     INS_PROPUESTA, UPD_PROPUESTA_PDF, UPD_PROPUESTA_ENVIADA
     INS_CONTRATO, UPD_CONTRATO_PDF, UPD_CONTRATO_ENVIADO, UPD_CONTRATO_ANULAR,
     UPD_CONTRATO_VISUALIZADO, UPD_CONTRATO_FIRMAR
     INS_REUNION, UPD_REUNION_INVITACION, UPD_REUNION_REGISTRAR
     UPD_USUARIO_CLAVE_OBLIGATORIA, SEL_USUARIO_DEBE_CAMBIAR

   MENSAJES
     Los errores van numerados y en mayúsculas (CONVENCIONES §1.5). El servicio
     les quita el número y la caja alta antes de mostrarlos.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

/* Módulos comerciales → funcionalidades del plan. Una sola fuente para la
   propuesta personalizada y para el plan que nace al firmar. */
CREATE OR ALTER FUNCTION [dbo].[FNC_COMERCIAL_MODULO_FUNCIONALIDAD] ()
RETURNS TABLE
AS
RETURN
    SELECT m.modulo, m.fun_codigo FROM (VALUES
        (N'MANTENIMIENTO', N'GESTION ACTIVOS'), (N'MANTENIMIENTO', N'TAREAS'), (N'MANTENIMIENTO', N'BITACORA'),
        (N'MANTENIMIENTO', N'EVIDENCIA FOTOGRAFICA'), (N'MANTENIMIENTO', N'REGISTRO TERRENO'), (N'MANTENIMIENTO', N'IMPORTACION EXCEL'),
        (N'MANTENIMIENTO', N'CREACION POR VOZ'), (N'MANTENIMIENTO', N'LECTURA POR VOZ'), (N'MANTENIMIENTO', N'INDICADORES AVANZADOS'),
        (N'MANTENIMIENTO', N'API EXTERNA'),
        (N'OT', N'ORDEN TRABAJO'), (N'OT', N'PERMISO TRABAJO'), (N'OT', N'SERVICIOS EXTERNOS'),
        (N'PLANIFICACION', N'PLAN MANTENIMIENTO'), (N'PLANIFICACION', N'PROGRAMACION CALENDARIO'), (N'PLANIFICACION', N'PROGRAMACION MEDIDOR'),
        (N'INSPECCION', N'CHECKLIST DINAMICO'),
        (N'INVENTARIO', N'INVENTARIO REPUESTOS'),
        (N'SIGMA_AI', N'ANALISIS VISUAL'), (N'SIGMA_AI', N'ANALISIS PREDICTIVO'), (N'SIGMA_AI', N'VIDA UTIL RESTANTE'), (N'SIGMA_AI', N'SIGMA AI CHAT'),
        (N'SIGMA_TWIN', N'SIGMA TWIN')
    ) AS m (modulo, fun_codigo)
GO

/* ===================================================================== LEAD */

CREATE OR ALTER PROCEDURE [dbo].[INS_LEAD_ACTIVIDAD]
@ID       INT = NULL OUTPUT,
@LEAD     INT,
@TIPO     VARCHAR(20),
@TITULO   NVARCHAR(200),
@DETALLE  NVARCHAR(2000) = NULL,
@ICONO    VARCHAR(40) = NULL,
@USUARIO  INT = NULL,
@REUNION  INT = NULL
AS
SET NOCOUNT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Lead] WHERE lea_id = @LEAD)
BEGIN RAISERROR('1.- EL LEAD NO EXISTE.', 16, 1) RETURN -1 END
IF LEN(LTRIM(RTRIM(ISNULL(@TITULO, N'')))) = 0
BEGIN RAISERROR('2.- ESCRIBE QUÉ PASÓ.', 16, 1) RETURN -1 END

INSERT [dbo].[Lead_Actividad] (lac_lead, lac_tipo, lac_icono, lac_titulo, lac_detalle, lac_usuario, lac_fecha, lac_reunion)
VALUES (@LEAD, @TIPO, @ICONO, LEFT(@TITULO, 200), @DETALLE, @USUARIO, [dbo].[FNC_AHORA](), @REUNION)
SET @ID = SCOPE_IDENTITY()

-- Una actividad manual cuenta como contacto: un lead NUEVO pasa a CONTACTADO.
IF @USUARIO IS NOT NULL AND @TIPO IN ('LLAMADA', 'EMAIL', 'REUNION')
    UPDATE [dbo].[Lead] SET lea_estado = 'CONTACTADO', lea_fecha_estado = [dbo].[FNC_AHORA]()
     WHERE lea_id = @LEAD AND lea_estado = 'NUEVO'
RETURN 0
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
RETURN 0
GO

/* Todos los leads con lo que el pipeline, el tablero y el resumen necesitan.
   Son decenas o cientos de filas: se filtran en el navegador, que así cuenta
   los chips sin volver a preguntar. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_LEAD_CENTRO]
AS
SET NOCOUNT ON
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

SELECT  L.lea_id                 AS ID,
        L.lea_codigo             AS CODIGO,
        L.lea_empresa            AS EMPRESA,
        L.lea_contacto_nombre    AS CONTACTO,
        L.lea_contacto_cargo     AS CARGO,
        L.lea_correo             AS CORREO,
        L.lea_telefono           AS TELEFONO,
        L.lea_estado             AS ESTADO,
        L.lea_origen             AS ORIGEN,
        L.lea_ejecutivo          AS EJECUTIVO_ID,
        LTRIM(RTRIM(ISNULL(U.usu_nombre, '') + ' ' + ISNULL(U.usu_apellido_paterno, ''))) AS EJECUTIVO,
        L.lea_proxima_accion_tipo  AS PROX_TIPO,
        L.lea_proxima_accion_texto AS PROX_TEXTO,
        CONVERT(VARCHAR(16), L.lea_proxima_accion_fecha, 120) AS PROX_FECHA,
        CONVERT(VARCHAR(16), L.lea_fecha_estado, 120)         AS FECHA_ESTADO,
        CONVERT(VARCHAR(16), L.lea_fecha_creacion, 120)       AS FECHA_CREACION,
        DATEDIFF(DAY, L.lea_fecha_estado, @HOY)               AS DIAS,
        UA.lac_titulo  AS ULT_TITULO,
        CONVERT(VARCHAR(16), UA.lac_fecha, 120) AS ULT_FECHA,
        D.ldm_estado   AS DEMO_ESTADO,
        CONVERT(VARCHAR(10), D.ldm_inicio, 120) AS DEMO_INICIO,
        CONVERT(VARCHAR(10), D.ldm_expira, 120) AS DEMO_EXPIRA,
        CASE WHEN D.ldm_id IS NULL THEN NULL ELSE DATEDIFF(DAY, @HOY, D.ldm_expira) END AS DEMO_DIAS,
        CONVERT(VARCHAR(16), DU.usu_ultimo_acceso, 120) AS DEMO_ULT_ACCESO,
        D.ldm_cliente  AS DEMO_CLIENTE,
        C.ctt_estado   AS CONTRATO_ESTADO,
        C.ctt_version  AS CONTRATO_VERSION,
        CONVERT(VARCHAR(16), C.ctt_enviado_fecha, 120) AS CONTRATO_ENVIADO,
        P.ppt_estado   AS PROPUESTA_ESTADO,
        P.ppt_aperturas AS PROPUESTA_APERTURAS,
        (SELECT COUNT(*) FROM [dbo].[Reunion] R
          WHERE R.reu_lead = L.lea_id AND R.reu_estado = 'AGENDADA'
            AND DATEADD(MINUTE, R.reu_duracion_min, R.reu_fecha_inicio) < [dbo].[FNC_AHORA]()) AS REUNIONES_SIN_REGISTRAR,
        L.lea_motivo_perdida AS MOTIVO_PERDIDA,
        L.lea_pais_id AS PAIS_ID, L.lea_moneda AS MONEDA
FROM    [dbo].[Lead] L
LEFT JOIN [dbo].[Usuario] U ON U.usu_id = L.lea_ejecutivo
LEFT JOIN [dbo].[Lead_Demo] D ON D.ldm_lead = L.lea_id
LEFT JOIN [dbo].[Usuario] DU ON DU.usu_id = D.ldm_usuario_principal
OUTER APPLY (SELECT TOP 1 lac_titulo, lac_fecha FROM [dbo].[Lead_Actividad] A
              WHERE A.lac_lead = L.lea_id ORDER BY A.lac_fecha DESC, A.lac_id DESC) UA
OUTER APPLY (SELECT TOP 1 ctt_estado, ctt_version, ctt_enviado_fecha FROM [dbo].[Contrato] X
              WHERE X.ctt_lead = L.lea_id ORDER BY X.ctt_version DESC) C
OUTER APPLY (SELECT TOP 1 ppt_estado, ppt_aperturas FROM [dbo].[Propuesta] Y
              WHERE Y.ppt_lead = L.lea_id ORDER BY Y.ppt_version DESC) P
WHERE   L.lea_habilitado = 1
ORDER BY CASE WHEN L.lea_proxima_accion_fecha IS NULL THEN 1 ELSE 0 END, L.lea_proxima_accion_fecha, L.lea_fecha_creacion DESC
GO

/* Quién puede ser ejecutivo: quien tenga el permiso de gestionar leads por
   alguno de sus perfiles globales. No se pregunta por el nombre del perfil. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_LEAD_EJECUTIVOS]
AS
SET NOCOUNT ON
SELECT DISTINCT U.usu_id AS ID,
       LTRIM(RTRIM(ISNULL(U.usu_nombre, '') + ' ' + ISNULL(U.usu_apellido_paterno, ''))) AS NOMBRE,
       U.usu_correo AS CORREO
  FROM [dbo].[Usuario] U
  JOIN [dbo].[Usuario_Perfil] UP ON UP.upe_usuario = U.usu_id
  JOIN [dbo].[Perfil_Permiso] PP ON PP.ppe_perfil = UP.upe_perfil
  JOIN [dbo].[Permiso] PR ON PR.prm_id = PP.ppe_permiso AND PR.prm_codigo = 'GESTIONAR LEADS'
 WHERE U.usu_habilitado = 1
 ORDER BY NOMBRE
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_LEAD_FICHA]
@LEAD INT
AS
SET NOCOUNT ON
-- 0 · el lead
SELECT  L.lea_id AS ID, L.lea_codigo AS CODIGO, L.lea_empresa AS EMPRESA, L.lea_rut AS RUT, L.lea_rubro AS RUBRO,
        L.lea_contacto_nombre AS CONTACTO, L.lea_contacto_cargo AS CARGO, L.lea_correo AS CORREO, L.lea_telefono AS TELEFONO,
        L.lea_pais AS PAIS, L.lea_n_activos AS N_ACTIVOS, L.lea_plan_interes AS PLAN_INTERES, L.lea_intereses AS INTERESES,
        L.lea_mensaje AS MENSAJE, L.lea_origen AS ORIGEN, L.lea_estado AS ESTADO, L.lea_motivo_perdida AS MOTIVO_PERDIDA,
        L.lea_ejecutivo AS EJECUTIVO_ID,
        LTRIM(RTRIM(ISNULL(U.usu_nombre, '') + ' ' + ISNULL(U.usu_apellido_paterno, ''))) AS EJECUTIVO,
        U.usu_correo AS EJECUTIVO_CORREO,
        L.lea_proxima_accion_tipo AS PROX_TIPO, L.lea_proxima_accion_texto AS PROX_TEXTO,
        CONVERT(VARCHAR(16), L.lea_proxima_accion_fecha, 120) AS PROX_FECHA,
        CONVERT(VARCHAR(16), L.lea_fecha_creacion, 120) AS FECHA_CREACION,
        CONVERT(VARCHAR(16), L.lea_fecha_estado, 120) AS FECHA_ESTADO,
        L.lea_cliente AS CLIENTE,
        L.lea_pais_id AS PAIS_ID, L.lea_identificador AS IDENTIFICADOR, L.lea_moneda AS MONEDA,
        PA.pai_identificador_nombre AS IDENTIFICADOR_NOMBRE
FROM    [dbo].[Lead] L
LEFT JOIN [dbo].[Paises] PA ON PA.pai_id = L.lea_pais_id
LEFT JOIN [dbo].[Usuario] U ON U.usu_id = L.lea_ejecutivo
WHERE   L.lea_id = @LEAD AND L.lea_habilitado = 1

-- 1 · actividad, la más reciente primero
SELECT  A.lac_id AS ID, A.lac_tipo AS TIPO, A.lac_icono AS ICONO, A.lac_titulo AS TITULO, A.lac_detalle AS DETALLE,
        CONVERT(VARCHAR(16), A.lac_fecha, 120) AS FECHA,
        CASE WHEN A.lac_usuario IS NULL THEN N'Sistema'
             ELSE LTRIM(RTRIM(ISNULL(U.usu_nombre, '') + ' ' + ISNULL(U.usu_apellido_paterno, ''))) END AS QUIEN,
        A.lac_reunion AS REUNION
FROM    [dbo].[Lead_Actividad] A
LEFT JOIN [dbo].[Usuario] U ON U.usu_id = A.lac_usuario
WHERE   A.lac_lead = @LEAD
ORDER BY A.lac_fecha DESC, A.lac_id DESC

-- 2 · demo
SELECT  D.ldm_id AS ID, D.ldm_estado AS ESTADO, CONVERT(VARCHAR(10), D.ldm_inicio, 120) AS INICIO,
        CONVERT(VARCHAR(10), D.ldm_expira, 120) AS EXPIRA, D.ldm_modulos AS MODULOS, D.ldm_cliente AS CLIENTE,
        DU.usu_correo AS USUARIO_CORREO, CONVERT(VARCHAR(16), DU.usu_ultimo_acceso, 120) AS ULT_ACCESO,
        DU.usu_debe_cambiar_clave AS PENDIENTE_CLAVE,
        D.ldm_lim_usuarios AS LIM_USUARIOS, D.ldm_lim_activos AS LIM_ACTIVOS, D.ldm_lim_ot AS LIM_OT,
        D.ldm_lim_programaciones AS LIM_PROGRAMACIONES, D.ldm_lim_checklists AS LIM_CHECKLISTS,
        D.ldm_lim_repuestos AS LIM_REPUESTOS, D.ldm_lim_bodegas AS LIM_BODEGAS, D.ldm_lim_plantas AS LIM_PLANTAS
FROM    [dbo].[Lead_Demo] D
JOIN    [dbo].[Usuario] DU ON DU.usu_id = D.ldm_usuario_principal
WHERE   D.ldm_lead = @LEAD

-- 3 · propuestas (sin el PDF)
SELECT  P.ppt_id AS ID, P.ppt_version AS VERSION, P.ppt_tipo AS TIPO, P.ppt_plan_comercial AS PLAN_COMERCIAL,
        P.ppt_nombre_plan AS NOMBRE_PLAN, P.ppt_modulos AS MODULOS, P.ppt_lim_usuarios AS LIM_USUARIOS,
        P.ppt_lim_activos AS LIM_ACTIVOS, P.ppt_lim_plantas AS LIM_PLANTAS, P.ppt_lim_bodegas AS LIM_BODEGAS,
        P.ppt_lim_almacenamiento_gb AS LIM_GB, P.ppt_implementacion_uf AS IMPLEMENTACION_UF, P.ppt_mensual_uf AS MENSUAL_UF,
        P.ppt_descuento_pct AS DESCUENTO_PCT, P.ppt_vigencia_meses AS VIGENCIA_MESES, P.ppt_total_uf AS TOTAL_UF,
        P.ppt_condiciones AS CONDICIONES, P.ppt_estado AS ESTADO, CONVERT(VARCHAR(16), P.ppt_enviada_fecha, 120) AS ENVIADA,
        P.ppt_aperturas AS APERTURAS, P.ppt_moneda AS MONEDA, CASE WHEN P.ppt_pdf IS NULL THEN 0 ELSE 1 END AS TIENE_PDF,
        CONVERT(VARCHAR(16), P.ppt_fecha_creacion, 120) AS CREADA
FROM    [dbo].[Propuesta] P
WHERE   P.ppt_lead = @LEAD
ORDER BY P.ppt_version DESC

-- 4 · contratos (sin los PDF)
SELECT  C.ctt_id AS ID, C.ctt_version AS VERSION, C.ctt_propuesta AS PROPUESTA, C.ctt_estado AS ESTADO,
        C.ctt_motivo_anulacion AS MOTIVO_ANULACION, C.ctt_pdf_sha256 AS PDF_SHA256,
        CONVERT(VARCHAR(16), C.ctt_token_expira, 120) AS TOKEN_EXPIRA, C.ctt_token_usado AS TOKEN_USADO,
        CONVERT(VARCHAR(16), C.ctt_enviado_fecha, 120) AS ENVIADO, CONVERT(VARCHAR(16), C.ctt_visualizado_fecha, 120) AS VISUALIZADO,
        CONVERT(VARCHAR(16), C.ctt_firmado_fecha, 120) AS FIRMADO, C.ctt_firmante_nombre AS FIRMANTE, C.ctt_firmante_rut AS FIRMANTE_RUT,
        C.ctt_firma_ip AS FIRMA_IP, C.ctt_pdf_firmado_sha256 AS PDF_FIRMADO_SHA256,
        CONVERT(VARCHAR(16), C.ctt_fecha_creacion, 120) AS CREADO
FROM    [dbo].[Contrato] C
WHERE   C.ctt_lead = @LEAD
ORDER BY C.ctt_version DESC

-- 5 · reuniones
SELECT  R.reu_id AS ID, CONVERT(VARCHAR(16), R.reu_fecha_inicio, 120) AS INICIO, R.reu_duracion_min AS DURACION,
        R.reu_lugar AS LUGAR, R.reu_enlace AS ENLACE, R.reu_direccion AS DIRECCION, R.reu_motivo AS MOTIVO,
        R.reu_estado AS ESTADO, R.reu_resumen AS RESUMEN, R.reu_objecion AS OBJECION, R.reu_acuerdos_json AS ACUERDOS,
        R.reu_datos_propuesta_json AS DATOS_PROPUESTA,
        (SELECT COUNT(*) FROM [dbo].[Reunion_Participante] RP WHERE RP.rup_reunion = R.reu_id) AS PARTICIPANTES
FROM    [dbo].[Reunion] R
WHERE   R.reu_lead = @LEAD
ORDER BY R.reu_fecha_inicio DESC
GO

/* Lo que el ejecutivo completa a mano en «Información». El RUT de la empresa
   es obligatorio antes del contrato: con él nace el cliente al firmar. */
CREATE OR ALTER PROCEDURE [dbo].[UPD_LEAD_DATOS]
@LEAD       INT,
@EMPRESA    NVARCHAR(200),
@RUT        VARCHAR(20) = NULL,
@PAIS_ID        INT = NULL,
@IDENTIFICADOR  NVARCHAR(30) = NULL,
@RUBRO      NVARCHAR(200) = NULL,
@CONTACTO   NVARCHAR(200),
@CARGO      NVARCHAR(200) = NULL,
@CORREO     NVARCHAR(200),
@TELEFONO   NVARCHAR(50) = NULL,
@INTERESES  NVARCHAR(500) = NULL,
@USUARIO    INT
AS
SET NOCOUNT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Lead] WHERE lea_id = @LEAD AND lea_habilitado = 1)
BEGIN RAISERROR('1.- EL LEAD NO EXISTE.', 16, 1) RETURN -1 END
IF EXISTS (SELECT 1 FROM [dbo].[Lead] WHERE lea_id = @LEAD AND lea_estado = 'CONCRETADO')
BEGIN RAISERROR('2.- EL LEAD YA ES CLIENTE: SUS DATOS SE EDITAN EN LA FICHA DEL CLIENTE.', 16, 1) RETURN -1 END
-- @RUT sigue valiendo para quien lo mande (Chile); @IDENTIFICADOR es el identificador según el país.
DECLARE @PAIS_ACTUAL INT = (SELECT ISNULL(lea_pais_id, 1) FROM [dbo].[Lead] WHERE lea_id = @LEAD)
SET @PAIS_ID = ISNULL(@PAIS_ID, @PAIS_ACTUAL)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Paises] WHERE pai_id = @PAIS_ID AND pai_habilItado = 1)
BEGIN RAISERROR('5.- EL PAÍS NO ES VÁLIDO.', 16, 1) RETURN -1 END
IF @PAIS_ID <> @PAIS_ACTUAL AND EXISTS (SELECT 1 FROM [dbo].[Propuesta] WHERE ppt_lead = @LEAD)
BEGIN RAISERROR('6.- EL PAÍS NO SE PUEDE CAMBIAR: LA PROPUESTA YA SE COTIZÓ EN LA MONEDA DEL PAÍS ANTERIOR.', 16, 1) RETURN -1 END
SET @IDENTIFICADOR = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@IDENTIFICADOR, @RUT)))), N'')
IF @IDENTIFICADOR IS NOT NULL AND [dbo].[FNC_IDENTIFICADOR_VALIDO](@PAIS_ID, @IDENTIFICADOR) = 0
BEGIN RAISERROR('3.- EL IDENTIFICADOR TRIBUTARIO DE LA EMPRESA NO ES VÁLIDO PARA ESE PAÍS.', 16, 1) RETURN -1 END
IF @CORREO IS NULL OR @CORREO NOT LIKE N'%_@_%._%'
BEGIN RAISERROR('4.- EL CORREO NO ES VÁLIDO.', 16, 1) RETURN -1 END

UPDATE [dbo].[Lead]
   SET lea_empresa = LTRIM(RTRIM(@EMPRESA)),
       lea_rut = CASE WHEN @PAIS_ID = 1 THEN CAST(@IDENTIFICADOR AS VARCHAR(20)) END,
       lea_pais_id = @PAIS_ID, lea_identificador = @IDENTIFICADOR,
       lea_pais = (SELECT pai_nombre FROM [dbo].[Paises] WHERE pai_id = @PAIS_ID),
       lea_moneda = CASE WHEN @PAIS_ID = 1 THEN 'UF' ELSE 'USD' END,
       lea_rubro = NULLIF(LTRIM(RTRIM(@RUBRO)), N''), lea_contacto_nombre = LTRIM(RTRIM(@CONTACTO)),
       lea_contacto_cargo = NULLIF(LTRIM(RTRIM(@CARGO)), N''), lea_correo = LOWER(LTRIM(RTRIM(@CORREO))),
       lea_telefono = NULLIF(LTRIM(RTRIM(@TELEFONO)), N''), lea_intereses = @INTERESES,
       lea_usuario_actualizacion = @USUARIO, lea_fecha_actualizacion = [dbo].[FNC_AHORA]()
 WHERE lea_id = @LEAD
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_LEAD_EJECUTIVO]
@LEAD INT, @EJECUTIVO INT, @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @NOMBRE NVARCHAR(200)
SELECT @NOMBRE = LTRIM(RTRIM(ISNULL(usu_nombre, '') + ' ' + ISNULL(usu_apellido_paterno, ''))) FROM [dbo].[Usuario] WHERE usu_id = @EJECUTIVO AND usu_habilitado = 1
IF @NOMBRE IS NULL BEGIN RAISERROR('1.- LA PERSONA ELEGIDA NO EXISTE O ESTÁ DESHABILITADA.', 16, 1) RETURN -1 END
IF NOT EXISTS (SELECT 1 FROM [dbo].[Lead] WHERE lea_id = @LEAD AND lea_habilitado = 1)
BEGIN RAISERROR('2.- EL LEAD NO EXISTE.', 16, 1) RETURN -1 END

UPDATE [dbo].[Lead] SET lea_ejecutivo = @EJECUTIVO, lea_usuario_actualizacion = @USUARIO, lea_fecha_actualizacion = [dbo].[FNC_AHORA]()
 WHERE lea_id = @LEAD
EXEC [dbo].[INS_LEAD_ACTIVIDAD] @LEAD = @LEAD, @TIPO = 'SISTEMA', @ICONO = 'person', @TITULO = N'Ejecutivo asignado', @DETALLE = @NOMBRE, @USUARIO = @USUARIO
RETURN 0
GO

/* Cambio de estado a mano (CONTACTADO, CALIFICADO, NEGOCIACION, PERDIDO o
   volver a abrir). Los estados que nacen de una acción (DEMO, PROPUESTA,
   CONTRATO, CONCRETADO) los ponen esas acciones, no este SP. */
CREATE OR ALTER PROCEDURE [dbo].[UPD_LEAD_ESTADO]
@LEAD INT, @ESTADO VARCHAR(20), @MOTIVO NVARCHAR(200) = NULL, @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @ACTUAL VARCHAR(20)
SELECT @ACTUAL = lea_estado FROM [dbo].[Lead] WHERE lea_id = @LEAD AND lea_habilitado = 1
IF @ACTUAL IS NULL BEGIN RAISERROR('1.- EL LEAD NO EXISTE.', 16, 1) RETURN -1 END
IF @ACTUAL = 'CONCRETADO' BEGIN RAISERROR('2.- EL LEAD YA ES CLIENTE.', 16, 1) RETURN -1 END
IF @ESTADO NOT IN ('NUEVO', 'CONTACTADO', 'CALIFICADO', 'NEGOCIACION', 'PERDIDO')
BEGIN RAISERROR('3.- ESE ESTADO LO PONE SU PROPIA ACCIÓN (CREAR DEMO, PROPUESTA O CONTRATO).', 16, 1) RETURN -1 END
IF @ESTADO = 'PERDIDO' AND LEN(LTRIM(RTRIM(ISNULL(@MOTIVO, N'')))) = 0
BEGIN RAISERROR('4.- INDICA POR QUÉ SE PIERDE EL LEAD.', 16, 1) RETURN -1 END
IF @ESTADO = 'NEGOCIACION' AND NOT EXISTS (SELECT 1 FROM [dbo].[Propuesta] WHERE ppt_lead = @LEAD AND ppt_estado = 'ENVIADA')
BEGIN RAISERROR('5.- PARA NEGOCIAR, PRIMERO ENVÍA UNA PROPUESTA.', 16, 1) RETURN -1 END

UPDATE [dbo].[Lead]
   SET lea_estado = @ESTADO, lea_fecha_estado = [dbo].[FNC_AHORA](),
       lea_motivo_perdida = CASE WHEN @ESTADO = 'PERDIDO' THEN @MOTIVO ELSE NULL END,
       lea_proxima_accion_tipo = CASE WHEN @ESTADO = 'PERDIDO' THEN NULL ELSE lea_proxima_accion_tipo END,
       lea_proxima_accion_texto = CASE WHEN @ESTADO = 'PERDIDO' THEN NULL ELSE lea_proxima_accion_texto END,
       lea_proxima_accion_fecha = CASE WHEN @ESTADO = 'PERDIDO' THEN NULL ELSE lea_proxima_accion_fecha END,
       lea_usuario_actualizacion = @USUARIO, lea_fecha_actualizacion = [dbo].[FNC_AHORA]()
 WHERE lea_id = @LEAD

DECLARE @T NVARCHAR(200) = CASE @ESTADO WHEN 'PERDIDO' THEN N'Marcado perdido' WHEN 'NEGOCIACION' THEN N'En negociación'
                                        WHEN 'CALIFICADO' THEN N'Lead calificado' WHEN 'CONTACTADO' THEN N'Lead contactado'
                                        ELSE N'Lead reabierto' END
DECLARE @D NVARCHAR(2000) = CASE WHEN @ESTADO = 'PERDIDO' THEN N'Motivo: ' + @MOTIVO ELSE N'Antes: ' + @ACTUAL END
EXEC [dbo].[INS_LEAD_ACTIVIDAD] @LEAD = @LEAD, @TIPO = 'SISTEMA', @ICONO = 'flag', @TITULO = @T, @DETALLE = @D, @USUARIO = @USUARIO
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_LEAD_PROXIMA_ACCION]
@LEAD INT, @TIPO VARCHAR(20) = NULL, @TEXTO NVARCHAR(200) = NULL, @FECHA DATETIME = NULL, @USUARIO INT
AS
SET NOCOUNT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Lead] WHERE lea_id = @LEAD AND lea_habilitado = 1)
BEGIN RAISERROR('1.- EL LEAD NO EXISTE.', 16, 1) RETURN -1 END
IF @FECHA IS NOT NULL AND LEN(LTRIM(RTRIM(ISNULL(@TEXTO, N'')))) = 0
BEGIN RAISERROR('2.- ESCRIBE CUÁL ES LA PRÓXIMA ACCIÓN.', 16, 1) RETURN -1 END
UPDATE [dbo].[Lead]
   SET lea_proxima_accion_tipo = @TIPO, lea_proxima_accion_texto = NULLIF(LTRIM(RTRIM(@TEXTO)), N''),
       lea_proxima_accion_fecha = @FECHA, lea_usuario_actualizacion = @USUARIO, lea_fecha_actualizacion = [dbo].[FNC_AHORA]()
 WHERE lea_id = @LEAD
RETURN 0
GO

/* ===================================================================== DEMO */

/* Crea la demo en UNA transacción: empresa, planta, bodega, usuario principal
   con clave temporal, suscripción al plan DEMO que vence con la demo, y los
   topes del cliente. Si algo falla, no queda nada a medias.

   EL CLIENTE DEMO ES EL FUTURO CLIENTE
     Al firmar no se crea otro: este mismo cambia de identificador, de plan y
     de fecha de término. Lo que el prospecto cargó en la demo se conserva. */
CREATE OR ALTER PROCEDURE [dbo].[INS_LEAD_DEMO]
@ID                 INT = NULL OUTPUT,
@CLIENTE            INT = NULL OUTPUT,
@USUARIO_DEMO       INT = NULL OUTPUT,
@LEAD               INT,
@DIAS               INT,
@MODULOS            NVARCHAR(500),
@LIM_USUARIOS       INT, @LIM_ACTIVOS INT, @LIM_OT INT, @LIM_PROGRAMACIONES INT,
@LIM_CHECKLISTS     INT, @LIM_REPUESTOS INT, @LIM_BODEGAS INT, @LIM_PLANTAS INT,
@CLAVE_TEMPORAL     VARCHAR(100),
@KEY_TEXTO          VARCHAR(200),
@USUARIO            INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA](), @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
DECLARE @EMPRESA NVARCHAR(200), @CODIGO VARCHAR(20), @CONTACTO NVARCHAR(200), @CORREO NVARCHAR(200), @TEL NVARCHAR(50), @ESTADO VARCHAR(20)
SELECT @EMPRESA = lea_empresa, @CODIGO = lea_codigo, @CONTACTO = lea_contacto_nombre, @CORREO = lea_correo,
       @TEL = lea_telefono, @ESTADO = lea_estado
  FROM [dbo].[Lead] WHERE lea_id = @LEAD AND lea_habilitado = 1

IF @EMPRESA IS NULL BEGIN RAISERROR('1.- EL LEAD NO EXISTE.', 16, 1) RETURN -1 END
IF @ESTADO IN ('CONCRETADO', 'PERDIDO') BEGIN RAISERROR('2.- ESTE LEAD ESTÁ CERRADO: REÁBRELO ANTES DE CREAR UNA DEMO.', 16, 1) RETURN -1 END
IF EXISTS (SELECT 1 FROM [dbo].[Lead_Demo] WHERE ldm_lead = @LEAD)
BEGIN RAISERROR('3.- ESTE LEAD YA TIENE UNA DEMO. PUEDES EXTENDERLA O REENVIAR LAS CREDENCIALES.', 16, 1) RETURN -1 END
IF ISNULL(@DIAS, 0) NOT BETWEEN 1 AND 30 BEGIN RAISERROR('4.- LA DEMO DURA ENTRE 1 Y 30 DÍAS.', 16, 1) RETURN -1 END
IF EXISTS (SELECT 1 FROM [dbo].[Usuario] WHERE usu_login = @CORREO OR usu_correo = @CORREO)
BEGIN RAISERROR('5.- YA EXISTE UNA CUENTA SIGMA CON EL CORREO DEL CONTACTO. CAMBIA EL CORREO EN «INFORMACIÓN» O USA ESA CUENTA.', 16, 1) RETURN -1 END
IF @LIM_USUARIOS < 1 OR @LIM_PLANTAS < 1 OR @LIM_BODEGAS < 1 OR @LIM_ACTIVOS < 1
BEGIN RAISERROR('6.- LOS LÍMITES DE USUARIOS, PLANTAS, BODEGAS Y ACTIVOS DEBEN SER AL MENOS 1.', 16, 1) RETURN -1 END

DECLARE @PLAN_DEMO INT = (SELECT plc_id FROM [dbo].[Plan_Comercial] WHERE plc_codigo = N'DEMO' AND plc_habilitado = 1)
IF @PLAN_DEMO IS NULL BEGIN RAISERROR('7.- FALTA EL PLAN DEMO (BLOQUE 455).', 16, 1) RETURN -1 END

DECLARE @EXPIRA DATE = DATEADD(DAY, @DIAS, @HOY)
DECLARE @SALT VARCHAR(50) = REPLACE(CONVERT(VARCHAR(50), NEWID()), '-', '')
DECLARE @PARTES TABLE (i INT IDENTITY(1,1), p NVARCHAR(200))
INSERT @PARTES (p) SELECT value FROM STRING_SPLIT(LTRIM(RTRIM(@CONTACTO)), N' ') WHERE value <> N''
DECLARE @NOMBRE NVARCHAR(200) = (SELECT p FROM @PARTES WHERE i = 1)
DECLARE @APELLIDO NVARCHAR(200) = ISNULL((SELECT STRING_AGG(p, N' ') WITHIN GROUP (ORDER BY i) FROM @PARTES WHERE i > 1), N'')
DECLARE @CUP INT, @UCL INT, @PLANTA INT, @SUS INT

BEGIN TRY
BEGIN TRANSACTION
    /* La empresa demo. El identificador es el código del lead: el RUT real
       llega con el contrato, y nunca choca con un cliente de verdad. */
    INSERT [dbo].[Cliente] (cli_nombre, cli_habilitado, cli_pais, cli_razon_social, cli_identificador, cli_nombre_fantasia,
                            cli_usuario_creacion, cli_fecha_creacion, cli_usuario_actualizacion, cli_fecha_actualizacion)
    VALUES (LEFT(@EMPRESA, 200), 1, 1, LEFT(@EMPRESA, 200), 'DEMO-' + @CODIGO, LEFT(N'Demo · ' + @EMPRESA, 200),
            @USUARIO, @AHORA, @USUARIO, @AHORA)
    SET @CLIENTE = SCOPE_IDENTITY()

    -- Quien crea la demo queda afiliado (puede «Entrar a la demo»), como en INS_CLIENTE.
    INSERT [dbo].[Cliente_Usuario] (ucl_id_usuario, ucl_id_cliente, ucl_habilitado, ucl_usuario_creacion, ucl_fecha_creacion, ucl_usuario_act, ucl_fecha_act)
    VALUES (@USUARIO, @CLIENTE, 1, @USUARIO, @AHORA, @USUARIO, @AHORA)

    -- Suscripción al plan DEMO que vence con la demo: el bloqueo de acceso ya existente (SEL_LOGIN, SuscripcionAcceso) hace el resto.
    EXEC [dbo].[INS_SUSCRIPCION] @ID = @SUS OUTPUT, @CLIENTE = @CLIENTE, @PLAN_COMERCIAL = @PLAN_DEMO, @KEY_PREFIJO = N'DEMO',
         @KEY_TEXTO = @KEY_TEXTO, @CONTACTO_NOMBRE = @CONTACTO, @CONTACTO_EMAIL = @CORREO, @CONTACTO_TELEFONO = @TEL,
         @OBSERVACION = N'Demo creada desde el Centro Comercial', @USUARIO = @USUARIO
    IF @SUS IS NULL RAISERROR('8.- NO FUE POSIBLE CREAR LA SUSCRIPCIÓN DE LA DEMO.', 16, 1)
    UPDATE [dbo].[Suscripcion] SET sus_fecha_fin = @EXPIRA, sus_dias_gracia = 0 WHERE sus_id = @SUS

    -- Los topes de ESTA demo (ganan sobre los del plan DEMO).
    INSERT [dbo].[Plan_Comercial_Funcionalidad] (pcf_plan_comercial, pcf_funcionalidad, pcf_cliente, pcf_funcionalidad_tipo, pcf_incluida,
                                                 pcf_limite, pcf_observacion, pcf_usuario_creacion, pcf_fecha_creacion, pcf_habilitado)
    SELECT @PLAN_DEMO, p.pcf_funcionalidad, @CLIENTE, p.pcf_funcionalidad_tipo, 1,
           CASE f.fun_codigo WHEN N'LIMITE USUARIOS' THEN @LIM_USUARIOS + 1   -- +1: quien vende también está afiliado
                             WHEN N'LIMITE ACTIVOS' THEN @LIM_ACTIVOS WHEN N'LIMITE PLANTAS' THEN @LIM_PLANTAS END,
           N'Límite de la demo ' + @CODIGO, @USUARIO, @AHORA, 1
      FROM [dbo].[Plan_Comercial_Funcionalidad] p
      JOIN [dbo].[Funcionalidad] f ON f.fun_id = p.pcf_funcionalidad
     WHERE p.pcf_plan_comercial = @PLAN_DEMO AND p.pcf_cliente IS NULL AND p.pcf_habilitado = 1
       AND f.fun_codigo IN (N'LIMITE USUARIOS', N'LIMITE ACTIVOS', N'LIMITE PLANTAS')

    INSERT [dbo].[Cliente_Instalacion] (cin_cliente, cin_nombre, cin_descripcion, cin_codigo, cin_habilitado,
                                        cin_usuario_creacion, cin_fecha_creacion, cin_usuario_actualizacion, cin_fecha_actualizacion)
    VALUES (@CLIENTE, 'Planta principal', 'Creada con la demo', N'PL-1', 1, @USUARIO, @AHORA, @USUARIO, @AHORA)
    SET @PLANTA = SCOPE_IDENTITY()

    INSERT [dbo].[Bodega] (bod_cliente, bod_cliente_instalacion, bod_codigo, bod_nombre, bod_descripcion,
                           bod_usuario_creacion, bod_fecha_creacion, bod_usuario_actualizacion, bod_fecha_actualizacion, bod_habilitado)
    VALUES (@CLIENTE, @PLANTA, N'BOD-1', N'Bodega principal', N'Creada con la demo', @USUARIO, @AHORA, @USUARIO, @AHORA, 1)

    -- El usuario principal: administra su empresa demo y debe cambiar la clave al entrar.
    INSERT [dbo].[Usuario] (usu_identificador, usu_login, usu_password, usu_password_salt, usu_nombre, usu_apellido_paterno,
                            usu_apellido_materno, usu_telefono, usu_correo, usu_usuario_creacion, usu_fecha_creacion,
                            usu_usuario_act, usu_fecha_act, usu_habilitado, usu_intentos_fallidos, usu_debe_cambiar_clave)
    VALUES ('DEMO-' + @CODIGO, @CORREO, [dbo].[FNC_PASSWORD_HASH](@CLAVE_TEMPORAL, @SALT), @SALT, LEFT(ISNULL(@NOMBRE, @CONTACTO), 500),
            LEFT(@APELLIDO, 500), '', @TEL, @CORREO, @USUARIO, @AHORA, @USUARIO, @AHORA, 1, 0, 1)
    SET @USUARIO_DEMO = SCOPE_IDENTITY()

    INSERT [dbo].[Usuario_Password_Historial] (uph_usuario, uph_password, uph_usuario_creacion, uph_fecha_creacion)
    VALUES (@USUARIO_DEMO, [dbo].[FNC_PASSWORD_HASH](@CLAVE_TEMPORAL, @SALT), @USUARIO, @AHORA)

    INSERT [dbo].[Usuario_Paises] (upa_id_usuario, upa_id_pais, upa_usuario_creacion, upa_fecha_creacion, upa_usuario_act, upa_fecha_act)
    VALUES (@USUARIO_DEMO, 1, @USUARIO, @AHORA, @USUARIO, @AHORA)

    DECLARE @PERFIL_ADMIN INT = (SELECT TOP 1 per_id FROM [dbo].[Perfiles] WHERE per_nombre = 'Administrador del Cliente' AND per_cliente IS NULL AND per_habilitado = 1)
    IF @PERFIL_ADMIN IS NULL RAISERROR('9.- FALTA EL PERFIL «ADMINISTRADOR DEL CLIENTE».', 16, 1)
    INSERT [dbo].[Usuario_Perfil] (upe_usuario, upe_perfil) VALUES (@USUARIO_DEMO, @PERFIL_ADMIN)

    INSERT [dbo].[Cliente_Usuario] (ucl_id_usuario, ucl_id_cliente, ucl_habilitado, ucl_usuario_creacion, ucl_fecha_creacion, ucl_usuario_act, ucl_fecha_act)
    VALUES (@USUARIO_DEMO, @CLIENTE, 1, @USUARIO, @AHORA, @USUARIO, @AHORA)
    SET @UCL = SCOPE_IDENTITY()
    INSERT [dbo].[Cliente_Usuario_Perfil] (cup_id_cliente_usuario, cup_id_perfil, cup_usuario_creacion, cup_fecha_creacion)
    VALUES (@UCL, @PERFIL_ADMIN, @USUARIO, @AHORA)

    INSERT [dbo].[Lead_Demo] (ldm_lead, ldm_cliente, ldm_usuario_principal, ldm_inicio, ldm_expira, ldm_estado, ldm_modulos,
                              ldm_lim_usuarios, ldm_lim_activos, ldm_lim_ot, ldm_lim_programaciones, ldm_lim_checklists,
                              ldm_lim_repuestos, ldm_lim_bodegas, ldm_lim_plantas, ldm_usuario_creacion, ldm_fecha_creacion)
    VALUES (@LEAD, @CLIENTE, @USUARIO_DEMO, @HOY, @EXPIRA, 'ACTIVA', @MODULOS,
            @LIM_USUARIOS, @LIM_ACTIVOS, @LIM_OT, @LIM_PROGRAMACIONES, @LIM_CHECKLISTS, @LIM_REPUESTOS, @LIM_BODEGAS, @LIM_PLANTAS,
            @USUARIO, @AHORA)
    SET @ID = SCOPE_IDENTITY()

    UPDATE [dbo].[Lead] SET lea_estado = 'DEMO', lea_fecha_estado = @AHORA,
                            lea_ejecutivo = ISNULL(lea_ejecutivo, @USUARIO),
                            lea_usuario_actualizacion = @USUARIO, lea_fecha_actualizacion = @AHORA
     WHERE lea_id = @LEAD

    DECLARE @DET NVARCHAR(2000) = CAST(@DIAS AS NVARCHAR(5)) + N' días · vence el ' + CONVERT(NVARCHAR(10), @EXPIRA, 103) + N' · credenciales para ' + @CORREO
    EXEC [dbo].[INS_LEAD_ACTIVIDAD] @LEAD = @LEAD, @TIPO = 'SISTEMA', @ICONO = 'rocket', @TITULO = N'Demo creada', @DETALLE = @DET, @USUARIO = @USUARIO
COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @ERR NVARCHAR(2000) = ERROR_MESSAGE()
    RAISERROR(@ERR, 16, 1)
    RETURN -1
END CATCH
RETURN 0
GO

/* Consumo real de la empresa demo frente a sus límites. Se cuenta lo
   habilitado, como FNC_CLIENTE_CONSUMO. Los usuarios excluyen a quien vende. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_LEAD_DEMO_USO]
@LEAD INT
AS
SET NOCOUNT ON
DECLARE @C INT = (SELECT ldm_cliente FROM [dbo].[Lead_Demo] WHERE ldm_lead = @LEAD)
IF @C IS NULL RETURN 0
SELECT
  (SELECT COUNT(*) FROM [dbo].[Cliente_Usuario] CU WHERE CU.ucl_id_cliente = @C AND CU.ucl_habilitado = 1
      AND NOT EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil] UP JOIN [dbo].[Perfiles] P ON P.per_id = UP.upe_perfil
                       WHERE UP.upe_usuario = CU.ucl_id_usuario AND P.per_tipo = 1))          AS USUARIOS,
  (SELECT COUNT(*) FROM [dbo].[Activo] WHERE act_cliente = @C AND act_habilitado = 1)          AS ACTIVOS,
  (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @C AND otr_habilitado = 1)   AS OT,
  (SELECT COUNT(*) FROM [dbo].[Programacion] WHERE pro_cliente = @C AND pro_habilitado = 1)    AS PROGRAMACIONES,
  (SELECT COUNT(*) FROM [dbo].[Checklist_Ejecucion] WHERE cej_cliente = @C AND cej_habilitado = 1) AS CHECKLISTS,
  (SELECT COUNT(*) FROM [dbo].[Repuesto] WHERE rep_cliente = @C AND rep_habilitado = 1)        AS REPUESTOS,
  (SELECT COUNT(*) FROM [dbo].[Bodega] WHERE bod_cliente = @C AND bod_habilitado = 1)          AS BODEGAS,
  (SELECT COUNT(*) FROM [dbo].[Cliente_Instalacion] WHERE cin_cliente = @C AND cin_habilitado = 1) AS PLANTAS,
  CONVERT(VARCHAR(16), (SELECT MAX(act_fecha_creacion) FROM [dbo].[Activo] WHERE act_cliente = @C), 120)        AS ULT_ACTIVO,
  CONVERT(VARCHAR(16), (SELECT MAX(otr_fecha_creacion) FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @C), 120) AS ULT_OT,
  CONVERT(VARCHAR(16), (SELECT MAX(cej_fecha_creacion) FROM [dbo].[Checklist_Ejecucion] WHERE cej_cliente = @C), 120) AS ULT_CHECKLIST
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_LEAD_DEMO_EXTENDER]
@LEAD INT, @DIAS INT, @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @EXP DATE, @C INT, @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE), @NUEVA DATE
SELECT @EXP = ldm_expira, @C = ldm_cliente FROM [dbo].[Lead_Demo] WHERE ldm_lead = @LEAD AND ldm_estado <> 'FINALIZADA'
IF @C IS NULL BEGIN RAISERROR('1.- ESTE LEAD NO TIENE UNA DEMO VIGENTE QUE EXTENDER.', 16, 1) RETURN -1 END
IF ISNULL(@DIAS, 0) NOT BETWEEN 1 AND 30 BEGIN RAISERROR('2.- SE EXTIENDE ENTRE 1 Y 30 DÍAS.', 16, 1) RETURN -1 END
-- Una demo vencida se extiende desde hoy, no desde la fecha en que venció.
SET @NUEVA = DATEADD(DAY, @DIAS, CASE WHEN @EXP < @HOY THEN @HOY ELSE @EXP END)

BEGIN TRANSACTION
    UPDATE [dbo].[Lead_Demo] SET ldm_expira = @NUEVA, ldm_estado = 'EXTENDIDA', ldm_usuario_actualizacion = @USUARIO,
                                 ldm_fecha_actualizacion = [dbo].[FNC_AHORA]() WHERE ldm_lead = @LEAD
    UPDATE [dbo].[Suscripcion] SET sus_fecha_fin = @NUEVA, sus_suscripcion_estado = 1, sus_usuario_actualizacion = @USUARIO,
                                   sus_fecha_actualizacion = [dbo].[FNC_AHORA]() WHERE sus_cliente = @C
    UPDATE [dbo].[Cliente_Usuario] SET ucl_habilitado = 1, ucl_usuario_act = @USUARIO, ucl_fecha_act = [dbo].[FNC_AHORA]()
     WHERE ucl_id_cliente = @C AND ucl_habilitado = 0
    DECLARE @DET NVARCHAR(200) = N'+' + CAST(@DIAS AS NVARCHAR(5)) + N' días · ahora vence el ' + CONVERT(NVARCHAR(10), @NUEVA, 103)
    EXEC [dbo].[INS_LEAD_ACTIVIDAD] @LEAD = @LEAD, @TIPO = 'SISTEMA', @ICONO = 'clock', @TITULO = N'Demo extendida', @DETALLE = @DET, @USUARIO = @USUARIO
COMMIT TRANSACTION
RETURN 0
GO

/* Reenviar credenciales = nueva clave temporal. La anterior no se puede
   reenviar porque nunca se guardó en claro. */
CREATE OR ALTER PROCEDURE [dbo].[UPD_LEAD_DEMO_CLAVE]
@LEAD INT, @CLAVE_TEMPORAL VARCHAR(100), @USUARIO INT, @CORREO NVARCHAR(200) = NULL OUTPUT
AS
SET NOCOUNT ON
DECLARE @U INT, @SALT VARCHAR(50)
SELECT @U = D.ldm_usuario_principal, @CORREO = US.usu_correo, @SALT = US.usu_password_salt
  FROM [dbo].[Lead_Demo] D JOIN [dbo].[Usuario] US ON US.usu_id = D.ldm_usuario_principal
 WHERE D.ldm_lead = @LEAD
IF @U IS NULL BEGIN RAISERROR('1.- ESTE LEAD NO TIENE DEMO.', 16, 1) RETURN -1 END
IF @SALT IS NULL SET @SALT = REPLACE(CONVERT(VARCHAR(50), NEWID()), '-', '')
BEGIN TRANSACTION
    UPDATE [dbo].[Usuario] SET usu_password = [dbo].[FNC_PASSWORD_HASH](@CLAVE_TEMPORAL, @SALT), usu_password_salt = @SALT,
                               usu_debe_cambiar_clave = 1, usu_intentos_fallidos = 0, usu_bloqueado_hasta = NULL,
                               usu_usuario_act = @USUARIO, usu_fecha_act = [dbo].[FNC_AHORA]()
     WHERE usu_id = @U
    INSERT [dbo].[Usuario_Password_Historial] (uph_usuario, uph_password, uph_usuario_creacion, uph_fecha_creacion)
    VALUES (@U, [dbo].[FNC_PASSWORD_HASH](@CLAVE_TEMPORAL, @SALT), @USUARIO, [dbo].[FNC_AHORA]())
    DECLARE @DET NVARCHAR(400) = N'Nueva clave temporal enviada a ' + @CORREO
    EXEC [dbo].[INS_LEAD_ACTIVIDAD] @LEAD = @LEAD, @TIPO = 'SISTEMA', @ICONO = 'send', @TITULO = N'Credenciales reenviadas', @DETALLE = @DET, @USUARIO = @USUARIO
COMMIT TRANSACTION
RETURN 0
GO

/* Deja constancia de las demos que vencieron. No es lo que corta el acceso
   (eso lo hace sus_fecha_fin): es para que el estado y la línea de tiempo lo
   digan. Se llama al cargar el Centro; es idempotente y barato. */
CREATE OR ALTER PROCEDURE [dbo].[UPD_LEAD_DEMO_VENCER]
AS
SET NOCOUNT ON
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
DECLARE @V TABLE (lead INT, expira DATE)
UPDATE [dbo].[Lead_Demo] SET ldm_estado = 'VENCIDA', ldm_fecha_actualizacion = [dbo].[FNC_AHORA]()
OUTPUT inserted.ldm_lead, inserted.ldm_expira INTO @V
 WHERE ldm_estado IN ('ACTIVA', 'EXTENDIDA') AND ldm_expira < @HOY
INSERT [dbo].[Lead_Actividad] (lac_lead, lac_tipo, lac_icono, lac_titulo, lac_detalle, lac_usuario, lac_fecha)
SELECT lead, 'SISTEMA', 'clock', N'Demo vencida', N'Venció el ' + CONVERT(NVARCHAR(10), expira, 103) + N'. El acceso quedó suspendido; los datos se conservan.', NULL, [dbo].[FNC_AHORA]()
  FROM @V
SELECT COUNT(*) AS VENCIDAS FROM @V
GO

/* =============================================================== PROPUESTA */

CREATE OR ALTER PROCEDURE [dbo].[INS_PROPUESTA]
@ID                 INT = NULL OUTPUT,
@VERSION            INT = NULL OUTPUT,
@LEAD               INT,
@TIPO               VARCHAR(15),
@PLAN_COMERCIAL     INT = NULL,
@NOMBRE_PLAN        NVARCHAR(100),
@MODULOS            NVARCHAR(500),
@LIM_USUARIOS       INT = NULL, @LIM_ACTIVOS INT = NULL, @LIM_PLANTAS INT = NULL, @LIM_BODEGAS INT = NULL, @LIM_GB INT = NULL,
@IMPLEMENTACION_UF  DECIMAL(18,2),
@MENSUAL_UF         DECIMAL(18,2),
@DESCUENTO_PCT      DECIMAL(5,2),
@VIGENCIA_MESES     INT,
@CONDICIONES        NVARCHAR(2000) = NULL,
@USUARIO            INT
AS
SET NOCOUNT ON
DECLARE @ESTADO VARCHAR(20) = (SELECT lea_estado FROM [dbo].[Lead] WHERE lea_id = @LEAD AND lea_habilitado = 1)
IF @ESTADO IS NULL BEGIN RAISERROR('1.- EL LEAD NO EXISTE.', 16, 1) RETURN -1 END
IF @ESTADO IN ('CONCRETADO', 'PERDIDO') BEGIN RAISERROR('2.- ESTE LEAD ESTÁ CERRADO.', 16, 1) RETURN -1 END
IF @TIPO = 'ESTANDAR' AND NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE plc_id = @PLAN_COMERCIAL AND plc_habilitado = 1 AND plc_publico = 1)
BEGIN RAISERROR('3.- ELIGE UN PLAN ESTÁNDAR.', 16, 1) RETURN -1 END
IF LEN(LTRIM(RTRIM(ISNULL(@NOMBRE_PLAN, N'')))) = 0 BEGIN RAISERROR('4.- PONLE NOMBRE AL PLAN.', 16, 1) RETURN -1 END
IF LEN(LTRIM(RTRIM(ISNULL(@MODULOS, N'')))) = 0 BEGIN RAISERROR('5.- ELIGE AL MENOS UN MÓDULO.', 16, 1) RETURN -1 END
IF ISNULL(@MENSUAL_UF, 0) <= 0 BEGIN RAISERROR('6.- LA MENSUALIDAD DEBE SER MAYOR QUE CERO.', 16, 1) RETURN -1 END
IF ISNULL(@IMPLEMENTACION_UF, 0) < 0 BEGIN RAISERROR('7.- LA IMPLEMENTACIÓN NO PUEDE SER NEGATIVA.', 16, 1) RETURN -1 END
IF ISNULL(@DESCUENTO_PCT, 0) NOT BETWEEN 0 AND 50 BEGIN RAISERROR('8.- EL DESCUENTO VA DE 0 A 50 %.', 16, 1) RETURN -1 END
IF ISNULL(@VIGENCIA_MESES, 0) NOT BETWEEN 1 AND 60 BEGIN RAISERROR('9.- LA VIGENCIA VA DE 1 A 60 MESES.', 16, 1) RETURN -1 END
IF EXISTS (SELECT 1 FROM [dbo].[Contrato] WHERE ctt_lead = @LEAD AND ctt_estado IN ('ENVIADO', 'VISUALIZADO'))
BEGIN RAISERROR('10.- HAY UN CONTRATO ESPERANDO FIRMA. ANÚLALO ANTES DE CAMBIAR LA PROPUESTA.', 16, 1) RETURN -1 END

-- Implementación + mensual con descuento × vigencia. Mismo cálculo que el navegador y que el PDF.
DECLARE @TOTAL DECIMAL(18,2) = ROUND(@IMPLEMENTACION_UF + ROUND(@MENSUAL_UF * (100 - @DESCUENTO_PCT) / 100, 2) * @VIGENCIA_MESES, 2)
SET @VERSION = ISNULL((SELECT MAX(ppt_version) FROM [dbo].[Propuesta] WHERE ppt_lead = @LEAD), 0) + 1

BEGIN TRANSACTION
    UPDATE [dbo].[Propuesta] SET ppt_estado = 'REEMPLAZADA', ppt_usuario_actualizacion = @USUARIO, ppt_fecha_actualizacion = [dbo].[FNC_AHORA]()
     WHERE ppt_lead = @LEAD AND ppt_estado IN ('BORRADOR', 'ENVIADA')
    DECLARE @MONEDA VARCHAR(3) = (SELECT lea_moneda FROM [dbo].[Lead] WHERE lea_id = @LEAD)
    INSERT [dbo].[Propuesta] (ppt_moneda, ppt_lead, ppt_version, ppt_tipo, ppt_plan_comercial, ppt_nombre_plan, ppt_modulos, ppt_lim_usuarios,
                              ppt_lim_activos, ppt_lim_plantas, ppt_lim_bodegas, ppt_lim_almacenamiento_gb, ppt_implementacion_uf,
                              ppt_mensual_uf, ppt_descuento_pct, ppt_vigencia_meses, ppt_total_uf, ppt_condiciones, ppt_estado,
                              ppt_usuario_creacion, ppt_fecha_creacion)
    VALUES (@MONEDA, @LEAD, @VERSION, @TIPO, CASE WHEN @TIPO = 'ESTANDAR' THEN @PLAN_COMERCIAL END, LTRIM(RTRIM(@NOMBRE_PLAN)), @MODULOS,
            @LIM_USUARIOS, @LIM_ACTIVOS, @LIM_PLANTAS, @LIM_BODEGAS, @LIM_GB, @IMPLEMENTACION_UF, @MENSUAL_UF, @DESCUENTO_PCT,
            @VIGENCIA_MESES, @TOTAL, @CONDICIONES, 'BORRADOR', @USUARIO, [dbo].[FNC_AHORA]())
    SET @ID = SCOPE_IDENTITY()
COMMIT TRANSACTION
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_PROPUESTA_PDF]
@ID INT, @PDF VARBINARY(MAX)
AS
SET NOCOUNT ON
UPDATE [dbo].[Propuesta] SET ppt_pdf = @PDF WHERE ppt_id = @ID
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_PROPUESTA_ENVIADA]
@ID INT, @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @LEAD INT, @V INT, @NOMBRE NVARCHAR(100), @TOTAL DECIMAL(18,2), @MENSUAL DECIMAL(18,2), @DESC DECIMAL(5,2)
SELECT @LEAD = ppt_lead, @V = ppt_version, @NOMBRE = ppt_nombre_plan, @TOTAL = ppt_total_uf, @MENSUAL = ppt_mensual_uf, @DESC = ppt_descuento_pct
  FROM [dbo].[Propuesta] WHERE ppt_id = @ID AND ppt_estado IN ('BORRADOR', 'ENVIADA')
IF @LEAD IS NULL BEGIN RAISERROR('1.- LA PROPUESTA NO EXISTE O YA FUE REEMPLAZADA.', 16, 1) RETURN -1 END
BEGIN TRANSACTION
    UPDATE [dbo].[Propuesta] SET ppt_estado = 'ENVIADA', ppt_enviada_fecha = [dbo].[FNC_AHORA](), ppt_usuario_actualizacion = @USUARIO,
                                 ppt_fecha_actualizacion = [dbo].[FNC_AHORA]() WHERE ppt_id = @ID
    UPDATE [dbo].[Lead] SET lea_estado = 'PROPUESTA', lea_fecha_estado = [dbo].[FNC_AHORA](), lea_ejecutivo = ISNULL(lea_ejecutivo, @USUARIO)
     WHERE lea_id = @LEAD AND lea_estado IN ('NUEVO', 'CONTACTADO', 'CALIFICADO', 'DEMO')
    DECLARE @DET NVARCHAR(400) = @NOMBRE + N' · v' + CAST(@V AS NVARCHAR(5)) + N' · '
          + REPLACE(CONVERT(NVARCHAR(20), ROUND(@MENSUAL * (100 - @DESC) / 100, 2)), '.', ',') + N' UF/mes · total '
          + REPLACE(CONVERT(NVARCHAR(20), @TOTAL), '.', ',') + N' UF'
    EXEC [dbo].[INS_LEAD_ACTIVIDAD] @LEAD = @LEAD, @TIPO = 'SISTEMA', @ICONO = 'quote', @TITULO = N'Propuesta enviada', @DETALLE = @DET, @USUARIO = @USUARIO
COMMIT TRANSACTION
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_PROPUESTA_PDF]
@ID INT
AS
SET NOCOUNT ON
SELECT P.ppt_pdf AS PDF, P.ppt_version AS VERSION, L.lea_empresa AS EMPRESA
  FROM [dbo].[Propuesta] P JOIN [dbo].[Lead] L ON L.lea_id = P.ppt_lead
 WHERE P.ppt_id = @ID
GO

/* ================================================================ CONTRATO */

/* Genera la versión siguiente del contrato a partir de una propuesta.
   Exige el RUT de la empresa: con él nace (o se convierte) el cliente. */
CREATE OR ALTER PROCEDURE [dbo].[INS_CONTRATO]
@ID INT = NULL OUTPUT, @VERSION INT = NULL OUTPUT, @LEAD INT, @PROPUESTA INT, @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @ESTADO VARCHAR(20), @RUT VARCHAR(30)
SELECT @ESTADO = lea_estado, @RUT = ISNULL(lea_identificador, lea_rut) FROM [dbo].[Lead] WHERE lea_id = @LEAD AND lea_habilitado = 1
IF @ESTADO IS NULL BEGIN RAISERROR('1.- EL LEAD NO EXISTE.', 16, 1) RETURN -1 END
IF @ESTADO IN ('CONCRETADO', 'PERDIDO') BEGIN RAISERROR('2.- ESTE LEAD ESTÁ CERRADO.', 16, 1) RETURN -1 END
IF @RUT IS NULL BEGIN RAISERROR('3.- FALTA EL IDENTIFICADOR TRIBUTARIO DE LA EMPRESA. COMPLÉTALO EN «INFORMACIÓN» ANTES DE GENERAR EL CONTRATO.', 16, 1) RETURN -1 END
IF EXISTS (SELECT 1 FROM [dbo].[Lead] WHERE lea_id = @LEAD AND lea_pais_id IS NULL) BEGIN RAISERROR('3.- FALTA EL PAÍS DE LA EMPRESA. ELÍGELO EN «INFORMACIÓN» ANTES DE GENERAR EL CONTRATO.', 16, 1) RETURN -1 END
IF EXISTS (SELECT 1 FROM [dbo].[Cliente] C WHERE C.cli_identificador = @RUT
            AND NOT EXISTS (SELECT 1 FROM [dbo].[Lead_Demo] D WHERE D.ldm_lead = @LEAD AND D.ldm_cliente = C.cli_id))
BEGIN RAISERROR('4.- YA EXISTE UN CLIENTE SIGMA CON ESE RUT.', 16, 1) RETURN -1 END
IF NOT EXISTS (SELECT 1 FROM [dbo].[Propuesta] WHERE ppt_id = @PROPUESTA AND ppt_lead = @LEAD AND ppt_estado IN ('ENVIADA', 'ACEPTADA'))
BEGIN RAISERROR('5.- EL CONTRATO SALE DE LA PROPUESTA VIGENTE Y ENVIADA.', 16, 1) RETURN -1 END
IF EXISTS (SELECT 1 FROM [dbo].[Contrato] WHERE ctt_lead = @LEAD AND ctt_estado IN ('ENVIADO', 'VISUALIZADO', 'BORRADOR'))
BEGIN RAISERROR('6.- YA HAY UN CONTRATO EN CURSO. ANÚLALO PARA GENERAR UNA VERSIÓN NUEVA.', 16, 1) RETURN -1 END

SET @VERSION = ISNULL((SELECT MAX(ctt_version) FROM [dbo].[Contrato] WHERE ctt_lead = @LEAD), 0) + 1
BEGIN TRANSACTION
    INSERT [dbo].[Contrato] (ctt_lead, ctt_propuesta, ctt_version, ctt_estado, ctt_usuario_creacion, ctt_fecha_creacion)
    VALUES (@LEAD, @PROPUESTA, @VERSION, 'BORRADOR', @USUARIO, [dbo].[FNC_AHORA]())
    SET @ID = SCOPE_IDENTITY()
    UPDATE [dbo].[Propuesta] SET ppt_estado = 'ACEPTADA', ppt_usuario_actualizacion = @USUARIO, ppt_fecha_actualizacion = [dbo].[FNC_AHORA]()
     WHERE ppt_id = @PROPUESTA
    UPDATE [dbo].[Lead] SET lea_estado = 'CONTRATO', lea_fecha_estado = [dbo].[FNC_AHORA]() WHERE lea_id = @LEAD
COMMIT TRANSACTION
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_CONTRATO_PDF]
@ID INT, @PDF VARBINARY(MAX), @SHA256 CHAR(64)
AS
SET NOCOUNT ON
IF EXISTS (SELECT 1 FROM [dbo].[Contrato] WHERE ctt_id = @ID AND ctt_estado <> 'BORRADOR')
BEGIN RAISERROR('1.- UN CONTRATO ENVIADO NO SE MODIFICA: GENERA UNA VERSIÓN NUEVA.', 16, 1) RETURN -1 END
UPDATE [dbo].[Contrato] SET ctt_pdf = @PDF, ctt_pdf_sha256 = LOWER(@SHA256) WHERE ctt_id = @ID
RETURN 0
GO

/* Enviar o reenviar: un token nuevo invalida el anterior (se guarda solo
   su hash, así que el enlace viejo deja de encontrar contrato). */
CREATE OR ALTER PROCEDURE [dbo].[UPD_CONTRATO_ENVIADO]
@ID INT, @TOKEN_HASH VARBINARY(32), @EXPIRA DATETIME, @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @LEAD INT, @V INT, @EST VARCHAR(15), @CORREO NVARCHAR(200)
SELECT @LEAD = C.ctt_lead, @V = C.ctt_version, @EST = C.ctt_estado, @CORREO = L.lea_correo
  FROM [dbo].[Contrato] C JOIN [dbo].[Lead] L ON L.lea_id = C.ctt_lead WHERE C.ctt_id = @ID
IF @LEAD IS NULL BEGIN RAISERROR('1.- EL CONTRATO NO EXISTE.', 16, 1) RETURN -1 END
IF @EST NOT IN ('BORRADOR', 'ENVIADO', 'VISUALIZADO') BEGIN RAISERROR('2.- ESTE CONTRATO YA NO SE PUEDE ENVIAR.', 16, 1) RETURN -1 END
IF EXISTS (SELECT 1 FROM [dbo].[Contrato] WHERE ctt_id = @ID AND ctt_pdf IS NULL) BEGIN RAISERROR('3.- EL CONTRATO NO TIENE DOCUMENTO.', 16, 1) RETURN -1 END
BEGIN TRANSACTION
    UPDATE [dbo].[Contrato] SET ctt_token_hash = @TOKEN_HASH, ctt_token_expira = @EXPIRA, ctt_token_usado = 0,
                                ctt_estado = CASE WHEN ctt_estado = 'BORRADOR' THEN 'ENVIADO' ELSE ctt_estado END,
                                ctt_enviado_fecha = [dbo].[FNC_AHORA](), ctt_usuario_actualizacion = @USUARIO, ctt_fecha_actualizacion = [dbo].[FNC_AHORA]()
     WHERE ctt_id = @ID
    DECLARE @T NVARCHAR(200) = CASE WHEN @EST = 'BORRADOR' THEN N'Contrato v' + CAST(@V AS NVARCHAR(5)) + N' enviado para firma'
                                    ELSE N'Contrato v' + CAST(@V AS NVARCHAR(5)) + N' reenviado' END
    DECLARE @D NVARCHAR(400) = N'Enlace personal enviado a ' + @CORREO + N' · vence el ' + CONVERT(NVARCHAR(10), @EXPIRA, 103)
    EXEC [dbo].[INS_LEAD_ACTIVIDAD] @LEAD = @LEAD, @TIPO = 'SISTEMA', @ICONO = 'sign', @TITULO = @T, @DETALLE = @D, @USUARIO = @USUARIO
COMMIT TRANSACTION
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_CONTRATO_ANULAR]
@ID INT, @MOTIVO NVARCHAR(300), @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @LEAD INT, @V INT, @EST VARCHAR(15)
SELECT @LEAD = ctt_lead, @V = ctt_version, @EST = ctt_estado FROM [dbo].[Contrato] WHERE ctt_id = @ID
IF @LEAD IS NULL BEGIN RAISERROR('1.- EL CONTRATO NO EXISTE.', 16, 1) RETURN -1 END
IF @EST IN ('FIRMADO', 'ANULADO') BEGIN RAISERROR('2.- UN CONTRATO FIRMADO O ANULADO NO SE ANULA.', 16, 1) RETURN -1 END
IF LEN(LTRIM(RTRIM(ISNULL(@MOTIVO, N'')))) = 0 BEGIN RAISERROR('3.- INDICA EL MOTIVO DE LA ANULACIÓN.', 16, 1) RETURN -1 END
BEGIN TRANSACTION
    UPDATE [dbo].[Contrato] SET ctt_estado = 'ANULADO', ctt_motivo_anulacion = @MOTIVO, ctt_token_usado = 1,
                                ctt_usuario_actualizacion = @USUARIO, ctt_fecha_actualizacion = [dbo].[FNC_AHORA]() WHERE ctt_id = @ID
    UPDATE [dbo].[Lead] SET lea_estado = 'NEGOCIACION', lea_fecha_estado = [dbo].[FNC_AHORA]() WHERE lea_id = @LEAD AND lea_estado = 'CONTRATO'
    UPDATE [dbo].[Propuesta] SET ppt_estado = 'ENVIADA' WHERE ppt_id = (SELECT ctt_propuesta FROM [dbo].[Contrato] WHERE ctt_id = @ID) AND ppt_estado = 'ACEPTADA'
    DECLARE @T NVARCHAR(200) = N'Contrato v' + CAST(@V AS NVARCHAR(5)) + N' anulado'
    EXEC [dbo].[INS_LEAD_ACTIVIDAD] @LEAD = @LEAD, @TIPO = 'SISTEMA', @ICONO = 'x', @TITULO = @T, @DETALLE = @MOTIVO, @USUARIO = @USUARIO
COMMIT TRANSACTION
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_CONTRATO_PDF]
@ID INT, @FIRMADO BIT = 0
AS
SET NOCOUNT ON
SELECT CASE WHEN @FIRMADO = 1 THEN C.ctt_pdf_firmado ELSE C.ctt_pdf END AS PDF, C.ctt_version AS VERSION, L.lea_empresa AS EMPRESA, C.ctt_lead AS LEAD
  FROM [dbo].[Contrato] C JOIN [dbo].[Lead] L ON L.lea_id = C.ctt_lead
 WHERE C.ctt_id = @ID
GO

/* La página pública pregunta por el HASH del token: el id del contrato nunca
   viaja ni autoriza. Devuelve lo necesario para decidir el estado de la
   página (pendiente, vencido, usado, inválido) y para mostrar el resumen. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CONTRATO_TOKEN]
@TOKEN_HASH VARBINARY(32)
AS
SET NOCOUNT ON
SELECT  C.ctt_id AS ID, C.ctt_version AS VERSION, C.ctt_estado AS ESTADO, C.ctt_token_usado AS USADO,
        CONVERT(VARCHAR(19), C.ctt_token_expira, 120) AS EXPIRA,
        CASE WHEN C.ctt_token_expira < [dbo].[FNC_AHORA]() THEN 1 ELSE 0 END AS VENCIDO,
        C.ctt_pdf_sha256 AS PDF_SHA256, CONVERT(VARCHAR(16), C.ctt_firmado_fecha, 120) AS FIRMADO,
        C.ctt_firmante_nombre AS FIRMANTE, C.ctt_pdf_firmado_sha256 AS PDF_FIRMADO_SHA256,
        L.lea_id AS LEAD, L.lea_empresa AS EMPRESA, ISNULL(L.lea_identificador, L.lea_rut) AS RUT_EMPRESA, L.lea_moneda AS MONEDA, ISNULL(L.lea_pais_id, 1) AS PAIS_ID,
        (SELECT pai_identificador_nombre FROM [dbo].[Paises] WHERE pai_id = ISNULL(L.lea_pais_id, 1)) AS IDENT_ETIQUETA, L.lea_contacto_nombre AS CONTACTO, L.lea_correo AS CORREO,
        P.ppt_nombre_plan AS PLAN_NOMBRE, P.ppt_mensual_uf AS MENSUAL_UF, P.ppt_descuento_pct AS DESCUENTO_PCT,
        P.ppt_implementacion_uf AS IMPLEMENTACION_UF, P.ppt_vigencia_meses AS VIGENCIA_MESES, P.ppt_total_uf AS TOTAL_UF,
        LTRIM(RTRIM(ISNULL(U.usu_nombre, '') + ' ' + ISNULL(U.usu_apellido_paterno, ''))) AS EJECUTIVO, U.usu_correo AS EJECUTIVO_CORREO
  FROM  [dbo].[Contrato] C
  JOIN  [dbo].[Lead] L ON L.lea_id = C.ctt_lead
  JOIN  [dbo].[Propuesta] P ON P.ppt_id = C.ctt_propuesta
  LEFT JOIN [dbo].[Usuario] U ON U.usu_id = L.lea_ejecutivo
 WHERE  C.ctt_token_hash = @TOKEN_HASH
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_CONTRATO_VISUALIZADO]
@ID INT
AS
SET NOCOUNT ON
DECLARE @LEAD INT, @V INT
UPDATE [dbo].[Contrato] SET ctt_estado = 'VISUALIZADO', ctt_visualizado_fecha = [dbo].[FNC_AHORA]()
 WHERE ctt_id = @ID AND ctt_estado = 'ENVIADO'
IF @@ROWCOUNT = 1
BEGIN
    SELECT @LEAD = ctt_lead, @V = ctt_version FROM [dbo].[Contrato] WHERE ctt_id = @ID
    DECLARE @T NVARCHAR(200) = N'Contrato v' + CAST(@V AS NVARCHAR(5)) + N' visualizado'
    EXEC [dbo].[INS_LEAD_ACTIVIDAD] @LEAD = @LEAD, @TIPO = 'SISTEMA', @ICONO = 'eye', @TITULO = @T, @DETALLE = N'El cliente abrió el enlace de firma'
END
RETURN 0
GO

/* LA FIRMA Y LA CONVERSIÓN, EN UNA TRANSACCIÓN
     Marca el token usado, guarda la evidencia, pasa el lead a CONCRETADO y
     deja un cliente con suscripción activa:
       - con demo: la empresa demo se convierte (RUT real, plan, término);
       - sin demo: se crea el cliente, su planta y su usuario principal.
     Plan: el estándar elegido o, si es personalizado, un plan no público
     propio de este cliente con sus módulos y topes.
   Devuelve @CLIENTE y, si creó un usuario, @USUARIO_NUEVO para que el
   servicio le envíe sus credenciales. */
CREATE OR ALTER PROCEDURE [dbo].[UPD_CONTRATO_FIRMAR]
@ID                 INT,
@TOKEN_HASH         VARBINARY(32),
@NOMBRE             NVARCHAR(200),
@RUT                VARCHAR(20),
@IP                 VARCHAR(64),
@USER_AGENT         NVARCHAR(500),
@FIRMA_HASH         CHAR(64),
@PDF_FIRMADO        VARBINARY(MAX),
@PDF_FIRMADO_SHA256 CHAR(64),
@KEY_TEXTO          VARCHAR(200),
@CLAVE_TEMPORAL     VARCHAR(100),
@CLIENTE            INT = NULL OUTPUT,
@USUARIO_NUEVO      INT = NULL OUTPUT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA](), @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
DECLARE @LEAD INT, @PROP INT, @EST VARCHAR(15), @USADO BIT, @EXP DATETIME, @V INT
SELECT @LEAD = ctt_lead, @PROP = ctt_propuesta, @EST = ctt_estado, @USADO = ctt_token_usado, @EXP = ctt_token_expira, @V = ctt_version
  FROM [dbo].[Contrato] WHERE ctt_id = @ID AND ctt_token_hash = @TOKEN_HASH

IF @LEAD IS NULL BEGIN RAISERROR('1.- EL ENLACE NO ES VÁLIDO.', 16, 1) RETURN -1 END
IF @USADO = 1 OR @EST NOT IN ('ENVIADO', 'VISUALIZADO') BEGIN RAISERROR('2.- ESTE ENLACE YA SE USÓ.', 16, 1) RETURN -1 END
IF @EXP < @AHORA BEGIN RAISERROR('3.- EL ENLACE VENCIÓ.', 16, 1) RETURN -1 END
DECLARE @PAIS INT = ISNULL((SELECT lea_pais_id FROM [dbo].[Lead] WHERE lea_id = @LEAD), 1)
DECLARE @MONEDA VARCHAR(3) = ISNULL((SELECT lea_moneda FROM [dbo].[Lead] WHERE lea_id = @LEAD), 'UF')
IF [dbo].[FNC_IDENTIFICADOR_VALIDO](@PAIS, @RUT) = 0 BEGIN RAISERROR('4.- EL IDENTIFICADOR DE QUIEN FIRMA NO ES VÁLIDO.', 16, 1) RETURN -1 END
IF LEN(LTRIM(RTRIM(ISNULL(@NOMBRE, N'')))) < 3 BEGIN RAISERROR('5.- ESCRIBE TU NOMBRE COMPLETO.', 16, 1) RETURN -1 END

DECLARE @EMPRESA NVARCHAR(200), @RUT_EMP VARCHAR(30), @CODIGO VARCHAR(20), @CONTACTO NVARCHAR(200), @CORREO NVARCHAR(200), @TEL NVARCHAR(50), @EJEC INT
SELECT @EMPRESA = lea_empresa, @RUT_EMP = ISNULL(lea_identificador, lea_rut), @CODIGO = lea_codigo, @CONTACTO = lea_contacto_nombre, @CORREO = lea_correo,
       @TEL = lea_telefono, @EJEC = ISNULL(lea_ejecutivo, 1)
  FROM [dbo].[Lead] WHERE lea_id = @LEAD

DECLARE @TIPO VARCHAR(15), @PLAN INT, @NOMBRE_PLAN NVARCHAR(100), @MODULOS NVARCHAR(500), @VIG INT, @MENSUAL DECIMAL(18,2), @DESC DECIMAL(5,2),
        @L_USU INT, @L_ACT INT, @L_PLA INT, @L_GB INT
SELECT @TIPO = ppt_tipo, @PLAN = ppt_plan_comercial, @NOMBRE_PLAN = ppt_nombre_plan, @MODULOS = ppt_modulos, @VIG = ppt_vigencia_meses,
       @MENSUAL = ppt_mensual_uf, @DESC = ppt_descuento_pct, @L_USU = ppt_lim_usuarios, @L_ACT = ppt_lim_activos,
       @L_PLA = ppt_lim_plantas, @L_GB = ppt_lim_almacenamiento_gb
  FROM [dbo].[Propuesta] WHERE ppt_id = @PROP

DECLARE @DEMO_CLIENTE INT = (SELECT ldm_cliente FROM [dbo].[Lead_Demo] WHERE ldm_lead = @LEAD)
DECLARE @FIN DATE = DATEADD(MONTH, @VIG, @HOY)
DECLARE @SUS INT

BEGIN TRY
BEGIN TRANSACTION
    -- 1 · evidencia de la firma; el token queda inutilizado
    UPDATE [dbo].[Contrato]
       SET ctt_estado = 'FIRMADO', ctt_token_usado = 1, ctt_firmado_fecha = @AHORA, ctt_firmante_nombre = LTRIM(RTRIM(@NOMBRE)),
           ctt_firmante_rut = UPPER(LTRIM(RTRIM(@RUT))), ctt_firma_ip = @IP, ctt_firma_user_agent = LEFT(@USER_AGENT, 500),
           ctt_firma_hash = LOWER(@FIRMA_HASH), ctt_pdf_firmado = @PDF_FIRMADO, ctt_pdf_firmado_sha256 = LOWER(@PDF_FIRMADO_SHA256),
           ctt_fecha_actualizacion = @AHORA
     WHERE ctt_id = @ID AND ctt_token_usado = 0
    IF @@ROWCOUNT = 0 RAISERROR('2.- ESTE ENLACE YA SE USÓ.', 16, 1)

    -- 2 · el plan: el estándar, o uno propio del cliente si es personalizado
    IF @TIPO = 'PERSONALIZADA'
    BEGIN
        INSERT [dbo].[Plan_Comercial] (plc_codigo, plc_nombre, plc_descripcion, plc_orden, plc_dias_gracia, plc_publico,
                                       plc_usuario_creacion, plc_fecha_creacion, plc_habilitado)
        VALUES (LEFT(N'PERS-' + @CODIGO + N'-V' + CAST(@V AS NVARCHAR(5)), 50), LEFT(@NOMBRE_PLAN, 100),
                N'Plan personalizado de ' + LEFT(@EMPRESA, 150) + N' (contrato v' + CAST(@V AS NVARCHAR(5)) + N')', 90, 5, 0, @EJEC, @AHORA, 1)
        SET @PLAN = SCOPE_IDENTITY()

        DECLARE @FULL INT = (SELECT plc_id FROM [dbo].[Plan_Comercial] WHERE plc_codigo = N'FULL')
        INSERT [dbo].[Plan_Comercial_Funcionalidad] (pcf_plan_comercial, pcf_funcionalidad, pcf_cliente, pcf_funcionalidad_tipo, pcf_incluida,
                                                     pcf_limite, pcf_observacion, pcf_usuario_creacion, pcf_fecha_creacion, pcf_habilitado)
        SELECT @PLAN, p.pcf_funcionalidad, NULL, p.pcf_funcionalidad_tipo,
               CASE WHEN f.fun_codigo LIKE N'LIMITE %' OR f.fun_codigo = N'SOPORTE TICKETS' THEN 1
                    WHEN EXISTS (SELECT 1 FROM [dbo].[FNC_COMERCIAL_MODULO_FUNCIONALIDAD]() M
                                  JOIN STRING_SPLIT(@MODULOS, ',') S ON LTRIM(RTRIM(S.value)) = M.modulo
                                 WHERE M.fun_codigo = f.fun_codigo) THEN 1 ELSE 0 END,
               CASE f.fun_codigo WHEN N'LIMITE USUARIOS' THEN @L_USU WHEN N'LIMITE ACTIVOS' THEN @L_ACT
                                 WHEN N'LIMITE PLANTAS' THEN @L_PLA WHEN N'LIMITE ALMACENAMIENTO' THEN @L_GB ELSE p.pcf_limite END,
               N'Plan personalizado (contrato)', @EJEC, @AHORA, 1
          FROM [dbo].[Plan_Comercial_Funcionalidad] p
          JOIN [dbo].[Funcionalidad] f ON f.fun_id = p.pcf_funcionalidad
         WHERE p.pcf_plan_comercial = @FULL AND p.pcf_cliente IS NULL AND p.pcf_habilitado = 1

        INSERT [dbo].[Plan_Comercial_Precio] (pcp_plan_comercial, pcp_periodicidad_cobro, pcp_valor_uf, pcp_vigencia_desde,
                                              pcp_descuento_porcentaje, pcp_moneda, pcp_usuario_creacion, pcp_fecha_creacion, pcp_habilitado)
        VALUES (@PLAN, 1, @MENSUAL, @HOY, @DESC, @MONEDA, @EJEC, @AHORA, 1)
    END

    -- 3 · el cliente
    IF @DEMO_CLIENTE IS NOT NULL
    BEGIN
        SET @CLIENTE = @DEMO_CLIENTE
        UPDATE [dbo].[Cliente] SET cli_nombre = LEFT(@EMPRESA, 200), cli_razon_social = LEFT(@EMPRESA, 200), cli_identificador = @RUT_EMP, cli_pais = @PAIS, cli_moneda_cobro = @MONEDA,
                                   cli_nombre_fantasia = LEFT(@EMPRESA, 200), cli_habilitado = 1, cli_usuario_actualizacion = @EJEC,
                                   cli_fecha_actualizacion = @AHORA
         WHERE cli_id = @CLIENTE
        -- Los topes de la demo dejan de mandar: manda el plan contratado.
        UPDATE [dbo].[Plan_Comercial_Funcionalidad] SET pcf_habilitado = 0, pcf_usuario_actualizacion = @EJEC, pcf_fecha_actualizacion = @AHORA
         WHERE pcf_cliente = @CLIENTE AND pcf_habilitado = 1
        UPDATE [dbo].[Suscripcion] SET sus_plan_comercial = @PLAN, sus_suscripcion_estado = 1, sus_fecha_inicio = @HOY, sus_fecha_fin = DATEADD(DAY, -1, @HOY),
                                       sus_dias_gracia = (SELECT plc_dias_gracia FROM [dbo].[Plan_Comercial] WHERE plc_id = @PLAN),
                                       sus_observacion = N'Contrato v' + CAST(@V AS NVARCHAR(5)) + N' firmado', sus_usuario_actualizacion = @EJEC,
                                       sus_fecha_actualizacion = @AHORA
         WHERE sus_cliente = @CLIENTE
        UPDATE [dbo].[Cliente_Usuario] SET ucl_habilitado = 1, ucl_usuario_act = @EJEC, ucl_fecha_act = @AHORA WHERE ucl_id_cliente = @CLIENTE
        UPDATE [dbo].[Lead_Demo] SET ldm_estado = 'FINALIZADA', ldm_fecha_actualizacion = @AHORA WHERE ldm_lead = @LEAD
    END
    ELSE
    BEGIN
        INSERT [dbo].[Cliente] (cli_nombre, cli_habilitado, cli_pais, cli_moneda_cobro, cli_razon_social, cli_identificador, cli_nombre_fantasia,
                                cli_usuario_creacion, cli_fecha_creacion, cli_usuario_actualizacion, cli_fecha_actualizacion)
        VALUES (LEFT(@EMPRESA, 200), 1, @PAIS, @MONEDA, LEFT(@EMPRESA, 200), @RUT_EMP, LEFT(@EMPRESA, 200), @EJEC, @AHORA, @EJEC, @AHORA)
        SET @CLIENTE = SCOPE_IDENTITY()

        INSERT [dbo].[Cliente_Usuario] (ucl_id_usuario, ucl_id_cliente, ucl_habilitado, ucl_usuario_creacion, ucl_fecha_creacion, ucl_usuario_act, ucl_fecha_act)
        VALUES (@EJEC, @CLIENTE, 1, @EJEC, @AHORA, @EJEC, @AHORA)

        INSERT [dbo].[Cliente_Instalacion] (cin_cliente, cin_nombre, cin_descripcion, cin_codigo, cin_habilitado,
                                            cin_usuario_creacion, cin_fecha_creacion, cin_usuario_actualizacion, cin_fecha_actualizacion)
        VALUES (@CLIENTE, 'Planta principal', 'Creada al firmar el contrato', N'PL-1', 1, @EJEC, @AHORA, @EJEC, @AHORA)

        EXEC [dbo].[INS_SUSCRIPCION] @ID = @SUS OUTPUT, @CLIENTE = @CLIENTE, @PLAN_COMERCIAL = @PLAN, @KEY_PREFIJO = N'SGM',
             @KEY_TEXTO = @KEY_TEXTO, @CONTACTO_NOMBRE = @CONTACTO, @CONTACTO_EMAIL = @CORREO, @CONTACTO_TELEFONO = @TEL,
             @OBSERVACION = N'Contrato firmado en el Centro Comercial', @USUARIO = @EJEC
        IF @SUS IS NULL RAISERROR('6.- NO FUE POSIBLE CREAR LA SUSCRIPCIÓN.', 16, 1)
        UPDATE [dbo].[Suscripcion] SET sus_fecha_fin = DATEADD(DAY, -1, @HOY) WHERE sus_id = @SUS

        -- Usuario principal, si el correo no tiene ya una cuenta.
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Usuario] WHERE usu_login = @CORREO OR usu_correo = @CORREO)
        BEGIN
            DECLARE @SALT VARCHAR(50) = REPLACE(CONVERT(VARCHAR(50), NEWID()), '-', '')
            DECLARE @PERFIL_ADMIN INT = (SELECT TOP 1 per_id FROM [dbo].[Perfiles] WHERE per_nombre = 'Administrador del Cliente' AND per_cliente IS NULL AND per_habilitado = 1)
            INSERT [dbo].[Usuario] (usu_identificador, usu_login, usu_password, usu_password_salt, usu_nombre, usu_apellido_paterno,
                                    usu_apellido_materno, usu_telefono, usu_correo, usu_usuario_creacion, usu_fecha_creacion,
                                    usu_usuario_act, usu_fecha_act, usu_habilitado, usu_intentos_fallidos, usu_debe_cambiar_clave)
            VALUES ('CLI-' + @CODIGO, @CORREO, [dbo].[FNC_PASSWORD_HASH](@CLAVE_TEMPORAL, @SALT), @SALT, LEFT(@CONTACTO, 500), '', '',
                    @TEL, @CORREO, @EJEC, @AHORA, @EJEC, @AHORA, 1, 0, 1)
            SET @USUARIO_NUEVO = SCOPE_IDENTITY()
            INSERT [dbo].[Usuario_Password_Historial] (uph_usuario, uph_password, uph_usuario_creacion, uph_fecha_creacion)
            VALUES (@USUARIO_NUEVO, [dbo].[FNC_PASSWORD_HASH](@CLAVE_TEMPORAL, @SALT), @EJEC, @AHORA)
            INSERT [dbo].[Usuario_Paises] (upa_id_usuario, upa_id_pais, upa_usuario_creacion, upa_fecha_creacion, upa_usuario_act, upa_fecha_act)
            VALUES (@USUARIO_NUEVO, @PAIS, @EJEC, @AHORA, @EJEC, @AHORA)
            IF @PERFIL_ADMIN IS NOT NULL
            BEGIN
                INSERT [dbo].[Usuario_Perfil] (upe_usuario, upe_perfil) VALUES (@USUARIO_NUEVO, @PERFIL_ADMIN)
                DECLARE @UCL INT
                INSERT [dbo].[Cliente_Usuario] (ucl_id_usuario, ucl_id_cliente, ucl_habilitado, ucl_usuario_creacion, ucl_fecha_creacion, ucl_usuario_act, ucl_fecha_act)
                VALUES (@USUARIO_NUEVO, @CLIENTE, 1, @EJEC, @AHORA, @EJEC, @AHORA)
                SET @UCL = SCOPE_IDENTITY()
                INSERT [dbo].[Cliente_Usuario_Perfil] (cup_id_cliente_usuario, cup_id_perfil, cup_usuario_creacion, cup_fecha_creacion)
                VALUES (@UCL, @PERFIL_ADMIN, @EJEC, @AHORA)
            END
        END
    END

    -- 4 · el lead queda concretado
    UPDATE [dbo].[Lead] SET lea_estado = 'CONCRETADO', lea_fecha_estado = @AHORA, lea_cliente = @CLIENTE,
                            lea_proxima_accion_tipo = NULL, lea_proxima_accion_texto = NULL, lea_proxima_accion_fecha = NULL
     WHERE lea_id = @LEAD

    DECLARE @D1 NVARCHAR(2000) = N'Firmó ' + LTRIM(RTRIM(@NOMBRE)) + N' (' + UPPER(@RUT) + N') desde ' + ISNULL(@IP, N'?') + N' · SHA-256 ' + LEFT(LOWER(@PDF_FIRMADO_SHA256), 16) + N'…'
    DECLARE @T1 NVARCHAR(200) = N'Contrato v' + CAST(@V AS NVARCHAR(5)) + N' firmado'
    EXEC [dbo].[INS_LEAD_ACTIVIDAD] @LEAD = @LEAD, @TIPO = 'SISTEMA', @ICONO = 'sign', @TITULO = @T1, @DETALLE = @D1
    DECLARE @D2 NVARCHAR(2000) = LEFT(@NOMBRE_PLAN, 100) + N' · suscripción activa hasta el ' + CONVERT(NVARCHAR(10), @FIN, 103)
    EXEC [dbo].[INS_LEAD_ACTIVIDAD] @LEAD = @LEAD, @TIPO = 'SISTEMA', @ICONO = 'check', @TITULO = N'Cliente activado', @DETALLE = @D2
COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @ERR NVARCHAR(2000) = ERROR_MESSAGE()
    RAISERROR(@ERR, 16, 1)
    RETURN -1
END CATCH
RETURN 0
GO

/* Concretados, con su suscripción y el uso de usuarios frente al tope. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_COMERCIAL_CLIENTES]
AS
SET NOCOUNT ON
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
SELECT  L.lea_id AS LEAD, L.lea_codigo AS CODIGO, C.cli_id AS CLIENTE, C.cli_nombre AS EMPRESA, C.cli_identificador AS RUT,
        PC.plc_nombre AS PLAN_NOMBRE, S.sus_suscripcion_estado AS ESTADO_ID, SE.sue_codigo AS ESTADO,
        CONVERT(VARCHAR(10), S.sus_fecha_inicio, 120) AS DESDE, CONVERT(VARCHAR(10), S.sus_fecha_fin, 120) AS RENUEVA,
        DATEDIFF(DAY, @HOY, S.sus_fecha_fin) AS DIAS_RENOVACION,
        (SELECT TOP 1 ROUND(P.ppt_mensual_uf * (100 - P.ppt_descuento_pct) / 100, 2) FROM [dbo].[Propuesta] P
          WHERE P.ppt_lead = L.lea_id AND P.ppt_estado = 'ACEPTADA' ORDER BY P.ppt_version DESC) AS MENSUAL_UF,
        [dbo].[FNC_CLIENTE_CONSUMO](C.cli_id, N'LIMITE USUARIOS') AS USUARIOS,
        [dbo].[FNC_CLIENTE_LIMITE](C.cli_id, N'LIMITE USUARIOS') AS USUARIOS_TOPE,
        LTRIM(RTRIM(ISNULL(U.usu_nombre, '') + ' ' + ISNULL(U.usu_apellido_paterno, ''))) AS EJECUTIVO,
        C.cli_moneda_cobro AS MONEDA, C.cli_pais AS PAIS_ID
FROM    [dbo].[Lead] L
JOIN    [dbo].[Cliente] C ON C.cli_id = L.lea_cliente
LEFT JOIN [dbo].[Suscripcion] S ON S.sus_cliente = C.cli_id AND S.sus_habilitado = 1
LEFT JOIN [dbo].[Plan_Comercial] PC ON PC.plc_id = S.sus_plan_comercial
LEFT JOIN [dbo].[Suscripcion_Estado] SE ON SE.sue_id = S.sus_suscripcion_estado
LEFT JOIN [dbo].[Usuario] U ON U.usu_id = L.lea_ejecutivo
WHERE   L.lea_estado = 'CONCRETADO' AND L.lea_habilitado = 1
ORDER BY C.cli_nombre
GO

/* ================================================================ REUNIÓN */

CREATE OR ALTER PROCEDURE [dbo].[INS_REUNION]
@ID             INT = NULL OUTPUT,
@LEAD           INT,
@INICIO         DATETIME,
@DURACION       INT,
@LUGAR          VARCHAR(12),
@ENLACE         NVARCHAR(300) = NULL,
@DIRECCION      NVARCHAR(300) = NULL,
@MOTIVO         NVARCHAR(300) = NULL,
@PARTICIPANTES  NVARCHAR(MAX),          -- JSON [{"n":"Nombre","c":"correo","o":0}]
@USUARIO        INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Lead] WHERE lea_id = @LEAD AND lea_habilitado = 1 AND lea_estado NOT IN ('CONCRETADO', 'PERDIDO'))
BEGIN RAISERROR('1.- EL LEAD NO EXISTE O ESTÁ CERRADO.', 16, 1) RETURN -1 END
IF @INICIO IS NULL OR @INICIO < DATEADD(MINUTE, -5, [dbo].[FNC_AHORA]())
BEGIN RAISERROR('2.- ELIGE UNA FECHA Y HORA QUE NO HAYA PASADO.', 16, 1) RETURN -1 END
IF @LUGAR = 'VIDEO' AND (NULLIF(LTRIM(RTRIM(@ENLACE)), N'') IS NULL OR @ENLACE NOT LIKE N'https://%')
BEGIN RAISERROR('3.- EL ENLACE DE LA VIDEOLLAMADA DEBE EMPEZAR CON HTTPS://.', 16, 1) RETURN -1 END
IF @LUGAR = 'PRESENCIAL' AND NULLIF(LTRIM(RTRIM(@DIRECCION)), N'') IS NULL
BEGIN RAISERROR('4.- INDICA LA DIRECCIÓN DE LA REUNIÓN.', 16, 1) RETURN -1 END
IF ISJSON(@PARTICIPANTES) = 0 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@PARTICIPANTES))
BEGIN RAISERROR('5.- AGREGA AL MENOS UN PARTICIPANTE.', 16, 1) RETURN -1 END

DECLARE @ACT INT
BEGIN TRANSACTION
    INSERT [dbo].[Reunion] (reu_lead, reu_fecha_inicio, reu_duracion_min, reu_lugar, reu_enlace, reu_direccion, reu_motivo, reu_estado,
                            reu_creada_por, reu_fecha_creacion)
    VALUES (@LEAD, @INICIO, @DURACION, @LUGAR, CASE WHEN @LUGAR = 'VIDEO' THEN @ENLACE END,
            CASE WHEN @LUGAR = 'PRESENCIAL' THEN @DIRECCION END, @MOTIVO, 'AGENDADA', @USUARIO, [dbo].[FNC_AHORA]())
    SET @ID = SCOPE_IDENTITY()

    INSERT [dbo].[Reunion_Participante] (rup_reunion, rup_nombre, rup_correo, rup_es_organizador)
    SELECT @ID, LEFT(j.n, 200), LOWER(LEFT(LTRIM(RTRIM(j.c)), 200)), ISNULL(j.o, 0)
      FROM OPENJSON(@PARTICIPANTES) WITH (n NVARCHAR(200) '$.n', c NVARCHAR(200) '$.c', o BIT '$.o') j
     WHERE j.c LIKE N'%_@_%._%'

    DECLARE @LUG NVARCHAR(40) = CASE @LUGAR WHEN 'VIDEO' THEN N'Videollamada' WHEN 'PRESENCIAL' THEN N'Presencial' ELSE N'Teléfono' END
    DECLARE @DET NVARCHAR(2000) = @LUG + N' · ' + CONVERT(NVARCHAR(16), @INICIO, 103) + N' ' + LEFT(CONVERT(NVARCHAR(8), @INICIO, 108), 5)
          + N' · ' + CAST(@DURACION AS NVARCHAR(5)) + N' min' + ISNULL(N' · ' + @MOTIVO, N'')
    EXEC [dbo].[INS_LEAD_ACTIVIDAD] @ID = @ACT OUTPUT, @LEAD = @LEAD, @TIPO = 'REUNION', @ICONO = 'users', @TITULO = N'Reunión agendada',
         @DETALLE = @DET, @USUARIO = @USUARIO, @REUNION = @ID
    UPDATE [dbo].[Reunion] SET reu_actividad = @ACT WHERE reu_id = @ID

    UPDATE [dbo].[Lead] SET lea_proxima_accion_tipo = 'REUNION', lea_proxima_accion_texto = LEFT(N'Reunión: ' + ISNULL(@MOTIVO, @LUG), 200),
                            lea_proxima_accion_fecha = @INICIO, lea_ejecutivo = ISNULL(lea_ejecutivo, @USUARIO)
     WHERE lea_id = @LEAD
COMMIT TRANSACTION
SELECT rup_id AS ID, rup_nombre AS NOMBRE, rup_correo AS CORREO, rup_es_organizador AS ORGANIZADOR FROM [dbo].[Reunion_Participante] WHERE rup_reunion = @ID
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_REUNION_INVITACION]
@PARTICIPANTE INT
AS
SET NOCOUNT ON
UPDATE [dbo].[Reunion_Participante] SET rup_invitacion_enviada = 1 WHERE rup_id = @PARTICIPANTE
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_REUNION_REGISTRAR]
@ID INT, @NOTAS NVARCHAR(MAX) = NULL, @RESUMEN NVARCHAR(2000), @ACUERDOS_JSON NVARCHAR(MAX) = NULL, @OBJECION NVARCHAR(40) = NULL,
@DATOS_PROPUESTA_JSON NVARCHAR(1000) = NULL, @PROX_TIPO VARCHAR(20) = NULL, @PROX_TEXTO NVARCHAR(200) = NULL, @PROX_FECHA DATETIME = NULL,
@USUARIO INT
AS
SET NOCOUNT ON
DECLARE @LEAD INT, @ACT INT, @EST VARCHAR(12), @LUG VARCHAR(12), @INI DATETIME, @DUR INT
SELECT @LEAD = reu_lead, @ACT = reu_actividad, @EST = reu_estado, @LUG = reu_lugar, @INI = reu_fecha_inicio, @DUR = reu_duracion_min
  FROM [dbo].[Reunion] WHERE reu_id = @ID
IF @LEAD IS NULL BEGIN RAISERROR('1.- LA REUNIÓN NO EXISTE.', 16, 1) RETURN -1 END
IF @EST = 'CANCELADA' BEGIN RAISERROR('2.- LA REUNIÓN FUE CANCELADA.', 16, 1) RETURN -1 END
IF LEN(LTRIM(RTRIM(ISNULL(@RESUMEN, N'')))) = 0 BEGIN RAISERROR('3.- ESCRIBE UN RESUMEN DE LA REUNIÓN.', 16, 1) RETURN -1 END
IF @ACUERDOS_JSON IS NOT NULL AND ISJSON(@ACUERDOS_JSON) = 0 BEGIN RAISERROR('4.- LOS ACUERDOS NO TIENEN UN FORMATO VÁLIDO.', 16, 1) RETURN -1 END

BEGIN TRANSACTION
    UPDATE [dbo].[Reunion] SET reu_estado = 'REALIZADA', reu_notas = @NOTAS, reu_resumen = @RESUMEN, reu_acuerdos_json = @ACUERDOS_JSON,
                               reu_objecion = @OBJECION, reu_datos_propuesta_json = @DATOS_PROPUESTA_JSON,
                               reu_usuario_actualizacion = @USUARIO, reu_fecha_actualizacion = [dbo].[FNC_AHORA]()
     WHERE reu_id = @ID
    DECLARE @LUGN NVARCHAR(40) = CASE @LUG WHEN 'VIDEO' THEN N'por videollamada' WHEN 'PRESENCIAL' THEN N'presencial' ELSE N'por teléfono' END
    UPDATE [dbo].[Lead_Actividad] SET lac_titulo = N'Reunión ' + @LUGN + N' · ' + CAST(@DUR AS NVARCHAR(5)) + N' min',
                                      lac_detalle = LEFT(@RESUMEN + ISNULL(N' · Objeción: ' + @OBJECION, N''), 2000), lac_usuario = @USUARIO
     WHERE lac_id = @ACT
    IF @PROX_FECHA IS NOT NULL
        UPDATE [dbo].[Lead] SET lea_proxima_accion_tipo = @PROX_TIPO, lea_proxima_accion_texto = @PROX_TEXTO, lea_proxima_accion_fecha = @PROX_FECHA
         WHERE lea_id = @LEAD
    ELSE
        UPDATE [dbo].[Lead] SET lea_proxima_accion_tipo = NULL, lea_proxima_accion_texto = NULL, lea_proxima_accion_fecha = NULL
         WHERE lea_id = @LEAD AND lea_proxima_accion_tipo = 'REUNION' AND lea_proxima_accion_fecha = @INI
    UPDATE [dbo].[Lead] SET lea_estado = 'CONTACTADO', lea_fecha_estado = [dbo].[FNC_AHORA]() WHERE lea_id = @LEAD AND lea_estado = 'NUEVO'
COMMIT TRANSACTION
RETURN 0
GO

/* ===================================================== CAMBIO DE CLAVE (J) */

CREATE OR ALTER PROCEDURE [dbo].[SEL_USUARIO_DEBE_CAMBIAR]
@USUARIO INT
AS
SET NOCOUNT ON
SELECT CAST(ISNULL(usu_debe_cambiar_clave, 0) AS BIT) AS DEBE, usu_correo AS CORREO, usu_login AS LOGIN,
       LTRIM(RTRIM(ISNULL(usu_nombre, ''))) AS NOMBRE
  FROM [dbo].[Usuario] WHERE usu_id = @USUARIO
GO

/* Cambia la clave temporal por la definitiva y apaga la marca. Reglas del
   diseño J: 10+ caracteres, mayúscula, minúscula, número y símbolo, distinta
   de la temporal (UPD_USUARIO_PASSWORD ya impide repetir las anteriores). */
CREATE OR ALTER PROCEDURE [dbo].[UPD_USUARIO_CLAVE_OBLIGATORIA]
@USUARIO INT, @PASSWORD_NUEVO VARCHAR(500)
AS
SET NOCOUNT ON
SET XACT_ABORT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Usuario] WHERE usu_id = @USUARIO AND usu_debe_cambiar_clave = 1)
BEGIN RAISERROR('1.- ESTA CUENTA NO TIENE UN CAMBIO DE CLAVE PENDIENTE.', 16, 1) RETURN -1 END
IF LEN(ISNULL(@PASSWORD_NUEVO, '')) < 10
   OR PATINDEX('%[A-Z]%', @PASSWORD_NUEVO COLLATE Latin1_General_BIN) = 0
   OR PATINDEX('%[a-z]%', @PASSWORD_NUEVO COLLATE Latin1_General_BIN) = 0
   OR PATINDEX('%[0-9]%', @PASSWORD_NUEVO) = 0
   OR PATINDEX('%[^A-Za-z0-9]%', @PASSWORD_NUEVO COLLATE Latin1_General_BIN) = 0
BEGIN RAISERROR('2.- LA CONTRASEÑA DEBE TENER 10 O MÁS CARACTERES, MAYÚSCULA, MINÚSCULA, NÚMERO Y SÍMBOLO.', 16, 1) RETURN -1 END

DECLARE @R INT
BEGIN TRANSACTION
    /* La clave actual ya se comprobó en el login de esta misma sesión. Que la
       nueva sea distinta de la temporal lo asegura el historial de
       UPD_USUARIO_PASSWORD (la temporal es su última entrada). */
    EXEC @R = [dbo].[UPD_USUARIO_PASSWORD] @USUARIO = @USUARIO, @PASSWORD_NUEVO = @PASSWORD_NUEVO, @EXIGE_ACTUAL = 0
    IF @R <> 0 BEGIN IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION RETURN -1 END
    UPDATE [dbo].[Usuario] SET usu_debe_cambiar_clave = 0 WHERE usu_id = @USUARIO
COMMIT TRANSACTION
RETURN 0
GO

PRINT '456_CENTRO_COMERCIAL_SP aplicado.'
GO
