USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  16-09-2026
-- DESCRIPTION:     LAS REGLAS QUE FALTABAN DE HU-043 Y HU-044 EN LA CAPTURA
--                  DE TERRENO, EN EL SP Y NO EN LA PANTALLA.
-- =============================================
-- HU-043 #2 · SALTO NO RAZONABLE
--   Activo_Medidor gana ame_maximo_diario (lo que el medidor puede avanzar por
--   dia; NULL = sin control). Una lectura que salta mas que maximo x dias
--   desde la anterior se ACEPTA -es lo que la persona leyo- pero queda con
--   Medicion_Calidad 5 PENDIENTE REVISION y abre una alerta LECTURA A REVISAR
--   (tipo nuevo), que es el informe de lecturas a revisar.
--
-- HU-044 #1 · UNIDAD DISTINTA
--   El veredicto contra los umbrales se toma sobre el EQUIVALENTE en la unidad
--   de la variable (vuelto desde el canonico), no sobre el numero tecleado.
--   El valor original y su unidad se siguen guardando tal cual.
--
-- HU-044 #2 · FUERA DE UMBRAL
--   Sin comentario, se rechaza: «indique un comentario con lo que observo».
--   Con comentario, se registra y abre una alerta MEDICION FUERA RANGO con
--   severidad segun el nivel. Ambos SP parten del bloque 141 (+ el origen
--   ORDEN TRABAJO del 233) y se recrean completos.
-- =============================================

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[dbo].[Activo_Medidor]') AND name = 'ame_maximo_diario')
    ALTER TABLE [dbo].[Activo_Medidor] ADD ame_maximo_diario DECIMAL(18,4) NULL
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[Medicion_Calidad] WHERE mca_codigo = 'PENDIENTE REVISION')
    INSERT [dbo].[Medicion_Calidad] (mca_codigo, mca_nombre, mca_orden, mca_habilitado)
    VALUES ('PENDIENTE REVISION', 'Pendiente de revisión', 5, 1)
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'LECTURA A REVISAR')
    INSERT [dbo].[Alerta_Tipo] (alt_codigo, alt_nombre, alt_orden, alt_habilitado, alt_permiso, alt_icono, alt_menu_link, alt_ficha_link, alt_ficha_id_columna)
    VALUES ('LECTURA A REVISAR', 'Lectura de medidor a revisar', 14, 1, 111, 'mdi mdi-speedometer-slow',
            '~/View/Activos/Activos/Activos.aspx', '~/View/Activos/Activos/Activo.aspx', 'ale_activo')
GO

/* Que el listado de medidores diga el maximo diario (SEL del bloque 77,
   parche sobre la definicion vigente, idempotente). */
DECLARE @SQL NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.SEL_ACTIVO_MEDIDOR'))
IF @SQL IS NOT NULL AND @SQL NOT LIKE '%AME_MAXIMO_DIARIO%'
BEGIN
    SET @SQL = REPLACE(@SQL, ',ame.ame_permite_reinicio       AS AME_PERMITE_REINICIO',
                             ',ame.ame_permite_reinicio       AS AME_PERMITE_REINICIO' + CHAR(13) + CHAR(10) +
                             '       ,ame.ame_maximo_diario          AS AME_MAXIMO_DIARIO')
    SET @SQL = REPLACE(REPLACE(REPLACE(REPLACE(@SQL, 'CREATE OR ALTER PROCEDURE', 'ALTER PROCEDURE'),
        'CREATE   PROCEDURE', 'ALTER PROCEDURE'), 'CREATE  PROCEDURE', 'ALTER PROCEDURE'), 'CREATE PROCEDURE', 'ALTER PROCEDURE')
    EXEC sp_executesql @SQL
    PRINT '--- SEL_ACTIVO_MEDIDOR devuelve AME_MAXIMO_DIARIO'
END
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO_MEDIDOR_MAXIMO_DIARIO]
@ID             INT,
@MAXIMO_DIARIO  DECIMAL(18,4) = NULL,
@USUARIO        INT
AS
SET NOCOUNT ON
    UPDATE [dbo].[Activo_Medidor]
    SET    ame_maximo_diario = @MAXIMO_DIARIO
          ,ame_usuario_actualizacion = @USUARIO
          ,ame_fecha_actualizacion = [dbo].[FNC_AHORA]()
    WHERE  ame_id = @ID
RETURN(0)
GO

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
        /* HU-043 #2: el maximo que el medidor puede avanzar por dia. Un salto
           mayor no se rechaza -la lectura es real- pero queda PENDIENTE DE
           REVISION y avisa. */
        ,@MAXIMO_DIARIO   DECIMAL(18,4)
        ,@FECHA_ACTUAL    DATETIME
        ,@ACTIVO          INT
        ,@CALIDAD         INT = 1
        ,@SALTO           DECIMAL(18,4)
        ,@DIAS            DECIMAL(18,4)
        ,@MENSAJE         NVARCHAR(500) = 'Lectura registrada.'

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
        ,@MAXIMO_DIARIO    = AME.ame_maximo_diario
        ,@FECHA_ACTUAL     = AME.ame_fecha_valor_actual_utc
        ,@ACTIVO           = AME.ame_activo
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

/* ---- Salto no razonable (HU-043 #2) ----
   Con un maximo diario definido, un avance mayor que maximo x dias desde la
   ultima lectura no se rechaza: la persona esta frente al medidor y lo que
   lee es real. Se guarda, queda PENDIENTE DE REVISION (Medicion_Calidad 5)
   y se abre una alerta LECTURA A REVISAR para el informe. Un dia como
   minimo: dos lecturas el mismo dia se comparan contra un dia entero. */
IF (@ES_REINICIO = 0 AND @MAXIMO_DIARIO IS NOT NULL AND @MAXIMO_DIARIO > 0
    AND @VALOR_ACTUAL IS NOT NULL)
BEGIN
    SET @SALTO = @VALOR_ACUMULADO - @VALOR_ACTUAL
    SET @DIAS  = CASE WHEN @FECHA_ACTUAL IS NULL THEN 1
                      ELSE CEILING(DATEDIFF(MINUTE, @FECHA_ACTUAL, @FECHA_LECTURA_UTC) / 1440.0) END
    IF (@DIAS < 1) SET @DIAS = 1

    IF (@SALTO > @MAXIMO_DIARIO * @DIAS)
    BEGIN
        SET @CALIDAD = 5
        SET @MENSAJE = 'Lectura registrada. El salto de ' + LTRIM(STR(@SALTO, 18, 1)) +
                       ' en ' + LTRIM(STR(@DIAS, 18, 0)) + ' dia(s) supera el maximo diario (' +
                       LTRIM(STR(@MAXIMO_DIARIO, 18, 1)) + '): queda pendiente de revision.'
    END
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
             CASE WHEN @ORDEN_TRABAJO IS NOT NULL THEN 4 ELSE 3 END,   -- ORDEN TRABAJO o MANUAL
             @CALIDAD,   -- 1 VALIDA · 5 PENDIENTE REVISION (salto no razonable)
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

        /* La alerta que alimenta el informe de lecturas a revisar. */
        IF (@CALIDAD = 5)
            INSERT INTO [dbo].[Alerta]
                (ale_uuid, ale_cliente, ale_cliente_instalacion, ale_alerta_tipo, ale_alerta_estado, ale_severidad,
                 ale_titulo, ale_descripcion, ale_fecha_deteccion_utc, ale_activo, ale_activo_medidor,
                 ale_valor_observado, ale_valor_umbral, ale_unidad_medida,
                 ale_fecha_primera_ocurrencia_utc, ale_fecha_ultima_ocurrencia_utc, ale_ocurrencias,
                 ale_usuario_creacion, ale_fecha_creacion, ale_habilitado)
            SELECT  NEWID(), @CLIENTE, ACT.act_cliente_instalacion,
                    (SELECT alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'LECTURA A REVISAR'), 1, 3,
                    'Lectura a revisar en ' + AME.ame_nombre,
                    'El medidor ' + AME.ame_codigo + ' de ' + ACT.act_codigo + ' avanzo ' + LTRIM(STR(@SALTO, 18, 1)) +
                    ' en ' + LTRIM(STR(@DIAS, 18, 0)) + ' dia(s); el maximo diario es ' + LTRIM(STR(@MAXIMO_DIARIO, 18, 1)) + '.',
                    @AHORA, @ACTIVO, @ACTIVO_MEDIDOR,
                    @SALTO, @MAXIMO_DIARIO * @DIAS, AME.ame_unidad_medida,
                    @AHORA, @AHORA, 1,
                    @USUARIO, @AHORA, 1
            FROM    [dbo].[Activo_Medidor] AME
            JOIN    [dbo].[Activo] ACT ON ACT.act_id = AME.ame_activo
            WHERE   AME.ame_id = @ACTIVO_MEDIDOR

    COMMIT TRANSACTION

    SELECT @ID [ID], '200' [CODE], @MENSAJE [MENSAJE]
    RETURN 0
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
    SET @MSG = ERROR_MESSAGE()
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END CATCH
GO

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
        /* HU-044 #1: el veredicto se toma sobre el equivalente en la unidad
           de la variable, que es la de los umbrales. */
        ,@FACTOR_VAR       DECIMAL(18,8)
        ,@OFFSET_VAR       DECIMAL(18,8)
        ,@VALOR_VAR        DECIMAL(18,4)
        ,@MIN              DECIMAL(18,4)
        ,@MAX              DECIMAL(18,4)
        ,@ADV              DECIMAL(18,4)
        ,@CRI              DECIMAL(18,4)
        ,@NIVEL            NVARCHAR(20) = 'NORMAL'
        ,@UMBRAL           DECIMAL(18,4)
        ,@SEVERIDAD        INT
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
        ,@MIN = AVA.ava_valor_minimo, @MAX = AVA.ava_valor_maximo
        ,@ADV = AVA.ava_valor_advertencia, @CRI = AVA.ava_valor_critico
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

/* ---- El equivalente en la unidad de la variable (HU-044 #1) ----
   Los umbrales estan en la unidad de la variable. Si se midio en otra (PSI
   con la variable en bar) se compara el equivalente, no el numero tecleado:
   45 PSI no son 45 bar. */
SELECT @FACTOR_VAR = ISNULL(ume_factor, 1), @OFFSET_VAR = ISNULL(ume_offset, 0)
FROM   [dbo].[Unidad_Medida] WHERE ume_id = @UNIDAD_VARIABLE
SET @VALOR_VAR = CASE WHEN @UNIDAD_MEDIDA = @UNIDAD_VARIABLE OR ISNULL(@FACTOR_VAR, 0) = 0 THEN @VALOR
                      ELSE (@VALOR_CANONICO - ISNULL(@OFFSET_VAR, 0)) / @FACTOR_VAR END

SET @NIVEL = CASE
    WHEN @CRI IS NOT NULL AND @VALOR_VAR >= @CRI THEN 'CRITICO'
    WHEN @ADV IS NOT NULL AND @VALOR_VAR >= @ADV THEN 'ADVERTENCIA'
    WHEN (@MIN IS NOT NULL AND @VALOR_VAR < @MIN) OR (@MAX IS NOT NULL AND @VALOR_VAR > @MAX) THEN 'FUERA_RANGO'
    ELSE 'NORMAL' END

/* ---- Fuera de umbral: se pide un comentario (HU-044 #2) ----
   Un valor critico sin una linea de contexto -que se vio, que se hizo- es
   un numero que despues nadie sabe interpretar. */
IF (@NIVEL <> 'NORMAL' AND (@OBSERVACION IS NULL OR LTRIM(RTRIM(@OBSERVACION)) = ''))
BEGIN
    SET @UMBRAL = CASE @NIVEL WHEN 'CRITICO' THEN @CRI WHEN 'ADVERTENCIA' THEN @ADV
                              WHEN 'FUERA_RANGO' THEN CASE WHEN @MIN IS NOT NULL AND @VALOR_VAR < @MIN THEN @MIN ELSE @MAX END END
    SET @MSG = '5.- EL VALOR (' + LTRIM(STR(@VALOR_VAR, 18, 2)) + ') ESTA FUERA DE UMBRAL (' +
               LTRIM(STR(@UMBRAL, 18, 2)) + '): INDIQUE UN COMENTARIO CON LO QUE OBSERVO.'
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END

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
             CASE WHEN @ORDEN_TRABAJO IS NOT NULL THEN 4 ELSE 3 END,   -- ORDEN TRABAJO o MANUAL
             ISNULL(@ENTRADA_MODO, 1),  -- TECLADO
             @ORDEN_TRABAJO, @OBSERVACION, @USUARIO, @AHORA)

        SET @ID = SCOPE_IDENTITY()

        /* ---- La alerta (HU-044 #2) ----
           MEDICION FUERA RANGO, con severidad segun el nivel: critico 4,
           advertencia 3, fuera del rango operativo 2. Va a la bandeja de
           alertas y a la ficha del activo. */
        IF (@NIVEL <> 'NORMAL')
        BEGIN
            SET @SEVERIDAD = CASE @NIVEL WHEN 'CRITICO' THEN 4 WHEN 'ADVERTENCIA' THEN 3 ELSE 2 END
            SET @UMBRAL = CASE @NIVEL WHEN 'CRITICO' THEN @CRI WHEN 'ADVERTENCIA' THEN @ADV
                                      ELSE CASE WHEN @MIN IS NOT NULL AND @VALOR_VAR < @MIN THEN @MIN ELSE @MAX END END
            INSERT INTO [dbo].[Alerta]
                (ale_uuid, ale_cliente, ale_cliente_instalacion, ale_alerta_tipo, ale_alerta_estado, ale_severidad,
                 ale_titulo, ale_descripcion, ale_fecha_deteccion_utc, ale_activo, ale_activo_componente,
                 ale_valor_observado, ale_valor_umbral, ale_unidad_medida,
                 ale_fecha_primera_ocurrencia_utc, ale_fecha_ultima_ocurrencia_utc, ale_ocurrencias,
                 ale_usuario_creacion, ale_fecha_creacion, ale_habilitado)
            SELECT  NEWID(), @CLIENTE, ACT.act_cliente_instalacion,
                    (SELECT alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'MEDICION FUERA RANGO'), 1, @SEVERIDAD,
                    VME.vme_nombre + ' ' + CASE @NIVEL WHEN 'CRITICO' THEN 'en nivel critico' WHEN 'ADVERTENCIA' THEN 'en advertencia' ELSE 'fuera del rango operativo' END +
                    ' en ' + ACT.act_codigo,
                    'Se midio ' + LTRIM(STR(@VALOR_VAR, 18, 2)) + ' ' + ISNULL(UME.ume_simbolo, '') +
                    ' contra un umbral de ' + LTRIM(STR(@UMBRAL, 18, 2)) + ' ' + ISNULL(UME.ume_simbolo, '') +
                    '. ' + ISNULL(@OBSERVACION, ''),
                    @FECHA_MEDICION_UTC, @ACTIVO, @ACTIVO_COMPONENTE,
                    @VALOR_VAR, @UMBRAL, @UNIDAD_VARIABLE,
                    @FECHA_MEDICION_UTC, @FECHA_MEDICION_UTC, 1,
                    @USUARIO, @AHORA, 1
            FROM    [dbo].[Activo] ACT
            JOIN    [dbo].[Activo_Variable] AVA ON AVA.ava_id = @ACTIVO_VARIABLE
            JOIN    [dbo].[Variable_Medicion] VME ON VME.vme_id = AVA.ava_variable_medicion
       LEFT JOIN    [dbo].[Unidad_Medida] UME ON UME.ume_id = @UNIDAD_VARIABLE
            WHERE   ACT.act_id = @ACTIVO
        END

    COMMIT TRANSACTION

    /* El veredicto contra los umbrales lo devuelve el SP, no la pantalla:
       la web y el telefono tienen que decir lo mismo sobre si un valor esta
       fuera de rango. */
    SELECT   @ID [ID]
            ,'200' [CODE]
            ,CASE @NIVEL
                WHEN 'CRITICO'     THEN 'Medicion registrada. VALOR CRITICO: supera el umbral definido.'
                WHEN 'ADVERTENCIA' THEN 'Medicion registrada. Valor en advertencia.'
                WHEN 'FUERA_RANGO' THEN 'Medicion registrada. Valor fuera del rango operativo.'
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

PRINT '--- Captura de terreno: reglas de HU-043 y HU-044 en el SP'
GO
