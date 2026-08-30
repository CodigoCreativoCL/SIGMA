USE [SIGMA]
GO
/****** Objeto:  Table [dbo].[CLIENTE]    Fecha de script: 14-08-2026 19:47:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO CODIGO CREATIVO
-- FECHA CREACION:  14-08-2026
-- DESCRIPTION:     CREA LA TABLA MAESTRA DE CLIENTES.
-- =============================================

-- ---------------------------------------------------------------------------
-- PATRON: PATRON_SP.md seccion 8.
--  1. Script IDEMPOTENTE (se puede re-ejecutar sin error).
--  2. Prefijo de 3 letras en todas las columnas: CLIENTE -> CLI_
--  3. Columnas de auditoria + CLI_HABILITADO (baja logica).
--  4. Constraints con nombre explicito: PK_ FK_ DF_ IX_ UX_
-- ---------------------------------------------------------------------------

IF NOT EXISTS (
    SELECT 1 FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[CLIENTE]')
    AND type = 'U'
)
BEGIN
    CREATE TABLE [dbo].[CLIENTE]
    (
        [CLI_ID]                INT            NOT NULL IDENTITY(1,1),
        [CLI_NOMBRE]            NVARCHAR(200)  NULL,
        [CLI_USUARIO_CREACION]  INT            NOT NULL,
        [CLI_FECHA_CREACION]    DATETIME       NOT NULL CONSTRAINT DF_CLI_FECHA_CREACION DEFAULT GETDATE(),
        [CLI_USUARIO_ACT]       INT            NULL,
        [CLI_FECHA_ACT]         DATETIME       NULL,
        [CLI_HABILITADO]        BIT            NOT NULL CONSTRAINT DF_CLI_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CLIENTE PRIMARY KEY CLUSTERED ([CLI_ID] ASC)
    )

    PRINT 'Tabla CLIENTE creada correctamente.'
END
ELSE
    PRINT 'Tabla CLIENTE ya existe.'
GO
