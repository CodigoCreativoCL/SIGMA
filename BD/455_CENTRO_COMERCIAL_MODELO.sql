/* ============================================================================
   SIGMA — Bloque 455
   CENTRO COMERCIAL · MODELO DE DATOS, PARÁMETROS, PERMISOS Y MENÚ
   ----------------------------------------------------------------------------
   Prompt: MD/PROMPT_CLAUDE_IMPLEMENTAR_CENTRO_COMERCIAL.md (§4).
   Diseño: Fase 2/.../Redisenos/CentroComercial/artefacto/.

   EL CICLO COMERCIAL NO SE CUELGA DE USUARIO
     Un Lead no es un usuario ni un cliente: es una empresa interesada. Solo al
     crear la demo nace un Cliente (la empresa demo) y un Usuario (su contacto);
     al firmar, ESE MISMO cliente se convierte en el cliente real. Nada se
     vuelve a escribir a mano.

   LO QUE SE REUTILIZA EN VEZ DE DUPLICAR
     - Configuración: Sys_Parametros (prefijo COMERCIAL_), no una tabla nueva.
     - Límites de la demo: un Plan_Comercial «DEMO» no público + filas de
       Plan_Comercial_Funcionalidad del cliente demo. Así los topes de plantas,
       usuarios y activos los hace cumplir FNC_CLIENTE_PUEDE_CREAR (bloque 47),
       la misma guarda de cualquier cliente.
     - Suscripción al firmar: Suscripcion / INS_SUSCRIPCION (bloque 08).

   ESTADOS COMO CÓDIGO CON CHECK
     Son ciclos cerrados que solo recorre este módulo; un catálogo con ids fijos
     no aporta y obligaría a un JOIN en cada lectura del pipeline.

   DATOS SENSIBLES
     - Los tokens (firma) se guardan como SHA-256, nunca en claro.
     - La clave temporal de la demo pasa por FNC_PASSWORD_HASH como cualquier
       otra, y el usuario queda con usu_debe_cambiar_clave = 1.

   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

/* ------------------------------------------------------------------ 1. Lead */
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Lead]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Lead]
    (
        [lea_id]                    INT             NOT NULL IDENTITY(1,1),
        [lea_codigo]                VARCHAR(20)     NULL,
        [lea_empresa]               NVARCHAR(200)   NOT NULL,
        [lea_rut]                   VARCHAR(20)     NULL,
        [lea_rubro]                 NVARCHAR(200)   NULL,
        [lea_contacto_nombre]       NVARCHAR(200)   NOT NULL,
        [lea_contacto_cargo]        NVARCHAR(200)   NULL,
        [lea_correo]                NVARCHAR(200)   NOT NULL,
        [lea_telefono]              NVARCHAR(50)    NULL,
        [lea_pais]                  NVARCHAR(80)    NULL,
        [lea_n_activos]             NVARCHAR(40)    NULL,
        [lea_plan_interes]          NVARCHAR(80)    NULL,
        [lea_intereses]             NVARCHAR(500)   NULL,
        [lea_mensaje]               NVARCHAR(2000)  NULL,
        [lea_origen]                VARCHAR(20)     NOT NULL CONSTRAINT DF_LEA_ORIGEN DEFAULT 'FORM_WEB',
        [lea_consentimiento]        BIT             NOT NULL CONSTRAINT DF_LEA_CONSENTIMIENTO DEFAULT 0,
        [lea_consentimiento_fecha]  DATETIME        NULL,
        [lea_ip]                    VARCHAR(64)     NULL,
        [lea_estado]                VARCHAR(20)     NOT NULL CONSTRAINT DF_LEA_ESTADO DEFAULT 'NUEVO',
        [lea_motivo_perdida]        NVARCHAR(200)   NULL,
        [lea_ejecutivo]             INT             NULL,
        [lea_proxima_accion_tipo]   VARCHAR(20)     NULL,
        [lea_proxima_accion_texto]  NVARCHAR(200)   NULL,
        [lea_proxima_accion_fecha]  DATETIME        NULL,
        [lea_fecha_estado]          DATETIME        NOT NULL CONSTRAINT DF_LEA_FECHA_ESTADO DEFAULT GETDATE(),
        [lea_cliente]               INT             NULL,
        [lea_usuario_creacion]      INT             NULL,
        [lea_fecha_creacion]        DATETIME        NOT NULL CONSTRAINT DF_LEA_FECHA_CREACION DEFAULT GETDATE(),
        [lea_usuario_actualizacion] INT             NULL,
        [lea_fecha_actualizacion]   DATETIME        NULL,
        [lea_habilitado]            BIT             NOT NULL CONSTRAINT DF_LEA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_LEAD PRIMARY KEY CLUSTERED ([lea_id] ASC),
        CONSTRAINT FK_LEA_EJECUTIVO FOREIGN KEY ([lea_ejecutivo]) REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_LEA_CLIENTE   FOREIGN KEY ([lea_cliente])   REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT CK_LEA_ESTADO CHECK ([lea_estado] IN ('NUEVO','CONTACTADO','CALIFICADO','DEMO','PROPUESTA','NEGOCIACION','CONTRATO','CONCRETADO','PERDIDO')),
        CONSTRAINT CK_LEA_ORIGEN CHECK ([lea_origen] IN ('FORM_WEB','MANUAL'))
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_LEA_CODIGO ON [dbo].[Lead] ([lea_codigo]) WHERE [lea_codigo] IS NOT NULL
    CREATE NONCLUSTERED INDEX IX_LEA_ESTADO ON [dbo].[Lead] ([lea_estado], [lea_habilitado]) INCLUDE ([lea_ejecutivo], [lea_proxima_accion_fecha])
    CREATE NONCLUSTERED INDEX IX_LEA_IP ON [dbo].[Lead] ([lea_ip], [lea_fecha_creacion])
    PRINT 'Tabla Lead creada.'
END
ELSE PRINT 'Tabla Lead ya existe.'
GO

/* ------------------------------------------------------- 2. Lead_Actividad */
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Lead_Actividad]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Lead_Actividad]
    (
        [lac_id]        INT             NOT NULL IDENTITY(1,1),
        [lac_lead]      INT             NOT NULL,
        [lac_tipo]      VARCHAR(20)     NOT NULL,
        [lac_icono]     VARCHAR(40)     NULL,
        [lac_titulo]    NVARCHAR(200)   NOT NULL,
        [lac_detalle]   NVARCHAR(2000)  NULL,
        [lac_usuario]   INT             NULL,       -- NULL = lo registró el sistema
        [lac_fecha]     DATETIME        NOT NULL CONSTRAINT DF_LAC_FECHA DEFAULT GETDATE(),
        [lac_reunion]   INT             NULL,

        CONSTRAINT PK_LEAD_ACTIVIDAD PRIMARY KEY CLUSTERED ([lac_id] ASC),
        CONSTRAINT FK_LAC_LEAD    FOREIGN KEY ([lac_lead])    REFERENCES [dbo].[Lead] ([lea_id]),
        CONSTRAINT FK_LAC_USUARIO FOREIGN KEY ([lac_usuario]) REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT CK_LAC_TIPO CHECK ([lac_tipo] IN ('LLAMADA','EMAIL','REUNION','NOTA','SISTEMA'))
    )
    CREATE NONCLUSTERED INDEX IX_LAC_LEAD ON [dbo].[Lead_Actividad] ([lac_lead], [lac_fecha] DESC)
    PRINT 'Tabla Lead_Actividad creada.'
END
ELSE PRINT 'Tabla Lead_Actividad ya existe.'
GO

/* ------------------------------------------------------------ 3. Lead_Demo */
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Lead_Demo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Lead_Demo]
    (
        [ldm_id]                    INT             NOT NULL IDENTITY(1,1),
        [ldm_lead]                  INT             NOT NULL,
        [ldm_cliente]               INT             NOT NULL,
        [ldm_usuario_principal]     INT             NOT NULL,
        [ldm_inicio]                DATE            NOT NULL,
        [ldm_expira]                DATE            NOT NULL,
        [ldm_estado]                VARCHAR(20)     NOT NULL CONSTRAINT DF_LDM_ESTADO DEFAULT 'ACTIVA',
        [ldm_modulos]               NVARCHAR(500)   NULL,
        [ldm_lim_usuarios]          INT             NOT NULL,
        [ldm_lim_activos]           INT             NOT NULL,
        [ldm_lim_ot]                INT             NOT NULL,
        [ldm_lim_programaciones]    INT             NOT NULL,
        [ldm_lim_checklists]        INT             NOT NULL,
        [ldm_lim_repuestos]         INT             NOT NULL,
        [ldm_lim_bodegas]           INT             NOT NULL,
        [ldm_lim_plantas]           INT             NOT NULL,
        [ldm_usuario_creacion]      INT             NOT NULL,
        [ldm_fecha_creacion]        DATETIME        NOT NULL CONSTRAINT DF_LDM_FECHA_CREACION DEFAULT GETDATE(),
        [ldm_usuario_actualizacion] INT             NULL,
        [ldm_fecha_actualizacion]   DATETIME        NULL,

        CONSTRAINT PK_LEAD_DEMO PRIMARY KEY CLUSTERED ([ldm_id] ASC),
        CONSTRAINT FK_LDM_LEAD    FOREIGN KEY ([ldm_lead])              REFERENCES [dbo].[Lead] ([lea_id]),
        CONSTRAINT FK_LDM_CLIENTE FOREIGN KEY ([ldm_cliente])           REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_LDM_USUARIO FOREIGN KEY ([ldm_usuario_principal]) REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT CK_LDM_ESTADO CHECK ([ldm_estado] IN ('ACTIVA','EXTENDIDA','VENCIDA','FINALIZADA'))
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_LDM_LEAD ON [dbo].[Lead_Demo] ([ldm_lead])
    PRINT 'Tabla Lead_Demo creada.'
END
ELSE PRINT 'Tabla Lead_Demo ya existe.'
GO

/* ------------------------------------------------------------ 4. Propuesta */
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Propuesta]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Propuesta]
    (
        [ppt_id]                    INT             NOT NULL IDENTITY(1,1),
        [ppt_lead]                  INT             NOT NULL,
        [ppt_version]               INT             NOT NULL,
        [ppt_tipo]                  VARCHAR(15)     NOT NULL,
        [ppt_plan_comercial]        INT             NULL,
        [ppt_nombre_plan]           NVARCHAR(100)   NOT NULL,
        [ppt_modulos]               NVARCHAR(500)   NULL,
        [ppt_lim_usuarios]          INT             NULL,
        [ppt_lim_activos]           INT             NULL,
        [ppt_lim_plantas]           INT             NULL,
        [ppt_lim_bodegas]           INT             NULL,
        [ppt_lim_almacenamiento_gb] INT             NULL,
        [ppt_implementacion_uf]     DECIMAL(18,2)   NOT NULL CONSTRAINT DF_PPT_IMPLEMENTACION DEFAULT 0,
        [ppt_mensual_uf]            DECIMAL(18,2)   NOT NULL,
        [ppt_descuento_pct]         DECIMAL(5,2)    NOT NULL CONSTRAINT DF_PPT_DESCUENTO DEFAULT 0,
        [ppt_vigencia_meses]        INT             NOT NULL,
        [ppt_total_uf]              DECIMAL(18,2)   NOT NULL,
        [ppt_condiciones]           NVARCHAR(2000)  NULL,
        [ppt_estado]                VARCHAR(15)     NOT NULL CONSTRAINT DF_PPT_ESTADO DEFAULT 'BORRADOR',
        [ppt_pdf]                   VARBINARY(MAX)  NULL,
        [ppt_enviada_fecha]         DATETIME        NULL,
        [ppt_aperturas]             INT             NOT NULL CONSTRAINT DF_PPT_APERTURAS DEFAULT 0,
        [ppt_usuario_creacion]      INT             NOT NULL,
        [ppt_fecha_creacion]        DATETIME        NOT NULL CONSTRAINT DF_PPT_FECHA_CREACION DEFAULT GETDATE(),
        [ppt_usuario_actualizacion] INT             NULL,
        [ppt_fecha_actualizacion]   DATETIME        NULL,

        CONSTRAINT PK_PROPUESTA PRIMARY KEY CLUSTERED ([ppt_id] ASC),
        CONSTRAINT FK_PPT_LEAD FOREIGN KEY ([ppt_lead]) REFERENCES [dbo].[Lead] ([lea_id]),
        CONSTRAINT FK_PPT_PLAN_COMERCIAL FOREIGN KEY ([ppt_plan_comercial]) REFERENCES [dbo].[Plan_Comercial] ([plc_id]),
        CONSTRAINT CK_PPT_TIPO CHECK ([ppt_tipo] IN ('ESTANDAR','PERSONALIZADA')),
        CONSTRAINT CK_PPT_ESTADO CHECK ([ppt_estado] IN ('BORRADOR','ENVIADA','ACEPTADA','RECHAZADA','REEMPLAZADA')),
        CONSTRAINT CK_PPT_DESCUENTO CHECK ([ppt_descuento_pct] BETWEEN 0 AND 100),
        CONSTRAINT CK_PPT_VIGENCIA CHECK ([ppt_vigencia_meses] > 0)
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_PPT_LEAD_VERSION ON [dbo].[Propuesta] ([ppt_lead], [ppt_version])
    PRINT 'Tabla Propuesta creada.'
END
ELSE PRINT 'Tabla Propuesta ya existe.'
GO

/* ------------------------------------------------------------- 5. Contrato
   Una fila por versión. El PDF que se firma se guarda en la fila (no en
   disco): es la evidencia, y su SHA-256 se calcula sobre esos bytes exactos. */
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Contrato]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Contrato]
    (
        [ctt_id]                    INT             NOT NULL IDENTITY(1,1),
        [ctt_lead]                  INT             NOT NULL,
        [ctt_propuesta]             INT             NOT NULL,
        [ctt_version]               INT             NOT NULL,
        [ctt_estado]                VARCHAR(15)     NOT NULL CONSTRAINT DF_CTT_ESTADO DEFAULT 'BORRADOR',
        [ctt_motivo_anulacion]      NVARCHAR(300)   NULL,
        [ctt_pdf]                   VARBINARY(MAX)  NULL,
        [ctt_pdf_sha256]            CHAR(64)        NULL,
        [ctt_token_hash]            VARBINARY(32)   NULL,
        [ctt_token_expira]          DATETIME        NULL,
        [ctt_token_usado]           BIT             NOT NULL CONSTRAINT DF_CTT_TOKEN_USADO DEFAULT 0,
        [ctt_enviado_fecha]         DATETIME        NULL,
        [ctt_visualizado_fecha]     DATETIME        NULL,
        [ctt_firmado_fecha]         DATETIME        NULL,
        [ctt_firmante_nombre]       NVARCHAR(200)   NULL,
        [ctt_firmante_rut]          VARCHAR(20)     NULL,
        [ctt_firma_ip]              VARCHAR(64)     NULL,
        [ctt_firma_user_agent]      NVARCHAR(500)   NULL,
        [ctt_firma_hash]            CHAR(64)        NULL,   -- SHA-256 del evento de firma
        [ctt_pdf_firmado]           VARBINARY(MAX)  NULL,
        [ctt_pdf_firmado_sha256]    CHAR(64)        NULL,
        [ctt_usuario_creacion]      INT             NOT NULL,
        [ctt_fecha_creacion]        DATETIME        NOT NULL CONSTRAINT DF_CTT_FECHA_CREACION DEFAULT GETDATE(),
        [ctt_usuario_actualizacion] INT             NULL,
        [ctt_fecha_actualizacion]   DATETIME        NULL,

        CONSTRAINT PK_CONTRATO PRIMARY KEY CLUSTERED ([ctt_id] ASC),
        CONSTRAINT FK_CTT_LEAD      FOREIGN KEY ([ctt_lead])      REFERENCES [dbo].[Lead] ([lea_id]),
        CONSTRAINT FK_CTT_PROPUESTA FOREIGN KEY ([ctt_propuesta]) REFERENCES [dbo].[Propuesta] ([ppt_id]),
        CONSTRAINT CK_CTT_ESTADO CHECK ([ctt_estado] IN ('BORRADOR','ENVIADO','VISUALIZADO','FIRMADO','ANULADO'))
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_CTT_LEAD_VERSION ON [dbo].[Contrato] ([ctt_lead], [ctt_version])
    CREATE UNIQUE NONCLUSTERED INDEX UX_CTT_TOKEN ON [dbo].[Contrato] ([ctt_token_hash]) WHERE [ctt_token_hash] IS NOT NULL
    PRINT 'Tabla Contrato creada.'
END
ELSE PRINT 'Tabla Contrato ya existe.'
GO

/* -------------------------------------------- 6. Reunion y sus participantes */
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Reunion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Reunion]
    (
        [reu_id]                    INT             NOT NULL IDENTITY(1,1),
        [reu_lead]                  INT             NOT NULL,
        [reu_actividad]             INT             NULL,
        [reu_fecha_inicio]          DATETIME        NOT NULL,
        [reu_duracion_min]          INT             NOT NULL,
        [reu_lugar]                 VARCHAR(12)     NOT NULL,
        [reu_enlace]                NVARCHAR(300)   NULL,
        [reu_direccion]             NVARCHAR(300)   NULL,
        [reu_motivo]                NVARCHAR(300)   NULL,
        [reu_estado]                VARCHAR(12)     NOT NULL CONSTRAINT DF_REU_ESTADO DEFAULT 'AGENDADA',
        [reu_notas]                 NVARCHAR(MAX)   NULL,
        [reu_resumen]               NVARCHAR(2000)  NULL,
        [reu_acuerdos_json]         NVARCHAR(MAX)   NULL,
        [reu_objecion]              NVARCHAR(40)    NULL,
        [reu_datos_propuesta_json]  NVARCHAR(1000)  NULL,
        [reu_creada_por]            INT             NOT NULL,
        [reu_fecha_creacion]        DATETIME        NOT NULL CONSTRAINT DF_REU_FECHA_CREACION DEFAULT GETDATE(),
        [reu_usuario_actualizacion] INT             NULL,
        [reu_fecha_actualizacion]   DATETIME        NULL,

        CONSTRAINT PK_REUNION PRIMARY KEY CLUSTERED ([reu_id] ASC),
        CONSTRAINT FK_REU_LEAD       FOREIGN KEY ([reu_lead])       REFERENCES [dbo].[Lead] ([lea_id]),
        CONSTRAINT FK_REU_ACTIVIDAD  FOREIGN KEY ([reu_actividad])  REFERENCES [dbo].[Lead_Actividad] ([lac_id]),
        CONSTRAINT FK_REU_CREADA_POR FOREIGN KEY ([reu_creada_por]) REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT CK_REU_LUGAR  CHECK ([reu_lugar] IN ('VIDEO','PRESENCIAL','TELEFONO')),
        CONSTRAINT CK_REU_ESTADO CHECK ([reu_estado] IN ('AGENDADA','REALIZADA','CANCELADA')),
        CONSTRAINT CK_REU_DURACION CHECK ([reu_duracion_min] BETWEEN 5 AND 480)
    )
    CREATE NONCLUSTERED INDEX IX_REU_LEAD ON [dbo].[Reunion] ([reu_lead], [reu_fecha_inicio])
    PRINT 'Tabla Reunion creada.'
END
ELSE PRINT 'Tabla Reunion ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Reunion_Participante]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Reunion_Participante]
    (
        [rup_id]                  INT             NOT NULL IDENTITY(1,1),
        [rup_reunion]             INT             NOT NULL,
        [rup_nombre]              NVARCHAR(200)   NULL,
        [rup_correo]              NVARCHAR(200)   NOT NULL,
        [rup_es_organizador]      BIT             NOT NULL CONSTRAINT DF_RUP_ES_ORGANIZADOR DEFAULT 0,
        [rup_invitacion_enviada]  BIT             NOT NULL CONSTRAINT DF_RUP_INVITACION DEFAULT 0,

        CONSTRAINT PK_REUNION_PARTICIPANTE PRIMARY KEY CLUSTERED ([rup_id] ASC),
        CONSTRAINT FK_RUP_REUNION FOREIGN KEY ([rup_reunion]) REFERENCES [dbo].[Reunion] ([reu_id])
    )
    PRINT 'Tabla Reunion_Participante creada.'
END
ELSE PRINT 'Tabla Reunion_Participante ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_LAC_REUNION')
    ALTER TABLE [dbo].[Lead_Actividad] ADD CONSTRAINT FK_LAC_REUNION FOREIGN KEY ([lac_reunion]) REFERENCES [dbo].[Reunion] ([reu_id])
GO

/* ------------------------------------- 7. Cambio de clave obligatorio (J) */
IF COL_LENGTH('dbo.Usuario', 'usu_debe_cambiar_clave') IS NULL
BEGIN
    ALTER TABLE [dbo].[Usuario] ADD [usu_debe_cambiar_clave] BIT NOT NULL CONSTRAINT DF_USU_DEBE_CAMBIAR_CLAVE DEFAULT 0
    PRINT 'Columna Usuario.usu_debe_cambiar_clave creada.'
END
GO

/* ------------------------------------------------ 8. Parámetros comerciales */
MERGE [dbo].[Sys_Parametros] AS D
USING (VALUES
  ('COMERCIAL_CORREO_AVISO',   'Correo del equipo comercial',        'Recibe el aviso de cada lead nuevo y la copia de cada contrato firmado.', 'comercial@codigocreativo.tech'),
  ('COMERCIAL_DEMO_DIAS',      'Duración de la demo (días)',         'Días que dura una demo si el ejecutivo no indica otro valor.', '7'),
  ('COMERCIAL_DEMO_LIMITES',   'Límites por defecto de la demo',     'CLAVE=valor separados por punto y coma. Se precargan al crear una demo y se pueden ajustar.', 'USUARIOS=2;ACTIVOS=10;OT=20;PROGRAMACIONES=5;CHECKLISTS=5;REPUESTOS=20;BODEGAS=1;PLANTAS=1'),
  ('COMERCIAL_FIRMA_DIAS',     'Vigencia del enlace de firma (días)','Días que el enlace personal de firma de un contrato sigue sirviendo.', '7'),
  ('COMERCIAL_LEADS_POR_IP',   'Leads por IP y hora',                'Máximo de formularios públicos aceptados desde una misma IP en una hora.', '5'),
  ('COMERCIAL_RETENCION_MESES','Retención de notas de reunión',      'Meses que se conservan las notas y transcripciones pegadas en una reunión.', '12')
) AS O (codigo, nombre, descripcion, valor)
   ON D.par_codigo = O.codigo
WHEN NOT MATCHED THEN
    INSERT (par_codigo, par_nombre, par_descripcion, par_valor) VALUES (O.codigo, O.nombre, O.descripcion, O.valor);
PRINT 'Parámetros COMERCIAL_ registrados.'
GO

/* --------------------------------------------------- 9. Plan DEMO (no público)
   Copia las funcionalidades del plan FULL (todo incluido) y le pone los topes
   de la demo. Cada demo agrega, además, sus propias filas por cliente. */
DECLARE @ROOT INT = 1
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE plc_codigo = N'DEMO')
BEGIN
    INSERT [dbo].[Plan_Comercial] (plc_codigo, plc_nombre, plc_descripcion, plc_orden, plc_dias_gracia, plc_publico,
                                   plc_usuario_creacion, plc_fecha_creacion, plc_habilitado)
    VALUES (N'DEMO', N'Demo', N'Prueba acotada que crea el Centro Comercial. No se vende ni se publica.', 99, 0, 0, @ROOT, GETDATE(), 1)

    DECLARE @DEMO INT = SCOPE_IDENTITY(), @FULL INT = (SELECT plc_id FROM [dbo].[Plan_Comercial] WHERE plc_codigo = N'FULL')

    INSERT [dbo].[Plan_Comercial_Funcionalidad]
        (pcf_plan_comercial, pcf_funcionalidad, pcf_cliente, pcf_funcionalidad_tipo, pcf_incluida, pcf_limite,
         pcf_observacion, pcf_usuario_creacion, pcf_fecha_creacion, pcf_habilitado)
    SELECT @DEMO, p.pcf_funcionalidad, NULL, p.pcf_funcionalidad_tipo, 1,
           CASE f.fun_codigo WHEN N'LIMITE PLANTAS' THEN 1 WHEN N'LIMITE USUARIOS' THEN 2
                             WHEN N'LIMITE ACTIVOS' THEN 10 WHEN N'LIMITE ALMACENAMIENTO' THEN 1
                             WHEN N'SOPORTE TICKETS' THEN 2 ELSE p.pcf_limite END,
           N'Plan demo (bloque 455)', @ROOT, GETDATE(), 1
      FROM [dbo].[Plan_Comercial_Funcionalidad] p
      JOIN [dbo].[Funcionalidad] f ON f.fun_id = p.pcf_funcionalidad
     WHERE p.pcf_plan_comercial = @FULL AND p.pcf_cliente IS NULL AND p.pcf_habilitado = 1
    PRINT 'Plan DEMO creado.'
END
ELSE PRINT 'Plan DEMO ya existe.'
GO

/* ------------------------------------------------------------ 10. Permisos */
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()
MERGE [dbo].[Permiso] AS D
USING (VALUES
  ('VER CENTRO COMERCIAL',   'Ver el Centro Comercial',         'COMERCIAL', 1, 'Permite ver leads, demos, propuestas, contratos y clientes concretados en el Centro Comercial.'),
  ('GESTIONAR LEADS',        'Gestionar leads',                 'COMERCIAL', 1, 'Permite asignar ejecutivo, registrar actividad y reuniones, cambiar el estado y marcar perdido un lead.'),
  ('GESTIONAR DEMOS',        'Crear y gestionar demos',         'COMERCIAL', 1, 'Permite crear la demo de un lead (empresa, usuario y credenciales), extenderla y reenviar credenciales.'),
  ('GESTIONAR PROPUESTAS',   'Crear propuestas y contratos',    'COMERCIAL', 1, 'Permite crear y enviar propuestas, generar contratos, reenviarlos para firma y anularlos.')
) AS O (codigo, nombre, modulo, ambito, descripcion)
   ON D.prm_codigo = O.codigo
WHEN NOT MATCHED THEN
    INSERT (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion, prm_usuario_creacion, prm_fecha_creacion)
    VALUES (O.codigo, O.nombre, O.modulo, O.ambito, O.descripcion, @ROOT, @AHORA)
WHEN MATCHED THEN
    UPDATE SET D.prm_nombre = O.nombre, D.prm_descripcion = O.descripcion;

/* A los perfiles de plataforma que ya ven suscripciones (Root y Gerente
   Comercial): son quienes venden. Soporte no. */
INSERT  [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  PER.per_id, PRM.prm_id, @ROOT, @AHORA
FROM    [dbo].[Perfiles] PER
CROSS JOIN [dbo].[Permiso] PRM
WHERE   PER.per_nombre IN ('Root', 'Gerente Comercial') AND PER.per_cliente IS NULL
  AND   PRM.prm_codigo IN ('VER CENTRO COMERCIAL', 'GESTIONAR LEADS', 'GESTIONAR DEMOS', 'GESTIONAR PROPUESTAS')
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] PP WHERE PP.ppe_perfil = PER.per_id AND PP.ppe_permiso = PRM.prm_id)
PRINT 'Permisos comerciales asignados.'
GO

/* --------------------------------------------------------------- 11. Menú
   Un solo ítem nuevo, primero dentro de «Comercial». Las pantallas antiguas
   (Clientes, Planes, Suscripción…) quedan como están. */
DECLARE @COMERCIAL INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_nombre = N'Comercial' AND mnu_nivel = 2)

INSERT INTO [dbo].[Menus]
    ([mnu_nombre], [mnu_descripcion], [mnu_nivel], [mnu_padre], [mnu_orden]
    ,[mnu_link], [mnu_visible], [mnu_icon], [mnu_permiso], [mnu_ambito])
SELECT N'Centro Comercial', N'Del formulario web al cliente activo: leads, demos, propuestas y contratos', 3, @COMERCIAL, 0
      ,N'~/View/Comercial/CentroComercial.aspx', 1, N'mdi mdi-handshake-outline', p.[prm_id], 1
  FROM [dbo].[Permiso] p
 WHERE p.[prm_codigo] = N'VER CENTRO COMERCIAL'
   AND @COMERCIAL IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Menus] m WHERE m.[mnu_link] = N'~/View/Comercial/CentroComercial.aspx')
PRINT 'Menú Centro Comercial registrado (bloque 455).'
GO
