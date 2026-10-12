# Patrón de uso de controles — Telerik (`Rad*2`), `WebControls` y `asp:LinkButton`

Complementa [`PATRON_MVC.md`](PATRON_MVC.md) y describe **cómo se usan los
controles de UI** en `.ascx`/`.aspx` y su code-behind.

> Los wrappers `Rad*2` viven en `Lib*/Library/Web/UI/Telerik/*.cs`
> (namespace `Telerik.Web.UI`): heredan de los controles Telerik originales y
> agregan defaults (skin, helpers, manejo de `ReadOnly`).
> Los controles propios viven en `Lib*/Library/Web/UI/WebControls/*.cs`
> (namespace `WebControls`).
> Tagprefix registrados en `web.config`: `rad:` → `Telerik.Web.UI`,
> `WebControls:` → `WebControls`.

**Antes de copiar markup entre proyectos**, verificar que existan las clases
CSS y los wrappers usados (ver [`../README.md`](../README.md) §3).

---

## 1. `rad:RadGrid2` — Grillas

### 1.1 Declaración en `.ascx`

```aspx
<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>
        <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgr<Entidad>_ItemDataBound">
            <MasterTableView CommandItemDisplay="Top" DataKeyNames="<pfx>_id, <pfx>_<fk_padre>">
                <CommandItemTemplate>
                    <div style="margin-bottom: 5px;">
                        <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar"
                            OnClientClick="abrir<Entidad>(0)" />
                        <asp:LinkButton ID="lnkEliminar" runat="server" Text="Eliminar" CssClass="icono_eliminar"
                            OnClick="lnkEliminar_Click"
                            OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea eliminar los registros seleccionados?');" />
                    </div>
                </CommandItemTemplate>
            </MasterTableView>
            <!-- Opcional: scroll interno para grids dentro de modales -->
            <ClientSettings>
                <Scrolling AllowScroll="True" ScrollHeight="320" />
            </ClientSettings>
        </rad:RadGrid2>
    </ContentTemplate>
</asp:UpdatePanel>
```

- Siempre dentro de un `asp:UpdatePanel` (`UpdateMode="Conditional"`) para
  refrescar con `udPanel.Update()` sin recargar la página.
- `DataKeyNames` lista las columnas que después se leen con
  `GetDataKeyValue("campo")` o `MasterTableView.DataKeyValues[i]["campo"]`.
  Si el markup declara `ClientDataKeyNames`, declarar **también**
  `DataKeyNames`: son colecciones distintas y el code-behind usa la de servidor.
- `CommandItemDisplay="Top"` + `CommandItemTemplate` con las acciones
  (`Nuevo`, `Eliminar`, `Añadir`, `Asociar`...) como `asp:LinkButton` (§4).

### 1.2 Construcción de columnas (code-behind, `!IsPostBack`)

`RadGrid2` agrega helpers para no escribir el XML de columnas a mano:

```csharp
if (!IsPostBack)
{
    Grid.AddSelectColumn();                                     // checkbox de selección
    Grid.AddColumn("<PFX>_ID", "", Width: "2%");                // columna espaciadora/oculta
    Grid.AddColumn("<PFX>_NOMBRE", "NOMBRE", Width: "60%");
    Grid.AddColumn("<PADRE>_NOMBRE", "<PADRE>", Width: "28%", Align: HorizontalAlign.Left);
    Grid.AddCheckboxColumn("<PFX>_HABILITADO", "HABILITADO");
    Grid.AddTemplateColumn("miColumna", "<PFX>_CAMPO", "ENCABEZADO", Width: "10%");
}
```

Métodos disponibles (verificar la firma real en el `RadGrid2.cs` del proyecto):

- `AddColumn(Field, Header, Width, Align, Wrap, SortExpression, DataFormat, ReadOnly, Agregate, FooterText, ...)` — `GridBoundColumn`.
- `AddSelectColumn(Width, Resizable, Align, HeaderAlign)` — `GridClientSelectColumn`, habilita `AllowRowSelect`.
- `AddCheckboxColumn(Field, Header, Width, Resizable, Editable, HederWrap)` — booleanos (`HABILITADO`).
- `AddTemplateColumn(uniqueName, Field, Header, Width, ...)` — obligatorio cuando se van a insertar controles dinámicos en `ItemCreated`/`ItemDataBound`.
- `AddEditColumn`, `AddCommandColumn`, `AddGroupField` — casos puntuales.
- `Width` admite `"NN"` (px) o `"NN%"`.

### 1.3 Carga de datos (`Page_PreRender`)

```csharp
protected void Page_PreRender(object sender, EventArgs e)
{
    if (!IsPostBack)
    {
        // construcción de columnas (§1.2)
    }

    if (ReadOnly)
        Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

    CargarGrid();
    Grid.DataBind();
    udPanel.Update();

    Tools.tools.RegisterPostBackScript(Grid);
}

protected void CargarGrid()
{
    <Entidad>Controller controller = new <Entidad>Controller();
    <Entidad> filtro = new <Entidad>();

    // ... aplicar filtros desde wucFiltro / combos ...

    Grid.DataSource = controller.Get<Entidad>s(filtro);
}
```

- `Tools.tools.RegisterPostBackScript(Grid)` registra el script para que la
  función JS `refresh()` (`__doPostBack("<%=Grid.ClientID %>", '')`) refresque
  el grid vía AJAX tras cerrar un modal o guardar.
- Grid de solo lectura → ocultar la barra de comandos.

### 1.4 `OnItemDataBound` — links/controles por fila

```csharp
protected void rgr<Entidad>_ItemDataBound(object sender, GridItemEventArgs e)
{
    if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
    {
        if (e.Item is GridDataItem)
        {
            GridDataItem item = e.Item as GridDataItem;
            string id = item.GetDataKeyValue("<pfx>_id").ToString();

            string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id<Entidad>=" + id + "&ReadOnly=" + ReadOnly));

            HyperLink Editar = new HyperLink();
            Editar.ID = "lnkEditar" + id;
            Editar.CssClass = "icono_Editar";
            Editar.NavigateUrl = "javascript:void(0)";
            Editar.Attributes.Add("onclick", "abrir<Entidad>('" + query + "')");

            item["<pfx>_id"].Controls.Add(Editar);
        }
    }
}
```

Detalle completo del ciclo `ItemCreated` / `ItemDataBound` / `Command` en
[`PATRON_GRID_EVENTS.md`](PATRON_GRID_EVENTS.md).

### 1.5 Eliminar seleccionados

```csharp
protected void lnkEliminar_Click(object sender, EventArgs e)
{
    try
    {
        if (Grid.SelectedIndexes.Count == 0)
        {
            Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
        }
        else
        {
            Respuesta respuesta = new Respuesta();
            <Entidad>Controller controller = new <Entidad>Controller();

            foreach (string idx in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(idx)];
                int id = Int32.Parse(value["<pfx>_id"].ToString());

                <Entidad> entidad = new <Entidad>();
                entidad.<pfx>_id = id;
                respuesta = controller.Delete<Entidad>(entidad);
            }

            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
    }
    catch (Exception ex)
    {
        Tools.tools.ClientAlert(ex.Message);
    }
}
```

### 1.6 Mostrar/ocultar botones del `CommandItem`

No se hace en `ItemCreated`/`ItemDataBound`, sino en `CargarGrid()` **después**
de `Grid.DataBind()` (antes, el `CommandItem` todavía no existe):

```csharp
Grid.DataBind();

if (!ReadOnly)
{
    LinkButton lnkNuevo = (LinkButton)Grid.MasterTableView.GetItems(GridItemType.CommandItem)[0].FindControl("lnkNuevo");
    LinkButton lnkAsociar = (LinkButton)Grid.MasterTableView.GetItems(GridItemType.CommandItem)[0].FindControl("lnkAsociar");

    lnkNuevo.Visible = !Asociar;
    lnkAsociar.Visible = Asociar;
}
```

- `GetItems(GridItemType.CommandItem)[0]` es la barra superior (la inferior,
  si existe, es `[1]`).
- Los IDs deben coincidir con los `LinkButton` del `CommandItemTemplate`.

---

## 2. `rad:RadComboBox2` — Combos

### 2.1 Declaración

```aspx
<rad:RadComboBox2 ID="cbo<Entidad>" runat="server" OnLoad="LoadControls" Filter="Contains" Width="50%" />

<!-- Con AutoPostBack para refrescar el grid al cambiar -->
<rad:RadComboBox2 ID="cbo<Entidad>" runat="server" OnLoad="LoadControls" MarkFirstMatch="true"
    EnableLoadOnDemand="true" Width="80%" Filter="Contains" AutoPostBack="true" />

<!-- Con ítems fijos en el markup -->
<rad:RadComboBox2 ID="cboHabilitados" runat="server" Filter="Contains" Width="100%">
    <Items>
        <rad:RadComboBoxItem Text="Todos" Value="" />
        <rad:RadComboBoxItem Text="Habilitados" Value="True" />
        <rad:RadComboBoxItem Text="Deshabilitados" Value="False" />
    </Items>
</rad:RadComboBox2>
```

### 2.2 Carga de datos — `OnLoad="LoadControls"`

Patrón estándar para poblar combos **una sola vez**:

```csharp
public void LoadControls(object sender, EventArgs e)
{
    if (!IsPostBack)
    {
        if (sender is RadComboBox2)
        {
            RadComboBox2 ctrl = (RadComboBox2)sender;
            switch (ctrl.ID)
            {
                case "cbo<Entidad>":
                    <Entidad> filtro = new <Entidad>();
                    filtro.filtro_habilitado = true;

                    <Entidad>Controller controller = new <Entidad>Controller();

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = controller.Get<Entidad>s(filtro);
                    ctrl.DataValueField = "<pfx>_id";
                    ctrl.DataTextField = "<pfx>_nombre";
                    ctrl.DataBind();
                    break;
            }
        }
    }
}
```

- Ítem `"Seleccione..."` con `Value=""` agregado **antes** del `DataBind()`,
  junto con `AppendDataBoundItems = true`.
- `DataValueField`/`DataTextField` = nombres de propiedades del Model.
- Un mismo `LoadControls` maneja varios combos vía `switch (ctrl.ID)`.
- Si un combo se recarga en **cada** postback (depende de otro filtro con
  `AutoPostBack`), hacer `ctrl.Items.Clear()` antes de volver a poblarlo.
- El evento de cambio usa `RadComboBoxSelectedIndexChangedEventArgs`.

### 2.3 Modo `ReadOnly`

`RadComboBox2.ReadOnly = true` renderiza el valor como `<span>` y oculta el
combo. Se aplica junto al resto de controles en `Bloqueo()`:

```csharp
protected void Bloqueo()
{
    cbo<Entidad>.ReadOnly = ReadOnly;
    txtNombre.ReadOnly = ReadOnly;
    btnGuardar.Visible = !ReadOnly;
}
```

### 2.4 Multi-selección

```csharp
entidad.<pfx>_campo_csv = ctrl.dbValues();   // guardar: CSV de los Value marcados
ctrl.SetValues(entidad.<pfx>_campo_csv);     // cargar: marca los ítems del CSV
```

---

## 3. `rad:RadNumericBox2` — Campos numéricos

```aspx
<rad:RadNumericBox2 ID="txtMonto" runat="server" Width="100%">
    <NumberFormat DecimalDigits="0" />
</rad:RadNumericBox2>
<asp:CustomValidator ID="CustomValidator1" runat="server"
    ControlToValidate="txtMonto"
    ValidateEmptyText="true"
    ClientValidationFunction="validaControl"
    ValidationGroup="<Entidad>" />
```

- Defaults: `DecimalDigits = 0`, alineado a la derecha, `MaxLength = 12`,
  clase `form-control`. Para decimales, sobreescribir `NumberFormat`.
- `ReadOnly = true` (o `Lock = true`) renderiza un `<span>` con el valor
  formateado y oculta el control.
- Uso dinámico dentro de una columna template:

```csharp
RadNumericBox2 txtOrden = new RadNumericBox2();
txtOrden.ID = "txtOrden" + id;
txtOrden.Value = orden;
txtOrden.Enabled = !ReadOnly;
txtOrden.Attributes.Add("onblur", "registraOrden('" + txtOrden.ClientID + "','" + id + "')");
item["<PFX>_ORDEN"].Controls.Add(txtOrden);
```

  El `onblur` llama a una función JS que hace `$.ajax` a un endpoint ASMX
  (ver [`PATRON_WEBSERVICE_AJAX.md`](PATRON_WEBSERVICE_AJAX.md)) y luego
  `refresh()`.

---

## 4. `asp:LinkButton` — acciones de grilla

Combina `OnClientClick` (JS en el navegador) y `OnClick` (postback al servidor).

### 4.1 Solo navegación cliente

```aspx
<asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar"
    OnClientClick="abrir<Entidad>(0)" />
```

```js
function abrir<Entidad>(query) {
    window.location = ('<%=ResolveUrl(URLNuevo<Entidad>) %>?query=' + query);
}
```

### 4.2 Confirmación + acción de servidor

```aspx
<asp:LinkButton ID="lnkEliminar" runat="server" Text="Eliminar" CssClass="icono_eliminar"
    OnClick="lnkEliminar_Click"
    OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea eliminar los registros seleccionados?');" />
```

- `ConfirSweetAlert(this, titulo, mensaje)` (función JS global) muestra el
  diálogo: si el usuario cancela devuelve `false` y **no** hay postback; si
  confirma, se ejecuta `lnkEliminar_Click`.

### 4.3 Solo acción de servidor

```aspx
<asp:LinkButton ID="lnkAsociar" runat="server" Text="Asociar" CssClass="icono_guardar"
    OnClick="lnkAsociar_Click" />
```

### 4.4 Links dinámicos por fila

Para acciones por fila (Editar, Ver detalle) se usa `HyperLink` creado en
`ItemDataBound` con `NavigateUrl="javascript:void(0)"` y atributo `onclick`
(§1.4), no `LinkButton`: evita el postback y abre el modal/página vía JS.

### 4.5 Convención de íconos (`CssClass`)

Clases habituales — **verificar que existan en el proyecto destino**, varían:

| Clase | Uso |
|---|---|
| `icono_guardar` | Nuevo / Añadir / Asociar / Guardar |
| `icono_eliminar` | Eliminar / Quitar / Desasociar |
| `icono_Editar` | Editar (link por fila) |
| `icono_ver_Lupa` | Ver detalle |
| `icono_Descargar` | Descargar archivo |
| `icono_descargar_excel` | Exportar / Carga masiva |

---

## 5. `WebControls:*` — controles propios

### 5.1 `TextBox2`

```aspx
<WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
<asp:CustomValidator ID="CustomValidator1" runat="server"
    ControlToValidate="txtNombre"
    ValidateEmptyText="true"
    ClientValidationFunction="validaControl"
    ValidationGroup="<Entidad>" />
```

- Hereda de `TextBox`, `CssClass = "form-control"` por defecto.
- Propiedades extra: `UpperCase`, `LowerCase`, `RequiredField`, `ValidaMaxLength`.
- `ReadOnly = true` → renderiza `<span>{Text}</span>` y oculta el input.
  **Por eso nunca usar `ReadOnly` en campos de contraseña** (mostraría el texto
  plano); usar `Enabled="false"`.

### 5.2 `TextArea2`

```aspx
<WebControls:TextArea2 ID="txtDescripcion" runat="server" />
```

Equivalente multilínea, para campos `NVARCHAR(MAX)`.

### 5.3 `PushButton`

```aspx
<WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar"
    OnClick="btnGuardar_Click" ValidationGroup="<Entidad>" />
<WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar"
    OnClientClick="closeWindow(); return false;" CssClass="ButtonCerrar" />
```

- Hereda de `Button`, `CssClass = "Button"`, `UseSubmitBehavior = false`.
- Botones que **solo** navegan/cierran: `OnClientClick="...; return false;"`.
- Botones de guardar: `OnClick` + `ValidationGroup` (el mismo de los validators).
- El `PushButton` renderiza un `<input type="submit">` (no admite `::before`),
  por eso los iconos se aplican como SVG inline en `background-image` desde el
  CSS del proyecto.

### 5.4 `ComboBox2` / `CheckBox2` / `Calendar`

- `ComboBox2`: select simple sin Telerik. Mismo patrón de carga (`LoadControls`).
- `CheckBox2`: checkbox con estilos propios.
- `Calendar`: la propiedad `.Value` es `DateTime?`; castear como
  `(WebControls.Calendar)controlRef` al obtenerlo por `FindControl`.

---

## 6. Validación cliente

```aspx
<asp:CustomValidator ID="CustomValidatorN" runat="server"
    ControlToValidate="<idControl>"
    ValidateEmptyText="true"
    ClientValidationFunction="validaControl"
    ValidationGroup="<NombreFormulario>" />
```

- `validaControl` es una función JS global del proyecto, genérica para
  `TextBox2`, `RadComboBox2`, `RadNumericBox2`, etc.
- El `ValidationGroup` debe coincidir entre **todos** los validators y el botón
  Guardar del mismo tab/formulario.
- En `Page_PreRender`:
  `ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);` para
  que el guardar funcione dentro del `UpdatePanel`.

---

## 7. Chips de estado en grillas

Para columnas que muestran **estado, categoría o importancia** con significado
(Pendiente/Enviado/Completado, Alta/Media/Baja), usar una columna template +
`Label` con clase de chip, **no** una columna de texto plano.

`Page_Load` (`!IsPostBack`):

```csharp
Grid.AddTemplateColumn("estadoChip", "", "ESTADO", Width: "10%", ItemPosition: HorizontalAlign.Center);
```

`ItemDataBound`:

```csharp
string estado = DataBinder.Eval(item.DataItem, "<pfx_estado>_nombre").ToString();

Label lblEstado = new Label();
lblEstado.Text = estado;
lblEstado.CssClass = "grid-estado-chip " + GetEstadoChipCss(estado);
item["estadoChip"].Controls.Add(lblEstado);
```

```csharp
private string GetEstadoChipCss(string estado)
{
    switch ((estado ?? "").Trim().ToUpper())
    {
        case "ENVIADO":    return "is-info";
        case "COMPLETADA": return "is-exito";
        case "ALTA":       return "is-alerta";
        default:           return "is-neutro";
    }
}
```

Variantes tonales habituales (verificar que el CSS exista en el destino):

| Clase | Uso típico |
|---|---|
| `is-neutro` | Estado por defecto / pendiente / prioridad baja |
| `is-info` | En curso / prioridad media |
| `is-acento` | Categoría secundaria destacada |
| `is-exito` | Completado / finalizado |
| `is-alerta` | Prioridad alta / abortado / error |

- El mapeo se hace por el **nombre** del estado devuelto por el SP, salvo que
  el datasource exponga el id (en ese caso, preferir el id).
- Cada control define su propio `Get<Algo>ChipCss(...)` privado: no crear un
  mapeo global, cada columna tiene su propio significado de colores.

---

## 8. Adjuntos: descarga y previsualización de imágenes

Patrón para los controles de archivos (`<Entidad>Archivos.ascx`):

```csharp
// Page_Load (!IsPostBack)
Grid.AddTemplateColumn("verImagen", "", "VER", Width: "5%", ItemPosition: HorizontalAlign.Center);
Grid.AddTemplateColumn("documentoFisico", "", "DESCARGAR", Width: "5%", ItemPosition: HorizontalAlign.Center);
```

```csharp
// Grid_ItemCreated
LinkButton lnkVer = new LinkButton();
lnkVer.ID = "lnkVer";
lnkVer.Text = "&nbsp";
lnkVer.CssClass = "icono_ver_Lupa";
lnkVer.Command += new CommandEventHandler(lnkVer_Command);
item["verImagen"].Controls.Add(lnkVer);
ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkVer);
```

```csharp
// Grid_ItemDataBound
string extension = DataBinder.Eval(item.DataItem, "<pfx>_extension").ToString();
LinkButton lnkVer = (LinkButton)item["verImagen"].FindControl("lnkVer");
lnkVer.CommandName = id;
lnkVer.CommandArgument = extension;
lnkVer.Visible = ArchivoController.EsImagen(extension);
```

```csharp
// Handler: envía la imagen como data URI al cliente y abre el lightbox
protected void lnkVer_Command(Object sender, CommandEventArgs e)
{
    Archivo item = new Archivo();
    item.<pfx>_archivo = int.Parse(e.CommandName.ToString());
    item = controller.GetBinario(item);

    string contentType = ArchivoController.GetContentType(e.CommandArgument.ToString());
    string base64 = Convert.ToBase64String(item.<pfx>_archivo_binario);

    Tools.tools.ClientExecute("archivoAbrirImagen('data:" + contentType + ";base64," + base64 + "')");
}
```

Markup del lightbox (tras el `UpdatePanel` del grid):

```aspx
<div id="pnlArchivoImagen" class="archivo-imagen-overlay" onclick="archivoCerrarImagen()">
    <span class="archivo-imagen-close"><i class="fas fa-times"></i></span>
    <img id="imgArchivoImagenGrande" class="archivo-imagen-grande" src="" alt="Imagen"
         onclick="event.stopPropagation();" />
</div>
<script type="text/javascript">
    function archivoAbrirImagen(src) {
        document.getElementById("imgArchivoImagenGrande").src = src;
        document.getElementById("pnlArchivoImagen").classList.add("is-open");
    }
    function archivoCerrarImagen() {
        document.getElementById("pnlArchivoImagen").classList.remove("is-open");
    }
</script>
```

- La lista de extensiones de imagen y el switch de content-type viven **una
  sola vez**, como helpers estáticos del `ArchivoController` del proyecto
  (`EsImagen`, `GetContentType`). No duplicarlos en otros controllers.
- La descarga usa el mismo patrón con `Response.AddHeader("content-disposition", ...)`
  + `Response.BinaryWrite(...)` — ver [`PATRON_GRID_EVENTS.md`](PATRON_GRID_EVENTS.md) §3.

---

## 9. Cheatsheet

| Necesito... | Control |
|---|---|
| Listado con paginación/orden/selección | `rad:RadGrid2` + helpers `AddColumn`/`AddSelectColumn`/`AddCheckboxColumn`/`AddTemplateColumn` |
| Combo cargado por Controller | `rad:RadComboBox2` + `OnLoad="LoadControls"` |
| Combo de selección múltiple | `RadComboBox2.dbValues()` / `SetValues()` |
| Campo numérico | `rad:RadNumericBox2` |
| Texto corto | `WebControls:TextBox2` |
| Texto largo | `WebControls:TextArea2` |
| Botón Guardar (con validación) | `WebControls:PushButton` + `OnClick` + `ValidationGroup` |
| Botón Cerrar / solo-cliente | `WebControls:PushButton` + `OnClientClick="...; return false;"` |
| Acción de grilla con confirmación | `asp:LinkButton` + `OnClientClick="return ConfirSweetAlert(...)"` + `OnClick` |
| Acción de grilla que abre formulario | `HyperLink` dinámico en `ItemDataBound` + querystring cifrado |
| Validación obligatoria de un campo | `asp:CustomValidator ClientValidationFunction="validaControl"` |
| Refrescar grid tras cerrar modal | `Tools.tools.RegisterPostBackScript(Grid)` + JS `refresh()` |
| Mensajes al usuario | `Tools.tools.ClientAlert(detalle, "ok"/"alerta"/"error", cerrarModal)` |
| Ejecutar JS desde el code-behind | `Tools.tools.ClientExecute("miFuncion(...)")` |
| Chip de estado en grid | `AddTemplateColumn` + `Label CssClass="grid-estado-chip is-xxx"` (§7) |
| Guardar sin recargar (orden, flags) | Endpoint ASMX + `$.ajax` (ver [`PATRON_WEBSERVICE_AJAX.md`](PATRON_WEBSERVICE_AJAX.md)) |
