using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// El maestro de repuestos, EN LECTURA (HU-050).
    ///
    /// POR QUE NO HAY POST NI PUT
    ///   HU-050 es una historia solo web: mantener el catalogo para que
    ///   todos nombren la misma pieza de la misma forma es trabajo de
    ///   escritorio, y la web llama a los SP directo sin pasar por la API.
    ///
    ///   Lo que si necesita la app es LEERLO: sin el maestro no puede
    ///   ofrecer que ingresar, que entregar ni que ajustar. Es la excepcion
    ///   E2 de MD/SIGMA_ALCANCE_APP.md — la lectura que consume otra
    ///   historia de App.
    ///
    ///   Crear un repuesto desde terreno existe, pero es otra cosa:
    ///   CREAR REPUESTO TERRENO, del Anexo D, que se otorga por persona y
    ///   pasa por el flujo de descubrimiento (HU-155, Sprint 5).
    /// </summary>
    [RoutePrefix("repuestos")]
    public class RepuestosController : ApiBase
    {
        /// <summary>
        /// GET /repuestos — el maestro, buscable.                  HU-050
        ///
        /// El filtro busca en codigo, nombre, fabricante y modelo. Eso es
        /// el criterio 2 de la historia: el tecnico escribe lo que tiene a
        /// mano —muchas veces el numero grabado en la pieza, que es el del
        /// fabricante— y lo encuentra igual.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, bool? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER REPUESTOS");
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<RepuestoDto> todo = Datos.Listar<RepuestoDto>("SEL_REPUESTO",
                    new Dictionary<string, object>
                    {
                        { "@ID", null },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@FILTRO", p.filtro },
                        // Por defecto solo los vigentes: ofrecer un repuesto
                        // dado de baja lleva a pedir algo que ya no se compra.
                        { "@HABILITADO", habilitado.HasValue ? (object)habilitado.Value : true }
                    });

                return Ok(Paginado<RepuestoDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /repuestos/{id} — la ficha.                HU-050</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER REPUESTOS");
                ExigirCliente();

                List<RepuestoDto> r = Datos.Listar<RepuestoDto>("SEL_REPUESTO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@FILTRO", null },
                        { "@HABILITADO", null }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("El repuesto");

                return Ok(r[0]);
            });
        }

        /// <summary>
        /// GET /repuestos/{id}/lotes — los lotes vigentes.  HU-054 CA2
        ///
        /// Solo tiene sentido para un repuesto que controla lote, y solo
        /// devuelve los que no estan vencidos: ofrecer un lote vencido en
        /// el combo del ingreso es invitar a usarlo.
        /// </summary>
        [HttpGet]
        [Route("{id:int}/lotes")]
        public IHttpActionResult Lotes(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER REPUESTOS");
                ExigirCliente();

                List<RepuestoLoteDto> r = Datos.Listar<RepuestoLoteDto>("SEL_REPUESTO_LOTE",
                    new Dictionary<string, object>
                    {
                        { "@ID", null },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@REPUESTO", id },
                        { "@VIGENTES", 1 }
                    });

                return Ok(r ?? new List<RepuestoLoteDto>());
            });
        }
    }
}
