USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  04-09-2026
-- DESCRIPTION:     LO QUE LA APP ESCRIBE DESDE TERRENO (HU-043 y HU-044).
-- =============================================
-- POR QUE EXISTE ESTE BLOQUE
--
--   La app ya sabe LEER (bloque 140, la sabana) pero no tenia como ESCRIBIR
--   lo unico que solo se captura en terreno: la lectura de un medidor y la
--   medicion de una variable de condicion.
--
-- NO HAY SENSORES
--
--   En SIGMA ningun activo reporta solo. Cada valor lo lee una persona en su
--   ronda y lo escribe en el telefono. Por eso:
--     · el origen por omision es MANUAL, no SENSOR;
--     · el modo de entrada por omision es TECLADO;
--     · se guarda QUIEN lo tomo y CUANDO, porque un numero sin dueño no se
--       puede auditar.
--
-- IDEMPOTENCIA POR UUID
--
--   Igual que INS_INVENTARIO_MOVIMIENTO. El telefono genera el uuid AL
--   ENCOLAR, no al enviar: generado al enviar, cada reintento traeria uno
--   nuevo y la idempotencia no serviria de nada — que es justo el caso del
--   timeout, donde el servidor si grabo pero la respuesta no llego.
--
--   La comprobacion va ANTES de las validaciones: un reintento no tiene por
--   que volver a pasar por reglas que ya paso.
--
-- LA FECHA ES LA DE CAPTURA, NO LA DEL ENVIO
--
--   Una lectura tomada a las 09:00 y enviada a las 18:00 es de las 09:00.
--   @FECHA_LECTURA_UTC la manda la app; @*_fecha_creacion la pone el
--   servidor. Son dos cosas distintas y se guardan las dos.
-- =============================================

-- =============================================================
-- HU-043 · LECTURA DE MEDIDOR
-- =============================================================
CREATE OR ALTER PROCEDURE [dbo].[API_INS_ACTIVO_MEDIDOR_LECTURA]
     @ID                 INT OUTPUT
    ,@CLIENTE            INT
    ,@ACTIVO_MEDIDOR     INT
    ,@VALOR_ACUMULADO    DECIMAL(18,4)
    ,@FECHA_LECTURA_UTC  DATETIME       = NULL
    ,@ES_REINICIO        BIT            = 0
    ,@ORDEN_TRABAJO      INT            = NULL
    ,@OBSERVACION        NVARCHAR(1000) = NULL
    ,@ENTRADA_MODO       INT            = NULL
    ,@UUID               UNIQUEIDENTIFIER = NULL
    ,@USUARIO            INT
AS
SET NOCOUNT ON

DECLARE  @AHORA           DATETIME = GETUTCDATE()
        ,@VALOR_ACTUAL    DECIMAL(18,4)
        ,@PERMITE_REINICIO BIT
        ,@MSG             NVARCHAR(500)

/* ---- Idempotencia ---- */
IF (@UUID IS NOT NULL)
BEGIN
    /* NULL a la fuerza: un SELECT sin filas NO toca la variable, y el
       llamador manda 0. Sin esto, TODA lectura con uuid responderia "ya
       estaba registrada" y no se guardaria nada. */
    SET @ID = NULL

    SELECT @ID = aml_id FROM [dbo].[Activo_Medidor_Lectura] WHERE aml_uuid = @UUID

    IF (@ID IS NOT NULL)
    BEGIN
        SELECT @ID [ID], '200' [CODE], 'La lectura ya estaba registrada.' [MENSAJE]
        RETURN 0
    END
END

SET @UUID = ISNULL(@UUID, NEWID())

/* La fecha de captura la manda la app. Si no viene, es de ahora: pero eso
   solo pasa si la registro estando en linea. */
SET @FECHA_LECTURA_UTC = ISNULL(@FECHA_LECTURA_UTC, @AHORA)

/* ---- El medidor tiene que ser del cliente ---- */
SELECT   @VALOR_ACTUAL     = AME.ame_valor_actual
        ,@PERMITE_REINICIO = AME.ame_permite_reinicio
FROM     [dbo].[Activo_Medidor] AME
WHERE    AME.ame_id         = @ACTIVO_MEDIDOR
AND      AME.ame_cliente    = @CLIENTE
AND      AME.ame_habilitado = 1

IF (@VALOR_ACTUAL IS NULL AND NOT EXISTS (
        SELECT 1 FROM [dbo].[Activo_Medidor]
         WHERE ame_id = @ACTIVO_MEDIDOR AND ame_cliente = @CLIENTE AND ame_habilitado = 1))
BEGIN
    RAISERROR('1.- EL MEDIDOR NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

/* ---- El valor ---- */
IF (@VALOR_ACUMULADO IS NULL OR @VALOR_ACUMULADO < 0)
BEGIN
    RAISERROR('2.- LA LECTURA DEBE SER UN VALOR POSITIVO.', 16, 1)
    RETURN -1
END

/* Un horometro no retrocede. Si el valor es menor que el ultimo, o el
   medidor se reinicio —y hay que declararlo— o alguien tecleo mal.
   Rechazarlo en silencio perderia la lectura; aceptarlo sin marcar
   descuadraria el acumulado y todas las proyecciones de mantenimiento que
   dependen de el. */
IF (@ES_REINICIO = 0 AND @VALOR_ACTUAL IS NOT NULL AND @VALOR_ACUMULADO < @VALOR_ACTUAL)
BEGIN
    SET @MSG = '3.- LA LECTURA (' + LTRIM(STR(@VALOR_ACUMULADO, 18, 2)) +
               ') ES MENOR QUE LA ULTIMA REGISTRADA (' +
               LTRIM(STR(@VALOR_ACTUAL, 18, 2)) +
               '). SI EL MEDIDOR SE REINICIO, MARCALO COMO REINICIO.'
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END

IF (@ES_REINICIO = 1 AND ISNULL(@PERMITE_REINICIO, 0) = 0)
BEGIN
    RAISERROR('4.- ESTE MEDIDOR NO ADMITE REINICIO.', 16, 1)
    RETURN -1
END

/* Una lectura del futuro es un reloj mal puesto. Se tolera una hora de
   desfase: el telefono puede ir corrido unos minutos y eso no es un error. */
IF (@FECHA_LECTURA_UTC > DATEADD(HOUR, 1, @AHORA))
BEGIN
    RAISERROR('5.- LA FECHA DE LA LECTURA ESTA EN EL FUTURO. REVISA LA HORA DEL DISPOSITIVO.', 16, 1)
    RETURN -1
END

BEGIN TRY
    SET XACT_ABORT ON
    BEGIN TRANSACTION

        INSERT [dbo].[Activo_Medidor_Lectura]
            (aml_uuid, aml_cliente, aml_activo_medidor, aml_fecha_lectura_utc,
             aml_valor_acumulado, aml_es_reinicio, aml_dato_origen,
             aml_medicion_calidad, aml_entrada_modo, aml_orden_trabajo,
             aml_observacion, aml_usuario_creacion, aml_fecha_creacion)
        VALUES
            (@UUID, @CLIENTE, @ACTIVO_MEDIDOR, @FECHA_LECTURA_UTC,
             @VALOR_ACUMULADO, @ES_REINICIO,
             3,   -- MANUAL: no hay sensores, lo escribio una persona
             1,   -- VALIDA
             ISNULL(@ENTRADA_MODO, 1),  -- TECLADO
             @ORDEN_TRABAJO, @OBSERVACION, @USUARIO, @AHORA)

        SET @ID = SCOPE_IDENTITY()

        /* El valor actual del medidor es una denormalizacion controlada: la
           ficha y las programaciones por medidor lo leen mil veces y buscar
           el maximo del historial en cada una seria caro.

           Solo se adelanta si esta lectura es mas nueva que la que hay: una
           lectura vieja que llega tarde —encolada sin señal— no puede
           retroceder el contador. */
        UPDATE  [dbo].[Activo_Medidor]
        SET     ame_valor_actual           = @VALOR_ACUMULADO
               ,ame_fecha_valor_actual_utc = @FECHA_LECTURA_UTC
               ,ame_usuario_actualizacion  = @USUARIO
               ,ame_fecha_actualizacion    = @AHORA
        WHERE   ame_id = @ACTIVO_MEDIDOR
        AND     (ame_fecha_valor_actual_utc IS NULL
                 OR ame_fecha_valor_actual_utc <= @FECHA_LECTURA_UTC)

    COMMIT TRANSACTION

    SELECT @ID [ID], '200' [CODE], 'Lectura registrada.' [MENSAJE]
    RETURN 0
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
    SET @MSG = ERROR_MESSAGE()
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END CATCH
GO


-- =============================================================
-- HU-044 · MEDICION DE CONDICION
-- =============================================================
CREATE OR ALTER PROCEDURE [dbo].[API_INS_ACTIVO_MEDICION]
     @ID                  INT OUTPUT
    ,@CLIENTE             INT
    ,@ACTIVO_VARIABLE     INT
    ,@VALOR               DECIMAL(18,4)
    ,@FECHA_MEDICION_UTC  DATETIME       = NULL
    ,@UNIDAD_MEDIDA       INT            = NULL
    ,@ACTIVO_COMPONENTE   INT            = NULL
    ,@ORDEN_TRABAJO       INT            = NULL
    ,@OBSERVACION         NVARCHAR(1000) = NULL
    ,@ENTRADA_MODO        INT            = NULL
    ,@UUID                UNIQUEIDENTIFIER = NULL
    ,@USUARIO             INT
AS
SET NOCOUNT ON

DECLARE  @AHORA            DATETIME = GETUTCDATE()
        ,@ACTIVO           INT
        ,@UNIDAD_VARIABLE  INT
        ,@FACTOR           DECIMAL(18,8)
        ,@OFFSET           DECIMAL(18,8)
        ,@UNIDAD_BASE      INT
        ,@VALOR_CANONICO   DECIMAL(18,4)
        ,@MSG              NVARCHAR(500)

/* ---- Idempotencia ---- */
IF (@UUID IS NOT NULL)
BEGIN
    SET @ID = NULL

    SELECT @ID = amd_id FROM [dbo].[Activo_Medicion] WHERE amd_uuid = @UUID

    IF (@ID IS NOT NULL)
    BEGIN
        SELECT @ID [ID], '200' [CODE], 'La medicion ya estaba registrada.' [MENSAJE]
        RETURN 0
    END
END

SET @UUID = ISNULL(@UUID, NEWID())
SET @FECHA_MEDICION_UTC = ISNULL(@FECHA_MEDICION_UTC, @AHORA)

/* ---- La variable tiene que ser del cliente ---- */
SELECT   @ACTIVO          = AVA.ava_activo
        ,@UNIDAD_VARIABLE = AVA.ava_unidad_medida
FROM     [dbo].[Activo_Variable] AVA
WHERE    AVA.ava_id         = @ACTIVO_VARIABLE
AND      AVA.ava_cliente    = @CLIENTE
AND      AVA.ava_habilitado = 1

IF (@ACTIVO IS NULL)
BEGIN
    RAISERROR('1.- LA VARIABLE NO EXISTE O NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@VALOR IS NULL)
BEGIN
    RAISERROR('2.- LA MEDICION NECESITA UN VALOR.', 16, 1)
    RETURN -1
END

IF (@FECHA_MEDICION_UTC > DATEADD(HOUR, 1, @AHORA))
BEGIN
    RAISERROR('3.- LA FECHA DE LA MEDICION ESTA EN EL FUTURO. REVISA LA HORA DEL DISPOSITIVO.', 16, 1)
    RETURN -1
END

/* La unidad en que se midio. Si la app no la manda, es la de la variable:
   es lo que la pantalla mostro al lado del campo. */
SET @UNIDAD_MEDIDA = ISNULL(@UNIDAD_MEDIDA, @UNIDAD_VARIABLE)

/* ---- El valor canonico ----
   Se guarda el valor tal como lo escribio la persona Y su equivalente en la
   unidad base de la magnitud. Sin el canonico, comparar una serie donde
   alguien midio en °C y otro en K obliga a convertir en cada consulta, y la
   conversion terminaria escrita en tres lugares distintos. */
SELECT   @FACTOR      = UME.ume_factor
        ,@OFFSET      = UME.ume_offset
        ,@UNIDAD_BASE = ISNULL(UME.ume_unidad_base, UME.ume_id)
FROM     [dbo].[Unidad_Medida] UME
WHERE    UME.ume_id = @UNIDAD_MEDIDA

IF (@FACTOR IS NULL)
BEGIN
    RAISERROR('4.- LA UNIDAD DE MEDIDA NO EXISTE.', 16, 1)
    RETURN -1
END

SET @VALOR_CANONICO = (@VALOR * @FACTOR) + ISNULL(@OFFSET, 0)

BEGIN TRY
    SET XACT_ABORT ON
    BEGIN TRANSACTION

        INSERT [dbo].[Activo_Medicion]
            (amd_uuid, amd_cliente, amd_activo_variable, amd_activo,
             amd_activo_componente, amd_fecha_medicion_utc, amd_valor,
             amd_unidad_medida, amd_valor_canonico, amd_unidad_canonica,
             amd_medicion_calidad, amd_dato_origen, amd_entrada_modo,
             amd_orden_trabajo, amd_observacion,
             amd_usuario_creacion, amd_fecha_creacion)
        VALUES
            (@UUID, @CLIENTE, @ACTIVO_VARIABLE, @ACTIVO,
             @ACTIVO_COMPONENTE, @FECHA_MEDICION_UTC, @VALOR,
             @UNIDAD_MEDIDA, @VALOR_CANONICO, @UNIDAD_BASE,
             1,   -- VALIDA
             3,   -- MANUAL: no hay sensores
             ISNULL(@ENTRADA_MODO, 1),  -- TECLADO
             @ORDEN_TRABAJO, @OBSERVACION, @USUARIO, @AHORA)

        SET @ID = SCOPE_IDENTITY()

    COMMIT TRANSACTION

    /* El veredicto contra los umbrales lo devuelve el SP, no la pantalla:
       la web y el telefono tienen que decir lo mismo sobre si un valor esta
       fuera de rango. */
    SELECT   @ID [ID]
            ,'200' [CODE]
            ,CASE
                WHEN AVA.ava_valor_critico IS NOT NULL
                 AND @VALOR >= AVA.ava_valor_critico
                    THEN 'Medicion registrada. VALOR CRITICO: supera el umbral definido.'
                WHEN AVA.ava_valor_advertencia IS NOT NULL
                 AND @VALOR >= AVA.ava_valor_advertencia
                    THEN 'Medicion registrada. Valor en advertencia.'
                WHEN (AVA.ava_valor_minimo IS NOT NULL AND @VALOR < AVA.ava_valor_minimo)
                  OR (AVA.ava_valor_maximo IS NOT NULL AND @VALOR > AVA.ava_valor_maximo)
                    THEN 'Medicion registrada. Valor fuera del rango operativo.'
                ELSE 'Medicion registrada.'
             END [MENSAJE]
    FROM     [dbo].[Activo_Variable] AVA
    WHERE    AVA.ava_id = @ACTIVO_VARIABLE

    RETURN 0
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
    SET @MSG = ERROR_MESSAGE()
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END CATCH
GO

PRINT 'API_INS_ACTIVO_MEDIDOR_LECTURA y API_INS_ACTIVO_MEDICION creados.'
GO
