/* ============================================================================
   424 · Arreglos de la ronda de pruebas del cliente (09-10-2026)
   1. UPS_PROGRAMACION_MEDIDOR: al ir y volver entre pestañas de frecuencia saltaba
      «Cannot insert duplicate key ... UX_PME_PROGRAMACION_MEDIDOR»: buscaba solo la regla
      habilitada. Ahora reutiliza (y reactiva) la que exista para la programación.
   Aplicar con -I. Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ---- 6. UPS_PROGRAMACION_MEDIDOR acepta el medidor vacio (= el de cada equipo) ---- */
CREATE OR ALTER PROCEDURE [dbo].[UPS_PROGRAMACION_MEDIDOR]
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
/* HU-073 #3: NULL significa «el horometro de cada equipo del plan»
   (FNC_PLAN_MEDIDOR_ESTADO lo resuelve por activo). Solo si viene uno
   concreto se exige que sea del cliente. */
IF @ACTIVO_MEDIDOR IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor]
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

    /* 424: también la regla deshabilitada (al cambiar de «Medidor» a otra frecuencia y volver):
       el índice UX_PME_PROGRAMACION_MEDIDOR no deja insertar otra para la misma programación. */
    SELECT TOP 1 @ID = pme_id FROM [dbo].[Programacion_Medidor]
     WHERE pme_programacion = @PROGRAMACION
     ORDER BY pme_habilitado DESC, pme_id DESC

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
               pme_fecha_actualizacion   = @AHORA,
               pme_habilitado            = 1
         WHERE pme_id = @ID
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Regla de medidor guardada con éxito.' AS MENSAJE
GO
PRINT '424 aplicado.'
GO
