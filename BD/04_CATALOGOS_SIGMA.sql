USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  19-08-2026
-- DESCRIPTION:     CREA Y CARGA LOS CATALOGOS DE IDS FIJOS DE SIGMA.
-- =============================================
-- Regla de datos: <pfx>_codigo en MAYUSCULAS con ESPACIOS (nunca guion bajo,
-- nunca tildes). <pfx>_nombre es el texto que ve el usuario en el front.
--
-- Dos clases de catalogo:
--   FIJO      el codigo bifurca por sus valores (estados, tipos de dato,
--             frecuencias, operadores). Agregar filas romperia la logica.
--   AMPLIABLE nadie bifurca por sus valores. Lleva <pfx>_cliente NULL y cada
--             cliente puede agregar los suyos sin tocar codigo.
--             NULL = fila global de SIGMA, valida para todos los clientes.
--
-- Script idempotente: se puede ejecutar las veces que sea.
-- =============================================

/* ========================================================================
   TRANSVERSALES
   ======================================================================== */

-- Dia_Semana (dse) — Dias de la semana ISO (1 lunes)
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Dia_Semana]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Dia_Semana]
    (
        [dse_id]                      INT             NOT NULL IDENTITY(1,1),
        [dse_codigo]                  NVARCHAR(50)    NOT NULL,
        [dse_nombre]                  NVARCHAR(100)   NOT NULL,
        [dse_orden]                   INT             NULL,
        [dse_habilitado]              BIT             NOT NULL CONSTRAINT DF_DSE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_DIA_SEMANA PRIMARY KEY CLUSTERED ([dse_id] ASC),
        CONSTRAINT UX_DSE_CODIGO UNIQUE ([dse_codigo])
    )

    PRINT 'Tabla Dia_Semana creada correctamente.'
END
ELSE
    PRINT 'Tabla Dia_Semana ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Dia_Semana] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dia_Semana] WHERE [dse_id] = 1)
    INSERT INTO [dbo].[Dia_Semana] ([dse_id], [dse_codigo], [dse_nombre], [dse_orden]) VALUES (1, N'LUNES', N'Lunes', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dia_Semana] WHERE [dse_id] = 2)
    INSERT INTO [dbo].[Dia_Semana] ([dse_id], [dse_codigo], [dse_nombre], [dse_orden]) VALUES (2, N'MARTES', N'Martes', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dia_Semana] WHERE [dse_id] = 3)
    INSERT INTO [dbo].[Dia_Semana] ([dse_id], [dse_codigo], [dse_nombre], [dse_orden]) VALUES (3, N'MIERCOLES', N'Miércoles', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dia_Semana] WHERE [dse_id] = 4)
    INSERT INTO [dbo].[Dia_Semana] ([dse_id], [dse_codigo], [dse_nombre], [dse_orden]) VALUES (4, N'JUEVES', N'Jueves', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dia_Semana] WHERE [dse_id] = 5)
    INSERT INTO [dbo].[Dia_Semana] ([dse_id], [dse_codigo], [dse_nombre], [dse_orden]) VALUES (5, N'VIERNES', N'Viernes', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dia_Semana] WHERE [dse_id] = 6)
    INSERT INTO [dbo].[Dia_Semana] ([dse_id], [dse_codigo], [dse_nombre], [dse_orden]) VALUES (6, N'SABADO', N'Sábado', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dia_Semana] WHERE [dse_id] = 7)
    INSERT INTO [dbo].[Dia_Semana] ([dse_id], [dse_codigo], [dse_nombre], [dse_orden]) VALUES (7, N'DOMINGO', N'Domingo', 7)
SET IDENTITY_INSERT [dbo].[Dia_Semana] OFF
GO

-- Frecuencia_Tipo (fre) — Frecuencia de una programacion por calendario
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Frecuencia_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Frecuencia_Tipo]
    (
        [fre_id]                      INT             NOT NULL IDENTITY(1,1),
        [fre_codigo]                  NVARCHAR(50)    NOT NULL,
        [fre_nombre]                  NVARCHAR(100)   NOT NULL,
        [fre_orden]                   INT             NULL,
        [fre_habilitado]              BIT             NOT NULL CONSTRAINT DF_FRE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_FRECUENCIA_TIPO PRIMARY KEY CLUSTERED ([fre_id] ASC),
        CONSTRAINT UX_FRE_CODIGO UNIQUE ([fre_codigo])
    )

    PRINT 'Tabla Frecuencia_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Frecuencia_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Frecuencia_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Frecuencia_Tipo] WHERE [fre_id] = 1)
    INSERT INTO [dbo].[Frecuencia_Tipo] ([fre_id], [fre_codigo], [fre_nombre], [fre_orden]) VALUES (1, N'DIARIA', N'Diaria', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Frecuencia_Tipo] WHERE [fre_id] = 2)
    INSERT INTO [dbo].[Frecuencia_Tipo] ([fre_id], [fre_codigo], [fre_nombre], [fre_orden]) VALUES (2, N'SEMANAL', N'Semanal', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Frecuencia_Tipo] WHERE [fre_id] = 3)
    INSERT INTO [dbo].[Frecuencia_Tipo] ([fre_id], [fre_codigo], [fre_nombre], [fre_orden]) VALUES (3, N'MENSUAL', N'Mensual', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Frecuencia_Tipo] WHERE [fre_id] = 4)
    INSERT INTO [dbo].[Frecuencia_Tipo] ([fre_id], [fre_codigo], [fre_nombre], [fre_orden]) VALUES (4, N'ANUAL', N'Anual', 4)
SET IDENTITY_INSERT [dbo].[Frecuencia_Tipo] OFF
GO

-- Unidad_Tiempo (uti) — Unidad de tiempo para intervalos
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Unidad_Tiempo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Unidad_Tiempo]
    (
        [uti_id]                      INT             NOT NULL IDENTITY(1,1),
        [uti_codigo]                  NVARCHAR(50)    NOT NULL,
        [uti_nombre]                  NVARCHAR(100)   NOT NULL,
        [uti_orden]                   INT             NULL,
        [uti_habilitado]              BIT             NOT NULL CONSTRAINT DF_UTI_HABILITADO DEFAULT 1,

        CONSTRAINT PK_UNIDAD_TIEMPO PRIMARY KEY CLUSTERED ([uti_id] ASC),
        CONSTRAINT UX_UTI_CODIGO UNIQUE ([uti_codigo])
    )

    PRINT 'Tabla Unidad_Tiempo creada correctamente.'
END
ELSE
    PRINT 'Tabla Unidad_Tiempo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Unidad_Tiempo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Tiempo] WHERE [uti_id] = 1)
    INSERT INTO [dbo].[Unidad_Tiempo] ([uti_id], [uti_codigo], [uti_nombre], [uti_orden]) VALUES (1, N'MINUTO', N'Minuto', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Tiempo] WHERE [uti_id] = 2)
    INSERT INTO [dbo].[Unidad_Tiempo] ([uti_id], [uti_codigo], [uti_nombre], [uti_orden]) VALUES (2, N'HORA', N'Hora', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Tiempo] WHERE [uti_id] = 3)
    INSERT INTO [dbo].[Unidad_Tiempo] ([uti_id], [uti_codigo], [uti_nombre], [uti_orden]) VALUES (3, N'DIA', N'Día', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Tiempo] WHERE [uti_id] = 4)
    INSERT INTO [dbo].[Unidad_Tiempo] ([uti_id], [uti_codigo], [uti_nombre], [uti_orden]) VALUES (4, N'SEMANA', N'Semana', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Tiempo] WHERE [uti_id] = 5)
    INSERT INTO [dbo].[Unidad_Tiempo] ([uti_id], [uti_codigo], [uti_nombre], [uti_orden]) VALUES (5, N'MES', N'Mes', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Tiempo] WHERE [uti_id] = 6)
    INSERT INTO [dbo].[Unidad_Tiempo] ([uti_id], [uti_codigo], [uti_nombre], [uti_orden]) VALUES (6, N'ANIO', N'Año', 6)
SET IDENTITY_INSERT [dbo].[Unidad_Tiempo] OFF
GO

-- Operador_Comparacion (opc) — Operadores de condicion y dependencia
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Operador_Comparacion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Operador_Comparacion]
    (
        [opc_id]                      INT             NOT NULL IDENTITY(1,1),
        [opc_codigo]                  NVARCHAR(50)    NOT NULL,
        [opc_nombre]                  NVARCHAR(100)   NOT NULL,
        [opc_orden]                   INT             NULL,
        [opc_habilitado]              BIT             NOT NULL CONSTRAINT DF_OPC_HABILITADO DEFAULT 1,

        CONSTRAINT PK_OPERADOR_COMPARACION PRIMARY KEY CLUSTERED ([opc_id] ASC),
        CONSTRAINT UX_OPC_CODIGO UNIQUE ([opc_codigo])
    )

    PRINT 'Tabla Operador_Comparacion creada correctamente.'
END
ELSE
    PRINT 'Tabla Operador_Comparacion ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Operador_Comparacion] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Operador_Comparacion] WHERE [opc_id] = 1)
    INSERT INTO [dbo].[Operador_Comparacion] ([opc_id], [opc_codigo], [opc_nombre], [opc_orden]) VALUES (1, N'IGUAL', N'Igual a', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Operador_Comparacion] WHERE [opc_id] = 2)
    INSERT INTO [dbo].[Operador_Comparacion] ([opc_id], [opc_codigo], [opc_nombre], [opc_orden]) VALUES (2, N'DISTINTO', N'Distinto de', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Operador_Comparacion] WHERE [opc_id] = 3)
    INSERT INTO [dbo].[Operador_Comparacion] ([opc_id], [opc_codigo], [opc_nombre], [opc_orden]) VALUES (3, N'MAYOR', N'Mayor que', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Operador_Comparacion] WHERE [opc_id] = 4)
    INSERT INTO [dbo].[Operador_Comparacion] ([opc_id], [opc_codigo], [opc_nombre], [opc_orden]) VALUES (4, N'MAYOR IGUAL', N'Mayor o igual que', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Operador_Comparacion] WHERE [opc_id] = 5)
    INSERT INTO [dbo].[Operador_Comparacion] ([opc_id], [opc_codigo], [opc_nombre], [opc_orden]) VALUES (5, N'MENOR', N'Menor que', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Operador_Comparacion] WHERE [opc_id] = 6)
    INSERT INTO [dbo].[Operador_Comparacion] ([opc_id], [opc_codigo], [opc_nombre], [opc_orden]) VALUES (6, N'MENOR IGUAL', N'Menor o igual que', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Operador_Comparacion] WHERE [opc_id] = 7)
    INSERT INTO [dbo].[Operador_Comparacion] ([opc_id], [opc_codigo], [opc_nombre], [opc_orden]) VALUES (7, N'ENTRE', N'Entre', 7)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Operador_Comparacion] WHERE [opc_id] = 8)
    INSERT INTO [dbo].[Operador_Comparacion] ([opc_id], [opc_codigo], [opc_nombre], [opc_orden]) VALUES (8, N'CONTIENE', N'Contiene', 8)
SET IDENTITY_INSERT [dbo].[Operador_Comparacion] OFF
GO

-- Severidad (sev) — Escala unica de severidad
--   FIJO: el codigo depende de estos ids  ·  visible en la app: lleva icono e imagen
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Severidad]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Severidad]
    (
        [sev_id]                      INT             NOT NULL IDENTITY(1,1),
        [sev_codigo]                  NVARCHAR(50)    NOT NULL,
        [sev_nombre]                  NVARCHAR(100)   NOT NULL,
        [sev_icono]                   NVARCHAR(50)    NULL,       -- icono del set de la app
        [sev_archivo]                 INT             NULL,       -- FK Archivo: foto real
        [sev_orden]                   INT             NULL,
        [sev_habilitado]              BIT             NOT NULL CONSTRAINT DF_SEV_HABILITADO DEFAULT 1,

        CONSTRAINT PK_SEVERIDAD PRIMARY KEY CLUSTERED ([sev_id] ASC),
        CONSTRAINT UX_SEV_CODIGO UNIQUE ([sev_codigo])
    )

    PRINT 'Tabla Severidad creada correctamente.'
END
ELSE
    PRINT 'Tabla Severidad ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Severidad] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Severidad] WHERE [sev_id] = 1)
    INSERT INTO [dbo].[Severidad] ([sev_id], [sev_codigo], [sev_nombre], [sev_orden]) VALUES (1, N'NORMAL', N'Normal', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Severidad] WHERE [sev_id] = 2)
    INSERT INTO [dbo].[Severidad] ([sev_id], [sev_codigo], [sev_nombre], [sev_orden]) VALUES (2, N'BAJA', N'Baja', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Severidad] WHERE [sev_id] = 3)
    INSERT INTO [dbo].[Severidad] ([sev_id], [sev_codigo], [sev_nombre], [sev_orden]) VALUES (3, N'ADVERTENCIA', N'Advertencia', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Severidad] WHERE [sev_id] = 4)
    INSERT INTO [dbo].[Severidad] ([sev_id], [sev_codigo], [sev_nombre], [sev_orden]) VALUES (4, N'ALTA', N'Alta', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Severidad] WHERE [sev_id] = 5)
    INSERT INTO [dbo].[Severidad] ([sev_id], [sev_codigo], [sev_nombre], [sev_orden]) VALUES (5, N'CRITICA', N'Crítica', 5)
SET IDENTITY_INSERT [dbo].[Severidad] OFF
GO

-- Tipo_Dato (tda) — Tipo de dato de un atributo, variable o item
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tipo_Dato]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Tipo_Dato]
    (
        [tda_id]                      INT             NOT NULL IDENTITY(1,1),
        [tda_codigo]                  NVARCHAR(50)    NOT NULL,
        [tda_nombre]                  NVARCHAR(100)   NOT NULL,
        [tda_orden]                   INT             NULL,
        [tda_habilitado]              BIT             NOT NULL CONSTRAINT DF_TDA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_TIPO_DATO PRIMARY KEY CLUSTERED ([tda_id] ASC),
        CONSTRAINT UX_TDA_CODIGO UNIQUE ([tda_codigo])
    )

    PRINT 'Tabla Tipo_Dato creada correctamente.'
END
ELSE
    PRINT 'Tabla Tipo_Dato ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Tipo_Dato] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tipo_Dato] WHERE [tda_id] = 1)
    INSERT INTO [dbo].[Tipo_Dato] ([tda_id], [tda_codigo], [tda_nombre], [tda_orden]) VALUES (1, N'TEXTO', N'Texto', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tipo_Dato] WHERE [tda_id] = 2)
    INSERT INTO [dbo].[Tipo_Dato] ([tda_id], [tda_codigo], [tda_nombre], [tda_orden]) VALUES (2, N'ENTERO', N'Entero', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tipo_Dato] WHERE [tda_id] = 3)
    INSERT INTO [dbo].[Tipo_Dato] ([tda_id], [tda_codigo], [tda_nombre], [tda_orden]) VALUES (3, N'DECIMAL', N'Decimal', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tipo_Dato] WHERE [tda_id] = 4)
    INSERT INTO [dbo].[Tipo_Dato] ([tda_id], [tda_codigo], [tda_nombre], [tda_orden]) VALUES (4, N'BIT', N'Sí / No', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tipo_Dato] WHERE [tda_id] = 5)
    INSERT INTO [dbo].[Tipo_Dato] ([tda_id], [tda_codigo], [tda_nombre], [tda_orden]) VALUES (5, N'FECHA', N'Fecha', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tipo_Dato] WHERE [tda_id] = 6)
    INSERT INTO [dbo].[Tipo_Dato] ([tda_id], [tda_codigo], [tda_nombre], [tda_orden]) VALUES (6, N'FECHA HORA', N'Fecha y hora', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tipo_Dato] WHERE [tda_id] = 7)
    INSERT INTO [dbo].[Tipo_Dato] ([tda_id], [tda_codigo], [tda_nombre], [tda_orden]) VALUES (7, N'HORA', N'Hora', 7)
SET IDENTITY_INSERT [dbo].[Tipo_Dato] OFF
GO

-- Magnitud (mag) — Magnitud fisica de una unidad de medida
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Magnitud]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Magnitud]
    (
        [mag_id]                      INT             NOT NULL IDENTITY(1,1),
        [mag_codigo]                  NVARCHAR(50)    NOT NULL,
        [mag_nombre]                  NVARCHAR(100)   NOT NULL,
        [mag_orden]                   INT             NULL,
        [mag_habilitado]              BIT             NOT NULL CONSTRAINT DF_MAG_HABILITADO DEFAULT 1,

        CONSTRAINT PK_MAGNITUD PRIMARY KEY CLUSTERED ([mag_id] ASC),
        CONSTRAINT UX_MAG_CODIGO UNIQUE ([mag_codigo])
    )

    PRINT 'Tabla Magnitud creada correctamente.'
END
ELSE
    PRINT 'Tabla Magnitud ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Magnitud] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Magnitud] WHERE [mag_id] = 1)
    INSERT INTO [dbo].[Magnitud] ([mag_id], [mag_codigo], [mag_nombre], [mag_orden]) VALUES (1, N'TEMPERATURA', N'Temperatura', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Magnitud] WHERE [mag_id] = 2)
    INSERT INTO [dbo].[Magnitud] ([mag_id], [mag_codigo], [mag_nombre], [mag_orden]) VALUES (2, N'VIBRACION', N'Vibración', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Magnitud] WHERE [mag_id] = 3)
    INSERT INTO [dbo].[Magnitud] ([mag_id], [mag_codigo], [mag_nombre], [mag_orden]) VALUES (3, N'PRESION', N'Presión', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Magnitud] WHERE [mag_id] = 4)
    INSERT INTO [dbo].[Magnitud] ([mag_id], [mag_codigo], [mag_nombre], [mag_orden]) VALUES (4, N'VELOCIDAD ROTACION', N'Velocidad de rotación', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Magnitud] WHERE [mag_id] = 5)
    INSERT INTO [dbo].[Magnitud] ([mag_id], [mag_codigo], [mag_nombre], [mag_orden]) VALUES (5, N'CORRIENTE', N'Corriente', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Magnitud] WHERE [mag_id] = 6)
    INSERT INTO [dbo].[Magnitud] ([mag_id], [mag_codigo], [mag_nombre], [mag_orden]) VALUES (6, N'VOLTAJE', N'Voltaje', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Magnitud] WHERE [mag_id] = 7)
    INSERT INTO [dbo].[Magnitud] ([mag_id], [mag_codigo], [mag_nombre], [mag_orden]) VALUES (7, N'CAUDAL', N'Caudal', 7)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Magnitud] WHERE [mag_id] = 8)
    INSERT INTO [dbo].[Magnitud] ([mag_id], [mag_codigo], [mag_nombre], [mag_orden]) VALUES (8, N'HUMEDAD', N'Humedad', 8)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Magnitud] WHERE [mag_id] = 9)
    INSERT INTO [dbo].[Magnitud] ([mag_id], [mag_codigo], [mag_nombre], [mag_orden]) VALUES (9, N'TIEMPO', N'Tiempo', 9)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Magnitud] WHERE [mag_id] = 10)
    INSERT INTO [dbo].[Magnitud] ([mag_id], [mag_codigo], [mag_nombre], [mag_orden]) VALUES (10, N'CONTEO', N'Conteo', 10)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Magnitud] WHERE [mag_id] = 11)
    INSERT INTO [dbo].[Magnitud] ([mag_id], [mag_codigo], [mag_nombre], [mag_orden]) VALUES (11, N'LONGITUD', N'Longitud', 11)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Magnitud] WHERE [mag_id] = 12)
    INSERT INTO [dbo].[Magnitud] ([mag_id], [mag_codigo], [mag_nombre], [mag_orden]) VALUES (12, N'MASA', N'Masa', 12)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Magnitud] WHERE [mag_id] = 13)
    INSERT INTO [dbo].[Magnitud] ([mag_id], [mag_codigo], [mag_nombre], [mag_orden]) VALUES (13, N'VOLUMEN', N'Volumen', 13)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Magnitud] WHERE [mag_id] = 14)
    INSERT INTO [dbo].[Magnitud] ([mag_id], [mag_codigo], [mag_nombre], [mag_orden]) VALUES (14, N'POTENCIA', N'Potencia', 14)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Magnitud] WHERE [mag_id] = 15)
    INSERT INTO [dbo].[Magnitud] ([mag_id], [mag_codigo], [mag_nombre], [mag_orden]) VALUES (15, N'ADIMENSIONAL', N'Adimensional', 15)
SET IDENTITY_INSERT [dbo].[Magnitud] OFF
GO

-- Moneda (mon) — Monedas admitidas
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Moneda]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Moneda]
    (
        [mon_id]                      INT             NOT NULL IDENTITY(1,1),
        [mon_codigo]                  NVARCHAR(50)    NOT NULL,
        [mon_nombre]                  NVARCHAR(100)   NOT NULL,
        [mon_orden]                   INT             NULL,
        [mon_habilitado]              BIT             NOT NULL CONSTRAINT DF_MON_HABILITADO DEFAULT 1,

        CONSTRAINT PK_MONEDA PRIMARY KEY CLUSTERED ([mon_id] ASC),
        CONSTRAINT UX_MON_CODIGO UNIQUE ([mon_codigo])
    )

    PRINT 'Tabla Moneda creada correctamente.'
END
ELSE
    PRINT 'Tabla Moneda ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Moneda] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Moneda] WHERE [mon_id] = 1)
    INSERT INTO [dbo].[Moneda] ([mon_id], [mon_codigo], [mon_nombre], [mon_orden]) VALUES (1, N'CLP', N'Peso chileno', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Moneda] WHERE [mon_id] = 2)
    INSERT INTO [dbo].[Moneda] ([mon_id], [mon_codigo], [mon_nombre], [mon_orden]) VALUES (2, N'USD', N'Dólar estadounidense', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Moneda] WHERE [mon_id] = 3)
    INSERT INTO [dbo].[Moneda] ([mon_id], [mon_codigo], [mon_nombre], [mon_orden]) VALUES (3, N'EUR', N'Euro', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Moneda] WHERE [mon_id] = 4)
    INSERT INTO [dbo].[Moneda] ([mon_id], [mon_codigo], [mon_nombre], [mon_orden]) VALUES (4, N'UF', N'Unidad de fomento', 4)
SET IDENTITY_INSERT [dbo].[Moneda] OFF
GO

-- Criticidad_Nivel (crn) — Criticidad de activo o componente
--   FIJO: el codigo depende de estos ids  ·  visible en la app: lleva icono e imagen
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Criticidad_Nivel]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Criticidad_Nivel]
    (
        [crn_id]                      INT             NOT NULL IDENTITY(1,1),
        [crn_codigo]                  NVARCHAR(50)    NOT NULL,
        [crn_nombre]                  NVARCHAR(100)   NOT NULL,
        [crn_icono]                   NVARCHAR(50)    NULL,       -- icono del set de la app
        [crn_archivo]                 INT             NULL,       -- FK Archivo: foto real
        [crn_orden]                   INT             NULL,
        [crn_habilitado]              BIT             NOT NULL CONSTRAINT DF_CRN_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CRITICIDAD_NIVEL PRIMARY KEY CLUSTERED ([crn_id] ASC),
        CONSTRAINT UX_CRN_CODIGO UNIQUE ([crn_codigo])
    )

    PRINT 'Tabla Criticidad_Nivel creada correctamente.'
END
ELSE
    PRINT 'Tabla Criticidad_Nivel ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Criticidad_Nivel] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Criticidad_Nivel] WHERE [crn_id] = 1)
    INSERT INTO [dbo].[Criticidad_Nivel] ([crn_id], [crn_codigo], [crn_nombre], [crn_orden]) VALUES (1, N'BAJA', N'Baja', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Criticidad_Nivel] WHERE [crn_id] = 2)
    INSERT INTO [dbo].[Criticidad_Nivel] ([crn_id], [crn_codigo], [crn_nombre], [crn_orden]) VALUES (2, N'MEDIA', N'Media', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Criticidad_Nivel] WHERE [crn_id] = 3)
    INSERT INTO [dbo].[Criticidad_Nivel] ([crn_id], [crn_codigo], [crn_nombre], [crn_orden]) VALUES (3, N'ALTA', N'Alta', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Criticidad_Nivel] WHERE [crn_id] = 4)
    INSERT INTO [dbo].[Criticidad_Nivel] ([crn_id], [crn_codigo], [crn_nombre], [crn_orden]) VALUES (4, N'CRITICA', N'Crítica', 4)
SET IDENTITY_INSERT [dbo].[Criticidad_Nivel] OFF
GO

-- Momento_Ejecucion (moe) — Momento en que se ejecuta un checklist dentro de un trabajo
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Momento_Ejecucion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Momento_Ejecucion]
    (
        [moe_id]                      INT             NOT NULL IDENTITY(1,1),
        [moe_codigo]                  NVARCHAR(50)    NOT NULL,
        [moe_nombre]                  NVARCHAR(100)   NOT NULL,
        [moe_orden]                   INT             NULL,
        [moe_habilitado]              BIT             NOT NULL CONSTRAINT DF_MOE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_MOMENTO_EJECUCION PRIMARY KEY CLUSTERED ([moe_id] ASC),
        CONSTRAINT UX_MOE_CODIGO UNIQUE ([moe_codigo])
    )

    PRINT 'Tabla Momento_Ejecucion creada correctamente.'
END
ELSE
    PRINT 'Tabla Momento_Ejecucion ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Momento_Ejecucion] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Momento_Ejecucion] WHERE [moe_id] = 1)
    INSERT INTO [dbo].[Momento_Ejecucion] ([moe_id], [moe_codigo], [moe_nombre], [moe_orden]) VALUES (1, N'ANTES', N'Antes', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Momento_Ejecucion] WHERE [moe_id] = 2)
    INSERT INTO [dbo].[Momento_Ejecucion] ([moe_id], [moe_codigo], [moe_nombre], [moe_orden]) VALUES (2, N'DURANTE', N'Durante', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Momento_Ejecucion] WHERE [moe_id] = 3)
    INSERT INTO [dbo].[Momento_Ejecucion] ([moe_id], [moe_codigo], [moe_nombre], [moe_orden]) VALUES (3, N'DESPUES', N'Después', 3)
SET IDENTITY_INSERT [dbo].[Momento_Ejecucion] OFF
GO

-- Proceso_Estado (pes) — Estado de un proceso asincrono (transcripcion, vision, entrenamiento, importacion)
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Proceso_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Proceso_Estado]
    (
        [pes_id]                      INT             NOT NULL IDENTITY(1,1),
        [pes_codigo]                  NVARCHAR(50)    NOT NULL,
        [pes_nombre]                  NVARCHAR(100)   NOT NULL,
        [pes_orden]                   INT             NULL,
        [pes_habilitado]              BIT             NOT NULL CONSTRAINT DF_PES_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PROCESO_ESTADO PRIMARY KEY CLUSTERED ([pes_id] ASC),
        CONSTRAINT UX_PES_CODIGO UNIQUE ([pes_codigo])
    )

    PRINT 'Tabla Proceso_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Proceso_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Proceso_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Proceso_Estado] WHERE [pes_id] = 1)
    INSERT INTO [dbo].[Proceso_Estado] ([pes_id], [pes_codigo], [pes_nombre], [pes_orden]) VALUES (1, N'PENDIENTE', N'Pendiente', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Proceso_Estado] WHERE [pes_id] = 2)
    INSERT INTO [dbo].[Proceso_Estado] ([pes_id], [pes_codigo], [pes_nombre], [pes_orden]) VALUES (2, N'EN PROCESO', N'En proceso', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Proceso_Estado] WHERE [pes_id] = 3)
    INSERT INTO [dbo].[Proceso_Estado] ([pes_id], [pes_codigo], [pes_nombre], [pes_orden]) VALUES (3, N'PROCESADO', N'Procesado', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Proceso_Estado] WHERE [pes_id] = 4)
    INSERT INTO [dbo].[Proceso_Estado] ([pes_id], [pes_codigo], [pes_nombre], [pes_orden]) VALUES (4, N'ERROR', N'Error', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Proceso_Estado] WHERE [pes_id] = 5)
    INSERT INTO [dbo].[Proceso_Estado] ([pes_id], [pes_codigo], [pes_nombre], [pes_orden]) VALUES (5, N'CANCELADO', N'Cancelado', 5)
SET IDENTITY_INSERT [dbo].[Proceso_Estado] OFF
GO

/* ========================================================================
   ORGANIZACIÓN Y SEGURIDAD
   ======================================================================== */

-- Instalacion_Area_Tipo (iat) — Tipo de area dentro de una planta
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Instalacion_Area_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Instalacion_Area_Tipo]
    (
        [iat_id]                      INT             NOT NULL IDENTITY(1,1),
        [iat_codigo]                  NVARCHAR(50)    NOT NULL,
        [iat_nombre]                  NVARCHAR(100)   NOT NULL,
        [iat_orden]                   INT             NULL,
        [iat_habilitado]              BIT             NOT NULL CONSTRAINT DF_IAT_HABILITADO DEFAULT 1,

        CONSTRAINT PK_INSTALACION_AREA_TIPO PRIMARY KEY CLUSTERED ([iat_id] ASC),
        CONSTRAINT UX_IAT_CODIGO UNIQUE ([iat_codigo])
    )

    PRINT 'Tabla Instalacion_Area_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Instalacion_Area_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Instalacion_Area_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area_Tipo] WHERE [iat_id] = 1)
    INSERT INTO [dbo].[Instalacion_Area_Tipo] ([iat_id], [iat_codigo], [iat_nombre], [iat_orden]) VALUES (1, N'AREA', N'Área', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area_Tipo] WHERE [iat_id] = 2)
    INSERT INTO [dbo].[Instalacion_Area_Tipo] ([iat_id], [iat_codigo], [iat_nombre], [iat_orden]) VALUES (2, N'SUBAREA', N'Subárea', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area_Tipo] WHERE [iat_id] = 3)
    INSERT INTO [dbo].[Instalacion_Area_Tipo] ([iat_id], [iat_codigo], [iat_nombre], [iat_orden]) VALUES (3, N'LINEA PRODUCCION', N'Línea de producción', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area_Tipo] WHERE [iat_id] = 4)
    INSERT INTO [dbo].[Instalacion_Area_Tipo] ([iat_id], [iat_codigo], [iat_nombre], [iat_orden]) VALUES (4, N'SALA', N'Sala', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area_Tipo] WHERE [iat_id] = 5)
    INSERT INTO [dbo].[Instalacion_Area_Tipo] ([iat_id], [iat_codigo], [iat_nombre], [iat_orden]) VALUES (5, N'ZONA EXTERIOR', N'Zona exterior', 5)
SET IDENTITY_INSERT [dbo].[Instalacion_Area_Tipo] OFF
GO

-- Especialidad_Nivel (enl) — Nivel de dominio de una especialidad
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Especialidad_Nivel]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Especialidad_Nivel]
    (
        [enl_id]                      INT             NOT NULL IDENTITY(1,1),
        [enl_codigo]                  NVARCHAR(50)    NOT NULL,
        [enl_nombre]                  NVARCHAR(100)   NOT NULL,
        [enl_orden]                   INT             NULL,
        [enl_habilitado]              BIT             NOT NULL CONSTRAINT DF_ENL_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ESPECIALIDAD_NIVEL PRIMARY KEY CLUSTERED ([enl_id] ASC),
        CONSTRAINT UX_ENL_CODIGO UNIQUE ([enl_codigo])
    )

    PRINT 'Tabla Especialidad_Nivel creada correctamente.'
END
ELSE
    PRINT 'Tabla Especialidad_Nivel ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Especialidad_Nivel] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Especialidad_Nivel] WHERE [enl_id] = 1)
    INSERT INTO [dbo].[Especialidad_Nivel] ([enl_id], [enl_codigo], [enl_nombre], [enl_orden]) VALUES (1, N'BASICO', N'Básico', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Especialidad_Nivel] WHERE [enl_id] = 2)
    INSERT INTO [dbo].[Especialidad_Nivel] ([enl_id], [enl_codigo], [enl_nombre], [enl_orden]) VALUES (2, N'INTERMEDIO', N'Intermedio', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Especialidad_Nivel] WHERE [enl_id] = 3)
    INSERT INTO [dbo].[Especialidad_Nivel] ([enl_id], [enl_codigo], [enl_nombre], [enl_orden]) VALUES (3, N'EXPERTO', N'Experto', 3)
SET IDENTITY_INSERT [dbo].[Especialidad_Nivel] OFF
GO

-- Especialidad (esp) — Especialidades tecnicas (globales; el cliente puede agregar)
--   AMPLIABLE por cliente
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Especialidad]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Especialidad]
    (
        [esp_id]                      INT             NOT NULL IDENTITY(1,1),
        [esp_cliente]                 INT             NULL,       -- NULL = global SIGMA
        [esp_codigo]                  NVARCHAR(50)    NOT NULL,
        [esp_nombre]                  NVARCHAR(100)   NOT NULL,
        [esp_orden]                   INT             NULL,
        [esp_usuario_creacion]        INT             NULL,
        [esp_fecha_creacion]          DATETIME        NULL CONSTRAINT DF_ESP_FECHA_CREACION DEFAULT GETDATE(),
        [esp_usuario_actualizacion]   INT             NULL,
        [esp_fecha_actualizacion]     DATETIME        NULL,
        [esp_habilitado]              BIT             NOT NULL CONSTRAINT DF_ESP_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ESPECIALIDAD PRIMARY KEY CLUSTERED ([esp_id] ASC),
        CONSTRAINT FK_ESP_CLIENTE FOREIGN KEY ([esp_cliente]) REFERENCES [dbo].[Cliente] ([cli_id])
    )

    -- El codigo es unico dentro del cliente; las globales van con cliente NULL.
    CREATE UNIQUE NONCLUSTERED INDEX UX_ESP_CLIENTE_CODIGO
        ON [dbo].[Especialidad] ([esp_cliente], [esp_codigo])

    PRINT 'Tabla Especialidad creada correctamente.'
END
ELSE
    PRINT 'Tabla Especialidad ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Especialidad] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Especialidad] WHERE [esp_id] = 1)
    INSERT INTO [dbo].[Especialidad] ([esp_id], [esp_codigo], [esp_nombre], [esp_orden]) VALUES (1, N'MECANICO', N'Mecánico', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Especialidad] WHERE [esp_id] = 2)
    INSERT INTO [dbo].[Especialidad] ([esp_id], [esp_codigo], [esp_nombre], [esp_orden]) VALUES (2, N'ELECTRICO', N'Eléctrico', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Especialidad] WHERE [esp_id] = 3)
    INSERT INTO [dbo].[Especialidad] ([esp_id], [esp_codigo], [esp_nombre], [esp_orden]) VALUES (3, N'ELECTROMECANICO', N'Electromecánico', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Especialidad] WHERE [esp_id] = 4)
    INSERT INTO [dbo].[Especialidad] ([esp_id], [esp_codigo], [esp_nombre], [esp_orden]) VALUES (4, N'INSTRUMENTISTA', N'Instrumentista', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Especialidad] WHERE [esp_id] = 5)
    INSERT INTO [dbo].[Especialidad] ([esp_id], [esp_codigo], [esp_nombre], [esp_orden]) VALUES (5, N'REFRIGERACION', N'Refrigeración', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Especialidad] WHERE [esp_id] = 6)
    INSERT INTO [dbo].[Especialidad] ([esp_id], [esp_codigo], [esp_nombre], [esp_orden]) VALUES (6, N'LIMPIEZA', N'Limpieza', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Especialidad] WHERE [esp_id] = 7)
    INSERT INTO [dbo].[Especialidad] ([esp_id], [esp_codigo], [esp_nombre], [esp_orden]) VALUES (7, N'INFRAESTRUCTURA', N'Infraestructura', 7)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Especialidad] WHERE [esp_id] = 8)
    INSERT INTO [dbo].[Especialidad] ([esp_id], [esp_codigo], [esp_nombre], [esp_orden]) VALUES (8, N'SOLDADURA', N'Soldadura', 8)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Especialidad] WHERE [esp_id] = 9)
    INSERT INTO [dbo].[Especialidad] ([esp_id], [esp_codigo], [esp_nombre], [esp_orden]) VALUES (9, N'AUTOMATIZACION', N'Automatización', 9)
SET IDENTITY_INSERT [dbo].[Especialidad] OFF
GO

-- Permiso_Ambito (pam) — Donde aplica un permiso
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Permiso_Ambito]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Permiso_Ambito]
    (
        [pam_id]                      INT             NOT NULL IDENTITY(1,1),
        [pam_codigo]                  NVARCHAR(50)    NOT NULL,
        [pam_nombre]                  NVARCHAR(100)   NOT NULL,
        [pam_orden]                   INT             NULL,
        [pam_habilitado]              BIT             NOT NULL CONSTRAINT DF_PAM_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PERMISO_AMBITO PRIMARY KEY CLUSTERED ([pam_id] ASC),
        CONSTRAINT UX_PAM_CODIGO UNIQUE ([pam_codigo])
    )

    PRINT 'Tabla Permiso_Ambito creada correctamente.'
END
ELSE
    PRINT 'Tabla Permiso_Ambito ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Permiso_Ambito] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Ambito] WHERE [pam_id] = 1)
    INSERT INTO [dbo].[Permiso_Ambito] ([pam_id], [pam_codigo], [pam_nombre], [pam_orden]) VALUES (1, N'WEB', N'Web administrativo', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Ambito] WHERE [pam_id] = 2)
    INSERT INTO [dbo].[Permiso_Ambito] ([pam_id], [pam_codigo], [pam_nombre], [pam_orden]) VALUES (2, N'APP', N'Aplicación móvil', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Ambito] WHERE [pam_id] = 3)
    INSERT INTO [dbo].[Permiso_Ambito] ([pam_id], [pam_codigo], [pam_nombre], [pam_orden]) VALUES (3, N'AMBOS', N'Web y móvil', 3)
SET IDENTITY_INSERT [dbo].[Permiso_Ambito] OFF
GO

/* ========================================================================
   ACTIVOS Y MEDICIONES
   ======================================================================== */

-- Activo_Estado (aes) — Estado operacional de una maquina
--   FIJO: el codigo depende de estos ids  ·  visible en la app: lleva icono e imagen
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Estado]
    (
        [aes_id]                      INT             NOT NULL IDENTITY(1,1),
        [aes_codigo]                  NVARCHAR(50)    NOT NULL,
        [aes_nombre]                  NVARCHAR(100)   NOT NULL,
        [aes_icono]                   NVARCHAR(50)    NULL,       -- icono del set de la app
        [aes_archivo]                 INT             NULL,       -- FK Archivo: foto real
        [aes_orden]                   INT             NULL,
        [aes_habilitado]              BIT             NOT NULL CONSTRAINT DF_AES_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ACTIVO_ESTADO PRIMARY KEY CLUSTERED ([aes_id] ASC),
        CONSTRAINT UX_AES_CODIGO UNIQUE ([aes_codigo])
    )

    PRINT 'Tabla Activo_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Activo_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Activo_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Estado] WHERE [aes_id] = 1)
    INSERT INTO [dbo].[Activo_Estado] ([aes_id], [aes_codigo], [aes_nombre], [aes_orden]) VALUES (1, N'OPERATIVO', N'Operativo', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Estado] WHERE [aes_id] = 2)
    INSERT INTO [dbo].[Activo_Estado] ([aes_id], [aes_codigo], [aes_nombre], [aes_orden]) VALUES (2, N'OPERATIVO CON OBSERVACION', N'Operativo con observación', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Estado] WHERE [aes_id] = 3)
    INSERT INTO [dbo].[Activo_Estado] ([aes_id], [aes_codigo], [aes_nombre], [aes_orden]) VALUES (3, N'DETENIDO', N'Detenido', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Estado] WHERE [aes_id] = 4)
    INSERT INTO [dbo].[Activo_Estado] ([aes_id], [aes_codigo], [aes_nombre], [aes_orden]) VALUES (4, N'EN MANTENIMIENTO', N'En mantenimiento', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Estado] WHERE [aes_id] = 5)
    INSERT INTO [dbo].[Activo_Estado] ([aes_id], [aes_codigo], [aes_nombre], [aes_orden]) VALUES (5, N'FUERA DE SERVICIO', N'Fuera de servicio', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Estado] WHERE [aes_id] = 6)
    INSERT INTO [dbo].[Activo_Estado] ([aes_id], [aes_codigo], [aes_nombre], [aes_orden]) VALUES (6, N'DADO DE BAJA', N'Dado de baja', 6)
SET IDENTITY_INSERT [dbo].[Activo_Estado] OFF
GO

-- Activo_Componente_Estado (ace) — Estado de un componente
--   FIJO: el codigo depende de estos ids  ·  visible en la app: lleva icono e imagen
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Componente_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Componente_Estado]
    (
        [ace_id]                      INT             NOT NULL IDENTITY(1,1),
        [ace_codigo]                  NVARCHAR(50)    NOT NULL,
        [ace_nombre]                  NVARCHAR(100)   NOT NULL,
        [ace_icono]                   NVARCHAR(50)    NULL,       -- icono del set de la app
        [ace_archivo]                 INT             NULL,       -- FK Archivo: foto real
        [ace_orden]                   INT             NULL,
        [ace_habilitado]              BIT             NOT NULL CONSTRAINT DF_ACE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ACTIVO_COMPONENTE_ESTADO PRIMARY KEY CLUSTERED ([ace_id] ASC),
        CONSTRAINT UX_ACE_CODIGO UNIQUE ([ace_codigo])
    )

    PRINT 'Tabla Activo_Componente_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Activo_Componente_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Activo_Componente_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente_Estado] WHERE [ace_id] = 1)
    INSERT INTO [dbo].[Activo_Componente_Estado] ([ace_id], [ace_codigo], [ace_nombre], [ace_orden]) VALUES (1, N'OPERATIVO', N'Operativo', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente_Estado] WHERE [ace_id] = 2)
    INSERT INTO [dbo].[Activo_Componente_Estado] ([ace_id], [ace_codigo], [ace_nombre], [ace_orden]) VALUES (2, N'CON OBSERVACION', N'Con observación', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente_Estado] WHERE [ace_id] = 3)
    INSERT INTO [dbo].[Activo_Componente_Estado] ([ace_id], [ace_codigo], [ace_nombre], [ace_orden]) VALUES (3, N'DEGRADADO', N'Degradado', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente_Estado] WHERE [ace_id] = 4)
    INSERT INTO [dbo].[Activo_Componente_Estado] ([ace_id], [ace_codigo], [ace_nombre], [ace_orden]) VALUES (4, N'FUERA DE SERVICIO', N'Fuera de servicio', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente_Estado] WHERE [ace_id] = 5)
    INSERT INTO [dbo].[Activo_Componente_Estado] ([ace_id], [ace_codigo], [ace_nombre], [ace_orden]) VALUES (5, N'RETIRADO', N'Retirado', 5)
SET IDENTITY_INSERT [dbo].[Activo_Componente_Estado] OFF
GO

-- Componente_Tipo (cto) — Tipo de componente mantenible
--   AMPLIABLE por cliente  ·  visible en la app: lleva icono e imagen
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Componente_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Componente_Tipo]
    (
        [cto_id]                      INT             NOT NULL IDENTITY(1,1),
        [cto_cliente]                 INT             NULL,       -- NULL = global SIGMA
        [cto_codigo]                  NVARCHAR(50)    NOT NULL,
        [cto_nombre]                  NVARCHAR(100)   NOT NULL,
        [cto_icono]                   NVARCHAR(50)    NULL,       -- icono del set de la app
        [cto_archivo]                 INT             NULL,       -- FK Archivo: foto real
        [cto_orden]                   INT             NULL,
        [cto_usuario_creacion]        INT             NULL,
        [cto_fecha_creacion]          DATETIME        NULL CONSTRAINT DF_CTO_FECHA_CREACION DEFAULT GETDATE(),
        [cto_usuario_actualizacion]   INT             NULL,
        [cto_fecha_actualizacion]     DATETIME        NULL,
        [cto_habilitado]              BIT             NOT NULL CONSTRAINT DF_CTO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_COMPONENTE_TIPO PRIMARY KEY CLUSTERED ([cto_id] ASC),
        CONSTRAINT FK_CTO_CLIENTE FOREIGN KEY ([cto_cliente]) REFERENCES [dbo].[Cliente] ([cli_id])
    )

    -- El codigo es unico dentro del cliente; las globales van con cliente NULL.
    CREATE UNIQUE NONCLUSTERED INDEX UX_CTO_CLIENTE_CODIGO
        ON [dbo].[Componente_Tipo] ([cto_cliente], [cto_codigo])

    PRINT 'Tabla Componente_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Componente_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Componente_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Tipo] WHERE [cto_id] = 1)
    INSERT INTO [dbo].[Componente_Tipo] ([cto_id], [cto_codigo], [cto_nombre], [cto_orden]) VALUES (1, N'MOTOR', N'Motor', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Tipo] WHERE [cto_id] = 2)
    INSERT INTO [dbo].[Componente_Tipo] ([cto_id], [cto_codigo], [cto_nombre], [cto_orden]) VALUES (2, N'REDUCTOR', N'Reductor', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Tipo] WHERE [cto_id] = 3)
    INSERT INTO [dbo].[Componente_Tipo] ([cto_id], [cto_codigo], [cto_nombre], [cto_orden]) VALUES (3, N'RODAMIENTO', N'Rodamiento', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Tipo] WHERE [cto_id] = 4)
    INSERT INTO [dbo].[Componente_Tipo] ([cto_id], [cto_codigo], [cto_nombre], [cto_orden]) VALUES (4, N'ACOPLE', N'Acople', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Tipo] WHERE [cto_id] = 5)
    INSERT INTO [dbo].[Componente_Tipo] ([cto_id], [cto_codigo], [cto_nombre], [cto_orden]) VALUES (5, N'CORREA', N'Correa', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Tipo] WHERE [cto_id] = 6)
    INSERT INTO [dbo].[Componente_Tipo] ([cto_id], [cto_codigo], [cto_nombre], [cto_orden]) VALUES (6, N'CADENA', N'Cadena', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Tipo] WHERE [cto_id] = 7)
    INSERT INTO [dbo].[Componente_Tipo] ([cto_id], [cto_codigo], [cto_nombre], [cto_orden]) VALUES (7, N'BOMBA', N'Bomba', 7)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Tipo] WHERE [cto_id] = 8)
    INSERT INTO [dbo].[Componente_Tipo] ([cto_id], [cto_codigo], [cto_nombre], [cto_orden]) VALUES (8, N'VALVULA', N'Válvula', 8)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Tipo] WHERE [cto_id] = 9)
    INSERT INTO [dbo].[Componente_Tipo] ([cto_id], [cto_codigo], [cto_nombre], [cto_orden]) VALUES (9, N'SENSOR', N'Sensor', 9)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Tipo] WHERE [cto_id] = 10)
    INSERT INTO [dbo].[Componente_Tipo] ([cto_id], [cto_codigo], [cto_nombre], [cto_orden]) VALUES (10, N'TABLERO', N'Tablero', 10)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Tipo] WHERE [cto_id] = 11)
    INSERT INTO [dbo].[Componente_Tipo] ([cto_id], [cto_codigo], [cto_nombre], [cto_orden]) VALUES (11, N'FILTRO', N'Filtro', 11)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Tipo] WHERE [cto_id] = 12)
    INSERT INTO [dbo].[Componente_Tipo] ([cto_id], [cto_codigo], [cto_nombre], [cto_orden]) VALUES (12, N'RETEN', N'Retén', 12)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Tipo] WHERE [cto_id] = 13)
    INSERT INTO [dbo].[Componente_Tipo] ([cto_id], [cto_codigo], [cto_nombre], [cto_orden]) VALUES (13, N'POLEA', N'Polea', 13)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Tipo] WHERE [cto_id] = 14)
    INSERT INTO [dbo].[Componente_Tipo] ([cto_id], [cto_codigo], [cto_nombre], [cto_orden]) VALUES (14, N'OTRO', N'Otro', 14)
SET IDENTITY_INSERT [dbo].[Componente_Tipo] OFF
GO

-- Componente_Posicion (cpn) — Posicion fisica del componente dentro del activo
--   AMPLIABLE por cliente  ·  visible en la app: lleva icono e imagen
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Componente_Posicion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Componente_Posicion]
    (
        [cpn_id]                      INT             NOT NULL IDENTITY(1,1),
        [cpn_cliente]                 INT             NULL,       -- NULL = global SIGMA
        [cpn_codigo]                  NVARCHAR(50)    NOT NULL,
        [cpn_nombre]                  NVARCHAR(100)   NOT NULL,
        [cpn_icono]                   NVARCHAR(50)    NULL,       -- icono del set de la app
        [cpn_archivo]                 INT             NULL,       -- FK Archivo: foto real
        [cpn_orden]                   INT             NULL,
        [cpn_usuario_creacion]        INT             NULL,
        [cpn_fecha_creacion]          DATETIME        NULL CONSTRAINT DF_CPN_FECHA_CREACION DEFAULT GETDATE(),
        [cpn_usuario_actualizacion]   INT             NULL,
        [cpn_fecha_actualizacion]     DATETIME        NULL,
        [cpn_habilitado]              BIT             NOT NULL CONSTRAINT DF_CPN_HABILITADO DEFAULT 1,

        CONSTRAINT PK_COMPONENTE_POSICION PRIMARY KEY CLUSTERED ([cpn_id] ASC),
        CONSTRAINT FK_CPN_CLIENTE FOREIGN KEY ([cpn_cliente]) REFERENCES [dbo].[Cliente] ([cli_id])
    )

    -- El codigo es unico dentro del cliente; las globales van con cliente NULL.
    CREATE UNIQUE NONCLUSTERED INDEX UX_CPN_CLIENTE_CODIGO
        ON [dbo].[Componente_Posicion] ([cpn_cliente], [cpn_codigo])

    PRINT 'Tabla Componente_Posicion creada correctamente.'
END
ELSE
    PRINT 'Tabla Componente_Posicion ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Componente_Posicion] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Posicion] WHERE [cpn_id] = 1)
    INSERT INTO [dbo].[Componente_Posicion] ([cpn_id], [cpn_codigo], [cpn_nombre], [cpn_orden]) VALUES (1, N'LADO A', N'Lado A', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Posicion] WHERE [cpn_id] = 2)
    INSERT INTO [dbo].[Componente_Posicion] ([cpn_id], [cpn_codigo], [cpn_nombre], [cpn_orden]) VALUES (2, N'LADO B', N'Lado B', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Posicion] WHERE [cpn_id] = 3)
    INSERT INTO [dbo].[Componente_Posicion] ([cpn_id], [cpn_codigo], [cpn_nombre], [cpn_orden]) VALUES (3, N'LADO MOTOR', N'Lado motor', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Posicion] WHERE [cpn_id] = 4)
    INSERT INTO [dbo].[Componente_Posicion] ([cpn_id], [cpn_codigo], [cpn_nombre], [cpn_orden]) VALUES (4, N'LADO ACOPLE', N'Lado acople', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Posicion] WHERE [cpn_id] = 5)
    INSERT INTO [dbo].[Componente_Posicion] ([cpn_id], [cpn_codigo], [cpn_nombre], [cpn_orden]) VALUES (5, N'ENTRADA', N'Entrada', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Posicion] WHERE [cpn_id] = 6)
    INSERT INTO [dbo].[Componente_Posicion] ([cpn_id], [cpn_codigo], [cpn_nombre], [cpn_orden]) VALUES (6, N'SALIDA', N'Salida', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Posicion] WHERE [cpn_id] = 7)
    INSERT INTO [dbo].[Componente_Posicion] ([cpn_id], [cpn_codigo], [cpn_nombre], [cpn_orden]) VALUES (7, N'SUPERIOR', N'Superior', 7)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Posicion] WHERE [cpn_id] = 8)
    INSERT INTO [dbo].[Componente_Posicion] ([cpn_id], [cpn_codigo], [cpn_nombre], [cpn_orden]) VALUES (8, N'INFERIOR', N'Inferior', 8)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Posicion] WHERE [cpn_id] = 9)
    INSERT INTO [dbo].[Componente_Posicion] ([cpn_id], [cpn_codigo], [cpn_nombre], [cpn_orden]) VALUES (9, N'IZQUIERDA', N'Izquierda', 9)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Posicion] WHERE [cpn_id] = 10)
    INSERT INTO [dbo].[Componente_Posicion] ([cpn_id], [cpn_codigo], [cpn_nombre], [cpn_orden]) VALUES (10, N'DERECHA', N'Derecha', 10)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Posicion] WHERE [cpn_id] = 11)
    INSERT INTO [dbo].[Componente_Posicion] ([cpn_id], [cpn_codigo], [cpn_nombre], [cpn_orden]) VALUES (11, N'DELANTERO', N'Delantero', 11)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Posicion] WHERE [cpn_id] = 12)
    INSERT INTO [dbo].[Componente_Posicion] ([cpn_id], [cpn_codigo], [cpn_nombre], [cpn_orden]) VALUES (12, N'TRASERO', N'Trasero', 12)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Posicion] WHERE [cpn_id] = 13)
    INSERT INTO [dbo].[Componente_Posicion] ([cpn_id], [cpn_codigo], [cpn_nombre], [cpn_orden]) VALUES (13, N'CENTRAL', N'Central', 13)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Componente_Posicion] WHERE [cpn_id] = 14)
    INSERT INTO [dbo].[Componente_Posicion] ([cpn_id], [cpn_codigo], [cpn_nombre], [cpn_orden]) VALUES (14, N'UNICO', N'Único', 14)
SET IDENTITY_INSERT [dbo].[Componente_Posicion] OFF
GO

-- Activo_Posicion_Motivo (apm) — Motivo de ocupacion o liberacion de una posicion funcional
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Posicion_Motivo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Activo_Posicion_Motivo]
    (
        [apm_id]                      INT             NOT NULL IDENTITY(1,1),
        [apm_codigo]                  NVARCHAR(50)    NOT NULL,
        [apm_nombre]                  NVARCHAR(100)   NOT NULL,
        [apm_orden]                   INT             NULL,
        [apm_habilitado]              BIT             NOT NULL CONSTRAINT DF_APM_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ACTIVO_POSICION_MOTIVO PRIMARY KEY CLUSTERED ([apm_id] ASC),
        CONSTRAINT UX_APM_CODIGO UNIQUE ([apm_codigo])
    )

    PRINT 'Tabla Activo_Posicion_Motivo creada correctamente.'
END
ELSE
    PRINT 'Tabla Activo_Posicion_Motivo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Activo_Posicion_Motivo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Posicion_Motivo] WHERE [apm_id] = 1)
    INSERT INTO [dbo].[Activo_Posicion_Motivo] ([apm_id], [apm_codigo], [apm_nombre], [apm_orden]) VALUES (1, N'INSTALACION INICIAL', N'Instalación inicial', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Posicion_Motivo] WHERE [apm_id] = 2)
    INSERT INTO [dbo].[Activo_Posicion_Motivo] ([apm_id], [apm_codigo], [apm_nombre], [apm_orden]) VALUES (2, N'REEMPLAZO', N'Reemplazo', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Posicion_Motivo] WHERE [apm_id] = 3)
    INSERT INTO [dbo].[Activo_Posicion_Motivo] ([apm_id], [apm_codigo], [apm_nombre], [apm_orden]) VALUES (3, N'RESPALDO TEMPORAL', N'Respaldo temporal', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Posicion_Motivo] WHERE [apm_id] = 4)
    INSERT INTO [dbo].[Activo_Posicion_Motivo] ([apm_id], [apm_codigo], [apm_nombre], [apm_orden]) VALUES (4, N'OVERHAUL', N'Overhaul', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Posicion_Motivo] WHERE [apm_id] = 5)
    INSERT INTO [dbo].[Activo_Posicion_Motivo] ([apm_id], [apm_codigo], [apm_nombre], [apm_orden]) VALUES (5, N'BAJA', N'Baja', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Posicion_Motivo] WHERE [apm_id] = 6)
    INSERT INTO [dbo].[Activo_Posicion_Motivo] ([apm_id], [apm_codigo], [apm_nombre], [apm_orden]) VALUES (6, N'TRASLADO', N'Traslado', 6)
SET IDENTITY_INSERT [dbo].[Activo_Posicion_Motivo] OFF
GO

-- Medicion_Calidad (mca) — Calidad de una medicion
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Medicion_Calidad]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Medicion_Calidad]
    (
        [mca_id]                      INT             NOT NULL IDENTITY(1,1),
        [mca_codigo]                  NVARCHAR(50)    NOT NULL,
        [mca_nombre]                  NVARCHAR(100)   NOT NULL,
        [mca_orden]                   INT             NULL,
        [mca_habilitado]              BIT             NOT NULL CONSTRAINT DF_MCA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_MEDICION_CALIDAD PRIMARY KEY CLUSTERED ([mca_id] ASC),
        CONSTRAINT UX_MCA_CODIGO UNIQUE ([mca_codigo])
    )

    PRINT 'Tabla Medicion_Calidad creada correctamente.'
END
ELSE
    PRINT 'Tabla Medicion_Calidad ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Medicion_Calidad] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Medicion_Calidad] WHERE [mca_id] = 1)
    INSERT INTO [dbo].[Medicion_Calidad] ([mca_id], [mca_codigo], [mca_nombre], [mca_orden]) VALUES (1, N'VALIDA', N'Válida', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Medicion_Calidad] WHERE [mca_id] = 2)
    INSERT INTO [dbo].[Medicion_Calidad] ([mca_id], [mca_codigo], [mca_nombre], [mca_orden]) VALUES (2, N'ESTIMADA', N'Estimada', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Medicion_Calidad] WHERE [mca_id] = 3)
    INSERT INTO [dbo].[Medicion_Calidad] ([mca_id], [mca_codigo], [mca_nombre], [mca_orden]) VALUES (3, N'CORREGIDA', N'Corregida', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Medicion_Calidad] WHERE [mca_id] = 4)
    INSERT INTO [dbo].[Medicion_Calidad] ([mca_id], [mca_codigo], [mca_nombre], [mca_orden]) VALUES (4, N'INVALIDA', N'Inválida', 4)
SET IDENTITY_INSERT [dbo].[Medicion_Calidad] OFF
GO

-- Dato_Origen (dor) — De donde proviene un dato capturado
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Dato_Origen]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Dato_Origen]
    (
        [dor_id]                      INT             NOT NULL IDENTITY(1,1),
        [dor_codigo]                  NVARCHAR(50)    NOT NULL,
        [dor_nombre]                  NVARCHAR(100)   NOT NULL,
        [dor_orden]                   INT             NULL,
        [dor_habilitado]              BIT             NOT NULL CONSTRAINT DF_DOR_HABILITADO DEFAULT 1,

        CONSTRAINT PK_DATO_ORIGEN PRIMARY KEY CLUSTERED ([dor_id] ASC),
        CONSTRAINT UX_DOR_CODIGO UNIQUE ([dor_codigo])
    )

    PRINT 'Tabla Dato_Origen creada correctamente.'
END
ELSE
    PRINT 'Tabla Dato_Origen ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Dato_Origen] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dato_Origen] WHERE [dor_id] = 1)
    INSERT INTO [dbo].[Dato_Origen] ([dor_id], [dor_codigo], [dor_nombre], [dor_orden]) VALUES (1, N'CHECKLIST', N'Checklist', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dato_Origen] WHERE [dor_id] = 2)
    INSERT INTO [dbo].[Dato_Origen] ([dor_id], [dor_codigo], [dor_nombre], [dor_orden]) VALUES (2, N'SENSOR', N'Sensor', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dato_Origen] WHERE [dor_id] = 3)
    INSERT INTO [dbo].[Dato_Origen] ([dor_id], [dor_codigo], [dor_nombre], [dor_orden]) VALUES (3, N'MANUAL', N'Ingreso manual', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dato_Origen] WHERE [dor_id] = 4)
    INSERT INTO [dbo].[Dato_Origen] ([dor_id], [dor_codigo], [dor_nombre], [dor_orden]) VALUES (4, N'ORDEN TRABAJO', N'Orden de trabajo', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dato_Origen] WHERE [dor_id] = 5)
    INSERT INTO [dbo].[Dato_Origen] ([dor_id], [dor_codigo], [dor_nombre], [dor_orden]) VALUES (5, N'IMPORTACION', N'Importación', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dato_Origen] WHERE [dor_id] = 6)
    INSERT INTO [dbo].[Dato_Origen] ([dor_id], [dor_codigo], [dor_nombre], [dor_orden]) VALUES (6, N'IA', N'Inteligencia artificial', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dato_Origen] WHERE [dor_id] = 7)
    INSERT INTO [dbo].[Dato_Origen] ([dor_id], [dor_codigo], [dor_nombre], [dor_orden]) VALUES (7, N'BITACORA', N'Bitácora', 7)
SET IDENTITY_INSERT [dbo].[Dato_Origen] OFF
GO

/* ========================================================================
   REPUESTOS E INVENTARIO
   ======================================================================== */

-- Repuesto_Retiro_Motivo (rrm) — Por que se retiro un repuesto (define el label de ML)
--   AMPLIABLE por cliente  ·  visible en la app: lleva icono e imagen
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Repuesto_Retiro_Motivo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Repuesto_Retiro_Motivo]
    (
        [rrm_id]                      INT             NOT NULL IDENTITY(1,1),
        [rrm_cliente]                 INT             NULL,       -- NULL = global SIGMA
        [rrm_codigo]                  NVARCHAR(50)    NOT NULL,
        [rrm_nombre]                  NVARCHAR(100)   NOT NULL,
        [rrm_motivo_base]             INT             NULL,       -- a que motivo global equivale
        [rrm_icono]                   NVARCHAR(50)    NULL,       -- icono del set de la app
        [rrm_archivo]                 INT             NULL,       -- FK Archivo: foto real
        [rrm_orden]                   INT             NULL,
        [rrm_usuario_creacion]        INT             NULL,
        [rrm_fecha_creacion]          DATETIME        NULL CONSTRAINT DF_RRM_FECHA_CREACION DEFAULT GETDATE(),
        [rrm_usuario_actualizacion]   INT             NULL,
        [rrm_fecha_actualizacion]     DATETIME        NULL,
        [rrm_habilitado]              BIT             NOT NULL CONSTRAINT DF_RRM_HABILITADO DEFAULT 1,

        CONSTRAINT PK_REPUESTO_RETIRO_MOTIVO PRIMARY KEY CLUSTERED ([rrm_id] ASC),
        CONSTRAINT FK_RRM_CLIENTE FOREIGN KEY ([rrm_cliente]) REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_RRM_MOTIVO_BASE FOREIGN KEY ([rrm_motivo_base]) REFERENCES [dbo].[Repuesto_Retiro_Motivo] ([rrm_id]),
        CONSTRAINT CK_RRM_BASE CHECK ([rrm_cliente] IS NULL OR [rrm_motivo_base] IS NOT NULL)
    )

    -- El codigo es unico dentro del cliente; las globales van con cliente NULL.
    CREATE UNIQUE NONCLUSTERED INDEX UX_RRM_CLIENTE_CODIGO
        ON [dbo].[Repuesto_Retiro_Motivo] ([rrm_cliente], [rrm_codigo])

    PRINT 'Tabla Repuesto_Retiro_Motivo creada correctamente.'
END
ELSE
    PRINT 'Tabla Repuesto_Retiro_Motivo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Repuesto_Retiro_Motivo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Retiro_Motivo] WHERE [rrm_id] = 1)
    INSERT INTO [dbo].[Repuesto_Retiro_Motivo] ([rrm_id], [rrm_codigo], [rrm_nombre], [rrm_orden]) VALUES (1, N'FALLA', N'Falla', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Retiro_Motivo] WHERE [rrm_id] = 2)
    INSERT INTO [dbo].[Repuesto_Retiro_Motivo] ([rrm_id], [rrm_codigo], [rrm_nombre], [rrm_orden]) VALUES (2, N'DESGASTE', N'Desgaste', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Retiro_Motivo] WHERE [rrm_id] = 3)
    INSERT INTO [dbo].[Repuesto_Retiro_Motivo] ([rrm_id], [rrm_codigo], [rrm_nombre], [rrm_orden]) VALUES (3, N'PREVENTIVO', N'Reemplazo preventivo', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Retiro_Motivo] WHERE [rrm_id] = 4)
    INSERT INTO [dbo].[Repuesto_Retiro_Motivo] ([rrm_id], [rrm_codigo], [rrm_nombre], [rrm_orden]) VALUES (4, N'MEJORA', N'Mejora', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Retiro_Motivo] WHERE [rrm_id] = 5)
    INSERT INTO [dbo].[Repuesto_Retiro_Motivo] ([rrm_id], [rrm_codigo], [rrm_nombre], [rrm_orden]) VALUES (5, N'DANO EXTERNO', N'Daño externo', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Retiro_Motivo] WHERE [rrm_id] = 6)
    INSERT INTO [dbo].[Repuesto_Retiro_Motivo] ([rrm_id], [rrm_codigo], [rrm_nombre], [rrm_orden]) VALUES (6, N'OBSOLESCENCIA', N'Obsolescencia', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Retiro_Motivo] WHERE [rrm_id] = 7)
    INSERT INTO [dbo].[Repuesto_Retiro_Motivo] ([rrm_id], [rrm_codigo], [rrm_nombre], [rrm_orden]) VALUES (7, N'OTRO', N'Otro', 7)
SET IDENTITY_INSERT [dbo].[Repuesto_Retiro_Motivo] OFF
GO

-- Repuesto_Estado_Final (ref) — Condicion observada del repuesto al retirarlo
--   AMPLIABLE por cliente  ·  visible en la app: lleva icono e imagen
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Repuesto_Estado_Final]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Repuesto_Estado_Final]
    (
        [ref_id]                      INT             NOT NULL IDENTITY(1,1),
        [ref_cliente]                 INT             NULL,       -- NULL = global SIGMA
        [ref_codigo]                  NVARCHAR(50)    NOT NULL,
        [ref_nombre]                  NVARCHAR(100)   NOT NULL,
        [ref_icono]                   NVARCHAR(50)    NULL,       -- icono del set de la app
        [ref_archivo]                 INT             NULL,       -- FK Archivo: foto real
        [ref_orden]                   INT             NULL,
        [ref_usuario_creacion]        INT             NULL,
        [ref_fecha_creacion]          DATETIME        NULL CONSTRAINT DF_REF_FECHA_CREACION DEFAULT GETDATE(),
        [ref_usuario_actualizacion]   INT             NULL,
        [ref_fecha_actualizacion]     DATETIME        NULL,
        [ref_habilitado]              BIT             NOT NULL CONSTRAINT DF_REF_HABILITADO DEFAULT 1,

        CONSTRAINT PK_REPUESTO_ESTADO_FINAL PRIMARY KEY CLUSTERED ([ref_id] ASC),
        CONSTRAINT FK_REF_CLIENTE FOREIGN KEY ([ref_cliente]) REFERENCES [dbo].[Cliente] ([cli_id])
    )

    -- El codigo es unico dentro del cliente; las globales van con cliente NULL.
    CREATE UNIQUE NONCLUSTERED INDEX UX_REF_CLIENTE_CODIGO
        ON [dbo].[Repuesto_Estado_Final] ([ref_cliente], [ref_codigo])

    PRINT 'Tabla Repuesto_Estado_Final creada correctamente.'
END
ELSE
    PRINT 'Tabla Repuesto_Estado_Final ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Repuesto_Estado_Final] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Estado_Final] WHERE [ref_id] = 1)
    INSERT INTO [dbo].[Repuesto_Estado_Final] ([ref_id], [ref_codigo], [ref_nombre], [ref_orden]) VALUES (1, N'BUENO', N'Bueno', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Estado_Final] WHERE [ref_id] = 2)
    INSERT INTO [dbo].[Repuesto_Estado_Final] ([ref_id], [ref_codigo], [ref_nombre], [ref_orden]) VALUES (2, N'DESGASTE LEVE', N'Desgaste leve', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Estado_Final] WHERE [ref_id] = 3)
    INSERT INTO [dbo].[Repuesto_Estado_Final] ([ref_id], [ref_codigo], [ref_nombre], [ref_orden]) VALUES (3, N'DESGASTE MODERADO', N'Desgaste moderado', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Estado_Final] WHERE [ref_id] = 4)
    INSERT INTO [dbo].[Repuesto_Estado_Final] ([ref_id], [ref_codigo], [ref_nombre], [ref_orden]) VALUES (4, N'DESGASTE SEVERO', N'Desgaste severo', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Estado_Final] WHERE [ref_id] = 5)
    INSERT INTO [dbo].[Repuesto_Estado_Final] ([ref_id], [ref_codigo], [ref_nombre], [ref_orden]) VALUES (5, N'ROTO', N'Roto', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Estado_Final] WHERE [ref_id] = 6)
    INSERT INTO [dbo].[Repuesto_Estado_Final] ([ref_id], [ref_codigo], [ref_nombre], [ref_orden]) VALUES (6, N'CORROIDO', N'Corroído', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Estado_Final] WHERE [ref_id] = 7)
    INSERT INTO [dbo].[Repuesto_Estado_Final] ([ref_id], [ref_codigo], [ref_nombre], [ref_orden]) VALUES (7, N'NO EVALUADO', N'No evaluado', 7)
SET IDENTITY_INSERT [dbo].[Repuesto_Estado_Final] OFF
GO

-- Inventario_Movimiento_Tipo (imt) — Tipo de movimiento de inventario
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Inventario_Movimiento_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Inventario_Movimiento_Tipo]
    (
        [imt_id]                      INT             NOT NULL IDENTITY(1,1),
        [imt_codigo]                  NVARCHAR(50)    NOT NULL,
        [imt_nombre]                  NVARCHAR(100)   NOT NULL,
        [imt_orden]                   INT             NULL,
        [imt_habilitado]              BIT             NOT NULL CONSTRAINT DF_IMT_HABILITADO DEFAULT 1,

        CONSTRAINT PK_INVENTARIO_MOVIMIENTO_TIPO PRIMARY KEY CLUSTERED ([imt_id] ASC),
        CONSTRAINT UX_IMT_CODIGO UNIQUE ([imt_codigo])
    )

    PRINT 'Tabla Inventario_Movimiento_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Inventario_Movimiento_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Inventario_Movimiento_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Inventario_Movimiento_Tipo] WHERE [imt_id] = 1)
    INSERT INTO [dbo].[Inventario_Movimiento_Tipo] ([imt_id], [imt_codigo], [imt_nombre], [imt_orden]) VALUES (1, N'INGRESO COMPRA', N'Ingreso por compra', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Inventario_Movimiento_Tipo] WHERE [imt_id] = 2)
    INSERT INTO [dbo].[Inventario_Movimiento_Tipo] ([imt_id], [imt_codigo], [imt_nombre], [imt_orden]) VALUES (2, N'SALIDA CONSUMO', N'Salida por consumo', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Inventario_Movimiento_Tipo] WHERE [imt_id] = 3)
    INSERT INTO [dbo].[Inventario_Movimiento_Tipo] ([imt_id], [imt_codigo], [imt_nombre], [imt_orden]) VALUES (3, N'DEVOLUCION', N'Devolución', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Inventario_Movimiento_Tipo] WHERE [imt_id] = 4)
    INSERT INTO [dbo].[Inventario_Movimiento_Tipo] ([imt_id], [imt_codigo], [imt_nombre], [imt_orden]) VALUES (4, N'AJUSTE POSITIVO', N'Ajuste positivo', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Inventario_Movimiento_Tipo] WHERE [imt_id] = 5)
    INSERT INTO [dbo].[Inventario_Movimiento_Tipo] ([imt_id], [imt_codigo], [imt_nombre], [imt_orden]) VALUES (5, N'AJUSTE NEGATIVO', N'Ajuste negativo', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Inventario_Movimiento_Tipo] WHERE [imt_id] = 6)
    INSERT INTO [dbo].[Inventario_Movimiento_Tipo] ([imt_id], [imt_codigo], [imt_nombre], [imt_orden]) VALUES (6, N'TRASLADO SALIDA', N'Traslado de salida', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Inventario_Movimiento_Tipo] WHERE [imt_id] = 7)
    INSERT INTO [dbo].[Inventario_Movimiento_Tipo] ([imt_id], [imt_codigo], [imt_nombre], [imt_orden]) VALUES (7, N'TRASLADO INGRESO', N'Traslado de ingreso', 7)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Inventario_Movimiento_Tipo] WHERE [imt_id] = 8)
    INSERT INTO [dbo].[Inventario_Movimiento_Tipo] ([imt_id], [imt_codigo], [imt_nombre], [imt_orden]) VALUES (8, N'MERMA', N'Merma', 8)
SET IDENTITY_INSERT [dbo].[Inventario_Movimiento_Tipo] OFF
GO

/* ========================================================================
   MOTOR DE PROGRAMACIÓN
   ======================================================================== */

-- Programacion_Tipo (pti) — Como se calcula la recurrencia
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Programacion_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Programacion_Tipo]
    (
        [pti_id]                      INT             NOT NULL IDENTITY(1,1),
        [pti_codigo]                  NVARCHAR(50)    NOT NULL,
        [pti_nombre]                  NVARCHAR(100)   NOT NULL,
        [pti_orden]                   INT             NULL,
        [pti_habilitado]              BIT             NOT NULL CONSTRAINT DF_PTI_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PROGRAMACION_TIPO PRIMARY KEY CLUSTERED ([pti_id] ASC),
        CONSTRAINT UX_PTI_CODIGO UNIQUE ([pti_codigo])
    )

    PRINT 'Tabla Programacion_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Programacion_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Programacion_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion_Tipo] WHERE [pti_id] = 1)
    INSERT INTO [dbo].[Programacion_Tipo] ([pti_id], [pti_codigo], [pti_nombre], [pti_orden]) VALUES (1, N'ABIERTA', N'Abierta', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion_Tipo] WHERE [pti_id] = 2)
    INSERT INTO [dbo].[Programacion_Tipo] ([pti_id], [pti_codigo], [pti_nombre], [pti_orden]) VALUES (2, N'FECHA UNICA', N'Fecha única', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion_Tipo] WHERE [pti_id] = 3)
    INSERT INTO [dbo].[Programacion_Tipo] ([pti_id], [pti_codigo], [pti_nombre], [pti_orden]) VALUES (3, N'CALENDARIO', N'Calendario', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion_Tipo] WHERE [pti_id] = 4)
    INSERT INTO [dbo].[Programacion_Tipo] ([pti_id], [pti_codigo], [pti_nombre], [pti_orden]) VALUES (4, N'INTERVALO TIEMPO', N'Intervalo de tiempo', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion_Tipo] WHERE [pti_id] = 5)
    INSERT INTO [dbo].[Programacion_Tipo] ([pti_id], [pti_codigo], [pti_nombre], [pti_orden]) VALUES (5, N'MEDIDOR', N'Por medidor', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion_Tipo] WHERE [pti_id] = 6)
    INSERT INTO [dbo].[Programacion_Tipo] ([pti_id], [pti_codigo], [pti_nombre], [pti_orden]) VALUES (6, N'CONDICION', N'Por condición', 6)
SET IDENTITY_INSERT [dbo].[Programacion_Tipo] OFF
GO

/* ========================================================================
   PLANES DE MANTENIMIENTO
   ======================================================================== */

-- Plan_Version_Estado (pve) — Ciclo de vida de una version de plan
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Plan_Version_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Plan_Version_Estado]
    (
        [pve_id]                      INT             NOT NULL IDENTITY(1,1),
        [pve_codigo]                  NVARCHAR(50)    NOT NULL,
        [pve_nombre]                  NVARCHAR(100)   NOT NULL,
        [pve_orden]                   INT             NULL,
        [pve_habilitado]              BIT             NOT NULL CONSTRAINT DF_PVE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PLAN_VERSION_ESTADO PRIMARY KEY CLUSTERED ([pve_id] ASC),
        CONSTRAINT UX_PVE_CODIGO UNIQUE ([pve_codigo])
    )

    PRINT 'Tabla Plan_Version_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Plan_Version_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Plan_Version_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Version_Estado] WHERE [pve_id] = 1)
    INSERT INTO [dbo].[Plan_Version_Estado] ([pve_id], [pve_codigo], [pve_nombre], [pve_orden]) VALUES (1, N'BORRADOR', N'Borrador', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Version_Estado] WHERE [pve_id] = 2)
    INSERT INTO [dbo].[Plan_Version_Estado] ([pve_id], [pve_codigo], [pve_nombre], [pve_orden]) VALUES (2, N'PUBLICADO', N'Publicado', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Version_Estado] WHERE [pve_id] = 3)
    INSERT INTO [dbo].[Plan_Version_Estado] ([pve_id], [pve_codigo], [pve_nombre], [pve_orden]) VALUES (3, N'RETIRADO', N'Retirado', 3)
SET IDENTITY_INSERT [dbo].[Plan_Version_Estado] OFF
GO

-- Plan_Ocurrencia_Estado (poe) — Ciclo de vida de una ocurrencia de plan (VENCIDA se calcula)
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Plan_Ocurrencia_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Plan_Ocurrencia_Estado]
    (
        [poe_id]                      INT             NOT NULL IDENTITY(1,1),
        [poe_codigo]                  NVARCHAR(50)    NOT NULL,
        [poe_nombre]                  NVARCHAR(100)   NOT NULL,
        [poe_orden]                   INT             NULL,
        [poe_habilitado]              BIT             NOT NULL CONSTRAINT DF_POE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PLAN_OCURRENCIA_ESTADO PRIMARY KEY CLUSTERED ([poe_id] ASC),
        CONSTRAINT UX_POE_CODIGO UNIQUE ([poe_codigo])
    )

    PRINT 'Tabla Plan_Ocurrencia_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Plan_Ocurrencia_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Plan_Ocurrencia_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Ocurrencia_Estado] WHERE [poe_id] = 1)
    INSERT INTO [dbo].[Plan_Ocurrencia_Estado] ([poe_id], [poe_codigo], [poe_nombre], [poe_orden]) VALUES (1, N'PENDIENTE', N'Pendiente', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Ocurrencia_Estado] WHERE [poe_id] = 2)
    INSERT INTO [dbo].[Plan_Ocurrencia_Estado] ([poe_id], [poe_codigo], [poe_nombre], [poe_orden]) VALUES (2, N'DISPONIBLE', N'Disponible', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Ocurrencia_Estado] WHERE [poe_id] = 3)
    INSERT INTO [dbo].[Plan_Ocurrencia_Estado] ([poe_id], [poe_codigo], [poe_nombre], [poe_orden]) VALUES (3, N'EN EJECUCION', N'En ejecución', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Ocurrencia_Estado] WHERE [poe_id] = 4)
    INSERT INTO [dbo].[Plan_Ocurrencia_Estado] ([poe_id], [poe_codigo], [poe_nombre], [poe_orden]) VALUES (4, N'COMPLETADA', N'Completada', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Ocurrencia_Estado] WHERE [poe_id] = 5)
    INSERT INTO [dbo].[Plan_Ocurrencia_Estado] ([poe_id], [poe_codigo], [poe_nombre], [poe_orden]) VALUES (5, N'OMITIDA', N'Omitida', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Ocurrencia_Estado] WHERE [poe_id] = 6)
    INSERT INTO [dbo].[Plan_Ocurrencia_Estado] ([poe_id], [poe_codigo], [poe_nombre], [poe_orden]) VALUES (6, N'CANCELADA', N'Cancelada', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Ocurrencia_Estado] WHERE [poe_id] = 7)
    INSERT INTO [dbo].[Plan_Ocurrencia_Estado] ([poe_id], [poe_codigo], [poe_nombre], [poe_orden]) VALUES (7, N'REPROGRAMADA', N'Reprogramada', 7)
SET IDENTITY_INSERT [dbo].[Plan_Ocurrencia_Estado] OFF
GO

/* ========================================================================
   CHECKLIST
   ======================================================================== */

-- Checklist_Version_Estado (cve) — Ciclo de vida de una version de plantilla
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Version_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Version_Estado]
    (
        [cve_id]                      INT             NOT NULL IDENTITY(1,1),
        [cve_codigo]                  NVARCHAR(50)    NOT NULL,
        [cve_nombre]                  NVARCHAR(100)   NOT NULL,
        [cve_orden]                   INT             NULL,
        [cve_habilitado]              BIT             NOT NULL CONSTRAINT DF_CVE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_VERSION_ESTADO PRIMARY KEY CLUSTERED ([cve_id] ASC),
        CONSTRAINT UX_CVE_CODIGO UNIQUE ([cve_codigo])
    )

    PRINT 'Tabla Checklist_Version_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Checklist_Version_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Checklist_Version_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Version_Estado] WHERE [cve_id] = 1)
    INSERT INTO [dbo].[Checklist_Version_Estado] ([cve_id], [cve_codigo], [cve_nombre], [cve_orden]) VALUES (1, N'BORRADOR', N'Borrador', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Version_Estado] WHERE [cve_id] = 2)
    INSERT INTO [dbo].[Checklist_Version_Estado] ([cve_id], [cve_codigo], [cve_nombre], [cve_orden]) VALUES (2, N'PUBLICADO', N'Publicado', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Version_Estado] WHERE [cve_id] = 3)
    INSERT INTO [dbo].[Checklist_Version_Estado] ([cve_id], [cve_codigo], [cve_nombre], [cve_orden]) VALUES (3, N'RETIRADO', N'Retirado', 3)
SET IDENTITY_INSERT [dbo].[Checklist_Version_Estado] OFF
GO

-- Checklist_Item_Tipo (cit) — Tipo de item de un checklist
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Item_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Item_Tipo]
    (
        [cit_id]                      INT             NOT NULL IDENTITY(1,1),
        [cit_codigo]                  NVARCHAR(50)    NOT NULL,
        [cit_nombre]                  NVARCHAR(100)   NOT NULL,
        [cit_orden]                   INT             NULL,
        [cit_habilitado]              BIT             NOT NULL CONSTRAINT DF_CIT_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_ITEM_TIPO PRIMARY KEY CLUSTERED ([cit_id] ASC),
        CONSTRAINT UX_CIT_CODIGO UNIQUE ([cit_codigo])
    )

    PRINT 'Tabla Checklist_Item_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Checklist_Item_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Checklist_Item_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 1)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (1, N'TEXTO CORTO', N'Texto corto', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 2)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (2, N'TEXTO LARGO', N'Texto largo', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 3)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (3, N'ENTERO', N'Número entero', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 4)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (4, N'DECIMAL', N'Número decimal', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 5)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (5, N'SI NO', N'Sí / No', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 6)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (6, N'FECHA', N'Fecha', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 7)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (7, N'FECHA HORA', N'Fecha y hora', 7)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 8)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (8, N'HORA', N'Hora', 8)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 9)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (9, N'SELECCION SIMPLE', N'Selección simple', 9)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 10)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (10, N'SELECCION MULTIPLE', N'Selección múltiple', 10)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 11)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (11, N'MEDICION', N'Medición', 11)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 12)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (12, N'FOTOGRAFIA', N'Fotografía', 12)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 13)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (13, N'AUDIO', N'Audio', 13)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 14)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (14, N'ARCHIVO', N'Archivo', 14)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 15)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (15, N'FIRMA', N'Firma', 15)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 16)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (16, N'CODIGO QR', N'Código QR', 16)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 17)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (17, N'ACTIVO', N'Activo', 17)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 18)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (18, N'COMPONENTE', N'Componente', 18)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Item_Tipo] WHERE [cit_id] = 19)
    INSERT INTO [dbo].[Checklist_Item_Tipo] ([cit_id], [cit_codigo], [cit_nombre], [cit_orden]) VALUES (19, N'REPUESTO', N'Repuesto', 19)
SET IDENTITY_INSERT [dbo].[Checklist_Item_Tipo] OFF
GO

-- Checklist_Asignacion_Tipo (cat) — A quien se asigna una ocurrencia
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Asignacion_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Asignacion_Tipo]
    (
        [cat_id]                      INT             NOT NULL IDENTITY(1,1),
        [cat_codigo]                  NVARCHAR(50)    NOT NULL,
        [cat_nombre]                  NVARCHAR(100)   NOT NULL,
        [cat_orden]                   INT             NULL,
        [cat_habilitado]              BIT             NOT NULL CONSTRAINT DF_CAT_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_ASIGNACION_TIPO PRIMARY KEY CLUSTERED ([cat_id] ASC),
        CONSTRAINT UX_CAT_CODIGO UNIQUE ([cat_codigo])
    )

    PRINT 'Tabla Checklist_Asignacion_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Checklist_Asignacion_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Checklist_Asignacion_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Asignacion_Tipo] WHERE [cat_id] = 1)
    INSERT INTO [dbo].[Checklist_Asignacion_Tipo] ([cat_id], [cat_codigo], [cat_nombre], [cat_orden]) VALUES (1, N'TECNICO', N'Técnico específico', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Asignacion_Tipo] WHERE [cat_id] = 2)
    INSERT INTO [dbo].[Checklist_Asignacion_Tipo] ([cat_id], [cat_codigo], [cat_nombre], [cat_orden]) VALUES (2, N'VARIOS TECNICOS', N'Varios técnicos', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Asignacion_Tipo] WHERE [cat_id] = 3)
    INSERT INTO [dbo].[Checklist_Asignacion_Tipo] ([cat_id], [cat_codigo], [cat_nombre], [cat_orden]) VALUES (3, N'CUALQUIERA PLANTA', N'Cualquier técnico de la planta', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Asignacion_Tipo] WHERE [cat_id] = 4)
    INSERT INTO [dbo].[Checklist_Asignacion_Tipo] ([cat_id], [cat_codigo], [cat_nombre], [cat_orden]) VALUES (4, N'GRUPO', N'Grupo de trabajo', 4)
SET IDENTITY_INSERT [dbo].[Checklist_Asignacion_Tipo] OFF
GO

-- Cumplimiento_Politica (cpo) — Cuando se considera cumplida una ocurrencia
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Cumplimiento_Politica]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Cumplimiento_Politica]
    (
        [cpo_id]                      INT             NOT NULL IDENTITY(1,1),
        [cpo_codigo]                  NVARCHAR(50)    NOT NULL,
        [cpo_nombre]                  NVARCHAR(100)   NOT NULL,
        [cpo_orden]                   INT             NULL,
        [cpo_habilitado]              BIT             NOT NULL CONSTRAINT DF_CPO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CUMPLIMIENTO_POLITICA PRIMARY KEY CLUSTERED ([cpo_id] ASC),
        CONSTRAINT UX_CPO_CODIGO UNIQUE ([cpo_codigo])
    )

    PRINT 'Tabla Cumplimiento_Politica creada correctamente.'
END
ELSE
    PRINT 'Tabla Cumplimiento_Politica ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Cumplimiento_Politica] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Cumplimiento_Politica] WHERE [cpo_id] = 1)
    INSERT INTO [dbo].[Cumplimiento_Politica] ([cpo_id], [cpo_codigo], [cpo_nombre], [cpo_orden]) VALUES (1, N'UNO', N'La completa uno', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Cumplimiento_Politica] WHERE [cpo_id] = 2)
    INSERT INTO [dbo].[Cumplimiento_Politica] ([cpo_id], [cpo_codigo], [cpo_nombre], [cpo_orden]) VALUES (2, N'TODOS', N'La completan todos', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Cumplimiento_Politica] WHERE [cpo_id] = 3)
    INSERT INTO [dbo].[Cumplimiento_Politica] ([cpo_id], [cpo_codigo], [cpo_nombre], [cpo_orden]) VALUES (3, N'MINIMO', N'Cantidad mínima', 3)
SET IDENTITY_INSERT [dbo].[Cumplimiento_Politica] OFF
GO

-- Checklist_Ocurrencia_Estado (coe) — Ciclo de vida de una ocurrencia de checklist (VENCIDA se calcula)
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Ocurrencia_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Ocurrencia_Estado]
    (
        [coe_id]                      INT             NOT NULL IDENTITY(1,1),
        [coe_codigo]                  NVARCHAR(50)    NOT NULL,
        [coe_nombre]                  NVARCHAR(100)   NOT NULL,
        [coe_orden]                   INT             NULL,
        [coe_habilitado]              BIT             NOT NULL CONSTRAINT DF_COE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_OCURRENCIA_ESTADO PRIMARY KEY CLUSTERED ([coe_id] ASC),
        CONSTRAINT UX_COE_CODIGO UNIQUE ([coe_codigo])
    )

    PRINT 'Tabla Checklist_Ocurrencia_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Checklist_Ocurrencia_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Checklist_Ocurrencia_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ocurrencia_Estado] WHERE [coe_id] = 1)
    INSERT INTO [dbo].[Checklist_Ocurrencia_Estado] ([coe_id], [coe_codigo], [coe_nombre], [coe_orden]) VALUES (1, N'PENDIENTE', N'Pendiente', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ocurrencia_Estado] WHERE [coe_id] = 2)
    INSERT INTO [dbo].[Checklist_Ocurrencia_Estado] ([coe_id], [coe_codigo], [coe_nombre], [coe_orden]) VALUES (2, N'DISPONIBLE', N'Disponible', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ocurrencia_Estado] WHERE [coe_id] = 3)
    INSERT INTO [dbo].[Checklist_Ocurrencia_Estado] ([coe_id], [coe_codigo], [coe_nombre], [coe_orden]) VALUES (3, N'EN EJECUCION', N'En ejecución', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ocurrencia_Estado] WHERE [coe_id] = 4)
    INSERT INTO [dbo].[Checklist_Ocurrencia_Estado] ([coe_id], [coe_codigo], [coe_nombre], [coe_orden]) VALUES (4, N'COMPLETADA', N'Completada', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ocurrencia_Estado] WHERE [coe_id] = 5)
    INSERT INTO [dbo].[Checklist_Ocurrencia_Estado] ([coe_id], [coe_codigo], [coe_nombre], [coe_orden]) VALUES (5, N'OMITIDA', N'Omitida', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ocurrencia_Estado] WHERE [coe_id] = 6)
    INSERT INTO [dbo].[Checklist_Ocurrencia_Estado] ([coe_id], [coe_codigo], [coe_nombre], [coe_orden]) VALUES (6, N'CANCELADA', N'Cancelada', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ocurrencia_Estado] WHERE [coe_id] = 7)
    INSERT INTO [dbo].[Checklist_Ocurrencia_Estado] ([coe_id], [coe_codigo], [coe_nombre], [coe_orden]) VALUES (7, N'REPROGRAMADA', N'Reprogramada', 7)
SET IDENTITY_INSERT [dbo].[Checklist_Ocurrencia_Estado] OFF
GO

-- Checklist_Ejecucion_Estado (cee) — Ciclo de vida de una ejecucion
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Ejecucion_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Checklist_Ejecucion_Estado]
    (
        [cee_id]                      INT             NOT NULL IDENTITY(1,1),
        [cee_codigo]                  NVARCHAR(50)    NOT NULL,
        [cee_nombre]                  NVARCHAR(100)   NOT NULL,
        [cee_orden]                   INT             NULL,
        [cee_habilitado]              BIT             NOT NULL CONSTRAINT DF_CEE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CHECKLIST_EJECUCION_ESTADO PRIMARY KEY CLUSTERED ([cee_id] ASC),
        CONSTRAINT UX_CEE_CODIGO UNIQUE ([cee_codigo])
    )

    PRINT 'Tabla Checklist_Ejecucion_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Checklist_Ejecucion_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Checklist_Ejecucion_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ejecucion_Estado] WHERE [cee_id] = 1)
    INSERT INTO [dbo].[Checklist_Ejecucion_Estado] ([cee_id], [cee_codigo], [cee_nombre], [cee_orden]) VALUES (1, N'BORRADOR', N'Borrador', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ejecucion_Estado] WHERE [cee_id] = 2)
    INSERT INTO [dbo].[Checklist_Ejecucion_Estado] ([cee_id], [cee_codigo], [cee_nombre], [cee_orden]) VALUES (2, N'SINCRONIZANDO', N'Sincronizando', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ejecucion_Estado] WHERE [cee_id] = 3)
    INSERT INTO [dbo].[Checklist_Ejecucion_Estado] ([cee_id], [cee_codigo], [cee_nombre], [cee_orden]) VALUES (3, N'ENVIADA', N'Enviada', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ejecucion_Estado] WHERE [cee_id] = 4)
    INSERT INTO [dbo].[Checklist_Ejecucion_Estado] ([cee_id], [cee_codigo], [cee_nombre], [cee_orden]) VALUES (4, N'VALIDADA', N'Validada', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ejecucion_Estado] WHERE [cee_id] = 5)
    INSERT INTO [dbo].[Checklist_Ejecucion_Estado] ([cee_id], [cee_codigo], [cee_nombre], [cee_orden]) VALUES (5, N'RECHAZADA', N'Rechazada', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ejecucion_Estado] WHERE [cee_id] = 6)
    INSERT INTO [dbo].[Checklist_Ejecucion_Estado] ([cee_id], [cee_codigo], [cee_nombre], [cee_orden]) VALUES (6, N'ANULADA', N'Anulada', 6)
SET IDENTITY_INSERT [dbo].[Checklist_Ejecucion_Estado] OFF
GO

-- Dependencia_Accion (dac) — Que hace una dependencia entre items
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Dependencia_Accion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Dependencia_Accion]
    (
        [dac_id]                      INT             NOT NULL IDENTITY(1,1),
        [dac_codigo]                  NVARCHAR(50)    NOT NULL,
        [dac_nombre]                  NVARCHAR(100)   NOT NULL,
        [dac_orden]                   INT             NULL,
        [dac_habilitado]              BIT             NOT NULL CONSTRAINT DF_DAC_HABILITADO DEFAULT 1,

        CONSTRAINT PK_DEPENDENCIA_ACCION PRIMARY KEY CLUSTERED ([dac_id] ASC),
        CONSTRAINT UX_DAC_CODIGO UNIQUE ([dac_codigo])
    )

    PRINT 'Tabla Dependencia_Accion creada correctamente.'
END
ELSE
    PRINT 'Tabla Dependencia_Accion ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Dependencia_Accion] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dependencia_Accion] WHERE [dac_id] = 1)
    INSERT INTO [dbo].[Dependencia_Accion] ([dac_id], [dac_codigo], [dac_nombre], [dac_orden]) VALUES (1, N'MOSTRAR', N'Mostrar', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dependencia_Accion] WHERE [dac_id] = 2)
    INSERT INTO [dbo].[Dependencia_Accion] ([dac_id], [dac_codigo], [dac_nombre], [dac_orden]) VALUES (2, N'OCULTAR', N'Ocultar', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dependencia_Accion] WHERE [dac_id] = 3)
    INSERT INTO [dbo].[Dependencia_Accion] ([dac_id], [dac_codigo], [dac_nombre], [dac_orden]) VALUES (3, N'REQUERIR', N'Requerir', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Dependencia_Accion] WHERE [dac_id] = 4)
    INSERT INTO [dbo].[Dependencia_Accion] ([dac_id], [dac_codigo], [dac_nombre], [dac_orden]) VALUES (4, N'BLOQUEAR', N'Bloquear', 4)
SET IDENTITY_INSERT [dbo].[Dependencia_Accion] OFF
GO

/* ========================================================================
   TAREAS
   ======================================================================== */

-- Tarea_Prioridad (tpa) — Prioridad de una tarea
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tarea_Prioridad]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Tarea_Prioridad]
    (
        [tpa_id]                      INT             NOT NULL IDENTITY(1,1),
        [tpa_codigo]                  NVARCHAR(50)    NOT NULL,
        [tpa_nombre]                  NVARCHAR(100)   NOT NULL,
        [tpa_orden]                   INT             NULL,
        [tpa_habilitado]              BIT             NOT NULL CONSTRAINT DF_TPA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_TAREA_PRIORIDAD PRIMARY KEY CLUSTERED ([tpa_id] ASC),
        CONSTRAINT UX_TPA_CODIGO UNIQUE ([tpa_codigo])
    )

    PRINT 'Tabla Tarea_Prioridad creada correctamente.'
END
ELSE
    PRINT 'Tabla Tarea_Prioridad ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Tarea_Prioridad] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Prioridad] WHERE [tpa_id] = 1)
    INSERT INTO [dbo].[Tarea_Prioridad] ([tpa_id], [tpa_codigo], [tpa_nombre], [tpa_orden]) VALUES (1, N'BAJA', N'Baja', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Prioridad] WHERE [tpa_id] = 2)
    INSERT INTO [dbo].[Tarea_Prioridad] ([tpa_id], [tpa_codigo], [tpa_nombre], [tpa_orden]) VALUES (2, N'MEDIA', N'Media', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Prioridad] WHERE [tpa_id] = 3)
    INSERT INTO [dbo].[Tarea_Prioridad] ([tpa_id], [tpa_codigo], [tpa_nombre], [tpa_orden]) VALUES (3, N'ALTA', N'Alta', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Prioridad] WHERE [tpa_id] = 4)
    INSERT INTO [dbo].[Tarea_Prioridad] ([tpa_id], [tpa_codigo], [tpa_nombre], [tpa_orden]) VALUES (4, N'CRITICA', N'Crítica', 4)
SET IDENTITY_INSERT [dbo].[Tarea_Prioridad] OFF
GO

-- Tarea_Ocurrencia_Estado (toe) — Ciclo de vida de una ocurrencia de tarea (VENCIDA se calcula)
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tarea_Ocurrencia_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Tarea_Ocurrencia_Estado]
    (
        [toe_id]                      INT             NOT NULL IDENTITY(1,1),
        [toe_codigo]                  NVARCHAR(50)    NOT NULL,
        [toe_nombre]                  NVARCHAR(100)   NOT NULL,
        [toe_orden]                   INT             NULL,
        [toe_habilitado]              BIT             NOT NULL CONSTRAINT DF_TOE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_TAREA_OCURRENCIA_ESTADO PRIMARY KEY CLUSTERED ([toe_id] ASC),
        CONSTRAINT UX_TOE_CODIGO UNIQUE ([toe_codigo])
    )

    PRINT 'Tabla Tarea_Ocurrencia_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Tarea_Ocurrencia_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Tarea_Ocurrencia_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia_Estado] WHERE [toe_id] = 1)
    INSERT INTO [dbo].[Tarea_Ocurrencia_Estado] ([toe_id], [toe_codigo], [toe_nombre], [toe_orden]) VALUES (1, N'PENDIENTE', N'Pendiente', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia_Estado] WHERE [toe_id] = 2)
    INSERT INTO [dbo].[Tarea_Ocurrencia_Estado] ([toe_id], [toe_codigo], [toe_nombre], [toe_orden]) VALUES (2, N'ACEPTADA', N'Aceptada', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia_Estado] WHERE [toe_id] = 3)
    INSERT INTO [dbo].[Tarea_Ocurrencia_Estado] ([toe_id], [toe_codigo], [toe_nombre], [toe_orden]) VALUES (3, N'EN EJECUCION', N'En ejecución', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia_Estado] WHERE [toe_id] = 4)
    INSERT INTO [dbo].[Tarea_Ocurrencia_Estado] ([toe_id], [toe_codigo], [toe_nombre], [toe_orden]) VALUES (4, N'COMPLETADA', N'Completada', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia_Estado] WHERE [toe_id] = 5)
    INSERT INTO [dbo].[Tarea_Ocurrencia_Estado] ([toe_id], [toe_codigo], [toe_nombre], [toe_orden]) VALUES (5, N'NO REALIZADA', N'No realizada', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia_Estado] WHERE [toe_id] = 6)
    INSERT INTO [dbo].[Tarea_Ocurrencia_Estado] ([toe_id], [toe_codigo], [toe_nombre], [toe_orden]) VALUES (6, N'CANCELADA', N'Cancelada', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia_Estado] WHERE [toe_id] = 7)
    INSERT INTO [dbo].[Tarea_Ocurrencia_Estado] ([toe_id], [toe_codigo], [toe_nombre], [toe_orden]) VALUES (7, N'REPROGRAMADA', N'Reprogramada', 7)
SET IDENTITY_INSERT [dbo].[Tarea_Ocurrencia_Estado] OFF
GO

/* ========================================================================
   ÓRDENES DE TRABAJO Y FALLAS
   ======================================================================== */

-- Orden_Trabajo_Tipo (ott) — Tipo de mantenimiento
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo_Tipo]
    (
        [ott_id]                      INT             NOT NULL IDENTITY(1,1),
        [ott_codigo]                  NVARCHAR(50)    NOT NULL,
        [ott_nombre]                  NVARCHAR(100)   NOT NULL,
        [ott_orden]                   INT             NULL,
        [ott_habilitado]              BIT             NOT NULL CONSTRAINT DF_OTT_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ORDEN_TRABAJO_TIPO PRIMARY KEY CLUSTERED ([ott_id] ASC),
        CONSTRAINT UX_OTT_CODIGO UNIQUE ([ott_codigo])
    )

    PRINT 'Tabla Orden_Trabajo_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Orden_Trabajo_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Orden_Trabajo_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Tipo] WHERE [ott_id] = 1)
    INSERT INTO [dbo].[Orden_Trabajo_Tipo] ([ott_id], [ott_codigo], [ott_nombre], [ott_orden]) VALUES (1, N'PREVENTIVA', N'Preventiva', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Tipo] WHERE [ott_id] = 2)
    INSERT INTO [dbo].[Orden_Trabajo_Tipo] ([ott_id], [ott_codigo], [ott_nombre], [ott_orden]) VALUES (2, N'CORRECTIVA', N'Correctiva', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Tipo] WHERE [ott_id] = 3)
    INSERT INTO [dbo].[Orden_Trabajo_Tipo] ([ott_id], [ott_codigo], [ott_nombre], [ott_orden]) VALUES (3, N'PREDICTIVA', N'Predictiva', 3)
SET IDENTITY_INSERT [dbo].[Orden_Trabajo_Tipo] OFF
GO

-- Orden_Trabajo_Estrategia (oet) — Estrategia dentro del tipo
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Estrategia]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo_Estrategia]
    (
        [oet_id]                      INT             NOT NULL IDENTITY(1,1),
        [oet_codigo]                  NVARCHAR(50)    NOT NULL,
        [oet_nombre]                  NVARCHAR(100)   NOT NULL,
        [oet_orden]                   INT             NULL,
        [oet_habilitado]              BIT             NOT NULL CONSTRAINT DF_OET_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ORDEN_TRABAJO_ESTRATEGIA PRIMARY KEY CLUSTERED ([oet_id] ASC),
        CONSTRAINT UX_OET_CODIGO UNIQUE ([oet_codigo])
    )

    PRINT 'Tabla Orden_Trabajo_Estrategia creada correctamente.'
END
ELSE
    PRINT 'Tabla Orden_Trabajo_Estrategia ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Orden_Trabajo_Estrategia] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Estrategia] WHERE [oet_id] = 1)
    INSERT INTO [dbo].[Orden_Trabajo_Estrategia] ([oet_id], [oet_codigo], [oet_nombre], [oet_orden]) VALUES (1, N'RUTINARIO', N'Rutinario', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Estrategia] WHERE [oet_id] = 2)
    INSERT INTO [dbo].[Orden_Trabajo_Estrategia] ([oet_id], [oet_codigo], [oet_nombre], [oet_orden]) VALUES (2, N'PROGRAMADO', N'Programado', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Estrategia] WHERE [oet_id] = 3)
    INSERT INTO [dbo].[Orden_Trabajo_Estrategia] ([oet_id], [oet_codigo], [oet_nombre], [oet_orden]) VALUES (3, N'EMERGENCIA', N'Emergencia', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Estrategia] WHERE [oet_id] = 4)
    INSERT INTO [dbo].[Orden_Trabajo_Estrategia] ([oet_id], [oet_codigo], [oet_nombre], [oet_orden]) VALUES (4, N'INSPECCION', N'Inspección', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Estrategia] WHERE [oet_id] = 5)
    INSERT INTO [dbo].[Orden_Trabajo_Estrategia] ([oet_id], [oet_codigo], [oet_nombre], [oet_orden]) VALUES (5, N'OVERHAUL', N'Overhaul', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Estrategia] WHERE [oet_id] = 6)
    INSERT INTO [dbo].[Orden_Trabajo_Estrategia] ([oet_id], [oet_codigo], [oet_nombre], [oet_orden]) VALUES (6, N'MEJORA', N'Mejora', 6)
SET IDENTITY_INSERT [dbo].[Orden_Trabajo_Estrategia] OFF
GO

-- Orden_Trabajo_Origen (oto) — Que activo la OT
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Origen]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo_Origen]
    (
        [oto_id]                      INT             NOT NULL IDENTITY(1,1),
        [oto_codigo]                  NVARCHAR(50)    NOT NULL,
        [oto_nombre]                  NVARCHAR(100)   NOT NULL,
        [oto_orden]                   INT             NULL,
        [oto_habilitado]              BIT             NOT NULL CONSTRAINT DF_OTO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ORDEN_TRABAJO_ORIGEN PRIMARY KEY CLUSTERED ([oto_id] ASC),
        CONSTRAINT UX_OTO_CODIGO UNIQUE ([oto_codigo])
    )

    PRINT 'Tabla Orden_Trabajo_Origen creada correctamente.'
END
ELSE
    PRINT 'Tabla Orden_Trabajo_Origen ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Orden_Trabajo_Origen] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Origen] WHERE [oto_id] = 1)
    INSERT INTO [dbo].[Orden_Trabajo_Origen] ([oto_id], [oto_codigo], [oto_nombre], [oto_orden]) VALUES (1, N'MANUAL', N'Manual', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Origen] WHERE [oto_id] = 2)
    INSERT INTO [dbo].[Orden_Trabajo_Origen] ([oto_id], [oto_codigo], [oto_nombre], [oto_orden]) VALUES (2, N'PLAN', N'Plan de mantenimiento', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Origen] WHERE [oto_id] = 3)
    INSERT INTO [dbo].[Orden_Trabajo_Origen] ([oto_id], [oto_codigo], [oto_nombre], [oto_orden]) VALUES (3, N'TAREA', N'Tarea', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Origen] WHERE [oto_id] = 4)
    INSERT INTO [dbo].[Orden_Trabajo_Origen] ([oto_id], [oto_codigo], [oto_nombre], [oto_orden]) VALUES (4, N'HALLAZGO CHECKLIST', N'Hallazgo de checklist', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Origen] WHERE [oto_id] = 5)
    INSERT INTO [dbo].[Orden_Trabajo_Origen] ([oto_id], [oto_codigo], [oto_nombre], [oto_orden]) VALUES (5, N'PREDICCION', N'Predicción', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Origen] WHERE [oto_id] = 6)
    INSERT INTO [dbo].[Orden_Trabajo_Origen] ([oto_id], [oto_codigo], [oto_nombre], [oto_orden]) VALUES (6, N'ALERTA', N'Alerta', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Origen] WHERE [oto_id] = 7)
    INSERT INTO [dbo].[Orden_Trabajo_Origen] ([oto_id], [oto_codigo], [oto_nombre], [oto_orden]) VALUES (7, N'FALLA', N'Falla', 7)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Origen] WHERE [oto_id] = 8)
    INSERT INTO [dbo].[Orden_Trabajo_Origen] ([oto_id], [oto_codigo], [oto_nombre], [oto_orden]) VALUES (8, N'BITACORA', N'Bitácora', 8)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Origen] WHERE [oto_id] = 9)
    INSERT INTO [dbo].[Orden_Trabajo_Origen] ([oto_id], [oto_codigo], [oto_nombre], [oto_orden]) VALUES (9, N'HALLAZGO EN OT', N'Hallazgo durante otra orden de trabajo', 9)
SET IDENTITY_INSERT [dbo].[Orden_Trabajo_Origen] OFF
GO

-- Orden_Trabajo_Estado (ote) — Ciclo de vida de la OT. Solo cuatro.
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo_Estado]
    (
        [ote_id]                      INT             NOT NULL IDENTITY(1,1),
        [ote_codigo]                  NVARCHAR(50)    NOT NULL,
        [ote_nombre]                  NVARCHAR(100)   NOT NULL,
        [ote_orden]                   INT             NULL,
        [ote_habilitado]              BIT             NOT NULL CONSTRAINT DF_OTE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ORDEN_TRABAJO_ESTADO PRIMARY KEY CLUSTERED ([ote_id] ASC),
        CONSTRAINT UX_OTE_CODIGO UNIQUE ([ote_codigo])
    )

    PRINT 'Tabla Orden_Trabajo_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Orden_Trabajo_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Orden_Trabajo_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Estado] WHERE [ote_id] = 1)
    INSERT INTO [dbo].[Orden_Trabajo_Estado] ([ote_id], [ote_codigo], [ote_nombre], [ote_orden]) VALUES (1, N'ABIERTA', N'Abierta', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Estado] WHERE [ote_id] = 2)
    INSERT INTO [dbo].[Orden_Trabajo_Estado] ([ote_id], [ote_codigo], [ote_nombre], [ote_orden]) VALUES (2, N'EN EJECUCION', N'En ejecución', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Estado] WHERE [ote_id] = 3)
    INSERT INTO [dbo].[Orden_Trabajo_Estado] ([ote_id], [ote_codigo], [ote_nombre], [ote_orden]) VALUES (3, N'EN ESPERA DE CIERRE', N'En espera de cierre', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Estado] WHERE [ote_id] = 4)
    INSERT INTO [dbo].[Orden_Trabajo_Estado] ([ote_id], [ote_codigo], [ote_nombre], [ote_orden]) VALUES (4, N'CERRADA', N'Cerrada', 4)
SET IDENTITY_INSERT [dbo].[Orden_Trabajo_Estado] OFF
GO

-- Orden_Trabajo_Cierre_Motivo (ocm) — Por que se cerro la OT
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Cierre_Motivo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo_Cierre_Motivo]
    (
        [ocm_id]                      INT             NOT NULL IDENTITY(1,1),
        [ocm_codigo]                  NVARCHAR(50)    NOT NULL,
        [ocm_nombre]                  NVARCHAR(100)   NOT NULL,
        [ocm_orden]                   INT             NULL,
        [ocm_habilitado]              BIT             NOT NULL CONSTRAINT DF_OCM_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ORDEN_TRABAJO_CIERRE_MOTIVO PRIMARY KEY CLUSTERED ([ocm_id] ASC),
        CONSTRAINT UX_OCM_CODIGO UNIQUE ([ocm_codigo])
    )

    PRINT 'Tabla Orden_Trabajo_Cierre_Motivo creada correctamente.'
END
ELSE
    PRINT 'Tabla Orden_Trabajo_Cierre_Motivo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Orden_Trabajo_Cierre_Motivo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Cierre_Motivo] WHERE [ocm_id] = 1)
    INSERT INTO [dbo].[Orden_Trabajo_Cierre_Motivo] ([ocm_id], [ocm_codigo], [ocm_nombre], [ocm_orden]) VALUES (1, N'TRABAJO REALIZADO', N'Trabajo realizado', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Cierre_Motivo] WHERE [ocm_id] = 2)
    INSERT INTO [dbo].[Orden_Trabajo_Cierre_Motivo] ([ocm_id], [ocm_codigo], [ocm_nombre], [ocm_orden]) VALUES (2, N'SIN HALLAZGO', N'Sin hallazgo, no requirió intervención', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Cierre_Motivo] WHERE [ocm_id] = 3)
    INSERT INTO [dbo].[Orden_Trabajo_Cierre_Motivo] ([ocm_id], [ocm_codigo], [ocm_nombre], [ocm_orden]) VALUES (3, N'RESUELTA EN OTRA OT', N'Resuelta en otra orden de trabajo', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Cierre_Motivo] WHERE [ocm_id] = 4)
    INSERT INTO [dbo].[Orden_Trabajo_Cierre_Motivo] ([ocm_id], [ocm_codigo], [ocm_nombre], [ocm_orden]) VALUES (4, N'DUPLICADA', N'Duplicada', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Cierre_Motivo] WHERE [ocm_id] = 5)
    INSERT INTO [dbo].[Orden_Trabajo_Cierre_Motivo] ([ocm_id], [ocm_codigo], [ocm_nombre], [ocm_orden]) VALUES (5, N'ANULADA POR ERROR', N'Anulada por error de registro', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Cierre_Motivo] WHERE [ocm_id] = 6)
    INSERT INTO [dbo].[Orden_Trabajo_Cierre_Motivo] ([ocm_id], [ocm_codigo], [ocm_nombre], [ocm_orden]) VALUES (6, N'NO APLICA', N'No aplica', 6)
SET IDENTITY_INSERT [dbo].[Orden_Trabajo_Cierre_Motivo] OFF
GO

-- Orden_Trabajo_Prioridad (opr) — Prioridad de la OT
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Prioridad]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Orden_Trabajo_Prioridad]
    (
        [opr_id]                      INT             NOT NULL IDENTITY(1,1),
        [opr_codigo]                  NVARCHAR(50)    NOT NULL,
        [opr_nombre]                  NVARCHAR(100)   NOT NULL,
        [opr_orden]                   INT             NULL,
        [opr_habilitado]              BIT             NOT NULL CONSTRAINT DF_OPR_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ORDEN_TRABAJO_PRIORIDAD PRIMARY KEY CLUSTERED ([opr_id] ASC),
        CONSTRAINT UX_OPR_CODIGO UNIQUE ([opr_codigo])
    )

    PRINT 'Tabla Orden_Trabajo_Prioridad creada correctamente.'
END
ELSE
    PRINT 'Tabla Orden_Trabajo_Prioridad ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Orden_Trabajo_Prioridad] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Prioridad] WHERE [opr_id] = 1)
    INSERT INTO [dbo].[Orden_Trabajo_Prioridad] ([opr_id], [opr_codigo], [opr_nombre], [opr_orden]) VALUES (1, N'BAJA', N'Baja', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Prioridad] WHERE [opr_id] = 2)
    INSERT INTO [dbo].[Orden_Trabajo_Prioridad] ([opr_id], [opr_codigo], [opr_nombre], [opr_orden]) VALUES (2, N'MEDIA', N'Media', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Prioridad] WHERE [opr_id] = 3)
    INSERT INTO [dbo].[Orden_Trabajo_Prioridad] ([opr_id], [opr_codigo], [opr_nombre], [opr_orden]) VALUES (3, N'ALTA', N'Alta', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Prioridad] WHERE [opr_id] = 4)
    INSERT INTO [dbo].[Orden_Trabajo_Prioridad] ([opr_id], [opr_codigo], [opr_nombre], [opr_orden]) VALUES (4, N'CRITICA', N'Crítica', 4)
SET IDENTITY_INSERT [dbo].[Orden_Trabajo_Prioridad] OFF
GO

-- Rol_Ejecucion (rej) — Rol de un asignado en la ejecucion
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Rol_Ejecucion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Rol_Ejecucion]
    (
        [rej_id]                      INT             NOT NULL IDENTITY(1,1),
        [rej_codigo]                  NVARCHAR(50)    NOT NULL,
        [rej_nombre]                  NVARCHAR(100)   NOT NULL,
        [rej_orden]                   INT             NULL,
        [rej_habilitado]              BIT             NOT NULL CONSTRAINT DF_REJ_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ROL_EJECUCION PRIMARY KEY CLUSTERED ([rej_id] ASC),
        CONSTRAINT UX_REJ_CODIGO UNIQUE ([rej_codigo])
    )

    PRINT 'Tabla Rol_Ejecucion creada correctamente.'
END
ELSE
    PRINT 'Tabla Rol_Ejecucion ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Rol_Ejecucion] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Rol_Ejecucion] WHERE [rej_id] = 1)
    INSERT INTO [dbo].[Rol_Ejecucion] ([rej_id], [rej_codigo], [rej_nombre], [rej_orden]) VALUES (1, N'EJECUTOR PRINCIPAL', N'Ejecutor principal', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Rol_Ejecucion] WHERE [rej_id] = 2)
    INSERT INTO [dbo].[Rol_Ejecucion] ([rej_id], [rej_codigo], [rej_nombre], [rej_orden]) VALUES (2, N'APOYO', N'Apoyo', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Rol_Ejecucion] WHERE [rej_id] = 3)
    INSERT INTO [dbo].[Rol_Ejecucion] ([rej_id], [rej_codigo], [rej_nombre], [rej_orden]) VALUES (3, N'SUPERVISOR', N'Supervisor', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Rol_Ejecucion] WHERE [rej_id] = 4)
    INSERT INTO [dbo].[Rol_Ejecucion] ([rej_id], [rej_codigo], [rej_nombre], [rej_orden]) VALUES (4, N'OBSERVADOR', N'Observador', 4)
SET IDENTITY_INSERT [dbo].[Rol_Ejecucion] OFF
GO

-- Validacion_Tipo (vat) — Las tres firmas del formato de OT
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Validacion_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Validacion_Tipo]
    (
        [vat_id]                      INT             NOT NULL IDENTITY(1,1),
        [vat_codigo]                  NVARCHAR(50)    NOT NULL,
        [vat_nombre]                  NVARCHAR(100)   NOT NULL,
        [vat_orden]                   INT             NULL,
        [vat_habilitado]              BIT             NOT NULL CONSTRAINT DF_VAT_HABILITADO DEFAULT 1,

        CONSTRAINT PK_VALIDACION_TIPO PRIMARY KEY CLUSTERED ([vat_id] ASC),
        CONSTRAINT UX_VAT_CODIGO UNIQUE ([vat_codigo])
    )

    PRINT 'Tabla Validacion_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Validacion_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Validacion_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Validacion_Tipo] WHERE [vat_id] = 1)
    INSERT INTO [dbo].[Validacion_Tipo] ([vat_id], [vat_codigo], [vat_nombre], [vat_orden]) VALUES (1, N'ACEPTACION', N'Aceptación', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Validacion_Tipo] WHERE [vat_id] = 2)
    INSERT INTO [dbo].[Validacion_Tipo] ([vat_id], [vat_codigo], [vat_nombre], [vat_orden]) VALUES (2, N'VALIDACION', N'Validación', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Validacion_Tipo] WHERE [vat_id] = 3)
    INSERT INTO [dbo].[Validacion_Tipo] ([vat_id], [vat_codigo], [vat_nombre], [vat_orden]) VALUES (3, N'EJECUCION', N'Ejecución', 3)
SET IDENTITY_INSERT [dbo].[Validacion_Tipo] OFF
GO

-- Resultado_Paso (rpa) — Resultado de un paso de OT
--   FIJO: el codigo depende de estos ids  ·  visible en la app: lleva icono e imagen
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Resultado_Paso]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Resultado_Paso]
    (
        [rpa_id]                      INT             NOT NULL IDENTITY(1,1),
        [rpa_codigo]                  NVARCHAR(50)    NOT NULL,
        [rpa_nombre]                  NVARCHAR(100)   NOT NULL,
        [rpa_icono]                   NVARCHAR(50)    NULL,       -- icono del set de la app
        [rpa_archivo]                 INT             NULL,       -- FK Archivo: foto real
        [rpa_orden]                   INT             NULL,
        [rpa_habilitado]              BIT             NOT NULL CONSTRAINT DF_RPA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_RESULTADO_PASO PRIMARY KEY CLUSTERED ([rpa_id] ASC),
        CONSTRAINT UX_RPA_CODIGO UNIQUE ([rpa_codigo])
    )

    PRINT 'Tabla Resultado_Paso creada correctamente.'
END
ELSE
    PRINT 'Tabla Resultado_Paso ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Resultado_Paso] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Resultado_Paso] WHERE [rpa_id] = 1)
    INSERT INTO [dbo].[Resultado_Paso] ([rpa_id], [rpa_codigo], [rpa_nombre], [rpa_orden]) VALUES (1, N'CONFORME', N'Conforme', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Resultado_Paso] WHERE [rpa_id] = 2)
    INSERT INTO [dbo].[Resultado_Paso] ([rpa_id], [rpa_codigo], [rpa_nombre], [rpa_orden]) VALUES (2, N'NO CONFORME', N'No conforme', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Resultado_Paso] WHERE [rpa_id] = 3)
    INSERT INTO [dbo].[Resultado_Paso] ([rpa_id], [rpa_codigo], [rpa_nombre], [rpa_orden]) VALUES (3, N'NO APLICA', N'No aplica', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Resultado_Paso] WHERE [rpa_id] = 4)
    INSERT INTO [dbo].[Resultado_Paso] ([rpa_id], [rpa_codigo], [rpa_nombre], [rpa_orden]) VALUES (4, N'PENDIENTE', N'Pendiente', 4)
SET IDENTITY_INSERT [dbo].[Resultado_Paso] OFF
GO

-- Servicio_Tipo (sti) — Tipo de servicio contratado a un proveedor
--   AMPLIABLE por cliente
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Servicio_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Servicio_Tipo]
    (
        [sti_id]                      INT             NOT NULL IDENTITY(1,1),
        [sti_cliente]                 INT             NULL,       -- NULL = global SIGMA
        [sti_codigo]                  NVARCHAR(50)    NOT NULL,
        [sti_nombre]                  NVARCHAR(100)   NOT NULL,
        [sti_orden]                   INT             NULL,
        [sti_usuario_creacion]        INT             NULL,
        [sti_fecha_creacion]          DATETIME        NULL CONSTRAINT DF_STI_FECHA_CREACION DEFAULT GETDATE(),
        [sti_usuario_actualizacion]   INT             NULL,
        [sti_fecha_actualizacion]     DATETIME        NULL,
        [sti_habilitado]              BIT             NOT NULL CONSTRAINT DF_STI_HABILITADO DEFAULT 1,

        CONSTRAINT PK_SERVICIO_TIPO PRIMARY KEY CLUSTERED ([sti_id] ASC),
        CONSTRAINT FK_STI_CLIENTE FOREIGN KEY ([sti_cliente]) REFERENCES [dbo].[Cliente] ([cli_id])
    )

    -- El codigo es unico dentro del cliente; las globales van con cliente NULL.
    CREATE UNIQUE NONCLUSTERED INDEX UX_STI_CLIENTE_CODIGO
        ON [dbo].[Servicio_Tipo] ([sti_cliente], [sti_codigo])

    PRINT 'Tabla Servicio_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Servicio_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Servicio_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Servicio_Tipo] WHERE [sti_id] = 1)
    INSERT INTO [dbo].[Servicio_Tipo] ([sti_id], [sti_codigo], [sti_nombre], [sti_orden]) VALUES (1, N'SERVICIO TECNICO', N'Servicio técnico', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Servicio_Tipo] WHERE [sti_id] = 2)
    INSERT INTO [dbo].[Servicio_Tipo] ([sti_id], [sti_codigo], [sti_nombre], [sti_orden]) VALUES (2, N'ARRIENDO EQUIPO', N'Arriendo de equipo', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Servicio_Tipo] WHERE [sti_id] = 3)
    INSERT INTO [dbo].[Servicio_Tipo] ([sti_id], [sti_codigo], [sti_nombre], [sti_orden]) VALUES (3, N'MONTAJE', N'Montaje', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Servicio_Tipo] WHERE [sti_id] = 4)
    INSERT INTO [dbo].[Servicio_Tipo] ([sti_id], [sti_codigo], [sti_nombre], [sti_orden]) VALUES (4, N'DESMONTAJE', N'Desmontaje', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Servicio_Tipo] WHERE [sti_id] = 5)
    INSERT INTO [dbo].[Servicio_Tipo] ([sti_id], [sti_codigo], [sti_nombre], [sti_orden]) VALUES (5, N'MANO OBRA EXTERNA', N'Mano de obra externa', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Servicio_Tipo] WHERE [sti_id] = 6)
    INSERT INTO [dbo].[Servicio_Tipo] ([sti_id], [sti_codigo], [sti_nombre], [sti_orden]) VALUES (6, N'REPUESTO', N'Repuesto', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Servicio_Tipo] WHERE [sti_id] = 7)
    INSERT INTO [dbo].[Servicio_Tipo] ([sti_id], [sti_codigo], [sti_nombre], [sti_orden]) VALUES (7, N'TRANSPORTE', N'Transporte', 7)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Servicio_Tipo] WHERE [sti_id] = 8)
    INSERT INTO [dbo].[Servicio_Tipo] ([sti_id], [sti_codigo], [sti_nombre], [sti_orden]) VALUES (8, N'CALIBRACION', N'Calibración', 8)
SET IDENTITY_INSERT [dbo].[Servicio_Tipo] OFF
GO

-- Indisponibilidad_Motivo (inm) — Por que el activo estuvo detenido
--   AMPLIABLE por cliente  ·  visible en la app: lleva icono e imagen
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Indisponibilidad_Motivo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Indisponibilidad_Motivo]
    (
        [inm_id]                      INT             NOT NULL IDENTITY(1,1),
        [inm_cliente]                 INT             NULL,       -- NULL = global SIGMA
        [inm_codigo]                  NVARCHAR(50)    NOT NULL,
        [inm_nombre]                  NVARCHAR(100)   NOT NULL,
        [inm_icono]                   NVARCHAR(50)    NULL,       -- icono del set de la app
        [inm_archivo]                 INT             NULL,       -- FK Archivo: foto real
        [inm_orden]                   INT             NULL,
        [inm_usuario_creacion]        INT             NULL,
        [inm_fecha_creacion]          DATETIME        NULL CONSTRAINT DF_INM_FECHA_CREACION DEFAULT GETDATE(),
        [inm_usuario_actualizacion]   INT             NULL,
        [inm_fecha_actualizacion]     DATETIME        NULL,
        [inm_habilitado]              BIT             NOT NULL CONSTRAINT DF_INM_HABILITADO DEFAULT 1,

        CONSTRAINT PK_INDISPONIBILIDAD_MOTIVO PRIMARY KEY CLUSTERED ([inm_id] ASC),
        CONSTRAINT FK_INM_CLIENTE FOREIGN KEY ([inm_cliente]) REFERENCES [dbo].[Cliente] ([cli_id])
    )

    -- El codigo es unico dentro del cliente; las globales van con cliente NULL.
    CREATE UNIQUE NONCLUSTERED INDEX UX_INM_CLIENTE_CODIGO
        ON [dbo].[Indisponibilidad_Motivo] ([inm_cliente], [inm_codigo])

    PRINT 'Tabla Indisponibilidad_Motivo creada correctamente.'
END
ELSE
    PRINT 'Tabla Indisponibilidad_Motivo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Indisponibilidad_Motivo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Indisponibilidad_Motivo] WHERE [inm_id] = 1)
    INSERT INTO [dbo].[Indisponibilidad_Motivo] ([inm_id], [inm_codigo], [inm_nombre], [inm_orden]) VALUES (1, N'MANTENIMIENTO PLANIFICADO', N'Mantenimiento planificado', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Indisponibilidad_Motivo] WHERE [inm_id] = 2)
    INSERT INTO [dbo].[Indisponibilidad_Motivo] ([inm_id], [inm_codigo], [inm_nombre], [inm_orden]) VALUES (2, N'FALLA', N'Falla', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Indisponibilidad_Motivo] WHERE [inm_id] = 3)
    INSERT INTO [dbo].[Indisponibilidad_Motivo] ([inm_id], [inm_codigo], [inm_nombre], [inm_orden]) VALUES (3, N'ESPERA REPUESTO', N'Espera de repuesto', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Indisponibilidad_Motivo] WHERE [inm_id] = 4)
    INSERT INTO [dbo].[Indisponibilidad_Motivo] ([inm_id], [inm_codigo], [inm_nombre], [inm_orden]) VALUES (4, N'ESPERA TECNICO', N'Espera de técnico', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Indisponibilidad_Motivo] WHERE [inm_id] = 5)
    INSERT INTO [dbo].[Indisponibilidad_Motivo] ([inm_id], [inm_codigo], [inm_nombre], [inm_orden]) VALUES (5, N'CAUSA EXTERNA', N'Causa externa', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Indisponibilidad_Motivo] WHERE [inm_id] = 6)
    INSERT INTO [dbo].[Indisponibilidad_Motivo] ([inm_id], [inm_codigo], [inm_nombre], [inm_orden]) VALUES (6, N'PARADA PRODUCCION', N'Parada de producción', 6)
SET IDENTITY_INSERT [dbo].[Indisponibilidad_Motivo] OFF
GO

-- Permiso_Trabajo_Tipo (ptt) — Tipo de permiso de trabajo
--   AMPLIABLE por cliente
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Permiso_Trabajo_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Permiso_Trabajo_Tipo]
    (
        [ptt_id]                      INT             NOT NULL IDENTITY(1,1),
        [ptt_cliente]                 INT             NULL,       -- NULL = global SIGMA
        [ptt_codigo]                  NVARCHAR(50)    NOT NULL,
        [ptt_nombre]                  NVARCHAR(100)   NOT NULL,
        [ptt_orden]                   INT             NULL,
        [ptt_usuario_creacion]        INT             NULL,
        [ptt_fecha_creacion]          DATETIME        NULL CONSTRAINT DF_PTT_FECHA_CREACION DEFAULT GETDATE(),
        [ptt_usuario_actualizacion]   INT             NULL,
        [ptt_fecha_actualizacion]     DATETIME        NULL,
        [ptt_habilitado]              BIT             NOT NULL CONSTRAINT DF_PTT_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PERMISO_TRABAJO_TIPO PRIMARY KEY CLUSTERED ([ptt_id] ASC),
        CONSTRAINT FK_PTT_CLIENTE FOREIGN KEY ([ptt_cliente]) REFERENCES [dbo].[Cliente] ([cli_id])
    )

    -- El codigo es unico dentro del cliente; las globales van con cliente NULL.
    CREATE UNIQUE NONCLUSTERED INDEX UX_PTT_CLIENTE_CODIGO
        ON [dbo].[Permiso_Trabajo_Tipo] ([ptt_cliente], [ptt_codigo])

    PRINT 'Tabla Permiso_Trabajo_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Permiso_Trabajo_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Permiso_Trabajo_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Tipo] WHERE [ptt_id] = 1)
    INSERT INTO [dbo].[Permiso_Trabajo_Tipo] ([ptt_id], [ptt_codigo], [ptt_nombre], [ptt_orden]) VALUES (1, N'ALTURA', N'Trabajo en altura', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Tipo] WHERE [ptt_id] = 2)
    INSERT INTO [dbo].[Permiso_Trabajo_Tipo] ([ptt_id], [ptt_codigo], [ptt_nombre], [ptt_orden]) VALUES (2, N'ESPACIO CONFINADO', N'Espacio confinado', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Tipo] WHERE [ptt_id] = 3)
    INSERT INTO [dbo].[Permiso_Trabajo_Tipo] ([ptt_id], [ptt_codigo], [ptt_nombre], [ptt_orden]) VALUES (3, N'TRABAJO CALIENTE', N'Trabajo caliente', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Tipo] WHERE [ptt_id] = 4)
    INSERT INTO [dbo].[Permiso_Trabajo_Tipo] ([ptt_id], [ptt_codigo], [ptt_nombre], [ptt_orden]) VALUES (4, N'ELECTRICO', N'Trabajo eléctrico', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Tipo] WHERE [ptt_id] = 5)
    INSERT INTO [dbo].[Permiso_Trabajo_Tipo] ([ptt_id], [ptt_codigo], [ptt_nombre], [ptt_orden]) VALUES (5, N'IZAJE', N'Izaje', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Tipo] WHERE [ptt_id] = 6)
    INSERT INTO [dbo].[Permiso_Trabajo_Tipo] ([ptt_id], [ptt_codigo], [ptt_nombre], [ptt_orden]) VALUES (6, N'BLOQUEO ENERGIA', N'Bloqueo de energía', 6)
SET IDENTITY_INSERT [dbo].[Permiso_Trabajo_Tipo] OFF
GO

-- Permiso_Trabajo_Estado (pte) — Ciclo de vida del permiso
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Permiso_Trabajo_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Permiso_Trabajo_Estado]
    (
        [pte_id]                      INT             NOT NULL IDENTITY(1,1),
        [pte_codigo]                  NVARCHAR(50)    NOT NULL,
        [pte_nombre]                  NVARCHAR(100)   NOT NULL,
        [pte_orden]                   INT             NULL,
        [pte_habilitado]              BIT             NOT NULL CONSTRAINT DF_PTE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PERMISO_TRABAJO_ESTADO PRIMARY KEY CLUSTERED ([pte_id] ASC),
        CONSTRAINT UX_PTE_CODIGO UNIQUE ([pte_codigo])
    )

    PRINT 'Tabla Permiso_Trabajo_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Permiso_Trabajo_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Permiso_Trabajo_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Estado] WHERE [pte_id] = 1)
    INSERT INTO [dbo].[Permiso_Trabajo_Estado] ([pte_id], [pte_codigo], [pte_nombre], [pte_orden]) VALUES (1, N'SOLICITADO', N'Solicitado', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Estado] WHERE [pte_id] = 2)
    INSERT INTO [dbo].[Permiso_Trabajo_Estado] ([pte_id], [pte_codigo], [pte_nombre], [pte_orden]) VALUES (2, N'AUTORIZADO', N'Autorizado', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Estado] WHERE [pte_id] = 3)
    INSERT INTO [dbo].[Permiso_Trabajo_Estado] ([pte_id], [pte_codigo], [pte_nombre], [pte_orden]) VALUES (3, N'RECHAZADO', N'Rechazado', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Estado] WHERE [pte_id] = 4)
    INSERT INTO [dbo].[Permiso_Trabajo_Estado] ([pte_id], [pte_codigo], [pte_nombre], [pte_orden]) VALUES (4, N'VENCIDO', N'Vencido', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo_Estado] WHERE [pte_id] = 5)
    INSERT INTO [dbo].[Permiso_Trabajo_Estado] ([pte_id], [pte_codigo], [pte_nombre], [pte_orden]) VALUES (5, N'CERRADO', N'Cerrado', 5)
SET IDENTITY_INSERT [dbo].[Permiso_Trabajo_Estado] OFF
GO

-- Diagnostico_Metodo (dme) — Como se diagnostico la falla
--   AMPLIABLE por cliente
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Diagnostico_Metodo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Diagnostico_Metodo]
    (
        [dme_id]                      INT             NOT NULL IDENTITY(1,1),
        [dme_cliente]                 INT             NULL,       -- NULL = global SIGMA
        [dme_codigo]                  NVARCHAR(50)    NOT NULL,
        [dme_nombre]                  NVARCHAR(100)   NOT NULL,
        [dme_orden]                   INT             NULL,
        [dme_usuario_creacion]        INT             NULL,
        [dme_fecha_creacion]          DATETIME        NULL CONSTRAINT DF_DME_FECHA_CREACION DEFAULT GETDATE(),
        [dme_usuario_actualizacion]   INT             NULL,
        [dme_fecha_actualizacion]     DATETIME        NULL,
        [dme_habilitado]              BIT             NOT NULL CONSTRAINT DF_DME_HABILITADO DEFAULT 1,

        CONSTRAINT PK_DIAGNOSTICO_METODO PRIMARY KEY CLUSTERED ([dme_id] ASC),
        CONSTRAINT FK_DME_CLIENTE FOREIGN KEY ([dme_cliente]) REFERENCES [dbo].[Cliente] ([cli_id])
    )

    -- El codigo es unico dentro del cliente; las globales van con cliente NULL.
    CREATE UNIQUE NONCLUSTERED INDEX UX_DME_CLIENTE_CODIGO
        ON [dbo].[Diagnostico_Metodo] ([dme_cliente], [dme_codigo])

    PRINT 'Tabla Diagnostico_Metodo creada correctamente.'
END
ELSE
    PRINT 'Tabla Diagnostico_Metodo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Diagnostico_Metodo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Diagnostico_Metodo] WHERE [dme_id] = 1)
    INSERT INTO [dbo].[Diagnostico_Metodo] ([dme_id], [dme_codigo], [dme_nombre], [dme_orden]) VALUES (1, N'INSPECCION VISUAL', N'Inspección visual', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Diagnostico_Metodo] WHERE [dme_id] = 2)
    INSERT INTO [dbo].[Diagnostico_Metodo] ([dme_id], [dme_codigo], [dme_nombre], [dme_orden]) VALUES (2, N'MEDICION', N'Medición', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Diagnostico_Metodo] WHERE [dme_id] = 3)
    INSERT INTO [dbo].[Diagnostico_Metodo] ([dme_id], [dme_codigo], [dme_nombre], [dme_orden]) VALUES (3, N'ANALISIS VIBRACION', N'Análisis de vibración', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Diagnostico_Metodo] WHERE [dme_id] = 4)
    INSERT INTO [dbo].[Diagnostico_Metodo] ([dme_id], [dme_codigo], [dme_nombre], [dme_orden]) VALUES (4, N'TERMOGRAFIA', N'Termografía', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Diagnostico_Metodo] WHERE [dme_id] = 5)
    INSERT INTO [dbo].[Diagnostico_Metodo] ([dme_id], [dme_codigo], [dme_nombre], [dme_orden]) VALUES (5, N'ANALISIS ACEITE', N'Análisis de aceite', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Diagnostico_Metodo] WHERE [dme_id] = 6)
    INSERT INTO [dbo].[Diagnostico_Metodo] ([dme_id], [dme_codigo], [dme_nombre], [dme_orden]) VALUES (6, N'ULTRASONIDO', N'Ultrasonido', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Diagnostico_Metodo] WHERE [dme_id] = 7)
    INSERT INTO [dbo].[Diagnostico_Metodo] ([dme_id], [dme_codigo], [dme_nombre], [dme_orden]) VALUES (7, N'DESARME', N'Desarme', 7)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Diagnostico_Metodo] WHERE [dme_id] = 8)
    INSERT INTO [dbo].[Diagnostico_Metodo] ([dme_id], [dme_codigo], [dme_nombre], [dme_orden]) VALUES (8, N'HISTORIAL', N'Historial', 8)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Diagnostico_Metodo] WHERE [dme_id] = 9)
    INSERT INTO [dbo].[Diagnostico_Metodo] ([dme_id], [dme_codigo], [dme_nombre], [dme_orden]) VALUES (9, N'ANALISIS IA', N'Análisis con IA', 9)
SET IDENTITY_INSERT [dbo].[Diagnostico_Metodo] OFF
GO

/* ========================================================================
   BITÁCORA
   ======================================================================== */

-- Bitacora_Tipo (bti) — Tipo de registro libre del tecnico
--   FIJO: el codigo depende de estos ids  ·  visible en la app: lleva icono e imagen
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Bitacora_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Bitacora_Tipo]
    (
        [bti_id]                      INT             NOT NULL IDENTITY(1,1),
        [bti_codigo]                  NVARCHAR(50)    NOT NULL,
        [bti_nombre]                  NVARCHAR(100)   NOT NULL,
        [bti_icono]                   NVARCHAR(50)    NULL,       -- icono del set de la app
        [bti_archivo]                 INT             NULL,       -- FK Archivo: foto real
        [bti_orden]                   INT             NULL,
        [bti_habilitado]              BIT             NOT NULL CONSTRAINT DF_BTI_HABILITADO DEFAULT 1,

        CONSTRAINT PK_BITACORA_TIPO PRIMARY KEY CLUSTERED ([bti_id] ASC),
        CONSTRAINT UX_BTI_CODIGO UNIQUE ([bti_codigo])
    )

    PRINT 'Tabla Bitacora_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Bitacora_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Bitacora_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Bitacora_Tipo] WHERE [bti_id] = 1)
    INSERT INTO [dbo].[Bitacora_Tipo] ([bti_id], [bti_codigo], [bti_nombre], [bti_orden]) VALUES (1, N'OBSERVACION', N'Observación', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Bitacora_Tipo] WHERE [bti_id] = 2)
    INSERT INTO [dbo].[Bitacora_Tipo] ([bti_id], [bti_codigo], [bti_nombre], [bti_orden]) VALUES (2, N'NOVEDAD', N'Novedad', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Bitacora_Tipo] WHERE [bti_id] = 3)
    INSERT INTO [dbo].[Bitacora_Tipo] ([bti_id], [bti_codigo], [bti_nombre], [bti_orden]) VALUES (3, N'INCIDENTE', N'Incidente', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Bitacora_Tipo] WHERE [bti_id] = 4)
    INSERT INTO [dbo].[Bitacora_Tipo] ([bti_id], [bti_codigo], [bti_nombre], [bti_orden]) VALUES (4, N'CAMBIO TURNO', N'Cambio de turno', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Bitacora_Tipo] WHERE [bti_id] = 5)
    INSERT INTO [dbo].[Bitacora_Tipo] ([bti_id], [bti_codigo], [bti_nombre], [bti_orden]) VALUES (5, N'HALLAZGO', N'Hallazgo', 5)
SET IDENTITY_INSERT [dbo].[Bitacora_Tipo] OFF
GO

/* ========================================================================
   ARCHIVOS Y ANÁLISIS VISUAL
   ======================================================================== */

-- Archivo_Categoria (aca) — Para que sirve el archivo
--   AMPLIABLE por cliente  ·  visible en la app: lleva icono e imagen
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Archivo_Categoria]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Archivo_Categoria]
    (
        [aca_id]                      INT             NOT NULL IDENTITY(1,1),
        [aca_cliente]                 INT             NULL,       -- NULL = global SIGMA
        [aca_codigo]                  NVARCHAR(50)    NOT NULL,
        [aca_nombre]                  NVARCHAR(100)   NOT NULL,
        [aca_icono]                   NVARCHAR(50)    NULL,       -- icono del set de la app
        [aca_archivo]                 INT             NULL,       -- FK Archivo: foto real
        [aca_orden]                   INT             NULL,
        [aca_usuario_creacion]        INT             NULL,
        [aca_fecha_creacion]          DATETIME        NULL CONSTRAINT DF_ACA_FECHA_CREACION DEFAULT GETDATE(),
        [aca_usuario_actualizacion]   INT             NULL,
        [aca_fecha_actualizacion]     DATETIME        NULL,
        [aca_habilitado]              BIT             NOT NULL CONSTRAINT DF_ACA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ARCHIVO_CATEGORIA PRIMARY KEY CLUSTERED ([aca_id] ASC),
        CONSTRAINT FK_ACA_CLIENTE FOREIGN KEY ([aca_cliente]) REFERENCES [dbo].[Cliente] ([cli_id])
    )

    -- El codigo es unico dentro del cliente; las globales van con cliente NULL.
    CREATE UNIQUE NONCLUSTERED INDEX UX_ACA_CLIENTE_CODIGO
        ON [dbo].[Archivo_Categoria] ([aca_cliente], [aca_codigo])

    PRINT 'Tabla Archivo_Categoria creada correctamente.'
END
ELSE
    PRINT 'Tabla Archivo_Categoria ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Archivo_Categoria] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria] WHERE [aca_id] = 1)
    INSERT INTO [dbo].[Archivo_Categoria] ([aca_id], [aca_codigo], [aca_nombre], [aca_orden]) VALUES (1, N'ESTADO MAQUINA', N'Estado de la máquina', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria] WHERE [aca_id] = 2)
    INSERT INTO [dbo].[Archivo_Categoria] ([aca_id], [aca_codigo], [aca_nombre], [aca_orden]) VALUES (2, N'FALLA', N'Falla', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria] WHERE [aca_id] = 3)
    INSERT INTO [dbo].[Archivo_Categoria] ([aca_id], [aca_codigo], [aca_nombre], [aca_orden]) VALUES (3, N'REPUESTO DETERIORADO', N'Repuesto deteriorado', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria] WHERE [aca_id] = 4)
    INSERT INTO [dbo].[Archivo_Categoria] ([aca_id], [aca_codigo], [aca_nombre], [aca_orden]) VALUES (4, N'ANTES', N'Antes', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria] WHERE [aca_id] = 5)
    INSERT INTO [dbo].[Archivo_Categoria] ([aca_id], [aca_codigo], [aca_nombre], [aca_orden]) VALUES (5, N'DURANTE', N'Durante', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria] WHERE [aca_id] = 6)
    INSERT INTO [dbo].[Archivo_Categoria] ([aca_id], [aca_codigo], [aca_nombre], [aca_orden]) VALUES (6, N'DESPUES', N'Después', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria] WHERE [aca_id] = 7)
    INSERT INTO [dbo].[Archivo_Categoria] ([aca_id], [aca_codigo], [aca_nombre], [aca_orden]) VALUES (7, N'BITACORA', N'Bitácora', 7)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria] WHERE [aca_id] = 8)
    INSERT INTO [dbo].[Archivo_Categoria] ([aca_id], [aca_codigo], [aca_nombre], [aca_orden]) VALUES (8, N'FIRMA', N'Firma', 8)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria] WHERE [aca_id] = 9)
    INSERT INTO [dbo].[Archivo_Categoria] ([aca_id], [aca_codigo], [aca_nombre], [aca_orden]) VALUES (9, N'DOCUMENTO', N'Documento', 9)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria] WHERE [aca_id] = 10)
    INSERT INTO [dbo].[Archivo_Categoria] ([aca_id], [aca_codigo], [aca_nombre], [aca_orden]) VALUES (10, N'REFERENCIA', N'Imagen de referencia', 10)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria] WHERE [aca_id] = 11)
    INSERT INTO [dbo].[Archivo_Categoria] ([aca_id], [aca_codigo], [aca_nombre], [aca_orden]) VALUES (11, N'AUDIO', N'Audio', 11)
SET IDENTITY_INSERT [dbo].[Archivo_Categoria] OFF
GO

-- Archivo_Antivirus_Estado (aae) — Resultado del escaneo del archivo
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Archivo_Antivirus_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Archivo_Antivirus_Estado]
    (
        [aae_id]                      INT             NOT NULL IDENTITY(1,1),
        [aae_codigo]                  NVARCHAR(50)    NOT NULL,
        [aae_nombre]                  NVARCHAR(100)   NOT NULL,
        [aae_orden]                   INT             NULL,
        [aae_habilitado]              BIT             NOT NULL CONSTRAINT DF_AAE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ARCHIVO_ANTIVIRUS_ESTADO PRIMARY KEY CLUSTERED ([aae_id] ASC),
        CONSTRAINT UX_AAE_CODIGO UNIQUE ([aae_codigo])
    )

    PRINT 'Tabla Archivo_Antivirus_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Archivo_Antivirus_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Archivo_Antivirus_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Antivirus_Estado] WHERE [aae_id] = 1)
    INSERT INTO [dbo].[Archivo_Antivirus_Estado] ([aae_id], [aae_codigo], [aae_nombre], [aae_orden]) VALUES (1, N'PENDIENTE', N'Pendiente', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Antivirus_Estado] WHERE [aae_id] = 2)
    INSERT INTO [dbo].[Archivo_Antivirus_Estado] ([aae_id], [aae_codigo], [aae_nombre], [aae_orden]) VALUES (2, N'LIMPIO', N'Limpio', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Antivirus_Estado] WHERE [aae_id] = 3)
    INSERT INTO [dbo].[Archivo_Antivirus_Estado] ([aae_id], [aae_codigo], [aae_nombre], [aae_orden]) VALUES (3, N'INFECTADO', N'Infectado', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Antivirus_Estado] WHERE [aae_id] = 4)
    INSERT INTO [dbo].[Archivo_Antivirus_Estado] ([aae_id], [aae_codigo], [aae_nombre], [aae_orden]) VALUES (4, N'ERROR', N'Error', 4)
SET IDENTITY_INSERT [dbo].[Archivo_Antivirus_Estado] OFF
GO

-- Archivo_Carga_Estado (acs) — Estado de una carga reanudable desde la app
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Archivo_Carga_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Archivo_Carga_Estado]
    (
        [acs_id]                      INT             NOT NULL IDENTITY(1,1),
        [acs_codigo]                  NVARCHAR(50)    NOT NULL,
        [acs_nombre]                  NVARCHAR(100)   NOT NULL,
        [acs_orden]                   INT             NULL,
        [acs_habilitado]              BIT             NOT NULL CONSTRAINT DF_ACS_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ARCHIVO_CARGA_ESTADO PRIMARY KEY CLUSTERED ([acs_id] ASC),
        CONSTRAINT UX_ACS_CODIGO UNIQUE ([acs_codigo])
    )

    PRINT 'Tabla Archivo_Carga_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Archivo_Carga_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Archivo_Carga_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Carga_Estado] WHERE [acs_id] = 1)
    INSERT INTO [dbo].[Archivo_Carga_Estado] ([acs_id], [acs_codigo], [acs_nombre], [acs_orden]) VALUES (1, N'INICIADA', N'Iniciada', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Carga_Estado] WHERE [acs_id] = 2)
    INSERT INTO [dbo].[Archivo_Carga_Estado] ([acs_id], [acs_codigo], [acs_nombre], [acs_orden]) VALUES (2, N'EN CURSO', N'En curso', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Carga_Estado] WHERE [acs_id] = 3)
    INSERT INTO [dbo].[Archivo_Carga_Estado] ([acs_id], [acs_codigo], [acs_nombre], [acs_orden]) VALUES (3, N'COMPLETADA', N'Completada', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Carga_Estado] WHERE [acs_id] = 4)
    INSERT INTO [dbo].[Archivo_Carga_Estado] ([acs_id], [acs_codigo], [acs_nombre], [acs_orden]) VALUES (4, N'EXPIRADA', N'Expirada', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Carga_Estado] WHERE [acs_id] = 5)
    INSERT INTO [dbo].[Archivo_Carga_Estado] ([acs_id], [acs_codigo], [acs_nombre], [acs_orden]) VALUES (5, N'CANCELADA', N'Cancelada', 5)
SET IDENTITY_INSERT [dbo].[Archivo_Carga_Estado] OFF
GO

/* ========================================================================
   ALERTAS
   ======================================================================== */

-- Alerta_Tipo (alt) — Que origino la alerta
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Alerta_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Alerta_Tipo]
    (
        [alt_id]                      INT             NOT NULL IDENTITY(1,1),
        [alt_codigo]                  NVARCHAR(50)    NOT NULL,
        [alt_nombre]                  NVARCHAR(100)   NOT NULL,
        [alt_orden]                   INT             NULL,
        [alt_habilitado]              BIT             NOT NULL CONSTRAINT DF_ALT_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ALERTA_TIPO PRIMARY KEY CLUSTERED ([alt_id] ASC),
        CONSTRAINT UX_ALT_CODIGO UNIQUE ([alt_codigo])
    )

    PRINT 'Tabla Alerta_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Alerta_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Alerta_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE [alt_id] = 1)
    INSERT INTO [dbo].[Alerta_Tipo] ([alt_id], [alt_codigo], [alt_nombre], [alt_orden]) VALUES (1, N'MEDICION FUERA RANGO', N'Medición fuera de rango', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE [alt_id] = 2)
    INSERT INTO [dbo].[Alerta_Tipo] ([alt_id], [alt_codigo], [alt_nombre], [alt_orden]) VALUES (2, N'HALLAZGO CRITICO', N'Hallazgo crítico', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE [alt_id] = 3)
    INSERT INTO [dbo].[Alerta_Tipo] ([alt_id], [alt_codigo], [alt_nombre], [alt_orden]) VALUES (3, N'OCURRENCIA VENCIDA', N'Ocurrencia vencida', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE [alt_id] = 4)
    INSERT INTO [dbo].[Alerta_Tipo] ([alt_id], [alt_codigo], [alt_nombre], [alt_orden]) VALUES (4, N'PREDICCION RIESGO', N'Predicción de riesgo', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE [alt_id] = 5)
    INSERT INTO [dbo].[Alerta_Tipo] ([alt_id], [alt_codigo], [alt_nombre], [alt_orden]) VALUES (5, N'STOCK MINIMO', N'Stock bajo el mínimo', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE [alt_id] = 6)
    INSERT INTO [dbo].[Alerta_Tipo] ([alt_id], [alt_codigo], [alt_nombre], [alt_orden]) VALUES (6, N'PERMISO VENCIDO', N'Permiso vencido', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE [alt_id] = 7)
    INSERT INTO [dbo].[Alerta_Tipo] ([alt_id], [alt_codigo], [alt_nombre], [alt_orden]) VALUES (7, N'MEDIDOR SIN LECTURA', N'Medidor sin lectura', 7)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE [alt_id] = 9)
    INSERT INTO [dbo].[Alerta_Tipo] ([alt_id], [alt_codigo], [alt_nombre], [alt_orden]) VALUES (9, N'MEDIDOR PROXIMO MANTENIMIENTO', N'Se acerca la hora de mantenimiento', 9)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE [alt_id] = 10)
    INSERT INTO [dbo].[Alerta_Tipo] ([alt_id], [alt_codigo], [alt_nombre], [alt_orden]) VALUES (10, N'STOCK MAXIMO', N'Stock sobre el máximo', 10)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE [alt_id] = 8)
    INSERT INTO [dbo].[Alerta_Tipo] ([alt_id], [alt_codigo], [alt_nombre], [alt_orden]) VALUES (8, N'DESCUBRIMIENTO TERRENO', N'Registro creado en terreno sin revisar', 8)
SET IDENTITY_INSERT [dbo].[Alerta_Tipo] OFF
GO

-- Alerta_Estado (aet) — Ciclo de vida de la alerta
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Alerta_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Alerta_Estado]
    (
        [aet_id]                      INT             NOT NULL IDENTITY(1,1),
        [aet_codigo]                  NVARCHAR(50)    NOT NULL,
        [aet_nombre]                  NVARCHAR(100)   NOT NULL,
        [aet_orden]                   INT             NULL,
        [aet_habilitado]              BIT             NOT NULL CONSTRAINT DF_AET_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ALERTA_ESTADO PRIMARY KEY CLUSTERED ([aet_id] ASC),
        CONSTRAINT UX_AET_CODIGO UNIQUE ([aet_codigo])
    )

    PRINT 'Tabla Alerta_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Alerta_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Alerta_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Estado] WHERE [aet_id] = 1)
    INSERT INTO [dbo].[Alerta_Estado] ([aet_id], [aet_codigo], [aet_nombre], [aet_orden]) VALUES (1, N'NUEVA', N'Nueva', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Estado] WHERE [aet_id] = 2)
    INSERT INTO [dbo].[Alerta_Estado] ([aet_id], [aet_codigo], [aet_nombre], [aet_orden]) VALUES (2, N'RECONOCIDA', N'Reconocida', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Estado] WHERE [aet_id] = 3)
    INSERT INTO [dbo].[Alerta_Estado] ([aet_id], [aet_codigo], [aet_nombre], [aet_orden]) VALUES (3, N'EN GESTION', N'En gestión', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Estado] WHERE [aet_id] = 4)
    INSERT INTO [dbo].[Alerta_Estado] ([aet_id], [aet_codigo], [aet_nombre], [aet_orden]) VALUES (4, N'RESUELTA', N'Resuelta', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Estado] WHERE [aet_id] = 5)
    INSERT INTO [dbo].[Alerta_Estado] ([aet_id], [aet_codigo], [aet_nombre], [aet_orden]) VALUES (5, N'DESCARTADA', N'Descartada', 5)
SET IDENTITY_INSERT [dbo].[Alerta_Estado] OFF
GO

/* ========================================================================
   MACHINE LEARNING
   ======================================================================== */

-- Modelo_Objetivo (mob) — Que predice el modelo
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Modelo_Objetivo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Modelo_Objetivo]
    (
        [mob_id]                      INT             NOT NULL IDENTITY(1,1),
        [mob_codigo]                  NVARCHAR(50)    NOT NULL,
        [mob_nombre]                  NVARCHAR(100)   NOT NULL,
        [mob_orden]                   INT             NULL,
        [mob_habilitado]              BIT             NOT NULL CONSTRAINT DF_MOB_HABILITADO DEFAULT 1,

        CONSTRAINT PK_MODELO_OBJETIVO PRIMARY KEY CLUSTERED ([mob_id] ASC),
        CONSTRAINT UX_MOB_CODIGO UNIQUE ([mob_codigo])
    )

    PRINT 'Tabla Modelo_Objetivo creada correctamente.'
END
ELSE
    PRINT 'Tabla Modelo_Objetivo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Modelo_Objetivo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Modelo_Objetivo] WHERE [mob_id] = 1)
    INSERT INTO [dbo].[Modelo_Objetivo] ([mob_id], [mob_codigo], [mob_nombre], [mob_orden]) VALUES (1, N'PROBABILIDAD FALLA', N'Probabilidad de falla', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Modelo_Objetivo] WHERE [mob_id] = 2)
    INSERT INTO [dbo].[Modelo_Objetivo] ([mob_id], [mob_codigo], [mob_nombre], [mob_orden]) VALUES (2, N'VIDA UTIL RESTANTE', N'Vida útil restante', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Modelo_Objetivo] WHERE [mob_id] = 3)
    INSERT INTO [dbo].[Modelo_Objetivo] ([mob_id], [mob_codigo], [mob_nombre], [mob_orden]) VALUES (3, N'DETECCION ANOMALIA', N'Detección de anomalía', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Modelo_Objetivo] WHERE [mob_id] = 4)
    INSERT INTO [dbo].[Modelo_Objetivo] ([mob_id], [mob_codigo], [mob_nombre], [mob_orden]) VALUES (4, N'CLASIFICACION VISUAL', N'Clasificación visual', 4)
SET IDENTITY_INSERT [dbo].[Modelo_Objetivo] OFF
GO

-- Modelo_Formato (mfo) — Formato del artefacto del modelo
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Modelo_Formato]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Modelo_Formato]
    (
        [mfo_id]                      INT             NOT NULL IDENTITY(1,1),
        [mfo_codigo]                  NVARCHAR(50)    NOT NULL,
        [mfo_nombre]                  NVARCHAR(100)   NOT NULL,
        [mfo_orden]                   INT             NULL,
        [mfo_habilitado]              BIT             NOT NULL CONSTRAINT DF_MFO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_MODELO_FORMATO PRIMARY KEY CLUSTERED ([mfo_id] ASC),
        CONSTRAINT UX_MFO_CODIGO UNIQUE ([mfo_codigo])
    )

    PRINT 'Tabla Modelo_Formato creada correctamente.'
END
ELSE
    PRINT 'Tabla Modelo_Formato ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Modelo_Formato] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Modelo_Formato] WHERE [mfo_id] = 1)
    INSERT INTO [dbo].[Modelo_Formato] ([mfo_id], [mfo_codigo], [mfo_nombre], [mfo_orden]) VALUES (1, N'ONNX', N'ONNX', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Modelo_Formato] WHERE [mfo_id] = 2)
    INSERT INTO [dbo].[Modelo_Formato] ([mfo_id], [mfo_codigo], [mfo_nombre], [mfo_orden]) VALUES (2, N'PICKLE', N'Pickle', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Modelo_Formato] WHERE [mfo_id] = 3)
    INSERT INTO [dbo].[Modelo_Formato] ([mfo_id], [mfo_codigo], [mfo_nombre], [mfo_orden]) VALUES (3, N'PMML', N'PMML', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Modelo_Formato] WHERE [mfo_id] = 4)
    INSERT INTO [dbo].[Modelo_Formato] ([mfo_id], [mfo_codigo], [mfo_nombre], [mfo_orden]) VALUES (4, N'SAVEDMODEL', N'SavedModel', 4)
SET IDENTITY_INSERT [dbo].[Modelo_Formato] OFF
GO

-- Prediccion_Estado (pde) — Ciclo de vida de una prediccion
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Prediccion_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Prediccion_Estado]
    (
        [pde_id]                      INT             NOT NULL IDENTITY(1,1),
        [pde_codigo]                  NVARCHAR(50)    NOT NULL,
        [pde_nombre]                  NVARCHAR(100)   NOT NULL,
        [pde_orden]                   INT             NULL,
        [pde_habilitado]              BIT             NOT NULL CONSTRAINT DF_PDE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PREDICCION_ESTADO PRIMARY KEY CLUSTERED ([pde_id] ASC),
        CONSTRAINT UX_PDE_CODIGO UNIQUE ([pde_codigo])
    )

    PRINT 'Tabla Prediccion_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Prediccion_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Prediccion_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Prediccion_Estado] WHERE [pde_id] = 1)
    INSERT INTO [dbo].[Prediccion_Estado] ([pde_id], [pde_codigo], [pde_nombre], [pde_orden]) VALUES (1, N'GENERADA', N'Generada', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Prediccion_Estado] WHERE [pde_id] = 2)
    INSERT INTO [dbo].[Prediccion_Estado] ([pde_id], [pde_codigo], [pde_nombre], [pde_orden]) VALUES (2, N'REVISADA', N'Revisada', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Prediccion_Estado] WHERE [pde_id] = 3)
    INSERT INTO [dbo].[Prediccion_Estado] ([pde_id], [pde_codigo], [pde_nombre], [pde_orden]) VALUES (3, N'ACEPTADA', N'Aceptada', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Prediccion_Estado] WHERE [pde_id] = 4)
    INSERT INTO [dbo].[Prediccion_Estado] ([pde_id], [pde_codigo], [pde_nombre], [pde_orden]) VALUES (4, N'DESCARTADA', N'Descartada', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Prediccion_Estado] WHERE [pde_id] = 5)
    INSERT INTO [dbo].[Prediccion_Estado] ([pde_id], [pde_codigo], [pde_nombre], [pde_orden]) VALUES (5, N'MATERIALIZADA', N'Materializada', 5)
SET IDENTITY_INSERT [dbo].[Prediccion_Estado] OFF
GO

-- Caracteristica_Tipo (ctm) — Tipo de feature del modelo
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Caracteristica_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Caracteristica_Tipo]
    (
        [ctm_id]                      INT             NOT NULL IDENTITY(1,1),
        [ctm_codigo]                  NVARCHAR(50)    NOT NULL,
        [ctm_nombre]                  NVARCHAR(100)   NOT NULL,
        [ctm_orden]                   INT             NULL,
        [ctm_habilitado]              BIT             NOT NULL CONSTRAINT DF_CTM_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CARACTERISTICA_TIPO PRIMARY KEY CLUSTERED ([ctm_id] ASC),
        CONSTRAINT UX_CTM_CODIGO UNIQUE ([ctm_codigo])
    )

    PRINT 'Tabla Caracteristica_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Caracteristica_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Caracteristica_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Caracteristica_Tipo] WHERE [ctm_id] = 1)
    INSERT INTO [dbo].[Caracteristica_Tipo] ([ctm_id], [ctm_codigo], [ctm_nombre], [ctm_orden]) VALUES (1, N'NUMERICA', N'Numérica', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Caracteristica_Tipo] WHERE [ctm_id] = 2)
    INSERT INTO [dbo].[Caracteristica_Tipo] ([ctm_id], [ctm_codigo], [ctm_nombre], [ctm_orden]) VALUES (2, N'CATEGORICA', N'Categórica', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Caracteristica_Tipo] WHERE [ctm_id] = 3)
    INSERT INTO [dbo].[Caracteristica_Tipo] ([ctm_id], [ctm_codigo], [ctm_nombre], [ctm_orden]) VALUES (3, N'BINARIA', N'Binaria', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Caracteristica_Tipo] WHERE [ctm_id] = 4)
    INSERT INTO [dbo].[Caracteristica_Tipo] ([ctm_id], [ctm_codigo], [ctm_nombre], [ctm_orden]) VALUES (4, N'TEMPORAL', N'Temporal', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Caracteristica_Tipo] WHERE [ctm_id] = 5)
    INSERT INTO [dbo].[Caracteristica_Tipo] ([ctm_id], [ctm_codigo], [ctm_nombre], [ctm_orden]) VALUES (5, N'DERIVADA', N'Derivada', 5)
SET IDENTITY_INSERT [dbo].[Caracteristica_Tipo] OFF
GO

/* ========================================================================
   IMPORTACIÓN Y DESCUBRIMIENTO
   ======================================================================== */

-- Importacion_Tipo (iti) — Que se esta importando
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Importacion_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Importacion_Tipo]
    (
        [iti_id]                      INT             NOT NULL IDENTITY(1,1),
        [iti_codigo]                  NVARCHAR(50)    NOT NULL,
        [iti_nombre]                  NVARCHAR(100)   NOT NULL,
        [iti_orden]                   INT             NULL,
        [iti_habilitado]              BIT             NOT NULL CONSTRAINT DF_ITI_HABILITADO DEFAULT 1,

        CONSTRAINT PK_IMPORTACION_TIPO PRIMARY KEY CLUSTERED ([iti_id] ASC),
        CONSTRAINT UX_ITI_CODIGO UNIQUE ([iti_codigo])
    )

    PRINT 'Tabla Importacion_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Importacion_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Importacion_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Importacion_Tipo] WHERE [iti_id] = 1)
    INSERT INTO [dbo].[Importacion_Tipo] ([iti_id], [iti_codigo], [iti_nombre], [iti_orden]) VALUES (1, N'MATRIZ OT', N'Matriz de OT', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Importacion_Tipo] WHERE [iti_id] = 2)
    INSERT INTO [dbo].[Importacion_Tipo] ([iti_id], [iti_codigo], [iti_nombre], [iti_orden]) VALUES (2, N'PLAN ANUAL', N'Plan anual', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Importacion_Tipo] WHERE [iti_id] = 3)
    INSERT INTO [dbo].[Importacion_Tipo] ([iti_id], [iti_codigo], [iti_nombre], [iti_orden]) VALUES (3, N'ACTIVOS', N'Activos', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Importacion_Tipo] WHERE [iti_id] = 4)
    INSERT INTO [dbo].[Importacion_Tipo] ([iti_id], [iti_codigo], [iti_nombre], [iti_orden]) VALUES (4, N'REPUESTOS', N'Repuestos', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Importacion_Tipo] WHERE [iti_id] = 5)
    INSERT INTO [dbo].[Importacion_Tipo] ([iti_id], [iti_codigo], [iti_nombre], [iti_orden]) VALUES (5, N'LECTURAS MEDIDOR', N'Lecturas de medidor', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Importacion_Tipo] WHERE [iti_id] = 6)
    INSERT INTO [dbo].[Importacion_Tipo] ([iti_id], [iti_codigo], [iti_nombre], [iti_orden]) VALUES (6, N'MEDICIONES', N'Mediciones', 6)
SET IDENTITY_INSERT [dbo].[Importacion_Tipo] OFF
GO

-- Importacion_Celda_Estado (ice) — Como quedo cada celda leida
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Importacion_Celda_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Importacion_Celda_Estado]
    (
        [ice_id]                      INT             NOT NULL IDENTITY(1,1),
        [ice_codigo]                  NVARCHAR(50)    NOT NULL,
        [ice_nombre]                  NVARCHAR(100)   NOT NULL,
        [ice_orden]                   INT             NULL,
        [ice_habilitado]              BIT             NOT NULL CONSTRAINT DF_ICE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_IMPORTACION_CELDA_ESTADO PRIMARY KEY CLUSTERED ([ice_id] ASC),
        CONSTRAINT UX_ICE_CODIGO UNIQUE ([ice_codigo])
    )

    PRINT 'Tabla Importacion_Celda_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Importacion_Celda_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Importacion_Celda_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Importacion_Celda_Estado] WHERE [ice_id] = 1)
    INSERT INTO [dbo].[Importacion_Celda_Estado] ([ice_id], [ice_codigo], [ice_nombre], [ice_orden]) VALUES (1, N'OK', N'Correcta', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Importacion_Celda_Estado] WHERE [ice_id] = 2)
    INSERT INTO [dbo].[Importacion_Celda_Estado] ([ice_id], [ice_codigo], [ice_nombre], [ice_orden]) VALUES (2, N'AMBIGUO', N'Ambigua', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Importacion_Celda_Estado] WHERE [ice_id] = 3)
    INSERT INTO [dbo].[Importacion_Celda_Estado] ([ice_id], [ice_codigo], [ice_nombre], [ice_orden]) VALUES (3, N'ERROR', N'Con error', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Importacion_Celda_Estado] WHERE [ice_id] = 4)
    INSERT INTO [dbo].[Importacion_Celda_Estado] ([ice_id], [ice_codigo], [ice_nombre], [ice_orden]) VALUES (4, N'IGNORADO', N'Ignorada', 4)
SET IDENTITY_INSERT [dbo].[Importacion_Celda_Estado] OFF
GO

-- Registro_Origen (ror) — Como nacio un registro de maestro
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Registro_Origen]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Registro_Origen]
    (
        [ror_id]                      INT             NOT NULL IDENTITY(1,1),
        [ror_codigo]                  NVARCHAR(50)    NOT NULL,
        [ror_nombre]                  NVARCHAR(100)   NOT NULL,
        [ror_orden]                   INT             NULL,
        [ror_habilitado]              BIT             NOT NULL CONSTRAINT DF_ROR_HABILITADO DEFAULT 1,

        CONSTRAINT PK_REGISTRO_ORIGEN PRIMARY KEY CLUSTERED ([ror_id] ASC),
        CONSTRAINT UX_ROR_CODIGO UNIQUE ([ror_codigo])
    )

    PRINT 'Tabla Registro_Origen creada correctamente.'
END
ELSE
    PRINT 'Tabla Registro_Origen ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Registro_Origen] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Registro_Origen] WHERE [ror_id] = 1)
    INSERT INTO [dbo].[Registro_Origen] ([ror_id], [ror_codigo], [ror_nombre], [ror_orden]) VALUES (1, N'CARGA INICIAL', N'Carga inicial', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Registro_Origen] WHERE [ror_id] = 2)
    INSERT INTO [dbo].[Registro_Origen] ([ror_id], [ror_codigo], [ror_nombre], [ror_orden]) VALUES (2, N'PLANIFICADOR WEB', N'Planificador desde la web', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Registro_Origen] WHERE [ror_id] = 3)
    INSERT INTO [dbo].[Registro_Origen] ([ror_id], [ror_codigo], [ror_nombre], [ror_orden]) VALUES (3, N'TERRENO ORDEN TRABAJO', N'Terreno, durante una orden de trabajo', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Registro_Origen] WHERE [ror_id] = 4)
    INSERT INTO [dbo].[Registro_Origen] ([ror_id], [ror_codigo], [ror_nombre], [ror_orden]) VALUES (4, N'TERRENO TAREA', N'Terreno, durante una tarea', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Registro_Origen] WHERE [ror_id] = 5)
    INSERT INTO [dbo].[Registro_Origen] ([ror_id], [ror_codigo], [ror_nombre], [ror_orden]) VALUES (5, N'TERRENO CHECKLIST', N'Terreno, durante un checklist', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Registro_Origen] WHERE [ror_id] = 6)
    INSERT INTO [dbo].[Registro_Origen] ([ror_id], [ror_codigo], [ror_nombre], [ror_orden]) VALUES (6, N'TERRENO BITACORA', N'Terreno, desde la bitácora', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Registro_Origen] WHERE [ror_id] = 7)
    INSERT INTO [dbo].[Registro_Origen] ([ror_id], [ror_codigo], [ror_nombre], [ror_orden]) VALUES (7, N'IMPORTACION EXCEL', N'Importación desde Excel', 7)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Registro_Origen] WHERE [ror_id] = 8)
    INSERT INTO [dbo].[Registro_Origen] ([ror_id], [ror_codigo], [ror_nombre], [ror_orden]) VALUES (8, N'API EXTERNA', N'API externa', 8)
SET IDENTITY_INSERT [dbo].[Registro_Origen] OFF
GO

/* ========================================================================
   VOZ E INCLUSIÓN
   ======================================================================== */

-- Entrada_Modo (emo) — Como se ingreso un dato
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Entrada_Modo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Entrada_Modo]
    (
        [emo_id]                      INT             NOT NULL IDENTITY(1,1),
        [emo_codigo]                  NVARCHAR(50)    NOT NULL,
        [emo_nombre]                  NVARCHAR(100)   NOT NULL,
        [emo_orden]                   INT             NULL,
        [emo_habilitado]              BIT             NOT NULL CONSTRAINT DF_EMO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ENTRADA_MODO PRIMARY KEY CLUSTERED ([emo_id] ASC),
        CONSTRAINT UX_EMO_CODIGO UNIQUE ([emo_codigo])
    )

    PRINT 'Tabla Entrada_Modo creada correctamente.'
END
ELSE
    PRINT 'Tabla Entrada_Modo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Entrada_Modo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Entrada_Modo] WHERE [emo_id] = 1)
    INSERT INTO [dbo].[Entrada_Modo] ([emo_id], [emo_codigo], [emo_nombre], [emo_orden]) VALUES (1, N'TECLADO', N'Teclado', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Entrada_Modo] WHERE [emo_id] = 2)
    INSERT INTO [dbo].[Entrada_Modo] ([emo_id], [emo_codigo], [emo_nombre], [emo_orden]) VALUES (2, N'VOZ', N'Dictado por voz', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Entrada_Modo] WHERE [emo_id] = 3)
    INSERT INTO [dbo].[Entrada_Modo] ([emo_id], [emo_codigo], [emo_nombre], [emo_orden]) VALUES (3, N'SELECCION', N'Selección de lista', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Entrada_Modo] WHERE [emo_id] = 4)
    INSERT INTO [dbo].[Entrada_Modo] ([emo_id], [emo_codigo], [emo_nombre], [emo_orden]) VALUES (4, N'ESCANEO QR', N'Escaneo de QR', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Entrada_Modo] WHERE [emo_id] = 5)
    INSERT INTO [dbo].[Entrada_Modo] ([emo_id], [emo_codigo], [emo_nombre], [emo_orden]) VALUES (5, N'SENSOR', N'Sensor', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Entrada_Modo] WHERE [emo_id] = 6)
    INSERT INTO [dbo].[Entrada_Modo] ([emo_id], [emo_codigo], [emo_nombre], [emo_orden]) VALUES (6, N'IMPORTACION', N'Importación', 6)
SET IDENTITY_INSERT [dbo].[Entrada_Modo] OFF
GO

/* ========================================================================
   MODELO COMERCIAL
   ======================================================================== */

-- Funcionalidad_Tipo (fnt) — Si la funcionalidad se incluye o se limita
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Funcionalidad_Tipo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Funcionalidad_Tipo]
    (
        [fnt_id]                      INT             NOT NULL IDENTITY(1,1),
        [fnt_codigo]                  NVARCHAR(50)    NOT NULL,
        [fnt_nombre]                  NVARCHAR(100)   NOT NULL,
        [fnt_orden]                   INT             NULL,
        [fnt_habilitado]              BIT             NOT NULL CONSTRAINT DF_FNT_HABILITADO DEFAULT 1,

        CONSTRAINT PK_FUNCIONALIDAD_TIPO PRIMARY KEY CLUSTERED ([fnt_id] ASC),
        CONSTRAINT UX_FNT_CODIGO UNIQUE ([fnt_codigo])
    )

    PRINT 'Tabla Funcionalidad_Tipo creada correctamente.'
END
ELSE
    PRINT 'Tabla Funcionalidad_Tipo ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Funcionalidad_Tipo] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad_Tipo] WHERE [fnt_id] = 1)
    INSERT INTO [dbo].[Funcionalidad_Tipo] ([fnt_id], [fnt_codigo], [fnt_nombre], [fnt_orden]) VALUES (1, N'INCLUSION', N'Se incluye o no', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad_Tipo] WHERE [fnt_id] = 2)
    INSERT INTO [dbo].[Funcionalidad_Tipo] ([fnt_id], [fnt_codigo], [fnt_nombre], [fnt_orden]) VALUES (2, N'LIMITE', N'Tiene un tope numérico', 2)
SET IDENTITY_INSERT [dbo].[Funcionalidad_Tipo] OFF
GO

-- Funcionalidad (fun) — Que puede hacer un cliente segun su plan
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Funcionalidad]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Funcionalidad]
    (
        [fun_id]                      INT             NOT NULL IDENTITY(1,1),
        [fun_codigo]                  NVARCHAR(50)    NOT NULL,
        [fun_nombre]                  NVARCHAR(100)   NOT NULL,
        [fun_orden]                   INT             NULL,
        [fun_habilitado]              BIT             NOT NULL CONSTRAINT DF_FUN_HABILITADO DEFAULT 1,

        CONSTRAINT PK_FUNCIONALIDAD PRIMARY KEY CLUSTERED ([fun_id] ASC),
        CONSTRAINT UX_FUN_CODIGO UNIQUE ([fun_codigo])
    )

    PRINT 'Tabla Funcionalidad creada correctamente.'
END
ELSE
    PRINT 'Tabla Funcionalidad ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Funcionalidad] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 1)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (1, N'GESTION ACTIVOS', N'Gestión de activos y componentes', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 2)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (2, N'CHECKLIST DINAMICO', N'Checklist dinámico', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 3)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (3, N'TAREAS', N'Tareas', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 4)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (4, N'ORDEN TRABAJO', N'Órdenes de trabajo', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 5)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (5, N'PLAN MANTENIMIENTO', N'Planes de mantenimiento', 5)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 6)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (6, N'PROGRAMACION CALENDARIO', N'Programación por calendario', 6)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 7)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (7, N'PROGRAMACION MEDIDOR', N'Programación por horómetro o ciclos', 7)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 8)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (8, N'BITACORA', N'Bitácora del técnico', 8)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 9)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (9, N'EVIDENCIA FOTOGRAFICA', N'Evidencia fotográfica', 9)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 10)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (10, N'REGISTRO TERRENO', N'Registro de maestros desde terreno', 10)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 11)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (11, N'CREACION POR VOZ', N'Creación y dictado por voz', 11)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 12)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (12, N'LECTURA POR VOZ', N'Lectura en voz alta e inclusión', 12)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 13)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (13, N'IMPORTACION EXCEL', N'Importación desde Excel', 13)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 14)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (14, N'INVENTARIO REPUESTOS', N'Inventario de repuestos', 14)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 15)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (15, N'SERVICIOS EXTERNOS', N'Proveedores y servicios contratados', 15)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 16)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (16, N'PERMISO TRABAJO', N'Permisos de trabajo', 16)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 17)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (17, N'ANALISIS VISUAL', N'Análisis visual de fotografías', 17)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 18)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (18, N'ANALISIS PREDICTIVO', N'Predicción de fallas', 18)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 19)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (19, N'VIDA UTIL RESTANTE', N'Estimación de vida útil restante', 19)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 20)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (20, N'API EXTERNA', N'API para integrar con otros sistemas', 20)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 21)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (21, N'INDICADORES AVANZADOS', N'Indicadores avanzados y exportación', 21)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 22)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (22, N'LIMITE PLANTAS', N'Máximo de plantas', 22)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 23)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (23, N'LIMITE USUARIOS', N'Máximo de usuarios', 23)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 24)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (24, N'LIMITE ACTIVOS', N'Máximo de activos', 24)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Funcionalidad] WHERE [fun_id] = 25)
    INSERT INTO [dbo].[Funcionalidad] ([fun_id], [fun_codigo], [fun_nombre], [fun_orden]) VALUES (25, N'LIMITE ALMACENAMIENTO', N'Máximo de almacenamiento en GB', 25)
SET IDENTITY_INSERT [dbo].[Funcionalidad] OFF
GO

-- Periodicidad_Cobro (pcb) — Cada cuanto se renueva la suscripcion
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Periodicidad_Cobro]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Periodicidad_Cobro]
    (
        [pcb_id]                      INT             NOT NULL IDENTITY(1,1),
        [pcb_codigo]                  NVARCHAR(50)    NOT NULL,
        [pcb_nombre]                  NVARCHAR(100)   NOT NULL,
        [pcb_orden]                   INT             NULL,
        [pcb_habilitado]              BIT             NOT NULL CONSTRAINT DF_PCB_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PERIODICIDAD_COBRO PRIMARY KEY CLUSTERED ([pcb_id] ASC),
        CONSTRAINT UX_PCB_CODIGO UNIQUE ([pcb_codigo])
    )

    PRINT 'Tabla Periodicidad_Cobro creada correctamente.'
END
ELSE
    PRINT 'Tabla Periodicidad_Cobro ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Periodicidad_Cobro] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Periodicidad_Cobro] WHERE [pcb_id] = 1)
    INSERT INTO [dbo].[Periodicidad_Cobro] ([pcb_id], [pcb_codigo], [pcb_nombre], [pcb_orden]) VALUES (1, N'MENSUAL', N'Mensual', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Periodicidad_Cobro] WHERE [pcb_id] = 2)
    INSERT INTO [dbo].[Periodicidad_Cobro] ([pcb_id], [pcb_codigo], [pcb_nombre], [pcb_orden]) VALUES (2, N'TRIMESTRAL', N'Trimestral', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Periodicidad_Cobro] WHERE [pcb_id] = 3)
    INSERT INTO [dbo].[Periodicidad_Cobro] ([pcb_id], [pcb_codigo], [pcb_nombre], [pcb_orden]) VALUES (3, N'ANUAL', N'Anual', 3)
SET IDENTITY_INSERT [dbo].[Periodicidad_Cobro] OFF
GO

-- Suscripcion_Estado (sue) — Estado administrativo de la suscripcion (VENCIDA se calcula)
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Suscripcion_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Suscripcion_Estado]
    (
        [sue_id]                      INT             NOT NULL IDENTITY(1,1),
        [sue_codigo]                  NVARCHAR(50)    NOT NULL,
        [sue_nombre]                  NVARCHAR(100)   NOT NULL,
        [sue_orden]                   INT             NULL,
        [sue_habilitado]              BIT             NOT NULL CONSTRAINT DF_SUE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_SUSCRIPCION_ESTADO PRIMARY KEY CLUSTERED ([sue_id] ASC),
        CONSTRAINT UX_SUE_CODIGO UNIQUE ([sue_codigo])
    )

    PRINT 'Tabla Suscripcion_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Suscripcion_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Suscripcion_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Estado] WHERE [sue_id] = 1)
    INSERT INTO [dbo].[Suscripcion_Estado] ([sue_id], [sue_codigo], [sue_nombre], [sue_orden]) VALUES (1, N'ACTIVA', N'Activa', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Estado] WHERE [sue_id] = 2)
    INSERT INTO [dbo].[Suscripcion_Estado] ([sue_id], [sue_codigo], [sue_nombre], [sue_orden]) VALUES (2, N'SUSPENDIDA', N'Suspendida', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Estado] WHERE [sue_id] = 3)
    INSERT INTO [dbo].[Suscripcion_Estado] ([sue_id], [sue_codigo], [sue_nombre], [sue_orden]) VALUES (3, N'CANCELADA', N'Cancelada', 3)
SET IDENTITY_INSERT [dbo].[Suscripcion_Estado] OFF
GO

-- Suscripcion_Periodo_Estado (spd) — Ciclo de vida de un periodo de suscripcion
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Suscripcion_Periodo_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Suscripcion_Periodo_Estado]
    (
        [spd_id]                      INT             NOT NULL IDENTITY(1,1),
        [spd_codigo]                  NVARCHAR(50)    NOT NULL,
        [spd_nombre]                  NVARCHAR(100)   NOT NULL,
        [spd_orden]                   INT             NULL,
        [spd_habilitado]              BIT             NOT NULL CONSTRAINT DF_SPD_HABILITADO DEFAULT 1,

        CONSTRAINT PK_SUSCRIPCION_PERIODO_ESTADO PRIMARY KEY CLUSTERED ([spd_id] ASC),
        CONSTRAINT UX_SPD_CODIGO UNIQUE ([spd_codigo])
    )

    PRINT 'Tabla Suscripcion_Periodo_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Suscripcion_Periodo_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Suscripcion_Periodo_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Periodo_Estado] WHERE [spd_id] = 1)
    INSERT INTO [dbo].[Suscripcion_Periodo_Estado] ([spd_id], [spd_codigo], [spd_nombre], [spd_orden]) VALUES (1, N'PENDIENTE PAGO', N'Pendiente de pago', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Periodo_Estado] WHERE [spd_id] = 2)
    INSERT INTO [dbo].[Suscripcion_Periodo_Estado] ([spd_id], [spd_codigo], [spd_nombre], [spd_orden]) VALUES (2, N'PAGO PARCIAL', N'Con abono parcial', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Periodo_Estado] WHERE [spd_id] = 3)
    INSERT INTO [dbo].[Suscripcion_Periodo_Estado] ([spd_id], [spd_codigo], [spd_nombre], [spd_orden]) VALUES (3, N'VIGENTE', N'Vigente', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Periodo_Estado] WHERE [spd_id] = 4)
    INSERT INTO [dbo].[Suscripcion_Periodo_Estado] ([spd_id], [spd_codigo], [spd_nombre], [spd_orden]) VALUES (4, N'CERRADO', N'Cerrado', 4)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Periodo_Estado] WHERE [spd_id] = 5)
    INSERT INTO [dbo].[Suscripcion_Periodo_Estado] ([spd_id], [spd_codigo], [spd_nombre], [spd_orden]) VALUES (5, N'ANULADO', N'Anulado', 5)
SET IDENTITY_INSERT [dbo].[Suscripcion_Periodo_Estado] OFF
GO

-- Suscripcion_Pago_Estado (spo) — Ciclo de vida de un abono
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Suscripcion_Pago_Estado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Suscripcion_Pago_Estado]
    (
        [spo_id]                      INT             NOT NULL IDENTITY(1,1),
        [spo_codigo]                  NVARCHAR(50)    NOT NULL,
        [spo_nombre]                  NVARCHAR(100)   NOT NULL,
        [spo_orden]                   INT             NULL,
        [spo_habilitado]              BIT             NOT NULL CONSTRAINT DF_SPO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_SUSCRIPCION_PAGO_ESTADO PRIMARY KEY CLUSTERED ([spo_id] ASC),
        CONSTRAINT UX_SPO_CODIGO UNIQUE ([spo_codigo])
    )

    PRINT 'Tabla Suscripcion_Pago_Estado creada correctamente.'
END
ELSE
    PRINT 'Tabla Suscripcion_Pago_Estado ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Suscripcion_Pago_Estado] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Pago_Estado] WHERE [spo_id] = 1)
    INSERT INTO [dbo].[Suscripcion_Pago_Estado] ([spo_id], [spo_codigo], [spo_nombre], [spo_orden]) VALUES (1, N'DECLARADO', N'Declarado por el cliente', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Pago_Estado] WHERE [spo_id] = 2)
    INSERT INTO [dbo].[Suscripcion_Pago_Estado] ([spo_id], [spo_codigo], [spo_nombre], [spo_orden]) VALUES (2, N'EN REVISION', N'En revisión', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Pago_Estado] WHERE [spo_id] = 3)
    INSERT INTO [dbo].[Suscripcion_Pago_Estado] ([spo_id], [spo_codigo], [spo_nombre], [spo_orden]) VALUES (3, N'VERIFICADO', N'Verificado', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Pago_Estado] WHERE [spo_id] = 4)
    INSERT INTO [dbo].[Suscripcion_Pago_Estado] ([spo_id], [spo_codigo], [spo_nombre], [spo_orden]) VALUES (4, N'RECHAZADO', N'Rechazado', 4)
SET IDENTITY_INSERT [dbo].[Suscripcion_Pago_Estado] OFF
GO

-- Uf_Origen (ufo) — De donde se obtuvo el valor de la UF
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Uf_Origen]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Uf_Origen]
    (
        [ufo_id]                      INT             NOT NULL IDENTITY(1,1),
        [ufo_codigo]                  NVARCHAR(50)    NOT NULL,
        [ufo_nombre]                  NVARCHAR(100)   NOT NULL,
        [ufo_orden]                   INT             NULL,
        [ufo_habilitado]              BIT             NOT NULL CONSTRAINT DF_UFO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_UF_ORIGEN PRIMARY KEY CLUSTERED ([ufo_id] ASC),
        CONSTRAINT UX_UFO_CODIGO UNIQUE ([ufo_codigo])
    )

    PRINT 'Tabla Uf_Origen creada correctamente.'
END
ELSE
    PRINT 'Tabla Uf_Origen ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Uf_Origen] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Uf_Origen] WHERE [ufo_id] = 1)
    INSERT INTO [dbo].[Uf_Origen] ([ufo_id], [ufo_codigo], [ufo_nombre], [ufo_orden]) VALUES (1, N'SII', N'Servicio de Impuestos Internos', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Uf_Origen] WHERE [ufo_id] = 2)
    INSERT INTO [dbo].[Uf_Origen] ([ufo_id], [ufo_codigo], [ufo_nombre], [ufo_orden]) VALUES (2, N'API EXTERNA', N'API externa', 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Uf_Origen] WHERE [ufo_id] = 3)
    INSERT INTO [dbo].[Uf_Origen] ([ufo_id], [ufo_codigo], [ufo_nombre], [ufo_orden]) VALUES (3, N'MANUAL', N'Carga manual', 3)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Uf_Origen] WHERE [ufo_id] = 4)
    INSERT INTO [dbo].[Uf_Origen] ([ufo_id], [ufo_codigo], [ufo_nombre], [ufo_orden]) VALUES (4, N'ARRASTRE', N'Arrastre del último valor conocido', 4)
SET IDENTITY_INSERT [dbo].[Uf_Origen] OFF
GO

/* ========================================================================
   VOZ E INCLUSIÓN
   ======================================================================== */

-- Voz_Motor (vmo) — Donde se proceso la voz de cada dictado
--   FIJO: el codigo depende de estos ids
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Voz_Motor]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Voz_Motor]
    (
        [vmo_id]                      INT             NOT NULL IDENTITY(1,1),
        [vmo_codigo]                  NVARCHAR(50)    NOT NULL,
        [vmo_nombre]                  NVARCHAR(100)   NOT NULL,
        [vmo_orden]                   INT             NULL,
        [vmo_habilitado]              BIT             NOT NULL CONSTRAINT DF_VMO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_VOZ_MOTOR PRIMARY KEY CLUSTERED ([vmo_id] ASC),
        CONSTRAINT UX_VMO_CODIGO UNIQUE ([vmo_codigo])
    )

    PRINT 'Tabla Voz_Motor creada correctamente.'
END
ELSE
    PRINT 'Tabla Voz_Motor ya existe.'
GO

SET IDENTITY_INSERT [dbo].[Voz_Motor] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Voz_Motor] WHERE [vmo_id] = 1)
    INSERT INTO [dbo].[Voz_Motor] ([vmo_id], [vmo_codigo], [vmo_nombre], [vmo_orden]) VALUES (1, N'DISPOSITIVO', N'En el teléfono, sin costo y sin señal', 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Voz_Motor] WHERE [vmo_id] = 2)
    INSERT INTO [dbo].[Voz_Motor] ([vmo_id], [vmo_codigo], [vmo_nombre], [vmo_orden]) VALUES (2, N'AZURE SPEECH', N'En la nube. No se usa: queda para trazabilidad futura', 2)
SET IDENTITY_INSERT [dbo].[Voz_Motor] OFF
GO
