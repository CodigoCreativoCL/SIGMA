using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// La falla como centro (HU-123, HU-124): Ficha, Diagnosticos, Acciones e
/// Indisponibilidad. Diagnosticos y acciones son hilos: se agregan, no se
/// editan (INS_FALLA_DIAGNOSTICO / INS_FALLA_ACCION), y el SP decide cual
/// es el definitivo y cuando la falla queda resuelta. «Generar orden
/// correctiva» llama a INS_ORDEN_TRABAJO con la falla (origen FALLA) y
/// abre la orden recien creada para asignarla.
/// </summary>
public partial class View_Mantenimiento_Fallas_Falla : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    private string _activoEditar = null, _componenteEditar = null;
    private Falla _falla = null;

    protected string QueryNuevaIndisponibilidad
    {
        get { return Id == 0 ? "0" : Cifrar("Id=0&Falla=" + Id + "&Activo=" + Falla().fal_activo); }
    }

    private string Cifrar(string texto) { return Server.UrlEncode(Tools.Crypto.Encrypt(texto)); }

    private Falla Falla()
    {
        if (_falla == null) _falla = new FallaController().GetFalla(Id);
        return _falla;
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");

            GridIndisponibilidad.AddTemplateColumn("PERIODO", "", "PERÍODO", Width: "34%");
            GridIndisponibilidad.AddTemplateColumn("MINUTOS", "", "MINUTOS", Width: "12%");
            GridIndisponibilidad.AddTemplateColumn("TIPO", "", "TIPO", Width: "18%");
            GridIndisponibilidad.AddColumn("MOTIVO_NOMBRE", "MOTIVO", Width: "16%");
            GridIndisponibilidad.AddColumn("AIN_MOTIVO", "DETALLE", Width: "20%");
        }
        Tools.tools.RegisterPostBackScript(GridIndisponibilidad);
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;
        RadComboBox2 ctrl = (RadComboBox2)sender;
        if (ctrl.ID == "cboPlanta")
        {
            ctrl.Items.Add(new RadComboBoxItem("Todas", ""));
            ctrl.AppendDataBoundItems = true;
            ctrl.DataSource = new ClienteInstalacionController().GetClienteInstalaciones(
                new ClienteInstalacion { filtro_cliente = SitioBase.Session.ClienteId().ToString(), filtro_habilitado = "1" });
            ctrl.DataValueField = "cin_id";
            ctrl.DataTextField = "cin_nombre";
            ctrl.DataBind();
        }
    }

    protected void cboPlanta_SelectedIndexChanged(object sender, EventArgs e) { }
    protected void cboActivo_SelectedIndexChanged(object sender, EventArgs e) { }

    private void CargarDependientes()
    {
        string selA = string.IsNullOrEmpty(_activoEditar) ? cboActivo.SelectedValue : _activoEditar;
        string selC = string.IsNullOrEmpty(_componenteEditar) ? cboComponente.SelectedValue : _componenteEditar;
        int cliente = SitioBase.Session.ClienteId(), planta;
        int.TryParse(cboPlanta.SelectedValue, out planta);

        cboActivo.Items.Clear();
        cboActivo.Items.Add(new RadComboBoxItem("Seleccione...", ""));
        Activo fa = new Activo { act_cliente = cliente, filtro_habilitado = true };
        if (planta > 0) fa.filtro_cliente_instalacion = planta;
        List<Activo> activos = new ActivoController().GetActivos(fa);
        if (activos != null) foreach (Activo a in activos) cboActivo.Items.Add(new RadComboBoxItem(a.act_codigo + " — " + a.act_nombre, a.act_id.ToString()));
        RadComboBoxItem ia = cboActivo.FindItemByValue(selA ?? ""); if (ia != null) ia.Selected = true;

        cboComponente.Items.Clear();
        cboComponente.Items.Add(new RadComboBoxItem("Todo el equipo", ""));
        int activo; int.TryParse(cboActivo.SelectedValue, out activo);
        if (activo > 0)
        {
            List<ActivoComponente> comps = new ActivoComponenteController().GetComponentes(new ActivoComponente { aco_cliente = cliente, filtro_activo = activo, filtro_habilitado = true });
            if (comps != null) foreach (ActivoComponente c in comps) cboComponente.Items.Add(new RadComboBoxItem(c.aco_codigo + " — " + c.aco_nombre, c.aco_id.ToString()));
        }
        RadComboBoxItem ic = cboComponente.FindItemByValue(selC ?? ""); if (ic != null) ic.Selected = true;
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        CargarDependientes();
        Bloqueo();

        bool con = Id > 0;
        tabDiagnosticos.Visible = tabAcciones.Visible = tabIndisponibilidad.Visible = con;

        if (con)
        {
            bool puede = Token.Puede("REGISTRAR FALLA");
            CargarDiagnosticos();
            CargarAcciones();
            pnlNuevoDiagnostico.Visible = puede;
            pnlNuevaAccion.Visible = puede && Falla().fal_fecha_solucion_utc == null;

            GridIndisponibilidad.DataSource = new IndisponibilidadController().Get(new ActivoIndisponibilidad { filtro_falla = Id }) ?? new List<ActivoIndisponibilidad>();
            GridIndisponibilidad.DataBind();
            if (!puede) GridIndisponibilidad.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;
        }

        ScriptManager sm = ScriptManager.GetCurrent(Page);
        sm.RegisterPostBackControl(btnGuardar);
        sm.RegisterPostBackControl(btnVolver);
        sm.RegisterPostBackControl(btnGenerarOT);
        sm.RegisterPostBackControl(btnDiagnostico);
        sm.RegisterPostBackControl(btnAccion);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            Falla f = Falla();
            lblId.Text = "F-" + f.fal_id;
            txtTitulo.Text = f.fal_titulo;
            txtDescripcion.Text = f.fal_descripcion;
            txtConsecuencia.Text = f.fal_consecuencia;
            Seleccionar(cboCriticidad, f.fal_criticidad_nivel.ToString());
            _activoEditar = f.fal_activo.ToString();
            if (f.fal_activo_componente != null) _componenteEditar = f.fal_activo_componente.Value.ToString();
            if (f.fal_activo_estado_posterior != null) Seleccionar(cboEstadoPosterior, f.fal_activo_estado_posterior.Value.ToString());
            txtFechaDeteccion.Text = f.fal_fecha_deteccion_utc == null ? "" : f.fal_fecha_deteccion_utc.Value.ToString("dd-MM-yyyy HH:mm");
            rdbProdSi.Checked = f.fal_detuvo_produccion; rdbProdNo.Checked = !f.fal_detuvo_produccion;
            Cabecera(f);
            wucAuditoria.Mostrar(f.usuario_creacion_nombre, f.fal_fecha_creacion, f.usuario_actualizacion_nombre, f.fal_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nueva";
            litTitulo.Text = "Registrar una falla";
            litSubtitulo.Text = "Guarde la ficha y aparecerán diagnósticos, acciones e indisponibilidad.";
            txtFechaDeteccion.Text = global::SitioBase.Hora.Ahora.ToString("dd-MM-yyyy HH:mm");
        }
    }

    private void Cabecera(Falla f)
    {
        litTitulo.Text = Server.HtmlEncode("F-" + f.fal_id + " · " + f.fal_titulo);
        List<string> p = new List<string>();
        p.Add(f.fal_fecha_solucion_utc == null ? (f.acciones_provisorias > 0 ? "reparada de forma provisoria" : "sin solución") : "resuelta");
        p.Add("criticidad " + (f.criticidad_nombre ?? "").ToLower());
        p.Add(f.activo_codigo + " " + f.activo_nombre + (string.IsNullOrEmpty(f.componente_nombre) ? "" : " / " + f.componente_nombre));
        if (f.fal_fecha_deteccion_utc != null) p.Add("detectada el " + f.fal_fecha_deteccion_utc.Value.ToString("dd-MM-yyyy HH:mm"));
        if (!string.IsNullOrEmpty(f.reporta_nombre)) p.Add("reportó " + f.reporta_nombre);
        if (f.ordenes > 0) p.Add(f.ordenes + " orden(es), última OT-" + f.ultima_ot_correlativo);
        litSubtitulo.Text = Server.HtmlEncode(string.Join(" · ", p.ToArray()));

        pnlResuelta.Visible = f.fal_fecha_solucion_utc != null;
        if (pnlResuelta.Visible)
            litResuelta.Text = "<strong>Resuelta</strong> el " + f.fal_fecha_solucion_utc.Value.ToString("dd-MM-yyyy HH:mm") + " con una acción definitiva. La ficha se consulta; diagnósticos y acciones quedan como historia.";

        pnlHistorial.Visible = f.provisorias_del_equipo >= 2;
        if (pnlHistorial.Visible)
            litHistorial.Text = "<strong>Este equipo acumula " + f.provisorias_del_equipo + " reparaciones provisorias.</strong> Conviene un diagnóstico definitivo antes de otro parche.";
    }

    private static void Seleccionar(RadComboBox2 cbo, string valor)
    {
        RadComboBoxItem item = cbo.FindItemByValue(valor ?? "");
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool resuelta = Id > 0 && Falla().fal_fecha_solucion_utc != null;
        bool puede = Token.Puede("REGISTRAR FALLA") && !resuelta;

        txtTitulo.ReadOnly = txtDescripcion.ReadOnly = txtConsecuencia.ReadOnly = !puede;
        cboCriticidad.Enabled = puede;
        rdbProdSi.Enabled = rdbProdNo.Enabled = puede;
        // Equipo, componente, deteccion y estado posterior se fijan al crear: el estado del equipo ya cambio.
        cboPlanta.Enabled = cboActivo.Enabled = cboComponente.Enabled = cboEstadoPosterior.Enabled = Id == 0;
        txtFechaDeteccion.ReadOnly = Id > 0;
        btnGuardar.Visible = puede;
        btnGenerarOT.Visible = Id > 0 && !resuelta && Token.Puede("CREAR ORDEN TRABAJO");
    }

    private static DateTime? Fecha(string texto, string campo)
    {
        string t = (texto ?? "").Trim();
        if (t.Length == 0) return null;
        DateTime d;
        string[] formatos = { "dd-MM-yyyy HH:mm", "dd-MM-yyyy", "dd/MM/yyyy HH:mm", "dd/MM/yyyy" };
        if (DateTime.TryParseExact(t, formatos, CultureInfo.InvariantCulture, DateTimeStyles.None, out d)) return d;
        throw new Exception("\"" + t + "\" no es una fecha válida en " + campo + " (dd-mm-aaaa hh:mm).");
    }

    protected void btnVolver_Click(object sender, EventArgs e)
    {
        Response.Redirect("~/View/Mantenimiento/Fallas/Fallas.aspx");
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            Falla f = new Falla { fal_id = Id };
            f.fal_titulo = txtTitulo.Text.Trim();
            f.fal_descripcion = string.IsNullOrEmpty(txtDescripcion.Text.Trim()) ? null : txtDescripcion.Text.Trim();
            f.fal_consecuencia = string.IsNullOrEmpty(txtConsecuencia.Text.Trim()) ? null : txtConsecuencia.Text.Trim();
            f.fal_criticidad_nivel = int.Parse(cboCriticidad.SelectedValue);
            f.fal_detuvo_produccion = rdbProdSi.Checked;
            if (Id == 0)
            {
                if (string.IsNullOrEmpty(cboActivo.SelectedValue)) throw new Exception("Indique el equipo que falló.");
                f.fal_activo = int.Parse(cboActivo.SelectedValue);
                if (!string.IsNullOrEmpty(cboComponente.SelectedValue)) f.fal_activo_componente = int.Parse(cboComponente.SelectedValue);
                if (!string.IsNullOrEmpty(cboEstadoPosterior.SelectedValue)) f.fal_activo_estado_posterior = int.Parse(cboEstadoPosterior.SelectedValue);
                f.fal_fecha_deteccion_utc = Fecha(txtFechaDeteccion.Text, "Detectada el");
            }

            FallaController c = new FallaController();
            bool nueva = Id == 0;
            Respuesta r = nueva ? c.Insert(f) : c.Update(f);
            if (!r.error)
            {
                if (nueva) Response.Redirect("~/View/Mantenimiento/Fallas/Falla.aspx?query=" + Cifrar("Id=" + r.codigo));
                _falla = null;
                Cabecera(Falla());
                Tools.tools.ClientAlert(r.detalle, "ok");
            }
            else Tools.tools.ClientAlert(r.detalle, "alerta");
        }
        catch (System.Threading.ThreadAbortException) { throw; }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    /// <summary>HU-123 / HU-110: la falla pide una correctiva de emergencia; su criticidad pasa a ser la prioridad.</summary>
    protected void btnGenerarOT_Click(object sender, EventArgs e)
    {
        try
        {
            Falla f = Falla();
            Activo a = new ActivoController().GetActivo(f.fal_activo);
            OrdenTrabajo o = new OrdenTrabajo
            {
                otr_titulo = "Falla: " + f.fal_titulo,
                otr_descripcion = f.fal_descripcion,
                otr_orden_trabajo_tipo = 2,          // correctiva
                otr_orden_trabajo_estrategia = 3,    // emergencia
                otr_orden_trabajo_prioridad = f.fal_criticidad_nivel,
                otr_cliente_instalacion = a.act_cliente_instalacion,
                otr_activo = f.fal_activo,
                otr_activo_componente = f.fal_activo_componente,
                otr_falla = f.fal_id,
                otr_requiere_permiso = false,
                otr_registro_posterior = false
            };
            Respuesta r = new OrdenTrabajoController().Insert(o);
            if (r.error) { Tools.tools.ClientAlert(r.detalle, "alerta"); return; }
            Response.Redirect("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx?query=" + Cifrar("Id=" + r.codigo));
        }
        catch (System.Threading.ThreadAbortException) { throw; }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    #region Diagnosticos

    private void CargarDiagnosticos()
    {
        List<FallaDiagnostico> lista = new FallaController().GetDiagnosticos(Id) ?? new List<FallaDiagnostico>();
        cboDiagnosticoAccion.Items.Clear();
        cboDiagnosticoAccion.Items.Add(new RadComboBoxItem("Sin diagnóstico asociado", ""));

        if (lista.Count == 0) { litDiagnosticos.Text = "<span class=\"sigma-inv-vacio\">Todavía no hay diagnósticos.</span>"; return; }
        StringBuilder sb = new StringBuilder("<div class=\"sigma-lista\">");
        foreach (FallaDiagnostico d in lista)
        {
            string texto = d.fdi_descripcion ?? "";
            string resumen = texto.Length > 60 ? texto.Substring(0, 60) + "…" : texto;
            cboDiagnosticoAccion.Items.Add(new RadComboBoxItem((d.fdi_es_definitivo ? "★ " : "") + resumen, d.fdi_id.ToString()));
            sb.Append("<div class=\"sigma-hilo-item\">")
              .Append(d.fdi_es_definitivo ? "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-star\"></i>Definitivo</span> " : "<span class=\"grid-estado-chip is-neutro\">Hipótesis</span> ")
              .Append(Server.HtmlEncode(texto))
              .Append("<div class=\"meta\">")
              .Append(string.IsNullOrEmpty(d.metodo_nombre) ? "" : Server.HtmlEncode(d.metodo_nombre) + " · ")
              .Append(d.fdi_confianza == null ? "" : "confianza " + d.fdi_confianza.Value.ToString("0") + "% · ")
              .Append(Server.HtmlEncode(d.diagnostica_nombre ?? ""))
              .Append(d.fdi_fecha_diagnostico_utc == null ? "" : " · " + d.fdi_fecha_diagnostico_utc.Value.ToString("dd-MM-yyyy HH:mm"))
              .Append("</div></div>");
        }
        litDiagnosticos.Text = sb.Append("</div>").ToString();
    }

    protected void btnDiagnostico_Click(object sender, EventArgs e)
    {
        Pestana(tabDiagnosticos, pvDiagnosticos);
        try
        {
            string texto = txtDiagnostico.Text.Trim();
            if (texto.Length == 0) throw new Exception("Escriba el diagnóstico.");
            FallaDiagnostico d = new FallaDiagnostico { fdi_falla = Id, fdi_descripcion = texto, fdi_es_definitivo = rdbDefSi.Checked };
            if (!string.IsNullOrEmpty(cboMetodo.SelectedValue)) d.fdi_diagnostico_metodo = int.Parse(cboMetodo.SelectedValue);
            if (!string.IsNullOrEmpty(txtConfianza.Text.Trim()))
            {
                int c;
                if (!int.TryParse(txtConfianza.Text.Trim(), out c) || c < 0 || c > 100) throw new Exception("La confianza es un porcentaje entre 0 y 100.");
                d.fdi_confianza = c;
            }
            Respuesta r = new FallaController().InsertDiagnostico(d);
            if (!r.error) { txtDiagnostico.Text = ""; txtConfianza.Text = ""; rdbDefNo.Checked = true; rdbDefSi.Checked = false; }
            Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    #endregion

    #region Acciones

    private void CargarAcciones()
    {
        cboOrdenAccion.Items.Clear();
        cboOrdenAccion.Items.Add(new RadComboBoxItem("Sin orden", ""));
        List<OrdenTrabajo> ordenes = new OrdenTrabajoController().GetOrdenes(new OrdenTrabajo { filtro_falla = Id }) ?? new List<OrdenTrabajo>();
        foreach (OrdenTrabajo o in ordenes) cboOrdenAccion.Items.Add(new RadComboBoxItem("OT-" + o.otr_correlativo + " · " + o.estado_nombre, o.otr_id.ToString()));

        List<FallaAccion> lista = new FallaController().GetAcciones(Id) ?? new List<FallaAccion>();
        if (lista.Count == 0) { litAcciones.Text = "<span class=\"sigma-inv-vacio\">Todavía no hay acciones.</span>"; return; }
        StringBuilder sb = new StringBuilder("<div class=\"sigma-lista\">");
        foreach (FallaAccion a in lista)
        {
            sb.Append("<div class=\"sigma-hilo-item\">")
              .Append(a.fac_es_definitiva ? "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-check-circle\"></i>Definitiva</span> " : "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-wrench-clock\"></i>Provisoria</span> ")
              .Append(Server.HtmlEncode(a.fac_descripcion ?? ""))
              .Append("<div class=\"meta\">")
              .Append(a.ot_correlativo == null ? "" : "OT-" + a.ot_correlativo + " · ")
              .Append(Server.HtmlEncode(a.ejecuta_nombre ?? ""))
              .Append(a.fac_fecha_accion_utc == null ? "" : " · " + a.fac_fecha_accion_utc.Value.ToString("dd-MM-yyyy HH:mm"))
              .Append("</div></div>");
        }
        litAcciones.Text = sb.Append("</div>").ToString();
    }

    protected void btnAccion_Click(object sender, EventArgs e)
    {
        Pestana(tabAcciones, pvAcciones);
        try
        {
            string texto = txtAccion.Text.Trim();
            if (texto.Length == 0) throw new Exception("Describa qué se hizo.");
            FallaAccion a = new FallaAccion { fac_falla = Id, fac_descripcion = texto, fac_es_definitiva = rdbAccDefinitiva.Checked };
            if (!string.IsNullOrEmpty(cboDiagnosticoAccion.SelectedValue)) a.fac_falla_diagnostico = int.Parse(cboDiagnosticoAccion.SelectedValue);
            if (!string.IsNullOrEmpty(cboOrdenAccion.SelectedValue)) a.fac_orden_trabajo = int.Parse(cboOrdenAccion.SelectedValue);
            a.fac_fecha_accion_utc = Fecha(txtFechaAccion.Text, "Cuándo");
            Respuesta r = new FallaController().InsertAccion(a);
            if (!r.error) { txtAccion.Text = ""; txtFechaAccion.Text = ""; _falla = null; Cabecera(Falla()); }
            Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    #endregion

    protected void GridIndisponibilidad_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;
        GridDataItem item = e.Item as GridDataItem;
        ActivoIndisponibilidad i = item.DataItem as ActivoIndisponibilidad;
        if (i == null) return;
        item["PERIODO"].Controls.Add(new Literal { Text = i.ain_fecha_inicio_utc.ToString("dd-MM-yyyy HH:mm") + " → " + (i.ain_fecha_fin_utc == null ? "<span class=\"grid-estado-chip is-alerta\">abierta</span>" : i.ain_fecha_fin_utc.Value.ToString("dd-MM-yyyy HH:mm")) });
        item["MINUTOS"].Controls.Add(new Literal { Text = "<strong>" + i.minutos_acumulados + "</strong>" });
        item["TIPO"].Controls.Add(new Literal
        {
            Text = (i.ain_planificada ? "<span class=\"grid-estado-chip is-neutro\">planificada</span>" : "<span class=\"grid-estado-chip is-alerta\">no planificada</span>")
                 + (i.ain_detuvo_produccion ? " <span class=\"grid-estado-chip is-advertencia\">detuvo producción</span>" : "")
        });
    }

    private void Pestana(RadTab tab, RadPageView vista) { tab.Selected = true; vista.Selected = true; }
}
