USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
/* QUOTED_IDENTIFIER ON al crear: Alerta tiene un indice filtrado (IX_ALE_ABIERTA) y sin esto
   el SP queda compilado con OFF y su INSERT falla (error 1934). Asi se corto la entrega de campanas. */
SET QUOTED_IDENTIFIER ON
GO
/* 381 — «Te puede interesar»: la card no desaparece tras la primera vista.
   SEL_CAMPANA_PENDIENTES devuelve ahora la columna MOSTRAR (1 = la frecuencia permite interrumpir con modal/banner). 
   El aviso de la campana (formato notificacion) quedaba al final del panel de alertas: SEL_ALERTA ordena por
   ale_fecha_deteccion_utc DESC y la alerta nacia con ese campo en NULL. Ahora nace con la fecha y se corrigen las ya creadas. IDEMPOTENTE. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CAMPANA_PENDIENTES]
    @USUARIO INT,
    @CLIENTE INT,
    @MODULO  NVARCHAR(150) = NULL
AS
SET NOCOUNT ON
    EXEC [dbo].[UPD_CAMPANA_VIGENCIA]
    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
    DECLARE @C TABLE (cam_id INT PRIMARY KEY)
    INSERT INTO @C (cam_id)
    SELECT  c.cam_id
    FROM    [dbo].[Campana] c
    WHERE   c.cam_habilitado = 1 AND c.cam_estado = 'activa'
      AND   c.cam_desde <= @AHORA AND (c.cam_hasta IS NULL OR c.cam_hasta >= @AHORA)
      AND   EXISTS (SELECT 1 FROM [dbo].[FNC_CAMPANA_AUDIENCIA]([dbo].[FNC_CAMPANA_CONDICIONES](c.cam_id), c.cam_union, @USUARIO) a
                     WHERE a.cliente = @CLIENTE)
    IF NOT EXISTS (SELECT 1 FROM @C) RETURN
    /* La fila de entrega existe desde que le corresponde, aunque no la vea:
       ahi se cuelga su aviso en la campana. */
    INSERT INTO [dbo].[Campana_Entrega] (cen_campana, cen_usuario, cen_cliente)
    SELECT c.cam_id, @USUARIO, @CLIENTE FROM @C c
     WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Campana_Entrega] e WHERE e.cen_campana = c.cam_id AND e.cen_usuario = @USUARIO AND e.cen_cliente = @CLIENTE)
    /* Formato «Centro de notificaciones»: una alerta dirigida, una vez. */
    DECLARE @TIPO INT = (SELECT alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = N'CAMPANA')
    DECLARE @NUEVA INT = (SELECT aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'NUEVA')
    DECLARE @E INT, @CAM INT
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT e.cen_id, e.cen_campana FROM [dbo].[Campana_Entrega] e JOIN @C c ON c.cam_id = e.cen_campana
          JOIN [dbo].[Campana] k ON k.cam_id = e.cen_campana
         WHERE e.cen_usuario = @USUARIO AND e.cen_cliente = @CLIENTE AND e.cen_alerta IS NULL
           AND (',' + k.cam_formatos + ',') LIKE '%,notif,%'
    OPEN cur
    FETCH NEXT FROM cur INTO @E, @CAM
    WHILE @@FETCH_STATUS = 0
    BEGIN
        INSERT INTO [dbo].[Alerta] (ale_cliente, ale_alerta_tipo, ale_alerta_estado, ale_titulo, ale_descripcion, ale_usuario_destinatario,
                                    ale_campana, ale_ayuda_contenido, ale_usuario_creacion, ale_fecha_primera_ocurrencia_utc, ale_fecha_ultima_ocurrencia_utc, ale_fecha_deteccion_utc)
        SELECT @CLIENTE, @TIPO, @NUEVA, k.cam_titulo, k.cam_descripcion, @USUARIO, k.cam_id, k.cam_contenido, k.cam_usuario_creacion, GETUTCDATE(), GETUTCDATE(), GETUTCDATE()
          FROM [dbo].[Campana] k WHERE k.cam_id = @CAM
        UPDATE [dbo].[Campana_Entrega] SET cen_alerta = SCOPE_IDENTITY() WHERE cen_id = @E
        FETCH NEXT FROM cur INTO @E, @CAM
    END
    CLOSE cur
    DEALLOCATE cur
    /* Las que se muestran ahora, segun su frecuencia y donde aparecen. */
    SELECT  k.cam_id, k.cam_tipo, k.cam_titulo, k.cam_descripcion, k.cam_medio, k.cam_tema, k.cam_archivo, k.cam_formatos, k.cam_presentacion,
            k.cam_cerrable, k.cam_confirmar, k.cam_cta_accion, k.cam_cta_texto, k.cam_cta_destino,
            k.cam_contenido, a.ayc_titulo AS CONTENIDO_TITULO, a.ayc_tipo AS CONTENIDO_TIPO, k.cam_frecuencia,
            e.cen_veces,
            MOSTRAR = CASE k.cam_frecuencia
                WHEN 'una'     THEN CASE WHEN e.cen_veces = 0 THEN 1 ELSE 0 END
                WHEN 'usuario' THEN CASE WHEN NOT EXISTS (SELECT 1 FROM [dbo].[Campana_Entrega] x WHERE x.cen_campana = k.cam_id AND x.cen_usuario = @USUARIO AND x.cen_veces > 0) THEN 1 ELSE 0 END
                WHEN 'leer'    THEN CASE WHEN e.cen_fecha_descarte IS NULL THEN 1 ELSE 0 END
                WHEN 'repetir' THEN CASE WHEN e.cen_veces = 0 OR e.cen_fecha_ultima <= DATEADD(DAY, -ISNULL(k.cam_cada_dias, 7), @AHORA) THEN 1 ELSE 0 END
                ELSE 0 END
    FROM    @C c
    JOIN    [dbo].[Campana] k ON k.cam_id = c.cam_id
    JOIN    [dbo].[Campana_Entrega] e ON e.cen_campana = k.cam_id AND e.cen_usuario = @USUARIO AND e.cen_cliente = @CLIENTE
    LEFT JOIN [dbo].[Ayuda_Contenido] a ON a.ayc_id = k.cam_contenido AND a.ayc_estado = 'Publicado'
    WHERE   (k.cam_donde = 'login' OR k.cam_donde_modulo = @MODULO)
            /* tiene algo que mostrar en la pagina (la campana ya se resolvio arriba) */
      AND   ((',' + k.cam_formatos + ',') LIKE '%,banner,%' OR (',' + k.cam_formatos + ',') LIKE '%,modal,%' OR (',' + k.cam_formatos + ',') LIKE '%,card,%')
      /* La frecuencia manda sobre el modal y el banner (columna MOSTRAR). La card de «Te puede interesar» no
         es una interrupcion: se queda mientras la campana este vigente y la persona no la haya descartado. */
      AND   (CASE k.cam_frecuencia
                /* una vez: la primera vista la da por cumplida */
                WHEN 'una'     THEN CASE WHEN e.cen_veces = 0 THEN 1 ELSE 0 END
                /* una vez por persona, aunque trabaje en varios clientes */
                WHEN 'usuario' THEN CASE WHEN NOT EXISTS (SELECT 1 FROM [dbo].[Campana_Entrega] x WHERE x.cen_campana = k.cam_id
                                                              AND x.cen_usuario = @USUARIO AND x.cen_veces > 0) THEN 1 ELSE 0 END
                /* hasta que la lea: cerrarla, tocar el boton o confirmarla */
                WHEN 'leer'    THEN CASE WHEN e.cen_fecha_descarte IS NULL THEN 1 ELSE 0 END
                /* cada X dias */
                WHEN 'repetir' THEN CASE WHEN e.cen_veces = 0 OR e.cen_fecha_ultima <= DATEADD(DAY, -ISNULL(k.cam_cada_dias, 7), @AHORA) THEN 1 ELSE 0 END
                ELSE 0 END = 1
             OR ((',' + k.cam_formatos + ',') LIKE '%,card,%' AND e.cen_fecha_descarte IS NULL))
    ORDER BY CASE k.cam_tipo WHEN 'importante' THEN 1 WHEN 'mant' THEN 2 ELSE 3 END, k.cam_desde DESC
GO
SET QUOTED_IDENTIFIER ON
GO
UPDATE [dbo].[Alerta] SET ale_fecha_deteccion_utc = ale_fecha_primera_ocurrencia_utc WHERE ale_campana IS NOT NULL AND ale_fecha_deteccion_utc IS NULL
GO
