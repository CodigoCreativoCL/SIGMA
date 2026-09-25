using API.Utils;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Controllers
{
    /// <summary>
    /// Corta la peticion con 402 si la suscripcion del cliente no permite
    /// operar (HU-160, T-4158).
    ///
    /// DE DONDE SALE LA KEY
    ///   Del encabezado `X-Cliente-Key`: es la llave del inquilino, distinta
    ///   del JWT de la persona. Se valida contra FNC_SUSCRIPCION_VIGENTE (via
    ///   API_SEL_SUSCRIPCION_VIGENTE), que CALCULA el estado -vigente, en
    ///   gracia, vencida- sin depender de un job.
    ///
    /// SIN EL ENCABEZADO, PASA
    ///   Hay clientes que aun no mandan la llave y endpoints anonimos (login).
    ///   Un handler que cortara todo lo que no la trae dejaria la API fuera de
    ///   alcance. La llave se valida cuando viene; su ausencia la resuelve
    ///   cada endpoint con ExigirUsuario / ExigirCliente.
    ///
    /// 402 Y NO 403
    ///   403 es "no tienes permiso"; 402 (Payment Required) es "la cuenta no
    ///   esta al dia". La app reacciona distinto: ante un 402 lleva a regularizar
    ///   el pago, no a pedir otra credencial.
    ///
    /// SI LA COMPROBACION FALLA POR INFRAESTRUCTURA, NO BLOQUEA
    ///   Un error de base al consultar la suscripcion no puede volverse un 402
    ///   que deje a todo un cliente sin trabajar: se deja pasar y el endpoint
    ///   sigue exigiendo token y cliente. El corte por 402 es para el caso
    ///   claro -la funcion dijo que no puede operar-, no para una duda.
    /// </summary>
    internal class SuscripcionVigenteHandler : DelegatingHandler
    {
        private const string ENCABEZADO = "X-Cliente-Key";

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            string key = LeerKey(request);

            // Sin llave: que lo resuelva el endpoint (token + cliente).
            if (string.IsNullOrEmpty(key))
                return base.SendAsync(request, cancellationToken);

            try
            {
                byte[] hash;
                using (SHA256 sha = SHA256.Create())
                    hash = sha.ComputeHash(Encoding.UTF8.GetBytes(key));

                DataSet ds = Datos.Conjunto("API_SEL_SUSCRIPCION_VIGENTE",
                    new Dictionary<string, object> { { "@KEY_HASH", hash } });

                object puede = Datos.Escalar(ds, 0, "PUEDE_OPERAR");
                object estado = Datos.Escalar(ds, 0, "ESTADO");

                // Sin fila: la llave no corresponde a ninguna suscripcion.
                if (puede == null)
                    return Rechazo("La llave del cliente no corresponde a una suscripción activa.");

                if (!Convert.ToBoolean(puede))
                    return Rechazo("La suscripción del cliente no permite operar (" +
                                   (estado != null ? estado.ToString().ToLower() : "sin vigencia") +
                                   "). Regularice el pago para continuar.");
            }
            catch (Exception)
            {
                // Falla de infraestructura: no se convierte en 402. El endpoint
                // sigue exigiendo token y cliente.
            }

            return base.SendAsync(request, cancellationToken);
        }

        private static string LeerKey(HttpRequestMessage request)
        {
            IEnumerable<string> valores;
            if (!request.Headers.TryGetValues(ENCABEZADO, out valores)) return null;

            string v = valores.FirstOrDefault();
            return string.IsNullOrEmpty(v) ? null : v.Trim();
        }

        /// <summary>
        /// 402 con el mismo cuerpo { codigo, mensaje, esDeNegocio } que usa
        /// ApiBase.Error, para que la app lea los errores de un solo modo.
        /// </summary>
        private static Task<HttpResponseMessage> Rechazo(string mensaje)
        {
            var respuesta = new HttpResponseMessage((HttpStatusCode)402)
            {
                Content = new StringContent(
                    "{\"codigo\":402,\"mensaje\":\"" +
                    mensaje.Replace("\\", "\\\\").Replace("\"", "\\\"") +
                    "\",\"esDeNegocio\":true}",
                    Encoding.UTF8, "application/json")
            };

            return Task.FromResult(respuesta);
        }
    }
}
