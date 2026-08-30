# Patrón de capas — WebForms + "MVC" propio

Estructura de Model, Controller, UserControls y páginas. Cualquier archivo
nuevo debe quedar indistinguible de los que ya existen en el proyecto.

> El proyecto **NO** es ASP.NET MVC. Es **WebForms (Web Site Project)** con una
> capa de acceso a datos propia organizada en carpetas `Controller` / `Model`
> — un "MVC manual", separado de las páginas y controles visuales.

---

## 1. Ubicación de archivos

```
<RaizWeb>/
├── App_Code/
│   └── MVC/
│       ├── <Proyecto>/
│       │   ├── Controller/   <Entidad>Controller.cs
│       │   └── Model/        <Entidad>.cs
│       └── SitioBase/        Controller/Model transversales (Token, Sesión, Menús, Usuario...)
└── View/
    └── <Modulo>/                        (Comercial, Comun, Clientes, Sistema, Root...)
        └── <SubModulo>/
            ├── <Entidad>s.aspx(.cs)     Página LISTADO
            ├── <Entidad>.aspx(.cs)      Página FORMULARIO
            └── Controls/
                └── <Entidad>/
                    ├── <Entidad>s.ascx(.cs)   UserControl LISTADO (grid)
                    ├── <Entidad>.ascx(.cs)    UserControl FORMULARIO (tabs)
                    └── <Tab>.ascx(.cs)        UserControl de cada tab
```

Reparto de responsabilidades:

| Archivo | Responsabilidad |
|---|---|
| `Model/<Entidad>.cs` | Datos (POCO). Sin lógica |
| `Controller/<Entidad>Controller.cs` | Llamar a los SPs y mapear a Model. Sin lógica de UI |
| `<Entidad>s.ascx` | Grilla, filtros, acciones masivas |
| `<Entidad>.ascx` | Contenedor de tabs del formulario |
| `<Tab>.ascx` | Campos + guardar de un tab |
| `<Entidad>s.aspx` / `<Entidad>.aspx` | Seguridad del menú + pasar propiedades al UserControl |

---

## 2. Model — `App_Code/MVC/<Proyecto>/Model/<Entidad>.cs`

- Namespace `<Proyecto>.Model`.
- Clase `[Serializable]`, propiedades auto-implementadas.
- **Nombre de propiedad = nombre de columna** (minúsculas con prefijo).
- Además de las columnas reales, se agregan **campos de filtro** que solo usa
  el Controller para armar la llamada al SP (`filtro`, `filtro_habilitado`,
  `filtro_<algo>`).
- Si el `SEL_` devuelve columnas de tablas unidas (`<PADRE>_NOMBRE`), también
  se declaran como propiedades.
- Sin lógica, sin validaciones, sin acceso a datos.

```csharp
using System;

namespace <Proyecto>.Model
{
    [Serializable]
    public class <Entidad>
    {
        // Columnas de la tabla
        public int <pfx>_id { get; set; }
        public int <pfx>_<fk_padre> { get; set; }
        public string <pfx>_nombre { get; set; }
        public string <pfx>_descripcion { get; set; }
        public int <pfx>_usuario_creacion { get; set; }
        public DateTime? <pfx>_fecha_creacion { get; set; }
        public int <pfx>_usuario_actualizacion { get; set; }
        public DateTime? <pfx>_fecha_actualizacion { get; set; }
        public bool <pfx>_habilitado { get; set; }

        // Columnas traídas por JOIN en el SEL_
        public string <padre>_nombre { get; set; }

        // Filtros que usa el Controller para construir la consulta
        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
    }
}
```

- Fechas anulables → `DateTime?`; el mapeo desde el `DataReader` debe
  comprobar `DBNull` (§3.4).

---

## 3. Controller — `App_Code/MVC/<Proyecto>/Controller/<Entidad>Controller.cs`

- Namespace `<Proyecto>.Controller`.
- Usings típicos: `System`, `System.Collections.Generic`, `System.Data`,
  `System.Data.SqlClient`, `System.Linq`, `System.Web`, `<Proyecto>.Model`,
  `SitioBase`.
- **Toda** operación empieza con `if (Token.TokenSeguridad())`.
- Acceso a datos vía `Conexion.GetCommand("<SP>")` / `Conexion.GetDataReader(cmd)`.
  **Nunca** SQL embebido.
- Métodos estándar por entidad:

| Método | SP | Devuelve |
|---|---|---|
| `List<<Entidad>> Get<Entidad>s(<Entidad> filtro = null)` | `SEL_<TABLA>` | Lista (o `null` si hubo error) |
| `<Entidad> Get<Entidad>(<Entidad> entidad)` | `SEL_<TABLA>` con `@ID` | Un registro |
| `Respuesta Insert<Entidad>(<Entidad> entidad)` | `INS_<TABLA>` | `Respuesta` con el id en `codigo` |
| `Respuesta Update<Entidad>(<Entidad> entidad)` | `UPD_<TABLA>` | `Respuesta` |
| `Respuesta Delete<Entidad>(<Entidad> entidad)` | `DEL_<TABLA>` | `Respuesta` |

### 3.1 Listado

```csharp
public List<<Entidad>> Get<Entidad>s(<Entidad> entidad = null)
{
    List<<Entidad>> lista = new List<<Entidad>>();

    if (Token.TokenSeguridad())
    {
        SqlCommand cmd = new SqlCommand();
        try
        {
            cmd.CommandText = "SEL_<TABLA>";

            if (entidad != null)
            {
                if (entidad.<pfx>_id > 0)
                    cmd.Parameters.AddWithValue("@ID", entidad.<pfx>_id);

                if (entidad.<pfx>_<fk_padre> > 0)
                    cmd.Parameters.AddWithValue("@<FK_PADRE>", entidad.<pfx>_<fk_padre>);

                if (!string.IsNullOrEmpty(entidad.filtro))
                    cmd.Parameters.AddWithValue("@FILTRO", entidad.filtro);

                if (entidad.filtro_habilitado != null)
                    cmd.Parameters.AddWithValue("@HABILITADO", entidad.filtro_habilitado);
            }

            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read())
                {
                    <Entidad> item = new <Entidad>();
                    item.<pfx>_id = int.Parse(dr["<PFX>_ID"].ToString());
                    item.<pfx>_nombre = dr["<PFX>_NOMBRE"].ToString();
                    item.<pfx>_descripcion = dr["<PFX>_DESCRIPCION"].ToString();
                    item.<padre>_nombre = dr["<PADRE>_NOMBRE"].ToString();
                    item.<pfx>_habilitado = bool.Parse(dr["<PFX>_HABILITADO"].ToString());

                    if (dr["<PFX>_FECHA_CREACION"] != DBNull.Value)
                        item.<pfx>_fecha_creacion = DateTime.Parse(dr["<PFX>_FECHA_CREACION"].ToString());

                    lista.Add(item);
                }
            }

            cmd.Connection.Close();
            cmd.Dispose();
        }
        catch (Exception ex)
        {
            cmd.Connection.Close();
            cmd.Dispose();
            lista = null;
        }
    }

    return lista;
}
```

- Los parámetros se agregan **solo si el filtro viene informado**: el SP los
  tiene todos `= NULL`.
- El nombre del parámetro (`@ID`, `@FILTRO`) debe coincidir exactamente con el
  del SP.

### 3.2 Registro único

```csharp
public <Entidad> Get<Entidad>(<Entidad> entidad)
{
    List<<Entidad>> lista = Get<Entidad>s(new <Entidad> { <pfx>_id = entidad.<pfx>_id });
    return (lista != null && lista.Count > 0) ? lista[0] : new <Entidad>();
}
```

Reutilizar el listado con `@ID` en vez de duplicar el mapeo.

### 3.3 Insert / Update / Delete

```csharp
public Respuesta Insert<Entidad>(<Entidad> entidad)
{
    Respuesta respuesta = new Respuesta();

    if (Token.TokenSeguridad())
    {
        SqlCommand cmdExecute = null;
        try
        {
            int id = 0;
            cmdExecute = Conexion.GetCommand("INS_<TABLA>");
            cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
            cmdExecute.Parameters.AddWithValue("@<FK_PADRE>", entidad.<pfx>_<fk_padre>);
            cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.<pfx>_nombre);
            cmdExecute.Parameters.AddWithValue("@DESCRIPCION", entidad.<pfx>_descripcion);
            cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
            cmdExecute.ExecuteNonQuery();
            cmdExecute.Connection.Close();

            id = (int)cmdExecute.Parameters["@ID"].Value;

            respuesta.codigo = id;
            respuesta.detalle = "<Entidad> creado con éxito.";
            respuesta.error = false;
        }
        catch (Exception ex)
        {
            cmdExecute.Connection.Close();
            respuesta.codigo = -1;
            respuesta.detalle = ex.Message;
            respuesta.error = true;
        }
    }

    return respuesta;
}

public Respuesta Update<Entidad>(<Entidad> entidad)
{
    Respuesta respuesta = new Respuesta();

    if (Token.TokenSeguridad())
    {
        SqlCommand cmdExecute = null;
        try
        {
            cmdExecute = Conexion.GetCommand("UPD_<TABLA>");
            cmdExecute.Parameters.AddWithValue("@ID", entidad.<pfx>_id);
            cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.<pfx>_nombre);
            cmdExecute.Parameters.AddWithValue("@DESCRIPCION", entidad.<pfx>_descripcion);
            cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.<pfx>_habilitado);
            cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
            cmdExecute.ExecuteNonQuery();
            cmdExecute.Connection.Close();

            respuesta.codigo = entidad.<pfx>_id;
            respuesta.detalle = "<Entidad> actualizado con éxito.";
            respuesta.error = false;
        }
        catch (Exception ex)
        {
            cmdExecute.Connection.Close();
            respuesta.codigo = -1;
            respuesta.detalle = ex.Message;
            respuesta.error = true;
        }
    }

    return respuesta;
}
```

`Delete<Entidad>` es igual con `DEL_<TABLA>`, solo `@ID`, y detalle
`"<Entidad> eliminado con éxito."`.

### 3.4 Reglas del Controller

- El usuario que audita **siempre** sale de `Session.UsuarioId()`, nunca de un
  parámetro del Model.
- Cerrar y liberar conexión/comando en **ambos** caminos (`try` y `catch`).
- En `catch`: `Get*` devuelve `null` (o lista vacía), los `Insert/Update/Delete`
  devuelven `respuesta.error = true` con `respuesta.detalle = ex.Message`.
- Mensajes de éxito en español terminados en `"con éxito."`.
- Columnas anulables: comprobar `!= DBNull.Value` antes de parsear.
- Si un SP devuelve **varios result sets**, recorrerlos con `dr.NextResult()`.
- Sin lógica de UI en el Controller (nada de `ClientAlert`, `ViewState`, etc.).

---

## 4. UserControl de LISTADO — `<Entidad>s.ascx(.cs)`

### 4.1 `.ascx`

```aspx
<%@ Control Language="C#" AutoEventWireup="true" CodeFile="<Entidad>s.ascx.cs" Inherits="View_<Ruta>_<Entidad>s" %>
<%@ Register Src="~/View/Comun/Controls/FiltroAvanzado.ascx" TagPrefix="wuc" TagName="Filtro" %>

<script type="text/javascript">
    function abrir<Entidad>(query) {
        window.location = ('<%=ResolveUrl(URLNuevo<Entidad>) %>?query=' + query);
    }
</script>

<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>
        <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgr<Entidad>_ItemDataBound">
            <MasterTableView CommandItemDisplay="Top" DataKeyNames="<pfx>_id">
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
        </rad:RadGrid2>
    </ContentTemplate>
</asp:UpdatePanel>
```

### 4.2 `.ascx.cs`

```csharp
public partial class View_<Ruta>_<Entidad>s : System.Web.UI.UserControl
{
    #region Propiedades

    public bool ReadOnly
    {
        get { return ViewState["ReadOnly"] != null ? (bool)ViewState["ReadOnly"] : false; }
        set { ViewState["ReadOnly"] = value; }
    }

    public string URLNuevo<Entidad>
    {
        get { return ViewState["URLNuevo<Entidad>"] != null ? (string)ViewState["URLNuevo<Entidad>"] : ""; }
        set { ViewState["URLNuevo<Entidad>"] = value; }
    }

    public int Ver_Todo
    {
        get { return ViewState["Ver_Todo"] != null ? (int)ViewState["Ver_Todo"] : 0; }
        set { ViewState["Ver_Todo"] = value; }
    }

    #endregion

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("<PFX>_ID", "", Width: "2%");
            Grid.AddColumn("<PFX>_NOMBRE", "NOMBRE", Width: "60%");
            Grid.AddColumn("<PADRE>_NOMBRE", "<PADRE>", Width: "30%");
            Grid.AddCheckboxColumn("<PFX>_HABILITADO", "HABILITADO");
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

        #region SeguridadPagina
        // Restringir el filtro según los permisos del usuario
        // (ver PATRON_SEGURIDAD_MENUS.md)
        #endregion

        filtro.filtro = wucFiltro.Filtro();

        Grid.DataSource = controller.Get<Entidad>s(filtro);
    }
}
```

- Propiedades públicas **siempre vía `ViewState`** (nunca campos privados): el
  UserControl las recibe desde la página y deben sobrevivir al postback.
- Null-check clásico: `ViewState["k"] != null ? (T)ViewState["k"] : default`.
- El link "Editar" por fila se crea en `ItemDataBound` con querystring cifrado
  — ver [`PATRON_GRID_EVENTS.md`](PATRON_GRID_EVENTS.md).
- `lnkEliminar_Click` valida selección, recorre `Grid.SelectedIndexes`, llama
  `Delete<Entidad>` y muestra `Tools.tools.ClientAlert(...)` — ver
  [`PATRON_CONTROLES.md`](PATRON_CONTROLES.md) §1.5.

---

## 5. UserControl de FORMULARIO con tabs — `<Entidad>.ascx(.cs)`

### 5.1 `.ascx`

- Registra un UserControl hijo por tab con
  `<%@ Register Src="..." TagPrefix="wuc" TagName="..." %>`.
- Estructura `rad:RadTabStrip2` (vertical) + `rad:RadMultiPage`, un `RadTab` +
  `RadPageView` por sub-control.
- Botón "Cerrar" (`WebControls:PushButton`) con
  `OnClientClick="closeWindow(); return false;"`.

### 5.2 `.ascx.cs`

- Propiedades `ReadOnly`, `Id<Entidad>` vía `ViewState`.
- `Page_PreRender` delega en los sub-controles: les pasa `ReadOnly` e `Id`.
- No accede a datos: cada tab carga lo suyo.

---

## 6. UserControl de TAB — `<Tab>.ascx(.cs)`

### 6.1 `.ascx`

- Todo dentro de `<asp:UpdatePanel ID="udPanel" UpdateMode="Conditional">`.
- Layout Bootstrap: `div class="row col-lg-12 col-md-12 col-xs-12"` + columnas.
- Controles del proyecto: `WebControls:TextBox2`, `rad:RadComboBox2`,
  `WebControls:PushButton`, más un `asp:CustomValidator` con
  `ClientValidationFunction="validaControl"` y `ValidationGroup="<Entidad>"`
  por campo obligatorio.
- Botón Guardar al final con el mismo `ValidationGroup`.

### 6.2 `.ascx.cs`

```csharp
public void LoadControls(object sender, EventArgs e)   // combos, solo !IsPostBack
protected void Page_PreRender(object sender, EventArgs e)
{
    CargarDatos();
    Bloqueo();
    ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
    udPanel.Update();
}
protected void CargarDatos()      // si Id<Entidad> > 0 trae y setea; si no, limpia
protected void Bloqueo()          // ReadOnly/Enabled/Visible de cada control según ReadOnly
protected void btnGuardar_Click(object sender, EventArgs e)
{
    try
    {
        <Entidad> entidad = new <Entidad>();
        entidad.<pfx>_id = Id<Entidad>;
        entidad.<pfx>_nombre = txtNombre.Text.Trim();
        // ...

        <Entidad>Controller controller = new <Entidad>Controller();
        Respuesta respuesta = (Id<Entidad> > 0)
            ? controller.Update<Entidad>(entidad)
            : controller.Insert<Entidad>(entidad);

        if (!respuesta.error)
        {
            Id<Entidad> = respuesta.codigo;
            Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
        }
        else
        {
            Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
    }
    catch (Exception ex)
    {
        Tools.tools.ClientAlert(ex.ToString(), "error");
    }
}
```

- **Nunca** agregar un `ScriptManager` en el UserControl: el master ya lo tiene.
- Todo el `btnGuardar_Click` dentro de `try/catch`.

---

## 7. Páginas `.aspx`

### 7.1 `.aspx`

```aspx
<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true"
    CodeFile="<Entidad>s.aspx.cs" Inherits="View_<Ruta>_<Entidad>s" %>
<%@ Register Src="~/View/<Modulo>/Controls/<Entidad>/<Entidad>s.ascx" TagPrefix="wuc" TagName="<Entidad>s" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="server" />
<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server" />
<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    <%-- Título de la página --%>
</asp:Content>
<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server" />
<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="server">
    <wuc:<Entidad>s ID="wuc<Entidad>s" runat="server"
        URLNuevo<Entidad>="~/View/<Modulo>/<SubModulo>/<Entidad>.aspx" />
</asp:Content>
```

### 7.2 `.aspx.cs`

```csharp
public partial class View_<Ruta>_<Entidad>s : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina
        MenuPerfil ver = new MenuPerfil();
        ver.mpe_menu = (int)SitioBase.Paginas.menu_<N>.Ver;
        SitioBase.Token.SecurityManagerVer(ver);
        #endregion

        wuc<Entidad>s.Ver_Todo = (int)SitioBase.Paginas.menu_<N>.Ver_Todo;
        wuc<Entidad>s.Crear_Editar = (int)SitioBase.Paginas.menu_<N>.Crear_Editar;
    }

    protected void Page_PreRender(object sender, EventArgs e) { }
}
```

En páginas de **formulario**, además se lee el querystring cifrado:

```csharp
if (Request.QueryString["query"] != null)
{
    string query = Tools.Crypto.Decrypt(Server.UrlDecode(Request.QueryString["query"]));
    NameValueCollection parametros = HttpUtility.ParseQueryString(query);

    wuc<Entidad>.Id<Entidad> = Convert.ToInt32(parametros["Id<Entidad>"] ?? "0");
    wuc<Entidad>.ReadOnly = Convert.ToBoolean(parametros["ReadOnly"] ?? "false");
}
```

---

## 8. Checklist al crear la entidad "`<Entidad>`"

1. `Model/<Entidad>.cs` — columnas + campos `filtro_*`.
2. `Controller/<Entidad>Controller.cs` — `Get<Entidad>s`, `Get<Entidad>`,
   `Insert<Entidad>`, `Update<Entidad>`, `Delete<Entidad>`.
3. `View/<Modulo>/Controls/<Entidad>/<Entidad>s.ascx(.cs)` — grid.
4. `View/<Modulo>/Controls/<Entidad>/<Entidad>.ascx(.cs)` — formulario/tabs.
5. Sub-controles de tabs si aplica.
6. `View/<Modulo>/<SubModulo>/<Entidad>s.aspx(.cs)` — página listado.
7. `View/<Modulo>/<SubModulo>/<Entidad>.aspx(.cs)` — página formulario.
8. Menús + `Paginas.menu_<N>` ([`PATRON_SEGURIDAD_MENUS.md`](PATRON_SEGURIDAD_MENUS.md)).
9. Todos los archivos en **UTF-8 con BOM**.
10. Precompilar con `aspnet_compiler.exe` y verificar `exitcode=0`.
