USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  25-09-2026
-- DESCRIPTION:     DATOS DE PRUEBA PARA ACTIVIDADES DE HITO (T-4055).
-- =============================================
-- ESTO NO ES UNA MIGRACION
--
--   Filas de ejemplo para ejercitar HU-082. Corre despues de
--   _SEMILLA_PLAN_HITOS.sql, porque una actividad sin hito no existe.
--
-- POR QUE INSERT DIRECTO Y NO INS_PLAN_ACTIVIDAD
--
--   El SP solo escribe sobre una version en BORRADOR, y con razon: una
--   version publicada ya genero ordenes con estos pasos copiados dentro.
--   Pero en la base hay UN solo hito en borrador y tres en la version
--   publicada de PMA-HORNOS-L1, que es justamente el plan que se consulta
--   para ver como queda la pantalla llena.
--
--   Esas actividades son datos que el plan publicado SI tuvo cuando era
--   borrador -por eso se publico-, asi que la semilla las escribe como
--   estaban. Saltarse el SP aca no debilita la regla: la regla sigue
--   protegiendo a la pantalla, que es quien la puede romper. Una semilla es
--   el estado inicial de la base, no una operacion de usuario.
--
-- LOS CASOS
--
--   1. Hito en BORRADOR (PMA-2 / REC-SEG): tres actividades editables. Es
--      donde se prueba crear, editar y eliminar.
--   2. Hito PUBLICADO con lubricacion (PMA-HORNOS-L1 v3 / LUB-MENSUAL):
--      cuatro actividades, una con procedimiento enganchado. Aca la
--      pantalla tiene que mostrarse en solo lectura.
--   3. Hito PUBLICADO de overhaul (OVH-QUEMADOR): cinco actividades, con
--      parada y con dos permisos de trabajo distintos -trabajo caliente y
--      bloqueo de energia-. Es el caso que llena la columna EXIGE.
--   4. Hito PUBLICADO por condicion (COND-TEMP): dos actividades, una NO
--      obligatoria, para que «obligatoria» tenga un contraste.
--
--   Las duraciones suman aproximadamente la del hito: un hito de 90 minutos
--   con actividades que suman 400 seria una planificacion que no cierra, y
--   quien mire la semilla la va a copiar.
-- TODO IDEMPOTENTE: se reconoce por hito + codigo.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1
DECLARE @USUARIO INT = (SELECT TOP 1 usu_id FROM [dbo].[Usuario] WHERE usu_login = 'rodrigo.quezada@hamburgo.cl')
DECLARE @NOW     DATETIME = [dbo].[FNC_PAIS_HORA]((SELECT cli_pais FROM [dbo].[Cliente] WHERE cli_id = 1))

/* Los hitos se buscan por su codigo y por el numero de version, no por id:
   los ids de la semilla anterior no son los mismos en cada base. */
DECLARE @H_BORRADOR INT, @H_LUB INT, @H_OVH INT, @H_COND INT
DECLARE @PRC_ACEITE INT, @PRC_MOTOR INT

SELECT @H_BORRADOR = pmh.pmh_id
  FROM [dbo].[Plan_Mantenimiento_Hito] pmh
  JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
  JOIN [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
 WHERE pma.pma_cliente = @CLIENTE AND pmh.pmh_codigo = 'REC-SEG'
   AND pmv.pmv_plan_version_estado = 1   -- BORRADOR

SELECT @H_LUB = pmh.pmh_id
  FROM [dbo].[Plan_Mantenimiento_Hito] pmh
  JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
  JOIN [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
  JOIN [dbo].[Plan_Version_Estado] pve ON pve.pve_id = pmv.pmv_plan_version_estado
 WHERE pma.pma_cliente = @CLIENTE AND pma.pma_codigo = 'PMA-HORNOS-L1'
   AND pve.pve_codigo = 'PUBLICADO' AND pmh.pmh_codigo = 'LUB-MENSUAL'

SELECT @H_OVH = pmh.pmh_id
  FROM [dbo].[Plan_Mantenimiento_Hito] pmh
  JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
  JOIN [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
  JOIN [dbo].[Plan_Version_Estado] pve ON pve.pve_id = pmv.pmv_plan_version_estado
 WHERE pma.pma_cliente = @CLIENTE AND pma.pma_codigo = 'PMA-HORNOS-L1'
   AND pve.pve_codigo = 'PUBLICADO' AND pmh.pmh_codigo = 'OVH-QUEMADOR'

SELECT @H_COND = pmh.pmh_id
  FROM [dbo].[Plan_Mantenimiento_Hito] pmh
  JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
  JOIN [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
  JOIN [dbo].[Plan_Version_Estado] pve ON pve.pve_id = pmv.pmv_plan_version_estado
 WHERE pma.pma_cliente = @CLIENTE AND pma.pma_codigo = 'PMA-HORNOS-L1'
   AND pve.pve_codigo = 'PUBLICADO' AND pmh.pmh_codigo = 'COND-TEMP'

SELECT @PRC_ACEITE = prc_id FROM [dbo].[Procedimiento] WHERE prc_cliente = @CLIENTE AND prc_codigo = 'PRC-ACEITE-BLW'
SELECT @PRC_MOTOR  = prc_id FROM [dbo].[Procedimiento] WHERE prc_cliente = @CLIENTE AND prc_codigo = 'CAMBIO-MOTORREDUCTOR'

IF (@USUARIO IS NULL OR @H_LUB IS NULL OR @H_OVH IS NULL)
BEGIN
    RAISERROR('1.- CORRA _SEMILLA_PLAN_HITOS.sql ANTES.', 16, 1)
    RETURN
END

/* Una tabla de trabajo en vez de cuatro bloques repetidos: las filas se leen
   como una lista de actividades y no como cien lineas de INSERT. */
DECLARE @D TABLE (
    hito        INT,
    codigo      NVARCHAR(100),
    nombre      NVARCHAR(400),
    descripcion NVARCHAR(1000),
    orden       INT,
    procedim    INT,
    duracion    INT,
    obligatoria BIT,
    parada      BIT,
    permiso     BIT,
    permiso_tipo INT
)

-- 1) HITO EN BORRADOR: recorrido de seguridad, 45 min ---------------------
IF @H_BORRADOR IS NOT NULL
INSERT INTO @D VALUES
 (@H_BORRADOR, 'ACT-010', N'Revisar guardas y protecciones de las transmisiones',
  N'Que estén puestas, completas y sin deformaciones. Si falta una, el recorrido se detiene y se levanta la falla.',
  1, NULL, 15, 1, 0, 0, NULL),
 (@H_BORRADOR, 'ACT-020', N'Probar las paradas de emergencia de la línea',
  N'Una por una, verificando que el equipo se detiene y que el rearme es manual.',
  2, NULL, 20, 1, 0, 0, NULL),
 (@H_BORRADOR, 'ACT-030', N'Registrar fugas, derrames y obstrucciones de pasillo',
  N'Lo que se vea. No corrige, solo registra: corregir es una orden aparte.',
  3, NULL, 10, 0, 0, 0, NULL)

-- 2) LUBRICACIÓN MENSUAL, 90 min -----------------------------------------
INSERT INTO @D VALUES
 (@H_LUB, 'ACT-010', N'Limpiar los puntos de engrase antes de aplicar',
  N'Grasa nueva sobre suciedad vieja arrastra la suciedad adentro del rodamiento.',
  1, NULL, 15, 1, 0, 0, NULL),
 (@H_LUB, 'ACT-020', N'Engrasar rodamientos de la cadena transportadora',
  N'Según la tabla de lubricación del horno: cantidad y tipo por punto.',
  2, NULL, 30, 1, 0, 0, NULL),
 (@H_LUB, 'ACT-030', N'Cambiar el aceite del blower',
  N'Con el procedimiento enganchado: sus pasos se copian dentro de la orden.',
  3, @PRC_ACEITE, 35, 1, 0, 0, NULL),
 (@H_LUB, 'ACT-040', N'Anotar el nivel y el estado del aceite retirado',
  N'Color, olor y presencia de partículas. Es lo que anticipa el desgaste.',
  4, NULL, 10, 0, 0, 0, NULL)

-- 3) OVERHAUL DEL QUEMADOR, 480 min, con parada y permisos ---------------
INSERT INTO @D VALUES
 (@H_OVH, 'ACT-010', N'Bloquear y rotular las energías del quemador',
  N'Eléctrica y de gas. Nada de lo que sigue empieza sin el bloqueo puesto y verificado.',
  1, NULL, 45, 1, 1, 1, 6),
 (@H_OVH, 'ACT-020', N'Desmontar el conjunto quemador-ventilador',
  N'Marcando la posición de las conexiones antes de soltarlas.',
  2, NULL, 90, 1, 1, 0, NULL),
 (@H_OVH, 'ACT-030', N'Reemplazar el motorreductor del ventilador',
  N'Solo si el diagnóstico lo indica; si no, se limpia y se mide vibración.',
  3, @PRC_MOTOR, 120, 0, 1, 0, NULL),
 (@H_OVH, 'ACT-040', N'Reparar la refractaria de la cámara',
  N'Requiere permiso de trabajo caliente: hay corte y soldadura.',
  4, NULL, 150, 1, 1, 1, 3),
 (@H_OVH, 'ACT-050', N'Montar, calibrar y hacer la prueba de llama',
  N'Con el retiro del bloqueo documentado y el equipo en marcha supervisada.',
  5, NULL, 75, 1, 1, 0, NULL)

-- 4) INTERVENCIÓN POR SOBRETEMPERATURA, 120 min --------------------------
IF @H_COND IS NOT NULL
INSERT INTO @D VALUES
 (@H_COND, 'ACT-010', N'Verificar el sensor que disparó la condición',
  N'Antes de intervenir el equipo: la mitad de las sobretemperaturas son el sensor.',
  1, NULL, 30, 1, 0, 0, NULL),
 (@H_COND, 'ACT-020', N'Revisar ventilación, filtros y flujo de aire',
  N'Lo que sube la temperatura sin que falle nada mecánico.',
  2, NULL, 60, 1, 1, 0, NULL),
 (@H_COND, 'ACT-030', N'Termografía del gabinete de potencia',
  N'Opcional: solo si la temperatura no se explica por la ventilación.',
  3, NULL, 30, 0, 0, 1, 4)

/* El INSERT se hace de lo que NO exista: la semilla se puede correr dos
   veces sin duplicar y sin pisar lo que alguien haya editado a mano. */
INSERT INTO [dbo].[Plan_Mantenimiento_Actividad]
      (paa_plan_mantenimiento_hito, paa_procedimiento, paa_codigo, paa_nombre, paa_descripcion,
       paa_orden, paa_duracion_estimada_minuto, paa_obligatoria, paa_requiere_parada,
       paa_requiere_permiso, paa_permiso_trabajo_tipo,
       paa_usuario_creacion, paa_fecha_creacion, paa_habilitado)
SELECT d.hito, d.procedim, d.codigo, d.nombre, d.descripcion,
       d.orden, d.duracion, d.obligatoria, d.parada,
       d.permiso, d.permiso_tipo,
       @USUARIO, @NOW, 1
  FROM @D d
 WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Actividad] a
                    WHERE a.paa_plan_mantenimiento_hito = d.hito AND a.paa_codigo = d.codigo)

PRINT '--- Actividades insertadas: ' + LTRIM(STR(@@ROWCOUNT))
GO

SELECT  pma.pma_codigo AS PLAN_, pmv.pmv_numero AS VER, pve.pve_codigo AS ESTADO,
        pmh.pmh_codigo AS HITO, paa.paa_orden AS N, paa.paa_codigo AS COD, paa.paa_nombre AS ACTIVIDAD,
        paa.paa_duracion_estimada_minuto AS MIN_, paa.paa_obligatoria AS OBL,
        paa.paa_requiere_parada AS PARA, ptt.ptt_codigo AS PERMISO,
        prc.prc_codigo AS PROCEDIMIENTO
  FROM  [dbo].[Plan_Mantenimiento_Actividad] paa
  JOIN  [dbo].[Plan_Mantenimiento_Hito] pmh ON pmh.pmh_id = paa.paa_plan_mantenimiento_hito
  JOIN  [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
  JOIN  [dbo].[Plan_Version_Estado] pve ON pve.pve_id = pmv.pmv_plan_version_estado
  JOIN  [dbo].[Plan_Mantenimiento] pma ON pma.pma_id = pmv.pmv_plan_mantenimiento
  LEFT  JOIN [dbo].[Permiso_Trabajo_Tipo] ptt ON ptt.ptt_id = paa.paa_permiso_trabajo_tipo
  LEFT  JOIN [dbo].[Procedimiento] prc ON prc.prc_id = paa.paa_procedimiento
 ORDER  BY pma.pma_codigo, pmv.pmv_numero, pmh.pmh_orden, paa.paa_orden
GO

PRINT '_SEMILLA_PLAN_ACTIVIDADES aplicada.'
GO
