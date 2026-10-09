/* ============================================================================
   390 · Calendario e intervalo: reactivar la regla deshabilitada · 09-10-2026

   Al cambiar el tipo de frecuencia, UPS_PLAN_HITO_FRECUENCIA (BD/384) deja la
   regla anterior en pca_habilitado / pin_habilitado = 0 en vez de borrarla.
   Los índices únicos UX_PCA_PROGRAMACION y UX_PIN_PROGRAMACION son por
   programación sin filtro, así que al volver a «Calendario» o «Intervalo» el
   UPSERT no veía la fila (buscaba solo habilitadas), intentaba insertar y
   fallaba: «Violation of UNIQUE KEY constraint 'UX_PCA_PROGRAMACION'».
   Ahora el UPSERT toma la fila de la programación aunque esté deshabilitada y
   la reactiva al actualizarla. El resto de ambos SP no cambia (BD/104).
   ============================================================================ */
CREATE OR ALTER PROCEDURE [dbo].[UPS_PROGRAMACION_CALENDARIO]
    @ID             INT = NULL OUTPUT,
    @PROGRAMACION   INT,
    @CLIENTE        INT,
    @FRECUENCIA     INT,
    @INTERVALO      INT = 1,
    @SEMANA_ORDINAL INT = NULL,
    @DIA_MES        INT = NULL,
    @MES            INT = NULL,
    @HORA_LOCAL     TIME,
    @DIAS           VARCHAR(100) = NULL,
    @USUARIO        INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME, @FREC NVARCHAR(100), @NDIAS INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

SELECT @FREC = fre_codigo FROM [dbo].[Frecuencia_Tipo] WHERE fre_id = @FRECUENCIA

IF (@FREC IS NULL)
BEGIN
    RAISERROR('2.- LA FRECUENCIA NO EXISTE.', 16, 1)
    RETURN -1
END

IF (ISNULL(@INTERVALO, 0) < 1)
BEGIN
    RAISERROR('3.- EL INTERVALO DEBE SER 1 O MAYOR.', 16, 1)
    RETURN -1
END

IF (@HORA_LOCAL IS NULL)
BEGIN
    RAISERROR('4.- INDIQUE LA HORA LOCAL DE LA OCURRENCIA.', 16, 1)
    RETURN -1
END

/* -1 es "el ultimo". Cualquier otro valor fuera de rango es un dato que
   despues no proyecta ninguna fecha y nadie sabe por que. */
IF (@DIA_MES IS NOT NULL AND @DIA_MES <> -1 AND (@DIA_MES < 1 OR @DIA_MES > 31))
BEGIN
    RAISERROR('5.- EL DIA DEL MES DEBE ESTAR ENTRE 1 Y 31, O -1 PARA EL ULTIMO.', 16, 1)
    RETURN -1
END

IF (@SEMANA_ORDINAL IS NOT NULL AND @SEMANA_ORDINAL <> -1 AND (@SEMANA_ORDINAL < 1 OR @SEMANA_ORDINAL > 4))
BEGIN
    RAISERROR('6.- EL ORDINAL DE SEMANA DEBE ESTAR ENTRE 1 Y 4, O -1 PARA LA ULTIMA.', 16, 1)
    RETURN -1
END

IF (@MES IS NOT NULL AND (@MES < 1 OR @MES > 12))
BEGIN
    RAISERROR('7.- EL MES DEBE ESTAR ENTRE 1 Y 12.', 16, 1)
    RETURN -1
END

SET @NDIAS = 0
IF (@DIAS IS NOT NULL AND LEN(LTRIM(RTRIM(@DIAS))) > 0)
    SELECT @NDIAS = COUNT(*) FROM [dbo].[SPLIT](@DIAS, ',')
     WHERE LTRIM(RTRIM(value)) <> ''

/* Cada frecuencia necesita datos distintos. Sin esto se guarda una regla
   incompleta que simplemente no produce fechas, y el usuario cree que el
   sistema no funciona. */
IF (@FREC = 'SEMANAL' AND @NDIAS = 0)
BEGIN
    RAISERROR('8.- UNA REPETICION SEMANAL NECESITA AL MENOS UN DIA DE LA SEMANA.', 16, 1)
    RETURN -1
END

IF (@FREC = 'MENSUAL' AND @DIA_MES IS NULL AND (@SEMANA_ORDINAL IS NULL OR @NDIAS = 0))
BEGIN
    RAISERROR('9.- UNA REPETICION MENSUAL NECESITA EL DIA DEL MES, O EL ORDINAL DE SEMANA MAS UN DIA.', 16, 1)
    RETURN -1
END

IF (@FREC = 'ANUAL' AND @MES IS NULL)
BEGIN
    RAISERROR('10.- UNA REPETICION ANUAL NECESITA EL MES.', 16, 1)
    RETURN -1
END

IF (@FREC = 'ANUAL' AND @DIA_MES IS NULL AND (@SEMANA_ORDINAL IS NULL OR @NDIAS = 0))
BEGIN
    RAISERROR('11.- UNA REPETICION ANUAL NECESITA EL DIA DEL MES, O EL ORDINAL DE SEMANA MAS UN DIA.', 16, 1)
    RETURN -1
END

IF (@NDIAS > 0 AND EXISTS (SELECT 1 FROM [dbo].[SPLIT](@DIAS, ',')
                            WHERE LTRIM(RTRIM(value)) <> ''
                              AND NOT EXISTS (SELECT 1 FROM [dbo].[Dia_Semana]
                                               WHERE dse_id = TRY_CAST(LTRIM(RTRIM(value)) AS INT))))
BEGIN
    RAISERROR('12.- UNO DE LOS DIAS DE LA SEMANA NO ES VALIDO.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    /* SET a NULL primero: un SELECT @V = col que no encuentra filas DEJA @V
       como estaba. Como @ID es OUTPUT, entra con el valor de la llamada
       anterior y sin esta linea el UPSERT actualiza la fila de OTRA
       programacion. */
    SET @ID = NULL

    /* 390: UX_PCA_PROGRAMACION no filtra por pca_habilitado: si la regla
       quedó deshabilitada (cambio de tipo), se reactiva esa misma fila. */
    SELECT TOP 1 @ID = pca_id FROM [dbo].[Programacion_Calendario]
     WHERE pca_programacion = @PROGRAMACION
     ORDER BY pca_habilitado DESC, pca_id DESC

    IF (@ID IS NULL)
    BEGIN
        INSERT INTO [dbo].[Programacion_Calendario]
            (pca_programacion, pca_frecuencia_tipo, pca_intervalo,
             pca_semana_ordinal, pca_dia_mes, pca_mes, pca_hora_local,
             pca_usuario_creacion, pca_fecha_creacion,
             pca_usuario_actualizacion, pca_fecha_actualizacion, pca_habilitado)
        VALUES
            (@PROGRAMACION, @FRECUENCIA, @INTERVALO,
             @SEMANA_ORDINAL, @DIA_MES, @MES, @HORA_LOCAL,
             @USUARIO, @AHORA, @USUARIO, @AHORA, 1)

        DECLARE @FILAS INT = @@ROWCOUNT
        SET @ID = SCOPE_IDENTITY()

        IF @FILAS = 0
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('13.- NO FUE POSIBLE GUARDAR LA REGLA DE CALENDARIO.', 16, 1)
            RETURN -1
        END
    END
    ELSE
    BEGIN
        UPDATE [dbo].[Programacion_Calendario]
           SET pca_frecuencia_tipo       = @FRECUENCIA,
               pca_intervalo             = @INTERVALO,
               pca_semana_ordinal        = @SEMANA_ORDINAL,
               pca_dia_mes               = @DIA_MES,
               pca_mes                   = @MES,
               pca_hora_local            = @HORA_LOCAL,
               pca_usuario_actualizacion = @USUARIO,
               pca_fecha_actualizacion   = @AHORA,
               pca_habilitado            = 1
         WHERE pca_id = @ID
    END

    /* Los dias se reemplazan enteros. Un diff fila por fila desde la
       pantalla es mas codigo y el resultado es el mismo: son a lo sumo
       siete filas sin datos propios que conservar. */
    DELETE FROM [dbo].[Programacion_Calendario_Dia]
     WHERE pcd_programacion_calendario = @ID

    IF (@NDIAS > 0)
        INSERT INTO [dbo].[Programacion_Calendario_Dia]
            (pcd_programacion_calendario, pcd_dia_semana)
        SELECT DISTINCT @ID, TRY_CAST(LTRIM(RTRIM(value)) AS INT)
          FROM [dbo].[SPLIT](@DIAS, ',')
         WHERE LTRIM(RTRIM(value)) <> ''

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Regla de calendario guardada con éxito.' AS MENSAJE
GO

CREATE OR ALTER PROCEDURE [dbo].[UPS_PROGRAMACION_INTERVALO]
    @ID                 INT = NULL OUTPUT,
    @PROGRAMACION       INT,
    @CLIENTE            INT,
    @UNIDAD_TIEMPO      INT,
    @CANTIDAD           INT,
    @FECHA_ANCLA_UTC    DATETIME = NULL,
    @DESDE_EJECUCION    BIT = 0,
    @USUARIO            INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME, @INICIO DATE

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

SELECT @INICIO = pro_fecha_inicio FROM [dbo].[Programacion] WHERE pro_id = @PROGRAMACION

/* Sin ancla explicita se usa el inicio de vigencia: es lo que el usuario
   entiende por "desde cuando", y evita un NULL en una columna NOT NULL. */
SET @FECHA_ANCLA_UTC = ISNULL(@FECHA_ANCLA_UTC, CAST(@INICIO AS DATETIME))

IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Tiempo] WHERE uti_id = @UNIDAD_TIEMPO)
BEGIN
    RAISERROR('2.- LA UNIDAD DE TIEMPO NO EXISTE.', 16, 1)
    RETURN -1
END

IF (ISNULL(@CANTIDAD, 0) < 1)
BEGIN
    RAISERROR('3.- LA CANTIDAD DEBE SER 1 O MAYOR.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    SET @ID = NULL

    /* 390: UX_PIN_PROGRAMACION no filtra por pin_habilitado: si la regla
       quedó deshabilitada (cambio de tipo), se reactiva esa misma fila. */
    SELECT TOP 1 @ID = pin_id FROM [dbo].[Programacion_Intervalo]
     WHERE pin_programacion = @PROGRAMACION
     ORDER BY pin_habilitado DESC, pin_id DESC

    IF (@ID IS NULL)
    BEGIN
        INSERT INTO [dbo].[Programacion_Intervalo]
            (pin_programacion, pin_unidad_tiempo, pin_fecha_ancla_utc, pin_cantidad,
             pin_desde_ejecucion,
             pin_usuario_creacion, pin_fecha_creacion,
             pin_usuario_actualizacion, pin_fecha_actualizacion, pin_habilitado)
        VALUES
            (@PROGRAMACION, @UNIDAD_TIEMPO, @FECHA_ANCLA_UTC, @CANTIDAD,
             ISNULL(@DESDE_EJECUCION, 0),
             @USUARIO, @AHORA, @USUARIO, @AHORA, 1)

        DECLARE @FILAS INT = @@ROWCOUNT
        SET @ID = SCOPE_IDENTITY()

        IF @FILAS = 0
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('4.- NO FUE POSIBLE GUARDAR LA REGLA DE INTERVALO.', 16, 1)
            RETURN -1
        END
    END
    ELSE
    BEGIN
        UPDATE [dbo].[Programacion_Intervalo]
           SET pin_unidad_tiempo         = @UNIDAD_TIEMPO,
               pin_fecha_ancla_utc       = @FECHA_ANCLA_UTC,
               pin_cantidad              = @CANTIDAD,
               pin_desde_ejecucion       = ISNULL(@DESDE_EJECUCION, pin_desde_ejecucion),
               pin_usuario_actualizacion = @USUARIO,
               pin_fecha_actualizacion   = @AHORA,
               pin_habilitado            = 1
         WHERE pin_id = @ID
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Regla de intervalo guardada con éxito.' AS MENSAJE
GO
