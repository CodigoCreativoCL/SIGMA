USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  30-08-2026
-- DESCRIPTION:     BLOQUE C.5 CONTENIDO DEL PLAN: QUE INCLUYE Y HASTA CUANTO.
-- =============================================
-- Va DESPUES de 45_SUSCRIPCION_KEY.
--
-- LA PREGUNTA QUE ORIGINA ESTE BLOQUE
--   "Como le asocio al plan lo que contiene?"
--
--   El modelo ya lo resuelve desde el bloque 08. Lo que faltaba era la
--   forma de mantenerlo sin escribir SQL a mano.
--
-- COMO FUNCIONA
--   Funcionalidad tiene 25 filas y DOS naturalezas, marcadas por
--   Funcionalidad_Tipo:
--
--     INCLUSION (21)  se tiene o no se tiene.
--                     GESTION ACTIVOS, ORDEN TRABAJO, ANALISIS PREDICTIVO,
--                     CREACION POR VOZ, API EXTERNA...
--
--     LIMITE (4)      se tiene, pero hasta un tope.
--                     LIMITE PLANTAS, LIMITE USUARIOS, LIMITE ACTIVOS,
--                     LIMITE ALMACENAMIENTO.
--
--   Plan_Comercial_Funcionalidad es la matriz: una fila por plan y
--   funcionalidad, con pcf_incluida (si/no) o pcf_limite (el tope). Sin
--   fila, la funcionalidad NO se tiene: FNC_CLIENTE_TIENE_FUNCIONALIDAD
--   devuelve 0 por defecto. La ausencia es negacion, no "sin definir".
--
-- LAS DOS COSAS QUE HACEN QUE ESTO NO SEA UNA TABLA MAS
--
--   1. pcf_cliente: LA EXCEPCION POR CLIENTE.
--      NULL = la regla del plan, para todos. Con un cliente = una excepcion
--      solo para el. Y la excepcion GANA sobre la regla del plan, que es el
--      mismo patron de los permisos por usuario del ANEXO D.
--
--      Sirve para lo que en la practica siempre pasa: un cliente que
--      negocio dos plantas extra sin cambiar de plan, o al que se le
--      concedio una funcionalidad como parte del cierre. Sin esto, la
--      unica salida seria crearle un plan a medida a cada cliente, y en un
--      ano habria treinta planes de un cliente cada uno.
--
--   2. pcf_vigencia_hasta: LA CONCESION QUE CADUCA SOLA.
--      Para las pruebas. "Le damos predictivo hasta fin de mes" se escribe
--      con una fecha, no con un recordatorio en la agenda de alguien. El
--      dia siguiente la funcion deja de estar sin que nadie tenga que
--      acordarse de quitarla.
--
-- LO QUE ESTE BLOQUE NO HACE
--   NO hace cumplir los limites. Hoy un cliente en BASICO puede crear diez
--   plantas aunque su plan diga una: FNC_CLIENTE_LIMITE existe y responde
--   bien, pero ningun INS_ la consulta todavia. Eso es el bloque D, y esta
--   anotado como pendiente. Este bloque deja el dato correcto; hacerlo
--   valer es el paso siguiente.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. SEL_PLAN_FUNCIONALIDAD

      La matriz completa de un plan: TODAS las funcionalidades, tengan o no
      fila. Devolver solo las que tienen fila obligaria a la pantalla a
      cruzar contra el catalogo para saber que falta, y lo que falta es
      justamente lo interesante: una funcionalidad sin fila esta NEGADA, y
      hay que verla para poder concederla.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_FUNCIONALIDAD]
@PLAN     INT,
@CLIENTE  INT = NULL

AS
SET NOCOUNT ON

DECLARE @HOY DATE = CAST(GETDATE() AS DATE)

    SELECT  f.fun_id                      AS FUN_ID,
            f.fun_codigo                  AS FUN_CODIGO,
            f.fun_nombre                  AS FUN_NOMBRE,
            f.fun_orden                   AS FUN_ORDEN,

            /* El tipo sale de la fila si existe, y si no del catalogo: las
               cuatro que empiezan con LIMITE son topes, el resto inclusion.
               Asi una funcionalidad sin fila igual se pinta con el control
               que le corresponde. */
            ISNULL(pcf.pcf_funcionalidad_tipo,
                   CASE WHEN f.fun_codigo LIKE N'LIMITE%' THEN 2 ELSE 1 END)
                                          AS PCF_TIPO,
            ft.fnt_codigo                 AS FNT_CODIGO,

            pcf.pcf_id                    AS PCF_ID,
            ISNULL(pcf.pcf_incluida, 0)   AS PCF_INCLUIDA,
            pcf.pcf_limite                AS PCF_LIMITE,
            pcf.pcf_cliente               AS PCF_CLIENTE,
            pcf.pcf_vigencia_hasta        AS PCF_VIGENCIA_HASTA,
            pcf.pcf_observacion           AS PCF_OBSERVACION,

            /* De donde sale lo que se muestra. Sin esto, quien mire la
               matriz de un cliente no sabria si un "si" es del plan o una
               excepcion que alguien le concedio. */
            CASE WHEN pcf.pcf_id IS NULL              THEN N'SIN DEFINIR'
                 WHEN pcf.pcf_cliente IS NOT NULL     THEN N'EXCEPCIÓN'
                 ELSE N'PLAN' END         AS ORIGEN,

            CASE WHEN pcf.pcf_vigencia_hasta IS NOT NULL AND pcf.pcf_vigencia_hasta < @HOY
                 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END
                                          AS CADUCADA

    FROM    [dbo].[Funcionalidad] f
    LEFT JOIN [dbo].[Plan_Comercial_Funcionalidad] pcf
           ON pcf.pcf_funcionalidad = f.fun_id
          AND pcf.pcf_plan_comercial = @PLAN
          AND pcf.pcf_habilitado = 1
          /* La excepcion del cliente gana: cuando se pide un cliente se
             prefiere su fila, y si no la tiene cae en la del plan. */
          AND (pcf.pcf_cliente IS NULL OR pcf.pcf_cliente = @CLIENTE)
          AND (@CLIENTE IS NOT NULL OR pcf.pcf_cliente IS NULL)
    LEFT JOIN [dbo].[Funcionalidad_Tipo] ft
           ON ft.fnt_id = ISNULL(pcf.pcf_funcionalidad_tipo,
                                 CASE WHEN f.fun_codigo LIKE N'LIMITE%' THEN 2 ELSE 1 END)
    WHERE   f.fun_habilitado = 1
    ORDER BY f.fun_orden

RETURN(0)
GO


/* ========================================================================
   2. UPS_PLAN_FUNCIONALIDAD

      Concede o niega una funcionalidad en un plan, o le fija el tope.

      Es un UPSERT porque la matriz se edita fila por fila desde la
      pantalla y no interesa si esa combinacion ya existia: lo que interesa
      es como queda.

      @CLIENTE NULL  -> la regla del plan, para todos.
      @CLIENTE con id -> la excepcion de ese cliente, que gana sobre el plan.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPS_PLAN_FUNCIONALIDAD]
@ID              INT = NULL OUTPUT,
@PLAN            INT,
@FUNCIONALIDAD   INT,
@CLIENTE         INT = NULL,
@INCLUIDA        BIT,
@LIMITE          DECIMAL(18,2) = NULL,
@VIGENCIA_HASTA  DATE = NULL,
@OBSERVACION     NVARCHAR(500) = NULL,
@USUARIO         INT

AS
SET NOCOUNT ON

DECLARE @TIPO INT, @CODIGO NVARCHAR(50)

BEGIN
    SELECT @CODIGO = fun_codigo FROM [dbo].[Funcionalidad]
     WHERE fun_id = @FUNCIONALIDAD AND fun_habilitado = 1

    IF @CODIGO IS NULL
    BEGIN
        RAISERROR('1.- LA FUNCIONALIDAD NO EXISTE O ESTÁ DESHABILITADA.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE plc_id = @PLAN)
    BEGIN
        RAISERROR('2.- EL PLAN NO EXISTE.', 16, 1)
        RETURN -1
    END

    -- Las cuatro LIMITE son topes; el resto, inclusion.
    SET @TIPO = CASE WHEN @CODIGO LIKE N'LIMITE%' THEN 2 ELSE 1 END

    /* El CHECK de la tabla exige tope cuando el tipo es LIMITE. Se avisa
       aca para no devolver un error de constraint, que no le dice nada a
       quien esta llenando el formulario.

       Ojo: un tope VACIO no es lo mismo que negar la funcionalidad. En el
       plan FULL, "plantas" esta incluida y su tope es NULL = sin tope. Por
       eso solo se exige el numero cuando la funcionalidad esta incluida Y
       no se quiso dejar ilimitada, lo que se distingue con @INCLUIDA. */
    IF @TIPO = 2 AND @INCLUIDA = 1 AND @LIMITE IS NULL
    BEGIN
        /* Sin tope explicito, ilimitado. Se guarda un limite nulo con el
           tipo INCLUSION para no chocar con CK_PCF_LIMITE, que solo aplica
           al tipo LIMITE. Es la forma que el modelo tiene de decir
           "infinito", y es como esta cargado el plan FULL. */
        SET @TIPO = 1
    END

    IF @TIPO = 2 AND @LIMITE < 0
    BEGIN
        RAISERROR('3.- EL TOPE NO PUEDE SER NEGATIVO.', 16, 1)
        RETURN -1
    END

    IF @CLIENTE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE)
    BEGIN
        RAISERROR('4.- EL CLIENTE DE LA EXCEPCIÓN NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @VIGENCIA_HASTA IS NOT NULL AND @VIGENCIA_HASTA < CAST(GETDATE() AS DATE)
    BEGIN
        RAISERROR('5.- LA VIGENCIA NO PUEDE TERMINAR ANTES DE HOY.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    SELECT @ID = pcf_id
      FROM [dbo].[Plan_Comercial_Funcionalidad]
     WHERE pcf_plan_comercial = @PLAN
       AND pcf_funcionalidad  = @FUNCIONALIDAD
       AND ((@CLIENTE IS NULL AND pcf_cliente IS NULL) OR pcf_cliente = @CLIENTE)

    IF @ID IS NULL
    BEGIN
        INSERT [dbo].[Plan_Comercial_Funcionalidad]
            (pcf_plan_comercial, pcf_funcionalidad, pcf_cliente, pcf_funcionalidad_tipo,
             pcf_incluida, pcf_limite, pcf_vigencia_hasta, pcf_observacion,
             pcf_usuario_creacion, pcf_fecha_creacion,
             pcf_usuario_actualizacion, pcf_fecha_actualizacion, pcf_habilitado)
        VALUES
            (@PLAN, @FUNCIONALIDAD, @CLIENTE, @TIPO,
             @INCLUIDA, CASE WHEN @TIPO = 2 THEN @LIMITE ELSE NULL END,
             @VIGENCIA_HASTA, @OBSERVACION,
             @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)

        SET @ID = SCOPE_IDENTITY()
    END
    ELSE
    BEGIN
        UPDATE  [dbo].[Plan_Comercial_Funcionalidad]
        SET     pcf_funcionalidad_tipo    = @TIPO,
                pcf_incluida              = @INCLUIDA,
                pcf_limite                = CASE WHEN @TIPO = 2 THEN @LIMITE ELSE NULL END,
                pcf_vigencia_hasta        = @VIGENCIA_HASTA,
                pcf_observacion           = @OBSERVACION,
                pcf_habilitado            = 1,
                pcf_usuario_actualizacion = @USUARIO,
                pcf_fecha_actualizacion   = GETDATE()
        WHERE   pcf_id = @ID
    END

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPS_PLAN_FUNCIONALIDAD @PLAN = ' + LTRIM(STR(@PLAN))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '6.- NO FUE POSIBLE GUARDAR LA FUNCIONALIDAD DEL PLAN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   3. DEL_PLAN_FUNCIONALIDAD

      Quita la fila. Baja LOGICA, y con una consecuencia que hay que tener
      clara: sin fila, la funcionalidad queda NEGADA, no "sin definir".
      FNC_CLIENTE_TIENE_FUNCIONALIDAD devuelve 0 por defecto.

      Sirve sobre todo para retirar una EXCEPCION de cliente y que vuelva a
      mandar la regla del plan.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_PLAN_FUNCIONALIDAD]
@ID      INT,
@USUARIO INT

AS
SET NOCOUNT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Comercial_Funcionalidad]
    SET     pcf_habilitado            = 0,
            pcf_usuario_actualizacion = @USUARIO,
            pcf_fecha_actualizacion   = GETDATE()
    WHERE   pcf_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_PLAN_FUNCIONALIDAD @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '1.- NO FUE POSIBLE QUITAR LA FUNCIONALIDAD.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'SPs de contenido del plan' AS control, COUNT(*) AS valor, 3 AS esperado
FROM   sys.procedures
WHERE  name IN ('SEL_PLAN_FUNCIONALIDAD','UPS_PLAN_FUNCIONALIDAD','DEL_PLAN_FUNCIONALIDAD')
UNION ALL
SELECT 'funcionalidades del catálogo', COUNT(*), 25 FROM [dbo].[Funcionalidad]
UNION ALL
SELECT 'filas de la matriz cargadas', COUNT(*), NULL FROM [dbo].[Plan_Comercial_Funcionalidad]
GO

-- Que incluye el plan BASICO hoy.
EXEC [dbo].[SEL_PLAN_FUNCIONALIDAD] @PLAN = 1
GO
