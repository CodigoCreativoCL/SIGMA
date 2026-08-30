﻿﻿USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  20-08-2026
-- DESCRIPTION:     D13 -- PROVEEDORES, PROCEDIMIENTOS, PERMISOS Y ALERTAS.
-- =============================================
-- Ver SIGMA_MODELO_LOGICO_v2.md §8.13
-- ORDEN: despues de 13_PROGRAMACION.sql y ANTES de 14_PLANES.sql
--        (Plan_Mantenimiento_Actividad tiene FK a Procedimiento)
--
-- POR QUE PROVEEDOR ES UNA ENTIDAD Y NO UN TEXTO
--   El informe de Vixon que cobro 2,4 UF/hora por una emergencia de nueve
--   horas es exactamente lo que hay que poder sumar al final del año. Con
--   el proveedor como texto libre, "VIXON", "Vixon SPA" y "vixon" son tres
--   proveedores distintos y el total no cuadra nunca.
--
-- PROCEDIMIENTO ES REUTILIZABLE, LA ACTIVIDAD NO
--   "Cambio de aceite de blower" se escribe una vez y lo referencian
--   quince actividades de plan. Cuando el procedimiento mejora, mejora en
--   los quince lugares. La OT, en cambio, COPIA el texto al materializarse
--   (Orden_Trabajo_Paso.otp_descripcion): la orden ejecutada tiene que
--   conservar lo que el tecnico leyo ese dia.
--
-- EL PERMISO DE TRABAJO: SOLO EVIDENCIA
--   Se decidio en terreno que SIGMA no gestiona la firma del
--   prevencionista. El permiso lo emite el area de prevencion en su
--   propio proceso; SIGMA guarda el numero, el tipo, la vigencia y la
--   FOTO del documento firmado. Nada mas. Modelar un flujo de aprobacion
--   que la planta no va a usar seria construir una pantalla muerta.
--
-- LA ALERTA PROPONE, NO ORDENA
--   Igual que el hallazgo. ale_orden_trabajo se llena cuando una persona
--   decide. Una alerta que abre ordenes sola termina ignorada.
--
-- IDEMPOTENTE: se puede ejecutar las veces que sea.
-- =============================================


/* ========================================================================
   1. PROVEEDOR (prv)

      prv_es_contratista distingue al que ejecuta trabajo en planta (y por
      lo tanto puede aparecer en Orden_Trabajo_Asignacion) del que solo
      vende repuestos.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Proveedor]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Proveedor]
    (
        [prv_id]                        INT             NOT NULL IDENTITY(1,1),
        [prv_cliente]                   INT             NOT NULL,
        [prv_rut]                       NVARCHAR(20)    NOT NULL,
        [prv_razon_social]              NVARCHAR(200)   NOT NULL,
        [prv_nombre_fantasia]           NVARCHAR(200)   NULL,
        [prv_giro]                      NVARCHAR(200)   NULL,
        [prv_contacto]                  NVARCHAR(200)   NULL,
        [prv_email]                     NVARCHAR(200)   NULL,
        [prv_telefono]                  NVARCHAR(50)    NULL,
        [prv_direccion]                 NVARCHAR(300)   NULL,
        [prv_es_contratista]            BIT             NOT NULL CONSTRAINT DF_PRV_CONTRATISTA DEFAULT 0,
        [prv_es_proveedor_repuesto]     BIT             NOT NULL CONSTRAINT DF_PRV_REPUESTO DEFAULT 0,
        [prv_observacion]               NVARCHAR(500)   NULL,
        [prv_usuario_creacion]          INT             NOT NULL,
        [prv_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PRV_FECHA_CREACION DEFAULT GETDATE(),
        [prv_usuario_actualizacion]     INT             NULL,
        [prv_fecha_actualizacion]       DATETIME        NULL,
        [prv_habilitado]                BIT             NOT NULL CONSTRAINT DF_PRV_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PROVEEDOR PRIMARY KEY CLUSTERED ([prv_id] ASC),
        CONSTRAINT FK_PRV_CLIENTE FOREIGN KEY ([prv_cliente]) REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT UX_PRV_CLIENTE_RUT UNIQUE ([prv_cliente], [prv_rut])
    )
    PRINT 'Tabla Proveedor creada correctamente.'
END
ELSE PRINT 'Tabla Proveedor ya existe.'
GO


/* ========================================================================
   2. PROCEDIMIENTO (prc)

      prc_cliente NULL = procedimiento de la biblioteca de SIGMA,
      disponible para todos. Es parte del valor comercial del producto:
      una planta que arranca no parte de cero.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Procedimiento]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Procedimiento]
    (
        [prc_id]                        INT             NOT NULL IDENTITY(1,1),
        [prc_cliente]                   INT             NULL,       -- NULL = biblioteca global SIGMA
        [prc_codigo]                    NVARCHAR(50)    NOT NULL,
        [prc_nombre]                    NVARCHAR(200)   NOT NULL,
        [prc_version]                   INT             NOT NULL CONSTRAINT DF_PRC_VERSION DEFAULT 1,
        [prc_activo_tipo]               INT             NULL,
        [prc_descripcion]               NVARCHAR(MAX)   NULL,
        [prc_duracion_estimada_minuto]  INT             NULL,
        [prc_requiere_permiso]          BIT             NOT NULL CONSTRAINT DF_PRC_PERMISO DEFAULT 0,
        [prc_permiso_trabajo_tipo]      INT             NULL,
        [prc_usuario_creacion]          INT             NOT NULL,
        [prc_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PRC_FECHA_CREACION DEFAULT GETDATE(),
        [prc_usuario_actualizacion]     INT             NULL,
        [prc_fecha_actualizacion]       DATETIME        NULL,
        [prc_habilitado]                BIT             NOT NULL CONSTRAINT DF_PRC_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PROCEDIMIENTO PRIMARY KEY CLUSTERED ([prc_id] ASC),
        CONSTRAINT FK_PRC_CLIENTE      FOREIGN KEY ([prc_cliente])              REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_PRC_ACTIVO_TIPO  FOREIGN KEY ([prc_activo_tipo])          REFERENCES [dbo].[Activo_Tipo] ([ati_id]),
        CONSTRAINT FK_PRC_PERMISO_TIPO FOREIGN KEY ([prc_permiso_trabajo_tipo]) REFERENCES [dbo].[Permiso_Trabajo_Tipo] ([ptt_id]),
        CONSTRAINT CK_PRC_VERSION CHECK ([prc_version] >= 1)
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_PRC_CLIENTE_CODIGO
        ON [dbo].[Procedimiento] ([prc_cliente], [prc_codigo], [prc_version]) WHERE [prc_cliente] IS NOT NULL
    CREATE UNIQUE NONCLUSTERED INDEX UX_PRC_GLOBAL_CODIGO
        ON [dbo].[Procedimiento] ([prc_codigo], [prc_version]) WHERE [prc_cliente] IS NULL
    PRINT 'Tabla Procedimiento creada correctamente.'
END
ELSE PRINT 'Tabla Procedimiento ya existe.'
GO


/* ========================================================================
   3. PROCEDIMIENTO_PASO (ppa)

      ppa_requiere_medicion + ppa_variable_medicion son el mismo puente
      que cpi_genera_medicion en el checklist: un paso que dice "medir
      vibracion del descanso" deja una medicion en la serie del activo,
      no un texto en un campo libre.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Procedimiento_Paso]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Procedimiento_Paso]
    (
        [ppa_id]                        INT             NOT NULL IDENTITY(1,1),
        [ppa_procedimiento]             INT             NOT NULL,
        [ppa_orden]                     INT             NOT NULL CONSTRAINT DF_PPA_ORDEN DEFAULT 1,
        [ppa_nombre]                    NVARCHAR(200)   NOT NULL,
        [ppa_instruccion]               NVARCHAR(MAX)   NULL,
        [ppa_es_punto_control]          BIT             NOT NULL CONSTRAINT DF_PPA_PUNTO_CONTROL DEFAULT 0,
        [ppa_requiere_evidencia]        BIT             NOT NULL CONSTRAINT DF_PPA_EVIDENCIA DEFAULT 0,
        [ppa_requiere_medicion]         BIT             NOT NULL CONSTRAINT DF_PPA_MEDICION DEFAULT 0,
        [ppa_variable_medicion]         INT             NULL,
        [ppa_duracion_estimada_minuto]  INT             NULL,
        [ppa_usuario_creacion]          INT             NOT NULL,
        [ppa_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PPA_FECHA_CREACION DEFAULT GETDATE(),
        [ppa_usuario_actualizacion]     INT             NULL,
        [ppa_fecha_actualizacion]       DATETIME        NULL,
        [ppa_habilitado]                BIT             NOT NULL CONSTRAINT DF_PPA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PROCEDIMIENTO_PASO PRIMARY KEY CLUSTERED ([ppa_id] ASC),
        CONSTRAINT FK_PPA_PROCEDIMIENTO FOREIGN KEY ([ppa_procedimiento])     REFERENCES [dbo].[Procedimiento] ([prc_id]),
        CONSTRAINT FK_PPA_VARIABLE      FOREIGN KEY ([ppa_variable_medicion]) REFERENCES [dbo].[Variable_Medicion] ([vme_id]),
        CONSTRAINT UX_PPA_PROCEDIMIENTO_ORDEN UNIQUE ([ppa_procedimiento], [ppa_orden]),
        CONSTRAINT CK_PPA_ORDEN    CHECK ([ppa_orden] >= 1),
        CONSTRAINT CK_PPA_MEDICION CHECK ([ppa_requiere_medicion] = 0 OR [ppa_variable_medicion] IS NOT NULL)
    )
    PRINT 'Tabla Procedimiento_Paso creada correctamente.'
END
ELSE PRINT 'Tabla Procedimiento_Paso ya existe.'
GO


/* ========================================================================
   4. PERMISO_TRABAJO (ptr) -- solo el registro y la evidencia

      ptr_orden_trabajo es FK DIFERIDA (bloque 22): la OT se crea despues.
      ptr_archivo (la foto del permiso firmado) la agrega el bloque 10.

      No hay columnas de firma de prevencionista ni de jefatura: se
      decidio expresamente no modelar ese flujo. Lo unico que SIGMA
      necesita saber es que el permiso existe, cual es, hasta cuando vale
      y donde esta el papel.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Permiso_Trabajo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Permiso_Trabajo]
    (
        [ptr_id]                        INT             NOT NULL IDENTITY(1,1),
        [ptr_cliente]                   INT             NOT NULL,
        [ptr_orden_trabajo]             INT             NULL,       -- FK diferida (bloque 22)
        [ptr_permiso_trabajo_tipo]      INT             NOT NULL,
        [ptr_permiso_trabajo_estado]    INT             NOT NULL,
        [ptr_numero]                    NVARCHAR(50)    NULL,       -- el folio que emite prevencion
        [ptr_usuario_solicitante]       INT             NULL,
        [ptr_fecha_solicitud_utc]       DATETIME        NULL,
        [ptr_fecha_vigencia_inicio_utc] DATETIME        NULL,
        [ptr_fecha_vigencia_fin_utc]    DATETIME        NULL,
        [ptr_observacion]               NVARCHAR(500)   NULL,
        [ptr_usuario_creacion]          INT             NOT NULL,
        [ptr_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PTR_FECHA_CREACION DEFAULT GETDATE(),
        [ptr_usuario_actualizacion]     INT             NULL,
        [ptr_fecha_actualizacion]       DATETIME        NULL,
        [ptr_habilitado]                BIT             NOT NULL CONSTRAINT DF_PTR_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PERMISO_TRABAJO PRIMARY KEY CLUSTERED ([ptr_id] ASC),
        CONSTRAINT FK_PTR_CLIENTE     FOREIGN KEY ([ptr_cliente])                REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_PTR_TIPO        FOREIGN KEY ([ptr_permiso_trabajo_tipo])   REFERENCES [dbo].[Permiso_Trabajo_Tipo] ([ptt_id]),
        CONSTRAINT FK_PTR_ESTADO      FOREIGN KEY ([ptr_permiso_trabajo_estado]) REFERENCES [dbo].[Permiso_Trabajo_Estado] ([pte_id]),
        CONSTRAINT FK_PTR_SOLICITANTE FOREIGN KEY ([ptr_usuario_solicitante])    REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT CK_PTR_VIGENCIA CHECK
            ([ptr_fecha_vigencia_fin_utc] IS NULL OR [ptr_fecha_vigencia_inicio_utc] IS NULL
             OR [ptr_fecha_vigencia_fin_utc] >= [ptr_fecha_vigencia_inicio_utc])
    )
    CREATE NONCLUSTERED INDEX IX_PTR_CLIENTE_VIGENCIA ON [dbo].[Permiso_Trabajo] ([ptr_cliente], [ptr_fecha_vigencia_fin_utc])
    PRINT 'Tabla Permiso_Trabajo creada correctamente.'
END
ELSE PRINT 'Tabla Permiso_Trabajo ya existe.'
GO


/* ========================================================================
   5. ALERTA (ale) -- la bandeja de lo que el sistema noto

      Las FK nullable de origen son explicitas y no polimorficas. Se
      evaluo una tabla puente con tipo+id y se descarto por lo de siempre:
      pierde la integridad referencial justo donde mas hace falta.

      ale_orden_trabajo es FK diferida (bloque 22).

      Los tipos de alerta viven en Alerta_Tipo e incluyen los dos que
      pidio el jefe de mantenimiento: MEDIDOR PROXIMO MANTENIMIENTO
      ("avisame antes de las horas") y STOCK MAXIMO.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Alerta]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Alerta]
    (
        [ale_id]                            INT                 NOT NULL IDENTITY(1,1),
        [ale_uuid]                          UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_ALE_UUID DEFAULT NEWID(),
        [ale_cliente]                       INT                 NOT NULL,
        [ale_cliente_instalacion]           INT                 NULL,
        [ale_alerta_tipo]                   INT                 NOT NULL,
        [ale_alerta_estado]                 INT                 NOT NULL,
        [ale_severidad]                     INT                 NULL,
        [ale_titulo]                        NVARCHAR(200)       NOT NULL,
        [ale_descripcion]                   NVARCHAR(MAX)       NULL,
        [ale_fecha_deteccion_utc]           DATETIME            NOT NULL CONSTRAINT DF_ALE_FECHA_DETECCION DEFAULT GETUTCDATE(),
        -- Sobre que objeto se disparo
        [ale_activo]                        INT                 NULL,
        [ale_activo_componente]             INT                 NULL,
        [ale_activo_medidor]                INT                 NULL,
        [ale_repuesto]                      INT                 NULL,
        [ale_bodega]                        INT                 NULL,
        -- De donde salio
        [ale_checklist_ejecucion_respuesta] INT                 NULL,   -- FK diferida (bloque 22)
        [ale_plan_mantenimiento_ocurrencia] INT                 NULL,   -- FK diferida (bloque 22)
        [ale_prediccion]                    INT                 NULL,   -- FK diferida (bloque 22)
        [ale_orden_trabajo]                 INT                 NULL,   -- FK diferida (bloque 22): OT que la resolvio
        -- Valores que la justifican
        [ale_valor_observado]               DECIMAL(18,6)       NULL,
        [ale_valor_umbral]                  DECIMAL(18,6)       NULL,
        [ale_unidad_medida]                 INT                 NULL,
        -- Quien la atendio
        [ale_usuario_atencion]              INT                 NULL,
        [ale_fecha_atencion_utc]            DATETIME            NULL,
        [ale_motivo_descarte]               NVARCHAR(500)       NULL,
        [ale_usuario_creacion]              INT                 NOT NULL,
        [ale_fecha_creacion]                DATETIME            NOT NULL CONSTRAINT DF_ALE_FECHA_CREACION DEFAULT GETDATE(),
        [ale_usuario_actualizacion]         INT                 NULL,
        [ale_fecha_actualizacion]           DATETIME            NULL,
        [ale_habilitado]                    BIT                 NOT NULL CONSTRAINT DF_ALE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ALERTA PRIMARY KEY CLUSTERED ([ale_id] ASC),
        CONSTRAINT FK_ALE_CLIENTE     FOREIGN KEY ([ale_cliente])             REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_ALE_INSTALACION FOREIGN KEY ([ale_cliente_instalacion]) REFERENCES [dbo].[Cliente_Instalacion] ([cin_id]),
        CONSTRAINT FK_ALE_TIPO        FOREIGN KEY ([ale_alerta_tipo])         REFERENCES [dbo].[Alerta_Tipo] ([alt_id]),
        CONSTRAINT FK_ALE_ESTADO      FOREIGN KEY ([ale_alerta_estado])       REFERENCES [dbo].[Alerta_Estado] ([aet_id]),
        CONSTRAINT FK_ALE_SEVERIDAD   FOREIGN KEY ([ale_severidad])           REFERENCES [dbo].[Severidad] ([sev_id]),
        CONSTRAINT FK_ALE_ACTIVO      FOREIGN KEY ([ale_activo])              REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_ALE_COMPONENTE  FOREIGN KEY ([ale_activo_componente])   REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_ALE_MEDIDOR     FOREIGN KEY ([ale_activo_medidor])      REFERENCES [dbo].[Activo_Medidor] ([amd_id]),
        CONSTRAINT FK_ALE_REPUESTO    FOREIGN KEY ([ale_repuesto])            REFERENCES [dbo].[Repuesto] ([rep_id]),
        CONSTRAINT FK_ALE_BODEGA      FOREIGN KEY ([ale_bodega])              REFERENCES [dbo].[Bodega] ([bod_id]),
        CONSTRAINT FK_ALE_UNIDAD      FOREIGN KEY ([ale_unidad_medida])       REFERENCES [dbo].[Unidad_Medida] ([ume_id]),
        CONSTRAINT FK_ALE_ATENCION    FOREIGN KEY ([ale_usuario_atencion])    REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT UX_ALE_UUID UNIQUE ([ale_uuid]),
        -- Atender exige quien y cuando: "atendida" sin responsable no dice nada.
        CONSTRAINT CK_ALE_ATENCION CHECK
            ([ale_fecha_atencion_utc] IS NULL OR [ale_usuario_atencion] IS NOT NULL)
    )
    -- Indice filtrado: la bandeja del planificador solo mira lo abierto.
    -- Estado 1 = ABIERTA en Alerta_Estado.
    CREATE NONCLUSTERED INDEX IX_ALE_ABIERTA
        ON [dbo].[Alerta] ([ale_cliente], [ale_severidad], [ale_fecha_deteccion_utc])
        WHERE [ale_alerta_estado] = 1
    CREATE NONCLUSTERED INDEX IX_ALE_ACTIVO ON [dbo].[Alerta] ([ale_activo], [ale_fecha_deteccion_utc])
    PRINT 'Tabla Alerta creada correctamente.'
END
ELSE PRINT 'Tabla Alerta ya existe.'
GO


/* ========================================================================
   6. VW_ALERTA_ABIERTA -- lo que hay que mirar hoy

       Ordenada por severidad y antiguedad. El "dia_esperando" es el
       indicador real: una alerta critica de hace cinco dias no es una
       alerta, es un problema de gestion.
   ======================================================================== */

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VW_ALERTA_ABIERTA]') AND type = 'V')
    DROP VIEW [dbo].[VW_ALERTA_ABIERTA]
GO

CREATE VIEW [dbo].[VW_ALERTA_ABIERTA]
AS
SELECT
    ALE.[ale_id],
    ALE.[ale_cliente],
    ALE.[ale_cliente_instalacion],
    ALT.[alt_codigo]                    AS [tipo_codigo],
    ALT.[alt_nombre]                    AS [tipo_nombre],
    SEV.[sev_nombre]                    AS [severidad_nombre],
    ALE.[ale_severidad],
    ALE.[ale_titulo],
    ALE.[ale_descripcion],
    ALE.[ale_activo],
    ACT.[act_codigo],
    ACT.[act_nombre],
    ALE.[ale_valor_observado],
    ALE.[ale_valor_umbral],
    ALE.[ale_fecha_deteccion_utc],
    DATEDIFF(DAY, ALE.[ale_fecha_deteccion_utc], GETUTCDATE()) AS [dia_esperando],
    ALE.[ale_orden_trabajo]
FROM [dbo].[Alerta] ALE
    INNER JOIN [dbo].[Alerta_Tipo] ALT ON ALT.[alt_id] = ALE.[ale_alerta_tipo]
    LEFT  JOIN [dbo].[Severidad]   SEV ON SEV.[sev_id] = ALE.[ale_severidad]
    LEFT  JOIN [dbo].[Activo]      ACT ON ACT.[act_id] = ALE.[ale_activo]
WHERE ALE.[ale_alerta_estado] = 1
  AND ALE.[ale_habilitado]    = 1
GO


PRINT 'Bloque 19 TERCEROS Y ALERTAS: 5 tablas y 1 vista procesadas.'
GO
