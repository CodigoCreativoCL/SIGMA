using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de variables de condicion por equipo (HU-041). Mismo esquema que
/// Medidores: el master resuelve el acceso por datos, aqui solo se pregunta
/// la funcion de escritura, y el cliente va desde la sesion en el controlador.
/// </summary>
public partial class View_Activos_Variables_ActivoVariables : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("AVA_ID", "", Width: "3%");
            Grid.AddColumn("ACTIVO_CODIGO", "EQUIPO", Width: "9%");
            Grid.AddColumn("ACTIVO_NOMBRE", "", Width: "16%");
            Grid.AddColumn("COMPONENTE_NOMBRE", "COMPONENTE", Width: "12%");
            Grid.AddColumn("VARIABLE_NOMBRE", "VARIABLE", Width: "13%");
            Grid.AddColumn("UNIDAD_SIMBOLO", "UNIDAD", Width: "6%");
            Grid.AddTemplateColumn("UMBRALES", "", "UMBRALES (mín · adv · crít · máx)", Width: "20%");
            Grid.AddColumn("AVA_FRECUENCIA_ESPERADA_HORA", "CADA (h)", Width: "6%");
            Grid.AddColumn("MEDICIONES", "MEDIC.", Width: "6%");
            Grid.AddCheckboxColumn("AVA_HABILITADO", "HABILITADA");
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

        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    private void ConfigurarPlantas()
    {
        RadComboBox2 cbo = (RadComboBox2)wucFiltro.FindControl("cboPlanta");
        if (cbo == null) return;
        string sel = cbo.SelectedValue;
        List<ClienteInstalacion> plantas = new ClienteInstalacionController().GetClienteInstalaciones(
            new ClienteInstalacion { cin_cliente = SitioBase.Session.ClienteId() }) ?? new List<ClienteInstalacion>();
        cbo.Items.Clear();
        cbo.Items.Add(new RadComboBoxItem("Todas", ""));
        foreach (ClienteInstalacion p in plantas) cbo.Items.Add(new RadComboBoxItem(p.cin_nombre, p.cin_id.ToString()));
        RadComboBoxItem it = cbo.FindItemByValue(sel ?? ""); if (it != null) it.Selected = true;
    }

    protected void CargarGrid()
    {
        ActivoVariable filtro = new ActivoVariable();
        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        RadComboBox2 cboPlanta = (RadComboBox2)wucFiltro.FindControl("cboPlanta");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "") filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";
        if (cboPlanta != null && cboPlanta.SelectedValue != "") filtro.filtro_instalacion = int.Parse(cboPlanta.SelectedValue);

        Grid.DataSource = new ActivoVariableController().GetVariables(filtro) ?? new List<ActivoVariable>();
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        ActivoVariable v = item.DataItem as ActivoVariable;
        if (v == null) return;

        string id = item.GetDataKeyValue("ava_id").ToString();
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

        HyperLink Editar = new HyperLink();
        Editar.ID = "lnkEditar" + id;
        Editar.CssClass = "icono_Editar";
        Editar.NavigateUrl = "javascript:void(0)";
        Editar.Attributes.Add("onclick", "abrirActivoVariable('" + query + "')");
        item["ava_id"].Controls.Add(Editar);

        if (string.IsNullOrEmpty(v.componente_nombre)) item["COMPONENTE_NOMBRE"].Text = "<span class=\"sigma-inv-vacio\">equipo completo</span>";
        if (v.ava_frecuencia_esperada_hora == null) item["AVA_FRECUENCIA_ESPERADA_HORA"].Text = "<span class=\"sigma-inv-vacio\">—</span>";

        item["UMBRALES"].Controls.Add(new Literal { Text = Umbrales(v) });
    }

    private static string Umbrales(ActivoVariable v)
    {
        string u = string.IsNullOrEmpty(v.unidad_simbolo) ? "" : " " + v.unidad_simbolo;
        string vacio = "<span class=\"sigma-inv-vacio\">—</span>";
        string s = (v.ava_valor_minimo == null ? vacio : v.ava_valor_minimo.Value.ToString("0.##")) + " · ";
        s += v.ava_valor_advertencia == null ? vacio : "<span class=\"grid-estado-chip is-advertencia\">" + v.ava_valor_advertencia.Value.ToString("0.##") + "</span>";
        s += " · ";
        s += v.ava_valor_critico == null ? vacio : "<span class=\"grid-estado-chip is-alerta\">" + v.ava_valor_critico.Value.ToString("0.##") + "</span>";
        s += " · " + (v.ava_valor_maximo == null ? vacio : v.ava_valor_maximo.Value.ToString("0.##")) + u;
        if (v.condiciones > 0) s += " <i class=\"mdi mdi-bell-ring-outline\" title=\"Vigilada por " + v.condiciones + " programación(es) por condición\"></i>";
        return s;
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0) { Tools.tools.ClientAlert("Debe seleccionar al menos un registro."); return; }

            Respuesta r = new Respuesta();
            foreach (string indice in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];
                r = new ActivoVariableController().Delete(Int32.Parse(value["ava_id"].ToString()));
                if (r.error) break;
            }
            Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok", !r.error);
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message); }
    }
}
