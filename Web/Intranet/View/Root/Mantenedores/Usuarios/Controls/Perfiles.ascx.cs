using System;
using System.Collections.Generic;
using Telerik.Web.UI;
using SitioBase.Controller;
using SitioBase.Model;

public partial class View_Sistema_Usuarios_Controls_Perfiles : System.Web.UI.UserControl
{
    private UsuarioPerfil usuario = new UsuarioPerfil();
    private UsuarioController usuarioController = new UsuarioController();

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
            Grid.AddColumn("upe_perfil", "ID", "5%");
            Grid.AddColumn("perfil_nombre", "PERFIL", "100%");
            Grid.AddCheckboxColumn("perfil_habilitado", "HABILITADO", "80");
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
        usuario.upe_usuario = IdUsuario;
        Grid.DataSource = usuarioController.GetUsuarioPerfil(usuario);
    }

    protected void lnkNuevo_Click(object sender, EventArgs e)
    {
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdUsuario=" + IdUsuario.ToString()));
        Tools.tools.ClientExecute("abrirPerfil('" + query + "')");
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
                List<UsuarioPerfil> listado = new List<UsuarioPerfil>();

                foreach (string item in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];

                    UsuarioPerfil add = new UsuarioPerfil();
                    add.upe_id = Int32.Parse(value["upe_id"].ToString());
                    listado.Add(add);
                }

                Respuesta respuesta = usuarioController.DeleteUsuarioPerfil(listado);

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