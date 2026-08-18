using System;
using System.IO;
using SitioBase.Model;
using SitioBase.Controller;
using Telerik.Web.UI;
using SitioBase;

public partial class View_Sistema_Usuarios_Usuario : System.Web.UI.Page
{
    UsuarioController usuariosController = new UsuarioController();

    public int Id
    {
        get { return Convert.ToInt32(ViewState["id"]); }
        set { ViewState.Add("id", value); }
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
            //Recupero el query string
            string[] query = Tools.Crypto.Decrypt(Server.UrlDecode(Request.QueryString["query"].ToString())).Split('&');

            foreach (string arr in query)
            {
                string[] array = arr.ToString().Split('=');
                switch (array[0].ToString())
                {
                    case "Id":
                        Id = Int32.Parse(array[1].ToString());
                        break;
                }

            }
        }
    }

    public void LoadControls(object sender, System.EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;
                switch (ctrl.ID)
                {
                    
                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            CargarDatos();
        }

        Validaciones();
    }

    protected void Validaciones()
    {
        if (Id > 0)
        {
            ragTab.Tabs[1].Visible = true;
            ragTab.Tabs[2].Visible = true;
            //pnlNombre.Visible = true;
        }
        else 
        {
            ragTab.Tabs[1].Visible = false;
            ragTab.Tabs[2].Visible = false;
            //pnlNombre.Visible = false;
            lblTituloUsuario.Text = "Nuevo Usuario";
        }
    }

    protected void CargarDatos()
    {
        if (Id > 0)
        {
            Usuario usuario = new Usuario();
            usuario.usu_id = Id;
            usuario.devuelve_foto = true;

            usuario = usuariosController.GetUsuario(usuario);

            lblTituloUsuario.Text = usuario.usu_login;

            lblID.Text = Id.ToString();
            textLogin.Text = usuario.usu_login;
            txtIdentificador.Text = usuario.usu_identificador;
            textPassword.Text = usuario.usu_password;
            TextNombre.Text = usuario.usu_nombres;
            txtPaterno.Text = usuario.usu_apellido_paterno;
            TextMaterno.Text = usuario.usu_apellido_materno;
            Textfono.Text = usuario.usu_telefono;
            TextCorreo.Text = usuario.usu_correo;
            if (usuario.usu_foto != null)
            {
                imgLogo.ImageUrl = "data:image/jpeg;base64," + Convert.ToBase64String(usuario.usu_foto, 0, usuario.usu_foto.Length);
                //lnkAgregarFoto.CssClass = "editar-img";
            }
            if (usuario.usu_habilitado != null)
            {
                if (bool.Parse(usuario.usu_habilitado.ToString()))
                {
                    rdbSi.Checked = true;
                    rdbNo.Checked = false;
                }
                else
                {
                    rdbSi.Checked = false;
                    rdbNo.Checked = true;
                }
            }
                        
            if (usuario.usu_foto != null)
            {
                string base64String = Convert.ToBase64String(usuario.usu_foto, 0, usuario.usu_foto.Length);
                imgLogo.ImageUrl = "data:image/jpeg;base64," + base64String;
            }

            wucUsuarioPerfil.IdUsuario = Id;
            wucUsuarioPaises.IdUsuario = Id;
        }
    }

    protected void btnGuardar_OnClick(object sender, EventArgs e)
    {
        try
        {
            Respuesta respuesta = new Respuesta();
            bool formatoCorrecto = true;

            if (fudLogo.HasFile)
            {
                if (Path.GetExtension(fudLogo.FileName).ToUpper() == ".JPG" | Path.GetExtension(fudLogo.FileName).ToUpper() == ".PNG")
                {
                    if (fudLogo.FileBytes.Length > 2097152) //2MB (1 MB = 1048576 bytes)
                    {
                        Tools.tools.ClientAlert("El tamaño del archivo no debe superar los 2MB", "alerta");
                        formatoCorrecto = false;
                        return;
                    }
                }
                else
                {
                    formatoCorrecto = false;
                    Tools.tools.ClientAlert("El formato de la imagen debe ser JPG O PNG","alerta");
                    return;
                }
            }

            if (formatoCorrecto)
            {
                Usuario usuario = new Usuario();

                usuario.usu_id = Id;
                usuario.usu_login = textLogin.Text;
                usuario.usu_password = textPassword.Text;
                usuario.usu_nombres = TextNombre.Text;
                usuario.usu_apellido_paterno = txtPaterno.Text;
                usuario.usu_apellido_materno = TextMaterno.Text;
                usuario.usu_telefono = Textfono.Text;
                usuario.usu_correo = TextCorreo.Text;
                usuario.usu_identificador = txtIdentificador.Text;

                if (rdbSi.Checked)
                    usuario.usu_habilitado = true;
                else
                    usuario.usu_habilitado = false;

                if (fudLogo.HasFile)
                {
                    usuario.usu_foto = SitioBase.SitioBase.ReducirImagen(fudLogo.FileBytes, 100, 100);
                    usuario.usu_foto_extension = Path.GetExtension(fudLogo.FileName);
                }
                    
                if (Id > 0)
                    respuesta = usuariosController.UpdateUsuario(usuario);
                else
                {
                    respuesta = usuariosController.InsertUsuario(usuario);
                    Id = respuesta.codigo;

                    wucUsuarioPerfil.IdUsuario = Id;
                    wucUsuarioPaises.IdUsuario = Id;
                }

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