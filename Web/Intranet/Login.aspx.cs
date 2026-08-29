using System;
using System.Web.UI;
using SitioBase.Controller;
using SitioBase.Model;

public partial class Login : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            // El cursor arranca donde el usuario va a escribir.
            txtCorreo.Focus();
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        Page.DataBind();
    }

    protected void btnLogin_Click(object sender, EventArgs e)
    {
        OcultarError();

        if (string.IsNullOrWhiteSpace(txtCorreo.Text) ||
            string.IsNullOrWhiteSpace(txtPassword.Text))
        {
            MostrarError("Ingresa tu correo y tu contraseña.");
            return;
        }

        UsuarioController usuarioController = new UsuarioController();
        Usuario usuario = new Usuario();

        usuario.usu_login = txtCorreo.Text.Trim();
        usuario.usu_password = txtPassword.Text;

        Respuesta respuesta = usuarioController.GetUsuarioLogin(usuario);

        if (respuesta.error)
        {
            // El error se muestra en la pantalla, no en un popup: el usuario
            // lo lee junto al campo que tiene que corregir.
            MostrarError(respuesta.detalle);
            txtPassword.Text = string.Empty;
            txtPassword.Focus();
            return;
        }

        Response.Redirect("~/Default.aspx");
    }

    private void MostrarError(string mensaje)
    {
        litError.Text = Server.HtmlEncode(mensaje);
        pnlError.Visible = true;
    }

    private void OcultarError()
    {
        litError.Text = string.Empty;
        pnlError.Visible = false;
    }
}
