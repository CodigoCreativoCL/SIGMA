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
