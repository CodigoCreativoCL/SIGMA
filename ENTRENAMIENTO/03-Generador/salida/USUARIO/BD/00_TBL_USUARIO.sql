USE [SIGMA]
GO
/****** Objeto:  Table [dbo].[USUARIO]    Fecha de script: 14-08-2026 19:31:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO CODIGO CREATIVO
-- FECHA CREACION:  14-08-2026
-- DESCRIPTION:     CREA LA TABLA MAESTRA DE USUARIOS.
-- =============================================

-- ---------------------------------------------------------------------------
-- PATRON: PATRON_SP.md seccion 8.
--  1. Script IDEMPOTENTE (se puede re-ejecutar sin error).
--  2. Prefijo de 3 letras en todas las columnas: USUARIO -> USU_
--  3. Columnas de auditoria + USU_HABILITADO (baja logica).
--  4. Constraints con nombre explicito: PK_ FK_ DF_ IX_ UX_
-- ---------------------------------------------------------------------------

IF NOT EXISTS (
    SELECT 1 FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[USUARIO]')
    AND type = 'U'
)
BEGIN
    CREATE TABLE [dbo].[USUARIO]
    (
        [USU_ID]                INT            NOT NULL IDENTITY(1,1),
        [USU_RUT]               NVARCHAR(12)   NOT NULL,
        [USU_NOMBRES]           NVARCHAR(200)  NOT NULL,
        [USU_APELLIDOS]         NVARCHAR(200)  NOT NULL,
        [USU_EMAIL]             NVARCHAR(200)  NOT NULL,
        [USU_TELEFONO]          NVARCHAR(20)   NULL,
        [USU_PASSWORD]          NVARCHAR(200)  NOT NULL,
        [USU_PERFIL]            INT            NOT NULL,
        [USU_PAIS]              INT            NOT NULL,
        [USU_USUARIO_CREACION]  INT            NOT NULL,
        [USU_FECHA_CREACION]    DATETIME       NOT NULL CONSTRAINT DF_USU_FECHA_CREACION DEFAULT GETDATE(),
        [USU_USUARIO_ACT]       INT            NULL,
        [USU_FECHA_ACT]         DATETIME       NULL,
        [USU_HABILITADO]        BIT            NOT NULL CONSTRAINT DF_USU_HABILITADO DEFAULT 1,

        CONSTRAINT PK_USUARIO PRIMARY KEY CLUSTERED ([USU_ID] ASC),

        CONSTRAINT FK_USU_PERFIL FOREIGN KEY ([USU_PERFIL])
            REFERENCES [dbo].[PERFIL] ([PER_ID]),

        CONSTRAINT FK_USU_PAIS FOREIGN KEY ([USU_PAIS])
            REFERENCES [dbo].[PAISES] ([PAI_ID])
    )

    -- RUT no puede repetirse.
    CREATE UNIQUE NONCLUSTERED INDEX UX_USU_RUT
        ON [dbo].[USUARIO] ([USU_RUT])

    -- Email no puede repetirse.
    CREATE UNIQUE NONCLUSTERED INDEX UX_USU_EMAIL
        ON [dbo].[USUARIO] ([USU_EMAIL])

    -- Indice de apoyo a los filtros del listado.
    CREATE NONCLUSTERED INDEX IX_USU_PERFIL
        ON [dbo].[USUARIO] ([USU_PERFIL])

    -- Indice de apoyo a los filtros del listado.
    CREATE NONCLUSTERED INDEX IX_USU_PAIS
        ON [dbo].[USUARIO] ([USU_PAIS])

    PRINT 'Tabla USUARIO creada correctamente.'
END
ELSE
    PRINT 'Tabla USUARIO ya existe.'
GO
