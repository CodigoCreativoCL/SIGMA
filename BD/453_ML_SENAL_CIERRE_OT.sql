/* ============================================================================
   453 · SIGMA AI: la señal de «se cerró una OT» (12-10-2026)

   Para qué
     El worker de SIGMA AI (ML/worker/sigma_worker.py) reentrena solo cada vez
     que se cierra una orden de trabajo. Para saberlo sin que nadie apriete un
     botón consulta cada pocos minutos esta señal: cuántas OT cerradas hay y
     cuándo fue el último cierre. Si el último cierre es posterior al que vio
     la vez anterior, hay datos nuevos.

   Qué devuelve (una fila, por cliente)
     CIERRES        OT cerradas habilitadas del cliente.
     ULTIMO_CIERRE  fecha del cierre más reciente (UTC de la base).
     ULTIMO_ID      id de la OT cerrada más reciente (desempata cierres iguales).

   Seguro: solo lee, es idempotente (CREATE OR ALTER) y usa el índice por cliente.
   ============================================================================ */
SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ML_SENAL]
     @CLIENTE INT
AS
BEGIN
    SET NOCOUNT ON

    SELECT  COUNT(*)                   AS CIERRES
           ,MAX(o.otr_fecha_cierre)    AS ULTIMO_CIERRE
           ,MAX(o.otr_id)              AS ULTIMO_ID
    FROM    [dbo].[Orden_Trabajo] o
    WHERE   o.otr_cliente      = @CLIENTE
      AND   o.otr_habilitado   = 1
      AND   o.otr_fecha_cierre IS NOT NULL
END
GO

PRINT '--- API_SEL_ML_SENAL creado (señal de cierre de OT para el worker de SIGMA AI).'
GO
