using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Ficha de existencia de un repuesto (HU-056 criterio 1).
///
/// "Veo la existencia por bodega, su ubicación y sus umbrales, y se destaca
/// la bodega cuya existencia está bajo el mínimo." Esta pantalla es ese
/// criterio, entero y en una sola vista.
///
/// Es de SOLO LECTURA. Mover existencia se hace desde Movimientos, con su
/// propio permiso: consultar y mover son dos cosas distintas y las hace
/// gente distinta.
/// </summary>
public partial class View_Inventario_Existencias_Existencia : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        /* Querystring.Entero recibe el valor TAL COMO VIENE de la URL:
           descifra por dentro. Pasarle el resultado de Descifrar lo hace
           descifrar dos veces, la segunda falla, y como el helper no lanza
           devuelve 0 en silencio: la ficha se abre en blanco como si fuera
           un registro nuevo. */
        if (!IsPostBack)
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        Cargar();
        udPanel.Update();
    }

    protected void Cargar()
    {
        if (Id == 0)
        {
            litHeroTitulo.Text = "Sin repuesto";
            litHeroDetalle.Text = "No se indicó qué repuesto consultar.";
            return;
        }

        RepuestoController ctrlRepuesto = new RepuestoController();
        Repuesto repuesto = ctrlRepuesto.GetRepuesto(Id);

        InventarioController controller = new InventarioController();
        List<InventarioSaldo> saldos = controller.GetSaldos(new InventarioSaldo { isa_repuesto = Id });

        if (saldos == null) saldos = new List<InventarioSaldo>();

        decimal total = 0;
        int alertas = 0;

        foreach (InventarioSaldo s in saldos)
        {
            total += s.isa_cantidad;
            if (s.bajo_minimo || s.sobre_maximo) alertas++;
        }

        litHeroTitulo.Text = Server.HtmlEncode(repuesto.rep_codigo + " · " + repuesto.rep_nombre);

        /* "1 bodega(s)" es lo que escribe un programa, no una persona. */
        string donde = (saldos.Count == 1) ? "1 bodega" : saldos.Count + " bodegas";

        litHeroDetalle.Text = total.ToString("N2") + " " +
                              Server.HtmlEncode(repuesto.unidad_simbolo) + " en " + donde +
                              (repuesto.rep_controla_lote
                                  ? " &middot; <i class=\"mdi mdi-barcode\"></i> controla lote" : "");

        /* Cero existencia no es una alerta por si misma: puede ser un
           repuesto que nunca se compro. Lo que importa es si esta bajo un
           umbral que alguien definio. */
        if (alertas > 0)
            litChipEstado.Text = "<span class=\"sigma-modal-chip is-alerta\">" + alertas +
                                 " bodega(s) fuera de umbral</span>";
        else if (saldos.Count == 0)
            litChipEstado.Text = "<span class=\"sigma-modal-chip is-info\">Sin existencia registrada</span>";
        else
            litChipEstado.Text = "<span class=\"sigma-modal-chip is-exito\">Dentro de sus umbrales</span>";

        if (GridBodegas.Columns.Count == 0)
        {
            /* Mismas columnas que el listado de Existencias, a proposito:
               entrar a la ficha no deberia obligar a reaprender donde esta
               cada dato. La cantidad y su rango van juntos, y el estado en
               un chip. */
            GridBodegas.AddTemplateColumn("BODEGA", "", "BODEGA", Width: "34%");
            GridBodegas.AddColumn("UBICACION_CODIGO", "UBICACIÓN", Width: "18%");

            GridBodegas.AddTemplateColumn("EXISTENCIA", "", "EXISTENCIA", Width: "22%",
                ItemPosition: HorizontalAlign.Right, HederPosition: HorizontalAlign.Right);

            GridBodegas.AddTemplateColumn("ESTADO", "", "ESTADO", Width: "26%");
        }

        GridBodegas.DataSource = saldos;
        GridBodegas.DataBind();

        if (GridMovimientos.Columns.Count == 0)
        {
            GridMovimientos.AddColumn("IMO_FECHA_MOVIMIENTO_UTC", "FECHA", Width: "17%",
                DataFormat: "{0:dd-MM-yyyy HH:mm}");

            GridMovimientos.AddTemplateColumn("FAMILIA", "", "QUÉ PASÓ", Width: "23%");
            GridMovimientos.AddColumn("BODEGA_NOMBRE", "BODEGA", Width: "24%");

            GridMovimientos.AddTemplateColumn("CANTIDAD", "", "CANTIDAD", Width: "15%",
                ItemPosition: HorizontalAlign.Right, HederPosition: HorizontalAlign.Right);

            GridMovimientos.AddColumn("USUARIO_NOMBRE", "QUIÉN", Width: "15%");

            GridMovimientos.AddTemplateColumn("DETALLE", "", "MOTIVO", Width: "6%",
                ItemPosition: HorizontalAlign.Center, HederPosition: HorizontalAlign.Center);
        }

        GridMovimientos.DataSource = controller.GetMovimientos(new InventarioMovimiento { imo_repuesto = Id });
        GridMovimientos.DataBind();
    }

    protected void GridBodegas_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem &&
            e.Item.ItemType != GridItemType.Item) return;

        GridDataItem item = e.Item as GridDataItem;

        if (item == null) return;

        InventarioSaldo f = item.DataItem as InventarioSaldo;

        if (f == null) return;

        // Bodega y, debajo, en qué planta: la planta ocupaba una columna
        // entera para repetirse en todas las filas.
        item["BODEGA"].Controls.Add(new Literal
        {
            Text = Server.HtmlEncode(f.bodega_nombre)
                 + "<span class=\"sigma-inv-nota\">" + Server.HtmlEncode(f.planta_nombre) + "</span>"
        });

        if (string.IsNullOrEmpty(f.ubicacion_codigo))
            item["UBICACION_CODIGO"].Text = "<span class=\"sigma-inv-vacio\">sin registrar</span>";

        string clase = f.bajo_minimo ? " is-bajo" : (f.sobre_maximo ? " is-sobre" : "");

        item["EXISTENCIA"].Controls.Add(new Literal
        {
            Text = "<div class=\"sigma-inv-cantidad" + clase + "\">"
                 + "<span><span class=\"valor\">" + f.isa_cantidad.ToString("N2") + "</span>"
                 + "<span class=\"unidad\">" + Server.HtmlEncode(f.unidad_simbolo) + "</span></span>"
                 + Rango(f) + "</div>"
        });

        item["ESTADO"].Controls.Add(new Literal { Text = Estado(f) });
    }

    /// <summary>
    /// "mín 100 · máx 600". Sin umbrales no se escribe nada: el chip de
    /// estado ya dice que no hay ninguno definido.
    /// </summary>
    private string Rango(InventarioSaldo f)
    {
        if (f.rbs_stock_minimo == null && f.rbs_stock_maximo == null) return "";

        string texto = "";

        if (f.rbs_stock_minimo != null)
            texto = "mín " + f.rbs_stock_minimo.Value.ToString("N0");

        if (f.rbs_stock_maximo != null)
            texto += (texto.Length > 0 ? " · " : "") + "máx " + f.rbs_stock_maximo.Value.ToString("N0");

        return "<span class=\"rango\">" + texto + "</span>";
    }

    /// <summary>
    /// El mismo chip que el listado. Que la ficha use otro código de color
    /// obligaría a reaprenderlo al entrar.
    /// </summary>
    private string Estado(InventarioSaldo f)
    {
        if (f.bajo_minimo)
        {
            decimal falta = (f.rbs_stock_minimo ?? 0) - f.isa_cantidad;

            return "<span class=\"grid-estado-chip is-alerta\">"
                 + "<i class=\"mdi mdi-alert-circle\"></i>Faltan " + falta.ToString("N0") + "</span>";
        }

        if (f.sobre_maximo)
            return "<span class=\"grid-estado-chip is-advertencia\">"
                 + "<i class=\"mdi mdi-arrow-up-bold\"></i>Sobre el máximo</span>";

        if (f.rbs_stock_minimo == null)
            return "<span class=\"grid-estado-chip is-neutro\">"
                 + "<i class=\"mdi mdi-help-circle-outline\"></i>Sin umbral</span>";

        if (f.rbs_punto_reposicion != null && f.isa_cantidad <= f.rbs_punto_reposicion.Value)
            return "<span class=\"grid-estado-chip is-advertencia\">"
                 + "<i class=\"mdi mdi-cart-outline\"></i>Hora de pedir</span>";

        return "<span class=\"grid-estado-chip is-exito\">"
             + "<i class=\"mdi mdi-check-circle\"></i>En rango</span>";
    }

    /// <summary>
    /// Los movimientos, con el mismo código de color que el listado:
    /// verde entra, rojo sale, ámbar se corrigió, azul se movió de sitio.
    /// </summary>
    protected void GridMovimientos_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem &&
            e.Item.ItemType != GridItemType.Item) return;

        GridDataItem item = e.Item as GridDataItem;

        if (item == null) return;

        InventarioMovimiento m = item.DataItem as InventarioMovimiento;

        if (m == null) return;

        string clase, icono;

        switch (m.familia)
        {
            case "INGRESO":  clase = "is-exito";       icono = "mdi-tray-arrow-down"; break;
            case "CONSUMO":  clase = "is-alerta";      icono = "mdi-tray-arrow-up";   break;
            case "AJUSTE":   clase = "is-advertencia"; icono = "mdi-tune-variant";    break;
            case "TRASLADO": clase = "is-info";        icono = "mdi-swap-horizontal"; break;
            default:         clase = "is-neutro";      icono = "mdi-help-circle-outline"; break;
        }

        item["FAMILIA"].Controls.Add(new Literal
        {
            Text = "<span class=\"grid-estado-chip " + clase + "\">"
                 + "<i class=\"mdi " + icono + "\"></i>" + Server.HtmlEncode(m.familia) + "</span>"
                 + "<span class=\"sigma-inv-nota\">" + Server.HtmlEncode(m.tipo_nombre) + "</span>"
        });

        item["CANTIDAD"].Controls.Add(new Literal
        {
            Text = "<span class=\"sigma-inv-signo " + (m.signo > 0 ? "entra" : "sale") + "\">"
                 + (m.signo > 0 ? "+" : "−") + m.imo_cantidad.ToString("N2")
                 + "<span class=\"unidad\">" + Server.HtmlEncode(m.unidad_simbolo) + "</span></span>"
        });

        item["DETALLE"].Controls.Add(new Literal { Text = Detalle(m) });
    }

    /// <summary>
    /// El detalle largo detrás de una lupa. Igual que en el listado: una
    /// frase de seis líneas dentro de un modal deja la grilla sin espacio.
    /// </summary>
    private string Detalle(InventarioMovimiento m)
    {
        List<string> lineas = new List<string>();

        if (!string.IsNullOrEmpty(m.bodega_destino_nombre))
            lineas.Add("Destino: " + m.bodega_destino_nombre);

        if (!string.IsNullOrEmpty(m.lote_codigo))
            lineas.Add("Lote: " + m.lote_codigo);

        if (m.imo_orden_trabajo != null)
            lineas.Add("Orden de trabajo: " + m.imo_orden_trabajo.Value);

        if (!string.IsNullOrEmpty(m.imo_observacion))
            lineas.Add(m.imo_observacion);

        if (lineas.Count == 0)
            return "<span class=\"sigma-inv-vacio\">—</span>";

        string texto = string.Join(((char)10).ToString(), lineas.ToArray());

        return "<a class=\"sigma-inv-lupa\" href=\"javascript:void(0)\""
             + " onclick=\"sgMotivo(this)\" title=\"Ver el detalle\""
             + " data-titulo=\"" + Server.HtmlEncode(m.familia + " · " + m.tipo_nombre) + "\""
             + " data-motivo=\"" + Server.HtmlEncode(texto) + "\">"
             + "<i class=\"mdi mdi-magnify\"></i></a>";
    }
}
