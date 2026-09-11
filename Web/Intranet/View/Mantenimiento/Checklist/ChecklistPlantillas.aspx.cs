using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de plantillas de checklist / pautas de inspección (HU-090). Filtra
/// SIEMPRE por el cliente en sesión (barrera multicliente). La barra de
/// comandos (Nuevo / Dar de baja) la habilita Token.PuedeFuncion("Crear y
/// editar"); si no hay fila en Menu_Funcion, no aparece ni para Root.
/// </summary>
public partial class View_Mantenimiento_Checklist_ChecklistPlantillas : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("cpl_id", "", Width: "4%");
            Grid.AddColumn("cpl_codigo", "CÓDIGO", Width: "14%");
            Grid.AddColumn("cpl_nombre", "PAUTA", Width: "26%");
            Grid.AddColumn("planta_nombre", "PLANTA", Width: "16%");
            Grid.AddColumn("asignacion_tipo_nombre", "ASIGNACIÓN", Width: "16%");
            Grid.AddColumn("activo_tipo_nombre", "TIPO DE ACTIVO", Width: "14%");
            Grid.AddColumn("versiones", "VER.", Width: "6%");
            Grid.AddCheckboxColumn("cpl_habilitado", "HABILITADO");
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
        ChecklistPlantilla filtro = new ChecklistPlantilla();
        ChecklistPlantillaController controller = new ChecklistPlantillaController();

        filtro.filtro_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetChecklistPlantillas(filtro);
    }

    protected void rgrPlantillas_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("cpl_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                // Clic en la fila = previsualizar (sin editar). La lupa sigue editando.
                item.Attributes["onclick"] = "clFilaVer(this, event, '" + query + "')";
                item.Style["cursor"] = "pointer";

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirChecklistPlantilla('" + query + "')");
                item["cpl_id"].Controls.Add(Editar);
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
                ChecklistPlantillaController controller = new ChecklistPlantillaController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];
                    ChecklistPlantilla entidad = new ChecklistPlantilla();
                    entidad.cpl_id = Int32.Parse(value["cpl_id"].ToString());
                    respuesta = controller.DeleteChecklistPlantilla(entidad);
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
