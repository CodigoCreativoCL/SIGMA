using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
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
/// </summary>
public partial class View_Activos_Activos_Activos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("ACT_ID", "", Width: "3%");
            Grid.AddColumn("ACT_CODIGO", "CÓDIGO", Width: "12%");
            Grid.AddColumn("ACT_NOMBRE", "NOMBRE", Width: "27%");
            Grid.AddColumn("PLANTA_NOMBRE", "PLANTA", Width: "18%");
            Grid.AddColumn("TIPO_NOMBRE", "TIPO", Width: "13%");
            Grid.AddColumn("ESTADO_NOMBRE", "ESTADO", Width: "13%");
            Grid.AddColumn("CRITICIDAD_NOMBRE", "CRITICIDAD", Width: "9%");
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

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        Activo filtro = new Activo();
        ActivoController controller = new ActivoController();

        // El filtro por cliente en sesión es la barrera multicliente: no es
        // opcional.
        filtro.act_cliente = SitioBase.Session.ClienteId();

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
