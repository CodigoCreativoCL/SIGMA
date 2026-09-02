using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.HtmlControls;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de areas de planta (HU-012).
///
/// UN ARBOL Y NO UNA GRILLA
///   Un area CONTIENE otras areas. La grilla lo insinuaba con una columna
///   "Área superior" y un padding izquierdo: para saber qué colgaba de qué
///   había que leer fila por fila y cruzar nombres a mano.
///
///   Acá la jerarquía se ve, se pliega y se navega, y cada rama ofrece
///   "nueva subárea" en su propio sitio. Antes había que abrir "Nueva" y
///   buscar el padre en un desplegable, que es pedir que alguien vuelva a
///   escribir lo que ya estaba mirando.
///
/// EL ARBOL SE DIBUJA PLANO
///   Una fila por área, en orden de recorrido, con su nivel y su padre en
///   atributos. Repetidores anidados obligarían a un control recursivo, y un
///   control recursivo dentro de un UpdatePanel es donde se pierden los
///   eventos de los botones. Plano, cada LinkButton sigue siendo un control
///   normal del repetidor.
/// </summary>
public partial class View_Organizacion_Areas_Areas : System.Web.UI.Page
{
    /// <summary>
    /// Un area con su profundidad ya calculada y si tiene hijos.
    ///
    /// El SEL_ devuelve un "nivel", pero ese nivel es el del árbol COMPLETO:
    /// cuando el filtro deja fuera al padre, el hijo llega con nivel 2 y no
    /// hay nivel 1 donde colgarlo. Acá se recalcula sobre lo que de verdad
    /// se va a mostrar, que es lo único que el usuario puede ver.
    /// </summary>
    protected class Nodo
    {
        public InstalacionArea Area { get; set; }
        public int Nivel { get; set; }
        public bool TieneHijos { get; set; }
        public int PadreVisible { get; set; }

        /// <summary>
        /// Cuantas areas cuelgan de esta, contando nietos.
        ///
        /// Se calcula al armar el arbol y no al pintar cada fila: durante el
        /// DataBind el repetidor solo tiene los items YA enlazados, asi que
        /// recorrerlo desde ItemDataBound para contar descendientes devuelve
        /// cero siempre —los hijos todavia no existen—.
        /// </summary>
        public int Descendientes { get; set; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
    }

    /// <summary>
    /// El combo de plantas del filtro. Solo las del cliente en sesion: es
    /// la primera barrera del aislamiento multicliente y evita que alguien
    /// pueda siquiera pedir las areas de otra empresa.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;

                if (ctrl.ID == "cboPlanta")
                {
                    ClienteInstalacion filtro = new ClienteInstalacion();
                    filtro.filtro_cliente = SitioBase.Session.ClienteId().ToString();
                    filtro.filtro_habilitado = "1";

                    ClienteInstalacionController controller = new ClienteInstalacionController();

                    ctrl.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = controller.GetClienteInstalaciones(filtro);
                    ctrl.DataValueField = "cin_id";
                    ctrl.DataTextField = "cin_nombre";
                    ctrl.DataBind();
                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;

        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;

        if (!hayCliente) return;

        lnkNuevo.Visible = Token.PuedeFuncion("Crear y editar");

        CargarArbol();
        udPanel.Update();
    }

    /// <summary>
    /// Lo que se ve, en orden de recorrido y con el nivel recalculado.
    /// </summary>
    protected void CargarArbol()
    {
        InstalacionArea filtro = new InstalacionArea();
        InstalacionAreaController controller = new InstalacionAreaController();

        filtro.iar_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboPlanta = (RadComboBox2)wucFiltro.FindControl("cboPlanta");
        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        if (cboPlanta != null && cboPlanta.SelectedValue != "")
            filtro.iar_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);

        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        List<InstalacionArea> lista = controller.GetInstalacionAreas(filtro);

        if (lista == null) lista = new List<InstalacionArea>();

        List<Nodo> nodos = Aplanar(lista);

        pnlVacio.Visible = (nodos.Count == 0);

        litVacio.Text = (filtro.filtro != null || filtro.iar_cliente_instalacion > 0 ||
                         filtro.filtro_habilitado != null)
                      ? "Con estos filtros no queda ninguna. Pruebe con menos condiciones."
                      : "Todavía no se ha creado ninguna área para esta empresa.";

        litCuenta.Text = nodos.Count == 0 ? ""
                       : (nodos.Count == 1 ? "1 área" : nodos.Count.ToString() + " áreas");

        rptAreas.DataSource = nodos;
        rptAreas.DataBind();
    }

    /// <summary>
    /// De la lista plana al recorrido en profundidad.
    ///
    /// UN AREA CUYO PADRE NO ESTA EN LA LISTA SE TRATA COMO RAIZ
    ///   Pasa siempre que hay filtro: se busca "bomba" y aparece un área
    ///   cuyo padre no contiene esa palabra. Esconderla porque "le falta el
    ///   padre" sería esconder justo lo que se estaba buscando. Se muestra al
    ///   primer nivel, que es donde el usuario puede verla.
    /// </summary>
    protected List<Nodo> Aplanar(List<InstalacionArea> lista)
    {
        List<Nodo> salida = new List<Nodo>();

        Dictionary<int, List<InstalacionArea>> hijos = new Dictionary<int, List<InstalacionArea>>();
        Dictionary<int, bool> presente = new Dictionary<int, bool>();

        foreach (InstalacionArea a in lista) presente[a.iar_id] = true;

        List<InstalacionArea> raices = new List<InstalacionArea>();

        foreach (InstalacionArea a in lista)
        {
            int padre = (a.iar_area_padre != null) ? a.iar_area_padre.Value : 0;

            if (padre == 0 || !presente.ContainsKey(padre))
            {
                raices.Add(a);
                continue;
            }

            if (!hijos.ContainsKey(padre)) hijos[padre] = new List<InstalacionArea>();
            hijos[padre].Add(a);
        }

        foreach (InstalacionArea r in raices) Descender(r, 1, 0, hijos, salida);

        return salida;
    }

    /// <summary>
    /// Agrega el nodo y despues sus hijos: el orden de la lista ES el orden
    /// del arbol, y de eso depende que plegar una rama pueda esconder el
    /// tramo contiguo de sus descendientes.
    ///
    /// Devuelve cuantos nodos agrego contando el propio, que es como cada
    /// padre se entera de cuantos lleva dentro sin recorrer nada dos veces.
    /// </summary>
    private int Descender(InstalacionArea a, int nivel, int padreVisible,
                          Dictionary<int, List<InstalacionArea>> hijos, List<Nodo> salida)
    {
        Nodo n = new Nodo();
        n.Area = a;
        n.Nivel = nivel;
        n.PadreVisible = padreVisible;
        n.TieneHijos = hijos.ContainsKey(a.iar_id) && hijos[a.iar_id].Count > 0;

        salida.Add(n);

        if (!n.TieneHijos) return 1;

        int dentro = 0;

        foreach (InstalacionArea h in hijos[a.iar_id])
            dentro += Descender(h, nivel + 1, a.iar_id, hijos, salida);

        n.Descendientes = dentro;

        return dentro + 1;
    }

    protected void rptAreas_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item &&
            e.Item.ItemType != ListItemType.AlternatingItem) return;

        Nodo n = (Nodo)e.Item.DataItem;
        InstalacionArea a = n.Area;

        bool puedeEditar = Token.PuedeFuncion("Crear y editar");

        HtmlGenericControl fila = (HtmlGenericControl)e.Item.FindControl("fila");
        HtmlGenericControl sangria = (HtmlGenericControl)e.Item.FindControl("sangria");

        fila.Attributes["data-id"] = a.iar_id.ToString();
        fila.Attributes["data-padre"] = n.PadreVisible.ToString();
        fila.Attributes["data-nivel"] = n.Nivel.ToString();
        fila.Attributes["data-hijos"] = n.TieneHijos ? "1" : "0";

        if (!a.iar_habilitado) fila.Attributes["class"] = "sg-arbol-fila is-deshabilitada";

        /* La sangria en un elemento propio y no como padding de la fila: el
           fondo de la fila al pasar el mouse tiene que llegar hasta el borde
           izquierdo, o las ramas profundas se ven cortadas. */
        sangria.Style["width"] = ((n.Nivel - 1) * 26) + "px";

        Literal toggle = (Literal)e.Item.FindControl("litToggle");

        toggle.Text = n.TieneHijos
            ? "<a href=\"javascript:void(0);\" class=\"sg-arbol-toggle\" " +
              "onclick=\"return sgArbolPlegar(this);\"><i class=\"mdi mdi-chevron-down\"></i></a>"
            : "<span class=\"sg-arbol-toggle is-hoja\"></span>";

        ((Literal)e.Item.FindControl("litNombre")).Text =
            Server.HtmlEncode(a.iar_codigo) + " · " + Server.HtmlEncode(a.iar_nombre);

        /* La planta solo cuando se ven varias: repetir "Planta Norte" en las
           treinta filas de Planta Norte es ruido. */
        RadComboBox2 cboPlanta = (RadComboBox2)wucFiltro.FindControl("cboPlanta");
        bool unaSolaPlanta = (cboPlanta != null && cboPlanta.SelectedValue != "");

        string meta = "";

        if (!unaSolaPlanta && !string.IsNullOrEmpty(a.cin_nombre))
            meta += Server.HtmlEncode(a.cin_nombre);

        if (!string.IsNullOrEmpty(a.iat_nombre))
            meta += (meta.Length > 0 ? " · " : "") + Server.HtmlEncode(a.iat_nombre);

        ((Literal)e.Item.FindControl("litMeta")).Text = meta;

        string chips = "";

        if (n.TieneHijos)
            chips += "<span class=\"sigma-modal-chip is-neutro\">" +
                     n.Descendientes + " dentro</span>";

        if (!a.iar_habilitado)
            chips += "<span class=\"sigma-modal-chip is-advertencia\">Deshabilitada</span>";

        ((Literal)e.Item.FindControl("litChips")).Text = chips;

        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + a.iar_id));

        LinkButton editar = (LinkButton)e.Item.FindControl("lnkEditar");
        editar.OnClientClick = "return abrirArea('" + query + "');";

        /* "Nueva subárea acá": el padre viaja resuelto, así que la ficha se
           abre con la rama ya elegida. */
        string qSub = Server.UrlEncode(Tools.Crypto.Encrypt("Id=0&Padre=" + a.iar_id));

        LinkButton sub = (LinkButton)e.Item.FindControl("lnkSub");
        sub.OnClientClick = "return abrirArea('" + qSub + "');";
        sub.Visible = puedeEditar;

        LinkButton eliminar = (LinkButton)e.Item.FindControl("lnkEliminar");
        eliminar.CommandArgument = a.iar_id.ToString();
        eliminar.Visible = puedeEditar;

        /* Un área con subáreas no se borra: el SP lo rechazaría igual, y es
           mejor no ofrecer el botón que ofrecerlo para que conteste que no.
           El aviso dice por qué, que es lo que hay que saber para resolverlo. */
        if (n.TieneHijos)
        {
            eliminar.Enabled = false;
            eliminar.CssClass = "sg-arbol-accion is-inerte";
            eliminar.ToolTip = "Tiene subáreas dentro. Hay que mover o eliminar esas primero.";
        }
        else
        {
            eliminar.OnClientClick =
                "return ConfirSweetAlert(this, '', '¿Eliminar el área " +
                Server.HtmlEncode(a.iar_nombre).Replace("'", "\\'") + "?');";
        }
    }

    protected void rptAreas_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        if (e.CommandName != "Eliminar") return;

        try
        {
            int id;

            if (!int.TryParse(Convert.ToString(e.CommandArgument), out id) || id <= 0) return;

            InstalacionAreaController controller = new InstalacionAreaController();

            Respuesta respuesta = controller.DeleteInstalacionArea(
                new InstalacionArea { iar_id = id });

            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok");
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>
    /// Lo llama refresh() al cerrar la ficha: el árbol pudo cambiar de forma
    /// —un área nueva, un padre distinto— y no solo de contenido.
    /// </summary>
    protected void lnkRefrescar_Click(object sender, EventArgs e)
    {
    }
}
