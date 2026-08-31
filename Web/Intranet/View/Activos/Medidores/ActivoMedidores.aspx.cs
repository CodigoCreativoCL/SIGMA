using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de medidores de activos (HU-042).
///
/// SEGURIDAD POR DATOS
///   El acceso lo resuelve el master con Token.ExigirPagina(). Aquí solo se
///   pregunta la función de escritura para la barra de comandos, y SIEMPRE se
///   filtra por el cliente en sesión: un medidor es de un activo de una
///   empresa, y sin este filtro se verían los de otra.
/// </summary>
public partial class View_Activos_Medidores_ActivoMedidores : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("AME_ID", "", Width: "3%");
            Grid.AddColumn("AME_CODIGO", "CÓDIGO", Width: "13%");
            Grid.AddColumn("AME_NOMBRE", "NOMBRE", Width: "24%");
            Grid.AddColumn("ACTIVO_CODIGO", "ACTIVO", Width: "13%");
            Grid.AddColumn("ACTIVO_NOMBRE", "", Width: "22%");
            Grid.AddColumn("UNIDAD_SIMBOLO", "UNIDAD", Width: "9%");
            Grid.AddColumn("AME_VALOR_ACTUAL", "VALOR ACTUAL", Width: "12%");
            Grid.AddCheckboxColumn("AME_HABILITADO", "HABILITADO");
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
        ActivoMedidor filtro = new ActivoMedidor();
        ActivoMedidorController controller = new ActivoMedidorController();

        // Barrera multicliente: no es opcional.
        filtro.ame_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetActivoMedidores(filtro);
    }

    protected void rgrMedidores_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("ame_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirActivoMedidor('" + query + "')");

                item["ame_id"].Controls.Add(Editar);
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
                ActivoMedidorController controller = new ActivoMedidorController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];

                    ActivoMedidor entidad = new ActivoMedidor();
                    entidad.ame_id = Int32.Parse(value["ame_id"].ToString());

                    respuesta = controller.DeleteActivoMedidor(entidad);
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
