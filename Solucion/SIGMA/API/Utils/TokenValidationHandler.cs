using Microsoft.IdentityModel.Tokens;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web;

namespace Controllers
{
    /// <summary>
    /// Valida el JWT de cada petición y deja la identidad en
    /// <see cref="Thread.CurrentPrincipal"/>, que es de donde la lee
    /// <c>SesionApi</c>.
    ///
    /// SIN encabezado Authorization la petición pasa igual: hay endpoints
    /// anónimos (POST /sesion, la recuperación de contraseña) y es el
    /// controller —con ExigirUsuario / ExigirPermiso— el que decide. Un
    /// handler que rechazara todo lo que no trae token dejaría el login
    /// fuera de alcance.
    /// </summary>
    internal class TokenValidationHandler : DelegatingHandler
    {
        /* Los tres esquemas que se aceptan.

           "Bearer" es el estándar (RFC 6750) y es el que usan la app movil,
           curl, Postman y cualquier cliente HTTP normal.

           "Base" es herencia de la API de FacilityGes, donde el cliente MAUI
           lo mandaba así. Se conserva para no romper a nadie que ya estuviera
           llamando con ese prefijo.

           Y se acepta el token pelado, sin esquema, por la misma razón. */
        private static readonly string[] ESQUEMAS = { "Bearer ", "Base " };

        /// <summary>
        /// Saca el token del encabezado Authorization, sin importar con cuál
        /// de los esquemas venga.
        ///
        /// ESTE ERA EL DEFECTO (corregido el 04-09-2026): solo se recortaba
        /// el prefijo "Base ". Con "Bearer eyJ..." el token se pasaba a
        /// validar CON el prefijo pegado, ValidateToken lanzaba una excepción
        /// que no es SecurityTokenValidationException, caía en el catch
        /// general y **todo endpoint autenticado respondía 500 con cuerpo
        /// vacío**. Ninguno había funcionado nunca desde un cliente estándar.
        /// </summary>
        private static bool TryRetrieveToken(HttpRequestMessage request, out string token)
        {
            token = null;
            IEnumerable<string> authzHeaders;

            if (!request.Headers.TryGetValues("Authorization", out authzHeaders) || authzHeaders.Count() > 1)
            {
                return false;
            }

            string encabezado = (authzHeaders.ElementAt(0) ?? string.Empty).Trim();
            if (encabezado.Length == 0) return false;

            foreach (string esquema in ESQUEMAS)
            {
                if (encabezado.StartsWith(esquema, StringComparison.OrdinalIgnoreCase))
                {
                    token = encabezado.Substring(esquema.Length).Trim();
                    return token.Length > 0;
                }
            }

            // Sin esquema: el encabezado es el token.
            token = encabezado;
            return true;
        }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            string token;

            if (!TryRetrieveToken(request, out token))
            {
                // Que lo resuelva el controller: puede ser un endpoint anónimo.
                return base.SendAsync(request, cancellationToken);
            }

            try
            {
                var secretKey = ConfigurationManager.AppSettings["JWT_SECRET_KEY"];
                var audienceToken = ConfigurationManager.AppSettings["JWT_AUDIENCE_TOKEN"];
                var issuerToken = ConfigurationManager.AppSettings["JWT_ISSUER_TOKEN"];

                /* Encoding.Default, igual que TokenGenerator. Los dos lados
                   tienen que derivar la misma clave del mismo texto: cambiar
                   uno solo invalida todos los tokens ya emitidos. */
                var securityKey = new SymmetricSecurityKey(Encoding.Default.GetBytes(secretKey));

                SecurityToken securityToken;
                var tokenHandler = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler();
                TokenValidationParameters validationParameters = new TokenValidationParameters()
                {
                    ValidAudience = audienceToken,
                    ValidIssuer = issuerToken,
                    ValidateLifetime = true,
                    ValidateIssuerSigningKey = true,
                    LifetimeValidator = this.LifetimeValidator,
                    IssuerSigningKey = securityKey
                };

                // Se valida UNA vez y se reutiliza el resultado: validar dos
                // veces el mismo token es el doble de trabajo criptográfico
                // en cada petición.
                var principal = tokenHandler.ValidateToken(token, validationParameters, out securityToken);

                Thread.CurrentPrincipal = principal;
                if (HttpContext.Current != null) HttpContext.Current.User = principal;

                return base.SendAsync(request, cancellationToken);
            }
            catch (SecurityTokenExpiredException)
            {
                return Rechazo(HttpStatusCode.Unauthorized, "La sesión expiró. Vuelve a iniciar sesión.");
            }
            catch (SecurityTokenValidationException)
            {
                return Rechazo(HttpStatusCode.Unauthorized, "El token no es válido.");
            }
            catch (ArgumentException)
            {
                /* Token mal formado —lo que pasaba con "Bearer" pegado—.
                   Es 401, no 500: el problema es la credencial que trae el
                   cliente, no una falla del servidor. Un 500 acá hace que la
                   app reintente en vez de renovar la sesión. */
                return Rechazo(HttpStatusCode.Unauthorized, "El token no es válido.");
            }
            catch (Exception)
            {
                return Rechazo(HttpStatusCode.InternalServerError,
                    "No fue posible validar la sesión.");
            }
        }

        /// <summary>
        /// Responde con el mismo cuerpo que usa ApiBase.Error
        /// —{ codigo, mensaje, esDeNegocio }— para que el cliente lea los
        /// errores de un solo modo. El handler original devolvía el código
        /// sin cuerpo, y un 401 mudo no le dice a la app si renovar la sesión
        /// o rendirse.
        /// </summary>
        private static Task<HttpResponseMessage> Rechazo(HttpStatusCode codigo, string mensaje)
        {
            var respuesta = new HttpResponseMessage(codigo)
            {
                Content = new StringContent(
                    "{\"codigo\":" + (int)codigo +
                    ",\"mensaje\":\"" + mensaje.Replace("\\", "\\\\").Replace("\"", "\\\"") +
                    "\",\"esDeNegocio\":true}",
                    Encoding.UTF8, "application/json")
            };

            return Task.FromResult(respuesta);
        }

        public bool LifetimeValidator(DateTime? notBefore, DateTime? expires, SecurityToken securityToken, TokenValidationParameters validationParameters)
        {
            if (expires != null)
            {
                if (DateTime.UtcNow < expires) return true;
            }
            return false;
        }
    }
}
