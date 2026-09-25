/* ============================================================================
   SIGMA — Bloque 248
   SIGMA VISION: QUE MUESTRA UNA FOTO DE TERRENO
   ----------------------------------------------------------------------------

   El tercer objetivo de SIGMA AI, por el mismo camino (245/246/247) con una
   diferencia: el modelo no se entrena en el equipo de quien entrena sino en
   Azure Custom Vision (nivel F0, gratis: 2 proyectos, 5.000 imagenes, 1 h
   de entrenamiento y 10.000 predicciones al mes), que se usa con CLAVES y
   exporta el modelo a ONNX. El ONNX se registra en Azure ML con su hash
   como los otros dos; la prediccion la hace Custom Vision y la API solo la
   pide y la guarda.

   EL DATASET SON LAS IMAGENES CON ETIQUETA CONFIRMADA POR UNA PERSONA
     `Analisis_Visual_Deteccion.avd_confirmado_humano = 1`. Una etiqueta que
     puso otro modelo y nadie reviso no ensena nada: entrenar con ella es
     copiar sus errores. Por eso el dataset solo cuenta lo confirmado, y la
     clasificacion que hace la API queda SIN confirmar hasta que alguien
     la mire.

   LO QUE SALE
     Una fila en Analisis_Visual_Revision (motor SIGMA VISION, version de la
     iteracion) y una deteccion por etiqueta con su probabilidad, la mejor
     con la severidad que tenga asociada la etiqueta.

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

/* ---------------------------------------------------------------------------
   1. EL MODELO Y SUS "CARACTERISTICAS" (aqui son las etiquetas que aprende)
   --------------------------------------------------------------------------- */
DECLARE @ROOT INT = 1, @MPR INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Modelo_Predictivo] WHERE [mpr_codigo] = N'SIGMA VISION')
    INSERT INTO [dbo].[Modelo_Predictivo]
        ([mpr_cliente], [mpr_modelo_objetivo], [mpr_codigo], [mpr_nombre], [mpr_descripcion]
        ,[mpr_horizonte_dia], [mpr_umbral_alerta], [mpr_umbral_critico]
        ,[mpr_usuario_creacion], [mpr_fecha_creacion], [mpr_habilitado])
    VALUES
        (NULL, 4, N'SIGMA VISION', N'Clasificacion de fotos de terreno'
        ,N'Clasificador de imagenes entrenado en Azure Custom Vision (nivel F0) con las fotos que una persona etiqueto: normal, corrosion, fuga, desgaste, rotura, suciedad. Devuelve la etiqueta con su probabilidad; la API la guarda como revision visual sin confirmar. El modelo exportado a ONNX se registra en Azure ML con su hash.'
        ,NULL, 0.60, 0.85                               -- probabilidad minima para avisar / para severidad alta
        ,@ROOT, GETDATE(), 1)

SELECT @MPR = [mpr_id] FROM [dbo].[Modelo_Predictivo] WHERE [mpr_codigo] = N'SIGMA VISION'

DECLARE @C TABLE (codigo NVARCHAR(100), etiqueta NVARCHAR(200), descripcion NVARCHAR(500), orden INT)
INSERT INTO @C VALUES
 (N'NORMAL',    N'Normal',           N'Sin hallazgo visible.',                                        1)
,(N'CORROSION', N'Corrosion',        N'Oxido o corrosion en superficies metalicas.',                  2)
,(N'FUGA',      N'Fuga',             N'Aceite, agua u otro fluido fuera de su circuito.',             3)
,(N'DESGASTE',  N'Desgaste',         N'Desgaste visible de una pieza (correa, rodamiento, sello).',   4)
,(N'ROTURA',    N'Rotura',           N'Pieza rota, fisurada o deformada.',                           5)
,(N'SUCIEDAD',  N'Suciedad',         N'Acumulacion de polvo, residuo o material que impide operar.', 6)

INSERT INTO [dbo].[Caracteristica_Modelo]
    ([cmo_modelo_predictivo], [cmo_codigo], [cmo_etiqueta], [cmo_descripcion], [cmo_caracteristica_tipo]
    ,[cmo_ventana_dia], [cmo_agregacion], [cmo_orden], [cmo_obligatoria]
    ,[cmo_usuario_creacion], [cmo_fecha_creacion], [cmo_habilitado])
SELECT @MPR, c.codigo, c.etiqueta, c.descripcion, 2, NULL, NULL, c.orden, 0, @ROOT, GETDATE(), 1   -- 2 = CATEGORICA
  FROM @C c
 WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Caracteristica_Modelo] x WHERE x.[cmo_modelo_predictivo] = @MPR AND x.[cmo_codigo] = c.codigo)

DECLARE @NC INT = (SELECT COUNT(*) FROM [dbo].[Caracteristica_Modelo] WHERE [cmo_modelo_predictivo] = @MPR)
PRINT '--- Modelo SIGMA VISION: ' + LTRIM(STR(@MPR)) + ', etiquetas: ' + LTRIM(STR(@NC)) + ' (esperado 6)'
GO

/* ---------------------------------------------------------------------------
   2. EL DATASET: imagenes con etiqueta confirmada por una persona
      Misma firma que los otros dos para que la API no distinga. @DESDE /
      @HASTA acotan por fecha de confirmacion; @PASO_DIAS y @HOY no aplican
      (con @HOY = 1 devuelve las imagenes de los ultimos 30 dias sin etiqueta,
      que son las candidatas a clasificar).
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ML_DATASET_VISION]
     @CLIENTE   INT
    ,@USUARIO   INT      = NULL
    ,@DESDE     DATE     = NULL
    ,@HASTA     DATE     = NULL
    ,@PASO_DIAS INT      = 7
    ,@HOY       BIT      = 0
    ,@ACTIVO    INT      = NULL
AS
SET NOCOUNT ON
    IF @HOY = 1
    BEGIN
        SELECT a.[arc_id] AS ARCHIVO, a.[arc_ruta] AS RUTA, a.[arc_nombre_original] AS NOMBRE, a.[arc_mime] AS MIME, a.[arc_byte] AS BYTES
              ,a.[arc_ancho_pixel] AS ANCHO, a.[arc_alto_pixel] AS ALTO, a.[arc_fecha_creacion] AS CORTE
              ,ac.[aca_codigo] AS CATEGORIA
              ,CAST(NULL AS NVARCHAR(100)) AS ETIQUETA, CAST(NULL AS DECIMAL(9,6)) AS CONFIANZA, CAST(NULL AS NVARCHAR(50)) AS SEVERIDAD
              ,CAST(NULL AS NVARCHAR(200)) AS CONFIRMADO_POR, CAST(NULL AS DATETIME) AS CONFIRMADO_UTC
          FROM [dbo].[Archivo] a
          LEFT JOIN [dbo].[Archivo_Categoria] ac ON ac.[aca_id] = a.[arc_archivo_categoria]
         WHERE a.[arc_cliente] = @CLIENTE AND a.[arc_habilitado] = 1
           AND a.[arc_mime] LIKE 'image/%'
           AND a.[arc_archivo_categoria] IN (1, 2, 3, 4, 5, 6, 7, 10)      -- fotos de terreno, no firmas ni comprobantes
           AND a.[arc_fecha_creacion] >= DATEADD(DAY, -30, GETDATE())
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Analisis_Visual_Revision] r WHERE r.[avr_archivo] = a.[arc_id] AND r.[avr_habilitado] = 1)
         ORDER BY a.[arc_id] DESC
        RETURN
    END

    SELECT a.[arc_id] AS ARCHIVO, a.[arc_ruta] AS RUTA, a.[arc_nombre_original] AS NOMBRE, a.[arc_mime] AS MIME, a.[arc_byte] AS BYTES
          ,a.[arc_ancho_pixel] AS ANCHO, a.[arc_alto_pixel] AS ALTO, d.[avd_fecha_confirmacion_utc] AS CORTE
          ,ac.[aca_codigo] AS CATEGORIA
          ,UPPER(d.[avd_etiqueta]) AS ETIQUETA, d.[avd_confianza] AS CONFIANZA, s.[sev_codigo] AS SEVERIDAD
          ,u.[usu_login] AS CONFIRMADO_POR, d.[avd_fecha_confirmacion_utc] AS CONFIRMADO_UTC
      FROM [dbo].[Analisis_Visual_Deteccion] d
      JOIN [dbo].[Analisis_Visual_Revision] r ON r.[avr_id] = d.[avd_analisis_visual_revision]
      JOIN [dbo].[Archivo] a ON a.[arc_id] = r.[avr_archivo]
      LEFT JOIN [dbo].[Archivo_Categoria] ac ON ac.[aca_id] = a.[arc_archivo_categoria]
      LEFT JOIN [dbo].[Severidad] s ON s.[sev_id] = d.[avd_severidad]
      LEFT JOIN [dbo].[Usuario] u ON u.[usu_id] = d.[avd_usuario_confirmacion]
     WHERE r.[avr_cliente] = @CLIENTE AND r.[avr_habilitado] = 1 AND d.[avd_habilitado] = 1
       AND d.[avd_confirmado_humano] = 1
       AND a.[arc_habilitado] = 1
       AND (@DESDE IS NULL OR d.[avd_fecha_confirmacion_utc] >= @DESDE)
       AND (@HASTA IS NULL OR d.[avd_fecha_confirmacion_utc] < DATEADD(DAY, 1, @HASTA))
     ORDER BY d.[avd_fecha_confirmacion_utc], a.[arc_id]
GO
PRINT '--- API_SEL_ML_DATASET_VISION creado.'
GO

/* ---------------------------------------------------------------------------
   3. GUARDAR LO QUE DIJO CUSTOM VISION
      @ETIQUETAS: [{"nombre":"CORROSION","probabilidad":0.91}, ...]
      Una revision por archivo y motor por dia; las detecciones quedan SIN
      confirmar. Si el archivo no existe (imagen subida solo para probar),
      @ARCHIVO viene NULL y se guarda solo... nada: sin archivo no hay
      revision, y se devuelve 0. La API igual devuelve las etiquetas.
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_INS_ANALISIS_VISUAL]
     @ID           INT OUTPUT
    ,@CLIENTE      INT
    ,@USUARIO      INT
    ,@ARCHIVO      INT
    ,@MOTOR        NVARCHAR(200)
    ,@VERSION      NVARCHAR(200)
    ,@MILISEGUNDOS INT           = NULL
    ,@ETIQUETAS    NVARCHAR(MAX)
    ,@MENSAJE      NVARCHAR(1000) = NULL
AS
SET NOCOUNT ON
    SET @ID = 0
    IF @ARCHIVO IS NULL RETURN 0
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo] WHERE [arc_id] = @ARCHIVO AND [arc_cliente] = @CLIENTE)
        BEGIN RAISERROR('1.- EL ARCHIVO NO ES DEL CLIENTE EN SESION.', 16, 1) RETURN -1 END
    IF ISJSON(@ETIQUETAS) <> 1 BEGIN RAISERROR('2.- LAS ETIQUETAS DEBEN VENIR EN JSON.', 16, 1) RETURN -1 END

    DECLARE @UMB_ALERTA DECIMAL(18,6) = ISNULL((SELECT [mpr_umbral_alerta] FROM [dbo].[Modelo_Predictivo] WHERE [mpr_codigo] = N'SIGMA VISION'), 0.6)
    DECLARE @UMB_ALTA   DECIMAL(18,6) = ISNULL((SELECT [mpr_umbral_critico] FROM [dbo].[Modelo_Predictivo] WHERE [mpr_codigo] = N'SIGMA VISION'), 0.85)

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @E TABLE (nombre NVARCHAR(100), probabilidad DECIMAL(9,6))
        INSERT INTO @E SELECT UPPER(LEFT(j.nombre, 100)), CAST(j.probabilidad AS DECIMAL(9,6))
          FROM OPENJSON(@ETIQUETAS) WITH (nombre NVARCHAR(100) '$.nombre', probabilidad FLOAT '$.probabilidad') j
         WHERE j.nombre IS NOT NULL

        DECLARE @MAX DECIMAL(9,6) = (SELECT MAX(probabilidad) FROM @E)

        INSERT INTO [dbo].[Analisis_Visual_Revision]
            ([avr_cliente], [avr_archivo], [avr_motor], [avr_modelo_version], [avr_proceso_estado]
            ,[avr_deteccion_cantidad], [avr_confianza_maxima], [avr_milisegundo_proceso], [avr_fecha_proceso_utc]
            ,[avr_revisado_humano], [avr_mensaje], [avr_usuario_creacion], [avr_fecha_creacion], [avr_habilitado])
        VALUES (@CLIENTE, @ARCHIVO, @MOTOR, @VERSION, 3                                   -- 3 = PROCESADO
               ,(SELECT COUNT(*) FROM @E WHERE probabilidad >= @UMB_ALERTA), @MAX, @MILISEGUNDOS, GETUTCDATE()
               ,0, @MENSAJE, @USUARIO, GETDATE(), 1)
        SET @ID = SCOPE_IDENTITY()

        /* Una deteccion por etiqueta que supere el umbral de aviso; si ninguna
           lo supera, la mejor igual queda, marcada por su probabilidad baja.
           La severidad sale del nombre: NORMAL = normal; ROTURA/FUGA = alta o
           critica segun probabilidad; el resto advertencia. */
        INSERT INTO [dbo].[Analisis_Visual_Deteccion]
            ([avd_analisis_visual_revision], [avd_etiqueta], [avd_confianza], [avd_severidad], [avd_descripcion]
            ,[avd_confirmado_humano], [avd_usuario_creacion], [avd_fecha_creacion], [avd_habilitado])
        SELECT @ID, e.nombre, e.probabilidad
              ,CASE WHEN e.nombre = N'NORMAL' THEN 1
                    WHEN e.nombre IN (N'ROTURA', N'FUGA') AND e.probabilidad >= @UMB_ALTA THEN 5
                    WHEN e.nombre IN (N'ROTURA', N'FUGA') THEN 4
                    WHEN e.probabilidad >= @UMB_ALTA THEN 4
                    ELSE 3 END
              ,CONCAT(N'SIGMA VISION (', @VERSION, N'): ', e.nombre, N' con ', CAST(CAST(ROUND(e.probabilidad * 100, 0) AS INT) AS NVARCHAR(10)), N' %. Sin confirmar.')
              ,0, @USUARIO, GETDATE(), 1
          FROM @E e
         WHERE e.probabilidad >= @UMB_ALERTA OR e.probabilidad = @MAX

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @ERR NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@ERR, 16, 1)
        RETURN -1
    END CATCH
GO
PRINT '--- API_INS_ANALISIS_VISUAL creado.'
GO

/* ---------------------------------------------------------------------------
   4. CONFIRMAR (O CORREGIR) UNA DETECCION: lo que alimenta el proximo dataset
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_UPD_ANALISIS_VISUAL_CONFIRMAR]
     @ID       INT             -- avd_id
    ,@CLIENTE  INT
    ,@USUARIO  INT
    ,@ETIQUETA NVARCHAR(100) = NULL   -- vacio = confirma la que esta; con valor = la corrige
AS
SET NOCOUNT ON
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Analisis_Visual_Deteccion] d
                    JOIN [dbo].[Analisis_Visual_Revision] r ON r.[avr_id] = d.[avd_analisis_visual_revision]
                   WHERE d.[avd_id] = @ID AND r.[avr_cliente] = @CLIENTE)
        BEGIN RAISERROR('1.- LA DETECCION NO ES DEL CLIENTE EN SESION.', 16, 1) RETURN -1 END

    UPDATE [dbo].[Analisis_Visual_Deteccion]
       SET [avd_etiqueta] = ISNULL(NULLIF(UPPER(LEFT(@ETIQUETA, 100)), N''), [avd_etiqueta])
          ,[avd_confirmado_humano] = 1, [avd_usuario_confirmacion] = @USUARIO, [avd_fecha_confirmacion_utc] = GETUTCDATE()
          ,[avd_usuario_actualizacion] = @USUARIO, [avd_fecha_actualizacion] = GETDATE()
     WHERE [avd_id] = @ID

    UPDATE r SET r.[avr_revisado_humano] = 1, r.[avr_usuario_revision] = @USUARIO
      FROM [dbo].[Analisis_Visual_Revision] r
      JOIN [dbo].[Analisis_Visual_Deteccion] d ON d.[avd_analisis_visual_revision] = r.[avr_id]
     WHERE d.[avd_id] = @ID
GO
/* ---------------------------------------------------------------------------
   5. UN ARCHIVO POR ID, DEL CLIENTE EN SESION (la API baja la imagen a clasificar)
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ARCHIVO_ID]
     @ID      INT
    ,@CLIENTE INT
AS
SET NOCOUNT ON
    SELECT TOP 1 a.[arc_id] AS ARC_ID, a.[arc_ruta] AS ARC_RUTA, a.[arc_mime] AS ARC_MIME, a.[arc_nombre_original] AS ARC_NOMBRE
      FROM [dbo].[Archivo] a
     WHERE a.[arc_id] = @ID AND a.[arc_cliente] = @CLIENTE AND a.[arc_habilitado] = 1
GO

PRINT '--- Bloque 248: SIGMA VISION listo para el camino completo.'
GO
