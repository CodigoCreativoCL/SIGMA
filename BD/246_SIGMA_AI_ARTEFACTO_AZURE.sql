/* ============================================================================
   SIGMA — Bloque 246
   AZURE ML ENTREGA EL MODELO: EL ARTEFACTO REGISTRADO, VERIFICADO EN LA API
   ----------------------------------------------------------------------------

   El bloque 245 dejo los pesos de cada version en `mpv_parametro` y el
   .onnx registrado en Azure ML. Faltaba cerrar el circulo: que la API
   pueda IR A BUSCAR ese artefacto al area de trabajo, comprobar que es el
   mismo que informo el entrenador (hash) y, si se quiere, tomar los pesos
   desde alli. Sin eso "registrado en Azure ML" era una anotacion; con
   esto es una fuente.

   COMO LLEGA SIN ENTIDAD DE SERVICIO
     El registro de modelos guarda los artefactos en la cuenta de
     almacenamiento del area de trabajo (`sigmacodigocreativo`, contenedor
     `azureml`), que es la misma cuenta a la que la API ya accede con su
     SAS para los archivos de SIGMA. No hace falta Entra ID: la ruta del
     artefacto (`azureml://.../datastores/workspaceartifactstore/paths/...`)
     se traduce a blob y se lee.

   LO QUE CAMBIA
     - `mpv_registro`: nombre:version del modelo en el registro de Azure ML
       ("SIGMA_FAILURE_30D:1"), para rastrearlo en Studio.
     - `mpv_fecha_verificacion_utc`: la ultima vez que la API bajo el
       artefacto y su hash coincidio con `mpv_hash`.
     - `mpv_ruta` pasa a ser la ruta del artefacto en el datastore (lo que
       `az ml model show` devuelve como `path`): es lo que la API descarga.
     - API_INS_ML_MODELO_VERSION recibe @REGISTRO.
     - API_UPD_ML_MODELO_VERSION_ARTEFACTO: la API deja constancia de la
       verificacion y, si se pide, reemplaza los pesos por los del
       artefacto (solo con hash coincidente: lo comprueba la API antes).
     - API_SEL_ML muestra registro y verificacion.

   IDEMPOTENTE.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON
GO

IF COL_LENGTH('dbo.Modelo_Predictivo_Version', 'mpv_registro') IS NULL
    ALTER TABLE [dbo].[Modelo_Predictivo_Version] ADD [mpv_registro] NVARCHAR(200) NULL
IF COL_LENGTH('dbo.Modelo_Predictivo_Version', 'mpv_fecha_verificacion_utc') IS NULL
    ALTER TABLE [dbo].[Modelo_Predictivo_Version] ADD [mpv_fecha_verificacion_utc] DATETIME NULL
GO

/* ---- la version 2 de SIGMA FAILURE 30D, entrenada el 18-09 contra SIGMA_AI ---- */
UPDATE [dbo].[Modelo_Predictivo_Version]
   SET [mpv_registro] = N'SIGMA_FAILURE_30D:1'
      ,[mpv_ruta] = N'azureml://subscriptions/af092419-a7e8-453a-b29a-8ef889109f66/resourceGroups/SIGMA/workspaces/SIGMA_AI/datastores/workspaceartifactstore/paths/ExperimentRun/dcid.319576fc-5bc5-4422-b5cc-ca9f799c8bcf/modelo'
 WHERE [mpv_id] = 5 AND [mpv_registro] IS NULL
   AND [mpv_ruta] LIKE N'azureml://%/models/SIGMA_FAILURE_30D/versions/1'
GO

/* ---------------------------------------------------------------------------
   API_INS_ML_MODELO_VERSION con @REGISTRO
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_INS_ML_MODELO_VERSION]
     @ID             INT OUTPUT
    ,@USUARIO        INT
    ,@MODELO         NVARCHAR(50)  = N'SIGMA FAILURE 30D'
    ,@DATASET        INT           = NULL
    ,@EJECUCION      INT           = NULL
    ,@FORMATO        NVARCHAR(20)  = N'ONNX'
    ,@ALGORITMO      NVARCHAR(100)
    ,@HIPERPARAMETRO NVARCHAR(MAX) = NULL
    ,@PARAMETRO      NVARCHAR(MAX)           -- JSON: caracteristicas, media, desviacion, coeficientes, intercepto
    ,@RUTA           NVARCHAR(500) = NULL    -- azureml://.../datastores/.../paths/... del artefacto
    ,@REGISTRO       NVARCHAR(200) = NULL    -- nombre:version en el registro de Azure ML
    ,@HASH           NVARCHAR(64)  = NULL
    ,@BYTE           BIGINT        = NULL
    ,@AUC            DECIMAL(18,6) = NULL
    ,@PRECISION      DECIMAL(18,6) = NULL
    ,@RECALL         DECIMAL(18,6) = NULL
    ,@F1             DECIMAL(18,6) = NULL
    ,@OBSERVACION    NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON
    DECLARE @MPR INT = (SELECT [mpr_id] FROM [dbo].[Modelo_Predictivo] WHERE [mpr_codigo] = @MODELO)
    IF @MPR IS NULL BEGIN RAISERROR('1.- EL MODELO %s NO EXISTE.', 16, 1, @MODELO) RETURN -1 END
    DECLARE @MFO INT = (SELECT [mfo_id] FROM [dbo].[Modelo_Formato] WHERE [mfo_codigo] = @FORMATO)
    IF @MFO IS NULL BEGIN RAISERROR('2.- EL FORMATO %s NO EXISTE.', 16, 1, @FORMATO) RETURN -1 END
    IF ISJSON(@PARAMETRO) <> 1 BEGIN RAISERROR('3.- LOS PARAMETROS DEL MODELO DEBEN VENIR EN JSON.', 16, 1) RETURN -1 END
    IF JSON_QUERY(@PARAMETRO, '$.caracteristicas') IS NULL OR JSON_QUERY(@PARAMETRO, '$.coeficientes') IS NULL
       OR JSON_VALUE(@PARAMETRO, '$.intercepto') IS NULL
        BEGIN RAISERROR('4.- LOS PARAMETROS DEBEN TRAER caracteristicas, coeficientes E intercepto.', 16, 1) RETURN -1 END

    BEGIN TRY
        BEGIN TRANSACTION
        DECLARE @N INT = ISNULL((SELECT MAX([mpv_numero]) FROM [dbo].[Modelo_Predictivo_Version] WHERE [mpv_modelo_predictivo] = @MPR), 0) + 1

        INSERT INTO [dbo].[Modelo_Predictivo_Version]
            ([mpv_modelo_predictivo], [mpv_dataset_entrenamiento], [mpv_numero], [mpv_modelo_formato]
            ,[mpv_algoritmo], [mpv_hiperparametro], [mpv_parametro], [mpv_ruta], [mpv_registro], [mpv_hash], [mpv_byte]
            ,[mpv_metrica_auc], [mpv_metrica_precision], [mpv_metrica_recall], [mpv_metrica_f1]
            ,[mpv_plan_version_estado], [mpv_fecha_entrenamiento_utc], [mpv_observacion]
            ,[mpv_usuario_creacion], [mpv_fecha_creacion], [mpv_habilitado])
        VALUES (@MPR, @DATASET, @N, @MFO
               ,@ALGORITMO, @HIPERPARAMETRO, @PARAMETRO, @RUTA, @REGISTRO, @HASH, @BYTE
               ,@AUC, @PRECISION, @RECALL, @F1
               ,1, GETUTCDATE(), @OBSERVACION            -- 1 = BORRADOR
               ,@USUARIO, GETDATE(), 1)
        SET @ID = SCOPE_IDENTITY()

        IF @EJECUCION IS NOT NULL
            UPDATE [dbo].[Entrenamiento_Ejecucion] SET [eej_modelo_predictivo_version] = @ID WHERE [eej_id] = @EJECUCION

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @E NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@E, 16, 1)
        RETURN -1
    END CATCH
GO

/* ---------------------------------------------------------------------------
   LA VERIFICACION (y, si se pide, los pesos desde el artefacto)
   La API baja el .onnx del area de trabajo, calcula su SHA-256 y solo
   llama aqui si coincide con mpv_hash (o si la version no tenia hash, en
   cuyo caso lo fija). Con @PARAMETRO reemplaza los pesos por los del JSON
   que acompana al artefacto.
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_UPD_ML_MODELO_VERSION_ARTEFACTO]
     @ID          INT
    ,@USUARIO     INT
    ,@HASH        NVARCHAR(64)
    ,@BYTE        BIGINT        = NULL
    ,@PARAMETRO   NVARCHAR(MAX) = NULL
    ,@OBSERVACION NVARCHAR(500) = NULL
AS
SET NOCOUNT ON
    DECLARE @HASH_ACTUAL NVARCHAR(64)
    SELECT @HASH_ACTUAL = [mpv_hash] FROM [dbo].[Modelo_Predictivo_Version] WHERE [mpv_id] = @ID AND [mpv_habilitado] = 1
    IF @@ROWCOUNT = 0 BEGIN RAISERROR('1.- LA VERSION NO EXISTE.', 16, 1) RETURN -1 END
    IF @HASH_ACTUAL IS NOT NULL AND @HASH_ACTUAL <> @HASH
        BEGIN RAISERROR('2.- EL ARTEFACTO DE AZURE ML NO ES EL QUE INFORMO EL ENTRENADOR (HASH DISTINTO). NO SE TOCA LA VERSION.', 16, 1) RETURN -1 END
    IF @PARAMETRO IS NOT NULL AND (ISJSON(@PARAMETRO) <> 1 OR JSON_QUERY(@PARAMETRO, '$.coeficientes') IS NULL)
        BEGIN RAISERROR('3.- LOS PESOS DEL ARTEFACTO NO SON UN JSON VALIDO.', 16, 1) RETURN -1 END

    UPDATE [dbo].[Modelo_Predictivo_Version]
       SET [mpv_hash] = @HASH
          ,[mpv_byte] = ISNULL(@BYTE, [mpv_byte])
          ,[mpv_parametro] = ISNULL(@PARAMETRO, [mpv_parametro])
          ,[mpv_fecha_verificacion_utc] = GETUTCDATE()
          ,[mpv_observacion] = CASE WHEN @OBSERVACION IS NULL THEN [mpv_observacion]
                                    ELSE LEFT(ISNULL([mpv_observacion], N'') + N' ' + @OBSERVACION, 4000) END
          ,[mpv_usuario_actualizacion] = @USUARIO, [mpv_fecha_actualizacion] = GETDATE()
     WHERE [mpv_id] = @ID
GO

/* ---------------------------------------------------------------------------
   API_SEL_ML con registro y verificacion
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ML]
     @CLIENTE INT
    ,@USUARIO INT          = NULL
    ,@TIPO    INT          = 1
    ,@MODELO  NVARCHAR(50) = N'SIGMA FAILURE 30D'
    ,@ID      INT          = NULL
AS
SET NOCOUNT ON
    DECLARE @MPR INT = (SELECT [mpr_id] FROM [dbo].[Modelo_Predictivo] WHERE [mpr_codigo] = @MODELO)

    IF @TIPO = 1
        SELECT m.[mpr_id], m.[mpr_codigo], m.[mpr_nombre], m.[mpr_descripcion], m.[mpr_horizonte_dia]
              ,m.[mpr_umbral_alerta], m.[mpr_umbral_critico]
              ,o.[mob_nombre] AS OBJETIVO
              ,v.[mpv_id] AS VERSION_ID, v.[mpv_numero] AS VERSION_NUMERO, v.[mpv_algoritmo] AS VERSION_ALGORITMO
              ,v.[mpv_parametro] AS VERSION_PARAMETRO, v.[mpv_ruta] AS VERSION_RUTA, v.[mpv_hash] AS VERSION_HASH
              ,v.[mpv_registro] AS VERSION_REGISTRO, v.[mpv_fecha_verificacion_utc] AS VERSION_VERIFICADA
              ,v.[mpv_metrica_auc] AS VERSION_AUC, v.[mpv_metrica_precision] AS VERSION_PRECISION
              ,v.[mpv_metrica_recall] AS VERSION_RECALL, v.[mpv_metrica_f1] AS VERSION_F1
              ,v.[mpv_fecha_publicacion] AS VERSION_PUBLICADA
              ,(SELECT COUNT(*) FROM [dbo].[Dataset_Entrenamiento] WHERE [den_modelo_predictivo] = m.[mpr_id] AND [den_cliente] = @CLIENTE) AS DATASETS
              ,(SELECT COUNT(*) FROM [dbo].[Entrenamiento_Ejecucion] WHERE [eej_modelo_predictivo] = m.[mpr_id]) AS CORRIDAS
              ,(SELECT COUNT(*) FROM [dbo].[Modelo_Predictivo_Version] WHERE [mpv_modelo_predictivo] = m.[mpr_id] AND [mpv_habilitado] = 1) AS VERSIONES
              ,(SELECT COUNT(*) FROM [dbo].[Prediccion] p JOIN [dbo].[Modelo_Predictivo_Version] pv ON pv.[mpv_id] = p.[pre_modelo_predictivo_version]
                 WHERE pv.[mpv_modelo_predictivo] = m.[mpr_id] AND p.[pre_cliente] = @CLIENTE AND p.[pre_habilitado] = 1
                   AND p.[pre_fecha_vigencia_hasta_utc] >= GETUTCDATE()) AS PREDICCIONES_VIGENTES
              ,(SELECT COUNT(*) FROM [dbo].[Activo] WHERE [act_cliente] = @CLIENTE AND [act_habilitado] = 1 AND [act_fusionado_en] IS NULL) AS ACTIVOS
              ,(SELECT COUNT(*) FROM [dbo].[Falla] WHERE [fal_cliente] = @CLIENTE AND [fal_habilitado] = 1) AS FALLAS
              ,(SELECT COUNT(*) FROM [dbo].[Activo_Medicion] WHERE [amd_cliente] = @CLIENTE) AS MEDICIONES
          FROM [dbo].[Modelo_Predictivo] m
          LEFT JOIN [dbo].[Modelo_Objetivo] o ON o.[mob_id] = m.[mpr_modelo_objetivo]
          LEFT JOIN [dbo].[Modelo_Predictivo_Version] v ON v.[mpv_modelo_predictivo] = m.[mpr_id]
                                                        AND v.[mpv_plan_version_estado] = 2 AND v.[mpv_habilitado] = 1
         WHERE m.[mpr_id] = @MPR

    IF @TIPO = 2
        SELECT d.[den_id], d.[den_codigo], d.[den_nombre], d.[den_fecha_desde], d.[den_fecha_hasta]
              ,d.[den_fila_total], d.[den_fila_positiva], d.[den_hash_datos], d.[den_ruta], d.[den_observacion], d.[den_fecha_creacion]
              ,(SELECT COUNT(*) FROM [dbo].[Modelo_Predictivo_Version] WHERE [mpv_dataset_entrenamiento] = d.[den_id]) AS VERSIONES
          FROM [dbo].[Dataset_Entrenamiento] d
         WHERE d.[den_modelo_predictivo] = @MPR AND d.[den_cliente] = @CLIENTE AND d.[den_habilitado] = 1
         ORDER BY d.[den_id] DESC

    IF @TIPO = 3
        SELECT e.[eej_id], e.[eej_dataset_entrenamiento], e.[eej_modelo_predictivo_version]
              ,pe.[pes_nombre] AS ESTADO, e.[eej_entorno], e.[eej_fecha_inicio_utc], e.[eej_fecha_fin_utc]
              ,e.[eej_segundo_duracion], e.[eej_metrica], e.[eej_mensaje]
              ,v.[mpv_numero] AS VERSION_NUMERO, d.[den_codigo] AS DATASET_CODIGO
          FROM [dbo].[Entrenamiento_Ejecucion] e
          LEFT JOIN [dbo].[Proceso_Estado] pe ON pe.[pes_id] = e.[eej_proceso_estado]
          LEFT JOIN [dbo].[Modelo_Predictivo_Version] v ON v.[mpv_id] = e.[eej_modelo_predictivo_version]
          LEFT JOIN [dbo].[Dataset_Entrenamiento] d ON d.[den_id] = e.[eej_dataset_entrenamiento]
         WHERE e.[eej_modelo_predictivo] = @MPR
           AND (d.[den_id] IS NULL OR d.[den_cliente] = @CLIENTE)
         ORDER BY e.[eej_id] DESC

    IF @TIPO = 4
        SELECT v.[mpv_id], v.[mpv_numero], f.[mfo_codigo] AS FORMATO, v.[mpv_algoritmo], v.[mpv_hiperparametro], v.[mpv_parametro]
              ,v.[mpv_ruta], v.[mpv_registro], v.[mpv_hash], v.[mpv_byte], v.[mpv_fecha_verificacion_utc]
              ,v.[mpv_metrica_auc], v.[mpv_metrica_precision], v.[mpv_metrica_recall], v.[mpv_metrica_f1]
              ,ve.[pve_nombre] AS ESTADO, v.[mpv_plan_version_estado]
              ,v.[mpv_fecha_entrenamiento_utc], v.[mpv_fecha_publicacion], v.[mpv_fecha_retiro], v.[mpv_observacion]
              ,d.[den_codigo] AS DATASET_CODIGO, d.[den_fila_total] AS DATASET_FILAS, d.[den_fila_positiva] AS DATASET_POSITIVAS
          FROM [dbo].[Modelo_Predictivo_Version] v
          LEFT JOIN [dbo].[Modelo_Formato] f ON f.[mfo_id] = v.[mpv_modelo_formato]
          LEFT JOIN [dbo].[Plan_Version_Estado] ve ON ve.[pve_id] = v.[mpv_plan_version_estado]
          LEFT JOIN [dbo].[Dataset_Entrenamiento] d ON d.[den_id] = v.[mpv_dataset_entrenamiento]
         WHERE v.[mpv_modelo_predictivo] = @MPR AND v.[mpv_habilitado] = 1
           AND (@ID IS NULL OR v.[mpv_id] = @ID)
           AND (d.[den_id] IS NULL OR d.[den_cliente] = @CLIENTE)
         ORDER BY v.[mpv_numero] DESC

    IF @TIPO = 5
        SELECT p.[pre_id], p.[pre_activo], a.[act_codigo] AS ACTIVO_CODIGO, a.[act_nombre] AS ACTIVO_NOMBRE
              ,p.[pre_probabilidad], p.[pre_severidad], cn.[crn_nombre] AS SEVERIDAD
              ,pe.[pde_nombre] AS ESTADO, p.[pre_fecha_calculo_utc], p.[pre_fecha_vigencia_hasta_utc]
              ,v.[mpv_numero] AS VERSION_NUMERO, p.[pre_alerta], p.[pre_orden_trabajo]
              ,(SELECT STRING_AGG(x.[pex_texto], N' | ') WITHIN GROUP (ORDER BY x.[pex_orden])
                  FROM [dbo].[Prediccion_Explicacion] x WHERE x.[pex_prediccion] = p.[pre_id]) AS EXPLICACION
          FROM [dbo].[Prediccion] p
          JOIN [dbo].[Modelo_Predictivo_Version] v ON v.[mpv_id] = p.[pre_modelo_predictivo_version]
          JOIN [dbo].[Activo] a ON a.[act_id] = p.[pre_activo]
          LEFT JOIN [dbo].[Criticidad_Nivel] cn ON cn.[crn_id] = p.[pre_severidad]
          LEFT JOIN [dbo].[Prediccion_Estado] pe ON pe.[pde_id] = p.[pre_prediccion_estado]
         WHERE v.[mpv_modelo_predictivo] = @MPR AND p.[pre_cliente] = @CLIENTE AND p.[pre_habilitado] = 1
           AND p.[pre_fecha_vigencia_hasta_utc] >= GETUTCDATE()
         ORDER BY p.[pre_probabilidad] DESC, a.[act_codigo]

    IF @TIPO = 6
        SELECT c.[cmo_id], c.[cmo_codigo], c.[cmo_etiqueta], c.[cmo_descripcion], c.[cmo_ventana_dia], c.[cmo_agregacion], c.[cmo_orden]
          FROM [dbo].[Caracteristica_Modelo] c
         WHERE c.[cmo_modelo_predictivo] = @MPR AND c.[cmo_habilitado] = 1
         ORDER BY c.[cmo_orden]
GO
PRINT '--- Bloque 246: el artefacto de Azure ML se verifica y puede entregar los pesos.'
GO
