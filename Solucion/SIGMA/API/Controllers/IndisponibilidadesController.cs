using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Indisponibilidad de un equipo: cuánto estuvo detenido y por qué.   HU-124
    ///
    /// LOS MINUTOS LOS CALCULA EL SP
    ///   ain_minuto sale de inicio y término en INS/UPD_ACTIVO_INDISPONIBILIDAD;
    ///   el teléfono no manda minutos. Mientras no haya término el periodo
    ///   está abierto y MINUTOS_ACUMULADOS corre contra la hora del servidor.
    ///
    /// PLANIFICADA O NO
    ///   Planificada (una parada de mantenimiento) no penaliza la
    ///   disponibilidad; no planificada sí. Una indisponibilidad puede venir
    ///   de una orden, de una falla, o de ninguna (un corte de energía).
    /// </summary>
    [RoutePrefix("activo-indisponibilidades")]
    public class IndisponibilidadesController : ApiBase
    {
        /// <summary>GET /activo-indisponibilidades — por equipo, orden, falla, planta o rango.</summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int? activo = null, int? orden = null, int? falla = null, int? instalacion = null,
                                        DateTime? desde = null, DateTime? hasta = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER ORDENES TRABAJO");
                ExigirCliente();
                return Ok(Datos.Listar<ActivoIndisponibilidadDto>("SEL_ACTIVO_INDISPONIBILIDAD", new Dictionary<string, object>
                {
                    { "@CLIENTE", SesionApi.ClienteId() },
                    { "@ACTIVO", activo },
                    { "@ORDEN", orden },
                    { "@FALLA", falla },
                    { "@INSTALACION", instalacion },
                    { "@DESDE", desde },
                    { "@HASTA", hasta }
                }));
            });
        }

        /// <summary>GET /activo-indisponibilidades/{id}</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Obtener(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER ORDENES TRABAJO");
                ExigirCliente();
                List<ActivoIndisponibilidadDto> l = Datos.Listar<ActivoIndisponibilidadDto>("SEL_ACTIVO_INDISPONIBILIDAD",
                    new Dictionary<string, object> { { "@CLIENTE", SesionApi.ClienteId() }, { "@ID", id } });
                if (l.Count == 0) return NoEncontrado("La indisponibilidad " + id);
                return Ok(l[0]);
            });
        }

        /// <summary>POST /activo-indisponibilidades — registrar un periodo; sin término queda abierto.</summary>
        /// <response code="400">Término anterior al inicio, equipo de otro cliente, o sin motivo (ni catálogo ni texto).</response>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(ActivoIndisponibilidadAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("REGISTRAR FALLA");
                ExigirCliente();
                ExigirUsuario();
                ExigirCuerpo(dto);

                int id = Datos.Ejecutar("INS_ACTIVO_INDISPONIBILIDAD", new Dictionary<string, object>
                {
                    { "@CLIENTE", SesionApi.ClienteId() },
                    { "@ACTIVO", dto.activo },
                    { "@ORDEN_TRABAJO", dto.orden_trabajo },
                    { "@FALLA", dto.falla },
                    { "@FECHA_INICIO_UTC", dto.fecha_inicio_utc },
                    { "@FECHA_FIN_UTC", dto.fecha_fin_utc },
                    { "@PLANIFICADA", dto.planificada },
                    { "@DETUVO_PRODUCCION", dto.detuvo_produccion },
                    { "@MOTIVO_CATALOGO", dto.motivo_catalogo },
                    { "@MOTIVO", dto.motivo },
                    { "@USUARIO", SesionApi.UsuarioId() }
                }, true);
                return Creado(id);
            });
        }

        /// <summary>PUT /activo-indisponibilidades/{id} — cerrar el periodo (término) o corregir tipo y motivo.</summary>
        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Actualizar(int id, ActivoIndisponibilidadEdicionDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("REGISTRAR FALLA");
                ExigirCliente();
                ExigirUsuario();
                ExigirCuerpo(dto);

                Datos.Ejecutar("UPD_ACTIVO_INDISPONIBILIDAD", new Dictionary<string, object>
                {
                    { "@ID", id },
                    { "@CLIENTE", SesionApi.ClienteId() },
                    { "@FECHA_FIN_UTC", dto.fecha_fin_utc },
                    { "@PLANIFICADA", dto.planificada },
                    { "@DETUVO_PRODUCCION", dto.detuvo_produccion },
                    { "@MOTIVO_CATALOGO", dto.motivo_catalogo },
                    { "@MOTIVO", dto.motivo },
                    { "@HABILITADO", dto.habilitado },
                    { "@USUARIO", SesionApi.UsuarioId() }
                });
                return Ok(new { ain_id = id });
            });
        }
    }
}
