/* ============================================================================
   SIGMA - Bloque 329
   MAPA 3D DE BODEGAS: POSICIONES, DIMENSIONES, ANALISIS, REPOSICION, PLANO,
   HISTORIAL Y TRABAJO EN EQUIPO
   ----------------------------------------------------------------------------

   1. POSICIONES REALES (planograma)
        Bodega_Ubicacion_Posicion fija en que nivel y posicion de un rack va
        cada repuesto ("P1-A-R03 · 2-04"). Hasta ahora la posicion la calculaba
        el visor y cambiaba si cambiaba el stock; ahora es un registro.
        LO QUE NO CAMBIA: el stock sigue por UBICACION (Inventario_Saldo). La
        posicion es el plan de donde va cada cosa dentro del rack, no un nivel
        mas del kardex: llevarla al saldo obligaria a que cada movimiento
        -web, app, carga masiva- la indique, y eso es otro alcance.

   2. DIMENSIONES Y PESO
        Largo, ancho y alto (cm) y peso (kg) por repuesto, y la carga admisible
        por nivel de cada rack. El mapa dibuja la caja de su tamano y avisa
        cuando un nivel supera su carga.

   3. CONSUMO (rotacion ABC y proyeccion de quiebre)
        SEL_BODEGA_MAPA_ROTACION: salidas por consumo y merma de los ultimos N
        dias por caja. El visor clasifica ABC por frecuencia de retiro, sugiere
        acercar a la entrada lo de alta rotacion y proyecta cuando se agota cada
        repuesto. Solo lectura: no hay nada que mantener al dia.

   4. COMPATIBLES CON UN EQUIPO
        Los repuestos que Repuesto_Compatibilidad declara para un activo (por
        modelo, por tipo o por componente), con la misma regla que usa
        INS_INVENTARIO_MOVIMIENTO al consumir contra una orden.

   5. SOLICITUD DE REPOSICION
        Desde las alertas de bajo minimo se arma una solicitud (lo que falta
        hasta el maximo o el punto de reposicion), con numero correlativo por
        cliente y estado PENDIENTE / ENVIADA / RECIBIDA / ANULADA. Es la
        constancia de lo pedido; la compra en si no es de este sistema.

   6. PLANO EDITABLE
        Bodega_Plano_Rack guarda la posicion y el giro de un rack que se movio
        en el mapa (si no tiene fila, se ubica por su codigo como siempre), y
        Bodega_Zona las zonas del piso: recepcion, cuarentena, despacho, muelle.

   7. HISTORIAL
        El stock de la planta al cierre de un dia, reconstruido desde el saldo
        de hoy menos los movimientos posteriores, y los movimientos de un rango
        de dias para reproducirlos en el mapa.

   8. TRABAJO EN EQUIPO
        SEL_BODEGA_MAPA_VERSION: el ultimo movimiento y una huella de la
        estructura. El visor la consulta cada pocos segundos y, si otro usuario
        movio algo, refresca solo lo que cambio.
   ============================================================================ */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. Tablas y columnas
   ======================================================================== */
IF COL_LENGTH('dbo.Repuesto', 'rep_largo_cm') IS NULL
    ALTER TABLE [dbo].[Repuesto] ADD
        rep_largo_cm  DECIMAL(9,2)  NULL,
        rep_ancho_cm  DECIMAL(9,2)  NULL,
        rep_alto_cm   DECIMAL(9,2)  NULL,
        rep_peso_kg   DECIMAL(10,3) NULL
GO
IF COL_LENGTH('dbo.Bodega_Ubicacion', 'bub_carga_nivel_kg') IS NULL
    ALTER TABLE [dbo].[Bodega_Ubicacion] ADD bub_carga_nivel_kg DECIMAL(10,2) NULL
GO

IF OBJECT_ID('dbo.Bodega_Ubicacion_Posicion') IS NULL
BEGIN
    CREATE TABLE [dbo].[Bodega_Ubicacion_Posicion] (
        bup_id               INT IDENTITY(1,1) NOT NULL,
        bup_ubicacion        INT      NOT NULL,
        bup_repuesto         INT      NOT NULL,
        bup_nivel            TINYINT  NOT NULL,
        bup_posicion         TINYINT  NOT NULL,
        bup_fila             TINYINT  NOT NULL CONSTRAINT DF_BUP_FILA DEFAULT (0),
        bup_usuario          INT      NOT NULL,
        bup_fecha            DATETIME NOT NULL CONSTRAINT DF_BUP_FECHA DEFAULT ([dbo].[FNC_AHORA]()),
        CONSTRAINT PK_BODEGA_UBICACION_POSICION PRIMARY KEY CLUSTERED (bup_id),
        CONSTRAINT FK_BUP_UBICACION FOREIGN KEY (bup_ubicacion) REFERENCES [dbo].[Bodega_Ubicacion] (bub_id),
        CONSTRAINT FK_BUP_REPUESTO FOREIGN KEY (bup_repuesto) REFERENCES [dbo].[Repuesto] (rep_id),
        CONSTRAINT UX_BUP_REPUESTO UNIQUE (bup_ubicacion, bup_repuesto),
        CONSTRAINT UX_BUP_CASILLERO UNIQUE (bup_ubicacion, bup_nivel, bup_posicion, bup_fila),
        CONSTRAINT CK_BUP_RANGO CHECK (bup_nivel BETWEEN 1 AND 10 AND bup_posicion BETWEEN 1 AND 30 AND bup_fila IN (0, 1))
    )
END
GO

IF OBJECT_ID('dbo.Solicitud_Reposicion') IS NULL
BEGIN
    CREATE TABLE [dbo].[Solicitud_Reposicion] (
        sre_id           INT IDENTITY(1,1) NOT NULL,
        sre_cliente      INT            NOT NULL,
        sre_numero       INT            NOT NULL,
        sre_bodega       INT            NOT NULL,
        sre_estado       VARCHAR(10)    NOT NULL CONSTRAINT DF_SRE_ESTADO DEFAULT ('PENDIENTE'),
        sre_observacion  NVARCHAR(500)  NULL,
        sre_usuario      INT            NOT NULL,
        sre_fecha        DATETIME       NOT NULL CONSTRAINT DF_SRE_FECHA DEFAULT ([dbo].[FNC_AHORA]()),
        sre_usuario_estado INT          NULL,
        sre_fecha_estado DATETIME       NULL,
        CONSTRAINT PK_SOLICITUD_REPOSICION PRIMARY KEY CLUSTERED (sre_id),
        CONSTRAINT FK_SRE_BODEGA FOREIGN KEY (sre_bodega) REFERENCES [dbo].[Bodega] (bod_id),
        CONSTRAINT UX_SRE_NUMERO UNIQUE (sre_cliente, sre_numero),
        CONSTRAINT CK_SRE_ESTADO CHECK (sre_estado IN ('PENDIENTE', 'ENVIADA', 'RECIBIDA', 'ANULADA'))
    )
    CREATE TABLE [dbo].[Solicitud_Reposicion_Detalle] (
        srd_id           INT IDENTITY(1,1) NOT NULL,
        srd_solicitud    INT            NOT NULL,
        srd_repuesto     INT            NOT NULL,
        srd_cantidad     DECIMAL(18,4)  NOT NULL,
        srd_stock        DECIMAL(18,4)  NULL,
        srd_minimo       DECIMAL(18,4)  NULL,
        srd_maximo       DECIMAL(18,4)  NULL,
        CONSTRAINT PK_SOLICITUD_REPOSICION_DETALLE PRIMARY KEY CLUSTERED (srd_id),
        CONSTRAINT FK_SRD_SOLICITUD FOREIGN KEY (srd_solicitud) REFERENCES [dbo].[Solicitud_Reposicion] (sre_id),
        CONSTRAINT FK_SRD_REPUESTO FOREIGN KEY (srd_repuesto) REFERENCES [dbo].[Repuesto] (rep_id),
        CONSTRAINT UX_SRD_REPUESTO UNIQUE (srd_solicitud, srd_repuesto),
        CONSTRAINT CK_SRD_CANTIDAD CHECK (srd_cantidad > 0)
    )
END
GO

IF OBJECT_ID('dbo.Bodega_Plano_Rack') IS NULL
    CREATE TABLE [dbo].[Bodega_Plano_Rack] (
        bpr_ubicacion   INT            NOT NULL,
        bpr_x           DECIMAL(9,3)   NOT NULL,
        bpr_z           DECIMAL(9,3)   NOT NULL,
        bpr_rot         DECIMAL(9,5)   NOT NULL,
        bpr_usuario     INT            NOT NULL,
        bpr_fecha       DATETIME       NOT NULL CONSTRAINT DF_BPR_FECHA DEFAULT ([dbo].[FNC_AHORA]()),
        CONSTRAINT PK_BODEGA_PLANO_RACK PRIMARY KEY CLUSTERED (bpr_ubicacion),
        CONSTRAINT FK_BPR_UBICACION FOREIGN KEY (bpr_ubicacion) REFERENCES [dbo].[Bodega_Ubicacion] (bub_id)
    )
GO

IF OBJECT_ID('dbo.Bodega_Zona') IS NULL
    CREATE TABLE [dbo].[Bodega_Zona] (
        bzo_id          INT IDENTITY(1,1) NOT NULL,
        bzo_bodega      INT            NOT NULL,
        bzo_tipo        VARCHAR(12)    NOT NULL,
        bzo_nombre      NVARCHAR(80)   NOT NULL,
        bzo_x           DECIMAL(9,3)   NOT NULL,
        bzo_z           DECIMAL(9,3)   NOT NULL,
        bzo_ancho       DECIMAL(9,3)   NOT NULL,
        bzo_largo       DECIMAL(9,3)   NOT NULL,
        bzo_habilitado  BIT            NOT NULL CONSTRAINT DF_BZO_HABILITADO DEFAULT (1),
        bzo_usuario     INT            NOT NULL,
        bzo_fecha       DATETIME       NOT NULL CONSTRAINT DF_BZO_FECHA DEFAULT ([dbo].[FNC_AHORA]()),
        CONSTRAINT PK_BODEGA_ZONA PRIMARY KEY CLUSTERED (bzo_id),
        CONSTRAINT FK_BZO_BODEGA FOREIGN KEY (bzo_bodega) REFERENCES [dbo].[Bodega] (bod_id),
        CONSTRAINT CK_BZO_TIPO CHECK (bzo_tipo IN ('RECEPCION', 'CUARENTENA', 'DESPACHO', 'MUELLE', 'PEATONAL', 'OTRA')),
        CONSTRAINT CK_BZO_MEDIDAS CHECK (bzo_ancho > 0 AND bzo_largo > 0)
    )
GO


/* ========================================================================
   2. Dimensiones, peso y carga
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPD_REPUESTO_DIMENSIONES]
    @CLIENTE  INT,
    @REPUESTO INT,
    @LARGO    DECIMAL(9,2) = NULL,
    @ANCHO    DECIMAL(9,2) = NULL,
    @ALTO     DECIMAL(9,2) = NULL,
    @PESO     DECIMAL(10,3) = NULL,
    @USUARIO  INT
AS
SET NOCOUNT ON
IF (ISNULL(@LARGO, 1) <= 0 OR ISNULL(@ANCHO, 1) <= 0 OR ISNULL(@ALTO, 1) <= 0 OR ISNULL(@PESO, 1) < 0)
BEGIN
    RAISERROR('1.- LAS MEDIDAS DEBEN SER MAYORES QUE CERO Y EL PESO NO PUEDE SER NEGATIVO.', 16, 1)
    RETURN -1
END
UPDATE [dbo].[Repuesto]
SET    rep_largo_cm = @LARGO, rep_ancho_cm = @ANCHO, rep_alto_cm = @ALTO, rep_peso_kg = @PESO
WHERE  rep_id = @REPUESTO AND rep_cliente = @CLIENTE
IF (@@ROWCOUNT = 0)
BEGIN
    RAISERROR('2.- EL REPUESTO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END
SELECT @REPUESTO [ID], '200' [CODE], 'Dimensiones actualizadas.' [MENSAJE]
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_UBICACION_CARGA]
    @CLIENTE   INT,
    @UBICACION INT,
    @CARGA     DECIMAL(10,2) = NULL,
    @USUARIO   INT
AS
SET NOCOUNT ON
IF (@CARGA IS NOT NULL AND @CARGA <= 0)
BEGIN
    RAISERROR('1.- LA CARGA POR NIVEL DEBE SER MAYOR QUE CERO.', 16, 1)
    RETURN -1
END
UPDATE u
SET    u.bub_carga_nivel_kg = @CARGA, u.bub_usuario_actualizacion = @USUARIO, u.bub_fecha_actualizacion = [dbo].[FNC_AHORA]()
FROM   [dbo].[Bodega_Ubicacion] u JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
WHERE  u.bub_id = @UBICACION AND b.bod_cliente = @CLIENTE
IF (@@ROWCOUNT = 0)
BEGIN
    RAISERROR('2.- LA UBICACION NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END
SELECT @UBICACION [ID], '200' [CODE], 'Carga actualizada.' [MENSAJE]
RETURN 0
GO

/* Lo que la ficha del repuesto del mapa necesita y GetRepuesto no trae. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO_FICHA_MAPA]
    @CLIENTE  INT,
    @REPUESTO INT
AS
SET NOCOUNT ON
    SELECT rep_metodo_salida AS METODO, rep_largo_cm AS LARGO, rep_ancho_cm AS ANCHO, rep_alto_cm AS ALTO, rep_peso_kg AS PESO
    FROM   [dbo].[Repuesto] WHERE rep_id = @REPUESTO AND rep_cliente = @CLIENTE
GO


/* ========================================================================
   3. Posiciones (planograma)
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_MAPA_POSICIONES]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
    SELECT p.bup_ubicacion AS BUB_ID, p.bup_repuesto AS REP_ID, p.bup_nivel AS NIVEL, p.bup_posicion AS POSICION, p.bup_fila AS FILA
    FROM   [dbo].[Bodega_Ubicacion_Posicion] p
    JOIN   [dbo].[Bodega_Ubicacion] u ON u.bub_id = p.bup_ubicacion
    JOIN   [dbo].[Bodega] b           ON b.bod_id = u.bub_bodega
    WHERE  b.bod_cliente = @CLIENTE
      AND  (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
GO

/* Reemplaza el planograma COMPLETO de un rack: @LISTA es un JSON
   [{"repuesto":1,"nivel":2,"posicion":3,"fila":0}, ...]. Todo o nada. */
CREATE OR ALTER PROCEDURE [dbo].[UPS_UBICACION_POSICIONES]
    @CLIENTE   INT,
    @UBICACION INT,
    @LISTA     NVARCHAR(MAX),
    @USUARIO   INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion] u JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
               WHERE u.bub_id = @UBICACION AND b.bod_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA UBICACION NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF (ISJSON(ISNULL(@LISTA, '')) = 0)
BEGIN
    RAISERROR('2.- LA LISTA DE POSICIONES NO ES VALIDA.', 16, 1)
    RETURN -1
END

DECLARE @P TABLE (repuesto INT, nivel INT, posicion INT, fila INT)
INSERT INTO @P SELECT repuesto, nivel, posicion, ISNULL(fila, 0)
FROM OPENJSON(@LISTA) WITH (repuesto INT '$.repuesto', nivel INT '$.nivel', posicion INT '$.posicion', fila INT '$.fila')

IF EXISTS (SELECT 1 FROM @P p LEFT JOIN [dbo].[Repuesto] r ON r.rep_id = p.repuesto AND r.rep_cliente = @CLIENTE WHERE r.rep_id IS NULL)
BEGIN
    RAISERROR('3.- HAY UN REPUESTO QUE NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF EXISTS (SELECT 1 FROM @P GROUP BY nivel, posicion, fila HAVING COUNT(*) > 1)
BEGIN
    RAISERROR('4.- DOS REPUESTOS NO PUEDEN OCUPAR LA MISMA POSICION.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION
    DELETE FROM [dbo].[Bodega_Ubicacion_Posicion] WHERE bup_ubicacion = @UBICACION
    INSERT INTO [dbo].[Bodega_Ubicacion_Posicion] (bup_ubicacion, bup_repuesto, bup_nivel, bup_posicion, bup_fila, bup_usuario)
    SELECT @UBICACION, repuesto, nivel, posicion, fila, @USUARIO FROM @P
COMMIT TRANSACTION

SELECT @UBICACION [ID], '200' [CODE], 'Posiciones guardadas.' [MENSAJE]
RETURN 0
GO


/* ========================================================================
   4. Consumo por caja (rotacion y quiebre)
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_MAPA_ROTACION]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @DIAS        INT = 90
AS
SET NOCOUNT ON
DECLARE @DESDE DATETIME = DATEADD(DAY, -ISNULL(@DIAS, 90), GETUTCDATE())

    SELECT  m.imo_bodega                                             AS BOD_ID,
            m.imo_bodega_ubicacion                                   AS BUB_ID,
            m.imo_repuesto                                           AS REP_ID,
            SUM(m.imo_cantidad)                                      AS SALIDAS,
            SUM(CASE WHEN m.imo_inventario_movimiento_tipo = 2 THEN 1 ELSE 0 END) AS RETIROS,
            MAX(m.imo_fecha_movimiento_utc)                          AS ULTIMA
    FROM    [dbo].[Inventario_Movimiento] m
    JOIN    [dbo].[Bodega] b ON b.bod_id = m.imo_bodega
    WHERE   m.imo_cliente = @CLIENTE
      AND   m.imo_inventario_movimiento_tipo IN (2, 8)
      AND   m.imo_fecha_movimiento_utc >= @DESDE
      AND   (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
    GROUP BY m.imo_bodega, m.imo_bodega_ubicacion, m.imo_repuesto
GO


/* ========================================================================
   5. Compatibles con un equipo
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_MAPA_ACTIVOS]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
    SELECT  a.act_id AS ID, a.act_codigo AS CODIGO, a.act_nombre AS NOMBRE,
            ISNULL(mo.amo_nombre, '') AS MODELO,
            (SELECT COUNT(*) FROM [dbo].[Repuesto_Compatibilidad] c
              WHERE (c.rco_activo_modelo = a.act_activo_modelo)
                 OR (c.rco_activo_modelo IS NULL AND c.rco_activo_componente IS NULL AND c.rco_activo_tipo = a.act_activo_tipo)
                 OR (c.rco_activo_componente IN (SELECT ac.aco_id FROM [dbo].[Activo_Componente] ac WHERE ac.aco_activo = a.act_id))) AS COMPATIBLES
    FROM    [dbo].[Activo] a
    LEFT JOIN [dbo].[Activo_Modelo] mo ON mo.amo_id = a.act_activo_modelo
    WHERE   a.act_cliente = @CLIENTE
      AND   ISNULL(a.act_habilitado, 0) = 1
      AND   a.act_fusionado_en IS NULL
      AND   (@INSTALACION IS NULL OR a.act_cliente_instalacion = @INSTALACION)
    ORDER BY a.act_codigo
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_MAPA_COMPATIBLES]
    @CLIENTE INT,
    @ACTIVO  INT
AS
SET NOCOUNT ON
DECLARE @TIPO INT, @MODELO INT
SELECT @TIPO = act_activo_tipo, @MODELO = act_activo_modelo FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE
IF (@@ROWCOUNT = 0)
BEGIN
    RAISERROR('1.- EL EQUIPO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END
    SELECT  c.rco_repuesto AS REP_ID,
            MIN(CASE WHEN c.rco_activo_componente IS NOT NULL THEN 'Componente'
                     WHEN c.rco_activo_modelo IS NOT NULL THEN 'Modelo' ELSE 'Tipo de equipo' END) AS REGLA,
            MAX(ISNULL(c.rco_observacion, '')) AS OBSERVACION
    FROM    [dbo].[Repuesto_Compatibilidad] c
    JOIN    [dbo].[Repuesto] r ON r.rep_id = c.rco_repuesto AND r.rep_cliente = @CLIENTE
    WHERE   (c.rco_activo_modelo IS NOT NULL AND c.rco_activo_modelo = @MODELO)
       OR   (c.rco_activo_modelo IS NULL AND c.rco_activo_componente IS NULL AND c.rco_activo_tipo IS NOT NULL AND c.rco_activo_tipo = @TIPO)
       OR   (c.rco_activo_componente IS NOT NULL AND EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] ac
                                                              WHERE ac.aco_id = c.rco_activo_componente AND ac.aco_activo = @ACTIVO))
    GROUP BY c.rco_repuesto
GO


/* ========================================================================
   6. Solicitud de reposicion
   ======================================================================== */
/* @DETALLE: [{"repuesto":1,"cantidad":10,"stock":2,"minimo":5,"maximo":12}, ...] */
CREATE OR ALTER PROCEDURE [dbo].[INS_SOLICITUD_REPOSICION]
    @ID          INT OUTPUT,
    @CLIENTE     INT,
    @BODEGA      INT,
    @OBSERVACION NVARCHAR(500) = NULL,
    @DETALLE     NVARCHAR(MAX),
    @USUARIO     INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega] WHERE bod_id = @BODEGA AND bod_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA BODEGA NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF (ISJSON(ISNULL(@DETALLE, '')) = 0)
BEGIN
    RAISERROR('2.- EL DETALLE DE LA SOLICITUD NO ES VALIDO.', 16, 1)
    RETURN -1
END

DECLARE @D TABLE (repuesto INT, cantidad DECIMAL(18,4), stock DECIMAL(18,4), minimo DECIMAL(18,4), maximo DECIMAL(18,4))
INSERT INTO @D SELECT repuesto, cantidad, stock, minimo, maximo
FROM OPENJSON(@DETALLE) WITH (repuesto INT '$.repuesto', cantidad DECIMAL(18,4) '$.cantidad', stock DECIMAL(18,4) '$.stock',
                              minimo DECIMAL(18,4) '$.minimo', maximo DECIMAL(18,4) '$.maximo')
DELETE FROM @D WHERE ISNULL(cantidad, 0) <= 0

IF NOT EXISTS (SELECT 1 FROM @D)
BEGIN
    RAISERROR('3.- LA SOLICITUD NO TIENE NINGUN REPUESTO CON CANTIDAD.', 16, 1)
    RETURN -1
END
IF EXISTS (SELECT 1 FROM @D d LEFT JOIN [dbo].[Repuesto] r ON r.rep_id = d.repuesto AND r.rep_cliente = @CLIENTE WHERE r.rep_id IS NULL)
BEGIN
    RAISERROR('4.- HAY UN REPUESTO QUE NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF EXISTS (SELECT 1 FROM @D GROUP BY repuesto HAVING COUNT(*) > 1)
BEGIN
    RAISERROR('5.- UN REPUESTO APARECE DOS VECES EN LA SOLICITUD.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION
    DECLARE @NUMERO INT = ISNULL((SELECT MAX(sre_numero) FROM [dbo].[Solicitud_Reposicion] WITH (UPDLOCK, HOLDLOCK) WHERE sre_cliente = @CLIENTE), 0) + 1
    INSERT INTO [dbo].[Solicitud_Reposicion] (sre_cliente, sre_numero, sre_bodega, sre_observacion, sre_usuario)
    VALUES (@CLIENTE, @NUMERO, @BODEGA, NULLIF(LTRIM(RTRIM(@OBSERVACION)), ''), @USUARIO)
    SET @ID = SCOPE_IDENTITY()
    INSERT INTO [dbo].[Solicitud_Reposicion_Detalle] (srd_solicitud, srd_repuesto, srd_cantidad, srd_stock, srd_minimo, srd_maximo)
    SELECT @ID, repuesto, cantidad, stock, minimo, maximo FROM @D
COMMIT TRANSACTION

SELECT @ID [ID], @NUMERO [NUMERO], '200' [CODE], 'Solicitud de reposición N° ' + LTRIM(STR(@NUMERO)) + ' creada.' [MENSAJE]
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_SOLICITUD_REPOSICION]
    @CLIENTE INT,
    @BODEGA  INT = NULL,
    @ID      INT = NULL
AS
SET NOCOUNT ON
    SELECT  s.sre_id AS ID, s.sre_numero AS NUMERO, s.sre_bodega AS BOD_ID, b.bod_nombre AS BODEGA,
            s.sre_estado AS ESTADO, ISNULL(s.sre_observacion, '') AS OBSERVACION, s.sre_fecha AS FECHA,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' ' + ISNULL(u.usu_apellido_paterno, ''))) AS USUARIO,
            d.srd_repuesto AS REP_ID, r.rep_codigo AS REP_CODIGO, r.rep_nombre AS REP_NOMBRE,
            ISNULL(ume.ume_simbolo, ume.ume_nombre) AS UNIDAD,
            d.srd_cantidad AS CANTIDAD, d.srd_stock AS STOCK, d.srd_minimo AS MINIMO, d.srd_maximo AS MAXIMO
    FROM    [dbo].[Solicitud_Reposicion] s
    JOIN    [dbo].[Bodega] b ON b.bod_id = s.sre_bodega
    JOIN    [dbo].[Solicitud_Reposicion_Detalle] d ON d.srd_solicitud = s.sre_id
    JOIN    [dbo].[Repuesto] r ON r.rep_id = d.srd_repuesto
    LEFT JOIN [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Usuario] u ON u.usu_id = s.sre_usuario
    WHERE   s.sre_cliente = @CLIENTE
      AND   (@BODEGA IS NULL OR s.sre_bodega = @BODEGA)
      AND   (@ID IS NULL OR s.sre_id = @ID)
      AND   (@ID IS NOT NULL OR s.sre_fecha >= DATEADD(DAY, -120, [dbo].[FNC_AHORA]()))
    ORDER BY s.sre_numero DESC, r.rep_codigo
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_SOLICITUD_REPOSICION_ESTADO]
    @CLIENTE INT,
    @ID      INT,
    @ESTADO  VARCHAR(10),
    @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @ACTUAL VARCHAR(10)
SELECT @ACTUAL = sre_estado FROM [dbo].[Solicitud_Reposicion] WHERE sre_id = @ID AND sre_cliente = @CLIENTE
IF (@ACTUAL IS NULL)
BEGIN
    RAISERROR('1.- LA SOLICITUD NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END
/* El camino es uno solo: PENDIENTE -> ENVIADA -> RECIBIDA, y se puede anular
   mientras no se haya recibido. Lo recibido o anulado ya no cambia. */
IF NOT ((@ACTUAL = 'PENDIENTE' AND @ESTADO IN ('ENVIADA', 'ANULADA'))
     OR (@ACTUAL = 'ENVIADA'   AND @ESTADO IN ('RECIBIDA', 'ANULADA')))
BEGIN
    RAISERROR('2.- LA SOLICITUD NO PUEDE PASAR DE ESE ESTADO AL QUE SE INDICA.', 16, 1)
    RETURN -1
END
UPDATE [dbo].[Solicitud_Reposicion]
SET    sre_estado = @ESTADO, sre_usuario_estado = @USUARIO, sre_fecha_estado = [dbo].[FNC_AHORA]()
WHERE  sre_id = @ID
SELECT @ID [ID], '200' [CODE], 'Solicitud actualizada.' [MENSAJE]
RETURN 0
GO


/* ========================================================================
   7. Plano: racks movidos y zonas
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_MAPA_PLANO]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
    SELECT 'RACK' AS CLASE, p.bpr_ubicacion AS ID, u.bub_bodega AS BOD_ID, '' AS TIPO, '' AS NOMBRE,
           p.bpr_x AS X, p.bpr_z AS Z, p.bpr_rot AS ROT, CAST(NULL AS DECIMAL(9,3)) AS ANCHO, CAST(NULL AS DECIMAL(9,3)) AS LARGO
    FROM   [dbo].[Bodega_Plano_Rack] p
    JOIN   [dbo].[Bodega_Ubicacion] u ON u.bub_id = p.bpr_ubicacion
    JOIN   [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
    WHERE  b.bod_cliente = @CLIENTE AND (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
    UNION ALL
    SELECT 'ZONA', z.bzo_id, z.bzo_bodega, z.bzo_tipo, z.bzo_nombre, z.bzo_x, z.bzo_z, 0, z.bzo_ancho, z.bzo_largo
    FROM   [dbo].[Bodega_Zona] z
    JOIN   [dbo].[Bodega] b ON b.bod_id = z.bzo_bodega
    WHERE  b.bod_cliente = @CLIENTE AND z.bzo_habilitado = 1 AND (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
GO

CREATE OR ALTER PROCEDURE [dbo].[UPS_BODEGA_PLANO_RACK]
    @CLIENTE   INT,
    @UBICACION INT,
    @X         DECIMAL(9,3),
    @Z         DECIMAL(9,3),
    @ROT       DECIMAL(9,5),
    @USUARIO   INT
AS
SET NOCOUNT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion] u JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
               WHERE u.bub_id = @UBICACION AND b.bod_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA UBICACION NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF EXISTS (SELECT 1 FROM [dbo].[Bodega_Plano_Rack] WHERE bpr_ubicacion = @UBICACION)
    UPDATE [dbo].[Bodega_Plano_Rack] SET bpr_x = @X, bpr_z = @Z, bpr_rot = @ROT, bpr_usuario = @USUARIO, bpr_fecha = [dbo].[FNC_AHORA]()
    WHERE  bpr_ubicacion = @UBICACION
ELSE
    INSERT INTO [dbo].[Bodega_Plano_Rack] (bpr_ubicacion, bpr_x, bpr_z, bpr_rot, bpr_usuario) VALUES (@UBICACION, @X, @Z, @ROT, @USUARIO)
SELECT @UBICACION [ID], '200' [CODE], 'Posición del rack guardada.' [MENSAJE]
RETURN 0
GO

/* Volver a la posicion que da el codigo: se borra la fila del plano (es una
   preferencia de dibujo, no un dato del negocio). */
CREATE OR ALTER PROCEDURE [dbo].[DEL_BODEGA_PLANO_RACK]
    @CLIENTE   INT,
    @UBICACION INT
AS
SET NOCOUNT ON
DELETE p FROM [dbo].[Bodega_Plano_Rack] p
JOIN [dbo].[Bodega_Ubicacion] u ON u.bub_id = p.bpr_ubicacion
JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
WHERE p.bpr_ubicacion = @UBICACION AND b.bod_cliente = @CLIENTE
SELECT @UBICACION [ID], '200' [CODE], 'El rack vuelve a su posición por código.' [MENSAJE]
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPS_BODEGA_ZONA]
    @ID       INT OUTPUT,
    @CLIENTE  INT,
    @BODEGA   INT,
    @TIPO     VARCHAR(12),
    @NOMBRE   NVARCHAR(80),
    @X        DECIMAL(9,3),
    @Z        DECIMAL(9,3),
    @ANCHO    DECIMAL(9,3),
    @LARGO    DECIMAL(9,3),
    @USUARIO  INT
AS
SET NOCOUNT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega] WHERE bod_id = @BODEGA AND bod_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA BODEGA NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF (@ANCHO < 0.5 OR @LARGO < 0.5)
BEGIN
    RAISERROR('2.- UNA ZONA MIDE AL MENOS 0,5 x 0,5 m.', 16, 1)
    RETURN -1
END
SET @NOMBRE = LTRIM(RTRIM(ISNULL(@NOMBRE, '')))
IF (@NOMBRE = '') SET @NOMBRE = @TIPO

IF (ISNULL(@ID, 0) > 0)
BEGIN
    UPDATE [dbo].[Bodega_Zona]
    SET    bzo_tipo = @TIPO, bzo_nombre = @NOMBRE, bzo_x = @X, bzo_z = @Z, bzo_ancho = @ANCHO, bzo_largo = @LARGO,
           bzo_usuario = @USUARIO, bzo_fecha = [dbo].[FNC_AHORA]()
    WHERE  bzo_id = @ID AND bzo_bodega = @BODEGA AND bzo_habilitado = 1
    IF (@@ROWCOUNT = 0)
    BEGIN
        RAISERROR('3.- LA ZONA NO EXISTE.', 16, 1)
        RETURN -1
    END
END
ELSE
BEGIN
    INSERT INTO [dbo].[Bodega_Zona] (bzo_bodega, bzo_tipo, bzo_nombre, bzo_x, bzo_z, bzo_ancho, bzo_largo, bzo_usuario)
    VALUES (@BODEGA, @TIPO, @NOMBRE, @X, @Z, @ANCHO, @LARGO, @USUARIO)
    SET @ID = SCOPE_IDENTITY()
END
SELECT @ID [ID], '200' [CODE], 'Zona guardada.' [MENSAJE]
RETURN 0
GO

/* Baja logica. */
CREATE OR ALTER PROCEDURE [dbo].[DEL_BODEGA_ZONA]
    @CLIENTE INT,
    @ID      INT,
    @USUARIO INT
AS
SET NOCOUNT ON
UPDATE z SET z.bzo_habilitado = 0, z.bzo_usuario = @USUARIO, z.bzo_fecha = [dbo].[FNC_AHORA]()
FROM [dbo].[Bodega_Zona] z JOIN [dbo].[Bodega] b ON b.bod_id = z.bzo_bodega
WHERE z.bzo_id = @ID AND b.bod_cliente = @CLIENTE
SELECT @ID [ID], '200' [CODE], 'Zona eliminada.' [MENSAJE]
RETURN 0
GO


/* ========================================================================
   8. Historial
   ======================================================================== */
/* El stock al CIERRE de @FECHA (hora de Santiago): el saldo de hoy menos lo
   que se movio despues. Cada saldo nacio de un movimiento, asi que una caja
   creada despues de esa fecha da cero y no aparece. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_MAPA_SALDOS_FECHA]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @FECHA       DATE
AS
SET NOCOUNT ON
DECLARE @HASTA_UTC DATETIME = CAST(CAST(DATEADD(DAY, 1, @FECHA) AS DATETIME) AT TIME ZONE 'Pacific SA Standard Time' AT TIME ZONE 'UTC' AS DATETIME)

;WITH delta AS (
    SELECT imo_bodega AS bod, imo_bodega_ubicacion AS ubi, imo_repuesto_lote AS lote, imo_repuesto AS rep,
           CASE WHEN imo_inventario_movimiento_tipo IN (1, 3, 4, 7) THEN imo_cantidad ELSE -imo_cantidad END AS d
    FROM   [dbo].[Inventario_Movimiento]
    WHERE  imo_cliente = @CLIENTE AND imo_fecha_movimiento_utc >= @HASTA_UTC
    UNION ALL
    SELECT imo_bodega, imo_bodega_ubicacion_destino, imo_repuesto_lote, imo_repuesto, imo_cantidad
    FROM   [dbo].[Inventario_Movimiento]
    WHERE  imo_cliente = @CLIENTE AND imo_fecha_movimiento_utc >= @HASTA_UTC AND imo_inventario_movimiento_tipo = 9
), porCubo AS (
    SELECT bod, ubi, lote, rep, SUM(d) AS d FROM delta GROUP BY bod, ubi, lote, rep
), cubo AS (
    SELECT s.isa_bodega AS bod, s.isa_bodega_ubicacion AS ubi, s.isa_repuesto_lote AS lote, s.isa_repuesto AS rep,
           s.isa_cantidad - ISNULL(p.d, 0) AS q
    FROM   [dbo].[Inventario_Saldo] s
    LEFT JOIN porCubo p ON p.bod = s.isa_bodega AND ISNULL(p.ubi, -1) = ISNULL(s.isa_bodega_ubicacion, -1)
                       AND ISNULL(p.lote, -1) = ISNULL(s.isa_repuesto_lote, -1) AND p.rep = s.isa_repuesto
    WHERE  s.isa_cliente = @CLIENTE
)
    SELECT  c.bod AS BOD_ID, c.ubi AS BUB_ID, r.rep_id AS REP_ID, r.rep_codigo AS REP_CODIGO, r.rep_nombre AS REP_NOMBRE,
            ISNULL(r.rep_fabricante, '') AS REP_FABRICANTE, ISNULL(r.rep_modelo, '') AS REP_MODELO,
            ISNULL(t.rti_id, 0) AS RTI_ID, ISNULL(t.rti_codigo, '') AS RTI_CODIGO, ISNULL(t.rti_nombre, 'Sin tipo') AS RTI_NOMBRE,
            ISNULL(ume.ume_simbolo, ume.ume_codigo) AS UNIDAD,
            SUM(c.q) AS CANTIDAD, CAST(0 AS DECIMAL(18,4)) AS RESERVADA, COUNT(DISTINCT c.lote) AS LOTES,
            CAST(NULL AS DATETIME) AS ULTIMO_MOVIMIENTO,
            MAX(rbs.rbs_stock_minimo) AS STOCK_MINIMO, MAX(rbs.rbs_stock_maximo) AS STOCK_MAXIMO, MAX(rbs.rbs_punto_reposicion) AS PUNTO_REPOSICION,
            ISNULL(r.rep_metodo_salida, b.bod_metodo_salida) AS METODO,
            CAST(NULL AS DATETIME) AS INGRESO_MIN, CAST(NULL AS DATETIME) AS INGRESO_MAX, MIN(lo.rlo_fecha_vencimiento) AS VENCE_MIN,
            r.rep_largo_cm AS LARGO, r.rep_ancho_cm AS ANCHO, r.rep_alto_cm AS ALTO, r.rep_peso_kg AS PESO
    FROM    cubo c
    JOIN    [dbo].[Bodega] b          ON b.bod_id = c.bod
    JOIN    [dbo].[Repuesto] r        ON r.rep_id = c.rep
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Repuesto_Tipo] t ON t.rti_id = r.rep_repuesto_tipo
    LEFT JOIN [dbo].[Repuesto_Lote] lo ON lo.rlo_id = c.lote
    LEFT JOIN [dbo].[Repuesto_Bodega_Stock] rbs ON rbs.rbs_repuesto = c.rep AND rbs.rbs_bodega = c.bod AND ISNULL(rbs.rbs_habilitado, 0) = 1
    WHERE   c.q > 0
      AND   ISNULL(b.bod_habilitado, 0) = 1
      AND   (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
    GROUP BY c.bod, c.ubi, r.rep_id, r.rep_codigo, r.rep_nombre, r.rep_fabricante, r.rep_modelo, t.rti_id, t.rti_codigo, t.rti_nombre,
             ume.ume_simbolo, ume.ume_codigo, r.rep_metodo_salida, b.bod_metodo_salida, r.rep_largo_cm, r.rep_ancho_cm, r.rep_alto_cm, r.rep_peso_kg
    ORDER BY c.bod, c.ubi, t.rti_codigo, r.rep_codigo
GO

/* Los movimientos de la planta entre dos dias (hora de Santiago), en orden:
   el visor los reproduce sobre la escena. Con tope, para que un rango largo
   no traiga el kardex entero. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_MAPA_MOVIMIENTOS]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @DESDE       DATE,
    @HASTA       DATE
AS
SET NOCOUNT ON
DECLARE @D DATETIME = CAST(CAST(@DESDE AS DATETIME) AT TIME ZONE 'Pacific SA Standard Time' AT TIME ZONE 'UTC' AS DATETIME)
DECLARE @H DATETIME = CAST(CAST(DATEADD(DAY, 1, @HASTA) AS DATETIME) AT TIME ZONE 'Pacific SA Standard Time' AT TIME ZONE 'UTC' AS DATETIME)
    SELECT TOP 1000
            m.imo_id AS ID,
            CAST(m.imo_fecha_movimiento_utc AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME) AS FECHA,
            m.imo_inventario_movimiento_tipo AS TIPO_ID, ISNULL(t.imt_nombre, '') AS TIPO,
            m.imo_repuesto AS REP_ID, r.rep_codigo AS REP_CODIGO, r.rep_nombre AS REP_NOMBRE,
            m.imo_bodega AS BOD_ID, m.imo_bodega_ubicacion AS BUB_ID, m.imo_bodega_ubicacion_destino AS BUB_DESTINO,
            m.imo_bodega_destino AS BOD_DESTINO, m.imo_cantidad AS CANTIDAD,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' ' + ISNULL(u.usu_apellido_paterno, ''))) AS USUARIO,
            ISNULL(m.imo_observacion, '') AS OBSERVACION
    FROM    [dbo].[Inventario_Movimiento] m
    JOIN    [dbo].[Bodega] b ON b.bod_id = m.imo_bodega
    JOIN    [dbo].[Repuesto] r ON r.rep_id = m.imo_repuesto
    LEFT JOIN [dbo].[Inventario_Movimiento_Tipo] t ON t.imt_id = m.imo_inventario_movimiento_tipo
    LEFT JOIN [dbo].[Usuario] u ON u.usu_id = m.imo_usuario_creacion
    WHERE   m.imo_cliente = @CLIENTE
      AND   m.imo_fecha_movimiento_utc >= @D AND m.imo_fecha_movimiento_utc < @H
      AND   (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
    ORDER BY m.imo_fecha_movimiento_utc, m.imo_id
GO

/* Cuantos movimientos hubo cada dia: el visor dibuja la actividad sobre la
   linea de tiempo para saber a donde ir. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_MAPA_ACTIVIDAD]
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @DIAS        INT = 90
AS
SET NOCOUNT ON
DECLARE @D DATETIME = DATEADD(DAY, -ISNULL(@DIAS, 90) - 1, GETUTCDATE())
    SELECT  CAST(CAST(m.imo_fecha_movimiento_utc AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME) AS DATE) AS DIA,
            COUNT(*) AS MOVIMIENTOS
    FROM    [dbo].[Inventario_Movimiento] m
    JOIN    [dbo].[Bodega] b ON b.bod_id = m.imo_bodega
    WHERE   m.imo_cliente = @CLIENTE AND m.imo_fecha_movimiento_utc >= @D
      AND   (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
    GROUP BY CAST(CAST(m.imo_fecha_movimiento_utc AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME) AS DATE)
    ORDER BY DIA
GO


/* ========================================================================
   9. Trabajo en equipo: la huella de lo que cambio
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_MAPA_VERSION]
    @CLIENTE     INT,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON
DECLARE @MOV INT, @USU INT, @FEC DATETIME
SELECT TOP 1 @MOV = m.imo_id, @USU = m.imo_usuario_creacion, @FEC = m.imo_fecha_creacion
FROM   [dbo].[Inventario_Movimiento] m JOIN [dbo].[Bodega] b ON b.bod_id = m.imo_bodega
WHERE  m.imo_cliente = @CLIENTE AND (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
ORDER BY m.imo_id DESC

    SELECT  ISNULL(@MOV, 0) AS MOVIMIENTO,
            (SELECT LTRIM(RTRIM(ISNULL(usu_nombre, '') + ' ' + ISNULL(usu_apellido_paterno, ''))) FROM [dbo].[Usuario] WHERE usu_id = @USU) AS USUARIO,
            @FEC AS FECHA,
            CONCAT(
              (SELECT COUNT(*) FROM [dbo].[Bodega] WHERE bod_cliente = @CLIENTE AND ISNULL(bod_habilitado, 0) = 1), '|',
              (SELECT CONVERT(VARCHAR(23), MAX(ISNULL(bod_fecha_actualizacion, bod_fecha_creacion)), 121) FROM [dbo].[Bodega] WHERE bod_cliente = @CLIENTE), '|',
              (SELECT COUNT(*) FROM [dbo].[Bodega_Ubicacion] u JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega WHERE b.bod_cliente = @CLIENTE AND ISNULL(u.bub_habilitado, 0) = 1), '|',
              (SELECT CONVERT(VARCHAR(23), MAX(ISNULL(u.bub_fecha_actualizacion, u.bub_fecha_creacion)), 121) FROM [dbo].[Bodega_Ubicacion] u JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega WHERE b.bod_cliente = @CLIENTE), '|',
              (SELECT CONVERT(VARCHAR(23), MAX(p.bpr_fecha), 121) FROM [dbo].[Bodega_Plano_Rack] p JOIN [dbo].[Bodega_Ubicacion] u ON u.bub_id = p.bpr_ubicacion JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega WHERE b.bod_cliente = @CLIENTE), '|',
              (SELECT CONCAT(COUNT(*), '-', CONVERT(VARCHAR(23), MAX(z.bzo_fecha), 121)) FROM [dbo].[Bodega_Zona] z JOIN [dbo].[Bodega] b ON b.bod_id = z.bzo_bodega WHERE b.bod_cliente = @CLIENTE), '|',
              (SELECT CONCAT(COUNT(*), '-', CONVERT(VARCHAR(23), MAX(p.bup_fecha), 121)) FROM [dbo].[Bodega_Ubicacion_Posicion] p JOIN [dbo].[Bodega_Ubicacion] u ON u.bub_id = p.bup_ubicacion JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega WHERE b.bod_cliente = @CLIENTE)
            ) AS ESTRUCTURA
GO


/* ========================================================================
   10. Lecturas del mapa con lo nuevo (carga por nivel, medidas y peso)
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
            u.bub_nombre                     AS BUB_NOMBRE,
            u.bub_carga_nivel_kg             AS BUB_CARGA_KG
    FROM    [dbo].[Bodega] b
    JOIN    [dbo].[Cliente_Instalacion] ci ON ci.cin_id = b.bod_cliente_instalacion
    LEFT JOIN [dbo].[Bodega_Ubicacion] u   ON u.bub_bodega = b.bod_id
                                          AND ISNULL(u.bub_habilitado, 0) = 1
    WHERE   b.bod_cliente = @CLIENTE
      AND   ISNULL(b.bod_habilitado, 0) = 1
      AND   (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
    ORDER BY ci.cin_nombre, b.bod_codigo, u.bub_codigo
GO

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
            MIN(lo.rlo_fecha_vencimiento)                AS VENCE_MIN,
            r.rep_largo_cm                               AS LARGO,
            r.rep_ancho_cm                               AS ANCHO,
            r.rep_alto_cm                                AS ALTO,
            r.rep_peso_kg                                AS PESO
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
             ume.ume_simbolo, ume.ume_codigo, r.rep_metodo_salida, b.bod_metodo_salida,
             r.rep_largo_cm, r.rep_ancho_cm, r.rep_alto_cm, r.rep_peso_kg
    ORDER BY s.isa_bodega, s.isa_bodega_ubicacion, t.rti_codigo, r.rep_codigo
GO
