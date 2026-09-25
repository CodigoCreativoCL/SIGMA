using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Posiciones funcionales: el lugar fijo de un área al que se le pega el
    /// QR y por el que pasan las máquinas.                       HU-033 · HU-154
    ///
    /// EL QR CODIFICA LA POSICIÓN, NO LA MÁQUINA
    ///   Cuando se cambia el equipo la etiqueta pegada en la sala sigue
    ///   sirviendo: el escaneo (GET /escaneo?c=POS-7) resuelve la posición y
    ///   de ahí el equipo que la ocupa hoy. Desde el teléfono, frente a una
    ///   posición vacía, se puede poner un equipo en ella (HU-154 #3).
    ///
    /// LAS REGLAS VIVEN EN EL SP
    ///   Misma planta, tipo admitido, un equipo en una sola posición, cierre
    ///   del periodo anterior: todo en UPD_ACTIVO_POSICION_OCUPAR (BD/231).
    ///   Aquí solo se arma la llamada.
    /// </summary>
    [RoutePrefix("posiciones")]
    public class PosicionesController : ApiBase
    {
        /// <summary>GET /posiciones — por planta o área; libre=true solo las vacías.</summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int? instalacion = null, int? area = null, bool? libre = null, string filtro = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER POSICIONES");
                ExigirCliente();
                return Ok(Datos.Listar<ActivoPosicionDto>("SEL_ACTIVO_POSICION", new Dictionary<string, object>
                {
                    { "@CLIENTE", SesionApi.ClienteId() },
                    { "@INSTALACION", instalacion },
                    { "@AREA", area },
                    { "@HABILITADO", true },
                    { "@LIBRE", libre },
                    { "@FILTRO", filtro }
                }));
            });
        }

        /// <summary>GET /posiciones/{id}</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Obtener(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER POSICIONES");
                ExigirCliente();
                List<ActivoPosicionDto> l = Datos.Listar<ActivoPosicionDto>("SEL_ACTIVO_POSICION",
                    new Dictionary<string, object> { { "@CLIENTE", SesionApi.ClienteId() }, { "@ID", id } });
                if (l.Count == 0) return NoEncontrado("La posición " + id);
                return Ok(l[0]);
            });
        }

        /// <summary>GET /posiciones/{id}/historial — los periodos de ocupación; el vigente no tiene fin. HU-033 #2</summary>
        [HttpGet]
        [Route("{id:int}/historial")]
        public IHttpActionResult Historial(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER POSICIONES");
                ExigirCliente();
                return Ok(Datos.Listar<ActivoPosicionHistorialDto>("SEL_ACTIVO_POSICION_HISTORIAL",
                    new Dictionary<string, object> { { "@CLIENTE", SesionApi.ClienteId() }, { "@POSICION", id } }));
            });
        }

        /// <summary>
        /// POST /posiciones/{id}/ocupar — pone un equipo en la posición. HU-154 #3
        /// Si había otro, su periodo se cierra; si el equipo venía de otra
        /// posición, también. Idempotente por uuid.
        /// </summary>
        /// <response code="200">APH_ID del periodo creado, POSICION y ACTIVO.</response>
        /// <response code="400">Equipo de otra planta, tipo no admitido, ya ocupa esa posición, posición deshabilitada.</response>
        [HttpPost]
        [Route("{id:int}/ocupar")]
        public IHttpActionResult Ocupar(int id, ActivoPosicionOcuparDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("CREAR EDITAR POSICIONES");
                ExigirCliente();
                ExigirUsuario();
                ExigirCuerpo(dto);

                List<ActivoPosicionOcupadaDto> r = Datos.Listar<ActivoPosicionOcupadaDto>("UPD_ACTIVO_POSICION_OCUPAR",
                    new Dictionary<string, object>
                    {
                        { "@POSICION", id },
                        { "@ACTIVO", dto.activo },
                        { "@MOTIVO", dto.motivo },
                        { "@OBSERVACION", dto.observacion },
                        { "@ORDEN_TRABAJO", dto.orden_trabajo },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@UUID", dto.uuid }
                    });
                return Ok(r.Count > 0 ? r[0] : new ActivoPosicionOcupadaDto { POSICION = id, ACTIVO = dto.activo });
            });
        }
    }
}
