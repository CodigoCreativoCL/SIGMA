using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Bandeja transversal de hallazgos de inspección (rediseño SIGMA-Pautas-360,
/// mockup 09). KPIs (pendientes / con OT / descartados), tabla propia y panel
/// de detalle. Las acciones (generar OT, descartar) y el Excel reusan el
/// ChecklistHallazgoController. El acceso lo resuelve el master por datos y el
/// cliente va siempre desde la sesión en el controlador.
/// </summary>
public partial class View_Mantenimiento_Hallazgos_ChecklistHallazgos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e) {
        // Rediseño de Mantenimiento en cinco lugares: esta lista vive ahora en su lugar nuevo.
        // «?legacy=1» abre la pantalla de antes mientras la pestaña nueva no la reemplace.
        if (!IsPostBack && Request.QueryString["legacy"] != "1")
        {
            Response.Redirect("~/View/Mantenimiento/Avisos/Avisos.aspx#avisos", false);
            Context.ApplicationInstance.CompleteRequest();
            return;
        } }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;
        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;
        if (!hayCliente) return;

        ConfigurarPlantas();
        ConfigurarCatalogos();

        List<ChecklistHallazgo> lista = new ChecklistHallazgoController().GetHallazgos(Filtro()) ?? new List<ChecklistHallazgo>();

        // KPIs.
        int pend = 0, conot = 0, desc = 0;
        foreach (ChecklistHallazgo h in lista)
        {
            if (h.orden_trabajo_id != null) conot++;
            else if (!string.IsNullOrEmpty(h.cha_motivo_descarte)) desc++;
            else if ((h.estado_codigo ?? "").ToUpperInvariant() == "PENDIENTE") pend++;
        }
        litKpiPend.Text = pend.ToString();
        litKpiOt.Text = conot.ToString();
        litKpiDesc.Text = desc.ToString();

        bool puedeResolver = Token.PuedeFuncion("Crear y editar");
        Render(lista, puedeResolver);

        udPanel.Update();
    }

    // ------------------------------------------------------------------ filtros
    private RadComboBox2 Cbo(string id) { return (RadComboBox2)wucFiltro.FindControl(id); }

    private void ConfigurarPlantas()
    {
        RadComboBox2 cbo = Cbo("cboPlanta");
        if (cbo == null) return;
        string seleccion = cbo.SelectedValue;

        List<ClienteInstalacion> plantas = new ClienteInstalacionController().GetClienteInstalaciones(
            new ClienteInstalacion { cin_cliente = SitioBase.Session.ClienteId() }) ?? new List<ClienteInstalacion>();

        cbo.Items.Clear();
        cbo.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
        foreach (ClienteInstalacion p in plantas) cbo.Items.Add(new RadComboBoxItem(p.cin_nombre, p.cin_id.ToString()));
        RadComboBoxItem item = cbo.FindItemByValue(seleccion ?? ""); if (item != null) item.Selected = true;
    }

    private void ConfigurarCatalogos()
    {
        RadComboBox2 sev = Cbo("cboSeveridad");
        if (sev != null && sev.Items.Count == 0)
        {
            sev.Items.Add(new RadComboBoxItem("Todas", ""));
            sev.Items.Add(new RadComboBoxItem("Crítica", "5"));
            sev.Items.Add(new RadComboBoxItem("Alta", "4"));
            sev.Items.Add(new RadComboBoxItem("Advertencia", "3"));
            sev.Items.Add(new RadComboBoxItem("Baja", "2"));
            sev.Items.Add(new RadComboBoxItem("Normal", "1"));
        }

        RadComboBox2 est = Cbo("cboEstado");
        if (est != null && est.Items.Count == 0)
        {
            est.Items.Add(new RadComboBoxItem("Todos", ""));
            est.Items.Add(new RadComboBoxItem("Pendiente", "1"));
            est.Items.Add(new RadComboBoxItem("En proceso", "2"));
            est.Items.Add(new RadComboBoxItem("Procesado", "3"));
            est.Items.Add(new RadComboBoxItem("Error", "4"));
            est.Items.Add(new RadComboBoxItem("Cancelado", "5"));
        }
    }

    private ChecklistHallazgo Filtro()
    {
        ChecklistHallazgo f = new ChecklistHallazgo();
        RadComboBox2 cboPlanta = Cbo("cboPlanta"), cboSev = Cbo("cboSeveridad"), cboEst = Cbo("cboEstado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) f.filtro = wucFiltro.Filtro();
        if (cboPlanta != null && cboPlanta.SelectedValue != "") f.filtro_instalacion = int.Parse(cboPlanta.SelectedValue);
        if (cboSev != null && cboSev.SelectedValue != "") f.filtro_severidad = int.Parse(cboSev.SelectedValue);
        if (cboEst != null && cboEst.SelectedValue != "") f.filtro_estado = int.Parse(cboEst.SelectedValue);
        return f;
    }

    // ------------------------------------------------------------------ render
    private void Render(List<ChecklistHallazgo> lista, bool puede)
    {
        string centro = ResolveUrl("~/View/Mantenimiento/Checklist/ChecklistCentro.aspx");
        if (lista.Count == 0)
        {
            litTabla.Text = "<div class='pc-vacio'><i class='mdi mdi-clipboard-check-outline'></i>No hay hallazgos que coincidan con el filtro.</div>";
            litDetalle.Text = "<div class='pc-vacio'><i class='mdi mdi-gesture-tap'></i>Selecciona un hallazgo para ver su detalle.</div>";
            return;
        }

        CultureInfo cul = new CultureInfo("es-CL");
        StringBuilder tb = new StringBuilder(), det = new StringBuilder();
        tb.Append("<table class='pc-table'><thead><tr><th>Código</th><th>Descripción</th><th>Severidad</th><th>Equipo</th><th>Pauta</th><th>Estado</th><th>Fecha</th><th class='acc'>Acciones</th></tr></thead><tbody>");

        bool first = true;
        foreach (ChecklistHallazgo h in lista)
        {
            string id = "H-" + h.cha_id.ToString("000");
            string activo = string.IsNullOrEmpty(h.activo_codigo) ? "—" : Server.HtmlEncode((h.activo_codigo + " · " + h.activo_nombre).Trim(' ', '·'));
            string pauta = string.IsNullOrEmpty(h.plantilla_nombre) ? "—" : Server.HtmlEncode(h.plantilla_nombre);
            string fecha = h.cha_fecha_creacion != null ? h.cha_fecha_creacion.Value.ToString("dd-MM-yyyy HH:mm", cul) : "—";
            string valor = h.respuesta_numero != null ? h.respuesta_numero.Value.ToString("0.####", cul) + (string.IsNullOrEmpty(h.respuesta_unidad) ? "" : " " + Server.HtmlEncode(h.respuesta_unidad)) : "";

            // Acciones por fila.
            string acc = "<a href='#' class='pc-btn out sm' onclick='return pcHzSel(" + h.cha_id + ")'>Ver detalle</a>";
            if (puede)
            {
                if (h.orden_trabajo_id != null)
                    acc = "<span class='pc-badge es-on'>OT #" + h.orden_trabajo_correlativo + "</span> " + acc;
                else if (!string.IsNullOrEmpty(h.cha_motivo_descarte))
                    acc = "<span class='pc-badge es-ret' title='" + Server.HtmlEncode(h.cha_motivo_descarte) + "'>Descartado</span> " + acc;
                else
                    acc += " <a href='#' class='pc-btn prim sm' onclick='return pcHzOT(" + h.cha_id + ")'><i class='mdi mdi-wrench-outline'></i>Generar OT</a>"
                         + " <a href='#' class='pc-btn danger sm' onclick='return pcHzDesc(" + h.cha_id + ")'>Descartar</a>";
            }

            tb.Append("<tr class='pc-hz-fila").Append(first ? " es-sel" : "").Append("' data-hz='").Append(h.cha_id).Append("'>")
              .Append("<td class='cod'><a href='#' onclick='return pcHzSel(").Append(h.cha_id).Append(")' style='color:inherit;text-decoration:none;'>").Append(id).Append("</a></td>")
              .Append("<td>").Append(Server.HtmlEncode(h.cha_titulo)).Append("</td>")
              .Append("<td>").Append(SevBadge(h.severidad_nombre)).Append("</td>")
              .Append("<td>").Append(activo).Append("</td>")
              .Append("<td>").Append(pauta).Append("</td>")
              .Append("<td>").Append(EstBadge(h.estado_codigo, h.estado_nombre)).Append("</td>")
              .Append("<td>").Append(fecha).Append("</td>")
              .Append("<td class='acc'>").Append(acc).Append("</td></tr>");

            // Detalle.
            det.Append("<div class='pc-hz-det").Append(first ? " es-sel" : "").Append("' data-hzdet='").Append(h.cha_id).Append("'>");
            det.Append("<div class='pc-hz-h'><div style='font-weight:800;color:var(--muted);font-size:12px;'>").Append(id).Append("</div>")
               .Append(EstBadge(h.estado_codigo, h.estado_nombre)).Append("</div>");
            det.Append("<div style='font-size:16px;font-weight:800;color:var(--ink);margin:4px 0 2px;'>").Append(Server.HtmlEncode(h.cha_titulo)).Append("</div>");
            det.Append("<div class='pc-hz-meta'>")
               .Append("<span><i class='mdi mdi-clipboard-outline'></i>").Append(pauta).Append("</span>")
               .Append("<span><i class='mdi mdi-cube-outline'></i>").Append(activo).Append("</span>")
               .Append("<span><i class='mdi mdi-calendar-outline'></i>").Append(fecha).Append("</span>")
               .Append("<span><i class='mdi mdi-account-outline'></i>").Append(string.IsNullOrEmpty(h.ejecutor_nombre) ? "—" : Server.HtmlEncode(h.ejecutor_nombre)).Append("</span></div>");

            det.Append("<div style='font-weight:800;color:var(--ink);font-size:13px;margin-bottom:10px;'>Detalle de la respuesta</div>");
            det.Append("<div class='pc-hz-grid'>")
               .Append("<div><div class='k'>Valor medido</div><div class='v'>").Append(valor == "" ? "—" : valor).Append("</div></div>")
               .Append("<div><div class='k'>Severidad</div><div class='v sm'>").Append(SevBadge(h.severidad_nombre)).Append("</div></div>")
               .Append("</div>");
            if (!string.IsNullOrEmpty(h.cha_descripcion))
                det.Append("<div style='margin-bottom:14px;'><div class='k' style='font-size:11px;color:var(--muted);text-transform:uppercase;margin-bottom:3px;'>Descripción</div><div style='font-size:13px;color:#384357;line-height:1.5;'>").Append(Server.HtmlEncode(h.cha_descripcion)).Append("</div></div>");
            if (!string.IsNullOrEmpty(h.cha_motivo_descarte))
                det.Append("<div class='pc-info-card' style='background:#EEF1F6;border-color:var(--line);margin-bottom:12px;'><div class='t' style='color:var(--muted);'><i class='mdi mdi-close-circle-outline' style='color:var(--muted);'></i>Descartado</div><p>").Append(Server.HtmlEncode(h.cha_motivo_descarte)).Append("</p></div>");
            if (h.orden_trabajo_id != null)
                det.Append("<div class='pc-info-card' style='background:#E7F4EE;border-color:#BBE4CE;margin-bottom:12px;'><div class='t' style='color:#16855B;'><i class='mdi mdi-wrench-outline' style='color:#16855B;'></i>OT vinculada #").Append(h.orden_trabajo_correlativo).Append("</div><p>Generar OT vincula el trabajo; no resuelve automáticamente el hallazgo.</p></div>");

            // "Abrir pauta" lleva al centro de ESA pauta (si se conoce su id); el centro
            // lee ?query=Encrypt("Id=<plantilla>") y abre su ficha directamente.
            string urlPauta = h.plantilla_id > 0
                ? centro + "?query=" + Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + h.plantilla_id))
                : centro;
            det.Append("<div class='pc-hz-acc'>")
               .Append("<a href='").Append(urlPauta).Append("' class='pc-btn out'><i class='mdi mdi-clipboard-outline'></i>Abrir pauta</a>");
            if (puede && h.orden_trabajo_id == null && string.IsNullOrEmpty(h.cha_motivo_descarte))
                det.Append("<a href='#' class='pc-btn prim' onclick='return pcHzOT(").Append(h.cha_id).Append(")'><i class='mdi mdi-wrench-outline'></i>Generar OT</a>");
            det.Append("</div>");
            det.Append("</div>");
            first = false;
        }
        tb.Append("</tbody></table>");
        litTabla.Text = tb.ToString();
        litDetalle.Text = det.ToString();
    }

    private string SevBadge(string sev)
    {
        if (string.IsNullOrEmpty(sev)) return "<span class='pc-badge es-ret'>—</span>";
        string s = sev.ToLower();
        string style = (s.Contains("crít") || s.Contains("crit") || s.Contains("alta")) ? "background:#FBEBEA;color:#C7352B;"
                     : s.Contains("advert") || s.Contains("media") ? "background:#FBF0E3;color:#B65C00;" : "background:#EAF4FF;color:#087BEA;";
        return "<span class='pc-badge' style='" + style + "'>" + Server.HtmlEncode(sev) + "</span>";
    }

    private string EstBadge(string codigo, string nombre)
    {
        string txt = Server.HtmlEncode(string.IsNullOrEmpty(nombre) ? (codigo ?? "") : nombre);
        switch ((codigo ?? "").ToUpperInvariant())
        {
            case "PENDIENTE": return "<span class='pc-badge' style='background:#FBEBEA;color:#C7352B;'>" + txt + "</span>";
            case "PROCESADO": return "<span class='pc-badge es-pub'>" + txt + "</span>";
            case "EN PROCESO": return "<span class='pc-badge es-bor'>" + txt + "</span>";
            case "CANCELADO": return "<span class='pc-badge es-ret'>" + txt + "</span>";
            default: return "<span class='pc-badge es-ret'>" + txt + "</span>";
        }
    }

    // ------------------------------------------------------------------ acciones
    protected void lnkRecargar_Click(object sender, EventArgs e) { /* el PreRender repinta */ }

    protected void btnGenerarOT_Click(object sender, EventArgs e)
    {
        Accion("CREAR ORDEN TRABAJO", id => new ChecklistHallazgoController().GenerarOrden(id));
    }

    protected void btnDescartar_Click(object sender, EventArgs e)
    {
        string motivo = (hdnMotivo.Value ?? "").Trim();
        Accion("CREAR ORDEN TRABAJO", id => new ChecklistHallazgoController().Descartar(id, motivo));
        hdnMotivo.Value = "";
    }

    private void Accion(string permiso, Func<int, Respuesta> accion)
    {
        try
        {
            if (!Token.Puede(permiso)) { Tools.tools.ClientAlert("No tiene permiso para resolver hallazgos.", "alerta"); return; }
            int id; if (!int.TryParse(hdnAccionId.Value, out id) || id <= 0) { Tools.tools.ClientAlert("No se identificó el hallazgo.", "alerta"); return; }
            Respuesta r = accion(id);
            Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    protected void lnkDescargar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("VER HALLAZGOS")) throw new Exception("No tiene permiso para ver hallazgos.");
            new ChecklistHallazgoController().Exportar(Filtro());
        }
        catch (System.Threading.ThreadAbortException) { throw; }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }
}
