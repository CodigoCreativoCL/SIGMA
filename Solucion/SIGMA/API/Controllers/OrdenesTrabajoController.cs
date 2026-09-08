using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Órdenes de trabajo para terreno.
    ///                            HU-110, HU-113, HU-114, HU-119, HU-121
    ///
    /// LA BANDEJA ES EL PUNTO DE PARTIDA DEL TURNO
    ///   El técnico abre la app y lo primero que necesita es qué le toca hoy.
    ///   Por eso `GET /ordenes-trabajo` trae ya resueltos el avance de pasos
    ///   y la situación —VENCIDA, VENCE HOY, EN PLAZO—: el teléfono no tiene
    ///   que restar fechas ni contar pasos para pintar la lista.
    ///
    /// LA SITUACION LA DECIDE EL SP, NO EL TELEFONO
    ///   Si la calculara la app, dos teléfonos con distinta hora darían
    ///   veredictos distintos sobre la misma orden, y el que va atrasado
    ///   creería que está en plazo.
    ///
    /// EL AMBITO SEPARA "LO MIO" DE "LO QUE PUEDO TOMAR"
    ///   `ambito=1` son mis órdenes; `ambito=2`, las abiertas sin dueño. Son
    ///   dos preguntas distintas y la segunda es la que permite que un
    ///   técnico que terminó antes tome trabajo disponible en vez de irse.
    ///
    /// TOMAR RESUELVE LA CARRERA EN LA BASE
    ///   Dos técnicos que tocan "Tomar" a la vez llegan los dos al SP, y el
    ///   UPDATE con `AND estado = 1` deja pasar a uno solo. El otro recibe un
    ///   409, no un duplicado. Resolverlo leyendo antes de escribir habría
    ///   dejado la ventana abierta entre la lectura y la escritura.
    /// </summary>
    [RoutePrefix("ordenes-trabajo")]
    public class OrdenesTrabajoController : ApiBase
    {
        /// <summary>
        /// GET /ordenes-trabajo — la bandeja.                      HU-121
        ///
        /// `ambito`: 1 mías, 2 disponibles para tomar, 3 todas mis plantas.
        /// `desde`: para la sincronización incremental de la app.
        /// </summary>
        /// <response code="200">El listado, ordenado por lo vencido y lo más prioritario.</response>
        /// <response code="403">Sin el permiso de ver órdenes.</response>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int ambito = 1, int? instalacion = null,
                                        DateTime? desde = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER ORDENES TRABAJO");
                ExigirCliente();

                List<OrdenTrabajoDto> todo = Datos.Listar<OrdenTrabajoDto>(
                    "API_SEL_ORDEN_TRABAJO",
                    new Dictionary<string, object>
                    {
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@TIPO", 1 },
                        { "@AMBITO", ambito },
                        { "@INSTALACION", instalacion },
                        { "@DESDE", desde }
                    });

                return Ok(todo);
            });
        }

        /// <summary>
        /// GET /ordenes-trabajo/{id} — la ficha con sus pasos.
        ///
        /// Cabecera y pasos en **una** llamada: son dos consultas para el
        /// servidor y un solo viaje de red para el teléfono, que es lo que
        /// importa con señal de bodega.
        /// </summary>
        /// <response code="200">La orden con sus pasos.</response>
        /// <response code="404">No existe, o no es de una planta autorizada.</response>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Obtener(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER ORDENES TRABAJO");
                ExigirCliente();

                List<OrdenTrabajoDto> cabecera = Datos.Listar<OrdenTrabajoDto>(
                    "API_SEL_ORDEN_TRABAJO",
                    Parametros(id, 2));

                if (cabecera.Count == 0) return NoEncontrado("La orden de trabajo no existe.");

                List<OrdenTrabajoPasoDto> pasos = Datos.Listar<OrdenTrabajoPasoDto>(
                    "API_SEL_ORDEN_TRABAJO",
                    Parametros(id, 3));

                List<OrdenTrabajoAsignadoDto> asignados = Datos.Listar<OrdenTrabajoAsignadoDto>(
                    "API_SEL_ORDEN_TRABAJO",
                    Parametros(id, 4));

                OrdenTrabajoFichaDto ficha = new OrdenTrabajoFichaDto
                {
                    orden = cabecera[0],
                    pasos = pasos,
                    asignados = asignados
                };

                return Ok(ficha);
            });
        }

        /// <summary>
        /// POST /ordenes-trabajo — crea una correctiva desde terreno. HU-110
        ///
        /// Idempotente por `uuid`. El teléfono lo genera **al encolar**, no al
        /// enviar: generado al enviar, cada reintento traería uno nuevo y esta
        /// protección no serviría de nada, que es justo el caso del timeout.
        /// </summary>
        /// <response code="201">Creada, o ya existía con ese uuid. Devuelve el id en los dos casos.</response>
        /// <response code="400">Sin título, o el activo no es de esa instalación.</response>
        /// <response code="403">La instalación no está autorizada para esta persona.</response>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(OrdenTrabajoAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("CREAR ORDEN TRABAJO");
                ExigirCliente();
                ExigirCuerpo(dto);

                int id = Datos.Ejecutar("API_INS_ORDEN_TRABAJO",
                    new Dictionary<string, object>
                    {
                        { "@UUID", dto.uuid },
                        // Del token, nunca del cuerpo: si viniera de fuera,
                        // cualquiera con un token válido crearía órdenes a
                        // nombre de otro y la auditoría diría lo que el
                        // atacante quiso.
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@INSTALACION", dto.instalacion },
                        { "@TITULO", dto.titulo },
                        { "@DESCRIPCION", dto.descripcion },
                        { "@ACTIVO", dto.activo },
                        { "@AREA", dto.area },
                        { "@TIPO", dto.tipo },
                        { "@ESTRATEGIA", dto.estrategia },
                        { "@PRIORIDAD", dto.prioridad },
                        { "@FECHA_EVENTO_UTC", dto.fecha_evento_utc },
                        { "@REQUIERE_PERMISO", dto.requiere_permiso },
                        { "@PASOS", dto.pasos },
                        { "@ENTRADA_MODO", dto.entrada_modo }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>
        /// POST /ordenes-trabajo/{id}/tomar — el técnico se hace cargo. HU-113
        /// </summary>
        /// <response code="200">Tomada. Queda EN EJECUCION y con responsable.</response>
        /// <response code="409">Otro la tomó primero, o no está abierta.</response>
        [HttpPost]
        [Route("{id:int}/tomar")]
        public IHttpActionResult Tomar(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("TOMAR ORDEN TRABAJO");
                ExigirCliente();

                Datos.Ejecutar("UPD_ORDEN_TRABAJO_TOMAR",
                    new Dictionary<string, object>
                    {
                        { "@OTR_ID", id },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(new { otr_id = id });
            });
        }

        /// <summary>
        /// POST /ordenes-trabajo/pasos/{id} — completa un paso.     HU-114
        ///
        /// Idempotente por paso: reenviar el mismo resultado no duplica ni
        /// falla, responde lo mismo. Es el caso del reintento de la cola.
        /// </summary>
        /// <response code="200">Completado, o ya estaba con ese resultado.</response>
        /// <response code="400">La orden no está en ejecución.</response>
        /// <response code="403">No estás asignado a esa orden.</response>
        [HttpPost]
        [Route("pasos/{id:int}")]
        public IHttpActionResult CompletarPaso(int id, PasoResultadoDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("EJECUTAR ORDEN TRABAJO");
                ExigirCliente();
                ExigirCuerpo(dto);

                Datos.Ejecutar("API_UPD_ORDEN_TRABAJO_PASO",
                    new Dictionary<string, object>
                    {
                        { "@OTP_ID", id },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@RESULTADO_PASO", dto.resultado },
                        { "@OBSERVACION", dto.observacion },
                        { "@ENTRADA_MODO", dto.entrada_modo }
                    });

                return Ok(new { otp_id = id });
            });
        }

        /// <summary>
        /// POST /ordenes-trabajo/{id}/finalizar — el técnico terminó. HU-119
        ///
        /// Deja la orden EN ESPERA DE CIERRE, no CERRADA: el cierre es del
        /// planificador o del supervisor, y esa separación es la que hace que
        /// el registro sirva como respaldo.
        /// </summary>
        /// <response code="200">Finalizada. Queda en espera de cierre.</response>
        /// <response code="400">Faltan pasos obligatorios, o ya no estaba en ejecución.</response>
        [HttpPost]
        [Route("{id:int}/finalizar")]
        public IHttpActionResult Finalizar(int id, OrdenTrabajoFinDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("EJECUTAR ORDEN TRABAJO");
                ExigirCliente();

                Datos.Ejecutar("UPD_ORDEN_TRABAJO_FINALIZAR",
                    new Dictionary<string, object>
                    {
                        { "@ORDEN_TRABAJO", id },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@OBSERVACION", dto == null ? null : dto.resultado }
                    });

                return Ok(new { otr_id = id });
            });
        }

        /// <summary>
        /// GET /ordenes-trabajo/{id}/recursos — mano de obra y repuestos.
        ///
        /// Los dos en una respuesta: en la ficha se miran juntos —cuánto se
        /// trabajó y qué se usó— y separarlos serían dos viajes de red para
        /// pintar una sola pestaña.
        /// </summary>
        /// <response code="200">Mano de obra y repuestos de la orden.</response>
        /// <response code="403">La orden no está en una planta autorizada.</response>
        [HttpGet]
        [Route("{id:int}/recursos")]
        public IHttpActionResult Recursos(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER ORDENES TRABAJO");
                ExigirCliente();

                List<ManoObraDto> mano = Datos.Listar<ManoObraDto>(
                    "API_SEL_ORDEN_TRABAJO_RECURSO", ParametrosRecurso(id, 1));

                List<OrdenTrabajoRepuestoDto> repuestos =
                    Datos.Listar<OrdenTrabajoRepuestoDto>(
                        "API_SEL_ORDEN_TRABAJO_RECURSO", ParametrosRecurso(id, 2));

                return Ok(new RecursosDto { mano_obra = mano, repuestos = repuestos });
            });
        }

        /// <summary>
        /// POST /ordenes-trabajo/{id}/mano-obra — registra un tramo. HU-115
        ///
        /// Sin mano de obra no hay MTTR ni carga por persona. El tramo es un
        /// **hecho**: la tabla no tiene baja lógica y este endpoint no tiene
        /// edición — una corrección se hace agregando otro tramo.
        /// </summary>
        /// <response code="201">Registrado. Devuelve el id.</response>
        /// <response code="400">El término es anterior al inicio, o el tramo supera 24 h.</response>
        [HttpPost]
        [Route("{id:int}/mano-obra")]
        public IHttpActionResult ManoObra(int id, ManoObraAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("EJECUTAR ORDEN TRABAJO");
                ExigirCliente();
                ExigirCuerpo(dto);

                int nuevo = Datos.Ejecutar("API_INS_ORDEN_TRABAJO_MANO_OBRA",
                    new Dictionary<string, object>
                    {
                        { "@OTR_ID", id },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@FECHA_INICIO", dto.fecha_inicio_utc },
                        { "@FECHA_FIN", dto.fecha_fin_utc },
                        { "@MINUTOS", dto.minutos },
                        { "@ESPECIALIDAD", dto.especialidad },
                        { "@ES_HORA_EXTRA", dto.es_hora_extra },
                        { "@OBSERVACION", dto.observacion },
                        // De quién es el tramo. Nulo = de quien lo registra,
                        // que es el caso normal en terreno.
                        { "@USUARIO_TRAMO", dto.usuario_tramo }
                    }, true);

                return Creado(nuevo);
            });
        }

        /// <summary>
        /// GET /ordenes-trabajo/{id}/repuestos-disponibles — que se puede
        /// consumir, y que de eso SIRVE para el equipo.
        ///
        /// POR QUE NO SE REUSA /existencias
        ///
        ///   Aquel listado es de la planta y no sabe nada de esta orden. La
        ///   pregunta acá es otra: «de lo que hay en bodega, que le calza a
        ///   ESTE equipo». Un rodamiento 6205 y uno 6310 se ven casi iguales
        ///   en una lista, y el que se equivoca lo descubre abajo, con el
        ///   equipo abierto y la pieza que no calza en la mano.
        /// </summary>
        [HttpGet]
        [Route("{id:int}/repuestos-disponibles")]
        public IHttpActionResult RepuestosDisponibles(int id, string filtro = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("EJECUTAR ORDEN TRABAJO");
                ExigirCliente();

                List<RepuestoOrdenDto> r = Datos.Listar<RepuestoOrdenDto>(
                    "API_SEL_APP_REPUESTO_ORDEN",
                    new Dictionary<string, object>
                    {
                        { "@OTR_ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@FILTRO", filtro }
                    });

                return Ok(r ?? new List<RepuestoOrdenDto>());
            });
        }

        /// <summary>
        /// POST /ordenes-trabajo/{id}/repuestos — consume o devuelve. HU-116
        ///
        /// **Mueve el inventario.** Registrar el consumo sin descontar del
        /// saldo dejaría la bodega mintiendo: el sistema diría que hay diez
        /// rodamientos y en el estante habría nueve. Las dos escrituras
        /// ocurren en la misma transacción del SP de inventario.
        ///
        /// `es_devolucion` invierte el gesto: el técnico sacó tres y usó dos,
        /// y el tercero vuelve al estante. Sin eso, el activo carga un costo
        /// que no tuvo y la bodega tiene una unidad fantasma.
        /// </summary>
        /// <response code="200">Movido. Devuelve el acumulado de la línea.</response>
        /// <response code="400">Sin saldo suficiente, o la bodega exige ubicación.</response>
        [HttpPost]
        [Route("{id:int}/repuestos")]
        public IHttpActionResult Repuestos(int id, OrdenTrabajoRepuestoAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("EJECUTAR ORDEN TRABAJO");
                ExigirCliente();
                ExigirCuerpo(dto);

                Datos.Ejecutar("API_INS_ORDEN_TRABAJO_REPUESTO",
                    new Dictionary<string, object>
                    {
                        { "@OTR_ID", id },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@REPUESTO", dto.repuesto },
                        { "@BODEGA", dto.bodega },
                        { "@CANTIDAD", dto.cantidad },
                        { "@UBICACION", dto.ubicacion },
                        { "@LOTE", dto.lote },
                        { "@ES_DEVOLUCION", dto.es_devolucion },
                        { "@OBSERVACION", dto.observacion },
                        { "@UUID", dto.uuid }
                    });

                return Ok(new { otr_id = id });
            });
        }

        /// <summary>
        /// Los parámetros de las consultas de recursos.
        /// </summary>
        private Dictionary<string, object> ParametrosRecurso(int id, int tipo)
        {
            return new Dictionary<string, object>
            {
                { "@USUARIO", SesionApi.UsuarioId() },
                { "@CLIENTE", SesionApi.ClienteId() },
                { "@OTR_ID", id },
                { "@TIPO", tipo }
            };
        }

        /// <summary>
        /// Los parámetros comunes de las tres consultas de la ficha.
        /// </summary>
        private Dictionary<string, object> Parametros(int id, int tipo)
        {
            return new Dictionary<string, object>
            {
                { "@USUARIO", SesionApi.UsuarioId() },
                { "@CLIENTE", SesionApi.ClienteId() },
                { "@TIPO", tipo },
                { "@OTR_ID", id }
            };
        }
    }
}
