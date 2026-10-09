# Prompt para Claude Code · Rediseño del menú Mantenimiento (5 lugares)

> Referencia visual y de comportamiento: `docs/rediseno-mantenimiento/sigma-mantenimiento-referencia.html` (ábrela en el navegador; todo es navegable y con datos de ejemplo).

> Análisis previo: Claude Doc «SIGMA · Blueprint funcional del menú Mantenimiento».

> Este prompt **no reemplaza** a `docs/rediseno-planificacion/prompt-claude-code-planes-por-pasos.md`: la ficha de plan por pasos se mantiene tal cual y queda dentro de **Planificación › Planes**.

---

## 1. Objetivo

Reordenar el menú Mantenimiento de SIGMA en **cinco lugares**, sin duplicar pantallas ni datos:

| Lugar | Pregunta que responde | Contenido |

|---|---|---|

| **Operación** | ¿Qué pasa hoy y qué está atrasado? | Monitoreo · Ejecuciones (planes + rondas + tareas) · Cumplimiento |

| **Órdenes de trabajo** | ¿Qué trabajo se ejecuta y en qué estado está? | Lista única de OT + ficha de OT |

| **Avisos** | ¿Qué se detectó y todavía no es trabajo? | Bandeja única: fallas, hallazgos de ronda, hallazgos en OT, predicciones, alertas |

| **Planificación** | ¿Qué se hace, cada cuánto y quién? | Planes · Rondas de inspección · Tareas recurrentes · Cobertura |

| **Biblioteca** | ¿Qué se reutiliza? | Procedimientos · Pautas de inspección · Calendarios compartidos · Ajustes |

Regla de oro: **en el trabajo diario, ningún flujo pide más de 3 lugares**. Todo enlace «Viene de» y «Abrir OT» lleva al lugar real, no a una copia.

---

## 2. Antes de escribir código (obligatorio)

1. Lee `CLAUDE.md` (paleta, botones por función, vocabulario «activo», nunca «equipo»).
2. Revisa los scripts de menú `BD/270*` y `BD/385*` y lista las filas actuales del menú Mantenimiento.
3. Revisa en `View/Mantenimiento/`: `Checklist/*`, `Fallas/*`, `Hallazgos/*`, `Ordenes/*`, `Planes/*`, `Procedimientos/*`, `Programaciones/*`, `Tareas/*`.
4. Confirma en BD: `Orden_Trabajo_Origen` (1 Manual, 2 Plan, 3 Tarea, 4 Hallazgo checklist, 5 Predicción, 6 Alerta, 7 Falla, 8 Bitácora, 9 Hallazgo en OT), las FK `otr_*` de `Orden_Trabajo`, `toc_orden_trabajo`, `pmo_orden_trabajo`, `Checklist_Hallazgo` y `Falla`.
5. Entrega un plan corto (pantallas que se crean, se mueven o se ocultan; scripts SQL) **antes** de implementar.

---

## 3. Menú

Sidebar › Mantenimiento con exactamente estos sub-ítems, en este orden:

1. Operación → `View/Mantenimiento/Operacion/Operacion.aspx` (nueva; contenedor con pestañas)
2. Órdenes de trabajo → `Ordenes/OrdenesTrabajo.aspx` (existente, rediseñada)
3. Avisos → `Avisos/Avisos.aspx` (nueva; vista unificada) · badge rojo con avisos sin tratar
4. Planificación → Centro de Planificación existente, con las pestañas nuevas
5. Biblioteca → `Biblioteca/Biblioteca.aspx` (nueva; contenedor con pestañas)

Script nuevo `BD/3xx_MENU_MANTENIMIENTO_5_LUGARES.sql`, idempotente:

- Oculta (no borra) las entradas antiguas: Pautas de inspección, Hallazgos de inspección, Tareas recurrentes, Categorías de tarea, Listado de órdenes, Fallas.
- Las URL antiguas redirigen a la pestaña nueva equivalente (marcadores y enlaces externos siguen funcionando).
- Permisos: hereda los del menú padre; Avisos visible para cualquier usuario que hoy ve Fallas o Hallazgos.

---

## 4. Operación

**Cabecera:** planta (filtro global) + botón primario **Reportar falla**. Cinco KPI clicables:

| KPI | Lleva a |

|---|---|

| Requieren atención (vencidas + atrasadas, de todos los tipos) | Ejecuciones con filtro «Requieren atención» |

| Disponibles para OT (solo planes) | Ejecuciones filtro «Disponibles» + tipo Planes |

| En curso ahora | Monitoreo |

| Avisos sin tratar | Avisos |

| Cumplimiento · 40 días | Cumplimiento |

**Monitoreo:** el módulo de sala de control ya especificado en `prompt-claude-code-planes-por-pasos.md`, ahora en su propio lugar. Además de las ejecuciones de planes, incluye:

- ocurrencias de rondas (etiqueta «Ronda»);
- ocurrencias de tareas (etiqueta «Tarea»);
- OT no generadas por plan (etiqueta «OT»), por ejemplo una correctiva en ejecución que detiene un activo.

Un clic en una OT abre su ficha.

**Ejecuciones (lista única):**

- Fuentes:

  - `Plan_Mantenimiento_Ocurrencia`;
  - ocurrencias de `Checklist_Programacion`;
  - ocurrencias de `Tarea`.
- Segmento de tipo: Todo · Planes · Rondas · Tareas. Vistas: Lista · Semana · Mes. Chips de situación: Requieren atención, Vencidas, Atrasadas, Disponibles, Futuras, Con OT, Cerradas, Todas.
- Acción por fila:

  - Plan: **Generar OT** (turquesa), individual o en lote. Mantiene las reglas actuales: no duplica y rechaza con motivo.
  - Ronda: **Registrar**, que abre el panel con la pauta. Una vez hecha, muestra «Sin hallazgos» o «N hallazgos».
  - Tarea: **Hecha** con un clic y Deshacer. El panel permite **Escalar a OT**.
- Solo los planes entran en la selección en lote. Las rondas y tareas muestran la casilla deshabilitada con un tooltip.

**Registrar ronda (panel):**

- Ítems de la pauta vigente, agrupados por sección. Respuestas según el tipo de ítem:

  - Cumple / No cumple / N/A;
  - medición con rango;
  - texto;
  - foto.
- Las mediciones son obligatorias.
- Cada «No cumple» o medición fuera de rango se marca en vivo como «Pasa a Avisos como hallazgo».
- Al registrar:

  - se crea un `Checklist_Hallazgo` por cada uno;
  - la severidad es Alta si el ítem es crítico y Media en otro caso;
  - la ejecución queda hecha;
  - un toast ofrece «Ver avisos».

**Escalar tarea a OT:**

- Se pide qué problema se encontró (mínimo 5 caracteres), el componente y la prioridad.
- Se crea una OT con origen 3 · Tarea y se llena `toc_orden_trabajo`.
- La ocurrencia queda «Con OT» y enlazada.

**Cumplimiento:**

- Base: lo programado que venció en los últimos 40 días.
- «Hecho» significa OT cerrada para los planes, o registro hecho para rondas y tareas.
- Bloques:

  - gráfico mensual;
  - «Por tipo de trabajo» (Planes, Rondas, Tareas), donde cada fila filtra Ejecuciones;
  - «Por plan, ronda o tarea», con el peor primero;
  - «Por activo».
- Las reprogramaciones se miden contra la fecha original.

---

## 5. Órdenes de trabajo

**Lista:**

- Chips: Abiertas (por defecto), Por iniciar, En ejecución, En espera de cierre, Cerradas, Todas.
- Filtros: origen, tipo y búsqueda.
- Columnas: OT · Trabajo y activo › componente · **Viene de** (chip de origen + código) · Tipo y prioridad · Programada · Responsable · Estado.

**Ficha de OT** (página, no modal):

- Breadcrumb «Órdenes de trabajo / OT-xxxx», con anterior y siguiente dentro del filtro actual.
- Cabecera:

  - código, estado, tipo, prioridad y «Con parada»;
  - título;
  - **activo › componente** · área · planta.
- Un solo botón primario según el estado:

  | Estado | Botón |

  |---|---|

  | Por iniciar | Iniciar trabajo |

  | En ejecución | Registrar cierre |

  | En espera de cierre | Cerrar OT |
- Caja **Viene de** con un enlace real al origen:

  - Plan → ficha del plan;
  - Aviso → panel del aviso, y desde ahí a la ronda u OT que lo encontró;
  - Tarea → programación de la tarea;
  - Manual.
- Barra de flujo de 4 estados.
- Pestañas:

  - **Resumen:** qué hacer, datos, asignación editable de responsable y grupo (queda en la bitácora), **Avisos vinculados** y **Bitácora**.
  - **Pasos:** actividades del plan con su procedimiento desplegado, o los pasos de la OT. Se marcan solo en ejecución.
  - **Repuestos:** reservado o entregado según el estado.
  - **Cierre:**

    - informe con trabajo realizado (obligatorio, mínimo 10 caracteres), horas reales, estado del activo al terminar y, si es correctiva, causa de la falla. «Enviar a cierre» la pasa a En espera de cierre;
    - el supervisor ve el informe y elige «Cerrar OT» o «Devolver a ejecución»;
    - bloque **«¿Encontraste algo que no es parte de esta OT?»**, que crea un aviso con origen 9 · Hallazgo en OT, enlazado a esta OT.
- Al cerrar:

  - si el origen es un plan, la ejecución cuenta como cumplida;
  - los avisos vinculados quedan resueltos.

**Nueva OT** (panel): activo agrupado por área, componente, trabajo, tipo, fecha, responsable, duración, prioridad, «Requiere detener el activo» y descripción. Origen 1 · Manual. Al crear, abre la ficha.

---

## 6. Avisos (vista unificada, sin tabla nueva si es posible)

Implementa una vista o servicio `VW_AVISOS` que una:

- `Falla` → origen Falla;
- `Checklist_Hallazgo` → Hallazgo de ronda;
- hallazgos registrados al ejecutar una OT → Hallazgo en OT;
- `Prediccion` → Predicción, con su confianza;
- alertas de medidor → Alerta.

Cada fila trae: código, origen, título, activo, componente, severidad, fecha y hora, quién o qué lo detectó, detalle, estado (`sin tratar | con OT | descartado`), OT vinculada, motivo y autor del descarte.

**Bandeja:**

- Chips: Sin tratar (por defecto), Con OT, Descartados, Todos.
- Filtro por origen y resumen clicable por origen.
- Orden: primero lo sin tratar, luego por severidad y por fecha.
- Cada tarjeta muestra:

  - barra de color por severidad;
  - chips de origen y severidad, y «Detuvo producción» cuando corresponde;
  - activo › componente · área;
  - cuándo y quién lo detectó.
- Acciones de cada tarjeta:

  - **Generar OT** (turquesa): crea la OT con el origen del aviso. Es Predictiva si viene de una predicción y Correctiva en los demás casos. Hereda la prioridad de la severidad y la parada si detuvo producción.
  - **Vincular** (contorno azul): popover con las OT abiertas del mismo activo y luego las de la misma área **y planta**. El aviso queda resuelto por esa OT y no se crea otra.
  - **Descartar** (texto): motivo obligatorio de al menos 10 caracteres, con atajos tomados de los motivos de descarte en Ajustes.

**Anti-duplicado:** si el activo ya tiene OT abiertas, el panel del aviso y el panel «Reportar falla» lo advierten y ofrecen vincular.

**Reportar falla** (panel, desde Operación y Avisos):

- Campos:

  - activo y componente;
  - qué falla (obligatorio);
  - criticidad;
  - estado actual del activo;
  - «Detuvo la producción»;
  - detalle;
  - «Generar la OT de inmediato» (se activa sola con criticidad Crítica).
- Guarda en `Falla` (síntoma, criticidad, `detuvo_produccion`, estado posterior, componente).

---

## 7. Planificación

- **Planes:** sin cambios respecto del prompt por pasos, salvo que **Monitoreo sale de aquí**. El conmutador de vista queda en Lista · Tarjetas.
- **Rondas de inspección** (`Checklist_Programacion`):

  - Columnas de la lista:

    - ronda;
    - pauta y versión, con el número de ítems;
    - activos;
    - frecuencia, o el calendario compartido;
    - responsable;
    - próxima;
    - últimos 30 días (barra «n de m»).
  - El panel crea o edita:

    - nombre y pauta;
    - planta;
    - activos (chips de la planta);
    - frecuencia (Semanal con días, Mensual con día, o Calendario compartido) y hora, con la vista previa de las 5 próximas fechas;
    - responsable y duración.
  - Al guardar se regeneran las ocurrencias futuras sin registrar (`GEN_CHECKLIST_OCURRENCIAS`). Ya no hace falta un botón manual para generarlas.
- **Tareas recurrentes** (`Tarea`): misma estructura, con categoría (punto de color) y «Dónde». La frase guía visible es «Una tarea no es una OT: si aparece un problema, se escala a OT».
- **Cobertura:** sin cambios.

---

## 8. Biblioteca

- **Procedimientos** y **Calendarios compartidos:** sin cambios (se mueven aquí).
- **Pautas de inspección** (`Checklist_Plantilla` + `Version`):

  - Lista con código y versión, área, ítems (y cuántos son críticos), umbrales y rondas que la usan.
  - El panel:

    - muestra secciones e ítems con su tipo, rango y marca de crítico;
    - muestra las dependencias;
    - permite agregar un ítem con su tipo, sección, mínimo, máximo, unidad y si es crítico;
    - avisa qué rondas la usan («la versión nueva rige desde su próxima ronda»).
  - El botón «Publicar vN+1» queda deshabilitado mientras no haya cambios.
- **Ajustes:** tres catálogos con conteo de uso:

  - Categorías de tarea;
  - Tipos de OT;
  - Motivos de descarte.

  Se puede agregar un elemento. Solo se quita lo que no tiene uso; lo que está en uso muestra el botón deshabilitado con un tooltip.

---

## 9. Estándar de UI (no negociable)

- Paleta:

  - morado `#6732F4` como único primario por grupo;
  - turquesa `#007F8A` para Generar OT, Reprogramar, Escalar a OT y Carga masiva;
  - contorno azul `#087BEA` para navegar o vincular;
  - ghost o texto para cancelar;
  - **rojo solo para lo destructivo**. Descartar un aviso no usa rojo.
- Sin gradientes en cabeceras. Tarjetas blancas sin borde.
- Cada lugar tiene cabecera con eyebrow «Mantenimiento», título, una frase de propósito y pestañas con contador.
- Paneles laterales para crear y editar (Esc cierra); toasts con «Deshacer» o «Abrir OT».
- Vocabulario:

  - «activo», nunca «equipo»;
  - «Avisos» para lo detectado;
  - «Ejecuciones» para lo programado;
  - «OT» para el trabajo.
- Responsive:

  - a 400 px no hay scroll horizontal de página;
  - las listas pasan a filas apiladas;
  - en la ficha de OT, el botón de estado baja bajo el título.
- Cada estado del módulo tiene URL propia: `#operacion`, `#ejecuciones`, `#cumplimiento`, `#ordenes`, `#ot-OT-4688`, `#avisos`, `#planes`, `#plan-PLN-0012`, `#rondas`, `#tareas`, `#cobertura`, `#biblioteca`, `#pautas`, `#calendarios`, `#ajustes`.

---

## 10. Criterios de aceptación

1. Aviso de falla → Generar OT → Iniciar → marcar pasos → informe de cierre (valida el mínimo de 10 caracteres) → Cerrar. El aviso queda «Con OT», la OT queda cerrada y la bitácora tiene las 4 entradas.
2. Aviso de un activo con una OT abierta: el panel sugiere vincular. Al vincular no se crea otra OT y el contador de Avisos baja.
3. Descartar un aviso sin motivo muestra un error. Con un motivo de atajo queda descartado y se puede deshacer.
4. Registrar una ronda con una medición fuera de rango y un «No cumple» crea 2 avisos de origen Hallazgo de ronda, enlazados a esa ronda. La ronda queda «2 hallazgos».
5. Escalar una tarea atrasada crea una OT con origen Tarea. La ocurrencia queda «Con OT» y la ficha de la OT enlaza a la tarea.
6. En Ejecuciones, Generar OT en lote solo acepta planes y respeta la regla de rechazo existente (PH-205 con correctiva en curso).
7. Monitoreo muestra la correctiva en ejecución de PH-205 como «En mantención ahora / con parada», y el clic abre su ficha.
8. Cumplimiento «Por tipo» suma planes, rondas y tareas. Las rondas no registradas cuentan como no cumplidas.
9. Publicar una pauta sube la versión y las rondas que la usan muestran la versión nueva.
10. Las URL antiguas del menú redirigen. No hay pantallas huérfanas en el menú y ningún permiso se pierde.
11. Ningún texto visible dice «equipo». Ningún botón rojo hace algo reversible.

Entrega por partes:

- (a) script de menú y redirecciones;
- (b) Avisos y su vista;
- (c) ficha de OT;
- (d) Operación;
- (e) Rondas, Tareas y Biblioteca.

Cada parte va con una prueba manual descrita paso a paso.

---

# Anexo v2 · Experiencia operacional (prevalece sobre lo anterior donde haya diferencia)

> La referencia `sigma-mantenimiento-referencia.html` ya incluye la versión 2. Para ver cada flujo de punta a punta, usa el botón **Recorridos** en Operación.

## A. Operación › Hoy (centro de control, pestaña por defecto)

**Cabecera:** «Operación de mantenimiento», con la fecha.

**Filtros persistentes:** Planta, Área, Responsable y Criticidad. Se guardan en sesión y se aplican a Hoy, Sala de control, Ejecuciones y Cumplimiento. Junto a ellos va «Quitar N filtros».

**Seis indicadores accionables**, en una sola franja (un clic = el detalle ya filtrado):

| Indicador | Lleva a |

|---|---|

| Cumplimiento | Pestaña Cumplimiento |

| Trabajo de hoy | Ejecuciones › Hoy |

| Atrasadas | Ejecuciones › Requieren atención |

| OT abiertas | OT › Abiertas |

| OT vencidas | OT › Vencidas |

| Activos en riesgo | Panel con la lista |

**Agenda de hoy** (columna principal): línea de tiempo por hora.

- Mezcla ejecuciones de planes, rondas, tareas y OT con fecha de hoy.
- Una línea roja marca la hora actual.
- Cada fila tiene un estado: Completada, En curso, Atrasada, Pendiente, Programada o Pausada.
- Cada fila tiene una acción directa: Generar OT, Registrar, Hecha o el número de la OT.

**Atención requerida** (columna lateral). Cada tarjeta muestra su conteo, los tres primeros casos y una acción:

- Ejecuciones sin OT → «Generar OTs pendientes»;
- Atrasadas o vencidas;
- OT vencidas;
- Hallazgos y fallas por evaluar;
- Activos en riesgo: criticidad A o B con una señal (predicción ≥ 55 %, aviso alto o crítico, o detenido por OT).

**SIGMA AI:** una sola tarjeta y solo cuando aporta. Incluye la recomendación, la probabilidad, el componente y la ventana, con las acciones Ver análisis y Crear OT.

**Tendencia:** cuatro gráficos de una serie, con tooltip:

- cumplimiento mensual con meta;
- backlog de OT en horas;
- tiempo de resolución;
- fallas por mes.

## B. Generar OTs pendientes

- Un banner en Ejecuciones y una tarjeta en Hoy muestran «N ejecuciones de planes ya deberían tener OT».
- El panel ancho dice «Se encontraron N ejecuciones sin OT.» y lista cada una con casilla: activo › componente, plan e intervención, fecha, responsable, prioridad y estado.
- El botón «Generar N OTs» las crea en una sola acción. El resultado separa las generadas, las que ya existían y las rechazadas, con su motivo.
- Nunca se crean OT en silencio.

## C. Ejecuciones

- Chips: Requieren atención, Hoy, En curso, Próximas, Sin OT, Con OT, Con hallazgos, Completadas, Canceladas y Todas.
- El detalle de una ejecución abre con una barra de acciones juntas:

  - **Ver OT**;
  - **Generar OT**;
  - **Ejecutar** (genera la OT si falta, la abre y la inicia);
  - **Reasignar** (selector en línea);
  - **Ver activo** (vista 360°).

## D. Cumplimiento mensual

- Selector de mes, con los dos meses anteriores y el actual.
- Ocho indicadores accionables: Cumplimiento %, Planificado, Ejecutado, Pendiente, Atrasado, En ejecución, OT abiertas y OT vencidas.
- Cuatro indicadores de esfuerzo:

  - tiempo promedio por OT cerrada;
  - duración total registrada;
  - backlog en horas;
  - activos afectados.
- Bloques:

  - gráfico por período con la meta;
  - «Por tipo de trabajo»;
  - «Por plan, ronda o tarea»;
  - «Por activo», con su criticidad;
  - **«Por responsable»**: un clic filtra toda Operación por esa persona.

## E. Ciclo de vida de la OT

**Estados:** Creada → Asignada → En progreso ⇄ Pausada → Completada → Cerrada.

- **Creada** es una OT sin responsable. Al asignar responsable pasa sola a **Asignada**.
- Las OT nacidas de un aviso nacen Creadas. Las nacidas de un plan nacen Asignadas al responsable de la intervención.

**Botón primario según el estado:**

| Estado | Botones |

|---|---|

| Creada | Asignar |

| Asignada | Iniciar trabajo |

| En progreso | Pausar (ghost) + Completar |

| Pausada | Reanudar |

| Completada | Devolver + Cerrar OT |

**Pausar:** pide el motivo (espera de repuesto, de permiso, fin de turno, otra prioridad, activo en producción). El tiempo no corre mientras está pausada.

**Franja de datos de la OT:**

- responsable y grupo;
- fecha programada;
- **vencimiento**: para un plan, la tolerancia de la ejecución; para correctivas y predictivas, el SLA por prioridad (Crítica 1 día, Alta 3, Media 7, Baja 15);
- **tiempo registrado** contra el estimado, con barra y reloj vivo.

Una OT vencida muestra un chip rojo y aparece en «OT vencidas».

**Pestañas:**

- **Resumen:** qué hacer, objeto mantenible, resumen de tareas, inspecciones, evidencias y repuestos, asignación, avisos vinculados, comentarios y SIGMA AI si existe.
- **Trabajo:** dos bloques separados.

  - **Tareas** (acción concreta): responsable, duración, «Evidencia requerida» y procedimiento desplegable.
  - **Inspecciones** (evaluación de condición): medición con rango y estado **Normal**, **Advertencia** o **Crítico**.

    - Advertencia: fuera de rango. Crítico: fuera de rango por más del 25 % del rango, o del 5 % del límite cuando solo hay uno.
    - Fuera de rango aparece «Se detectó una condición fuera de rango», con **Crear hallazgo** o **Generar OT** (crea aviso y OT enlazados).
- **Evidencias:** fotos con autor y hora, más subir foto desde archivo o cámara. Incluye los comentarios.
- **Repuestos:** material consumido, distinto del objeto mantenible.
- **Historial:** cada acción queda en la línea de tiempo: asignación, inicio, pausa con motivo, tareas, mediciones con valor y estado, evidencias, comentarios, completada y cerrada.
- **Cierre.**

## F. Objeto mantenible

Un plan, una OT o un aviso apunta a uno de estos niveles:

- **Activo**;
- **Subactivo** (`act_activo_padre`);
- **Componente** (`Activo_Componente`).

**Selector único:**

- primero «Activo completo», luego un grupo «Subactivos» y un grupo de componentes por cada subactivo;
- se usa en el paso 1 del plan (en línea por activo), al agregar activos, en Reportar falla, en Nueva OT y en Escalar tarea.

**Presentación:** siempre como «Activo › Subactivo › Componente», con un chip del nivel. Los repuestos nunca se ofrecen como objeto mantenible.

## G. Activo 360° (panel ancho; se abre desde la OT, el aviso, la ejecución, el monitoreo y la cobertura)

**Cabecera:** estado operativo derivado (Operativo, Con OT abierta, Con falla reportada o Detenido por mantención), criticidad, área, planta y medidor.

**Pestañas:**

- **Resumen:**

  - OT abiertas;
  - avisos sin tratar;
  - cumplimiento a 40 días;
  - próxima ejecución;
  - SIGMA AI;
  - árbol del objeto mantenible, con conteo de registros por componente.
- **Historial:** OT, fallas, hallazgos e inspecciones en una sola línea de tiempo, con filtros.
- **Variables:** 30 días con umbrales de advertencia y crítico, valor actual y estado.
- **Planes y rondas:** planes con su objeto mantenible, rondas y tareas.
- **Repuestos:** los instalados (`Componente_Repuesto_Instalacion`) y los consumidos en sus OT.
- **SIGMA AI:** probabilidad, ventana, «Por qué lo dice» y recomendación. No crea trabajo por sí sola.

**Pie del panel:** Reportar falla y Nueva OT, con el activo ya precargado.

## H. Avisos

- Cada aviso sin tratar muestra una **evaluación sugerida** según su origen. En las predicciones, esa evaluación es la recomendación de SIGMA AI.
- El aviso muestra la criticidad del activo y un acceso a la Vista 360°.

## I. Estados de pantalla

Cada lugar tiene diseñados sus estados:

- **Vacío**, con la acción para empezar;
- **Cargando** (skeleton);
- **Error**, con «Reintentar» y sin perder lo que estaba en pantalla;
- **Éxito**, con un toast que ofrece «Abrir OT», «Ver aviso» o «Deshacer».

## J. Criterios de aceptación adicionales

12. En Hoy, todo indicador y tarjeta lleva al detalle filtrado. Los filtros se mantienen al cambiar de pestaña.
13. «Generar OTs pendientes» muestra la confirmación con la lista completa. Destildar filas cambia el total y las horas.
14. Al asignar responsable a una OT Creada, pasa a Asignada. Pausar exige motivo y detiene el reloj; Reanudar lo reactiva.
15. Una medición crítica en una OT permite crear el hallazgo o la OT. Ambos quedan enlazados en la bitácora.
16. El objeto mantenible se puede elegir a nivel de subactivo o de componente, y se ve igual en el plan, la OT, el aviso y la vista 360°.
17. La vista 360° muestra la historia unificada del activo y lleva a cada OT o aviso con un clic.
18. Los cinco flujos de **Recorridos** (A–E) funcionan sobre el prototipo sin pasos manuales intermedios.

---

# Anexo v3 · Menú por ciclo de vida y tablero de Operación

## Menú (prevalece sobre §3)

Sub-ítems de Mantenimiento en el orden del ciclo de vida:

1. **Planificación** · Definir
2. **Operación** · Controlar
3. **Órdenes de trabajo** · Ejecutar
4. **Avisos** · Detectar

Después de un separador «Recursos» va **Biblioteca** (transversal).

- Una línea vertical une los cuatro pasos con un punto por ítem; el del lugar activo va relleno en cian.
- Cada ítem lleva un tooltip con su rol, por ejemplo «2 · Controlar: lo programado, lo que pasa hoy y lo atrasado».
- Con el menú contraído (flyout), los puntos se ocultan y se mantienen el orden y el separador.
- La pantalla de entrada del módulo sigue siendo Operación.

## Operación › Hoy (prevalece sobre la sección A del anexo v2)

**1. Agenda de hoy**

- Chips para filtrar: Todo · Pendiente · En curso · Atrasado · Completado, cada uno con su conteo.
- Barra de avance del día y línea «Ahora».

**2. Atención requerida**

- Una sola tarjeta con categorías plegables, ordenadas por gravedad: Atrasadas o vencidas, Ejecuciones sin OT, OT vencidas, Hallazgos y fallas por evaluar, Activos en riesgo.
- Cerrada, cada categoría muestra el conteo y el primer caso «y N más». Abierta, muestra hasta 4 casos y su acción.
- Solo una categoría abierta a la vez.

**3. SIGMA AI:** una tarjeta, solo si hay un activo con predicción.

**4. Estado por área** (ancho completo)

- Una tarjeta por área de la planta. El estado de cada área es el más grave entre:

  - Activo detenido;
  - En mantención ahora;
  - Requiere atención;
  - Mantención programada;
  - Operando normal.
- Cada tarjeta muestra:

  - un cuadrado por activo, coloreado por su estado, con tooltip;
  - los conteos de hoy, atrasos, OT abiertas y avisos.
- Un clic filtra todo el tablero por esa área (es el mismo filtro «Área» de arriba). Otro clic lo quita.

**5. Tendencia:** sin cambios.

## Criterios adicionales

19. El menú muestra Planificación → Operación → Órdenes de trabajo → Avisos y, bajo «Recursos», Biblioteca.
20. En Estado por área, un área con una OT en progreso que detiene un activo aparece primero como «Activo detenido». Al tocarla, la agenda, los indicadores y Atención quedan filtrados por esa área.

---

# Anexo v4 · Cabecera de módulo (estándar «Centro de Activos»)

Todas las vistas del menú Mantenimiento usan la misma cabecera:

- Operación;
- Órdenes de trabajo;
- Avisos;
- Centro de Planificación;
- Biblioteca.

**Banda:** fondo sólido `#161A33`, sin gradiente; radio 20 px; padding 22 × 28 px.

**Textos:**

- Eyebrow «Centro de Mantenimiento» en cian `#16C6C9`, 12,5 px, peso 700 y sin mayúsculas forzadas.
- Título en blanco, 28 px, peso 800. Si hay planta filtrada, el título la agrega en gris `#9AA1BC`.
- Frase de propósito en `#C3C8DA`, 14 px.

**Títulos y frases por vista:**

| Vista | Título | Frase |

|---|---|---|

| Operación | Operación de mantenimiento | La fecha + «Qué estaba planificado, qué está pasando…» |

| Órdenes de trabajo | Órdenes de trabajo | (frase propia) |

| Avisos | Avisos | (frase propia) |

| Planificación | Centro de Planificación | «Qué se mantiene, cómo, cada cuánto y quién lo ejecuta.» |

| Biblioteca | Biblioteca | (frase propia) |

**Controles a la derecha:**

- Selectores en «píldora»: fondo transparente, borde `rgba(255,255,255,.18)`, etiqueta gris y valor blanco en negrita, alto 44 px, `color-scheme: dark`, foco cian.
- Botones de 44 px: turquesa para Carga masiva y morado primario con sombra para la acción principal. El contorno se vuelve blanco translúcido sobre la banda.

**Filtros de Operación:** Planta, Área, Responsable y Criticidad van dentro de la banda, en una segunda fila separada por una línea `rgba(255,255,255,.08)`.

**Ficha de OT:** mantiene su propia cabecera de ficha, sin banda.

**Móvil:** padding 18 px, título de 22 px; los botones ocupan el ancho y los filtros se apilan.

---

# Anexo v5 · Asignación de activos, intervenciones y cierre con firmas

## Rondas · activos que recorre (panel Nueva ronda / editar)

**Recorrido**

- Arriba va el recorrido: una lista numerada en el orden de inspección.
- Cada fila muestra nombre, código, área y criticidad, con botones para subir, bajar y quitar.
- Debajo: «~N min de recorrido (10 min por activo)», con un atajo «Usar X h como duración».

**Sugerencia de la pauta**

Si la pauta elegida tiene área, se ofrece «Agregar sus N activos».

**Selector**

- Buscador por código, nombre o tipo.
- Lista agrupada por área, con el área de la pauta primero y una casilla por área (vacía, parcial o completa) para marcar o desmarcar toda el área.
- Cada fila muestra:

  - nombre, código y tipo;
  - la criticidad;
  - «En RON-xxx» si otra ronda ya lo recorre;
  - el número de orden si está elegido.
- La lista tiene alto máximo con scroll interno; el encabezado de área queda fijo.

**Datos:** el orden de `eqs` se guarda tal cual en `Checklist_Programacion` (campo de orden por activo).

## Plan · paso 1 «¿Qué activos se mantienen?»

- Las tarjetas angostas pasan a **filas a todo el ancho**:

  - ícono;
  - nombre, código, área y tipo, con chips de criticidad, medidor, «fuera de alcance» y «también en PLN-x»;
  - bloque **Objeto mantenible**;
  - acciones «Vista 360°» y quitar.
- **Objeto mantenible:**

  - segmentado Activo / Subactivo / Componente. Un nivel se deshabilita, con tooltip, si el activo no tiene ese nivel registrado;
  - al elegir Subactivo o Componente aparece su selector (componentes agrupados por subactivo);
  - siempre se muestra la ruta resultante, por ejemplo «PH-205 › Bomba de pistones › Sello del eje».
- Sobre la lista, un resumen: «1 a nivel de activo · 1 a nivel de componente».

## Plan · paso 2 · tarjetas de intervención

- Tarjetas de ancho fijo (236 px), sin desbordes:

  - fila superior: código (chip), tipo de OT y estado (✓ completa, «Falta un dato» o «Pausada»);
  - nombre en hasta 2 líneas;
  - meta: actividades · duración · parada.
- «Agregar intervención» es una tarjeta del mismo alto, con borde azul.
- **Bug corregido:** la clase `.cd` del código chocaba con la del calendario y mostraba un scroll. Se renombró a `.icd`; usar nombres con prefijo para evitar colisiones.

## Cierre de OT con firmas

**Firmas requeridas**

| Rol | Cuándo se exige | Quién firma |

|---|---|---|

| Ejecutó el trabajo | Para pasar a **Completada** | El técnico responsable, junto con el informe (mínimo 10 caracteres) |

| Recibe el activo | Para **cerrar**, solo si la OT detuvo el activo | Producción · jefe de turno del área (nombre y cargo) |

| Aprueba el cierre | Para **cerrar** | Supervisor de mantenimiento |

**Cómo se firma**

- Recuadro con línea guía, para el dedo o el mouse (canvas, `touch-action: none`).
- Botones «Limpiar» y «Confirmar firma»; Confirmar se habilita al trazar algo.
- Nombre y cargo editables.
- Al confirmar queda la imagen, con nombre, cargo, fecha y hora, y la bitácora registra «Firmado por …».

**Avance y bloqueos**

- Una barra de pasos muestra Informe → Firma técnico → (Recepción) → Firma supervisor → Cerrada.
- Los botones muestran por qué no avanzan («Falta el informe», «Falta la firma del técnico»).
- «Cerrar OT» sin las firmas lleva a la pestaña Cierre, desplaza a la firma pendiente y avisa con un toast.

**OT cerrada**

- Muestra el **Acta de cierre**: OT, activo › objeto mantenible, fecha, informe y las firmas en tarjetas de solo lectura.
- Las OT cerradas antes de la puesta en marcha muestran sus firmas registradas.

**Datos:** tabla `Orden_Trabajo_Firma`:

- `otf_orden_trabajo`, `otf_rol` (ejecutor, recepción o supervisor);
- `otf_nombre`, `otf_cargo`, `otf_usuario` (opcional);
- `otf_imagen` (PNG en base64 o en archivo);
- `otf_fecha`.

El cierre valida las firmas en el servidor, no solo en la interfaz.

## Criterios adicionales

21. En la ronda, el recorrido respeta el orden elegido; «Agregar sus N activos» toma el área de la pauta, y marcar un área agrega o quita todos sus activos.
22. En el paso 1 del plan no hay controles que desborden la fila; el nivel del objeto mantenible y su ruta se ven a la vez.
23. Una OT no pasa a Completada sin informe y firma del técnico, ni a Cerrada sin la firma del supervisor (y la de recepción si detuvo el activo).

---

# Anexo v6 · Trabajo sobre subactivos y componentes · identidad de SIGMA AI

## Dónde se crea trabajo sobre un subactivo o componente

El **mismo selector de objeto mantenible** aparece en todos los puntos donde nace trabajo:

- segmentado Activo completo / Subactivo / Componente;
- selector del nivel elegido;
- ruta con nombres: «Bomba Hidráulica PH-205 › Bomba de pistones › Sello del eje».

| Dónde | Qué se crea | Se guarda en |

|---|---|---|

| Nueva OT («¿Sobre qué se trabaja?») | OT manual | `otr_activo_componente` |

| Reportar falla («¿Qué está fallando?») | Aviso de falla y, opcionalmente, su OT | `Falla.componente` |

| Tarea recurrente (panel) | Tarea programada | `Tarea.componente` (nuevo) |

| Escalar tarea a OT | OT de origen Tarea | hereda el componente de la tarea |

| Ronda · cada activo del recorrido | Qué se inspecciona de ese activo | `Checklist_Programacion_Activo.componente` (nuevo) |

| Plan · paso 1 | Intervención preventiva | `pac_activo_componente` |

| **Vista 360° › árbol del objeto mantenible** | En cada nivel, los botones **OT · Inspección · Tarea · Falla** abren el panel con el activo y el nivel precargados | — |

**Reglas:**

- Si se cambia el activo, un componente que no le pertenece se descarta.
- Un nivel sin registros se deshabilita y explica por qué.

**Visualización:** la ficha de la OT, el aviso, las listas de tareas y rondas, y las ocurrencias muestran el **nombre del activo** y la ruta, nunca solo el código. El dato «Objeto mantenible» de la OT muestra el chip del nivel, el nombre completo y, debajo, el código.

## SIGMA AI (predicciones)

Todo lo que viene de una predicción usa la identidad de SIGMA AI, con los recursos oficiales de `Imagen/sigma-ai/`:

- `sigma-ai-wordmark-dark.svg`;
- `sigma-ai-symbol-gradient.svg`;
- `sigma-ai-status-recommendation.svg`.

**Superficie:**

- fondo `#070B16`, con retícula sutil `rgba(148,163,214,.07)` cada 24 px y un halo violeta en la esquina;
- borde `rgba(148,163,214,.16)`, radio 16 px;
- texto `#F4F6FF`, secundario `#B7BED6` y `#7E87A6`.

**Acentos:**

- teal `#00E0C2` para acciones y enlaces;
- violeta `#6C5CFF`;
- rosa `#FF4D9D`.

**Probabilidad:**

- alta (≥ 70 %): `#FF5C8A`;
- media: `#FFB547`.

**Dónde aplica:**

- la tarjeta «Recomendación» en Operación › Hoy;
- la ficha de OT (si el activo tiene predicción);
- el resumen y la pestaña **SIGMA AI** de la Vista 360°, con anillo de probabilidad, «Por qué lo dice» y «Crear OT predictiva»;
- el panel del aviso de predicción, con su evaluación;
- el chip de origen «SIGMA AI» (símbolo más texto, fondo oscuro);
- la barra lateral del aviso, en degradado de marca;
- el resumen de Avisos;
- la pestaña con el símbolo.

**Botones dentro de la superficie oscura:**

- secundario: texto `#B7BED6`;
- acción: contorno teal.

SIGMA AI nunca crea trabajo por sí sola: la OT predictiva se genera solo con la confirmación del usuario.

## Rondas · fila del recorrido (corrección)

- Nombre y código van en la primera línea.
- El selector de «qué se inspecciona» va en una segunda línea a todo el ancho.
- Así no se comprime el nombre en paneles angostos.

## Criterios adicionales

24. Desde la Vista 360° se puede crear una OT, una inspección, una tarea o una falla sobre cualquier subactivo o componente, en un clic y con todo precargado.
25. La ficha de OT muestra el nombre del activo y la ruta completa del objeto mantenible.
26. Ningún elemento de predicción usa el estilo genérico: todos llevan la marca y la superficie de SIGMA AI.

---

# Anexo v7 · Repuestos planificados con compatibilidades

En **Plan › paso 2 › actividad › Repuestos planificados**, SIGMA propone los repuestos compatibles con lo que mantiene el plan. El alcance de cada plan es cada activo con su objeto mantenible (activo, subactivo o componente).

## Datos

**Compatibilidad** (`Componente_Repuesto`, extendida):

- `rep_codigo`;
- alcance por `tipo_activo` y/o `modelo`, o por activo puntual;
- `objeto` (subactivo o componente donde se instala; vacío = consumible del activo);
- `cantidad_sugerida` por activo.

**Stock:** disponible, mínimo, bodega y días de reposición.

## Cómo se calcula la compatibilidad, por cada activo del alcance

1. **Del objeto mantenible:** el repuesto se instala exactamente en el subactivo o componente elegido.
2. **De sus componentes:** el plan apunta al activo completo, o a un subactivo, y el repuesto se instala en una pieza que forma parte de él.
3. **Del activo:** consumibles y filtros del tipo o modelo, sin objeto.

Un repuesto aparece una sola vez, con el mejor nivel, el máximo de cantidad sugerida y la lista de activos donde calza.

## Interfaz

**Lista de planificados.** Cada fila muestra:

- nombre y código;
- **chip de compatibilidad:** «Compatible con los N activos», «Compatible con CMP-01» o, en ámbar, «Sin compatibilidad registrada»;
- cantidad por activo;
- total por ejecución («× 2 activos = 2 un»);
- **stock:** «N en bodega», en ámbar «Stock bajo» o en rojo «Sin stock · N d de reposición»;
- botón para quitar.

**Bloque «Compatibles con lo que mantiene este plan».**

- **Cabecera:**

  - chips del alcance (por ejemplo «CMP-01 › Unidad compresora › Elemento compresor», «CMP-02 · activo completo»);
  - atajo «Agregar los N del objeto mantenible».
- **Grupos:** Del objeto mantenible · De sus componentes · Del activo.
- **Cada fila:**

  - dónde calza (activo › ruta);
  - «N de M activos»;
  - stock;
  - cantidad sugerida × activos;
  - **Agregar** (o «Agregado ✓»).
- **Más de 6:** filtro y «Ver los N compatibles».
- **Sin activos en el paso 1:** se explica que primero hay que agregarlos.

**Búsqueda en todo el catálogo** («¿No está en la lista?»):

- los compatibles salen primero;
- los demás llevan la marca «Sin compatibilidad» y se pueden agregar igual, quedando señalados en la lista.

**Al generar la OT**, los repuestos se reservan por activo con la cantidad × activos del plan. Si no hay stock, la OT nace con alerta de repuesto.

## Criterios adicionales

27. Al elegir un componente en el paso 1, la actividad propone primero sus repuestos («Del objeto mantenible») y luego los consumibles del activo.
28. Agregar un repuesto compatible usa la cantidad sugerida. Uno no compatible queda marcado «Sin compatibilidad registrada».
29. El stock bajo o en cero se ve antes de activar el plan.

Ademas incluye en todas las vistas es decir Default.master SIGMA AI Chat como esta en la pantalla de SIGMA AI. obviamente esto va si cumple con el Plan el cliente le aparece de lo contrario no.

Lo mismo con SIGMA Twin deberian ser parte del plan si no lo tiene el cliente dentro no deberia verlo.

---

# Anexo v3 · Cambios de Catalina ya en el código (09-10-2026)

> La rama `CatalinaPescio` se fusionó en `BryanChavez` (merge `47db1ef`). El rediseño **parte de este código**, no del anterior. Donde el prompt diga «responsable» o «hoy», rige lo de este anexo. Scripts: `BD/390` a `BD/393`, más `BD/381`–`383` reaplicados.

## Qué cambió y cómo afecta al rediseño

1. **Varios responsables por intervención** (`BD/391`, tabla `Plan_Mantenimiento_Hito_Responsable`).
   - El primero es el **Principal** y sigue guardado en `pmh_usuario_responsable`; lista, Monitoreo y validaciones lo leen igual que antes.
   - Al generar la OT, el principal queda como responsable y los demás entran como **Apoyo** (`ota_rol_ejecucion = 2`).
   - **Efecto:** en Operación (Hoy, Agenda, filtro «Responsable»), Ejecuciones, Rondas, Tareas y la ficha de OT, «Responsable» se muestra como avatares con el principal primero y «+N». El filtro Responsable incluye a quien sea apoyo. La asignación editable de la ficha de OT (Resumen) admite principal + apoyos, no solo uno.
2. **Personas con foto, perfil y especialidad** (`SEL_PLAN_CENTRO_PERSONAS`). Todo selector de personas del módulo (OT nueva, Rondas, Tareas, Reasignar) usa el combo SIGMA con foto o iniciales y «perfil · especialidad». `sigma-combo.js` acepta `ini` para las iniciales.
3. **Grupo de trabajo desglosado** (`SEL_PLAN_CENTRO_GRUPO_INTEGRANTE`): el combo muestra cuántos integrantes tiene y, elegido, los lista con el chip «Líder». Se reutiliza en OT, Rondas y Tareas.
4. **Áreas en árbol** (`SEL_PLAN_AREA_ARBOL`, `AreasArbol()`): el filtro **Área** de Operación y el selector de activo agrupado por área de «Nueva OT» y «Reportar falla» muestran área madre y líneas con sangría. Nunca una lista plana de «Línea 1» repetidas.
5. **«Hoy» y «ahora» en hora de la planta** (`BD/392`, `BD/393`). Las fechas de las ejecuciones se guardan en hora de la planta pese al sufijo `_utc`. Todo SP o servicio nuevo compara con `[dbo].[FNC_AHORA]()`, **nunca con `GETUTCDATE()`**. Aplica a: Hoy, Agenda con la línea de la hora actual, vencida/atrasada/disponible, Cumplimiento (corte de 40 días), Monitoreo, `VW_AVISOS` (fecha y hora) y la regla «Generar OTs pendientes».
6. **Ejecuciones se refrescan al activar, aplicar o desactivar un plan:** el estado de la pestaña se invalida (`EX.rango = null`). Toda pestaña nueva con caché por rango debe hacer lo mismo. Al reprogramar se conserva la **hora** de la ejecución.
7. **Condición en línea en el paso Frecuencia** (`Condiciones`, `AgregarCondicion`, `QuitarCondicion`): «Por condición» ya no abre `Programacion.aspx` en modal. Rondas y Tareas **no** vuelven al modal para condiciones.
8. **Volver a «Calendario» o «Intervalo»** reactiva la regla deshabilitada (`BD/390`); y «Por medidor» guarda «Avisar antes» = 0 como NULL (`CK_PME_ANTICIPACION`).
9. **Campañas y alertas:** `BD/381`–`383` ya fijan `QUOTED_IDENTIFIER ON`; sin eso las campañas no llegaban a nadie. Los avisos de tipo Alerta de `VW_AVISOS` dependen de esto.

## Reglas nuevas para el rediseño

- **Todo script que cree un SP abre con `SET ANSI_NULLS ON` y `SET QUOTED_IDENTIFIER ON`.** Se aplica con `-I`. Revisar `sys.sql_modules` (`uses_quoted_identifier = 0`) antes de entregar. Los SP pendientes de revisar son `SEL_FALLA`, `RPT_CHECKLIST_HALLAZGO_EXCEL`, `UPS_AYUDA_PANTALLA_SINCRONIZAR`, `JOB_SIGMA_NOCTURNO` e `INS_ORDEN_TRABAJO_TIPO`. `SEL_FALLA` entra en `VW_AVISOS`, así que se corrige primero.
- **Responsables múltiples en la OT:** «Mis OT» y la bandeja de quien es apoyo deben incluir las OT donde figura con `ota_rol_ejecucion = 2`.
- **Monitoreo** (se mueve de Planificación a Operación): lo de BD/389 + BD/392 es la base. Al sumarle rondas, tareas y OT se mantiene la hora de planta.
- **Planes:** la ficha por pasos queda como está, con el Paso 4 «Responsable» de varios responsables y el grupo desglosado. No se rehace.

## Criterios adicionales

30. Una intervención con 3 responsables genera una OT con el principal como responsable y 2 en «Apoyo»; los 3 la ven en su bandeja.
31. A las 22:00 hora de Chile, una ejecución de hoy a las 23:00 aparece «Pendiente» y no «Vencida», en Hoy, Ejecuciones y Monitoreo.
32. Activar un plan y entrar a Ejecuciones muestra sus ejecuciones sin recargar la página.
33. En «Nueva OT», el selector de activo muestra el área madre con sus líneas desglosadas.
