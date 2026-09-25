using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de ordenes de trabajo y bandeja de cierre (HU-110, HU-122).
///
/// UN SOLO LISTADO, DOS LECTURAS
///   Con estado «Bandeja de cierre» la grilla cambia: se ordena por
///   antiguedad, muestra los dias de espera y aparece el cierre masivo con
///   un motivo comun. Es la misma pantalla porque es la misma lista; lo que
///   cambia es la pregunta que se le hace.
///
/// EL CIERRE ES DEL SP
///   Jerarquia (FNC_USUARIO_PUEDE_CERRAR_OT), estado y resultado obligatorio
///   se deciden en UPD_ORDEN_TRABAJO_CERRAR_WEB. Aqui solo se esconde el
///   boton a quien no tiene la funcion «Cerrar» de la pagina.
/// </summary>
public partial class View_Mantenimiento_Ordenes_OrdenTrabajos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("OTR_ID", "", Width: "3%");
            Grid.AddTemplateColumn("OT", "", "OT", Width: "7%");
            Grid.AddColumn("OTR_TITULO", "TÍTULO", Width: "24%");
            Grid.AddTemplateColumn("EQUIPO", "", "EQUIPO / ÁREA", Width: "16%");
            Grid.AddTemplateColumn("TIPO", "", "TIPO", Width: "10%");
            Grid.AddTemplateColumn("PRIORIDAD", "", "PRIORIDAD", Width: "8%");
            Grid.AddTemplateColumn("RESPONSABLE", "", "RESPONSABLE", Width: "12%");
            Grid.AddTemplateColumn("ESTADO", "", "ESTADO", Width: "12%");
            Grid.AddTemplateColumn("PASOS", "", "PASOS", Width: "6%");
        }
        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;
        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;
        if (!hayCliente) return;

        ConfigurarPlantas();

        bool puedeCrear = Token.PuedeFuncion("Crear y editar");
        bool puedeCerrar = Token.PuedeFuncion("Cerrar");
        bool bandeja = Cbo("cboEstado") != null && Cbo("cboEstado").SelectedValue == "3";

        pnlCierre.Visible = bandeja && puedeCerrar;

        CargarGrid();
        Grid.DataBind();

        if (!puedeCrear && !puedeCerrar) Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;
        foreach (GridItem it in Grid.MasterTableView.GetItems(GridItemType.CommandItem))
        {
            Control n = it.FindControl("lnkNuevo"); if (n != null) n.Visible = puedeCrear;
            Control c = it.FindControl("lnkCerrar"); if (c != null) c.Visible = bandeja && puedeCerrar;
        }
        udPanel.Update();
    }

    private RadComboBox2 Cbo(string id) { return (RadComboBox2)wucFiltro.FindControl(id); }

    private void ConfigurarPlantas()
    {
        RadComboBox2 cbo = Cbo("cboPlanta");
        if (cbo == null) return;
        string sel = cbo.SelectedValue;
        List<ClienteInstalacion> plantas = new ClienteInstalacionController().GetClienteInstalaciones(
            new ClienteInstalacion { cin_cliente = SitioBase.Session.ClienteId() }) ?? new List<ClienteInstalacion>();
        cbo.Items.Clear();
        cbo.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
        foreach (ClienteInstalacion p in plantas) cbo.Items.Add(new RadComboBoxItem(p.cin_nombre, p.cin_id.ToString()));
        RadComboBoxItem it = cbo.FindItemByValue(sel ?? ""); if (it != null) it.Selected = true;
    }

    protected void CargarGrid()
    {
        OrdenTrabajo f = new OrdenTrabajo();
        RadComboBox2 cboEstado = Cbo("cboEstado"), cboTipo = Cbo("cboTipo"), cboPlanta = Cbo("cboPlanta");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) f.filtro = wucFiltro.Filtro();
        if (cboTipo != null && cboTipo.SelectedValue != "") f.filtro_tipo = int.Parse(cboTipo.SelectedValue);
        if (cboPlanta != null && cboPlanta.SelectedValue != "") f.filtro_instalacion = int.Parse(cboPlanta.SelectedValue);

        List<OrdenTrabajo> lista;
        string estado = cboEstado == null ? "ABIERTAS" : cboEstado.SelectedValue;
        if (estado == "ABIERTAS")
        {
            // Abiertas y en ejecucion: dos consultas del mismo SP, lo que se ve de lunes a viernes.
            lista = new OrdenTrabajoController().GetOrdenes(Copia(f, 1)) ?? new List<OrdenTrabajo>();
            lista.AddRange(new OrdenTrabajoController().GetOrdenes(Copia(f, 2)) ?? new List<OrdenTrabajo>());
            lista.Sort((a, b) => b.otr_correlativo.CompareTo(a.otr_correlativo));
        }
        else
        {
            if (estado != "") f.filtro_estado = int.Parse(estado);
            lista = new OrdenTrabajoController().GetOrdenes(f) ?? new List<OrdenTrabajo>();
        }
        Grid.DataSource = lista;
    }

    private static OrdenTrabajo Copia(OrdenTrabajo f, int estado)
    {
        return new OrdenTrabajo { filtro = f.filtro, filtro_tipo = f.filtro_tipo, filtro_instalacion = f.filtro_instalacion, filtro_estado = estado };
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        OrdenTrabajo o = item.DataItem as OrdenTrabajo;
        if (o == null) return;

        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + o.otr_id));
        HyperLink Editar = new HyperLink { ID = "lnkEditar" + o.otr_id, CssClass = "icono_Editar", NavigateUrl = "javascript:void(0)" };
        Editar.Attributes.Add("onclick", "abrirOrdenTrabajo('" + query + "')");
        item["otr_id"].Controls.Add(Editar);

        item["OT"].Controls.Add(new Literal { Text = "<strong>OT-" + o.otr_correlativo + "</strong>" + (o.otr_registro_posterior ? " <i class=\"mdi mdi-history\" title=\"Registro posterior\"></i>" : "") });
        item["EQUIPO"].Controls.Add(new Literal
        {
            Text = string.IsNullOrEmpty(o.activo_codigo)
                 ? "<span class=\"sigma-inv-vacio\">sin equipo</span> · " + Server.HtmlEncode(o.area_nombre ?? "")
                 : Server.HtmlEncode(o.activo_codigo) + " <span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(o.activo_nombre) + "</span>"
        });
        item["TIPO"].Controls.Add(new Literal { Text = Server.HtmlEncode(o.tipo_nombre) + "<br/><span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(o.origen_nombre) + "</span>" });
        item["PRIORIDAD"].Controls.Add(new Literal { Text = ChipPrioridad(o.prioridad_codigo, o.prioridad_nombre) });
        item["RESPONSABLE"].Controls.Add(new Literal
        {
            Text = !string.IsNullOrEmpty(o.responsable_nombre) ? Server.HtmlEncode(o.responsable_nombre)
                 : !string.IsNullOrEmpty(o.responsable_proveedor) ? "<i class=\"mdi mdi-domain\"></i> " + Server.HtmlEncode(o.responsable_proveedor)
                 : "<span class=\"sigma-inv-vacio\">sin asignar</span>"
        });
        string estado = ChipEstado(o.estado_codigo, o.estado_nombre);
        if (o.dias_espera_cierre != null) estado += "<br/><span class=\"sigma-inv-vacio\">" + o.dias_espera_cierre + " día(s) esperando</span>";
        if (o.otr_orden_trabajo_estado == 4 && !string.IsNullOrEmpty(o.cierre_motivo_nombre)) estado += "<br/><span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(o.cierre_motivo_nombre) + "</span>";
        item["ESTADO"].Controls.Add(new Literal { Text = estado });
        item["PASOS"].Controls.Add(new Literal { Text = o.pasos == 0 ? "<span class=\"sigma-inv-vacio\">—</span>" : (o.pasos - o.pasos_pendientes) + "/" + o.pasos });
    }

    public static string ChipPrioridad(string codigo, string nombre)
    {
        switch ((codigo ?? "").ToUpperInvariant())
        {
            case "CRITICA": return "<span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-alert\"></i>" + nombre + "</span>";
            case "ALTA":    return "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-arrow-up-bold\"></i>" + nombre + "</span>";
            default:        return "<span class=\"grid-estado-chip is-neutro\">" + nombre + "</span>";
        }
    }

    public static string ChipEstado(string codigo, string nombre)
    {
        switch ((codigo ?? "").ToUpperInvariant())
        {
            case "ABIERTA":             return "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-folder-open-outline\"></i>" + nombre + "</span>";
            case "EN EJECUCION":        return "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-progress-wrench\"></i>" + nombre + "</span>";
            case "EN ESPERA DE CIERRE": return "<span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-clock-alert-outline\"></i>" + nombre + "</span>";
            default:                    return "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-check-circle\"></i>" + nombre + "</span>";
        }
    }

    /// <summary>HU-122 #2: varias ordenes, un motivo comun, un registro por cada una.</summary>
    protected void lnkCerrar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.PuedeFuncion("Cerrar")) throw new Exception("No tiene la función de cerrar órdenes en esta pantalla.");
            if (Grid.SelectedIndexes.Count == 0) { Tools.tools.ClientAlert("Seleccione al menos una orden."); return; }

            int motivo = int.Parse(cboMotivoCierre.SelectedValue);
            string resultado = txtResultado.Text.Trim();
            System.Text.StringBuilder sb = new System.Text.StringBuilder();
            int ok = 0, malos = 0;

            foreach (string indice in Grid.SelectedIndexes)
            {
                GridDataItem fila = (GridDataItem)Grid.MasterTableView.Items[Int32.Parse(indice)];
                int id = Int32.Parse(Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)]["otr_id"].ToString());
                Respuesta r = new OrdenTrabajoController().Cerrar(id, motivo, resultado);
                string etiqueta = Server.HtmlEncode(fila["OTR_TITULO"].Text);
                if (r.error) { malos++; sb.Append("<div><span class=\"grid-estado-chip is-alerta\">rechazada</span> " + etiqueta + " — " + Server.HtmlEncode(r.detalle) + "</div>"); }
                else { ok++; sb.Append("<div><span class=\"grid-estado-chip is-exito\">cerrada</span> " + etiqueta + "</div>"); }
            }

            pnlResultado.Visible = true;
            litResultado.Text = "<strong>" + ok + " cerrada(s) · " + malos + " rechazada(s)</strong>" + sb;
            if (malos == 0) txtResultado.Text = "";
            Tools.tools.ClientAlert(ok + " orden(es) cerrada(s).", malos > 0 ? "alerta" : "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }
}
