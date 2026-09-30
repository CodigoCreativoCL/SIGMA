# Módulo Tareas — Estado y decisiones (Sprint 4)

Épica **EP-11**. Historias HU-100, HU-101, HU-102, HU-104. Documento de estado
que acompaña a los informes de prueba (`Fase 2/Pruebas/SIGMA_Pruebas_HU-1xx.docx`).

Ambiente de verificación: Intranet local, BD `db_acd593_sigma`, cliente
**Hamburgo SA** (`cli_id = 1`), usuario `catalina@codigocreativo.cl` (Root).

El módulo se implementó alrededor de un **centro de tarea** (`Tarea.aspx`) con
pestañas: Configuración (la tarea), Programaciones/Ocurrencias (HU-102) y
Comentarios (HU-104). El listado es `Tareas.aspx`; las categorías tienen su
propio mantenedor (`TareaCategorias.aspx` / `TareaCategoria.aspx`).

---

## HU-100 — Administrar categorías de tarea

**Estado:** cerrada (dev + pruebas). Verificada el 24-09-2026.

- **Mantenedor de categorías** (`TareaCategorias.aspx`, `TareaCategoria.aspx`):
  CRUD sobre `Tarea_Categoria` (SP `SEL/INS/UPD/DEL_TAREA_CATEGORIA`). Campos:
  código (único por cliente), nombre, **color** (`tca_color`, hex de etiqueta),
  orden y habilitado. El color se muestra como swatch en el listado.
- **Brecha detectada y corregida en esta iteración:** el centro de tarea no
  exponía la categoría, así que una categoría creada no quedaba "disponible al
  crear tareas" (parte del criterio de aceptación). La capa de datos ya lo
  soportaba (`TareaController.Insert/UpdateTarea` envían `@TAREA_CATEGORIA` /
  `@QUITA_CATEGORIA`; el modelo `Tarea` tiene `tar_tarea_categoria` y
  `quita_categoria`). **Se agregó el combo _Categoría_** a la ficha
  (`Tarea.aspx` + `Tarea.aspx.cs`): se puebla desde
  `TareaCategoriaController.GetTareaCategorias` filtrado por cliente, se
  selecciona al editar y se guarda (o se limpia con `quita_categoria` cuando se
  deja "Sin categoría").
- **No hay endpoint de API** para categorías (es un mantenedor web), por lo que
  no aplica documentación Swagger; la documentación es este MD + el informe.
- **Observación abierta:** la cláusula "el color se usa en el calendario del
  planificador" no es demostrable end-to-end porque no existe todavía una vista
  de calendario del planificador en la web que consuma `tca_color`. El color se
  persiste y queda disponible para esa vista. Limitación conocida, no defecto.

---

## HU-101 — Crear una tarea

**Estado:** cerrada (dev + pruebas). Verificada el 24-09-2026.

- **Centro de tarea** (`Tarea.aspx`, `Tarea.aspx.cs`) + **listado** (`Tareas.aspx`):
  alta/edición de la tarea (código único por cliente, título, prioridad,
  categoría, duración, evidencia, planta/área/equipo) sobre los SP
  `SEL/INS/UPD/DEL_TAREA`. El acceso lo resuelve el master por datos y la
  escritura con `Token.Puede/ExigirPagina`; el cliente sale de la sesión.
- **CA-1** (crear con título, categoría y prioridad; código único; disponible
  para programarse): verificado. El alta con código repetido se rechaza
  («YA EXISTE UNA TAREA CON EL CÓDIGO …»). La categoría quedó disponible en la
  ficha gracias al combo agregado en HU-100.
- **CA-2** (asociada a un equipo → aparece en su historial; no cuenta en
  indicadores): verificado. La tarea aparece en el Centro de activos 360° del
  equipo (pestaña Mantenimiento → «Tareas recurrentes»). Al no tener
  programación, no genera ocurrencias ni OT, por lo que no se contabiliza en los
  indicadores del plan (que se calculan sobre ocurrencias/órdenes de trabajo).
- **Sin endpoint de API** propio para el alta web; la documentación es este MD y
  el informe `Fase 2/Pruebas/SIGMA_Pruebas_HU-101.docx`.

---

## HU-102 — Programar una tarea recurrente

**Estado:** cerrada (dev + pruebas). Verificada el 24-09-2026.

- **Programaciones** desde el centro de tarea (pestaña Configuración, tarjeta
  «Cuándo y quién» → «Agregar programación», modal `TareaProgramacion.aspx`).
  Reutiliza la entidad Programación (tipos: Abierta, Fecha única, Calendario,
  Intervalo, Medidor, Condición) por medio de `Tarea_Programacion`.
- **Generación de ocurrencias:** botón «Generar ocurrencias» del centro →
  `TareaController.GenerarOcurrencias(Id, 90)` → SP `GEN_TAREA_OCURRENCIAS`
  (horizonte 90 días). Las ocurrencias se ven en la pestaña Ocurrencias.
- **CA-1** (asociar programación → genera ocurrencias): verificado.
- **CA-2** (fecha única con cuatro fechas → cuatro ocurrencias independientes):
  verificado. Con la programación «Cuatro fechas puntuales» (tipo Fecha única)
  se generaron exactamente 4 ocurrencias (05-oct, 19-oct, 09-nov, 14-dic 2026),
  cada una con `toc_uuid` propio, estado propio y su panel de ejecución/
  evidencias/conversación.
- Informe: `Fase 2/Pruebas/SIGMA_Pruebas_HU-102.docx`.

---

## HU-104 — Comentar una tarea

**Estado:** cerrada (dev + pruebas). Verificada el 24-09-2026.

- **Comentarios por ocurrencia** en el centro de tarea (pestaña Comentarios):
  hilo por ocurrencia, con respuestas anidadas. La UI no ofrece editar ni
  borrar: un comentario se conserva como registro y solo se responde. SP
  `INS/SEL_TAREA_COMENTARIO`; en la app, `API_INS/API_SEL_TAREA_COMENTARIO`.
- **CA-1** (comentario con nombre y fecha, inmutable): verificado. El comentario
  queda con autor, canal y fecha; el hilo solo tiene «Responder».
- **CA-2** (respuesta anidada): verificado. La respuesta cuelga del comentario
  raíz (`tco_comentario_padre`).
- **API** (HU-104): `POST /api/tareas/{id}/comentarios` (comentar una ocurrencia;
  idempotente por dictado_uuid) y el detalle de la tarea incluyen la
  conversación. Documentados con comentarios XML de Swagger (summary/response)
  en `API/Controllers/TareasController.cs`.
- Informe: `Fase 2/Pruebas/SIGMA_Pruebas_HU-104.docx`.

---

## HU-096 — Bandeja de hallazgos de checklist

**Estado:** cerrada (pruebas + corrección). Verificada el 28-09-2026.

- **Bandeja** (`ChecklistHallazgos.aspx`, Centro de Mantenimiento → Hallazgos de
  inspección): lista los hallazgos pendientes (SP `SEL_CHECKLIST_HALLAZGO`) con
  activo, severidad, respuesta/valor, técnico y estado. Acciones: **Generar
  orden de trabajo** (`GenerarOrden`) y **Descartar con motivo** (`Descartar`).
- **Defecto encontrado y corregido (CA-1):** el SP ordenaba solo por
  `cha_fecha_creacion DESC`, sin severidad. Se corrigió a
  `cha_severidad DESC, cha_fecha_creacion ASC` (más severo y más antiguo
  primero); mismo criterio en el export a Excel `RPT_CHECKLIST_HALLAZGO_EXCEL`.
  Archivo: `BD/221_CHECKLIST_HALLAZGO.sql`.
- **CA-2** (convertir en OT): verificado. La OT se crea con origen «Hallazgo de
  checklist» (`otr_orden_trabajo_origen = 4`) y enlazada (`otr_checklist_hallazgo`);
  el hallazgo queda Procesado y sale de la bandeja.
- **CA-3** (descartar con motivo): verificado. Motivo < 10 caracteres se rechaza;
  con motivo válido se registra el descarte con usuario y fecha.
- Informe: `Fase 2/Pruebas/SIGMA_Pruebas_HU-096.docx`.

---

## HU-094 — Programar un checklist recurrente

**Estado:** cerrada (generador construido + pruebas). Verificada el 28-09-2026.

- **Programación** (`ChecklistProgramacion.aspx` / `ChecklistProgramacions.aspx`):
  CRUD de `Checklist_Programacion` (pauta + recurrencia + objetivo activo/área +
  responsable). CA-3 lo valida el SP `INS_CHECKLIST_PROGRAMACION`
  («Indique un objetivo: un activo o un área»).
- **Generador construido en esta iteración (faltaba):** no existía forma de
  generar las ocurrencias que piden CA-1/CA-2. Se agregó:
  - **SP `GEN_CHECKLIST_OCURRENCIAS`** (`BD/304_GEN_CHECKLIST_OCURRENCIAS.sql`):
    genera las ocurrencias por recurrencia (reusa `FNC_PROGRAMACION_FECHAS`),
    con el objetivo (activo o área) y el responsable de la programación; cada
    ocurrencia queda asignada al responsable (`Checklist_Ocurrencia_Asignacion`).
    Idempotente.
  - **`ChecklistProgramacionController.GenerarOcurrencias`** + botón
    **«Generar ocurrencias»** en el listado.
- **CA-1** (activo → ocurrencia diaria asignada): verificado (91 ocurrencias
  diarias sobre ACT-35, asignadas al responsable).
- **CA-2** (área → ocurrencia para el área): verificado (91 ocurrencias diarias
  con `coc_instalacion_area`).
- **CA-3** (sin objetivo → rechazo): verificado.
- Informe: `Fase 2/Pruebas/SIGMA_Pruebas_HU-094.docx`.

---

## HU-097 — Consultar el historial de ejecuciones de un checklist

**Estado:** cerrada (desarrollo + pruebas). Verificada el 29-09-2026.

- **Pantalla nueva** `ChecklistHistorial.aspx` (solo lectura, Centro de
  Mantenimiento → Historial de ejecuciones): filtro por pauta y estado, grilla
  de ejecuciones y detalle de una ejecución.
- **Backend construido en esta iteración:**
  - **SP `SEL_CHECKLIST_HISTORIAL`** + índice `IX_Checklist_Ejecucion_Cliente_Version`
    (`BD/306`): lista las ejecuciones de una pauta. Es por EJECUCIÓN, así ve
    también las ad-hoc que `SEL_CHECKLIST_OCURRENCIA` no muestra.
  - **`ChecklistCentroController.GetHistorial`** (+ modelo `ChecklistEjecucionHist`).
    El detalle reutiliza `GetRespuestas`/`GetEvidencias` (SP existentes).
  - **Permiso `VER HISTORIAL CHECKLIST`** + fila en `Menus` (`BD/305`).
- **CA-1** (historial por plantilla): verificado. La grilla muestra fecha,
  ejecutor, activo, versión, no conformidades, avance y estado.
- **CA-2** (detalle de una ejecución): verificado. Cada pregunta de la versión
  ejecutada con su respuesta, severidad (Conforme / Fuera de rango) y sus
  fotografías, agrupadas por sección.
- Informe: `Fase 2/Pruebas/SIGMA_Pruebas_HU-097.docx`.

---

## HU-091 — Definir los umbrales y las acciones de un ítem

**Estado:** cerrada (desarrollo + pruebas). Verificada el 29-09-2026.

- **Mantenedor construido** (no existía forma web de definir umbrales): pantalla
  `ChecklistItemValidacions.aspx` (listado) + `ChecklistItemValidacion.aspx`
  (ficha), controlador `ChecklistItemValidacionController` y modelo.
- **Backend:** SP `SEL/INS/UPD/DEL_CHECKLIST_ITEM_VALIDACION` + `SEL_CHECKLIST_ITEM_LISTA`
  (`BD/307`). Una validación por ítem (índice `UX_CIV_ITEM`), con umbrales
  coherentes. Permisos `VER VALIDACIONES` / `CREAR EDITAR VALIDACIONES` + menú
  bajo «Centro de Mantenimiento» (`BD/308`).
- **CA-1** (umbrales y severidad): verificado. Con mínimo 60 / advertencia 70 /
  crítico 80 / máximo 90, `FNC_CHECKLIST_SEVERIDAD` clasifica 84 → CRÍTICO
  (72 → ADVERTENCIA, 65 → NORMAL, 95 y 55 → CRÍTICO).
- **CA-2 / CA-3** (comentario / fotografía obligatorios): el mantenedor define
  `civ_requiere_comentario_fuera_rango` / `civ_requiere_evidencia_fuera_rango`;
  la app los lee (`API_SEL_CHECKLIST`) y los exige en terreno.
- **CA-4** (genera hallazgo): el mantenedor define `civ_genera_hallazgo`; el alta
  de respuesta (`API_UPS_CHECKLIST_RESPUESTA`) crea un `Checklist_Hallazgo`
  pendiente y no crea una orden por sí solo (la OT se genera aparte, HU-096).
- Informe: `Fase 2/Pruebas/SIGMA_Pruebas_HU-091.docx`.

---

## HU-092 — Definir dependencias entre ítems

**Estado:** cerrada (desarrollo + pruebas). Verificada el 29-09-2026.

- **Mantenedor construido** (no existía forma web de definir dependencias):
  pantalla `ChecklistItemDependencias.aspx` (listado) + `ChecklistItemDependencia.aspx`
  (ficha), controlador `ChecklistItemDependenciaController` y modelo. La ficha
  define el ítem dependiente, la acción (mostrar / ocultar / requerir / bloquear),
  el ítem de condición, el operador (igual, distinto, mayor, mayor o igual, menor,
  menor o igual, entre, contiene) y el valor.
- **Backend:** SP `SEL/INS/UPD/DEL_CHECKLIST_ITEM_DEPENDENCIA` (`BD/309`). El alta
  valida que ambos ítems sean de la MISMA pauta, que un ítem no dependa de sí mismo
  y que no exista la dependencia inversa (evita el ciclo directo). El combo de
  ítems reutiliza `SEL_CHECKLIST_ITEM_LISTA` (HU-091). Permisos `VER DEPENDENCIAS`
  / `CREAR EDITAR DEPENDENCIAS` + menú bajo «Centro de Mantenimiento» (`BD/310`).
- **CA-1** (la respuesta condiciona a otro ítem): el mantenedor define la
  dependencia (ítem, condición, operador, valor, acción); la app la aplica en
  terreno al responder (muestra / oculta / requiere / bloquea el ítem dependiente).
- **CA-2** (sin dependencias circulares): verificado. `INS_CHECKLIST_ITEM_DEPENDENCIA`
  rechaza que un ítem dependa de sí mismo («1.- UN ITEM NO PUEDE DEPENDER DE SI
  MISMO.»), la dependencia inversa (ciclo directo) y las de distinta pauta.
- **CA-3** (ítem oculto y obligatorio no bloquea): un ítem oculto por una
  dependencia no participa de la obligatoriedad y queda como «no aplicable» al
  cerrar la pauta (enforcement en terreno).
- Informe: `Fase 2/Pruebas/SIGMA_Pruebas_HU-092.docx`.
