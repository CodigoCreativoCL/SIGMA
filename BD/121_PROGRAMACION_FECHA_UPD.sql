/* ============================================================================
   SIGMA — Bloque 121
   EDITAR UNA FECHA DE LA PROGRAMACION
   ----------------------------------------------------------------------------

   POR QUE UN UPD Y NO BORRAR + INSERTAR

     La ficha ahora deja corregir una fecha en la misma fila. La tentacion es
     resolverlo con el DEL y el INS que ya existen, pero eso CAMBIA EL ID.

     Y el id importa: `Programacion_Fecha` es lo que cuelga la ocurrencia.
     Borrar y recrear convierte "corregi el dia" en "borre el trabajo del 5 y
     cree otro el 6", y con el se va lo que ya estuviera enganchado a esa
     fila.

   LAS MISMAS REGLAS QUE EL ALTA

     No se puede repetir la fecha dentro de la misma programacion —ahora
     excluyendo la propia fila, que si no una edicion que no cambia el dia se
     rechazaria a si misma— y la fecha pasada se ACEPTA con aviso, porque
     sirve para registrar trabajo ya hecho.

     Editar no puede ser una puerta trasera para dejar la fila en un estado
     que el alta no permite.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.UPD_PROGRAMACION_FECHA') IS NOT NULL
    DROP PROCEDURE [dbo].[UPD_PROGRAMACION_FECHA]
GO

CREATE PROCEDURE [dbo].[UPD_PROGRAMACION_FECHA]
    @ID             INT,
    @CLIENTE        INT,
    @FECHA          DATE,
    @HORA           TIME = NULL,
    @INCLUIDA       BIT = NULL,
    @USUARIO        INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PROGRAMACION INT, @PAIS INT, @HOY DATE

/* El cliente se comprueba por la programacion padre, no por la fila: la fila
   sola no sabe de quien es, y sin este JOIN cualquiera con el id podria
   editar la fecha de otra empresa. */
SELECT  @PROGRAMACION = p.pro_id
FROM    [dbo].[Programacion_Fecha] f
JOIN    [dbo].[Programacion] p ON p.pro_id = f.pfe_programacion
WHERE   f.pfe_id = @ID AND p.pro_cliente = @CLIENTE

IF (@PROGRAMACION IS NULL)
BEGIN
    RAISERROR('1.- LA FECHA NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@FECHA IS NULL)
BEGIN
    RAISERROR('2.- INDIQUE LA FECHA.', 16, 1)
    RETURN -1
END

/* Excluyendo la propia fila: sin el `pfe_id <> @ID`, guardar sin cambiar el
   dia se rechazaria a si mismo por duplicado. */
IF EXISTS (SELECT 1 FROM [dbo].[Programacion_Fecha]
            WHERE pfe_programacion = @PROGRAMACION
              AND pfe_fecha = @FECHA
              AND pfe_id <> @ID)
BEGIN
    RAISERROR('3.- ESA FECHA YA ESTA EN LA PROGRAMACION.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Programacion_Fecha]
    SET     pfe_fecha    = @FECHA,
            pfe_hora     = @HORA,
            pfe_incluida = ISNULL(@INCLUIDA, pfe_incluida)
    WHERE   pfe_id = @ID

    DECLARE @FILAS INT = @@ROWCOUNT

    IF @FILAS = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('4.- NO FUE POSIBLE ACTUALIZAR LA FECHA.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @HOY = CAST([dbo].[FNC_PAIS_HORA](@PAIS) AS DATE)

/* Igual que el alta: la fecha pasada se avisa, no se rechaza. */
SELECT  @ID AS ID,
        200 AS CODE,
        CASE WHEN @FECHA < @HOY
             THEN 'Fecha actualizada. Es anterior a hoy: se usará para registrar trabajo ya realizado.'
             ELSE 'Fecha actualizada con éxito.' END AS MENSAJE,
        CAST(CASE WHEN @FECHA < @HOY THEN 1 ELSE 0 END AS BIT) AS ES_PASADA
GO

PRINT '--- UPD_PROGRAMACION_FECHA creado.'
GO

PRINT '121_PROGRAMACION_FECHA_UPD aplicado.'
GO
