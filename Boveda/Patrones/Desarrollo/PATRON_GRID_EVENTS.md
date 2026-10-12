# Patrón de eventos de `RadGrid2` — ItemCreated / Command / ItemDataBound

Cómo se manejan en el code-behind los eventos del `RadGrid2` para crear
controles dinámicos por fila, asociarles una acción y enlazarlos a los datos de
cada fila.

> **Importante**: en estos proyectos **no se usa** el evento de grilla
> `OnItemCommand` / `GridCommandEventArgs`. El "comando" de un botón dentro de
> la grilla se implementa con el patrón **`ItemCreated` + `ItemDataBound` +
> evento `Command` propio del control** (LinkButton, etc.).

---

## 1. Declaración en el `.ascx` / `.aspx`

```aspx
<rad:RadGrid2 runat="server" ID="Grid"
    OnItemCreated="Grid_ItemCreated"
    OnItemDataBound="Grid_ItemDataBound">
    <MasterTableView CommandItemDisplay="None" DataKeyNames="<pfx>_id">
    </MasterTableView>
</rad:RadGrid2>
```

- `DataKeyNames` debe incluir las columnas que después se leen con
  `item.GetDataKeyValue(...)`.
- La columna donde se inserta el control dinámico debe existir: crearla antes
  con `Grid.AddTemplateColumn(...)` en `Page_Load`/`Page_PreRender`
  (`!IsPostBack`) — ver [`PATRON_CONTROLES.md`](PATRON_CONTROLES.md) §1.2.

---

## 2. `Grid_ItemCreated` — crear los controles dinámicos

Se ejecuta en cada postback/databind, por cada ítem de la grilla. Sirve para
**crear** controles que no vienen declarados en el markup (LinkButtons de
acción, CheckBoxes, `RadNumericBox2`...) y agregarlos a la celda de la columna.

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
        lnkDescarga.ToolTip = "Descargar Archivo";
        lnkDescarga.Command += new CommandEventHandler(lnkDescarga_Command);

        item["documentoFisico"].Controls.Add(lnkDescarga);

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkDescarga);
    }
}
```

Reglas:

- Validar siempre `if (e.Item is GridDataItem)`. Si además hay que crear
  controles en el encabezado, validar `if (e.Item is GridHeaderItem)` en un
  bloque aparte.
- El `ID` del control es **fijo** (el mismo en todas las filas, ej.
  `"lnkDescarga"`): después se ubica en `ItemDataBound` con
  `item["columna"].FindControl("lnkDescarga")`.
- Si el control dispara postback (`LinkButton`/`Button` con `Command`):
  suscribir el handler **aquí** con `+= new CommandEventHandler(...)` y
  registrarlo con `ScriptManager.GetCurrent(Page).RegisterPostBackControl(ctrl)`
  para que funcione dentro del `UpdatePanel`.
- `item["NOMBRE_COLUMNA"]` es la `TableCell` de esa columna: debe existir
  previamente (`AddTemplateColumn`/`AddColumn`).
- Para crear un control por **cada columna de un DataTable** (matrices de
  permisos/checkboxes), iterar `dt.Columns` dentro de `Grid_ItemCreated`.

---

## 3. Patrón "GridCommand" — evento `Command` + handler dedicado

En vez de `OnItemCommand` del grid, cada control creado en `ItemCreated`
dispara su propio evento `Command`, atendido por un método dedicado
`xxx_Command(object sender, CommandEventArgs e)`. El dato necesario para la
acción (normalmente el id de la fila) se asigna como `CommandName` en
`ItemDataBound` (§4).

```csharp
protected void lnkDescarga_Command(object sender, CommandEventArgs e)
{
    Archivo item = new Archivo();
    item.<pfx>_archivo = int.Parse(e.CommandName.ToString());
    item = controller.GetBinario(item);

    HttpContext.Current.Response.Clear();
    HttpContext.Current.Response.Charset = "";
    HttpContext.Current.Response.AddHeader("content-disposition", "attachment; filename=" + item.<pfx>_nombre_archivo + "");
    HttpContext.Current.Response.BinaryWrite(item.<pfx>_archivo_binario);
    HttpContext.Current.Response.End();
}
```

Reglas:

- Firma siempre `(object sender, CommandEventArgs e)`.
- `e.CommandName` trae el valor asignado en `ItemDataBound` (normalmente el id
  como string); convertir según el tipo.
- `e.CommandArgument` para un segundo dato (ej. la extensión del archivo).
- La suscripción `control.Command += new CommandEventHandler(metodo)` se hace
  **una sola vez**, en `ItemCreated`. Suscribirlo también en `ItemDataBound`
  duplica la ejecución del handler — hay archivos heredados con ese bug: **no
  replicarlo**.
- Para acciones que **navegan** (abrir un formulario), no se usa `Command`:
  se usa un `HyperLink` con `NavigateUrl="javascript:void(0)"` y un atributo
  `onclick` que llama a la función JS de apertura con el querystring cifrado
  (§4.2).

---

## 4. `Grid_ItemDataBound` — enlazar los datos de la fila

Se ejecuta por cada fila ya con datos. Aquí se busca el control creado en
`ItemCreated` y se le asignan los valores que dependen de la fila
(`CommandName`, `Text`, `CssClass`, `onclick`, `Visible`...).

### 4.1 Caso simple — asignar `CommandName`

```csharp
protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
{
    if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
    {
        if (((e.Item) is GridDataItem))
        {
            GridDataItem item = e.Item as GridDataItem;
            string id = item.GetDataKeyValue("<pfx>_id").ToString();

            LinkButton lnkDescarga = (LinkButton)item["documentoFisico"].FindControl("lnkDescarga");
            lnkDescarga.CommandName = id;
        }
    }
}
```

### 4.2 Caso con querystring cifrado + `HyperLink`

```csharp
protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
{
    if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
    {
        if (((e.Item) is GridDataItem))
        {
            GridDataItem item = e.Item as GridDataItem;
            string id = item.GetDataKeyValue("<pfx>_id").ToString();

            string query = Server.UrlEncode(Tools.Crypto.Encrypt(
                "Id<Entidad>=" + id
                + "&Id<Padre>=" + Id<Padre>
                + "&ReadOnly=" + ReadOnly));

            HyperLink Editar = new HyperLink();
            Editar.ID = "lnkEditar" + id;
            Editar.CssClass = "icono_Editar";
            Editar.NavigateUrl = "javascript:void(0)";
            Editar.Attributes.Add("onclick", "abrir<Entidad>('" + query + "')");

            TableCell celda = item["<pfx>_id"];
            celda.Controls.Add(Editar);
        }
    }
}
```

### 4.3 Caso de matriz de checkboxes (por columna del DataTable)

Cuando la grilla es una matriz (perfiles × funciones), se recorre el mismo
`dt.Columns` que en `ItemCreated` para ubicar cada `CheckBox`, marcarlo según
el dato y agregarle el `onclick` que llama al endpoint AJAX:

```csharp
protected void rgrPermisos_ItemDataBound(object sender, GridItemEventArgs e)
{
    if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
    {
        if (((e.Item) is GridDataItem))
        {
            GridDataItem item = e.Item as GridDataItem;
            string idPerfil = item.GetDataKeyValue("<pfx>_id").ToString();

            foreach (DataColumn column in dt.Columns)
            {
                if (column.ColumnName != "<PFX>_ID" & column.ColumnName != "PERFIL")
                {
                    string uniqueName = column.ColumnName.Replace(' ', '_');
                    string idFuncion = column.ColumnName.Split('_')[1];

                    CheckBox chk = (CheckBox)item[uniqueName].FindControl("chk" + uniqueName);

                    string cadena = Tools.Crypto.Encrypt("idPerfil=" + idPerfil + ";idFuncion=" + idFuncion);
                    chk.Attributes.Add("onclick", "GuardaPermisos('" + cadena + "','" + item.ItemIndex + "','" + chk.ID + "')");

                    bool marcado = item.GetDataKeyValue(column.ColumnName).ToString() == "1"
                                || item.GetDataKeyValue(column.ColumnName).ToString() == "True";
                    chk.Checked = marcado;
                }
            }
        }
    }
}
```

### 4.4 Reglas comunes de `ItemDataBound`

- Filtrar siempre por
  `e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item`
  (solo filas de datos, no encabezado/footer/paginador). En el código existente
  se ve tanto `|` como `||`.
- Validar `if (((e.Item) is GridDataItem))` antes de castear.
- Id de la fila: `item.GetDataKeyValue("<columna_clave>").ToString()` — la
  columna debe estar en `DataKeyNames`.
- Control creado en `ItemCreated`:
  `item["NOMBRE_COLUMNA"].FindControl("idControl")`.
- Valores que no son columnas clave: `DataBinder.Eval(item.DataItem, "campo")`.
- Acción de **descarga/comando** → asignar `CommandName` (§4.1).
- Acción de **navegación/modal** → querystring cifrado + `onclick` (§4.2).

---

## 5. Botones del `CommandItem` según permisos/estado

Mostrar u ocultar los botones de la barra de comandos **no** se hace en
`ItemCreated`/`ItemDataBound`, sino en `CargarGrid()` (o `Page_PreRender`),
**después** de `Grid.DataBind()`:

```csharp
if (ReadOnly)
    Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

Grid.DataBind();

if (!ReadOnly && Id<Padre> > 0)
{
    LinkButton lnkNuevo    = (LinkButton)Grid.MasterTableView.GetItems(GridItemType.CommandItem)[0].FindControl("lnkNuevo");
    LinkButton lnkAsociar  = (LinkButton)Grid.MasterTableView.GetItems(GridItemType.CommandItem)[0].FindControl("lnkAsociar");

    lnkNuevo.Visible   = !Asociar;
    lnkAsociar.Visible = Asociar;
}
```

- `Grid.DataBind()` debe ejecutarse **antes** de `GetItems(GridItemType.CommandItem)`:
  antes de eso, el `CommandItem` todavía no existe y revienta con index out of range.
- `GetItems(GridItemType.CommandItem)[0]` es la barra superior; `[1]` la inferior.
- Los IDs deben coincidir con los `LinkButton` del `CommandItemTemplate`.

---

## 6. Checklist — acción por fila en un `RadGrid2`

1. **Markup**: `OnItemCreated="Grid_ItemCreated"` y
   `OnItemDataBound="Grid_ItemDataBound"` en el `RadGrid2`; la columna destino
   creada con `Grid.AddTemplateColumn(...)` en `!IsPostBack`; la columna clave
   en `DataKeyNames`.
2. **`Grid_ItemCreated`**: `if (e.Item is GridDataItem)` → crear el control con
   `ID` fijo, agregarlo a `item["columna"]`; si dispara postback, suscribir
   `Command` + `RegisterPostBackControl`.
3. **`Grid_ItemDataBound`**: filtrar tipo de ítem, obtener el id con
   `GetDataKeyValue`, ubicar el control con `FindControl`, setear `CommandName`
   (comando) o el `onclick` con querystring cifrado (navegación), y `Visible`
   si la acción es condicional.
4. **`xxx_Command`**: leer `e.CommandName`/`e.CommandArgument` y ejecutar la
   acción (descarga, llamada al Controller, `ClientExecute`...).
5. **Botones del `CommandItem`**: togglearlos en `CargarGrid()` después de
   `Grid.DataBind()`.
6. Guardar el archivo en **UTF-8 con BOM**
   (ver [`../CONVENCIONES.md`](../CONVENCIONES.md) §2).
