using Agendamiento.Controller;
using Agendamiento.Model;
using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using Tools;

public partial class View_Root_LogSistema_LogApp : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina
        MenuPerfil ver = new MenuPerfil();
        ver.mpe_menu = (int)Paginas.menu_1049.Ver;
        Token.SecurityManagerVer(ver);
        #endregion

        if (!IsPostBack)
        {
            Grid.AddColumn("ACCION_VER",          "VER",           Width: "4%");
            Grid.AddColumn("lot_id",              "ID",            Width: "5%");
            Grid.AddColumn("lot_endpoint",        "ENDPOINT",      Width: "22%");
            Grid.AddColumn("lot_metodo",          "METODO",        Width: "6%");
            Grid.AddColumn("lot_error",           "ERROR",         Width: "5%");
            Grid.AddColumn("lot_nombre_usuario",  "USUARIO",       Width: "14%");
            Grid.AddColumn("lot_ip",              "IP",            Width: "10%"); 
            Grid.AddColumn("lot_duracion_ms",     "DURACION (ms)", Width: "8%");
            Grid.AddColumn("lot_fecha_creacion",  "FECHA",         Width: "13%");

            // Cargar combo de usuarios (perfil 11)
            RadComboBox2 cboUsuario = (RadComboBox2)wucFiltro.FindControl("cboUsuario");
            if (cboUsuario != null)
            {
                UsuarioController ctrlUsu = new UsuarioController();
                List<Usuario> usuarios = ctrlUsu.GetUsuarios(new Usuario { id_perfiles = "11" });
                if (usuarios != null)
                {
                    cboUsuario.Items.Add(new RadComboBoxItem("Todos", "0"));
                    foreach (Usuario u in usuarios)
                        cboUsuario.Items.Add(new RadComboBoxItem(u.nombre_completo, u.usu_id.ToString()));
                }
            }
        }

        tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    private void CargarGrid()
    {
        LogAppController ctrl = new LogAppController();
        LogApp filtro = new LogApp();

        // Filtro texto libre
        filtro.filtro = wucFiltro.Filtro();

        // Controles del panel personalizado
        System.Web.UI.WebControls.TextBox txtEndpoint = (System.Web.UI.WebControls.TextBox)wucFiltro.FindControl("txtEndpoint");
        RadComboBox2 cboUsuario = (RadComboBox2)wucFiltro.FindControl("cboUsuario");
        RadComboBox2 cboError   = (RadComboBox2)wucFiltro.FindControl("cboError");
        WebControls.Calendar calDesde = (WebControls.Calendar)wucFiltro.FindControl("radFechaDesde");
        WebControls.Calendar calHasta = (WebControls.Calendar)wucFiltro.FindControl("radFechaHasta");

        if (txtEndpoint != null && !string.IsNullOrWhiteSpace(txtEndpoint.Text))
            filtro.filtro_endpoint = txtEndpoint.Text.Trim();

        if (cboUsuario != null && !string.IsNullOrEmpty(cboUsuario.SelectedValue)
            && cboUsuario.SelectedValue != "0")
            filtro.filtro_id_cliente_usuario = Convert.ToInt32(cboUsuario.SelectedValue);

        if (cboError != null && !string.IsNullOrEmpty(cboError.SelectedValue))
            filtro.filtro_error = cboError.SelectedValue;

        if (calDesde != null && calDesde.Value.HasValue)
            filtro.filtro_desde = calDesde.Value.Value.ToString("yyyy-MM-dd");

        if (calHasta != null && calHasta.Value.HasValue)
            filtro.filtro_hasta = calHasta.Value.Value.ToString("yyyy-MM-dd");

        Grid.DataSource = ctrl.GetLogs(filtro);
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem &&
            e.Item.ItemType != GridItemType.Item) return;

        GridDataItem item = e.Item as GridDataItem;
        if (item == null) return;

        string id    = item.GetDataKeyValue("lot_id").ToString();
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

        // Botón Ver
        HyperLink lnkVer = new HyperLink();
        lnkVer.ID          = "lnkVer" + id;
        lnkVer.CssClass    = "icono_Editar";
        lnkVer.NavigateUrl = "javascript:void(0)";
        lnkVer.Attributes.Add("onclick", "abrirDetalle('" + query + "')");
        lnkVer.ToolTip     = "Ver detalle";
        item["ACCION_VER"].Controls.Add(lnkVer);

        // Badge Error
        TableCell celdaError = item["lot_error"];
        bool esError = celdaError.Text.Trim().ToLower() == "true";
        celdaError.Text = esError
            ? "<span class=\"label label-danger\">Si;</span>"
            : "<span class=\"label label-success\">No</span>";
    }
}
