using API.MVC.Model;
using API.Utils;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// SIGMA AI · el análisis predictivo.                  HU-173 y HU-175
    ///
    /// QUE HAY DETRAS DE ESTOS NUMEROS
    ///   Un modelo de línea base: una regresión lineal sobre las lecturas de
    ///   una variable, proyectada hasta el límite declarado del equipo. No
    ///   aprende, no tiene pesos, no se entrena. Lo que sí tiene es que cada
    ///   número se puede rastrear hasta las lecturas que lo produjeron, y por
    ///   eso la ficha devuelve el modelo, su versión, su algoritmo y los datos
    ///   que usó: quien decide desarmar una máquina por esto tiene derecho a
    ///   saber qué se lo dijo.
    ///
    /// EL VACIO ES INFORMACION, NO UN ERROR
    ///   Un panel sin predicciones puede significar tres cosas distintas —no
    ///   hay equipos vigilados, hay pero nadie los mide, o se miden y están
    ///   tranquilos— y quien lo mira necesita saber cuál. Por eso
    ///   `/vigilados` devuelve los equipos con el motivo de su silencio en vez
    ///   de una lista vacía.
    ///
    /// NUNCA EN AFIRMATIVO
    ///   Ningún texto de acá dice que un equipo va a fallar. Dice que una
    ///   variable medida va a cruzar un límite declarado **si la tendencia se
    ///   mantiene**, que es lo único que el modelo puede sostener.
    /// </summary>
    [RoutePrefix("predicciones")]
    public class PrediccionesController : ApiBase
    {
        /// <summary>
        /// GET /predicciones — las vigentes, la más urgente primero.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Panel(int? instalacion = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();

                return Ok(Datos.Listar<PrediccionDto>(
                    "API_SEL_PREDICCION", Parametros(1, null, instalacion)));
            });
        }

        /// <summary>
        /// GET /predicciones/vigilados — los equipos que se miran y no dijeron
        /// nada, con el motivo del silencio.
        /// </summary>
        [HttpGet]
        [Route("vigilados")]
        public IHttpActionResult Vigilados(int? instalacion = null)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();

                return Ok(Datos.Listar<VigiladoDto>(
                    "API_SEL_PREDICCION", Parametros(5, null, instalacion)));
            });
        }

        /// <summary>
        /// GET /predicciones/{id} — la ficha completa.
        ///
        /// Las razones, los datos usados y la serie viajan en la misma
        /// respuesta: la pantalla no se puede dibujar sin ellos, y cuatro
        /// viajes de red para una vista en terreno es una vista que no se abre.
        /// </summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Ficha(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();

                List<PrediccionFichaDto> cab = Datos.Listar<PrediccionFichaDto>(
                    "API_SEL_PREDICCION", Parametros(2, id));

                if (cab.Count == 0) return NoEncontrado("La predicción no existe.");

                PrediccionFichaDto ficha = cab[0];
                ficha.razones = Datos.Listar<PrediccionRazonDto>(
                    "API_SEL_PREDICCION", Parametros(3, id));
                ficha.datos = Datos.Listar<PrediccionDatoDto>(
                    "API_SEL_PREDICCION", Parametros(4, id));
                ficha.serie = Datos.Listar<PrediccionPuntoDto>(
                    "API_SEL_PREDICCION", Parametros(6, id));

                return Ok(ficha);
            });
        }

        /// <summary>
        /// POST /predicciones/{id}/revision — reconocer o descartar.
        ///
        /// Descartar exige motivo. Una predicción descartada sin explicación no
        /// se puede aprender: quien después revise si el modelo sirve necesita
        /// saber si fue un falso positivo, si el equipo igual se iba a cambiar,
        /// o si simplemente nadie le creyó. Las tres llevan a decisiones
        /// distintas sobre el modelo.
        /// </summary>
        /// <response code="200">Revisada. `YA_ESTABA` avisa si era un reenvío.</response>
        /// <response code="400">Falta el motivo, o ya se convirtió en orden de trabajo.</response>
        [HttpPost]
        [Route("{id:int}/revision")]
        public IHttpActionResult Revisar(int id, PrediccionRevisionDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("VER PREDICCIONES");
                ExigirCliente();
                ExigirCuerpo(dto);

                List<PrediccionRevisionResultadoDto> r =
                    Datos.Listar<PrediccionRevisionResultadoDto>(
                        "API_UPD_PREDICCION_REVISION",
                        new Dictionary<string, object>
                        {
                            { "@ID", id },
                            { "@USUARIO", SesionApi.UsuarioId() },
                            { "@CLIENTE", SesionApi.ClienteId() },
                            { "@ACEPTAR", dto.aceptar },
                            { "@MOTIVO", dto.motivo }
                        });

                return Ok(r.Count > 0 ? r[0] : new PrediccionRevisionResultadoDto());
            });
        }

        /// <summary>
        /// POST /predicciones/{id}/orden-trabajo — abre la OT predictiva.
        ///
        /// Se llama con la **alerta**, no con la predicción: el SP que ya
        /// existía (`INS_ORDEN_TRABAJO_DESDE_PREDICCION`) parte de ahí, y con
        /// razón —generar la orden también cambia el estado de la alerta y deja
        /// el rastro en `Alerta_Historial`—. Una predicción bajo el umbral no
        /// tiene alerta y por eso no se puede convertir: primero hay que
        /// creerle.
        /// </summary>
        /// <response code="201">Creada, o la que ya existía.</response>
        /// <response code="400">La predicción no generó alerta.</response>
        [HttpPost]
        [Route("{id:int}/orden-trabajo")]
        public IHttpActionResult GenerarOrden(int id)
        {
            return Ejecutar(() =>
            {
                ExigirPermiso("GENERAR OT PREDICCION");
                ExigirCliente();

                List<PrediccionFichaDto> cab = Datos.Listar<PrediccionFichaDto>(
                    "API_SEL_PREDICCION", Parametros(2, id));

                if (cab.Count == 0) return NoEncontrado("La predicción no existe.");

                if (cab[0].ALERTA_ID == null)
                    return BadRequest("Esta predicción no llegó al umbral de alerta, "
                                    + "así que no hay desde dónde abrir la orden.");

                int orden = Datos.Ejecutar("INS_ORDEN_TRABAJO_DESDE_PREDICCION",
                    new Dictionary<string, object>
                    {
                        { "@ALERTA", cab[0].ALERTA_ID.Value },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                return Creado(orden);
            });
        }

        // ------------------------------------------------------------------

        private Dictionary<string, object> Parametros(
            int tipo, int? id = null, int? instalacion = null)
        {
            return new Dictionary<string, object>
            {
                { "@USUARIO", SesionApi.UsuarioId() },
                { "@CLIENTE", SesionApi.ClienteId() },
                { "@TIPO", tipo },
                { "@ID", id },
                { "@INSTALACION", instalacion }
            };
        }
    }
}
