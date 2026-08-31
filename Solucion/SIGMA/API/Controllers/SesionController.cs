using API.MVC.Model;
using API.Utils;
using Controllers;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Net;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Iniciar y cerrar sesión (HU-001 y HU-003).
    ///
    /// TODA LA REGLA VIVE EN SEL_LOGIN, NO ACA
    ///   Contar intentos fallidos, bloquear quince minutos, migrar la
    ///   contraseña de texto plano a hash, comprobar que la afiliación esté
    ///   habilitada: nada de eso se reimplementa acá. Si estuviera en dos
    ///   lugares, algún día la web y la app dirían cosas distintas sobre la
    ///   misma cuenta, y la que estaría mal sería la que menos se prueba.
    ///
    ///   Este controller traduce: recibe credenciales, llama al SP, y
    ///   convierte su respuesta en un token y un código HTTP.
    ///
    /// EL MENSAJE NO DISTINGUE QUE FALLO
    ///   SEL_LOGIN devuelve el mismo texto para cuenta inexistente y para
    ///   contraseña mala (HU-001 escenario 2). Eso se respeta tal cual: un
    ///   mensaje distinto por caso le permite a cualquiera averiguar qué
    ///   correos están registrados probándolos de a uno.
    /// </summary>
    [AllowAnonymous]
    [RoutePrefix("sesion")]
    public class SesionController : ApiBase
    {
        /// <summary>
        /// POST /sesion — iniciar sesión.                        HU-001
        ///
        /// 200 con token · 401 credenciales malas · 423 cuenta bloqueada.
        /// </summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Iniciar(LoginDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirCuerpo(dto);
                ExigirTexto(dto.login, "login");
                ExigirTexto(dto.password, "password");

                List<LoginResultado> r = Datos.Listar<LoginResultado>("SEL_LOGIN",
                    new Dictionary<string, object>
                    {
                        { "@LOGIN", dto.login.Trim() },
                        { "@PASSWORD", dto.password },

                        /* 2 = APP (bloque 58). Quien entra por acá está
                           entrando a la aplicación móvil, y SEL_LOGIN
                           rechaza al perfil que no opera en ella: el
                           Administrador del Cliente configura desde la web
                           y no tiene nada que hacer en el teléfono.

                           El parámetro tiene DF 1 en el SP para que la web
                           siga llamando con dos argumentos. Acá se pasa
                           explícito porque el valor por defecto es
                           justamente el que no corresponde. */
                        { "@AMBITO", 2 }
                    });

                if (r == null || r.Count == 0)
                    return Error(HttpStatusCode.Unauthorized, "Correo o contraseña incorrectos.");

                LoginResultado res = r[0];

                /* Los códigos los define SEL_LOGIN y se respetan tal cual.
                   Traducirlos a otra cosa acá obligaría a mantener dos
                   tablas de códigos sincronizadas. */
                if (res.CODE == "423")
                    return Error((HttpStatusCode)423, res.MENSAJE);

                if (res.CODE == "401")
                    return Error(HttpStatusCode.Forbidden, res.MENSAJE);

                /* 403: la cuenta existe y la clave estaba bien, pero no
                   puede estar acá —sin perfil asignado, o con un perfil que
                   solo opera en la web—. Se responde 403 y no 401 para que
                   la app no borre la sesión y vuelva a pedir credenciales:
                   reintentar no va a cambiar nada, y el mensaje del SP ya
                   dice por dónde sí puede entrar. */
                if (res.CODE == "403")
                    return Error(HttpStatusCode.Forbidden, res.MENSAJE);

                /* 402: la suscripción de la empresa no está vigente. El
                   pago se regulariza desde la web; en el teléfono no hay
                   nada que hacer más que mostrarlo. */
                if (res.CODE == "402")
                    return Error(HttpStatusCode.PaymentRequired, res.MENSAJE);

                if (res.CODE != "200" || res.ID <= 0)
                    return Error(HttpStatusCode.Unauthorized, res.MENSAJE ?? "Correo o contraseña incorrectos.");

                // ---- Entró. Ahora, con qué cliente. ----
                List<ClienteElegibleDto> clientes = ClientesDe(res.ID);

                SesionDto sesion = new SesionDto();
                sesion.usuario = res.ID;
                sesion.login = dto.login.Trim();
                sesion.expira_minutos = Minutos();

                /* Con un solo cliente se entra directo: obligar a elegir
                   dentro de una lista de un elemento es un paso de más.
                   Con varios, el token sale SIN cliente y la app tiene que
                   mandar a elegir (HU-002).

                   Cero clientes es una cuenta de plataforma —quien da de
                   alta al primer cliente— y también entra. */
                if (clientes.Count == 1)
                {
                    sesion.cliente = clientes[0].cli_id;
                    sesion.cliente_nombre = clientes[0].cli_nombre;
                }
                else if (clientes.Count > 1)
                {
                    sesion.debe_elegir_cliente = true;
                }

                sesion.token = TokenGenerator.GenerarTokenUsuario(
                    sesion.usuario, sesion.login, sesion.cliente);

                return Ok(sesion);
            });
        }

        /// <summary>
        /// DELETE /sesion — cerrar sesión.                       HU-003
        ///
        /// POR QUE NO HAY NADA QUE BORRAR EN EL SERVIDOR
        ///   El JWT no se guarda: se firma y se valida en cada petición. No
        ///   existe una fila que marcar como cerrada, así que cerrar sesión
        ///   es que el cliente deje de mandar el token.
        ///
        ///   El endpoint existe igual, y no es decorativo: le da a la app un
        ///   lugar donde avisar, deja la acción registrada, y el día que
        ///   haya lista de revocación se implementa acá sin que la app
        ///   cambie una línea.
        ///
        ///   La expiración real la da JWT_EXPIRE_MINUTES. Que sea de ocho
        ///   horas y no de treinta minutos como la web es a propósito: un
        ///   técnico en planta no puede quedar fuera a mitad de una orden
        ///   por dejar el teléfono en el bolsillo.
        /// </summary>
        [HttpDelete]
        [Route("")]
        public IHttpActionResult Cerrar()
        {
            return Ejecutar(() =>
            {
                System.Diagnostics.Trace.TraceInformation(
                    "SIGMA API: cierre de sesión del usuario " + SesionApi.UsuarioId());

                return Ok(new
                {
                    mensaje = "Sesión cerrada. Descarte el token en el cliente.",
                    expira_minutos = Minutos()
                });
            });
        }

        /// <summary>
        /// GET /sesion — quién soy, según el token.
        /// Sirve para que la app sepa si el token sigue vivo sin adivinar.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Actual()
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();

                return Ok(new
                {
                    usuario = SesionApi.UsuarioId(),
                    login = SesionApi.Login(),
                    cliente = SesionApi.ClienteId()
                });
            });
        }

        internal static List<ClienteElegibleDto> ClientesDe(int usuario)
        {
            List<ClienteElegibleDto> lista = Datos.Listar<ClienteElegibleDto>("SEL_CLIENTE",
                new Dictionary<string, object>
                {
                    { "@USUARIO", usuario },
                    { "@HABILITADO", true }
                });

            return lista ?? new List<ClienteElegibleDto>();
        }

        private static int Minutos()
        {
            int m;
            return int.TryParse(ConfigurationManager.AppSettings["JWT_EXPIRE_MINUTES"], out m) ? m : 480;
        }
    }
}
