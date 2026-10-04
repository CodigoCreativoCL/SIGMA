/* ============================================================================
   SIGMA - Bloque 332
   LA FICHA DE BODEGA ALINEADA CON EL MAPA 3D
   ----------------------------------------------------------------------------

   El mapa 3D arma la bodega leyendo el codigo de cada rack (P1-A-R01 =
   pasillo A, rack 01) y le agrego metodo de salida, carga por nivel, plano y
   conteo ciclico (bloques 326 a 329). La ficha de bodega del menu
   (Inventario > Bodegas) seguia creando ubicaciones UBI-<id> y no mostraba
   nada de eso. Estas dos lecturas le dan lo que necesita; las escrituras
   siguen por los SP de siempre (INS/UPD_BODEGA_UBICACION,
   UPD_BODEGA_METODO_SALIDA, UPD_UBICACION_CARGA).

     SEL_BODEGA_RESUMEN_MAPA      por bodega: metodo, racks, racks movidos
                                  en el plano y racks contados en 30 dias.
     SEL_BODEGA_UBICACIONES_MAPA  por rack de una bodega: carga por nivel, si
                                  se movio en el plano, que guarda y cuando se
                                  conto por ultima vez.
   ============================================================================ */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_RESUMEN_MAPA]
    @CLIENTE INT,
    @BODEGA  INT = NULL
AS
SET NOCOUNT ON
DECLARE @HACE30 DATETIME = DATEADD(DAY, -30, [dbo].[FNC_AHORA]())

    SELECT  b.bod_id AS BOD_ID,
            ISNULL(b.bod_metodo_salida, 'FEFO') AS METODO,
            (SELECT COUNT(*) FROM [dbo].[Bodega_Ubicacion] u
              WHERE u.bub_bodega = b.bod_id AND u.bub_habilitado = 1) AS RACKS,
            (SELECT COUNT(*) FROM [dbo].[Bodega_Plano_Rack] p
              JOIN [dbo].[Bodega_Ubicacion] u ON u.bub_id = p.bpr_ubicacion
              WHERE u.bub_bodega = b.bod_id AND u.bub_habilitado = 1) AS MOVIDOS,
            (SELECT COUNT(DISTINCT d.icd_bodega_ubicacion) FROM [dbo].[Inventario_Conteo_Detalle] d
              JOIN [dbo].[Bodega_Ubicacion] u ON u.bub_id = d.icd_bodega_ubicacion
              WHERE u.bub_bodega = b.bod_id AND d.icd_fecha >= @HACE30) AS CONTADOS_30
    FROM    [dbo].[Bodega] b
    WHERE   b.bod_cliente = @CLIENTE
      AND   (@BODEGA IS NULL OR b.bod_id = @BODEGA)
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_UBICACIONES_MAPA]
    @CLIENTE INT,
    @BODEGA  INT
AS
SET NOCOUNT ON

;WITH saldo AS (
    SELECT  s.isa_bodega_ubicacion AS ubi, COUNT(DISTINCT s.isa_repuesto) AS repuestos, SUM(s.isa_cantidad) AS cantidad
    FROM    [dbo].[Inventario_Saldo] s
    WHERE   s.isa_cliente = @CLIENTE AND s.isa_bodega = @BODEGA AND s.isa_cantidad > 0
    GROUP BY s.isa_bodega_ubicacion
), conteo AS (
    SELECT  d.icd_bodega_ubicacion AS ubi, MAX(d.icd_fecha) AS fecha
    FROM    [dbo].[Inventario_Conteo_Detalle] d
    JOIN    [dbo].[Inventario_Conteo] c ON c.ico_id = d.icd_conteo
    WHERE   c.ico_cliente = @CLIENTE AND c.ico_bodega = @BODEGA
    GROUP BY d.icd_bodega_ubicacion
)
    SELECT  u.bub_id AS BUB_ID, u.bub_codigo AS CODIGO, u.bub_nombre AS NOMBRE,
            u.bub_carga_nivel_kg AS CARGA,
            CAST(CASE WHEN p.bpr_ubicacion IS NULL THEN 0 ELSE 1 END AS BIT) AS MOVIDO,
            ISNULL(s.repuestos, 0) AS REPUESTOS, ISNULL(s.cantidad, 0) AS CANTIDAD,
            k.fecha AS CONTEO_FECHA
    FROM    [dbo].[Bodega_Ubicacion] u
    JOIN    [dbo].[Bodega] b ON b.bod_id = u.bub_bodega AND b.bod_cliente = @CLIENTE
    LEFT JOIN [dbo].[Bodega_Plano_Rack] p ON p.bpr_ubicacion = u.bub_id
    LEFT JOIN saldo s ON s.ubi = u.bub_id
    LEFT JOIN conteo k ON k.ubi = u.bub_id
    WHERE   u.bub_bodega = @BODEGA AND u.bub_habilitado = 1
    ORDER BY u.bub_codigo
GO
