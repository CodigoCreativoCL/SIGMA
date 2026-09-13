using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Bandeja de hallazgos de checklist (HU-096). Solo lectura: el hallazgo lo
/// abre el telefono cuando una respuesta sale de rango, y se cierra cuando
/// alguien lo confirma con una orden o lo descarta con un motivo. Aqui se
/// ve todo eso, se filtra y se baja a Excel; no se edita.
///
/// El acceso lo resuelve el master por datos (fila en Menus con VER
/// HALLAZGOS) y el cliente va siempre desde la sesion en el controlador.
/// </summary>
public partial class View_Mantenimiento_Hallazgos_ChecklistHallazgos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddTemplateColumn("FECHA", "", "FECHA", Width: "10%");
            Grid.AddTemplateColumn("SEVERIDAD", "", "SEVERIDAD", Width: "9%");
            Grid.AddColumn("CHA_TITULO", "HALLAZGO", Width: "22%");
            Grid.AddTemplateColumn("EQUIPO", "", "EQUIPO", Width: "14%");
            Grid.AddColumn("PLANTILLA_NOMBRE", "PAUTA", Width: "12%");
            Grid.AddTemplateColumn("RESPUESTA", "", "RESPUESTA", Width: "13%");
            Grid.AddColumn("EJECUTOR_NOMBRE", "TÉCNICO", Width: "10%");
            Grid.AddTemplateColumn("ESTADO", "", "ESTADO", Width: "10%");
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
        ConfigurarCatalogos();

        CargarGrid();
        Grid.DataBind();

        foreach (GridItem it in Grid.MasterTableView.GetItems(GridItemType.CommandItem))
        {
            Control lnk = it.FindControl("lnkDescargar");
            if (lnk != null) ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnk);
        }

        udPanel.Update();
    }

    private RadComboBox2 Cbo(string id) { return (RadComboBox2)wucFiltro.FindControl(id); }

    private void ConfigurarPlantas()
    {
        RadComboBox2 cbo = Cbo("cboPlanta");
        if (cbo == null) return;
        string seleccion = cbo.SelectedValue;

        List<ClienteInstalacion> plantas = new ClienteInstalacionController().GetClienteInstalaciones(
            new ClienteInstalacion { cin_cliente = SitioBase.Session.ClienteId() }) ?? new List<ClienteInstalacion>();

        cbo.Items.Clear();
        cbo.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
        foreach (ClienteInstalacion p in plantas) cbo.Items.Add(new RadComboBoxItem(p.cin_nombre, p.cin_id.ToString()));
        RadComboBoxItem item = cbo.FindItemByValue(seleccion ?? ""); if (item != null) item.Selected = true;
    }

    /// <summary>Severidad y Proceso_Estado son catalogos fijos (bloques 19 y 156).</summary>
    private void ConfigurarCatalogos()
    {
        RadComboBox2 sev = Cbo("cboSeveridad");
        if (sev != null && sev.Items.Count == 0)
        {
            sev.Items.Add(new RadComboBoxItem("Todas", ""));
            sev.Items.Add(new RadComboBoxItem("Crítica", "5"));
            sev.Items.Add(new RadComboBoxItem("Alta", "4"));
            sev.Items.Add(new RadComboBoxItem("Advertencia", "3"));
            sev.Items.Add(new RadComboBoxItem("Baja", "2"));
            sev.Items.Add(new RadComboBoxItem("Normal", "1"));
        }

        RadComboBox2 est = Cbo("cboEstado");
        if (est != null && est.Items.Count == 0)
        {
            est.Items.Add(new RadComboBoxItem("Todos", ""));
            est.Items.Add(new RadComboBoxItem("Pendiente", "1") { Selected = true });
            est.Items.Add(new RadComboBoxItem("En proceso", "2"));
            est.Items.Add(new RadComboBoxItem("Procesado", "3"));
            est.Items.Add(new RadComboBoxItem("Error", "4"));
            est.Items.Add(new RadComboBoxItem("Cancelado", "5"));
        }
    }

    private ChecklistHallazgo Filtro()
    {
        ChecklistHallazgo f = new ChecklistHallazgo();
        RadComboBox2 cboPlanta = Cbo("cboPlanta"), cboSev = Cbo("cboSeveridad"), cboEst = Cbo("cboEstado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) f.filtro = wucFiltro.Filtro();
        if (cboPlanta != null && cboPlanta.SelectedValue != "") f.filtro_instalacion = int.Parse(cboPlanta.SelectedValue);
        if (cboSev != null && cboSev.SelectedValue != "") f.filtro_severidad = int.Parse(cboSev.SelectedValue);
        if (cboEst != null && cboEst.SelectedValue != "") f.filtro_estado = int.Parse(cboEst.SelectedValue);
        return f;
    }

    protected void CargarGrid()
    {
        Grid.DataSource = new ChecklistHallazgoController().GetHallazgos(Filtro()) ?? new List<ChecklistHallazgo>();
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        ChecklistHallazgo h = item.DataItem as ChecklistHallazgo;
        if (h == null) return;

        item["FECHA"].Controls.Add(new Literal
        {
            Text = (h.cha_fecha_creacion == null ? "" : h.cha_fecha_creacion.Value.ToString("dd-MM-yyyy HH:mm"))
                 + (h.cha_generado_ia ? " <i class=\"mdi mdi-robot-outline\" title=\"Generado por SIGMA AI" + (h.cha_confianza_ia == null ? "" : " · confianza " + (h.cha_confianza_ia.Value * 100).ToString("0") + " %") + "\"></i>" : "")
        });

        item["SEVERIDAD"].Controls.Add(new Literal { Text = ChipSeveridad(h.severidad_codigo, h.severidad_nombre) });

        item["EQUIPO"].Controls.Add(new Literal
        {
            Text = string.IsNullOrEmpty(h.activo_codigo)
                 ? "<span class=\"sigma-inv-vacio\">sin equipo</span>"
                 : Server.HtmlEncode(h.activo_codigo) + " <span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(h.activo_nombre)
                   + (string.IsNullOrEmpty(h.componente_nombre) ? "" : " · " + Server.HtmlEncode(h.componente_nombre)) + "</span>"
        });

        string resp = "";
        if (!string.IsNullOrEmpty(h.item_texto)) resp = "<span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(h.item_texto) + "</span><br/>";
        if (h.respuesta_numero != null) resp += "<strong>" + h.respuesta_numero.Value.ToString("0.##") + " " + Server.HtmlEncode(h.respuesta_unidad ?? "") + "</strong>";
        else if (!string.IsNullOrEmpty(h.respuesta_texto)) resp += "<strong>" + Server.HtmlEncode(h.respuesta_texto) + "</strong>";
        if (h.respuesta_fuera_rango) resp += " <span class=\"grid-estado-chip is-alerta\">fuera de rango</span>";
        if (resp.Length == 0) resp = "<span class=\"sigma-inv-vacio\">—</span>";
        item["RESPUESTA"].Controls.Add(new Literal { Text = resp });

        if (string.IsNullOrEmpty(h.plantilla_nombre)) item["PLANTILLA_NOMBRE"].Text = "<span class=\"sigma-inv-vacio\">—</span>";

        string estado = ChipEstado(h.estado_codigo, h.estado_nombre);
        if (h.orden_trabajo_correlativo != null)
            estado += "<br/><span class=\"sigma-inv-vacio\" title=\"" + Server.HtmlEncode(h.orden_trabajo_estado ?? "") + "\">OT-" + h.orden_trabajo_correlativo + "</span>";
        if (!string.IsNullOrEmpty(h.cha_motivo_descarte))
            estado += "<br/><span class=\"sigma-inv-vacio\" title=\"" + Server.HtmlEncode(h.cha_motivo_descarte) + "\">descartado</span>";
        item["ESTADO"].Controls.Add(new Literal { Text = estado });
    }

    private static string ChipSeveridad(string codigo, string nombre)
    {
        if (string.IsNullOrEmpty(codigo)) return "<span class=\"sigma-inv-vacio\">sin severidad</span>";
        switch (codigo.ToUpperInvariant())
        {
            case "CRITICA":     return "<span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-alert\"></i>" + nombre + "</span>";
            case "ALTA":        return "<span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-arrow-up-bold\"></i>" + nombre + "</span>";
            case "ADVERTENCIA": return "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-alert-outline\"></i>" + nombre + "</span>";
            default:            return "<span class=\"grid-estado-chip is-neutro\">" + nombre + "</span>";
        }
    }

    private static string ChipEstado(string codigo, string nombre)
    {
        switch ((codigo ?? "").ToUpperInvariant())
        {
            case "PENDIENTE":  return "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-clock-outline\"></i>" + nombre + "</span>";
            case "EN PROCESO": return "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-progress-clock\"></i>" + nombre + "</span>";
            case "PROCESADO":  return "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-check-circle\"></i>" + nombre + "</span>";
            case "ERROR":      return "<span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-alert-circle\"></i>" + nombre + "</span>";
            default:           return "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-close-circle-outline\"></i>" + (nombre ?? "") + "</span>";
        }
    }

    protected void lnkDescargar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("VER HALLAZGOS"))
                throw new Exception("No tiene permiso para ver hallazgos.");

            new ChecklistHallazgoController().Exportar(Filtro());
        }
        catch (System.Threading.ThreadAbortException) { throw; }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
