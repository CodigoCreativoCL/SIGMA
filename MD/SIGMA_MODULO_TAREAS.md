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
