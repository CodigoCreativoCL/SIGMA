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
            /* El centro se puede abrir apuntando a UN equipo: es lo que hacen
               "Ver ficha del activo" desde el plan y cualquier enlace guardado.
               Sin esto la url llegaba con el id y la pantalla abria el listado,
               que es peor que no tener el enlace. */
            int deLaUrl = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
            if (deLaUrl > 0) hdnActivo.Value = deLaUrl.ToString();

            // Columnas de la lista de resultados (la lupa se agrega en ItemDataBound).
        }

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
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkExportarLista);

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

    /// <summary>
    /// La lista de equipos: lo que hay que saber de cada uno ANTES de abrirlo.
    ///
    /// POR QUE NO ES UNA GRILLA DE CODIGO Y NOMBRE
    ///   Quien entra aca no viene a leer un catalogo: viene a encontrar EL
    ///   equipo que tiene un problema. Por eso cada fila trae su foto, su
    ///   estado, cuantas ordenes abiertas carga y cuando le toca lo proximo,
    ///   y los numeros de arriba dicen como esta la planta entera.
    ///
    ///   Los conteos salen de UNA consulta (bloque 275). Pedirlos por activo
    ///   eran cinco por fila.
    /// </summary>
    protected void CargarResultados()
    {
        List<Activo> lista = FiltrarActivos();

        litTitulo.Text = "Centro de activos 360°";
        litSubtitulo.Text = "Historial, mantenimiento y condición de tus equipos.";

        pnlLista.Visible = lista.Count > 0;
        pnlSinActivo.Visible = lista.Count == 0;

        if (lista.Count == 0) return;

        Dictionary<int, ActivoResumenLista> resumen = new ActivoCentroController().GetResumenLista()
                                                      ?? new Dictionary<int, ActivoResumenLista>();

        int operativos = 0, detenidos = 0, enMantencion = 0, atencion = 0, conOt = 0;

        StringBuilder s = new StringBuilder();

        s.Append("<div class=\"sg-a3-tabla-cab sg-lista-cab\">")
         .Append("<span></span><span>Activo</span><span>Ubicación</span><span>Estado</span>")
         .Append("<span>Criticidad</span><span>OT abiertas</span><span>Próximo mantenimiento</span>")
         .Append("<span></span></div>");

        foreach (Activo a in lista.OrderBy(x => x.act_codigo))
        {
            ActivoResumenLista r;
            if (!resumen.TryGetValue(a.act_id, out r)) r = new ActivoResumenLista();

            string estado = Texto(a.estado_nombre);
            string e = estado.ToUpperInvariant();

            if (e.Contains("OPERATIV")) operativos++;
            else if (e.Contains("DETEN") || e.Contains("PARAD")) detenidos++;
            else if (e.Contains("MANTEN")) enMantencion++;

            if (r.requiere_atencion) atencion++;
            if (r.ot_abiertas > 0) conOt++;

            string ubicacion = string.Join(" · ", new[] { Texto(a.planta_nombre), Texto(a.area_nombre) }
                                           .Where(x => !string.IsNullOrEmpty(x)).ToArray());

            s.Append("<div class=\"sg-a3-tabla-fila sg-lista-fila\" data-act=\"").Append(a.act_id)
             .Append("\" data-lista-atencion=\"").Append(r.requiere_atencion ? "1" : "0")
             .Append("\" data-lista-ot=\"").Append(r.ot_abiertas)
             .Append("\" data-lista-txt=\"")
             .Append(Server.HtmlEncode((Texto(a.act_codigo) + " " + Texto(a.act_nombre) + " " + Texto(a.tipo_nombre) + " " + ubicacion).ToLower()))
             .Append("\">")

             .Append("<span class=\"c-dato\">")
             .Append(r.imagen_id == null
                    ? "<span class=\"sg-comp-foto es-vacia\"><i class=\"mdi mdi-cog-outline\"></i></span>"
                    : "<span class=\"sg-comp-foto\"><img src=\"" + Server.HtmlEncode(UrlArchivo.Ver(r.imagen_id.Value)) +
                      "\" alt=\"" + Server.HtmlEncode(Texto(a.act_nombre)) + "\" /></span>")
             .Append("</span>")

             .Append("<span class=\"c-cod\">").Append(Server.HtmlEncode(Texto(a.act_nombre)))
             .Append("<span>").Append(Server.HtmlEncode(Texto(a.act_codigo)))
             .Append(string.IsNullOrEmpty(a.tipo_nombre) ? "" : " · " + Server.HtmlEncode(a.tipo_nombre))
             .Append("</span></span>")

             .Append("<span class=\"c-dato\">")
             .Append(Server.HtmlEncode(ubicacion.Length == 0 ? "Sin ubicación" : ubicacion)).Append("</span>")

             .Append("<span class=\"c-dato\">").Append(ChipEstado(a)).Append("</span>")
             .Append("<span class=\"c-dato\">").Append(ChipNivelCriticidad(a.criticidad_nombre)).Append("</span>")

             .Append("<span class=\"c-dato\">")
             .Append(r.ot_abiertas == 0
                    ? "<span class=\"sg-ot-vacio-txt\">0</span>"
                    : "<span class=\"sg-lista-num\">" + r.ot_abiertas + "</span>")
             .Append("</span>")

             .Append("<span class=\"c-dato\">")
             .Append(r.proxima_mantencion == null
                    ? "<span class=\"sg-ot-vacio-txt\">Sin programación</span>"
                    : Server.HtmlEncode(r.proxima_mantencion.Value.ToString("dd MMM yyyy")))
             .Append("</span>")

             .Append("<span class=\"c-acc\">")
             .Append("<a class=\"sg-ot-btn es-accion\" href=\"javascript:void(0)\" data-abrir-act=\"")
             .Append(a.act_id).Append("\">Abrir 360°<i class=\"mdi mdi-arrow-right\"></i></a>")
             .Append("</span>")
             .Append("</div>");
        }

        litLista.Text = s.ToString();

        litListaTodos.Text = lista.Count.ToString();
        litListaAtencion.Text = atencion.ToString();
        litListaOt.Text = conOt.ToString();

        /* Los cuatro numeros de arriba: como esta la planta antes de mirar
           equipo por equipo. */
        litListaKpis.Text =
            "<div class=\"sg-a3-kpis\">" +
            Kpi("mdi-cog-outline", lista.Count.ToString(), "Activos", "En la búsqueda actual", "es-teal") +
            Kpi("mdi-check-circle-outline", operativos.ToString(), "Operativos", "", "es-verde") +
            Kpi("mdi-alert-octagon-outline", detenidos.ToString(), "Detenidos", "", detenidos > 0 ? "es-rojo" : "es-verde") +
            Kpi("mdi-wrench-outline", enMantencion.ToString(), "En mantenimiento", "", "es-ambar") +
            "</div>";
    }

    protected void btnBuscar_Click(object sender, EventArgs e) { hdnSeccion.Value = "historial"; }

    protected void btnVolver_Click(object sender, EventArgs e)
    {
        hdnActivo.Value = "0";
        hdnSeccion.Value = "resumen";
    }

    /// <summary>
    /// El querystring cifrado para crear un componente de ESTE equipo. El
    /// activo viaja dentro: la ficha se abre con el equipo ya puesto.
    /// </summary>
    protected string QueryNuevoComponente
    {
        get
        {
            int id = ActivoSeleccionado();
            return id > 0 ? Server.UrlEncode(Tools.Crypto.Encrypt("Id=0&Activo=" + id)) : "0";
        }
    }

    /// <summary>El querystring cifrado para crear una variable de ESTE equipo.</summary>
    protected string QueryNuevaVariable
    {
        get
        {
            int id = ActivoSeleccionado();
            return id > 0 ? Server.UrlEncode(Tools.Crypto.Encrypt("Id=0&Activo=" + id)) : "0";
        }
    }

    /// <summary>El querystring cifrado para anotar una lectura de ESTE equipo.</summary>
    protected string QueryLectura
    {
        get
        {
            int id = ActivoSeleccionado();
            return id > 0 ? Server.UrlEncode(Tools.Crypto.Encrypt("Activo=" + id)) : "0";
        }
    }

    /// <summary>El querystring cifrado para crear un contador de ESTE equipo.</summary>
    protected string QueryNuevoMedidor
    {
        get
        {
            int id = ActivoSeleccionado();
            return id > 0 ? Server.UrlEncode(Tools.Crypto.Encrypt("Id=0&Activo=" + id)) : "0";
        }
    }

    /// <summary>
    /// La criticidad en la lista va sin la palabra "Criticidad": la columna ya
    /// se llama asi, y repetirla en cada fila no deja ancho para el nivel.
    /// </summary>
    private string ChipNivelCriticidad(string nivel)
    {
        string n = (nivel ?? "").ToUpperInvariant();

        string clase = n.Contains("CRITIC") || n.Contains("ALTA") ? "es-aviso"
                     : (n.Contains("BAJA") ? "es-ok" : "es-neutro");

        return "<span class=\"sg-ot-chip " + clase + "\">" +
               Server.HtmlEncode(string.IsNullOrEmpty(nivel) ? "Sin definir" : nivel) + "</span>";
    }

    /// <summary>El id del campo oculto que el JS usa para elegir un equipo.</summary>
    protected string IdCampoActivo { get { return hdnActivo.ClientID; } }

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
        InspeccionesYTareas(a);
        RepuestosYCostos(a);
        SigmaAi(a, ordenes, fallas);
        BitacoraYTrazabilidad(a, eventos);
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

        /* Editar el activo ya no abre un modal: lleva a la pestaña Ficha,
           que es el mismo formulario sin sacar a nadie del centro. */
        hlEditar.Attributes["onclick"] = "sigmaActivo360.irA('ficha'); return false;";

        hlGenerarOT.NavigateUrl = ResolveUrl("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx");
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

        /* Cada KPI toma el color de LO QUE MIDE y no el morado de marca: el
           trabajo abierto en ambar, la falla en rojo, lo planificado en azul.
           Cuatro iconos iguales se leen como cuatro veces lo mismo. */
        k.Append(Kpi("mdi-clipboard-text-outline", abiertas.Count.ToString(), "OT abiertas", "",
                 abiertas.Count > 0 ? "es-ambar" : "es-verde"));
        k.Append(Kpi("mdi-alert-outline", fallasAbiertas.Count.ToString(), "Fallas abiertas", "",
                 fallasAbiertas.Count > 0 ? "es-rojo" : "es-verde"));
        k.Append(Kpi("mdi-calendar-outline",
                 proxima == null ? "Sin programar" : proxima.fecha_programada.ToString("dd MMM yyyy"),
                 "Próxima mantención",
                 proxima == null ? "" : Texto(proxima.hito_nombre), "es-azul", proxima == null));
        k.Append(Kpi("mdi-clock-outline", Duracion(minutos), "Detención del período",
                 hoy.ToString("MMMM yyyy"), minutos > 0 ? "es-ambar" : "es-teal"));

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
                     Boton(UrlFalla(f.fal_id), "Ver falla")));

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
             .Append(Boton(UrlOrden(o.otr_id), "Abrir OT completa"))
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

    /// <summary>
    /// Lo que el plan tiene dicho para este equipo y cuando le toca.
    ///
    /// LA AGENDA ES UN CALENDARIO Y NO OTRA LISTA
    ///   La lista de al lado responde "que viene"; el calendario responde
    ///   "como viene el mes", que es la pregunta de quien tiene que repartir
    ///   gente. Dos semanas seguidas con cuatro mantenciones cada una se ven
    ///   en el calendario y no se ven en una lista ordenada por fecha.
    /// </summary>
    private void Mantenimiento(Activo a, List<PlanOcurrencia> ocurrencias)
    {
        DateTime hoy = global::SitioBase.Hora.Hoy;

        // ---- planes que lo cubren ----
        var planes = ocurrencias
            .GroupBy(o => new { o.plan_id, o.plan_codigo, o.plan_nombre, o.version_numero })
            .Select(g => g.Key).ToList();

        if (planes.Count == 0)
        {
            litPlanes.Text = "<div class=\"sg-ot-vacio es-chico\"><i class=\"mdi mdi-calendar-remove-outline\"></i>" +
                             "<p>Sin plan de mantenimiento</p>" +
                             "<span>Este equipo no está incluido en ningún plan: todo lo que se le haga será correctivo.</span></div>";
        }
        else
        {
            StringBuilder p = new StringBuilder();

            p.Append("<div class=\"sg-a3-tabla-cab sg-mant-plan-cab\">")
             .Append("<span>Código</span><span>Plan</span><span>Versión</span><span></span></div>");

            foreach (var pl in planes)
                p.Append("<div class=\"sg-a3-tabla-fila sg-mant-plan\">")
                 .Append("<span class=\"c-dato\"><span class=\"sg-a3-codigo\">")
                 .Append(Server.HtmlEncode(Texto(pl.plan_codigo))).Append("</span></span>")
                 .Append("<span class=\"c-cod\">").Append(Server.HtmlEncode(Texto(pl.plan_nombre))).Append("</span>")
                 .Append("<span class=\"c-dato\">")
                 .Append(pl.version_numero == null
                        ? "<span class=\"sg-ot-chip es-aviso\">Sin publicar</span>"
                        : "<span class=\"sg-ot-chip es-ok\">v" + pl.version_numero + " publicada</span>")
                 .Append("</span>")
                 .Append("<span class=\"c-acc\">").Append(Boton(UrlPlan(pl.plan_id), "Ver plan")).Append("</span>")
                 .Append("</div>");

            litPlanes.Text = p.ToString();
        }

        // ---- proximas actividades ----
        List<PlanOcurrencia> proximas = ocurrencias
            .Where(x => x.fecha_programada.Date >= hoy)
            .OrderBy(x => x.fecha_programada)
            .ToList();

        litOcurrenciasConteo.Text = proximas.Count == 0 ? "" :
            "<div class=\"sg-ot-card-acc sg-ot-avance\"><div class=\"sg-ot-avance-num\"><strong>" +
            proximas.Count + "</strong><span>por delante</span></div></div>";

        if (proximas.Count == 0)
        {
            litOcurrencias.Text = "<p class=\"sg-ot-vacio-txt\">No hay mantenciones programadas por delante.</p>";
        }
        else
        {
            StringBuilder oc = new StringBuilder();

            oc.Append("<div class=\"sg-a3-tabla-cab sg-mant-oc-cab\">")
              .Append("<span>Fecha</span><span>Actividad</span><span>Plan</span>")
              .Append("<span>Situación</span><span>OT</span></div>");

            foreach (PlanOcurrencia o in proximas.Take(10))
                oc.Append("<div class=\"sg-a3-tabla-fila sg-mant-oc\">")
                  .Append("<span class=\"c-cod\">").Append(o.fecha_programada.ToString("dd MMM yyyy"))
                  .Append("<span>").Append(Dias(o.fecha_programada, hoy)).Append("</span></span>")
                  .Append("<span class=\"c-dato\">").Append(Server.HtmlEncode(Texto(o.hito_nombre))).Append("</span>")
                  .Append("<span class=\"c-dato\">").Append(Server.HtmlEncode(Texto(o.plan_codigo))).Append("</span>")
                  .Append("<span class=\"c-dato\">").Append(ChipSituacionActivo(o.situacion)).Append("</span>")
                  .Append("<span class=\"c-dato\">")
                  .Append(o.orden_trabajo_id == null
                         ? "<span class=\"sg-ot-vacio-txt\">Sin generar</span>"
                         : Boton(UrlOrden(o.orden_trabajo_id.Value), "OT-" + o.orden_trabajo_correlativo))
                  .Append("</span>")
                  .Append("</div>");

            litOcurrencias.Text = oc.ToString();
        }

        // ---- tareas recurrentes ----
        List<Tarea> tareas = new TareaController().GetTareas(new Tarea { filtro_activo = a.act_id }) ?? new List<Tarea>();

        if (tareas.Count == 0)
        {
            litTareas.Text = "<p class=\"sg-ot-vacio-txt\">Este equipo no tiene tareas recurrentes.</p>";
        }
        else
        {
            StringBuilder tb = new StringBuilder();

            tb.Append("<div class=\"sg-a3-tabla-cab sg-mant-tar-cab\">")
              .Append("<span>Código</span><span>Tarea</span><span>Programaciones</span><span></span></div>");

            foreach (Tarea x in tareas)
                tb.Append("<div class=\"sg-a3-tabla-fila sg-mant-tar\">")
                  .Append("<span class=\"c-dato\"><span class=\"sg-a3-codigo\">")
                  .Append(Server.HtmlEncode(Texto(x.tar_codigo))).Append("</span></span>")
                  .Append("<span class=\"c-cod\">").Append(Server.HtmlEncode(Texto(x.tar_titulo))).Append("</span>")
                  .Append("<span class=\"c-dato\">").Append(x.programaciones)
                  .Append(x.programaciones == 1 ? " programación" : " programaciones")
                  .Append(x.pendientes > 0 ? " · " + x.pendientes + " pendientes" : "").Append("</span>")
                  .Append("<span class=\"c-acc\">").Append(Boton(UrlTarea(x.tar_id), "Ver tarea")).Append("</span>")
                  .Append("</div>");

            litTareas.Text = tb.ToString();
        }

        Agenda(ocurrencias, hoy);
    }

    /// <summary>
    /// El mes en curso con un punto en los dias que tienen algo. El detalle
    /// del dia se arma en el navegador con lo que ya viaja en la casilla: son
    /// treinta dias, no hace falta volver al servidor por cada uno.
    /// </summary>
    private void Agenda(List<PlanOcurrencia> ocurrencias, DateTime hoy)
    {
        DateTime primero = new DateTime(hoy.Year, hoy.Month, 1);
        int dias = DateTime.DaysInMonth(hoy.Year, hoy.Month);

        /* La semana empieza el lunes: es como se reparte el trabajo en una
           planta, y como lo muestra el calendario del plan. */
        int desplazamiento = ((int)primero.DayOfWeek + 6) % 7;

        StringBuilder s = new StringBuilder("<div class=\"sg-mant-cal\">");

        s.Append("<header class=\"sg-mant-cal-cab\"><strong>")
         .Append(Server.HtmlEncode(primero.ToString("MMMM yyyy"))).Append("</strong></header>");

        s.Append("<div class=\"sg-mant-cal-dias\">");
        foreach (string d in new[] { "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom" })
            s.Append("<span>").Append(d).Append("</span>");
        s.Append("</div>");

        s.Append("<div class=\"sg-mant-cal-grid\">");

        for (int i = 0; i < desplazamiento; i++) s.Append("<span class=\"sg-mant-cal-hueco\"></span>");

        for (int d = 1; d <= dias; d++)
        {
            DateTime dia = new DateTime(hoy.Year, hoy.Month, d);

            List<PlanOcurrencia> delDia = ocurrencias.Where(x => x.fecha_programada.Date == dia).ToList();

            string clases = "sg-mant-cal-dia";
            if (dia == hoy) clases += " es-hoy";
            if (delDia.Count > 0) clases += " es-con";
            if (delDia.Any(x => x.orden_trabajo_id != null)) clases += " es-ot";

            s.Append("<a href=\"javascript:void(0)\" class=\"").Append(clases)
             .Append("\" data-dia=\"").Append(dia.ToString("dd MMM yyyy"))
             .Append("\" data-eventos=\"").Append(Server.HtmlEncode(Eventos(delDia)))
             .Append("\">").Append(d);

            if (delDia.Count > 0) s.Append("<i></i>");

            s.Append("</a>");
        }

        s.Append("</div>");

        s.Append("<div class=\"sg-mant-cal-leyenda\">")
         .Append("<span><i class=\"es-con\"></i>Ocurrencia planificada</span>")
         .Append("<span><i class=\"es-ot\"></i>Con OT vinculada</span>")
         .Append("</div></div>");

        litAgenda.Text = s.ToString();
    }

    /// <summary>
    /// Lo del dia, en una linea por evento. Viaja como texto en la casilla
    /// para que el detalle se pinte sin pedir nada.
    /// </summary>
    private string Eventos(List<PlanOcurrencia> delDia)
    {
        if (delDia.Count == 0) return "";

        List<string> lineas = new List<string>();

        foreach (PlanOcurrencia o in delDia.OrderBy(x => x.fecha_programada))
            lineas.Add(o.fecha_programada.ToString("HH:mm") + " · " + Texto(o.hito_nombre) +
                       (o.orden_trabajo_correlativo == null ? "" : " · OT-" + o.orden_trabajo_correlativo));

        return string.Join("\n", lineas.ToArray());
    }

    /// <summary>Cuanto falta, en palabras: "en 3 días" se lee mejor que una resta.</summary>
    private static string Dias(DateTime fecha, DateTime hoy)
    {
        int d = (int)(fecha.Date - hoy).TotalDays;

        if (d == 0) return "hoy";
        if (d == 1) return "mañana";
        if (d < 0) return "hace " + (-d) + " días";

        return "en " + d + " días";
    }

    private static string ChipSituacionActivo(string situacion)
    {
        switch ((situacion ?? "").ToUpperInvariant())
        {
            case "VENCIDA": return "<span class=\"sg-ot-chip es-rojo\">Vencida</span>";
            case "ATRASADA": return "<span class=\"sg-ot-chip es-aviso\">Atrasada</span>";
            case "DISPONIBLE": return "<span class=\"sg-ot-chip es-ok\">Disponible</span>";
            case "CERRADA": return "<span class=\"sg-ot-chip es-neutro\">Cerrada</span>";
            default: return "<span class=\"sg-ot-chip es-info\">Futura</span>";
        }
    }

    #endregion

    #region 5. Ficha tecnica

    /// <summary>
    /// La pestaña Ficha muestra el MISMO formulario del modal de alta, como
    /// control compartido. Aca solo se le dice de que activo habla y en que
    /// modo se esta mostrando.
    ///
    /// POR QUE NO ES UNA VISTA DE SOLO LECTURA APARTE
    ///   Antes habia una "Ficha tecnica" que solo mostraba, y para cambiar un
    ///   dato mandaba a un modal con los mismos campos. Eran dos pantallas
    ///   para la misma informacion y la de leer siempre se quedaba atras.
    /// </summary>
    private void FichaTecnica(Activo a)
    {
        frmFicha.ActivoDelCentro = a.act_id;

        litFichaModo.Text = Token.Puede("CREAR EDITAR ACTIVOS")
            ? "<span class=\"sg-a3-ficha-chip\"><i class=\"mdi mdi-pencil-outline\"></i>Editando</span>"
            : "<span class=\"sg-a3-ficha-chip es-lectura\"><i class=\"mdi mdi-eye-outline\"></i>Solo lectura</span>";
    }

    /// <summary>
    /// El formulario guardo: la cabecera del centro puede haber cambiado -el
    /// nombre, el estado, la criticidad- y se vuelve a pintar entera.
    /// </summary>
    protected void frmFicha_Guardado(object sender, EventArgs e)
    {
        hdnSeccion.Value = "ficha";
    }

    #endregion

    #region 6. Componentes

    /// <summary>
    /// De que esta hecho el equipo: su estructura, sus piezas y lo que se les
    /// cambio.
    ///
    /// EL DETALLE SE ARMA EN EL NAVEGADOR
    ///   Cada fila lleva lo suyo en atributos. Pedirle el componente al
    ///   servidor para mostrar lo que ya esta en pantalla es un viaje de mas
    ///   y una pantalla que parpadea al elegir una fila.
    /// </summary>
    private void Componentes(Activo a)
    {
        List<ActivoComponente> lista = new ActivoComponenteController().GetComponentes(
            new ActivoComponente { aco_cliente = _cliente, filtro_activo = a.act_id })
            ?? new List<ActivoComponente>();

        bool puedeEditar = Token.Puede("CREAR EDITAR COMPONENTES");
        lnkNuevoComponente.Visible = puedeEditar;

        litCompTitulo.Text = "Componentes de " + Server.HtmlEncode(Texto(a.act_nombre));

        int instalados = lista.Count(c => c.aco_habilitado);
        litCompInstalados.Text = instalados.ToString();
        litCompRetirados.Text = (lista.Count - instalados).ToString();

        Arbol(a, lista);

        if (lista.Count == 0)
        {
            litComponentes.Text = "<div class=\"sg-ot-vacio\"><i class=\"mdi mdi-puzzle-outline\"></i>" +
                                  "<p>Sin componentes registrados</p><span>" +
                                  (puedeEditar ? "Agregue las partes del equipo con «Asociar componente»."
                                               : "Las partes del equipo todavía no se han cargado.") +
                                  "</span></div>";
            litReemplazos.Text = "<p class=\"sg-ot-vacio-txt\">Sin componentes, no hay reemplazos que mostrar.</p>";
            return;
        }

        ActivoComponenteImagenController imagenes = new ActivoComponenteImagenController();

        StringBuilder s = new StringBuilder();

        s.Append("<div class=\"sg-a3-tabla-cab sg-comp-cab\">")
         .Append("<span></span><span>Código</span><span>Descripción</span><span>Instalación</span>")
         .Append("<span>Estado</span><span></span></div>");

        foreach (ActivoComponente c in lista.OrderBy(x => x.aco_codigo))
        {
            string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + c.aco_id));

            /* La foto de la pieza: "cambiar el rodamiento lado motor" se
               decide mirandola, no leyendo su codigo. */
            int foto = imagenes.GetImagenId(c.aco_id, _cliente);
            string urlFoto = foto > 0 ? UrlArchivo.Ver(foto) : "";

            s.Append("<div class=\"sg-a3-tabla-fila sg-comp-fila\" data-comp=\"").Append(c.aco_id)
             .Append("\" data-comp-foto=\"").Append(Server.HtmlEncode(urlFoto))
             .Append("\" data-comp-estado=\"").Append(c.aco_habilitado ? "instalados" : "retirados")
             .Append("\" data-comp-txt=\"").Append(Server.HtmlEncode((Texto(c.aco_codigo) + " " + Texto(c.aco_nombre) + " " + Texto(c.tipo_nombre)).ToLower()))
             .Append("\" data-comp-nombre=\"").Append(Server.HtmlEncode(Texto(c.aco_nombre)))
             .Append("\" data-comp-codigo=\"").Append(Server.HtmlEncode(Texto(c.aco_codigo)))
             .Append("\" data-comp-tipo=\"").Append(Server.HtmlEncode(Texto(c.tipo_nombre)))
             .Append("\" data-comp-desc=\"").Append(Server.HtmlEncode(Texto(c.aco_descripcion)))
             .Append("\" data-comp-criticidad=\"").Append(Server.HtmlEncode(Texto(c.criticidad_nombre)))
             .Append("\" data-comp-posicion=\"").Append(Server.HtmlEncode(Texto(c.posicion_nombre)))
             .Append("\" data-comp-padre=\"").Append(Server.HtmlEncode(Texto(c.padre_nombre)))
             .Append("\" data-comp-instalacion=\"")
             .Append(c.aco_fecha_instalacion == null ? "" : c.aco_fecha_instalacion.Value.ToString("dd MMM yyyy"))
             .Append("\" data-comp-estado-txt=\"").Append(Server.HtmlEncode(Texto(c.estado_nombre)))
             .Append("\" data-comp-motivo=\"").Append(Server.HtmlEncode(Texto(c.aco_motivo_estado)))
             .Append("\" data-comp-query=\"").Append(query).Append("\">")

             .Append("<span class=\"c-dato\">")
             .Append(foto > 0
                    ? "<span class=\"sg-comp-foto\"><img src=\"" + Server.HtmlEncode(urlFoto) + "\" alt=\"" + Server.HtmlEncode(Texto(c.aco_nombre)) + "\" /></span>"
                    : "<span class=\"sg-comp-foto es-vacia\"><i class=\"mdi mdi-puzzle-outline\"></i></span>")
             .Append("</span>")
             .Append("<span class=\"c-dato\"><span class=\"sg-a3-codigo\">").Append(Server.HtmlEncode(Texto(c.aco_codigo))).Append("</span></span>")
             .Append("<span class=\"c-cod\">").Append(Server.HtmlEncode(Texto(c.aco_nombre)))
             .Append("<span>").Append(Server.HtmlEncode(Texto(c.tipo_nombre))).Append("</span></span>")
             .Append("<span class=\"c-dato\">")
             .Append(c.aco_fecha_instalacion == null ? "—" : c.aco_fecha_instalacion.Value.ToString("dd MMM yyyy"))
             .Append("</span>")
             .Append("<span class=\"c-dato\">").Append(ChipEstadoComponente(c)).Append("</span>")
             .Append("<span class=\"c-acc\">")
             .Append("<a class=\"sg-ot-btn es-plano\" href=\"javascript:void(0)\" onclick=\"abrirComponente('")
             .Append(query).Append("')\"><i class=\"mdi ").Append(puedeEditar ? "mdi-pencil-outline" : "mdi-eye-outline")
             .Append("\"></i>").Append(puedeEditar ? "Editar" : "Ver").Append("</a></span>")
             .Append("</div>");
        }

        litComponentes.Text = s.ToString();

        Reemplazos(a);
    }

    /// <summary>
    /// La estructura del equipo: sus piezas de primer nivel y lo que cuelga de
    /// cada una. Dos niveles alcanzan: un arbol mas hondo en una barra angosta
    /// se lee peor que la lista de al lado.
    /// </summary>
    private void Arbol(Activo a, List<ActivoComponente> lista)
    {
        StringBuilder s = new StringBuilder("<ul class=\"sg-comp-arbol-lista\">");

        s.Append("<li class=\"es-raiz\"><span class=\"sg-comp-nodo es-equipo\">")
         .Append("<i class=\"mdi mdi-cog-outline\"></i><div><strong>")
         .Append(Server.HtmlEncode(Texto(a.act_nombre))).Append("</strong><span>")
         .Append(Server.HtmlEncode(Texto(a.act_codigo))).Append("</span></div></span>");

        List<ActivoComponente> raiz = lista.Where(c => c.aco_componente_padre == null).OrderBy(c => c.aco_codigo).ToList();

        if (raiz.Count > 0)
        {
            s.Append("<ul>");

            foreach (ActivoComponente c in raiz)
            {
                s.Append(Nodo(c));

                List<ActivoComponente> hijos = lista.Where(x => x.aco_componente_padre == c.aco_id).OrderBy(x => x.aco_codigo).ToList();

                if (hijos.Count > 0)
                {
                    s.Append("<ul>");
                    foreach (ActivoComponente h in hijos) s.Append(Nodo(h)).Append("</li>");
                    s.Append("</ul>");
                }

                s.Append("</li>");
            }

            s.Append("</ul>");
        }

        s.Append("</li></ul>");

        litArbol.Text = s.ToString();
    }

    /// <summary>
    /// El color del estado sale del ESTADO y no de si esta habilitado: un
    /// componente degradado sigue habilitado, y pintarlo en verde es decir
    /// que esta bien.
    /// </summary>
    private string ChipEstadoComponente(ActivoComponente c)
    {
        string nombre = Texto(c.estado_nombre);
        string n = nombre.ToUpperInvariant();

        string clase = !c.aco_habilitado ? "es-neutro"
                     : (n.Contains("OPERATIV") || n.Contains("NUEVO") ? "es-ok"
                     : (n.Contains("FUERA") || n.Contains("FALLA") ? "es-rojo" : "es-aviso"));

        return "<span class=\"sg-ot-chip " + clase + "\">" +
               Server.HtmlEncode(string.IsNullOrEmpty(nombre) ? "Sin estado" : nombre) + "</span>";
    }

    private string Nodo(ActivoComponente c)
    {
        return "<li><a href=\"javascript:void(0)\" class=\"sg-comp-nodo\" data-ir-comp=\"" + c.aco_id + "\">" +
               "<i class=\"mdi " + (c.aco_habilitado ? "mdi-circle-small" : "mdi-close-circle-outline") + "\"></i>" +
               "<div><strong>" + Server.HtmlEncode(Texto(c.aco_nombre)) + "</strong>" +
               "<span>" + Server.HtmlEncode(Texto(c.aco_codigo)) + "</span></div></a>";
    }

    /// <summary>
    /// Que repuesto se le cambio a cada pieza, con la orden que lo consumio.
    /// Es lo que responde "cuantos rodamientos lleva este ventilador".
    /// </summary>
    private void Reemplazos(Activo a)
    {
        List<ActivoConsumo> consumos = new ActivoCentroController().GetConsumos(a.act_id)
                                       ?? new List<ActivoConsumo>();

        if (consumos.Count == 0)
        {
            litReemplazos.Text = "<p class=\"sg-ot-vacio-txt\">Todavía no se registran repuestos consumidos en este equipo.</p>";
            return;
        }

        StringBuilder s = new StringBuilder();

        s.Append("<div class=\"sg-a3-tabla-cab sg-comp-rep-cab\">")
         .Append("<span>Fecha</span><span>Repuesto</span><span>Componente</span>")
         .Append("<span>Cantidad</span><span>Orden</span><span></span></div>");

        foreach (ActivoConsumo c in consumos)
        {
            s.Append("<div class=\"sg-a3-tabla-fila sg-comp-rep\" data-comp-rep=\"")
             .Append(c.componente_id == null ? "" : c.componente_id.Value.ToString()).Append("\">")
             .Append("<span class=\"c-dato\">").Append(c.fecha == null ? "—" : c.fecha.Value.ToString("dd MMM yyyy")).Append("</span>")
             .Append("<span class=\"c-cod\">").Append(Server.HtmlEncode(Texto(c.repuesto_nombre)))
             .Append("<span>").Append(Server.HtmlEncode(Texto(c.repuesto_codigo))).Append("</span></span>")
             .Append("<span class=\"c-dato\">")
             .Append(Server.HtmlEncode(string.IsNullOrEmpty(c.componente) ? "Equipo completo" : c.componente)).Append("</span>")
             .Append("<span class=\"c-dato\">").Append(Server.HtmlEncode(Cantidad(c.cantidad, c.unidad))).Append("</span>")
             .Append("<span class=\"c-dato\"><span class=\"sg-a3-codigo\">").Append(c.orden_codigo).Append("</span></span>")
             .Append("<span class=\"c-acc\">").Append(Boton(UrlOrden(c.orden_id), "Abrir OT")).Append("</span>")
             .Append("</div>");
        }

        litReemplazos.Text = s.ToString();
    }

    #endregion

    #region 7. Fallas e indisponibilidad

    /// <summary>
    /// Lo que se reporto del equipo y el tiempo que costo.
    ///
    /// SON DOS CUENTAS DISTINTAS
    ///   Una falla es lo que le paso a la maquina; una detencion es el tiempo
    ///   que estuvo parada. Una falla puede no detener nada y una detencion
    ///   planificada no viene de ninguna falla. Mezclarlas en una lista
    ///   obliga a leer cada fila para saber cual es cual.
    /// </summary>
    private void FallasYDetenciones(Activo a, List<Falla> fallas, List<ActivoIndisponibilidad> detenciones)
    {
        // ======================================================== fallas ====
        int abiertas = fallas.Count(f => f.fal_fecha_solucion_utc == null);

        litFallasN.Text = fallas.Count.ToString();
        litFallasAbiertas.Text = abiertas.ToString();

        if (fallas.Count == 0)
        {
            litFallas.Text = "<div class=\"sg-ot-vacio\"><i class=\"mdi mdi-check-circle-outline\"></i>" +
                             "<p>Sin fallas registradas</p>" +
                             "<span>Este equipo no tiene fallas reportadas.</span></div>";
        }
        else
        {
            StringBuilder s = new StringBuilder();

            s.Append("<div class=\"sg-a3-tabla-cab sg-falla-cab\">")
             .Append("<span>Falla</span><span>Síntoma</span><span>Criticidad</span>")
             .Append("<span>Estado</span><span>Detectada</span><span>OT</span><span></span></div>");

            foreach (Falla f in fallas.OrderByDescending(x => x.fal_fecha_deteccion_utc ?? x.fal_fecha_creacion))
            {
                bool abierta = f.fal_fecha_solucion_utc == null;

                s.Append("<div class=\"sg-a3-tabla-fila sg-falla\" data-falla-estado=\"")
                 .Append(abierta ? "abierta" : "resuelta")
                 .Append("\" data-falla-txt=\"")
                 .Append(Server.HtmlEncode((Texto(f.fal_titulo) + " " + Texto(f.sintoma_nombre) + " " + Texto(f.componente_nombre)).ToLower()))
                 .Append("\">")

                 .Append("<span class=\"c-cod\">").Append(Server.HtmlEncode(Texto(f.fal_titulo)))
                 .Append("<span>")
                 .Append(Server.HtmlEncode(string.IsNullOrEmpty(f.componente_nombre) ? "Equipo completo" : f.componente_nombre))
                 .Append("</span></span>")

                 .Append("<span class=\"c-dato\">").Append(Server.HtmlEncode(Texto(f.sintoma_nombre))).Append("</span>")
                 .Append("<span class=\"c-dato\">").Append(ChipCriticidad(f.criticidad_nombre)).Append("</span>")

                 .Append("<span class=\"c-dato\">")
                 .Append(abierta
                        ? "<span class=\"sg-ot-chip es-rojo\"><i class=\"mdi mdi-alert-circle-outline\"></i>Abierta</span>"
                        : "<span class=\"sg-ot-chip es-ok\"><i class=\"mdi mdi-check\"></i>Resuelta</span>")
                 .Append("</span>")

                 .Append("<span class=\"c-dato\">")
                 .Append(f.fal_fecha_deteccion_utc == null ? "—" : f.fal_fecha_deteccion_utc.Value.ToString("dd MMM yyyy"))
                 .Append("</span>")

                 .Append("<span class=\"c-dato\">")
                 .Append(f.ultima_ot_correlativo == null
                        ? "<span class=\"sg-ot-vacio-txt\">Sin OT</span>"
                        : "<span class=\"sg-a3-codigo\">OT-" + f.ultima_ot_correlativo + "</span>")
                 .Append("</span>")

                 .Append("<span class=\"c-acc\">").Append(Boton(UrlFalla(f.fal_id), "Abrir falla")).Append("</span>")
                 .Append("</div>");
            }

            litFallas.Text = s.ToString();
        }

        // =================================================== detenciones ====
        DateTime hoy = global::SitioBase.Hora.Hoy;
        DateTime mes = new DateTime(hoy.Year, hoy.Month, 1);

        int minutosMes = detenciones.Where(d => d.ain_fecha_inicio_utc >= mes).Sum(d => d.minutos_acumulados);
        int minutosNoPlan = detenciones.Where(d => d.ain_fecha_inicio_utc >= mes && !d.ain_planificada).Sum(d => d.minutos_acumulados);

        litDetencionesN.Text = detenciones.Count.ToString();

        litDetencionTotal.Text =
            "<div class=\"sg-a3-kpis\">" +
            Kpi("mdi-clock-outline", Duracion(minutosMes), "Detención del período",
                hoy.ToString("MMMM yyyy"), minutosMes > 0 ? "es-ambar" : "es-verde") +
            Kpi("mdi-flash-outline", Duracion(minutosNoPlan), "De ella, no planificada",
                minutosNoPlan > 0 ? "Tiempo que se perdió" : "Nada imprevisto",
                minutosNoPlan > 0 ? "es-rojo" : "es-verde") +
            Kpi("mdi-counter", detenciones.Count.ToString(), "Detenciones registradas", "Historia completa", "es-azul") +
            "</div>";

        if (detenciones.Count == 0)
        {
            litIndisponibilidad.Text = "<div class=\"sg-ot-vacio\"><i class=\"mdi mdi-power-plug-outline\"></i>" +
                                       "<p>Sin períodos de detención</p>" +
                                       "<span>El equipo no registra paradas.</span></div>";
        }
        else
        {
            StringBuilder d = new StringBuilder();

            d.Append("<div class=\"sg-a3-tabla-cab sg-deten-cab\">")
             .Append("<span>Inicio</span><span>Fin</span><span>Duración</span>")
             .Append("<span>Tipo</span><span>Causa</span><span>OT</span><span></span></div>");

            foreach (ActivoIndisponibilidad i in detenciones.OrderByDescending(x => x.ain_fecha_inicio_utc))
            {
                bool abierta = i.ain_fecha_fin_utc == null;

                d.Append("<div class=\"sg-a3-tabla-fila sg-deten\">")
                 .Append("<span class=\"c-cod\">").Append(i.ain_fecha_inicio_utc.ToString("dd MMM yyyy"))
                 .Append("<span>").Append(i.ain_fecha_inicio_utc.ToString("HH:mm")).Append("</span></span>")

                 .Append("<span class=\"c-dato\">")
                 .Append(abierta
                        ? "<span class=\"sg-ot-chip es-rojo\">Sigue detenido</span>"
                        : Server.HtmlEncode(i.ain_fecha_fin_utc.Value.ToString("dd MMM yyyy · HH:mm")))
                 .Append("</span>")

                 .Append("<span class=\"c-dato\">").Append(Duracion(i.minutos_acumulados)).Append("</span>")

                 .Append("<span class=\"c-dato\">")
                 .Append(i.ain_planificada
                        ? "<span class=\"sg-ot-chip es-info\">Planificada</span>"
                        : "<span class=\"sg-ot-chip es-aviso\">No planificada</span>")
                 .Append("</span>")

                 .Append("<span class=\"c-dato\">")
                 .Append(Server.HtmlEncode(
                     !string.IsNullOrEmpty(i.motivo_nombre) ? i.motivo_nombre
                     : (!string.IsNullOrEmpty(i.falla_titulo) ? i.falla_titulo : Texto(i.ain_motivo))))
                 .Append("</span>")

                 .Append("<span class=\"c-dato\">")
                 .Append(i.ot_correlativo == null
                        ? "<span class=\"sg-ot-vacio-txt\">—</span>"
                        : "<span class=\"sg-a3-codigo\">OT-" + i.ot_correlativo + "</span>")
                 .Append("</span>")

                 .Append("<span class=\"c-acc\">")
                 .Append(i.ain_orden_trabajo == null ? "" : Boton(UrlOrden(i.ain_orden_trabajo.Value), "Abrir OT"))
                 .Append("</span>")
                 .Append("</div>");
            }

            litIndisponibilidad.Text = d.ToString();
        }

        // ---- el estado de AHORA, en la cabecera ----
        bool detenidoAhora = detenciones.Any(x => x.ain_fecha_fin_utc == null);

        litEstadoAhora.Text = detenidoAhora
            ? "<span class=\"sg-ot-chip es-rojo sg-ot-card-acc\"><i class=\"mdi mdi-flash-outline\"></i>Detenido ahora</span>"
            : "<span class=\"sg-ot-chip es-ok sg-ot-card-acc\"><i class=\"mdi mdi-check-circle-outline\"></i>Operando</span>";
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
    /// <summary>
    /// Lo que se mide del equipo: su ultima lectura, contra que se compara y
    /// de donde vino ese numero.
    ///
    /// LA TABLA Y LAS TARJETAS DICEN LO MISMO A PROPOSITO
    ///   La tarjeta responde "como esta" de un vistazo; la tabla responde
    ///   "contra que" -los umbrales-, que es lo que hay que mirar antes de
    ///   decidir. Con solo tarjetas hay que abrir la ficha de cada variable
    ///   para ver el rango; con solo tabla, el estado se pierde entre numeros.
    /// </summary>
    private void Condicion(Activo a)
    {
        ActivoVariableController ctlVar = new ActivoVariableController();

        List<ActivoVariable> variables = ctlVar.GetVariables(
            new ActivoVariable { ava_cliente = _cliente, filtro_activo = a.act_id, filtro_habilitado = true })
            ?? new List<ActivoVariable>();

        bool puedeVariable = Token.Puede("CREAR EDITAR VARIABLES ACTIVO");
        lnkNuevaVariable.Visible = puedeVariable;

        lnkRegistrarLectura.Visible = Token.Puede("REGISTRAR MEDICION") || Token.Puede("REGISTRAR LECTURA");

        litCondActivo.Text = Server.HtmlEncode(Texto(a.act_nombre)) +
                             (string.IsNullOrEmpty(a.act_codigo) ? "" : " · " + Server.HtmlEncode(a.act_codigo));

        litCondVariables.Text = litCondVariables2.Text = variables.Count.ToString();

        DateTime hoy = global::SitioBase.Hora.Hoy;

        StringBuilder tarjetas = new StringBuilder();
        StringBuilder lecturas = new StringBuilder();

        int fuera = 0, revisar = 0, sinLectura = 0;

        foreach (ActivoVariable v in variables)
        {
            MedicionSerieResumen r = ctlVar.GetSerieResumen(v.ava_id, hoy.AddDays(-90), null);

            string clase, etiqueta;
            Semaforo(v, r, hoy, out clase, out etiqueta);

            if (clase == "es-critico") fuera++;
            else if (clase == "es-aviso") revisar++;
            else if (clase == "es-sin") sinLectura++;

            bool hay = r != null && r.ultimo_valor != null;
            string valor = hay ? r.ultimo_valor.Value.ToString("N2").TrimEnd('0').TrimEnd(',', '.') : "—";
            string unidad = Texto(v.unidad_simbolo);
            string componente = string.IsNullOrEmpty(v.componente_nombre) ? "Equipo completo" : v.componente_nombre;
            string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + v.ava_id));

            List<MedicionSerie> serie = ctlVar.GetSerie(v.ava_id, hoy.AddDays(-90), null) ?? new List<MedicionSerie>();
            MedicionSerie ultima = serie.OrderByDescending(x => x.fecha).FirstOrDefault();

            tarjetas.Append("<a href=\"javascript:void(0)\" class=\"sg-cond-card ").Append(clase)
                    .Append("\" data-cond=\"variable\" data-clase=\"").Append(clase)
                    .Append("\" data-id=\"v").Append(v.ava_id)
                    .Append("\" data-buscar=\"")
                    .Append(Server.HtmlEncode((Texto(v.variable_nombre) + " " + componente + " " + unidad).ToLowerInvariant()))
                    .Append("\" data-titulo=\"").Append(Server.HtmlEncode(Texto(v.variable_nombre)))
                    .Append("\" data-sub=\"").Append(Server.HtmlEncode(componente))
                    .Append("\" data-rango=\"").Append(Server.HtmlEncode(Rangos(v)))
                    .Append("\" data-frecuencia=\"")
                    .Append(v.ava_frecuencia_esperada_hora == null ? "Sin frecuencia definida" : "Se espera una lectura cada " + v.ava_frecuencia_esperada_hora + " h")
                    .Append("\" data-serie=\"").Append(UrlSerie(v.ava_id))
                    .Append("\" data-query=\"").Append(query)
                    .Append("\" data-lectura=\"")
                    .Append(Server.UrlEncode(Tools.Crypto.Encrypt("Activo=" + a.act_id + "&Que=v" + v.ava_id)))
                    .Append("\" data-editar=\"").Append(puedeVariable ? "1" : "0").Append("\">")

                    .Append("<span class=\"sg-cond-card-top\">")
                    .Append("<span class=\"sg-cond-ico\"><i class=\"mdi ").Append(IconoVariable(v.variable_nombre)).Append("\"></i></span>")
                    .Append("<span class=\"sg-cond-card-id\"><strong>").Append(Server.HtmlEncode(Texto(v.variable_nombre))).Append("</strong>")
                    .Append("<span>").Append(Server.HtmlEncode(componente)).Append("</span></span>")
                    .Append(ChipEstado(clase, etiqueta))
                    .Append("</span>")

                    .Append("<span class=\"sg-cond-card-val\"><b>").Append(Server.HtmlEncode(valor)).Append("</b>")
                    .Append(unidad.Length == 0 ? "" : "<small>" + Server.HtmlEncode(unidad) + "</small>")
                    .Append("</span>")

                    .Append("<span class=\"sg-cond-card-ref\">").Append(Server.HtmlEncode(Referencia(v, clase, unidad))).Append("</span>")

                    .Append("<span class=\"sg-cond-card-pie\">")
                    .Append(hay
                        ? "<span><i class=\"mdi mdi-clock-outline\"></i>" + Server.HtmlEncode(Cuando(r.ultima_fecha_utc, ultima == null ? "" : ultima.origen)) + "</span><em>Ver detalle <i class=\"mdi mdi-arrow-right\"></i></em>"
                        : "<span></span><em>Registrar lectura <i class=\"mdi mdi-arrow-right\"></i></em>")
                    .Append("</span></a>");

            foreach (MedicionSerie p in serie.OrderByDescending(x => x.fecha).Take(6))
                lecturas.Append("<div class=\"sg-cond-lec\" data-de=\"v").Append(v.ava_id).Append("\">")
                        .Append("<span>").Append(p.fecha.ToString("dd MMM yyyy · HH:mm")).Append("</span>")
                        .Append("<b>").Append(p.valor.ToString("0.##"))
                        .Append(unidad.Length == 0 ? "" : " " + Server.HtmlEncode(unidad)).Append("</b>")
                        .Append("<span>").Append(Server.HtmlEncode(Texto(p.origen))).Append("</span>")
                        .Append(ChipNivel(p.nivel))
                        .Append("</div>");
        }

        litCondicion.Text = variables.Count > 0
            ? tarjetas.ToString()
            : "<div class=\"sg-ot-vacio es-chico\"><i class=\"mdi mdi-gauge-empty\"></i>" +
              "<p>Sin variables de condición</p><span>" +
              (puedeVariable ? "Agregue una con «Configurar» y el equipo empezará a medirse."
                             : "Todavía no se ha configurado qué se le mide a este equipo.") + "</span></div>";

        litCondLecturas.Text = lecturas.ToString();

        Aviso(fuera, revisar, sinLectura);
        Medidores(a, variables.Count);
    }

    /// <summary>
    /// La banda de arriba: cuantas piden atencion y por que.
    ///
    /// Con doce tarjetas, la que esta fuera de limite se pierde entre las que
    /// estan bien. La banda la cuenta antes de que haya que buscarla.
    /// </summary>
    private void Aviso(int fuera, int revisar, int sinLectura)
    {
        int total = fuera + revisar + sinLectura;

        if (total == 0)
        {
            litCondAviso.Text = "";
            return;
        }

        List<string> partes = new List<string>();
        if (fuera > 0) partes.Add(fuera + (fuera == 1 ? " fuera de límite" : " fuera de límite"));
        if (revisar > 0) partes.Add(revisar + " para revisar");
        if (sinLectura > 0) partes.Add(sinLectura + (sinLectura == 1 ? " sin lectura" : " sin lectura"));

        litCondAviso.Text =
            "<div class=\"sg-cond-aviso " + (fuera > 0 ? "es-critico" : "es-aviso") + "\">" +
            "<i class=\"mdi mdi-alert-circle-outline\"></i>" +
            "<strong>" + total + (total == 1 ? " variable necesita" : " variables necesitan") + " revisión</strong>" +
            "<span>" + string.Join("  ·  ", partes.ToArray()) + "</span>" +
            "<a href=\"javascript:void(0)\" class=\"sg-cond-aviso-ver\">Ver pendientes <i class=\"mdi mdi-arrow-right\"></i></a></div>";
    }

    /// <summary>El chip del estado, con la palabra corta que se lee de lejos.</summary>
    private static string ChipEstado(string clase, string etiqueta)
    {
        string color;

        switch (clase)
        {
            case "es-critico": color = "es-rojo"; break;
            case "es-aviso": color = "es-aviso"; break;
            case "es-normal": color = "es-ok"; break;
            default: color = "es-neutro"; break;
        }

        string icono = clase == "es-critico" ? "mdi-alert-circle"
                     : clase == "es-aviso" ? "mdi-alert-outline"
                     : clase == "es-normal" ? "mdi-check-circle"
                     : "mdi-minus-circle-outline";

        return "<span class=\"sg-ot-chip " + color + "\"><i class=\"mdi " + icono + "\"></i>" +
               System.Web.HttpUtility.HtmlEncode(etiqueta) + "</span>";
    }

    /// <summary>
    /// Contra que se esta comparando la lectura. No es el listado completo de
    /// rangos: es EL umbral que explica el color de la tarjeta.
    /// </summary>
    private string Referencia(ActivoVariable v, string clase, string unidad)
    {
        string u = unidad.Length == 0 ? "" : " " + unidad;

        if (clase == "es-sin") return "Registra la primera medición.";

        if (clase == "es-critico" && v.ava_valor_critico != null)
            return "Límite crítico: " + v.ava_valor_critico.Value.ToString("0.##") + u;

        if (clase == "es-aviso" && v.ava_valor_advertencia != null)
            return "Aviso desde: " + v.ava_valor_advertencia.Value.ToString("0.##") + u;

        if (v.ava_valor_minimo != null && v.ava_valor_maximo != null)
            return (clase == "es-normal" ? "Rango: " : "Rango esperado: ") +
                   v.ava_valor_minimo.Value.ToString("0.##") + " – " +
                   v.ava_valor_maximo.Value.ToString("0.##") + u;

        if (v.ava_valor_minimo != null) return "Aviso bajo: " + v.ava_valor_minimo.Value.ToString("0.##") + u;
        if (v.ava_valor_advertencia != null) return "Aviso desde: " + v.ava_valor_advertencia.Value.ToString("0.##") + u;
        if (v.ava_valor_critico != null) return "Límite crítico: " + v.ava_valor_critico.Value.ToString("0.##") + u;

        return "Sin rangos configurados";
    }

    /// <summary>Cuando y de donde vino la lectura, en el largo de un pie de tarjeta.</summary>
    private string Cuando(DateTime? fecha, string origen)
    {
        if (fecha == null) return "Sin lecturas";

        DateTime hoy = global::SitioBase.Hora.Hoy;
        int dias = (int)(hoy.Date - fecha.Value.Date).TotalDays;

        string cuando = dias == 0 ? "Hoy, " + fecha.Value.ToString("HH:mm")
                      : dias == 1 ? "Ayer, " + fecha.Value.ToString("HH:mm")
                      : fecha.Value.ToString("dd MMM · HH:mm");

        return string.IsNullOrEmpty(origen) ? cuando : cuando + " · " + origen;
    }

    /// <summary>
    /// El icono de la variable se deduce de su nombre: la tabla de variables
    /// no guarda uno, y doce tarjetas con el mismo simbolo obligan a leer cada
    /// titulo para distinguirlas.
    /// </summary>
    private static string IconoVariable(string nombre)
    {
        string n = (nombre ?? "").ToLowerInvariant();

        if (n.Contains("vibra")) return "mdi-pulse";
        if (n.Contains("temperatura") || n.Contains("térmic") || n.Contains("termic")) return "mdi-thermometer";
        if (n.Contains("humedad") || n.Contains("aceite") || n.Contains("nivel")) return "mdi-water-outline";
        if (n.Contains("presión") || n.Contains("presion")) return "mdi-gauge";
        if (n.Contains("corriente") || n.Contains("tensión") || n.Contains("voltaje") || n.Contains("energ")) return "mdi-flash";
        if (n.Contains("caudal") || n.Contains("flujo")) return "mdi-waves";
        if (n.Contains("ruido") || n.Contains("sonor")) return "mdi-volume-high";
        if (n.Contains("velocidad") || n.Contains("rpm") || n.Contains("giro")) return "mdi-speedometer";
        if (n.Contains("hora") || n.Contains("tiempo")) return "mdi-clock-outline";

        return "mdi-chart-line";
    }

    /// <summary>Los rangos de la variable, en una linea que se lee de corrido.</summary>
    private string Rangos(ActivoVariable v)
    {
        List<string> partes = new List<string>();

        if (v.ava_valor_minimo != null || v.ava_valor_maximo != null)
            partes.Add("Normal " +
                       (v.ava_valor_minimo == null ? "" : v.ava_valor_minimo.Value.ToString("0.##")) + " – " +
                       (v.ava_valor_maximo == null ? "" : v.ava_valor_maximo.Value.ToString("0.##")));

        if (v.ava_valor_advertencia != null) partes.Add("Aviso " + v.ava_valor_advertencia.Value.ToString("0.##"));
        if (v.ava_valor_critico != null) partes.Add("Crítico " + v.ava_valor_critico.Value.ToString("0.##"));

        return partes.Count == 0 ? "Sin rangos configurados" : string.Join("  ·  ", partes.ToArray());
    }

    /// <summary>
    /// El nivel de un punto de la serie lo calcula el SP contra los umbrales
    /// de la variable; aca solo se le pone color.
    /// </summary>
    private static string ChipNivel(string nivel)
    {
        string n = (nivel ?? "").ToUpperInvariant();

        if (n.Contains("CRIT")) return "<span class=\"sg-ot-chip es-rojo\">Crítico</span>";
        if (n.Contains("ADVERT") || n.Contains("AVISO")) return "<span class=\"sg-ot-chip es-aviso\">Advertencia</span>";
        if (n.Contains("FUERA")) return "<span class=\"sg-ot-chip es-aviso\">Fuera de rango</span>";
        if (n.Length == 0) return "<span class=\"sg-ot-vacio-txt\">—</span>";

        return "<span class=\"sg-ot-chip es-ok\">Normal</span>";
    }

    private string UrlSerie(int variable)
    {
        return UrlRegistro("~/View/Activos/Variables/ActivoVariableSerie.aspx", variable);
    }

    /// <summary>
    /// Los contadores del equipo: no bajan, se acumulan.
    ///
    /// La tarjeta dice cuanto falta para el proximo mantenimiento por uso, que
    /// es lo unico que se hace con un contador: el numero suelto -84.250 kWh-
    /// no le dice nada a nadie si no esta al lado de "faltan 1.650".
    /// </summary>
    private void Medidores(Activo a, int variables)
    {
        List<ActivoMedidorResumen> medidores = new ActivoCentroController().GetResumenMedidores(a.act_id)
                                               ?? new List<ActivoMedidorResumen>();

        bool puedeMedidor = Token.Puede("CREAR EDITAR MEDIDORES");
        lnkNuevoMedidor.Visible = puedeMedidor;

        litCondMedidores.Text = litCondMedidores2.Text = medidores.Count.ToString();
        litCondTodas.Text = (variables + medidores.Count).ToString();

        if (medidores.Count == 0)
        {
            litMedidores.Text = "<div class=\"sg-ot-vacio es-chico\"><i class=\"mdi mdi-counter\"></i>" +
                                "<p>Sin contadores</p><span>" +
                                (puedeMedidor ? "Agregue uno con «Nuevo contador»: es lo que permite programar por uso y no solo por calendario."
                                              : "Este equipo no tiene contadores.") + "</span></div>";
            return;
        }

        StringBuilder m = new StringBuilder();

        foreach (ActivoMedidorResumen x in medidores)
        {
            string unidad = Texto(x.unidad);
            string u = unidad.Length == 0 ? "" : " " + unidad;
            string clase = x.fecha == null ? "es-sin" : "es-contador";
            string sub = string.IsNullOrEmpty(x.componente) ? "Equipo completo" : x.componente;

            string falta = x.falta == null
                ? (string.IsNullOrEmpty(x.plan_nombre) ? "Consumo acumulado" : "Sin objetivo pendiente")
                : "Faltan " + x.falta.Value.ToString("N0") + u + " para mantenimiento";

            string proximo = x.objetivo == null
                ? "Sin mantenimiento asociado"
                : "Próximo: " + x.objetivo.Value.ToString("N0") + u;

            m.Append("<a href=\"javascript:void(0)\" class=\"sg-cond-card es-medidor ").Append(clase)
             .Append("\" data-cond=\"medidor\" data-clase=\"").Append(clase == "es-sin" ? "es-sin" : "es-normal")
             .Append("\" data-id=\"m").Append(x.id)
             .Append("\" data-buscar=\"").Append(Server.HtmlEncode((Texto(x.nombre) + " " + Texto(x.codigo) + " " + sub + " " + unidad).ToLowerInvariant()))
             .Append("\" data-titulo=\"").Append(Server.HtmlEncode(Texto(x.nombre)))
             .Append("\" data-sub=\"").Append(Server.HtmlEncode(sub))
             .Append("\" data-rango=\"").Append(Server.HtmlEncode(proximo))
             .Append("\" data-frecuencia=\"")
             .Append(Server.HtmlEncode(string.IsNullOrEmpty(x.plan_nombre) ? "Sin plan por uso asociado" : "Plan: " + x.plan_nombre))
             .Append("\" data-query=\"").Append(Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + x.id)))
             .Append("\" data-lectura=\"")
             .Append(Server.UrlEncode(Tools.Crypto.Encrypt("Activo=" + a.act_id + "&Que=m" + x.id)))
             .Append("\" data-editar=\"").Append(puedeMedidor ? "1" : "0").Append("\">")

             .Append("<span class=\"sg-cond-card-top\">")
             .Append("<span class=\"sg-cond-ico\"><i class=\"mdi ").Append(IconoContador(x.nombre)).Append("\"></i></span>")
             .Append("<span class=\"sg-cond-card-id\"><strong>").Append(Server.HtmlEncode(Texto(x.nombre))).Append("</strong>")
             .Append("<span>").Append(Server.HtmlEncode(sub)).Append("</span></span>")
             .Append("</span>")

             .Append("<span class=\"sg-cond-card-val\"><b>").Append(x.valor.ToString("N0")).Append("</b>")
             .Append(unidad.Length == 0 ? "" : "<small>" + Server.HtmlEncode(unidad) + "</small>")
             .Append("</span>")

             .Append("<span class=\"sg-cond-card-ref\">").Append(Server.HtmlEncode(falta))
             .Append("<small>").Append(Server.HtmlEncode(proximo)).Append("</small></span>")

             .Append("<span class=\"sg-cond-card-pie\">")
             .Append("<span><i class=\"mdi mdi-clock-outline\"></i>").Append(Server.HtmlEncode(Cuando(x.fecha, x.origen))).Append("</span>")
             .Append("<em>Ver detalle <i class=\"mdi mdi-arrow-right\"></i></em>")
             .Append("</span></a>");
        }

        litMedidores.Text = m.ToString();
    }

    /// <summary>Igual que la variable: el icono sale del nombre del contador.</summary>
    private static string IconoContador(string nombre)
    {
        string n = (nombre ?? "").ToLowerInvariant();

        if (n.Contains("hora") || n.Contains("horómetro") || n.Contains("horometro")) return "mdi-clock-outline";
        if (n.Contains("ciclo") || n.Contains("producción") || n.Contains("produccion")) return "mdi-cog-outline";
        if (n.Contains("energ") || n.Contains("kwh") || n.Contains("consumo")) return "mdi-flash";
        if (n.Contains("arranque") || n.Contains("partida")) return "mdi-power";
        if (n.Contains("kilómetro") || n.Contains("kilometro") || n.Contains("km")) return "mdi-map-marker-distance";

        return "mdi-counter";
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
            clase = "es-sin";
            etiqueta = "Sin lectura";
            return;
        }

        int dias = (int)(hoy - r.ultima_fecha_utc.Value.Date).TotalDays;

        if (dias > 14)
        {
            clase = "es-aviso";
            etiqueta = "Revisar";
            return;
        }

        decimal valor = r.ultimo_valor.Value;

        /* Los umbrales son los de la variable del equipo: primero el critico y
           despues el de advertencia, porque un valor que pasa el critico
           tambien pasa el de aviso y la etiqueta tiene que decir lo peor. El
           rango normal -minimo y maximo- se mira al final. */
        if (v.ava_valor_critico != null && valor >= v.ava_valor_critico)
        {
            clase = "es-critico"; etiqueta = "Fuera de límite"; return;
        }

        if (v.ava_valor_advertencia != null && valor >= v.ava_valor_advertencia)
        {
            clase = "es-aviso"; etiqueta = "Revisar"; return;
        }

        if ((v.ava_valor_maximo != null && valor > v.ava_valor_maximo) ||
            (v.ava_valor_minimo != null && valor < v.ava_valor_minimo))
        {
            clase = "es-aviso"; etiqueta = "Revisar"; return;
        }

        clase = "es-normal";
        etiqueta = "En rango";
    }

    #endregion

    #region 9. Documentos y galeria

    /// <summary>
    /// Todo lo que hay del equipo en archivos: sus documentos, su foto y lo
    /// que el terreno fotografio en sus ordenes, inspecciones y tareas.
    ///
    /// ANTES SE VEIA VACIO Y NO LO ESTABA
    ///   La galeria pedia solo los documentos colgados de la ficha, que es lo
    ///   unico que devuelve SEL_ACTIVO_ARCHIVO -su imagen la deja fuera a
    ///   proposito-. Un equipo con su foto y veinte evidencias de terreno
    ///   mostraba "sin documentos ni fotografias".
    ///
    ///   Los archivos viven en Blob Storage: aca solo viaja el id, y la imagen
    ///   se pide por VerArchivo.aspx con ese id cifrado.
    /// </summary>
    /// <summary>
    /// Todo lo que hay del equipo en archivos: sus documentos, sus fotos y lo
    /// que el terreno adjuntó en sus ordenes, inspecciones y tareas.
    ///
    /// TRES VISTAS POR LO QUE SON, NO POR SU EXTENSION
    ///   Un manual y la foto de una correa rota son dos cosas distintas
    ///   aunque las dos sean archivos: el manual se busca una vez y se lee;
    ///   la foto es prueba de algo que paso un dia. Separarlas por "imagen" y
    ///   "documento" deja el manual escaneado junto a las evidencias.
    ///
    ///   Los archivos viven en Blob Storage: aca solo viaja el id, y la
    ///   imagen se pide por VerArchivo.aspx con ese id cifrado.
    /// </summary>
    private void Documentos(Activo a)
    {
        List<ActivoArchivoOrigen> archivos = new ActivoArchivoController().GetTodos(a.act_id, _cliente)
                                             ?? new List<ActivoArchivoOrigen>();

        int evidencias = archivos.Count(x => x.es_evidencia);
        int fotos = archivos.Count(x => x.es_imagen && !x.es_evidencia);
        int documentos = archivos.Count(x => !x.es_imagen && !x.es_evidencia);

        litEvTodas.Text = archivos.Count.ToString();
        litEvDocs.Text = documentos.ToString();
        litEvFotos.Text = fotos.ToString();
        litEvEvidencias.Text = evidencias.ToString();

        pnlSinArchivos.Visible = archivos.Count == 0;

        litDocConteos.Text =
            "<div class=\"sg-ot-card-acc sg-ot-avance\">" +
            "<div class=\"sg-ot-avance-num\"><strong>" + archivos.Count + "</strong><span>archivos</span></div>" +
            "<div class=\"sg-ot-avance-num\"><strong>" + evidencias + "</strong><span>de terreno</span></div></div>";

        if (archivos.Count == 0)
        {
            litArchivos.Text = "";
            litDocTabla.Text = "";
            return;
        }

        StringBuilder s = new StringBuilder();
        StringBuilder tabla = new StringBuilder();

        tabla.Append("<div class=\"sg-a3-tabla-cab sg-doc-cab\">")
             .Append("<span>Nombre</span><span>Tipo</span><span>Origen</span>")
             .Append("<span>Fecha</span><span>Quién</span><span>Tamaño</span><span></span></div>");

        foreach (ActivoArchivoOrigen f in archivos)
        {
            string clase = f.es_evidencia ? "evidencia" : (f.es_imagen ? "fotografia" : "documento");
            string url = UrlArchivo.Ver(f.arc_id);
            string buscar = (Texto(f.nombre) + " " + Texto(f.origen_etiqueta) + " " + Texto(f.usuario)).ToLower();

            // ---- la tarjeta de la galeria ----
            s.Append("<article class=\"sg-ot-ev-card\" data-tipo=\"").Append(f.es_imagen ? "imagen" : "documento")
             .Append("\" data-doc-clase=\"").Append(clase)
             .Append("\" data-paso=\"").Append(Server.HtmlEncode(Texto(f.origen_etiqueta)))
             .Append("\" data-paso-txt=\"").Append(Server.HtmlEncode(Texto(f.origen_etiqueta)))
             .Append("\" data-paso-etq=\"Origen\"")
             .Append(" data-buscar=\"").Append(Server.HtmlEncode(buscar))
             .Append("\" data-url=\"").Append(url)
             .Append("\" data-titulo=\"").Append(Server.HtmlEncode(f.etiqueta))
             .Append("\" data-usuario=\"").Append(Server.HtmlEncode(Texto(f.usuario)))
             .Append("\" data-fecha=\"").Append(f.fecha == null ? "" : f.fecha.Value.ToString("dd MMM yyyy · HH:mm"))
             .Append("\" data-obs=\"").Append(Server.HtmlEncode(Texto(f.descripcion)))
             .Append("\" data-orden=\"").Append(f.orden_id == null ? "" : UrlOrden(f.orden_id.Value))
             .Append("\" data-icono=\"").Append(f.es_imagen ? "mdi-image-outline" : "mdi-file-document-outline")
             .Append("\" data-imagen=\"").Append(f.es_imagen ? "1" : "0").Append("\">");

            s.Append("<span class=\"sg-ot-ev-foto\">");
            if (f.es_imagen)
                s.Append("<img src=\"").Append(url).Append("\" alt=\"").Append(Server.HtmlEncode(f.etiqueta)).Append("\" />");
            else
                s.Append("<i class=\"mdi mdi-file-document-outline sg-ot-ev-icono\"></i>");

            /* La etiqueta de donde vino va sobre la miniatura: en una grilla
               de doce fotos, leer doce pies para encontrar la de la OT es
               justo lo que se quiere evitar. */
            s.Append("<span class=\"sg-doc-badge es-").Append(clase).Append("\">")
             .Append(clase == "evidencia" ? "Terreno" : (clase == "fotografia" ? "Foto" : "Documento"))
             .Append("</span>");

            s.Append("</span>");

            s.Append("<div class=\"sg-ot-ev-txt\"><span class=\"sg-ot-ev-nom\">")
             .Append(Server.HtmlEncode(f.etiqueta)).Append("</span>")
             .Append("<span class=\"sg-ot-ev-meta\">")
             .Append(Server.HtmlEncode(Texto(f.origen_etiqueta)))
             .Append(f.bytes > 0 ? " · " + Tamano(f.bytes) : "")
             .Append("</span></div></article>");

            // ---- su fila en la tabla ----
            tabla.Append("<div class=\"sg-a3-tabla-fila sg-doc-fila\" data-doc-clase=\"").Append(clase)
                 .Append("\" data-doc-txt=\"").Append(Server.HtmlEncode(buscar))
                 .Append("\" data-doc-origen=\"").Append(Server.HtmlEncode(Texto(f.origen_etiqueta))).Append("\">")

                 .Append("<span class=\"c-cod\">").Append(Server.HtmlEncode(f.etiqueta))
                 .Append("<span>").Append(Server.HtmlEncode(Texto(f.descripcion))).Append("</span></span>")

                 .Append("<span class=\"c-dato\"><span class=\"sg-ot-chip ")
                 .Append(clase == "evidencia" ? "es-info" : (clase == "fotografia" ? "es-tarea" : "es-neutro"))
                 .Append("\">")
                 .Append(clase == "evidencia" ? "Evidencia" : (clase == "fotografia" ? "Fotografía" : "Documento"))
                 .Append("</span></span>")

                 .Append("<span class=\"c-dato\">").Append(Server.HtmlEncode(Texto(f.origen_etiqueta))).Append("</span>")
                 .Append("<span class=\"c-dato\">")
                 .Append(f.fecha == null ? "—" : f.fecha.Value.ToString("dd MMM yyyy")).Append("</span>")
                 .Append("<span class=\"c-dato\">").Append(Server.HtmlEncode(Texto(f.usuario))).Append("</span>")
                 .Append("<span class=\"c-dato\">").Append(f.bytes > 0 ? Tamano(f.bytes) : "—").Append("</span>")

                 .Append("<span class=\"c-acc\">")
                 .Append("<a class=\"sg-ot-btn es-accion\" href=\"").Append(url)
                 .Append("\" target=\"_blank\" rel=\"noopener\">Ver<i class=\"mdi mdi-open-in-new\"></i></a>")
                 .Append("</span>")
                 .Append("</div>");
        }

        litArchivos.Text = s.ToString();
        litDocTabla.Text = tabla.ToString();
    }

    private static string Tamano(long bytes)
    {
        if (bytes <= 0) return "";
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return (bytes / 1024) + " KB";
        return (bytes / (1024 * 1024)) + " MB";
    }

    #endregion


    #region 10. Inspecciones y tareas

    /// <summary>
    /// Todo lo que se paso a revisar en el equipo: pautas de inspeccion y
    /// tareas, en una sola lista.
    ///
    /// SON DOS COSAS DISTINTAS Y LA PANTALLA LAS SEPARA
    ///   El ESTADO dice el avance -pendiente, en ejecucion, completada- y el
    ///   RESULTADO dice la evaluacion del tecnico. Mezclarlos deja pasar el
    ///   caso que mas importa: la inspeccion que se hizo completa y encontro
    ///   algo. Completada no significa conforme.
    /// </summary>
    private void InspeccionesYTareas(Activo a)
    {
        List<ActivoRevision> revisiones = new ActivoCentroController().GetRevisiones(a.act_id)
                                          ?? new List<ActivoRevision>();

        int inspecciones = revisiones.Count(x => x.es_inspeccion);
        int hallazgos = revisiones.Count(x => x.resultado_codigo == "CON_OBSERVACION");

        litRevTodas.Text = revisiones.Count.ToString();
        litRevInsp.Text = inspecciones.ToString();
        litRevTareas.Text = (revisiones.Count - inspecciones).ToString();

        litRevConteos.Text =
            "<div class=\"sg-ot-card-acc sg-ot-avance\">" +
            "<div class=\"sg-ot-avance-num\"><strong>" + revisiones.Count + "</strong><span>registros</span></div>" +
            "<div class=\"sg-ot-avance-num\"><strong>" + revisiones.Count(x => x.ejecutada) + "</strong><span>ejecutadas</span></div>" +
            "<div class=\"sg-ot-avance-num\"><strong>" + hallazgos + "</strong><span>con observación</span></div></div>";

        if (revisiones.Count == 0)
        {
            litRevisiones.Text = "<div class=\"sg-ot-vacio\"><i class=\"mdi mdi-clipboard-check-outline\"></i>" +
                                 "<p>Sin inspecciones ni tareas</p>" +
                                 "<span>Se programan desde Pautas de inspección y desde Tareas recurrentes.</span></div>";
            return;
        }

        ChecklistCentroController checklists = new ChecklistCentroController();

        StringBuilder s = new StringBuilder();

        s.Append("<div class=\"sg-a3-tabla-cab sg-a3-rev-cab\">")
         .Append("<span>Inspección / Tarea</span><span>Tipo</span><span>Fecha</span>")
         .Append("<span>Resultado técnico</span><span>Estado</span><span>Responsable</span><span></span></div>");

        foreach (ActivoRevision r in revisiones)
        {
            string clave = r.tipo.ToLower() + "-" + r.ocurrencia_id;

            s.Append("<div class=\"sg-a3-tabla-fila sg-a3-rev\" data-rev=\"").Append(clave)
             .Append("\" data-rev-tipo=\"").Append(r.tipo)
             .Append("\" data-rev-res=\"").Append(r.resultado_codigo)
             .Append("\" data-rev-txt=\"").Append(Server.HtmlEncode((Texto(r.nombre) + " " + Texto(r.codigo) + " " + Texto(r.responsable)).ToLower()))
             .Append("\">")

             .Append("<span class=\"c-cod\">").Append(Server.HtmlEncode(Texto(r.nombre)))
             .Append("<span>").Append(Server.HtmlEncode(Texto(r.descripcion))).Append("</span></span>")

             .Append("<span class=\"c-dato\"><span class=\"sg-ot-chip ")
             .Append(r.es_inspeccion ? "es-tipo" : "es-tarea").Append("\">")
             .Append(r.es_inspeccion ? "Inspección" : "Tarea").Append("</span></span>")

             .Append("<span class=\"c-dato\">")
             .Append(r.fecha == null ? "—" : r.fecha.Value.ToString("dd MMM yyyy"))
             .Append("</span>")

             .Append("<span class=\"c-dato\">").Append(ChipResultado(r)).Append("</span>")

             .Append("<span class=\"c-dato\"><span class=\"sg-ot-chip es-estado\">")
             .Append(Server.HtmlEncode(string.IsNullOrEmpty(r.estado_nombre) ? "Sin estado" : r.estado_nombre))
             .Append("</span></span>")

             .Append("<span class=\"c-dato\">")
             .Append(Server.HtmlEncode(string.IsNullOrEmpty(r.responsable) ? "Sin asignar" : r.responsable))
             .Append("</span>")

             .Append("<span class=\"c-acc\"><i class=\"mdi mdi-chevron-down sg-a3-rev-flecha\"></i></span>")
             .Append("</div>");

            // ---- el detalle que se despliega ----
            s.Append("<div class=\"sg-a3-ot-detalle sg-a3-rev-detalle\" id=\"rev-").Append(clave).Append("\">");

            if (!r.ejecutada)
            {
                s.Append(DetItem("mdi-calendar-clock", "Programada para",
                         r.programada == null ? "" : r.programada.Value.ToString("dd MMM yyyy · HH:mm")));
                s.Append(DetItem("mdi-information-outline", "Todavía sin ejecutar",
                         "No hay resultado que mostrar hasta que alguien la pase en terreno."));
            }
            else
            {
                /* Los items respondidos se piden solo para lo ejecutado: una
                   ocurrencia pendiente no tiene respuestas que leer. */
                if (r.es_inspeccion && r.ejecucion_id != null)
                    s.Append(Respuestas(checklists.GetRespuestas(r.ejecucion_id.Value)));

                s.Append(DetItem("mdi-comment-text-outline", "Observaciones",
                         string.IsNullOrEmpty(r.observacion) ? "Sin observaciones." : r.observacion));

                s.Append(DetItem("mdi-image-multiple-outline", "Evidencias",
                         r.evidencias == 0 ? "Sin archivos"
                         : r.evidencias + (r.evidencias == 1 ? " archivo adjunto" : " archivos adjuntos")));

                s.Append(DetItem("mdi-cellphone-link", "Fuente del registro",
                         string.IsNullOrEmpty(r.origen) ? "" : r.origen));
            }

            s.Append("</div>");
        }

        litRevisiones.Text = s.ToString();
    }

    /// <summary>
    /// Los items de la pauta con lo que quedo respondido. Un item sin
    /// responder tambien se muestra: omitirlo haria ver completa una ronda
    /// que no lo esta.
    /// </summary>
    private string Respuestas(List<ChecklistRespuesta> items)
    {
        if (items == null || items.Count == 0)
            return DetItem("mdi-format-list-checks", "Resultados de la inspección", "Sin items respondidos.");

        StringBuilder s = new StringBuilder("<div class=\"sg-a3-ot-det-item es-ancho\">");
        s.Append("<strong><i class=\"mdi mdi-format-list-checks\"></i>Resultados de la inspección</strong>");
        s.Append("<div class=\"sg-a3-items\">");

        foreach (ChecklistRespuesta i in items.Take(12))
        {
            string clase = !i.respondido ? "es-pendiente" : (i.fuera_rango ? "es-malo" : "es-bueno");
            string icono = !i.respondido ? "mdi-circle-outline"
                         : (i.fuera_rango ? "mdi-alert-circle-outline" : "mdi-check-circle");

            s.Append("<div class=\"sg-a3-item ").Append(clase).Append("\">")
             .Append("<i class=\"mdi ").Append(icono).Append("\"></i>")
             .Append("<span class=\"sg-a3-item-txt\">").Append(Server.HtmlEncode(Texto(i.texto))).Append("</span>")
             .Append("<span class=\"sg-a3-item-val\">")
             .Append(Server.HtmlEncode(!i.respondido ? "Sin responder"
                     : (i.no_aplica ? "No aplica" : (string.IsNullOrEmpty(i.valor) ? "Respondido" : i.valor))))
             .Append("</span></div>");
        }

        if (items.Count > 12)
            s.Append("<p class=\"sg-ot-vacio-txt\">Y ").Append(items.Count - 12)
             .Append(" items más en la pauta completa.</p>");

        return s.Append("</div></div>").ToString();
    }

    private string ChipResultado(ActivoRevision r)
    {
        string clase = r.resultado_codigo == "CONFORME" ? "es-ok"
                     : (r.resultado_codigo == "CON_OBSERVACION" ? "es-aviso" : "es-neutro");

        string icono = r.resultado_codigo == "CONFORME" ? "mdi-check"
                     : (r.resultado_codigo == "CON_OBSERVACION" ? "mdi-alert-circle-outline" : "mdi-minus-circle-outline");

        return "<span class=\"sg-ot-chip " + clase + "\"><i class=\"mdi " + icono + "\"></i>" +
               Server.HtmlEncode(r.resultado_nombre) + "</span>";
    }

    #endregion

    #region 11. Repuestos y costos

    /// <summary>
    /// Que se le cambio al equipo y cuanto costo.
    ///
    /// LO QUE SE MUESTRA ES LO REGISTRADO, NO LO QUE COSTO
    ///   Si nadie cargo el costo hora del tecnico, la mano de obra sale en
    ///   cero. Un total con ceros adentro invita a concluir que mantener este
    ///   equipo salio barato, que es exactamente la decision que no se quiere
    ///   inducir. Por eso, mientras falte algo, la pantalla lo dice.
    /// </summary>
    private void RepuestosYCostos(Activo a)
    {
        ActivoCentroController ctl = new ActivoCentroController();

        ActivoCosto costo = ctl.GetCostos(a.act_id);
        List<ActivoConsumo> consumos = ctl.GetConsumos(a.act_id) ?? new List<ActivoConsumo>();

        StringBuilder k = new StringBuilder("<div class=\"sg-a3-kpis\">");

        /* Cero pesos con lineas cargadas no es "salio gratis": es un precio que
           nadie puso. Se dice con palabras para no invitar a sumarlo. */
        k.Append(Kpi("mdi-package-variant-closed",
                 costo.lineas_material == 0 ? "Sin consumo"
                 : (costo.material <= 0 ? "Sin costo cargado" : Moneda(costo.material)), "Materiales registrados",
                 costo.lineas_material + (costo.lineas_material == 1 ? " línea" : " líneas"), "es-teal"));

        k.Append(Kpi("mdi-wrench-outline",
                 costo.minutos_mano_obra == 0 ? "Sin registrar"
                 : (costo.mano_obra <= 0 ? "Sin costo cargado" : Moneda(costo.mano_obra)), "Mano de obra",
                 costo.minutos_mano_obra == 0 ? "Nadie cargó horas" : Duracion(costo.minutos_mano_obra) + " cargadas", "es-azul"));

        k.Append(Kpi("mdi-handshake-outline",
                 costo.lineas_servicio == 0 ? "Sin registrar" : Moneda(costo.servicio), "Servicios externos",
                 costo.lineas_servicio + (costo.lineas_servicio == 1 ? " línea" : " líneas"), "es-ambar"));

        k.Append(Kpi("mdi-calculator-variant-outline", Moneda(costo.total), "Total conocido",
                 costo.ordenes + (costo.ordenes == 1 ? " orden" : " órdenes"), "es-verde"));

        k.Append("</div>");

        if (costo.incompleto)
            k.Append("<div class=\"sg-ot-nota es-aviso\"><i class=\"mdi mdi-information-outline\"></i>")
             .Append("<span>El total no incluye lo que todavía no tiene precio cargado. ")
             .Append("Es un piso, no el costo del equipo.</span></div>");

        litCostoKpis.Text = k.ToString();

        // ---- consumos ----
        litConsumoConteos.Text =
            "<div class=\"sg-ot-card-acc sg-ot-avance\">" +
            "<div class=\"sg-ot-avance-num\"><strong>" + consumos.Count + "</strong><span>consumos</span></div></div>";

        if (consumos.Count == 0)
        {
            litConsumos.Text = "<div class=\"sg-ot-vacio es-chico\"><i class=\"mdi mdi-package-variant\"></i>" +
                               "<p>Sin consumo de repuestos</p>" +
                               "<span>Nada salió de bodega para este equipo todavía.</span></div>";
        }
        else
        {
            StringBuilder s = new StringBuilder();

            s.Append("<div class=\"sg-a3-tabla-cab sg-a3-rep-cab\">")
             .Append("<span>Material / Repuesto</span><span>Código</span><span>Consumo</span>")
             .Append("<span>Costo unitario</span><span>Costo total</span><span>Fecha</span>")
             .Append("<span>Orden</span><span></span></div>");

            foreach (ActivoConsumo c in consumos)
            {
                s.Append("<div class=\"sg-a3-tabla-fila sg-a3-rep\">")
                 .Append("<span class=\"c-cod\">").Append(Server.HtmlEncode(Texto(c.repuesto_nombre)))
                 .Append("<span>").Append(Server.HtmlEncode(string.IsNullOrEmpty(c.componente) ? Texto(c.orden_titulo) : c.componente))
                 .Append("</span></span>")
                 .Append("<span class=\"c-dato\"><span class=\"sg-a3-codigo\">").Append(Server.HtmlEncode(Texto(c.repuesto_codigo))).Append("</span></span>")
                 .Append("<span class=\"c-dato\">").Append(Server.HtmlEncode(Cantidad(c.cantidad, c.unidad))).Append("</span>")
                 .Append("<span class=\"c-dato\">").Append(c.costo_registrado ? Moneda(c.costo_unitario) : "Sin cargar").Append("</span>")
                 .Append("<span class=\"c-dato\">").Append(c.costo_registrado ? Moneda(c.costo) : "—").Append("</span>")
                 .Append("<span class=\"c-dato\">").Append(c.fecha == null ? "—" : c.fecha.Value.ToString("dd MMM yyyy")).Append("</span>")
                 .Append("<span class=\"c-dato\"><span class=\"sg-a3-codigo\">").Append(c.orden_codigo).Append("</span></span>")
                 .Append("<span class=\"c-acc\">").Append(Boton(UrlOrden(c.orden_id), "Abrir OT")).Append("</span>")
                 .Append("</div>");
            }

            litConsumos.Text = s.ToString();
        }

        // ---- compatibles ----
        List<ActivoRepuesto> compatibles = new ActivoRepuestoController().GetRepuestos(a.act_id, _cliente)
                                           ?? new List<ActivoRepuesto>();

        if (compatibles.Count == 0)
        {
            litCompatibles.Text = "<p class=\"sg-ot-vacio-txt\">No hay repuestos declarados como compatibles con este equipo.</p>";
            return;
        }

        StringBuilder m = new StringBuilder();

        foreach (ActivoRepuesto r in compatibles)
            m.Append(Fila("mdi-shape-outline", "",
                     Texto(r.rep_nombre),
                     string.Join(" · ", new[] { Texto(r.rep_fabricante), Texto(r.rep_modelo) }
                                 .Where(x => !string.IsNullOrEmpty(x)).ToArray()),
                     "<span class=\"sg-a3-codigo\">" + Server.HtmlEncode(Texto(r.rep_codigo)) + "</span>"));

        litCompatibles.Text = m.ToString();
    }

    private static string Moneda(decimal valor)
    {
        return "$" + valor.ToString("N0") + " CLP";
    }

    #endregion

    #region 12. SIGMA AI

    /// <summary>
    /// Lo que el modelo vio en este equipo.
    ///
    /// NO AFIRMA UNA FALLA
    ///   Una prediccion es un patron que alguien tiene que ir a mirar. Se
    ///   muestra lo que la alerta dejo escrito y nada mas: sin porcentaje de
    ///   confianza inventado, sin diagnostico y sin crear ordenes solo. El
    ///   boton propone crear la OT; la crea una persona.
    /// </summary>
    private void SigmaAi(Activo a, List<OrdenTrabajo> ordenes, List<Falla> fallas)
    {
        List<Alerta> alertas = new AlertaController().GetAlertas(false, 200) ?? new List<Alerta>();

        List<Alerta> predicciones = alertas
            .Where(x => x.ES_PREDICCION && x.ale_activo == a.act_id)
            .OrderByDescending(x => x.ale_fecha_deteccion_utc)
            .ToList();

        StringBuilder s = new StringBuilder("<div class=\"sg-ot-card sg-a3-ia-card\">");

        Alerta p = predicciones.FirstOrDefault();

        s.Append("<header class=\"sg-a3-ia-head\">")
         .Append("<span class=\"sg-a3-ia-ico\"><i class=\"mdi mdi-star-four-points-outline\"></i></span>")
         .Append("<div><h3>SIGMA AI<span> · ").Append(p == null ? "Sin análisis" : "Predicción por revisar").Append("</span></h3>")
         .Append("<p class=\"sg-ot-card-sub\">Lo que el modelo observó en este equipo, para que una persona lo revise.</p></div>");

        if (p != null)
            s.Append("<span class=\"sg-a3-ia-fecha\">Último análisis: ")
             .Append(p.ale_fecha_deteccion_utc.ToString("dd MMM yyyy · HH:mm")).Append("</span>");

        s.Append("</header>");

        if (p == null)
        {
            s.Append("<div class=\"sg-ot-vacio\"><i class=\"mdi mdi-robot-outline\"></i>")
             .Append("<p>Sin análisis predictivo para este equipo</p>")
             .Append("<span>El modelo todavía no encontró un patrón que valga la pena mirar acá.</span></div>")
             .Append("</div>");

            litIaPanel.Text = s.ToString();
            return;
        }

        s.Append("<div class=\"sg-a3-ia-cols\">");

        // ---- el aviso ----
        s.Append("<div class=\"sg-a3-ia-aviso\">")
         .Append("<i class=\"mdi mdi-alert-outline\"></i>")
         .Append("<div><strong>").Append(Server.HtmlEncode(Texto(p.ale_titulo))).Append("</strong>")
         .Append("<span class=\"sg-a3-ia-tipo\">").Append(Server.HtmlEncode(Texto(p.alt_nombre))).Append("</span>")
         .Append("<p>").Append(Server.HtmlEncode(Texto(p.ale_descripcion))).Append("</p>")
         .Append("<p class=\"sg-a3-ia-limite\">El modelo detecta un patrón. <strong>No confirma una falla.</strong></p>")
         .Append("</div></div>");

        // ---- las senales que alimentan el modelo ----
        s.Append("<div class=\"sg-a3-ia-senal\"><h4>Estado de señales de entrada</h4><div class=\"sg-a3-senales\">");

        List<ActivoVariable> variables = new ActivoVariableController().GetVariables(
            new ActivoVariable { ava_cliente = _cliente, filtro_activo = a.act_id, filtro_habilitado = true })
            ?? new List<ActivoVariable>();

        if (variables.Count == 0)
            s.Append("<p class=\"sg-ot-vacio-txt\">Este equipo no tiene variables de condición configuradas.</p>");
        else
        {
            DateTime hoy = global::SitioBase.Hora.Hoy;
            ActivoVariableController ctlVar = new ActivoVariableController();

            foreach (ActivoVariable v in variables.Take(4))
            {
                MedicionSerieResumen r = ctlVar.GetSerieResumen(v.ava_id, hoy.AddDays(-30), null);
                bool hay = r != null && r.ultimo_valor != null;

                s.Append("<div class=\"sg-a3-senal ").Append(hay ? "es-ok" : "es-sin").Append("\">")
                 .Append("<i class=\"mdi mdi-pulse\"></i>")
                 .Append("<div><span>").Append(Server.HtmlEncode(Texto(v.variable_nombre))).Append("</span>")
                 .Append("<b>").Append(hay ? "Disponible" : "Sin datos").Append("</b></div></div>");
            }
        }

        s.Append("</div></div></div>");

        // ---- recomendacion y acciones ----
        s.Append("<div class=\"sg-a3-ia-cols es-abajo\">");

        s.Append("<div class=\"sg-a3-ia-reco\"><h4><i class=\"mdi mdi-wrench-outline\"></i>Recomendación</h4>")
         .Append("<p>Revisar el equipo y validar las lecturas antes de intervenir.</p>");

        /* La alerta no guarda una recomendacion escrita: guarda el numero que
           disparo el aviso. Se muestra ese, que es lo unico comprobable. */
        if (p.ale_valor_observado != null)
            s.Append("<p class=\"sg-a3-ia-dato\">Valor observado <strong>")
             .Append(p.ale_valor_observado.Value.ToString("0.##")).Append("</strong>")
             .Append(p.ale_valor_umbral == null ? "" : " · umbral " + p.ale_valor_umbral.Value.ToString("0.##"))
             .Append("</p>");

        s
         .Append("<div class=\"sg-ot-nota es-chica\"><i class=\"mdi mdi-information-outline\"></i>")
         .Append("<span>Revisión humana requerida antes de cualquier acción.</span></div></div>");

        s.Append("<div class=\"sg-a3-ia-acc\"><h4>Acciones sugeridas</h4>")
         .Append(BotonSeccion("condicion", "Ver señales del equipo"))
         .Append(Boton(ResolveUrl("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx"), "Crear OT predictiva", true))
         .Append("<p class=\"sg-a3-ia-limite\">Revise si ya existe una orden abierta antes de crear otra.</p></div>");

        s.Append("</div>");

        // ---- con que se relaciona ----
        s.Append("<div class=\"sg-a3-ia-rel\">");

        s.Append("<div><h4><i class=\"mdi mdi-clipboard-text-outline\"></i>Órdenes abiertas del equipo</h4>");
        List<OrdenTrabajo> abiertas = ordenes.Where(o => o.otr_orden_trabajo_estado != 4).Take(4).ToList();

        if (abiertas.Count == 0)
            s.Append("<p class=\"sg-ot-vacio-txt\">Sin órdenes abiertas.</p>");
        else
            foreach (OrdenTrabajo o in abiertas)
                s.Append(Fila("mdi-clipboard-text-outline", "", "OT-" + o.otr_correlativo + " · " + Texto(o.otr_titulo),
                         Texto(o.tipo_nombre), Boton(UrlOrden(o.otr_id), "Abrir OT")));

        s.Append("</div>");

        s.Append("<div><h4><i class=\"mdi mdi-alert-outline\"></i>Fallas registradas</h4>");
        List<Falla> abiertasFalla = fallas.Take(4).ToList();

        if (abiertasFalla.Count == 0)
            s.Append("<p class=\"sg-ot-vacio-txt\">Sin fallas registradas.</p>");
        else
            foreach (Falla f in abiertasFalla)
                s.Append(Fila("mdi-alert-outline", "es-rojo", Texto(f.fal_titulo),
                         f.fal_fecha_deteccion_utc == null ? "" : f.fal_fecha_deteccion_utc.Value.ToString("dd MMM yyyy"),
                         ""));

        s.Append("</div></div>");

        s.Append("<div class=\"sg-ot-nota es-chica\"><i class=\"mdi mdi-information-outline\"></i>")
         .Append("<span>La predicción es un apoyo al análisis. Requiere revisión humana y validación en terreno.</span></div>");

        s.Append("</div>");

        litIaPanel.Text = s.ToString();
    }

    #endregion

    #region 13. Bitacora y trazabilidad

    /// <summary>
    /// Lo que la gente anoto del equipo y cada cambio de estado que tuvo.
    ///
    /// LA BITACORA NO SE EDITA
    ///   Una correccion entra como un registro nuevo. La trazabilidad se
    ///   pierde el dia que alguien puede arreglar lo que escribio ayer, asi
    ///   que esta pantalla solo agrega.
    /// </summary>
    private void BitacoraYTrazabilidad(Activo a, List<ActivoFichaEvento> eventos)
    {
        List<ActivoBitacora> registros = new ActivoCentroController().GetBitacora(a.act_id)
                                         ?? new List<ActivoBitacora>();

        litBitConteos.Text =
            "<div class=\"sg-ot-card-acc sg-ot-avance\">" +
            "<div class=\"sg-ot-avance-num\"><strong>" + registros.Count + "</strong><span>registros</span></div>" +
            "<div class=\"sg-ot-avance-num\"><strong>" + registros.Count(x => x.requiere_atencion) + "</strong><span>por atender</span></div></div>";

        if (registros.Count == 0)
            litBitacora.Text = "<div class=\"sg-ot-vacio es-chico\"><i class=\"mdi mdi-notebook-outline\"></i>" +
                               "<p>Sin registros de bitácora</p>" +
                               "<span>Las observaciones llegan desde la app o se escriben acá abajo.</span></div>";
        else
        {
            StringBuilder s = new StringBuilder("<ul class=\"sg-a3-linea\">");

            foreach (ActivoBitacora b in registros)
            {
                s.Append("<li class=\"").Append(b.requiere_atencion ? "es-aviso" : "").Append("\">")
                 .Append("<span class=\"sg-a3-linea-ico\"><i class=\"mdi ")
                 .Append(b.tipo_icono.StartsWith("mdi-") ? b.tipo_icono : "mdi-note-text-outline").Append("\"></i></span>")
                 .Append("<div class=\"sg-a3-linea-txt\">")
                 .Append("<span class=\"sg-a3-linea-tit\">").Append(Server.HtmlEncode(b.etiqueta))
                 .Append("<span class=\"sg-ot-chip es-tipo\">").Append(Server.HtmlEncode(Texto(b.tipo_nombre))).Append("</span>");

                if (b.requiere_atencion)
                    s.Append("<span class=\"sg-ot-chip es-aviso\">Requiere atención</span>");

                s.Append("</span>")
                 .Append("<span class=\"sg-a3-linea-sub\">").Append(Server.HtmlEncode(Texto(b.texto))).Append("</span>")
                 .Append("<span class=\"sg-a3-linea-pie\">")
                 .Append(b.fecha == null ? "Sin fecha" : b.fecha.Value.ToString("dd MMM yyyy · HH:mm"))
                 .Append(" · ").Append(Server.HtmlEncode(string.IsNullOrEmpty(b.usuario) ? "Sin usuario" : b.usuario))
                 .Append(" · ").Append(Server.HtmlEncode(Texto(b.origen)));

                if (!string.IsNullOrEmpty(b.componente))
                    s.Append(" · ").Append(Server.HtmlEncode(b.componente));

                if (b.orden_id != null && b.orden_correlativo > 0)
                    s.Append(" · OT-").Append(b.orden_correlativo);

                /* Se escribio sin conexion y llego despues: la fecha del
                   evento y la de llegada no son la misma, y eso es justo lo
                   que se revisa cuando algo no cuadra. */
                if (b.llego_tarde)
                    s.Append(" · <em>sincronizado el ")
                     .Append(b.sincronizacion.Value.ToString("dd MMM yyyy · HH:mm")).Append("</em>");

                s.Append("</span></div></li>");
            }

            litBitacora.Text = s.Append("</ul>").ToString();
        }

        // ---- trazabilidad: los cambios de estado del equipo ----
        List<ActivoFichaEvento> cambios = eventos
            .Where(x => (x.tipo_evento ?? "").ToUpperInvariant() == "ESTADO")
            .Take(15)
            .ToList();

        if (cambios.Count == 0)
        {
            litTrazabilidad.Text = "<p class=\"sg-ot-vacio-txt\">Este equipo no registra cambios de estado.</p>";
            return;
        }

        StringBuilder tz = new StringBuilder();

        foreach (ActivoFichaEvento c in cambios)
            tz.Append(Fila("mdi-swap-horizontal", "",
                     Texto(c.titulo),
                     (c.fecha == null ? "Sin fecha" : c.fecha.Value.ToString("dd MMM yyyy · HH:mm")) +
                     (string.IsNullOrEmpty(c.usuario_nombre) ? "" : " · " + c.usuario_nombre),
                     ""));

        litTrazabilidad.Text = tz.ToString();
    }

    /// <summary>
    /// Publica la observacion escrita en la pantalla. Es el unico punto de
    /// esta ficha que escribe, y escribe por el mismo camino que la app.
    /// </summary>
    protected void lnkPublicar_Click(object sender, EventArgs e)
    {
        hdnSeccion.Value = "bitacora";

        int id = ActivoSeleccionado();
        if (id == 0) return;

        Activo a = new ActivoController().GetActivo(id);
        if (a == null || a.act_id == 0 || a.act_cliente != _cliente) return;

        Respuesta r = new ActivoCentroController().AgregarObservacion(
            a.act_id, a.act_cliente_instalacion, a.act_instalacion_area, txtObservacion.Text);

        litObsAviso.Text = "<div class=\"sg-ot-nota " + (r.error ? "es-aviso" : "es-ok") + "\">" +
                           "<i class=\"mdi " + (r.error ? "mdi-alert-outline" : "mdi-check-circle-outline") + "\"></i>" +
                           "<span>" + Server.HtmlEncode(r.detalle) + "</span></div>";

        if (!r.error) txtObservacion.Text = "";
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

    /// <summary>
    /// Un boton que lleva a OTRO registro. Abre en una pestaña nueva: el
    /// centro es donde se estaba mirando el equipo, y volver con el boton
    /// atras pierde la seccion, los filtros y la fila desplegada.
    /// </summary>
    private string Boton(string url, string texto, bool primario = false)
    {
        return "<a class=\"sg-ot-btn " + (primario ? "es-primario" : "es-plano") +
               "\" href=\"" + url + "\" target=\"_blank\" rel=\"noopener\">" +
               Server.HtmlEncode(texto) + "<i class=\"mdi mdi-open-in-new\"></i></a>";
    }

    /// <summary>El id nunca viaja en claro: va cifrado como en todo el sitio.</summary>
    private string UrlRegistro(string pagina, int id)
    {
        return ResolveUrl(pagina) + "?query=" + Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));
    }

    private string UrlFalla(int id) { return UrlRegistro("~/View/Mantenimiento/Fallas/Falla.aspx", id); }
    private string UrlPlan(int id) { return UrlRegistro("~/View/Mantenimiento/Planes/PlanMantenimiento.aspx", id); }
    private string UrlTarea(int id) { return UrlRegistro("~/View/Mantenimiento/Tareas/Tarea.aspx", id); }

    private string BotonSeccion(string seccion, string texto)
    {
        return "<a class=\"sg-ot-btn es-plano\" href=\"#\" data-ir-sec=\"" + seccion + "\">" +
               Server.HtmlEncode(texto) + "</a>";
    }

    private string UrlOrden(int id)
    {
        return UrlRegistro("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx", id);
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
    /// <summary>
    /// Baja la lista de activos tal como se esta viendo.
    ///
    /// POR QUE NO REUSA EL EXPORTAR DE LA FICHA
    ///   Aquel baja el HISTORIAL de UN equipo y empieza pidiendo que se elija
    ///   uno: apretado desde la lista solo respondia "elija un equipo
    ///   primero", que es exactamente lo contrario de lo que se pedia.
    ///
    ///   Se exporta lo que el filtro dejo, no todo el catalogo: quien filtro
    ///   por una planta espera esa planta en el archivo.
    /// </summary>
    protected void lnkExportarLista_Click(object sender, EventArgs e)
    {
        try
        {
            List<Activo> lista = FiltrarActivos();

            Dictionary<int, ActivoResumenLista> resumen = new ActivoCentroController().GetResumenLista()
                                                          ?? new Dictionary<int, ActivoResumenLista>();

            StringBuilder sb = new StringBuilder();

            sb.Append("<table border='1'><tr>")
              .Append("<th>Código</th><th>Activo</th><th>Tipo</th><th>Planta</th><th>Área</th>")
              .Append("<th>Estado</th><th>Criticidad</th><th>OT abiertas</th><th>Fallas abiertas</th>")
              .Append("<th>Próximo mantenimiento</th></tr>");

            foreach (Activo a in lista.OrderBy(x => x.act_codigo))
            {
                ActivoResumenLista r;
                if (!resumen.TryGetValue(a.act_id, out r)) r = new ActivoResumenLista();

                sb.Append("<tr>")
                  .Append("<td>").Append(Server.HtmlEncode(Texto(a.act_codigo))).Append("</td>")
                  .Append("<td>").Append(Server.HtmlEncode(Texto(a.act_nombre))).Append("</td>")
                  .Append("<td>").Append(Server.HtmlEncode(Texto(a.tipo_nombre))).Append("</td>")
                  .Append("<td>").Append(Server.HtmlEncode(Texto(a.planta_nombre))).Append("</td>")
                  .Append("<td>").Append(Server.HtmlEncode(Texto(a.area_nombre))).Append("</td>")
                  .Append("<td>").Append(Server.HtmlEncode(Texto(a.estado_nombre))).Append("</td>")
                  .Append("<td>").Append(Server.HtmlEncode(Texto(a.criticidad_nombre))).Append("</td>")
                  .Append("<td>").Append(r.ot_abiertas).Append("</td>")
                  .Append("<td>").Append(r.fallas_abiertas).Append("</td>")
                  .Append("<td>")
                  .Append(r.proxima_mantencion == null ? "Sin programación" : r.proxima_mantencion.Value.ToString("dd-MM-yyyy"))
                  .Append("</td></tr>");
            }

            sb.Append("</table>");

            Response.Clear();
            Response.Buffer = true;
            Response.AddHeader("content-disposition", "attachment;filename=Activos.xls");
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

    protected void lnkExportar_Click(object sender, EventArgs e)
    {
        try
        {
            int activo = ActivoSeleccionado();
            if (activo == 0) { Tools.tools.ClientAlert("Elija un activo primero."); return; }

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
