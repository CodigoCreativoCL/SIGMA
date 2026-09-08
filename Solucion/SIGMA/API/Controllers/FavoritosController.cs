using API.MVC.Model;
using API.Utils;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Lo que la persona fija arriba de su bandeja.
    ///
    /// POR QUE UN SOLO ENDPOINT QUE ALTERNA
    ///
    ///   La estrella es un interruptor, y la app no sabe —ni tiene por que
    ///   saber— si el favorito ya estaba antes de tocarla. Con un POST para
    ///   marcar y un DELETE para desmarcar, dos toques rapidos pueden cruzarse
    ///   y dejar el estado invertido respecto de lo que muestra la pantalla.
    ///
    ///   Este devuelve COMO QUEDO, asi la estrella se pinta con lo que dijo la
    ///   base y no con lo que la app supone.
    ///
    /// NO HAY UN LISTADO DE FAVORITOS
    ///
    ///   A proposito: marcar algo no cambia lo que es, cambia DONDE aparece.
    ///   El favorito viaja como `ES_FAVORITO` dentro del listado que la
    ///   persona ya esta mirando, y se fija arriba de esa misma bandeja. Una
    ///   pantalla aparte seria una lista mas que mantener y un sitio mas donde
    ///   mirar.
    /// </summary>
    [RoutePrefix("favoritos")]
    public class FavoritosController : ApiBase
    {
        /// <summary>
        /// POST /favoritos — marca o desmarca, y responde como quedo.
        /// </summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Alternar(FavoritoDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                if (dto == null)
                    return BadRequest("Falta el cuerpo de la petición.");

                /* El SP valida la entidad y responde con un RAISERROR que
                   ErrorSql traduce a 400 con su mensaje: no se repite la lista
                   de entidades validas aca, porque dos listas se
                   desincronizan. */
                List<FavoritoResultadoDto> r =
                    Datos.Listar<FavoritoResultadoDto>("API_UPS_FAVORITO",
                        new Dictionary<string, object>
                        {
                            { "@USUARIO", SesionApi.UsuarioId() },
                            { "@CLIENTE", SesionApi.ClienteId() },
                            { "@ENTIDAD", dto.entidad },
                            { "@ENTIDAD_ID", dto.entidad_id }
                        });

                return Ok(new
                {
                    entidad = dto.entidad,
                    entidad_id = dto.entidad_id,
                    es_favorito = (r != null && r.Count > 0) && r[0].ES_FAVORITO
                });
            });
        }
    }
}
