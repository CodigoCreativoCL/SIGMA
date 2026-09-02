using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Permisos de trabajo: el papel que habilita una faena de riesgo.
    ///                                                              HU-063
    ///
    /// ESTE MODULO ES DE TERRENO
    ///   El permiso se registra donde se va a trabajar, con el teléfono, y
    ///   se consulta ahí mismo antes de empezar. Por eso el alta es
    ///   idempotente y la consulta trae la situación ya calculada: el
    ///   teléfono no tiene que restar fechas para saber si el permiso sirve.
    ///
    /// LA SITUACION NO SE GUARDA, SE CALCULA
    ///   El catálogo tiene un estado VENCIDO, pero un estado guardado
    ///   envejece solo: un permiso que venció anoche seguiría diciendo
    ///   AUTORIZADO hasta que alguien corriera un proceso. `SITUACION` sale
    ///   del SP contra la fecha de hoy, así que una app que quedó con datos
    ///   viejos en la mano los ve viejos, no equivocados.
    ///
    /// AUTORIZADO EXIGE EL DOCUMENTO FIRMADO
    ///   Lo impone `CK_PTR_AUTORIZADO` en la tabla, no este controller. Un
    ///   alta con estado AUTORIZADO y sin `archivo` se rechaza con un 400
    ///   que lo explica, no con un 500 del constraint.
    /// </summary>
    [RoutePrefix("permisos-trabajo")]
    public class PermisosTrabajoController : ApiBase
    {
        /// <summary>
        /// GET /permisos-trabajo — el listado.                     T-3223
        ///
        /// `situacion` filtra por lo que de verdad importa en terreno:
        /// "¿qué está por vencer?" es la pregunta, no "¿en qué estado está?".
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, int? tipo = null,
                                        int? estado = null, string situacion = null,
                                        int? orden_trabajo = null, int dias_aviso = 7)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER PERMISOS TRABAJO");
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<PermisoTrabajoDto> todo = Datos.Listar<PermisoTrabajoDto>(
                    "SEL_PERMISO_TRABAJO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@ID", null },
                        { "@ORDEN_TRABAJO", orden_trabajo },
                        { "@TIPO", tipo },
                        { "@ESTADO", estado },
                        { "@SITUACION", string.IsNullOrEmpty(situacion) ? null : situacion.ToUpper() },
                        { "@HABILITADO", true },
                        { "@FILTRO", p.filtro },
                        { "@DIAS_AVISO", dias_aviso }
                    });

                return Ok(Paginado<PermisoTrabajoDto>.Armar(todo, p));
            });
        }

        /// <summary>
        /// GET /permisos-trabajo/vigentes — lo que está vigente y lo que
        /// está por vencer.                                 HU-064 · T-3313
        ///
        /// LA PREGUNTA QUE SE HACE EN TERRENO
        ///   "No descubrir en terreno que el permiso caducó." Por eso el
        ///   orden es **lo vencido primero**, después lo que menos días le
        ///   queda: es el orden en que hay que atenderlos, no el del
        ///   calendario.
        ///
        ///   Lo CERRADO y lo que no tiene vigencia declarada quedan fuera:
        ///   no son parte de esta pregunta.
        ///
        /// CACHE DE UN MINUTO                                       T-3314
        ///   La app la consulta al abrir la pantalla, y varias personas de
        ///   la misma cuadrilla preguntan lo mismo al empezar el turno. El
        ///   dato cambia cuando alguien registra o autoriza un permiso: en
        ///   un minuto de desfase nadie se queda sin saber que su permiso
        ///   venció, porque **los días se recalculan contra la fecha de hoy
        ///   en cada consulta**, no se guardan.
        ///
        ///   La clave incluye el cliente y los filtros: sin eso, la
        ///   respuesta de una empresa se le serviría a la siguiente.
        /// </summary>
        [HttpGet]
        [Route("vigentes")]
        public IHttpActionResult Vigentes(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                          string filtro = null, int? tipo = null,
                                          int dias_aviso = 7, bool incluir_vencidos = true,
                                          bool solo_por_vencer = false)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER PERMISOS TRABAJO");
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                string clave = "permisos-vigentes-" + SesionApi.ClienteId() +
                               "-" + dias_aviso + "-" + (tipo ?? 0) +
                               "-" + (incluir_vencidos ? 1 : 0) + (solo_por_vencer ? 1 : 0) +
                               "-" + (p.filtro ?? "");

                List<PermisoVigenteDto> todo = CacheCorta.Obtener(clave, () =>
                    Datos.Listar<PermisoVigenteDto>(
                        "SEL_PERMISO_TRABAJO_VIGENTE",
                        new Dictionary<string, object>
                        {
                            { "@CLIENTE", SesionApi.ClienteId() },
                            { "@DIAS_AVISO", dias_aviso },
                            { "@TIPO", tipo },
                            { "@INCLUIR_VENCIDOS", incluir_vencidos },
                            { "@SOLO_POR_VENCER", solo_por_vencer },
                            { "@FILTRO", p.filtro }
                        }));

                return Ok(Paginado<PermisoVigenteDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /permisos-trabajo/{id} — el detalle.        T-3223</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER PERMISOS TRABAJO");
                ExigirCliente();

                List<PermisoTrabajoDto> r = Datos.Listar<PermisoTrabajoDto>(
                    "SEL_PERMISO_TRABAJO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@ID", id },
                        { "@ORDEN_TRABAJO", null }, { "@TIPO", null }, { "@ESTADO", null },
                        { "@SITUACION", null }, { "@HABILITADO", null }, { "@FILTRO", null },
                        { "@DIAS_AVISO", 7 }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("El permiso de trabajo");

                return Ok(r[0]);
            });
        }

        /// <summary>
        /// POST /permisos-trabajo — registra el permiso.            T-3222
        ///
        /// IDEMPOTENTE POR uuid
        ///   Se registra en terreno, con la red de una planta: la app manda,
        ///   se corta, y no sabe si llegó. Si reintenta con el mismo uuid, el
        ///   SP devuelve el id que ya existía sin crear un segundo permiso
        ///   para la misma faena.
        ///
        ///   Sin esto el prevencionista vería duplicados y no sabría cuál
        ///   firmó. Y si el reintento fallara por una regla, la app mostraría
        ///   un error por algo que sí se había guardado.
        ///
        ///   El uuid lo genera el TELEFONO. Si no viene, el alta funciona
        ///   igual pero deja de ser reintentable: se acepta porque un
        ///   cliente que no puede generar uno —una prueba con curl— no tiene
        ///   por qué quedar afuera.
        /// </summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(PermisoTrabajoAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirCuerpo(dto);
                ExigirPermiso("REGISTRAR PERMISO TRABAJO");
                ExigirCliente();
                ExigirUsuario();

                if (dto.tipo <= 0)
                    throw new ArgumentException("Indique el tipo de permiso.");

                /* Se comprueba ACA lo que la tabla va a impedir igual, para
                   poder decirlo: dejar que salte CK_PTR_AUTORIZADO devuelve
                   un error de constraint que no le sirve a nadie. */
                if (dto.archivo == null && EsAutorizado(dto.estado))
                    throw new ArgumentException(
                        "Un permiso autorizado necesita el documento firmado adjunto. " +
                        "Regístrelo como solicitado y autorícelo cuando pueda adjuntarlo.");

                if (dto.vigencia_inicio != null && dto.vigencia_fin != null &&
                    dto.vigencia_fin < dto.vigencia_inicio)
                    throw new ArgumentException("La vigencia termina antes de empezar.");

                int id = Datos.Ejecutar("INS_PERMISO_TRABAJO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@TIPO", dto.tipo },
                        { "@ESTADO", dto.estado },
                        { "@NUMERO", dto.numero },
                        { "@ORDEN_TRABAJO", dto.orden_trabajo },
                        { "@SOLICITANTE", dto.solicitante },
                        { "@VIGENCIA_INICIO", dto.vigencia_inicio },
                        { "@VIGENCIA_FIN", dto.vigencia_fin },
                        { "@OBSERVACION", dto.observacion },
                        { "@ARCHIVO", dto.archivo },
                        { "@UUID", dto.uuid },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>
        /// PUT /permisos-trabajo/{id} — corrige el registro.
        ///
        /// Solo mientras el estado lo permita: SOLICITADO y AUTORIZADO se
        /// corrigen; RECHAZADO, VENCIDO y CERRADO no. Son el final de la
        /// historia de ese permiso, y editarlos reescribiría lo que ya quedó
        /// como constancia. El SP lo rechaza con su mensaje.
        /// </summary>
        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Editar(int id, PermisoTrabajoAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirCuerpo(dto);
                ExigirPermiso("REGISTRAR PERMISO TRABAJO");
                ExigirCliente();
                ExigirUsuario();

                if (dto.vigencia_inicio != null && dto.vigencia_fin != null &&
                    dto.vigencia_fin < dto.vigencia_inicio)
                    throw new ArgumentException("La vigencia termina antes de empezar.");

                Datos.Ejecutar("UPD_PERMISO_TRABAJO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@TIPO", dto.tipo > 0 ? (object)dto.tipo : null },
                        { "@ESTADO", dto.estado },
                        { "@NUMERO", dto.numero },
                        { "@ORDEN_TRABAJO", dto.orden_trabajo },
                        { "@SOLICITANTE", dto.solicitante },
                        { "@VIGENCIA_INICIO", dto.vigencia_inicio },
                        { "@VIGENCIA_FIN", dto.vigencia_fin },
                        { "@OBSERVACION", dto.observacion },
                        { "@ARCHIVO", dto.archivo },
                        { "@HABILITADO", null },
                        { "@QUITA_ORDEN", false },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id, mensaje = "Permiso de trabajo actualizado." });
            });
        }

        /// <summary>
        /// GET /permisos-trabajo/tipos — el catálogo para el formulario.
        ///
        /// La app no puede traer los seis tipos escritos adentro: salen del
        /// reglamento y una empresa puede agregar los suyos. Una lista
        /// quemada en el teléfono obliga a publicar una versión nueva cada
        /// vez que cambie.
        /// </summary>
        [HttpGet]
        [Route("tipos")]
        public IHttpActionResult Tipos()
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER PERMISOS TRABAJO");
                ExigirCliente();

                return Ok(Datos.Listar<PermisoTrabajoTipoDto>("SEL_PERMISO_TRABAJO_TIPO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@HABILITADO", true }
                    }));
            });
        }

        /// <summary>GET /permisos-trabajo/estados — el otro catálogo.</summary>
        [HttpGet]
        [Route("estados")]
        public IHttpActionResult Estados()
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER PERMISOS TRABAJO");
                ExigirCliente();

                return Ok(Datos.Listar<PermisoTrabajoEstadoDto>("SEL_PERMISO_TRABAJO_ESTADO",
                    new Dictionary<string, object> { { "@HABILITADO", true } }));
            });
        }

        /// <summary>
        /// Si el estado pedido es AUTORIZADO.
        ///
        /// Se resuelve contra la base y no contra un 2 escrito acá: el id del
        /// estado es un dato del catálogo, y un número quemado en el código
        /// es correcto hasta el día que alguien reordene la tabla.
        /// </summary>
        private bool EsAutorizado(int? estado)
        {
            if (estado == null || estado.Value <= 0) return false;

            List<PermisoTrabajoEstadoDto> estados = Datos.Listar<PermisoTrabajoEstadoDto>(
                "SEL_PERMISO_TRABAJO_ESTADO",
                new Dictionary<string, object> { { "@HABILITADO", true } });

            if (estados == null) return false;

            foreach (PermisoTrabajoEstadoDto e in estados)
                if (e.PTE_ID == estado.Value)
                    return string.Equals(e.PTE_CODIGO, "AUTORIZADO", StringComparison.OrdinalIgnoreCase);

            return false;
        }
    }
}
