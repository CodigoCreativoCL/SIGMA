using System;
using System.Collections.Generic;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using Sigma.Model;
using Sigma.Controller;
using SitioBase;

/// <summary>
/// CODE-BEHIND DEL LISTADO.
///
/// PATRON (ver PATRON_MVC.md seccion 4, PATRON_CONTROLES.md seccion 1,
/// PATRON_GRID_EVENTS.md secciones 2-4):
///
///  1. La clase es partial y hereda de System.Web.UI.UserControl.
///     El nombre = ruta del archivo con "_" (View_Seguridad_Controls_Usuario_Usuarios).
///  2. Las propiedades publicas se guardan en ViewState, NO en campos privados:
///     un campo privado se pierde entre postbacks, el ViewState no.
///  3. Las columnas del grid se construyen por codigo en !IsPostBack con los
///     helpers de RadGrid2 (AddColumn / AddSelectColumn / AddCheckboxColumn).
///  4. La carga de datos va en Page_PreRender, no en Page_Load: asi el grid
///     ya refleja los cambios que hicieron los eventos de los botones.
///  5. El code-behind NUNCA toca la base de datos: siempre pasa por el Controller.
/// </summary>
public partial class View_Seguridad_Controls_Usuario_Usuarios : System.Web.UI.UserControl
{
    #region PROPIEDADES (siempre en ViewState)

    /// <summary>Modo solo lectura: oculta la barra de comandos del grid.</summary>
    public bool ReadOnly
    {
        get { return ViewState["ReadOnly"] == null ? false : (bool)ViewState["ReadOnly"]; }
        set { ViewState["ReadOnly"] = value; }
    }

    /// <summary>Ruta del formulario. La setea la pagina padre (.aspx).</summary>
    public string URLNuevoUsuario
    {
        get { return ViewState["URLNuevoUsuario"] == null ? "" : ViewState["URLNuevoUsuario"].ToString(); }
        set { ViewState["URLNuevoUsuario"] = value; }
    }

    // --- Propiedades de SEGURIDAD que setea la pagina padre desde SitioBase.Paginas ---

    /// <summary>Id de la funcion "Ver todo" del menu: permite ver registros de otros usuarios.</summary>
    public int Ver_Todo
    {
        get { return ViewState["Ver_Todo"] == null ? 0 : (int)ViewState["Ver_Todo"]; }
        set { ViewState["Ver_Todo"] = value; }
    }

    /// <summary>Id de la funcion "Ver todo paises": permite ver usuarios de todos los paises.</summary>
    public int VerTodoPaises
    {
        get { return ViewState["VerTodoPaises"] == null ? 0 : (int)ViewState["VerTodoPaises"]; }
        set { ViewState["VerTodoPaises"] = value; }
    }

    /// <summary>Id de la funcion "Crear/Editar": si no la tiene, el grid va en ReadOnly.</summary>
    public int Crear_Editar
    {
        get { return ViewState["Crear_Editar"] == null ? 0 : (int)ViewState["Crear_Editar"]; }
        set { ViewState["Crear_Editar"] = value; }
    }

    #endregion

    #region CICLO DE VIDA

    /// <summary>
    /// PreRender: es el ultimo evento antes de renderizar. Cargar aqui garantiza
    /// que el grid muestre el resultado de los clicks que ya se procesaron.
    /// </summary>
    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            // --- Construccion de columnas. Solo la primera vez. ---

            Grid.AddSelectColumn();                                     // checkbox de seleccion por fila
            Grid.AddColumn("usu_id", "", Width: "3%");                  // celda donde se inyecta el link Editar
            Grid.AddColumn("usu_rut", "RUT", Width: "12%");
            Grid.AddColumn("usu_nombres", "NOMBRES", Width: "20%");
            Grid.AddColumn("usu_apellidos", "APELLIDOS", Width: "20%");
            Grid.AddColumn("usu_email", "EMAIL", Width: "22%");
            Grid.AddColumn("per_nombre", "PERFIL", Width: "13%");
            Grid.AddColumn("pai_nombre", "PAIS", Width: "10%");
            Grid.AddCheckboxColumn("usu_habilitado", "HABILITADO");
        }

        // En solo lectura se oculta toda la barra Nuevo/Deshabilitar.
        if (ReadOnly)
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();

        // Registra el script que permite refresh() desde JS (__doPostBack).
        Tools.tools.RegisterPostBackScript(Grid);
    }

    #endregion

    #region CARGA DE DATOS

    /// <summary>
    /// Arma el Model de filtros y se lo entrega al Controller.
    /// Aqui NO hay SQL: solo se traducen los controles de pantalla a filtros.
    /// </summary>
    protected void CargarGrid()
    {
        UsuarioController usuarioController = new UsuarioController();
        Usuario filtro = new Usuario();

        #region SeguridadPagina

        // Si el perfil NO tiene la funcion "Ver todo paises", se le limita
        // el listado a los paises que tiene asignados en su sesion.
        MenuFuncion verTodoPaises = new MenuFuncion();
        verTodoPaises.mfu_funcion = VerTodoPaises;

        if (!SitioBase.Token.SecurityManager(verTodoPaises))
            filtro.filtro_paises = SitioBase.Session.UsuarioIdPaises();

        #endregion

        // Texto libre de la barra de filtros comun.
        filtro.filtro = wucFiltro.Filtro();

        // Controles que viven dentro del UserControl de filtro: se buscan con FindControl.
        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        if (cboHabilitado != null && !string.IsNullOrEmpty(cboHabilitado.SelectedValue))
            filtro.filtro_habilitado = bool.Parse(cboHabilitado.SelectedValue);

        RadComboBox2 cboPerfil = (RadComboBox2)wucFiltro.FindControl("cboPerfil");
        if (cboPerfil != null && !string.IsNullOrEmpty(cboPerfil.SelectedValue))
            filtro.filtro_perfil = int.Parse(cboPerfil.SelectedValue);

        // Unica llamada a datos de todo el archivo.
        Grid.DataSource = usuarioController.GetUsuarios(filtro);
    }

    #endregion

    #region EVENTOS DEL GRID

    /// <summary>
    /// Se ejecuta UNA VEZ POR FILA ya con datos.
    /// Aqui se inyecta el link "Editar" que abre el formulario.
    ///
    /// El id NO viaja en claro por la URL: se cifra con Tools.Crypto.Encrypt
    /// para que nadie pueda editar otro registro cambiando el numero a mano.
    /// </summary>
    protected void rgrUsuarios_ItemDataBound(object sender, GridItemEventArgs e)
    {
        // Solo filas de datos: ni encabezado, ni footer, ni paginador.
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (e.Item is GridDataItem)
            {
                GridDataItem item = e.Item as GridDataItem;

                // La columna debe estar declarada en DataKeyNames del MasterTableView.
                string id = item.GetDataKeyValue("usu_id").ToString();

                string query = Server.UrlEncode(
                    Tools.Crypto.Encrypt("IdUsuario=" + id + "&ReadOnly=" + ReadOnly));

                // Para NAVEGAR se usa HyperLink (sin postback), no LinkButton.
                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirUsuario('" + query + "')");

                item["usu_id"].Controls.Add(Editar);
            }
        }
    }

    /// <summary>
    /// Accion masiva sobre las filas seleccionadas.
    /// Patron: validar seleccion -> recorrer SelectedIndexes -> llamar al Controller
    /// -> avisar con Tools.tools.ClientAlert.
    /// </summary>
    protected void lnkDeshabilitar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
                return;
            }

            Respuesta respuesta = new Respuesta();
            UsuarioController usuarioController = new UsuarioController();

            foreach (string idx in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[int.Parse(idx)];
                int id = int.Parse(value["usu_id"].ToString());

                Usuario usuario = new Usuario { usu_id = id };
                respuesta = usuarioController.DeshabilitarUsuario(usuario);
            }

            // El tercer parametro true cierra el modal / dispara refresh().
            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }

    #endregion
}
