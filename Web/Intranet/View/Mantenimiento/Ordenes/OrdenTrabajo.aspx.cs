using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// La orden de trabajo como centro (HU-110, HU-112, HU-120, HU-124): Resumen,
/// Ficha, Asignacion, Pasos, Evidencias, Indisponibilidad y Cierre.
///
/// NADA RECARGA LA PAGINA
///   Todo el centro vive en un UpdatePanel y ningun boton se registra como
///   postback completo: guardar, asignar, registrar una detencion o cerrar
///   son idas y vueltas asincronas. Cambiar de pestaña ni siquiera llega al
///   servidor -lo hace sigma-orden.js- y la galeria de evidencias filtra y
///   muestra el detalle en el navegador, porque los datos ya estan en la
///   pagina. Antes cada gesto costaba una recarga entera con su menu, su
///   barra y sus consultas.
///
/// LO QUE ERAN MODALES AHORA ES PARTE DE LA PANTALLA
///   Asignar e indisponibilidad se hacian en ventanas aparte. Se ven mejor
///   al lado de lo que modifican: quien asigna necesita mirar al responsable
///   actual mientras elige, y quien registra una detencion, los periodos que
///   ya estan. OrdenTrabajoAsignacion.aspx se retira.
///
/// Las reglas -jerarquia del cierre, un solo responsable, registro posterior
/// con dos fechas- las decide el SP; aca se traduce el tipeo y se esconde lo
/// que no aplica.
/// </summary>
public partial class View_Mantenimiento_Ordenes_OrdenTrabajo : System.Web.UI.Page
{
    #region Estado

    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>El paso abierto en la pestaña Pasos; -1 si ninguno.</summary>
    public int PasoElegido
    {
        get { return ViewState["PasoElegido"] != null ? (int)ViewState["PasoElegido"] : 0; }
        set { ViewState["PasoElegido"] = value; }
    }

    private string _activoEditar = null, _areaEditar = null;
    private OrdenTrabajo _orden = null;
    private List<Dictionary<string, object>> _pasos = null;
    private List<OrdenTrabajoArchivo> _evidencias = null;

    private OrdenTrabajo Orden()
    {
        if (_orden == null) _orden = new OrdenTrabajoController().GetOrden(Id);
        return _orden;
    }

    private List<Dictionary<string, object>> Pasos()
    {
        if (_pasos == null) _pasos = LeerPasos();
        return _pasos;
    }

    private List<OrdenTrabajoArchivo> Evidencias()
    {
        if (_evidencias == null) _evidencias = new OrdenTrabajoArchivoController().GetEvidencias(Id);
        return _evidencias;
    }

    private string Cifrar(string texto) { return Server.UrlEncode(Tools.Crypto.Encrypt(texto)); }

    /// <summary>Deja abierta la pestaña que corresponde despues de un postback.</summary>
    private void Pestana(string nombre) { hdnTab.Value = nombre; }

    #endregion

    #region Ciclo de vida

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        switch (ctrl.ID)
        {
            case "cboPlanta":
                ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                ctrl.AppendDataBoundItems = true;
                ctrl.DataSource = new ClienteInstalacionController().GetClienteInstalaciones(
                    new ClienteInstalacion { filtro_cliente = cliente.ToString(), filtro_habilitado = "1" });
                ctrl.DataValueField = "cin_id";
                ctrl.DataTextField = "cin_nombre";
                ctrl.DataBind();
                break;

            case "cboUsuario":
                CargarCandidatos(ctrl);
                break;

            case "cboProveedor":
                {
                    ctrl.Items.Add(new RadComboBoxItem("Seleccione una empresa...", ""));
                    List<Proveedor> lista = new ProveedorController().GetProveedores(new Proveedor { filtro_habilitado = true, filtro_es_contratista = true });
                    if (lista != null) foreach (Proveedor p in lista) ctrl.Items.Add(new RadComboBoxItem(p.prv_razon_social, p.prv_id.ToString()));
                    break;
                }

            case "cboGrupo":
                {
                    ctrl.Items.Add(new RadComboBoxItem("Sin grupo", ""));
                    List<GrupoTrabajo> grupos = new GrupoTrabajoController().GetGruposTrabajo(new GrupoTrabajo { gtr_cliente = cliente, filtro_habilitado = true });
                    if (grupos != null) foreach (GrupoTrabajo g in grupos) ctrl.Items.Add(new RadComboBoxItem(g.gtr_codigo + " — " + g.gtr_nombre, g.gtr_id.ToString()));
                    break;
                }

            case "cboIndMotivo":
                // Indisponibilidad_Motivo: catalogo fijo del bloque 19.
                ctrl.Items.Add(new RadComboBoxItem("Seleccione un motivo", ""));
                ctrl.Items.Add(new RadComboBoxItem("Mantenimiento planificado", "1"));
                ctrl.Items.Add(new RadComboBoxItem("Falla", "2"));
                ctrl.Items.Add(new RadComboBoxItem("Espera de repuesto", "3"));
                ctrl.Items.Add(new RadComboBoxItem("Espera de técnico", "4"));
                ctrl.Items.Add(new RadComboBoxItem("Causa externa", "5"));
                ctrl.Items.Add(new RadComboBoxItem("Parada de producción", "6"));
                break;
        }
    }

    /// <summary>
    /// Los tecnicos, ORDENADOS por candidatura (SEL_ORDEN_TRABAJO_CANDIDATO):
    /// primero quien tiene todas las especialidades que la orden exige con su
    /// certificacion vigente, despues quien las tiene vencidas, al final el
    /// resto. Cada fila dice lo que sabe hacer.
    /// </summary>
    private void CargarCandidatos(RadComboBox2 ctrl)
    {
        ctrl.Items.Add(new RadComboBoxItem("Selecciona un técnico...", ""));

        if (Id == 0) return;

        System.Data.SqlClient.SqlCommand cmd = Conexion.GetCommand("SEL_ORDEN_TRABAJO_CANDIDATO");
        try
        {
            cmd.Parameters.AddWithValue("@CLIENTE", SitioBase.Session.ClienteId());
            cmd.Parameters.AddWithValue("@ORDEN", Id);

            using (System.Data.SqlClient.SqlDataReader dr = cmd.ExecuteReader())
            {
                while (dr.Read())
                {
                    string nombre = Convert.ToString(dr["USU_NOMBRE"]).Trim();
                    string perfiles = Convert.ToString(dr["PERFILES"]);
                    string especialidades = Convert.ToString(dr["ESPECIALIDADES"]);
                    bool candidato = Convert.ToInt32(dr["CANDIDATO"]) == 1;
                    string vencida = dr["CERTIFICACION_VENCIDA"] == DBNull.Value ? "" : Convert.ToString(dr["CERTIFICACION_VENCIDA"]);

                    if (candidato) nombre = (string.IsNullOrEmpty(vencida) ? "★ Candidato · " : "⚠ Candidato (certificación vencida) · ") + nombre;
                    if (!string.IsNullOrEmpty(especialidades)) nombre += "  ·  " + especialidades;
                    else if (!string.IsNullOrEmpty(perfiles)) nombre += "  ·  " + perfiles;

                    ctrl.Items.Add(new RadComboBoxItem(nombre, Convert.ToString(dr["USU_ID"])));
                }
            }
        }
        finally
        {
            cmd.Connection.Close();
            cmd.Dispose();
        }
    }

    protected void cboPlanta_SelectedIndexChanged(object sender, EventArgs e) { Pestana("ficha"); }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        CargarDependientes();
        Pintar();
        Bloqueo();

        /* A proposito NO se registra ningun boton como postback completo: esta
           pantalla no recarga nunca. Las descargas, que son lo unico que no
           sobrevive a un postback asincrono, no viven aca. */
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id == 0)
        {
            litTitulo.Text = "Nueva orden de trabajo";
            litSubtitulo.Text = "Guarde la ficha y aparecerán asignación, pasos, evidencias, indisponibilidad y cierre.";
            hdnTab.Value = "ficha";
            txtIndInicio.Text = global::SitioBase.Hora.Ahora.ToString("dd-MM-yyyy HH:mm");
            return;
        }

        OrdenTrabajo o = Orden();

        txtTitulo.Text = o.otr_titulo;
        txtDescripcion.Text = o.otr_descripcion;
        txtNotas.Text = o.otr_notas;
        Seleccionar(cboTipo, o.otr_orden_trabajo_tipo.ToString());
        Seleccionar(cboEstrategia, o.otr_orden_trabajo_estrategia.ToString());
        Seleccionar(cboPrioridad, o.otr_orden_trabajo_prioridad.ToString());
        Seleccionar(cboPlanta, o.otr_cliente_instalacion.ToString());
        if (o.otr_activo != null) _activoEditar = o.otr_activo.Value.ToString();
        if (o.otr_instalacion_area != null) _areaEditar = o.otr_instalacion_area.Value.ToString();
        txtFechaProgramada.Text = o.otr_fecha_programada_utc == null ? "" : o.otr_fecha_programada_utc.Value.ToString("dd-MM-yyyy HH:mm");
        txtDuracion.Text = o.otr_duracion_estimada_minuto == null ? "" : o.otr_duracion_estimada_minuto.ToString();
        rdbPermisoSi.Checked = o.otr_requiere_permiso; rdbPermisoNo.Checked = !o.otr_requiere_permiso;
        rdbPosteriorSi.Checked = o.otr_registro_posterior; rdbPosteriorNo.Checked = !o.otr_registro_posterior;
        txtFechaOcurrencia.Text = o.otr_fecha_ocurrencia == null ? "" : o.otr_fecha_ocurrencia.Value.ToString("dd-MM-yyyy HH:mm");
        txtResultadoCierre.Text = o.otr_resultado;
        if (o.otr_cierre_motivo != null) Seleccionar(cboMotivoCierre, o.otr_cierre_motivo.Value.ToString());

        txtIndInicio.Text = global::SitioBase.Hora.Ahora.ToString("dd-MM-yyyy HH:mm");
        Seleccionar(cboIndMotivo, "1");

        wucAuditoria.Mostrar(o.usuario_creacion_nombre, o.otr_fecha_creacion, o.usuario_actualizacion_nombre, o.otr_fecha_actualizacion);
    }

    private void CargarDependientes()
    {
        string selA = string.IsNullOrEmpty(_activoEditar) ? cboActivo.SelectedValue : _activoEditar;
        string selR = string.IsNullOrEmpty(_areaEditar) ? cboArea.SelectedValue : _areaEditar;
        int cliente = SitioBase.Session.ClienteId(), planta;
        int.TryParse(cboPlanta.SelectedValue, out planta);

        cboActivo.Items.Clear();
        cboActivo.Items.Add(new RadComboBoxItem("Sin equipo (orden sobre un área)", ""));
        Activo fa = new Activo { act_cliente = cliente, filtro_habilitado = true };
        if (planta > 0) fa.filtro_cliente_instalacion = planta;
        List<Activo> activos = new ActivoController().GetActivos(fa);
        if (activos != null) foreach (Activo a in activos) cboActivo.Items.Add(new RadComboBoxItem(a.act_codigo + " · " + a.act_nombre, a.act_id.ToString()));

        cboArea.Items.Clear();
        cboArea.Items.Add(new RadComboBoxItem("Sin área", ""));
        if (planta > 0)
        {
            List<InstalacionArea> areas = new InstalacionAreaController().GetInstalacionAreas(
                new InstalacionArea { iar_cliente = cliente, iar_cliente_instalacion = planta, filtro_habilitado = true });
            if (areas != null) foreach (InstalacionArea a in areas) cboArea.Items.Add(new RadComboBoxItem(string.IsNullOrEmpty(a.ruta) ? a.iar_nombre : a.ruta, a.iar_id.ToString()));
        }

        RadComboBoxItem ia = cboActivo.FindItemByValue(selA ?? ""); if (ia != null) ia.Selected = true;
        RadComboBoxItem ir = cboArea.FindItemByValue(selR ?? ""); if (ir != null) ir.Selected = true;
    }

    private static void Seleccionar(RadComboBox2 cbo, string valor)
    {
        RadComboBoxItem item = cbo.FindItemByValue(valor ?? "");
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool cerrada = Id > 0 && Orden().otr_orden_trabajo_estado == 4;
        bool puede = Token.Puede("CREAR ORDEN TRABAJO") && !cerrada;

        txtTitulo.ReadOnly = txtDescripcion.ReadOnly = txtNotas.ReadOnly = txtFechaProgramada.ReadOnly =
            txtDuracion.ReadOnly = txtFechaOcurrencia.ReadOnly = !puede;
        cboEstrategia.ReadOnly = cboPrioridad.ReadOnly = !puede;

        // Donde, el tipo y el registro posterior se fijan al crear: despues la
        // orden ya tiene historia colgando de esos datos.
        cboPlanta.Enabled = cboActivo.Enabled = cboArea.Enabled = Id == 0;
        cboTipo.Enabled = Id == 0;
        rdbPosteriorSi.Enabled = rdbPosteriorNo.Enabled = Id == 0;
        txtFechaOcurrencia.ReadOnly = Id > 0;
        rdbPermisoSi.Enabled = rdbPermisoNo.Enabled = puede;
        btnGuardar.Visible = puede;

        // Las pestañas que no existen sin orden guardada las esconde el JS con
        // este dato; sin el, "Asignación" abriria un panel vacio.
        hdnNueva.Value = Id == 0 ? "1" : "0";

        bool puedeAsignar = Token.Puede("CREAR ORDEN TRABAJO") && !cerrada;
        pnlNuevaAsignacion.Visible = Id > 0 && puedeAsignar;

        pnlFormIndisp.Visible = Id > 0 && Token.Puede("REGISTRAR FALLA") && Orden().otr_activo != null && !cerrada;

        bool puedeCerrar = Id > 0 && Token.PuedeFuncion("Cerrar") && !cerrada;
        pnlFormCierre.Visible = Id > 0;
        pnlFirma.Visible = puedeCerrar;
        txtResultadoCierre.ReadOnly = !puedeCerrar;
        cboMotivoCierre.ReadOnly = !puedeCerrar;
    }

    #endregion

    #region Pintado

    private void Pintar()
    {
        if (Id == 0)
        {
            litNumero.Text = "Nueva";
            litCabTitulo.Text = "Nueva orden de trabajo";
            litCabSub.Text = "Complete la ficha para crearla.";
            return;
        }

        OrdenTrabajo o = Orden();

        Cabecera(o);
        PintarResumen(o);
        PintarContexto(o);
        PintarAsignacion(o);
        PintarPasos();
        PintarEvidencias();
        PintarIndisponibilidad();
        PintarCierre(o);
    }

    private void Cabecera(OrdenTrabajo o)
    {
        /* El master pinta un titulo por pantalla y la orden ya trae el suyo
           en la tarjeta de arriba, con su numero y sus chips. Repetirlo era
           leer lo mismo dos veces en dos tamaños distintos. */
        litTitulo.Text = "Órdenes de trabajo";
        litSubtitulo.Text = "";

        litNumero.Text = "OT-" + o.otr_correlativo;
        litCabTitulo.Text = Server.HtmlEncode(o.otr_titulo);

        List<string> donde = new List<string>();
        if (!string.IsNullOrEmpty(o.activo_codigo)) donde.Add(o.activo_codigo);
        if (!string.IsNullOrEmpty(o.activo_nombre)) donde.Add(o.activo_nombre);
        else if (!string.IsNullOrEmpty(o.area_nombre)) donde.Add(o.area_nombre);
        if (!string.IsNullOrEmpty(o.planta_nombre)) donde.Add(o.planta_nombre);
        litCabSub.Text = Server.HtmlEncode(string.Join(" · ", donde.ToArray()));

        StringBuilder chips = new StringBuilder();
        chips.Append(Chip(ClaseEstado(o.estado_codigo), IconoEstado(o.estado_codigo), o.estado_nombre));
        chips.Append(Chip("es-tipo", "mdi-wrench-outline", o.tipo_nombre));
        chips.Append(Chip("es-estrategia", "mdi-alarm-light-outline", o.estrategia_nombre));
        chips.Append(Chip(ClasePrioridad(o.prioridad_codigo), "mdi-chart-bar", o.prioridad_nombre));
        litChips.Text = chips.ToString();
    }

    private string Chip(string clase, string icono, string texto)
    {
        return "<span class=\"sg-ot-chip " + clase + "\"><i class=\"mdi " + icono + "\"></i>" +
               Server.HtmlEncode(texto ?? "") + "</span>";
    }

    private static string ClaseEstado(string codigo)
    {
        switch ((codigo ?? "").ToUpper())
        {
            case "EJECUCION": return "es-ejecucion";
            case "CERRADA": return "es-cerrada";
            case "ESPERA CIERRE": return "es-espera";
            case "ANULADA": return "es-anulada";
            default: return "es-abierta";
        }
    }

    private static string IconoEstado(string codigo)
    {
        switch ((codigo ?? "").ToUpper())
        {
            case "EJECUCION": return "mdi-play-circle-outline";
            case "CERRADA": return "mdi-check-circle-outline";
            case "ESPERA CIERRE": return "mdi-clock-outline";
            case "ANULADA": return "mdi-close-circle-outline";
            default: return "mdi-file-document-outline";
        }
    }

    private static string ClasePrioridad(string codigo)
    {
        switch ((codigo ?? "").ToUpper())
        {
            case "CRITICA": return "es-critica";
            case "ALTA": return "es-alta";
            case "BAJA": return "es-baja";
            default: return "es-media";
        }
    }

    /// <summary>
    /// El resumen: lo que alguien necesita para saber como va la orden sin
    /// abrir ninguna otra pestaña. Es todo de lectura, asi que se arma de una
    /// vez en vez de repartirlo en veinte controles.
    /// </summary>
    private void PintarResumen(OrdenTrabajo o)
    {
        List<Dictionary<string, object>> pasos = Pasos();
        int resueltos = pasos.Count(Resuelto);
        int avance = pasos.Count > 0 ? (int)Math.Round(resueltos * 100.0 / pasos.Count) : 0;

        StringBuilder s = new StringBuilder();

        // ---- la fila de indicadores ----
        s.Append("<div class=\"sg-ot-kpis\">");
        s.Append(Kpi("mdi-checkbox-marked-circle-outline", resueltos + " de " + pasos.Count, "Pasos resueltos"));
        s.Append(Kpi("mdi-account-outline", Quien(o), "Responsable"));
        s.Append(Kpi("mdi-calendar-outline",
                     o.otr_fecha_programada_utc == null ? "Sin programar" : o.otr_fecha_programada_utc.Value.ToString("dd MMM yyyy · HH:mm"),
                     "Programada"));
        s.Append(Kpi("mdi-clock-outline",
                     o.indisponibilidades == 0 ? "Sin registros" : o.indisponibilidades + " período(s)", "Indisponibilidad"));
        s.Append("</div>");

        s.Append("<div class=\"sg-ot-cols\"><div class=\"sg-ot-col\">");

        // ---- el trabajo ----
        s.Append("<div class=\"sg-ot-card\"><header class=\"sg-ot-card-cab\">")
         .Append("<span class=\"sg-ot-card-ico\"><i class=\"mdi mdi-file-document-outline\"></i></span>")
         .Append("<h3>Trabajo a realizar</h3></header>")
         .Append("<p class=\"sg-ot-texto es-grande\">")
         .Append(string.IsNullOrEmpty(o.otr_descripcion) ? "<span class=\"sg-ot-vacio-txt\">Sin descripción.</span>" : Server.HtmlEncode(o.otr_descripcion))
         .Append("</p></div>");

        // ---- el avance ----
        s.Append("<div class=\"sg-ot-card\"><header class=\"sg-ot-card-cab\">")
         .Append("<span class=\"sg-ot-card-ico\"><i class=\"mdi mdi-chart-timeline-variant\"></i></span>")
         .Append("<h3>Avance de la intervención</h3>")
         .Append("<span class=\"sg-ot-card-acc sg-ot-avance-pct\">").Append(avance).Append("% completado</span></header>");

        s.Append("<div class=\"sg-ot-barra\"><span style=\"width:").Append(avance).Append("%\"></span></div>");

        if (pasos.Count == 0)
            s.Append("<p class=\"sg-ot-vacio-txt\">Esta orden todavía no tiene pasos.</p>");
        else
        {
            s.Append("<div class=\"sg-ot-avance-lista\">");
            foreach (Dictionary<string, object> p in pasos)
            {
                string cod = Convert.ToString(p["RESULTADO_CODIGO"]);
                s.Append("<div class=\"sg-ot-avance-fila\">")
                 .Append("<span class=\"sg-ot-paso-num ").Append(ClasePaso(cod)).Append("\">").Append(p["otp_orden"]).Append("</span>")
                 .Append("<span class=\"sg-ot-avance-nom\">").Append(Server.HtmlEncode(Convert.ToString(p["otp_nombre"]))).Append("</span>")
                 .Append("<span class=\"sg-ot-estado ").Append(ClasePaso(cod)).Append("\"><i class=\"mdi ").Append(IconoPaso(cod)).Append("\"></i>")
                 .Append(Server.HtmlEncode(EstadoPaso(p))).Append("</span></div>");
            }
            s.Append("</div>");
        }
        s.Append("</div>");

        if (o.otr_requiere_permiso)
            s.Append("<a class=\"sg-ot-banner\" href=\"#\" data-ir=\"ficha\"><span class=\"sg-ot-banner-ico\">")
             .Append("<i class=\"mdi mdi-lock-outline\"></i></span><strong>Permiso de trabajo requerido</strong>")
             .Append("<span class=\"sg-ot-banner-sep\">·</span><span>Revisar permiso</span>")
             .Append("<i class=\"mdi mdi-chevron-right\"></i></a>");

        s.Append("</div><aside class=\"sg-ot-lado\">");

        // ---- responsable ----
        s.Append("<div class=\"sg-ot-card\"><header class=\"sg-ot-card-cab\">")
         .Append("<span class=\"sg-ot-card-ico\"><i class=\"mdi mdi-account-outline\"></i></span>")
         .Append("<h3>Responsable</h3>")
         .Append("<a class=\"sg-ot-card-acc sg-ot-link\" href=\"#\" data-ir=\"asignacion\">Ver asignación <i class=\"mdi mdi-arrow-right\"></i></a></header>");

        if (string.IsNullOrEmpty(Quien(o)) || Quien(o) == "Sin asignar")
            s.Append("<p class=\"sg-ot-vacio-txt\">Todavía no hay un responsable asignado.</p>");
        else
            s.Append("<div class=\"sg-ot-persona\"><span class=\"sg-ot-avatar es-grande\">").Append(Iniciales(Quien(o)))
             .Append("</span><div class=\"sg-ot-persona-txt\"><span class=\"sg-ot-persona-nom es-grande\">")
             .Append(Server.HtmlEncode(Quien(o))).Append("</span></div></div>");

        s.Append("</div>");

        // ---- antes del cierre ----
        s.Append("<div class=\"sg-ot-card\"><header class=\"sg-ot-card-cab\">")
         .Append("<span class=\"sg-ot-card-ico\"><i class=\"mdi mdi-clipboard-check-outline\"></i></span>")
         .Append("<h3>Antes del cierre</h3>")
         .Append("<a class=\"sg-ot-card-acc sg-ot-link\" href=\"#\" data-ir=\"cierre\">Revisar requisitos <i class=\"mdi mdi-arrow-right\"></i></a></header>");

        List<string> faltan = Requisitos(o, pasos, false);
        if (faltan.Count == 0)
            s.Append("<div class=\"sg-ot-aviso es-ok\"><i class=\"mdi mdi-check-circle-outline\"></i>Todo listo para cerrar.</div>");
        else
            foreach (string f in faltan)
                s.Append("<div class=\"sg-ot-aviso\"><i class=\"mdi mdi-alert-outline\"></i>").Append(f).Append("</div>");

        s.Append("</div>");

        // ---- evidencias ----
        List<OrdenTrabajoArchivo> ev = Evidencias();
        s.Append("<div class=\"sg-ot-card\"><header class=\"sg-ot-card-cab\">")
         .Append("<span class=\"sg-ot-card-ico\"><i class=\"mdi mdi-image-multiple-outline\"></i></span>")
         .Append("<h3>Evidencias desde la app</h3>")
         .Append("<a class=\"sg-ot-card-acc sg-ot-link\" href=\"#\" data-ir=\"evidencias\">Ver evidencias <i class=\"mdi mdi-arrow-right\"></i></a></header>");

        if (ev.Count == 0)
            s.Append("<p class=\"sg-ot-vacio-txt\">Todavía no llegaron evidencias del terreno.</p>");
        else
        {
            s.Append("<div class=\"sg-ot-miniaturas\">");
            foreach (OrdenTrabajoArchivo a in ev.Where(x => x.es_imagen).Take(3))
                s.Append("<span class=\"sg-ot-mini\"><img src=\"").Append(UrlArchivo(a.arc_id)).Append("\" alt=\"")
                 .Append(Server.HtmlEncode(a.etiqueta)).Append("\" /></span>");
            s.Append("</div>");
        }
        s.Append("</div>");

        s.Append("</aside></div>");

        litResumen.Text = s.ToString();
    }

    private string Kpi(string icono, string valor, string etiqueta)
    {
        return "<div class=\"sg-ot-kpi\"><span class=\"sg-ot-kpi-ico\"><i class=\"mdi " + icono + "\"></i></span>" +
               "<div><span class=\"sg-ot-kpi-valor\">" + Server.HtmlEncode(valor ?? "") + "</span>" +
               "<span class=\"sg-ot-kpi-etq\">" + Server.HtmlEncode(etiqueta) + "</span></div></div>";
    }

    private static string Quien(OrdenTrabajo o)
    {
        if (!string.IsNullOrEmpty(o.responsable_nombre)) return o.responsable_nombre;
        if (!string.IsNullOrEmpty(o.responsable_proveedor)) return o.responsable_proveedor;
        return "Sin asignar";
    }

    public static string Iniciales(string nombre)
    {
        string[] partes = (nombre ?? "").Trim().Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
        if (partes.Length == 0) return "?";
        if (partes.Length == 1) return partes[0].Substring(0, 1).ToUpper();
        return (partes[0].Substring(0, 1) + partes[1].Substring(0, 1)).ToUpper();
    }

    private string UrlArchivo(int id)
    {
        return ResolveUrl("~/View/Comun/Archivos/VerArchivo.aspx") + "?query=" + Cifrar("Id=" + id + "&Modo=VER");
    }

    private void PintarContexto(OrdenTrabajo o)
    {
        StringBuilder s = new StringBuilder();

        s.Append(Dato("mdi-account-outline", "Responsable", Quien(o)));
        s.Append("<div class=\"sg-ot-dato\"><span class=\"sg-ot-dato-ico\"><i class=\"mdi mdi-shield-outline\"></i></span>")
         .Append("<div><span class=\"sg-ot-dato-etq\">Estado</span>")
         .Append(Chip(ClaseEstado(o.estado_codigo), IconoEstado(o.estado_codigo), o.estado_nombre))
         .Append("</div></div>");
        s.Append(Dato("mdi-source-branch", "Origen", o.origen_nombre));
        if (!string.IsNullOrEmpty(o.plan_codigo)) s.Append(Dato("mdi-calendar-text-outline", "Plan", o.plan_codigo));
        if (!string.IsNullOrEmpty(o.falla_titulo)) s.Append(Dato("mdi-alert-outline", "Falla", o.falla_titulo));

        litContexto.Text = s.ToString();
    }

    private string Dato(string icono, string etiqueta, string valor)
    {
        return "<div class=\"sg-ot-dato\"><span class=\"sg-ot-dato-ico\"><i class=\"mdi " + icono + "\"></i></span>" +
               "<div><span class=\"sg-ot-dato-etq\">" + Server.HtmlEncode(etiqueta) + "</span>" +
               "<span class=\"sg-ot-dato-val\">" + Server.HtmlEncode(string.IsNullOrEmpty(valor) ? "—" : valor) + "</span></div></div>";
    }

    #endregion

    #region Asignacion (HU-112)

    private void PintarAsignacion(OrdenTrabajo o)
    {
        List<OrdenTrabajoAsignacion> lista = new OrdenTrabajoController().GetAsignaciones(Id) ?? new List<OrdenTrabajoAsignacion>();

        OrdenTrabajoAsignacion resp = lista.FirstOrDefault(a => a.ota_es_responsable);

        if (resp == null)
            litResponsable.Text = "<div class=\"sg-ot-vacio es-chico\"><i class=\"mdi mdi-account-question-outline\"></i>" +
                                  "<p>Sin responsable</p><span>Asigne a alguien para que la orden avance.</span></div>";
        else
        {
            string nombre = resp.ota_usuario != null ? resp.usuario_nombre : resp.proveedor_nombre;
            StringBuilder s = new StringBuilder();
            s.Append("<div class=\"sg-ot-responsable\">")
             .Append("<span class=\"sg-ot-avatar es-grande\">").Append(Iniciales(nombre)).Append("</span>")
             .Append("<div class=\"sg-ot-persona-txt\"><span class=\"sg-ot-persona-nom es-grande\">").Append(Server.HtmlEncode(nombre))
             .Append("</span><span class=\"sg-ot-chip es-ejecucion\"><i class=\"mdi mdi-check-circle-outline\"></i>Responsable</span>")
             .Append("<span class=\"sg-ot-persona-meta\">")
             .Append(resp.ota_fecha_asignacion_utc == null ? "" : "Asignada " + resp.ota_fecha_asignacion_utc.Value.ToString("dd MMM yyyy · HH:mm"))
             .Append(string.IsNullOrEmpty(resp.asignado_por_nombre) ? "" : " · por " + Server.HtmlEncode(resp.asignado_por_nombre))
             .Append("</span></div>")
             .Append("<div class=\"sg-ot-responsable-datos\">")
             .Append(Dato("mdi-account-group-outline", "Grupo", resp.grupo_nombre))
             .Append(Dato("mdi-note-text-outline", "Observación", resp.ota_observacion))
             .Append("</div></div>");
            litResponsable.Text = s.ToString();
        }

        List<OrdenTrabajoAsignacion> apoyos = lista.Where(a => !a.ota_es_responsable).ToList();

        rptApoyos.DataSource = apoyos.Select(a => new
        {
            id = a.ota_id,
            iniciales = Iniciales(a.ota_usuario != null ? a.usuario_nombre : a.proveedor_nombre),
            nombre = a.ota_usuario != null ? a.usuario_nombre : a.proveedor_nombre,
            meta = Server.HtmlEncode(
                (a.ota_usuario != null ? (string.IsNullOrEmpty(a.especialidades) ? "Técnico" : a.especialidades) : "Empresa externa") +
                (a.ota_fecha_asignacion_utc == null ? "" : " · " + a.ota_fecha_asignacion_utc.Value.ToString("dd MMM yyyy")))
        }).ToList();
        rptApoyos.DataBind();

        pnlSinApoyos.Visible = apoyos.Count == 0;
    }

    protected void rdbQuien_CheckedChanged(object sender, EventArgs e)
    {
        Pestana("asignacion");
        pnlTecnico.Visible = rdbQuienTecnico.Checked;
        pnlEmpresa.Visible = rdbQuienEmpresa.Checked;
    }

    protected void btnAsignar_Click(object sender, EventArgs e)
    {
        Pestana("asignacion");
        try
        {
            OrdenTrabajoAsignacion a = new OrdenTrabajoAsignacion { ota_orden_trabajo = Id };

            if (rdbQuienTecnico.Checked)
            {
                if (string.IsNullOrEmpty(cboUsuario.SelectedValue)) throw new Exception("Elija el técnico que va a asignar.");
                a.ota_usuario = int.Parse(cboUsuario.SelectedValue);
            }
            else
            {
                if (string.IsNullOrEmpty(cboProveedor.SelectedValue)) throw new Exception("Elija la empresa externa que va a asignar.");
                a.ota_proveedor = int.Parse(cboProveedor.SelectedValue);
            }

            if (!string.IsNullOrEmpty(cboGrupo.SelectedValue)) a.ota_grupo_trabajo = int.Parse(cboGrupo.SelectedValue);
            a.ota_es_responsable = cboRol.SelectedValue == "1";
            a.ota_observacion = string.IsNullOrEmpty(txtObservacion.Text.Trim()) ? null : txtObservacion.Text.Trim();

            Respuesta r = new OrdenTrabajoController().Asignar(a);

            if (!r.error)
            {
                cboUsuario.ClearSelection();
                cboProveedor.ClearSelection();
                txtObservacion.Text = "";
                _orden = null;
            }

            Tools.tools.ClientAlert(r.detalle, r.error || r.detalle.Contains("advertencia") ? "alerta" : "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    protected void rptAsignaciones_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        Pestana("asignacion");
        try
        {
            int id;
            if (!int.TryParse(Convert.ToString(e.CommandArgument), out id)) return;

            if (e.CommandName == "quitar")
            {
                Respuesta r = new OrdenTrabajoController().QuitarAsignacion(id);
                _orden = null;
                Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
                return;
            }

            if (e.CommandName == "responsable")
            {
                /* Nombrar responsable a un apoyo es volver a asignarlo con el
                   rol cambiado: el SP es el que sabe pasar al anterior a
                   apoyo, y repetir esa regla aca seria la segunda copia -la
                   que se olvida de actualizar-. */
                OrdenTrabajoAsignacion vieja = (new OrdenTrabajoController().GetAsignaciones(Id) ?? new List<OrdenTrabajoAsignacion>())
                    .FirstOrDefault(x => x.ota_id == id);

                if (vieja == null) throw new Exception("La asignación ya no existe.");

                OrdenTrabajoAsignacion nueva = new OrdenTrabajoAsignacion
                {
                    ota_orden_trabajo = Id,
                    ota_usuario = vieja.ota_usuario,
                    ota_proveedor = vieja.ota_proveedor,
                    ota_grupo_trabajo = vieja.ota_grupo_trabajo,
                    ota_observacion = vieja.ota_observacion,
                    ota_es_responsable = true
                };

                Respuesta r = new OrdenTrabajoController().Asignar(nueva);
                _orden = null;
                Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
            }
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    #endregion

    #region Pasos (lectura)

    private void PintarPasos()
    {
        List<Dictionary<string, object>> pasos = Pasos();

        int resueltos = pasos.Count(Resuelto);
        int avance = pasos.Count > 0 ? (int)Math.Round(resueltos * 100.0 / pasos.Count) : 0;

        litPasosAvance.Text =
            "<div class=\"sg-ot-avance\">" + Anillo(avance) +
            "<div class=\"sg-ot-avance-num\"><strong>" + resueltos + " de " + pasos.Count + "</strong><span>resueltos</span></div>" +
            "<div class=\"sg-ot-avance-num\"><strong>" + (pasos.Count - resueltos) + "</strong><span>pendientes</span></div></div>";

        if (PasoElegido >= pasos.Count) PasoElegido = 0;

        rptPasos.DataSource = pasos.Select((p, i) => new
        {
            indice = i,
            numero = Convert.ToString(p["otp_orden"]),
            nombre = Convert.ToString(p["otp_nombre"]),
            estado = EstadoPaso(p),
            clase = ClasePaso(Convert.ToString(p["RESULTADO_CODIGO"])),
            icono = IconoPaso(Convert.ToString(p["RESULTADO_CODIGO"])),
            elegido = i == PasoElegido
        }).ToList();
        rptPasos.DataBind();

        pnlSinPasos.Visible = pasos.Count == 0;

        litPasoDetalle.Text = pasos.Count == 0
            ? "<div class=\"sg-ot-vacio\"><i class=\"mdi mdi-gesture-tap-button\"></i><p>Sin pasos que mostrar</p></div>"
            : DetallePaso(pasos[PasoElegido]);
    }

    /// <summary>El anillo de avance: un circulo SVG con su trazo recortado.</summary>
    private static string Anillo(int porcentaje)
    {
        const double R = 22, C = 2 * Math.PI * R;
        double largo = C * porcentaje / 100.0;

        return "<span class=\"sg-ot-anillo\"><svg viewBox=\"0 0 52 52\" width=\"52\" height=\"52\">" +
               "<circle cx=\"26\" cy=\"26\" r=\"22\" fill=\"none\" stroke=\"#ece9fb\" stroke-width=\"5\" />" +
               "<circle cx=\"26\" cy=\"26\" r=\"22\" fill=\"none\" stroke=\"#6C5CFF\" stroke-width=\"5\" stroke-linecap=\"round\" " +
               "stroke-dasharray=\"" + largo.ToString("0.##", CultureInfo.InvariantCulture) + " " + C.ToString("0.##", CultureInfo.InvariantCulture) + "\" " +
               "transform=\"rotate(-90 26 26)\" /></svg><b>" + porcentaje + "%</b></span>";
    }

    /// <summary>
    /// Un paso esta resuelto cuando el tecnico lo marco con ALGO distinto de
    /// "pendiente". Contar los que traen codigo no sirve: el pendiente
    /// tambien trae el suyo, y con esa cuenta una orden recien abierta se
    /// mostraba al 100% con todos sus pasos en "Pendiente" al lado.
    /// </summary>
    private static bool Resuelto(Dictionary<string, object> p)
    {
        string codigo = Convert.ToString(p["RESULTADO_CODIGO"]).Trim().ToUpper();
        return codigo.Length > 0 && codigo != "PENDIENTE";
    }

    private static string EstadoPaso(Dictionary<string, object> p)
    {
        string nombre = Convert.ToString(p["RESULTADO_NOMBRE"]);
        return string.IsNullOrEmpty(nombre) ? "Pendiente" : nombre;
    }

    private static string ClasePaso(string codigo)
    {
        switch ((codigo ?? "").ToUpper())
        {
            case "CONFORME": return "es-conforme";
            case "NO CONFORME": return "es-noconforme";
            case "NO APLICA": return "es-noaplica";
            default: return "es-pendiente";
        }
    }

    private static string IconoPaso(string codigo)
    {
        switch ((codigo ?? "").ToUpper())
        {
            case "CONFORME": return "mdi-check-circle-outline";
            case "NO CONFORME": return "mdi-alert-circle-outline";
            case "NO APLICA": return "mdi-minus-circle-outline";
            default: return "mdi-clock-outline";
        }
    }

    private string DetallePaso(Dictionary<string, object> p)
    {
        string cod = Convert.ToString(p["RESULTADO_CODIGO"]);
        int pasoId = Convert.ToInt32(p["otp_id"]);

        StringBuilder s = new StringBuilder();

        s.Append("<header class=\"sg-ot-card-cab\"><span class=\"sg-ot-paso-num es-grande ").Append(ClasePaso(cod)).Append("\">")
         .Append(p["otp_orden"]).Append("</span><h3>").Append(Server.HtmlEncode(Convert.ToString(p["otp_nombre"])))
         .Append("</h3><span class=\"sg-ot-card-acc sg-ot-estado ").Append(ClasePaso(cod)).Append("\"><i class=\"mdi ")
         .Append(IconoPaso(cod)).Append("\"></i>").Append(Server.HtmlEncode(EstadoPaso(p))).Append("</span></header>");

        s.Append("<div class=\"sg-ot-datos\">");
        s.Append(Dato("mdi-account-outline", "Registrado por", Convert.ToString(p["EJECUTOR_NOMBRE"])));
        s.Append(Dato("mdi-calendar-outline", "Fecha",
                 p["otp_fecha_ejecucion_utc"] == null ? "" : ((DateTime)p["otp_fecha_ejecucion_utc"]).ToString("dd MMM yyyy · HH:mm")));
        s.Append("</div>");

        s.Append(Dato("mdi-note-text-outline", "Observación", Convert.ToString(p["otp_resultado"])));

        if (!string.IsNullOrEmpty(Convert.ToString(p["otp_descripcion"])))
            s.Append(Dato("mdi-text-box-outline", "Instrucción", Convert.ToString(p["otp_descripcion"])));

        // ---- evidencias del paso ----
        List<OrdenTrabajoArchivo> ev = Evidencias().Where(x => x.paso_id == pasoId).ToList();

        s.Append("<div class=\"sg-ot-sub-titulo es-con-acc\">Evidencias del paso");
        if (ev.Count > 0) s.Append("<a href=\"#\" class=\"sg-ot-link\" data-ir=\"evidencias\">Consultar evidencias <i class=\"mdi mdi-arrow-right\"></i></a>");
        s.Append("</div>");

        if (ev.Count == 0)
            s.Append("<p class=\"sg-ot-vacio-txt\">Este paso no tiene evidencias.</p>");
        else
        {
            s.Append("<div class=\"sg-ot-miniaturas\">");
            foreach (OrdenTrabajoArchivo a in ev.Take(4))
                s.Append(a.es_imagen
                    ? "<span class=\"sg-ot-mini\"><img src=\"" + UrlArchivo(a.arc_id) + "\" alt=\"" + Server.HtmlEncode(a.etiqueta) + "\" /></span>"
                    : "<span class=\"sg-ot-mini es-doc\"><i class=\"mdi " + IconoArchivo(a) + "\"></i></span>");
            s.Append("</div>");
        }

        return s.ToString();
    }

    protected void rptPasos_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        Pestana("pasos");
        int i;
        if (e.CommandName == "sel" && int.TryParse(Convert.ToString(e.CommandArgument), out i)) PasoElegido = i;
    }

    private List<Dictionary<string, object>> LeerPasos()
    {
        List<Dictionary<string, object>> lista = new List<Dictionary<string, object>>();

        if (Id == 0) return lista;

        System.Data.SqlClient.SqlCommand cmd = new System.Data.SqlClient.SqlCommand();
        try
        {
            cmd.CommandText = "SEL_ORDEN_TRABAJO_PASO";
            cmd.Parameters.AddWithValue("@CLIENTE", SitioBase.Session.ClienteId());
            cmd.Parameters.AddWithValue("@ORDEN", Id);

            using (System.Data.SqlClient.SqlDataReader dr = Conexion.GetDataReader(cmd))
                while (dr.Read())
                {
                    Dictionary<string, object> f = new Dictionary<string, object>();
                    for (int i = 0; i < dr.FieldCount; i++) f[dr.GetName(i)] = dr.IsDBNull(i) ? null : dr.GetValue(i);
                    lista.Add(f);
                }

            cmd.Connection.Close(); cmd.Dispose();
        }
        catch (Exception) { if (cmd.Connection != null) cmd.Connection.Close(); }

        return lista;
    }

    #endregion

    #region Evidencias

    /// <summary>
    /// La galeria. Cada tarjeta lleva lo suyo en atributos -tipo, paso, texto
    /// buscable y los datos del detalle-, asi que filtrar, buscar y abrir una
    /// evidencia no le cuesta un viaje al servidor: lo resuelve
    /// sigma-orden.js con lo que ya esta en la pagina.
    /// </summary>
    private void PintarEvidencias()
    {
        List<OrdenTrabajoArchivo> ev = Evidencias();

        litEvTodas.Text = ev.Count.ToString();
        litEvFotos.Text = ev.Count(a => a.es_imagen).ToString();
        litEvVideos.Text = ev.Count(a => a.es_video).ToString();
        litEvArchivos.Text = ev.Count(a => a.es_documento || a.es_audio).ToString();

        pnlSinEvidencias.Visible = ev.Count == 0;

        StringBuilder s = new StringBuilder();

        foreach (OrdenTrabajoArchivo a in ev)
        {
            string tipo = a.es_imagen ? "imagen" : a.es_video ? "video" : "documento";
            string url = UrlArchivo(a.arc_id);
            string paso = a.paso_id == null ? "" : "Paso " + a.paso_orden + " · " + a.paso_nombre;

            s.Append("<article class=\"sg-ot-ev-card\" data-tipo=\"").Append(tipo)
             .Append("\" data-paso=\"").Append(a.paso_id == null ? "" : a.paso_id.ToString())
             .Append("\" data-buscar=\"").Append(Server.HtmlEncode((a.etiqueta + " " + a.descripcion + " " + paso).ToLower()))
             .Append("\" data-url=\"").Append(url)
             .Append("\" data-titulo=\"").Append(Server.HtmlEncode(a.etiqueta))
             .Append("\" data-paso-txt=\"").Append(Server.HtmlEncode(paso))
             .Append("\" data-usuario=\"").Append(Server.HtmlEncode(a.usuario))
             .Append("\" data-fecha=\"").Append(a.fecha == null ? "" : a.fecha.Value.ToString("dd MMM yyyy · HH:mm"))
             .Append("\" data-obs=\"").Append(Server.HtmlEncode(a.descripcion))
             .Append("\" data-icono=\"").Append(IconoArchivo(a))
             .Append("\" data-imagen=\"").Append(a.es_imagen ? "1" : "0").Append("\">");

            s.Append("<span class=\"sg-ot-ev-foto\">");
            if (a.es_imagen) s.Append("<img src=\"").Append(url).Append("\" alt=\"").Append(Server.HtmlEncode(a.etiqueta)).Append("\" />");
            else s.Append("<i class=\"mdi ").Append(IconoArchivo(a)).Append(" sg-ot-ev-icono\"></i>");
            s.Append("<span class=\"sg-ot-ev-tipo\"><i class=\"mdi ").Append(IconoArchivo(a)).Append("\"></i></span>");
            s.Append("</span>");

            s.Append("<div class=\"sg-ot-ev-txt\"><span class=\"sg-ot-ev-nom\">").Append(Server.HtmlEncode(a.etiqueta)).Append("</span>")
             .Append("<span class=\"sg-ot-ev-meta\">").Append(Server.HtmlEncode(a.usuario))
             .Append(a.fecha == null ? "" : " · " + a.fecha.Value.ToString("dd MMM yyyy")).Append("</span>");

            if (paso.Length > 0) s.Append("<span class=\"sg-ot-ev-paso\">").Append(Server.HtmlEncode(paso)).Append("</span>");

            s.Append("</div></article>");
        }

        litEvidencias.Text = s.ToString();
    }

    private static string IconoArchivo(OrdenTrabajoArchivo a)
    {
        if (a.es_imagen) return "mdi-image-outline";
        if (a.es_video) return "mdi-video-outline";
        if (a.es_audio) return "mdi-microphone-outline";
        return "mdi-file-document-outline";
    }

    #endregion

    #region Indisponibilidad

    private void PintarIndisponibilidad()
    {
        List<ActivoIndisponibilidad> lista =
            new IndisponibilidadController().Get(new ActivoIndisponibilidad { filtro_orden = Id }) ?? new List<ActivoIndisponibilidad>();

        if (lista.Count == 0)
        {
            litIndisponibilidad.Text =
                "<div class=\"sg-ot-vacio\"><i class=\"mdi mdi-clock-outline\"></i><p>Sin períodos registrados</p>" +
                "<span>Aún no se ha informado una detención para esta OT.</span>" +
                "<div class=\"sg-ot-nota es-chica\"><i class=\"mdi mdi-information-outline\"></i>" +
                "<span>Registre los períodos en que el equipo estuvo detenido debido a esta intervención.</span></div></div>";
            return;
        }

        StringBuilder s = new StringBuilder();

        foreach (ActivoIndisponibilidad i in lista)
        {
            s.Append("<div class=\"sg-ot-periodo\">")
             .Append("<span class=\"sg-ot-periodo-ico ").Append(i.ain_planificada ? "es-ok" : "es-alerta").Append("\"><i class=\"mdi ")
             .Append(i.ain_planificada ? "mdi-calendar-check-outline" : "mdi-flash-outline").Append("\"></i></span>")
             .Append("<div class=\"sg-ot-periodo-txt\"><span class=\"sg-ot-periodo-fechas\">")
             .Append(i.ain_fecha_inicio_utc.ToString("dd MMM yyyy · HH:mm")).Append(" → ")
             .Append(i.ain_fecha_fin_utc == null ? "<b class=\"sg-ot-abierta\">sigue detenido</b>" : i.ain_fecha_fin_utc.Value.ToString("dd MMM yyyy · HH:mm"))
             .Append("</span><span class=\"sg-ot-periodo-meta\">")
             .Append(Server.HtmlEncode(string.IsNullOrEmpty(i.motivo_nombre) ? "Sin motivo" : i.motivo_nombre))
             .Append(i.ain_detuvo_produccion ? " · detuvo producción" : "")
             .Append(string.IsNullOrEmpty(i.ain_motivo) ? "" : " · " + Server.HtmlEncode(i.ain_motivo))
             .Append("</span></div>")
             .Append("<span class=\"sg-ot-periodo-min\"><strong>").Append(i.minutos_acumulados).Append("</strong><span>min</span></span>")
             .Append("</div>");
        }

        litIndisponibilidad.Text = s.ToString();
    }

    protected void btnIndLimpiar_Click(object sender, EventArgs e)
    {
        Pestana("indisponibilidad");
        txtIndFin.Text = "";
        txtIndDetalle.Text = "";
        txtIndInicio.Text = global::SitioBase.Hora.Ahora.ToString("dd-MM-yyyy HH:mm");
        rdbIndPlan.Checked = true; rdbIndNoPlan.Checked = false;
        rdbIndProdNo.Checked = true; rdbIndProdSi.Checked = false;
    }

    protected void btnIndRegistrar_Click(object sender, EventArgs e)
    {
        Pestana("indisponibilidad");
        try
        {
            OrdenTrabajo o = Orden();
            if (o.otr_activo == null) throw new Exception("Esta orden no tiene equipo: no hay indisponibilidad que registrar.");

            DateTime? inicio = Fecha(txtIndInicio.Text, "Inicio");
            if (inicio == null) throw new Exception("Indique cuándo empezó la detención.");

            DateTime? fin = Fecha(txtIndFin.Text, "Término");
            if (fin != null && fin <= inicio) throw new Exception("El término debe ser posterior al inicio.");

            ActivoIndisponibilidad i = new ActivoIndisponibilidad();
            i.ain_activo = o.otr_activo.Value;
            i.ain_orden_trabajo = Id;
            i.ain_fecha_inicio_utc = inicio.Value;
            i.ain_fecha_fin_utc = fin;
            i.ain_planificada = rdbIndPlan.Checked;
            i.ain_detuvo_produccion = rdbIndProdSi.Checked;
            if (!string.IsNullOrEmpty(cboIndMotivo.SelectedValue)) i.ain_indisponibilidad_motivo = int.Parse(cboIndMotivo.SelectedValue);
            i.ain_motivo = string.IsNullOrEmpty(txtIndDetalle.Text.Trim()) ? null : txtIndDetalle.Text.Trim();

            Respuesta r = new IndisponibilidadController().Insert(i);

            if (!r.error) { _orden = null; btnIndLimpiar_Click(sender, e); }

            Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    #endregion

    #region Cierre (HU-120)

    private void PintarCierre(OrdenTrabajo o)
    {
        litUsuarioCierre.Text = Server.HtmlEncode(SitioBase.Session.UsuarioNombre());

        List<Dictionary<string, object>> pasos = Pasos();
        int resueltos = pasos.Count(Resuelto);

        // ---- la validacion, requisito por requisito ----
        StringBuilder s = new StringBuilder();

        s.Append("<div class=\"sg-ot-validacion-cab\"><span>")
         .Append(resueltos).Append(" de ").Append(pasos.Count).Append(" pasos resueltos</span>")
         .Append("<div class=\"sg-ot-barra es-fina\"><span style=\"width:")
         .Append(pasos.Count > 0 ? (int)Math.Round(resueltos * 100.0 / pasos.Count) : 100).Append("%\"></span></div></div>");

        s.Append(Requisito(!string.IsNullOrEmpty(txtResultadoCierre.Text.Trim()) || !string.IsNullOrEmpty(o.otr_resultado),
                 "Trabajo realizado descrito", "Se registró el resultado del trabajo."));
        s.Append(Requisito(Evidencias().Count > 0, "Evidencias disponibles", "Se adjuntaron registros del trabajo."));
        s.Append(Requisito(pasos.Count == 0 || resueltos == pasos.Count, "Pasos resueltos", "Todos los pasos de la intervención están marcados."));
        s.Append(Requisito(o.permisos_pendientes == 0, "Permisos autorizados", "No quedan permisos de trabajo sin autorizar."));
        s.Append(Requisito(o.otr_orden_trabajo_estado == 3 || o.otr_orden_trabajo_estado == 4, "En espera de cierre",
                 "Con \"Trabajo realizado\" la orden tiene que estar en espera de cierre."));

        litValidacion.Text = s.ToString();

        // ---- las evidencias del tecnico ----
        List<OrdenTrabajoArchivo> ev = Evidencias().Where(a => a.es_imagen).Take(3).ToList();

        litCierreEvidencias.Text = ev.Count == 0
            ? "<p class=\"sg-ot-vacio-txt\">El técnico todavía no envió respaldos desde la app.</p>"
            : "<div class=\"sg-ot-miniaturas es-grandes\">" +
              string.Join("", ev.Select(a => "<span class=\"sg-ot-mini\"><img src=\"" + UrlArchivo(a.arc_id) + "\" alt=\"" +
                                             Server.HtmlEncode(a.etiqueta) + "\" /></span>").ToArray()) + "</div>";

        // ---- si ya esta cerrada ----
        litCerrada.Text = o.otr_orden_trabajo_estado != 4 ? "" :
            "<div class=\"sg-ot-card sg-ot-cerrada\"><header class=\"sg-ot-card-cab\">" +
            "<span class=\"sg-ot-card-ico es-ok\"><i class=\"mdi mdi-check-circle-outline\"></i></span>" +
            "<div><h3>Orden cerrada</h3><p class=\"sg-ot-card-sub\">" +
            (o.otr_fecha_cierre ?? DateTime.MinValue).ToString("dd MMM yyyy · HH:mm") + " · " +
            Server.HtmlEncode(o.cierre_usuario_nombre) + "</p></div></header>" +
            "<p class=\"sg-ot-texto\"><strong>" + Server.HtmlEncode(o.cierre_motivo_nombre) + "</strong>" +
            (string.IsNullOrEmpty(o.otr_resultado) ? "" : "<br/>" + Server.HtmlEncode(o.otr_resultado)) + "</p></div>";
    }

    private string Requisito(bool cumple, string titulo, string detalle)
    {
        return "<div class=\"sg-ot-requisito " + (cumple ? "es-ok" : "es-falta") + "\">" +
               "<i class=\"mdi " + (cumple ? "mdi-check-circle" : "mdi-alert-circle-outline") + "\"></i>" +
               "<div><strong>" + Server.HtmlEncode(titulo) + "</strong><span>" + Server.HtmlEncode(detalle) + "</span></div></div>";
    }

    /// <summary>Lo que falta para cerrar, en una linea cada cosa.</summary>
    private List<string> Requisitos(OrdenTrabajo o, List<Dictionary<string, object>> pasos, bool todos)
    {
        List<string> faltan = new List<string>();

        int resueltos = pasos.Count(Resuelto);

        if (o.otr_orden_trabajo_estado != 3 && o.otr_orden_trabajo_estado != 4) faltan.Add("La OT debe estar en espera de cierre");
        if (pasos.Count > 0 && resueltos < pasos.Count) faltan.Add((pasos.Count - resueltos) + " paso(s) sin resolver");
        if (o.permisos_pendientes > 0) faltan.Add(o.permisos_pendientes + " permiso(s) sin autorizar");
        if (string.IsNullOrEmpty(o.otr_resultado)) faltan.Add("Falta describir el trabajo realizado");

        return faltan;
    }

    protected void btnCerrarOT_Click(object sender, EventArgs e)
    {
        Pestana("cierre");
        try
        {
            if (!Token.PuedeFuncion("Cerrar")) throw new Exception("Su perfil no tiene la facultad de cerrar órdenes de trabajo.");
            if (!chkConfirmo.Checked) throw new Exception("Confirme que revisó el trabajo y sus evidencias.");
            if (string.IsNullOrEmpty(hdnFirma.Value)) throw new Exception("Dibuje su firma antes de cerrar la orden.");

            /* La firma se guarda ANTES de cerrar: si el cierre falla -un paso
               sin resolver, un permiso pendiente-, queda un archivo de mas,
               que cuesta espacio y no miente. Al reves quedaria una orden
               cerrada sin el respaldo de quien la autorizo. */
            Respuesta f = new OrdenTrabajoArchivoController().GuardarFirma(Id, hdnFirma.Value);
            if (f.error) throw new Exception("No se pudo guardar la firma: " + f.detalle);

            Respuesta r = new OrdenTrabajoController().Cerrar(Id, int.Parse(cboMotivoCierre.SelectedValue), txtResultadoCierre.Text.Trim());

            if (!r.error)
            {
                _orden = null; _evidencias = null;
                hdnFirma.Value = "";
                chkConfirmo.Checked = false;
            }

            Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    #endregion

    #region Ficha

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
        Response.Redirect("~/View/Mantenimiento/Ordenes/OrdenTrabajos.aspx");
    }

    protected void btnCancelar_Click(object sender, EventArgs e)
    {
        Response.Redirect(Id > 0
            ? "~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx?query=" + Cifrar("Id=" + Id)
            : "~/View/Mantenimiento/Ordenes/OrdenTrabajos.aspx");
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        Pestana("ficha");
        try
        {
            OrdenTrabajo o = new OrdenTrabajo();
            o.otr_id = Id;
            o.otr_titulo = txtTitulo.Text.Trim();
            o.otr_descripcion = string.IsNullOrEmpty(txtDescripcion.Text.Trim()) ? null : txtDescripcion.Text.Trim();
            o.otr_notas = string.IsNullOrEmpty(txtNotas.Text.Trim()) ? null : txtNotas.Text.Trim();
            o.otr_orden_trabajo_tipo = int.Parse(cboTipo.SelectedValue);
            o.otr_orden_trabajo_estrategia = int.Parse(cboEstrategia.SelectedValue);
            o.otr_orden_trabajo_prioridad = int.Parse(cboPrioridad.SelectedValue);

            if (!string.IsNullOrEmpty(cboPlanta.SelectedValue)) o.otr_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);
            if (!string.IsNullOrEmpty(cboActivo.SelectedValue)) o.otr_activo = int.Parse(cboActivo.SelectedValue);
            if (!string.IsNullOrEmpty(cboArea.SelectedValue)) o.otr_instalacion_area = int.Parse(cboArea.SelectedValue);

            o.otr_fecha_programada_utc = Fecha(txtFechaProgramada.Text, "Fecha programada");
            o.quita_fecha = o.otr_fecha_programada_utc == null;

            if (!string.IsNullOrEmpty(txtDuracion.Text.Trim()))
            {
                int d;
                if (!int.TryParse(txtDuracion.Text.Trim(), out d) || d <= 0)
                    throw new Exception("La duración estimada tiene que ser un entero de minutos mayor que cero.");
                o.otr_duracion_estimada_minuto = d;
            }
            else o.quita_duracion = true;

            o.otr_requiere_permiso = rdbPermisoSi.Checked;
            o.otr_registro_posterior = rdbPosteriorSi.Checked;
            o.otr_fecha_ocurrencia = Fecha(txtFechaOcurrencia.Text, "Cuándo ocurrió");

            OrdenTrabajoController c = new OrdenTrabajoController();
            bool nueva = Id == 0;
            Respuesta r = nueva ? c.Insert(o) : c.Update(o);

            if (r.error) { Tools.tools.ClientAlert(r.detalle, "alerta"); return; }

            /* Una orden recien creada cambia de direccion: el id va cifrado en
               el query y las pestañas que no existian aparecen. Es la unica
               navegacion de esta pantalla. */
            if (nueva) Response.Redirect("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx?query=" + Cifrar("Id=" + r.codigo));

            _orden = null;
            Tools.tools.ClientAlert(r.detalle, "ok");
        }
        catch (System.Threading.ThreadAbortException) { throw; }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    #endregion
}
