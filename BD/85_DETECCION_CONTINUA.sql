/* ============================================================================
   SIGMA — Bloque 85
   EL DETECTOR CORRE SOLO, SIN MACHACAR LA BASE
   ----------------------------------------------------------------------------

   EL PROBLEMA

     GEN_ALERTA_INVENTARIO existia pero nadie lo llamaba salvo un boton. Sin
     eso, el modulo de alertas depende de que alguien se acuerde de apretarlo,
     y nadie lo va a hacer.

   POR QUE NO SE LLAMA EN CADA CARGA DE PAGINA

     La cabecera se dibuja en TODAS las pantallas. Correr el detector ahi
     serian varios recorridos de saldos y lotes por cada clic de cada usuario:
     con diez personas navegando, cientos de ejecuciones por minuto para
     encontrar las mismas tres alertas.

   EL FRENO VIVE EN LA BASE, NO EN LA APLICACION

     Podria guardarse la ultima ejecucion en memoria del sitio, pero eso se
     pierde al reciclar el proceso y no sirve si manana hay dos servidores: los
     dos creerian que les toca.

     Alerta_Deteccion guarda cuando se corrio por ultima vez para cada cliente,
     y el UPDATE que reclama el turno es ATOMICO: dos usuarios que entran en el
     mismo segundo no pueden ganar los dos. El que pierde no espera ni falla,
     simplemente no ejecuta.

   POR QUE ES SEGURO LLAMARLO TAN SEGUIDO COMO SE QUIERA

     GEN_ALERTA_INVENTARIO es idempotente: abre lo que empezo a pasar y cierra
     lo que dejo de pasar. Llamarlo de mas no duplica nada. Lo unico que hay
     que cuidar es el costo, y de eso se encarga el freno.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. CUANDO SE CORRIO POR ULTIMA VEZ
   ======================================================================== */
IF OBJECT_ID('dbo.Alerta_Deteccion') IS NULL
BEGIN
    CREATE TABLE [dbo].[Alerta_Deteccion] (
        [ade_cliente]   INT NOT NULL,
        [ade_fecha_utc] DATETIME NOT NULL,
        /* Cuantas abrio y cerro la ultima vez. No se usa para decidir nada:
           esta para poder responder "hace cuanto que esto no encuentra nada",
           que es la pregunta que uno se hace cuando sospecha que se rompio. */
        [ade_abiertas]  INT NULL,
        [ade_cerradas]  INT NULL,
        CONSTRAINT [PK_Alerta_Deteccion] PRIMARY KEY CLUSTERED ([ade_cliente]),
        CONSTRAINT [FK_Alerta_Deteccion_Cliente]
            FOREIGN KEY ([ade_cliente]) REFERENCES [dbo].[Cliente]([cli_id])
    )
    PRINT '--- Tabla Alerta_Deteccion creada'
END
ELSE PRINT '--- Tabla Alerta_Deteccion ya existia'
GO


/* ========================================================================
   2. EL TURNO

      Se llama en cada sondeo del navegador. Casi siempre contesta "todavia
      no toca" y no hace nada mas, que es exactamente lo que tiene que costar.
   ======================================================================== */
IF OBJECT_ID('dbo.GEN_ALERTA_DETECTAR') IS NOT NULL DROP PROCEDURE [dbo].[GEN_ALERTA_DETECTAR]
GO

CREATE PROCEDURE [dbo].[GEN_ALERTA_DETECTAR]
    @CLIENTE INT,
    @USUARIO INT,
    /* Cinco minutos: un repuesto no baja de su minimo dos veces en ese rato,
       y es corto para que quien acaba de registrar una salida vea el aviso
       antes de irse de la pantalla. */
    @MINUTOS INT = 5,
    /* El boton "Revisar ahora" pasa por aca igual, pero saltandose el freno:
       si alguien lo aprieta es porque quiere saber AHORA. */
    @FORZAR  BIT = 0
AS
SET NOCOUNT ON

DECLARE @AHORA DATETIME = GETUTCDATE()
DECLARE @TOCA BIT = 0

/* Se reclama el turno con un UPDATE condicional. Es atomico: de dos usuarios
   que entren en el mismo segundo, solo uno ve @@ROWCOUNT = 1. El otro sigue
   de largo sin esperar ni fallar. */
UPDATE [dbo].[Alerta_Deteccion]
SET    ade_fecha_utc = @AHORA
WHERE  ade_cliente = @CLIENTE
  AND  (@FORZAR = 1 OR DATEDIFF(MINUTE, ade_fecha_utc, @AHORA) >= @MINUTOS)

IF (@@ROWCOUNT = 1) SET @TOCA = 1

/* Primera vez para este cliente. El INSERT puede chocar si dos entran a la
   vez; el que pierde simplemente no ejecuta. */
IF (@TOCA = 0 AND NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Deteccion] WHERE ade_cliente = @CLIENTE))
BEGIN
    BEGIN TRY
        INSERT INTO [dbo].[Alerta_Deteccion] (ade_cliente, ade_fecha_utc)
        VALUES (@CLIENTE, @AHORA)

        SET @TOCA = 1
    END TRY
    BEGIN CATCH
        SET @TOCA = 0
    END CATCH
END

IF (@TOCA = 1)
BEGIN
    DECLARE @R TABLE (ABIERTAS INT, CERRADAS INT)

    INSERT INTO @R
    EXEC [dbo].[GEN_ALERTA_INVENTARIO] @CLIENTE = @CLIENTE, @USUARIO = @USUARIO

    UPDATE  d
    SET     d.ade_abiertas = r.ABIERTAS,
            d.ade_cerradas = r.CERRADAS
    FROM    [dbo].[Alerta_Deteccion] d
    CROSS JOIN (SELECT TOP 1 ABIERTAS, CERRADAS FROM @R) r
    WHERE   d.ade_cliente = @CLIENTE
END

/* Se devuelve el resumen SIEMPRE, corriera o no el detector: el navegador
   pregunta para refrescar sus numeros, y hacerle dar dos viajes -uno para
   detectar y otro para contar- seria el doble de trafico para lo mismo. */
EXEC [dbo].[SEL_ALERTA_RESUMEN] @CLIENTE = @CLIENTE, @USUARIO = @USUARIO

RETURN 0
GO


/* ========================================================================
   3. VERIFICACION
   ======================================================================== */
PRINT '--- Primera llamada: deberia detectar ---'
EXEC [dbo].[GEN_ALERTA_DETECTAR] @CLIENTE = 1, @USUARIO = 1

PRINT '--- Segunda seguida: el freno la detiene, pero contesta igual ---'
EXEC [dbo].[GEN_ALERTA_DETECTAR] @CLIENTE = 1, @USUARIO = 1

SELECT ade_cliente, ade_fecha_utc, ade_abiertas, ade_cerradas
FROM   [dbo].[Alerta_Deteccion]
GO
