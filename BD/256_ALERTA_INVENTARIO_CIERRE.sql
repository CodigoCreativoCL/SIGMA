/* ============================================================================
   SIGMA — Bloque 256
   EL DETECTOR DE INVENTARIO CIERRA SIN CHOCAR CON CK_ALE_ATENCION      HU-077 #2
   ----------------------------------------------------------------------------

   Al reponer la existencia, GEN_ALERTA_INVENTARIO marca RESUELTA la alerta
   de stock y ponía ale_fecha_atencion_utc sin ale_usuario_atencion. Desde que
   Alerta tiene CK_ALE_ATENCION (fecha de atención exige usuario) ese UPDATE
   fallaba con 547 y la alerta quedaba NUEVA para siempre: el detector abría
   bien y no cerraba nunca. GEN_ALERTA_OPERACION (bloque 238) ya lo hacía
   bien; se deja el cierre del inventario igual: usuario de atención y motivo
   «La condición dejó de darse (detector automático)».

   Se parcha el texto vivo del SP (mismo patrón que los bloques 85 y 86,
   porque el cuerpo actual es la suma de esos parches). IDEMPOTENTE.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DECLARE @SQL NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.GEN_ALERTA_INVENTARIO'))

IF @SQL IS NULL
BEGIN
    RAISERROR('GEN_ALERTA_INVENTARIO no existe. Ejecute antes el bloque 81.', 16, 1)
    RETURN
END

IF @SQL LIKE '%a.ale_usuario_atencion      = ISNULL(a.ale_usuario_atencion, @USUARIO)%'
    PRINT '--- GEN_ALERTA_INVENTARIO ya cerraba con usuario de atención'
ELSE
BEGIN
    SET @SQL = REPLACE(@SQL,
        'SET     a.ale_alerta_estado       = @RESUELTA,
        a.ale_fecha_atencion_utc  = @AHORA,
        a.ale_usuario_actualizacion = @USUARIO,',
        'SET     a.ale_alerta_estado       = @RESUELTA,
        a.ale_fecha_atencion_utc  = @AHORA,
        a.ale_usuario_atencion      = ISNULL(a.ale_usuario_atencion, @USUARIO),
        a.ale_motivo_resolucion     = ISNULL(a.ale_motivo_resolucion, N''La condición dejó de darse (detector automático).''),
        a.ale_usuario_actualizacion = @USUARIO,')

    IF @SQL NOT LIKE '%a.ale_usuario_atencion      = ISNULL(a.ale_usuario_atencion, @USUARIO)%'
    BEGIN
        RAISERROR('No se encontró el UPDATE de cierre en GEN_ALERTA_INVENTARIO: revise el texto del SP.', 16, 1)
        RETURN
    END

    SET @SQL = REPLACE(@SQL, 'CREATE   PROCEDURE', 'ALTER PROCEDURE')
    SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')

    EXEC sp_executesql @SQL
    PRINT '--- GEN_ALERTA_INVENTARIO cierra con usuario de atención y motivo (bloque 256).'
END
GO
