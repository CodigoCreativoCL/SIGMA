using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Bodegas y sus ubicaciones, EN LECTURA (HU-052).
    ///
    /// Crearlas y editarlas es trabajo de escritorio y vive solo en la web.
    /// La app las lee porque sin bodega no hay donde ingresar, de donde
    /// entregar ni que ajustar, y sin ubicacion el criterio 2 de HU-052 no
    /// se cumple: "al consultar un repuesto se indica su ubicacion exacta".
    /// </summary>
    [RoutePrefix("bodegas")]
    public class BodegasController : ApiBase
    {
        /// <summary>GET /bodegas — las bodegas del cliente.        HU-052</summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, int? instalacion = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER BODEGAS");
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<BodegaDto> todo = Datos.Listar<BodegaDto>("SEL_BODEGA",
                    new Dictionary<string, object>
                    {
                        { "@ID", null },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@INSTALACION", instalacion },
                        { "@FILTRO", p.filtro },
                        { "@HABILITADO", true }
                    });

                return Ok(Paginado<BodegaDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /bodegas/{id} — la ficha.                  HU-052</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER BODEGAS");
                ExigirCliente();

                List<BodegaDto> r = Datos.Listar<BodegaDto>("SEL_BODEGA",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@INSTALACION", null },
                        { "@FILTRO", null },
                        { "@HABILITADO", null }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("La bodega");

                return Ok(r[0]);
            });
        }

        /// <summary>
        /// GET /bodegas/{id}/ubicaciones — los estantes.    HU-052 CA2
        ///
        /// Sin paginar: una bodega tiene decenas de ubicaciones, no miles,
        /// y la app las necesita todas juntas para llenar un selector.
        /// </summary>
        [HttpGet]
        [Route("{id:int}/ubicaciones")]
        public IHttpActionResult Ubicaciones(int id)
        {
            return Ejecutar(() =>
            {
                /* HU-116: el técnico que consume un repuesto contra su orden
                   tiene que decir DE QUÉ ESTANTE sale (el SP lo exige cuando
                   la bodega tiene ubicaciones), y el técnico no tiene VER
                   BODEGAS. Probado el 14-09-2026: 403 acá dejaba el consumo
                   sin camino desde el teléfono. Leer los estantes de una
                   bodega no revela nada que el consumo no exponga ya. */
                ExigirAlgunPermiso("VER BODEGAS", "EJECUTAR ORDEN TRABAJO");
                ExigirCliente();

                List<BodegaUbicacionDto> r = Datos.Listar<BodegaUbicacionDto>("SEL_BODEGA_UBICACION",
                    new Dictionary<string, object>
                    {
                        { "@ID", null },
                        { "@BODEGA", id },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@FILTRO", null },
                        { "@HABILITADO", true }
                    });

                return Ok(r ?? new List<BodegaUbicacionDto>());
            });
        }
    }
}
