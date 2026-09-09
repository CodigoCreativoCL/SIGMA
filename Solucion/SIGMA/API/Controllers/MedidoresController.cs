using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Medidores y sus lecturas — vistas 9.1 y 9.2.
    ///
    /// POR QUE HIZO FALTA
    ///   Registrar una lectura ya se podia (HU-043, por CapturaTerreno), pero
    ///   no habia forma de LEER las anteriores. El tecnico anotaba el
    ///   horometro sin poder mirar si el numero que estaba escribiendo tenia
    ///   sentido contra los ultimos seis meses, que es justo lo que 9.1 pide
    ///   como «advertencia por salto no razonable»: sin historial no hay con
    ///   que advertir.
    ///
    /// EL ALTA NO ESTA ACA
    ///   Sigue en CapturaTerreno, con el resto de lo que se captura en
    ///   terreno, porque se encola igual que una bitacora o una evidencia.
    ///   Partirla en dos sitios seria tener dos caminos para un mismo dato.
    /// </summary>
    [RoutePrefix("medidores")]
    public class MedidoresController : ApiBase
    {
        /// <summary>
        /// GET /medidores?activo={id} — los medidores de un equipo.
        ///
        /// Es el punto de entrada de 9.2: se elige el medidor y despues se
        /// mira su historial. Sin `activo` devuelve los del cliente, que es
        /// lo que necesita una busqueda.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int? activo = null, string filtro = null,
                                        int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER MEDIDORES");
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<MedidorDto> todo = Datos.Listar<MedidorDto>("SEL_ACTIVO_MEDIDOR",
                    new Dictionary<string, object>
                    {
                        { "@ID", null },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@ACTIVO", activo.HasValue ? (object)activo.Value : null },
                        { "@HABILITADO", true },
                        { "@FILTRO", p.filtro }
                    });

                return Ok(Paginado<MedidorDto>.Armar(todo, p));
            });
        }

        /// <summary>
        /// GET /medidores/{id} — el medidor con sus umbrales.
        ///
        /// Los umbrales van en la misma respuesta porque la pantalla los
        /// dibuja como lineas sobre el mismo grafico: pedirlos aparte seria
        /// un segundo viaje para poder pintar el primero.
        /// </summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER MEDIDORES");
                ExigirCliente();

                List<MedidorDto> r = Datos.Listar<MedidorDto>("SEL_ACTIVO_MEDIDOR",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@ACTIVO", null },
                        { "@HABILITADO", null },
                        { "@FILTRO", null }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("El medidor");

                MedidorDto m = r[0];

                m.UMBRALES = Datos.Listar<MedidorUmbralDto>("API_SEL_ACTIVO_MEDIDOR_UMBRAL",
                    new Dictionary<string, object>
                    {
                        { "@MEDIDOR", id },
                        { "@CLIENTE", SesionApi.ClienteId() }
                    }) ?? new List<MedidorUmbralDto>();

                return Ok(m);
            });
        }

        /// <summary>
        /// GET /medidores/{id}/lecturas — el historial.             Vista 9.2
        ///
        /// Vienen en orden ASCENDENTE y con el incremento ya calculado: es
        /// una serie para un grafico, y un grafico al reves cuenta la
        /// historia de atras para adelante. La tabla la da vuelta la pantalla,
        /// que es una linea.
        /// </summary>
        [HttpGet]
        [Route("{id:int}/lecturas")]
        public IHttpActionResult Lecturas(int id, DateTime? desde = null, DateTime? hasta = null,
                                          int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER MEDIDORES");
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano };

                string extra = "id=" + id +
                               ";d=" + (desde.HasValue ? desde.Value.ToString("yyyyMMdd") : "") +
                               ";h=" + (hasta.HasValue ? hasta.Value.ToString("yyyyMMdd") : "");

                List<LecturaDto> todo = CacheCorta.Obtener(
                    CacheCorta.Clave("lecturas", SesionApi.UsuarioId(), SesionApi.ClienteId(), extra), () =>
                    {
                        // @TOTAL es parametro de SALIDA obligatorio: omitirlo
                        // hace que SQL Server rechace la llamada entera.
                        int totalSql;
                        return Datos.ListarConTotal<LecturaDto>("API_SEL_ACTIVO_MEDIDOR_LECTURA",
                            new Dictionary<string, object>
                            {
                                { "@MEDIDOR", id },
                                { "@CLIENTE", SesionApi.ClienteId() },
                                { "@FECHA_DESDE", desde },
                                { "@FECHA_HASTA", hasta },
                                { "@PAGINA", 1 },
                                { "@TAMANO", 500 }
                            }, out totalSql);
                    });

                return Ok(Paginado<LecturaDto>.Armar(todo, p));
            });
        }
    }
}
