using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Web;
using System.Web.UI.HtmlControls;
using System.Web.UI.WebControls;
using SitioBase.Controller;
using SitioBase.Model;

public partial class Login : System.Web.UI.Page
{

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {

        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {

        Page.DataBind();
    }

    protected void btnLogin_Click(object sender, EventArgs e)
    {
    }


    protected void btnLoginEmpresa_Click(object sender, EventArgs e)
    {
        UsuarioController usuarioController = new UsuarioController();

        Usuario usuario = new Usuario();
        usuario.usu_login = txtLogin.Text;
        usuario.usu_password = txtPassword.Text;
        string ComputerName = Environment.MachineName;
        Console.WriteLine("Computer Name: " + ComputerName);
        Respuesta respuesta = usuarioController.GetUsuarioLogin(usuario);

        if (!respuesta.error)
        {
            Response.Redirect("~/Default.aspx");
        }
        else
            lblMensaje.Text = respuesta.detalle;
    }
}


