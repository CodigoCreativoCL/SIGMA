using System;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using SitioBase.Controller;
using SitioBase.Model;
using SitioBase;

public partial class View_Sistema_Usuarios_Usuarios : System.Web.UI.Page
{
    UsuarioController controller = new UsuarioController();

    protected void Page_Load(object sender, EventArgs e)
    {

        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("USU_ID", "", "10");
            Grid.AddColumn("USU_ID", "ID", "10");
            Grid.AddColumn("USU_LOGIN", "LOGIN");
            Grid.AddColumn("NOMBRE_COMPLETO", "NOMBRE", "20%");
            Grid.AddColumn("USU_CORREO", "CORREO");
            Grid.AddColumn("PAISES", "PAISES");
            Grid.AddColumn("PERFILES", "PERFILES");
            Grid.AddColumn("USU_HABILITADO", "ESTADO");
            
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }
    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;
                switch (ctrl.ID)
                {                  

                    case "cboPerfiles":

                        PerfilController perfilController = new PerfilController();
                        Perfil perfil = new Perfil();
                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataValueField = "per_id";
                        ctrl.DataTextField = "per_nombre";
                        perfil.tipo = "1";
                        ctrl.DataSource = perfilController.ListoPerfiles(perfil);
                        ctrl.DataBind();

                        break;

                    case "cboPais":

                        PaisesController paisesController = new PaisesController();
                        Paises paises = new Paises();
                        paises.filtro_habilitado = "1";
                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataValueField = "pai_id";
                        ctrl.DataTextField = "pai_nombres";
                        ctrl.DataSource = paisesController.GetPaises(paises);
                        ctrl.DataBind();

                        break;

                }
            }
        }
    }
    protected void CargarGrid()
    {
        Usuario usuario = new Usuario();
        if (wucFiltro.Filtro() != null) usuario.filtro = wucFiltro.Filtro();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        if (cboHabilitado.SelectedValue == "1") usuario.usu_habilitado = true;
        if (cboHabilitado.SelectedValue == "0") usuario.usu_habilitado = false;

        RadComboBox2 cboPerfiles = (RadComboBox2)wucFiltro.FindControl("cboPerfiles");
        if (cboPerfiles.SelectedValue != "") usuario.id_perfiles = cboPerfiles.SelectedValue;

        RadComboBox2 cboPais = (RadComboBox2)wucFiltro.FindControl("cboPais");
        if (cboPais.SelectedValue != "") usuario.id_paises = cboPais.SelectedValue;
      
        //usuario.perfiles = "1";

        Grid.DataSource = controller.GetUsuarios(usuario);
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("usu_id").ToString();
                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                //Creo el link
                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkAnular" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrir('" + query + "')");

                //Asigno el Link a la celda
                GridDataItem DataItem = e.Item as GridDataItem;
                TableCell USU_ID = DataItem["usu_id"];

                USU_ID.Controls.Add(Editar);

                TableCell USU_HABILITADO = DataItem["USU_HABILITADO"];

                if (USU_HABILITADO.Text == "True")
                    USU_HABILITADO.Text = "Habilitado";
                else
                    USU_HABILITADO.Text = "Deshabilitado";

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

                foreach (string item in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                    int id = Int32.Parse(value["usu_id"].ToString());

                    Usuario usuario = new Usuario();
                    usuario.usu_id = id;

                    respuesta = controller.DeleteUsuario(usuario);
                }

                if(!respuesta.error)
                    Tools.tools.ClientAlert(respuesta.detalle, "ok");
                else
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }
}