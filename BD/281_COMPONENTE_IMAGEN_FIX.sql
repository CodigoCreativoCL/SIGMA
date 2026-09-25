USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  24-09-2026
-- DESCRIPTION:     ARREGLA EL VINCULO DE LA FOTO DEL COMPONENTE.
-- =============================================
-- VIN_ACTIVO_COMPONENTE_IMAGEN NUNCA PUDO GUARDAR NADA
--
--   El bloque 274 lo dejo insertando solo avi_activo_componente, y esa
--   columna NO es un padre para CK_AVI_UN_PADRE: el CHECK cuenta
--   orden_trabajo, paso, falla, bitacora, respuesta, item, actividad,
--   tarea_ejecucion, ACTIVO, repuesto, permiso y hallazgo, y exige
--   exactamente uno. Con todos en NULL la suma daba 0 y el INSERT se caia
--   con un 547.
--
--   Por eso en toda la base no hay ni una foto de componente: no es que
--   nadie haya subido ninguna, es que no se podia.
--
--   El padre correcto es el ACTIVO -la pieza cuelga de el- y
--   avi_activo_componente acompaña diciendo de que pieza suya se trata. Es
--   la misma forma que usa la evidencia de una orden cuando apunta a un paso.
--
--   El SEL no cambia: filtra por avi_activo_componente, que sigue siendo la
--   columna que identifica la pieza.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[VIN_ACTIVO_COMPONENTE_IMAGEN]
    @ID         INT = NULL OUTPUT,
    @COMPONENTE INT,
    @ARCHIVO    INT,
    @USUARIO    INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @CLIENTE INT, @ACTIVO INT, @NOW DATETIME, @PAIS INT

SELECT  @CLIENTE = aco_cliente,
        @ACTIVO  = aco_activo
  FROM  [dbo].[Activo_Componente]
 WHERE  aco_id = @COMPONENTE

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL COMPONENTE NO EXISTE.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo] WHERE arc_id = @ARCHIVO AND arc_cliente = @CLIENTE)
BEGIN
    RAISERROR('2.- EL ARCHIVO NO EXISTE O ES DE OTRO CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

BEGIN TRANSACTION

    /* Una sola vigente: la anterior se apaga en la misma transaccion. Si se
       apagara despues, un error en el medio dejaria dos y la pantalla
       mostraria la que viniera primero. */
    UPDATE  [dbo].[Archivo_Vinculo]
       SET  avi_habilitado = 0,
            avi_usuario_actualizacion = @USUARIO,
            avi_fecha_actualizacion = @NOW
     WHERE  avi_activo_componente = @COMPONENTE
       AND  avi_es_referencia = 1
       AND  ISNULL(avi_habilitado, 1) = 1

    INSERT INTO [dbo].[Archivo_Vinculo]
        ([avi_archivo], [avi_activo], [avi_activo_componente], [avi_es_referencia],
         [avi_usuario_creacion], [avi_fecha_creacion], [avi_habilitado])
    VALUES
        (@ARCHIVO, @ACTIVO, @COMPONENTE, 1, @USUARIO, @NOW, 1)

    SET @ID = SCOPE_IDENTITY()

COMMIT TRANSACTION

SELECT @ID AS ID
GO
PRINT '--- VIN_ACTIVO_COMPONENTE_IMAGEN corregido.'
GO

/* ========================================================================
   La foto del activo no puede confundirse con la de una pieza suya.

   SEL_ACTIVO_LISTA_RESUMEN y la galeria buscan la imagen del activo por
   avi_activo + avi_es_referencia. Ahora que la foto de un componente TAMBIEN
   lleva avi_activo, hay que exigir que avi_activo_componente sea NULL o el
   equipo aparece en la lista con la foto de su rodamiento.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_LISTA_RESUMEN]
    @CLIENTE INT
AS
SET NOCOUNT ON

DECLARE @HOY DATETIME = [dbo].[FNC_AHORA]()

    SELECT  a.act_id                                  AS ACTIVO_ID,

            (SELECT COUNT(*)
               FROM [dbo].[Orden_Trabajo] o
              WHERE o.otr_activo = a.act_id
                AND o.otr_cliente = @CLIENTE
                AND ISNULL(o.otr_orden_trabajo_estado, 0) <> 4)        AS OT_ABIERTAS,

            (SELECT COUNT(*)
               FROM [dbo].[Falla] f
              WHERE f.fal_activo = a.act_id
                AND ISNULL(f.fal_habilitado, 1) = 1
                AND f.fal_fecha_solucion_utc IS NULL)                  AS FALLAS_ABIERTAS,

            (SELECT COUNT(*)
               FROM [dbo].[Activo_Indisponibilidad] i
              WHERE i.ain_activo = a.act_id
                AND ISNULL(i.ain_habilitado, 1) = 1
                AND i.ain_fecha_fin_utc IS NULL)                       AS DETENCION_ABIERTA,

            (SELECT MIN(o.pmo_fecha_programada_utc)
               FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
              WHERE o.pmo_activo = a.act_id
                AND ISNULL(o.pmo_habilitado, 1) = 1
                AND ISNULL(o.pmo_plan_ocurrencia_estado, 1) NOT IN (4, 5, 6)
                AND o.pmo_fecha_programada_utc >= @HOY)                AS PROXIMA_MANTENCION,

            (SELECT TOP 1 v.avi_archivo
               FROM [dbo].[Archivo_Vinculo] v
               JOIN [dbo].[Archivo] arc ON arc.arc_id = v.avi_archivo
              WHERE v.avi_activo = a.act_id
                AND v.avi_es_referencia = 1

                /* La del EQUIPO, no la de una pieza suya. */
                AND v.avi_activo_componente IS NULL

                AND ISNULL(v.avi_habilitado, 1) = 1
                AND ISNULL(arc.arc_habilitado, 1) = 1
              ORDER BY v.avi_id DESC)                                  AS IMAGEN_ID

    FROM    [dbo].[Activo] a
    WHERE   a.act_cliente = @CLIENTE
GO
PRINT '--- SEL_ACTIVO_LISTA_RESUMEN actualizado: la foto del activo no es la de su pieza.'
GO

PRINT '281_COMPONENTE_IMAGEN_FIX aplicado.'
GO
