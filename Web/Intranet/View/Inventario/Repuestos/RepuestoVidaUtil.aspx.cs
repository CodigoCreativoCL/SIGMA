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
/// Vida útil real de los repuestos instalados (HU-058, bloques 108 y 236).
///
/// "Para ajustar la frecuencia del plan con datos y no con supuestos."
///
/// SOLO LECTURA
///   Nadie crea una vida útil: la fila nace cuando un técnico instala o
///   retira la pieza en una orden de trabajo. Esta pantalla es cómo se lee.
///
/// EL ACCESO LO RESUELVE EL MASTER
///   Token.ExigirPagina() contra el menú: en SIGMA los permisos son datos,
///   no código. La pantalla cuelga de VER REPUESTOS —la vida útil es un
///   dato del repuesto— y el filtro por cliente en sesión lo pone el
///   controller en cada consulta.
///
/// TRES NUMEROS POR REPUESTO ANTES DE LA LISTA (criterio 3)
///   Promedio, mínima y máxima de las instalaciones CERRADAS del mismo
///   repuesto. Vienen calculados por el SP en cada fila (por ventana); acá
///   se pintan una vez por repuesto.
/// </summary>
public partial class View_Inventario_Repuestos_RepuestoVidaUtil : System.Web.UI.Page
{
    /// <summary>Lo que se pintó, para que la exportación baje exactamente eso.</summary>
    private List<RepuestoVidaUtil> _mostrado;

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("CRI_ID", "", Width: "3%");
            Grid.AddTemplateColumn("REPUESTO", "", "REPUESTO", Width: "20%");
            Grid.AddTemplateColumn("DONDE", "", "EQUIPO Y COMPONENTE", Width: "20%");
            Grid.AddTemplateColumn("PERIODO", "", "INSTALADA → RETIRADA", Width: "19%");
            Grid.AddTemplateColumn("HORAS", "", "VIDA ÚTIL (HORAS)", Width: "13%");
            Grid.AddTemplateColumn("DIAS", "", "VIDA ÚTIL (DÍAS)", Width: "10%");
            Grid.AddTemplateColumn("RETIRO", "", "RETIRO", Width: "15%");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack && sender is RadComboBox2)
        {
            RadComboBox2 ctrl = (RadComboBox2)sender;

            if (ctrl.ID == "cboRepuesto")
            {
                RepuestoController controller = new RepuestoController();

                ctrl.Items.Add(new RadComboBoxItem("Todos los repuestos", ""));

                /* Solo los que tienen alguna instalación registrada: un combo
                   con los trescientos repuestos del maestro, de los que
                   doscientos noventa no van a devolver nada, no ayuda a
                   elegir. */
                List<RepuestoVidaUtil> todas = controller.GetVidaUtil() ?? new List<RepuestoVidaUtil>();
                Dictionary<int, string> vistos = new Dictionary<int, string>();

                foreach (RepuestoVidaUtil v in todas)
                {
                    if (vistos.ContainsKey(v.cri_repuesto)) continue;
                    vistos[v.cri_repuesto] = v.rep_codigo;
                    ctrl.Items.Add(new RadComboBoxItem(v.rep_codigo + " · " + v.rep_nombre, v.cri_repuesto.ToString()));
                }

                /* Se puede llegar desde la ficha del repuesto con ?Repuesto=id:
                   ahí ya se sabe cuál se quiere mirar. */
                int pedido;
                if (int.TryParse(Request.QueryString["Repuesto"], out pedido) && pedido > 0)
                {
                    RadComboBoxItem item = ctrl.FindItemByValue(pedido.ToString());
                    if (item != null) item.Selected = true;
                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        /* La descarga escribe el archivo directo en la respuesta, y eso no
           sobrevive a un postback asíncrono: el UpdatePanel espera un
           fragmento y recibe un binario. */
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkExportar);

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        RepuestoController controller = new RepuestoController();
        RepuestoVidaUtil filtro = new RepuestoVidaUtil();

        RadComboBox2 cboRepuesto = (RadComboBox2)wucFiltro.FindControl("cboRepuesto");
        RadComboBox2 cboSituacion = (RadComboBox2)wucFiltro.FindControl("cboSituacion");

        int repuesto = 0;
        if (cboRepuesto != null) int.TryParse(cboRepuesto.SelectedValue, out repuesto);
        filtro.filtro_repuesto = repuesto;

        if (cboSituacion != null && !string.IsNullOrEmpty(cboSituacion.SelectedValue))
            filtro.filtro_solo_retirados = (cboSituacion.SelectedValue == "1");

        filtro.filtro = wucFiltro.Filtro();

        // El filtro por cliente en sesión lo pone el controller: no es opcional.
        List<RepuestoVidaUtil> lista = controller.GetVidaUtil(filtro) ?? new List<RepuestoVidaUtil>();

        _mostrado = lista;

        litComparacion.Text = Comparacion(lista);

        pnlVacio.Visible = (lista.Count == 0);

        litVacio.Text = repuesto == 0 && filtro.filtro_solo_retirados == null && string.IsNullOrEmpty(filtro.filtro)
            ? "Todavía no hay repuestos instalados ni retirados en órdenes de trabajo. " +
              "Cuando un técnico registre el cambio de una pieza, aparecerá acá con lo que duró."
            : "Con estos filtros no queda ninguna instalación.";

        litCuenta.Text = lista.Count == 0 ? ""
                       : (lista.Count == 1 ? "1 instalación" : lista.Count + " instalaciones");

        Grid.DataSource = lista;
    }

    /// <summary>
    /// Una tarjeta por repuesto con el promedio, la mínima y la máxima de
    /// sus instalaciones cerradas (criterio 3), y la esperada al lado para
    /// que la comparación salte a la vista.
    ///
    /// Todo lo que va al HTML pasa por HtmlEncode salvo los números, que
    /// se formatean acá mismo.
    /// </summary>
    private string Comparacion(List<RepuestoVidaUtil> lista)
    {
        StringBuilder sb = new StringBuilder();
        HashSet<int> pintados = new HashSet<int>();

        foreach (RepuestoVidaUtil v in lista)
        {
            if (pintados.Contains(v.cri_repuesto)) continue;
            pintados.Add(v.cri_repuesto);

            sb.Append("<div class=\"sg-vu-repuesto\">");
            sb.Append("<div class=\"titulo\"><strong>" + Server.HtmlEncode(v.rep_codigo + " · " + v.rep_nombre) + "</strong>");
            sb.Append("<small>" + v.instalaciones_cerradas + (v.instalaciones_cerradas == 1 ? " instalación cerrada" : " instalaciones cerradas") +
                      " de " + v.instalaciones_total + "</small></div>");

            if (v.instalaciones_cerradas == 0)
            {
                sb.Append("<div class=\"sg-vu-esperada\">Sin instalaciones retiradas todavía: no hay vida útil que comparar.</div>");
            }
            else
            {
                sb.Append("<div class=\"sg-vu-medidas\">");
                sb.Append(Medida("Promedio", v.promedio_horas, v.promedio_dias));
                sb.Append(Medida("Mínima", v.minimo_horas, v.minimo_dias));
                sb.Append(Medida("Máxima", v.maximo_horas, v.maximo_dias));
                sb.Append("</div>");
            }

            if (v.esperada_horas != null || v.esperada_dias != null)
            {
                sb.Append("<div class=\"sg-vu-esperada\"><i class=\"mdi mdi-target\"></i> Esperada en la ficha: ");
                if (v.esperada_horas != null) sb.Append("<strong>" + v.esperada_horas.Value.ToString("N0") + " h</strong>");
                if (v.esperada_horas != null && v.esperada_dias != null) sb.Append(" · ");
                if (v.esperada_dias != null) sb.Append("<strong>" + v.esperada_dias.Value.ToString("N0") + " días</strong>");
                sb.Append(Veredicto(v));
                sb.Append("</div>");
            }

            sb.Append("</div>");
        }

        return sb.ToString();
    }

    /// <summary>
    /// El promedio contra lo esperado, en una frase. Es el dato por el que
    /// alguien entra a esta pantalla: si las piezas duran menos de lo que
    /// dice la ficha, el plan está mal calibrado.
    /// </summary>
    private static string Veredicto(RepuestoVidaUtil v)
    {
        if (v.instalaciones_cerradas == 0) return "";

        if (v.esperada_horas != null && v.promedio_horas != null)
        {
            decimal razon = v.esperada_horas.Value == 0 ? 0 : v.promedio_horas.Value / v.esperada_horas.Value;
            if (razon < 0.8m)
                return " <span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-trending-down\"></i>Dura " + (razon * 100).ToString("N0") + "% de lo esperado</span>";
            if (razon > 1.2m)
                return " <span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-trending-up\"></i>Dura " + (razon * 100).ToString("N0") + "% de lo esperado</span>";
            return " <span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-check\"></i>Dentro de lo esperado</span>";
        }

        if (v.esperada_dias != null && v.promedio_dias != null)
        {
            decimal razon = v.esperada_dias.Value == 0 ? 0 : (decimal)v.promedio_dias.Value / v.esperada_dias.Value;
            if (razon < 0.8m)
                return " <span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-trending-down\"></i>Dura " + (razon * 100).ToString("N0") + "% de lo esperado</span>";
            if (razon > 1.2m)
                return " <span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-trending-up\"></i>Dura " + (razon * 100).ToString("N0") + "% de lo esperado</span>";
            return " <span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-check\"></i>Dentro de lo esperado</span>";
        }

        return "";
    }

    /// <summary>
    /// Una medida: las horas grandes si existen y los días debajo. Sin
    /// horas (criterio 2) el número grande son los días y se dice que el
    /// dato de horas no está disponible.
    /// </summary>
    private static string Medida(string rotulo, decimal? horas, int? dias)
    {
        string html = "<div class=\"sg-vu-medida\">";

        if (horas != null)
            html += "<div><span class=\"n\">" + horas.Value.ToString("N0") + "</span> <span class=\"u\">h</span></div>" +
                    "<div class=\"u\">" + (dias == null ? "" : dias.Value.ToString("N0") + " días") + "</div>";
        else
            html += "<div><span class=\"n\">" + (dias == null ? "—" : dias.Value.ToString("N0")) + "</span> <span class=\"u\">días</span></div>" +
                    "<div class=\"u\">horas no disponibles</div>";

        html += "<span class=\"t\">" + rotulo + "</span></div>";
        return html;
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem &&
            e.Item.ItemType != GridItemType.Item) return;

        GridDataItem item = e.Item as GridDataItem;
        if (item == null) return;

        RepuestoVidaUtil v = item.DataItem as RepuestoVidaUtil;
        if (v == null) return;

        // ---- Enlace a la ficha del repuesto ----
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + v.cri_repuesto));

        HyperLink abrir = new HyperLink();
        abrir.ID = "lnkAbrir" + item.ItemIndex;
        abrir.CssClass = "icono_Editar";
        abrir.ToolTip = "Abrir la ficha del repuesto";
        abrir.Attributes["aria-label"] = "Abrir la ficha del repuesto " + Server.HtmlEncode(v.rep_codigo);
        abrir.NavigateUrl = "javascript:void(0)";
        abrir.Attributes.Add("onclick", "abrirRepuesto('" + query + "')");
        item["CRI_ID"].Controls.Add(abrir);

        // ---- Qué pieza ----
        item["REPUESTO"].Text = "<div class=\"sg-vu-celda\"><strong>" + Server.HtmlEncode(v.rep_codigo) + "</strong>" +
                                "<small>" + Server.HtmlEncode(v.rep_nombre) + "</small>" +
                                (v.cri_cantidad != 1 ? "<small><i class=\"mdi mdi-numeric\"></i>Cantidad " + v.cri_cantidad.ToString("N0") + "</small>" : "") +
                                "</div>";

        // ---- Dónde ----
        item["DONDE"].Text = "<div class=\"sg-vu-celda\"><strong>" + Server.HtmlEncode((v.activo_codigo + " " + v.activo_nombre).Trim()) + "</strong>" +
                             "<small><i class=\"mdi mdi-cog-outline\"></i>" + Server.HtmlEncode((v.componente_codigo + " " + v.componente_nombre).Trim()) + "</small>" +
                             (string.IsNullOrEmpty(v.tecnico_nombre) ? "" : "<small><i class=\"mdi mdi-account-hard-hat\"></i>" + Server.HtmlEncode(v.tecnico_nombre) + "</small>") +
                             "</div>";

        // ---- Periodo ----
        string periodo = "<div class=\"sg-vu-celda\">" +
                         (v.instalada
                            ? "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-play-circle-outline\"></i>Instalada</span>"
                            : "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-stop-circle-outline\"></i>Retirada</span>") +
                         "<strong>" + v.fecha_instalacion.ToString("dd MMM yyyy") + " → " +
                         (v.fecha_retiro == null ? "hoy" : v.fecha_retiro.Value.ToString("dd MMM yyyy")) + "</strong>";

        if (v.ot_instalacion != null || v.ot_retiro != null)
            periodo += "<small><i class=\"mdi mdi-clipboard-text-outline\"></i>" +
                       (v.ot_instalacion == null ? "" : "OT " + v.ot_instalacion + " instala") +
                       (v.ot_instalacion != null && v.ot_retiro != null ? " · " : "") +
                       (v.ot_retiro == null ? "" : "OT " + v.ot_retiro + " retira") + "</small>";

        item["PERIODO"].Text = periodo + "</div>";

        // ---- Horas (criterios 1 y 2) ----
        if (v.tiene_horas)
            item["HORAS"].Text = "<div class=\"sg-vu-celda\"><span class=\"sg-vu-horas\">" + v.vida_util_horas.Value.ToString("N0") + " h</span>" +
                                 "<small><i class=\"mdi mdi-speedometer\"></i>" + v.cri_lectura_inicial.Value.ToString("N0") + " → " +
                                 v.cri_lectura_final.Value.ToString("N0") + " " + Server.HtmlEncode(v.medidor_unidad) + "</small></div>";
        else if (v.instalada && v.cri_lectura_inicial != null)
            item["HORAS"].Text = "<div class=\"sg-vu-celda\"><span class=\"sg-vu-horas is-sin\">En curso</span>" +
                                 "<small><i class=\"mdi mdi-speedometer\"></i>desde " + v.cri_lectura_inicial.Value.ToString("N0") + " " +
                                 Server.HtmlEncode(v.medidor_unidad) + "</small></div>";
        else
            item["HORAS"].Text = "<div class=\"sg-vu-celda\"><span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-timer-off-outline\"></i>Sin horómetro</span>" +
                                 "<small>el dato de horas no está disponible</small></div>";

        // ---- Días ----
        item["DIAS"].Text = "<div class=\"sg-vu-celda\"><span class=\"sg-vu-horas\">" + v.vida_util_dias.ToString("N0") + "</span>" +
                            "<small>" + (v.instalada ? "días y contando" : "días") + "</small></div>";

        // ---- Retiro ----
        if (v.instalada)
            item["RETIRO"].Text = "<span class=\"sigma-inv-vacio\">—</span>";
        else
            item["RETIRO"].Text = "<div class=\"sg-vu-celda\">" +
                                  (v.cri_fallo ? "<span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-alert-outline\"></i>Falló</span>" : "") +
                                  (string.IsNullOrEmpty(v.motivo_retiro) ? "" : "<strong>" + Server.HtmlEncode(v.motivo_retiro) + "</strong>") +
                                  (string.IsNullOrEmpty(v.estado_final) ? "" : "<small>" + Server.HtmlEncode(v.estado_final) + "</small>") +
                                  "</div>";

        item.CssClass += " sg-permit-row";
    }

    protected void lnkExportar_Click(object sender, EventArgs e)
    {
        try
        {
            /* Se comprueba en el SERVIDOR y no confiando en que el botón
               estaba visible: quien manda el postback a mano se lo salta. */
            if (!Token.Puede("VER REPUESTOS"))
                throw new Exception("No tiene permiso para ver los repuestos.");

            // PreRender todavía no corrió en este postback: _mostrado está en null.
            CargarGrid();

            new RepuestoController().ExportarVidaUtil(_mostrado);
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
