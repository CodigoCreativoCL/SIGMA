/* ============================================================================
   SIGMA — Bloque 105
   EXCLUSIONES, CONDICIONES, MENUS Y PERMISOS          HU-074 · HU-075 · HU-070..073
   ----------------------------------------------------------------------------

   Cierra la definicion de programaciones que empezaron los bloques 103
   (cabecera) y 104 (detalle por tipo). Aca van:

     - Exclusiones  (HU-075 #2, #3): los periodos en que NO se genera nada.
     - Condiciones  (HU-074): los umbrales que disparan por medicion.
     - El menu, los permisos y los perfiles que lo usan.

   UNA DEPENDENCIA QUE VIENE DEL SPRINT 2

     `Programacion_Condicion.pco_activo_variable` apunta a `Activo_Variable`,
     que hoy tiene CERO filas y ningun SP. Esa tabla la llena HU-041
     "Administrar variables de condicion", que es del Sprint 2 y sigue en
     "Por hacer".

     O sea: el CRUD de condiciones queda completo y probado, pero el combo de
     variables de la pantalla va a estar vacio hasta que se cierre HU-041.
     Se agrega aca un SEL_ACTIVO_VARIABLE minimo para que la pantalla pueda
     al menos armarse; el mantenedor completo sigue siendo HU-041.

   POR QUE LA EXCLUSION NO BORRA, DESPLAZA

     HU-075 #2 dice "una ocurrencia que caeria en feriado se desplaza al
     siguiente dia habil Y la fecha original queda registrada", pero #3 dice
     "no se generan ocurrencias dentro de ese periodo". Son dos cosas
     distintas: el feriado corre la fecha, la parada de planta la elimina.

     El modelo tiene `pmo_fecha_programada_original_utc` para el primer caso.
     La distincion la hace `pxc_desplaza`, que se agrega aca: sin ella una
     sola tabla de exclusiones no puede cumplir los dos criterios.

   FALTA UNA TABLA QUE NINGUNA HISTORIA PIDIO

     No existe tabla de feriados. HU-075 #2 habla de "excluyo los feriados"
     como si fuera un calendario nacional, y SIGMA es multipais. Hoy se
     resuelve cargando los feriados como exclusiones con desplazamiento, que
     funciona pero obliga a cargarlos a mano por cliente. Queda anotado.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   0. LA COLUMNA QUE DISTINGUE LOS DOS CRITERIOS               HU-075 #2 vs #3
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID('dbo.Programacion_Exclusion')
                  AND name = 'pxc_desplaza')
BEGIN
    ALTER TABLE [dbo].[Programacion_Exclusion]
        ADD pxc_desplaza BIT NOT NULL
            CONSTRAINT DF_PXC_DESPLAZA DEFAULT (0)

    PRINT '--- Programacion_Exclusion.pxc_desplaza agregada.'
END
ELSE
    PRINT '--- Programacion_Exclusion.pxc_desplaza ya existia.'
GO


/* ========================================================================
   1. EXCLUSIONES                                                     HU-075
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PROGRAMACION_EXCLUSION') IS NOT NULL DROP PROCEDURE [dbo].[SEL_PROGRAMACION_EXCLUSION]
GO

CREATE PROCEDURE [dbo].[SEL_PROGRAMACION_EXCLUSION]
    @PROGRAMACION   INT,
    @CLIENTE        INT,
    @ID             INT = NULL,
    @HABILITADO     BIT = NULL
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

    SELECT  e.pxc_id,
            e.pxc_programacion,
            e.pxc_fecha_inicio_utc,
            e.pxc_fecha_fin_utc,
            e.pxc_motivo,
            e.pxc_desplaza,
            e.pxc_habilitado,
            e.pxc_usuario_creacion,
            e.pxc_fecha_creacion,
            e.pxc_usuario_actualizacion,
            e.pxc_fecha_actualizacion,
            ISNULL(uc.usu_nombre + ' ' + uc.usu_apellido_paterno, '') AS USUARIO_CREACION_NOMBRE,
            DATEDIFF(DAY, e.pxc_fecha_inicio_utc, e.pxc_fecha_fin_utc) + 1 AS DIAS,
            CASE WHEN e.pxc_desplaza = 1 THEN 'Desplaza al siguiente día hábil'
                 ELSE 'No se genera nada en el período' END           AS EFECTO
    FROM    [dbo].[Programacion_Exclusion] e
    LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = e.pxc_usuario_creacion
    WHERE   e.pxc_programacion = @PROGRAMACION
      AND   (@ID IS NULL OR e.pxc_id = @ID)
      AND   (@HABILITADO IS NULL OR e.pxc_habilitado = @HABILITADO)
    ORDER BY e.pxc_fecha_inicio_utc, e.pxc_id
GO

PRINT '--- SEL_PROGRAMACION_EXCLUSION creado.'
GO


IF OBJECT_ID('dbo.INS_PROGRAMACION_EXCLUSION') IS NOT NULL DROP PROCEDURE [dbo].[INS_PROGRAMACION_EXCLUSION]
GO

CREATE PROCEDURE [dbo].[INS_PROGRAMACION_EXCLUSION]
    @ID             INT OUTPUT,
    @PROGRAMACION   INT,
    @CLIENTE        INT,
    @FECHA_INICIO   DATETIME,
    @FECHA_FIN      DATETIME,
    @MOTIVO         NVARCHAR(400),
    @DESPLAZA       BIT = 0,
    @USUARIO        INT
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

SET @MOTIVO = LTRIM(RTRIM(@MOTIVO))

IF (@MOTIVO IS NULL OR LEN(@MOTIVO) = 0)
BEGIN
    RAISERROR('2.- INDIQUE EL MOTIVO DE LA EXCLUSION.', 16, 1)
    RETURN -1
END

IF (@FECHA_INICIO IS NULL OR @FECHA_FIN IS NULL)
BEGIN
    RAISERROR('3.- INDIQUE EL PERIODO COMPLETO DE LA EXCLUSION.', 16, 1)
    RETURN -1
END

IF (@FECHA_FIN < @FECHA_INICIO)
BEGIN
    RAISERROR('4.- LA FECHA DE TERMINO NO PUEDE SER ANTERIOR A LA DE INICIO.', 16, 1)
    RETURN -1
END

/* Dos exclusiones superpuestas no rompen nada al proyectar -la fecha queda
   excluida igual- pero son un sintoma de que alguien cargo lo mismo dos
   veces, y despues nadie entiende por que borrar una no cambio el resultado. */
IF EXISTS (SELECT 1 FROM [dbo].[Programacion_Exclusion]
            WHERE pxc_programacion = @PROGRAMACION
              AND pxc_habilitado = 1
              AND pxc_fecha_inicio_utc <= @FECHA_FIN
              AND pxc_fecha_fin_utc    >= @FECHA_INICIO)
BEGIN
    RAISERROR('5.- YA EXISTE UNA EXCLUSION QUE SE SUPERPONE CON ESE PERIODO.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    INSERT INTO [dbo].[Programacion_Exclusion]
        (pxc_programacion, pxc_fecha_inicio_utc, pxc_fecha_fin_utc, pxc_motivo,
         pxc_desplaza,
         pxc_usuario_creacion, pxc_fecha_creacion,
         pxc_usuario_actualizacion, pxc_fecha_actualizacion, pxc_habilitado)
    VALUES
        (@PROGRAMACION, @FECHA_INICIO, @FECHA_FIN, @MOTIVO,
         ISNULL(@DESPLAZA, 0),
         @USUARIO, @AHORA, @USUARIO, @AHORA, 1)

    DECLARE @FILAS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()

    IF @FILAS = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('6.- NO FUE POSIBLE INSERTAR LA EXCLUSION.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Exclusión creada con éxito.' AS MENSAJE
GO

PRINT '--- INS_PROGRAMACION_EXCLUSION creado.'
GO


IF OBJECT_ID('dbo.UPD_PROGRAMACION_EXCLUSION') IS NOT NULL DROP PROCEDURE [dbo].[UPD_PROGRAMACION_EXCLUSION]
GO

CREATE PROCEDURE [dbo].[UPD_PROGRAMACION_EXCLUSION]
    @ID             INT,
    @CLIENTE        INT,
    @FECHA_INICIO   DATETIME = NULL,
    @FECHA_FIN      DATETIME = NULL,
    @MOTIVO         NVARCHAR(400) = NULL,
    @DESPLAZA       BIT = NULL,
    @HABILITADO     BIT = NULL,
    @USUARIO        INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME, @PROGRAMACION INT
DECLARE @INICIO DATETIME, @FIN DATETIME

SELECT @PROGRAMACION = e.pxc_programacion,
       @INICIO = ISNULL(@FECHA_INICIO, e.pxc_fecha_inicio_utc),
       @FIN    = ISNULL(@FECHA_FIN, e.pxc_fecha_fin_utc)
  FROM [dbo].[Programacion_Exclusion] e
  JOIN [dbo].[Programacion] p ON p.pro_id = e.pxc_programacion
 WHERE e.pxc_id = @ID AND p.pro_cliente = @CLIENTE

IF (@PROGRAMACION IS NULL)
BEGIN
    RAISERROR('1.- LA EXCLUSION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @MOTIVO = LTRIM(RTRIM(@MOTIVO))

IF (@MOTIVO IS NOT NULL AND LEN(@MOTIVO) = 0)
BEGIN
    RAISERROR('2.- EL MOTIVO NO PUEDE QUEDAR VACIO.', 16, 1)
    RETURN -1
END

IF (@FIN < @INICIO)
BEGIN
    RAISERROR('3.- LA FECHA DE TERMINO NO PUEDE SER ANTERIOR A LA DE INICIO.', 16, 1)
    RETURN -1
END

/* La superposicion se mira EXCLUYENDO la propia fila: si no, editar el
   motivo sin tocar las fechas choca consigo misma. */
IF EXISTS (SELECT 1 FROM [dbo].[Programacion_Exclusion]
            WHERE pxc_programacion = @PROGRAMACION
              AND pxc_id <> @ID
              AND pxc_habilitado = 1
              AND pxc_fecha_inicio_utc <= @FIN
              AND pxc_fecha_fin_utc    >= @INICIO)
BEGIN
    RAISERROR('4.- YA EXISTE OTRA EXCLUSION QUE SE SUPERPONE CON ESE PERIODO.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE [dbo].[Programacion_Exclusion]
       SET pxc_fecha_inicio_utc      = @INICIO,
           pxc_fecha_fin_utc         = @FIN,
           pxc_motivo                = ISNULL(@MOTIVO, pxc_motivo),
           pxc_desplaza              = ISNULL(@DESPLAZA, pxc_desplaza),
           pxc_habilitado            = ISNULL(@HABILITADO, pxc_habilitado),
           pxc_usuario_actualizacion = @USUARIO,
           pxc_fecha_actualizacion   = @AHORA
     WHERE pxc_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('5.- NO FUE POSIBLE ACTUALIZAR LA EXCLUSION.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Exclusión actualizada con éxito.' AS MENSAJE
GO

PRINT '--- UPD_PROGRAMACION_EXCLUSION creado.'
GO


IF OBJECT_ID('dbo.DEL_PROGRAMACION_EXCLUSION') IS NOT NULL DROP PROCEDURE [dbo].[DEL_PROGRAMACION_EXCLUSION]
GO

CREATE PROCEDURE [dbo].[DEL_PROGRAMACION_EXCLUSION]
    @ID         INT,
    @CLIENTE    INT,
    @USUARIO    INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME

IF NOT EXISTS (SELECT 1
                 FROM [dbo].[Programacion_Exclusion] e
                 JOIN [dbo].[Programacion] p ON p.pro_id = e.pxc_programacion
                WHERE e.pxc_id = @ID AND p.pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA EXCLUSION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

/* Baja logica: una exclusion explica por que un periodo quedo sin trabajo
   programado. Borrarla fisicamente deja ese hueco sin explicacion en la
   auditoria del plan. */
BEGIN TRANSACTION

    UPDATE [dbo].[Programacion_Exclusion]
       SET pxc_habilitado            = 0,
           pxc_usuario_actualizacion = @USUARIO,
           pxc_fecha_actualizacion   = @AHORA
     WHERE pxc_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('2.- NO FUE POSIBLE ELIMINAR LA EXCLUSION.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Exclusión eliminada con éxito.' AS MENSAJE
GO

PRINT '--- DEL_PROGRAMACION_EXCLUSION creado.'
GO


/* ========================================================================
   2. CONDICIONES                                                     HU-074

      Bloqueada aguas arriba por HU-041 (Sprint 2): sin variables cargadas
      el combo de la pantalla va vacio. El CRUD queda listo igual.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PROGRAMACION_CONDICION') IS NOT NULL DROP PROCEDURE [dbo].[SEL_PROGRAMACION_CONDICION]
GO

CREATE PROCEDURE [dbo].[SEL_PROGRAMACION_CONDICION]
    @PROGRAMACION   INT,
    @CLIENTE        INT,
    @ID             INT = NULL,
    @HABILITADO     BIT = NULL
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

    SELECT  c.pco_id,
            c.pco_programacion,
            c.pco_activo_variable,
            v.ava_activo,
            ISNULL(a.act_nombre, '')        AS ACTIVO_NOMBRE,
            ISNULL(vm.vme_nombre, '')       AS VARIABLE_NOMBRE,
            c.pco_operador_comparacion,
            o.opc_codigo                    AS OPERADOR_CODIGO,
            o.opc_nombre                    AS OPERADOR_NOMBRE,
            c.pco_umbral,
            c.pco_umbral_hasta,
            c.pco_duracion_minima_minuto,
            c.pco_severidad,
            s.sev_nombre                    AS SEVERIDAD_NOMBRE,
            c.pco_habilitado,
            /* La regla en una frase, para la grilla. */
            ISNULL(vm.vme_nombre, 'Variable') + ' ' + o.opc_nombre + ' '
              + CAST(CAST(c.pco_umbral AS DECIMAL(18,2)) AS VARCHAR(20))
              + CASE WHEN c.pco_umbral_hasta IS NOT NULL
                     THEN ' y ' + CAST(CAST(c.pco_umbral_hasta AS DECIMAL(18,2)) AS VARCHAR(20))
                     ELSE '' END
              + CASE WHEN c.pco_duracion_minima_minuto IS NOT NULL
                     THEN ' por ' + CAST(c.pco_duracion_minima_minuto AS VARCHAR(10)) + ' min'
                     ELSE '' END            AS REGLA
    FROM    [dbo].[Programacion_Condicion] c
    JOIN    [dbo].[Operador_Comparacion] o ON o.opc_id = c.pco_operador_comparacion
    JOIN    [dbo].[Severidad] s ON s.sev_id = c.pco_severidad
    LEFT JOIN [dbo].[Activo_Variable] v ON v.ava_id = c.pco_activo_variable
    LEFT JOIN [dbo].[Activo] a ON a.act_id = v.ava_activo
    LEFT JOIN [dbo].[Variable_Medicion] vm ON vm.vme_id = v.ava_variable_medicion
    WHERE   c.pco_programacion = @PROGRAMACION
      AND   (@ID IS NULL OR c.pco_id = @ID)
      AND   (@HABILITADO IS NULL OR c.pco_habilitado = @HABILITADO)
    ORDER BY c.pco_id
GO

PRINT '--- SEL_PROGRAMACION_CONDICION creado.'
GO


IF OBJECT_ID('dbo.INS_PROGRAMACION_CONDICION') IS NOT NULL DROP PROCEDURE [dbo].[INS_PROGRAMACION_CONDICION]
GO

CREATE PROCEDURE [dbo].[INS_PROGRAMACION_CONDICION]
    @ID                 INT OUTPUT,
    @PROGRAMACION       INT,
    @CLIENTE            INT,
    @ACTIVO_VARIABLE    INT,
    @OPERADOR           INT,
    @UMBRAL             DECIMAL(18,6),
    @UMBRAL_HASTA       DECIMAL(18,6) = NULL,
    @DURACION_MINIMA    INT = NULL,
    @SEVERIDAD          INT,
    @USUARIO            INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME, @OPERADOR_CODIGO NVARCHAR(100)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

/* La variable tiene que ser del mismo cliente. Mismo motivo que en el
   medidor: sin esta linea se ata una regla propia a un sensor ajeno. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Variable]
                WHERE ava_id = @ACTIVO_VARIABLE AND ava_cliente = @CLIENTE AND ava_habilitado = 1)
BEGIN
    RAISERROR('2.- LA VARIABLE NO EXISTE PARA ESTE CLIENTE O ESTA DESHABILITADA.', 16, 1)
    RETURN -1
END

SELECT @OPERADOR_CODIGO = opc_codigo FROM [dbo].[Operador_Comparacion] WHERE opc_id = @OPERADOR

IF (@OPERADOR_CODIGO IS NULL)
BEGIN
    RAISERROR('3.- EL OPERADOR DE COMPARACION NO EXISTE.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Severidad] WHERE sev_id = @SEVERIDAD)
BEGIN
    RAISERROR('4.- LA SEVERIDAD NO EXISTE.', 16, 1)
    RETURN -1
END

/* "Entre" sin el segundo extremo no es un rango: es una comparacion que no
   se puede evaluar y que el motor tendria que adivinar. */
IF (@OPERADOR_CODIGO = 'ENTRE' AND @UMBRAL_HASTA IS NULL)
BEGIN
    RAISERROR('5.- EL OPERADOR "ENTRE" NECESITA EL SEGUNDO VALOR DEL RANGO.', 16, 1)
    RETURN -1
END

IF (@UMBRAL_HASTA IS NOT NULL AND @UMBRAL_HASTA <= @UMBRAL)
BEGIN
    RAISERROR('6.- EL SEGUNDO VALOR DEL RANGO DEBE SER MAYOR QUE EL PRIMERO.', 16, 1)
    RETURN -1
END

IF (@DURACION_MINIMA IS NOT NULL AND @DURACION_MINIMA < 0)
BEGIN
    RAISERROR('7.- LA DURACION MINIMA NO PUEDE SER NEGATIVA.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    INSERT INTO [dbo].[Programacion_Condicion]
        (pco_programacion, pco_activo_variable, pco_operador_comparacion,
         pco_umbral, pco_umbral_hasta, pco_duracion_minima_minuto, pco_severidad,
         pco_usuario_creacion, pco_fecha_creacion,
         pco_usuario_actualizacion, pco_fecha_actualizacion, pco_habilitado)
    VALUES
        (@PROGRAMACION, @ACTIVO_VARIABLE, @OPERADOR,
         @UMBRAL, @UMBRAL_HASTA, @DURACION_MINIMA, @SEVERIDAD,
         @USUARIO, @AHORA, @USUARIO, @AHORA, 1)

    DECLARE @FILAS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()

    IF @FILAS = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('8.- NO FUE POSIBLE INSERTAR LA CONDICION.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Condición creada con éxito.' AS MENSAJE
GO

PRINT '--- INS_PROGRAMACION_CONDICION creado.'
GO


IF OBJECT_ID('dbo.UPD_PROGRAMACION_CONDICION') IS NOT NULL DROP PROCEDURE [dbo].[UPD_PROGRAMACION_CONDICION]
GO

CREATE PROCEDURE [dbo].[UPD_PROGRAMACION_CONDICION]
    @ID                 INT,
    @CLIENTE            INT,
    @OPERADOR           INT = NULL,
    @UMBRAL             DECIMAL(18,6) = NULL,
    @UMBRAL_HASTA       DECIMAL(18,6) = NULL,
    @LIMPIA_UMBRAL_HASTA BIT = 0,
    @DURACION_MINIMA    INT = NULL,
    @SEVERIDAD          INT = NULL,
    @HABILITADO         BIT = NULL,
    @USUARIO            INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME, @OPERADOR_CODIGO NVARCHAR(100)
DECLARE @OP INT, @UMB DECIMAL(18,6), @HASTA DECIMAL(18,6), @EXISTE INT

SELECT @EXISTE = 1,
       @OP    = ISNULL(@OPERADOR, c.pco_operador_comparacion),
       @UMB   = ISNULL(@UMBRAL, c.pco_umbral),
       @HASTA = CASE WHEN @LIMPIA_UMBRAL_HASTA = 1 THEN NULL
                     ELSE ISNULL(@UMBRAL_HASTA, c.pco_umbral_hasta) END
  FROM [dbo].[Programacion_Condicion] c
  JOIN [dbo].[Programacion] p ON p.pro_id = c.pco_programacion
 WHERE c.pco_id = @ID AND p.pro_cliente = @CLIENTE

IF (@EXISTE IS NULL)
BEGIN
    RAISERROR('1.- LA CONDICION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

SELECT @OPERADOR_CODIGO = opc_codigo FROM [dbo].[Operador_Comparacion] WHERE opc_id = @OP

IF (@OPERADOR_CODIGO IS NULL)
BEGIN
    RAISERROR('2.- EL OPERADOR DE COMPARACION NO EXISTE.', 16, 1)
    RETURN -1
END

IF (@SEVERIDAD IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Severidad] WHERE sev_id = @SEVERIDAD))
BEGIN
    RAISERROR('3.- LA SEVERIDAD NO EXISTE.', 16, 1)
    RETURN -1
END

IF (@OPERADOR_CODIGO = 'ENTRE' AND @HASTA IS NULL)
BEGIN
    RAISERROR('4.- EL OPERADOR "ENTRE" NECESITA EL SEGUNDO VALOR DEL RANGO.', 16, 1)
    RETURN -1
END

IF (@HASTA IS NOT NULL AND @HASTA <= @UMB)
BEGIN
    RAISERROR('5.- EL SEGUNDO VALOR DEL RANGO DEBE SER MAYOR QUE EL PRIMERO.', 16, 1)
    RETURN -1
END

IF (@DURACION_MINIMA IS NOT NULL AND @DURACION_MINIMA < 0)
BEGIN
    RAISERROR('6.- LA DURACION MINIMA NO PUEDE SER NEGATIVA.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE [dbo].[Programacion_Condicion]
       SET pco_operador_comparacion   = @OP,
           pco_umbral                 = @UMB,
           pco_umbral_hasta           = @HASTA,
           pco_duracion_minima_minuto = ISNULL(@DURACION_MINIMA, pco_duracion_minima_minuto),
           pco_severidad              = ISNULL(@SEVERIDAD, pco_severidad),
           pco_habilitado             = ISNULL(@HABILITADO, pco_habilitado),
           pco_usuario_actualizacion  = @USUARIO,
           pco_fecha_actualizacion    = @AHORA
     WHERE pco_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('7.- NO FUE POSIBLE ACTUALIZAR LA CONDICION.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Condición actualizada con éxito.' AS MENSAJE
GO

PRINT '--- UPD_PROGRAMACION_CONDICION creado.'
GO


IF OBJECT_ID('dbo.DEL_PROGRAMACION_CONDICION') IS NOT NULL DROP PROCEDURE [dbo].[DEL_PROGRAMACION_CONDICION]
GO

CREATE PROCEDURE [dbo].[DEL_PROGRAMACION_CONDICION]
    @ID         INT,
    @CLIENTE    INT,
    @USUARIO    INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME, @PROGRAMACION INT, @QUEDAN INT

SELECT @PROGRAMACION = c.pco_programacion
  FROM [dbo].[Programacion_Condicion] c
  JOIN [dbo].[Programacion] p ON p.pro_id = c.pco_programacion
 WHERE c.pco_id = @ID AND p.pro_cliente = @CLIENTE

IF (@PROGRAMACION IS NULL)
BEGIN
    RAISERROR('1.- LA CONDICION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

/* Una programacion por condicion sin ninguna condicion no dispara nunca:
   queda viva en la lista sin hacer nada y nadie sabe por que. */
SELECT @QUEDAN = COUNT(*)
  FROM [dbo].[Programacion_Condicion]
 WHERE pco_programacion = @PROGRAMACION AND pco_habilitado = 1 AND pco_id <> @ID

IF (@QUEDAN = 0)
BEGIN
    RAISERROR('2.- ES LA UNICA CONDICION: DESHABILITE LA PROGRAMACION COMPLETA EN VEZ DE DEJARLA SIN REGLAS.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE [dbo].[Programacion_Condicion]
       SET pco_habilitado            = 0,
           pco_usuario_actualizacion = @USUARIO,
           pco_fecha_actualizacion   = @AHORA
     WHERE pco_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('3.- NO FUE POSIBLE ELIMINAR LA CONDICION.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Condición eliminada con éxito.' AS MENSAJE
GO

PRINT '--- DEL_PROGRAMACION_CONDICION creado.'
GO


/* ========================================================================
   3. SEL_ACTIVO_VARIABLE — MINIMO                        HU-041 (Sprint 2)

      Solo para que el combo de la pantalla de condiciones exista. El
      mantenedor completo de variables es HU-041 y sigue pendiente.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_ACTIVO_VARIABLE') IS NOT NULL DROP PROCEDURE [dbo].[SEL_ACTIVO_VARIABLE]
GO

CREATE PROCEDURE [dbo].[SEL_ACTIVO_VARIABLE]
    @CLIENTE    INT,
    @ID         INT = NULL,
    @ACTIVO     INT = NULL,
    @HABILITADO BIT = NULL
AS
SET NOCOUNT ON

    SELECT  v.ava_id,
            v.ava_cliente,
            v.ava_activo,
            ISNULL(a.act_nombre, '')    AS ACTIVO_NOMBRE,
            v.ava_activo_componente,
            v.ava_variable_medicion,
            ISNULL(vm.vme_nombre, '')   AS VARIABLE_NOMBRE,
            v.ava_unidad_medida,
            ISNULL(um.ume_nombre, '')   AS UNIDAD_NOMBRE,
            v.ava_valor_minimo,
            v.ava_valor_maximo,
            v.ava_valor_advertencia,
            v.ava_valor_critico,
            v.ava_frecuencia_esperada_hora,
            v.ava_habilitado,
            /* Lo que el combo muestra: "Bomba 3 — Temperatura (°C)". */
            ISNULL(a.act_nombre, '') + ' — ' + ISNULL(vm.vme_nombre, '')
              + CASE WHEN um.ume_nombre IS NOT NULL THEN ' (' + um.ume_nombre + ')' ELSE '' END
                                        AS ETIQUETA
    FROM    [dbo].[Activo_Variable] v
    LEFT JOIN [dbo].[Activo] a ON a.act_id = v.ava_activo
    LEFT JOIN [dbo].[Variable_Medicion] vm ON vm.vme_id = v.ava_variable_medicion
    LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = v.ava_unidad_medida
    WHERE   v.ava_cliente = @CLIENTE
      AND   (@ID IS NULL OR v.ava_id = @ID)
      AND   (@ACTIVO IS NULL OR v.ava_activo = @ACTIVO)
      AND   (@HABILITADO IS NULL OR v.ava_habilitado = @HABILITADO)
    ORDER BY a.act_nombre, vm.vme_nombre, v.ava_id
GO

PRINT '--- SEL_ACTIVO_VARIABLE creado (minimo, HU-041 lo completa).'
GO


/* ========================================================================
   4. PERMISOS Y MENU

      La seguridad de SIGMA es por datos: sin fila en Menus la pantalla no
      abre, aunque el archivo exista y el usuario sea Root.
   ======================================================================== */
DECLARE @VER INT, @EDITAR INT, @PADRE INT, @MNU INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PROGRAMACIONES')
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    VALUES ('VER PROGRAMACIONES', 'Ver programaciones', 'MANTENIMIENTO', 3,
            'Consultar las reglas que definen cuándo toca cada trabajo', 1, GETDATE(), 1, 0)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR PROGRAMACIONES')
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    VALUES ('CREAR EDITAR PROGRAMACIONES', 'Crear y editar programaciones', 'MANTENIMIENTO', 1,
            'Definir y mantener las reglas de programación del mantenimiento', 1, GETDATE(), 1, 0)

SELECT @VER    = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PROGRAMACIONES'
SELECT @EDITAR = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR PROGRAMACIONES'

/* El modulo Mantenimiento, hermano de Inventario, Activos y Terceros. Aca
   van a colgar despues los planes (HU-080) y la bandeja de ocurrencias
   (HU-087), que son del Sprint 4. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_nombre = 'Mantenimiento' AND mnu_nivel = 2)
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Mantenimiento', 'Programaciones, planes y ocurrencias',
            2, 1, 7, '#', 1, 'mdi mdi-calendar-clock', @VER, 1)

SELECT @PADRE = mnu_id FROM [dbo].[Menus] WHERE mnu_nombre = 'Mantenimiento' AND mnu_nivel = 2

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Mantenimiento/Programaciones/Programaciones.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Programaciones', 'Reglas que definen cuándo toca cada trabajo',
            3, @PADRE, 1, '~/View/Mantenimiento/Programaciones/Programaciones.aspx',
            1, NULL, @VER, 1)

/* La ficha va invisible pero CON fila: se llega desde el listado, y sin su
   registro Token.ExigirPagina la cierra. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Mantenimiento/Programaciones/Programacion.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Programación (detalle)', 'Ficha de la programación',
            3, @PADRE, 99, '~/View/Mantenimiento/Programaciones/Programacion.aspx',
            0, NULL, @VER, 1)

/* Menu_Funcion SIEMPRE que nace un menu: sin la fila, Token.PuedeFuncion
   devuelve false para todos -Root incluido- y el boton no aparece, sin
   ningun error que lo explique. */
SELECT @MNU = mnu_id FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Mantenimiento/Programaciones/Programaciones.aspx'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Crear y editar', @MNU, @EDITAR)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Eliminar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Eliminar', @MNU, @EDITAR)

SELECT @MNU = mnu_id FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Mantenimiento/Programaciones/Programacion.aspx'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Crear y editar', @MNU, @EDITAR)

PRINT '--- Permisos y menu de Mantenimiento/Programaciones listos.'
GO


/* ========================================================================
   5. LOS PERFILES QUE LO NECESITAN

      Sin esto el menu existe y no lo ve nadie salvo Root.
   ======================================================================== */
DECLARE @VER INT, @EDITAR INT

SELECT @VER    = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER PROGRAMACIONES'
SELECT @EDITAR = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR PROGRAMACIONES'

/* Planificador de Mantenimiento (11) es el protagonista literal de las
   siete historias. Jefe de Mantenimiento (5) aprueba y corrige.
   Administrador del Cliente (10) mantiene los maestros de su empresa. */
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT p.per_id, x.prm, 1, GETDATE()
FROM   (VALUES (11), (5), (10)) AS p(per_id)
CROSS JOIN (VALUES (@VER), (@EDITAR)) AS x(prm)
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso]
                    WHERE ppe_perfil = p.per_id AND ppe_permiso = x.prm)

/* El Supervisor (12) las consulta para saber que le toca a su turno, pero
   no define reglas. */
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT 12, @VER, 1, GETDATE()
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso]
                    WHERE ppe_perfil = 12 AND ppe_permiso = @VER)

PRINT '--- Perfiles con acceso a programaciones listos.'
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
SELECT  m.mnu_id, m.mnu_nivel, m.mnu_nombre, m.mnu_link, m.mnu_visible,
        (SELECT COUNT(*) FROM [dbo].[Menu_Funcion] f WHERE f.mfu_menu = m.mnu_id) AS FUNCIONES
FROM    [dbo].[Menus] m
WHERE   m.mnu_nombre = 'Mantenimiento' OR m.mnu_link LIKE '%Programacion%'
ORDER BY m.mnu_nivel, m.mnu_orden
GO

SELECT  per.per_nombre, prm.prm_codigo
FROM    [dbo].[Perfil_Permiso] pp
JOIN    [dbo].[Perfiles] per ON per.per_id = pp.ppe_perfil
JOIN    [dbo].[Permiso] prm ON prm.prm_id = pp.ppe_permiso
WHERE   prm.prm_modulo = 'MANTENIMIENTO'
ORDER BY per.per_id, prm.prm_codigo
GO

PRINT '105_PROGRAMACION_EXCLUSION_CONDICION aplicado.'
GO
