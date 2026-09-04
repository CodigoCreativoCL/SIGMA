/* ============================================================================
   SIGMA — Bloque 117
   GENERAR LA ORDEN DE TRABAJO DESDE EL ANALISIS PREDICTIVO
   ----------------------------------------------------------------------------

   EL MODELO YA ESPERABA ESTO

     No hay que inventar nada de estructura. `Orden_Trabajo` trae la columna
     `otr_prediccion`, el catalogo de origen trae el valor 5 = PREDICCION, y
     `CK_OTR_ORIGEN_COHERENTE` exige justamente que una OT de ese origen
     apunte a la prediccion que la motivo. La tabla `Alerta` trae ademas
     `ale_orden_trabajo` para el enlace de vuelta.

     Es decir: la decision de diseño ya estaba tomada. Este bloque solo la
     ejecuta.

   CIERRA EL CICLO

     Sin esto el panel predictivo termina en un dato: "este motor falla en 9
     dias". Con esto termina en un encargo con responsable. Esa es la unica
     diferencia entre un tablero que se mira y uno que se usa.

   NO CREA DOS

     Si la alerta ya tiene OT, devuelve ESA y no crea otra. Generar dos
     ordenes para la misma prediccion manda dos cuadrillas al mismo equipo.
     El que aprieta el boton dos veces —o dos personas a la vez— recibe la
     misma OT.

   LO QUE NO DECIDE

     La OT nace ABIERTA y SIN FECHA PROGRAMADA. Se guarda la fecha estimada
     de falla en `otr_fecha_evento_utc` para que quien programe sepa contra
     que plazo corre, pero programar es una decision de planificacion con
     dotacion y repuestos a la vista, y el modelo no tiene ninguna de las
     dos cosas.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.INS_ORDEN_TRABAJO_DESDE_PREDICCION') IS NOT NULL
    DROP PROCEDURE [dbo].[INS_ORDEN_TRABAJO_DESDE_PREDICCION]
GO

CREATE PROCEDURE [dbo].[INS_ORDEN_TRABAJO_DESDE_PREDICCION]
    @ALERTA     INT,
    @CLIENTE    INT,
    @USUARIO    INT,
    @ID         INT = NULL OUTPUT
AS
SET NOCOUNT ON

/* Que no arrastre el valor de una llamada anterior: un SELECT que no
   encuentra filas NO toca la variable, y el OUTPUT quedaria mintiendo. */
SET @ID = NULL

DECLARE @PRED INT, @ACT INT, @INST INT, @AREA INT, @SEV VARCHAR(50),
        @TITULO NVARCHAR(200), @DESC NVARCHAR(MAX), @EVENTO DATETIME,
        @DIAS INT, @PROB DECIMAL(18,6), @OTEXISTE INT

SELECT  @PRED     = a.ale_prediccion,
        @ACT      = ISNULL(a.ale_activo, p.pre_activo),
        /* La instalacion sale de la alerta si la trae, y si no del EQUIPO.

           No es un parche: la orden se ejecuta sobre el activo, y el activo
           es el que sabe donde esta instalado. Una alerta puede nacer de un
           detector que solo conocia el equipo. */
        @INST     = ISNULL(a.ale_cliente_instalacion, ac.act_cliente_instalacion),
        @AREA     = ac.act_instalacion_area,
        @SEV      = ISNULL(s.sev_codigo, ''),
        @TITULO   = a.ale_titulo,
        @DESC     = a.ale_descripcion,
        @EVENTO   = p.pre_fecha_evento_estimada_utc,
        @DIAS     = p.pre_dia_restante,
        @PROB     = p.pre_probabilidad,
        @OTEXISTE = a.ale_orden_trabajo
FROM    [dbo].[Alerta] a
LEFT JOIN [dbo].[Prediccion] p ON p.pre_id = a.ale_prediccion
LEFT JOIN [dbo].[Severidad] s  ON s.sev_id = a.ale_severidad
LEFT JOIN [dbo].[Activo] ac    ON ac.act_id = ISNULL(a.ale_activo, p.pre_activo)
WHERE   a.ale_id = @ALERTA
  AND   a.ale_cliente = @CLIENTE
  AND   a.ale_habilitado = 1

IF (@PRED IS NULL)
BEGIN
    RAISERROR('La alerta no existe o no proviene de un análisis predictivo.', 16, 1)
    RETURN
END

/* Ya tiene OT: se devuelve la que hay. */
IF (@OTEXISTE IS NOT NULL)
BEGIN
    SET @ID = @OTEXISTE
    SELECT  otr_id, otr_correlativo, YA_EXISTIA = CAST(1 AS BIT)
    FROM    [dbo].[Orden_Trabajo] WHERE otr_id = @OTEXISTE
    RETURN
END

IF (@INST IS NULL)
BEGIN
    RAISERROR('Ni la alerta ni el activo tienen instalación asociada: no se puede generar la orden.', 16, 1)
    RETURN
END

/* La prioridad sale de la severidad que ya trae la alerta. No se recalcula
   acá: si dos pantallas deciden la severidad por su cuenta, terminan
   discrepando sobre el mismo equipo. */
DECLARE @PRIORIDAD INT =
    CASE @SEV WHEN 'CRITICA' THEN 4 WHEN 'ALTA' THEN 3 WHEN 'MEDIA' THEN 2 ELSE 1 END

DECLARE @CUERPO NVARCHAR(MAX) =
    ISNULL(@DESC, '') +
    CASE WHEN @PROB IS NULL THEN ''
         ELSE CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) +
              'Generada desde el análisis predictivo de SIGMA AI. Probabilidad de falla: ' +
              CAST(CAST(ROUND(CASE WHEN @PROB <= 1 THEN @PROB * 100 ELSE @PROB END, 0) AS INT) AS VARCHAR(10)) + ' %.' +
              CASE WHEN @DIAS IS NULL THEN ''
                   ELSE ' Vida útil estimada: ' + CAST(@DIAS AS VARCHAR(10)) + ' días.' END
    END

BEGIN TRY
    BEGIN TRANSACTION

        /* El correlativo se toma con el candado puesto: dos personas
           apretando a la vez sacarian el mismo numero. */
        DECLARE @CORR INT
        SELECT  @CORR = ISNULL(MAX(otr_correlativo), 0) + 1
        FROM    [dbo].[Orden_Trabajo] WITH (UPDLOCK, HOLDLOCK)
        WHERE   otr_cliente = @CLIENTE

        INSERT INTO [dbo].[Orden_Trabajo]
            (otr_cliente, otr_cliente_instalacion, otr_instalacion_area,
             otr_correlativo, otr_activo,
             otr_orden_trabajo_tipo,        /* 3 PREDICTIVA */
             otr_orden_trabajo_estrategia,  /* 2 PROGRAMADO */
             otr_orden_trabajo_origen,      /* 5 PREDICCION */
             otr_orden_trabajo_estado,      /* 1 ABIERTA    */
             otr_orden_trabajo_prioridad,
             otr_usuario_generador, otr_titulo, otr_descripcion,
             otr_fecha_evento_utc, otr_prediccion, otr_usuario_creacion)
        VALUES
            (@CLIENTE, @INST, @AREA, @CORR, @ACT,
             3, 2, 5, 1, @PRIORIDAD,
             @USUARIO, @TITULO, @CUERPO,
             @EVENTO, @PRED, @USUARIO)

        SET @ID = SCOPE_IDENTITY()

        /* El enlace de vuelta: desde la alerta se llega a la OT, y por esta
           misma columna es que no se genera una segunda. */
        UPDATE  [dbo].[Alerta]
        SET     ale_orden_trabajo = @ID
        WHERE   ale_id = @ALERTA

        /* Generar la orden ES hacerse cargo. Se reutiliza el SP de estado en
           vez de escribir las fechas a mano: es el que sabe que columnas
           mueve y el que deja el rastro en Alerta_Historial. */
        EXEC [dbo].[UPD_ALERTA_ESTADO]
             @ALERTA      = @ALERTA,
             @CLIENTE     = @CLIENTE,
             @USUARIO     = @USUARIO,
             @ESTADO      = 'EN GESTION',
             @MOTIVO      = N'Se generó la orden de trabajo desde el análisis predictivo.',
             @RESPONSABLE = NULL

    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
    SET @ID = NULL

    DECLARE @M NVARCHAR(2048) = ERROR_MESSAGE()
    RAISERROR(@M, 16, 1)
    RETURN
END CATCH

SELECT otr_id, otr_correlativo, YA_EXISTIA = CAST(0 AS BIT)
FROM   [dbo].[Orden_Trabajo] WHERE otr_id = @ID
GO

PRINT '--- INS_ORDEN_TRABAJO_DESDE_PREDICCION creado.'
GO


/* ========================================================================
   EL PERMISO

     Las dos funciones que ya tenia esta pantalla —"Marcar como leido" y
     "Revisar ahora"— cuelgan del permiso 68, que es VER EXISTENCIAS
     INVENTARIO. Es herencia de cuando la pantalla era la bandeja de avisos
     de stock.

     Generar una orden de trabajo no puede colgar de ahi. Que alguien pueda
     mirar el inventario no dice nada sobre si puede mandar una cuadrilla a
     intervenir un motor.

     Se crea un permiso propio y se concede a EXACTAMENTE los perfiles que
     hoy tienen el 68: nadie gana ni pierde acceso con este bloque, pero a
     partir de ahora las dos cosas se pueden separar sin tocar codigo.
   ======================================================================== */
DECLARE @USU INT = 1
DECLARE @PRM INT, @MENU INT

SELECT @PRM = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'GENERAR OT PREDICCION'

IF (@PRM IS NULL)
BEGIN
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito,
         prm_descripcion, prm_usuario_creacion, prm_asignable_usuario)
    VALUES
        ('GENERAR OT PREDICCION', 'Generar orden de trabajo desde una predicción',
         'MANTENIMIENTO', 3,
         'Permite convertir un análisis predictivo en una orden de trabajo.',
         @USU, 0)

    SET @PRM = SCOPE_IDENTITY()
    PRINT '--- Permiso GENERAR OT PREDICCION creado.'
END
ELSE
    PRINT '--- Permiso GENERAR OT PREDICCION ya existia.'

/* A los mismos perfiles que ya entran a la pantalla. */
INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion)
SELECT DISTINCT pp.ppe_perfil, @PRM, @USU
FROM   [dbo].[Perfil_Permiso] pp
WHERE  pp.ppe_permiso = 68
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x
                    WHERE x.ppe_perfil = pp.ppe_perfil AND x.ppe_permiso = @PRM)

PRINT '--- Perfiles concedidos.'

/* Y la funcion, que es lo que la pantalla consulta por nombre. */
SELECT @MENU = mnu_id FROM [dbo].[Menus]
WHERE  mnu_link LIKE '%Notificaciones.aspx%'

IF (@MENU IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM [dbo].[Menu_Funcion]
        WHERE  mfu_menu = @MENU AND mfu_nombre = 'Generar orden de trabajo'))
BEGIN
    INSERT INTO [dbo].[Menu_Funcion] (mfu_menu, mfu_nombre, mfu_permiso)
    VALUES (@MENU, 'Generar orden de trabajo', @PRM)

    PRINT '--- Funcion "Generar orden de trabajo" registrada.'
END
ELSE
    PRINT '--- La funcion ya existia (o falta el menu).'
GO

PRINT '117_OT_DESDE_PREDICCION aplicado.'
GO
