SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  10-10-2026
-- DESCRIPTION:     FICHA DE OT V8 (ANEXO V8 DEL REDISEÑO): COMENTARIOS Y
--                  BODEGA DE SALIDA DEL REPUESTO AGREGADO EN TERRENO.
-- =============================================
-- QUE CAMBIA
--
--   La ficha nueva tiene «Comentar» (acción rápida y caja en Resumen) y
--   «Agregar repuesto» desde el riel de Ejecución. Lo demás (horas, detención
--   y su término, servicios, hallazgo) ya tenía SP.
--
--   1. INS/SEL_OT_COMENTARIO: el comentario es una entrada de Bitacora tipo
--      OBSERVACION ligada a la OT (bit_orden_trabajo) y a su activo, así
--      aparece también en la bitácora del activo. No pasa por API_INS_BITACORA
--      porque esa exige afiliación a la planta (es la regla de la app en
--      terreno); aquí basta con que la OT sea del cliente en sesión.
--   2. SEL_OT_REPUESTO_BODEGA: de qué bodega sale el repuesto: la que tiene
--      más disponible (cantidad - reservada). La persona no elige bodega en
--      terreno; si no hay stock en ninguna, no se devuelve nada y la web avisa.
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[INS_OT_COMENTARIO]
@ID       INT = NULL OUTPUT,
@CLIENTE  INT,
@ORDEN    INT,
@TEXTO    NVARCHAR(2000),
@USUARIO  INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @PLANTA INT, @AREA INT, @ACTIVO INT, @COMP INT

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @TEXTO = LTRIM(RTRIM(ISNULL(@TEXTO, '')))

BEGIN
    SELECT @PLANTA = otr_cliente_instalacion, @AREA = otr_instalacion_area, @ACTIVO = otr_activo, @COMP = otr_activo_componente
      FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN AND otr_cliente = @CLIENTE
    IF @PLANTA IS NULL AND @ACTIVO IS NULL
    BEGIN
        RAISERROR('1.- LA ORDEN DE TRABAJO NO EXISTE PARA ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
    IF LEN(@TEXTO) = 0
    BEGIN
        RAISERROR('2.- ESCRIBE EL COMENTARIO.', 16, 1)
        RETURN -1
    END

    INSERT INTO [dbo].[Bitacora]
        (bit_uuid, bit_cliente, bit_cliente_instalacion, bit_instalacion_area, bit_bitacora_tipo, bit_activo, bit_activo_componente,
         bit_orden_trabajo, bit_titulo, bit_texto, bit_fecha_evento_utc, bit_requiere_atencion, bit_usuario_creacion, bit_fecha_creacion)
    VALUES
        (NEWID(), @CLIENTE, @PLANTA, @AREA, 1, @ACTIVO, @COMP,
         @ORDEN, N'Comentario en OT', @TEXTO, GETUTCDATE(), 0, @USUARIO, @DATE_NOW)
    SET @ID = SCOPE_IDENTITY()

    SELECT @ID AS ID, 200 AS CODE, 'Comentario registrado.' AS MENSAJE
END
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_OT_COMENTARIO]
    @CLIENTE  INT,
    @ORDEN    INT
AS
SET NOCOUNT ON

    SELECT  b.bit_id                    AS ID,
            b.bit_texto                 AS TEXTO,
            b.bit_fecha_creacion        AS FECHA,
            ISNULL(u.usu_nombre, '')    AS QUIEN
    FROM    [dbo].[Bitacora] b
    LEFT JOIN [dbo].[Usuario] u ON u.usu_id = b.bit_usuario_creacion
    WHERE   b.bit_orden_trabajo = @ORDEN
      AND   b.bit_cliente       = @CLIENTE
    ORDER BY b.bit_fecha_creacion DESC, b.bit_id DESC
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_OT_REPUESTO_BODEGA]
    @CLIENTE   INT,
    @REPUESTO  INT
AS
SET NOCOUNT ON

    SELECT TOP 1 s.isa_bodega AS BODEGA, s.isa_bodega_ubicacion AS UBICACION,
           CAST(SUM(s.isa_cantidad - ISNULL(s.isa_cantidad_reservada, 0)) OVER (PARTITION BY s.isa_bodega) AS DECIMAL(18, 2)) AS DISPONIBLE
    FROM   [dbo].[Inventario_Saldo] s
    WHERE  s.isa_cliente = @CLIENTE AND s.isa_repuesto = @REPUESTO
      AND  s.isa_cantidad - ISNULL(s.isa_cantidad_reservada, 0) > 0
    ORDER BY DISPONIBLE DESC, s.isa_cantidad DESC
GO
