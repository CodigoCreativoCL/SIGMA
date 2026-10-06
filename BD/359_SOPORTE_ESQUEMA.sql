USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     MODULO SOPORTE (etapa a): mesa de ayuda, centro de ayuda
--                  y campanas. Tablas, catalogos, permisos, menus y tipos de
--                  alerta.
-- =============================================
-- Referencia visual y de comportamiento:
--   docs/rediseno-soporte/sigma-soporte-referencia.html
--
-- QUIEN ES "EL EQUIPO DE SOPORTE"
--   Root y el perfil de plataforma Soporte (per_id = 2). Los cuatro permisos
--   de gestion son de plataforma (prm_asignable_cliente = 0): un cliente no
--   puede darselos a su gente. Si mas adelante se quiere sumar otro perfil de
--   plataforma, se le marcan en Sistema > Perfiles (Perfil.aspx); no hay nada
--   escrito en codigo que diga "solo el perfil 2".
--
-- QUIEN REPORTA Y CONSULTA AYUDA
--   Todos: SOPORTE REPORTAR y AYUDA VER se entregan a todos los perfiles de
--   cliente que existen hoy y quedan asignables para los que se creen.
--
-- LAS NOTIFICACIONES VAN POR LA CAMPANA QUE YA EXISTE
--   No hay tabla de notificaciones nueva: cada aviso es una fila de Alerta
--   dirigida (ale_usuario_destinatario) con un tipo SOPORTE * o CAMPANA. Se
--   agregan dos columnas a Alerta para saber a que ticket o contenido lleva.
--
-- LOS EVENTOS DEL TICKET NO SE EDITAN
--   Soporte_Ticket_Evento es la trazabilidad: un trigger INSTEAD OF rechaza
--   cualquier UPDATE o DELETE. Si algo se dijo mal, se corrige con otro
--   evento.
--
-- ES IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. CATALOGOS DE SOPORTE
   ======================================================================== */

IF OBJECT_ID('dbo.Soporte_Estado') IS NULL
CREATE TABLE [dbo].[Soporte_Estado] (
    ses_codigo      VARCHAR(5)    NOT NULL CONSTRAINT PK_Soporte_Estado PRIMARY KEY,
    ses_nombre      NVARCHAR(60)  NOT NULL,
    ses_descripcion NVARCHAR(120) NULL,
    ses_tono        VARCHAR(10)   NOT NULL,   -- b azul, w ambar, c cian, s verde, n gris, d rojo
    ses_abierto     BIT           NOT NULL,   -- cuenta como pendiente
    ses_pausa_sla   BIT           NOT NULL CONSTRAINT DF_Soporte_Estado_Pausa DEFAULT (0),
    ses_orden       INT           NOT NULL)
GO

MERGE [dbo].[Soporte_Estado] AS t
USING (VALUES
    ('rep', N'Reportado',         N'Recién llegó',                 'b', 1, 0, 1),
    ('rev', N'En revisión',       N'Mesa de ayuda lo está viendo', 'b', 1, 0, 2),
    ('asg', N'Asignado',          N'Tiene responsable',            'b', 1, 0, 3),
    ('ana', N'En análisis',       N'Buscando la causa',            'w', 1, 0, 4),
    ('esp', N'Esperando usuario', N'Pausa el SLA',                 'c', 1, 1, 5),
    ('dev', N'En corrección',     N'Desarrollo lo corrige',        'w', 1, 0, 6),
    ('res', N'Resuelto',          N'Envía la encuesta',            's', 0, 0, 7),
    ('cer', N'Cerrado',           N'Sin más cambios',              'n', 0, 0, 8),
    ('rea', N'Reabierto',         N'Vuelve a abrirse',             'd', 1, 0, 9)
) AS s (codigo, nombre, descripcion, tono, abierto, pausa, orden)
ON t.ses_codigo = s.codigo
WHEN MATCHED THEN UPDATE SET ses_nombre = s.nombre, ses_descripcion = s.descripcion, ses_tono = s.tono,
                             ses_abierto = s.abierto, ses_pausa_sla = s.pausa, ses_orden = s.orden
WHEN NOT MATCHED THEN INSERT (ses_codigo, ses_nombre, ses_descripcion, ses_tono, ses_abierto, ses_pausa_sla, ses_orden)
                      VALUES (s.codigo, s.nombre, s.descripcion, s.tono, s.abierto, s.pausa, s.orden);
GO

IF OBJECT_ID('dbo.Soporte_Prioridad') IS NULL
CREATE TABLE [dbo].[Soporte_Prioridad] (
    spr_codigo      CHAR(1)       NOT NULL CONSTRAINT PK_Soporte_Prioridad PRIMARY KEY,
    spr_nombre      NVARCHAR(30)  NOT NULL,
    spr_descripcion NVARCHAR(120) NOT NULL,
    spr_horas_sla   INT           NOT NULL,
    spr_barras      INT           NOT NULL,
    spr_orden       INT           NOT NULL)
GO

MERGE [dbo].[Soporte_Prioridad] AS t
USING (VALUES
    ('c', N'Crítica', N'Toda la planta o un proceso está detenido', 4,  4, 1),
    ('a', N'Alta',    N'No puedo terminar una tarea',              12, 3, 2),
    ('m', N'Media',   N'Puedo seguir trabajando con dificultad',   24, 2, 3),
    ('b', N'Baja',    N'Es una duda o una mejora',                 72, 1, 4)
) AS s (codigo, nombre, descripcion, horas, barras, orden)
ON t.spr_codigo = s.codigo
WHEN MATCHED THEN UPDATE SET spr_nombre = s.nombre, spr_descripcion = s.descripcion, spr_horas_sla = s.horas,
                             spr_barras = s.barras, spr_orden = s.orden
WHEN NOT MATCHED THEN INSERT (spr_codigo, spr_nombre, spr_descripcion, spr_horas_sla, spr_barras, spr_orden)
                      VALUES (s.codigo, s.nombre, s.descripcion, s.horas, s.barras, s.orden);
GO

IF OBJECT_ID('dbo.Soporte_Categoria') IS NULL
CREATE TABLE [dbo].[Soporte_Categoria] (
    sca_codigo  VARCHAR(10)  NOT NULL CONSTRAINT PK_Soporte_Categoria PRIMARY KEY,
    sca_nombre  NVARCHAR(60) NOT NULL,
    sca_icono   VARCHAR(20)  NOT NULL,
    sca_orden   INT          NOT NULL)
GO

MERGE [dbo].[Soporte_Categoria] AS t
USING (VALUES
    ('error',  N'Error del sistema',  'warn',  1),
    ('func',   N'Problema funcional', 'gear',  2),
    ('acceso', N'Acceso/permisos',    'lock',  3),
    ('datos',  N'Datos incorrectos',  'list',  4),
    ('rend',   N'Rendimiento',        'gauge', 5),
    ('integ',  N'Integración',        'link',  6),
    ('sug',    N'Sugerencia',         'bulb',  7),
    ('otro',   N'Otro',               'more',  8)
) AS s (codigo, nombre, icono, orden)
ON t.sca_codigo = s.codigo
WHEN MATCHED THEN UPDATE SET sca_nombre = s.nombre, sca_icono = s.icono, sca_orden = s.orden
WHEN NOT MATCHED THEN INSERT (sca_codigo, sca_nombre, sca_icono, sca_orden) VALUES (s.codigo, s.nombre, s.icono, s.orden);
GO

IF OBJECT_ID('dbo.Soporte_Area') IS NULL
CREATE TABLE [dbo].[Soporte_Area] (
    sar_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Soporte_Area PRIMARY KEY,
    sar_nombre     NVARCHAR(60) NOT NULL,
    sar_orden      INT          NOT NULL,
    sar_habilitado BIT          NOT NULL CONSTRAINT DF_Soporte_Area_Hab DEFAULT (1))
GO

INSERT INTO [dbo].[Soporte_Area] (sar_nombre, sar_orden)
SELECT s.nombre, s.orden
FROM (VALUES (N'Mesa de Ayuda', 1), (N'Soporte funcional', 2), (N'Desarrollo', 3), (N'Infraestructura', 4)) s (nombre, orden)
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Soporte_Area] a WHERE a.sar_nombre = s.nombre)
GO


/* ========================================================================
   2. PROBLEMAS RECURRENTES (antes que el ticket: el ticket apunta aqui)
   ======================================================================== */

IF OBJECT_ID('dbo.Soporte_Recurrente') IS NULL
CREATE TABLE [dbo].[Soporte_Recurrente] (
    sre_id                  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Soporte_Recurrente PRIMARY KEY,
    sre_titulo              NVARCHAR(200) NOT NULL,
    sre_modulo              NVARCHAR(150) NULL,
    sre_submodulo           NVARCHAR(150) NULL,
    sre_pantalla            NVARCHAR(150) NULL,
    sre_seccion             NVARCHAR(150) NULL,
    sre_categoria           VARCHAR(10)   NULL CONSTRAINT FK_Soporte_Recurrente_Cat REFERENCES [dbo].[Soporte_Categoria](sca_codigo),
    sre_causa               NVARCHAR(500) NULL,
    sre_contenido           INT           NULL,   -- Ayuda_Contenido que lo explica (FK al final)
    sre_usuario_creacion    INT           NULL,
    sre_fecha_creacion      DATETIME      NOT NULL CONSTRAINT DF_Soporte_Recurrente_Fc DEFAULT ([dbo].[FNC_AHORA]()),
    sre_fecha_actualizacion DATETIME      NULL,
    sre_habilitado          BIT           NOT NULL CONSTRAINT DF_Soporte_Recurrente_Hab DEFAULT (1))
GO


/* ========================================================================
   3. TICKETS
   ======================================================================== */

IF OBJECT_ID('dbo.Soporte_Ticket') IS NULL
CREATE TABLE [dbo].[Soporte_Ticket] (
    stk_id                     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Soporte_Ticket PRIMARY KEY,
    stk_folio                  AS ('SUP-' + RIGHT('000000' + CAST(stk_id AS VARCHAR(10)), 6)) PERSISTED,
    stk_cliente                INT           NOT NULL CONSTRAINT FK_Soporte_Ticket_Cliente REFERENCES [dbo].[Cliente](cli_id),
    stk_cliente_instalacion    INT           NULL     CONSTRAINT FK_Soporte_Ticket_Planta  REFERENCES [dbo].[Cliente_Instalacion](cin_id),
    stk_usuario                INT           NOT NULL CONSTRAINT FK_Soporte_Ticket_Usuario REFERENCES [dbo].[Usuario](usu_id),
    stk_titulo                 NVARCHAR(200) NOT NULL,
    stk_descripcion            NVARCHAR(MAX) NULL,
    stk_categoria              VARCHAR(10)   NOT NULL CONSTRAINT FK_Soporte_Ticket_Cat    REFERENCES [dbo].[Soporte_Categoria](sca_codigo),
    stk_prioridad              CHAR(1)       NOT NULL CONSTRAINT FK_Soporte_Ticket_Prio   REFERENCES [dbo].[Soporte_Prioridad](spr_codigo),
    stk_estado                 VARCHAR(5)    NOT NULL CONSTRAINT FK_Soporte_Ticket_Estado REFERENCES [dbo].[Soporte_Estado](ses_codigo),
    stk_responsable            INT           NULL     CONSTRAINT FK_Soporte_Ticket_Resp   REFERENCES [dbo].[Usuario](usu_id),
    stk_area                   INT           NULL     CONSTRAINT FK_Soporte_Ticket_Area   REFERENCES [dbo].[Soporte_Area](sar_id),
    /* Contexto detectado: lo llena la pantalla, el usuario solo corrige
       pantalla y registro. */
    stk_modulo                 NVARCHAR(150) NULL,
    stk_submodulo              NVARCHAR(150) NULL,
    stk_pantalla               NVARCHAR(150) NULL,
    stk_seccion                NVARCHAR(150) NULL,
    stk_ruta                   NVARCHAR(400) NULL,
    stk_registro               NVARCHAR(200) NULL,
    stk_navegador              NVARCHAR(200) NULL,
    stk_perfil                 NVARCHAR(200) NULL,
    stk_recurrente             INT           NULL     CONSTRAINT FK_Soporte_Ticket_Recur  REFERENCES [dbo].[Soporte_Recurrente](sre_id),
    stk_contenido_sugerido     INT           NULL,
    /* SLA: los minutos en pausa se acumulan cada vez que sale de
       «Esperando usuario»; mientras esta ahi, stk_fecha_pausa dice desde
       cuando. */
    stk_sla_pausa_min          INT           NOT NULL CONSTRAINT DF_Soporte_Ticket_Pausa DEFAULT (0),
    stk_fecha_pausa            DATETIME      NULL,
    stk_fecha_primera_respuesta DATETIME     NULL,
    stk_fecha_resolucion       DATETIME      NULL,
    stk_fecha_cierre           DATETIME      NULL,
    stk_usuario_creacion       INT           NOT NULL,
    stk_fecha_creacion         DATETIME      NOT NULL CONSTRAINT DF_Soporte_Ticket_Fc DEFAULT ([dbo].[FNC_AHORA]()),
    stk_usuario_actualizacion  INT           NULL,
    stk_fecha_actualizacion    DATETIME      NOT NULL CONSTRAINT DF_Soporte_Ticket_Fa DEFAULT ([dbo].[FNC_AHORA]()),
    stk_habilitado             BIT           NOT NULL CONSTRAINT DF_Soporte_Ticket_Hab DEFAULT (1))
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Soporte_Ticket_Estado')
    CREATE INDEX IX_Soporte_Ticket_Estado ON [dbo].[Soporte_Ticket] (stk_estado, stk_fecha_actualizacion DESC)
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Soporte_Ticket_Usuario')
    CREATE INDEX IX_Soporte_Ticket_Usuario ON [dbo].[Soporte_Ticket] (stk_usuario, stk_fecha_actualizacion DESC)
GO

IF OBJECT_ID('dbo.Soporte_Ticket_Evento') IS NULL
CREATE TABLE [dbo].[Soporte_Ticket_Evento] (
    ste_id              INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Soporte_Ticket_Evento PRIMARY KEY,
    ste_ticket          INT           NOT NULL CONSTRAINT FK_Soporte_Evento_Ticket REFERENCES [dbo].[Soporte_Ticket](stk_id),
    /* rep reporte · com comentario · req pide informacion · file adjunto ·
       st cambio de estado · asg asignacion · int nota interna · res
       resolucion · fb encuesta · prio prioridad · sys sistema */
    ste_tipo            VARCHAR(5)    NOT NULL,
    ste_usuario         INT           NULL,       -- NULL = SIGMA
    ste_es_soporte      BIT           NOT NULL CONSTRAINT DF_Soporte_Evento_Sop DEFAULT (0),
    ste_interno         BIT           NOT NULL CONSTRAINT DF_Soporte_Evento_Int DEFAULT (0),
    ste_texto           NVARCHAR(MAX) NULL,
    ste_estado_desde    VARCHAR(5)    NULL,
    ste_estado_hasta    VARCHAR(5)    NULL,
    ste_destinatario    INT           NULL,       -- a quien se asigno
    ste_contenido       INT           NULL,       -- ayuda compartida en la respuesta
    ste_archivo         INT           NULL,
    ste_archivo_nombre  NVARCHAR(260) NULL,
    ste_archivo_byte    BIGINT        NULL,
    ste_fecha           DATETIME      NOT NULL CONSTRAINT DF_Soporte_Evento_F DEFAULT ([dbo].[FNC_AHORA]()))
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Soporte_Evento_Ticket')
    CREATE INDEX IX_Soporte_Evento_Ticket ON [dbo].[Soporte_Ticket_Evento] (ste_ticket, ste_id)
GO

/* La trazabilidad no se reescribe. */
CREATE OR ALTER TRIGGER [dbo].[TRG_Soporte_Ticket_Evento_Inmutable]
ON [dbo].[Soporte_Ticket_Evento]
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON
    RAISERROR(N'Los eventos de un ticket no se modifican ni se borran: se agrega otro evento.', 16, 1)
END
GO

IF OBJECT_ID('dbo.Soporte_Encuesta') IS NULL
CREATE TABLE [dbo].[Soporte_Encuesta] (
    sen_id          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Soporte_Encuesta PRIMARY KEY,
    sen_ticket      INT           NOT NULL CONSTRAINT FK_Soporte_Encuesta_Ticket REFERENCES [dbo].[Soporte_Ticket](stk_id),
    sen_respuesta   VARCHAR(10)   NOT NULL CONSTRAINT CK_Soporte_Encuesta_Resp CHECK (sen_respuesta IN ('si','parcial','no')),
    sen_estrellas   INT           NOT NULL CONSTRAINT CK_Soporte_Encuesta_Est CHECK (sen_estrellas BETWEEN 1 AND 5),
    sen_comentario  NVARCHAR(1000) NULL,
    sen_responsable INT           NULL,   -- quien lo resolvio (para el CSAT por persona)
    sen_usuario     INT           NOT NULL,
    sen_fecha       DATETIME      NOT NULL CONSTRAINT DF_Soporte_Encuesta_F DEFAULT ([dbo].[FNC_AHORA]()))
GO

/* «Sí, se resolvió» con la ayuda sugerida: un ticket que no se creo. */
IF OBJECT_ID('dbo.Soporte_Ticket_Evitado') IS NULL
CREATE TABLE [dbo].[Soporte_Ticket_Evitado] (
    stv_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Soporte_Ticket_Evitado PRIMARY KEY,
    stv_usuario    INT           NOT NULL,
    stv_cliente    INT           NOT NULL,
    stv_contenido  INT           NULL,
    stv_titulo     NVARCHAR(200) NULL,
    stv_modulo     NVARCHAR(150) NULL,
    stv_pantalla   NVARCHAR(150) NULL,
    stv_fecha      DATETIME      NOT NULL CONSTRAINT DF_Soporte_Evitado_F DEFAULT ([dbo].[FNC_AHORA]()))
GO

/* Hasta donde leyo cada persona: el punto azul de «con novedades». */
IF OBJECT_ID('dbo.Soporte_Ticket_Lectura') IS NULL
CREATE TABLE [dbo].[Soporte_Ticket_Lectura] (
    stl_ticket       INT      NOT NULL CONSTRAINT FK_Soporte_Lectura_Ticket REFERENCES [dbo].[Soporte_Ticket](stk_id),
    stl_usuario      INT      NOT NULL,
    stl_ultimo_evento INT     NOT NULL,
    stl_fecha        DATETIME NOT NULL CONSTRAINT DF_Soporte_Lectura_F DEFAULT ([dbo].[FNC_AHORA]()),
    CONSTRAINT PK_Soporte_Ticket_Lectura PRIMARY KEY (stl_ticket, stl_usuario))
GO


/* ========================================================================
   4. CENTRO DE AYUDA
   ======================================================================== */

/* Las pantallas de SIGMA para la vinculacion contextual, sacadas de Menus:
   Modulo (nivel 2) > Submodulo (nivel 3) > Pantalla (nivel 3 o 4). La
   seccion se escribe en el vinculo, porque Menus no la conoce. */
IF OBJECT_ID('dbo.Ayuda_Pantalla') IS NULL
CREATE TABLE [dbo].[Ayuda_Pantalla] (
    apa_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Ayuda_Pantalla PRIMARY KEY,
    apa_menu       INT           NULL,
    apa_link       NVARCHAR(500) NULL,
    apa_modulo     NVARCHAR(150) NOT NULL,
    apa_submodulo  NVARCHAR(150) NOT NULL,
    apa_pantalla   NVARCHAR(150) NOT NULL,
    apa_visible    BIT           NOT NULL CONSTRAINT DF_Ayuda_Pantalla_Vis DEFAULT (1),
    apa_habilitado BIT           NOT NULL CONSTRAINT DF_Ayuda_Pantalla_Hab DEFAULT (1))
GO

IF OBJECT_ID('dbo.Ayuda_Categoria') IS NULL
CREATE TABLE [dbo].[Ayuda_Categoria] (
    aca_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Ayuda_Categoria PRIMARY KEY,
    aca_nombre     NVARCHAR(100) NOT NULL,
    aca_modulo     NVARCHAR(150) NOT NULL,
    aca_icono      VARCHAR(20)   NOT NULL CONSTRAINT DF_Ayuda_Categoria_Ico DEFAULT ('folder'),
    aca_tono       VARCHAR(10)   NOT NULL CONSTRAINT DF_Ayuda_Categoria_Tono DEFAULT ('p'),
    aca_orden      INT           NOT NULL CONSTRAINT DF_Ayuda_Categoria_Ord DEFAULT (99),
    aca_habilitado BIT           NOT NULL CONSTRAINT DF_Ayuda_Categoria_Hab DEFAULT (1))
GO

IF OBJECT_ID('dbo.Ayuda_Contenido') IS NULL
CREATE TABLE [dbo].[Ayuda_Contenido] (
    ayc_id                  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Ayuda_Contenido PRIMARY KEY,
    ayc_tipo                VARCHAR(12)   NOT NULL CONSTRAINT CK_Ayuda_Contenido_Tipo CHECK (ayc_tipo IN ('capsula','video','manual','documento','guia','faq')),
    ayc_titulo              NVARCHAR(200) NOT NULL,
    ayc_descripcion         NVARCHAR(1000) NULL,
    ayc_objetivo            NVARCHAR(500) NULL,
    ayc_cuerpo              NVARCHAR(MAX) NULL,   -- texto de guias y FAQ
    ayc_formato             VARCHAR(10)   NULL,   -- MP4, PDF, DOCX, XLSX, PPTX, URL, Web
    ayc_duracion            VARCHAR(10)   NULL,   -- m:ss de videos
    ayc_paginas             INT           NULL,
    ayc_lectura             NVARCHAR(40)  NULL,
    ayc_archivo             INT           NULL,
    ayc_url                 NVARCHAR(600) NULL,
    ayc_estado              VARCHAR(12)   NOT NULL CONSTRAINT CK_Ayuda_Contenido_Estado CHECK (ayc_estado IN ('Publicado','Borrador','En revisión','Archivado')),
    ayc_version             VARCHAR(12)   NOT NULL CONSTRAINT DF_Ayuda_Contenido_Ver DEFAULT ('v1.0'),
    ayc_categoria           INT           NULL CONSTRAINT FK_Ayuda_Contenido_Cat REFERENCES [dbo].[Ayuda_Categoria](aca_id),
    /* Audiencia: NULL = todos. Si no, condiciones como las de campanas. */
    ayc_audiencia           NVARCHAR(200) NULL,
    ayc_audiencia_condiciones NVARCHAR(MAX) NULL,
    ayc_audiencia_union     VARCHAR(3)    NOT NULL CONSTRAINT DF_Ayuda_Contenido_Union DEFAULT ('AND'),
    ayc_tema                INT           NOT NULL CONSTRAINT DF_Ayuda_Contenido_Tema DEFAULT (0),
    ayc_recurrente          INT           NULL,
    ayc_usuario_creacion    INT           NOT NULL,
    ayc_fecha_creacion      DATETIME      NOT NULL CONSTRAINT DF_Ayuda_Contenido_Fc DEFAULT ([dbo].[FNC_AHORA]()),
    ayc_usuario_actualizacion INT         NULL,
    ayc_fecha_actualizacion DATETIME      NOT NULL CONSTRAINT DF_Ayuda_Contenido_Fa DEFAULT ([dbo].[FNC_AHORA]()),
    ayc_habilitado          BIT           NOT NULL CONSTRAINT DF_Ayuda_Contenido_Hab DEFAULT (1))
GO

IF OBJECT_ID('dbo.Ayuda_Contenido_Paso') IS NULL
CREATE TABLE [dbo].[Ayuda_Contenido_Paso] (
    acp_id        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Ayuda_Contenido_Paso PRIMARY KEY,
    acp_contenido INT           NOT NULL CONSTRAINT FK_Ayuda_Paso_Contenido REFERENCES [dbo].[Ayuda_Contenido](ayc_id),
    acp_orden     INT           NOT NULL,
    acp_titulo    NVARCHAR(200) NOT NULL,
    acp_minuto    VARCHAR(10)   NULL)
GO

IF OBJECT_ID('dbo.Ayuda_Contenido_Recomendacion') IS NULL
CREATE TABLE [dbo].[Ayuda_Contenido_Recomendacion] (
    acr_id        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Ayuda_Contenido_Recomendacion PRIMARY KEY,
    acr_contenido INT           NOT NULL CONSTRAINT FK_Ayuda_Rec_Contenido REFERENCES [dbo].[Ayuda_Contenido](ayc_id),
    acr_orden     INT           NOT NULL,
    acr_texto     NVARCHAR(400) NOT NULL)
GO

/* Donde aparece: Modulo > Submodulo > Pantalla > Seccion. Un contenido
   puede vincularse a varias pantallas. */
IF OBJECT_ID('dbo.Ayuda_Contenido_Vinculo') IS NULL
CREATE TABLE [dbo].[Ayuda_Contenido_Vinculo] (
    acv_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Ayuda_Contenido_Vinculo PRIMARY KEY,
    acv_contenido  INT           NOT NULL CONSTRAINT FK_Ayuda_Vinculo_Contenido REFERENCES [dbo].[Ayuda_Contenido](ayc_id),
    acv_modulo     NVARCHAR(150) NOT NULL,
    acv_submodulo  NVARCHAR(150) NULL,
    acv_pantalla   NVARCHAR(150) NULL,
    acv_seccion    NVARCHAR(150) NULL,
    acv_orden      INT           NOT NULL CONSTRAINT DF_Ayuda_Vinculo_Ord DEFAULT (1))
GO

/* Cada publicacion es una version con la foto completa del contenido. Volver
   a una version vieja publica una NUEVA con esa foto: el historial no se
   reescribe. */
IF OBJECT_ID('dbo.Ayuda_Contenido_Version') IS NULL
CREATE TABLE [dbo].[Ayuda_Contenido_Version] (
    aver_id        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Ayuda_Contenido_Version PRIMARY KEY,
    aver_contenido INT           NOT NULL CONSTRAINT FK_Ayuda_Version_Contenido REFERENCES [dbo].[Ayuda_Contenido](ayc_id),
    aver_version   VARCHAR(12)   NOT NULL,
    aver_nota      NVARCHAR(400) NULL,
    aver_estado    VARCHAR(12)   NOT NULL,
    aver_archivo   INT           NULL,
    aver_foto      NVARCHAR(MAX) NOT NULL,   -- JSON del contenido, pasos, recomendaciones y vinculos
    aver_usuario   INT           NOT NULL,
    aver_fecha     DATETIME      NOT NULL CONSTRAINT DF_Ayuda_Version_F DEFAULT ([dbo].[FNC_AHORA]()))
GO

IF OBJECT_ID('dbo.Ayuda_Vista') IS NULL
CREATE TABLE [dbo].[Ayuda_Vista] (
    avs_id        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Ayuda_Vista PRIMARY KEY,
    avs_contenido INT          NOT NULL CONSTRAINT FK_Ayuda_Vista_Contenido REFERENCES [dbo].[Ayuda_Contenido](ayc_id),
    avs_usuario   INT          NOT NULL,
    avs_cliente   INT          NULL,
    avs_tipo      VARCHAR(12)  NOT NULL,   -- vista · descarga · reproduccion · completo
    avs_origen    VARCHAR(20)  NULL,       -- centro · contextual · sugerencia · ticket · campana
    avs_fecha     DATETIME     NOT NULL CONSTRAINT DF_Ayuda_Vista_F DEFAULT ([dbo].[FNC_AHORA]()))
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ayuda_Vista_Contenido')
    CREATE INDEX IX_Ayuda_Vista_Contenido ON [dbo].[Ayuda_Vista] (avs_contenido, avs_fecha)
GO

IF OBJECT_ID('dbo.Ayuda_Valoracion') IS NULL
CREATE TABLE [dbo].[Ayuda_Valoracion] (
    ava_id        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Ayuda_Valoracion PRIMARY KEY,
    ava_contenido INT      NOT NULL CONSTRAINT FK_Ayuda_Valoracion_Contenido REFERENCES [dbo].[Ayuda_Contenido](ayc_id),
    ava_usuario   INT      NOT NULL,
    ava_util      BIT      NOT NULL,
    ava_estrellas INT      NOT NULL,
    ava_fecha     DATETIME NOT NULL CONSTRAINT DF_Ayuda_Valoracion_F DEFAULT ([dbo].[FNC_AHORA]()),
    CONSTRAINT UQ_Ayuda_Valoracion UNIQUE (ava_contenido, ava_usuario))
GO

IF OBJECT_ID('dbo.Ayuda_Busqueda') IS NULL
CREATE TABLE [dbo].[Ayuda_Busqueda] (
    abu_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Ayuda_Busqueda PRIMARY KEY,
    abu_texto      NVARCHAR(200) NOT NULL,
    abu_resultados INT           NOT NULL,
    abu_usuario    INT           NOT NULL,
    abu_cliente    INT           NULL,
    abu_fecha      DATETIME      NOT NULL CONSTRAINT DF_Ayuda_Busqueda_F DEFAULT ([dbo].[FNC_AHORA]()))
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Soporte_Recurrente_Contenido')
    ALTER TABLE [dbo].[Soporte_Recurrente] ADD CONSTRAINT FK_Soporte_Recurrente_Contenido
        FOREIGN KEY (sre_contenido) REFERENCES [dbo].[Ayuda_Contenido](ayc_id)
GO


/* ========================================================================
   5. CAMPANAS
   ======================================================================== */

IF OBJECT_ID('dbo.Campana') IS NULL
CREATE TABLE [dbo].[Campana] (
    cam_id                  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Campana PRIMARY KEY,
    cam_tipo                VARCHAR(12)   NOT NULL,   -- anuncio novedad mant tutorial importante comunicado consejo
    cam_titulo              NVARCHAR(70)  NOT NULL,
    cam_descripcion         NVARCHAR(220) NULL,
    cam_estado              VARCHAR(12)   NOT NULL CONSTRAINT CK_Campana_Estado CHECK (cam_estado IN ('borrador','programada','activa','pausada','finalizada')),
    cam_medio               VARCHAR(10)   NOT NULL CONSTRAINT DF_Campana_Medio DEFAULT ('imagen'),
    cam_tema                INT           NOT NULL CONSTRAINT DF_Campana_Tema DEFAULT (0),
    cam_archivo             INT           NULL,       -- imagen o video subido
    cam_formatos            VARCHAR(40)   NOT NULL CONSTRAINT DF_Campana_Fmt DEFAULT ('banner'),
    cam_donde               VARCHAR(10)   NOT NULL CONSTRAINT DF_Campana_Donde DEFAULT ('login'),
    cam_donde_modulo        NVARCHAR(150) NULL,
    cam_cerrable            BIT           NOT NULL CONSTRAINT DF_Campana_Cerrable DEFAULT (1),
    cam_confirmar           BIT           NOT NULL CONSTRAINT DF_Campana_Confirmar DEFAULT (0),
    cam_cta_accion          VARCHAR(12)   NOT NULL CONSTRAINT DF_Campana_CtaA DEFAULT ('nada'),
    cam_cta_texto           NVARCHAR(60)  NULL,
    cam_cta_destino         NVARCHAR(600) NULL,
    cam_contenido           INT           NULL CONSTRAINT FK_Campana_Contenido REFERENCES [dbo].[Ayuda_Contenido](ayc_id),
    cam_union               VARCHAR(3)    NOT NULL CONSTRAINT DF_Campana_Union DEFAULT ('AND'),
    cam_frecuencia          VARCHAR(10)   NOT NULL CONSTRAINT DF_Campana_Freq DEFAULT ('usuario'),
    cam_cada_dias           INT           NULL,
    cam_desde               DATETIME      NULL,
    cam_hasta               DATETIME      NULL,
    cam_alcance             INT           NOT NULL CONSTRAINT DF_Campana_Alcance DEFAULT (0),
    cam_usuario_creacion    INT           NOT NULL,
    cam_fecha_creacion      DATETIME      NOT NULL CONSTRAINT DF_Campana_Fc DEFAULT ([dbo].[FNC_AHORA]()),
    cam_usuario_actualizacion INT         NULL,
    cam_fecha_actualizacion DATETIME      NOT NULL CONSTRAINT DF_Campana_Fa DEFAULT ([dbo].[FNC_AHORA]()),
    cam_habilitado          BIT           NOT NULL CONSTRAINT DF_Campana_Hab DEFAULT (1))
GO

IF OBJECT_ID('dbo.Campana_Condicion') IS NULL
CREATE TABLE [dbo].[Campana_Condicion] (
    ccn_id       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Campana_Condicion PRIMARY KEY,
    ccn_campana  INT           NOT NULL CONSTRAINT FK_Campana_Condicion_Campana REFERENCES [dbo].[Campana](cam_id),
    ccn_orden    INT           NOT NULL,
    ccn_campo    VARCHAR(20)   NOT NULL,   -- estado perfil cliente planta usuario modulo
    ccn_operador VARCHAR(2)    NOT NULL CONSTRAINT CK_Campana_Condicion_Op CHECK (ccn_operador IN ('=','!=')),
    ccn_valor    NVARCHAR(200) NOT NULL)
GO

IF OBJECT_ID('dbo.Campana_Segmento') IS NULL
CREATE TABLE [dbo].[Campana_Segmento] (
    csg_id          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Campana_Segmento PRIMARY KEY,
    csg_nombre      NVARCHAR(100) NOT NULL,
    csg_union       VARCHAR(3)    NOT NULL,
    csg_condiciones NVARCHAR(MAX) NOT NULL,   -- [{"campo":"perfil","op":"=","valor":"Bodeguero"}]
    csg_usuario     INT           NOT NULL,
    csg_fecha       DATETIME      NOT NULL CONSTRAINT DF_Campana_Segmento_F DEFAULT ([dbo].[FNC_AHORA]()),
    csg_habilitado  BIT           NOT NULL CONSTRAINT DF_Campana_Segmento_Hab DEFAULT (1))
GO

/* Una fila por persona y campana: cuando la vio, cuantas veces, si toco el
   boton, si la cerro y si confirmo lectura. */
IF OBJECT_ID('dbo.Campana_Entrega') IS NULL
CREATE TABLE [dbo].[Campana_Entrega] (
    cen_id                INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Campana_Entrega PRIMARY KEY,
    cen_campana           INT      NOT NULL CONSTRAINT FK_Campana_Entrega_Campana REFERENCES [dbo].[Campana](cam_id),
    cen_usuario           INT      NOT NULL,
    cen_cliente           INT      NOT NULL,
    cen_veces             INT      NOT NULL CONSTRAINT DF_Campana_Entrega_Veces DEFAULT (0),
    cen_fecha_primera     DATETIME NULL,
    cen_fecha_ultima      DATETIME NULL,
    cen_fecha_interaccion DATETIME NULL,
    cen_fecha_descarte    DATETIME NULL,
    cen_fecha_confirmacion DATETIME NULL,
    cen_alerta            INT      NULL,
    CONSTRAINT UQ_Campana_Entrega UNIQUE (cen_campana, cen_usuario, cen_cliente))
GO


/* ========================================================================
   6. ALERTA: a que ticket o contenido lleva el aviso
   ======================================================================== */

IF COL_LENGTH('dbo.Alerta', 'ale_soporte_ticket') IS NULL
    ALTER TABLE [dbo].[Alerta] ADD ale_soporte_ticket INT NULL
GO
IF COL_LENGTH('dbo.Alerta', 'ale_ayuda_contenido') IS NULL
    ALTER TABLE [dbo].[Alerta] ADD ale_ayuda_contenido INT NULL
GO
IF COL_LENGTH('dbo.Alerta', 'ale_campana') IS NULL
    ALTER TABLE [dbo].[Alerta] ADD ale_campana INT NULL
GO


/* ========================================================================
   7. PERMISOS
   ======================================================================== */

DECLARE @P TABLE (codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  descripcion NVARCHAR(400) COLLATE DATABASE_DEFAULT,
                  ambito INT, asignable_cliente BIT)

INSERT INTO @P VALUES
    (N'SOPORTE REPORTAR',     N'Reportar problemas',                N'Reporta un problema desde cualquier pantalla y sigue sus respuestas en «Mis problemas».', 3, 1),
    (N'AYUDA VER',            N'Consultar el centro de ayuda',      N'Ve cápsulas, manuales y la ayuda contextual de cada pantalla.',                          3, 1),
    (N'SOPORTE GESTIONAR',    N'Atender la mesa de ayuda',          N'Ve y atiende los problemas de todos los clientes: asigna, responde y resuelve.',         1, 0),
    (N'AYUDA ADMINISTRAR',    N'Administrar el centro de ayuda',    N'Crea, versiona y vincula cápsulas, videos y documentos.',                                 1, 0),
    (N'CAMPANAS ADMINISTRAR', N'Administrar campañas',              N'Crea y publica campañas segmentadas.',                                                    1, 0),
    (N'SOPORTE ANALITICA',    N'Ver la analítica de soporte',       N'Indicadores de la mesa de ayuda y del centro de ayuda.',                                   1, 0)

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario, prm_asignable_cliente)
SELECT  p.codigo, p.nombre, N'SOPORTE', p.ambito, p.descripcion, 1, [dbo].[FNC_AHORA](), 1, 0, p.asignable_cliente
FROM    @P p
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] x WHERE x.prm_codigo = p.codigo)

/* El equipo de soporte: el perfil de plataforma Soporte (2). Root no
   necesita filas: FNC_USUARIO_TIENE_PERMISO lo deja pasar siempre. */
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  2, pr.prm_id, 1, [dbo].[FNC_AHORA]()
FROM    [dbo].[Permiso] pr
WHERE   pr.prm_codigo IN (SELECT codigo FROM @P)
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = 2 AND x.ppe_permiso = pr.prm_id)

/* Reportar y consultar ayuda: todos los perfiles de cliente y los de
   plataforma que no son soporte (Gerente Comercial). */
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  pe.per_id, pr.prm_id, 1, [dbo].[FNC_AHORA]()
FROM    [dbo].[Perfiles] pe
CROSS JOIN [dbo].[Permiso] pr
WHERE   pr.prm_codigo IN (N'SOPORTE REPORTAR', N'AYUDA VER')
  AND   pe.per_id NOT IN (1, 2)
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pe.per_id AND x.ppe_permiso = pr.prm_id)

DECLARE @N INT
SELECT @N = COUNT(*) FROM [dbo].[Permiso] WHERE prm_codigo IN (SELECT codigo FROM @P)
PRINT '--- Permisos de Soporte: ' + LTRIM(STR(@N)) + ' (esperado 6)'
GO


/* ========================================================================
   8. MENUS: Soporte (nivel 2) y sus pantallas
   ======================================================================== */

DECLARE @RAIZ INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_nivel = 1 AND mnu_nombre COLLATE DATABASE_DEFAULT = N'Menus')

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_nivel = 2 AND mnu_padre = @RAIZ AND mnu_nombre COLLATE DATABASE_DEFAULT = N'Soporte')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Soporte', N'Mesa de ayuda, centro de ayuda y campañas', 2, @RAIZ, 10, N'#', 1, N'mdi mdi-lifebuoy', NULL, 1)

DECLARE @SOP INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_nivel = 2 AND mnu_padre = @RAIZ AND mnu_nombre COLLATE DATABASE_DEFAULT = N'Soporte')

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_padre = @SOP AND mnu_nombre COLLATE DATABASE_DEFAULT = N'Analítica')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES (N'Analítica', N'Analítica de soporte y del centro de ayuda', 3, @SOP, 9, N'#', 1, N'mdi mdi-chart-line', NULL, 1)

DECLARE @ANA INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_padre = @SOP AND mnu_nombre COLLATE DATABASE_DEFAULT = N'Analítica')

DECLARE @M TABLE (nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT, link NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  nivel INT, padre INT, orden INT, visible BIT, icono NVARCHAR(100) COLLATE DATABASE_DEFAULT,
                  permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)

INSERT INTO @M VALUES
    (N'Inicio de soporte',          N'~/View/Soporte/Inicio.aspx',                3, @SOP, 1,  1, N'mdi mdi-home-outline',           N'SOPORTE GESTIONAR'),
    (N'Problemas detectados',       N'~/View/Soporte/Problemas.aspx',             3, @SOP, 2,  1, N'mdi mdi-inbox-outline',          N'SOPORTE GESTIONAR'),
    (N'Mis problemas',              N'~/View/Soporte/MisProblemas.aspx',          3, @SOP, 3,  1, N'mdi mdi-flag-outline',           N'SOPORTE REPORTAR'),
    (N'Problema (detalle)',         N'~/View/Soporte/Problema.aspx',              3, @SOP, 90, 0, NULL,                              N'SOPORTE REPORTAR'),
    (N'Campañas',                   N'~/View/Soporte/Campanas/Campanas.aspx',     3, @SOP, 4,  1, N'mdi mdi-bullhorn-outline',       N'CAMPANAS ADMINISTRAR'),
    (N'Campaña (asistente)',        N'~/View/Soporte/Campanas/Campana.aspx',      3, @SOP, 91, 0, NULL,                              N'CAMPANAS ADMINISTRAR'),
    (N'Centro de ayuda',            N'~/View/Soporte/Ayuda/Centro.aspx',          3, @SOP, 5,  1, N'mdi mdi-book-open-outline',      N'AYUDA VER'),
    (N'Biblioteca de ayuda',        N'~/View/Soporte/Ayuda/Biblioteca.aspx',      3, @SOP, 6,  1, N'mdi mdi-bookshelf',              N'AYUDA VER'),
    (N'Categorías de ayuda',        N'~/View/Soporte/Ayuda/Categorias.aspx',      3, @SOP, 7,  1, N'mdi mdi-folder-outline',         N'AYUDA ADMINISTRAR'),
    (N'Contenido de ayuda (detalle)', N'~/View/Soporte/Ayuda/Contenido.aspx',     3, @SOP, 92, 0, NULL,                              N'AYUDA VER'),
    (N'Contenido de ayuda (asistente)', N'~/View/Soporte/Ayuda/ContenidoForm.aspx', 3, @SOP, 93, 0, NULL,                            N'AYUDA ADMINISTRAR'),
    (N'Soporte',                    N'~/View/Soporte/Analitica/Soporte.aspx',     4, @ANA, 1,  1, N'mdi mdi-chart-box-outline',      N'SOPORTE ANALITICA'),
    (N'Centro de ayuda',            N'~/View/Soporte/Analitica/Ayuda.aspx',       4, @ANA, 2,  1, N'mdi mdi-chart-areaspline',       N'SOPORTE ANALITICA')

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden,
                           mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
SELECT  m.nombre, m.nombre, m.nivel, m.padre, m.orden, m.link, m.visible, m.icono,
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = m.permiso), 1
FROM    @M m
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Menus] x WHERE x.mnu_link COLLATE DATABASE_DEFAULT = m.link)

DECLARE @N INT
SELECT @N = COUNT(*) FROM [dbo].[Menus] WHERE mnu_link COLLATE DATABASE_DEFAULT LIKE N'~/View/Soporte/%'
PRINT '--- Menus de Soporte: ' + LTRIM(STR(@N)) + ' (esperado 13)'
GO


/* ========================================================================
   9. TIPOS DE ALERTA (la campana de siempre)
   ======================================================================== */

DECLARE @A TABLE (codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT, nombre NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  icono NVARCHAR(100) COLLATE DATABASE_DEFAULT, ficha NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  columna NVARCHAR(100) COLLATE DATABASE_DEFAULT)
INSERT INTO @A VALUES
    (N'SOPORTE RESPUESTA',   N'Soporte respondió tu problema',     N'mdi mdi-message-reply-text-outline', N'~/View/Soporte/Problema.aspx', N'ale_soporte_ticket'),
    (N'SOPORTE INFORMACION', N'Soporte te pidió información',      N'mdi mdi-help-circle-outline',        N'~/View/Soporte/Problema.aspx', N'ale_soporte_ticket'),
    (N'SOPORTE ESTADO',      N'Tu problema cambió de estado',      N'mdi mdi-swap-horizontal',            N'~/View/Soporte/Problema.aspx', N'ale_soporte_ticket'),
    (N'SOPORTE RESUELTO',    N'Problema resuelto: ¿se solucionó?', N'mdi mdi-check-circle-outline',       N'~/View/Soporte/Problema.aspx', N'ale_soporte_ticket'),
    (N'SOPORTE ASIGNADO',    N'Te asignaron un problema',          N'mdi mdi-account-arrow-left-outline', N'~/View/Soporte/Problema.aspx', N'ale_soporte_ticket'),
    (N'SOPORTE COMENTARIO',  N'El usuario respondió',              N'mdi mdi-comment-text-outline',       N'~/View/Soporte/Problema.aspx', N'ale_soporte_ticket'),
    (N'SOPORTE REABIERTO',   N'Problema reabierto',                N'mdi mdi-restore-alert',              N'~/View/Soporte/Problema.aspx', N'ale_soporte_ticket'),
    (N'AYUDA NUEVA',         N'Nuevo contenido de ayuda',          N'mdi mdi-book-open-variant',          N'~/View/Soporte/Ayuda/Contenido.aspx', N'ale_ayuda_contenido'),
    (N'CAMPANA',             N'Aviso de SIGMA',                    N'mdi mdi-bullhorn-outline',           NULL, NULL)

DECLARE @ORD INT = (SELECT ISNULL(MAX(alt_orden), 0) FROM [dbo].[Alerta_Tipo])

INSERT INTO [dbo].[Alerta_Tipo] (alt_codigo, alt_nombre, alt_orden, alt_habilitado, alt_permiso, alt_icono,
                                 alt_menu_link, alt_ficha_link, alt_ficha_id_columna)
SELECT  a.codigo, a.nombre, @ORD + ROW_NUMBER() OVER (ORDER BY a.codigo), 1, NULL, a.icono, NULL, a.ficha, a.columna
FROM    @A a
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] x WHERE x.alt_codigo COLLATE DATABASE_DEFAULT = a.codigo)

DECLARE @N INT
SELECT @N = COUNT(*) FROM [dbo].[Alerta_Tipo] WHERE alt_codigo IN (SELECT codigo FROM @A)
PRINT '--- Tipos de alerta de Soporte: ' + LTRIM(STR(@N)) + ' (esperado 9)'
GO


/* ========================================================================
   10. PANTALLAS PARA LA AYUDA CONTEXTUAL Y CATEGORIAS INICIALES
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPS_AYUDA_PANTALLA_SINCRONIZAR]
AS
SET NOCOUNT ON
    /* Modulo = nivel 2 · Submodulo = nivel 3 · Pantalla = nivel 4, o la
       misma del nivel 3 cuando esa ya es una pagina. Solo paginas web
       (~/View/...), no las de la app. */
    ;WITH P AS (
        SELECT  m3.mnu_id, m3.mnu_link, m2.mnu_nombre AS modulo, m3.mnu_nombre AS submodulo, m3.mnu_nombre AS pantalla, m3.mnu_visible AS visible
        FROM    [dbo].[Menus] m3
        JOIN    [dbo].[Menus] m2 ON m2.mnu_id = m3.mnu_padre AND m2.mnu_nivel = 2
        WHERE   m3.mnu_nivel = 3 AND m3.mnu_link LIKE N'~/View/%'
        UNION ALL
        SELECT  m4.mnu_id, m4.mnu_link, m2.mnu_nombre, m3.mnu_nombre, m4.mnu_nombre, m4.mnu_visible
        FROM    [dbo].[Menus] m4
        JOIN    [dbo].[Menus] m3 ON m3.mnu_id = m4.mnu_padre AND m3.mnu_nivel = 3
        JOIN    [dbo].[Menus] m2 ON m2.mnu_id = m3.mnu_padre AND m2.mnu_nivel = 2
        WHERE   m4.mnu_nivel = 4 AND m4.mnu_link LIKE N'~/View/%'
    )
    MERGE [dbo].[Ayuda_Pantalla] AS t
    USING P AS s ON t.apa_menu = s.mnu_id
    WHEN MATCHED THEN UPDATE SET apa_link = s.mnu_link, apa_modulo = s.modulo, apa_submodulo = s.submodulo,
                                 apa_pantalla = s.pantalla, apa_visible = s.visible, apa_habilitado = 1
    WHEN NOT MATCHED BY TARGET THEN INSERT (apa_menu, apa_link, apa_modulo, apa_submodulo, apa_pantalla, apa_visible)
                                    VALUES (s.mnu_id, s.mnu_link, s.modulo, s.submodulo, s.pantalla, s.visible)
    WHEN NOT MATCHED BY SOURCE THEN UPDATE SET apa_habilitado = 0;
GO

EXEC [dbo].[UPS_AYUDA_PANTALLA_SINCRONIZAR]
GO

INSERT INTO [dbo].[Ayuda_Categoria] (aca_nombre, aca_modulo, aca_icono, aca_tono, aca_orden)
SELECT  s.nombre, s.modulo, s.icono, s.tono, s.orden
FROM (VALUES
    (N'Inventario',               N'Inventario',               'box',    'p', 1),
    (N'Control de activos',       N'Control de activos',       'gear',   'c', 2),
    (N'Centro de Mantenimiento',  N'Centro de Mantenimiento',  'wrench', 'b', 3),
    (N'Cliente',                  N'Cliente',                  'users',  's', 4),
    (N'Terceros',                 N'Terceros',                 'building','w', 5),
    (N'SIGMA AI',                 N'SIGMA AI',                 'spark',  'p', 6),
    (N'Utilidades',               N'Utilidades',               'layers', 'n', 7),
    (N'Soporte',                  N'Soporte',                  'help',   'n', 8)
) s (nombre, modulo, icono, tono, orden)
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Ayuda_Categoria] c WHERE c.aca_modulo = s.modulo)
GO

DECLARE @N INT
SELECT @N = COUNT(*) FROM [dbo].[Ayuda_Pantalla] WHERE apa_habilitado = 1
PRINT '--- Pantallas para la ayuda contextual: ' + LTRIM(STR(@N))
GO
