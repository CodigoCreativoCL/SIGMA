using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de fallas (HU-123). Por defecto las que aun no tienen solucion;
/// la columna «Historial» avisa cuando el equipo acumula reparaciones
/// provisorias, que es la señal que la HU pide hacer visible.
/// </summary>
public partial class View_Mantenimiento_Fallas_Fallas : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("FAL_ID", "", Width: "3%");
            Grid.AddColumn("FAL_TITULO", "FALLA", Width: "24%");
            Grid.AddTemplateColumn("EQUIPO", "", "EQUIPO", Width: "18%");
            Grid.AddTemplateColumn("CRITICIDAD", "", "CRITICIDAD", Width: "9%");
            Grid.AddTemplateColumn("DETECCION", "", "DETECTADA", Width: "10%");
            Grid.AddTemplateColumn("SITUACION", "", "SITUACIÓN", Width: "14%");
            Grid.AddTemplateColumn("ORDENES", "", "OT", Width: "8%");
            Grid.AddTemplateColumn("HISTORIAL", "", "HISTORIAL DEL EQUIPO", Width: "14%");
        }
        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;
        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;
        if (!hayCliente) return;

        ConfigurarPlantas();
        bool puedeCrear = Token.PuedeFuncion("Crear y editar");

        CargarGrid();
        Grid.DataBind();

        if (!puedeCrear) Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;
        udPanel.Update();
    }

    private RadComboBox2 Cbo(string id) { return (RadComboBox2)wucFiltro.FindControl(id); }

    private void ConfigurarPlantas()
    {
        RadComboBox2 cbo = Cbo("cboPlanta");
        if (cbo == null) return;
        string sel = cbo.SelectedValue;
        List<ClienteInstalacion> plantas = new ClienteInstalacionController().GetClienteInstalaciones(
            new ClienteInstalacion { cin_cliente = SitioBase.Session.ClienteId() }) ?? new List<ClienteInstalacion>();
        cbo.Items.Clear();
        cbo.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
        foreach (ClienteInstalacion p in plantas) cbo.Items.Add(new RadComboBoxItem(p.cin_nombre, p.cin_id.ToString()));
        RadComboBoxItem it = cbo.FindItemByValue(sel ?? ""); if (it != null) it.Selected = true;
    }

    protected void CargarGrid()
    {
        Falla f = new Falla();
        RadComboBox2 cboAbiertas = Cbo("cboAbiertas"), cboPlanta = Cbo("cboPlanta");
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) f.filtro = wucFiltro.Filtro();
        if (cboPlanta != null && cboPlanta.SelectedValue != "") f.filtro_instalacion = int.Parse(cboPlanta.SelectedValue);
        string ab = cboAbiertas == null ? "1" : cboAbiertas.SelectedValue;
        if (ab != "") f.filtro_abiertas = ab == "1";
        Grid.DataSource = new FallaController().GetFallas(f) ?? new List<Falla>();
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        Falla f = item.DataItem as Falla;
        if (f == null) return;

        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + f.fal_id));
        HyperLink Editar = new HyperLink { ID = "lnkEditar" + f.fal_id, CssClass = "icono_Editar", NavigateUrl = "javascript:void(0)" };
        Editar.Attributes.Add("onclick", "abrirFalla('" + query + "')");
        item["fal_id"].Controls.Add(Editar);

        item["EQUIPO"].Controls.Add(new Literal
        {
            Text = Server.HtmlEncode(f.activo_codigo) + " <span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(f.activo_nombre) + "</span>"
                 + (string.IsNullOrEmpty(f.componente_nombre) ? "" : "<br/><span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(f.componente_nombre) + "</span>")
        });
        item["CRITICIDAD"].Controls.Add(new Literal { Text = ChipCriticidad(f.criticidad_codigo, f.criticidad_nombre) });
        item["DETECCION"].Controls.Add(new Literal
        {
            Text = (f.fal_fecha_deteccion_utc == null ? "—" : f.fal_fecha_deteccion_utc.Value.ToString("dd-MM-yyyy HH:mm"))
                 + (f.fal_detuvo_produccion ? "<br/><span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-factory\"></i>detuvo producción</span>" : "")
        });
        item["SITUACION"].Controls.Add(new Literal { Text = ChipSituacion(f) });
        item["ORDENES"].Controls.Add(new Literal
        {
            Text = f.ordenes == 0 ? "<span class=\"sigma-inv-vacio\">sin OT</span>"
                 : "OT-" + f.ultima_ot_correlativo + (f.ordenes > 1 ? " <span class=\"sigma-inv-vacio\">(+" + (f.ordenes - 1) + ")</span>" : "")
        });
        item["HISTORIAL"].Controls.Add(new Literal
        {
            Text = f.provisorias_del_equipo >= 2
                 ? "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-repeat\"></i>" + f.provisorias_del_equipo + " reparaciones provisorias</span>"
                 : f.provisorias_del_equipo == 1 ? "<span class=\"sigma-inv-vacio\">1 provisoria</span>"
                 : "<span class=\"sigma-inv-vacio\">—</span>"
        });
    }

    public static string ChipCriticidad(string codigo, string nombre)
    {
        switch ((codigo ?? "").ToUpperInvariant())
        {
            case "CRITICA": case "ALTA": return "<span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-alert\"></i>" + nombre + "</span>";
            case "MEDIA":                return "<span class=\"grid-estado-chip is-advertencia\">" + nombre + "</span>";
            default:                     return "<span class=\"grid-estado-chip is-neutro\">" + nombre + "</span>";
        }
    }

    public static string ChipSituacion(Falla f)
    {
        if (f.fal_fecha_solucion_utc != null)
            return "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-check-circle\"></i>Resuelta</span><br/><span class=\"sigma-inv-vacio\">" + f.fal_fecha_solucion_utc.Value.ToString("dd-MM-yyyy") + "</span>";
        if (f.acciones_provisorias > 0)
            return "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-wrench-clock\"></i>Provisoria</span>";
        if (f.diagnosticos > 0)
            return "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-stethoscope\"></i>Diagnosticada</span>";
        return "<span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-alert-circle-outline\"></i>Abierta</span>";
    }
}
