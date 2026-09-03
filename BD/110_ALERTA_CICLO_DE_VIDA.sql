/* ============================================================================
   SIGMA — Bloque 110
   CICLO DE VIDA DE LA ALERTA: RESPONSABLE, TRANSICIONES Y REPETICIONES
   ----------------------------------------------------------------------------

   LO QUE EL MODELO YA TENIA, Y NO SE TOCA

     Antes de agregar nada se midio lo que habia. La mitad de lo que suele
     pedirse aca ya estaba resuelto desde el bloque 19:

       - Los CINCO estados operacionales existen en `Alerta_Estado`:
         NUEVA, RECONOCIDA, EN GESTION, RESUELTA, DESCARTADA.
       - `Alerta_Lectura` guarda la lectura POR USUARIO, separada del estado
         operacional, que es de la empresa. Abrir una alerta no la resuelve:
         son dos tablas distintas y siempre lo fueron.
       - El detector ya evita duplicados con una llave funcional
         -cliente + tipo + repuesto + bodega + lote- sobre las alertas que
         siguen abiertas.
       - `ale_usuario_atencion` y `ale_fecha_atencion_utc` son el CIERRE, con
         un CHECK que impide poner la fecha sin el usuario.

     Nada de eso se reescribe. Lo que sigue es lo que faltaba de verdad.

   1. EL RESPONSABLE NO ES QUIEN CERRO

     `ale_usuario_atencion` responde "quien la cerro". No responde "de quien
     es ahora", que es lo que la bandeja necesita para poder decir "sin
     responsable" y para que alguien pueda tomarla sin haberla terminado.
     Son dos personas distintas en el caso normal: uno la toma el lunes y
     otro la cierra el jueves.

   2. TRES MOMENTOS, NO UNO

     Reconocer, empezar a gestionar y resolver son tres cosas y ocurren en
     tres momentos. Con una sola fecha de atencion no se puede responder
     cuanto tardo el equipo en HACERSE CARGO, que es distinto de cuanto tardo
     en resolver, y es la unica de las dos que se puede mejorar de inmediato.

   3. LA REPETICION SE PIERDE

     El detector no duplica -eso ya estaba-, pero tampoco deja rastro de que
     la condicion volvio a darse. Un repuesto que cae bajo el minimo catorce
     veces en un mes se ve igual que uno que cayo una sola vez, y son dos
     problemas completamente distintos. Se agregan primera ocurrencia, ultima
     ocurrencia y contador.

   4. NO HAY HISTORIAL DE TRANSICIONES

     Se puede saber en que estado esta una alerta, no como llego. `Alerta_
     Historial` registra cada cambio con quien, cuando y por que.

   TODO ES ADITIVO Y CON DEFAULT SEGURO
     Ninguna columna nueva es obligatoria, ningun estado existente cambia de
     significado, y el bloque se puede volver a ejecutar sin efecto.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. COLUMNAS NUEVAS EN Alerta
   ======================================================================== */

/* De quien es la alerta AHORA. Distinto de ale_usuario_atencion, que es
   quien la cerro. */
IF COL_LENGTH('dbo.Alerta', 'ale_usuario_responsable') IS NULL
BEGIN
    ALTER TABLE [dbo].[Alerta] ADD [ale_usuario_responsable] INT NULL
    PRINT '--- ale_usuario_responsable agregada.'
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ALE_RESPONSABLE')
    ALTER TABLE [dbo].[Alerta] WITH CHECK ADD CONSTRAINT [FK_ALE_RESPONSABLE]
        FOREIGN KEY ([ale_usuario_responsable]) REFERENCES [dbo].[Usuario] ([usu_id])
GO

/* Reconocer: "la vi y me hago cargo". La alerta sigue ABIERTA. */
IF COL_LENGTH('dbo.Alerta', 'ale_fecha_reconocimiento_utc') IS NULL
    ALTER TABLE [dbo].[Alerta] ADD [ale_fecha_reconocimiento_utc] DATETIME NULL
GO

IF COL_LENGTH('dbo.Alerta', 'ale_usuario_reconocimiento') IS NULL
    ALTER TABLE [dbo].[Alerta] ADD [ale_usuario_reconocimiento] INT NULL
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ALE_RECONOCIMIENTO')
    ALTER TABLE [dbo].[Alerta] WITH CHECK ADD CONSTRAINT [FK_ALE_RECONOCIMIENTO]
        FOREIGN KEY ([ale_usuario_reconocimiento]) REFERENCES [dbo].[Usuario] ([usu_id])
GO

/* Cuando empezo el trabajo de verdad. Con reconocimiento y gestion separados
   se puede medir cuanto tardo el equipo en HACERSE CARGO, que es distinto de
   cuanto tardo en resolver y es lo unico de los dos que se corrige rapido. */
IF COL_LENGTH('dbo.Alerta', 'ale_fecha_gestion_utc') IS NULL
    ALTER TABLE [dbo].[Alerta] ADD [ale_fecha_gestion_utc] DATETIME NULL
GO

/* El descarte ya tenia su motivo. La resolucion no: se cerraba sin poder
   decir que se hizo. */
IF COL_LENGTH('dbo.Alerta', 'ale_motivo_resolucion') IS NULL
    ALTER TABLE [dbo].[Alerta] ADD [ale_motivo_resolucion] NVARCHAR(1000) NULL
GO

/* La repeticion. El detector no duplica, pero tampoco dejaba rastro de que
   la condicion volvio a darse: un repuesto que cae bajo el minimo catorce
   veces se veia igual que uno que cayo una vez. */
IF COL_LENGTH('dbo.Alerta', 'ale_fecha_primera_ocurrencia_utc') IS NULL
    ALTER TABLE [dbo].[Alerta] ADD [ale_fecha_primera_ocurrencia_utc] DATETIME NULL
GO

IF COL_LENGTH('dbo.Alerta', 'ale_fecha_ultima_ocurrencia_utc') IS NULL
    ALTER TABLE [dbo].[Alerta] ADD [ale_fecha_ultima_ocurrencia_utc] DATETIME NULL
GO

IF COL_LENGTH('dbo.Alerta', 'ale_ocurrencias') IS NULL
BEGIN
    ALTER TABLE [dbo].[Alerta] ADD [ale_ocurrencias] INT NOT NULL
        CONSTRAINT DF_ALE_OCURRENCIAS DEFAULT (1)
    PRINT '--- ale_ocurrencias agregada (default 1).'
END
GO

/* Las alertas que ya existian nacieron con una sola ocurrencia: la deteccion
   con la que se crearon. Sin este relleno quedarian con las dos fechas en
   NULL y la pantalla tendria que tratar ese caso aparte para siempre. */
UPDATE [dbo].[Alerta]
   SET ale_fecha_primera_ocurrencia_utc = ISNULL(ale_fecha_primera_ocurrencia_utc, ale_fecha_deteccion_utc),
       ale_fecha_ultima_ocurrencia_utc  = ISNULL(ale_fecha_ultima_ocurrencia_utc,  ale_fecha_deteccion_utc)
 WHERE ale_fecha_primera_ocurrencia_utc IS NULL
    OR ale_fecha_ultima_ocurrencia_utc  IS NULL
GO

PRINT '--- Columnas de ciclo de vida listas.'
GO


/* ========================================================================
   2. Alerta_Historial

      Se puede saber en que estado esta una alerta; no como llego. Cada
      transicion queda con quien, cuando y por que.

      NO SE BORRA NUNCA: es la respuesta a "¿por que esto estuvo dos semanas
      sin que nadie lo tocara?", y esa pregunta siempre llega despues.
   ======================================================================== */
IF OBJECT_ID('dbo.Alerta_Historial') IS NULL
BEGIN
    CREATE TABLE [dbo].[Alerta_Historial]
    (
        [ahi_id]                    INT IDENTITY(1,1) NOT NULL,
        [ahi_alerta]                INT             NOT NULL,
        [ahi_estado_desde]          INT             NULL,
        [ahi_estado_hasta]          INT             NOT NULL,
        [ahi_usuario]               INT             NOT NULL,
        [ahi_fecha_utc]             DATETIME        NOT NULL,
        [ahi_motivo]                NVARCHAR(1000)  NULL,
        [ahi_usuario_responsable]   INT             NULL,

        CONSTRAINT [PK_ALERTA_HISTORIAL] PRIMARY KEY CLUSTERED ([ahi_id] ASC),
        CONSTRAINT [FK_AHI_ALERTA]        FOREIGN KEY ([ahi_alerta])
            REFERENCES [dbo].[Alerta] ([ale_id]),
        CONSTRAINT [FK_AHI_ESTADO_DESDE]  FOREIGN KEY ([ahi_estado_desde])
            REFERENCES [dbo].[Alerta_Estado] ([aet_id]),
        CONSTRAINT [FK_AHI_ESTADO_HASTA]  FOREIGN KEY ([ahi_estado_hasta])
            REFERENCES [dbo].[Alerta_Estado] ([aet_id]),
        CONSTRAINT [FK_AHI_USUARIO]       FOREIGN KEY ([ahi_usuario])
            REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT [FK_AHI_RESPONSABLE]   FOREIGN KEY ([ahi_usuario_responsable])
            REFERENCES [dbo].[Usuario] ([usu_id])
    )

    CREATE INDEX [IX_AHI_ALERTA] ON [dbo].[Alerta_Historial] ([ahi_alerta], [ahi_fecha_utc])

    PRINT '--- Alerta_Historial creada.'
END
ELSE PRINT '--- Alerta_Historial ya existia.'
GO


/* ========================================================================
   3. INDICE PARA LA BANDEJA

      La pantalla filtra por cliente y estado, y ordena por gravedad y
      antiguedad. El indice de hoy -IX_ALE_ABIERTA- esta filtrado a
      `ale_alerta_estado = 1`, o sea solo las NUEVAS: la pestaña "En gestion"
      no lo puede usar.
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE object_id = OBJECT_ID('dbo.Alerta') AND name = 'IX_ALE_BANDEJA')
BEGIN
    CREATE INDEX [IX_ALE_BANDEJA]
        ON [dbo].[Alerta] (ale_cliente, ale_alerta_estado, ale_habilitado)
        INCLUDE (ale_severidad, ale_fecha_deteccion_utc, ale_usuario_responsable,
                 ale_alerta_tipo, ale_titulo)
    PRINT '--- IX_ALE_BANDEJA creado.'
END
ELSE PRINT '--- IX_ALE_BANDEJA ya existia.'
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
SELECT  columna = c.name,
        tipo    = TYPE_NAME(c.user_type_id),
        nulo    = IIF(c.is_nullable = 1, 'NULL', 'NOT NULL')
FROM    sys.columns c
WHERE   c.object_id = OBJECT_ID('dbo.Alerta')
  AND   c.name IN ('ale_usuario_responsable', 'ale_fecha_reconocimiento_utc',
                   'ale_usuario_reconocimiento', 'ale_fecha_gestion_utc',
                   'ale_motivo_resolucion', 'ale_fecha_primera_ocurrencia_utc',
                   'ale_fecha_ultima_ocurrencia_utc', 'ale_ocurrencias')
ORDER BY c.column_id
GO

SELECT  alertas_con_ocurrencia = COUNT(*)
FROM    [dbo].[Alerta]
WHERE   ale_fecha_primera_ocurrencia_utc IS NOT NULL
GO

PRINT '110_ALERTA_CICLO_DE_VIDA aplicado.'
GO
