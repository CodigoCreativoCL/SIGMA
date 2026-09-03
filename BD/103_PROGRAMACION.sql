/* ============================================================================
   SIGMA — Bloque 103
   PROGRAMACIONES: DEFINICION          HU-070 · HU-071 · HU-072 · HU-073 · HU-075
   ----------------------------------------------------------------------------

   QUE ES UNA PROGRAMACION

     La regla que dice CUANDO toca hacer un trabajo. "El primer lunes de cada
     mes", "cada 500 horas de horometro", "cada 90 dias desde la ultima
     ejecucion". Se define una vez y despues el motor de generacion la usa
     para crear las ocurrencias.

   LO QUE EL MODELO YA DECIDIO Y ESTE BLOQUE RESPETA

     1. UNA ENTIDAD CON CINCO VARIANTES, NO CINCO ENTIDADES

        `Programacion` es la cabecera y `pro_programacion_tipo` dice de que
        tipo es. Cada tipo tiene su tabla de detalle:

          FECHA UNICA       -> Programacion_Fecha        (1..N fechas)
          CALENDARIO        -> Programacion_Calendario   (1..1) + _Dia (1..N)
          INTERVALO TIEMPO  -> Programacion_Intervalo    (1..1)
          MEDIDOR           -> Programacion_Medidor      (1..1)
          CONDICION         -> Programacion_Condicion    (1..N)

        Por eso hay UN CRUD de cabecera y no cinco. Las tareas del backlog
        proponian INS_PROGRAMACION_CALENDARIO, INS_PROGRAMACION_MEDIDOR, etc.
        como entidades separadas: eso duplica las validaciones comunes
        -vigencia, tolerancias, nombre unico- en cinco lugares y garantiza
        que se desincronicen.

     2. TODO EN UTC, LA HORA LOCAL APARTE

        pxc_fecha_*_utc y pin_fecha_ancla_utc son UTC. pca_hora_local es TIME
        y se combina con pro_zona_horaria al proyectar. Guardar la hora local
        ya convertida rompe en cada cambio de horario de verano.

     3. LAS TOLERANCIAS VIVEN EN LA CABECERA

        pro_tolerancia_antes_minuto / _despues_minuto aplican a la
        programacion completa, no a cada ocurrencia. Es el HU-075 #1.

   LO QUE ESTE BLOQUE **NO** HACE

     No genera ocurrencias. Plan_Mantenimiento_Ocurrencia.pmo_plan_mante-
     nimiento_hito es NOT NULL contra Plan_Mantenimiento_Hito, que es HU-081
     del Sprint 4 y hoy esta vacia. La proyeccion de fechas -que es el
     algoritmo, y lo dificil- va en el bloque 104 y no necesita ocurrencias.

   PENDIENTE DE DECISION (no se toca aca)

     Programacion_Medidor.pme_activo_medidor es NOT NULL, o sea que la regla
     "cada 500 horas" esta obligada a nombrar UN horometro concreto. HU-073 #3
     pide que un plan sobre cuatro blowers dispare con el horometro de cada
     uno sin crear cuatro programaciones, y eso sale de
     Plan_Mantenimiento_Activo.pac_activo_medidor. Deberia ser nullable
     -NULL = "el medidor que traiga cada activo del plan"- pero es un cambio
     de modelo que decide el equipo, no este bloque.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. SEL_PROGRAMACION                                       HU-070 a HU-075

      Un solo SP para la grilla y para la ficha, como en todo el sistema.
      Devuelve la cabecera mas una descripcion legible del detalle, para que
      el listado pueda mostrar "Semanal cada 1" sin abrir la ficha ni hacer
      cinco consultas desde el C#.

      @FILTRO va PARAMETRIZADO, nunca concatenado (bloque 49).
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PROGRAMACION') IS NOT NULL DROP PROCEDURE [dbo].[SEL_PROGRAMACION]
GO

CREATE PROCEDURE [dbo].[SEL_PROGRAMACION]
    @CLIENTE        INT,
    @ID             INT = NULL,
    @TIPO           INT = NULL,
    @FILTRO         VARCHAR(200) = NULL,
    @HABILITADO     BIT = NULL,
    @VIGENTE        BIT = NULL
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @HOY DATE

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @HOY = CAST([dbo].[FNC_PAIS_HORA](@PAIS) AS DATE)

    SELECT  p.pro_id,
            p.pro_cliente,
            p.pro_programacion_tipo,
            t.pti_codigo                        AS TIPO_CODIGO,
            t.pti_nombre                        AS TIPO_NOMBRE,
            p.pro_zona_horaria,
            ISNULL(z.zho_nombre, '')            AS ZONA_HORARIA_NOMBRE,
            p.pro_nombre,
            p.pro_fecha_inicio,
            p.pro_fecha_fin,
            p.pro_tolerancia_antes_minuto,
            p.pro_tolerancia_despues_minuto,
            p.pro_permite_anticipada,
            p.pro_permite_atrasada,
            p.pro_cumplimiento_politica,
            ISNULL(c.cpo_nombre, '')            AS CUMPLIMIENTO_POLITICA_NOMBRE,
            p.pro_genera_automaticamente,

            /* ---- Alcance: donde se hace ----
               Los tres niveles viajan juntos con su nombre resuelto, para que
               la ficha no tenga que consultar tres catalogos solo para
               escribir un encabezado. */
            p.pro_cliente_instalacion,
            ISNULL(ins.cin_nombre, '')          AS INSTALACION_NOMBRE,
            p.pro_instalacion_area,
            ISNULL(ar.iar_nombre, '')           AS AREA_NOMBRE,
            p.pro_activo,
            ISNULL(ac.act_codigo, '')           AS ACTIVO_CODIGO,
            ISNULL(ac.act_nombre, '')           AS ACTIVO_NOMBRE,

            /* ---- Asignacion: quien responde ---- */
            /* Los responsables ya no son UNA columna: una programacion puede
               tener varias personas sin que haya que inventarles una cuadrilla.
               Se entregan armados —nombres para mostrar, ids para volver a
               marcar en la ficha— y no con una segunda consulta por fila. */
            RESPONSABLES = ISNULL(STUFF((
                SELECT N', ' + u2.usu_nombre + N' ' + u2.usu_apellido_paterno
                FROM   [dbo].[Programacion_Responsable] r2
                JOIN   [dbo].[Usuario] u2 ON u2.usu_id = r2.prr_usuario
                WHERE  r2.prr_programacion = p.pro_id
                ORDER BY u2.usu_nombre, u2.usu_apellido_paterno
                FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N''), N''),

            /* MISMO ORDEN que RESPONSABLES, y por eso el JOIN: el listado
               empareja nombre e id por posicion para pintar cada avatar de su
               color. Sin este ORDER BY, el tercer nombre podia salir con el
               color del primero. */
            RESPONSABLES_IDS = ISNULL(STUFF((
                SELECT N',' + CAST(r3.prr_usuario AS NVARCHAR(10))
                FROM   [dbo].[Programacion_Responsable] r3
                JOIN   [dbo].[Usuario] u3 ON u3.usu_id = r3.prr_usuario
                WHERE  r3.prr_programacion = p.pro_id
                ORDER BY u3.usu_nombre, u3.usu_apellido_paterno
                FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, N''), N''),
            p.pro_grupo_trabajo,
            ISNULL(gt.gtr_nombre, '')          AS GRUPO_NOMBRE,

            p.pro_habilitado,
            p.pro_usuario_creacion,
            p.pro_fecha_creacion,
            p.pro_usuario_actualizacion,
            p.pro_fecha_actualizacion,
            ISNULL(uc.usu_nombre + ' ' + uc.usu_apellido_paterno, '') AS USUARIO_CREACION_NOMBRE,
            ISNULL(ua.usu_nombre + ' ' + ua.usu_apellido_paterno, '') AS USUARIO_ACTUALIZACION_NOMBRE,

            /* Vigente = hoy cae dentro de la ventana. Se calcula, no se
               guarda: un estado guardado queda viejo al dia siguiente. */
            CAST(CASE WHEN p.pro_fecha_inicio <= @HOY
                       AND (p.pro_fecha_fin IS NULL OR p.pro_fecha_fin >= @HOY)
                      THEN 1 ELSE 0 END AS BIT)  AS VIGENTE,

            /* La descripcion del detalle segun el tipo. Un CASE aca y no
               cinco consultas desde el C#. */
            CASE t.pti_codigo
                WHEN 'FECHA UNICA' THEN
                    CAST((SELECT COUNT(*) FROM [dbo].[Programacion_Fecha] f
                           WHERE f.pfe_programacion = p.pro_id AND f.pfe_incluida = 1) AS VARCHAR(10))
                    + ' fecha(s)'
                WHEN 'CALENDARIO' THEN
                    ISNULL((SELECT TOP 1 fr.fre_nombre + ' cada ' + CAST(ca.pca_intervalo AS VARCHAR(10))
                            FROM [dbo].[Programacion_Calendario] ca
                            JOIN [dbo].[Frecuencia_Tipo] fr ON fr.fre_id = ca.pca_frecuencia_tipo
                            WHERE ca.pca_programacion = p.pro_id AND ca.pca_habilitado = 1), '')
                WHEN 'INTERVALO TIEMPO' THEN
                    ISNULL((SELECT TOP 1 'Cada ' + CAST(i.pin_cantidad AS VARCHAR(10)) + ' ' + u.uti_nombre
                            FROM [dbo].[Programacion_Intervalo] i
                            JOIN [dbo].[Unidad_Tiempo] u ON u.uti_id = i.pin_unidad_tiempo
                            WHERE i.pin_programacion = p.pro_id AND i.pin_habilitado = 1), '')
                WHEN 'MEDIDOR' THEN
                    ISNULL((SELECT TOP 1 'Cada ' + CAST(CAST(m.pme_cada_cantidad AS DECIMAL(18,2)) AS VARCHAR(20))
                                   + ' (' + am.ame_nombre + ')'
                            FROM [dbo].[Programacion_Medidor] m
                            JOIN [dbo].[Activo_Medidor] am ON am.ame_id = m.pme_activo_medidor
                            WHERE m.pme_programacion = p.pro_id AND m.pme_habilitado = 1), '')
                WHEN 'CONDICION' THEN
                    CAST((SELECT COUNT(*) FROM [dbo].[Programacion_Condicion] cc
                           WHERE cc.pco_programacion = p.pro_id AND cc.pco_habilitado = 1) AS VARCHAR(10))
                    + ' condicion(es)'
                ELSE ''
            END                                 AS DETALLE,

            (SELECT COUNT(*) FROM [dbo].[Programacion_Exclusion] e
              WHERE e.pxc_programacion = p.pro_id AND e.pxc_habilitado = 1) AS EXCLUSIONES,

            /* Cuantas ocurrencias colgaron de esta programacion. Es lo que
               HU-076 #4 exige conservar al deshabilitarla. */
            (SELECT COUNT(*) FROM [dbo].[Plan_Mantenimiento_Ocurrencia] o
              WHERE o.pmo_programacion = p.pro_id)                          AS OCURRENCIAS

    FROM    [dbo].[Programacion] p
    JOIN    [dbo].[Programacion_Tipo] t ON t.pti_id = p.pro_programacion_tipo
    LEFT JOIN [dbo].[Zona_Horaria] z ON z.zho_id = p.pro_zona_horaria
    LEFT JOIN [dbo].[Cliente_Instalacion] ins ON ins.cin_id = p.pro_cliente_instalacion
    LEFT JOIN [dbo].[Instalacion_Area] ar     ON ar.iar_id  = p.pro_instalacion_area
    LEFT JOIN [dbo].[Activo] ac               ON ac.act_id  = p.pro_activo
    LEFT JOIN [dbo].[Grupo_Trabajo] gt        ON gt.gtr_id  = p.pro_grupo_trabajo
    LEFT JOIN [dbo].[Cumplimiento_Politica] c ON c.cpo_id = p.pro_cumplimiento_politica
    LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = p.pro_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = p.pro_usuario_actualizacion
    WHERE   p.pro_cliente = @CLIENTE
      AND   (@ID IS NULL OR p.pro_id = @ID)
      AND   (@TIPO IS NULL OR p.pro_programacion_tipo = @TIPO)
      AND   (@HABILITADO IS NULL OR p.pro_habilitado = @HABILITADO)
      AND   (@VIGENTE IS NULL
             OR (@VIGENTE = 1 AND p.pro_fecha_inicio <= @HOY
                             AND (p.pro_fecha_fin IS NULL OR p.pro_fecha_fin >= @HOY))
             OR (@VIGENTE = 0 AND (p.pro_fecha_inicio > @HOY
                                   OR (p.pro_fecha_fin IS NOT NULL AND p.pro_fecha_fin < @HOY))))
      AND   (@FILTRO IS NULL OR p.pro_nombre LIKE '%' + @FILTRO + '%')
    /* Desempate por id: dos programaciones pueden llamarse parecido y sin
       esto la paginacion repite filas y se salta otras. */
    ORDER BY p.pro_nombre, p.pro_id
GO

PRINT '--- SEL_PROGRAMACION creado.'
GO


/* ========================================================================
   2. INS_PROGRAMACION                                       HU-070 a HU-075

      Solo la cabecera. El detalle lo escribe el SP de su tipo, porque cada
      tabla tiene columnas distintas y un SP con veinte parametros opcionales
      no valida bien ninguno.
   ======================================================================== */
IF OBJECT_ID('dbo.INS_PROGRAMACION') IS NOT NULL DROP PROCEDURE [dbo].[INS_PROGRAMACION]
GO

CREATE PROCEDURE [dbo].[INS_PROGRAMACION]
    @ID                     INT OUTPUT,
    @CLIENTE                INT,
    @TIPO                   INT,
    @NOMBRE                 NVARCHAR(400),
    @FECHA_INICIO           DATE,
    @FECHA_FIN              DATE = NULL,
    @ZONA_HORARIA           INT = NULL,
    @TOLERANCIA_ANTES       INT = 0,
    @TOLERANCIA_DESPUES     INT = 0,
    @PERMITE_ANTICIPADA     BIT = 1,
    @PERMITE_ATRASADA       BIT = 1,
    @CUMPLIMIENTO_POLITICA  INT = NULL,
    @GENERA_AUTOMATICAMENTE BIT = 1,

    /* Alcance y asignacion. Todos opcionales: una programacion puede no
       tener alcance declarado, y en ese caso la pantalla lo dice asi en vez
       de inventarle una instalacion. */
    @INSTALACION            INT = NULL,
    @AREA                   INT = NULL,
    @ACTIVO                 INT = NULL,
    @GRUPO                 INT = NULL,

    @USUARIO                INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME, @TIPO_CODIGO NVARCHAR(100)

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))

IF (@NOMBRE IS NULL OR LEN(@NOMBRE) = 0)
BEGIN
    RAISERROR('1.- INDIQUE EL NOMBRE DE LA PROGRAMACION.', 16, 1)
    RETURN -1
END

SELECT @TIPO_CODIGO = pti_codigo FROM [dbo].[Programacion_Tipo]
 WHERE pti_id = @TIPO AND pti_habilitado = 1

IF (@TIPO_CODIGO IS NULL)
BEGIN
    RAISERROR('2.- EL TIPO DE PROGRAMACION NO EXISTE O ESTA DESHABILITADO.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Programacion]
            WHERE pro_cliente = @CLIENTE AND pro_nombre = @NOMBRE AND pro_habilitado = 1)
BEGIN
    RAISERROR('3.- YA EXISTE UNA PROGRAMACION LLAMADA "%s".', 16, 1, @NOMBRE)
    RETURN -1
END

IF (@FECHA_INICIO IS NULL)
BEGIN
    RAISERROR('4.- INDIQUE LA FECHA DE INICIO DE VIGENCIA.', 16, 1)
    RETURN -1
END

IF (@FECHA_FIN IS NOT NULL AND @FECHA_FIN < @FECHA_INICIO)
BEGIN
    RAISERROR('5.- LA FECHA DE TERMINO NO PUEDE SER ANTERIOR A LA DE INICIO.', 16, 1)
    RETURN -1
END

/* Una tolerancia negativa invierte la ventana de cumplimiento y hace que
   toda ejecucion quede fuera de plazo sin que nadie entienda por que. */
IF (ISNULL(@TOLERANCIA_ANTES, 0) < 0 OR ISNULL(@TOLERANCIA_DESPUES, 0) < 0)
BEGIN
    RAISERROR('6.- LAS TOLERANCIAS NO PUEDEN SER NEGATIVAS.', 16, 1)
    RETURN -1
END

/* HU-074 #3: con varias condiciones hay que saber si basta una o si tienen
   que cumplirse todas. Sin politica el motor no puede decidir. */
IF (@TIPO_CODIGO = 'CONDICION' AND @CUMPLIMIENTO_POLITICA IS NULL)
BEGIN
    RAISERROR('7.- UNA PROGRAMACION POR CONDICION REQUIERE LA POLITICA DE CUMPLIMIENTO.', 16, 1)
    RETURN -1
END

/* El activo tiene que vivir en la instalacion declarada. Sin esto se puede
   programar el mantenimiento de un motor de Antofagasta diciendo que se hace
   en Rancagua, y la orden saldria con la cuadrilla equivocada. */
IF (@ACTIVO IS NOT NULL AND @INSTALACION IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo]
                     WHERE act_id = @ACTIVO AND act_cliente_instalacion = @INSTALACION))
BEGIN
    RAISERROR('8.- EL ACTIVO NO PERTENECE A LA INSTALACION SELECCIONADA.', 16, 1)
    RETURN -1
END

/* Persona o grupo, no las dos: es la forma mas comun de que al final no
   responda nadie, porque cada parte supone que contestaba la otra. */
/* Las personas responsables NO se asignan aca: son varias y no caben en un
   parametro de la cabecera. Van por UPS_PROGRAMACION_RESPONSABLE, que es el
   que ademas valida que no haya personas y grupo a la vez. */

BEGIN TRANSACTION

    INSERT INTO [dbo].[Programacion]
        (pro_cliente_instalacion, pro_instalacion_area, pro_activo,
         pro_grupo_trabajo,
         pro_cliente, pro_programacion_tipo, pro_zona_horaria, pro_nombre,
         pro_fecha_inicio, pro_fecha_fin,
         pro_tolerancia_antes_minuto, pro_tolerancia_despues_minuto,
         pro_permite_anticipada, pro_permite_atrasada,
         pro_cumplimiento_politica, pro_genera_automaticamente,
         pro_usuario_creacion, pro_fecha_creacion,
         pro_usuario_actualizacion, pro_fecha_actualizacion, pro_habilitado)
    VALUES
        (@INSTALACION, @AREA, @ACTIVO, @GRUPO,
         @CLIENTE, @TIPO, @ZONA_HORARIA, @NOMBRE,
         @FECHA_INICIO, @FECHA_FIN,
         ISNULL(@TOLERANCIA_ANTES, 0), ISNULL(@TOLERANCIA_DESPUES, 0),
         @PERMITE_ANTICIPADA, @PERMITE_ATRASADA,
         @CUMPLIMIENTO_POLITICA, @GENERA_AUTOMATICAMENTE,
         @USUARIO, @AHORA, @USUARIO, @AHORA, 1)

    /* @@ROWCOUNT se lee ACA: cualquier sentencia intermedia lo reescribe
       (es lo que arreglo el bloque 89 en siete procedimientos). */
    DECLARE @FILAS INT = @@ROWCOUNT

    SET @ID = SCOPE_IDENTITY()

    IF @FILAS = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('8.- NO FUE POSIBLE INSERTAR LA PROGRAMACION.', 16, 1)
        RETURN -1
    END

    /* El horizonte de generacion nace con la programacion: sin fila en
       Programacion_Generacion el motor de HU-076 no tiene marca de agua
       donde apoyarse y regenera todo en cada pasada. */
    INSERT INTO [dbo].[Programacion_Generacion]
        (pge_programacion, pge_horizonte_dia, pge_ocurrencias_generadas,
         pge_usuario_creacion, pge_fecha_creacion)
    VALUES (@ID, 90, 0, @USUARIO, @AHORA)

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Programación creada con éxito.' AS MENSAJE
GO

PRINT '--- INS_PROGRAMACION creado.'
GO


/* ========================================================================
   3. UPD_PROGRAMACION                                       HU-070 a HU-075

      Los campos que la ficha no manda se conservan con ISNULL(@X, columna):
      guardar desde una pestana no puede borrar lo que edito otra.
   ======================================================================== */
IF OBJECT_ID('dbo.UPD_PROGRAMACION') IS NOT NULL DROP PROCEDURE [dbo].[UPD_PROGRAMACION]
GO

CREATE PROCEDURE [dbo].[UPD_PROGRAMACION]
    @ID                     INT,
    @CLIENTE                INT,
    @NOMBRE                 NVARCHAR(400) = NULL,
    @FECHA_INICIO           DATE = NULL,
    @FECHA_FIN              DATE = NULL,
    @LIMPIA_FECHA_FIN       BIT = 0,
    @ZONA_HORARIA           INT = NULL,
    @TOLERANCIA_ANTES       INT = NULL,
    @TOLERANCIA_DESPUES     INT = NULL,
    @PERMITE_ANTICIPADA     BIT = NULL,
    @PERMITE_ATRASADA       BIT = NULL,
    @CUMPLIMIENTO_POLITICA  INT = NULL,
    @GENERA_AUTOMATICAMENTE BIT = NULL,
    @HABILITADO             BIT = NULL,

    /* Alcance y asignacion.

       Aca NULL no puede significar "no cambiar", porque NULL es tambien un
       valor legitimo: quitarle el alcance a una programacion es una edicion
       real. Por eso van con su propio interruptor: cuando viene en 1, los
       cinco parametros mandan tal cual, NULL incluido. */
    @APLICA_ALCANCE         BIT = 0,
    @INSTALACION            INT = NULL,
    @AREA                   INT = NULL,
    @ACTIVO                 INT = NULL,

    @APLICA_ASIGNACION      BIT = 0,
    @GRUPO                 INT = NULL,

    @USUARIO                INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME, @TIPO_CODIGO NVARCHAR(100)
DECLARE @INICIO DATE, @FIN DATE, @POLITICA INT

/* El cliente va en el WHERE, no solo de parametro: sin eso un id adivinado
   deja editar la programacion de otra empresa. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @ID AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

SELECT @TIPO_CODIGO = t.pti_codigo,
       @INICIO   = ISNULL(@FECHA_INICIO, p.pro_fecha_inicio),
       @FIN      = CASE WHEN @LIMPIA_FECHA_FIN = 1 THEN NULL
                        ELSE ISNULL(@FECHA_FIN, p.pro_fecha_fin) END,
       @POLITICA = ISNULL(@CUMPLIMIENTO_POLITICA, p.pro_cumplimiento_politica)
  FROM [dbo].[Programacion] p
  JOIN [dbo].[Programacion_Tipo] t ON t.pti_id = p.pro_programacion_tipo
 WHERE p.pro_id = @ID

SET @NOMBRE = LTRIM(RTRIM(@NOMBRE))

IF (@NOMBRE IS NOT NULL AND LEN(@NOMBRE) = 0)
BEGIN
    RAISERROR('2.- EL NOMBRE DE LA PROGRAMACION NO PUEDE QUEDAR VACIO.', 16, 1)
    RETURN -1
END

IF (@NOMBRE IS NOT NULL
    AND EXISTS (SELECT 1 FROM [dbo].[Programacion]
                 WHERE pro_cliente = @CLIENTE AND pro_nombre = @NOMBRE
                   AND pro_habilitado = 1 AND pro_id <> @ID))
BEGIN
    RAISERROR('3.- YA EXISTE OTRA PROGRAMACION LLAMADA "%s".', 16, 1, @NOMBRE)
    RETURN -1
END

IF (@FIN IS NOT NULL AND @FIN < @INICIO)
BEGIN
    RAISERROR('4.- LA FECHA DE TERMINO NO PUEDE SER ANTERIOR A LA DE INICIO.', 16, 1)
    RETURN -1
END

IF (ISNULL(@TOLERANCIA_ANTES, 0) < 0 OR ISNULL(@TOLERANCIA_DESPUES, 0) < 0)
BEGIN
    RAISERROR('5.- LAS TOLERANCIAS NO PUEDEN SER NEGATIVAS.', 16, 1)
    RETURN -1
END

IF (@TIPO_CODIGO = 'CONDICION' AND @POLITICA IS NULL)
BEGIN
    RAISERROR('6.- UNA PROGRAMACION POR CONDICION REQUIERE LA POLITICA DE CUMPLIMIENTO.', 16, 1)
    RETURN -1
END

/* Las mismas dos reglas del INS: editar no puede ser una puerta trasera
   para dejar la fila en un estado que el alta rechaza. */
IF (@APLICA_ALCANCE = 1 AND @ACTIVO IS NOT NULL AND @INSTALACION IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo]
                     WHERE act_id = @ACTIVO AND act_cliente_instalacion = @INSTALACION))
BEGIN
    RAISERROR('8.- EL ACTIVO NO PERTENECE A LA INSTALACION SELECCIONADA.', 16, 1)
    RETURN -1
END

/* Poner un grupo con personas ya asignadas es la misma contradiccion que
   antes atajaba el CHECK. Como ahora las personas viven en otra tabla, la
   regla se comprueba aca. */
IF (@APLICA_ASIGNACION = 1 AND @GRUPO IS NOT NULL
    AND EXISTS (SELECT 1 FROM [dbo].[Programacion_Responsable]
                 WHERE prr_programacion = @ID))
BEGIN
    RAISERROR('9.- LA PROGRAMACION YA TIENE PERSONAS ASIGNADAS: QUITELAS ANTES DE ASIGNAR UN GRUPO.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE [dbo].[Programacion]
       SET pro_nombre                     = ISNULL(@NOMBRE, pro_nombre),
           pro_fecha_inicio               = @INICIO,
           pro_fecha_fin                  = @FIN,
           pro_zona_horaria               = ISNULL(@ZONA_HORARIA, pro_zona_horaria),
           pro_tolerancia_antes_minuto    = ISNULL(@TOLERANCIA_ANTES, pro_tolerancia_antes_minuto),
           pro_tolerancia_despues_minuto  = ISNULL(@TOLERANCIA_DESPUES, pro_tolerancia_despues_minuto),
           pro_permite_anticipada         = ISNULL(@PERMITE_ANTICIPADA, pro_permite_anticipada),
           pro_permite_atrasada           = ISNULL(@PERMITE_ATRASADA, pro_permite_atrasada),
           pro_cumplimiento_politica      = @POLITICA,
           pro_genera_automaticamente     = ISNULL(@GENERA_AUTOMATICAMENTE, pro_genera_automaticamente),
           pro_habilitado                 = ISNULL(@HABILITADO, pro_habilitado),

           /* Con el interruptor en 0 la columna no se toca; en 1 manda lo
              que vino, NULL incluido, porque quitar el alcance es una
              edicion tan valida como ponerlo. */
           pro_cliente_instalacion        = CASE WHEN @APLICA_ALCANCE = 1
                                                 THEN @INSTALACION ELSE pro_cliente_instalacion END,
           pro_instalacion_area           = CASE WHEN @APLICA_ALCANCE = 1
                                                 THEN @AREA ELSE pro_instalacion_area END,
           pro_activo                     = CASE WHEN @APLICA_ALCANCE = 1
                                                 THEN @ACTIVO ELSE pro_activo END,
           pro_grupo_trabajo         = CASE WHEN @APLICA_ASIGNACION = 1
                                                 THEN @GRUPO ELSE pro_grupo_trabajo END,

           pro_usuario_actualizacion      = @USUARIO,
           pro_fecha_actualizacion        = @AHORA
     WHERE pro_id = @ID AND pro_cliente = @CLIENTE

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('7.- NO FUE POSIBLE ACTUALIZAR LA PROGRAMACION.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Programación actualizada con éxito.' AS MENSAJE
GO

PRINT '--- UPD_PROGRAMACION creado.'
GO


/* ========================================================================
   4. DEL_PROGRAMACION                                              HU-076 #4

      Baja LOGICA. El criterio dice literalmente: "deshabilito una
      programacion, deja de generar ocurrencias nuevas Y las ya generadas se
      conservan". Un DELETE fisico se llevaria por delante el historial del
      trabajo ya hecho.
   ======================================================================== */
IF OBJECT_ID('dbo.DEL_PROGRAMACION') IS NOT NULL DROP PROCEDURE [dbo].[DEL_PROGRAMACION]
GO

CREATE PROCEDURE [dbo].[DEL_PROGRAMACION]
    @ID         INT,
    @CLIENTE    INT,
    @USUARIO    INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PAIS INT, @AHORA DATETIME, @HITOS INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @ID AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

/* Un hito de un plan publicado que apunte aca se queda sin regla de fecha
   si la programacion se apaga. Se avisa en vez de dejar el plan roto. */
SELECT @HITOS = COUNT(*)
  FROM [dbo].[Plan_Mantenimiento_Hito] h
 WHERE h.pmh_programacion = @ID AND h.pmh_habilitado = 1

IF (@HITOS > 0)
BEGIN
    RAISERROR('2.- NO SE PUEDE ELIMINAR: %d HITO(S) DE PLANES LA ESTAN USANDO.', 16, 1, @HITOS)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE [dbo].[Programacion]
       SET pro_habilitado             = 0,
           pro_genera_automaticamente = 0,
           pro_usuario_actualizacion  = @USUARIO,
           pro_fecha_actualizacion    = @AHORA
     WHERE pro_id = @ID AND pro_cliente = @CLIENTE

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('3.- NO FUE POSIBLE ELIMINAR LA PROGRAMACION.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Programación eliminada con éxito.' AS MENSAJE
GO

PRINT '--- DEL_PROGRAMACION creado.'
GO
