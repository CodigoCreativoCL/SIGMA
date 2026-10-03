/* ============================================================================
   SIGMA - Bloque 326
   CONTEO CICLICO DE INVENTARIO (desde el recorrido del mapa 3D)
   ----------------------------------------------------------------------------

   El recorrido de pasillo del mapa 3D ya mostraba lo que el sistema cree que
   hay en cada caja. Con esto el bodeguero ademas lo CUENTA: confirma o corrige
   la cantidad de cada caja, y lo que no calza se ajusta en el acto.

   EL CONTEO NO MUEVE STOCK POR SU CUENTA
     Las diferencias se ajustan con INS_INVENTARIO_MOVIMIENTO (tipo 4 AJUSTE
     POSITIVO / 5 AJUSTE NEGATIVO), el mismo SP de siempre, con sus reglas y su
     kardex. Estas tablas solo dejan la constancia: que se conto, cuando, quien,
     cuanto decia el sistema, cuanto habia y que movimientos lo corrigieron.

   LO QUE "DECIA EL SISTEMA" LO FIJA EL SERVIDOR
     icd_sistema se calcula al confirmar, no lo manda la pantalla: si otro
     movio stock mientras se contaba, la diferencia se mide contra lo real.

   RECONTAR UNA CAJA NO DUPLICA
     Una caja (repuesto + ubicacion) tiene una sola linea por conteo. Si se
     vuelve a contar, se actualiza lo contado y se agregan los movimientos;
     icd_sistema queda con el primer valor, que es contra el que se mide la
     exactitud del conteo.

     Inventario_Conteo          cabecera: bodega, alcance (p. ej. "Pasillo A"),
                                quien, inicio, cierre y el resumen al cerrar.
     Inventario_Conteo_Detalle  una linea por caja contada.

     INS_INVENTARIO_CONTEO           abre un conteo.
     UPS_INVENTARIO_CONTEO_DETALLE   registra (o recuenta) una caja.
     UPD_INVENTARIO_CONTEO_CERRAR    lo cierra y devuelve el resumen.
     SEL_INVENTARIO_CONTEO_ULTIMO    el ultimo conteo de cada ubicacion, para
                                     mostrar en el mapa "contado hace 3 dias".
   ============================================================================ */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. Tablas
   ======================================================================== */
IF OBJECT_ID('dbo.Inventario_Conteo') IS NULL
BEGIN
    CREATE TABLE [dbo].[Inventario_Conteo] (
        ico_id               INT IDENTITY(1,1) NOT NULL,
        ico_cliente          INT            NOT NULL,
        ico_bodega           INT            NOT NULL,
        ico_alcance          NVARCHAR(200)  NOT NULL,
        ico_estado           VARCHAR(10)    NOT NULL CONSTRAINT DF_ICO_ESTADO DEFAULT ('ABIERTO'),
        ico_fecha_inicio     DATETIME       NOT NULL CONSTRAINT DF_ICO_INICIO DEFAULT ([dbo].[FNC_AHORA]()),
        ico_fecha_cierre     DATETIME       NULL,
        ico_usuario          INT            NOT NULL,
        ico_lineas           INT            NULL,
        ico_coinciden        INT            NULL,
        ico_exactitud        DECIMAL(5,2)   NULL,
        CONSTRAINT PK_INVENTARIO_CONTEO PRIMARY KEY CLUSTERED (ico_id),
        CONSTRAINT FK_ICO_BODEGA FOREIGN KEY (ico_bodega) REFERENCES [dbo].[Bodega] (bod_id),
        CONSTRAINT CK_ICO_ESTADO CHECK (ico_estado IN ('ABIERTO', 'CERRADO'))
    )
    CREATE NONCLUSTERED INDEX IX_ICO_CLIENTE_BODEGA ON [dbo].[Inventario_Conteo] (ico_cliente, ico_bodega, ico_fecha_inicio DESC)
END
GO

IF OBJECT_ID('dbo.Inventario_Conteo_Detalle') IS NULL
BEGIN
    CREATE TABLE [dbo].[Inventario_Conteo_Detalle] (
        icd_id                 INT IDENTITY(1,1) NOT NULL,
        icd_conteo             INT            NOT NULL,
        icd_repuesto           INT            NOT NULL,
        icd_bodega_ubicacion   INT            NOT NULL,
        icd_sistema            DECIMAL(18,4)  NOT NULL,
        icd_contado            DECIMAL(18,4)  NOT NULL,
        icd_diferencia         AS (icd_contado - icd_sistema) PERSISTED,
        icd_movimientos        NVARCHAR(400)  NULL,
        icd_resultado          NVARCHAR(400)  NULL,
        icd_usuario            INT            NOT NULL,
        icd_fecha              DATETIME       NOT NULL CONSTRAINT DF_ICD_FECHA DEFAULT ([dbo].[FNC_AHORA]()),
        CONSTRAINT PK_INVENTARIO_CONTEO_DETALLE PRIMARY KEY CLUSTERED (icd_id),
        CONSTRAINT FK_ICD_CONTEO FOREIGN KEY (icd_conteo) REFERENCES [dbo].[Inventario_Conteo] (ico_id),
        CONSTRAINT FK_ICD_REPUESTO FOREIGN KEY (icd_repuesto) REFERENCES [dbo].[Repuesto] (rep_id),
        CONSTRAINT FK_ICD_UBICACION FOREIGN KEY (icd_bodega_ubicacion) REFERENCES [dbo].[Bodega_Ubicacion] (bub_id),
        CONSTRAINT UX_ICD_CAJA UNIQUE (icd_conteo, icd_repuesto, icd_bodega_ubicacion)
    )
    CREATE NONCLUSTERED INDEX IX_ICD_UBICACION ON [dbo].[Inventario_Conteo_Detalle] (icd_bodega_ubicacion, icd_fecha DESC) INCLUDE (icd_conteo, icd_diferencia)
END
GO


/* ========================================================================
   2. Abrir un conteo
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_INVENTARIO_CONTEO]
    @ID       INT OUTPUT,
    @CLIENTE  INT,
    @BODEGA   INT,
    @ALCANCE  NVARCHAR(200),
    @USUARIO  INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega] WHERE bod_id = @BODEGA AND bod_cliente = @CLIENTE AND ISNULL(bod_habilitado, 0) = 1)
BEGIN
    RAISERROR('1.- LA BODEGA NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@ALCANCE IS NULL OR LEN(LTRIM(@ALCANCE)) = 0)
    SET @ALCANCE = N'Conteo'

INSERT INTO [dbo].[Inventario_Conteo] (ico_cliente, ico_bodega, ico_alcance, ico_usuario)
VALUES (@CLIENTE, @BODEGA, LEFT(LTRIM(RTRIM(@ALCANCE)), 200), @USUARIO)

SET @ID = SCOPE_IDENTITY()
SELECT @ID [ID], '200' [CODE], 'Conteo iniciado.' [MENSAJE]
RETURN 0
GO


/* ========================================================================
   3. Registrar (o recontar) una caja
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPS_INVENTARIO_CONTEO_DETALLE]
    @CLIENTE      INT,
    @CONTEO       INT,
    @REPUESTO     INT,
    @UBICACION    INT,
    @SISTEMA      DECIMAL(18,4),
    @CONTADO      DECIMAL(18,4),
    @MOVIMIENTOS  NVARCHAR(400) = NULL,
    @RESULTADO    NVARCHAR(400) = NULL,
    @USUARIO      INT
AS
SET NOCOUNT ON

DECLARE @BODEGA INT

SELECT @BODEGA = ico_bodega
FROM   [dbo].[Inventario_Conteo]
WHERE  ico_id = @CONTEO AND ico_cliente = @CLIENTE AND ico_estado = 'ABIERTO'

IF (@BODEGA IS NULL)
BEGIN
    RAISERROR('1.- EL CONTEO NO EXISTE, NO ES DE ESTE CLIENTE O YA ESTA CERRADO.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion] WHERE bub_id = @UBICACION AND bub_bodega = @BODEGA)
BEGIN
    RAISERROR('2.- LA UBICACION NO PERTENECE A LA BODEGA DEL CONTEO.', 16, 1)
    RETURN -1
END

IF (@CONTADO < 0)
BEGIN
    RAISERROR('3.- LA CANTIDAD CONTADA NO PUEDE SER NEGATIVA.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Inventario_Conteo_Detalle]
           WHERE icd_conteo = @CONTEO AND icd_repuesto = @REPUESTO AND icd_bodega_ubicacion = @UBICACION)
    UPDATE [dbo].[Inventario_Conteo_Detalle]
    SET    icd_contado = @CONTADO,
           icd_movimientos = LEFT(CASE WHEN @MOVIMIENTOS IS NULL THEN icd_movimientos
                                       WHEN icd_movimientos IS NULL THEN @MOVIMIENTOS
                                       ELSE icd_movimientos + ',' + @MOVIMIENTOS END, 400),
           icd_resultado = ISNULL(@RESULTADO, icd_resultado),
           icd_usuario = @USUARIO,
           icd_fecha = [dbo].[FNC_AHORA]()
    WHERE  icd_conteo = @CONTEO AND icd_repuesto = @REPUESTO AND icd_bodega_ubicacion = @UBICACION
ELSE
    INSERT INTO [dbo].[Inventario_Conteo_Detalle]
           (icd_conteo, icd_repuesto, icd_bodega_ubicacion, icd_sistema, icd_contado, icd_movimientos, icd_resultado, icd_usuario)
    VALUES (@CONTEO, @REPUESTO, @UBICACION, @SISTEMA, @CONTADO, @MOVIMIENTOS, @RESULTADO, @USUARIO)

SELECT @CONTEO [ID], '200' [CODE], 'Caja contada.' [MENSAJE]
RETURN 0
GO


/* ========================================================================
   4. Cerrar el conteo y devolver el resumen
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPD_INVENTARIO_CONTEO_CERRAR]
    @CLIENTE  INT,
    @ID       INT,
    @USUARIO  INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Inventario_Conteo] WHERE ico_id = @ID AND ico_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL CONTEO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

DECLARE @LINEAS INT, @COINCIDEN INT

SELECT @LINEAS = COUNT(*),
       @COINCIDEN = SUM(CASE WHEN icd_diferencia = 0 THEN 1 ELSE 0 END)
FROM   [dbo].[Inventario_Conteo_Detalle]
WHERE  icd_conteo = @ID

/* Cerrar dos veces no cambia nada: el resumen queda el de la primera vez. */
UPDATE [dbo].[Inventario_Conteo]
SET    ico_estado = 'CERRADO',
       ico_fecha_cierre = [dbo].[FNC_AHORA](),
       ico_lineas = @LINEAS,
       ico_coinciden = ISNULL(@COINCIDEN, 0),
       ico_exactitud = CASE WHEN @LINEAS > 0 THEN CAST(ISNULL(@COINCIDEN, 0) * 100.0 / @LINEAS AS DECIMAL(5,2)) END
WHERE  ico_id = @ID AND ico_estado = 'ABIERTO'

SELECT  c.ico_id                                                         AS ID,
        c.ico_alcance                                                    AS ALCANCE,
        c.ico_fecha_inicio                                               AS INICIO,
        c.ico_fecha_cierre                                               AS CIERRE,
        ISNULL(c.ico_lineas, 0)                                          AS LINEAS,
        ISNULL(c.ico_coinciden, 0)                                       AS COINCIDEN,
        c.ico_exactitud                                                  AS EXACTITUD,
        COUNT(DISTINCT d.icd_bodega_ubicacion)                           AS UBICACIONES,
        SUM(CASE WHEN d.icd_diferencia > 0 THEN 1 ELSE 0 END)            AS SOBRANTES,
        SUM(CASE WHEN d.icd_diferencia < 0 THEN 1 ELSE 0 END)            AS FALTANTES,
        ISNULL(SUM(ABS(d.icd_diferencia)), 0)                            AS UNIDADES_AJUSTADAS
FROM    [dbo].[Inventario_Conteo] c
LEFT JOIN [dbo].[Inventario_Conteo_Detalle] d ON d.icd_conteo = c.ico_id
WHERE   c.ico_id = @ID
GROUP BY c.ico_id, c.ico_alcance, c.ico_fecha_inicio, c.ico_fecha_cierre, c.ico_lineas, c.ico_coinciden, c.ico_exactitud
RETURN 0
GO


/* ========================================================================
   5. El ultimo conteo de cada ubicacion de una planta
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_INVENTARIO_CONTEO_ULTIMO]
    @CLIENTE      INT,
    @INSTALACION  INT = NULL
AS
SET NOCOUNT ON

;WITH porUbicacion AS (
    SELECT  d.icd_bodega_ubicacion                                   AS BUB_ID,
            d.icd_conteo                                             AS CONTEO,
            MAX(d.icd_fecha)                                         AS FECHA,
            COUNT(*)                                                 AS LINEAS,
            SUM(CASE WHEN d.icd_diferencia = 0 THEN 1 ELSE 0 END)    AS COINCIDEN,
            MAX(d.icd_usuario)                                       AS USUARIO
    FROM    [dbo].[Inventario_Conteo_Detalle] d
    JOIN    [dbo].[Inventario_Conteo] c ON c.ico_id = d.icd_conteo
    JOIN    [dbo].[Bodega] b            ON b.bod_id = c.ico_bodega
    WHERE   c.ico_cliente = @CLIENTE
      AND   (@INSTALACION IS NULL OR b.bod_cliente_instalacion = @INSTALACION)
    GROUP BY d.icd_bodega_ubicacion, d.icd_conteo
), ultimo AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY BUB_ID ORDER BY FECHA DESC) AS N
    FROM   porUbicacion
)
SELECT  u.BUB_ID, u.CONTEO, u.FECHA, u.LINEAS, u.COINCIDEN,
        LTRIM(RTRIM(ISNULL(us.usu_nombre, '') + ' ' + ISNULL(us.usu_apellido_paterno, ''))) AS USUARIO
FROM    ultimo u
LEFT JOIN [dbo].[Usuario] us ON us.usu_id = u.USUARIO
WHERE   u.N = 1
RETURN 0
GO
