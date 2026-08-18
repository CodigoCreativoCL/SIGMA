using System;
using System.Collections.Generic;
using Telerik.Web.UI;
using SitioBase.Controller;
using SitioBase.Model;

public partial class View_Sistema_Usuarios_Controls_Paises : System.Web.UI.UserControl
{
    private UsuarioController usuarioController = new UsuarioController();
    private Usuario usuario = new Usuario();

    public int IdUsuario
    {
        get { return Convert.ToInt32(ViewState["IdUsuario"]); }
        set { ViewState.Add("IdUsuario", value); }
    }

    public bool SoloLectura
    {
        get { return ((ViewState["SoloLectura"] == null) ? false : bool.Parse(ViewState["SoloLectura"].ToString())); }
        set { ViewState.Add("SoloLectura", value); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("upa_id", "ID", "5%");
            Grid.AddColumn("nombre", "NOMBRE PAIS", "100%");
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarGrid();
        Grid.DataBind();
        udPanel.Update();

        if (SoloLectura)
        {
            Grid.MasterTableView.Columns[0].Visible = false;
            Grid.MasterTableView.GetItems(GridItemType.CommandItem)[0].FindControl("lnkNuevo").Visible = false;
            Grid.MasterTableView.GetItems(GridItemType.CommandItem)[0].FindControl("lnkEliminar").Visible = false;
        }
    }

    protected void CargarGrid()
    {
        usuario.usu_id = IdUsuario;
        Grid.DataSource = usuarioController.GetUsuarioPaises(usuario);
    }

    protected void lnkNuevo_Click(object sender, EventArgs e)
    {
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdUsuario=" + IdUsuario.ToString()));
        Tools.tools.ClientExecute("abrirPaises('" + query + "')");
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un Perfil");
            }
            else
            {
                List<UsuarioPaises> usuarioPaises = new List<UsuarioPaises>();

                foreach (string item in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];

                    UsuarioPaises usuarioPais = new UsuarioPaises();
                    usuarioPais.upa_id = Int32.Parse(value["upa_id"].ToString());

                    usuarioPaises.Add(usuarioPais);
                }

                Respuesta respuesta = usuarioController.DeleteUsuarioPaises(usuarioPaises);

                if (!respuesta.error)
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