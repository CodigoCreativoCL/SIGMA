USE [SIGMA]
GO
/****** Objeto:  Table [dbo].[PRODUCTO]    Fecha de script: 14-08-2026 19:31:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO CODIGO CREATIVO
-- FECHA CREACION:  14-08-2026
-- DESCRIPTION:     CREA LA TABLA MAESTRA DE PRODUCTOS.
-- =============================================

-- ---------------------------------------------------------------------------
-- PATRON: PATRON_SP.md seccion 8.
--  1. Script IDEMPOTENTE (se puede re-ejecutar sin error).
--  2. Prefijo de 3 letras en todas las columnas: PRODUCTO -> PRO_
--  3. Columnas de auditoria + PRO_HABILITADO (baja logica).
--  4. Constraints con nombre explicito: PK_ FK_ DF_ IX_ UX_
-- ---------------------------------------------------------------------------

IF NOT EXISTS (
    SELECT 1 FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[PRODUCTO]')
    AND type = 'U'
)
BEGIN
    CREATE TABLE [dbo].[PRODUCTO]
    (
        [PRO_ID]                INT            NOT NULL IDENTITY(1,1),
        [PRO_CODIGO]            NVARCHAR(20)   NOT NULL,
        [PRO_NOMBRE]            NVARCHAR(200)  NOT NULL,
        [PRO_DESCRIPCION]       NVARCHAR(MAX)  NULL,
        [PRO_CATEGORIA]         INT            NOT NULL,
        [PRO_PROVEEDOR]         INT            NULL,
        [PRO_PRECIO]            DECIMAL(18,2)  NOT NULL,
        [PRO_STOCK]             INT            NULL,
        [PRO_VENCIMIENTO]       DATETIME       NULL,
        [PRO_USUARIO_CREACION]  INT            NOT NULL,
        [PRO_FECHA_CREACION]    DATETIME       NOT NULL CONSTRAINT DF_PRO_FECHA_CREACION DEFAULT GETDATE(),
        [PRO_USUARIO_ACT]       INT            NULL,
        [PRO_FECHA_ACT]         DATETIME       NULL,
        [PRO_HABILITADO]        BIT            NOT NULL CONSTRAINT DF_PRO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PRODUCTO PRIMARY KEY CLUSTERED ([PRO_ID] ASC),

        CONSTRAINT FK_PRO_CATEGORIA FOREIGN KEY ([PRO_CATEGORIA])
            REFERENCES [dbo].[CATEGORIA] ([CAT_ID]),

        CONSTRAINT FK_PRO_PROVEEDOR FOREIGN KEY ([PRO_PROVEEDOR])
            REFERENCES [dbo].[PROVEEDOR] ([PRV_ID])
    )

    -- Codigo no puede repetirse.
    CREATE UNIQUE NONCLUSTERED INDEX UX_PRO_CODIGO
        ON [dbo].[PRODUCTO] ([PRO_CODIGO])

    -- Nombre no puede repetirse.
    CREATE UNIQUE NONCLUSTERED INDEX UX_PRO_NOMBRE
        ON [dbo].[PRODUCTO] ([PRO_NOMBRE])

    -- Indice de apoyo a los filtros del listado.
    CREATE NONCLUSTERED INDEX IX_PRO_CATEGORIA
        ON [dbo].[PRODUCTO] ([PRO_CATEGORIA])

    -- Indice de apoyo a los filtros del listado.
    CREATE NONCLUSTERED INDEX IX_PRO_PROVEEDOR
        ON [dbo].[PRODUCTO] ([PRO_PROVEEDOR])

    PRINT 'Tabla PRODUCTO creada correctamente.'
END
ELSE
    PRINT 'Tabla PRODUCTO ya existe.'
GO
