﻿﻿﻿USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  19-08-2026
-- DESCRIPTION:     D4 -- REPUESTOS, BODEGAS E INVENTARIO.
-- =============================================
-- Ver SIGMA_MODELO_LOGICO_v2.md §8.4
-- ORDEN: despues de 11_ACTIVOS_MEDICIONES.sql
--
-- LA TABLA QUE IMPORTA MAS DE LO QUE PARECE
--   Componente_Repuesto_Instalacion (cri) no es una tabla de inventario:
--   es LA QUE PRODUCE EL LABEL DEL MODELO PREDICTIVO.
--
--   Cada fila cerrada dice: este rodamiento se instalo con el horometro en
--   13.500, se retiro con 20.420, y se retiro POR FALLA. Son 6.920 horas de
--   vida util real y una etiqueta de si fallo o no. Sin esas tres cosas
--   -- lectura inicial, lectura final y motivo -- no hay nada que aprender.
--
--   Por eso cri_motivo es obligatorio cuando hay retiro: no es burocracia,
--   es el dato sin el cual el modelo no se puede entrenar.
--
-- TRES VIDAS UTILES, NO UNA
--   rep_vida_util_hora, _dia y _ciclo son columnas SEPARADAS. Un rodamiento
--   se mide en horas, un filtro en dias, una matriz en ciclos. Una sola
--   columna "vida_util" con una unidad al lado obliga a convertir para
--   comparar, y nadie convierte bien todas las veces.
--
-- IDEMPOTENTE: se puede ejecutar las veces que sea.
-- =============================================


/* ========================================================================
   1. REPUESTO (rep)
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Repuesto]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Repuesto]
    (
        [rep_id]                        INT                 NOT NULL IDENTITY(1,1),
        [rep_uuid]                      UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_REP_UUID DEFAULT NEWID(),
        [rep_cliente]                   INT                 NOT NULL,
        [rep_unidad_medida]             INT                 NOT NULL,
        [rep_codigo]                    NVARCHAR(50)        NOT NULL,
        [rep_nombre]                    NVARCHAR(200)       NOT NULL,
        [rep_fabricante]                NVARCHAR(200)       NULL,
        [rep_modelo]                    NVARCHAR(200)       NULL,
        -- Tres dimensiones separadas. Ver la nota de la cabecera.
        [rep_vida_util_hora]            DECIMAL(18,2)       NULL,
        [rep_vida_util_dia]             INT                 NULL,
        [rep_vida_util_ciclo]           DECIMAL(18,2)       NULL,
        [rep_es_reparable]              BIT                 NOT NULL CONSTRAINT DF_REP_REPARABLE DEFAULT 0,
        [rep_es_consumible]             BIT                 NOT NULL CONSTRAINT DF_REP_CONSUMIBLE DEFAULT 0,
        [rep_costo_referencia]          DECIMAL(18,2)       NULL,
        [rep_moneda]                    INT                 NULL,
        [rep_descripcion]               NVARCHAR(500)       NULL,
        [rep_registro_origen]           INT                 NULL,
        [rep_usuario_creacion]          INT                 NOT NULL,
        [rep_fecha_creacion]            DATETIME            NOT NULL CONSTRAINT DF_REP_FECHA_CREACION DEFAULT GETDATE(),
        [rep_usuario_actualizacion]     INT                 NULL,
        [rep_fecha_actualizacion]       DATETIME            NULL,
        [rep_habilitado]                BIT                 NOT NULL CONSTRAINT DF_REP_HABILITADO DEFAULT 1,

        CONSTRAINT PK_REPUESTO PRIMARY KEY CLUSTERED ([rep_id] ASC),
        CONSTRAINT FK_REP_CLIENTE FOREIGN KEY ([rep_cliente])         REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_REP_UNIDAD  FOREIGN KEY ([rep_unidad_medida])   REFERENCES [dbo].[Unidad_Medida] ([ume_id]),
        CONSTRAINT FK_REP_MONEDA  FOREIGN KEY ([rep_moneda])          REFERENCES [dbo].[Moneda] ([mon_id]),
        CONSTRAINT FK_REP_ORIGEN  FOREIGN KEY ([rep_registro_origen]) REFERENCES [dbo].[Registro_Origen] ([ror_id]),
        CONSTRAINT UX_REP_CLIENTE_ID UNIQUE ([rep_cliente], [rep_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_REP_UUID           ON [dbo].[Repuesto] ([rep_uuid])
    CREATE UNIQUE NONCLUSTERED INDEX UX_REP_CLIENTE_CODIGO ON [dbo].[Repuesto] ([rep_cliente], [rep_codigo])
    PRINT 'Tabla Repuesto creada correctamente.'
END
ELSE PRINT 'Tabla Repuesto ya existe.'
GO


/* ========================================================================
   2. REPUESTO_COMPATIBILIDAD (rco)

      "Rodamientos: 6312-C3 / 6212-C3" de la ficha del blower. La
      compatibilidad se declara a nivel de tipo de maquina, de modelo o de
      componente concreto -- por eso las tres FK son anulables y un CHECK
      exige que al menos una este informada. Sin ese CHECK se podrian
      cargar filas que no compatibilizan con nada.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Repuesto_Compatibilidad]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Repuesto_Compatibilidad]
    (
        [rco_id]                    INT             NOT NULL IDENTITY(1,1),
        [rco_repuesto]              INT             NOT NULL,
        [rco_activo_tipo]           INT             NULL,
        [rco_activo_modelo]         INT             NULL,
        [rco_activo_componente]     INT             NULL,
        [rco_observacion]           NVARCHAR(500)   NULL,
        [rco_usuario_creacion]      INT             NOT NULL,
        [rco_fecha_creacion]        DATETIME        NOT NULL CONSTRAINT DF_RCO_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_REPUESTO_COMPATIBILIDAD PRIMARY KEY CLUSTERED ([rco_id] ASC),
        CONSTRAINT FK_RCO_REPUESTO   FOREIGN KEY ([rco_repuesto])          REFERENCES [dbo].[Repuesto] ([rep_id]),
        CONSTRAINT FK_RCO_TIPO       FOREIGN KEY ([rco_activo_tipo])       REFERENCES [dbo].[Activo_Tipo] ([ati_id]),
        CONSTRAINT FK_RCO_MODELO     FOREIGN KEY ([rco_activo_modelo])     REFERENCES [dbo].[Activo_Modelo] ([amo_id]),
        CONSTRAINT FK_RCO_COMPONENTE FOREIGN KEY ([rco_activo_componente]) REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT CK_RCO_ALCANCE CHECK ([rco_activo_tipo] IS NOT NULL
                                      OR [rco_activo_modelo] IS NOT NULL
                                      OR [rco_activo_componente] IS NOT NULL)
    )
    CREATE NONCLUSTERED INDEX IX_RCO_REPUESTO ON [dbo].[Repuesto_Compatibilidad] ([rco_repuesto])
    PRINT 'Tabla Repuesto_Compatibilidad creada correctamente.'
END
ELSE PRINT 'Tabla Repuesto_Compatibilidad ya existe.'
GO


/* ========================================================================
   3. BODEGA (bod) y BODEGA_UBICACION (bub)
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Bodega]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Bodega]
    (
        [bod_id]                        INT             NOT NULL IDENTITY(1,1),
        [bod_cliente]                   INT             NOT NULL,
        [bod_cliente_instalacion]       INT             NOT NULL,
        [bod_codigo]                    NVARCHAR(50)    NOT NULL,
        [bod_nombre]                    NVARCHAR(200)   NOT NULL,
        [bod_descripcion]               NVARCHAR(500)   NULL,
        [bod_usuario_creacion]          INT             NOT NULL,
        [bod_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_BOD_FECHA_CREACION DEFAULT GETDATE(),
        [bod_usuario_actualizacion]     INT             NULL,
        [bod_fecha_actualizacion]       DATETIME        NULL,
        [bod_habilitado]                BIT             NOT NULL CONSTRAINT DF_BOD_HABILITADO DEFAULT 1,

        CONSTRAINT PK_BODEGA PRIMARY KEY CLUSTERED ([bod_id] ASC),
        CONSTRAINT FK_BOD_CLIENTE     FOREIGN KEY ([bod_cliente])             REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_BOD_INSTALACION FOREIGN KEY ([bod_cliente_instalacion]) REFERENCES [dbo].[Cliente_Instalacion] ([cin_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_BOD_CLIENTE_CODIGO ON [dbo].[Bodega] ([bod_cliente], [bod_codigo])
    PRINT 'Tabla Bodega creada correctamente.'
END
ELSE PRINT 'Tabla Bodega ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Bodega_Ubicacion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Bodega_Ubicacion]
    (
        [bub_id]                        INT             NOT NULL IDENTITY(1,1),
        [bub_bodega]                    INT             NOT NULL,
        [bub_codigo]                    NVARCHAR(50)    NOT NULL,   -- pasillo A, estante 3
        [bub_nombre]                    NVARCHAR(200)   NOT NULL,
        [bub_usuario_creacion]          INT             NOT NULL,
        [bub_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_BUB_FECHA_CREACION DEFAULT GETDATE(),
        [bub_usuario_actualizacion]     INT             NULL,
        [bub_fecha_actualizacion]       DATETIME        NULL,
        [bub_habilitado]                BIT             NOT NULL CONSTRAINT DF_BUB_HABILITADO DEFAULT 1,

        CONSTRAINT PK_BODEGA_UBICACION PRIMARY KEY CLUSTERED ([bub_id] ASC),
        CONSTRAINT FK_BUB_BODEGA FOREIGN KEY ([bub_bodega]) REFERENCES [dbo].[Bodega] ([bod_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_BUB_BODEGA_CODIGO ON [dbo].[Bodega_Ubicacion] ([bub_bodega], [bub_codigo])
    PRINT 'Tabla Bodega_Ubicacion creada correctamente.'
END
ELSE PRINT 'Tabla Bodega_Ubicacion ya existe.'
GO


/* ========================================================================
   4. REPUESTO_LOTE (rlo) -- trazabilidad de lote o serie
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Repuesto_Lote]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Repuesto_Lote]
    (
        [rlo_id]                        INT             NOT NULL IDENTITY(1,1),
        [rlo_cliente]                   INT             NOT NULL,
        [rlo_repuesto]                  INT             NOT NULL,
        [rlo_codigo]                    NVARCHAR(100)   NOT NULL,   -- numero de lote o de serie
        [rlo_fecha_ingreso]             DATE            NULL,
        [rlo_fecha_vencimiento]         DATE            NULL,
        [rlo_proveedor]                 INT             NULL,       -- FK diferida (19)
        [rlo_costo_unitario]            DECIMAL(18,2)   NULL,
        [rlo_moneda]                    INT             NULL,
        [rlo_observacion]               NVARCHAR(500)   NULL,
        [rlo_usuario_creacion]          INT             NOT NULL,
        [rlo_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_RLO_FECHA_CREACION DEFAULT GETDATE(),
        [rlo_usuario_actualizacion]     INT             NULL,
        [rlo_fecha_actualizacion]       DATETIME        NULL,
        [rlo_habilitado]                BIT             NOT NULL CONSTRAINT DF_RLO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_REPUESTO_LOTE PRIMARY KEY CLUSTERED ([rlo_id] ASC),
        CONSTRAINT FK_RLO_CLIENTE  FOREIGN KEY ([rlo_cliente])  REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_RLO_REPUESTO FOREIGN KEY ([rlo_repuesto]) REFERENCES [dbo].[Repuesto] ([rep_id]),
        CONSTRAINT FK_RLO_MONEDA   FOREIGN KEY ([rlo_moneda])   REFERENCES [dbo].[Moneda] ([mon_id])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_RLO_REPUESTO_CODIGO ON [dbo].[Repuesto_Lote] ([rlo_repuesto], [rlo_codigo])
    PRINT 'Tabla Repuesto_Lote creada correctamente.'
END
ELSE PRINT 'Tabla Repuesto_Lote ya existe.'
GO


/* ========================================================================
   5. INVENTARIO_MOVIMIENTO (imo) -- append-only

      El saldo NO se edita: se mueve. Cada entrada, salida y ajuste es una
      fila, y el saldo es su consecuencia. Permitir editar el saldo
      directamente convierte un descuadre en algo indetectable.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Inventario_Movimiento]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Inventario_Movimiento]
    (
        [imo_id]                        INT                 NOT NULL IDENTITY(1,1),
        [imo_uuid]                      UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_IMO_UUID DEFAULT NEWID(),
        [imo_cliente]                   INT                 NOT NULL,
        [imo_repuesto]                  INT                 NOT NULL,
        [imo_bodega]                    INT                 NOT NULL,
        [imo_bodega_ubicacion]          INT                 NULL,
        [imo_repuesto_lote]             INT                 NULL,
        [imo_inventario_movimiento_tipo] INT                NOT NULL,
        [imo_cantidad]                  DECIMAL(18,2)       NOT NULL,   -- siempre positiva; el signo lo da el tipo
        [imo_costo_unitario]            DECIMAL(18,2)       NULL,
        [imo_moneda]                    INT                 NULL,
        [imo_fecha_movimiento_utc]      DATETIME            NOT NULL,
        [imo_orden_trabajo]             INT                 NULL,       -- FK diferida (17)
        [imo_bodega_destino]            INT                 NULL,       -- para traslados
        [imo_observacion]               NVARCHAR(500)       NULL,
        [imo_usuario_creacion]          INT                 NOT NULL,
        [imo_fecha_creacion]            DATETIME            NOT NULL CONSTRAINT DF_IMO_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_INVENTARIO_MOVIMIENTO PRIMARY KEY CLUSTERED ([imo_id] ASC),
        CONSTRAINT FK_IMO_CLIENTE   FOREIGN KEY ([imo_cliente])                   REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_IMO_REPUESTO  FOREIGN KEY ([imo_repuesto])                  REFERENCES [dbo].[Repuesto] ([rep_id]),
        CONSTRAINT FK_IMO_BODEGA    FOREIGN KEY ([imo_bodega])                    REFERENCES [dbo].[Bodega] ([bod_id]),
        CONSTRAINT FK_IMO_UBICACION FOREIGN KEY ([imo_bodega_ubicacion])          REFERENCES [dbo].[Bodega_Ubicacion] ([bub_id]),
        CONSTRAINT FK_IMO_LOTE      FOREIGN KEY ([imo_repuesto_lote])             REFERENCES [dbo].[Repuesto_Lote] ([rlo_id]),
        CONSTRAINT FK_IMO_TIPO      FOREIGN KEY ([imo_inventario_movimiento_tipo]) REFERENCES [dbo].[Inventario_Movimiento_Tipo] ([imt_id]),
        CONSTRAINT FK_IMO_MONEDA    FOREIGN KEY ([imo_moneda])                    REFERENCES [dbo].[Moneda] ([mon_id]),
        CONSTRAINT FK_IMO_DESTINO   FOREIGN KEY ([imo_bodega_destino])            REFERENCES [dbo].[Bodega] ([bod_id]),
        CONSTRAINT CK_IMO_CANTIDAD  CHECK ([imo_cantidad] > 0)
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_IMO_UUID ON [dbo].[Inventario_Movimiento] ([imo_uuid])
    CREATE NONCLUSTERED INDEX IX_IMO_REPUESTO_BODEGA
        ON [dbo].[Inventario_Movimiento] ([imo_repuesto], [imo_bodega], [imo_fecha_movimiento_utc] DESC)
    PRINT 'Tabla Inventario_Movimiento creada correctamente.'
END
ELSE PRINT 'Tabla Inventario_Movimiento ya existe.'
GO


/* ========================================================================
   6. INVENTARIO_SALDO (isa) -- denormalizacion controlada

      El saldo se puede calcular sumando los movimientos. Se guarda igual
      porque la app consulta "hay stock?" en cada linea de repuesto de cada
      OT, y sumar el historico completo en cada consulta no escala.
      La verdad sigue estando en los movimientos: el SP actualiza ambos en
      la misma transaccion, igual que ame_valor_actual.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Inventario_Saldo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Inventario_Saldo]
    (
        [isa_id]                        INT             NOT NULL IDENTITY(1,1),
        [isa_cliente]                   INT             NOT NULL,
        [isa_repuesto]                  INT             NOT NULL,
        [isa_bodega]                    INT             NOT NULL,
        [isa_cantidad]                  DECIMAL(18,2)   NOT NULL CONSTRAINT DF_ISA_CANTIDAD DEFAULT 0,
        [isa_cantidad_reservada]        DECIMAL(18,2)   NOT NULL CONSTRAINT DF_ISA_RESERVADA DEFAULT 0,
        [isa_costo_promedio]            DECIMAL(18,2)   NULL,
        [isa_fecha_ultimo_movimiento]   DATETIME        NULL,
        [isa_usuario_actualizacion]     INT             NULL,
        [isa_fecha_actualizacion]       DATETIME        NULL,

        CONSTRAINT PK_INVENTARIO_SALDO PRIMARY KEY CLUSTERED ([isa_id] ASC),
        CONSTRAINT FK_ISA_CLIENTE  FOREIGN KEY ([isa_cliente])  REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_ISA_REPUESTO FOREIGN KEY ([isa_repuesto]) REFERENCES [dbo].[Repuesto] ([rep_id]),
        CONSTRAINT FK_ISA_BODEGA   FOREIGN KEY ([isa_bodega])   REFERENCES [dbo].[Bodega] ([bod_id]),
        CONSTRAINT CK_ISA_CANTIDAD CHECK ([isa_cantidad] >= 0 AND [isa_cantidad_reservada] >= 0)
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_ISA_REPUESTO_BODEGA ON [dbo].[Inventario_Saldo] ([isa_repuesto], [isa_bodega])
    PRINT 'Tabla Inventario_Saldo creada correctamente.'
END
ELSE PRINT 'Tabla Inventario_Saldo ya existe.'
GO


/* ========================================================================
   7. COMPONENTE_REPUESTO_INSTALACION (cri)
      LA TABLA QUE PRODUCE EL LABEL DEL PREDICTIVO. Ver la cabecera.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Componente_Repuesto_Instalacion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Componente_Repuesto_Instalacion]
    (
        [cri_id]                        INT             NOT NULL IDENTITY(1,1),
        [cri_cliente]                   INT             NOT NULL,
        [cri_activo_componente]         INT             NOT NULL,
        [cri_repuesto]                  INT             NOT NULL,
        [cri_repuesto_lote]             INT             NULL,
        [cri_activo_medidor]            INT             NULL,       -- contra que medidor se leyo
        [cri_cantidad]                  DECIMAL(18,2)   NOT NULL CONSTRAINT DF_CRI_CANTIDAD DEFAULT 1,
        [cri_fecha_instalacion_utc]     DATETIME        NOT NULL,
        [cri_lectura_inicial]           DECIMAL(18,2)   NULL,       -- horometro al instalar: 13.500
        [cri_fecha_retiro_utc]          DATETIME        NULL,       -- NULL = instalado
        [cri_lectura_final]             DECIMAL(18,2)   NULL,       -- horometro al retirar: 20.420
        [cri_repuesto_retiro_motivo]    INT             NULL,
        [cri_repuesto_estado_final]     INT             NULL,
        [cri_fallo]                     BIT             NOT NULL CONSTRAINT DF_CRI_FALLO DEFAULT 0,  -- label de clasificacion
        [cri_usuario_tecnico]           INT             NULL,
        [cri_orden_trabajo_instalacion] INT             NULL,       -- FK diferida (17)
        [cri_orden_trabajo_retiro]      INT             NULL,       -- FK diferida (17)
        [cri_observacion]               NVARCHAR(500)   NULL,
        [cri_usuario_creacion]          INT             NOT NULL,
        [cri_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_CRI_FECHA_CREACION DEFAULT GETDATE(),
        [cri_usuario_actualizacion]     INT             NULL,
        [cri_fecha_actualizacion]       DATETIME        NULL,

        CONSTRAINT PK_COMPONENTE_REPUESTO_INSTALACION PRIMARY KEY CLUSTERED ([cri_id] ASC),
        CONSTRAINT FK_CRI_CLIENTE     FOREIGN KEY ([cri_cliente])                REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_CRI_COMPONENTE  FOREIGN KEY ([cri_activo_componente])      REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_CRI_REPUESTO    FOREIGN KEY ([cri_repuesto])               REFERENCES [dbo].[Repuesto] ([rep_id]),
        CONSTRAINT FK_CRI_LOTE        FOREIGN KEY ([cri_repuesto_lote])          REFERENCES [dbo].[Repuesto_Lote] ([rlo_id]),
        CONSTRAINT FK_CRI_MEDIDOR     FOREIGN KEY ([cri_activo_medidor])         REFERENCES [dbo].[Activo_Medidor] ([ame_id]),
        CONSTRAINT FK_CRI_MOTIVO      FOREIGN KEY ([cri_repuesto_retiro_motivo]) REFERENCES [dbo].[Repuesto_Retiro_Motivo] ([rrm_id]),
        CONSTRAINT FK_CRI_ESTADO_FIN  FOREIGN KEY ([cri_repuesto_estado_final])  REFERENCES [dbo].[Repuesto_Estado_Final] ([ref_id]),
        CONSTRAINT FK_CRI_TECNICO     FOREIGN KEY ([cri_usuario_tecnico])        REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT CK_CRI_RANGO       CHECK ([cri_fecha_retiro_utc] IS NULL OR [cri_fecha_retiro_utc] >= [cri_fecha_instalacion_utc]),
        -- Retirado exige motivo: es el label que aprende el modelo.
        CONSTRAINT CK_CRI_RETIRO      CHECK ([cri_fecha_retiro_utc] IS NULL OR [cri_repuesto_retiro_motivo] IS NOT NULL),
        -- Si hay lectura final tiene que haber inicial, o la resta no significa nada.
        CONSTRAINT CK_CRI_LECTURA     CHECK ([cri_lectura_final] IS NULL OR [cri_lectura_inicial] IS NOT NULL)
    )
    -- Una sola instalacion vigente por componente y repuesto.
    CREATE UNIQUE NONCLUSTERED INDEX UX_CRI_COMPONENTE_VIGENTE
        ON [dbo].[Componente_Repuesto_Instalacion] ([cri_activo_componente], [cri_repuesto])
        WHERE [cri_fecha_retiro_utc] IS NULL
    CREATE NONCLUSTERED INDEX IX_CRI_REPUESTO
        ON [dbo].[Componente_Repuesto_Instalacion] ([cri_repuesto], [cri_fecha_instalacion_utc] DESC)
    -- El indice que alimenta el dataset de vida util.
    CREATE NONCLUSTERED INDEX IX_CRI_CERRADAS
        ON [dbo].[Componente_Repuesto_Instalacion] ([cri_repuesto], [cri_fallo])
        INCLUDE ([cri_lectura_inicial], [cri_lectura_final], [cri_repuesto_retiro_motivo])
        WHERE [cri_fecha_retiro_utc] IS NOT NULL
    PRINT 'Tabla Componente_Repuesto_Instalacion creada correctamente.'
END
ELSE PRINT 'Tabla Componente_Repuesto_Instalacion ya existe.'
GO

PRINT 'Bloque D4 (repuestos, bodegas e inventario) aplicado correctamente.'
GO
