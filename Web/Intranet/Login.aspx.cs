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
            /* Viene rebotado por la compuerta de suscripción: eligió un
               cliente con la suscripción caída y no es quien la administra.
               Se le explica aquí, porque su sesión ya se cerró y no queda
               ninguna pantalla del sistema donde decírselo. */
            if (Request.QueryString["motivo"] == "suscripcion")
            {
                MostrarError("La suscripción de esa empresa no está vigente. " +
                             "Contacta al administrador de tu empresa para regularizarla.");
            }

            /* Con la sesion rearmada desde la cookie persistente no tiene
               sentido pedir la clave otra vez. */
            else if (Session["usu_id"] != null)
            {
                Response.Redirect("~/Default.aspx");
                return;
            }

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

        /* Centro Comercial (J). Una cuenta con clave temporal (demo o cliente
           recién firmado) no entra hasta cambiarla: la sesión se descarta y
           solo queda el id pendiente, que CambiarClave.aspx usa y nada más. */
        int pendiente;
        if (int.TryParse(SitioBase.Session.UsuarioId(), out pendiente) && DebeCambiarClave(pendiente))
        {
            Session.Clear();
            System.Web.Security.FormsAuthentication.SignOut();
            Session[CambiarClave.CLAVE_SESION] = pendiente;
            Response.Redirect("~/CambiarClave.aspx");
            return;
        }

        // HU-002. Adonde va depende de a cuantos clientes pertenece:
        // con uno se elige solo y no ve el selector; con varios tiene que
        // elegir antes de continuar.
        SitioBase.SesionPersistente.Emitir();

        ClienteSesionController clienteSesion = new ClienteSesionController();
        string destino = clienteSesion.ResolverClienteInicial(respuesta.codigo);

        Response.Redirect(destino);
    }

    /// <summary>Si la cuenta entró con una clave temporal (SEL_USUARIO_DEBE_CAMBIAR, bloque 456).</summary>
    private static bool DebeCambiarClave(int usuario)
    {
        try
        {
            System.Collections.Generic.Dictionary<string, object> f = SoporteDatos.Fila("SEL_USUARIO_DEBE_CAMBIAR", "@USUARIO", usuario);
            object v; return f.TryGetValue("DEBE", out v) && v != null && Convert.ToBoolean(v);
        }
        catch (Exception)
        {
            return false;
        }
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
