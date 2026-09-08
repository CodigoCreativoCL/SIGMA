using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Plantas del cliente (HU-011).
    ///
    /// NO HAY BORRADO FISICO. Una planta con áreas, activos, órdenes o
    /// usuarios asociados no se borra: se deshabilita. La baja lógica
    /// conserva el histórico, que es lo que pide el negocio y lo que
    /// exige el estándar del grupo para tablas maestro.
    /// </summary>
    [RoutePrefix("cliente-instalaciones")]
    public class ClienteInstalacionesController : ApiBase
    {
        /// <summary>GET /cliente-instalaciones — listado.        HU-011</summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, int? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER PLANTAS");
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                /* SOLO LAS PLANTAS A LAS QUE ESTA PERSONA ESTA ASIGNADA

                   Antes se llamaba a SEL_CLIENTE_INSTALACION, que es el
                   listado de la web y devuelve TODAS las plantas del cliente.
                   En la app eso deja elegir contexto en una planta donde la
                   persona no trabaja, y cuyos activos la sincronizacion nunca
                   le baja — la pantalla queda ofreciendo algo que despues
                   aparece vacio.

                   API_SEL_APP_INSTALACION aplica la MISMA regla que usa la
                   sabana para armar @PLANTAS, asi los dos caminos no se pueden
                   contradecir. Sin asignacion devuelve cero filas, que es lo
                   correcto: pertenecer al cliente no es estar asignado a una
                   planta. */
                List<ClienteInstalacionDto> todo = Datos.Listar<ClienteInstalacionDto>("API_SEL_APP_INSTALACION",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@FILTRO", p.filtro }
                    });

                return Ok(Paginado<ClienteInstalacionDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /cliente-instalaciones/{id} — detalle.   HU-011</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER PLANTAS");
                ExigirCliente();

                /* El detalle usa el MISMO filtro que el listado. Si no, una
                   planta que no aparece en la lista se puede abrir igual
                   escribiendo su id, y la restriccion seria decorativa. */
                List<ClienteInstalacionDto> r = Datos.Listar<ClienteInstalacionDto>("API_SEL_APP_INSTALACION",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@ID", id }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("La planta");

                return Ok(r[0]);
            });
        }

        /// <summary>
        /// Las coordenadas son opcionales, pero si vienen tienen que ser
        /// coordenadas. Un error de tipeo que ponga la planta en mitad del
        /// océano no lo detecta nadie hasta que un mapa se ve raro.
        /// </summary>
        private static void ValidarCoordenadas(ClienteInstalacionAltaDto dto)
        {
            if (dto.latitud.HasValue && (dto.latitud < -90 || dto.latitud > 90))
                throw new ArgumentException("La latitud debe estar entre -90 y 90.");

            if (dto.longitud.HasValue && (dto.longitud < -180 || dto.longitud > 180))
                throw new ArgumentException("La longitud debe estar entre -180 y 180.");
        }
    }
}
