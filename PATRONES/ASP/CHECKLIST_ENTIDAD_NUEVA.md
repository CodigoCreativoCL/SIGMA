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

---

## 5. Seguridad y navegación

- [ ] `INSERT` de los menús con `mnu_link` en el formato del proyecto →
      [`Desarrollo/PATRON_SEGURIDAD_MENUS.md`](Desarrollo/PATRON_SEGURIDAD_MENUS.md) §2.
- [ ] `enum menu_<N>` en `Paginas.cs` con `Ver` y las funciones necesarias.
- [ ] `SecurityManagerVer` en el `Page_Load` de la página.
- [ ] Permisos finos (`Ver_Todo`, `Crear_Editar`) propagados al UserControl y
      aplicados con `Token.SecurityManager(...)`.
- [ ] Menú asignado al perfil desde **Sistema › Acceso › Perfiles**.

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
