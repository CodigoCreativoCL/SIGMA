﻿using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de umbrales y acciones de ítems (HU-091). Solo lectura de la grilla:
/// el alta/edición va en la ficha (RadWindow). Filtra por el cliente en sesión y,
/// opcionalmente, por pauta. La barra de comandos la habilita la función
/// "Crear y editar".
/// </summary>
public partial class View_Mantenimiento_Checklist_ChecklistItemValidacions : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("civ_id", "", Width: "3%");
            Grid.AddColumn("plantilla_nombre", "PAUTA", Width: "18%");
            Grid.AddTemplateColumn("ITEM", "", "ÍTEM", Width: "24%");
            Grid.AddColumn("tipo_nombre", "TIPO", Width: "9%");
            Grid.AddTemplateColumn("UMBRALES", "", "UMBRALES", Width: "16%");
            Grid.AddTemplateColumn("ACCIONES", "", "ACCIONES", Width: "18%");
            Grid.AddCheckboxColumn("habilitado", "HABILITADO");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;
        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;
        if (!hayCliente) return;

        ConfigurarPlantillas();

        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    private RadComboBox2 Cbo(string id) { return (RadComboBox2)wucFiltro.FindControl(id); }

    private void ConfigurarPlantillas()
    {
        RadComboBox2 cbo = Cbo("cboPlantilla");
        if (cbo == null || cbo.Items.Count > 0) return;

        cbo.Items.Add(new RadComboBoxItem("Todas las pautas", ""));
        List<ChecklistPlantilla> pautas = new ChecklistPlantillaController().GetChecklistPlantillas(
            new ChecklistPlantilla { cpl_cliente = SitioBase.Session.ClienteId() }) ?? new List<ChecklistPlantilla>();
        foreach (ChecklistPlantilla p in pautas) cbo.Items.Add(new RadComboBoxItem(p.cpl_nombre, p.cpl_id.ToString()));
    }

    protected void CargarGrid()
    {
        ChecklistItemValidacion filtro = new ChecklistItemValidacion();
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        RadComboBox2 cbo = Cbo("cboPlantilla");
        if (cbo != null && cbo.SelectedValue != "") filtro.filtro_plantilla = int.Parse(cbo.SelectedValue);

        Grid.DataSource = new ChecklistItemValidacionController().GetValidaciones(filtro) ?? new List<ChecklistItemValidacion>();
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        ChecklistItemValidacion v = item.DataItem as ChecklistItemValidacion;
        if (v == null) return;

        // ÍTEM: sección · texto
        item["ITEM"].Controls.Add(new Literal
        {
            Text = (string.IsNullOrEmpty(v.seccion_nombre) ? "" : "<span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(v.seccion_nombre) + " · </span>")
                 + Server.HtmlEncode(v.item_texto)
        });

        // UMBRALES: min / adv / crit / max
        item["UMBRALES"].Controls.Add(new Literal { Text = Umbrales(v) });

        // ACCIONES: chips
        item["ACCIONES"].Controls.Add(new Literal { Text = Acciones(v) });

        // Link de edición en la celda del id
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + v.civ_id));
        HyperLink editar = new HyperLink { ID = "lnkEditar" + v.civ_id, CssClass = "icono_Editar", NavigateUrl = "javascript:void(0)" };
        editar.Attributes.Add("onclick", "abrirValidacion('" + query + "')");
        item["civ_id"].Controls.Add(editar);
    }

    private static string Umbrales(ChecklistItemValidacion v)
    {
        System.Func<decimal?, string> f = d => d == null ? "—" : d.Value.ToString("0.####");
        bool hayNum = v.valor_minimo != null || v.valor_maximo != null || v.valor_advertencia != null || v.valor_critico != null;
        if (!hayNum) return "<span class=\"sigma-inv-vacio\">sin umbrales</span>";
        return "<span title=\"mínimo / advertencia / crítico / máximo\">"
             + f(v.valor_minimo) + " / <span style=\"color:#b06400;\">" + f(v.valor_advertencia) + "</span> / <span style=\"color:#b91c1c;\">"
             + f(v.valor_critico) + "</span> / " + f(v.valor_maximo) + "</span>";
    }

    private static string Acciones(ChecklistItemValidacion v)
    {
        System.Text.StringBuilder s = new System.Text.StringBuilder();
        if (v.requiere_comentario) s.Append("<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-comment-alert-outline\"></i>comentario</span> ");
        if (v.requiere_evidencia) s.Append("<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-camera\"></i>foto</span> ");
        if (v.genera_alerta) s.Append("<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-bell-alert-outline\"></i>alerta</span> ");
        if (v.genera_hallazgo) s.Append("<span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-clipboard-alert-outline\"></i>hallazgo</span> ");
        if (s.Length == 0) return "<span class=\"sigma-inv-vacio\">—</span>";
        return s.ToString();
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0) { Tools.tools.ClientAlert("Debe seleccionar al menos un registro."); return; }

            Respuesta respuesta = new Respuesta();
            ChecklistItemValidacionController controller = new ChecklistItemValidacionController();
            foreach (string indice in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[int.Parse(indice)];
                respuesta = controller.DeleteValidacion(new ChecklistItemValidacion { civ_id = int.Parse(value["civ_id"].ToString()) });
            }

            if (!respuesta.error) Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            else Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message); }
    }
}
