using System;
using System.Text.RegularExpressions;
using System.Web.UI;
using SitioBase.Controller;
using SitioBase.Model;

/// <summary>
/// Solicitud del enlace de recuperación (HU-004 escenario 1).
///
/// La pantalla responde SIEMPRE lo mismo, exista o no el correo. Es un
/// requisito explícito de la historia: si respondiera distinto, cualquiera
/// podría averiguar qué correos están registrados probándolos de a uno.
/// </summary>
public partial class RecuperarClave : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            txtCorreo.Focus();
        }
    }

    protected void btnEnviar_Click(object sender, EventArgs e)
    {
        OcultarError();

        string correo = txtCorreo.Text.Trim();

        // Lo único que se valida en pantalla es el formato. Que el correo
        // exista o no NO se comprueba aquí: esa respuesta es la que no se
        // puede dar.
        if (string.IsNullOrEmpty(correo))
        {
            MostrarError("Ingresa tu correo electrónico.");
            return;
        }

        if (!Regex.IsMatch(correo, @"^[^@\s]+@[^@\s]+\.[^@\s]+$"))
        {
            MostrarError("El correo no tiene un formato válido.");
            return;
        }

        try
        {
            CuentaController controller = new CuentaController();
            Respuesta respuesta = controller.SolicitarEnlace(correo, Request.UserHostAddress);

            litMensaje.Text = Server.HtmlEncode(respuesta.detalle);
            pnlSolicitud.Visible = false;
            pnlEnviado.Visible = true;
        }
        catch (Exception ex)
        {
            MostrarError("No fue posible procesar la solicitud. Intenta nuevamente.");
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
