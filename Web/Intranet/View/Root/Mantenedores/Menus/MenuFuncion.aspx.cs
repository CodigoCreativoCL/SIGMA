using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using Telerik.Web.UI;

public partial class View_Root_Mantenedores_MenuFuncion : System.Web.UI.Page
{
    private MantenedorMenusController controller = new MantenedorMenusController();

    public int IdMenu
    {
        get { return Convert.ToInt32(ViewState["IdMenu"]); }
        set { ViewState.Add("IdMenu", value); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (Request.QueryString["query"] != null)
            {
                string[] query = Tools.Crypto.Decrypt(Server.UrlDecode(Request.QueryString["query"].ToString())).Split('&');

                foreach (string arr in query)
                {
                    string[] array = arr.ToString().Split('=');
                    if (array[0].ToString() == "Id")
                        IdMenu = Int32.Parse(array[1].ToString());
                }
            }

            Grid.AddSelectColumn();
            Grid.AddColumn("mfu_id", "ID", Width: "8%");
            Grid.AddColumn("mfu_nombre", "FUNCION", Width: "30%");
            Grid.AddColumn("prm_codigo", "PERMISO", Width: "40%");
            Grid.AddColumn("prm_modulo", "MODULO", Width: "22%");

            Menus menu = controller.GetMenu(IdMenu);
            lblMenu.Text = menu != null ? menu.mnu_nombre : "(menú no encontrado)";

            cboPermiso.Items.Clear();
            foreach (Permiso p in controller.GetPermisos(null))
                cboPermiso.Items.Add(new RadComboBoxItem(p.prm_modulo + " · " + p.prm_codigo, p.prm_id.ToString()));
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        Grid.DataSource = controller.GetFunciones(IdMenu);
        Grid.DataBind();
        udPanel.Update();
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        // La grilla es de solo lectura: una funcion se agrega o se elimina,
        // no se edita. Cambiarle el permiso a una existente equivale a otra.
    }

    protected void btnAgregar_Click(object sender, EventArgs e)
    {
        try
        {
            string nombre = cboNombre.Text;
            int permiso;

            if (string.IsNullOrEmpty(nombre))
            {
                Tools.tools.ClientAlert("Debe indicar el nombre de la función.", "alerta");
                return;
            }

            if (!int.TryParse(cboPermiso.SelectedValue, out permiso) || permiso <= 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar el permiso que representa la función.", "alerta");
                return;
            }

            MenuFuncion funcion = new MenuFuncion();
            funcion.mfu_nombre = nombre;
            funcion.mfu_menu = IdMenu;
            funcion.mfu_permiso = permiso;

            Respuesta respuesta = controller.InsertFuncion(funcion);

            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok");
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos una función.");
                return;
            }

            Respuesta respuesta = new Respuesta();

            foreach (string item in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                respuesta = controller.DeleteFuncion(Int32.Parse(value["mfu_id"].ToString()));
            }

            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok");
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }
}
