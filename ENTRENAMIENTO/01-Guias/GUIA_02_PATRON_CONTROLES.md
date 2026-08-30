# Guía 02 — Patrón de Controles (Telerik `Rad*2` + `WebControls`)

> Archivo original: [`../00-Patrones-Originales/PATRON_CONTROLES.md`](../00-Patrones-Originales/PATRON_CONTROLES.md)
> Código de ejemplo: [`Identidad.ascx`](../02-Ejemplo-Usuario/View/Seguridad/Controls/Usuario/Identidad.ascx) y [`Usuarios.ascx`](../02-Ejemplo-Usuario/View/Seguridad/Controls/Usuario/Usuarios.ascx)
> Duración estimada: **50 min**

---

## 1. La regla que resume toda la guía

**Nunca uses el control nativo de ASP.NET si existe la versión del proyecto.**

| No uses | Usa | Por qué |
|---|---|---|
| `asp:TextBox` | `WebControls:TextBox2` | Ya trae `form-control`, `ReadOnly`, `UpperCase`, validación de largo |
| `asp:DropDownList` | `rad:RadComboBox2` | Filtro por texto, skin Bootstrap, `dbValues()`/`SetValues()` |
| `asp:Button` | `WebControls:PushButton` | Estilos M3, iconos, `UseSubmitBehavior=false` |
| `asp:GridView` | `rad:RadGrid2` | Paginación, orden, selección y los helpers `AddColumn` |
| `asp:CheckBox` | `WebControls:CheckBox2` | Estilos propios |

### ¿Qué es el "2" del nombre?

Son **wrappers**: clases que heredan del control original y le agregan defaults del proyecto.

```
Telerik.Web.UI.RadGrid          (Telerik, comprado)
        ↑ hereda
Telerik.Web.UI.RadGrid2         (nuestro, en Librarias/Library/Web/UI/Telerik/)
```

El wrapper hace tres cosas: aplica el skin Bootstrap, agrega helpers (`AddColumn`, `dbValues`) y **maneja `ReadOnly` de forma uniforme**.

Esto último es lo importante: cuando pones `ReadOnly = true` en cualquier control del proyecto, el control **renderiza un `<span>` con el valor y oculta el input**. No es un `disabled` que se pueda quitar desde el inspector del navegador — el input directamente no existe en el HTML.

---

## 2. `RadGrid2` — la grilla

### 2.1 Estructura mínima en el `.ascx`

Mira [`Usuarios.ascx`](../02-Ejemplo-Usuario/View/Seguridad/Controls/Usuario/Usuarios.ascx):

```aspx
<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>
        <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrUsuarios_ItemDataBound">
            <MasterTableView CommandItemDisplay="Top" DataKeyNames="usu_id">
                <CommandItemTemplate>
                    ... botones ...
                </CommandItemTemplate>
            </MasterTableView>
        </rad:RadGrid2>
    </ContentTemplate>
</asp:UpdatePanel>
```

Tres cosas que **siempre** van:

1. **`UpdatePanel` con `UpdateMode="Conditional"`.** Sin esto, cada click recarga toda la página. Con esto, se refresca solo el grid llamando a `udPanel.Update()`.
2. **`DataKeyNames`.** Es la lista de columnas que después puedes leer con `GetDataKeyValue("usu_id")`. Si la columna no está aquí, `GetDataKeyValue` explota en tiempo de ejecución. **Es el error #1 de los que empiezan.**
3. **`CommandItemDisplay="Top"` + `CommandItemTemplate`.** La barra de botones del grid.

### 2.2 Las columnas se declaran en C#, no en el markup

Este es el giro que sorprende a quien viene de GridView:

```csharp
if (!IsPostBack)
{
    Grid.AddSelectColumn();                                // checkbox de selección
    Grid.AddColumn("usu_id", "", Width: "3%");             // celda para el link Editar
    Grid.AddColumn("usu_rut", "RUT", Width: "12%");
    Grid.AddColumn("usu_nombres", "NOMBRES", Width: "20%");
    Grid.AddCheckboxColumn("usu_habilitado", "HABILITADO");
}
```

Helpers disponibles:

| Helper | Genera | Cuándo |
|---|---|---|
| `AddColumn(campo, titulo, ...)` | `GridBoundColumn` | Texto plano |
| `AddSelectColumn()` | `GridClientSelectColumn` | Checkbox de selección de fila |
| `AddCheckboxColumn(campo, titulo)` | `GridCheckBoxColumn` | Mostrar un `bit` |
| `AddTemplateColumn(unique, campo, titulo)` | `GridTemplateColumn` | Cuando vas a inyectar controles en `ItemDataBound` |

El **`if (!IsPostBack)` es obligatorio**. Si lo olvidas, en cada postback se agregan las columnas otra vez y el grid termina con las columnas duplicadas, triplicadas, etc. Síntoma clásico: "el grid se me llena de columnas repetidas al hacer click".

Fíjate en la primera columna: `AddColumn("usu_id", "", Width: "3%")` — título vacío, 3% de ancho. Esa celda existe **solo** para meterle dentro el icono de editar en `ItemDataBound`.

### 2.3 Dónde se cargan los datos: `Page_PreRender`, no `Page_Load`

```csharp
protected void Page_PreRender(object sender, EventArgs e)
{
    if (!IsPostBack) { /* columnas */ }

    if (ReadOnly)
        Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

    CargarGrid();
    Grid.DataBind();
    udPanel.Update();

    Tools.tools.RegisterPostBackScript(Grid);
}
```

**Por qué `PreRender` y no `Load`:** el ciclo de vida de WebForms es:

```
Init → Load → [eventos de los controles: Click, etc.] → PreRender → Render
```

Si cargas en `Load`, cargas **antes** de que se ejecute el click de "Eliminar". Resultado: eliminas un registro y sigue apareciendo en pantalla hasta que refrescas. Si cargas en `PreRender`, ya pasó el evento y ves el dato actualizado.

**Este es el concepto más importante de toda la guía.** Vale la pena dibujar el ciclo de vida en la pizarra.

---

## 3. `ItemDataBound` — inyectar controles por fila

Se ejecuta **una vez por cada fila** ya con datos:

```csharp
protected void rgrUsuarios_ItemDataBound(object sender, GridItemEventArgs e)
{
    if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
    {
        if (e.Item is GridDataItem)
        {
            GridDataItem item = e.Item as GridDataItem;
            string id = item.GetDataKeyValue("usu_id").ToString();

            string query = Server.UrlEncode(
                Tools.Crypto.Encrypt("IdUsuario=" + id + "&ReadOnly=" + ReadOnly));

            HyperLink Editar = new HyperLink();
            Editar.ID = "lnkEditar" + id;
            Editar.CssClass = "icono_Editar";
            Editar.NavigateUrl = "javascript:void(0)";
            Editar.Attributes.Add("onclick", "abrirUsuario('" + query + "')");

            item["usu_id"].Controls.Add(Editar);
        }
    }
}
```

Los dos `if` anidados no son paranoia:

- El primero filtra **filas de datos**. Sin él, el código corre también sobre el encabezado, el pie y el paginador, y revienta.
- El segundo valida el tipo antes del cast.

`item["usu_id"]` es la **celda** (`TableCell`) de esa columna en esa fila. Le agregas controles con `.Controls.Add(...)`.

### `HyperLink` o `LinkButton`: cuál elegir

| Necesito | Control | Por qué |
|---|---|---|
| **Navegar** a otra página / abrir modal | `HyperLink` + `onclick` JS | Sin postback: más rápido, no recarga |
| **Ejecutar código de servidor** (descargar, procesar) | `LinkButton` + evento `Command` | Necesitas el servidor |

En el ejemplo usamos `HyperLink` porque editar es navegar.

---

## 4. `RadComboBox2` y el patrón `LoadControls`

Mira [`Identidad.ascx.cs`](../02-Ejemplo-Usuario/View/Seguridad/Controls/Usuario/Identidad.ascx.cs).

En el markup:

```aspx
<rad:RadComboBox2 ID="cboPerfil" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
<rad:RadComboBox2 ID="cboPais"   runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
```

Los dos combos apuntan al **mismo método**. En el code-behind se desambigua con un `switch`:

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
                case "cboPerfil":
                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = new PerfilController().GetPerfiles(filtro);
                    ctrl.DataValueField = "per_id";
                    ctrl.DataTextField  = "per_nombre";
                    ctrl.DataBind();
                    break;
            }
        }
    }
}
```

Cuatro puntos a explicar:

1. **`if (!IsPostBack)`** — sin esto el combo se recarga en cada postback y **pierde la selección del usuario**. Síntoma: "escojo un perfil, guardo, y el combo vuelve a Seleccione".
2. **`AppendDataBoundItems = true`** — sin esto, el `DataBind()` **borra** el item "Seleccione..." que acabas de agregar. El orden es: agregar item → `AppendDataBoundItems = true` → `DataBind()`.
3. **`DataValueField` / `DataTextField`** deben ser nombres de propiedades **del Model** que devuelve el Controller. Si escribes `"per_nombres"` y la propiedad es `per_nombre`, falla en runtime, no al compilar.
4. Para **seleccionar** un valor se usa `cboPerfil.SelectedValue = "3"` (el Value), nunca el Text.

---

## 5. Validación: `CustomValidator` + `ValidationGroup`

Junto a cada campo obligatorio:

```aspx
<WebControls:TextBox2 ID="txtEmail" runat="server" MaxLength="200" LowerCase="true" />
<asp:CustomValidator ID="cvEmail" runat="server"
    ControlToValidate="txtEmail"
    ValidateEmptyText="true"
    ClientValidationFunction="validaControl"
    ValidationGroup="Usuario" />
```

Y en el botón:

```aspx
<WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar"
    OnClick="btnGuardar_Click" ValidationGroup="Usuario" />
```

**`ValidationGroup` tiene que ser idéntico en los validators y en el botón.** Si no coinciden, los validators simplemente no se ejecutan y el formulario guarda vacío. No hay error ni warning: falla en silencio. Es el bug más frustrante de esta capa.

`ValidateEmptyText="true"` es necesario porque, sin él, `CustomValidator` no valida los campos vacíos — que es justo lo que quieres validar.

Y en `Page_PreRender`:

```csharp
ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
```

Sin esta línea, el botón Guardar dentro de un `UpdatePanel` no dispara el postback completo. Síntoma: "hago click en Guardar y no pasa absolutamente nada".

---

## 6. `PushButton`: botón que guarda vs botón que solo navega

```aspx
<%-- Guarda: postback + validación --%>
<WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar"
    CssClass="Button IcoGuardar"
    OnClick="btnGuardar_Click" ValidationGroup="Usuario" />

<%-- Solo navega: el "return false" MATA el postback --%>
<WebControls:PushButton ID="btnCerrar" runat="server" Text="Volver"
    CssClass="ButtonCerrar IcoVolver"
    OnClientClick="closeWindow(); return false;" />
```

El `return false` es la diferencia. Sin él, el JS navega **y además** se dispara un postback inútil.

### Clases de estilo (M3)

| Clase | Uso |
|---|---|
| `Button` | Acción principal (Guardar) |
| `ButtonCerrar` | Cerrar / Volver |
| `ButtonAzul` | Énfasis medio |
| `ButtonEviar` | Enviar / confirmar |
| `ButtonCancelar` | Destructiva |

Iconos utilitarios que se combinan: `IcoGuardar`, `IcoVolver`, `IcoEditar`, `IcoEliminar`, `IcoBuscar`, `IcoCerrar`.

---

## 7. `LinkButton` en la barra del grid y `ConfirSweetAlert`

```aspx
<asp:LinkButton ID="lnkDeshabilitar" runat="server" Text="Deshabilitar"
    CssClass="icono_eliminar"
    OnClick="lnkDeshabilitar_Click"
    OnClientClick="return ConfirSweetAlert(this, '', 'Esta seguro...?');" />
```

Cómo funciona la combinación:

1. El usuario hace click.
2. Corre `OnClientClick` (navegador). `ConfirSweetAlert` muestra el diálogo.
3. Si **cancela** → devuelve `false` → `return false` → **no hay postback** → `OnClick` nunca se ejecuta.
4. Si **confirma** → devuelve `true` → postback → corre `lnkDeshabilitar_Click` en el servidor.

El `return` delante de `ConfirSweetAlert` es lo que hace que funcione. Sin `return`, el diálogo aparece pero el postback se dispara igual.

### Iconos de comandos

| Clase CSS | Uso |
|---|---|
| `icono_guardar` | Nuevo / Añadir |
| `icono_eliminar` | Eliminar / Deshabilitar |
| `icono_Editar` | Editar (por fila) |
| `icono_ver_Lupa` | Ver detalle |
| `icono_descargar_excel` | Exportar |

---

## 8. `Bloqueo()` — el modo consulta en un solo lugar

```csharp
protected void Bloqueo()
{
    txtRut.ReadOnly       = ReadOnly;
    txtNombres.ReadOnly   = ReadOnly;
    cboPerfil.ReadOnly    = ReadOnly;
    chkHabilitado.Enabled = !ReadOnly;
    txtPassword.Enabled   = !ReadOnly;   // ojo: Enabled, no ReadOnly
    btnGuardar.Visible    = !ReadOnly;
}
```

**Regla:** un solo método `Bloqueo()` por control, llamado desde `Page_PreRender`. Nunca repartas los `ReadOnly` por todo el archivo — cuando agregues un campo se te va a olvidar uno.

### La trampa del campo Password

En un `TextBox2` con `TextMode="Password"`, **NO** uses `ReadOnly = true`. Recuerda lo que hace el wrapper: renderiza un `<span>` con el texto. En un campo de contraseña eso significa **mostrar la contraseña en pantalla, sin máscara**. Usa `Enabled = false`.

---

## 9. Cheatsheet para pegar en la pared

| Necesito... | Uso |
|---|---|
| Listado con paginación y selección | `rad:RadGrid2` + helpers `Add*Column` |
| Combo cargado desde BD | `rad:RadComboBox2` + `OnLoad="LoadControls"` |
| Campo numérico | `rad:RadNumericBox2` |
| Texto corto | `WebControls:TextBox2` |
| Texto largo | `WebControls:TextArea2` |
| Botón Guardar | `WebControls:PushButton` + `OnClick` + `ValidationGroup` |
| Botón Volver | `WebControls:PushButton` + `OnClientClick="...; return false;"` |
| Acción de grilla con confirmación | `asp:LinkButton` + `return ConfirSweetAlert(...)` + `OnClick` |
| Link Editar por fila | `HyperLink` en `ItemDataBound` |
| Campo obligatorio | `asp:CustomValidator ClientValidationFunction="validaControl"` |
| Mensaje al usuario | `Tools.tools.ClientAlert(texto, "ok"/"alerta"/"error", cerrarModal)` |
| Refrescar grid tras cerrar modal | `Tools.tools.RegisterPostBackScript(Grid)` + JS `refresh()` |

---

## 10. Los 6 errores que vas a ver esta semana

1. **Columnas duplicadas en el grid** → falta el `if (!IsPostBack)` al agregar columnas.
2. **`GetDataKeyValue` explota** → la columna no está en `DataKeyNames`.
3. **El combo pierde la selección** → falta el `if (!IsPostBack)` en `LoadControls`.
4. **Desaparece "Seleccione..."** → falta `AppendDataBoundItems = true`.
5. **El botón Guardar no hace nada** → falta `RegisterPostBackControl(btnGuardar)`.
6. **Guarda sin validar** → `ValidationGroup` distinto entre validators y botón.
