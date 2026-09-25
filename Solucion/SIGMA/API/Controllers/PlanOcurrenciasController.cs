using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Ocurrencias de los planes de mantenimiento.        HU-076 · HU-087 · HU-111
    ///
    /// EL GENERADOR ES EL MISMO PARA TODOS
    ///   POST /plan-ocurrencias/generar llama a GEN_PLAN_OCURRENCIAS, el mismo
    ///   SP que usa el boton del centro del plan y que usara el job nocturno
    ///   (con @SOLO_AUTOMATICAS = 1). No hay dos generadores: si la web y la
    ///   API calcularan por su cuenta, terminarian discrepando sobre el mismo
    ///   plan. Es idempotente: correrlo dos veces no crea nada nuevo.
    ///
    /// LA ORDEN NACE DEL SP
    ///   POST /plan-ocurrencias/{id}/orden llama a INS_ORDEN_TRABAJO_OCURRENCIA.
    ///   Si la ocurrencia ya tiene orden devuelve esa (YA_EXISTIA = true): un
    ///   reintento del telefono no abre dos ordenes por la misma mantencion.
    /// </summary>
    [RoutePrefix("plan-ocurrencias")]
    public class PlanOcurrenciasController : ApiBase
    {
        /// <summary>
        /// GET /plan-ocurrencias — el calendario / la bandeja de pendientes.
        /// Sin rango, el año en curso. La SITUACION (futura, disponible,
        /// atrasada, vencida, cerrada) se deriva al consultar, no la guarda un
        /// proceso nocturno.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int? plan = null, int? activo = null, int? instalacion = null, int? estado = null,
                                        DateTime? desde = null, DateTime? hasta = null, string filtro = null,
                                        int pagina = 1, int tamano = 100)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER PLANES MANTENIMIENTO");
                ExigirCliente();

                List<PlanOcurrenciaDto> lista = Datos.Listar<PlanOcurrenciaDto>(
                    "SEL_PLAN_CALENDARIO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@PLAN", plan },
                        { "@ACTIVO", activo },
                        { "@INSTALACION", instalacion },
                        { "@ESTADO", estado },
                        { "@DESDE", desde },
                        { "@HASTA", hasta },
                        { "@FILTRO", filtro },
                        { "@PAGINA", pagina },
                        { "@TAMANO", tamano }
                    });

                return Ok(lista);
            });
        }

        /// <summary>
        /// POST /plan-ocurrencias/generar — genera las ocurrencias que faltan.
        /// </summary>
        /// <response code="200">Cuantas se generaron y el detalle por plan e hito.</response>
        /// <response code="400">El plan no existe o no tiene una version publicada.</response>
        [HttpPost]
        [Route("generar")]
        public IHttpActionResult Generar(PlanOcurrenciaGenerarDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("CREAR EDITAR PLANES MANTENIMIENTO");
                ExigirCliente();

                if (dto == null) dto = new PlanOcurrenciaGenerarDto();

                List<PlanOcurrenciaGeneradaDto> detalle = Datos.Listar<PlanOcurrenciaGeneradaDto>(
                    "GEN_PLAN_OCURRENCIAS",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@PLAN", dto.plan },
                        { "@HORIZONTE_DIA", dto.horizonte_dia ?? 90 },
                        { "@SOLO_AUTOMATICAS", dto.solo_automaticas },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                int total = 0;
                foreach (PlanOcurrenciaGeneradaDto d in detalle) total += d.GENERADAS;

                return Ok(new PlanOcurrenciaGeneracionDto { generadas = total, horizonte_dia = dto.horizonte_dia ?? 90, detalle = detalle });
            });
        }

        /// <summary>
        /// POST /plan-ocurrencias/{id}/orden — materializa la ocurrencia en una orden de trabajo.
        /// </summary>
        /// <response code="200">La orden, nueva o la que ya tenia (YA_EXISTIA).</response>
        /// <response code="400">La ocurrencia no esta pendiente ni disponible.</response>
        [HttpPost]
        [Route("{id:int}/orden")]
        public IHttpActionResult GenerarOrden(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("CREAR ORDEN TRABAJO");
                ExigirCliente();

                List<OrdenDesdeOcurrenciaDto> r = Datos.Listar<OrdenDesdeOcurrenciaDto>(
                    "INS_ORDEN_TRABAJO_OCURRENCIA",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@OCURRENCIA", id },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(r.Count > 0 ? r[0] : new OrdenDesdeOcurrenciaDto());
            });
        }
    }
}
