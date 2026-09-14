using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Fallas: qué se rompió, qué se encontró y cómo se reparó.   HU-123 · HU-110
    ///
    /// TRES HILOS, NO UNA FICHA GRANDE
    ///   La falla es la ficha; los diagnósticos y las acciones son hilos que
    ///   se agregan y no se editan. El SP decide cuál diagnóstico es el
    ///   definitivo (desmarca los anteriores) y cuándo la falla queda resuelta
    ///   (la primera acción definitiva fija fal_fecha_solucion_utc). La web
    ///   y la app llaman a los mismos SP, así que llegan al mismo veredicto.
    ///
    /// EL ESTADO DEL EQUIPO CAMBIA AL REGISTRAR
    ///   Si la falla trae estado_posterior, INS_FALLA llama a
    ///   ACTIVO_CAMBIAR_ESTADO y queda en el historial del equipo con la
    ///   falla como motivo. No se cambia dos veces: después la ficha no lo
    ///   permite editar.
    ///
    /// LA ORDEN NACE DEL SP
    ///   POST /fallas/{id}/orden llama a INS_ORDEN_TRABAJO con @FALLA: origen
    ///   FALLA, correctiva de emergencia, prioridad = criticidad de la falla.
    /// </summary>
    [RoutePrefix("fallas")]
    public class FallasController : ApiBase
    {
        /// <summary>
        /// GET /fallas — listado. `abiertas`: true solo sin solución, false solo
        /// resueltas, vacío todas. PROVISORIAS_DEL_EQUIPO cuenta las reparaciones
        /// provisorias del mismo equipo: dos o más es un equipo que pide atención.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int? activo = null, int? instalacion = null, bool? abiertas = null, string filtro = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER ORDENES TRABAJO");
                ExigirCliente();
                return Ok(Datos.Listar<FallaDto>("SEL_FALLA", new Dictionary<string, object>
                {
                    { "@CLIENTE", SesionApi.ClienteId() },
                    { "@ACTIVO", activo },
                    { "@INSTALACION", instalacion },
                    { "@ABIERTAS", abiertas },
                    { "@FILTRO", filtro }
                }));
            });
        }

        /// <summary>GET /fallas/{id} — la ficha con sus contadores.</summary>
        /// <response code="404">No existe o es de otro cliente.</response>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Obtener(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER ORDENES TRABAJO");
                ExigirCliente();
                List<FallaDto> l = Datos.Listar<FallaDto>("SEL_FALLA", new Dictionary<string, object> { { "@CLIENTE", SesionApi.ClienteId() }, { "@ID", id } });
                if (l.Count == 0) return NoEncontrado("La falla " + id);
                return Ok(l[0]);
            });
        }

        /// <summary>POST /fallas — registrar una falla.</summary>
        /// <response code="201">Creada. Si trae estado_posterior el equipo ya cambió de estado.</response>
        /// <response code="400">Equipo de otro cliente, criticidad fuera de catálogo o título vacío.</response>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(FallaAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("REGISTRAR FALLA");
                ExigirCliente();
                ExigirUsuario();
                ExigirCuerpo(dto);

                int id = Datos.Ejecutar("INS_FALLA", new Dictionary<string, object>
                {
                    { "@CLIENTE", SesionApi.ClienteId() },
                    { "@ACTIVO", dto.activo },
                    { "@ACTIVO_COMPONENTE", dto.componente },
                    { "@FALLA_SINTOMA", dto.sintoma },
                    { "@CRITICIDAD_NIVEL", dto.criticidad ?? 2 },
                    { "@TITULO", dto.titulo },
                    { "@DESCRIPCION", dto.descripcion },
                    { "@CONSECUENCIA", dto.consecuencia },
                    { "@ESTADO_POSTERIOR", dto.estado_posterior },
                    { "@DETUVO_PRODUCCION", dto.detuvo_produccion },
                    { "@FECHA_DETECCION_UTC", dto.fecha_deteccion_utc },
                    { "@USUARIO", SesionApi.UsuarioId() },
                    { "@UUID", dto.uuid }
                }, true);

                return Creado(id);
            });
        }

        /// <summary>PUT /fallas/{id} — corregir título, descripción, consecuencia, criticidad o detuvo producción.</summary>
        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Actualizar(int id, FallaEdicionDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("REGISTRAR FALLA");
                ExigirCliente();
                ExigirUsuario();
                ExigirCuerpo(dto);

                Datos.Ejecutar("UPD_FALLA", new Dictionary<string, object>
                {
                    { "@ID", id },
                    { "@CLIENTE", SesionApi.ClienteId() },
                    { "@TITULO", dto.titulo },
                    { "@DESCRIPCION", dto.descripcion },
                    { "@CONSECUENCIA", dto.consecuencia },
                    { "@CRITICIDAD_NIVEL", dto.criticidad },
                    { "@DETUVO_PRODUCCION", dto.detuvo_produccion },
                    { "@QUITA_SOLUCION", false },
                    { "@USUARIO", SesionApi.UsuarioId() }
                });
                return Ok(new { fal_id = id });
            });
        }

        /// <summary>GET /fallas/{id}/diagnosticos — el hilo, el definitivo primero.</summary>
        [HttpGet]
        [Route("{id:int}/diagnosticos")]
        public IHttpActionResult Diagnosticos(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER ORDENES TRABAJO");
                ExigirCliente();
                return Ok(Datos.Listar<FallaDiagnosticoDto>("SEL_FALLA_DIAGNOSTICO", new Dictionary<string, object> { { "@CLIENTE", SesionApi.ClienteId() }, { "@FALLA", id } }));
            });
        }

        /// <summary>POST /fallas/{id}/diagnosticos — agrega un diagnóstico; `es_definitivo` desmarca los anteriores.</summary>
        [HttpPost]
        [Route("{id:int}/diagnosticos")]
        public IHttpActionResult AgregarDiagnostico(int id, FallaDiagnosticoAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("REGISTRAR FALLA");
                ExigirCliente();
                ExigirUsuario();
                ExigirCuerpo(dto);

                int nuevo = Datos.Ejecutar("INS_FALLA_DIAGNOSTICO", new Dictionary<string, object>
                {
                    { "@CLIENTE", SesionApi.ClienteId() },
                    { "@FALLA", id },
                    { "@FALLA_MODO", dto.modo },
                    { "@FALLA_CAUSA", dto.causa },
                    { "@DIAGNOSTICO_METODO", dto.metodo },
                    { "@DESCRIPCION", dto.descripcion ?? "" },
                    { "@ES_DEFINITIVO", dto.es_definitivo },
                    { "@CONFIANZA", dto.confianza },
                    { "@USUARIO", SesionApi.UsuarioId() },
                    { "@UUID", dto.uuid }
                }, true);
                return Creado(nuevo);
            });
        }

        /// <summary>GET /fallas/{id}/acciones — qué se hizo, en orden.</summary>
        [HttpGet]
        [Route("{id:int}/acciones")]
        public IHttpActionResult Acciones(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER ORDENES TRABAJO");
                ExigirCliente();
                return Ok(Datos.Listar<FallaAccionDto>("SEL_FALLA_ACCION", new Dictionary<string, object> { { "@CLIENTE", SesionApi.ClienteId() }, { "@FALLA", id } }));
            });
        }

        /// <summary>POST /fallas/{id}/acciones — provisoria mantiene la falla abierta; definitiva la resuelve.</summary>
        /// <response code="400">La falla ya está resuelta, o la orden no es de esta falla.</response>
        [HttpPost]
        [Route("{id:int}/acciones")]
        public IHttpActionResult AgregarAccion(int id, FallaAccionAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("REGISTRAR FALLA");
                ExigirCliente();
                ExigirUsuario();
                ExigirCuerpo(dto);

                int nuevo = Datos.Ejecutar("INS_FALLA_ACCION", new Dictionary<string, object>
                {
                    { "@CLIENTE", SesionApi.ClienteId() },
                    { "@FALLA", id },
                    { "@FALLA_DIAGNOSTICO", dto.diagnostico },
                    { "@ORDEN_TRABAJO", dto.orden_trabajo },
                    { "@DESCRIPCION", dto.descripcion ?? "" },
                    { "@ES_DEFINITIVA", dto.es_definitiva },
                    { "@FECHA_ACCION_UTC", dto.fecha_accion_utc },
                    { "@USUARIO", SesionApi.UsuarioId() },
                    { "@UUID", dto.uuid }
                }, true);
                return Creado(nuevo);
            });
        }

        /// <summary>
        /// POST /fallas/{id}/orden — abre la correctiva de emergencia de esta falla.
        /// Origen FALLA, prioridad = criticidad; equipo y componente los de la falla.
        /// </summary>
        /// <response code="201">La orden nueva.</response>
        /// <response code="400">La falla no existe o ya está resuelta.</response>
        [HttpPost]
        [Route("{id:int}/orden")]
        public IHttpActionResult GenerarOrden(int id, FallaOrdenDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("CREAR ORDEN TRABAJO");
                ExigirCliente();
                ExigirUsuario();
                if (dto == null) dto = new FallaOrdenDto();

                List<FallaDto> l = Datos.Listar<FallaDto>("SEL_FALLA", new Dictionary<string, object> { { "@CLIENTE", SesionApi.ClienteId() }, { "@ID", id } });
                if (l.Count == 0) return NoEncontrado("La falla " + id);
                FallaDto f = l[0];
                if (f.FAL_FECHA_SOLUCION_UTC != null) throw new ArgumentException("La falla ya está resuelta; no corresponde abrir otra orden.");

                int orden = Datos.Ejecutar("INS_ORDEN_TRABAJO", new Dictionary<string, object>
                {
                    { "@CLIENTE", SesionApi.ClienteId() },
                    { "@CLIENTE_INSTALACION", f.ACTIVO_INSTALACION },
                    { "@ACTIVO", f.FAL_ACTIVO },
                    { "@ACTIVO_COMPONENTE", f.FAL_ACTIVO_COMPONENTE },
                    { "@TIPO", 2 },
                    { "@ESTRATEGIA", dto.estrategia ?? 3 },
                    { "@PRIORIDAD", f.FAL_CRITICIDAD_NIVEL },
                    { "@TITULO", "Falla: " + f.FAL_TITULO },
                    { "@DESCRIPCION", f.FAL_DESCRIPCION },
                    { "@FECHA_PROGRAMADA_UTC", dto.fecha_programada_utc },
                    { "@DURACION_ESTIMADA_MINUTO", dto.duracion_estimada_minuto },
                    { "@REQUIERE_PERMISO", dto.requiere_permiso },
                    { "@REGISTRO_POSTERIOR", false },
                    { "@FALLA", id },
                    { "@USUARIO", SesionApi.UsuarioId() }
                }, true);

                return Creado(orden);
            });
        }
    }
}
