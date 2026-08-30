# Patrón de eventos de RadGrid2 – FacilityGes (ItemCreated / Command / ItemDataBound)

Este documento describe cómo el equipo maneja en el code-behind (`.aspx.cs` /
`.ascx.cs`) los eventos del `RadGrid2` para crear controles dinámicos por fila,
asociarles una acción ("comando") y enlazarlos a los datos de cada fila.

> **Importante**: en este proyecto **no se usa** el evento de grilla
> `OnItemCommand` / `GridCommandEventArgs`. El "comando" de un botón dentro
> de la grilla se implementa con el patrón **ItemCreated + ItemDataBound +
> evento `Command` propio del control** (LinkButton, etc.), como se explica
> abajo.

---

## 1. Declaración en el `.aspx`/`.ascx`

El grid declara los handlers de `ItemCreated` y `ItemDataBound` (y opcionalmente
`ItemCommand` si se usa el patrón de botones de comando del `MasterTableView`,
pero lo más común en este proyecto es **solo** `ItemCreated`/`ItemDataBound`):

```aspx
<rad:RadGrid2 runat="server" ID="Grid"
    OnItemCreated="Grid_ItemCreated"
    OnItemDataBound="Grid_ItemDataBound">
    <MasterTableView CommandItemDisplay="None" DataKeyNames="arc_archivo">
    </MasterTableView>
</rad:RadGrid2>
```

- `DataKeyNames` debe incluir la(s) columna(s) que luego se leen con
  `item.GetDataKeyValue(...)` en `ItemDataBound`.
- Si la columna donde se va a insertar el control dinámico es de tipo
  plantilla, debe crearse antes con `Grid.AddTemplateColumn(...)` (ver
  `Web/Intranet/PATRON_CONTROLES.md`).

---

## 2. `Grid_ItemCreated` – crear el/los controles dinámicos por fila

Se usa para **crear** controles que no vienen declarados en el `.ascx`
(LinkButtons de acción, CheckBoxes, RadNumericBox2, etc.) y agregarlos a la
celda de la columna plantilla. Se ejecuta en cada postback/databind, por cada
ítem de la grilla (incluye encabezado si se valida `GridHeaderItem`).

Patrón estándar (botón de descarga de archivo), tomado de
`View/Comun/Controls/Cliente/Archivos/BitacoraArchivos.ascx.cs`:

```csharp
protected void Grid_ItemCreated(object sender, GridItemEventArgs e)
{
    if (e.Item is GridDataItem)
    {
        GridDataItem item = (e.Item as GridDataItem);

        LinkButton lnkDescarga = new LinkButton();
        lnkDescarga.ID = "lnkDescarga";
        lnkDescarga.Text = "&nbsp";
        lnkDescarga.CssClass = "icono_Descargar";
        lnkDescarga.Command += new CommandEventHandler(lnkDescarga_Command);
        lnkDescarga.ToolTip = "Descargar Archivo";

        item["documentoFisico"].Controls.Add(lnkDescarga);

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkDescarga);
    }
}
```

Reglas:
- Validar siempre `if (e.Item is GridDataItem)` (y, si aplica, también
  `if (e.Item is GridHeaderItem)` para crear controles en el encabezado, como
  en `View/Root/Mantenedores/Accesos/Accesos.aspx.cs` con los `CheckBox` por
  columna de permisos).
- El `ID` del control se fija fijo (mismo para todas las filas, ej.
  `"lnkDescarga"`); luego se ubica en `ItemDataBound` con
  `item["columna"].FindControl("lnkDescarga")`.
- Si el control va a disparar un postback (LinkButton/Button con `Command`),
  suscribir el handler con `+= new CommandEventHandler(...)` **aquí** y
  registrarlo con `ScriptManager.GetCurrent(Page).RegisterPostBackControl(ctrl)`
  para que funcione dentro del `UpdatePanel`.
- `item["NOMBRE_COLUMNA"]` es la `TableCell` de la columna (debe existir,
  agregada antes con `AddTemplateColumn`/`AddColumn`).
- Para crear controles dinámicos por **cada columna de un DataTable**
  (matriz de permisos/checkboxes), iterar `dt.Columns` dentro de
  `Grid_ItemCreated` como en `Accesos.aspx.cs`.

---

## 3. Patrón "GridCommand" – evento `Command` del control + handler dedicado

En vez de `OnItemCommand` del grid, cada control creado en `ItemCreated`
dispara su propio evento `Command`, que se atiende en un método dedicado
`xxx_Command(object sender, CommandEventArgs e)`. El dato necesario para la
acción (normalmente el Id de la fila) se asigna como `CommandName` en
`Grid_ItemDataBound` (ver sección 4).

```csharp
protected void lnkDescarga_Command(object sender, CommandEventArgs e)
{
    Archivo item = new Archivo();
    item.arc_archivo = int.Parse(e.CommandName.ToString());
    item = controller.GetBinario(item);

    HttpContext.Current.Response.Clear();
    HttpContext.Current.Response.Charset = "";
    HttpContext.Current.Response.AddHeader("content-disposition", "attachment; filename=" + item.arc_nombre_archivo + "");
    HttpContext.Current.Response.BinaryWrite(item.abi_archivo);
    HttpContext.Current.Response.End();
}
```

Reglas:
- La firma siempre es `(object sender, CommandEventArgs e)`.
- `e.CommandName` trae el valor asignado en `ItemDataBound` (normalmente el
  Id de la fila como string); convertir con `int.Parse(...)` según el tipo.
- `e.CommandArgument` se puede usar para un segundo dato si hace falta
  (no se observa en los ejemplos actuales, pero está disponible).
- La suscripción `control.Command += new CommandEventHandler(metodo)` se hace
  en `Grid_ItemCreated` (ver sección 2). **No** volver a suscribir el mismo
  handler en `Grid_ItemDataBound`: en algún archivo (`OrdenesTrabajoDetalle.ascx.cs`)
  aparece suscrito dos veces (una en `ItemCreated` y otra en `ItemDataBound`),
  lo cual duplica la ejecución del handler — **no replicar esa duplicación**,
  suscribir una sola vez en `ItemCreated`.
- Para acciones que **navegan** a otra página (ej. abrir un formulario de
  edición) en vez de ejecutar un `Command`, se usa un `HyperLink` con
  `NavigateUrl="javascript:void(0)"` y un atributo `onclick` que llama a una
  función JS de apertura de modal/redirección, pasando un querystring cifrado
  (ver sección 4, ejemplo de `Usuarios.ascx.cs`). En ese caso no hace falta
  `Command`/`CommandName`.

---

## 4. `Grid_ItemDataBound` – enlazar datos a los controles de la fila

Se ejecuta por cada fila ya con datos (`DataBind`). Aquí se busca el control
creado en `ItemCreated` y se le asignan los valores dependientes de la fila
(`CommandName`, `Text`, `CssClass`, atributos `onclick`, etc.).

### 4.1 Caso simple – asignar `CommandName` (descarga de archivo)

`View/Comun/Controls/Cliente/Archivos/BitacoraArchivos.ascx.cs`:

```csharp
protected void Grid_ItemDataBound(object sender, Telerik.Web.UI.GridItemEventArgs e)
{
    if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
    {
        if (((e.Item) is GridDataItem))
        {
            GridDataItem item = e.Item as GridDataItem;
            string id = item.GetDataKeyValue("arc_archivo").ToString();

            LinkButton lnkDescarga = (LinkButton)item["documentoFisico"].FindControl("lnkDescarga");
            lnkDescarga.CommandName = id;
        }
    }
}
```

### 4.2 Caso con querystring cifrado + `HyperLink`/navegación

`View/Comun/Controls/Cliente/Usuarios.ascx.cs`:

```csharp
protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
{
    if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
    {
        if (((e.Item) is GridDataItem))
        {
            GridDataItem item = e.Item as GridDataItem;
            string id = item.GetDataKeyValue("usu_id").ToString();
            string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id + "&IdCliente=" + IdCliente + "&ReadOnly=" + ReadOnly
                + "&Asociar=" + Asociar + "&TipoPerfil=" + TipoPerfil + "&UsuarioCliente=" + true + "&Perfiles" + Perfiles));

            HyperLink Editar = new HyperLink();
            Editar.ID = "lnkAnular" + id;
            Editar.CssClass = "icono_Editar";
            Editar.NavigateUrl = "javascript:void(0)";
            Editar.Attributes.Add("onclick", "abrirUsuario('" + query + "')");

            GridDataItem DataItem = e.Item as GridDataItem;
            TableCell USU_ID = DataItem["usu_id"];
            USU_ID.Controls.Add(Editar);
        }
    }
}
```

### 4.3 Caso de matriz de checkboxes (ItemCreated + ItemDataBound por columna)

`View/Root/Mantenedores/Accesos/Accesos.aspx.cs` — en `ItemDataBound` se
recorre el mismo `dt.Columns` usado en `ItemCreated` para ubicar cada
`CheckBox` por nombre, marcarlo (`Checked`) según el valor del dato, y
agregarle un atributo `onclick` que llama a una función JS (que a su vez
invoca un `[WebMethod]` vía PageMethods con un string cifrado):

```csharp
protected void rgrPermisos_ItemDataBound(object sender, GridItemEventArgs e)
{
    if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
    {
        if (((e.Item) is GridDataItem))
        {
            GridDataItem item = e.Item as GridDataItem;
            string idPerfil = item.GetDataKeyValue("per_id").ToString();

            foreach (DataColumn column in dt.Columns)
            {
                if (column.ColumnName != "PER_ID" & column.ColumnName != "PERFIL")
                {
                    string uniqueName = column.ColumnName.Replace(' ', '_');
                    string idFuncion = column.ColumnName.Split('_')[1];

                    CheckBox chk = (CheckBox)item[uniqueName].FindControl("chk" + uniqueName);

                    string cadena = Tools.Crypto.Encrypt("idPerfil=" + idPerfil + ";idFuncion=" + idFuncion + ";idMenu=" + idMenu);
                    chk.Attributes.Add("onclick", "GuardaPermisos('" + cadena + "','" + item.ItemIndex + "','" + chk.ID + "')");

                    bool checked1 = item.GetDataKeyValue(column.ColumnName).ToString() == "1"
                                 || item.GetDataKeyValue(column.ColumnName).ToString() == "True";
                    chk.Checked = checked1;
                }
            }
        }
    }
}
```

Reglas comunes a `Grid_ItemDataBound`:
- Filtrar siempre por
  `e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item`
  (filas de datos, no encabezado/footer/paginador). El operador puede ser
  `|` o `||`, ambos se ven en el código existente.
- Validar también `if (((e.Item) is GridDataItem))` antes de castear.
- Obtener el id de la fila con `item.GetDataKeyValue("<columna_clave>").ToString()`
  (la columna debe estar en `DataKeyNames` del `MasterTableView`).
- Buscar el control creado en `ItemCreated` con
  `item["NOMBRE_COLUMNA"].FindControl("idControl")`.
- Para acciones de **descarga/comando** → asignar `CommandName` (sección 4.1).
- Para acciones de **navegación/modal** → construir querystring con
  `Server.UrlEncode(Tools.Crypto.Encrypt("Param1=" + v1 + "&Param2=" + v2 + ...))`
  y asignarlo a un atributo `onclick` de un `HyperLink`/`LinkButton` que llama
  a una función JS (sección 4.2).

---

## 5. Mostrar/ocultar botones del `CommandItem` según permisos/estado

Cuando hay que mostrar u ocultar los botones de la barra de comandos
(`Nuevo`, `Eliminar`, `Asociar`, etc.) según un flag (ej. `Asociar`,
`ReadOnly`), esto **no** se hace en `ItemCreated`/`ItemDataBound`, sino en
`CargarGrid()` (o `Page_PreRender`), después de `Grid.DataBind()`, usando
`Grid.MasterTableView.GetItems(GridItemType.CommandItem)[0]`:

`View/Comun/Controls/Cliente/Usuarios.ascx.cs`:

```csharp
if (ReadOnly)
    Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

Grid.DataBind();

if (!ReadOnly && IdCliente > 0)
{
    LinkButton lnkNuevo = (LinkButton)Grid.MasterTableView.GetItems(GridItemType.CommandItem)[0].FindControl("lnkNuevo");
    LinkButton lnkDeshabilitar = (LinkButton)Grid.MasterTableView.GetItems(GridItemType.CommandItem)[0].FindControl("lnkDeshabilitar");
    LinkButton lnkCargaMasiva = (LinkButton)Grid.MasterTableView.GetItems(GridItemType.CommandItem)[0].FindControl("lnkCargaMasiva");
    LinkButton lnkAsociar = (LinkButton)Grid.MasterTableView.GetItems(GridItemType.CommandItem)[0].FindControl("lnkAsociar");
    LinkButton lnkDesasociar = (LinkButton)Grid.MasterTableView.GetItems(GridItemType.CommandItem)[0].FindControl("lnkDesasociar");

    if (Asociar)
    {
        lnkNuevo.Visible = false;
        lnkDeshabilitar.Visible = false;
        lnkCargaMasiva.Visible = false;
        lnkAsociar.Visible = true;
        lnkDesasociar.Visible = true;
    }
    else
    {
        lnkNuevo.Visible = true;
        lnkDeshabilitar.Visible = true;
        lnkCargaMasiva.Visible = true;
        lnkAsociar.Visible = false;
        lnkDesasociar.Visible = false;
    }
}
```

Reglas:
- `Grid.DataBind()` debe ejecutarse **antes** de llamar a `GetItems(GridItemType.CommandItem)`,
  de lo contrario el `CommandItem` no existe todavía.
- `GetItems(GridItemType.CommandItem)[0]` es la barra de comandos superior
  (la inferior, si existe, sería `[1]`).
- Los IDs (`lnkNuevo`, `lnkAsociar`, etc.) deben coincidir con los `LinkButton`
  declarados dentro del `CommandItemTemplate` en el `.ascx`.

---

## 6. Resumen / checklist al implementar acciones por fila en un RadGrid2

1. En el `.ascx`/`.aspx`: declarar `OnItemCreated="Grid_ItemCreated"` y
   `OnItemDataBound="Grid_ItemDataBound"` en el `RadGrid2`, y la columna
   plantilla destino con `Grid.AddTemplateColumn(...)` en `Page_Load`.
2. `Grid_ItemCreated`:
   - `if (e.Item is GridDataItem)` → crear el control (LinkButton/CheckBox/etc.)
     con `ID` fijo, agregarlo a `item["columna"]`.
   - Si dispara postback: `control.Command += new CommandEventHandler(metodo_Command)`
     y `ScriptManager.GetCurrent(Page).RegisterPostBackControl(control)`.
3. `Grid_ItemDataBound`:
   - Filtrar `GridItemType.AlternatingItem | GridItemType.Item` y `is GridDataItem`.
   - `item.GetDataKeyValue("clave")` para obtener el id de la fila.
   - `item["columna"].FindControl("idControl")` para ubicar el control creado
     en `ItemCreated`.
   - Setear `CommandName` (si se usará `xxx_Command`) o construir el
     querystring cifrado + atributo `onclick` (si se usará navegación JS).
4. `xxx_Command(object sender, CommandEventArgs e)`:
   - Leer `e.CommandName`/`e.CommandArgument`, ejecutar la acción (descarga,
     llamada a Controller, etc.).
5. Si hace falta togglear botones del `CommandItem`: hacerlo en `CargarGrid()`
   después de `Grid.DataBind()`, vía `Grid.MasterTableView.GetItems(GridItemType.CommandItem)[0]`.
6. Guardar el archivo en **UTF-8 con BOM** (ver regla general en
   [`../../CLAUDE.md`](../../CLAUDE.md)).
