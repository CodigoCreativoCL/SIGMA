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
        sb.Append("<table class='pc-table' id='sgPautaLista'><thead><tr>")
          .Append("<th>Código</th><th>Nombre</th><th>Alcance</th><th>Versión</th><th>Estado</th><th class='acc'>Acciones</th>")
          .Append("</tr></thead><tbody>");

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

            sb.Append("<tr class='pc-fila' data-buscar='").Append(buscar).Append("'>")
              .Append("<td class='cod'>").Append(Server.HtmlEncode(p.cpl_codigo)).Append("</td>")
              .Append("<td class='nom'>").Append(Server.HtmlEncode(p.cpl_nombre)).Append("</td>")
              .Append("<td>").Append(alcance).Append("</td>")
              .Append("<td>").Append(verBadge).Append("</td>")
              .Append("<td>").Append(estadoBadge).Append("</td>")
              .Append("<td class='acc'><a href='#' class='pc-btn out' onclick=\"return abrirCentro(").Append(p.cpl_id).Append(")\"><i class='mdi mdi-open-in-new'></i>Abrir</a></td>")
              .Append("</tr>");
        }
        sb.Append("</tbody></table>");
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

        // Programaciones: se usan aquí (Estado y ejecución) y en su pestaña.
        List<ChecklistProgramacion> progs = new ChecklistProgramacionController()
            .GetProgramaciones(new ChecklistProgramacion { filtro_cliente = cliente, filtro_checklist_plantilla = Plantilla })
            ?? new List<ChecklistProgramacion>();
        bool hayProgActiva = progs.Exists(p => p.cpr_habilitado);

        CultureInfo esCL = new CultureInfo("es-CL");
        string mes = DateTime.Now.ToString("MMMM yyyy", esCL);
        if (mes.Length > 0) mes = char.ToUpper(mes[0]) + mes.Substring(1);

        // ---- KPIs (como el mockup 02: anillo de cumplimiento + tarjetas) ----
        StringBuilder k = new StringBuilder();
        k.Append("<div class='sg-pc-ind'><h4>Indicadores · ").Append(mes).Append("</h4>")
         .Append("<a href='#' data-ir-sec='ocurrencias'>Ver detalle →</a></div>");
        k.Append("<div class='sg-a3-kpis'>");

        string ring = cumplimiento >= 80 ? "var(--success)" : cumplimiento >= 50 ? "var(--warning)" : "#C7352B";
        k.Append("<div class='sg-a3-kpi'><span class='pc-donut' style='background:conic-gradient(")
         .Append(ring).Append(" ").Append(cumplimiento).Append("%, var(--line) 0);'><span class='pc-donut-in'>")
         .Append(cumplimiento).Append("%</span></span><div class='sg-a3-kpi-txt'><span>Cumplimiento</span><b style='font-size:14px;'>")
         .Append(exigibles > 0 ? (cumplidas + " de " + exigibles + " completadas") : "Sin exigibles").Append("</b></div></div>");

        k.Append(Kpi("mdi-calendar-check", "", "Última ronda",
            ultima != null && ultima.fin != null ? ultima.fin.Value.ToString("dd MMM yyyy", esCL) : "—",
            ultima != null && ultima.fin != null ? ultima.fin.Value.ToString("HH:mm") : "Sin ejecuciones"));
        k.Append(Kpi("mdi-alert-outline", hallazgos > 0 ? "es-alerta" : "", "Hallazgos", hallazgos.ToString(),
            hallazgos == 1 ? "1 en sus ejecuciones" : hallazgos + " en sus ejecuciones"));
        k.Append(Kpi("mdi-calendar-clock", "es-info", "Próxima ocurrencia",
            proxima != null && proxima.prevista != null ? proxima.prevista.Value.ToString("dd MMM yyyy", esCL) : "Sin programar",
            proxima != null ? "Programada" : "No hay futuras"));
        k.Append("</div>");
        k.Append("<div class='sg-ot-nota'><i class='mdi mdi-information-outline'></i> El cumplimiento excluye ocurrencias futuras y canceladas, y no equivale al resultado técnico de las inspecciones.</div>");
        litKpis.Text = k.ToString();

        // ---- Estado y ejecución (tarjeta lateral del mockup 02) ----
        string ee = "<div class='sg-pc-ee'>";
        ee += "<div class='l'>" + (pla.cpl_habilitado ? "<span class='pc-badge es-on'>Habilitada</span>" : "<span class='pc-badge es-off'>Deshabilitada</span>") + "</div>";
        ee += "<div class='l'><i class='mdi mdi-calendar-clock'></i>" + (hayProgActiva ? "Con programación activa" : "Sin programación activa") + "</div>";
        if (!pla.cpl_habilitado || !hayProgActiva)
            ee += "<div style='margin-top:4px;'>Para realizar ejecuciones, la pauta debe estar habilitada y contar con una programación.</div>";
        ee += "</div>";
        litEstadoEjec.Text = ee;

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

        // ---- Pestaña CONFIGURACIÓN (formulario editable, mockup 03) ----
        bool puedeCfg = Token.Puede("CREAR EDITAR PAUTAS");
        txtCodigoCfg.Text = pla.cpl_codigo;
        txtCodigoCfg.ReadOnly = true;                     // el código no se edita tras el alta
        txtNombreCfg.Text = pla.cpl_nombre;
        txtNombreCfg.ReadOnly = !puedeCfg;
        txtDescripcionCfg.Text = pla.cpl_descripcion;
        txtDescripcionCfg.ReadOnly = !puedeCfg;
        chkHabilitadaCfg.Checked = pla.cpl_habilitado;
        chkHabilitadaCfg.Enabled = puedeCfg;

        int clienteCfg = cliente;
        BindComboInstalacion(cboPlantaCfg, clienteCfg, pla.cpl_cliente_instalacion);
        BindComboActivoTipo(cboActivoTipoCfg, clienteCfg, pla.cpl_activo_tipo);
        BindComboAsignacion(cboAsignacionCfg, pla.cpl_checklist_asignacion_tipo);
        cboPlantaCfg.Enabled = puedeCfg; cboActivoTipoCfg.Enabled = puedeCfg; cboAsignacionCfg.Enabled = puedeCfg;

        litCfgId.Text = pla.cpl_id.ToString();
        litCfgCreado.Text = pla.cpl_fecha_creacion != null
            ? pla.cpl_fecha_creacion.Value.ToString("dd MMM yyyy HH:mm", new CultureInfo("es-CL")) : "—";
        btnGuardarCfg.Visible = puedeCfg;

        // ---- Pestaña ESTRUCTURA (solo lectura de la versión actual) ----
        hlEditarEstructura.NavigateUrl = "javascript:void(0)";
        hlEditarEstructura.Attributes["onclick"] = "return abrirPauta('" + queryEditar + "')";
        hlEditarEstructura.Visible = Token.Puede("CREAR EDITAR PAUTAS");
        // Umbrales (validaciones) y dependencias: ya no están en el menú; se
        // gestionan desde aquí (sus pantallas filtran por pauta).
        hlUmbrales.NavigateUrl = ResolveUrl("~/View/Mantenimiento/Checklist/ChecklistItemValidacions.aspx");
        hlDependencias.NavigateUrl = ResolveUrl("~/View/Mantenimiento/Checklist/ChecklistItemDependencias.aspx");
        RenderEstructura(actual != null ? actual.cpv_id : 0,
                         actual != null ? actual.cpv_numero : 0,
                         actual != null ? actual.cpv_estado : 0);

        // ---- Pestaña VERSIONES (mockup 05) ----
        hlNuevaVersion.NavigateUrl = "javascript:void(0)";
        hlNuevaVersion.Attributes["onclick"] = "return abrirPauta('" + queryEditar + "')";
        hlNuevaVersion.Visible = Token.Puede("CREAR EDITAR PAUTAS");
        litVersiones.Text = RenderVersiones(versiones);
        ChecklistVersion borrador = versiones.Find(v => v.cpv_estado == 1);
        lnkPublicar.Visible = borrador != null && Token.Puede("CREAR EDITAR PAUTAS");
        int progActivas = progs.FindAll(pp => pp.cpr_habilitado).Count;
        litPublicacion.Text = RenderPublicacion(borrador, pub, progActivas);
        if (borrador != null && pub != null) { pnlComparacion.Visible = true; litComparacion.Text = RenderComparacion(pub, borrador); }
        else pnlComparacion.Visible = false;

        // ---- Pestaña PROGRAMACIONES ----
        hlNuevaProg.NavigateUrl = "javascript:void(0)";
        hlNuevaProg.Attributes["onclick"] = "return abrirProgramacion(0)";
        hlNuevaProg.Visible = Token.Puede("CREAR EDITAR PAUTAS");
        RenderProgramaciones(progs);

        // Hallazgos de la pauta (se usan en Ocurrencias y en su propia pestaña).
        hlBandeja.NavigateUrl = ResolveUrl("~/View/Mantenimiento/Hallazgos/ChecklistHallazgos.aspx");
        List<ChecklistHallazgo> hall = new ChecklistHallazgoController().GetHallazgos(new ChecklistHallazgo()) ?? new List<ChecklistHallazgo>();
        // El SP de hallazgos no filtra por pauta; se acota aquí por su código
        // (único dentro del cliente, y el SP ya viene acotado al cliente).
        List<ChecklistHallazgo> mios = hall.FindAll(h => h.plantilla_codigo == pla.cpl_codigo);

        // ---- Pestaña OCURRENCIAS Y EJECUCIONES (mockup 07: master-detalle) ----
        RenderOcurrenciasMaster(ocs, mios);

        // ---- Pestaña HALLAZGOS DE LA PAUTA (mockup 08: master-detalle) ----
        RenderHallazgos(mios);
    }

    private string SevBadge(string sev)
    {
        if (string.IsNullOrEmpty(sev)) return "—";
        string s = sev.ToLower();
        string style = (s.Contains("alta") || s.Contains("crít") || s.Contains("crit")) ? "background:#FBEBEA;color:#C7352B;"
                     : s.Contains("media") ? "background:#FBF0E3;color:#B65C00;" : "background:#EAF4FF;color:#087BEA;";
        return "<span class='pc-badge' style='" + style + "'>" + Server.HtmlEncode(sev) + "</span>";
    }

    /// <summary>Hallazgos de la pauta (mockup 08): lista (izq) + detalle (der).</summary>
    private void RenderHallazgos(List<ChecklistHallazgo> hs)
    {
        string bandeja = ResolveUrl("~/View/Mantenimiento/Hallazgos/ChecklistHallazgos.aspx");
        if (hs == null || hs.Count == 0)
        {
            litHallazgosPauta.Text = "<div class='pc-vacio'><i class='mdi mdi-clipboard-check-outline'></i>Esta pauta no tiene hallazgos registrados.</div>";
            litHallazgoDet.Text = "<div class='pc-vacio'><i class='mdi mdi-gesture-tap'></i>Cuando haya hallazgos, aquí verás su detalle.</div>";
            return;
        }

        CultureInfo cul = new CultureInfo("es-CL");
        StringBuilder tb = new StringBuilder(), det = new StringBuilder();
        tb.Append("<table class='pc-table'><thead><tr><th>ID</th><th>Descripción</th><th>Activo</th><th>Valor</th><th>Severidad</th><th>Estado</th><th>Fecha</th><th>Reporta</th><th></th></tr></thead><tbody>");

        bool first = true;
        foreach (ChecklistHallazgo h in hs)
        {
            string id = "H-" + h.cha_id.ToString("000");
            string activo = Server.HtmlEncode((h.activo_codigo + " · " + h.activo_nombre).Trim(' ', '·'));
            string valor = h.respuesta_numero != null ? Num(h.respuesta_numero) + (string.IsNullOrEmpty(h.respuesta_unidad) ? "" : " " + Server.HtmlEncode(h.respuesta_unidad)) : "—";
            string fecha = h.cha_fecha_creacion != null ? h.cha_fecha_creacion.Value.ToString("dd-MM-yyyy HH:mm", cul) : "—";
            string reporta = string.IsNullOrEmpty(h.ejecutor_nombre) ? "—" : Server.HtmlEncode(h.ejecutor_nombre);
            string est = string.IsNullOrEmpty(h.estado_nombre) ? "—" : "<span class='pc-badge es-bor'>" + Server.HtmlEncode(h.estado_nombre) + "</span>";

            tb.Append("<tr class='pc-hz-fila").Append(first ? " es-sel" : "").Append("' data-hz='").Append(h.cha_id)
              .Append("' onclick='pcHzSel(").Append(h.cha_id).Append(")'>")
              .Append("<td class='cod'>").Append(id).Append("</td><td>").Append(Server.HtmlEncode(h.cha_titulo)).Append("</td><td>").Append(activo)
              .Append("</td><td>").Append(valor).Append("</td><td>").Append(SevBadge(h.severidad_nombre)).Append("</td><td>").Append(est)
              .Append("</td><td>").Append(fecha).Append("</td><td>").Append(reporta).Append("</td><td class='acc'><i class='mdi mdi-chevron-right' style='color:var(--muted);'></i></td></tr>");

            // Detalle
            det.Append("<div class='pc-hz-det").Append(first ? " es-sel" : "").Append("' data-hzdet='").Append(h.cha_id).Append("'>");
            det.Append("<div class='pc-hz-h'><div style='font-weight:800;color:var(--muted);font-size:12px;'>").Append(id).Append("</div>")
               .Append(string.IsNullOrEmpty(h.estado_nombre) ? "" : "<span class='pc-badge es-bor'>" + Server.HtmlEncode(h.estado_nombre) + "</span>").Append("</div>");
            det.Append("<div style='font-size:16px;font-weight:800;color:var(--ink);margin:4px 0 2px;'>").Append(Server.HtmlEncode(h.cha_titulo)).Append("</div>");
            det.Append("<div class='pc-hz-meta'>")
               .Append("<span><i class='mdi mdi-cube-outline'></i>").Append(activo).Append("</span>")
               .Append("<span><i class='mdi mdi-calendar-outline'></i>").Append(fecha).Append("</span>")
               .Append("<span><i class='mdi mdi-account-outline'></i>").Append(reporta).Append("</span></div>");

            det.Append("<div style='font-weight:800;color:var(--ink);font-size:13px;margin-bottom:10px;'>Detalle de la respuesta</div>");
            det.Append("<div class='pc-hz-grid'>")
               .Append("<div><div class='k'>Valor medido</div><div class='v'>").Append(valor).Append("</div></div>")
               .Append("<div><div class='k'>Resultado</div><div class='v sm'>").Append(h.respuesta_fuera_rango ? "<span style='color:#C7352B;'>Fuera de rango</span>" : "Registrado").Append("</div></div>")
               .Append("</div>");
            det.Append("<div class='pc-hz-grid'>")
               .Append("<div><div class='k'>Origen</div><div class='v sm'>Ejecución de pauta")
               .Append(h.ejecucion_fecha != null ? " · " + h.ejecucion_fecha.Value.ToString("dd-MM-yyyy", cul) : "").Append("</div></div>")
               .Append("<div><div class='k'>Ítem</div><div class='v sm'>").Append(string.IsNullOrEmpty(h.item_texto) ? "—" : Server.HtmlEncode(h.item_texto)).Append("</div></div>")
               .Append("</div>");

            if (h.orden_trabajo_id != null)
                det.Append("<div class='pc-info-card' style='background:#E7F4EE;border-color:#BBE4CE;margin-bottom:12px;'><div class='t' style='color:#16855B;'><i class='mdi mdi-wrench-outline' style='color:#16855B;'></i>OT vinculada #")
                   .Append(h.orden_trabajo_correlativo).Append("</div><p>Este hallazgo ya tiene una orden de trabajo asociada.</p></div>");

            det.Append("<div class='pc-hz-acc'>")
               .Append("<a href='#' class='pc-btn out' data-ir-sec='ocurrencias'><i class='mdi mdi-play-circle-outline'></i>Ver ejecución</a>")
               .Append("<a href='").Append(bandeja).Append("' class='pc-btn out'><i class='mdi mdi-tray-full'></i>Abrir en bandeja</a>")
               .Append("</div>");
            det.Append("<div class='pc-info-card' style='background:var(--sigma-cyan-soft);border-color:#BDEDEE;margin-top:12px;'><p style='margin:0;'><i class='mdi mdi-information-outline'></i> Generar una OT vincula el trabajo; no resuelve automáticamente el hallazgo. Las acciones (Generar OT, Descartar) están en la bandeja.</p></div>");
            det.Append("</div>");
            first = false;
        }
        tb.Append("</tbody></table>");
        litHallazgosPauta.Text = tb.ToString();
        litHallazgoDet.Text = det.ToString();
    }

    /// <summary>Programaciones (mockup 06): tabla (izq) + detalle (der).</summary>
    private void RenderProgramaciones(List<ChecklistProgramacion> progs)
    {
        if (progs == null || progs.Count == 0)
        {
            litProgramaciones.Text = "<div class='pc-vacio'><i class='mdi mdi-calendar-blank-outline'></i>Esta pauta todavía no tiene programaciones. Crea una para que genere rondas.</div>";
            litProgDetalle.Text = "<div style='color:var(--muted);font-size:13px;'>Crea una programación para ver su detalle aquí.</div>";
            return;
        }

        bool puede = Token.Puede("CREAR EDITAR PAUTAS");
        StringBuilder tb = new StringBuilder(), det = new StringBuilder();
        tb.Append("<table class='pc-table'><thead><tr><th>Nombre</th><th>Frecuencia</th><th>Objetivo</th><th>Grupo</th><th>Responsable</th><th>Estado</th></tr></thead><tbody>");

        bool first = true;
        foreach (ChecklistProgramacion p in progs)
        {
            string objetivo = !string.IsNullOrEmpty(p.activo_nombre)
                ? Server.HtmlEncode((p.activo_codigo + " · " + p.activo_nombre).Trim(' ', '·'))
                : !string.IsNullOrEmpty(p.area_nombre) ? "Área: " + Server.HtmlEncode(p.area_nombre) : "Sin objetivo";
            string grupo = string.IsNullOrEmpty(p.grupo_nombre) ? "Sin grupo" : Server.HtmlEncode(p.grupo_nombre);
            string resp = string.IsNullOrEmpty(p.responsable_nombre) ? "Sin responsable" : Server.HtmlEncode(p.responsable_nombre);
            string estado = p.cpr_habilitado ? "<span class='pc-badge es-on'>Habilitada</span>" : "<span class='pc-badge es-off'>Deshabilitada</span>";

            tb.Append("<tr class='pc-prog-fila").Append(first ? " es-sel" : "").Append("' data-prog='").Append(p.cpr_id)
              .Append("' onclick='pcProgSel(").Append(p.cpr_id).Append(")'>")
              .Append("<td class='cod'>").Append(Server.HtmlEncode(p.cpr_nombre)).Append("</td>")
              .Append("<td>").Append(Server.HtmlEncode(p.programacion_nombre ?? "—")).Append("</td>")
              .Append("<td>").Append(objetivo).Append("</td>")
              .Append("<td>").Append(grupo).Append("</td>")
              .Append("<td>").Append(resp).Append("</td>")
              .Append("<td>").Append(estado).Append("</td></tr>");

            // Detalle (aside)
            string ver = p.version_numero > 0 ? "v" + p.version_numero + " - Publicada" : "Versión publicada";
            det.Append("<div class='pc-prog-det").Append(first ? " es-sel" : "").Append("' data-progdet='").Append(p.cpr_id).Append("'>")
               .Append("<div class='pc-grid-2'>")
               .Append(FldRo("Nombre", Server.HtmlEncode(p.cpr_nombre)))
               .Append(FldRo("Pauta", ver))
               .Append(FldRo("Recurrencia", Server.HtmlEncode(p.programacion_nombre ?? "—")))
               .Append(FldRo("Objetivo (activo)", string.IsNullOrEmpty(p.activo_nombre) ? "—" : Server.HtmlEncode((p.activo_codigo + " · " + p.activo_nombre).Trim(' ', '·'))))
               .Append(FldRo("Área", string.IsNullOrEmpty(p.area_nombre) ? "Sin área" : Server.HtmlEncode(p.area_nombre)))
               .Append(FldRo("Grupo", grupo))
               .Append(FldRo("Responsable", resp))
               .Append("<div class='pc-fld'><label>Estado</label><div>" + estado + "</div></div>")
               .Append("</div>");
            if (!p.cpr_habilitado)
                det.Append("<div class='pc-info-card' style='background:#FBF0E3;border-color:#F2D9B8;margin-top:12px;'><div class='t' style='color:#B65C00;'><i class='mdi mdi-alert-outline' style='color:#B65C00;'></i>Programación deshabilitada</div><p>No genera nuevas ocurrencias mientras esté deshabilitada.</p></div>");
            if (puede)
            {
                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + p.cpr_id));
                det.Append("<div class='pc-form-actions' style='border:none;padding-top:14px;margin-top:6px;'>")
                   .Append("<a href='#' class='pc-btn out' onclick=\"return abrirProgramacion('").Append(query).Append("')\"><i class='mdi mdi-pencil-outline'></i>Editar programación</a></div>");
            }
            det.Append("</div>");
            first = false;
        }
        tb.Append("</tbody></table>");
        litProgramaciones.Text = tb.ToString();
        litProgDetalle.Text = det.ToString();
    }

    private string FldRo(string k, string v)
    {
        return "<div class='pc-fld'><label>" + Server.HtmlEncode(k) + "</label><div class='ro'>" + v + "</div></div>";
    }

    /// <summary>
    /// Ocurrencias y ejecuciones (mockup 07): lista (izq) + detalle de la
    /// ejecución seleccionada (der). La selección va por postback (hdnEjec)
    /// porque una ejecución puede tener cientos de respuestas.
    /// </summary>
    private void RenderOcurrenciasMaster(List<ChecklistOcurrencia> ocs, List<ChecklistHallazgo> hallazgos)
    {
        if (ocs == null || ocs.Count == 0)
        {
            litOcurrencias.Text = "<div class='pc-vacio'><i class='mdi mdi-calendar-blank-outline'></i>Esta pauta todavía no tiene ocurrencias generadas.</div>";
            litEjecucion.Text = "<div class='pc-vacio'><i class='mdi mdi-gesture-tap'></i>Cuando haya ejecuciones, aquí verás su detalle.</div>";
            return;
        }

        CultureInfo cul = new CultureInfo("es-CL");
        ocs.Sort((a, b) => Nullable.Compare(b.prevista, a.prevista));

        // Ejecución seleccionada: la de hdnEjec si pertenece a esta pauta, o la
        // más reciente ejecutada.
        int selEjec; int.TryParse(hdnEjec.Value, out selEjec);
        ChecklistOcurrencia sel = null;
        foreach (ChecklistOcurrencia o in ocs) if (o.ejecucion_id != null && o.ejecucion_id.Value == selEjec) { sel = o; break; }
        if (sel == null) foreach (ChecklistOcurrencia o in ocs) if (o.ejecutada) { sel = o; break; }

        StringBuilder sb = new StringBuilder();
        sb.Append("<table class='pc-table'><thead><tr><th>Fecha programada</th><th>Estado</th><th>Equipo</th><th>Versión</th><th></th></tr></thead><tbody>");
        int n = 0;
        foreach (ChecklistOcurrencia o in ocs)
        {
            if (n++ >= 50) break;
            string estado = "<span class='pc-badge " + (o.ejecutada ? "es-pub" : "es-bor") + "'>" +
                            Server.HtmlEncode(string.IsNullOrEmpty(o.estado_nombre) ? "" : o.estado_nombre) + "</span>";
            string fecha = o.prevista != null ? o.prevista.Value.ToString("dd-MM-yyyy HH:mm", cul) : "—";
            string equipo = string.IsNullOrEmpty(o.activo_codigo) ? (string.IsNullOrEmpty(o.area) ? "—" : Server.HtmlEncode(o.area)) : Server.HtmlEncode(o.activo_codigo);
            bool esSel = sel != null && o.ejecucion_id != null && sel.ejecucion_id != null && o.ejecucion_id.Value == sel.ejecucion_id.Value;
            string click = o.ejecutada ? " onclick='pcOcSel(" + o.ejecucion_id.Value + ")'" : "";
            string chev = o.ejecutada ? "<i class='mdi mdi-chevron-right' style='color:var(--muted);'></i>" : "";
            sb.Append("<tr class='pc-oc-fila").Append(esSel ? " es-sel" : "").Append("'").Append(click).Append(">")
              .Append("<td>").Append(fecha).Append("</td><td>").Append(estado).Append("</td><td class='cod'>").Append(equipo)
              .Append("</td><td>v").Append(o.version_numero).Append("</td><td class='acc'>").Append(chev).Append("</td></tr>");
        }
        sb.Append("</tbody></table>");
        if (ocs.Count > 50) sb.Append("<div class='pc-vacio' style='padding:10px;'>Mostrando las 50 más recientes de ").Append(ocs.Count).Append(".</div>");
        litOcurrencias.Text = sb.ToString();

        litEjecucion.Text = sel != null ? RenderEjecucionDetalle(sel, hallazgos)
            : "<div class='pc-vacio'><i class='mdi mdi-gesture-tap'></i>Selecciona una ejecución para ver su detalle.</div>";
    }

    private string RenderEjecucionDetalle(ChecklistOcurrencia o, List<ChecklistHallazgo> hallazgos)
    {
        CultureInfo cul = new CultureInfo("es-CL");
        StringBuilder sb = new StringBuilder();

        string titulo = o.fin != null ? "Ejecución del " + o.fin.Value.ToString("dd 'de' MMMM 'de' yyyy, HH:mm", cul) : "Ejecución";
        string estadoBadge = "<span class='pc-badge es-pub'>" + Server.HtmlEncode(string.IsNullOrEmpty(o.estado_nombre) ? "Completada" : o.estado_nombre) + "</span>";
        sb.Append("<div style='display:flex;align-items:flex-start;justify-content:space-between;gap:12px;'><h2 style='margin:0;font-size:18px;font-weight:800;color:var(--ink);'>")
          .Append(Server.HtmlEncode(titulo)).Append("</h2>").Append(estadoBadge).Append("</div>");

        sb.Append("<div class='pc-ej-attrs'>")
          .Append(EjAttr("mdi-account-outline", "Técnico", string.IsNullOrEmpty(o.ejecutor) ? "—" : Server.HtmlEncode(o.ejecutor)))
          .Append(EjAttr("mdi-calendar-check", "Fecha y hora de término", o.fin != null ? o.fin.Value.ToString("dd-MM-yyyy HH:mm", cul) : "—"))
          .Append(EjAttr("mdi-cellphone", "Origen", string.IsNullOrEmpty(o.origen) ? "—" : Server.HtmlEncode(o.origen)))
          .Append(EjAttr("mdi-file-outline", "Versión ejecutada", "v" + o.version_numero))
          .Append("</div>");

        sb.Append("<h3 style='margin:0 0 2px;font-size:14px;font-weight:800;color:var(--ink);'>Respuestas de la inspección</h3>")
          .Append("<div style='color:var(--muted);font-size:12.5px;margin-bottom:10px;'>Resultados registrados por el técnico. La ejecución está completada y no se puede editar.</div>");

        List<ChecklistRespuesta> resp = new ChecklistCentroController().GetRespuestas(o.ejecucion_id ?? 0) ?? new List<ChecklistRespuesta>();
        if (resp.Count == 0)
            sb.Append("<div class='pc-vacio' style='padding:16px;'>Sin respuestas registradas.</div>");
        else
        {
            resp.Sort((a, b) => { int c = a.seccion_orden.CompareTo(b.seccion_orden); return c != 0 ? c : a.orden.CompareTo(b.orden); });
            sb.Append("<table class='pc-table'><thead><tr><th>Ítem</th><th>Respuesta</th><th>Observación</th><th>Foto</th></tr></thead><tbody>");
            int i = 0;
            foreach (ChecklistRespuesta r in resp)
            {
                i++;
                string val = Server.HtmlEncode(r.valor ?? "");
                string rb;
                if (!r.respondido) rb = "<span class='pc-badge es-ret'>Sin responder</span>";
                else if (r.fuera_rango) rb = "<span class='pc-badge' style='background:#FBEBEA;color:#C7352B;'>Fuera de rango</span>" + (val != "" ? " <span style='color:#C7352B;'>" + val + "</span>" : "");
                else if (r.no_aplica) rb = "<span class='pc-badge es-ret'>No aplica</span>";
                else rb = "<span class='pc-badge es-on'>" + (val != "" ? val : "Conforme") + "</span>";
                string obs = string.IsNullOrEmpty(r.comentario) ? "<span style='color:var(--muted);'>—</span>" : Server.HtmlEncode(r.comentario);
                string foto = r.evidencias > 0 ? "<span style='color:var(--sigma-purple);'><i class='mdi mdi-camera-outline'></i> " + r.evidencias + "</span>" : "<span style='color:var(--muted);'>—</span>";
                sb.Append("<tr><td><b style='color:var(--ink);'>").Append(i).Append(".</b> ").Append(Server.HtmlEncode(r.texto)).Append("</td><td>")
                  .Append(rb).Append("</td><td>").Append(obs).Append("</td><td>").Append(foto).Append("</td></tr>");
            }
            sb.Append("</tbody></table>");
        }

        // Hallazgo asociado a esta ejecución.
        ChecklistHallazgo h = null;
        if (hallazgos != null) foreach (ChecklistHallazgo x in hallazgos) if (x.ejecucion_id == (o.ejecucion_id ?? -1)) { h = x; break; }
        if (h != null)
        {
            string est = string.IsNullOrEmpty(h.estado_nombre) ? "" : "<span class='pc-badge es-bor'>" + Server.HtmlEncode(h.estado_nombre) + "</span>";
            sb.Append("<div class='pc-info-card' style='background:#FBEBEA;border-color:#F3C9C6;margin-top:16px;'>")
              .Append("<div style='display:flex;align-items:center;gap:10px;'><i class='mdi mdi-alert-outline' style='color:#C7352B;font-size:20px;'></i>")
              .Append("<div style='flex:1;'><div style='font-weight:800;color:#C7352B;'>Hallazgo asociado</div><div style='color:#7a2b26;font-size:12.5px;'>Este resultado generó un hallazgo de inspección.</div></div>")
              .Append("<div style='font-weight:700;color:var(--ink);'>").Append(Server.HtmlEncode(h.cha_titulo)).Append("</div>").Append(est)
              .Append("<a href='").Append(ResolveUrl("~/View/Mantenimiento/Hallazgos/ChecklistHallazgos.aspx")).Append("' class='pc-btn out'><i class='mdi mdi-open-in-new'></i>Abrir hallazgo</a></div>");
        }
        return sb.ToString();
    }

    private string EjAttr(string ico, string k, string v)
    {
        return "<div class='pc-ej-attr'><span class='ic'><i class='mdi " + ico + "'></i></span><div><div class='k'>" +
               Server.HtmlEncode(k) + "</div><div class='v'>" + v + "</div></div></div>";
    }

    /// <summary>
    /// Estructura (mockup 04): árbol de secciones/ítems (izq), detalle del ítem
    /// (centro) y vista previa móvil (der). El detalle y la preview de todos los
    /// ítems se pintan ocultos; el árbol muestra el seleccionado (JS). Umbral,
    /// evidencia y severidad salen de las validaciones (HU-091).
    /// </summary>
    private void RenderEstructura(int versionId, int numero, int estado)
    {
        litEstVer.Text = versionId > 0
            ? " <span class='pc-badge es-ver'>v" + numero + "</span> " +
              (estado == 2 ? "<span class='pc-badge es-pub'>Publicada</span>"
               : estado == 3 ? "<span class='pc-badge es-ret'>Retirada</span>"
               : "<span class='pc-badge es-bor'>Borrador</span>")
            : "";

        if (versionId <= 0) { litEstTree.Text = "<div class='pc-vacio'>Esta pauta todavía no tiene una versión con estructura.</div>"; litEstDetail.Text = ""; litEstPreview.Text = ""; return; }

        ChecklistEstructuraController c = new ChecklistEstructuraController();
        List<ChecklistSeccion> secciones = c.GetSecciones(versionId) ?? new List<ChecklistSeccion>();
        List<ChecklistItem> items = c.GetItems(versionId) ?? new List<ChecklistItem>();
        if (secciones.Count == 0) { litEstTree.Text = "<div class='pc-vacio'>Sin secciones en esta versión.</div>"; litEstDetail.Text = ""; litEstPreview.Text = ""; return; }

        // Validaciones (umbral/evidencia/severidad) por ítem.
        Dictionary<int, ChecklistItemValidacion> vmap = new Dictionary<int, ChecklistItemValidacion>();
        List<ChecklistItemValidacion> vals = new ChecklistItemValidacionController().GetValidaciones(new ChecklistItemValidacion { filtro_plantilla = Plantilla });
        if (vals != null) foreach (ChecklistItemValidacion v in vals) if (!vmap.ContainsKey(v.item_id)) vmap[v.item_id] = v;

        StringBuilder tree = new StringBuilder(), det = new StringBuilder(), prev = new StringBuilder();
        bool first = true;
        foreach (ChecklistSeccion s in secciones)
        {
            List<ChecklistItem> its = items.FindAll(i => i.seccion_sid == s.sid);
            tree.Append("<div class='pc-tree-sec'><div class='cab' onclick=\"this.parentNode.classList.toggle('cerrada')\"><i class='mdi mdi-chevron-down chev'></i><i class='mdi mdi-folder-outline'></i>")
                .Append(Server.HtmlEncode(s.cps_nombre)).Append("<span class='n'>").Append(its.Count).Append("</span></div><div class='pc-tree-items'>");

            int idx = 0;
            foreach (ChecklistItem it in its)
            {
                idx++;
                ChecklistItemValidacion v = vmap.ContainsKey(it.cpi_id) ? vmap[it.cpi_id] : null;
                tree.Append("<div class='pc-tree-item").Append(first ? " es-sel" : "").Append("' data-item='").Append(it.cpi_id)
                    .Append("' onclick='pcEstSel(").Append(it.cpi_id).Append(")'><i class='mdi mdi-file-outline'></i><span class='num'>")
                    .Append(idx).Append("</span>").Append(Server.HtmlEncode(it.cpi_texto)).Append("</div>");
                det.Append(RenderItemDetalle(it, s, v, idx, its.Count, first));
                prev.Append(RenderItemPreview(it, s, v, first));
                first = false;
            }
            tree.Append("</div></div>");
        }
        litEstTree.Text = tree.ToString();
        litEstDetail.Text = det.ToString();
        litEstPreview.Text = prev.ToString();
    }

    private static string Num(decimal? d)
    {
        return d == null ? "" : d.Value.ToString("0.####", new CultureInfo("es-CL"));
    }

    private string UmbralTexto(ChecklistItemValidacion v)
    {
        if (v == null) return "—";
        if (v.valor_minimo != null && v.valor_maximo != null) return "Fuera de " + Num(v.valor_minimo) + " – " + Num(v.valor_maximo);
        if (v.valor_maximo != null) return "Fuera de rango > " + Num(v.valor_maximo);
        if (v.valor_minimo != null) return "Fuera de rango < " + Num(v.valor_minimo);
        if (v.largo_maximo != null) return "Máx. " + v.largo_maximo + " caracteres";
        return "—";
    }

    private string RenderItemDetalle(ChecklistItem it, ChecklistSeccion s, ChecklistItemValidacion v, int idx, int total, bool sel)
    {
        string unidad = string.IsNullOrEmpty(it.unidad_simbolo) ? "—" : Server.HtmlEncode(it.unidad_simbolo);
        string umbral = UmbralTexto(v);
        string evidencia = (v != null && v.requiere_evidencia) ? "Sí, si aplica" : "No requerida";
        string severidad = (v != null && v.genera_hallazgo) ? "<span class='pc-badge' style='background:#FBEBEA;color:#C7352B;'>Alta</span>"
                          : (v != null && v.genera_alerta) ? "<span class='pc-badge es-bor'>Media</span>" : "—";
        string criterio = (v != null && !string.IsNullOrEmpty(v.mensaje)) ? Server.HtmlEncode(v.mensaje) : "";

        StringBuilder sb = new StringBuilder();
        sb.Append("<div class='pc-det").Append(sel ? " es-sel" : "").Append("' data-detail='").Append(it.cpi_id).Append("'>");
        sb.Append("<div class='pc-det-h'><div><h2>").Append(Server.HtmlEncode(it.cpi_texto)).Append("</h2><div class='sec'>Sección: ")
          .Append(Server.HtmlEncode(s.cps_nombre)).Append("</div></div>")
          .Append("<div class='pc-det-nav'><span class='cnt'>Ítem ").Append(idx).Append(" de ").Append(total).Append("</span>")
          .Append("<a href='#' class='pc-btn out' onclick='return pcEstNav(-1)'><i class=\"mdi mdi-chevron-left\"></i></a>")
          .Append("<a href='#' class='pc-btn out' onclick='return pcEstNav(1)'><i class=\"mdi mdi-chevron-right\"></i></a></div></div>");

        sb.Append("<div class='pc-det-attrs'>")
          .Append(Attr("Tipo de dato", Server.HtmlEncode(it.tipo_nombre ?? "—")))
          .Append(Attr("Unidad", unidad))
          .Append(Attr("Obligatorio", it.cpi_obligatorio ? "Sí" : "No"))
          .Append(Attr("Regla de umbral", umbral))
          .Append(Attr("Evidencia", evidencia))
          .Append(Attr("Severidad", severidad))
          .Append("</div>");

        if (!string.IsNullOrEmpty(criterio))
            sb.Append("<div class='pc-det-block'><h4>Criterio de aceptación</h4><p>").Append(criterio).Append("</p></div>");
        else if (umbral != "—")
            sb.Append("<div class='pc-det-block'><h4>Criterio de aceptación</h4><p>Valor dentro del rango definido. ").Append(Server.HtmlEncode(umbral)).Append(" se considera fuera de rango.</p></div>");

        sb.Append("</div>");
        return sb.ToString();
    }

    private string Attr(string k, string v)
    {
        return "<div class='pc-attr'><div class='k'>" + Server.HtmlEncode(k) + "</div><div class='v'>" + v + "</div></div>";
    }

    private string RenderItemPreview(ChecklistItem it, ChecklistSeccion s, ChecklistItemValidacion v, bool sel)
    {
        string unidad = string.IsNullOrEmpty(it.unidad_simbolo) ? "" : Server.HtmlEncode(it.unidad_simbolo);
        string hint = (v != null && v.valor_maximo != null) ? "Valor aceptable: ≤ " + Num(v.valor_maximo) + " " + unidad : "";
        StringBuilder sb = new StringBuilder();
        sb.Append("<div class='pc-ph-wrap").Append(sel ? " es-sel" : "").Append("' data-prev='").Append(it.cpi_id).Append("'>");
        sb.Append("<div class='pc-phone'>")
          .Append("<div class='ph-cab'><span><i class='mdi mdi-chevron-left'></i></span></div>")
          .Append("<div class='ph-sec'>").Append(Server.HtmlEncode(s.cps_nombre)).Append("</div>")
          .Append("<div class='ph-q'>").Append(Server.HtmlEncode(it.cpi_texto)).Append("</div>")
          .Append("<div class='ph-in'><span>").Append(string.IsNullOrEmpty(unidad) ? "Respuesta" : "0,0").Append("</span><span>").Append(unidad).Append("</span></div>");
        if (!string.IsNullOrEmpty(hint)) sb.Append("<div class='ph-hint'>").Append(hint).Append("</div>");
        if (v != null && v.requiere_evidencia)
            sb.Append("<div class='ph-in' style='color:#C7352B;'><span><i class='mdi mdi-camera-outline'></i> Tomar foto</span><span>&rsaquo;</span></div>");
        sb.Append("<div class='ph-hint'>Observación (opcional)</div><div class='ph-in'><span>Agrega una observación…</span></div>");
        sb.Append("</div></div>");
        return sb.ToString();
    }

    /// <summary>Historial de versiones (tabla, mockup 05).</summary>
    private string RenderVersiones(List<ChecklistVersion> versiones)
    {
        if (versiones == null || versiones.Count == 0)
            return "<div class='pc-vacio'>Esta pauta todavía no tiene versiones.</div>";

        CultureInfo cul = new CultureInfo("es-CL");
        StringBuilder sb = new StringBuilder();
        sb.Append("<table class='pc-table'><thead><tr>")
          .Append("<th>Versión</th><th>Estado</th><th>Fecha</th><th>Publicada por</th><th>Descripción</th><th class='acc'>Acciones</th>")
          .Append("</tr></thead><tbody>");
        foreach (ChecklistVersion v in versiones)
        {
            string badge = v.cpv_estado == 2 ? "<span class='pc-badge es-pub'>Publicada</span>"
                         : v.cpv_estado == 3 ? "<span class='pc-badge es-ret'>Retirada</span>"
                         : "<span class='pc-badge es-bor'>Borrador</span>";
            string fecha = v.cpv_estado == 2 && v.cpv_fecha_publicacion != null ? v.cpv_fecha_publicacion.Value.ToString("dd-MM-yyyy HH:mm", cul)
                         : v.cpv_estado == 3 && v.cpv_fecha_retiro != null ? v.cpv_fecha_retiro.Value.ToString("dd-MM-yyyy HH:mm", cul)
                         : "—";
            string por = string.IsNullOrEmpty(v.usuario_publicacion_nombre) ? "—" : Server.HtmlEncode(v.usuario_publicacion_nombre);
            string desc = string.IsNullOrEmpty(v.cpv_observacion)
                ? "<span style='color:var(--muted);'>" + v.secciones + " sec · " + v.items + " ítems</span>"
                : Server.HtmlEncode(v.cpv_observacion);
            string acc = v.cpv_estado == 1
                ? "<a href='#' class='pc-btn out' data-ir-sec='estructura'><i class='mdi mdi-file-tree-outline'></i>Ver estructura</a>"
                : "<a href='#' class='pc-btn out' data-ir-sec='estructura'><i class='mdi mdi-eye-outline'></i>Consultar</a>";

            sb.Append("<tr><td class='cod'>v").Append(v.cpv_numero).Append("</td><td>").Append(badge).Append("</td><td>")
              .Append(fecha).Append("</td><td>").Append(por).Append("</td><td>").Append(desc).Append("</td><td class='acc'>")
              .Append(acc).Append("</td></tr>");
        }
        sb.Append("</tbody></table>");
        return sb.ToString();
    }

    /// <summary>Aside de revisión de publicación (mockup 05).</summary>
    private string RenderPublicacion(ChecklistVersion borrador, ChecklistVersion pub, int progActivas)
    {
        if (borrador == null)
            return "<p style='color:var(--muted);font-size:13px;margin:0;'>No hay una versión en borrador. Crea una nueva versión para editar la estructura y luego publícala.</p>";

        StringBuilder sb = new StringBuilder();
        sb.Append("<p style='color:#384357;font-size:13px;margin:0 0 12px;'>Antes de publicar la <b>v")
          .Append(borrador.cpv_numero).Append("</b>, revisa el impacto en las programaciones existentes.</p>");
        if (progActivas > 0)
            sb.Append("<div class='pc-info-card' style='background:#FBF0E3;border-color:#F2D9B8;'><div class='t' style='color:#B65C00;'><i class='mdi mdi-alert-outline' style='color:#B65C00;'></i>")
              .Append(progActivas).Append(progActivas == 1 ? " programación requiere revisión" : " programaciones requieren revisión")
              .Append("</div><p>Al publicar, las próximas ocurrencias usarán la nueva versión.</p></div>");
        else
            sb.Append("<div class='pc-info-card' style='background:#E7F4EE;border-color:#BBE4CE;'><div class='t' style='color:#16855B;'><i class='mdi mdi-check-circle-outline' style='color:#16855B;'></i>Sin programaciones activas</div><p>Publicar no afecta programaciones en curso.</p></div>");
        return sb.ToString();
    }

    /// <summary>Comparación resumen entre la versión publicada y el borrador.</summary>
    private string RenderComparacion(ChecklistVersion pub, ChecklistVersion borrador)
    {
        StringBuilder sb = new StringBuilder();
        sb.Append("<div style='margin-bottom:10px;font-size:12px;color:var(--muted);'>")
          .Append("<span class='pc-badge es-pub'>v").Append(pub.cpv_numero).Append(" publicada</span> &rarr; <span class='pc-badge es-bor'>v")
          .Append(borrador.cpv_numero).Append(" borrador</span></div>");
        sb.Append("<table class='pc-table'><thead><tr><th>Elemento</th><th>v").Append(pub.cpv_numero).Append("</th><th>v")
          .Append(borrador.cpv_numero).Append("</th><th class='acc'>Cambio</th></tr></thead><tbody>");
        sb.Append(FilaComparacion("Secciones", pub.secciones, borrador.secciones));
        sb.Append(FilaComparacion("Ítems", pub.items, borrador.items));
        sb.Append("</tbody></table>");
        return sb.ToString();
    }

    private string FilaComparacion(string elem, int a, int b)
    {
        string cambio = b > a ? "<span class='pc-badge' style='background:#EAF4FF;color:#087BEA;'>+" + (b - a) + " agregado</span>"
                      : b < a ? "<span class='pc-badge' style='background:#FBF0E3;color:#B65C00;'>-" + (a - b) + "</span>"
                      : "<span class='pc-badge es-ret'>Sin cambios</span>";
        return "<tr><td class='cod'>" + Server.HtmlEncode(elem) + "</td><td>" + a + "</td><td>" + b + "</td><td class='acc'>" + cambio + "</td></tr>";
    }

    protected void lnkPublicar_Click(object sender, EventArgs e)
    {
        if (!Token.Puede("CREAR EDITAR PAUTAS"))
        {
            Tools.tools.ClientAlert("No tiene permiso para publicar versiones.", "alerta");
            return;
        }
        Respuesta r = new ChecklistVersionController().Publicar(Plantilla, "");
        Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
        // El PreRender repinta la ficha con la versión ya publicada.
    }

    private string Kpi(string icono, string iconClass, string titulo, string valor, string sub)
    {
        return "<div class='sg-a3-kpi'><span class='sg-a3-kpi-ico " + iconClass + "'><i class='mdi " + icono + "'></i></span>" +
               "<div class='sg-a3-kpi-txt'><span>" + Server.HtmlEncode(titulo) + "</span><b>" + Server.HtmlEncode(valor) + "</b>" +
               "<em style='display:block;color:#94a3b8;font-style:normal;font-size:11.5px;margin-top:2px;'>" + Server.HtmlEncode(sub) + "</em></div></div>";
    }

    private string InfoFila(string icono, string k, string v)
    {
        return "<div style='display:flex;align-items:center;gap:10px;padding:7px 4px;font-size:13px;border-top:1px solid #f1f5f9;'>" +
               "<i class='mdi " + icono + "' style='color:#94a3b8;font-size:17px;'></i>" +
               "<span style='color:#64748b;flex:0 0 110px;'>" + Server.HtmlEncode(k) + "</span>" +
               "<span style='color:#0f172a;font-weight:600;'>" + v + "</span></div>";
    }

    // ---- Combos del formulario de Configuración ----
    private void SeleccionarCombo(RadComboBox2 combo, int id)
    {
        RadComboBoxItem item = combo.FindItemByValue(id.ToString());
        if (item != null) item.Selected = true;
    }

    private void BindComboInstalacion(RadComboBox2 c, int cliente, int? sel)
    {
        c.Items.Clear();
        c.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
        c.AppendDataBoundItems = true;
        c.DataSource = new ClienteInstalacionController().GetClienteInstalaciones(new ClienteInstalacion { cin_cliente = cliente, filtro_habilitado = "1" });
        c.DataValueField = "cin_id"; c.DataTextField = "cin_nombre"; c.DataBind();
        c.AppendDataBoundItems = false;
        if (sel != null) SeleccionarCombo(c, sel.Value);
    }

    private void BindComboActivoTipo(RadComboBox2 c, int cliente, int? sel)
    {
        c.Items.Clear();
        c.Items.Add(new RadComboBoxItem("Cualquier tipo", ""));
        c.AppendDataBoundItems = true;
        c.DataSource = new ActivoTipoController().GetActivoTipos(new ActivoTipo { filtro_cliente = cliente, filtro_habilitado = true });
        c.DataValueField = "ati_id"; c.DataTextField = "ati_nombre"; c.DataBind();
        c.AppendDataBoundItems = false;
        if (sel != null) SeleccionarCombo(c, sel.Value);
    }

    private void BindComboAsignacion(RadComboBox2 c, int? sel)
    {
        c.Items.Clear();
        c.Items.Add(new RadComboBoxItem("Sin definir", ""));
        c.AppendDataBoundItems = true;
        c.DataSource = new ChecklistAsignacionTipoController().GetTipos();
        c.DataValueField = "cat_id"; c.DataTextField = "cat_nombre"; c.DataBind();
        c.AppendDataBoundItems = false;
        if (sel != null) SeleccionarCombo(c, sel.Value);
    }

    protected void btnGuardarCfg_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("CREAR EDITAR PAUTAS")) { Tools.tools.ClientAlert("No tiene permiso para editar la pauta.", "alerta"); return; }
            if (string.IsNullOrEmpty(txtNombreCfg.Text.Trim())) { Tools.tools.ClientAlert("Debe indicar el nombre.", "alerta"); return; }

            ChecklistPlantilla x = new ChecklistPlantilla();
            x.cpl_id = Plantilla;
            x.cpl_codigo = txtCodigoCfg.Text.Trim();
            x.cpl_nombre = txtNombreCfg.Text.Trim();
            x.cpl_habilitado = chkHabilitadaCfg.Checked;
            if (!string.IsNullOrEmpty(txtDescripcionCfg.Text.Trim())) x.cpl_descripcion = txtDescripcionCfg.Text.Trim();
            if (!string.IsNullOrEmpty(cboPlantaCfg.SelectedValue)) x.cpl_cliente_instalacion = int.Parse(cboPlantaCfg.SelectedValue);
            if (!string.IsNullOrEmpty(cboActivoTipoCfg.SelectedValue)) x.cpl_activo_tipo = int.Parse(cboActivoTipoCfg.SelectedValue);
            if (!string.IsNullOrEmpty(cboAsignacionCfg.SelectedValue)) x.cpl_checklist_asignacion_tipo = int.Parse(cboAsignacionCfg.SelectedValue);

            Respuesta r = new ChecklistPlantillaController().UpdateChecklistPlantilla(x);
            Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
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
