using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de unidades de medida (HU-040).
///
/// Catálogo GLOBAL de plataforma: NO se filtra por cliente (una unidad es
/// de todos). El acceso lo resuelve el master con Token.ExigirPagina() y el
/// permiso VER UNIDADES MEDIDA; solo se pregunta la función de escritura.
/// </summary>
public partial class View_Sistema_UnidadesMedida_UnidadMedidas : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("UME_ID", "", Width: "3%");
            Grid.AddColumn("UME_CODIGO", "CÓDIGO", Width: "15%");
            Grid.AddColumn("UME_NOMBRE", "NOMBRE", Width: "27%");
            Grid.AddColumn("UME_SIMBOLO", "SÍMBOLO", Width: "10%");
            Grid.AddColumn("MAGNITUD_NOMBRE", "MAGNITUD", Width: "20%");
            Grid.AddColumn("UNIDAD_BASE_NOMBRE", "BASE", Width: "15%");
            Grid.AddCheckboxColumn("UME_HABILITADO", "HABILITADO");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        UnidadMedida filtro = new UnidadMedida();
        UnidadMedidaController controller = new UnidadMedidaController();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetUnidades(filtro);
    }

    protected void rgrUnidades_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("ume_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirUnidad('" + query + "')");
                item["ume_id"].Controls.Add(Editar);
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
                UnidadMedidaController controller = new UnidadMedidaController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];

                    UnidadMedida entidad = new UnidadMedida();
                    entidad.ume_id = Int32.Parse(value["ume_id"].ToString());

                    respuesta = controller.DeleteUnidad(entidad);
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
