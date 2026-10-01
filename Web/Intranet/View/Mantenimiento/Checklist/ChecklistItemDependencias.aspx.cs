using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Dependencias entre ítems (HU-092), en MODAL desde el centro de la pauta.
/// Se abre con ?query=Encrypt("Id=&lt;plantilla&gt;"): filtra al BORRADOR de esa
/// pauta (creándolo/clonándolo de la publicada si no existe). El alta/edición va
/// en la ficha.
/// </summary>
public partial class View_Mantenimiento_Checklist_ChecklistItemDependencias : System.Web.UI.Page
{
    public int Plantilla
    {
        get { return ViewState["Plantilla"] != null ? (int)ViewState["Plantilla"] : 0; }
        set { ViewState["Plantilla"] = value; }
    }

    public int Version
    {
        get { return ViewState["Version"] != null ? (int)ViewState["Version"] : 0; }
        set { ViewState["Version"] = value; }
    }

    /// <summary>Query cifrado para el botón "Nuevo": acota los selectores de ítem a este borrador.</summary>
    protected string NuevoQuery
    {
        get { return Server.UrlEncode(Tools.Crypto.Encrypt("Version=" + Version)); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("cid_id", "", Width: "4%");
            Grid.AddTemplateColumn("ITEM", "", "ÍTEM DEPENDIENTE", Width: "28%");
            Grid.AddTemplateColumn("ACCION", "", "ACCIÓN", Width: "15%");
            Grid.AddTemplateColumn("CONDICION", "", "CONDICIÓN", Width: "37%");
            Grid.AddCheckboxColumn("habilitado", "HABILITADO");

            Plantilla = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
            ResolverBorrador();
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    /// <summary>Crea/obtiene el borrador de la pauta (clonando la publicada) y su nombre.</summary>
    private void ResolverBorrador()
    {
        if (Plantilla <= 0) return;
        ChecklistPlantilla pla = new ChecklistPlantillaController().GetChecklistPlantilla(Plantilla);
        litPauta.Text = pla != null ? Server.HtmlEncode(pla.cpl_nombre) : "—";
        Version = new ChecklistEstructuraController().GetBorradorVersion(Plantilla, SitioBase.Session.UsuarioId(), true);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool ok = SitioBase.Session.ClienteId() > 0 && Plantilla > 0;
        pnlSinCliente.Visible = !ok;
        udPanel.Visible = ok;
        if (!ok) return;

        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        ChecklistItemDependencia filtro = new ChecklistItemDependencia
        {
            filtro_plantilla = Plantilla,
            filtro_version = Version > 0 ? Version : (int?)null
        };
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
