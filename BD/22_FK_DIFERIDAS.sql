USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  20-08-2026
-- DESCRIPTION:     CIERRE DEL GRAFO: FK QUE CRUZAN DOMINIOS HACIA ATRAS.
-- =============================================
-- ORDEN: EL ULTIMO antes de 99_VERIFICACION.sql
--
-- POR QUE ESTE BLOQUE EXISTE
--   El modelo tiene ciclos REALES, no accidentales:
--     una medicion puede nacer de una OT   (amd_orden_trabajo)
--     y una OT puede registrar mediciones  (Activo_Medicion -> OT)
--     una prediccion puede generar una OT  (otr_prediccion)
--     y una OT puede confirmar la prediccion (prs_orden_trabajo)
--
--   Un ciclo no se puede crear en un solo orden de CREATE TABLE. Las
--   opciones eran tres:
--     (a) romper el ciclo quitando una FK  -> se pierde integridad
--     (b) usar tablas puente sin FK real   -> se pierde integridad
--     (c) crear las columnas primero y las FK al final  <- esta
--
--   La opcion (c) conserva TODAS las FK como restricciones reales de la
--   base. El costo es este archivo. Es un costo barato.
--
-- ARCHIVO_VINCULO TAMBIEN VA AQUI
--   Es la tabla que reemplazo a las diez tablas *_Archivo identicas. Tiene
--   FK nullable a doce padres distintos, asi que solo se puede crear
--   cuando los doce existen. Ese momento es ahora.
--
-- IDEMPOTENTE: cada ALTER pregunta primero si la constraint ya existe.
-- =============================================


/* ========================================================================
   1. HACIA ORDEN_TRABAJO

      Diez tablas de dominios anteriores apuntan a la OT. Todas se crean
      antes que ella porque la OT las referencia a su vez.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_APH_ORDEN_TRABAJO')
    ALTER TABLE [dbo].[Activo_Posicion_Historial] WITH CHECK
        ADD CONSTRAINT FK_APH_ORDEN_TRABAJO FOREIGN KEY ([aph_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_AEH_ORDEN_TRABAJO')
    ALTER TABLE [dbo].[Activo_Estado_Historial] WITH CHECK
        ADD CONSTRAINT FK_AEH_ORDEN_TRABAJO FOREIGN KEY ([aeh_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_AMD_ORDEN_TRABAJO')
    ALTER TABLE [dbo].[Activo_Medicion] WITH CHECK
        ADD CONSTRAINT FK_AMD_ORDEN_TRABAJO FOREIGN KEY ([amd_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_AML_ORDEN_TRABAJO')
    ALTER TABLE [dbo].[Activo_Medidor_Lectura] WITH CHECK
        ADD CONSTRAINT FK_AML_ORDEN_TRABAJO FOREIGN KEY ([aml_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_IMO_ORDEN_TRABAJO')
    ALTER TABLE [dbo].[Inventario_Movimiento] WITH CHECK
        ADD CONSTRAINT FK_IMO_ORDEN_TRABAJO FOREIGN KEY ([imo_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO

-- Las dos del repuesto instalado: con que OT se monto y con cual se retiro.
-- Son las que permiten calcular la vida util real de una pieza fisica.
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CRI_OT_INSTALACION')
    ALTER TABLE [dbo].[Componente_Repuesto_Instalacion] WITH CHECK
        ADD CONSTRAINT FK_CRI_OT_INSTALACION FOREIGN KEY ([cri_orden_trabajo_instalacion]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CRI_OT_RETIRO')
    ALTER TABLE [dbo].[Componente_Repuesto_Instalacion] WITH CHECK
        ADD CONSTRAINT FK_CRI_OT_RETIRO FOREIGN KEY ([cri_orden_trabajo_retiro]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_PMO_ORDEN_TRABAJO')
    ALTER TABLE [dbo].[Plan_Mantenimiento_Ocurrencia] WITH CHECK
        ADD CONSTRAINT FK_PMO_ORDEN_TRABAJO FOREIGN KEY ([pmo_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_TOC_ORDEN_TRABAJO')
    ALTER TABLE [dbo].[Tarea_Ocurrencia] WITH CHECK
        ADD CONSTRAINT FK_TOC_ORDEN_TRABAJO FOREIGN KEY ([toc_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CHA_ORDEN_TRABAJO')
    ALTER TABLE [dbo].[Checklist_Hallazgo] WITH CHECK
        ADD CONSTRAINT FK_CHA_ORDEN_TRABAJO FOREIGN KEY ([cha_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_PTR_ORDEN_TRABAJO')
    ALTER TABLE [dbo].[Permiso_Trabajo] WITH CHECK
        ADD CONSTRAINT FK_PTR_ORDEN_TRABAJO FOREIGN KEY ([ptr_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ALE_ORDEN_TRABAJO')
    ALTER TABLE [dbo].[Alerta] WITH CHECK
        ADD CONSTRAINT FK_ALE_ORDEN_TRABAJO FOREIGN KEY ([ale_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FAC_ORDEN_TRABAJO')
    ALTER TABLE [dbo].[Falla_Accion] WITH CHECK
        ADD CONSTRAINT FK_FAC_ORDEN_TRABAJO FOREIGN KEY ([fac_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_PRE_ORDEN_TRABAJO')
    ALTER TABLE [dbo].[Prediccion] WITH CHECK
        ADD CONSTRAINT FK_PRE_ORDEN_TRABAJO FOREIGN KEY ([pre_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_PRS_ORDEN_TRABAJO')
    ALTER TABLE [dbo].[Prediccion_Resultado] WITH CHECK
        ADD CONSTRAINT FK_PRS_ORDEN_TRABAJO FOREIGN KEY ([prs_orden_trabajo]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO


/* ========================================================================
   2. HACIA CHECKLIST Y PREDICCION

      El ciclo checklist -> medicion -> checklist y el ciclo
      prediccion -> OT -> prediccion se cierran aqui.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_AMD_CER')
    ALTER TABLE [dbo].[Activo_Medicion] WITH CHECK
        ADD CONSTRAINT FK_AMD_CER FOREIGN KEY ([amd_checklist_ejecucion_respuesta]) REFERENCES [dbo].[Checklist_Ejecucion_Respuesta] ([cer_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ALE_CER')
    ALTER TABLE [dbo].[Alerta] WITH CHECK
        ADD CONSTRAINT FK_ALE_CER FOREIGN KEY ([ale_checklist_ejecucion_respuesta]) REFERENCES [dbo].[Checklist_Ejecucion_Respuesta] ([cer_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ALE_PMO')
    ALTER TABLE [dbo].[Alerta] WITH CHECK
        ADD CONSTRAINT FK_ALE_PMO FOREIGN KEY ([ale_plan_mantenimiento_ocurrencia]) REFERENCES [dbo].[Plan_Mantenimiento_Ocurrencia] ([pmo_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ALE_PREDICCION')
    ALTER TABLE [dbo].[Alerta] WITH CHECK
        ADD CONSTRAINT FK_ALE_PREDICCION FOREIGN KEY ([ale_prediccion]) REFERENCES [dbo].[Prediccion] ([pre_id])
GO

-- La OT nacida de una prediccion. Cierra el circuito de SIGMA Intelligence:
-- el modelo avisa, alguien abre la OT, y Prediccion_Resultado mide si acerto.
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_OTR_PREDICCION')
    ALTER TABLE [dbo].[Orden_Trabajo] WITH CHECK
        ADD CONSTRAINT FK_OTR_PREDICCION FOREIGN KEY ([otr_prediccion]) REFERENCES [dbo].[Prediccion] ([pre_id])
GO


/* ========================================================================
   3. HACIA ARCHIVO Y PROVEEDOR
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_OTV_ARCHIVO_FIRMA')
    ALTER TABLE [dbo].[Orden_Trabajo_Validacion] WITH CHECK
        ADD CONSTRAINT FK_OTV_ARCHIVO_FIRMA FOREIGN KEY ([otv_archivo_firma]) REFERENCES [dbo].[Archivo] ([arc_id])
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_RLO_PROVEEDOR')
    ALTER TABLE [dbo].[Repuesto_Lote] WITH CHECK
        ADD CONSTRAINT FK_RLO_PROVEEDOR FOREIGN KEY ([rlo_proveedor]) REFERENCES [dbo].[Proveedor] ([prv_id])
GO


/* ========================================================================
   4. ARCHIVO_VINCULO (avi) -- UNA tabla en lugar de diez

      Reemplaza a Orden_Trabajo_Archivo, Falla_Archivo, Bitacora_Archivo,
      Checklist_Respuesta_Archivo, Plan_Actividad_Archivo,
      Checklist_Item_Archivo, Tarea_Archivo, Activo_Archivo,
      Repuesto_Archivo y Permiso_Trabajo_Archivo.

      El CHECK exige EXACTAMENTE UNA FK informada. Eso es lo que hace que
      esta tabla no sea una relacion polimorfica disfrazada: cada columna
      es una FK real que la base valida, y la fila no puede colgar de dos
      padres ni de ninguno.

      avi_es_referencia distingue los dos usos que la UI tiene que
      separar:
        1 = imagen de REFERENCIA: la puso el planificador, muestra como
            DEBE quedar el trabajo
        0 = evidencia de EJECUCION: la tomo el tecnico, muestra como
            QUEDO
      Sin ese BIT, la app mezcla la foto modelo con la foto del terreno y
      el tecnico no sabe cual esta mirando.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Archivo_Vinculo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Archivo_Vinculo]
    (
        [avi_id]                              INT             NOT NULL IDENTITY(1,1),
        [avi_archivo]                         INT             NOT NULL,
        -- Doce padres posibles, exactamente uno informado
        [avi_orden_trabajo]                   INT             NULL,
        [avi_orden_trabajo_paso]              INT             NULL,
        [avi_falla]                           INT             NULL,
        [avi_bitacora]                        INT             NULL,
        [avi_checklist_ejecucion_respuesta]   INT             NULL,
        [avi_checklist_plantilla_item]        INT             NULL,   -- imagen de referencia del item
        [avi_plan_mantenimiento_actividad]    INT             NULL,   -- imagen de referencia de la actividad
        [avi_tarea_ejecucion]                 INT             NULL,
        [avi_activo]                          INT             NULL,
        [avi_repuesto]                        INT             NULL,
        [avi_permiso_trabajo]                 INT             NULL,   -- la foto del permiso firmado
        [avi_checklist_hallazgo]              INT             NULL,
        -- Que clase de vinculo es
        [avi_es_referencia]                   BIT             NOT NULL CONSTRAINT DF_AVI_REFERENCIA DEFAULT 0,
        [avi_orden]                           INT             NULL,
        [avi_titulo]                          NVARCHAR(200)   NULL,
        [avi_descripcion]                     NVARCHAR(500)   NULL,
        [avi_usuario_creacion]                INT             NOT NULL,
        [avi_fecha_creacion]                  DATETIME        NOT NULL CONSTRAINT DF_AVI_FECHA_CREACION DEFAULT GETDATE(),
        [avi_usuario_actualizacion]           INT             NULL,
        [avi_fecha_actualizacion]             DATETIME        NULL,
        [avi_habilitado]                      BIT             NOT NULL CONSTRAINT DF_AVI_HABILITADO DEFAULT 1,

        CONSTRAINT PK_ARCHIVO_VINCULO PRIMARY KEY CLUSTERED ([avi_id] ASC),
        CONSTRAINT FK_AVI_ARCHIVO      FOREIGN KEY ([avi_archivo])                       REFERENCES [dbo].[Archivo] ([arc_id]),
        CONSTRAINT FK_AVI_OT           FOREIGN KEY ([avi_orden_trabajo])                 REFERENCES [dbo].[Orden_Trabajo] ([otr_id]),
        CONSTRAINT FK_AVI_OT_PASO      FOREIGN KEY ([avi_orden_trabajo_paso])            REFERENCES [dbo].[Orden_Trabajo_Paso] ([otp_id]),
        CONSTRAINT FK_AVI_FALLA        FOREIGN KEY ([avi_falla])                         REFERENCES [dbo].[Falla] ([fal_id]),
        CONSTRAINT FK_AVI_BITACORA     FOREIGN KEY ([avi_bitacora])                      REFERENCES [dbo].[Bitacora] ([bit_id]),
        CONSTRAINT FK_AVI_CER          FOREIGN KEY ([avi_checklist_ejecucion_respuesta]) REFERENCES [dbo].[Checklist_Ejecucion_Respuesta] ([cer_id]),
        CONSTRAINT FK_AVI_CPI          FOREIGN KEY ([avi_checklist_plantilla_item])      REFERENCES [dbo].[Checklist_Plantilla_Item] ([cpi_id]),
        CONSTRAINT FK_AVI_PAA          FOREIGN KEY ([avi_plan_mantenimiento_actividad])  REFERENCES [dbo].[Plan_Mantenimiento_Actividad] ([paa_id]),
        CONSTRAINT FK_AVI_TAREA_EJEC   FOREIGN KEY ([avi_tarea_ejecucion])               REFERENCES [dbo].[Tarea_Ejecucion] ([tej_id]),
        CONSTRAINT FK_AVI_ACTIVO       FOREIGN KEY ([avi_activo])                        REFERENCES [dbo].[Activo] ([act_id]),
        CONSTRAINT FK_AVI_REPUESTO     FOREIGN KEY ([avi_repuesto])                      REFERENCES [dbo].[Repuesto] ([rep_id]),
        CONSTRAINT FK_AVI_PERMISO      FOREIGN KEY ([avi_permiso_trabajo])               REFERENCES [dbo].[Permiso_Trabajo] ([ptr_id]),
        CONSTRAINT FK_AVI_HALLAZGO     FOREIGN KEY ([avi_checklist_hallazgo])            REFERENCES [dbo].[Checklist_Hallazgo] ([cha_id]),
        -- EXACTAMENTE UN padre. Ni cero ni dos.
        CONSTRAINT CK_AVI_UN_PADRE CHECK
            ((CASE WHEN [avi_orden_trabajo]                 IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN [avi_orden_trabajo_paso]            IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN [avi_falla]                         IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN [avi_bitacora]                      IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN [avi_checklist_ejecucion_respuesta] IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN [avi_checklist_plantilla_item]      IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN [avi_plan_mantenimiento_actividad]  IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN [avi_tarea_ejecucion]               IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN [avi_activo]                        IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN [avi_repuesto]                      IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN [avi_permiso_trabajo]               IS NULL THEN 0 ELSE 1 END) +
             (CASE WHEN [avi_checklist_hallazgo]            IS NULL THEN 0 ELSE 1 END) = 1)
    )
    -- Un indice por padre frecuente, filtrado: "los adjuntos de esta OT"
    -- se resuelve sin tocar las filas de los otros once padres.
    CREATE NONCLUSTERED INDEX IX_AVI_OT       ON [dbo].[Archivo_Vinculo] ([avi_orden_trabajo])                 WHERE [avi_orden_trabajo] IS NOT NULL
    CREATE NONCLUSTERED INDEX IX_AVI_CER      ON [dbo].[Archivo_Vinculo] ([avi_checklist_ejecucion_respuesta]) WHERE [avi_checklist_ejecucion_respuesta] IS NOT NULL
    CREATE NONCLUSTERED INDEX IX_AVI_BITACORA ON [dbo].[Archivo_Vinculo] ([avi_bitacora])                      WHERE [avi_bitacora] IS NOT NULL
    CREATE NONCLUSTERED INDEX IX_AVI_ACTIVO   ON [dbo].[Archivo_Vinculo] ([avi_activo])                        WHERE [avi_activo] IS NOT NULL
    CREATE NONCLUSTERED INDEX IX_AVI_ARCHIVO  ON [dbo].[Archivo_Vinculo] ([avi_archivo])
    PRINT 'Tabla Archivo_Vinculo creada correctamente.'
END
ELSE PRINT 'Tabla Archivo_Vinculo ya existe.'
GO


/* ========================================================================
   5. COMPROBACION DEL CIERRE

      Si alguna de las FK anteriores no quedo creada, aqui se ve. Es
      preferible enterarse ahora que seis meses despues, cuando una fila
      huerfana rompa un reporte.
   ======================================================================== */

DECLARE @ESPERADAS TABLE ([nombre] NVARCHAR(128))
INSERT INTO @ESPERADAS ([nombre]) VALUES
    ('FK_APH_ORDEN_TRABAJO'), ('FK_AEH_ORDEN_TRABAJO'), ('FK_AMD_ORDEN_TRABAJO'),
    ('FK_AML_ORDEN_TRABAJO'), ('FK_IMO_ORDEN_TRABAJO'), ('FK_CRI_OT_INSTALACION'),
    ('FK_CRI_OT_RETIRO'),     ('FK_PMO_ORDEN_TRABAJO'), ('FK_TOC_ORDEN_TRABAJO'),
    ('FK_CHA_ORDEN_TRABAJO'), ('FK_PTR_ORDEN_TRABAJO'), ('FK_ALE_ORDEN_TRABAJO'),
    ('FK_FAC_ORDEN_TRABAJO'), ('FK_PRE_ORDEN_TRABAJO'), ('FK_PRS_ORDEN_TRABAJO'),
    ('FK_AMD_CER'),           ('FK_ALE_CER'),           ('FK_ALE_PMO'),
    ('FK_ALE_PREDICCION'),    ('FK_OTR_PREDICCION'),    ('FK_OTV_ARCHIVO_FIRMA'),
    ('FK_RLO_PROVEEDOR')

SELECT
    'FK diferidas'                                              AS [concepto],
    (SELECT COUNT(*) FROM @ESPERADAS)                           AS [esperadas],
    (SELECT COUNT(*) FROM @ESPERADAS E
      WHERE EXISTS (SELECT 1 FROM sys.foreign_keys F WHERE F.name = E.[nombre])) AS [creadas]

SELECT E.[nombre] AS [FK QUE FALTA]
  FROM @ESPERADAS E
 WHERE NOT EXISTS (SELECT 1 FROM sys.foreign_keys F WHERE F.name = E.[nombre])
GO


PRINT 'Bloque 22 FK DIFERIDAS: 22 constraints y 1 tabla procesadas.'
GO
