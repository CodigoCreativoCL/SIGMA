/* ============================================================================
   SIGMA — Bloque 112
   LA CONDICION QUE VUELVE A DARSE
   ----------------------------------------------------------------------------

   LO QUE YA FUNCIONABA

     `GEN_ALERTA_INVENTARIO` nunca duplica: antes de insertar comprueba con un
     NOT EXISTS si ya hay una alerta ABIERTA para la misma llave funcional
     -cliente + tipo + repuesto + bodega + lote-. Eso estaba bien y no se
     toca.

   LO QUE FALTABA

     Al no insertar tampoco dejaba rastro. Un repuesto que cae bajo el minimo
     el lunes, se repone el martes y vuelve a caer el miercoles se veia igual
     que uno que cayo una sola vez hace tres semanas: misma alerta, misma
     fecha, ningun indicio de que el problema es cronico.

     El bloque 110 agrego las columnas. Este las llena: cada pasada del
     detector, para cada condicion que SIGUE dandose, adelanta la fecha de
     ultima ocurrencia y suma uno al contador. La primera deteccion no se
     mueve nunca: es la respuesta a "¿desde cuando arrastramos esto?".

   POR QUE UN PROCEDIMIENTO APARTE Y NO DENTRO DEL DETECTOR

     `GEN_ALERTA_INVENTARIO` arma sus hallazgos en #HALLAZGO y despues inserta
     lo que no existe. Reabrirlo para agregar un UPDATE significa tocar un
     procedimiento de 200 lineas que hoy funciona y esta probado. Este SP hace
     una cosa sola, se llama justo despues, y se puede leer entero de una vez.

   LA CONDICION RESUELTA VUELVE COMO ALERTA NUEVA

     Si la alerta se cerro y el problema reaparece, el NOT EXISTS del detector
     ya no la encuentra -solo mira las abiertas- y crea una nueva, con su
     contador en uno. Eso es lo correcto: son dos episodios distintos y el
     historial tiene que poder contarlos por separado.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.UPD_ALERTA_REPETICION') IS NOT NULL
    DROP PROCEDURE [dbo].[UPD_ALERTA_REPETICION]
GO

CREATE PROCEDURE [dbo].[UPD_ALERTA_REPETICION]
    @CLIENTE    INT,
    @ALERTA     INT = NULL      /* NULL = todas las que siguen abiertas */
AS
SET NOCOUNT ON

DECLARE @AHORA DATETIME = GETUTCDATE()

    UPDATE  a
       SET  a.ale_fecha_ultima_ocurrencia_utc = @AHORA,
            a.ale_ocurrencias = a.ale_ocurrencias + 1,

            /* Se rellena por si la alerta es anterior al bloque 110 y nacio
               sin primera ocurrencia. No se pisa nunca si ya tiene valor. */
            a.ale_fecha_primera_ocurrencia_utc =
                ISNULL(a.ale_fecha_primera_ocurrencia_utc, a.ale_fecha_deteccion_utc)
      FROM  [dbo].[Alerta] a
      JOIN  [dbo].[Alerta_Estado] e ON e.aet_id = a.ale_alerta_estado
     WHERE  a.ale_cliente = @CLIENTE
       AND  a.ale_habilitado = 1
       AND  e.aet_codigo NOT IN ('RESUELTA', 'DESCARTADA')
       AND  (@ALERTA IS NULL OR a.ale_id = @ALERTA)
       /* Solo si la deteccion es de OTRA pasada. Sin esto, dos ejecuciones
          seguidas del detector —el boton "Revisar ahora" apretado dos veces—
          contarian dos repeticiones de un problema que ocurrio una vez. */
       AND  DATEDIFF(MINUTE, ISNULL(a.ale_fecha_ultima_ocurrencia_utc,
                                    a.ale_fecha_deteccion_utc), @AHORA) >= 1

    SELECT REPETIDAS = @@ROWCOUNT
GO

PRINT '--- UPD_ALERTA_REPETICION creado.'
GO


/* ========================================================================
   VERIFICACION

      Se prueba sobre las alertas de demo: contador antes, una pasada, y
      contador despues. Es la unica forma de saber que la regla del minuto
      hace lo que dice.
   ======================================================================== */
SELECT  paso = 'antes',
        ale_id, ale_ocurrencias,
        primera = ale_fecha_primera_ocurrencia_utc,
        ultima  = ale_fecha_ultima_ocurrencia_utc
FROM    [dbo].[Alerta]
WHERE   ale_cliente = 1
ORDER BY ale_id
GO

EXEC [dbo].[UPD_ALERTA_REPETICION] @CLIENTE = 1
GO

SELECT  paso = 'despues',
        ale_id, ale_ocurrencias,
        primera = ale_fecha_primera_ocurrencia_utc,
        ultima  = ale_fecha_ultima_ocurrencia_utc
FROM    [dbo].[Alerta]
WHERE   ale_cliente = 1
ORDER BY ale_id
GO

PRINT '112_ALERTA_REPETICION aplicado.'
GO
