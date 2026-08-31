/* ============================================================================
   SIGMA — Bloque 63
   LA VIDA UTIL ESPERADA DEL REPUESTO
   ----------------------------------------------------------------------------

   EL HUECO

     Repuesto tiene rep_vida_util_hora, rep_vida_util_dia y
     rep_vida_util_ciclo desde las fundaciones. SEL_REPUESTO (bloque 60) las
     devuelve. Pero INS_REPUESTO y UPD_REPUESTO **no las reciben**, asi que
     no hay forma de escribirlas: la consulta lee tres columnas que siempre
     van a estar en NULL.

     Es un descuido del bloque 60: mapear una columna en el SELECT y
     olvidarla en el alta es peor que no tenerla, porque la pantalla muestra
     un dato vacio y nadie sabe si es que no se cargo o que no existe.

   TRES MEDIDAS Y NO UNA, A PROPOSITO

     Un rodamiento dura HORAS de marcha. Un filtro de aire dura DIAS, gire o
     no gire el equipo. Un contacto de partida dura CICLOS, y no le importa
     el tiempo. Obligar a las tres a una sola columna significaria elegir
     una unidad y que las otras dos mientan.

     Las tres son opcionales y pueden convivir: un aceite puede vencer a las
     2.000 horas O a los 365 dias, lo que ocurra primero.

   ESTO ES LA VIDA UTIL **ESPERADA**, NO LA REAL

     La real es HU-058 y no vive aca: se calcula sobre
     Componente_Repuesto_Instalacion, que registra con que horometro se
     instalo la pieza y con cual se retiro. La esperada es lo que dice el
     fabricante; la real es lo que paso en la planta, y la gracia del modulo
     es justamente poder compararlas.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. INS_REPUESTO — con la vida util esperada
   ======================================================================== */
IF OBJECT_ID('dbo.INS_REPUESTO') IS NOT NULL DROP PROCEDURE [dbo].[INS_REPUESTO]
GO

CREATE PROCEDURE [dbo].[INS_REPUESTO]
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
         rep_es_consumible, rep_controla_lote, rep_costo_referencia, rep_moneda,
         rep_vida_util_hora, rep_vida_util_dia, rep_vida_util_ciclo,
         rep_usuario_creacion, rep_fecha_creacion, rep_habilitado)
    VALUES (NEWID(), @CLIENTE, @UNIDAD_MEDIDA, LTRIM(RTRIM(@CODIGO)), @NOMBRE,
            @FABRICANTE, @MODELO, @DESCRIPCION, ISNULL(@ES_REPARABLE, 0),
            ISNULL(@ES_CONSUMIBLE, 0), ISNULL(@CONTROLA_LOTE, 0),
            @COSTO_REFERENCIA, @MONEDA,
            @VIDA_UTIL_HORA, @VIDA_UTIL_DIA, @VIDA_UTIL_CICLO,
            @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

COMMIT TRANSACTION
RETURN 0
GO


/* ========================================================================
   2. UPD_REPUESTO — idem
   ======================================================================== */
IF OBJECT_ID('dbo.UPD_REPUESTO') IS NOT NULL DROP PROCEDURE [dbo].[UPD_REPUESTO]
GO

CREATE PROCEDURE [dbo].[UPD_REPUESTO]
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


/* ========================================================================
   3. VERIFICACION
   ======================================================================== */
PRINT '--- Los tres parametros de vida util en el alta y la edicion ---'
SELECT  o.name AS procedimiento, p.name AS parametro, TYPE_NAME(p.user_type_id) AS tipo
FROM    sys.objects o
JOIN    sys.parameters p ON p.object_id = o.object_id
WHERE   o.name IN ('INS_REPUESTO', 'UPD_REPUESTO')
  AND   p.name LIKE '%VIDA_UTIL%'
ORDER BY o.name, p.parameter_id
GO
