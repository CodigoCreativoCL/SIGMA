using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de plantas del cliente (HU-011).
///
/// No hay boton Eliminar. Una planta con áreas, activos, órdenes o
/// usuarios asociados no se borra: se deshabilita desde su ficha. La baja
/// lógica conserva el histórico, que es lo que pide el negocio.
/// </summary>
public partial class View_Organizacion_Plantas_Plantas : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("CIN_ID", "", Width: "3%");
            Grid.AddColumn("CIN_CODIGO", "CÓDIGO", Width: "12%");
            Grid.AddColumn("CIN_NOMBRE", "NOMBRE", Width: "28%");
            Grid.AddColumn("CIN_DIRECCION", "DIRECCIÓN", Width: "32%");
            Grid.AddColumn("ZHO_NOMBRE", "ZONA HORARIA", Width: "18%");
            Grid.AddCheckboxColumn("CIN_HABILITADO", "HABILITADA");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;

        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;

        if (!hayCliente) return;

        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        ClienteInstalacion filtro = new ClienteInstalacion();
        ClienteInstalacionController controller = new ClienteInstalacionController();

        filtro.filtro_cliente = SitioBase.Session.ClienteId().ToString();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue;

        Grid.DataSource = controller.GetClienteInstalaciones(filtro);
    }

    protected void rgrPlantas_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("cin_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirPlanta('" + query + "')");

                item["cin_id"].Controls.Add(Editar);
            }
        }
    }
}
