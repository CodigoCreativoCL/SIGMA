using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado del arbol de menus.
///
/// No hay bloque de seguridad: el permiso de esta pagina sale de su propia
/// URL contra Menus.mnu_link, y lo verifica Default.master.
/// </summary>
public partial class View_Root_Mantenedores_Menus : System.Web.UI.Page
{
    private MantenedorMenusController controller = new MantenedorMenusController();

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("mnu_id", "", Width: "2%");
            Grid.AddColumn("mnu_id", "ID", Width: "5%");
            Grid.AddColumn("mnu_nombre", "NOMBRE", Width: "18%");
            Grid.AddColumn("padre_nombre", "DEPENDE DE", Width: "13%");
            Grid.AddColumn("mnu_tipo", "TIPO", Width: "8%");
            Grid.AddColumn("mnu_link", "PAGINA", Width: "26%");
            Grid.AddColumn("prm_codigo", "PERMISO", Width: "20%");
            Grid.AddColumn("mnu_orden", "ORDEN", Width: "4%");
            Grid.AddCheckboxColumn("mnu_visible", "VISIBLE", Width: "4%");
        }
        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        Menus filtro = new Menus();
        if (wucFiltro.Filtro() != null) filtro.filtro = wucFiltro.Filtro();

        Grid.DataSource = controller.GetMenus(filtro);
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("mnu_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink editar = new HyperLink();
                editar.ID = "lnkEditar" + id;
                editar.CssClass = "icono_Editar";
                editar.NavigateUrl = "javascript:void(0)";
                editar.Attributes.Add("onclick", "abrirMenu('" + query + "')");
                item["mnu_id"].Controls.Add(editar);

                // Las funciones solo tienen sentido en una pagina, no en un contenedor.
                if (item["mnu_link"].Text != "#")
                {
                    HyperLink funciones = new HyperLink();
                    funciones.ID = "lnkFunciones" + id;
                    funciones.Text = "Funciones";
                    funciones.NavigateUrl = "javascript:void(0)";
                    funciones.Attributes.Add("onclick", "abrirFunciones('" + query + "')");
                    item["prm_codigo"].Controls.Add(new LiteralControl("&nbsp;&nbsp;"));
                    item["prm_codigo"].Controls.Add(funciones);
                }
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
                return;
            }

            Respuesta respuesta = new Respuesta();

            foreach (string item in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                respuesta = controller.DeleteMenu(Int32.Parse(value["mnu_id"].ToString()));
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
