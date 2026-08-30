USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  19-08-2026
-- DESCRIPTION:     D2 + D3 -- ACTIVOS, UBICACION TECNICA, VARIABLES Y MEDICIONES.
-- =============================================
-- Ver SIGMA_MODELO_DATOS_v3.md y SIGMA_MODELO_LOGICO_v2.md §8.2 y §8.3
--
-- ORDEN DE EJECUCION: despues de 04_CATALOGOS_SIGMA.sql
--
-- DOS IDEAS QUE ORDENAN ESTE BLOQUE
--
--   1. LA POSICION NO ES LA MAQUINA.
--      Activo_Posicion es "Blower 1 de la sala de blowers" -- un lugar
--      funcional con un codigo estable que va impreso en el QR.
--      Activo es la maquina fisica con su numero de serie.
--      Cuando se cambia el blower por uno de respaldo, la POSICION sigue
--      siendo CB01 y la MAQUINA que la ocupa cambia. Sin esa separacion,
--      el historial de mantenimiento de la posicion y el de la maquina se
--      mezclan, y no hay forma de responder "cuantas horas lleva ESTE
--      equipo" ni "que se le ha hecho a ESTA posicion".
--      La ocupacion vigente vive en Activo_Posicion_Historial con un
--      indice unico filtrado: una posicion no puede estar ocupada por dos
--      maquinas al mismo tiempo, y lo impide el motor.
--
--   NOTA: Componente_Repuesto_Instalacion NO esta aqui aunque sea de
--   activos: hace FK a Repuesto, que se crea en el bloque 12. Vive alli.
--
--   2. LA MEDICION SE GUARDA DOS VECES: COMO SE INGRESO Y EN UNIDAD BASE.
--      amd_valor es lo que tecleo el tecnico, con su unidad.
--      amd_valor_canonico es lo mismo convertido a la unidad base de la
--      magnitud. Si un tecnico mide en °F y otro en °C, comparar sus
--      lecturas sin canonizar produce un modelo predictivo que aprende
--      basura. Y guardar SOLO lo canonico impediria mostrarle al tecnico
--      lo que el escribio, que es lo que va a reclamar si no coincide.
--
-- IDEMPOTENTE: se puede ejecutar las veces que sea.
-- =============================================


/* ========================================================================
   1. ACTIVO_TIPO (ati) -- catalogo jerarquico y ampliable

      Jerarquico porque el PDF de OT de Hamburgo trae CLASIFICACION 1 y
      CLASIFICACION 2: "Equipo rotativo" -> "Blower". Dos niveles que en
      v1 eran dos columnas de texto y aqui son una FK a si misma.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Tipo]
    (
        [ati_id]                        INT             NOT NULL IDENTITY(1,1),
        [ati_cliente]                   INT             NULL,       -- NULL = global SIGMA
        [ati_activo_tipo_padre]         INT             NULL,       -- clasificacion de nivel superior
        [ati_codigo]                    NVARCHAR(50)    NOT NULL,
        [ati_nombre]                    NVARCHAR(200)   NOT NULL,
        [ati_descripcion]               NVARCHAR(500)   NULL,
        [ati_orden]                     INT             NULL,
        [ati_usuario_creacion]          INT             NOT NULL,
        [ati_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_ATI_FECHA_CREACION DEFAULT GETDATE(),
        [ati_usuario_actualizacion]     INT             NULL,
        [ati_fecha_actualizacion]       DATETIME        NULL,
        [ati_habilitado]                BIT             NOT NULL CONSTRAINT DF_ATI_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ACTIVO_TIPO PRIMARY KEY CLUSTERED ([ati_id] ASC),
        CONSTRAINT FK_ATI_CLIENTE FOREIGN KEY ([ati_cliente]) REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_ATI_PADRE   FOREIGN KEY ([ati_activo_tipo_padre]) REFERENCES [dbo].[Activo_Tipo] ([ati_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_ATI_CLIENTE_CODIGO ON [dbo].[Activo_Tipo] ([ati_cliente], [ati_codigo])
    PRINT 'Tabla Activo_Tipo creada correctamente.'
END
ELSE PRINT 'Tabla Activo_Tipo ya existe.'
GO


/* ========================================================================
   2. ACTIVO_MODELO (amo) -- fabricante y modelo
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Modelo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Modelo]
    (
        [amo_id]                        INT             NOT NULL IDENTITY(1,1),
        [amo_cliente]                   INT             NULL,       -- NULL = global
        [amo_activo_tipo]               INT             NOT NULL,
        [amo_fabricante]                NVARCHAR(200)   NULL,
        [amo_nombre]                    NVARCHAR(200)   NOT NULL,   -- GM10S
        [amo_descripcion]               NVARCHAR(500)   NULL,
        [amo_usuario_creacion]          INT             NOT NULL,
        [amo_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_AMO_FECHA_CREACION DEFAULT GETDATE(),
        [amo_usuario_actualizacion]     INT             NULL,
        [amo_fecha_actualizacion]       DATETIME        NULL,
        [amo_habilitado]                BIT             NOT NULL CONSTRAINT DF_AMO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ACTIVO_MODELO PRIMARY KEY CLUSTERED ([amo_id] ASC),
        CONSTRAINT FK_AMO_CLIENTE     FOREIGN KEY ([amo_cliente])     REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_AMO_ACTIVO_TIPO FOREIGN KEY ([amo_activo_tipo]) REFERENCES [dbo].[Activo_Tipo] ([ati_id])
    )
    CREATE NONCLUSTERED INDEX IX_AMO_TIPO ON [dbo].[Activo_Modelo] ([amo_activo_tipo], [amo_nombre])
    PRINT 'Tabla Activo_Modelo creada correctamente.'
END
ELSE PRINT 'Tabla Activo_Modelo ya existe.'
GO


/* ========================================================================
   3. ACTIVO_POSICION (apo) -- la ubicacion funcional

      apo_codigo es lo que va impreso en el QR pegado en la maquina, y por
      eso NO cambia cuando se cambia el equipo. Es el punto fijo del
      sistema: el tecnico escanea un lugar, no un numero de serie.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Posicion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Posicion]
    (
        [apo_id]                        INT             NOT NULL IDENTITY(1,1),
        [apo_cliente]                   INT             NOT NULL,
        [apo_cliente_instalacion]       INT             NOT NULL,
        [apo_instalacion_area]          INT             NOT NULL,
        [apo_activo_tipo]               INT             NULL,       -- que tipo de maquina admite
        [apo_codigo]                    NVARCHAR(50)    NOT NULL,   -- CB01, estable, va en el QR
        [apo_nombre]                    NVARCHAR(200)   NOT NULL,
        [apo_critica]                   BIT             NOT NULL CONSTRAINT DF_APO_CRITICA DEFAULT 0,
        [apo_descripcion]               NVARCHAR(500)   NULL,
        [apo_usuario_creacion]          INT             NOT NULL,
        [apo_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_APO_FECHA_CREACION DEFAULT GETDATE(),
        [apo_usuario_actualizacion]     INT             NULL,
        [apo_fecha_actualizacion]       DATETIME        NULL,
        [apo_habilitado]                BIT             NOT NULL CONSTRAINT DF_APO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ACTIVO_POSICION PRIMARY KEY CLUSTERED ([apo_id] ASC),
        CONSTRAINT FK_APO_CLIENTE      FOREIGN KEY ([apo_cliente])            REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_APO_INSTALACION  FOREIGN KEY ([apo_cliente_instalacion]) REFERENCES [dbo].[Cliente_Instalacion] ([cin_id]),
        CONSTRAINT FK_APO_AREA         FOREIGN KEY ([apo_instalacion_area])   REFERENCES [dbo].[Instalacion_Area] ([iar_id]),
        CONSTRAINT FK_APO_ACTIVO_TIPO  FOREIGN KEY ([apo_activo_tipo])        REFERENCES [dbo].[Activo_Tipo] ([ati_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_APO_CLIENTE_CODIGO ON [dbo].[Activo_Posicion] ([apo_cliente], [apo_codigo])
    PRINT 'Tabla Activo_Posicion creada correctamente.'
END
ELSE PRINT 'Tabla Activo_Posicion ya existe.'
GO


/* ========================================================================
   4. ACTIVO (act) -- la maquina fisica

      UX_ACT_CLIENTE_ID no es un indice de rendimiento: es lo que HABILITA
      las FK compuestas de todo el resto del modelo. Sin el, SQL Server no
      permite declarar FOREIGN KEY (otr_cliente, otr_activo), y el
      aislamiento entre clientes vuelve a depender del WHERE.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo]
    (
        [act_id]                        INT                 NOT NULL IDENTITY(1,1),
        [act_uuid]                      UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_ACT_UUID DEFAULT NEWID(),
        [act_cliente]                   INT                 NOT NULL,
        [act_cliente_instalacion]        INT                 NOT NULL,
        [act_instalacion_area]          INT                 NULL,
        [act_activo_posicion]           INT                 NULL,   -- posicion ACTUAL; la historia va en aph
        [act_activo_tipo]               INT                 NOT NULL,
        [act_activo_modelo]             INT                 NULL,
        [act_activo_estado]             INT                 NOT NULL,
        [act_activo_padre]              INT                 NULL,   -- subactivo
        [act_centro_costo]              INT                 NULL,
        [act_criticidad_nivel]          INT                 NOT NULL,
        [act_codigo]                    NVARCHAR(50)        NOT NULL,
        [act_nombre]                    NVARCHAR(200)       NOT NULL,
        [act_numero_serie]              NVARCHAR(100)       NULL,   -- identidad fisica real
        [act_fabricante]                NVARCHAR(200)       NULL,
        [act_anio_fabricacion]          INT                 NULL,
        [act_fecha_puesta_marcha]       DATE                NULL,
        [act_fecha_baja]                DATE                NULL,
        [act_descripcion]               NVARCHAR(500)       NULL,
        [act_registro_origen]           INT                 NULL,   -- creado en terreno o en la web
        [act_usuario_creacion]          INT                 NOT NULL,
        [act_fecha_creacion]            DATETIME            NOT NULL CONSTRAINT DF_ACT_FECHA_CREACION DEFAULT GETDATE(),
        [act_usuario_actualizacion]     INT                 NULL,
        [act_fecha_actualizacion]       DATETIME            NULL,
        [act_habilitado]                BIT                 NOT NULL CONSTRAINT DF_ACT_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ACTIVO PRIMARY KEY CLUSTERED ([act_id] ASC),
        CONSTRAINT FK_ACT_CLIENTE          FOREIGN KEY ([act_cliente])             REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_ACT_INSTALACION      FOREIGN KEY ([act_cliente_instalacion]) REFERENCES [dbo].[Cliente_Instalacion] ([cin_id]),
        CONSTRAINT FK_ACT_AREA             FOREIGN KEY ([act_instalacion_area])    REFERENCES [dbo].[Instalacion_Area] ([iar_id]),
        CONSTRAINT FK_ACT_POSICION         FOREIGN KEY ([act_activo_posicion])     REFERENCES [dbo].[Activo_Posicion] ([apo_id]),
        CONSTRAINT FK_ACT_ACTIVO_TIPO      FOREIGN KEY ([act_activo_tipo])         REFERENCES [dbo].[Activo_Tipo] ([ati_id]),
        CONSTRAINT FK_ACT_ACTIVO_MODELO    FOREIGN KEY ([act_activo_modelo])       REFERENCES [dbo].[Activo_Modelo] ([amo_id]),
        CONSTRAINT FK_ACT_ACTIVO_ESTADO    FOREIGN KEY ([act_activo_estado])       REFERENCES [dbo].[Activo_Estado] ([aes_id]),
        CONSTRAINT FK_ACT_PADRE            FOREIGN KEY ([act_activo_padre])        REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_ACT_CENTRO_COSTO     FOREIGN KEY ([act_centro_costo])        REFERENCES [dbo].[Centro_Costo] ([cco_id]),
        CONSTRAINT FK_ACT_CRITICIDAD       FOREIGN KEY ([act_criticidad_nivel])    REFERENCES [dbo].[Criticidad_Nivel] ([crn_id]),
        CONSTRAINT FK_ACT_REGISTRO_ORIGEN  FOREIGN KEY ([act_registro_origen])     REFERENCES [dbo].[Registro_Origen] ([ror_id]),
        -- HABILITA las FK compuestas del resto del modelo. No tocar.
        CONSTRAINT UX_ACT_CLIENTE_ID UNIQUE ([act_cliente], [act_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_ACT_UUID           ON [dbo].[Activo] ([act_uuid])
    CREATE UNIQUE NONCLUSTERED INDEX UX_ACT_CLIENTE_CODIGO ON [dbo].[Activo] ([act_cliente], [act_codigo])
    CREATE NONCLUSTERED INDEX IX_ACT_POSICION ON [dbo].[Activo] ([act_activo_posicion]) WHERE [act_activo_posicion] IS NOT NULL
    PRINT 'Tabla Activo creada correctamente.'
END
ELSE PRINT 'Tabla Activo ya existe.'
GO


/* ========================================================================
   5. ACTIVO_POSICION_HISTORIAL (aph) -- quien ocupa que, y desde cuando

      El indice unico filtrado es la regla de negocio hecha restriccion:
      una posicion no puede tener dos ocupaciones vigentes. Si alguien
      intenta montar un segundo blower en CB01 sin desmontar el primero,
      el motor lo rechaza.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Posicion_Historial]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Posicion_Historial]
    (
        [aph_id]                        INT             NOT NULL IDENTITY(1,1),
        [aph_cliente]                   INT             NOT NULL,
        [aph_activo_posicion]           INT             NOT NULL,
        [aph_activo]                    INT             NOT NULL,
        [aph_fecha_inicio_utc]          DATETIME        NOT NULL,
        [aph_fecha_fin_utc]             DATETIME        NULL,       -- NULL = ocupacion vigente
        [aph_activo_posicion_motivo]    INT             NOT NULL,
        [aph_orden_trabajo]             INT             NULL,       -- FK diferida: ver 15_ORDEN_TRABAJO
        [aph_observacion]               NVARCHAR(500)   NULL,
        [aph_usuario_creacion]          INT             NOT NULL,
        [aph_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_APH_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_ACTIVO_POSICION_HISTORIAL PRIMARY KEY CLUSTERED ([aph_id] ASC),
        CONSTRAINT FK_APH_CLIENTE  FOREIGN KEY ([aph_cliente])                REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_APH_POSICION FOREIGN KEY ([aph_activo_posicion])        REFERENCES [dbo].[Activo_Posicion] ([apo_id]),
        CONSTRAINT FK_APH_ACTIVO   FOREIGN KEY ([aph_activo])                 REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_APH_MOTIVO   FOREIGN KEY ([aph_activo_posicion_motivo]) REFERENCES [dbo].[Activo_Posicion_Motivo] ([apm_id]),
        CONSTRAINT CK_APH_RANGO    CHECK ([aph_fecha_fin_utc] IS NULL OR [aph_fecha_fin_utc] >= [aph_fecha_inicio_utc])
    )
    -- Una sola ocupacion vigente por posicion.
    CREATE UNIQUE NONCLUSTERED INDEX UX_APH_POSICION_VIGENTE
        ON [dbo].[Activo_Posicion_Historial] ([aph_activo_posicion])
        WHERE [aph_fecha_fin_utc] IS NULL

    CREATE NONCLUSTERED INDEX IX_APH_ACTIVO ON [dbo].[Activo_Posicion_Historial] ([aph_activo], [aph_fecha_inicio_utc] DESC)
    PRINT 'Tabla Activo_Posicion_Historial creada correctamente.'
END
ELSE PRINT 'Tabla Activo_Posicion_Historial ya existe.'
GO


/* ========================================================================
   6. ACTIVO_ESTADO_HISTORIAL (aeh) -- append-only
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Estado_Historial]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Estado_Historial]
    (
        [aeh_id]                    INT             NOT NULL IDENTITY(1,1),
        [aeh_cliente]               INT             NOT NULL,
        [aeh_activo]                INT             NOT NULL,
        [aeh_activo_estado]         INT             NOT NULL,
        [aeh_fecha_inicio_utc]      DATETIME        NOT NULL,
        [aeh_fecha_fin_utc]         DATETIME        NULL,
        [aeh_motivo]                NVARCHAR(500)   NULL,
        [aeh_orden_trabajo]         INT             NULL,           -- FK diferida
        [aeh_usuario_creacion]      INT             NOT NULL,
        [aeh_fecha_creacion]        DATETIME        NOT NULL CONSTRAINT DF_AEH_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_ACTIVO_ESTADO_HISTORIAL PRIMARY KEY CLUSTERED ([aeh_id] ASC),
        CONSTRAINT FK_AEH_CLIENTE FOREIGN KEY ([aeh_cliente])       REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_AEH_ACTIVO  FOREIGN KEY ([aeh_activo])        REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_AEH_ESTADO  FOREIGN KEY ([aeh_activo_estado]) REFERENCES [dbo].[Activo_Estado] ([aes_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_AEH_ACTIVO_VIGENTE
        ON [dbo].[Activo_Estado_Historial] ([aeh_activo]) WHERE [aeh_fecha_fin_utc] IS NULL
    PRINT 'Tabla Activo_Estado_Historial creada correctamente.'
END
ELSE PRINT 'Tabla Activo_Estado_Historial ya existe.'
GO


/* ========================================================================
   7. ACTIVO_COMPONENTE (aco) -- lo que se mantiene dentro de la maquina

      aco_tipo y aco_posicion eran NVARCHAR en v1. Ahora son FK a
      Componente_Tipo y Componente_Posicion, y de ahi sale el nombre que
      SIGMA arma solo: "Rodamiento lado A". Es lo que impide que dos
      tecnicos que encuentran el mismo rodamiento creen dos filas
      distintas (ver Anexo C).
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Componente]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Componente]
    (
        [aco_id]                        INT                 NOT NULL IDENTITY(1,1),
        [aco_uuid]                      UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_ACO_UUID DEFAULT NEWID(),
        [aco_cliente]                   INT                 NOT NULL,
        [aco_activo]                    INT                 NOT NULL,
        [aco_componente_padre]          INT                 NULL,
        [aco_componente_tipo]           INT                 NOT NULL,
        [aco_componente_posicion]       INT                 NULL,
        [aco_criticidad_nivel]          INT                 NOT NULL,
        [aco_activo_componente_estado]  INT                 NOT NULL,
        [aco_codigo]                    NVARCHAR(50)        NOT NULL,
        [aco_nombre]                    NVARCHAR(200)       NOT NULL,
        [aco_fecha_instalacion]         DATE                NULL,
        [aco_descripcion]               NVARCHAR(500)       NULL,
        [aco_registro_origen]           INT                 NULL,
        [aco_usuario_creacion]          INT                 NOT NULL,
        [aco_fecha_creacion]            DATETIME            NOT NULL CONSTRAINT DF_ACO_FECHA_CREACION DEFAULT GETDATE(),
        [aco_usuario_actualizacion]     INT                 NULL,
        [aco_fecha_actualizacion]       DATETIME            NULL,
        [aco_habilitado]                BIT                 NOT NULL CONSTRAINT DF_ACO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ACTIVO_COMPONENTE PRIMARY KEY CLUSTERED ([aco_id] ASC),
        CONSTRAINT FK_ACO_CLIENTE   FOREIGN KEY ([aco_cliente])                  REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_ACO_ACTIVO    FOREIGN KEY ([aco_activo])                   REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_ACO_PADRE     FOREIGN KEY ([aco_componente_padre])         REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_ACO_TIPO      FOREIGN KEY ([aco_componente_tipo])          REFERENCES [dbo].[Componente_Tipo] ([cto_id]),
        CONSTRAINT FK_ACO_POSICION  FOREIGN KEY ([aco_componente_posicion])      REFERENCES [dbo].[Componente_Posicion] ([cpn_id]),
        CONSTRAINT FK_ACO_CRITICIDAD FOREIGN KEY ([aco_criticidad_nivel])        REFERENCES [dbo].[Criticidad_Nivel] ([crn_id]),
        CONSTRAINT FK_ACO_ESTADO    FOREIGN KEY ([aco_activo_componente_estado]) REFERENCES [dbo].[Activo_Componente_Estado] ([ace_id]),
        CONSTRAINT FK_ACO_ORIGEN    FOREIGN KEY ([aco_registro_origen])          REFERENCES [dbo].[Registro_Origen] ([ror_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_ACO_UUID          ON [dbo].[Activo_Componente] ([aco_uuid])
    CREATE UNIQUE NONCLUSTERED INDEX UX_ACO_ACTIVO_CODIGO ON [dbo].[Activo_Componente] ([aco_activo], [aco_codigo])
    -- Un mismo tipo no puede repetirse en la misma posicion del mismo activo:
    -- es lo que evita dos "rodamiento lado A" en el mismo blower.
    CREATE UNIQUE NONCLUSTERED INDEX UX_ACO_ACTIVO_TIPO_POSICION
        ON [dbo].[Activo_Componente] ([aco_activo], [aco_componente_tipo], [aco_componente_posicion])
        WHERE [aco_habilitado] = 1 AND [aco_componente_posicion] IS NOT NULL
    PRINT 'Tabla Activo_Componente creada correctamente.'
END
ELSE PRINT 'Tabla Activo_Componente ya existe.'
GO


/* ========================================================================
   9. UNIDAD_MEDIDA (ume) -- la base de la conversion canonica

      ume_unidad_base apunta a si misma: NULL significa "yo SOY la base de
      mi magnitud". Con factor y offset se convierte cualquier unidad a su
      base, que es lo que hace comparables las mediciones de dos tecnicos
      que usaron escalas distintas.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Unidad_Medida]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Unidad_Medida]
    (
        [ume_id]                        INT             NOT NULL IDENTITY(1,1),
        [ume_magnitud]                  INT             NOT NULL,
        [ume_unidad_base]               INT             NULL,       -- NULL = es la base
        [ume_codigo]                    NVARCHAR(20)    NOT NULL,
        [ume_nombre]                    NVARCHAR(100)   NOT NULL,
        [ume_simbolo]                   NVARCHAR(20)    NOT NULL,
        [ume_factor]                    DECIMAL(18,6)   NOT NULL CONSTRAINT DF_UME_FACTOR DEFAULT 1,
        [ume_offset]                    DECIMAL(18,6)   NOT NULL CONSTRAINT DF_UME_OFFSET DEFAULT 0,
        [ume_usuario_creacion]          INT             NOT NULL,
        [ume_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_UME_FECHA_CREACION DEFAULT GETDATE(),
        [ume_usuario_actualizacion]     INT             NULL,
        [ume_fecha_actualizacion]       DATETIME        NULL,
        [ume_habilitado]                BIT             NOT NULL CONSTRAINT DF_UME_HABILITADO DEFAULT 1,

        CONSTRAINT PK_UNIDAD_MEDIDA PRIMARY KEY CLUSTERED ([ume_id] ASC),
        CONSTRAINT FK_UME_MAGNITUD FOREIGN KEY ([ume_magnitud])    REFERENCES [dbo].[Magnitud] ([mag_id]),
        CONSTRAINT FK_UME_BASE     FOREIGN KEY ([ume_unidad_base]) REFERENCES [dbo].[Unidad_Medida] ([ume_id]),
        CONSTRAINT UX_UME_CODIGO   UNIQUE ([ume_codigo])
    )
    -- Una sola unidad base por magnitud.
    CREATE UNIQUE NONCLUSTERED INDEX UX_UME_MAGNITUD_BASE
        ON [dbo].[Unidad_Medida] ([ume_magnitud]) WHERE [ume_unidad_base] IS NULL
    PRINT 'Tabla Unidad_Medida creada correctamente.'
END
ELSE PRINT 'Tabla Unidad_Medida ya existe.'
GO

/* ========================================================================
   8. ATRIBUTO_TECNICO (ate) y ACTIVO_ATRIBUTO (aat)

      Los datos de placa (RPM nominal, potencia, peso) no son columnas de
      Activo: son filas. Un blower y una amasadora tienen atributos
      distintos, y agregar una columna por cada dato tecnico de cada tipo
      de maquina termina en una tabla de doscientas columnas casi todas
      nulas. Aqui el tipo de maquina define que atributos aplican.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Atributo_Tecnico]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Atributo_Tecnico]
    (
        [ate_id]                        INT             NOT NULL IDENTITY(1,1),
        [ate_cliente]                   INT             NULL,       -- NULL = global
        [ate_activo_tipo]               INT             NULL,       -- a que tipo de maquina aplica
        [ate_tipo_dato]                 INT             NOT NULL,
        [ate_unidad_medida]             INT             NULL,
        [ate_codigo]                    NVARCHAR(50)    NOT NULL,   -- RPM NOMINAL, POTENCIA KW
        [ate_nombre]                    NVARCHAR(200)   NOT NULL,
        [ate_orden]                     INT             NULL,
        [ate_usuario_creacion]          INT             NOT NULL,
        [ate_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_ATE_FECHA_CREACION DEFAULT GETDATE(),
        [ate_usuario_actualizacion]     INT             NULL,
        [ate_fecha_actualizacion]       DATETIME        NULL,
        [ate_habilitado]                BIT             NOT NULL CONSTRAINT DF_ATE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ATRIBUTO_TECNICO PRIMARY KEY CLUSTERED ([ate_id] ASC),
        CONSTRAINT FK_ATE_CLIENTE     FOREIGN KEY ([ate_cliente])       REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_ATE_ACTIVO_TIPO FOREIGN KEY ([ate_activo_tipo])   REFERENCES [dbo].[Activo_Tipo] ([ati_id]),
        CONSTRAINT FK_ATE_TIPO_DATO   FOREIGN KEY ([ate_tipo_dato])     REFERENCES [dbo].[Tipo_Dato] ([tda_id]),
        CONSTRAINT FK_ATE_UNIDAD      FOREIGN KEY ([ate_unidad_medida]) REFERENCES [dbo].[Unidad_Medida] ([ume_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_ATE_CLIENTE_CODIGO ON [dbo].[Atributo_Tecnico] ([ate_cliente], [ate_codigo])
    PRINT 'Tabla Atributo_Tecnico creada correctamente.'
END
ELSE PRINT 'Tabla Atributo_Tecnico ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Atributo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Atributo]
    (
        [aat_id]                        INT             NOT NULL IDENTITY(1,1),
        [aat_cliente]                   INT             NOT NULL,
        [aat_activo]                    INT             NOT NULL,
        [aat_atributo_tecnico]          INT             NOT NULL,
        [aat_unidad_medida]             INT             NULL,
        -- Una columna por tipo. La API valida que solo la que corresponde
        -- a ate_tipo_dato este informada -- misma regla que en la respuesta
        -- de checklist. Un solo NVARCHAR obligaria a parsear para comparar.
        [aat_valor_texto]               NVARCHAR(500)   NULL,
        [aat_valor_numero]              DECIMAL(18,6)   NULL,
        [aat_valor_fecha]               DATETIME        NULL,
        [aat_valor_bit]                 BIT             NULL,
        [aat_usuario_creacion]          INT             NOT NULL,
        [aat_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_AAT_FECHA_CREACION DEFAULT GETDATE(),
        [aat_usuario_actualizacion]     INT             NULL,
        [aat_fecha_actualizacion]       DATETIME        NULL,
        [aat_habilitado]                BIT             NOT NULL CONSTRAINT DF_AAT_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ACTIVO_ATRIBUTO PRIMARY KEY CLUSTERED ([aat_id] ASC),
        CONSTRAINT FK_AAT_CLIENTE  FOREIGN KEY ([aat_cliente])          REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_AAT_ACTIVO   FOREIGN KEY ([aat_activo])           REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_AAT_ATRIBUTO FOREIGN KEY ([aat_atributo_tecnico]) REFERENCES [dbo].[Atributo_Tecnico] ([ate_id]),
        CONSTRAINT FK_AAT_UNIDAD   FOREIGN KEY ([aat_unidad_medida])    REFERENCES [dbo].[Unidad_Medida] ([ume_id]),
        -- Exactamente un valor informado.
        CONSTRAINT CK_AAT_UN_VALOR CHECK (
            (CASE WHEN [aat_valor_texto]  IS NOT NULL THEN 1 ELSE 0 END +
             CASE WHEN [aat_valor_numero] IS NOT NULL THEN 1 ELSE 0 END +
             CASE WHEN [aat_valor_fecha]  IS NOT NULL THEN 1 ELSE 0 END +
             CASE WHEN [aat_valor_bit]    IS NOT NULL THEN 1 ELSE 0 END) = 1)
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_AAT_ACTIVO_ATRIBUTO ON [dbo].[Activo_Atributo] ([aat_activo], [aat_atributo_tecnico])
    PRINT 'Tabla Activo_Atributo creada correctamente.'
END
ELSE PRINT 'Tabla Activo_Atributo ya existe.'
GO





/* ========================================================================
   10. VARIABLE_MEDICION (vme) -- que se mide, en general
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Variable_Medicion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Variable_Medicion]
    (
        [vme_id]                        INT             NOT NULL IDENTITY(1,1),
        [vme_cliente]                   INT             NULL,       -- NULL = global
        [vme_unidad_medida]             INT             NOT NULL,
        [vme_tipo_dato]                 INT             NOT NULL,
        [vme_codigo]                    NVARCHAR(50)    NOT NULL,
        [vme_nombre]                    NVARCHAR(200)   NOT NULL,
        [vme_decimales]                 INT             NOT NULL CONSTRAINT DF_VME_DECIMALES DEFAULT 2,
        [vme_relevante_ia]              BIT             NOT NULL CONSTRAINT DF_VME_RELEVANTE_IA DEFAULT 1,
        [vme_permite_manual]            BIT             NOT NULL CONSTRAINT DF_VME_MANUAL DEFAULT 1,
        [vme_permite_sensor]            BIT             NOT NULL CONSTRAINT DF_VME_SENSOR DEFAULT 0,
        [vme_descripcion]               NVARCHAR(500)   NULL,
        [vme_usuario_creacion]          INT             NOT NULL,
        [vme_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_VME_FECHA_CREACION DEFAULT GETDATE(),
        [vme_usuario_actualizacion]     INT             NULL,
        [vme_fecha_actualizacion]       DATETIME        NULL,
        [vme_habilitado]                BIT             NOT NULL CONSTRAINT DF_VME_HABILITADO DEFAULT 1,

        CONSTRAINT PK_VARIABLE_MEDICION PRIMARY KEY CLUSTERED ([vme_id] ASC),
        CONSTRAINT FK_VME_CLIENTE   FOREIGN KEY ([vme_cliente])       REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_VME_UNIDAD    FOREIGN KEY ([vme_unidad_medida]) REFERENCES [dbo].[Unidad_Medida] ([ume_id]),
        CONSTRAINT FK_VME_TIPO_DATO FOREIGN KEY ([vme_tipo_dato])     REFERENCES [dbo].[Tipo_Dato] ([tda_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_VME_CLIENTE_CODIGO ON [dbo].[Variable_Medicion] ([vme_cliente], [vme_codigo])
    PRINT 'Tabla Variable_Medicion creada correctamente.'
END
ELSE PRINT 'Tabla Variable_Medicion ya existe.'
GO


/* ========================================================================
   11. ACTIVO_VARIABLE (ava) -- que se mide en ESTA maquina, y con que rango

      Los umbrales de advertencia y critico viven aqui y no en la variable
      global: 80 °C es critico en un rodamiento y normal en un horno.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Variable]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Variable]
    (
        [ava_id]                        INT             NOT NULL IDENTITY(1,1),
        [ava_cliente]                   INT             NOT NULL,
        [ava_activo]                    INT             NOT NULL,
        [ava_activo_componente]         INT             NULL,
        [ava_variable_medicion]         INT             NOT NULL,
        [ava_unidad_medida]             INT             NOT NULL,
        [ava_valor_minimo]              DECIMAL(18,6)   NULL,
        [ava_valor_maximo]              DECIMAL(18,6)   NULL,
        [ava_valor_advertencia]         DECIMAL(18,6)   NULL,
        [ava_valor_critico]             DECIMAL(18,6)   NULL,
        [ava_frecuencia_esperada_hora]  INT             NULL,
        [ava_usuario_creacion]          INT             NOT NULL,
        [ava_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_AVA_FECHA_CREACION DEFAULT GETDATE(),
        [ava_usuario_actualizacion]     INT             NULL,
        [ava_fecha_actualizacion]       DATETIME        NULL,
        [ava_habilitado]                BIT             NOT NULL CONSTRAINT DF_AVA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ACTIVO_VARIABLE PRIMARY KEY CLUSTERED ([ava_id] ASC),
        CONSTRAINT FK_AVA_CLIENTE     FOREIGN KEY ([ava_cliente])            REFERENCES [dbo].[Cliente] ([cli_id]),
        -- FK COMPUESTA: una variable del cliente A no puede colgar de un activo del cliente B.
        CONSTRAINT FK_AVA_ACTIVO_CLIENTE FOREIGN KEY ([ava_cliente], [ava_activo])
            REFERENCES [dbo].[Activo] ([act_cliente], [act_id]),
        CONSTRAINT FK_AVA_COMPONENTE  FOREIGN KEY ([ava_activo_componente])  REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_AVA_VARIABLE    FOREIGN KEY ([ava_variable_medicion])  REFERENCES [dbo].[Variable_Medicion] ([vme_id]),
        CONSTRAINT FK_AVA_UNIDAD      FOREIGN KEY ([ava_unidad_medida])      REFERENCES [dbo].[Unidad_Medida] ([ume_id]),
        CONSTRAINT CK_AVA_RANGO       CHECK ([ava_valor_minimo] IS NULL OR [ava_valor_maximo] IS NULL
                                          OR [ava_valor_maximo] >= [ava_valor_minimo])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_AVA_ACTIVO_COMPONENTE_VARIABLE
        ON [dbo].[Activo_Variable] ([ava_activo], [ava_activo_componente], [ava_variable_medicion])
    PRINT 'Tabla Activo_Variable creada correctamente.'
END
ELSE PRINT 'Tabla Activo_Variable ya existe.'
GO


/* ========================================================================
   12. ACTIVO_MEDICION (amd) -- append-only, la tabla central del ML

      Cuatro columnas donde uno esperaria dos: valor + unidad como lo
      ingreso el tecnico, y valor + unidad canonicos. Ver la nota de la
      cabecera. amd_activo y amd_activo_componente estan denormalizados a
      proposito: sin ellos, filtrar el historial de un componente obliga a
      un JOIN en la tabla que mas crece de todo el modelo.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Medicion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Medicion]
    (
        [amd_id]                            INT                 NOT NULL IDENTITY(1,1),
        [amd_uuid]                          UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_AMD_UUID DEFAULT NEWID(),
        [amd_cliente]                       INT                 NOT NULL,
        [amd_activo_variable]               INT                 NOT NULL,
        [amd_activo]                        INT                 NOT NULL,   -- denormalizado
        [amd_activo_componente]             INT                 NULL,       -- denormalizado
        [amd_fecha_medicion_utc]            DATETIME            NOT NULL,
        [amd_valor]                         DECIMAL(18,6)       NOT NULL,   -- como lo ingreso el tecnico
        [amd_unidad_medida]                 INT                 NOT NULL,
        [amd_valor_canonico]                DECIMAL(18,6)       NOT NULL,   -- convertido a la base
        [amd_unidad_canonica]               INT                 NOT NULL,
        [amd_medicion_calidad]              INT                 NOT NULL,
        [amd_dato_origen]                   INT                 NOT NULL,
        [amd_entrada_modo]                  INT                 NULL,       -- teclado, voz, sensor...
        [amd_checklist_ejecucion_respuesta] INT                 NULL,       -- FK diferida (13)
        [amd_orden_trabajo]                 INT                 NULL,       -- FK diferida (15)
        [amd_observacion]                   NVARCHAR(500)       NULL,
        [amd_usuario_creacion]              INT                 NOT NULL,
        [amd_fecha_creacion]                DATETIME            NOT NULL CONSTRAINT DF_AMD_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_ACTIVO_MEDICION PRIMARY KEY CLUSTERED ([amd_id] ASC),
        CONSTRAINT FK_AMD_CLIENTE   FOREIGN KEY ([amd_cliente])            REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_AMD_VARIABLE  FOREIGN KEY ([amd_activo_variable])    REFERENCES [dbo].[Activo_Variable] ([ava_id]),
        CONSTRAINT FK_AMD_ACTIVO_CLIENTE FOREIGN KEY ([amd_cliente], [amd_activo])
            REFERENCES [dbo].[Activo] ([act_cliente], [act_id]),
        CONSTRAINT FK_AMD_COMPONENTE FOREIGN KEY ([amd_activo_componente]) REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_AMD_UNIDAD     FOREIGN KEY ([amd_unidad_medida])     REFERENCES [dbo].[Unidad_Medida] ([ume_id]),
        CONSTRAINT FK_AMD_UNIDAD_CAN FOREIGN KEY ([amd_unidad_canonica])   REFERENCES [dbo].[Unidad_Medida] ([ume_id]),
        CONSTRAINT FK_AMD_CALIDAD    FOREIGN KEY ([amd_medicion_calidad])  REFERENCES [dbo].[Medicion_Calidad] ([mca_id]),
        CONSTRAINT FK_AMD_ORIGEN     FOREIGN KEY ([amd_dato_origen])       REFERENCES [dbo].[Dato_Origen] ([dor_id]),
        CONSTRAINT FK_AMD_ENTRADA    FOREIGN KEY ([amd_entrada_modo])      REFERENCES [dbo].[Entrada_Modo] ([emo_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_AMD_UUID ON [dbo].[Activo_Medicion] ([amd_uuid])
    -- El indice que sostiene el dataset de ML y las tendencias.
    CREATE NONCLUSTERED INDEX IX_AMD_VARIABLE_FECHA
        ON [dbo].[Activo_Medicion] ([amd_activo_variable], [amd_fecha_medicion_utc] DESC)
        INCLUDE ([amd_valor_canonico], [amd_medicion_calidad])
    CREATE NONCLUSTERED INDEX IX_AMD_ACTIVO_FECHA
        ON [dbo].[Activo_Medicion] ([amd_cliente], [amd_activo], [amd_fecha_medicion_utc] DESC)
    PRINT 'Tabla Activo_Medicion creada correctamente.'
END
ELSE PRINT 'Tabla Activo_Medicion ya existe.'
GO


/* ========================================================================
   13. ACTIVO_MEDIDOR (ame) y ACTIVO_MEDIDOR_LECTURA (aml)

      ame_valor_actual es denormalizacion CONTROLADA: el motor de
      programacion por medidor lo consulta en cada evaluacion, y hacer
      MAX() sobre el historico en cada lectura no escala. La verdad sigue
      estando en las lecturas; el SP actualiza ambas en la misma
      transaccion.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Medidor]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Medidor]
    (
        [ame_id]                        INT             NOT NULL IDENTITY(1,1),
        [ame_cliente]                   INT             NOT NULL,
        [ame_activo]                    INT             NOT NULL,
        [ame_activo_componente]         INT             NULL,
        [ame_unidad_medida]             INT             NOT NULL,   -- H / CICLO / KM
        [ame_codigo]                    NVARCHAR(50)    NOT NULL,
        [ame_nombre]                    NVARCHAR(200)   NOT NULL,
        [ame_valor_actual]              DECIMAL(18,2)   NOT NULL CONSTRAINT DF_AME_VALOR_ACTUAL DEFAULT 0,
        [ame_fecha_valor_actual_utc]    DATETIME        NULL,
        [ame_valor_reinicio]            DECIMAL(18,2)   NULL,
        [ame_permite_reinicio]          BIT             NOT NULL CONSTRAINT DF_AME_PERMITE_REINICIO DEFAULT 0,
        [ame_usuario_creacion]          INT             NOT NULL,
        [ame_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_AME_FECHA_CREACION DEFAULT GETDATE(),
        [ame_usuario_actualizacion]     INT             NULL,
        [ame_fecha_actualizacion]       DATETIME        NULL,
        [ame_habilitado]                BIT             NOT NULL CONSTRAINT DF_AME_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ACTIVO_MEDIDOR PRIMARY KEY CLUSTERED ([ame_id] ASC),
        CONSTRAINT FK_AME_CLIENTE    FOREIGN KEY ([ame_cliente])           REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_AME_ACTIVO_CLIENTE FOREIGN KEY ([ame_cliente], [ame_activo])
            REFERENCES [dbo].[Activo] ([act_cliente], [act_id]),
        CONSTRAINT FK_AME_COMPONENTE FOREIGN KEY ([ame_activo_componente]) REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_AME_UNIDAD     FOREIGN KEY ([ame_unidad_medida])     REFERENCES [dbo].[Unidad_Medida] ([ume_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_AME_ACTIVO_CODIGO ON [dbo].[Activo_Medidor] ([ame_activo], [ame_codigo])
    PRINT 'Tabla Activo_Medidor creada correctamente.'
END
ELSE PRINT 'Tabla Activo_Medidor ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Medidor_Lectura]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Medidor_Lectura]
    (
        [aml_id]                    INT                 NOT NULL IDENTITY(1,1),
        [aml_uuid]                  UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_AML_UUID DEFAULT NEWID(),
        [aml_cliente]               INT                 NOT NULL,
        [aml_activo_medidor]        INT                 NOT NULL,
        [aml_fecha_lectura_utc]     DATETIME            NOT NULL,
        [aml_valor_acumulado]       DECIMAL(18,2)       NOT NULL,
        [aml_es_reinicio]           BIT                 NOT NULL CONSTRAINT DF_AML_ES_REINICIO DEFAULT 0,
        [aml_dato_origen]           INT                 NOT NULL,
        [aml_medicion_calidad]      INT                 NOT NULL,
        [aml_entrada_modo]          INT                 NULL,
        [aml_orden_trabajo]         INT                 NULL,       -- FK diferida (15)
        [aml_observacion]           NVARCHAR(500)       NULL,
        [aml_usuario_creacion]      INT                 NOT NULL,
        [aml_fecha_creacion]        DATETIME            NOT NULL CONSTRAINT DF_AML_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_ACTIVO_MEDIDOR_LECTURA PRIMARY KEY CLUSTERED ([aml_id] ASC),
        CONSTRAINT FK_AML_CLIENTE FOREIGN KEY ([aml_cliente])          REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_AML_MEDIDOR FOREIGN KEY ([aml_activo_medidor])   REFERENCES [dbo].[Activo_Medidor] ([ame_id]),
        CONSTRAINT FK_AML_ORIGEN  FOREIGN KEY ([aml_dato_origen])      REFERENCES [dbo].[Dato_Origen] ([dor_id]),
        CONSTRAINT FK_AML_CALIDAD FOREIGN KEY ([aml_medicion_calidad]) REFERENCES [dbo].[Medicion_Calidad] ([mca_id]),
        CONSTRAINT FK_AML_ENTRADA FOREIGN KEY ([aml_entrada_modo])     REFERENCES [dbo].[Entrada_Modo] ([emo_id]),
        CONSTRAINT CK_AML_VALOR   CHECK ([aml_valor_acumulado] >= 0)
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_AML_UUID ON [dbo].[Activo_Medidor_Lectura] ([aml_uuid])
    CREATE NONCLUSTERED INDEX IX_AML_MEDIDOR_FECHA
        ON [dbo].[Activo_Medidor_Lectura] ([aml_activo_medidor], [aml_fecha_lectura_utc] DESC)
    PRINT 'Tabla Activo_Medidor_Lectura creada correctamente.'
END
ELSE PRINT 'Tabla Activo_Medidor_Lectura ya existe.'
GO


PRINT 'Bloque D2 + D3 (activos, ubicacion tecnica, variables y mediciones) aplicado correctamente.'
GO
