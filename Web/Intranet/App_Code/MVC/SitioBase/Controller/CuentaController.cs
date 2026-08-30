using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Linq;
using System.Net.Mail;
using System.Security.Cryptography;
using System.Web;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// La cuenta de la propia persona: recuperar la contrasena (HU-004) y
    /// mantener sus datos (HU-005).
    ///
    /// Es el unico controller cuyos metodos publicos NO empiezan con
    /// Token.TokenSeguridad(): quien esta recuperando su contrasena por
    /// definicion no tiene sesion. Los metodos de HU-005, que si requieren
    /// sesion, la exigen.
    /// </summary>
    public class CuentaController
    {
        /* ================================================================
           HU-004 - RECUPERACION
           ================================================================ */

        /// <summary>
        /// Genera el token del enlace.
        ///
        /// Se usa RNGCryptoServiceProvider y no Random: Random se siembra
        /// con el reloj, asi que dos solicitudes en el mismo milisegundo dan
        /// el mismo token y, peor, la secuencia es predecible. Un token de
        /// recuperacion predecible es una llave maestra.
        ///
        /// Se codifica en base64 apto para URL: el token viaja en el enlace.
        /// </summary>
        private string GenerarToken()
        {
            byte[] bytes = new byte[32];

            using (RNGCryptoServiceProvider rng = new RNGCryptoServiceProvider())
            {
                rng.GetBytes(bytes);
            }

            return Convert.ToBase64String(bytes)
                          .Replace("+", "-")
                          .Replace("/", "_")
                          .Replace("=", "");
        }

        /// <summary>
        /// Solicita el enlace de recuperacion (HU-004 escenario 1).
        ///
        /// SIEMPRE devuelve exito, exista o no el correo. Es el escenario 1
        /// al pie de la letra: "el mensaje en pantalla es el mismo exista o
        /// no el correo". Si respondiera distinto, cualquiera podria
        /// averiguar que correos estan registrados probandolos de a uno.
        ///
        /// Que el envio del correo falle tampoco cambia lo que ve el
        /// usuario: se registra en Sis_Excepcion y se sigue.
        /// </summary>
        public Respuesta SolicitarEnlace(string correo, string ip)
        {
            Respuesta respuesta = new Respuesta();
            respuesta.error = false;
            respuesta.detalle = "Si el correo está registrado, le enviamos un enlace para restablecer su contraseña. " +
                                "Revise su bandeja de entrada; el enlace vence en 60 minutos.";

            SqlCommand cmdExecute = null;

            try
            {
                string token = GenerarToken();

                cmdExecute = Conexion.GetCommand("INS_USUARIO_RECUPERACION");
                cmdExecute.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                cmdExecute.Parameters.AddWithValue("@CORREO", correo);
                cmdExecute.Parameters.AddWithValue("@TOKEN", token);
                cmdExecute.Parameters.AddWithValue("@IP", (object)ip ?? DBNull.Value);
                cmdExecute.Parameters.AddWithValue("@ENVIAR", false).Direction = System.Data.ParameterDirection.Output;
                cmdExecute.Parameters.AddWithValue("@USUARIO_ID", 0).Direction = System.Data.ParameterDirection.Output;
                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                bool enviar = Convert.ToBoolean(cmdExecute.Parameters["@ENVIAR"].Value);

                if (enviar)
                    EnviarCorreoRecuperacion(correo, token);
            }
            catch (Exception ex)
            {
                if (cmdExecute != null && cmdExecute.Connection != null)
                    cmdExecute.Connection.Close();

                // El usuario ve el mismo mensaje de siempre. El problema se
                // registra para que alguien lo mire, no se le muestra a
                // quien esta intentando entrar.
                RegistrarExcepcion("CuentaController.SolicitarEnlace correo=" + correo, ex.Message);
            }

            return respuesta;
        }

        private void EnviarCorreoRecuperacion(string correo, string token)
        {
            try
            {
                string urlSitio = ConfigurationManager.AppSettings["UrlSitio"];
                string remitente = ConfigurationManager.AppSettings["CorreoRemitente"];
                string remitenteNombre = ConfigurationManager.AppSettings["CorreoRemitenteNombre"];

                if (string.IsNullOrEmpty(urlSitio)) urlSitio = "";
                if (string.IsNullOrEmpty(remitente)) remitente = "no-responder@sigma.cl";
                if (string.IsNullOrEmpty(remitenteNombre)) remitenteNombre = "SIGMA";

                string enlace = urlSitio.TrimEnd('/') + "/RestablecerClave.aspx?t=" + HttpUtility.UrlEncode(token);

                string cuerpo =
                    "<div style=\"font-family:'Segoe UI',Arial,sans-serif;color:#0B0F1A;\">" +
                    "<p>Recibimos una solicitud para restablecer su contraseña de SIGMA.</p>" +
                    "<p><a href=\"" + enlace + "\" " +
                    "style=\"display:inline-block;background:#6C5CFF;color:#ffffff;text-decoration:none;" +
                    "padding:12px 22px;border-radius:8px;font-weight:600;\">Restablecer mi contraseña</a></p>" +
                    "<p style=\"color:#475569;font-size:13px;\">El enlace vence en 60 minutos y sirve una sola vez.<br/>" +
                    "Si usted no pidió este cambio, ignore este correo: su contraseña no cambia.</p>" +
                    "</div>";

                using (MailMessage mensaje = new MailMessage())
                {
                    mensaje.From = new MailAddress(remitente, remitenteNombre);
                    mensaje.To.Add(correo);
                    mensaje.Subject = "SIGMA - Restablecer su contraseña";
                    mensaje.Body = cuerpo;
                    mensaje.IsBodyHtml = true;

                    using (SmtpClient smtp = new SmtpClient())
                    {
                        smtp.Send(mensaje);
                    }
                }
            }
            catch (Exception ex)
            {
                RegistrarExcepcion("CuentaController.EnviarCorreoRecuperacion correo=" + correo, ex.Message);
            }
        }

        /// <summary>
        /// Estado del enlace: VIGENTE / USADO / VENCIDO / INVALIDO.
        ///
        /// Se pregunta ANTES de mostrar el formulario de contrasena nueva,
        /// para no hacerle escribir una clave a alguien cuyo enlace ya no
        /// sirve. Vencido e invalido se distinguen porque el escenario 3
        /// pide ofrecer solicitar uno nuevo solo en el primer caso.
        /// </summary>
        public string EstadoEnlace(string token)
        {
            string estado = "INVALIDO";

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_USUARIO_RECUPERACION";
                cmd.Parameters.AddWithValue("@TOKEN", token);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                        estado = dr["ESTADO"].ToString();
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception ex)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
                estado = "INVALIDO";
            }

            return estado;
        }

        /// <summary>
        /// Consume el enlace y fija la contrasena nueva (HU-004 escenario 2).
        /// </summary>
        public Respuesta RestablecerConEnlace(string token, string claveNueva)
        {
            Respuesta respuesta = new Respuesta();
            SqlCommand cmdExecute = null;

            try
            {
                cmdExecute = Conexion.GetCommand("UPD_USUARIO_RECUPERACION_USAR");
                cmdExecute.Parameters.AddWithValue("@TOKEN", token);
                cmdExecute.Parameters.AddWithValue("@PASSWORD_NUEVO", claveNueva);
                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                respuesta.error = false;
                respuesta.codigo = 0;
                respuesta.detalle = "Su contraseña fue actualizada. Ya puede ingresar.";
            }
            catch (Exception ex)
            {
                if (cmdExecute != null && cmdExecute.Connection != null)
                    cmdExecute.Connection.Close();

                respuesta.error = true;
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
            }

            return respuesta;
        }

        /* ================================================================
           HU-005 - MI CUENTA
           ================================================================ */

        /// <summary>
        /// Cambio de contrasena estando dentro. Exige la actual.
        /// </summary>
        public Respuesta CambiarMiClave(string claveActual, string claveNueva)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_USUARIO_PASSWORD");
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.Parameters.AddWithValue("@PASSWORD_ACTUAL", claveActual);
                    cmdExecute.Parameters.AddWithValue("@PASSWORD_NUEVO", claveNueva);
                    cmdExecute.Parameters.AddWithValue("@EXIGE_ACTUAL", true);
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.error = false;
                    respuesta.detalle = "Contraseña actualizada con éxito.";
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.error = true;
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// Telefono, idioma y fotografia de la propia persona.
        ///
        /// Acotado a proposito: el nombre, el RUT y el correo los mantiene
        /// el administrador (HU-014). El correo es la llave de la cuenta y
        /// de la recuperacion, asi que no se cambia desde aqui.
        /// </summary>
        public Respuesta ActualizarMiPerfil(string telefono, int? idioma, byte[] foto)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_USUARIO_MI_PERFIL");
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.Parameters.AddWithValue("@TELEFONO", (object)telefono ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@IDIOMA", (object)idioma ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@FOTO", (object)foto ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CAMBIA_FOTO", foto != null);
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    // El encabezado muestra estos datos desde la sesion: si
                    // no se refrescan aqui, el cambio no se ve hasta volver
                    // a entrar. El escenario 2 pide que se refleje de
                    // inmediato.
                    HttpContext.Current.Session["usu_fono"] = telefono;
                    if (foto != null)
                        HttpContext.Current.Session["usu_foto"] = Convert.ToBase64String(foto, 0, foto.Length);

                    respuesta.error = false;
                    respuesta.detalle = "Perfil actualizado con éxito.";
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.error = true;
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                }
            }

            return respuesta;
        }

        /* ================================================================
           APOYO
           ================================================================ */

        /// <summary>
        /// Deja constancia de un problema sin interrumpir al usuario.
        /// Se escribe directo en Sis_Excepcion y no con INS_EXCEPCION,
        /// porque ese SP termina en RAISERROR y aqui el punto es
        /// justamente NO propagar el error.
        /// </summary>
        private void RegistrarExcepcion(string variables, string mensaje)
        {
            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("INS_EXCEPCION");
                cmd.Parameters.AddWithValue("@CODIGO", 0).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@VARIABLES", variables);
                cmd.Parameters.AddWithValue("@MSG", mensaje);
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();
            }
            catch
            {
                // INS_EXCEPCION siempre termina en RAISERROR: esa excepcion
                // es esperada y se descarta. Si ademas falla la escritura,
                // no hay nada mas que hacer desde aqui.
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }
        }
    }
}
