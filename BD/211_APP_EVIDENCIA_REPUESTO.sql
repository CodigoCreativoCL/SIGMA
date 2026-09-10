USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  09-09-2026
-- DESCRIPTION:     LA FOTO DEL REPUESTO, SUBIDA DESDE LA APP.
-- =============================================
-- Bryan: «de la APP tambien se pueden subir imagenes del repuesto».
--
-- La ficha del repuesto ya tenia GALERIA para mirar y ninguna forma de subir:
-- las fotos solo podian entrar por la web. Y es al reves de lo util — quien
-- tiene la pieza en la mano es el bodeguero, en el pasillo, con el telefono.
--
-- POR QUE IMPORTA MAS DE LO QUE PARECE
--   Un rodamiento 6205 y uno 6310 se ven casi iguales en una lista. La foto de
--   la pieza REAL, con su empaque y su etiqueta, es lo que evita bajar al
--   equipo con la que no calza. Esa foto la saca quien la tiene delante.
--
-- `avi_repuesto` existe en Archivo_Vinculo desde siempre: lo unico que le
-- faltaba era la rama en estos dos SP, igual que le paso a COMPONENTE.
-- =============================================
SET NOCOUNT ON
GO

-- DESCRIPTION:     FOTOS DE EVIDENCIA DESDE EL TELEFONO.
-- =============================================
-- UN SP Y NO UNO POR PANTALLA
--
--   `Archivo_Vinculo` es polimorfica a proposito: tiene una columna por cada
--   cosa a la que se le puede colgar un archivo -orden, paso, falla, bitacora,
--   respuesta de checklist, hallazgo, permiso de trabajo, tarea-. El modelo ya
--   decidio que la evidencia es una sola idea con muchos duenos, asi que un
--   INS por pantalla seria repetir ocho veces la misma escritura y garantizar
--   que un dia difieran.
--
--   El @DESTINO dice a cual columna va. Es feo comparado con ocho SP, pero es
--   una fealdad que se lee en un solo lugar.
--
-- EL BLOB VA PRIMERO, LA FILA DESPUES
--
--   Es la regla que ya fijo `INS_ARCHIVO` y este bloque la respeta: una fila
--   sin blob es un enlace roto silencioso -alguien abre la foto meses despues
--   y no hay nada-, y un blob sin fila es basura que se puede recolectar. De
--   los dos desastres se elige el recuperable.
--
-- IDEMPOTENTE POR EL UUID DEL ARCHIVO
--
--   Lo genera el telefono al sacar la foto, no al enviarla. Una foto tomada
--   sin senal se reintenta varias veces; sin esto, la tarea quedaria con la
--   misma foto cuatro veces y nadie sabria cual mirar.
-- =============================================


-- ---------------------------------------------------------------------------
-- 1 - REGISTRAR UNA EVIDENCIA YA SUBIDA AL BLOB
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_EVIDENCIA]
     @ID INT = NULL OUTPUT
    ,@UUID              UNIQUEIDENTIFIER
    ,@USUARIO           INT
    ,@CLIENTE           INT

    /* TAREA | ORDEN | PASO | RESPUESTA | FALLA | HALLAZGO | ACTIVO */
    ,@DESTINO           NVARCHAR(20)
    ,@DESTINO_ID        INT

    ,@CATEGORIA         INT            = 5          -- 5 = DURANTE
    ,@NOMBRE_ORIGINAL   NVARCHAR(255)
    ,@NOMBRE_ALMACENADO NVARCHAR(255)
    ,@RUTA              NVARCHAR(500)
    ,@MIME              NVARCHAR(100)  = N'image/jpeg'
    ,@EXTENSION         NVARCHAR(20)   = N'jpg'
    ,@BYTE              BIGINT
    ,@HASH              NVARCHAR(64)   = NULL
    ,@ANCHO             INT            = NULL
    ,@ALTO              INT            = NULL
    ,@LATITUD           DECIMAL(9,6)   = NULL
    ,@LONGITUD          DECIMAL(9,6)   = NULL
    ,@CAPTURA_UTC       DATETIME       = NULL
    ,@DISPOSITIVO       NVARCHAR(400)  = NULL
    ,@TITULO            NVARCHAR(400)  = NULL
    ,@DESCRIPCION       NVARCHAR(1000) = NULL
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY

        DECLARE @DES NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@DESTINO, N''))))

        IF @DES NOT IN (N'TAREA', N'ORDEN', N'PASO', N'RESPUESTA',
                        N'FALLA', N'HALLAZGO', N'ACTIVO', N'BITACORA', N'COMPONENTE',
                        N'REPUESTO')
        BEGIN
            RAISERROR('Ese destino de evidencia no existe.', 16, 1)
            RETURN
        END

        /* ---- Reenvio de la cola: devolver lo mismo, no una segunda foto ---- */
        DECLARE @ARC INT

        SELECT @ARC = [arc_id] FROM [dbo].[Archivo] WHERE [arc_uuid] = @UUID

        IF @ARC IS NOT NULL
        BEGIN
            SET @ID = @ARC
            SELECT @ARC AS [arc_id], 1 AS [YA_ESTABA]
            RETURN
        END

        BEGIN TRANSACTION

        INSERT INTO [dbo].[Archivo]
            ([arc_uuid], [arc_cliente], [arc_archivo_categoria]
            ,[arc_nombre_original], [arc_nombre_almacenado], [arc_ruta]
            ,[arc_mime], [arc_extension], [arc_byte], [arc_hash]
            ,[arc_ancho_pixel], [arc_alto_pixel]
            ,[arc_latitud], [arc_longitud], [arc_fecha_captura_utc]
            ,[arc_dispositivo], [arc_archivo_antivirus_estado]
            ,[arc_usuario_creacion], [arc_fecha_creacion]
            ,[arc_usuario_actualizacion], [arc_fecha_actualizacion]
            ,[arc_habilitado])
        VALUES
            (@UUID, @CLIENTE, @CATEGORIA
            ,@NOMBRE_ORIGINAL, @NOMBRE_ALMACENADO, @RUTA
            ,@MIME, @EXTENSION, @BYTE, @HASH
            ,@ANCHO, @ALTO
            ,@LATITUD, @LONGITUD, @CAPTURA_UTC
            ,@DISPOSITIVO, 1                            -- 1 = PENDIENTE antivirus
            ,@USUARIO, GETDATE()
            ,@USUARIO, GETDATE()
            ,1)

        SET @ARC = SCOPE_IDENTITY()

        /* El orden dentro del destino: se muestran en el orden en que se
           sacaron, y con captura sin senal el id no respeta ese orden. */
        DECLARE @ORDEN INT =
            (SELECT ISNULL(MAX([avi_orden]), 0) + 1
               FROM [dbo].[Archivo_Vinculo]
              WHERE (@DES = N'TAREA'     AND [avi_tarea_ejecucion] = @DESTINO_ID)
                 OR (@DES = N'ORDEN'     AND [avi_orden_trabajo] = @DESTINO_ID)
                 OR (@DES = N'PASO'      AND [avi_orden_trabajo_paso] = @DESTINO_ID)
                 OR (@DES = N'RESPUESTA' AND [avi_checklist_ejecucion_respuesta] = @DESTINO_ID)
                 OR (@DES = N'FALLA'     AND [avi_falla] = @DESTINO_ID)
                 OR (@DES = N'HALLAZGO'  AND [avi_checklist_hallazgo] = @DESTINO_ID)
                 OR (@DES = N'ACTIVO'    AND [avi_activo] = @DESTINO_ID)
                 OR (@DES = N'BITACORA'  AND [avi_bitacora] = @DESTINO_ID)
                 OR (@DES = N'COMPONENTE' AND [avi_activo_componente] = @DESTINO_ID)
                 OR (@DES = N'REPUESTO'  AND [avi_repuesto] = @DESTINO_ID))

        INSERT INTO [dbo].[Archivo_Vinculo]
            ([avi_archivo]
            ,[avi_tarea_ejecucion], [avi_orden_trabajo], [avi_orden_trabajo_paso]
            ,[avi_checklist_ejecucion_respuesta], [avi_falla]
            ,[avi_checklist_hallazgo], [avi_activo], [avi_bitacora]
            ,[avi_activo_componente], [avi_repuesto]
            ,[avi_es_referencia], [avi_orden], [avi_titulo], [avi_descripcion]
            ,[avi_usuario_creacion], [avi_fecha_creacion], [avi_habilitado])
        VALUES
            (@ARC
            ,CASE WHEN @DES = N'TAREA'     THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'ORDEN'     THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'PASO'      THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'RESPUESTA' THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'FALLA'     THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'HALLAZGO'  THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'ACTIVO'    THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'BITACORA'  THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'COMPONENTE' THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'REPUESTO'  THEN @DESTINO_ID END
            /* Una foto de terreno nunca es �de referencia�: la referencia es
               como deberia verse el equipo, y esto es como se veia. */
            ,0, @ORDEN, @TITULO, @DESCRIPCION
            ,@USUARIO, GETDATE(), 1)

        COMMIT TRANSACTION
        SET @ID = @ARC
        SELECT @ARC AS [arc_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO

-- ---------------------------------------------------------------------------
--   Devuelve la ruta del blob, no los bytes. El telefono la pide despues por
--   `/archivo/ver` y la cachea; mandar las fotos dentro de la ficha haria que
--   abrir una tarea con seis fotos costara seis megas en terreno.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_EVIDENCIA]
     @USUARIO     INT
    ,@CLIENTE     INT
    ,@DESTINO     NVARCHAR(20)
    ,@DESTINO_ID  INT
AS
SET NOCOUNT ON

BEGIN

    DECLARE @DES NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@DESTINO, N''))))

    SELECT
         arc.[arc_id]
        ,arc.[arc_uuid]
        ,arc.[arc_ruta]
        ,arc.[arc_nombre_original]
        ,arc.[arc_mime]
        ,arc.[arc_byte]
        ,arc.[arc_ancho_pixel]
        ,arc.[arc_alto_pixel]
        ,arc.[arc_fecha_captura_utc]
        ,aca.[aca_codigo]              AS [CATEGORIA_CODIGO]
        ,aca.[aca_nombre]              AS [CATEGORIA_NOMBRE]
        ,avi.[avi_orden]
        ,avi.[avi_titulo]
        ,avi.[avi_descripcion]
        ,usr.[usu_nombre] + N' ' + ISNULL(usr.[usu_apellido_paterno], N'')
                                       AS [USUARIO_NOMBRE]
        ,arc.[arc_fecha_creacion]

      FROM [dbo].[Archivo_Vinculo]      avi
      JOIN [dbo].[Archivo]              arc ON arc.[arc_id] = avi.[avi_archivo]
 LEFT JOIN [dbo].[Archivo_Categoria]    aca ON aca.[aca_id] = arc.[arc_archivo_categoria]
 LEFT JOIN [dbo].[Usuario]              usr ON usr.[usu_id] = arc.[arc_usuario_creacion]

     WHERE arc.[arc_cliente]    = @CLIENTE
       AND arc.[arc_habilitado] = 1
       AND avi.[avi_habilitado] = 1
       AND (   (@DES = N'TAREA'     AND avi.[avi_tarea_ejecucion] = @DESTINO_ID)
            OR (@DES = N'ORDEN'     AND avi.[avi_orden_trabajo] = @DESTINO_ID)
            OR (@DES = N'PASO'      AND avi.[avi_orden_trabajo_paso] = @DESTINO_ID)
            OR (@DES = N'RESPUESTA' AND avi.[avi_checklist_ejecucion_respuesta] = @DESTINO_ID)
            OR (@DES = N'FALLA'     AND avi.[avi_falla] = @DESTINO_ID)
            OR (@DES = N'HALLAZGO'  AND avi.[avi_checklist_hallazgo] = @DESTINO_ID)
            OR (@DES = N'ACTIVO'    AND avi.[avi_activo] = @DESTINO_ID)
            OR (@DES = N'BITACORA'  AND avi.[avi_bitacora] = @DESTINO_ID)
            OR (@DES = N'COMPONENTE' AND avi.[avi_activo_componente] = @DESTINO_ID)
            OR (@DES = N'REPUESTO'  AND avi.[avi_repuesto] = @DESTINO_ID))

     ORDER BY avi.[avi_orden], arc.[arc_id]

END
GO
