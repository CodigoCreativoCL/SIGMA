﻿﻿﻿﻿USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  20-08-2026
-- DESCRIPTION:     D7 -- CHECKLIST DINAMICO: PLANTILLA, VERSION Y EJECUCION.
-- =============================================
-- Ver SIGMA_MODELO_LOGICO_v2.md §5.14 y §8.7
-- ORDEN: despues de 14_PLANES.sql
--
-- ESTO REEMPLAZA AL CHECKLIST LEGADO
--   Checklist, Checklist_Detalle y CheckList_Detalle_ComboBox se eliminan
--   en 00_SANEAMIENTO. El legado no versionaba: editar una plantilla
--   cambiaba retroactivamente el significado de las ejecuciones pasadas.
--
-- TRES NIVELES, Y CADA UNO EXISTE POR UNA RAZON
--   Checklist_Plantilla          el concepto: "Ronda diaria sala blowers"
--   Checklist_Plantilla_Version  lo que se congela al publicar
--   Checklist_Plantilla_Seccion  agrupa items en pantalla
--   Checklist_Plantilla_Item     la pregunta concreta
--
--   La ejecucion apunta a la VERSION, no a la plantilla. Por eso una
--   ronda de hace un año se reconstruye con sus preguntas de entonces,
--   en su orden, con sus unidades y sus umbrales de entonces.
--
-- EL ITEM PUEDE GENERAR UNA MEDICION
--   cpi_genera_medicion + cpi_activo_variable convierten una respuesta
--   numerica del checklist en una fila de Activo_Medicion. Es lo que
--   hace que "temperatura del descanso: 78" alimente la serie historica
--   y, mas adelante, al modelo predictivo -- sin que el tecnico tenga que
--   escribir el mismo numero dos veces en dos pantallas distintas.
--
-- LOS CUATRO UMBRALES NO SON DECORACION
--   minimo / advertencia / critico / maximo producen cer_severidad, y la
--   severidad decide si se pide comentario, si se exige foto, si nace un
--   hallazgo y si nace una alerta. Sin umbrales, el checklist recoge
--   numeros que nadie mira.
--
-- NI EL HALLAZGO NI LA ALERTA CREAN UNA OT SOLOS
--   Proponen. La OT la crea una persona autorizada. Un sistema que abre
--   ordenes de trabajo por su cuenta genera ruido, y el ruido se ignora.
--
-- IDEMPOTENTE: se puede ejecutar las veces que sea.
-- =============================================


/* ========================================================================
   1. CHECKLIST_PLANTILLA (cpl) -- el concepto estable
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Plantilla]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Plantilla]
    (
        [cpl_id]                        INT             NOT NULL IDENTITY(1,1),
        [cpl_cliente]                   INT             NOT NULL,
        [cpl_cliente_instalacion]       INT             NULL,
        [cpl_checklist_asignacion_tipo] INT             NULL,
        [cpl_codigo]                    NVARCHAR(50)    NOT NULL,
        [cpl_nombre]                    NVARCHAR(200)   NOT NULL,
        [cpl_descripcion]               NVARCHAR(MAX)   NULL,
        [cpl_activo_tipo]               INT             NULL,
        [cpl_usuario_creacion]          INT             NOT NULL,
        [cpl_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_CPL_FECHA_CREACION DEFAULT GETDATE(),
        [cpl_usuario_actualizacion]     INT             NULL,
        [cpl_fecha_actualizacion]       DATETIME        NULL,
        [cpl_habilitado]                BIT             NOT NULL CONSTRAINT DF_CPL_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_PLANTILLA PRIMARY KEY CLUSTERED ([cpl_id] ASC),
        CONSTRAINT FK_CPL_CLIENTE     FOREIGN KEY ([cpl_cliente])             REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_CPL_INSTALACION FOREIGN KEY ([cpl_cliente_instalacion]) REFERENCES [dbo].[Cliente_Instalacion] ([cin_id]),
        CONSTRAINT FK_CPL_TIPO        FOREIGN KEY ([cpl_checklist_asignacion_tipo]) REFERENCES [dbo].[Checklist_Asignacion_Tipo] ([cat_id]),
        CONSTRAINT FK_CPL_ACTIVO_TIPO FOREIGN KEY ([cpl_activo_tipo])         REFERENCES [dbo].[Activo_Tipo] ([ati_id]),
        CONSTRAINT UX_CPL_CLIENTE_CODIGO UNIQUE ([cpl_cliente], [cpl_codigo])
    )
    PRINT 'Tabla Checklist_Plantilla creada correctamente.'
END
ELSE PRINT 'Tabla Checklist_Plantilla ya existe.'
GO


/* ========================================================================
   2. CHECKLIST_PLANTILLA_VERSION (cpv) -- lo que se congela

      Mismo patron que Plan_Mantenimiento_Version, y a proposito: dos
      conceptos que se comportan igual deben modelarse igual, o el
      equipo tiene que recordar dos reglas donde bastaba una.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Plantilla_Version]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Plantilla_Version]
    (
        [cpv_id]                        INT             NOT NULL IDENTITY(1,1),
        [cpv_checklist_plantilla]       INT             NOT NULL,
        [cpv_numero]                    INT             NOT NULL,
        [cpv_checklist_version_estado]  INT             NOT NULL,   -- BORRADOR / PUBLICADO / RETIRADO
        [cpv_fecha_publicacion]         DATETIME        NULL,
        [cpv_usuario_publicacion]       INT             NULL,
        [cpv_fecha_retiro]              DATETIME        NULL,
        [cpv_observacion]               NVARCHAR(MAX)   NULL,
        [cpv_usuario_creacion]          INT             NOT NULL,
        [cpv_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_CPV_FECHA_CREACION DEFAULT GETDATE(),
        [cpv_usuario_actualizacion]     INT             NULL,
        [cpv_fecha_actualizacion]       DATETIME        NULL,
        [cpv_habilitado]                BIT             NOT NULL CONSTRAINT DF_CPV_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_PLANTILLA_VERSION PRIMARY KEY CLUSTERED ([cpv_id] ASC),
        CONSTRAINT FK_CPV_PLANTILLA   FOREIGN KEY ([cpv_checklist_plantilla]) REFERENCES [dbo].[Checklist_Plantilla] ([cpl_id]),
        CONSTRAINT FK_CPV_ESTADO      FOREIGN KEY ([cpv_checklist_version_estado]) REFERENCES [dbo].[Checklist_Version_Estado] ([cve_id]),
        CONSTRAINT FK_CPV_PUBLICADOR  FOREIGN KEY ([cpv_usuario_publicacion]) REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT UX_CPV_PLANTILLA_NUMERO UNIQUE ([cpv_checklist_plantilla], [cpv_numero]),
        CONSTRAINT CK_CPV_NUMERO CHECK ([cpv_numero] >= 1)
    )
    PRINT 'Tabla Checklist_Plantilla_Version creada correctamente.'
END
ELSE PRINT 'Tabla Checklist_Plantilla_Version ya existe.'
GO


/* ========================================================================
   3. CHECKLIST_PLANTILLA_SECCION (cps)

      Existe por la pantalla del telefono. Veinte preguntas seguidas en
      una lista plana se llenan mal; agrupadas en "Motor", "Lubricacion",
      "Seguridad" se llenan bien. La seccion tambien permite colapsar lo
      que no aplica sin borrarlo.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Plantilla_Seccion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Plantilla_Seccion]
    (
        [cps_id]                           INT             NOT NULL IDENTITY(1,1),
        [cps_checklist_plantilla_version]  INT             NOT NULL,
        [cps_codigo]                       NVARCHAR(50)    NOT NULL,
        [cps_nombre]                       NVARCHAR(200)   NOT NULL,
        [cps_descripcion]                  NVARCHAR(500)   NULL,
        [cps_orden]                        INT             NOT NULL CONSTRAINT DF_CPS_ORDEN DEFAULT 1,
        [cps_usuario_creacion]             INT             NOT NULL,
        [cps_fecha_creacion]               DATETIME        NOT NULL CONSTRAINT DF_CPS_FECHA_CREACION DEFAULT GETDATE(),
        [cps_usuario_actualizacion]        INT             NULL,
        [cps_fecha_actualizacion]          DATETIME        NULL,
        [cps_habilitado]                   BIT             NOT NULL CONSTRAINT DF_CPS_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_PLANTILLA_SECCION PRIMARY KEY CLUSTERED ([cps_id] ASC),
        CONSTRAINT FK_CPS_VERSION FOREIGN KEY ([cps_checklist_plantilla_version]) REFERENCES [dbo].[Checklist_Plantilla_Version] ([cpv_id]),
        CONSTRAINT UX_CPS_VERSION_CODIGO UNIQUE ([cps_checklist_plantilla_version], [cps_codigo]),
        CONSTRAINT CK_CPS_ORDEN CHECK ([cps_orden] >= 1)
    )
    PRINT 'Tabla Checklist_Plantilla_Seccion creada correctamente.'
END
ELSE PRINT 'Tabla Checklist_Plantilla_Seccion ya existe.'
GO


/* ========================================================================
   4. CHECKLIST_PLANTILLA_ITEM (cpi) -- la pregunta

      cpi_genera_medicion es el puente entre "el tecnico anoto 78" y la
      serie historica de temperatura del activo. Sin ese puente, el
      checklist y las mediciones son dos silos y el modelo predictivo se
      queda sin la mitad de los datos que la planta ya recoge a diario.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Plantilla_Item]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Plantilla_Item]
    (
        [cpi_id]                          INT             NOT NULL IDENTITY(1,1),
        [cpi_checklist_plantilla_version] INT             NOT NULL,
        [cpi_checklist_plantilla_seccion] INT             NULL,
        [cpi_codigo]                      NVARCHAR(50)    NOT NULL,
        [cpi_texto]                       NVARCHAR(500)   NOT NULL,
        [cpi_ayuda]                       NVARCHAR(500)   NULL,
        [cpi_checklist_item_tipo]         INT             NOT NULL,
        [cpi_orden]                       INT             NOT NULL CONSTRAINT DF_CPI_ORDEN DEFAULT 1,
        [cpi_obligatorio]                 BIT             NOT NULL CONSTRAINT DF_CPI_OBLIGATORIO DEFAULT 1,
        [cpi_permite_comentario]          BIT             NOT NULL CONSTRAINT DF_CPI_COMENTARIO DEFAULT 1,
        [cpi_requiere_evidencia]          BIT             NOT NULL CONSTRAINT DF_CPI_EVIDENCIA DEFAULT 0,
        [cpi_unidad_medida]               INT             NULL,      -- unidad esperada de la respuesta numerica
        [cpi_genera_medicion]             BIT             NOT NULL CONSTRAINT DF_CPI_GENERA_MEDICION DEFAULT 0,
        [cpi_activo_variable]             INT             NULL,      -- a que variable del activo se manda
        [cpi_usuario_creacion]            INT             NOT NULL,
        [cpi_fecha_creacion]              DATETIME        NOT NULL CONSTRAINT DF_CPI_FECHA_CREACION DEFAULT GETDATE(),
        [cpi_usuario_actualizacion]       INT             NULL,
        [cpi_fecha_actualizacion]         DATETIME        NULL,
        [cpi_habilitado]                  BIT             NOT NULL CONSTRAINT DF_CPI_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_PLANTILLA_ITEM PRIMARY KEY CLUSTERED ([cpi_id] ASC),
        CONSTRAINT FK_CPI_VERSION  FOREIGN KEY ([cpi_checklist_plantilla_version]) REFERENCES [dbo].[Checklist_Plantilla_Version] ([cpv_id]),
        CONSTRAINT FK_CPI_SECCION  FOREIGN KEY ([cpi_checklist_plantilla_seccion]) REFERENCES [dbo].[Checklist_Plantilla_Seccion] ([cps_id]),
        CONSTRAINT FK_CPI_TIPO     FOREIGN KEY ([cpi_checklist_item_tipo])         REFERENCES [dbo].[Checklist_Item_Tipo] ([cit_id]),
        CONSTRAINT FK_CPI_UNIDAD   FOREIGN KEY ([cpi_unidad_medida])               REFERENCES [dbo].[Unidad_Medida] ([ume_id]),
        CONSTRAINT FK_CPI_VARIABLE FOREIGN KEY ([cpi_activo_variable])             REFERENCES [dbo].[Activo_Variable] ([ava_id]),
        CONSTRAINT UX_CPI_VERSION_CODIGO UNIQUE ([cpi_checklist_plantilla_version], [cpi_codigo]),
        CONSTRAINT CK_CPI_ORDEN CHECK ([cpi_orden] >= 1),
        -- Si genera medicion hay que decir a que variable. Si no, la medicion no tiene donde ir.
        CONSTRAINT CK_CPI_MEDICION CHECK ([cpi_genera_medicion] = 0 OR [cpi_activo_variable] IS NOT NULL)
    )
    CREATE NONCLUSTERED INDEX IX_CPI_VERSION_ORDEN ON [dbo].[Checklist_Plantilla_Item] ([cpi_checklist_plantilla_version], [cpi_orden])
    PRINT 'Tabla Checklist_Plantilla_Item creada correctamente.'
END
ELSE PRINT 'Tabla Checklist_Plantilla_Item ya existe.'
GO


/* ========================================================================
   5. CHECKLIST_ITEM_OPCION (cio) -- las alternativas de una lista

      Reemplaza a CheckList_Detalle_ComboBox del legado. cio_es_conforme
      es lo que permite calcular "% de conformidad" sin que el codigo
      tenga que saber que 'OK' y 'BUENO' significan lo mismo.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Item_Opcion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Item_Opcion]
    (
        [cio_id]                        INT             NOT NULL IDENTITY(1,1),
        [cio_checklist_plantilla_item]  INT             NOT NULL,
        [cio_codigo]                    NVARCHAR(50)    NOT NULL,
        [cio_texto]                     NVARCHAR(200)   NOT NULL,
        [cio_valor]                     DECIMAL(18,6)   NULL,
        [cio_orden]                     INT             NOT NULL CONSTRAINT DF_CIO_ORDEN DEFAULT 1,
        [cio_es_conforme]               BIT             NOT NULL CONSTRAINT DF_CIO_CONFORME DEFAULT 1,
        [cio_severidad]                 INT             NULL,
        [cio_requiere_comentario]       BIT             NOT NULL CONSTRAINT DF_CIO_COMENTARIO DEFAULT 0,
        [cio_requiere_evidencia]        BIT             NOT NULL CONSTRAINT DF_CIO_EVIDENCIA DEFAULT 0,
        [cio_usuario_creacion]          INT             NOT NULL,
        [cio_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_CIO_FECHA_CREACION DEFAULT GETDATE(),
        [cio_usuario_actualizacion]     INT             NULL,
        [cio_fecha_actualizacion]       DATETIME        NULL,
        [cio_habilitado]                BIT             NOT NULL CONSTRAINT DF_CIO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_ITEM_OPCION PRIMARY KEY CLUSTERED ([cio_id] ASC),
        CONSTRAINT FK_CIO_ITEM      FOREIGN KEY ([cio_checklist_plantilla_item]) REFERENCES [dbo].[Checklist_Plantilla_Item] ([cpi_id]),
        CONSTRAINT FK_CIO_SEVERIDAD FOREIGN KEY ([cio_severidad])                REFERENCES [dbo].[Severidad] ([sev_id]),
        CONSTRAINT UX_CIO_ITEM_CODIGO UNIQUE ([cio_checklist_plantilla_item], [cio_codigo]),
        CONSTRAINT CK_CIO_ORDEN CHECK ([cio_orden] >= 1)
    )
    PRINT 'Tabla Checklist_Item_Opcion creada correctamente.'
END
ELSE PRINT 'Tabla Checklist_Item_Opcion ya existe.'
GO


/* ========================================================================
   6. CHECKLIST_ITEM_VALIDACION (civ) -- los cuatro umbrales

      minimo -- advertencia -- critico -- maximo, en ese orden. La
      severidad que sale de aqui decide cuatro cosas distintas, y por eso
      los cuatro BIT que siguen no son configuracion suelta: son la
      politica de la planta escrita una sola vez.

      No hay CHECK que ordene los umbrales entre si porque no siempre
      aplican los cuatro: una presion tiene minimo y maximo pero puede no
      tener advertencia. Validar el subconjunto informado es trabajo del
      SP, que si conoce el caso.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Item_Validacion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Item_Validacion]
    (
        [civ_id]                              INT             NOT NULL IDENTITY(1,1),
        [civ_checklist_plantilla_item]        INT             NOT NULL,
        [civ_valor_minimo]                    DECIMAL(18,6)   NULL,
        [civ_valor_maximo]                    DECIMAL(18,6)   NULL,
        [civ_valor_advertencia]               DECIMAL(18,6)   NULL,
        [civ_valor_critico]                   DECIMAL(18,6)   NULL,
        [civ_largo_minimo]                    INT             NULL,
        [civ_largo_maximo]                    INT             NULL,
        [civ_expresion_regular]               NVARCHAR(500)   NULL,
        [civ_unidad_medida]                   INT             NULL,
        [civ_requiere_comentario_fuera_rango] BIT             NOT NULL CONSTRAINT DF_CIV_COMENTARIO DEFAULT 0,
        [civ_requiere_evidencia_fuera_rango]  BIT             NOT NULL CONSTRAINT DF_CIV_EVIDENCIA DEFAULT 0,
        [civ_genera_alerta]                   BIT             NOT NULL CONSTRAINT DF_CIV_ALERTA DEFAULT 0,
        [civ_genera_hallazgo]                 BIT             NOT NULL CONSTRAINT DF_CIV_HALLAZGO DEFAULT 0,
        [civ_mensaje]                         NVARCHAR(500)   NULL,
        [civ_usuario_creacion]                INT             NOT NULL,
        [civ_fecha_creacion]                  DATETIME        NOT NULL CONSTRAINT DF_CIV_FECHA_CREACION DEFAULT GETDATE(),
        [civ_usuario_actualizacion]           INT             NULL,
        [civ_fecha_actualizacion]             DATETIME        NULL,
        [civ_habilitado]                      BIT             NOT NULL CONSTRAINT DF_CIV_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_ITEM_VALIDACION PRIMARY KEY CLUSTERED ([civ_id] ASC),
        CONSTRAINT FK_CIV_ITEM   FOREIGN KEY ([civ_checklist_plantilla_item]) REFERENCES [dbo].[Checklist_Plantilla_Item] ([cpi_id]),
        CONSTRAINT FK_CIV_UNIDAD FOREIGN KEY ([civ_unidad_medida])            REFERENCES [dbo].[Unidad_Medida] ([ume_id]),
        CONSTRAINT UX_CIV_ITEM UNIQUE ([civ_checklist_plantilla_item]),
        CONSTRAINT CK_CIV_RANGO CHECK
            ([civ_valor_minimo] IS NULL OR [civ_valor_maximo] IS NULL OR [civ_valor_maximo] >= [civ_valor_minimo]),
        CONSTRAINT CK_CIV_LARGO CHECK
            ([civ_largo_minimo] IS NULL OR [civ_largo_maximo] IS NULL OR [civ_largo_maximo] >= [civ_largo_minimo])
    )
    PRINT 'Tabla Checklist_Item_Validacion creada correctamente.'
END
ELSE PRINT 'Tabla Checklist_Item_Validacion ya existe.'
GO


/* ========================================================================
   7. CHECKLIST_ITEM_DEPENDENCIA (cid) -- mostrar solo lo que aplica

      "Si respondio NO a 'la maquina esta operativa', no preguntes la
      temperatura". El operador de comparacion viene del catalogo, no de
      un string, para que la app y el servidor evaluen exactamente lo
      mismo.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Item_Dependencia]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Item_Dependencia]
    (
        [cid_id]                            INT             NOT NULL IDENTITY(1,1),
        [cid_checklist_plantilla_item]      INT             NOT NULL,   -- el item que se muestra u oculta
        [cid_item_condicion]                INT             NOT NULL,   -- el item cuya respuesta manda
        [cid_operador_comparacion]          INT             NOT NULL,
        [cid_valor_comparacion]             NVARCHAR(200)   NULL,
        [cid_checklist_item_opcion]         INT             NULL,       -- si la condicion es sobre una opcion
        [cid_dependencia_accion]            INT             NOT NULL,   -- MOSTRAR / OCULTAR / REQUERIR / BLOQUEAR
        [cid_usuario_creacion]              INT             NOT NULL,
        [cid_fecha_creacion]                DATETIME        NOT NULL CONSTRAINT DF_CID_FECHA_CREACION DEFAULT GETDATE(),
        [cid_usuario_actualizacion]         INT             NULL,
        [cid_fecha_actualizacion]           DATETIME        NULL,
        [cid_habilitado]                    BIT             NOT NULL CONSTRAINT DF_CID_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_ITEM_DEPENDENCIA PRIMARY KEY CLUSTERED ([cid_id] ASC),
        CONSTRAINT FK_CID_ITEM      FOREIGN KEY ([cid_checklist_plantilla_item]) REFERENCES [dbo].[Checklist_Plantilla_Item] ([cpi_id]),
        CONSTRAINT FK_CID_CONDICION FOREIGN KEY ([cid_item_condicion])           REFERENCES [dbo].[Checklist_Plantilla_Item] ([cpi_id]),
        CONSTRAINT FK_CID_OPERADOR  FOREIGN KEY ([cid_operador_comparacion])     REFERENCES [dbo].[Operador_Comparacion] ([opc_id]),
        CONSTRAINT FK_CID_OPCION    FOREIGN KEY ([cid_checklist_item_opcion])    REFERENCES [dbo].[Checklist_Item_Opcion] ([cio_id]),
        CONSTRAINT FK_CID_ACCION    FOREIGN KEY ([cid_dependencia_accion])       REFERENCES [dbo].[Dependencia_Accion] ([dac_id]),
        -- Un item no puede depender de si mismo: seria un bucle infinito en la app.
        CONSTRAINT CK_CID_NO_AUTO CHECK ([cid_checklist_plantilla_item] <> [cid_item_condicion])
    )
    PRINT 'Tabla Checklist_Item_Dependencia creada correctamente.'
END
ELSE PRINT 'Tabla Checklist_Item_Dependencia ya existe.'
GO


/* ========================================================================
   8. CHECKLIST_PROGRAMACION (cpr) -- el checklist se engancha al motor

      No tiene recurrencia propia: apunta a Programacion, igual que los
      hitos de plan y las tareas. Un motor, tres consumidores.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Programacion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Programacion]
    (
        [cpr_id]                          INT             NOT NULL IDENTITY(1,1),
        [cpr_cliente]                     INT             NOT NULL,
        [cpr_checklist_plantilla_version] INT             NOT NULL,
        [cpr_programacion]                INT             NOT NULL,
        [cpr_activo]                      INT             NULL,
        [cpr_instalacion_area]            INT             NULL,
        [cpr_grupo_trabajo]               INT             NULL,
        [cpr_usuario_responsable]         INT             NULL,
        [cpr_nombre]                      NVARCHAR(200)   NOT NULL,
        [cpr_usuario_creacion]            INT             NOT NULL,
        [cpr_fecha_creacion]              DATETIME        NOT NULL CONSTRAINT DF_CPR_FECHA_CREACION DEFAULT GETDATE(),
        [cpr_usuario_actualizacion]       INT             NULL,
        [cpr_fecha_actualizacion]         DATETIME        NULL,
        [cpr_habilitado]                  BIT             NOT NULL CONSTRAINT DF_CPR_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_PROGRAMACION PRIMARY KEY CLUSTERED ([cpr_id] ASC),
        CONSTRAINT FK_CPR_CLIENTE      FOREIGN KEY ([cpr_cliente])                     REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_CPR_VERSION      FOREIGN KEY ([cpr_checklist_plantilla_version]) REFERENCES [dbo].[Checklist_Plantilla_Version] ([cpv_id]),
        CONSTRAINT FK_CPR_PROGRAMACION FOREIGN KEY ([cpr_programacion])                REFERENCES [dbo].[Programacion] ([pro_id]),
        CONSTRAINT FK_CPR_ACTIVO       FOREIGN KEY ([cpr_activo])                      REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_CPR_AREA         FOREIGN KEY ([cpr_instalacion_area])            REFERENCES [dbo].[Instalacion_Area] ([iar_id]),
        CONSTRAINT FK_CPR_GRUPO        FOREIGN KEY ([cpr_grupo_trabajo])               REFERENCES [dbo].[Grupo_Trabajo] ([gtr_id]),
        CONSTRAINT FK_CPR_RESPONSABLE  FOREIGN KEY ([cpr_usuario_responsable])         REFERENCES [dbo].[Usuario] ([usu_id]),
        -- Un checklist se hace sobre una maquina o sobre un area. Sin ninguna de las dos no hay donde ir.
        CONSTRAINT CK_CPR_OBJETIVO CHECK ([cpr_activo] IS NOT NULL OR [cpr_instalacion_area] IS NOT NULL)
    )
    PRINT 'Tabla Checklist_Programacion creada correctamente.'
END
ELSE PRINT 'Tabla Checklist_Programacion ya existe.'
GO


/* ========================================================================
   9. CHECKLIST_OCURRENCIA (coc) -- la ronda concreta de hoy

      coc_fecha_programada_original_utc + coc_ocurrencia_origen: misma
      regla que en los planes. Reprogramar deja rastro.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Ocurrencia]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Ocurrencia]
    (
        [coc_id]                            INT                 NOT NULL IDENTITY(1,1),
        [coc_uuid]                          UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_COC_UUID DEFAULT NEWID(),
        [coc_cliente]                       INT                 NOT NULL,
        [coc_checklist_programacion]        INT                 NULL,   -- NULL = ocurrencia creada a mano
        [coc_checklist_plantilla_version]   INT                 NOT NULL,
        [coc_activo]                        INT                 NULL,
        [coc_instalacion_area]              INT                 NULL,
        [coc_checklist_ocurrencia_estado]   INT                 NOT NULL,
        [coc_fecha_programada_utc]          DATETIME            NOT NULL,
        [coc_fecha_disponible_utc]          DATETIME            NULL,
        [coc_fecha_limite_utc]              DATETIME            NULL,
        [coc_fecha_programada_original_utc] DATETIME            NULL,
        [coc_ocurrencia_origen]             INT                 NULL,
        [coc_usuario_creacion]              INT                 NOT NULL,
        [coc_fecha_creacion]                DATETIME            NOT NULL CONSTRAINT DF_COC_FECHA_CREACION DEFAULT GETDATE(),
        [coc_usuario_actualizacion]         INT                 NULL,
        [coc_fecha_actualizacion]           DATETIME            NULL,
        [coc_habilitado]                    BIT                 NOT NULL CONSTRAINT DF_COC_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_OCURRENCIA PRIMARY KEY CLUSTERED ([coc_id] ASC),
        CONSTRAINT FK_COC_CLIENTE      FOREIGN KEY ([coc_cliente])                       REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_COC_PROGRAMACION FOREIGN KEY ([coc_checklist_programacion])        REFERENCES [dbo].[Checklist_Programacion] ([cpr_id]),
        CONSTRAINT FK_COC_VERSION      FOREIGN KEY ([coc_checklist_plantilla_version])   REFERENCES [dbo].[Checklist_Plantilla_Version] ([cpv_id]),
        CONSTRAINT FK_COC_ACTIVO       FOREIGN KEY ([coc_activo])                        REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_COC_AREA         FOREIGN KEY ([coc_instalacion_area])              REFERENCES [dbo].[Instalacion_Area] ([iar_id]),
        CONSTRAINT FK_COC_ESTADO       FOREIGN KEY ([coc_checklist_ocurrencia_estado])   REFERENCES [dbo].[Checklist_Ocurrencia_Estado] ([coe_id]),
        CONSTRAINT FK_COC_ORIGEN       FOREIGN KEY ([coc_ocurrencia_origen])             REFERENCES [dbo].[Checklist_Ocurrencia] ([coc_id]),
        CONSTRAINT UX_COC_UUID UNIQUE ([coc_uuid]),
        CONSTRAINT CK_COC_OBJETIVO CHECK ([coc_activo] IS NOT NULL OR [coc_instalacion_area] IS NOT NULL)
    )
    CREATE NONCLUSTERED INDEX IX_COC_CLIENTE_ESTADO_FECHA
        ON [dbo].[Checklist_Ocurrencia] ([coc_cliente], [coc_checklist_ocurrencia_estado], [coc_fecha_programada_utc])
    PRINT 'Tabla Checklist_Ocurrencia creada correctamente.'
END
ELSE PRINT 'Tabla Checklist_Ocurrencia ya existe.'
GO


/* ========================================================================
   10. CHECKLIST_OCURRENCIA_ASIGNACION (coa)

       Usuario o grupo, exactamente uno. El CHECK lo obliga. Sin el, una
       fila con ambos NULL es una asignacion a nadie, y una fila con
       ambos informados es una asignacion ambigua -- las dos se ven bien
       en un INSERT y las dos rompen el tablero del planificador.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Ocurrencia_Asignacion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Ocurrencia_Asignacion]
    (
        [coa_id]                        INT         NOT NULL IDENTITY(1,1),
        [coa_checklist_ocurrencia]      INT         NOT NULL,
        [coa_usuario]                   INT         NULL,
        [coa_grupo_trabajo]             INT         NULL,
        [coa_es_responsable]            BIT         NOT NULL CONSTRAINT DF_COA_RESPONSABLE DEFAULT 1,
        [coa_fecha_asignacion_utc]      DATETIME    NOT NULL CONSTRAINT DF_COA_FECHA_ASIGNACION DEFAULT GETUTCDATE(),
        [coa_fecha_aceptacion_utc]      DATETIME    NULL,
        [coa_usuario_creacion]          INT         NOT NULL,
        [coa_fecha_creacion]            DATETIME    NOT NULL CONSTRAINT DF_COA_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_CHECKLIST_OCURRENCIA_ASIGNACION PRIMARY KEY CLUSTERED ([coa_id] ASC),
        CONSTRAINT FK_COA_OCURRENCIA FOREIGN KEY ([coa_checklist_ocurrencia]) REFERENCES [dbo].[Checklist_Ocurrencia] ([coc_id]),
        CONSTRAINT FK_COA_USUARIO    FOREIGN KEY ([coa_usuario])              REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_COA_GRUPO      FOREIGN KEY ([coa_grupo_trabajo])        REFERENCES [dbo].[Grupo_Trabajo] ([gtr_id]),
        CONSTRAINT CK_COA_DESTINATARIO CHECK
            ((CASE WHEN [coa_usuario] IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN [coa_grupo_trabajo] IS NULL THEN 0 ELSE 1 END) = 1)
    )
    CREATE NONCLUSTERED INDEX IX_COA_OCURRENCIA ON [dbo].[Checklist_Ocurrencia_Asignacion] ([coa_checklist_ocurrencia])
    PRINT 'Tabla Checklist_Ocurrencia_Asignacion creada correctamente.'
END
ELSE PRINT 'Tabla Checklist_Ocurrencia_Asignacion ya existe.'
GO


/* ========================================================================
   11. CHECKLIST_OCURRENCIA_HISTORIAL (coh) -- append-only
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Ocurrencia_Historial]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Ocurrencia_Historial]
    (
        [coh_id]                        INT             NOT NULL IDENTITY(1,1),
        [coh_checklist_ocurrencia]      INT             NOT NULL,
        [coh_estado_anterior]           INT             NULL,
        [coh_estado_nuevo]              INT             NOT NULL,
        [coh_fecha_anterior_utc]        DATETIME        NULL,
        [coh_fecha_nueva_utc]           DATETIME        NULL,
        [coh_motivo]                    NVARCHAR(500)   NULL,
        [coh_usuario_creacion]          INT             NOT NULL,
        [coh_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_COH_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_CHECKLIST_OCURRENCIA_HISTORIAL PRIMARY KEY CLUSTERED ([coh_id] ASC),
        CONSTRAINT FK_COH_OCURRENCIA      FOREIGN KEY ([coh_checklist_ocurrencia]) REFERENCES [dbo].[Checklist_Ocurrencia] ([coc_id]),
        CONSTRAINT FK_COH_ESTADO_ANTERIOR FOREIGN KEY ([coh_estado_anterior])      REFERENCES [dbo].[Checklist_Ocurrencia_Estado] ([coe_id]),
        CONSTRAINT FK_COH_ESTADO_NUEVO    FOREIGN KEY ([coh_estado_nuevo])         REFERENCES [dbo].[Checklist_Ocurrencia_Estado] ([coe_id]),
        CONSTRAINT FK_COH_USUARIO         FOREIGN KEY ([coh_usuario_creacion])     REFERENCES [dbo].[Usuario] ([usu_id])
    )
    CREATE NONCLUSTERED INDEX IX_COH_OCURRENCIA ON [dbo].[Checklist_Ocurrencia_Historial] ([coh_checklist_ocurrencia], [coh_fecha_creacion])
    PRINT 'Tabla Checklist_Ocurrencia_Historial creada correctamente.'
END
ELSE PRINT 'Tabla Checklist_Ocurrencia_Historial ya existe.'
GO


/* ========================================================================
   12. CHECKLIST_EJECUCION (cej) -- el llenado real

      Separada de la ocurrencia porque una ocurrencia puede ejecutarse
      mas de una vez (se rehizo, se corrigio) y porque la ejecucion tiene
      su propia geolocalizacion, su propio dispositivo y su propio
      horario, que son datos del acto de llenar, no de la programacion.

      cej_offline_creado registra que se lleno sin señal. Importa: es la
      diferencia entre "lo hizo a las 3 AM" y "lo sincronizo a las 3 AM".
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Ejecucion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Ejecucion]
    (
        [cej_id]                        INT                 NOT NULL IDENTITY(1,1),
        [cej_uuid]                      UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_CEJ_UUID DEFAULT NEWID(),
        [cej_cliente]                   INT                 NOT NULL,
        [cej_checklist_ocurrencia]      INT                 NULL,   -- NULL = ejecucion espontanea
        [cej_checklist_plantilla_version] INT               NOT NULL,
        [cej_activo]                    INT                 NULL,
        [cej_usuario_ejecutor]          INT                 NOT NULL,
        [cej_checklist_ejecucion_estado] INT                NOT NULL,
        [cej_fecha_inicio_utc]          DATETIME            NOT NULL CONSTRAINT DF_CEJ_FECHA_INICIO DEFAULT GETUTCDATE(),
        [cej_fecha_fin_utc]             DATETIME            NULL,
        [cej_duracion_minuto]           INT                 NULL,
        [cej_latitud]                   DECIMAL(9,6)        NULL,
        [cej_longitud]                  DECIMAL(9,6)        NULL,
        [cej_dispositivo]               NVARCHAR(200)       NULL,
        [cej_offline_creado]            BIT                 NOT NULL CONSTRAINT DF_CEJ_OFFLINE DEFAULT 0,
        [cej_fecha_sincronizacion_utc]  DATETIME            NULL,
        [cej_item_total]                INT                 NULL,
        [cej_item_respondido]           INT                 NULL,
        [cej_item_no_conforme]          INT                 NULL,
        [cej_observacion]               NVARCHAR(MAX)       NULL,
        [cej_usuario_creacion]          INT                 NOT NULL,
        [cej_fecha_creacion]            DATETIME            NOT NULL CONSTRAINT DF_CEJ_FECHA_CREACION DEFAULT GETDATE(),
        [cej_usuario_actualizacion]     INT                 NULL,
        [cej_fecha_actualizacion]       DATETIME            NULL,
        [cej_habilitado]                BIT                 NOT NULL CONSTRAINT DF_CEJ_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_EJECUCION PRIMARY KEY CLUSTERED ([cej_id] ASC),
        CONSTRAINT FK_CEJ_CLIENTE    FOREIGN KEY ([cej_cliente])                     REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_CEJ_OCURRENCIA FOREIGN KEY ([cej_checklist_ocurrencia])        REFERENCES [dbo].[Checklist_Ocurrencia] ([coc_id]),
        CONSTRAINT FK_CEJ_VERSION    FOREIGN KEY ([cej_checklist_plantilla_version]) REFERENCES [dbo].[Checklist_Plantilla_Version] ([cpv_id]),
        CONSTRAINT FK_CEJ_ACTIVO     FOREIGN KEY ([cej_activo])                      REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_CEJ_EJECUTOR   FOREIGN KEY ([cej_usuario_ejecutor])            REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_CEJ_ESTADO     FOREIGN KEY ([cej_checklist_ejecucion_estado])  REFERENCES [dbo].[Checklist_Ejecucion_Estado] ([cee_id]),
        -- UUID unico: la app manda el mismo INSERT dos veces si la red se corta a medias.
        CONSTRAINT UX_CEJ_UUID UNIQUE ([cej_uuid]),
        CONSTRAINT CK_CEJ_FECHAS CHECK ([cej_fecha_fin_utc] IS NULL OR [cej_fecha_fin_utc] >= [cej_fecha_inicio_utc])
    )
    CREATE NONCLUSTERED INDEX IX_CEJ_ACTIVO_FECHA ON [dbo].[Checklist_Ejecucion] ([cej_activo], [cej_fecha_inicio_utc])
    PRINT 'Tabla Checklist_Ejecucion creada correctamente.'
END
ELSE PRINT 'Tabla Checklist_Ejecucion ya existe.'
GO


/* ========================================================================
   13. CHECKLIST_EJECUCION_RESPUESTA (cer) -- una fila por pregunta

      cer_valor_canonico es la clave del asunto. El tecnico anota en la
      unidad que tiene a mano -- PSI, bar, kg/cm2 -- y el sistema guarda
      LAS DOS COSAS: lo que escribio y su equivalente en la unidad base.
      Comparar contra el umbral se hace sobre el canonico; mostrar en
      pantalla, sobre el original.

      cer_severidad se calcula al insertar y se guarda. Es la excepcion
      deliberada a "un estado derivable no es un estado": el umbral que
      se aplico puede cambiar en una version posterior de la plantilla,
      y recalcularlo despues daria una respuesta distinta a la que el
      tecnico vio en pantalla.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Ejecucion_Respuesta]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Ejecucion_Respuesta]
    (
        [cer_id]                        INT             NOT NULL IDENTITY(1,1),
        [cer_checklist_ejecucion]       INT             NOT NULL,
        [cer_checklist_plantilla_item]  INT             NOT NULL,
        [cer_valor_texto]               NVARCHAR(MAX)   NULL,
        [cer_valor_numero]              DECIMAL(18,6)   NULL,
        [cer_valor_fecha]               DATETIME        NULL,
        [cer_valor_booleano]            BIT             NULL,
        [cer_unidad_medida]             INT             NULL,      -- en que unidad lo escribio
        [cer_valor_canonico]            DECIMAL(18,6)   NULL,      -- lo mismo, en la unidad base
        [cer_unidad_canonica]           INT             NULL,
        [cer_fuera_rango]               BIT             NOT NULL CONSTRAINT DF_CER_FUERA_RANGO DEFAULT 0,
        [cer_severidad]                 NVARCHAR(20)    NULL,      -- NORMAL / ADVERTENCIA / CRITICO
        [cer_comentario]                NVARCHAR(MAX)   NULL,
        [cer_no_aplica]                 BIT             NOT NULL CONSTRAINT DF_CER_NO_APLICA DEFAULT 0,
        [cer_fecha_respuesta_utc]       DATETIME        NOT NULL CONSTRAINT DF_CER_FECHA_RESPUESTA DEFAULT GETUTCDATE(),
        [cer_usuario_creacion]          INT             NOT NULL,
        [cer_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_CER_FECHA_CREACION DEFAULT GETDATE(),
        [cer_usuario_actualizacion]     INT             NULL,
        [cer_fecha_actualizacion]       DATETIME        NULL,
        [cer_habilitado]                BIT             NOT NULL CONSTRAINT DF_CER_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_EJECUCION_RESPUESTA PRIMARY KEY CLUSTERED ([cer_id] ASC),
        CONSTRAINT FK_CER_EJECUCION FOREIGN KEY ([cer_checklist_ejecucion])      REFERENCES [dbo].[Checklist_Ejecucion] ([cej_id]),
        CONSTRAINT FK_CER_ITEM      FOREIGN KEY ([cer_checklist_plantilla_item]) REFERENCES [dbo].[Checklist_Plantilla_Item] ([cpi_id]),
        CONSTRAINT FK_CER_UNIDAD    FOREIGN KEY ([cer_unidad_medida])            REFERENCES [dbo].[Unidad_Medida] ([ume_id]),
        CONSTRAINT FK_CER_UNIDAD_CANONICA FOREIGN KEY ([cer_unidad_canonica])    REFERENCES [dbo].[Unidad_Medida] ([ume_id]),
        CONSTRAINT UX_CER_EJECUCION_ITEM UNIQUE ([cer_checklist_ejecucion], [cer_checklist_plantilla_item]),
        CONSTRAINT CK_CER_SEVERIDAD CHECK ([cer_severidad] IS NULL OR [cer_severidad] IN ('NORMAL', 'ADVERTENCIA', 'CRITICO'))
    )
    CREATE NONCLUSTERED INDEX IX_CER_FUERA_RANGO ON [dbo].[Checklist_Ejecucion_Respuesta] ([cer_checklist_ejecucion])
        WHERE [cer_fuera_rango] = 1
    PRINT 'Tabla Checklist_Ejecucion_Respuesta creada correctamente.'
END
ELSE PRINT 'Tabla Checklist_Ejecucion_Respuesta ya existe.'
GO


/* ========================================================================
   14. CHECKLIST_RESPUESTA_OPCION (cro) -- respuestas de seleccion multiple

      Tabla aparte en vez de una columna: un item de seleccion multiple
      admite N opciones, y meterlas como texto separado por comas
      haria imposible contar cuantas veces se marco "fuga de aceite".
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Respuesta_Opcion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Respuesta_Opcion]
    (
        [cro_id]                            INT         NOT NULL IDENTITY(1,1),
        [cro_checklist_ejecucion_respuesta] INT         NOT NULL,
        [cro_checklist_item_opcion]         INT         NOT NULL,
        [cro_usuario_creacion]              INT         NOT NULL,
        [cro_fecha_creacion]                DATETIME    NOT NULL CONSTRAINT DF_CRO_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_CHECKLIST_RESPUESTA_OPCION PRIMARY KEY CLUSTERED ([cro_id] ASC),
        CONSTRAINT FK_CRO_RESPUESTA FOREIGN KEY ([cro_checklist_ejecucion_respuesta]) REFERENCES [dbo].[Checklist_Ejecucion_Respuesta] ([cer_id]),
        CONSTRAINT FK_CRO_OPCION    FOREIGN KEY ([cro_checklist_item_opcion])         REFERENCES [dbo].[Checklist_Item_Opcion] ([cio_id]),
        CONSTRAINT UX_CRO_RESPUESTA_OPCION UNIQUE ([cro_checklist_ejecucion_respuesta], [cro_checklist_item_opcion])
    )
    PRINT 'Tabla Checklist_Respuesta_Opcion creada correctamente.'
END
ELSE PRINT 'Tabla Checklist_Respuesta_Opcion ya existe.'
GO


/* ========================================================================
   15. CHECKLIST_HALLAZGO (cha) -- lo que el checklist encontro

      El hallazgo PROPONE una OT; no la crea. cha_orden_trabajo se llena
      cuando una persona autorizada confirma. Mientras esta en NULL, el
      hallazgo aparece en la bandeja del planificador -- que es
      exactamente el comportamiento que se quiere: alguien tiene que
      decidir, y esa decision queda registrada con nombre y fecha.

      cha_generado_ia distingue el hallazgo que escribio el tecnico del
      que propuso el modelo a partir del dictado o del informe externo.
      No cambia el flujo -- ambos requieren confirmacion -- pero permite
      medir cuanto acierta la IA antes de confiarle mas.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Hallazgo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Hallazgo]
    (
        [cha_id]                            INT                 NOT NULL IDENTITY(1,1),
        [cha_uuid]                          UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_CHA_UUID DEFAULT NEWID(),
        [cha_cliente]                       INT                 NOT NULL,
        [cha_checklist_ejecucion]           INT                 NULL,
        [cha_checklist_ejecucion_respuesta] INT                 NULL,
        [cha_activo]                        INT                 NULL,
        [cha_activo_componente]             INT                 NULL,
        [cha_titulo]                        NVARCHAR(200)       NOT NULL,
        [cha_descripcion]                   NVARCHAR(MAX)       NULL,
        [cha_severidad]                     INT                 NULL,
        [cha_criticidad_nivel]              INT                 NULL,
        [cha_proceso_estado]                INT                 NOT NULL,
        [cha_generado_ia]                   BIT                 NOT NULL CONSTRAINT DF_CHA_GENERADO_IA DEFAULT 0,
        [cha_confianza_ia]                  DECIMAL(18,6)       NULL,
        [cha_orden_trabajo]                 INT                 NULL,   -- FK diferida (bloque 22)
        [cha_usuario_confirmacion]          INT                 NULL,
        [cha_fecha_confirmacion_utc]        DATETIME            NULL,
        [cha_motivo_descarte]               NVARCHAR(500)       NULL,
        [cha_usuario_creacion]              INT                 NOT NULL,
        [cha_fecha_creacion]                DATETIME            NOT NULL CONSTRAINT DF_CHA_FECHA_CREACION DEFAULT GETDATE(),
        [cha_usuario_actualizacion]         INT                 NULL,
        [cha_fecha_actualizacion]           DATETIME            NULL,
        [cha_habilitado]                    BIT                 NOT NULL CONSTRAINT DF_CHA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_HALLAZGO PRIMARY KEY CLUSTERED ([cha_id] ASC),
        CONSTRAINT FK_CHA_CLIENTE     FOREIGN KEY ([cha_cliente])                       REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_CHA_EJECUCION   FOREIGN KEY ([cha_checklist_ejecucion])            REFERENCES [dbo].[Checklist_Ejecucion] ([cej_id]),
        CONSTRAINT FK_CHA_RESPUESTA   FOREIGN KEY ([cha_checklist_ejecucion_respuesta])  REFERENCES [dbo].[Checklist_Ejecucion_Respuesta] ([cer_id]),
        CONSTRAINT FK_CHA_ACTIVO      FOREIGN KEY ([cha_activo])                         REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_CHA_COMPONENTE  FOREIGN KEY ([cha_activo_componente])              REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_CHA_SEVERIDAD   FOREIGN KEY ([cha_severidad])                      REFERENCES [dbo].[Severidad] ([sev_id]),
        CONSTRAINT FK_CHA_CRITICIDAD  FOREIGN KEY ([cha_criticidad_nivel])               REFERENCES [dbo].[Criticidad_Nivel] ([crn_id]),
        CONSTRAINT FK_CHA_ESTADO      FOREIGN KEY ([cha_proceso_estado])                 REFERENCES [dbo].[Proceso_Estado] ([pes_id]),
        CONSTRAINT FK_CHA_CONFIRMADOR FOREIGN KEY ([cha_usuario_confirmacion])           REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT UX_CHA_UUID UNIQUE ([cha_uuid]),
        -- Confirmar exige quien y cuando. Sin eso, "aprobado" no es trazable.
        CONSTRAINT CK_CHA_CONFIRMACION CHECK
            ([cha_orden_trabajo] IS NULL
             OR ([cha_usuario_confirmacion] IS NOT NULL AND [cha_fecha_confirmacion_utc] IS NOT NULL)),
        -- Si dice que lo genero la IA, tiene que traer la confianza con que lo genero.
        CONSTRAINT CK_CHA_IA CHECK ([cha_generado_ia] = 0 OR [cha_confianza_ia] IS NOT NULL)
    )
    CREATE NONCLUSTERED INDEX IX_CHA_PENDIENTE ON [dbo].[Checklist_Hallazgo] ([cha_cliente], [cha_fecha_creacion])
        WHERE [cha_orden_trabajo] IS NULL
    PRINT 'Tabla Checklist_Hallazgo creada correctamente.'
END
ELSE PRINT 'Tabla Checklist_Hallazgo ya existe.'
GO


/* ========================================================================
   16. FNC_CHECKLIST_SEVERIDAD (fnc)

      Una sola definicion de severidad para toda la aplicacion. La app
      Flutter la aplica offline con la misma tabla de umbrales que baja
      en la sincronizacion, y al subir el servidor la recalcula: si dan
      distinto, hay un bug, y se detecta en vez de quedar escondido.
   ======================================================================== */

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FNC_CHECKLIST_SEVERIDAD]') AND type IN ('FN','IF','TF'))
    DROP FUNCTION [dbo].[FNC_CHECKLIST_SEVERIDAD]
GO

CREATE FUNCTION [dbo].[FNC_CHECKLIST_SEVERIDAD]
(
    @ITEM       INT,
    @CANONICO   DECIMAL(18,6)
)
RETURNS NVARCHAR(20)
AS
BEGIN
    IF @CANONICO IS NULL RETURN NULL

    DECLARE @MIN DECIMAL(18,6), @MAX DECIMAL(18,6), @ADV DECIMAL(18,6), @CRI DECIMAL(18,6)

    SELECT @MIN = [civ_valor_minimo],
           @MAX = [civ_valor_maximo],
           @ADV = [civ_valor_advertencia],
           @CRI = [civ_valor_critico]
      FROM [dbo].[Checklist_Item_Validacion]
     WHERE [civ_checklist_plantilla_item] = @ITEM
       AND [civ_habilitado]               = 1

    -- Fuera del rango duro: critico, sin discusion.
    IF (@MIN IS NOT NULL AND @CANONICO < @MIN) RETURN 'CRITICO'
    IF (@MAX IS NOT NULL AND @CANONICO > @MAX) RETURN 'CRITICO'

    -- Dentro del rango, pero pasado el umbral critico.
    IF (@CRI IS NOT NULL AND @CANONICO >= @CRI) RETURN 'CRITICO'
    IF (@ADV IS NOT NULL AND @CANONICO >= @ADV) RETURN 'ADVERTENCIA'

    RETURN 'NORMAL'
END
GO


/* ========================================================================
   17. VW_CHECKLIST_HALLAZGO_PENDIENTE

       La bandeja del planificador. Lo que el checklist encontro y
       todavia no se convirtio ni se descarto. Si esta lista crece, el
       problema no es del sistema: es que nadie esta decidiendo.
   ======================================================================== */

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VW_CHECKLIST_HALLAZGO_PENDIENTE]') AND type = 'V')
    DROP VIEW [dbo].[VW_CHECKLIST_HALLAZGO_PENDIENTE]
GO

CREATE VIEW [dbo].[VW_CHECKLIST_HALLAZGO_PENDIENTE]
AS
SELECT
    CHA.[cha_id],
    CHA.[cha_cliente],
    CHA.[cha_titulo],
    CHA.[cha_descripcion],
    CHA.[cha_severidad],
    SEV.[sev_nombre]                AS [severidad_nombre],
    CHA.[cha_generado_ia],
    CHA.[cha_confianza_ia],
    CHA.[cha_activo],
    ACT.[act_codigo],
    ACT.[act_nombre],
    CEJ.[cej_usuario_ejecutor],
    CHA.[cha_fecha_creacion],
    DATEDIFF(DAY, CHA.[cha_fecha_creacion], GETDATE()) AS [dia_esperando],
    CASE WHEN CHA.[cha_motivo_descarte] IS NOT NULL THEN 'DESCARTADO' ELSE 'PENDIENTE' END AS [situacion]
FROM [dbo].[Checklist_Hallazgo] CHA
    LEFT JOIN [dbo].[Checklist_Ejecucion] CEJ ON CEJ.[cej_id] = CHA.[cha_checklist_ejecucion]
    LEFT JOIN [dbo].[Activo]              ACT ON ACT.[act_id] = CHA.[cha_activo]
    LEFT JOIN [dbo].[Severidad]           SEV ON SEV.[sev_id] = CHA.[cha_severidad]
WHERE CHA.[cha_orden_trabajo] IS NULL
  AND CHA.[cha_habilitado]    = 1
GO


PRINT 'Bloque 15 CHECKLIST: 15 tablas, 1 funcion y 1 vista procesadas.'
GO
