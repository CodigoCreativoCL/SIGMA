USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     CIERRA LOS HUECOS DE MODELO QUE PIDE EL SPRINT 1.
-- =============================================
-- Va DESPUES de 24_VOZ_ENGANCHES.
--
-- POR QUE ESTE SCRIPT
--   Las 232 tablas del modelo ya estan desplegadas y las tablas nuevas de
--   SIGMA (Instalacion_Area, Centro_Costo, Grupo_Trabajo, Especialidad,
--   Usuario_Especialidad, Cliente_Usuario_Permiso) nacieron completas.
--
--   Lo que NO esta completo son las tres tablas HEREDADAS de FacilityGes que
--   el Sprint 1 vuelve a poner en el centro: Cliente, Cliente_Instalacion y
--   Usuario. Fueron disenadas para otro producto y les faltan campos que los
--   criterios de aceptacion piden de forma explicita. Aqui se agregan, sin
--   tocar ninguna columna existente: el codigo viejo sigue leyendo lo suyo.
--
--   Se agregan ademas tres tablas nuevas para requisitos que hoy no tienen
--   donde vivir: el historial de contrasenas, los enlaces de recuperacion y
--   el registro de catalogos.
--
-- LO QUE NO SE HACE AQUI
--   No se renombra ni se elimina nada. Las columnas nuevas entran NULL o con
--   DEFAULT, como manda PATRON_TABLAS §7: la tabla ya tiene datos.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   BLOQUE 1 - Cliente
   HU-010 pide pais, zona horaria, idioma, moneda, nombre de fantasia y que
   el RUT no se repita en la plataforma. La tabla solo traia pais y RUT.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Cliente]') AND name = 'cli_nombre_fantasia')
BEGIN
    ALTER TABLE [dbo].[Cliente] ADD [cli_nombre_fantasia] NVARCHAR(200) NULL
    PRINT 'Columna cli_nombre_fantasia agregada a Cliente.'
END
ELSE PRINT 'Columna cli_nombre_fantasia ya existe en Cliente.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Cliente]') AND name = 'cli_zona_horaria')
BEGIN
    ALTER TABLE [dbo].[Cliente] ADD [cli_zona_horaria] INT NULL
    PRINT 'Columna cli_zona_horaria agregada a Cliente.'
END
ELSE PRINT 'Columna cli_zona_horaria ya existe en Cliente.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Cliente]') AND name = 'cli_idioma')
BEGIN
    ALTER TABLE [dbo].[Cliente] ADD [cli_idioma] INT NULL
    PRINT 'Columna cli_idioma agregada a Cliente.'
END
ELSE PRINT 'Columna cli_idioma ya existe en Cliente.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Cliente]') AND name = 'cli_moneda')
BEGIN
    ALTER TABLE [dbo].[Cliente] ADD [cli_moneda] INT NULL
    PRINT 'Columna cli_moneda agregada a Cliente.'
END
ELSE PRINT 'Columna cli_moneda ya existe en Cliente.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CLI_ZONA_HORARIA')
    ALTER TABLE [dbo].[Cliente] WITH CHECK ADD CONSTRAINT FK_CLI_ZONA_HORARIA
        FOREIGN KEY ([cli_zona_horaria]) REFERENCES [dbo].[Zona_Horaria] ([zho_id])
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CLI_IDIOMA')
    ALTER TABLE [dbo].[Cliente] WITH CHECK ADD CONSTRAINT FK_CLI_IDIOMA
        FOREIGN KEY ([cli_idioma]) REFERENCES [dbo].[Idioma] ([idi_id])
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CLI_MONEDA')
    ALTER TABLE [dbo].[Cliente] WITH CHECK ADD CONSTRAINT FK_CLI_MONEDA
        FOREIGN KEY ([cli_moneda]) REFERENCES [dbo].[Moneda] ([mon_id])
GO

/* El RUT es unico en la plataforma (HU-010 escenario 1). Indice FILTRADO:
   los clientes historicos sin RUT no deben bloquear la creacion de otros,
   y un UNIQUE normal trataria varios NULL como duplicados. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_CLI_IDENTIFICADOR' AND object_id = OBJECT_ID(N'[dbo].[Cliente]'))
BEGIN
    IF EXISTS (SELECT cli_identificador FROM [dbo].[Cliente]
               WHERE cli_identificador IS NOT NULL AND LTRIM(RTRIM(cli_identificador)) <> ''
               GROUP BY cli_identificador HAVING COUNT(*) > 1)
        PRINT 'AVISO: hay RUT de cliente duplicados. UX_CLI_IDENTIFICADOR no se creo. Depurar antes.'
    ELSE
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX UX_CLI_IDENTIFICADOR
            ON [dbo].[Cliente] ([cli_identificador])
            WHERE [cli_identificador] IS NOT NULL
        PRINT 'Indice UX_CLI_IDENTIFICADOR creado.'
    END
END
ELSE PRINT 'Indice UX_CLI_IDENTIFICADOR ya existe.'
GO


/* ========================================================================
   BLOQUE 2 - Cliente_Instalacion (la "planta" del negocio)
   HU-011 pide codigo unico por cliente, zona horaria propia y coordenadas.
   La zona horaria propia no es decorativa: el escenario 2 dice que las
   programaciones de esa planta se calculan con ella.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Cliente_Instalacion]') AND name = 'cin_codigo')
BEGIN
    ALTER TABLE [dbo].[Cliente_Instalacion] ADD [cin_codigo] NVARCHAR(100) NULL
    PRINT 'Columna cin_codigo agregada a Cliente_Instalacion.'
END
ELSE PRINT 'Columna cin_codigo ya existe en Cliente_Instalacion.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Cliente_Instalacion]') AND name = 'cin_zona_horaria')
BEGIN
    ALTER TABLE [dbo].[Cliente_Instalacion] ADD [cin_zona_horaria] INT NULL
    PRINT 'Columna cin_zona_horaria agregada a Cliente_Instalacion.'
END
ELSE PRINT 'Columna cin_zona_horaria ya existe en Cliente_Instalacion.'
GO

/* DECIMAL(9,6): 6 decimales son ~11 cm en el ecuador, de sobra para ubicar
   una planta. FLOAT queda descartado por PATRON_TABLAS §3.1. */
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Cliente_Instalacion]') AND name = 'cin_latitud')
BEGIN
    ALTER TABLE [dbo].[Cliente_Instalacion] ADD [cin_latitud] DECIMAL(9,6) NULL
    PRINT 'Columna cin_latitud agregada a Cliente_Instalacion.'
END
ELSE PRINT 'Columna cin_latitud ya existe en Cliente_Instalacion.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Cliente_Instalacion]') AND name = 'cin_longitud')
BEGIN
    ALTER TABLE [dbo].[Cliente_Instalacion] ADD [cin_longitud] DECIMAL(9,6) NULL
    PRINT 'Columna cin_longitud agregada a Cliente_Instalacion.'
END
ELSE PRINT 'Columna cin_longitud ya existe en Cliente_Instalacion.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CIN_ZONA_HORARIA')
    ALTER TABLE [dbo].[Cliente_Instalacion] WITH CHECK ADD CONSTRAINT FK_CIN_ZONA_HORARIA
        FOREIGN KEY ([cin_zona_horaria]) REFERENCES [dbo].[Zona_Horaria] ([zho_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_CIN_LATITUD')
    ALTER TABLE [dbo].[Cliente_Instalacion] WITH CHECK ADD CONSTRAINT CK_CIN_LATITUD
        CHECK ([cin_latitud] IS NULL OR ([cin_latitud] >= -90 AND [cin_latitud] <= 90))
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_CIN_LONGITUD')
    ALTER TABLE [dbo].[Cliente_Instalacion] WITH CHECK ADD CONSTRAINT CK_CIN_LONGITUD
        CHECK ([cin_longitud] IS NULL OR ([cin_longitud] >= -180 AND [cin_longitud] <= 180))
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_CIN_CLIENTE_CODIGO' AND object_id = OBJECT_ID(N'[dbo].[Cliente_Instalacion]'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_CIN_CLIENTE_CODIGO
        ON [dbo].[Cliente_Instalacion] ([cin_cliente], [cin_codigo])
        WHERE [cin_codigo] IS NOT NULL
    PRINT 'Indice UX_CIN_CLIENTE_CODIGO creado.'
END
ELSE PRINT 'Indice UX_CIN_CLIENTE_CODIGO ya existe.'
GO


/* ========================================================================
   BLOQUE 3 - Usuario
   HU-001 escenario 1 pide registrar el ultimo acceso y el escenario 4 pide
   bloqueo por cinco intentos fallidos en quince minutos. Nada de eso tenia
   donde guardarse. El idioma lo pide HU-005.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Usuario]') AND name = 'usu_ultimo_acceso')
BEGIN
    ALTER TABLE [dbo].[Usuario] ADD [usu_ultimo_acceso] DATETIME NULL
    PRINT 'Columna usu_ultimo_acceso agregada a Usuario.'
END
ELSE PRINT 'Columna usu_ultimo_acceso ya existe en Usuario.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Usuario]') AND name = 'usu_intentos_fallidos')
BEGIN
    ALTER TABLE [dbo].[Usuario]
        ADD [usu_intentos_fallidos] INT NOT NULL CONSTRAINT DF_USU_INTENTOS_FALLIDOS DEFAULT 0
    PRINT 'Columna usu_intentos_fallidos agregada a Usuario.'
END
ELSE PRINT 'Columna usu_intentos_fallidos ya existe en Usuario.'
GO

/* Momento del PRIMER intento fallido de la racha. La ventana de quince
   minutos se mide desde aqui, no desde el ultimo intento: si no, cinco
   fallos espaciados quince minutos cada uno nunca bloquearian. */
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Usuario]') AND name = 'usu_primer_intento_fallido')
BEGIN
    ALTER TABLE [dbo].[Usuario] ADD [usu_primer_intento_fallido] DATETIME NULL
    PRINT 'Columna usu_primer_intento_fallido agregada a Usuario.'
END
ELSE PRINT 'Columna usu_primer_intento_fallido ya existe en Usuario.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Usuario]') AND name = 'usu_bloqueado_hasta')
BEGIN
    ALTER TABLE [dbo].[Usuario] ADD [usu_bloqueado_hasta] DATETIME NULL
    PRINT 'Columna usu_bloqueado_hasta agregada a Usuario.'
END
ELSE PRINT 'Columna usu_bloqueado_hasta ya existe en Usuario.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Usuario]') AND name = 'usu_idioma')
BEGIN
    ALTER TABLE [dbo].[Usuario] ADD [usu_idioma] INT NULL
    PRINT 'Columna usu_idioma agregada a Usuario.'
END
ELSE PRINT 'Columna usu_idioma ya existe en Usuario.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_USU_IDIOMA')
    ALTER TABLE [dbo].[Usuario] WITH CHECK ADD CONSTRAINT FK_USU_IDIOMA
        FOREIGN KEY ([usu_idioma]) REFERENCES [dbo].[Idioma] ([idi_id])
GO

/* HU-014 escenario 1: el correo es unico en TODA la plataforma, no por
   cliente. Filtrado por la misma razon que el RUT del cliente. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_USU_CORREO' AND object_id = OBJECT_ID(N'[dbo].[Usuario]'))
BEGIN
    IF EXISTS (SELECT usu_correo FROM [dbo].[Usuario]
               WHERE usu_correo IS NOT NULL AND LTRIM(RTRIM(usu_correo)) <> ''
               GROUP BY usu_correo HAVING COUNT(*) > 1)
        PRINT 'AVISO: hay correos de usuario duplicados. UX_USU_CORREO no se creo. Depurar antes.'
    ELSE
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX UX_USU_CORREO
            ON [dbo].[Usuario] ([usu_correo])
            WHERE [usu_correo] IS NOT NULL
        PRINT 'Indice UX_USU_CORREO creado.'
    END
END
ELSE PRINT 'Indice UX_USU_CORREO ya existe.'
GO


/* ========================================================================
   BLOQUE 4 - Cliente_Usuario_Permiso
   HU-007 define tres ambitos para la excepcion: Cliente, Planta y Area.
   La tabla resolvia Cliente (columna NULL) y Planta, pero no Area.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Cliente_Usuario_Permiso]') AND name = 'cpm_instalacion_area')
BEGIN
    ALTER TABLE [dbo].[Cliente_Usuario_Permiso] ADD [cpm_instalacion_area] INT NULL
    PRINT 'Columna cpm_instalacion_area agregada a Cliente_Usuario_Permiso.'
END
ELSE PRINT 'Columna cpm_instalacion_area ya existe en Cliente_Usuario_Permiso.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CPM_INSTALACION_AREA')
    ALTER TABLE [dbo].[Cliente_Usuario_Permiso] WITH CHECK ADD CONSTRAINT FK_CPM_INSTALACION_AREA
        FOREIGN KEY ([cpm_instalacion_area]) REFERENCES [dbo].[Instalacion_Area] ([iar_id])
GO


/* ========================================================================
   BLOQUE 5 - Usuario_Password_Historial
   HU-005 escenario 1: la contrasena nueva no puede ser igual a ninguna de
   las tres anteriores. Sin historial esa regla no se puede evaluar, porque
   Usuario solo guarda la vigente.

   Tabla append-only: solo usuario y fecha de creacion, sin _act ni
   _habilitado (PATRON_TABLAS §2).
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Usuario_Password_Historial]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Usuario_Password_Historial]
    (
        [uph_id]                 INT          NOT NULL IDENTITY(1,1),
        [uph_usuario]            INT          NOT NULL,
        [uph_password]           VARCHAR(500) NOT NULL,
        [uph_usuario_creacion]   INT          NOT NULL,
        [uph_fecha_creacion]     DATETIME     NOT NULL CONSTRAINT DF_UPH_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_USUARIO_PASSWORD_HISTORIAL PRIMARY KEY CLUSTERED ([uph_id] ASC),
        CONSTRAINT FK_UPH_USUARIO FOREIGN KEY ([uph_usuario])
            REFERENCES [dbo].[Usuario] ([usu_id])
    )

    CREATE NONCLUSTERED INDEX IX_UPH_USUARIO_FECHA
        ON [dbo].[Usuario_Password_Historial] ([uph_usuario], [uph_fecha_creacion] DESC)

    PRINT 'Tabla Usuario_Password_Historial creada correctamente.'
END
ELSE PRINT 'Tabla Usuario_Password_Historial ya existe.'
GO


/* ========================================================================
   BLOQUE 6 - Usuario_Recuperacion
   HU-004: enlace de un solo uso con vigencia de 60 minutos.

   "Un solo uso" y "vencido" son dos estados distintos y el escenario 3 los
   distingue, por eso hay ure_fecha_uso ademas de ure_fecha_expiracion: un
   enlace ya usado no se reporta como vencido.

   Se guarda el HASH del token, no el token. Si alguien lee esta tabla no
   puede restablecer la clave de nadie. El token en claro viaja solo en el
   correo, una vez.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Usuario_Recuperacion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Usuario_Recuperacion]
    (
        [ure_id]                 INT            NOT NULL IDENTITY(1,1),
        [ure_usuario]            INT            NOT NULL,
        [ure_token_hash]         VARBINARY(32)  NOT NULL,
        [ure_fecha_expiracion]   DATETIME       NOT NULL,
        [ure_fecha_uso]          DATETIME       NULL,
        [ure_ip_solicitud]       NVARCHAR(50)   NULL,
        [ure_usuario_creacion]   INT            NOT NULL,
        [ure_fecha_creacion]     DATETIME       NOT NULL CONSTRAINT DF_URE_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_USUARIO_RECUPERACION PRIMARY KEY CLUSTERED ([ure_id] ASC),
        CONSTRAINT FK_URE_USUARIO FOREIGN KEY ([ure_usuario])
            REFERENCES [dbo].[Usuario] ([usu_id])
    )

    CREATE UNIQUE NONCLUSTERED INDEX UX_URE_TOKEN_HASH
        ON [dbo].[Usuario_Recuperacion] ([ure_token_hash])

    CREATE NONCLUSTERED INDEX IX_URE_USUARIO
        ON [dbo].[Usuario_Recuperacion] ([ure_usuario], [ure_fecha_creacion] DESC)

    PRINT 'Tabla Usuario_Recuperacion creada correctamente.'
END
ELSE PRINT 'Tabla Usuario_Recuperacion ya existe.'
GO


/* ========================================================================
   BLOQUE 7 - Catalogo
   HU-020 pide consultar cualquier catalogo del sistema y buscar de forma
   transversal en todos. HU-021 pide agregar valores propios en los que lo
   permiten.

   Una pantalla por catalogo serian sesenta pantallas identicas. En vez de
   eso se registra aqui QUE catalogos existen, en que tabla viven y cuales
   admiten valores del cliente. Una sola pantalla los recorre todos, y
   sumar un catalogo nuevo es un INSERT, no una pantalla.

   Es la misma decision que ya se tomo con los permisos: que el sistema se
   configure por datos y no por codigo.

   ctl_ampliable = 1 exige que la tabla tenga una columna <pfx>_cliente
   NULLABLE. Ese es el mecanismo: valor del sistema = cliente NULL, valor
   propio = cliente informado.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Catalogo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Catalogo]
    (
        [ctl_id]                 INT            NOT NULL IDENTITY(1,1),
        [ctl_codigo]             NVARCHAR(100)  NOT NULL,
        [ctl_nombre]             NVARCHAR(200)  NOT NULL,
        [ctl_descripcion]        NVARCHAR(1000) NULL,
        [ctl_tabla]              NVARCHAR(128)  NOT NULL,
        [ctl_prefijo]            NVARCHAR(10)   NOT NULL,
        [ctl_modulo]             NVARCHAR(100)  NULL,
        [ctl_ampliable]          BIT            NOT NULL CONSTRAINT DF_CTL_AMPLIABLE DEFAULT 0,
        [ctl_orden]              INT            NULL,
        [ctl_habilitado]         BIT            NOT NULL CONSTRAINT DF_CTL_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CATALOGO PRIMARY KEY CLUSTERED ([ctl_id] ASC),
        CONSTRAINT UX_CTL_CODIGO UNIQUE ([ctl_codigo]),
        CONSTRAINT UX_CTL_TABLA  UNIQUE ([ctl_tabla])
    )

    PRINT 'Tabla Catalogo creada correctamente.'
END
ELSE PRINT 'Tabla Catalogo ya existe.'
GO


/* ------------------------------------------------------------------------
   Carga del registro de catalogos.

   El criterio para que una tabla entre: tiene <pfx>_id, <pfx>_codigo,
   <pfx>_nombre, <pfx>_habilitado y <pfx>_orden. Ese <pfx>_orden es lo que
   separa un catalogo de una entidad: Activo, Bodega, Repuesto u
   Orden_Trabajo tienen codigo y nombre pero nadie los ordena a mano en una
   lista desplegable.

   Sobre ese criterio hay dos ajustes explicitos:
     - Se excluyen las tablas de DETALLE que tambien traen orden
       (secciones de plantilla, actividades e hitos de un plan) y la
       configuracion comercial. No son catalogos: son parte de otra entidad.
     - Se incluyen a mano Falla_Causa, Falla_Modo y Falla_Sintoma, que son
       catalogos ampliables de manual pero nacieron sin columna de orden.

   El modulo se deduce del nombre de la tabla y sirve para agrupar la lista
   en pantalla. Se puede corregir despues con un UPDATE.
   ------------------------------------------------------------------------ */

;WITH cols AS (
    SELECT t.name AS tabla,
           LEFT(c.name, CHARINDEX('_', c.name) - 1) AS pfx,
           SUBSTRING(c.name, CHARINDEX('_', c.name) + 1, 128) AS suf
    FROM   sys.tables t
    JOIN   sys.columns c ON c.object_id = t.object_id
    WHERE  CHARINDEX('_', c.name) > 0
),
candidatas AS (
    SELECT tabla,
           MIN(pfx) AS pfx,
           MAX(CASE WHEN suf = 'cliente' THEN 1 ELSE 0 END) AS ampliable,
           MAX(CASE WHEN suf = 'orden'   THEN 1 ELSE 0 END) AS tiene_orden
    FROM   cols
    GROUP BY tabla
    HAVING MAX(CASE WHEN suf = 'id'         THEN 1 ELSE 0 END) = 1
       AND MAX(CASE WHEN suf = 'codigo'     THEN 1 ELSE 0 END) = 1
       AND MAX(CASE WHEN suf = 'nombre'     THEN 1 ELSE 0 END) = 1
       AND MAX(CASE WHEN suf = 'habilitado' THEN 1 ELSE 0 END) = 1
),
registro AS (
    SELECT tabla, pfx, ampliable
    FROM   candidatas
    WHERE  tiene_orden = 1
      AND  tabla NOT IN ('Checklist_Plantilla_Seccion',
                         'Plan_Mantenimiento_Actividad',
                         'Plan_Mantenimiento_Hito',
                         'Plan_Comercial',
                         'Funcionalidad')
    UNION
    SELECT tabla, pfx, ampliable
    FROM   candidatas
    WHERE  tabla IN ('Falla_Causa', 'Falla_Modo', 'Falla_Sintoma')
)
INSERT INTO [dbo].[Catalogo] (ctl_codigo, ctl_nombre, ctl_descripcion, ctl_tabla, ctl_prefijo, ctl_modulo, ctl_ampliable, ctl_orden)
SELECT UPPER(r.tabla),
       REPLACE(r.tabla, '_', ' '),
       NULL,
       r.tabla,
       r.pfx,
       CASE
            WHEN r.tabla LIKE 'Activo%'      THEN 'Activos'
            WHEN r.tabla LIKE 'Checklist%'   THEN 'Checklists'
            WHEN r.tabla LIKE 'Orden_Trabajo%' THEN 'Ordenes de trabajo'
            WHEN r.tabla LIKE 'Plan%'        THEN 'Planes'
            WHEN r.tabla LIKE 'Repuesto%'
              OR r.tabla LIKE 'Inventario%'  THEN 'Inventario'
            WHEN r.tabla LIKE 'Tarea%'       THEN 'Tareas'
            WHEN r.tabla LIKE 'Falla%'
              OR r.tabla LIKE 'Diagnostico%' THEN 'Fallas'
            WHEN r.tabla LIKE 'Suscripcion%' THEN 'Suscripcion'
            WHEN r.tabla LIKE 'Permiso%'     THEN 'Seguridad'
            WHEN r.tabla LIKE 'Modelo%'
              OR r.tabla LIKE 'Prediccion%'  THEN 'Prediccion'
            ELSE 'Sistema'
       END,
       r.ampliable,
       0
FROM   registro r
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Catalogo] c WHERE c.ctl_tabla = r.tabla)
GO

PRINT 'Registro de catalogos cargado.'
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'columnas nuevas en Cliente'             AS control,
       COUNT(*) AS valor, 4 AS esperado
FROM   sys.columns
WHERE  object_id = OBJECT_ID(N'[dbo].[Cliente]')
  AND  name IN ('cli_nombre_fantasia','cli_zona_horaria','cli_idioma','cli_moneda')
UNION ALL
SELECT 'columnas nuevas en Cliente_Instalacion', COUNT(*), 4
FROM   sys.columns
WHERE  object_id = OBJECT_ID(N'[dbo].[Cliente_Instalacion]')
  AND  name IN ('cin_codigo','cin_zona_horaria','cin_latitud','cin_longitud')
UNION ALL
SELECT 'columnas nuevas en Usuario', COUNT(*), 5
FROM   sys.columns
WHERE  object_id = OBJECT_ID(N'[dbo].[Usuario]')
  AND  name IN ('usu_ultimo_acceso','usu_intentos_fallidos','usu_primer_intento_fallido','usu_bloqueado_hasta','usu_idioma')
UNION ALL
SELECT 'tablas nuevas del sprint', COUNT(*), 3
FROM   sys.tables
WHERE  name IN ('Usuario_Password_Historial','Usuario_Recuperacion','Catalogo')
UNION ALL
SELECT 'catalogos registrados', COUNT(*), NULL FROM [dbo].[Catalogo]
UNION ALL
SELECT 'catalogos ampliables',  COUNT(*), NULL FROM [dbo].[Catalogo] WHERE ctl_ampliable = 1
GO

/* Un catalogo marcado ampliable cuya tabla NO tenga <pfx>_cliente nullable
   romperia el alta de valores propios. Debe devolver cero filas. */
SELECT c.ctl_codigo AS catalogo_ampliable_sin_columna_cliente
FROM   [dbo].[Catalogo] c
WHERE  c.ctl_ampliable = 1
  AND  NOT EXISTS (
        SELECT 1 FROM sys.columns col
        WHERE  col.object_id = OBJECT_ID('[dbo].[' + c.ctl_tabla + ']')
          AND  col.name = c.ctl_prefijo + '_cliente'
          AND  col.is_nullable = 1)
GO
