using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Consulta de activos desde la app (HU-037).
    ///
    /// SOLO LECTURA. El alta y la edición de activos son del administrativo
    /// web; la app consulta la ficha y el historial de un equipo para
    /// entender qué le ha pasado antes de intervenirlo.
    ///
    /// EL CLIENTE SALE DEL TOKEN, NO DE LA URL
    ///   SesionApi.ClienteId() sale del JWT firmado. Aceptarlo por parámetro
    ///   dejaría consultar la historia de un activo de otra empresa cambiando
    ///   un número. El SP además valida que el activo sea del cliente.
    /// </summary>
    [RoutePrefix("activos")]
    public class ActivosController : ApiBase
    {
        /// <summary>
        /// GET /activos/{id}/ficha — la línea de tiempo del activo. HU-037
        ///
        /// Une cambios de estado, de posición y mediciones, con filtros por
        /// tipo de evento y rango de fechas, y paginación. La respuesta se
        /// cachea corto: el historial de un activo no cambia entre dos
        /// peticiones seguidas, y esta consulta se abre repetido desde el
        /// mismo equipo.
        /// </summary>
        [HttpGet]
        [Route("{id:int}/ficha")]
        public IHttpActionResult Ficha(int id, int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                       string tipo = null, DateTime? desde = null, DateTime? hasta = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER ACTIVOS");
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano };

                string extra = "id=" + id + ";t=" + (tipo ?? "") +
                               ";d=" + (desde.HasValue ? desde.Value.ToString("yyyyMMdd") : "") +
                               ";h=" + (hasta.HasValue ? hasta.Value.ToString("yyyyMMdd") : "");

                List<ActivoFichaEventoDto> todo = CacheCorta.Obtener(
                    CacheCorta.Clave("activoficha", SesionApi.UsuarioId(), SesionApi.ClienteId(), extra), () =>
                    Datos.Listar<ActivoFichaEventoDto>("SEL_ACTIVO_FICHA",
                        new Dictionary<string, object>
                        {
                            { "@ACTIVO", id },
                            { "@CLIENTE", SesionApi.ClienteId() },
                            { "@TIPO_EVENTO", tipo },
                            { "@FECHA_DESDE", desde },
                            { "@FECHA_HASTA", hasta },
                            { "@ORDEN_DESC", 1 },
                            { "@PAGINA", 1 },
                            { "@TAMANO", 200 }
                        }));

                return Ok(Paginado<ActivoFichaEventoDto>.Armar(todo, p));
            });
        }
    }
}
