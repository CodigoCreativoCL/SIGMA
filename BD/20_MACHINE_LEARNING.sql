USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  20-08-2026
-- DESCRIPTION:     D12 -- MACHINE LEARNING: EL MOTOR DE SIGMA INTELLIGENCE.
-- =============================================
-- Ver SIGMA_MODELO_LOGICO_v2.md §8.12
-- ORDEN: despues de 23_BITACORA.sql
--
-- ESTAS DIEZ TABLAS SON LO QUE HAY DETRAS DE "SIGMA INTELLIGENCE"
--   Lo que el usuario ve en la portada -- la tarjeta que se anima y suena
--   cuando una maquina entra en riesgo -- se alimenta de Prediccion. Todo
--   lo demas de este bloque existe para que esa tarjeta sea creible.
--
-- UNA PREDICCION SIN EXPLICACION NO SE USA
--   "El blower CB01 va a fallar en 12 dias" no mueve a nadie. "El blower
--   CB01 va a fallar en 12 dias PORQUE la temperatura del descanso subio
--   14% en tres semanas y el horometro paso las 8.700 h sin cambio de
--   rodamiento" hace que el planificador abra la OT.
--
--   Por eso Prediccion_Explicacion no es opcional en la practica: es la
--   diferencia entre un numero que se ignora y una decision que se toma.
--   Es tambien lo que la pantalla muestra al desplegar la tarjeta.
--
-- SIN Prediccion_Resultado EL MODELO NUNCA MEJORA
--   prs_mantenimiento_previo es la columna mas importante del bloque. Sin
--   ella es imposible distinguir dos casos que se ven identicos en los
--   datos:
--     (a) el modelo se equivoco: dijo que fallaria y no fallo
--     (b) el modelo ACERTO: dijo que fallaria, alguien intervino, y por
--         eso no fallo
--   Contar (b) como error entrena al modelo a no avisar. Es el error
--   clasico del mantenimiento predictivo y aqui esta modelado desde el
--   principio.
--
-- EL MODELO SE VERSIONA COMO UN PLAN
--   Modelo_Predictivo_Version congela hiperparametros, metricas y el
--   archivo del modelo. Una prediccion guarda CON QUE VERSION se hizo. Si
--   la v4 resulta peor que la v3, se puede volver -- y se puede demostrar
--   con numeros, no con impresiones.
--
-- IDEMPOTENTE: se puede ejecutar las veces que sea.
-- =============================================


/* ========================================================================
   1. MODELO_PREDICTIVO (mpr) -- el concepto

      mpr_cliente NULL = modelo global entrenado con datos de todas las
      plantas. Es una decision comercial ademas de tecnica: un cliente
      nuevo sin historia recibe predicciones desde el primer dia usando
      el modelo global, y a medida que acumula datos se le entrena el
      suyo. Sin esa columna, SIGMA no serviria de nada los primeros seis
      meses de cada cliente.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Modelo_Predictivo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Modelo_Predictivo]
    (
        [mpr_id]                        INT             NOT NULL IDENTITY(1,1),
        [mpr_cliente]                   INT             NULL,       -- NULL = modelo global SIGMA
        [mpr_modelo_objetivo]           INT             NOT NULL,   -- FALLA / RUL / ANOMALIA / CONSUMO
        [mpr_activo_tipo]               INT             NULL,       -- para que familia de maquina
        [mpr_codigo]                    NVARCHAR(50)    NOT NULL,
        [mpr_nombre]                    NVARCHAR(200)   NOT NULL,
        [mpr_descripcion]               NVARCHAR(MAX)   NULL,
        [mpr_horizonte_dia]             INT             NULL,       -- a cuantos dias predice
        [mpr_umbral_alerta]             DECIMAL(18,6)   NULL,       -- desde que probabilidad se avisa
        [mpr_umbral_critico]            DECIMAL(18,6)   NULL,
        [mpr_usuario_creacion]          INT             NOT NULL,
        [mpr_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_MPR_FECHA_CREACION DEFAULT GETDATE(),
        [mpr_usuario_actualizacion]     INT             NULL,
        [mpr_fecha_actualizacion]       DATETIME        NULL,
        [mpr_habilitado]                BIT             NOT NULL CONSTRAINT DF_MPR_HABILITADO DEFAULT 1,

        CONSTRAINT PK_MODELO_PREDICTIVO PRIMARY KEY CLUSTERED ([mpr_id] ASC),
        CONSTRAINT FK_MPR_CLIENTE     FOREIGN KEY ([mpr_cliente])          REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_MPR_OBJETIVO    FOREIGN KEY ([mpr_modelo_objetivo])  REFERENCES [dbo].[Modelo_Objetivo] ([mob_id]),
        CONSTRAINT FK_MPR_ACTIVO_TIPO FOREIGN KEY ([mpr_activo_tipo])      REFERENCES [dbo].[Activo_Tipo] ([ati_id]),
        CONSTRAINT CK_MPR_UMBRAL CHECK
            (([mpr_umbral_alerta]  IS NULL OR ([mpr_umbral_alerta]  >= 0 AND [mpr_umbral_alerta]  <= 1))
         AND ([mpr_umbral_critico] IS NULL OR ([mpr_umbral_critico] >= 0 AND [mpr_umbral_critico] <= 1)))
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_MPR_CLIENTE_CODIGO
        ON [dbo].[Modelo_Predictivo] ([mpr_cliente], [mpr_codigo]) WHERE [mpr_cliente] IS NOT NULL
    CREATE UNIQUE NONCLUSTERED INDEX UX_MPR_GLOBAL_CODIGO
        ON [dbo].[Modelo_Predictivo] ([mpr_codigo]) WHERE [mpr_cliente] IS NULL
    PRINT 'Tabla Modelo_Predictivo creada correctamente.'
END
ELSE PRINT 'Tabla Modelo_Predictivo ya existe.'
GO


/* ========================================================================
   2. CARACTERISTICA_MODELO (cmo) -- las features

      Cada fila es una variable de entrada: "temperatura media 7 dias",
      "horas desde el ultimo cambio de rodamiento", "cantidad de fallas
      en 90 dias". cmo_expresion guarda como se calcula.

      Existe como tabla y no como codigo porque la explicacion que se le
      muestra al usuario ("la temperatura subio 14%") tiene que salir de
      algun lado que sea legible en español, y ese lado es cmo_etiqueta.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Caracteristica_Modelo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Caracteristica_Modelo]
    (
        [cmo_id]                        INT             NOT NULL IDENTITY(1,1),
        [cmo_modelo_predictivo]         INT             NOT NULL,
        [cmo_codigo]                    NVARCHAR(100)   NOT NULL,
        [cmo_etiqueta]                  NVARCHAR(200)   NOT NULL,   -- lo que lee el usuario
        [cmo_descripcion]               NVARCHAR(500)   NULL,
        [cmo_caracteristica_tipo]       INT             NOT NULL,   -- NUMERICA / CATEGORICA / BINARIA / TEMPORAL / DERIVADA
        [cmo_variable_medicion]         INT             NULL,       -- si viene de una serie del activo
        [cmo_unidad_medida]             INT             NULL,
        [cmo_expresion]                 NVARCHAR(MAX)   NULL,       -- como se calcula
        [cmo_ventana_dia]               INT             NULL,       -- sobre cuantos dias se agrega
        [cmo_agregacion]                NVARCHAR(30)    NULL,       -- MEDIA / MAX / MIN / PENDIENTE / CONTEO
        [cmo_orden]                     INT             NULL,
        [cmo_obligatoria]               BIT             NOT NULL CONSTRAINT DF_CMO_OBLIGATORIA DEFAULT 1,
        [cmo_usuario_creacion]          INT             NOT NULL,
        [cmo_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_CMO_FECHA_CREACION DEFAULT GETDATE(),
        [cmo_usuario_actualizacion]     INT             NULL,
        [cmo_fecha_actualizacion]       DATETIME        NULL,
        [cmo_habilitado]                BIT             NOT NULL CONSTRAINT DF_CMO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_CARACTERISTICA_MODELO PRIMARY KEY CLUSTERED ([cmo_id] ASC),
        CONSTRAINT FK_CMO_MODELO   FOREIGN KEY ([cmo_modelo_predictivo]) REFERENCES [dbo].[Modelo_Predictivo] ([mpr_id]),
        CONSTRAINT FK_CMO_TIPO     FOREIGN KEY ([cmo_caracteristica_tipo]) REFERENCES [dbo].[Caracteristica_Tipo] ([ctm_id]),
        CONSTRAINT FK_CMO_VARIABLE FOREIGN KEY ([cmo_variable_medicion]) REFERENCES [dbo].[Variable_Medicion] ([vme_id]),
        CONSTRAINT FK_CMO_UNIDAD   FOREIGN KEY ([cmo_unidad_medida])     REFERENCES [dbo].[Unidad_Medida] ([ume_id]),
        CONSTRAINT UX_CMO_MODELO_CODIGO UNIQUE ([cmo_modelo_predictivo], [cmo_codigo]),
        CONSTRAINT CK_CMO_AGREGACION CHECK
            ([cmo_agregacion] IS NULL OR [cmo_agregacion] IN ('MEDIA','MAX','MIN','SUMA','CONTEO','PENDIENTE','DESVIACION','ULTIMO'))
    )
    PRINT 'Tabla Caracteristica_Modelo creada correctamente.'
END
ELSE PRINT 'Tabla Caracteristica_Modelo ya existe.'
GO


/* ========================================================================
   3. DATASET_ENTRENAMIENTO (den)

      El corte de datos con el que se entreno una version. Guardar el
      rango de fechas y el conteo de filas es lo que hace REPRODUCIBLE el
      entrenamiento: sin eso, "reentrenamos y dio peor" es una anecdota
      que nadie puede investigar.

      den_hash_datos permite detectar que dos entrenamientos que dicen
      usar el mismo dataset efectivamente lo hicieron.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Dataset_Entrenamiento]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Dataset_Entrenamiento]
    (
        [den_id]                        INT             NOT NULL IDENTITY(1,1),
        [den_modelo_predictivo]         INT             NOT NULL,
        [den_cliente]                   INT             NULL,
        [den_codigo]                    NVARCHAR(50)    NOT NULL,
        [den_nombre]                    NVARCHAR(200)   NOT NULL,
        [den_fecha_desde]               DATE            NOT NULL,
        [den_fecha_hasta]               DATE            NOT NULL,
        [den_fila_total]                INT             NULL,
        [den_fila_positiva]             INT             NULL,       -- cuantos casos de falla real
        [den_fila_entrenamiento]        INT             NULL,
        [den_fila_validacion]           INT             NULL,
        [den_fila_prueba]               INT             NULL,
        [den_hash_datos]                NVARCHAR(64)    NULL,
        [den_ruta]                      NVARCHAR(500)   NULL,
        [den_observacion]               NVARCHAR(MAX)   NULL,
        [den_usuario_creacion]          INT             NOT NULL,
        [den_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_DEN_FECHA_CREACION DEFAULT GETDATE(),
        [den_usuario_actualizacion]     INT             NULL,
        [den_fecha_actualizacion]       DATETIME        NULL,
        [den_habilitado]                BIT             NOT NULL CONSTRAINT DF_DEN_HABILITADO DEFAULT 1,

        CONSTRAINT PK_DATASET_ENTRENAMIENTO PRIMARY KEY CLUSTERED ([den_id] ASC),
        CONSTRAINT FK_DEN_MODELO  FOREIGN KEY ([den_modelo_predictivo]) REFERENCES [dbo].[Modelo_Predictivo] ([mpr_id]),
        CONSTRAINT FK_DEN_CLIENTE FOREIGN KEY ([den_cliente])           REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT UX_DEN_MODELO_CODIGO UNIQUE ([den_modelo_predictivo], [den_codigo]),
        CONSTRAINT CK_DEN_RANGO CHECK ([den_fecha_hasta] >= [den_fecha_desde])
    )
    PRINT 'Tabla Dataset_Entrenamiento creada correctamente.'
END
ELSE PRINT 'Tabla Dataset_Entrenamiento ya existe.'
GO


/* ========================================================================
   4. MODELO_PREDICTIVO_VERSION (mpv) -- lo que se congela

      Las metricas van aqui y no en el modelo porque son de LA VERSION.
      Poder mostrar "v3: AUC 0,84 / v4: AUC 0,79" es lo que convierte la
      decision de publicar en un hecho comprobable.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Modelo_Predictivo_Version]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Modelo_Predictivo_Version]
    (
        [mpv_id]                        INT             NOT NULL IDENTITY(1,1),
        [mpv_modelo_predictivo]         INT             NOT NULL,
        [mpv_dataset_entrenamiento]     INT             NULL,
        [mpv_numero]                    INT             NOT NULL,
        [mpv_modelo_formato]            INT             NOT NULL,   -- ONNX / PICKLE / PMML
        [mpv_algoritmo]                 NVARCHAR(100)   NULL,
        [mpv_hiperparametro]            NVARCHAR(MAX)   NULL,       -- JSON
        [mpv_ruta]                      NVARCHAR(500)   NULL,
        [mpv_hash]                      NVARCHAR(64)    NULL,
        [mpv_byte]                      BIGINT          NULL,
        -- Metricas de la version
        [mpv_metrica_auc]               DECIMAL(18,6)   NULL,
        [mpv_metrica_precision]         DECIMAL(18,6)   NULL,
        [mpv_metrica_recall]            DECIMAL(18,6)   NULL,
        [mpv_metrica_f1]                DECIMAL(18,6)   NULL,
        [mpv_metrica_mae]               DECIMAL(18,6)   NULL,       -- para RUL, en dias
        -- Publicacion
        [mpv_plan_version_estado]       INT             NOT NULL,   -- BORRADOR / PUBLICADO / RETIRADO
        [mpv_fecha_entrenamiento_utc]   DATETIME        NULL,
        [mpv_fecha_publicacion]         DATETIME        NULL,
        [mpv_usuario_publicacion]       INT             NULL,
        [mpv_fecha_retiro]              DATETIME        NULL,
        [mpv_observacion]               NVARCHAR(MAX)   NULL,
        [mpv_usuario_creacion]          INT             NOT NULL,
        [mpv_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_MPV_FECHA_CREACION DEFAULT GETDATE(),
        [mpv_usuario_actualizacion]     INT             NULL,
        [mpv_fecha_actualizacion]       DATETIME        NULL,
        [mpv_habilitado]                BIT             NOT NULL CONSTRAINT DF_MPV_HABILITADO DEFAULT 1,

        CONSTRAINT PK_MODELO_PREDICTIVO_VERSION PRIMARY KEY CLUSTERED ([mpv_id] ASC),
        CONSTRAINT FK_MPV_MODELO     FOREIGN KEY ([mpv_modelo_predictivo])     REFERENCES [dbo].[Modelo_Predictivo] ([mpr_id]),
        CONSTRAINT FK_MPV_DATASET    FOREIGN KEY ([mpv_dataset_entrenamiento]) REFERENCES [dbo].[Dataset_Entrenamiento] ([den_id]),
        CONSTRAINT FK_MPV_FORMATO    FOREIGN KEY ([mpv_modelo_formato])        REFERENCES [dbo].[Modelo_Formato] ([mfo_id]),
        CONSTRAINT FK_MPV_ESTADO     FOREIGN KEY ([mpv_plan_version_estado])   REFERENCES [dbo].[Plan_Version_Estado] ([pve_id]),
        CONSTRAINT FK_MPV_PUBLICADOR FOREIGN KEY ([mpv_usuario_publicacion])   REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT UX_MPV_MODELO_NUMERO UNIQUE ([mpv_modelo_predictivo], [mpv_numero]),
        CONSTRAINT CK_MPV_NUMERO CHECK ([mpv_numero] >= 1)
    )
    PRINT 'Tabla Modelo_Predictivo_Version creada correctamente.'
END
ELSE PRINT 'Tabla Modelo_Predictivo_Version ya existe.'
GO


/* ========================================================================
   5. ENTRENAMIENTO_EJECUCION (eej) -- cada corrida

      Incluye las que fallaron. Un entrenamiento que se cayo a las tres
      horas por falta de memoria es informacion util; borrarlo hace que
      el problema se repita.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Entrenamiento_Ejecucion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Entrenamiento_Ejecucion]
    (
        [eej_id]                        INT             NOT NULL IDENTITY(1,1),
        [eej_modelo_predictivo]         INT             NOT NULL,
        [eej_modelo_predictivo_version] INT             NULL,       -- NULL si no llego a producir version
        [eej_dataset_entrenamiento]     INT             NULL,
        [eej_proceso_estado]            INT             NOT NULL,
        [eej_entorno]                   NVARCHAR(200)   NULL,       -- donde corrio
        [eej_fecha_inicio_utc]          DATETIME        NOT NULL CONSTRAINT DF_EEJ_FECHA_INICIO DEFAULT GETUTCDATE(),
        [eej_fecha_fin_utc]             DATETIME        NULL,
        [eej_segundo_duracion]          INT             NULL,
        [eej_metrica]                   NVARCHAR(MAX)   NULL,       -- JSON con todo lo que salio
        [eej_mensaje]                   NVARCHAR(MAX)   NULL,       -- el error, si lo hubo
        [eej_usuario_creacion]          INT             NOT NULL,
        [eej_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_EEJ_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_ENTRENAMIENTO_EJECUCION PRIMARY KEY CLUSTERED ([eej_id] ASC),
        CONSTRAINT FK_EEJ_MODELO  FOREIGN KEY ([eej_modelo_predictivo])         REFERENCES [dbo].[Modelo_Predictivo] ([mpr_id]),
        CONSTRAINT FK_EEJ_VERSION FOREIGN KEY ([eej_modelo_predictivo_version]) REFERENCES [dbo].[Modelo_Predictivo_Version] ([mpv_id]),
        CONSTRAINT FK_EEJ_DATASET FOREIGN KEY ([eej_dataset_entrenamiento])     REFERENCES [dbo].[Dataset_Entrenamiento] ([den_id]),
        CONSTRAINT FK_EEJ_ESTADO  FOREIGN KEY ([eej_proceso_estado])            REFERENCES [dbo].[Proceso_Estado] ([pes_id]),
        CONSTRAINT CK_EEJ_FECHAS CHECK ([eej_fecha_fin_utc] IS NULL OR [eej_fecha_fin_utc] >= [eej_fecha_inicio_utc])
    )
    CREATE NONCLUSTERED INDEX IX_EEJ_MODELO_FECHA ON [dbo].[Entrenamiento_Ejecucion] ([eej_modelo_predictivo], [eej_fecha_inicio_utc])
    PRINT 'Tabla Entrenamiento_Ejecucion creada correctamente.'
END
ELSE PRINT 'Tabla Entrenamiento_Ejecucion ya existe.'
GO


/* ========================================================================
   6. PREDICCION (pre) -- LA FILA QUE VE EL USUARIO

      Esta es la tabla que alimenta la tarjeta de SIGMA Intelligence en la
      portada de la web y en el inicio de la app.

      pre_componente_repuesto_instalacion permite predecir a nivel del
      REPUESTO FISICO instalado, que es la unidad natural de la vida util
      restante: no se agota "el blower", se agota el rodamiento que se
      monto en marzo.

      pre_valor + pre_probabilidad + pre_dia_restante son los tres numeros
      que la tarjeta muestra segun el tipo de modelo.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Prediccion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Prediccion]
    (
        [pre_id]                              INT                 NOT NULL IDENTITY(1,1),
        [pre_uuid]                            UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_PRE_UUID DEFAULT NEWID(),
        [pre_cliente]                         INT                 NOT NULL,
        [pre_modelo_predictivo_version]       INT                 NOT NULL,
        [pre_prediccion_estado]               INT                 NOT NULL,
        -- Sobre que se predice
        [pre_activo]                          INT                 NOT NULL,
        [pre_activo_componente]               INT                 NULL,
        [pre_componente_repuesto_instalacion] INT                 NULL,
        -- Que dice
        [pre_valor]                           DECIMAL(18,6)       NULL,      -- valor predicho (RUL en dias, consumo, etc.)
        [pre_probabilidad]                    DECIMAL(18,6)       NULL,      -- 0..1 para clasificacion
        [pre_dia_restante]                    INT                 NULL,      -- vida util restante estimada
        [pre_fecha_evento_estimada_utc]       DATETIME            NULL,
        [pre_severidad]                       INT                 NULL,
        [pre_confianza]                       DECIMAL(18,6)       NULL,
        [pre_intervalo_inferior]              DECIMAL(18,6)       NULL,
        [pre_intervalo_superior]              DECIMAL(18,6)       NULL,
        -- Cuando se calculo
        [pre_fecha_calculo_utc]               DATETIME            NOT NULL CONSTRAINT DF_PRE_FECHA_CALCULO DEFAULT GETUTCDATE(),
        [pre_fecha_vigencia_hasta_utc]        DATETIME            NULL,      -- despues de esto hay que recalcular
        -- Que se hizo con ella
        [pre_alerta]                          INT                 NULL,
        [pre_orden_trabajo]                   INT                 NULL,      -- FK diferida (bloque 22)
        [pre_usuario_revision]                INT                 NULL,
        [pre_fecha_revision_utc]              DATETIME            NULL,
        [pre_motivo_descarte]                 NVARCHAR(500)       NULL,
        [pre_usuario_creacion]                INT                 NOT NULL,
        [pre_fecha_creacion]                  DATETIME            NOT NULL CONSTRAINT DF_PRE_FECHA_CREACION DEFAULT GETDATE(),
        [pre_usuario_actualizacion]           INT                 NULL,
        [pre_fecha_actualizacion]             DATETIME            NULL,
        [pre_habilitado]                      BIT                 NOT NULL CONSTRAINT DF_PRE_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PREDICCION PRIMARY KEY CLUSTERED ([pre_id] ASC),
        CONSTRAINT FK_PRE_CLIENTE     FOREIGN KEY ([pre_cliente])                         REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_PRE_VERSION     FOREIGN KEY ([pre_modelo_predictivo_version])       REFERENCES [dbo].[Modelo_Predictivo_Version] ([mpv_id]),
        CONSTRAINT FK_PRE_ESTADO      FOREIGN KEY ([pre_prediccion_estado])               REFERENCES [dbo].[Prediccion_Estado] ([pde_id]),
        CONSTRAINT FK_PRE_ACTIVO      FOREIGN KEY ([pre_activo])                          REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_PRE_COMPONENTE  FOREIGN KEY ([pre_activo_componente])               REFERENCES [dbo].[Activo_Componente] ([aco_id]),
        CONSTRAINT FK_PRE_INSTALACION FOREIGN KEY ([pre_componente_repuesto_instalacion]) REFERENCES [dbo].[Componente_Repuesto_Instalacion] ([cri_id]),
        CONSTRAINT FK_PRE_SEVERIDAD   FOREIGN KEY ([pre_severidad])                       REFERENCES [dbo].[Severidad] ([sev_id]),
        CONSTRAINT FK_PRE_ALERTA      FOREIGN KEY ([pre_alerta])                          REFERENCES [dbo].[Alerta] ([ale_id]),
        CONSTRAINT FK_PRE_REVISION    FOREIGN KEY ([pre_usuario_revision])                REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT UX_PRE_UUID UNIQUE ([pre_uuid]),
        CONSTRAINT CK_PRE_PROBABILIDAD CHECK
            ([pre_probabilidad] IS NULL OR ([pre_probabilidad] >= 0 AND [pre_probabilidad] <= 1)),
        CONSTRAINT CK_PRE_CONFIANZA CHECK
            ([pre_confianza] IS NULL OR ([pre_confianza] >= 0 AND [pre_confianza] <= 1)),
        CONSTRAINT CK_PRE_INTERVALO CHECK
            ([pre_intervalo_inferior] IS NULL OR [pre_intervalo_superior] IS NULL
             OR [pre_intervalo_superior] >= [pre_intervalo_inferior])
    )
    -- El indice que hace instantanea la portada: ultimas predicciones vigentes
    -- del cliente, ordenadas por gravedad.
    CREATE NONCLUSTERED INDEX IX_PRE_CLIENTE_VIGENTE
        ON [dbo].[Prediccion] ([pre_cliente], [pre_severidad], [pre_fecha_calculo_utc])
        INCLUDE ([pre_activo], [pre_probabilidad], [pre_dia_restante])
    CREATE NONCLUSTERED INDEX IX_PRE_ACTIVO_FECHA ON [dbo].[Prediccion] ([pre_activo], [pre_fecha_calculo_utc])
    PRINT 'Tabla Prediccion creada correctamente.'
END
ELSE PRINT 'Tabla Prediccion ya existe.'
GO


/* ========================================================================
   7. PREDICCION_CARACTERISTICA (pcr) -- los valores que entraron

      Con que numeros exactos se calculo esta prediccion. Es lo que
      permite reproducir el resultado y, sobre todo, defenderlo cuando el
      jefe de mantenimiento pregunta "y de donde sacaste eso".
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Prediccion_Caracteristica]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Prediccion_Caracteristica]
    (
        [pcr_id]                        INT             NOT NULL IDENTITY(1,1),
        [pcr_prediccion]                INT             NOT NULL,
        [pcr_caracteristica_modelo]     INT             NOT NULL,
        [pcr_valor]                     DECIMAL(18,6)   NULL,
        [pcr_valor_texto]               NVARCHAR(500)   NULL,
        [pcr_imputado]                  BIT             NOT NULL CONSTRAINT DF_PCR_IMPUTADO DEFAULT 0,
        [pcr_usuario_creacion]          INT             NOT NULL,
        [pcr_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PCR_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_PREDICCION_CARACTERISTICA PRIMARY KEY CLUSTERED ([pcr_id] ASC),
        CONSTRAINT FK_PCR_PREDICCION     FOREIGN KEY ([pcr_prediccion])            REFERENCES [dbo].[Prediccion] ([pre_id]),
        CONSTRAINT FK_PCR_CARACTERISTICA FOREIGN KEY ([pcr_caracteristica_modelo]) REFERENCES [dbo].[Caracteristica_Modelo] ([cmo_id]),
        CONSTRAINT UX_PCR_PREDICCION_CARACTERISTICA UNIQUE ([pcr_prediccion], [pcr_caracteristica_modelo])
    )
    PRINT 'Tabla Prediccion_Caracteristica creada correctamente.'
END
ELSE PRINT 'Tabla Prediccion_Caracteristica ya existe.'
GO


/* ========================================================================
   8. PREDICCION_EXPLICACION (pex)

       El prefijo cambio de pem a pex: el anterior no derivaba del nombre
       de la tabla, y el registro de prefijos exige que si lo haga.

       pex_texto es lo que se muestra literalmente en la tarjeta de SIGMA
       Intelligence al desplegarla. pex_contribucion es el peso (SHAP o
       equivalente) que ordena las razones de mayor a menor. La tarjeta
       muestra las tres primeras; el detalle muestra todas.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Prediccion_Explicacion]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Prediccion_Explicacion]
    (
        [pex_id]                        INT             NOT NULL IDENTITY(1,1),
        [pex_prediccion]                INT             NOT NULL,
        [pex_caracteristica_modelo]     INT             NULL,
        [pex_orden]                     INT             NOT NULL CONSTRAINT DF_PEX_ORDEN DEFAULT 1,
        [pex_texto]                     NVARCHAR(500)   NOT NULL,   -- en español, para el usuario
        [pex_contribucion]              DECIMAL(18,6)   NULL,       -- peso relativo (SHAP)
        [pex_direccion]                 NVARCHAR(20)    NULL,       -- AUMENTA / DISMINUYE
        [pex_valor_observado]           DECIMAL(18,6)   NULL,
        [pex_valor_referencia]          DECIMAL(18,6)   NULL,
        [pex_usuario_creacion]          INT             NOT NULL,
        [pex_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PEX_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_PREDICCION_EXPLICACION PRIMARY KEY CLUSTERED ([pex_id] ASC),
        CONSTRAINT FK_PEX_PREDICCION     FOREIGN KEY ([pex_prediccion])            REFERENCES [dbo].[Prediccion] ([pre_id]),
        CONSTRAINT FK_PEX_CARACTERISTICA FOREIGN KEY ([pex_caracteristica_modelo]) REFERENCES [dbo].[Caracteristica_Modelo] ([cmo_id]),
        CONSTRAINT CK_PEX_DIRECCION CHECK ([pex_direccion] IS NULL OR [pex_direccion] IN ('AUMENTA', 'DISMINUYE'))
    )
    CREATE NONCLUSTERED INDEX IX_PEX_PREDICCION ON [dbo].[Prediccion_Explicacion] ([pex_prediccion], [pex_orden])
    PRINT 'Tabla Prediccion_Explicacion creada correctamente.'
END
ELSE PRINT 'Tabla Prediccion_Explicacion ya existe.'
GO


/* ========================================================================
   9. PREDICCION_RESULTADO (prs) -- LA TABLA QUE HACE QUE EL MODELO APRENDA

       prs_mantenimiento_previo distingue el error del acierto que
       provoco una intervencion. Es la unica columna del bloque sin la
       cual el sistema se degrada solo:

         predijo falla + no fallo + NO hubo mantenimiento  -> ERROR real
         predijo falla + no fallo + SI hubo mantenimiento  -> ACIERTO

       Si las dos filas se cuentan igual, el reentrenamiento castiga al
       modelo justamente por las veces que sirvio, y a los pocos ciclos
       deja de avisar.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Prediccion_Resultado]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Prediccion_Resultado]
    (
        [prs_id]                        INT             NOT NULL IDENTITY(1,1),
        [prs_prediccion]                INT             NOT NULL,
        [prs_ocurrio]                   BIT             NOT NULL,
        [prs_falla]                     INT             NULL,       -- la falla real, si ocurrio
        [prs_orden_trabajo]             INT             NULL,       -- FK diferida (bloque 22)
        [prs_fecha_evento_real_utc]     DATETIME        NULL,
        [prs_valor_real]                DECIMAL(18,6)   NULL,
        [prs_error_absoluto]            DECIMAL(18,2)   NULL,       -- |predicho - real|
        [prs_mantenimiento_previo]      BIT             NOT NULL CONSTRAINT DF_PRS_MANTENIMIENTO DEFAULT 0,
        [prs_clasificacion]             NVARCHAR(30)    NULL,       -- calculada al evaluar
        [prs_observacion]               NVARCHAR(MAX)   NULL,
        [prs_usuario_evaluacion]        INT             NULL,
        [prs_fecha_evaluacion_utc]      DATETIME        NOT NULL CONSTRAINT DF_PRS_FECHA_EVALUACION DEFAULT GETUTCDATE(),
        [prs_usuario_creacion]          INT             NOT NULL,
        [prs_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_PRS_FECHA_CREACION DEFAULT GETDATE(),
        [prs_usuario_actualizacion]     INT             NULL,
        [prs_fecha_actualizacion]       DATETIME        NULL,
        [prs_habilitado]                BIT             NOT NULL CONSTRAINT DF_PRS_HABILITADO DEFAULT 1,

        CONSTRAINT PK_PREDICCION_RESULTADO PRIMARY KEY CLUSTERED ([prs_id] ASC),
        CONSTRAINT FK_PRS_PREDICCION FOREIGN KEY ([prs_prediccion])         REFERENCES [dbo].[Prediccion] ([pre_id]),
        CONSTRAINT FK_PRS_FALLA      FOREIGN KEY ([prs_falla])              REFERENCES [dbo].[Falla] ([fal_id]),
        CONSTRAINT FK_PRS_EVALUADOR  FOREIGN KEY ([prs_usuario_evaluacion]) REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT UX_PRS_PREDICCION UNIQUE ([prs_prediccion]),
        CONSTRAINT CK_PRS_CLASIFICACION CHECK
            ([prs_clasificacion] IS NULL
             OR [prs_clasificacion] IN ('VERDADERO POSITIVO', 'FALSO POSITIVO', 'VERDADERO NEGATIVO',
                                        'FALSO NEGATIVO', 'ACIERTO CON INTERVENCION'))
    )
    PRINT 'Tabla Prediccion_Resultado creada correctamente.'
END
ELSE PRINT 'Tabla Prediccion_Resultado ya existe.'
GO


/* ========================================================================
   10. MODELO_MONITOREO (mmo) -- la salud del modelo en produccion

       Un modelo entrenado en 2026 con datos de 2025 se degrada solo: la
       planta cambia de proveedor de aceite, se cambia un blower, se
       modifica el turno. Esta tabla mide esa deriva.

       Si mmo_deriva_datos sube y mmo_metrica_actual baja, hay que
       reentrenar. Sin medirlo, nadie se entera hasta que alguien
       comenta que "las predicciones ya no achuntan".
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Modelo_Monitoreo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Modelo_Monitoreo]
    (
        [mmo_id]                        INT             NOT NULL IDENTITY(1,1),
        [mmo_modelo_predictivo_version] INT             NOT NULL,
        [mmo_cliente]                   INT             NULL,
        [mmo_periodo_anio]              INT             NOT NULL,
        [mmo_periodo_mes]               INT             NOT NULL,
        [mmo_prediccion_total]          INT             NOT NULL CONSTRAINT DF_MMO_TOTAL DEFAULT 0,
        [mmo_prediccion_evaluada]       INT             NOT NULL CONSTRAINT DF_MMO_EVALUADA DEFAULT 0,
        [mmo_verdadero_positivo]        INT             NOT NULL CONSTRAINT DF_MMO_VP DEFAULT 0,
        [mmo_falso_positivo]            INT             NOT NULL CONSTRAINT DF_MMO_FP DEFAULT 0,
        [mmo_verdadero_negativo]        INT             NOT NULL CONSTRAINT DF_MMO_VN DEFAULT 0,
        [mmo_falso_negativo]            INT             NOT NULL CONSTRAINT DF_MMO_FN DEFAULT 0,
        [mmo_acierto_con_intervencion]  INT             NOT NULL CONSTRAINT DF_MMO_ACI DEFAULT 0,
        [mmo_metrica_actual]            DECIMAL(18,6)   NULL,
        [mmo_metrica_referencia]        DECIMAL(18,6)   NULL,
        [mmo_deriva_datos]              DECIMAL(18,6)   NULL,       -- PSI o equivalente
        [mmo_requiere_reentrenamiento]  BIT             NOT NULL CONSTRAINT DF_MMO_REENTRENAR DEFAULT 0,
        [mmo_observacion]               NVARCHAR(MAX)   NULL,
        [mmo_usuario_creacion]          INT             NOT NULL,
        [mmo_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_MMO_FECHA_CREACION DEFAULT GETDATE(),
        [mmo_usuario_actualizacion]     INT             NULL,
        [mmo_fecha_actualizacion]       DATETIME        NULL,
        [mmo_habilitado]                BIT             NOT NULL CONSTRAINT DF_MMO_HABILITADO DEFAULT 1,

        CONSTRAINT PK_MODELO_MONITOREO PRIMARY KEY CLUSTERED ([mmo_id] ASC),
        CONSTRAINT FK_MMO_VERSION FOREIGN KEY ([mmo_modelo_predictivo_version]) REFERENCES [dbo].[Modelo_Predictivo_Version] ([mpv_id]),
        CONSTRAINT FK_MMO_CLIENTE FOREIGN KEY ([mmo_cliente])                   REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT CK_MMO_MES CHECK ([mmo_periodo_mes] BETWEEN 1 AND 12)
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_MMO_VERSION_CLIENTE_PERIODO
        ON [dbo].[Modelo_Monitoreo] ([mmo_modelo_predictivo_version], [mmo_cliente], [mmo_periodo_anio], [mmo_periodo_mes])
        WHERE [mmo_cliente] IS NOT NULL
    CREATE UNIQUE NONCLUSTERED INDEX UX_MMO_VERSION_PERIODO
        ON [dbo].[Modelo_Monitoreo] ([mmo_modelo_predictivo_version], [mmo_periodo_anio], [mmo_periodo_mes])
        WHERE [mmo_cliente] IS NULL
    PRINT 'Tabla Modelo_Monitoreo creada correctamente.'
END
ELSE PRINT 'Tabla Modelo_Monitoreo ya existe.'
GO


/* ========================================================================
   11. VW_SIGMA_INTELLIGENCE -- lo que consume la portada

       Una fila por prediccion vigente, con el activo, la gravedad, los
       dias restantes y las TRES razones principales ya concatenadas.

       La vista existe para que la portada haga UNA consulta. Si la web
       tuviera que pedir la prediccion, luego las explicaciones, luego el
       activo, la pantalla tardaria lo suficiente como para que nadie la
       deje abierta -- y una alerta que nadie mira no sirve.

       nivel: CRITICO / ALTO / MEDIO / INFORMATIVO. Es lo que decide el
       color de la tarjeta, si se anima y si suena.
   ======================================================================== */

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VW_SIGMA_INTELLIGENCE]') AND type = 'V')
    DROP VIEW [dbo].[VW_SIGMA_INTELLIGENCE]
GO

CREATE VIEW [dbo].[VW_SIGMA_INTELLIGENCE]
AS
SELECT
    PRE.[pre_id],
    PRE.[pre_uuid],
    PRE.[pre_cliente],
    ACT.[act_cliente_instalacion],
    PRE.[pre_activo],
    ACT.[act_codigo],
    ACT.[act_nombre],
    ATI.[ati_nombre]                    AS [activo_tipo_nombre],
    MPR.[mpr_nombre]                    AS [modelo_nombre],
    MOB.[mob_codigo]                    AS [objetivo_codigo],
    MPV.[mpv_numero]                    AS [modelo_version],
    PRE.[pre_probabilidad],
    PRE.[pre_dia_restante],
    PRE.[pre_valor],
    PRE.[pre_confianza],
    PRE.[pre_fecha_evento_estimada_utc],
    PRE.[pre_fecha_calculo_utc],
    PRE.[pre_severidad],
    PRE.[pre_orden_trabajo],
    PRE.[pre_alerta],
    -- El nivel decide el color, la animacion y el sonido en la interfaz.
    CASE
        WHEN PRE.[pre_probabilidad] >= ISNULL(MPR.[mpr_umbral_critico], 0.80) THEN 'CRITICO'
        WHEN PRE.[pre_dia_restante] IS NOT NULL AND PRE.[pre_dia_restante] <= 7 THEN 'CRITICO'
        WHEN PRE.[pre_probabilidad] >= ISNULL(MPR.[mpr_umbral_alerta], 0.60) THEN 'ALTO'
        WHEN PRE.[pre_dia_restante] IS NOT NULL AND PRE.[pre_dia_restante] <= 30 THEN 'MEDIO'
        ELSE 'INFORMATIVO'
    END                                 AS [nivel],
    -- Las tres razones principales, listas para mostrar.
    STUFF((SELECT N' · ' + E.[pex_texto]
             FROM [dbo].[Prediccion_Explicacion] E
            WHERE E.[pex_prediccion] = PRE.[pre_id]
            ORDER BY E.[pex_orden]
              OFFSET 0 ROWS FETCH NEXT 3 ROWS ONLY
              FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 3, '') AS [razon_principal],
    -- Si ya se atendio, la tarjeta no debe volver a sonar.
    CASE WHEN PRE.[pre_orden_trabajo] IS NOT NULL THEN 1 ELSE 0 END AS [tiene_orden_trabajo],
    CASE WHEN PRE.[pre_usuario_revision] IS NOT NULL THEN 1 ELSE 0 END AS [fue_revisada]
FROM [dbo].[Prediccion] PRE
    INNER JOIN [dbo].[Modelo_Predictivo_Version] MPV ON MPV.[mpv_id]  = PRE.[pre_modelo_predictivo_version]
    INNER JOIN [dbo].[Modelo_Predictivo]         MPR ON MPR.[mpr_id]  = MPV.[mpv_modelo_predictivo]
    INNER JOIN [dbo].[Modelo_Objetivo]           MOB ON MOB.[mob_id]  = MPR.[mpr_modelo_objetivo]
    INNER JOIN [dbo].[Activo]                    ACT ON ACT.[act_id]  = PRE.[pre_activo]
    LEFT  JOIN [dbo].[Activo_Tipo]               ATI ON ATI.[ati_id]  = ACT.[act_activo_tipo]
WHERE PRE.[pre_habilitado] = 1
  AND PRE.[pre_motivo_descarte] IS NULL
  AND (PRE.[pre_fecha_vigencia_hasta_utc] IS NULL OR PRE.[pre_fecha_vigencia_hasta_utc] >= GETUTCDATE())
GO


PRINT 'Bloque 20 MACHINE LEARNING: 10 tablas y 1 vista procesadas.'
GO
