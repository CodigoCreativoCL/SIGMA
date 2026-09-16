using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web.Script.Serialization;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// La serie historica de una variable de condicion (HU-045): grafico con la
/// banda de valores normales y los puntos fuera de umbral destacados (#1), y
/// el origen de cada dato al tocarlo (#2).
///
/// El acceso lo resuelve el master con Token.ExigirPagina(); el veredicto de
/// cada punto contra los umbrales lo trae SEL_ACTIVO_MEDICION_SERIE, que es
/// la misma regla con que la app lo registro. Aqui no se recalcula nada.
/// </summary>
public partial class View_Activos_Variables_ActivoVariableSerie : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (Request.QueryString["query"] != null)
                Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");

            Grid.AddColumn("FECHA", "CUÁNDO", Width: "16%", DataFormat: "{0:dd-MM-yyyy HH:mm}");
            Grid.AddTemplateColumn("VALOR_", "", "VALOR", Width: "12%");
            Grid.AddTemplateColumn("NIVEL_", "", "NIVEL", Width: "14%");
            Grid.AddColumn("ORIGEN", "ORIGEN", Width: "14%");
            Grid.AddColumn("ENTRADA", "ENTRADA", Width: "8%");
            Grid.AddTemplateColumn("REFERENCIA", "", "OT / CHECKLIST", Width: "14%");
            Grid.AddColumn("USUARIO_NOMBRE", "QUIÉN", Width: "14%");
            Grid.AddColumn("CALIDAD", "CALIDAD", Width: "8%");

            /* Por defecto, los ultimos 90 dias en hora de Santiago. */
            calHasta.Value = global::SitioBase.Hora.Hoy;
            calDesde.Value = global::SitioBase.Hora.Hoy.AddDays(-90);
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        Cargar();
        udPanel.Update();
    }

    protected void btnAplicar_Click(object sender, EventArgs e)
    {
        // Cargar() corre en PreRender con las fechas nuevas.
    }

    /// <summary>
    /// Las fechas del filtro se eligen en hora de Santiago y la base guarda
    /// UTC: se convierten antes de preguntar. Hasta incluye el dia entero.
    /// </summary>
    private void Rango(out DateTime? desdeUtc, out DateTime? hastaUtc)
    {
        TimeZoneInfo zona;
        try { zona = TimeZoneInfo.FindSystemTimeZoneById("Pacific SA Standard Time"); }
        catch (Exception) { zona = TimeZoneInfo.Local; }

        desdeUtc = calDesde.Value == null ? (DateTime?)null
            : TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(calDesde.Value.Value.Date, DateTimeKind.Unspecified), zona);
        hastaUtc = calHasta.Value == null ? (DateTime?)null
            : TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(calHasta.Value.Value.Date.AddDays(1).AddSeconds(-1), DateTimeKind.Unspecified), zona);
    }

    protected void Cargar()
    {
        ActivoVariableController controller = new ActivoVariableController();
        ActivoVariable v = Id > 0 ? controller.GetVariable(Id) : null;

        if (v == null || v.ava_id == 0)
        {
            pnlSinVariable.Visible = true;
            pnlSerie.Visible = false;
            return;
        }

        litTitulo.Text = Server.HtmlEncode(v.variable_nombre) + " · " + Server.HtmlEncode(v.activo_codigo);
        litEquipo.Text = Server.HtmlEncode(v.activo_codigo + " · " + v.activo_nombre)
                       + (string.IsNullOrEmpty(v.componente_nombre) ? "" : " <span style=\"color:#6b7280\">· " + Server.HtmlEncode(v.componente_nombre) + "</span>");
        litVariable.Text = Server.HtmlEncode(v.variable_nombre);
        litUnidad.Text = Server.HtmlEncode(v.unidad_simbolo ?? v.unidad_nombre ?? "");
        litUmbrales.Text = Umbral("mín", v.ava_valor_minimo, "is-neutro") + Umbral("adv", v.ava_valor_advertencia, "is-advertencia")
                         + Umbral("crít", v.ava_valor_critico, "is-alerta") + Umbral("máx", v.ava_valor_maximo, "is-neutro");

        DateTime? desde, hasta;
        Rango(out desde, out hasta);

        List<MedicionSerie> puntos = controller.GetSerie(Id, desde, hasta) ?? new List<MedicionSerie>();
        MedicionSerieResumen r = controller.GetSerieResumen(Id, desde, hasta);

        litResumen.Text =
            Kpi(r.puntos.ToString(), "mediciones en el rango", "") +
            Kpi(r.criticos.ToString(), "críticas", r.criticos > 0 ? "is-alerta" : "") +
            Kpi(r.advertencias.ToString(), "en advertencia", r.advertencias > 0 ? "is-advertencia" : "") +
            Kpi(r.fuera_rango.ToString(), "fuera del rango operativo", r.fuera_rango > 0 ? "is-advertencia" : "") +
            Kpi(r.ultimo_valor == null ? "—" : Num(r.ultimo_valor.Value) + " " + (v.unidad_simbolo ?? ""),
                r.ultima_fecha_utc == null ? "último valor" : "último valor · " + Local(r.ultima_fecha_utc.Value).ToString("dd-MM-yyyy HH:mm"), "") +
            Kpi(r.promedio == null ? "—" : Num(r.promedio.Value) + " " + (v.unidad_simbolo ?? ""), "promedio del rango", "");

        Grid.DataSource = puntos;
        Grid.DataBind();

        litDatos.Text = "<script type=\"text/javascript\">window.sgSerie = " + Json(v, puntos) + ";</script>";
    }

    private static DateTime Local(DateTime utc)
    {
        try
        {
            TimeZoneInfo zona = TimeZoneInfo.FindSystemTimeZoneById("Pacific SA Standard Time");
            return TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utc, DateTimeKind.Utc), zona);
        }
        catch (Exception) { return utc.ToLocalTime(); }
    }

    private static string Num(decimal d) { return d.ToString("0.##", CultureInfo.GetCultureInfo("es-CL")); }

    private static string Umbral(string etiqueta, decimal? valor, string clase)
    {
        if (valor == null) return "";
        return "<span class=\"grid-estado-chip " + clase + "\">" + etiqueta + " " + Num(valor.Value) + "</span>";
    }

    private static string Kpi(string n, string t, string clase)
    {
        return "<div class=\"sg-serie-kpi " + clase + "\"><div class=\"n\">" + n + "</div><div class=\"t\">" + t + "</div></div>";
    }

    private static string NivelTexto(string nivel)
    {
        switch (nivel)
        {
            case "CRITICO": return "Crítico";
            case "ADVERTENCIA": return "Advertencia";
            case "FUERA_RANGO": return "Fuera de rango";
            default: return "Normal";
        }
    }

    private static string NivelClase(string nivel)
    {
        switch (nivel)
        {
            case "CRITICO": return "is-alerta";
            case "ADVERTENCIA": return "is-advertencia";
            case "FUERA_RANGO": return "is-advertencia";
            default: return "is-exito";
        }
    }

    /// <summary>
    /// Lo que el grafico necesita, como JSON: los umbrales de la variable y
    /// un punto por medicion con su nivel y su origen ya redactados. Los
    /// numeros van con punto decimal (invariante) porque los lee JavaScript.
    /// </summary>
    private string Json(ActivoVariable v, List<MedicionSerie> puntos)
    {
        List<object> lista = new List<object>();
        foreach (MedicionSerie p in puntos)
        {
            lista.Add(new
            {
                t = (long)(DateTime.SpecifyKind(p.fecha, DateTimeKind.Unspecified) - new DateTime(1970, 1, 1)).TotalMilliseconds,
                v = (double)p.valor,
                vo = (double)p.valor_original,
                uo = p.unidad_original,
                n = p.nivel,
                nivelTexto = NivelTexto(p.nivel),
                chip = NivelClase(p.nivel),
                fecha = p.fecha.ToString("dd-MM-yyyy HH:mm"),
                origen = p.origen,
                entrada = p.entrada,
                ot = p.ot_correlativo,
                checklist = p.checklist_ejecucion,
                quien = p.usuario_nombre,
                calidad = p.calidad,
                obs = p.observacion
            });
        }

        object o = new
        {
            variable = new
            {
                nombre = v.variable_nombre,
                unidad = v.unidad_simbolo ?? "",
                minimo = v.ava_valor_minimo == null ? (double?)null : (double)v.ava_valor_minimo.Value,
                maximo = v.ava_valor_maximo == null ? (double?)null : (double)v.ava_valor_maximo.Value,
                advertencia = v.ava_valor_advertencia == null ? (double?)null : (double)v.ava_valor_advertencia.Value,
                critico = v.ava_valor_critico == null ? (double?)null : (double)v.ava_valor_critico.Value
            },
            puntos = lista
        };

        return new JavaScriptSerializer().Serialize(o);
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        MedicionSerie p = item.DataItem as MedicionSerie;
        if (p == null) return;

        item.Attributes["data-punto"] = item.ItemIndex.ToString();
        item.Attributes["onclick"] = "sgMostrarPunto(" + item.ItemIndex + ");";
        item.Style["cursor"] = "pointer";

        string valor = "<strong>" + Num(p.valor) + "</strong>";
        if (p.valor_original != p.valor)
            valor += " <span style=\"color:#6b7280\">(" + Num(p.valor_original) + " " + Server.HtmlEncode(p.unidad_original) + ")</span>";
        item["VALOR_"].Controls.Add(new Literal { Text = valor });

        item["NIVEL_"].Controls.Add(new Literal
        {
            Text = "<span class=\"grid-estado-chip " + NivelClase(p.nivel) + "\">" + NivelTexto(p.nivel) + "</span>"
        });

        string referencia = "";
        if (p.ot_correlativo != null) referencia += "OT-" + p.ot_correlativo;
        if (p.checklist_ejecucion != null) referencia += (referencia.Length > 0 ? " · " : "") + "Checklist #" + p.checklist_ejecucion;
        if (referencia.Length == 0) referencia = "<span class=\"sigma-inv-vacio\">—</span>";
        item["REFERENCIA"].Controls.Add(new Literal { Text = referencia });
    }
}
