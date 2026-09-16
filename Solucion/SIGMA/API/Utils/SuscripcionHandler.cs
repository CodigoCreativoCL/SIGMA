using API.Utils;
using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Security.Claims;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web;

namespace Controllers
{
    /// <summary>
    /// La compuerta comercial de la API (HU-151, T-3007): si la suscripción
    /// de la empresa no permite operar, toda petición con cliente en el
    /// token responde 402 en vez de llegar al controller.
    ///
    /// POR QUE UN HANDLER Y NO UNA LINEA EN CADA ENDPOINT
    ///   Son sesenta endpoints. Uno que se olvide es una empresa vencida
    ///   que sigue escribiendo por la app mientras la web ya la tiene
    ///   afuera. Va en el pipeline, después de validar el token y antes de
    ///   enrutar, para que no dependa de que cada controller se acuerde.
    ///
    /// LA MISMA FUENTE DE VERDAD QUE LA WEB Y EL LOGIN
    ///   SEL_SUSCRIPCION_ESTADO_CLIENTE → FNC_SUSCRIPCION_VIGENTE. No se
    ///   reimplementa la regla de vigencia y gracia acá: si la web, el
    ///   login y la API opinaran distinto del mismo cliente, el técnico
    ///   vería "vencida" en el teléfono y "vigente" en la oficina.
    ///
    /// SE CACHEA UN MINUTO POR CLIENTE
    ///   Una petición a la base por cada llamada de la app sería pagar la
    ///   regla más cara del sistema en cada scroll. Un minuto es lo que
    ///   tarda en verse un pago recién declarado, y es aceptable: el que
    ///   pagó espera segundos, no horas.
    ///
    /// LO QUE PASA IGUAL
    ///   · Sin token, o con token sin cliente: no hay suscripción que
    ///     mirar. El login (POST /sesion) ya rechaza con 402 por su cuenta,
    ///     y elegir cliente (cliente-usuarios) tiene que poder responder
    ///     para que la app muestre la lista.
    ///   · Las cuentas de plataforma no llevan cliente en el token.
    ///
    /// EL RECHAZO QUEDA REGISTRADO
    ///   INS_SUSCRIPCION_BLOQUEO_LOG con origen API, igual que la web: es
    ///   lo que permite responder "¿desde cuándo no puede entrar?" cuando
    ///   el cliente llama. Se registra una vez por minuto y por cliente,
    ///   no una por petición: la app reintenta y llenaría la tabla.
    /// </summary>
    internal class SuscripcionHandler : DelegatingHandler
    {
        /// <summary>Rutas que responden aunque la suscripción esté vencida.</summary>
        private static readonly string[] EXENTAS = { "~/sesion", "~/cliente-usuarios", "~/swagger", "~/mi-perfil" };

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            int cliente = SesionApi.ClienteId();
            int usuario = SesionApi.UsuarioId();

            if (cliente <= 0 || Exenta())
                return base.SendAsync(request, cancellationToken);

            EstadoSuscripcionDto estado;

            try
            {
                estado = Estado(cliente);
            }
            catch (Exception ex)
            {
                /* Si la base no responde, la petición sigue: el controller va
                   a fallar por lo mismo y con su propio mensaje. Un 402 por
                   una caída de red le diría al cliente que no pagó. */
                System.Diagnostics.Trace.TraceError("SIGMA API: suscripción no consultable :: " + ex);
                return base.SendAsync(request, cancellationToken);
            }

            if (estado == null || estado.PUEDE_OPERAR)
                return base.SendAsync(request, cancellationToken);

            Registrar(cliente, usuario, estado.ESTADO, request);

            return Rechazo(Mensaje(estado));
        }

        private static bool Exenta()
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx == null) return false;

            string ruta = (ctx.Request.AppRelativeCurrentExecutionFilePath ?? "").ToLowerInvariant();

            foreach (string e in EXENTAS)
                if (ruta == e || ruta.StartsWith(e + "/")) return true;

            return false;
        }

        private static EstadoSuscripcionDto Estado(int cliente)
        {
            // La clave lleva el cliente; el usuario no importa para este dato.
            string clave = CacheCorta.Clave("suscripcion", 0, cliente);

            List<EstadoSuscripcionDto> filas = CacheCorta.Obtener(clave, () =>
                Datos.Listar<EstadoSuscripcionDto>("SEL_SUSCRIPCION_ESTADO_CLIENTE",
                    new Dictionary<string, object> { { "@CLIENTE", cliente } }));

            return (filas != null && filas.Count > 0) ? filas[0] : null;
        }

        /// <summary>
        /// El mensaje que ve el técnico. Distingue "vencida", "suspendida" y
        /// "cancelada" porque son tres conversaciones distintas con la
        /// empresa; y siempre dice dónde se arregla, que no es en el
        /// teléfono.
        /// </summary>
        private static string Mensaje(EstadoSuscripcionDto e)
        {
            string estado = (e.ESTADO ?? "").Trim().ToUpperInvariant();
            string base_;

            if (estado == "SUSPENDIDA")
                base_ = "La suscripción de tu empresa está suspendida.";
            else if (estado == "CANCELADA")
                base_ = "La suscripción de tu empresa fue cancelada.";
            else
                base_ = "La suscripción de tu empresa venció" +
                        (e.FECHA_FIN == null ? "." : " el " + e.FECHA_FIN.Value.ToString("dd-MM-yyyy") + ".");

            return base_ + " Lo que capturaste queda guardado en el teléfono y se enviará cuando se " +
                   "regularice. El pago se gestiona desde la web de SIGMA por el administrador de tu empresa.";
        }

        private static void Registrar(int cliente, int usuario, string estado, HttpRequestMessage request)
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx == null || ctx.Cache == null) return;

            // Una marca por minuto y por cliente: la app reintenta.
            string marca = "_sigma_api_bloqueo_" + cliente;
            if (ctx.Cache[marca] != null) return;
            ctx.Cache.Insert(marca, "1", null, DateTime.UtcNow.AddSeconds(CacheCorta.SEGUNDOS),
                             System.Web.Caching.Cache.NoSlidingExpiration);

            try
            {
                Datos.Ejecutar("INS_SUSCRIPCION_BLOQUEO_LOG", new Dictionary<string, object>
                {
                    { "@CLIENTE", cliente },
                    { "@ESTADO", (estado ?? "VENCIDA").Length > 20 ? estado.Substring(0, 20) : (estado ?? "VENCIDA") },
                    { "@ORIGEN", "API" },
                    { "@ENDPOINT", request.Method.Method + " " + (ctx.Request.AppRelativeCurrentExecutionFilePath ?? "") },
                    { "@IP", ctx.Request.UserHostAddress },
                    { "@USUARIO", usuario > 0 ? (object)usuario : null }
                });
            }
            catch (Exception ex)
            {
                // El registro es para diagnóstico: que falle no cambia la respuesta.
                System.Diagnostics.Trace.TraceError("SIGMA API: no se pudo registrar el bloqueo :: " + ex);
            }
        }

        /// <summary>
        /// El mismo cuerpo que ApiBase.Error —{ codigo, mensaje, esDeNegocio }—
        /// para que la app lea todos los errores de un solo modo.
        /// </summary>
        private static Task<HttpResponseMessage> Rechazo(string mensaje)
        {
            var respuesta = new HttpResponseMessage(HttpStatusCode.PaymentRequired)
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

    /// <summary>Lo que devuelve SEL_SUSCRIPCION_ESTADO_CLIENTE.</summary>
    public class EstadoSuscripcionDto
    {
        public int CLIENTE { get; set; }
        public int SUSCRIPCION { get; set; }
        public int? PLAN_COMERCIAL { get; set; }
        public string ESTADO { get; set; }
        public DateTime? FECHA_FIN { get; set; }
        public int? DIAS_RESTANTES { get; set; }
        public bool PUEDE_OPERAR { get; set; }
        public bool AVISAR { get; set; }
    }
}
