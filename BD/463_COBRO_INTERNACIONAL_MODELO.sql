/* ============================================================================
   SIGMA — Bloque 463
   CAPA INTERNACIONAL DEL CENTRO COMERCIAL: país del cliente y moneda de cobro
   ----------------------------------------------------------------------------
   REGLA (prompt V2, §5)
     Chile  -> precio en UF, cobro en CLP con la UF del día, Webpay o transferencia.
     Otro   -> precio y cobro en USD, transferencia internacional (SWIFT).

   LO QUE YA EXISTÍA Y SE REUTILIZA (no se duplica)
     Paises.pai_identificador_nombre / _validacion / _largo  -> RUT, RUC, CUIT...
     Cliente.cli_pais, cli_identificador                      -> país e identificador
   LO QUE SE AGREGA
     Cliente.cli_moneda_cobro      'UF' | 'USD'  (se fija al crear; no cambia sola)
     Lead.lea_pais_id, lea_identificador, lea_moneda
     Plan_Comercial_Precio.pcp_moneda   (pcp_valor_uf pasa a ser «valor en pcp_moneda»)
     Propuesta.ppt_moneda
     Suscripcion_Periodo.spe_moneda     (en USD: valor_uf_dia / fecha_valor_uf van NULL;
                                         spe_valor_uf_plan = monto USD; spe_monto_clp = monto de cobro)
     Suscripcion_Pago.spa_moneda, spa_medio
     Config_Comercial  -> datos bancarios editables (nunca fijos en código)
   Los montos siguen en DECIMAL. Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

/* ---- Países: Colombia y México (identificador libre, solo formato) ---- */
IF NOT EXISTS (SELECT 1 FROM Paises WHERE pai_nombre = 'Colombia')
    INSERT INTO Paises (pai_nombre, pai_suma_resta, pai_hora, pai_habilItado, pai_usuario_creacion, pai_fecha_creacion,
                        pai_identificador_nombre, pai_identificador_validacion, pai_identificador_largo, pai_zona_horaria)
    VALUES ('Colombia', '0', 0, 1, 1, GETDATE(), 'NIT', 'NINGUNO', 15, 'SA Pacific Standard Time')
IF NOT EXISTS (SELECT 1 FROM Paises WHERE pai_nombre LIKE 'M_xico')
    INSERT INTO Paises (pai_nombre, pai_suma_resta, pai_hora, pai_habilItado, pai_usuario_creacion, pai_fecha_creacion,
                        pai_identificador_nombre, pai_identificador_validacion, pai_identificador_largo, pai_zona_horaria)
    VALUES (N'México', '1', 1, 1, 1, GETDATE(), 'RFC', 'NINGUNO', 13, 'Central Standard Time (Mexico)')
GO

/* ---- Cliente ---- */
IF COL_LENGTH('dbo.Cliente', 'cli_moneda_cobro') IS NULL
BEGIN
    ALTER TABLE [dbo].[Cliente] ADD [cli_moneda_cobro] VARCHAR(3) NOT NULL CONSTRAINT DF_CLI_MONEDA_COBRO DEFAULT 'UF'
    EXEC(N'ALTER TABLE [dbo].[Cliente] ADD CONSTRAINT CK_CLI_MONEDA_COBRO CHECK ([cli_moneda_cobro] IN (''UF'',''USD''))')
END
GO
-- Los clientes de fuera de Chile ya existentes cobran en USD; los chilenos quedan en UF.
UPDATE Cliente SET cli_moneda_cobro = 'USD' WHERE cli_pais <> 1 AND cli_moneda_cobro = 'UF'
GO

/* ---- Lead ---- */
IF COL_LENGTH('dbo.Lead', 'lea_pais_id') IS NULL
BEGIN
    ALTER TABLE [dbo].[Lead] ADD [lea_pais_id] INT NULL
    ALTER TABLE [dbo].[Lead] ADD [lea_identificador] NVARCHAR(30) NULL
    ALTER TABLE [dbo].[Lead] ADD [lea_moneda] VARCHAR(3) NOT NULL CONSTRAINT DF_LEA_MONEDA DEFAULT 'UF'
    EXEC(N'ALTER TABLE [dbo].[Lead] ADD CONSTRAINT CK_LEA_MONEDA CHECK ([lea_moneda] IN (''UF'',''USD''))')
    EXEC(N'ALTER TABLE [dbo].[Lead] ADD CONSTRAINT FK_LEA_PAIS FOREIGN KEY ([lea_pais_id]) REFERENCES [dbo].[Paises] ([pai_id])')
END
GO
UPDATE Lead SET lea_pais_id = 1 WHERE lea_pais_id IS NULL AND (lea_pais IS NULL OR lea_pais IN (N'Chile', N'CL', N''))
UPDATE Lead SET lea_identificador = lea_rut WHERE lea_identificador IS NULL AND lea_rut IS NOT NULL
GO

/* ---- Precio versionado: una fila vigente por plan, periodicidad y moneda ---- */
IF COL_LENGTH('dbo.Plan_Comercial_Precio', 'pcp_moneda') IS NULL
BEGIN
    ALTER TABLE [dbo].[Plan_Comercial_Precio] ADD [pcp_moneda] VARCHAR(3) NOT NULL CONSTRAINT DF_PCP_MONEDA DEFAULT 'UF'
    EXEC(N'ALTER TABLE [dbo].[Plan_Comercial_Precio] ADD CONSTRAINT CK_PCP_MONEDA CHECK ([pcp_moneda] IN (''UF'',''USD''))')
END
GO
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_PCP_PLAN_PERIODICIDAD_VIGENTE' AND object_id = OBJECT_ID('dbo.Plan_Comercial_Precio'))
    DROP INDEX UX_PCP_PLAN_PERIODICIDAD_VIGENTE ON [dbo].[Plan_Comercial_Precio]
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_PCP_PLAN_PERIODICIDAD_MONEDA_VIGENTE')
    CREATE UNIQUE NONCLUSTERED INDEX UX_PCP_PLAN_PERIODICIDAD_MONEDA_VIGENTE
        ON [dbo].[Plan_Comercial_Precio] ([pcp_plan_comercial], [pcp_periodicidad_cobro], [pcp_moneda])
        WHERE [pcp_vigencia_hasta] IS NULL AND [pcp_habilitado] = 1
GO

/* ---- Propuesta ---- */
IF COL_LENGTH('dbo.Propuesta', 'ppt_moneda') IS NULL
BEGIN
    ALTER TABLE [dbo].[Propuesta] ADD [ppt_moneda] VARCHAR(3) NOT NULL CONSTRAINT DF_PPT_MONEDA DEFAULT 'UF'
    EXEC(N'ALTER TABLE [dbo].[Propuesta] ADD CONSTRAINT CK_PPT_MONEDA CHECK ([ppt_moneda] IN (''UF'',''USD''))')
END
GO

/* ---- Período: en USD no hay UF ---- */
IF COL_LENGTH('dbo.Suscripcion_Periodo', 'spe_moneda') IS NULL
BEGIN
    ALTER TABLE [dbo].[Suscripcion_Periodo] ADD [spe_moneda] VARCHAR(3) NOT NULL CONSTRAINT DF_SPE_MONEDA DEFAULT 'UF'
    EXEC(N'ALTER TABLE [dbo].[Suscripcion_Periodo] ADD CONSTRAINT CK_SPE_MONEDA CHECK ([spe_moneda] IN (''UF'',''USD''))')
    EXEC(N'ALTER TABLE [dbo].[Suscripcion_Periodo] ALTER COLUMN [spe_valor_uf_dia] DECIMAL(18,4) NULL')
    EXEC(N'ALTER TABLE [dbo].[Suscripcion_Periodo] ALTER COLUMN [spe_fecha_valor_uf] DATE NULL')
END
GO

/* ---- Pago ---- */
IF COL_LENGTH('dbo.Suscripcion_Pago', 'spa_moneda') IS NULL
BEGIN
    ALTER TABLE [dbo].[Suscripcion_Pago] ADD [spa_moneda] VARCHAR(3) NOT NULL CONSTRAINT DF_SPA_MONEDA DEFAULT 'CLP'
    ALTER TABLE [dbo].[Suscripcion_Pago] ADD [spa_medio] VARCHAR(30) NOT NULL CONSTRAINT DF_SPA_MEDIO DEFAULT 'TRANSFERENCIA_NACIONAL'
    EXEC(N'ALTER TABLE [dbo].[Suscripcion_Pago] ADD CONSTRAINT CK_SPA_MONEDA CHECK ([spa_moneda] IN (''CLP'',''USD''))')
    EXEC(N'ALTER TABLE [dbo].[Suscripcion_Pago] ADD CONSTRAINT CK_SPA_MEDIO CHECK ([spa_medio] IN (''WEBPAY'',''TRANSFERENCIA_NACIONAL'',''TRANSFERENCIA_INTERNACIONAL''))')
END
GO
-- Los pagos que entraron por Webpay quedan marcados como tales.
UPDATE Suscripcion_Pago SET spa_medio = 'WEBPAY'
WHERE spa_medio = 'TRANSFERENCIA_NACIONAL' AND spa_banco = N'Webpay Plus'
GO

/* ---- Config_Comercial: datos bancarios editables ---- */
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Config_Comercial]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Config_Comercial]
    (
        [ccm_clave]                 VARCHAR(60)     NOT NULL,
        [ccm_grupo]                 VARCHAR(30)     NOT NULL,
        [ccm_etiqueta]              NVARCHAR(100)   NOT NULL,
        [ccm_valor]                 NVARCHAR(300)   NULL,
        [ccm_orden]                 INT             NOT NULL CONSTRAINT DF_CCM_ORDEN DEFAULT 0,
        [ccm_usuario_actualizacion] INT             NULL,
        [ccm_fecha_actualizacion]   DATETIME        NULL,
        CONSTRAINT PK_CONFIG_COMERCIAL PRIMARY KEY CLUSTERED ([ccm_clave] ASC),
        CONSTRAINT CK_CCM_GRUPO CHECK ([ccm_grupo] IN ('BANCO_NACIONAL','BANCO_INTERNACIONAL'))
    )
END
GO
-- Claves sembradas SIN valor: se completan en Configuración (no van en código).
INSERT INTO Config_Comercial (ccm_clave, ccm_grupo, ccm_etiqueta, ccm_orden)
SELECT v.k, v.g, v.e, v.o FROM (VALUES
 ('NAC_BANCO',        'BANCO_NACIONAL',      N'Banco',                 1),
 ('NAC_TIPO_CUENTA',  'BANCO_NACIONAL',      N'Tipo de cuenta',        2),
 ('NAC_NUMERO_CUENTA','BANCO_NACIONAL',      N'N° de cuenta',          3),
 ('NAC_TITULAR',      'BANCO_NACIONAL',      N'Titular',               4),
 ('NAC_RUT',          'BANCO_NACIONAL',      N'RUT del titular',       5),
 ('NAC_CORREO',       'BANCO_NACIONAL',      N'Correo de aviso',       6),
 ('INT_BENEFICIARIO', 'BANCO_INTERNACIONAL', N'Beneficiario',          1),
 ('INT_BANCO',        'BANCO_INTERNACIONAL', N'Banco',                 2),
 ('INT_SWIFT',        'BANCO_INTERNACIONAL', N'Código SWIFT / BIC',    3),
 ('INT_CUENTA',       'BANCO_INTERNACIONAL', N'Cuenta (IBAN o número)',4),
 ('INT_DIRECCION',    'BANCO_INTERNACIONAL', N'Dirección del banco',   5)
) v(k, g, e, o)
WHERE NOT EXISTS (SELECT 1 FROM Config_Comercial c WHERE c.ccm_clave = v.k)
GO
PRINT 'Bloque 463 aplicado.'
GO
