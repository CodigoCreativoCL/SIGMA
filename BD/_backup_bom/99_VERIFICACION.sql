﻿USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  20-08-2026
-- DESCRIPTION:     VERIFICA EL ESTADO DE LA BASE CONTRA EL MODELO COMPLETO.
-- =============================================
-- No crea ni modifica nada. Se puede correr en cualquier momento y
-- responde una sola pregunta: que tablas del modelo existen y cuales no.
--
-- El modelo define 235 tablas en 15 dominios, de las cuales 48 son
-- catalogos de ids fijos.
--
-- La columna [bloque] dice QUE ARCHIVO crea cada tabla. Si una tabla
-- figura como FALTA, ese es el script que hay que ejecutar. Las que
-- dicen SGF vienen de la base legada y ya existian antes de SIGMA.
--
-- SEIS CUADROS DE SALIDA:
--   1. resumen por dominio       cuanto falta y donde
--   2. total                     una linea con el estado global
--   3. detalle de lo que falta   con el bloque que lo crea
--   4. catalogos vacios          creados pero sin filas: rompen FK
--   5. tablas fuera del modelo   estan en la base y no en el diseño
--   6. FK y constraints          cuantas hay, por si el bloque 22 fallo
-- =============================================

SET NOCOUNT ON

DECLARE @MODELO TABLE (dominio NVARCHAR(60), tabla NVARCHAR(128), prefijo NVARCHAR(3), catalogo BIT, bloque NVARCHAR(8))

-- D1 Organizacion y seguridad  (53 tablas)
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Centro_Costo', N'cco', 0, N'21')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Cliente', N'cli', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Cliente_App_Instalacion', N'cai', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Cliente_Binario', N'clb', 0, N'21')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Cliente_Instalacion', N'cin', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Cliente_Instalacion_Usuario', N'ciu', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Cliente_Usuario', N'ucl', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Cliente_Usuario_Perfil', N'cup', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Cliente_Usuario_Permiso', N'cpm', 0, N'06')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Criticidad_Nivel', N'crn', 1, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Dia_Semana', N'dse', 1, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Especialidad', N'esp', 0, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Especialidad_Nivel', N'enl', 1, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Frecuencia_Tipo', N'fre', 1, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Grupo_Trabajo', N'gtr', 0, N'21')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Grupo_Trabajo_Usuario', N'gtu', 0, N'21')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Idioma', N'idi', 0, N'21')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Instalacion_Area', N'iar', 0, N'21')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Instalacion_Area_Tipo', N'iat', 1, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Log', N'log', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Log_Estado', N'loe', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Log_Tabla', N'lot', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Magnitud', N'mag', 1, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Menu_Funcion', N'mfu', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Menu_Funcion_Perfil', N'mfp', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Menu_Perfil', N'mpe', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Menus', N'mnu', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Modulos_Sistema', N'mds', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Momento_Ejecucion', N'moe', 1, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Moneda', N'mon', 1, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Operador_Comparacion', N'opc', 1, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Paises', N'pai', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Perfil_Permiso', N'ppe', 0, N'21')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Perfiles', N'per', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Permiso', N'prm', 0, N'21')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Permiso_Ambito', N'pam', 1, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Privacidad_Modulos_Sistema', N'pms', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Proceso_Estado', N'pes', 1, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Registro_Origen', N'ror', 1, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Severidad', N'sev', 1, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Sis_Excepcion', N'lge', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Sys_Parametros', N'par', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Tipo_Dato', N'tda', 1, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Tipo_Perfil', N'tpp', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Unidad_Tiempo', N'uti', 1, N'04')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Usuario', N'usu', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Usuario_Accesibilidad', N'uac', 0, N'07')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Usuario_App_Dispositivo', N'uad', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Usuario_Especialidad', N'ues', 0, N'21')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Usuario_Foto', N'uft', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Usuario_Paises', N'upa', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Usuario_Perfil', N'upe', 0, N'SGF')
INSERT INTO @MODELO VALUES (N'D1 Organizacion y seguridad', N'Zona_Horaria', N'zho', 0, N'21')

-- D2 Activos y ubicacion  (18 tablas)
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Activo', N'act', 0, N'11')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Activo_Atributo', N'aat', 0, N'11')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Activo_Componente', N'aco', 0, N'11')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Activo_Componente_Estado', N'ace', 0, N'04')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Activo_Componente_Fusion', N'acf', 0, N'05')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Activo_Estado', N'aes', 0, N'04')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Activo_Estado_Historial', N'aeh', 0, N'11')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Activo_Fusion', N'afu', 0, N'05')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Activo_Modelo', N'amo', 0, N'11')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Activo_Posicion', N'apo', 0, N'11')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Activo_Posicion_Historial', N'aph', 0, N'11')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Activo_Posicion_Motivo', N'apm', 1, N'04')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Activo_Tipo', N'ati', 0, N'11')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Activo_Variable', N'ava', 0, N'11')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Atributo_Tecnico', N'ate', 0, N'11')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Componente_Posicion', N'cpn', 1, N'04')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Componente_Repuesto_Instalacion', N'cri', 0, N'12')
INSERT INTO @MODELO VALUES (N'D2 Activos y ubicacion', N'Componente_Tipo', N'cto', 1, N'04')

-- D3 Mediciones y medidores  (7 tablas)
INSERT INTO @MODELO VALUES (N'D3 Mediciones y medidores', N'Activo_Medicion', N'amd', 0, N'11')
INSERT INTO @MODELO VALUES (N'D3 Mediciones y medidores', N'Activo_Medidor', N'ame', 0, N'11')
INSERT INTO @MODELO VALUES (N'D3 Mediciones y medidores', N'Activo_Medidor_Lectura', N'aml', 0, N'11')
INSERT INTO @MODELO VALUES (N'D3 Mediciones y medidores', N'Dato_Origen', N'dor', 0, N'04')
INSERT INTO @MODELO VALUES (N'D3 Mediciones y medidores', N'Medicion_Calidad', N'mca', 0, N'04')
INSERT INTO @MODELO VALUES (N'D3 Mediciones y medidores', N'Unidad_Medida', N'ume', 0, N'11')
INSERT INTO @MODELO VALUES (N'D3 Mediciones y medidores', N'Variable_Medicion', N'vme', 0, N'11')

-- D4 Repuestos e inventario  (12 tablas)
INSERT INTO @MODELO VALUES (N'D4 Repuestos e inventario', N'Bodega', N'bod', 0, N'12')
INSERT INTO @MODELO VALUES (N'D4 Repuestos e inventario', N'Bodega_Ubicacion', N'bub', 0, N'12')
INSERT INTO @MODELO VALUES (N'D4 Repuestos e inventario', N'Inventario_Movimiento', N'imo', 0, N'12')
INSERT INTO @MODELO VALUES (N'D4 Repuestos e inventario', N'Inventario_Movimiento_Tipo', N'imt', 1, N'04')
INSERT INTO @MODELO VALUES (N'D4 Repuestos e inventario', N'Inventario_Saldo', N'isa', 0, N'12')
INSERT INTO @MODELO VALUES (N'D4 Repuestos e inventario', N'Repuesto', N'rep', 0, N'12')
INSERT INTO @MODELO VALUES (N'D4 Repuestos e inventario', N'Repuesto_Bodega_Stock', N'rbs', 0, N'10')
INSERT INTO @MODELO VALUES (N'D4 Repuestos e inventario', N'Repuesto_Compatibilidad', N'rco', 0, N'12')
INSERT INTO @MODELO VALUES (N'D4 Repuestos e inventario', N'Repuesto_Estado_Final', N'ref', 1, N'04')
INSERT INTO @MODELO VALUES (N'D4 Repuestos e inventario', N'Repuesto_Fusion', N'rfu', 0, N'05')
INSERT INTO @MODELO VALUES (N'D4 Repuestos e inventario', N'Repuesto_Lote', N'rlo', 0, N'12')
INSERT INTO @MODELO VALUES (N'D4 Repuestos e inventario', N'Repuesto_Retiro_Motivo', N'rrm', 1, N'04')

-- D5 Programacion  (10 tablas)
INSERT INTO @MODELO VALUES (N'D5 Programacion', N'Programacion', N'pro', 0, N'13')
INSERT INTO @MODELO VALUES (N'D5 Programacion', N'Programacion_Calendario', N'pca', 0, N'13')
INSERT INTO @MODELO VALUES (N'D5 Programacion', N'Programacion_Calendario_Dia', N'pcd', 0, N'13')
INSERT INTO @MODELO VALUES (N'D5 Programacion', N'Programacion_Condicion', N'pco', 0, N'13')
INSERT INTO @MODELO VALUES (N'D5 Programacion', N'Programacion_Exclusion', N'pxc', 0, N'13')
INSERT INTO @MODELO VALUES (N'D5 Programacion', N'Programacion_Fecha', N'pfe', 0, N'13')
INSERT INTO @MODELO VALUES (N'D5 Programacion', N'Programacion_Generacion', N'pge', 0, N'13')
INSERT INTO @MODELO VALUES (N'D5 Programacion', N'Programacion_Intervalo', N'pin', 0, N'13')
INSERT INTO @MODELO VALUES (N'D5 Programacion', N'Programacion_Medidor', N'pme', 0, N'13')
INSERT INTO @MODELO VALUES (N'D5 Programacion', N'Programacion_Tipo', N'pti', 0, N'04')

-- D6 Planes de mantenimiento  (12 tablas)
INSERT INTO @MODELO VALUES (N'D6 Planes de mantenimiento', N'Plan_Actividad_Checklist', N'pck', 0, N'14')
INSERT INTO @MODELO VALUES (N'D6 Planes de mantenimiento', N'Plan_Actividad_Especialidad', N'pae', 0, N'14')
INSERT INTO @MODELO VALUES (N'D6 Planes de mantenimiento', N'Plan_Actividad_Repuesto', N'pra', 0, N'14')
INSERT INTO @MODELO VALUES (N'D6 Planes de mantenimiento', N'Plan_Mantenimiento', N'pma', 0, N'14')
INSERT INTO @MODELO VALUES (N'D6 Planes de mantenimiento', N'Plan_Mantenimiento_Actividad', N'paa', 0, N'14')
INSERT INTO @MODELO VALUES (N'D6 Planes de mantenimiento', N'Plan_Mantenimiento_Activo', N'pac', 0, N'14')
INSERT INTO @MODELO VALUES (N'D6 Planes de mantenimiento', N'Plan_Mantenimiento_Hito', N'pmh', 0, N'14')
INSERT INTO @MODELO VALUES (N'D6 Planes de mantenimiento', N'Plan_Mantenimiento_Ocurrencia', N'pmo', 0, N'14')
INSERT INTO @MODELO VALUES (N'D6 Planes de mantenimiento', N'Plan_Mantenimiento_Version', N'pmv', 0, N'14')
INSERT INTO @MODELO VALUES (N'D6 Planes de mantenimiento', N'Plan_Ocurrencia_Estado', N'poe', 0, N'04')
INSERT INTO @MODELO VALUES (N'D6 Planes de mantenimiento', N'Plan_Ocurrencia_Historial', N'poh', 0, N'14')
INSERT INTO @MODELO VALUES (N'D6 Planes de mantenimiento', N'Plan_Version_Estado', N'pve', 0, N'04')

-- D7 Checklist dinamico  (22 tablas)
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Asignacion_Tipo', N'cat', 0, N'04')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Ejecucion', N'cej', 0, N'15')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Ejecucion_Estado', N'cee', 0, N'04')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Ejecucion_Respuesta', N'cer', 0, N'15')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Hallazgo', N'cha', 0, N'15')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Item_Dependencia', N'cid', 0, N'15')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Item_Opcion', N'cio', 0, N'15')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Item_Tipo', N'cit', 0, N'04')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Item_Validacion', N'civ', 0, N'15')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Ocurrencia', N'coc', 0, N'15')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Ocurrencia_Asignacion', N'coa', 0, N'15')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Ocurrencia_Estado', N'coe', 0, N'04')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Ocurrencia_Historial', N'coh', 0, N'15')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Plantilla', N'cpl', 0, N'15')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Plantilla_Item', N'cpi', 0, N'15')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Plantilla_Seccion', N'cps', 0, N'15')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Plantilla_Version', N'cpv', 0, N'15')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Programacion', N'cpr', 0, N'15')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Respuesta_Opcion', N'cro', 0, N'15')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Checklist_Version_Estado', N'cve', 0, N'04')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Cumplimiento_Politica', N'cpo', 1, N'04')
INSERT INTO @MODELO VALUES (N'D7 Checklist dinamico', N'Dependencia_Accion', N'dac', 1, N'04')

-- D8 Tareas  (11 tablas)
INSERT INTO @MODELO VALUES (N'D8 Tareas', N'Tarea', N'tar', 0, N'16')
INSERT INTO @MODELO VALUES (N'D8 Tareas', N'Tarea_Categoria', N'tca', 0, N'16')
INSERT INTO @MODELO VALUES (N'D8 Tareas', N'Tarea_Checklist', N'tck', 0, N'16')
INSERT INTO @MODELO VALUES (N'D8 Tareas', N'Tarea_Comentario', N'tco', 0, N'16')
INSERT INTO @MODELO VALUES (N'D8 Tareas', N'Tarea_Ejecucion', N'tej', 0, N'16')
INSERT INTO @MODELO VALUES (N'D8 Tareas', N'Tarea_Historial', N'thi', 0, N'16')
INSERT INTO @MODELO VALUES (N'D8 Tareas', N'Tarea_Ocurrencia', N'toc', 0, N'16')
INSERT INTO @MODELO VALUES (N'D8 Tareas', N'Tarea_Ocurrencia_Asignacion', N'toa', 0, N'16')
INSERT INTO @MODELO VALUES (N'D8 Tareas', N'Tarea_Ocurrencia_Estado', N'toe', 0, N'04')
INSERT INTO @MODELO VALUES (N'D8 Tareas', N'Tarea_Prioridad', N'tpa', 0, N'04')
INSERT INTO @MODELO VALUES (N'D8 Tareas', N'Tarea_Programacion', N'tpr', 0, N'16')

-- D9 Ordenes de trabajo  (27 tablas)
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Activo_Indisponibilidad', N'ain', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Falla', N'fal', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Falla_Accion', N'fac', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Falla_Causa', N'fca', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Falla_Diagnostico', N'fdi', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Falla_Modo', N'fmo', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Falla_Sintoma', N'fsi', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Indisponibilidad_Motivo', N'inm', 1, N'04')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo', N'otr', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo_Asignacion', N'ota', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo_Checklist', N'otc', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo_Cierre_Motivo', N'ocm', 0, N'04')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo_Especialidad', N'oep', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo_Estado', N'ote', 0, N'04')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo_Estado_Historial', N'oeh', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo_Estrategia', N'oet', 0, N'04')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo_Mano_Obra', N'omo', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo_Origen', N'oto', 0, N'04')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo_Paso', N'otp', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo_Prioridad', N'opr', 0, N'04')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo_Repuesto', N'ore', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo_Servicio', N'ots', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo_Tipo', N'ott', 0, N'04')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Orden_Trabajo_Validacion', N'otv', 0, N'17')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Resultado_Paso', N'rpa', 1, N'04')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Rol_Ejecucion', N'rej', 1, N'04')
INSERT INTO @MODELO VALUES (N'D9 Ordenes de trabajo', N'Validacion_Tipo', N'vat', 1, N'04')

-- D10 Bitacora  (4 tablas)
INSERT INTO @MODELO VALUES (N'D10 Bitacora', N'Bitacora', N'bit', 0, N'23')
INSERT INTO @MODELO VALUES (N'D10 Bitacora', N'Bitacora_Comentario', N'bco', 0, N'23')
INSERT INTO @MODELO VALUES (N'D10 Bitacora', N'Bitacora_Rectificacion', N'bre', 0, N'23')
INSERT INTO @MODELO VALUES (N'D10 Bitacora', N'Bitacora_Tipo', N'bti', 0, N'04')

-- D11 Evidencias y archivos  (9 tablas)
INSERT INTO @MODELO VALUES (N'D11 Evidencias y archivos', N'Analisis_Visual_Deteccion', N'avd', 0, N'18')
INSERT INTO @MODELO VALUES (N'D11 Evidencias y archivos', N'Analisis_Visual_Revision', N'avr', 0, N'18')
INSERT INTO @MODELO VALUES (N'D11 Evidencias y archivos', N'Archivo', N'arc', 0, N'18')
INSERT INTO @MODELO VALUES (N'D11 Evidencias y archivos', N'Archivo_Analisis_Visual', N'aav', 0, N'18')
INSERT INTO @MODELO VALUES (N'D11 Evidencias y archivos', N'Archivo_Antivirus_Estado', N'aae', 1, N'04')
INSERT INTO @MODELO VALUES (N'D11 Evidencias y archivos', N'Archivo_Carga', N'acg', 0, N'18')
INSERT INTO @MODELO VALUES (N'D11 Evidencias y archivos', N'Archivo_Carga_Estado', N'acs', 1, N'04')
INSERT INTO @MODELO VALUES (N'D11 Evidencias y archivos', N'Archivo_Categoria', N'aca', 0, N'04')
INSERT INTO @MODELO VALUES (N'D11 Evidencias y archivos', N'Archivo_Vinculo', N'avi', 0, N'22')

-- D12 Machine learning  (14 tablas)
INSERT INTO @MODELO VALUES (N'D12 Machine learning', N'Caracteristica_Modelo', N'cmo', 0, N'20')
INSERT INTO @MODELO VALUES (N'D12 Machine learning', N'Caracteristica_Tipo', N'ctm', 1, N'04')
INSERT INTO @MODELO VALUES (N'D12 Machine learning', N'Dataset_Entrenamiento', N'den', 0, N'20')
INSERT INTO @MODELO VALUES (N'D12 Machine learning', N'Entrenamiento_Ejecucion', N'eej', 0, N'20')
INSERT INTO @MODELO VALUES (N'D12 Machine learning', N'Modelo_Formato', N'mfo', 1, N'04')
INSERT INTO @MODELO VALUES (N'D12 Machine learning', N'Modelo_Monitoreo', N'mmo', 0, N'20')
INSERT INTO @MODELO VALUES (N'D12 Machine learning', N'Modelo_Objetivo', N'mob', 1, N'04')
INSERT INTO @MODELO VALUES (N'D12 Machine learning', N'Modelo_Predictivo', N'mpr', 0, N'20')
INSERT INTO @MODELO VALUES (N'D12 Machine learning', N'Modelo_Predictivo_Version', N'mpv', 0, N'20')
INSERT INTO @MODELO VALUES (N'D12 Machine learning', N'Prediccion', N'pre', 0, N'20')
INSERT INTO @MODELO VALUES (N'D12 Machine learning', N'Prediccion_Caracteristica', N'pcr', 0, N'20')
INSERT INTO @MODELO VALUES (N'D12 Machine learning', N'Prediccion_Estado', N'pde', 1, N'04')
INSERT INTO @MODELO VALUES (N'D12 Machine learning', N'Prediccion_Explicacion', N'pex', 0, N'20')
INSERT INTO @MODELO VALUES (N'D12 Machine learning', N'Prediccion_Resultado', N'prs', 0, N'20')

-- D13 Terceros y alertas  (11 tablas)
INSERT INTO @MODELO VALUES (N'D13 Terceros y alertas', N'Alerta', N'ale', 0, N'19')
INSERT INTO @MODELO VALUES (N'D13 Terceros y alertas', N'Alerta_Estado', N'aet', 1, N'04')
INSERT INTO @MODELO VALUES (N'D13 Terceros y alertas', N'Alerta_Tipo', N'alt', 0, N'04')
INSERT INTO @MODELO VALUES (N'D13 Terceros y alertas', N'Diagnostico_Metodo', N'dme', 1, N'04')
INSERT INTO @MODELO VALUES (N'D13 Terceros y alertas', N'Permiso_Trabajo', N'ptr', 0, N'19')
INSERT INTO @MODELO VALUES (N'D13 Terceros y alertas', N'Permiso_Trabajo_Estado', N'pte', 1, N'04')
INSERT INTO @MODELO VALUES (N'D13 Terceros y alertas', N'Permiso_Trabajo_Tipo', N'ptt', 0, N'04')
INSERT INTO @MODELO VALUES (N'D13 Terceros y alertas', N'Procedimiento', N'prc', 0, N'19')
INSERT INTO @MODELO VALUES (N'D13 Terceros y alertas', N'Procedimiento_Paso', N'ppa', 0, N'19')
INSERT INTO @MODELO VALUES (N'D13 Terceros y alertas', N'Proveedor', N'prv', 0, N'19')
INSERT INTO @MODELO VALUES (N'D13 Terceros y alertas', N'Servicio_Tipo', N'sti', 1, N'04')

-- D14 Ingesta y voz  (7 tablas)
INSERT INTO @MODELO VALUES (N'D14 Ingesta y voz', N'Dictado_Voz', N'dvo', 0, N'07')
INSERT INTO @MODELO VALUES (N'D14 Ingesta y voz', N'Entrada_Modo', N'emo', 1, N'04')
INSERT INTO @MODELO VALUES (N'D14 Ingesta y voz', N'Importacion_Carga', N'ica', 0, N'21')
INSERT INTO @MODELO VALUES (N'D14 Ingesta y voz', N'Importacion_Carga_Celda', N'icc', 0, N'21')
INSERT INTO @MODELO VALUES (N'D14 Ingesta y voz', N'Importacion_Celda_Estado', N'ice', 1, N'04')
INSERT INTO @MODELO VALUES (N'D14 Ingesta y voz', N'Importacion_Tipo', N'iti', 1, N'04')
INSERT INTO @MODELO VALUES (N'D14 Ingesta y voz', N'Registro_Descubrimiento', N'rde', 0, N'05')

-- D15 Modelo comercial  (18 tablas)
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Funcionalidad', N'fun', 1, N'04')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Funcionalidad_Tipo', N'fnt', 1, N'04')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Periodicidad_Cobro', N'pcb', 1, N'04')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Plan_Comercial', N'plc', 0, N'08')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Plan_Comercial_Funcionalidad', N'pcf', 0, N'08')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Plan_Comercial_Precio', N'pcp', 0, N'08')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Suscripcion', N'sus', 0, N'08')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Suscripcion_Bloqueo_Log', N'sbl', 0, N'08')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Suscripcion_Consumo', N'sco', 0, N'08')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Suscripcion_Estado', N'sue', 1, N'04')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Suscripcion_Key_Historial', N'skh', 0, N'08')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Suscripcion_Pago', N'spa', 0, N'08')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Suscripcion_Pago_Estado', N'spo', 1, N'04')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Suscripcion_Periodo', N'spe', 0, N'08')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Suscripcion_Periodo_Estado', N'spd', 1, N'04')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Uf_Origen', N'ufo', 1, N'04')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Valor_Uf', N'vuf', 0, N'08')
INSERT INTO @MODELO VALUES (N'D15 Modelo comercial', N'Voz_Motor', N'vmo', 1, N'04')


/* ---- 1. RESUMEN POR DOMINIO ------------------------------------------ */
SELECT
    M.[dominio],
    COUNT(*)                                                    AS [en_el_modelo],
    SUM(CASE WHEN O.object_id IS NOT NULL THEN 1 ELSE 0 END)    AS [existen],
    SUM(CASE WHEN O.object_id IS NULL     THEN 1 ELSE 0 END)    AS [faltan],
    CAST(100.0 * SUM(CASE WHEN O.object_id IS NOT NULL THEN 1 ELSE 0 END)
         / COUNT(*) AS DECIMAL(5,1))                            AS [porcentaje]
FROM @MODELO M
    LEFT JOIN sys.objects O ON O.name = M.[tabla] AND O.type = 'U'
GROUP BY M.[dominio]
ORDER BY M.[dominio]


/* ---- 2. TOTAL -------------------------------------------------------- */
SELECT
    'TOTAL SIGMA'                                               AS [concepto],
    COUNT(*)                                                    AS [en_el_modelo],
    SUM(CASE WHEN O.object_id IS NOT NULL THEN 1 ELSE 0 END)    AS [existen],
    SUM(CASE WHEN O.object_id IS NULL     THEN 1 ELSE 0 END)    AS [faltan],
    CAST(100.0 * SUM(CASE WHEN O.object_id IS NOT NULL THEN 1 ELSE 0 END)
         / COUNT(*) AS DECIMAL(5,1))                            AS [porcentaje]
FROM @MODELO M
    LEFT JOIN sys.objects O ON O.name = M.[tabla] AND O.type = 'U'


/* ---- 3. QUE FALTA, Y QUE SCRIPT LO CREA ------------------------------ */
SELECT
    M.[bloque]      AS [ejecutar_bloque],
    M.[dominio],
    M.[tabla]       AS [TABLA QUE FALTA],
    M.[prefijo],
    CASE WHEN M.[catalogo] = 1 THEN 'catalogo' ELSE '' END AS [tipo]
FROM @MODELO M
    LEFT JOIN sys.objects O ON O.name = M.[tabla] AND O.type = 'U'
WHERE O.object_id IS NULL
ORDER BY M.[bloque], M.[dominio], M.[tabla]


/* ---- 4. CATALOGOS CREADOS PERO VACIOS --------------------------------- */
/*      Un catalogo vacio es peor que uno que falta: la tabla existe, la
        FK se crea, y el primer INSERT real revienta en produccion.       */
DECLARE @VACIO TABLE (tabla NVARCHAR(128), filas INT)
DECLARE @T NVARCHAR(128), @SQL NVARCHAR(MAX), @N INT

DECLARE CUR_CAT CURSOR LOCAL FAST_FORWARD FOR
    SELECT M.[tabla] FROM @MODELO M
        INNER JOIN sys.objects O ON O.name = M.[tabla] AND O.type = 'U'
    WHERE M.[catalogo] = 1

OPEN CUR_CAT
FETCH NEXT FROM CUR_CAT INTO @T
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = N'SELECT @N = COUNT(*) FROM [dbo].[' + @T + N']'
    EXEC sp_executesql @SQL, N'@N INT OUTPUT', @N = @N OUTPUT
    IF @N = 0 INSERT INTO @VACIO VALUES (@T, 0)
    FETCH NEXT FROM CUR_CAT INTO @T
END
CLOSE CUR_CAT
DEALLOCATE CUR_CAT

SELECT [tabla] AS [CATALOGO VACIO (rompe FK)], [filas] FROM @VACIO ORDER BY [tabla]


/* ---- 5. TABLAS EN LA BASE QUE NO ESTAN EN EL MODELO ------------------- */
/*      Esperado: solo las del checklist legado si aun no se ejecuto el
        bloque 00 de saneamiento.                                         */
SELECT O.name AS [TABLA NO MODELADA]
FROM sys.objects O
WHERE O.type = 'U'
  AND O.name NOT LIKE 'sys%'
  AND O.name NOT IN (SELECT [tabla] FROM @MODELO)
ORDER BY O.name


/* ---- 6. INTEGRIDAD REFERENCIAL --------------------------------------- */
SELECT
    'Constraints en la base'                            AS [concepto],
    (SELECT COUNT(*) FROM sys.foreign_keys)             AS [foreign_key],
    (SELECT COUNT(*) FROM sys.check_constraints)        AS [check_constraint],
    (SELECT COUNT(*) FROM sys.key_constraints WHERE type = 'PK') AS [primary_key],
    (SELECT COUNT(*) FROM sys.key_constraints WHERE type = 'UQ') AS [unique_key],
    (SELECT COUNT(*) FROM sys.indexes WHERE is_primary_key = 0 AND is_unique_constraint = 0 AND type > 0) AS [indice]

/*      FK sin verificar: quedaron con WITH NOCHECK o se desactivaron.
        Deberia devolver cero filas.                                      */
SELECT name AS [FK NO VERIFICADA], OBJECT_NAME(parent_object_id) AS [tabla]
FROM sys.foreign_keys
WHERE is_not_trusted = 1 OR is_disabled = 1
ORDER BY name
GO
