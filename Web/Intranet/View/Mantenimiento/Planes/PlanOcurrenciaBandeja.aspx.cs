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
/// Bandeja de ocurrencias pendientes (HU-087).
///
/// LA PREGUNTA ES OTRA QUE LA DEL CALENDARIO
///   El calendario del plan responde «qué le toca a ESTE plan este año» y se
///   mira por meses. La bandeja responde «qué tengo encima AHORA», de todos
///   los planes, ordenado por urgencia. Por eso tiene su propio SP y su
///   propia pantalla, y no es el calendario con un filtro más.
///
/// LA SITUACIÓN SE CALCULA AL CONSULTAR
///   Vencida, atrasada, disponible y futura no existen en ninguna tabla: se
///   derivan de las fechas contra ahora. Es el criterio 2 de la historia, y
///   evita que la bandeja dependa de un proceso nocturno que, el día que
///   falle, la deja diciendo que no hay nada atrasado.
///
/// SE MIRA Y SE ACTÚA
///   La tarea la describía como pantalla de solo lectura. Se le dejó además
///   «Generar órdenes de trabajo» sobre lo seleccionado: es el criterio 3 de
///   la historia, el SP ya existe (INS_ORDEN_TRABAJO_OCURRENCIA, bloque 220)
///   y una bandeja que muestra siete vencidas sin poder hacer nada con ellas
///   obliga a entrar plan por plan para ejecutar lo que se acaba de ver.
/// </summary>
public partial class View_Mantenimiento_Planes_PlanOcurrenciaBandeja : System.Web.UI.Page
{
    /// <summary>La situación elegida en la botonera de contadores.</summary>
    public string Situacion
    {
        get { return ViewState["Situacion"] as string ?? ""; }
        set { ViewState["Situacion"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            /* Wrap: true en todo lo que lleva texto. AddTemplateColumn no
               envuelve por omisión, y una celda con nombre de hito y de
               equipo en una sola línea ensancha la tabla hasta empujar la
               última columna fuera del borde. */
            Grid.AddTemplateColumn("SITUACION", "", "SITUACIÓN", Width: "10%", Wrap: true);
            Grid.AddTemplateColumn("CUANDO", "", "PROGRAMADA", Width: "14%", Wrap: true);
            Grid.AddTemplateColumn("EQUIPO", "", "EQUIPO", Width: "19%", Wrap: true);
            Grid.AddTemplateColumn("TRABAJO", "", "QUÉ SE HACE", Width: "29%", Wrap: true);
            Grid.AddTemplateColumn("EXIGE", "", "EXIGE", Width: "13%", Wrap: true);
            Grid.AddTemplateColumn("ORDEN", "", "ORDEN", Width: "8%", Wrap: true);
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;

        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;

        if (!hayCliente) return;

        ConfigurarFiltros();

        /* Generar una orden es crear trabajo, no mirarlo: se pide el permiso
           de órdenes, no el de planes. Esconder la barra no autoriza nada
           —el evento vuelve a preguntarlo en el servidor—, solo evita
           ofrecer un botón que terminaría en un rechazo. */
        if (!Token.Puede("CREAR ORDEN TRABAJO"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    /// <summary>
    /// La URL de un archivo del sitio con la fecha del archivo colgada.
    ///
    /// Un `?vrs=N` escrito a mano solo cambia cuando alguien se acuerda de
    /// subirlo, y hasta entonces el navegador sirve el CSS viejo y la
    /// corrección «no funciona». La fecha del archivo se acuerda sola.
    /// </summary>
    protected string Asset(string ruta)
    {
        string url = ResolveUrl(ruta);

        try
        {
            string fisica = Server.MapPath(ruta);

            if (System.IO.File.Exists(fisica))
                return url + "?v=" + System.IO.File.GetLastWriteTimeUtc(fisica).Ticks;
        }
        catch (Exception)
        {
            /* Si no se puede leer la fecha, la URL sin versión igual sirve la
               página: es mejor un CSS cacheado que una pantalla caída. */
        }

        return url;
    }

    private RadComboBox2 Cbo(string id) { return (RadComboBox2)wucFiltro.FindControl(id); }
    private CheckBox Chk(string id) { return (CheckBox)wucFiltro.FindControl(id); }
    /* global:: obligatorio: `using System.Web.UI` hace que WebControls
       resuelva al namespace de ASP.NET, que tiene su propio Calendar.
       Sin el prefijo compila igual y revienta en el cast, en ejecucion. */
    private global::WebControls.Calendar Cal(string id) { return (global::WebControls.Calendar)wucFiltro.FindControl(id); }

    /// <summary>
    /// Los combos se llenan desde la base y no desde el markup: un catálogo
    /// copiado en un .aspx es el que nadie actualiza el día que cambia. Se
    /// reconstruyen en cada carga preservando lo elegido.
    /// </summary>
    private void ConfigurarFiltros()
    {
        int cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboPlanta = Cbo("cboPlanta");
        if (cboPlanta != null)
        {
            string seleccion = cboPlanta.SelectedValue;

            List<ClienteInstalacion> plantas =
                new ClienteInstalacionController().GetClienteInstalaciones(
                    new ClienteInstalacion { cin_cliente = cliente }) ?? new List<ClienteInstalacion>();

            cboPlanta.Items.Clear();
            cboPlanta.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
            foreach (ClienteInstalacion p in plantas)
                cboPlanta.Items.Add(new RadComboBoxItem(p.cin_nombre, p.cin_id.ToString()));

            RadComboBoxItem item = cboPlanta.FindItemByValue(seleccion ?? "");
            if (item != null) item.Selected = true;
        }

        RadComboBox2 cboPlan = Cbo("cboPlan");
        if (cboPlan != null)
        {
            string seleccion = cboPlan.SelectedValue;

            List<PlanMantenimiento> planes = new PlanMantenimientoController().GetPlanesMantenimiento(
                new PlanMantenimiento { pma_cliente = cliente, filtro_habilitado = true }) ?? new List<PlanMantenimiento>();

            cboPlan.Items.Clear();
            cboPlan.Items.Add(new RadComboBoxItem("Todos los planes", ""));
            foreach (PlanMantenimiento p in planes)
                cboPlan.Items.Add(new RadComboBoxItem(p.pma_codigo + " — " + p.pma_nombre, p.pma_id.ToString()));

            RadComboBoxItem item = cboPlan.FindItemByValue(seleccion ?? "");
            if (item != null) item.Selected = true;
        }
    }

    /// <summary>
    /// El filtro armado, uno solo, que usan la grilla, los contadores y la
    /// exportación. Que sean el mismo objeto es lo que garantiza que el Excel
    /// traiga exactamente lo que se está mirando.
    /// </summary>
    private PlanOcurrencia Filtro()
    {
        PlanOcurrencia f = new PlanOcurrencia();

        RadComboBox2 cboPlanta = Cbo("cboPlanta");
        RadComboBox2 cboPlan = Cbo("cboPlan");
        CheckBox chkParada = Chk("chkSoloParada");
        CheckBox chkCerradas = Chk("chkVerCerradas");
        global::WebControls.Calendar desde = Cal("calDesde");
        global::WebControls.Calendar hasta = Cal("calHasta");

        if (cboPlanta != null && cboPlanta.SelectedValue != "") f.filtro_instalacion = int.Parse(cboPlanta.SelectedValue);
        if (cboPlan != null && cboPlan.SelectedValue != "") f.filtro_plan = int.Parse(cboPlan.SelectedValue);
        if (desde != null && desde.Value != null) f.filtro_desde = desde.Value;
        if (hasta != null && hasta.Value != null) f.filtro_hasta = hasta.Value;

        // Solo se manda cuando está marcado: mandar 0 pediría «las que NO
        // requieren parada», que es otra pregunta.
        if (chkParada != null && chkParada.Checked) f.solo_parada = true;

        f.solo_abiertas = !(chkCerradas != null && chkCerradas.Checked);

        if (!string.IsNullOrEmpty(Situacion)) f.filtro_situacion = Situacion;

        // wucFiltro.Filtro() va al @FILTRO parametrizado del SP. Nunca
        // concatenado: en el buscador eso era inyección SQL (bloque 49).
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) f.filtro = wucFiltro.Filtro();

        return f;
    }

    protected void CargarGrid()
    {
        BandejaResumen resumen;

        List<PlanOcurrencia> lista = new PlanOcurrenciaController().GetBandeja(Filtro(), out resumen)
                                     ?? new List<PlanOcurrencia>();

        Grid.DataSource = lista;

        Kpis(resumen);
        Contexto(lista, resumen);
    }

    /// <summary>
    /// Los cuatro contadores, armados en el servidor.
    ///
    /// Van como HTML y no como controles porque el markup metido dentro de
    /// un LinkButton no sobrevive al re-render asíncrono: la primera carga
    /// pinta la tarjeta y al apretarla vuelve un &lt;a&gt; vacío. El postback lo
    /// recibe un solo LinkButton escondido, con la situación en el argumento.
    /// </summary>
    private void Kpis(BandejaResumen r)
    {
        StringBuilder s = new StringBuilder("<div class=\"sg-a3-kpis\">");

        s.Append(Kpi("VENCIDA", "mdi-alert-octagon-outline", "es-rojo", "Vencidas", r.vencidas, "Pasó la fecha límite"));
        s.Append(Kpi("ATRASADA", "mdi-clock-alert-outline", "es-ambar", "Atrasadas", r.atrasadas, "Pasó la fecha, no el límite"));
        s.Append(Kpi("DISPONIBLE", "mdi-play-circle-outline", "es-verde", "Disponibles", r.disponibles, "Se pueden adelantar"));
        s.Append(Kpi("FUTURA", "mdi-calendar-clock", "es-azul", "Futuras", r.futuras, "Todavía no toca"));

        s.Append("</div>");

        litKpis.Text = s.ToString();
    }

    private string Kpi(string situacion, string icono, string color, string etiqueta, int valor, string pie)
    {
        bool elegido = Situacion == situacion;

        string titulo = elegido
            ? "Está filtrando por esta situación. Apriete otra vez para ver todas."
            : "Ver solo las de esta situación";

        return "<a href=\"javascript:void(0)\" title=\"" + Server.HtmlEncode(titulo) + "\""
             + " class=\"sg-a3-kpi" + (elegido ? " es-elegido" : "") + "\""
             + " onclick=\"document.getElementById('hdnSituacion').value='" + situacion + "';"
             + Page.ClientScript.GetPostBackEventReference(lnkSituacion, "") + ";return false;\">"
             + "<span class=\"sg-a3-kpi-ico " + color + "\"><i class=\"mdi " + icono + "\"></i></span>"
             + "<div><span class=\"sg-a3-kpi-etq\">" + Server.HtmlEncode(etiqueta) + "</span>"
             + "<span class=\"sg-a3-kpi-val\">" + valor + "</span>"
             + "<span class=\"sg-a3-kpi-pie\">" + Server.HtmlEncode(pie) + "</span></div></a>";
    }

    /// <summary>
    /// Una línea que dice qué se está mirando y qué se está dejando fuera.
    ///
    /// Sin ella, una bandeja vacía se lee como «no hay nada que hacer»
    /// cuando en realidad puede ser un filtro puesto hace tres pantallas.
    /// </summary>
    private void Contexto(List<PlanOcurrencia> lista, BandejaResumen resumen)
    {
        string texto;

        if (!string.IsNullOrEmpty(Situacion))
            texto = "Mostrando solo las <strong>" + Server.HtmlEncode(Situacion.ToLower()) + "s</strong>. "
                  + "Apriete el mismo contador otra vez para ver todas.";
        else if (resumen.pendientes == 0)
            texto = "No hay nada vencido, atrasado ni disponible: la planta está al día.";
        else
            texto = "<strong>" + resumen.pendientes + "</strong> "
                  + (resumen.pendientes == 1 ? "mantención requiere" : "mantenciones requieren")
                  + " atención hoy"
                  + (resumen.con_parada > 0
                        ? ", " + resumen.con_parada + " de ellas con <strong>parada de equipo</strong>."
                        : ".");

        litContexto.Text = "<p class=\"sg-plan-anio\"><i class=\"mdi mdi-inbox-arrow-down-outline\"></i>" + texto + "</p>";
    }

    protected void Filtro_Changed(object sender, EventArgs e)
    {
        Grid.CurrentPageIndex = 0;
    }

    protected void lnkSituacion_Click(object sender, EventArgs e)
    {
        // Cual se apreto viaja en el campo oculto: hay un solo boton para
        // los cuatro contadores.
        string pedida = (hdnSituacion.Value ?? "").Trim().ToUpperInvariant();

        // El mismo contador dos veces suelta el filtro: es el gesto que
        // espera cualquiera que acaba de entrar en «vencidas».
        Situacion = (Situacion == pedida) ? "" : pedida;

        Grid.CurrentPageIndex = 0;
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        PlanOcurrencia o = item.DataItem as PlanOcurrencia;
        if (o == null) return;

        item["SITUACION"].Controls.Add(new Literal { Text = ChipSituacion(o) });
        item["CUANDO"].Controls.Add(new Literal { Text = CeldaCuando(o) });
        item["EQUIPO"].Controls.Add(new Literal { Text = CeldaEquipo(o) });
        item["TRABAJO"].Controls.Add(new Literal { Text = CeldaTrabajo(o) });
        item["EXIGE"].Controls.Add(new Literal { Text = CeldaExige(o) });
        item["ORDEN"].Controls.Add(new Literal { Text = CeldaOrden(o) });
    }

    private string ChipSituacion(PlanOcurrencia o)
    {
        switch ((o.situacion ?? "").ToUpperInvariant())
        {
            case "VENCIDA":
                return "<span class=\"grid-estado-chip is-error\"><i class=\"mdi mdi-alert-octagon-outline\"></i>Vencida</span>";
            case "ATRASADA":
                return "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-clock-alert-outline\"></i>Atrasada</span>";
            case "DISPONIBLE":
                return "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-play-circle-outline\"></i>Disponible</span>";
            case "CERRADA":
                return "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-check-circle-outline\"></i>"
                     + Server.HtmlEncode(o.estado_nombre) + "</span>";
            default:
                return "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-calendar-clock\"></i>Futura</span>";
        }
    }

    /// <summary>
    /// La fecha y, debajo, cuánto falta o cuánto lleva esperando.
    ///
    /// «hace 12 días» se entiende sin hacer la resta; «01-09-2026» obliga a
    /// mirar el calendario para saber si eso es grave.
    /// </summary>
    private string CeldaCuando(PlanOcurrencia o)
    {
        string fecha = o.fecha_programada.ToString("dd-MM-yyyy");
        int dias = o.dias_restantes;

        string cuanto;
        if (dias == 0) cuanto = "hoy";
        else if (dias == 1) cuanto = "mañana";
        else if (dias == -1) cuanto = "ayer";
        else if (dias > 1) cuanto = "en " + dias + " días";
        else cuanto = "hace " + (-dias) + " días";

        string sub = "<span class=\"sg-plan-sub\">" + cuanto;

        // Con el límite encima, eso es lo que manda y va dicho aparte.
        if (o.dias_para_limite != null && o.situacion != "CERRADA")
        {
            int limite = o.dias_para_limite.Value;
            if (limite < 0) sub += " · límite vencido hace " + (-limite) + " días";
            else if (limite <= 7) sub += " · vence " + (limite == 0 ? "hoy" : "en " + limite + " días");
        }

        if (o.fue_reprogramada) sub += " · reprogramada";

        return "<strong>" + fecha + "</strong>" + sub + "</span>";
    }

    private string CeldaEquipo(PlanOcurrencia o)
    {
        string s = "<strong>" + Server.HtmlEncode(o.activo_codigo) + "</strong> "
                 + Server.HtmlEncode(o.activo_nombre);

        s += "<span class=\"sg-plan-sub\">"
           + (string.IsNullOrEmpty(o.planta_nombre) ? "sin planta" : Server.HtmlEncode(o.planta_nombre));

        if (!string.IsNullOrEmpty(o.componente_nombre))
            s += " · " + Server.HtmlEncode(o.componente_nombre);

        return s + "</span>";
    }

    private string CeldaTrabajo(PlanOcurrencia o)
    {
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + o.plan_id));

        string s = "<strong>" + Server.HtmlEncode(o.hito_codigo) + "</strong> "
                 + Server.HtmlEncode(o.hito_nombre);

        s += "<span class=\"sg-plan-sub\"><a href=\"javascript:void(0)\" onclick=\"abrirPlan('" + query + "')\">"
           + Server.HtmlEncode(o.plan_codigo) + "</a>";

        /* Un hito sin actividades genera una orden con un solo paso -el hito
           entero-, y conviene saberlo ANTES de generarla, no al abrirla. */
        if (o.actividades == 0)
            s += " · <span class=\"grid-estado-chip is-advertencia\">"
               + "<i class=\"mdi mdi-alert-outline\"></i>sin actividades</span>";
        else
            s += " · " + o.actividades + (o.actividades == 1 ? " actividad" : " actividades");

        return s + "</span>";
    }

    private string CeldaExige(PlanOcurrencia o)
    {
        string chips = "";

        if (o.requiere_parada)
            chips += "<span class=\"grid-estado-chip is-advertencia\" title=\"Exige el equipo detenido\">"
                   + "<i class=\"mdi mdi-stop-circle-outline\"></i>parada</span> ";

        if (o.es_overhaul)
            chips += "<span class=\"grid-estado-chip is-neutro\" title=\"Intervención mayor\">"
                   + "<i class=\"mdi mdi-wrench-outline\"></i>overhaul</span> ";

        if (o.duracion_estimada_minuto != null)
            chips += "<span class=\"sg-plan-sub\">" + Duracion(o.duracion_estimada_minuto.Value) + "</span>";

        return chips == "" ? "<span class=\"sigma-inv-vacio\">nada especial</span>" : chips;
    }

    private static string Duracion(int minutos)
    {
        if (minutos < 60) return minutos + " min";

        int horas = minutos / 60, resto = minutos % 60;
        return resto == 0 ? horas + " h" : horas + " h " + resto + " min";
    }

    private string CeldaOrden(PlanOcurrencia o)
    {
        if (o.orden_trabajo_id == null)
            return "<span class=\"sigma-inv-vacio\">sin orden</span>";

        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + o.orden_trabajo_id.Value));

        /* Solo el numero, y el titulo como tooltip: el titulo de la orden es
           "<hito> - <equipo>", o sea las dos columnas que la fila ya tiene al
           lado. Repetirlo ensanchaba la tabla hasta cortarla contra el borde
           para no decir nada nuevo. */
        return "<a href=\"javascript:void(0)\" onclick=\"abrirOrden('" + query + "')\""
             + " title=\"" + Server.HtmlEncode(o.orden_trabajo_titulo) + "\">"
             + "<i class=\"mdi mdi-clipboard-text-outline\"></i> OT-" + o.orden_trabajo_correlativo + "</a>";
    }

    protected void lnkGenerarOT_Click(object sender, EventArgs e)
    {
        try
        {
            /* La guarda de verdad, en el servidor. Esconder la barra solo
               evita ofrecerla; un postback armado a mano llega igual acá. */
            if (!Token.Puede("CREAR ORDEN TRABAJO"))
            {
                Tools.tools.ClientAlert("No tiene permiso para crear órdenes de trabajo.", "alerta");
                return;
            }

            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Marque al menos una mantención de la lista.");
                return;
            }

            int creadas = 0, existian = 0;
            List<string> errores = new List<string>();
            PlanOcurrenciaController controller = new PlanOcurrenciaController();

            foreach (string indice in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[int.Parse(indice)];
                int ocurrencia = int.Parse(value["pmo_id"].ToString());

                Respuesta r = controller.GenerarOrden(ocurrencia);

                /* El SP es idempotente: si la ocurrencia ya tenía orden
                   devuelve esa misma en vez de crear una segunda. Se cuenta
                   aparte para no anunciar como creado lo que ya estaba. */
                if (r.error) errores.Add(r.detalle);
                else if (r.detalle != null && r.detalle.IndexOf("ya", StringComparison.OrdinalIgnoreCase) == 0) existian++;
                else creadas++;
            }

            string mensaje = creadas + (creadas == 1 ? " orden generada" : " órdenes generadas");
            if (existian > 0) mensaje += "; " + existian + (existian == 1 ? " ya tenía orden" : " ya tenían orden");
            if (errores.Count > 0) mensaje += "; " + errores.Count + " no se pudo generar: " + errores[0];

            pnlResultado.Visible = true;
            litResultado.Text = Server.HtmlEncode(mensaje);

            Tools.tools.ClientAlert(mensaje, errores.Count > 0 ? "alerta" : "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void lnkDescargar_Click(object sender, EventArgs e)
    {
        try
        {
            // El mismo filtro que la grilla: el Excel trae lo que se ve.
            new PlanOcurrenciaController().ExportarBandeja(Filtro());
        }
        catch (System.Threading.ThreadAbortException)
        {
            /* Response.End() dentro de la exportación aborta el hilo a
               propósito. No es un error: es cómo termina una descarga. */
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
