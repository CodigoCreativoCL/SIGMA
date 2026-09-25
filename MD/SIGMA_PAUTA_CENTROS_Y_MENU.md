# Pauta: menús por módulo y pantallas tipo «centro»

Para **Emilio**, que unifica Inspección, y para quien tome cualquier otro
módulo después. Es lo que ya quedó aplicado en Activos, Planificación,
Tareas y Órdenes de trabajo: seguir el mismo camino evita que la misma rama
del menú termine con dos criterios distintos.

Rama: `master` (commit `5a948fc`). Bloques de base de datos `267` a `272`.

---

## 1. El menú se agrupa por módulo

Una rama con nueve entradas sueltas no dice qué pertenece a qué. Cada módulo
es una **carpeta** con sus pantallas adentro.

```
Mantenimiento
  Planificación            → Programaciones · Planes de mantenimiento
  Procedimientos
  Tareas                   → Tareas recurrentes · Categorías de tarea
  Órdenes de trabajo       → Listado de órdenes · Fallas
  ...inspección            ← esto es lo que falta
```

Para inspección, la carpeta natural agrupa **Pautas de inspección**,
**Programación de pautas** y **Hallazgos de inspección**, con sus fichas de
detalle (`2181`, `2182`, `2212`, `2214`).

### Cómo se escribe el bloque

Mirar `BD/269_MENU_PLANIFICACION.sql` y `BD/270_MENU_TAREAS_FALLAS.sql`; son
el mismo molde. Tres reglas que no son obvias:

1. **La carpeta va sin permiso** — `mnu_permiso` en `NULL`, como todas las
   carpetas del árbol. Ponerle el permiso de una de sus hijas la deja
   invisible para quien solo tiene la otra. El FK `FK_MNU_PERMISO` además
   rechaza un `0`.
2. **Las fichas de detalle se mudan con su madre.** Son modales invisibles,
   pero el permiso de una pantalla sale de SU fila en `Menus`: un detalle
   colgando de otra rama funciona y no se entiende al revisar permisos.
3. **No confiar en `SCOPE_IDENTITY()`** para recuperar el id de la carpeta
   recién creada: releerla por nombre. El día que alguien ponga un trigger
   sobre `Menus`, la identidad que devuelve deja de ser la de esa fila y las
   pantallas se van a otra rama.

Y una que sí es obvia pero se olvida: **nada se borra**. Una pantalla existe
porque tiene fila en `Menus`; borrarla le quita el permiso a quien entre por
una alerta o por un enlace guardado. Se esconde con `mnu_visible = 0`.

---

## 2. Una pantalla «centro» en vez de cuatro pantallas sueltas

El patrón está en tres pantallas ya hechas:

| Centro | Archivo |
|---|---|
| Orden de trabajo | `View/Mantenimiento/Ordenes/OrdenTrabajo.aspx` |
| Activo | `View/Activos/Ficha/ActivoFicha.aspx` |
| Plan de mantenimiento | `View/Mantenimiento/Planes/PlanMantenimiento.aspx` |

La cáscara se reusa tal cual: `sigma-orden.css` (tarjetas, chips, tablas,
vacíos, botones, galería y visor) + `sigma-activo360.css` (encabezado, KPIs,
navegación, filas) + `sigma-activo360.js`.

### Lo que hay que respetar

- **Las pestañas son del navegador, no del servidor.** `sigma-activo360.js`
  ya lo resuelve: basta con `<a class="sg-a3-tab" data-sec="x">` y
  `<section class="sg-a3-panel" data-panel="x">`, más un
  `<asp:HiddenField ID="hdnSeccion" ClientIDMode="Static">` para que un
  postback asíncrono no devuelva siempre al Resumen. Cambiar de pestaña no
  puede costar un viaje.
- **Cada fila que se despliega** usa `class="sg-a3-rev" data-rev="clave"` y
  su detalle `id="rev-clave"`. El JS lo engancha solo.
- **Los "Abrir/Ver" llevan al REGISTRO**, no al listado del módulo, con el
  id cifrado y `target="_blank"`: el centro es donde la persona estaba
  mirando, y volver con el botón atrás pierde la sección y los filtros.
- **Las fichas que se crean desde el centro reciben el padre ya decidido**
  (`Id=0&Activo=<n>` cifrado) y no lo ofrecen: lo muestran. Ver
  `ActivoComponente.aspx.cs`, propiedad `ActivoFijo`.
- **Un formulario que se muestra en dos lados es un control, no una copia.**
  `ActivoForm.ascx` lo usan el modal de alta y la pestaña Ficha del centro;
  cambia la piel por CSS, no el markup.
- **Los archivos vienen de Blob Storage.** El SP devuelve el id; la pantalla
  pide la imagen por `VerArchivo.aspx?query=<cifrado>`. Nunca bytes en el
  HTML.

### Dos trampas que ya costaron tiempo

- **`sigma-orden.css` reparte los campos de cualquier `.sigma-modal-grid`
  que esté dentro de un `.sg-ot`.** Si el centro monta un formulario, sus
  campos quedan de a dos por fila aunque el markup pida tres. Se corrige
  con una regla propia más específica, no tocando `sigma-orden.css`.
- **Una propiedad pública de un control no se puede llamar `Id`**: en el
  markup `ID` es el nombre del control y ASP.NET intenta asignarle el
  nombre a un `int`.

---

## 3. Lo que hace falta del lado de los datos

Los SP existentes leen por plantilla, por tarea o por orden. Un centro
pregunta al revés —dado UN registro, qué le pasó— y eso normalmente pide un
SP nuevo. Ver `BD/267_ACTIVO_CENTRO.sql` como molde: cuatro consultas, cada
una con su comentario de por qué no servía la que ya existía.

Para inspección, la parte de datos **ya está hecha**: `BD/266_CHECKLIST_CENTRO.sql`
(`SEL_CHECKLIST_OCURRENCIA`, `SEL_CHECKLIST_EJECUCION_RESPUESTA`,
`SEL_CHECKLIST_EJECUCION_ARCHIVO`) y su `ChecklistCentroController`. Falta la
pantalla.

---

## 4. Evidencia

Cada bloque cierra con capturas en `Fase 2/Pruebas/capturas/S3` y una fila en
`MD/SIGMA_ESTADO_DESARROLLO.md`. El script de Selenium vive en `_scratch` y
no se versiona; lo que se versiona es la captura y lo que dice el commit.
