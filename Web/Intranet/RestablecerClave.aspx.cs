using System;
using System.Web.UI;
using SitioBase.Controller;
using SitioBase.Model;

/// <summary>
/// Fijar la contraseña nueva con el enlace recibido (HU-004 escenarios 2 y 3).
/// </summary>
public partial class RestablecerClave : System.Web.UI.Page
{
    /// <summary>
    /// El token del enlace. Viaja en ViewState entre el GET y el postback:
    /// si se volviera a leer del querystring al guardar, bastaría con
    /// recargar la página para reusar un enlace ya consumido.
    /// </summary>
    private string Token
    {
        get { return ViewState["Token"] != null ? (string)ViewState["Token"] : ""; }
        set { ViewState["Token"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Token = Request.QueryString["t"] != null ? Request.QueryString["t"].ToString() : "";
            EvaluarEnlace();
        }
    }

    /// <summary>
    /// Se comprueba el estado ANTES de mostrar el formulario, para no
    /// hacerle escribir una contraseña a alguien cuyo enlace ya no sirve.
    /// </summary>
    private void EvaluarEnlace()
    {
        CuentaController controller = new CuentaController();
        string estado = controller.EstadoEnlace(Token);

        if (estado == "VIGENTE")
        {
            pnlFormulario.Visible = true;
            pnlNoValido.Visible = false;
            txtClave.Focus();
            return;
        }

        pnlFormulario.Visible = false;
        pnlNoValido.Visible = true;

        // Vencido y usado se distinguen: el escenario 3 pide informar que
        // expiró y ofrecer solicitar uno nuevo, que no es lo mismo que
        // decirle a alguien que su enlace nunca existió.
        switch (estado)
        {
            case "VENCIDO":
                litTituloNoValido.Text = "El enlace expiró";
                litMensajeNoValido.Text = "Los enlaces de recuperación duran 60 minutos. Solicita uno nuevo y vuelve a intentar.";
                break;

            case "USADO":
                litTituloNoValido.Text = "El enlace ya se usó";
                litMensajeNoValido.Text = "Cada enlace sirve una sola vez. Si necesitas cambiar tu contraseña otra vez, solicita uno nuevo.";
                break;

            default:
                litTituloNoValido.Text = "El enlace no es válido";
                litMensajeNoValido.Text = "Revisa que hayas copiado la dirección completa del correo, o solicita un enlace nuevo.";
                break;
        }
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        OcultarError();

        if (string.IsNullOrEmpty(txtClave.Text))
        {
            MostrarError("Ingresa tu contraseña nueva.");
            return;
        }

        if (txtClave.Text != txtConfirmacion.Text)
        {
            MostrarError("Las contraseñas no coinciden.");
            return;
        }

        try
        {
            CuentaController controller = new CuentaController();
            Respuesta respuesta = controller.RestablecerConEnlace(Token, txtClave.Text);

            if (respuesta.error)
            {
                // El detalle viene del SP: largo mínimo, letra y número, o
                // repetir una de las tres anteriores. Son mensajes que el
                // usuario necesita leer tal cual para poder corregir.
                MostrarError(respuesta.detalle);
                return;
            }

            pnlFormulario.Visible = false;
            pnlNoValido.Visible = false;
            pnlListo.Visible = true;
        }
        catch (Exception ex)
        {
            MostrarError("No fue posible actualizar la contraseña. Intenta nuevamente.");
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
