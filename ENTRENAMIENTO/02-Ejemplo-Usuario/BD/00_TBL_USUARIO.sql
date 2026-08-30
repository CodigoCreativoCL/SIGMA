USE [SIGMA]
GO
/****** Objeto:  Table [dbo].[USUARIO]    Fecha de script: 14-08-2026 10:00:00 ******/
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
-- REGLAS DEL PATRON (ver 00-Patrones-Originales/PATRON_SP.md seccion 8):
--
--  1. El script es IDEMPOTENTE: se verifica con sys.objects antes de crear,
--     para poder re-ejecutarlo sin que reviente.
--  2. Prefijo de 3 letras en TODAS las columnas: tabla USUARIO -> USU_.
--  3. Columnas de auditoria obligatorias en toda tabla del sistema:
--        USU_USUARIO_CREACION / USU_FECHA_CREACION
--        USU_USUARIO_ACT      / USU_FECHA_ACT
--        USU_HABILITADO       (baja logica)
--  4. Constraints con nombre EXPLICITO y prefijo por tipo:
--        PK_ (primary key)  FK_ (foreign key)
--        DF_ (default)      IX_ (indice)   UX_ (indice unico)
--  5. PRINT final indicando si se creo o ya existia.
-- ---------------------------------------------------------------------------

IF NOT EXISTS (
    SELECT 1 FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[USUARIO]')
    AND type = 'U'
)
BEGIN
    CREATE TABLE [dbo].[USUARIO]
    (
        [USU_ID]                INT             NOT NULL IDENTITY(1,1),
        [USU_RUT]               NVARCHAR(12)    NOT NULL,
        [USU_NOMBRES]           NVARCHAR(200)   NOT NULL,
        [USU_APELLIDOS]         NVARCHAR(200)   NOT NULL,
        [USU_EMAIL]             NVARCHAR(200)   NOT NULL,
        [USU_TELEFONO]          NVARCHAR(20)    NULL,
        [USU_PASSWORD]          NVARCHAR(200)   NOT NULL,
        [USU_PERFIL]            INT             NOT NULL,
        [USU_PAIS]              INT             NOT NULL,
        [USU_USUARIO_CREACION]  INT             NOT NULL,
        [USU_FECHA_CREACION]    DATETIME        NOT NULL CONSTRAINT DF_USU_FECHA_CREACION DEFAULT GETDATE(),
        [USU_USUARIO_ACT]       INT             NULL,
        [USU_FECHA_ACT]         DATETIME        NULL,
        [USU_HABILITADO]        BIT             NOT NULL CONSTRAINT DF_USU_HABILITADO DEFAULT 1,

        CONSTRAINT PK_USUARIO PRIMARY KEY CLUSTERED ([USU_ID] ASC),

        CONSTRAINT FK_USU_PERFIL FOREIGN KEY ([USU_PERFIL])
            REFERENCES [dbo].[PERFIL] ([PER_ID]),

        CONSTRAINT FK_USU_PAIS FOREIGN KEY ([USU_PAIS])
            REFERENCES [dbo].[PAISES] ([PAI_ID])
    )

    -- El email es la credencial de acceso: no puede repetirse.
    CREATE UNIQUE NONCLUSTERED INDEX UX_USU_EMAIL
        ON [dbo].[USUARIO] ([USU_EMAIL])

    -- El RUT tambien es unico por persona.
    CREATE UNIQUE NONCLUSTERED INDEX UX_USU_RUT
        ON [dbo].[USUARIO] ([USU_RUT])

    -- Indice de apoyo al filtro mas usado del listado.
    CREATE NONCLUSTERED INDEX IX_USU_PERFIL
        ON [dbo].[USUARIO] ([USU_PERFIL])

    PRINT 'Tabla USUARIO creada correctamente.'
END
ELSE
    PRINT 'Tabla USUARIO ya existe.'
GO
