using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de bodegas (HU-052).
/// </summary>
public partial class View_Inventario_Bodegas_Bodegas : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("BOD_ID", "", Width: "3%");
            Grid.AddColumn("BOD_CODIGO", "CÓDIGO", Width: "14%");
            Grid.AddColumn("BOD_NOMBRE", "NOMBRE", Width: "28%");
            Grid.AddColumn("PLANTA_NOMBRE", "PLANTA", Width: "22%");
            Grid.AddColumn("UBICACIONES", "UBICACIONES", Width: "13%");
            Grid.AddColumn("REPUESTOS_CON_SALDO", "CON EXISTENCIA", Width: "20%");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    /// <summary>
    /// Llena el combo de plantas del filtro (patrón: OnLoad="LoadControls").
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack && sender is RadComboBox2)
        {
            RadComboBox2 ctrl = (RadComboBox2)sender;

            if (ctrl.ID == "cboPlanta")
            {
                ClienteInstalacion filtroPlanta = new ClienteInstalacion();
                filtroPlanta.filtro_cliente = SitioBase.Session.ClienteId().ToString();
                filtroPlanta.filtro_habilitado = "1";

                ClienteInstalacionController ctrlPlanta = new ClienteInstalacionController();

                ctrl.Items.Add(new RadComboBoxItem("Todas", ""));
                ctrl.AppendDataBoundItems = true;
                ctrl.DataSource = ctrlPlanta.GetClienteInstalaciones(filtroPlanta);
                ctrl.DataValueField = "cin_id";
                ctrl.DataTextField = "cin_nombre";
                ctrl.DataBind();
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("bod_id").ToString();
                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + item.ItemIndex;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirBodega('" + query + "')");

                item["bod_id"].Controls.Add(Editar);
            }
        }
    }

    protected void CargarGrid()
    {
        BodegaController controller = new BodegaController();

        Bodega filtro = new Bodega();

        /* El texto busca por código y por nombre: es lo que hace @FILTRO en
           SEL_BODEGA, parametrizado. */
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        RadComboBox2 cboPlanta = (RadComboBox2)wucFiltro.FindControl("cboPlanta");
        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (cboPlanta != null && !string.IsNullOrEmpty(cboPlanta.SelectedValue))
            filtro.filtro_instalacion = int.Parse(cboPlanta.SelectedValue);

        /* Por defecto solo las habilitadas. Sin esto el listado abriría
           mostrando también las dadas de baja, que es información de
           auditoría y no lo que se viene a hacer. */
        filtro.filtro_habilitado = (cboHabilitado != null && !string.IsNullOrEmpty(cboHabilitado.SelectedValue))
            ? (bool?)(cboHabilitado.SelectedValue == "1")
            : true;

        Grid.DataSource = controller.GetBodegas(filtro);
    }
}
