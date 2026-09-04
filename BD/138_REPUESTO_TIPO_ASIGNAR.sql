/* ============================================================================
   SIGMA - Bloque 138
   EL TIPO EN EL REPUESTO, Y COMO ASIGNARLO SIN ABRIR TRESCIENTAS FICHAS
   ----------------------------------------------------------------------------

   QUE AGREGA

     1. `UPS_REPUESTO_TIPO_ASIGNAR`, que le pone el mismo tipo a MUCHOS
        repuestos de una vez.
     2. `@REPUESTO_TIPO` en INS_REPUESTO y UPD_REPUESTO.
     3. El tipo y su nombre en el SELECT de SEL_REPUESTO.

   POR QUE HACE FALTA LA ASIGNACION EN LOTE

     Clasificar un maestro que YA existe es el caso real: una planta con
     trescientos repuestos cargados tiene que ponerles tipo a todos. Uno por
     uno son trescientas fichas abiertas, y nadie lo va a hacer: el campo
     queda vacio y las pestañas no sirven para nada.

     Marcando varios en el listado y eligiendo el tipo una sola vez,
     clasificar doscientos rodamientos es un minuto.

   LOS IDS VIAJAN COMO TEXTO SEPARADO POR COMAS

     Es lo que la pantalla tiene a mano tras leer los checkboxes marcados.
     `STRING_SPLIT` los convierte en filas: no hay SQL dinamico ni consulta
     concatenada. Y se filtra ADEMAS por cliente, asi que aunque llegara un id
     de otra empresa, el UPDATE no lo alcanza.

   PONER EL TIPO EN VACIO ES VALIDO

     `@REPUESTO_TIPO` en NULL desclasifica. Es la forma de deshacer una
     asignacion equivocada sin tener que elegir "otro" tipo cualquiera.

   POR QUE LOS DOS PROCEDIMIENTOS VAN COMPLETOS Y NO PARCHEADOS

     La primera version de este bloque los modificaba con REPLACE sobre su
     propia definicion. `REPLACE(@def, '@USUARIO', ...)` toca TODAS las
     apariciones de @USUARIO -no solo la declaracion del parametro- y el
     procedimiento salia corrupto. Fallo antes de aplicarse, pero fue suerte.

     Van escritos enteros, que es lo unico que se puede leer y revisar.

   ES IDEMPOTENTE
   ============================================================================ */

SET NOCOUNT ON
GO

/* ================================================== ASIGNACION EN LOTE */
CREATE OR ALTER PROCEDURE [dbo].[UPS_REPUESTO_TIPO_ASIGNAR]
    @CLIENTE        INT,
    @REPUESTO_TIPO  INT = NULL,
    @IDS            VARCHAR(MAX),
    @USUARIO        INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @AHORA DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

IF LTRIM(RTRIM(ISNULL(@IDS, ''))) = ''
BEGIN
    RAISERROR('1.- NO SE INDICO NINGUN REPUESTO.', 16, 1)
    RETURN -1
END

/* El tipo tiene que ser del mismo cliente. Sin esto, un id de otra empresa
   clasificaria repuestos bajo una categoria ajena. */
IF @REPUESTO_TIPO IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Tipo]
                    WHERE rti_id = @REPUESTO_TIPO
                      AND rti_cliente = @CLIENTE
                      AND rti_habilitado = 1)
BEGIN
    RAISERROR('2.- EL TIPO DE REPUESTO NO EXISTE, NO ES DE ESTE CLIENTE O ESTA DESHABILITADO.', 16, 1)
    RETURN -1
END

UPDATE  r
SET     r.rep_repuesto_tipo         = @REPUESTO_TIPO,
        r.rep_usuario_actualizacion = @USUARIO,
        r.rep_fecha_actualizacion   = @AHORA
FROM    [dbo].[Repuesto] r
JOIN    (SELECT LTRIM(RTRIM(value)) AS ID FROM STRING_SPLIT(@IDS, ',')
          WHERE LTRIM(RTRIM(value)) <> '') s
        ON s.ID = CAST(r.rep_id AS VARCHAR(20))
WHERE   r.rep_cliente = @CLIENTE

SELECT @@ROWCOUNT AS AFECTADOS
GO

/* ============================ INS_REPUESTO, con @REPUESTO_TIPO ============ */
ALTER PROCEDURE [dbo].[INS_REPUESTO]
    @ID               INT OUTPUT,
    @CLIENTE          INT,
    @CODIGO           NVARCHAR(100),
    @NOMBRE           NVARCHAR(400),
    @UNIDAD_MEDIDA    INT,
    @FABRICANTE       NVARCHAR(400) = NULL,
    @MODELO           NVARCHAR(400) = NULL,
    @DESCRIPCION      NVARCHAR(1000) = NULL,
    @ES_REPARABLE     BIT = 0,
    @ES_CONSUMIBLE    BIT = 0,
    @CONTROLA_LOTE    BIT = 0,
    @COSTO_REFERENCIA DECIMAL(18,4) = NULL,
    @MONEDA           INT = NULL,
    @VIDA_UTIL_HORA   DECIMAL(18,4) = NULL,
    @VIDA_UTIL_DIA    INT = NULL,
    @VIDA_UTIL_CICLO  DECIMAL(18,4) = NULL,
    @REPUESTO_TIPO    INT = NULL,
    @USUARIO          INT
AS
SET NOCOUNT ON

    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0)
    BEGIN
        RAISERROR('1.- INDIQUE EL CODIGO DEL REPUESTO.', 16, 1)
        RETURN -1
    END

    IF (@NOMBRE IS NULL OR LEN(LTRIM(@NOMBRE)) = 0)
    BEGIN
        RAISERROR('2.- INDIQUE EL NOMBRE DEL REPUESTO.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida]
                    WHERE ume_id = @UNIDAD_MEDIDA AND ume_habilitado = 1)
    BEGIN
        RAISERROR('3.- LA UNIDAD DE MEDIDA NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Repuesto]
                WHERE rep_cliente = @CLIENTE AND rep_codigo = @CODIGO)
    BEGIN
        RAISERROR('4.- YA EXISTE UN REPUESTO CON ESE CODIGO.', 16, 1)
        RETURN -1
    END

    /* Cero no es "no aplica", es "dura cero". Se rechaza para que el NULL
       siga significando lo unico que puede significar: no se sabe. */
    IF (@VIDA_UTIL_HORA IS NOT NULL AND @VIDA_UTIL_HORA <= 0)
     OR (@VIDA_UTIL_DIA IS NOT NULL AND @VIDA_UTIL_DIA <= 0)
     OR (@VIDA_UTIL_CICLO IS NOT NULL AND @VIDA_UTIL_CICLO <= 0)
    BEGIN
        RAISERROR('5.- LA VIDA UTIL DEBE SER MAYOR QUE CERO. DEJELA VACIA SI NO SE CONOCE.', 16, 1)
        RETURN -1
    END

SET XACT_ABORT ON

BEGIN TRANSACTION

    INSERT INTO [dbo].[Repuesto]
        (rep_uuid, rep_cliente, rep_unidad_medida, rep_codigo, rep_nombre,
         rep_fabricante, rep_modelo, rep_descripcion, rep_es_reparable,
         rep_es_consumible, rep_controla_lote, rep_repuesto_tipo, rep_costo_referencia, rep_moneda,
         rep_vida_util_hora, rep_vida_util_dia, rep_vida_util_ciclo,
         rep_usuario_creacion, rep_fecha_creacion, rep_habilitado)
    VALUES (NEWID(), @CLIENTE, @UNIDAD_MEDIDA, LTRIM(RTRIM(@CODIGO)), @NOMBRE,
            @FABRICANTE, @MODELO, @DESCRIPCION, ISNULL(@ES_REPARABLE, 0),
            ISNULL(@ES_CONSUMIBLE, 0), ISNULL(@CONTROLA_LOTE, 0), @REPUESTO_TIPO,
            @COSTO_REFERENCIA, @MONEDA,
            @VIDA_UTIL_HORA, @VIDA_UTIL_DIA, @VIDA_UTIL_CICLO,
            @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()
    /* ---- CODIGO AUTOMATICO ---- 
       El codigo depende del ID y el ID no existe hasta aca. La ficha
       manda 'AUTO'; ese valor satisface el NOT NULL, pasa por el
       INSERT y nunca queda guardado. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = 'AUTO')
        UPDATE [dbo].[Repuesto]
        SET    [rep_codigo] = [dbo].[FNC_CODIGO_AUTOMATICO]('REP', @ID)
        WHERE  [rep_id] = @ID


COMMIT TRANSACTION
RETURN 0
GO

/* ============================ UPD_REPUESTO, con @REPUESTO_TIPO ============ */
ALTER PROCEDURE [dbo].[UPD_REPUESTO]
    @ID               INT,
    @CLIENTE          INT,
    @NOMBRE           NVARCHAR(400) = NULL,
    @UNIDAD_MEDIDA    INT = NULL,
    @FABRICANTE       NVARCHAR(400) = NULL,
    @MODELO           NVARCHAR(400) = NULL,
    @DESCRIPCION      NVARCHAR(1000) = NULL,
    @ES_REPARABLE     BIT = NULL,
    @ES_CONSUMIBLE    BIT = NULL,
    @CONTROLA_LOTE    BIT = NULL,
    @COSTO_REFERENCIA DECIMAL(18,4) = NULL,
    @MONEDA           INT = NULL,
    @VIDA_UTIL_HORA   DECIMAL(18,4) = NULL,
    @VIDA_UTIL_DIA    INT = NULL,
    @VIDA_UTIL_CICLO  DECIMAL(18,4) = NULL,
    @REPUESTO_TIPO    INT = NULL,
    @LIMPIA_VIDA_UTIL BIT = 0,
    @HABILITADO       BIT = NULL,
    @USUARIO          INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto] WHERE rep_id = @ID AND rep_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- EL REPUESTO NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF (@UNIDAD_MEDIDA IS NOT NULL
        AND @UNIDAD_MEDIDA <> (SELECT rep_unidad_medida FROM [dbo].[Repuesto] WHERE rep_id = @ID)
        AND EXISTS (SELECT 1 FROM [dbo].[Inventario_Saldo]
                     WHERE isa_repuesto = @ID AND isa_cantidad <> 0))
    BEGIN
        DECLARE @MSG_UME NVARCHAR(400) =
            '2.- NO SE PUEDE CAMBIAR LA UNIDAD DE MEDIDA: EL REPUESTO TIENE EXISTENCIA. '
          + 'EL SALDO PASARIA A ESTAR EN OTRA UNIDAD SIN QUE NADIE LO CONVIRTIERA.'
        RAISERROR(@MSG_UME, 16, 1)
        RETURN -1
    END

    IF (@VIDA_UTIL_HORA IS NOT NULL AND @VIDA_UTIL_HORA <= 0)
     OR (@VIDA_UTIL_DIA IS NOT NULL AND @VIDA_UTIL_DIA <= 0)
     OR (@VIDA_UTIL_CICLO IS NOT NULL AND @VIDA_UTIL_CICLO <= 0)
    BEGIN
        RAISERROR('3.- LA VIDA UTIL DEBE SER MAYOR QUE CERO. DEJELA VACIA SI NO SE CONOCE.', 16, 1)
        RETURN -1
    END

SET XACT_ABORT ON

BEGIN TRANSACTION

    /* @LIMPIA_VIDA_UTIL: el problema de ISNULL

       Con ISNULL(@X, columna), un campo que llega vacio significa "no lo
       toques". Eso es lo correcto para casi todo —es lo que evito que
       UPD_CLIENTE_INSTALACION borrara la zona horaria (bloque 51)—, pero
       hace imposible BORRAR un valor: quien se dio cuenta de que la vida
       util estaba mal cargada y limpia el campo, lo ve volver.

       Por eso la bandera. Es explicita a proposito: quien borra tiene que
       decir que esta borrando. */
    UPDATE  [dbo].[Repuesto]
    SET     rep_nombre                = ISNULL(@NOMBRE,           rep_nombre)
           ,rep_unidad_medida         = ISNULL(@UNIDAD_MEDIDA,    rep_unidad_medida)
           ,rep_fabricante            = ISNULL(@FABRICANTE,       rep_fabricante)
           ,rep_modelo                = ISNULL(@MODELO,           rep_modelo)
           ,rep_descripcion           = ISNULL(@DESCRIPCION,      rep_descripcion)
           ,rep_es_reparable          = ISNULL(@ES_REPARABLE,     rep_es_reparable)
           ,rep_es_consumible         = ISNULL(@ES_CONSUMIBLE,    rep_es_consumible)
           ,rep_controla_lote         = ISNULL(@CONTROLA_LOTE,    rep_controla_lote)
           ,rep_repuesto_tipo         = ISNULL(@REPUESTO_TIPO,    rep_repuesto_tipo)
           ,rep_costo_referencia      = ISNULL(@COSTO_REFERENCIA, rep_costo_referencia)
           ,rep_moneda                = ISNULL(@MONEDA,           rep_moneda)
           ,rep_vida_util_hora        = CASE WHEN @LIMPIA_VIDA_UTIL = 1 THEN @VIDA_UTIL_HORA
                                             ELSE ISNULL(@VIDA_UTIL_HORA,  rep_vida_util_hora) END
           ,rep_vida_util_dia         = CASE WHEN @LIMPIA_VIDA_UTIL = 1 THEN @VIDA_UTIL_DIA
                                             ELSE ISNULL(@VIDA_UTIL_DIA,   rep_vida_util_dia) END
           ,rep_vida_util_ciclo       = CASE WHEN @LIMPIA_VIDA_UTIL = 1 THEN @VIDA_UTIL_CICLO
                                             ELSE ISNULL(@VIDA_UTIL_CICLO, rep_vida_util_ciclo) END
           ,rep_habilitado            = ISNULL(@HABILITADO,       rep_habilitado)
           ,rep_usuario_actualizacion = @USUARIO
           ,rep_fecha_actualizacion   = GETDATE()
    WHERE   rep_id = @ID

COMMIT TRANSACTION
RETURN 0
GO

PRINT '138_REPUESTO_TIPO_ASIGNAR aplicado.'
GO
