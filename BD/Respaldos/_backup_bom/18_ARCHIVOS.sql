﻿﻿USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  20-08-2026
-- DESCRIPTION:     D11 -- ARCHIVOS, CARGA Y ANALISIS VISUAL.
-- =============================================
-- Ver SIGMA_MODELO_LOGICO_v2.md §8.11
-- ORDEN: temprano, despues de 21_FUNDACIONES_RESTO.sql
--        (Dictado_Voz y Suscripcion_Pago tienen FK a Archivo)
--
-- UNA TABLA DE ARCHIVO, NO DIEZ
--   La primera version del modelo tenia diez tablas identicas --
--   Orden_Trabajo_Archivo, Falla_Archivo, Bitacora_Archivo... -- que
--   solo se diferenciaban en la columna del padre. Diez tablas, diez
--   SP de alta, diez de baja, y diez lugares donde arreglar el mismo
--   bug de antivirus.
--
--   Ahora hay UNA tabla Archivo con el binario y su metadata, y UNA
--   tabla Archivo_Vinculo con FK nullable explicitas a cada padre
--   posible mas un CHECK que exige exactamente una. Archivo_Vinculo se
--   crea en el bloque 22, cuando ya existen todos los padres.
--
-- EL BINARIO NO VA EN ESTA TABLA
--   arc_ruta apunta al almacenamiento; la fila guarda hash, tamaño,
--   mime y estado de antivirus. Meter VARBINARY(MAX) aqui haria que
--   listar los adjuntos de una OT arrastre los megabytes de cada foto.
--
-- EL ANTIVIRUS ES UN ESTADO, NO UN BIT
--   PENDIENTE / LIMPIO / INFECTADO / ERROR. Un archivo recien subido no
--   es "limpio hasta que se demuestre lo contrario": es PENDIENTE, y la
--   app no lo muestra hasta que pase. Con un BIT esa distincion se
--   pierde y se termina sirviendo archivos sin revisar.
--
-- IDEMPOTENTE: se puede ejecutar las veces que sea.
-- =============================================


/* ========================================================================
   1. ARCHIVO (arc) -- el archivo, una sola vez

      arc_hash permite deduplicar: la misma foto subida dos veces desde
      dos telefonos es una fila y dos vinculos, no dos copias del binario.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Archivo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Archivo]
    (
        [arc_id]                        INT                 NOT NULL IDENTITY(1,1),
        [arc_uuid]                      UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_ARC_UUID DEFAULT NEWID(),
        [arc_cliente]                   INT                 NOT NULL,
        [arc_archivo_categoria]         INT                 NOT NULL,
        [arc_nombre_original]           NVARCHAR(255)       NOT NULL,
        [arc_nombre_almacenado]         NVARCHAR(255)       NOT NULL,
        [arc_ruta]                      NVARCHAR(500)       NOT NULL,
        [arc_mime]                      NVARCHAR(100)       NULL,
        [arc_extension]                 NVARCHAR(20)        NULL,
        [arc_byte]                      BIGINT              NOT NULL,
        [arc_hash]                      NVARCHAR(64)        NULL,       -- SHA-256, para deduplicar
        [arc_ancho_pixel]               INT                 NULL,
        [arc_alto_pixel]                INT                 NULL,
        [arc_duracion_segundo]          INT                 NULL,       -- audio y video
        -- Donde y cuando se capturo, no cuando se subio
        [arc_latitud]                   DECIMAL(9,6)        NULL,
        [arc_longitud]                  DECIMAL(9,6)        NULL,
        [arc_fecha_captura_utc]         DATETIME            NULL,
        [arc_dispositivo]               NVARCHAR(200)       NULL,
        -- Antivirus
        [arc_archivo_antivirus_estado]  INT                 NOT NULL,
        [arc_fecha_antivirus_utc]       DATETIME            NULL,
        [arc_antivirus_detalle]         NVARCHAR(500)       NULL,
        [arc_usuario_creacion]          INT                 NOT NULL,
        [arc_fecha_creacion]            DATETIME            NOT NULL CONSTRAINT DF_ARC_FECHA_CREACION DEFAULT GETDATE(),
        [arc_usuario_actualizacion]     INT                 NULL,
        [arc_fecha_actualizacion]       DATETIME            NULL,
        [arc_habilitado]                BIT                 NOT NULL CONSTRAINT DF_ARC_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ARCHIVO PRIMARY KEY CLUSTERED ([arc_id] ASC),
        CONSTRAINT FK_ARC_CLIENTE   FOREIGN KEY ([arc_cliente])                  REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_ARC_CATEGORIA FOREIGN KEY ([arc_archivo_categoria])        REFERENCES [dbo].[Archivo_Categoria] ([aca_id]),
        CONSTRAINT FK_ARC_ANTIVIRUS FOREIGN KEY ([arc_archivo_antivirus_estado]) REFERENCES [dbo].[Archivo_Antivirus_Estado] ([aae_id]),
        CONSTRAINT UX_ARC_UUID UNIQUE ([arc_uuid]),
        CONSTRAINT CK_ARC_BYTE CHECK ([arc_byte] >= 0)
    )
    CREATE NONCLUSTERED INDEX IX_ARC_CLIENTE_HASH ON [dbo].[Archivo] ([arc_cliente], [arc_hash])
    PRINT 'Tabla Archivo creada correctamente.'
END
ELSE PRINT 'Tabla Archivo ya existe.'
GO


/* ========================================================================
   2. ARCHIVO_CARGA (acg) -- la subida en trozos

      Subir una foto de 4 MB desde la sala de blowers, con dos rayas de
      señal, falla a la mitad. Esta tabla guarda el progreso por trozo
      para poder retomar en vez de empezar de nuevo. Sin ella, el tecnico
      reintenta cinco veces y termina no subiendo la evidencia.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Archivo_Carga]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Archivo_Carga]
    (
        [acg_id]                        INT                 NOT NULL IDENTITY(1,1),
        [acg_uuid]                      UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_ACG_UUID DEFAULT NEWID(),
        [acg_cliente]                   INT                 NOT NULL,
        [acg_archivo]                   INT                 NULL,       -- se llena al completar
        [acg_archivo_carga_estado]      INT                 NOT NULL,
        [acg_nombre_original]           NVARCHAR(255)       NOT NULL,
        [acg_byte_total]                BIGINT              NOT NULL,
        [acg_byte_recibido]             BIGINT              NOT NULL CONSTRAINT DF_ACG_BYTE_RECIBIDO DEFAULT 0,
        [acg_trozo_total]               INT                 NULL,
        [acg_trozo_recibido]            INT                 NOT NULL CONSTRAINT DF_ACG_TROZO_RECIBIDO DEFAULT 0,
        [acg_hash_esperado]             NVARCHAR(64)        NULL,
        [acg_intento]                   INT                 NOT NULL CONSTRAINT DF_ACG_INTENTO DEFAULT 0,
        [acg_fecha_inicio_utc]          DATETIME            NOT NULL CONSTRAINT DF_ACG_FECHA_INICIO DEFAULT GETUTCDATE(),
        [acg_fecha_fin_utc]             DATETIME            NULL,
        [acg_mensaje]                   NVARCHAR(500)       NULL,
        [acg_usuario_creacion]          INT                 NOT NULL,
        [acg_fecha_creacion]            DATETIME            NOT NULL CONSTRAINT DF_ACG_FECHA_CREACION DEFAULT GETDATE(),
        [acg_usuario_actualizacion]     INT                 NULL,
        [acg_fecha_actualizacion]       DATETIME            NULL,
        [acg_habilitado]                BIT                 NOT NULL CONSTRAINT DF_ACG_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ARCHIVO_CARGA PRIMARY KEY CLUSTERED ([acg_id] ASC),
        CONSTRAINT FK_ACG_CLIENTE FOREIGN KEY ([acg_cliente])                REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_ACG_ARCHIVO FOREIGN KEY ([acg_archivo])                REFERENCES [dbo].[Archivo] ([arc_id]),
        CONSTRAINT FK_ACG_ESTADO  FOREIGN KEY ([acg_archivo_carga_estado])   REFERENCES [dbo].[Archivo_Carga_Estado] ([acs_id]),
        CONSTRAINT UX_ACG_UUID UNIQUE ([acg_uuid]),
        CONSTRAINT CK_ACG_BYTE CHECK ([acg_byte_recibido] >= 0 AND [acg_byte_recibido] <= [acg_byte_total])
    )
    PRINT 'Tabla Archivo_Carga creada correctamente.'
END
ELSE PRINT 'Tabla Archivo_Carga ya existe.'
GO


/* ========================================================================
   3. ANALISIS_VISUAL_REVISION (avr) -- una pasada del modelo de vision

      Es la CABECERA: que modelo miro que archivo, cuando, con que
      version. Guardar la version es lo que permite decir, seis meses
      despues, "esa deteccion la hizo el modelo v3, que tenia el problema
      con las fotos a contraluz".
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Analisis_Visual_Revision]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Analisis_Visual_Revision]
    (
        [avr_id]                        INT             NOT NULL IDENTITY(1,1),
        [avr_cliente]                   INT             NOT NULL,
        [avr_archivo]                   INT             NOT NULL,
        [avr_motor]                     NVARCHAR(100)   NOT NULL,
        [avr_modelo_version]            NVARCHAR(100)   NULL,
        [avr_proceso_estado]            INT             NOT NULL,
        [avr_deteccion_cantidad]        INT             NOT NULL CONSTRAINT DF_AVR_DETECCION DEFAULT 0,
        [avr_confianza_maxima]          DECIMAL(18,6)   NULL,
        [avr_milisegundo_proceso]       INT             NULL,
        [avr_fecha_proceso_utc]         DATETIME        NULL,
        [avr_revisado_humano]           BIT             NOT NULL CONSTRAINT DF_AVR_REVISADO DEFAULT 0,
        [avr_usuario_revision]          INT             NULL,
        [avr_mensaje]                   NVARCHAR(500)   NULL,
        [avr_usuario_creacion]          INT             NOT NULL,
        [avr_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_AVR_FECHA_CREACION DEFAULT GETDATE(),
        [avr_usuario_actualizacion]     INT             NULL,
        [avr_fecha_actualizacion]       DATETIME        NULL,
        [avr_habilitado]                BIT             NOT NULL CONSTRAINT DF_AVR_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ANALISIS_VISUAL_REVISION PRIMARY KEY CLUSTERED ([avr_id] ASC),
        CONSTRAINT FK_AVR_CLIENTE  FOREIGN KEY ([avr_cliente])          REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_AVR_ARCHIVO  FOREIGN KEY ([avr_archivo])          REFERENCES [dbo].[Archivo] ([arc_id]),
        CONSTRAINT FK_AVR_ESTADO   FOREIGN KEY ([avr_proceso_estado])   REFERENCES [dbo].[Proceso_Estado] ([pes_id]),
        CONSTRAINT FK_AVR_REVISION FOREIGN KEY ([avr_usuario_revision]) REFERENCES [dbo].[Usuario] ([usu_id])
    )
    CREATE NONCLUSTERED INDEX IX_AVR_ARCHIVO ON [dbo].[Analisis_Visual_Revision] ([avr_archivo])
    PRINT 'Tabla Analisis_Visual_Revision creada correctamente.'
END
ELSE PRINT 'Tabla Analisis_Visual_Revision ya existe.'
GO


/* ========================================================================
   4. ANALISIS_VISUAL_DETECCION (avd) -- cada cosa encontrada

      Con su caja delimitadora. avd_confirmado_humano es lo que convierte
      esta tabla en un dataset de entrenamiento: la deteccion que una
      persona confirmo o rechazo es un ejemplo etiquetado gratis.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Analisis_Visual_Deteccion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Analisis_Visual_Deteccion]
    (
        [avd_id]                        INT             NOT NULL IDENTITY(1,1),
        [avd_analisis_visual_revision]  INT             NOT NULL,
        [avd_etiqueta]                  NVARCHAR(100)   NOT NULL,   -- FUGA / CORROSION / FISURA / TEMPERATURA
        [avd_confianza]                 DECIMAL(18,6)   NOT NULL,
        [avd_severidad]                 INT             NULL,
        -- Caja delimitadora en fraccion de la imagen (0..1), no en pixeles:
        -- asi sobrevive a que la foto se reescale.
        [avd_caja_x]                    DECIMAL(9,6)    NULL,
        [avd_caja_y]                    DECIMAL(9,6)    NULL,
        [avd_caja_ancho]                DECIMAL(9,6)    NULL,
        [avd_caja_alto]                 DECIMAL(9,6)    NULL,
        [avd_descripcion]               NVARCHAR(500)   NULL,
        [avd_confirmado_humano]         BIT             NULL,       -- NULL = nadie la miro aun
        [avd_usuario_confirmacion]      INT             NULL,
        [avd_fecha_confirmacion_utc]    DATETIME        NULL,
        [avd_usuario_creacion]          INT             NOT NULL,
        [avd_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_AVD_FECHA_CREACION DEFAULT GETDATE(),
        [avd_usuario_actualizacion]     INT             NULL,
        [avd_fecha_actualizacion]       DATETIME        NULL,
        [avd_habilitado]                BIT             NOT NULL CONSTRAINT DF_AVD_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ANALISIS_VISUAL_DETECCION PRIMARY KEY CLUSTERED ([avd_id] ASC),
        CONSTRAINT FK_AVD_REVISION     FOREIGN KEY ([avd_analisis_visual_revision]) REFERENCES [dbo].[Analisis_Visual_Revision] ([avr_id]),
        CONSTRAINT FK_AVD_SEVERIDAD    FOREIGN KEY ([avd_severidad])                REFERENCES [dbo].[Severidad] ([sev_id]),
        CONSTRAINT FK_AVD_CONFIRMACION FOREIGN KEY ([avd_usuario_confirmacion])     REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT CK_AVD_CONFIANZA CHECK ([avd_confianza] >= 0 AND [avd_confianza] <= 1),
        CONSTRAINT CK_AVD_CAJA CHECK
            (([avd_caja_x] IS NULL     OR ([avd_caja_x] >= 0     AND [avd_caja_x] <= 1))
         AND ([avd_caja_y] IS NULL     OR ([avd_caja_y] >= 0     AND [avd_caja_y] <= 1))
         AND ([avd_caja_ancho] IS NULL OR ([avd_caja_ancho] > 0  AND [avd_caja_ancho] <= 1))
         AND ([avd_caja_alto] IS NULL  OR ([avd_caja_alto] > 0   AND [avd_caja_alto] <= 1)))
    )
    CREATE NONCLUSTERED INDEX IX_AVD_REVISION ON [dbo].[Analisis_Visual_Deteccion] ([avd_analisis_visual_revision])
    PRINT 'Tabla Analisis_Visual_Deteccion creada correctamente.'
END
ELSE PRINT 'Tabla Analisis_Visual_Deteccion ya existe.'
GO


/* ========================================================================
   5. ARCHIVO_ANALISIS_VISUAL (aav) -- la cola de trabajo

      Que archivos hay que analizar y cuales ya se analizaron. Es la cola
      que consume el job de vision: sin ella habria que escanear toda la
      tabla Archivo buscando fotos sin revision, lo que a los seis meses
      es un table scan de millones de filas cada cinco minutos.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Archivo_Analisis_Visual]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Archivo_Analisis_Visual]
    (
        [aav_id]                        INT             NOT NULL IDENTITY(1,1),
        [aav_archivo]                   INT             NOT NULL,
        [aav_analisis_visual_revision]  INT             NULL,
        [aav_proceso_estado]            INT             NOT NULL,
        [aav_prioridad]                 INT             NOT NULL CONSTRAINT DF_AAV_PRIORIDAD DEFAULT 5,
        [aav_intento]                   INT             NOT NULL CONSTRAINT DF_AAV_INTENTO DEFAULT 0,
        [aav_fecha_encolado_utc]        DATETIME        NOT NULL CONSTRAINT DF_AAV_FECHA_ENCOLADO DEFAULT GETUTCDATE(),
        [aav_fecha_proceso_utc]         DATETIME        NULL,
        [aav_mensaje]                   NVARCHAR(500)   NULL,
        [aav_usuario_creacion]          INT             NOT NULL,
        [aav_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_AAV_FECHA_CREACION DEFAULT GETDATE(),
        [aav_usuario_actualizacion]     INT             NULL,
        [aav_fecha_actualizacion]       DATETIME        NULL,
        [aav_habilitado]                BIT             NOT NULL CONSTRAINT DF_AAV_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ARCHIVO_ANALISIS_VISUAL PRIMARY KEY CLUSTERED ([aav_id] ASC),
        CONSTRAINT FK_AAV_ARCHIVO  FOREIGN KEY ([aav_archivo])                  REFERENCES [dbo].[Archivo] ([arc_id]),
        CONSTRAINT FK_AAV_REVISION FOREIGN KEY ([aav_analisis_visual_revision]) REFERENCES [dbo].[Analisis_Visual_Revision] ([avr_id]),
        CONSTRAINT FK_AAV_ESTADO   FOREIGN KEY ([aav_proceso_estado])           REFERENCES [dbo].[Proceso_Estado] ([pes_id]),
        CONSTRAINT UX_AAV_ARCHIVO UNIQUE ([aav_archivo])
    )
    -- La cola: estado 1 = PENDIENTE. Indice filtrado para que el job lea poco.
    CREATE NONCLUSTERED INDEX IX_AAV_COLA ON [dbo].[Archivo_Analisis_Visual] ([aav_prioridad], [aav_fecha_encolado_utc])
        WHERE [aav_proceso_estado] = 1
    PRINT 'Tabla Archivo_Analisis_Visual creada correctamente.'
END
ELSE PRINT 'Tabla Archivo_Analisis_Visual ya existe.'
GO


PRINT 'Bloque 18 ARCHIVOS: 5 tablas procesadas.'
GO
