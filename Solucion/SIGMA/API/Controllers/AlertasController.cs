using API.MVC.Model;
using API.Utils;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Alertas que el sistema detecta solo (HU-077, bloques 81-85).
    ///
    /// LA APP RECIBE LO MISMO QUE LA WEB
    ///   Son los mismos SEL_ALERTA y SEL_ALERTA_RESUMEN que usa la intranet.
    ///   Un SP "para movil" seria el lugar donde algun dia una alerta
    ///   aparece en un lado y en el otro no, y nadie se entera hasta que
    ///   alguien reclama que la web le avisó y el telefono no.
    ///
    /// EL RESUMEN VA APARTE Y NO ES UN CAPRICHO
    ///   La campanita se refresca seguido. Traer la lista completa para
    ///   contar cuantas hay seria bajar decenas de filas por cada refresco,
    ///   con los datos del telefono del tecnico. El resumen son dos enteros.
    ///
    /// NO HAY ENDPOINT PARA CREAR UNA ALERTA
    ///   Las alertas las detecta el servidor —GEN_ALERTA_DETECTAR y
    ///   GEN_ALERTA_INVENTARIO—, no las declara un cliente. Dejar abierto un
    ///   POST permitiria que un dispositivo inventara alertas que nadie
    ///   detecto.
    /// </summary>
    [RoutePrefix("alertas")]
    public class AlertasController : ApiBase
    {
        /// <summary>
        /// GET /alertas — las alertas del usuario en su cliente.     HU-077
        ///
        /// El SP ya filtra por lo que la persona puede ver: no hace falta
        /// —ni conviene— repetir esa regla aca.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        bool soloAbiertas = true, int tope = 200)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                /* El tope se acota acá: un cliente que pida tope=999999
                   obligaria al SP a materializar todo el historial de
                   alertas para devolver una pagina de veinte. */
                if (tope < 1) tope = 1;
                if (tope > 500) tope = 500;

                Pagina p = new Pagina { pagina = pagina, tamano = tamano };

                List<AlertaDto> todo = Datos.Listar<AlertaDto>("SEL_ALERTA",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@SOLO_ABIERTAS", soloAbiertas },
                        { "@TOPE", tope }
                    });

                return Ok(Paginado<AlertaDto>.Armar(todo, p));
            });
        }

        /// <summary>
        /// GET /alertas/resumen — cuantas hay y cuantas sin leer.    HU-077
        /// </summary>
        [HttpGet]
        [Route("resumen")]
        public IHttpActionResult Resumen()
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                List<AlertaResumenDto> r = Datos.Listar<AlertaResumenDto>("SEL_ALERTA_RESUMEN",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                /* Sin filas significa "ninguna alerta", no un error: la
                   campanita tiene que poder mostrar cero. */
                if (r == null || r.Count == 0)
                    return Ok(new AlertaResumenDto { ABIERTAS = 0, NO_LEIDAS = 0 });

                return Ok(r[0]);
            });
        }

        /// <summary>
        /// POST /alertas/{id}/leer — marcarla como vista.            HU-077
        ///
        /// Leer no es resolver: la alerta sigue abierta hasta que el
        /// problema que la origino deje de existir. Esto solo apaga el
        /// contador de "sin leer" para esta persona.
        /// </summary>
        [HttpPost]
        [Route("{id:int}/leer")]
        public IHttpActionResult Leer(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                Datos.Ejecutar("UPD_ALERTA_LEER",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@ALERTA", id }
                    });

                return Ok(new { leida = true, alerta = id });
            });
        }
    }
}
