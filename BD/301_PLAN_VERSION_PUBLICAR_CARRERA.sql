USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- HU-084 #4 · Publicación simultánea.
--
-- La carrera YA estaba resuelta en el SP base (UPDATE ... WHERE estado =
-- BORRADOR y @@ROWCOUNT = 0 → rechazo), y la prueba con dos sesiones lo
-- confirma: la segunda queda bloqueada hasta que la primera confirma y
-- luego es rechazada. Lo que no calzaba era el MENSAJE: el criterio pide
-- «La versión ya no está en borrador» y el usuario rechazado leía «Solo se
-- publica una versión en borrador», que suena a error suyo y no a que otro
-- se le adelantó. Los dos puntos donde se decide (la validación del
-- envoltorio, que es donde cae la segunda sesión al desbloquearse, y el
-- UPDATE del SP base) dicen ahora lo mismo.
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_VERSION_PUBLICAR]
@ID          INT,
@CLIENTE     INT,
@OBSERVACION NVARCHAR(1000) = NULL,
@USUARIO     INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version] v
               JOIN [dbo].[Plan_Mantenimiento] p ON p.pma_id = v.pmv_plan_mantenimiento
               WHERE v.pmv_id = @ID AND p.pma_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA VERSION NO EXISTE.', 16, 1)
    RETURN -1
END

-- Si otro usuario la publicó mientras tanto, esta lectura espera su
-- bloqueo y ve el estado nuevo: el rechazo tiene que decir eso.
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Version] WHERE pmv_id = @ID AND pmv_plan_version_estado = 1)
BEGIN
    RAISERROR(N'2.- LA VERSIÓN YA NO ESTÁ EN BORRADOR: OTRO USUARIO LA PUBLICÓ O LA RETIRÓ.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito] WHERE pmh_plan_mantenimiento_version = @ID AND pmh_habilitado = 1)
BEGIN
    RAISERROR('3.- LA VERSION NO TIENE HITOS: NO GENERARIA NADA NUNCA.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo] WHERE pac_plan_mantenimiento_version = @ID)
BEGIN
    RAISERROR('4.- LA VERSION NO TIENE EQUIPOS: NO HABRIA PARA QUE MAQUINA GENERAR.', 16, 1)
    RETURN -1
END

BEGIN TRY
    BEGIN TRANSACTION

    IF @OBSERVACION IS NOT NULL
        UPDATE [dbo].[Plan_Mantenimiento_Version] SET pmv_observacion = @OBSERVACION WHERE pmv_id = @ID

    -- El SP base hace el trabajo: retira la publicada anterior y publica esta
    -- solo si TODAVIA es borrador (la carrera se decide ahi).
    EXEC [dbo].[UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR] @PMV_ID = @ID, @USUARIO = @USUARIO

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    RAISERROR(N'5.- %s', 16, 1, @MSG)
    RETURN -1
END CATCH

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- Proceso base: publica el borrador y retira la publicada anterior en la misma
-- transaccion. Con XACT_ABORT ON un error en cualquier UPDATE revierte todo.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR]
    @PMV_ID     INT,
    @USUARIO    INT
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON
    DECLARE @PLAN INT
    SELECT @PLAN = [pmv_plan_mantenimiento]
      FROM [dbo].[Plan_Mantenimiento_Version]
     WHERE [pmv_id] = @PMV_ID
    IF @PLAN IS NULL
    BEGIN
        RAISERROR('La version indicada no existe.', 16, 1)
        RETURN
    END
    -- Un plan sin hitos no se publica: no generaria nada nunca.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito]
                    WHERE [pmh_plan_mantenimiento_version] = @PMV_ID AND [pmh_habilitado] = 1)
    BEGIN
        RAISERROR('No se puede publicar una version sin hitos.', 16, 1)
        RETURN
    END
    -- Un plan sin activos tampoco: no habria para que maquina generar.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo]
                    WHERE [pac_plan_mantenimiento_version] = @PMV_ID)
    BEGIN
        RAISERROR('No se puede publicar una version sin activos asociados.', 16, 1)
        RETURN
    END
    BEGIN TRY
        BEGIN TRANSACTION
        -- Retira la publicada anterior del mismo plan.
        UPDATE [dbo].[Plan_Mantenimiento_Version]
           SET [pmv_plan_version_estado]  = 3,          -- RETIRADO
               [pmv_fecha_retiro]         = [dbo].[FNC_AHORA](),
               [pmv_usuario_actualizacion]= @USUARIO,
               [pmv_fecha_actualizacion]  = [dbo].[FNC_AHORA]()
         WHERE [pmv_plan_mantenimiento]   = @PLAN
           AND [pmv_plan_version_estado]  = 2
           AND [pmv_id]                  <> @PMV_ID
        UPDATE [dbo].[Plan_Mantenimiento_Version]
           SET [pmv_plan_version_estado]  = 2,          -- PUBLICADO
               [pmv_fecha_publicacion]    = [dbo].[FNC_AHORA](),
               [pmv_usuario_publicacion]  = @USUARIO,
               [pmv_usuario_actualizacion]= @USUARIO,
               [pmv_fecha_actualizacion]  = [dbo].[FNC_AHORA]()
         WHERE [pmv_id]                   = @PMV_ID
           AND [pmv_plan_version_estado]  = 1           -- <- la carrera se decide aqui
        IF @@ROWCOUNT = 0
            RAISERROR(N'La versión ya no está en borrador: otro usuario la publicó o la retiró.', 16, 1)
        COMMIT TRANSACTION
        SELECT @PMV_ID AS [pmv_id]
    END TRY
    BEGIN CATCH
        -- El ROLLBACK queda en un solo lugar: hacerlo antes del RAISERROR,
        -- dentro de la transacción del envoltorio, dejaba además el aviso
        -- de «transaction count mismatch» pegado al mensaje.
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH
END
GO

-- La prueba de la carrera (26-09-2026) restauró la observación de la v1 de
-- PMA-2 pasando el texto por la línea de comandos y la «ó» se perdió.
UPDATE [dbo].[Plan_Mantenimiento_Version]
   SET pmv_observacion = N'Publicada durante la ejecución de pruebas de HU-082.'
 WHERE pmv_id = 2 AND pmv_observacion LIKE N'Publicada durante la ejecuci%' AND pmv_observacion <> N'Publicada durante la ejecución de pruebas de HU-082.'
GO

PRINT '301_PLAN_VERSION_PUBLICAR_CARRERA aplicado.'
GO
