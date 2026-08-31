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

                List<ClienteInstalacionDto> todo = Datos.Listar<ClienteInstalacionDto>("SEL_CLIENTE_INSTALACION",
                    new Dictionary<string, object>
                    {
                        // El SP lo declara varchar: recibe el id como texto.
                        { "@CLIENTE", SesionApi.ClienteId().ToString() },
                        { "@FILTRO", p.filtro },
                        { "@HABILITADO", habilitado }
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

                List<ClienteInstalacionDto> r = Datos.Listar<ClienteInstalacionDto>("SEL_CLIENTE_INSTALACION",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId().ToString() }
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
