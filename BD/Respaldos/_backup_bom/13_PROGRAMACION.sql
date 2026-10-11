﻿﻿﻿﻿USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  19-08-2026
-- DESCRIPTION:     D5 -- MOTOR DE PROGRAMACION (RECURRENCIA UNICA).
-- =============================================
-- Ver SIGMA_MODELO_LOGICO_v2.md §5.15 y §8.5
-- ORDEN: despues de 11_ACTIVOS_MEDICIONES.sql
--
-- UN MOTOR, TRES CONSUMIDORES
--   Planes, tareas y checklists NO tienen cada uno su propia recurrencia:
--   los tres apuntan a la misma Programacion. Si cada uno tuviera la suya,
--   "cada segundo martes del mes" habria que implementarlo tres veces, y a
--   los seis meses las tres implementaciones se comportarian distinto ante
--   el mismo feriado.
--
-- SEIS TIPOS, UNA TABLA POR TIPO
--   Programacion dice QUE se repite y con que tolerancias.
--   Las tablas hijas dicen COMO, y solo existe la que corresponde al tipo:
--     ABIERTA           -> ninguna. Se toma cuando alguien puede
--     FECHA UNICA       -> Programacion_Fecha
--     CALENDARIO        -> Programacion_Calendario (+ _Dia)
--     INTERVALO TIEMPO  -> Programacion_Intervalo
--     MEDIDOR           -> Programacion_Medidor
--     CONDICION         -> Programacion_Condicion
--   Una sola tabla con veinte columnas nulas serviria igual, y seria
--   imposible saber cual combinacion es valida.
--
-- LA MARCA DE AGUA
--   Programacion_Generacion guarda hasta donde se genero. Sin ella, dos
--   ejecuciones del job crean la misma ocurrencia dos veces y el tecnico
--   ve trabajo duplicado. Con ella, generar es idempotente.
--
-- IDEMPOTENTE: se puede ejecutar las veces que sea.
-- =============================================


/* ========================================================================
   1. PROGRAMACION (pro) -- la cabecera comun a los seis tipos

      Las tolerancias son lo que convierte una fecha en una VENTANA:
      "disponible desde 2 dias antes, vence 3 dias despues". Sin ellas,
      una tarea del martes que se hizo el miercoles figura como incumplida,
      y el indicador de cumplimiento deja de significar algo.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Programacion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Programacion]
    (
        [pro_id]                        INT             NOT NULL IDENTITY(1,1),
        [pro_cliente]                   INT             NOT NULL,
        [pro_programacion_tipo]         INT             NOT NULL,
        [pro_zona_horaria]              INT             NULL,       -- NULL = hereda de la planta
        [pro_nombre]                    NVARCHAR(200)   NOT NULL,
        [pro_fecha_inicio]              DATE            NOT NULL,
        [pro_fecha_fin]                 DATE            NULL,       -- NULL = indefinida
        [pro_tolerancia_antes_minuto]   INT             NOT NULL CONSTRAINT DF_PRO_TOL_ANTES DEFAULT 0,
        [pro_tolerancia_despues_minuto] INT             NOT NULL CONSTRAINT DF_PRO_TOL_DESPUES DEFAULT 0,
        [pro_permite_anticipada]        BIT             NOT NULL CONSTRAINT DF_PRO_ANTICIPADA DEFAULT 1,
        [pro_permite_atrasada]          BIT             NOT NULL CONSTRAINT DF_PRO_ATRASADA DEFAULT 1,
        [pro_cumplimiento_politica]     INT             NULL,       -- con varias condiciones: basta UNA, hacen falta TODAS, o un MINIMO
        [pro_genera_automaticamente]    BIT             NOT NULL CONSTRAINT DF_PRO_AUTOMATICA DEFAULT 1,
        [pro_usuario_creacion]          INT             NOT NULL,
        [pro_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PRO_FECHA_CREACION DEFAULT GETDATE(),
        [pro_usuario_actualizacion]     INT             NULL,
        [pro_fecha_actualizacion]       DATETIME        NULL,
        [pro_habilitado]                BIT             NOT NULL CONSTRAINT DF_PRO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PROGRAMACION PRIMARY KEY CLUSTERED ([pro_id] ASC),
        CONSTRAINT FK_PRO_CLIENTE FOREIGN KEY ([pro_cliente])           REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_PRO_TIPO    FOREIGN KEY ([pro_programacion_tipo]) REFERENCES [dbo].[Programacion_Tipo] ([pti_id]),
        CONSTRAINT FK_PRO_ZONA    FOREIGN KEY ([pro_zona_horaria])      REFERENCES [dbo].[Zona_Horaria] ([zho_id]),
        CONSTRAINT FK_PRO_POLITICA FOREIGN KEY ([pro_cumplimiento_politica]) REFERENCES [dbo].[Cumplimiento_Politica] ([cpo_id]),
        CONSTRAINT CK_PRO_RANGO   CHECK ([pro_fecha_fin] IS NULL OR [pro_fecha_fin] >= [pro_fecha_inicio]),
        CONSTRAINT CK_PRO_TOLERANCIA CHECK ([pro_tolerancia_antes_minuto] >= 0 AND [pro_tolerancia_despues_minuto] >= 0)
    )
    CREATE NONCLUSTERED INDEX IX_PRO_CLIENTE_TIPO ON [dbo].[Programacion] ([pro_cliente], [pro_programacion_tipo])
    PRINT 'Tabla Programacion creada correctamente.'
END
ELSE PRINT 'Tabla Programacion ya existe.'
GO


/* ========================================================================
   2. PROGRAMACION_CALENDARIO (pca) y PROGRAMACION_CALENDARIO_DIA (pcd)

      Los dos ordinales negativos son deliberados y resuelven casos reales:
        pca_semana_ordinal = -1  -> "el ultimo viernes del mes"
        pca_dia_mes        = -1  -> "el ultimo dia del mes"
      Sin ellos habria que elegir entre el dia 28, el 30 o el 31 y
      equivocarse en febrero.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Programacion_Calendario]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Programacion_Calendario]
    (
        [pca_id]                        INT             NOT NULL IDENTITY(1,1),
        [pca_programacion]              INT             NOT NULL,
        [pca_frecuencia_tipo]           INT             NOT NULL,
        [pca_intervalo]                 INT             NOT NULL CONSTRAINT DF_PCA_INTERVALO DEFAULT 1,  -- cada 2 semanas
        [pca_semana_ordinal]            INT             NULL,       -- 1..5, -1 = ultima
        [pca_dia_mes]                   INT             NULL,       -- 1..31, -1 = ultimo dia
        [pca_mes]                       INT             NULL,       -- 1..12, solo ANUAL
        [pca_hora_local]                TIME(0)         NOT NULL,
        [pca_usuario_creacion]          INT             NOT NULL,
        [pca_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PCA_FECHA_CREACION DEFAULT GETDATE(),
        [pca_usuario_actualizacion]     INT             NULL,
        [pca_fecha_actualizacion]       DATETIME        NULL,
        [pca_habilitado]                BIT             NOT NULL CONSTRAINT DF_PCA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PROGRAMACION_CALENDARIO PRIMARY KEY CLUSTERED ([pca_id] ASC),
        CONSTRAINT FK_PCA_PROGRAMACION FOREIGN KEY ([pca_programacion])    REFERENCES [dbo].[Programacion] ([pro_id]),
        CONSTRAINT FK_PCA_FRECUENCIA   FOREIGN KEY ([pca_frecuencia_tipo]) REFERENCES [dbo].[Frecuencia_Tipo] ([fre_id]),
        CONSTRAINT UX_PCA_PROGRAMACION UNIQUE ([pca_programacion]),
        CONSTRAINT CK_PCA_INTERVALO    CHECK ([pca_intervalo] >= 1),
        CONSTRAINT CK_PCA_SEMANA       CHECK ([pca_semana_ordinal] IS NULL OR [pca_semana_ordinal] BETWEEN 1 AND 5 OR [pca_semana_ordinal] = -1),
        CONSTRAINT CK_PCA_DIA_MES      CHECK ([pca_dia_mes] IS NULL OR [pca_dia_mes] BETWEEN 1 AND 31 OR [pca_dia_mes] = -1),
        CONSTRAINT CK_PCA_MES          CHECK ([pca_mes] IS NULL OR [pca_mes] BETWEEN 1 AND 12),
        -- El mes solo tiene sentido en la frecuencia ANUAL (fre_id = 4).
        CONSTRAINT CK_PCA_MES_ANUAL    CHECK ([pca_mes] IS NULL OR [pca_frecuencia_tipo] = 4)
    )
    PRINT 'Tabla Programacion_Calendario creada correctamente.'
END
ELSE PRINT 'Tabla Programacion_Calendario ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Programacion_Calendario_Dia]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Programacion_Calendario_Dia]
    (
        [pcd_id]                        INT     NOT NULL IDENTITY(1,1),
        [pcd_programacion_calendario]   INT     NOT NULL,
        [pcd_dia_semana]                INT     NOT NULL,   -- FK Dia_Semana: 1 lunes .. 7 domingo

        CONSTRAINT PK_PROGRAMACION_CALENDARIO_DIA PRIMARY KEY CLUSTERED ([pcd_id] ASC),
        CONSTRAINT FK_PCD_CALENDARIO FOREIGN KEY ([pcd_programacion_calendario]) REFERENCES [dbo].[Programacion_Calendario] ([pca_id]),
        CONSTRAINT FK_PCD_DIA        FOREIGN KEY ([pcd_dia_semana])              REFERENCES [dbo].[Dia_Semana] ([dse_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_PCD_CALENDARIO_DIA
        ON [dbo].[Programacion_Calendario_Dia] ([pcd_programacion_calendario], [pcd_dia_semana])
    PRINT 'Tabla Programacion_Calendario_Dia creada correctamente.'
END
ELSE PRINT 'Tabla Programacion_Calendario_Dia ya existe.'
GO


/* ========================================================================
   3. PROGRAMACION_FECHA (pfe) -- fechas explicitas

      pfe_incluida = 0 sirve para EXCLUIR una fecha concreta de una serie
      generada. Es distinto de Programacion_Exclusion, que excluye rangos.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Programacion_Fecha]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Programacion_Fecha]
    (
        [pfe_id]                INT     NOT NULL IDENTITY(1,1),
        [pfe_programacion]      INT     NOT NULL,
        [pfe_fecha]             DATE    NOT NULL,
        [pfe_hora]              TIME(0) NULL,
        [pfe_incluida]          BIT     NOT NULL CONSTRAINT DF_PFE_INCLUIDA DEFAULT 1,

        CONSTRAINT PK_PROGRAMACION_FECHA PRIMARY KEY CLUSTERED ([pfe_id] ASC),
        CONSTRAINT FK_PFE_PROGRAMACION FOREIGN KEY ([pfe_programacion]) REFERENCES [dbo].[Programacion] ([pro_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_PFE_PROGRAMACION_FECHA ON [dbo].[Programacion_Fecha] ([pfe_programacion], [pfe_fecha])
    PRINT 'Tabla Programacion_Fecha creada correctamente.'
END
ELSE PRINT 'Tabla Programacion_Fecha ya existe.'
GO


/* ========================================================================
   4. PROGRAMACION_INTERVALO (pin) -- "cada 90 dias desde tal fecha"

      La diferencia con CALENDARIO importa: el intervalo cuenta desde una
      FECHA ANCLA, no desde el calendario. "Cada 90 dias" corre solo; "el
      primer lunes de cada mes" se alinea al mes.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Programacion_Intervalo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Programacion_Intervalo]
    (
        [pin_id]                        INT         NOT NULL IDENTITY(1,1),
        [pin_programacion]              INT         NOT NULL,
        [pin_unidad_tiempo]             INT         NOT NULL,
        [pin_fecha_ancla_utc]           DATETIME    NOT NULL,
        [pin_cantidad]                  INT         NOT NULL,
        [pin_usuario_creacion]          INT         NOT NULL,
        [pin_fecha_creacion]            DATETIME    NOT NULL CONSTRAINT DF_PIN_FECHA_CREACION DEFAULT GETDATE(),
        [pin_usuario_actualizacion]     INT         NULL,
        [pin_fecha_actualizacion]       DATETIME    NULL,
        [pin_habilitado]                BIT         NOT NULL CONSTRAINT DF_PIN_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PROGRAMACION_INTERVALO PRIMARY KEY CLUSTERED ([pin_id] ASC),
        CONSTRAINT FK_PIN_PROGRAMACION FOREIGN KEY ([pin_programacion])  REFERENCES [dbo].[Programacion] ([pro_id]),
        CONSTRAINT FK_PIN_UNIDAD       FOREIGN KEY ([pin_unidad_tiempo]) REFERENCES [dbo].[Unidad_Tiempo] ([uti_id]),
        CONSTRAINT UX_PIN_PROGRAMACION UNIQUE ([pin_programacion]),
        CONSTRAINT CK_PIN_CANTIDAD     CHECK ([pin_cantidad] >= 1)
    )
    PRINT 'Tabla Programacion_Intervalo creada correctamente.'
END
ELSE PRINT 'Tabla Programacion_Intervalo ya existe.'
GO


/* ========================================================================
   5. PROGRAMACION_MEDIDOR (pme) -- "cada 500 horas"

      pme_aviso_anticipacion viene del Anexo H: avisar 50 horas ANTES.
      Se expresa en unidades del medidor y no en dias a proposito -- cuantos
      dias son 50 horas depende de cuanto trabaje la maquina, que es lo que
      no se sabe de antemano.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Programacion_Medidor]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Programacion_Medidor]
    (
        [pme_id]                        INT             NOT NULL IDENTITY(1,1),
        [pme_programacion]              INT             NOT NULL,
        [pme_activo_medidor]            INT             NOT NULL,
        [pme_valor_inicial]             DECIMAL(18,2)   NOT NULL CONSTRAINT DF_PME_VALOR_INICIAL DEFAULT 0,
        [pme_cada_cantidad]             DECIMAL(18,2)   NOT NULL,   -- 500 horas
        [pme_aviso_anticipacion]        DECIMAL(18,2)   NULL,       -- avisar 50 h antes
        [pme_usuario_creacion]          INT             NOT NULL,
        [pme_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PME_FECHA_CREACION DEFAULT GETDATE(),
        [pme_usuario_actualizacion]     INT             NULL,
        [pme_fecha_actualizacion]       DATETIME        NULL,
        [pme_habilitado]                BIT             NOT NULL CONSTRAINT DF_PME_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PROGRAMACION_MEDIDOR PRIMARY KEY CLUSTERED ([pme_id] ASC),
        CONSTRAINT FK_PME_PROGRAMACION FOREIGN KEY ([pme_programacion])   REFERENCES [dbo].[Programacion] ([pro_id]),
        CONSTRAINT FK_PME_MEDIDOR      FOREIGN KEY ([pme_activo_medidor]) REFERENCES [dbo].[Activo_Medidor] ([ame_id]),
        CONSTRAINT CK_PME_CADA         CHECK ([pme_cada_cantidad] > 0),
        CONSTRAINT CK_PME_ANTICIPACION CHECK ([pme_aviso_anticipacion] IS NULL OR [pme_aviso_anticipacion] > 0)
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_PME_PROGRAMACION_MEDIDOR
        ON [dbo].[Programacion_Medidor] ([pme_programacion], [pme_activo_medidor])
    PRINT 'Tabla Programacion_Medidor creada correctamente.'
END
ELSE PRINT 'Tabla Programacion_Medidor ya existe.'
GO


/* ========================================================================
   6. PROGRAMACION_CONDICION (pco) -- "cuando la vibracion pase de 7 mm/s"

      pco_duracion_minima_minuto evita el disparo por un pico aislado: la
      condicion tiene que sostenerse. Sin eso, una lectura mala genera una
      OT que nadie necesitaba, y a la tercera vez el planificador deja de
      creerle al sistema.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Programacion_Condicion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Programacion_Condicion]
    (
        [pco_id]                        INT             NOT NULL IDENTITY(1,1),
        [pco_programacion]              INT             NOT NULL,
        [pco_activo_variable]           INT             NOT NULL,
        [pco_operador_comparacion]      INT             NOT NULL,
        [pco_umbral]                    DECIMAL(18,6)   NOT NULL,
        [pco_umbral_hasta]              DECIMAL(18,6)   NULL,       -- solo para el operador ENTRE
        [pco_duracion_minima_minuto]    INT             NULL,
        [pco_severidad]                 INT             NOT NULL,
        [pco_usuario_creacion]          INT             NOT NULL,
        [pco_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PCO_FECHA_CREACION DEFAULT GETDATE(),
        [pco_usuario_actualizacion]     INT             NULL,
        [pco_fecha_actualizacion]       DATETIME        NULL,
        [pco_habilitado]                BIT             NOT NULL CONSTRAINT DF_PCO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PROGRAMACION_CONDICION PRIMARY KEY CLUSTERED ([pco_id] ASC),
        CONSTRAINT FK_PCO_PROGRAMACION FOREIGN KEY ([pco_programacion])         REFERENCES [dbo].[Programacion] ([pro_id]),
        CONSTRAINT FK_PCO_VARIABLE     FOREIGN KEY ([pco_activo_variable])      REFERENCES [dbo].[Activo_Variable] ([ava_id]),
        CONSTRAINT FK_PCO_OPERADOR     FOREIGN KEY ([pco_operador_comparacion]) REFERENCES [dbo].[Operador_Comparacion] ([opc_id]),
        CONSTRAINT FK_PCO_SEVERIDAD    FOREIGN KEY ([pco_severidad])            REFERENCES [dbo].[Severidad] ([sev_id]),
        -- El operador ENTRE (opc_id = 7) exige el segundo umbral.
        CONSTRAINT CK_PCO_ENTRE        CHECK ([pco_operador_comparacion] <> 7 OR [pco_umbral_hasta] IS NOT NULL)
    )
    CREATE NONCLUSTERED INDEX IX_PCO_VARIABLE ON [dbo].[Programacion_Condicion] ([pco_activo_variable])
    PRINT 'Tabla Programacion_Condicion creada correctamente.'
END
ELSE PRINT 'Tabla Programacion_Condicion ya existe.'
GO


/* ========================================================================
   7. PROGRAMACION_EXCLUSION (pxc) -- feriados y paradas de planta
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Programacion_Exclusion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Programacion_Exclusion]
    (
        [pxc_id]                        INT             NOT NULL IDENTITY(1,1),
        [pxc_programacion]              INT             NOT NULL,
        [pxc_fecha_inicio_utc]          DATETIME        NOT NULL,
        [pxc_fecha_fin_utc]             DATETIME        NOT NULL,
        [pxc_motivo]                    NVARCHAR(200)   NOT NULL,
        [pxc_usuario_creacion]          INT             NOT NULL,
        [pxc_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PXC_FECHA_CREACION DEFAULT GETDATE(),
        [pxc_usuario_actualizacion]     INT             NULL,
        [pxc_fecha_actualizacion]       DATETIME        NULL,
        [pxc_habilitado]                BIT             NOT NULL CONSTRAINT DF_PXC_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PROGRAMACION_EXCLUSION PRIMARY KEY CLUSTERED ([pxc_id] ASC),
        CONSTRAINT FK_PXC_PROGRAMACION FOREIGN KEY ([pxc_programacion]) REFERENCES [dbo].[Programacion] ([pro_id]),
        CONSTRAINT CK_PXC_RANGO        CHECK ([pxc_fecha_fin_utc] >= [pxc_fecha_inicio_utc])
    )
    CREATE NONCLUSTERED INDEX IX_PXC_PROGRAMACION ON [dbo].[Programacion_Exclusion] ([pxc_programacion], [pxc_fecha_inicio_utc])
    PRINT 'Tabla Programacion_Exclusion creada correctamente.'
END
ELSE PRINT 'Tabla Programacion_Exclusion ya existe.'
GO


/* ========================================================================
   8. PROGRAMACION_GENERACION (pge) -- la marca de agua

      Una fila por programacion. Guarda hasta donde ya se genero, para que
      correr el generador dos veces no duplique ocurrencias.

      pge_ultimo_valor_medidor cumple la misma funcion para las
      programaciones por horometro: si ya se genero la ocurrencia de las
      13.500 horas, no se vuelve a generar aunque el job corra de nuevo.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Programacion_Generacion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Programacion_Generacion]
    (
        [pge_id]                        INT             NOT NULL IDENTITY(1,1),
        [pge_programacion]              INT             NOT NULL,
        [pge_horizonte_dia]             INT             NOT NULL CONSTRAINT DF_PGE_HORIZONTE DEFAULT 60,
        [pge_fecha_generada_hasta_utc]  DATETIME        NULL,       -- la marca de agua
        [pge_ultimo_valor_medidor]      DECIMAL(18,2)   NULL,
        [pge_ultima_ejecucion_utc]      DATETIME        NULL,
        [pge_ocurrencias_generadas]     INT             NOT NULL CONSTRAINT DF_PGE_OCURRENCIAS DEFAULT 0,
        [pge_ultimo_error]              NVARCHAR(500)   NULL,
        [pge_usuario_creacion]          INT             NOT NULL,
        [pge_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PGE_FECHA_CREACION DEFAULT GETDATE(),
        [pge_usuario_actualizacion]     INT             NULL,
        [pge_fecha_actualizacion]       DATETIME        NULL,

        CONSTRAINT PK_PROGRAMACION_GENERACION PRIMARY KEY CLUSTERED ([pge_id] ASC),
        CONSTRAINT FK_PGE_PROGRAMACION FOREIGN KEY ([pge_programacion]) REFERENCES [dbo].[Programacion] ([pro_id]),
        CONSTRAINT UX_PGE_PROGRAMACION UNIQUE ([pge_programacion]),
        CONSTRAINT CK_PGE_HORIZONTE    CHECK ([pge_horizonte_dia] > 0)
    )
    PRINT 'Tabla Programacion_Generacion creada correctamente.'
END
ELSE PRINT 'Tabla Programacion_Generacion ya existe.'
GO

PRINT 'Bloque D5 (motor de programacion) aplicado correctamente.'
GO
