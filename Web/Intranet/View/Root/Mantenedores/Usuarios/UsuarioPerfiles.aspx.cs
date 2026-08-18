using System;
using System.Collections.Generic;
using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
public partial class View_Sistema_Usuarios_UsuarioPerfiles : System.Web.UI.Page
{
    private UsuarioPerfil usuario = new UsuarioPerfil();
    private UsuarioController usuarioController = new UsuarioController();

    public int IdUsuario
    {
        get { return Convert.ToInt32(ViewState["IdUsuario"]); }
        set { ViewState.Add("IdUsuario", value); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina
        MenuPerfil ver = new MenuPerfil();
        ver.mpe_menu = (int)Paginas.menu_5.Ver;
        Token.SecurityManagerVer(ver);
        #endregion
        if (!IsPostBack)
        {
            string[] query = Tools.Crypto.Decrypt(Server.UrlDecode(Request.QueryString["query"].ToString())).Split('&');

            foreach (string arr in query)
            {
                string[] array = arr.ToString().Split('=');
                switch (array[0].ToString())
                {
                    case "IdUsuario":
                        IdUsuario = Int32.Parse(array[1].ToString());
                        break;
                }
            }

            Grid.AddSelectColumn();
            Grid.AddColumn("upe_perfil", "ID", "5%");
            Grid.AddColumn("perfil_nombre", "PERFIL", "80%");
            Grid.AddCheckboxColumn("perfil_habilitado", "HABILITADO", "15%");
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        usuario.upe_usuario = IdUsuario;
        usuario.perfil_tipo = 1;
        Grid.DataSource = usuarioController.GetUsuarioPerfilesNoAsociados(usuario);
    }

    protected void btnAsociar_Click(object sender, EventArgs e)
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
                    add.upe_usuario = IdUsuario;
                    add.upe_perfil = Int32.Parse(value["upe_perfil"].ToString());
                    listado.Add(add);
                }

                Respuesta respuesta = usuarioController.InsertUsuarioPerfil(listado);

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