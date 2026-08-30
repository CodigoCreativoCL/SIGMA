﻿﻿﻿USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  19-08-2026
-- DESCRIPTION:     REFINAMIENTOS DE TERRENO: CICLO DE LA OT, TRABAJO EXTERNO,
--                  PERMISOS CON EVIDENCIA, HOROMETRO EN REPUESTOS Y STOCK.
-- =============================================
-- Ver SIGMA_ANEXO_H_REFINAMIENTOS_TERRENO.md
--
-- DE DONDE SALE ESTE BLOQUE
--   De la reunion con el equipo y de lo que Emilio, planificador de Hamburgo,
--   describio sobre como funciona el proceso HOY. No es diseño teorico: es
--   el proceso real, escrito por quien lo opera.
--
-- LA FRASE QUE ORDENA TODO
--   "Al final todo termina siendo una OT."
--   No hay entidad Solicitud, no hay universo paralelo de peticiones. Una
--   sola entidad, un solo ciclo de vida, un solo lugar donde mirar. Cuando
--   un tecnico detecta trabajo nuevo dentro de una OT, hay dos caminos y
--   ninguno inventa una tabla:
--     a) se resuelve en el momento -> se RETROALIMENTA la misma OT
--     b) queda para despues        -> nace otra OT con otr_ot_origen apuntando
--                                     a la que la detecto
--
-- EL CICLO REAL, EN PALABRAS DE EMILIO
--   "La OT se crea a peticion del tecnico, se realiza y se le da finalizado,
--    pero queda como en status EN ESPERA hasta que el planner o jefatura le
--    de el cierre. Ahi es donde el planner tiene la pega de cerrarlas todas."
--
--   ABIERTA -> EN EJECUCION -> EN ESPERA DE CIERRE -> CERRADA
--                              ^^^^^^^^^^^^^^^^^^^
--                              hasta aqui llega el tecnico
--
--   La frontera entre los dos ultimos estados NO es un tecnicismo: es la
--   definicion del trabajo del planificador. Contar cuantas OT estan en
--   EN ESPERA DE CIERRE es medir su carga pendiente.
--
-- TRES REGLAS QUE NO SE ROMPEN
--   1. El tecnico puede ABRIR una OT correctiva y puede FINALIZARLA, pero
--      NO puede cerrarla. Cerrar es de planificador, supervisor o jefe.
--      Se valida en el SP, no en la pantalla.
--   2. Un estado derivable no es un estado. ASIGNADA no existe: es "hay
--      fila en Orden_Trabajo_Asignacion". VALIDADA no existe: es "hay fila
--      en Orden_Trabajo_Validacion". ANULADA tampoco: anular es cerrar con
--      motivo ANULADA POR ERROR.
--   3. La fecha en que ocurrio el trabajo y la fecha en que se registro son
--      DOS datos distintos. Emilio: "por lo general en esos casos se crea la
--      ot al dia siguiente, que no es legalmente bien hecho". SIGMA no
--      esconde eso: guarda las dos y marca la diferencia.
--
-- DEPENDENCIAS
--   Requiere 04: Orden_Trabajo_Estado (4 valores), Orden_Trabajo_Cierre_Motivo,
--                Orden_Trabajo_Origen (9), Alerta_Tipo (10), Rol_Ejecucion
--   Requiere v2: Orden_Trabajo, Orden_Trabajo_Asignacion, Orden_Trabajo_Repuesto,
--                Permiso_Trabajo, Proveedor, Bodega, Repuesto, Programacion_Medidor
--
-- IDEMPOTENTE: se puede ejecutar las veces que sea.
-- =============================================


/* ========================================================================
   1. ORDEN_TRABAJO: origen, cierre y la fecha que nadie registraba

      otr_ot_origen es la traduccion literal del caso que conto Emilio:
      "revisaron un eje con una ot establecida y te das cuenta que hay que
       cambiarlo, el tecnico en la misma ot de trabajo pide otra ot".
      La OT nueva sabe de cual nacio. Sin esa FK, el historial del eje
      queda partido en dos y nadie puede reconstruir por que se cambio.
   ======================================================================== */

-- 1.1 De que OT nacio esta OT
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo]') AND name = 'otr_ot_origen')
BEGIN
    ALTER TABLE [dbo].[Orden_Trabajo] ADD [otr_ot_origen] INT NULL
    PRINT 'Columna otr_ot_origen agregada.'
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FK_OTR_OT_ORIGEN]') AND type = 'F')
    ALTER TABLE [dbo].[Orden_Trabajo]
        ADD CONSTRAINT FK_OTR_OT_ORIGEN FOREIGN KEY ([otr_ot_origen]) REFERENCES [dbo].[Orden_Trabajo] ([otr_id])
GO

-- 1.2 Cuando ocurrio el trabajo, contra cuando se registro
--     La emergencia de las 3 de la mañana se registra al dia siguiente.
--     Guardar solo la fecha de creacion seria mentir sobre cuando paso;
--     guardar solo la declarada seria no poder auditarlo. Se guardan las dos.
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo]') AND name = 'otr_fecha_ocurrencia')
BEGIN
    ALTER TABLE [dbo].[Orden_Trabajo] ADD [otr_fecha_ocurrencia] DATETIME NULL
    PRINT 'Columna otr_fecha_ocurrencia agregada.'
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo]') AND name = 'otr_registro_posterior')
BEGIN
    ALTER TABLE [dbo].[Orden_Trabajo]
        ADD [otr_registro_posterior] BIT NOT NULL CONSTRAINT DF_OTR_REGISTRO_POSTERIOR DEFAULT 0
    PRINT 'Columna otr_registro_posterior agregada.'
END
GO

-- 1.3 El cierre: quien, cuando y por que
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo]') AND name = 'otr_cierre_motivo')
BEGIN
    ALTER TABLE [dbo].[Orden_Trabajo] ADD [otr_cierre_motivo]  INT      NULL
    ALTER TABLE [dbo].[Orden_Trabajo] ADD [otr_usuario_cierre] INT      NULL
    ALTER TABLE [dbo].[Orden_Trabajo] ADD [otr_fecha_cierre]   DATETIME NULL
    PRINT 'Columnas de cierre agregadas.'
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FK_OTR_CIERRE_MOTIVO]') AND type = 'F')
BEGIN
    ALTER TABLE [dbo].[Orden_Trabajo]
        ADD CONSTRAINT FK_OTR_CIERRE_MOTIVO FOREIGN KEY ([otr_cierre_motivo]) REFERENCES [dbo].[Orden_Trabajo_Cierre_Motivo] ([ocm_id])
    ALTER TABLE [dbo].[Orden_Trabajo]
        ADD CONSTRAINT FK_OTR_USUARIO_CIERRE FOREIGN KEY ([otr_usuario_cierre]) REFERENCES [dbo].[Usuario] ([usu_id])
END
GO

-- 1.4 Una OT cerrada tiene que decir quien la cerro y por que.
--     El motor lo obliga; no depende de que la pantalla se acuerde.
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CK_OTR_CIERRE_COMPLETO]') AND type = 'C')
    ALTER TABLE [dbo].[Orden_Trabajo]
        ADD CONSTRAINT CK_OTR_CIERRE_COMPLETO CHECK
            ([otr_orden_trabajo_estado] <> 4
          OR ([otr_cierre_motivo] IS NOT NULL AND [otr_usuario_cierre] IS NOT NULL AND [otr_fecha_cierre] IS NOT NULL))
GO

-- La bandeja del planificador: lo que espera cierre, lo mas viejo primero.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OTR_ESPERA_CIERRE' AND object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo]'))
    CREATE NONCLUSTERED INDEX IX_OTR_ESPERA_CIERRE
        ON [dbo].[Orden_Trabajo] ([otr_cliente], [otr_orden_trabajo_estado], [otr_fecha_ocurrencia])
        WHERE [otr_orden_trabajo_estado] = 3
GO


/* ========================================================================
   2. ORDEN_TRABAJO_ASIGNACION: el trabajo externo

      "Cuando se asigne una OT poder indicar si es externo o no, y indicar
       la empresa. Ademas en las tareas programadas puede estar tecnico de
       planta como un externo, ya que el tecnico de planta puede ser
       ayudante de un externo."

      Por eso lo externo va en la ASIGNACION y no en la OT: en la misma OT
      conviven el externo que ejecuta y el tecnico de planta que apoya. Una
      bandera a nivel de OT no podria expresar eso.

      Y no se guarda otr_es_externo: es derivable — "existe alguna asignacion
      con proveedor". Un dato derivable que se guarda es un dato que algun
      dia va a estar desincronizado.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Asignacion]') AND name = 'ota_proveedor')
BEGIN
    ALTER TABLE [dbo].[Orden_Trabajo_Asignacion] ADD [ota_proveedor] INT NULL
    PRINT 'Columna ota_proveedor agregada.'
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Asignacion]') AND name = 'ota_asignado_por')
BEGIN
    -- Quien lo sumo al trabajo. En una actividad abierta, el tecnico que la
    -- tomo puede agregar a los que trabajaron con el, y queda registrado
    -- que fue el quien los agrego, no el planificador.
    ALTER TABLE [dbo].[Orden_Trabajo_Asignacion] ADD [ota_asignado_por] INT NULL
    PRINT 'Columna ota_asignado_por agregada.'
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FK_OTA_PROVEEDOR]') AND type = 'F')
BEGIN
    ALTER TABLE [dbo].[Orden_Trabajo_Asignacion]
        ADD CONSTRAINT FK_OTA_PROVEEDOR FOREIGN KEY ([ota_proveedor]) REFERENCES [dbo].[Proveedor] ([prv_id])
    ALTER TABLE [dbo].[Orden_Trabajo_Asignacion]
        ADD CONSTRAINT FK_OTA_ASIGNADO_POR FOREIGN KEY ([ota_asignado_por]) REFERENCES [dbo].[Usuario] ([usu_id])
END
GO

-- Una asignacion es de una persona O de una empresa externa, nunca de las dos
-- ni de ninguna. La alternativa era un par tipo/id polimorfico, que el modelo
-- rechaza en todas partes por la misma razon: pierde integridad referencial.
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CK_OTA_EJECUTANTE]') AND type = 'C')
    ALTER TABLE [dbo].[Orden_Trabajo_Asignacion]
        ADD CONSTRAINT CK_OTA_EJECUTANTE CHECK
            (([ota_usuario] IS NOT NULL AND [ota_proveedor] IS NULL)
          OR ([ota_usuario] IS NULL AND [ota_proveedor] IS NOT NULL))
GO


/* ========================================================================
   3. PERMISO_TRABAJO: la evidencia, y nada mas

      "Si es si debe adjuntarse una evidencia del permiso, puede haber mas
       de un permiso que se requiera para el trabajo."

      DECISION: no se modela al prevencionista ni sus firmas. El permiso de
      trabajo es un formulario de PREVENCION DE RIESGOS, no de mantenimiento:
      lo emite y lo firma otra area, con su propio proceso y su propio papel.
      SIGMA no lo reemplaza ni lo audita; solo guarda la prueba de que existe.

      Modelar dos firmas obligaba a que el prevencionista fuera usuario del
      sistema, a mantener su vigencia y a que alguien transcribiera desde el
      papel una firma que ya estaba en el papel. Tres problemas nuevos para
      no agregar informacion: la evidencia adjunta ya prueba lo mismo.

      Si mañana Prevencion quiere emitir permisos DENTRO de SIGMA, esto se
      amplia. Hoy no lo hacen, y modelar para un proceso que no existe es
      la forma mas cara de equivocarse.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Permiso_Trabajo]') AND name = 'ptr_archivo')
BEGIN
    ALTER TABLE [dbo].[Permiso_Trabajo] ADD [ptr_archivo] INT NULL   -- evidencia escaneada o fotografiada
    PRINT 'Columna ptr_archivo agregada.'
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FK_PTR_ARCHIVO]') AND type = 'F')
    ALTER TABLE [dbo].[Permiso_Trabajo]
        ADD CONSTRAINT FK_PTR_ARCHIVO FOREIGN KEY ([ptr_archivo]) REFERENCES [dbo].[Archivo] ([arc_id])
GO

-- Un permiso AUTORIZADO (estado 2) exige la evidencia. Autorizar sin adjuntar
-- nada es exactamente el agujero que el papel permitia.
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CK_PTR_AUTORIZADO]') AND type = 'C')
    ALTER TABLE [dbo].[Permiso_Trabajo]
        ADD CONSTRAINT CK_PTR_AUTORIZADO CHECK
            ([ptr_permiso_trabajo_estado] <> 2 OR [ptr_archivo] IS NOT NULL)
GO


/* ========================================================================
   4. ORDEN_TRABAJO_REPUESTO: el horometro al retirar y al instalar

      "Retirado con horometro, instalado con horometro. El horometro es
       opcional."

      Opcional en la captura, decisivo en el modelo: la vida util real de un
      repuesto es horometro_retiro menos horometro_instalacion de la vez
      anterior. Sin esos dos numeros, el predictivo estima vida util en dias
      calendario, que para una maquina que trabaja por turnos no significa
      nada. Es la diferencia entre "duro 8 meses" y "duro 2.900 horas".
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo_Repuesto]') AND name = 'ore_horometro_retiro')
BEGIN
    ALTER TABLE [dbo].[Orden_Trabajo_Repuesto] ADD [ore_horometro_retiro]      DECIMAL(18,2) NULL
    ALTER TABLE [dbo].[Orden_Trabajo_Repuesto] ADD [ore_horometro_instalacion] DECIMAL(18,2) NULL
    ALTER TABLE [dbo].[Orden_Trabajo_Repuesto] ADD [ore_activo_medidor]        INT           NULL
    PRINT 'Columnas de horometro agregadas a Orden_Trabajo_Repuesto.'
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FK_ORE_ACTIVO_MEDIDOR]') AND type = 'F')
    ALTER TABLE [dbo].[Orden_Trabajo_Repuesto]
        ADD CONSTRAINT FK_ORE_ACTIVO_MEDIDOR FOREIGN KEY ([ore_activo_medidor]) REFERENCES [dbo].[Activo_Medidor] ([ame_id])
GO
-- Si se declara un horometro, hay que decir de que medidor salio. Un numero
-- sin medidor no se puede comparar con nada.
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CK_ORE_HOROMETRO]') AND type = 'C')
    ALTER TABLE [dbo].[Orden_Trabajo_Repuesto]
        ADD CONSTRAINT CK_ORE_HOROMETRO CHECK
            (([ore_horometro_retiro] IS NULL AND [ore_horometro_instalacion] IS NULL)
          OR [ore_activo_medidor] IS NOT NULL)
GO


/* ========================================================================
   5. REPUESTO_BODEGA_STOCK (rbs): el trabajo del bodeguero

      "El bodeguero es quien va a registrar los repuestos en cuanto a minimo
       y maximo de stock. El no compra ni nada."

      Ese "no compra ni nada" es la definicion del perfil, y por eso el
      minimo y el maximo viven en su propia tabla y no dentro de
      Inventario_Saldo. El saldo es un HECHO que resulta de los movimientos;
      el minimo y el maximo son una DECISION de una persona. Mezclarlos haria
      que un ajuste de inventario y una decision de reposicion se vieran
      igual en la auditoria.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Repuesto_Bodega_Stock]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Repuesto_Bodega_Stock]
    (
        [rbs_id]                        INT             NOT NULL IDENTITY(1,1),
        [rbs_cliente]                   INT             NOT NULL,
        [rbs_repuesto]                  INT             NOT NULL,
        [rbs_bodega]                    INT             NOT NULL,
        [rbs_stock_minimo]              DECIMAL(18,2)   NOT NULL CONSTRAINT DF_RBS_MINIMO DEFAULT 0,
        [rbs_stock_maximo]              DECIMAL(18,2)   NULL,
        [rbs_punto_reposicion]          DECIMAL(18,2)   NULL,
        [rbs_observacion]               NVARCHAR(500)   NULL,
        [rbs_usuario_creacion]          INT             NOT NULL,
        [rbs_fecha_creacion]            DATETIME        NOT NULL CONSTRAINT DF_RBS_FECHA_CREACION DEFAULT GETDATE(),
        [rbs_usuario_actualizacion]     INT             NULL,
        [rbs_fecha_actualizacion]       DATETIME        NULL,
        [rbs_habilitado]                BIT             NOT NULL CONSTRAINT DF_RBS_HABILITADO DEFAULT 1,

        CONSTRAINT PK_REPUESTO_BODEGA_STOCK PRIMARY KEY CLUSTERED ([rbs_id] ASC),
        CONSTRAINT FK_RBS_CLIENTE  FOREIGN KEY ([rbs_cliente])  REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_RBS_REPUESTO FOREIGN KEY ([rbs_repuesto]) REFERENCES [dbo].[Repuesto] ([rep_id]),
        CONSTRAINT FK_RBS_BODEGA   FOREIGN KEY ([rbs_bodega])   REFERENCES [dbo].[Bodega] ([bod_id]),
        CONSTRAINT CK_RBS_MINIMO   CHECK ([rbs_stock_minimo] >= 0),
        CONSTRAINT CK_RBS_RANGO    CHECK ([rbs_stock_maximo] IS NULL OR [rbs_stock_maximo] >= [rbs_stock_minimo])
    )
    CREATE UNIQUE NONCLUSTERED INDEX UX_RBS_REPUESTO_BODEGA
        ON [dbo].[Repuesto_Bodega_Stock] ([rbs_repuesto], [rbs_bodega])

    PRINT 'Tabla Repuesto_Bodega_Stock creada correctamente.'
END
ELSE
    PRINT 'Tabla Repuesto_Bodega_Stock ya existe.'
GO


/* ========================================================================
   6. PROGRAMACION_MEDIDOR: avisar ANTES de que se cumpla la hora

      "Aca necesitamos que me genere alertas de proximas a las horas de
       mantenimiento."

      Una alerta que llega cuando la hora ya se cumplio no sirve: el
      planificador necesita margen para conseguir el repuesto y coordinar la
      detencion. Por eso el aviso se configura en unidades del medidor, no en
      dias: faltan 50 horas, no faltan 3 dias. Los dias dependen de cuanto
      trabaje la maquina, que es justamente lo que no se sabe de antemano.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Programacion_Medidor]') AND name = 'pme_aviso_anticipacion')
BEGIN
    ALTER TABLE [dbo].[Programacion_Medidor] ADD [pme_aviso_anticipacion] DECIMAL(18,2) NULL
    PRINT 'Columna pme_aviso_anticipacion agregada.'
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CK_PME_ANTICIPACION]') AND type = 'C')
    ALTER TABLE [dbo].[Programacion_Medidor]
        ADD CONSTRAINT CK_PME_ANTICIPACION CHECK ([pme_aviso_anticipacion] IS NULL OR [pme_aviso_anticipacion] > 0)
GO


/* ========================================================================
   7. FNC_USUARIO_PUEDE_CERRAR_OT

      La regla de Emilio, hecha codigo: "el planner debe cerrarla por temas
      de jerarquia o el supervisor, pero debe tener un cierre".

      El tecnico finaliza. Cerrar es de planificador, supervisor de
      mantenimiento o jefe de mantenimiento. Se comprueba por PERMISO y no
      por nombre de perfil: el dia que el cliente llame distinto a sus cargos,
      esto sigue funcionando.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_USUARIO_PUEDE_CERRAR_OT]
(
    @CLIENTE INT,
    @USUARIO INT
)
RETURNS BIT
AS
BEGIN
    IF [dbo].[FNC_USUARIO_TIENE_PERMISO](@CLIENTE, @USUARIO, N'CERRAR OT') = 1
        RETURN 1
    RETURN 0
END
GO


/* ========================================================================
   8. UPD_ORDEN_TRABAJO_FINALIZAR
      Lo que hace el tecnico. Deja la OT esperando cierre, no cerrada.

      El UPDATE ... WHERE estado = 2 con @@ROWCOUNT es el mismo patron de
      concurrencia que se usa en la actividad abierta: si otro ya la movio,
      esta no pisa nada y avisa.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_ORDEN_TRABAJO_FINALIZAR]
    @ORDEN_TRABAJO  INT,
    @USUARIO        INT,
    @OBSERVACION    NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON

    UPDATE [dbo].[Orden_Trabajo]
       SET otr_orden_trabajo_estado  = 3,      -- EN ESPERA DE CIERRE
           otr_usuario_actualizacion = @USUARIO,
           otr_fecha_actualizacion   = GETDATE()
     WHERE otr_id = @ORDEN_TRABAJO
       AND otr_orden_trabajo_estado IN (1, 2)  -- ABIERTA o EN EJECUCION

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('La orden de trabajo no esta abierta ni en ejecucion. Alguien mas la movio.', 16, 1)
        RETURN
    END

    INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
        ([oeh_orden_trabajo], [oeh_orden_trabajo_estado], [oeh_observacion], [oeh_usuario_creacion])
    VALUES (@ORDEN_TRABAJO, 3, @OBSERVACION, @USUARIO)

    SELECT @ORDEN_TRABAJO AS ORDEN_TRABAJO, 3 AS ESTADO, N'EN ESPERA DE CIERRE' AS ESTADO_NOMBRE
END
GO


/* ========================================================================
   9. UPD_ORDEN_TRABAJO_CERRAR
      Lo que hace el planificador, el supervisor o el jefe. Nadie mas.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_ORDEN_TRABAJO_CERRAR]
    @ORDEN_TRABAJO  INT,
    @USUARIO        INT,
    @CIERRE_MOTIVO  INT,
    @OBSERVACION    NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @CLIENTE INT
    SELECT @CLIENTE = otr_cliente FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN_TRABAJO

    IF @CLIENTE IS NULL
    BEGIN
        RAISERROR('La orden de trabajo no existe.', 16, 1)
        RETURN
    END

    -- La regla de jerarquia. El tecnico finaliza; cerrar es de otros.
    IF [dbo].[FNC_USUARIO_PUEDE_CERRAR_OT](@CLIENTE, @USUARIO) = 0
    BEGIN
        RAISERROR('Este usuario no puede cerrar ordenes de trabajo. El cierre es del planificador, el supervisor o el jefe de mantenimiento.', 16, 1)
        RETURN
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Cierre_Motivo] WHERE ocm_id = @CIERRE_MOTIVO AND ocm_habilitado = 1)
    BEGIN
        RAISERROR('El motivo de cierre no existe.', 16, 1)
        RETURN
    END

    -- Un permiso de trabajo exigido y no autorizado bloquea el cierre.
    -- Cerrar una OT cuyo permiso nunca se firmo es documentar una mentira.
    IF EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo]
                WHERE ptr_orden_trabajo = @ORDEN_TRABAJO
                  AND ptr_permiso_trabajo_estado NOT IN (2, 5))   -- AUTORIZADO o CERRADO
    BEGIN
        RAISERROR('Hay permisos de trabajo sin autorizar. No se puede cerrar la OT.', 16, 1)
        RETURN
    END

    UPDATE [dbo].[Orden_Trabajo]
       SET otr_orden_trabajo_estado  = 4,      -- CERRADA
           otr_cierre_motivo         = @CIERRE_MOTIVO,
           otr_usuario_cierre        = @USUARIO,
           otr_fecha_cierre          = GETDATE(),
           otr_usuario_actualizacion = @USUARIO,
           otr_fecha_actualizacion   = GETDATE()
     WHERE otr_id = @ORDEN_TRABAJO
       AND otr_orden_trabajo_estado = 3        -- solo desde EN ESPERA DE CIERRE

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('La OT no esta en espera de cierre. El tecnico tiene que finalizarla primero.', 16, 1)
        RETURN
    END

    INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
        ([oeh_orden_trabajo], [oeh_orden_trabajo_estado], [oeh_observacion], [oeh_usuario_creacion])
    VALUES (@ORDEN_TRABAJO, 4, @OBSERVACION, @USUARIO)

    SELECT @ORDEN_TRABAJO AS ORDEN_TRABAJO, 4 AS ESTADO, N'CERRADA' AS ESTADO_NOMBRE
END
GO


/* ========================================================================
   10. VW_PLANIFICADOR_PENDIENTE_CIERRE
       "Ahi es donde el planner tiene la pega de cerrarlas todas."
       Esta vista ES esa pega, contada.
   ======================================================================== */

CREATE OR ALTER VIEW [dbo].[VW_PLANIFICADOR_PENDIENTE_CIERRE]
AS
SELECT
    otr.otr_cliente                                     AS CLIENTE,
    otr.otr_id                                          AS ORDEN_TRABAJO,
    otr.otr_activo                                      AS ACTIVO,
    ott.ott_nombre                                      AS TIPO,
    opr.opr_nombre                                      AS PRIORIDAD,
    oto.oto_nombre                                      AS ORIGEN,
    otr.otr_ot_origen                                   AS NACIO_DE_LA_OT,
    otr.otr_fecha_ocurrencia                            AS FECHA_OCURRENCIA,
    otr.otr_registro_posterior                          AS REGISTRO_POSTERIOR,
    DATEDIFF(DAY, ISNULL(otr.otr_fecha_ocurrencia, otr.otr_fecha_creacion), GETDATE()) AS DIAS_ESPERANDO,
    CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Asignacion] ota
                       WHERE ota.ota_orden_trabajo = otr.otr_id AND ota.ota_proveedor IS NOT NULL)
         THEN 1 ELSE 0 END                              AS TIENE_TRABAJO_EXTERNO,
    CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo] ptr
                       WHERE ptr.ptr_orden_trabajo = otr.otr_id
                         AND ptr.ptr_permiso_trabajo_estado NOT IN (2, 5))
         THEN 1 ELSE 0 END                              AS BLOQUEADA_POR_PERMISO
  FROM [dbo].[Orden_Trabajo] otr
  LEFT JOIN [dbo].[Orden_Trabajo_Tipo]      ott ON ott.ott_id = otr.otr_orden_trabajo_tipo
  LEFT JOIN [dbo].[Orden_Trabajo_Prioridad] opr ON opr.opr_id = otr.otr_orden_trabajo_prioridad
  LEFT JOIN [dbo].[Orden_Trabajo_Origen]    oto ON oto.oto_id = otr.otr_orden_trabajo_origen
 WHERE otr.otr_orden_trabajo_estado = 3
GO


/* ========================================================================
   11. PERMISOS NUEVOS
       Se otorgan por perfil y, cuando hace falta, por usuario (bloque 06).
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE [prm_codigo] = 'CERRAR OT')
    INSERT INTO [dbo].[Permiso] ([prm_codigo], [prm_nombre], [prm_descripcion])
    VALUES ('CERRAR OT', 'Cerrar órdenes de trabajo',
            'Planificador, supervisor de mantenimiento y jefe de mantenimiento. El técnico finaliza, pero no cierra.')
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE [prm_codigo] = 'ADJUNTAR OT EXTERNA')
    INSERT INTO [dbo].[Permiso] ([prm_codigo], [prm_nombre], [prm_descripcion])
    VALUES ('ADJUNTAR OT EXTERNA', 'Adjuntar la OT del proveedor externo',
            'El jefe de mantenimiento adjunta el informe que la empresa externa envía por correo.')
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE [prm_codigo] = 'GESTIONAR STOCK')
    INSERT INTO [dbo].[Permiso] ([prm_codigo], [prm_nombre], [prm_descripcion])
    VALUES ('GESTIONAR STOCK', 'Definir mínimo y máximo de stock',
            'Del bodeguero. Define niveles de reposición; no compra ni autoriza compras.')
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE [prm_codigo] = 'AGREGAR COMPANERO ACTIVIDAD')
    INSERT INTO [dbo].[Permiso] ([prm_codigo], [prm_nombre], [prm_descripcion])
    VALUES ('AGREGAR COMPANERO ACTIVIDAD', 'Sumar técnicos a una actividad tomada',
            'Quien tomó la actividad abierta puede registrar con quiénes la realizó.')
GO

PRINT 'Bloque de refinamientos de terreno aplicado correctamente.'
GO
