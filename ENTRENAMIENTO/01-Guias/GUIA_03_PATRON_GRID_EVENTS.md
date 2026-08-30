# Guía 03 — Eventos de `RadGrid2` (`ItemCreated` / `Command` / `ItemDataBound`)

> Archivo original: [`../00-Patrones-Originales/PATRON_GRID_EVENTS.md`](../00-Patrones-Originales/PATRON_GRID_EVENTS.md)
> Código de ejemplo: [`Usuarios.ascx.cs`](../02-Ejemplo-Usuario/View/Seguridad/Controls/Usuario/Usuarios.ascx.cs)
> Duración estimada: **35 min**

---

## 1. La decisión que hay que anunciar de entrada

> **En este proyecto NO usamos `OnItemCommand` del grid.**

Es la forma "de manual" de Telerik, la que aparece en toda la documentación oficial, y aquí no se usa. En su lugar:

```
ItemCreated  →  crear el control y suscribir su evento Command
ItemDataBound →  darle los datos de la fila (CommandName, Text, onclick)
xxx_Command  →  ejecutar la acción
```

Hay que decirlo explícitamente al equipo porque van a buscar en Google, van a encontrar `ItemCommand` y van a introducir un patrón que no calza con el resto del código.

---

## 2. Los dos escenarios: navegar vs ejecutar

Antes de ver código, esta tabla resuelve el 90% de las dudas:

| Quiero que la fila... | Uso | Hay postback |
|---|---|---|
| **Abra otra página / modal** (Editar, Ver) | `HyperLink` creado en `ItemDataBound`, con `onclick` JS | No |
| **Ejecute código en el servidor** (Descargar, Aprobar, Anular) | `LinkButton` creado en `ItemCreated` + evento `Command` | Sí |

El ejemplo `Usuario` usa el **primer** escenario (editar = navegar). Abajo se explica el segundo, que es el que necesita los tres eventos.

---

## 3. Por qué hacen falta DOS eventos y no uno

Esta es la pregunta que siempre aparece: *"¿por qué no creo el botón y le pongo los datos en el mismo lugar?"*

La respuesta está en el ciclo de vida de WebForms:

```
ItemCreated    → se ejecuta SIEMPRE, en cada postback, haya datos o no.
                 Aquí existe la estructura de la fila, pero NO los datos.

ItemDataBound  → se ejecuta SOLO cuando hay DataBind().
                 Aquí ya están los datos de la fila.
```

Y aquí está la clave: **para que un control dinámico dispare su evento después de un postback, tiene que haber sido creado ANTES de que ASP.NET procese el postback.**

`ItemDataBound` corre demasiado tarde. Si creas el `LinkButton` ahí, el botón se ve en pantalla pero **al hacer click no pasa nada** — el evento se pierde porque el control no existía cuando ASP.NET buscó quién había disparado el postback.

Por eso:

- **`ItemCreated`** → crear el control (siempre existe, siempre se recrea).
- **`ItemDataBound`** → darle los datos (`CommandName` con el id de la fila).

Dos eventos, dos responsabilidades. No es burocracia, es cómo funciona WebForms.

---

## 4. `ItemCreated` — crear la estructura

```csharp
protected void Grid_ItemCreated(object sender, GridItemEventArgs e)
{
    if (e.Item is GridDataItem)
    {
        GridDataItem item = (e.Item as GridDataItem);

        LinkButton lnkDescarga = new LinkButton();
        lnkDescarga.ID = "lnkDescarga";                  // ID FIJO, igual en todas las filas
        lnkDescarga.Text = "&nbsp";
        lnkDescarga.CssClass = "icono_Descargar";
        lnkDescarga.ToolTip = "Descargar Archivo";
        lnkDescarga.Command += new CommandEventHandler(lnkDescarga_Command);

        item["documentoFisico"].Controls.Add(lnkDescarga);

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkDescarga);
    }
}
```

Cuatro detalles que hay que subrayar:

1. **El `ID` es fijo**, el mismo `"lnkDescarga"` en todas las filas. No es un error. Como cada fila es un contenedor distinto, no hay colisión, y en `ItemDataBound` lo encuentras con `item["columna"].FindControl("lnkDescarga")`.
2. **La suscripción `Command +=` va AQUÍ**, no en `ItemDataBound`. Si la haces en los dos lados, el handler se ejecuta **dos veces** por click. (Hay un archivo en FacilityGes con este bug: `OrdenesTrabajoDetalle.ascx.cs`. No lo repliquen.)
3. **`RegisterPostBackControl`** es obligatorio dentro de un `UpdatePanel`. Sin él, el click no llega al servidor.
4. **`item["documentoFisico"]`** — esa columna tiene que existir. Se crea antes con `Grid.AddTemplateColumn("documentoFisico", ...)` en `Page_Load`. Si no existe, excepción.

---

## 5. `ItemDataBound` — poner los datos

```csharp
protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
{
    if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
    {
        if (e.Item is GridDataItem)
        {
            GridDataItem item = e.Item as GridDataItem;
            string id = item.GetDataKeyValue("arc_archivo").ToString();

            LinkButton lnkDescarga = (LinkButton)item["documentoFisico"].FindControl("lnkDescarga");
            lnkDescarga.CommandName = id;
        }
    }
}
```

El truco central: **el id de la fila se guarda en `CommandName`**.

Es un uso poco ortodoxo de la propiedad (`CommandName` suele llevar el *nombre* de la acción), pero es la convención del proyecto y hay que respetarla porque está en todos lados. Si te hace falta un segundo dato, `CommandArgument` está libre.

Sobre el `|` en la condición: es un OR **binario**, no lógico. En este caso funciona igual que `||`. Aparecen los dos en el código existente. No lo cambies solo por estilo, pero si escribes código nuevo usa `||`.

---

## 6. El handler `Command`

```csharp
protected void lnkDescarga_Command(object sender, CommandEventArgs e)
{
    Archivo item = new Archivo();
    item.arc_archivo = int.Parse(e.CommandName.ToString());   // el id que guardamos
    item = controller.GetBinario(item);

    HttpContext.Current.Response.Clear();
    HttpContext.Current.Response.Charset = "";
    HttpContext.Current.Response.AddHeader("content-disposition",
        "attachment; filename=" + item.arc_nombre_archivo);
    HttpContext.Current.Response.BinaryWrite(item.abi_archivo);
    HttpContext.Current.Response.End();
}
```

Firma siempre `(object sender, CommandEventArgs e)`. Lees `e.CommandName`, conviertes, llamas al Controller, actúas.

---

## 7. El otro camino: navegar con `HyperLink`

Es el que usa nuestro ejemplo `Usuario`. Solo necesita **`ItemDataBound`**, porque un `HyperLink` no dispara postback y por lo tanto no necesita existir antes:

```csharp
string id = item.GetDataKeyValue("usu_id").ToString();
string query = Server.UrlEncode(
    Tools.Crypto.Encrypt("IdUsuario=" + id + "&ReadOnly=" + ReadOnly));

HyperLink Editar = new HyperLink();
Editar.ID = "lnkEditar" + id;              // aquí sí lleva el id: no hay FindControl después
Editar.CssClass = "icono_Editar";
Editar.NavigateUrl = "javascript:void(0)";
Editar.Attributes.Add("onclick", "abrirUsuario('" + query + "')");

item["usu_id"].Controls.Add(Editar);
```

Diferencia de detalle con el caso anterior: aquí el `ID` **sí** lleva el id concatenado, porque nunca vas a buscar este control con `FindControl`. En el `LinkButton` el ID era fijo justamente porque sí lo buscas.

---

## 8. Mostrar/ocultar botones de la barra de comandos

No va en `ItemCreated` ni en `ItemDataBound`. Va en `CargarGrid()`, **después** de `Grid.DataBind()`:

```csharp
Grid.DataBind();   // ← imprescindible antes

if (!ReadOnly && IdCliente > 0)
{
    LinkButton lnkNuevo = (LinkButton)Grid.MasterTableView
        .GetItems(GridItemType.CommandItem)[0]
        .FindControl("lnkNuevo");

    lnkNuevo.Visible = !Asociar;
}
```

**El `DataBind()` tiene que ir antes.** Antes de él, el `CommandItem` no existe todavía y `GetItems(...)[0]` lanza `IndexOutOfRange`.

`[0]` es la barra superior. Si además hubiera barra inferior, sería `[1]`.

---

## 9. Checklist para implementar una acción por fila

1. En el markup: declarar `OnItemCreated` y `OnItemDataBound` en el `RadGrid2`, y la columna destino con `Grid.AddTemplateColumn(...)` en `Page_Load` (dentro de `!IsPostBack`).
2. Verificar que la columna clave esté en `DataKeyNames`.
3. `Grid_ItemCreated`: crear el control con **ID fijo**, suscribir `Command +=`, `RegisterPostBackControl`.
4. `Grid_ItemDataBound`: filtrar tipo de fila, `GetDataKeyValue`, `FindControl`, asignar `CommandName`.
5. `xxx_Command`: leer `e.CommandName`, llamar al Controller, actuar.
6. Guardar en **UTF-8 con BOM**.

---

## 10. Diagnóstico rápido

| Síntoma | Causa | Solución |
|---|---|---|
| El botón se ve pero el click no hace nada | Se creó en `ItemDataBound` | Crearlo en `ItemCreated` |
| El handler se ejecuta dos veces | `Command +=` suscrito en los dos eventos | Suscribir solo en `ItemCreated` |
| `NullReferenceException` en `FindControl` | El ID no coincide, o la columna no existe | Revisar ID fijo y `AddTemplateColumn` |
| `GetDataKeyValue` falla | Columna ausente en `DataKeyNames` | Agregarla al `MasterTableView` |
| `IndexOutOfRange` en `GetItems(CommandItem)` | Se llamó antes de `DataBind()` | Mover después del `DataBind()` |
| El click no llega al servidor | Falta `RegisterPostBackControl` | Agregarlo en `ItemCreated` |
| El código corre sobre el encabezado y explota | Falta el filtro de `ItemType` | Filtrar `Item`/`AlternatingItem` |
