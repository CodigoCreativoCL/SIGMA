/* ============================================================================
   SIGMA — Bloque 64
   DATOS DE PRUEBA DEL INVENTARIO  ·  Y LA ORDEN QUE NO SE VALIDABA
   ----------------------------------------------------------------------------

   Cierra las 7 tareas de "datos de prueba" del modulo del bodeguero
   (T-3061, T-3076, T-3091, T-3105, T-3133, T-3180, T-3274).

   La suite de 18 casos del bloque 61 se ejecuto dentro de transacciones
   REVERTIDAS: probo que las reglas funcionan y no dejo nada en la base. Las
   pantallas se abren vacias y Catalina no tiene contra que recorrerlas.

   QUE SE SIEMBRA, Y POR QUE ESTOS NUMEROS

     No son diez repuestos al azar. Estan elegidos para que las pantallas
     muestren TODOS los estados que hay que poder verificar:

       · uno BAJO EL MINIMO      -> la fila roja de HU-053 CA2 y HU-056 CA1
       · uno SOBRE EL MAXIMO     -> HU-053 CA3
       · uno que CONTROLA LOTE   -> HU-054 CA2
       · uno con existencia CERO -> el caso que no es alerta y se confunde
       · un traslado             -> dos bodegas, dos saldos
       · un ajuste con motivo    -> HU-057, y que se distinga en el listado

     Sembrar diez filas todas en verde deja una pantalla bonita donde no se
     puede probar nada.

   TODO LLEVA EL PREFIJO DEMO-
     Para que se pueda distinguir de lo que cargue el cliente, y borrar.

   IDEMPOTENTE
     Si ya se sembro, no hace nada. Correrlo dos veces no duplica saldos.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. LA ORDEN DE TRABAJO NO SE VALIDABA

      Aparecio preparando esto. En Movimiento.aspx la orden es un campo de
      texto libre: quien registra una entrega escribe un numero. Si ese
      numero no existe, lo unico que atajaba era la clave foranea
      FK_IMO_ORDEN_TRABAJO, y el mensaje que llega es

        "The INSERT statement conflicted with the FOREIGN KEY constraint..."

      Peor: una orden de OTRO cliente si existe, asi que la FK la deja pasar
      y el consumo se anota en la orden de otra empresa.

      Se valida en el SP, que es donde tiene que estar.
   ======================================================================== */
IF OBJECT_ID('dbo.INS_INVENTARIO_MOVIMIENTO') IS NOT NULL
BEGIN
    DECLARE @SQL NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.INS_INVENTARIO_MOVIMIENTO'))

    IF @SQL NOT LIKE '%14.- LA ORDEN DE TRABAJO%'
    BEGIN
        SET @SQL = REPLACE(@SQL,
            '/* ---- Saldo suficiente: HU-055 criterio 2 ----',
            '/* ---- La orden de trabajo, si viene, es de este cliente ----
   Sin esto lo unico que ataja un numero inventado es la clave foranea, y
   su mensaje no se le puede mostrar a nadie. Y una orden de otro cliente
   la FK la deja pasar: el consumo se anotaria en la orden de otra empresa. */
IF (@ORDEN_TRABAJO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo]
                     WHERE otr_id = @ORDEN_TRABAJO AND otr_cliente = @CLIENTE))
BEGIN
    RAISERROR(''14.- LA ORDEN DE TRABAJO NO EXISTE O NO ES DE ESTE CLIENTE.'', 16, 1)
    RETURN -1
END


/* ---- Saldo suficiente: HU-055 criterio 2 ----')

        SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')

        EXEC sp_executesql @SQL
        PRINT '--- INS_INVENTARIO_MOVIMIENTO: validacion de la orden de trabajo agregada'
    END
    ELSE
        PRINT '--- INS_INVENTARIO_MOVIMIENTO ya validaba la orden'
END
GO


/* ========================================================================
   2. LOS DATOS
   ======================================================================== */
IF EXISTS (SELECT 1 FROM [dbo].[Bodega] WHERE bod_codigo LIKE 'DEMO-%')
BEGIN
    PRINT '--- Los datos de prueba ya estaban sembrados. No se hace nada.'
    RETURN
END

DECLARE @CLI INT = 1          -- Hamburgo SA
DECLARE @CIN INT              -- Planta Santiago
DECLARE @U   INT = 1          -- root
DECLARE @UN  INT, @LT INT, @MT INT, @PAR INT
DECLARE @CLP INT = (SELECT mon_id FROM [dbo].[Moneda] WHERE mon_codigo = 'CLP')

SELECT TOP 1 @CIN = cin_id FROM [dbo].[Cliente_Instalacion]
 WHERE cin_cliente = @CLI AND ISNULL(cin_habilitado, 0) = 1 ORDER BY cin_id

IF (@CIN IS NULL)
BEGIN
    PRINT '--- No hay planta habilitada para el cliente 1. No se siembra nada.'
    RETURN
END

SELECT @UN  = ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'UNIDAD'
SELECT @LT  = ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'LITRO'
SELECT @MT  = ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'METRO'
SELECT @PAR = ume_id FROM [dbo].[Unidad_Medida] WHERE ume_codigo = N'PAR'


/* ---- 2.1 Dos bodegas ----
   Una central y un panol. El panol existe para que el traslado tenga a
   donde ir y para que se vea que el mismo repuesto en dos bodegas son dos
   existencias distintas. */
DECLARE @BOD INT, @PAN INT

EXEC [dbo].[INS_BODEGA] @ID = @BOD OUTPUT, @CLIENTE = @CLI, @INSTALACION = @CIN,
     @CODIGO = N'DEMO-BOD-CENTRAL', @NOMBRE = N'Bodega Central',
     @DESCRIPCION = N'Bodega principal de la planta, junto a recepción.', @USUARIO = @U

EXEC [dbo].[INS_BODEGA] @ID = @PAN OUTPUT, @CLIENTE = @CLI, @INSTALACION = @CIN,
     @CODIGO = N'DEMO-PANOL-ELEC', @NOMBRE = N'Pañol Sala Eléctrica',
     @DESCRIPCION = N'Pañol de electricidad, contiguo a la sala eléctrica.', @USUARIO = @U


/* ---- 2.2 Ubicaciones ----
   El codigo es la etiqueta que el bodeguero lee en el pasillo. */
DECLARE @U1 INT, @U2 INT, @U3 INT, @U4 INT, @U5 INT, @P1 INT, @P2 INT

EXEC [dbo].[INS_BODEGA_UBICACION] @ID=@U1 OUTPUT, @BODEGA=@BOD, @CLIENTE=@CLI,
     @CODIGO=N'PA-E1-N1', @NOMBRE=N'Pasillo A · Estante 1 · Nivel 1', @USUARIO=@U
EXEC [dbo].[INS_BODEGA_UBICACION] @ID=@U2 OUTPUT, @BODEGA=@BOD, @CLIENTE=@CLI,
     @CODIGO=N'PA-E1-N2', @NOMBRE=N'Pasillo A · Estante 1 · Nivel 2', @USUARIO=@U
EXEC [dbo].[INS_BODEGA_UBICACION] @ID=@U3 OUTPUT, @BODEGA=@BOD, @CLIENTE=@CLI,
     @CODIGO=N'PA-E3-N2', @NOMBRE=N'Pasillo A · Estante 3 · Nivel 2', @USUARIO=@U
EXEC [dbo].[INS_BODEGA_UBICACION] @ID=@U4 OUTPUT, @BODEGA=@BOD, @CLIENTE=@CLI,
     @CODIGO=N'PB-E2-N1', @NOMBRE=N'Pasillo B · Estante 2 · Nivel 1', @USUARIO=@U
EXEC [dbo].[INS_BODEGA_UBICACION] @ID=@U5 OUTPUT, @BODEGA=@BOD, @CLIENTE=@CLI,
     @CODIGO=N'ZONA-LIQ', @NOMBRE=N'Zona de líquidos, con contención', @USUARIO=@U

EXEC [dbo].[INS_BODEGA_UBICACION] @ID=@P1 OUTPUT, @BODEGA=@PAN, @CLIENTE=@CLI,
     @CODIGO=N'EST-A', @NOMBRE=N'Estante A · maniobra', @USUARIO=@U
EXEC [dbo].[INS_BODEGA_UBICACION] @ID=@P2 OUTPUT, @BODEGA=@PAN, @CLIENTE=@CLI,
     @CODIGO=N'EST-B', @NOMBRE=N'Estante B · protección', @USUARIO=@U


/* ---- 2.3 Diez repuestos ----
   Una planta de alimentos: blowers, transportadores y envasado. */
DECLARE @R1 INT, @R2 INT, @R3 INT, @R4 INT, @R5 INT,
        @R6 INT, @R7 INT, @R8 INT, @R9 INT, @R10 INT

EXEC [dbo].[INS_REPUESTO] @ID=@R1 OUTPUT, @CLIENTE=@CLI, @CODIGO=N'DEMO-ROD-6205',
     @NOMBRE=N'Rodamiento rígido de bolas 6205 2RS', @UNIDAD_MEDIDA=@UN,
     @FABRICANTE=N'SKF', @MODELO=N'6205-2RS1', @COSTO_REFERENCIA=8500, @MONEDA=@CLP,
     @VIDA_UTIL_HORA=8000, @USUARIO=@U

EXEC [dbo].[INS_REPUESTO] @ID=@R2 OUTPUT, @CLIENTE=@CLI, @CODIGO=N'DEMO-ROD-6308',
     @NOMBRE=N'Rodamiento rígido de bolas 6308 2Z', @UNIDAD_MEDIDA=@UN,
     @FABRICANTE=N'SKF', @MODELO=N'6308-2Z', @COSTO_REFERENCIA=23400, @MONEDA=@CLP,
     @VIDA_UTIL_HORA=12000, @USUARIO=@U

EXEC [dbo].[INS_REPUESTO] @ID=@R3 OUTPUT, @CLIENTE=@CLI, @CODIGO=N'DEMO-CORREA-A42',
     @NOMBRE=N'Correa trapecial A42', @UNIDAD_MEDIDA=@UN,
     @FABRICANTE=N'Optibelt', @MODELO=N'A42', @COSTO_REFERENCIA=6200, @MONEDA=@CLP,
     @VIDA_UTIL_HORA=4000, @USUARIO=@U

-- Controla lote: vence, y hay que poder rastrearlo (HU-054 CA2)
EXEC [dbo].[INS_REPUESTO] @ID=@R4 OUTPUT, @CLIENTE=@CLI, @CODIGO=N'DEMO-FILT-G4',
     @NOMBRE=N'Filtro de aire plisado G4 592x592x48', @UNIDAD_MEDIDA=@UN,
     @FABRICANTE=N'Camfil', @MODELO=N'30/30 G4', @COSTO_REFERENCIA=14900, @MONEDA=@CLP,
     @CONTROLA_LOTE=1, @VIDA_UTIL_DIA=180, @USUARIO=@U

EXEC [dbo].[INS_REPUESTO] @ID=@R5 OUTPUT, @CLIENTE=@CLI, @CODIGO=N'DEMO-ACEITE-68',
     @NOMBRE=N'Aceite hidráulico ISO VG 68', @UNIDAD_MEDIDA=@LT,
     @FABRICANTE=N'Shell', @MODELO=N'Tellus S2 MX 68', @COSTO_REFERENCIA=4800, @MONEDA=@CLP,
     @CONTROLA_LOTE=1, @ES_CONSUMIBLE=1, @VIDA_UTIL_HORA=2000, @VIDA_UTIL_DIA=365, @USUARIO=@U

EXEC [dbo].[INS_REPUESTO] @ID=@R6 OUTPUT, @CLIENTE=@CLI, @CODIGO=N'DEMO-SELLO-25',
     @NOMBRE=N'Sello mecánico 25 mm, cara de carburo', @UNIDAD_MEDIDA=@UN,
     @FABRICANTE=N'Burgmann', @MODELO=N'MG1-25', @COSTO_REFERENCIA=98000, @MONEDA=@CLP,
     @ES_REPARABLE=1, @VIDA_UTIL_HORA=6000, @USUARIO=@U

-- Vida util en CICLOS: al contactor no le importa el tiempo
EXEC [dbo].[INS_REPUESTO] @ID=@R7 OUTPUT, @CLIENTE=@CLI, @CODIGO=N'DEMO-CONT-LC1D18',
     @NOMBRE=N'Contactor tripolar 18 A, bobina 220 V', @UNIDAD_MEDIDA=@UN,
     @FABRICANTE=N'Schneider', @MODELO=N'LC1D18M7', @COSTO_REFERENCIA=41200, @MONEDA=@CLP,
     @VIDA_UTIL_CICLO=1000000, @USUARIO=@U

EXEC [dbo].[INS_REPUESTO] @ID=@R8 OUTPUT, @CLIENTE=@CLI, @CODIGO=N'DEMO-FUS-NH1-100',
     @NOMBRE=N'Fusible NH1 100 A gG', @UNIDAD_MEDIDA=@UN,
     @FABRICANTE=N'Siemens', @MODELO=N'3NA3830', @COSTO_REFERENCIA=7300, @MONEDA=@CLP,
     @ES_CONSUMIBLE=1, @USUARIO=@U

EXEC [dbo].[INS_REPUESTO] @ID=@R9 OUTPUT, @CLIENTE=@CLI, @CODIGO=N'DEMO-EMPAQ-SIL3',
     @NOMBRE=N'Empaquetadura siliconada 3 mm, grado alimentario', @UNIDAD_MEDIDA=@MT,
     @FABRICANTE=N'Klinger', @COSTO_REFERENCIA=11500, @MONEDA=@CLP,
     @ES_CONSUMIBLE=1, @USUARIO=@U

EXEC [dbo].[INS_REPUESTO] @ID=@R10 OUTPUT, @CLIENTE=@CLI, @CODIGO=N'DEMO-GUANTE-NIT-M',
     @NOMBRE=N'Guante de nitrilo talla M', @UNIDAD_MEDIDA=@PAR,
     @FABRICANTE=N'Ansell', @COSTO_REFERENCIA=2100, @MONEDA=@CLP,
     @ES_CONSUMIBLE=1, @USUARIO=@U


/* ---- 2.4 Umbrales ----
   Elegidos para que despues de los movimientos queden los tres estados:
   bajo el minimo, sobre el maximo y dentro. */
DECLARE @X INT

EXEC [dbo].[UPS_REPUESTO_BODEGA_STOCK] @ID=@X OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R1,
     @BODEGA=@BOD, @STOCK_MINIMO=4, @STOCK_MAXIMO=12, @PUNTO_REPOSICION=6,
     @OBSERVACION=N'Crítico: para el blower de la línea 1.', @USUARIO=@U

EXEC [dbo].[UPS_REPUESTO_BODEGA_STOCK] @ID=@X OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R2,
     @BODEGA=@BOD, @STOCK_MINIMO=2, @STOCK_MAXIMO=8, @USUARIO=@U

EXEC [dbo].[UPS_REPUESTO_BODEGA_STOCK] @ID=@X OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R3,
     @BODEGA=@BOD, @STOCK_MINIMO=2, @STOCK_MAXIMO=10, @USUARIO=@U

EXEC [dbo].[UPS_REPUESTO_BODEGA_STOCK] @ID=@X OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R4,
     @BODEGA=@BOD, @STOCK_MINIMO=8, @STOCK_MAXIMO=24, @USUARIO=@U

EXEC [dbo].[UPS_REPUESTO_BODEGA_STOCK] @ID=@X OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R5,
     @BODEGA=@BOD, @STOCK_MINIMO=100, @STOCK_MAXIMO=600, @PUNTO_REPOSICION=200, @USUARIO=@U

EXEC [dbo].[UPS_REPUESTO_BODEGA_STOCK] @ID=@X OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R7,
     @BODEGA=@PAN, @STOCK_MINIMO=2, @STOCK_MAXIMO=6, @USUARIO=@U

EXEC [dbo].[UPS_REPUESTO_BODEGA_STOCK] @ID=@X OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R8,
     @BODEGA=@PAN, @STOCK_MINIMO=6, @STOCK_MAXIMO=20, @USUARIO=@U

EXEC [dbo].[UPS_REPUESTO_BODEGA_STOCK] @ID=@X OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R10,
     @BODEGA=@BOD, @STOCK_MINIMO=20, @STOCK_MAXIMO=200, @USUARIO=@U


/* ---- 2.5 Lotes de lo que los controla ---- */
DECLARE @L_FILT INT, @L_ACE INT

EXEC [dbo].[INS_REPUESTO_LOTE] @ID=@L_FILT OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R4,
     @CODIGO=N'DEMO-L-FILT-2608', @FECHA_INGRESO='2026-08-12',
     @FECHA_VENCIMIENTO='2028-08-12', @USUARIO=@U

EXEC [dbo].[INS_REPUESTO_LOTE] @ID=@L_ACE OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R5,
     @CODIGO=N'DEMO-L-ACE-A4471', @FECHA_INGRESO='2026-08-05',
     @FECHA_VENCIMIENTO='2027-08-05', @USUARIO=@U


/* ---- 2.6 Los movimientos ----
   El orden importa: primero entra, despues sale. */
DECLARE @M INT

-- Ingresos
EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO] @ID=@M OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R1,
     @BODEGA=@BOD, @TIPO=1, @CANTIDAD=10, @UBICACION=@U1, @COSTO_UNITARIO=8500,
     @MONEDA=@CLP, @OBSERVACION=N'OC 4471, proveedor Rodasur.', @USUARIO=@U

EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO] @ID=@M OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R2,
     @BODEGA=@BOD, @TIPO=1, @CANTIDAD=5, @UBICACION=@U1, @COSTO_UNITARIO=23400,
     @MONEDA=@CLP, @OBSERVACION=N'OC 4471, proveedor Rodasur.', @USUARIO=@U

EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO] @ID=@M OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R3,
     @BODEGA=@BOD, @TIPO=1, @CANTIDAD=6, @UBICACION=@U2, @COSTO_UNITARIO=6200,
     @MONEDA=@CLP, @USUARIO=@U

-- Sobre el maximo a proposito: 30 con maximo 24 (HU-053 CA3)
EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO] @ID=@M OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R4,
     @BODEGA=@BOD, @TIPO=1, @CANTIDAD=30, @UBICACION=@U2, @LOTE=@L_FILT,
     @COSTO_UNITARIO=14900, @MONEDA=@CLP,
     @OBSERVACION=N'Compra anual de filtros. Quedó sobre el máximo.', @USUARIO=@U

EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO] @ID=@M OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R5,
     @BODEGA=@BOD, @TIPO=1, @CANTIDAD=400, @UBICACION=@U5, @LOTE=@L_ACE,
     @COSTO_UNITARIO=4800, @MONEDA=@CLP, @OBSERVACION=N'Dos tambores de 200 L.', @USUARIO=@U

EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO] @ID=@M OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R6,
     @BODEGA=@BOD, @TIPO=1, @CANTIDAD=2, @UBICACION=@U3, @COSTO_UNITARIO=98000,
     @MONEDA=@CLP, @USUARIO=@U

-- Bajo el minimo a proposito: 1 con minimo 2 (HU-053 CA2)
EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO] @ID=@M OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R7,
     @BODEGA=@PAN, @TIPO=1, @CANTIDAD=1, @UBICACION=@P1, @COSTO_UNITARIO=41200,
     @MONEDA=@CLP, @USUARIO=@U

EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO] @ID=@M OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R8,
     @BODEGA=@PAN, @TIPO=1, @CANTIDAD=12, @UBICACION=@P2, @COSTO_UNITARIO=7300,
     @MONEDA=@CLP, @USUARIO=@U

EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO] @ID=@M OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R10,
     @BODEGA=@BOD, @TIPO=1, @CANTIDAD=50, @UBICACION=@U4, @COSTO_UNITARIO=2100,
     @MONEDA=@CLP, @USUARIO=@U

/* Entregas SIN orden de trabajo: el modulo de OT es del Sprint 5 y todavia
   no hay ninguna. El SP acepta NULL; lo que no acepta -desde este bloque-
   es un numero inventado. */
EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO] @ID=@M OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R1,
     @BODEGA=@BOD, @TIPO=2, @CANTIDAD=8, @COSTO_UNITARIO=8500, @MONEDA=@CLP,
     @OBSERVACION=N'Cambio de rodamientos del blower B-101. Queda bajo el mínimo.', @USUARIO=@U

EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO] @ID=@M OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R5,
     @BODEGA=@BOD, @TIPO=2, @CANTIDAD=60, @LOTE=@L_ACE, @COSTO_UNITARIO=4800,
     @MONEDA=@CLP, @OBSERVACION=N'Recambio de aceite de la unidad hidráulica.', @USUARIO=@U

-- Una devolucion: sobro material
EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO] @ID=@M OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R1,
     @BODEGA=@BOD, @TIPO=3, @CANTIDAD=1, @COSTO_UNITARIO=8500, @MONEDA=@CLP,
     @OBSERVACION=N'Sobró uno del cambio del B-101.', @USUARIO=@U

-- Ajuste con motivo (HU-057 CA1)
EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO] @ID=@M OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R10,
     @BODEGA=@BOD, @TIPO=5, @CANTIDAD=5, @UBICACION=@U4,
     @OBSERVACION=N'Conteo físico del 28-08: faltaban 5 pares respecto del sistema.',
     @USUARIO=@U

-- Traslado entre bodegas
EXEC [dbo].[INS_INVENTARIO_MOVIMIENTO] @ID=@M OUTPUT, @CLIENTE=@CLI, @REPUESTO=@R8,
     @BODEGA=@PAN, @TIPO=6, @CANTIDAD=4, @BODEGA_DESTINO=@BOD,
     @OBSERVACION=N'Se dejan 4 fusibles en la central para el turno de noche.', @USUARIO=@U

PRINT '--- Datos de prueba del inventario sembrados.'
GO


/* ========================================================================
   3. VERIFICACION — lo que Catalina va a ver
   ======================================================================== */
PRINT '--- Existencias, con su estado ---'
SELECT  r.rep_codigo, r.rep_nombre, b.bod_nombre AS bodega,
        s.isa_cantidad, st.rbs_stock_minimo AS minimo, st.rbs_stock_maximo AS maximo,
        CASE WHEN st.rbs_stock_minimo IS NOT NULL AND s.isa_cantidad < st.rbs_stock_minimo
                  THEN 'BAJO EL MINIMO'
             WHEN st.rbs_stock_maximo IS NOT NULL AND s.isa_cantidad > st.rbs_stock_maximo
                  THEN 'SOBRE EL MAXIMO'
             WHEN st.rbs_id IS NULL THEN 'sin umbrales'
             ELSE 'dentro' END AS estado
FROM    [dbo].[Inventario_Saldo] s
JOIN    [dbo].[Repuesto] r ON r.rep_id = s.isa_repuesto
JOIN    [dbo].[Bodega]   b ON b.bod_id = s.isa_bodega
LEFT JOIN [dbo].[Repuesto_Bodega_Stock] st
       ON st.rbs_repuesto = s.isa_repuesto AND st.rbs_bodega = s.isa_bodega AND st.rbs_habilitado = 1
ORDER BY r.rep_codigo, b.bod_codigo

PRINT '--- El saldo cuadra con la suma de sus movimientos? ---'
SELECT  COUNT(*) AS combinaciones,
        SUM(CASE WHEN s.isa_cantidad = m.total THEN 1 ELSE 0 END) AS cuadran
FROM    [dbo].[Inventario_Saldo] s
CROSS APPLY (SELECT SUM(CASE WHEN imo_inventario_movimiento_tipo IN (1,3,4,7)
                             THEN imo_cantidad ELSE -imo_cantidad END) AS total
               FROM [dbo].[Inventario_Movimiento]
              WHERE imo_repuesto = s.isa_repuesto AND imo_bodega = s.isa_bodega) m

PRINT '--- Movimientos por familia ---'
SELECT  CASE WHEN t.imt_id IN (4,5,8) THEN 'AJUSTE'
             WHEN t.imt_id IN (6,7)   THEN 'TRASLADO'
             WHEN t.imt_id = 2        THEN 'CONSUMO'
             ELSE 'INGRESO' END AS familia, COUNT(*) AS movimientos
FROM    [dbo].[Inventario_Movimiento] m
JOIN    [dbo].[Inventario_Movimiento_Tipo] t ON t.imt_id = m.imo_inventario_movimiento_tipo
GROUP BY CASE WHEN t.imt_id IN (4,5,8) THEN 'AJUSTE'
              WHEN t.imt_id IN (6,7)   THEN 'TRASLADO'
              WHEN t.imt_id = 2        THEN 'CONSUMO'
              ELSE 'INGRESO' END
GO
