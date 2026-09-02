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
/// Ficha e historial de un activo, solo lectura (HU-037).
///
/// Muestra la ficha del activo elegido (CA1) y su línea de tiempo (CA2):
/// cambios de estado, de posición y mediciones, unidos por SEL_ACTIVO_FICHA,
/// con filtros por tipo de evento y rango de fechas. SIEMPRE se filtra por el
/// cliente en sesión: un activo es de una empresa, y el SP rechaza el de otra.
/// </summary>
public partial class View_Activos_Ficha_ActivoFicha : System.Web.UI.Page
{
    // Tope de eventos que la grilla trae de una vez; la paginación fina la
    // hace RadGrid sobre este conjunto. El SP soporta paginación real para la
    // API; en la web basta con esto para los volúmenes del sprint.
    private const int TOPE_EVENTOS = 200;

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("FECHA", "FECHA", Width: "16%");
            Grid.AddColumn("TIPO_EVENTO", "TIPO", Width: "14%");
            Grid.AddColumn("TITULO", "EVENTO", Width: "34%");
            Grid.AddColumn("DETALLE", "DETALLE", Width: "24%");
            Grid.AddColumn("USUARIO_NOMBRE", "USUARIO", Width: "12%");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        if (ctrl.ID != "cboActivo") return;

        ActivoController controller = new ActivoController();
        List<Activo> lista = controller.GetActivos(
            new Activo { act_cliente = SitioBase.Session.ClienteId() });

        ctrl.Items.Add(new RadComboBoxItem("Seleccione un activo...", ""));
        ctrl.AppendDataBoundItems = true;

        if (lista != null)
            foreach (Activo a in lista)
                ctrl.Items.Add(new RadComboBoxItem(a.act_codigo + " — " + a.act_nombre, a.act_id.ToString()));
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;
        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;
        if (!hayCliente) return;

        Cargar();
        udPanel.Update();
    }

    protected void btnBuscar_Click(object sender, EventArgs e)
    {
        // El postback ya recarga en PreRender; el handler existe para que el
        // botón dispare el ciclo.
    }

    protected int ActivoSeleccionado()
    {
        RadComboBox2 cbo = (RadComboBox2)wucFiltro.FindControl("cboActivo");
        int id;
        if (cbo != null && int.TryParse(cbo.SelectedValue, out id)) return id;
        return 0;
    }

    protected void Cargar()
    {
        int activo = ActivoSeleccionado();

        pnlSinActivo.Visible = (activo == 0);
        pnlFicha.Visible = (activo > 0);
        pnlHistorial.Visible = (activo > 0);

        if (activo == 0) return;

        CargarFicha(activo);
        CargarHistorial(activo);
    }

    /// <summary>La ficha del activo (CA1): datos que devuelve SEL_ACTIVO.</summary>
    protected void CargarFicha(int activo)
    {
        ActivoController controller = new ActivoController();
        Activo a = controller.GetActivo(activo);

        // GetActivo no filtra por cliente; se verifica que sea del cliente en
        // sesión para no mostrar la ficha de otra empresa.
        if (a == null || a.act_id == 0 || a.act_cliente != SitioBase.Session.ClienteId())
        {
            pnlFicha.Visible = false;
            pnlHistorial.Visible = false;
            pnlSinActivo.Visible = true;
            return;
        }

        lblCodigo.Text = a.act_codigo;
        lblNombre.Text = a.act_nombre;
        lblPlanta.Text = a.planta_nombre;
        lblArea.Text = string.IsNullOrEmpty(a.area_nombre) ? "—" : a.area_nombre;
        lblTipo.Text = a.tipo_nombre;
        lblEstado.Text = a.estado_nombre;
        lblCriticidad.Text = a.criticidad_nombre;
    }

    protected void CargarHistorial(int activo)
    {
        int total;
        Grid.DataSource = LeerHistorial(activo, out total);
        Grid.DataBind();
    }

    private List<ActivoFichaEvento> LeerHistorial(int activo, out int total)
    {
        RadComboBox2 cboTipoCtrl = (RadComboBox2)wucFiltro.FindControl("cboTipo");
        WebControls.Calendar calDesdeCtrl = (WebControls.Calendar)wucFiltro.FindControl("calDesde");
        WebControls.Calendar calHastaCtrl = (WebControls.Calendar)wucFiltro.FindControl("calHasta");

        string tipo = (cboTipoCtrl != null) ? cboTipoCtrl.SelectedValue : "";
        DateTime? desde = (calDesdeCtrl != null) ? calDesdeCtrl.Value : null;
        DateTime? hasta = (calHastaCtrl != null) ? calHastaCtrl.Value : null;

        ActivoFichaController controller = new ActivoFichaController();
        return controller.GetHistorial(activo, SitioBase.Session.ClienteId(), tipo,
                                       desde, hasta, true, 1, TOPE_EVENTOS, out total);
    }

    protected void rgrHistorial_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (!(e.Item is GridDataItem)) return;
        GridDataItem item = (GridDataItem)e.Item;

        // La fecha se muestra dd-MM-yyyy HH:mm.
        object f = DataBinder.Eval(item.DataItem, "fecha");
        if (f != null && f != DBNull.Value)
            item["FECHA"].Text = Convert.ToDateTime(f).ToString("dd-MM-yyyy HH:mm");

        // Un color por familia de evento, para leer la línea de un vistazo.
        object t = DataBinder.Eval(item.DataItem, "tipo_evento");
        string tipo = t == null ? "" : t.ToString();
        string etiqueta = tipo == "ESTADO" ? "Estado"
                        : tipo == "POSICION" ? "Posición"
                        : tipo == "MEDICION" ? "Medición" : tipo;
        item["TIPO_EVENTO"].Text = etiqueta;
    }

    /// <summary>
    /// Exporta el historial completo del activo a Excel. Se usa el truco
    /// clásico de una tabla HTML con content-type de Excel: no agrega
    /// dependencias y abre bien en Excel y LibreOffice.
    /// </summary>
    protected void lnkExportar_Click(object sender, EventArgs e)
    {
        try
        {
            int activo = ActivoSeleccionado();
            if (activo == 0)
            {
                Tools.tools.ClientAlert("Elija un activo primero.");
                return;
            }

            int total;
            List<ActivoFichaEvento> datos = LeerHistorial(activo, out total);
            if (datos == null) datos = new List<ActivoFichaEvento>();

            StringBuilder sb = new StringBuilder();
            sb.Append("<table border='1'><tr>");
            sb.Append("<th>Fecha</th><th>Tipo</th><th>Evento</th><th>Detalle</th><th>Usuario</th></tr>");
            foreach (ActivoFichaEvento ev in datos)
            {
                sb.Append("<tr>");
                sb.Append("<td>" + (ev.fecha.HasValue ? ev.fecha.Value.ToString("dd-MM-yyyy HH:mm") : "") + "</td>");
                sb.Append("<td>" + Server.HtmlEncode(ev.tipo_evento) + "</td>");
                sb.Append("<td>" + Server.HtmlEncode(ev.titulo) + "</td>");
                sb.Append("<td>" + Server.HtmlEncode(ev.detalle) + "</td>");
                sb.Append("<td>" + Server.HtmlEncode(ev.usuario_nombre) + "</td>");
                sb.Append("</tr>");
            }
            sb.Append("</table>");

            Response.Clear();
            Response.Buffer = true;
            Response.AddHeader("content-disposition", "attachment;filename=Historial_Activo.xls");
            Response.ContentType = "application/vnd.ms-excel";
            Response.Charset = "UTF-8";
            Response.ContentEncoding = System.Text.Encoding.UTF8;
            Response.Write("<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">");
            Response.Write(sb.ToString());
            Response.Flush();
            Response.End();
        }
        catch (System.Threading.ThreadAbortException)
        {
            // Response.End lanza esta excepción por diseño; se ignora.
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }
}
