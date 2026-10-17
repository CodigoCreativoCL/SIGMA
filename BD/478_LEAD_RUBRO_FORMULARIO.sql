/* 478 · El formulario público de Inicio.aspx pide el rubro de la empresa (lea_rubro). Idempotente. */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[INS_LEAD_PUBLICO]
@ID             INT = NULL OUTPUT,
@CODIGO         VARCHAR(20) = NULL OUTPUT,
@EMPRESA        NVARCHAR(200),
@CONTACTO       NVARCHAR(200),
@CARGO          NVARCHAR(200) = NULL,
@RUBRO          NVARCHAR(200) = NULL,
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
    INSERT [dbo].[Lead] (lea_empresa, lea_contacto_nombre, lea_rubro, lea_contacto_cargo, lea_correo, lea_telefono, lea_pais,
                         lea_pais_id, lea_identificador, lea_rut, lea_moneda, lea_n_activos, lea_plan_interes, lea_intereses, lea_mensaje, lea_origen, lea_consentimiento,
                         lea_consentimiento_fecha, lea_ip, lea_estado, lea_fecha_estado, lea_usuario_creacion, lea_fecha_creacion)
    VALUES (LTRIM(RTRIM(@EMPRESA)), LTRIM(RTRIM(@CONTACTO)), NULLIF(LTRIM(RTRIM(@RUBRO)), N''), NULLIF(LTRIM(RTRIM(@CARGO)), N''), LOWER(LTRIM(RTRIM(@CORREO))),
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
PRINT '478_LEAD_RUBRO_FORMULARIO aplicado.'
GO
