using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de centros de costo (HU-013).
///
/// El acceso a la pantalla lo resuelve el master con Token.ExigirPagina():
/// aqui no hay bloque de seguridad porque en SIGMA los permisos son datos,
/// no codigo. Lo unico que se pregunta es la funcion de escritura.
/// </summary>
public partial class View_Organizacion_CentrosCosto_CentrosCosto : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("CCO_ID", "", Width: "3%");
            Grid.AddColumn("CCO_CODIGO", "CÓDIGO", Width: "15%");
            Grid.AddColumn("CCO_NOMBRE", "NOMBRE", Width: "32%");
            Grid.AddColumn("PADRE_NOMBRE", "DEPENDE DE", Width: "25%");
            Grid.AddColumn("RUTA", "UBICACIÓN", Width: "20%");
            Grid.AddCheckboxColumn("CCO_HABILITADO", "HABILITADO");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        // Sin cliente en sesion no hay nada que listar: los centros de costo
        // son de un cliente, no de la plataforma.
        bool hayCliente = SitioBase.Session.ClienteId() > 0;

        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;

        if (!hayCliente) return;

        // Sin la funcion de escritura la barra de comandos no se muestra.
        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        CentroCosto filtro = new CentroCosto();
        CentroCostoController controller = new CentroCostoController();

        filtro.cco_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetCentrosCosto(filtro);
    }

    protected void rgrCentrosCosto_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("cco_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirCentroCosto('" + query + "')");

                item["cco_id"].Controls.Add(Editar);

                // El nivel del arbol se muestra indentando el nombre. Es lo
                // que convierte una lista plana en algo que se lee como
                // jerarquia sin cambiar de control.
                int nivel = 1;
                object valorNivel = DataBinder.Eval(item.DataItem, "nivel");
                if (valorNivel != null) int.TryParse(valorNivel.ToString(), out nivel);

                if (nivel > 1)
                    item["cco_nombre"].Style["padding-left"] = ((nivel - 1) * 22) + "px";
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
                CentroCostoController controller = new CentroCostoController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];

                    CentroCosto entidad = new CentroCosto();
                    entidad.cco_id = Int32.Parse(value["cco_id"].ToString());

                    respuesta = controller.DeleteCentroCosto(entidad);
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
