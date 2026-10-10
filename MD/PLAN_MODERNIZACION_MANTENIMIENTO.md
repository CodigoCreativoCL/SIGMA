# Plan de implementación · Modernización de Mantenimiento (5 lugares)

Base: `MD/PROMPT_CLAUDE_MODERNIZACION_MANTENIMIENTO.md` (con el Anexo v3 de Catalina). Fecha: 09-10-2026. **Es un plan para aprobar; no se ha escrito código.**

## 1. Lo que ya existe (se reutiliza, no se rehace)
- `Planificacion.aspx` + `sigma-centro-planificacion.js` ya tiene las pestañas **Planes · Ejecuciones · Cumplimiento · Cobertura · Recursos** (procedimientos y calendarios), el Monitoreo (BD/389 + 392) y las acciones Generar OT / Reprogramar. Cumplimiento y Ejecuciones de planes salen de aquí hacia Operación.
- Menú Mantenimiento (padre 2154 «Centro de Mantenimiento»): visible hoy → 2222 Centro de Planificación, 2238 Inspección (#), 2223 Tareas (#), 2224 Órdenes de trabajo (#). Ya ocultas: 2155, 2161, 2213, 2233, 2235, 2232 y los detalles.
- Páginas legadas: `Checklist/*` (12), `Fallas/*` (3), `Hallazgos/ChecklistHallazgos`, `Ordenes/OrdenTrabajo(s)`, `Tareas/*` (5).
- `Orden_Trabajo_Origen` ya trae los 9 orígenes. Tablas: `Falla`, `Checklist_Hallazgo`, `Prediccion`, `Alerta`, `Checklist_Programacion/Ocurrencia/Ejecucion`, `Tarea/Tarea_Ocurrencia/Tarea_Ejecucion`.
- **La base de desarrollo tiene 0 filas** en Falla, Checklist_Hallazgo, Prediccion, Tarea_Ocurrencia y Checklist_Ocurrencia: cada parte necesita una semilla de prueba.

## 2. Decisiones de diseño
| Tema | Decisión |
|---|---|
| Contenedores | Una página por lugar con pestañas por hash (`Operacion.aspx`, `Avisos/Avisos.aspx`, `Biblioteca/Biblioteca.aspx`); Planificación sigue siendo `Planificacion.aspx`. Mismo patrón que hoy: cáscara .aspx + un JS por lugar + WS propio. |
| Código | Se reutilizan los helpers del IIFE actual (combo, calendario, paneles, escribir). Para no duplicar 270 KB, el JS común (`api`, `esc`, `ic`, `combo`, panel lateral) se extrae a `sigma-mant-comun.js`; **el generado actual se edita a mano** (los cambios de Catalina viven en él). |
| Vista de avisos | `VW_AVISOS` = UNION de Falla, Checklist_Hallazgo (inspección y OT), Prediccion y Alerta. Sin tabla nueva; el estado `sin tratar / con OT / descartado` sale de la OT vinculada y de columnas de descarte (si faltan, una tabla `Aviso_Descarte` mínima). |
| Hora | Todo con `FNC_AHORA()` (hora de planta). |
| Seguridad | Por datos (INSERT en `Menus`); cada pantalla nueva es una fila nueva con el permiso del padre; Avisos visible para quien hoy ve Fallas o Hallazgos. |
| Calidad SQL | Cada script abre con `SET ANSI_NULLS ON / QUOTED_IDENTIFIER ON` y se aplica con `-I`. |

## 3. Entrega por partes (orden propuesto)
| Parte | Qué se crea o mueve | Scripts | Prueba manual |
|---|---|---|---|
| **a · Menú y redirecciones** | 5 entradas: Operación, Órdenes de trabajo, Avisos (badge `mnu_contador`), Planificación, Recursos. Ocultar 2238, 2223 y sus hijos y Fallas/Hallazgos (`mnu_visible=0`). Las .aspx antiguas redirigen al hash nuevo. | `BD/394_MENU_MANTENIMIENTO_5_LUGARES.sql` | Cada ítem abre su lugar; marcador viejo redirige; ningún permiso se pierde. |
| **b · Avisos** | `VW_AVISOS`, `SEL_AVISOS`, `INS_AVISO_VINCULAR`, `INS_AVISO_GENERAR_OT`, `UPD_AVISO_DESCARTAR`, motivos de descarte; panel «Reportar falla» con anti-duplicado. | `BD/395_AVISOS.sql` | Criterios 1–3. |
| **c · Ficha de OT** | `OrdenTrabajo.aspx` como página: Resumen, Pasos, Repuestos, Cierre, caja «Viene de», bitácora, responsables múltiples (apoyo, Anexo v3), «¿Encontraste algo…?» (origen 9). | `BD/396_OT_FICHA.sql` | Criterios 1, 2 y 30. |
| **d · Operación** | Hoy (6 indicadores, agenda, atención requerida, SIGMA AI, tendencia), Monitoreo ampliado (inspecciones, tareas, OT), Ejecuciones unificadas (planes + inspecciones + tareas), Registrar inspección, Escalar tarea a OT, Cumplimiento por tipo, «Generar OTs pendientes». | `BD/397_OPERACION.sql` | Criterios 4–8, 31–32. |
| **e · Inspecciones, Tareas y Recursos** | Pestañas Inspecciones y Tareas en Planificación (paneles, vista previa de 5 fechas, regeneración de ocurrencias), Recursos (Pautas con versión, Calendarios, Ajustes con conteo de uso). | `BD/398_INSPECCIONES_TAREAS_BIBLIOTECA.sql` | Criterios 4, 5, 9, 33. |
| **f · Planes/Repuestos/chat** | Lo del final del prompt: repuestos compatibles en actividades, SIGMA AI Chat y SIGMA Twin en el master solo si el cliente tiene el plan contratado. | por definir | Criterios 27–29. |

Orden: a → b → c → d → e → f. Cada parte se compila (MSBuild), se prueba en el navegador con semilla y se commitea sola; la bitácora del MD se actualiza al cerrar cada una.

## 4. Riesgos y preguntas
1. **Datos de prueba:** hay que sembrar fallas, hallazgos, inspecciones y tareas en desarrollo (script `_SEMILLA_*`).
2. **`SEL_FALLA` y otros SP con `QUOTED_IDENTIFIER OFF`:** se reaplican antes de la vista.
3. **Migración de hallazgos** de `ChecklistHallazgos.aspx` al flujo de Avisos sin perder su estado actual.
4. **Descarte de avisos:** confirmar si se acepta una tabla mínima `Aviso_Descarte` (el prompt dice «sin tabla nueva si es posible»).
5. **SIGMA AI Chat / Twin por plan contratado:** falta saber dónde vive hoy la bandera de plan del cliente.
6. **Producción (Azure):** cada script nuevo debe aplicarse allí también; falta además 381–383.
