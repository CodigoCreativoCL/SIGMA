using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Net.Http;
using System.Security.Claims;
using System.Text;

namespace API.Utils
{
    /// <summary>
    /// La clave con la que la WEB se identifica ante la API (`X-Api-Key`),
    /// y la sesión que la web delega con ella.
    ///
    /// QUE ES LA SESION DELEGADA
    ///   La web ya autenticó a la persona y ya eligió cliente; cuando llama
    ///   a la API en nombre de esa persona manda la clave de servicio más
    ///   dos encabezados —`X-Sigma-Usuario` y `X-Sigma-Cliente`— y el
    ///   handler de tokens arma con ellos la misma identidad que armaría un
    ///   JWT. Del controller hacia abajo no hay diferencia: SesionApi,
    ///   Permisos y ExigirPermiso funcionan igual, y la auditoría de cada
    ///   tabla queda a nombre de la persona, no de "la web".
    ///
    /// POR QUE NO ES UN AGUJERO
    ///   Los encabezados de usuario y cliente solo se leen si la clave de
    ///   servicio es correcta, y la clave solo la tiene el Web.config del
    ///   servidor web. Un navegador no la conoce. Es la misma confianza que
    ///   `/archivo` deposita en la web desde el 29-08, extendida a la
    ///   identidad de quien opera.
    ///
    ///   Y sin clave configurada NO se abre: se cierra (misma regla que
    ///   ArchivoController.HayClaveDeServicio).
    /// </summary>
    public static class ClaveServicio
    {
        public const string ENCABEZADO = "X-Api-Key";
        public const string ENCABEZADO_USUARIO = "X-Sigma-Usuario";
        public const string ENCABEZADO_CLIENTE = "X-Sigma-Cliente";

        /// <summary>True si la petición trae la clave de servicio correcta.</summary>
        public static bool Valida(HttpRequestMessage request)
        {
            string esperada = ConfigurationManager.AppSettings["ServiciosApiKey"];

            if (string.IsNullOrEmpty(esperada) ||
                esperada.IndexOf("PENDIENTE", StringComparison.OrdinalIgnoreCase) >= 0)
                return false;

            string recibida = Encabezado(request, ENCABEZADO);

            return IgualEnTiempoConstante(esperada, recibida);
        }

        /// <summary>
        /// La identidad delegada por la web, o null si la petición no la
        /// trae (o trae la clave mal).
        /// </summary>
        public static ClaimsPrincipal SesionDelegada(HttpRequestMessage request)
        {
            if (!Valida(request)) return null;

            int usuario, cliente;
            if (!int.TryParse(Encabezado(request, ENCABEZADO_USUARIO), out usuario) || usuario <= 0) return null;
            if (!int.TryParse(Encabezado(request, ENCABEZADO_CLIENTE), out cliente)) cliente = 0;

            ClaimsIdentity identidad = new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.Name, "web:" + usuario),
                new Claim(ClaimTypes.NameIdentifier, usuario.ToString()),
                new Claim("sigma_usuario", usuario.ToString()),
                new Claim("sigma_cliente", cliente.ToString()),
                new Claim("sigma_origen", "web")
            }, "ClaveServicio");

            return new ClaimsPrincipal(identidad);
        }

        private static string Encabezado(HttpRequestMessage request, string nombre)
        {
            IEnumerable<string> valores;
            if (request.Headers.TryGetValues(nombre, out valores))
                return valores.FirstOrDefault();
            return null;
        }

        /// <summary>
        /// Compara sin cortar en la primera diferencia: un == normal filtra
        /// la clave carácter a carácter por el tiempo que tarda.
        /// </summary>
        private static bool IgualEnTiempoConstante(string esperada, string recibida)
        {
            if (recibida == null) return false;

            byte[] a = Encoding.UTF8.GetBytes(esperada);
            byte[] b = Encoding.UTF8.GetBytes(recibida);

            int diferencia = a.Length ^ b.Length;

            for (int i = 0; i < a.Length && i < b.Length; i++)
                diferencia |= a[i] ^ b[i];

            return diferencia == 0;
        }
    }
}
