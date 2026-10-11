using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Web;

/// <summary>
/// HU-125 · La orden de trabajo en papel. La arma el servidor con los mismos SP que la ficha
/// (SEL_ORDEN_TRABAJO, pasos, repuestos, mano de obra, servicios y firmas) más el encabezado del
/// cliente (SEL_ORDEN_TRABAJO_IMPRIMIR). Si la OT está cerrada, agrega el resultado, el motivo de
/// cierre y las firmas registradas; si no, deja los espacios de firma en blanco.
///
/// SEGURIDAD EN EL SERVIDOR: sesión válida y permiso «VER ORDENES TRABAJO»; la OT se pide con el
/// cliente de la sesión, así que un id de otro cliente no devuelve nada.
/// </summary>
public partial class View_Mantenimiento_Ordenes_OrdenTrabajoImprimir : System.Web.UI.Page
{
    private const string P_VER = "VER ORDENES TRABAJO";
    private static readonly CultureInfo CL = new CultureInfo("es-CL");

    public string Titulo { get; private set; }
    public string Cuerpo { get; private set; }
    public string Falla { get; private set; }

    protected void Page_Load(object sender, EventArgs e)
    {
        Titulo = "Orden de trabajo";
        if (!Token.TokenSeguridad()) { Response.Redirect(ResolveUrl("~/Login.aspx"), true); return; }
        try
        {
            if (!Token.Puede(P_VER)) throw new Exception("Tu perfil no tiene permiso para ver órdenes de trabajo.");
            int id = IdDe(Request.QueryString["query"]);
            int cli = SitioBase.Session.ClienteId();
            List<Dictionary<string, object>> cab = SoporteDatos.Filas("SEL_ORDEN_TRABAJO", "@ID", id, "@CLIENTE", cli);
            if (cab.Count == 0) throw new Exception("La orden de trabajo no existe.");
            Dictionary<string, object> ot = cab[0];
            Dictionary<string, object> cl = SoporteDatos.Filas("SEL_ORDEN_TRABAJO_IMPRIMIR", "@CLIENTE", cli, "@ID", id).FirstOrDefault();
            Titulo = "OT-" + T(ot, "otr_correlativo") + " · " + T(ot, "otr_titulo");
            Cuerpo = Armar(id, cli, ot, cl);
        }
        catch (Exception ex)
        {
            Falla = ex.Message;
        }
    }

    private string Armar(int id, int cli, Dictionary<string, object> ot, Dictionary<string, object> cl)
    {
        bool cerrada = N(ot, "otr_orden_trabajo_estado") == 4;
        StringBuilder s = new StringBuilder();

        // Encabezado del cliente
        int logo = (int)N(cl, "CLIENTE_LOGO");
        s.Append("<header class=\"cab\">");
        if (logo > 0) s.Append("<img src=\"" + H(SitioBase.UrlArchivo.Ver(logo)) + "\" alt=\"\">");
        s.Append("<div class=\"cli\"><b>" + H(T(cl, "CLIENTE_RAZON_SOCIAL")) + "</b><small>" + H(T(cl, "CLIENTE_RUT")) + (T(ot, "PLANTA_NOMBRE").Length > 0 ? " · " + H(T(ot, "PLANTA_NOMBRE")) : "") + "</small></div>");
        s.Append("<div class=\"ot\"><small>Orden de trabajo</small><b>OT-" + H(T(ot, "otr_correlativo")) + "</b><span class=\"chip" + (cerrada ? " ok" : "") + "\">" + H(T(ot, "ESTADO_NOMBRE")) + "</span></div></header>");

        // Datos de la orden
        s.Append("<h1>" + H(T(ot, "otr_titulo")) + "</h1>");
        s.Append("<div class=\"grid\">");
        Dato(s, "Activo", T(ot, "ACTIVO_CODIGO") + " · " + T(ot, "ACTIVO_NOMBRE") + (T(ot, "COMPONENTE_NOMBRE").Length > 0 ? " › " + T(ot, "COMPONENTE_NOMBRE") : ""));
        Dato(s, "Área", T(ot, "AREA_NOMBRE"));
        Dato(s, "Tipo", T(ot, "TIPO_NOMBRE"));
        Dato(s, "Prioridad", T(ot, "PRIORIDAD_NOMBRE"));
        Dato(s, "Responsable", T(ot, "RESPONSABLE_NOMBRE").Length > 0 ? T(ot, "RESPONSABLE_NOMBRE") : T(ot, "RESPONSABLE_PROVEEDOR"));
        Dato(s, "Programada", F(ot, "otr_fecha_programada_utc"));
        Dato(s, "Duración estimada", Horas(N(ot, "otr_duracion_estimada_minuto")));
        Dato(s, "Origen", T(ot, "ORIGEN_NOMBRE") + (T(ot, "PLAN_CODIGO").Length > 0 ? " · " + T(ot, "PLAN_CODIGO") : ""));
        s.Append("</div>");
        if (T(ot, "otr_descripcion").Length > 0) s.Append("<h2>Qué hay que hacer</h2><div class=\"texto\">" + H(T(ot, "otr_descripcion")) + "</div>");

        // Pasos
        List<Dictionary<string, object>> pasos = SoporteDatos.Filas("SEL_ORDEN_TRABAJO_PASO", "@CLIENTE", cli, "@ORDEN", id);
        s.Append("<h2>Pasos</h2>");
        if (pasos.Count == 0) s.Append("<p class=\"vacio\">Sin pasos.</p>");
        else
        {
            s.Append("<table><tr><th style=\"width:24px\">#</th><th>Paso</th><th style=\"width:110px\">Resultado</th><th style=\"width:120px\">Ejecutó</th></tr>");
            int k = 0;
            foreach (Dictionary<string, object> p in pasos)
            {
                int r = (int)N(p, "otp_resultado_paso");
                string res = r == 1 ? "Conforme" : r == 2 ? "No conforme" : r == 3 ? "No aplica" : "☐ Pendiente";
                s.Append("<tr><td>" + (++k) + "</td><td><b>" + H(T(p, "otp_nombre")) + "</b>" + (T(p, "otp_descripcion").Length > 0 ? "<br><small>" + H(T(p, "otp_descripcion")) + "</small>" : "") + (T(p, "otp_resultado").Length > 0 ? "<br><small>" + H(T(p, "otp_resultado")) + "</small>" : "") + "</td><td>" + res + "</td><td>" + H(r == 4 ? "" : T(p, "EJECUTOR_NOMBRE")) + "</td></tr>");
            }
            s.Append("</table>");
        }

        // Repuestos
        List<Dictionary<string, object>> reps = SoporteDatos.Filas("SEL_ORDEN_TRABAJO_REPUESTO", "@CLIENTE", cli, "@ORDEN", id);
        s.Append("<h2>Repuestos</h2>");
        if (reps.Count == 0) s.Append("<p class=\"vacio\">Sin repuestos.</p>");
        else
        {
            s.Append("<table><tr><th>Código</th><th>Repuesto</th><th class=\"n\">Planificada</th><th class=\"n\">Consumida</th><th class=\"n\">Devuelta</th></tr>");
            foreach (Dictionary<string, object> r in reps)
                s.Append("<tr><td>" + H(T(r, "REPUESTO_CODIGO")) + "</td><td>" + H(T(r, "REPUESTO_NOMBRE")) + (T(r, "LOTE").Length > 0 ? "<br><small>Lote " + H(T(r, "LOTE")) + "</small>" : "") + "</td><td class=\"n\">" + Num(N(r, "PLANIFICADA")) + " " + H(T(r, "UNIDAD")) + "</td><td class=\"n\">" + Num(N(r, "CONSUMIDA")) + "</td><td class=\"n\">" + Num(N(r, "DEVUELTA")) + "</td></tr>");
            s.Append("</table>");
        }

        // Mano de obra
        List<Dictionary<string, object>> mo = SoporteDatos.Filas("SEL_ORDEN_TRABAJO_MANO_OBRA", "@CLIENTE", cli, "@ORDEN", id);
        s.Append("<h2>Mano de obra</h2>");
        if (mo.Count == 0) s.Append("<p class=\"vacio\">Sin horas registradas.</p>");
        else
        {
            s.Append("<table><tr><th>Quién</th><th>Especialidad</th><th>Inicio</th><th class=\"n\">Horas</th><th class=\"n\">Costo</th></tr>");
            foreach (Dictionary<string, object> m in mo)
                s.Append("<tr><td>" + H(T(m, "USUARIO_NOMBRE").Length > 0 ? T(m, "USUARIO_NOMBRE") : T(m, "PROVEEDOR_NOMBRE")) + "</td><td>" + H(T(m, "ESPECIALIDAD")) + "</td><td>" + F(m, "omo_fecha_inicio_utc") + "</td><td class=\"n\">" + Num(N(m, "MINUTOS") / 60m, 1) + "</td><td class=\"n\">" + (Valor(m, "COSTO") == null ? "—" : H(T(m, "MONEDA")) + " " + Num(N(m, "COSTO"))) + "</td></tr>");
            s.Append("</table>");
        }

        // Servicios de terceros (HU-117): total separado por moneda
        List<Dictionary<string, object>> sv = SoporteDatos.Filas("SEL_ORDEN_TRABAJO_SERVICIO", "@CLIENTE", cli, "@ORDEN", id);
        s.Append("<h2>Servicios contratados</h2>");
        if (sv.Count == 0) s.Append("<p class=\"vacio\">Sin servicios de terceros.</p>");
        else
        {
            s.Append("<table><tr><th>Proveedor</th><th>Servicio</th><th>Documento</th><th class=\"n\">Monto</th></tr>");
            foreach (Dictionary<string, object> x in sv)
                s.Append("<tr><td>" + H(T(x, "PROVEEDOR_NOMBRE")) + "</td><td><b>" + H(T(x, "TIPO")) + "</b><br><small>" + H(T(x, "DESCRIPCION")) + "</small></td><td>" + H(T(x, "DOCUMENTO")) + (Valor(x, "INFORME_ID") == null ? "" : "<br><small>Con informe</small>") + "</td><td class=\"n\">" + H(T(x, "MONEDA")) + " " + Num(N(x, "COSTO"), T(x, "MONEDA") == "UF" ? 2 : 0) + "</td></tr>");
            s.Append("</table><div class=\"tot\">");
            foreach (Dictionary<string, object> t in SoporteDatos.Filas("SEL_OT_SERVICIO_TOTAL", "@CLIENTE", cli, "@ORDEN", id))
                s.Append("<b>Total " + H(T(t, "MONEDA")) + " " + Num(N(t, "TOTAL"), T(t, "MONEDA") == "UF" ? 2 : 0) + "</b>");
            s.Append("</div>");
        }

        // Cierre
        s.Append("<h2>Cierre</h2>");
        if (cerrada)
        {
            s.Append("<div class=\"grid\">");
            Dato(s, "Motivo de cierre", T(ot, "CIERRE_MOTIVO_NOMBRE"));
            Dato(s, "Cerró", T(ot, "CIERRE_USUARIO_NOMBRE"));
            Dato(s, "Fecha de cierre", F(ot, "otr_fecha_cierre"));
            Dato(s, "Duración real", Horas(N(ot, "otr_duracion_real_minuto")));
            s.Append("</div><div class=\"texto\" style=\"margin-top:8px\">" + H(T(ot, "otr_resultado").Length > 0 ? T(ot, "otr_resultado") : "Sin resultado registrado.") + "</div>");
        }
        else s.Append("<div class=\"texto\" style=\"min-height:70px\"></div>");

        // Firmas: las registradas (OT cerrada o validada) y, si faltan, espacios en blanco
        s.Append("<h2>Firmas</h2><div class=\"firmas\">");
        List<OrdenTrabajoValidacion> fs = new OrdenTrabajoValidacionController().GetValidaciones(id) ?? new List<OrdenTrabajoValidacion>();
        int n = 0;
        foreach (OrdenTrabajoValidacion f in fs.Where(x => x.archivo_firma.HasValue || !string.IsNullOrEmpty(x.usuario_nombre)).Take(3))
        {
            n++;
            s.Append("<div class=\"firma\">" + (f.archivo_firma.HasValue ? "<img src=\"" + H(SitioBase.UrlArchivo.Ver(f.archivo_firma.Value)) + "\" alt=\"\">" : "<i></i>") +
                "<b>" + H(f.usuario_nombre) + "</b><small>" + H(f.tipo_nombre) + " · " + H(f.resultado) + " · " + f.fecha.ToString("dd-MM-yyyy HH:mm") + "</small></div>");
        }
        string[] blancos = { "Ejecutó", "Recibe conforme", "Aprueba el cierre" };
        for (int k = n; k < 3; k++) s.Append("<div class=\"firma\"><i></i><b>" + blancos[k] + "</b><small>Nombre, firma y fecha</small></div>");
        s.Append("</div>");

        s.Append("<div class=\"pie\"><span>SIGMA · " + H(T(cl, "CLIENTE_NOMBRE")) + "</span><span>Impreso el " + F(cl, "FECHA_IMPRESION") + "</span></div>");
        return s.ToString();
    }

    // ---------------------------------------------------------------------

    private static void Dato(StringBuilder s, string k, string v) { s.Append("<div><span>" + H(k) + "</span><b>" + H(string.IsNullOrWhiteSpace(v) ? "—" : v) + "</b></div>"); }
    public static string H(string v) { return HttpUtility.HtmlEncode(v ?? ""); }
    private static object Valor(Dictionary<string, object> d, string k)
    {
        if (d == null) return null;
        foreach (KeyValuePair<string, object> kv in d) if (string.Equals(kv.Key, k, StringComparison.OrdinalIgnoreCase)) return kv.Value == DBNull.Value ? null : kv.Value;
        return null;
    }
    private static string T(Dictionary<string, object> d, string k) { object v = Valor(d, k); return v == null ? "" : Convert.ToString(v, CL).Trim(); }
    private static decimal N(Dictionary<string, object> d, string k)
    {
        object v = Valor(d, k); decimal n;
        if (v == null) return 0;
        if (v is bool) return (bool)v ? 1 : 0;
        return decimal.TryParse(Convert.ToString(v, CultureInfo.InvariantCulture), NumberStyles.Any, CultureInfo.InvariantCulture, out n) ? n : 0;
    }
    private static string F(Dictionary<string, object> d, string k) { object v = Valor(d, k); return v is DateTime ? ((DateTime)v).ToString("dd-MM-yyyy HH:mm") : "—"; }
    private static string Num(decimal v, int dec = 0) { return v.ToString("N" + dec, CL); }
    private static string Horas(decimal min) { return min > 0 ? Num(min / 60m, 1) + " h" : "—"; }
    private static int IdDe(string token)
    {
        // El QueryString ya llega decodificado: decodificarlo otra vez convertiría el «+» del cifrado en espacio.
        string plano = Tools.Crypto.Decrypt(token ?? "");
        int id; if (!int.TryParse((plano ?? "").Split('=').Last(), out id)) throw new Exception("La orden de trabajo no existe.");
        return id;
    }
}
