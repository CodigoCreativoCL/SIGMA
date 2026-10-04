using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI.HtmlControls;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de centros de costo (HU-013).
///
/// El acceso a la pantalla lo resuelve el master con Token.ExigirPagina():
/// aqui no hay bloque de seguridad porque en SIGMA los permisos son datos,
/// no codigo. Lo unico que se pregunta es la funcion de escritura.
///
/// UN ARBOL, IGUAL QUE AREAS
///   Un centro de costo contiene otros (Mantenimiento > Electrico). La
///   grilla lo mostraba con una columna "Depende de" y un padding; ahora se
///   dibuja con el mismo arbol de Areas (sigma-arbol.css): plano, en orden
///   de recorrido, con nivel y padre en atributos para plegar en el cliente.
/// </summary>
public partial class View_Organizacion_CentrosCosto_CentrosCosto : System.Web.UI.Page
{
    /// <summary>Un centro con su profundidad recalculada sobre lo visible.</summary>
    protected class Nodo
    {
        public CentroCosto Centro { get; set; }
        public int Nivel { get; set; }
        public bool TieneHijos { get; set; }
        public int PadreVisible { get; set; }
        public int Descendientes { get; set; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        // Sin cliente en sesion no hay nada que listar: los centros de costo
        // son de un cliente, no de la plataforma.
        bool hayCliente = SitioBase.Session.ClienteId() > 0;

        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;

        if (!hayCliente) return;

        lnkNuevo.Visible = Token.PuedeFuncion("Crear y editar");

        CargarArbol();
        udPanel.Update();
    }

    protected void CargarArbol()
    {
        CentroCosto filtro = new CentroCosto();
        CentroCostoController controller = new CentroCostoController();

        filtro.cco_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        List<CentroCosto> lista = controller.GetCentrosCosto(filtro) ?? new List<CentroCosto>();

        List<Nodo> nodos = Aplanar(lista);

        pnlVacio.Visible = (nodos.Count == 0);

        litVacio.Text = (filtro.filtro != null || filtro.filtro_habilitado != null)
                      ? "Con estos filtros no queda ninguno. Pruebe con menos condiciones."
                      : "Todavía no se ha creado ningún centro de costo para esta empresa.";

        litCuenta.Text = nodos.Count == 0 ? ""
                       : (nodos.Count == 1 ? "1 centro de costo" : nodos.Count + " centros de costo");

        rptCentros.DataSource = nodos;
        rptCentros.DataBind();
    }

    /// <summary>
    /// De la lista plana al recorrido en profundidad. Un centro cuyo padre
    /// no esta en la lista (lo dejo fuera el filtro) se muestra como raiz,
    /// para no esconder justo lo que se busco.
    /// </summary>
    protected List<Nodo> Aplanar(List<CentroCosto> lista)
    {
        List<Nodo> salida = new List<Nodo>();
        Dictionary<int, List<CentroCosto>> hijos = new Dictionary<int, List<CentroCosto>>();
        HashSet<int> presente = new HashSet<int>();

        foreach (CentroCosto c in lista) presente.Add(c.cco_id);

        List<CentroCosto> raices = new List<CentroCosto>();

        foreach (CentroCosto c in lista)
        {
            int padre = c.cco_centro_costo_padre ?? 0;

            if (padre == 0 || !presente.Contains(padre))
            {
                raices.Add(c);
                continue;
            }

            if (!hijos.ContainsKey(padre)) hijos[padre] = new List<CentroCosto>();
            hijos[padre].Add(c);
        }

        foreach (CentroCosto r in raices) Descender(r, 1, 0, hijos, salida);

        return salida;
    }

    /// <summary>
    /// Agrega el nodo y despues sus hijos; devuelve cuantos agrego contando
    /// el propio, que es como el padre sabe cuantos lleva dentro.
    /// </summary>
    private int Descender(CentroCosto c, int nivel, int padreVisible,
                          Dictionary<int, List<CentroCosto>> hijos, List<Nodo> salida)
    {
        Nodo n = new Nodo();
        n.Centro = c;
        n.Nivel = nivel;
        n.PadreVisible = padreVisible;
        n.TieneHijos = hijos.ContainsKey(c.cco_id) && hijos[c.cco_id].Count > 0;

        salida.Add(n);

        if (!n.TieneHijos) return 1;

        int dentro = 0;
        foreach (CentroCosto h in hijos[c.cco_id])
            dentro += Descender(h, nivel + 1, c.cco_id, hijos, salida);

        n.Descendientes = dentro;
        return dentro + 1;
    }

    protected void rptCentros_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item &&
            e.Item.ItemType != ListItemType.AlternatingItem) return;

        Nodo n = (Nodo)e.Item.DataItem;
        CentroCosto c = n.Centro;

        bool puedeEditar = Token.PuedeFuncion("Crear y editar");

        HtmlGenericControl fila = (HtmlGenericControl)e.Item.FindControl("fila");
        HtmlGenericControl sangria = (HtmlGenericControl)e.Item.FindControl("sangria");

        fila.Attributes["data-id"] = c.cco_id.ToString();
        fila.Attributes["data-padre"] = n.PadreVisible.ToString();
        fila.Attributes["data-nivel"] = n.Nivel.ToString();
        fila.Attributes["data-hijos"] = n.TieneHijos ? "1" : "0";

        if (!c.cco_habilitado) fila.Attributes["class"] = "sg-arbol-fila is-deshabilitada";

        sangria.Style["width"] = ((n.Nivel - 1) * 26) + "px";

        ((Literal)e.Item.FindControl("litToggle")).Text = n.TieneHijos
            ? "<a href=\"javascript:void(0);\" class=\"sg-arbol-toggle\" " +
              "onclick=\"return sgArbolPlegar(this);\"><i class=\"mdi mdi-chevron-down\"></i></a>"
            : "<span class=\"sg-arbol-toggle is-hoja\"></span>";

        ((Literal)e.Item.FindControl("litNombre")).Text =
            Server.HtmlEncode(c.cco_codigo) + " · " + Server.HtmlEncode(c.cco_nombre);

        /* De quien depende, solo cuando el arbol no lo muestra: si el padre
           quedo fuera por el filtro, la fila sube a raiz y sin esto se
           perderia el dato. */
        string meta = (n.Nivel == 1 && !string.IsNullOrEmpty(c.padre_nombre))
            ? "Depende de " + Server.HtmlEncode(c.padre_nombre)
            : (n.Nivel == 1 ? "Centro de costo" : "Subcentro");

        ((Literal)e.Item.FindControl("litMeta")).Text = meta;

        string chips = "";

        if (n.TieneHijos)
            chips += "<span class=\"sigma-modal-chip is-neutro\">" + n.Descendientes + " dentro</span>";

        if (!c.cco_habilitado)
            chips += "<span class=\"sigma-modal-chip is-advertencia\">Deshabilitado</span>";

        ((Literal)e.Item.FindControl("litChips")).Text = chips;

        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + c.cco_id));

        LinkButton editar = (LinkButton)e.Item.FindControl("lnkEditar");
        editar.OnClientClick = "return abrirCentroCosto('" + query + "');";

        string qSub = Server.UrlEncode(Tools.Crypto.Encrypt("Id=0&Padre=" + c.cco_id));

        LinkButton sub = (LinkButton)e.Item.FindControl("lnkSub");
        sub.OnClientClick = "return abrirCentroCosto('" + qSub + "');";
        sub.Visible = puedeEditar;

        LinkButton eliminar = (LinkButton)e.Item.FindControl("lnkEliminar");
        eliminar.CommandArgument = c.cco_id.ToString();
        eliminar.Visible = puedeEditar;

        /* Con subcentros no se borra: mejor no ofrecer el boton que
           ofrecerlo para que conteste que no. */
        if (n.TieneHijos)
        {
            eliminar.Enabled = false;
            eliminar.CssClass = "sg-arbol-accion is-inerte";
            eliminar.ToolTip = "Tiene centros de costo dentro. Hay que mover o eliminar esos primero.";
        }
        else
        {
            eliminar.OnClientClick =
                "return ConfirSweetAlert(this, '', '¿Eliminar el centro de costo " +
                Server.HtmlEncode(c.cco_nombre).Replace("'", "\\'") + "?');";
        }
    }

    protected void rptCentros_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        if (e.CommandName != "Eliminar") return;

        try
        {
            int id;
            if (!int.TryParse(Convert.ToString(e.CommandArgument), out id) || id <= 0) return;

            Respuesta respuesta = new CentroCostoController().DeleteCentroCosto(new CentroCosto { cco_id = id });

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

    /// <summary>Lo llama refresh() al cerrar la ficha.</summary>
    protected void lnkRefrescar_Click(object sender, EventArgs e)
    {
    }
}
