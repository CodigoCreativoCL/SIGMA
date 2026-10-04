/* ============================================================================
   SIGMA - Bloque 325
   MAPA 3D DE BODEGAS
   ----------------------------------------------------------------------------

   El mapa 3D se dibuja SOLO con lo que hay en la base: las bodegas de la
   planta, sus ubicaciones y el stock que hay en cada una. No hay un plano
   cargado a mano que se desactualice: si alguien crea una ubicacion o registra
   un ingreso, el mapa la muestra en la siguiente carga.

   Dos lecturas, separadas porque cambian a ritmos distintos -la estructura casi
   nunca, el stock todo el dia- y porque el visor pide la segunda de nuevo al
   refrescar sin rearmar la escena:

     SEL_BODEGA_MAPA_ESTRUCTURA  bodegas y ubicaciones de una planta (o todas).
                                 LEFT JOIN: una bodega sin ubicaciones tambien
                                 se dibuja, vacia, para que se note que falta.
     SEL_BODEGA_MAPA_SALDOS      stock por bodega, ubicacion y repuesto, con su
                                 tipo, su unidad y sus umbrales. El stock sin
                                 ubicacion (isa_bodega_ubicacion NULL) tambien
                                 viene: el visor lo muestra en una zona de
                                 recepcion, porque esconderlo seria mentir sobre
                                 lo que hay en la bodega.

   Y la entrada de menu, con el permiso VER BODEGAS.
   ============================================================================ */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. Estructura
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_MAPA_ESTRUCTURA]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON

    SELECT  b.bod_id                         AS BOD_ID,
            b.bod_codigo                     AS BOD_CODIGO,
            b.bod_nombre                     AS BOD_NOMBRE,
            ISNULL(b.bod_descripcion, '')    AS BOD_DESCRIPCION,
            ci.cin_id                        AS CIN_ID,
            ci.cin_nombre                    AS CIN_NOMBRE,
            u.bub_id                         AS BUB_ID,
            u.bub_codigo                     AS BUB_CODIGO,
            u.bub_nombre                     AS BUB_NOMBRE
    FROM    [dbo].[Bodega] b
    JOIN    [dbo].[Cliente_Instalacion] ci ON ci.cin_id = b.bod_cliente_instalacion
    LEFT JOIN [dbo].[Bodega_Ubicacion] u   ON u.bub_bodega = b.bod_id
                                          AND ISNULL(u.bub_habilitado, 0) = 1
    WHERE   b.bod_cliente = @CLIENTE
      AND   ISNULL(b.bod_habilitado, 0) = 1
      AND   (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
    ORDER BY ci.cin_nombre, b.bod_codigo, u.bub_codigo
GO


/* ========================================================================
   2. Stock por ubicacion

      Se agrupa por bodega + ubicacion + repuesto: varios lotes del mismo
      repuesto en el mismo rack son UNA caja en el mapa, con la cantidad
      sumada y cuantos lotes la componen.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_MAPA_SALDOS]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON

    SELECT  s.isa_bodega                                 AS BOD_ID,
            s.isa_bodega_ubicacion                       AS BUB_ID,
            r.rep_id                                     AS REP_ID,
            r.rep_codigo                                 AS REP_CODIGO,
            r.rep_nombre                                 AS REP_NOMBRE,
            ISNULL(r.rep_fabricante, '')                 AS REP_FABRICANTE,
            ISNULL(r.rep_modelo, '')                     AS REP_MODELO,
            ISNULL(t.rti_id, 0)                          AS RTI_ID,
            ISNULL(t.rti_codigo, '')                     AS RTI_CODIGO,
            ISNULL(t.rti_nombre, 'Sin tipo')             AS RTI_NOMBRE,
            ISNULL(ume.ume_simbolo, ume.ume_codigo)      AS UNIDAD,
            SUM(s.isa_cantidad)                          AS CANTIDAD,
            SUM(ISNULL(s.isa_cantidad_reservada, 0))     AS RESERVADA,
            COUNT(DISTINCT s.isa_repuesto_lote)          AS LOTES,
            MAX(s.isa_fecha_ultimo_movimiento)           AS ULTIMO_MOVIMIENTO,
            MAX(rbs.rbs_stock_minimo)                    AS STOCK_MINIMO,
            MAX(rbs.rbs_stock_maximo)                    AS STOCK_MAXIMO,
            MAX(rbs.rbs_punto_reposicion)                AS PUNTO_REPOSICION
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Bodega] b              ON b.bod_id  = s.isa_bodega
    JOIN    [dbo].[Repuesto] r            ON r.rep_id  = s.isa_repuesto
    JOIN    [dbo].[Unidad_Medida] ume     ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Repuesto_Tipo] t     ON t.rti_id  = r.rep_repuesto_tipo
    LEFT JOIN [dbo].[Repuesto_Bodega_Stock] rbs
                                          ON rbs.rbs_repuesto = s.isa_repuesto
                                         AND rbs.rbs_bodega   = s.isa_bodega
                                         AND ISNULL(rbs.rbs_habilitado, 0) = 1
    WHERE   s.isa_cliente = @CLIENTE
      AND   s.isa_cantidad > 0
      AND   ISNULL(b.bod_habilitado, 0) = 1
      AND   (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
    GROUP BY s.isa_bodega, s.isa_bodega_ubicacion, r.rep_id, r.rep_codigo, r.rep_nombre,
             r.rep_fabricante, r.rep_modelo, t.rti_id, t.rti_codigo, t.rti_nombre,
             ume.ume_simbolo, ume.ume_codigo
    ORDER BY s.isa_bodega, s.isa_bodega_ubicacion, t.rti_codigo, r.rep_codigo
GO


/* ========================================================================
   3. La entrada de menu

      Inventario > Mapa 3D de bodegas, despues del Centro de repuestos.
      Exige VER BODEGAS: quien ve las bodegas puede ver donde esta cada cosa.
      Idempotente: si ya existe, solo se reacomoda.
   ======================================================================== */
DECLARE @INVENTARIO INT, @PERM INT, @MENU INT

SELECT @INVENTARIO = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre = N'Inventario' AND mnu_nivel = 2
SELECT @PERM       = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER BODEGAS'
SELECT @MENU       = mnu_id FROM [dbo].[Menus] WHERE mnu_link = N'~/View/Inventario/Bodegas/BodegaMapa3D.aspx'

IF @INVENTARIO IS NULL OR @PERM IS NULL
    RAISERROR('No se encontro el menu Inventario o el permiso VER BODEGAS.', 16, 1)
ELSE IF @MENU IS NULL
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES
        (N'Mapa 3D de bodegas', N'Recorrido en 3D de las bodegas de la planta, con su stock por ubicacion',
         3, @INVENTARIO, 4, N'~/View/Inventario/Bodegas/BodegaMapa3D.aspx',
         1, N'mdi mdi-warehouse', @PERM, 1)
ELSE
    UPDATE [dbo].[Menus]
    SET    mnu_padre = @INVENTARIO, mnu_nivel = 3, mnu_orden = 4, mnu_visible = 1,
           mnu_permiso = @PERM, mnu_icon = N'mdi mdi-warehouse'
    WHERE  mnu_id = @MENU
GO


/* ============================================================================
   COMPROBACION
   ============================================================================ */
SELECT m.mnu_orden AS orden, m.mnu_nombre AS pantalla, m.mnu_link AS link, p.prm_codigo AS permiso
FROM   [dbo].[Menus] m
LEFT JOIN [dbo].[Permiso] p ON p.prm_id = m.mnu_permiso
WHERE  m.mnu_padre = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_nombre = N'Inventario' AND mnu_nivel = 2)
  AND  m.mnu_visible = 1
ORDER BY m.mnu_orden
GO
