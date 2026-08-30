using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Recuperación de contraseña (HU-004).
    ///
    /// LA RESPUESTA ES LA MISMA EXISTA O NO EL CORREO
    ///   Siempre 200 con el mismo mensaje. Es el escenario 1 de la historia
    ///   y no es una formalidad: si la respuesta cambiara según el correo
    ///   exista, este endpoint sería una forma de averiguar qué correos
    ///   están registrados en SIGMA probándolos de a uno, sin credenciales
    ///   y sin límite.
    ///
    ///   El SP está escrito para eso: devuelve 0 siempre y nunca hace
    ///   RAISERROR cuando el correo no existe.
    ///
    /// ES ANONIMO A PROPOSITO
    ///   Quien no puede entrar es justamente quien no tiene token. Pedirlo
    ///   haría el endpoint inútil.
    ///
    /// PENDIENTE CONOCIDO: EL CORREO NO SALE
    ///   El SMTP todavía no está configurado. El token se genera y se
    ///   guarda —así que el flujo es completo del lado de los datos— pero
    ///   el enlace no llega a nadie hasta que se configure. Está anotado
    ///   como bloqueante en el MD de estado.
    /// </summary>
    [AllowAnonymous]
    [RoutePrefix("usuario-recuperaciones")]
    public class UsuarioRecuperacionesController : ApiBase
    {
        /// <summary>
        /// POST /usuario-recuperaciones — pedir el enlace.          HU-004
        /// </summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Solicitar(RecuperacionDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirCuerpo(dto);
                ExigirTexto(dto.correo, "correo");

                /* El token lo genera la aplicación y de él la base guarda
                   solo el hash, igual que con las contraseñas: quien mire
                   la tabla no puede usar los enlaces pendientes de otros. */
                string token = GenerarToken();

                Datos.Ejecutar("INS_USUARIO_RECUPERACION",
                    new Dictionary<string, object>
                    {
                        { "@CORREO", dto.correo.Trim() },
                        { "@TOKEN", token },
                        { "@IP", Ip() }
                    }, true);

                /* El token NO se devuelve. Viaja por correo y solo por
                   correo: devolverlo acá convertiría "pedir recuperación"
                   en "obtener acceso", que es exactamente lo contrario de
                   lo que hace el flujo. */
                return Ok(new
                {
                    mensaje = "Si el correo está registrado, le llegará un enlace para " +
                              "restablecer su contraseña. El enlace vence en 60 minutos."
                });
            });
        }

        /// <summary>
        /// POST /usuario-recuperaciones/restablecer — usar el enlace.
        ///                                                          HU-004
        ///
        /// El token es de UN SOLO USO y vence en 60 minutos. Las dos cosas
        /// las comprueba el SP dentro de la misma transacción en que cambia
        /// la contraseña, así que no hay ventana para usarlo dos veces.
        /// </summary>
        [HttpPost]
        [Route("restablecer")]
        public IHttpActionResult Restablecer(RestablecerDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirCuerpo(dto);
                ExigirTexto(dto.token, "token");
                ExigirTexto(dto.password_nuevo, "password_nuevo");

                Datos.Ejecutar("UPD_USUARIO_RECUPERACION_USAR",
                    new Dictionary<string, object>
                    {
                        { "@TOKEN", dto.token.Trim() },
                        { "@PASSWORD_NUEVO", dto.password_nuevo }
                    });

                return Ok(new { mensaje = "Contraseña restablecida. Ya puede iniciar sesión." });
            });
        }

        /// <summary>
        /// Token de un solo uso, de 32 bytes en hexadecimal.
        ///
        /// RNGCryptoServiceProvider y no Random: Random se siembra con el
        /// reloj, así que dos solicitudes en el mismo instante producirían
        /// el mismo token y cualquiera podría adivinarlo sabiendo la hora.
        /// </summary>
        private static string GenerarToken()
        {
            byte[] bytes = new byte[32];

            using (RNGCryptoServiceProvider rng = new RNGCryptoServiceProvider())
            {
                rng.GetBytes(bytes);
            }

            StringBuilder sb = new StringBuilder(bytes.Length * 2);
            for (int i = 0; i < bytes.Length; i++) sb.Append(bytes[i].ToString("x2"));

            return sb.ToString();
        }

        /// <summary>
        /// La IP desde donde se pidió, para poder revisar después si alguien
        /// estuvo probando correos de a uno.
        /// </summary>
        private static string Ip()
        {
            try
            {
                System.Web.HttpContext ctx = System.Web.HttpContext.Current;
                if (ctx == null || ctx.Request == null) return null;

                // Detrás de un proxy, UserHostAddress es el proxy.
                string reenviada = ctx.Request.ServerVariables["HTTP_X_FORWARDED_FOR"];

                return !string.IsNullOrEmpty(reenviada)
                    ? reenviada.Split(',')[0].Trim()
                    : ctx.Request.UserHostAddress;
            }
            catch (Exception ex)
            {
                return null;
            }
        }
    }
}
