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
/// Ficha e historial de un activo, solo lectura (HU-037). Vista 360°: encabezado
/// con estado, tarjeta de resumen con imagen y métricas, pestañas, línea de
/// tiempo y panel lateral. SIEMPRE se filtra por el cliente en sesión.
/// </summary>
public partial class View_Activos_Ficha_ActivoFicha : System.Web.UI.Page
{
    private const int TOPE_EVENTOS = 200;

    protected void Page_Load(object sender, EventArgs e)
    {
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

    protected void btnBuscar_Click(object sender, EventArgs e) { }

    // Al elegir un activo, el postback recarga la ficha en PreRender: no hay
    // que apretar ningún botón.
    protected void cboActivo_SelectedIndexChanged(object sender, EventArgs e) { }

    protected int ActivoSeleccionado()
    {
        int id;
        if (cboActivo != null && int.TryParse(cboActivo.SelectedValue, out id)) return id;
        return 0;
    }

    protected void Cargar()
    {
        int activo = ActivoSeleccionado();

        pnlSinActivo.Visible = (activo == 0);
        pnlFicha.Visible = (activo > 0);
        if (activo == 0) return;

        ActivoController controller = new ActivoController();
        Activo a = controller.GetActivo(activo);

        // GetActivo no filtra por cliente; se verifica para no mostrar la ficha
        // de otra empresa.
        if (a == null || a.act_id == 0 || a.act_cliente != SitioBase.Session.ClienteId())
        {
            pnlFicha.Visible = false;
            pnlSinActivo.Visible = true;
            return;
        }

        CargarFicha(a);
        CargarHistorial(activo);
    }

    protected void CargarFicha(Activo a)
    {
        string codigo = Server.HtmlEncode(a.act_codigo);
        string nombre = Server.HtmlEncode(a.act_nombre);
        string tipo = Server.HtmlEncode(string.IsNullOrEmpty(a.tipo_nombre) ? "—" : a.tipo_nombre);
        string planta = Server.HtmlEncode(string.IsNullOrEmpty(a.planta_nombre) ? "—" : a.planta_nombre);
        string area = Server.HtmlEncode(string.IsNullOrEmpty(a.area_nombre) ? "—" : a.area_nombre);
        string estado = Server.HtmlEncode(string.IsNullOrEmpty(a.estado_nombre) ? "—" : a.estado_nombre);
        string critic = Server.HtmlEncode(string.IsNullOrEmpty(a.criticidad_nombre) ? "—" : a.criticidad_nombre);

        // Encabezado
        litHeroCodigo.Text = codigo;
        litHeroNombre.Text = nombre;
        litBadges.Text = BadgeEstado(a.act_activo_estado, estado) + BadgeCriticidad(critic);

        // Tarjeta resumen
        litIdentCodigo.Text = codigo;
        litTipo.Text = tipo;
        litPlanta.Text = planta;
        litArea.Text = area;
        litImagen.Text = ImagenActivo(a.act_id);

        // Métricas
        litTileEstado.Text = "<span class=\"" + ClaseColorEstado(a.act_activo_estado) + "\">" + estado + "</span>";
        litTileCriticidad.Text = "<span class=\"" + ClaseColorCriticidad(critic) + "\">" + critic + "</span>";

        // Panel lateral — ficha técnica
        litFtCodigo.Text = codigo;
        litFtTipo.Text = tipo;
        litFtPlanta.Text = planta;
        litFtArea.Text = area;
        litFtEstado.Text = "<span class=\"" + ClaseColorEstado(a.act_activo_estado) + "\">" + estado + "</span>";
        litFtCriticidad.Text = "<span class=\"" + ClaseColorCriticidad(critic) + "\">" + critic + "</span>";

        // Resumen (pestaña)
        string desc = string.IsNullOrEmpty(a.act_descripcion) ? "Sin descripción registrada." : Server.HtmlEncode(a.act_descripcion);
        StringBuilder r = new StringBuilder();
        r.Append("<p style=\"margin:0 0 12px;color:#475569;font-size:13px;line-height:1.6;\">" + desc + "</p>");
        if (!string.IsNullOrEmpty(a.act_numero_serie))
            r.Append("<div style=\"font-size:12.5px;color:#64748b;\"><strong>N° de serie:</strong> " + Server.HtmlEncode(a.act_numero_serie) + "</div>");
        if (!string.IsNullOrEmpty(a.act_fabricante))
            r.Append("<div style=\"font-size:12.5px;color:#64748b;margin-top:4px;\"><strong>Fabricante:</strong> " + Server.HtmlEncode(a.act_fabricante) + "</div>");
        litResumen.Text = r.ToString();

        // Enlaces de acción
        string q = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + a.act_id));
        string urlEditar = ResolveUrl("~/View/Activos/Activos/Activo.aspx");
        string onclickEditar = "return SigmaModal.open({url:'" + urlEditar + "?query=" + q + "', title:'Editar activo', width:960, initialHeight:620});";
        hlEditar.Attributes["onclick"] = onclickEditar;
        hlAccEditar.Attributes["onclick"] = onclickEditar;

        hlComponentes.NavigateUrl = ResolveUrl("~/View/Activos/Componentes/ActivoComponentes.aspx");
        hlAccComponentes.NavigateUrl = ResolveUrl("~/View/Activos/Componentes/ActivoComponentes.aspx");
        hlMedidores.NavigateUrl = ResolveUrl("~/View/Activos/Medidores/ActivoMedidores.aspx");
        hlAccCambiar.NavigateUrl = ResolveUrl("~/View/Activos/Estado/ActivoEstado.aspx");
        hlAtributos.NavigateUrl = ResolveUrl("~/View/Activos/Atributos/AtributoTecnicos.aspx");
        hlGenerarOT.NavigateUrl = ResolveUrl("~/Default.aspx");
        hlAccOT.NavigateUrl = ResolveUrl("~/Default.aspx");

        CargarTabs(a);
    }

    /// <summary>
    /// Carga las pestañas centralizadas del activo: componentes, medidores y
    /// atributos técnicos del tipo. Solo lectura (el ABM completo se abre con
    /// "Gestionar"). Reutiliza los controllers de cada módulo.
    /// </summary>
    protected void CargarTabs(Activo a)
    {
        int cliente = SitioBase.Session.ClienteId();

        // Componentes del activo
        var lc = new ActivoComponenteController().GetComponentes(new ActivoComponente
        { aco_cliente = cliente, filtro_activo = a.act_id, filtro_habilitado = true });
        if (lc == null) lc = new System.Collections.Generic.List<ActivoComponente>();
        rptComponentes.DataSource = lc; rptComponentes.DataBind();
        pnlSinComponentes.Visible = (lc.Count == 0);

        // Medidores del activo
        var lm = new ActivoMedidorController().GetActivoMedidores(new ActivoMedidor
        { ame_cliente = cliente, filtro_activo = a.act_id, filtro_habilitado = true });
        if (lm == null) lm = new System.Collections.Generic.List<ActivoMedidor>();
        rptMedidores.DataSource = lm; rptMedidores.DataBind();
        pnlSinMedidores.Visible = (lm.Count == 0);

        // Atributos técnicos del TIPO del activo
        var la = new AtributoTecnicoController().GetAtributos(new AtributoTecnico
        { filtro_cliente = cliente, filtro_activo_tipo = a.act_activo_tipo, filtro_habilitado = true });
        if (la == null) la = new System.Collections.Generic.List<AtributoTecnico>();
        rptAtributos.DataSource = la; rptAtributos.DataBind();
        pnlSinAtributos.Visible = (la.Count == 0);
    }

    protected void CargarHistorial(int activo)
    {
        int total;
        List<ActivoFichaEvento> datos = LeerHistorial(activo, out total);
        if (datos == null) datos = new List<ActivoFichaEvento>();

        rptHistorial.DataSource = datos;
        rptHistorial.DataBind();

        pnlSinEventos.Visible = (datos.Count == 0);
        litEventos.Text = datos.Count.ToString();

        // Último evento = el más reciente (la lista viene ordenada desc).
        if (datos.Count > 0 && datos[0].fecha.HasValue)
            litUltimoEvento.Text = datos[0].fecha.Value.ToString("dd MMM yyyy");
        else
            litUltimoEvento.Text = "—";
    }

    private List<ActivoFichaEvento> LeerHistorial(int activo, out int total)
    {
        string tipo = (cboTipo != null) ? cboTipo.SelectedValue : "";
        DateTime? desde = (calDesde != null) ? calDesde.Value : null;
        DateTime? hasta = (calHasta != null) ? calHasta.Value : null;

        ActivoFichaController controller = new ActivoFichaController();
        return controller.GetHistorial(activo, SitioBase.Session.ClienteId(), tipo,
                                       desde, hasta, true, 1, TOPE_EVENTOS, out total);
    }

    /* ---- Helpers de presentación (usados por el Repeater y la ficha) ---- */

    public string FechaLarga(object f)
    {
        if (f == null || f == DBNull.Value) return "";
        DateTime d = Convert.ToDateTime(f);
        return d.ToString("dd MMM yyyy") + " · " + d.ToString("HH:mm");
    }

    public string TipoEtiqueta(object t)
    {
        string tipo = t == null ? "" : t.ToString();
        return tipo == "ESTADO" ? "Estado"
             : tipo == "POSICION" ? "Posición"
             : tipo == "MEDICION" ? "Medición" : tipo;
    }

    public string TipoClase(object t)
    {
        string tipo = t == null ? "" : t.ToString();
        return tipo == "ESTADO" ? "is-estado"
             : tipo == "POSICION" ? "is-posicion"
             : tipo == "MEDICION" ? "is-medicion" : "";
    }

    private string BadgeEstado(int idEstado, string texto)
    {
        string color = idEstado == 1 ? "is-verde"
                     : (idEstado == 2 || idEstado == 4) ? "is-amarillo"
                     : (idEstado == 3 || idEstado == 5 || idEstado == 6) ? "is-rojo" : "is-gris";
        return "<span class=\"sigma-af-badge " + color + "\">" + texto + "</span>";
    }

    private string ClaseColorEstado(int idEstado)
    {
        return idEstado == 1 ? "val is-verde"
             : (idEstado == 3 || idEstado == 5 || idEstado == 6) ? "val is-rojo" : "val";
    }

    private bool EsCritica(string critic)
    {
        string c = (critic ?? "").ToUpperInvariant();
        return c.Contains("CRÍT") || c.Contains("CRIT") || c.Contains("ALTA");
    }

    private string BadgeCriticidad(string critic)
    {
        string color = EsCritica(critic) ? "is-rojo"
                     : (critic ?? "").ToUpperInvariant().Contains("MEDIA") ? "is-amarillo" : "is-gris";
        return "<span class=\"sigma-af-badge " + color + "\">Criticidad " + critic + "</span>";
    }

    private string ClaseColorCriticidad(string critic)
    {
        return EsCritica(critic) ? "val is-rojo" : "val";
    }

    private string ImagenActivo(int activo)
    {
        ActivoImagenController c = new ActivoImagenController();
        int idArchivo = c.GetImagenId(activo, SitioBase.Session.ClienteId());
        if (idArchivo > 0)
            return "<img src=\"" + Server.HtmlEncode(UrlArchivo.Ver(idArchivo)) + "\" alt=\"Imagen del activo\" />";

        // Sin imagen: ilustración de respaldo (gráfico de un equipo).
        return "<svg class=\"sigma-af-motor\" viewBox=\"0 0 64 64\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">"
             + "<rect x=\"10\" y=\"24\" width=\"30\" height=\"20\" rx=\"3\" fill=\"#ffffff\" opacity=\".92\"/>"
             + "<rect x=\"40\" y=\"29\" width=\"12\" height=\"10\" rx=\"2\" fill=\"#ffffff\" opacity=\".75\"/>"
             + "<circle cx=\"25\" cy=\"34\" r=\"7\" fill=\"#7c6cff\"/>"
             + "<circle cx=\"25\" cy=\"34\" r=\"2.6\" fill=\"#ffffff\"/>"
             + "<rect x=\"14\" y=\"44\" width=\"26\" height=\"4\" rx=\"2\" fill=\"#ffffff\" opacity=\".6\"/>"
             + "<path d=\"M52 20l3 3M52 48l3-3\" stroke=\"#ffffff\" stroke-width=\"2\" stroke-linecap=\"round\" opacity=\".7\"/>"
             + "</svg>";
    }

    /// <summary>Exporta el historial completo del activo a Excel (tabla HTML).</summary>
    protected void lnkExportar_Click(object sender, EventArgs e)
    {
        try
        {
            int activo = ActivoSeleccionado();
            if (activo == 0) { Tools.tools.ClientAlert("Elija un activo primero."); return; }

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
        catch (System.Threading.ThreadAbortException) { }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message); }
    }
}
