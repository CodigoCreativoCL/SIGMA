USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  07-09-2026
-- DESCRIPTION:     BITACORA DE PRUEBA Y, SOBRE TODO, LA RECTIFICACION.
-- =============================================
-- LO QUE HAY QUE DEMOSTRAR
--
--   Que el registro original sigue ahi despues de corregirlo. Es la unica
--   propiedad de este modulo que, si falla, no se nota hasta el dia que
--   importa -cuando alguien tiene que explicar que se sabia y cuando-.
--
--   Por eso el bloque rectifica dos veces la misma entrada y despues lee las
--   tres versiones: el original, la primera correccion y la segunda.
-- =============================================

SET XACT_ABORT ON
GO

DECLARE @CLI INT = 1
DECLARE @CIN INT = 3
DECLARE @USR INT = 11                      -- cristian.munoz, mantenedor
DECLARE @SUP INT = 9                       -- emilio.fuentes
DECLARE @HOY DATETIME = GETUTCDATE()

/* Se puede volver a correr. */
DELETE bco FROM [dbo].[Bitacora_Comentario] bco
  JOIN [dbo].[Bitacora] b ON b.[bit_id] = bco.[bco_bitacora] WHERE b.[bit_cliente] = @CLI
DELETE bre FROM [dbo].[Bitacora_Rectificacion] bre
  JOIN [dbo].[Bitacora] b ON b.[bit_id] = bre.[bre_bitacora] WHERE b.[bit_cliente] = @CLI
DELETE FROM [dbo].[Bitacora] WHERE [bit_cliente] = @CLI
DELETE FROM [dbo].[Dictado_Voz] WHERE [dvo_uuid] LIKE 'BE1C3A70-%'

DECLARE @HORNO INT = (SELECT [act_id] FROM [dbo].[Activo] WHERE [act_codigo] = N'ACT-34')
DECLARE @REVOL INT = (SELECT [act_id] FROM [dbo].[Activo] WHERE [act_codigo] = N'ACT-35')

--  Las fechas van en variables porque EXEC **no acepta expresiones** como
--  argumento: un DATEADD ahi es error de sintaxis, igual que un CASE.
DECLARE @HACE6  DATETIME = DATEADD(HOUR, -6, @HOY)
DECLARE @HACE20 DATETIME = DATEADD(HOUR, -20, @HOY)

DECLARE @U1 UNIQUEIDENTIFIER = 'BE1C3A70-0001-4A00-9000-000000000001'
DECLARE @U2 UNIQUEIDENTIFIER = 'BE1C3A70-0001-4A00-9000-000000000002'
DECLARE @U3 UNIQUEIDENTIFIER = 'BE1C3A70-0001-4A00-9000-000000000003'
DECLARE @U4 UNIQUEIDENTIFIER = 'BE1C3A70-0001-4A00-9000-000000000004'

/* -- 1. Cambio de turno, dictado -- */
PRINT '== ENTRADAS =='
EXEC [dbo].[API_INS_BITACORA]
     @UUID = @U1, @USUARIO = @USR, @CLIENTE = @CLI, @INSTALACION = @CIN
    ,@TIPO = 4                                          -- CAMBIO TURNO
    ,@TITULO = N'Entrega de turno noche'
    ,@TEXTO = N'Linea 1 operando normal. El horno quedo con la puerta trabando un poco, se avisa al turno de dia.'
    ,@TURNO = N'Noche', @AREA = 4
    ,@FECHA_EVENTO = @HOY
    ,@DICTADO_UUID  = 'BE1C3A70-0002-4A00-9000-000000000001'
    ,@TEXTO_DICTADO = N'linea uno operando normal el horno quedo con la puerta trabando un poco se avisa al turno de dia'
    ,@DICTADO_CONFIANZA = 0.9120, @DICTADO_SEGUNDOS = 11

/* -- 2. Un incidente, con severidad y atencion requerida -- */
EXEC [dbo].[API_INS_BITACORA]
     @UUID = @U2, @USUARIO = @USR, @CLIENTE = @CLI, @INSTALACION = @CIN
    ,@TIPO = 3                                          -- INCIDENTE
    ,@TITULO = N'Corte de vapor en linea 1'
    ,@TEXTO = N'Se corto el vapor a las 03:10 por unos 20 minutos. Se perdio una hornada.'
    ,@ACTIVO = @HORNO, @AREA = 4, @TURNO = N'Noche'
    ,@REQUIERE_ATENCION = 1, @SEVERIDAD = 4             -- ALTA
    ,@FECHA_EVENTO = @HACE6
    ,@OFFLINE = 1                                       -- escrita sin senal

/* -- 3. Una observacion cualquiera -- */
EXEC [dbo].[API_INS_BITACORA]
     @UUID = @U3, @USUARIO = @SUP, @CLIENTE = @CLI, @INSTALACION = @CIN
    ,@TIPO = 1                                          -- OBSERVACION
    ,@TEXTO = N'Se cambio la correa de la revolvedora 1. Quedo alineada y con tension correcta.'
    ,@ACTIVO = @REVOL, @AREA = 6
    ,@FECHA_EVENTO = @HACE20

/* -- 4. El reintento de la cola: no debe crear otra -- */
PRINT '== REENVIO DEL MISMO UUID (no debe duplicar) =='
EXEC [dbo].[API_INS_BITACORA]
     @UUID = @U2, @USUARIO = @USR, @CLIENTE = @CLI, @INSTALACION = @CIN
    ,@TIPO = 3, @TEXTO = N'Se corto el vapor a las 03:10 por unos 20 minutos. Se perdio una hornada.'
    ,@ACTIVO = @HORNO, @REQUIERE_ATENCION = 1, @SEVERIDAD = 4

/* -- 5. Un incidente sin severidad debe rebotar -- */
PRINT '== INCIDENTE SIN SEVERIDAD (debe fallar) =='
BEGIN TRY
    EXEC [dbo].[API_INS_BITACORA]
         @UUID = @U4, @USUARIO = @USR, @CLIENTE = @CLI, @INSTALACION = @CIN
        ,@TIPO = 3, @TEXTO = N'Algo paso en la linea 2.'
    PRINT '  MAL: acepto un incidente sin severidad'
END TRY
BEGIN CATCH
    PRINT '  rechazado: ' + ERROR_MESSAGE()
END CATCH
GO


-- ---------------------------------------------------------------------------
-- LA RECTIFICACION
-- ---------------------------------------------------------------------------
DECLARE @CLI INT = 1, @USR INT = 11, @SUP INT = 9
DECLARE @BIT INT = (SELECT [bit_id] FROM [dbo].[Bitacora]
                     WHERE [bit_uuid] = 'BE1C3A70-0001-4A00-9000-000000000002')

PRINT ''
PRINT '== RECTIFICAR SIN MOTIVO (debe fallar) =='
BEGIN TRY
    EXEC [dbo].[API_INS_BITACORA_RECTIFICACION]
         @BITACORA = @BIT, @USUARIO = @USR, @CLIENTE = @CLI
        ,@TEXTO = N'Se corto el vapor a las 03:10 por 35 minutos.'
    PRINT '  MAL: rectifico sin motivo'
END TRY
BEGIN CATCH
    PRINT '  rechazado: ' + ERROR_MESSAGE()
END CATCH

PRINT '== RECTIFICAR SIENDO OTRO (debe fallar) =='
BEGIN TRY
    EXEC [dbo].[API_INS_BITACORA_RECTIFICACION]
         @BITACORA = @BIT, @USUARIO = @SUP, @CLIENTE = @CLI
        ,@TEXTO = N'Otra version de los hechos.'
        ,@MOTIVO = N'Me parece que fue distinto.'
    PRINT '  MAL: un tercero corrigio el relato ajeno'
END TRY
BEGIN CATCH
    PRINT '  rechazado: ' + ERROR_MESSAGE()
END CATCH

PRINT '== PRIMERA RECTIFICACION =='
EXEC [dbo].[API_INS_BITACORA_RECTIFICACION]
     @BITACORA = @BIT, @USUARIO = @USR, @CLIENTE = @CLI
    ,@TEXTO = N'Se corto el vapor a las 03:10 por unos 35 minutos. Se perdieron dos hornadas.'
    ,@MOTIVO = N'Revise el registro del caldero: fueron 35 minutos y no 20, y se perdio una segunda hornada.'

PRINT '== SEGUNDA RECTIFICACION =='
EXEC [dbo].[API_INS_BITACORA_RECTIFICACION]
     @BITACORA = @BIT, @USUARIO = @USR, @CLIENTE = @CLI
    ,@TEXTO = N'Se corto el vapor a las 03:10 por 35 minutos. Se perdieron dos hornadas. Causa: valvula reguladora trabada.'
    ,@MOTIVO = N'El turno de dia encontro la causa y corresponde dejarla anotada aca.'

PRINT '== RECTIFICAR SIN CAMBIAR NADA (debe fallar) =='
BEGIN TRY
    EXEC [dbo].[API_INS_BITACORA_RECTIFICACION]
         @BITACORA = @BIT, @USUARIO = @USR, @CLIENTE = @CLI
        ,@TEXTO = N'Se corto el vapor a las 03:10 por 35 minutos. Se perdieron dos hornadas. Causa: valvula reguladora trabada.'
        ,@MOTIVO = N'Nada, probando.'
    PRINT '  MAL: acepto una rectificacion vacia de contenido'
END TRY
BEGIN CATCH
    PRINT '  rechazado: ' + ERROR_MESSAGE()
END CATCH

/* -- Comentar: eso si lo puede hacer un tercero -- */
PRINT ''
PRINT '== COMENTARIOS =='
EXEC [dbo].[API_INS_BITACORA_COMENTARIO]
     @BITACORA = @BIT, @USUARIO = @SUP, @CLIENTE = @CLI
    ,@TEXTO = N'Se abrio la OT para revisar la valvula. Queda para el sabado.'

DECLARE @PADRE INT = (SELECT TOP 1 [bco_id] FROM [dbo].[Bitacora_Comentario]
                       WHERE [bco_bitacora] = @BIT ORDER BY [bco_id] DESC)

EXEC [dbo].[API_INS_BITACORA_COMENTARIO]
     @BITACORA = @BIT, @USUARIO = @USR, @CLIENTE = @CLI
    ,@TEXTO = N'Gracias. Dejo la valvula marcada con cinta para que la ubiquen.'
    ,@PADRE = @PADRE

PRINT '== COMENTARIO REPETIDO (no debe duplicar) =='
EXEC [dbo].[API_INS_BITACORA_COMENTARIO]
     @BITACORA = @BIT, @USUARIO = @SUP, @CLIENTE = @CLI
    ,@TEXTO = N'Se abrio la OT para revisar la valvula. Queda para el sabado.'
GO


-- ---------------------------------------------------------------------------
-- LO QUE QUEDO
-- ---------------------------------------------------------------------------
PRINT ''
PRINT '== LINEA DE TIEMPO =='
EXEC [dbo].[API_SEL_BITACORA] @USUARIO = 11, @CLIENTE = 1, @TIPO = 1

DECLARE @BIT INT = (SELECT [bit_id] FROM [dbo].[Bitacora]
                     WHERE [bit_uuid] = 'BE1C3A70-0001-4A00-9000-000000000002')

PRINT ''
PRINT '== EL ORIGINAL SIGUE AHI =='
SELECT   [bit_texto] AS [ORIGINAL]
        ,ISNULL((SELECT TOP 1 r.[bre_texto_rectificado]
                   FROM [dbo].[Bitacora_Rectificacion] r
                  WHERE r.[bre_bitacora] = [bit_id]
                  ORDER BY r.[bre_id] DESC), [bit_texto]) AS [VIGENTE]
FROM     [dbo].[Bitacora] WHERE [bit_id] = @BIT

PRINT ''
PRINT '== LAS RECTIFICACIONES, EN ORDEN =='
EXEC [dbo].[API_SEL_BITACORA] @USUARIO = 11, @CLIENTE = 1, @TIPO = 4, @ID = @BIT

PRINT ''
PRINT '== EL HILO =='
EXEC [dbo].[API_SEL_BITACORA] @USUARIO = 11, @CLIENTE = 1, @TIPO = 3, @ID = @BIT
GO
