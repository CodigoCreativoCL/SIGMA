using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de activos (HU-035).
///
/// SEGURIDAD POR DATOS
///   El acceso a la pantalla lo resuelve el master con Token.ExigirPagina():
///   una página sin fila en Menus no se abre. Aquí no hay bloque de
///   seguridad de página. Lo único que se pregunta es la función de
///   escritura, para mostrar u ocultar la barra de comandos, y SIEMPRE se
///   filtra por el cliente en sesión: un activo es de una empresa, y sin
///   este filtro un usuario vería los de otra.
///
/// FILTRO POR UBICACIÓN (cascada)
///   En la barra de búsqueda hay tres desplegables encadenados:
///   Planta -> Área -> Línea. Al elegir uno, el grid muestra solo los activos
///   de esa ubicación; el área incluye sus sub-áreas por el filtro recursivo
///   del SEL_ACTIVO. Gana la selección más específica (línea > área > planta).
/// </summary>
public partial class View_Activos_Activos_Activos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("ACT_ID", "", Width: "3%");
            Grid.AddColumn("ACT_CODIGO", "CÓDIGO", Width: "11%");
            Grid.AddColumn("ACT_NOMBRE", "NOMBRE", Width: "23%");
            Grid.AddColumn("PLANTA_NOMBRE", "PLANTA", Width: "15%");
            Grid.AddColumn("AREA_NOMBRE", "ÁREA / LÍNEA", Width: "13%");
            Grid.AddColumn("TIPO_NOMBRE", "TIPO", Width: "12%");
            Grid.AddColumn("ESTADO_NOMBRE", "ESTADO", Width: "11%");
            Grid.AddColumn("CRITICIDAD_NOMBRE", "CRITICIDAD", Width: "8%");
            Grid.AddCheckboxColumn("ACT_HABILITADO", "HABILITADO");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        // Sin cliente en sesión no hay nada que listar: los activos son de un
        // cliente, no de la plataforma.
        bool hayCliente = SitioBase.Session.ClienteId() > 0;

        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;

        if (!hayCliente) return;

        // Sin la función de escritura la barra de comandos no se muestra.
        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        ConfigurarUbicacion();
        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    private RadComboBox2 Cbo(string id) { return (RadComboBox2)wucFiltro.FindControl(id); }

    private void Seleccionar(RadComboBox2 cbo, string valor)
    {
        RadComboBoxItem item = cbo.FindItemByValue(valor ?? "");
        if (item == null) item = cbo.Items.Count > 0 ? cbo.Items[0] : null;
        if (item != null) item.Selected = true;
    }

    /// <summary>
    /// Cascada Planta -> Area -> Linea. Se reconstruye en cada carga a partir
    /// de lo elegido: el hijo siempre corresponde al padre y, si el padre
    /// cambia, el hijo se resetea a "Todas".
    /// </summary>
    protected void ConfigurarUbicacion()
    {
        RadComboBox2 cboPlanta = Cbo("cboPlanta");
        RadComboBox2 cboArea = Cbo("cboArea");
        RadComboBox2 cboLinea = Cbo("cboLinea");
        if (cboPlanta == null || cboArea == null || cboLinea == null) return;

        int cliente = SitioBase.Session.ClienteId();

        // Seleccion actual (viene del postback), antes de reconstruir.
        string selP = cboPlanta.SelectedValue;
        string selA = cboArea.SelectedValue;
        string selL = cboLinea.SelectedValue;

        List<ClienteInstalacion> plantas =
            new ClienteInstalacionController().GetClienteInstalaciones(new ClienteInstalacion { cin_cliente = cliente })
            ?? new List<ClienteInstalacion>();

        List<InstalacionArea> areas =
            new InstalacionAreaController().GetInstalacionAreas(new InstalacionArea { iar_cliente = cliente, filtro_habilitado = true })
            ?? new List<InstalacionArea>();

        // ---- PLANTA ----
        cboPlanta.Items.Clear();
        cboPlanta.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
        foreach (ClienteInstalacion p in plantas)
            cboPlanta.Items.Add(new RadComboBoxItem(p.cin_nombre, p.cin_id.ToString()));

        // Una sola planta y sin eleccion previa: se preselecciona.
        if (string.IsNullOrEmpty(selP) && plantas.Count == 1)
            selP = plantas[0].cin_id.ToString();
        Seleccionar(cboPlanta, selP);
        selP = cboPlanta.SelectedValue;
        int plantaId; int.TryParse(selP, out plantaId);

        // ---- AREA (areas raiz de la planta elegida) ----
        cboArea.Items.Clear();
        cboArea.Items.Add(new RadComboBoxItem("Todas las áreas", ""));
        if (plantaId > 0)
            foreach (InstalacionArea a in areas)
                if (a.iar_cliente_instalacion == plantaId && (a.iar_area_padre == null || a.iar_area_padre == 0))
                    cboArea.Items.Add(new RadComboBoxItem(a.iar_nombre, a.iar_id.ToString()));

        if (cboArea.FindItemByValue(selA) == null) selA = "";
        Seleccionar(cboArea, selA);
        selA = cboArea.SelectedValue;
        int areaId; int.TryParse(selA, out areaId);

        // ---- LINEA (sub-areas del area elegida) ----
        cboLinea.Items.Clear();
        cboLinea.Items.Add(new RadComboBoxItem("Todas las líneas", ""));
        if (areaId > 0)
            foreach (InstalacionArea a in areas)
                if (a.iar_area_padre == areaId)
                    cboLinea.Items.Add(new RadComboBoxItem(a.iar_nombre, a.iar_id.ToString()));

        if (cboLinea.FindItemByValue(selL) == null) selL = "";
        Seleccionar(cboLinea, selL);
    }

    protected void CargarGrid()
    {
        Activo filtro = new Activo();
        ActivoController controller = new ActivoController();

        // El filtro por cliente en sesión es la barrera multicliente: no es
        // opcional.
        filtro.act_cliente = SitioBase.Session.ClienteId();

        // Ubicación: gana la selección más específica (línea > área > planta).
        string valLinea = Cbo("cboLinea") != null ? Cbo("cboLinea").SelectedValue : "";
        string valArea = Cbo("cboArea") != null ? Cbo("cboArea").SelectedValue : "";
        string valPlanta = Cbo("cboPlanta") != null ? Cbo("cboPlanta").SelectedValue : "";

        int id;
        if (!string.IsNullOrEmpty(valLinea) && int.TryParse(valLinea, out id))
            filtro.filtro_instalacion_area = id;
        else if (!string.IsNullOrEmpty(valArea) && int.TryParse(valArea, out id))
            filtro.filtro_instalacion_area = id;
        else if (!string.IsNullOrEmpty(valPlanta) && int.TryParse(valPlanta, out id))
            filtro.filtro_cliente_instalacion = id;

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetActivos(filtro);
    }

    protected void rgrActivos_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("act_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirActivo('" + query + "')");

                item["act_id"].Controls.Add(Editar);
            }
        }
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
            }
            else
            {
                Respuesta respuesta = new Respuesta();
                ActivoController controller = new ActivoController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];

                    Activo entidad = new Activo();
                    entidad.act_id = Int32.Parse(value["act_id"].ToString());

                    respuesta = controller.DeleteActivo(entidad);
                }

                if (!respuesta.error)
                    Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
                else
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }
}
