SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  10-10-2026
-- DESCRIPTION:     HU-125 · IMPRIMIR UNA ORDEN DE TRABAJO (T-5302..T-5305).
-- =============================================
-- QUE CAMBIA
--
--   La orden ya tiene todo lo que se imprime en sus SP de siempre (cabecera,
--   pasos, repuestos, mano de obra, servicios, firmas). Lo único que faltaba
--   es el ENCABEZADO DEL CLIENTE: razón social, RUT y logo, que es lo que
--   hace que la hoja sea «el formato que usa la planta». Este SP lo entrega
--   junto con la OT, acotado al cliente en sesión. Nada se arma por
--   concatenación: todo va por parámetros.
--
--   Índices: el papel se pide desde la ficha, por id; los hijos de la OT se
--   leen por su FK. Se asegura que pasos y validaciones tengan su índice por
--   orden (servicios, repuestos y mano de obra ya lo tenían).
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[SEL_ORDEN_TRABAJO_IMPRIMIR]
    @CLIENTE  INT,
    @ID       INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ID AND otr_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA ORDEN DE TRABAJO NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

    SELECT  c.cli_id,
            ISNULL(NULLIF(c.cli_razon_social, ''), c.cli_nombre) AS CLIENTE_RAZON_SOCIAL,
            ISNULL(c.cli_nombre_fantasia, c.cli_nombre)           AS CLIENTE_NOMBRE,
            ISNULL(c.cli_identificador, '')                       AS CLIENTE_RUT,
            c.cli_archivo_logo                                    AS CLIENTE_LOGO,
            [dbo].[FNC_PAIS_HORA](c.cli_pais)                     AS FECHA_IMPRESION
    FROM    [dbo].[Cliente] c
    WHERE   c.cli_id = @CLIENTE
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OTP_ORDEN_TRABAJO_IMP' AND object_id = OBJECT_ID('dbo.Orden_Trabajo_Paso'))
   AND NOT EXISTS (SELECT 1 FROM sys.index_columns ic JOIN sys.columns col ON col.object_id = ic.object_id AND col.column_id = ic.column_id
                    WHERE ic.object_id = OBJECT_ID('dbo.Orden_Trabajo_Paso') AND ic.key_ordinal = 1 AND col.name = 'otp_orden_trabajo')
    CREATE NONCLUSTERED INDEX IX_OTP_ORDEN_TRABAJO_IMP ON [dbo].[Orden_Trabajo_Paso] (otp_orden_trabajo)
GO
IF COL_LENGTH('dbo.Orden_Trabajo_Validacion', 'otv_orden_trabajo') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.index_columns ic JOIN sys.columns col ON col.object_id = ic.object_id AND col.column_id = ic.column_id
                    WHERE ic.object_id = OBJECT_ID('dbo.Orden_Trabajo_Validacion') AND ic.key_ordinal = 1 AND col.name = 'otv_orden_trabajo')
    EXEC('CREATE NONCLUSTERED INDEX IX_OTV_ORDEN_TRABAJO_IMP ON [dbo].[Orden_Trabajo_Validacion] (otv_orden_trabajo)')
GO
