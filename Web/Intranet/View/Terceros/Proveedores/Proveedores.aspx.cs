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
/// Proveedores — vista única con dos pestañas (10-10-2026).
///
/// Antes eran dos pantallas sueltas bajo la carpeta «Proveedores»:
///   - Maestro de proveedores (HU-060, bloque 91): listar, crear y editar.
///   - Historial de servicios (HU-065, bloques 108 y 236): solo lectura, el
///     gasto por contratista separado por moneda.
/// Se unifican en esta pantalla con pestañas, igual que se hizo en Activos y
/// Mantenimiento, para que Terceros quede con un único ítem «Proveedores».
/// El alta y la edición siguen en el modal (Proveedor.aspx).
///
/// LAS DOS PESTAÑAS COMPARTEN EL PERMISO
///   Ambas cuelgan de VER PROVEEDORES: el historial es un dato del proveedor.
///   El acceso lo exige el master contra el menú; el filtro por cliente en
///   sesión lo pone el controller en cada consulta, nunca la pantalla.
///
/// ELIMINAR NO BORRA
///   Deshabilita. Un proveedor con lotes recibidos o servicios contratados
///   aparece en el historial de compra y en el gasto del año: su nombre tiene
///   que seguir estando. El SP rechaza el borrado y dice cuántos registros
///   dependen de él.
/// </summary>
public partial class View_Terceros_Proveedores_Proveedores : System.Web.UI.Page
{
    /// <summary>Pestaña activa: "M" Maestro (por defecto) o "H" Historial.</summary>
    private string Tab
    {
        get { return (ViewState["Tab"] as string) ?? "M"; }
        set { ViewState["Tab"] = value; }
    }

    /// <summary>Lo que se pintó en el historial, para que la exportación baje exactamente eso.</summary>
    private List<ProveedorHistorial> _mostrado;

    /// <summary>
    /// El rango vigente del historial. Va en ViewState y no se lee del
    /// calendario en cada postback: el calendario es un control del filtro y
    /// se reconstruye; lo que el usuario APLICÓ tiene que sobrevivir a cambiar
    /// el combo o de pestaña.
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
            // ---- Columnas del Maestro ----
            GridMaestro.AddSelectColumn();
            GridMaestro.AddColumn("PRV_ID", "", Width: "5%");
            GridMaestro.AddColumn("PRV_RUT", "RUT", Width: "13%");
            GridMaestro.AddTemplateColumn("EMPRESA", "", "EMPRESA", Width: "30%");
            GridMaestro.AddTemplateColumn("CONTACTO", "", "CONTACTO", Width: "24%");
            GridMaestro.AddTemplateColumn("TIPO", "", "TIPO", Width: "16%");
            GridMaestro.AddTemplateColumn("MOVIMIENTO", "", "SE LE HA COMPRADO", Width: "14%",
                                          ItemPosition: HorizontalAlign.Center,
                                          HederPosition: HorizontalAlign.Center);
            GridMaestro.AddCheckboxColumn("PRV_HABILITADO", "HABILITADO");

            // ---- Columnas del Historial ----
            GridHistorial.AddColumn("OTS_ID", "", Width: "3%");
            GridHistorial.AddTemplateColumn("FECHA", "", "FECHA", Width: "11%");
            GridHistorial.AddTemplateColumn("PROVEEDOR", "", "PROVEEDOR", Width: "20%");
            GridHistorial.AddTemplateColumn("ORDEN", "", "ORDEN DE TRABAJO", Width: "22%");
            GridHistorial.AddTemplateColumn("SERVICIO", "", "SERVICIO", Width: "26%");
            GridHistorial.AddTemplateColumn("MONTO", "", "MONTO", Width: "18%");

            /* Se puede llegar desde la ficha/lista con ?Proveedor=id y desde
               cualquier parte con ?Desde=yyyy-MM-dd&Hasta=...; y abrir directo
               en el historial con ?tab=H. */
            string tab = (Request.QueryString["tab"] ?? "").Trim().ToUpperInvariant();
            if (tab == "H") Tab = "H";

            DateTime d, h;
            if (DateTime.TryParseExact(Request.QueryString["Desde"], "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d)) Desde = d;
            if (DateTime.TryParseExact(Request.QueryString["Hasta"], "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out h)) Hasta = h;
        }

        Tools.tools.RegisterPostBackScript(GridMaestro);
        Tools.tools.RegisterPostBackScript(GridHistorial);
    }

    /// <summary>Poblado de los combos del Historial (una sola vez).</summary>
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
            else if (ctrl.ID == "cboTipoServicio")
            {
                ctrl.Items.Add(new RadComboBoxItem("Todos los tipos", ""));

                List<CatalogoValor> tipos = new CatalogoController().GetValoresPorCodigo("SERVICIO_TIPO", cliente)
                                            ?? new List<CatalogoValor>();

                foreach (CatalogoValor t in tipos)
                    ctrl.Items.Add(new RadComboBoxItem(t.valor_nombre, t.valor_id.ToString()));
            }
        }
    }

    protected void Tab_Click(object sender, EventArgs e)
    {
        LinkButton lb = sender as LinkButton;
        if (lb != null && (lb.CommandArgument == "M" || lb.CommandArgument == "H"))
            Tab = lb.CommandArgument;
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool esHistorial = (Tab == "H");

        // ---- Pestañas, paneles y subtítulo ----
        tabMaestro.CssClass = "sg-ter-tab" + (esHistorial ? "" : " is-activa");
        tabHistorial.CssClass = "sg-ter-tab" + (esHistorial ? " is-activa" : "");
        if (!esHistorial) tabMaestro.Attributes["aria-selected"] = "true"; else tabHistorial.Attributes["aria-selected"] = "true";

        /* Los dos grupos de filtros viven dentro del template de wucFiltro, así
           que no son campos de la página: se alcanzan con FindControl, igual
           que los combos. */
        Control pfm = wucFiltro.FindControl("pnlFiltroMaestro");
        Control pfh = wucFiltro.FindControl("pnlFiltroHistorial");
        if (pfm != null) pfm.Visible = !esHistorial;
        if (pfh != null) pfh.Visible = esHistorial;

        pnlMaestro.Visible = !esHistorial;
        pnlHistorial.Visible = esHistorial;

        litSubtitulo.Text = esHistorial
            ? "Todo lo contratado a cada contratista, con el gasto separado por moneda, para negociar con datos."
            : "Las empresas que le prestan servicios a la planta y las que le venden repuestos.";

        if (esHistorial) BindHistorial();
        else BindMaestro();

        udPanel.Update();
    }

    // ============================================================ MAESTRO

    private void BindMaestro()
    {
        /* El botón se esconde a quien no puede, pero eso es cortesía, no
           seguridad: la potestad la valida el servidor en cada acción. */
        lnkNuevo.Visible = Token.PuedeFuncion("Crear y editar");
        lnkEliminar.Visible = Token.PuedeFuncion("Eliminar");

        CargarGridMaestro();
        GridMaestro.DataBind();
    }

    protected void CargarGridMaestro()
    {
        Proveedor filtro = new Proveedor();
        ProveedorController controller = new ProveedorController();

        RadComboBox2 cboTipo = (RadComboBox2)wucFiltro.FindControl("cboTipo");
        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        if (cboTipo != null)
        {
            if (cboTipo.SelectedValue == "C") filtro.filtro_es_contratista = true;
            else if (cboTipo.SelectedValue == "R") filtro.filtro_es_proveedor_repuesto = true;
        }

        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        GridMaestro.DataSource = controller.GetProveedores(filtro);
    }

    protected void GridMaestro_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem &&
            e.Item.ItemType != GridItemType.Item) return;

        GridDataItem item = e.Item as GridDataItem;

        if (item == null) return;

        Proveedor p = item.DataItem as Proveedor;

        if (p == null) return;

        // ---- Enlace a la ficha ----
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + p.prv_id));

        HyperLink editar = new HyperLink();
        editar.ID = "lnkEditar" + item.ItemIndex;
        editar.CssClass = "icono_Editar";
        editar.NavigateUrl = "javascript:void(0)";
        editar.Attributes.Add("onclick", "abrirProveedor('" + query + "')");

        item["PRV_ID"].Controls.Add(editar);

        /* ---- El historial de servicios (HU-065) ----
           Al lado del lápiz: quien mira la lista de contratistas quiere saber
           cuánto se le ha contratado a cada uno. Ahora es la otra pestaña de
           esta misma pantalla, con el proveedor ya elegido. */
        HyperLink historial = new HyperLink();
        historial.ID = "lnkHistorial" + item.ItemIndex;
        historial.CssClass = "icono_Editar";
        historial.ToolTip = "Ver el historial de servicios";
        historial.Text = "<i class=\"mdi mdi-history\"></i>";
        historial.NavigateUrl = ResolveUrl("~/View/Terceros/Proveedores/Proveedores.aspx") + "?tab=H&Proveedor=" + p.prv_id;
        item["PRV_ID"].Controls.Add(historial);

        /* ---- La empresa ----
           El nombre de fantasía arriba, que es como la gente la llama, y la
           razón social debajo. */
        string nombre = string.IsNullOrEmpty(p.prv_nombre_fantasia)
                      ? p.prv_razon_social : p.prv_nombre_fantasia;

        string empresa = "<strong>" + Server.HtmlEncode(nombre) + "</strong>";

        if (!string.IsNullOrEmpty(p.prv_nombre_fantasia))
            empresa += "<br /><span style=\"color:#777;font-size:11px;\">" +
                       Server.HtmlEncode(p.prv_razon_social) + "</span>";

        if (!string.IsNullOrEmpty(p.prv_giro))
            empresa += "<br /><span style=\"color:#999;font-size:11px;\">" +
                       Server.HtmlEncode(p.prv_giro) + "</span>";

        item["EMPRESA"].Text = empresa;

        // ---- Con quién se habla ----
        string contacto = "";

        if (!string.IsNullOrEmpty(p.prv_contacto))
            contacto += Server.HtmlEncode(p.prv_contacto);

        if (!string.IsNullOrEmpty(p.prv_email))
            contacto += (contacto.Length > 0 ? "<br />" : "") +
                        "<span style=\"color:#777;font-size:11px;\">" +
                        Server.HtmlEncode(p.prv_email) + "</span>";

        if (!string.IsNullOrEmpty(p.prv_telefono))
            contacto += (contacto.Length > 0 ? "<br />" : "") +
                        "<span style=\"color:#777;font-size:11px;\">" +
                        Server.HtmlEncode(p.prv_telefono) + "</span>";

        item["CONTACTO"].Text = contacto.Length > 0 ? contacto : "—";

        // ---- Qué es ----
        string tipo = "";

        if (p.prv_es_contratista)
            tipo += "<span class=\"grid-estado-chip is-info\">" +
                    "<i class=\"mdi mdi-hard-hat\"></i>Contratista</span>";

        if (p.prv_es_proveedor_repuesto)
            tipo += "<span class=\"grid-estado-chip is-acento\">" +
                    "<i class=\"mdi mdi-package-variant\"></i>Repuestos</span>";

        item["TIPO"].Text = tipo;

        /* ---- Cuánto se le ha comprado ----
           Dice de un vistazo si el proveedor está en uso, que es lo que
           determina si se puede eliminar. */
        string mov = "";

        if (p.lotes > 0)
            mov += p.lotes + (p.lotes == 1 ? " lote" : " lotes");

        if (p.servicios > 0)
            mov += (mov.Length > 0 ? "<br />" : "") +
                   p.servicios + (p.servicios == 1 ? " servicio" : " servicios");

        item["MOVIMIENTO"].Text = mov.Length > 0
            ? mov
            : "<span style=\"color:#aaa;\">sin uso</span>";
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            /* Se comprueba en el SERVIDOR, no confiando en que el botón estaba
               escondido: quien manda el postback a mano se salta el esconderlo. */
            if (!Token.PuedeFuncion("Eliminar"))
                throw new Exception("No tiene permiso para eliminar proveedores.");

            if (GridMaestro.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
                return;
            }

            ProveedorController controller = new ProveedorController();

            List<string> fallidos = new List<string>();
            int borrados = 0;

            foreach (string indice in GridMaestro.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = GridMaestro.MasterTableView.DataKeyValues[int.Parse(indice)];

                int id = int.Parse(value["prv_id"].ToString());

                Respuesta respuesta = controller.DeleteProveedor(id);

                if (respuesta.error) fallidos.Add(respuesta.detalle);
                else borrados++;
            }

            /* Se informa lo que pasó con CADA uno. Mostrar solo el último
               resultado dice "eliminado con éxito" cuando se seleccionaron
               tres y dos fueron rechazados. */
            if (fallidos.Count == 0)
            {
                Tools.tools.ClientAlert(
                    borrados == 1 ? "Proveedor eliminado con éxito."
                                  : borrados + " proveedores eliminados con éxito.", "ok", true);
            }
            else
            {
                string detalle = (borrados > 0 ? borrados + " eliminado(s). " : "") +
                                 string.Join(" ", fallidos.ToArray());

                Tools.tools.ClientAlert(detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    // ============================================================ HISTORIAL

    private void BindHistorial()
    {
        /* La descarga escribe el archivo directo en la respuesta, y eso no
           sobrevive a un postback asíncrono. */
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkExportar);

        if (!IsPostBack) { calDesde.Value = Desde; calHasta.Value = Hasta; }

        CargarGridHistorial();
        GridHistorial.DataBind();
    }

    protected void CargarGridHistorial()
    {
        ProveedorController controller = new ProveedorController();
        ProveedorHistorial filtro = new ProveedorHistorial();

        RadComboBox2 cboProveedor = (RadComboBox2)wucFiltro.FindControl("cboProveedor");
        RadComboBox2 cboTipoServicio = (RadComboBox2)wucFiltro.FindControl("cboTipoServicio");

        int proveedor = 0, tipo = 0;
        if (cboProveedor != null) int.TryParse(cboProveedor.SelectedValue, out proveedor);
        if (cboTipoServicio != null) int.TryParse(cboTipoServicio.SelectedValue, out tipo);

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

        GridHistorial.DataSource = lista;
    }

    /// <summary>
    /// Una tarjeta por moneda con su total, y una con las órdenes en que
    /// participó el proveedor. Los totales por moneda se suman entre
    /// proveedores —siguen siendo de la misma moneda— y la de órdenes cuenta
    /// las distintas. Los montos se formatean acá; los códigos de moneda
    /// pasan por HtmlEncode.
    /// </summary>
    private string Totales(List<ProveedorHistorial> lista, bool unProveedor)
    {
        if (lista.Count == 0) return "";

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

    protected void GridHistorial_ItemDataBound(object sender, GridItemEventArgs e)
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
            /* Se comprueba en el SERVIDOR y no confiando en que el botón estaba
               visible: quien manda el postback a mano se lo salta. */
            if (!Token.Puede("VER PROVEEDORES"))
                throw new Exception("No tiene permiso para ver los proveedores.");

            // PreRender todavía no corrió en este postback: _mostrado está en null.
            CargarGridHistorial();

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
