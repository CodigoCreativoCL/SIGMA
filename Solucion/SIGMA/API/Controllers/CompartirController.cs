using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Compartir un trabajo con un compañero, y sumarse al de otro.
    ///
    /// QUE RESUELVE
    ///
    ///   Un tecnico abre un motor y ve que no lo saca solo: necesita al
    ///   electrico, o a alguien que sostenga mientras desmonta. Hoy eso se
    ///   arregla por telefono o gritando en la planta, y no queda registrado:
    ///   la orden termina firmada por uno solo aunque la hicieron dos.
    ///
    /// EL AVISO ENTRA POR LA BANDEJA QUE YA EXISTE
    ///
    ///   `Alerta` tiene badge, no-leidas, pantalla y push previsto. Una bandeja
    ///   aparte para «lo que me compartieron» seria un segundo sitio donde
    ///   mirar, y lo que no se mira no sirve de aviso.
    ///
    /// UNIRSE ES UN TRAMO DE MANO DE OBRA, NO UNA REASIGNACION
    ///
    ///   El responsable de la orden no cambia: quien se suma **participa**. Por
    ///   eso «unirme» escribe en la mano de obra con `@USUARIO_TRAMO`, que es
    ///   como el modelo ya representa «este rato lo trabajo otra persona».
    ///   Reasignar la orden le quitaria el trabajo a quien lo pidio.
    /// </summary>
    [RoutePrefix("compartir")]
    public class CompartirController : ApiBase
    {
        /// <summary>
        /// GET /compartir/companeros?instalacion=3 — con quien se puede.
        ///
        /// Salen de `Cliente_Instalacion_Usuario`, la MISMA regla que usan la
        /// sabana, las plantas y el contexto. Compartir con alguien que no
        /// trabaja en esa planta es mandarle un aviso sobre un equipo que no
        /// puede tocar.
        /// </summary>
        [HttpGet]
        [Route("companeros")]
        public IHttpActionResult Companeros(int instalacion = 0, string filtro = null,
                                            string perfiles = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                if (instalacion <= 0)
                    return BadRequest("Falta la instalación del trabajo.");

                List<CompaneroDto> r = Datos.Listar<CompaneroDto>("API_SEL_APP_COMPANERO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@INSTALACION", instalacion },
                        { "@FILTRO", filtro },

                        /* QUIENES PUEDEN ESTAR EN UN TRABAJO

                           Sin esto salian TODOS los usuarios de la planta, el
                           gerente comercial y el administrador incluidos, que
                           no van a estar delante de la maquina. Lo elige la
                           app y no el SP porque las dos hojas —sumar compañero
                           y compartir— pueden pedir conjuntos distintos.

                           Se sanea antes de pasarlo: es una lista de numeros y
                           entra en un LIKE dentro del SP. Cualquier cosa que
                           no sean digitos y comas se descarta. */
                        { "@PERFILES", SoloIdsDePerfil(perfiles) }
                    });

                return Ok(r ?? new List<CompaneroDto>());
            });
        }

        /// <summary>
        /// Deja solo digitos y comas, y descarta el resto.
        ///
        /// El parametro viaja hasta un LIKE del SP. Aunque `Datos` lo manda
        /// parametrizado —no hay concatenacion, asi que no hay inyeccion—, un
        /// valor con basura devolveria una lista vacia sin explicar por que.
        /// Saneado, o filtra bien o no filtra.
        /// </summary>
        private static string SoloIdsDePerfil(string crudo)
        {
            if (string.IsNullOrWhiteSpace(crudo)) return null;

            List<string> ids = new List<string>();

            foreach (string parte in crudo.Split(','))
            {
                int id;
                if (int.TryParse(parte.Trim(), out id) && id > 0)
                    ids.Add(id.ToString());
            }

            /* SI PIDIO FILTRAR Y NADA ERA VALIDO, NO SE DEVUELVE A TODOS

               Devolver null aca seria «sin filtro», o sea que un parametro con
               basura ampliaria la lista en vez de reducirla. En algo que decide
               a quien se le puede mandar un trabajo, equivocarse hacia el lado
               permisivo es el peor de los dos. Se responde con un id que no es
               de nadie: lista vacia, y se nota. */
            return ids.Count == 0 ? "0" : string.Join(",", ids);
        }

        /// <summary>
        /// POST /compartir — deja el aviso en la bandeja del compañero.
        ///
        /// El titulo lo arma el SP y no la app: «Ramiro te compartio OT-1»
        /// tiene que decir lo mismo venga del telefono de quien sea.
        /// </summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Compartir(CompartirAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                if (dto == null)
                    return BadRequest("Falta el cuerpo de la petición.");

                if (dto.destinatario <= 0)
                    return BadRequest("Falta con quién compartir.");

                int id = Datos.Ejecutar("API_INS_COMPARTIR",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@DESTINATARIO", dto.destinatario },
                        { "@ENTIDAD", dto.entidad },
                        { "@ENTIDAD_ID", dto.entidad_id },
                        { "@MENSAJE", dto.mensaje },
                        { "@UUID", dto.uuid }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>
        /// POST /compartir/unirme — sumarse a una orden como participante.
        ///
        /// POR QUE ABRE UN TRAMO EN CERO Y NO REGISTRA TIEMPO
        ///
        ///   Unirse es decir «voy para alla», no «ya trabaje veinte minutos».
        ///   El tramo se abre con la hora de ahora y sin minutos; el tiempo lo
        ///   pone despues el cronometro de la app al cerrar. Registrar tiempo
        ///   al unirse inflaria toda orden que alguien mire y abandone.
        /// </summary>
        [HttpPost]
        [Route("unirme")]
        public IHttpActionResult Unirme(UnirmeDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirPermiso("EJECUTAR ORDEN TRABAJO");

                if (dto == null || dto.orden_trabajo <= 0)
                    return BadRequest("Falta la orden a la que unirse.");

                int id = Datos.Ejecutar("API_INS_ORDEN_TRABAJO_MANO_OBRA",
                    new Dictionary<string, object>
                    {
                        { "@OTR_ID", dto.orden_trabajo },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@FECHA_INICIO", DateTime.UtcNow },
                        { "@FECHA_FIN", null },
                        { "@MINUTOS", null },
                        { "@ESPECIALIDAD", null },
                        { "@ES_HORA_EXTRA", false },
                        { "@OBSERVACION", "Se unió desde un trabajo compartido." },
                        { "@UUID", dto.uuid },
                        /* Nulo = el tramo es de quien lo registra, que es
                           exactamente lo que significa unirse. */
                        { "@USUARIO_TRAMO", null }
                    }, true);

                return Creado(id);
            });
        }
    }
}
