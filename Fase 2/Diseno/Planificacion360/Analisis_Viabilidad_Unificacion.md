# Centro de Mantenimiento — Viabilidad técnica de unificación

**Módulos evaluados:** Programaciones · Plan de mantenimiento · Bandeja de mantenciones
**Sistema:** SIGMA — ASP.NET WebForms 4.8 · Telerik UI · SQL Server
**Fecha del análisis:** 26-09-2026
**Preparado para:** equipo de Diseño (como insumo, no como especificación cerrada)

> Nota de alcance: los "Sprint 1–6" de este documento son la numeración de **esta iniciativa de unificación**, no los sprints ya cerrados del proyecto SIGMA (que a la fecha de este análisis va en Sprint 4 con S1–S3 entregados). No se reabre trabajo ya cerrado; esto es una hoja de ruta nueva sobre el estado actual del código.

---

## 1. Resumen ejecutivo

**Se puede unificar la navegación y la experiencia de los tres módulos bajo un solo punto de entrada. No se recomienda unificarlos en un solo controlador/vista con un ViewState compartido.**

La razón no es de opinión de arquitectura: es una medición. Las tres pantallas de entrada ya pesan esto, hoy, sin tocar nada:

| Pantalla | ViewState | Nodos DOM | Controles Telerik vivos | Tiempo hasta interactiva |
|---|---:|---:|---:|---:|
| Programaciones (listado) | 80.552 B | 2.314 | 2 | 7,3 s |
| Programación (ficha, wizard de 6 pasos) | 45.176 B | 630 | 11 | 11,8 s |
| Planes (listado) | 24.404 B | 791 | 7 | 4,7 s |
| Centro del plan (5 pestañas) | 25.024 B | 922 | 13 | 6,0 s |
| Bandeja de mantenciones | 33.900 B | 1.893 | 7 | 5,0 s |

*(Medido en el ambiente de pruebas, con datos de volumen mínimo: 14 programaciones, 6 planes, 72 ocurrencias. Este peso no viene del volumen de datos — viene de la estructura de controles. Con datos de producción, empeora.)*

Dos datos duros detrás de la tabla:

- **Ninguna de las dos fichas más pesadas (Programación, Centro del plan) desactiva `ViewState` en ningún control.** El peso medido es el peso real de la arquitectura actual, sin ninguna mitigación ya aplicada que estemos a punto de perder.
- **La pantalla de Programaciones pesa 80 KB de ViewState y 2.314 nodos de DOM prácticamente vacía** (0 filas de grilla en pantalla). Es sobrecarga estructural de los controles Telerik (`RadGrid2`, `RadComboBox2`) renderizando su estado de cliente y sus plantillas ocultas, no del contenido.

Fusionar los tres módulos en una sola página con un solo `<form runat="server">` y un solo árbol de ViewState **suma** estos números en cada postback parcial, porque un `UpdatePanel` serializa el ViewState de la página completa, no solo el panel que cambia. Juntar el wizard de Programación (45 KB solo él) dentro del mismo documento que ya carga el Centro del plan (25 KB) y la Bandeja (34 KB) empuja el ViewState de una sola página por encima de 100 KB, y cada cambio de pestaña o paso del wizard vuelve a mover ese bloque completo de ida y vuelta.

**Recomendación de fondo:** unificar la *entrada* (menú, IA, un hub llamado "Centro de Mantenimiento") reutilizando el patrón "Centro 360" que el propio Plan de mantenimiento ya implementa (pestañas en el navegador, sin postback al cambiar de pestaña). Mantener las fichas pesadas — el wizard de Programación en particular — como piezas separadas (modal o navegación), no fusionadas en el mismo árbol de página.

---

## 2. Qué existe hoy (inventario real)

### 2.1 Código

| Módulo | Archivos | Líneas totales | Patrón de UI |
|---|---:|---:|---|
| Programaciones | 4 (.aspx + .cs × 2 pantallas) | 4.761 | Listado clásico (RadGrid) + ficha modal de **6 pasos** (wizard) |
| Plan de mantenimiento | 20 (.aspx + .cs × 10 pantallas) | 5.537 | Listado + **Centro 360** (pestañas: Resumen, Hitos, Equipos, Calendario, Configuración) + 6 fichas satélite en modal |
| Bandeja de mantenciones | 2 (.aspx + .cs) | 688 | Listado transversal con contadores-filtro y acción de generar OT |

El Plan de mantenimiento **ya es el módulo más avanzado en términos de patrón de interfaz**: es el único de los tres que usa el esquema `sg-a3-tab` / `sg-a3-panel` (pestañas resueltas en el navegador, cero postback al navegar entre ellas). Programaciones es, en cambio, la pantalla más antigua del grupo: listado + modal wizard clásico con postback en cada paso.

### 2.2 Acoplamiento real en base de datos

Los tres módulos **no son independientes hoy**. Ya existe una relación obligatoria a nivel de esquema:

```
Plan_Mantenimiento_Hito.pmh_programacion   → FK NOT NULL → Programacion.pro_id
Plan_Mantenimiento_Ocurrencia.pmo_programacion → FK        → Programacion.pro_id
```

Un hito de un plan **no puede existir sin una programación**. Esto significa que la unificación conceptual ("un solo lugar para planificar mantenimiento") ya está parcialmente resuelta en el modelo de datos — el trabajo pendiente es de **interfaz**, no de rediseñar el esquema.

### 2.3 Los dos modelos de cálculo no son el mismo modelo

Este es el punto técnico más importante del análisis, y el que más le importa a Diseño porque determina qué se puede mostrar junto en una sola pantalla sin mentir:

- **Programaciones** calcula sus próximas ejecuciones **al vuelo**, vía `SEL_PROGRAMACION_PROYECCION`: no persiste filas, proyecta fechas futuras a partir de la regla de recurrencia en el momento de la consulta.
- **Plan de mantenimiento / Bandeja** trabaja sobre `Plan_Mantenimiento_Ocurrencia`, una tabla de **filas materializadas**: cada ocurrencia existe como registro, con su propio estado, su fecha límite y su historial de reprogramación.

Son dos formas de responder "¿cuándo toca?" que no son intercambiables: una es una previsión (puede cambiar si se edita la regla), la otra es un compromiso ya generado (tiene estado propio, se puede reprogramar, se puede vencer). Una pantalla que mezcle ambas sin dejarlo claro va a mostrarle al usuario una fecha "proyectada" al lado de una fecha "comprometida" como si fueran lo mismo, y no lo son.

### 2.4 Permisos: dos esquemas distintos hoy

| Módulo | Permiso de ver | Permiso de escribir |
|---|---:|---:|
| Programaciones | 92 | 93 |
| Plan de mantenimiento (todo el árbol) | 116 | 117 |
| Bandeja de mantenciones | 116 (ver el plan) | 117 (generar OT se valida aparte, sobre "CREAR ORDEN TRABAJO") |

Unificar el menú bajo un solo nodo no obliga a unificar los códigos de permiso — SIGMA ya trata "quién ve" y "quién edita" como filas de `Menus` y `Menu_Funcion`, independientes de cómo se agrupe visualmente. Pero si Diseño propone una sola pantalla con partes visibles/editables mezcladas de los tres orígenes, **hay que decidir explícitamente** si el permiso se evalúa por módulo de origen del dato (como hoy) o si nace un permiso nuevo "Centro de Mantenimiento". Lo primero es gratis; lo segundo es una migración de permisos con su propio riesgo (usuarios que hoy pueden ver Programaciones pero no Planes quedarían con acceso parcial a una sola pantalla, lo cual el modelo de permisos actual de SIGMA no contempla bien).

### 2.5 Volumen de datos actual

| Tabla | Filas |
|---|---:|
| `Programacion` | 14 |
| `Plan_Mantenimiento` | 6 |
| `Plan_Mantenimiento_Version` | 9 |
| `Plan_Mantenimiento_Hito` | 11 |
| `Plan_Mantenimiento_Actividad` | 26 |
| `Plan_Mantenimiento_Activo` | 12 |
| `Plan_Mantenimiento_Ocurrencia` | 72 |

Es volumen de ambiente de pruebas. El peso medido en la sección 1 **no depende de este volumen** — es overhead estructural de los controles. Con datos de producción (decenas de plantas, cientos de programaciones), el peso de ViewState y DOM crece adicionalmente por cada fila de grilla renderizada, porque `RadGrid2` no pagina del lado del cliente sin volver a pedir la página.

---

## 3. Veredicto de viabilidad, por capa

| Capa | ¿Se puede unificar? | Cómo |
|---|---|---|
| **Menú / punto de entrada** | Sí, sin riesgo | Un nodo "Centro de Mantenimiento" en el árbol de `Menus`, con las tres pantallas actuales como sus hijas. Es una fila de base de datos, no un refactor de código. |
| **Navegación entre los tres (IA)** | Sí, con trabajo moderado | Extender el patrón `sg-a3-tab` que ya usa el Centro del plan para que sus pestañas incluyan "Programaciones" y "Bandeja" como vistas del mismo hub, en vez de required navigation a otra URL. |
| **Modelo de datos** | Ya está parcialmente unificado | La FK `pmh_programacion` ya obliga la relación. No hace falta tocar el esquema para la unificación de interfaz. |
| **Cálculo de "próxima ejecución"** | No conviene fusionar | Son dos modelos distintos (proyección vs. materializado) que responden preguntas distintas. Mostrarlos juntos es válido si la interfaz distingue "proyectado" de "comprometido"; fusionarlos en un solo cálculo produciría datos incorrectos. |
| **Controlador único / una sola página con un ViewState** | **No se recomienda** | El wizard de Programación por sí solo pesa 45 KB de ViewState sin optimizar. Sumado al Centro del plan (25 KB) y la Bandeja (34 KB) en el mismo árbol de página, cada postback parcial de cualquier pestaña movería ~100+ KB de estado de ida y vuelta. Es el tipo de decisión que dobla el tiempo de respuesta percibido sin que el usuario haya pedido más datos. |
| **Permisos** | Se puede mantener separado | El modelo actual (permiso por pantalla de origen) sigue siendo válido bajo un menú unificado. Unificar el permiso en sí es un proyecto aparte con su propia migración. |

---

## 4. Desglose técnico por sprint

Cada sprint entrega algo usable por sí solo — no depende de que Diseño ya tenga las pantallas finales del sprint siguiente.

### Sprint 1 — Auditoría y punto de entrada único (sin tocar código de negocio)

- Inventario formal de las 3 pantallas de entrada + las 8 fichas satélite ocultas, con sus permisos actuales documentados (tabla de la sección 2.4, formalizada).
- Alta del nodo de menú "Centro de Mantenimiento" (fila en `Menus`, `mnu_padre` = el nodo actual "Planificación" o uno nuevo, según decida Diseño la profundidad del árbol).
- Redirección: las tres pantallas actuales pasan a ser accesibles desde ahí, **sin cambiar una línea de sus `.aspx.cs`**. Es reordenar el árbol, no reescribir vistas.
- Medición base (la de la sección 1) queda documentada como línea de partida para comparar cualquier cambio posterior.

**Entregable a Diseño:** wireframe de bajo detalle del hub, con las tres entradas como tarjetas o pestañas, y la tabla de permisos actual para que Diseño sepa qué usuario ve qué.

### Sprint 2 — Componentes compartidos (filtro, chip de situación, cabecera)

- Extraer como componente reusable el patrón de "situación derivada" (vencida / atrasada / disponible / futura) que hoy vive dentro de `SEL_PLAN_OCURRENCIA_BANDEJA` y de `SEL_PLAN_CALENDARIO`. Es la misma lógica en dos SP; conviene que sea una sola vista o función escalar antes de que un tercer consumidor (el hub) la necesite otra vez.
- Extraer la barra de filtros (planta, plan, rango de fechas) como control compartido entre Bandeja y el Centro del plan — hoy están duplicados casi idénticos en `PlanOcurrenciaBandeja.aspx` y en la pestaña Calendario de `PlanMantenimiento.aspx`.
- Diseñar (sin implementar aún) el criterio para mostrar "próxima ejecución" de Programaciones al lado de una fila de Bandeja/Plan sin mezclar los dos modelos de cálculo — esto es una decisión de Diseño + Producto, documentada en la sección 2.3, y bloquea a Sprint 4.

**Entregable a Diseño:** especificación de qué campos son "proyectados" (vienen de Programación, pueden cambiar) y cuáles son "comprometidos" (vienen de una Ocurrencia, tienen estado propio), para que la interfaz los distinga visualmente (ej. un chip distinto, un ícono, un texto "estimado").

### Sprint 3 — Programaciones al patrón "Centro"

- Migrar el **listado** de Programaciones (no la ficha) al mismo esquema `sg-a3-tab` que ya usa el Centro del plan. Esto por sí solo reduce el DOM de 2.314 a un orden de magnitud comparable al Centro del plan (~900), porque deja de depender de `RadGrid2` con su plantilla de comandos completa para una lista que puede resolverse con el mismo patrón de tarjetas/filas que ya usa Bandeja.
- La ficha de Programación (el wizard de 6 pasos, 2.131 líneas de code-behind) **se mantiene como está, en modal separado**. No es candidata a fusión en este sprint ni en ninguno de los siguientes: es la pieza más pesada medida (45 KB de ViewState, 11 controles Telerik, 11,8 s de carga) y tocarla es un proyecto de optimización propio, no parte de la unificación de módulos.
- Auditoría de performance intermedia: remedir DOM/ViewState del nuevo listado de Programaciones contra la línea base del Sprint 1.

**Entregable a Diseño:** el listado de Programaciones como una pestaña más del hub, con la misma cáscara visual (tarjetas, chips) que ya usan Bandeja y el Centro del plan.

### Sprint 4 — Bandeja como vista de entrada del hub

- La Bandeja de mantenciones es, de las tres, la que **conceptualmente más se parece** a lo que Diseño probablemente imagina como "Centro de Mantenimiento": ya es transversal a todos los planes, ya tiene contadores-filtro, ya genera órdenes de trabajo desde ahí. Se propone que sea la pestaña por defecto al entrar al hub.
- Incorporar en sus filas, cuando aplique, la marca visual "proyectado" definida en el Sprint 2 para las ocurrencias que todavía no se materializan pero que Programaciones anticipa.
- Enlaces cruzados: de una fila de Bandeja al plan que la generó (ya existe), del plan al hito, del hito a su programación (nuevo — hoy el hito muestra el nombre de la programación pero no enlaza a su ficha).

**Entregable a Diseño:** la Bandeja funcionando como landing del hub, con navegación de vuelta hacia plan → hito → programación consistente en las tres direcciones.

### Sprint 5 — La pieza cara: optimizar el wizard de Programación

Este sprint es explícitamente sobre pagar la deuda técnica que hace inviable fusionar Programación con las otras dos, no sobre features nuevas de Diseño.

- Auditar `Programacion.aspx` paso por paso (son 6 `pnlPasoN`) para identificar qué controles pueden pasar a `EnableViewState="false"` sin romper el postback — hoy ninguno lo tiene, así que hay margen real de reducción antes de tocar la estructura.
- Evaluar dividir el wizard en `UpdatePanel`s independientes por paso, para que avanzar de un paso a otro no reserialize los pasos ya completados.
- Evaluar si los 20 `RadComboBox2` + `RadNumericBox2` de esa ficha necesitan todos carga server-side inmediata o si algunos pueden pasar a carga bajo demanda (Filter="Contains" ya lo hacen varios; falta auditar cuáles cargan su catálogo completo en cada apertura).
- Con la ficha más liviana, recién ahí evaluar si conviene que abra como modal desde el hub (como hoy) o como una pestaña más — la decisión de Diseño en este punto ya no arriesga los números de la sección 1.

**Entregable a Diseño:** métricas de antes/después de la ficha de Programación, y una recomendación concreta (modal vs. pestaña) basada en el peso ya optimizado.

### Sprint 6 — Cierre: permisos, menú definitivo, QA y documentación

- Decisión final sobre permisos (mantener los tres esquemas actuales bajo el hub, que es lo recomendado, o migrar a un permiso único "Centro de Mantenimiento" si Producto lo pide explícitamente — en ese caso, sub-tarea de migración de `Cliente_Usuario_Permiso` para no dejar a nadie sin acceso el día del corte).
- Retirar del árbol de menú los dos nodos de primer nivel que hoy son independientes (Programaciones, Planes) si Diseño confirma que el hub los reemplaza por completo — o dejarlos como atajos si Diseño prefiere mantener acceso directo además del hub.
- Medición final comparada contra la tabla de la sección 1, publicada como criterio de aceptación del proyecto.
- Actualización de `SIGMA_ESTADO_DESARROLLO.md` con las decisiones de esta iniciativa, para que quien retome el módulo en seis meses no tenga que redescubrir por qué el wizard de Programación sigue siendo una pieza aparte.

**Entregable a Diseño:** el Centro de Mantenimiento completo, con benchmark de performance documentado como parte de la entrega, no como una promesa aparte.

---

## 5. Lo que este documento no resuelve (y a quién le toca)

- **Qué tan agresiva quiere ser la fusión visual** (¿un hub con pestañas, o tres pantallas separadas con una barra de navegación común?) es una decisión de Diseño, no técnica. Este documento dice qué es seguro hacer en cada caso, no cuál elegir.
- **Si el permiso se unifica o se mantiene por origen** es una decisión de Producto + Seguridad, con costo de migración real si se unifica (sección 2.4 y Sprint 6).
- **Si vale la pena optimizar el wizard de Programación antes o después de fusionar la IA** — este documento propone hacerlo en Sprint 5, después de la fusión de navegación, porque así Diseño puede iterar sobre el hub sin esperar a que termine una optimización de performance que no cambia lo que el usuario ve, solo qué tan rápido lo ve.

---

*Documento generado a partir de medición directa del código y del ambiente de pruebas de SIGMA (Web/Intranet, base `db_acd593_sigma`). Los números de la sección 1 son reproducibles corriendo las mismas pantallas con datos de volumen mínimo; se recomienda remedir con un volumen representativo de producción antes de comprometer un SLA de performance para el Centro de Mantenimiento.*

---

## 6. Anexo — Qué hay pendiente en los Sprint Backlogs 1 a 6, relacionado con Plan / Programación / Bandeja

Revisión de los seis backlogs reales de SIGMA (no de esta iniciativa) buscando toda historia y tarea relacionada con Plan de mantenimiento, Programaciones, Ocurrencias, Hitos o Bandejas, para saber qué queda por hacer que afecte o se cruce con esta unificación.

### 6.1 Precedente directo: Programaciones ya pasó por una decisión de unificación

En el Sprint 3, el backlog original planificaba **cinco pantallas separadas** por tipo de programación: `ProgramacionMedidor.aspx`, `ProgramacionCalendario.aspx`, `ProgramacionIntervalo.aspx`, `ProgramacionCondicion.aspx`, `ProgramacionExclusion.aspx` — una ficha y un listado por cada una (10 tareas en total). Todas están marcadas **Descartada** en el backlog: se construyeron como **una sola ficha** (`Programacion.aspx`, el wizard de 6 pasos) en su lugar.

Esto es evidencia a favor de la unificación de pantallas como estrategia — el equipo ya lo hizo una vez dentro del propio módulo de Programaciones — pero también es la explicación de por qué esa ficha terminó pesando lo que pesa (sección 1): un wizard de 6 pasos que reemplaza 5 pantallas independientes concentra en un solo árbol de controles lo que antes eran 5 páginas separadas, cada una con su propio ciclo de vida y su propio ViewState más liviano. Es el mismo riesgo que este documento señala para "Centro de Mantenimiento", ya materializado una vez en miniatura dentro del propio módulo de Programaciones.

**No queda tarea pendiente aquí** — las únicas tareas activas de esas historias (T-3029, T-3055) son validaciones con la PO, bloqueadas en una persona, no en código.

### 6.2 Consumidores del módulo Programaciones fuera de los tres módulos analizados

Esto no estaba en el cuerpo del documento y cambia el radio del proyecto: **Programaciones no es un módulo consumido solo por Plan de mantenimiento.** Dos módulos más lo usan tal cual, llamando al mismo `ProgramacionController`:

| Consumidor | Historia | Dónde |
|---|---|---|
| Tareas recurrentes | HU-102 | `TareaProgramacion.aspx.cs` → `new ProgramacionController().GetProgramaciones(...)` |
| Checklists recurrentes | HU-094 | `ChecklistProgramacion.aspx.cs` → `new ProgramacionController().GetProgramaciones(...)` |

Ambas historias están **En revisión** (construidas, pendiente validación de la PO o pruebas/documentación menores — T-4210, T-4211, T-4294, T-4295). No bloquean nada, pero sí importan para el diseño: **si "Centro de Mantenimiento" cambia la forma en que se elige o se muestra una programación** (el combo, el catálogo, la navegación a su ficha), ese cambio se propaga a las pantallas de Tareas y Checklists, que hoy dependen del mismo combo y no forman parte del hub propuesto. La Sección 3 del cuerpo de este documento (Sprint 2, extracción de componentes compartidos) debería incluir explícitamente el combo de selección de programación como componente compartido con estos dos consumidores externos, no solo con Plan de mantenimiento.

### 6.3 Riesgo de trabajo duplicado: HU-181 se superpone con lo ya construido para HU-086

Este es el hallazgo más importante del anexo.

En el Sprint 4 (HU-086, "Reprogramar una ocurrencia"), al cerrar el criterio 2 se construyó `SEL_PLAN_CUMPLIMIENTO`: un cálculo de cumplimiento del plan medido contra la fecha programada **original**, con desglose de vencidas/atrasadas/reprogramadas, embebido como una línea de texto dentro de la pestaña Calendario del Centro del plan.

En el Sprint 6, **sin asignar y sin empezar**, existe **HU-181 — "Consultar el cumplimiento del plan de mantenimiento"** — con estos criterios de aceptación:

1. *"Se calcula como ocurrencias completadas sobre ocurrencias programadas, y se mide contra la fecha programada original y no contra la reprogramada."* — **Es literalmente la misma regla** que ya implementa `SEL_PLAN_CUMPLIMIENTO`.
2. *"Veo las ocurrencias completadas, atrasadas, vencidas, omitidas y reprogramadas"* (desglose) — ya está sustancialmente cubierto por las columnas que el mismo SP devuelve.
3. *"Agrupo por activo y veo el cumplimiento de cada equipo, ordenado de menor a mayor"* — **esto no existe todavía**, el SP actual da un número agregado, no por equipo.

HU-181 además pide una tabla nueva, `Indicador_Valor`, y una pantalla propia de solo lectura (`IndicadorCumplimiento.aspx`) con filtros, grilla y exportación — una arquitectura más general, pensada para servir a más de un indicador, no solo al cumplimiento del plan.

**Recomendación concreta:** cuando se tome HU-181, no partir de cero. Extender `SEL_PLAN_CUMPLIMIENTO` con el `GROUP BY` por activo que falta (criterio 3) y decidir explícitamente si vale la pena la tabla genérica `Indicador_Valor` para un solo indicador hoy, o si conviene construirla cuando exista un segundo indicador real que la necesite. Construir esto sin revisar lo ya hecho en HU-086 duplicaría el cálculo de cumplimiento en dos lugares del código con el riesgo de que, con el tiempo, den números distintos para la misma pregunta.

### 6.4 Un tercer concepto de "bandeja" que compite por el mismo nombre en la mente del usuario

El backlog tiene **tres pantallas distintas** que un usuario llamaría "la bandeja", y ninguna es la misma:

| Historia | A quién le habla | Sobre qué tabla | Estado |
|---|---|---|---|
| **HU-087** — Bandeja de mantenciones | Planificador | `Plan_Mantenimiento_Ocurrencia` (la que este documento analiza) | En revisión |
| **HU-121** — Mi bandeja de trabajo | Técnico en terreno (app) | `Orden_Trabajo` | Construida y verificada, en Sprint 6 |
| **HU-122** — Bandeja de órdenes en espera de cierre | Planificador | `Orden_Trabajo` (estado 3) | En revisión |
| **HU-184** — Bandeja de alertas | Planificador | `Alerta` (tabla nueva, sin construir) | Sin empezar, Sprint 6 |

HU-184 es la más relevante para este análisis porque su objetivo declarado — *"ver en un solo lugar todo lo que el sistema detectó, para no revisar cinco pantallas distintas"* — es, en espíritu, la misma pregunta que "Centro de Mantenimiento" le hace a Programaciones/Plan/Bandeja. Son dos iniciativas de unificación independientes, sobre dominios distintos (una sobre planificación, otra sobre alertas), que **podrían terminar compitiendo por el mismo lugar en el menú o por la misma metáfora visual** si Diseño las trabaja sin coordinarlas. No es una razón para fusionarlas — son datos distintos con dueños distintos (`Plan_Mantenimiento_Ocurrencia` vs. `Alerta`) — pero sí una razón para que Diseño las revise juntas antes de nombrar y ubicar el hub de esta iniciativa, para no terminar con "Centro de Mantenimiento" y "Bandeja de alertas" como dos puertas de entrada distintas que un usuario esperaría que fueran la misma.

HU-121 y HU-122 no comparten dominio de datos con este análisis (dependen de `Orden_Trabajo`, no de `Plan_Mantenimiento_*` ni de `Programacion`) y ya están construidas — se mencionan solo para que Diseño no las confunda con la Bandeja de mantenciones al conversar con el equipo.
