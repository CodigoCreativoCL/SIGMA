# SIGMA — Centro de Planificación · Alcance funcional

> **Contrato funcional** para el diseño UI/UX del Centro de Planificación (Claude Design).
> Fecha del análisis: 07-10-2026 · Rama `BryanChavez` · BD de desarrollo `db_acd593_sigma`.

## Cómo leer este documento

| Marca | Significado |
|---|---|
| **[EXISTE]** | Comportamiento verificado en el código, en un SP o en una función de la BD. Lleva la referencia. |
| **[PROPUESTA]** | No existe hoy. Es una decisión de diseño de este documento. |
| **[ESQUEMA]** | La tabla o columna existe en la BD, pero **ningún** SP, página ni API la lee o la escribe. |

**Fuentes verificadas.** Páginas `Web/Intranet/View/Mantenimiento/**`, controladores `App_Code/MVC/SitioBase/Controller/*`, `App_Code/WebService/WsPlanificacion360.cs`, `Js/sigma-planificacion360.js`, API `Solucion/SIGMA/API/Controllers/*`. Las definiciones de los SP y funciones se leyeron de la BD con `OBJECT_DEFINITION` (212 SP y 5 funciones del dominio), no de los archivos `BD/*.sql`, que tienen versiones superpuestas. Los menús se leyeron de la tabla `Menus`. La BD de desarrollo no tiene filas de mantenimiento: el análisis es de **estructura y comportamiento**, no de volumen.

**Vocabulario.** En el código y en la BD los nombres son técnicos (hito, ocurrencia, programación). En la interfaz propuesta se usan otros nombres; la equivalencia está en §8.1. Mientras se describe lo que existe, se usan los nombres técnicos.

---

## 1. Resumen ejecutivo

### Qué hay hoy

Planificar un mantenimiento preventivo en SIGMA obliga a armar **tres entidades vivas en tres pantallas distintas**, y después a ejecutar **dos acciones manuales** que nadie hace por el usuario:

1. Una **Programación** (la regla de fechas) en *Programaciones*: un asistente de 6 pasos en un modal.
2. Un **Plan de mantenimiento** en el *Centro del plan* (`PlanMantenimiento.aspx`, se abre en otra pestaña del navegador). Ahí se cargan **hitos** (qué intervención y con qué programación), **actividades** por hito y **equipos**, cada uno en su propio modal y con un guardado por registro.
3. Un **Procedimiento** (la receta paso a paso) en *Procedimientos*, si la actividad necesita uno que todavía no existe.
4. Publicar la versión.
5. **Generar ocurrencias** a mano, en otra pestaña del plan. Publicar **no** genera nada y no existe un job nocturno.
6. **Generar la OT** a mano, ocurrencia por ocurrencia o en lote, desde la Bandeja o el Calendario. La OT nace **sin responsable**.

Un plan con una intervención, una actividad y tres equipos cuesta hoy **2 menús, 1 pestaña nueva del navegador, 6 modales y 9 guardados** (detalle en §4.3).

### Hallazgos que condicionan el diseño (verificados)

| # | Hallazgo | Dónde |
|---|---|---|
| H1 | Publicar no genera ejecuciones. Hay que generarlas a mano con un horizonte (30, 90, 180 o 365 días). `pro_genera_automaticamente` no tiene efecto, porque nadie llama a los generadores con `@SOLO_AUTOMATICAS = 1`. La pantalla dice además «Se generan al publicar la versión», y eso es **falso**. | `UPD_PLAN_VERSION_PUBLICAR`, `GEN_PLAN_OCURRENCIAS`, `PlanMantenimiento.aspx.cs` (`ResumenCalendario`) |
| H2 | La Programación es **compartida y editable en caliente**. Editarla cambia lo que genera la versión **publicada** del plan, sin versión nueva, y también las tareas y pautas que la usen. | `INS_PLAN_VERSION_NUEVA` copia `pmh_programacion` por referencia |
| H3 | Publicar una versión nueva **no limpia** las ejecuciones futuras de la versión retirada. Siguen en la Bandeja y pueden duplicar trabajo o mantener equipos que se quitaron del plan. | `UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR`, `SEL_PLAN_OCURRENCIA_BANDEJA` |
| H4 | El **«quién» no existe en el plan**. La OT generada no trae asignación. Los responsables de la Programación se guardan, pero ningún generador los usa, y `Plan_Actividad_Especialidad` no tiene pantalla. | `INS_ORDEN_TRABAJO_OCURRENCIA` |
| H5 | **Cerrar la OT desde la app no completa la ejecución del plan.** Solo lo hace el cierre web. La ejecución queda «En ejecución» y el cumplimiento sale subestimado. | `UPD_ORDEN_TRABAJO_CERRAR` (API) vs `UPD_ORDEN_TRABAJO_CERRAR_WEB` |
| H6 | La Programación pide datos que el plan **ignora**: alcance, asignación, zona horaria, «permite anticipada/atrasada» e intervalo «desde la última ejecución». | §3.4 |
| H7 | Las rondas de una pauta solo se generan desde una página **oculta del menú** (`ChecklistProgramacions.aspx`). El centro de la pauta no tiene el botón. | `Menus` (2213, `mnu_visible = 0`) |
| H8 | Las tablas para poner una pauta dentro de una actividad del plan o de una OT existen, pero **solo como esquema**. | `Plan_Actividad_Checklist`, `Orden_Trabajo_Checklist`, `Tarea_Checklist` |

### Decisión

- **El Centro de Planificación es `Planificacion.aspx` transformada.** Es la misma URL y el mismo menú (2222), convertidos en un **workspace** con cinco pestañas: **Planes · Ejecuciones · Cumplimiento · Cobertura · Biblioteca**.
- **El Plan es la unidad que el usuario administra.** Todo se configura dentro de su ficha, sin cambiar de pantalla: qué mantener, qué hacer, cómo, cuándo y quién.
- **La frecuencia se define dentro de la intervención.** El sistema crea la Programación por detrás y la deja privada para esa intervención. Las programaciones compartidas pasan a ser una opción avanzada en *Biblioteca → Calendarios*.
- **Los procedimientos se quedan como biblioteca reutilizable** dentro del Centro. Se crean y se editan en un panel lateral, sin salir del plan.
- **«Activar» = publicar + generar las ejecuciones del horizonte**, en un solo gesto. Desactivar y modificar limpian las ejecuciones futuras que todavía no tienen OT.
- **Quedan como centros especializados**, fuera del Centro: Tareas recurrentes, Pautas de inspección, Hallazgos, Fallas y Órdenes de trabajo.
- **Desaparecen como menú** Programaciones, Procedimientos y Categorías de tarea (detalle en §18).

---

## 2. Estado actual

### 2.1 Menú real (tabla `Menus`)

```text
Centro de Mantenimiento (2154)
├── Planificación (2222) ............ ~/View/Mantenimiento/Planificacion.aspx           visible
├── Programaciones (2155) ........... ~/View/Mantenimiento/Programaciones/Programaciones.aspx  visible (nivel 4 colgando del nivel 2)
├── Procedimientos (2161) ........... ~/View/Mantenimiento/Procedimientos/Procedimientos.aspx  visible
├── Inspección (2238, carpeta)
│   ├── Pautas de inspección (2180) . ~/View/Mantenimiento/Checklist/ChecklistCentro.aspx
│   └── Hallazgos de inspección (2193) ~/View/Mantenimiento/Hallazgos/ChecklistHallazgos.aspx
├── Tareas (2223, carpeta)
│   ├── Tareas recurrentes (2190) ... ~/View/Mantenimiento/Tareas/Tareas.aspx
│   └── Categorías de tarea (2218) .. ~/View/Mantenimiento/Tareas/TareaCategorias.aspx
└── Órdenes de trabajo (2224, carpeta)
    ├── Listado de órdenes (2196) ... ~/View/Mantenimiento/Ordenes/OrdenTrabajos.aspx
    └── Fallas (2199) ............... ~/View/Mantenimiento/Fallas/Fallas.aspx
```

**Ocultas** (`mnu_visible = 0`), con el permiso vigente y la URL funcionando:

| Menú | Página | Situación real |
|---|---|---|
| Planes de mantenimiento (2183) | `Planes/PlanMantenimientos.aspx` | Reemplazada por la pestaña *Planes* de Planificación. |
| Bandeja de mantenciones (2229) | `Planes/PlanOcurrenciaBandeja.aspx` | Reemplazada por la pestaña *Bandeja*; se sigue usando para exportar a Excel. |
| Plan de mantenimiento (detalle) (2184) | `Planes/PlanMantenimiento.aspx` | **Es el Centro del plan**: donde realmente se arma el plan. |
| Hito / Equipo / Actividad (2186, 2188, 2228) | `PlanHito.aspx`, `PlanActivo.aspx`, `PlanActividad.aspx` | Modales del Centro del plan. |
| Actividades del hito (2227) | `PlanActividades.aspx` | Huérfana: las actividades ya se editan dentro del hito. |
| Versiones del plan (2215) | `PlanVersion.aspx` | Huérfana: nada la abre. Las versiones viven en la pestaña Configuración. |
| Reprogramar ocurrencia (2216) | `PlanOcurrenciaReprogramar.aspx` | Modal desde Bandeja y Calendario. |
| Carga masiva de planes (2189) | `CargaMasivaPlanes.aspx` | Modal desde la pestaña Planes. |
| Programación (detalle) (2156) | `Programaciones/Programacion.aspx` | El asistente de 6 pasos (modal). |
| Programación de pautas (2213) | `Checklist/ChecklistProgramacions.aspx` | **Único lugar con «Generar ocurrencias» de pautas** (H7). |
| Programación de pauta (detalle) (2214) | `Checklist/ChecklistProgramacion.aspx` | Modal desde el centro de la pauta. |
| Tarea / Programación de tarea (2191, 2192) | `Tareas/Tarea.aspx`, `TareaProgramacion.aspx` | Centro de la tarea y su modal. |

### 2.2 Qué hace cada página (verificado)

| Página | Qué hace realmente | Entidades | SP principales | Permiso |
|---|---|---|---|---|
| **Planificación** `Planificacion.aspx` | «Planificación 360». Cabecera con planta y período; 4 KPI (requieren atención, disponibles, cumplimiento del año, carga de 4 semanas); 7 pestañas por AJAX (`WsPlanificacion360.asmx`, sin UpdatePanel ni ViewState): **Resumen** (urgencias, paradas, borradores, actividad reciente), **Bandeja** (ocurrencias abiertas por urgencia; Generar OT y Reprogramar), **Calendario** (mes/semana/día), **Planes** (versión publicada y borrador por separado; *Nuevo plan* abre otra pestaña del navegador; Carga masiva), **Programaciones** (proyección de fechas y «dónde se usa»; *Nueva programación* abre el asistente en modal), **Cumplimiento** (cohorte por fecha original), **Cobertura** (equipos sin plan). | Ocurrencia, Plan, Versión, Programación, Activo | `SEL_PLAN_OCURRENCIA_BANDEJA`, `SEL_PLANIFICACION_*`, `SEL_PLAN_CUMPLIMIENTO`, `INS_ORDEN_TRABAJO_OCURRENCIA` | 116 VER PLANES MANTENIMIENTO (pestaña Programaciones: 92) |
| **Centro del plan** `Planes/PlanMantenimiento.aspx` | Pestañas **Resumen** (KPI del año, requiere atención, alcance), **Hitos** (fila desplegable con programación, marcas y actividades; *Nuevo hito* y *Nueva actividad* abren modales), **Equipos** (tarjetas con foto; *Nuevo equipo* abre modal), **Calendario** (grilla de ocurrencias del año; **Generar OT** con selección múltiple; **Generar ocurrencias** con horizonte; Excel), **Configuración** (ficha del plan + historial de versiones con *Nueva versión* / *Publicar*). Un plan nuevo solo muestra Configuración hasta el primer guardado. | Plan, Versión, Hito, Actividad, Activo del plan, Ocurrencia | `INS/UPD_PLAN_MANTENIMIENTO`, `INS_PLAN_VERSION_NUEVA`, `UPD_PLAN_VERSION_PUBLICAR`, `GEN_PLAN_OCURRENCIAS`, `INS_ORDEN_TRABAJO_OCURRENCIA` | 116 / 117 CREAR EDITAR PLANES MANTENIMIENTO / 102 CREAR ORDEN TRABAJO |
| Hito (modal) `PlanHito.aspx` | Código, nombre, orden, descripción, **programación (combo de las existentes)**, valor de medidor y unidad, overhaul, parada, duración, tipo y prioridad de OT. Ayuda en pantalla: «¿No está? Se crea en *Programaciones*». | Hito | `INS/UPD/DEL_PLAN_HITO` | 117 |
| Actividad (modal) `PlanActividad.aspx` | Código, nombre, descripción, orden, **procedimiento (combo, solo última versión)**, duración, obligatoria, parada, permiso y tipo de permiso. **Los repuestos aparecen recién después de guardar**: hay que reabrir el modal. | Actividad, Repuesto de actividad | `INS/UPD/DEL_PLAN_ACTIVIDAD`, `INS/DEL_PLAN_ACTIVIDAD_REPUESTO` | 117 |
| Equipo (modal) `PlanActivo.aspx` | **Un equipo por vez**, con componente y medidor opcionales. El combo no filtra por el alcance del plan; el SP rechaza después. Avisa si el equipo ya está en otro plan vigente. | Activo del plan | `INS/UPD/DEL_PLAN_ACTIVO`, `SEL_PLAN_ACTIVO_COBERTURA` | 117 |
| **Programaciones** `Programaciones/Programaciones.aspx` | Listado maestro-detalle de reglas: tipo, próxima fecha, responsables, vigencia, exclusiones. Acciones *Nueva*, **Duplicar** y *Deshabilitar*. | Programación | `SEL_PROGRAMACION`, `SEL_PROGRAMACION_PROYECCION` | 92 / 93 |
| Programación (asistente) `Programacion.aspx` | 6 pasos: **Información general** (nombre único, tipo —no se cambia después de guardar—, vigencia, zona horaria), **Alcance** (planta, área, activo), **Asignación** (personas o grupo), **Frecuencia** (panel según el tipo + tolerancias, «permite anticipada/atrasada», política), **Exclusiones**, **Revisar**. Fecha única, Condición, Exclusiones y la proyección **exigen guardar primero**. | Programación y sus detalles | `INS/UPD_PROGRAMACION`, `UPS_PROGRAMACION_CALENDARIO/INTERVALO/MEDIDOR/RESPONSABLE`, `INS_PROGRAMACION_FECHA/EXCLUSION/CONDICION` | 93 |
| **Procedimientos** `Procedimientos/Procedimientos.aspx` + `Procedimiento.aspx` | Receta con pasos editados en memoria y guardados de una vez; importación desde Excel. Código + **versión escrita a mano al crear** (no hay «nueva versión»). Los globales (sin cliente) se ven, pero no se editan. | Procedimiento, Paso | `INS/UPD/DEL_PROCEDIMIENTO`, `INS/UPD/DEL_PROCEDIMIENTO_PASO`, `UPD_PROCEDIMIENTO_PASO_ORDEN` | 97 / 98 |
| **Tareas recurrentes** `Tareas/Tareas.aspx` + `Tarea.aspx` | Rutina liviana: código, título, prioridad, categoría, duración, evidencia, planta/área/equipo. Programaciones con responsable o grupo (modal `TareaProgramacion.aspx`, eligiendo una programación existente). *Generar ocurrencias* (90 días). La ejecución, la evidencia y los comentarios llegan por la app. **No genera OT.** | Tarea, Tarea_Programacion, Tarea_Ocurrencia, Tarea_Ejecucion | `GEN_TAREA_OCURRENCIAS`, `API_UPS_TAREA_EJECUCION` | 118 / 119 |
| Categorías de tarea | Catálogo: código, nombre, color, orden. | Tarea_Categoria | `*_TAREA_CATEGORIA` | — |
| **Pautas de inspección** `Checklist/ChecklistCentro.aspx` | Centro de la pauta: Resumen, Configuración, Estructura, Versiones, Programaciones (pauta + programación + activo o área + responsable o grupo), Ocurrencias y ejecuciones, Hallazgos. | Checklist_* | `INS_CHECKLIST_PROGRAMACION`, `GEN_CHECKLIST_OCURRENCIAS` (solo desde la página oculta) | 114 / 115 |
| **Hallazgos** `Hallazgos/ChecklistHallazgos.aspx` | Bandeja de hallazgos: generar OT correctiva o descartar con motivo (≥ 10 caracteres). | Checklist_Hallazgo | `INS_ORDEN_TRABAJO_HALLAZGO`, `UPD_CHECKLIST_HALLAZGO_DESCARTAR` | 120 |
| **Órdenes de trabajo** `Ordenes/OrdenTrabajos.aspx` + `OrdenTrabajo.aspx` | Listado (filtros: texto, tipo, planta, estado; **sin filtro por plan**) y centro de la OT: resumen, ficha, asignación, pasos (se pueden **agregar pasos de un procedimiento**), evidencias, indisponibilidad, cierre. | Orden_Trabajo y anexas | `INS_ORDEN_TRABAJO`, `INS_ORDEN_TRABAJO_PASO_PROCEDIMIENTO`, `UPD_ORDEN_TRABAJO_CERRAR_WEB` | 101 / 102 |
| **Fallas** `Fallas/Fallas.aspx` + `Falla.aspx` | Centro de la falla: ficha, diagnósticos, acciones, indisponibilidad. *Generar orden correctiva* → `INS_ORDEN_TRABAJO` con la falla (origen FALLA). | Falla y anexas | `INS_FALLA`, `INS_ORDEN_TRABAJO` | 123 |

### 2.3 Qué datos se crean, modifican y generan

| Acción del usuario | Escribe | Genera automáticamente |
|---|---|---|
| Guardar un plan nuevo | `Plan_Mantenimiento` + **versión 1 en borrador** (`INS_PLAN_MANTENIMIENTO`) | Código automático con prefijo |
| Guardar hito / actividad / equipo | `Plan_Mantenimiento_Hito` / `_Actividad` / `_Activo`, **solo sobre el borrador** | — |
| Publicar | Cambia el estado: la versión pasa a PUBLICADO y la anterior a RETIRADO | **Nada más.** No genera ocurrencias. |
| Nueva versión | Copia la vigente (hitos, actividades, equipos) a un borrador nuevo (`INS_PLAN_VERSION_NUEVA`) | — |
| Generar ocurrencias (botón) | `Plan_Mantenimiento_Ocurrencia` (hito × equipo × fecha), `Programacion_Generacion` | Fecha disponible y fecha límite desde las tolerancias de la programación |
| Registrar una lectura de medidor o una medición (app/API) | — | `GEN_PLAN_OCURRENCIAS_MEDIDOR` / `_CONDICION`: **la única generación automática que existe**, y solo para planes |
| Generar OT | `Orden_Trabajo`, `Orden_Trabajo_Paso`, `Orden_Trabajo_Repuesto`, historiales | La ocurrencia pasa a EN EJECUCIÓN |
| Reprogramar | La ocurrencia vieja pasa a REPROGRAMADA y nace otra en la fecha nueva | La ventana se corre con la fecha; la fecha original se conserva |
| Cerrar OT (web) | `Orden_Trabajo` estado CERRADA | La ocurrencia queda COMPLETADA (motivos 1 y 2) u OMITIDA (los demás) |
| Cerrar OT (app) | `Orden_Trabajo` estado CERRADA | **Nada sobre la ocurrencia** (H5) |

---

## 3. Arquitectura funcional actual

### 3.1 Modelo real

```text
Plan_Mantenimiento ─────────────── ficha + ALCANCE (planta?, tipo de activo?, modelo?) + planificador (solo informativo)
 └─ Plan_Mantenimiento_Version ── BORRADOR (máx. 1) · PUBLICADO (máx. 1, «la que manda») · RETIRADO
     ├─ Plan_Mantenimiento_Hito ── «qué intervención y cada cuánto»
     │    ├─ → Programacion (FK obligatoria, COMPARTIDA)
     │    ├─ overhaul, parada, duración, tipo y prioridad de la OT, descripción
     │    ├─ valor de medidor + unidad ......................... (informativo: no lo usa la generación)
     │    └─ Plan_Mantenimiento_Actividad ── «qué se hace» (pasos de la OT)
     │         ├─ → Procedimiento? (sus pasos se COPIAN a la OT al generarla)
     │         ├─ obligatoria, parada, permiso de trabajo + tipo, duración
     │         ├─ Plan_Actividad_Repuesto ── repuestos planificados
     │         ├─ Plan_Actividad_Especialidad ............... [ESQUEMA] (solo se lee: «personas» = 0)
     │         └─ Plan_Actividad_Checklist .................. [ESQUEMA]
     └─ Plan_Mantenimiento_Activo ── equipo (+ componente?, + medidor?) validado contra el alcance

Plan_Mantenimiento_Ocurrencia ── hito × equipo × fecha (y programación) · estado · OT · cadena de reprogramación
 └─ → Orden_Trabajo (1:1, idempotente)

Programacion ── tipo + vigencia + tolerancias + exclusiones (+ metadatos que el plan ignora, ver §3.4)
 ├─ usada por Plan_Mantenimiento_Hito
 ├─ usada por Tarea_Programacion (tarea + responsable o grupo)
 └─ usada por Checklist_Programacion (pauta + activo o área + responsable o grupo)

Procedimiento (código + versión) └─ Procedimiento_Paso (instrucción, punto de control, evidencia, medición + variable)
 ├─ usado por Plan_Mantenimiento_Actividad
 └─ usado por Orden_Trabajo (se agregan sus pasos a una OT abierta)
```

### 3.2 Las tres cadenas de trabajo programado que conviven hoy

| Cadena | Unidad | Programación | Genera | Termina en | Ejecución |
|---|---|---|---|---|---|
| **Plan preventivo** | Plan → versión → hito × equipo | Programación por hito | `Plan_Mantenimiento_Ocurrencia` (manual; automático solo por medidor o condición) | **OT** (manual) | App y web sobre la OT |
| **Tarea recurrente** | Tarea (+ planta/área/equipo opcional) | N programaciones por tarea, cada una con responsable o grupo | `Tarea_Ocurrencia` (manual, 90 días) | Ejecución de la tarea (sin OT) | App (`API_UPS_TAREA_EJECUCION`) |
| **Pauta de inspección** | Pauta (versionada) × activo o área | `Checklist_Programacion` | `Checklist_Ocurrencia` + asignación (manual, desde página oculta) | Ejecución de checklist → **hallazgo** → OT correctiva (manual) | App (`API_INS_CHECKLIST_EJECUCION`, `API_UPS_CHECKLIST_RESPUESTA`) |

Y dos cadenas **reactivas** que terminan en OT: **Falla → OT correctiva** (origen 7) y **Hallazgo → OT correctiva** (origen 4). Además existen orígenes de OT desde predicción (5) y desde alerta (6).

> El catálogo `Orden_Trabajo_Origen` incluye **TAREA (3)**, y las columnas `otr_tarea_ocurrencia` y `toc_orden_trabajo` existen, pero **ningún SP las escribe**. Una tarea recurrente **no** produce OT.

### 3.3 Estados y cómo se calculan

**Versión del plan** (`Plan_Version_Estado`): 1 BORRADOR · 2 PUBLICADO · 3 RETIRADO.

**Ocurrencia** (`Plan_Ocurrencia_Estado`): 1 PENDIENTE · 2 DISPONIBLE · 3 EN EJECUCIÓN · 4 COMPLETADA · 5 OMITIDA · 6 CANCELADA · 7 REPROGRAMADA.

**Situación** (calculada en `SEL_PLAN_OCURRENCIA_BANDEJA`, no guardada):

| Situación | Regla |
|---|---|
| CERRADA | estado 4, 5, 6 o 7 |
| VENCIDA | fecha límite < ahora |
| ATRASADA | fecha programada < ahora (dentro de la tolerancia) |
| DISPONIBLE | fecha disponible ≤ ahora |
| FUTURA | el resto |

Orden de la Bandeja: Vencida → Atrasada → Disponible → Futura, luego por fecha y fecha límite.

**OT** (`Orden_Trabajo_Estado`): 1 ABIERTA · 2 EN EJECUCIÓN · 3 EN ESPERA DE CIERRE (el técnico finaliza) · 4 CERRADA (planificador, supervisor o jefe).

### 3.4 Qué campos de la Programación usa cada generador (hallazgo H6)

| Campo de `Programacion` | Planes | Tareas | Pautas | Conclusión |
|---|---|---|---|---|
| Tipo + regla (fechas, calendario, intervalo) | Sí (`FNC_PROGRAMACION_FECHAS`) | Sí | Sí | Núcleo |
| Medidor (`Programacion_Medidor`) | Sí, al registrar la lectura (`GEN_PLAN_OCURRENCIAS_MEDIDOR`) | **No genera** | **No genera** | Solo planes |
| Condición (`Programacion_Condicion` + política) | Sí, al registrar la medición (`GEN_PLAN_OCURRENCIAS_CONDICION`) | **No genera** | **No genera** | Solo planes |
| Abierta | No genera nada | No | No | Sin uso en un plan |
| Vigencia inicio/fin | Sí | Sí | Sí | Núcleo |
| Tolerancias antes/después | Sí → fecha disponible y fecha límite | Sí | Sí | Núcleo |
| Exclusiones (omite o desplaza) | Sí | Sí | Sí | Núcleo |
| `pro_genera_automaticamente` | Solo con `@SOLO_AUTOMATICAS = 1`, que **nadie invoca** | Ídem | No | **Sin efecto** |
| Alcance (planta/área/activo) | **No** (el plan usa sus equipos) | No | No | Decorativo |
| Responsables / grupo | **No** | No (la tarea usa `tpr_usuario_responsable`) | No (la pauta usa `cpr_usuario_responsable`) | Decorativo |
| Zona horaria | **No** (el plan usa la hora de la planta de cada equipo: `FNC_INSTALACION_HORA`) | No (usa la fecha UTC) | No | Decorativo |
| Permite anticipada / atrasada | **No** | No | No | Decorativo |
| Intervalo «desde la última ejecución» (`pin_desde_ejecucion`) | **No**: el intervalo siempre cuenta desde el ancla | No | No | Decorativo |

En el hito, además, `pmh_valor_medidor` y `pmh_unidad_medida` **no se usan** al generar: la generación por medidor usa `pme_cada_cantidad` de la programación (`FNC_PLAN_MEDIDOR_ESTADO`).

### 3.5 Dependencias

| Entre | Dependencia real |
|---|---|
| Plan → Programación | Cada hito **exige** una programación existente (FK `pmh_programacion NOT NULL`). Una programación usada por hitos no se puede deshabilitar (`DEL_PROGRAMACION`), aunque sí se puede **editar**. |
| Plan → Procedimiento | Opcional, por actividad (`paa_procedimiento`). Solo de **este cliente**: los globales no se aceptan (`INS_PLAN_ACTIVIDAD` exige `prc_cliente = @CLIENTE`). Apunta a una **versión concreta** (un `prc_id`). |
| Plan → Tareas | **Ninguna**. Solo comparten el concepto de programación. |
| Plan → Pautas | **Ninguna implementada**. `Plan_Actividad_Checklist` es solo esquema. |
| Plan → Activo | Por versión (`Plan_Mantenimiento_Activo`). El alcance (planta, tipo, modelo) **sí** se hace cumplir (`INS_PLAN_ACTIVO`). |
| Ocurrencia → OT | 1:1. `INS_ORDEN_TRABAJO_OCURRENCIA` es idempotente: devuelve la existente. |
| OT → Ocurrencia | El cierre web completa u omite la ocurrencia. El cierre desde la app no la toca. |

### 3.6 Qué genera finalmente una Orden de Trabajo

| Origen | Cómo | Automático |
|---|---|---|
| Ocurrencia de plan | *Generar OT* (Centro del plan → Calendario; Planificación → Bandeja o Calendario) → `INS_ORDEN_TRABAJO_OCURRENCIA` | **No** |
| Hallazgo de pauta | Bandeja de hallazgos → `INS_ORDEN_TRABAJO_HALLAZGO` | No |
| Falla | Centro de la falla → `INS_ORDEN_TRABAJO` con `@FALLA` | No |
| Manual | Nueva OT → `INS_ORDEN_TRABAJO` | — |
| Predicción / Alerta | SIGMA AI / Notificaciones | No |

**Lo que copia la OT de una ocurrencia** [EXISTE, `INS_ORDEN_TRABAJO_OCURRENCIA`]:

- **Tipo**: el del hito o PREVENTIVA. **Estrategia**: PROGRAMADO, u OVERHAUL si el hito lo es. **Origen**: PLAN. **Estado**: ABIERTA. **Prioridad**: la del hito o MEDIA.
- **Título**: «hito · código y nombre del equipo». **Descripción**: la del hito + «Generada desde el plan X vN, hito H, programada para el dd/mm/aaaa» + «REQUIERE PARADA» si corresponde.
- **Fecha programada** = la de la ocurrencia. **Duración estimada** = la del hito (no la suma de las actividades). **Minutos de parada** = la duración, si el hito exige parada.
- **Requiere permiso** si alguna actividad lo exige.
- **Pasos**: uno por actividad. Si la actividad tiene procedimiento, un paso por cada paso del procedimiento, con el texto **copiado** (nombre «Actividad · n. paso»). Un punto de control es obligatorio. Si el hito no tiene actividades, el hito mismo es el único paso.
- **Repuestos**: la suma de los planificados en las actividades, por repuesto.
- **Asignación**: **ninguna** (H4).

---

## 4. Flujo actual

### 4.1 Lo que el prompt suponía y lo que realmente pasa

| Paso supuesto | ¿Ocurre? | Realidad |
|---|---|---|
| Crear planificación → Guardar | Sí | Se crea en el Centro del plan. Guardar crea la **versión 1 en borrador** y recarga la página. |
| Crear programación | Sí, **antes** y **en otra pantalla** | Es la frecuencia, y vive fuera del plan. |
| Configurar frecuencia | Sí | Dentro de la programación (paso 4 del asistente). |
| Asociar activo | Sí | Por versión, un equipo por modal. |
| Crear procedimiento | Opcional, **en otra pantalla** | Solo si la actividad necesita uno que no existe. |
| Crear tareas | Sí, como **actividades del hito** | No son las «Tareas recurrentes». |
| Asociar procedimiento | Sí | Combo dentro de la actividad. |
| Activar | Sí, como **Publicar** | En la pestaña Configuración. No genera nada. |
| Generar ejecución | **Manual** | Botón *Generar ocurrencias* con horizonte. No hay job. |
| Generar OT | **Manual** | Por ocurrencia o en lote. Sin responsable. |

### 4.2 Flujo real paso a paso: crear un preventivo mensual para 3 equipos

| # | Dónde | Qué hace el usuario | Qué se escribe |
|---|---|---|---|
| 1 | Menú → **Programaciones** (o Planificación → pestaña Programaciones) | *Nueva programación* → modal de 6 pasos: nombre, tipo Calendario, vigencia; alcance y asignación (opcionales; el plan los ignora); frecuencia Mensual, día y hora; tolerancias → **Guardar** | `Programacion`, `Programacion_Calendario` (+ responsables) |
| 2 | Menú → **Planificación** → pestaña Planes | *Nuevo plan* → **se abre otra pestaña del navegador** | — |
| 3 | Centro del plan (solo Configuración visible) | Código, nombre, planta, planificador, tipo, modelo → **Guardar** → la página recarga y aparecen las pestañas | `Plan_Mantenimiento`, `Plan_Mantenimiento_Version` v1 |
| 4 | Pestaña **Hitos** | *Nuevo hito* (modal): código, nombre, **elige la programación del paso 1**, parada, duración, tipo y prioridad de OT → **Guardar** | `Plan_Mantenimiento_Hito` |
| 5 | Fila del hito (desplegar) | *Nueva actividad* (modal): código, nombre, procedimiento (si no existe → ir a **Procedimientos**, crearlo, volver y reabrir el modal), duración, obligatoria, permiso → **Guardar**; para repuestos, **reabrir** el modal | `Plan_Mantenimiento_Actividad` (+ `Plan_Actividad_Repuesto`) |
| 6 | Pestaña **Equipos** | *Nuevo equipo* (modal) → elegir equipo → **Guardar**. **Tres veces.** | 3 × `Plan_Mantenimiento_Activo` |
| 7 | Pestaña **Configuración** | Historial de versiones → **Publicar** | v1 PUBLICADO |
| 8 | Pestaña **Calendario** | Horizonte 90 días → **Generar ocurrencias** | N × `Plan_Mantenimiento_Ocurrencia` |
| 9 | Cuando llegue la fecha: Planificación → Bandeja (o Calendario) | **Generar OT** por ocurrencia | `Orden_Trabajo` + pasos + repuestos |
| 10 | Centro de la OT | **Asignar** responsable y técnicos | `Orden_Trabajo_Asignacion` |
| 11 | App | El técnico ejecuta y **finaliza** | OT en espera de cierre |
| 12 | Centro de la OT (web) | El planificador **cierra** con motivo | OT cerrada → ocurrencia COMPLETADA |

### 4.3 Costo medido del flujo (pasos 1 a 8)

| Medida | Hoy |
|---|---|
| Menús distintos que hay que abrir | 2 (3 si falta el procedimiento) |
| Pestañas nuevas del navegador | 1 |
| Modales abiertos | 6 (programación, hito, actividad, 3 equipos) + 1 si hay repuestos |
| Guardados / acciones de servidor | 9 (programación, ficha, hito, actividad, 3 equipos, publicar, generar) |
| Cambios de pestaña dentro del plan | 4 (Hitos → Equipos → Configuración → Calendario) |
| Recargas de página completas | 2 (al crear el plan y al publicar) |
| Datos pedidos que no tienen efecto | 6 campos de la programación (§3.4) + valor de medidor del hito |

### 4.4 Ciclo de vida actual de una ejecución (ocurrencia)

```text
(generar ocurrencias / lectura de medidor)
        ↓
   PENDIENTE ──(llega la fecha disponible)──► situación DISPONIBLE
        │                                      │
        ├──Reprogramar──► REPROGRAMADA + nueva PENDIENTE (conserva la fecha original)
        │
        └──Generar OT──► EN EJECUCIÓN ──cierre web (motivo 1 o 2)──► COMPLETADA
                                      ──cierre web (otros motivos)─► OMITIDA
                                      ──cierre desde la app─────────► (queda EN EJECUCIÓN)  ← H5
```

No existe una acción para **cancelar** u **omitir** una ocurrencia sin OT. CANCELADA (6) no la asigna ningún SP.

---

## 5. Problemas detectados

> Cada problema es verificable en la referencia indicada.

**P-01 · La frecuencia vive fuera del plan.**
- **Problema:** el hito exige elegir una programación ya existente. Si no existe, hay que salir a *Programaciones*, crearla en un asistente de 6 pasos, volver al plan y reabrir el hito (`PlanHito.aspx`: «¿No está? Se crea en *Programaciones*»).
- **Impacto:** es el corte más grande del flujo. El usuario tiene que saber de antemano que la frecuencia es otra entidad.
- **Propuesta:** frecuencia **dentro** de la intervención; el sistema crea la programación privada (§15).

**P-02 · El asistente de programación pide datos que el plan ignora.**
- **Problema:** de sus 6 pasos, *Alcance* y *Asignación* no afectan a ningún generador, y en *Frecuencia* tampoco influyen zona horaria, anticipada/atrasada, «genera automáticamente» ni «desde la última ejecución» (§3.4).
- **Impacto:** formularios largos, expectativas falsas («asigné responsables y la OT llegó sin nadie»).
- **Propuesta:** en el Centro solo se piden los campos que tienen efecto: tipo, regla, vigencia, tolerancias y exclusiones. Los decorativos no se muestran (§15.5).

**P-03 · La programación compartida rompe la inmutabilidad de las versiones.**
- **Problema:** la versión publicada no se puede editar, pero su programación sí, y cualquier cambio altera en caliente lo que genera. La versión nueva copia la referencia (`INS_PLAN_VERSION_NUEVA`), así que editar la frecuencia del borrador cambia también la publicada, y las tareas o pautas que compartan esa programación. Además, el índice único `UX_PMO_PROGRAMACION_ACTIVO_FECHA` (programación, equipo, fecha) hace que **dos planes que comparten una programación sobre el mismo equipo choquen**: solo uno genera esa fecha y el otro la pierde en silencio (la cláusula `NOT EXISTS` de `GEN_PLAN_OCURRENCIAS`).
- **Impacto:** cambios silenciosos de calendario; el versionado del plan no protege lo más importante; mantenciones que faltan sin aviso.
- **Propuesta:** programación **privada por intervención**, con copia al escribir desde un borrador (RP-03). Las compartidas solo se usan si alguien las elige a propósito y con un aviso de «usada por N».

**P-04 · Activar no activa nada.**
- **Problema:** publicar solo cambia el estado. Las ocurrencias se generan con un botón en otra pestaña, y no hay job (está pendiente en `SIGMA_CHECKLIST_PENDIENTES.md`: «job nocturno… que no existe todavía»). El texto «Se generan al publicar la versión» es falso.
- **Impacto:** planes «publicados» que no producen trabajo; la Bandeja queda vacía sin explicación.
- **Propuesta:** **Activar = publicar + generar el horizonte** en la misma transacción lógica (RP-05), y una renovación diaria del horizonte (Fase 2, RP-06).

**P-05 · Publicar una versión nueva deja vivas las ejecuciones de la anterior.**
- **Problema:** las ocurrencias futuras sin OT de la versión retirada siguen en la Bandeja (no se filtra por estado de versión). Si la versión nueva cambió la programación, conviven las dos series; si quitó un equipo, el equipo sigue recibiendo trabajo.
- **Impacto:** trabajo duplicado o fantasma; cumplimiento distorsionado.
- **Propuesta:** al aplicar cambios, las futuras sin OT de la versión retirada **se traspasan** a la intervención equivalente de la versión nueva cuando la frecuencia y el equipo siguen; las demás se cancelan, y lo que falta se genera. El impacto se muestra antes de confirmar (RP-07).

**P-06 · Desactivar o eliminar un plan no está resuelto.**
- **Problema:** «Habilitado = No» detiene la generación, pero las ocurrencias abiertas siguen. No existe la acción «retirar versión», y `DEL_PLAN_MANTENIMIENTO` exige retirar la publicada: un plan publicado **no se puede eliminar** nunca.
- **Impacto:** planes zombis; no hay forma limpia de terminar un plan.
- **Propuesta:** **Desactivar** (retira la versión vigente y cancela las futuras sin OT) y **Reactivar** (RP-08).

**P-07 · El «quién» no existe en el plan.**
- **Problema:** la OT nace sin responsable ni técnicos. Los responsables de la programación no se usan; `Plan_Actividad_Especialidad` no tiene pantalla, y la Planificación muestra «personas: 0».
- **Impacto:** cada OT se asigna a mano, una por una.
- **Propuesta:** responsable y grupo por intervención, aplicados al generar la OT (RP-09).

**P-08 · Los equipos se asocian de a uno.**
- **Problema:** un modal y un guardado por equipo. El combo no filtra por el alcance del plan: el SP rechaza después.
- **Impacto:** un plan para 20 bombas son 20 modales; si no, carga masiva por Excel.
- **Propuesta:** selector múltiple filtrado por el alcance, con resultado por fila (§11.3).

**P-09 · Crear o versionar un procedimiento obliga a salir del plan.**
- **Problema:** está en otro menú. La versión se escribe a mano al crear y no hay «nueva versión»: las actividades siguen apuntando al `prc_id` viejo. Los globales se ven en el listado, pero el plan y la OT los rechazan.
- **Impacto:** se pierde el contexto, quedan recetas desactualizadas y los globales confunden.
- **Propuesta:** panel lateral para crear y editar; «nueva versión» con aviso a las actividades que la usan; globales con «copiar para usar» (§13).

**P-10 · Los repuestos de una actividad exigen guardar y reabrir.**
- **Problema:** la lista aparece recién después del primer guardado.
- **Impacto:** un viaje extra por actividad.
- **Propuesta:** edición inline, con un borrador que se guarda solo (§11).

**P-11 · El plan se edita en otra pantalla, en otra pestaña del navegador.**
- **Problema:** *Nuevo plan* abre `PlanMantenimiento.aspx` en otra pestaña; ahí hay 5 pestañas y 3 tipos de modal, y guardar la ficha recarga la página.
- **Impacto:** dos lugares para el mismo plan (la lista en Planificación y el centro aparte).
- **Propuesta:** la ficha vive **dentro** del workspace del Centro (§11).

**P-12 · El versionado se expone como mecánica.**
- **Problema:** *Nueva versión* y *Publicar* están en Configuración. Los hitos se bloquean en la versión publicada y el usuario tiene que descubrir que debe «abrir una versión nueva».
- **Impacto:** fricción para un cambio menor; conceptos técnicos a la vista.
- **Propuesta:** editar un plan activo abre el borrador **implícitamente**; un solo botón «Aplicar cambios» publica (RP-04). El historial queda como consulta.

**P-13 · El valor del medidor se pide dos veces.**
- **Problema:** se pide en el hito y en la programación, pero solo se usa el de la programación.
- **Impacto:** datos inconsistentes; el usuario no sabe cuál manda.
- **Propuesta:** un solo campo, «cada N unidades», dentro de la frecuencia por medidor (§15.3).

**P-14 · El cierre desde la app no completa la ejecución.**
- **Problema:** `UPD_ORDEN_TRABAJO_CERRAR` (la API) no actualiza `Plan_Mantenimiento_Ocurrencia`; solo lo hace `UPD_ORDEN_TRABAJO_CERRAR_WEB`.
- **Impacto:** ejecuciones eternamente «En ejecución» y cumplimiento subestimado.
- **Propuesta:** el mismo efecto en los dos cierres (RP-12). Es un arreglo de BD **previo** al MVP.

**P-15 · Las OT de un plan no se pueden listar.**
- **Problema:** el listado de OT no filtra por plan. Las OT de un plan solo se ven sueltas en la columna OT del calendario.
- **Impacto:** no se puede responder «¿qué OT generó este plan y en qué estado están?».
- **Propuesta:** sección «OT generadas» en la ficha y filtro por plan en el listado (§17.4).

**P-16 · Las pautas programadas no generan rondas desde la interfaz visible.**
- **Problema:** `GEN_CHECKLIST_OCURRENCIAS` solo se llama desde `ChecklistProgramacions.aspx`, que está oculta del menú. El centro de la pauta permite programar, pero no generar.
- **Impacto:** inspecciones programadas que nunca aparecen en la app.
- **Propuesta:** botón en el centro de la pauta (arreglo rápido fuera del Centro, §16.3) y renovación diaria (Fase 2).

**P-17 · Una pauta no se puede exigir dentro de un mantenimiento.**
- **Problema:** `Plan_Actividad_Checklist` y `Orden_Trabajo_Checklist` existen, pero sin código.
- **Impacto:** «inspeccionar con la pauta X durante el preventivo» no se puede configurar.
- **Propuesta:** Fase 2 (§16.2).

**P-18 · Tres formas de programar trabajo sin guía.**
- **Problema:** plan, tarea y pauta usan la misma programación, pero producen cosas distintas (OT, ejecución liviana, checklist + hallazgo), y nada orienta cuál elegir. La tarea no genera OT, aunque el catálogo tenga el origen TAREA.
- **Impacto:** se elige mal la herramienta, y aparecen datos duplicados (rondas cargadas como tareas, preventivos cargados como tareas).
- **Propuesta:** el Centro es el lugar del **preventivo con OT** y lo dice. En la Biblioteca y en el estado vacío se explica cuándo usar una tarea o una pauta, con enlace a su centro (§7.4).

**P-19 · Los permisos están fragmentados.**
- **Problema:** Planificación exige 116, Programaciones 92 y Procedimientos 97. Por eso Programaciones tuvo que volver a ser visible en el menú (`BD/297`, `BD/300`).
- **Impacto:** al absorber menús, alguien puede perder la entrada.
- **Propuesta:** el Centro se abre con 116, 92 **o** 97, y cada pestaña se muestra según su permiso (RP-15).

**P-20 · Hay pantallas huérfanas acumuladas.**
- **Problema:** `PlanVersion.aspx` (nada la abre), `PlanActividades.aspx`, `PlanMantenimientos.aspx` y `PlanOcurrenciaBandeja.aspx` (solo para exportar).
- **Impacto:** deuda y rutas que confunden al soporte.
- **Propuesta:** se retiran del menú cuando el Centro esté vivo, conservando la URL un sprint (§26).

**P-21 · «Hito» no comunica.**
- **Problema:** el término técnico es lo que se muestra en pantalla.
- **Impacto:** curva de aprendizaje.
- **Propuesta:** en la interfaz pasa a llamarse **Intervención** (§8.1).

**P-22 · No se puede duplicar un plan.**
- **Problema:** solo se duplican las programaciones (`DuplicarProgramacion`).
- **Impacto:** planes casi iguales para modelos parecidos se cargan desde cero o por Excel.
- **Propuesta:** *Duplicar plan* (RP-13).

**P-23 · Una programación nueva exige guardar antes de completarla.**
- **Problema:** Fecha única, Condición, Exclusiones y la proyección no se pueden cargar sin guardar primero.
- **Impacto:** guardar dos veces; no se ve el resultado mientras se configura.
- **Propuesta:** el borrador se guarda solo y la vista previa de fechas se ve mientras se escribe (§15.4).

**P-24 · Una intervención por medidor puede no generar nunca, en silencio.**
- **Problema:** la generación por medidor toma el medidor de la programación, el del equipo en el plan o, si no hay, cualquier medidor del equipo (`FNC_PLAN_MEDIDOR_ESTADO`). Un equipo **sin ningún medidor** nunca genera, y nada lo advierte al publicar. Además, la duración de la OT es la de la intervención y no considera las actividades: si la intervención no la define, la OT nace sin duración estimada aunque sus actividades la tengan (RE-17).
- **Impacto:** planes «activos» que no producen trabajo para algunos equipos; carga de horas subestimada en el Calendario.
- **Propuesta:** advertencia en «Listo para activar» (RP-10) y duración por suma de actividades cuando falta (OT-6).

**P-25 · No hay acción para omitir una ejecución.**
- **Problema:** solo se puede reprogramar, o generar la OT y anularla.
- **Impacto:** OT basura para registrar que «esta vez no corresponde».
- **Propuesta:** *Omitir con motivo* sobre una ejecución sin OT (Fase 2, RP-14).

---

## 6. Oportunidades

Lo que ya existe y el Centro reutiliza **sin reescribir**:

| Activo existente | Uso en el Centro |
|---|---|
| SP idempotentes: `GEN_PLAN_OCURRENCIAS` (índices únicos), `INS_ORDEN_TRABAJO_OCURRENCIA` (devuelve la existente) | Activar y generar en lote sin miedo a duplicar. |
| `FNC_PROGRAMACION_FECHAS` y `SEL_PROGRAMACION_PROYECCION` | Vista previa de las próximas fechas en el editor de frecuencia. Las exclusiones se devuelven marcadas: se puede mostrar *por qué* falta una fecha. |
| `INS_PLAN_VERSION_NUEVA` (copia hitos, actividades y equipos) | Borrador implícito al editar y base de *Duplicar plan*. |
| Validaciones de `INS_PLAN_ACTIVO` (alcance, componente, medidor, duplicado) | Selector múltiple: se llama por equipo y se informa el resultado por fila, como en la carga masiva. |
| `SEL_PLAN_ACTIVO_COBERTURA` y `SEL_PLANIFICACION_COBERTURA` | Aviso «este equipo ya está en el plan X»; *Crear plan* desde Cobertura. |
| `WsPlanificacion360.asmx` + `sigma-planificacion360.js` (sin UpdatePanel ni ViewState, pestañas por AJAX, estado en la URL `#tab=`) | El patrón técnico del Centro. Se extiende, no se reemplaza. |
| Carga masiva de planes (3 hojas, resultado por fila) | Se mantiene como acción secundaria de la pestaña Planes. |
| API `POST /plan-ocurrencias/generar` con `solo_automaticas` | Lista para una tarea programada (no hay SQL Agent en el hosting). |
| Tablas en esquema: `Plan_Actividad_Especialidad`, `Plan_Actividad_Checklist`, `Orden_Trabajo_Checklist` | Fase 2: personas requeridas y pauta dentro de la intervención, sin cambiar el modelo. |
| Cumplimiento contra la fecha original (`SEL_PLAN_CUMPLIMIENTO`) | Se conserva tal cual: es la regla que da sentido a reprogramar. |
| Editor de procedimiento con pasos en memoria e importación desde Excel (`Procedimiento.aspx.cs`) | Su lógica se reutiliza en el panel lateral. |

---

## 7. Visión del Centro de Planificación

### 7.1 Enunciado

> **«Configuro el mantenimiento de estos equipos en un solo lugar: qué, cómo, cuándo y quién. Lo activo, y SIGMA se encarga de que el trabajo aparezca a tiempo.»**

El usuario piensa en **planes y equipos**, nunca en programaciones, versiones ni ocurrencias. El sistema crea y mantiene esas relaciones por detrás.

### 7.2 Principios que el diseño debe cumplir

1. **Un plan = un lugar.** Ver, crear, editar, activar, desactivar y seguir un plan ocurre dentro del Centro, sin cambiar de página ni abrir pestañas del navegador.
2. **Workspace, no asistente.** Lista de planes + ficha del plan elegido. La ficha tiene secciones que se editan inline; el «paso a paso» es una lista de verificación, no un wizard.
3. **Solo se pregunta lo que tiene efecto.** Un campo que no cambia lo que se genera no se muestra (§3.4).
4. **El sistema hace los vínculos.** La programación, el borrador, la generación de ejecuciones y la asignación de la OT son consecuencias, no tareas del usuario.
5. **Mostrar el resultado antes de comprometerse.** Las próximas fechas mientras se configura la frecuencia; el impacto (ejecuciones que se crean, se cancelan o se mantienen) antes de activar o aplicar cambios.
6. **Panel lateral en vez de modal** para todo lo secundario (procedimiento, reprogramar, equipos). El modal queda solo para confirmar acciones irreversibles.

### 7.3 Persona principal

**Planificador de mantenimiento** (permisos 116 + 117; 102 para generar OT). Arma y ajusta planes para una o varias plantas, revisa qué viene y genera las OT.

Secundarias: **Supervisor o jefe** (consulta y cumplimiento) y **Administrador de catálogos** (procedimientos; permisos 97/98).

### 7.4 Qué es y qué no es el Centro

| Es | No es |
|---|---|
| El lugar del **mantenimiento preventivo que genera OT**: planes, intervenciones, frecuencias, procedimientos, ejecuciones programadas y su paso a OT. | El editor de **pautas de inspección** (estructura, ítems, validaciones): eso sigue en su centro. |
| El calendario y la bandeja de lo **programado**. | La **ejecución** de la OT (asignar técnicos en detalle, pasos, evidencias, cierre): eso sigue en el centro de la OT. |
| La biblioteca de **procedimientos** y **calendarios compartidos**. | Las **tareas recurrentes** (rutinas sin OT), los **hallazgos** y las **fallas**. |

Cuando el usuario quiera algo que no es preventivo con OT, el Centro **orienta**:

- *«¿Una ronda con checklist? → Pautas de inspección.»*
- *«¿Una rutina sin orden de trabajo (aseo, lectura, verificación rápida)? → Tareas recurrentes.»*

---

## 8. Arquitectura funcional propuesta

### 8.1 Vocabulario de la interfaz ↔ entidad técnica

| En la interfaz [PROPUESTA] | Entidad / tabla [EXISTE] | Nota |
|---|---|---|
| **Plan** | `Plan_Mantenimiento` | Se mantiene. |
| **Estado del plan** (Borrador · Activo · Activo con cambios · Inactivo) | Derivado de versiones + `pma_habilitado` | Ver §8.3. |
| **Intervención** | `Plan_Mantenimiento_Hito` | Reemplaza «Hito». Ej.: «Mantención 500 h», «Overhaul anual». |
| **Frecuencia** | `Programacion` privada + su detalle | El usuario no la ve como entidad. |
| **Calendario compartido** | `Programacion` reutilizada por varias intervenciones, tareas o pautas | Solo en Biblioteca y como opción avanzada. |
| **Actividad** | `Plan_Mantenimiento_Actividad` | «Qué se hace». Cada una es un paso de la OT. |
| **Procedimiento** | `Procedimiento` + `Procedimiento_Paso` | Se mantiene. |
| **Equipos del plan** | `Plan_Mantenimiento_Activo` | «Qué mantener». |
| **Ejecución programada** (o «ejecución») | `Plan_Mantenimiento_Ocurrencia` | Una fecha concreta para un equipo. |
| **Versión** | `Plan_Mantenimiento_Version` | Solo visible en el historial. |
| **Responsable de la intervención** | **[PROPUESTA]** `pmh_usuario_responsable`, `pmh_grupo_trabajo` | Columnas nuevas (§19.3). |

### 8.2 Reglas de propiedad (quién es dueño de qué)

| Objeto | Dueño | Reutilizable | Regla |
|---|---|---|---|
| Frecuencia de una intervención | La intervención | **No** (privada) | La crea el sistema con el nombre `«{código plan} · {código intervención}»`. Se edita solo desde el borrador del plan, con copia al escribir (RP-03). |
| Calendario compartido | La Biblioteca | Sí | Solo si el usuario lo elige a propósito. Al editarlo se muestra «usado por N planes, M tareas, K pautas» y se exige confirmar. |
| Procedimiento | La Biblioteca | Sí | Una actividad apunta a una versión. Una versión nueva no cambia las actividades sin confirmación (§13.3). |
| Equipos, intervenciones, actividades | La versión del plan | No | Se copian a cada versión nueva (`INS_PLAN_VERSION_NUEVA`). |
| Ejecuciones | El plan (por la intervención) | — | Las crea y las cancela el sistema según las reglas RP-05 a RP-08. El usuario solo reprograma, omite o genera la OT. |

### 8.3 Estados del plan para el usuario [PROPUESTA, derivado de datos existentes]

| Estado | Condición en los datos | Qué puede hacer el usuario |
|---|---|---|
| **Borrador** | `pma_habilitado = 1`, sin versión PUBLICADA, con BORRADOR | Configurar todo · **Activar** · Eliminar |
| **Activo** | Versión PUBLICADA, `pma_habilitado = 1`, sin BORRADOR | Ver · **Editar** (abre borrador implícito) · Duplicar · **Desactivar** |
| **Activo · cambios sin aplicar** | PUBLICADA + BORRADOR | Seguir editando · **Aplicar cambios** · **Descartar cambios** · Desactivar |
| **Inactivo** | `pma_habilitado = 0` (sin versión PUBLICADA tras desactivar) | Ver historial · **Reactivar** · Duplicar · Eliminar (si nunca generó) |

```text
            Activar                         Editar
Borrador ───────────► Activo ◄──────────────────────┐
   │                   │  │                         │ Aplicar cambios
   │ Eliminar          │  └──► Activo · cambios ────┘
   ▼                   │        sin aplicar ── Descartar cambios ──► Activo
 (baja)       Desactivar│
                       ▼
                   Inactivo ── Reactivar ──► Activo
```

### 8.4 Alcance del Centro dentro del ciclo completo

```text
 DENTRO DEL CENTRO ──────────────────────────────────────────────────────────── FUERA (enlaza)
 Qué mantener → Intervenciones → Frecuencia → Activar → Ejecuciones → Generar OT ─► OT: asignar, ejecutar,
 (equipos)     (actividades,                         (bandeja,       (con          cerrar (Órdenes de trabajo)
               procedimiento,                         calendario,     responsable)
               repuestos, quién)                      reprogramar)                ─► Resultado e historial: se LEE en el
                                                                                     Centro (estado de la OT, cumplimiento)

 Pauta de inspección ──► Ejecución ──► Hallazgo ──► OT ......... fuera (Pautas / Hallazgos); en Fase 2 la pauta
                                                                 puede exigirse dentro de una intervención
 Falla ──► OT ................................................. fuera (Fallas)
 Tarea recurrente ──► Ejecución (sin OT) ...................... fuera (Tareas recurrentes)
```

**Empieza** en «qué equipos necesitan mantenimiento» (incluida la Cobertura: equipos sin plan). **Termina** al generar la OT con su responsable. Desde ahí el Centro solo **lee**: el estado de la OT, el cumplimiento y el historial del plan.

---

## 9. Flujo UX propuesto

### 9.1 Crear → Configurar → Revisar → Activar

| Momento | Qué hace el usuario | Qué hace el sistema por detrás |
|---|---|---|
| **Crear** | *Nuevo plan* en la pestaña Planes. Escribe el **nombre**; la planta se propone desde el filtro de la cabecera. | Crea el plan + versión 1 en borrador (`INS_PLAN_MANTENIMIENTO`) y le asigna código automático. La ficha queda abierta **en el mismo workspace**. |
| **Configurar** | Completa las secciones en cualquier orden: **Equipos** (selector múltiple), **Intervenciones** (nombre + frecuencia + actividades + quién), procedimientos en el panel lateral. | Guarda cada cambio solo (borrador). Al definir la frecuencia crea o actualiza la programación privada. Muestra las próximas fechas en vivo. |
| **Revisar** | Mira la tarjeta **«Listo para activar»** (siempre visible en la ficha): lo que falta y lo que conviene revisar, más el impacto. | Corre las validaciones (§21) y calcula «se generarán N ejecuciones en 90 días para M equipos». |
| **Activar** | Un botón: **Activar plan**. | Publica, genera el horizonte de ejecuciones y deja el plan en *Activo* (RP-05). Informa el resultado en la misma ficha. |

### 9.2 Modificar un plan activo

1. El usuario edita cualquier campo de un plan *Activo*.
2. El sistema abre el borrador (copia de la vigente) **en ese momento** y muestra el banner: «Estás editando cambios sin aplicar. La versión activa sigue generando trabajo.»
3. **Aplicar cambios** muestra el impacto: ejecuciones futuras sin OT que pasan a la versión nueva (misma frecuencia y equipo), las que se cancelan (frecuencia cambiada o equipo quitado), las nuevas que se crean y las que tienen OT y se mantienen.
4. Al confirmar: publica, traspasa, cancela y genera lo que falta (RP-07).

**Descartar cambios** elimina el borrador.

### 9.3 Desactivar y reactivar

- **Desactivar** pide un motivo y muestra el impacto (N ejecuciones futuras sin OT se cancelan; las que tienen OT siguen su curso). Retira la versión vigente y deja el plan *Inactivo* (RP-08).
- **Reactivar** publica de nuevo la última versión retirada (como un borrador nuevo copiado de ella), **reabre** las ejecuciones futuras que canceló la desactivación y genera lo que falte del horizonte.

### 9.4 Comparación de costo (mismo caso de §4.2)

| Medida | Hoy | Objetivo |
|---|---|---|
| Menús distintos | 2–3 | **1** |
| Pestañas nuevas del navegador | 1 | **0** |
| Modales en el camino principal | 6–7 | **0** (solo la confirmación de Activar) |
| Acciones de guardado explícitas | 9 | **1** (Activar). El borrador se guarda solo. |
| Recargas de página | 2 | **0** |
| Campos sin efecto pedidos | 7 | **0** |

---

## 10. Pantalla principal

`Planificacion.aspx`, rotulada **Centro de Planificación** [PROPUESTA]. Mantiene la cáscara de Planificación 360: Default.master, cabecera con planta y período, KPI, pestañas por AJAX y estado en la URL.

### 10.1 Cabecera

- **Título:** «Centro de Planificación» + nombre de la planta si hay una elegida.
- **Filtros globales [EXISTE]:** Planta (todas o una) y Período (mes y año, selector propio). Afectan a todas las pestañas.
- **4 KPI [EXISTE]**, cada uno navega a su vista filtrada:
  - *Requieren atención* (vencidas + atrasadas) → Ejecuciones, filtro «Requieren atención».
  - *Disponibles* → Ejecuciones, filtro «Disponibles».
  - *Cumplimiento anual* → Cumplimiento.
  - *Carga próximas 4 semanas* (horas estimadas) → Ejecuciones, vista Semana.
- **Acción primaria (morado):** **Nuevo plan**.
- **Acción secundaria (turquesa):** **Carga masiva** [EXISTE], en panel lateral.

### 10.2 Pestañas [PROPUESTA]

Son 5 en vez de las 7 actuales:

| Pestaña | Contenido | Reemplaza a | Permiso |
|---|---|---|---|
| **Planes** (por defecto) | Workspace: lista de planes + ficha del plan elegido (§11). | Planes + Resumen (los borradores pendientes pasan a ser un filtro) + el Centro del plan aparte | 116 (editar: 117) |
| **Ejecuciones** | Lo programado, en tres vistas sobre el mismo filtro: **Lista** (la Bandeja actual), **Semana** y **Mes** (el Calendario actual). Acciones: Generar OT (una o en lote), Reprogramar, Omitir (Fase 2), Abrir OT. | Bandeja + Calendario + las urgencias y paradas del Resumen | 116 (Generar OT: 102) |
| **Cumplimiento** | Igual que hoy [EXISTE]. Al tocar un equipo, sus ejecuciones del período. | Cumplimiento | 116 |
| **Cobertura** | Igual que hoy [EXISTE] + **selección múltiple y «Crear plan con estos equipos»** [PROPUESTA]. | Cobertura | 116 |
| **Biblioteca** | Dos sub-vistas: **Procedimientos** (§13) y **Calendarios compartidos** (§15.6). | Menús Procedimientos y Programaciones | 97 (procedimientos) · 92 (calendarios) |

**Resumen desaparece como pestaña.** Su contenido se reubica:

- Urgencias y paradas → Ejecuciones (filtro por defecto «Requieren atención», marca de parada).
- Borradores pendientes → Planes (filtro «Con cambios sin aplicar» / «Borrador»).
- Actividad reciente → sección «OT generadas» de cada ficha.

### 10.3 Pestaña Planes: el workspace

Layout de dos zonas en escritorio:

1. **Lista (izquierda, ~380 px, con scroll propio).**
   - Buscador: nombre, código, equipo o intervención.
   - Chips de filtro con conteo: *Todos · Activos · Borradores · Con cambios sin aplicar · Inactivos · Requieren atención* (con ejecuciones vencidas o atrasadas).
   - Orden: requieren atención primero, luego por próxima ejecución.
   - **Fila de plan** (tarjeta compacta, no tabla):
     - Nombre + código.
     - Chip de estado (§8.3).
     - Planta.
     - «N equipos · M intervenciones».
     - **Próxima ejecución** (fecha + equipo).
     - Resumen de frecuencias («Mensual · Cada 500 h»).
     - Responsable principal.
     - Indicador rojo o ámbar si tiene vencidas o atrasadas.
   - Selección múltiple (casilla al pasar el puntero) con acciones en lote: **Desactivar**, **Duplicar** (de a uno: desactivado si hay más de uno).
2. **Ficha (derecha, resto del ancho).** El plan elegido (§11). Sin plan elegido: estado vacío con «Nuevo plan», la explicación de qué es un plan y los atajos «¿Una ronda con checklist? → Pautas» y «¿Una rutina sin OT? → Tareas recurrentes».

En pantallas angostas (< 1100 px) la lista y la ficha se alternan: la ficha entra sobre la lista con la acción «← Planes».

**La selección vive en la URL** (`#tab=planes&plan=<id cifrado>`), para volver igual desde la OT o desde la ficha del activo.

### 10.4 Pestaña Ejecuciones

- **Filtros:** situación (Requieren atención · Vencidas · Atrasadas · Disponibles · Futuras · Cerradas), plan, equipo, «solo con parada», texto.
- **Vista Lista:** fila = fecha (y fecha límite), equipo, plan · intervención, chips (parada, overhaul, permiso, n.º de actividades), situación, OT. Selección múltiple → **Generar OT** (turquesa; resultado por fila: generada, ya existía, rechazada y por qué) [EXISTE en la lógica].
- **Vistas Semana y Mes:** calendario con la carga en horas por día y semana [EXISTE]. Clic en una ejecución → **panel lateral** con el detalle y sus acciones; no abre otra pestaña del navegador.
- **Reprogramar:** en el panel lateral (hoy es modal): fecha nueva + motivo obligatorio. Avisa que el cumplimiento se sigue midiendo contra la fecha original [EXISTE, regla RE-14].

### 10.5 Reglas de color de acciones (CLAUDE.md)

| Función | Color | Ejemplos en el Centro |
|---|---|---|
| Primario (morado) | Una por grupo | Activar plan · Aplicar cambios · Nuevo plan · Guardar procedimiento |
| Secundario (turquesa oscuro) | La acción paralela | Generar OT · Reprogramar · Carga masiva |
| Contorno (azul) | Navegar o abrir | Abrir OT · Ver ficha del activo · Ver historial |
| Ghost (morado suave) | Cancelar | Cancelar · Descartar panel |
| Peligro (rojo) | Solo destructivo | Eliminar plan (borrador) · Quitar equipo |

Desactivar **no** es rojo: es reversible. Va como contorno, con confirmación.

---

## 11. Ficha de planificación

La ficha **es** el editor. No hay modo «ver» y modo «editar»: los campos se editan inline cuando el plan es editable y el usuario tiene 117. En un plan *Activo*, el primer cambio abre el borrador implícito (§9.2).

### 11.1 Encabezado de la ficha

- Nombre (editable inline) · código (solo lectura) · chip de estado · versión vigente («v3 activa desde 12-09-2026», clic → historial).
- Línea de alcance: planta · tipo de activo · modelo («Cualquier…» cuando no hay).
- **Próxima ejecución** y **requieren atención** (número, clic → Ejecuciones filtrada por este plan).
- **Acciones**, según el estado (§8.3):

| Estado | Primaria (morado) | Otras |
|---|---|---|
| Borrador | **Activar plan** | Duplicar · Eliminar (rojo) |
| Activo | — | Duplicar · Desactivar · Ver historial |
| Activo · cambios sin aplicar | **Aplicar cambios** | Descartar cambios (ghost) · Desactivar |
| Inactivo | **Reactivar** | Duplicar · Ver historial · Eliminar (si nunca generó) |

- **Banner del borrador implícito** (estado «cambios sin aplicar»): «Estás editando cambios sin aplicar. La versión activa sigue generando trabajo hasta que apliques.» Incluye cuántos cambios hay (hitos, actividades y equipos distintos de la vigente; `SEL_PLANIFICACION_BORRADOR` ya calcula `CAMBIOS`).

### 11.2 Tarjeta «Listo para activar» (siempre visible, columna lateral o al pie)

Una lista de verificación viva, no un asistente.

**Bloqueantes** (impiden activar):

- ☐ Al menos un equipo. [EXISTE, RE-05]
- ☐ Al menos una intervención habilitada. [EXISTE, RE-04]
- ☐ Cada intervención tiene frecuencia. [EXISTE: FK obligatoria]
- ☐ Toda actividad con permiso tiene el tipo de permiso. [EXISTE, RE-19]

**Advertencias** (no impiden):

- ⚠ Intervención sin actividades: su OT tendrá un solo paso. [EXISTE: comportamiento de `INS_ORDEN_TRABAJO_OCURRENCIA`]
- ⚠ Frecuencia sin fechas en los próximos 90 días.
- ⚠ Frecuencia por medidor con un equipo sin ningún medidor: ese equipo nunca generará. [PROPUESTA, RP-10]
- ⚠ Intervención sin responsable: las OT nacerán sin asignar.
- ⚠ Equipo que ya está en otro plan activo. [EXISTE, `SEL_PLAN_ACTIVO_COBERTURA`]

**Impacto:** «Al activar se generarán **N** ejecuciones entre el {hoy} y el {hoy + 90} para **M** equipos.»

### 11.3 Sección «Qué mantener» (equipos)

- **Alcance** (inline): planta, tipo de activo y modelo (opcionales). Cambiar el alcance valida contra los equipos ya agregados y avisa cuáles quedarían fuera [PROPUESTA].
- **Lista de equipos** en tarjetas compactas con foto [EXISTE en el Centro del plan]: código, nombre, área, componente («Equipo completo» si no hay), medidor, chip «también en el plan X», acción «Ver ficha del activo» y quitar (rojo, solo en borrador).
- **Agregar equipos [PROPUESTA]:** selector múltiple en **panel lateral**.
  - Buscador y filtros por planta, área, tipo y modelo, **prefiltrado por el alcance del plan**. Los que no calzan se muestran deshabilitados con el motivo («otra planta», «otro tipo»).
  - Columna de cobertura: «sin plan» o «en N planes».
  - Componente y medidor por equipo, opcionales, editables en la lista antes de confirmar.
  - **Agregar seleccionados** → una llamada por equipo a `INS_PLAN_ACTIVO`; resultado por fila (agregado / rechazado y por qué).

### 11.4 Sección «Qué hacer, cómo y cuándo» (intervenciones)

Una tarjeta desplegable por intervención, ordenadas por `pmh_orden` (se reordenan arrastrando [PROPUESTA]).

**Cabecera de la tarjeta (inline):**

- Nombre y código.
- **Frecuencia en lenguaje natural** («Cada mes, el día 15 a las 08:00 · tolerancia ±2 días»; «Cada 500 h del horómetro»), clic → editor de frecuencia (§15).
- Próximas 3 fechas.
- Chips: parada · overhaul · n.º de actividades · duración.
- Responsable.
- Habilitada sí/no.

**Cuerpo desplegado (bloques):**

1. **Datos de la OT** (inline): tipo de OT, prioridad, duración estimada, requiere parada, overhaul, descripción (va a la OT). [EXISTE como campos del hito]
2. **Cuándo** → editor de frecuencia embebido (§15). [PROPUESTA]
3. **Qué se hace** → lista de actividades (§14), con *Agregar actividad* y *Agregar desde procedimiento*.
4. **Quién** → responsable (persona) + grupo de trabajo o apoyo. Se aplica a cada OT generada. [PROPUESTA, RP-09]

*Agregar intervención* crea una tarjeta nueva abierta, con el nombre enfocado. El código se propone automáticamente (`INT-01`, `INT-02`…; hoy el código del hito es obligatorio y manual).

### 11.5 Sección «Próximas ejecuciones»

- Las próximas 10 ejecuciones del plan (fecha, equipo, intervención, situación, OT), más «Ver todas en Ejecuciones» (contorno).
- En un **borrador nunca activado**: **proyección** calculada con `FNC_PROGRAMACION_FECHAS` (sin escribir nada), rotulada «Proyección: se generarán al activar».

### 11.6 Sección «OT generadas» [PROPUESTA]

- Las OT cuyo `otr_plan_mantenimiento_ocurrencia` pertenece a este plan: OT-n, equipo, intervención, fecha, estado de la OT, responsable.
- Filtro rápido: Abiertas · En espera de cierre · Cerradas.
- «Abrir OT» (contorno), en la misma pestaña, conservando el regreso por URL.

### 11.7 Sección «Historial»

- Versiones [EXISTE, `SEL_PLAN_VERSION`]: número, estado, publicada por y cuándo, retirada, observación, n.º de intervenciones, equipos y ejecuciones.
- La auditoría del plan (creado y modificado por).
- Solo lectura.

### 11.8 Comportamiento de guardado

- Cada edición inline se guarda al salir del campo, con indicador «Guardado» / «Guardando…» / «No se pudo guardar: {motivo del SP}» [PROPUESTA]. Los mensajes de error son los de los SP (ya están redactados para el usuario).
- Sin postback completo ni recarga (patrón `WsPlanificacion360`).

---

## 12. Creación de planificación

### 12.1 Puntos de entrada

| Entrada | Qué precarga | Estado |
|---|---|---|
| *Nuevo plan* (cabecera o estado vacío) | La planta del filtro global | [PROPUESTA] (hoy abre otra pestaña del navegador) |
| *Crear plan con estos equipos* (Cobertura) | Los equipos elegidos; el alcance se propone si todos comparten planta y tipo | [PROPUESTA] |
| *Crear plan* desde la ficha del activo | El equipo | [PROPUESTA] (la ficha hoy solo **muestra** los planes que lo cubren) |
| *Duplicar plan* | Todo menos los equipos (opcionales) y el código | [PROPUESTA, RP-13] |
| *Carga masiva* (Excel de 3 hojas) | Planes completos | [EXISTE] |

### 12.2 Mínimo para crear

Solo el **nombre**. El código es automático [EXISTE, código con prefijo]. Todo lo demás se completa en la ficha. El plan nace en *Borrador* y no genera nada hasta activarse.

### 12.3 Atajo opcional «Plan rápido» [PROPUESTA, Fase 2]

Para el caso más común (un equipo, una intervención, una frecuencia): un formulario de una sola tarjeta (equipos + nombre de la intervención + frecuencia + responsable) que crea el plan completo y deja la ficha abierta para revisar y activar. **No** es un asistente de pasos.

### 12.4 Plantillas [Futuro]

«Crear desde plantilla del fabricante o del modelo»: fuera de alcance; ver §24.

---

## 13. Procedimientos

### 13.1 Qué existe

- **Modelo [EXISTE]:** `Procedimiento` = código + **versión** (la llave es cliente + código + versión), nombre, tipo de activo, descripción, duración estimada, «requiere permiso» + tipo de permiso. `Procedimiento_Paso` = orden (único por procedimiento), nombre, instrucción, **punto de control**, **requiere evidencia**, **requiere medición** + variable de medición, duración.
- **Editor [EXISTE]:** `Procedimiento.aspx`. Los pasos se editan en memoria y se guardan de una vez (el orden se aplica en una sola pasada con `UPD_PROCEDIMIENTO_PASO_ORDEN`); importación de pasos desde Excel; los pasos usados en una OT no se borran (baja lógica).
- **Globales [EXISTE]:** `prc_cliente NULL`. Se listan, pero no se editan ni se eliminan, y **no se pueden usar** en una actividad ni en una OT (los SP exigen `prc_cliente = @CLIENTE`).
- **Uso [EXISTE]:** en la actividad del plan (sus pasos se copian a la OT al generarla) y directamente en una OT abierta (`INS_ORDEN_TRABAJO_PASO_PROCEDIMIENTO`: agrega los pasos al final).
- **Versionado real [EXISTE]:** el número se escribe a mano al crear y después no se edita. No hay «nueva versión»; editar cambia la receta **en el lugar**. Las OT ya generadas no cambian, porque el texto se copió [EXISTE, RE-16].

### 13.2 Decisión

- El procedimiento **se mantiene como entidad independiente y reutilizable**: lo usan los planes y las OT manuales.
- **Deja de ser menú.** Vive en **Biblioteca → Procedimientos** dentro del Centro.
- Se crea y se edita en un **panel lateral ancho** (~720 px) que se abre desde la Biblioteca o **desde una actividad** sin perder la ficha del plan. El panel reutiliza la lógica del editor actual: pasos en memoria, reordenar, importar Excel.

### 13.3 Comportamiento propuesto

| Situación | Comportamiento |
|---|---|
| En una actividad: *Elegir procedimiento* | Buscador sobre la última versión de los procedimientos del cliente [EXISTE: `filtro_solo_ultima`], con vista previa de los pasos (n.º de pasos, puntos de control, mediciones, duración). |
| En una actividad: *Crear procedimiento* | Abre el panel con el nombre de la actividad precargado. Al guardar queda vinculado a la actividad. [PROPUESTA] |
| *Agregar desde procedimiento* (en la intervención) | Crea una actividad con el nombre, la duración y el permiso del procedimiento, y el procedimiento vinculado. [PROPUESTA] |
| Editar un procedimiento usado por planes activos | Aviso: «Usado por N actividades de M planes activos. Las OT futuras tomarán los pasos nuevos; las ya generadas no cambian.» [PROPUESTA; refleja RE-16] |
| *Nueva versión* | Copia el procedimiento con versión + 1 [PROPUESTA, RP-11]. Muestra las actividades que usan la versión anterior con «Actualizar a vN» (individual o todas). Las de planes activos se actualizan en su borrador implícito. |
| Procedimiento global | En la Biblioteca, con la marca «Sistema» y la acción **Copiar para usar** (crea la copia del cliente) [PROPUESTA]. En los selectores de actividad **no** aparecen globales, para no ofrecer algo que el SP rechaza. |

---

## 14. Tareas (actividades de la intervención)

### 14.1 Aclaración de términos (obligatoria para el diseño)

En este Centro, **«tareas / actividades» = `Plan_Mantenimiento_Actividad`**: lo que se hace dentro de una intervención y que se convierte en paso de la OT.

**No** confundir con el módulo **Tareas recurrentes** (`Tarea`): rutinas livianas con ejecución propia en la app, **sin OT**. Ese módulo queda fuera del Centro (§18).

### 14.2 Campos de una actividad [EXISTE]

Código (único en la intervención), nombre, descripción, orden, procedimiento (opcional), duración estimada, **obligatoria** (sin resultado no deja cerrar; si no es obligatoria, el técnico puede marcar «no aplica»), **requiere parada**, **requiere permiso** + tipo de permiso (obligatorio si requiere permiso).

**Repuestos planificados** por actividad: repuesto, cantidad, unidad, obligatorio, observación (`Plan_Actividad_Repuesto`).

### 14.3 Edición propuesta

- Lista **inline** dentro de la tarjeta de la intervención: una fila por actividad con orden (arrastrable), nombre, procedimiento (chip con «n pasos»), duración, chips Obligatoria / Parada / Permiso.
- Clic en una fila → se despliega en el lugar: descripción, procedimiento (elegir o crear), permiso y **repuestos** (buscador de repuestos + cantidad, en la misma fila, **sin guardar antes**) [PROPUESTA, resuelve P-10].
- El código se propone solo (`ACT-01`…); hoy es obligatorio y manual [PROPUESTA].
- **Suma de duraciones vs duración de la intervención:** se muestra la diferencia, como el editor de procedimientos ya hace con sus pasos [EXISTE en procedimientos; PROPUESTA aquí]. Es informativa: la OT usa la duración de la intervención [EXISTE, RE-17].
- **Personas requeridas por especialidad** (`Plan_Actividad_Especialidad`, [ESQUEMA]): Fase 2.

### 14.4 Qué ve el técnico (para que el diseño lo explique)

Cada actividad es un paso de la OT. Si tiene procedimiento, se despliega en tantos pasos como pasos tenga el procedimiento, con el texto copiado al generar la OT. Un **punto de control** del procedimiento siempre es obligatorio [EXISTE, RE-15].

---

## 15. Programación y frecuencia

### 15.1 Decisión

- La frecuencia se configura **dentro de cada intervención** con un editor embebido.
- Por detrás, el sistema crea una `Programacion` **privada** para esa intervención (nombre técnico `«{plan} · {intervención}»`, único por cliente [EXISTE, RE-21]) y su detalle.
- El usuario puede, como opción avanzada, **usar un calendario compartido** de la Biblioteca.

### 15.2 Tipos de frecuencia que se ofrecen

| Tipo [EXISTE en `Programacion_Tipo`] | Se ofrece en el Centro | Campos | Tabla |
|---|---|---|---|
| **Calendario** | Sí (por defecto) | Repetición: diaria / semanal / mensual / anual · «cada N» · días de la semana (semanal) · día del mes **o** semana ordinal + día (mensual) · mes (anual) · hora | `Programacion_Calendario` (+ `_Dia`) |
| **Intervalo** | Sí | Cada N {minutos, horas, días, semanas, meses, años} · a partir de (fecha y hora ancla) | `Programacion_Intervalo` |
| **Fechas puntuales** (Fecha única) | Sí | Lista de fechas, con hora opcional | `Programacion_Fecha` |
| **Por medidor** | Sí | Cada N unidades · valor inicial · avisar N antes · medidor: el de cada equipo del plan (`pac_activo_medidor`), o uno fijo | `Programacion_Medidor` |
| **Por condición** | Sí, en «Avanzado» | Variable · operador · umbral (y «hasta») · duración mínima · severidad · política si hay varias condiciones (una / todas / mínimo) | `Programacion_Condicion` |
| Abierta | **No** | — | En un plan no genera nada (§3.4). |

**Comunes a todos:**

- **Vigencia** (desde, obligatoria; hasta, opcional). Por defecto: desde hoy, sin fin.
- **Tolerancia** antes y después, en días u horas (por defecto 0). Definen *disponible desde* y *vence el* [EXISTE, RE-12].
- **Exclusiones**: rango de fechas + motivo + efecto (**omitir** o **correr** la fecha; `pxc_desplaza`) [EXISTE].

### 15.3 Medidor: un solo valor [PROPUESTA, resuelve P-13]

- El «cada N unidades» vive solo en la frecuencia (`pme_cada_cantidad`, el que usa la generación).
- `pmh_valor_medidor` y `pmh_unidad_medida` dejan de pedirse. Se rellenan automáticamente con el mismo valor para compatibilidad de lectura.
- El editor muestra, por equipo, el valor actual del medidor y el próximo disparo (`FNC_PLAN_MEDIDOR_ESTADO`), y advierte si un equipo no tiene medidor.

### 15.4 Vista previa en vivo [PROPUESTA, resuelve P-23]

Mientras se edita, el editor muestra las **próximas 6 fechas**, con las excluidas tachadas y su motivo (`FNC_PROGRAMACION_FECHAS` devuelve `DESCARTADA` y `MOTIVO` [EXISTE]). Para medidor y condición muestra el disparador («al llegar a 12.500 h», «cuando la temperatura > 80 °C por 10 min»), no fechas inventadas [EXISTE: criterio de Planificación 360].

Como la función necesita una programación guardada, el editor trabaja sobre la programación privada **en borrador** (se crea con el primer cambio). Por eso no existe el estado «guarde primero».

### 15.5 Lo que NO se pide (decorativo hoy, §3.4)

Alcance, responsables y grupo de la programación, zona horaria, «permite anticipada», «permite atrasada», «desde la última ejecución» y «genera automáticamente».

- La privada se crea con `pro_genera_automaticamente = 1`, el alcance vacío y sin responsables.
- El **quién** se define en la intervención (§11.4), donde sí tendrá efecto.

### 15.6 Calendarios compartidos (Biblioteca)

- Lista de las programaciones **reutilizables** (las que no son privadas de una intervención), con «dónde se usa» [EXISTE: `SEL_PLANIFICACION_PROGRAMACION_USO`]: planes, tareas, pautas.
- Se crean y editan con el mismo editor de frecuencia, en un panel lateral. Al editar se muestra «Usado por N planes, M tareas, K pautas: el cambio afecta a todos» y se exige confirmar [PROPUESTA].
- En una intervención: *Usar calendario compartido* → elegir de la lista. La frecuencia queda en solo lectura, con «Editar en Biblioteca» y «Convertir en propia» (copia privada) [PROPUESTA].
- **Duplicar** [EXISTE: `DuplicarProgramacion`].
- Las tareas recurrentes y las pautas siguen eligiendo de esta lista (sus modales no cambian en el MVP).

### 15.7 Cómo distinguir privada de compartida [PROPUESTA, técnica]

Se necesita una marca. Columna nueva `pro_es_privada BIT NOT NULL DEFAULT 0` en `Programacion`. Las existentes quedan como compartidas (0), y las que cree el Centro, como privadas (1). Los selectores de tareas y pautas listan solo las compartidas.

---

## 16. Inspecciones

### 16.1 Qué existe

- **Pauta** (`Checklist_Plantilla`): versionada (borrador / publicado / retirado); estructura de secciones e ítems con tipos, opciones, **validaciones** (mínimo, máximo, advertencia, crítico; «genera alerta»; «genera hallazgo») y **dependencias** entre ítems; tipo de asignación.
- **Programación de pauta** (`Checklist_Programacion`): versión de la pauta + `Programacion` + **activo o área** + responsable o grupo.
- **Generación** (`GEN_CHECKLIST_OCURRENCIAS`): crea las rondas y las asigna al responsable o grupo. **Solo se invoca desde la página oculta** `ChecklistProgramacions.aspx` (H7).
- **Ejecución** en la app; las respuestas fuera de rango marcan y, si la validación lo pide, **abren el hallazgo automáticamente** (`API_UPS_CHECKLIST_RESPUESTA`).
- **Hallazgo → OT correctiva** (origen HALLAZGO CHECKLIST) o descarte con motivo, desde la bandeja de hallazgos.

### 16.2 Decisión

- **Las pautas siguen siendo un centro especializado.** Su editor (estructura, versiones, validaciones, dependencias) es un dominio propio y complejo, y el planificador no lo usa a diario.
- **En el MVP el Centro no programa pautas.** Pautas y Hallazgos mantienen sus menús.
- **Fase 2 · «Exigir pauta en la intervención» [PROPUESTA, usa tablas en ESQUEMA]:**
  - En una actividad: *Agregar pauta* → elegir una pauta **publicada** + momento (antes / durante / después) + obligatoria.
  - Se guarda en `Plan_Actividad_Checklist`.
  - Al generar la OT se copia a `Orden_Trabajo_Checklist`, y la app ejecuta la pauta como parte de la OT.
  - Los hallazgos de esa ejecución quedan vinculados a la OT de origen (origen 9 «Hallazgo durante otra OT» [EXISTE en el catálogo]).
- **Fuera del Centro:** las rondas autónomas (pauta × activo o área con su propia frecuencia) siguen en el centro de la pauta.

### 16.3 Arreglo previo, fuera del Centro (recomendado para el MVP)

Agregar «Generar rondas (90 días)» en la pestaña *Programaciones* del centro de la pauta, llamando a `ChecklistProgramacionController.GenerarOcurrencias(programacion)`. Hoy, sin entrar por URL a la página oculta, una pauta programada **nunca** produce rondas.

---

## 17. Integración con OT

### 17.1 Qué existe

- **Generación manual**, por ocurrencia o en lote, idempotente (§3.6).
- **Lo que se copia** del plan a la OT (§3.6): pasos, repuestos, permiso, parada, tipo, prioridad, estrategia, origen PLAN y vínculo `otr_plan_mantenimiento_ocurrencia`.
- **Cierre web** → la ocurrencia queda COMPLETADA (motivos «Trabajo realizado» y «Sin hallazgo») u OMITIDA (resuelta en otra OT, duplicada, anulada por error, no aplica).
- **Cierre desde la app** → la ocurrencia **no cambia** (H5).

### 17.2 Decisión: el Centro termina en la OT generada

El Centro **genera** la OT y **muestra** su estado. Asignar técnicos en detalle, ejecutar, registrar mano de obra, evidencias, permisos y cerrar siguen en el centro de la OT.

### 17.3 Cambios propuestos

| # | Cambio | Tipo |
|---|---|---|
| OT-1 | Al generar la OT se crea su asignación con el **responsable** y el **grupo** de la intervención (`Orden_Trabajo_Asignacion`: responsable con `ota_es_responsable = 1`; el grupo como asignación de grupo). Si la intervención no tiene, la OT nace sin asignar, como hoy. | [PROPUESTA] MVP · RP-09 |
| OT-2 | El cierre desde la app aplica a la ocurrencia la misma regla que el cierre web. | [PROPUESTA] **previo al MVP** · RP-12 |
| OT-3 | Sección «OT generadas» en la ficha del plan y filtro **Plan** en el listado de OT (`SEL_ORDEN_TRABAJO` recibe `@PLAN`). | [PROPUESTA] MVP |
| OT-4 | En Ejecuciones, las que tienen OT muestran el **estado de la OT** (abierta, en ejecución, en espera de cierre, cerrada) además de la situación. | [PROPUESTA] MVP |
| OT-5 | **Generación automática de OT** por plan: opción «Crear la OT automáticamente N días antes» en la intervención; la ejecuta la renovación diaria. | [PROPUESTA] Fase 2 · RP-06 |
| OT-6 | La duración estimada de la OT = la de la intervención si existe; si no, la suma de las actividades. | [PROPUESTA] Fase 2 |

---

## 18. Decisión sobre menús actuales

| Menú | Mantener | Transformar | Absorber | Eliminar | Justificación |
|---|:---:|:---:|:---:|:---:|---|
| **Planificación** | | **✔** | | | Se convierte en el **Centro de Planificación**: misma página (`Planificacion.aspx`) y mismo menú (2222), renombrado «Centro de Planificación». Pasa de tablero de 7 pestañas de consulta a workspace de 5 pestañas donde se crea, configura, activa y sigue cada plan. Absorbe el Centro del plan (`PlanMantenimiento.aspx`), que hoy es una página oculta que se abre en otra pestaña del navegador. |
| **Programaciones** | | | **✔** | | La frecuencia se define dentro de la intervención y la Programación pasa a ser un detalle técnico privado (P-01, P-02, P-03). Las reutilizables viven en **Biblioteca → Calendarios compartidos**, con su «dónde se usa». Hoy es menú solo porque quien tiene el permiso 92 y no el 116 perdía la entrada (`BD/297`, `BD/300`); el Centro admite el 92 (RP-15). El menú 2155 pasa a `mnu_visible = 0`; la URL sigue funcionando. |
| **Procedimientos** | | | **✔** | | Es una entidad reutilizable que **se mantiene**, pero su lugar natural es junto a donde se usa: la actividad del plan. Pasa a **Biblioteca → Procedimientos**, con creación y edición en panel lateral desde la actividad (P-09). El menú 2161 pasa a `mnu_visible = 0`. La OT sigue agregando pasos de procedimientos desde su propio centro (no necesita el menú). El Centro admite el permiso 97 (RP-15). |
| **Tareas recurrentes** | **✔** | | | | Es otra cadena: rutina liviana con ejecución propia en la app y **sin OT** (§3.2). Mezclarla con el preventivo con OT es justo la confusión que hay que evitar (P-18). Se mantiene como centro propio; el Centro de Planificación la referencia en el estado vacío y en la Biblioteca («¿una rutina sin OT?»). |
| **Categorías de tarea** | | | **✔** | | Es un catálogo de etiquetas (código, nombre, color) que **solo** usan las tareas recurrentes. Pasa a gestionarse dentro de *Tareas recurrentes* (acción «Categorías» en su listado y alta rápida desde el combo de la tarea). El menú 2218 pasa a `mnu_visible = 0`. *Fase 2* (fuera del camino crítico del Centro). |
| **Pautas de inspección** | **✔** | | | | Es un editor especializado (estructura, ítems, validaciones, dependencias, versiones) que el planificador no usa a diario. Se mantiene como centro propio. En Fase 2 una intervención puede **exigir** una pauta publicada (§16.2). Arreglo previo: botón para generar rondas en su pestaña Programaciones (P-16). |
| **Hallazgos** | **✔** | | | | Es la bandeja operativa del resultado de una inspección: decide si hay OT o descarte. No es planificación. |
| **Fallas** | **✔** | | | | Es mantenimiento reactivo (falla → diagnóstico → acción → OT correctiva). No es planificación. |
| **Órdenes de trabajo** | **✔** | | | | Es la ejecución, donde termina el Centro (§17.2). Se agrega el **filtro por plan** y el regreso al Centro desde una OT de origen PLAN. |

**Páginas ocultas que se retiran** cuando el Centro esté en producción (menú ya en `mnu_visible = 0`; se conserva la URL un sprint con redirección):

| Página | Destino |
|---|---|
| `Planes/PlanMantenimiento.aspx` | Redirige a `Planificacion.aspx#tab=planes&plan={id}` (la usan la ficha del activo, notificaciones y enlaces viejos). |
| `Planes/PlanMantenimientos.aspx` | Redirige a la pestaña Planes. |
| `Planes/PlanOcurrenciaBandeja.aspx` | La exportación a Excel pasa a un método del servicio del Centro; luego se retira. |
| `Planes/PlanVersion.aspx`, `Planes/PlanActividades.aspx` | Se retiran (huérfanas). |
| `Planes/PlanHito.aspx`, `PlanActivo.aspx`, `PlanActividad.aspx` | Las reemplaza la edición inline; se retiran tras el MVP. |
| `Planes/PlanOcurrenciaReprogramar.aspx` | La reemplaza el panel lateral de Ejecuciones. |

**Menú resultante:**

```text
Centro de Mantenimiento
├── Centro de Planificación ....... Planes · Ejecuciones · Cumplimiento · Cobertura · Biblioteca (Procedimientos, Calendarios)
├── Inspección
│   ├── Pautas de inspección
│   └── Hallazgos de inspección
├── Tareas recurrentes ............ (con Categorías adentro, Fase 2)
└── Órdenes de trabajo
    ├── Listado de órdenes
    └── Fallas
```

---

## 19. Entidades y relaciones

### 19.1 Entidades que usa el Centro (todas existen)

| Entidad | Tabla | Rol en el Centro | Relación clave |
|---|---|---|---|
| Plan | `Plan_Mantenimiento` | Unidad que se administra | 1 plan → N versiones |
| Versión | `Plan_Mantenimiento_Version` | Inmutabilidad de lo publicado | ≤ 1 borrador, ≤ 1 publicada por plan |
| Intervención | `Plan_Mantenimiento_Hito` | Qué se hace y cada cuánto | N por versión · 1 → 1 programación |
| Actividad | `Plan_Mantenimiento_Actividad` | Paso de la OT | N por intervención · 0..1 procedimiento |
| Repuesto planificado | `Plan_Actividad_Repuesto` | Repuestos de la OT | N por actividad |
| Equipo del plan | `Plan_Mantenimiento_Activo` | Qué se mantiene | N por versión · único por (versión, activo) como equipo completo y por (versión, activo, componente) por componente (`UX_PAC_VERSION_ACTIVO`, `UX_PAC_VERSION_ACTIVO_COMPONENTE`) |
| Frecuencia / calendario | `Programacion` + `_Calendario`, `_Calendario_Dia`, `_Intervalo`, `_Fecha`, `_Medidor`, `_Condicion`, `_Exclusion` | Cuándo | 1 por intervención (privada) o compartida |
| Marca de generación | `Programacion_Generacion` | Hasta dónde se generó | 1 por programación |
| Ejecución programada | `Plan_Mantenimiento_Ocurrencia` (+ `Plan_Ocurrencia_Historial`) | Lo que hay que hacer, con fecha | intervención × equipo × fecha · 0..1 OT · cadena de reprogramación (`pmo_ocurrencia_origen`) |
| Procedimiento | `Procedimiento` + `Procedimiento_Paso` | Receta | N actividades → 1 versión de procedimiento |
| OT | `Orden_Trabajo` (+ `_Paso`, `_Repuesto`, `_Asignacion`, `_Estado_Historial`) | Resultado del Centro | 1 ejecución → 0..1 OT (`otr_plan_mantenimiento_ocurrencia`) |
| Activo | `Activo`, `Activo_Componente`, `Activo_Medidor` | Equipo, componente, medidor | — |
| Cobertura | (derivada) `SEL_PLANIFICACION_COBERTURA` | Equipos sin plan | — |

### 19.2 Entidades relacionadas fuera del Centro

`Tarea`, `Tarea_Programacion`, `Tarea_Ocurrencia`, `Tarea_Categoria` · `Checklist_Plantilla` y todas las `Checklist_*` · `Checklist_Hallazgo` · `Falla` y anexas. El Centro solo las **referencia**: «dónde se usa» un calendario compartido, y los enlaces de orientación.

### 19.3 Cambios de esquema propuestos [PROPUESTA]

| Cambio | Tabla | Motivo | Fase |
|---|---|---|---|
| `pro_es_privada BIT NOT NULL DEFAULT 0` | `Programacion` | Separar la frecuencia privada de la intervención de los calendarios compartidos (§15.7). | MVP |
| `pmh_usuario_responsable INT NULL → Usuario` | `Plan_Mantenimiento_Hito` | El «quién» de la intervención (RP-09). | MVP |
| `pmh_grupo_trabajo INT NULL → Grupo_Trabajo` | `Plan_Mantenimiento_Hito` | Grupo de apoyo de la intervención (RP-09). | MVP |
| `pmv_motivo_retiro NVARCHAR(400) NULL` | `Plan_Mantenimiento_Version` | Motivo de desactivar (RP-08). | MVP |
| `pmh_ot_dias_anticipacion INT NULL` | `Plan_Mantenimiento_Hito` | Crear la OT automáticamente N días antes (OT-5). | Fase 2 |
| — (usar las existentes) | `Plan_Actividad_Especialidad`, `Plan_Actividad_Checklist`, `Orden_Trabajo_Checklist` | Personas requeridas; pauta dentro de la intervención. | Fase 2 |

`INS_PLAN_VERSION_NUEVA` y el duplicado de planes deben copiar las columnas nuevas del hito.

---

## 20. Casos de uso

> Formato: **Hoy** (pasos reales verificados) → **Propuesto** (comportamiento esperado) · Reglas.

**CU-01 · Crear mantenimiento preventivo.**
- **Hoy:** Programaciones → asistente (6 pasos) → Guardar → Planificación → Planes → *Nuevo plan* (otra pestaña del navegador) → ficha → Guardar (recarga) → modal de hito → modal de actividad → N modales de equipo → Configuración → Publicar → Calendario → Generar ocurrencias (§4.2).
- **Propuesto:** Planes → *Nuevo plan* → nombre → la ficha se abre en el workspace → agregar equipos (selector múltiple) → agregar intervención (nombre + frecuencia inline + actividades + responsable) → la tarjeta «Listo para activar» en verde → **Activar** → resultado «N ejecuciones generadas».
- **Reglas:** RE-01 a RE-05, RE-08, RE-11 · RP-01, RP-05, RP-09, RP-10.

**CU-02 · Asociar un activo.**
- **Hoy:** pestaña Equipos → modal → combo con todos los equipos del cliente → Guardar; el SP rechaza si no calza con el alcance.
- **Propuesto:** «Agregar equipos» → panel lateral prefiltrado por el alcance → marcar uno → Agregar. Componente y medidor opcionales en la misma fila.
- **Reglas:** RE-08.

**CU-03 · Asociar varios activos.**
- **Hoy:** un modal por equipo, o carga masiva por Excel.
- **Propuesto:** el mismo panel, con selección múltiple (y «seleccionar todos los filtrados») → *Agregar seleccionados* → resultado por fila. También desde **Cobertura**: marcar equipos sin plan → «Crear plan con estos equipos» o «Agregar a un plan existente».
- **Reglas:** RE-08 (por equipo) · el aviso de equipo en otro plan (`SEL_PLAN_ACTIVO_COBERTURA`).

**CU-04 · Seleccionar un procedimiento existente.**
- **Hoy:** modal de actividad → combo de procedimientos (última versión) → Guardar.
- **Propuesto:** en la fila de la actividad → «Procedimiento» → buscador con vista previa de los pasos → elegir. O «Agregar desde procedimiento», que crea la actividad.
- **Reglas:** RE-19 (del cliente) · los globales no aparecen en el selector (§13.3).

**CU-05 · Crear un procedimiento nuevo.**
- **Hoy:** salir al menú Procedimientos → crear (código, versión a mano, pasos) → Guardar → volver al plan → reabrir el modal de la actividad → elegirlo.
- **Propuesto:** en la actividad → «Crear procedimiento» → panel lateral (nombre precargado, pasos, importar Excel) → Guardar → queda vinculado, sin salir del plan.
- **Reglas:** RE-20.

**CU-06 · Agregar tareas (actividades).**
- **Hoy:** desplegar el hito → *Nueva actividad* (modal) → Guardar → reabrir para repuestos.
- **Propuesto:** «Agregar actividad» → fila nueva inline (código automático) → nombre, duración y marcas → repuestos en la misma fila. Se guarda sola.
- **Reglas:** RE-09, RE-19 · RP-16.

**CU-07 · Configurar la frecuencia.**
- **Hoy:** asistente de programación aparte. Fecha única, condición y exclusiones exigen guardar primero; el hito elige la programación de un combo.
- **Propuesto:** editor embebido en la intervención: tipo → regla → tolerancia → exclusiones, con vista previa de las próximas 6 fechas en vivo. El sistema crea la programación privada. Opción «Usar calendario compartido».
- **Reglas:** RE-12, RE-21 · RP-01, RP-03, RP-17, RP-18.

**CU-08 · Asignar técnicos.**
- **Hoy:** no se puede en el plan. Cada OT generada se asigna a mano en su centro.
- **Propuesto:** en la intervención, «Quién»: responsable (una persona) + grupo de trabajo. Cada OT generada nace con esa asignación. El detalle por OT se sigue ajustando en el centro de la OT.
- **Reglas:** RP-09.

**CU-09 · Agregar una pauta de inspección.**
- **Hoy:** no es posible dentro del plan (tablas solo en esquema). Las rondas se programan aparte en el centro de la pauta, y se generan solo desde una página oculta.
- **Propuesto MVP:** no se ofrece dentro del Centro. El estado vacío y la Biblioteca orientan a *Pautas de inspección*.
- **Propuesto Fase 2:** en la actividad → *Agregar pauta* (publicada, momento, obligatoria) → se ejecuta con la OT.
- **Reglas:** §16.2.

**CU-10 · Duplicar una planificación.**
- **Hoy:** no existe (solo se duplican programaciones).
- **Propuesto:** acción *Duplicar* → nombre «Copia de …» → opción «incluir equipos» → crea un plan nuevo en *Borrador* con intervenciones, actividades, repuestos y responsables. Las frecuencias privadas se copian como programaciones nuevas; las compartidas se mantienen por referencia.
- **Reglas:** RP-13.

**CU-11 · Modificar una planificación.**
- **Hoy:** Configuración → *Nueva versión* → editar hitos, equipos y actividades en sus modales → *Publicar*. Las ejecuciones futuras de la versión anterior quedan vivas.
- **Propuesto:** editar directamente → borrador implícito con su banner → **Aplicar cambios** con vista del impacto (se cancelan X, se crean Y, se mantienen Z con OT) → confirmar. *Descartar cambios* disponible.
- **Reglas:** RE-03, RE-06, RE-07 · RP-03, RP-04, RP-07.

**CU-12 · Desactivar una planificación.**
- **Hoy:** ficha → «Habilitado = No» → Guardar. Deja de generar, pero las ejecuciones abiertas quedan; no se puede retirar la versión ni eliminar el plan.
- **Propuesto:** *Desactivar* → motivo → impacto (N ejecuciones futuras sin OT se cancelan) → confirmar → *Inactivo*. *Reactivar* lo devuelve a *Activo* y regenera.
- **Reglas:** RP-08.

**CU-13 · Revisar las próximas ejecuciones.**
- **Hoy:** Calendario del plan (solo lo ya generado), Bandeja o Calendario de Planificación; proyección solo en la pestaña Programaciones (hasta 3 fechas).
- **Propuesto:** en la ficha, «Próximas ejecuciones» (las 10 siguientes; proyección si es borrador). En Ejecuciones, vistas Lista, Semana y Mes filtradas por el plan, con generación de OT y reprogramación en panel lateral.
- **Reglas:** RE-11, RE-12, RE-14.

**CU-14 · Ver las OT generadas desde una planificación.**
- **Hoy:** columna OT en el calendario del plan; el listado de OT no filtra por plan.
- **Propuesto:** sección «OT generadas» en la ficha (estado, responsable, filtro rápido) y filtro *Plan* en el listado de OT.
- **Reglas:** OT-3, OT-4.

---

## 21. Reglas de negocio

### 21.1 Reglas existentes (implementadas; fuente entre paréntesis)

| ID | Regla |
|---|---|
| RE-01 | El código del plan es único por cliente; el nombre es obligatorio; la planta debe ser del cliente; el modelo debe ser del tipo indicado. (`INS/UPD_PLAN_MANTENIMIENTO`) |
| RE-02 | Al crear un plan nace su versión 1 en BORRADOR. (`INS_PLAN_MANTENIMIENTO`) |
| RE-03 | Un plan tiene a lo sumo un BORRADOR (`INS_PLAN_VERSION_NUEVA`, error 2) y una PUBLICADA: publicar retira la anterior en la misma transacción. (`UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR`) |
| RE-04 | No se publica una versión sin hitos habilitados. (`UPD_PLAN_VERSION_PUBLICAR`) |
| RE-05 | No se publica una versión sin equipos. (ídem) |
| RE-06 | Si dos usuarios publican a la vez, el segundo recibe «La versión ya no está en borrador». (ídem, `BD/301`) |
| RE-07 | Hitos, actividades y equipos solo se crean, modifican o eliminan sobre la versión en BORRADOR. (`INS/UPD/DEL_PLAN_HITO`, `_ACTIVIDAD`, `_ACTIVO`) |
| RE-08 | El equipo debe estar habilitado, ser del cliente y calzar con el alcance del plan (planta, tipo, modelo); componente y medidor deben ser de ese equipo; un equipo no se repite en la versión. (`INS_PLAN_ACTIVO`, errores 3 a 9) |
| RE-09 | Código de hito único en la versión; código de actividad único en el hito; duraciones > 0; la programación del hito debe existir y ser del cliente. (`INS_PLAN_HITO`, `INS_PLAN_ACTIVIDAD`) |
| RE-10 | No se elimina: un hito que generó mantenciones o que tiene actividades; un equipo de la versión con mantenciones; un plan con mantenciones o con versión publicada. Esas bajas son lógicas. (`DEL_PLAN_HITO`, `DEL_PLAN_ACTIVO`, `DEL_PLAN_MANTENIMIENTO`) |
| RE-11 | Solo generan las versiones PUBLICADAS de planes habilitados, sobre equipos habilitados y programaciones habilitadas. Horizonte de 1 a 730 días (90 por defecto). Idempotente por (hito, equipo, fecha) y (programación, equipo, fecha). La ventana se abre con la hora de la planta de cada equipo. (`GEN_PLAN_OCURRENCIAS`) |
| RE-12 | Fecha disponible = fecha − tolerancia antes; fecha límite = fecha + tolerancia después. La situación (vencida, atrasada, disponible, futura) se calcula contra ellas. (`GEN_PLAN_OCURRENCIAS`, `SEL_PLAN_OCURRENCIA_BANDEJA`) |
| RE-13 | La OT solo se genera desde una ocurrencia PENDIENTE o DISPONIBLE; si ya tiene OT se devuelve esa; el equipo debe tener planta. (`INS_ORDEN_TRABAJO_OCURRENCIA`) |
| RE-14 | Reprogramar: solo pendiente o disponible; motivo obligatorio; fecha distinta y sin chocar con otra del mismo hito y equipo. La vieja pasa a REPROGRAMADA y nace otra con la ventana corrida y la fecha original conservada. El cumplimiento se mide contra la fecha original. (`PLAN_OCURRENCIA_REPROGRAMAR`, `SEL_PLAN_CUMPLIMIENTO`) |
| RE-15 | Al generar la OT, cada actividad es un paso; con procedimiento, un paso por cada paso del procedimiento; un punto de control es obligatorio; sin actividades, el hito es el único paso. (`INS_ORDEN_TRABAJO_OCURRENCIA`) |
| RE-16 | El texto de los pasos se **copia** al generar: cambiar el procedimiento después no altera las OT ya generadas. (ídem) |
| RE-17 | Duración de la OT = la del hito; minutos de parada = esa duración si el hito exige parada; la OT requiere permiso si alguna actividad lo exige; los repuestos se suman por repuesto. (ídem) |
| RE-18 | El técnico finaliza la OT (EN ESPERA DE CIERRE). Cierran solo los perfiles con facultad. Los motivos 1 a 3 (realizado, sin hallazgo, resuelta en otra OT) exigen que la OT esté en espera de cierre; los demás anulan desde cualquier estado. «Trabajo realizado» exige además un resultado de 5 caracteres o más. Los permisos de trabajo sin autorizar impiden cerrar como realizado. El cierre web pasa la ocurrencia a COMPLETADA (motivos 1 y 2) u OMITIDA (los demás). (`UPD_ORDEN_TRABAJO_CERRAR_WEB`, `FNC_USUARIO_PUEDE_CERRAR_OT`) |
| RE-19 | Una actividad que requiere permiso debe indicar el tipo de permiso; el procedimiento de la actividad debe ser del cliente. (`INS_PLAN_ACTIVIDAD`) |
| RE-20 | Procedimiento: la llave es cliente + código + versión; la versión parte en 1; los globales no se editan ni se eliminan; si exige permiso, debe indicar el tipo. (`INS/UPD/DEL_PROCEDIMIENTO`) |
| RE-21 | Programación: nombre único por cliente; inicio obligatorio; fin ≥ inicio; tolerancias ≥ 0; la de condición exige política; alcance jerárquico (área o activo exigen planta); personas o grupo, no ambos. No se deshabilita si la usan hitos. El tipo no cambia después de guardar (en la pantalla). (`INS/UPD/DEL_PROGRAMACION`, `Programacion.aspx.cs`) |
| RE-22 | Por medidor: al registrar una lectura se genera la ocurrencia cuando el contador alcanza el próximo valor (hasta 5 por lectura) y se abre una alerta de aviso al entrar en la anticipación. El medidor sale de la programación, del equipo del plan o, en su defecto, de cualquier medidor del equipo. (`GEN_PLAN_OCURRENCIAS_MEDIDOR`, `FNC_PLAN_MEDIDOR_ESTADO`) |
| RE-23 | Hallazgo: se abre automáticamente si la validación del ítem lo pide (uno por respuesta); la OT solo se genera desde uno pendiente; descartar exige un motivo de 10 caracteres o más. (`API_UPS_CHECKLIST_RESPUESTA`, `INS_ORDEN_TRABAJO_HALLAZGO`, `UPD_CHECKLIST_HALLAZGO_DESCARTAR`) |
| RE-24 | Permisos: ver planes 116, editar planes 117, ver programaciones 92, editar 93, ver procedimientos 97, editar 98, crear OT 102. Cada llamada del servicio vuelve a validar sesión y permiso. (`WsPlanificacion360.cs`, `Token.Puede`) |

### 21.2 Reglas propuestas

| ID | Regla |
|---|---|
| RP-01 | Cada intervención tiene su frecuencia **privada**: el sistema crea la `Programacion` con `pro_es_privada = 1`, `pro_genera_automaticamente = 1`, sin alcance ni responsables, y nombre `«{código plan} · {código intervención}»`. |
| RP-02 | Los selectores de programación de tareas recurrentes y pautas muestran solo las compartidas (`pro_es_privada = 0`). |
| RP-03 | **Copia al escribir:** si se edita la frecuencia de una intervención del borrador y esa programación también la usa una versión PUBLICADA (o cualquier otro uso), se crea una programación privada nueva con los cambios y la intervención del borrador pasa a apuntarla. La versión publicada nunca cambia de calendario sin «Aplicar cambios». |
| RP-04 | **Borrador implícito:** la primera edición sobre un plan *Activo* abre el borrador (`INS_PLAN_VERSION_NUEVA`). *Descartar cambios* da de baja el borrador y deja la versión activa intacta. |
| RP-05 | **Activar** = validar bloqueantes (§11.2) + publicar + generar las ejecuciones del horizonte del cliente (90 días por defecto) para ese plan. Si la generación falla, el plan queda publicado y la ficha muestra «Activo · ejecuciones pendientes de generar» con el botón «Reintentar». No se deshace la publicación. |
| RP-06 | **Renovación diaria (Fase 2):** una tarea programada llama a `POST /plan-ocurrencias/generar` con `solo_automaticas = 1` (y su equivalente para tareas y pautas) para mantener el horizonte. Si la intervención tiene `pmh_ot_dias_anticipacion`, crea la OT cuando falten esos días. |
| RP-07 | **Aplicar cambios:** publicar el borrador y, en la misma operación, tomar las ejecuciones de versiones retiradas del plan que estén PENDIENTES o DISPONIBLES, sin OT y con fecha desde hoy: **(a) traspasar** a la intervención de la versión nueva con el mismo código (`pmh_codigo`) las que conservan la misma programación y cuyo equipo sigue en el plan (`UPDATE pmo_plan_mantenimiento_hito`, con historial «Pasa a la versión N»); **(b) cancelar** las demás (estado 6, historial «Reemplazada por la versión N»); **(c) generar** lo que falte desde la versión nueva. Las que tienen OT no se tocan. El traspaso es obligatorio, no una optimización: el índice único `UX_PMO_PROGRAMACION_ACTIVO_FECHA` impediría regenerar una fecha cancelada con la misma programación. El usuario ve los cuatro conteos (traspasan, se cancelan, se crean, se mantienen) antes de confirmar. |
| RP-08 | **Desactivar:** motivo obligatorio; `pma_habilitado = 0`; la versión publicada pasa a RETIRADO con el motivo; se cancelan las futuras sin OT (historial «Plan desactivado»). **Reactivar:** borrador nuevo copiado de la última versión retirada + publicar; las ejecuciones canceladas por la desactivación con fecha desde hoy **vuelven a PENDIENTE** traspasadas a la versión nueva (mismo motivo de índice que RP-07); después se genera lo que falte. **Eliminar:** solo si el plan nunca generó ejecuciones (RE-10 se mantiene); un plan desactivado sin ejecuciones se puede eliminar. |
| RP-09 | La intervención tiene un **responsable** (una persona) y un **grupo** (opcional). Al generar la OT se crean sus asignaciones: el responsable con `ota_es_responsable = 1` y el grupo como asignación de grupo. |
| RP-10 | «Listo para activar» advierte (sin bloquear) cuando una intervención por medidor incluye equipos sin ningún medidor, y lista esos equipos: con el comportamiento de `FNC_PLAN_MEDIDOR_ESTADO` nunca generarán. |
| RP-11 | Un procedimiento se versiona con *Nueva versión* (copia con versión + 1). Las actividades siguen en la versión anterior hasta que alguien elige «Actualizar a vN»; en planes activos el cambio va al borrador implícito. |
| RP-12 | **Cerrar la OT desde la app** aplica a la ejecución del plan la misma regla que el cierre web (COMPLETADA para motivos 1 y 2; OMITIDA para los demás) y deja historial. |
| RP-13 | **Duplicar plan:** crea un plan nuevo (código automático, nombre «Copia de {nombre}») con la versión 1 en borrador, copiando de la versión vigente (o del borrador si no hay vigente) intervenciones, actividades, repuestos y responsables. Los equipos se copian solo si se pide. Las frecuencias privadas se copian como programaciones nuevas. |
| RP-14 | **Omitir ejecución (Fase 2):** una ejecución PENDIENTE o DISPONIBLE sin OT puede pasar a OMITIDA con motivo obligatorio. Cuenta como no cumplida en el cumplimiento. |
| RP-15 | **Acceso:** el Centro se abre con 116, 92 **o** 97. Planes, Ejecuciones, Cumplimiento y Cobertura exigen 116; Biblioteca → Calendarios exige 92; Biblioteca → Procedimientos exige 97. Escritura: 117 (planes), 93 (calendarios compartidos), 98 (procedimientos), 102 (generar OT). |
| RP-16 | Los códigos de intervención (`INT-nn`) y de actividad (`ACT-nn`) se proponen automáticamente y se pueden editar mientras la versión es borrador. |
| RP-17 | El tipo «Abierta» no se ofrece para una intervención: no generaría nunca. |
| RP-18 | En una frecuencia por medidor el «cada N» se escribe una sola vez (`pme_cada_cantidad`); `pmh_valor_medidor` y `pmh_unidad_medida` se rellenan con ese valor. |
| RP-19 | Editar un calendario compartido muestra sus usos y exige confirmar. «Convertir en propia» crea una copia privada para esa intervención (vía RP-03). |
| RP-20 | El texto «Se generan al publicar la versión» desaparece. El estado vacío de ejecuciones dice la regla real («Se generan al activar el plan» una vez implementado RP-05). |

---

## 22. MVP

### 22.1 Arreglos previos (pequeños, fuera de la interfaz del Centro, de alto impacto)

1. **RP-12:** `UPD_ORDEN_TRABAJO_CERRAR` (cierre desde la app) actualiza la ejecución del plan como el cierre web.
2. **P-16:** botón «Generar rondas (90 días)» en la pestaña Programaciones del centro de la pauta.
3. **RP-20:** quitar el texto engañoso del Centro del plan.

### 22.2 Alcance del MVP

| Área | Incluye |
|---|---|
| Página y menú | `Planificacion.aspx` renombrada «Centro de Planificación» con 5 pestañas. Menús Programaciones y Procedimientos a `mnu_visible = 0`. Acceso con 116, 92 o 97 (RP-15). |
| Pestaña Planes | Lista con buscador, chips de estado y conteos, próxima ejecución y marca de atención. Ficha en el mismo workspace con encabezado, «Listo para activar», Qué mantener, Intervenciones, Próximas ejecuciones, OT generadas e Historial. Estado en la URL. |
| Crear | *Nuevo plan* con solo el nombre; *Crear plan con estos equipos* desde Cobertura; Carga masiva (existente). |
| Equipos | Selector múltiple en panel lateral, prefiltrado por el alcance, con resultado por fila. |
| Intervenciones | Edición inline con código automático; datos de la OT; **frecuencia inline** para Calendario, Intervalo, Fechas puntuales y Medidor, con tolerancias, exclusiones y vista previa en vivo; **responsable y grupo**. Condición: se muestra en lenguaje natural y se edita con el asistente actual en un panel lateral. |
| Actividades | Lista inline con orden, marcas, permiso y **repuestos sin guardar antes**; procedimiento elegido con vista previa; **crear y editar procedimiento en panel lateral** (el panel puede cargar el editor actual `Procedimiento.aspx` en modo panel). |
| Ciclo de vida | **Activar** (RP-05), **borrador implícito** (RP-04), **Aplicar cambios** con impacto y limpieza (RP-07), **Descartar cambios**, **Desactivar / Reactivar** (RP-08), **Duplicar** (RP-13), frecuencia privada con copia al escribir (RP-01, RP-03). |
| OT | Asignación desde la intervención (RP-09), estado de la OT en Ejecuciones (OT-4), sección «OT generadas» y filtro por plan en el listado (OT-3). |
| Ejecuciones | La Bandeja y el Calendario actuales como vistas Lista, Semana y Mes de una sola pestaña. Generar OT en lote; Reprogramar en panel lateral. |
| Cumplimiento y Cobertura | Como hoy, más la selección múltiple en Cobertura. |
| Biblioteca | Procedimientos (lista + panel) y Calendarios compartidos (lista + «dónde se usa» + editor actual en panel). |

### 22.3 Por qué es realista

- **No cambia el modelo de datos**, salvo 4 columnas (§19.3).
- Reutiliza todos los SP de escritura del plan.
- Los SP nuevos son envoltorios: activar, desactivar, reactivar, descartar borrador, duplicar, frecuencia de la intervención, y las lecturas de la lista y la ficha.
- Los editores complejos que no son el camino principal (condición, calendario compartido, procedimiento) se reutilizan dentro de paneles en vez de reescribirse.

---

## 23. Fase 2

| # | Mejora | Referencia |
|---|---|---|
| F2-01 | Renovación diaria del horizonte (tarea programada contra la API) para planes, tareas y pautas. | RP-06 |
| F2-02 | Creación automática de la OT N días antes, por intervención. | OT-5, RP-06 |
| F2-03 | Exigir una pauta publicada dentro de una actividad; ejecutarla con la OT. | §16.2 |
| F2-04 | Personas requeridas por especialidad en la actividad, sumadas por intervención. | `Plan_Actividad_Especialidad` |
| F2-05 | Omitir una ejecución con motivo. | RP-14 |
| F2-06 | Editor inline de frecuencia por condición. | §15.2 |
| F2-07 | Editor de procedimientos nativo en el panel (sin cargar la página antigua); *Nueva versión* con «Actualizar a vN»; *Copiar para usar* en globales. | §13.3, RP-11 |
| F2-08 | «Plan rápido» de una tarjeta. | §12.3 |
| F2-09 | Reordenar intervenciones y actividades arrastrando. | §11.4 |
| F2-10 | *Crear plan* desde la ficha del activo. | §12.1 |
| F2-11 | Categorías de tarea dentro de Tareas recurrentes; retiro del menú 2218. | §18 |
| F2-12 | Duración de la OT = suma de actividades cuando la intervención no la define. | OT-6 |
| F2-13 | Retiro definitivo de las páginas ocultas de §18. | §18 |

---

## 24. Fuera de alcance

**No forma parte del Centro de Planificación** (ni del MVP ni de la Fase 2):

- Ejecución de la OT: asignación detallada, pasos, mano de obra, evidencias, permisos de trabajo, cierre. Sigue en *Órdenes de trabajo*.
- Editor de pautas de inspección (estructura, versiones, validaciones, dependencias) y rondas autónomas.
- Bandeja de hallazgos y fallas.
- Tareas recurrentes (salvo la reubicación de sus categorías en F2-11).
- Cambios en la app móvil (la ejecución no cambia; solo se beneficia de la asignación y del cierre sincronizado).
- Predicción de fallas (SIGMA AI), costos y presupuesto del mantenimiento.

**Futuro** (ideas registradas, sin compromiso):

- Plantillas de planes por fabricante o modelo.
- Nivelación de carga y planificación por capacidad de técnicos.
- Flujo de aprobación de planes (borrador → revisión → activo).
- Sugerencia de frecuencias desde el historial de fallas o la vida útil estimada (SIGMA AI).
- Simulación de la carga anual antes de activar.
- Notificaciones al responsable cuando se generan sus OT.

---

## 25. Criterios de aceptación

> Verificables en el navegador y, cuando se indica, con una consulta a la BD.

**Navegación y estructura**

| ID | Criterio |
|---|---|
| CA-01 | El menú muestra «Centro de Planificación» y **no** muestra Programaciones ni Procedimientos (`mnu_visible = 0` en 2155 y 2161). Sus URLs siguen abriendo. |
| CA-02 | El Centro tiene exactamente 5 pestañas: Planes, Ejecuciones, Cumplimiento, Cobertura, Biblioteca. Cambiar de pestaña no recarga la página ni hace postback. |
| CA-03 | Un usuario con solo el permiso 97 entra al Centro y ve únicamente *Biblioteca → Procedimientos*. Con solo el 92 ve *Biblioteca → Calendarios*. Con el 116 ve las 4 primeras pestañas. |
| CA-04 | Abrir un plan desde la lista no cambia de página ni abre otra pestaña del navegador. La URL refleja el plan elegido, y recargarla vuelve al mismo plan. |

**Crear y configurar**

| ID | Criterio |
|---|---|
| CA-05 | Se puede crear un plan escribiendo solo el nombre. Queda en *Borrador*, con código automático y versión 1 en borrador. |
| CA-06 | **Prueba de flujo:** crear un plan con 1 intervención mensual, 1 actividad con un procedimiento existente y 3 equipos, y activarlo, **sin abrir otra página, otra pestaña del navegador ni un modal** (salvo la confirmación de Activar), y con una sola acción explícita de guardado (Activar). |
| CA-07 | Se agregan 10 equipos en una sola acción desde el panel lateral. Los que no calzan con el alcance muestran el motivo y los demás quedan agregados. |
| CA-08 | La frecuencia se configura dentro de la intervención y la vista previa muestra las próximas 6 fechas sin guardar explícitamente. Las fechas excluidas aparecen tachadas con su motivo. |
| CA-09 | El editor de frecuencia **no** muestra alcance, asignación, zona horaria, «permite anticipada/atrasada», «desde la última ejecución» ni «genera automáticamente». |
| CA-10 | Una intervención por medidor pide el «cada N» una sola vez. En la BD, `pmh_valor_medidor` = `pme_cada_cantidad`. |
| CA-11 | Se crea un procedimiento desde una actividad, en un panel lateral, y al guardarlo queda vinculado a la actividad sin perder la ficha del plan. |
| CA-12 | Se agregan repuestos a una actividad recién creada sin un paso previo de «guardar y reabrir». |

**Activar, modificar, desactivar**

| ID | Criterio |
|---|---|
| CA-13 | «Activar» queda deshabilitado mientras falte un bloqueante (sin equipos, sin intervención habilitada, intervención sin frecuencia, actividad con permiso sin tipo), y la tarjeta dice cuál falta. |
| CA-14 | Después de **Activar**, sin otra acción, existen ejecuciones de los próximos 90 días para todos los equipos del plan (visibles en Ejecuciones y en «Próximas ejecuciones»). |
| CA-15 | Editar un plan *Activo* lo deja en «Activo · cambios sin aplicar» con el banner. Hasta aplicar, las fechas que genera la versión activa **no cambian**: en la BD, la intervención de la versión publicada conserva su `pmh_programacion` y esa programación no fue modificada. |
| CA-16 | «Aplicar cambios» muestra antes de confirmar cuántas ejecuciones traspasan, se cancelan, se crean y se mantienen. Al confirmar: las futuras sin OT con la misma frecuencia y equipo pasan a la intervención de la versión nueva (mismo `pmo_id`, `pmo_plan_mantenimiento_hito` de la versión nueva); las de un equipo quitado o con frecuencia cambiada quedan CANCELADAS; no queda ninguna fecha sin ejecución por choque con `UX_PMO_PROGRAMACION_ACTIVO_FECHA`; las que tienen OT no cambian. Una OT generada después del cambio trae las actividades de la versión nueva. |
| CA-17 | «Descartar cambios» deja el plan *Activo* sin borrador y con la misma versión vigente. |
| CA-18 | «Desactivar» exige motivo, cancela las futuras sin OT y deja el plan *Inactivo*. Una ejecución de generación posterior no crea nada para ese plan. «Reactivar» lo vuelve *Activo*: las ejecuciones futuras canceladas por la desactivación vuelven a PENDIENTE y se genera lo que falte, sin fechas perdidas. |
| CA-19 | «Duplicar» crea un plan nuevo en *Borrador* con las mismas intervenciones, actividades, repuestos y responsables. Sus frecuencias son programaciones **nuevas** (otro `pro_id`) con la misma regla. |

**OT y seguimiento**

| ID | Criterio |
|---|---|
| CA-20 | La OT generada desde una ejecución trae en *Asignación* el responsable (como responsable) y el grupo de su intervención. |
| CA-21 | Cerrar desde la app una OT generada por un plan deja su ejecución en COMPLETADA (motivos 1 y 2) u OMITIDA (los demás), igual que el cierre web. |
| CA-22 | La sección «OT generadas» de la ficha lista exactamente las OT cuyo `otr_plan_mantenimiento_ocurrencia` pertenece al plan, con su estado y responsable. |
| CA-23 | El listado de OT filtra por plan. |
| CA-24 | En Ejecuciones, generar OT para 5 ejecuciones seleccionadas informa el resultado por fila (generada / ya existía / rechazada y por qué) y no duplica si se repite. |
| CA-25 | Reprogramar se hace en un panel lateral con motivo obligatorio, y el cumplimiento sigue midiéndose contra la fecha original. |

**Calidad**

| ID | Criterio |
|---|---|
| CA-26 | El Centro no usa UpdatePanel ni RadGrid y corre con ViewState apagado. Las acciones validan sesión y permiso en el servidor en cada llamada. |
| CA-27 | La interfaz cumple el estándar de `CLAUDE.md`: un primario morado por grupo, turquesa para Generar OT y Reprogramar, contorno azul para abrir, sin degradados en cabeceras, foco turquesa visible con teclado. Las fechas usan el calendario de SIGMA (no `type=date`). |
| CA-28 | Con 200 planes y 2.000 ejecuciones abiertas, la pestaña Planes y la ficha de un plan cargan en menos de 2 segundos. La lista se resuelve con una sola consulta, no una por plan. |
| CA-29 | No aparece el texto «Se generan al publicar la versión» en ninguna pantalla. |

---

## 26. Recomendaciones de implementación

### 26.1 Orden sugerido

1. **Arreglos previos** (§22.1): son independientes del diseño y corrigen datos que el Centro va a mostrar.
2. **BD:**
   - Columnas de §19.3.
   - SP nuevos (§26.2).
   - Modificaciones (§26.3).
   - Script de migración de programaciones (§26.5).
   - Script de menús: `UPDATE Menus` con `mnu_visible = 0` y el renombre. Los menús nunca se borran: la seguridad es por datos.
3. **Servicio:** `WsCentroPlanificacion.asmx` nuevo para las **escrituras** del Centro, con el mismo patrón que `WsPlanificacion360` (JSON, sin ViewState, `Token.Puede` en cada método). `WsPlanificacion360` sigue sirviendo las lecturas de Ejecuciones, Cumplimiento y Cobertura.
4. **Interfaz:** `Planificacion.aspx` + `Js/sigma-centro-planificacion.js` + `Css/LookAndFeel/sigma-centro-planificacion.css`, sobre la cáscara de Planificación 360.
5. **Redirecciones y retiro** de las páginas de §18.

### 26.2 SP nuevos [PROPUESTA]

| SP | Qué hace |
|---|---|
| `SEL_PLAN_CENTRO` | La lista de planes en **una** consulta: estado derivado (§8.3), versión vigente y borrador, conteos, próxima ejecución, vencidas y atrasadas, responsables. Reemplaza el N+1 actual de `WsPlanificacion360.Planes()`, que por cada plan consulta versiones, cumplimiento y calendario. |
| `SEL_PLAN_FICHA` | Varios result sets: plan, versión vigente y borrador, intervenciones con su frecuencia (texto + próximas fechas), actividades, repuestos, equipos con cobertura, próximas ejecuciones y OT generadas. |
| `UPS_PLAN_HITO_FRECUENCIA` | Crea o actualiza la programación privada de una intervención del borrador, con su detalle según el tipo. Aplica la copia al escribir (RP-03). Devuelve la proyección. |
| `UPD_PLAN_ACTIVAR` | Valida los bloqueantes de §11.2 (los de RE-04, RE-05 y RE-19), ejecuta `UPD_PLAN_VERSION_PUBLICAR`, traspasa y cancela según RP-07 y ejecuta `GEN_PLAN_OCURRENCIAS @PLAN`. Devuelve los conteos. Sirve también para «Aplicar cambios». |
| `SEL_PLAN_IMPACTO` | Conteos de RP-07 / RP-08 para la confirmación, sin escribir. |
| `UPD_PLAN_DESACTIVAR` / `UPD_PLAN_REACTIVAR` | RP-08. |
| `DEL_PLAN_VERSION_BORRADOR` | «Descartar cambios» (RP-04). |
| `INS_PLAN_DUPLICAR` | RP-13. Reutiliza la lógica de copia de `INS_PLAN_VERSION_NUEVA`. |

### 26.3 SP existentes que cambian [PROPUESTA]

| SP | Cambio |
|---|---|
| `INS_ORDEN_TRABAJO_OCURRENCIA` | Crear `Orden_Trabajo_Asignacion` desde el responsable y el grupo de la intervención (RP-09). |
| `UPD_ORDEN_TRABAJO_CERRAR` | Sincronizar la ejecución (RP-12). |
| `SEL_ORDEN_TRABAJO` | Parámetro `@PLAN` (OT-3). |
| `INS/UPD_PLAN_HITO`, `INS_PLAN_VERSION_NUEVA` | Responsable y grupo; código automático si viene vacío (RP-16). |
| `INS_PLAN_ACTIVIDAD` | Código automático si viene vacío. |
| `SEL_PROGRAMACION`, `SEL_PROGRAMACION_CATALOGO` | Excluir las privadas en los selectores de tareas y pautas (RP-02). |
| `SEL_PLAN_OCURRENCIA_BANDEJA` | Devolver el estado de la OT (OT-4). |

### 26.4 Convenciones del proyecto que aplican

- Leer los **PATRONES/ASP** del proyecto antes de la primera línea de SQL o C#.
- Archivos en UTF-8 con BOM y CRLF; todo `<button>` dentro del form lleva `type="button"`.
- Compilar con `aspnet_compiler` después de tocar C#. Aplicar SQL con `_scratch/aplicar_sql.py`, usando `-I` cuando el SP use `FOR XML` o índices filtrados (QUOTED_IDENTIFIER).
- Fechas con el calendario de SIGMA (`.sigma-modal-fecha` + `SigmaCalendario.conectar()` tras pintar), nunca `type=date` o `type=time`.
- Paneles laterales con el componente de modal y panel existente del sitio. Los editores reutilizados (`Procedimiento.aspx`, `Programacion.aspx`) se cargan en modo panel (`Simple.master`).
- Actualizar `MD/SIGMA_ESTADO_DESARROLLO.md` al cerrar cada bloque.

### 26.5 Migración de programaciones existentes

Marcar `pro_es_privada = 1` **solo** cuando todos los usos de la programación sean hitos de **un mismo plan con el mismo código de hito** (las versiones copian la referencia) y no la usen tareas ni pautas. El resto queda compartido y aparece en *Biblioteca → Calendarios*, con su «dónde se usa». Así no cambia el comportamiento de nada que ya genera.

Las compartidas que usan **dos o más planes sobre un mismo equipo** se marcan en la Biblioteca con la advertencia «Choque: solo uno de los planes genera cada fecha» (P-03) y la acción «Convertir en propia» en cada intervención afectada.

### 26.6 Riesgos

| Riesgo | Mitigación |
|---|---|
| Activar un plan grande genera muchas filas (equipos × fechas). | `GEN_PLAN_OCURRENCIAS` ya es por conjunto e idempotente. Horizonte de 90 días por defecto; el resultado se informa con conteos. |
| Cancelar ejecuciones al aplicar cambios borra trabajo que alguien esperaba. | Primero se traspasa todo lo que conserva frecuencia y equipo; solo se cancela lo que ya no corresponde, sin OT y desde hoy. El usuario ve los conteos antes. El historial dice «Pasa a la versión N» o «Reemplazada por la versión N». |
| El índice único (programación, equipo, fecha) bloquea regenerar fechas canceladas. | Por eso RP-07 y RP-08 **traspasan o reabren** en vez de cancelar y regenerar. Hay que probarlo con un cambio que solo toque actividades (misma frecuencia). |
| Usuarios con permisos sueltos (92, 97) pierden su entrada al ocultar los menús. | RP-15. El criterio CA-03 se verifica antes de ocultar los menús. |
| Enlaces viejos a `PlanMantenimiento.aspx` (ficha del activo, notificaciones, correos). | Redirección durante al menos un sprint (§18). |
| El estado derivado del plan no coincide con lo que ve el usuario en otros lugares. | Una sola fuente: `SEL_PLAN_CENTRO`. La ficha del activo y Planificación leen el mismo estado. |

### 26.7 Pruebas

- Cada criterio de §25 es un caso de prueba, con evidencia en el informe del sprint correspondiente.
- Casos de regresión obligatorios:
  - La generación por medidor sigue funcionando con la programación privada.
  - El cumplimiento contra la fecha original no cambia.
  - La idempotencia de Generar OT.
  - Las tareas recurrentes y las pautas siguen eligiendo programaciones (solo las compartidas).
