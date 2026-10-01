using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Umbrales y acciones de ítems (HU-091), en MODAL desde el centro de la pauta.
/// Se abre con ?query=Encrypt("Id=&lt;plantilla&gt;"): filtra al BORRADOR de esa
/// pauta (creándolo/clonándolo de la publicada si no existe), para no editar los
/// umbrales congelados de la versión publicada. El alta/edición va en la ficha.
/// </summary>
public partial class View_Mantenimiento_Checklist_ChecklistItemValidacions : System.Web.UI.Page
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

    /// <summary>Query cifrado para el botón "Nuevo": acota el selector de ítem a este borrador.</summary>
    protected string NuevoQuery
    {
        get { return Server.UrlEncode(Tools.Crypto.Encrypt("Version=" + Version)); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("civ_id", "", Width: "4%");
            Grid.AddTemplateColumn("ITEM", "", "ÍTEM", Width: "34%");
            Grid.AddColumn("tipo_nombre", "TIPO", Width: "11%");
            Grid.AddTemplateColumn("UMBRALES", "", "UMBRALES", Width: "20%");
            Grid.AddTemplateColumn("ACCIONES", "", "ACCIONES", Width: "21%");
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
        ChecklistItemValidacion filtro = new ChecklistItemValidacion
        {
            filtro_plantilla = Plantilla,
            filtro_version = Version > 0 ? Version : (int?)null
        };
        Grid.DataSource = new ChecklistItemValidacionController().GetValidaciones(filtro) ?? new List<ChecklistItemValidacion>();
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        ChecklistItemValidacion v = item.DataItem as ChecklistItemValidacion;
        if (v == null) return;

        // ÍTEM: sección · texto
        item["ITEM"].Controls.Add(new Literal
        {
            Text = (string.IsNullOrEmpty(v.seccion_nombre) ? "" : "<span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(v.seccion_nombre) + " · </span>")
                 + Server.HtmlEncode(v.item_texto)
        });

        // UMBRALES: min / adv / crit / max
        item["UMBRALES"].Controls.Add(new Literal { Text = Umbrales(v) });

        // ACCIONES: chips
        item["ACCIONES"].Controls.Add(new Literal { Text = Acciones(v) });

        // Link de edición en la celda del id
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + v.civ_id));
        HyperLink editar = new HyperLink { ID = "lnkEditar" + v.civ_id, CssClass = "icono_Editar", NavigateUrl = "javascript:void(0)" };
        editar.Attributes.Add("onclick", "abrirValidacion('" + query + "')");
        item["civ_id"].Controls.Add(editar);
    }

    private static string Umbrales(ChecklistItemValidacion v)
    {
        System.Func<decimal?, string> f = d => d == null ? "—" : d.Value.ToString("0.####");
        bool hayNum = v.valor_minimo != null || v.valor_maximo != null || v.valor_advertencia != null || v.valor_critico != null;
        if (!hayNum) return "<span class=\"sigma-inv-vacio\">sin umbrales</span>";
        return "<span title=\"mínimo / advertencia / crítico / máximo\">"
             + f(v.valor_minimo) + " / <span style=\"color:#b06400;\">" + f(v.valor_advertencia) + "</span> / <span style=\"color:#b91c1c;\">"
             + f(v.valor_critico) + "</span> / " + f(v.valor_maximo) + "</span>";
    }

    private static string Acciones(ChecklistItemValidacion v)
    {
        System.Text.StringBuilder s = new System.Text.StringBuilder();
        if (v.requiere_comentario) s.Append("<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-comment-alert-outline\"></i>comentario</span> ");
        if (v.requiere_evidencia) s.Append("<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-camera\"></i>foto</span> ");
        if (v.genera_alerta) s.Append("<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-bell-alert-outline\"></i>alerta</span> ");
        if (v.genera_hallazgo) s.Append("<span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-clipboard-alert-outline\"></i>hallazgo</span> ");
        if (s.Length == 0) return "<span class=\"sigma-inv-vacio\">—</span>";
        return s.ToString();
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0) { Tools.tools.ClientAlert("Debe seleccionar al menos un registro."); return; }

            Respuesta respuesta = new Respuesta();
            ChecklistItemValidacionController controller = new ChecklistItemValidacionController();
            foreach (string indice in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[int.Parse(indice)];
                respuesta = controller.DeleteValidacion(new ChecklistItemValidacion { civ_id = int.Parse(value["civ_id"].ToString()) });
            }

            if (!respuesta.error) Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            else Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message); }
    }
}
