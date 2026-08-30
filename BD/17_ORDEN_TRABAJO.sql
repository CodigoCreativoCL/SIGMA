USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  20-08-2026
-- DESCRIPTION:     D9 -- ORDEN DE TRABAJO, FALLAS E INDISPONIBILIDAD.
-- =============================================
-- Ver SIGMA_MODELO_LOGICO_v2.md §5.6, §5.8 y §8.9 · SIGMA_ANEXO_H
-- ORDEN: despues de 16_TAREAS.sql
--
-- "AL FINAL TODO TERMINA SIENDO UNA OT"
--   Esa frase del planificador es la regla de diseño de este bloque. No
--   existe una entidad Solicitud_Ot separada: lo que en otros sistemas es
--   una solicitud, aqui es una OT en estado ABIERTA con
--   otr_usuario_solicitante informado. Una tabla menos, un traspaso menos,
--   y ningun momento en que el trabajo "todavia no existe".
--
-- CUATRO ESTADOS, NO NUEVE
--   ABIERTA -> EN EJECUCION -> EN ESPERA DE CIERRE -> CERRADA
--
--   Se eliminaron ASIGNADA y VALIDADA porque son DERIVABLES: hay
--   asignacion si existe fila en Orden_Trabajo_Asignacion, y hay
--   validacion si existe fila en Orden_Trabajo_Validacion. Un estado que
--   se puede calcular no es un estado: es una consulta que alguien
--   duplico en una columna, y esa columna se desincroniza.
--
--   ANULADA tampoco es estado. Anular es CERRAR con
--   otr_cierre_motivo = ANULADA POR ERROR. Asi el correlativo no se
--   pierde y la OT anulada sigue siendo auditable.
--
-- QUIEN CIERRA
--   El tecnico puede ABRIR una correctiva, pero no puede cerrarla. Cierra
--   el jefe de mantenimiento, el supervisor o el planificador. Eso lo
--   controla FNC_USUARIO_PUEDE_CERRAR_OT (bloque 10).
--   EN ESPERA DE CIERRE no es burocracia: contar esas filas es medir
--   directamente el atraso del planificador.
--
-- EL EJECUTANTE PUEDE SER EXTERNO
--   Orden_Trabajo_Asignacion admite usuario, grupo O PROVEEDOR, con un
--   CHECK que exige exactamente uno. Es lo que permite registrar el
--   trabajo de Vixon sin inventarle un usuario del sistema.
--
-- LAS CINCO FK DE ORIGEN SON EXPLICITAS
--   plan / tarea / hallazgo / prediccion / falla. Se evaluo la
--   alternativa de tipo+id y se descarto: pierde integridad referencial.
--   otr_orden_trabajo_origen dice cual de las cinco esta informada.
--
-- IDEMPOTENTE: se puede ejecutar las veces que sea.
-- =============================================


/* ========================================================================
   1. FALLAS -- el vocabulario de lo que se rompe

      Cinco tablas antes de Orden_Trabajo porque la OT correctiva las
      referencia. Sintoma es lo que se OBSERVA ("ruido en el descanso"),
      modo es COMO fallo ("desgaste de pista interior"), causa es POR QUE
      ("falta de lubricacion"). Confundirlos es lo que convierte el
      analisis de fallas en una lista de anecdotas.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Falla_Sintoma]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Falla_Sintoma]
    (
        [fsi_id]                        INT             NOT NULL IDENTITY(1,1),
        [fsi_cliente]                   INT             NULL,       -- NULL = catalogo global SIGMA
        [fsi_activo_tipo]               INT             NULL,
        [fsi_codigo]                    NVARCHAR(50)    NOT NULL,
        [fsi_nombre]                    NVARCHAR(200)   NOT NULL,
        [fsi_descripcion]               NVARCHAR(500)   NULL,
        [fsi_usuario_creacion]          INT             NOT NULL,
        [fsi_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_FSI_FECHA_CREACION DEFAULT GETDATE(),
        [fsi_usuario_actualizacion]     INT             NULL,
        [fsi_fecha_actualizacion]       DATETIME        NULL,
        [fsi_habilitado]                BIT             NOT NULL CONSTRAINT DF_FSI_HABILITADO DEFAULT 1,

        CONSTRAINT PK_FALLA_SINTOMA PRIMARY KEY CLUSTERED ([fsi_id] ASC),
        CONSTRAINT FK_FSI_CLIENTE     FOREIGN KEY ([fsi_cliente])     REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_FSI_ACTIVO_TIPO FOREIGN KEY ([fsi_activo_tipo]) REFERENCES [dbo].[Activo_Tipo] ([ati_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_FSI_CLIENTE_CODIGO
        ON [dbo].[Falla_Sintoma] ([fsi_cliente], [fsi_codigo]) WHERE [fsi_cliente] IS NOT NULL
    CREATE UNIQUE NONCLUSTERED INDEX UX_FSI_GLOBAL_CODIGO
        ON [dbo].[Falla_Sintoma] ([fsi_codigo]) WHERE [fsi_cliente] IS NULL
    PRINT 'Tabla Falla_Sintoma creada correctamente.'
END
ELSE PRINT 'Tabla Falla_Sintoma ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Falla_Modo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Falla_Modo]
    (
        [fmo_id]                        INT             NOT NULL IDENTITY(1,1),
        [fmo_cliente]                   INT             NULL,
        [fmo_activo_tipo]               INT             NULL,
        [fmo_codigo]                    NVARCHAR(50)    NOT NULL,
        [fmo_nombre]                    NVARCHAR(200)   NOT NULL,
        [fmo_descripcion]               NVARCHAR(500)   NULL,
        [fmo_usuario_creacion]          INT             NOT NULL,
        [fmo_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_FMO_FECHA_CREACION DEFAULT GETDATE(),
        [fmo_usuario_actualizacion]     INT             NULL,
        [fmo_fecha_actualizacion]       DATETIME        NULL,
        [fmo_habilitado]                BIT             NOT NULL CONSTRAINT DF_FMO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_FALLA_MODO PRIMARY KEY CLUSTERED ([fmo_id] ASC),
        CONSTRAINT FK_FMO_CLIENTE     FOREIGN KEY ([fmo_cliente])     REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_FMO_ACTIVO_TIPO FOREIGN KEY ([fmo_activo_tipo]) REFERENCES [dbo].[Activo_Tipo] ([ati_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_FMO_CLIENTE_CODIGO
        ON [dbo].[Falla_Modo] ([fmo_cliente], [fmo_codigo]) WHERE [fmo_cliente] IS NOT NULL
    CREATE UNIQUE NONCLUSTERED INDEX UX_FMO_GLOBAL_CODIGO
        ON [dbo].[Falla_Modo] ([fmo_codigo]) WHERE [fmo_cliente] IS NULL
    PRINT 'Tabla Falla_Modo creada correctamente.'
END
ELSE PRINT 'Tabla Falla_Modo ya existe.'
GO

-- Falla_Causa es JERARQUICA: "falta de lubricacion" cuelga de "mantenimiento
-- deficiente". El arbol es lo que permite agrupar 40 fallas distintas en las
-- 5 causas raiz que de verdad hay que atacar.
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Falla_Causa]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Falla_Causa]
    (
        [fca_id]                        INT             NOT NULL IDENTITY(1,1),
        [fca_cliente]                   INT             NULL,
        [fca_causa_padre]               INT             NULL,
        [fca_codigo]                    NVARCHAR(50)    NOT NULL,
        [fca_nombre]                    NVARCHAR(200)   NOT NULL,
        [fca_descripcion]               NVARCHAR(500)   NULL,
        [fca_es_causa_raiz]             BIT             NOT NULL CONSTRAINT DF_FCA_RAIZ DEFAULT 0,
        [fca_usuario_creacion]          INT             NOT NULL,
        [fca_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_FCA_FECHA_CREACION DEFAULT GETDATE(),
        [fca_usuario_actualizacion]     INT             NULL,
        [fca_fecha_actualizacion]       DATETIME        NULL,
        [fca_habilitado]                BIT             NOT NULL CONSTRAINT DF_FCA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_FALLA_CAUSA PRIMARY KEY CLUSTERED ([fca_id] ASC),
        CONSTRAINT FK_FCA_CLIENTE FOREIGN KEY ([fca_cliente])     REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_FCA_PADRE   FOREIGN KEY ([fca_causa_padre]) REFERENCES [dbo].[Falla_Causa] ([fca_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_FCA_CLIENTE_CODIGO
        ON [dbo].[Falla_Causa] ([fca_cliente], [fca_codigo]) WHERE [fca_cliente] IS NOT NULL
    CREATE UNIQUE NONCLUSTERED INDEX UX_FCA_GLOBAL_CODIGO
        ON [dbo].[Falla_Causa] ([fca_codigo]) WHERE [fca_cliente] IS NULL
    PRINT 'Tabla Falla_Causa creada correctamente.'
END
ELSE PRINT 'Tabla Falla_Causa ya existe.'
GO

/* ------------------------------------------------------------------------
   FALLA (fal) -- el evento concreto

   fal_activo_estado_posterior guarda como quedo la maquina despues. Es
   lo que distingue "fallo y siguio operando con observacion" de "fallo y
   quedo fuera de servicio", y sin esa distincion el indicador de
   disponibilidad es un promedio sin sentido.
   ------------------------------------------------------------------------ */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Falla]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Falla]
    (
        [fal_id]                        INT                 NOT NULL IDENTITY(1,1),
        [fal_uuid]                      UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_FAL_UUID DEFAULT NEWID(),
        [fal_cliente]                   INT                 NOT NULL,
        [fal_activo]                    INT                 NOT NULL,
        [fal_activo_componente]         INT                 NULL,
        [fal_falla_sintoma]             INT                 NULL,
        [fal_criticidad_nivel]          INT                 NULL,
        [fal_titulo]                    NVARCHAR(200)       NOT NULL,
        [fal_descripcion]               NVARCHAR(MAX)       NULL,
        [fal_consecuencia]              NVARCHAR(500)       NULL,
        [fal_activo_estado_posterior]   INT                 NULL,
        [fal_detuvo_produccion]         BIT                 NOT NULL CONSTRAINT DF_FAL_DETUVO DEFAULT 0,
        [fal_fecha_deteccion_utc]       DATETIME            NOT NULL CONSTRAINT DF_FAL_FECHA_DETECCION DEFAULT GETUTCDATE(),
        [fal_fecha_solucion_utc]        DATETIME            NULL,
        [fal_usuario_reporta]           INT                 NOT NULL,
        [fal_usuario_creacion]          INT                 NOT NULL,
        [fal_fecha_creacion]            DATETIME            NOT NULL CONSTRAINT DF_FAL_FECHA_CREACION DEFAULT GETDATE(),
        [fal_usuario_actualizacion]     INT                 NULL,
        [fal_fecha_actualizacion]       DATETIME            NULL,
        [fal_habilitado]                BIT                 NOT NULL CONSTRAINT DF_FAL_HABILITADO DEFAULT 1,

        CONSTRAINT PK_FALLA PRIMARY KEY CLUSTERED ([fal_id] ASC),
        CONSTRAINT FK_FAL_CLIENTE     FOREIGN KEY ([fal_cliente])                 REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_FAL_ACTIVO      FOREIGN KEY ([fal_activo])                  REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_FAL_COMPONENTE  FOREIGN KEY ([fal_activo_componente])       REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_FAL_SINTOMA     FOREIGN KEY ([fal_falla_sintoma])           REFERENCES [dbo].[Falla_Sintoma] ([fsi_id]),
        CONSTRAINT FK_FAL_CRITICIDAD  FOREIGN KEY ([fal_criticidad_nivel])        REFERENCES [dbo].[Criticidad_Nivel] ([crn_id]),
        CONSTRAINT FK_FAL_ESTADO_POST FOREIGN KEY ([fal_activo_estado_posterior]) REFERENCES [dbo].[Activo_Estado] ([aes_id]),
        CONSTRAINT FK_FAL_REPORTA     FOREIGN KEY ([fal_usuario_reporta])         REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT UX_FAL_UUID UNIQUE ([fal_uuid]),
        CONSTRAINT CK_FAL_FECHAS CHECK ([fal_fecha_solucion_utc] IS NULL OR [fal_fecha_solucion_utc] >= [fal_fecha_deteccion_utc])
    )
    -- Este indice es el que hace barato el MTBF por activo.
    CREATE NONCLUSTERED INDEX IX_FAL_ACTIVO_FECHA ON [dbo].[Falla] ([fal_activo], [fal_fecha_deteccion_utc])
    PRINT 'Tabla Falla creada correctamente.'
END
ELSE PRINT 'Tabla Falla ya existe.'
GO

-- El diagnostico llega DESPUES de la falla y puede haber mas de uno
-- (primera hipotesis, hipotesis corregida al desarmar). Por eso es tabla
-- aparte y no columnas de Falla.
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Falla_Diagnostico]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Falla_Diagnostico]
    (
        [fdi_id]                        INT             NOT NULL IDENTITY(1,1),
        [fdi_falla]                     INT             NOT NULL,
        [fdi_falla_modo]                INT             NULL,
        [fdi_falla_causa]               INT             NULL,
        [fdi_diagnostico_metodo]        INT             NULL,       -- como se llego: MEDICION / TERMOGRAFIA / DESARME...
        [fdi_descripcion]               NVARCHAR(MAX)   NULL,
        [fdi_es_definitivo]             BIT             NOT NULL CONSTRAINT DF_FDI_DEFINITIVO DEFAULT 0,
        [fdi_confianza]                 DECIMAL(18,6)   NULL,
        [fdi_usuario_diagnostica]       INT             NOT NULL,
        [fdi_fecha_diagnostico_utc]     DATETIME        NOT NULL CONSTRAINT DF_FDI_FECHA DEFAULT GETUTCDATE(),
        [fdi_usuario_creacion]          INT             NOT NULL,
        [fdi_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_FDI_FECHA_CREACION DEFAULT GETDATE(),
        [fdi_usuario_actualizacion]     INT             NULL,
        [fdi_fecha_actualizacion]       DATETIME        NULL,
        [fdi_habilitado]                BIT             NOT NULL CONSTRAINT DF_FDI_HABILITADO DEFAULT 1,

        CONSTRAINT PK_FALLA_DIAGNOSTICO PRIMARY KEY CLUSTERED ([fdi_id] ASC),
        CONSTRAINT FK_FDI_FALLA       FOREIGN KEY ([fdi_falla])               REFERENCES [dbo].[Falla] ([fal_id]),
        CONSTRAINT FK_FDI_MODO        FOREIGN KEY ([fdi_falla_modo])          REFERENCES [dbo].[Falla_Modo] ([fmo_id]),
        CONSTRAINT FK_FDI_CAUSA       FOREIGN KEY ([fdi_falla_causa])         REFERENCES [dbo].[Falla_Causa] ([fca_id]),
        CONSTRAINT FK_FDI_METODO      FOREIGN KEY ([fdi_diagnostico_metodo])  REFERENCES [dbo].[Diagnostico_Metodo] ([dme_id]),
        CONSTRAINT FK_FDI_DIAGNOSTICA FOREIGN KEY ([fdi_usuario_diagnostica]) REFERENCES [dbo].[Usuario] ([usu_id])
    )
    CREATE NONCLUSTERED INDEX IX_FDI_FALLA ON [dbo].[Falla_Diagnostico] ([fdi_falla])
    PRINT 'Tabla Falla_Diagnostico creada correctamente.'
END
ELSE PRINT 'Tabla Falla_Diagnostico ya existe.'
GO

-- La accion correctiva. fac_es_definitiva separa el parche del arreglo:
-- "se apreto la brida" vs "se cambio el empaque". Sin esa distincion no se
-- puede detectar la maquina que se arregla mal cinco veces al año.
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Falla_Accion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Falla_Accion]
    (
        [fac_id]                        INT             NOT NULL IDENTITY(1,1),
        [fac_falla]                     INT             NOT NULL,
        [fac_falla_diagnostico]         INT             NULL,
        [fac_orden_trabajo]             INT             NULL,       -- FK diferida (bloque 22)
        [fac_descripcion]               NVARCHAR(MAX)   NOT NULL,
        [fac_es_definitiva]             BIT             NOT NULL CONSTRAINT DF_FAC_DEFINITIVA DEFAULT 0,
        [fac_fecha_accion_utc]          DATETIME        NOT NULL CONSTRAINT DF_FAC_FECHA DEFAULT GETUTCDATE(),
        [fac_usuario_ejecuta]           INT             NULL,
        [fac_usuario_creacion]          INT             NOT NULL,
        [fac_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_FAC_FECHA_CREACION DEFAULT GETDATE(),
        [fac_usuario_actualizacion]     INT             NULL,
        [fac_fecha_actualizacion]       DATETIME        NULL,
        [fac_habilitado]                BIT             NOT NULL CONSTRAINT DF_FAC_HABILITADO DEFAULT 1,

        CONSTRAINT PK_FALLA_ACCION PRIMARY KEY CLUSTERED ([fac_id] ASC),
        CONSTRAINT FK_FAC_FALLA       FOREIGN KEY ([fac_falla])             REFERENCES [dbo].[Falla] ([fal_id]),
        CONSTRAINT FK_FAC_DIAGNOSTICO FOREIGN KEY ([fac_falla_diagnostico]) REFERENCES [dbo].[Falla_Diagnostico] ([fdi_id]),
        CONSTRAINT FK_FAC_EJECUTA     FOREIGN KEY ([fac_usuario_ejecuta])   REFERENCES [dbo].[Usuario] ([usu_id])
    )
    CREATE NONCLUSTERED INDEX IX_FAC_FALLA ON [dbo].[Falla_Accion] ([fac_falla])
    PRINT 'Tabla Falla_Accion creada correctamente.'
END
ELSE PRINT 'Tabla Falla_Accion ya existe.'
GO


/* ========================================================================
   2. ORDEN_TRABAJO (otr) -- el centro del sistema

      otr_correlativo es el "N° 23074" que la planta usa para hablar. Es
      por cliente, no global: dos clientes distintos pueden tener ambos
      la OT 1. UX_OTR_CLIENTE_CORRELATIVO lo garantiza.

      otr_uuid existe para la app: si el telefono manda el mismo POST dos
      veces porque se corto la red, la segunda choca contra el UNIQUE en
      vez de crear una OT duplicada.

      otr_activo es NULL a proposito (correccion §5.8): existe trabajo
      real sobre un area sin activo definido -- "revisar la iluminacion
      de la sala de blowers".

      Las columnas de cierre (otr_fecha_cierre, otr_usuario_cierre,
      otr_cierre_motivo) y el enlace otr_ot_origen los agrega el
      bloque 10, que corre despues.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo]
    (
        [otr_id]                            INT                 NOT NULL IDENTITY(1,1),
        [otr_uuid]                          UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_OTR_UUID DEFAULT NEWID(),
        [otr_cliente]                       INT                 NOT NULL,
        [otr_cliente_instalacion]           INT                 NOT NULL,
        [otr_correlativo]                   INT                 NOT NULL,
        [otr_instalacion_area]              INT                 NULL,
        [otr_activo]                        INT                 NULL,
        [otr_activo_componente]             INT                 NULL,
        [otr_activo_posicion]               INT                 NULL,   -- congela donde estaba la maquina
        -- Clasificacion
        [otr_orden_trabajo_tipo]            INT                 NOT NULL,
        [otr_orden_trabajo_estrategia]      INT                 NOT NULL,
        [otr_orden_trabajo_origen]          INT                 NOT NULL,
        [otr_orden_trabajo_estado]          INT                 NOT NULL,
        [otr_orden_trabajo_prioridad]       INT                 NOT NULL,
        [otr_centro_costo]                  INT                 NULL,
        -- Personas
        [otr_usuario_generador]             INT                 NOT NULL,
        [otr_usuario_solicitante]           INT                 NULL,
        [otr_numero_solicitud]              NVARCHAR(50)        NULL,
        [otr_usuario_responsable]           INT                 NULL,
        -- Contenido
        [otr_titulo]                        NVARCHAR(200)       NOT NULL,
        [otr_descripcion]                   NVARCHAR(MAX)       NULL,
        [otr_notas]                         NVARCHAR(MAX)       NULL,
        [otr_resultado]                     NVARCHAR(MAX)       NULL,
        -- Tiempos
        [otr_fecha_evento_utc]              DATETIME            NULL,
        [otr_fecha_programada_utc]          DATETIME            NULL,
        [otr_fecha_inicio_real_utc]         DATETIME            NULL,
        [otr_fecha_fin_real_utc]            DATETIME            NULL,
        [otr_duracion_estimada_minuto]      INT                 NULL,
        [otr_duracion_real_minuto]          INT                 NULL,
        [otr_minuto_parada_activo]          INT                 NULL,
        [otr_requiere_permiso]              BIT                 NOT NULL CONSTRAINT DF_OTR_PERMISO DEFAULT 0,
        -- Trazabilidad de origen: cinco FK explicitas, una informada
        [otr_plan_mantenimiento_ocurrencia] INT                 NULL,
        [otr_tarea_ocurrencia]              INT                 NULL,
        [otr_checklist_hallazgo]            INT                 NULL,
        [otr_prediccion]                    INT                 NULL,   -- FK diferida (bloque 22)
        [otr_falla]                         INT                 NULL,
        [otr_usuario_creacion]              INT                 NOT NULL,
        [otr_fecha_creacion]                DATETIME            NOT NULL CONSTRAINT DF_OTR_FECHA_CREACION DEFAULT GETDATE(),
        [otr_usuario_actualizacion]         INT                 NULL,
        [otr_fecha_actualizacion]           DATETIME            NULL,
        [otr_habilitado]                    BIT                 NOT NULL CONSTRAINT DF_OTR_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ORDEN_TRABAJO PRIMARY KEY CLUSTERED ([otr_id] ASC),
        CONSTRAINT FK_OTR_CLIENTE      FOREIGN KEY ([otr_cliente])                  REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_OTR_INSTALACION  FOREIGN KEY ([otr_cliente_instalacion])      REFERENCES [dbo].[Cliente_Instalacion] ([cin_id]),
        CONSTRAINT FK_OTR_AREA         FOREIGN KEY ([otr_instalacion_area])         REFERENCES [dbo].[Instalacion_Area] ([iar_id]),
        CONSTRAINT FK_OTR_ACTIVO       FOREIGN KEY ([otr_activo])                   REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_OTR_COMPONENTE   FOREIGN KEY ([otr_activo_componente])        REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_OTR_POSICION     FOREIGN KEY ([otr_activo_posicion])          REFERENCES [dbo].[Activo_Posicion] ([apo_id]),
        CONSTRAINT FK_OTR_TIPO         FOREIGN KEY ([otr_orden_trabajo_tipo])       REFERENCES [dbo].[Orden_Trabajo_Tipo] ([ott_id]),
        CONSTRAINT FK_OTR_ESTRATEGIA   FOREIGN KEY ([otr_orden_trabajo_estrategia]) REFERENCES [dbo].[Orden_Trabajo_Estrategia] ([oet_id]),
        CONSTRAINT FK_OTR_ORIGEN       FOREIGN KEY ([otr_orden_trabajo_origen])     REFERENCES [dbo].[Orden_Trabajo_Origen] ([oto_id]),
        CONSTRAINT FK_OTR_ESTADO       FOREIGN KEY ([otr_orden_trabajo_estado])     REFERENCES [dbo].[Orden_Trabajo_Estado] ([ote_id]),
        CONSTRAINT FK_OTR_PRIORIDAD    FOREIGN KEY ([otr_orden_trabajo_prioridad])  REFERENCES [dbo].[Orden_Trabajo_Prioridad] ([opr_id]),
        CONSTRAINT FK_OTR_CENTRO_COSTO FOREIGN KEY ([otr_centro_costo])             REFERENCES [dbo].[Centro_Costo] ([cco_id]),
        CONSTRAINT FK_OTR_GENERADOR    FOREIGN KEY ([otr_usuario_generador])        REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_OTR_SOLICITANTE  FOREIGN KEY ([otr_usuario_solicitante])      REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_OTR_RESPONSABLE  FOREIGN KEY ([otr_usuario_responsable])      REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_OTR_PMO          FOREIGN KEY ([otr_plan_mantenimiento_ocurrencia]) REFERENCES [dbo].[Plan_Mantenimiento_Ocurrencia] ([pmo_id]),
        CONSTRAINT FK_OTR_TAREA_OCU    FOREIGN KEY ([otr_tarea_ocurrencia])         REFERENCES [dbo].[Tarea_Ocurrencia] ([toc_id]),
        CONSTRAINT FK_OTR_HALLAZGO     FOREIGN KEY ([otr_checklist_hallazgo])       REFERENCES [dbo].[Checklist_Hallazgo] ([cha_id]),
        CONSTRAINT FK_OTR_FALLA        FOREIGN KEY ([otr_falla])                    REFERENCES [dbo].[Falla] ([fal_id]),
        CONSTRAINT UX_OTR_UUID UNIQUE ([otr_uuid]),
        -- El "N 23074" de la planta. Por cliente, no global.
        CONSTRAINT UX_OTR_CLIENTE_CORRELATIVO UNIQUE ([otr_cliente], [otr_correlativo]),
        -- Necesaria para las FK compuestas de multitenencia (ver §5.3).
        CONSTRAINT UX_OTR_CLIENTE_ID UNIQUE ([otr_cliente], [otr_id]),
        CONSTRAINT CK_OTR_FECHAS CHECK
            ([otr_fecha_fin_real_utc] IS NULL OR [otr_fecha_inicio_real_utc] IS NULL
             OR [otr_fecha_fin_real_utc] >= [otr_fecha_inicio_real_utc]),
        CONSTRAINT CK_OTR_DURACION CHECK
            ([otr_duracion_real_minuto] IS NULL OR [otr_duracion_real_minuto] >= 0),
        -- El origen declarado y la FK informada tienen que coincidir.
        -- 2 PLAN · 3 TAREA · 4 HALLAZGO CHECKLIST · 5 PREDICCION · 7 FALLA
        CONSTRAINT CK_OTR_ORIGEN_COHERENTE CHECK
            (   ([otr_orden_trabajo_origen] = 2 AND [otr_plan_mantenimiento_ocurrencia] IS NOT NULL)
             OR ([otr_orden_trabajo_origen] = 3 AND [otr_tarea_ocurrencia]              IS NOT NULL)
             OR ([otr_orden_trabajo_origen] = 4 AND [otr_checklist_hallazgo]            IS NOT NULL)
             OR ([otr_orden_trabajo_origen] = 5 AND [otr_prediccion]                    IS NOT NULL)
             OR ([otr_orden_trabajo_origen] = 7 AND [otr_falla]                         IS NOT NULL)
             OR  [otr_orden_trabajo_origen] NOT IN (2, 3, 4, 5, 7))
    )
    -- El tablero del planificador filtra por estado y fecha: este indice lo cubre.
    CREATE NONCLUSTERED INDEX IX_OTR_CLIENTE_ESTADO_FECHA
        ON [dbo].[Orden_Trabajo] ([otr_cliente], [otr_orden_trabajo_estado], [otr_fecha_programada_utc])
    CREATE NONCLUSTERED INDEX IX_OTR_ACTIVO_FECHA
        ON [dbo].[Orden_Trabajo] ([otr_activo], [otr_fecha_creacion])
    PRINT 'Tabla Orden_Trabajo creada correctamente.'
END
ELSE PRINT 'Tabla Orden_Trabajo ya existe.'
GO


/* ========================================================================
   3. ORDEN_TRABAJO_ASIGNACION (ota)

      Tres destinatarios posibles y un CHECK que exige exactamente uno:
        usuario   -> el tecnico de planta
        grupo     -> el turno
        proveedor -> el externo (Vixon)

      El bloque 10 agrega ota_proveedor y ota_asignado_por junto con el
      CHECK definitivo; aqui se crea la forma base.

      "Si la toma un tecnico el otro no puede tomarla, pero el que la
      tomo si puede sumar a otro": eso es una fila con
      ota_es_responsable = 1 y las demas en 0. La exclusividad de la
      TOMA la resuelve el SP con UPDATE ... WHERE estado = ABIERTA, no
      una constraint.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Asignacion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo_Asignacion]
    (
        [ota_id]                        INT             NOT NULL IDENTITY(1,1),
        [ota_orden_trabajo]             INT             NOT NULL,
        [ota_usuario]                   INT             NULL,
        [ota_grupo_trabajo]             INT             NULL,
        [ota_es_responsable]            BIT             NOT NULL CONSTRAINT DF_OTA_RESPONSABLE DEFAULT 0,
        [ota_rol_ejecucion]             INT             NULL,       -- EJECUTOR PRINCIPAL / APOYO / SUPERVISOR / OBSERVADOR
        [ota_fecha_asignacion_utc]      DATETIME        NOT NULL CONSTRAINT DF_OTA_FECHA_ASIGNACION DEFAULT GETUTCDATE(),
        [ota_fecha_aceptacion_utc]      DATETIME        NULL,
        [ota_observacion]               NVARCHAR(500)   NULL,
        [ota_usuario_creacion]          INT             NOT NULL,
        [ota_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_OTA_FECHA_CREACION DEFAULT GETDATE(),
        [ota_usuario_actualizacion]     INT             NULL,
        [ota_fecha_actualizacion]       DATETIME        NULL,
        [ota_habilitado]                BIT             NOT NULL CONSTRAINT DF_OTA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ORDEN_TRABAJO_ASIGNACION PRIMARY KEY CLUSTERED ([ota_id] ASC),
        CONSTRAINT FK_OTA_ORDEN_TRABAJO FOREIGN KEY ([ota_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id]),
        CONSTRAINT FK_OTA_USUARIO       FOREIGN KEY ([ota_usuario])       REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_OTA_GRUPO         FOREIGN KEY ([ota_grupo_trabajo]) REFERENCES [dbo].[Grupo_Trabajo] ([gtr_id]),
        CONSTRAINT FK_OTA_ROL           FOREIGN KEY ([ota_rol_ejecucion]) REFERENCES [dbo].[Rol_Ejecucion] ([rej_id])
    )
    CREATE NONCLUSTERED INDEX IX_OTA_ORDEN_TRABAJO ON [dbo].[Orden_Trabajo_Asignacion] ([ota_orden_trabajo])
    CREATE NONCLUSTERED INDEX IX_OTA_USUARIO ON [dbo].[Orden_Trabajo_Asignacion] ([ota_usuario]) WHERE [ota_usuario] IS NOT NULL
    -- Un solo responsable por OT. Dos responsables es no tener ninguno.
    CREATE UNIQUE NONCLUSTERED INDEX UX_OTA_RESPONSABLE
        ON [dbo].[Orden_Trabajo_Asignacion] ([ota_orden_trabajo]) WHERE [ota_es_responsable] = 1
    PRINT 'Tabla Orden_Trabajo_Asignacion creada correctamente.'
END
ELSE PRINT 'Tabla Orden_Trabajo_Asignacion ya existe.'
GO


/* ========================================================================
   4. ORDEN_TRABAJO_ESPECIALIDAD (oep) -- la "Calificacion" del formato
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Especialidad]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo_Especialidad]
    (
        [oep_id]                        INT         NOT NULL IDENTITY(1,1),
        [oep_orden_trabajo]             INT         NOT NULL,
        [oep_especialidad]              INT         NOT NULL,
        [oep_cantidad_persona]          INT         NOT NULL CONSTRAINT DF_OEP_CANTIDAD DEFAULT 1,
        [oep_usuario_creacion]          INT         NOT NULL,
        [oep_fecha_creacion]            DATETIME    NOT NULL CONSTRAINT DF_OEP_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_ORDEN_TRABAJO_ESPECIALIDAD PRIMARY KEY CLUSTERED ([oep_id] ASC),
        CONSTRAINT FK_OEP_ORDEN_TRABAJO FOREIGN KEY ([oep_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id]),
        CONSTRAINT FK_OEP_ESPECIALIDAD  FOREIGN KEY ([oep_especialidad])  REFERENCES [dbo].[Especialidad] ([esp_id]),
        CONSTRAINT UX_OEP_ORDEN_ESPECIALIDAD UNIQUE ([oep_orden_trabajo], [oep_especialidad]),
        CONSTRAINT CK_OEP_CANTIDAD CHECK ([oep_cantidad_persona] >= 1)
    )
    PRINT 'Tabla Orden_Trabajo_Especialidad creada correctamente.'
END
ELSE PRINT 'Tabla Orden_Trabajo_Especialidad ya existe.'
GO


/* ========================================================================
   5. ORDEN_TRABAJO_PASO (otp)

      otp_descripcion es una COPIA del texto del procedimiento, no una
      referencia. Es deliberado: si el procedimiento cambia el año que
      viene, la OT ejecutada tiene que seguir mostrando lo que el tecnico
      leyo. otp_procedimiento_paso conserva de donde salio.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Paso]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo_Paso]
    (
        [otp_id]                        INT             NOT NULL IDENTITY(1,1),
        [otp_orden_trabajo]             INT             NOT NULL,
        [otp_procedimiento_paso]        INT             NULL,
        [otp_plan_mantenimiento_actividad] INT          NULL,
        [otp_orden]                     INT             NOT NULL CONSTRAINT DF_OTP_ORDEN DEFAULT 1,
        [otp_nombre]                    NVARCHAR(200)   NOT NULL,
        [otp_descripcion]               NVARCHAR(MAX)   NULL,       -- copia congelada
        [otp_obligatorio]               BIT             NOT NULL CONSTRAINT DF_OTP_OBLIGATORIO DEFAULT 1,
        [otp_resultado_paso]            INT             NOT NULL,   -- CONFORME / NO CONFORME / NO APLICA / PENDIENTE
        [otp_resultado]                 NVARCHAR(MAX)   NULL,
        [otp_usuario_ejecutor]          INT             NULL,
        [otp_fecha_ejecucion_utc]       DATETIME        NULL,
        [otp_usuario_creacion]          INT             NOT NULL,
        [otp_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_OTP_FECHA_CREACION DEFAULT GETDATE(),
        [otp_usuario_actualizacion]     INT             NULL,
        [otp_fecha_actualizacion]       DATETIME        NULL,
        [otp_habilitado]                BIT             NOT NULL CONSTRAINT DF_OTP_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ORDEN_TRABAJO_PASO PRIMARY KEY CLUSTERED ([otp_id] ASC),
        CONSTRAINT FK_OTP_ORDEN_TRABAJO FOREIGN KEY ([otp_orden_trabajo])                REFERENCES [dbo].[Orden_Trabajo] ([otr_id]),
        CONSTRAINT FK_OTP_PROC_PASO     FOREIGN KEY ([otp_procedimiento_paso])           REFERENCES [dbo].[Procedimiento_Paso] ([ppa_id]),
        CONSTRAINT FK_OTP_ACTIVIDAD     FOREIGN KEY ([otp_plan_mantenimiento_actividad]) REFERENCES [dbo].[Plan_Mantenimiento_Actividad] ([paa_id]),
        CONSTRAINT FK_OTP_EJECUTOR      FOREIGN KEY ([otp_usuario_ejecutor])             REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_OTP_RESULTADO     FOREIGN KEY ([otp_resultado_paso])               REFERENCES [dbo].[Resultado_Paso] ([rpa_id]),
        CONSTRAINT UX_OTP_ORDEN_SECUENCIA UNIQUE ([otp_orden_trabajo], [otp_orden]),
        CONSTRAINT CK_OTP_ORDEN CHECK ([otp_orden] >= 1),
        -- Completar exige quien y cuando.
        -- Todo paso resuelto exige quien y cuando. Estado 4 = PENDIENTE.
        CONSTRAINT CK_OTP_RESUELTO CHECK
            ([otp_resultado_paso] = 4 OR ([otp_usuario_ejecutor] IS NOT NULL AND [otp_fecha_ejecucion_utc] IS NOT NULL))
    )
    PRINT 'Tabla Orden_Trabajo_Paso creada correctamente.'
END
ELSE PRINT 'Tabla Orden_Trabajo_Paso ya existe.'
GO


/* ========================================================================
   6. ORDEN_TRABAJO_MANO_OBRA (omo) -- append-only

      Cada bloque de trabajo, no un total. Con las filas se calcula la
      duracion real, se separa hora normal de hora extra y se puede
      valorizar al proveedor: las nueve horas de Vixon a 2,4 UF cada una
      salen de sumar estas filas, no de un campo que alguien tipeo.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Mano_Obra]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo_Mano_Obra]
    (
        [omo_id]                        INT             NOT NULL IDENTITY(1,1),
        [omo_orden_trabajo]             INT             NOT NULL,
        [omo_usuario]                   INT             NULL,
        [omo_proveedor]                 INT             NULL,
        [omo_especialidad]              INT             NULL,
        [omo_fecha_inicio_utc]          DATETIME        NOT NULL,
        [omo_fecha_fin_utc]             DATETIME        NULL,
        [omo_minuto]                    INT             NOT NULL,
        [omo_es_hora_extra]             BIT             NOT NULL CONSTRAINT DF_OMO_HORA_EXTRA DEFAULT 0,
        [omo_costo_hora]                DECIMAL(18,2)   NULL,
        [omo_moneda]                    INT             NULL,
        [omo_observacion]               NVARCHAR(500)   NULL,
        [omo_usuario_creacion]          INT             NOT NULL,
        [omo_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_OMO_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_ORDEN_TRABAJO_MANO_OBRA PRIMARY KEY CLUSTERED ([omo_id] ASC),
        CONSTRAINT FK_OMO_ORDEN_TRABAJO FOREIGN KEY ([omo_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id]),
        CONSTRAINT FK_OMO_USUARIO       FOREIGN KEY ([omo_usuario])       REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_OMO_PROVEEDOR     FOREIGN KEY ([omo_proveedor])     REFERENCES [dbo].[Proveedor] ([prv_id]),
        CONSTRAINT FK_OMO_ESPECIALIDAD  FOREIGN KEY ([omo_especialidad])  REFERENCES [dbo].[Especialidad] ([esp_id]),
        CONSTRAINT FK_OMO_MONEDA        FOREIGN KEY ([omo_moneda])        REFERENCES [dbo].[Moneda] ([mon_id]),
        -- Interno o externo, exactamente uno. Horas de nadie no existen.
        CONSTRAINT CK_OMO_EJECUTANTE CHECK
            ((CASE WHEN [omo_usuario] IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN [omo_proveedor] IS NULL THEN 0 ELSE 1 END) = 1),
        CONSTRAINT CK_OMO_MINUTO CHECK ([omo_minuto] > 0),
        CONSTRAINT CK_OMO_FECHAS CHECK ([omo_fecha_fin_utc] IS NULL OR [omo_fecha_fin_utc] >= [omo_fecha_inicio_utc])
    )
    CREATE NONCLUSTERED INDEX IX_OMO_ORDEN_TRABAJO ON [dbo].[Orden_Trabajo_Mano_Obra] ([omo_orden_trabajo])
    PRINT 'Tabla Orden_Trabajo_Mano_Obra creada correctamente.'
END
ELSE PRINT 'Tabla Orden_Trabajo_Mano_Obra ya existe.'
GO


/* ========================================================================
   7. ORDEN_TRABAJO_REPUESTO (ore)

      Cuatro cantidades y no una: planificada (lo que el plan pedia),
      reservada (lo que la bodega aparto), consumida (lo que realmente se
      uso) y devuelta (lo que volvio). La diferencia entre planificada y
      consumida es exactamente el dato que corrige el plan del año que
      viene.

      El bloque 10 agrega los horometros de retiro e instalacion.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Repuesto]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo_Repuesto]
    (
        [ore_id]                              INT             NOT NULL IDENTITY(1,1),
        [ore_orden_trabajo]                   INT             NOT NULL,
        [ore_repuesto]                        INT             NOT NULL,
        [ore_repuesto_lote]                   INT             NULL,
        [ore_activo_componente]               INT             NULL,
        [ore_componente_repuesto_instalacion] INT             NULL,
        [ore_cantidad_planificada]            DECIMAL(18,4)   NULL,
        [ore_cantidad_reservada]              DECIMAL(18,4)   NULL,
        [ore_cantidad_consumida]              DECIMAL(18,4)   NULL,
        [ore_cantidad_devuelta]               DECIMAL(18,4)   NULL,
        [ore_costo_unitario]                  DECIMAL(18,2)   NULL,
        [ore_moneda]                          INT             NULL,
        [ore_observacion]                     NVARCHAR(500)   NULL,
        [ore_usuario_creacion]                INT             NOT NULL,
        [ore_fecha_creacion]                  DATETIME        NOT NULL CONSTRAINT DF_ORE_FECHA_CREACION DEFAULT GETDATE(),
        [ore_usuario_actualizacion]           INT             NULL,
        [ore_fecha_actualizacion]             DATETIME        NULL,
        [ore_habilitado]                      BIT             NOT NULL CONSTRAINT DF_ORE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ORDEN_TRABAJO_REPUESTO PRIMARY KEY CLUSTERED ([ore_id] ASC),
        CONSTRAINT FK_ORE_ORDEN_TRABAJO FOREIGN KEY ([ore_orden_trabajo])                   REFERENCES [dbo].[Orden_Trabajo] ([otr_id]),
        CONSTRAINT FK_ORE_REPUESTO      FOREIGN KEY ([ore_repuesto])                        REFERENCES [dbo].[Repuesto] ([rep_id]),
        CONSTRAINT FK_ORE_LOTE          FOREIGN KEY ([ore_repuesto_lote])                   REFERENCES [dbo].[Repuesto_Lote] ([rlo_id]),
        CONSTRAINT FK_ORE_COMPONENTE    FOREIGN KEY ([ore_activo_componente])               REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_ORE_INSTALACION   FOREIGN KEY ([ore_componente_repuesto_instalacion]) REFERENCES [dbo].[Componente_Repuesto_Instalacion] ([cri_id]),
        CONSTRAINT FK_ORE_MONEDA        FOREIGN KEY ([ore_moneda])                          REFERENCES [dbo].[Moneda] ([mon_id]),
        CONSTRAINT CK_ORE_CANTIDADES CHECK
            (([ore_cantidad_planificada] IS NULL OR [ore_cantidad_planificada] >= 0)
         AND ([ore_cantidad_reservada]   IS NULL OR [ore_cantidad_reservada]   >= 0)
         AND ([ore_cantidad_consumida]   IS NULL OR [ore_cantidad_consumida]   >= 0)
         AND ([ore_cantidad_devuelta]    IS NULL OR [ore_cantidad_devuelta]    >= 0))
    )
    CREATE NONCLUSTERED INDEX IX_ORE_ORDEN_TRABAJO ON [dbo].[Orden_Trabajo_Repuesto] ([ore_orden_trabajo])
    CREATE NONCLUSTERED INDEX IX_ORE_REPUESTO ON [dbo].[Orden_Trabajo_Repuesto] ([ore_repuesto])
    PRINT 'Tabla Orden_Trabajo_Repuesto creada correctamente.'
END
ELSE PRINT 'Tabla Orden_Trabajo_Repuesto ya existe.'
GO


/* ========================================================================
   8. ORDEN_TRABAJO_CHECKLIST (otc)
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Checklist]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo_Checklist]
    (
        [otc_id]                          INT       NOT NULL IDENTITY(1,1),
        [otc_orden_trabajo]               INT       NOT NULL,
        [otc_checklist_plantilla_version] INT       NOT NULL,
        [otc_checklist_ocurrencia]        INT       NULL,
        [otc_checklist_ejecucion]         INT       NULL,
        [otc_momento_ejecucion]           INT       NOT NULL,
        [otc_obligatorio]                 BIT       NOT NULL CONSTRAINT DF_OTC_OBLIGATORIO DEFAULT 1,
        [otc_usuario_creacion]            INT       NOT NULL,
        [otc_fecha_creacion]              DATETIME  NOT NULL CONSTRAINT DF_OTC_FECHA_CREACION DEFAULT GETDATE(),
        [otc_usuario_actualizacion]       INT       NULL,
        [otc_fecha_actualizacion]         DATETIME  NULL,
        [otc_habilitado]                  BIT       NOT NULL CONSTRAINT DF_OTC_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ORDEN_TRABAJO_CHECKLIST PRIMARY KEY CLUSTERED ([otc_id] ASC),
        CONSTRAINT FK_OTC_ORDEN_TRABAJO FOREIGN KEY ([otc_orden_trabajo])               REFERENCES [dbo].[Orden_Trabajo] ([otr_id]),
        CONSTRAINT FK_OTC_VERSION       FOREIGN KEY ([otc_checklist_plantilla_version]) REFERENCES [dbo].[Checklist_Plantilla_Version] ([cpv_id]),
        CONSTRAINT FK_OTC_OCURRENCIA    FOREIGN KEY ([otc_checklist_ocurrencia])        REFERENCES [dbo].[Checklist_Ocurrencia] ([coc_id]),
        CONSTRAINT FK_OTC_EJECUCION     FOREIGN KEY ([otc_checklist_ejecucion])         REFERENCES [dbo].[Checklist_Ejecucion] ([cej_id]),
        CONSTRAINT FK_OTC_MOMENTO       FOREIGN KEY ([otc_momento_ejecucion])           REFERENCES [dbo].[Momento_Ejecucion] ([moe_id]),
        CONSTRAINT UX_OTC_ORDEN_VERSION_MOMENTO UNIQUE ([otc_orden_trabajo], [otc_checklist_plantilla_version], [otc_momento_ejecucion])
    )
    PRINT 'Tabla Orden_Trabajo_Checklist creada correctamente.'
END
ELSE PRINT 'Tabla Orden_Trabajo_Checklist ya existe.'
GO


/* ========================================================================
   9. ORDEN_TRABAJO_SERVICIO (ots) -- lo que se le compra al externo

      Cada linea del informe de Vixon es una fila aqui: horas de servicio,
      arriendo de la grua, el montaje, el desmontaje. ots_documento_
      referencia guarda la OC o la factura, que es lo que pide finanzas
      cuando pregunta de donde salio el gasto.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Servicio]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo_Servicio]
    (
        [ots_id]                        INT             NOT NULL IDENTITY(1,1),
        [ots_orden_trabajo]             INT             NOT NULL,
        [ots_proveedor]                 INT             NOT NULL,
        [ots_servicio_tipo]             INT             NOT NULL,
        [ots_descripcion]               NVARCHAR(500)   NOT NULL,
        [ots_cantidad]                  DECIMAL(18,4)   NULL,
        [ots_monto_unitario]            DECIMAL(18,2)   NULL,
        [ots_monto]                     DECIMAL(18,2)   NOT NULL,
        [ots_moneda]                    INT             NULL,
        [ots_documento_referencia]      NVARCHAR(100)   NULL,       -- OC / factura / guia
        [ots_fecha_servicio_utc]        DATETIME        NULL,
        [ots_fecha_documento]           DATE            NULL,
        [ots_usuario_creacion]          INT             NOT NULL,
        [ots_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_OTS_FECHA_CREACION DEFAULT GETDATE(),
        [ots_usuario_actualizacion]     INT             NULL,
        [ots_fecha_actualizacion]       DATETIME        NULL,
        [ots_habilitado]                BIT             NOT NULL CONSTRAINT DF_OTS_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ORDEN_TRABAJO_SERVICIO PRIMARY KEY CLUSTERED ([ots_id] ASC),
        CONSTRAINT FK_OTS_ORDEN_TRABAJO FOREIGN KEY ([ots_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id]),
        CONSTRAINT FK_OTS_PROVEEDOR     FOREIGN KEY ([ots_proveedor])     REFERENCES [dbo].[Proveedor] ([prv_id]),
        CONSTRAINT FK_OTS_MONEDA        FOREIGN KEY ([ots_moneda])        REFERENCES [dbo].[Moneda] ([mon_id]),
        CONSTRAINT FK_OTS_TIPO          FOREIGN KEY ([ots_servicio_tipo]) REFERENCES [dbo].[Servicio_Tipo] ([sti_id]),
        CONSTRAINT CK_OTS_MONTO CHECK ([ots_monto] >= 0)
    )
    CREATE NONCLUSTERED INDEX IX_OTS_ORDEN_TRABAJO ON [dbo].[Orden_Trabajo_Servicio] ([ots_orden_trabajo])
    CREATE NONCLUSTERED INDEX IX_OTS_PROVEEDOR ON [dbo].[Orden_Trabajo_Servicio] ([ots_proveedor], [ots_fecha_servicio_utc])
    PRINT 'Tabla Orden_Trabajo_Servicio creada correctamente.'
END
ELSE PRINT 'Tabla Orden_Trabajo_Servicio ya existe.'
GO


/* ========================================================================
   10. ORDEN_TRABAJO_ESTADO_HISTORIAL (oeh) -- append-only

       Con cuatro estados el historial es corto, y por eso mismo es util:
       cada fila es una transicion que alguien decidio. Aqui esta la
       respuesta a "cuanto tiempo estuvo esperando cierre".

       oeh_orden_trabajo apunta a la OT; oeh_activo_... no: eso es
       Activo_Estado_Historial, que es otra cosa.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Estado_Historial]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo_Estado_Historial]
    (
        [oeh_id]                        INT             NOT NULL IDENTITY(1,1),
        [oeh_orden_trabajo]             INT             NOT NULL,
        [oeh_estado_anterior]           INT             NULL,
        [oeh_estado_nuevo]              INT             NOT NULL,
        [oeh_motivo]                    NVARCHAR(500)   NULL,
        [oeh_fecha_cambio_utc]          DATETIME        NOT NULL CONSTRAINT DF_OEH_FECHA_CAMBIO DEFAULT GETUTCDATE(),
        [oeh_usuario_creacion]          INT             NOT NULL,
        [oeh_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_OEH_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_ORDEN_TRABAJO_ESTADO_HISTORIAL PRIMARY KEY CLUSTERED ([oeh_id] ASC),
        CONSTRAINT FK_OEH_ORDEN_TRABAJO   FOREIGN KEY ([oeh_orden_trabajo])   REFERENCES [dbo].[Orden_Trabajo] ([otr_id]),
        CONSTRAINT FK_OEH_ESTADO_ANTERIOR FOREIGN KEY ([oeh_estado_anterior]) REFERENCES [dbo].[Orden_Trabajo_Estado] ([ote_id]),
        CONSTRAINT FK_OEH_ESTADO_NUEVO    FOREIGN KEY ([oeh_estado_nuevo])    REFERENCES [dbo].[Orden_Trabajo_Estado] ([ote_id]),
        CONSTRAINT FK_OEH_USUARIO         FOREIGN KEY ([oeh_usuario_creacion]) REFERENCES [dbo].[Usuario] ([usu_id])
    )
    CREATE NONCLUSTERED INDEX IX_OEH_ORDEN_TRABAJO ON [dbo].[Orden_Trabajo_Estado_Historial] ([oeh_orden_trabajo], [oeh_fecha_cambio_utc])
    PRINT 'Tabla Orden_Trabajo_Estado_Historial creada correctamente.'
END
ELSE PRINT 'Tabla Orden_Trabajo_Estado_Historial ya existe.'
GO


/* ========================================================================
   11. ORDEN_TRABAJO_VALIDACION (otv) -- las tres firmas del formato real

       ACEPTACION  el que recibe el trabajo
       EJECUCION   el que lo hizo
       VALIDACION  el que lo aprueba

       Es tabla y no tres pares de columnas porque puede faltar alguna,
       repetirse (rechazo y nueva validacion) o venir de distintas
       personas. Y porque la existencia de la fila es lo que hace
       innecesario el estado VALIDADA.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Validacion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo_Validacion]
    (
        [otv_id]                        INT             NOT NULL IDENTITY(1,1),
        [otv_orden_trabajo]             INT             NOT NULL,
        [otv_validacion_tipo]           INT             NOT NULL,   -- ACEPTACION / VALIDACION / EJECUCION
        [otv_usuario]                   INT             NOT NULL,
        [otv_resultado]                 NVARCHAR(20)    NOT NULL,   -- APROBADO / RECHAZADO
        [otv_fecha_utc]                 DATETIME        NOT NULL CONSTRAINT DF_OTV_FECHA DEFAULT GETUTCDATE(),
        [otv_observacion]               NVARCHAR(MAX)   NULL,
        [otv_archivo_firma]             INT             NULL,       -- FK diferida (bloque 22)
        [otv_usuario_creacion]          INT             NOT NULL,
        [otv_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_OTV_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_ORDEN_TRABAJO_VALIDACION PRIMARY KEY CLUSTERED ([otv_id] ASC),
        CONSTRAINT FK_OTV_ORDEN_TRABAJO FOREIGN KEY ([otv_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id]),
        CONSTRAINT FK_OTV_USUARIO       FOREIGN KEY ([otv_usuario])          REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_OTV_TIPO          FOREIGN KEY ([otv_validacion_tipo])  REFERENCES [dbo].[Validacion_Tipo] ([vat_id]),
        CONSTRAINT CK_OTV_RESULTADO CHECK ([otv_resultado] IN ('APROBADO', 'RECHAZADO'))
    )
    CREATE NONCLUSTERED INDEX IX_OTV_ORDEN_TRABAJO ON [dbo].[Orden_Trabajo_Validacion] ([otv_orden_trabajo], [otv_validacion_tipo])
    PRINT 'Tabla Orden_Trabajo_Validacion creada correctamente.'
END
ELSE PRINT 'Tabla Orden_Trabajo_Validacion ya existe.'
GO


/* ========================================================================
   12. ACTIVO_INDISPONIBILIDAD (ain)

       El tiempo en que la maquina NO estuvo disponible. Separado de la
       OT porque no toda parada tiene OT (corte de energia) y no toda OT
       para la maquina (lubricacion en marcha).

       ain_planificada es la columna que permite calcular disponibilidad
       de verdad: una parada programada de ocho horas no se castiga igual
       que una falla de ocho horas.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Indisponibilidad]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Indisponibilidad]
    (
        [ain_id]                        INT             NOT NULL IDENTITY(1,1),
        [ain_cliente]                   INT             NOT NULL,
        [ain_activo]                    INT             NOT NULL,
        [ain_orden_trabajo]             INT             NULL,
        [ain_falla]                     INT             NULL,
        [ain_fecha_inicio_utc]          DATETIME        NOT NULL,
        [ain_fecha_fin_utc]             DATETIME        NULL,
        [ain_minuto]                    INT             NULL,
        [ain_planificada]               BIT             NOT NULL CONSTRAINT DF_AIN_PLANIFICADA DEFAULT 0,
        [ain_detuvo_produccion]         BIT             NOT NULL CONSTRAINT DF_AIN_DETUVO DEFAULT 0,
        [ain_indisponibilidad_motivo]   INT             NULL,       -- MANTENIMIENTO PLANIFICADO / FALLA / ESPERA REPUESTO...
        [ain_motivo]                    NVARCHAR(500)   NULL,       -- el detalle en palabras, complementa al catalogo
        [ain_usuario_creacion]          INT             NOT NULL,
        [ain_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_AIN_FECHA_CREACION DEFAULT GETDATE(),
        [ain_usuario_actualizacion]     INT             NULL,
        [ain_fecha_actualizacion]       DATETIME        NULL,
        [ain_habilitado]                BIT             NOT NULL CONSTRAINT DF_AIN_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ACTIVO_INDISPONIBILIDAD PRIMARY KEY CLUSTERED ([ain_id] ASC),
        CONSTRAINT FK_AIN_CLIENTE       FOREIGN KEY ([ain_cliente])       REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_AIN_ACTIVO        FOREIGN KEY ([ain_activo])        REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_AIN_ORDEN_TRABAJO FOREIGN KEY ([ain_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id]),
        CONSTRAINT FK_AIN_FALLA         FOREIGN KEY ([ain_falla])         REFERENCES [dbo].[Falla] ([fal_id]),
        CONSTRAINT FK_AIN_MOTIVO        FOREIGN KEY ([ain_indisponibilidad_motivo]) REFERENCES [dbo].[Indisponibilidad_Motivo] ([inm_id]),
        CONSTRAINT CK_AIN_FECHAS CHECK ([ain_fecha_fin_utc] IS NULL OR [ain_fecha_fin_utc] >= [ain_fecha_inicio_utc]),
        CONSTRAINT CK_AIN_MINUTO CHECK ([ain_minuto] IS NULL OR [ain_minuto] >= 0)
    )
    CREATE NONCLUSTERED INDEX IX_AIN_ACTIVO_FECHA ON [dbo].[Activo_Indisponibilidad] ([ain_activo], [ain_fecha_inicio_utc])
    PRINT 'Tabla Activo_Indisponibilidad creada correctamente.'
END
ELSE PRINT 'Tabla Activo_Indisponibilidad ya existe.'
GO


/* ========================================================================
   13. FNC_ORDEN_TRABAJO_CORRELATIVO (fnc)

       El siguiente numero por cliente. No usa IDENTITY porque el
       correlativo es POR CLIENTE y IDENTITY es por tabla.

       El SP que lo consume debe llamarlo dentro de la transaccion y con
       el UNIQUE como ultima defensa: si dos usuarios crean una OT en el
       mismo milisegundo, el segundo choca contra
       UX_OTR_CLIENTE_CORRELATIVO y reintenta. Es preferible reintentar
       que entregar dos OT con el mismo numero.
   ======================================================================== */

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FNC_ORDEN_TRABAJO_CORRELATIVO]') AND type IN ('FN','IF','TF'))
    DROP FUNCTION [dbo].[FNC_ORDEN_TRABAJO_CORRELATIVO]
GO

CREATE FUNCTION [dbo].[FNC_ORDEN_TRABAJO_CORRELATIVO]
(
    @CLIENTE INT
)
RETURNS INT
AS
BEGIN
    DECLARE @SIGUIENTE INT

    SELECT @SIGUIENTE = ISNULL(MAX([otr_correlativo]), 0) + 1
      FROM [dbo].[Orden_Trabajo]
     WHERE [otr_cliente] = @CLIENTE

    RETURN @SIGUIENTE
END
GO


/* ========================================================================
   14. UPD_ORDEN_TRABAJO_TOMAR (upd)

       "Si la toma un tecnico el otro no puede tomarla."

       La carrera se decide en el WHERE, no en el codigo C#. Dos tecnicos
       que aprietan TOMAR en el mismo segundo: uno pasa la OT a EN
       EJECUCION, el otro recibe @@ROWCOUNT = 0 y un mensaje claro. Sin
       esto, ambos verian "listo" y llegarian los dos a la maquina.

       Estados: 2 = ABIERTA · 3 = EN EJECUCION
   ======================================================================== */

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UPD_ORDEN_TRABAJO_TOMAR]') AND type = 'P')
    DROP PROCEDURE [dbo].[UPD_ORDEN_TRABAJO_TOMAR]
GO

CREATE PROCEDURE [dbo].[UPD_ORDEN_TRABAJO_TOMAR]
    @OTR_ID     INT,
    @USUARIO    INT
AS
BEGIN
    SET NOCOUNT ON

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO_ANTERIOR INT

        SELECT @ESTADO_ANTERIOR = [otr_orden_trabajo_estado]
          FROM [dbo].[Orden_Trabajo]
         WHERE [otr_id] = @OTR_ID

        UPDATE [dbo].[Orden_Trabajo]
           SET [otr_orden_trabajo_estado]  = 3,                  -- EN EJECUCION
               [otr_usuario_responsable]   = @USUARIO,
               [otr_fecha_inicio_real_utc] = ISNULL([otr_fecha_inicio_real_utc], GETUTCDATE()),
               [otr_usuario_actualizacion] = @USUARIO,
               [otr_fecha_actualizacion]   = GETDATE()
         WHERE [otr_id]                    = @OTR_ID
           AND [otr_orden_trabajo_estado]  = 2                   -- <- la carrera se decide aqui

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden ya fue tomada por otro usuario o no esta abierta.', 16, 1)
            RETURN
        END

        -- El que la tomo queda como responsable. Puede sumar a otros despues.
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Asignacion]
                        WHERE [ota_orden_trabajo] = @OTR_ID AND [ota_es_responsable] = 1)
            INSERT INTO [dbo].[Orden_Trabajo_Asignacion]
                ([ota_orden_trabajo], [ota_usuario], [ota_es_responsable], [ota_rol_ejecucion],
                 [ota_fecha_aceptacion_utc], [ota_usuario_creacion])
            VALUES
                (@OTR_ID, @USUARIO, 1, N'EJECUTOR', GETUTCDATE(), @USUARIO)

        INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
            ([oeh_orden_trabajo], [oeh_estado_anterior], [oeh_estado_nuevo], [oeh_motivo], [oeh_usuario_creacion])
        VALUES
            (@OTR_ID, @ESTADO_ANTERIOR, 3, N'Tomada por el ejecutante', @USUARIO)

        COMMIT TRANSACTION
        SELECT @OTR_ID AS [otr_id]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH
END
GO


/* ========================================================================
   15. VW_ORDEN_TRABAJO_TABLERO

       Una fila por OT con lo que el planificador mira: quien la tiene,
       cuanto lleva, cuanto costo. Los estados derivados (ASIGNADA,
       VALIDADA) se calculan aqui, que es donde corresponde -- no como
       columnas que se desincronizan.
   ======================================================================== */

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VW_ORDEN_TRABAJO_TABLERO]') AND type = 'V')
    DROP VIEW [dbo].[VW_ORDEN_TRABAJO_TABLERO]
GO

CREATE VIEW [dbo].[VW_ORDEN_TRABAJO_TABLERO]
AS
SELECT
    OTR.[otr_id],
    OTR.[otr_cliente],
    OTR.[otr_cliente_instalacion],
    OTR.[otr_correlativo],
    OTR.[otr_titulo],
    OTR.[otr_orden_trabajo_estado],
    OTE.[ote_nombre]                    AS [estado_nombre],
    OTT.[ott_nombre]                    AS [tipo_nombre],
    OPR.[opr_nombre]                    AS [prioridad_nombre],
    OTO.[oto_nombre]                    AS [origen_nombre],
    OTR.[otr_activo],
    ACT.[act_codigo],
    ACT.[act_nombre],
    OTR.[otr_fecha_programada_utc],
    OTR.[otr_fecha_inicio_real_utc],
    OTR.[otr_fecha_fin_real_utc],
    -- Estados DERIVADOS: existen como consulta, no como columna.
    CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Asignacion] A
                       WHERE A.[ota_orden_trabajo] = OTR.[otr_id])
         THEN 1 ELSE 0 END              AS [esta_asignada],
    CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Validacion] V
                       WHERE V.[otv_orden_trabajo] = OTR.[otr_id]
                         AND V.[otv_validacion_tipo] = 2            -- VALIDACION
                         AND V.[otv_resultado]       = 'APROBADO')
         THEN 1 ELSE 0 END              AS [esta_validada],
    -- Horas reales: suma de la mano de obra, no un campo tipeado.
    ISNULL((SELECT SUM(M.[omo_minuto]) FROM [dbo].[Orden_Trabajo_Mano_Obra] M
             WHERE M.[omo_orden_trabajo] = OTR.[otr_id]), 0)      AS [minuto_mano_obra],
    -- Costo de terceros: suma de los servicios contratados.
    ISNULL((SELECT SUM(S.[ots_monto]) FROM [dbo].[Orden_Trabajo_Servicio] S
             WHERE S.[ots_orden_trabajo] = OTR.[otr_id]
               AND S.[ots_habilitado]    = 1), 0)                 AS [monto_servicio_externo],
    -- Cuantos dias lleva abierta. Estado 5 = CERRADA.
    CASE WHEN OTR.[otr_orden_trabajo_estado] = 5 THEN NULL
         ELSE DATEDIFF(DAY, OTR.[otr_fecha_creacion], GETDATE()) END AS [dia_abierta]
FROM [dbo].[Orden_Trabajo] OTR
    INNER JOIN [dbo].[Orden_Trabajo_Estado]    OTE ON OTE.[ote_id] = OTR.[otr_orden_trabajo_estado]
    INNER JOIN [dbo].[Orden_Trabajo_Tipo]      OTT ON OTT.[ott_id] = OTR.[otr_orden_trabajo_tipo]
    INNER JOIN [dbo].[Orden_Trabajo_Prioridad] OPR ON OPR.[opr_id] = OTR.[otr_orden_trabajo_prioridad]
    INNER JOIN [dbo].[Orden_Trabajo_Origen]    OTO ON OTO.[oto_id] = OTR.[otr_orden_trabajo_origen]
    LEFT  JOIN [dbo].[Activo]                  ACT ON ACT.[act_id] = OTR.[otr_activo]
WHERE OTR.[otr_habilitado] = 1
GO


PRINT 'Bloque 17 ORDEN DE TRABAJO: 17 tablas, 1 funcion, 1 SP y 1 vista procesados.'
GO
