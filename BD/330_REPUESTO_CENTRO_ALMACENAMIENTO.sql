/* ============================================================================
   SIGMA - Bloque 330
   CENTRO DEL REPUESTO: lo nuevo de la bodega, visto desde el repuesto
   ----------------------------------------------------------------------------

   El mapa 3D trajo metodo de salida, medidas y peso, planograma, conteo
   ciclico, consumo y solicitudes de reposicion (bloques 326 a 329). El Centro
   del repuesto los muestra desde su lado: donde esta cada caja, en que
   posicion, cuando entro y vence, cuando se conto, cuanto se consume y que se
   pidio. Solo lecturas: escribir sigue pasando por los SP de esos bloques.

     SEL_REPUESTO_ALMACENAMIENTO  una fila por bodega + ubicacion con saldo:
                                  metodo que rige, ingreso, vencimiento,
                                  posicion fija y el ultimo conteo de esa caja.
     SEL_REPUESTO_CONSUMO         salidas por consumo y merma por bodega en los
                                  ultimos N dias.
     SEL_REPUESTO_CONTEOS         las ultimas cajas contadas del repuesto.
     SEL_REPUESTO_REPOSICIONES    las solicitudes de reposicion que lo incluyen.
   ============================================================================ */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO_ALMACENAMIENTO]
    @CLIENTE  INT,
    @REPUESTO INT
AS
SET NOCOUNT ON

;WITH cubo AS (
    SELECT  s.isa_bodega AS bod, s.isa_bodega_ubicacion AS ubi,
            SUM(s.isa_cantidad) AS cantidad,
            MIN([dbo].[FNC_SALDO_FECHA_INGRESO](s.isa_repuesto, s.isa_bodega, s.isa_bodega_ubicacion, s.isa_repuesto_lote)) AS ingreso,
            MIN(lo.rlo_fecha_vencimiento) AS vence,
            COUNT(DISTINCT s.isa_repuesto_lote) AS lotes
    FROM    [dbo].[Inventario_Saldo] s
    LEFT JOIN [dbo].[Repuesto_Lote] lo ON lo.rlo_id = s.isa_repuesto_lote
    WHERE   s.isa_cliente = @CLIENTE AND s.isa_repuesto = @REPUESTO AND s.isa_cantidad > 0
    GROUP BY s.isa_bodega, s.isa_bodega_ubicacion
), conteo AS (
    SELECT  d.icd_bodega_ubicacion AS ubi, d.icd_fecha AS fecha, d.icd_diferencia AS dif, d.icd_usuario AS usu,
            ROW_NUMBER() OVER (PARTITION BY d.icd_bodega_ubicacion ORDER BY d.icd_fecha DESC) AS n
    FROM    [dbo].[Inventario_Conteo_Detalle] d
    JOIN    [dbo].[Inventario_Conteo] c ON c.ico_id = d.icd_conteo
    WHERE   c.ico_cliente = @CLIENTE AND d.icd_repuesto = @REPUESTO
)
    SELECT  b.bod_id AS BOD_ID, b.bod_codigo AS BOD_CODIGO, b.bod_nombre AS BOD_NOMBRE,
            ISNULL(r.rep_metodo_salida, b.bod_metodo_salida) AS METODO,
            CAST(CASE WHEN r.rep_metodo_salida IS NULL THEN 0 ELSE 1 END AS BIT) AS METODO_PROPIO,
            c.ubi AS BUB_ID, ISNULL(u.bub_codigo, '') AS BUB_CODIGO,
            c.cantidad AS CANTIDAD, c.lotes AS LOTES, c.ingreso AS INGRESO, c.vence AS VENCE,
            p.bup_nivel AS NIVEL, p.bup_posicion AS POSICION, p.bup_fila AS FILA,
            k.fecha AS CONTEO_FECHA, k.dif AS CONTEO_DIFERENCIA,
            LTRIM(RTRIM(ISNULL(us.usu_nombre, '') + ' ' + ISNULL(us.usu_apellido_paterno, ''))) AS CONTEO_USUARIO
    FROM    cubo c
    JOIN    [dbo].[Bodega] b ON b.bod_id = c.bod
    JOIN    [dbo].[Repuesto] r ON r.rep_id = @REPUESTO
    LEFT JOIN [dbo].[Bodega_Ubicacion] u ON u.bub_id = c.ubi
    LEFT JOIN [dbo].[Bodega_Ubicacion_Posicion] p ON p.bup_ubicacion = c.ubi AND p.bup_repuesto = @REPUESTO
    LEFT JOIN conteo k ON k.ubi = c.ubi AND k.n = 1
    LEFT JOIN [dbo].[Usuario] us ON us.usu_id = k.usu
    ORDER BY b.bod_nombre, u.bub_codigo
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO_CONSUMO]
    @CLIENTE  INT,
    @REPUESTO INT,
    @DIAS     INT = 90
AS
SET NOCOUNT ON
DECLARE @DESDE DATETIME = DATEADD(DAY, -ISNULL(@DIAS, 90), GETUTCDATE())
    SELECT  b.bod_id AS BOD_ID, b.bod_nombre AS BOD_NOMBRE,
            SUM(m.imo_cantidad) AS SALIDAS,
            SUM(CASE WHEN m.imo_inventario_movimiento_tipo = 2 THEN 1 ELSE 0 END) AS RETIROS,
            MAX(m.imo_fecha_movimiento_utc) AS ULTIMA
    FROM    [dbo].[Inventario_Movimiento] m
    JOIN    [dbo].[Bodega] b ON b.bod_id = m.imo_bodega
    WHERE   m.imo_cliente = @CLIENTE AND m.imo_repuesto = @REPUESTO
      AND   m.imo_inventario_movimiento_tipo IN (2, 8)
      AND   m.imo_fecha_movimiento_utc >= @DESDE
    GROUP BY b.bod_id, b.bod_nombre
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO_CONTEOS]
    @CLIENTE  INT,
    @REPUESTO INT
AS
SET NOCOUNT ON
    SELECT TOP 30
            d.icd_fecha AS FECHA, c.ico_id AS CONTEO, c.ico_alcance AS ALCANCE, c.ico_estado AS ESTADO,
            b.bod_nombre AS BODEGA, u.bub_codigo AS UBICACION,
            d.icd_sistema AS SISTEMA, d.icd_contado AS CONTADO, d.icd_diferencia AS DIFERENCIA,
            ISNULL(d.icd_resultado, '') AS RESULTADO,
            LTRIM(RTRIM(ISNULL(us.usu_nombre, '') + ' ' + ISNULL(us.usu_apellido_paterno, ''))) AS USUARIO
    FROM    [dbo].[Inventario_Conteo_Detalle] d
    JOIN    [dbo].[Inventario_Conteo] c ON c.ico_id = d.icd_conteo
    JOIN    [dbo].[Bodega] b ON b.bod_id = c.ico_bodega
    JOIN    [dbo].[Bodega_Ubicacion] u ON u.bub_id = d.icd_bodega_ubicacion
    LEFT JOIN [dbo].[Usuario] us ON us.usu_id = d.icd_usuario
    WHERE   c.ico_cliente = @CLIENTE AND d.icd_repuesto = @REPUESTO
    ORDER BY d.icd_fecha DESC
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO_REPOSICIONES]
    @CLIENTE  INT,
    @REPUESTO INT
AS
SET NOCOUNT ON
    SELECT TOP 30
            s.sre_id AS ID, s.sre_numero AS NUMERO, s.sre_fecha AS FECHA, s.sre_estado AS ESTADO,
            b.bod_nombre AS BODEGA, d.srd_cantidad AS CANTIDAD, d.srd_stock AS STOCK,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' ' + ISNULL(u.usu_apellido_paterno, ''))) AS USUARIO,
            ISNULL(s.sre_observacion, '') AS OBSERVACION
    FROM    [dbo].[Solicitud_Reposicion] s
    JOIN    [dbo].[Solicitud_Reposicion_Detalle] d ON d.srd_solicitud = s.sre_id
    JOIN    [dbo].[Bodega] b ON b.bod_id = s.sre_bodega
    LEFT JOIN [dbo].[Usuario] u ON u.usu_id = s.sre_usuario
    WHERE   s.sre_cliente = @CLIENTE AND d.srd_repuesto = @REPUESTO
    ORDER BY s.sre_numero DESC
GO
