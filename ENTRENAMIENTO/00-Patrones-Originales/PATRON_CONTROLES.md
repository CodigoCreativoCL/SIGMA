# Patrón de uso de controles – Telerik (`Rad...2`), `WebControls` y `asp:LinkButton`

Este documento complementa [PATRON_MVC.md](PATRON_MVC.md) y describe **cómo se
usan los controles de UI** en `.ascx`/`.aspx` y su code-behind: wrappers de
Telerik (`RadGrid2`, `RadComboBox2`, `RadNumericBox2`, etc.), los controles
propios de `WebControls` (`TextBox2`, `TextArea2`, `PushButton`, `ComboBox2`,
`CheckBox2`...) y `asp:LinkButton` para acciones con `OnClientClick`/`OnClick`.

> Los wrappers `Rad*2` están en
> `Librarias/Library/Web/UI/Telerik/*.cs` (namespace `Telerik.Web.UI`,
> heredan de los controles Telerik originales y agregan defaults: skin
> `Bootstrap`, helpers, manejo de `ReadOnly`, etc.).
> Los controles propios están en
> `Librarias/Library/Web/UI/WebControls/*.cs` (namespace `WebControls`).
> Registro de tagprefix en `web.config` / páginas: `rad:` → `Telerik.Web.UI`,
> `WebControls:` → `WebControls`.

---

## 1. `rad:RadGrid2` – Grillas

### 1.1 Declaración en `.ascx`

```aspx
<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>
        <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrXxx_ItemDataBound">
            <MasterTableView CommandItemDisplay="Top" DataKeyNames="<pk1>, <pk2>, ...">
                <CommandItemTemplate>
                    <div style="margin-bottom: 5px;">
                        <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClientClick="abrirXxx(0)" />
                        <asp:LinkButton ID="lnkEliminar" runat="server" Text="Eliminar" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
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
  poder refrescar con `udPanel.Update()` sin recargar la página.
- `MasterTableView.DataKeyNames` lista las columnas que luego se leen con
  `GetDataKeyValue("campo")` o `DataKeyValues[i]["campo"]`.
- `CommandItemDisplay="Top"` + `CommandItemTemplate` con los botones de
  acción (`Nuevo`, `Eliminar`, `Añadir`, `Quitar`, etc.) usando `asp:LinkButton`
  (ver sección 4).

### 1.2 Construcción de columnas (code-behind, `!IsPostBack`)

`RadGrid2` agrega helpers para no escribir XML de columnas a mano:

```csharp
protected void Page_Load(object sender, EventArgs e)
{
    if (!IsPostBack)
    {
        Grid.AddSelectColumn();                                    // checkbox de selección de fila
        Grid.AddColumn("XXX_ID", "", Width: "2%");                 // columna oculta/espaciadora
        Grid.AddColumn("XXX_ID", "ID", Width: "6%");
        Grid.AddColumn("XXX_NOMBRE", "NOMBRE", Width: "68%");
        Grid.AddColumn("PAI_NOMBRE", "PAÍS", Width: "28%", Align: HorizontalAlign.Left);
        Grid.AddCheckboxColumn("XXX_HABILITADO", "HABILITADO");
        Grid.AddTemplateColumn("MICOLUMNA", "CAMPO", "ENCABEZADO", Width: "10%");
    }
}
```

Métodos disponibles (`RadGrid2.cs`):
- `AddColumn(Field, Header, Width, Align, Wrap, SortExpression, DataFormat, ReadOnly, Agregate, FooterText, HederWrap, HeaderAlign, HerderToolTip, headerColor)`
  – columna de datos normal (`GridBoundColumn`).
- `AddSelectColumn(Width, Resizable, Align, HeaderAlign)` – columna de checkbox
  de selección (`GridClientSelectColumn`), habilita `AllowRowSelect`.
- `AddCheckboxColumn(Field, Header, Width, Resizable, Editable, HederWrap)` –
  columna `GridCheckBoxColumn` (para mostrar booleanos tipo `HABILITADO`).
- `AddTemplateColumn(uniqueName, Field, Header, Width, ...)` – columna
  `GridTemplateColumn`, se usa cuando hay que poner controles dinámicos en
  `ItemDataBound` (links, `RadNumericBox2`, labels, etc.).
- `AddEditColumn`, `AddCommandColumn`, `AddGroupField` – casos puntuales
  (edición inline, botones de comando, agrupamiento).
- `Width` admite `"NN"` (px) o `"NN%"`.

### 1.3 Carga de datos (`Page_PreRender`)

```csharp
protected void Page_PreRender(object sender, EventArgs e)
{
    if (!IsPostBack)
    {
        // Construcción de columnas (ver 1.2)
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
    XxxController controller = new XxxController();
    Xxx filtro = new Xxx();

    // ... aplicar filtros desde wucFiltro / combos ...

    Grid.DataSource = controller.GetXxxs(filtro);
}
```

- `Tools.tools.RegisterPostBackScript(Grid)` registra el script para que
  `__doPostBack("<%=Grid.ClientID %>", '')` (función JS `refresh()`) refresque
  el grid vía AJAX tras una operación (alta/baja/edición en una ventana modal).
- Si el grid es de **solo lectura** (`ReadOnly == true`), ocultar la barra de
  comandos con `CommandItemDisplay = GridCommandItemDisplay.None`.

### 1.4 `OnItemDataBound` – agregar links/controles por fila

```csharp
protected void rgrXxx_ItemDataBound(object sender, GridItemEventArgs e)
{
    if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
    {
        if (e.Item is GridDataItem)
        {
            GridDataItem item = e.Item as GridDataItem;
            string id = item.GetDataKeyValue("xxx_id").ToString();

            // Querystring cifrado para abrir el formulario de edición
            string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdXxx=" + id + "&ReadOnly=" + ReadOnly));

            HyperLink Editar = new HyperLink();
            Editar.ID = "lnkEditar" + id;
            Editar.CssClass = "icono_Editar";
            Editar.NavigateUrl = "javascript:void(0)";
            Editar.Attributes.Add("onclick", "abrirXxx('" + query + "')");

            item["xxx_id"].Controls.Add(Editar);

            // Ejemplo: RadNumericBox2 dinámico dentro de una columna template
            RadNumericBox2 txtOrden = new RadNumericBox2();
            txtOrden.ID = "txtOrden" + id;
            txtOrden.Value = /* valor actual */ 0;
            txtOrden.Enabled = !ReadOnly;
            txtOrden.Attributes.Add("onblur", "registraOrden('" + txtOrden.ClientID + "','" + id + "','...')");
            item["CHD_ORDEN"].Controls.Add(txtOrden);
        }
    }
}
```

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
            XxxController controller = new XxxController();

            foreach (string idx in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(idx)];
                int id = Int32.Parse(value["xxx_id"].ToString());

                Xxx entidad = new Xxx { xxx_id = id };
                respuesta = controller.DeleteXxx(entidad);
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

---

## 2. `rad:RadComboBox2` – Combos

### 2.1 Declaración

```aspx
<rad:RadComboBox2 ID="cboPais" runat="server" OnLoad="LoadControls" Filter="Contains" Width="50%" />

<!-- Con AutoPostBack para refrescar el grid al cambiar -->
<rad:RadComboBox2 ID="cboPais" runat="server" OnLoad="LoadControls" MarkFirstMatch="true"
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

### 2.2 Carga de datos – `OnLoad="LoadControls"`

Patrón estándar para poblar combos **una sola vez** (no en cada postback),
usando un Controller del módulo `Facilityges.Controller` / `SitioBase.Controller`:

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
                case "cboPais":
                    Paises filtro = new Paises { filtro_habilitado = "1" };
                    PaisesController paisesController = new PaisesController();

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = paisesController.GetPaises(filtro);
                    ctrl.DataValueField = "pai_id";
                    ctrl.DataTextField = "pai_nombres";
                    ctrl.DataBind();
                    break;
            }
        }
    }
}
```

- Item "Seleccione..." con `Value=""` agregado manualmente antes del
  `DataBind()`, junto con `AppendDataBoundItems = true`.
- `DataValueField` / `DataTextField` deben coincidir con las propiedades del
  Model devuelto por el Controller.
- Un mismo método `LoadControls` puede manejar **varios combos** del mismo
  control mediante el `switch (ctrl.ID)`.
- Para combos que dependen de otro filtro (ej. recargar `cboPais` al cambiar
  `AutoPostBack`), quitar el `Items.Clear()` antes de volver a poblar si se
  recarga en cada postback (ver `Clientes.ascx.cs`, que hace `ctrl.Items.Clear()`
  porque ese combo se recarga siempre, no solo en `!IsPostBack`).

### 2.3 Modo `ReadOnly`

`RadComboBox2.ReadOnly = true` renderiza el valor como `<span>{Text}</span>` y
oculta el combo (`Visible = false`, `display:none`). Se usa junto con el resto
de controles del formulario en `Bloqueo()`:

```csharp
protected void Bloqueo()
{
    cboPais.ReadOnly = ReadOnly;
    txtNombre.ReadOnly = ReadOnly;
    // ...
}
```

### 2.4 Multi-selección (`RadComboCheckBox2` / checkboxes en `RadComboBox2`)

`RadComboBox2` expone:
- `dbValues()` → string CSV con los `Value` de los ítems marcados
  (`CheckedItems`), para guardar en BD.
- `SetValues(string values)` → recorre el CSV y marca (`Checked = true`) los
  ítems correspondientes al cargar el formulario.

```csharp
// Guardar
entidad.campo_csv = ctrl.dbValues();

// Cargar
ctrl.SetValues(entidad.campo_csv);
```

---

## 3. `rad:RadNumericBox2` – Campos numéricos

### 3.1 Declaración típica

```aspx
<rad:RadNumericBox2 ID="txtMonto" runat="server" Width="100%">
    <NumberFormat DecimalDigits="0" />
</rad:RadNumericBox2>
<asp:CustomValidator ID="CustomValidator1" runat="server"
    ControlToValidate="txtMonto"
    ValidateEmptyText="true"
    ClientValidationFunction="validaControl"
    ValidationGroup="Xxx" />
```

- Por defecto: `NumberFormat.DecimalDigits = 0`, alineado a la derecha,
  `MaxLength = 12`, clase `form-control`.
- Para decimales, sobreescribir `NumberFormat.DecimalDigits` en el markup o
  en `Page_Load`.

### 3.2 Uso dinámico dentro de un `GridTemplateColumn` (ver 1.4)

```csharp
RadNumericBox2 txtOrden = new RadNumericBox2();
txtOrden.ID = "txtOrden" + id;
txtOrden.Value = chd_orden;
txtOrden.Enabled = !ReadOnly;
txtOrden.Attributes.Add("onblur", "registraOrden('" + txtOrden.ClientID + "','" + id + "','" + idPadre + "')");
item["CHD_ORDEN"].Controls.Add(txtOrden);
```

- `onblur` dispara una función JS que hace un `$.ajax` a un WebService
  (`WsOrdenChecklist.asmx`) y luego llama a `refresh()` (ver patrón JS en
  `ChecklistDetalle.ascx`).

### 3.3 Modo `ReadOnly` / `Lock`

`RadNumericBox2.ReadOnly = true` (o `Lock = true`) renderiza un `<span>` con
el valor formateado con `Tools.Formato.Miles(...)` y oculta el control.

```csharp
txtMonto.ReadOnly = ReadOnly;   // o txtMonto.Lock = true; para bloqueo independiente de ReadOnly
```

---

## 4. `asp:LinkButton` – acciones con `OnClientClick` + `OnClick`

`asp:LinkButton` es el botón estándar para **acciones de grilla** (Nuevo,
Editar, Eliminar, Añadir, Quitar, Asociar, etc.). Combina:

- **`OnClientClick`** → JavaScript que se ejecuta en el navegador (abrir
  ventana, confirmación, etc.).
- **`OnClick`** → evento de servidor (postback) que ejecuta el Controller.

### 4.1 Solo navegación cliente (sin postback)

```aspx
<asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar"
    OnClientClick="abrirXxx(0)" />
```

```js
function abrirXxx(query) {
    window.location = ('<%=ResolveUrl(URLNuevoXxx) %>?query=' + query);
}
```

- Si `OnClientClick` **no** retorna `false` ni hace `return`, el postback de
  todas formas se dispara después del JS (normalmente no afecta porque
  `window.location` ya navegó).

### 4.2 Confirmación (SweetAlert) + acción de servidor

```aspx
<asp:LinkButton ID="lnkEliminar" runat="server" Text="Eliminar" CssClass="icono_eliminar"
    OnClick="lnkEliminar_Click"
    OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea eliminar los registros seleccionados?');" />
```

- `ConfirSweetAlert(this, '', mensaje)` (función JS global del proyecto)
  muestra un `Swal` de confirmación:
  - Si el usuario **cancela**, `ConfirSweetAlert` retorna `false` →
    `OnClientClick="return false"` → **no** se dispara `OnClick` (no hay postback).
  - Si confirma, retorna `true` → continúa el postback normal y se ejecuta
    `lnkEliminar_Click` en el code-behind.
- El `OnClick` del code-behind sigue el patrón de la sección 1.5
  (`lnkEliminar_Click`): valida selección, recorre `Grid.SelectedIndexes`,
  llama `Delete<Entidad>` del Controller y muestra
  `Tools.tools.ClientAlert(respuesta.detalle, "ok"/"alerta", true)`.

### 4.3 Solo acción de servidor (sin confirmación)

```aspx
<asp:LinkButton ID="lnkAñadir" runat="server" Text="Añadir" CssClass="icono_guardar"
    OnClick="lnkAñadir_Click" />
```

```csharp
protected void lnkAñadir_Click(object sender, EventArgs e)
{
    // lógica + Tools.tools.ClientAlert(...)
}
```

### 4.4 Links dinámicos por fila (`HyperLink` en `ItemDataBound`)

Para acciones por fila (Editar, Ver detalle) se usa `HyperLink` (no
`LinkButton`) creado en `ItemDataBound` con `NavigateUrl = "javascript:void(0)"`
y el evento por atributo `onclick` (ver sección 1.4). Esto evita postback y
navega/abre modal vía JS (`abrirXxx('<query cifrada>')`).

### 4.5 Convención de íconos (`CssClass`)

Clases CSS estándar usadas en los `LinkButton`/`HyperLink` de comandos:
- `icono_guardar` – Nuevo / Añadir / Asociar / Guardar.
- `icono_eliminar` – Eliminar / Quitar / Desasociar.
- `icono_Editar` – Editar (link por fila).
- `icono_ver_Lupa` – Ver detalle.
- `icono_descargar_excel` – Exportar / Carga masiva.

---

## 5. `WebControls:*` – controles propios

Namespace `WebControls` (`Librarias/Library/Web/UI/WebControls`).

### 5.1 `WebControls:TextBox2`

```aspx
<WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
<asp:CustomValidator ID="CustomValidator1" runat="server"
    ControlToValidate="txtNombre"
    ValidateEmptyText="true"
    ClientValidationFunction="validaControl"
    ValidationGroup="Xxx" />
```

- Hereda de `TextBox`, `CssClass = "form-control"` por defecto.
- Propiedades extra: `UpperCase`, `LowerCase` (transforman el texto vía JS
  `onkeyup` + CSS `text-transform`), `RequiredField` (agrega un
  `RequiredFieldValidator` automáticamente), `ValidaMaxLength`.
- `ReadOnly = true` → renderiza `<span>{Text}</span>` y oculta el input.

### 5.2 `WebControls:TextArea2`

```aspx
<WebControls:TextArea2 ID="txtDescripcion" runat="server" />
```

- Equivalente a `TextBox2` pero multilínea (para campos `VARCHAR(MAX)`/`TEXT`).

### 5.3 `WebControls:PushButton`

```aspx
<WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Xxx" />
<WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" OnClientClick="closeWindow(); return false;" CssClass="ButtonCerrar" />
```

- Hereda de `Button`, `CssClass = "Button"` por defecto, `UseSubmitBehavior = false`.
- Para botones que **solo** navegan/cierran ventana (sin postback), usar
  `OnClientClick="...; return false;"` (el `return false` evita el postback).
- Para botones de **guardar**, usar `OnClick="btnGuardar_Click"` +
  `ValidationGroup="<MismoGrupoQueLosValidators>"`.
- `WaitText` disponible (actualmente sin comportamiento activo en el wrapper).

#### 5.3.1 Jerarquía de clases (estilo "M3 Expressive")

Los estilos viven en `Css/UI/WebControls/Button.css` usando los tokens
`--fg-m3-*` de `Css/LookAndFeel/v2/01-Variables.css`:

| Clase | Rol M3 | Uso |
|---|---|---|
| `Button` | Filled primario | Guardar / acción principal |
| `ButtonFilter` | Filled primario compacto (icono lupa) | Buscar/Filtrar en barras de filtro |
| `ButtonCerrar` | Tonal con borde (icono X) | Cerrar / Volver (acción secundaria) |
| `ButtonAzul` | Filled tonal | Énfasis medio / informativo |
| `ButtonEviar` | Filled success (icono enviar) | Enviar / confirmar positivo |
| `ButtonImprimir` | Filled warning (icono impresora) | Imprimir |
| `ButtonCancelar` | Filled error (icono X) | Cancelar / acción destructiva |

#### 5.3.2 Iconografía en botones (clases utilitarias `Ico*`)

`PushButton` renderiza `<input type="submit">` (no admite `::before`), por lo
que los iconos se aplican como SVG inline en `background-image`. Las clases
`ButtonCerrar`, `ButtonFilter`, `ButtonEviar`, `ButtonImprimir` y
`ButtonCancelar` ya traen icono por defecto. Para el resto, combinar la clase
de color con una utilitaria de icono **blanco** (solo sobre botones filled):

```aspx
<WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" CssClass="Button IcoGuardar" />
<WebControls:PushButton ID="btnVolver" runat="server" Text="Volver" CssClass="ButtonCerrar IcoVolver" />
```

Utilitarias disponibles: `IcoGuardar`, `IcoConfirmar`, `IcoCrear`,
`IcoVolver`, `IcoEditar`, `IcoEliminar`, `IcoBuscar`, `IcoCerrar`.
(`ButtonCerrar IcoVolver` tiene una variante gris específica para la
superficie tonal clara.) Ver ejemplos en vivo en
`View/Root/GuiaEstilos/GuiaEstilos.aspx`.

### 5.4 `WebControls:ComboBox2` / `WebControls:CheckBox2`

- `ComboBox2`: variante propia de combo (no Telerik) para selects simples
  donde no se requiere skin/filtro de Telerik.
- `CheckBox2`: checkbox con estilos propios del proyecto.
- Se usan con el mismo patrón de carga (`LoadControls` + Controller) cuando
  reemplazan a un `RadComboBox2`.

---

## 6. Validación cliente (`asp:CustomValidator` + `validaControl`)

Patrón repetido junto a cada campo obligatorio:

```aspx
<asp:CustomValidator ID="CustomValidatorN" runat="server"
    ControlToValidate="<idControl>"
    ValidateEmptyText="true"
    ClientValidationFunction="validaControl"
    ValidationGroup="<NombreFormulario>" />
```

- `ClientValidationFunction="validaControl"` es una función JS global del
  proyecto que valida que el control tenga valor (genérica para
  `TextBox2`, `RadComboBox2`, `RadNumericBox2`, etc.).
- `ValidationGroup` debe coincidir entre **todos** los validators y el botón
  `PushButton` de Guardar del mismo formulario/tab (ej. `"Cliente"`,
  `"Checklist"`).
- `ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);` se
  llama en `Page_PreRender` para que el botón Guardar funcione dentro del
  `UpdatePanel`.

---

## 7. Cards tonales, switch expandible y campo contraseña (MiCuenta.ascx)

Patrones agregados en el rediseño de `MiCuenta.ascx`
(`View/Comun/Controls/MiCuenta/MiCuenta.ascx`), reutilizables en cualquier
panel de "solo lectura" que necesite destacar información asociada
(Cliente, Instalaciones, etc.) o un campo de contraseña con cambio
opcional.

### 7.1 Card informativa tonal (`.identidad-card-cliente` / `.identidad-card-instalacion`)

Variante de `.cliente-container.identidad-card` con un tinte de fondo
(`--fg-m3-primary-container` / `--fg-m3-secondary-container`) para
diferenciar tarjetas de información asociada (de solo lectura) del resto
de tarjetas blancas del formulario. Los chips internos usan
`.identidad-readonly-chip.identidad-chip-tonal` (fondo semitransparente
blanco) o, para listas, `.identidad-instalacion-chip` dentro de
`.identidad-instalaciones-list`.

```aspx
<asp:Panel ID="pnlCliente" runat="server" CssClass="col-lg-6 col-md-6 col-xs-12 mb-3" Visible="false">
    <div class="cliente-container identidad-card identidad-card-cliente">
        <div class="cliente-label">
            <i class="fas fa-building"></i>
            <span>Cliente Asociado</span>
        </div>
        <div class="row col-12">
            <div class="form-group col-lg-4 col-md-4 col-xs-12 identidad-field">
                <label>ID Cliente</label>
                <div class="identidad-readonly-chip identidad-chip-tonal">
                    <asp:Label ID="lblClienteId" runat="server"></asp:Label>
                </div>
            </div>
            <div class="form-group col-lg-8 col-md-8 col-xs-12 identidad-field">
                <label>Nombre Cliente</label>
                <div class="identidad-readonly-chip identidad-chip-tonal">
                    <asp:Label ID="lblClienteNombre" runat="server"></asp:Label>
                </div>
            </div>
        </div>
    </div>
</asp:Panel>
```

- El `asp:Panel` se muestra/oculta (`Visible`) en `CargarDatos()` según si
  existen datos asociados (p. ej. `id_clientes`/`id_instalaciones` no
  vacíos).
- Para listas (varias instalaciones), usar `asp:Repeater` con
  `.identidad-instalacion-chip` por item (ver `rptInstalaciones` en
  `MiCuenta.ascx`).

### 7.2 Campos de contraseña con mostrar/ocultar (`.identidad-password-field`)

`WebControls:TextBox2` con `TextMode="Password"` (editable) envuelto en
`.identidad-password-field`, con un icono `fa-eye`/`fa-eye-slash` que
alterna el `type` del input vía JS. Se usa en los 3 campos del formulario
de cambio de contraseña (Actual / Nueva / Confirmar) dentro de
`pnlCambiarPassword` — **no** crear un campo de solo lectura separado para
"ver la contraseña actual": NO usar `ReadOnly="true"` en `TextBox2`
(renderiza un `<span>` con el texto plano y oculta el input, mostrando la
contraseña sin máscara); si se necesitara un campo deshabilitado, usar
`Enabled="false"` en su lugar.

```aspx
<div class="identidad-password-field">
    <WebControls:TextBox2 ID="txtPasswordActual" runat="server" TextMode="Password" MaxLength="100" />
    <i class="fas fa-eye identidad-password-toggle" onclick="togglePasswordVisibility('<%= txtPasswordActual.ClientID %>', this)"></i>
</div>
```

```javascript
function togglePasswordVisibility(inputId, icono) {
    var input = document.getElementById(inputId);
    if (input.type === "password") {
        input.type = "text";
        icono.classList.replace("fa-eye", "fa-eye-slash");
    } else {
        input.type = "password";
        icono.classList.replace("fa-eye-slash", "fa-eye");
    }
}
```

### 7.3 Switch en encabezado de card + sección expandible (`.identidad-switch` + `.identidad-collapse`)

Checkbox estilizado como switch M3 ubicado en el encabezado de la card
(`.cliente-label.cliente-label-actions`, con `.cliente-label-titulo` para
el icono+título a la izquierda y `.identidad-switch-row` para el switch a
la derecha). Al activarse, expande (sin recargar página) un `asp:Panel`
con `CssClass="identidad-collapse"` agregando la clase `is-open`
(transición CSS `max-height`/`opacity`).

```aspx
<div class="cliente-label cliente-label-actions">
    <div class="cliente-label-titulo">
        <i class="fas fa-lock"></i>
        <span>Seguridad</span>
    </div>
    <div class="identidad-switch-row">
        <span>Cambiar contraseña</span>
        <label class="identidad-switch">
            <asp:CheckBox ID="chkCambiarPassword" runat="server" onclick="toggleCambiarPassword(this)" />
            <span class="identidad-switch-slider"></span>
        </label>
    </div>
</div>

<asp:Panel ID="pnlCambiarPassword" runat="server" CssClass="identidad-collapse">
    <!-- campos de Contraseña actual / Nueva / Confirmar -->
</asp:Panel>
```

```javascript
function toggleCambiarPassword(checkbox) {
    var contenedor = document.getElementById('<%= pnlCambiarPassword.ClientID %>');
    contenedor.classList.toggle("is-open", checkbox.checked);
}
```

- En el code-behind, el estado del checkbox (`chkCambiarPassword.Checked`)
  define si se valida/actualiza la contraseña en `btnGuardar_Click`,
  independientemente del estado visual del `.identidad-collapse`.

### 7.4 Campo con icono dentro del input (`.identidad-field-icon`)

Para campos editables que requieren un icono identificador (p. ej.
Teléfono), envolver el `WebControls:TextBox2` en `.identidad-field-icon`
con un `<i>` posicionado sobre el padding izquierdo del input.

```aspx
<div class="identidad-field-icon">
    <i class="fas fa-phone"></i>
    <WebControls:TextBox2 ID="txtTelefono" runat="server" MaxLength="20" />
</div>
```

---

## 8. Chips de estado en grids y visor de imágenes (Archivos)

### 8.1 Chips de estado/categoría/importancia en grids (`.grid-estado-chip`)

Para columnas de grid que muestran un **estado, categoría o importancia**
con significado (Pendiente/Enviado/Completada, Alta/Media/Baja,
Interna/Externa, etc.), usar una columna `AddTemplateColumn` + `Label` con
clase `grid-estado-chip` más una variante tonal — **no** `AddColumn` con
texto plano. Estilos en `Css/LookAndFeel/v2/06-General.css`
(`.grid-estado-chip` y variantes), sobre los tokens `--fg-m3-*` de
`01-Variables.css` (incluye el par
`--fg-m3-error-container`/`--fg-m3-on-error-container` agregado para la
variante `is-alerta`).

Variantes disponibles:

| Clase | Tonalidad | Uso típico |
|---|---|---|
| `is-neutro` | Gris (`--fg-m3-chip-bg`) | Estado por defecto / pendiente / prioridad baja |
| `is-info` | Azul (`--fg-m3-primary-container`) | En curso / prioridad media |
| `is-acento` | Cian (`--fg-m3-secondary-container`) | Categoría secundaria/destacada |
| `is-exito` | Verde (`--fg-m3-success-container`) | Completado / finalizado |
| `is-alerta` | Rojo (`--fg-m3-error-container`) | Prioridad alta / abortado |

`Page_Load` (`!IsPostBack`):

```csharp
Grid.AddTemplateColumn("estadoChip", "", "ESTADO", Width: "10%", ItemPosition: HorizontalAlign.Center);
```

`Grid_ItemDataBound`:

```csharp
string estado = DataBinder.Eval(item.DataItem, "cte_nombre").ToString();

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
        case "ENVIADO":
            return "is-info";
        case "COMPLETADA":
            return "is-exito";
        default:
            return "is-neutro";
    }
}
```

- El mapeo se hace por el **nombre** del estado/categoría (`*_nombre`
  devuelto por el SP/Controller a través de `DataBinder.Eval`), no por el id
  numérico, salvo que el datasource ya expone el id (en ese caso preferir el
  id). Ver ejemplos reales: `Tareas.ascx.cs` (`cte_nombre`:
  Pendiente/Enviado/Completada), `OrdenesTrabajo.ascx.cs` (`cti_nombre`
  Importancia: Alta/Media/Baja → `is-alerta`/`is-info`/`is-neutro`;
  `ctc_nombre` Categoría: Interna/Externa → `is-acento`/`is-neutro`),
  `CheckList.ascx.cs` (`estado`: Pendiente/Finalizado/Abortado →
  `is-neutro`/`is-exito`/`is-alerta`).
- Cada control define su propio `GetXxxChipCss(...)` privado (un `switch`
  por columna) — no crear un mapeo global único, cada columna tiene su
  propio significado de colores.

### 8.2 Visor de imágenes adjuntas en controles `Archivos` (`.archivo-imagen-*`)

En los listados de adjuntos (`View/Comun/Controls/Cliente/Archivos/*.ascx`:
`BitacoraArchivos`, `CheckListArchivos`, `OrdenesTrabajoArchivos`,
`TareasArchivos`, `TareasRespuestaArchivos`), la columna **VER** abre un
lightbox inline (sin recargar página ni navegar a otra `.aspx`) cuando el
adjunto es una imagen. Se apoya en dos helpers **estáticos** de
`ArchivoController`:

```csharp
ArchivoController.EsImagen(string extension);      // true si la extensión es JPG/JPEG/PNG/GIF/BMP/WEBP
ArchivoController.GetContentType(string extension); // "image/jpeg", "image/png", ... o "application/octet-stream"
```

`Page_Load` (`!IsPostBack`), antes de la columna `documentoFisico`:

```csharp
Grid.AddTemplateColumn("verImagen", "", "VER", Width: "5%", ItemPosition: HorizontalAlign.Center);
Grid.AddTemplateColumn("documentoFisico", "", "DESCARGAR", Width: "5%", ItemPosition: HorizontalAlign.Center);
```

`Grid_ItemCreated`:

```csharp
LinkButton lnkVer = new LinkButton();
lnkVer.ID = "lnkVer";
lnkVer.Text = "&nbsp";
lnkVer.CssClass = "icono_ver_Lupa";
lnkVer.Command += new CommandEventHandler(lnkVer_Command);
lnkVer.ToolTip = "Ver Imagen";
item["verImagen"].Controls.Add(lnkVer);
ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkVer);
```

`Grid_ItemDataBound`:

```csharp
string extension = DataBinder.Eval(item.DataItem, "arc_extension").ToString();
LinkButton lnkVer = (LinkButton)item["verImagen"].FindControl("lnkVer");
lnkVer.CommandName = id;
lnkVer.CommandArgument = extension;
lnkVer.Visible = ArchivoController.EsImagen(extension);
```

Handler `lnkVer_Command` (envía la imagen como data URI base64 al cliente):

```csharp
protected void lnkVer_Command(Object sender, CommandEventArgs e)
{
    Archivo item = new Archivo();
    item.arc_archivo = int.Parse(e.CommandName.ToString());
    item = controller.GetBinario(item);

    string contentType = ArchivoController.GetContentType(e.CommandArgument.ToString());
    string base64 = Convert.ToBase64String(item.abi_archivo);

    Tools.tools.ClientExecute("archivoAbrirImagen('data:" + contentType + ";base64," + base64 + "')");
}
```

Markup `.ascx` (agregar tras el `asp:UpdatePanel` del grid):

```aspx
<div id="pnlArchivoImagen" class="archivo-imagen-overlay" onclick="archivoCerrarImagen()">
    <span class="archivo-imagen-close"><i class="fas fa-times"></i></span>
    <img id="imgArchivoImagenGrande" class="archivo-imagen-grande" src="" alt="Imagen" onclick="event.stopPropagation();" />
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

- Estilos `.archivo-imagen-overlay` / `.archivo-imagen-grande` /
  `.archivo-imagen-close` en `Css/LookAndFeel/v2/06-General.css` (mismo
  patrón de lightbox que `.ingreso-detalle-foto-overlay` de
  `IngresoDetalle.ascx`).
- No duplicar la lista de extensiones de imagen ni el switch de
  content-type en otro Controller: reutilizar siempre
  `ArchivoController.EsImagen`/`GetContentType`.

---

## 9. Resumen rápido (cheatsheet)

| Necesito...                                   | Control                              |
|------------------------------------------------|---------------------------------------|
| Listado con paginación/orden/selección          | `rad:RadGrid2` (+ helpers `AddColumn`/`AddSelectColumn`/`AddCheckboxColumn`/`AddTemplateColumn`) |
| Combo simple/cargado por Controller             | `rad:RadComboBox2` + `OnLoad="LoadControls"` |
| Combo de selección múltiple                     | `RadComboBox2.dbValues()` / `SetValues()` (o `RadComboCheckBox2`) |
| Campo numérico                                  | `rad:RadNumericBox2` |
| Texto corto                                     | `WebControls:TextBox2` |
| Texto largo / descripción                       | `WebControls:TextArea2` |
| Botón Guardar (con validación)                  | `WebControls:PushButton` + `OnClick` + `ValidationGroup` |
| Botón Cerrar / acción solo-cliente              | `WebControls:PushButton` + `OnClientClick="...; return false;"` |
| Acción de grilla con confirmación + postback    | `asp:LinkButton` + `OnClientClick="return ConfirSweetAlert(...)"` + `OnClick` |
| Acción de grilla solo navegación (abrir modal)  | `asp:LinkButton OnClientClick="abrirXxx(...)"` o `HyperLink` dinámico en `ItemDataBound` |
| Validación obligatoria de un campo              | `asp:CustomValidator ClientValidationFunction="validaControl"` |
| Refrescar grid tras cerrar modal                | `Tools.tools.RegisterPostBackScript(Grid)` + JS `refresh()` (`__doPostBack`) |
| Mensajes al usuario (ok/alerta/error)           | `Tools.tools.ClientAlert(detalle, "ok"/"alerta"/"error", cerrarModal)` |
| Chip de estado/categoría/importancia en grid    | `AddTemplateColumn` + `Label CssClass="grid-estado-chip is-xxx"` (ver 8.1) |
| Previsualizar imagen adjunta (Archivos)         | Columna `verImagen` + `ArchivoController.EsImagen`/`GetContentType` + lightbox `.archivo-imagen-*` (ver 8.2) |
