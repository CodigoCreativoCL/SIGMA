# Planificación 360 — propuesta de diseño

**Módulo:** Centro de Mantenimiento › Planificación
**Sistema:** SIGMA — ASP.NET WebForms 4.8 · SQL Server
**Fecha:** 26-09-2026
**Para:** equipo de Diseño. Las capturas de todas las pantallas actuales están en `capturas/`, numeradas en el orden en que un usuario las recorre; `capturas/indice.json` dice qué es cada una.

---

## 1. La idea en una línea

Una sola pantalla con la forma del **Centro 360 del activo** (cabecera con KPIs + pestañas que cambian sin recargar), pero centrada en **la planificación de la planta**: qué toca hoy, qué viene, qué planes hay, con qué reglas se disparan y cuánto se está cumpliendo.

Reemplaza el contenido de la página `Planificación` que hoy es un hub de tres tarjetas (`01_planificacion_hub.png`). El menú no cambia: el nodo *Centro de Mantenimiento › Planificación* ya apunta a esa página.

### Lo que NO es

- **No absorbe los editores.** El wizard de Programación (6 pasos, `03_programacion_paso*.png`), el Centro del plan (`06_centro_plan_*.png`) y las fichas de hito, equipo y actividad (`09`–`12`) siguen siendo sus propias pantallas y modales. El 360 los **abre**; no los contiene.
- La razón es medida, no de gusto: el análisis de viabilidad midió 80 KB de ViewState en el listado de Programaciones vacío y 45 KB en su ficha. Meter esos editores dentro de una página con pestañas suma ese peso en cada clic. El 360 se queda liviano y deja cada editor en su lugar.

---

## 2. Referencia de estilo

`19_referencia_centro360_activo.png` y `20_referencia_centro360_activo_mantenimiento.png`: el Centro 360 del activo ya resolvió el lenguaje visual (cabecera, fila de KPIs clicables, pestañas con contador, tarjetas `sg-ot-card`, chips de estado, filas desplegables). La propuesta es **reusarlo tal cual**, no inventar otro. Todo el CSS existe: `sigma-activo360.css`, `sigma-orden.css`, `sigma-plan360.css`.

---

## 3. Estructura propuesta

### 3.1 Cabecera (fija para todas las pestañas)

| Elemento | Contenido | De dónde sale hoy |
|---|---|---|
| Título | Planificación · *nombre de la planta* | — |
| Filtro global | **Planta** y **período** (año / trimestre / mes) | Hoy cada pantalla tiene su propio filtro de planta (`04`, `13`) |
| KPI 1 | **Requieren atención** = vencidas + atrasadas, en rojo | `SEL_PLAN_OCURRENCIA_BANDEJA` (resumen) |
| KPI 2 | **Disponibles**: se pueden adelantar hoy | ídem |
| KPI 3 | **Cumplimiento del año**, medido contra la fecha original | `SEL_PLAN_CUMPLIMIENTO` |
| KPI 4 | **Carga de las próximas 4 semanas**, en horas estimadas | Hoy solo por plan (`06_centro_plan_calendario.png`) |

Cada KPI es clicable y abre la pestaña que lo explica, igual que en el 360 del activo.

### 3.2 Pestañas

El orden sigue la frecuencia de uso, no el orden en que se configuran las cosas: lo diario primero, la configuración al final.

---

#### Pestaña 1 · Resumen *(la que abre por defecto)*

- **Requiere atención**: las 5 mantenciones más urgentes (vencidas y atrasadas), cada una con equipo, hito, días de atraso y acción directa (*Generar orden*, *Reprogramar*).
- **Próximas paradas**: lo que exige detener un equipo en los próximos 30 días. Es lo que hay que coordinar con Producción con anticipación.
- **Planes con cambios sin publicar**: versiones en borrador abiertas, con quién las abrió y hace cuánto.
- **Actividad reciente**: órdenes generadas desde el plan en la última semana.

Datos: todo sale de SP que ya existen, con filtros. No hay consulta nueva.

---

#### Pestaña 2 · Bandeja

Lo que hoy es `13_bandeja.png` / `14_bandeja_vencidas.png`, con las mismas capacidades:

- Contadores que filtran (vencidas / atrasadas / disponibles / futuras).
- Por fila: situación, fecha y cuánto falta o cuánto lleva atrasada, equipo, hito, lo que exige (parada, overhaul), orden generada.
- Acciones: **Generar orden** sobre lo marcado, **Reprogramar** por fila (`15_reprogramar.png`), **Descargar Excel**.

Cambio respecto de hoy: **sin RadGrid**. Filas en el mismo formato que el resto del 360, con el motor de filtros que ya tiene el 360 del activo (`data-filtra`). Hoy la bandeja pesa 34 KB de ViewState y 1.893 nodos de DOM con 45 filas.

---

#### Pestaña 3 · Calendario

Hoy **solo existe dentro de cada plan** (`06_centro_plan_calendario.png`). Un planificador con seis planes tiene que abrir seis calendarios para saber qué pasa la semana que viene.

- Vista **mes**: las ocurrencias de todos los planes en una grilla de días, coloreadas por situación.
- Vista **semana**: carga en horas por semana (el cálculo ya existe para un plan; se aplica a todos).
- Filtro por plan, por equipo y *solo con parada*.

Datos: `SEL_PLAN_CALENDARIO` ya acepta `@PLAN = NULL` (todos los planes). No hay SP nuevo.

---

#### Pestaña 4 · Planes

Hoy `04_planes_listado.png`, una grilla de código y nombre.

- Cada plan como una fila con: versión (publicada / borrador), hitos, equipos, **cumplimiento de ese plan** y próxima ocurrencia.
- Al hacer clic, abre el **Centro del plan** (pantalla actual, sin cambios).
- *Nuevo plan* y *Carga masiva* (`05_planes_carga_masiva.png`) desde acá.

---

#### Pestaña 5 · Programaciones

Hoy `02_programaciones_listado.png` + la ficha de 6 pasos.

- Cada regla como una fila con: tipo (fecha única, calendario, intervalo, medidor, condición), **sus próximas 3 fechas** y **dónde se usa**.
- *Dónde se usa* es información nueva y necesaria: una programación no la usan solo los planes. **Tareas recurrentes** (`17`, `18`) y **Programación de pautas** (`16`) eligen su programación del mismo catálogo. Hoy nadie ve eso: se edita una regla sin saber qué otras cosas dispara.
- Al hacer clic, abre el wizard actual en modal.

Datos: las próximas fechas salen de `SEL_PROGRAMACION_PROYECCION`. *Dónde se usa* necesita un SP nuevo (un `UNION` de las tres tablas que la referencian).

---

#### Pestaña 6 · Cumplimiento

- **Cumplimiento del período**, medido contra la fecha programada **original**, con lo que marcaría contra la fecha reprogramada al lado para que la diferencia se vea.
- Desglose: completadas, atrasadas, vencidas, omitidas, reprogramadas.
- **Por equipo**, ordenado de menor a mayor: dónde se está postergando el preventivo.

**Esta pestaña cierra HU-181** (Sprint 6, sin asignar, 0 de 3 criterios). Sus tres criterios son exactamente estos tres bloques. El primero ya está resuelto por `SEL_PLAN_CUMPLIMIENTO` (se construyó para HU-086); falta agregarle el desglose por equipo.

---

#### Pestaña 7 · Cobertura *(nueva)*

La pregunta que hoy no se puede contestar en SIGMA: **¿qué equipos no tienen plan preventivo?**

- Equipos **sin ningún plan vigente**, por planta y tipo.
- Equipos **en dos o más planes** a la vez: lo que hoy solo se avisa al asociar un equipo (`10_equipo_del_plan_ficha.png`).

Datos: SP nuevo sobre `Activo` y `Plan_Mantenimiento_Activo`. Los datos ya existen.

---

## 4. Cómo se construye para que no pese

| Decisión | Por qué |
|---|---|
| Pestañas resueltas en el navegador (`sg-a3-tab`), como el 360 del activo | Cambiar de pestaña no hace postback |
| Cabecera y Resumen se pintan en servidor, como texto | Es lo que se ve al entrar; tiene que estar al primer pintado |
| Bandeja, Calendario, Programaciones, Cumplimiento y Cobertura **se cargan al abrirlas la primera vez**, por WebMethod | Nadie paga lo que no mira. Precedente directo: `WsProgramacion.cs` ya hace esto (sesión, JSON, ids cifrados, permiso validado adentro) |
| Sin `RadGrid2` ni `UpdatePanel` en la página | Son el origen del peso medido |
| Los editores pesados siguen en modal o en su página | El wizard de Programación son 45 KB de ViewState por sí solo |
| Acciones que escriben (generar orden, reprogramar) validan permiso en el servidor | Igual que hoy |

**Meta medible:** la página entera por debajo de **10 KB de ViewState** y **1.000 nodos de DOM** al entrar. Hoy: Programaciones 80 KB / 2.314 nodos; Bandeja 34 KB / 1.893 nodos.

### Permisos

Se mantienen los de hoy. La página exige 116 (ver planes), como el hub actual. Dentro, cada pestaña se muestra según el permiso de su origen: Programaciones con 92, el resto con 116. Escribir sigue pidiendo 93 / 117 / *Crear orden de trabajo*. Unificar los permisos es una decisión aparte (ver el análisis de viabilidad, §2.4).

---

## 5. Lo que se ordena de paso

Recorriendo las pantallas para estas capturas aparecieron cosas que el 360 resuelve:

1. **`PlanVersion.aspx` no tiene entrada.** Está registrada en el menú (*Versiones del plan (detalle)*) y ninguna pantalla la abre: las versiones se manejan desde la pestaña Configuración del Centro del plan (`06_centro_plan_configuracion.png`). Es la segunda pantalla huérfana del módulo; la primera fue Reprogramar, que ya se conectó desde la Bandeja. Hay que decidir si se conecta o se da de baja.
2. **Tres cosas se llaman "bandeja".** Bandeja de mantenciones (esta), Mi bandeja de trabajo (HU-121, del técnico) y Bandeja de alertas (HU-184, sin construir). En el 360 esta pasa a ser la pestaña *Bandeja* dentro de Planificación, lo que la distingue por contexto.
3. **HU-181 deja de ser una pantalla aparte** y pasa a ser la pestaña Cumplimiento, reusando el cálculo que ya existe en vez de duplicarlo.

---

## 6. Preguntas para Diseño

1. **¿Resumen o Bandeja como pestaña inicial?** La propuesta es Resumen (lo más urgente arriba, con acción directa), pero un planificador que entra solo a trabajar la cola podría preferir la Bandeja.
2. **Proyectado vs. comprometido.** Las próximas fechas de una Programación son una *previsión* (cambian si se edita la regla); las ocurrencias de la Bandeja y el Calendario son *compromisos* (tienen estado propio). ¿Cómo se distinguen visualmente cuando aparecen juntas?
3. **Calendario:** ¿grilla mensual tipo calendario o línea de tiempo por equipo? La segunda escala mejor con muchos equipos; la primera se lee más rápido.
4. **Cobertura:** ¿pestaña propia o bloque dentro de Planes?

---

## 7. Índice de capturas

| Archivo | Pantalla | En el 360 va a |
|---|---|---|
| `00_menu_centro_de_mantenimiento` | Menú lateral del módulo | — |
| `01_planificacion_hub` | Planificación (hub actual) | Se reemplaza por el 360 |
| `02_programaciones_listado` | Programaciones — listado | Pestaña Programaciones |
| `03_programacion_paso1…6` | Programación — ficha (wizard) | Modal, sin cambios |
| `04_planes_listado` | Planes — listado | Pestaña Planes |
| `05_planes_carga_masiva` | Planes — carga masiva | Acción de la pestaña Planes |
| `06_centro_plan_resumen/hitos/equipos/calendario/configuracion` | Centro del plan (5 pestañas) | Página propia, sin cambios; su calendario inspira la pestaña Calendario |
| `07_centro_plan_hito_desplegado` | Hito desplegado | — |
| `08_centro_plan_borrador_hitos` | Hitos de un plan en borrador | — |
| `09_hito_ficha` | Hito — ficha | Modal, sin cambios |
| `10_equipo_del_plan_ficha` | Equipo del plan, con aviso de otro plan | Origen de la pestaña Cobertura |
| `11_actividades_del_hito` | Actividades del hito | Página propia, sin cambios |
| `12_actividad_ficha`, `12b_…_repuestos` | Actividad — ficha | Modal, sin cambios |
| `13_bandeja`, `14_bandeja_vencidas` | Bandeja | Pestaña Bandeja |
| `15_reprogramar` | Reprogramar ocurrencia | Acción de la pestaña Bandeja |
| `16_programacion_de_pautas` | Programación de pautas | "Dónde se usa" de Programaciones |
| `17_tareas_recurrentes`, `18_tarea_ficha` | Tareas recurrentes | "Dónde se usa" de Programaciones |
| `19_…`, `20_referencia_centro360_activo…` | Centro 360 del activo | Referencia de estilo |
