using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado del maestro de repuestos (HU-050).
///
/// POR QUE NO HAY UNA COLUMNA "BODEGAS" CON UN NUMERO PELADO
///   La tenía, y decía 1, 2 o 0. Un 0 en una columna llamada BODEGAS no se
///   entiende: ¿es que no tiene bodega asignada? ¿que está mal cargado? Lo
///   que significa es que **no queda ninguna unidad**, que es justo el dato
///   que hay que ver primero y estaba escrito como si fuera un detalle.
///
///   Ahora la existencia y dónde está van en la misma celda, y el cero se
///   dice con todas sus letras.
///
/// FABRICANTE Y MODELO BAJAN A SEGUNDA LINEA
///   Ocupaban dos columnas para un dato que casi nunca se lee de corrido:
///   se usa para BUSCAR —el filtro mira los cuatro campos— no para
///   comparar filas. Debajo del nombre siguen visibles y liberan la mitad
///   del ancho.
/// </summary>
public partial class View_Inventario_Repuestos_Repuestos : System.Web.UI.Page
{
    /// <summary>
    /// Que pestaña se esta mirando.
    ///
    ///   -1  todas
    ///    0  sin clasificar
    ///   >0  el id del tipo
    ///
    /// Vive en ViewState y no en la sesion: es una decision de ESTA pantalla
    /// y de este momento. En la sesion, quien volviera mañana se encontraria
    /// filtrado por una categoria que ya no recuerda haber elegido.
    /// </summary>
    public int TipoTab
    {
        get { return ViewState["TipoTab"] != null ? (int)ViewState["TipoTab"] : -1; }
        set { ViewState["TipoTab"] = value; }
    }

    /// <summary>Los tipos del cliente, leidos una vez por peticion.</summary>
    private List<RepuestoTipo> _tipos;

    private List<RepuestoTipo> Tipos()
    {
        if (_tipos == null)
            _tipos = new RepuestoTipoController().GetRepuestoTipos(
                new RepuestoTipo { filtro_habilitado = true });

        return _tipos;
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            /* La casilla de seleccion habilita la asignacion en lote: sin
               ella habria que abrir trescientas fichas para clasificar el
               maestro. */
            Grid.AddSelectColumn();
            Grid.AddColumn("REP_ID", "", Width: "3%");
            Grid.AddColumn("REP_CODIGO", "CÓDIGO", Width: "15%");

            Grid.AddTemplateColumn("REPUESTO", "", "REPUESTO", Width: "34%");
            Grid.AddTemplateColumn("ATRIBUTOS", "", "CARACTERÍSTICAS", Width: "22%");

            Grid.AddTemplateColumn("EXISTENCIA", "", "EXISTENCIA", Width: "26%",
                ItemPosition: HorizontalAlign.Left, HederPosition: HorizontalAlign.Left);
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    /// <summary>
    /// El combo de tipos de la barra de asignacion.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;

        if (ctrl.ID != "cboTipoLote") return;

        /* "Sin clasificar" tambien es una opcion: sirve para deshacer una
           asignacion equivocada sin tener que elegir otro tipo cualquiera. */
        ctrl.Items.Add(new RadComboBoxItem("Sin clasificar", "0"));
        ctrl.AppendDataBoundItems = true;
        ctrl.DataSource = Tipos();
        ctrl.DataValueField = "rti_id";
        ctrl.DataTextField = "rti_nombre";
        ctrl.DataBind();
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        /* Escribe el archivo directo en la respuesta, y eso no sobrevive a un
           postback asíncrono: el UpdatePanel espera un fragmento y recibe un
           binario. */
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkDescargar);

        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarTabs();
        CargarGrid();
        Grid.DataBind();

        /* La barra aparece sola cuando hay algo marcado. Permanente seria una
           fila mas de ruido en una pantalla que casi siempre se usa para
           buscar, no para clasificar. */
        int marcados = Grid.SelectedIndexes.Count;

        pnlAsignar.Visible = marcados > 0 && Token.Puede("CREAR EDITAR REPUESTOS");
        litMarcados.Text = marcados == 1 ? "1 repuesto marcado" : marcados + " repuestos marcados";

        udPanel.Update();
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem &&
            e.Item.ItemType != GridItemType.Item) return;

        GridDataItem item = e.Item as GridDataItem;

        if (item == null) return;

        Repuesto r = item.DataItem as Repuesto;

        if (r == null) return;

        // ---- Enlace a la ficha ----
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + r.rep_id));

        HyperLink editar = new HyperLink();
        editar.ID = "lnkEditar" + item.ItemIndex;
        editar.CssClass = "icono_Editar";
        editar.NavigateUrl = "javascript:void(0)";
        editar.Attributes.Add("onclick", "abrirRepuesto('" + query + "')");

        item["REP_ID"].Controls.Add(editar);

        // ---- Nombre, y debajo con qué se lo busca ----
        string marca = "";

        if (!string.IsNullOrEmpty(r.rep_fabricante)) marca = r.rep_fabricante;

        if (!string.IsNullOrEmpty(r.rep_modelo))
            marca += (marca.Length > 0 ? " · " : "") + r.rep_modelo;

        string nombre = Server.HtmlEncode(r.rep_nombre);

        if (marca.Length > 0)
            nombre += "<span class=\"sigma-inv-nota\">" + Server.HtmlEncode(marca) + "</span>";

        item["REPUESTO"].Controls.Add(new Literal { Text = nombre });

        // ---- Características ----
        item["ATRIBUTOS"].Controls.Add(new Literal { Text = Atributos(r) });

        // ---- Existencia y dónde está ----
        item["EXISTENCIA"].Controls.Add(new Literal { Text = Existencia(r) });
    }

    /// <summary>
    /// Lo que cambia cómo se opera el repuesto, no lo que lo describe.
    ///
    /// "Controla lote" es el que importa de verdad: decide si el ingreso va
    /// a exigir un número de lote. Verlo recién al intentar guardar es
    /// enterarse tarde.
    /// </summary>
    private string Atributos(Repuesto r)
    {
        string html = "";

        if (r.rep_controla_lote)
            html += "<span class=\"grid-estado-chip is-info\">"
                  + "<i class=\"mdi mdi-barcode\"></i>Lote</span> ";

        if (r.rep_es_consumible)
            html += "<span class=\"grid-estado-chip is-neutro\">"
                  + "<i class=\"mdi mdi-delete-sweep-outline\"></i>Consumible</span> ";

        if (r.rep_es_reparable)
            html += "<span class=\"grid-estado-chip is-acento\">"
                  + "<i class=\"mdi mdi-wrench-outline\"></i>Reparable</span> ";

        if (html.Length == 0)
            html = "<span class=\"sigma-inv-vacio\">—</span>";

        return html;
    }

    /// <summary>
    /// La cantidad total y en cuántas bodegas está.
    ///
    /// Cero no se escribe como "0,00 · 0 bodegas": se dice "Sin existencia",
    /// en rojo, porque es lo que hace que alguien reaccione. Un cero
    /// alineado entre otros números pasa desapercibido.
    /// </summary>
    private string Existencia(Repuesto r)
    {
        if (r.existencia_total <= 0)
            return "<span class=\"grid-estado-chip is-alerta\">"
                 + "<i class=\"mdi mdi-package-variant\"></i>Sin existencia</span>";

        string donde = (r.bodegas_con_saldo == 1)
            ? "en 1 bodega"
            : "en " + r.bodegas_con_saldo + " bodegas";

        return "<div class=\"sigma-inv-cantidad\">"
             + "<span><span class=\"valor\">" + r.existencia_total.ToString("N2") + "</span>"
             + "<span class=\"unidad\">" + Server.HtmlEncode(r.unidad_simbolo) + "</span></span>"
             + "<span class=\"rango\">" + donde + "</span>"
             + "</div>";
    }

    /// <summary>
    /// Las pestañas: "Todos", una por tipo, y "Sin clasificar" al final.
    ///
    /// "SIN CLASIFICAR" NO SE ESCONDE CUANDO ESTA VACIA
    ///   Es justamente la pestaña que hay que vaciar, y verla en cero es la
    ///   señal de que el maestro quedo clasificado. Escondida, no habria forma
    ///   de saber si faltan repuestos por clasificar.
    /// </summary>
    protected void CargarTabs()
    {
        List<Repuesto> todos = ListaBase();

        List<object> tabs = new List<object>();

        tabs.Add(new object[] { -1, "Todos", todos.Count });

        foreach (RepuestoTipo t in Tipos())
        {
            int n = 0;

            foreach (Repuesto r in todos)
                if (r.rep_repuesto_tipo == t.rti_id) n++;

            tabs.Add(new object[] { t.rti_id, t.rti_nombre, n });
        }

        int sin = 0;

        foreach (Repuesto r in todos)
            if (r.rep_repuesto_tipo <= 0) sin++;

        tabs.Add(new object[] { 0, "Sin clasificar", sin });

        rptTabs.DataSource = tabs;
        rptTabs.DataBind();
    }

    protected void rptTabs_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item &&
            e.Item.ItemType != ListItemType.AlternatingItem) return;

        object[] d = e.Item.DataItem as object[];

        if (d == null) return;

        LinkButton b = (LinkButton)e.Item.FindControl("lnkTab");

        if (b == null) return;

        int id = (int)d[0];

        b.CommandArgument = id.ToString();

        /* El contenido va en `Text` y no en controles hijos: un LinkButton
           dibuja sus hijos solo cuando `Text` esta vacio, y eso depende de que
           el arbol se reconstruya igual en cada postback parcial. Ya paso con
           las tarjetas de permisos y quedaron en blanco. */
        b.Text = Server.HtmlEncode((string)d[1]) +
                 "<span class=\"n\">" + (int)d[2] + "</span>";

        b.CssClass = "sg-rep-tab" + (TipoTab == id ? " is-activa" : "") +
                     ((int)d[2] == 0 && TipoTab != id ? " is-vacia" : "");
    }

    protected void rptTabs_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        if (e.CommandName != "tab") return;

        int id;

        if (!int.TryParse(Convert.ToString(e.CommandArgument), out id)) return;

        TipoTab = id;

        /* Cambiar de pestaña limpia lo marcado: lo que estaba seleccionado ya
           no se ve, y asignarle un tipo a filas invisibles es la clase de cosa
           que despues nadie entiende. */
        Grid.SelectedIndexes.Clear();
    }

    /// <summary>
    /// La lista SIN el filtro de pestaña: es la que cuentan las pestañas.
    ///
    /// Si contaran sobre la lista ya filtrada, cada pestaña mostraria su
    /// propio total y las demas en cero.
    /// </summary>
    protected List<Repuesto> ListaBase()
    {
        RepuestoController controller = new RepuestoController();

        Repuesto filtro = new Repuesto();
        filtro.filtro_habilitado = true;

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        List<Repuesto> lista = controller.GetRepuestos(filtro);

        return lista ?? new List<Repuesto>();
    }

    protected void lnkAsignar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("CREAR EDITAR REPUESTOS"))
            {
                Tools.tools.ClientAlert("No tiene permisos para clasificar repuestos.", "alerta");
                return;
            }

            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Marque al menos un repuesto.", "alerta");
                return;
            }

            List<string> ids = new List<string>();

            foreach (string indice in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey k = Grid.MasterTableView.DataKeyValues[int.Parse(indice)];
                ids.Add(k["rep_id"].ToString());
            }

            int tipo;

            if (!int.TryParse(cboTipoLote.SelectedValue, out tipo)) tipo = 0;

            RepuestoController controller = new RepuestoController();
            Respuesta respuesta = controller.AsignarTipo(tipo, string.Join(",", ids.ToArray()));

            if (!respuesta.error) Grid.SelectedIndexes.Clear();

            Tools.tools.ClientAlert(respuesta.detalle, respuesta.error ? "alerta" : "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }

    protected void CargarGrid()
    {
        RepuestoController controller = new RepuestoController();

        Repuesto filtro = new Repuesto();
        filtro.filtro_habilitado = true;

        /* El texto busca en código, nombre, fabricante Y modelo. Es el
           criterio 2 de HU-050: el técnico escribe el número grabado en la
           pieza y la encuentra igual. Lo hace @FILTRO en SEL_REPUESTO. */
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        List<Repuesto> lista = controller.GetRepuestos(filtro);

        if (lista == null) lista = new List<Repuesto>();

        /* Lote y existencia se filtran acá y no en el SP: el primero es una
           columna que el SEL_ ya trae, y el segundo se deriva de un SUM que
           el SP calcula. Agregarles parámetros sería mover a la base una
           decisión de pantalla sin ganar nada. */
        RadComboBox2 cboLote = (RadComboBox2)wucFiltro.FindControl("cboLote");
        RadComboBox2 cboExistencia = (RadComboBox2)wucFiltro.FindControl("cboExistencia");

        if (cboLote != null && !string.IsNullOrEmpty(cboLote.SelectedValue))
        {
            bool quiere = (cboLote.SelectedValue == "1");
            lista = lista.FindAll(delegate(Repuesto r) { return r.rep_controla_lote == quiere; });
        }

        if (cboExistencia != null && !string.IsNullOrEmpty(cboExistencia.SelectedValue))
        {
            bool con = (cboExistencia.SelectedValue == "1");
            lista = lista.FindAll(delegate(Repuesto r)
            {
                return con ? r.existencia_total > 0 : r.existencia_total <= 0;
            });
        }

        /* La pestaña filtra al final, sobre la lista ya acotada por el
           buscador y los combos: asi "Rodamientos" muestra los rodamientos
           QUE ADEMAS coinciden con lo que se busco, y no todos. */
        if (TipoTab >= 0)
        {
            int tab = TipoTab;

            lista = lista.FindAll(delegate(Repuesto r)
            {
                return tab == 0 ? r.rep_repuesto_tipo <= 0 : r.rep_repuesto_tipo == tab;
            });
        }

        Grid.DataSource = lista;
    }

    /// <summary>
    /// El filtro que la descarga puede reproducir.
    ///
    /// SOLO EL TEXTO Y EL HABILITADO
    ///   Los combos de lote y existencia los aplica la grilla EN MEMORIA
    ///   sobre la lista ya traída —uno mira una columna, el otro un SUM que
    ///   el SP calcula—, así que RPT_REPUESTO_EXCEL no los conoce. Antes de
    ///   inventarles parámetros, la descarga dice lo que hace: baja lo que
    ///   coincide con la búsqueda.
    /// </summary>
    protected Repuesto FiltroActual()
    {
        Repuesto filtro = new Repuesto();
        filtro.filtro_habilitado = true;

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        return filtro;
    }

    /// <summary>
    /// Baja a Excel lo que se está viendo.
    ///
    /// Con el MISMO filtro de la pantalla: si alguien buscó "rodamiento" y
    /// descarga, espera los rodamientos. Bajar el catálogo entero cuando la
    /// pantalla muestra diez filas es una sorpresa desagradable, y con cinco
    /// mil repuestos un archivo inútil.
    /// </summary>
    protected void lnkDescargar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("VER REPUESTOS"))
                throw new Exception("No tiene permiso para ver repuestos.");

            RepuestoController controller = new RepuestoController();
            controller.ExportarRepuestos(FiltroActual());
        }
        catch (System.Threading.ThreadAbortException)
        {
            /* Response.End() la lanza siempre: es cómo termina una descarga,
               no un fallo. Se deja pasar para que no llegue al catch de abajo
               y muestre una alerta sobre un archivo que sí se envió. */
            throw;
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

}
