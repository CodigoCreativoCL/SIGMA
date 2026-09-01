using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web.UI;
using SitioBase.Controller;
using SitioBase.Model;

/// <summary>
/// Menu lateral.
///
/// QUE CAMBIO
///   Antes preguntaba por CADA NODO si el usuario tenia permiso, y cada
///   pregunta era un viaje a la base: con 17 menus eran 17 consultas en
///   cada render de cada pagina. Ahora Token cachea el set de permisos del
///   usuario en la sesion, asi que estas verificaciones son lookups en
///   memoria y el render no consulta nada.
///
///   Ademas los contenedores (mnu_link = '#') ya no necesitan permiso
///   propio: se muestran solo si alguno de sus hijos se muestra. Asi no
///   hay que mantener permisos de carpetas y no aparecen menus vacios que
///   no llevan a ninguna parte.
/// </summary>
public partial class View_Comun_Controls_MenusLateral : System.Web.UI.UserControl
{
    private MenusController menusController = new MenusController();

    protected void Page_Load(object sender, EventArgs e)
    {
        CargarMenus();
    }

    protected void CargarMenus()
    {
        List<Menus> menus = menusController.GetMenus(new Menus());
        StringBuilder sbMenus = new StringBuilder();

        foreach (Menus item in menus.Where(x => x.mnu_nivel == 1).OrderBy(x => x.mnu_orden))
        {
            if (!item.mnu_visible) continue;

            // Una seccion de nivel 1 es un titulo: solo vale si trae algo debajo.
            string hijos = addMenu(menus, item.mnu_id, 1, 0).ToString();
            if (string.IsNullOrEmpty(hijos)) continue;

            sbMenus.AppendLine("<li class='menu-title'>");
            sbMenus.AppendLine(item.mnu_nombre);
            sbMenus.AppendLine("</li>");
            sbMenus.AppendLine(hijos);
        }

        LiteralControl lc = new LiteralControl();
        lc.Text = sbMenus.ToString();
        phdMenus.Controls.Add(lc);
    }

    /// <summary>
    /// Dibuja los hijos de un nodo.
    ///
    /// <paramref name="countNivel"/> decide si el item lleva icono: los que
    /// cuelgan directo de un titulo si, los de un submenu no.
    ///
    /// <paramref name="profundidad"/> es otra cosa: cuenta cuantos submenus
    /// llevamos abiertos, para nombrar el &lt;ul&gt; como Adminto espera
    /// -nav-second-level el primero, nav-third-level de ahi para dentro-.
    /// Antes todos los niveles salian como nav-second-level, asi que un
    /// tercer nivel se dibujaba con la misma sangria que el segundo y no se
    /// leia como algo que esta adentro.
    /// </summary>
    /// <summary>
    /// Cuantas alertas abiertas tiene cada pantalla.
    ///
    /// Se pide UNA vez por peticion -el controlador lo cachea- y no una por
    /// item: con veinte menus serian veinte consultas para pintar tres
    /// numeros.
    /// </summary>
    private Dictionary<string, int> _alertas;

    private Dictionary<string, int> Alertas
    {
        get
        {
            if (_alertas == null)
                _alertas = new AlertaController().GetResumen().PorMenu;

            return _alertas;
        }
    }

    /// <summary>
    /// El numero al lado del nombre del menu.
    ///
    /// Es el mismo hallazgo que muestra la campana, visto desde donde se
    /// resuelve: la campana dice "hay tres cosas", el menu dice "las tres son
    /// de Existencias". Sin esto habria que abrir la campana para saber
    /// adonde ir.
    /// </summary>
    protected string BadgeDe(string link)
    {
        if (string.IsNullOrEmpty(link)) return "";

        int n;
        if (!Alertas.TryGetValue(link, out n) || n <= 0) return "";

        return " <span class='sg-menu-badge'>" + (n > 99 ? "99+" : n.ToString()) + "</span>";
    }

    /// <summary>
    /// Todas las alertas de una rama, por hondo que este la pantalla.
    ///
    /// Recursivo y no un nivel: Inventario contiene Operacion y Operacion
    /// contiene Existencias. Sumando solo los hijos directos, el modulo
    /// marcaba cero teniendo tres alertas dos niveles mas abajo.
    /// </summary>
    protected int TotalRama(List<Menus> menus, int padre)
    {
        int total = 0;

        foreach (Menus h in menus.Where(x => x.mnu_padre == padre))
        {
            int n;

            if (!string.IsNullOrEmpty(h.mnu_link) && h.mnu_link != "#" &&
                Alertas.TryGetValue(h.mnu_link, out n)) total += n;

            total += TotalRama(menus, h.mnu_id);
        }

        return total;
    }

    /// <summary>
    /// El punto que late en el modulo.
    ///
    /// Va como SVG y no como un div con box-shadow porque el anillo tiene que
    /// expandirse por fuera del punto sin empujar el texto del menu: dentro
    /// del svg el dibujo se sale de su caja sin afectar el layout.
    /// </summary>
    /// <summary>
    /// El indicador de novedades del menú, del kit de marca.
    ///
    /// Es el SVG de SIGMA y no un punto dibujado a mano: la animación y la
    /// geometría neuronal vienen dentro del vector, así que el menú no tiene
    /// que saber nada de cómo late.
    ///
    /// Solo se dibuja cuando hay algo. El README del kit lo dice y tiene
    /// razón: un indicador siempre presente deja de indicar.
    /// </summary>
    protected string PuntoPulso()
    {
        return "<span class='sigma-menu-alert' title='Hay alertas en este módulo'>" +
               "<img src='" + ResolveUrl("~/Imagen/indicadores/sigma-menu-pulse.svg") +
               "' alt='' aria-hidden='true' /></span>";
    }

    protected StringBuilder addMenu(List<Menus> menus, int padre, int countNivel, int profundidad)
    {
        StringBuilder sb = new StringBuilder();

        foreach (Menus item in menus.Where(x => x.mnu_padre == padre).OrderBy(x => x.mnu_orden))
        {
            if (!item.mnu_visible) continue;

            if (item.mnu_link == "#")
            {
                // Contenedor: se arma primero el contenido y si queda vacio
                // no se dibuja. No se le pide permiso propio.
                string hijos = addMenu(menus, item.mnu_id, 0, profundidad + 1).ToString();
                if (string.IsNullOrEmpty(hijos)) continue;

                string clase = profundidad == 0 ? "nav-second-level" : "nav-third-level";

                sb.AppendLine("<li>");
                sb.AppendLine(" <a href='javascript: void(0);'>");

                // El icono, con el mismo criterio que las paginas: solo en el
                // primer nivel. Un contenedor anidado con icono se leeria
                // como si estuviera al mismo nivel que los de arriba.
                if (countNivel != 0)
                    sb.AppendLine("     <i class='" + item.mnu_icon + "'></i>");

                /* El contenedor suma lo de TODA su rama, no solo sus hijos
                   directos: Inventario cuelga de Operacion y Operacion de
                   Existencias, asi que mirando un nivel el modulo quedaba en
                   cero justo cuando tenia tres alertas adentro. */
                int enRama = TotalRama(menus, item.mnu_id);

                sb.AppendLine("     <span>" + item.mnu_nombre + "</span>");

                /* EL PULSO BAJA EN CASCADA; EL NUMERO SE QUEDA DONDE ESTA

                   Las CARPETAS -Inventario, Operacion- solo laten: dicen "hay
                   algo por aca" y guian hacia abajo. El numero aparece una
                   sola vez, en la pantalla que realmente tiene la alerta.

                   Antes el contador se repetia en cada nivel: Operacion decia
                   3 y Existencias decia 3, y las dos eran las MISMAS tres. Un
                   numero repetido se lee como si fueran seis. */
                if (enRama > 0) sb.AppendLine("     " + PuntoPulso());

                sb.AppendLine("     <span class='menu-arrow'></span>");
                sb.AppendLine(" </a>");
                sb.AppendLine(" <ul class='" + clase + "' aria-expanded='false'>");
                sb.AppendLine(hijos);
                sb.AppendLine(" </ul>");
                sb.AppendLine("</li>");
            }
            else
            {
                // Pagina: aca si manda el permiso.
                if (!SitioBase.Token.PuedeMenu(item.mnu_id)) continue;

                sb.AppendLine("<li>");
                sb.AppendLine(" <a href='" + ResolveUrl(item.mnu_link) + "'>");

                string badge = BadgeDe(item.mnu_link);

                if (countNivel == 0)
                {
                    sb.AppendLine(item.mnu_nombre + badge);
                }
                else
                {
                    sb.AppendLine("     <i class='" + item.mnu_icon + "'></i>");
                    sb.AppendLine("     <span>" + item.mnu_nombre + "</span>" + badge);
                }
                sb.AppendLine(" </a>");
                sb.AppendLine(addMenu(menus, item.mnu_id, 1, profundidad + 1).ToString());
                sb.AppendLine("</li>");
            }
        }

        return sb;
    }
}
