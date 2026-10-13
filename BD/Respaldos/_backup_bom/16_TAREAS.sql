﻿﻿USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  20-08-2026
-- DESCRIPTION:     D8 -- TAREAS: EL TRABAJO QUE NO ES UNA ORDEN DE TRABAJO.
-- =============================================
-- Ver SIGMA_MODELO_LOGICO_v2.md §8.8
-- ORDEN: despues de 15_CHECKLIST.sql
--
-- POR QUE EXISTE TAREA SI TODO TERMINA SIENDO UNA OT
--   Porque no todo trabajo toca una maquina. "Revisar el extintor del
--   pasillo", "ordenar la bodega", "sacar fotos de los medidores de la
--   linea 3" son trabajo real, programable y verificable, pero no tienen
--   activo, no consumen repuestos, no paran produccion y no alimentan
--   MTBF. Meterlos en Orden_Trabajo contaminaria todos los indicadores
--   de mantenimiento con trabajo que no es mantenimiento.
--
--   Cuando una tarea SI resulta en intervencion sobre una maquina, se
--   crea una OT y toc_orden_trabajo las enlaza. La tarea no se convierte:
--   se relaciona. Asi el que la pidio ve que se resolvio, y el indicador
--   de mantenimiento solo cuenta la OT.
--
-- LA TAREA TAMPOCO TIENE RECURRENCIA PROPIA
--   Tarea_Programacion apunta a Programacion. Tercer consumidor del mismo
--   motor. El caso "una tarea con cuatro fechas" es una Programacion
--   FECHA UNICA con cuatro filas en Programacion_Fecha -- no requiere
--   nada especial aqui.
--
-- IDEMPOTENTE: se puede ejecutar las veces que sea.
-- =============================================


/* ========================================================================
   1. TAREA_CATEGORIA (tca) -- catalogo por cliente

      No es un catalogo global: cada planta clasifica su trabajo no-OT
      con las categorias que le sirven. Hamburgo usara "Aseo tecnico",
      "Seguridad", "Inventario"; otro cliente usara otras.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tarea_Categoria]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Tarea_Categoria]
    (
        [tca_id]                        INT             NOT NULL IDENTITY(1,1),
        [tca_cliente]                   INT             NULL,       -- NULL = categoria global de SIGMA
        [tca_codigo]                    NVARCHAR(50)    NOT NULL,
        [tca_nombre]                    NVARCHAR(200)   NOT NULL,
        [tca_color]                     NVARCHAR(20)    NULL,       -- para el calendario del planificador
        [tca_orden]                     INT             NULL,
        [tca_usuario_creacion]          INT             NOT NULL,
        [tca_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_TCA_FECHA_CREACION DEFAULT GETDATE(),
        [tca_usuario_actualizacion]     INT             NULL,
        [tca_fecha_actualizacion]       DATETIME        NULL,
        [tca_habilitado]                BIT             NOT NULL CONSTRAINT DF_TCA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_TAREA_CATEGORIA PRIMARY KEY CLUSTERED ([tca_id] ASC),
        CONSTRAINT FK_TCA_CLIENTE FOREIGN KEY ([tca_cliente]) REFERENCES [dbo].[Cliente] ([cli_id])
    )
    -- UNIQUE filtrado: el catalogo global (cliente NULL) tiene su propio espacio de codigos.
    CREATE UNIQUE NONCLUSTERED INDEX UX_TCA_CLIENTE_CODIGO
        ON [dbo].[Tarea_Categoria] ([tca_cliente], [tca_codigo]) WHERE [tca_cliente] IS NOT NULL
    CREATE UNIQUE NONCLUSTERED INDEX UX_TCA_GLOBAL_CODIGO
        ON [dbo].[Tarea_Categoria] ([tca_codigo]) WHERE [tca_cliente] IS NULL
    PRINT 'Tabla Tarea_Categoria creada correctamente.'
END
ELSE PRINT 'Tabla Tarea_Categoria ya existe.'
GO


/* ========================================================================
   2. TAREA (tar) -- la definicion

      tar_activo es NULL casi siempre, y esa es la diferencia con una OT.
      Cuando NO es NULL, la tarea es una rutina asociada a una maquina que
      no justifica abrir una orden -- por ejemplo, tomar la lectura del
      horometro.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tarea]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Tarea]
    (
        [tar_id]                        INT             NOT NULL IDENTITY(1,1),
        [tar_cliente]                   INT             NOT NULL,
        [tar_cliente_instalacion]       INT             NULL,
        [tar_instalacion_area]          INT             NULL,
        [tar_tarea_categoria]           INT             NULL,
        [tar_activo]                    INT             NULL,
        [tar_codigo]                    NVARCHAR(50)    NOT NULL,
        [tar_titulo]                    NVARCHAR(200)   NOT NULL,
        [tar_descripcion]               NVARCHAR(MAX)   NULL,
        [tar_tarea_prioridad]           INT             NOT NULL,
        [tar_duracion_estimada_minuto]  INT             NULL,
        [tar_requiere_evidencia]        BIT             NOT NULL CONSTRAINT DF_TAR_EVIDENCIA DEFAULT 0,
        [tar_usuario_creacion]          INT             NOT NULL,
        [tar_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_TAR_FECHA_CREACION DEFAULT GETDATE(),
        [tar_usuario_actualizacion]     INT             NULL,
        [tar_fecha_actualizacion]       DATETIME        NULL,
        [tar_habilitado]                BIT             NOT NULL CONSTRAINT DF_TAR_HABILITADO DEFAULT 1,

        CONSTRAINT PK_TAREA PRIMARY KEY CLUSTERED ([tar_id] ASC),
        CONSTRAINT FK_TAR_CLIENTE     FOREIGN KEY ([tar_cliente])             REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_TAR_INSTALACION FOREIGN KEY ([tar_cliente_instalacion]) REFERENCES [dbo].[Cliente_Instalacion] ([cin_id]),
        CONSTRAINT FK_TAR_AREA        FOREIGN KEY ([tar_instalacion_area])    REFERENCES [dbo].[Instalacion_Area] ([iar_id]),
        CONSTRAINT FK_TAR_CATEGORIA   FOREIGN KEY ([tar_tarea_categoria])     REFERENCES [dbo].[Tarea_Categoria] ([tca_id]),
        CONSTRAINT FK_TAR_ACTIVO      FOREIGN KEY ([tar_activo])              REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_TAR_PRIORIDAD   FOREIGN KEY ([tar_tarea_prioridad])     REFERENCES [dbo].[Tarea_Prioridad] ([tpa_id]),
        CONSTRAINT UX_TAR_CLIENTE_CODIGO UNIQUE ([tar_cliente], [tar_codigo])
    )
    PRINT 'Tabla Tarea creada correctamente.'
END
ELSE PRINT 'Tabla Tarea ya existe.'
GO


/* ========================================================================
   3. TAREA_PROGRAMACION (tpr) -- enganche al motor unico
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tarea_Programacion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Tarea_Programacion]
    (
        [tpr_id]                        INT         NOT NULL IDENTITY(1,1),
        [tpr_tarea]                     INT         NOT NULL,
        [tpr_programacion]              INT         NOT NULL,
        [tpr_usuario_responsable]       INT         NULL,
        [tpr_grupo_trabajo]             INT         NULL,
        [tpr_usuario_creacion]          INT         NOT NULL,
        [tpr_fecha_creacion]            DATETIME    NOT NULL CONSTRAINT DF_TPR_FECHA_CREACION DEFAULT GETDATE(),
        [tpr_usuario_actualizacion]     INT         NULL,
        [tpr_fecha_actualizacion]       DATETIME    NULL,
        [tpr_habilitado]                BIT         NOT NULL CONSTRAINT DF_TPR_HABILITADO DEFAULT 1,

        CONSTRAINT PK_TAREA_PROGRAMACION PRIMARY KEY CLUSTERED ([tpr_id] ASC),
        CONSTRAINT FK_TPR_TAREA        FOREIGN KEY ([tpr_tarea])               REFERENCES [dbo].[Tarea] ([tar_id]),
        CONSTRAINT FK_TPR_PROGRAMACION FOREIGN KEY ([tpr_programacion])        REFERENCES [dbo].[Programacion] ([pro_id]),
        CONSTRAINT FK_TPR_RESPONSABLE  FOREIGN KEY ([tpr_usuario_responsable]) REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_TPR_GRUPO        FOREIGN KEY ([tpr_grupo_trabajo])       REFERENCES [dbo].[Grupo_Trabajo] ([gtr_id]),
        CONSTRAINT UX_TPR_TAREA_PROGRAMACION UNIQUE ([tpr_tarea], [tpr_programacion])
    )
    PRINT 'Tabla Tarea_Programacion creada correctamente.'
END
ELSE PRINT 'Tabla Tarea_Programacion ya existe.'
GO


/* ========================================================================
   4. TAREA_OCURRENCIA (toc) -- la instancia concreta

      toc_orden_trabajo es la puerta hacia la OT cuando la tarea revela
      trabajo de mantenimiento de verdad. FK diferida (bloque 22).
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tarea_Ocurrencia]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Tarea_Ocurrencia]
    (
        [toc_id]                            INT                 NOT NULL IDENTITY(1,1),
        [toc_uuid]                          UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_TOC_UUID DEFAULT NEWID(),
        [toc_cliente]                       INT                 NOT NULL,
        [toc_tarea]                         INT                 NOT NULL,
        [toc_tarea_programacion]            INT                 NULL,   -- NULL = creada a mano
        [toc_tarea_ocurrencia_estado]       INT                 NOT NULL,
        [toc_fecha_programada_utc]          DATETIME            NOT NULL,
        [toc_fecha_disponible_utc]          DATETIME            NULL,
        [toc_fecha_limite_utc]              DATETIME            NULL,
        [toc_fecha_programada_original_utc] DATETIME            NULL,
        [toc_ocurrencia_origen]             INT                 NULL,
        [toc_orden_trabajo]                 INT                 NULL,   -- FK diferida (bloque 22)
        [toc_observacion]                   NVARCHAR(500)       NULL,
        [toc_usuario_creacion]              INT                 NOT NULL,
        [toc_fecha_creacion]                DATETIME            NOT NULL CONSTRAINT DF_TOC_FECHA_CREACION DEFAULT GETDATE(),
        [toc_usuario_actualizacion]         INT                 NULL,
        [toc_fecha_actualizacion]           DATETIME            NULL,
        [toc_habilitado]                    BIT                 NOT NULL CONSTRAINT DF_TOC_HABILITADO DEFAULT 1,

        CONSTRAINT PK_TAREA_OCURRENCIA PRIMARY KEY CLUSTERED ([toc_id] ASC),
        CONSTRAINT FK_TOC_CLIENTE      FOREIGN KEY ([toc_cliente])                  REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_TOC_TAREA        FOREIGN KEY ([toc_tarea])                    REFERENCES [dbo].[Tarea] ([tar_id]),
        CONSTRAINT FK_TOC_PROGRAMACION FOREIGN KEY ([toc_tarea_programacion])       REFERENCES [dbo].[Tarea_Programacion] ([tpr_id]),
        CONSTRAINT FK_TOC_ESTADO       FOREIGN KEY ([toc_tarea_ocurrencia_estado])  REFERENCES [dbo].[Tarea_Ocurrencia_Estado] ([toe_id]),
        CONSTRAINT FK_TOC_ORIGEN       FOREIGN KEY ([toc_ocurrencia_origen])        REFERENCES [dbo].[Tarea_Ocurrencia] ([toc_id]),
        CONSTRAINT UX_TOC_UUID UNIQUE ([toc_uuid]),
        CONSTRAINT CK_TOC_LIMITE CHECK ([toc_fecha_limite_utc] IS NULL OR [toc_fecha_limite_utc] >= [toc_fecha_programada_utc])
    )
    CREATE NONCLUSTERED INDEX IX_TOC_CLIENTE_ESTADO_FECHA
        ON [dbo].[Tarea_Ocurrencia] ([toc_cliente], [toc_tarea_ocurrencia_estado], [toc_fecha_programada_utc])
    PRINT 'Tabla Tarea_Ocurrencia creada correctamente.'
END
ELSE PRINT 'Tabla Tarea_Ocurrencia ya existe.'
GO


/* ========================================================================
   5. TAREA_OCURRENCIA_ASIGNACION (toa)

      Mismo CHECK de exclusividad que el checklist: usuario o grupo, uno.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tarea_Ocurrencia_Asignacion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Tarea_Ocurrencia_Asignacion]
    (
        [toa_id]                        INT         NOT NULL IDENTITY(1,1),
        [toa_tarea_ocurrencia]          INT         NOT NULL,
        [toa_usuario]                   INT         NULL,
        [toa_grupo_trabajo]             INT         NULL,
        [toa_es_responsable]            BIT         NOT NULL CONSTRAINT DF_TOA_RESPONSABLE DEFAULT 1,
        [toa_fecha_asignacion_utc]      DATETIME    NOT NULL CONSTRAINT DF_TOA_FECHA_ASIGNACION DEFAULT GETUTCDATE(),
        [toa_fecha_aceptacion_utc]      DATETIME    NULL,
        [toa_usuario_creacion]          INT         NOT NULL,
        [toa_fecha_creacion]            DATETIME    NOT NULL CONSTRAINT DF_TOA_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_TAREA_OCURRENCIA_ASIGNACION PRIMARY KEY CLUSTERED ([toa_id] ASC),
        CONSTRAINT FK_TOA_OCURRENCIA FOREIGN KEY ([toa_tarea_ocurrencia]) REFERENCES [dbo].[Tarea_Ocurrencia] ([toc_id]),
        CONSTRAINT FK_TOA_USUARIO    FOREIGN KEY ([toa_usuario])          REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_TOA_GRUPO      FOREIGN KEY ([toa_grupo_trabajo])    REFERENCES [dbo].[Grupo_Trabajo] ([gtr_id]),
        CONSTRAINT CK_TOA_DESTINATARIO CHECK
            ((CASE WHEN [toa_usuario] IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN [toa_grupo_trabajo] IS NULL THEN 0 ELSE 1 END) = 1)
    )
    CREATE NONCLUSTERED INDEX IX_TOA_OCURRENCIA ON [dbo].[Tarea_Ocurrencia_Asignacion] ([toa_tarea_ocurrencia])
    PRINT 'Tabla Tarea_Ocurrencia_Asignacion creada correctamente.'
END
ELSE PRINT 'Tabla Tarea_Ocurrencia_Asignacion ya existe.'
GO


/* ========================================================================
   6. TAREA_EJECUCION (tej) -- el hacer

      tej_offline_creado y la geolocalizacion, igual que en el checklist.
      Una tarea de terreno se hace donde no hay señal, y el momento en que
      se hizo no es el momento en que llego al servidor.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tarea_Ejecucion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Tarea_Ejecucion]
    (
        [tej_id]                        INT                 NOT NULL IDENTITY(1,1),
        [tej_uuid]                      UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_TEJ_UUID DEFAULT NEWID(),
        [tej_tarea_ocurrencia]          INT                 NOT NULL,
        [tej_usuario_ejecutor]          INT                 NOT NULL,
        [tej_fecha_inicio_utc]          DATETIME            NOT NULL CONSTRAINT DF_TEJ_FECHA_INICIO DEFAULT GETUTCDATE(),
        [tej_fecha_fin_utc]             DATETIME            NULL,
        [tej_duracion_minuto]           INT                 NULL,
        [tej_resultado]                 NVARCHAR(MAX)       NULL,
        [tej_conforme]                  BIT                 NULL,
        [tej_latitud]                   DECIMAL(9,6)        NULL,
        [tej_longitud]                  DECIMAL(9,6)        NULL,
        [tej_dispositivo]               NVARCHAR(200)       NULL,
        [tej_offline_creado]            BIT                 NOT NULL CONSTRAINT DF_TEJ_OFFLINE DEFAULT 0,
        [tej_fecha_sincronizacion_utc]  DATETIME            NULL,
        [tej_usuario_creacion]          INT                 NOT NULL,
        [tej_fecha_creacion]            DATETIME            NOT NULL CONSTRAINT DF_TEJ_FECHA_CREACION DEFAULT GETDATE(),
        [tej_usuario_actualizacion]     INT                 NULL,
        [tej_fecha_actualizacion]       DATETIME            NULL,
        [tej_habilitado]                BIT                 NOT NULL CONSTRAINT DF_TEJ_HABILITADO DEFAULT 1,

        CONSTRAINT PK_TAREA_EJECUCION PRIMARY KEY CLUSTERED ([tej_id] ASC),
        CONSTRAINT FK_TEJ_OCURRENCIA FOREIGN KEY ([tej_tarea_ocurrencia])  REFERENCES [dbo].[Tarea_Ocurrencia] ([toc_id]),
        CONSTRAINT FK_TEJ_EJECUTOR   FOREIGN KEY ([tej_usuario_ejecutor])  REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT UX_TEJ_UUID UNIQUE ([tej_uuid]),
        CONSTRAINT CK_TEJ_FECHAS CHECK ([tej_fecha_fin_utc] IS NULL OR [tej_fecha_fin_utc] >= [tej_fecha_inicio_utc])
    )
    PRINT 'Tabla Tarea_Ejecucion creada correctamente.'
END
ELSE PRINT 'Tabla Tarea_Ejecucion ya existe.'
GO


/* ========================================================================
   7. TAREA_CHECKLIST (tck) -- una tarea tambien puede exigir un checklist
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tarea_Checklist]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Tarea_Checklist]
    (
        [tck_id]                          INT       NOT NULL IDENTITY(1,1),
        [tck_tarea]                       INT       NOT NULL,
        [tck_checklist_plantilla_version] INT       NOT NULL,
        [tck_momento_ejecucion]           INT       NOT NULL,
        [tck_obligatorio]                 BIT       NOT NULL CONSTRAINT DF_TCK_OBLIGATORIO DEFAULT 1,
        [tck_usuario_creacion]            INT       NOT NULL,
        [tck_fecha_creacion]              DATETIME  NOT NULL CONSTRAINT DF_TCK_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_TAREA_CHECKLIST PRIMARY KEY CLUSTERED ([tck_id] ASC),
        CONSTRAINT FK_TCK_TAREA   FOREIGN KEY ([tck_tarea])                       REFERENCES [dbo].[Tarea] ([tar_id]),
        CONSTRAINT FK_TCK_VERSION FOREIGN KEY ([tck_checklist_plantilla_version]) REFERENCES [dbo].[Checklist_Plantilla_Version] ([cpv_id]),
        CONSTRAINT FK_TCK_MOMENTO FOREIGN KEY ([tck_momento_ejecucion])           REFERENCES [dbo].[Momento_Ejecucion] ([moe_id]),
        CONSTRAINT UX_TCK_TAREA_VERSION_MOMENTO UNIQUE ([tck_tarea], [tck_checklist_plantilla_version], [tck_momento_ejecucion])
    )
    PRINT 'Tabla Tarea_Checklist creada correctamente.'
END
ELSE PRINT 'Tabla Tarea_Checklist ya existe.'
GO


/* ========================================================================
   8. TAREA_COMENTARIO (tco) -- append-only

      Los comentarios no se editan ni se borran. Un hilo de conversacion
      sobre trabajo hecho que se puede reescribir despues no sirve como
      evidencia de nada.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tarea_Comentario]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Tarea_Comentario]
    (
        [tco_id]                        INT             NOT NULL IDENTITY(1,1),
        [tco_tarea_ocurrencia]          INT             NOT NULL,
        [tco_comentario_padre]          INT             NULL,       -- respuesta a otro comentario
        [tco_texto]                     NVARCHAR(MAX)   NOT NULL,
        [tco_dictado_voz]               INT             NULL,       -- si se dicto en vez de escribirse
        [tco_usuario_creacion]          INT             NOT NULL,
        [tco_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_TCO_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_TAREA_COMENTARIO PRIMARY KEY CLUSTERED ([tco_id] ASC),
        CONSTRAINT FK_TCO_OCURRENCIA FOREIGN KEY ([tco_tarea_ocurrencia]) REFERENCES [dbo].[Tarea_Ocurrencia] ([toc_id]),
        CONSTRAINT FK_TCO_PADRE      FOREIGN KEY ([tco_comentario_padre]) REFERENCES [dbo].[Tarea_Comentario] ([tco_id]),
        CONSTRAINT FK_TCO_DICTADO    FOREIGN KEY ([tco_dictado_voz])      REFERENCES [dbo].[Dictado_Voz] ([dvo_id]),
        CONSTRAINT FK_TCO_USUARIO    FOREIGN KEY ([tco_usuario_creacion]) REFERENCES [dbo].[Usuario] ([usu_id])
    )
    CREATE NONCLUSTERED INDEX IX_TCO_OCURRENCIA ON [dbo].[Tarea_Comentario] ([tco_tarea_ocurrencia], [tco_fecha_creacion])
    PRINT 'Tabla Tarea_Comentario creada correctamente.'
END
ELSE PRINT 'Tabla Tarea_Comentario ya existe.'
GO


/* ========================================================================
   9. TAREA_HISTORIAL (thi) -- append-only
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tarea_Historial]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Tarea_Historial]
    (
        [thi_id]                        INT             NOT NULL IDENTITY(1,1),
        [thi_tarea_ocurrencia]          INT             NOT NULL,
        [thi_estado_anterior]           INT             NULL,
        [thi_estado_nuevo]              INT             NOT NULL,
        [thi_fecha_anterior_utc]        DATETIME        NULL,
        [thi_fecha_nueva_utc]           DATETIME        NULL,
        [thi_motivo]                    NVARCHAR(500)   NULL,
        [thi_usuario_creacion]          INT             NOT NULL,
        [thi_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_THI_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_TAREA_HISTORIAL PRIMARY KEY CLUSTERED ([thi_id] ASC),
        CONSTRAINT FK_THI_OCURRENCIA      FOREIGN KEY ([thi_tarea_ocurrencia]) REFERENCES [dbo].[Tarea_Ocurrencia] ([toc_id]),
        CONSTRAINT FK_THI_ESTADO_ANTERIOR FOREIGN KEY ([thi_estado_anterior])  REFERENCES [dbo].[Tarea_Ocurrencia_Estado] ([toe_id]),
        CONSTRAINT FK_THI_ESTADO_NUEVO    FOREIGN KEY ([thi_estado_nuevo])     REFERENCES [dbo].[Tarea_Ocurrencia_Estado] ([toe_id]),
        CONSTRAINT FK_THI_USUARIO         FOREIGN KEY ([thi_usuario_creacion]) REFERENCES [dbo].[Usuario] ([usu_id])
    )
    CREATE NONCLUSTERED INDEX IX_THI_OCURRENCIA ON [dbo].[Tarea_Historial] ([thi_tarea_ocurrencia], [thi_fecha_creacion])
    PRINT 'Tabla Tarea_Historial creada correctamente.'
END
ELSE PRINT 'Tabla Tarea_Historial ya existe.'
GO


PRINT 'Bloque 16 TAREAS: 9 tablas procesadas.'
GO
