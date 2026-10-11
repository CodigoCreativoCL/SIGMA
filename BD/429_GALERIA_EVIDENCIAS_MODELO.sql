/* ============================================================================
   429 · Galería de evidencias: revisión del modelo e índices de apoyo (10-10-2026)
   HU-142 (T-5250, T-5252) y base de HU-143 (T-5261). Autora: Catalina Pescio.

   REVISIÓN DEL MODELO (Archivo_Vinculo) — lo que no se deduce mirando la tabla
     · No hace falta tabla nueva. Archivo_Vinculo ya enlaza un archivo con la orden
       (avi_orden_trabajo) o con uno de sus pasos (avi_orden_trabajo_paso), y
       CK_AVI_UN_PADRE obliga a UN solo padre: una foto de una orden NO trae avi_activo.
       La galería de un equipo sale por Orden_Trabajo.otr_activo (orden y pasos de
       cada orden del equipo), no por avi_activo (que son las fotos de catálogo).
     · El «momento» de la foto (Antes, Durante, Después) es la categoría del ARCHIVO
       (arc_archivo_categoria 4/5/6), no del vínculo. Firma es la categoría 8 (FIRMA)
       y la galería la deja fuera, como ya hace la ficha de la orden.
     · avi_es_referencia está SOBRECARGADO: en avi_activo / avi_repuesto marca la
       PORTADA del catálogo (BD/132, 348), y la app lo deja en 0 en toda evidencia
       de terreno (BD/164). La categoría 10 (REFERENCIA) también se usó para todas
       las fotos de catálogo. Por eso, para HU-143, una imagen de referencia se
       reconoce por su DESTINO: avi_plan_mantenimiento_actividad o
       avi_checklist_plantilla_item (con avi_es_referencia = 1 por coherencia). En la
       orden llega por Orden_Trabajo_Paso.otp_plan_mantenimiento_actividad.
     · La tarea pide «confirmar el índice único del código dentro del cliente»: no
       aplica. Archivo_Vinculo no tiene código; el archivo se identifica por arc_uuid
       (UX_ARC_UUID) y el cliente vive en Archivo.arc_cliente.

   ÍNDICES (T-5252). Ya existían IX_AVI_OT, IX_AVI_ACTIVO y, en Orden_Trabajo,
   IX_OTR_ACTIVO_FECHA (sirve a la galería del equipo). Faltaban, todos filtrados:
     · IX_AVI_OT_PASO: SEL_ORDEN_TRABAJO_ARCHIVO busca los pasos con
       «avi_orden_trabajo_paso IN (...)» y hoy recorre la tabla entera.
     · IX_AVI_PAA e IX_AVI_CPI: las referencias de HU-143 por actividad del plan y
       por ítem de pauta.
   Aplicar con -I (índices filtrados). Idempotente.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Archivo_Vinculo') AND name = 'IX_AVI_OT_PASO')
    CREATE NONCLUSTERED INDEX IX_AVI_OT_PASO ON [dbo].[Archivo_Vinculo] (avi_orden_trabajo_paso)
        INCLUDE (avi_archivo, avi_orden, avi_habilitado) WHERE avi_orden_trabajo_paso IS NOT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Archivo_Vinculo') AND name = 'IX_AVI_PAA')
    CREATE NONCLUSTERED INDEX IX_AVI_PAA ON [dbo].[Archivo_Vinculo] (avi_plan_mantenimiento_actividad)
        INCLUDE (avi_archivo, avi_orden, avi_habilitado) WHERE avi_plan_mantenimiento_actividad IS NOT NULL
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Archivo_Vinculo') AND name = 'IX_AVI_CPI')
    CREATE NONCLUSTERED INDEX IX_AVI_CPI ON [dbo].[Archivo_Vinculo] (avi_checklist_plantilla_item)
        INCLUDE (avi_archivo, avi_orden, avi_habilitado) WHERE avi_checklist_plantilla_item IS NOT NULL
GO
PRINT '429_GALERIA_EVIDENCIAS_MODELO aplicado.'
GO
