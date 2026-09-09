USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  09-09-2026
-- DESCRIPTION:     LO QUE LE FALTABA A LA BASE PARA LAS VISTAS 8.1 A 8.4.
-- =============================================
-- QUE TRAE ESTE SCRIPT Y QUE NO
--
--   NO trae el listado ni la ficha del componente: `SEL_ACTIVO_COMPONENTE`
--   ya existe, ya recibe @ACTIVO y @FILTRO, y ya devuelve el activo padre, el
--   tipo, el estado, la criticidad y la posicion. Escribir un SP nuevo para
--   la app seria mantener dos consultas que dicen lo mismo, y en cuanto
--   alguien agregue una columna una de las dos se queda atras.
--
--   Trae las tres cosas que de verdad NO existian:
--
--   1. La columna `avi_activo_componente` en `Archivo_Vinculo`. Sin ella una
--      foto no se puede colgar de un componente: hoy solo se cuelga de un
--      activo, una OT, una falla, un repuesto... El componente era el unico
--      de la lista que faltaba, y la galeria (8.4) no tenia donde existir.
--
--   2. `API_SEL_COMPONENTE_FOTO`, gemelo de `API_SEL_ACTIVO_FOTO`.
--
--   3. `API_SEL_ACTIVO_COMPONENTE_FICHA`, la linea de tiempo del componente
--      (8.3).
-- =============================================
SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 1) La foto de un componente necesita donde colgarse
-- ---------------------------------------------------------------------------
--
-- `Archivo_Vinculo` es una tabla de vinculos con una columna por cada cosa a
-- la que un archivo se puede pegar. El componente no estaba, asi que se
-- agrega igual que las demas: NULL, sin defecto y con su FK. Nada de lo que
-- ya funciona cambia, porque una columna nueva y anulable no toca ninguna
-- fila existente.
IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID('[dbo].[Archivo_Vinculo]')
                  AND name = 'avi_activo_componente')
BEGIN
    ALTER TABLE [dbo].[Archivo_Vinculo] ADD avi_activo_componente INT NULL
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_AVI_ACTIVO_COMPONENTE')
BEGIN
    ALTER TABLE [dbo].[Archivo_Vinculo] WITH CHECK
        ADD CONSTRAINT [FK_AVI_ACTIVO_COMPONENTE]
        FOREIGN KEY (avi_activo_componente)
        REFERENCES [dbo].[Activo_Componente] (aco_id)
END
GO

-- El indice filtrado, no el completo: la inmensa mayoria de los vinculos NO
-- son de un componente, y un indice sobre una columna casi toda nula ocuparia
-- sitio para no responder mas rapido.
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'IX_AVI_ACTIVO_COMPONENTE'
                  AND object_id = OBJECT_ID('[dbo].[Archivo_Vinculo]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_AVI_ACTIVO_COMPONENTE]
        ON [dbo].[Archivo_Vinculo] (avi_activo_componente)
        WHERE avi_activo_componente IS NOT NULL
END
GO

-- ---------------------------------------------------------------------------
-- 2) API_SEL_COMPONENTE_FOTO
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_COMPONENTE_FOTO]
@COMPONENTE INT,
@CLIENTE    INT
AS
SET NOCOUNT ON

    /* Mismo criterio que `API_SEL_ACTIVO_FOTO`: el cliente se valida contra
       el COMPONENTE y no solo contra el archivo, porque un archivo del mismo
       cliente colgado de otro componente no es foto de este. */
    SELECT      a.arc_ruta              AS ARC_RUTA,
                a.arc_mime              AS ARC_MIME,
                a.arc_nombre_original   AS ARC_NOMBRE,
                v.avi_es_referencia     AS ES_PORTADA,
                v.avi_descripcion       AS DESCRIPCION,
                a.arc_fecha_captura_utc AS FECHA_CAPTURA_UTC,
                LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' +
                            ISNULL(u.usu_apellido_paterno, N''))) AS AUTOR_NOMBRE
    FROM        [dbo].[Archivo_Vinculo]    v
    INNER JOIN  [dbo].[Archivo]            a   ON a.arc_id   = v.avi_archivo
    INNER JOIN  [dbo].[Activo_Componente]  aco ON aco.aco_id = v.avi_activo_componente
    LEFT  JOIN  [dbo].[Usuario]            u   ON u.usu_id   = a.arc_usuario_creacion
    WHERE       v.avi_activo_componente = @COMPONENTE
      AND       v.avi_habilitado        = 1
      AND       a.arc_habilitado        = 1
      AND       a.arc_cliente           = @CLIENTE
      AND       aco.aco_cliente         = @CLIENTE
      /* Solo imagenes: un PDF colgado del mismo componente no se dibuja en
         una miniatura, y pedirlo seria bajar megabytes para nada. */
      AND       a.arc_mime LIKE 'image/%'
      AND       LTRIM(RTRIM(ISNULL(a.arc_ruta, ''))) <> ''
    ORDER BY    v.avi_es_referencia DESC,
                ISNULL(v.avi_orden, 0),
                a.arc_id
GO

-- ---------------------------------------------------------------------------
-- 3) API_SEL_ACTIVO_COMPONENTE_FICHA — la linea de tiempo del componente
-- ---------------------------------------------------------------------------
--
-- Mismo molde que `SEL_ACTIVO_FICHA`: tabla temporal, @TOTAL de salida y una
-- pagina. Cambian las fuentes, que son las que cuelgan del componente.
--
-- QUE SE PUEDE CONTAR HOY Y QUE NO
--
--   La especificacion (8.3) pide instalacion, cambios de estado, lecturas,
--   fallas, reparaciones, sustituciones, OT, comentarios y rectificaciones.
--   Seis de esas ocho existen en la base y se devuelven.
--
--   **Los cambios de estado del componente no**: hay
--   `Activo_Estado_Historial` para el activo, pero el componente guarda su
--   estado en una columna sin historial, asi que no hay de donde sacarlos.
--   Inventar la fila mirando `aco_fecha_actualizacion` diria «cambio de
--   estado» cada vez que alguien corrigio una falta de ortografia en el
--   nombre, que es peor que no decir nada. Queda anotado como pendiente de
--   base, no de pantalla.
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ACTIVO_COMPONENTE_FICHA]
@COMPONENTE     INT,
@CLIENTE        INT,
@TIPO_EVENTO    NVARCHAR(20) = NULL,
@PAGINA         INT = 1,
@TAMANO         INT = 20,
@TOTAL          INT = NULL OUTPUT
AS
SET NOCOUNT ON

-- Barrera multicliente: el componente tiene que ser del cliente en sesion.
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente]
                WHERE aco_id = @COMPONENTE AND aco_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL COMPONENTE NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @PAGINA < 1 SET @PAGINA = 1
IF @TAMANO < 1 SET @TAMANO = 20
IF @TAMANO > 200 SET @TAMANO = 200   -- tope: el consumidor es un telefono
DECLARE @OFFSET INT = (@PAGINA - 1) * @TAMANO

CREATE TABLE #ev
(
    fecha           DATETIME,
    tipo_evento     NVARCHAR(20),
    titulo          NVARCHAR(400),
    detalle         NVARCHAR(1000),
    usuario_nombre  NVARCHAR(200),
    ref_id          INT,            -- el id del registro, para poder abrirlo
    ref_texto       NVARCHAR(100)   -- su correlativo o codigo, para mostrarlo
)

-- 1) La instalacion: el primer dia del componente.
IF (@TIPO_EVENTO IS NULL OR @TIPO_EVENTO = N'INSTALACION')
    INSERT INTO #ev (fecha, tipo_evento, titulo, detalle, usuario_nombre, ref_id, ref_texto)
    SELECT  CAST(ISNULL(aco.aco_fecha_instalacion, aco.aco_fecha_creacion) AS DATETIME),
            N'INSTALACION',
            N'Instalado en ' + ISNULL(act.act_nombre, N'el equipo'),
            aco.aco_descripcion,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))),
            aco.aco_id,
            aco.aco_codigo
    FROM    [dbo].[Activo_Componente] aco
    LEFT JOIN [dbo].[Activo]  act ON act.act_id = aco.aco_activo
    LEFT JOIN [dbo].[Usuario] u   ON u.usu_id   = aco.aco_usuario_creacion
    WHERE   aco.aco_id = @COMPONENTE

-- 2) Lecturas de los medidores que cuelgan del componente.
IF (@TIPO_EVENTO IS NULL OR @TIPO_EVENTO = N'LECTURA')
    INSERT INTO #ev (fecha, tipo_evento, titulo, detalle, usuario_nombre, ref_id, ref_texto)
    SELECT  aml.aml_fecha_lectura_utc,
            N'LECTURA',
            ame.ame_nombre + N': ' +
                CONVERT(NVARCHAR(40), CAST(aml.aml_valor_acumulado AS DECIMAL(18,2))) +
                ISNULL(N' ' + ume.ume_simbolo, N''),
            aml.aml_observacion,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))),
            aml.aml_id,
            ame.ame_codigo
    FROM    [dbo].[Activo_Medidor_Lectura] aml
    INNER JOIN [dbo].[Activo_Medidor] ame ON ame.ame_id = aml.aml_activo_medidor
    LEFT  JOIN [dbo].[Unidad_Medida]  ume ON ume.ume_id = ame.ame_unidad_medida
    LEFT  JOIN [dbo].[Usuario]        u   ON u.usu_id   = aml.aml_usuario_creacion
    WHERE   ame.ame_activo_componente = @COMPONENTE

-- 3) Fallas reportadas sobre el componente.
IF (@TIPO_EVENTO IS NULL OR @TIPO_EVENTO = N'FALLA')
    INSERT INTO #ev (fecha, tipo_evento, titulo, detalle, usuario_nombre, ref_id, ref_texto)
    SELECT  fal.fal_fecha_deteccion_utc,
            N'FALLA',
            fal.fal_titulo,
            fal.fal_descripcion,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))),
            fal.fal_id,
            NULL
    FROM    [dbo].[Falla] fal
    LEFT JOIN [dbo].[Usuario] u ON u.usu_id = ISNULL(fal.fal_usuario_reporta, fal.fal_usuario_creacion)
    WHERE   fal.fal_activo_componente = @COMPONENTE
      AND   fal.fal_habilitado = 1

-- 4) Ordenes de trabajo emitidas contra el componente. Son las reparaciones:
--    la reparacion no es una tabla propia, es la OT que la ejecuto.
IF (@TIPO_EVENTO IS NULL OR @TIPO_EVENTO = N'OT')
    INSERT INTO #ev (fecha, tipo_evento, titulo, detalle, usuario_nombre, ref_id, ref_texto)
    SELECT  otr.otr_fecha_creacion,
            N'OT',
            otr.otr_titulo,
            ISNULL(ote.ote_nombre, N''),
            LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))),
            otr.otr_id,
            otr.otr_correlativo
    FROM    [dbo].[Orden_Trabajo] otr
    LEFT JOIN [dbo].[Orden_Trabajo_Estado] ote ON ote.ote_id = otr.otr_orden_trabajo_estado
    LEFT JOIN [dbo].[Usuario] u ON u.usu_id = otr.otr_usuario_creacion
    WHERE   otr.otr_activo_componente = @COMPONENTE

-- 5) Repuestos instalados y retirados: el cambio de pieza dentro del
--    componente. Cada instalacion y cada retiro son eventos distintos porque
--    pasaron en momentos distintos, y juntarlos escondería meses de vida util.
IF (@TIPO_EVENTO IS NULL OR @TIPO_EVENTO = N'REPUESTO')
BEGIN
    INSERT INTO #ev (fecha, tipo_evento, titulo, detalle, usuario_nombre, ref_id, ref_texto)
    SELECT  cri.cri_fecha_instalacion_utc,
            N'REPUESTO',
            N'Se instaló ' + ISNULL(rep.rep_nombre, N'un repuesto'),
            cri.cri_observacion,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))),
            cri.cri_repuesto,
            rep.rep_codigo
    FROM    [dbo].[Componente_Repuesto_Instalacion] cri
    LEFT JOIN [dbo].[Repuesto] rep ON rep.rep_id = cri.cri_repuesto
    LEFT JOIN [dbo].[Usuario]  u   ON u.usu_id   = ISNULL(cri.cri_usuario_tecnico, cri.cri_usuario_creacion)
    WHERE   cri.cri_activo_componente = @COMPONENTE
      AND   cri.cri_fecha_instalacion_utc IS NOT NULL

    INSERT INTO #ev (fecha, tipo_evento, titulo, detalle, usuario_nombre, ref_id, ref_texto)
    SELECT  cri.cri_fecha_retiro_utc,
            N'REPUESTO',
            N'Se retiró ' + ISNULL(rep.rep_nombre, N'un repuesto') +
                CASE WHEN cri.cri_fallo = 1 THEN N' (falló)' ELSE N'' END,
            cri.cri_observacion,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))),
            cri.cri_repuesto,
            rep.rep_codigo
    FROM    [dbo].[Componente_Repuesto_Instalacion] cri
    LEFT JOIN [dbo].[Repuesto] rep ON rep.rep_id = cri.cri_repuesto
    LEFT JOIN [dbo].[Usuario]  u   ON u.usu_id   = ISNULL(cri.cri_usuario_tecnico, cri.cri_usuario_creacion)
    WHERE   cri.cri_activo_componente = @COMPONENTE
      AND   cri.cri_fecha_retiro_utc IS NOT NULL
END

-- 6) Sustituciones: el componente se fusiono con otro. Se miran las DOS
--    puntas —lo absorbio o fue absorbido— porque desde cualquiera de los dos
--    lados es el mismo hecho y ninguno de los dos deberia enterarse a medias.
IF (@TIPO_EVENTO IS NULL OR @TIPO_EVENTO = N'SUSTITUCION')
    INSERT INTO #ev (fecha, tipo_evento, titulo, detalle, usuario_nombre, ref_id, ref_texto)
    SELECT  acf.acf_fecha_utc,
            N'SUSTITUCION',
            CASE WHEN acf.acf_componente_destino = @COMPONENTE
                 THEN N'Absorbió a ' + ISNULL(ori.aco_codigo, N'otro componente')
                 ELSE N'Sustituido por ' + ISNULL(des.aco_codigo, N'otro componente')
            END,
            acf.acf_motivo,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))),
            CASE WHEN acf.acf_componente_destino = @COMPONENTE
                 THEN acf.acf_componente_origen ELSE acf.acf_componente_destino END,
            NULL
    FROM    [dbo].[Activo_Componente_Fusion] acf
    LEFT JOIN [dbo].[Activo_Componente] ori ON ori.aco_id = acf.acf_componente_origen
    LEFT JOIN [dbo].[Activo_Componente] des ON des.aco_id = acf.acf_componente_destino
    LEFT JOIN [dbo].[Usuario] u ON u.usu_id = acf.acf_usuario_creacion
    WHERE   (acf.acf_componente_origen = @COMPONENTE OR acf.acf_componente_destino = @COMPONENTE)
      AND   acf.acf_cliente = @CLIENTE

-- 7) Comentarios: la bitacora que alguien escribio sobre el componente.
IF (@TIPO_EVENTO IS NULL OR @TIPO_EVENTO = N'BITACORA')
    INSERT INTO #ev (fecha, tipo_evento, titulo, detalle, usuario_nombre, ref_id, ref_texto)
    SELECT  bit.bit_fecha_evento_utc,
            N'BITACORA',
            ISNULL(bit.bit_titulo, N'Anotación en bitácora'),
            bit.bit_texto,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' + ISNULL(u.usu_apellido_paterno, N''))),
            bit.bit_id,
            NULL
    FROM    [dbo].[Bitacora] bit
    LEFT JOIN [dbo].[Usuario] u ON u.usu_id = bit.bit_usuario_creacion
    WHERE   bit.bit_activo_componente = @COMPONENTE
      AND   bit.bit_cliente = @CLIENTE

SET @TOTAL = (SELECT COUNT(*) FROM #ev)

-- Siempre lo mas reciente primero: la ficha de un componente se abre para
-- saber que le pasó ULTIMO, no para leer su biografia desde el principio.
SELECT  fecha           AS FECHA,
        tipo_evento     AS TIPO_EVENTO,
        titulo          AS TITULO,
        detalle         AS DETALLE,
        usuario_nombre  AS USUARIO_NOMBRE,
        ref_id          AS REF_ID,
        ref_texto       AS REF_TEXTO
FROM    #ev
ORDER BY fecha DESC
OFFSET @OFFSET ROWS FETCH NEXT @TAMANO ROWS ONLY

DROP TABLE #ev

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- Verificacion
-- ---------------------------------------------------------------------------
SELECT 'avi_activo_componente = ' +
       CASE WHEN EXISTS (SELECT 1 FROM sys.columns
                          WHERE object_id = OBJECT_ID('[dbo].[Archivo_Vinculo]')
                            AND name = 'avi_activo_componente')
            THEN 'OK' ELSE 'FALTA' END AS RESULTADO
UNION ALL
SELECT 'API_SEL_COMPONENTE_FOTO = ' +
       CASE WHEN OBJECT_ID('[dbo].[API_SEL_COMPONENTE_FOTO]') IS NULL
            THEN 'FALTA' ELSE 'OK' END
UNION ALL
SELECT 'API_SEL_ACTIVO_COMPONENTE_FICHA = ' +
       CASE WHEN OBJECT_ID('[dbo].[API_SEL_ACTIVO_COMPONENTE_FICHA]') IS NULL
            THEN 'FALTA' ELSE 'OK' END
GO
