# Patrón de programación – Intranet FacilityGes (WebForms + "MVC" propio)

Este documento describe el patrón que sigue **Web/Intranet** para que cualquier
archivo nuevo o modificado (Controller, Model, Page `.aspx`, UserControl `.ascx`)
mantenga la misma estructura y estilo que el resto del proyecto.

> El proyecto NO es ASP.NET MVC. Es **Web Forms** con una capa de acceso a datos
> propia organizada en carpetas `Controller` / `Model` (un "MVC" manual, separado
> de las páginas/controles visuales).

---

## 1. Ubicación de archivos

```
Web/Intranet/
├── App_Code/
│   └── MVC/
│       └── Facilityges/
│           ├── Controller/   <NombreEntidad>Controller.cs
│           └── Model/        <NombreEntidad>.cs
│       └── SitioBase/        Controller/Model genéricos (Token, Sesión, Páginas, etc.)
└── View/
    └── <Modulo>/                       (Comercial, Comun, Clientes, Sistema, Root, ...)
        └── <SubModulo>/
            ├── <Pagina>.aspx           Página (usa Master + UserControls)
            ├── <Pagina>.aspx.cs        Code-behind de la página
            └── Controls/
                └── <Entidad>/
                    ├── <Entidad>s.ascx     UserControl LISTADO (grid)
                    ├── <Entidad>s.ascx.cs
                    ├── <Entidad>.ascx      UserControl FORMULARIO/Tabs
                    ├── <Entidad>.ascx.cs
                    └── <SubEntidad>.ascx(.cs)  Tabs internos del formulario
```

Ejemplo real usado como referencia: entidad **Cliente**
- Model: `App_Code/MVC/Facilityges/Model/Cliente.cs`
- Controller: `App_Code/MVC/Facilityges/Controller/ClienteController.cs`
- Listado (grid): `View/Comun/Controls/Cliente/Clientes.ascx(.cs)`
- Formulario con tabs: `View/Comun/Controls/Cliente/Cliente.ascx(.cs)`
- Tab "Identidad": `View/Comun/Controls/Cliente/Identidad.ascx(.cs)`
- Página listado: `View/Comercial/Clientes/Clientes.aspx(.cs)`
- Página formulario: `View/Comercial/Clientes/Cliente.aspx(.cs)`

---

## 2. Model (`App_Code/MVC/Facilityges/Model/<Entidad>.cs`)

- Namespace `Facilityges.Model`.
- Clase `[Serializable]`, propiedades auto-implementadas (`get; set;`).
- Nombre de propiedades = nombre de columna en minúsculas con prefijo de tabla
  (ej. `cli_id`, `cli_nombre`, `cli_pais`).
- Además de los campos "reales" de la entidad, se agregan **campos de filtro**
  usados solo por el Controller para construir la query (`filtro`, `filtro_habilitado`,
  `filtro_pais`, `filtro_paises`, `filtro_usuarios`, `filtro_instalacion`, `tipo_perfil`, ...).
- No tiene lógica, solo datos (POCO).

```csharp
using System;

namespace Facilityges.Model
{
    [Serializable]
    public class Cliente
    {
        public int cli_id { get; set; }
        public string cli_nombre { get; set; }
        public int cli_pais { get; set; }
        // ... resto de columnas

        // filtros usados por el Controller
        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public string filtro_pais { get; set; }
    }
}
```

---

## 3. Controller (`App_Code/MVC/Facilityges/Controller/<Entidad>Controller.cs`)

- Namespace `Facilityges.Controller`.
- Usings típicos: `System`, `System.Collections.Generic`, `System.Data.SqlClient`,
  `System.Linq`, `System.Web`, `Facilityges.Model`, `SitioBase`.
- Toda operación empieza comprobando `Token.TokenSeguridad()`.
- Acceso a datos vía **Stored Procedures** con `Conexion.GetDataReader(cmd)` /
  `Conexion.GetCommand("SP_NAME")`. Nunca SQL embebido (queries directas).
- Convención de nombres de SP: `SEL_<ENTIDAD>`, `INS_<ENTIDAD>`, `UPD_<ENTIDAD>`, `DEL_<ENTIDAD>`.
- Métodos típicos por entidad:
  - `List<Entidad> Get<Entidad>s(Entidad filtro = null)` – usa `SEL_*`, agrega
    parámetros solo `if` el campo de filtro viene informado.
  - `Entidad Get<Entidad>(Entidad entidad)` – trae un único registro por id.
  - `Respuesta Insert<Entidad>(Entidad entidad)` – `INS_*`, parámetro `@ID` de
    salida (`ParameterDirection.Output`), agrega `@USUARIO` con `Session.UsuarioId()`.
  - `Respuesta Update<Entidad>(Entidad entidad)` – `UPD_*`.
  - `Respuesta Delete<Entidad>(Entidad entidad)` – `DEL_*`.
- Manejo de errores: `try/catch` cerrando y disposing la conexión/comando en
  ambos caminos; en `catch` se devuelve `respuesta.error = true` y
  `respuesta.detalle = ex.Message` (o se devuelve `null`/lista vacía en los `Get`).
- Mensajes de éxito en español, terminados en "con éxito." (p.ej.
  `"Cliente creado con éxito."`).

```csharp
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using Facilityges.Model;
using SitioBase;

namespace Facilityges.Controller
{
    public class EntidadController
    {
        public List<Entidad> GetEntidades(Entidad entidad = null)
        {
            List<Entidad> entidades = new List<Entidad>();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_ENTIDAD";
                    if (entidad.ent_id > 0) cmd.Parameters.AddWithValue("@ID", entidad.ent_id);
                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Entidad item = new Entidad();
                            item.ent_id = int.Parse(dr["ENT_ID"].ToString());
                            entidades.Add(item);
                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                    entidades = null;
                }
            }
            return entidades;
        }

        public Respuesta InsertEntidad(Entidad entidad)
        {
            Respuesta respuesta = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    int id = 0;
                    cmdExecute = Conexion.GetCommand("INS_ENTIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;
                    respuesta.codigo = id;
                    respuesta.detalle = "Entidad creada con éxito.";
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
    }
}
```

---

## 4. UserControl de LISTADO / Grid (`<Entidad>s.ascx` + `.ascx.cs`)

### `.ascx`
- Directiva `<%@ Control Language="C#" AutoEventWireup="true" CodeFile="<Entidad>s.ascx.cs" Inherits="View_<Ruta>_<Entidad>s" %>`.
- Registra `~/View/Comun/Controls/FiltroAvanzado.ascx` como `wuc:Filtro` para filtros.
- Script JS para abrir el formulario (`abrirXxx(query)`) navegando a
  `<%=ResolveUrl(URLNuevoXxx) %>?query=' + query`.
- `rad:RadGrid2` dentro de `asp:UpdatePanel` (`UpdateMode="Conditional"`).
- `MasterTableView` con `CommandItemDisplay="Top"`, `DataKeyNames="<pk>"`.
- `CommandItemTemplate` con botones `Nuevo` (`icono_guardar`) y `Eliminar`
  (`icono_eliminar`, con `ConfirSweetAlert`).

### `.ascx.cs`
- `partial class View_<Ruta>_<Entidad>s : System.Web.UI.UserControl`.
- Propiedades públicas vía `ViewState` (no campos privados): `ReadOnly`,
  `URLNuevo<Entidad>`, y propiedades de seguridad (`VerTodoPaises`, `Ver_Todo`,
  `Crear_Editar`, `Tipo_Perfil`, etc.) que la página padre setea.
- `Page_PreRender`:
  - Si `!IsPostBack`, agrega columnas con `Grid.AddSelectColumn()`,
    `Grid.AddColumn(...)`, `Grid.AddCheckboxColumn(...)`.
  - Aplica `ReadOnly` ocultando `CommandItemDisplay`.
  - Llama `CargarGrid()`, `Grid.DataBind()`, `udPanel.Update()`,
    `Tools.tools.RegisterPostBackScript(Grid)`.
- `CargarGrid()`:
  - Bloque `#region SeguridadPagina` que usa `MenuFuncion` + `SitioBase.Token.SecurityManager(...)`
    para restringir filtros según permisos del usuario (países, "ver todo", etc.).
  - Toma valores del `wucFiltro` (`wucFiltro.Filtro()`, controles dentro de `FindControl`).
  - Llama al Controller: `Grid.DataSource = entidadController.GetEntidades(entidad);`.
- `rgr<Entidad>_ItemDataBound`: agrega un `HyperLink` "Editar" por fila que llama
  a `abrirXxx('<query cifrada>')`, donde `query` se genera con
  `Tools.Crypto.Encrypt("Id<Entidad>=" + id + "&ReadOnly=" + ReadOnly)`.
- `lnk<Eliminar>_Click`: valida selección, recorre `Grid.SelectedIndexes`,
  obtiene la PK con `Grid.MasterTableView.DataKeyValues[...]`, llama
  `Delete<Entidad>` por cada fila y muestra `Tools.tools.ClientAlert(...)`.

---

## 5. UserControl de FORMULARIO con TABS (`<Entidad>.ascx` + `.ascx.cs`)

### `.ascx`
- Registra los UserControls hijos (uno por tab) con `<%@ Register Src="..." TagPrefix="wuc" TagName="..." %>`.
- Estructura: `RadTabStrip2` (orientación vertical) + `RadMultiPage`, un
  `RadTab`/`RadPageView` por sub-control.
- Botón "Cerrar" (`WebControls:PushButton`) que ejecuta JS `closeWindow()`
  navegando a `<%=ResolveUrl(URLVolverXxx) %>`.

### `.ascx.cs`
- Propiedades públicas vía `ViewState`: `ReadOnly`, `Id<Entidad>`, etc.
- `Page_PreRender`: típicamente delega en los sub-controles (les pasa `ReadOnly`/`Id`).

---

## 6. UserControl de TAB / sub-formulario (ej. `Identidad.ascx` + `.ascx.cs`)

### `.ascx`
- Envuelto en `<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">`.
- Layout con `div class="row col-lg-12 col-md-12 col-xs-12"` + columnas Bootstrap
  (`col-lg-2`/`col-lg-10`, etc.), siguiendo el grid de 12 columnas.
- Controles propios del proyecto: `WebControls:TextBox2`, `rad:RadComboBox2`,
  `WebControls:PushButton`, `asp:CustomValidator` con
  `ClientValidationFunction="validaControl"` y `ValidationGroup="<Entidad>"`.
- Botón Guardar al final: `WebControls:PushButton ... OnClick="btnGuardar_Click" ValidationGroup="<Entidad>"`.

### `.ascx.cs`
- `partial class View_<Ruta>_<Entidad>_<Tab> : System.Web.UI.UserControl`.
- Propiedades `ReadOnly`, `Id<Entidad>` vía `ViewState`.
- `LoadControls(sender, e)`: carga combos (`RadComboBox2`) en `!IsPostBack`,
  usando el Controller correspondiente (ej. `PaisesController`).
- `Page_PreRender`: `CargarDatos()`, `Bloqueo()`,
  `ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar)`, `udPanel.Update()`.
- `CargarDatos()`: si `Id<Entidad> > 0`, trae el registro con el Controller y
  setea los controles; si no, limpia los campos.
- `Bloqueo()`: setea `ReadOnly`/`Enabled`/`Visible` de cada control según `ReadOnly`.
- `btnGuardar_Click`: arma el Model desde los controles, valida (ej. extensión
  de archivo subido), llama `Insert`/`Update` del Controller según
  `Id<Entidad> > 0`, y muestra el resultado con `Tools.tools.ClientAlert(respuesta.detalle, "ok"/"alerta"/"error", true)`.
- Todo dentro de `try/catch` que captura excepciones con
  `Tools.tools.ClientAlert(ex.ToString(), "error")`.

---

## 7. Página `.aspx` (listado o formulario)

### `.aspx`
- `<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="<Pagina>.aspx.cs" Inherits="View_<Ruta>_<Pagina>" %>`.
- Registra el UserControl principal (listado o formulario) con `<%@ Register ... TagPrefix="wuc" %>`.
- Secciones `asp:Content` para los placeholders del master:
  `cphHeder`, `chpScript`, `cphTitulo` (título de la página), `cphFiltro`, `cphBody`.
- En `cphBody` se coloca el `wuc:` principal, pasando `URLNuevoXxx` /
  `URLVolverXxx` con rutas relativas (`~/View/...`).

### `.aspx.cs`
- `partial class View_<Ruta>_<Pagina> : System.Web.UI.Page`.
- `Page_Load`:
  - `#region SeguridadPagina`: crea `MenuPerfil ver` con `mpe_menu = (int)SitioBase.Paginas.menu_<N>.Ver`
    y llama `SitioBase.Token.SecurityManagerVer(ver)`.
  - Setea propiedades de seguridad/configuración del UserControl principal
    (`wucXxx.VerTodoPaises = (int)SitioBase.Paginas.menu_<N>.Ver_Todo_Paises;`,
    `wucXxx.Ver_Todo = ...`, `wucXxx.Crear_Editar = ...`, `wucXxx.Tipo_Perfil = ...`).
  - En páginas de formulario, también puede leer querystring cifrado
    (`Tools.Crypto.Decrypt`) para `Id<Entidad>` / `ReadOnly` y pasarlos al UserControl.
- `Page_PreRender`: normalmente vacío (placeholder).

---

## 8. Convenciones generales

- **Idioma**: nombres de propiedades/columnas en español/abreviado con prefijo
  de tabla (`cli_`, `usu_`, etc.); textos de UI y mensajes en español.
- **Clases auxiliares de `SitioBase`** (no reinventar):
  - `Token.TokenSeguridad()` / `Token.SecurityManager(...)` / `Token.SecurityManagerVer(...)`
  - `Session.UsuarioId()` / `Session.UsuarioIdPaises()`
  - `Conexion.GetDataReader(cmd)` / `Conexion.GetCommand("SP")`
  - `Respuesta` (Model) con `codigo`, `detalle`, `error`
  - `Tools.tools.ClientAlert(...)`, `Tools.tools.RegisterPostBackScript(...)`, `Tools.Crypto.Encrypt/Decrypt`
  - `Paginas.menu_<N>` para permisos por menú/función.
- **Controles custom**: `WebControls:TextBox2`, `WebControls:PushButton`,
  `rad:RadComboBox2`, `rad:RadGrid2`, `rad:RadTabStrip2`/`RadMultiPage` (Telerik
  envueltos en wrappers propios `WebControls`).
- **Codificación de archivos**: todos los `.cs`, `.ascx`, `.aspx` existentes
  están en **UTF-8 con BOM** y terminadores de línea **CRLF**. Cualquier archivo
  nuevo o modificado debe respetar este formato (ver tarea de codificación).

---

## 9. Checklist al crear una nueva entidad "Xxx"

1. `App_Code/MVC/Facilityges/Model/Xxx.cs` – propiedades + campos `filtro_*`.
2. `App_Code/MVC/Facilityges/Controller/XxxController.cs` – `GetXxxs`, `GetXxx`,
   `InsertXxx`, `UpdateXxx`, `DeleteXxx` usando SPs `SEL_/INS_/UPD_/DEL_XXX`.
3. `View/<Modulo>/Controls/Xxx/Xxxs.ascx(.cs)` – grid de listado.
4. `View/<Modulo>/Controls/Xxx/Xxx.ascx(.cs)` – formulario (con tabs si aplica).
5. Sub-controles de tabs si corresponde (`Identidad.ascx`, etc.).
6. `View/<Modulo>/<SubModulo>/Xxxs.aspx(.cs)` – página listado.
7. `View/<Modulo>/<SubModulo>/Xxx.aspx(.cs)` – página formulario.
8. Registrar permisos en `SitioBase.Paginas` (`menu_<N>`) si es un módulo nuevo.
9. Guardar todos los archivos nuevos/editados en **UTF-8 con BOM**.
