# EP-09 · Planes de mantenimiento

> Trasladar el plan anual de la planta al sistema y que genere el trabajo por sí solo.

**Manual de operación.** Cómo se usa este módulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, así que dice lo mismo que hace el sistema.


## 1. Dónde está en el menú

| Pantalla | Ruta en el menú | Permiso que exige |
|---|---|---|
| Planificación | Centro de Mantenimiento › Planificación | Ver planes de mantenimiento |
| Bandeja de mantenciones *(no aparece en el menú; se abre desde otra pantalla)* | Centro de Mantenimiento › Planificación › Bandeja de mantenciones | Ver planes de mantenimiento |
| Planes de mantenimiento *(no aparece en el menú; se abre desde otra pantalla)* | Centro de Mantenimiento › Planificación › Planes de mantenimiento | Ver planes de mantenimiento |
| Plan de mantenimiento (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Centro de Mantenimiento › Planificación › Plan de mantenimiento (detalle) | Ver planes de mantenimiento |
| Hito de plan (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Centro de Mantenimiento › Planificación › Hito de plan (detalle) | Ver planes de mantenimiento |
| Equipo de plan (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Centro de Mantenimiento › Planificación › Equipo de plan (detalle) | Ver planes de mantenimiento |
| Carga masiva de planes *(no aparece en el menú; se abre desde otra pantalla)* | Centro de Mantenimiento › Planificación › Carga masiva de planes | Ver planes de mantenimiento |
| Versiones del plan (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Centro de Mantenimiento › Planificación › Versiones del plan (detalle) | Ver planes de mantenimiento |
| Reprogramar ocurrencia (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Centro de Mantenimiento › Planificación › Reprogramar ocurrencia (detalle) | Ver planes de mantenimiento |
| Actividades del hito (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Centro de Mantenimiento › Planificación › Actividades del hito (detalle) | Ver planes de mantenimiento |
| Actividad de hito (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Centro de Mantenimiento › Planificación › Actividad de hito (detalle) | Ver planes de mantenimiento |


## 2. Qué permisos hacen falta

Sin estos permisos el módulo no se ve, y la acción se rechaza en el servidor aunque se intente por otra vía:

- **Ver planes de mantenimiento**


## 3. Qué tiene que existir antes

Este módulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operación:

- `HU-031` — Administrar modelos de activo
- `HU-042` — Configurar el medidor de un activo
- `HU-062` — Definir los pasos de un procedimiento
- `HU-073` — Crear una programación por medidor
- `HU-076` — Generar las ocurrencias de forma automática
- `HU-080` — Crear un plan de mantenimiento
- `HU-081` — Definir los hitos de un plan
- `HU-082` — Definir las actividades de un hito
- `HU-083` — Asociar activos a un plan
- `HU-084` — Publicar una versión del plan


## 4. Paso a paso


### HU-080 · Crear un plan de mantenimiento

**Para qué.** Como planificador, definir un plan de mantenimiento para una familia de equipos, dejar de administrar el plan anual en una planilla.

*Web · Sprint 4*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Código del plan | Texto | Sí | Único por cliente |
| Nombre | Texto | Sí | Ejemplo: Plan preventivo Blower Aerzen GM10S |
| Planta | Lista desplegable | No | Vacío indica que aplica a todas las plantas |
| Tipo de activo | Lista desplegable | No | Del árbol de tipos |
| Modelo | Lista desplegable dependiente del tipo | No | Modelos del tipo seleccionado |
| Planificador responsable | Lista desplegable | No | Usuarios habilitados del cliente |
| Descripción | Texto multilinea | No | Sin límite |

**Cómo saber que quedó bien:**

1. **Alta de plan** — Cuando creo un plan con código y nombre Entonces se crea automáticamente su versión 1 en estado borrador Y su código es único dentro del cliente
2. **Plan por tipo o modelo** — Cuando asocio el plan al modelo GM10S Entonces al agregar activos solo se ofrecen los equipos de ese modelo


### HU-081 · Definir los hitos de un plan

**Para qué.** Como planificador, agrupar las actividades del plan en hitos programados, que al llegar a las 500 horas se genere una sola orden con todas sus actividades.

*Web · Sprint 4*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Código del hito | Texto | Sí | Único dentro de la versión. Ejemplo: H500 |
| Nombre | Texto | Sí | Ejemplo: 500 HRS |
| Orden | Numérico entero | Sí | Mayor o igual a 1 |
| Recurrencia | Abre el asistente de programación | Sí | Obligatoria |
| Valor del medidor | Numérico decimal | No | Ejemplo: 500 |
| Unidad | Lista desplegable | No | Horas o ciclos |
| Es overhaul | Interruptor | No | Desactivado por defecto |
| Requiere parada del equipo | Interruptor | No | Desactivado por defecto |
| Duración estimada (minutos) | Numérico entero | No | Mayor que cero |
| Tipo de orden que genera | Lista desplegable | No | Preventiva por defecto |
| Prioridad de la orden | Lista desplegable | No | Del catálogo de prioridades |

**Cómo saber que quedó bien:**

1. **Alta de hito** — Cuando creo el hito 500 HRS y le asocio una programación por medidor cada 500 horas Entonces al alcanzarse las horas se genera una ocurrencia de ese hito
2. **Hito sin programación** — Cuando intento guardar un hito sin programación asociada Entonces la operación es rechazada con "El hito debe tener una recurrencia definida"
3. **Una orden por hito** — Dado un hito con cuatro actividades Cuando se materializa la ocurrencia Entonces se genera una única orden de trabajo con cuatro pasos Y no se generan cuatro órdenes separadas
4. **Hito de overhaul** — Cuando marco un hito como overhaul que requiere parada Entonces la orden generada indica que el equipo debe detenerse


### HU-082 · Definir las actividades de un hito

**Para qué.** Como planificador, detallar que se hace en cada hito, que el técnico reciba la instrucción concreta y los repuestos que va a necesitar.

*Web · Sprint 4*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Código | Texto | Sí | Único dentro del hito |
| Nombre | Texto | Sí | Ejemplo: Cambio de filtro de aire |
| Orden | Numérico entero, reordenable arrastrando | Sí | Mayor o igual a 1 |
| Procedimiento | Lista desplegable con buscador | No | Procedimientos del cliente |
| Instrucción | Texto enriquecido con dictado | No | Sin límite |
| Duración estimada (minutos) | Numérico entero | No | Mayor que cero |
| Obligatoria | Interruptor | Sí | Activada por defecto. Desactivada equivale a "a evaluar" |
| Requiere parada | Interruptor | No | Desactivado por defecto |
| Requiere permiso de trabajo | Interruptor | No | Desactivado por defecto |
| Tipo de permiso | Lista desplegable | No | Del catálogo de tipos de permiso |
| Repuestos que consume | Grilla: repuesto, cantidad, obligatorio | No | Cantidad mayor que cero |
| Especialidades requeridas | Grilla: especialidad, cantidad de personas | No | Cantidad mayor o igual a 1 |
| Checklists exigidos | Grilla: plantilla, momento, obligatorio | No | Momento: antes, durante o después |

**Cómo saber que quedó bien:**

1. **Alta de actividad** — Cuando agrego la actividad Cambio de filtro de aire al hito 500 HRS Entonces esa actividad se convierte en un paso de la orden generada
2. **Actividad a evaluar** — Cuando desmarco la actividad como obligatoria Entonces el técnico puede indicarla como no aplica en terreno Y la actividad permanece registrada en el plan
3. **Repuestos de la actividad** — Cuando asocio un repuesto con su cantidad a la actividad Entonces la orden generada incluye ese repuesto como cantidad planificada
4. **Permiso requerido** — Cuando marco que la actividad requiere permiso de trabajo Entonces se exige indicar el tipo de permiso Y la orden generada queda marcada como que requiere permiso


### HU-083 · Asociar activos a un plan

**Para qué.** Como planificador, indicar a qué equipos aplica el plan, aplicar un mismo plan a varias máquinas identicas sin duplicarlo.

*Web · Sprint 4*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Activos | Selección múltiple con filtro por tipo, modelo y área | Sí | Al menos un activo |
| Horómetro a utilizar | Lista desplegable por fila | No | Medidores del activo seleccionado |
| Componente | Lista desplegable por fila | No | Componentes del activo seleccionado |

**Cómo saber que quedó bien:**

1. **Selección múltiple** — Cuando selecciono cuatro blowers para el plan Entonces el plan genera ocurrencias independientes para cada uno
2. **Horómetro por activo** — Cuando indico contra que horómetro se cuentan los hitos de cada activo Entonces cada equipo dispara según su propio uso
3. **Activo ya cubierto** — Cuando agrego un activo que ya está cubierto por otro plan vigente del mismo tipo Entonces se advierte cuál es el otro plan Y se permite continuar


### HU-084 · Publicar una versión del plan

**Para qué.** Como planificador, publicar el plan para que empiece a generar trabajo, que el contenido quede congelado y las órdenes históricas sean reconstruibles.

*Web · Sprint 4*

**Cómo saber que quedó bien:**

1. **Publicación** — Cuando publico una versión en borrador Entonces la versión publicada anterior pasa a retirada Y ambas transiciones ocurren en la misma operación Y queda registrado quién publicó y en qué fecha
2. **Plan sin hitos** — Cuando intento publicar una versión sin hitos Entonces la operación es rechazada con "No se puede publicar una versión sin hitos"
3. **Plan sin activos** — Cuando intento publicar una versión sin activos asociados Entonces la operación es rechazada con "No se puede publicar una versión sin activos"
4. **Publicación simultanea** — Cuando dos usuarios publican la misma versión al mismo tiempo Entonces uno publica y el otro recibe "La versión ya no está en borrador"
5. **Versión publicada es inmutable** — Cuando intento modificar una versión publicada Entonces la edición no está disponible Y se ofrece crear la versión siguiente


### HU-086 · Reprogramar una ocurrencia indicando el motivo

**Para qué.** Como planificador, mover una mantención de fecha dejando registro, que el indicador de cumplimiento no se pueda maquillar moviendo fechas.

*Web · Sprint 4*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Fecha nueva | Selector de fecha y hora | Sí | Distinta de la fecha actual de la ocurrencia |
| Motivo de la reprogramación | Texto multilinea | Sí | Mínimo 10 caracteres |

**Cómo saber que quedó bien:**

1. **Reprogramación con rastro** — Dado una ocurrencia programada para el 12 de marzo Cuando la reprogramo al 19 de marzo indicando el motivo Entonces la ocurrencia original queda en estado reprogramada Y la nueva conserva la referencia a la original y su fecha programada inicial
2. **Medición del cumplimiento** — Cuando se calcula el indicador de cumplimiento Entonces se mide contra la fecha programada original y no contra la nueva
3. **Motivo obligatorio** — Cuando intento reprogramar sin indicar motivo Entonces la operación es rechazada


### HU-087 · Consultar la bandeja de ocurrencias pendientes

**Para qué.** Como planificador, ver qué mantenciones están por vencer o vencidas, anticiparme antes de que el trabajo se acumule.

*Web · Sprint 4*

**Cómo saber que quedó bien:**

1. **Bandeja de pendientes** — Cuando abro la bandeja Entonces veo las ocurrencias pendientes ordenadas por fecha Y cada una indica si está futura, disponible, atrasada o vencida
2. **Situación derivada** — Dado una ocurrencia cuya fecha límite ya paso y no fue completada Entonces se presenta como vencida Y esa condición se calcula al consultar, no depende de un proceso nocturno
3. **Generar la orden** — Cuando selecciono una ocurrencia disponible y genero la orden Entonces la orden se crea con los pasos del hito Y la ocurrencia queda enlazada a esa orden


### HU-085 · Consultar el calendario anual de mantenimiento

**Para qué.** Como jefe de mantenimiento, ver en un calendario todo el mantenimiento planificado del año, coordinar las paradas de planta con producción.

*Web · Sprint 4*

**Cómo saber que quedó bien:**

1. **Vista de calendario** — Cuando abro el calendario anual Entonces veo las ocurrencias distribuidas por mes con su activo y su hito Y puedo filtrar por planta, área, activo y tipo de trabajo
2. **Ocurrencias que requieren parada** — Cuando filtro por trabajos que requieren parada Entonces se muestran solo esas ocurrencias
3. **Carga por semana** — Cuando cambio a la vista semanal Entonces veo la cantidad de horas estimadas por semana


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la acción se intente desde la API o desde la app.

- **HU-081 · Hito sin programación** — Cuando intento guardar un hito sin programación asociada Entonces la operación es rechazada con "El hito debe tener una recurrencia definida"
- **HU-083 · Activo ya cubierto** — Cuando agrego un activo que ya está cubierto por otro plan vigente del mismo tipo Entonces se advierte cuál es el otro plan Y se permite continuar
- **HU-084 · Plan sin hitos** — Cuando intento publicar una versión sin hitos Entonces la operación es rechazada con "No se puede publicar una versión sin hitos"
- **HU-084 · Plan sin activos** — Cuando intento publicar una versión sin activos asociados Entonces la operación es rechazada con "No se puede publicar una versión sin activos"
- **HU-086 · Motivo obligatorio** — Cuando intento reprogramar sin indicar motivo Entonces la operación es rechazada


## 6. Si algo no funciona

| Síntoma | Causa más probable |
|---|---|
| No aparece la opción en el menú | Falta el permiso de la sección 2, o la pantalla no tiene su fila en `Menus` |
| La pantalla abre pero el botón no hace nada | Falta el permiso de la función (ver ≠ crear y editar) |
| Dice que no se puede guardar sin más detalle | Alguna regla de la sección 5; el mensaje viene del procedimiento almacenado |
| Los combos salen vacíos | Falta construir lo de la sección 3 |

---

*Generado desde `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx` y la tabla `Menus`. Para actualizarlo: `python _scratch/gen_manuales.py`.*
