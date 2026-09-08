﻿using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Checklist en terreno.                                       HU-095
    ///
    /// LA PAUTA SE LLENA SIN SEÑAL
    ///   El modelo lo tenía previsto —`cej_uuid`, `cej_offline_creado`,
    ///   `cej_fecha_sincronizacion_utc`— y estos endpoints lo respetan: la
    ///   ejecución es idempotente por uuid y cada respuesta lo es por
    ///   (ejecución, item). Reenviar una pauta de treinta ítems desde la cola
    ///   no duplica nada.
    ///
    /// EL RANGO LO EVALUA EL SERVIDOR
    ///   `Checklist_Item_Validacion` dice qué se espera y si genera hallazgo.
    ///   Si lo evaluara la app, un teléfono con la pauta vieja aceptaría en
    ///   silencio lo que la planta ya considera fuera de norma.
    ///
    /// FUERA DE RANGO NO IMPIDE RESPONDER
    ///   Es al revés: el valor fuera de rango **es** el hallazgo. Bloquear su
    ///   captura obligaría al técnico a anotarlo en papel, que es justo lo que
    ///   esta app existe para evitar.
    ///
    /// LA CONFORMIDAD DE UN SI/NO LA DECLARA LA PAUTA
    ///   A «¿Hay fugas visibles?» la respuesta conforme es NO; a «¿Opera sin
    ///   ruidos?» es SÍ. Misma estructura, criterio opuesto. Lo sabe quien
    ///   redactó la pregunta, así que vive en `cio_es_conforme` y no en una
    ///   regla adivinada.
    /// </summary>
    [RoutePrefix("checklist")]
    public class ChecklistController : ApiBase
    {
        /// <summary>
        /// GET /checklist/pendientes — las pautas que me tocan.
        /// </summary>
        /// <response code="200">Ordenadas por lo vencido primero.</response>
        [HttpGet]
        [Route("pendientes")]
        public IHttpActionResult Pendientes(int? instalacion = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("EJECUTAR CHECKLIST");
                ExigirCliente();

                List<ChecklistPendienteDto> todo = Datos.Listar<ChecklistPendienteDto>(
                    "API_SEL_CHECKLIST",
                    new Dictionary<string, object>
                    {
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@TIPO", 1 },
                        { "@INSTALACION", instalacion }
                    });

                return Ok(todo);
            });
        }

        /// <summary>
        /// GET /checklist/plantillas/{version} — ítems y opciones de la pauta.
        ///
        /// Los dos juntos porque la app **no puede pintar un ítem de selección
        /// sin sus opciones**, y pedirlas aparte serían dos viajes de red para
        /// dibujar una sola pantalla.
        /// </summary>
        [HttpGet]
        [Route("plantillas/{version:int}")]
        public IHttpActionResult Plantilla(int version)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("EJECUTAR CHECKLIST");
                ExigirCliente();

                List<ChecklistItemDto> items = Datos.Listar<ChecklistItemDto>(
                    "API_SEL_CHECKLIST", Parametros(2, version));

                List<ChecklistOpcionDto> opciones = Datos.Listar<ChecklistOpcionDto>(
                    "API_SEL_CHECKLIST", Parametros(4, version));

                return Ok(new ChecklistPlantillaDto { items = items, opciones = opciones });
            });
        }

        /// <summary>
        /// POST /checklist/ejecuciones — abre o retoma una ejecución.
        ///
        /// Si ya hay un borrador de esa ocurrencia, se devuelve **ese**: una
        /// pauta a medias que se abandona y se rehace pierde lo caminado, y en
        /// terreno eso significa volver a recorrer la planta.
        /// </summary>
        /// <response code="201">Abierta, o la que ya estaba. Devuelve el id en los dos casos.</response>
        /// <response code="400">Esa versión de la pauta no está publicada.</response>
        [HttpPost]
        [Route("ejecuciones")]
        public IHttpActionResult Abrir(ChecklistEjecucionAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("EJECUTAR CHECKLIST");
                ExigirCliente();
                ExigirCuerpo(dto);

                int id = Datos.Ejecutar("API_INS_CHECKLIST_EJECUCION",
                    new Dictionary<string, object>
                    {
                        { "@UUID", dto.uuid },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@OCURRENCIA", dto.ocurrencia },
                        { "@VERSION", dto.version },
                        { "@ACTIVO", dto.activo },
                        { "@DISPOSITIVO", dto.dispositivo },
                        { "@OFFLINE", dto.offline }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>
        /// GET /checklist/ejecuciones/{id} — la ejecución con sus respuestas.
        /// </summary>
        [HttpGet]
        [Route("ejecuciones/{id:int}")]
        public IHttpActionResult Ejecucion(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("EJECUTAR CHECKLIST");
                ExigirCliente();

                ChecklistEjecucionDto cabecera;
                List<ChecklistRespuestaDto> respuestas;

                Datos.ListarDos("API_SEL_CHECKLIST", Parametros(3, id),
                                out cabecera, out respuestas);

                if (cabecera == null) return NoEncontrado("La ejecución no existe.");

                cabecera.respuestas = respuestas;
                return Ok(cabecera);
            });
        }

        /// <summary>
        /// POST /checklist/ejecuciones/{id}/respuestas — responde un ítem.
        ///
        /// Es un UPSERT por (ejecución, ítem): volver a responder **actualiza**.
        /// Eso es lo que hace seguro reenviar la pauta desde la cola, y también
        /// que el técnico pueda corregirse antes de cerrar.
        /// </summary>
        /// <response code="200">Grabada. Dice si quedó fuera de rango y por qué.</response>
        /// <response code="400">La pauta ya fue enviada, o el ítem no es de esa pauta.</response>
        [HttpPost]
        [Route("ejecuciones/{id:int}/respuestas")]
        public IHttpActionResult Responder(int id, ChecklistRespuestaAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("EJECUTAR CHECKLIST");
                ExigirCliente();
                ExigirCuerpo(dto);

                List<ChecklistRespuestaResultadoDto> r =
                    Datos.Listar<ChecklistRespuestaResultadoDto>(
                        "API_UPS_CHECKLIST_RESPUESTA",
                        new Dictionary<string, object>
                        {
                            { "@CEJ_ID", id },
                            { "@USUARIO", SesionApi.UsuarioId() },
                            { "@CLIENTE", SesionApi.ClienteId() },
                            { "@ITEM", dto.item },
                            { "@VALOR_TEXTO", dto.valor_texto },
                            { "@VALOR_NUMERO", dto.valor_numero },
                            { "@VALOR_BOOLEANO", dto.valor_booleano },
                            { "@VALOR_FECHA", dto.valor_fecha },
                            { "@NO_APLICA", dto.no_aplica },
                            { "@COMENTARIO", dto.comentario },
                            { "@ENTRADA_MODO", dto.entrada_modo }
                        });

                return Ok(r.Count > 0 ? r[0] : new ChecklistRespuestaResultadoDto());
            });
        }

        /// <summary>
        /// POST /checklist/ejecuciones/{id}/cerrar — envía la pauta.
        ///
        /// Exige los obligatorios respondidos. **«No aplica» cuenta como
        /// respuesta**: no todo ítem corresponde a todo equipo, y obligar a
        /// inventar un valor para poder cerrar es peor que aceptar el
        /// «no aplica».
        /// </summary>
        /// <response code="200">Enviada. Cerrar dos veces responde lo mismo.</response>
        /// <response code="400">Faltan ítems obligatorios; el mensaje dice cuántos.</response>
        [HttpPost]
        [Route("ejecuciones/{id:int}/cerrar")]
        public IHttpActionResult Cerrar(int id, ChecklistCierreDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("EJECUTAR CHECKLIST");
                ExigirCliente();

                Datos.Ejecutar("API_UPD_CHECKLIST_CERRAR",
                    new Dictionary<string, object>
                    {
                        { "@CEJ_ID", id },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@MINUTOS", dto == null ? null : (object)dto.minutos },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@OBSERVACION", dto == null ? null : dto.observacion }
                    });

                return Ok(new { cej_id = id });
            });
        }

        private Dictionary<string, object> Parametros(int tipo, int id)
        {
            return new Dictionary<string, object>
            {
                { "@USUARIO", SesionApi.UsuarioId() },
                { "@CLIENTE", SesionApi.ClienteId() },
                { "@TIPO", tipo },
                { "@ID", id }
            };
        }
    }
}
