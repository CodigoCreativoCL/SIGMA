using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Historial de ejecuciones de una pauta (HU-097). Solo lectura: se elige una
/// pauta y se ven sus ejecuciones (fecha, ejecutor, equipo y no conformidades);
/// al abrir una ejecución se ve cada pregunta con su respuesta, si salió de
/// rango y sus fotografías, con las preguntas de la versión con que se ejecutó.
///
/// Reutiliza ChecklistCentroController (lee por pauta, no por usuario como la
/// app). El acceso lo resuelve el master por datos (fila en Menus con
/// VER HISTORIAL CHECKLIST) y el cliente va siempre desde la sesión.
/// </summary>
public partial class View_Mantenimiento_Checklist_ChecklistHistorial : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddTemplateColumn("FECHA", "", "FECHA", Width: "13%");
            Grid.AddColumn("ejecutor", "EJECUTOR", Width: "15%");
            Grid.AddTemplateColumn("EQUIPO", "", "EQUIPO", Width: "17%");
            Grid.AddTemplateColumn("VERSION", "", "VERSIÓN", Width: "8%");
            Grid.AddTemplateColumn("NOCONF", "", "NO CONFORMIDADES", Width: "12%");
            Grid.AddTemplateColumn("AVANCE", "", "AVANCE", Width: "9%");
            Grid.AddTemplateColumn("ESTADO", "", "ESTADO", Width: "12%");
            Grid.AddTemplateColumn("DETALLE", "", "", Width: "10%");
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
        ConfigurarEstados();

        pnlElijaPauta.Visible = PlantillaSeleccionada() <= 0;

        CargarGrid();
        Grid.DataBind();

        RenderDetalle();

        udPanel.Update();
    }

    /// <summary>Al cambiar la pauta se cierra el detalle abierto.</summary>
    protected void Filtro_Changed(object sender, EventArgs e)
    {
        if (sender == cboPlantilla) hidEjecucion.Value = "";
    }

    private int PlantillaSeleccionada()
    {
        int id;
        return int.TryParse(cboPlantilla.SelectedValue, out id) ? id : 0;
    }

    private void ConfigurarPlantillas()
    {
        if (cboPlantilla.Items.Count > 0) return;

        cboPlantilla.Items.Add(new RadComboBoxItem("Seleccione una pauta…", ""));
        List<ChecklistPlantilla> pautas = new ChecklistPlantillaController().GetChecklistPlantillas(
            new ChecklistPlantilla { cpl_cliente = SitioBase.Session.ClienteId() }) ?? new List<ChecklistPlantilla>();
        foreach (ChecklistPlantilla p in pautas)
            cboPlantilla.Items.Add(new RadComboBoxItem(p.cpl_nombre, p.cpl_id.ToString()));
    }

    /// <summary>Checklist_Ejecucion_Estado, catálogo fijo (bloque 159).</summary>
    private void ConfigurarEstados()
    {
        if (cboEstado.Items.Count > 0) return;
        cboEstado.Items.Add(new RadComboBoxItem("Todas (sin anuladas)", ""));
        cboEstado.Items.Add(new RadComboBoxItem("Enviada", "3"));
        cboEstado.Items.Add(new RadComboBoxItem("Validada", "4"));
        cboEstado.Items.Add(new RadComboBoxItem("Borrador", "1"));
        cboEstado.Items.Add(new RadComboBoxItem("Rechazada", "5"));
    }

    protected void CargarGrid()
    {
        int plantilla = PlantillaSeleccionada();
        if (plantilla <= 0) { Grid.DataSource = new List<ChecklistEjecucionHist>(); return; }

        int estado = 0;
        bool hayEstado = int.TryParse(cboEstado.SelectedValue, out estado);

        Grid.DataSource = new ChecklistCentroController().GetHistorial(
            plantilla, hayEstado ? (int?)estado : null) ?? new List<ChecklistEjecucionHist>();
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        ChecklistEjecucionHist o = item.DataItem as ChecklistEjecucionHist;
        if (o == null) return;

        DateTime? cuando = o.fin ?? o.inicio;
        item["FECHA"].Controls.Add(new Literal { Text = cuando == null ? "—" : cuando.Value.ToString("dd-MM-yyyy HH:mm") });

        item["EQUIPO"].Controls.Add(new Literal
        {
            Text = string.IsNullOrEmpty(o.activo_codigo)
                 ? "<span class=\"sigma-inv-vacio\">sin equipo</span>"
                 : Server.HtmlEncode(o.activo_codigo) + " <span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(o.activo_nombre) + "</span>"
        });

        item["VERSION"].Controls.Add(new Literal { Text = "<span class=\"sigma-inv-vacio\">v" + o.version_numero + "</span>" });

        string noconf = o.item_no_conforme > 0
            ? "<span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-alert\"></i>" + o.item_no_conforme + "</span>"
            : "<span class=\"grid-estado-chip is-exito\">0</span>";
        item["NOCONF"].Controls.Add(new Literal { Text = noconf });

        item["AVANCE"].Controls.Add(new Literal { Text = o.avance + "%" });

        item["ESTADO"].Controls.Add(new Literal { Text = ChipEstado(o.estado_codigo, o.estado_nombre) });

        item["DETALLE"].Controls.Add(new Literal
        {
            Text = "<a href=\"#\" class=\"icono_ver\" onclick=\"verDetalle(" + o.ejecucion_id + ");return false;\">Ver detalle</a>"
        });
    }

    /// <summary>
    /// CA-2: cada pregunta de la versión ejecutada con su respuesta, si salió de
    /// rango y sus fotografías. El id de la ejecución llega en hidEjecucion
    /// (lo pone el enlace «Ver detalle» antes del postback de la grilla).
    /// </summary>
    private void RenderDetalle()
    {
        int ejecucion;
        if (!int.TryParse(hidEjecucion.Value, out ejecucion) || ejecucion <= 0)
        {
            pnlDetalle.Visible = false;
            return;
        }

        ChecklistCentroController ctl = new ChecklistCentroController();
        List<ChecklistRespuesta> respuestas = ctl.GetRespuestas(ejecucion);
        List<ChecklistArchivo> fotos = ctl.GetEvidencias(ejecucion);

        StringBuilder s = new StringBuilder();
        s.Append("<h4 style=\"margin:0 0 10px;\">Detalle de la ejecución <span class=\"sigma-inv-vacio\">#")
         .Append(ejecucion).Append("</span></h4>");

        if (respuestas.Count == 0)
        {
            s.Append("<p class=\"sigma-inv-vacio\">Esta ejecución no tiene preguntas registradas.</p>");
        }
        else
        {
            string seccion = null;
            s.Append("<div class=\"sigma-hist-detalle\">");
            foreach (ChecklistRespuesta r in respuestas)
            {
                if (r.seccion != seccion)
                {
                    seccion = r.seccion;
                    s.Append("<h5 style=\"margin:14px 0 6px; color:#6C5CFF;\">")
                     .Append(Server.HtmlEncode(string.IsNullOrEmpty(seccion) ? "General" : seccion)).Append("</h5>");
                }

                s.Append("<div style=\"padding:8px 0; border-bottom:1px solid #eef0f4;\">");
                s.Append("<div><strong>").Append(Server.HtmlEncode(r.texto)).Append("</strong>");
                if (r.obligatorio) s.Append(" <span class=\"sg-req\">*</span>");
                s.Append("</div>");

                s.Append("<div style=\"margin-top:3px;\">");
                if (!r.respondido)
                    s.Append("<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-minus-circle-outline\"></i>Sin responder</span>");
                else
                {
                    if (r.no_aplica)
                        s.Append("<span class=\"grid-estado-chip is-neutro\">No aplica</span>");
                    else
                        s.Append("<strong>").Append(Server.HtmlEncode(string.IsNullOrEmpty(r.valor) ? "—" : r.valor))
                         .Append(string.IsNullOrEmpty(r.unidad) ? "" : " " + Server.HtmlEncode(r.unidad)).Append("</strong>");

                    if (r.fuera_rango)
                        s.Append(" <span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-alert\"></i>Fuera de rango (no conformidad)</span>");
                    else if (r.respondido && !r.no_aplica)
                        s.Append(" <span class=\"grid-estado-chip is-exito\">Conforme</span>");

                    if (r.evidencias > 0)
                        s.Append(" <span class=\"sigma-inv-vacio\"><i class=\"mdi mdi-camera\"></i> ").Append(r.evidencias).Append(" foto(s)</span>");
                }
                if (!string.IsNullOrEmpty(r.comentario))
                    s.Append("<div class=\"sigma-inv-vacio\" style=\"margin-top:2px;\">").Append(Server.HtmlEncode(r.comentario)).Append("</div>");
                s.Append("</div></div>");
            }
            s.Append("</div>");
        }

        if (fotos != null && fotos.Count > 0)
        {
            s.Append("<h5 style=\"margin:16px 0 6px;\">Fotografías (").Append(fotos.Count).Append(")</h5><div>");
            foreach (ChecklistArchivo f in fotos)
                s.Append("<span class=\"grid-estado-chip is-neutro\" style=\"margin:2px;\"><i class=\"mdi ")
                 .Append(f.es_imagen ? "mdi-image-outline" : (f.es_video ? "mdi-video-outline" : "mdi-file-outline"))
                 .Append("\"></i> ").Append(Server.HtmlEncode(f.etiqueta)).Append("</span>");
            s.Append("</div>");
        }

        litDetalle.Text = s.ToString();
        pnlDetalle.Visible = true;
    }

    private static string ChipEstado(string codigo, string nombre)
    {
        switch ((codigo ?? "").ToUpperInvariant())
        {
            case "VALIDADA":      return "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-check-decagram\"></i>" + nombre + "</span>";
            case "ENVIADA":       return "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-check-circle\"></i>" + nombre + "</span>";
            case "BORRADOR":      return "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-pencil-outline\"></i>" + nombre + "</span>";
            case "SINCRONIZANDO": return "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-sync\"></i>" + nombre + "</span>";
            case "RECHAZADA":     return "<span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-close-circle\"></i>" + nombre + "</span>";
            default:              return "<span class=\"grid-estado-chip is-neutro\">" + (nombre ?? "") + "</span>";
        }
    }
}
