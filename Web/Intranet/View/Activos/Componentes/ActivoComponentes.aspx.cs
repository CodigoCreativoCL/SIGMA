using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de componentes de activos (HU-036). Filtra SIEMPRE por el cliente
/// en sesión: un componente es de un activo de una empresa.
/// </summary>
public partial class View_Activos_Componentes_ActivoComponentes : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("ACO_ID", "", Width: "3%");
            Grid.AddColumn("ACO_CODIGO", "CÓDIGO", Width: "12%");
            Grid.AddColumn("ACO_NOMBRE", "NOMBRE", Width: "25%");
            Grid.AddColumn("ACTIVO_CODIGO", "ACTIVO", Width: "13%");
            Grid.AddColumn("TIPO_NOMBRE", "TIPO", Width: "15%");
            Grid.AddColumn("ESTADO_NOMBRE", "ESTADO", Width: "12%");
            Grid.AddColumn("CRITICIDAD_NOMBRE", "CRITICIDAD", Width: "10%");
            Grid.AddCheckboxColumn("ACO_HABILITADO", "HABILITADO");
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
        ActivoComponente filtro = new ActivoComponente();
        ActivoComponenteController controller = new ActivoComponenteController();

        filtro.aco_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetComponentes(filtro);
    }

    protected void rgrComponentes_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("aco_id").ToString();
                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirComponente('" + query + "')");
                item["aco_id"].Controls.Add(Editar);
            }
        }
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
            }
            else
            {
                Respuesta respuesta = new Respuesta();
                ActivoComponenteController controller = new ActivoComponenteController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];
                    ActivoComponente entidad = new ActivoComponente();
                    entidad.aco_id = Int32.Parse(value["aco_id"].ToString());
                    respuesta = controller.DeleteComponente(entidad);
                }

                if (!respuesta.error)
                    Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
                else
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }
}
