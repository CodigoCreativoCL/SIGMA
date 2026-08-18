using Telerik.Web.UI;
using System;
using System.Web.UI.WebControls;
using System.Data;
using SitioBase.Model;
using SitioBase.Controller;
using System.Linq;

public partial class View_Root_Mantenedores_Log_Logs : System.Web.UI.Page
{
    public int Id
    {
        get { return Convert.ToInt32(ViewState["Id"]); }
        set { ViewState.Add("Id", value); }
    }

    private LogController controller = new LogController();
    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina
        MenuPerfil ver = new MenuPerfil();
        ver.mpe_menu = (int)SitioBase.Paginas.menu_1060.Ver;
        SitioBase.Token.SecurityManagerVer(ver);
        #endregion

        if (!IsPostBack)
        {
            ConfigurarGrid();
        }

        Tools.tools.RegisterPostBackScript(Grid);

    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargaGrid();
        udPanel.Update();
    }

    public void LoadControls(object sender, System.EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;
                switch (ctrl.ID)
                {
                    case "cboTabla":
                        Log filtro = new Log();
                        ctrl.AppendDataBoundItems = true;
                        ctrl.EmptyMessage = "Seleccione...";
                        ctrl.DataSource = controller.GetLogTabla(filtro);
                        ctrl.DataValueField = "lot_id";
                        ctrl.DataTextField = "lot_tabla";
                        ctrl.DataBind();
                        break;
                    case "cboUsuarios":
                        UsuarioController controller1 = new UsuarioController();
                        Usuario usuario = new Usuario();
                        ctrl.AppendDataBoundItems = true;
                        ctrl.EmptyMessage = "Seleccione...";
                        ctrl.DataSource = controller1.GetUsuarios(usuario);
                        ctrl.DataValueField = "usu_id";
                        ctrl.DataTextField = "nombre_completo";
                        ctrl.DataBind();
                        break;
                }
            }
        }
    }
    protected void ConfigurarGrid()
    {
        Grid.AddColumn("log_id", "ID", "10");
        Grid.AddColumn("usuario_nombre", "USUARIO", "30%");
        Grid.AddColumn("log_fecha_ejecucion", "FECHA EJECUCIÓN", "", HorizontalAlign.Left, false, "", "{0:dd-MM-yyyy hh:mm}");
        Grid.AddColumn("lot_tabla", "TABLA");
        Grid.AddColumn("log_columna", "COLUMNA", "30%");
        Grid.AddColumn("log_valor_actual", "VALOR ACTUAL", "30%");
        Grid.AddColumn("log_valor_nuevo", "VALOR NUEVO", "30%");
        Grid.AddColumn("loe_nombre", "ESTADO", "30%");

    }
    protected void CargaGrid()
    {
        Log log = new Log();

        if (wucFiltro.Filtro() != null) log.filtro = wucFiltro.Filtro();
        RadComboBox2 cboAccion = (RadComboBox2)wucFiltro.FindControl("cboAccion");
        RadComboBox2 cboTabla = (RadComboBox2)wucFiltro.FindControl("cboTabla");
        RadComboBox2 cboUsuarios = (RadComboBox2)wucFiltro.FindControl("cboUsuarios");

        if (!string.IsNullOrEmpty(cboAccion.dbValues())) log.accion = cboAccion.dbValues();
        if (!string.IsNullOrEmpty(cboTabla.dbValues())) log.tablas = cboTabla.dbValues();
        if (!string.IsNullOrEmpty(cboUsuarios.dbValues())) log.usuarios = cboUsuarios.dbValues();

        Grid.DataSource = controller.GetLogs(log);
        Grid.DataBind();
    }

}

