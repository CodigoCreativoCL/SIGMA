/* ============================================================================
   SIGMA — Bloque 109
   DATOS DE DEMO PARA VIDA UTIL E HISTORIAL          HU-058 · HU-065  (T-3194, T-3302)
   ----------------------------------------------------------------------------

   Los numeros NO son al azar: cada fila esta puesta para que un criterio de
   aceptacion de un resultado exacto y comprobable a mano.

   HU-058 · criterio 1
     "instalado con horometro 300 y retirado con 8.712 -> 8.412 horas"
     Se siembra exactamente esa instalacion. Si el SP devuelve otra cosa, el
     criterio falla y se ve de inmediato.

   HU-058 · criterio 2
     Una instalacion SIN medidor y sin lecturas. Tiene que salir con vida util
     en dias y TIENE_HORAS en 0.

   HU-058 · criterio 3
     Dos instalaciones cerradas del MISMO repuesto -8.412 y 3.388 horas- para
     que el promedio de 5.900, el minimo 3.388 y el maximo 8.412. Mas una
     TERCERA todavia instalada, que no debe entrar en el promedio: si entrara,
     el promedio bajaria y las piezas parecerian durar menos de lo que duran.

   HU-065 · criterio 2
     Al proveedor Antuco se le cargan dos servicios en pesos (450.000 y
     280.000) y uno en UF (12,5). El total tiene que salir 730.000 CLP y 12,5
     UF POR SEPARADO. Y un cuarto servicio sin moneda declarada, para
     comprobar que no se mezcla con los pesos.

   TODO LLEVA PREFIJO DEMO- Y ES IDEMPOTENTE
     Se puede volver a ejecutar sin duplicar. Las ordenes de trabajo se crean
     directo porque su mantenedor es HU-110, del Sprint 5: aca son soporte
     para poder consultar el historial, no una implementacion de esa historia.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. INSTALACIONES DE REPUESTO                            HU-058 · T-3194
   ======================================================================== */
DECLARE @CLI INT = 1, @USU INT = 1
DECLARE @REP_ROD INT, @REP_CORREA INT, @COMP_ROD INT, @COMP_EJE INT, @MED INT

SELECT @REP_ROD    = rep_id FROM [dbo].[Repuesto] WHERE rep_cliente = @CLI AND rep_codigo = 'DEMO-ROD-6205'
SELECT @REP_CORREA = rep_id FROM [dbo].[Repuesto] WHERE rep_cliente = @CLI AND rep_codigo = 'DEMO-CORREA-A42'
SELECT @COMP_ROD   = aco_id FROM [dbo].[Activo_Componente] WHERE aco_codigo = 'ROD-01'
SELECT @COMP_EJE   = aco_id FROM [dbo].[Activo_Componente] WHERE aco_codigo = 'EJE-01'
SELECT @MED        = ame_id FROM [dbo].[Activo_Medidor] WHERE ame_codigo = 'HOROMETRO' AND ame_activo = 1

IF (@REP_ROD IS NULL OR @COMP_ROD IS NULL)
    PRINT '--- FALTAN los repuestos o componentes de demo: no se siembran instalaciones.'
ELSE IF EXISTS (SELECT 1 FROM [dbo].[Componente_Repuesto_Instalacion]
                 WHERE cri_cliente = @CLI AND cri_observacion LIKE 'DEMO-%')
    PRINT '--- Las instalaciones de demo ya existian.'
ELSE
BEGIN
    INSERT INTO [dbo].[Componente_Repuesto_Instalacion]
        (cri_cliente, cri_activo_componente, cri_repuesto, cri_activo_medidor,
         cri_cantidad, cri_fecha_instalacion_utc, cri_lectura_inicial,
         cri_fecha_retiro_utc, cri_lectura_final,
         cri_repuesto_retiro_motivo, cri_repuesto_estado_final, cri_fallo,
         cri_usuario_tecnico, cri_observacion,
         cri_usuario_creacion, cri_fecha_creacion)
    VALUES
        /* CRITERIO 1, textual: 8712 - 300 = 8412 horas. 522 dias corridos. */
        (@CLI, @COMP_ROD, @REP_ROD, @MED, 1, '2024-01-15', 300,
         '2025-06-20', 8712, 2, 4, 0, @USU,
         'DEMO-058-1 · el caso del criterio 1: 300 a 8712 son 8412 horas',
         @USU, GETDATE()),

        /* La segunda del mismo repuesto: 12100 - 8712 = 3388 horas.
           Con la anterior dan promedio 5900, minimo 3388, maximo 8412. */
        (@CLI, @COMP_ROD, @REP_ROD, @MED, 1, '2025-06-20', 8712,
         '2026-02-10', 12100, 1, 5, 1, @USU,
         'DEMO-058-2 · fallo antes de tiempo: 3388 horas',
         @USU, GETDATE()),

        /* Todavia instalada. NO debe entrar en el promedio del criterio 3. */
        (@CLI, @COMP_ROD, @REP_ROD, @MED, 1, '2026-02-10', 12100,
         NULL, NULL, NULL, NULL, 0, @USU,
         'DEMO-058-3 · sigue puesta: no tiene vida util, tiene tiempo corriendo',
         @USU, GETDATE()),

        /* CRITERIO 2: sin medidor y sin lecturas. Solo vida util en dias. */
        (@CLI, ISNULL(@COMP_EJE, @COMP_ROD), @REP_CORREA, NULL, 1,
         '2025-03-01', NULL, '2025-09-01', NULL, 2, 3, 0, @USU,
         'DEMO-058-4 · el caso del criterio 2: nadie anoto el horometro',
         @USU, GETDATE())

    PRINT '--- 4 instalaciones de demo creadas.'
END
GO


/* ========================================================================
   2. ORDENES DE TRABAJO Y SERVICIOS                       HU-065 · T-3302

      Las ordenes se crean directo: su mantenedor es HU-110, del Sprint 5.
      Aca son el soporte para poder consultar el historial, no una
      implementacion de esa historia.
   ======================================================================== */
DECLARE @CLI INT = 1, @USU INT = 1
DECLARE @INST INT, @TIPO INT, @ESTRAT INT, @ORIGEN INT, @ESTADO INT, @PRIO INT
DECLARE @CIERRE INT
DECLARE @OT1 INT, @OT2 INT, @OT3 INT
DECLARE @PRV_ANTUCO INT, @PRV_ELEBIO INT
DECLARE @ST_SERVICIO INT, @ST_MONTAJE INT, @ST_TRANSPORTE INT
DECLARE @CLP INT, @UF INT

SELECT TOP 1 @INST   = cin_id FROM [dbo].[Cliente_Instalacion] WHERE cin_cliente = @CLI ORDER BY cin_id
SELECT TOP 1 @TIPO   = ott_id FROM [dbo].[Orden_Trabajo_Tipo] ORDER BY ott_id
SELECT TOP 1 @ESTRAT = oet_id FROM [dbo].[Orden_Trabajo_Estrategia] ORDER BY oet_id
/* Origen MANUAL a proposito: los demas exigen su antecedente
   -CK_OTR_ORIGEN_COHERENTE-, y una orden nacida de un plan necesitaria la
   ocurrencia que todavia no se puede crear (HU-081, Sprint 4). */
SELECT @ORIGEN = oto_id FROM [dbo].[Orden_Trabajo_Origen] WHERE oto_codigo = 'MANUAL'

/* CERRADAS, porque un servicio facturado cuelga de trabajo terminado. Y
   cerrar exige motivo, usuario y fecha: lo pide CK_OTR_CIERRE_COMPLETO. */
SELECT @ESTADO = ote_id FROM [dbo].[Orden_Trabajo_Estado] WHERE ote_codigo = 'CERRADA'
SELECT @CIERRE = ocm_id FROM [dbo].[Orden_Trabajo_Cierre_Motivo] WHERE ocm_codigo = 'TRABAJO REALIZADO'

SELECT TOP 1 @PRIO   = opr_id FROM [dbo].[Orden_Trabajo_Prioridad] ORDER BY opr_id

SELECT @PRV_ANTUCO = prv_id FROM [dbo].[Proveedor] WHERE prv_cliente = @CLI AND prv_razon_social LIKE 'Servicios Industriales Antuco%'
SELECT @PRV_ELEBIO = prv_id FROM [dbo].[Proveedor] WHERE prv_cliente = @CLI AND prv_razon_social LIKE 'El_ctrica B_o B_o%'

SELECT @ST_SERVICIO   = sti_id FROM [dbo].[Servicio_Tipo] WHERE sti_codigo = 'SERVICIO TECNICO'
SELECT @ST_MONTAJE    = sti_id FROM [dbo].[Servicio_Tipo] WHERE sti_codigo = 'MONTAJE'
SELECT @ST_TRANSPORTE = sti_id FROM [dbo].[Servicio_Tipo] WHERE sti_codigo = 'TRANSPORTE'

SELECT @CLP = mon_id FROM [dbo].[Moneda] WHERE mon_codigo = 'CLP'
SELECT @UF  = mon_id FROM [dbo].[Moneda] WHERE mon_codigo = 'UF'

IF (@INST IS NULL OR @PRV_ANTUCO IS NULL)
    PRINT '--- FALTAN la planta o los proveedores de demo: no se siembra el historial.'
ELSE IF EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] WHERE otr_cliente = @CLI AND otr_titulo LIKE 'DEMO-%')
    PRINT '--- Las ordenes de demo ya existian.'
ELSE
BEGIN
    INSERT INTO [dbo].[Orden_Trabajo]
        (otr_cliente, otr_cliente_instalacion, otr_correlativo,
         otr_orden_trabajo_tipo, otr_orden_trabajo_estrategia,
         otr_orden_trabajo_origen, otr_orden_trabajo_estado,
         otr_orden_trabajo_prioridad, otr_usuario_generador,
         otr_titulo, otr_usuario_creacion,
         otr_cierre_motivo, otr_usuario_cierre, otr_fecha_cierre)
    VALUES (@CLI, @INST, 9001, @TIPO, @ESTRAT, @ORIGEN, @ESTADO, @PRIO, @USU,
            'DEMO-OT-9001 · Cambio de rodamientos del blower 1', @USU,
            @CIERRE, @USU, '2025-06-26')
    SET @OT1 = SCOPE_IDENTITY()

    INSERT INTO [dbo].[Orden_Trabajo]
        (otr_cliente, otr_cliente_instalacion, otr_correlativo,
         otr_orden_trabajo_tipo, otr_orden_trabajo_estrategia,
         otr_orden_trabajo_origen, otr_orden_trabajo_estado,
         otr_orden_trabajo_prioridad, otr_usuario_generador,
         otr_titulo, otr_usuario_creacion,
         otr_cierre_motivo, otr_usuario_cierre, otr_fecha_cierre)
    VALUES (@CLI, @INST, 9002, @TIPO, @ESTRAT, @ORIGEN, @ESTADO, @PRIO, @USU,
            'DEMO-OT-9002 · Montaje de la bomba de respaldo', @USU,
            @CIERRE, @USU, '2025-08-21')
    SET @OT2 = SCOPE_IDENTITY()

    INSERT INTO [dbo].[Orden_Trabajo]
        (otr_cliente, otr_cliente_instalacion, otr_correlativo,
         otr_orden_trabajo_tipo, otr_orden_trabajo_estrategia,
         otr_orden_trabajo_origen, otr_orden_trabajo_estado,
         otr_orden_trabajo_prioridad, otr_usuario_generador,
         otr_titulo, otr_usuario_creacion,
         otr_cierre_motivo, otr_usuario_cierre, otr_fecha_cierre)
    VALUES (@CLI, @INST, 9003, @TIPO, @ESTRAT, @ORIGEN, @ESTADO, @PRIO, @USU,
            'DEMO-OT-9003 · Revisión del tablero eléctrico', @USU,
            @CIERRE, @USU, '2025-11-09')
    SET @OT3 = SCOPE_IDENTITY()

    INSERT INTO [dbo].[Orden_Trabajo_Servicio]
        (ots_orden_trabajo, ots_proveedor, ots_servicio_tipo, ots_descripcion,
         ots_cantidad, ots_monto_unitario, ots_monto, ots_moneda,
         ots_documento_referencia, ots_fecha_servicio_utc, ots_fecha_documento,
         ots_usuario_creacion, ots_fecha_creacion, ots_habilitado)
    VALUES
        /* CRITERIO 2: Antuco suma 730.000 en pesos... */
        (@OT1, @PRV_ANTUCO, @ST_SERVICIO, 'Desmontaje y montaje de rodamientos',
         1, 450000, 450000, @CLP, 'F-1042', '2025-06-20', '2025-06-25', @USU, GETDATE(), 1),
        (@OT2, @PRV_ANTUCO, @ST_MONTAJE, 'Alineación láser del conjunto motor-bomba',
         1, 280000, 280000, @CLP, 'F-1078', '2025-08-14', '2025-08-20', @USU, GETDATE(), 1),

        /* ...y 12,5 UF, que NO se suman con los pesos. */
        (@OT1, @PRV_ANTUCO, @ST_SERVICIO, 'Contrato de mantenimiento trimestral',
         1, 12.5, 12.5, @UF, 'F-1099', '2025-09-30', '2025-10-05', @USU, GETDATE(), 1),

        /* Sin moneda declarada: su propio grupo, no se mezcla con los pesos. */
        (@OT3, @PRV_ANTUCO, @ST_TRANSPORTE, 'Flete de equipo a taller (sin moneda cargada)',
         1, NULL, 90000, NULL, NULL, '2025-11-03', NULL, @USU, GETDATE(), 1)

    IF (@PRV_ELEBIO IS NOT NULL)
        INSERT INTO [dbo].[Orden_Trabajo_Servicio]
            (ots_orden_trabajo, ots_proveedor, ots_servicio_tipo, ots_descripcion,
             ots_cantidad, ots_monto_unitario, ots_monto, ots_moneda,
             ots_documento_referencia, ots_fecha_servicio_utc, ots_fecha_documento,
             ots_usuario_creacion, ots_fecha_creacion, ots_habilitado)
        VALUES (@OT3, @PRV_ELEBIO, @ST_SERVICIO, 'Revisión y ajuste de protecciones',
                1, 150000, 150000, @CLP, 'F-2210', '2025-11-03', '2025-11-08', @USU, GETDATE(), 1)

    /* Se cuenta lo que quedo de verdad: el PRINT anterior decia
       "creados" aunque los INSERT hubieran sido rechazados por un
       CHECK, que es como se pierde una hora buscando el error. */
    DECLARE @OTS INT, @SRV INT
    SELECT @OTS = COUNT(*) FROM [dbo].[Orden_Trabajo] WHERE otr_titulo LIKE 'DEMO-%'
    SELECT @SRV = COUNT(*) FROM [dbo].[Orden_Trabajo_Servicio]
    PRINT '--- ordenes de demo: ' + LTRIM(STR(@OTS)) + ' · servicios: ' + LTRIM(STR(@SRV))
END
GO


/* ========================================================================
   VERIFICACION CONTRA LOS CRITERIOS
   ======================================================================== */
PRINT ''
PRINT '=== HU-058 criterios 1, 2 y 3 ==='
GO

EXEC [dbo].[SEL_REPUESTO_VIDA_UTIL] @CLIENTE = 1
GO

PRINT ''
PRINT '=== HU-065 criterios 1 y 2 ==='
GO

EXEC [dbo].[SEL_PROVEEDOR_HISTORIAL] @CLIENTE = 1
GO

PRINT '109_VIDA_UTIL_HISTORIAL_DEMO aplicado.'
GO
