﻿﻿USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  20-08-2026
-- DESCRIPTION:     D10 -- BITACORA DE TURNO: LO QUE PASO, ESCRITO POR QUIEN LO VIO.
-- =============================================
-- Ver SIGMA_MODELO_LOGICO_v2.md §8.10
-- ORDEN: despues de 17_ORDEN_TRABAJO.sql
--
-- POR QUE LA BITACORA NO SE EDITA
--   Una bitacora de turno que se puede corregir despues no sirve como
--   evidencia de nada. Si el turno de noche anoto "se sintio un golpe en
--   el blower 2" y a la semana siguiente el blower 2 se rompe, lo que
--   importa es que ESO se escribio ESA noche.
--
--   Por eso Bitacora es append-only y las correcciones van en
--   Bitacora_Rectificacion: la entrada original queda, la correccion se
--   agrega, y ambas se muestran juntas. Es el mismo principio de un
--   libro de novedades en papel, donde no se borra: se tarja y se anota
--   al lado.
--
-- bit_requiere_atencion Y bit_alerta
--   El que escribe puede marcar que algo necesita seguimiento. Esa marca
--   puede generar una Alerta, y bit_alerta guarda cual. No genera OT: la
--   OT la decide una persona, como siempre.
--
-- IDEMPOTENTE: se puede ejecutar las veces que sea.
-- =============================================


/* ========================================================================
   1. BITACORA (bit) -- append-only

      bit_dictado_voz enlaza la entrada dictada. En terreno, con guantes
      y ruido, dictar es la unica forma realista de dejar registro, y esa
      es la razon de ser del modulo de voz.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Bitacora]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Bitacora]
    (
        [bit_id]                        INT                 NOT NULL IDENTITY(1,1),
        [bit_uuid]                      UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_BIT_UUID DEFAULT NEWID(),
        [bit_cliente]                   INT                 NOT NULL,
        [bit_cliente_instalacion]       INT                 NOT NULL,
        [bit_instalacion_area]          INT                 NULL,
        [bit_bitacora_tipo]             INT                 NOT NULL,
        [bit_activo]                    INT                 NULL,
        [bit_activo_componente]         INT                 NULL,
        [bit_orden_trabajo]             INT                 NULL,
        [bit_titulo]                    NVARCHAR(200)       NULL,
        [bit_texto]                     NVARCHAR(MAX)       NOT NULL,
        [bit_fecha_evento_utc]          DATETIME            NOT NULL CONSTRAINT DF_BIT_FECHA_EVENTO DEFAULT GETUTCDATE(),
        [bit_turno]                     NVARCHAR(50)        NULL,
        [bit_requiere_atencion]         BIT                 NOT NULL CONSTRAINT DF_BIT_ATENCION DEFAULT 0,
        [bit_alerta]                    INT                 NULL,
        [bit_severidad]                 INT                 NULL,
        [bit_dictado_voz]               INT                 NULL,
        [bit_entrada_modo]              INT                 NULL,   -- TECLADO / VOZ / QR
        [bit_latitud]                   DECIMAL(9,6)        NULL,
        [bit_longitud]                  DECIMAL(9,6)        NULL,
        [bit_offline_creado]            BIT                 NOT NULL CONSTRAINT DF_BIT_OFFLINE DEFAULT 0,
        [bit_fecha_sincronizacion_utc]  DATETIME            NULL,
        [bit_usuario_creacion]          INT                 NOT NULL,
        [bit_fecha_creacion]            DATETIME            NOT NULL CONSTRAINT DF_BIT_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_BITACORA PRIMARY KEY CLUSTERED ([bit_id] ASC),
        CONSTRAINT FK_BIT_CLIENTE       FOREIGN KEY ([bit_cliente])             REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_BIT_INSTALACION   FOREIGN KEY ([bit_cliente_instalacion]) REFERENCES [dbo].[Cliente_Instalacion] ([cin_id]),
        CONSTRAINT FK_BIT_AREA          FOREIGN KEY ([bit_instalacion_area])    REFERENCES [dbo].[Instalacion_Area] ([iar_id]),
        CONSTRAINT FK_BIT_TIPO          FOREIGN KEY ([bit_bitacora_tipo])       REFERENCES [dbo].[Bitacora_Tipo] ([bti_id]),
        CONSTRAINT FK_BIT_ACTIVO        FOREIGN KEY ([bit_activo])              REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_BIT_COMPONENTE    FOREIGN KEY ([bit_activo_componente])   REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_BIT_ORDEN_TRABAJO FOREIGN KEY ([bit_orden_trabajo])       REFERENCES [dbo].[Orden_Trabajo] ([otr_id]),
        CONSTRAINT FK_BIT_ALERTA        FOREIGN KEY ([bit_alerta])              REFERENCES [dbo].[Alerta] ([ale_id]),
        CONSTRAINT FK_BIT_SEVERIDAD     FOREIGN KEY ([bit_severidad])           REFERENCES [dbo].[Severidad] ([sev_id]),
        CONSTRAINT FK_BIT_DICTADO       FOREIGN KEY ([bit_dictado_voz])         REFERENCES [dbo].[Dictado_Voz] ([dvo_id]),
        CONSTRAINT FK_BIT_ENTRADA_MODO  FOREIGN KEY ([bit_entrada_modo])        REFERENCES [dbo].[Entrada_Modo] ([emo_id]),
        CONSTRAINT FK_BIT_USUARIO       FOREIGN KEY ([bit_usuario_creacion])    REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT UX_BIT_UUID UNIQUE ([bit_uuid])
    )
    CREATE NONCLUSTERED INDEX IX_BIT_INSTALACION_FECHA ON [dbo].[Bitacora] ([bit_cliente_instalacion], [bit_fecha_evento_utc])
    CREATE NONCLUSTERED INDEX IX_BIT_ACTIVO_FECHA      ON [dbo].[Bitacora] ([bit_activo], [bit_fecha_evento_utc])
    -- La bandeja: lo que alguien marco y nadie miro.
    CREATE NONCLUSTERED INDEX IX_BIT_ATENCION ON [dbo].[Bitacora] ([bit_cliente], [bit_fecha_evento_utc])
        WHERE [bit_requiere_atencion] = 1
    PRINT 'Tabla Bitacora creada correctamente.'
END
ELSE PRINT 'Tabla Bitacora ya existe.'
GO


/* ========================================================================
   2. BITACORA_COMENTARIO (bco) -- append-only

      El hilo. Tampoco se edita ni se borra: es una conversacion sobre un
      hecho registrado, y reescribirla despues la vacia de valor.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Bitacora_Comentario]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Bitacora_Comentario]
    (
        [bco_id]                        INT             NOT NULL IDENTITY(1,1),
        [bco_bitacora]                  INT             NOT NULL,
        [bco_comentario_padre]          INT             NULL,
        [bco_texto]                     NVARCHAR(MAX)   NOT NULL,
        [bco_dictado_voz]               INT             NULL,
        [bco_usuario_creacion]          INT             NOT NULL,
        [bco_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_BCO_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_BITACORA_COMENTARIO PRIMARY KEY CLUSTERED ([bco_id] ASC),
        CONSTRAINT FK_BCO_BITACORA FOREIGN KEY ([bco_bitacora])          REFERENCES [dbo].[Bitacora] ([bit_id]),
        CONSTRAINT FK_BCO_PADRE    FOREIGN KEY ([bco_comentario_padre])  REFERENCES [dbo].[Bitacora_Comentario] ([bco_id]),
        CONSTRAINT FK_BCO_DICTADO  FOREIGN KEY ([bco_dictado_voz])       REFERENCES [dbo].[Dictado_Voz] ([dvo_id]),
        CONSTRAINT FK_BCO_USUARIO  FOREIGN KEY ([bco_usuario_creacion])  REFERENCES [dbo].[Usuario] ([usu_id])
    )
    CREATE NONCLUSTERED INDEX IX_BCO_BITACORA ON [dbo].[Bitacora_Comentario] ([bco_bitacora], [bco_fecha_creacion])
    PRINT 'Tabla Bitacora_Comentario creada correctamente.'
END
ELSE PRINT 'Tabla Bitacora_Comentario ya existe.'
GO


/* ========================================================================
   3. BITACORA_RECTIFICACION (bre)

      La forma honesta de corregir un registro inmutable. El texto
      original queda; la rectificacion dice que estaba mal, que es lo
      correcto, quien lo corrige y por que. La UI muestra la entrada
      original TACHADA con su rectificacion al lado -- nunca reemplaza el
      texto en silencio.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Bitacora_Rectificacion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Bitacora_Rectificacion]
    (
        [bre_id]                        INT             NOT NULL IDENTITY(1,1),
        [bre_bitacora]                  INT             NOT NULL,
        [bre_texto_rectificado]         NVARCHAR(MAX)   NOT NULL,
        [bre_motivo]                    NVARCHAR(500)   NOT NULL,
        [bre_usuario_creacion]          INT             NOT NULL,
        [bre_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_BRE_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_BITACORA_RECTIFICACION PRIMARY KEY CLUSTERED ([bre_id] ASC),
        CONSTRAINT FK_BRE_BITACORA FOREIGN KEY ([bre_bitacora])         REFERENCES [dbo].[Bitacora] ([bit_id]),
        CONSTRAINT FK_BRE_USUARIO  FOREIGN KEY ([bre_usuario_creacion]) REFERENCES [dbo].[Usuario] ([usu_id])
    )
    CREATE NONCLUSTERED INDEX IX_BRE_BITACORA ON [dbo].[Bitacora_Rectificacion] ([bre_bitacora], [bre_fecha_creacion])
    PRINT 'Tabla Bitacora_Rectificacion creada correctamente.'
END
ELSE PRINT 'Tabla Bitacora_Rectificacion ya existe.'
GO


PRINT 'Bloque 23 BITACORA: 3 tablas procesadas.'
GO
