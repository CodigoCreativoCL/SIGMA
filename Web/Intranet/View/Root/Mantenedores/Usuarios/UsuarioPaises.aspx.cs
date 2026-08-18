using System;
using System.Collections.Generic;
using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
public partial class View_Sistema_Usuarios_UsuarioPaises : System.Web.UI.Page
{
    private UsuarioController usuarioController = new UsuarioController();
    private Usuario usuario = new Usuario();

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
            Grid.AddColumn("pai_id", "ID", Width:"5%");
            Grid.AddColumn("pai_nombres", "NOMBRE PAIS", Width: "90%");
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
        usuario.usu_id = IdUsuario;
        Grid.DataSource = usuarioController.GetUsuarioPaisesNoAsociados(usuario);
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
                List<UsuarioPaises> usuarioPaises = new List<UsuarioPaises>();

                foreach (string item in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];

                    UsuarioPaises usuarioPais = new UsuarioPaises();
                    usuarioPais.upa_id_usuario = IdUsuario;
                    usuarioPais.upa_id_pais = Int32.Parse(value["pai_id"].ToString());
                    usuarioPaises.Add(usuarioPais);
                }

                Respuesta respuesta = usuarioController.InsertUsuarioPais(usuarioPaises);

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