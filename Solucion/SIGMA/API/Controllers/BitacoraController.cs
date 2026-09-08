using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// La bitácora de planta.                              HU-130 y HU-131
    ///
    /// LO QUE SE ESCRIBIO NO SE REESCRIBE
    ///   `Bitacora` no tiene `habilitado` ni auditoría de actualización. No es
    ///   un olvido del modelo: es su decisión. Una bitácora es el relato de lo
    ///   que pasó en el turno, y un relato editable deja de servir como
    ///   relato —sobre todo el día que alguien tenga que explicar por qué se
    ///   quemó un motor—. Por eso acá hay POST y no hay PUT ni DELETE.
    ///
    /// RECTIFICAR ES ESCRIBIR, NO BORRAR
    ///   Una rectificación es una fila nueva con el texto corregido y **el
    ///   motivo, obligatorio**. La entrada original queda intacta y la ficha
    ///   la muestra siempre. Se pueden encadenar: vale la última, se ven
    ///   todas.
    ///
    /// SOLO EL AUTOR RECTIFICA
    ///   Lo resuelve el SP contra `bit_usuario_creacion`, y no es un permiso:
    ///   un permiso de «rectificar cualquier entrada» sería la llave para
    ///   reescribir el relato ajeno, que es justo lo que este módulo existe
    ///   para impedir. Un tercero que tenga algo que agregar, comenta.
    ///
    /// SE ESCRIBE SIN SEÑAL
    ///   Idempotente por `uuid`, generado en el teléfono al empezar a
    ///   escribir. Si naciera en el envío, un reintento de la cola dejaría el
    ///   turno contado dos veces — y en una bitácora eso no es un duplicado
    ///   molesto, es un relato que se contradice.
    /// </summary>
    [RoutePrefix("bitacora")]
    public class BitacoraController : ApiBase
    {
        /// <summary>
        /// GET /bitacora — la línea de tiempo.
        ///
        /// Ordenada por la fecha del **evento**, no la de creación: una
        /// entrada escrita sin señal a las tres de la mañana y subida a las
        /// nueve pertenece a la noche.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Linea(
            int? instalacion = null, int? activo = null, int? area = null,
            DateTime? desde = null, bool atencion = false,
            int pagina = 1, int tamano = 30)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER BITACORA");
                ExigirCliente();

                List<BitacoraEntradaDto> lista = Datos.Listar<BitacoraEntradaDto>(
                    "API_SEL_BITACORA",
                    new Dictionary<string, object>
                    {
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@TIPO", 1 },
                        { "@INSTALACION", instalacion },
                        { "@ACTIVO", activo },
                        { "@AREA", area },
                        { "@DESDE", desde },
                        { "@SOLO_ATENCION", atencion },
                        { "@PAGINA", pagina },
                        { "@TAMANO", tamano }
                    });

                // El `Paginado` se arma a mano y no con `Paginado.Armar`:
                // ese pagina en memoria sobre la lista completa, y acá el SP
                // ya paginó en SQL con OFFSET/FETCH y devolvió el total en
                // `COUNT(*) OVER ()`. Volver a cortar recortaría la página.
                int total = lista.Count > 0 ? lista[0].TOTAL : 0;

                return Ok(new Paginado<BitacoraEntradaDto>
                {
                    pagina = pagina < 1 ? 1 : pagina,
                    tamano = tamano,
                    total = total,
                    paginas = tamano > 0 ? (total + tamano - 1) / tamano : 0,
                    datos = lista
                });
            });
        }

        /// <summary>
        /// GET /bitacora/tipos — observación, novedad, incidente, cambio de
        /// turno, hallazgo.
        /// </summary>
        [HttpGet]
        [Route("tipos")]
        public IHttpActionResult Tipos()
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER BITACORA");
                ExigirCliente();

                return Ok(Datos.Listar<BitacoraTipoDto>(
                    "API_SEL_BITACORA", Parametros(5)));
            });
        }

        /// <summary>
        /// GET /bitacora/{id} — la entrada con su hilo y sus rectificaciones.
        ///
        /// Devuelve el texto original **y** el vigente. La pantalla muestra
        /// los dos: el original tachado o plegado, y encima la última versión
        /// con el motivo del cambio. Mandar solo el vigente ahorraría bytes y
        /// perdería exactamente lo que este módulo protege.
        /// </summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Ficha(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER BITACORA");
                ExigirCliente();

                List<BitacoraFichaDto> cab = Datos.Listar<BitacoraFichaDto>(
                    "API_SEL_BITACORA", Parametros(2, id));

                if (cab.Count == 0) return NoEncontrado("La entrada no existe.");

                BitacoraFichaDto f = cab[0];
                f.comentarios = Datos.Listar<BitacoraComentarioDto>(
                    "API_SEL_BITACORA", Parametros(3, id));
                f.rectificaciones = Datos.Listar<BitacoraRectificacionDto>(
                    "API_SEL_BITACORA", Parametros(4, id));

                return Ok(f);
            });
        }

        /// <summary>
        /// POST /bitacora — escribe una entrada.
        /// </summary>
        /// <response code="201">Escrita, o la que ya estaba si era un reenvío.</response>
        /// <response code="400">Texto vacío, planta no autorizada, o incidente sin severidad.</response>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Escribir(BitacoraAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("REGISTRAR BITACORA");
                ExigirCliente();
                ExigirCuerpo(dto);

                int id = Datos.Ejecutar("API_INS_BITACORA",
                    new Dictionary<string, object>
                    {
                        { "@UUID", dto.uuid },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@INSTALACION", dto.instalacion },
                        { "@TIPO", dto.tipo },
                        { "@TEXTO", dto.texto },
                        { "@TITULO", dto.titulo },
                        { "@AREA", dto.area },
                        { "@ACTIVO", dto.activo },
                        { "@COMPONENTE", dto.componente },
                        { "@ORDEN_TRABAJO", dto.orden_trabajo },
                        { "@FECHA_EVENTO", dto.fecha_evento },
                        { "@TURNO", dto.turno },
                        { "@REQUIERE_ATENCION", dto.requiere_atencion },
                        { "@SEVERIDAD", dto.severidad },
                        { "@LATITUD", dto.latitud },
                        { "@LONGITUD", dto.longitud },
                        { "@OFFLINE", dto.offline },
                        { "@DICTADO_UUID", dto.dictado_uuid },
                        { "@TEXTO_DICTADO", dto.texto_dictado },
                        { "@DICTADO_CONFIANZA", dto.dictado_confianza },
                        { "@DICTADO_SEGUNDOS", dto.dictado_segundos },
                        { "@DISPOSITIVO", dto.dispositivo }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>
        /// POST /bitacora/{id}/rectificaciones — corrige, sin borrar.
        ///
        /// El motivo es obligatorio. Sin él, quien lea la bitácora después no
        /// puede saber si el texto cambió porque estaba mal escrito, porque se
        /// supo algo nuevo, o porque a alguien no le gustó cómo sonaba: las
        /// tres cosas se leen muy distinto.
        /// </summary>
        /// <response code="201">Rectificada. El original sigue disponible.</response>
        /// <response code="400">Falta el motivo, el texto es el mismo, o no eres quien la escribió.</response>
        [HttpPost]
        [Route("{id:int}/rectificaciones")]
        public IHttpActionResult Rectificar(int id, BitacoraRectificacionAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("REGISTRAR BITACORA");
                ExigirCliente();
                ExigirCuerpo(dto);

                int nuevo = Datos.Ejecutar("API_INS_BITACORA_RECTIFICACION",
                    new Dictionary<string, object>
                    {
                        { "@BITACORA", id },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@TEXTO", dto.texto },
                        { "@MOTIVO", dto.motivo }
                    }, true);

                return Creado(nuevo);
            });
        }

        /// <summary>
        /// POST /bitacora/{id}/comentarios — agrega al hilo.
        ///
        /// Esto sí lo puede hacer un tercero: agregar es de cualquiera,
        /// corregir el relato es de quien lo escribió.
        /// </summary>
        [HttpPost]
        [Route("{id:int}/comentarios")]
        public IHttpActionResult Comentar(int id, BitacoraComentarioAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("REGISTRAR BITACORA");
                ExigirCliente();
                ExigirCuerpo(dto);

                int nuevo = Datos.Ejecutar("API_INS_BITACORA_COMENTARIO",
                    new Dictionary<string, object>
                    {
                        { "@BITACORA", id },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@TEXTO", dto.texto },
                        { "@PADRE", dto.padre },
                        { "@DICTADO_UUID", dto.dictado_uuid },
                        { "@TEXTO_DICTADO", dto.texto_dictado },
                        { "@DICTADO_CONFIANZA", dto.dictado_confianza },
                        { "@DICTADO_SEGUNDOS", dto.dictado_segundos },
                        { "@DISPOSITIVO", dto.dispositivo }
                    }, true);

                return Creado(nuevo);
            });
        }

        // ------------------------------------------------------------------

        private Dictionary<string, object> Parametros(int tipo, int? id = null)
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
