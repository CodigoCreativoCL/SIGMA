USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  09-09-2026
-- DESCRIPTION:     LO QUE NECESITA EL CENTRO DE EVIDENCIAS (VISTA 13.2).
-- =============================================
-- QUE PREGUNTA RESPONDE ESTA PANTALLA
--
--   «¿Se subieron mis fotos?». Hoy la unica forma de saberlo es abrir una por
--   una las ordenes, tareas y bitacoras donde se sacaron. Quien fotografio
--   veinte cosas en un turno sin señal no tiene manera de comprobar que
--   llegaron, y se entera de que falto una cuando alguien se la reclama.
--
--   Por eso el SP no filtra por destino sino por USUARIO: es la vuelta al
--   reves de `API_SEL_EVIDENCIA`, que responde «que fotos tiene esta tarea».
--
-- EL DESTINO VIAJA RESUELTO, NO COMO ID
--
--   De poco sirve saber que una foto cuelga del destino 412: hay que decir
--   «OT-2026-0031» o «Bitacora: ruido en el reductor». El SP arma ese texto
--   una vez; que lo armara el telefono obligaria a bajar cuatro listados
--   completos para traducir cuatro ids.
--
-- POR QUE NO SE DEVUELVE EL ESTADO DE ANTIVIRUS
--
--   `arc_archivo_antivirus_estado` existe y `API_INS_EVIDENCIA` lo deja
--   siempre en 1 = Pendiente, pero **no hay ningun proceso que lo mueva a
--   Limpio**. Mostrarlo pondria «pendiente de revision» en el 100% de los
--   archivos para siempre, que es una alarma que no significa nada. Cuando
--   exista el antivirus se agrega una columna y la pantalla la pinta; hasta
--   entonces, callar es mas honesto que alarmar.
-- =============================================
SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 1) El componente como destino de evidencia
-- ---------------------------------------------------------------------------
--
-- `avi_activo_componente` la creo BD/202 para la galeria (8.4), pero los dos
-- SP de evidencia no la conocian: se podian ver fotos de un componente y no
-- se podia subir ninguna. Se completan las dos puntas.
DECLARE @SQL NVARCHAR(MAX)

-- El INS: aceptar COMPONENTE en la lista de destinos y escribir la columna.
SET @SQL = OBJECT_DEFINITION(OBJECT_ID('[dbo].[API_INS_EVIDENCIA]'))

IF (@SQL IS NULL)
BEGIN
    RAISERROR('1.- NO EXISTE API_INS_EVIDENCIA.', 16, 1)
    RETURN
END

/* CADA PARCHE SE MIRA POR SEPARADO

   El primer intento de este script hizo tres de los cuatro cambios y fallo el
   cuarto en silencio -un REPLACE de varias lineas no calza, porque el archivo
   guarda LF y SQL Server devuelve CRLF-. Al reaplicarlo, los tres que YA
   estaban se volvieron a aplicar y duplicaron la columna en el INSERT.

   La leccion, y por eso esta escrito asi: un script idempotente no es el que
   se puede correr dos veces, es el que **comprueba cada cambio por su cuenta**
   antes de hacerlo. Un guardia global miente en cuanto una corrida queda a
   medias. */
/* CREATE -> ALTER, CON LOS DOS ESPACIADOS

   `OBJECT_DEFINITION` no devuelve el texto tal cual se envio: un SP que se
   modifico con ALTER vuelve como CREATE, y ademas normaliza los espacios. El
   original decia `CREATE   PROCEDURE` con tres espacios y despues del primer
   ALTER paso a decir `CREATE PROCEDURE` con uno, asi que el REPLACE dejo de
   calzar y el script intento CREAR un SP que ya existia. Se cubren los dos. */
SET @SQL = REPLACE(@SQL, 'CREATE   PROCEDURE', 'ALTER PROCEDURE')
SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')

-- a) la validacion del destino. De una sola linea, por lo del CRLF.
IF (CHARINDEX('N''BITACORA'', N''COMPONENTE'')', @SQL) = 0)
    SET @SQL = REPLACE(@SQL,
        'N''ACTIVO'', N''BITACORA'')',
        'N''ACTIVO'', N''BITACORA'', N''COMPONENTE'')')

-- b) el calculo del orden dentro del destino
IF (CHARINDEX('@DES = N''COMPONENTE'' AND [avi_activo_componente]', @SQL) = 0)
    SET @SQL = REPLACE(@SQL,
        'OR (@DES = N''BITACORA''  AND [avi_bitacora] = @DESTINO_ID))',
        'OR (@DES = N''BITACORA''  AND [avi_bitacora] = @DESTINO_ID)
                 OR (@DES = N''COMPONENTE'' AND [avi_activo_componente] = @DESTINO_ID))')

-- c) la columna en la lista del INSERT
IF (CHARINDEX(',[avi_activo_componente]', @SQL) = 0)
    SET @SQL = REPLACE(@SQL,
        ',[avi_checklist_hallazgo], [avi_activo], [avi_bitacora]',
        ',[avi_checklist_hallazgo], [avi_activo], [avi_bitacora]
            ,[avi_activo_componente]')

-- d) y su valor
IF (CHARINDEX('CASE WHEN @DES = N''COMPONENTE'' THEN @DESTINO_ID END', @SQL) = 0)
    SET @SQL = REPLACE(@SQL,
        ',CASE WHEN @DES = N''BITACORA''  THEN @DESTINO_ID END',
        ',CASE WHEN @DES = N''BITACORA''  THEN @DESTINO_ID END
            ,CASE WHEN @DES = N''COMPONENTE'' THEN @DESTINO_ID END')

EXEC sp_executesql @SQL
GO

-- El SEL: la rama que faltaba.
DECLARE @SQL NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('[dbo].[API_SEL_EVIDENCIA]'))

IF (@SQL IS NOT NULL AND CHARINDEX('COMPONENTE', @SQL) = 0)
BEGIN
    SET @SQL = REPLACE(@SQL, 'CREATE   PROCEDURE', 'ALTER PROCEDURE')
    SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
    SET @SQL = REPLACE(@SQL,
        'OR (@DES = N''BITACORA''  AND avi.[avi_bitacora] = @DESTINO_ID))',
        'OR (@DES = N''BITACORA''  AND avi.[avi_bitacora] = @DESTINO_ID)
            OR (@DES = N''COMPONENTE'' AND avi.[avi_activo_componente] = @DESTINO_ID))')
    EXEC sp_executesql @SQL
END
GO

-- ---------------------------------------------------------------------------
-- 2) API_SEL_EVIDENCIA_MIAS — lo que subi yo, con su registro
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_EVIDENCIA_MIAS]
@USUARIO    INT,
@CLIENTE    INT,
@DIAS       INT = 30,
@PAGINA     INT = 1,
@TAMANO     INT = 50,
@TOTAL      INT = NULL OUTPUT
AS
SET NOCOUNT ON

IF @PAGINA < 1 SET @PAGINA = 1
IF @TAMANO < 1 SET @TAMANO = 50
IF @TAMANO > 200 SET @TAMANO = 200
IF @DIAS   < 1 SET @DIAS   = 30
DECLARE @OFFSET INT = (@PAGINA - 1) * @TAMANO

/* UNA VENTANA DE DIAS, NO TODO EL HISTORIAL

   La pregunta es «se subio lo de este turno», no «que fotografie en dos
   años». Sin tope, un tecnico con dos temporadas de trabajo bajaria miles de
   filas para mirar las seis de ayer. */
DECLARE @DESDE DATETIME = DATEADD(DAY, -@DIAS, GETDATE())

SELECT  arc.arc_id                  AS ARC_ID,
        arc.arc_uuid                AS ARC_UUID,
        arc.arc_ruta                AS ARC_RUTA,
        arc.arc_nombre_original     AS ARC_NOMBRE,
        arc.arc_mime                AS ARC_MIME,
        arc.arc_byte                AS ARC_BYTE,
        ISNULL(arc.arc_fecha_captura_utc, arc.arc_fecha_creacion) AS FECHA_CAPTURA_UTC,
        arc.arc_fecha_creacion      AS FECHA_SUBIDA,
        aca.aca_nombre              AS CATEGORIA_NOMBRE,
        avi.avi_descripcion         AS DESCRIPCION,

        /* De que cuelga, en palabras. El primero que no sea nulo manda: un
           vinculo tiene exactamente un dueño, la tabla solo esta preparada
           para muchos tipos de dueño. */
        CASE
            WHEN avi.avi_orden_trabajo IS NOT NULL      THEN N'Orden de trabajo'
            WHEN avi.avi_orden_trabajo_paso IS NOT NULL THEN N'Paso de una orden'
            WHEN avi.avi_tarea_ejecucion IS NOT NULL    THEN N'Tarea'
            WHEN avi.avi_bitacora IS NOT NULL           THEN N'Bitácora'
            WHEN avi.avi_falla IS NOT NULL              THEN N'Falla'
            WHEN avi.avi_checklist_hallazgo IS NOT NULL THEN N'Hallazgo'
            WHEN avi.avi_checklist_ejecucion_respuesta IS NOT NULL THEN N'Pauta'
            WHEN avi.avi_activo_componente IS NOT NULL  THEN N'Componente'
            WHEN avi.avi_activo IS NOT NULL             THEN N'Equipo'
            WHEN avi.avi_repuesto IS NOT NULL           THEN N'Repuesto'
            WHEN avi.avi_permiso_trabajo IS NOT NULL    THEN N'Permiso de trabajo'
            ELSE N'Sin registro'
        END                         AS DESTINO_TIPO,

        /* CAST a texto en TODAS las ramas, no solo en las que parecen
           numero. `otr_correlativo` es INT, y sin el CAST el COALESCE entero
           se resuelve como INT: la primera bitacora con titulo hacia caer el
           endpoint con «Conversion failed converting the nvarchar value
           'Prueba 193' to data type int». Un COALESCE mezcla tipos en
           silencio hasta que un dato real lo delata. */
        COALESCE(CAST(otr.otr_correlativo AS NVARCHAR(200)),
                 CAST(otp.otr_correlativo AS NVARCHAR(200)),
                 CAST(bit.bit_titulo      AS NVARCHAR(200)),
                 CAST(fal.fal_titulo      AS NVARCHAR(200)),
                 CAST(aco.aco_codigo      AS NVARCHAR(200)),
                 CAST(act.act_codigo      AS NVARCHAR(200)),
                 CAST(rep.rep_codigo      AS NVARCHAR(200)),
                 CAST(ptr.ptr_numero      AS NVARCHAR(200)),
                 N'')               AS DESTINO_TEXTO,

        COALESCE(avi.avi_orden_trabajo,
                 avi.avi_bitacora,
                 avi.avi_falla,
                 avi.avi_activo_componente,
                 avi.avi_activo,
                 avi.avi_repuesto,
                 avi.avi_permiso_trabajo) AS DESTINO_ID
INTO    #mias
FROM    [dbo].[Archivo_Vinculo] avi
INNER JOIN [dbo].[Archivo] arc ON arc.arc_id = avi.avi_archivo
LEFT  JOIN [dbo].[Archivo_Categoria] aca ON aca.aca_id = arc.arc_archivo_categoria
LEFT  JOIN [dbo].[Orden_Trabajo] otr ON otr.otr_id = avi.avi_orden_trabajo
LEFT  JOIN [dbo].[Orden_Trabajo_Paso] otps ON otps.otp_id = avi.avi_orden_trabajo_paso
LEFT  JOIN [dbo].[Orden_Trabajo] otp ON otp.otr_id = otps.otp_orden_trabajo
LEFT  JOIN [dbo].[Bitacora] bit ON bit.bit_id = avi.avi_bitacora
LEFT  JOIN [dbo].[Falla] fal ON fal.fal_id = avi.avi_falla
LEFT  JOIN [dbo].[Activo_Componente] aco ON aco.aco_id = avi.avi_activo_componente
LEFT  JOIN [dbo].[Activo] act ON act.act_id = avi.avi_activo
LEFT  JOIN [dbo].[Repuesto] rep ON rep.rep_id = avi.avi_repuesto
LEFT  JOIN [dbo].[Permiso_Trabajo] ptr ON ptr.ptr_id = avi.avi_permiso_trabajo
WHERE   arc.arc_cliente          = @CLIENTE
  AND   arc.arc_usuario_creacion = @USUARIO
  AND   arc.arc_habilitado       = 1
  AND   avi.avi_habilitado       = 1
  AND   arc.arc_fecha_creacion  >= @DESDE

SET @TOTAL = (SELECT COUNT(*) FROM #mias)

-- Lo mas reciente primero: se abre para comprobar lo del turno que acaba.
SELECT * FROM #mias
ORDER BY FECHA_SUBIDA DESC, ARC_ID DESC
OFFSET @OFFSET ROWS FETCH NEXT @TAMANO ROWS ONLY

DROP TABLE #mias

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- Verificacion
-- ---------------------------------------------------------------------------
-- Se verifica que COMPONENTE este en la LISTA DE DESTINOS VALIDOS, no que la
-- palabra aparezca en alguna parte: la primera version de este script daba OK
-- con la validacion sin tocar, porque `avi_activo_componente` ya la contiene.
SELECT 'API_INS_EVIDENCIA acepta COMPONENTE = ' +
       CASE WHEN CHARINDEX('N''BITACORA'', N''COMPONENTE'')',
                           OBJECT_DEFINITION(OBJECT_ID('[dbo].[API_INS_EVIDENCIA]'))) > 0
            THEN 'OK' ELSE 'FALTA' END AS RESULTADO
UNION ALL
SELECT 'API_SEL_EVIDENCIA acepta COMPONENTE = ' +
       CASE WHEN CHARINDEX('N''COMPONENTE''',
                           OBJECT_DEFINITION(OBJECT_ID('[dbo].[API_SEL_EVIDENCIA]'))) > 0
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'API_SEL_EVIDENCIA_MIAS = ' +
       CASE WHEN OBJECT_ID('[dbo].[API_SEL_EVIDENCIA_MIAS]') IS NULL THEN 'FALTA' ELSE 'OK' END
GO
