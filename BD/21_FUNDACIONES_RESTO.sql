USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  20-08-2026
-- DESCRIPTION:     D1 + D14 -- FUNDACIONES: LO QUE TODO LO DEMAS NECESITA.
-- =============================================
-- Ver SIGMA_MODELO_LOGICO_v2.md §8.1 y §8.14
--
-- ESTE BLOQUE CORRE TEMPRANO, NO AL FINAL
--   El numero del archivo es un NOMBRE, no un orden. El orden lo manda
--   00_MAESTRO.sql, y ahi este bloque va inmediatamente despues de los
--   catalogos. La razon es concreta: Activo tiene FK a Instalacion_Area
--   y a Centro_Costo, y Activo se crea en el bloque 11.
--
-- QUE HAY AQUI
--   Zona_Horaria e Idioma      -> localizacion; multipais desde el dia uno
--   Permiso y Perfil_Permiso   -> permisos finos, mas alla del perfil
--   Especialidad ya existe (catalogo, bloque 04); aqui va la union
--   Usuario_Especialidad       -> quien sabe hacer que, y hasta cuando
--   Grupo_Trabajo (+ Usuario)  -> "turno noche mecanicos" como destinatario
--   Instalacion_Area           -> jerarquia fisica: Planta > Linea > Sala
--   Centro_Costo               -> a quien se le imputa el gasto
--   Cliente_Binario            -> el logo, fuera de la tabla maestra
--   Importacion_Carga (+Celda) -> la trazabilidad de cargar un Excel real
--
-- POR QUE Usuario_Especialidad TIENE VENCIMIENTO
--   Una certificacion de trabajo en altura vence. Si el modelo no guarda
--   la fecha, el sistema asigna a un tecnico cuyo permiso caduco hace tres
--   meses y nadie se entera hasta la auditoria.
--
-- POR QUE Importacion_Carga_Celda GUARDA LA CELDA, NO LA FILA
--   Cargar la MATRIZ real de Hamburgo produce ambiguedades por celda, no
--   por fila: una fila puede tener el activo correcto y la frecuencia
--   escrita como "500 hrs / anual". Guardando celda por celda se puede
--   mostrar exactamente donde hay que decidir, en vez de rechazar la fila
--   completa y perder el trabajo bueno que traia.
--
-- IDEMPOTENTE: se puede ejecutar las veces que sea.
-- =============================================


/* ========================================================================
   1. ZONA_HORARIA (zho)

      Dos identificadores, no uno: Windows para SQL Server / .NET,
      IANA para Flutter y para cualquier cosa que no sea Microsoft.
      El offset es referencial -- no sirve para calcular, porque el
      horario de verano lo cambia; sirve para ordenar una lista.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Zona_Horaria]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Zona_Horaria]
    (
        [zho_id]                        INT             NOT NULL IDENTITY(1,1),
        [zho_nombre]                    NVARCHAR(100)   NOT NULL,
        [zho_identificador_windows]     NVARCHAR(100)   NOT NULL,
        [zho_identificador_iana]        NVARCHAR(100)   NOT NULL,
        [zho_offset_minuto]             INT             NOT NULL CONSTRAINT DF_ZHO_OFFSET DEFAULT 0,
        [zho_usuario_creacion]          INT             NOT NULL,
        [zho_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_ZHO_FECHA_CREACION DEFAULT GETDATE(),
        [zho_usuario_actualizacion]     INT             NULL,
        [zho_fecha_actualizacion]       DATETIME        NULL,
        [zho_habilitado]                BIT             NOT NULL CONSTRAINT DF_ZHO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ZONA_HORARIA PRIMARY KEY CLUSTERED ([zho_id] ASC),
        CONSTRAINT UX_ZHO_IANA UNIQUE ([zho_identificador_iana])
    )
    PRINT 'Tabla Zona_Horaria creada correctamente.'
END
ELSE PRINT 'Tabla Zona_Horaria ya existe.'
GO


/* ========================================================================
   2. IDIOMA (idi)
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Idioma]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Idioma]
    (
        [idi_id]                        INT             NOT NULL IDENTITY(1,1),
        [idi_codigo]                    NVARCHAR(10)    NOT NULL,
        [idi_nombre]                    NVARCHAR(100)   NOT NULL,
        [idi_orden]                     INT             NULL,
        [idi_usuario_creacion]          INT             NOT NULL,
        [idi_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_IDI_FECHA_CREACION DEFAULT GETDATE(),
        [idi_usuario_actualizacion]     INT             NULL,
        [idi_fecha_actualizacion]       DATETIME        NULL,
        [idi_habilitado]                BIT             NOT NULL CONSTRAINT DF_IDI_HABILITADO DEFAULT 1,

        CONSTRAINT PK_IDIOMA PRIMARY KEY CLUSTERED ([idi_id] ASC),
        CONSTRAINT UX_IDI_CODIGO UNIQUE ([idi_codigo])
    )
    PRINT 'Tabla Idioma creada correctamente.'
END
ELSE PRINT 'Tabla Idioma ya existe.'
GO


/* ========================================================================
   3. PERMISO (prm) y PERFIL_PERMISO (ppe)

      El prefijo es prm, no per: per ya lo ocupa Perfiles, que existe en
      la base legada de SGF. El registro de prefijos manda.

      Esto convive con Cliente_Usuario_Permiso (bloque 06), que es la
      excepcion por usuario. La regla general esta aqui: perfil -> permisos.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Permiso]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Permiso]
    (
        [prm_id]                        INT             NOT NULL IDENTITY(1,1),
        [prm_codigo]                    NVARCHAR(100)   NOT NULL,
        [prm_nombre]                    NVARCHAR(200)   NOT NULL,
        [prm_modulo]                    NVARCHAR(100)   NOT NULL,
        [prm_permiso_ambito]            INT             NULL,
        [prm_descripcion]               NVARCHAR(500)   NULL,
        [prm_usuario_creacion]          INT             NOT NULL,
        [prm_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PRM_FECHA_CREACION DEFAULT GETDATE(),
        [prm_usuario_actualizacion]     INT             NULL,
        [prm_fecha_actualizacion]       DATETIME        NULL,
        [prm_habilitado]                BIT             NOT NULL CONSTRAINT DF_PRM_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PERMISO PRIMARY KEY CLUSTERED ([prm_id] ASC),
        CONSTRAINT FK_PRM_AMBITO FOREIGN KEY ([prm_permiso_ambito]) REFERENCES [dbo].[Permiso_Ambito] ([pam_id]),
        CONSTRAINT UX_PRM_CODIGO UNIQUE ([prm_codigo])
    )
    CREATE NONCLUSTERED INDEX IX_PRM_MODULO ON [dbo].[Permiso] ([prm_modulo])
    PRINT 'Tabla Permiso creada correctamente.'
END
ELSE PRINT 'Tabla Permiso ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Perfil_Permiso]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Perfil_Permiso]
    (
        [ppe_id]                        INT             NOT NULL IDENTITY(1,1),
        [ppe_perfil]                    INT             NOT NULL,
        [ppe_permiso]                   INT             NOT NULL,
        [ppe_usuario_creacion]          INT             NOT NULL,
        [ppe_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PPE_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_PERFIL_PERMISO PRIMARY KEY CLUSTERED ([ppe_id] ASC),
        CONSTRAINT FK_PPE_PERFIL  FOREIGN KEY ([ppe_perfil])  REFERENCES [dbo].[Perfiles] ([per_id]),
        CONSTRAINT FK_PPE_PERMISO FOREIGN KEY ([ppe_permiso]) REFERENCES [dbo].[Permiso] ([prm_id]),
        CONSTRAINT UX_PPE_PERFIL_PERMISO UNIQUE ([ppe_perfil], [ppe_permiso])
    )
    PRINT 'Tabla Perfil_Permiso creada correctamente.'
END
ELSE PRINT 'Tabla Perfil_Permiso ya existe.'
GO


/* ========================================================================
   4. USUARIO_ESPECIALIDAD (ues)

      ues_fecha_vencimiento es la columna que hace util a esta tabla.
      Sin ella solo dice "sabe soldar"; con ella dice "sabe soldar y su
      certificacion vence el 12 de marzo", que es lo que hay que mirar
      antes de asignarle un trabajo caliente.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Usuario_Especialidad]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Usuario_Especialidad]
    (
        [ues_id]                        INT             NOT NULL IDENTITY(1,1),
        [ues_usuario]                   INT             NOT NULL,
        [ues_cliente]                   INT             NOT NULL,
        [ues_especialidad]              INT             NOT NULL,
        [ues_especialidad_nivel]        INT             NULL,
        [ues_certificacion]             NVARCHAR(200)   NULL,
        [ues_fecha_vencimiento]         DATE            NULL,
        [ues_usuario_creacion]          INT             NOT NULL,
        [ues_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_UES_FECHA_CREACION DEFAULT GETDATE(),
        [ues_usuario_actualizacion]     INT             NULL,
        [ues_fecha_actualizacion]       DATETIME        NULL,
        [ues_habilitado]                BIT             NOT NULL CONSTRAINT DF_UES_HABILITADO DEFAULT 1,

        CONSTRAINT PK_USUARIO_ESPECIALIDAD PRIMARY KEY CLUSTERED ([ues_id] ASC),
        CONSTRAINT FK_UES_USUARIO      FOREIGN KEY ([ues_usuario])            REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_UES_CLIENTE      FOREIGN KEY ([ues_cliente])            REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_UES_ESPECIALIDAD FOREIGN KEY ([ues_especialidad])       REFERENCES [dbo].[Especialidad] ([esp_id]),
        CONSTRAINT FK_UES_NIVEL        FOREIGN KEY ([ues_especialidad_nivel]) REFERENCES [dbo].[Especialidad_Nivel] ([enl_id]),
        CONSTRAINT UX_UES_USUARIO_CLIENTE_ESPECIALIDAD UNIQUE ([ues_usuario], [ues_cliente], [ues_especialidad])
    )
    CREATE NONCLUSTERED INDEX IX_UES_VENCIMIENTO ON [dbo].[Usuario_Especialidad] ([ues_fecha_vencimiento])
        WHERE [ues_fecha_vencimiento] IS NOT NULL
    PRINT 'Tabla Usuario_Especialidad creada correctamente.'
END
ELSE PRINT 'Tabla Usuario_Especialidad ya existe.'
GO


/* ========================================================================
   5. GRUPO_TRABAJO (gtr) y GRUPO_TRABAJO_USUARIO (gtu)

      Asignar a un grupo en vez de a una persona resuelve el turno: la
      OT del turno noche no se le asigna a Juan, se le asigna al turno
      noche, y la toma quien este. Quien la tomo queda en la asignacion,
      no en la programacion.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Grupo_Trabajo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Grupo_Trabajo]
    (
        [gtr_id]                        INT             NOT NULL IDENTITY(1,1),
        [gtr_cliente]                   INT             NOT NULL,
        [gtr_cliente_instalacion]       INT             NULL,       -- NULL = transversal al cliente
        [gtr_codigo]                    NVARCHAR(50)    NOT NULL,
        [gtr_nombre]                    NVARCHAR(200)   NOT NULL,
        [gtr_especialidad]              INT             NULL,
        [gtr_descripcion]               NVARCHAR(500)   NULL,
        [gtr_usuario_creacion]          INT             NOT NULL,
        [gtr_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_GTR_FECHA_CREACION DEFAULT GETDATE(),
        [gtr_usuario_actualizacion]     INT             NULL,
        [gtr_fecha_actualizacion]       DATETIME        NULL,
        [gtr_habilitado]                BIT             NOT NULL CONSTRAINT DF_GTR_HABILITADO DEFAULT 1,

        CONSTRAINT PK_GRUPO_TRABAJO PRIMARY KEY CLUSTERED ([gtr_id] ASC),
        CONSTRAINT FK_GTR_CLIENTE      FOREIGN KEY ([gtr_cliente])             REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_GTR_INSTALACION  FOREIGN KEY ([gtr_cliente_instalacion]) REFERENCES [dbo].[Cliente_Instalacion] ([cin_id]),
        CONSTRAINT FK_GTR_ESPECIALIDAD FOREIGN KEY ([gtr_especialidad])        REFERENCES [dbo].[Especialidad] ([esp_id]),
        CONSTRAINT UX_GTR_CLIENTE_CODIGO UNIQUE ([gtr_cliente], [gtr_codigo])
    )
    PRINT 'Tabla Grupo_Trabajo creada correctamente.'
END
ELSE PRINT 'Tabla Grupo_Trabajo ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Grupo_Trabajo_Usuario]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Grupo_Trabajo_Usuario]
    (
        [gtu_id]                        INT             NOT NULL IDENTITY(1,1),
        [gtu_grupo_trabajo]             INT             NOT NULL,
        [gtu_usuario]                   INT             NOT NULL,
        [gtu_es_lider]                  BIT             NOT NULL CONSTRAINT DF_GTU_LIDER DEFAULT 0,
        [gtu_fecha_inicio]              DATE            NOT NULL CONSTRAINT DF_GTU_FECHA_INICIO DEFAULT GETDATE(),
        [gtu_fecha_fin]                 DATE            NULL,
        [gtu_usuario_creacion]          INT             NOT NULL,
        [gtu_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_GTU_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_GRUPO_TRABAJO_USUARIO PRIMARY KEY CLUSTERED ([gtu_id] ASC),
        CONSTRAINT FK_GTU_GRUPO   FOREIGN KEY ([gtu_grupo_trabajo]) REFERENCES [dbo].[Grupo_Trabajo] ([gtr_id]),
        CONSTRAINT FK_GTU_USUARIO FOREIGN KEY ([gtu_usuario])       REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT UX_GTU_GRUPO_USUARIO UNIQUE ([gtu_grupo_trabajo], [gtu_usuario]),
        CONSTRAINT CK_GTU_VIGENCIA CHECK ([gtu_fecha_fin] IS NULL OR [gtu_fecha_fin] >= [gtu_fecha_inicio])
    )
    PRINT 'Tabla Grupo_Trabajo_Usuario creada correctamente.'
END
ELSE PRINT 'Tabla Grupo_Trabajo_Usuario ya existe.'
GO


/* ========================================================================
   6. INSTALACION_AREA (iar)

      Jerarquica por iar_area_padre: Planta 2 > Produccion > Linea 1.
      La jerarquia importa para el rollup de indicadores: "cuantas horas
      de paro tuvo Produccion" es la suma de sus hijas, y sin arbol hay
      que mantener esa suma a mano.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Instalacion_Area]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Instalacion_Area]
    (
        [iar_id]                        INT             NOT NULL IDENTITY(1,1),
        [iar_cliente]                   INT             NOT NULL,
        [iar_cliente_instalacion]       INT             NOT NULL,
        [iar_area_padre]                INT             NULL,
        [iar_instalacion_area_tipo]     INT             NULL,
        [iar_codigo]                    NVARCHAR(50)    NOT NULL,
        [iar_nombre]                    NVARCHAR(200)   NOT NULL,
        [iar_descripcion]               NVARCHAR(500)   NULL,
        [iar_usuario_creacion]          INT             NOT NULL,
        [iar_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_IAR_FECHA_CREACION DEFAULT GETDATE(),
        [iar_usuario_actualizacion]     INT             NULL,
        [iar_fecha_actualizacion]       DATETIME        NULL,
        [iar_habilitado]                BIT             NOT NULL CONSTRAINT DF_IAR_HABILITADO DEFAULT 1,

        CONSTRAINT PK_INSTALACION_AREA PRIMARY KEY CLUSTERED ([iar_id] ASC),
        CONSTRAINT FK_IAR_CLIENTE     FOREIGN KEY ([iar_cliente])              REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_IAR_INSTALACION FOREIGN KEY ([iar_cliente_instalacion])  REFERENCES [dbo].[Cliente_Instalacion] ([cin_id]),
        CONSTRAINT FK_IAR_PADRE       FOREIGN KEY ([iar_area_padre])           REFERENCES [dbo].[Instalacion_Area] ([iar_id]),
        CONSTRAINT FK_IAR_TIPO        FOREIGN KEY ([iar_instalacion_area_tipo]) REFERENCES [dbo].[Instalacion_Area_Tipo] ([iat_id]),
        CONSTRAINT UX_IAR_INSTALACION_CODIGO UNIQUE ([iar_cliente_instalacion], [iar_codigo])
    )
    CREATE NONCLUSTERED INDEX IX_IAR_PADRE ON [dbo].[Instalacion_Area] ([iar_area_padre])
    PRINT 'Tabla Instalacion_Area creada correctamente.'
END
ELSE PRINT 'Tabla Instalacion_Area ya existe.'
GO


/* ========================================================================
   7. CENTRO_COSTO (cco)

      Tambien jerarquico. Es lo que permite contestar "cuanto costo
      mantener la linea de panaderia este año" sin que nadie tenga que
      clasificar OT por OT a mano al cierre de mes.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Centro_Costo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Centro_Costo]
    (
        [cco_id]                        INT             NOT NULL IDENTITY(1,1),
        [cco_cliente]                   INT             NOT NULL,
        [cco_centro_costo_padre]        INT             NULL,
        [cco_codigo]                    NVARCHAR(50)    NOT NULL,
        [cco_nombre]                    NVARCHAR(200)   NOT NULL,
        [cco_usuario_creacion]          INT             NOT NULL,
        [cco_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_CCO_FECHA_CREACION DEFAULT GETDATE(),
        [cco_usuario_actualizacion]     INT             NULL,
        [cco_fecha_actualizacion]       DATETIME        NULL,
        [cco_habilitado]                BIT             NOT NULL CONSTRAINT DF_CCO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CENTRO_COSTO PRIMARY KEY CLUSTERED ([cco_id] ASC),
        CONSTRAINT FK_CCO_CLIENTE FOREIGN KEY ([cco_cliente])             REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_CCO_PADRE   FOREIGN KEY ([cco_centro_costo_padre])  REFERENCES [dbo].[Centro_Costo] ([cco_id]),
        CONSTRAINT UX_CCO_CLIENTE_CODIGO UNIQUE ([cco_cliente], [cco_codigo])
    )
    PRINT 'Tabla Centro_Costo creada correctamente.'
END
ELSE PRINT 'Tabla Centro_Costo ya existe.'
GO


/* ========================================================================
   8. CLIENTE_BINARIO (clb) -- hallazgo A-07

      El logo del cliente NO va como VARBINARY dentro de Cliente. Un
      SELECT * a la tabla maestra en una grilla de clientes traeria el
      logo de cada uno por el cable. Va aparte, igual que Usuario_Foto,
      que es el precedente que la propia base ya tenia.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Cliente_Binario]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Cliente_Binario]
    (
        [clb_id]                        INT             NOT NULL IDENTITY(1,1),
        [clb_cliente]                   INT             NOT NULL,
        [clb_tipo]                      NVARCHAR(30)    NOT NULL CONSTRAINT DF_CLB_TIPO DEFAULT 'LOGO',
        [clb_nombre_archivo]            NVARCHAR(255)   NULL,
        [clb_mime]                      NVARCHAR(100)   NULL,
        [clb_byte]                      INT             NULL,
        [clb_contenido]                 VARBINARY(MAX)  NOT NULL,
        [clb_usuario_creacion]          INT             NOT NULL,
        [clb_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_CLB_FECHA_CREACION DEFAULT GETDATE(),
        [clb_usuario_actualizacion]     INT             NULL,
        [clb_fecha_actualizacion]       DATETIME        NULL,
        [clb_habilitado]                BIT             NOT NULL CONSTRAINT DF_CLB_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CLIENTE_BINARIO PRIMARY KEY CLUSTERED ([clb_id] ASC),
        CONSTRAINT FK_CLB_CLIENTE FOREIGN KEY ([clb_cliente]) REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT UX_CLB_CLIENTE_TIPO UNIQUE ([clb_cliente], [clb_tipo]),
        CONSTRAINT CK_CLB_TIPO CHECK ([clb_tipo] IN ('LOGO', 'ICONO', 'FONDO', 'MEMBRETE'))
    )
    PRINT 'Tabla Cliente_Binario creada correctamente.'
END
ELSE PRINT 'Tabla Cliente_Binario ya existe.'
GO


/* ========================================================================
   9. IMPORTACION_CARGA (ica) -- D14

      Cargar la MATRIZ de Hamburgo no es "subir un Excel". Es una
      operacion que puede quedar a medias, que hay que poder repetir sin
      duplicar, y de la que hay que poder decir despues "de donde salio
      este activo". El hash del archivo es lo que evita cargar dos veces
      el mismo documento por error.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Importacion_Carga]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Importacion_Carga]
    (
        [ica_id]                        INT             NOT NULL IDENTITY(1,1),
        [ica_cliente]                   INT             NOT NULL,
        [ica_cliente_instalacion]       INT             NULL,
        [ica_importacion_tipo]          INT             NOT NULL,
        [ica_proceso_estado]            INT             NOT NULL,
        [ica_nombre_archivo]            NVARCHAR(255)   NOT NULL,
        [ica_hash_archivo]              NVARCHAR(64)    NULL,       -- SHA-256: evita la doble carga
        [ica_byte]                      INT             NULL,
        [ica_fila_leida]                INT             NOT NULL CONSTRAINT DF_ICA_FILA_LEIDA DEFAULT 0,
        [ica_fila_valida]               INT             NOT NULL CONSTRAINT DF_ICA_FILA_VALIDA DEFAULT 0,
        [ica_fila_rechazada]            INT             NOT NULL CONSTRAINT DF_ICA_FILA_RECHAZADA DEFAULT 0,
        [ica_fila_ambigua]              INT             NOT NULL CONSTRAINT DF_ICA_FILA_AMBIGUA DEFAULT 0,
        [ica_fecha_inicio_utc]          DATETIME        NULL,
        [ica_fecha_fin_utc]             DATETIME        NULL,
        [ica_mensaje]                   NVARCHAR(MAX)   NULL,
        [ica_usuario_creacion]          INT             NOT NULL,
        [ica_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_ICA_FECHA_CREACION DEFAULT GETDATE(),
        [ica_usuario_actualizacion]     INT             NULL,
        [ica_fecha_actualizacion]       DATETIME        NULL,
        [ica_habilitado]                BIT             NOT NULL CONSTRAINT DF_ICA_HABILITADO DEFAULT 1,

        CONSTRAINT PK_IMPORTACION_CARGA PRIMARY KEY CLUSTERED ([ica_id] ASC),
        CONSTRAINT FK_ICA_CLIENTE     FOREIGN KEY ([ica_cliente])             REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_ICA_INSTALACION FOREIGN KEY ([ica_cliente_instalacion]) REFERENCES [dbo].[Cliente_Instalacion] ([cin_id]),
        CONSTRAINT FK_ICA_TIPO        FOREIGN KEY ([ica_importacion_tipo])    REFERENCES [dbo].[Importacion_Tipo] ([iti_id]),
        CONSTRAINT FK_ICA_ESTADO      FOREIGN KEY ([ica_proceso_estado])      REFERENCES [dbo].[Proceso_Estado] ([pes_id]),
        CONSTRAINT CK_ICA_FILAS CHECK ([ica_fila_leida] >= 0 AND [ica_fila_valida] >= 0 AND [ica_fila_rechazada] >= 0)
    )
    CREATE NONCLUSTERED INDEX IX_ICA_CLIENTE_ESTADO ON [dbo].[Importacion_Carga] ([ica_cliente], [ica_proceso_estado])
    PRINT 'Tabla Importacion_Carga creada correctamente.'
END
ELSE PRINT 'Tabla Importacion_Carga ya existe.'
GO


/* ========================================================================
   10. IMPORTACION_CARGA_CELDA (icc) -- append-only

       Grano de celda, no de fila. La frecuencia escrita como
       "500 hrs / anual" es un problema de UNA celda: el activo de esa
       misma fila puede estar perfecto. Rechazar la fila entera
       significaria volver a tipear lo que ya venia bien.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Importacion_Carga_Celda]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Importacion_Carga_Celda]
    (
        [icc_id]                        INT             NOT NULL IDENTITY(1,1),
        [icc_importacion_carga]         INT             NOT NULL,
        [icc_hoja]                      NVARCHAR(100)   NULL,
        [icc_fila]                      INT             NOT NULL,
        [icc_columna]                   NVARCHAR(50)    NOT NULL,
        [icc_valor_original]            NVARCHAR(MAX)   NULL,
        [icc_valor_interpretado]        NVARCHAR(MAX)   NULL,
        [icc_importacion_celda_estado]  INT             NOT NULL,
        [icc_mensaje]                   NVARCHAR(500)   NULL,
        [icc_usuario_creacion]          INT             NOT NULL,
        [icc_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_ICC_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_IMPORTACION_CARGA_CELDA PRIMARY KEY CLUSTERED ([icc_id] ASC),
        CONSTRAINT FK_ICC_CARGA  FOREIGN KEY ([icc_importacion_carga])        REFERENCES [dbo].[Importacion_Carga] ([ica_id]),
        CONSTRAINT FK_ICC_ESTADO FOREIGN KEY ([icc_importacion_celda_estado]) REFERENCES [dbo].[Importacion_Celda_Estado] ([ice_id]),
        CONSTRAINT CK_ICC_FILA CHECK ([icc_fila] >= 0)
    )
    CREATE NONCLUSTERED INDEX IX_ICC_CARGA_ESTADO ON [dbo].[Importacion_Carga_Celda] ([icc_importacion_carga], [icc_importacion_celda_estado])
    PRINT 'Tabla Importacion_Carga_Celda creada correctamente.'
END
ELSE PRINT 'Tabla Importacion_Carga_Celda ya existe.'
GO


/* ========================================================================
   11. CARGA INICIAL MINIMA

       Zona horaria e idioma de Chile. Sin al menos una fila en
       Zona_Horaria, toda Programacion queda sin referencia horaria.
   ======================================================================== */

SET IDENTITY_INSERT [dbo].[Zona_Horaria] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Zona_Horaria] WHERE [zho_id] = 1)
    INSERT INTO [dbo].[Zona_Horaria] ([zho_id], [zho_nombre], [zho_identificador_windows], [zho_identificador_iana], [zho_offset_minuto], [zho_usuario_creacion])
    VALUES (1, N'Hora de Chile continental', N'Pacific SA Standard Time', N'America/Santiago', -240, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Zona_Horaria] WHERE [zho_id] = 2)
    INSERT INTO [dbo].[Zona_Horaria] ([zho_id], [zho_nombre], [zho_identificador_windows], [zho_identificador_iana], [zho_offset_minuto], [zho_usuario_creacion])
    VALUES (2, N'Hora de Isla de Pascua', N'Easter Island Standard Time', N'Pacific/Easter', -360, 1)
SET IDENTITY_INSERT [dbo].[Zona_Horaria] OFF
GO

SET IDENTITY_INSERT [dbo].[Idioma] ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Idioma] WHERE [idi_id] = 1)
    INSERT INTO [dbo].[Idioma] ([idi_id], [idi_codigo], [idi_nombre], [idi_orden], [idi_usuario_creacion])
    VALUES (1, N'es-CL', N'Espanol (Chile)', 1, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Idioma] WHERE [idi_id] = 2)
    INSERT INTO [dbo].[Idioma] ([idi_id], [idi_codigo], [idi_nombre], [idi_orden], [idi_usuario_creacion])
    VALUES (2, N'en-US', N'English (United States)', 2, 1)
SET IDENTITY_INSERT [dbo].[Idioma] OFF
GO

PRINT 'Bloque 21 FUNDACIONES: 12 tablas procesadas.'
GO
