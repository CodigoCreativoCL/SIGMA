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
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("REP_ID", "", Width: "3%");
            Grid.AddColumn("REP_CODIGO", "CÓDIGO", Width: "15%");

            Grid.AddTemplateColumn("REPUESTO", "", "REPUESTO", Width: "34%");
            Grid.AddTemplateColumn("ATRIBUTOS", "", "CARACTERÍSTICAS", Width: "22%");

            Grid.AddTemplateColumn("EXISTENCIA", "", "EXISTENCIA", Width: "26%",
                ItemPosition: HorizontalAlign.Left, HederPosition: HorizontalAlign.Left);
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        /* Escribe el archivo directo en la respuesta, y eso no sobrevive a un
           postback asíncrono: el UpdatePanel espera un fragmento y recibe un
           binario. */
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkDescargar);

        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
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
