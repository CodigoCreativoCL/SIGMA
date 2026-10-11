using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// La galería de evidencias para la app (HU-142, T-5254 y T-5255).
    ///
    /// MISMO SP QUE LA WEB
    ///   SEL_ARCHIVO_VINCULO (BD/434, RUTA desde BD/436) sirve las dos galerías de la
    ///   historia: la de una orden (por paso y momento) y la de un equipo (todas sus
    ///   órdenes, por fecha). Las referencias de HU-143 vienen marcadas con
    ///   ES_REFERENCIA y primero. Si la app armara su propia consulta, a la primera
    ///   regla nueva (otra categoría que excluir, otro destino) las dos galerías
    ///   empezarían a mostrar cosas distintas.
    ///
    /// LA RUTA, NO LOS BYTES
    ///   Como GET /evidencias: cada imagen se pide después por /archivo/ver?ruta=...,
    ///   que vuelve a exigir que la ruta sea del cliente de la sesión.
    ///
    /// PERMISO DE LO QUE SE MIRA
    ///   La galería de una orden pide VER ORDENES TRABAJO y la de un equipo VER
    ///   ACTIVOS: las mismas llaves que abren esas fichas. Un permiso propio de «ver
    ///   evidencias» sería una puerta lateral a lo que esas dos protegen.
    /// </summary>
    [RoutePrefix("archivo-vinculos")]
    public class ArchivoVinculosController : ApiBase
    {
        /// <summary>
        /// Treinta segundos y no el minuto de permisos o catálogos: aquí lo que cambia es
        /// el contenido. Un técnico que sube una foto y abre la galería la ve, como mucho,
        /// medio minuto después; y abrir la misma galería varias veces seguidas (volver
        /// desde el visor, girar el teléfono) no va a la base cada vez.
        /// </summary>
        private const int SEGUNDOS_CACHE = 30;

        private static readonly HashSet<string> Momentos =
            new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "ANTES", "DURANTE", "DESPUES", "OTRO", "REFERENCIA" };

        /// <summary>
        /// GET /archivo-vinculos?orden_trabajo=1 — galería de una orden.
        /// GET /archivo-vinculos?activo=10 — galería de un equipo.
        /// Filtros: momento (ANTES | DURANTE | DESPUES | OTRO | REFERENCIA), solo_imagenes,
        /// incluir_referencias. Paginado: pagina (desde 1) y tamano (50 por omisión, tope 200).
        /// </summary>
        /// <response code="200">La página pedida, con el total sin paginar.</response>
        /// <response code="400">Falta orden_trabajo o activo, o el momento no existe.</response>
        /// <response code="403">Sin el permiso de la ficha que se quiere mirar.</response>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int orden_trabajo = 0, int activo = 0, string momento = null,
                                        bool solo_imagenes = false, bool incluir_referencias = true,
                                        int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO)
        {
            return Ejecutar(() =>
            {
                ExigirCliente();

                if (orden_trabajo <= 0 && activo <= 0)
                    return BadRequest("Indica la orden de trabajo o el activo de la galería.");

                if (!string.IsNullOrEmpty(momento) && !Momentos.Contains(momento))
                    return BadRequest("El momento debe ser ANTES, DURANTE, DESPUES, OTRO o REFERENCIA.");

                // Si llegan los dos manda la orden, igual que en el SP.
                ExigirPermiso(orden_trabajo > 0 ? "VER ORDENES TRABAJO" : "VER ACTIVOS");

                Pagina p = new Pagina { pagina = pagina, tamano = tamano };
                int usuario = SesionApi.UsuarioId();
                int cliente = SesionApi.ClienteId();

                // Todo lo que cambia la respuesta va en la clave; usuario y cliente siempre (CacheCorta).
                string extra = string.Join(":", orden_trabajo, orden_trabajo > 0 ? 0 : activo,
                                           (momento ?? "").ToUpperInvariant(), solo_imagenes ? 1 : 0,
                                           incluir_referencias ? 1 : 0, p.pagina, p.tamano);

                List<ArchivoVinculoDto> filas = CacheCorta.Obtener(
                    CacheCorta.Clave("archivo-vinculos", usuario, cliente, extra),
                    () => Datos.Listar<ArchivoVinculoDto>("SEL_ARCHIVO_VINCULO",
                        new Dictionary<string, object>
                        {
                            { "@CLIENTE", cliente },
                            { "@ORDEN_TRABAJO", orden_trabajo > 0 ? (object)orden_trabajo : null },
                            { "@ACTIVO", activo > 0 ? (object)activo : null },
                            { "@MOMENTO", string.IsNullOrEmpty(momento) ? null : momento.ToUpperInvariant() },
                            { "@SOLO_IMAGENES", solo_imagenes },
                            { "@INCLUIR_REFERENCIAS", incluir_referencias },
                            { "@PAGINA", p.pagina },
                            { "@TAMANO", p.tamano }
                        }),
                    SEGUNDOS_CACHE);

                if (filas == null) filas = new List<ArchivoVinculoDto>();

                // El SP pagina y repite el total en cada fila; una página vacía no lo trae.
                int total = filas.Count > 0 ? filas[0].TOTAL : 0;

                return Ok(Paginado<ArchivoVinculoDto>.DeServidor(filas, total, p));
            });
        }
    }
}
