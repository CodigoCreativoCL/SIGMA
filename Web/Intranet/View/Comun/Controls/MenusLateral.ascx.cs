using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web.UI;
using SitioBase.Controller;
using SitioBase.Model;

/// <summary>
/// Menu lateral (diseno «sidebar propuesto», 06-10-2026).
///
/// TODO SALE DE LA TABLA DE MENUS
///   Los grupos con titulo (Configuracion, Gestion, Operacion, Centro de Ayuda, Inteligencia), el nombre corto de una linea y
///   el contador de cada modulo viven en Menus.mnu_grupo / mnu_nombre_corto / mnu_contador (BD/378);
///   los permisos siguen siendo los de siempre. Nada del menu esta fijo en el HTML, salvo «Inicio»,
///   que no es una pantalla con permiso sino la puerta de entrada de todos.
///
///   - Una opcion con mnu_grupo se dibuja como modulo propio aunque cuelgue de otra (SIGMA Twin
///     sigue en Inventario para los permisos y se ve en Inteligencia).
///   - mnu_grupo = '~' la saca del sidebar (Alertas: vive en la campana).
///   - Un modulo con una sola pantalla visible lleva directo a ella, sin desplegable.
///   - Los contenedores (mnu_link = '#') solo se ven si alguno de sus hijos se ve.
///
/// QUE QUEDA PARA EL NAVEGADOR (Js/sigma-sidebar.js)
///   El acordeon recordado por persona, «Ir a…» (Ctrl K), los recientes, el boton de contraer y el
///   refresco de los contadores.
/// </summary>
public partial class View_Comun_Controls_MenusLateral : System.Web.UI.UserControl
{
    private MenusController menusController = new MenusController();

    private class Meta { public string Grupo, Corto, Contador; }
    private Dictionary<int, Meta> _meta = new Dictionary<int, Meta>();
    private Dictionary<string, int> _cont = new Dictionary<string, int>();
    private string _actual = "";

    /* Configuración (la de root) primero; Inteligencia al final. */
    private static readonly string[] GRUPOS = { "Configuración", "Gestión", "Operación", "Centro de Ayuda", "Inteligencia" };

    protected void Page_Load(object sender, EventArgs e)
    {
        CargarMenus();
    }

    private void CargarMeta()
    {
        try
        {
            foreach (Dictionary<string, object> f in SoporteDatos.Filas("SEL_MENUS_SIDEBAR"))
                _meta[Convert.ToInt32(f["ID"])] = new Meta
                {
                    Grupo = f["GRUPO"] as string,
                    Corto = f["CORTO"] as string,
                    Contador = f["CONTADOR"] as string
                };
        }
        catch (Exception) { /* sin las columnas el menu se arma igual, sin grupos ni contadores */ }

        try
        {
            Dictionary<string, object> c = SoporteDatos.Fila("SEL_MENU_CONTADORES", "@CLIENTE", SitioBase.Session.ClienteId(), "@USUARIO", SoporteDatos.Usuario());
            foreach (KeyValuePair<string, object> kv in c)
                _cont[kv.Key.ToLowerInvariant()] = kv.Value == null ? 0 : Convert.ToInt32(kv.Value);
        }
        catch (Exception) { }
    }

    private Meta MetaDe(int id)
    {
        Meta m;
        return _meta.TryGetValue(id, out m) ? m : new Meta();
    }

    /* El permiso de la pagina y, para las que dependen del plan (la ticketera de Soporte), que el plan del cliente las incluya. */
    private static bool Puede(Menus m)
    {
        return SitioBase.Token.PuedeMenu(m.mnu_id) && SitioBase.Controller.SoportePlan.PermiteMenu(m.mnu_link);
    }

    private static string Ico(string k, int n)
    {
        string d;
        switch (k)
        {
            case "search": d = "<circle cx=\"11\" cy=\"11\" r=\"7\"/><path d=\"M20 20l-3.5-3.5\"/>"; break;
            case "chev": d = "<path d=\"M9 6l6 6-6 6\"/>"; break;
            default: d = ""; break;
        }
        return "<svg class=\"ic\" style=\"width:" + n + "px;height:" + n + "px\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.9\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">" + d + "</svg>";
    }

    private bool EsActual(string link)
    {
        if (string.IsNullOrEmpty(link) || link == "#" || link.StartsWith("app://")) return false;
        string p = ResolveUrl(link).ToLowerInvariant();
        int q = p.IndexOf('?'); if (q >= 0) p = p.Substring(0, q);
        return _actual == p;
    }

    protected void CargarMenus()
    {
        CargarMeta();
        _actual = Request.Url.AbsolutePath.ToLowerInvariant();

        List<Menus> menus = menusController.GetMenus(new Menus());

        /* Los modulos: cada opcion de nivel 2, y cualquiera con grupo propio. Los de grupo «~» no van. */
        List<Menus> modulos = menus.Where(x => x.mnu_visible && (x.mnu_nivel == 2 || MetaDe(x.mnu_id).Grupo != null))
                                   .Where(x => MetaDe(x.mnu_id).Grupo != "~")
                                   .OrderBy(x => x.mnu_nivel == 2 ? 0 : 1).ThenBy(x => x.mnu_orden).ToList();

        StringBuilder sb = new StringBuilder();

        sb.Append("<button type=\"button\" class=\"nv-find\" data-sg-cmdk=\"1\" title=\"Ir a… (Ctrl K)\">" + Ico("search", 15) + "<span>Ir a…</span><kbd>Ctrl K</kbd></button>");

        string home = ResolveUrl("~/Default.aspx");
        bool enInicio = _actual == home.ToLowerInvariant() || _actual == ResolveUrl("~/").ToLowerInvariant();
        sb.Append("<div class=\"nv-li\"><a href=\"" + home + "\" class=\"nv-a" + (enInicio ? " on" : "") + "\" title=\"Inicio\"" + (enInicio ? " aria-current=\"page\"" : "") +
                  " data-sg-t=\"Inicio\"><i class=\"nv-ic\"><span class=\"mdi mdi-home-outline\"></span></i><span class=\"nv-n\">Inicio</span></a></div>");

        foreach (string grupo in GRUPOS)
        {
            string html = "";
            foreach (Menus m in modulos.Where(x => (MetaDe(x.mnu_id).Grupo ?? "Gestión") == grupo))
                html += Modulo(menus, m);
            if (html == "") continue;
            sb.Append("<div class=\"nav-t\">" + Server.HtmlEncode(grupo) + "</div>");
            sb.Append(html);
        }

        /* Los modulos con un grupo que no es ninguno de los cuatro conocidos van al final, sin titulo propio. */
        foreach (string otro in modulos.Select(x => MetaDe(x.mnu_id).Grupo).Where(g => g != null && !GRUPOS.Contains(g)).Distinct())
        {
            string html = "";
            foreach (Menus m in modulos.Where(x => MetaDe(x.mnu_id).Grupo == otro)) html += Modulo(menus, m);
            if (html != "") sb.Append("<div class=\"nav-t\">" + Server.HtmlEncode(otro) + "</div>" + html);
        }

        sb.Append("<div class=\"nav-t rec-t\" id=\"sgRecT\" hidden>Recientes</div><div class=\"rec\" id=\"sgRec\"></div>");

        LiteralControl lc = new LiteralControl();
        lc.Text = sb.ToString();
        phdMenus.Controls.Add(lc);
    }

    /// <summary>Un modulo del menu: desplegable con sus pantallas, o enlace directo si solo tiene una.</summary>
    private string Modulo(List<Menus> menus, Menus m)
    {
        Meta mt = MetaDe(m.mnu_id);
        string nombre = string.IsNullOrEmpty(mt.Corto) ? m.mnu_nombre : mt.Corto;
        string icono = IconoModulo(m);

        int hojas = 0; string unica = null; bool activo = false;
        string sub = m.mnu_link == "#" ? Hijos(menus, m.mnu_id, 0, nombre, m.mnu_icon, ref hojas, ref unica, ref activo) : "";

        bool directo;
        string href;
        if (m.mnu_link != "#")
        {
            if (!Puede(m)) return "";
            directo = true; href = ResolveUrl(m.mnu_link); activo = EsActual(m.mnu_link);
        }
        else
        {
            if (sub == "") return "";
            directo = hojas == 1 && unica != null;
            href = directo ? ResolveUrl(unica) : "#";
            if (directo) activo = EsActual(unica);
        }

        string badge = Contador(mt.Contador);
        string title = Server.HtmlEncode(m.mnu_nombre);
        StringBuilder sb = new StringBuilder();

        if (directo)
        {
            sb.Append("<div class=\"nv-li\"><a href=\"" + href + "\" class=\"nv-a" + (activo ? " on" : "") + "\" title=\"" + title + "\"" + (activo ? " aria-current=\"page\"" : "") +
                      " data-sg-t=\"" + Server.HtmlEncode(m.mnu_nombre) + "\" data-sg-i=\"" + Server.HtmlEncode(m.mnu_icon ?? "") + "\"" + AtrCont(mt.Contador) + ">" + icono + "<span class=\"nv-n\">" + Server.HtmlEncode(nombre) + "</span>" + badge + "</a></div>");
            return sb.ToString();
        }

        sb.Append("<div class=\"nv-li" + (activo ? " open has-on" : "") + "\" data-sg-key=\"m" + m.mnu_id + "\">");
        sb.Append("<a href=\"#\" role=\"button\" class=\"nv-a" + (activo ? " on" : "") + "\" data-sg-tog=\"m" + m.mnu_id + "\" aria-expanded=\"" + (activo ? "true" : "false") + "\" title=\"" + title + "\"" + AtrCont(mt.Contador) + ">" +
                  icono + "<span class=\"nv-n\">" + Server.HtmlEncode(nombre) + "</span>" + badge + "<b class=\"chev\">" + Ico("chev", 13) + "</b></a>");
        sb.Append("<div class=\"sub\"><div class=\"sub-t\">" + title + "</div>" + sub + "</div></div>");
        return sb.ToString();
    }

    /// <summary>El chip del icono: el simbolo de marca para SIGMA AI y SIGMA Twin, el icono del menu para el resto.</summary>
    private string IconoModulo(Menus m)
    {
        string link = m.mnu_link ?? "";
        if (link.EndsWith("BodegaMapa3D.aspx", StringComparison.OrdinalIgnoreCase))
            return "<i class=\"nv-ic br\"><img src=\"" + ResolveUrl("~/Imagen/sigma-twin/sigma-twin-symbol-gradient.svg") + "\" alt=\"\" /></i>";
        if (m.mnu_nivel == 2 && string.Equals(m.mnu_nombre, "SIGMA AI", StringComparison.OrdinalIgnoreCase))
            return "<i class=\"nv-ic br\"><img src=\"" + ResolveUrl("~/Imagen/sigma-ai/sigma-ai-symbol-gradient.svg") + "\" alt=\"\" /></i>";
        return "<i class=\"nv-ic\"><span class=\"" + Server.HtmlEncode(string.IsNullOrEmpty(m.mnu_icon) ? "mdi mdi-circle-outline" : m.mnu_icon) + "\"></span></i>";
    }

    private static string AtrCont(string clave) { return string.IsNullOrEmpty(clave) ? "" : " data-sg-c=\"" + clave + "\""; }

    /// <summary>La pastilla del contador: rojo vencidas, ambar umbrales, teal novedades, gris abiertos.</summary>
    private string Contador(string clave)
    {
        if (string.IsNullOrEmpty(clave)) return "";
        int n; if (!_cont.TryGetValue(clave.ToLowerInvariant(), out n) || n <= 0) return "";
        string tono = clave == "ot" ? "r" : clave == "stock" ? "a" : clave == "ai" ? "n" : "g";
        string txt = clave == "ot" ? " vencidas" : clave == "stock" ? " fuera de umbral" : clave == "ai" ? " predicciones nuevas" : " abiertos";
        return "<em class=\"nb " + tono + "\" data-sg-cont=\"" + clave + "\" title=\"" + n + txt + "\">" + (n > 99 ? "99+" : n.ToString()) + "</em>";
    }

    /// <summary>
    /// Las pantallas de un modulo, planas y con los contenedores intermedios como rotulo.
    /// Cuenta las pantallas visibles y recuerda la unica, para decidir si el modulo es un enlace directo.
    /// </summary>
    private string Hijos(List<Menus> menus, int padre, int profundidad, string modulo, string icono, ref int hojas, ref string unica, ref bool activo)
    {
        StringBuilder sb = new StringBuilder();
        foreach (Menus h in menus.Where(x => x.mnu_padre == padre && x.mnu_visible).OrderBy(x => x.mnu_orden))
        {
            if (MetaDe(h.mnu_id).Grupo != null) continue;           // ya se dibuja como modulo propio

            if (h.mnu_link == "#")
            {
                int n0 = 0; string u0 = null; bool a0 = false;
                string dentro = Hijos(menus, h.mnu_id, profundidad + 1, modulo, icono, ref n0, ref u0, ref a0);
                if (dentro == "") continue;
                hojas += n0 + 1;                                     // un contenedor visible ya obliga al desplegable
                if (a0) activo = true;
                /* Un nivel intermedio con pantallas adentro es su propio acordeon: chevron a la derecha y abierto solo si la pagina actual esta adentro. */
                sb.Append("<div class=\"sg-g" + (a0 ? " open" : "") + "\" data-sg-key=\"g" + h.mnu_id + "\"><a href=\"#\" role=\"button\" class=\"sub-gt d" + profundidad + "\" data-sg-gtog=\"g" + h.mnu_id + "\" aria-expanded=\"" + (a0 ? "true" : "false") + "\">" +
                          "<span>" + Server.HtmlEncode(h.mnu_nombre) + "</span><b class=\"chev\">" + Ico("chev", 12) + "</b></a><div class=\"sub-gb\">" + dentro + "</div></div>");
                continue;
            }

            if (!Puede(h)) continue;
            hojas++; unica = h.mnu_link;
            bool es = EsActual(h.mnu_link);
            if (es) activo = true;
            sb.Append("<a href=\"" + ResolveUrl(h.mnu_link) + "\" class=\"sbl d" + profundidad + (es ? " on" : "") + "\"" + (es ? " aria-current=\"page\"" : "") +
                      " data-sg-t=\"" + Server.HtmlEncode(h.mnu_nombre) + "\" data-sg-m=\"" + Server.HtmlEncode(modulo) + "\" data-sg-i=\"" + Server.HtmlEncode(icono ?? "") + "\">" + Server.HtmlEncode(h.mnu_nombre) + "</a>");
        }
        return sb.ToString();
    }
}
