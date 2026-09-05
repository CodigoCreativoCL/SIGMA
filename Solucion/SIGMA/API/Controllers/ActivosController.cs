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
        /// <summary>
        /// GET /activos/{id} — la cabecera del activo.            HU-037
        ///
        /// POR QUE HIZO FALTA
        ///   `/ficha` devuelve los EVENTOS del activo, no el activo. La app
        ///   llegaba a la pantalla de ficha sin nombre, tipo ni criticidad y
        ///   tenia que recibirlos por parametro desde donde la abrieron — asi
        ///   que un activo abierto desde el escaneo mostraba distinto que el
        ///   mismo abierto desde un listado. Detectado al conectar la app.
        ///
        /// EL CLIENTE SALE DEL TOKEN
        ///   `SEL_ACTIVO` lo recibe y filtra: un id de otro cliente devuelve
        ///   404, no la ficha ajena.
        /// </summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER ACTIVOS");
                ExigirCliente();

                List<ActivoDto> r = Datos.Listar<ActivoDto>("SEL_ACTIVO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("El activo");

                return Ok(r[0]);
            });
        }

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

                /* @TOTAL es un parámetro de SALIDA obligatorio de
                   SEL_ACTIVO_FICHA. Omitirlo hacía que SQL Server rechazara
                   la llamada —"expects parameter '@TOTAL', which was not
                   supplied"— y este endpoint respondía 500 en cada petición.
                   Se detectó ejercitando la API por HTTP el 04-09-2026.
                   Por eso va ListarConTotal y no Listar. */
                List<ActivoFichaEventoDto> todo = CacheCorta.Obtener(
                    CacheCorta.Clave("activoficha", SesionApi.UsuarioId(), SesionApi.ClienteId(), extra), () =>
                    {
                        int totalSql;
                        return Datos.ListarConTotal<ActivoFichaEventoDto>("SEL_ACTIVO_FICHA",
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
                            }, out totalSql);
                    });

                return Ok(Paginado<ActivoFichaEventoDto>.Armar(todo, p));
            });
        }
    }
}
