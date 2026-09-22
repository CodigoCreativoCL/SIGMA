using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de programaciones recurrentes de pautas (HU-094). Filtra siempre por
/// el cliente en sesión. La barra de comandos la habilita la función
/// "Crear y editar".
/// </summary>
public partial class View_Mantenimiento_Checklist_ChecklistProgramacions : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("cpr_id", "", Width: "4%");
            Grid.AddColumn("cpr_nombre", "NOMBRE", Width: "22%");
            Grid.AddColumn("pauta_nombre", "PAUTA", Width: "22%");
            Grid.AddColumn("programacion_nombre", "RECURRENCIA", Width: "14%");
            Grid.AddColumn("activo_nombre", "OBJETIVO", Width: "16%");
            Grid.AddColumn("responsable_nombre", "RESPONSABLE", Width: "12%");
            Grid.AddCheckboxColumn("cpr_habilitado", "HABILITADO");
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
        ChecklistProgramacion filtro = new ChecklistProgramacion();
        ChecklistProgramacionController controller = new ChecklistProgramacionController();

        filtro.filtro_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetProgramaciones(filtro);
    }

    protected void rgrProgramaciones_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("cpr_id").ToString();

                // Objetivo: el activo o, si no, el área.
                string activo = Convert.ToString(DataBinder.Eval(item.DataItem, "activo_nombre"));
                string area = Convert.ToString(DataBinder.Eval(item.DataItem, "area_nombre"));
                item["activo_nombre"].Text = !string.IsNullOrEmpty(activo)
                    ? Server.HtmlEncode(activo)
                    : (!string.IsNullOrEmpty(area) ? "<span style=\"color:#6C5CFF;\">Área:</span> " + Server.HtmlEncode(area) : "—");

                // Pauta con su número de versión.
                string pauta = Convert.ToString(DataBinder.Eval(item.DataItem, "pauta_nombre"));
                object numo = DataBinder.Eval(item.DataItem, "version_numero");
                item["pauta_nombre"].Text = Server.HtmlEncode(pauta) + (numo != null ? " <span style=\"color:#94a3b8;\">v" + numo + "</span>" : "");

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));
                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirProgramacion('" + query + "')");
                item["cpr_id"].Controls.Add(Editar);
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
                ChecklistProgramacionController controller = new ChecklistProgramacionController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];
                    ChecklistProgramacion entidad = new ChecklistProgramacion();
                    entidad.cpr_id = Int32.Parse(value["cpr_id"].ToString());
                    respuesta = controller.DeleteProgramacion(entidad);
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
