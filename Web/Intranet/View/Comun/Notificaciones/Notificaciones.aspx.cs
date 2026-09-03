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
/// Centro de Acción Operacional.
///
/// MAESTRO–DETALLE Y NO UNA LISTA
///   La bandeja anterior agrupaba por categoría y abría cada alerta en una
///   ventana modal. Servía para enterarse; no para resolver: había que salir
///   de la lista para hacer cualquier cosa. Acá la cola queda a la izquierda,
///   el detalle accionable a la derecha, y la selección sobrevive al postback.
///
/// LEER, RECONOCER Y RESOLVER SON TRES COSAS
///   Abrir una alerta la marca leída —eso es de cada persona, vive en
///   Alerta_Lectura— y no le cambia el estado. Tomarla es explícito. Resolver
///   pide observación y descartar pide motivo. Ninguna de las tres se simula
///   en JavaScript: las tres pasan por UPD_ALERTA_ESTADO, que revalida el
///   permiso en el servidor.
///
/// LOS NÚMEROS NO SE INVENTAN
///   Los cinco indicadores salen de SEL_ALERTA_RESUMEN. Donde el modelo no
///   entregó un dato —una probabilidad, una vida útil— la pantalla esconde el
///   componente en vez de escribir un número de relleno.
/// </summary>
public partial class View_Comun_Notificaciones_Notificaciones : System.Web.UI.Page
{
    #region Estado

    /// <summary>La alerta abierta a la derecha. Sobrevive a los postbacks.</summary>
    public int AlertaId
    {
        get { return ViewState["AlertaId"] != null ? (int)ViewState["AlertaId"] : 0; }
        set { ViewState["AlertaId"] = value; }
    }

    /// <summary>ACTIVAS · GESTION · RESUELTAS.</summary>
    public string Tab
    {
        get { return ViewState["Tab"] != null ? (string)ViewState["Tab"] : "ACTIVAS"; }
        set { ViewState["Tab"] = value; }
    }

    /// <summary>
    /// Cuando el usuario pidió cerrar la alerta: RESUELTA o DESCARTADA. El
    /// panel de motivo se muestra ANTES de ejecutar, porque descartar sin
    /// motivo deja una alerta cerrada que nadie puede explicar después.
    /// </summary>
    public string ModoCierre
    {
        get { return ViewState["ModoCierre"] != null ? (string)ViewState["ModoCierre"] : ""; }
        set { ViewState["ModoCierre"] = value; }
    }

    /// <summary>Si el panel para elegir responsable está abierto.</summary>
    public bool MostrarAsignar
    {
        get { return ViewState["MostrarAsignar"] != null && (bool)ViewState["MostrarAsignar"]; }
        set { ViewState["MostrarAsignar"] = value; }
    }

    private AlertaResumen _resumen;
    private List<Alerta> _lista;

    #endregion

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack) CargarTipos();
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        /* La lista se arma SIEMPRE, también en postback. El defecto histórico
           de esta pantalla fue justo el contrario: se saltaba la carga en
           postback y volvía a dibujarse desde el ViewState, así que filtrar
           parpadeaba y mostraba lo mismo. No fallaba con un error: fallaba
           mostrando datos viejos. */
        CargarKpis();
        CargarCola();
        CargarDetalle();

        udPanel.Update();
    }

    #region Cola

    /// <summary>
    /// Los tipos salen de las alertas que HAY, no del catálogo completo:
    /// ofrecer filtrar por un tipo sin ninguna alerta es ofrecer un camino
    /// que termina en una lista vacía.
    /// </summary>
    protected void CargarTipos()
    {
        cboTipo.Items.Clear();
        cboTipo.Items.Add(new RadComboBoxItem("Todo tipo", ""));

        List<Alerta> todas = new AlertaController().GetAlertas(false, 500);

        List<string> vistos = new List<string>();

        foreach (Alerta a in todas)
        {
            if (vistos.Contains(a.alt_codigo)) continue;

            vistos.Add(a.alt_codigo);
            cboTipo.Items.Add(new RadComboBoxItem(a.alt_nombre, a.alt_codigo));
        }
    }

    protected AlertaResumen Resumen()
    {
        if (_resumen == null) _resumen = new AlertaController().GetResumen();
        return _resumen;
    }

    protected void CargarKpis()
    {
        AlertaResumen r = Resumen();

        /* Una clase PUBLICA y no un tipo anónimo: los anónimos son internal,
           y Eval() los resuelve por reflexión respetando la accesibilidad.
           En un Website project —donde el marcado compila a otro ensamblado—
           eso falla en tiempo de ejecución con "no se encontró la propiedad",
           que es un error que no aparece al compilar. */
        AlertaTendencia t = new AlertaController().GetTendencia(7);

        List<Kpi> kpis = new List<Kpi>();

        kpis.Add(new Kpi(r.Abiertas,       "Activas",         "mdi mdi-bell-outline",             "",            t.Activas,        t.VarActivas));
        kpis.Add(new Kpi(r.Criticas,       "Críticas",        "mdi mdi-alert-octagon-outline",    "is-critica",  t.Criticas,       t.VarCriticas));
        kpis.Add(new Kpi(r.EnGestion,      "En gestión",      "mdi mdi-account-clock-outline",    "is-gestion",  t.EnGestion,      t.VarEnGestion));
        kpis.Add(new Kpi(r.SinResponsable, "Sin responsable", "mdi mdi-account-question-outline", "is-alerta",   t.SinResponsable, t.VarSinResponsable));
        /* La de predicciones lleva el SIMBOLO de SIGMA AI, no un icono de
           librería: es lo único de la fila que sale del modelo y tiene que
           reconocerse como tal de un vistazo. */
        Kpi ai = new Kpi(r.Predicciones, "Predicciones AI", "", "is-ai",
                         t.Predicciones, t.VarPredicciones);
        ai.Svg = ResolveUrl("~/Imagen/sigma-ai/sigma-ai-symbol-gradient.svg");
        kpis.Add(ai);

        rptKpis.DataSource = kpis;
        rptKpis.DataBind();

        /* El rótulo se arma acá, no en el marcado: dentro del LinkButton los
           hijos estáticos no sobreviven al re-dibujo del UpdatePanel y las
           pestañas desaparecían al primer postback. */
        tabActivas.Text = Pestana("Activas", r.Abiertas);
        tabGestion.Text = Pestana("En gestión", r.EnGestion);
        tabResueltas.Text = Pestana("Resueltas", 0);

        tabActivas.CssClass = "sg-tab" + (Tab == "ACTIVAS" ? " is-activa" : "");
        tabGestion.CssClass = "sg-tab" + (Tab == "GESTION" ? " is-activa" : "");
        tabResueltas.CssClass = "sg-tab" + (Tab == "RESUELTAS" ? " is-activa" : "");
    }

    /// <summary>El rótulo de una pestaña, con su contador cuando hay algo.</summary>
    protected string Pestana(string texto, int cuantas)
    {
        string s = Server.HtmlEncode(texto);

        if (cuantas > 0)
            s += " <span class=\"sg-tab-n\">" + cuantas + "</span>";

        return s;
    }

    /// <summary>Un indicador de la fila superior, con su curva y su "vs ayer".</summary>
    public class Kpi
    {
        public int Valor { get; set; }
        public string Rotulo { get; set; }
        public string Icono { get; set; }
        public string Clase { get; set; }
        public List<int> Serie { get; set; }
        public int? Variacion { get; set; }

        /// <summary>
        /// Cuando el indicador tiene marca propia. Si viene, se dibuja la
        /// imagen en vez del icono de fuente.
        /// </summary>
        public string Svg { get; set; }

        /// <summary>El contenido del cuadro: la marca si la hay, si no el icono.</summary>
        public string IconoHtml
        {
            get
            {
                if (!string.IsNullOrEmpty(Svg))
                    return "<img src=\"" + Svg + "\" alt=\"\" class=\"sg-kpi-marca\" />";

                return "<i class=\"" + Icono + "\"></i>";
            }
        }

        public Kpi(int valor, string rotulo, string icono, string clase,
                   List<int> serie, int? variacion)
        {
            Valor = valor;
            Rotulo = rotulo;
            Icono = icono;
            Clase = clase;
            Serie = serie ?? new List<int>();
            Variacion = variacion;
        }

        /// <summary>
        /// "↑ 12% vs ayer". Vacío cuando ayer no hubo nada: no existe el
        /// porcentaje de crecer desde cero, y escribir uno sería inventarlo.
        /// </summary>
        public string TendenciaTexto
        {
            get
            {
                if (Variacion == null) return "";

                string flecha = Variacion.Value >= 0 ? "&#8593;" : "&#8595;";
                return flecha + " " + Math.Abs(Variacion.Value) + "% vs ayer";
            }
        }

        public string TendenciaClase
        {
            get { return Variacion == null ? "" : (Variacion.Value >= 0 ? "is-sube" : "is-baja"); }
        }

        /// <summary>
        /// La curva, como SVG en línea. Se dibuja en el servidor y no con una
        /// librería: son siete puntos, y traer un gráfico entero para eso
        /// pesaría más que la página.
        ///
        /// El viewBox es fijo y el trazo se escala con preserveAspectRatio,
        /// así que la tarjeta puede cambiar de ancho sin recalcular nada.
        /// </summary>
        public string Sparkline
        {
            get
            {
                if (Serie == null || Serie.Count < 2) return "";

                int max = 0;
                foreach (int v in Serie) if (v > max) max = v;

                /* Todo en cero es una línea plana abajo, no una división por
                   cero ni una curva inventada. */
                if (max <= 0) max = 1;

                System.Text.StringBuilder pts = new System.Text.StringBuilder();

                for (int i = 0; i < Serie.Count; i++)
                {
                    double x = (100.0 * i) / (Serie.Count - 1);
                    double y = 28.0 - (24.0 * Serie[i] / max);

                    if (i > 0) pts.Append(' ');
                    pts.Append(x.ToString("0.##", System.Globalization.CultureInfo.InvariantCulture));
                    pts.Append(',');
                    pts.Append(y.ToString("0.##", System.Globalization.CultureInfo.InvariantCulture));
                }

                return "<svg class=\"sg-spark\" viewBox=\"0 0 100 32\" preserveAspectRatio=\"none\" " +
                       "aria-hidden=\"true\" focusable=\"false\">" +
                       "<polyline points=\"" + pts + "\" fill=\"none\" stroke=\"currentColor\" " +
                       "stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" " +
                       "vector-effect=\"non-scaling-stroke\" /></svg>";
            }
        }
    }

    protected List<Alerta> Lista()
    {
        if (_lista != null) return _lista;

        AlertaController controller = new AlertaController();

        /* La pestaña de resueltas necesita ver lo cerrado; las otras dos no.
           Se le dice al SP en vez de traer todo y filtrar acá: el tope corta
           ANTES del filtro, así que filtrar en memoria dejaba páginas vacías
           teniendo datos. */
        bool soloAbiertas = (Tab != "RESUELTAS");

        _lista = controller.GetAlertas(
            soloAbiertas, 300,
            Tab,
            cboSeveridad.SelectedValue,
            cboTipo.SelectedValue,
            null,
            txtBuscar.Text.Trim());

        return _lista;
    }

    protected void CargarCola()
    {
        List<Alerta> lista = Lista();

        pnlColaVacia.Visible = (lista.Count == 0);
        rptAlertas.Visible = (lista.Count > 0);

        if (lista.Count == 0)
        {
            litColaVacia.Text = Tab == "RESUELTAS"
                ? "Todavía no se ha cerrado ninguna alerta con estos filtros."
                : "No hay alertas con estos filtros.";
        }

        rptAlertas.DataSource = lista;
        rptAlertas.DataBind();
    }

    protected void rptAlertas_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem)
            return;

        Alerta a = (Alerta)e.Item.DataItem;
        LinkButton lnk = (LinkButton)e.Item.FindControl("lnkItem");
        Literal lit = (Literal)e.Item.FindControl("litItem");

        lnk.CssClass = "sg-alerta " + ClaseSeveridad(a.sev_codigo) +
                       (a.ale_id == AlertaId ? " is-seleccionada" : "") +
                       (a.LEIDA ? "" : " is-nueva");

        StringBuilder sb = new StringBuilder();

        sb.Append("<span class=\"sg-alerta-barra\"></span>");
        sb.Append("<span class=\"sg-alerta-cuerpo\">");

        // ---- Título y chips ----
        sb.Append("<span class=\"sg-alerta-fila1\">");
        sb.Append("<span class=\"sg-alerta-titulo\">" + Server.HtmlEncode(a.ale_titulo) + "</span>");
        sb.Append("<span class=\"sg-chip " + ClaseSeveridad(a.sev_codigo) + "\">" +
                  Server.HtmlEncode(a.sev_nombre.ToUpper()) + "</span>");
        sb.Append("</span>");

        // ---- Qué cosa es: activo, repuesto, planta ----
        List<string> contexto = new List<string>();

        if (!string.IsNullOrEmpty(a.ACTIVO_CODIGO)) contexto.Add(a.ACTIVO_CODIGO);
        else if (!string.IsNullOrEmpty(a.REPUESTO_CODIGO)) contexto.Add(a.REPUESTO_CODIGO);

        if (!string.IsNullOrEmpty(a.BODEGA_NOMBRE)) contexto.Add(a.BODEGA_NOMBRE);
        if (!string.IsNullOrEmpty(a.INSTALACION_NOMBRE)) contexto.Add(a.INSTALACION_NOMBRE);

        if (contexto.Count > 0)
            sb.Append("<span class=\"sg-alerta-contexto\">" +
                      Server.HtmlEncode(string.Join(" · ", contexto.ToArray())) + "</span>");

        // ---- Pie: responsable, antigüedad, origen ----
        sb.Append("<span class=\"sg-alerta-pie\">");

        if (string.IsNullOrEmpty(a.RESPONSABLE_NOMBRE))
            sb.Append("<span class=\"sg-chip is-sinresp\">Sin responsable</span>");
        else
            sb.Append("<span class=\"sg-alerta-resp\">" +
                      Server.HtmlEncode(a.RESPONSABLE_NOMBRE) + "</span>");

        if (a.aet_codigo != "NUEVA")
            sb.Append("<span class=\"sg-chip is-estado\">" +
                      Server.HtmlEncode(a.aet_nombre) + "</span>");

        /* El distintivo de SIGMA AI SOLO en lo que salió del modelo. Ponerlo
           en un stock bajo el mínimo —que es una resta— sería atribuirle al
           modelo un trabajo que no hizo. */
        if (a.ES_PREDICCION)
            /* La variante -dark lleva tinta #0B0F1A y es la que se lee sobre
               la fila, que es clara. La -light es blanca y desaparecía. */
            sb.Append("<span class=\"sg-alerta-ai\" title=\"Generada por SIGMA AI\">" +
                      "<img alt=\"\" src=\"" +
                      ResolveUrl("~/Imagen/sigma-ai/sigma-ai-badge-dark.svg") + "\" />" +
                      "<span>SIGMA AI</span></span>");

        sb.Append("<span class=\"sg-alerta-cuando\">" + Server.HtmlEncode(a.Antiguedad) + "</span>");

        if (a.ale_ocurrencias > 1)
            sb.Append("<span class=\"sg-alerta-veces\" title=\"La condición se repitió\">&times;" +
                      a.ale_ocurrencias + "</span>");

        sb.Append("</span>");
        sb.Append("</span>");

        lit.Text = sb.ToString();
    }

    protected void rptAlertas_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        if (e.CommandName != "Seleccionar") return;

        int id;
        if (!int.TryParse(e.CommandArgument.ToString(), out id)) return;

        AlertaId = id;
        ModoCierre = "";
        MostrarAsignar = false;

        /* Abrir la alerta la marca LEÍDA y nada más. No la reconoce, no la
           resuelve: eso es explícito y pasa por otro botón. */
        new AlertaController().Leer(id);

        _resumen = null;
        _lista = null;
    }

    #endregion

    #region Detalle

    protected void CargarDetalle()
    {
        Alerta a = Actual();

        pnlSinSeleccion.Visible = (a == null);
        pnlDetalle.Visible = (a != null);

        if (a == null) return;

        // ---- Chips de cabecera ----
        StringBuilder chips = new StringBuilder();
        chips.Append("<span class=\"sg-chip " + ClaseSeveridad(a.sev_codigo) + "\">" +
                     Server.HtmlEncode(a.sev_nombre.ToUpper()) + "</span>");
        chips.Append("<span class=\"sg-chip is-estado\">" + Server.HtmlEncode(a.aet_nombre) + "</span>");

        if (string.IsNullOrEmpty(a.RESPONSABLE_NOMBRE))
            chips.Append("<span class=\"sg-chip is-sinresp\">Sin responsable</span>");

        litChips.Text = chips.ToString();
        litTitulo.Text = Server.HtmlEncode(a.ale_titulo);

        // ---- Meta ----
        /* Cada dato en su propia pastilla, no una tira de texto separada por
           puntos. Con chips el ojo salta directo al que busca —el equipo, la
           planta, el responsable— en vez de leer la linea entera. */
        StringBuilder meta = new StringBuilder();

        if (!string.IsNullOrEmpty(a.ACTIVO_CODIGO))
            meta.Append(Pastilla("mdi-cog-outline", a.ACTIVO_CODIGO +
                (string.IsNullOrEmpty(a.ACTIVO_NOMBRE) ? "" : " · " + a.ACTIVO_NOMBRE), "is-dato"));

        if (!string.IsNullOrEmpty(a.REPUESTO_CODIGO))
            meta.Append(Pastilla("mdi-package-variant", a.REPUESTO_CODIGO, "is-dato"));

        if (!string.IsNullOrEmpty(a.BODEGA_NOMBRE))
            meta.Append(Pastilla("mdi-warehouse", a.BODEGA_NOMBRE, "is-dato"));

        if (!string.IsNullOrEmpty(a.INSTALACION_NOMBRE))
            meta.Append(Pastilla("mdi-map-marker-outline", a.INSTALACION_NOMBRE, "is-dato"));

        meta.Append(Pastilla("mdi-clock-outline", a.Antiguedad, "is-dato"));
        meta.Append(Pastilla("mdi-source-branch", a.alt_nombre, "is-origen"));

        if (!string.IsNullOrEmpty(a.RESPONSABLE_NOMBRE))
            meta.Append(Pastilla("mdi-account-outline", a.RESPONSABLE_NOMBRE, "is-persona"));

        if (a.ale_ocurrencias > 1)
            meta.Append(Pastilla("mdi-repeat", "Se repitió " + a.ale_ocurrencias + " veces", "is-repite"));

        litMeta.Text = meta.ToString();

        // ---- Descripción y valores ----
        StringBuilder desc = new StringBuilder();
        desc.Append("<p>" + Server.HtmlEncode(a.ale_descripcion) + "</p>");

        if (a.ale_valor_observado != null && a.ale_valor_umbral != null)
        {
            desc.Append("<div class=\"sg-umbral\">");
            desc.Append("<span><b>Valor actual</b>" + a.ale_valor_observado.Value.ToString("N2") + "</span>");
            desc.Append("<span><b>Umbral</b>" + a.ale_valor_umbral.Value.ToString("N2") + "</span>");

            if (a.ale_ocurrencias > 1)
                desc.Append("<span><b>Se repitió</b>" + a.ale_ocurrencias + " veces</span>");

            desc.Append("</div>");
        }

        litDescripcion.Text = desc.ToString();

        CargarPrediccion(a);
        CargarRecomendacion(a);
        CargarLinea(a);
        CargarAcciones(a);
        CargarResponsables(a);
        CargarCierre();
    }

    /// <summary>Una pastilla del encabezado: icono y dato, sin puntos sueltos.</summary>
    protected string Pastilla(string icono, string texto, string clase)
    {
        return "<span class=\"sg-pill " + clase + "\">" +
               "<i class=\"mdi " + icono + "\"></i>" +
               "<span>" + Server.HtmlEncode(texto) + "</span></span>";
    }

    protected Alerta Actual()
    {
        if (AlertaId == 0) return null;

        foreach (Alerta a in Lista())
            if (a.ale_id == AlertaId) return a;

        /* Puede haber salido de la lista por un cambio de pestaña o de
           filtro. Se busca aparte para no perder el detalle abierto. */
        List<Alerta> todas = new AlertaController().GetAlertas(false, 500);

        foreach (Alerta a in todas)
            if (a.ale_id == AlertaId) return a;

        return null;
    }

    /// <summary>
    /// El panel de SIGMA AI. Solo para alertas del modelo, y solo con los
    /// datos que el modelo entregó de verdad.
    /// </summary>
    protected void CargarPrediccion(Alerta a)
    {
        pnlPrediccion.Visible = false;
        pnlAnalizando.Visible = false;

        if (!a.ES_PREDICCION) return;

        AlertaPrediccion p = new AlertaController().GetPrediccion(a.ale_id);

        /* La alerta dice que es del modelo pero la predicción todavía no está
           calculada: eso es "analizando", no "sin datos". */
        if (p == null)
        {
            pnlAnalizando.Visible = true;
            return;
        }

        pnlPrediccion.Visible = true;

        litAiCuando.Text = p.pre_fecha_calculo_utc != null
            ? "Calculado el " + p.pre_fecha_calculo_utc.Value.ToLocalTime().ToString("dd-MM-yyyy HH:mm")
            : "";

        if (!string.IsNullOrEmpty(p.MODELO_VERSION))
            litAiCuando.Text += "  ·  " + Server.HtmlEncode(p.MODELO_NOMBRE) + " v" + p.MODELO_VERSION;

        // ---- Riesgo: solo lo que existe ----
        StringBuilder r = new StringBuilder();

        if (p.pre_probabilidad != null)
            r.Append(Anillo(p));

        if (p.pre_dia_restante != null)
            r.Append("<div class=\"sg-ai-vida\"><span class=\"t\">Vida útil estimada</span><span class=\"n\">" +
                     p.pre_dia_restante.Value + (p.pre_dia_restante.Value == 1 ? " día" : " días") + "</span></div>");

        if (r.Length == 0)
            r.Append("<div class=\"sg-ai-nodato\">No disponible</div>");

        litRiesgo.Text = r.ToString();

        // ---- La curva de los últimos días ----
        litCurva.Text = Curva(p);

        // ---- De la predicción al encargo ----
        CargarOrdenTrabajo(p);

        // ---- Qué detectó ----
        /* La explicación del hallazgo es la DESCRIPCIÓN de la alerta, que es
           donde el detector deja la frase redactada. Antes se mostraba el
           nombre del primer factor —"Vibración"— que no explica nada: dice
           qué se midió, no qué se encontró. */
        litHallazgo.Text = !string.IsNullOrEmpty(a.ale_descripcion)
            ? Server.HtmlEncode(a.ale_descripcion)
            : "<span class=\"sg-ai-nodato\">El modelo no entregó una explicación para esta predicción.</span>";

        // ---- Factores ----
        StringBuilder f = new StringBuilder();

        foreach (AlertaFactor factor in p.Factores)
        {
            f.Append("<div class=\"sg-factor\">");
            f.Append("<span class=\"sg-factor-nombre\">" + Server.HtmlEncode(factor.Texto ?? "") + "</span>");

            if (factor.Contribucion != null)
            {
                string signo = factor.Contribucion.Value >= 0 ? "+" : "";
                f.Append("<span class=\"sg-factor-valor\">" + signo +
                         factor.Contribucion.Value.ToString("N0") + " %</span>");
            }
            else if (factor.ValorObservado != null)
            {
                f.Append("<span class=\"sg-factor-valor\">" +
                         factor.ValorObservado.Value.ToString("N2") + "</span>");
            }

            f.Append("</div>");
        }

        litFactores.Text = f.Length > 0 ? f.ToString()
            : "<div class=\"sg-ai-nodato\">Sin factores registrados.</div>";
    }

    /// <summary>
    /// El anillo con la probabilidad de falla.
    ///
    /// Se dibuja en el servidor por la misma razón que el sparkline: el panel
    /// vive dentro de un UpdatePanel, y un gráfico que depende de JavaScript
    /// para existir desaparece en el primer refresco parcial.
    /// </summary>
    private string Anillo(AlertaPrediccion p)
    {
        decimal v = p.pre_probabilidad.Value;
        if (v <= 1) v = v * 100;

        double pct = (double)Math.Round(v, 0);
        if (pct < 0) pct = 0;
        if (pct > 100) pct = 100;

        /* El radio y el perímetro tienen que cuadrar: el trazo se recorta con
           stroke-dasharray, así que el perímetro ES la escala del gráfico. */
        const double radio = 44;
        double perimetro = 2 * Math.PI * radio;
        double pintado = perimetro * pct / 100.0;

        StringBuilder b = new StringBuilder();
        b.Append("<div class=\"sg-anillo\">");
        b.Append("<svg viewBox=\"0 0 104 104\" class=\"sg-anillo-svg\" aria-hidden=\"true\">");

        /* El fondo completo primero: es la referencia contra la que se lee
           cuánto falta, y sin él un 87% y un 40% se ven igual de "casi". */
        b.Append("<circle cx=\"52\" cy=\"52\" r=\"" + N(radio) + "\" fill=\"none\" " +
                 "stroke=\"rgba(230,57,70,.14)\" stroke-width=\"11\" />");

        b.Append("<circle cx=\"52\" cy=\"52\" r=\"" + N(radio) + "\" fill=\"none\" " +
                 "stroke=\"var(--sg-danger, #E63946)\" stroke-width=\"11\" stroke-linecap=\"round\" " +
                 "stroke-dasharray=\"" + N(pintado) + " " + N(perimetro) + "\" " +
                 "transform=\"rotate(-90 52 52)\" />");

        b.Append("</svg>");
        b.Append("<span class=\"sg-anillo-txt\">");
        b.Append("<span class=\"n\">" + pct.ToString("0", CultureInfo.InvariantCulture) + "%</span>");
        b.Append("<span class=\"t\">Probabilidad<br />de falla</span>");
        b.Append("</span></div>");

        return b.ToString();
    }

    /// <summary>
    /// Cómo venía subiendo el riesgo, una corrida por día.
    ///
    /// Con menos de dos puntos devuelve vacío y no se dibuja nada: una línea
    /// de un solo punto no cuenta ninguna historia, y unos ejes vacíos
    /// sugieren que faltan datos que en realidad nunca se midieron.
    /// </summary>
    private string Curva(AlertaPrediccion p)
    {
        if (p.Serie == null || p.Serie.Count < 2) return "";

        int n = p.Serie.Count;
        const double ancho = 260, alto = 90;

        StringBuilder linea = new StringBuilder();
        StringBuilder area = new StringBuilder();

        area.Append("0," + N(alto) + " ");

        for (int i = 0; i < n; i++)
        {
            double x = (ancho * i) / (n - 1);

            /* La escala es 0..100 fija y no el mínimo-máximo de la serie: una
               escala que se ajusta sola haría ver un paso de 2% a 5% igual de
               dramático que uno de 10% a 90%. */
            double y = alto - (alto * (double)p.Serie[i].Porcentaje / 100.0);

            if (i > 0) linea.Append(' ');
            linea.Append(N(x) + "," + N(y));
            area.Append(N(x) + "," + N(y) + " ");
        }

        area.Append(N(ancho) + "," + N(alto));

        StringBuilder b = new StringBuilder();
        b.Append("<div class=\"sg-curva\">");
        b.Append("<div class=\"sg-curva-y\"><span>100%</span><span>50%</span><span>0%</span></div>");
        b.Append("<div class=\"sg-curva-plot\">");
        b.Append("<svg viewBox=\"0 0 " + N(ancho) + " " + N(alto) + "\" preserveAspectRatio=\"none\" " +
                 "class=\"sg-curva-svg\" aria-hidden=\"true\">");
        b.Append("<polygon points=\"" + area + "\" fill=\"rgba(230,57,70,.12)\" />");
        b.Append("<polyline points=\"" + linea + "\" fill=\"none\" " +
                 "stroke=\"var(--sg-danger, #E63946)\" stroke-width=\"2\" " +
                 "stroke-linejoin=\"round\" stroke-linecap=\"round\" " +
                 "vector-effect=\"non-scaling-stroke\" />");
        b.Append("</svg>");

        /* Las etiquetas salen de las corridas reales y no de un "-7d" escrito
           a mano: si el modelo se saltó un día, el eje lo dice. */
        b.Append("<div class=\"sg-curva-x\">");

        for (int i = 0; i < n; i++)
        {
            int atras = n - 1 - i;

            /* Una de cada dos para que no se amontonen, y siempre la de hoy,
               que es la que se busca primero. */
            if (atras != 0 && atras % 2 != 0)
            {
                b.Append("<span></span>");
                continue;
            }

            b.Append("<span>" + (atras == 0 ? "Hoy" : "-" + atras + "d") + "</span>");
        }

        b.Append("</div></div></div>");

        return b.ToString();
    }

    /// <summary>Un número para el SVG: punto decimal siempre, sin locale.</summary>
    private static string N(double v)
    {
        return v.ToString("0.##", CultureInfo.InvariantCulture);
    }

    /// <summary>
    /// El paso de la predicción al encargo.
    ///
    /// Tres casos y ninguno inventado: ya hay OT y se muestra cuál; se puede
    /// generar y aparece el botón; no se tiene la función y no aparece nada.
    /// Un botón que no hace nada es peor que no tenerlo.
    /// </summary>
    private void CargarOrdenTrabajo(AlertaPrediccion p)
    {
        btnGenerarOt.Visible = false;
        litOrdenTrabajo.Text = "";

        if (p.ORDEN_TRABAJO != null)
        {
            string numero = p.ORDEN_CORRELATIVO != null
                ? p.ORDEN_CORRELATIVO.Value.ToString()
                : p.ORDEN_TRABAJO.Value.ToString();

            litOrdenTrabajo.Text =
                "<span class=\"sg-ai-ot-hecha\"><i class=\"mdi mdi-clipboard-check-outline\"></i>" +
                "<span>Orden de trabajo N° " + numero + " generada</span></span>";
            return;
        }

        /* El permiso se resuelve por consulta —Menu_Funcion contra el perfil—
           y no por una lista de cargos escrita en el código. */
        btnGenerarOt.Visible = Token.PuedeFuncion("Generar orden de trabajo");
    }

    /// <summary>
    /// Genera la orden y deja la alerta en gestión. El SP hace las dos cosas
    /// en una transacción y no crea una segunda si ya existía.
    /// </summary>
    protected void btnGenerarOt_Click(object sender, EventArgs e)
    {
        if (AlertaId == 0) return;

        Respuesta r = new AlertaController().GenerarOrdenTrabajo(AlertaId);

        if (r.error)
        {
            Tools.tools.ClientAlert(r.detalle, "alerta");
            return;
        }

        /* Generar la orden dejó la alerta EN GESTIÓN, así que el resumen y la
           lista que quedaron en memoria ya no valen: sin botarlos, los
           contadores seguirían mostrando lo de antes de apretar el botón. */
        _resumen = null;
        _lista = null;

        Tools.tools.ClientAlert(r.detalle, "ok");
    }

    /// <summary>
    /// La acción recomendada. Sale del modelo cuando existe; si no, del tipo
    /// de alerta, que es una regla del negocio y no una invención.
    /// </summary>
    protected void CargarRecomendacion(Alerta a)
    {
        string texto = Recomendacion(a.alt_codigo);

        pnlRecomendacion.Visible = !string.IsNullOrEmpty(texto);
        litRecomendacion.Text = Server.HtmlEncode(texto);
    }

    protected string Recomendacion(string tipo)
    {
        switch (tipo)
        {
            case "STOCK MINIMO":
                return "Revisar la existencia y registrar el ingreso que falta antes de que un trabajo se detenga por esta pieza.";
            case "STOCK MAXIMO":
                return "Revisar la existencia y evaluar un traslado a otra bodega o un ajuste.";
            case "LOTE VENCIDO":
                return "Retirar el lote vencido de la estantería y registrar el ajuste con su motivo.";
            case "LOTE POR VENCER":
                return "Priorizar el consumo de este lote antes de su vencimiento.";
            case "PERMISO VENCIDO":
                return "Adjuntar el permiso vigente antes de autorizar trabajo del contratista.";
            case "MEDIDOR SIN LECTURA":
                return "Registrar o solicitar la lectura pendiente: sin ella el plan por horas no avanza.";
            case "MEDIDOR PROXIMO MANTENIMIENTO":
                return "Programar la mantención antes de que el medidor alcance el valor objetivo.";
            case "MEDICION FUERA RANGO":
                return "Revisar la medición en terreno y confirmar si el valor es real o de instrumento.";
            case "HALLAZGO CRITICO":
                return "Revisar el checklist y decidir si el hallazgo requiere una orden de trabajo.";
            case "OCURRENCIA VENCIDA":
                return "Reprogramar la ocurrencia o asignarla, indicando el motivo del atraso.";
            case "DESCUBRIMIENTO TERRENO":
                return "Revisar el registro creado en terreno y completarlo o recodificarlo.";
            case "PREDICCION RIESGO":
                return "Revisar el análisis y decidir la intervención dentro del horizonte estimado.";
        }

        return "";
    }

    protected void CargarLinea(Alerta a)
    {
        List<AlertaHito> hitos = new AlertaController().GetHistorial(a.ale_id);

        StringBuilder sb = new StringBuilder();

        foreach (AlertaHito h in hitos)
        {
            sb.Append("<div class=\"sg-hito\">");
            sb.Append("<span class=\"sg-hito-punto\"></span>");
            sb.Append("<span class=\"sg-hito-cuerpo\">");
            sb.Append("<span class=\"sg-hito-estado\">" + Server.HtmlEncode(h.EstadoHasta) + "</span>");
            sb.Append("<span class=\"sg-hito-meta\">" +
                      h.Fecha.ToLocalTime().ToString("dd-MM-yyyy HH:mm"));

            if (!string.IsNullOrEmpty(h.Usuario))
                sb.Append(" · " + Server.HtmlEncode(h.Usuario));

            sb.Append("</span>");

            if (!string.IsNullOrEmpty(h.Motivo))
                sb.Append("<span class=\"sg-hito-motivo\">" + Server.HtmlEncode(h.Motivo) + "</span>");

            sb.Append("</span></div>");
        }

        litLinea.Text = sb.ToString();
    }

    /// <summary>
    /// Qué acciones se ven, según el estado de la alerta.
    ///
    /// Los botones están DECLARADOS en el marcado y acá solo se muestran o se
    /// esconden. Antes se creaban acá con new LinkButton() y se agregaban a un
    /// PlaceHolder: se dibujaban bien, pero en el postback todavía no existían
    /// cuando ASP.NET reparte los eventos, así que ninguno hacía nada. Es el
    /// error de ciclo de vida más común de WebForms y no da ningún mensaje.
    ///
    /// No se dibuja ningún botón sin función real: "Generar OT predictiva" no
    /// aparece porque crear órdenes es HU-110, del Sprint 5. Un botón que no
    /// hace nada enseña a desconfiar de los que sí hacen.
    /// </summary>
    protected void CargarAcciones(Alerta a)
    {
        btnTomar.Visible = a.PuedeReconocer;
        btnGestionar.Visible = a.PuedeGestionar;
        btnAsignar.Visible = a.PuedeCerrar;
        btnResolver.Visible = a.PuedeCerrar;
        btnDescartar.Visible = a.PuedeCerrar;

        /* Abrir el registro relacionado. Solo cuando el tipo declara una
           ficha y hay id: llevar al listado sería avisar y después hacer
           buscar, que es la mitad del trabajo. */
        bool hayFicha = !string.IsNullOrEmpty(a.FICHA_LINK) && a.FICHA_ID != null && a.FICHA_ID > 0;

        lnkOrigen.Visible = hayFicha;

        if (hayFicha)
        {
            string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + a.FICHA_ID.Value));
            string menu = string.IsNullOrEmpty(a.alt_menu_link) ? "" : ResolveUrl(a.alt_menu_link);

            lnkOrigen.Attributes["onclick"] = "return abrirFicha('" + ResolveUrl(a.FICHA_LINK) +
                                              "', '" + query + "', " + a.ale_id + ", '" + menu + "');";
        }
    }

    /// <summary>
    /// El combo de responsables. Solo la gente de este cliente: asignarle una
    /// alerta a alguien de otra empresa la dejaría en un limbo donde esa
    /// persona ni siquiera puede verla. El SP lo vuelve a comprobar.
    /// </summary>
    protected void CargarResponsables(Alerta a)
    {
        pnlAsignar.Visible = MostrarAsignar;

        if (!MostrarAsignar || cboResponsable.Items.Count > 0) return;

        cboResponsable.Items.Clear();
        cboResponsable.Items.Add(new RadComboBoxItem("(elija a quién)", ""));

        try
        {
            ClienteUsuarioController controller = new ClienteUsuarioController();

            ClienteUsuario filtro = new ClienteUsuario();

            /* EL CLIENTE ES OBLIGATORIO. SEL_CLIENTE_USUARIO filtra por él y
               sin asignarlo viajaba un cero: el combo salía vacío y no había
               ningún error que lo explicara. */
            filtro.ucl_id_cliente = SitioBase.Session.ClienteId();
            filtro.usu_habilitado = true;

            /* Cadenas vacías y no null: el controlador decide si manda cada
               parámetro con `if (campo != "")`, y un null pasa esa prueba y
               termina enviando el filtro en nulo, que no devuelve nada. */
            filtro.id_perfiles = "";
            filtro.filtro = "";

            List<ClienteUsuario> usuarios = controller.GetClienteUsuarios(filtro);

            if (usuarios != null)
            {
                foreach (ClienteUsuario u in usuarios)
                {
                    string nombre = !string.IsNullOrEmpty(u.nombre_completo)
                                  ? u.nombre_completo.Trim()
                                  : (u.usu_nombres + " " + u.usu_apellido_paterno).Trim();

                    /* El perfil junto al nombre: en una planta hay dos
                       Gonzalez y lo que decide a quién se le asigna es si es
                       bodeguero o técnico, no el apellido. */
                    if (!string.IsNullOrEmpty(u.perfiles))
                        nombre += "  ·  " + u.perfiles;

                    cboResponsable.Items.Add(new RadComboBoxItem(nombre, u.usu_id.ToString()));
                }
            }

            if (cboResponsable.Items.Count == 1)
                cboResponsable.Items[0].Text = "(este cliente no tiene usuarios habilitados)";
        }
        catch (Exception)
        {
            /* Sin la lista el combo queda con su opción vacía y el SP rechaza
               el guardado con un mensaje claro. Tumbar la pantalla entera por
               un desplegable sería desproporcionado. */
        }
    }

    protected void CargarCierre()
    {
        pnlCierre.Visible = !string.IsNullOrEmpty(ModoCierre);

        if (!pnlCierre.Visible) return;

        litCierreRotulo.Text = ModoCierre == "DESCARTADA"
            ? "¿Por qué se descarta? El motivo es obligatorio."
            : "¿Qué se hizo para resolverla?";
    }

    #endregion

    #region Acciones

    protected void Tomar_Click(object sender, EventArgs e) { Mover("RECONOCIDA", null); }
    protected void Gestionar_Click(object sender, EventArgs e) { Mover("EN GESTION", null); }

    protected void Resolver_Click(object sender, EventArgs e)
    {
        MostrarAsignar = false;
        ModoCierre = "RESUELTA";
        txtMotivo.Text = "";
    }

    protected void Descartar_Click(object sender, EventArgs e)
    {
        MostrarAsignar = false;
        ModoCierre = "DESCARTADA";
        txtMotivo.Text = "";
    }

    protected void Asignar_Click(object sender, EventArgs e)
    {
        MostrarAsignar = true;
        ModoCierre = "";
    }

    protected void btnAsignarCancelar_Click(object sender, EventArgs e)
    {
        MostrarAsignar = false;
    }

    protected void btnAsignarConfirmar_Click(object sender, EventArgs e)
    {
        if (AlertaId == 0) return;

        int responsable;

        if (!int.TryParse(cboResponsable.SelectedValue, out responsable) || responsable <= 0)
        {
            Tools.tools.ClientAlert("Elija a quién se le asigna.", "alerta");
            return;
        }

        Respuesta r = new AlertaController().AsignarResponsable(AlertaId, responsable);

        if (r.error)
        {
            Tools.tools.ClientAlert(r.detalle, "alerta");
            return;
        }

        MostrarAsignar = false;

        _resumen = null;
        _lista = null;

        Tools.tools.ClientAlert(r.detalle, "ok");
    }

    protected void lnkCierreCancelar_Click(object sender, EventArgs e)
    {
        ModoCierre = "";
        txtMotivo.Text = "";
    }

    protected void lnkCierreConfirmar_Click(object sender, EventArgs e)
    {
        string motivo = txtMotivo.Text.Trim();

        /* Se valida acá y otra vez en el SP. Lo de acá es cortesía —decirlo
           antes del viaje—; lo del servidor es lo que de verdad impide
           cerrar una alerta sin dejar constancia. */
        if (ModoCierre == "DESCARTADA" && motivo.Length < 5)
        {
            Tools.tools.ClientAlert("Indique el motivo del descarte.", "alerta");
            return;
        }

        Mover(ModoCierre, motivo);
    }

    protected void Mover(string estado, string motivo)
    {
        if (AlertaId == 0) return;

        Respuesta r = new AlertaController().CambiarEstado(AlertaId, estado, motivo);

        if (r.error)
        {
            Tools.tools.ClientAlert(r.detalle, "alerta");
            return;
        }

        ModoCierre = "";
        MostrarAsignar = false;
        txtMotivo.Text = "";

        _resumen = null;
        _lista = null;

        Tools.tools.ClientAlert(r.detalle, "ok");
    }

    protected void Tab_Command(object sender, CommandEventArgs e)
    {
        Tab = e.CommandArgument.ToString();
        ModoCierre = "";
        MostrarAsignar = false;

        _lista = null;
    }

    protected void Filtro_Changed(object sender, EventArgs e)
    {
        _lista = null;
    }

    /// <summary>
    /// El SelectedIndexChanged de RadComboBox trae su propio tipo de
    /// argumentos: no se puede reusar el manejador del cuadro de texto.
    /// </summary>
    protected void Combo_Changed(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        _lista = null;
    }

    /// <summary>
    /// Vuelve a revisar los umbrales. Existe porque hoy nadie dispara el
    /// detector solo: sin este botón la lista muestra lo que se detectó la
    /// última vez que alguien lo corrió, y no hay forma de saberlo.
    /// </summary>
    protected void lnkRevisar_Click(object sender, EventArgs e)
    {
        new AlertaController().Detectar(true);

        _resumen = null;
        _lista = null;

        Tools.tools.ClientAlert("Revisión hecha.", "ok");
    }

    #endregion

    protected string ClaseSeveridad(string codigo)
    {
        switch (codigo)
        {
            case "CRITICA": return "is-critica";
            case "ALTA": return "is-alta";
            case "ADVERTENCIA": return "is-advertencia";
            case "BAJA": return "is-baja";
        }

        return "is-normal";
    }
}
