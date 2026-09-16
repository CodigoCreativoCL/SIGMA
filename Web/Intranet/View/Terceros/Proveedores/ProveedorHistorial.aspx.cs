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
/// Historial de servicios de un proveedor (HU-065, bloques 108 y 236).
///
/// "Para negociar con datos y saber cuánto representa cada contratista
/// en el gasto."
///
/// SOLO LECTURA
///   Los servicios se registran en la orden de trabajo en que se
///   contrataron (HU-117). Esta pantalla es cómo se leen, todos juntos.
///
/// EL ACCESO LO RESUELVE EL MASTER
///   Token.ExigirPagina() contra el menú: la pantalla cuelga de VER
///   PROVEEDORES —el historial es un dato del proveedor— y el filtro por
///   cliente en sesión lo pone el controller en cada consulta, por los dos
///   caminos (la orden y el proveedor).
///
/// LOS TOTALES VAN POR MONEDA (criterio 2)
///   El SP los trae por ventana en cada fila; acá se pintan una vez por
///   moneda. Nunca se suman entre sí.
/// </summary>
public partial class View_Terceros_Proveedores_ProveedorHistorial : System.Web.UI.Page
{
    /// <summary>Lo que se pintó, para que la exportación baje exactamente eso.</summary>
    private List<ProveedorHistorial> _mostrado;

    /// <summary>
    /// El rango vigente. Va en ViewState y no se lee del calendario en cada
    /// postback: el calendario es un control del filtro y se reconstruye;
    /// lo que el usuario APLICO tiene que sobrevivir a cambiar el combo.
    /// </summary>
    private DateTime? Desde
    {
        get { return ViewState["Desde"] as DateTime?; }
        set { ViewState["Desde"] = value; }
    }

    private DateTime? Hasta
    {
        get { return ViewState["Hasta"] as DateTime?; }
        set { ViewState["Hasta"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("OTS_ID", "", Width: "3%");
            Grid.AddTemplateColumn("FECHA", "", "FECHA", Width: "11%");
            Grid.AddTemplateColumn("PROVEEDOR", "", "PROVEEDOR", Width: "20%");
            Grid.AddTemplateColumn("ORDEN", "", "ORDEN DE TRABAJO", Width: "22%");
            Grid.AddTemplateColumn("SERVICIO", "", "SERVICIO", Width: "26%");
            Grid.AddTemplateColumn("MONTO", "", "MONTO", Width: "18%");

            /* Se puede llegar desde la ficha del proveedor con ?Proveedor=id
               y desde cualquier parte con ?Desde=yyyy-MM-dd&Hasta=... */
            DateTime d, h;
            if (DateTime.TryParseExact(Request.QueryString["Desde"], "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d)) Desde = d;
            if (DateTime.TryParseExact(Request.QueryString["Hasta"], "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out h)) Hasta = h;
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack && sender is RadComboBox2)
        {
            RadComboBox2 ctrl = (RadComboBox2)sender;
            int cliente = SitioBase.Session.ClienteId();

            if (ctrl.ID == "cboProveedor")
            {
                ctrl.Items.Add(new RadComboBoxItem("Todos los proveedores", ""));

                List<Proveedor> lista = new ProveedorController().GetProveedores(new Proveedor { filtro_habilitado = true })
                                        ?? new List<Proveedor>();

                foreach (Proveedor p in lista)
                    ctrl.Items.Add(new RadComboBoxItem(p.prv_razon_social, p.prv_id.ToString()));

                int pedido;
                if (int.TryParse(Request.QueryString["Proveedor"], out pedido) && pedido > 0)
                {
                    RadComboBoxItem item = ctrl.FindItemByValue(pedido.ToString());
                    if (item != null) item.Selected = true;
                }
            }
            else if (ctrl.ID == "cboTipo")
            {
                ctrl.Items.Add(new RadComboBoxItem("Todos los tipos", ""));

                List<CatalogoValor> tipos = new CatalogoController().GetValoresPorCodigo("SERVICIO_TIPO", cliente)
                                            ?? new List<CatalogoValor>();

                foreach (CatalogoValor t in tipos)
                    ctrl.Items.Add(new RadComboBoxItem(t.valor_nombre, t.valor_id.ToString()));
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        /* La descarga escribe el archivo directo en la respuesta, y eso no
           sobrevive a un postback asíncrono. */
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkExportar);

        if (!IsPostBack) { calDesde.Value = Desde; calHasta.Value = Hasta; }

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        ProveedorController controller = new ProveedorController();
        ProveedorHistorial filtro = new ProveedorHistorial();

        RadComboBox2 cboProveedor = (RadComboBox2)wucFiltro.FindControl("cboProveedor");
        RadComboBox2 cboTipo = (RadComboBox2)wucFiltro.FindControl("cboTipo");

        int proveedor = 0, tipo = 0;
        if (cboProveedor != null) int.TryParse(cboProveedor.SelectedValue, out proveedor);
        if (cboTipo != null) int.TryParse(cboTipo.SelectedValue, out tipo);

        filtro.filtro_proveedor = proveedor;
        filtro.filtro_servicio_tipo = tipo;
        filtro.filtro_desde = Desde;
        filtro.filtro_hasta = Hasta;
        filtro.filtro = wucFiltro.Filtro();

        // El filtro por cliente en sesión lo pone el controller: no es opcional.
        List<ProveedorHistorial> lista = controller.GetHistorial(filtro) ?? new List<ProveedorHistorial>();

        _mostrado = lista;

        litTotales.Text = Totales(lista, proveedor > 0);

        // El rango vigente, dicho con todas sus letras.
        if (Desde != null || Hasta != null)
        {
            litFiltroActivo.Text = "<span class=\"grid-estado-chip is-info\"><i class=\"mdi mdi-calendar-range\"></i>" +
                                   (Desde == null ? "Hasta el " + Hasta.Value.ToString("dd MMM yyyy")
                                   : Hasta == null ? "Desde el " + Desde.Value.ToString("dd MMM yyyy")
                                   : "Del " + Desde.Value.ToString("dd MMM yyyy") + " al " + Hasta.Value.ToString("dd MMM yyyy")) +
                                   "</span>";
            lnkQuitarRango.Visible = true;
        }
        else
        {
            litFiltroActivo.Text = "";
            lnkQuitarRango.Visible = false;
        }

        pnlVacio.Visible = (lista.Count == 0);

        litVacio.Text = proveedor == 0 && tipo == 0 && Desde == null && Hasta == null && string.IsNullOrEmpty(filtro.filtro)
            ? "Todavía no se ha registrado ningún servicio contratado en las órdenes de trabajo."
            : "Con estos filtros no queda ningún servicio.";

        litCuenta.Text = lista.Count == 0 ? ""
                       : (lista.Count == 1 ? "1 servicio" : lista.Count + " servicios");

        Grid.DataSource = lista;
    }

    /// <summary>
    /// Una tarjeta por moneda con su total, y una con las órdenes en que
    /// participó el proveedor. Con varios proveedores en pantalla los
    /// totales por moneda se suman entre proveedores —siguen siendo de la
    /// misma moneda— y la de órdenes cuenta las distintas.
    ///
    /// Los montos se formatean acá; los códigos de moneda pasan por
    /// HtmlEncode.
    /// </summary>
    private string Totales(List<ProveedorHistorial> lista, bool unProveedor)
    {
        if (lista.Count == 0) return "";

        // moneda -> (código, nombre, total, servicios)
        Dictionary<int, decimal> total = new Dictionary<int, decimal>();
        Dictionary<int, int> cuenta = new Dictionary<int, int>();
        Dictionary<int, string> codigo = new Dictionary<int, string>();
        Dictionary<int, string> nombre = new Dictionary<int, string>();
        List<int> orden = new List<int>();
        HashSet<int> ordenes = new HashSet<int>();

        foreach (ProveedorHistorial h in lista)
        {
            if (!total.ContainsKey(h.moneda_grupo))
            {
                total[h.moneda_grupo] = 0;
                cuenta[h.moneda_grupo] = 0;
                codigo[h.moneda_grupo] = h.moneda_codigo;
                nombre[h.moneda_grupo] = h.moneda_nombre;
                orden.Add(h.moneda_grupo);
            }

            total[h.moneda_grupo] += h.ots_monto;
            cuenta[h.moneda_grupo] += 1;
            ordenes.Add(h.ots_orden_trabajo);
        }

        // Las monedas declaradas primero; "sin moneda" al final.
        orden.Sort(delegate (int a, int b)
        {
            if (a == 0) return 1;
            if (b == 0) return -1;
            return a.CompareTo(b);
        });

        StringBuilder sb = new StringBuilder();

        foreach (int m in orden)
        {
            bool sin = (m == 0);
            sb.Append("<div class=\"sg-ph-total" + (sin ? " is-sin" : "") + "\">");
            sb.Append("<span class=\"n\">" + Monto(total[m], codigo[m]) + "</span>");
            sb.Append("<span class=\"t\">" + Server.HtmlEncode(sin ? "Sin moneda declarada" : "Total en " + nombre[m]) +
                      " · " + cuenta[m] + (cuenta[m] == 1 ? " servicio" : " servicios") + "</span>");
            sb.Append("</div>");
        }

        sb.Append("<div class=\"sg-ph-total is-ordenes\">");
        sb.Append("<span class=\"n\">" + ordenes.Count + "</span>");
        sb.Append("<span class=\"t\">" + (ordenes.Count == 1 ? "Orden de trabajo" : "Órdenes de trabajo") +
                  (unProveedor ? " en que participó" : " con servicios") + "</span>");
        sb.Append("</div>");

        return sb.ToString();
    }

    /// <summary>
    /// El monto en su moneda. Los pesos van sin decimales —nadie factura
    /// centavos— y el resto con dos: 12,5 UF tiene que verse 12,50 y no 13.
    /// </summary>
    private static string Monto(decimal monto, string codigoMoneda)
    {
        string c = (codigoMoneda ?? "").Trim().ToUpperInvariant();
        string numero = (c == "CLP" || c == "SIN MONEDA") ? monto.ToString("N0") : monto.ToString("N2");
        return numero + "<small>" + (c == "SIN MONEDA" ? "" : c) + "</small>";
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem &&
            e.Item.ItemType != GridItemType.Item) return;

        GridDataItem item = e.Item as GridDataItem;
        if (item == null) return;

        ProveedorHistorial h = item.DataItem as ProveedorHistorial;
        if (h == null) return;

        // ---- Enlace a la ficha del proveedor ----
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + h.ots_proveedor));

        HyperLink abrir = new HyperLink();
        abrir.ID = "lnkAbrir" + item.ItemIndex;
        abrir.CssClass = "icono_Editar";
        abrir.ToolTip = "Abrir la ficha del proveedor";
        abrir.Attributes["aria-label"] = "Abrir la ficha del proveedor " + Server.HtmlEncode(h.prv_razon_social);
        abrir.NavigateUrl = "javascript:void(0)";
        abrir.Attributes.Add("onclick", "abrirProveedor('" + query + "')");
        item["OTS_ID"].Controls.Add(abrir);

        // ---- Fecha ----
        string fecha = "<div class=\"sg-ph-celda\"><strong>" + h.fecha_efectiva.ToString("dd MMM yyyy") + "</strong>";
        if (h.ots_fecha_documento != null && h.ots_fecha_documento.Value.Date != h.fecha_efectiva.Date)
            fecha += "<small><i class=\"mdi mdi-file-document-outline\"></i>doc. " + h.ots_fecha_documento.Value.ToString("dd MMM yyyy") + "</small>";
        item["FECHA"].Text = fecha + "</div>";

        // ---- Proveedor ----
        item["PROVEEDOR"].Text = "<div class=\"sg-ph-celda\"><strong>" + Server.HtmlEncode(h.prv_razon_social) + "</strong>" +
                                 "<small><i class=\"mdi mdi-card-account-details-outline\"></i>" + Server.HtmlEncode(h.prv_rut) + "</small></div>";

        // ---- Orden ----
        item["ORDEN"].Text = "<div class=\"sg-ph-celda\"><strong>OT " + h.otr_correlativo + "</strong>" +
                             "<small>" + Server.HtmlEncode(h.orden_titulo) + "</small>" +
                             (string.IsNullOrEmpty(h.orden_estado) ? "" : "<small><i class=\"mdi mdi-progress-check\"></i>" + Server.HtmlEncode(h.orden_estado) + "</small>") +
                             "</div>";

        // ---- Servicio ----
        string servicio = "<div class=\"sg-ph-celda\"><strong>" + Server.HtmlEncode(h.servicio_tipo_nombre) + "</strong>" +
                          "<small>" + Server.HtmlEncode(h.ots_descripcion) + "</small>";
        if (!string.IsNullOrEmpty(h.ots_documento_referencia))
            servicio += "<small><i class=\"mdi mdi-receipt-text-outline\"></i>" + Server.HtmlEncode(h.ots_documento_referencia) + "</small>";
        item["SERVICIO"].Text = servicio + "</div>";

        // ---- Monto ----
        string monto = "<div class=\"sg-ph-celda\"><span class=\"sg-ph-monto\">" + Monto(h.ots_monto, h.moneda_codigo) + "</span>";
        if (h.moneda_grupo == 0)
            monto += "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-help-circle-outline\"></i>Sin moneda</span>";
        else if (h.ots_cantidad != null && h.ots_monto_unitario != null && h.ots_cantidad != 1)
            monto += "<small>" + h.ots_cantidad.Value.ToString("N0") + " × " + Monto(h.ots_monto_unitario.Value, h.moneda_codigo) + "</small>";
        item["MONTO"].Text = monto + "</div>";

        item.CssClass += " sg-permit-row";
    }

    protected void btnAplicar_Click(object sender, EventArgs e)
    {
        Desde = calDesde.Value;
        Hasta = calHasta.Value;

        // Un rango al revés no es un error: es que se llenó al revés.
        if (Desde != null && Hasta != null && Desde > Hasta)
        {
            DateTime? aux = Desde; Desde = Hasta; Hasta = aux;
            calDesde.Value = Desde;
            calHasta.Value = Hasta;
        }
    }

    protected void lnkQuitarRango_Click(object sender, EventArgs e)
    {
        Desde = null;
        Hasta = null;

        calDesde.Value = null;
        calHasta.Value = null;
    }

    protected void lnkExportar_Click(object sender, EventArgs e)
    {
        try
        {
            /* Se comprueba en el SERVIDOR y no confiando en que el botón
               estaba visible: quien manda el postback a mano se lo salta. */
            if (!Token.Puede("VER PROVEEDORES"))
                throw new Exception("No tiene permiso para ver los proveedores.");

            // PreRender todavía no corrió en este postback: _mostrado está en null.
            CargarGrid();

            new ProveedorController().ExportarHistorial(_mostrado);
        }
        catch (System.Threading.ThreadAbortException)
        {
            // Response.End() la lanza siempre: es cómo termina una descarga.
            throw;
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
