using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using WebControls;

/// <summary>
/// Historial de movimientos de inventario (HU-057 criterio 2).
///
/// "Cuando consulto los movimientos de un repuesto, los ajustes se
/// distinguen de los ingresos y de los consumos."
///
/// EL COLOR DICE QUÉ PASÓ, ANTES DE LEER
///   verde entra · rojo sale · ámbar se corrigió · violeta se movió de sitio
///
///   La familia la calcula el SP y llega en la fila. Deducirla acá del
///   nombre del tipo —que es texto y puede cambiar— sería una segunda regla
///   conviviendo con la de la base.
/// </summary>
public partial class View_Inventario_Movimientos_Movimientos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("IMO_ID", "", Width: "3%");
            Grid.AddColumn("IMO_FECHA_MOVIMIENTO_UTC", "FECHA", Width: "13%",
                DataFormat: "{0:dd-MM-yyyy HH:mm}");

            Grid.AddTemplateColumn("FAMILIA", "", "QUÉ PASÓ", Width: "17%");

            Grid.AddColumn("REPUESTO_CODIGO", "REPUESTO", Width: "14%");
            Grid.AddColumn("BODEGA_NOMBRE", "BODEGA", Width: "18%");

            Grid.AddTemplateColumn("CANTIDAD", "", "CANTIDAD", Width: "11%",
                ItemPosition: HorizontalAlign.Right, HederPosition: HorizontalAlign.Right);

            Grid.AddColumn("USUARIO_NOMBRE", "QUIÉN", Width: "12%");

            Grid.AddTemplateColumn("DETALLE", "", "MOTIVO", Width: "6%",
                ItemPosition: HorizontalAlign.Center, HederPosition: HorizontalAlign.Center);
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    /// <summary>
    /// Llena los combos del filtro. Los tipos salen de la tabla, no del
    /// markup: un catálogo copiado en un .aspx es el que nadie actualiza.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack && sender is RadComboBox2)
        {
            RadComboBox2 ctrl = (RadComboBox2)sender;

            switch (ctrl.ID)
            {
                case "cboTipo":

                    InventarioController ctrlInv = new InventarioController();

                    ctrl.Items.Add(new RadComboBoxItem("Todos", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = ctrlInv.GetTipos();
                    ctrl.DataValueField = "imt_id";
                    ctrl.DataTextField = "imt_nombre";
                    ctrl.DataBind();
                    break;

                case "cboUsuario":

                    InventarioController ctrlUsu = new InventarioController();

                    ctrl.Items.Add(new RadComboBoxItem("Todos", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = ctrlUsu.GetUsuariosConMovimiento();
                    ctrl.DataValueField = "usu_id";
                    ctrl.DataTextField = "etiqueta";
                    ctrl.DataBind();
                    break;

                case "cboBodega":

                    BodegaController ctrlBod = new BodegaController();

                    ctrl.Items.Add(new RadComboBoxItem("Todas", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = ctrlBod.GetBodegas(new Bodega { filtro_habilitado = true });
                    ctrl.DataValueField = "bod_id";
                    ctrl.DataTextField = "bod_nombre";
                    ctrl.DataBind();
                    break;
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        /* El botón de la barra registra un movimiento. Los tres permisos
           llevan a la misma ficha, y quien solo consulta no ve ninguno. */
        if (!Token.Puede("REGISTRAR INGRESO REPUESTO")
            && !Token.Puede("ENTREGAR REPUESTO")
            && !Token.Puede("AJUSTAR INVENTARIO"))
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

        InventarioMovimiento m = item.DataItem as InventarioMovimiento;

        if (m == null) return;

        // ---- Enlace al detalle ----
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + m.imo_id));

        HyperLink ver = new HyperLink();
        ver.ID = "lnkVer" + item.ItemIndex;
        ver.CssClass = "icono_Editar";
        ver.NavigateUrl = "javascript:void(0)";
        ver.Attributes.Add("onclick", "abrirMovimiento('" + query + "')");

        item["IMO_ID"].Controls.Add(ver);

        // ---- Qué pasó ----
        item["FAMILIA"].Controls.Add(new Literal { Text = Familia(m) });

        // ---- Cantidad, con su signo ----
        item["CANTIDAD"].Controls.Add(new Literal
        {
            Text = "<span class=\"sigma-inv-signo " + (m.signo > 0 ? "entra" : "sale") + "\">"
                 + (m.signo > 0 ? "+" : "−") + m.imo_cantidad.ToString("N2")
                 + "<span class=\"unidad\">" + Server.HtmlEncode(m.unidad_simbolo) + "</span></span>"
        });

        // ---- Motivo, destino del traslado, lote ----
        item["DETALLE"].Controls.Add(new Literal { Text = Detalle(m) });
    }

    /// <summary>
    /// El badge de la familia, con su icono y su color.
    ///
    /// Debajo, el nombre exacto del tipo: la familia agrupa —hay tres
    /// movimientos distintos dentro de AJUSTE— y quien audita necesita
    /// saber cuál fue.
    /// </summary>
    private string Familia(InventarioMovimiento m)
    {
        string clase, icono;

        switch (m.familia)
        {
            case "INGRESO":
                clase = "is-exito"; icono = "mdi-tray-arrow-down"; break;

            case "CONSUMO":
                clase = "is-alerta"; icono = "mdi-tray-arrow-up"; break;

            case "AJUSTE":
                clase = "is-advertencia"; icono = "mdi-tune-variant"; break;

            case "TRASLADO":
                clase = "is-info"; icono = "mdi-swap-horizontal"; break;

            default:
                clase = "is-neutro"; icono = "mdi-help-circle-outline"; break;
        }

        return "<span class=\"grid-estado-chip " + clase + "\">"
             + "<i class=\"mdi " + icono + "\"></i>" + Server.HtmlEncode(m.familia) + "</span>"
             + "<span class=\"sigma-inv-nota\">" + Server.HtmlEncode(m.tipo_nombre) + "</span>";
    }

    /// <summary>
    /// El detalle largo de la fila, detrás de una lupa.
    ///
    /// POR QUE NO VA EN LA CELDA
    ///   El motivo de un ajuste es una frase, no un dato: "Conteo físico del
    ///   28-08: faltaban 5 pares respecto del sistema". Puesta en la grilla
    ///   estira la fila a seis líneas y empuja fuera de pantalla lo que se
    ///   venía a mirar, que son la cantidad y el estado.
    ///
    /// EL TEXTO VIAJA EN UN ATRIBUTO, NO EN EL HTML
    ///   Lo escribió un usuario. Va HtmlEncode al atributo, y el JavaScript
    ///   lo inserta con textContent, nunca con innerHTML.
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

        // Sin nada que mostrar no se pinta una lupa que abre un panel vacío.
        if (lineas.Count == 0)
            return "<span class=\"sigma-inv-vacio\">—</span>";

        // El título del popover dice de qué movimiento es, porque una vez
        // abierto tapa la fila que lo originó.
        string titulo = m.familia + " · " + m.repuesto_codigo;

        /* El separador es el salto de linea (10), que es lo que corta el
           JavaScript del popover. Se escribe como caracter para no
           depender del escape. */
        string texto = string.Join(((char)10).ToString(), lineas.ToArray());

        return "<a class=\"sigma-inv-lupa\" href=\"javascript:void(0)\""
             + " onclick=\"sgMotivo(this)\""
             + " title=\"Ver el detalle\""
             + " data-titulo=\"" + Server.HtmlEncode(titulo) + "\""
             + " data-motivo=\"" + Server.HtmlEncode(texto) + "\">"
             + "<i class=\"mdi mdi-magnify\"></i></a>";
    }

    protected void CargarGrid()
    {
        InventarioController controller = new InventarioController();

        InventarioMovimiento filtro = new InventarioMovimiento();

        /* El texto busca en el código y el nombre del repuesto, y también en
           la OBSERVACIÓN: buscar "conteo físico" y que aparezcan los ajustes
           de ese día es media auditoría resuelta. Lo hace @FILTRO en
           SEL_INVENTARIO_MOVIMIENTO, parametrizado. */
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        RadComboBox2 cboTipo = (RadComboBox2)wucFiltro.FindControl("cboTipo");
        RadComboBox2 cboBodega = (RadComboBox2)wucFiltro.FindControl("cboBodega");

        if (cboTipo != null && !string.IsNullOrEmpty(cboTipo.SelectedValue))
            filtro.filtro_tipo = int.Parse(cboTipo.SelectedValue);

        if (cboBodega != null && !string.IsNullOrEmpty(cboBodega.SelectedValue))
            filtro.imo_bodega = int.Parse(cboBodega.SelectedValue);

        RadComboBox2 cboUsuario = (RadComboBox2)wucFiltro.FindControl("cboUsuario");

        if (cboUsuario != null && !string.IsNullOrEmpty(cboUsuario.SelectedValue))
            filtro.filtro_usuario = int.Parse(cboUsuario.SelectedValue);

        /* Las fechas se filtran EN EL SP con @DESDE y @HASTA. El SP ya
           resuelve el caso borde de "hasta": compara contra el dia SIGUIENTE,
           porque imo_fecha_movimiento_utc lleva hora y un <= a medianoche
           dejaria fuera todo lo del ultimo dia. */
        TextBox2 txtDesde = (TextBox2)wucFiltro.FindControl("txtDesde");
        TextBox2 txtHasta = (TextBox2)wucFiltro.FindControl("txtHasta");

        if (txtDesde != null) filtro.filtro_desde = LeerFecha(txtDesde.Text, "desde");
        if (txtHasta != null) filtro.filtro_hasta = LeerFecha(txtHasta.Text, "hasta");

        Grid.DataSource = controller.GetMovimientos(filtro);
    }

    /// <summary>
    /// Una fecha del filtro. Vacía es válida —significa "sin límite"— y una
    /// mal escrita se ignora en vez de voltear la pantalla: es un filtro,
    /// no un formulario que se está guardando.
    /// </summary>
    private DateTime? LeerFecha(string texto, string campo)
    {
        if (string.IsNullOrEmpty(texto) || string.IsNullOrEmpty(texto.Trim())) return null;

        string[] formatos = new string[] { "dd-MM-yyyy", "dd/MM/yyyy", "yyyy-MM-dd" };

        DateTime fecha;

        if (!DateTime.TryParseExact(texto.Trim(), formatos,
                                    System.Globalization.CultureInfo.InvariantCulture,
                                    System.Globalization.DateTimeStyles.None, out fecha))
            return null;

        return fecha;
    }
}
