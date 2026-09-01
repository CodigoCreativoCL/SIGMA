using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de tipos de activo, en árbol (HU-030).
///
/// Muestra los tipos del cliente en sesión MÁS los globales de SIGMA (que
/// se ven pero no se editan). El acceso lo resuelve el master con
/// Token.ExigirPagina(); aquí solo se pregunta la función de escritura.
/// </summary>
public partial class View_Activos_Tipos_ActivoTipos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("ATI_ID", "", Width: "3%");
            Grid.AddColumn("ATI_CODIGO", "CÓDIGO", Width: "18%");
            Grid.AddColumn("ATI_NOMBRE", "NOMBRE", Width: "30%");
            Grid.AddColumn("PADRE_NOMBRE", "DEPENDE DE", Width: "22%");
            Grid.AddColumn("AMBITO", "ÁMBITO", Width: "12%");
            Grid.AddCheckboxColumn("ATI_HABILITADO", "HABILITADO");
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
        ActivoTipo filtro = new ActivoTipo();
        ActivoTipoController controller = new ActivoTipoController();

        // El SEL devuelve los del cliente MÁS los globales.
        filtro.filtro_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetActivoTipos(filtro);
    }

    protected void rgrTipos_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("ati_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirActivoTipo('" + query + "')");
                item["ati_id"].Controls.Add(Editar);

                // Indentación por nivel: convierte la lista plana en jerarquía.
                int nivel = 1;
                object valorNivel = DataBinder.Eval(item.DataItem, "nivel");
                if (valorNivel != null) int.TryParse(valorNivel.ToString(), out nivel);
                if (nivel > 1)
                    item["ati_nombre"].Style["padding-left"] = ((nivel - 1) * 22) + "px";
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
                ActivoTipoController controller = new ActivoTipoController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];

                    ActivoTipo entidad = new ActivoTipo();
                    entidad.ati_id = Int32.Parse(value["ati_id"].ToString());

                    respuesta = controller.DeleteActivoTipo(entidad);
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
