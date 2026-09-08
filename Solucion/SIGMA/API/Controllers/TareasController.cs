using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Tareas en terreno.                                  HU-103 y HU-104
    ///
    /// UNA TAREA NO ES UNA ORDEN CHICA
    ///   Es el trabajo breve que hoy no deja registro: revisar un nivel,
    ///   limpiar un filtro, apretar un prensaestopas. Abrir una OT para eso es
    ///   tanto papeleo que nadie lo hace —y lo que no se registra no existe,
    ///   ni para el historial del activo ni para dimensionar la carga real del
    ///   equipo—. Por eso no tiene pasos, ni permiso de trabajo, ni cierre por
    ///   un supervisor.
    ///
    /// EMPEZAR Y CERRAR SON EL MISMO ENDPOINT
    ///   Porque en terreno son un solo acto, muchas veces en la misma pantalla
    ///   y sin señal. Partirlo en dos obligaría a la cola a mantener el orden
    ///   entre ambos, y un «cerrar» que llega antes que su «empezar» no tiene
    ///   arreglo.
    ///
    /// EL DICTADO SE GUARDA, EL AUDIO NO
    ///   Un comentario dictado deja dos textos: el que entendió el teléfono y
    ///   el que la persona dio por bueno. Guardar los dos es lo único que
    ///   después permite saber si dictar sirve en una sala de máquinas. El
    ///   audio no se guarda: es una carga de privacidad que no hace falta para
    ///   nada de lo que el sistema tiene que hacer.
    ///
    /// EL COMENTARIO NO SE EDITA NI SE BORRA
    ///   `Tarea_Comentario` no tiene `habilitado` ni auditoría de
    ///   actualización, y sí tiene `tco_comentario_padre`. El modelo lo dice
    ///   claro: un comentario se responde, no se reescribe. Por eso acá hay
    ///   POST y no hay PUT ni DELETE.
    /// </summary>
    [RoutePrefix("tareas")]
    public class TareasController : ApiBase
    {
        /// <summary>
        /// GET /tareas — mis tareas pendientes.
        ///
        /// Incluye las que **no tienen dueño**: una tarea breve sin asignar la
        /// puede tomar cualquiera del turno, que es justo lo que la hace útil.
        /// </summary>
        /// <response code="200">Lo vencido primero, después por prioridad y plazo.</response>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Pendientes(int? instalacion = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("EJECUTAR TAREA");
                ExigirCliente();

                List<TareaPendienteDto> todo = Datos.Listar<TareaPendienteDto>(
                    "API_SEL_TAREA",
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
        /// GET /tareas/{id} — la tarea con su ejecución y su hilo.
        ///
        /// El hilo viene en la misma respuesta porque la pantalla no se puede
        /// dibujar sin él, y pedirlo aparte serían dos viajes de red para una
        /// sola vista.
        /// </summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Ficha(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("EJECUTAR TAREA");
                ExigirCliente();

                List<TareaDto> cab = Datos.Listar<TareaDto>(
                    "API_SEL_TAREA",
                    new Dictionary<string, object>
                    {
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@TIPO", 2 },
                        { "@ID", id }
                    });

                if (cab.Count == 0) return NoEncontrado("La tarea no existe.");

                TareaDto tarea = cab[0];
                tarea.comentarios = Comentarios(id);

                return Ok(tarea);
            });
        }

        /// <summary>
        /// POST /tareas/ejecuciones — empieza o cierra una tarea.
        ///
        /// Idempotente por `uuid`, que genera el teléfono al empezar y no al
        /// enviar: si se generara al enviar, un reintento traería uno nuevo y
        /// abriría una segunda ejecución de algo que se hizo una sola vez.
        ///
        /// Reenviar un cierre que ya llegó responde lo mismo en vez de fallar.
        /// Sin eso, la cola reintentando le mostraría al técnico un error por
        /// algo que sí quedó grabado, y volvería a llenar lo que ya estaba.
        /// </summary>
        /// <response code="200">Abierta, retomada o cerrada. `YA_ESTABA` dice si el envío ya había llegado.</response>
        /// <response code="400">La tarea ya está cerrada, o falta el motivo de una no realizada.</response>
        [HttpPost]
        [Route("ejecuciones")]
        public IHttpActionResult Registrar(TareaEjecucionDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("EJECUTAR TAREA");
                ExigirCliente();
                ExigirCuerpo(dto);

                List<TareaEjecucionResultadoDto> r =
                    Datos.Listar<TareaEjecucionResultadoDto>(
                        "API_UPS_TAREA_EJECUCION",
                        new Dictionary<string, object>
                        {
                            { "@UUID", dto.uuid },
                            { "@USUARIO", SesionApi.UsuarioId() },
                            { "@CLIENTE", SesionApi.ClienteId() },
                            { "@OCURRENCIA", dto.ocurrencia },
                            { "@FINALIZAR", dto.finalizar },
                            { "@CONFORME", dto.conforme },
                            { "@RESULTADO", dto.resultado },
                            { "@MINUTOS", dto.minutos },
                            { "@DISPOSITIVO", dto.dispositivo },
                            { "@OFFLINE", dto.offline }
                        });

                return Ok(r.Count > 0 ? r[0] : new TareaEjecucionResultadoDto());
            });
        }

        /// <summary>
        /// GET /tareas/{id}/comentarios — el hilo.
        /// </summary>
        [HttpGet]
        [Route("{id:int}/comentarios")]
        public IHttpActionResult Hilo(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("COMENTAR TAREA");
                ExigirCliente();

                return Ok(Comentarios(id));
            });
        }

        /// <summary>
        /// POST /tareas/{id}/comentarios — escribe o responde.
        ///
        /// El dictado, si lo hubo, se graba en la misma transacción: un
        /// comentario y su dictado son un solo acto, y en dos envíos la cola
        /// podría dejar uno sin el otro.
        ///
        /// Se pide `COMENTAR TAREA` y no `EJECUTAR TAREA` porque comentar y
        /// ejecutar las hacen personas distintas: el planificador responde el
        /// hilo sin caminar la tarea.
        /// </summary>
        /// <response code="200">Grabado. `YA_ESTABA` avisa si era un reenvío.</response>
        /// <response code="400">Comentario vacío, o respuesta a un comentario de otra tarea.</response>
        [HttpPost]
        [Route("{id:int}/comentarios")]
        public IHttpActionResult Comentar(int id, TareaComentarioAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("COMENTAR TAREA");
                ExigirCliente();
                ExigirCuerpo(dto);

                int nuevo = Datos.Ejecutar("API_INS_TAREA_COMENTARIO",
                    new Dictionary<string, object>
                    {
                        { "@OCURRENCIA", id },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@TEXTO", dto.texto },
                        { "@PADRE", dto.padre },
                        { "@DICTADO_UUID", dto.dictado_uuid },
                        { "@TEXTO_DICTADO", dto.texto_dictado },
                        { "@DICTADO_CONFIANZA", dto.dictado_confianza },
                        { "@DICTADO_SEGUNDOS", dto.dictado_segundos },
                        { "@DICTADO_INTENTOS", dto.dictado_intentos },
                        { "@DISPOSITIVO", dto.dispositivo }
                    }, true);

                return Creado(nuevo);
            });
        }

        // ------------------------------------------------------------------

        private List<TareaComentarioDto> Comentarios(int ocurrencia)
        {
            return Datos.Listar<TareaComentarioDto>(
                "API_SEL_TAREA_COMENTARIO",
                new Dictionary<string, object>
                {
                    { "@USUARIO", SesionApi.UsuarioId() },
                    { "@CLIENTE", SesionApi.ClienteId() },
                    { "@ID", ocurrencia }
                });
        }
    }
}
