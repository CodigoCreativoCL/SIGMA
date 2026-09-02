/* ============================================================================
   SIGMA — Bloque 104
   PROGRAMACIONES: DETALLE POR TIPO    HU-070 · HU-071 · HU-072 · HU-073 · HU-074 · HU-075
   ----------------------------------------------------------------------------

   Continua el bloque 103, que dejo la cabecera. Aca va el detalle de cada
   tipo, mas las exclusiones y las condiciones.

   POR QUE HAY "UPS_" Y NO "INS_/UPD_" EN TRES DE ELLOS

     Calendario, Intervalo y Medidor son 1..1 con la programacion: una
     programacion de calendario tiene UNA regla de calendario, no una lista.
     Con INS_ y UPD_ separados la pantalla tendria que preguntar antes si ya
     existe para saber cual llamar, y esa pregunta se contesta mal la primera
     vez que dos personas guardan a la vez. UPS_ resuelve el caso completo.

     Fecha, Exclusion y Condicion si son 1..N y llevan su CRUD normal.

   UNA COLUMNA QUE FALTABA                                          HU-072 #2

     Los dos criterios de HU-072 piden cosas opuestas:

       #1  "intervalo de 90 dias DESDE LA ULTIMA EJECUCION" -> si la anterior
           se ejecuto el dia 10, la siguiente va 90 dias despues del dia 10.
       #2  "intervalo contado DESDE LA FECHA PROGRAMADA" -> un atraso en la
           ejecucion NO desplaza las ocurrencias siguientes.

     `Programacion_Intervalo` tenia ancla, cantidad y unidad, pero ninguna
     columna que dijera cual de los dos modos es. Sin ella HU-072 solo puede
     cumplir uno de sus dos criterios. Se agrega `pin_desde_ejecucion`, que
     es aditiva y con default: 0 = desde la fecha programada (fijo, el
     comportamiento que ya se asumia), 1 = desde la ultima ejecucion.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   0. LA COLUMNA QUE FALTABA                                        HU-072 #2
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID('dbo.Programacion_Intervalo')
                  AND name = 'pin_desde_ejecucion')
BEGIN
    ALTER TABLE [dbo].[Programacion_Intervalo]
        ADD pin_desde_ejecucion BIT NOT NULL
            CONSTRAINT DF_PIN_DESDE_EJECUCION DEFAULT (0)

    PRINT '--- Programacion_Intervalo.pin_desde_ejecucion agregada.'
END
ELSE
    PRINT '--- Programacion_Intervalo.pin_desde_ejecucion ya existia.'
GO


/* ========================================================================
   1. FECHAS PUNTUALES                                                HU-070

      "Cuando defino cuatro fechas especificas, se generan cuatro ocurrencias
      independientes". La tabla no tiene auditoria ni habilitado: una fecha
      puntual o esta o no esta, y `pfe_incluida` distingue la fecha que se
      agrega de la que se saca a mano de una serie.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PROGRAMACION_FECHA') IS NOT NULL DROP PROCEDURE [dbo].[SEL_PROGRAMACION_FECHA]
GO

CREATE PROCEDURE [dbo].[SEL_PROGRAMACION_FECHA]
    @PROGRAMACION   INT,
    @CLIENTE        INT,
    @INCLUIDA       BIT = NULL
AS
SET NOCOUNT ON

/* El cliente se verifica siempre, aunque el id venga de la propia pantalla:
   es lo unico que impide leer el detalle de otra empresa cambiando el
   querystring. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

    SELECT  f.pfe_id,
            f.pfe_programacion,
            f.pfe_fecha,
            f.pfe_hora,
            f.pfe_incluida
    FROM    [dbo].[Programacion_Fecha] f
    WHERE   f.pfe_programacion = @PROGRAMACION
      AND   (@INCLUIDA IS NULL OR f.pfe_incluida = @INCLUIDA)
    ORDER BY f.pfe_fecha, f.pfe_id
GO

PRINT '--- SEL_PROGRAMACION_FECHA creado.'
GO


IF OBJECT_ID('dbo.INS_PROGRAMACION_FECHA') IS NOT NULL DROP PROCEDURE [dbo].[INS_PROGRAMACION_FECHA]
GO

CREATE PROCEDURE [dbo].[INS_PROGRAMACION_FECHA]
    @ID             INT OUTPUT,
    @PROGRAMACION   INT,
    @CLIENTE        INT,
    @FECHA          DATE,
    @HORA           TIME = NULL,
    @INCLUIDA       BIT = 1,
    @USUARIO        INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @HOY DATE

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@FECHA IS NULL)
BEGIN
    RAISERROR('2.- INDIQUE LA FECHA.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Programacion_Fecha]
            WHERE pfe_programacion = @PROGRAMACION AND pfe_fecha = @FECHA)
BEGIN
    RAISERROR('3.- ESA FECHA YA ESTA EN LA PROGRAMACION.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    INSERT INTO [dbo].[Programacion_Fecha]
        (pfe_programacion, pfe_fecha, pfe_hora, pfe_incluida)
    VALUES (@PROGRAMACION, @FECHA, @HORA, ISNULL(@INCLUIDA, 1))

    DECLARE @FILAS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()

    IF @FILAS = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('4.- NO FUE POSIBLE AGREGAR LA FECHA.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @HOY = CAST([dbo].[FNC_PAIS_HORA](@PAIS) AS DATE)

/* HU-070 #2: una fecha pasada se ADVIERTE pero se acepta, porque sirve para
   registrar trabajo que ya se hizo. Por eso es un aviso en el resultado y
   no un RAISERROR que abortaria el alta. */
SELECT  @ID AS ID,
        200 AS CODE,
        CASE WHEN @FECHA < @HOY
             THEN 'Fecha agregada. Es anterior a hoy: se usará para registrar trabajo ya realizado.'
             ELSE 'Fecha agregada con éxito.' END AS MENSAJE,
        CAST(CASE WHEN @FECHA < @HOY THEN 1 ELSE 0 END AS BIT) AS ES_PASADA
GO

PRINT '--- INS_PROGRAMACION_FECHA creado.'
GO


IF OBJECT_ID('dbo.DEL_PROGRAMACION_FECHA') IS NOT NULL DROP PROCEDURE [dbo].[DEL_PROGRAMACION_FECHA]
GO

CREATE PROCEDURE [dbo].[DEL_PROGRAMACION_FECHA]
    @ID         INT,
    @CLIENTE    INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

/* Borrado fisico: la tabla no tiene habilitado y una fecha puntual que se
   saca de la lista no deja historia que conservar. Lo que si se conserva
   son las ocurrencias que esa fecha ya haya generado, que cuelgan de la
   programacion y no de la fila de fecha. */
IF NOT EXISTS (SELECT 1
                 FROM [dbo].[Programacion_Fecha] f
                 JOIN [dbo].[Programacion] p ON p.pro_id = f.pfe_programacion
                WHERE f.pfe_id = @ID AND p.pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA FECHA NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    DELETE FROM [dbo].[Programacion_Fecha] WHERE pfe_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('2.- NO FUE POSIBLE ELIMINAR LA FECHA.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Fecha eliminada con éxito.' AS MENSAJE
GO

PRINT '--- DEL_PROGRAMACION_FECHA creado.'
GO


/* ========================================================================
   2. CALENDARIO                                                      HU-071

      La regla recurrente. Los tres criterios de la historia son los tres
      casos dificiles del calendario:

        #1 semanal en varios dias  -> Programacion_Calendario_Dia
        #2 "ultimo dia del mes"    -> pca_dia_mes = -1
        #3 "ultimo viernes"        -> pca_semana_ordinal = -1 + dia

      La convencion del -1 es la que evita tener que guardar 28/29/30/31 y
      elegir mal en febrero. Se valida aca y la interpreta el bloque 105.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PROGRAMACION_CALENDARIO') IS NOT NULL DROP PROCEDURE [dbo].[SEL_PROGRAMACION_CALENDARIO]
GO

CREATE PROCEDURE [dbo].[SEL_PROGRAMACION_CALENDARIO]
    @PROGRAMACION   INT,
    @CLIENTE        INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

    SELECT  c.pca_id,
            c.pca_programacion,
            c.pca_frecuencia_tipo,
            f.fre_codigo                AS FRECUENCIA_CODIGO,
            f.fre_nombre                AS FRECUENCIA_NOMBRE,
            c.pca_intervalo,
            c.pca_semana_ordinal,
            c.pca_dia_mes,
            c.pca_mes,
            c.pca_hora_local,
            c.pca_habilitado,
            /* Los dias en una sola celda: el combo multiple de la ficha los
               lee de aca y no necesita una segunda consulta. */
            ISNULL(STUFF((SELECT ',' + CAST(d.pcd_dia_semana AS VARCHAR(2))
                            FROM [dbo].[Programacion_Calendario_Dia] d
                           WHERE d.pcd_programacion_calendario = c.pca_id
                           ORDER BY d.pcd_dia_semana
                             FOR XML PATH('')), 1, 1, ''), '')  AS DIAS,
            ISNULL(STUFF((SELECT ', ' + s.dse_nombre
                            FROM [dbo].[Programacion_Calendario_Dia] d
                            JOIN [dbo].[Dia_Semana] s ON s.dse_id = d.pcd_dia_semana
                           WHERE d.pcd_programacion_calendario = c.pca_id
                           ORDER BY d.pcd_dia_semana
                             FOR XML PATH('')), 1, 2, ''), '')  AS DIAS_NOMBRE
    FROM    [dbo].[Programacion_Calendario] c
    JOIN    [dbo].[Frecuencia_Tipo] f ON f.fre_id = c.pca_frecuencia_tipo
    WHERE   c.pca_programacion = @PROGRAMACION
      AND   c.pca_habilitado = 1
GO

PRINT '--- SEL_PROGRAMACION_CALENDARIO creado.'
GO


IF OBJECT_ID('dbo.UPS_PROGRAMACION_CALENDARIO') IS NOT NULL DROP PROCEDURE [dbo].[UPS_PROGRAMACION_CALENDARIO]
GO

CREATE PROCEDURE [dbo].[UPS_PROGRAMACION_CALENDARIO]
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

    SELECT @ID = pca_id FROM [dbo].[Programacion_Calendario]
     WHERE pca_programacion = @PROGRAMACION AND pca_habilitado = 1

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
               pca_fecha_actualizacion   = @AHORA
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

PRINT '--- UPS_PROGRAMACION_CALENDARIO creado.'
GO


/* ========================================================================
   3. INTERVALO DE TIEMPO                                             HU-072
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PROGRAMACION_INTERVALO') IS NOT NULL DROP PROCEDURE [dbo].[SEL_PROGRAMACION_INTERVALO]
GO

CREATE PROCEDURE [dbo].[SEL_PROGRAMACION_INTERVALO]
    @PROGRAMACION   INT,
    @CLIENTE        INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

    SELECT  i.pin_id,
            i.pin_programacion,
            i.pin_unidad_tiempo,
            u.uti_codigo                AS UNIDAD_CODIGO,
            u.uti_nombre                AS UNIDAD_NOMBRE,
            i.pin_fecha_ancla_utc,
            i.pin_cantidad,
            i.pin_desde_ejecucion,
            i.pin_habilitado
    FROM    [dbo].[Programacion_Intervalo] i
    JOIN    [dbo].[Unidad_Tiempo] u ON u.uti_id = i.pin_unidad_tiempo
    WHERE   i.pin_programacion = @PROGRAMACION
      AND   i.pin_habilitado = 1
GO

PRINT '--- SEL_PROGRAMACION_INTERVALO creado.'
GO


IF OBJECT_ID('dbo.UPS_PROGRAMACION_INTERVALO') IS NOT NULL DROP PROCEDURE [dbo].[UPS_PROGRAMACION_INTERVALO]
GO

CREATE PROCEDURE [dbo].[UPS_PROGRAMACION_INTERVALO]
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

    SELECT @ID = pin_id FROM [dbo].[Programacion_Intervalo]
     WHERE pin_programacion = @PROGRAMACION AND pin_habilitado = 1

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
               pin_fecha_actualizacion   = @AHORA
         WHERE pin_id = @ID
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Regla de intervalo guardada con éxito.' AS MENSAJE
GO

PRINT '--- UPS_PROGRAMACION_INTERVALO creado.'
GO


/* ========================================================================
   4. MEDIDOR                                                         HU-073

      NOTA DE MODELO: pme_activo_medidor es NOT NULL, asi que hoy la regla
      queda atada a UN horometro concreto. HU-073 #3 -un plan sobre cuatro
      blowers, cada uno con el suyo, sin crear cuatro planes- necesita que
      sea nullable y que el medidor salga de Plan_Mantenimiento_Activo.
      Queda anotado; el cambio lo decide el equipo.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PROGRAMACION_MEDIDOR') IS NOT NULL DROP PROCEDURE [dbo].[SEL_PROGRAMACION_MEDIDOR]
GO

CREATE PROCEDURE [dbo].[SEL_PROGRAMACION_MEDIDOR]
    @PROGRAMACION   INT,
    @CLIENTE        INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

    SELECT  m.pme_id,
            m.pme_programacion,
            m.pme_activo_medidor,
            am.ame_codigo               AS MEDIDOR_CODIGO,
            am.ame_nombre               AS MEDIDOR_NOMBRE,
            am.ame_valor_actual         AS MEDIDOR_VALOR_ACTUAL,
            am.ame_activo,
            a.act_nombre                AS ACTIVO_NOMBRE,
            m.pme_valor_inicial,
            m.pme_cada_cantidad,
            m.pme_aviso_anticipacion,
            m.pme_habilitado,
            /* Cuanto falta para el proximo disparo, que es lo que el
               planificador mira en la ficha. */
            CAST(m.pme_valor_inicial + m.pme_cada_cantidad
                 * (FLOOR((am.ame_valor_actual - m.pme_valor_inicial) / NULLIF(m.pme_cada_cantidad, 0)) + 1)
                 AS DECIMAL(18,2))      AS PROXIMO_VALOR
    FROM    [dbo].[Programacion_Medidor] m
    JOIN    [dbo].[Activo_Medidor] am ON am.ame_id = m.pme_activo_medidor
    JOIN    [dbo].[Activo] a ON a.act_id = am.ame_activo
    WHERE   m.pme_programacion = @PROGRAMACION
      AND   m.pme_habilitado = 1
GO

PRINT '--- SEL_PROGRAMACION_MEDIDOR creado.'
GO


IF OBJECT_ID('dbo.UPS_PROGRAMACION_MEDIDOR') IS NOT NULL DROP PROCEDURE [dbo].[UPS_PROGRAMACION_MEDIDOR]
GO

CREATE PROCEDURE [dbo].[UPS_PROGRAMACION_MEDIDOR]
    @ID                 INT = NULL OUTPUT,
    @PROGRAMACION       INT,
    @CLIENTE            INT,
    @ACTIVO_MEDIDOR     INT,
    @VALOR_INICIAL      DECIMAL(18,2) = NULL,
    @CADA_CANTIDAD      DECIMAL(18,2),
    @AVISO_ANTICIPACION DECIMAL(18,2) = NULL,
    @USUARIO            INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

/* El medidor tiene que ser del mismo cliente: sin esta linea se puede atar
   una programacion propia al horometro de otra empresa. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor]
                WHERE ame_id = @ACTIVO_MEDIDOR AND ame_cliente = @CLIENTE AND ame_habilitado = 1)
BEGIN
    RAISERROR('2.- EL MEDIDOR NO EXISTE PARA ESTE CLIENTE O ESTA DESHABILITADO.', 16, 1)
    RETURN -1
END

IF (ISNULL(@CADA_CANTIDAD, 0) <= 0)
BEGIN
    RAISERROR('3.- EL INTERVALO DE MEDIDOR DEBE SER MAYOR QUE CERO.', 16, 1)
    RETURN -1
END

/* HU-073 #2: el aviso anticipado tiene que caer DENTRO del intervalo. Un
   aviso de 600 horas sobre un ciclo de 500 estaria siempre activo y dejaria
   de significar nada. */
IF (@AVISO_ANTICIPACION IS NOT NULL AND @AVISO_ANTICIPACION >= @CADA_CANTIDAD)
BEGIN
    RAISERROR('4.- EL AVISO ANTICIPADO DEBE SER MENOR QUE EL INTERVALO.', 16, 1)
    RETURN -1
END

IF (@AVISO_ANTICIPACION IS NOT NULL AND @AVISO_ANTICIPACION < 0)
BEGIN
    RAISERROR('5.- EL AVISO ANTICIPADO NO PUEDE SER NEGATIVO.', 16, 1)
    RETURN -1
END

/* Sin valor inicial se toma la lectura actual del medidor: el ciclo empieza
   a contar desde donde esta el equipo hoy, no desde cero. */
IF (@VALOR_INICIAL IS NULL)
    SELECT @VALOR_INICIAL = ame_valor_actual FROM [dbo].[Activo_Medidor]
     WHERE ame_id = @ACTIVO_MEDIDOR

BEGIN TRANSACTION

    SET @ID = NULL

    SELECT @ID = pme_id FROM [dbo].[Programacion_Medidor]
     WHERE pme_programacion = @PROGRAMACION AND pme_habilitado = 1

    IF (@ID IS NULL)
    BEGIN
        INSERT INTO [dbo].[Programacion_Medidor]
            (pme_programacion, pme_activo_medidor, pme_valor_inicial,
             pme_cada_cantidad, pme_aviso_anticipacion,
             pme_usuario_creacion, pme_fecha_creacion,
             pme_usuario_actualizacion, pme_fecha_actualizacion, pme_habilitado)
        VALUES
            (@PROGRAMACION, @ACTIVO_MEDIDOR, @VALOR_INICIAL,
             @CADA_CANTIDAD, @AVISO_ANTICIPACION,
             @USUARIO, @AHORA, @USUARIO, @AHORA, 1)

        DECLARE @FILAS INT = @@ROWCOUNT
        SET @ID = SCOPE_IDENTITY()

        IF @FILAS = 0
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('6.- NO FUE POSIBLE GUARDAR LA REGLA DE MEDIDOR.', 16, 1)
            RETURN -1
        END
    END
    ELSE
    BEGIN
        UPDATE [dbo].[Programacion_Medidor]
           SET pme_activo_medidor        = @ACTIVO_MEDIDOR,
               pme_valor_inicial         = @VALOR_INICIAL,
               pme_cada_cantidad         = @CADA_CANTIDAD,
               pme_aviso_anticipacion    = @AVISO_ANTICIPACION,
               pme_usuario_actualizacion = @USUARIO,
               pme_fecha_actualizacion   = @AHORA
         WHERE pme_id = @ID
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Regla de medidor guardada con éxito.' AS MENSAJE
GO

PRINT '--- UPS_PROGRAMACION_MEDIDOR creado.'
GO
