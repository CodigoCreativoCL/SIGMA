using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Áreas de una planta (HU-012).
    ///
    /// SON UN ARBOL. Un área puede colgar de otra, y el SP rechaza los
    /// ciclos —incluidos los INDIRECTOS: A padre de B, B padre de C, y
    /// alguien intenta poner C como padre de A—. Esa comprobación NO se
    /// repite acá: está en INS_/UPD_INSTALACION_AREA, que es donde puede
    /// mirar el árbol completo dentro de la misma transacción.
    /// </summary>
    [RoutePrefix("instalacion-areas")]
    public class InstalacionAreasController : ApiBase
    {
        /// <summary>GET /instalacion-areas — listado.            HU-012</summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, int? instalacion = null,
                                        int? padre = null, bool soloRaiz = false,
                                        bool? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER AREAS");
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<InstalacionAreaDto> todo = Datos.Listar<InstalacionAreaDto>("SEL_INSTALACION_AREA",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@CLIENTE_INSTALACION", instalacion },
                        { "@AREA_PADRE", padre },
                        { "@SOLO_RAIZ", soloRaiz ? (object)true : null },
                        { "@HABILITADO", habilitado },
                        { "@FILTRO", p.filtro }
                    });

                return Ok(Paginado<InstalacionAreaDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /instalacion-areas/{id} — detalle.       HU-012</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER AREAS");
                ExigirCliente();

                List<InstalacionAreaDto> r = Datos.Listar<InstalacionAreaDto>("SEL_INSTALACION_AREA",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("El área");

                return Ok(r[0]);
            });
        }
    }
}
