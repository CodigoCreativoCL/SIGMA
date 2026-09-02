USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  01-09-2026
-- DESCRIPTION:     SPRINT 2 - HU-037 CONSULTAR LA FICHA Y EL HISTORIAL DE UN ACTIVO.
-- =============================================
-- Numeracion: Bryan uso 80-86 (inventario/notificaciones); Activo_Tipo se
-- renumero a 87-89, y la ficha sigue desde 90.
--
-- QUE CUBRE
--   T-2049  Revision del modelo Activo (ya confirmado en HU-035).
--   T-2050  SEL_ACTIVO_FICHA: la LINEA DE TIEMPO del activo. Une en un solo
--           listado los cambios de estado, los cambios de posicion y las
--           mediciones, con filtros, ordenamiento y PAGINACION. Todo por
--           PARAMETROS: no se arma SQL por concatenacion.
--   T-2051  Indices de apoyo para que el UNION no haga scan cuando la
--           historia crezca.
--
-- LA FICHA (CA1: identificacion, ubicacion, estado, criticidad) la resuelve
-- SEL_ACTIVO por @ID. Este SP es el HISTORIAL (CA2).
--
-- FUENTES DE EVENTOS HOY: Activo_Estado_Historial, Activo_Posicion_Historial
-- y Activo_Medidor_Lectura. Ordenes de trabajo y fallas son de sprints
-- posteriores; cuando existan se agregan como otro UNION ALL, sin cambiar la
-- firma.
--
-- ES IDEMPOTENTE: CREATE OR ALTER; los indices se crean solo si faltan.
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   T-2051 - INDICES DE APOYO
      El UNION filtra y ordena por (activo, fecha). Sin estos indices, cada
      fuente hace scan cuando la historia crece.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AEH_ACTIVO_FECHA' AND object_id = OBJECT_ID(N'[dbo].[Activo_Estado_Historial]'))
    CREATE NONCLUSTERED INDEX IX_AEH_ACTIVO_FECHA ON [dbo].[Activo_Estado_Historial] ([aeh_activo], [aeh_fecha_inicio_utc] DESC)
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_APH_ACTIVO_FECHA' AND object_id = OBJECT_ID(N'[dbo].[Activo_Posicion_Historial]'))
    CREATE NONCLUSTERED INDEX IX_APH_ACTIVO_FECHA ON [dbo].[Activo_Posicion_Historial] ([aph_activo], [aph_fecha_inicio_utc] DESC)
GO
-- Activo_Medidor_Lectura ya trae IX por (aml_activo_medidor, aml_fecha_lectura_utc DESC) del bloque 11.
GO


/* ========================================================================
   T-2050 - SEL_ACTIVO_FICHA
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_FICHA]
@ACTIVO         INT,
@CLIENTE        INT,
@TIPO_EVENTO    NVARCHAR(20) = NULL,   -- ESTADO / POSICION / MEDICION (NULL = todos)
@FECHA_DESDE    DATE = NULL,
@FECHA_HASTA    DATE = NULL,
@ORDEN_DESC     BIT = 1,               -- 1 = mas reciente primero
@PAGINA         INT = 1,
@TAMANO         INT = 20,
@TOTAL          INT = NULL OUTPUT

AS
SET NOCOUNT ON

-- Barrera multicliente: el activo tiene que ser del cliente en sesion.
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL ACTIVO NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @PAGINA < 1 SET @PAGINA = 1
IF @TAMANO < 1 SET @TAMANO = 20
IF @TAMANO > 200 SET @TAMANO = 200   -- tope, el consumidor puede ser un telefono
DECLARE @OFFSET INT = (@PAGINA - 1) * @TAMANO

-- Los eventos de las tres fuentes, ya filtrados, a una tabla temporal. Se
-- materializa una vez para poder contar el total y devolver la pagina sin
-- recorrer el UNION dos veces.
CREATE TABLE #ev
(
    fecha           DATETIME,
    tipo_evento     NVARCHAR(20),
    titulo          NVARCHAR(400),
    detalle         NVARCHAR(1000),
    usuario_nombre  NVARCHAR(200)
)

-- 1) Cambios de estado
IF (@TIPO_EVENTO IS NULL OR @TIPO_EVENTO = N'ESTADO')
    INSERT INTO #ev (fecha, tipo_evento, titulo, detalle, usuario_nombre)
    SELECT  aeh.aeh_fecha_inicio_utc,
            N'ESTADO',
            N'Cambio de estado a ' + ISNULL(aes.aes_nombre, N'(desconocido)'),
            aeh.aeh_motivo,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N'')))
    FROM    [dbo].[Activo_Estado_Historial] aeh
    LEFT JOIN [dbo].[Activo_Estado] aes ON aes.aes_id = aeh.aeh_activo_estado
    LEFT JOIN [dbo].[Usuario]       u   ON u.usu_id   = aeh.aeh_usuario_creacion
    WHERE   aeh.aeh_activo = @ACTIVO
      AND   (@FECHA_DESDE IS NULL OR aeh.aeh_fecha_inicio_utc >= @FECHA_DESDE)
      AND   (@FECHA_HASTA IS NULL OR aeh.aeh_fecha_inicio_utc < DATEADD(DAY, 1, @FECHA_HASTA))

-- 2) Cambios de posicion
IF (@TIPO_EVENTO IS NULL OR @TIPO_EVENTO = N'POSICION')
    INSERT INTO #ev (fecha, tipo_evento, titulo, detalle, usuario_nombre)
    SELECT  aph.aph_fecha_inicio_utc,
            N'POSICION',
            N'Cambio de posición a ' + ISNULL(apo.apo_codigo, N'(desconocida)'),
            aph.aph_observacion,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N'')))
    FROM    [dbo].[Activo_Posicion_Historial] aph
    LEFT JOIN [dbo].[Activo_Posicion] apo ON apo.apo_id = aph.aph_activo_posicion
    LEFT JOIN [dbo].[Usuario]         u   ON u.usu_id   = aph.aph_usuario_creacion
    WHERE   aph.aph_activo = @ACTIVO
      AND   (@FECHA_DESDE IS NULL OR aph.aph_fecha_inicio_utc >= @FECHA_DESDE)
      AND   (@FECHA_HASTA IS NULL OR aph.aph_fecha_inicio_utc < DATEADD(DAY, 1, @FECHA_HASTA))

-- 3) Mediciones (la lectura cuelga del medidor, y el medidor del activo)
IF (@TIPO_EVENTO IS NULL OR @TIPO_EVENTO = N'MEDICION')
    INSERT INTO #ev (fecha, tipo_evento, titulo, detalle, usuario_nombre)
    SELECT  aml.aml_fecha_lectura_utc,
            N'MEDICION',
            ame.ame_nombre + N': ' + CONVERT(NVARCHAR(40), CAST(aml.aml_valor_acumulado AS DECIMAL(18,2)))
                + ISNULL(N' ' + ume.ume_simbolo, N''),
            aml.aml_observacion,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N'')))
    FROM    [dbo].[Activo_Medidor_Lectura] aml
    INNER JOIN [dbo].[Activo_Medidor] ame ON ame.ame_id = aml.aml_activo_medidor
    LEFT  JOIN [dbo].[Unidad_Medida]  ume ON ume.ume_id = ame.ame_unidad_medida
    LEFT  JOIN [dbo].[Usuario]        u   ON u.usu_id   = aml.aml_usuario_creacion
    WHERE   ame.ame_activo = @ACTIVO
      AND   (@FECHA_DESDE IS NULL OR aml.aml_fecha_lectura_utc >= @FECHA_DESDE)
      AND   (@FECHA_HASTA IS NULL OR aml.aml_fecha_lectura_utc < DATEADD(DAY, 1, @FECHA_HASTA))

-- Total para la paginacion de la UI.
SET @TOTAL = (SELECT COUNT(*) FROM #ev)

-- La pagina pedida, ordenada por fecha en la direccion elegida. El doble
-- CASE evita concatenar SQL para el ASC/DESC.
SELECT  fecha           AS FECHA,
        tipo_evento     AS TIPO_EVENTO,
        titulo          AS TITULO,
        detalle         AS DETALLE,
        usuario_nombre  AS USUARIO_NOMBRE
FROM    #ev
ORDER BY CASE WHEN @ORDEN_DESC = 1 THEN fecha END DESC,
         CASE WHEN @ORDEN_DESC = 0 THEN fecha END ASC
OFFSET @OFFSET ROWS FETCH NEXT @TAMANO ROWS ONLY

DROP TABLE #ev

RETURN(0)
GO


PRINT '90_SPRINT2_ACTIVO_FICHA aplicado: SEL_ACTIVO_FICHA e indices de apoyo.'
GO
