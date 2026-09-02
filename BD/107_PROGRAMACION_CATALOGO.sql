/* ============================================================================
   SIGMA — Bloque 107
   CATALOGOS DE LA FICHA DE PROGRAMACION            HU-070 · HU-071 · HU-072 · HU-074
   ----------------------------------------------------------------------------

   La ficha de programacion necesita ocho combos: tipo, frecuencia, unidad de
   tiempo, dia de la semana, zona horaria, politica de cumplimiento, operador
   de comparacion y severidad.

   Ninguno vive en la tabla `Catalogo` generica -son tablas propias con su
   FK-, asi que `SEL_CATALOGO` no los sirve. Y ocho SPs de cuatro lineas cada
   uno serian ocho archivos que nadie vuelve a mirar.

   Un solo SP con un parametro. El @CATALOGO va contra una lista blanca de
   nombres: no se concatena en un EXEC ni se arma SQL dinamico, porque un
   nombre de tabla que viene de la pantalla es exactamente por donde entra
   una inyeccion.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.SEL_PROGRAMACION_CATALOGO') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_PROGRAMACION_CATALOGO]
GO

CREATE PROCEDURE [dbo].[SEL_PROGRAMACION_CATALOGO]
    @CATALOGO   VARCHAR(40)
AS
SET NOCOUNT ON

    /* UNION de las ocho, filtrada por el nombre. El plan resuelve solo la
       rama que corresponde y no hay SQL dinamico de por medio. */
    SELECT ID, CODIGO, NOMBRE, ORDEN
      FROM (
            SELECT CAT = 'PROGRAMACION_TIPO', ID = pti_id, CODIGO = pti_codigo,
                   NOMBRE = pti_nombre, ORDEN = ISNULL(pti_orden, pti_id)
              FROM [dbo].[Programacion_Tipo] WHERE pti_habilitado = 1

            UNION ALL
            SELECT 'FRECUENCIA_TIPO', fre_id, fre_codigo, fre_nombre, fre_id
              FROM [dbo].[Frecuencia_Tipo]

            UNION ALL
            SELECT 'UNIDAD_TIEMPO', uti_id, uti_codigo, uti_nombre, uti_id
              FROM [dbo].[Unidad_Tiempo]

            UNION ALL
            SELECT 'DIA_SEMANA', dse_id, dse_codigo, dse_nombre, dse_id
              FROM [dbo].[Dia_Semana]

            UNION ALL
            SELECT 'ZONA_HORARIA', zho_id, zho_codigo, zho_nombre, zho_id
              FROM [dbo].[Zona_Horaria]

            UNION ALL
            SELECT 'CUMPLIMIENTO_POLITICA', cpo_id, cpo_codigo, cpo_nombre, cpo_id
              FROM [dbo].[Cumplimiento_Politica]

            UNION ALL
            SELECT 'OPERADOR_COMPARACION', opc_id, opc_codigo, opc_nombre, opc_id
              FROM [dbo].[Operador_Comparacion]

            UNION ALL
            SELECT 'SEVERIDAD', sev_id, sev_codigo, sev_nombre, sev_id
              FROM [dbo].[Severidad]
           ) x
     WHERE x.CAT = @CATALOGO
     ORDER BY x.ORDEN, x.NOMBRE
GO

PRINT '--- SEL_PROGRAMACION_CATALOGO creado.'
GO

/* Verificacion: las ocho tienen que devolver filas. Una vacia significa que
   falta poblar el catalogo y la ficha saldria con un combo en blanco. */
SELECT catalogo = 'PROGRAMACION_TIPO',     filas = COUNT(*) FROM [dbo].[Programacion_Tipo] WHERE pti_habilitado = 1
UNION ALL SELECT 'FRECUENCIA_TIPO',       COUNT(*) FROM [dbo].[Frecuencia_Tipo]
UNION ALL SELECT 'UNIDAD_TIEMPO',         COUNT(*) FROM [dbo].[Unidad_Tiempo]
UNION ALL SELECT 'DIA_SEMANA',            COUNT(*) FROM [dbo].[Dia_Semana]
UNION ALL SELECT 'ZONA_HORARIA',          COUNT(*) FROM [dbo].[Zona_Horaria]
UNION ALL SELECT 'CUMPLIMIENTO_POLITICA', COUNT(*) FROM [dbo].[Cumplimiento_Politica]
UNION ALL SELECT 'OPERADOR_COMPARACION',  COUNT(*) FROM [dbo].[Operador_Comparacion]
UNION ALL SELECT 'SEVERIDAD',             COUNT(*) FROM [dbo].[Severidad]
GO

PRINT '107_PROGRAMACION_CATALOGO aplicado.'
GO
