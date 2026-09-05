using API.MVC.Model;
using API.Utils;
using System.Collections.Generic;
using System.Net;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// El token FCM del teléfono, para que las alertas lleguen solas (HU-077).
    ///
    /// POR QUE NO EXIGE PERMISO
    ///   Registrar el token es parte de iniciar sesión, igual que
    ///   `GET /cliente-usuarios/mis-clientes`. Exigir un permiso aquí dejaría
    ///   sin avisos a quien todavía no tiene ninguno asignado, que es
    ///   justamente a quien hay que avisarle que ya puede trabajar.
    ///
    ///   Sí exige usuario: el token se asocia a quien trae el JWT, **nunca a
    ///   un ?usuario= de la URL**. Si no, cualquiera con un token válido
    ///   redirigiría las alertas de otra persona a su propio teléfono.
    ///
    /// EL DELETE NO ES OPCIONAL
    ///   Al cerrar sesión hay que borrarlo. Sin eso, el próximo que use ese
    ///   teléfono recibe las alertas del anterior — y eso es una fuga de
    ///   información del cliente, no una molestia.
    ///
    /// EL TOKEN IDENTIFICA AL TELEFONO, NO A LA PERSONA
    ///   `API_UPS_USUARIO_APP_DISPOSITIVO` hace MERGE por token: si el técnico
    ///   y el supervisor usan el mismo aparato, el token pasa del uno al otro
    ///   en vez de quedar en los dos.
    /// </summary>
    [RoutePrefix("dispositivos")]
    public class DispositivosController : ApiBase
    {
        /// <summary>
        /// POST /dispositivos — registra o reasigna el token de este teléfono.
        /// </summary>
        /// <response code="200">Registrado.</response>
        /// <response code="400">Falta el token.</response>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Registrar(DispositivoDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCuerpo(dto);

                if (string.IsNullOrWhiteSpace(dto.token))
                    return Error(HttpStatusCode.BadRequest, "Falta el token del dispositivo.");

                /* El nombre del aparato y la versión van juntos: cuando alguien
                   reclame "no me llegan las alertas", saber que es un Xiaomi
                   con la 1.0.3 ahorra media hora de preguntas. */
                string descripcion = dto.dispositivo;

                if (!string.IsNullOrWhiteSpace(dto.app_version))
                    descripcion = (descripcion ?? "") + " · v" + dto.app_version;

                Datos.Ejecutar("API_UPS_USUARIO_APP_DISPOSITIVO",
                    new Dictionary<string, object>
                    {
                        { "@ID_USUARIO", SesionApi.UsuarioId() },
                        { "@TOKEN", dto.token.Trim() },
                        { "@DISPOSITIVO", descripcion }
                    });

                return Ok(new { registrado = true });
            });
        }

        /// <summary>
        /// DELETE /dispositivos — baja el token al cerrar sesión.
        ///
        /// Sin `token` en el cuerpo, el SP de baja quita **todos** los del
        /// usuario: es lo que corresponde cuando alguien pierde el teléfono.
        /// </summary>
        [HttpDelete]
        [Route("")]
        public IHttpActionResult Eliminar(DispositivoDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();

                Datos.Ejecutar("DEL_USUARIO_APP_DISPOSITIVO",
                    new Dictionary<string, object>
                    {
                        { "@ID_USUARIO", SesionApi.UsuarioId() },
                        { "@TOKEN", dto == null ? null : dto.token }
                    });

                return Ok(new { eliminado = true });
            });
        }
    }
}
