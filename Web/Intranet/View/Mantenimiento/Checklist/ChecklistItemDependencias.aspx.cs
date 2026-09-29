using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de dependencias entre ítems (HU-092). Solo lectura de la grilla: el
/// alta/edición va en la ficha (RadWindow). Filtra por el cliente en sesión y,
/// opcionalmente, por pauta. La barra de comandos la habilita la función
/// "Crear y editar".
/// </summary>
public partial class View_Mantenimiento_Checklist_ChecklistItemDependencias : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("cid_id", "", Width: "3%");
            Grid.AddColumn("plantilla_nombre", "PAUTA", Width: "18%");
            Grid.AddTemplateColumn("ITEM", "", "ÍTEM DEPENDIENTE", Width: "22%");
            Grid.AddTemplateColumn("ACCION", "", "ACCIÓN", Width: "13%");
            Grid.AddTemplateColumn("CONDICION", "", "CONDICIÓN", Width: "30%");
            Grid.AddCheckboxColumn("habilitado", "HABILITADO");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;
        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;
        if (!hayCliente) return;

        ConfigurarPlantillas();

        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    private RadComboBox2 Cbo(string id) { return (RadComboBox2)wucFiltro.FindControl(id); }

    private void ConfigurarPlantillas()
    {
        RadComboBox2 cbo = Cbo("cboPlantilla");
        if (cbo == null || cbo.Items.Count > 0) return;

        cbo.Items.Add(new RadComboBoxItem("Todas las pautas", ""));
        List<ChecklistPlantilla> pautas = new ChecklistPlantillaController().GetChecklistPlantillas(
            new ChecklistPlantilla { cpl_cliente = SitioBase.Session.ClienteId() }) ?? new List<ChecklistPlantilla>();
        foreach (ChecklistPlantilla p in pautas) cbo.Items.Add(new RadComboBoxItem(p.cpl_nombre, p.cpl_id.ToString()));
    }

    protected void CargarGrid()
    {
        ChecklistItemDependencia filtro = new ChecklistItemDependencia();
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        RadComboBox2 cbo = Cbo("cboPlantilla");
        if (cbo != null && cbo.SelectedValue != "") filtro.filtro_plantilla = int.Parse(cbo.SelectedValue);

        Grid.DataSource = new ChecklistItemDependenciaController().GetDependencias(filtro) ?? new List<ChecklistItemDependencia>();
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        ChecklistItemDependencia d = item.DataItem as ChecklistItemDependencia;
        if (d == null) return;

        item["ITEM"].Controls.Add(new Literal { Text = Server.HtmlEncode(d.item_texto) });
        item["ACCION"].Controls.Add(new Literal { Text = Accion(d) });
        item["CONDICION"].Controls.Add(new Literal { Text = Condicion(d) });

        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + d.cid_id));
        HyperLink editar = new HyperLink { ID = "lnkEditar" + d.cid_id, CssClass = "icono_Editar", NavigateUrl = "javascript:void(0)" };
        editar.Attributes.Add("onclick", "abrirDependencia('" + query + "')");
        item["cid_id"].Controls.Add(editar);
    }

    private string Accion(ChecklistItemDependencia d)
    {
        string clase = "is-neutro";
        switch ((d.accion_codigo ?? "").ToUpper())
        {
            case "MOSTRAR": clase = "is-ok"; break;
            case "OCULTAR": clase = "is-neutro"; break;
            case "REQUERIR": clase = "is-advertencia"; break;
            case "BLOQUEAR": clase = "is-alerta"; break;
        }
        return "<span class=\"grid-estado-chip " + clase + "\">" + Server.HtmlEncode(d.accion_nombre) + "</span>";
    }

    private string Condicion(ChecklistItemDependencia d)
    {
        // "cuando <ítem condición> <operador> <valor / opción>"
        string valor = !string.IsNullOrEmpty(d.opcion_texto) ? d.opcion_texto : d.valor;
        string cola = string.IsNullOrEmpty(valor) ? "" : " <strong>" + Server.HtmlEncode(valor) + "</strong>";
        return "<span class=\"sigma-inv-vacio\">si</span> " + Server.HtmlEncode(d.condicion_texto)
             + " <span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(d.operador_nombre) + "</span>" + cola;
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0) { Tools.tools.ClientAlert("Debe seleccionar al menos un registro."); return; }

            Respuesta respuesta = new Respuesta();
            ChecklistItemDependenciaController controller = new ChecklistItemDependenciaController();
            foreach (string indice in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[int.Parse(indice)];
                respuesta = controller.DeleteDependencia(new ChecklistItemDependencia { cid_id = int.Parse(value["cid_id"].ToString()) });
            }

            if (!respuesta.error) Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            else Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message); }
    }
}
