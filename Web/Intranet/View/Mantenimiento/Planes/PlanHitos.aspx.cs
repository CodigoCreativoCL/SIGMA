using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de hitos de plan (HU-081).
///
/// El acceso lo resuelve el master con Token.ExigirPagina(); aqui solo se
/// pregunta la funcion de escritura. El cliente viaja siempre en el filtro
/// y el SP lo cruza a traves del plan.
/// </summary>
public partial class View_Mantenimiento_Planes_PlanHitos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("PMH_ID", "", Width: "3%");
            Grid.AddColumn("PLAN_CODIGO", "PLAN", Width: "11%");
            Grid.AddTemplateColumn("VERSION", "", "VERSIÓN", Width: "10%");
            Grid.AddColumn("PMH_ORDEN", "#", Width: "3%");
            Grid.AddColumn("PMH_CODIGO", "CÓDIGO", Width: "10%");
            Grid.AddColumn("PMH_NOMBRE", "HITO", Width: "20%");
            Grid.AddColumn("PROGRAMACION_NOMBRE", "CADA CUÁNTO", Width: "16%");
            Grid.AddTemplateColumn("MARCAS", "", "", Width: "9%");
            Grid.AddColumn("ACTIVIDADES", "ACTIV.", Width: "5%");
            Grid.AddCheckboxColumn("PMH_HABILITADO", "HABILITADO");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;

        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;

        if (!hayCliente) return;

        ConfigurarPlanes();

        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    private RadComboBox2 Cbo(string id) { return (RadComboBox2)wucFiltro.FindControl(id); }

    /// <summary>
    /// El combo de planes del filtro, desde la base. Solo los habilitados:
    /// los hitos de un plan deshabilitado se miran desde el plan, no desde
    /// aqui.
    /// </summary>
    private void ConfigurarPlanes()
    {
        RadComboBox2 cboPlan = Cbo("cboPlan");
        if (cboPlan == null) return;

        string seleccion = cboPlan.SelectedValue;

        List<PlanMantenimiento> planes =
            new PlanMantenimientoController().GetPlanesMantenimiento(
                new PlanMantenimiento { pma_cliente = SitioBase.Session.ClienteId(), filtro_habilitado = true })
            ?? new List<PlanMantenimiento>();

        cboPlan.Items.Clear();
        cboPlan.Items.Add(new RadComboBoxItem("Todos los planes", ""));
        foreach (PlanMantenimiento p in planes)
            cboPlan.Items.Add(new RadComboBoxItem(p.pma_codigo + " — " + p.pma_nombre, p.pma_id.ToString()));

        RadComboBoxItem item = cboPlan.FindItemByValue(seleccion ?? "");
        if (item != null) item.Selected = true;
    }

    protected void CargarGrid()
    {
        PlanHito filtro = new PlanHito();
        PlanHitoController controller = new PlanHitoController();

        filtro.filtro_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboHabilitado = Cbo("cboHabilitado");
        RadComboBox2 cboPlan = Cbo("cboPlan");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";
        if (cboPlan != null && cboPlan.SelectedValue != "")
            filtro.filtro_plan = int.Parse(cboPlan.SelectedValue);

        Grid.DataSource = controller.GetPlanHitos(filtro);
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        PlanHito hito = item.DataItem as PlanHito;
        if (hito == null) return;

        string id = item.GetDataKeyValue("pmh_id").ToString();
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

        HyperLink Editar = new HyperLink();
        Editar.ID = "lnkEditar" + id;
        Editar.CssClass = "icono_Editar";
        Editar.NavigateUrl = "javascript:void(0)";
        Editar.Attributes.Add("onclick", "abrirPlanHito('" + query + "')");
        item["pmh_id"].Controls.Add(Editar);

        // La programacion con su tipo debajo: «Cada 3 meses» dice mas que
        // «Trimestral L1», y el tipo es lo que distingue calendario de medidor.
        if (!string.IsNullOrEmpty(hito.programacion_tipo_nombre))
            item["PROGRAMACION_NOMBRE"].Text = Server.HtmlEncode(hito.programacion_nombre)
                + "<br/><span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(hito.programacion_tipo_nombre) + "</span>";

        item["VERSION"].Controls.Add(new Literal { Text = ChipVersion(hito) });
        item["MARCAS"].Controls.Add(new Literal { Text = Marcas(hito) });
    }

    private string ChipVersion(PlanHito h)
    {
        string numero = "v" + (h.version_numero ?? 0);

        switch ((h.version_estado_codigo ?? "").ToUpperInvariant())
        {
            case "PUBLICADO":
                return "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-check-circle\"></i>" + numero + " publicada</span>";
            case "RETIRADO":
                return "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-archive-outline\"></i>" + numero + " retirada</span>";
            default:
                return "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-pencil-outline\"></i>" + numero + " borrador</span>";
        }
    }

    /// <summary>
    /// Overhaul y parada como marcas, no como columnas de SI/NO: dos
    /// columnas de casillas se leen como una tabla; dos iconos se leen de un
    /// vistazo, que es lo que importa para saber si un hito para la linea.
    /// </summary>
    private string Marcas(PlanHito h)
    {
        string s = "";
        if (h.pmh_requiere_parada)
            s += "<span class=\"grid-estado-chip is-alerta\" title=\"Requiere parada del equipo\"><i class=\"mdi mdi-power\"></i>Parada</span> ";
        if (h.pmh_es_overhaul)
            s += "<span class=\"grid-estado-chip is-advertencia\" title=\"Overhaul: intervención mayor\"><i class=\"mdi mdi-wrench\"></i>Overhaul</span>";
        return s;
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
                return;
            }

            Respuesta respuesta = new Respuesta();
            PlanHitoController controller = new PlanHitoController();

            foreach (string indice in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];

                PlanHito entidad = new PlanHito();
                entidad.pmh_id = Int32.Parse(value["pmh_id"].ToString());

                respuesta = controller.DeletePlanHito(entidad);
                if (respuesta.error) break;
            }

            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }
}
