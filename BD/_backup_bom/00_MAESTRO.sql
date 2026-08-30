﻿﻿﻿USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  20-08-2026
-- DESCRIPTION:     ORQUESTADOR: EJECUTA TODOS LOS BLOQUES EN ORDEN.
-- =============================================
--
-- COMO SE EJECUTA
--   1. Abrir este archivo en SSMS
--   2. Menu Query -> SQLCMD Mode  (SIN esto, los :r fallan)
--   3. Ajustar la ruta de $(RUTA) mas abajo
--   4. Ejecutar
--
--   Si el modo SQLCMD no esta disponible -- por ejemplo desde el panel web
--   de SmarterASP -- ejecutar los archivos a mano en el orden de la lista.
--
-- EL NUMERO DEL ARCHIVO ES UN NOMBRE, NO UN ORDEN
--   El orden real es ESTA LISTA. Los numeros se conservan porque los
--   documentos y anexos ya los referencian. Dos ejemplos de por que no
--   coinciden:
--     21_FUNDACIONES va TERCERO, no ultimo, porque Activo tiene FK a
--       Instalacion_Area y a Centro_Costo, que se crean ahi.
--     10_REFINAMIENTOS va casi al final porque son ALTER TABLE sobre
--       tablas que crean los bloques 13, 17 y 19.
--
-- EL ORDEN NO ES NEGOCIABLE
--   Cada bloque solo referencia tablas de los bloques anteriores. La
--   unica excepcion son los ciclos reales del modelo -- una medicion
--   puede nacer de una OT y una OT puede registrar mediciones -- y esos
--   se cierran al final, en 22_FK_DIFERIDAS.
--
-- TODOS LOS BLOQUES SON IDEMPOTENTES
--   Se pueden correr dos veces seguidas y la segunda no rompe nada. Eso
--   no es un lujo: es lo que permite reejecutar despues de arreglar un
--   error a mitad de camino, sin borrar la base.
--   La forma de comprobarlo es correrlo dos veces. Hacerlo.
--
-- ANTES DE EMPEZAR: 00_SANEAMIENTO
--   El bloque 00 elimina el checklist legado y las tablas que se dieron
--   de baja. Ver SIGMA_ANEXO_A_CATALOGOS_v3.md. Si la base esta vacia, no
--   hay nada que sanear y se puede saltar.
--
-- EL MODELO SON 235 TABLAS
--   210 las crean estos scripts; 25 ya existian en la base legada de SGF
--   (Usuario, Perfiles, Menus, Cliente, Paises...). Al terminar,
--   99_VERIFICACION dice exactamente cuantas hay y cuales faltan.
-- =============================================

:setvar RUTA "C:\Users\Bchavez1\OneDrive - OUTSOURCING Inc\Escritorio\PERSONAL\CAPSTONE\BD"

PRINT '========================================================'
PRINT ' SIGMA : carga completa del modelo de datos (235 tablas)'
PRINT '========================================================'
GO

-- ── 1. CATALOGOS ────────────────────────────────────────────────────────
--    73 tablas de ids fijos con su carga. Van primero SIEMPRE: todo lo
--    demas les hace FK.
PRINT ''
PRINT '--- 04 CATALOGOS (73 tablas) ---'
GO
:r $(RUTA)\04_CATALOGOS_SIGMA.sql
GO

-- ── 2. FUNDACIONES ──────────────────────────────────────────────────────
--    D1 + D14. Zona horaria, permisos finos, areas, centros de costo.
--    Va TERCERO y no ultimo: Activo tiene FK a Instalacion_Area.
PRINT ''
PRINT '--- 21 FUNDACIONES (12 tablas) ---'
GO
:r $(RUTA)\21_FUNDACIONES_RESTO.sql
GO

-- ── 3. ARCHIVOS ─────────────────────────────────────────────────────────
--    D11 sin Archivo_Vinculo. Temprano porque Dictado_Voz y
--    Suscripcion_Pago tienen FK a Archivo.
PRINT ''
PRINT '--- 18 ARCHIVOS Y ANALISIS VISUAL (5 tablas) ---'
GO
:r $(RUTA)\18_ARCHIVOS.sql
GO

-- ── 4. PERMISOS, VOZ Y MODELO COMERCIAL ─────────────────────────────────
PRINT ''
PRINT '--- 06 PERMISOS POR USUARIO (1 tabla) ---'
GO
:r $(RUTA)\06_PERMISOS_USUARIO.sql
GO

PRINT ''
PRINT '--- 07 VOZ E INCLUSION (2 tablas; los enganches van en el 24) ---'
GO
:r $(RUTA)\07_VOZ_INCLUSION.sql
GO

PRINT ''
PRINT '--- 08 SUSCRIPCION Y MODELO COMERCIAL (10 tablas) ---'
GO
:r $(RUTA)\08_SUSCRIPCION.sql
GO

-- ── 5. NUCLEO TECNICO ───────────────────────────────────────────────────
--    D2 + D3. Todo el resto del modelo cuelga de Activo.
PRINT ''
PRINT '--- 11 ACTIVOS Y MEDICIONES (15 tablas) ---'
GO
:r $(RUTA)\11_ACTIVOS_MEDICIONES.sql
GO

PRINT ''
PRINT '--- 12 REPUESTOS E INVENTARIO (8 tablas) ---'
GO
:r $(RUTA)\12_REPUESTOS_INVENTARIO.sql
GO

PRINT ''
PRINT '--- 13 MOTOR DE PROGRAMACION (9 tablas) ---'
GO
:r $(RUTA)\13_PROGRAMACION.sql
GO

-- ── 6. TERCEROS Y ALERTAS ───────────────────────────────────────────────
--    Antes de los planes: Plan_Mantenimiento_Actividad -> Procedimiento.
PRINT ''
PRINT '--- 19 TERCEROS, PROCEDIMIENTOS Y ALERTAS (5 tablas) ---'
GO
:r $(RUTA)\19_TERCEROS_ALERTAS.sql
GO

-- ── 7. EL TRABAJO ───────────────────────────────────────────────────────
--    Checklist va ANTES que planes: Plan_Actividad_Checklist tiene FK a
--    Checklist_Plantilla_Version. El checklist no depende de los planes.
PRINT ''
PRINT '--- 15 CHECKLIST DINAMICO (15 tablas) ---'
GO
:r $(RUTA)\15_CHECKLIST.sql
GO

PRINT ''
PRINT '--- 14 PLANES DE MANTENIMIENTO (10 tablas) ---'
GO
:r $(RUTA)\14_PLANES.sql
GO

PRINT ''
PRINT '--- 16 TAREAS (9 tablas) ---'
GO
:r $(RUTA)\16_TAREAS.sql
GO

PRINT ''
PRINT '--- 17 ORDENES DE TRABAJO Y FALLAS (17 tablas) ---'
GO
:r $(RUTA)\17_ORDEN_TRABAJO.sql
GO

PRINT ''
PRINT '--- 23 BITACORA (3 tablas) ---'
GO
:r $(RUTA)\23_BITACORA.sql
GO

-- ── 8. INTELIGENCIA ─────────────────────────────────────────────────────
--    D12. El motor de SIGMA Intelligence.
PRINT ''
PRINT '--- 20 MACHINE LEARNING (10 tablas) ---'
GO
:r $(RUTA)\20_MACHINE_LEARNING.sql
GO

-- ── 9. TERRENO ──────────────────────────────────────────────────────────
--    05 necesita Bitacora, OT, Checklist_Ejecucion y Tarea_Ocurrencia.
PRINT ''
PRINT '--- 05 DESCUBRIMIENTO EN TERRENO (4 tablas) ---'
GO
:r $(RUTA)\05_DESCUBRIMIENTO_TERRENO.sql
GO

--    10 son ALTER TABLE sobre tablas de los bloques 13, 17 y 19.
--    Por eso va aqui y no en su numero.
PRINT ''
PRINT '--- 10 REFINAMIENTOS DE TERRENO (1 tabla + ALTERs) ---'
GO
:r $(RUTA)\10_REFINAMIENTOS_TERRENO.sql
GO

--    24 agrega las columnas de voz y modo de entrada a Activo_Medicion,
--    Orden_Trabajo, Checklist_Ejecucion_Respuesta, Bitacora y Falla.
PRINT ''
PRINT '--- 24 ENGANCHES DE VOZ (solo ALTERs) ---'
GO
:r $(RUTA)\24_VOZ_ENGANCHES.sql
GO

-- ── 10. CIERRE DEL GRAFO ────────────────────────────────────────────────
--    Las FK que cruzan dominios hacia atras, mas Archivo_Vinculo.
PRINT ''
PRINT '--- 22 FK DIFERIDAS Y ARCHIVO_VINCULO (1 tabla + 22 FK) ---'
GO
:r $(RUTA)\22_FK_DIFERIDAS.sql
GO

-- ── 11. VERIFICACION ────────────────────────────────────────────────────
PRINT ''
PRINT '--- 99 VERIFICACION DEL ESTADO ---'
GO
:r $(RUTA)\99_VERIFICACION.sql
GO

PRINT ''
PRINT '========================================================'
PRINT ' Fin. Revisar la salida de 99_VERIFICACION:'
PRINT '   - cuadro 2: debe decir 235 de 235'
PRINT '   - cuadro 3: que falta, y que bloque lo crea'
PRINT '   - cuadro 4: catalogos creados pero VACIOS (rompen FK)'
PRINT '   - cuadro 6: FK, CHECK y PK creadas'
PRINT '========================================================'
GO
