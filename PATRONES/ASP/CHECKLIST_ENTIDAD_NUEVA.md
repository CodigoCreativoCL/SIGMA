# Checklist end-to-end — Entidad nueva

Guion completo para agregar una entidad `<Entidad>` (tabla `<Tabla>`) a un
proyecto WebForms del grupo, desde la base de datos hasta el menú.

Seguir el orden. Cada paso enlaza al patrón que lo detalla.

---

## 0. Antes de empezar

- [ ] Definir el nombre de la tabla en `Pascal_Snake_Case` (`Cliente_Tarea`) y
      su prefijo de 3 letras, verificando que el prefijo **no esté usado** →
      [`BaseDatos/PATRON_TABLAS.md`](BaseDatos/PATRON_TABLAS.md) §1.
- [ ] Verificar que **no exista ya** una tabla/columna/catálogo que cumpla lo
      mismo → [`CONVENCIONES.md`](CONVENCIONES.md) §6.
- [ ] Confirmar la infraestructura del proyecto destino (`INS_EXCEPCION`,
      `LOG`, wrappers, clases CSS) → [`README.md`](README.md) §3.
- [ ] Quitar el read-only de TFS de los archivos que se van a tocar.

---

## 1. Base de datos

- [ ] `<Tabla>` creada con script idempotente (`IF NOT EXISTS ... ELSE PRINT`),
      PK/FK/DF/IX nombrados y columnas de auditoría →
      [`BaseDatos/PATRON_TABLAS.md`](BaseDatos/PATRON_TABLAS.md) §3.
- [ ] Catálogos asociados (`<Entidad>_Estado`, `<Entidad>_Tipo`) si aplica, con
      ids fijos → §5 del mismo documento.
- [ ] `INS_<TABLA>` — `@ID OUTPUT` primero, validaciones, transacción.
- [ ] `SEL_<TABLA>` — `@SELECT`/`@FROM`/`@WHERE`, `WHERE 1=1`, escape de
      comillas en los textos.
- [ ] `UPD_<TABLA>` — `@ID` + `@USUARIO` obligatorios, resto con `ISNULL`.
- [ ] `DEL_<TABLA>` — solo si el borrado es físico.
- [ ] Los 4 SPs con encabezado estándar (`USE`, `SET ANSI_NULLS`,
      `AUTHOR/FECHA CREACIÓN/DESCRIPTION`) →
      [`BaseDatos/PATRON_SP.md`](BaseDatos/PATRON_SP.md).
- [ ] Probados en SSMS: `EXEC SEL_<TABLA>`, `EXEC INS_<TABLA> ...`.
- [ ] Scripts `.sql` guardados en **UTF-8 con BOM**.

---

## 2. Capa de datos (C#)

- [ ] `App_Code/MVC/<Proyecto>/Model/<Entidad>.cs` — `[Serializable]`,
      propiedades = columnas, campos `filtro_*`, columnas de JOIN →
      [`Desarrollo/PATRON_MVC.md`](Desarrollo/PATRON_MVC.md) §2.
- [ ] `App_Code/MVC/<Proyecto>/Controller/<Entidad>Controller.cs` con
      `Get<Entidad>s`, `Get<Entidad>`, `Insert<Entidad>`, `Update<Entidad>`,
      `Delete<Entidad>` → §3.
- [ ] `Token.TokenSeguridad()` en todos los métodos.
- [ ] `Session.UsuarioId()` como `@USUARIO` (nunca del Model).
- [ ] Conexión cerrada en `try` **y** en `catch`.
- [ ] Mensajes `"<Entidad> creado/actualizado/eliminado con éxito."`.

---

## 3. Interfaz — listado

- [ ] `View/<Modulo>/Controls/<Entidad>/<Entidad>s.ascx(.cs)`:
  - [ ] `RadGrid2` dentro de `UpdatePanel` (`UpdateMode="Conditional"`).
  - [ ] `MasterTableView` con `DataKeyNames` y `CommandItemTemplate`
        (`lnkNuevo`, `lnkEliminar` con `ConfirSweetAlert`).
  - [ ] Columnas construidas en `!IsPostBack` con `AddSelectColumn`/`AddColumn`/
        `AddCheckboxColumn`/`AddTemplateColumn`.
  - [ ] Propiedades públicas vía `ViewState` (`ReadOnly`, `URLNuevo<Entidad>`,
        permisos).
  - [ ] `CargarGrid()` + `Grid.DataBind()` + `udPanel.Update()` +
        `RegisterPostBackScript(Grid)` en `Page_PreRender`.
  - [ ] Link "Editar" por fila con querystring cifrado en `ItemDataBound` →
        [`Desarrollo/PATRON_GRID_EVENTS.md`](Desarrollo/PATRON_GRID_EVENTS.md).
  - [ ] `lnkEliminar_Click` que recorre `Grid.SelectedIndexes`.
- [ ] `View/<Modulo>/<SubModulo>/<Entidad>s.aspx(.cs)` con
      `#region SeguridadPagina` y las URLs del formulario.

---

## 4. Interfaz — formulario

- [ ] `View/<Modulo>/Controls/<Entidad>/<Entidad>.ascx(.cs)` — `RadTabStrip2` +
      `RadMultiPage` si hay tabs; botón Cerrar con `return false;`.
- [ ] Un `.ascx` por tab, con:
  - [ ] Todo dentro de `UpdatePanel`.
  - [ ] Controles del proyecto (`TextBox2`, `RadComboBox2`, `PushButton`) →
        [`Desarrollo/PATRON_CONTROLES.md`](Desarrollo/PATRON_CONTROLES.md).
  - [ ] `CustomValidator` + `validaControl` + `ValidationGroup` único por tab.
  - [ ] `LoadControls` para los combos (`!IsPostBack`).
  - [ ] `CargarDatos()`, `Bloqueo()`, `btnGuardar_Click` con `try/catch` y
        `ClientAlert`.
  - [ ] **Sin** `ScriptManager` propio.
- [ ] `View/<Modulo>/<SubModulo>/<Entidad>.aspx(.cs)` que descifra el
      querystring y setea `Id<Entidad>` / `ReadOnly`.

### El listado lleva `wucFiltro`. **Siempre.**

- [ ] `<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>`
- [ ] El control va en el placeholder **`cphFiltro`**, no dentro de `cphBody`.
- [ ] Los filtros propios, dentro de `<FiltroPersonalizado>` con la rejilla
      `row col-lg-12` que usa el resto del sitio.
- [ ] `wucFiltro.Filtro()` → al campo `filtro` del modelo → al **`@FILTRO`
      parametrizado** del `SEL_`. Nunca concatenado: en `SEL_CLIENTE_USUARIO`
      eso era inyección SQL desde el buscador (bloque 49).
- [ ] Los combos se leen con `wucFiltro.FindControl("cboX")`.
- [ ] Los que salen de un catálogo se pueblan con `OnLoad="LoadControls"`,
      **no se escriben a mano en el markup**: un catálogo copiado en un
      `.aspx` es el que nadie actualiza el día que cambia. Si no existe el
      `SEL_` del catálogo, se crea (bloque **67**, por ejemplo).

> Las cuatro pantallas del inventario nacieron **sin buscador**. La nota al
> pie de Repuestos incluso prometía uno —"el buscador mira el código, el
> nombre, el fabricante y el modelo"— que no existía en pantalla. Corregido
> el 31-08-2026.

### La ficha: pestañas, secciones y trazabilidad

- [ ] **Más de un bloque → `RadTabStrip2` + `RadMultiPage`**, no secciones
      apiladas. Tres bloques uno debajo del otro obligan a desplazar para
      llegar al último y hacen crecer la ventana.
      La pestaña que no aplica se oculta **entera** (`tab.Visible = false`),
      no vacía: una pestaña que al abrirla no tiene nada se lee como que la
      pantalla se rompió.
- [ ] **El formulario va seccionado** con `.sigma-form-seccion`: Identificación,
      Fabricante, Características, Vida útil… Quince campos en una sola
      rejilla obligan a leerlos todos para encontrar uno.
- [ ] **`wuc:Auditoria` al pie de toda ficha.**

```aspx
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>
...
<wuc:Auditoria runat="server" ID="wucAuditoria" />
```

```csharp
wucAuditoria.Mostrar(e.usuario_creacion_nombre, e.x_fecha_creacion,
                     e.usuario_actualizacion_nombre, e.x_fecha_actualizacion);
```

> Las tablas llevan sus cuatro columnas de auditoría desde las fundaciones y
> los SP las escriben religiosamente, pero **ningún `SEL_` las devolvía y
> ninguna pantalla las mostraba**: el dato existía y solo se podía leer con
> acceso a la base. Una auditoría que hay que consultar por SSMS no sirve
> para lo que se hizo.
>
> El `SEL_` tiene que devolver las cuatro columnas **y el nombre del
> usuario** —`USUARIO_CREACION_NOMBRE`, `USUARIO_ACTUALIZACION_NOMBRE`— con
> `LEFT JOIN` a `Usuario`. Devolver el id obliga a quien mira a ir a buscar
> quién es 7. Corregido para inventario en el bloque **68**.

---

## 5. Seguridad y navegación

> **En SIGMA la seguridad es por datos.** No existe `Paginas.cs` ni
> `SecurityManagerVer`: una pantalla sin fila en `Menus` no se abre, porque
> `Token.ExigirPagina()` niega por omisión.

- [ ] `INSERT` en **`Menus`** por cada pantalla — listado **y** ficha. La ficha
      va con `mnu_orden = 99` y `mnu_visible = 0`, pero **con su fila**: sin
      ella no se abre.
- [ ] `mnu_permiso` apuntando al permiso que la abre. `mnu_ambito`: 1 WEB,
      2 APP, 3 AMBOS (bloque 58).

### El **orden** de los hijos de un nodo

- [ ] `mnu_orden` refleja **qué hay que hacer primero**, no el alfabeto ni la
      importancia. Si B necesita que A exista, A va arriba.

> Un menú ordenado de otra forma le miente al que entra por primera vez: abre
> la primera opción, la encuentra vacía, y no tiene cómo saber que lo que le
> falta es haber pasado por otra pantalla.
>
> Inventario abría con **Repuestos**, pero un repuesto sin bodega no tiene
> dónde existir —sus umbrales se definen *por bodega* y el primer ingreso pide
> una—. Corregido en el bloque **66** a: Bodegas → Repuestos → Existencias →
> Movimientos.
>
> **Cuando la dependencia y el uso apuntan distinto, entre dos pantallas que
> ya se pueden abrir, manda el uso.** Por dependencia estricta Movimientos iría
> antes que Existencias —la existencia es la suma de los movimientos— pero una
> es un registro y la otra una consulta, y la consulta se mira cien veces por
> cada vez que se escribe.

- [ ] Las **fichas** van con `mnu_orden = 99` y `mnu_visible = 0`: tienen fila
      porque sin ella no se abren, pero no son una opción del árbol.

### `Menu_Funcion` — **siempre que se crea un menú**

- [ ] `INSERT` en **`Menu_Funcion`** por cada acción de la pantalla que no sea
      simplemente verla: `Crear y editar`, `Emitir período`, `Verificar pago`,
      `Otorgar y revocar`.

> **Esto se olvida y el síntoma engaña.** `Token.PuedeFuncion("Crear y
> editar")` busca la función **de la página actual** en el mapa que arma
> `SEL_MENUS_PERMISOS_MAPA`. Si no hay fila en `Menu_Funcion`, devuelve
> `false` **para todos, incluido Root** — y el botón "Nuevo" simplemente no
> aparece. Nadie ve un error: se ve una pantalla sin botón, y quien mira
> concluye que le falta un permiso que en realidad tiene.
>
> Pasó con el módulo de suscripción y volvió a pasar con el de inventario
> (bloque 62). El propio comentario de `Token.PuedeFuncion` lo advierte.
>
> El nombre de la función es **texto y tiene que calzar exactamente** con el
> que usa el `.aspx.cs`. `Crear y editar` es el que usa todo el sitio.

- [ ] Alternativa válida cuando la acción no es de una página concreta:
      `Token.Puede("CODIGO")` directo, sin pasar por `Menu_Funcion`. Es lo que
      hacen las **fichas**, porque `Menu_Funcion` cuelga del listado y desde
      la ficha no resuelve.
- [ ] `Perfil_Permiso` para los perfiles que corresponda — **incluidos Root y
      Soporte**. Root resuelve todo por regla en `SEL_USUARIO_PERMISOS`, pero
      dejar sus filas explícitas hace que la matriz se pueda leer.
- [ ] Verificar que **cada `mnu_link` apunte a un archivo que existe**.

---

## 6. Extras (solo si aplican)

- [ ] Endpoint AJAX para microacciones (orden, flags) →
      [`Desarrollo/PATRON_WEBSERVICE_AJAX.md`](Desarrollo/PATRON_WEBSERVICE_AJAX.md).
- [ ] Adjuntos: tabla `<Entidad>_Archivo` + control `<Entidad>Archivos.ascx`
      con descarga y visor de imágenes →
      [`Desarrollo/PATRON_CONTROLES.md`](Desarrollo/PATRON_CONTROLES.md) §8.
- [ ] Chips de estado en la grilla → §7 del mismo documento.
- [ ] Trigger de auditoría `TRG_LOG_<Tabla>` si el proyecto tiene tabla `LOG` →
      [`BaseDatos/PATRON_TABLAS.md`](BaseDatos/PATRON_TABLAS.md) §8.
- [ ] Exportación a Excel: parámetro `@EXCEL` en el `SEL_` con encabezados en
      español.

---

## 7. Cierre

- [ ] **Todos** los archivos nuevos en UTF-8 con BOM (verificar los creados con
      herramientas que no lo agregan) → [`CONVENCIONES.md`](CONVENCIONES.md) §2.
- [ ] Precompilar y confirmar `exitcode=0`:

```bash
"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_compiler.exe" -v "/Check" -p "C:\ruta\<RaizWeb>" "C:\temp\salida" -f
```

- [ ] Prueba funcional: listar → filtrar → crear → editar → deshabilitar/
      eliminar → volver al listado.
- [ ] Prueba con un usuario **sin** permiso: la pantalla debe redirigir y los
      botones restringidos no deben aparecer.
- [ ] Check-in en TFS con los archivos de BD y de código en el mismo changeset.
