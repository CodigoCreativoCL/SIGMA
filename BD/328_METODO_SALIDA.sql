/* ============================================================================
   SIGMA - Bloque 328
   METODO DE SALIDA CONFIGURABLE: FEFO, FIFO o LIFO
   ----------------------------------------------------------------------------

   De que caja y de que lote se saca primero ya no esta fijo en FEFO: se
   configura por BODEGA, y un repuesto puede tener su propia excepcion (un
   aceite que se rige por vencimiento dentro de una bodega que trabaja FIFO).

     FEFO  primero el lote que vence antes. Lo sin vencimiento va al final y,
           entre ellos, por fecha de ingreso (FIFO). Es el valor por defecto:
           era lo que hacia SEL_INVENTARIO_ORIGEN hasta hoy.
     FIFO  primero lo que entro antes.
     LIFO  primero lo que entro ultimo.

   EL METODO SE APLICA DONDE SE DECIDE DE DONDE SACAR
     SEL_INVENTARIO_ORIGEN devuelve los origenes (ubicacion + lote con saldo)
     ya ordenados segun el metodo. Lo usan Movimiento.aspx para el combo
     "Sale de", el mapa 3D para el picking y el conteo ciclico para descontar
     un faltante. Asi el orden es uno solo, el de la base, y no hay una regla en
     cada pantalla que con el tiempo diga cosas distintas.

   QUE ES "LA FECHA DE INGRESO" DE UN SALDO
     Con lote: la fecha de ingreso del lote (rlo_fecha_ingreso).
     Sin lote: la fecha del ULTIMO ingreso a esa caja (compra, devolucion,
     ajuste positivo, traslado o reubicacion que la tiene como destino). Un
     saldo sin lote no guarda la edad de cada unidad; la caja que hace mas tiempo
     no se repone es la que tiene el stock mas viejo, y ese es el criterio.

     FNC_METODO_SALIDA            el metodo que rige para un repuesto en una bodega.
     UPD_BODEGA_METODO_SALIDA     cambia el de una bodega.
     UPD_REPUESTO_METODO_SALIDA   pone o quita la excepcion de un repuesto.
     SEL_REPUESTO_METODO_SALIDA   la excepcion de un repuesto (para su ficha).
     SEL_INVENTARIO_ORIGEN        ordena por el metodo y lo devuelve.
     SEL_BODEGA_MAPA_ESTRUCTURA   devuelve el metodo de cada bodega.
     SEL_BODEGA_MAPA_SALDOS       devuelve metodo, ingreso y vencimiento por caja.
   ============================================================================ */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. Columnas
   ======================================================================== */
IF COL_LENGTH('dbo.Bodega', 'bod_metodo_salida') IS NULL
    ALTER TABLE [dbo].[Bodega] ADD bod_metodo_salida VARCHAR(4) NOT NULL
        CONSTRAINT DF_BOD_METODO_SALIDA DEFAULT ('FEFO')
        CONSTRAINT CK_BOD_METODO_SALIDA CHECK (bod_metodo_salida IN ('FEFO', 'FIFO', 'LIFO'))
GO

IF COL_LENGTH('dbo.Repuesto', 'rep_metodo_salida') IS NULL
    ALTER TABLE [dbo].[Repuesto] ADD rep_metodo_salida VARCHAR(4) NULL
        CONSTRAINT CK_REP_METODO_SALIDA CHECK (rep_metodo_salida IS NULL OR rep_metodo_salida IN ('FEFO', 'FIFO', 'LIFO'))
GO


/* ========================================================================
   2. El metodo que rige
   ======================================================================== */
CREATE OR ALTER FUNCTION [dbo].[FNC_METODO_SALIDA] (@REPUESTO INT, @BODEGA INT)
RETURNS VARCHAR(4)
AS
BEGIN
    RETURN ISNULL((SELECT rep_metodo_salida FROM [dbo].[Repuesto] WHERE rep_id = @REPUESTO),
           ISNULL((SELECT bod_metodo_salida FROM [dbo].[Bodega] WHERE bod_id = @BODEGA), 'FEFO'))
END
GO

/* La fecha de ingreso de un saldo (ver encabezado). */
CREATE OR ALTER FUNCTION [dbo].[FNC_SALDO_FECHA_INGRESO] (@REPUESTO INT, @BODEGA INT, @UBICACION INT, @LOTE INT)
RETURNS DATETIME
AS
BEGIN
    DECLARE @F DATETIME

    IF (@LOTE IS NOT NULL)
        SELECT @F = rlo_fecha_ingreso FROM [dbo].[Repuesto_Lote] WHERE rlo_id = @LOTE

    IF (@F IS NULL)
        SELECT @F = MAX(m.imo_fecha_movimiento_utc)
        FROM   [dbo].[Inventario_Movimiento] m
        WHERE  m.imo_repuesto = @REPUESTO
          AND  ISNULL(m.imo_repuesto_lote, 0) = ISNULL(@LOTE, 0)
          AND  (   (m.imo_inventario_movimiento_tipo IN (1, 3, 4, 7)
                    AND m.imo_bodega = @BODEGA
                    AND ISNULL(m.imo_bodega_ubicacion, 0) = ISNULL(@UBICACION, 0))
                OR (m.imo_inventario_movimiento_tipo = 9
                    AND m.imo_bodega = @BODEGA
                    AND m.imo_bodega_ubicacion_destino = @UBICACION)
                OR (m.imo_inventario_movimiento_tipo = 6
                    AND m.imo_bodega_destino = @BODEGA
                    AND ISNULL(m.imo_bodega_ubicacion_destino, 0) = ISNULL(@UBICACION, 0)))

    RETURN @F
END
GO


/* ========================================================================
   3. Configurarlo
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPD_BODEGA_METODO_SALIDA]
    @CLIENTE  INT,
    @BODEGA   INT,
    @METODO   VARCHAR(4),
    @USUARIO  INT
AS
SET NOCOUNT ON

SET @METODO = UPPER(LTRIM(RTRIM(ISNULL(@METODO, ''))))
IF (@METODO NOT IN ('FEFO', 'FIFO', 'LIFO'))
BEGIN
    RAISERROR('1.- EL METODO DE SALIDA DEBE SER FEFO, FIFO O LIFO.', 16, 1)
    RETURN -1
END

UPDATE [dbo].[Bodega]
SET    bod_metodo_salida = @METODO, bod_usuario_actualizacion = @USUARIO, bod_fecha_actualizacion = [dbo].[FNC_AHORA]()
WHERE  bod_id = @BODEGA AND bod_cliente = @CLIENTE

IF (@@ROWCOUNT = 0)
BEGIN
    RAISERROR('2.- LA BODEGA NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @BODEGA [ID], '200' [CODE], 'Método de salida actualizado.' [MENSAJE]
RETURN 0
GO

/* @METODO NULL (o vacio) quita la excepcion: el repuesto vuelve a seguir el
   metodo de cada bodega. */
CREATE OR ALTER PROCEDURE [dbo].[UPD_REPUESTO_METODO_SALIDA]
    @CLIENTE  INT,
    @REPUESTO INT,
    @METODO   VARCHAR(4) = NULL,
    @USUARIO  INT
AS
SET NOCOUNT ON

SET @METODO = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@METODO, '')))), '')
IF (@METODO IS NOT NULL AND @METODO NOT IN ('FEFO', 'FIFO', 'LIFO'))
BEGIN
    RAISERROR('1.- EL METODO DE SALIDA DEBE SER FEFO, FIFO O LIFO.', 16, 1)
    RETURN -1
END

UPDATE [dbo].[Repuesto]
SET    rep_metodo_salida = @METODO
WHERE  rep_id = @REPUESTO AND rep_cliente = @CLIENTE

IF (@@ROWCOUNT = 0)
BEGIN
    RAISERROR('2.- EL REPUESTO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @REPUESTO [ID], '200' [CODE], 'Método de salida actualizado.' [MENSAJE]
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO_METODO_SALIDA]
    @CLIENTE  INT,
    @REPUESTO INT
AS
SET NOCOUNT ON
    SELECT rep_metodo_salida AS METODO FROM [dbo].[Repuesto] WHERE rep_id = @REPUESTO AND rep_cliente = @CLIENTE
GO


/* ========================================================================
   4. De donde sacar, en el orden del metodo
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_INVENTARIO_ORIGEN]
    @CLIENTE         INT,
    @REPUESTO        INT,
    @BODEGA          INT,
    @SOLO_CON_SALDO  BIT = 1
AS
SET NOCOUNT ON

DECLARE @METODO VARCHAR(4) = [dbo].[FNC_METODO_SALIDA](@REPUESTO, @BODEGA)

    SELECT  s.isa_bodega_ubicacion                              AS UBICACION_ID,
            ISNULL(ub.bub_codigo, '')                           AS UBICACION_CODIGO,
            ISNULL(ub.bub_nombre, '')                           AS UBICACION_NOMBRE,
            s.isa_repuesto_lote                                 AS LOTE_ID,
            ISNULL(lo.rlo_codigo, '')                           AS LOTE_CODIGO,
            lo.rlo_fecha_vencimiento                            AS LOTE_VENCE,
            CAST(CASE WHEN lo.rlo_fecha_vencimiento IS NOT NULL
                       AND lo.rlo_fecha_vencimiento < CAST([dbo].[FNC_AHORA]() AS DATE)
                      THEN 1 ELSE 0 END AS BIT)                 AS LOTE_VENCIDO,
            s.isa_cantidad                                      AS CANTIDAD,
            ISNULL(ume.ume_simbolo, '')                         AS UNIDAD,
            @METODO                                             AS METODO,
            x.INGRESO                                           AS FECHA_INGRESO
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Repuesto] r
            ON  r.rep_id = s.isa_repuesto
    LEFT JOIN [dbo].[Unidad_Medida] ume
            ON  ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Bodega_Ubicacion] ub
            ON  ub.bub_id = s.isa_bodega_ubicacion
    LEFT JOIN [dbo].[Repuesto_Lote] lo
            ON  lo.rlo_id = s.isa_repuesto_lote
    CROSS APPLY (SELECT [dbo].[FNC_SALDO_FECHA_INGRESO](s.isa_repuesto, s.isa_bodega, s.isa_bodega_ubicacion, s.isa_repuesto_lote) AS INGRESO) x
    WHERE   s.isa_cliente  = @CLIENTE
      AND   s.isa_repuesto = @REPUESTO
      AND   s.isa_bodega   = @BODEGA
      AND   (@SOLO_CON_SALDO = 0 OR s.isa_cantidad > 0)
    ORDER BY CASE WHEN @METODO = 'FEFO' AND lo.rlo_fecha_vencimiento IS NULL THEN 1 ELSE 0 END,
             CASE WHEN @METODO = 'FEFO' THEN lo.rlo_fecha_vencimiento END,
             CASE WHEN @METODO = 'LIFO' THEN x.INGRESO END DESC,
             CASE WHEN @METODO <> 'LIFO' THEN x.INGRESO END,
             ub.bub_codigo,
             s.isa_repuesto_lote
GO


/* ========================================================================
   5. El mapa 3D: el metodo de cada bodega y las fechas de cada caja
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
            b.bod_metodo_salida              AS BOD_METODO_SALIDA,
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

/* Una caja del mapa junta los lotes de un repuesto en una ubicacion: se
   devuelve el ingreso mas viejo y el mas nuevo (FIFO compara el primero, LIFO
   el segundo) y el vencimiento mas proximo (FEFO). */
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
            MAX(rbs.rbs_punto_reposicion)                AS PUNTO_REPOSICION,
            ISNULL(r.rep_metodo_salida, b.bod_metodo_salida) AS METODO,
            MIN(x.INGRESO)                               AS INGRESO_MIN,
            MAX(x.INGRESO)                               AS INGRESO_MAX,
            MIN(lo.rlo_fecha_vencimiento)                AS VENCE_MIN
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Bodega] b              ON b.bod_id  = s.isa_bodega
    JOIN    [dbo].[Repuesto] r            ON r.rep_id  = s.isa_repuesto
    JOIN    [dbo].[Unidad_Medida] ume     ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Repuesto_Tipo] t     ON t.rti_id  = r.rep_repuesto_tipo
    LEFT JOIN [dbo].[Repuesto_Lote] lo    ON lo.rlo_id = s.isa_repuesto_lote
    LEFT JOIN [dbo].[Repuesto_Bodega_Stock] rbs
                                          ON rbs.rbs_repuesto = s.isa_repuesto
                                         AND rbs.rbs_bodega   = s.isa_bodega
                                         AND ISNULL(rbs.rbs_habilitado, 0) = 1
    CROSS APPLY (SELECT [dbo].[FNC_SALDO_FECHA_INGRESO](s.isa_repuesto, s.isa_bodega, s.isa_bodega_ubicacion, s.isa_repuesto_lote) AS INGRESO) x
    WHERE   s.isa_cliente = @CLIENTE
      AND   s.isa_cantidad > 0
      AND   ISNULL(b.bod_habilitado, 0) = 1
      AND   (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
    GROUP BY s.isa_bodega, s.isa_bodega_ubicacion, r.rep_id, r.rep_codigo, r.rep_nombre,
             r.rep_fabricante, r.rep_modelo, t.rti_id, t.rti_codigo, t.rti_nombre,
             ume.ume_simbolo, ume.ume_codigo, r.rep_metodo_salida, b.bod_metodo_salida
    ORDER BY s.isa_bodega, s.isa_bodega_ubicacion, t.rti_codigo, r.rep_codigo
GO
