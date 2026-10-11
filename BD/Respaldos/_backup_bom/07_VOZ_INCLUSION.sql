﻿﻿﻿﻿USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  19-08-2026
-- DESCRIPTION:     VOZ E INCLUSION: DICTADO, MODO DE ENTRADA Y ACCESIBILIDAD.
-- =============================================
-- Ver SIGMA_ANEXO_E_VOZ_INCLUSION.md
--
-- El audio NO se almacena: se transcribe, se confirma hablando y se descarta.
-- Por eso la confirmacion ocurre en el dispositivo, antes de descartar.
--
-- DEPENDENCIAS
--   Requiere: Cliente, Usuario, Idioma, Archivo, Proceso_Estado, Entrada_Modo
--   Las FK hacia Orden_Trabajo, Checklist_Ejecucion_Respuesta, Bitacora y Falla
--   se agregan en la seccion 4, idempotente, cuando esas tablas existan.
-- =============================================


/* ========================================================================
   1. ARCHIVO_TRANSCRIPCION SE ELIMINA
      Tenia sentido cuando el audio se guardaba como archivo. La reemplaza
      Dictado_Voz, que no depende de que exista un audio.
   ======================================================================== */

IF OBJECT_ID(N'[dbo].[Archivo_Transcripcion]', N'U') IS NOT NULL
BEGIN
    DROP TABLE [dbo].[Archivo_Transcripcion]
    PRINT 'Tabla Archivo_Transcripcion eliminada (la reemplaza Dictado_Voz).'
END
GO


/* ========================================================================
   2. DICTADO_VOZ
      Una fila por dictado CONFIRMADO. dvo_texto guarda lo que el tecnico
      confirmo, no el primer intento del motor.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Dictado_Voz]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Dictado_Voz]
    (
        [dvo_id]                        INT                 NOT NULL IDENTITY(1,1),
        [dvo_uuid]                      UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_DVO_UUID DEFAULT NEWID(),
        [dvo_cliente]                   INT                 NOT NULL,
        [dvo_usuario]                   INT                 NOT NULL,
        [dvo_fecha_utc]                 DATETIME            NOT NULL,
        [dvo_archivo]                   INT                 NULL,       -- normalmente NULL: el audio no se guarda
        [dvo_voz_motor]                 INT                 NOT NULL,   -- DISPOSITIVO / AZURE SPEECH
        [dvo_modelo_version]            NVARCHAR(100)       NULL,
        [dvo_idioma]                    INT                 NOT NULL,
        [dvo_texto]                     NVARCHAR(MAX)       NOT NULL,
        [dvo_confianza]                 DECIMAL(18,6)       NULL,
        [dvo_duracion_segundo]          INT                 NULL,
        [dvo_intentos]                  INT                 NOT NULL CONSTRAINT DF_DVO_INTENTOS DEFAULT 1,
        [dvo_confirmado]                BIT                 NOT NULL CONSTRAINT DF_DVO_CONFIRMADO DEFAULT 0,
        [dvo_confirmado_por_voz]        BIT                 NOT NULL CONSTRAINT DF_DVO_CONF_VOZ DEFAULT 0,
        [dvo_fecha_confirmacion_utc]    DATETIME            NULL,
        [dvo_dispositivo_uuid]          UNIQUEIDENTIFIER    NULL,
        [dvo_proceso_estado]            INT                 NOT NULL,
        [dvo_usuario_creacion]          INT                 NOT NULL,
        [dvo_fecha_creacion]            DATETIME            NOT NULL CONSTRAINT DF_DVO_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_DICTADO_VOZ PRIMARY KEY CLUSTERED ([dvo_id] ASC),
        CONSTRAINT FK_DVO_CLIENTE  FOREIGN KEY ([dvo_cliente])  REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_DVO_USUARIO  FOREIGN KEY ([dvo_usuario])  REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_DVO_IDIOMA   FOREIGN KEY ([dvo_idioma])   REFERENCES [dbo].[Idioma] ([idi_id]),
        CONSTRAINT FK_DVO_MOTOR    FOREIGN KEY ([dvo_voz_motor]) REFERENCES [dbo].[Voz_Motor] ([vmo_id]),
        CONSTRAINT FK_DVO_ARCHIVO  FOREIGN KEY ([dvo_archivo])  REFERENCES [dbo].[Archivo] ([arc_id]),
        CONSTRAINT FK_DVO_PROCESO_ESTADO FOREIGN KEY ([dvo_proceso_estado]) REFERENCES [dbo].[Proceso_Estado] ([pes_id]),
        -- Nada se guarda sin confirmacion del tecnico.
        CONSTRAINT CK_DVO_CONFIRMADO CHECK ([dvo_confirmado] = 0 OR [dvo_fecha_confirmacion_utc] IS NOT NULL)
    )

    CREATE UNIQUE NONCLUSTERED INDEX UX_DVO_UUID ON [dbo].[Dictado_Voz] ([dvo_uuid])

    -- Metrica clave: si los intentos suben, el reconocimiento esta fallando
    -- en esa planta y hay que ajustar vocabulario antes de que dejen de usarlo.
    CREATE NONCLUSTERED INDEX IX_DVO_CLIENTE_FECHA
        ON [dbo].[Dictado_Voz] ([dvo_cliente], [dvo_fecha_utc] DESC)
        INCLUDE ([dvo_intentos], [dvo_confianza])

    PRINT 'Tabla Dictado_Voz creada correctamente.'
END
ELSE
    PRINT 'Tabla Dictado_Voz ya existe.'
GO


/* ========================================================================
   3. USUARIO_ACCESIBILIDAD
      Preferencias de interfaz de la PERSONA. No describen lo que le falta
      al usuario, describen lo que hace la aplicacion.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Usuario_Accesibilidad]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Usuario_Accesibilidad]
    (
        [uac_id]                        INT             NOT NULL IDENTITY(1,1),
        [uac_usuario]                   INT             NOT NULL,
        [uac_entrada_voz]               BIT             NOT NULL CONSTRAINT DF_UAC_ENTRADA_VOZ DEFAULT 0,
        [uac_lectura_voz]               BIT             NOT NULL CONSTRAINT DF_UAC_LECTURA_VOZ DEFAULT 0,
        [uac_confirmacion_hablada]      BIT             NOT NULL CONSTRAINT DF_UAC_CONF_HABLADA DEFAULT 0,
        [uac_velocidad_voz]             DECIMAL(18,2)   NOT NULL CONSTRAINT DF_UAC_VELOCIDAD DEFAULT 1.00,
        [uac_texto_grande]              BIT             NOT NULL CONSTRAINT DF_UAC_TEXTO_GRANDE DEFAULT 0,
        [uac_alto_contraste]            BIT             NOT NULL CONSTRAINT DF_UAC_CONTRASTE DEFAULT 0,
        [uac_iconos_grandes]            BIT             NOT NULL CONSTRAINT DF_UAC_ICONOS DEFAULT 0,
        [uac_idioma]                    INT             NULL,
        [uac_usuario_creacion]          INT             NOT NULL,
        [uac_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_UAC_FECHA_CREACION DEFAULT GETDATE(),
        [uac_usuario_actualizacion]     INT             NULL,
        [uac_fecha_actualizacion]       DATETIME        NULL,
        [uac_habilitado]                BIT             NOT NULL CONSTRAINT DF_UAC_HABILITADO DEFAULT 1,

        CONSTRAINT PK_USUARIO_ACCESIBILIDAD PRIMARY KEY CLUSTERED ([uac_id] ASC),
        CONSTRAINT FK_UAC_USUARIO FOREIGN KEY ([uac_usuario]) REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_UAC_IDIOMA  FOREIGN KEY ([uac_idioma])  REFERENCES [dbo].[Idioma] ([idi_id])
    )

    CREATE UNIQUE NONCLUSTERED INDEX UX_UAC_USUARIO ON [dbo].[Usuario_Accesibilidad] ([uac_usuario])

    PRINT 'Tabla Usuario_Accesibilidad creada correctamente.'
END
ELSE
    PRINT 'Tabla Usuario_Accesibilidad ya existe.'
GO



PRINT 'Bloque 07 VOZ: 2 tablas procesadas. Los enganches van en 24_VOZ_ENGANCHES.sql.'
GO
