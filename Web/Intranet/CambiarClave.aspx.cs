using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;

/// <summary>
/// Cambio obligatorio de contraseña en el primer ingreso (Centro Comercial, J).
///
/// SIN SESIÓN, CON UN SOLO DATO
///   Login.aspx descarta la sesión de quien entró con clave temporal y deja
///   solo su id en Session[CLAVE_SESION]. Esta página no ve nada más del
///   sistema: guarda la clave nueva y recién entonces arma la sesión normal,
///   igual que el login.
///
/// LAS REGLAS SON LAS DEL SP
///   El navegador las muestra en vivo; UPD_USUARIO_CLAVE_OBLIGATORIA las vuelve
///   a exigir y, por el historial, impide reutilizar la clave temporal.
/// </summary>
public partial class CambiarClave : System.Web.UI.Page
{
    public const string CLAVE_SESION = "SIGMA_CLAVE_PENDIENTE";

    private int Pendiente
    {
        get { object v = Session[CLAVE_SESION]; return v is int ? (int)v : 0; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (Pendiente <= 0) { Response.Redirect("~/Login.aspx"); return; }
        if (!IsPostBack)
        {
            Dictionary<string, object> f = SoporteDatos.Fila("SEL_USUARIO_DEBE_CAMBIAR", "@USUARIO", Pendiente);
            object v;
            if (!f.TryGetValue("DEBE", out v) || v == null || !Convert.ToBoolean(v)) { Session.Remove(CLAVE_SESION); Response.Redirect("~/Login.aspx"); return; }
            litCorreo.Text = Server.HtmlEncode(Convert.ToString(f["CORREO"]));
        }
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        pnlError.Visible = false;
        int usuario = Pendiente;
        if (txtNueva.Text != txtRepite.Text) { MostrarError("Las contraseñas no coinciden."); return; }

        SqlCommand cmd = Conexion.GetCommand("UPD_USUARIO_CLAVE_OBLIGATORIA");
        try
        {
            cmd.Parameters.AddWithValue("@USUARIO", usuario);
            cmd.Parameters.AddWithValue("@PASSWORD_NUEVO", txtNueva.Text);
            cmd.ExecuteNonQuery();
        }
        catch (SqlException ex)
        {
            MostrarError(WsComercial.Limpio(ex.Message));
            return;
        }
        finally { if (cmd.Connection != null) cmd.Connection.Close(); }

        // Ahora sí, la sesión normal, igual que Login.aspx.
        Session.Remove(CLAVE_SESION);
        string login = Convert.ToString(SoporteDatos.Fila("SEL_USUARIO_DEBE_CAMBIAR", "@USUARIO", usuario)["LOGIN"]);
        Respuesta r = new UsuarioController().GetUsuarioSession(new Usuario { usu_id = usuario, usu_login = login });
        if (r.error) { Response.Redirect("~/Login.aspx"); return; }
        SesionPersistente.Emitir();
        Response.Redirect(new ClienteSesionController().ResolverClienteInicial(r.codigo));
    }

    protected void lnkSalir_Click(object sender, EventArgs e)
    {
        Session.Clear();
        Response.Redirect("~/Login.aspx");
    }

    private void MostrarError(string m)
    {
        litError.Text = Server.HtmlEncode(m);
        pnlError.Visible = true;
    }
}
