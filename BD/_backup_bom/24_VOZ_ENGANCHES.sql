﻿﻿USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  20-08-2026
-- DESCRIPTION:     ENGANCHES DE VOZ Y MODO DE ENTRADA SOBRE LAS TABLAS DE TRABAJO.
-- =============================================
-- Ver SIGMA_ANEXO_E_VOZ_INCLUSION.md
-- ORDEN: al final, junto con 10_REFINAMIENTOS_TERRENO.sql
--
-- POR QUE ESTA SEPARADO DE 07_VOZ_INCLUSION
--   07 crea Dictado_Voz y Usuario_Accesibilidad, y tiene que correr
--   TEMPRANO porque Tarea_Comentario y Bitacora le hacen FK.
--   Este archivo, en cambio, agrega columnas a Activo_Medicion,
--   Orden_Trabajo, Checklist_Ejecucion_Respuesta, Bitacora y Falla, que
--   se crean mucho despues. Un solo archivo no podia estar en los dos
--   lugares del orden a la vez.
--
-- QUE AGREGA
--   <pfx>_entrada_modo   -> TECLADO / VOZ / QR / IMPORTACION
--   <pfx>_dictado_voz    -> de que dictado salio el texto
--
-- POR QUE IMPORTA EL MODO DE ENTRADA
--   Un valor dictado y uno tecleado no tienen la misma confiabilidad, y
--   los dos alimentan al modelo predictivo. Guardar COMO entro el dato
--   permite auditar la calidad de lo que entrena al modelo -- y, si hace
--   falta, ponderarlo distinto.
--
-- IDEMPOTENTE: cada ALTER pregunta primero si la columna ya existe, y
-- ademas si la tabla existe. Correrlo en una base a medio cargar no
-- rompe: simplemente no hace nada.
-- =============================================

/* ========================================================================
   4. MODO DE ENTRADA Y ENGANCHE DEL DICTADO
      <pfx>_entrada_modo   donde el modo de captura afecta la confianza del dato
      <pfx>_dictado_voz    donde el texto puede haber nacido dictado
   ======================================================================== */

-- Activo_Medicion: un valor dictado que alimenta modelos de ML tiene que ser
-- auditable por su modo de entrada.
IF OBJECT_ID(N'[dbo].[Activo_Medicion]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Medicion]') AND name = 'amd_entrada_modo')
    ALTER TABLE [dbo].[Activo_Medicion] ADD [amd_entrada_modo] INT NULL
GO
IF OBJECT_ID(N'[dbo].[Activo_Medidor_Lectura]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Activo_Medidor_Lectura]') AND name = 'aml_entrada_modo')
    ALTER TABLE [dbo].[Activo_Medidor_Lectura] ADD [aml_entrada_modo] INT NULL
GO
IF OBJECT_ID(N'[dbo].[Checklist_Ejecucion_Respuesta]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Ejecucion_Respuesta]') AND name = 'cer_entrada_modo')
    ALTER TABLE [dbo].[Checklist_Ejecucion_Respuesta] ADD [cer_entrada_modo] INT NULL
GO
IF OBJECT_ID(N'[dbo].[Orden_Trabajo]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo]') AND name = 'otr_entrada_modo')
    ALTER TABLE [dbo].[Orden_Trabajo] ADD [otr_entrada_modo] INT NULL
GO
IF OBJECT_ID(N'[dbo].[Bitacora]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Bitacora]') AND name = 'bit_entrada_modo')
    ALTER TABLE [dbo].[Bitacora] ADD [bit_entrada_modo] INT NULL
GO

-- Enganche del dictado
IF OBJECT_ID(N'[dbo].[Orden_Trabajo]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Orden_Trabajo]') AND name = 'otr_dictado_voz')
    ALTER TABLE [dbo].[Orden_Trabajo] ADD [otr_dictado_voz] INT NULL
GO
IF OBJECT_ID(N'[dbo].[Checklist_Ejecucion_Respuesta]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Ejecucion_Respuesta]') AND name = 'cer_dictado_voz')
    ALTER TABLE [dbo].[Checklist_Ejecucion_Respuesta] ADD [cer_dictado_voz] INT NULL
GO
IF OBJECT_ID(N'[dbo].[Bitacora]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Bitacora]') AND name = 'bit_dictado_voz')
    ALTER TABLE [dbo].[Bitacora] ADD [bit_dictado_voz] INT NULL
GO
IF OBJECT_ID(N'[dbo].[Falla]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Falla]') AND name = 'fal_dictado_voz')
    ALTER TABLE [dbo].[Falla] ADD [fal_dictado_voz] INT NULL
GO

-- Pregunta hablada del checklist: si es NULL se lee cpi_pregunta.
-- Sirve cuando la pregunta escrita trae abreviaturas o unidades que se leen mal.
IF OBJECT_ID(N'[dbo].[Checklist_Plantilla_Item]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Checklist_Plantilla_Item]') AND name = 'cpi_pregunta_voz')
    ALTER TABLE [dbo].[Checklist_Plantilla_Item] ADD [cpi_pregunta_voz] NVARCHAR(500) NULL
GO


/* ========================================================================
   5. FK DIFERIDAS
      Idempotente: se re-ejecuta cuando existan las tablas de destino.
   ======================================================================== */

IF OBJECT_ID(N'[dbo].[Activo_Medicion]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_AMD_ENTRADA_MODO')
    ALTER TABLE [dbo].[Activo_Medicion] WITH CHECK ADD CONSTRAINT [FK_AMD_ENTRADA_MODO]
        FOREIGN KEY ([amd_entrada_modo]) REFERENCES [dbo].[Entrada_Modo] ([emo_id])
GO
IF OBJECT_ID(N'[dbo].[Activo_Medidor_Lectura]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_AML_ENTRADA_MODO')
    ALTER TABLE [dbo].[Activo_Medidor_Lectura] WITH CHECK ADD CONSTRAINT [FK_AML_ENTRADA_MODO]
        FOREIGN KEY ([aml_entrada_modo]) REFERENCES [dbo].[Entrada_Modo] ([emo_id])
GO
IF OBJECT_ID(N'[dbo].[Checklist_Ejecucion_Respuesta]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CER_ENTRADA_MODO')
    ALTER TABLE [dbo].[Checklist_Ejecucion_Respuesta] WITH CHECK ADD CONSTRAINT [FK_CER_ENTRADA_MODO]
        FOREIGN KEY ([cer_entrada_modo]) REFERENCES [dbo].[Entrada_Modo] ([emo_id])
GO
IF OBJECT_ID(N'[dbo].[Orden_Trabajo]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_OTR_ENTRADA_MODO')
    ALTER TABLE [dbo].[Orden_Trabajo] WITH CHECK ADD CONSTRAINT [FK_OTR_ENTRADA_MODO]
        FOREIGN KEY ([otr_entrada_modo]) REFERENCES [dbo].[Entrada_Modo] ([emo_id])
GO
IF OBJECT_ID(N'[dbo].[Bitacora]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_BIT_ENTRADA_MODO')
    ALTER TABLE [dbo].[Bitacora] WITH CHECK ADD CONSTRAINT [FK_BIT_ENTRADA_MODO]
        FOREIGN KEY ([bit_entrada_modo]) REFERENCES [dbo].[Entrada_Modo] ([emo_id])
GO

IF OBJECT_ID(N'[dbo].[Orden_Trabajo]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_OTR_DICTADO_VOZ')
    ALTER TABLE [dbo].[Orden_Trabajo] WITH CHECK ADD CONSTRAINT [FK_OTR_DICTADO_VOZ]
        FOREIGN KEY ([otr_dictado_voz]) REFERENCES [dbo].[Dictado_Voz] ([dvo_id])
GO
IF OBJECT_ID(N'[dbo].[Checklist_Ejecucion_Respuesta]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CER_DICTADO_VOZ')
    ALTER TABLE [dbo].[Checklist_Ejecucion_Respuesta] WITH CHECK ADD CONSTRAINT [FK_CER_DICTADO_VOZ]
        FOREIGN KEY ([cer_dictado_voz]) REFERENCES [dbo].[Dictado_Voz] ([dvo_id])
GO
IF OBJECT_ID(N'[dbo].[Bitacora]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_BIT_DICTADO_VOZ')
    ALTER TABLE [dbo].[Bitacora] WITH CHECK ADD CONSTRAINT [FK_BIT_DICTADO_VOZ]
        FOREIGN KEY ([bit_dictado_voz]) REFERENCES [dbo].[Dictado_Voz] ([dvo_id])
GO
IF OBJECT_ID(N'[dbo].[Falla]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FAL_DICTADO_VOZ')
    ALTER TABLE [dbo].[Falla] WITH CHECK ADD CONSTRAINT [FK_FAL_DICTADO_VOZ]
        FOREIGN KEY ([fal_dictado_voz]) REFERENCES [dbo].[Dictado_Voz] ([dvo_id])
GO

PRINT 'Bloque de voz e inclusion aplicado correctamente.'
GO
