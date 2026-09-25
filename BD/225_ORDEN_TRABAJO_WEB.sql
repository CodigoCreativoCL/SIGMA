USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  14-09-2026
-- DESCRIPTION:     EL CICLO DE LA ORDEN DE TRABAJO DESDE LA WEB (Sprint 5):
--                  HU-110 crear correctiva · HU-112 asignar · HU-120 cerrar ·
--                  HU-122 bandeja de cierre · HU-123 falla y diagnostico ·
--                  HU-124 indisponibilidad.
-- =============================================
-- LO QUE HABIA Y LO QUE FALTABA
--
--   La OT nacia solo desde el telefono (API_INS_ORDEN_TRABAJO), desde una
--   prediccion (bloque 117), desde el plan y desde un hallazgo (220/223).
--   Se tomaba, finalizaba y cerraba por la app. Desde la web no habia forma
--   de crear una correctiva, asignarla, cerrarla, ni de registrar la falla
--   que la origina o la parada del equipo. Este bloque es el centro de la
--   orden en la web; reusa lo que existe (ACTIVO_CAMBIAR_ESTADO,
--   FNC_USUARIO_PUEDE_CERRAR_OT) y no duplica el cierre del telefono.
--
-- DECISIONES QUE NO SE DEDUCEN DEL CODIGO
--
--   · HU-110 #3 registro posterior: otr_registro_posterior = 1 y
--     otr_fecha_ocurrencia (cuando paso) distinta de otr_fecha_creacion
--     (cuando se anoto). Las dos se conservan.
--   · HU-110 #4 orden sin activo: otr_activo NULL con area obligatoria en
--     ese caso; los indicadores por equipo la ignoran solos.
--   · HU-112 #3 un solo responsable: UX_OTA_RESPONSABLE lo garantiza; al
--     nombrar otro, el anterior pasa a APOYO en la misma transaccion.
--   · HU-112 #4 especialidad: se ADVIERTE y se permite; la advertencia
--     queda en ota_observacion y vuelve en el result set.
--   · HU-120: UPD_ORDEN_TRABAJO_CERRAR (bloque 189) exige EN ESPERA DE
--     CIERRE. Anular una orden creada por error (#3) no pasa por ahi: se
--     cierra desde ABIERTA con motivo DUPLICADA / ANULADA / NO APLICA. El
--     resultado es obligatorio solo cuando el motivo es TRABAJO REALIZADO
--     (#4). La jerarquia es la misma funcion que usa el telefono.
--   · Cerrar una OT que vino de una ocurrencia del plan la marca
--     COMPLETADA (trabajo realizado) u OMITIDA (los demas motivos), con
--     historial. Es el unico punto donde la ocurrencia se completa.
--   · HU-123: Falla_Sintoma/Modo/Causa son catalogos por cliente y estan
--     vacios; el SP los acepta pero no los exige. El estado posterior del
--     equipo (#4) se registra con ACTIVO_CAMBIAR_ESTADO, el mismo SP de
--     «Cambiar estado», para que quede en el historial del activo.
--   · HU-124: los minutos se calculan de inicio a termino en el SP (#1);
--     planificada/no planificada es una marca para el indicador (#2); la
--     orden y la falla son opcionales (#3).
-- =============================================

-- ---------------------------------------------------------------------------
-- 1) SEL_ORDEN_TRABAJO — listado, ficha y bandeja de cierre
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_ORDEN_TRABAJO]
@ID          INT = NULL,
@CLIENTE     INT,
@INSTALACION INT = NULL,
@ESTADO      INT = NULL,
@TIPO        INT = NULL,
@ORIGEN      INT = NULL,
@ACTIVO      INT = NULL,
@FALLA       INT = NULL,
@DESDE       DATE = NULL,
@HASTA       DATE = NULL,
@FILTRO      NVARCHAR(200) = NULL,
@PAGINA      INT = NULL,
@TAMANO      INT = NULL

AS
SET NOCOUNT ON

IF (@PAGINA IS NULL OR @PAGINA < 1) SET @PAGINA = 1
IF (@TAMANO IS NULL OR @TAMANO < 1) SET @TAMANO = 1000000

SELECT  o.otr_id, o.otr_uuid, o.otr_cliente, o.otr_cliente_instalacion, o.otr_correlativo, o.otr_instalacion_area,
        o.otr_activo, o.otr_activo_componente, o.otr_orden_trabajo_tipo, o.otr_orden_trabajo_estrategia,
        o.otr_orden_trabajo_origen, o.otr_orden_trabajo_estado, o.otr_orden_trabajo_prioridad,
        o.otr_usuario_generador, o.otr_titulo, o.otr_descripcion, o.otr_notas, o.otr_resultado,
        o.otr_fecha_evento_utc, o.otr_fecha_programada_utc, o.otr_fecha_inicio_real_utc, o.otr_fecha_fin_real_utc,
        o.otr_duracion_estimada_minuto, o.otr_duracion_real_minuto, o.otr_minuto_parada_activo, o.otr_requiere_permiso,
        o.otr_plan_mantenimiento_ocurrencia, o.otr_tarea_ocurrencia, o.otr_checklist_hallazgo, o.otr_prediccion, o.otr_falla,
        o.otr_registro_posterior, o.otr_fecha_ocurrencia, o.otr_cierre_motivo, o.otr_usuario_cierre, o.otr_fecha_cierre,
        o.otr_usuario_creacion, o.otr_fecha_creacion, o.otr_usuario_actualizacion, o.otr_fecha_actualizacion, o.otr_habilitado,
        cin.cin_nombre                  AS PLANTA_NOMBRE,
        iar.iar_nombre                  AS AREA_NOMBRE,
        act.act_codigo                  AS ACTIVO_CODIGO,
        act.act_nombre                  AS ACTIVO_NOMBRE,
        aco.aco_nombre                  AS COMPONENTE_NOMBRE,
        oty.ott_codigo                  AS TIPO_CODIGO,
        oty.ott_nombre                  AS TIPO_NOMBRE,
        oes.oet_codigo                  AS ESTRATEGIA_CODIGO,
        oes.oet_nombre                  AS ESTRATEGIA_NOMBRE,
        oto.oto_codigo                  AS ORIGEN_CODIGO,
        oto.oto_nombre                  AS ORIGEN_NOMBRE,
        ote.ote_codigo                  AS ESTADO_CODIGO,
        ote.ote_nombre                  AS ESTADO_NOMBRE,
        opr.opr_codigo                  AS PRIORIDAD_CODIGO,
        opr.opr_nombre                  AS PRIORIDAD_NOMBRE,
        ocm.ocm_nombre                  AS CIERRE_MOTIVO_NOMBRE,
        LTRIM(RTRIM(ISNULL(ug.usu_nombre,'') + ' ' + ISNULL(ug.usu_apellido_paterno,''))) AS GENERADOR_NOMBRE,
        LTRIM(RTRIM(ISNULL(uc.usu_nombre,'') + ' ' + ISNULL(uc.usu_apellido_paterno,''))) AS CIERRE_USUARIO_NOMBRE,
        LTRIM(RTRIM(ISNULL(ucr.usu_nombre,'') + ' ' + ISNULL(ucr.usu_apellido_paterno,''))) AS USUARIO_CREACION_NOMBRE,
        LTRIM(RTRIM(ISNULL(uac.usu_nombre,'') + ' ' + ISNULL(uac.usu_apellido_paterno,''))) AS USUARIO_ACTUALIZACION_NOMBRE,
        -- El responsable: una persona o una empresa externa
        ISNULL(LTRIM(RTRIM(ISNULL(ur.usu_nombre,'') + ' ' + ISNULL(ur.usu_apellido_paterno,''))), '') AS RESPONSABLE_NOMBRE,
        prv.prv_razon_social            AS RESPONSABLE_PROVEEDOR,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Asignacion] x WHERE x.ota_orden_trabajo = o.otr_id AND x.ota_habilitado = 1) AS ASIGNADOS,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Paso] p WHERE p.otp_orden_trabajo = o.otr_id AND p.otp_habilitado = 1) AS PASOS,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Paso] p WHERE p.otp_orden_trabajo = o.otr_id AND p.otp_habilitado = 1 AND p.otp_resultado_paso = 4) AS PASOS_PENDIENTES,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Repuesto] r WHERE r.ore_orden_trabajo = o.otr_id AND r.ore_habilitado = 1) AS REPUESTOS,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Servicio] s WHERE s.ots_orden_trabajo = o.otr_id AND s.ots_habilitado = 1) AS SERVICIOS,
        (SELECT COUNT(*) FROM [dbo].[Activo_Indisponibilidad] i WHERE i.ain_orden_trabajo = o.otr_id AND i.ain_habilitado = 1) AS INDISPONIBILIDADES,
        (SELECT COUNT(*) FROM [dbo].[Permiso_Trabajo] pt WHERE pt.ptr_orden_trabajo = o.otr_id AND pt.ptr_permiso_trabajo_estado NOT IN (2, 5)) AS PERMISOS_PENDIENTES,
        CASE WHEN o.otr_orden_trabajo_estado = 3 THEN DATEDIFF(DAY, ISNULL(o.otr_fecha_fin_real_utc, o.otr_fecha_actualizacion), GETUTCDATE()) ELSE NULL END AS DIAS_ESPERA_CIERRE,
        fal.fal_titulo                  AS FALLA_TITULO,
        pma.pma_codigo                  AS PLAN_CODIGO,
        COUNT(*) OVER ()                AS TOTAL
FROM    [dbo].[Orden_Trabajo] o
LEFT JOIN [dbo].[Cliente_Instalacion]      cin ON cin.cin_id = o.otr_cliente_instalacion
LEFT JOIN [dbo].[Instalacion_Area]         iar ON iar.iar_id = o.otr_instalacion_area
LEFT JOIN [dbo].[Activo]                   act ON act.act_id = o.otr_activo
LEFT JOIN [dbo].[Activo_Componente]        aco ON aco.aco_id = o.otr_activo_componente
LEFT JOIN [dbo].[Orden_Trabajo_Tipo]       oty ON oty.ott_id = o.otr_orden_trabajo_tipo
LEFT JOIN [dbo].[Orden_Trabajo_Estrategia] oes ON oes.oet_id = o.otr_orden_trabajo_estrategia
LEFT JOIN [dbo].[Orden_Trabajo_Origen]     oto ON oto.oto_id = o.otr_orden_trabajo_origen
LEFT JOIN [dbo].[Orden_Trabajo_Estado]     ote ON ote.ote_id = o.otr_orden_trabajo_estado
LEFT JOIN [dbo].[Orden_Trabajo_Prioridad]  opr ON opr.opr_id = o.otr_orden_trabajo_prioridad
LEFT JOIN [dbo].[Orden_Trabajo_Cierre_Motivo] ocm ON ocm.ocm_id = o.otr_cierre_motivo
LEFT JOIN [dbo].[Usuario] ug  ON ug.usu_id  = o.otr_usuario_generador
LEFT JOIN [dbo].[Usuario] uc  ON uc.usu_id  = o.otr_usuario_cierre
LEFT JOIN [dbo].[Usuario] ucr ON ucr.usu_id = o.otr_usuario_creacion
LEFT JOIN [dbo].[Usuario] uac ON uac.usu_id = o.otr_usuario_actualizacion
LEFT JOIN [dbo].[Orden_Trabajo_Asignacion] ota ON ota.ota_orden_trabajo = o.otr_id AND ota.ota_es_responsable = 1 AND ota.ota_habilitado = 1
LEFT JOIN [dbo].[Usuario]   ur  ON ur.usu_id  = ota.ota_usuario
LEFT JOIN [dbo].[Proveedor] prv ON prv.prv_id = ota.ota_proveedor
LEFT JOIN [dbo].[Falla]     fal ON fal.fal_id = o.otr_falla
LEFT JOIN [dbo].[Plan_Mantenimiento_Ocurrencia] pmo ON pmo.pmo_id = o.otr_plan_mantenimiento_ocurrencia
LEFT JOIN [dbo].[Plan_Mantenimiento_Hito] pmh ON pmh.pmh_id = pmo.pmo_plan_mantenimiento_hito
LEFT JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
LEFT JOIN [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
WHERE   o.otr_cliente = @CLIENTE AND o.otr_habilitado = 1
  AND   (@ID IS NULL OR o.otr_id = @ID)
  AND   (@INSTALACION IS NULL OR o.otr_cliente_instalacion = @INSTALACION)
  AND   (@ESTADO IS NULL OR o.otr_orden_trabajo_estado = @ESTADO)
  AND   (@TIPO IS NULL OR o.otr_orden_trabajo_tipo = @TIPO)
  AND   (@ORIGEN IS NULL OR o.otr_orden_trabajo_origen = @ORIGEN)
  AND   (@ACTIVO IS NULL OR o.otr_activo = @ACTIVO)
  AND   (@FALLA IS NULL OR o.otr_falla = @FALLA)
  AND   (@DESDE IS NULL OR o.otr_fecha_creacion >= CAST(@DESDE AS DATETIME))
  AND   (@HASTA IS NULL OR o.otr_fecha_creacion <  DATEADD(DAY, 1, CAST(@HASTA AS DATETIME)))
  AND   (@FILTRO IS NULL OR o.otr_titulo LIKE '%' + @FILTRO + '%' OR CAST(o.otr_correlativo AS NVARCHAR(20)) = @FILTRO
                         OR act.act_codigo LIKE '%' + @FILTRO + '%' OR act.act_nombre LIKE '%' + @FILTRO + '%')
-- La bandeja de cierre pide antiguedad primero; el listado, lo mas nuevo primero.
ORDER BY CASE WHEN @ESTADO = 3 THEN o.otr_fecha_actualizacion END ASC,
         o.otr_correlativo DESC
OFFSET (@PAGINA - 1) * @TAMANO ROWS
FETCH NEXT @TAMANO ROWS ONLY
GO

-- ---------------------------------------------------------------------------
-- 2) INS_ORDEN_TRABAJO — la correctiva desde la web (HU-110)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_ORDEN_TRABAJO]
@ID                       INT = NULL OUTPUT,
@CLIENTE                  INT,
@CLIENTE_INSTALACION      INT = NULL,
@INSTALACION_AREA         INT = NULL,
@ACTIVO                   INT = NULL,
@ACTIVO_COMPONENTE        INT = NULL,
@TIPO                     INT,
@ESTRATEGIA               INT,
@PRIORIDAD                INT,
@TITULO                   NVARCHAR(400),
@DESCRIPCION              NVARCHAR(MAX) = NULL,
@FECHA_PROGRAMADA_UTC     DATETIME = NULL,
@DURACION_ESTIMADA_MINUTO INT = NULL,
@REQUIERE_PERMISO         BIT = 0,
@REGISTRO_POSTERIOR       BIT = 0,
@FECHA_OCURRENCIA         DATETIME = NULL,
@FALLA                    INT = NULL,
@USUARIO                  INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @TITULO = LTRIM(RTRIM(@TITULO))

IF (@TITULO IS NULL OR @TITULO = N'')
BEGIN
    RAISERROR('1.- INDIQUE EL TÍTULO DE LA ORDEN.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Tipo] WHERE ott_id = @TIPO AND ott_habilitado = 1)
   OR NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Estrategia] WHERE oet_id = @ESTRATEGIA AND oet_habilitado = 1)
   OR NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Prioridad] WHERE opr_id = @PRIORIDAD AND opr_habilitado = 1)
BEGIN
    RAISERROR('2.- INDIQUE TIPO, ESTRATEGIA Y PRIORIDAD DE LA ORDEN.', 16, 1)
    RETURN -1
END

-- El equipo trae su planta y su area; sin equipo, la orden es de un area (HU-110 #4)
IF @ACTIVO IS NOT NULL
BEGIN
    DECLARE @PLANTA_ACT INT, @AREA_ACT INT
    SELECT @PLANTA_ACT = act_cliente_instalacion, @AREA_ACT = act_instalacion_area FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE
    IF @PLANTA_ACT IS NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE)
    BEGIN
        RAISERROR('3.- EL EQUIPO NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
    IF @CLIENTE_INSTALACION IS NULL SET @CLIENTE_INSTALACION = @PLANTA_ACT
    IF @INSTALACION_AREA IS NULL SET @INSTALACION_AREA = @AREA_ACT
    IF @ACTIVO_COMPONENTE IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_id = @ACTIVO_COMPONENTE AND aco_activo = @ACTIVO)
    BEGIN
        RAISERROR('4.- EL COMPONENTE NO ES DE ESE EQUIPO.', 16, 1)
        RETURN -1
    END
END
ELSE IF @INSTALACION_AREA IS NULL
BEGIN
    RAISERROR('5.- UNA ORDEN SIN EQUIPO TIENE QUE INDICAR EL ÁREA DONDE SE HACE.', 16, 1)
    RETURN -1
END

IF @INSTALACION_AREA IS NOT NULL
BEGIN
    DECLARE @PLANTA_AREA INT = (SELECT iar_cliente_instalacion FROM [dbo].[Instalacion_Area] WHERE iar_id = @INSTALACION_AREA AND iar_cliente = @CLIENTE)
    IF @PLANTA_AREA IS NULL
    BEGIN
        RAISERROR('6.- EL ÁREA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
    IF @CLIENTE_INSTALACION IS NULL SET @CLIENTE_INSTALACION = @PLANTA_AREA
END

IF @CLIENTE_INSTALACION IS NULL OR NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion] WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
BEGIN
    RAISERROR('7.- LA ORDEN NECESITA UNA PLANTA: POR EL EQUIPO, POR EL ÁREA O INDICADA.', 16, 1)
    RETURN -1
END

-- Registro posterior (HU-110 #3): cuando paso y cuando se anoto se guardan aparte
IF @REGISTRO_POSTERIOR = 1
BEGIN
    IF @FECHA_OCURRENCIA IS NULL
    BEGIN
        RAISERROR('8.- UN REGISTRO POSTERIOR TIENE QUE INDICAR CUÁNDO OCURRIÓ EL TRABAJO.', 16, 1)
        RETURN -1
    END
    IF @FECHA_OCURRENCIA > @DATE_NOW
    BEGIN
        RAISERROR('9.- LA FECHA DE OCURRENCIA NO PUEDE SER FUTURA.', 16, 1)
        RETURN -1
    END
END
ELSE SET @FECHA_OCURRENCIA = NULL

IF @FALLA IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Falla] WHERE fal_id = @FALLA AND fal_cliente = @CLIENTE)
BEGIN
    RAISERROR('10.- LA FALLA NO EXISTE.', 16, 1)
    RETURN -1
END

BEGIN TRY
    BEGIN TRANSACTION

    DECLARE @CORR INT
    SELECT @CORR = ISNULL(MAX(otr_correlativo), 0) + 1 FROM [dbo].[Orden_Trabajo] WITH (UPDLOCK, HOLDLOCK) WHERE otr_cliente = @CLIENTE

    INSERT INTO [dbo].[Orden_Trabajo]
        (otr_cliente, otr_cliente_instalacion, otr_instalacion_area, otr_correlativo, otr_activo, otr_activo_componente,
         otr_orden_trabajo_tipo, otr_orden_trabajo_estrategia, otr_orden_trabajo_origen, otr_orden_trabajo_estado, otr_orden_trabajo_prioridad,
         otr_usuario_generador, otr_titulo, otr_descripcion, otr_fecha_programada_utc, otr_duracion_estimada_minuto, otr_requiere_permiso,
         otr_falla, otr_registro_posterior, otr_fecha_ocurrencia, otr_usuario_creacion, otr_fecha_creacion)
    VALUES
        (@CLIENTE, @CLIENTE_INSTALACION, @INSTALACION_AREA, @CORR, @ACTIVO, @ACTIVO_COMPONENTE,
         @TIPO, @ESTRATEGIA, CASE WHEN @FALLA IS NULL THEN 1 ELSE 7 END, 1, @PRIORIDAD,
         @USUARIO, @TITULO, @DESCRIPCION, @FECHA_PROGRAMADA_UTC, @DURACION_ESTIMADA_MINUTO, ISNULL(@REQUIERE_PERMISO, 0),
         @FALLA, ISNULL(@REGISTRO_POSTERIOR, 0), @FECHA_OCURRENCIA, @USUARIO, @DATE_NOW)

    SET @ID = SCOPE_IDENTITY()

    INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
        (oeh_orden_trabajo, oeh_estado_anterior, oeh_estado_nuevo, oeh_motivo, oeh_fecha_cambio_utc, oeh_usuario_creacion, oeh_fecha_creacion)
    VALUES (@ID, NULL, 1, CASE WHEN @FALLA IS NULL THEN N'Creada desde la web' ELSE N'Creada desde la falla' END, GETUTCDATE(), @USUARIO, @DATE_NOW)

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_ORDEN_TRABAJO', @MSG = @MSG
    RAISERROR('11.- NO FUE POSIBLE CREAR LA ORDEN: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

RETURN 0
GO

-- ---------------------------------------------------------------------------
-- 3) UPD_ORDEN_TRABAJO — solo mientras esta ABIERTA
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_ORDEN_TRABAJO]
@ID                       INT,
@CLIENTE                  INT,
@TITULO                   NVARCHAR(400) = NULL,
@DESCRIPCION              NVARCHAR(MAX) = NULL,
@PRIORIDAD                INT = NULL,
@ESTRATEGIA               INT = NULL,
@FECHA_PROGRAMADA_UTC     DATETIME = NULL,
@DURACION_ESTIMADA_MINUTO INT = NULL,
@REQUIERE_PERMISO         BIT = NULL,
@NOTAS                    NVARCHAR(MAX) = NULL,
@QUITA_FECHA              BIT = 0,
@QUITA_DURACION           BIT = 0,
@USUARIO                  INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @ESTADO INT
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SELECT @ESTADO = otr_orden_trabajo_estado FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ID AND otr_cliente = @CLIENTE

IF @ESTADO IS NULL
BEGIN
    RAISERROR('1.- LA ORDEN NO EXISTE.', 16, 1)
    RETURN -1
END

IF @ESTADO = 4
BEGIN
    RAISERROR('2.- UNA ORDEN CERRADA NO SE EDITA; SE CONSULTA.', 16, 1)
    RETURN -1
END

SET @TITULO = LTRIM(RTRIM(@TITULO))
IF @TITULO IS NOT NULL AND @TITULO = N''
BEGIN
    RAISERROR('3.- INDIQUE EL TÍTULO DE LA ORDEN.', 16, 1)
    RETURN -1
END

UPDATE [dbo].[Orden_Trabajo]
SET otr_titulo                   = ISNULL(@TITULO, otr_titulo),
    otr_descripcion              = ISNULL(@DESCRIPCION, otr_descripcion),
    otr_orden_trabajo_prioridad  = ISNULL(@PRIORIDAD, otr_orden_trabajo_prioridad),
    otr_orden_trabajo_estrategia = ISNULL(@ESTRATEGIA, otr_orden_trabajo_estrategia),
    otr_fecha_programada_utc     = CASE WHEN @QUITA_FECHA = 1 THEN NULL ELSE ISNULL(@FECHA_PROGRAMADA_UTC, otr_fecha_programada_utc) END,
    otr_duracion_estimada_minuto = CASE WHEN @QUITA_DURACION = 1 THEN NULL ELSE ISNULL(@DURACION_ESTIMADA_MINUTO, otr_duracion_estimada_minuto) END,
    otr_requiere_permiso         = ISNULL(@REQUIERE_PERMISO, otr_requiere_permiso),
    otr_notas                    = ISNULL(@NOTAS, otr_notas),
    otr_usuario_actualizacion    = @USUARIO,
    otr_fecha_actualizacion      = @DATE_NOW
WHERE otr_id = @ID

RETURN 0
GO

-- ---------------------------------------------------------------------------
-- 4) Asignacion (HU-112)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_ORDEN_TRABAJO_ASIGNACION]
@CLIENTE INT,
@ORDEN   INT

AS
SET NOCOUNT ON

SELECT  a.ota_id, a.ota_orden_trabajo, a.ota_usuario, a.ota_proveedor, a.ota_grupo_trabajo, a.ota_es_responsable, a.ota_rol_ejecucion,
        a.ota_fecha_asignacion_utc, a.ota_fecha_aceptacion_utc, a.ota_observacion, a.ota_habilitado, a.ota_asignado_por,
        LTRIM(RTRIM(ISNULL(u.usu_nombre,'') + ' ' + ISNULL(u.usu_apellido_paterno,''))) AS USUARIO_NOMBRE,
        p.prv_razon_social               AS PROVEEDOR_NOMBRE,
        g.gtr_nombre                     AS GRUPO_NOMBRE,
        r.rej_codigo                     AS ROL_CODIGO,
        r.rej_nombre                     AS ROL_NOMBRE,
        LTRIM(RTRIM(ISNULL(ua.usu_nombre,'') + ' ' + ISNULL(ua.usu_apellido_paterno,''))) AS ASIGNADO_POR_NOMBRE,
        STUFF((SELECT ', ' + e.esp_nombre FROM [dbo].[Usuario_Especialidad] ue JOIN [dbo].[Especialidad] e ON e.esp_id = ue.ues_especialidad
               WHERE ue.ues_usuario = a.ota_usuario AND ue.ues_habilitado = 1 FOR XML PATH('')), 1, 2, '') AS ESPECIALIDADES
FROM    [dbo].[Orden_Trabajo_Asignacion] a
JOIN    [dbo].[Orden_Trabajo] o ON o.otr_id = a.ota_orden_trabajo
LEFT JOIN [dbo].[Usuario]       u  ON u.usu_id  = a.ota_usuario
LEFT JOIN [dbo].[Proveedor]     p  ON p.prv_id  = a.ota_proveedor
LEFT JOIN [dbo].[Grupo_Trabajo] g  ON g.gtr_id  = a.ota_grupo_trabajo
LEFT JOIN [dbo].[Rol_Ejecucion] r  ON r.rej_id  = a.ota_rol_ejecucion
LEFT JOIN [dbo].[Usuario]       ua ON ua.usu_id = a.ota_asignado_por
WHERE   o.otr_cliente = @CLIENTE AND a.ota_orden_trabajo = @ORDEN AND a.ota_habilitado = 1
ORDER BY a.ota_es_responsable DESC, a.ota_fecha_asignacion_utc
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_ORDEN_TRABAJO_ASIGNACION]
@ID             INT = NULL OUTPUT,
@CLIENTE        INT,
@ORDEN          INT,
@USUARIO_ASIG   INT = NULL,
@PROVEEDOR      INT = NULL,
@GRUPO_TRABAJO  INT = NULL,
@ES_RESPONSABLE BIT = 1,
@ROL_EJECUCION  INT = NULL,
@OBSERVACION    NVARCHAR(1000) = NULL,
@USUARIO        INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @ESTADO INT, @ADVERTENCIA NVARCHAR(400) = NULL
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SELECT @ESTADO = otr_orden_trabajo_estado FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN AND otr_cliente = @CLIENTE

IF @ESTADO IS NULL
BEGIN
    RAISERROR('1.- LA ORDEN NO EXISTE.', 16, 1)
    RETURN -1
END

IF @ESTADO IN (3, 4)
BEGIN
    RAISERROR('2.- UNA ORDEN EN ESPERA DE CIERRE O CERRADA YA NO SE ASIGNA.', 16, 1)
    RETURN -1
END

-- Una persona O una empresa externa (CK_OTA_EJECUTANTE), no las dos ni ninguna
IF (@USUARIO_ASIG IS NULL AND @PROVEEDOR IS NULL) OR (@USUARIO_ASIG IS NOT NULL AND @PROVEEDOR IS NOT NULL)
BEGIN
    RAISERROR('3.- INDIQUE UN TÉCNICO O UNA EMPRESA EXTERNA, NO AMBOS.', 16, 1)
    RETURN -1
END

IF @USUARIO_ASIG IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario] WHERE ucl_id_usuario = @USUARIO_ASIG AND ucl_id_cliente = @CLIENTE AND ucl_habilitado = 1)
BEGIN
    RAISERROR('4.- EL TÉCNICO NO ES USUARIO DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

-- HU-112 #2: la empresa sale del registro de contratistas; no se crea usuario
IF @PROVEEDOR IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Proveedor] WHERE prv_id = @PROVEEDOR AND prv_cliente = @CLIENTE AND prv_es_contratista = 1 AND prv_habilitado = 1)
BEGIN
    RAISERROR('5.- LA EMPRESA NO ESTÁ REGISTRADA COMO CONTRATISTA DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @GRUPO_TRABAJO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Grupo_Trabajo] WHERE gtr_id = @GRUPO_TRABAJO AND gtr_cliente = @CLIENTE)
BEGIN
    RAISERROR('6.- EL GRUPO DE TRABAJO NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @ROL_EJECUCION IS NULL SET @ROL_EJECUCION = CASE WHEN @ES_RESPONSABLE = 1 THEN 1 ELSE 2 END

-- Ya esta en la orden: se actualiza esa fila en vez de duplicar
DECLARE @YA INT = (SELECT TOP 1 ota_id FROM [dbo].[Orden_Trabajo_Asignacion]
                   WHERE ota_orden_trabajo = @ORDEN AND ota_habilitado = 1
                     AND ((@USUARIO_ASIG IS NOT NULL AND ota_usuario = @USUARIO_ASIG) OR (@PROVEEDOR IS NOT NULL AND ota_proveedor = @PROVEEDOR)))

-- HU-112 #4: especialidad requerida que el tecnico no tiene -> se advierte y se permite
IF @USUARIO_ASIG IS NOT NULL AND EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Especialidad] WHERE oep_orden_trabajo = @ORDEN)
BEGIN
    DECLARE @FALTAN NVARCHAR(400) =
        STUFF((SELECT ', ' + e.esp_nombre
               FROM [dbo].[Orden_Trabajo_Especialidad] oe JOIN [dbo].[Especialidad] e ON e.esp_id = oe.oep_especialidad
               WHERE oe.oep_orden_trabajo = @ORDEN
                 AND NOT EXISTS (SELECT 1 FROM [dbo].[Usuario_Especialidad] ue WHERE ue.ues_usuario = @USUARIO_ASIG AND ue.ues_especialidad = oe.oep_especialidad AND ue.ues_habilitado = 1)
               FOR XML PATH('')), 1, 2, '')
    IF @FALTAN IS NOT NULL
        SET @ADVERTENCIA = N'El técnico no tiene la especialidad requerida: ' + @FALTAN + N'.'
END

BEGIN TRY
    BEGIN TRANSACTION

    -- HU-112 #3: un solo responsable; el anterior pasa a apoyo
    IF @ES_RESPONSABLE = 1
        UPDATE [dbo].[Orden_Trabajo_Asignacion]
        SET ota_es_responsable = 0, ota_rol_ejecucion = 2, ota_usuario_actualizacion = @USUARIO, ota_fecha_actualizacion = @DATE_NOW
        WHERE ota_orden_trabajo = @ORDEN AND ota_es_responsable = 1 AND ota_habilitado = 1 AND ISNULL(ota_id, 0) <> ISNULL(@YA, 0)

    IF @YA IS NOT NULL
    BEGIN
        UPDATE [dbo].[Orden_Trabajo_Asignacion]
        SET ota_es_responsable = @ES_RESPONSABLE, ota_rol_ejecucion = @ROL_EJECUCION, ota_grupo_trabajo = ISNULL(@GRUPO_TRABAJO, ota_grupo_trabajo),
            ota_observacion = ISNULL(@ADVERTENCIA + CHAR(13) + CHAR(10), N'') + ISNULL(@OBSERVACION, N''),
            ota_usuario_actualizacion = @USUARIO, ota_fecha_actualizacion = @DATE_NOW
        WHERE ota_id = @YA
        SET @ID = @YA
    END
    ELSE
    BEGIN
        INSERT INTO [dbo].[Orden_Trabajo_Asignacion]
            (ota_orden_trabajo, ota_usuario, ota_proveedor, ota_grupo_trabajo, ota_es_responsable, ota_rol_ejecucion, ota_fecha_asignacion_utc,
             ota_observacion, ota_asignado_por, ota_usuario_creacion, ota_fecha_creacion, ota_habilitado)
        VALUES
            (@ORDEN, @USUARIO_ASIG, @PROVEEDOR, @GRUPO_TRABAJO, @ES_RESPONSABLE, @ROL_EJECUCION, GETUTCDATE(),
             ISNULL(@ADVERTENCIA + CHAR(13) + CHAR(10), N'') + ISNULL(@OBSERVACION, N''), @USUARIO, @USUARIO, @DATE_NOW, 1)
        SET @ID = SCOPE_IDENTITY()
    END

    -- HU-112 #1: le aparece en su bandeja y recibe una notificacion
    IF @USUARIO_ASIG IS NOT NULL AND OBJECT_ID('dbo.INS_NOTIFICACION') IS NOT NULL
    BEGIN
        DECLARE @TIT NVARCHAR(200) = (SELECT N'OT-' + CAST(otr_correlativo AS NVARCHAR(10)) + N' · ' + LEFT(otr_titulo, 150) FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN)
        BEGIN TRY
            EXEC [dbo].[INS_NOTIFICACION] @CLIENTE = @CLIENTE, @USUARIO_DESTINO = @USUARIO_ASIG, @TITULO = N'Te asignaron una orden de trabajo',
                 @MENSAJE = @TIT, @ENTIDAD = N'ORDEN', @ENTIDAD_ID = @ORDEN, @USUARIO = @USUARIO
        END TRY
        BEGIN CATCH
            -- La notificacion no puede tumbar la asignacion.
        END CATCH
    END

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_ORDEN_TRABAJO_ASIGNACION', @MSG = @MSG
    RAISERROR('7.- NO FUE POSIBLE ASIGNAR LA ORDEN: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

SELECT @ID AS OTA_ID, @ADVERTENCIA AS ADVERTENCIA
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[DEL_ORDEN_TRABAJO_ASIGNACION]
@ID      INT,
@CLIENTE INT,
@USUARIO INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Asignacion] a JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = a.ota_orden_trabajo
               WHERE a.ota_id = @ID AND o.otr_cliente = @CLIENTE AND o.otr_orden_trabajo_estado IN (1, 2))
BEGIN
    RAISERROR('1.- LA ASIGNACIÓN NO EXISTE O LA ORDEN YA NO ADMITE CAMBIOS.', 16, 1)
    RETURN -1
END

UPDATE [dbo].[Orden_Trabajo_Asignacion]
SET ota_habilitado = 0, ota_es_responsable = 0, ota_usuario_actualizacion = @USUARIO, ota_fecha_actualizacion = @DATE_NOW
WHERE ota_id = @ID

RETURN 0
GO

-- ---------------------------------------------------------------------------
-- 5) UPD_ORDEN_TRABAJO_CERRAR_WEB (HU-120 / HU-122)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_ORDEN_TRABAJO_CERRAR_WEB]
@ID            INT,
@CLIENTE       INT,
@CIERRE_MOTIVO INT,
@RESULTADO     NVARCHAR(MAX) = NULL,
@USUARIO       INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @ESTADO INT, @OCURRENCIA INT, @CORR INT
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @RESULTADO = LTRIM(RTRIM(@RESULTADO))

SELECT @ESTADO = otr_orden_trabajo_estado, @OCURRENCIA = otr_plan_mantenimiento_ocurrencia, @CORR = otr_correlativo
FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ID AND otr_cliente = @CLIENTE

IF @ESTADO IS NULL
BEGIN
    RAISERROR('1.- LA ORDEN NO EXISTE.', 16, 1)
    RETURN -1
END

-- HU-120 #2: la jerarquia. El tecnico finaliza; cerrar es del planificador, el supervisor o el jefe.
IF [dbo].[FNC_USUARIO_PUEDE_CERRAR_OT](@CLIENTE, @USUARIO) = 0
BEGIN
    RAISERROR('2.- SU PERFIL NO TIENE LA FACULTAD DE CERRAR ÓRDENES DE TRABAJO.', 16, 1)
    RETURN -1
END

IF @ESTADO = 4
BEGIN
    RAISERROR('3.- LA ORDEN OT-%d YA ESTÁ CERRADA.', 16, 1, @CORR)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Cierre_Motivo] WHERE ocm_id = @CIERRE_MOTIVO AND ocm_habilitado = 1)
BEGIN
    RAISERROR('4.- INDIQUE EL MOTIVO DE CIERRE.', 16, 1)
    RETURN -1
END

-- HU-120 #4: el trabajo realizado se describe; anular o marcar duplicada no lo exige
IF @CIERRE_MOTIVO = 1 AND (@RESULTADO IS NULL OR LEN(@RESULTADO) < 5)
BEGIN
    RAISERROR('5.- DESCRIBA EL TRABAJO REALIZADO PARA CERRAR LA ORDEN OT-%d.', 16, 1, @CORR)
    RETURN -1
END

-- Solo se cierra como TRABAJO REALIZADO lo que el tecnico finalizo (#1); lo demas se anula desde cualquier estado (#3)
IF @CIERRE_MOTIVO IN (1, 2, 3) AND @ESTADO <> 3
BEGIN
    RAISERROR('6.- LA ORDEN OT-%d NO ESTÁ EN ESPERA DE CIERRE: EL TÉCNICO TIENE QUE FINALIZARLA PRIMERO (O ANÚLELA).', 16, 1, @CORR)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo] WHERE ptr_orden_trabajo = @ID AND ptr_permiso_trabajo_estado NOT IN (2, 5)) AND @CIERRE_MOTIVO = 1
BEGIN
    RAISERROR('7.- HAY PERMISOS DE TRABAJO SIN AUTORIZAR EN LA OT-%d; NO SE PUEDE CERRAR.', 16, 1, @CORR)
    RETURN -1
END

BEGIN TRY
    BEGIN TRANSACTION

    UPDATE [dbo].[Orden_Trabajo]
    SET otr_orden_trabajo_estado = 4, otr_cierre_motivo = @CIERRE_MOTIVO, otr_usuario_cierre = @USUARIO, otr_fecha_cierre = @DATE_NOW,
        otr_resultado = ISNULL(@RESULTADO, otr_resultado),
        otr_fecha_fin_real_utc = ISNULL(otr_fecha_fin_real_utc, CASE WHEN @CIERRE_MOTIVO = 1 THEN GETUTCDATE() ELSE NULL END),
        otr_usuario_actualizacion = @USUARIO, otr_fecha_actualizacion = @DATE_NOW
    WHERE otr_id = @ID

    INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
        (oeh_orden_trabajo, oeh_estado_anterior, oeh_estado_nuevo, oeh_motivo, oeh_fecha_cambio_utc, oeh_usuario_creacion, oeh_fecha_creacion)
    SELECT @ID, @ESTADO, 4, N'Cerrada desde la web: ' + ocm_nombre, GETUTCDATE(), @USUARIO, @DATE_NOW
    FROM [dbo].[Orden_Trabajo_Cierre_Motivo] WHERE ocm_id = @CIERRE_MOTIVO

    -- La ocurrencia del plan se completa (o se omite) con el cierre
    IF @OCURRENCIA IS NOT NULL
    BEGIN
        DECLARE @NUEVO INT = CASE WHEN @CIERRE_MOTIVO IN (1, 2) THEN 4 ELSE 5 END, @ANT INT
        SELECT @ANT = pmo_plan_ocurrencia_estado FROM [dbo].[Plan_Mantenimiento_Ocurrencia] WHERE pmo_id = @OCURRENCIA
        UPDATE [dbo].[Plan_Mantenimiento_Ocurrencia]
        SET pmo_plan_ocurrencia_estado = @NUEVO, pmo_usuario_actualizacion = @USUARIO, pmo_fecha_actualizacion = @DATE_NOW
        WHERE pmo_id = @OCURRENCIA AND pmo_plan_ocurrencia_estado NOT IN (4, 5, 6)
        IF @@ROWCOUNT > 0
            INSERT INTO [dbo].[Plan_Ocurrencia_Historial] (poh_plan_mantenimiento_ocurrencia, poh_estado_anterior, poh_estado_nuevo, poh_motivo, poh_usuario_creacion, poh_fecha_creacion)
            VALUES (@OCURRENCIA, @ANT, @NUEVO, N'Cierre de la OT-' + CAST(@CORR AS NVARCHAR(10)), @USUARIO, @DATE_NOW)
    END

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'UPD_ORDEN_TRABAJO_CERRAR_WEB', @MSG = @MSG
    RAISERROR('8.- NO FUE POSIBLE CERRAR LA ORDEN: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

RETURN 0
GO

-- ---------------------------------------------------------------------------
-- 6) Fallas (HU-123)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_FALLA]
@ID          INT = NULL,
@CLIENTE     INT,
@ACTIVO      INT = NULL,
@INSTALACION INT = NULL,
@ABIERTAS    BIT = NULL,
@FILTRO      NVARCHAR(200) = NULL

AS
SET NOCOUNT ON

SELECT  f.fal_id, f.fal_uuid, f.fal_cliente, f.fal_activo, f.fal_activo_componente, f.fal_falla_sintoma, f.fal_criticidad_nivel,
        f.fal_titulo, f.fal_descripcion, f.fal_consecuencia, f.fal_activo_estado_posterior, f.fal_detuvo_produccion,
        f.fal_fecha_deteccion_utc, f.fal_fecha_solucion_utc, f.fal_usuario_reporta,
        f.fal_usuario_creacion, f.fal_fecha_creacion, f.fal_usuario_actualizacion, f.fal_fecha_actualizacion, f.fal_habilitado,
        act.act_codigo AS ACTIVO_CODIGO, act.act_nombre AS ACTIVO_NOMBRE, cin.cin_nombre AS PLANTA_NOMBRE,
        act.act_cliente_instalacion AS ACTIVO_INSTALACION,
        aco.aco_nombre AS COMPONENTE_NOMBRE, fs.fsi_nombre AS SINTOMA_NOMBRE,
        crn.crn_codigo AS CRITICIDAD_CODIGO, crn.crn_nombre AS CRITICIDAD_NOMBRE,
        aes.aes_nombre AS ESTADO_POSTERIOR_NOMBRE,
        LTRIM(RTRIM(ISNULL(ur.usu_nombre,'') + ' ' + ISNULL(ur.usu_apellido_paterno,''))) AS REPORTA_NOMBRE,
        LTRIM(RTRIM(ISNULL(uc.usu_nombre,'') + ' ' + ISNULL(uc.usu_apellido_paterno,''))) AS USUARIO_CREACION_NOMBRE,
        LTRIM(RTRIM(ISNULL(ua.usu_nombre,'') + ' ' + ISNULL(ua.usu_apellido_paterno,''))) AS USUARIO_ACTUALIZACION_NOMBRE,
        (SELECT COUNT(*) FROM [dbo].[Falla_Diagnostico] d WHERE d.fdi_falla = f.fal_id AND d.fdi_habilitado = 1) AS DIAGNOSTICOS,
        (SELECT COUNT(*) FROM [dbo].[Falla_Accion] a WHERE a.fac_falla = f.fal_id AND a.fac_habilitado = 1) AS ACCIONES,
        (SELECT COUNT(*) FROM [dbo].[Falla_Accion] a WHERE a.fac_falla = f.fal_id AND a.fac_habilitado = 1 AND a.fac_es_definitiva = 0) AS ACCIONES_PROVISORIAS,
        (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo] o WHERE o.otr_falla = f.fal_id AND o.otr_habilitado = 1) AS ORDENES,
        (SELECT TOP 1 o.otr_correlativo FROM [dbo].[Orden_Trabajo] o WHERE o.otr_falla = f.fal_id AND o.otr_habilitado = 1 ORDER BY o.otr_id DESC) AS ULTIMA_OT_CORRELATIVO,
        (SELECT COUNT(*) FROM [dbo].[Activo_Indisponibilidad] i WHERE i.ain_falla = f.fal_id AND i.ain_habilitado = 1) AS INDISPONIBILIDADES,
        -- Reparado de forma provisoria varias veces: el equipo que pide atencion (HU-123 #3)
        (SELECT COUNT(*) FROM [dbo].[Falla_Accion] a JOIN [dbo].[Falla] f2 ON f2.fal_id = a.fac_falla
         WHERE f2.fal_activo = f.fal_activo AND a.fac_es_definitiva = 0 AND a.fac_habilitado = 1 AND f2.fal_habilitado = 1) AS PROVISORIAS_DEL_EQUIPO
FROM    [dbo].[Falla] f
JOIN    [dbo].[Activo] act ON act.act_id = f.fal_activo
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = act.act_cliente_instalacion
LEFT JOIN [dbo].[Activo_Componente] aco ON aco.aco_id = f.fal_activo_componente
LEFT JOIN [dbo].[Falla_Sintoma] fs ON fs.fsi_id = f.fal_falla_sintoma
LEFT JOIN [dbo].[Criticidad_Nivel] crn ON crn.crn_id = f.fal_criticidad_nivel
LEFT JOIN [dbo].[Activo_Estado] aes ON aes.aes_id = f.fal_activo_estado_posterior
LEFT JOIN [dbo].[Usuario] ur ON ur.usu_id = f.fal_usuario_reporta
LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = f.fal_usuario_creacion
LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = f.fal_usuario_actualizacion
WHERE   f.fal_cliente = @CLIENTE AND f.fal_habilitado = 1
  AND   (@ID IS NULL OR f.fal_id = @ID)
  AND   (@ACTIVO IS NULL OR f.fal_activo = @ACTIVO)
  AND   (@INSTALACION IS NULL OR act.act_cliente_instalacion = @INSTALACION)
  AND   (@ABIERTAS IS NULL OR (@ABIERTAS = 1 AND f.fal_fecha_solucion_utc IS NULL) OR (@ABIERTAS = 0 AND f.fal_fecha_solucion_utc IS NOT NULL))
  AND   (@FILTRO IS NULL OR f.fal_titulo LIKE '%' + @FILTRO + '%' OR act.act_codigo LIKE '%' + @FILTRO + '%' OR act.act_nombre LIKE '%' + @FILTRO + '%')
ORDER BY f.fal_fecha_deteccion_utc DESC
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_FALLA]
@ID                    INT = NULL OUTPUT,
@CLIENTE               INT,
@ACTIVO                INT,
@ACTIVO_COMPONENTE     INT = NULL,
@FALLA_SINTOMA         INT = NULL,
@CRITICIDAD_NIVEL      INT,
@TITULO                NVARCHAR(400),
@DESCRIPCION           NVARCHAR(MAX) = NULL,
@CONSECUENCIA          NVARCHAR(MAX) = NULL,
@ESTADO_POSTERIOR      INT = NULL,
@DETUVO_PRODUCCION     BIT = 0,
@FECHA_DETECCION_UTC   DATETIME = NULL,
@USUARIO               INT

AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @TITULO = LTRIM(RTRIM(@TITULO))
IF @FECHA_DETECCION_UTC IS NULL SET @FECHA_DETECCION_UTC = GETUTCDATE()

IF (@TITULO IS NULL OR @TITULO = N'')
BEGIN
    RAISERROR('1.- INDIQUE EL SÍNTOMA O TÍTULO DE LA FALLA.', 16, 1)
    RETURN -1
END
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE)
BEGIN
    RAISERROR('2.- EL EQUIPO NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF @ACTIVO_COMPONENTE IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_id = @ACTIVO_COMPONENTE AND aco_activo = @ACTIVO)
BEGIN
    RAISERROR('3.- EL COMPONENTE NO ES DE ESE EQUIPO.', 16, 1)
    RETURN -1
END
IF NOT EXISTS (SELECT 1 FROM [dbo].[Criticidad_Nivel] WHERE crn_id = @CRITICIDAD_NIVEL AND crn_habilitado = 1)
BEGIN
    RAISERROR('4.- INDIQUE LA CRITICIDAD DE LA FALLA.', 16, 1)
    RETURN -1
END
IF @FECHA_DETECCION_UTC > DATEADD(MINUTE, 5, GETUTCDATE())
BEGIN
    RAISERROR('5.- LA FECHA DE DETECCIÓN NO PUEDE SER FUTURA.', 16, 1)
    RETURN -1
END

BEGIN TRY
    BEGIN TRANSACTION

    INSERT INTO [dbo].[Falla]
        (fal_uuid, fal_cliente, fal_activo, fal_activo_componente, fal_falla_sintoma, fal_criticidad_nivel, fal_titulo, fal_descripcion, fal_consecuencia,
         fal_activo_estado_posterior, fal_detuvo_produccion, fal_fecha_deteccion_utc, fal_usuario_reporta, fal_usuario_creacion, fal_fecha_creacion, fal_habilitado)
    VALUES
        (NEWID(), @CLIENTE, @ACTIVO, @ACTIVO_COMPONENTE, @FALLA_SINTOMA, @CRITICIDAD_NIVEL, @TITULO, @DESCRIPCION, @CONSECUENCIA,
         @ESTADO_POSTERIOR, ISNULL(@DETUVO_PRODUCCION, 0), @FECHA_DETECCION_UTC, @USUARIO, @USUARIO, @DATE_NOW, 1)

    SET @ID = SCOPE_IDENTITY()

    -- HU-123 #4: el estado en que queda el equipo se registra en su historial, con el mismo SP de «Cambiar estado».
    -- Si el equipo ya esta en ese estado (una segunda falla del mismo equipo detenido) no hay cambio que registrar:
    -- la falla se guarda igual, con el estado posterior anotado.
    IF @ESTADO_POSTERIOR IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_activo_estado = @ESTADO_POSTERIOR)
    BEGIN
        DECLARE @MOT NVARCHAR(500) = LEFT(N'Falla: ' + @TITULO, 500), @H INT
        EXEC [dbo].[ACTIVO_CAMBIAR_ESTADO] @ID = @H OUTPUT, @ACTIVO = @ACTIVO, @CLIENTE = @CLIENTE, @NUEVO_ESTADO = @ESTADO_POSTERIOR, @MOTIVO = @MOT, @USUARIO = @USUARIO
    END

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
    EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_FALLA', @MSG = @MSG
    RAISERROR('6.- NO FUE POSIBLE REGISTRAR LA FALLA: %s', 16, 1, @MSG)
    RETURN -1
END CATCH

RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_FALLA]
@ID                  INT,
@CLIENTE             INT,
@TITULO              NVARCHAR(400) = NULL,
@DESCRIPCION         NVARCHAR(MAX) = NULL,
@CONSECUENCIA        NVARCHAR(MAX) = NULL,
@CRITICIDAD_NIVEL    INT = NULL,
@DETUVO_PRODUCCION   BIT = NULL,
@FECHA_SOLUCION_UTC  DATETIME = NULL,
@QUITA_SOLUCION      BIT = 0,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @DET DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SELECT @DET = fal_fecha_deteccion_utc FROM [dbo].[Falla] WHERE fal_id = @ID AND fal_cliente = @CLIENTE

IF @DET IS NULL
BEGIN
    RAISERROR('1.- LA FALLA NO EXISTE.', 16, 1)
    RETURN -1
END
IF @FECHA_SOLUCION_UTC IS NOT NULL AND @FECHA_SOLUCION_UTC < @DET
BEGIN
    RAISERROR('2.- LA SOLUCIÓN NO PUEDE SER ANTERIOR A LA DETECCIÓN.', 16, 1)
    RETURN -1
END

UPDATE [dbo].[Falla]
SET fal_titulo = ISNULL(NULLIF(LTRIM(RTRIM(@TITULO)), N''), fal_titulo),
    fal_descripcion = ISNULL(@DESCRIPCION, fal_descripcion),
    fal_consecuencia = ISNULL(@CONSECUENCIA, fal_consecuencia),
    fal_criticidad_nivel = ISNULL(@CRITICIDAD_NIVEL, fal_criticidad_nivel),
    fal_detuvo_produccion = ISNULL(@DETUVO_PRODUCCION, fal_detuvo_produccion),
    fal_fecha_solucion_utc = CASE WHEN @QUITA_SOLUCION = 1 THEN NULL ELSE ISNULL(@FECHA_SOLUCION_UTC, fal_fecha_solucion_utc) END,
    fal_usuario_actualizacion = @USUARIO, fal_fecha_actualizacion = @DATE_NOW
WHERE fal_id = @ID

RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_FALLA_DIAGNOSTICO]
@CLIENTE INT,
@FALLA   INT

AS
SET NOCOUNT ON

SELECT  d.fdi_id, d.fdi_falla, d.fdi_falla_modo, d.fdi_falla_causa, d.fdi_diagnostico_metodo, d.fdi_descripcion, d.fdi_es_definitivo, d.fdi_confianza,
        d.fdi_usuario_diagnostica, d.fdi_fecha_diagnostico_utc, d.fdi_fecha_creacion, d.fdi_habilitado,
        fm.fmo_nombre AS MODO_NOMBRE, fc.fca_nombre AS CAUSA_NOMBRE, dm.dme_nombre AS METODO_NOMBRE,
        LTRIM(RTRIM(ISNULL(u.usu_nombre,'') + ' ' + ISNULL(u.usu_apellido_paterno,''))) AS DIAGNOSTICA_NOMBRE
FROM    [dbo].[Falla_Diagnostico] d
JOIN    [dbo].[Falla] f ON f.fal_id = d.fdi_falla AND f.fal_cliente = @CLIENTE
LEFT JOIN [dbo].[Falla_Modo] fm ON fm.fmo_id = d.fdi_falla_modo
LEFT JOIN [dbo].[Falla_Causa] fc ON fc.fca_id = d.fdi_falla_causa
LEFT JOIN [dbo].[Diagnostico_Metodo] dm ON dm.dme_id = d.fdi_diagnostico_metodo
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = d.fdi_usuario_diagnostica
WHERE   d.fdi_falla = @FALLA AND d.fdi_habilitado = 1
ORDER BY d.fdi_fecha_diagnostico_utc, d.fdi_id
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_FALLA_DIAGNOSTICO]
@ID                 INT = NULL OUTPUT,
@CLIENTE            INT,
@FALLA              INT,
@FALLA_MODO         INT = NULL,
@FALLA_CAUSA        INT = NULL,
@DIAGNOSTICO_METODO INT = NULL,
@DESCRIPCION        NVARCHAR(MAX),
@ES_DEFINITIVO      BIT = 0,
@CONFIANZA          DECIMAL(5,2) = NULL,
@USUARIO            INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @DESCRIPCION = LTRIM(RTRIM(@DESCRIPCION))

IF NOT EXISTS (SELECT 1 FROM [dbo].[Falla] WHERE fal_id = @FALLA AND fal_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA FALLA NO EXISTE.', 16, 1)
    RETURN -1
END
IF (@DESCRIPCION IS NULL OR @DESCRIPCION = N'')
BEGIN
    RAISERROR('2.- DESCRIBA EL DIAGNÓSTICO.', 16, 1)
    RETURN -1
END
IF @CONFIANZA IS NOT NULL AND (@CONFIANZA < 0 OR @CONFIANZA > 100)
BEGIN
    RAISERROR('3.- LA CONFIANZA VA DE 0 A 100.', 16, 1)
    RETURN -1
END

-- Varios diagnosticos sucesivos (#2): el definitivo desmarca a los anteriores
IF @ES_DEFINITIVO = 1
    UPDATE [dbo].[Falla_Diagnostico] SET fdi_es_definitivo = 0, fdi_usuario_actualizacion = @USUARIO, fdi_fecha_actualizacion = @DATE_NOW
    WHERE fdi_falla = @FALLA AND fdi_es_definitivo = 1

INSERT INTO [dbo].[Falla_Diagnostico]
    (fdi_falla, fdi_falla_modo, fdi_falla_causa, fdi_diagnostico_metodo, fdi_descripcion, fdi_es_definitivo, fdi_confianza,
     fdi_usuario_diagnostica, fdi_fecha_diagnostico_utc, fdi_usuario_creacion, fdi_fecha_creacion, fdi_habilitado)
VALUES
    (@FALLA, @FALLA_MODO, @FALLA_CAUSA, @DIAGNOSTICO_METODO, @DESCRIPCION, ISNULL(@ES_DEFINITIVO, 0), @CONFIANZA,
     @USUARIO, GETUTCDATE(), @USUARIO, @DATE_NOW, 1)

SET @ID = SCOPE_IDENTITY()
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_FALLA_ACCION]
@CLIENTE INT,
@FALLA   INT

AS
SET NOCOUNT ON

SELECT  a.fac_id, a.fac_falla, a.fac_falla_diagnostico, a.fac_orden_trabajo, a.fac_descripcion, a.fac_es_definitiva, a.fac_fecha_accion_utc,
        a.fac_usuario_ejecuta, a.fac_fecha_creacion, a.fac_habilitado,
        o.otr_correlativo AS OT_CORRELATIVO,
        LTRIM(RTRIM(ISNULL(u.usu_nombre,'') + ' ' + ISNULL(u.usu_apellido_paterno,''))) AS EJECUTA_NOMBRE
FROM    [dbo].[Falla_Accion] a
JOIN    [dbo].[Falla] f ON f.fal_id = a.fac_falla AND f.fal_cliente = @CLIENTE
LEFT JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = a.fac_orden_trabajo
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = a.fac_usuario_ejecuta
WHERE   a.fac_falla = @FALLA AND a.fac_habilitado = 1
ORDER BY a.fac_fecha_accion_utc, a.fac_id
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_FALLA_ACCION]
@ID                INT = NULL OUTPUT,
@CLIENTE           INT,
@FALLA             INT,
@FALLA_DIAGNOSTICO INT = NULL,
@ORDEN_TRABAJO     INT = NULL,
@DESCRIPCION       NVARCHAR(MAX),
@ES_DEFINITIVA     BIT = 0,
@FECHA_ACCION_UTC  DATETIME = NULL,
@USUARIO           INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SET @DESCRIPCION = LTRIM(RTRIM(@DESCRIPCION))

IF NOT EXISTS (SELECT 1 FROM [dbo].[Falla] WHERE fal_id = @FALLA AND fal_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA FALLA NO EXISTE.', 16, 1)
    RETURN -1
END
IF (@DESCRIPCION IS NULL OR @DESCRIPCION = N'')
BEGIN
    RAISERROR('2.- DESCRIBA LA ACCIÓN.', 16, 1)
    RETURN -1
END
IF @FALLA_DIAGNOSTICO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Falla_Diagnostico] WHERE fdi_id = @FALLA_DIAGNOSTICO AND fdi_falla = @FALLA)
BEGIN
    RAISERROR('3.- EL DIAGNÓSTICO NO ES DE ESTA FALLA.', 16, 1)
    RETURN -1
END
IF @ORDEN_TRABAJO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN_TRABAJO AND otr_cliente = @CLIENTE)
BEGIN
    RAISERROR('4.- LA ORDEN NO EXISTE.', 16, 1)
    RETURN -1
END

INSERT INTO [dbo].[Falla_Accion]
    (fac_falla, fac_falla_diagnostico, fac_orden_trabajo, fac_descripcion, fac_es_definitiva, fac_fecha_accion_utc, fac_usuario_ejecuta,
     fac_usuario_creacion, fac_fecha_creacion, fac_habilitado)
VALUES
    (@FALLA, @FALLA_DIAGNOSTICO, @ORDEN_TRABAJO, @DESCRIPCION, ISNULL(@ES_DEFINITIVA, 0), ISNULL(@FECHA_ACCION_UTC, GETUTCDATE()), @USUARIO,
     @USUARIO, @DATE_NOW, 1)

SET @ID = SCOPE_IDENTITY()

-- Una accion definitiva cierra la falla si no tenia fecha de solucion
IF @ES_DEFINITIVA = 1
    UPDATE [dbo].[Falla] SET fal_fecha_solucion_utc = ISNULL(fal_fecha_solucion_utc, ISNULL(@FECHA_ACCION_UTC, GETUTCDATE())),
           fal_usuario_actualizacion = @USUARIO, fal_fecha_actualizacion = @DATE_NOW
    WHERE fal_id = @FALLA

RETURN 0
GO

-- ---------------------------------------------------------------------------
-- 7) Indisponibilidad (HU-124)
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_INDISPONIBILIDAD]
@ID          INT = NULL,
@CLIENTE     INT,
@ACTIVO      INT = NULL,
@ORDEN       INT = NULL,
@FALLA       INT = NULL,
@INSTALACION INT = NULL,
@DESDE       DATE = NULL,
@HASTA       DATE = NULL

AS
SET NOCOUNT ON

SELECT  i.ain_id, i.ain_cliente, i.ain_activo, i.ain_orden_trabajo, i.ain_falla, i.ain_fecha_inicio_utc, i.ain_fecha_fin_utc, i.ain_minuto,
        i.ain_planificada, i.ain_detuvo_produccion, i.ain_indisponibilidad_motivo, i.ain_motivo,
        i.ain_usuario_creacion, i.ain_fecha_creacion, i.ain_usuario_actualizacion, i.ain_fecha_actualizacion, i.ain_habilitado,
        act.act_codigo AS ACTIVO_CODIGO, act.act_nombre AS ACTIVO_NOMBRE, cin.cin_nombre AS PLANTA_NOMBRE,
        im.inm_nombre AS MOTIVO_NOMBRE, o.otr_correlativo AS OT_CORRELATIVO, f.fal_titulo AS FALLA_TITULO,
        -- Abierta: sin termino todavia; los minutos corren
        CASE WHEN i.ain_fecha_fin_utc IS NULL THEN DATEDIFF(MINUTE, i.ain_fecha_inicio_utc, GETUTCDATE()) ELSE i.ain_minuto END AS MINUTOS_ACUMULADOS,
        LTRIM(RTRIM(ISNULL(uc.usu_nombre,'') + ' ' + ISNULL(uc.usu_apellido_paterno,''))) AS USUARIO_CREACION_NOMBRE
FROM    [dbo].[Activo_Indisponibilidad] i
JOIN    [dbo].[Activo] act ON act.act_id = i.ain_activo
LEFT JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = act.act_cliente_instalacion
LEFT JOIN [dbo].[Indisponibilidad_Motivo] im ON im.inm_id = i.ain_indisponibilidad_motivo
LEFT JOIN [dbo].[Orden_Trabajo] o ON o.otr_id = i.ain_orden_trabajo
LEFT JOIN [dbo].[Falla] f ON f.fal_id = i.ain_falla
LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = i.ain_usuario_creacion
WHERE   i.ain_cliente = @CLIENTE AND i.ain_habilitado = 1
  AND   (@ID IS NULL OR i.ain_id = @ID)
  AND   (@ACTIVO IS NULL OR i.ain_activo = @ACTIVO)
  AND   (@ORDEN IS NULL OR i.ain_orden_trabajo = @ORDEN)
  AND   (@FALLA IS NULL OR i.ain_falla = @FALLA)
  AND   (@INSTALACION IS NULL OR act.act_cliente_instalacion = @INSTALACION)
  AND   (@DESDE IS NULL OR i.ain_fecha_inicio_utc >= CAST(@DESDE AS DATETIME))
  AND   (@HASTA IS NULL OR i.ain_fecha_inicio_utc < DATEADD(DAY, 1, CAST(@HASTA AS DATETIME)))
ORDER BY i.ain_fecha_inicio_utc DESC
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_ACTIVO_INDISPONIBILIDAD]
@ID                INT = NULL OUTPUT,
@CLIENTE           INT,
@ACTIVO            INT,
@ORDEN_TRABAJO     INT = NULL,
@FALLA             INT = NULL,
@FECHA_INICIO_UTC  DATETIME,
@FECHA_FIN_UTC     DATETIME = NULL,
@PLANIFICADA       BIT = 0,
@DETUVO_PRODUCCION BIT = 0,
@MOTIVO_CATALOGO   INT = NULL,
@MOTIVO            NVARCHAR(1000) = NULL,
@USUARIO           INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL EQUIPO NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END
IF @FECHA_INICIO_UTC IS NULL
BEGIN
    RAISERROR('2.- INDIQUE CUÁNDO EMPEZÓ LA INDISPONIBILIDAD.', 16, 1)
    RETURN -1
END
IF @FECHA_FIN_UTC IS NOT NULL AND @FECHA_FIN_UTC < @FECHA_INICIO_UTC
BEGIN
    RAISERROR('3.- EL TÉRMINO NO PUEDE SER ANTERIOR AL INICIO.', 16, 1)
    RETURN -1
END
IF @ORDEN_TRABAJO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN_TRABAJO AND otr_cliente = @CLIENTE)
BEGIN
    RAISERROR('4.- LA ORDEN NO EXISTE.', 16, 1)
    RETURN -1
END
IF @FALLA IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Falla] WHERE fal_id = @FALLA AND fal_cliente = @CLIENTE)
BEGIN
    RAISERROR('5.- LA FALLA NO EXISTE.', 16, 1)
    RETURN -1
END
IF @MOTIVO_CATALOGO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Indisponibilidad_Motivo] WHERE inm_id = @MOTIVO_CATALOGO AND inm_habilitado = 1)
BEGIN
    RAISERROR('6.- EL MOTIVO NO EXISTE.', 16, 1)
    RETURN -1
END
IF @MOTIVO_CATALOGO IS NULL AND (@MOTIVO IS NULL OR LTRIM(RTRIM(@MOTIVO)) = N'')
BEGIN
    RAISERROR('7.- INDIQUE EL MOTIVO DE LA INDISPONIBILIDAD.', 16, 1)
    RETURN -1
END

INSERT INTO [dbo].[Activo_Indisponibilidad]
    (ain_cliente, ain_activo, ain_orden_trabajo, ain_falla, ain_fecha_inicio_utc, ain_fecha_fin_utc,
     ain_minuto, ain_planificada, ain_detuvo_produccion, ain_indisponibilidad_motivo, ain_motivo,
     ain_usuario_creacion, ain_fecha_creacion, ain_habilitado)
VALUES
    (@CLIENTE, @ACTIVO, @ORDEN_TRABAJO, @FALLA, @FECHA_INICIO_UTC, @FECHA_FIN_UTC,
     CASE WHEN @FECHA_FIN_UTC IS NULL THEN NULL ELSE DATEDIFF(MINUTE, @FECHA_INICIO_UTC, @FECHA_FIN_UTC) END,   -- #1 los minutos se calculan
     ISNULL(@PLANIFICADA, 0), ISNULL(@DETUVO_PRODUCCION, 0), @MOTIVO_CATALOGO, @MOTIVO,
     @USUARIO, @DATE_NOW, 1)

SET @ID = SCOPE_IDENTITY()
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_ACTIVO_INDISPONIBILIDAD]
@ID                INT,
@CLIENTE           INT,
@FECHA_FIN_UTC     DATETIME = NULL,
@PLANIFICADA       BIT = NULL,
@DETUVO_PRODUCCION BIT = NULL,
@MOTIVO_CATALOGO   INT = NULL,
@MOTIVO            NVARCHAR(1000) = NULL,
@HABILITADO        BIT = NULL,
@USUARIO           INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @INI DATETIME
SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)
SELECT @INI = ain_fecha_inicio_utc FROM [dbo].[Activo_Indisponibilidad] WHERE ain_id = @ID AND ain_cliente = @CLIENTE

IF @INI IS NULL
BEGIN
    RAISERROR('1.- LA INDISPONIBILIDAD NO EXISTE.', 16, 1)
    RETURN -1
END
IF @FECHA_FIN_UTC IS NOT NULL AND @FECHA_FIN_UTC < @INI
BEGIN
    RAISERROR('2.- EL TÉRMINO NO PUEDE SER ANTERIOR AL INICIO.', 16, 1)
    RETURN -1
END

UPDATE [dbo].[Activo_Indisponibilidad]
SET ain_fecha_fin_utc = ISNULL(@FECHA_FIN_UTC, ain_fecha_fin_utc),
    ain_minuto = CASE WHEN ISNULL(@FECHA_FIN_UTC, ain_fecha_fin_utc) IS NULL THEN NULL ELSE DATEDIFF(MINUTE, ain_fecha_inicio_utc, ISNULL(@FECHA_FIN_UTC, ain_fecha_fin_utc)) END,
    ain_planificada = ISNULL(@PLANIFICADA, ain_planificada),
    ain_detuvo_produccion = ISNULL(@DETUVO_PRODUCCION, ain_detuvo_produccion),
    ain_indisponibilidad_motivo = ISNULL(@MOTIVO_CATALOGO, ain_indisponibilidad_motivo),
    ain_motivo = ISNULL(@MOTIVO, ain_motivo),
    ain_habilitado = ISNULL(@HABILITADO, ain_habilitado),
    ain_usuario_actualizacion = @USUARIO, ain_fecha_actualizacion = @DATE_NOW
WHERE ain_id = @ID

RETURN 0
GO

-- ---------------------------------------------------------------------------
-- 9) SEL_ORDEN_TRABAJO_PASO — los pasos, para leerlos desde la web
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_ORDEN_TRABAJO_PASO]
@CLIENTE INT,
@ORDEN   INT

AS
SET NOCOUNT ON

SELECT  p.otp_id, p.otp_orden, p.otp_nombre, p.otp_descripcion, p.otp_obligatorio, p.otp_resultado_paso, p.otp_resultado, p.otp_fecha_ejecucion_utc,
        r.rpa_codigo AS RESULTADO_CODIGO, r.rpa_nombre AS RESULTADO_NOMBRE,
        LTRIM(RTRIM(ISNULL(u.usu_nombre,'') + ' ' + ISNULL(u.usu_apellido_paterno,''))) AS EJECUTOR_NOMBRE
FROM    [dbo].[Orden_Trabajo_Paso] p
JOIN    [dbo].[Orden_Trabajo] o ON o.otr_id = p.otp_orden_trabajo AND o.otr_cliente = @CLIENTE
LEFT JOIN [dbo].[Resultado_Paso] r ON r.rpa_id = p.otp_resultado_paso
LEFT JOIN [dbo].[Usuario] u ON u.usu_id = p.otp_usuario_ejecutor
WHERE   p.otp_orden_trabajo = @ORDEN AND p.otp_habilitado = 1
ORDER BY p.otp_orden, p.otp_id
GO

-- ---------------------------------------------------------------------------
-- 8) Permisos y menus
-- ---------------------------------------------------------------------------
DECLARE @HOY DATETIME = GETDATE()

-- Los permisos de OT valian solo para la app (ambito 2); ahora la web tambien crea y ve
UPDATE [dbo].[Permiso] SET prm_permiso_ambito = 3 WHERE prm_codigo IN ('VER ORDENES TRABAJO', 'CREAR ORDEN TRABAJO') AND prm_permiso_ambito = 2

DECLARE @VER_OT INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER ORDENES TRABAJO')
DECLARE @CREAR_OT INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR ORDEN TRABAJO')
DECLARE @CERRAR_OT INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CERRAR OT')

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'REGISTRAR FALLA')
    INSERT INTO [dbo].[Permiso] (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion, prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    SELECT 'REGISTRAR FALLA', 'Registrar fallas y diagnósticos', p.prm_modulo, 3, 'Registrar una falla, sus diagnósticos, acciones y la indisponibilidad del equipo',
           p.prm_usuario_creacion, @HOY, 1, p.prm_asignable_usuario FROM [dbo].[Permiso] p WHERE p.prm_id = @CREAR_OT

DECLARE @FALLA INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'REGISTRAR FALLA')

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT pp.ppe_perfil, @FALLA, pp.ppe_usuario_creacion, @HOY FROM [dbo].[Perfil_Permiso] pp WHERE pp.ppe_permiso = @CREAR_OT
  AND NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x WHERE x.ppe_perfil = pp.ppe_perfil AND x.ppe_permiso = @FALLA)

DECLARE @PADRE INT = (SELECT mnu_padre FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Planes/PlanMantenimientos.aspx')
DECLARE @ORDEN INT = ISNULL((SELECT MAX(mnu_orden) FROM [dbo].[Menus] WHERE mnu_padre = @PADRE AND mnu_orden < 99), 0)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Ordenes/OrdenTrabajos.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Órdenes de trabajo', 'Crear, asignar, seguir y cerrar el trabajo; bandeja de cierre', 3, @PADRE, @ORDEN + 1,
            '~/View/Mantenimiento/Ordenes/OrdenTrabajos.aspx', 1, 'mdi mdi-clipboard-text-outline', @VER_OT, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Orden de trabajo (detalle)', 'Ficha, asignación, pasos, indisponibilidad y cierre', 3, @PADRE, 99,
            '~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx', 0, '', @VER_OT, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Ordenes/OrdenTrabajoAsignacion.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Asignación de orden (detalle)', 'Quién ejecuta la orden', 3, @PADRE, 99,
            '~/View/Mantenimiento/Ordenes/OrdenTrabajoAsignacion.aspx', 0, '', @VER_OT, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Fallas/Fallas.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Fallas', 'Qué se rompió, por qué y cómo se reparó', 3, @PADRE, @ORDEN + 2,
            '~/View/Mantenimiento/Fallas/Fallas.aspx', 1, 'mdi mdi-flash-alert-outline', @VER_OT, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Fallas/Falla.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Falla (detalle)', 'Ficha, diagnósticos, acciones e indisponibilidad', 3, @PADRE, 99,
            '~/View/Mantenimiento/Fallas/Falla.aspx', 0, '', @VER_OT, 1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Fallas/ActivoIndisponibilidad.aspx')
    INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Indisponibilidad (detalle)', 'Un periodo en que el equipo no estuvo disponible', 3, @PADRE, 99,
            '~/View/Mantenimiento/Fallas/ActivoIndisponibilidad.aspx', 0, '', @VER_OT, 1)

DECLARE @M INT
SET @M = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Ordenes/OrdenTrabajos.aspx')
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @M AND mfu_nombre = 'Crear y editar') INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Crear y editar', @M, @CREAR_OT)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @M AND mfu_nombre = 'Cerrar') INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Cerrar', @M, @CERRAR_OT)
SET @M = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx')
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @M AND mfu_nombre = 'Crear y editar') INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Crear y editar', @M, @CREAR_OT)
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @M AND mfu_nombre = 'Cerrar') INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Cerrar', @M, @CERRAR_OT)
SET @M = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Fallas/Fallas.aspx')
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @M AND mfu_nombre = 'Crear y editar') INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Crear y editar', @M, @FALLA)
SET @M = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_link = '~/View/Mantenimiento/Fallas/Falla.aspx')
IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] WHERE mfu_menu = @M AND mfu_nombre = 'Crear y editar') INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso) VALUES ('Crear y editar', @M, @FALLA)
GO

SELECT 'SP = ' + CAST((SELECT COUNT(*) FROM sys.procedures WHERE name IN
    ('SEL_ORDEN_TRABAJO','INS_ORDEN_TRABAJO','UPD_ORDEN_TRABAJO','SEL_ORDEN_TRABAJO_ASIGNACION','INS_ORDEN_TRABAJO_ASIGNACION','DEL_ORDEN_TRABAJO_ASIGNACION',
     'UPD_ORDEN_TRABAJO_CERRAR_WEB','SEL_FALLA','INS_FALLA','UPD_FALLA','SEL_FALLA_DIAGNOSTICO','INS_FALLA_DIAGNOSTICO','SEL_FALLA_ACCION','INS_FALLA_ACCION',
     'SEL_ACTIVO_INDISPONIBILIDAD','INS_ACTIVO_INDISPONIBILIDAD','UPD_ACTIVO_INDISPONIBILIDAD','SEL_ORDEN_TRABAJO_PASO')) AS VARCHAR) + ' de 18' AS RESULTADO
UNION ALL SELECT 'Menus = ' + CAST((SELECT COUNT(*) FROM [dbo].[Menus] WHERE mnu_link LIKE '%/Mantenimiento/Ordenes/%' OR mnu_link LIKE '%/Mantenimiento/Fallas/%') AS VARCHAR) + ' de 6'
GO
