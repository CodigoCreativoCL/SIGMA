﻿﻿﻿USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  20-08-2026
-- DESCRIPTION:     D6 -- PLANES DE MANTENIMIENTO, HITOS Y OCURRENCIAS.
-- =============================================
-- Ver SIGMA_MODELO_LOGICO_v2.md §5.1 y §8.6
-- ORDEN: despues de 13_PROGRAMACION.sql
--
-- EL HITO ES LA PIEZA QUE FALTABA (defecto E-01)
--   El plan real de los blowers Aerzen no dice "cambiar filtro cada 500
--   horas". Dice: "a las 500 HRS hacer estas cuatro cosas". El agrupador
--   es el HITO, y es el hito -- no la actividad -- lo que se programa.
--
--   Plan_Mantenimiento          "Plan preventivo Blower Aerzen GM10S"
--   └── Plan_Mantenimiento_Version   v1, PUBLICADO, inmutable
--       ├── Plan_Mantenimiento_Activo   CB01 CB02 CB03 CB04
--       ├── Plan_Mantenimiento_Hito  "500 HRS"  -> Programacion MEDIDOR 500
--       │     ├── Actividad  Cambio de filtro de aire
--       │     └── Actividad  Cambio de aceite
--       └── Plan_Mantenimiento_Hito  "15000 HRS -- Over Haul"
--
--   Sin el hito, al llegar a las 500 horas el generador crea DOS ordenes
--   sueltas -- una por actividad -- y el tecnico va dos veces a la misma
--   maquina. Con el hito crea UNA orden con dos pasos.
--
-- LA VERSION PUBLICADA ES INMUTABLE
--   Publicar congela. Corregir un plan publicado no se edita: se crea la
--   version siguiente. Asi una OT de hace ocho meses se puede reconstruir
--   con el texto que el tecnico realmente leyo ese dia.
--
-- LA OCURRENCIA ES DEL HITO, PARA UN ACTIVO, EN UNA FECHA
--   UX_PMO_HITO_ACTIVO_FECHA es la red de seguridad del generador: si el
--   job corre dos veces, la segunda choca contra el indice en vez de
--   duplicar el trabajo del tecnico.
--
-- LA REPROGRAMACION NO BORRA
--   Correr una mantencion de fecha deja rastro: la ocurrencia original
--   pasa a REPROGRAMADA y la nueva apunta a ella por pmo_ocurrencia_origen.
--   El cumplimiento se mide contra pmo_fecha_programada_original_utc, que
--   es la unica forma de que "cumplimos el 100%" signifique algo.
--
-- IDEMPOTENTE: se puede ejecutar las veces que sea.
-- =============================================


/* ========================================================================
   1. PLAN_MANTENIMIENTO (pma) -- la cabecera estable

      El plan como concepto no cambia nunca: "plan preventivo de los
      blowers". Lo que cambia es su contenido, y eso vive en la version.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Plan_Mantenimiento]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Plan_Mantenimiento]
    (
        [pma_id]                        INT             NOT NULL IDENTITY(1,1),
        [pma_cliente]                   INT             NOT NULL,
        [pma_cliente_instalacion]       INT             NULL,       -- NULL = aplica a todas las plantas del cliente
        [pma_codigo]                    NVARCHAR(50)    NOT NULL,
        [pma_nombre]                    NVARCHAR(200)   NOT NULL,
        [pma_descripcion]               NVARCHAR(MAX)   NULL,
        [pma_usuario_planificador]      INT             NULL,
        [pma_activo_tipo]               INT             NULL,       -- para que familia de maquina se penso
        [pma_activo_modelo]             INT             NULL,
        [pma_usuario_creacion]          INT             NOT NULL,
        [pma_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PMA_FECHA_CREACION DEFAULT GETDATE(),
        [pma_usuario_actualizacion]     INT             NULL,
        [pma_fecha_actualizacion]       DATETIME        NULL,
        [pma_habilitado]                BIT             NOT NULL CONSTRAINT DF_PMA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PLAN_MANTENIMIENTO PRIMARY KEY CLUSTERED ([pma_id] ASC),
        CONSTRAINT FK_PMA_CLIENTE       FOREIGN KEY ([pma_cliente])              REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_PMA_INSTALACION   FOREIGN KEY ([pma_cliente_instalacion])  REFERENCES [dbo].[Cliente_Instalacion] ([cin_id]),
        CONSTRAINT FK_PMA_PLANIFICADOR  FOREIGN KEY ([pma_usuario_planificador]) REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_PMA_ACTIVO_TIPO   FOREIGN KEY ([pma_activo_tipo])          REFERENCES [dbo].[Activo_Tipo] ([ati_id]),
        CONSTRAINT FK_PMA_ACTIVO_MODELO FOREIGN KEY ([pma_activo_modelo])        REFERENCES [dbo].[Activo_Modelo] ([amo_id]),
        CONSTRAINT UX_PMA_CLIENTE_CODIGO UNIQUE ([pma_cliente], [pma_codigo])
    )
    PRINT 'Tabla Plan_Mantenimiento creada correctamente.'
END
ELSE PRINT 'Tabla Plan_Mantenimiento ya existe.'
GO


/* ========================================================================
   2. PLAN_MANTENIMIENTO_VERSION (pmv)

      pmv_numero es correlativo por plan, no global. UX_PMV_PLAN_NUMERO
      impide que existan dos "v2" del mismo plan.

      Publicar es una transicion de estado con fecha y responsable, no un
      BIT: cuando alguien pregunte "quien autorizo este plan y cuando",
      la respuesta esta en la fila.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Plan_Mantenimiento_Version]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Plan_Mantenimiento_Version]
    (
        [pmv_id]                        INT             NOT NULL IDENTITY(1,1),
        [pmv_plan_mantenimiento]        INT             NOT NULL,
        [pmv_numero]                    INT             NOT NULL,
        [pmv_plan_version_estado]       INT             NOT NULL,
        [pmv_fecha_publicacion]         DATETIME        NULL,
        [pmv_usuario_publicacion]       INT             NULL,
        [pmv_fecha_retiro]              DATETIME        NULL,
        [pmv_observacion]               NVARCHAR(MAX)   NULL,
        [pmv_usuario_creacion]          INT             NOT NULL,
        [pmv_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PMV_FECHA_CREACION DEFAULT GETDATE(),
        [pmv_usuario_actualizacion]     INT             NULL,
        [pmv_fecha_actualizacion]       DATETIME        NULL,
        [pmv_habilitado]                BIT             NOT NULL CONSTRAINT DF_PMV_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PLAN_MANTENIMIENTO_VERSION PRIMARY KEY CLUSTERED ([pmv_id] ASC),
        CONSTRAINT FK_PMV_PLAN        FOREIGN KEY ([pmv_plan_mantenimiento])  REFERENCES [dbo].[Plan_Mantenimiento] ([pma_id]),
        CONSTRAINT FK_PMV_ESTADO      FOREIGN KEY ([pmv_plan_version_estado]) REFERENCES [dbo].[Plan_Version_Estado] ([pve_id]),
        CONSTRAINT FK_PMV_PUBLICADOR  FOREIGN KEY ([pmv_usuario_publicacion]) REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT UX_PMV_PLAN_NUMERO UNIQUE ([pmv_plan_mantenimiento], [pmv_numero]),
        CONSTRAINT CK_PMV_NUMERO      CHECK ([pmv_numero] >= 1),
        -- Publicada exige fecha y responsable. Estado 1 = BORRADOR.
        CONSTRAINT CK_PMV_PUBLICACION CHECK
            ([pmv_plan_version_estado] = 1
             OR ([pmv_fecha_publicacion] IS NOT NULL AND [pmv_usuario_publicacion] IS NOT NULL))
    )
    CREATE NONCLUSTERED INDEX IX_PMV_PLAN_ESTADO ON [dbo].[Plan_Mantenimiento_Version] ([pmv_plan_mantenimiento], [pmv_plan_version_estado])
    PRINT 'Tabla Plan_Mantenimiento_Version creada correctamente.'
END
ELSE PRINT 'Tabla Plan_Mantenimiento_Version ya existe.'
GO


/* ========================================================================
   3. PLAN_MANTENIMIENTO_ACTIVO (pac) -- a que maquinas aplica

      pac_activo_medidor es la columna que hace posible el plan por horas
      en cuatro maquinas iguales: cada blower lleva su propio horometro,
      y las 500 HRS de CB01 no son las de CB02. Sin esta columna habria
      que crear cuatro planes identicos.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Plan_Mantenimiento_Activo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Plan_Mantenimiento_Activo]
    (
        [pac_id]                          INT           NOT NULL IDENTITY(1,1),
        [pac_plan_mantenimiento_version]  INT           NOT NULL,
        [pac_activo]                      INT           NOT NULL,
        [pac_activo_componente]           INT           NULL,
        [pac_activo_medidor]              INT           NULL,
        [pac_usuario_creacion]            INT           NOT NULL,
        [pac_fecha_creacion]              DATETIME      NOT NULL CONSTRAINT DF_PAC_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_PLAN_MANTENIMIENTO_ACTIVO PRIMARY KEY CLUSTERED ([pac_id] ASC),
        CONSTRAINT FK_PAC_VERSION    FOREIGN KEY ([pac_plan_mantenimiento_version]) REFERENCES [dbo].[Plan_Mantenimiento_Version] ([pmv_id]),
        CONSTRAINT FK_PAC_ACTIVO     FOREIGN KEY ([pac_activo])                     REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_PAC_COMPONENTE FOREIGN KEY ([pac_activo_componente])          REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_PAC_MEDIDOR    FOREIGN KEY ([pac_activo_medidor])             REFERENCES [dbo].[Activo_Medidor] ([amd_id])
    )
    -- UNIQUE filtrado: el componente NULL no colisiona consigo mismo en un UNIQUE normal.
    CREATE UNIQUE NONCLUSTERED INDEX UX_PAC_VERSION_ACTIVO
        ON [dbo].[Plan_Mantenimiento_Activo] ([pac_plan_mantenimiento_version], [pac_activo])
        WHERE [pac_activo_componente] IS NULL
    CREATE UNIQUE NONCLUSTERED INDEX UX_PAC_VERSION_ACTIVO_COMPONENTE
        ON [dbo].[Plan_Mantenimiento_Activo] ([pac_plan_mantenimiento_version], [pac_activo], [pac_activo_componente])
        WHERE [pac_activo_componente] IS NOT NULL
    PRINT 'Tabla Plan_Mantenimiento_Activo creada correctamente.'
END
ELSE PRINT 'Tabla Plan_Mantenimiento_Activo ya existe.'
GO


/* ========================================================================
   4. PLAN_MANTENIMIENTO_HITO (pmh) -- LA CORRECCION DE E-01

      pmh_programacion NOT NULL: un hito sin programacion no se dispara
      nunca, y un plan con hitos que no se disparan es un documento, no
      un sistema.

      pmh_valor_medidor duplica informacion que ya esta en
      Programacion_Medidor. Es deliberado: el planificador quiere ver
      "500 / 3000 / 9000 / 15000" en una lista sin que la consulta tenga
      que bajar a la tabla de programacion por cada fila.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Plan_Mantenimiento_Hito]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Plan_Mantenimiento_Hito]
    (
        [pmh_id]                          INT             NOT NULL IDENTITY(1,1),
        [pmh_plan_mantenimiento_version]  INT             NOT NULL,
        [pmh_programacion]                INT             NOT NULL,
        [pmh_codigo]                      NVARCHAR(50)    NOT NULL,
        [pmh_nombre]                      NVARCHAR(200)   NOT NULL,
        [pmh_orden]                       INT             NOT NULL CONSTRAINT DF_PMH_ORDEN DEFAULT 1,
        [pmh_valor_medidor]               DECIMAL(18,2)   NULL,
        [pmh_unidad_medida]               INT             NULL,
        [pmh_es_overhaul]                 BIT             NOT NULL CONSTRAINT DF_PMH_OVERHAUL DEFAULT 0,
        [pmh_requiere_parada]             BIT             NOT NULL CONSTRAINT DF_PMH_PARADA DEFAULT 0,
        [pmh_duracion_estimada_minuto]    INT             NULL,
        [pmh_orden_trabajo_tipo]          INT             NULL,
        [pmh_orden_trabajo_prioridad]     INT             NULL,
        [pmh_descripcion]                 NVARCHAR(500)   NULL,
        [pmh_usuario_creacion]            INT             NOT NULL,
        [pmh_fecha_creacion]              DATETIME        NOT NULL CONSTRAINT DF_PMH_FECHA_CREACION DEFAULT GETDATE(),
        [pmh_usuario_actualizacion]       INT             NULL,
        [pmh_fecha_actualizacion]         DATETIME        NULL,
        [pmh_habilitado]                  BIT             NOT NULL CONSTRAINT DF_PMH_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PLAN_MANTENIMIENTO_HITO PRIMARY KEY CLUSTERED ([pmh_id] ASC),
        CONSTRAINT FK_PMH_VERSION      FOREIGN KEY ([pmh_plan_mantenimiento_version]) REFERENCES [dbo].[Plan_Mantenimiento_Version] ([pmv_id]),
        CONSTRAINT FK_PMH_PROGRAMACION FOREIGN KEY ([pmh_programacion])                REFERENCES [dbo].[Programacion] ([pro_id]),
        CONSTRAINT FK_PMH_UNIDAD       FOREIGN KEY ([pmh_unidad_medida])               REFERENCES [dbo].[Unidad_Medida] ([ume_id]),
        CONSTRAINT FK_PMH_OT_TIPO      FOREIGN KEY ([pmh_orden_trabajo_tipo])          REFERENCES [dbo].[Orden_Trabajo_Tipo] ([ott_id]),
        CONSTRAINT FK_PMH_OT_PRIORIDAD FOREIGN KEY ([pmh_orden_trabajo_prioridad])     REFERENCES [dbo].[Orden_Trabajo_Prioridad] ([opr_id]),
        CONSTRAINT UX_PMH_VERSION_CODIGO UNIQUE ([pmh_plan_mantenimiento_version], [pmh_codigo]),
        CONSTRAINT CK_PMH_ORDEN    CHECK ([pmh_orden] >= 1),
        CONSTRAINT CK_PMH_DURACION CHECK ([pmh_duracion_estimada_minuto] IS NULL OR [pmh_duracion_estimada_minuto] > 0)
    )
    CREATE NONCLUSTERED INDEX IX_PMH_PROGRAMACION ON [dbo].[Plan_Mantenimiento_Hito] ([pmh_programacion])
    PRINT 'Tabla Plan_Mantenimiento_Hito creada correctamente.'
END
ELSE PRINT 'Tabla Plan_Mantenimiento_Hito ya existe.'
GO


/* ========================================================================
   5. PLAN_MANTENIMIENTO_ACTIVIDAD (paa) -- cuelga del HITO

      paa_obligatoria = 0 modela literalmente la columna "a evaluar" del
      plan anual real: la actividad esta escrita, pero el tecnico decide
      en terreno si corresponde. Sin este BIT habria que sacarla del plan
      y perder que estaba prevista.

      paa_procedimiento apunta al procedimiento reutilizable; la
      descripcion propia sigue existiendo para el caso en que no haya uno.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Plan_Mantenimiento_Actividad]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Plan_Mantenimiento_Actividad]
    (
        [paa_id]                        INT             NOT NULL IDENTITY(1,1),
        [paa_plan_mantenimiento_hito]   INT             NOT NULL,
        [paa_procedimiento]             INT             NULL,
        [paa_codigo]                    NVARCHAR(50)    NOT NULL,
        [paa_nombre]                    NVARCHAR(200)   NOT NULL,
        [paa_descripcion]               NVARCHAR(MAX)   NULL,
        [paa_orden]                     INT             NOT NULL CONSTRAINT DF_PAA_ORDEN DEFAULT 1,
        [paa_duracion_estimada_minuto]  INT             NULL,
        [paa_obligatoria]               BIT             NOT NULL CONSTRAINT DF_PAA_OBLIGATORIA DEFAULT 1,
        [paa_requiere_parada]           BIT             NOT NULL CONSTRAINT DF_PAA_PARADA DEFAULT 0,
        [paa_requiere_permiso]          BIT             NOT NULL CONSTRAINT DF_PAA_PERMISO DEFAULT 0,
        [paa_permiso_trabajo_tipo]      INT             NULL,
        [paa_usuario_creacion]          INT             NOT NULL,
        [paa_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PAA_FECHA_CREACION DEFAULT GETDATE(),
        [paa_usuario_actualizacion]     INT             NULL,
        [paa_fecha_actualizacion]       DATETIME        NULL,
        [paa_habilitado]                BIT             NOT NULL CONSTRAINT DF_PAA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PLAN_MANTENIMIENTO_ACTIVIDAD PRIMARY KEY CLUSTERED ([paa_id] ASC),
        CONSTRAINT FK_PAA_HITO          FOREIGN KEY ([paa_plan_mantenimiento_hito]) REFERENCES [dbo].[Plan_Mantenimiento_Hito] ([pmh_id]),
        CONSTRAINT FK_PAA_PROCEDIMIENTO FOREIGN KEY ([paa_procedimiento])           REFERENCES [dbo].[Procedimiento] ([prc_id]),
        CONSTRAINT FK_PAA_PERMISO_TIPO  FOREIGN KEY ([paa_permiso_trabajo_tipo])    REFERENCES [dbo].[Permiso_Trabajo_Tipo] ([ptt_id]),
        CONSTRAINT UX_PAA_HITO_CODIGO UNIQUE ([paa_plan_mantenimiento_hito], [paa_codigo]),
        CONSTRAINT CK_PAA_ORDEN   CHECK ([paa_orden] >= 1),
        -- Si exige permiso, hay que decir de que tipo. "Requiere permiso, no se cual" no sirve en terreno.
        CONSTRAINT CK_PAA_PERMISO CHECK ([paa_requiere_permiso] = 0 OR [paa_permiso_trabajo_tipo] IS NOT NULL)
    )
    PRINT 'Tabla Plan_Mantenimiento_Actividad creada correctamente.'
END
ELSE PRINT 'Tabla Plan_Mantenimiento_Actividad ya existe.'
GO


/* ========================================================================
   6. HIJAS DE ACTIVIDAD -- pck, pra, pae

      Tres relaciones puras (AUD-R): el checklist que hay que llenar, los
      repuestos que se van a consumir, y las especialidades que se
      necesitan. Todas con UNIQUE sobre el par, porque repetir la misma
      fila dos veces no significa nada.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Plan_Actividad_Checklist]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Plan_Actividad_Checklist]
    (
        [pck_id]                          INT       NOT NULL IDENTITY(1,1),
        [pck_plan_mantenimiento_actividad] INT      NOT NULL,
        [pck_checklist_plantilla_version] INT       NOT NULL,
        [pck_momento_ejecucion]           INT       NOT NULL,   -- ANTES / DURANTE / DESPUES
        [pck_obligatorio]                 BIT       NOT NULL CONSTRAINT DF_PCK_OBLIGATORIO DEFAULT 1,
        [pck_usuario_creacion]            INT       NOT NULL,
        [pck_fecha_creacion]              DATETIME  NOT NULL CONSTRAINT DF_PCK_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_PLAN_ACTIVIDAD_CHECKLIST PRIMARY KEY CLUSTERED ([pck_id] ASC),
        CONSTRAINT FK_PCK_ACTIVIDAD FOREIGN KEY ([pck_plan_mantenimiento_actividad]) REFERENCES [dbo].[Plan_Mantenimiento_Actividad] ([paa_id]),
        CONSTRAINT FK_PCK_VERSION   FOREIGN KEY ([pck_checklist_plantilla_version])  REFERENCES [dbo].[Checklist_Plantilla_Version] ([cpv_id]),
        CONSTRAINT FK_PCK_MOMENTO   FOREIGN KEY ([pck_momento_ejecucion])            REFERENCES [dbo].[Momento_Ejecucion] ([moe_id]),
        CONSTRAINT UX_PCK_ACTIVIDAD_VERSION_MOMENTO UNIQUE ([pck_plan_mantenimiento_actividad], [pck_checklist_plantilla_version], [pck_momento_ejecucion])
    )
    PRINT 'Tabla Plan_Actividad_Checklist creada correctamente.'
END
ELSE PRINT 'Tabla Plan_Actividad_Checklist ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Plan_Actividad_Repuesto]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Plan_Actividad_Repuesto]
    (
        [pra_id]                           INT             NOT NULL IDENTITY(1,1),
        [pra_plan_mantenimiento_actividad] INT             NOT NULL,
        [pra_repuesto]                     INT             NOT NULL,
        [pra_cantidad]                     DECIMAL(18,4)   NOT NULL,
        [pra_unidad_medida]                INT             NULL,
        [pra_obligatorio]                  BIT             NOT NULL CONSTRAINT DF_PRA_OBLIGATORIO DEFAULT 1,
        [pra_observacion]                  NVARCHAR(500)   NULL,
        [pra_usuario_creacion]             INT             NOT NULL,
        [pra_fecha_creacion]               DATETIME        NOT NULL CONSTRAINT DF_PRA_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_PLAN_ACTIVIDAD_REPUESTO PRIMARY KEY CLUSTERED ([pra_id] ASC),
        CONSTRAINT FK_PRA_ACTIVIDAD FOREIGN KEY ([pra_plan_mantenimiento_actividad]) REFERENCES [dbo].[Plan_Mantenimiento_Actividad] ([paa_id]),
        CONSTRAINT FK_PRA_REPUESTO  FOREIGN KEY ([pra_repuesto])                     REFERENCES [dbo].[Repuesto] ([rep_id]),
        CONSTRAINT FK_PRA_UNIDAD    FOREIGN KEY ([pra_unidad_medida])                REFERENCES [dbo].[Unidad_Medida] ([ume_id]),
        CONSTRAINT UX_PRA_ACTIVIDAD_REPUESTO UNIQUE ([pra_plan_mantenimiento_actividad], [pra_repuesto]),
        CONSTRAINT CK_PRA_CANTIDAD CHECK ([pra_cantidad] > 0)
    )
    PRINT 'Tabla Plan_Actividad_Repuesto creada correctamente.'
END
ELSE PRINT 'Tabla Plan_Actividad_Repuesto ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Plan_Actividad_Especialidad]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Plan_Actividad_Especialidad]
    (
        [pae_id]                           INT       NOT NULL IDENTITY(1,1),
        [pae_plan_mantenimiento_actividad] INT       NOT NULL,
        [pae_especialidad]                 INT       NOT NULL,
        [pae_cantidad_persona]             INT       NOT NULL CONSTRAINT DF_PAE_CANTIDAD DEFAULT 1,
        [pae_especialidad_nivel]           INT       NULL,
        [pae_usuario_creacion]             INT       NOT NULL,
        [pae_fecha_creacion]               DATETIME  NOT NULL CONSTRAINT DF_PAE_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_PLAN_ACTIVIDAD_ESPECIALIDAD PRIMARY KEY CLUSTERED ([pae_id] ASC),
        CONSTRAINT FK_PAE_ACTIVIDAD    FOREIGN KEY ([pae_plan_mantenimiento_actividad]) REFERENCES [dbo].[Plan_Mantenimiento_Actividad] ([paa_id]),
        CONSTRAINT FK_PAE_ESPECIALIDAD FOREIGN KEY ([pae_especialidad])                 REFERENCES [dbo].[Especialidad] ([esp_id]),
        CONSTRAINT FK_PAE_NIVEL        FOREIGN KEY ([pae_especialidad_nivel])           REFERENCES [dbo].[Especialidad_Nivel] ([enl_id]),
        CONSTRAINT UX_PAE_ACTIVIDAD_ESPECIALIDAD UNIQUE ([pae_plan_mantenimiento_actividad], [pae_especialidad]),
        CONSTRAINT CK_PAE_CANTIDAD CHECK ([pae_cantidad_persona] >= 1)
    )
    PRINT 'Tabla Plan_Actividad_Especialidad creada correctamente.'
END
ELSE PRINT 'Tabla Plan_Actividad_Especialidad ya existe.'
GO


/* ========================================================================
   7. PLAN_MANTENIMIENTO_OCURRENCIA (pmo) -- lo que el generador crea

      Es la instancia concreta: hito H9000, activo CB01, fecha 12 de
      marzo. La OT nace de aqui, y pmo_orden_trabajo cierra el circulo.

      pmo_orden_trabajo se agrega como FK DIFERIDA en el bloque 22:
      Orden_Trabajo se crea despues.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Plan_Mantenimiento_Ocurrencia]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Plan_Mantenimiento_Ocurrencia]
    (
        [pmo_id]                            INT                 NOT NULL IDENTITY(1,1),
        [pmo_uuid]                          UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_PMO_UUID DEFAULT NEWID(),
        [pmo_cliente]                       INT                 NOT NULL,
        [pmo_plan_mantenimiento_hito]       INT                 NOT NULL,
        [pmo_programacion]                  INT                 NOT NULL,
        [pmo_activo]                        INT                 NOT NULL,
        [pmo_activo_componente]             INT                 NULL,
        [pmo_fecha_programada_utc]          DATETIME            NOT NULL,
        [pmo_fecha_limite_utc]              DATETIME            NULL,
        [pmo_fecha_disponible_utc]          DATETIME            NULL,
        [pmo_fecha_programada_original_utc] DATETIME            NULL,
        [pmo_ocurrencia_origen]             INT                 NULL,   -- de que ocurrencia se reprogramo
        [pmo_valor_medidor_objetivo]        DECIMAL(18,2)       NULL,
        [pmo_plan_ocurrencia_estado]        INT                 NOT NULL,
        [pmo_orden_trabajo]                 INT                 NULL,   -- FK diferida (bloque 22)
        [pmo_observacion]                   NVARCHAR(500)       NULL,
        [pmo_usuario_creacion]              INT                 NOT NULL,
        [pmo_fecha_creacion]                DATETIME            NOT NULL CONSTRAINT DF_PMO_FECHA_CREACION DEFAULT GETDATE(),
        [pmo_usuario_actualizacion]         INT                 NULL,
        [pmo_fecha_actualizacion]           DATETIME            NULL,
        [pmo_habilitado]                    BIT                 NOT NULL CONSTRAINT DF_PMO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PLAN_MANTENIMIENTO_OCURRENCIA PRIMARY KEY CLUSTERED ([pmo_id] ASC),
        CONSTRAINT FK_PMO_CLIENTE      FOREIGN KEY ([pmo_cliente])                  REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_PMO_HITO         FOREIGN KEY ([pmo_plan_mantenimiento_hito])  REFERENCES [dbo].[Plan_Mantenimiento_Hito] ([pmh_id]),
        CONSTRAINT FK_PMO_PROGRAMACION FOREIGN KEY ([pmo_programacion])             REFERENCES [dbo].[Programacion] ([pro_id]),
        CONSTRAINT FK_PMO_ACTIVO       FOREIGN KEY ([pmo_activo])                   REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_PMO_COMPONENTE   FOREIGN KEY ([pmo_activo_componente])        REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_PMO_ORIGEN       FOREIGN KEY ([pmo_ocurrencia_origen])        REFERENCES [dbo].[Plan_Mantenimiento_Ocurrencia] ([pmo_id]),
        CONSTRAINT FK_PMO_ESTADO       FOREIGN KEY ([pmo_plan_ocurrencia_estado])   REFERENCES [dbo].[Plan_Ocurrencia_Estado] ([poe_id]),
        CONSTRAINT UX_PMO_UUID UNIQUE ([pmo_uuid]),
        -- La red del generador: correr el job dos veces no duplica trabajo.
        CONSTRAINT UX_PMO_HITO_ACTIVO_FECHA UNIQUE ([pmo_plan_mantenimiento_hito], [pmo_activo], [pmo_fecha_programada_utc]),
        CONSTRAINT CK_PMO_LIMITE CHECK ([pmo_fecha_limite_utc] IS NULL OR [pmo_fecha_limite_utc] >= [pmo_fecha_programada_utc])
    )
    -- Cinturon y tirantes: tambien por programacion, segun §5.7 del modelo logico.
    CREATE UNIQUE NONCLUSTERED INDEX UX_PMO_PROGRAMACION_ACTIVO_FECHA
        ON [dbo].[Plan_Mantenimiento_Ocurrencia] ([pmo_programacion], [pmo_activo], [pmo_fecha_programada_utc])
    CREATE NONCLUSTERED INDEX IX_PMO_CLIENTE_ESTADO_FECHA
        ON [dbo].[Plan_Mantenimiento_Ocurrencia] ([pmo_cliente], [pmo_plan_ocurrencia_estado], [pmo_fecha_programada_utc])
    PRINT 'Tabla Plan_Mantenimiento_Ocurrencia creada correctamente.'
END
ELSE PRINT 'Tabla Plan_Mantenimiento_Ocurrencia ya existe.'
GO


/* ========================================================================
   8. PLAN_OCURRENCIA_HISTORIAL (poh) -- append-only

      Quien reprogramo, cuando y por que. Es la tabla que contesta la
      pregunta incomoda de la auditoria: "esta mantencion figura cumplida,
      pero se movio tres veces -- quien la movio".
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Plan_Ocurrencia_Historial]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Plan_Ocurrencia_Historial]
    (
        [poh_id]                            INT             NOT NULL IDENTITY(1,1),
        [poh_plan_mantenimiento_ocurrencia] INT             NOT NULL,
        [poh_estado_anterior]               INT             NULL,
        [poh_estado_nuevo]                  INT             NOT NULL,
        [poh_fecha_anterior_utc]            DATETIME        NULL,
        [poh_fecha_nueva_utc]               DATETIME        NULL,
        [poh_motivo]                        NVARCHAR(500)   NULL,
        [poh_usuario_creacion]              INT             NOT NULL,
        [poh_fecha_creacion]                DATETIME        NOT NULL CONSTRAINT DF_POH_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_PLAN_OCURRENCIA_HISTORIAL PRIMARY KEY CLUSTERED ([poh_id] ASC),
        CONSTRAINT FK_POH_OCURRENCIA      FOREIGN KEY ([poh_plan_mantenimiento_ocurrencia]) REFERENCES [dbo].[Plan_Mantenimiento_Ocurrencia] ([pmo_id]),
        CONSTRAINT FK_POH_ESTADO_ANTERIOR FOREIGN KEY ([poh_estado_anterior])               REFERENCES [dbo].[Plan_Ocurrencia_Estado] ([poe_id]),
        CONSTRAINT FK_POH_ESTADO_NUEVO    FOREIGN KEY ([poh_estado_nuevo])                  REFERENCES [dbo].[Plan_Ocurrencia_Estado] ([poe_id]),
        CONSTRAINT FK_POH_USUARIO         FOREIGN KEY ([poh_usuario_creacion])              REFERENCES [dbo].[Usuario] ([usu_id])
    )
    CREATE NONCLUSTERED INDEX IX_POH_OCURRENCIA ON [dbo].[Plan_Ocurrencia_Historial] ([poh_plan_mantenimiento_ocurrencia], [poh_fecha_creacion])
    PRINT 'Tabla Plan_Ocurrencia_Historial creada correctamente.'
END
ELSE PRINT 'Tabla Plan_Ocurrencia_Historial ya existe.'
GO


/* ========================================================================
   9. FNC_PLAN_VERSION_VIGENTE (fnc)

      Devuelve la version PUBLICADA de un plan. Una sola definicion de
      "vigente" para toda la aplicacion: si maniana se agrega el concepto
      de vigencia por fecha, se cambia aqui y no en veinte consultas.
   ======================================================================== */

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FNC_PLAN_VERSION_VIGENTE]') AND type IN ('FN','IF','TF'))
    DROP FUNCTION [dbo].[FNC_PLAN_VERSION_VIGENTE]
GO

CREATE FUNCTION [dbo].[FNC_PLAN_VERSION_VIGENTE]
(
    @PLAN_MANTENIMIENTO INT
)
RETURNS INT
AS
BEGIN
    DECLARE @VERSION INT

    SELECT TOP 1 @VERSION = [pmv_id]
      FROM [dbo].[Plan_Mantenimiento_Version]
     WHERE [pmv_plan_mantenimiento]  = @PLAN_MANTENIMIENTO
       AND [pmv_plan_version_estado] = 2          -- PUBLICADO
       AND [pmv_habilitado]          = 1
     ORDER BY [pmv_numero] DESC

    RETURN @VERSION
END
GO


/* ========================================================================
   10. UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR (upd)

       Publicar retira la version anterior en la misma transaccion. Si no
       lo hiciera, quedarian dos versiones publicadas del mismo plan y
       FNC_PLAN_VERSION_VIGENTE tendria que adivinar cual.

       La carrera se decide en el WHERE: solo se publica lo que TODAVIA
       esta en BORRADOR. Dos usuarios que publiquen a la vez -> uno gana,
       el otro recibe un error explicito en vez de un resultado silencioso.
   ======================================================================== */

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR]') AND type = 'P')
    DROP PROCEDURE [dbo].[UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR]
GO

CREATE PROCEDURE [dbo].[UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR]
    @PMV_ID     INT,
    @USUARIO    INT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @PLAN INT

    SELECT @PLAN = [pmv_plan_mantenimiento]
      FROM [dbo].[Plan_Mantenimiento_Version]
     WHERE [pmv_id] = @PMV_ID

    IF @PLAN IS NULL
    BEGIN
        RAISERROR('La version indicada no existe.', 16, 1)
        RETURN
    END

    -- Un plan sin hitos no se publica: no generaria nada nunca.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito]
                    WHERE [pmh_plan_mantenimiento_version] = @PMV_ID AND [pmh_habilitado] = 1)
    BEGIN
        RAISERROR('No se puede publicar una version sin hitos.', 16, 1)
        RETURN
    END

    -- Un plan sin activos tampoco: no habria para que maquina generar.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo]
                    WHERE [pac_plan_mantenimiento_version] = @PMV_ID)
    BEGIN
        RAISERROR('No se puede publicar una version sin activos asociados.', 16, 1)
        RETURN
    END

    BEGIN TRY
        BEGIN TRANSACTION

        -- Retira la publicada anterior del mismo plan.
        UPDATE [dbo].[Plan_Mantenimiento_Version]
           SET [pmv_plan_version_estado]  = 3,          -- RETIRADO
               [pmv_fecha_retiro]         = GETDATE(),
               [pmv_usuario_actualizacion]= @USUARIO,
               [pmv_fecha_actualizacion]  = GETDATE()
         WHERE [pmv_plan_mantenimiento]   = @PLAN
           AND [pmv_plan_version_estado]  = 2
           AND [pmv_id]                  <> @PMV_ID

        UPDATE [dbo].[Plan_Mantenimiento_Version]
           SET [pmv_plan_version_estado]  = 2,          -- PUBLICADO
               [pmv_fecha_publicacion]    = GETDATE(),
               [pmv_usuario_publicacion]  = @USUARIO,
               [pmv_usuario_actualizacion]= @USUARIO,
               [pmv_fecha_actualizacion]  = GETDATE()
         WHERE [pmv_id]                   = @PMV_ID
           AND [pmv_plan_version_estado]  = 1           -- <- la carrera se decide aqui

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La version ya no estaba en BORRADOR. Otro usuario la publico o la retiro.', 16, 1)
            RETURN
        END

        COMMIT TRANSACTION
        SELECT @PMV_ID AS [pmv_id]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH
END
GO


/* ========================================================================
   11. VW_PLAN_OCURRENCIA_PENDIENTE

       El estado VENCIDA no se guarda: se deriva. Una ocurrencia esta
       vencida si paso su fecha limite y no se completo. Guardarlo como
       estado obligaria a un job que "vence" filas cada noche, y bastaria
       que ese job fallara un dia para que el tablero mienta.
   ======================================================================== */

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VW_PLAN_OCURRENCIA_PENDIENTE]') AND type = 'V')
    DROP VIEW [dbo].[VW_PLAN_OCURRENCIA_PENDIENTE]
GO

CREATE VIEW [dbo].[VW_PLAN_OCURRENCIA_PENDIENTE]
AS
SELECT
    PMO.[pmo_id],
    PMO.[pmo_cliente],
    PMO.[pmo_activo],
    ACT.[act_codigo],
    ACT.[act_nombre],
    PMH.[pmh_codigo]                    AS [hito_codigo],
    PMH.[pmh_nombre]                    AS [hito_nombre],
    PMA.[pma_nombre]                    AS [plan_nombre],
    PMO.[pmo_fecha_programada_utc],
    PMO.[pmo_fecha_limite_utc],
    PMO.[pmo_fecha_programada_original_utc],
    PMO.[pmo_plan_ocurrencia_estado],
    PMO.[pmo_orden_trabajo],
    -- Estado derivado, no almacenado.
    CASE
        WHEN PMO.[pmo_plan_ocurrencia_estado] IN (4, 6, 7) THEN 'CERRADA'
        WHEN PMO.[pmo_fecha_limite_utc] IS NOT NULL
             AND PMO.[pmo_fecha_limite_utc] < GETUTCDATE()          THEN 'VENCIDA'
        WHEN PMO.[pmo_fecha_programada_utc] < GETUTCDATE()          THEN 'ATRASADA'
        WHEN PMO.[pmo_fecha_disponible_utc] IS NOT NULL
             AND PMO.[pmo_fecha_disponible_utc] <= GETUTCDATE()     THEN 'DISPONIBLE'
        ELSE 'FUTURA'
    END                                 AS [situacion],
    DATEDIFF(DAY, GETUTCDATE(), PMO.[pmo_fecha_programada_utc]) AS [dia_restante],
    -- Cuantas veces se movio: 0 = nunca.
    CASE WHEN PMO.[pmo_ocurrencia_origen] IS NULL THEN 0 ELSE 1 END AS [fue_reprogramada]
FROM [dbo].[Plan_Mantenimiento_Ocurrencia] PMO
    INNER JOIN [dbo].[Plan_Mantenimiento_Hito]    PMH ON PMH.[pmh_id]  = PMO.[pmo_plan_mantenimiento_hito]
    INNER JOIN [dbo].[Plan_Mantenimiento_Version] PMV ON PMV.[pmv_id]  = PMH.[pmh_plan_mantenimiento_version]
    INNER JOIN [dbo].[Plan_Mantenimiento]         PMA ON PMA.[pma_id]  = PMV.[pmv_plan_mantenimiento]
    INNER JOIN [dbo].[Activo]                     ACT ON ACT.[act_id]  = PMO.[pmo_activo]
WHERE PMO.[pmo_habilitado] = 1
GO


PRINT 'Bloque 14 PLANES: 10 tablas, 1 funcion, 1 SP y 1 vista procesados.'
GO
