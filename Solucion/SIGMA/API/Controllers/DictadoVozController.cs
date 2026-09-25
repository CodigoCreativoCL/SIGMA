using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Data;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// El dictado por voz de cualquier campo de la app (HU-160).
    ///
    /// QUE ES Y QUE NO ES
    ///   No es un recurso que el usuario "administra": es un hecho que el
    ///   telefono registra cuando alguien dicta en un campo -una observacion,
    ///   una falla, un comentario-. Por eso la seguridad no es un permiso de
    ///   modulo sino la identidad del token y el cliente en contexto: quien
    ///   puede escribir en el campo puede dictarlo, y solo ve lo suyo.
    ///
    /// LA IDENTIDAD SALE DEL TOKEN, NUNCA DE UN PARAMETRO
    ///   @USUARIO y @CLIENTE los pone SesionApi. Aceptar ?usuario= dejaria que
    ///   cualquiera con un token valido subiera o se bajara los dictados de
    ///   otro.
    ///
    /// LA SUSCRIPCION LA CORTA EL MIDDLEWARE
    ///   SuscripcionVigenteHandler valida la KEY del cliente y responde 402
    ///   antes de llegar aca (T-4158). El controller no lo repite.
    /// </summary>
    [RoutePrefix("dictado-voz")]
    public class DictadoVozController : ApiBase
    {
        /// <summary>
        /// GET /dictado-voz/sync — descarga para el dispositivo, del usuario y
        /// su cliente. `?desde=` trae solo lo posterior (incremental).   HU-160
        /// </summary>
        [HttpGet]
        [Route("sync")]
        public IHttpActionResult Descargar(DateTime? desde = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                DataSet ds = Datos.Conjunto("API_SEL_DICTADO_VOZ",
                    new Dictionary<string, object>
                    {
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@DESDE", desde }
                    });

                return Ok(new
                {
                    desde = desde,
                    servidor_fecha_utc = DateTime.UtcNow,
                    dictados = Datos.Filas(ds, 0)
                });
            });
        }

        /// <summary>
        /// POST /dictado-voz/sync — subida por lotes, idempotente por uuid. La
        /// app manda lo que encolo sin señal; el reenvio de un uuid ya recibido
        /// devuelve el mismo id, no un duplicado.                        HU-160
        /// </summary>
        /// <response code="200">Procesado. Devuelve el id de cada uuid.</response>
        /// <response code="400">Un item sin uuid o sin texto.</response>
        /// <response code="402">La suscripcion del cliente no permite operar.</response>
        [HttpPost]
        [Route("sync")]
        public IHttpActionResult Subir(List<DictadoVozAltaDto> dtos)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dtos);

                List<Dictionary<string, object>> resultados = new List<Dictionary<string, object>>();

                foreach (DictadoVozAltaDto dto in dtos)
                {
                    if (dto == null) throw new ArgumentException("El lote trae un item vacío.");
                    if (dto.uuid == null || dto.uuid == Guid.Empty)
                        throw new ArgumentException("Cada dictado necesita su uuid (lo genera el teléfono).");
                    ExigirTexto(dto.texto, "texto");

                    int id = Datos.Ejecutar("API_INS_DICTADO_VOZ",
                        new Dictionary<string, object>
                        {
                            { "@UUID", dto.uuid },
                            // Del token, no del cuerpo: es a quien se audita.
                            { "@USUARIO", SesionApi.UsuarioId() },
                            { "@CLIENTE", SesionApi.ClienteId() },
                            { "@TEXTO", dto.texto },
                            { "@IDIOMA", dto.idioma },
                            { "@MOTOR", dto.motor },
                            { "@MODELO", dto.modelo },
                            { "@CONFIANZA", dto.confianza },
                            { "@SEGUNDOS", dto.segundos },
                            { "@INTENTOS", dto.intentos },
                            { "@CONFIRMADO", dto.confirmado },
                            { "@CONFIRMADO_VOZ", dto.confirmado_por_voz },
                            { "@DISPOSITIVO", dto.dispositivo_uuid }
                        }, true);

                    resultados.Add(new Dictionary<string, object>
                    {
                        { "uuid", dto.uuid },
                        { "id", id }
                    });
                }

                return Ok(new
                {
                    recibidos = dtos.Count,
                    guardados = resultados,
                    servidor_fecha_utc = DateTime.UtcNow
                });
            });
        }
    }
}
