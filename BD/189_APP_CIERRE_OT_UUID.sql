USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     IDEMPOTENCIA POR UUID EN EL CIERRE DE LA ORDEN DE TRABAJO.
-- =============================================
-- HU-120. El cierre entra a la app y, como toda captura de terreno, se encola:
-- el supervisor cierra desde el telefono y la cola reintenta. Sin corte por
-- uuid, el reintento de un cierre que SI entro vuelve a pasar por las
-- validaciones y muere en "La OT no esta en espera de cierre" -porque ya esta
-- en 4-, es decir, falla por haber funcionado. La cola lo marcaria rechazado y
-- el supervisor veria un error rojo sobre una OT correctamente cerrada.
--
-- Es el mismo patron de los scripts 177, 186 y 188: el corte va ANTES de toda
-- validacion, no despues. Puesto despues, la segunda llamada tendria que
-- volver a satisfacer reglas que el mundo ya cambio.
--
-- POR QUE UNA COLUMNA PROPIA Y NO otr_uuid
--   `otr_uuid` es el uuid de CREACION de la orden: lo usa API_INS_ORDEN_TRABAJO
--   para que un alta reintentada no cree dos OT. Reusarlo para el cierre
--   confundiria dos hechos distintos -nacer y cerrarse- en una sola columna, y
--   una OT creada desde la app ya lo trae ocupado.
--
-- LO QUE ESTE SCRIPT NO TOCA
--   Las reglas del cierre no cambian: la jerarquia por permiso -no por nombre
--   de perfil-, el estado 3 previo, el motivo habilitado y el bloqueo por
--   permiso de trabajo sin autorizar quedan exactamente como estaban.
-- =============================================
SET NOCOUNT ON
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID('[dbo].[Orden_Trabajo]')
                  AND name = 'otr_cierre_uuid')
BEGIN
    ALTER TABLE [dbo].[Orden_Trabajo]
        ADD otr_cierre_uuid UNIQUEIDENTIFIER NULL
END
GO

/* Filtrado: las OT que cierra la web no llevan uuid y son todas NULL; un
   unique normal dejaria pasar una sola en toda la tabla. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE object_id = OBJECT_ID('[dbo].[Orden_Trabajo]')
                  AND name = 'UQ_OTR_CIERRE_UUID')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_OTR_CIERRE_UUID
        ON [dbo].[Orden_Trabajo](otr_cierre_uuid)
        WHERE otr_cierre_uuid IS NOT NULL
END
GO

/* ========================================================================
   UPD_ORDEN_TRABAJO_CERRAR
      Lo que hace el planificador, el supervisor o el jefe. Nadie mas.
      Ahora idempotente por uuid, para poder encolarse desde el telefono.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPD_ORDEN_TRABAJO_CERRAR]
    @ORDEN_TRABAJO  INT,
    @USUARIO        INT,
    @CIERRE_MOTIVO  INT,
    @OBSERVACION    NVARCHAR(500) = NULL,
    /* Nace en el telefono AL ENCOLAR. Opcional: la web no lo manda. */
    @UUID           UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON

    /* ---- Idempotencia: si el uuid ya cerro una OT, se responde lo mismo ----
       Va ANTES de toda validacion. Sin esto, el reintento de un cierre que ya
       entro respondia "La OT no esta en espera de cierre" -porque este mismo
       uuid la dejo en 4-, y la cola marcaba rechazado un cierre correcto. */
    IF (@UUID IS NOT NULL)
    BEGIN
        DECLARE @YA INT = NULL

        SELECT @YA = [otr_id] FROM [dbo].[Orden_Trabajo]
         WHERE [otr_cierre_uuid] = @UUID

        IF (@YA IS NOT NULL)
        BEGIN
            SELECT @YA AS ORDEN_TRABAJO, 4 AS ESTADO, N'CERRADA' AS ESTADO_NOMBRE
            RETURN
        END
    END

    DECLARE @CLIENTE INT
    SELECT @CLIENTE = otr_cliente FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN_TRABAJO

    IF @CLIENTE IS NULL
    BEGIN
        RAISERROR('La orden de trabajo no existe.', 16, 1)
        RETURN
    END

    -- La regla de jerarquia. El tecnico finaliza; cerrar es de otros.
    IF [dbo].[FNC_USUARIO_PUEDE_CERRAR_OT](@CLIENTE, @USUARIO) = 0
    BEGIN
        RAISERROR('Este usuario no puede cerrar ordenes de trabajo. El cierre es del planificador, el supervisor o el jefe de mantenimiento.', 16, 1)
        RETURN
    END

    /* El texto NO dice "no existe" a proposito: `ErrorSql` traduce a 404 todo
       mensaje que contenga esa frase, y un 404 sobre /ordenes-trabajo/{id}/cerrar
       le dice a la app que la ORDEN no existe cuando lo que no sirve es un campo
       del cuerpo. Redactado asi cae en el 400 que le corresponde a un valor
       invalido. Arreglarlo en ErrorSql habria cambiado el codigo de los ~150 SP
       que comparten ese traductor. */
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Cierre_Motivo] WHERE ocm_id = @CIERRE_MOTIVO AND ocm_habilitado = 1)
    BEGIN
        RAISERROR('El motivo de cierre no es valido o fue deshabilitado.', 16, 1)
        RETURN
    END

    -- Un permiso de trabajo exigido y no autorizado bloquea el cierre.
    -- Cerrar una OT cuyo permiso nunca se firmo es documentar una mentira.
    IF EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo]
                WHERE ptr_orden_trabajo = @ORDEN_TRABAJO
                  AND ptr_permiso_trabajo_estado NOT IN (2, 5))   -- AUTORIZADO o CERRADO
    BEGIN
        RAISERROR('Hay permisos de trabajo sin autorizar. No se puede cerrar la OT.', 16, 1)
        RETURN
    END

    UPDATE [dbo].[Orden_Trabajo]
       SET otr_orden_trabajo_estado  = 4,      -- CERRADA
           otr_cierre_motivo         = @CIERRE_MOTIVO,
           otr_usuario_cierre        = @USUARIO,
           otr_fecha_cierre          = GETDATE(),
           otr_cierre_uuid           = @UUID,
           otr_usuario_actualizacion = @USUARIO,
           otr_fecha_actualizacion   = GETDATE()
     WHERE otr_id = @ORDEN_TRABAJO
       AND otr_orden_trabajo_estado = 3        -- solo desde EN ESPERA DE CIERRE

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('La OT no esta en espera de cierre. El tecnico tiene que finalizarla primero.', 16, 1)
        RETURN
    END

    INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
        ([oeh_orden_trabajo], [oeh_estado_nuevo], [oeh_motivo], [oeh_usuario_creacion])
    VALUES (@ORDEN_TRABAJO, 4, @OBSERVACION, @USUARIO)

    SELECT @ORDEN_TRABAJO AS ORDEN_TRABAJO, 4 AS ESTADO, N'CERRADA' AS ESTADO_NOMBRE
END
GO

/* ========================================================================
   API_SEL_ORDEN_TRABAJO_CIERRE_MOTIVO
      El catalogo para la hoja de cierre de la app.

      La app no puede traer los seis motivos escritos adentro: son un dato de
      la empresa y se habilitan o deshabilitan desde la web. Una lista quemada
      en el telefono obliga a publicar una version nueva cada vez que cambie, y
      deja al supervisor eligiendo un motivo que el SP ya rechaza.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ORDEN_TRABAJO_CIERRE_MOTIVO]
    @HABILITADO BIT = 1
AS
BEGIN
    SET NOCOUNT ON

    SELECT [ocm_id], [ocm_codigo], [ocm_nombre], [ocm_orden]
      FROM [dbo].[Orden_Trabajo_Cierre_Motivo]
     WHERE (@HABILITADO IS NULL OR [ocm_habilitado] = @HABILITADO)
     ORDER BY ISNULL([ocm_orden], 999), [ocm_nombre]
END
GO
