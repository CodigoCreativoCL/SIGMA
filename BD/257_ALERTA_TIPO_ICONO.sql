/* ============================================================================
   SIGMA — Bloque 257
   EL ICONO DEL TIPO DE ALERTA, ESCRITO IGUAL EN LAS 15 FILAS
   ----------------------------------------------------------------------------

   El panel de la campana pinta el icono de cada fila con lo que dice
   Alerta_Tipo.alt_icono. Catorce filas traen la clase completa de Material
   («mdi mdi-gauge») y COMPARTIDO quedó con el nombre pelado
   («account-multiple-outline»), que como clase CSS no pinta nada.

   La pantalla ya normaliza las dos formas, pero el dato vale por sí mismo:
   quien mire el catálogo tiene que ver quince filas iguales, y la app va a
   leer la misma columna.
   ============================================================================ */
USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

UPDATE [dbo].[Alerta_Tipo]
SET    alt_icono = N'mdi mdi-' + LTRIM(RTRIM(alt_icono))
WHERE  alt_icono IS NOT NULL
  AND  LTRIM(RTRIM(alt_icono)) <> ''
  AND  alt_icono NOT LIKE 'mdi %'
GO

PRINT '--- Alerta_Tipo.alt_icono normalizado (bloque 257).'
GO
