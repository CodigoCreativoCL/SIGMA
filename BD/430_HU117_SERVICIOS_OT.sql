SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  10-10-2026
-- DESCRIPTION:     HU-117 · REGISTRAR LOS SERVICIOS CONTRATADOS EN UNA ORDEN
--                  (T-5152..T-5156).
-- =============================================
-- QUE CAMBIA
--
--   Orden_Trabajo_Servicio ya existía (BD/263) con proveedor, tipo, monto y
--   moneda, pero solo se leía. Aquí nace todo lo que falta para registrarlo:
--
--   1. ots_archivo_informe: el informe que entrega el proveedor. Va en la
--      línea del servicio (cada contratista entrega el suyo) y además se
--      vincula a la OT, así aparece entre sus respaldos.
--   2. INS / UPD / DEL_ORDEN_TRABAJO_SERVICIO y UPD_..._INFORME.
--   3. SEL_ORDEN_TRABAJO_SERVICIO devuelve los ids para editar y si falta el
--      informe.
--   4. SEL_OT_SERVICIO_TOTAL: el costo de terceros SEPARADO POR MONEDA. Nunca
--      se suman UF con pesos: el criterio 3 lo prohíbe y no hay tipo de cambio.
--   5. SEL_OT_SERVICIO_SIN_INFORME: lo que impide cerrar (criterio 2).
--
--   Se edita mientras la OT no esté cerrada (estado 4).
-- =============================================

/* 1) Informe del proveedor */
IF COL_LENGTH('dbo.Orden_Trabajo_Servicio', 'ots_archivo_informe') IS NULL
BEGIN
    ALTER TABLE [dbo].[Orden_Trabajo_Servicio] ADD [ots_archivo_informe] INT NULL
    ALTER TABLE [dbo].[Orden_Trabajo_Servicio] ADD CONSTRAINT FK_OTS_ARCHIVO_INFORME
        FOREIGN KEY ([ots_archivo_informe]) REFERENCES [dbo].[Archivo] ([arc_id])
END
GO

/* 2) Consulta para la ficha */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ORDEN_TRABAJO_SERVICIO]
    @CLIENTE  INT,
    @ORDEN    INT
AS
SET NOCOUNT ON

    SELECT  s.ots_id,
            s.ots_proveedor                           AS PROVEEDOR_ID,
            ISNULL(prv.prv_razon_social, '')          AS PROVEEDOR_NOMBRE,
            ISNULL(prv.prv_rut, '')                   AS PROVEEDOR_RUT,
            s.ots_servicio_tipo                       AS TIPO_ID,
            ISNULL(sti.sti_nombre, '')                AS TIPO,
            ISNULL(s.ots_descripcion, '')             AS DESCRIPCION,
            ISNULL(s.ots_cantidad, 0)                 AS CANTIDAD,
            ISNULL(s.ots_monto_unitario, 0)           AS MONTO_UNITARIO,

            /* El monto de la linea viene grabado, pero puede venir nulo si se
               cargo solo el unitario: ahi se calcula. */
            CAST(ISNULL(s.ots_monto, ISNULL(s.ots_monto_unitario, 0) * ISNULL(s.ots_cantidad, 0)) AS DECIMAL(18, 2)) AS COSTO,

            s.ots_moneda                              AS MONEDA_ID,
            ISNULL(mon.mon_codigo, '')                AS MONEDA,
            ISNULL(s.ots_documento_referencia, '')    AS DOCUMENTO,
            s.ots_fecha_servicio_utc,
            s.ots_fecha_documento,
            s.ots_archivo_informe                     AS INFORME_ID,
            arc.arc_nombre_original                   AS INFORME_NOMBRE

    FROM    [dbo].[Orden_Trabajo_Servicio] s
    JOIN    [dbo].[Orden_Trabajo] o      ON o.otr_id = s.ots_orden_trabajo
    LEFT JOIN [dbo].[Proveedor] prv      ON prv.prv_id = s.ots_proveedor
    LEFT JOIN [dbo].[Servicio_Tipo] sti  ON sti.sti_id = s.ots_servicio_tipo
    LEFT JOIN [dbo].[Moneda] mon         ON mon.mon_id = s.ots_moneda
    LEFT JOIN [dbo].[Archivo] arc        ON arc.arc_id = s.ots_archivo_informe

    WHERE   s.ots_orden_trabajo = @ORDEN
      AND   o.otr_cliente       = @CLIENTE
      AND   ISNULL(s.ots_habilitado, 1) = 1

    ORDER BY s.ots_fecha_servicio_utc, s.ots_id
GO

/* 3) Total de terceros, una fila por moneda */
CREATE OR ALTER PROCEDURE [dbo].[SEL_OT_SERVICIO_TOTAL]
    @CLIENTE  INT,
    @ORDEN    INT
AS
SET NOCOUNT ON

    SELECT  ISNULL(mon.mon_codigo, '')  AS MONEDA,
            ISNULL(mon.mon_nombre, '')  AS MONEDA_NOMBRE,
            COUNT(*)                    AS SERVICIOS,
            CAST(SUM(ISNULL(s.ots_monto, ISNULL(s.ots_monto_unitario, 0) * ISNULL(s.ots_cantidad, 0))) AS DECIMAL(18, 2)) AS TOTAL
    FROM    [dbo].[Orden_Trabajo_Servicio] s
    JOIN    [dbo].[Orden_Trabajo] o ON o.otr_id = s.ots_orden_trabajo
    LEFT JOIN [dbo].[Moneda] mon    ON mon.mon_id = s.ots_moneda
    WHERE   s.ots_orden_trabajo = @ORDEN
      AND   o.otr_cliente       = @CLIENTE
      AND   ISNULL(s.ots_habilitado, 1) = 1
    GROUP BY mon.mon_codigo, mon.mon_nombre, mon.mon_orden
    ORDER BY mon.mon_orden
GO

/* 4) Lo que impide cerrar: servicios sin informe */
CREATE OR ALTER PROCEDURE [dbo].[SEL_OT_SERVICIO_SIN_INFORME]
    @CLIENTE  INT,
    @ORDEN    INT
AS
SET NOCOUNT ON

    SELECT  s.ots_id, ISNULL(prv.prv_razon_social, '') AS PROVEEDOR_NOMBRE, ISNULL(s.ots_descripcion, '') AS DESCRIPCION
    FROM    [dbo].[Orden_Trabajo_Servicio] s
    JOIN    [dbo].[Orden_Trabajo] o ON o.otr_id = s.ots_orden_trabajo
    LEFT JOIN [dbo].[Proveedor] prv ON prv.prv_id = s.ots_proveedor
    WHERE   s.ots_orden_trabajo = @ORDEN
      AND   o.otr_cliente       = @CLIENTE
      AND   ISNULL(s.ots_habilitado, 1) = 1
      AND   s.ots_archivo_informe IS NULL
GO

/* 5) Alta */
CREATE OR ALTER PROCEDURE [dbo].[INS_ORDEN_TRABAJO_SERVICIO]
@ID               INT = NULL OUTPUT,
@CLIENTE          INT,
@ORDEN            INT,
@PROVEEDOR        INT,
@SERVICIO_TIPO    INT,
@DESCRIPCION      NVARCHAR(500),
@CANTIDAD         DECIMAL(18,2) = 1,
@MONTO_UNITARIO   DECIMAL(18,2) = NULL,
@MONTO            DECIMAL(18,2),
@MONEDA           INT,
@DOCUMENTO        NVARCHAR(100) = NULL,
@FECHA_SERVICIO   DATETIME = NULL,
@USUARIO          INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @DESCRIPCION = LTRIM(RTRIM(ISNULL(@DESCRIPCION, '')))

BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN AND otr_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- LA ORDEN DE TRABAJO NO EXISTE PARA ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
    IF EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN AND otr_orden_trabajo_estado = 4)
    BEGIN
        RAISERROR('2.- LA ORDEN YA ESTA CERRADA: NO SE LE AGREGAN SERVICIOS.', 16, 1)
        RETURN -1
    END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Proveedor] WHERE prv_id = @PROVEEDOR AND prv_cliente = @CLIENTE AND prv_habilitado = 1)
    BEGIN
        RAISERROR('3.- ELIGE EL PROVEEDOR QUE PRESTO EL SERVICIO.', 16, 1)
        RETURN -1
    END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Servicio_Tipo] WHERE sti_id = @SERVICIO_TIPO AND ISNULL(sti_cliente, @CLIENTE) = @CLIENTE AND sti_habilitado = 1)
    BEGIN
        RAISERROR('4.- ELIGE EL TIPO DE SERVICIO.', 16, 1)
        RETURN -1
    END
    IF LEN(@DESCRIPCION) = 0
    BEGIN
        RAISERROR('5.- DESCRIBE EL SERVICIO.', 16, 1)
        RETURN -1
    END
    IF ISNULL(@MONTO, 0) <= 0
    BEGIN
        RAISERROR('6.- EL MONTO DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Moneda] WHERE mon_id = @MONEDA AND mon_habilitado = 1)
    BEGIN
        RAISERROR('7.- ELIGE LA MONEDA DEL MONTO.', 16, 1)
        RETURN -1
    END
    IF @FECHA_SERVICIO IS NOT NULL AND CAST(@FECHA_SERVICIO AS DATE) > CAST(@DATE_NOW AS DATE)
    BEGIN
        RAISERROR('8.- LA FECHA DEL SERVICIO NO PUEDE SER FUTURA.', 16, 1)
        RETURN -1
    END

    BEGIN TRANSACTION
        INSERT INTO [dbo].[Orden_Trabajo_Servicio]
            (ots_orden_trabajo, ots_proveedor, ots_servicio_tipo, ots_descripcion, ots_cantidad, ots_monto_unitario, ots_monto,
             ots_moneda, ots_documento_referencia, ots_fecha_servicio_utc, ots_usuario_creacion, ots_fecha_creacion, ots_habilitado)
        VALUES
            (@ORDEN, @PROVEEDOR, @SERVICIO_TIPO, @DESCRIPCION, ISNULL(@CANTIDAD, 1), @MONTO_UNITARIO, @MONTO,
             @MONEDA, NULLIF(LTRIM(RTRIM(@DOCUMENTO)), ''), ISNULL(@FECHA_SERVICIO, @DATE_NOW), @USUARIO, @DATE_NOW, 1)
        SET @ID = SCOPE_IDENTITY()
    COMMIT TRANSACTION

    SELECT @ID AS ID, 200 AS CODE, 'Servicio registrado con éxito.' AS MENSAJE
END
GO

/* 6) Corrección, mientras la OT no esté cerrada */
CREATE OR ALTER PROCEDURE [dbo].[UPD_ORDEN_TRABAJO_SERVICIO]
@ID               INT,
@CLIENTE          INT,
@PROVEEDOR        INT,
@SERVICIO_TIPO    INT,
@DESCRIPCION      NVARCHAR(500),
@CANTIDAD         DECIMAL(18,2) = 1,
@MONTO_UNITARIO   DECIMAL(18,2) = NULL,
@MONTO            DECIMAL(18,2),
@MONEDA           INT,
@DOCUMENTO        NVARCHAR(100) = NULL,
@FECHA_SERVICIO   DATETIME = NULL,
@USUARIO          INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @ESTADO INT

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @DESCRIPCION = LTRIM(RTRIM(ISNULL(@DESCRIPCION, '')))

BEGIN
    SELECT @ESTADO = o.otr_orden_trabajo_estado
      FROM [dbo].[Orden_Trabajo_Servicio] s JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = s.ots_orden_trabajo
     WHERE s.ots_id = @ID AND o.otr_cliente = @CLIENTE AND s.ots_habilitado = 1
    IF @ESTADO IS NULL
    BEGIN
        RAISERROR('1.- EL SERVICIO NO EXISTE.', 16, 1)
        RETURN -1
    END
    IF @ESTADO = 4
    BEGIN
        RAISERROR('2.- LA ORDEN YA ESTA CERRADA: SUS SERVICIOS NO SE CORRIGEN.', 16, 1)
        RETURN -1
    END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Proveedor] WHERE prv_id = @PROVEEDOR AND prv_cliente = @CLIENTE AND prv_habilitado = 1)
    BEGIN
        RAISERROR('3.- ELIGE EL PROVEEDOR QUE PRESTO EL SERVICIO.', 16, 1)
        RETURN -1
    END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Servicio_Tipo] WHERE sti_id = @SERVICIO_TIPO AND ISNULL(sti_cliente, @CLIENTE) = @CLIENTE AND sti_habilitado = 1)
    BEGIN
        RAISERROR('4.- ELIGE EL TIPO DE SERVICIO.', 16, 1)
        RETURN -1
    END
    IF LEN(@DESCRIPCION) = 0
    BEGIN
        RAISERROR('5.- DESCRIBE EL SERVICIO.', 16, 1)
        RETURN -1
    END
    IF ISNULL(@MONTO, 0) <= 0
    BEGIN
        RAISERROR('6.- EL MONTO DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Moneda] WHERE mon_id = @MONEDA AND mon_habilitado = 1)
    BEGIN
        RAISERROR('7.- ELIGE LA MONEDA DEL MONTO.', 16, 1)
        RETURN -1
    END
    IF @FECHA_SERVICIO IS NOT NULL AND CAST(@FECHA_SERVICIO AS DATE) > CAST(@DATE_NOW AS DATE)
    BEGIN
        RAISERROR('8.- LA FECHA DEL SERVICIO NO PUEDE SER FUTURA.', 16, 1)
        RETURN -1
    END

    UPDATE [dbo].[Orden_Trabajo_Servicio]
       SET ots_proveedor = @PROVEEDOR, ots_servicio_tipo = @SERVICIO_TIPO, ots_descripcion = @DESCRIPCION,
           ots_cantidad = ISNULL(@CANTIDAD, 1), ots_monto_unitario = @MONTO_UNITARIO, ots_monto = @MONTO, ots_moneda = @MONEDA,
           ots_documento_referencia = NULLIF(LTRIM(RTRIM(@DOCUMENTO)), ''), ots_fecha_servicio_utc = ISNULL(@FECHA_SERVICIO, ots_fecha_servicio_utc),
           ots_usuario_actualizacion = @USUARIO, ots_fecha_actualizacion = @DATE_NOW
     WHERE ots_id = @ID

    SELECT @ID AS ID, 200 AS CODE, 'Servicio actualizado con éxito.' AS MENSAJE
END
GO

/* 7) Baja lógica */
CREATE OR ALTER PROCEDURE [dbo].[DEL_ORDEN_TRABAJO_SERVICIO]
@ID       INT,
@CLIENTE  INT,
@USUARIO  INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @ESTADO INT

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN
    SELECT @ESTADO = o.otr_orden_trabajo_estado
      FROM [dbo].[Orden_Trabajo_Servicio] s JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = s.ots_orden_trabajo
     WHERE s.ots_id = @ID AND o.otr_cliente = @CLIENTE AND s.ots_habilitado = 1
    IF @ESTADO IS NULL
    BEGIN
        RAISERROR('1.- EL SERVICIO NO EXISTE.', 16, 1)
        RETURN -1
    END
    IF @ESTADO = 4
    BEGIN
        RAISERROR('2.- LA ORDEN YA ESTA CERRADA: SUS SERVICIOS NO SE QUITAN.', 16, 1)
        RETURN -1
    END

    UPDATE [dbo].[Orden_Trabajo_Servicio]
       SET ots_habilitado = 0, ots_usuario_actualizacion = @USUARIO, ots_fecha_actualizacion = @DATE_NOW
     WHERE ots_id = @ID

    SELECT @ID AS ID, 200 AS CODE, 'Servicio quitado.' AS MENSAJE
END
GO

/* 8) El informe del proveedor: el archivo ya se subió (ArchivoController) y se vincula a la OT aparte */
CREATE OR ALTER PROCEDURE [dbo].[UPD_ORDEN_TRABAJO_SERVICIO_INFORME]
@ID       INT,
@CLIENTE  INT,
@ARCHIVO  INT,
@USUARIO  INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @ESTADO INT

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN
    SELECT @ESTADO = o.otr_orden_trabajo_estado
      FROM [dbo].[Orden_Trabajo_Servicio] s JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = s.ots_orden_trabajo
     WHERE s.ots_id = @ID AND o.otr_cliente = @CLIENTE AND s.ots_habilitado = 1
    IF @ESTADO IS NULL
    BEGIN
        RAISERROR('1.- EL SERVICIO NO EXISTE.', 16, 1)
        RETURN -1
    END
    IF @ESTADO = 4
    BEGIN
        RAISERROR('2.- LA ORDEN YA ESTA CERRADA.', 16, 1)
        RETURN -1
    END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo] WHERE arc_id = @ARCHIVO AND arc_cliente = @CLIENTE)
    BEGIN
        RAISERROR('3.- EL ARCHIVO NO EXISTE.', 16, 1)
        RETURN -1
    END

    UPDATE [dbo].[Orden_Trabajo_Servicio]
       SET ots_archivo_informe = @ARCHIVO, ots_usuario_actualizacion = @USUARIO, ots_fecha_actualizacion = @DATE_NOW
     WHERE ots_id = @ID

    SELECT @ID AS ID, 200 AS CODE, 'Informe adjuntado.' AS MENSAJE
END
GO

/* 9) Catálogos del formulario: tipos de servicio (comunes y del cliente) y monedas */
CREATE OR ALTER PROCEDURE [dbo].[SEL_OT_SERVICIO_CATALOGO]
    @CLIENTE  INT
AS
SET NOCOUNT ON

    SELECT  sti_id AS ID, sti_nombre AS NOMBRE
    FROM    [dbo].[Servicio_Tipo]
    WHERE   ISNULL(sti_cliente, @CLIENTE) = @CLIENTE AND sti_habilitado = 1
    ORDER BY ISNULL(sti_orden, 999), sti_nombre

    SELECT  mon_id AS ID, mon_codigo AS CODIGO, mon_nombre AS NOMBRE
    FROM    [dbo].[Moneda]
    WHERE   mon_habilitado = 1
    ORDER BY ISNULL(mon_orden, 999), mon_id
GO
