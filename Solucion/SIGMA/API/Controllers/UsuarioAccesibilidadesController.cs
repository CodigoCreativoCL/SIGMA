using API.MVC.Model;
using API.Utils;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Las opciones de accesibilidad de la PERSONA.                    HU-162
    ///
    /// CADA UNO LAS SUYAS
    ///   La preferencia es de quien entra, no de un administrador: hay una fila
    ///   por usuario (índice único UX_UAC_USUARIO). Por eso estos endpoints
    ///   trabajan siempre contra el usuario del token —`SesionApi.UsuarioId()`—
    ///   y nunca reciben un id de usuario por parámetro: nadie lee ni cambia las
    ///   opciones de otro. Eso ocupa el lugar del «filtro por cliente» del resto
    ///   de la API: acá el dueño es la persona.
    /// </summary>
    [RoutePrefix("usuario-accesibilidades")]
    public class UsuarioAccesibilidadesController : ApiBase
    {
        /// <summary>
        /// GET /usuario-accesibilidades — las opciones de quien llama.
        ///
        /// Devuelve la fila de la persona (0 o 1; el índice único garantiza que
        /// no hay más). Se expone un DTO sin las columnas internas (quién creó,
        /// fechas de auditoría de escritura).
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Mias(bool? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();

                List<UsuarioAccesibilidadDto> lista = Datos.Listar<UsuarioAccesibilidadDto>(
                    "SEL_USUARIO_ACCESIBILIDAD",
                    new Dictionary<string, object>
                    {
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@HABILITADO", habilitado }
                    });

                return Ok(lista);
            });
        }
    }
}
