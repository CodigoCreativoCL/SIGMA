﻿﻿﻿USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  19-08-2026
-- DESCRIPTION:     MODELO COMERCIAL: PLANES, SUSCRIPCION, UF Y RENOVACION.
-- =============================================
-- Ver SIGMA_ANEXO_F_MODELO_COMERCIAL.md
--
-- TRES REGLAS QUE NO SE ROMPEN
--   1. El precio se versiona. Nunca se hace UPDATE de un precio vigente:
--      se cierra la fila y se inserta otra. Lo facturado no cambia.
--   2. El valor de la UF usado se CONGELA en el periodo. Nunca una FK a
--      Valor_Uf: leer un cobro de hace dos años debe mostrar lo que se cobro.
--   3. VENCIDA no es un estado guardado: se calcula. Un estado que cambia
--      solo porque paso el tiempo no puede depender de que un job corra.
--
-- DEPENDENCIAS
--   Requiere: Cliente, Usuario, Archivo, Sys_Parametros
--   Requiere catalogos (04): Funcionalidad, Funcionalidad_Tipo,
--            Periodicidad_Cobro, Suscripcion_Estado, Suscripcion_Periodo_Estado,
--            Suscripcion_Pago_Estado, Uf_Origen
-- =============================================


/* ========================================================================
   1. VALOR_UF
      Una fila por dia. La alimenta un JOB DEL SERVIDOR, nunca el navegador:
      si el monto dependiera de un valor enviado por el front, quien paga
      podria alterarlo.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Valor_Uf]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Valor_Uf]
    (
        [vuf_id]                    INT             NOT NULL IDENTITY(1,1),
        [vuf_fecha]                 DATE            NOT NULL,
        [vuf_valor]                 DECIMAL(18,4)   NOT NULL,
        [vuf_uf_origen]             INT             NOT NULL,
        [vuf_fecha_obtencion_utc]   DATETIME        NOT NULL,
        [vuf_respuesta_cruda]       NVARCHAR(500)   NULL,
        [vuf_usuario_creacion]      INT             NOT NULL,
        [vuf_fecha_creacion]        DATETIME        NOT NULL CONSTRAINT DF_VUF_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_VALOR_UF PRIMARY KEY CLUSTERED ([vuf_id] ASC),
        CONSTRAINT FK_VUF_UF_ORIGEN FOREIGN KEY ([vuf_uf_origen]) REFERENCES [dbo].[Uf_Origen] ([ufo_id]),
        CONSTRAINT CK_VUF_VALOR CHECK ([vuf_valor] > 0)
    )

    CREATE UNIQUE NONCLUSTERED INDEX UX_VUF_FECHA ON [dbo].[Valor_Uf] ([vuf_fecha])

    PRINT 'Tabla Valor_Uf creada correctamente.'
END
ELSE
    PRINT 'Tabla Valor_Uf ya existe.'
GO

-- Devuelve la UF de una fecha; si no existe, la ultima conocida (arrastre).
-- Nunca devuelve NULL por caida de la fuente: eso bloquearia una renovacion.
CREATE OR ALTER FUNCTION [dbo].[FNC_VALOR_UF] (@FECHA DATE)
RETURNS DECIMAL(18,4)
AS
BEGIN
    DECLARE @V DECIMAL(18,4)
    SELECT TOP 1 @V = vuf_valor FROM [dbo].[Valor_Uf]
     WHERE vuf_fecha <= @FECHA ORDER BY vuf_fecha DESC
    RETURN @V
END
GO


/* ========================================================================
   2. PLAN_COMERCIAL
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Plan_Comercial]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Plan_Comercial]
    (
        [plc_id]                        INT             NOT NULL IDENTITY(1,1),
        [plc_codigo]                    NVARCHAR(50)    NOT NULL,
        [plc_nombre]                    NVARCHAR(100)   NOT NULL,
        [plc_descripcion]               NVARCHAR(500)   NULL,
        -- El orden decide que es upgrade y que es downgrade.
        [plc_orden]                     INT             NOT NULL,
        [plc_dias_gracia]               INT             NOT NULL CONSTRAINT DF_PLC_DIAS_GRACIA DEFAULT 5,
        [plc_publico]                   BIT             NOT NULL CONSTRAINT DF_PLC_PUBLICO DEFAULT 1,
        [plc_usuario_creacion]          INT             NOT NULL,
        [plc_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PLC_FECHA_CREACION DEFAULT GETDATE(),
        [plc_usuario_actualizacion]     INT             NULL,
        [plc_fecha_actualizacion]       DATETIME        NULL,
        [plc_habilitado]                BIT             NOT NULL CONSTRAINT DF_PLC_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PLAN_COMERCIAL PRIMARY KEY CLUSTERED ([plc_id] ASC),
        CONSTRAINT UX_PLC_CODIGO UNIQUE ([plc_codigo])
    )
    PRINT 'Tabla Plan_Comercial creada correctamente.'
END
ELSE
    PRINT 'Tabla Plan_Comercial ya existe.'
GO


/* ========================================================================
   3. PLAN_COMERCIAL_PRECIO
      Versionado por vigencia. Si no hay fila para (plan, periodicidad),
      esa combinacion NO SE VENDE: la ausencia de precio es la regla.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Plan_Comercial_Precio]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Plan_Comercial_Precio]
    (
        [pcp_id]                        INT             NOT NULL IDENTITY(1,1),
        [pcp_plan_comercial]            INT             NOT NULL,
        [pcp_periodicidad_cobro]        INT             NOT NULL,
        [pcp_valor_uf]                  DECIMAL(18,4)   NOT NULL,
        [pcp_vigencia_desde]            DATE            NOT NULL,
        [pcp_vigencia_hasta]            DATE            NULL,
        [pcp_descuento_porcentaje]      DECIMAL(18,2)   NULL,
        [pcp_usuario_creacion]          INT             NOT NULL,
        [pcp_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PCP_FECHA_CREACION DEFAULT GETDATE(),
        [pcp_usuario_actualizacion]     INT             NULL,
        [pcp_fecha_actualizacion]       DATETIME        NULL,
        [pcp_habilitado]                BIT             NOT NULL CONSTRAINT DF_PCP_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PLAN_COMERCIAL_PRECIO PRIMARY KEY CLUSTERED ([pcp_id] ASC),
        CONSTRAINT FK_PCP_PLAN_COMERCIAL FOREIGN KEY ([pcp_plan_comercial]) REFERENCES [dbo].[Plan_Comercial] ([plc_id]),
        CONSTRAINT FK_PCP_PERIODICIDAD FOREIGN KEY ([pcp_periodicidad_cobro]) REFERENCES [dbo].[Periodicidad_Cobro] ([pcb_id]),
        CONSTRAINT CK_PCP_VALOR CHECK ([pcp_valor_uf] > 0),
        CONSTRAINT CK_PCP_VIGENCIA CHECK ([pcp_vigencia_hasta] IS NULL OR [pcp_vigencia_hasta] >= [pcp_vigencia_desde])
    )

    -- Un solo precio vigente por plan y periodicidad.
    CREATE UNIQUE NONCLUSTERED INDEX UX_PCP_PLAN_PERIODICIDAD_VIGENTE
        ON [dbo].[Plan_Comercial_Precio] ([pcp_plan_comercial], [pcp_periodicidad_cobro])
        WHERE [pcp_vigencia_hasta] IS NULL AND [pcp_habilitado] = 1

    PRINT 'Tabla Plan_Comercial_Precio creada correctamente.'
END
ELSE
    PRINT 'Tabla Plan_Comercial_Precio ya existe.'
GO


/* ========================================================================
   4. PLAN_COMERCIAL_FUNCIONALIDAD
      pcf_cliente NULL = regla del plan.
      pcf_cliente con valor = excepcion negociada para ESE cliente.
      Sin esa columna, cada trato especial obliga a crear un plan nuevo.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Plan_Comercial_Funcionalidad]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Plan_Comercial_Funcionalidad]
    (
        [pcf_id]                        INT             NOT NULL IDENTITY(1,1),
        [pcf_plan_comercial]            INT             NOT NULL,
        [pcf_funcionalidad]             INT             NOT NULL,
        [pcf_cliente]                   INT             NULL,
        [pcf_funcionalidad_tipo]        INT             NOT NULL,   -- INCLUSION (se tiene o no) / LIMITE (tiene tope)
        [pcf_incluida]                  BIT             NOT NULL CONSTRAINT DF_PCF_INCLUIDA DEFAULT 1,
        [pcf_limite]                    DECIMAL(18,2)   NULL,       -- NULL = sin tope
        [pcf_vigencia_hasta]            DATE            NULL,       -- para pruebas temporales
        [pcf_observacion]               NVARCHAR(500)   NULL,
        [pcf_usuario_creacion]          INT             NOT NULL,
        [pcf_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PCF_FECHA_CREACION DEFAULT GETDATE(),
        [pcf_usuario_actualizacion]     INT             NULL,
        [pcf_fecha_actualizacion]       DATETIME        NULL,
        [pcf_habilitado]                BIT             NOT NULL CONSTRAINT DF_PCF_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PLAN_COMERCIAL_FUNCIONALIDAD PRIMARY KEY CLUSTERED ([pcf_id] ASC),
        CONSTRAINT FK_PCF_PLAN_COMERCIAL FOREIGN KEY ([pcf_plan_comercial]) REFERENCES [dbo].[Plan_Comercial] ([plc_id]),
        CONSTRAINT FK_PCF_FUNCIONALIDAD FOREIGN KEY ([pcf_funcionalidad]) REFERENCES [dbo].[Funcionalidad] ([fun_id]),
        CONSTRAINT FK_PCF_CLIENTE FOREIGN KEY ([pcf_cliente]) REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_PCF_TIPO    FOREIGN KEY ([pcf_funcionalidad_tipo]) REFERENCES [dbo].[Funcionalidad_Tipo] ([fnt_id]),
        -- Tipo 2 = LIMITE: si dice que tiene tope, el tope tiene que estar.
        CONSTRAINT CK_PCF_LIMITE  CHECK ([pcf_funcionalidad_tipo] <> 2 OR [pcf_limite] IS NOT NULL)
    )

    CREATE UNIQUE NONCLUSTERED INDEX UX_PCF_PLAN_FUNCIONALIDAD_CLIENTE
        ON [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_cliente])

    PRINT 'Tabla Plan_Comercial_Funcionalidad creada correctamente.'
END
ELSE
    PRINT 'Tabla Plan_Comercial_Funcionalidad ya existe.'
GO


/* ========================================================================
   5. SUSCRIPCION
      Una por cliente, para siempre. La KEY se guarda con hash, como una
      contraseña: da acceso a todos los datos del cliente y una tabla con
      claves en texto plano es una filtracion esperando ocurrir.
      Renovar NO cambia la clave. Solo la cambia una revocacion explicita.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Suscripcion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Suscripcion]
    (
        [sus_id]                        INT             NOT NULL IDENTITY(1,1),
        [sus_cliente]                   INT             NOT NULL,
        [sus_key_prefijo]               NVARCHAR(20)    NOT NULL,   -- SIGMA-K7M2Q, para soporte
        [sus_key_hash]                  VARBINARY(32)   NOT NULL,   -- SHA-256 de la clave completa
        [sus_suscripcion_estado]        INT             NOT NULL,
        [sus_plan_comercial]            INT             NULL,       -- plan vigente, denormalizado
        [sus_fecha_inicio]              DATE            NOT NULL,
        [sus_fecha_fin]                 DATE            NULL,       -- avanza con cada renovacion
        [sus_dias_gracia]               INT             NOT NULL CONSTRAINT DF_SUS_DIAS_GRACIA DEFAULT 5,
        [sus_fecha_emision_key_utc]     DATETIME        NOT NULL,
        [sus_contacto_nombre]           NVARCHAR(200)   NULL,
        [sus_contacto_email]            NVARCHAR(200)   NULL,
        [sus_contacto_telefono]         NVARCHAR(50)    NULL,
        [sus_observacion]               NVARCHAR(500)   NULL,
        [sus_usuario_creacion]          INT             NOT NULL,
        [sus_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_SUS_FECHA_CREACION DEFAULT GETDATE(),
        [sus_usuario_actualizacion]     INT             NULL,
        [sus_fecha_actualizacion]       DATETIME        NULL,
        [sus_habilitado]                BIT             NOT NULL CONSTRAINT DF_SUS_HABILITADO DEFAULT 1,

        CONSTRAINT PK_SUSCRIPCION PRIMARY KEY CLUSTERED ([sus_id] ASC),
        CONSTRAINT FK_SUS_CLIENTE FOREIGN KEY ([sus_cliente]) REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_SUS_ESTADO FOREIGN KEY ([sus_suscripcion_estado]) REFERENCES [dbo].[Suscripcion_Estado] ([sue_id]),
        CONSTRAINT FK_SUS_PLAN_COMERCIAL FOREIGN KEY ([sus_plan_comercial]) REFERENCES [dbo].[Plan_Comercial] ([plc_id])
    )

    CREATE UNIQUE NONCLUSTERED INDEX UX_SUS_CLIENTE   ON [dbo].[Suscripcion] ([sus_cliente])
    -- La API busca por hash en cada autenticacion: tiene que ser unico e indexado.
    CREATE UNIQUE NONCLUSTERED INDEX UX_SUS_KEY_HASH  ON [dbo].[Suscripcion] ([sus_key_hash])
    CREATE NONCLUSTERED INDEX IX_SUS_FECHA_FIN        ON [dbo].[Suscripcion] ([sus_fecha_fin])
        INCLUDE ([sus_cliente], [sus_suscripcion_estado], [sus_dias_gracia])

    PRINT 'Tabla Suscripcion creada correctamente.'
END
ELSE
    PRINT 'Tabla Suscripcion ya existe.'
GO


/* ========================================================================
   6. SUSCRIPCION_KEY_HISTORIAL  (append-only)
      La clave no cambia al renovar. Si cambia es por filtracion o perdida,
      y eso es un acto administrativo que tiene que quedar registrado.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Suscripcion_Key_Historial]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Suscripcion_Key_Historial]
    (
        [skh_id]                    INT             NOT NULL IDENTITY(1,1),
        [skh_suscripcion]           INT             NOT NULL,
        [skh_key_prefijo]           NVARCHAR(20)    NOT NULL,
        [skh_key_hash]              VARBINARY(32)   NOT NULL,
        [skh_accion]                NVARCHAR(20)    NOT NULL,   -- EMISION | REVOCACION | REEMISION
        [skh_motivo]                NVARCHAR(500)   NULL,
        [skh_fecha_utc]             DATETIME        NOT NULL,
        [skh_usuario_creacion]      INT             NOT NULL,
        [skh_fecha_creacion]        DATETIME        NOT NULL CONSTRAINT DF_SKH_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_SUSCRIPCION_KEY_HISTORIAL PRIMARY KEY CLUSTERED ([skh_id] ASC),
        CONSTRAINT FK_SKH_SUSCRIPCION FOREIGN KEY ([skh_suscripcion]) REFERENCES [dbo].[Suscripcion] ([sus_id])
    )
    CREATE NONCLUSTERED INDEX IX_SKH_SUSCRIPCION ON [dbo].[Suscripcion_Key_Historial] ([skh_suscripcion], [skh_fecha_utc] DESC)
    PRINT 'Tabla Suscripcion_Key_Historial creada correctamente.'
END
ELSE
    PRINT 'Tabla Suscripcion_Key_Historial ya existe.'
GO


/* ========================================================================
   7. SUSCRIPCION_PERIODO
      Cinco columnas de monto, y cada una responde una pregunta que alguien
      va a hacer: que plan tenia, cuanto costaba en UF, a cuanto estaba la
      UF, de que dia, y cuanto pago. Todo CONGELADO al emitir.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Suscripcion_Periodo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Suscripcion_Periodo]
    (
        [spe_id]                            INT             NOT NULL IDENTITY(1,1),
        [spe_suscripcion]                   INT             NOT NULL,
        [spe_plan_comercial]                INT             NOT NULL,
        [spe_periodicidad_cobro]            INT             NOT NULL,
        [spe_fecha_inicio]                  DATE            NOT NULL,
        [spe_fecha_fin]                     DATE            NOT NULL,
        [spe_valor_uf_plan]                 DECIMAL(18,4)   NOT NULL,   -- precio en UF, congelado
        [spe_valor_uf_dia]                  DECIMAL(18,4)   NOT NULL,   -- UF del dia, congelada
        [spe_fecha_valor_uf]                DATE            NOT NULL,
        [spe_monto_clp]                     DECIMAL(18,2)   NOT NULL,
        [spe_monto_pagado_clp]              DECIMAL(18,2)   NOT NULL CONSTRAINT DF_SPE_PAGADO DEFAULT 0,
        [spe_suscripcion_periodo_estado]    INT             NOT NULL,
        [spe_es_implantacion]               BIT             NOT NULL CONSTRAINT DF_SPE_IMPLANTACION DEFAULT 0,
        [spe_observacion]                   NVARCHAR(500)   NULL,
        [spe_usuario_creacion]              INT             NOT NULL,
        [spe_fecha_creacion]                DATETIME        NOT NULL CONSTRAINT DF_SPE_FECHA_CREACION DEFAULT GETDATE(),
        [spe_usuario_actualizacion]         INT             NULL,
        [spe_fecha_actualizacion]           DATETIME        NULL,
        [spe_habilitado]                    BIT             NOT NULL CONSTRAINT DF_SPE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_SUSCRIPCION_PERIODO PRIMARY KEY CLUSTERED ([spe_id] ASC),
        CONSTRAINT FK_SPE_SUSCRIPCION FOREIGN KEY ([spe_suscripcion]) REFERENCES [dbo].[Suscripcion] ([sus_id]),
        CONSTRAINT FK_SPE_PLAN_COMERCIAL FOREIGN KEY ([spe_plan_comercial]) REFERENCES [dbo].[Plan_Comercial] ([plc_id]),
        CONSTRAINT FK_SPE_PERIODICIDAD FOREIGN KEY ([spe_periodicidad_cobro]) REFERENCES [dbo].[Periodicidad_Cobro] ([pcb_id]),
        CONSTRAINT FK_SPE_ESTADO FOREIGN KEY ([spe_suscripcion_periodo_estado]) REFERENCES [dbo].[Suscripcion_Periodo_Estado] ([spd_id]),
        CONSTRAINT CK_SPE_RANGO CHECK ([spe_fecha_fin] >= [spe_fecha_inicio]),
        CONSTRAINT CK_SPE_MONTO CHECK ([spe_monto_clp] >= 0)
    )
    CREATE NONCLUSTERED INDEX IX_SPE_SUSCRIPCION ON [dbo].[Suscripcion_Periodo] ([spe_suscripcion], [spe_fecha_fin] DESC)
    PRINT 'Tabla Suscripcion_Periodo creada correctamente.'
END
ELSE
    PRINT 'Tabla Suscripcion_Periodo ya existe.'
GO


/* ========================================================================
   8. SUSCRIPCION_PAGO
      Dos columnas de monto: declarado por el cliente y verificado contra la
      cartola. Con una sola, la diferencia se perderia al corregirla, y esa
      diferencia es justamente lo que hay que gestionar.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Suscripcion_Pago]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Suscripcion_Pago]
    (
        [spa_id]                        INT             NOT NULL IDENTITY(1,1),
        [spa_suscripcion_periodo]       INT             NOT NULL,
        [spa_monto_declarado_clp]       DECIMAL(18,2)   NOT NULL,
        [spa_monto_verificado_clp]      DECIMAL(18,2)   NULL,
        [spa_fecha_transferencia]       DATE            NOT NULL,
        [spa_banco]                     NVARCHAR(100)   NULL,
        [spa_numero_operacion]          NVARCHAR(50)    NULL,
        [spa_archivo]                   INT             NOT NULL,   -- el comprobante, en Blob
        [spa_suscripcion_pago_estado]   INT             NOT NULL,
        [spa_usuario_verificador]       INT             NULL,
        [spa_fecha_verificacion_utc]    DATETIME        NULL,
        [spa_motivo_rechazo]            NVARCHAR(500)   NULL,
        [spa_usuario_creacion]          INT             NOT NULL,
        [spa_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_SPA_FECHA_CREACION DEFAULT GETDATE(),
        [spa_usuario_actualizacion]     INT             NULL,
        [spa_fecha_actualizacion]       DATETIME        NULL,
        [spa_habilitado]                BIT             NOT NULL CONSTRAINT DF_SPA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_SUSCRIPCION_PAGO PRIMARY KEY CLUSTERED ([spa_id] ASC),
        CONSTRAINT FK_SPA_PERIODO FOREIGN KEY ([spa_suscripcion_periodo]) REFERENCES [dbo].[Suscripcion_Periodo] ([spe_id]),
        CONSTRAINT FK_SPA_ARCHIVO FOREIGN KEY ([spa_archivo]) REFERENCES [dbo].[Archivo] ([arc_id]),
        CONSTRAINT FK_SPA_ESTADO FOREIGN KEY ([spa_suscripcion_pago_estado]) REFERENCES [dbo].[Suscripcion_Pago_Estado] ([spo_id]),
        CONSTRAINT FK_SPA_VERIFICADOR FOREIGN KEY ([spa_usuario_verificador]) REFERENCES [dbo].[Usuario] ([usu_id]),
        -- Un pago verificado tiene que tener monto verificado y quien lo verifico.
        CONSTRAINT CK_SPA_VERIFICADO CHECK ([spa_suscripcion_pago_estado] <> 3
              OR ([spa_monto_verificado_clp] IS NOT NULL AND [spa_usuario_verificador] IS NOT NULL))
    )
    CREATE NONCLUSTERED INDEX IX_SPA_PERIODO ON [dbo].[Suscripcion_Pago] ([spa_suscripcion_periodo])
    PRINT 'Tabla Suscripcion_Pago creada correctamente.'
END
ELSE
    PRINT 'Tabla Suscripcion_Pago ya existe.'
GO


/* ========================================================================
   9. SUSCRIPCION_CONSUMO  (append-only)
      Foto mensual del uso. Sirve para facturar por sobreconsumo y, sobre
      todo, para saber a quien ofrecerle el upgrade.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Suscripcion_Consumo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Suscripcion_Consumo]
    (
        [sco_id]                    INT             NOT NULL IDENTITY(1,1),
        [sco_suscripcion]           INT             NOT NULL,
        [sco_periodo_anio]          INT             NOT NULL,
        [sco_periodo_mes]           INT             NOT NULL,
        [sco_plantas]               INT             NOT NULL,
        [sco_usuarios]              INT             NOT NULL,
        [sco_activos]               INT             NOT NULL,
        [sco_ordenes_trabajo]       INT             NOT NULL,
        [sco_ejecuciones_checklist] INT             NOT NULL,
        [sco_dictados_voz]          INT             NOT NULL,
        [sco_almacenamiento_gb]     DECIMAL(18,2)   NOT NULL,
        [sco_fecha_utc]             DATETIME        NOT NULL,
        [sco_usuario_creacion]      INT             NOT NULL,
        [sco_fecha_creacion]        DATETIME        NOT NULL CONSTRAINT DF_SCO_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_SUSCRIPCION_CONSUMO PRIMARY KEY CLUSTERED ([sco_id] ASC),
        CONSTRAINT FK_SCO_SUSCRIPCION FOREIGN KEY ([sco_suscripcion]) REFERENCES [dbo].[Suscripcion] ([sus_id]),
        CONSTRAINT CK_SCO_MES CHECK ([sco_periodo_mes] BETWEEN 1 AND 12)
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_SCO_SUSCRIPCION_PERIODO
        ON [dbo].[Suscripcion_Consumo] ([sco_suscripcion], [sco_periodo_anio], [sco_periodo_mes])
    PRINT 'Tabla Suscripcion_Consumo creada correctamente.'
END
ELSE
    PRINT 'Tabla Suscripcion_Consumo ya existe.'
GO


/* ========================================================================
   10. SUSCRIPCION_BLOQUEO_LOG  (append-only)
       Responde "desde cuando este cliente no puede entrar" cuando llama
       enojado, y deja ver si alguien esta probando claves.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Suscripcion_Bloqueo_Log]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Suscripcion_Bloqueo_Log]
    (
        [sbl_id]                    INT             NOT NULL IDENTITY(1,1),
        [sbl_suscripcion]           INT             NULL,       -- NULL = la clave no existe
        [sbl_key_prefijo]           NVARCHAR(20)    NULL,
        [sbl_estado]                NVARCHAR(20)    NOT NULL,   -- VENCIDA | SUSPENDIDA | CANCELADA | NO EXISTE
        [sbl_origen]                NVARCHAR(10)    NOT NULL,   -- WEB | APP | API
        [sbl_endpoint]              NVARCHAR(200)   NULL,
        [sbl_ip]                    NVARCHAR(45)    NULL,
        [sbl_fecha_utc]             DATETIME        NOT NULL,
        [sbl_usuario_creacion]      INT             NULL,
        [sbl_fecha_creacion]        DATETIME        NOT NULL CONSTRAINT DF_SBL_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_SUSCRIPCION_BLOQUEO_LOG PRIMARY KEY CLUSTERED ([sbl_id] ASC),
        CONSTRAINT FK_SBL_SUSCRIPCION FOREIGN KEY ([sbl_suscripcion]) REFERENCES [dbo].[Suscripcion] ([sus_id])
    )
    CREATE NONCLUSTERED INDEX IX_SBL_FECHA ON [dbo].[Suscripcion_Bloqueo_Log] ([sbl_fecha_utc] DESC)
    PRINT 'Tabla Suscripcion_Bloqueo_Log creada correctamente.'
END
ELSE
    PRINT 'Tabla Suscripcion_Bloqueo_Log ya existe.'
GO


/* ========================================================================
   11. FNC_SUSCRIPCION_VIGENTE
       Unica fuente de verdad. VENCIDA y EN GRACIA se CALCULAN: un estado
       que cambia solo porque paso el tiempo no puede depender de un job.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_SUSCRIPCION_VIGENTE] (@KEY_HASH VARBINARY(32))
RETURNS @R TABLE
(
    CLIENTE         INT,
    SUSCRIPCION     INT,
    PLAN_COMERCIAL  INT,
    ESTADO          NVARCHAR(20),
    FECHA_FIN       DATE,
    DIAS_RESTANTES  INT,
    PUEDE_OPERAR    BIT
)
AS
BEGIN
    DECLARE @HOY DATE = CAST(GETDATE() AS DATE)

    INSERT @R (CLIENTE, SUSCRIPCION, PLAN_COMERCIAL, ESTADO, FECHA_FIN, DIAS_RESTANTES, PUEDE_OPERAR)
    SELECT  s.sus_cliente,
            s.sus_id,
            s.sus_plan_comercial,
            CASE
                WHEN s.sus_suscripcion_estado = 3 THEN N'CANCELADA'
                WHEN s.sus_suscripcion_estado = 2 THEN N'SUSPENDIDA'
                WHEN s.sus_fecha_fin IS NULL      THEN N'VENCIDA'
                WHEN s.sus_fecha_fin >= @HOY      THEN N'VIGENTE'
                WHEN DATEADD(DAY, s.sus_dias_gracia, s.sus_fecha_fin) >= @HOY THEN N'EN GRACIA'
                ELSE N'VENCIDA'
            END,
            s.sus_fecha_fin,
            DATEDIFF(DAY, @HOY, s.sus_fecha_fin),
            CASE WHEN s.sus_suscripcion_estado = 1
                  AND s.sus_habilitado = 1
                  AND DATEADD(DAY, s.sus_dias_gracia, ISNULL(s.sus_fecha_fin, '19000101')) >= @HOY
                 THEN 1 ELSE 0 END
    FROM    [dbo].[Suscripcion] s
    WHERE   s.sus_key_hash = @KEY_HASH

    RETURN
END
GO


/* ========================================================================
   12. FNC_CLIENTE_TIENE_FUNCIONALIDAD
       La excepcion del cliente gana sobre la regla del plan.
       Mismo patron que los permisos por usuario del Anexo D.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_CLIENTE_TIENE_FUNCIONALIDAD]
(
    @CLIENTE             INT,
    @FUNCIONALIDAD_CODIGO NVARCHAR(50)
)
RETURNS BIT
AS
BEGIN
    DECLARE @FUN INT, @PLAN INT, @INCLUIDA BIT, @HOY DATE = CAST(GETDATE() AS DATE)

    SELECT @FUN = fun_id FROM [dbo].[Funcionalidad]
     WHERE fun_codigo = @FUNCIONALIDAD_CODIGO AND fun_habilitado = 1
    IF @FUN IS NULL RETURN 0

    SELECT @PLAN = sus_plan_comercial FROM [dbo].[Suscripcion]
     WHERE sus_cliente = @CLIENTE AND sus_habilitado = 1
    IF @PLAN IS NULL RETURN 0

    -- La fila del cliente gana; si no hay, manda la del plan.
    SELECT TOP 1 @INCLUIDA = pcf.pcf_incluida
      FROM [dbo].[Plan_Comercial_Funcionalidad] pcf
     WHERE pcf.pcf_plan_comercial = @PLAN
       AND pcf.pcf_funcionalidad  = @FUN
       AND pcf.pcf_habilitado     = 1
       AND (pcf.pcf_cliente IS NULL OR pcf.pcf_cliente = @CLIENTE)
       AND (pcf.pcf_vigencia_hasta IS NULL OR pcf.pcf_vigencia_hasta >= @HOY)
     ORDER BY CASE WHEN pcf.pcf_cliente IS NULL THEN 1 ELSE 0 END

    RETURN ISNULL(@INCLUIDA, 0)
END
GO


/* ========================================================================
   13. FNC_CLIENTE_LIMITE
       Devuelve el tope de una funcionalidad de tipo LIMITE.
       NULL = sin tope. Los INS_ la consultan antes de crear.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_CLIENTE_LIMITE]
(
    @CLIENTE              INT,
    @FUNCIONALIDAD_CODIGO NVARCHAR(50)
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @FUN INT, @PLAN INT, @LIMITE DECIMAL(18,2), @HOY DATE = CAST(GETDATE() AS DATE)

    SELECT @FUN = fun_id FROM [dbo].[Funcionalidad] WHERE fun_codigo = @FUNCIONALIDAD_CODIGO
    SELECT @PLAN = sus_plan_comercial FROM [dbo].[Suscripcion] WHERE sus_cliente = @CLIENTE AND sus_habilitado = 1
    IF @FUN IS NULL OR @PLAN IS NULL RETURN 0

    SELECT TOP 1 @LIMITE = pcf.pcf_limite
      FROM [dbo].[Plan_Comercial_Funcionalidad] pcf
     WHERE pcf.pcf_plan_comercial = @PLAN
       AND pcf.pcf_funcionalidad  = @FUN
       AND pcf.pcf_habilitado     = 1
       AND pcf.pcf_incluida       = 1
       AND (pcf.pcf_cliente IS NULL OR pcf.pcf_cliente = @CLIENTE)
       AND (pcf.pcf_vigencia_hasta IS NULL OR pcf.pcf_vigencia_hasta >= @HOY)
     ORDER BY CASE WHEN pcf.pcf_cliente IS NULL THEN 1 ELSE 0 END

    RETURN @LIMITE      -- NULL = sin tope
END
GO


/* ========================================================================
   14. PARAMETROS
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM [dbo].[Sys_Parametros] WHERE [par_codigo] = 'SUSCRIPCION_TOLERANCIA_CLP')
    INSERT INTO [dbo].[Sys_Parametros] ([par_codigo], [par_nombre], [par_descripcion], [par_valor])
    VALUES ('SUSCRIPCION_TOLERANCIA_CLP', 'Tolerancia de pago en pesos',
            'Diferencia en pesos que se acepta entre lo cobrado y lo transferido.', '2000')
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[Sys_Parametros] WHERE [par_codigo] = 'SUSCRIPCION_TOLERANCIA_PORCENTAJE')
    INSERT INTO [dbo].[Sys_Parametros] ([par_codigo], [par_nombre], [par_descripcion], [par_valor])
    VALUES ('SUSCRIPCION_TOLERANCIA_PORCENTAJE', 'Tolerancia de pago en porcentaje',
            'Diferencia porcentual que se acepta entre lo cobrado y lo transferido.', '1.0')
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[Sys_Parametros] WHERE [par_codigo] = 'SUSCRIPCION_DIAS_AVISO')
    INSERT INTO [dbo].[Sys_Parametros] ([par_codigo], [par_nombre], [par_descripcion], [par_valor])
    VALUES ('SUSCRIPCION_DIAS_AVISO', 'Dias de aviso previo al vencimiento',
            'Con cuantos dias de anticipacion se avisa que la suscripcion vence.', '10')
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[Sys_Parametros] WHERE [par_codigo] = 'UF_API_URL')
    INSERT INTO [dbo].[Sys_Parametros] ([par_codigo], [par_nombre], [par_descripcion], [par_valor])
    VALUES ('UF_API_URL', 'URL de la fuente de UF',
            'La consulta la hace el JOB DEL SERVIDOR, nunca el navegador.', 'https://mindicador.cl/api/uf')
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[Sys_Parametros] WHERE [par_codigo] = 'SUSCRIPCION_URL_RENOVACION')
    INSERT INTO [dbo].[Sys_Parametros] ([par_codigo], [par_nombre], [par_descripcion], [par_valor])
    VALUES ('SUSCRIPCION_URL_RENOVACION', 'URL de la pagina de renovacion',
            'A donde se envia al cliente cuando la API responde 402.', 'https://sigma.cl/renovar')
GO


/* ========================================================================
   15. CARGA INICIAL DE PLANES
   ======================================================================== */

-- Planes
SET IDENTITY_INSERT [dbo].[Plan_Comercial] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE [plc_id] = 1)
    INSERT INTO [dbo].[Plan_Comercial] ([plc_id], [plc_codigo], [plc_nombre], [plc_descripcion], [plc_orden], [plc_dias_gracia], [plc_publico], [plc_usuario_creacion])
    VALUES (1, N'BASICO', N'Básico', N'Mantenimiento preventivo por calendario para una planta.', 1, 5, 1, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE [plc_id] = 2)
    INSERT INTO [dbo].[Plan_Comercial] ([plc_id], [plc_codigo], [plc_nombre], [plc_descripcion], [plc_orden], [plc_dias_gracia], [plc_publico], [plc_usuario_creacion])
    VALUES (2, N'MEDIO', N'Medio', N'Suma horómetros, voz, inclusión, inventario y terreno.', 2, 5, 1, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE [plc_id] = 3)
    INSERT INTO [dbo].[Plan_Comercial] ([plc_id], [plc_codigo], [plc_nombre], [plc_descripcion], [plc_orden], [plc_dias_gracia], [plc_publico], [plc_usuario_creacion])
    VALUES (3, N'FULL', N'Full', N'Suma análisis visual, predicción de fallas y API de integración.', 3, 10, 1, 1)
SET IDENTITY_INSERT [dbo].[Plan_Comercial] OFF
GO

-- Precios vigentes desde hoy. Para subir un precio NO se hace UPDATE:
-- se cierra la fila vigente con pcp_vigencia_hasta y se inserta otra.
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Precio] WHERE [pcp_plan_comercial] = 1 AND [pcp_periodicidad_cobro] = 1 AND [pcp_vigencia_hasta] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Precio] ([pcp_plan_comercial], [pcp_periodicidad_cobro], [pcp_valor_uf], [pcp_vigencia_desde], [pcp_descuento_porcentaje], [pcp_usuario_creacion])
    VALUES (1, 1, 9.0, CAST(GETDATE() AS DATE), NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Precio] WHERE [pcp_plan_comercial] = 1 AND [pcp_periodicidad_cobro] = 2 AND [pcp_vigencia_hasta] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Precio] ([pcp_plan_comercial], [pcp_periodicidad_cobro], [pcp_valor_uf], [pcp_vigencia_desde], [pcp_descuento_porcentaje], [pcp_usuario_creacion])
    VALUES (1, 2, 25.7, CAST(GETDATE() AS DATE), 5.0, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Precio] WHERE [pcp_plan_comercial] = 1 AND [pcp_periodicidad_cobro] = 3 AND [pcp_vigencia_hasta] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Precio] ([pcp_plan_comercial], [pcp_periodicidad_cobro], [pcp_valor_uf], [pcp_vigencia_desde], [pcp_descuento_porcentaje], [pcp_usuario_creacion])
    VALUES (1, 3, 90.0, CAST(GETDATE() AS DATE), 16.67, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Precio] WHERE [pcp_plan_comercial] = 2 AND [pcp_periodicidad_cobro] = 1 AND [pcp_vigencia_hasta] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Precio] ([pcp_plan_comercial], [pcp_periodicidad_cobro], [pcp_valor_uf], [pcp_vigencia_desde], [pcp_descuento_porcentaje], [pcp_usuario_creacion])
    VALUES (2, 1, 22.0, CAST(GETDATE() AS DATE), NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Precio] WHERE [pcp_plan_comercial] = 2 AND [pcp_periodicidad_cobro] = 2 AND [pcp_vigencia_hasta] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Precio] ([pcp_plan_comercial], [pcp_periodicidad_cobro], [pcp_valor_uf], [pcp_vigencia_desde], [pcp_descuento_porcentaje], [pcp_usuario_creacion])
    VALUES (2, 2, 62.7, CAST(GETDATE() AS DATE), 5.0, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Precio] WHERE [pcp_plan_comercial] = 2 AND [pcp_periodicidad_cobro] = 3 AND [pcp_vigencia_hasta] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Precio] ([pcp_plan_comercial], [pcp_periodicidad_cobro], [pcp_valor_uf], [pcp_vigencia_desde], [pcp_descuento_porcentaje], [pcp_usuario_creacion])
    VALUES (2, 3, 220.0, CAST(GETDATE() AS DATE), 16.67, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Precio] WHERE [pcp_plan_comercial] = 3 AND [pcp_periodicidad_cobro] = 1 AND [pcp_vigencia_hasta] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Precio] ([pcp_plan_comercial], [pcp_periodicidad_cobro], [pcp_valor_uf], [pcp_vigencia_desde], [pcp_descuento_porcentaje], [pcp_usuario_creacion])
    VALUES (3, 1, 45.0, CAST(GETDATE() AS DATE), NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Precio] WHERE [pcp_plan_comercial] = 3 AND [pcp_periodicidad_cobro] = 2 AND [pcp_vigencia_hasta] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Precio] ([pcp_plan_comercial], [pcp_periodicidad_cobro], [pcp_valor_uf], [pcp_vigencia_desde], [pcp_descuento_porcentaje], [pcp_usuario_creacion])
    VALUES (3, 2, 128.3, CAST(GETDATE() AS DATE), 5.0, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Precio] WHERE [pcp_plan_comercial] = 3 AND [pcp_periodicidad_cobro] = 3 AND [pcp_vigencia_hasta] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Precio] ([pcp_plan_comercial], [pcp_periodicidad_cobro], [pcp_valor_uf], [pcp_vigencia_desde], [pcp_descuento_porcentaje], [pcp_usuario_creacion])
    VALUES (3, 3, 450.0, CAST(GETDATE() AS DATE), 16.67, 1)
GO

-- Funcionalidades por plan (pcf_cliente NULL = regla del plan)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 1 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 1, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 2 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 2, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 3 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 3, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 4 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 4, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 5 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 5, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 6 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 6, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 7 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 7, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 8 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 8, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 9 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 9, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 10 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 10, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 11 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 11, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 12 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_observacion], [pcf_usuario_creacion]) VALUES (1, 12, 1, NULL, N'INCLUIDA EN TODOS LOS PLANES. La lectura en voz alta es lo que permite trabajar a quien no sabe leer: es acceso, no comodidad. Corre en el telefono, asi que no cuesta nada cobrarla ni ahorra nada negarla.', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 13 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 13, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 14 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 14, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 15 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 15, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 16 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 16, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 17 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 17, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 18 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 18, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 19 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 19, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 20 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 20, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 21 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 21, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 22 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 22, 1, 1, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 23 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 23, 1, 5, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 24 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 24, 1, 150, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 1 AND [pcf_funcionalidad] = 25 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (1, 25, 1, 5, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 1 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 1, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 2 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 2, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 3 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 3, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 4 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 4, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 5 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 5, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 6 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 6, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 7 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 7, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 8 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 8, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 9 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 9, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 10 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 10, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 11 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 11, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 12 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 12, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 13 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 13, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 14 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 14, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 15 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 15, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 16 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 16, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 17 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 17, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 18 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 18, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 19 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 19, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 20 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 20, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 21 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 21, 0, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 22 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 22, 1, 3, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 23 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 23, 1, 25, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 24 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 24, 1, 750, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 2 AND [pcf_funcionalidad] = 25 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (2, 25, 1, 50, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 1 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 1, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 2 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 2, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 3 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 3, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 4 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 4, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 5 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 5, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 6 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 6, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 7 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 7, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 8 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 8, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 9 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 9, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 10 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 10, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 11 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 11, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 12 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 12, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 13 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 13, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 14 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 14, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 15 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 15, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 16 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 16, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 17 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 17, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 18 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 18, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 19 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 19, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 20 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 20, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 21 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 21, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 22 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 22, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 23 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 23, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 24 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 24, 1, NULL, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial_Funcionalidad] WHERE [pcf_plan_comercial] = 3 AND [pcf_funcionalidad] = 25 AND [pcf_cliente] IS NULL)
    INSERT INTO [dbo].[Plan_Comercial_Funcionalidad] ([pcf_plan_comercial], [pcf_funcionalidad], [pcf_incluida], [pcf_limite], [pcf_usuario_creacion]) VALUES (3, 25, 1, 500, 1)
GO

PRINT 'Bloque de suscripcion y modelo comercial aplicado correctamente.'
GO
