USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  19-08-2026
-- DESCRIPTION:     REGISTRO DE MAESTROS DESDE TERRENO Y FUSION DE DUPLICADOS.
-- =============================================
-- Ver SIGMA_ANEXO_C_DESCUBRIMIENTO_TERRENO.md
--
-- DEPENDENCIAS
--   Requiere: Cliente, Cliente_Instalacion, Usuario, Registro_Origen (04_CATALOGOS)
--   Requiere: Activo, Activo_Componente, Activo_Medidor, Activo_Atributo,
--             Activo_Variable, Repuesto        (bloques 2 a 4)
--   Las FK de Registro_Descubrimiento hacia Orden_Trabajo, Tarea_Ocurrencia,
--   Checklist_Ejecucion y Bitacora se agregan al final (seccion 6), porque esas
--   tablas se crean en bloques posteriores. Ese bloque es idempotente y se puede
--   re-ejecutar cuando existan.
-- =============================================


/* ========================================================================
   1. REGISTRO_DESCUBRIMIENTO
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Registro_Descubrimiento]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Registro_Descubrimiento]
    (
        [rde_id]                    INT                 NOT NULL IDENTITY(1,1),
        [rde_uuid]                  UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_RDE_UUID DEFAULT NEWID(),
        [rde_cliente]               INT                 NOT NULL,
        [rde_cliente_instalacion]   INT                 NOT NULL,
        [rde_usuario]               INT                 NOT NULL,
        [rde_fecha_utc]             DATETIME            NOT NULL,
        [rde_registro_origen]       INT                 NOT NULL,
        [rde_orden_trabajo]         INT                 NULL,
        [rde_tarea_ocurrencia]      INT                 NULL,
        [rde_checklist_ejecucion]   INT                 NULL,
        [rde_bitacora]              INT                 NULL,
        [rde_dispositivo_uuid]      UNIQUEIDENTIFIER    NULL,
        [rde_latitud]               DECIMAL(10,7)       NULL,
        [rde_longitud]              DECIMAL(10,7)       NULL,
        [rde_observacion]           NVARCHAR(500)       NULL,
        [rde_usuario_revision]      INT                 NULL,
        [rde_fecha_revision]        DATETIME            NULL,
        [rde_usuario_creacion]      INT                 NOT NULL,
        [rde_fecha_creacion]        DATETIME            NOT NULL CONSTRAINT DF_RDE_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_REGISTRO_DESCUBRIMIENTO PRIMARY KEY CLUSTERED ([rde_id] ASC),
        CONSTRAINT FK_RDE_CLIENTE FOREIGN KEY ([rde_cliente])
            REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_RDE_CLIENTE_INSTALACION FOREIGN KEY ([rde_cliente_instalacion])
            REFERENCES [dbo].[Cliente_Instalacion] ([cin_id]),
        CONSTRAINT FK_RDE_USUARIO FOREIGN KEY ([rde_usuario])
            REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_RDE_USUARIO_REVISION FOREIGN KEY ([rde_usuario_revision])
            REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_RDE_REGISTRO_ORIGEN FOREIGN KEY ([rde_registro_origen])
            REFERENCES [dbo].[Registro_Origen] ([ror_id])
    )

    CREATE UNIQUE NONCLUSTERED INDEX UX_RDE_UUID
        ON [dbo].[Registro_Descubrimiento] ([rde_uuid])

    -- Bandeja del planificador: lo no revisado de sus plantas, lo mas reciente primero.
    CREATE NONCLUSTERED INDEX IX_RDE_CLIENTE_REVISION
        ON [dbo].[Registro_Descubrimiento] ([rde_cliente], [rde_cliente_instalacion], [rde_fecha_utc] DESC)
        INCLUDE ([rde_usuario], [rde_orden_trabajo], [rde_observacion])
        WHERE [rde_fecha_revision] IS NULL

    CREATE NONCLUSTERED INDEX IX_RDE_ORDEN_TRABAJO
        ON [dbo].[Registro_Descubrimiento] ([rde_orden_trabajo])

    PRINT 'Tabla Registro_Descubrimiento creada correctamente.'
END
ELSE
    PRINT 'Tabla Registro_Descubrimiento ya existe.'
GO


/* ========================================================================
   2. BLOQUE DE DESCUBRIMIENTO EN LOS SEIS MAESTROS
      Dos columnas por tabla. NULL = nacio en carga inicial o desde la web.
   ======================================================================== */

-- Activo -----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Activo]') AND name = 'act_registro_descubrimiento')
BEGIN
    ALTER TABLE [dbo].[Activo] ADD [act_registro_descubrimiento] INT NULL
    PRINT 'Columna act_registro_descubrimiento agregada a Activo.'
END
ELSE
    PRINT 'Columna act_registro_descubrimiento ya existe en Activo.'
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ACT_REGISTRO_DESCUBRIMIENTO')
    ALTER TABLE [dbo].[Activo] WITH CHECK ADD CONSTRAINT [FK_ACT_REGISTRO_DESCUBRIMIENTO]
        FOREIGN KEY ([act_registro_descubrimiento]) REFERENCES [dbo].[Registro_Descubrimiento] ([rde_id])
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ACT_REGISTRO_DESCUBRIMIENTO')
    CREATE NONCLUSTERED INDEX IX_ACT_REGISTRO_DESCUBRIMIENTO
        ON [dbo].[Activo] ([act_registro_descubrimiento]) WHERE [act_registro_descubrimiento] IS NOT NULL
GO

-- Activo_Componente ------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Componente]') AND name = 'aco_registro_descubrimiento')
BEGIN
    ALTER TABLE [dbo].[Activo_Componente] ADD [aco_registro_descubrimiento] INT NULL
    PRINT 'Columna aco_registro_descubrimiento agregada a Activo_Componente.'
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ACO_REGISTRO_DESCUBRIMIENTO')
    ALTER TABLE [dbo].[Activo_Componente] WITH CHECK ADD CONSTRAINT [FK_ACO_REGISTRO_DESCUBRIMIENTO]
        FOREIGN KEY ([aco_registro_descubrimiento]) REFERENCES [dbo].[Registro_Descubrimiento] ([rde_id])
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ACO_REGISTRO_DESCUBRIMIENTO')
    CREATE NONCLUSTERED INDEX IX_ACO_REGISTRO_DESCUBRIMIENTO
        ON [dbo].[Activo_Componente] ([aco_registro_descubrimiento]) WHERE [aco_registro_descubrimiento] IS NOT NULL
GO

-- Activo_Medidor / Activo_Atributo / Activo_Variable / Repuesto ----------
-- (mismo bloque, un IF NOT EXISTS por columna; ver patron arriba)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Medidor]') AND name = 'ame_registro_descubrimiento')
    ALTER TABLE [dbo].[Activo_Medidor] ADD [ame_registro_descubrimiento] INT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Atributo]') AND name = 'aat_registro_descubrimiento')
    ALTER TABLE [dbo].[Activo_Atributo] ADD [aat_registro_descubrimiento] INT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Variable]') AND name = 'ava_registro_descubrimiento')
    ALTER TABLE [dbo].[Activo_Variable] ADD [ava_registro_descubrimiento] INT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Repuesto]') AND name = 'rep_registro_descubrimiento')
    ALTER TABLE [dbo].[Repuesto] ADD [rep_registro_descubrimiento] INT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_AME_REGISTRO_DESCUBRIMIENTO')
    ALTER TABLE [dbo].[Activo_Medidor] WITH CHECK ADD CONSTRAINT [FK_AME_REGISTRO_DESCUBRIMIENTO]
        FOREIGN KEY ([ame_registro_descubrimiento]) REFERENCES [dbo].[Registro_Descubrimiento] ([rde_id])
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_AAT_REGISTRO_DESCUBRIMIENTO')
    ALTER TABLE [dbo].[Activo_Atributo] WITH CHECK ADD CONSTRAINT [FK_AAT_REGISTRO_DESCUBRIMIENTO]
        FOREIGN KEY ([aat_registro_descubrimiento]) REFERENCES [dbo].[Registro_Descubrimiento] ([rde_id])
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_AVA_REGISTRO_DESCUBRIMIENTO')
    ALTER TABLE [dbo].[Activo_Variable] WITH CHECK ADD CONSTRAINT [FK_AVA_REGISTRO_DESCUBRIMIENTO]
        FOREIGN KEY ([ava_registro_descubrimiento]) REFERENCES [dbo].[Registro_Descubrimiento] ([rde_id])
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_REP_REGISTRO_DESCUBRIMIENTO')
    ALTER TABLE [dbo].[Repuesto] WITH CHECK ADD CONSTRAINT [FK_REP_REGISTRO_DESCUBRIMIENTO]
        FOREIGN KEY ([rep_registro_descubrimiento]) REFERENCES [dbo].[Registro_Descubrimiento] ([rde_id])
GO


/* ========================================================================
   3. POSICION DEL COMPONENTE COMO CATALOGO
      Reemplaza a aco_posicion NVARCHAR(100). Junto con aco_componente_tipo
      arma el nombre y evita el duplicado en el origen (Anexo C seccion 4).
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Componente]') AND name = 'aco_componente_posicion')
BEGIN
    ALTER TABLE [dbo].[Activo_Componente] ADD [aco_componente_posicion] INT NULL
    PRINT 'Columna aco_componente_posicion agregada a Activo_Componente.'
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ACO_COMPONENTE_POSICION')
    ALTER TABLE [dbo].[Activo_Componente] WITH CHECK ADD CONSTRAINT [FK_ACO_COMPONENTE_POSICION]
        FOREIGN KEY ([aco_componente_posicion]) REFERENCES [dbo].[Componente_Posicion] ([cpn_id])
GO
-- Un solo componente por (activo, tipo, posicion) mientras este habilitado.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_ACO_ACTIVO_TIPO_POSICION')
    CREATE UNIQUE NONCLUSTERED INDEX UX_ACO_ACTIVO_TIPO_POSICION
        ON [dbo].[Activo_Componente] ([aco_activo], [aco_componente_tipo], [aco_componente_posicion])
        WHERE [aco_habilitado] = 1 AND [aco_componente_posicion] IS NOT NULL
GO


/* ========================================================================
   4. FUSION DE DUPLICADOS
      La fila absorbida NO se borra: conserva su historial y queda apuntando
      al superviviente. Operacion reversible y auditable.
   ======================================================================== */

-- 4.1 Puntero al superviviente en cada maestro fusionable
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Activo]') AND name = 'act_fusionado_en')
    ALTER TABLE [dbo].[Activo] ADD [act_fusionado_en] INT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Componente]') AND name = 'aco_fusionado_en')
    ALTER TABLE [dbo].[Activo_Componente] ADD [aco_fusionado_en] INT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Repuesto]') AND name = 'rep_fusionado_en')
    ALTER TABLE [dbo].[Repuesto] ADD [rep_fusionado_en] INT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ACT_FUSIONADO_EN')
    ALTER TABLE [dbo].[Activo] WITH CHECK ADD CONSTRAINT [FK_ACT_FUSIONADO_EN]
        FOREIGN KEY ([act_fusionado_en]) REFERENCES [dbo].[Activo] ([act_id])
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ACO_FUSIONADO_EN')
    ALTER TABLE [dbo].[Activo_Componente] WITH CHECK ADD CONSTRAINT [FK_ACO_FUSIONADO_EN]
        FOREIGN KEY ([aco_fusionado_en]) REFERENCES [dbo].[Activo_Componente] ([aco_id])
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_REP_FUSIONADO_EN')
    ALTER TABLE [dbo].[Repuesto] WITH CHECK ADD CONSTRAINT [FK_REP_FUSIONADO_EN]
        FOREIGN KEY ([rep_fusionado_en]) REFERENCES [dbo].[Repuesto] ([rep_id])
GO

-- 4.2 Bitacora de fusiones (append-only)
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Componente_Fusion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Componente_Fusion]
    (
        [acf_id]                    INT             NOT NULL IDENTITY(1,1),
        [acf_cliente]               INT             NOT NULL,
        [acf_componente_origen]     INT             NOT NULL,
        [acf_componente_destino]    INT             NOT NULL,
        [acf_motivo]                NVARCHAR(500)   NULL,
        [acf_filas_repuntadas]      INT             NULL,
        [acf_fecha_utc]             DATETIME        NOT NULL,
        [acf_usuario_creacion]      INT             NOT NULL,
        [acf_fecha_creacion]        DATETIME        NOT NULL CONSTRAINT DF_ACF_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_ACTIVO_COMPONENTE_FUSION PRIMARY KEY CLUSTERED ([acf_id] ASC),
        CONSTRAINT FK_ACF_CLIENTE FOREIGN KEY ([acf_cliente]) REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_ACF_COMPONENTE_ORIGEN FOREIGN KEY ([acf_componente_origen])
            REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_ACF_COMPONENTE_DESTINO FOREIGN KEY ([acf_componente_destino])
            REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT CK_ACF_DISTINTOS CHECK ([acf_componente_origen] <> [acf_componente_destino])
    )
    CREATE NONCLUSTERED INDEX IX_ACF_DESTINO ON [dbo].[Activo_Componente_Fusion] ([acf_componente_destino])
    PRINT 'Tabla Activo_Componente_Fusion creada correctamente.'
END
ELSE
    PRINT 'Tabla Activo_Componente_Fusion ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Fusion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Fusion]
    (
        [afu_id]                INT             NOT NULL IDENTITY(1,1),
        [afu_cliente]           INT             NOT NULL,
        [afu_activo_origen]     INT             NOT NULL,
        [afu_activo_destino]    INT             NOT NULL,
        [afu_motivo]            NVARCHAR(500)   NULL,
        [afu_filas_repuntadas]  INT             NULL,
        [afu_fecha_utc]         DATETIME        NOT NULL,
        [afu_usuario_creacion]  INT             NOT NULL,
        [afu_fecha_creacion]    DATETIME        NOT NULL CONSTRAINT DF_AFU_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_ACTIVO_FUSION PRIMARY KEY CLUSTERED ([afu_id] ASC),
        CONSTRAINT FK_AFU_CLIENTE FOREIGN KEY ([afu_cliente]) REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_AFU_ACTIVO_ORIGEN  FOREIGN KEY ([afu_activo_origen])  REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_AFU_ACTIVO_DESTINO FOREIGN KEY ([afu_activo_destino]) REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT CK_AFU_DISTINTOS CHECK ([afu_activo_origen] <> [afu_activo_destino])
    )
    PRINT 'Tabla Activo_Fusion creada correctamente.'
END
ELSE
    PRINT 'Tabla Activo_Fusion ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Repuesto_Fusion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Repuesto_Fusion]
    (
        [rfu_id]                INT             NOT NULL IDENTITY(1,1),
        [rfu_cliente]           INT             NOT NULL,
        [rfu_repuesto_origen]   INT             NOT NULL,
        [rfu_repuesto_destino]  INT             NOT NULL,
        [rfu_motivo]            NVARCHAR(500)   NULL,
        [rfu_filas_repuntadas]  INT             NULL,
        [rfu_fecha_utc]         DATETIME        NOT NULL,
        [rfu_usuario_creacion]  INT             NOT NULL,
        [rfu_fecha_creacion]    DATETIME        NOT NULL CONSTRAINT DF_RFU_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_REPUESTO_FUSION PRIMARY KEY CLUSTERED ([rfu_id] ASC),
        CONSTRAINT FK_RFU_CLIENTE FOREIGN KEY ([rfu_cliente]) REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_RFU_REPUESTO_ORIGEN  FOREIGN KEY ([rfu_repuesto_origen])  REFERENCES [dbo].[Repuesto] ([rep_id]),
        CONSTRAINT FK_RFU_REPUESTO_DESTINO FOREIGN KEY ([rfu_repuesto_destino]) REFERENCES [dbo].[Repuesto] ([rep_id]),
        CONSTRAINT CK_RFU_DISTINTOS CHECK ([rfu_repuesto_origen] <> [rfu_repuesto_destino])
    )
    PRINT 'Tabla Repuesto_Fusion creada correctamente.'
END
ELSE
    PRINT 'Tabla Repuesto_Fusion ya existe.'
GO


/* ========================================================================
   5. PERMISOS -> ver 06_PERMISOS_USUARIO.sql
      Los permisos de terreno se otorgan por USUARIO, no por perfil:
      el planificador habilita a tecnicos concretos.
      Ver SIGMA_ANEXO_D_PERMISOS_USUARIO.md
   ======================================================================== */


/* ========================================================================
   6. FK DIFERIDAS
      Se ejecutan cuando existan Orden_Trabajo, Tarea_Ocurrencia,
      Checklist_Ejecucion y Bitacora (bloques 7 a 11). Idempotente.
   ======================================================================== */

IF OBJECT_ID(N'[dbo].[Orden_Trabajo]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_RDE_ORDEN_TRABAJO')
    ALTER TABLE [dbo].[Registro_Descubrimiento] WITH CHECK ADD CONSTRAINT [FK_RDE_ORDEN_TRABAJO]
        FOREIGN KEY ([rde_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO
IF OBJECT_ID(N'[dbo].[Tarea_Ocurrencia]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_RDE_TAREA_OCURRENCIA')
    ALTER TABLE [dbo].[Registro_Descubrimiento] WITH CHECK ADD CONSTRAINT [FK_RDE_TAREA_OCURRENCIA]
        FOREIGN KEY ([rde_tarea_ocurrencia]) REFERENCES [dbo].[Tarea_Ocurrencia] ([toc_id])
GO
IF OBJECT_ID(N'[dbo].[Checklist_Ejecucion]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_RDE_CHECKLIST_EJECUCION')
    ALTER TABLE [dbo].[Registro_Descubrimiento] WITH CHECK ADD CONSTRAINT [FK_RDE_CHECKLIST_EJECUCION]
        FOREIGN KEY ([rde_checklist_ejecucion]) REFERENCES [dbo].[Checklist_Ejecucion] ([cej_id])
GO
IF OBJECT_ID(N'[dbo].[Bitacora]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_RDE_BITACORA')
    ALTER TABLE [dbo].[Registro_Descubrimiento] WITH CHECK ADD CONSTRAINT [FK_RDE_BITACORA]
        FOREIGN KEY ([rde_bitacora]) REFERENCES [dbo].[Bitacora] ([bit_id])
GO


/* ========================================================================
   7. BANDEJA DEL PLANIFICADOR
      Union de los seis maestros. Conserva las FK reales: no hay puntero
      polimorfico entidad/id en ninguna parte.
   ======================================================================== */

CREATE OR ALTER VIEW [dbo].[VW_DESCUBRIMIENTO_PENDIENTE]
AS
SELECT rde.rde_id, rde.rde_cliente, rde.rde_cliente_instalacion,
       CAST('Activo' AS NVARCHAR(50)) AS ENTIDAD, act.act_id AS ENTIDAD_ID,
       act.act_nombre AS ENTIDAD_NOMBRE, act.act_codigo AS ENTIDAD_CODIGO,
       rde.rde_usuario, rde.rde_fecha_utc, rde.rde_orden_trabajo, rde.rde_observacion
FROM   [dbo].[Registro_Descubrimiento] rde
JOIN   [dbo].[Activo] act ON act.act_registro_descubrimiento = rde.rde_id
WHERE  rde.rde_fecha_revision IS NULL
UNION ALL
SELECT rde.rde_id, rde.rde_cliente, rde.rde_cliente_instalacion,
       CAST('Activo_Componente' AS NVARCHAR(50)), aco.aco_id,
       aco.aco_nombre, aco.aco_codigo,
       rde.rde_usuario, rde.rde_fecha_utc, rde.rde_orden_trabajo, rde.rde_observacion
FROM   [dbo].[Registro_Descubrimiento] rde
JOIN   [dbo].[Activo_Componente] aco ON aco.aco_registro_descubrimiento = rde.rde_id
WHERE  rde.rde_fecha_revision IS NULL
UNION ALL
SELECT rde.rde_id, rde.rde_cliente, rde.rde_cliente_instalacion,
       CAST('Activo_Medidor' AS NVARCHAR(50)), ame.ame_id,
       ame.ame_nombre, ame.ame_codigo,
       rde.rde_usuario, rde.rde_fecha_utc, rde.rde_orden_trabajo, rde.rde_observacion
FROM   [dbo].[Registro_Descubrimiento] rde
JOIN   [dbo].[Activo_Medidor] ame ON ame.ame_registro_descubrimiento = rde.rde_id
WHERE  rde.rde_fecha_revision IS NULL
UNION ALL
SELECT rde.rde_id, rde.rde_cliente, rde.rde_cliente_instalacion,
       CAST('Repuesto' AS NVARCHAR(50)), rep.rep_id,
       rep.rep_nombre, rep.rep_codigo,
       rde.rde_usuario, rde.rde_fecha_utc, rde.rde_orden_trabajo, rde.rde_observacion
FROM   [dbo].[Registro_Descubrimiento] rde
JOIN   [dbo].[Repuesto] rep ON rep.rep_registro_descubrimiento = rde.rde_id
WHERE  rde.rde_fecha_revision IS NULL
GO

PRINT 'Bloque de descubrimiento en terreno aplicado correctamente.'
GO
