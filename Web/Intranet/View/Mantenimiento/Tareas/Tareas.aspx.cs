using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de tareas recurrentes (HU-102). Mismo esquema que Planes: el
/// acceso lo resuelve el master por datos, aqui solo se pregunta la funcion
/// de escritura, y el cliente va siempre en el filtro.
/// </summary>
public partial class View_Mantenimiento_Tareas_Tareas : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("TAR_ID", "", Width: "3%");
            Grid.AddColumn("TAR_CODIGO", "CÓDIGO", Width: "9%");
            Grid.AddColumn("TAR_TITULO", "TAREA", Width: "26%");
            Grid.AddTemplateColumn("PRIORIDAD", "", "PRIORIDAD", Width: "9%");
            Grid.AddColumn("PLANTA_NOMBRE", "PLANTA", Width: "10%");
            Grid.AddColumn("AREA_NOMBRE", "ÁREA", Width: "10%");
            Grid.AddColumn("ACTIVO_NOMBRE", "EQUIPO", Width: "13%");
            Grid.AddColumn("PROGRAMACIONES", "PROG.", Width: "5%");
            Grid.AddTemplateColumn("PENDIENTES", "", "PENDIENTES", Width: "7%");
            Grid.AddCheckboxColumn("TAR_HABILITADO", "HABILITADO");
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
        ConfigurarPrioridades();

        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    private RadComboBox2 Cbo(string id) { return (RadComboBox2)wucFiltro.FindControl(id); }

    private void ConfigurarPlantas()
    {
        RadComboBox2 cbo = Cbo("cboPlanta");
        if (cbo == null) return;

        string seleccion = cbo.SelectedValue;

        List<ClienteInstalacion> plantas =
            new ClienteInstalacionController().GetClienteInstalaciones(
                new ClienteInstalacion { cin_cliente = SitioBase.Session.ClienteId() })
            ?? new List<ClienteInstalacion>();

        cbo.Items.Clear();
        cbo.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
        foreach (ClienteInstalacion p in plantas)
            cbo.Items.Add(new RadComboBoxItem(p.cin_nombre, p.cin_id.ToString()));

        RadComboBoxItem item = cbo.FindItemByValue(seleccion ?? "");
        if (item != null) item.Selected = true;
    }

    /// <summary>Tarea_Prioridad es un catalogo fijo del bloque 159 (1 Baja … 4 Crítica).</summary>
    private void ConfigurarPrioridades()
    {
        RadComboBox2 cbo = Cbo("cboPrioridad");
        if (cbo == null || cbo.Items.Count > 0) return;

        cbo.Items.Add(new RadComboBoxItem("Todas", ""));
        cbo.Items.Add(new RadComboBoxItem("Baja", "1"));
        cbo.Items.Add(new RadComboBoxItem("Media", "2"));
        cbo.Items.Add(new RadComboBoxItem("Alta", "3"));
        cbo.Items.Add(new RadComboBoxItem("Crítica", "4"));
    }

    protected void CargarGrid()
    {
        Tarea filtro = new Tarea { tar_cliente = SitioBase.Session.ClienteId() };

        RadComboBox2 cboHabilitado = Cbo("cboHabilitado");
        RadComboBox2 cboPlanta = Cbo("cboPlanta");
        RadComboBox2 cboPrioridad = Cbo("cboPrioridad");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "") filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";
        if (cboPlanta != null && cboPlanta.SelectedValue != "") filtro.filtro_instalacion = int.Parse(cboPlanta.SelectedValue);
        if (cboPrioridad != null && cboPrioridad.SelectedValue != "") filtro.filtro_prioridad = int.Parse(cboPrioridad.SelectedValue);

        Grid.DataSource = new TareaController().GetTareas(filtro);
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        Tarea t = item.DataItem as Tarea;
        if (t == null) return;

        string id = item.GetDataKeyValue("tar_id").ToString();
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

        HyperLink Editar = new HyperLink();
        Editar.ID = "lnkEditar" + id;
        Editar.CssClass = "icono_Editar";
        Editar.NavigateUrl = "javascript:void(0)";
        Editar.Attributes.Add("onclick", "abrirTarea('" + query + "')");
        item["tar_id"].Controls.Add(Editar);

        if (string.IsNullOrEmpty(t.planta_nombre)) item["PLANTA_NOMBRE"].Text = "<span class=\"sigma-inv-vacio\">cualquiera</span>";
        if (string.IsNullOrEmpty(t.area_nombre)) item["AREA_NOMBRE"].Text = "<span class=\"sigma-inv-vacio\">—</span>";
        if (string.IsNullOrEmpty(t.activo_nombre)) item["ACTIVO_NOMBRE"].Text = "<span class=\"sigma-inv-vacio\">sin equipo</span>";
        else item["ACTIVO_NOMBRE"].Text = Server.HtmlEncode(t.activo_codigo) + " <span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(t.activo_nombre) + "</span>";

        item["PRIORIDAD"].Controls.Add(new Literal { Text = ChipPrioridad(t.prioridad_codigo, t.prioridad_nombre) });

        item["PENDIENTES"].Controls.Add(new Literal
        {
            Text = t.pendientes > 0
                 ? "<span class=\"grid-estado-chip is-advertencia\">" + t.pendientes + " pendiente" + (t.pendientes == 1 ? "" : "s") + "</span>"
                 : "<span class=\"sigma-inv-vacio\">" + (t.ocurrencias > 0 ? "al día" : "sin ocurrencias") + "</span>"
        });
    }

    public static string ChipPrioridad(string codigo, string nombre)
    {
        switch ((codigo ?? "").ToUpperInvariant())
        {
            case "CRITICA": return "<span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-alert\"></i>" + nombre + "</span>";
            case "ALTA":    return "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-arrow-up-bold\"></i>" + nombre + "</span>";
            case "MEDIA":   return "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-minus\"></i>" + nombre + "</span>";
            default:        return "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-arrow-down-bold\"></i>" + nombre + "</span>";
        }
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
            TareaController controller = new TareaController();

            foreach (string indice in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];
                respuesta = controller.DeleteTarea(new Tarea { tar_id = Int32.Parse(value["tar_id"].ToString()) });
                if (respuesta.error) break;
            }

            if (!respuesta.error) Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            else Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }
}
