using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de planes de mantenimiento (HU-080).
///
/// El acceso a la pantalla lo resuelve el master con Token.ExigirPagina():
/// aqui no hay bloque de seguridad porque en SIGMA los permisos son datos,
/// no codigo. Lo unico que se pregunta es la funcion de escritura.
///
/// EL CLIENTE VIAJA SIEMPRE EN EL FILTRO
///   Session.ClienteId() va en cada consulta. Un plan de otra empresa no
///   aparece aunque se conozca su id, porque el SP filtra por cliente y el
///   listado nunca se pide sin el.
/// </summary>
public partial class View_Mantenimiento_Planes_PlanMantenimientos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("PMA_ID", "", Width: "3%");
            Grid.AddColumn("PMA_CODIGO", "CÓDIGO", Width: "10%");
            Grid.AddColumn("PMA_NOMBRE", "NOMBRE", Width: "24%");
            Grid.AddColumn("PLANTA_NOMBRE", "PLANTA", Width: "12%");
            Grid.AddColumn("TIPO_NOMBRE", "TIPO DE ACTIVO", Width: "12%");
            Grid.AddColumn("PLANIFICADOR_NOMBRE", "PLANIFICA", Width: "12%");
            /* Field vacio: el contenido lo arma ItemDataBound con el chip de
               la version. Es como lo hacen Existencias y Suscripciones. */
            Grid.AddTemplateColumn("VERSION", "", "VERSIÓN", Width: "13%");
            Grid.AddColumn("HITOS", "HITOS", Width: "5%");
            Grid.AddColumn("ACTIVOS", "EQUIPOS", Width: "5%");
            Grid.AddCheckboxColumn("PMA_HABILITADO", "HABILITADO");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        // Sin cliente en sesion no hay nada que listar: los planes son de un
        // cliente, no de la plataforma.
        bool hayCliente = SitioBase.Session.ClienteId() > 0;

        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;

        if (!hayCliente) return;

        ConfigurarPlantas();

        // Sin la funcion de escritura la barra de comandos no se muestra.
        // Esconderla no autoriza nada: el SP y la ficha vuelven a exigir el
        // permiso. Solo evita ofrecer un boton que terminaria en un rechazo.
        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    private RadComboBox2 Cbo(string id) { return (RadComboBox2)wucFiltro.FindControl(id); }

    /// <summary>
    /// El combo de plantas del filtro se llena desde la base y no desde el
    /// markup: un catalogo copiado en un .aspx es el que nadie actualiza el
    /// dia que cambia. Se reconstruye en cada carga preservando lo elegido.
    /// </summary>
    private void ConfigurarPlantas()
    {
        RadComboBox2 cboPlanta = Cbo("cboPlanta");
        if (cboPlanta == null) return;

        string seleccion = cboPlanta.SelectedValue;

        List<ClienteInstalacion> plantas =
            new ClienteInstalacionController().GetClienteInstalaciones(
                new ClienteInstalacion { cin_cliente = SitioBase.Session.ClienteId() })
            ?? new List<ClienteInstalacion>();

        cboPlanta.Items.Clear();
        cboPlanta.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
        foreach (ClienteInstalacion p in plantas)
            cboPlanta.Items.Add(new RadComboBoxItem(p.cin_nombre, p.cin_id.ToString()));

        RadComboBoxItem item = cboPlanta.FindItemByValue(seleccion ?? "");
        if (item != null) item.Selected = true;
    }

    protected void CargarGrid()
    {
        PlanMantenimiento filtro = new PlanMantenimiento();
        PlanMantenimientoController controller = new PlanMantenimientoController();

        filtro.pma_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboHabilitado = Cbo("cboHabilitado");
        RadComboBox2 cboPlanta = Cbo("cboPlanta");

        // wucFiltro.Filtro() va al @FILTRO parametrizado del SEL_. Nunca
        // concatenado: en el buscador eso era inyeccion SQL (bloque 49).
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";
        if (cboPlanta != null && cboPlanta.SelectedValue != "")
            filtro.filtro_instalacion = int.Parse(cboPlanta.SelectedValue);

        Grid.DataSource = controller.GetPlanesMantenimiento(filtro);
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        PlanMantenimiento plan = item.DataItem as PlanMantenimiento;
        if (plan == null) return;

        string id = item.GetDataKeyValue("pma_id").ToString();
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

        HyperLink Editar = new HyperLink();
        Editar.ID = "lnkEditar" + id;
        Editar.CssClass = "icono_Editar";
        Editar.NavigateUrl = "javascript:void(0)";
        Editar.Attributes.Add("onclick", "abrirPlanMantenimiento('" + query + "')");
        item["pma_id"].Controls.Add(Editar);

        // Vacio no se entiende; "cualquiera" si: un plan sin planta aplica a
        // todas las del cliente.
        if (string.IsNullOrEmpty(plan.planta_nombre))
            item["PLANTA_NOMBRE"].Text = "<span class=\"sigma-inv-vacio\">cualquiera</span>";
        if (string.IsNullOrEmpty(plan.tipo_nombre))
            item["TIPO_NOMBRE"].Text = "<span class=\"sigma-inv-vacio\">cualquiera</span>";
        if (string.IsNullOrEmpty(plan.planificador_nombre))
            item["PLANIFICADOR_NOMBRE"].Text = "<span class=\"sigma-inv-vacio\">sin asignar</span>";

        item["VERSION"].Controls.Add(new Literal { Text = ChipVersion(plan) });
    }

    /// <summary>
    /// El chip de la version que manda.
    ///
    /// Es lo primero que se pregunta de un plan: ¿genera mantenciones o es
    /// un borrador? Y va con el numero, porque «v3 publicada» y «v4 en
    /// borrador» son dos cosas que pueden convivir y el planificador tiene
    /// que saber cual esta mirando.
    /// </summary>
    private string ChipVersion(PlanMantenimiento plan)
    {
        if (plan.version_numero == null)
            return "<span class=\"grid-estado-chip is-neutro\">"
                 + "<i class=\"mdi mdi-help-circle-outline\"></i>Sin versión</span>";

        string numero = "v" + plan.version_numero;

        switch ((plan.version_estado_codigo ?? "").ToUpperInvariant())
        {
            case "PUBLICADO":
                return "<span class=\"grid-estado-chip is-exito\">"
                     + "<i class=\"mdi mdi-check-circle\"></i>" + numero + " publicada</span>";

            case "RETIRADO":
                return "<span class=\"grid-estado-chip is-neutro\">"
                     + "<i class=\"mdi mdi-archive-outline\"></i>" + numero + " retirada</span>";

            default:
                return "<span class=\"grid-estado-chip is-advertencia\">"
                     + "<i class=\"mdi mdi-pencil-outline\"></i>" + numero + " borrador</span>";
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
            PlanMantenimientoController controller = new PlanMantenimientoController();

            foreach (string indice in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];

                PlanMantenimiento entidad = new PlanMantenimiento();
                entidad.pma_id = Int32.Parse(value["pma_id"].ToString());

                respuesta = controller.DeletePlanMantenimiento(entidad);

                // El primero que rebota corta: el mensaje del SP dice cual y
                // por que, y seguir con el resto lo taparia.
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
