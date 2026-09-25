using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de categorías de tarea (HU-100). El acceso a la pantalla lo resuelve
/// el master con Token.ExigirPagina(): aquí solo se pregunta la función de
/// escritura. Siempre acotado al cliente en sesión.
/// </summary>
public partial class View_Mantenimiento_Tareas_TareaCategorias : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("tca_id", "", Width: "4%");
            Grid.AddColumn("tca_codigo", "CÓDIGO", Width: "18%");
            Grid.AddColumn("tca_nombre", "NOMBRE", Width: "38%");
            Grid.AddColumn("tca_color", "COLOR", Width: "14%");
            Grid.AddColumn("tca_orden", "ORDEN", Width: "10%");
            Grid.AddCheckboxColumn("tca_habilitado", "HABILITADO");
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
        TareaCategoria filtro = new TareaCategoria();
        TareaCategoriaController controller = new TareaCategoriaController();

        filtro.tca_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetTareaCategorias(filtro);
    }

    protected void rgrTareaCategorias_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("tca_id").ToString();

                // Muestra el color como una muestra junto al valor.
                string color = Convert.ToString(DataBinder.Eval(item.DataItem, "tca_color"));
                if (!string.IsNullOrEmpty(color))
                    item["tca_color"].Text = "<span style=\"display:inline-block;width:12px;height:12px;border-radius:3px;vertical-align:middle;margin-right:6px;background:"
                        + Server.HtmlEncode(color) + ";border:1px solid #cbd5e1;\"></span>" + Server.HtmlEncode(color);

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));
                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirTareaCategoria('" + query + "')");
                item["tca_id"].Controls.Add(Editar);
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
                TareaCategoriaController controller = new TareaCategoriaController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];
                    TareaCategoria entidad = new TareaCategoria();
                    entidad.tca_id = Int32.Parse(value["tca_id"].ToString());
                    respuesta = controller.DeleteTareaCategoria(entidad);
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
