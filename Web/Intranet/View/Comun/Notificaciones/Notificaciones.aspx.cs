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
/// La bandeja completa de notificaciones.
///
/// AGRUPADA POR CATEGORIA, NO UNA LISTA PLANA
///   Veinte avisos seguidos obligan a leerlos todos para saber si hay algo de
///   bodega. Agrupados, se mira el grupo que importa y se ignora el resto, y
///   cada grupo dice cuántos trae para poder decidir sin abrirlo.
///
/// EL ORDEN DE LOS GRUPOS LO DA LA GRAVEDAD
///   Primero el grupo que contiene lo más grave, no el alfabético. Lo que
///   decide qué se mira ahora es la gravedad, no cómo se llama el módulo.
/// </summary>
public partial class View_Comun_Notificaciones_Notificaciones : System.Web.UI.Page
{
    /// <summary>Un grupo de la pantalla: una categoría con sus avisos.</summary>
    public class Grupo
    {
        public string Codigo { get; set; }
        public string Nombre { get; set; }
        public string Icono { get; set; }
        public int Total { get; set; }
        public int Gravedad { get; set; }
        public List<Alerta> Items { get; set; }

        public Grupo() { Items = new List<Alerta>(); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            CargarCategorias();
            Cargar();
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        /* El buscador y los combos disparan el filtro por su cuenta; acá solo
           hay que volver a armar la lista cuando eso pasa. */
        if (IsPostBack) return;
    }

    /// <summary>
    /// Los combos viven DENTRO de wucFiltro, en su FiltroPersonalizado, asi
    /// que no son campos de la pagina: se buscan por nombre. Es el mismo
    /// patron que usan los demas listados del proyecto.
    /// </summary>
    protected RadComboBox2 Combo(string id)
    {
        return wucFiltro.FindControl(id) as RadComboBox2;
    }

    protected string ValorCombo(string id)
    {
        RadComboBox2 c = Combo(id);
        return c == null ? "" : c.SelectedValue;
    }

    protected void CargarCategorias()
    {
        RadComboBox2 cbo = Combo("cboCategoria");
        if (cbo == null) return;

        /* Las categorias salen de lo que HAY, no del catalogo completo:
           ofrecer filtrar por un tipo que no tiene ni una alerta es ofrecer un
           camino que termina en una lista vacia. */
        List<Alerta> todas = new AlertaController().GetAlertas(false, 500);

        List<string> vistos = new List<string>();

        cbo.Items.Add(new RadComboBoxItem("Todas", ""));

        foreach (Alerta a in todas)
        {
            if (vistos.Contains(a.alt_codigo)) continue;

            vistos.Add(a.alt_codigo);
            cbo.Items.Add(new RadComboBoxItem(a.alt_nombre, a.alt_codigo));
        }
    }

    protected void Cargar()
    {
        string estado = ValorCombo("cboLectura");
        if (string.IsNullOrEmpty(estado)) estado = "ABIERTAS";

        AlertaController controller = new AlertaController();

        /* "TODAS" incluye resueltas: es la vista de historia —"¿cuántas veces
           nos quedamos sin este repuesto?"— y por eso trae más filas. */
        List<Alerta> lista = controller.GetAlertas(estado != "TODAS", 500);

        string categoria = ValorCombo("cboCategoria");
        string severidad = ValorCombo("cboSeveridad");
        string texto = wucFiltro.Filtro();

        List<Grupo> grupos = new List<Grupo>();

        foreach (Alerta a in lista)
        {
            if (estado == "NUEVAS" && a.LEIDA) continue;
            if (!string.IsNullOrEmpty(categoria) && a.alt_codigo != categoria) continue;
            if (!string.IsNullOrEmpty(severidad) && a.sev_codigo != severidad) continue;

            if (!string.IsNullOrEmpty(texto))
            {
                string donde = (a.ale_titulo + " " + a.ale_descripcion).ToUpper();
                if (!donde.Contains(texto.ToUpper())) continue;
            }

            Grupo g = grupos.Find(delegate(Grupo x) { return x.Codigo == a.alt_codigo; });

            if (g == null)
            {
                g = new Grupo();
                g.Codigo = a.alt_codigo;
                g.Nombre = a.alt_nombre;
                g.Icono = a.alt_icono;
                grupos.Add(g);
            }

            g.Items.Add(a);
            g.Total++;

            int peso = Gravedad(a.sev_codigo);
            if (peso > g.Gravedad) g.Gravedad = peso;
        }

        /* El grupo con lo más grave va primero. Alfabético pondría "Lote por
           vencer" antes que "Stock bajo el mínimo" sin ninguna razón. */
        grupos.Sort(delegate(Grupo x, Grupo y)
        {
            int c = y.Gravedad.CompareTo(x.Gravedad);
            return c != 0 ? c : y.Total.CompareTo(x.Total);
        });

        pnlVacio.Visible = (grupos.Count == 0);
        rptGrupos.Visible = (grupos.Count > 0);

        int total = 0;
        foreach (Grupo g in grupos) total += g.Total;

        litCuenta.Text = total == 0 ? "" :
                         (total == 1 ? "1 alerta" : total.ToString() + " alertas");

        rptGrupos.DataSource = grupos;
        rptGrupos.DataBind();
    }

    protected void rptGrupos_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem)
            return;

        Grupo g = (Grupo)e.Item.DataItem;
        Literal lit = (Literal)e.Item.FindControl("litItems");

        StringBuilder sb = new StringBuilder();

        foreach (Alerta a in g.Items)
        {
            /* Se abre el REGISTRO, no el listado del módulo: avisar y después
               hacer buscar es la mitad del trabajo. */
            string onclick;

            if (!string.IsNullOrEmpty(a.FICHA_LINK) && a.FICHA_ID != null && a.FICHA_ID > 0)
            {
                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + a.FICHA_ID.Value));
                onclick = "return abrirFicha('" + ResolveUrl(a.FICHA_LINK) + "', '" +
                          query + "', " + a.ale_id + ");";
            }
            else if (!string.IsNullOrEmpty(a.alt_menu_link))
            {
                onclick = "if(window.sigmaAlertas) sigmaAlertas.leer(" + a.ale_id + ");" +
                          " window.location='" + ResolveUrl(a.alt_menu_link) + "'; return false;";
            }
            else
            {
                onclick = "return false;";
            }

            sb.Append("<a class=\"sg-notif-item" + (a.LEIDA ? "" : " is-nueva") +
                      "\" href=\"javascript:void(0);\" onclick=\"" + onclick + "\">");

            sb.Append("<span class=\"icono " + Clase(a.sev_codigo) + "\">" +
                      "<i class=\"" + Server.HtmlEncode(a.alt_icono) + "\"></i></span>");

            sb.Append("<span class=\"texto\">");
            sb.Append("<span class=\"titulo\">" + Server.HtmlEncode(a.ale_titulo) + "</span>");
            sb.Append("<span class=\"detalle\">" + Server.HtmlEncode(a.ale_descripcion) + "</span>");

            sb.Append("<span class=\"cuando\">" + Server.HtmlEncode(a.Antiguedad));

            /* El estado solo se dice cuando NO es el normal: rotular "Nueva"
               en cada fila de una bandeja de novedades es ruido. */
            if (a.aet_codigo != "NUEVA")
                sb.Append(" &middot; " + Server.HtmlEncode(a.aet_nombre));

            sb.Append("</span></span>");

            sb.Append("<span class=\"sg-notif-sev " + Clase(a.sev_codigo) + "\">" +
                      Server.HtmlEncode(a.sev_nombre) + "</span>");

            if (!a.LEIDA) sb.Append("<span class=\"punto\"></span>");

            sb.Append("</a>");
        }

        lit.Text = sb.ToString();
    }

    protected void lnkLeerTodo_Click(object sender, EventArgs e)
    {
        new AlertaController().Leer();
        Cargar();
        udPanel.Update();
    }

    /// <summary>
    /// Vuelve a revisar los umbrales.
    ///
    /// Existe porque hoy nadie dispara el detector solo: sin este botón, la
    /// lista muestra lo que se detectó la última vez que alguien lo corrió, y
    /// no hay forma de saberlo desde la pantalla.
    /// </summary>
    protected void lnkRevisar_Click(object sender, EventArgs e)
    {
        AlertaController controller = new AlertaController();

        /* Forzado: si alguien aprieta "Revisar ahora" es porque quiere
           saber EN ESTE MOMENTO, no cuando al freno le parezca. */
        controller.Detectar(true);
        Cargar();

        udPanel.Update();
        Tools.tools.ClientAlert("Revisión hecha.", "ok");
    }

    protected int Gravedad(string codigo)
    {
        switch (codigo)
        {
            case "CRITICA": return 5;
            case "ALTA": return 4;
            case "ADVERTENCIA": return 3;
            case "BAJA": return 2;
        }

        return 1;
    }

    protected string Clase(string codigo)
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
