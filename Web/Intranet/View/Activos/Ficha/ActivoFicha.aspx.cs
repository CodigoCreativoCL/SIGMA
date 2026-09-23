using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// El centro del activo (HU-037): todo lo que le pasa a un equipo en una sola
/// pantalla.
///
/// POR QUE UN CENTRO Y NO SIETE PANTALLAS
///   Las ordenes del equipo estaban en Ordenes de trabajo, sus mantenciones en
///   Planes, sus fallas en Fallas, sus lecturas en Medidores y sus fotos en la
///   ficha. Para responder "que le pasa al Horno L1" habia que recorrer cinco
///   menus filtrando por el mismo equipo en cada uno, y en ninguno se veia de
///   que equipo se estaba hablando. Aca el equipo se elige una vez.
///
///   Las cuatro secciones que se usan siempre -Resumen, Historial, Ordenes y
///   Mantenimiento- estan a la vista; el resto vive en "Mas", que escribe el
///   nombre de la elegida al lado para no perder el lugar.
///
/// SIEMPRE ACOTADO AL CLIENTE EN SESION
///   GetActivo no filtra por cliente, asi que se comprueba antes de pintar
///   nada: un id de otra empresa es facil de escribir en el campo oculto.
/// </summary>
public partial class View_Activos_Ficha_ActivoFicha : System.Web.UI.Page
{
    private const int TOPE_EVENTOS = 200;

    #region Ciclo de vida y lista

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            // Columnas de la lista de resultados (la lupa se agrega en ItemDataBound).
            gridResultados.AddColumn("ACT_ID", "", Width: "4%");
            gridResultados.AddColumn("ACT_CODIGO", "CÓDIGO", Width: "13%");
            gridResultados.AddColumn("ACT_NOMBRE", "NOMBRE", Width: "30%");
            gridResultados.AddColumn("TIPO_NOMBRE", "TIPO", Width: "17%");
            gridResultados.AddColumn("AREA_NOMBRE", "ÁREA / LÍNEA", Width: "18%");
            gridResultados.AddColumn("ESTADO_NOMBRE", "ESTADO", Width: "18%");
        }

        Tools.tools.RegisterPostBackScript(gridResultados);
    }

    public void LoadControls(object sender, EventArgs e) { }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;
        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;
        if (!hayCliente) return;

        ConfigurarUbicacion();

        int activo = ActivoSeleccionado();

        if (activo > 0)
        {
            pnlLista.Visible = false;
            pnlSinActivo.Visible = false;
            Cargar();
        }
        else
        {
            pnlFicha.Visible = false;
            CargarResultados();
        }

        /* Exportar devuelve un archivo y un binario no sobrevive a un postback
           asincrono. Lo demas -filtrar, cambiar de seccion- no recarga. */
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkExportar);

        udPanel.Update();
    }

    private RadComboBox2 Cbo(string id) { return (RadComboBox2)wucFiltro.FindControl(id); }

    private void Seleccionar(RadComboBox2 cbo, string valor)
    {
        RadComboBoxItem item = cbo.FindItemByValue(valor ?? "");
        if (item == null) item = cbo.Items.Count > 0 ? cbo.Items[0] : null;
        if (item != null) item.Selected = true;
    }

    /// <summary>
    /// Cascada Planta -> Área -> Línea: el hijo siempre corresponde al padre;
    /// si el padre cambia, el hijo vuelve a "Todas".
    /// </summary>
    protected void ConfigurarUbicacion()
    {
        RadComboBox2 cboPlanta = Cbo("cboPlanta");
        RadComboBox2 cboArea = Cbo("cboArea");
        RadComboBox2 cboLinea = Cbo("cboLinea");
        if (cboPlanta == null || cboArea == null || cboLinea == null) return;

        int cliente = SitioBase.Session.ClienteId();

        string selP = cboPlanta.SelectedValue;
        string selA = cboArea.SelectedValue;
        string selL = cboLinea.SelectedValue;

        List<ClienteInstalacion> plantas =
            new ClienteInstalacionController().GetClienteInstalaciones(new ClienteInstalacion { cin_cliente = cliente })
            ?? new List<ClienteInstalacion>();

        List<InstalacionArea> areas =
            new InstalacionAreaController().GetInstalacionAreas(new InstalacionArea { iar_cliente = cliente, filtro_habilitado = true })
            ?? new List<InstalacionArea>();

        cboPlanta.Items.Clear();
        cboPlanta.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
        foreach (ClienteInstalacion p in plantas)
            cboPlanta.Items.Add(new RadComboBoxItem(p.cin_nombre, p.cin_id.ToString()));

        if (string.IsNullOrEmpty(selP) && plantas.Count == 1) selP = plantas[0].cin_id.ToString();
        Seleccionar(cboPlanta, selP);
        selP = cboPlanta.SelectedValue;
        int plantaId; int.TryParse(selP, out plantaId);

        cboArea.Items.Clear();
        cboArea.Items.Add(new RadComboBoxItem("Todas las áreas", ""));
        if (plantaId > 0)
            foreach (InstalacionArea a in areas)
                if (a.iar_cliente_instalacion == plantaId && (a.iar_area_padre == null || a.iar_area_padre == 0))
                    cboArea.Items.Add(new RadComboBoxItem(a.iar_nombre, a.iar_id.ToString()));

        if (cboArea.FindItemByValue(selA) == null) selA = "";
        Seleccionar(cboArea, selA);
        selA = cboArea.SelectedValue;
        int areaId; int.TryParse(selA, out areaId);

        cboLinea.Items.Clear();
        cboLinea.Items.Add(new RadComboBoxItem("Todas las líneas", ""));
        if (areaId > 0)
            foreach (InstalacionArea a in areas)
                if (a.iar_area_padre == areaId)
                    cboLinea.Items.Add(new RadComboBoxItem(a.iar_nombre, a.iar_id.ToString()));

        if (cboLinea.FindItemByValue(selL) == null) selL = "";
        Seleccionar(cboLinea, selL);
    }

    private List<Activo> FiltrarActivos()
    {
        Activo filtro = new Activo { act_cliente = SitioBase.Session.ClienteId() };

        RadComboBox2 cboLinea = Cbo("cboLinea");
        RadComboBox2 cboArea = Cbo("cboArea");
        RadComboBox2 cboPlanta = Cbo("cboPlanta");
        RadComboBox2 cboHabilitado = Cbo("cboHabilitado");

        string vL = cboLinea != null ? cboLinea.SelectedValue : "";
        string vA = cboArea != null ? cboArea.SelectedValue : "";
        string vP = cboPlanta != null ? cboPlanta.SelectedValue : "";

        int id;
        if (!string.IsNullOrEmpty(vL) && int.TryParse(vL, out id)) filtro.filtro_instalacion_area = id;
        else if (!string.IsNullOrEmpty(vA) && int.TryParse(vA, out id)) filtro.filtro_instalacion_area = id;
        else if (!string.IsNullOrEmpty(vP) && int.TryParse(vP, out id)) filtro.filtro_cliente_instalacion = id;

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        return new ActivoController().GetActivos(filtro) ?? new List<Activo>();
    }

    protected void CargarResultados()
    {
        List<Activo> lista = FiltrarActivos();

        gridResultados.DataSource = lista;
        gridResultados.DataBind();

        pnlLista.Visible = lista.Count > 0;
        pnlSinActivo.Visible = lista.Count == 0;
    }

    protected void gridResultados_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item is GridDataItem)
        {
            GridDataItem item = (GridDataItem)e.Item;
            string id = item.GetDataKeyValue("act_id").ToString();
            string sel = "document.getElementById('" + hdnActivo.ClientID + "').value='" + id + "';__doPostBack('','');";

            HyperLink ver = new HyperLink();
            ver.CssClass = "icono_Editar";
            ver.NavigateUrl = "javascript:void(0)";
            ver.Attributes.Add("onclick", sel);
            item["act_id"].Controls.Add(ver);

            item.Attributes["onclick"] = sel;
            item.Style["cursor"] = "pointer";
        }
    }

    protected void btnBuscar_Click(object sender, EventArgs e) { hdnSeccion.Value = "historial"; }

    protected void btnVolver_Click(object sender, EventArgs e)
    {
        hdnActivo.Value = "0";
        hdnSeccion.Value = "resumen";
    }

    protected int ActivoSeleccionado()
    {
        int id;
        if (hdnActivo != null && int.TryParse(hdnActivo.Value, out id)) return id;
        return 0;
    }

    #endregion

    #region El centro

    private int _cliente { get { return SitioBase.Session.ClienteId(); } }

    protected void Cargar()
    {
        int id = ActivoSeleccionado();

        pnlFicha.Visible = id > 0;
        if (id == 0) return;

        Activo a = new ActivoController().GetActivo(id);

        /* GetActivo no filtra por cliente: se comprueba aca. Un id de otra
           empresa es facil de escribir en el campo oculto. */
        if (a == null || a.act_id == 0 || a.act_cliente != _cliente)
        {
            pnlFicha.Visible = false;
            hdnActivo.Value = "0";
            CargarResultados();
            return;
        }

        Cabecera(a);

        // Lo que varias secciones comparten se lee UNA vez.
        List<OrdenTrabajo> ordenes = new OrdenTrabajoController().GetOrdenes(
            new OrdenTrabajo { filtro_activo = a.act_id }) ?? new List<OrdenTrabajo>();

        List<Falla> fallas = new FallaController().GetFallas(
            new Falla { filtro_activo = a.act_id }) ?? new List<Falla>();

        List<ActivoIndisponibilidad> detenciones = new IndisponibilidadController().Get(
            new ActivoIndisponibilidad { filtro_activo = a.act_id }) ?? new List<ActivoIndisponibilidad>();

        List<PlanOcurrencia> ocurrencias = new PlanOcurrenciaController().GetCalendario(
            new PlanOcurrencia { filtro_activo = a.act_id }) ?? new List<PlanOcurrencia>();

        List<ActivoFichaEvento> eventos = CargarHistorial(a.act_id);

        Resumen(a, ordenes, fallas, detenciones, ocurrencias, eventos);
        Ordenes(ordenes);
        Mantenimiento(a, ocurrencias);
        FichaTecnica(a);
        Componentes(a);
        FallasYDetenciones(a, fallas, detenciones);
        Condicion(a);
        Documentos(a);
    }

    private void Cabecera(Activo a)
    {
        litHeroNombre.Text = Server.HtmlEncode(a.act_nombre);

        List<string> donde = new List<string>();
        donde.Add(a.act_codigo);
        if (!string.IsNullOrEmpty(a.planta_nombre)) donde.Add(a.planta_nombre);
        if (!string.IsNullOrEmpty(a.area_nombre)) donde.Add(a.area_nombre);
        litHeroSub.Text = Server.HtmlEncode(string.Join(" · ", donde.ToArray()));

        litBadges.Text = ChipEstado(a) + ChipCriticidad(a.criticidad_nombre);

        string q = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + a.act_id));
        string urlEditar = ResolveUrl("~/View/Activos/Activos/Activo.aspx");
        string abrir = "return SigmaModal.open({url:'" + urlEditar + "?query=" + q +
                       "', title:'Editar activo', width:960, initialHeight:620});";

        hlEditar.Attributes["onclick"] = abrir;
        hlEditarFicha.Attributes["onclick"] = abrir;

        hlEscanear.NavigateUrl = ResolveUrl("~/View/Activos/Escaneo/Escanear.aspx");
        hlGenerarOT.NavigateUrl = ResolveUrl("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx");
        hlComponentes.NavigateUrl = ResolveUrl("~/View/Activos/Componentes/ActivoComponentes.aspx");
        hlMedidores.NavigateUrl = ResolveUrl("~/View/Activos/Medidores/ActivoMedidores.aspx");
    }

    #endregion

    #region 1. Resumen

    private void Resumen(Activo a, List<OrdenTrabajo> ordenes, List<Falla> fallas,
                         List<ActivoIndisponibilidad> detenciones, List<PlanOcurrencia> ocurrencias,
                         List<ActivoFichaEvento> eventos)
    {
        DateTime hoy = global::SitioBase.Hora.Hoy;

        List<OrdenTrabajo> abiertas = ordenes.Where(o => o.otr_orden_trabajo_estado != 4).ToList();
        List<Falla> fallasAbiertas = fallas.Where(f => f.fal_fecha_solucion_utc == null).ToList();

        PlanOcurrencia proxima = ocurrencias
            .Where(o => o.fecha_programada.Date >= hoy && o.orden_trabajo_id == null)
            .OrderBy(o => o.fecha_programada).FirstOrDefault();

        // La detencion del mes en curso: mezclar meses da un numero que no es de nadie.
        DateTime mes = new DateTime(hoy.Year, hoy.Month, 1);
        int minutos = detenciones.Where(d => d.ain_fecha_inicio_utc >= mes).Sum(d => d.minutos_acumulados);

        StringBuilder k = new StringBuilder("<div class=\"sg-a3-kpis\">");

        k.Append(Kpi("mdi-clipboard-text-outline", abiertas.Count.ToString(), "OT abiertas", "", abiertas.Count > 0 ? "es-alerta" : "es-ok"));
        k.Append(Kpi("mdi-alert-outline", fallasAbiertas.Count.ToString(), "Fallas abiertas", "", fallasAbiertas.Count > 0 ? "es-alerta" : "es-ok"));
        k.Append(Kpi("mdi-calendar-outline",
                 proxima == null ? "Sin programar" : proxima.fecha_programada.ToString("dd MMM yyyy"),
                 "Próxima mantención",
                 proxima == null ? "" : Texto(proxima.hito_nombre), "", proxima == null));
        k.Append(Kpi("mdi-clock-outline", Duracion(minutos), "Detención del período",
                 hoy.ToString("MMMM yyyy"), minutos > 0 ? "es-alerta" : ""));

        litKpis.Text = k.Append("</div>").ToString();

        // ---- requiere atencion ----
        StringBuilder at = new StringBuilder();

        foreach (OrdenTrabajo o in abiertas.Take(3))
            at.Append(Fila("mdi-clipboard-text-outline", "",
                     "OT-" + o.otr_correlativo + " · " + Texto(o.otr_titulo),
                     Texto(o.otr_descripcion),
                     ChipEstadoOt(o) + Boton(UrlOrden(o.otr_id), "Abrir OT")));

        foreach (Falla f in fallasAbiertas.Take(3))
            at.Append(Fila("mdi-alert-outline", "es-alerta",
                     Texto(f.fal_titulo),
                     Texto(f.sintoma_nombre),
                     "<span class=\"sg-ot-chip es-critica\">" + Server.HtmlEncode(Texto(f.criticidad_nombre)) + "</span>" +
                     Boton(ResolveUrl("~/View/Mantenimiento/Fallas/Fallas.aspx"), "Ver falla")));

        if (proxima != null)
            at.Append(Fila("mdi-calendar-clock", "es-plan",
                     Texto(proxima.hito_nombre),
                     "Mantención programada · " + Texto(proxima.plan_nombre),
                     "<span class=\"sg-ot-chip es-abierta\"><i class=\"mdi mdi-calendar-outline\"></i>" +
                     proxima.fecha_programada.ToString("dd MMM yyyy") + "</span>" +
                     BotonSeccion("mantenimiento", "Ver programación")));

        litAtencion.Text = at.Length > 0 ? at.ToString()
            : "<div class=\"sg-ot-vacio es-chico\"><i class=\"mdi mdi-check-circle-outline\"></i>" +
              "<p>Nada pendiente</p><span>Sin órdenes ni fallas abiertas sobre este equipo.</span></div>";

        // ---- actividad reciente ----
        StringBuilder ac = new StringBuilder();

        foreach (ActivoFichaEvento ev in eventos.Take(5))
            ac.Append(Fila(IconoEvento(ev.tipo_evento), "",
                     Texto(ev.titulo),
                     Texto(ev.detalle),
                     "<span class=\"sg-ot-vacio-txt\">" +
                     (ev.fecha == null ? "" : ev.fecha.Value.ToString("dd MMM yyyy · HH:mm")) + "</span>"));

        litActividad.Text = ac.Length > 0 ? ac.ToString()
            : "<p class=\"sg-ot-vacio-txt\">Este equipo todavía no tiene eventos registrados.</p>";

        // ---- identidad ----
        StringBuilder id = new StringBuilder();

        id.Append(Foto(a.act_id));
        id.Append("<dl class=\"sg-a3-ident\">");
        id.Append(Dato2("Tipo", a.tipo_nombre));
        id.Append(Dato2("Planta", a.planta_nombre));
        id.Append(Dato2("Área", a.area_nombre));
        id.Append(Dato2("Código", a.act_codigo));
        id.Append("<dt>Estado</dt><dd>" + ChipEstado(a) + "</dd>");
        id.Append("</dl>");

        litIdentidad.Text = id.ToString();

        // ---- SIGMA AI ----
        litIA.Text = Prediccion(a);
    }

    /// <summary>
    /// La tarjeta de SIGMA AI.
    ///
    /// Se muestra lo que el modelo dejo escrito en la alerta de prediccion y
    /// NADA mas: sin porcentaje de confianza inventado y sin afirmar que hay
    /// una falla. Una prediccion es un patron que alguien tiene que ir a
    /// mirar, y el texto lo dice.
    /// </summary>
    private string Prediccion(Activo a)
    {
        /* GetAlertas no filtra por activo -devuelve la bandeja del cliente- y
           agregarle un parametro obligaria a tocar el SP que alimenta el panel
           de notificaciones. Para una bandeja de decenas de filas, filtrar aca
           es mas barato que arriesgar esa pantalla. */
        List<Alerta> alertas = new AlertaController().GetAlertas(false, 200) ?? new List<Alerta>();

        Alerta p = alertas
            .Where(x => x.ES_PREDICCION && x.ale_activo == a.act_id)
            .OrderByDescending(x => x.ale_fecha_deteccion_utc)
            .FirstOrDefault();

        if (p == null)
            return "<p class=\"sg-ot-vacio-txt\">Sin análisis predictivo para este equipo todavía.</p>";

        StringBuilder s = new StringBuilder("<div class=\"sg-a3-ia\">");

        s.Append("<div class=\"sg-a3-ia-cab\"><i class=\"mdi mdi-star-four-points-outline\"></i>Predicción por revisar")
         .Append("<span class=\"sg-ot-chip es-tipo\">").Append(Server.HtmlEncode(Texto(p.alt_nombre))).Append("</span></div>");

        s.Append("<p><strong>").Append(Server.HtmlEncode(Texto(p.ale_titulo))).Append("</strong></p>");
        s.Append("<p>").Append(Server.HtmlEncode(Texto(p.ale_descripcion))).Append("</p>");

        s.Append("<div class=\"sg-a3-ia-senales\">Analizada el ")
         .Append(p.ale_fecha_deteccion_utc.ToString("dd MMM yyyy · HH:mm"))
         .Append(". El modelo detecta un patrón; no confirma una falla.</div>");

        s.Append("</div>");

        return s.ToString();
    }

    #endregion

    #region 2. Historial

    private List<ActivoFichaEvento> CargarHistorial(int activo)
    {
        int total;
        List<ActivoFichaEvento> datos = LeerHistorial(activo, out total) ?? new List<ActivoFichaEvento>();

        pnlSinEventos.Visible = datos.Count == 0;

        StringBuilder s = new StringBuilder("<ul class=\"sg-a3-linea\">");

        foreach (ActivoFichaEvento ev in datos)
        {
            s.Append("<li><span class=\"fecha\">")
             .Append(ev.fecha == null ? "" : ev.fecha.Value.ToString("dd MMM yyyy · HH:mm"))
             .Append(" · ").Append(Server.HtmlEncode(TipoEtiqueta(ev.tipo_evento))).Append("</span>")
             .Append("<span class=\"tit\">").Append(Server.HtmlEncode(Texto(ev.titulo))).Append("</span>");

            if (!string.IsNullOrEmpty(ev.detalle))
                s.Append("<span class=\"det\">").Append(Server.HtmlEncode(ev.detalle)).Append("</span>");

            if (!string.IsNullOrEmpty(ev.usuario_nombre))
                s.Append("<span class=\"det\">").Append(Server.HtmlEncode(ev.usuario_nombre)).Append("</span>");

            s.Append("</li>");
        }

        litHistorial.Text = datos.Count == 0 ? "" : s.Append("</ul>").ToString();

        return datos;
    }

    private List<ActivoFichaEvento> LeerHistorial(int activo, out int total)
    {
        string tipo = cboTipo != null ? cboTipo.SelectedValue : "";
        DateTime? desde = calDesde != null ? calDesde.Value : null;
        DateTime? hasta = calHasta != null ? calHasta.Value : null;

        return new ActivoFichaController().GetHistorial(activo, _cliente, tipo, desde, hasta, true, 1, TOPE_EVENTOS, out total);
    }

    #endregion

    #region 3. Ordenes de trabajo

    /// <summary>
    /// Las ordenes del equipo. Cada fila se despliega en su lugar con lo que
    /// se hizo, lo que se gasto, las evidencias y el cierre: abrir la OT
    /// completa es un clic mas, pero la pregunta de "que le hicieron" se
    /// responde sin salir.
    /// </summary>
    private void Ordenes(List<OrdenTrabajo> ordenes)
    {
        int abiertas = ordenes.Count(o => o.otr_orden_trabajo_estado != 4);

        litOtConteos.Text =
            "<div class=\"sg-ot-card-acc sg-ot-avance\">" +
            "<div class=\"sg-ot-avance-num\"><strong>" + ordenes.Count + "</strong><span>total</span></div>" +
            "<div class=\"sg-ot-avance-num\"><strong>" + abiertas + "</strong><span>abiertas</span></div>" +
            "<div class=\"sg-ot-avance-num\"><strong>" + (ordenes.Count - abiertas) + "</strong><span>cerradas</span></div></div>";

        if (ordenes.Count == 0)
        {
            litOrdenes.Text = "<div class=\"sg-ot-vacio\"><i class=\"mdi mdi-clipboard-text-outline\"></i>" +
                              "<p>Sin órdenes de trabajo</p><span>Este equipo no registra intervenciones.</span></div>";
            return;
        }

        OrdenTrabajoRecursoController recursos = new OrdenTrabajoRecursoController();
        OrdenTrabajoArchivoController archivos = new OrdenTrabajoArchivoController();

        StringBuilder s = new StringBuilder();

        s.Append("<div class=\"sg-a3-tabla-cab sg-a3-ot-cab\">")
         .Append("<span>Orden de trabajo</span><span>Tipo</span><span>Responsable</span>")
         .Append("<span>Estado</span><span>Fecha</span><span>Pasos</span><span></span></div>");

        foreach (OrdenTrabajo o in ordenes.OrderByDescending(x => x.otr_fecha_programada_utc ?? x.otr_fecha_creacion))
        {
            s.Append("<div class=\"sg-a3-tabla-fila sg-a3-ot\" data-ot=\"").Append(o.otr_id).Append("\">")
             .Append("<span class=\"c-cod\">OT-").Append(o.otr_correlativo)
             .Append("<span>").Append(Server.HtmlEncode(Texto(o.otr_titulo))).Append("</span></span>")
             .Append("<span class=\"c-dato\"><span class=\"sg-ot-chip es-tipo\">").Append(Server.HtmlEncode(Texto(o.tipo_nombre))).Append("</span></span>")
             .Append("<span class=\"c-dato\">").Append(Server.HtmlEncode(Quien(o))).Append("</span>")
             .Append("<span class=\"c-dato\">").Append(ChipEstadoOt(o)).Append("</span>")
             .Append("<span class=\"c-dato\">")
             .Append(o.otr_fecha_programada_utc == null ? "—" : o.otr_fecha_programada_utc.Value.ToString("dd MMM yyyy"))
             .Append("</span>")
             .Append("<span class=\"c-dato\">").Append(o.pasos - o.pasos_pendientes).Append(" / ").Append(o.pasos).Append("</span>")
             .Append("<span class=\"c-acc\">").Append(Boton(UrlOrden(o.otr_id), "Abrir OT")).Append("</span>")
             .Append("</div>");

            // ---- el detalle que se despliega ----
            List<OrdenTrabajoRepuesto> rep = recursos.GetRepuestos(o.otr_id);
            List<OrdenTrabajoArchivo> ev = archivos.GetEvidencias(o.otr_id);

            s.Append("<div class=\"sg-a3-ot-detalle\" id=\"det-").Append(o.otr_id).Append("\">");

            s.Append(DetItem("mdi-wrench-outline", "Trabajo realizado",
                     string.IsNullOrEmpty(o.otr_resultado) ? Texto(o.otr_descripcion) : o.otr_resultado));

            s.Append(DetItem("mdi-package-variant-closed", "Repuestos",
                     rep.Count == 0 ? "Sin consumo registrado"
                     : string.Join(" · ", rep.Select(r => r.codigo + " · " + Cantidad(r.neto, r.unidad)).ToArray())));

            s.Append(DetItem("mdi-image-multiple-outline", "Evidencias",
                     ev.Count == 0 ? "Sin archivos" : ev.Count + (ev.Count == 1 ? " archivo" : " archivos")));

            s.Append(DetItem("mdi-shield-check-outline", "Cierre",
                     o.otr_orden_trabajo_estado == 4
                        ? Texto(o.cierre_motivo_nombre) + (string.IsNullOrEmpty(o.cierre_usuario_nombre) ? "" : " · " + o.cierre_usuario_nombre)
                        : "Sin cerrar"));

            s.Append("<div class=\"sg-a3-ot-det-acc\">")
             .Append(Boton(UrlOrden(o.otr_id), "Abrir OT completa", true))
             .Append("</div></div>");
        }

        litOrdenes.Text = s.ToString();
    }

    private string DetItem(string icono, string titulo, string valor)
    {
        return "<div class=\"sg-a3-ot-det-item\"><strong><i class=\"mdi " + icono + "\"></i>" +
               Server.HtmlEncode(titulo) + "</strong><span>" +
               Server.HtmlEncode(string.IsNullOrEmpty(valor) ? "Sin registrar" : valor) + "</span></div>";
    }

    #endregion

    #region 4. Mantenimiento

    private void Mantenimiento(Activo a, List<PlanOcurrencia> ocurrencias)
    {
        DateTime hoy = global::SitioBase.Hora.Hoy;

        // ---- planes que lo cubren ----
        var planes = ocurrencias
            .GroupBy(o => new { o.plan_id, o.plan_codigo, o.plan_nombre, o.version_numero })
            .Select(g => g.Key).ToList();

        StringBuilder p = new StringBuilder();

        foreach (var pl in planes)
            p.Append(Fila("mdi-calendar-text-outline", "es-plan",
                     Texto(pl.plan_codigo) + " · " + Texto(pl.plan_nombre),
                     pl.version_numero == null ? "Sin versión publicada" : "Versión " + pl.version_numero,
                     Boton(ResolveUrl("~/View/Mantenimiento/Planes/PlanMantenimientos.aspx"), "Ver plan")));

        litPlanes.Text = p.Length > 0 ? p.ToString()
            : "<p class=\"sg-ot-vacio-txt\">Ningún plan de mantenimiento incluye este equipo.</p>";

        // ---- proximas ocurrencias ----
        StringBuilder oc = new StringBuilder();

        foreach (PlanOcurrencia o in ocurrencias.Where(x => x.fecha_programada.Date >= hoy)
                                                .OrderBy(x => x.fecha_programada).Take(8))
        {
            string chip = o.orden_trabajo_id != null
                ? "<span class=\"sg-ot-chip es-ejecucion\">OT-" + o.orden_trabajo_correlativo + "</span>"
                : "<span class=\"sg-ot-chip es-abierta\">" + Server.HtmlEncode(Texto(o.situacion)) + "</span>";

            oc.Append(Fila("mdi-calendar-clock", "es-plan",
                     o.fecha_programada.ToString("dd MMM yyyy") + " · " + Texto(o.hito_nombre),
                     Texto(o.plan_nombre),
                     chip));
        }

        litOcurrencias.Text = oc.Length > 0 ? oc.ToString()
            : "<p class=\"sg-ot-vacio-txt\">No hay mantenciones programadas por delante.</p>";

        // ---- tareas recurrentes ----
        List<Tarea> tareas = new TareaController().GetTareas(new Tarea { filtro_activo = a.act_id }) ?? new List<Tarea>();

        StringBuilder t = new StringBuilder();

        foreach (Tarea x in tareas)
            t.Append(Fila("mdi-checkbox-marked-circle-outline", "",
                     Texto(x.tar_codigo) + " · " + Texto(x.tar_titulo),
                     x.programaciones + (x.programaciones == 1 ? " programación" : " programaciones") +
                     (x.pendientes > 0 ? " · " + x.pendientes + " pendientes" : ""),
                     Boton(ResolveUrl("~/View/Mantenimiento/Tareas/Tareas.aspx"), "Ver tarea")));

        litTareas.Text = t.Length > 0 ? t.ToString()
            : "<p class=\"sg-ot-vacio-txt\">Este equipo no tiene tareas recurrentes.</p>";
    }

    #endregion

    #region 5. Ficha tecnica

    private void FichaTecnica(Activo a)
    {
        StringBuilder s = new StringBuilder();

        s.Append("<div class=\"sg-ot-sub-titulo\">Identificación</div><div class=\"sg-ot-datos\">");
        s.Append(Dato("mdi-barcode", "Código", a.act_codigo));
        s.Append(Dato("mdi-tag-outline", "Nombre", a.act_nombre));
        s.Append(Dato("mdi-shape-outline", "Tipo", a.tipo_nombre));
        s.Append(Dato("mdi-factory", "Fabricante", a.act_fabricante));
        s.Append(Dato("mdi-identifier", "N° de serie", a.act_numero_serie));
        s.Append("</div>");

        s.Append("<div class=\"sg-ot-sub-titulo\">Ubicación</div><div class=\"sg-ot-datos\">");
        s.Append(Dato("mdi-factory", "Planta", a.planta_nombre));
        s.Append(Dato("mdi-map-marker-outline", "Área", a.area_nombre));
        s.Append("</div>");

        s.Append("<div class=\"sg-ot-sub-titulo\">Gestión</div><div class=\"sg-ot-datos\">");
        s.Append("<div class=\"sg-ot-dato\"><span class=\"sg-ot-dato-ico\"><i class=\"mdi mdi-shield-alert-outline\"></i></span>" +
                 "<div><span class=\"sg-ot-dato-etq\">Criticidad</span>" + ChipCriticidad(a.criticidad_nombre) + "</div></div>");
        s.Append("<div class=\"sg-ot-dato\"><span class=\"sg-ot-dato-ico\"><i class=\"mdi mdi-pulse\"></i></span>" +
                 "<div><span class=\"sg-ot-dato-etq\">Estado</span>" + ChipEstado(a) + "</div></div>");
        s.Append("</div>");

        if (!string.IsNullOrEmpty(a.act_descripcion))
            s.Append("<div class=\"sg-ot-sub-titulo\">Descripción</div><p class=\"sg-ot-texto\">")
             .Append(Server.HtmlEncode(a.act_descripcion)).Append("</p>");

        litFichaTecnica.Text = s.ToString();

        // ---- atributos tecnicos ----
        List<ActivoAtributoValor> atributos = new ActivoAtributoController().GetValores(a.act_id, _cliente)
                                              ?? new List<ActivoAtributoValor>();

        StringBuilder at = new StringBuilder("<div class=\"sg-ot-datos\">");

        foreach (ActivoAtributoValor v in atributos)
            at.Append(Dato("mdi-tune-variant", v.ate_nombre, v.valor_mostrar));

        litAtributos.Text = atributos.Count > 0 ? at.Append("</div>").ToString()
            : "<p class=\"sg-ot-vacio-txt\">El tipo de este equipo no define atributos técnicos.</p>";

        litFotoFicha.Text = Foto(a.act_id);

        litQr.Text = "<div class=\"sg-ot-nota es-chica\" style=\"margin-top:12px;\">" +
                     "<i class=\"mdi mdi-qrcode\"></i><span>La etiqueta QR del equipo se imprime desde " +
                     "<strong>Activos · Etiquetas</strong> y se lee con «Escanear QR».</span></div>";
    }

    #endregion

    #region 6. Componentes

    private void Componentes(Activo a)
    {
        List<ActivoComponente> lista = new ActivoComponenteController().GetComponentes(
            new ActivoComponente { aco_cliente = _cliente, filtro_activo = a.act_id, filtro_habilitado = true })
            ?? new List<ActivoComponente>();

        if (lista.Count == 0)
        {
            litComponentes.Text = "<div class=\"sg-ot-vacio\"><i class=\"mdi mdi-puzzle-outline\"></i>" +
                                  "<p>Sin componentes registrados</p><span>Las partes del equipo se cargan desde Componentes.</span></div>";
            return;
        }

        StringBuilder s = new StringBuilder();

        s.Append("<div class=\"sg-a3-tabla-cab sg-a3-t4-cab\">")
         .Append("<span>Componente</span><span>Tipo</span><span>Estado</span><span></span></div>");

        foreach (ActivoComponente c in lista)
        {
            s.Append("<div class=\"sg-a3-tabla-fila sg-a3-t4\">")
             .Append("<span class=\"c-cod\">").Append(Server.HtmlEncode(Texto(c.aco_codigo)))
             .Append("<span>").Append(Server.HtmlEncode(Texto(c.aco_nombre))).Append("</span></span>")
             .Append("<span class=\"c-dato\">").Append(Server.HtmlEncode(Texto(c.tipo_nombre))).Append("</span>")
             .Append("<span class=\"c-dato\"><span class=\"sg-ot-chip es-abierta\">")
             .Append(Server.HtmlEncode(Texto(c.estado_nombre))).Append("</span></span>")
             .Append("<span class=\"c-acc\">").Append(Boton(ResolveUrl("~/View/Activos/Componentes/ActivoComponentes.aspx"), "Ver ficha")).Append("</span>")
             .Append("</div>");
        }

        litComponentes.Text = s.ToString();
    }

    #endregion

    #region 7. Fallas e indisponibilidad

    private void FallasYDetenciones(Activo a, List<Falla> fallas, List<ActivoIndisponibilidad> detenciones)
    {
        // ---- fallas ----
        if (fallas.Count == 0)
            litFallas.Text = "<div class=\"sg-ot-vacio es-chico\"><i class=\"mdi mdi-check-circle-outline\"></i>" +
                             "<p>Sin fallas registradas</p><span>Este equipo no tiene reportes.</span></div>";
        else
        {
            StringBuilder s = new StringBuilder();

            foreach (Falla f in fallas.OrderByDescending(x => x.fal_fecha_deteccion_utc))
            {
                bool abierta = f.fal_fecha_solucion_utc == null;

                s.Append(Fila(abierta ? "mdi-alert-outline" : "mdi-check-circle-outline",
                         abierta ? "es-alerta" : "es-ok",
                         Texto(f.fal_titulo),
                         (f.fal_fecha_deteccion_utc == null ? "" : f.fal_fecha_deteccion_utc.Value.ToString("dd MMM yyyy") + " · ") +
                         Texto(f.sintoma_nombre) +
                         (f.ultima_ot_correlativo != null ? " · OT-" + f.ultima_ot_correlativo : ""),
                         (abierta
                            ? "<span class=\"sg-ot-chip es-espera\">Abierta</span>"
                            : "<span class=\"sg-ot-chip es-ejecucion\">Resuelta</span>") +
                         Boton(ResolveUrl("~/View/Mantenimiento/Fallas/Fallas.aspx"), "Abrir falla")));
            }

            litFallas.Text = s.ToString();
        }

        // ---- detenciones ----
        DateTime hoy = global::SitioBase.Hora.Hoy;
        DateTime mes = new DateTime(hoy.Year, hoy.Month, 1);
        int minutosMes = detenciones.Where(d => d.ain_fecha_inicio_utc >= mes).Sum(d => d.minutos_acumulados);

        litDetencionTotal.Text = "<div class=\"sg-ot-card-acc sg-ot-avance\"><div class=\"sg-ot-avance-num\"><strong>" +
                                 Duracion(minutosMes) + "</strong><span>" + hoy.ToString("MMMM yyyy") + "</span></div></div>";

        if (detenciones.Count == 0)
        {
            litIndisponibilidad.Text = "<p class=\"sg-ot-vacio-txt\">Sin períodos de detención registrados.</p>";
        }
        else
        {
            StringBuilder d = new StringBuilder();

            foreach (ActivoIndisponibilidad i in detenciones.OrderByDescending(x => x.ain_fecha_inicio_utc).Take(10))
                d.Append(Fila(i.ain_planificada ? "mdi-calendar-check-outline" : "mdi-flash-outline",
                         i.ain_planificada ? "es-ok" : "es-alerta",
                         i.ain_fecha_inicio_utc.ToString("dd MMM yyyy · HH:mm") + " → " +
                         (i.ain_fecha_fin_utc == null ? "sigue detenido" : i.ain_fecha_fin_utc.Value.ToString("HH:mm")),
                         Texto(i.motivo_nombre) + (i.ot_correlativo != null ? " · OT-" + i.ot_correlativo : ""),
                         "<span class=\"sg-ot-chip " + (i.ain_planificada ? "es-abierta" : "es-critica") + "\">" +
                         (i.ain_planificada ? "Planificada" : "No planificada") + "</span>" +
                         "<span class=\"sg-a3-codigo\">" + Duracion(i.minutos_acumulados) + "</span>"));

            litIndisponibilidad.Text = d.ToString();
        }

        // ---- estado ahora ----
        bool detenidoAhora = detenciones.Any(x => x.ain_fecha_fin_utc == null);

        litEstadoAhora.Text = detenidoAhora
            ? "<div class=\"sg-ot-aviso\"><i class=\"mdi mdi-flash-outline\"></i>Hay una detención abierta: el equipo figura detenido ahora mismo.</div>"
            : "<div class=\"sg-ot-aviso es-ok\"><i class=\"mdi mdi-check-circle-outline\"></i>Sin detenciones abiertas: el equipo figura operando.</div>";
    }

    #endregion

    #region 8. Condicion y medidores

    /// <summary>
    /// Las variables de condicion y los contadores. Se separan a proposito: una
    /// temperatura sube y baja y se compara contra un rango; un horometro solo
    /// acumula. Mezclarlos hace que "el valor subio" signifique cosas distintas
    /// en la misma tabla.
    ///
    /// "Dato desactualizado" no es lo mismo que "normal": una lectura de hace
    /// tres semanas no dice que el equipo este bien, dice que nadie lo midio.
    /// </summary>
    private void Condicion(Activo a)
    {
        ActivoVariableController ctlVar = new ActivoVariableController();

        List<ActivoVariable> variables = ctlVar.GetVariables(
            new ActivoVariable { ava_cliente = _cliente, filtro_activo = a.act_id, filtro_habilitado = true })
            ?? new List<ActivoVariable>();

        if (variables.Count == 0)
            litCondicion.Text = "<div class=\"sg-ot-vacio es-chico\"><i class=\"mdi mdi-gauge-empty\"></i>" +
                                "<p>Sin variables de condición</p><span>Se configuran en Activos · Variables.</span></div>";
        else
        {
            DateTime hoy = global::SitioBase.Hora.Hoy;
            StringBuilder s = new StringBuilder("<div class=\"sg-a3-cond\">");

            foreach (ActivoVariable v in variables)
            {
                /* La variable dice que se mide y entre que valores; la ultima
                   lectura vive en la serie. Se pide el resumen de los ultimos
                   noventa dias, que es lo que ya calcula el SP. */
                MedicionSerieResumen r = ctlVar.GetSerieResumen(v.ava_id, hoy.AddDays(-90), null);

                string clase, etiqueta;
                Semaforo(v, r, hoy, out clase, out etiqueta);

                s.Append("<div class=\"sg-a3-cond-card ").Append(clase).Append("\">")
                 .Append("<span class=\"sg-a3-cond-nom\">").Append(Server.HtmlEncode(Texto(v.variable_nombre))).Append("</span>")
                 .Append("<span class=\"sg-a3-cond-val\">")
                 .Append(r == null || r.ultimo_valor == null ? "—" : r.ultimo_valor.Value.ToString("0.##"))
                 .Append(string.IsNullOrEmpty(v.unidad_simbolo) ? "" : " <small>" + Server.HtmlEncode(v.unidad_simbolo) + "</small>")
                 .Append("</span>")
                 .Append("<span class=\"sg-a3-cond-pie\">").Append(etiqueta).Append("</span>")
                 .Append("</div>");
            }

            litCondicion.Text = s.Append("</div>").ToString();
        }

        // ---- contadores ----
        List<ActivoMedidor> medidores = new ActivoMedidorController().GetActivoMedidores(
            new ActivoMedidor { ame_cliente = _cliente, filtro_activo = a.act_id, filtro_habilitado = true })
            ?? new List<ActivoMedidor>();

        if (medidores.Count == 0)
        {
            litMedidores.Text = "<p class=\"sg-ot-vacio-txt\">Este equipo no tiene contadores.</p>";
            return;
        }

        StringBuilder m = new StringBuilder();

        foreach (ActivoMedidor x in medidores)
            m.Append(Fila("mdi-counter", "",
                     Texto(x.ame_nombre),
                     x.ame_fecha_valor_actual_utc == null
                        ? "Sin lecturas"
                        : "Última lectura " + x.ame_fecha_valor_actual_utc.Value.ToString("dd MMM yyyy · HH:mm"),
                     "<span class=\"sg-a3-codigo\">" + x.ame_valor_actual.ToString("0.##") +
                     (string.IsNullOrEmpty(x.unidad_simbolo) ? "" : " " + Server.HtmlEncode(x.unidad_simbolo)) + "</span>"));

        litMedidores.Text = m.ToString();
    }

    /// <summary>
    /// En que color cae la variable. Antes que el rango se mira la FECHA: sin
    /// lectura reciente no hay nada que comparar, y pintarla de verde seria
    /// decir que el equipo esta bien porque nadie lo midio.
    /// </summary>
    private void Semaforo(ActivoVariable v, MedicionSerieResumen r, DateTime hoy, out string clase, out string etiqueta)
    {
        if (r == null || r.ultimo_valor == null || r.ultima_fecha_utc == null)
        {
            clase = "";
            etiqueta = "Sin datos";
            return;
        }

        int dias = (int)(hoy - r.ultima_fecha_utc.Value.Date).TotalDays;

        if (dias > 14)
        {
            clase = "es-viejo";
            etiqueta = "Dato desactualizado · " + r.ultima_fecha_utc.Value.ToString("dd MMM yyyy");
            return;
        }

        decimal valor = r.ultimo_valor.Value;
        string cuando = "Última lectura " + r.ultima_fecha_utc.Value.ToString("dd MMM · HH:mm");

        /* Los umbrales son los de la variable del equipo: primero el critico y
           despues el de advertencia, porque un valor que pasa el critico
           tambien pasa el de aviso y la etiqueta tiene que decir lo peor. El
           rango normal -minimo y maximo- se mira al final. */
        if (v.ava_valor_critico != null && valor >= v.ava_valor_critico)
        {
            clase = "es-critico"; etiqueta = "Crítico · " + cuando; return;
        }

        if (v.ava_valor_advertencia != null && valor >= v.ava_valor_advertencia)
        {
            clase = "es-aviso"; etiqueta = "Advertencia · " + cuando; return;
        }

        if ((v.ava_valor_maximo != null && valor > v.ava_valor_maximo) ||
            (v.ava_valor_minimo != null && valor < v.ava_valor_minimo))
        {
            clase = "es-aviso"; etiqueta = "Fuera de rango · " + cuando; return;
        }

        clase = "es-normal";
        etiqueta = "Normal · " + cuando;
    }

    #endregion

    #region 9. Documentos y galeria

    private void Documentos(Activo a)
    {
        List<ActivoArchivo> archivos = new ActivoArchivoController().GetArchivos(a.act_id, _cliente)
                                       ?? new List<ActivoArchivo>();

        litEvTodas.Text = archivos.Count.ToString();
        litEvFotos.Text = archivos.Count(x => x.es_imagen).ToString();
        litEvDocs.Text = archivos.Count(x => !x.es_imagen).ToString();

        pnlSinArchivos.Visible = archivos.Count == 0;

        litDocConteos.Text = "";

        StringBuilder s = new StringBuilder();

        foreach (ActivoArchivo f in archivos)
        {
            string tipo = f.es_imagen ? "imagen" : "documento";
            string url = UrlArchivo.Ver(f.arc_id);

            s.Append("<article class=\"sg-ot-ev-card\" data-tipo=\"").Append(tipo)
             .Append("\" data-paso=\"\" data-buscar=\"").Append(Server.HtmlEncode((f.arc_nombre ?? "").ToLower()))
             .Append("\" data-url=\"").Append(url)
             .Append("\" data-titulo=\"").Append(Server.HtmlEncode(Texto(f.arc_nombre)))
             .Append("\" data-paso-txt=\"Ficha del activo\" data-usuario=\"\" data-fecha=\"\" data-obs=\"\"")
             .Append(" data-icono=\"").Append(f.es_imagen ? "mdi-image-outline" : "mdi-file-document-outline")
             .Append("\" data-imagen=\"").Append(f.es_imagen ? "1" : "0").Append("\">");

            s.Append("<span class=\"sg-ot-ev-foto\">");
            if (f.es_imagen) s.Append("<img src=\"").Append(url).Append("\" alt=\"").Append(Server.HtmlEncode(Texto(f.arc_nombre))).Append("\" />");
            else s.Append("<i class=\"mdi mdi-file-document-outline sg-ot-ev-icono\"></i>");
            s.Append("</span>");

            s.Append("<div class=\"sg-ot-ev-txt\"><span class=\"sg-ot-ev-nom\">")
             .Append(Server.HtmlEncode(Texto(f.arc_nombre))).Append("</span>")
             .Append("<span class=\"sg-ot-ev-meta\">").Append(Tamano(f.arc_byte)).Append("</span></div></article>");
        }

        litArchivos.Text = s.ToString();
    }

    private static string Tamano(long bytes)
    {
        if (bytes <= 0) return "";
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return (bytes / 1024) + " KB";
        return (bytes / (1024 * 1024)) + " MB";
    }

    #endregion

    #region Presentacion

    private string Texto(string v) { return string.IsNullOrEmpty(v) ? "" : v; }

    private string Kpi(string icono, string valor, string etiqueta, string pie = "", string clase = "", bool chico = false)
    {
        return "<div class=\"sg-a3-kpi\"><span class=\"sg-a3-kpi-ico " + clase + "\"><i class=\"mdi " + icono + "\"></i></span>" +
               "<div><span class=\"sg-a3-kpi-etq\">" + Server.HtmlEncode(etiqueta) + "</span>" +
               "<span class=\"sg-a3-kpi-val" + (chico || valor.Length > 12 ? " es-chico" : "") + "\">" + Server.HtmlEncode(valor) + "</span>" +
               (string.IsNullOrEmpty(pie) ? "" : "<span class=\"sg-a3-kpi-pie\">" + Server.HtmlEncode(pie) + "</span>") +
               "</div></div>";
    }

    private string Fila(string icono, string clase, string titulo, string sub, string acciones)
    {
        return "<div class=\"sg-a3-fila\"><span class=\"sg-a3-fila-ico " + clase + "\"><i class=\"mdi " + icono + "\"></i></span>" +
               "<div class=\"sg-a3-fila-txt\"><span class=\"sg-a3-fila-tit\">" + Server.HtmlEncode(titulo) + "</span>" +
               (string.IsNullOrEmpty(sub) ? "" : "<span class=\"sg-a3-fila-sub\">" + Server.HtmlEncode(sub) + "</span>") +
               "</div><div class=\"sg-a3-fila-acc\">" + acciones + "</div></div>";
    }

    private string Dato(string icono, string etiqueta, string valor)
    {
        return "<div class=\"sg-ot-dato\"><span class=\"sg-ot-dato-ico\"><i class=\"mdi " + icono + "\"></i></span>" +
               "<div><span class=\"sg-ot-dato-etq\">" + Server.HtmlEncode(etiqueta) + "</span>" +
               "<span class=\"sg-ot-dato-val\">" + Server.HtmlEncode(string.IsNullOrEmpty(valor) ? "Sin registrar" : valor) + "</span></div></div>";
    }

    private string Dato2(string etiqueta, string valor)
    {
        return "<dt>" + Server.HtmlEncode(etiqueta) + "</dt><dd>" +
               Server.HtmlEncode(string.IsNullOrEmpty(valor) ? "Sin registrar" : valor) + "</dd>";
    }

    private string Boton(string url, string texto, bool primario = false)
    {
        return "<a class=\"sg-ot-btn " + (primario ? "es-primario" : "es-plano") + "\" href=\"" + url + "\">" +
               Server.HtmlEncode(texto) + "<i class=\"mdi mdi-open-in-new\"></i></a>";
    }

    private string BotonSeccion(string seccion, string texto)
    {
        return "<a class=\"sg-ot-btn es-plano\" href=\"#\" data-ir-sec=\"" + seccion + "\">" +
               Server.HtmlEncode(texto) + "</a>";
    }

    private string UrlOrden(int id)
    {
        return ResolveUrl("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx") + "?query=" +
               Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));
    }

    private string Foto(int activo)
    {
        int idArchivo = new ActivoImagenController().GetImagenId(activo, _cliente);

        if (idArchivo > 0)
            return "<span class=\"sg-a3-foto\"><img src=\"" + Server.HtmlEncode(UrlArchivo.Ver(idArchivo)) +
                   "\" alt=\"Imagen del equipo\" /></span>";

        return "<span class=\"sg-a3-foto es-vacia\"><i class=\"mdi mdi-image-off-outline\"></i></span>";
    }

    private string ChipEstado(Activo a)
    {
        string texto = string.IsNullOrEmpty(a.estado_nombre) ? "Sin estado" : a.estado_nombre;

        string clase = a.act_activo_estado == 1 ? "es-ejecucion"
                     : (a.act_activo_estado == 2 || a.act_activo_estado == 4) ? "es-espera"
                     : (a.act_activo_estado == 3 || a.act_activo_estado == 5 || a.act_activo_estado == 6) ? "es-critica"
                     : "es-anulada";

        return "<span class=\"sg-ot-chip " + clase + "\"><i class=\"mdi mdi-circle-medium\"></i>" +
               Server.HtmlEncode(texto) + "</span>";
    }

    private string ChipCriticidad(string critic)
    {
        string c = (critic ?? "").ToUpperInvariant();
        string clase = c.Contains("CRÍT") || c.Contains("CRIT") || c.Contains("ALTA") ? "es-critica"
                     : c.Contains("MEDIA") ? "es-alta" : "es-media";

        return "<span class=\"sg-ot-chip " + clase + "\"><i class=\"mdi mdi-shield-alert-outline\"></i>Criticidad " +
               Server.HtmlEncode(string.IsNullOrEmpty(critic) ? "sin definir" : critic.ToLower()) + "</span>";
    }

    private string ChipEstadoOt(OrdenTrabajo o)
    {
        string clase = o.otr_orden_trabajo_estado == 4 ? "es-cerrada"
                     : o.otr_orden_trabajo_estado == 3 ? "es-espera"
                     : o.otr_orden_trabajo_estado == 2 ? "es-ejecucion" : "es-abierta";

        return "<span class=\"sg-ot-chip " + clase + "\"><i class=\"mdi mdi-circle-medium\"></i>" +
               Server.HtmlEncode(Texto(o.estado_nombre)) + "</span>";
    }

    private static string Quien(OrdenTrabajo o)
    {
        if (!string.IsNullOrEmpty(o.responsable_nombre)) return o.responsable_nombre;
        if (!string.IsNullOrEmpty(o.responsable_proveedor)) return o.responsable_proveedor;
        return "Sin asignar";
    }

    private static string Cantidad(decimal valor, string unidad)
    {
        string n = valor == Math.Floor(valor) ? ((long)valor).ToString("N0") : valor.ToString("0.##");
        return n + (string.IsNullOrEmpty(unidad) ? "" : " " + unidad);
    }

    private static string Duracion(int minutos)
    {
        if (minutos <= 0) return "Sin registros";
        if (minutos < 60) return minutos + " min";

        int horas = minutos / 60, resto = minutos % 60;
        return horas + " h" + (resto > 0 ? " " + resto + " min" : "");
    }

    private static string IconoEvento(string tipo)
    {
        switch ((tipo ?? "").ToUpperInvariant())
        {
            case "ESTADO": return "mdi-pulse";
            case "POSICION": return "mdi-map-marker-outline";
            case "MEDICION": return "mdi-gauge";
            default: return "mdi-file-document-outline";
        }
    }

    public string TipoEtiqueta(object t)
    {
        string tipo = t == null ? "" : t.ToString();
        return tipo == "ESTADO" ? "Estado"
             : tipo == "POSICION" ? "Posición"
             : tipo == "MEDICION" ? "Medición" : tipo;
    }

    #endregion

    #region Exportar

    /// <summary>El historial del equipo, tal como se esta mirando.</summary>
    protected void lnkExportar_Click(object sender, EventArgs e)
    {
        try
        {
            int activo = ActivoSeleccionado();
            if (activo == 0) { Tools.tools.ClientAlert("Elija un equipo primero."); return; }

            int total;
            List<ActivoFichaEvento> datos = LeerHistorial(activo, out total) ?? new List<ActivoFichaEvento>();

            StringBuilder sb = new StringBuilder();
            sb.Append("<table border='1'><tr>");
            sb.Append("<th>Fecha</th><th>Tipo</th><th>Evento</th><th>Detalle</th><th>Usuario</th></tr>");

            foreach (ActivoFichaEvento ev in datos)
            {
                sb.Append("<tr>");
                sb.Append("<td>" + (ev.fecha.HasValue ? ev.fecha.Value.ToString("dd-MM-yyyy HH:mm") : "") + "</td>");
                sb.Append("<td>" + Server.HtmlEncode(TipoEtiqueta(ev.tipo_evento)) + "</td>");
                sb.Append("<td>" + Server.HtmlEncode(ev.titulo) + "</td>");
                sb.Append("<td>" + Server.HtmlEncode(ev.detalle) + "</td>");
                sb.Append("<td>" + Server.HtmlEncode(ev.usuario_nombre) + "</td>");
                sb.Append("</tr>");
            }

            sb.Append("</table>");

            Response.Clear();
            Response.Buffer = true;
            Response.AddHeader("content-disposition", "attachment;filename=Historial_Activo.xls");
            Response.ContentType = "application/vnd.ms-excel";
            Response.Charset = "UTF-8";
            Response.ContentEncoding = System.Text.Encoding.UTF8;
            Response.Write("<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">");
            Response.Write(sb.ToString());
            Response.Flush();
            Response.End();
        }
        catch (System.Threading.ThreadAbortException) { }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message); }
    }

    #endregion
}
