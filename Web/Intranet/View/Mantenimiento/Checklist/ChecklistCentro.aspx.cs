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
/// Centro de Pauta de inspección 360 (rediseño SIGMA-Pautas-360, Fase 1).
///
/// Una sola pantalla: el listado de pautas y, al abrir una, su centro con
/// pestañas (Resumen · Configuración · Estructura · Versiones · Programaciones ·
/// Ocurrencias y ejecuciones · Hallazgos). Mantiene el topbar y el sidebar del
/// sistema (Default.master) y reusa la cáscara del centro del activo.
///
/// FASE 1: cáscara + listado + Resumen (con datos reales). Las otras seis
/// pestañas quedan como marcador; se llenan en las fases siguientes. No se
/// borran menús, permisos ni endpoints: la navegación se consolida por encima.
/// </summary>
public partial class View_Mantenimiento_Checklist_ChecklistCentro : System.Web.UI.Page
{
    /// <summary>Pauta abierta (cpl_id). 0 = mostrar el listado.</summary>
    public int Plantilla
    {
        get { int v; return int.TryParse(hdnPlantilla.Value, out v) ? v : 0; }
        set { hdnPlantilla.Value = value.ToString(); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        // Enlace directo: ?query cifrado con Id de la pauta (para las
        // redirecciones de los accesos históricos).
        if (!IsPostBack && Request.QueryString["query"] != null)
        {
            int id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
            if (id > 0) Plantilla = id;
        }
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack) return;
        RadComboBox2 c = sender as RadComboBox2;
        if (c == null || c.ID != "cboPlanta") return;

        c.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
        List<ChecklistPlantilla> lista = new ChecklistPlantillaController()
            .GetChecklistPlantillas(new ChecklistPlantilla { filtro_cliente = SitioBase.Session.ClienteId() });

        HashSet<int> vistos = new HashSet<int>();
        if (lista != null)
            foreach (ChecklistPlantilla p in lista)
                if (p.cpl_cliente_instalacion != null && !string.IsNullOrEmpty(p.planta_nombre)
                    && vistos.Add(p.cpl_cliente_instalacion.Value))
                    c.Items.Add(new RadComboBoxItem(p.planta_nombre, p.cpl_cliente_instalacion.ToString()));
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;
        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;
        if (!hayCliente) return;

        hlHallazgos.NavigateUrl = ResolveUrl("~/View/Mantenimiento/Hallazgos/ChecklistHallazgos.aspx");

        if (Plantilla > 0)
        {
            pnlLista.Visible = false;
            pnlFicha.Visible = true;
            CargarFicha();
        }
        else
        {
            pnlFicha.Visible = false;
            pnlLista.Visible = true;
            CargarLista();
        }

        udPanel.Update();
    }

    // =====================================================================
    // LISTADO
    // =====================================================================
    protected void CargarLista()
    {
        ChecklistPlantilla filtro = new ChecklistPlantilla();
        filtro.filtro_cliente = SitioBase.Session.ClienteId();

        int inst;
        if (cboPlanta.SelectedValue != "" && int.TryParse(cboPlanta.SelectedValue, out inst))
            filtro.filtro_cliente_instalacion = inst;
        if (cboEstado.SelectedValue != "")
            filtro.filtro_habilitado = cboEstado.SelectedValue == "1";

        List<ChecklistPlantilla> lista = new ChecklistPlantillaController().GetChecklistPlantillas(filtro)
                                         ?? new List<ChecklistPlantilla>();

        // Versión publicada por pauta (una consulta, no una por fila).
        Dictionary<int, int> publicadas = new Dictionary<int, int>();
        List<ChecklistVersion> pubs = new ChecklistVersionController().GetPublicadas(SitioBase.Session.ClienteId());
        if (pubs != null)
            foreach (ChecklistVersion v in pubs)
                if (!publicadas.ContainsKey(v.cpv_checklist_plantilla))
                    publicadas[v.cpv_checklist_plantilla] = v.cpv_numero;

        pnlListaVacia.Visible = lista.Count == 0;

        StringBuilder sb = new StringBuilder();
        sb.Append("<div id='sgPautaLista' class='sg-pc-lista'>");
        // Cabecera de columnas.
        sb.Append("<div class='sg-ot-fila' style='font-size:11px;font-weight:700;color:#64748b;text-transform:uppercase;letter-spacing:.03em;border:none;'>")
          .Append("<span style='flex:0 0 150px;'>Código</span>")
          .Append("<span style='flex:1;'>Nombre</span>")
          .Append("<span style='flex:0 0 120px;'>Alcance</span>")
          .Append("<span style='flex:0 0 140px;'>Versión</span>")
          .Append("<span style='flex:0 0 120px;'>Estado</span>")
          .Append("<span style='flex:0 0 110px;text-align:right;'>Acciones</span>")
          .Append("</div>");

        foreach (ChecklistPlantilla p in lista)
        {
            string verBadge = publicadas.ContainsKey(p.cpl_id)
                ? "<span class='pc-badge es-ver'>v" + publicadas[p.cpl_id] + "</span> <span class='pc-badge es-pub'>Publicada</span>"
                : "<span class='pc-badge es-bor'>Sin publicar</span>";
            string estadoBadge = p.cpl_habilitado
                ? "<span class='pc-badge es-on'>Habilitada</span>"
                : "<span class='pc-badge es-off'>Deshabilitada</span>";
            string alcance = string.IsNullOrEmpty(p.planta_nombre) ? "Todas" : Server.HtmlEncode(p.planta_nombre);
            string buscar = Server.HtmlEncode((p.cpl_codigo + " " + p.cpl_nombre + " " + (p.cpl_descripcion ?? "")).ToLower());

            sb.Append("<div class='sg-ot-fila' data-buscar='").Append(buscar).Append("' ")
              .Append("style='display:flex;align-items:center;gap:12px;padding:12px 8px;border-top:1px solid #eef0f4;font-size:13px;'>")
              .Append("<span style='flex:0 0 150px;font-weight:700;color:#0f172a;'>").Append(Server.HtmlEncode(p.cpl_codigo)).Append("</span>")
              .Append("<span style='flex:1;color:#0f172a;'>").Append(Server.HtmlEncode(p.cpl_nombre)).Append("</span>")
              .Append("<span style='flex:0 0 120px;color:#475569;'>").Append(alcance).Append("</span>")
              .Append("<span style='flex:0 0 140px;'>").Append(verBadge).Append("</span>")
              .Append("<span style='flex:0 0 120px;'>").Append(estadoBadge).Append("</span>")
              .Append("<span style='flex:0 0 110px;text-align:right;'>")
              .Append("<a href='#' class='sg-ot-btn es-plano' onclick=\"return abrirCentro(").Append(p.cpl_id).Append(")\"><i class='mdi mdi-open-in-new'></i>Abrir</a>")
              .Append("</span></div>");
        }
        sb.Append("</div>");
        litLista.Text = lista.Count == 0 ? "" : sb.ToString();
    }

    // =====================================================================
    // CENTRO DE LA PAUTA
    // =====================================================================
    protected void CargarFicha()
    {
        int cliente = SitioBase.Session.ClienteId();
        ChecklistPlantilla pla = new ChecklistPlantillaController().GetChecklistPlantilla(Plantilla);
        if (pla == null || pla.cpl_id <= 0) { Plantilla = 0; pnlFicha.Visible = false; pnlLista.Visible = true; CargarLista(); return; }

        // Versión publicada (número + conteos).
        List<ChecklistVersion> versiones = new ChecklistVersionController().GetVersiones(Plantilla, cliente) ?? new List<ChecklistVersion>();
        ChecklistVersion pub = versiones.Find(v => v.cpv_estado == 2);
        ChecklistVersion actual = pub ?? (versiones.Count > 0 ? versiones[0] : null);

        // ---- Hero + miga ----
        litMiga.Text = Server.HtmlEncode(pla.cpl_codigo);
        litHeroNombre.Text = Server.HtmlEncode(pla.cpl_nombre);
        string alcance = string.IsNullOrEmpty(pla.planta_nombre) ? "Todas las plantas" : Server.HtmlEncode(pla.planta_nombre);
        string badges = "";
        if (actual != null)
            badges = " <span class='pc-badge es-ver'>v" + actual.cpv_numero + "</span> "
                   + (actual.cpv_estado == 2 ? "<span class='pc-badge es-pub'>Publicada</span>"
                      : actual.cpv_estado == 3 ? "<span class='pc-badge es-ret'>Retirada</span>"
                      : "<span class='pc-badge es-bor'>Borrador</span>");
        badges += pla.cpl_habilitado ? " <span class='pc-badge es-on'>Habilitada</span>" : " <span class='pc-badge es-off'>Deshabilitada</span>";
        litHeroSub.Text = "<b>" + Server.HtmlEncode(pla.cpl_codigo) + "</b> · " + alcance + badges;

        string queryEditar = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + pla.cpl_id));
        hlEditar.NavigateUrl = "javascript:void(0)";
        hlEditar.Attributes["onclick"] = "return abrirPauta('" + queryEditar + "')";

        // ---- Aviso si está deshabilitada ----
        litResumenAviso.Text = pla.cpl_habilitado ? "" :
            "<div class='sg-ot-aviso'><i class='mdi mdi-information-outline'></i>" +
            "<div><b>Pauta deshabilitada.</b> Revisa la habilitación y la programación antes de realizar nuevas ejecuciones.</div></div>";

        // ---- Ocurrencias (para KPIs) ----
        List<ChecklistOcurrencia> ocs = new ChecklistCentroController().GetOcurrencias(Plantilla) ?? new List<ChecklistOcurrencia>();
        DateTime ahora = DateTime.UtcNow;

        int exigibles = 0, cumplidas = 0, hallazgos = 0;
        ChecklistOcurrencia ultima = null, proxima = null;
        foreach (ChecklistOcurrencia o in ocs)
        {
            hallazgos += o.hallazgos;
            bool cancelada = (o.estado_codigo ?? "").ToUpper().Contains("CANCEL");
            // Exigible: su fecha prevista ya pasó y no fue cancelada.
            if (o.prevista != null && o.prevista.Value <= ahora && !cancelada)
            {
                exigibles++;
                if (o.ejecutada) cumplidas++;
            }
            // Última ejecutada (por fin).
            if (o.ejecutada && (ultima == null || (o.fin ?? DateTime.MinValue) > (ultima.fin ?? DateTime.MinValue)))
                ultima = o;
            // Próxima pendiente futura.
            if (o.prevista != null && o.prevista.Value > ahora && !cancelada && !o.ejecutada
                && (proxima == null || o.prevista.Value < proxima.prevista.Value))
                proxima = o;
        }
        int cumplimiento = exigibles > 0 ? (int)Math.Round(cumplidas * 100.0 / exigibles) : 0;

        // ---- KPIs (tarjetas) ----
        StringBuilder k = new StringBuilder();
        k.Append("<div class='sg-a3-kpis'>");
        k.Append(Kpi("mdi-chart-donut", cumplimiento + "%", "Cumplimiento",
            exigibles > 0 ? (cumplidas + " de " + exigibles + " ocurrencias exigibles completadas") : "Sin ocurrencias exigibles aún"));
        k.Append(Kpi("mdi-calendar-check", ultima != null && ultima.fin != null ? ultima.fin.Value.ToString("dd MMM yyyy", new CultureInfo("es-CL")) : "—",
            "Última ronda", ultima != null && ultima.fin != null ? ultima.fin.Value.ToString("HH:mm") : "Sin ejecuciones"));
        k.Append(Kpi("mdi-alert-outline", hallazgos.ToString(), "Hallazgos registrados", hallazgos == 1 ? "1 hallazgo en sus ejecuciones" : hallazgos + " hallazgos en sus ejecuciones"));
        k.Append(Kpi("mdi-calendar-clock", proxima != null && proxima.prevista != null ? proxima.prevista.Value.ToString("dd MMM yyyy", new CultureInfo("es-CL")) : "Sin programar",
            "Próxima ocurrencia", proxima != null ? "Programada" : "No hay ocurrencias futuras"));
        k.Append("</div>");
        k.Append("<div class='sg-ot-nota'><i class='mdi mdi-information-outline'></i> El cumplimiento excluye ocurrencias futuras y canceladas, y no equivale al resultado técnico de las inspecciones.</div>");
        litKpis.Text = k.ToString();

        // ---- Última ejecución ----
        if (ultima != null)
        {
            litUltima.Text = "<div style='padding:6px 4px;'>" +
                "<div style='font-weight:700;color:#0f172a;'>" + Server.HtmlEncode(ultima.donde) + "</div>" +
                "<div style='color:#64748b;font-size:12.5px;margin-top:4px;'>" +
                (ultima.fin != null ? ultima.fin.Value.ToString("dd MMM yyyy HH:mm", new CultureInfo("es-CL")) : "") +
                (string.IsNullOrEmpty(ultima.ejecutor) ? "" : " · " + Server.HtmlEncode(ultima.ejecutor)) + "</div>" +
                "<div style='margin-top:6px;'><span class='pc-badge es-pub'>" + Server.HtmlEncode(string.IsNullOrEmpty(ultima.estado_nombre) ? "Completada" : ultima.estado_nombre) + "</span></div>" +
                "</div>";
        }
        else litUltima.Text = "<div class='sg-ot-vacio-min'>Esta pauta todavía no tiene ejecuciones.</div>";

        // ---- Hallazgos ----
        litHallazgos.Text = hallazgos > 0
            ? "<div style='padding:6px 4px;color:#0f172a;'>Hay <b>" + hallazgos + "</b> hallazgo" + (hallazgos == 1 ? "" : "s") + " registrado" + (hallazgos == 1 ? "" : "s") + " en las ejecuciones de esta pauta.</div>"
            : "<div class='sg-ot-vacio-min'>Sin hallazgos registrados.</div>";

        // ---- Información general ----
        litInfo.Text =
            InfoFila("mdi-map-marker-outline", "Alcance", string.IsNullOrEmpty(pla.planta_nombre) ? "Todas las plantas" : Server.HtmlEncode(pla.planta_nombre)) +
            InfoFila("mdi-cube-outline", "Tipo de activo", string.IsNullOrEmpty(pla.activo_tipo_nombre) ? "Cualquiera" : Server.HtmlEncode(pla.activo_tipo_nombre)) +
            InfoFila("mdi-account-group-outline", "Asignación", string.IsNullOrEmpty(pla.asignacion_tipo_nombre) ? "Sin definir" : Server.HtmlEncode(pla.asignacion_tipo_nombre));

        // ---- Versión actual ----
        if (actual != null)
        {
            string est = actual.cpv_estado == 2 ? "<span class='pc-badge es-pub'>Publicada</span>"
                       : actual.cpv_estado == 3 ? "<span class='pc-badge es-ret'>Retirada</span>"
                       : "<span class='pc-badge es-bor'>Borrador</span>";
            litVersion.Text =
                "<div style='display:flex;align-items:center;gap:10px;padding:4px 4px 8px;'><i class='mdi mdi-cube-outline' style='font-size:20px;color:#6d28d9;'></i>" +
                "<span style='font-weight:800;font-size:18px;color:#0f172a;'>v" + actual.cpv_numero + "</span>" + est + "</div>" +
                InfoFila("mdi-format-list-bulleted", "Secciones", actual.secciones.ToString()) +
                InfoFila("mdi-checkbox-marked-outline", "Ítems", actual.items.ToString());
        }
        else litVersion.Text = "<div class='sg-ot-vacio-min'>Esta pauta todavía no tiene versiones.</div>";
    }

    private string Kpi(string icono, string valor, string titulo, string sub)
    {
        return "<div class='sg-a3-kpi'><span class='sg-a3-kpi-ico'><i class='mdi " + icono + "'></i></span>" +
               "<div class='sg-a3-kpi-txt'><b>" + valor + "</b><span>" + Server.HtmlEncode(titulo) + "</span>" +
               "<em style='display:block;color:#94a3b8;font-style:normal;font-size:11.5px;margin-top:2px;'>" + Server.HtmlEncode(sub) + "</em></div></div>";
    }

    private string InfoFila(string icono, string k, string v)
    {
        return "<div style='display:flex;align-items:center;gap:10px;padding:7px 4px;font-size:13px;border-top:1px solid #f1f5f9;'>" +
               "<i class='mdi " + icono + "' style='color:#94a3b8;font-size:17px;'></i>" +
               "<span style='color:#64748b;flex:0 0 110px;'>" + Server.HtmlEncode(k) + "</span>" +
               "<span style='color:#0f172a;font-weight:600;'>" + v + "</span></div>";
    }

    protected void lnkRecargar_Click(object sender, EventArgs e) { /* el PreRender repinta según hdnPlantilla */ }
    protected void lnkVolver_Click(object sender, EventArgs e) { Plantilla = 0; }

    /// <summary>URL de un asset con cache-busting por fecha del archivo.</summary>
    protected string Asset(string ruta)
    {
        string url = ResolveUrl(ruta);
        try
        {
            string fisica = Server.MapPath(ruta);
            if (System.IO.File.Exists(fisica))
                return url + "?v=" + System.IO.File.GetLastWriteTimeUtc(fisica).Ticks;
        }
        catch (Exception) { }
        return url;
    }
}
