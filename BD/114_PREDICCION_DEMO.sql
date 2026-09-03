/* ============================================================================
   SIGMA — Bloque 114
   UNA PREDICCION DE DEMO PARA EL PANEL DE SIGMA AI
   ----------------------------------------------------------------------------

   POR QUE HACE FALTA

     El panel de SIGMA AI del Centro de Accion Operacional lee de `Prediccion`
     y de `Prediccion_Explicacion`. Las dos tablas existen, el modelo esta
     completo y la pantalla sabe pintarlo, pero hay CERO filas: no hay todavia
     ningun proceso que entrene ni que puntue.

     Sin una prediccion el panel no se puede ni mirar. No es que este mal
     hecho: es que no tiene nada que mostrar, y esconderlo es justo lo que la
     pantalla hace cuando la alerta no salio del modelo.

   LOS NUMEROS SON LOS DE LA MAQUETA, Y ESO ES DELIBERADO

     87% de probabilidad, 9 dias de vida util, vibracion +31%, temperatura
     +18. Son los valores de la propuesta visual, cargados como DATO para que
     la pantalla los lea del mismo sitio del que leera los del modelo real.

     Cuando exista el proceso que puntua, esta fila se reemplaza y la pantalla
     no cambia ni una linea. Lo que NO se hizo fue escribir esos numeros en el
     marcado: ahi habrian quedado para siempre.

   TODO CON PREFIJO DEMO- E IDEMPOTENTE.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DECLARE @CLI INT = 1, @USU INT = 1
DECLARE @OBJ INT, @FOR INT, @EST_VER INT, @EST_PRE INT, @SEV INT
DECLARE @MODELO INT, @VERSION INT, @ACTIVO INT, @TIPO INT, @ALERTA INT, @PRED INT
DECLARE @AHORA DATETIME = GETUTCDATE()

SELECT TOP 1 @OBJ = mob_id FROM [dbo].[Modelo_Objetivo] ORDER BY mob_id
SELECT TOP 1 @FOR = mfo_id FROM [dbo].[Modelo_Formato] ORDER BY mfo_id
SELECT TOP 1 @EST_VER = pve_id FROM [dbo].[Plan_Version_Estado] ORDER BY pve_id DESC
SELECT TOP 1 @EST_PRE = pde_id FROM [dbo].[Prediccion_Estado] ORDER BY pde_id
SELECT @SEV = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'CRITICA'
SELECT @TIPO = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'PREDICCION RIESGO'

/* El activo con horometro: es el que tiene sentido para una prediccion por
   desgaste. Si no hay ninguno, se toma el primero. */
SELECT TOP 1 @ACTIVO = a.act_id
FROM [dbo].[Activo] a
LEFT JOIN [dbo].[Activo_Medidor] m ON m.ame_activo = a.act_id
WHERE a.act_cliente = @CLI
ORDER BY CASE WHEN m.ame_id IS NULL THEN 1 ELSE 0 END, a.act_id

IF (@ACTIVO IS NULL OR @TIPO IS NULL)
    PRINT '--- FALTAN activos o el tipo PREDICCION RIESGO: no se siembra.'
ELSE IF EXISTS (SELECT 1 FROM [dbo].[Modelo_Predictivo] WHERE mpr_codigo = 'DEMO-FALLA-MOTOR')
    PRINT '--- La prediccion de demo ya existia.'
ELSE
BEGIN
    INSERT INTO [dbo].[Modelo_Predictivo]
        (mpr_cliente, mpr_modelo_objetivo, mpr_codigo, mpr_nombre, mpr_descripcion,
         mpr_horizonte_dia, mpr_usuario_creacion)
    VALUES (@CLI, @OBJ, 'DEMO-FALLA-MOTOR', 'Predicción de falla en motores',
            'Estima la probabilidad de falla a partir de vibración y temperatura.',
            30, @USU)
    SET @MODELO = SCOPE_IDENTITY()

    INSERT INTO [dbo].[Modelo_Predictivo_Version]
        (mpv_modelo_predictivo, mpv_numero, mpv_modelo_formato, mpv_plan_version_estado,
         mpv_algoritmo, mpv_metrica_auc, mpv_fecha_entrenamiento_utc, mpv_usuario_creacion)
    VALUES (@MODELO, 3, @FOR, @EST_VER, 'Gradient boosting', 0.91,
            DATEADD(DAY, -12, @AHORA), @USU)
    SET @VERSION = SCOPE_IDENTITY()

    /* La alerta primero: la prediccion la referencia y viceversa, asi que una
       de las dos tiene que existir antes. */
    INSERT INTO [dbo].[Alerta]
        (ale_cliente, ale_alerta_tipo, ale_alerta_estado, ale_severidad,
         ale_titulo, ale_descripcion, ale_fecha_deteccion_utc, ale_activo,
         ale_fecha_primera_ocurrencia_utc, ale_fecha_ultima_ocurrencia_utc,
         ale_ocurrencias, ale_usuario_creacion, ale_fecha_creacion, ale_habilitado)
    SELECT  @CLI, @TIPO,
            (SELECT aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'NUEVA'),
            @SEV,
            'Riesgo de falla en ' + a.act_nombre,
            'El modelo detectó un patrón anómalo en la vibración y la temperatura del equipo que indica alta probabilidad de falla en los próximos días.',
            DATEADD(MINUTE, -18, @AHORA), @ACTIVO,
            DATEADD(MINUTE, -18, @AHORA), DATEADD(MINUTE, -18, @AHORA),
            1, @USU, GETDATE(), 1
    FROM [dbo].[Activo] a WHERE a.act_id = @ACTIVO

    SET @ALERTA = SCOPE_IDENTITY()

    INSERT INTO [dbo].[Prediccion]
        (pre_cliente, pre_modelo_predictivo_version, pre_prediccion_estado,
         pre_activo, pre_probabilidad, pre_dia_restante, pre_severidad,
         pre_confianza, pre_intervalo_inferior, pre_intervalo_superior,
         pre_fecha_calculo_utc, pre_fecha_evento_estimada_utc,
         pre_alerta, pre_usuario_creacion)
    VALUES (@CLI, @VERSION, @EST_PRE, @ACTIVO,
            0.87, 9, @SEV, 0.82, 0.79, 0.93,
            DATEADD(MINUTE, -17, @AHORA), DATEADD(DAY, 9, @AHORA),
            @ALERTA, @USU)

    SET @PRED = SCOPE_IDENTITY()

    UPDATE [dbo].[Alerta] SET ale_prediccion = @PRED WHERE ale_id = @ALERTA

    /* Los factores: que empujo la prediccion y cuanto. Es lo que la pantalla
       pinta en "Factores principales". */
    INSERT INTO [dbo].[Prediccion_Explicacion]
        (pex_prediccion, pex_orden, pex_texto, pex_contribucion, pex_direccion,
         pex_valor_observado, pex_valor_referencia, pex_usuario_creacion)
    /* AUMENTA / DISMINUYE: lo fija CK_PEX_DIRECCION. */
    VALUES
        (@PRED, 1, 'Vibración',                  31, 'AUMENTA', 7.9,  6.0, @USU),
        (@PRED, 2, 'Temperatura',                18, 'AUMENTA', 78.0, 66.0, @USU),
        (@PRED, 3, 'Patrón anómalo recurrente',  12, 'AUMENTA', NULL, NULL, @USU)

    PRINT '--- Prediccion de demo creada. Alerta ' + LTRIM(STR(@ALERTA)) +
          ', prediccion ' + LTRIM(STR(@PRED))
END
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
DECLARE @A INT
SELECT TOP 1 @A = ale_id FROM [dbo].[Alerta]
 WHERE ale_prediccion IS NOT NULL ORDER BY ale_id DESC

EXEC [dbo].[SEL_ALERTA_PREDICCION] @ALERTA = @A, @CLIENTE = 1
GO

PRINT '114_PREDICCION_DEMO aplicado.'
GO
