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
/// Listado de posiciones funcionales (HU-033) e impresion masiva de sus
/// etiquetas QR (HU-034 #2).
///
/// El acceso a la pantalla lo resuelve el master con Token.ExigirPagina():
/// en SIGMA los permisos son datos, no codigo. Aqui solo se pregunta la
/// funcion de escritura y el permiso de imprimir.
/// </summary>
public partial class View_Activos_Posiciones_Posiciones : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("APO_ID", "", Width: "3%");
            Grid.AddColumn("APO_CODIGO", "CÓDIGO", Width: "10%");
            Grid.AddColumn("APO_NOMBRE", "NOMBRE", Width: "20%");
            Grid.AddColumn("PLANTA_NOMBRE", "PLANTA", Width: "10%");
            Grid.AddColumn("AREA_NOMBRE", "ÁREA", Width: "15%");
            Grid.AddColumn("TIPO_NOMBRE", "ADMITE", Width: "12%");
            Grid.AddTemplateColumn("EQUIPO", "", "EQUIPO ACTUAL", Width: "20%");
            Grid.AddCheckboxColumn("APO_CRITICA", "CRÍTICA");
            Grid.AddCheckboxColumn("APO_HABILITADO", "HABILITADA");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;

        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;

        if (!hayCliente) return;

        ConfigurarUbicacion();
        CargarGrid();
        Grid.DataBind();

        /* La barra de comandos se muestra si hay algo que hacer en ella: crear
           (funcion de escritura) o imprimir (permiso de etiquetas). Con
           ninguno de los dos, desaparece entera. */
        bool puedeEscribir = Token.PuedeFuncion("Crear y editar");
        bool puedeImprimir = Token.Puede("IMPRIMIR ETIQUETAS");

        if (!puedeEscribir && !puedeImprimir)
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;
        else
        {
            GridCommandItem barra = Grid.MasterTableView.GetItems(GridItemType.CommandItem).Length > 0
                ? (GridCommandItem)Grid.MasterTableView.GetItems(GridItemType.CommandItem)[0] : null;

            if (barra != null)
            {
                LinkButton nuevo = (LinkButton)barra.FindControl("lnkNuevo");
                LinkButton eliminar = (LinkButton)barra.FindControl("lnkEliminar");
                LinkButton etiquetas = (LinkButton)barra.FindControl("lnkEtiquetas");
                if (nuevo != null) nuevo.Visible = puedeEscribir;
                if (eliminar != null) eliminar.Visible = puedeEscribir;
                if (etiquetas != null) etiquetas.Visible = puedeImprimir;
            }
        }

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
    /// Cascada Planta -> Area, igual que en Activos.aspx. El area se lista
    /// con su ruta (Produccion / Linea 1) porque una posicion vive en la
    /// hoja del arbol y el nombre solo no dice donde.
    /// </summary>
    protected void ConfigurarUbicacion()
    {
        RadComboBox2 cboPlanta = Cbo("cboPlanta");
        RadComboBox2 cboArea = Cbo("cboArea");
        if (cboPlanta == null || cboArea == null) return;

        int cliente = SitioBase.Session.ClienteId();

        string selP = cboPlanta.SelectedValue;
        string selA = cboArea.SelectedValue;

        List<ClienteInstalacion> plantas =
            new ClienteInstalacionController().GetClienteInstalaciones(new ClienteInstalacion { cin_cliente = cliente })
            ?? new List<ClienteInstalacion>();

        List<InstalacionArea> areas =
            new InstalacionAreaController().GetInstalacionAreas(new InstalacionArea { iar_cliente = cliente, filtro_habilitado = true })
            ?? new List<InstalacionArea>();

        cboPlanta.Items.Clear();
        cboPlanta.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
        foreach (ClienteInstalacion p in plantas)
            cboPlanta.Items.Add(new RadComboBoxItem(p.cin_nombre, p.cin_id.ToString()));

        if (string.IsNullOrEmpty(selP) && plantas.Count == 1)
            selP = plantas[0].cin_id.ToString();
        Seleccionar(cboPlanta, selP);
        selP = cboPlanta.SelectedValue;
        int plantaId; int.TryParse(selP, out plantaId);

        cboArea.Items.Clear();
        cboArea.Items.Add(new RadComboBoxItem("Todas las áreas", ""));
        if (plantaId > 0)
            foreach (InstalacionArea a in areas)
                if (a.iar_cliente_instalacion == plantaId)
                    cboArea.Items.Add(new RadComboBoxItem(a.ruta, a.iar_id.ToString()));

        if (cboArea.FindItemByValue(selA) == null) selA = "";
        Seleccionar(cboArea, selA);
    }

    protected void CargarGrid()
    {
        ActivoPosicion filtro = new ActivoPosicion();
        ActivoPosicionController controller = new ActivoPosicionController();

        // El filtro por cliente en sesion es la barrera multicliente: no es opcional.
        filtro.apo_cliente = SitioBase.Session.ClienteId();

        int id;
        string valArea = Cbo("cboArea") != null ? Cbo("cboArea").SelectedValue : "";
        string valPlanta = Cbo("cboPlanta") != null ? Cbo("cboPlanta").SelectedValue : "";
        if (!string.IsNullOrEmpty(valArea) && int.TryParse(valArea, out id)) filtro.filtro_instalacion_area = id;
        else if (!string.IsNullOrEmpty(valPlanta) && int.TryParse(valPlanta, out id)) filtro.filtro_cliente_instalacion = id;

        RadComboBox2 cboOcupacion = Cbo("cboOcupacion");
        RadComboBox2 cboHabilitado = Cbo("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboOcupacion != null && cboOcupacion.SelectedValue != "")
            filtro.filtro_libre = cboOcupacion.SelectedValue == "1";
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetPosiciones(filtro);
    }

    protected void rgrPosiciones_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                ActivoPosicion p = (ActivoPosicion)item.DataItem;
                string id = item.GetDataKeyValue("apo_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirPosicion('" + query + "')");

                item["apo_id"].Controls.Add(Editar);

                /* Que hay en la posicion hoy, como chip: se lee de un vistazo
                   cuales estan vacias. */
                string equipo = p.activo_id == null
                    ? "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-map-marker-off-outline\"></i>Libre</span>"
                    : "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-engine-outline\"></i>"
                      + Server.HtmlEncode(p.activo_codigo) + "</span> " + Server.HtmlEncode(p.activo_nombre);

                item["EQUIPO"].Controls.Add(new Literal { Text = equipo });
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
                ActivoPosicionController controller = new ActivoPosicionController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];

                    ActivoPosicion entidad = new ActivoPosicion();
                    entidad.apo_id = Int32.Parse(value["apo_id"].ToString());

                    respuesta = controller.DeletePosicion(entidad);
                    if (respuesta.error) break;
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

    /// <summary>
    /// HU-034 #2: un solo documento con una etiqueta por posicion marcada.
    /// Sin seleccion se imprimen todas las que muestra la grilla, que es lo
    /// que quiere quien filtro por area para rotular la sala completa.
    /// </summary>
    protected void lnkEtiquetas_Click(object sender, EventArgs e)
    {
        try
        {
            StringBuilder ids = new StringBuilder();

            if (Grid.SelectedIndexes.Count > 0)
            {
                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];
                    if (ids.Length > 0) ids.Append(",");
                    ids.Append(value["apo_id"].ToString());
                }
            }
            else
            {
                foreach (Telerik.Web.UI.DataKey value in Grid.MasterTableView.DataKeyValues)
                {
                    if (ids.Length > 0) ids.Append(",");
                    ids.Append(value["apo_id"].ToString());
                }
            }

            if (ids.Length == 0)
            {
                Tools.tools.ClientAlert("No hay posiciones que imprimir con el filtro actual.");
                return;
            }

            string query = Server.UrlEncode(Tools.Crypto.Encrypt("Origen=" + EtiquetaOrigen.Posicion + "&Ids=" + ids));
            Tools.tools.ClientExecute("abrirEtiquetas('" + query + "')");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }
}
