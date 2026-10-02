# EP-11 · Tareas

> Registrar el trabajo programable que no interviene una máquina.

**Manual de operación.** Cómo se usa este módulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, así que dice lo mismo que hace el sistema.


## 1. Dónde está en el menú

| Pantalla | Ruta en el menú | Permiso que exige |
|---|---|---|
| Tareas recurrentes | Centro de Mantenimiento › Tareas › Tareas recurrentes | Ver tareas recurrentes |
| Categorías de tarea | Centro de Mantenimiento › Tareas › Categorías de tarea | Ver tareas recurrentes |
| Tarea (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Centro de Mantenimiento › Tareas › Tarea (detalle) | Ver tareas recurrentes |
| Programación de tarea (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Centro de Mantenimiento › Tareas › Programación de tarea (detalle) | Ver tareas recurrentes |
| Categoría de tarea (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Centro de Mantenimiento › Tareas › Categoría de tarea (detalle) | Ver tareas recurrentes |


## 2. Qué permisos hacen falta

Sin estos permisos el módulo no se ve, y la acción se rechaza en el servidor aunque se intente por otra vía:

- **Ver tareas recurrentes**


## 3. Qué tiene que existir antes

Este módulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operación:

- `HU-070` — Crear una programación de fecha única
- `HU-100` — Administrar categorías de tarea
- `HU-101` — Crear una tarea
- `HU-102` — Programar una tarea recurrente
- `HU-103` — Ejecutar una tarea en terreno


## 4. Paso a paso


### HU-103 · Ejecutar una tarea en terreno

**Para qué.** Como técnico de mantenimiento, completar una tarea desde el teléfono, dejar registro de lo hecho sin volver a la oficina.

*App · Sprint 6*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Resultado | Texto multilinea con dictado por voz | Sí | Mínimo 10 caracteres |
| Resultado conforme | Botones de opción: Conforme / No conforme | Sí | Una única selección |
| Evidencias | Cámara, hasta 5 imágenes | No | JPG, máximo 4 MB por imagen |
| Duración real (minutos) | Numérico entero | No | Mayor que cero |

**Cómo saber que quedó bien:**

1. **Ejecución de la tarea** — Cuando registro el resultado y finalizo Entonces la ocurrencia queda completada con su duración y su ejecutor
2. **Evidencia obligatoria** — Dado que la tarea requiere evidencia Cuando intento finalizar sin fotografía Entonces se indica que falta la evidencia y no se permite finalizar
3. **Ejecución sin conexión** — Dado que estoy sin señal Entonces la tarea se completa localmente y se sincroniza al recuperar conexión


### HU-101 · Crear una tarea

**Para qué.** Como planificador, registrar un trabajo que no interviene un equipo, que ese trabajo también quede planificado y verificado.

*Web · Sprint 4*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Código | Texto | Sí | Único por cliente |
| Título | Texto | Sí | Máximo 200 caracteres |
| Categoría | Lista desplegable | No | Categorías de tarea del cliente |
| Planta | Lista desplegable | No | Plantas del cliente |
| Área | Lista desplegable dependiente | No | Áreas de la planta |
| Activo | Lista desplegable con buscador | No | Activos del cliente |
| Prioridad | Lista desplegable | Sí | Del catálogo de prioridades de tarea |
| Descripción | Texto multilinea con dictado | No | Sin límite |
| Duración estimada (minutos) | Numérico entero | No | Mayor que cero |
| Requiere evidencia | Interruptor | No | Desactivado por defecto |
| Checklists exigidos | Grilla: plantilla, momento, obligatorio | No | Momento: antes, durante o después |

**Cómo saber que quedó bien:**

1. **Alta de tarea** — Cuando creo una tarea con título, categoría y prioridad Entonces queda disponible para programarse o asignarse directamente Y su código es único dentro del cliente
2. **Tarea asociada a un equipo** — Cuando asocio la tarea a un activo Entonces la tarea aparece en el historial del activo Y no se contabiliza en los indicadores de mantenimiento


### HU-102 · Programar una tarea recurrente

**Para qué.** Como planificador, programar la repetición de una tarea, que la revisión mensual de extintores aparezca sola en la bandeja.

*Web · Sprint 4*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Recurrencia | Abre el asistente de programación | Sí | Obligatoria |
| Responsable | Lista desplegable de usuarios | No | Usuarios habilitados |
| Grupo de trabajo | Lista desplegable | No | Grupos del cliente |

**Cómo saber que quedó bien:**

1. **Programación de la tarea** — Cuando asocio una programación a la tarea Entonces se generan ocurrencias según la recurrencia definida
2. **Tarea con varias fechas** — Cuando defino una programación de fecha única con cuatro fechas Entonces se generan cuatro ocurrencias independientes Y cada una tiene su propia ejecución y evidencias


### HU-100 · Administrar categorías de tarea

**Para qué.** Como administrador del cliente, clasificar las tareas según las categorías de mi planta, poder agrupar y filtrar el trabajo no asociado a equipos.

*Web · Sprint 4*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Código | Texto | Sí | Único por cliente |
| Nombre | Texto | Sí | Ejemplo: Aseo técnico, Seguridad, Inventario |
| Color | Selector de color | No | Código hexadecimal |
| Orden | Numérico entero | No | Define la posición en las listas |

**Cómo saber que quedó bien:**

1. **Alta de categoría** — Cuando creo una categoría con nombre y color Entonces queda disponible al crear tareas Y el color se usa en el calendario del planificador


### HU-104 · Comentar una tarea

**Para qué.** Como usuario de mantenimiento, dejar comentarios en el hilo de una tarea, coordinar sin salir del sistema y conservar lo que se acordó.

*Web y App · Sprint 4*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Comentario | Texto multilinea con dictado por voz | Sí | Mínimo 3 caracteres |

**Cómo saber que quedó bien:**

1. **Comentario en el hilo** — Cuando escribo un comentario Entonces queda registrado con mi nombre y la fecha Y no puede editarse ni eliminarse después
2. **Respuesta a un comentario** — Cuando respondo a un comentario existente Entonces la respuesta se muestra anidada bajo el comentario original


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la acción se intente desde la API o desde la app.

- **HU-103 · Evidencia obligatoria** — Dado que la tarea requiere evidencia Cuando intento finalizar sin fotografía Entonces se indica que falta la evidencia y no se permite finalizar
- **HU-104 · Comentario en el hilo** — Cuando escribo un comentario Entonces queda registrado con mi nombre y la fecha Y no puede editarse ni eliminarse después


## 6. Si algo no funciona

| Síntoma | Causa más probable |
|---|---|
| No aparece la opción en el menú | Falta el permiso de la sección 2, o la pantalla no tiene su fila en `Menus` |
| La pantalla abre pero el botón no hace nada | Falta el permiso de la función (ver ≠ crear y editar) |
| Dice que no se puede guardar sin más detalle | Alguna regla de la sección 5; el mensaje viene del procedimiento almacenado |
| Los combos salen vacíos | Falta construir lo de la sección 3 |

---

*Generado desde `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx` y la tabla `Menus`. Para actualizarlo: `python _scratch/gen_manuales.py`.*
