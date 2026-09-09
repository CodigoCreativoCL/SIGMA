using API.MVC.Model;
using API.Services;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Net;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Fotos de evidencia desde el teléfono.
    ///
    /// POR QUE NO USA /archivo
    ///   Ese endpoint se autentica con `X-Api-Key` porque atiende a un
    ///   SERVIDOR: la web guardando lo que subió alguien que ya se autenticó
    ///   contra la web. Éste atiende a una PERSONA con su token de sesión, y
    ///   además tiene que dejar la fila y el vínculo —`/archivo` solo sube el
    ///   blob—. Meter las dos autenticaciones en un controlador sería tener
    ///   que razonar en cada método cuál de las dos aplica.
    ///
    /// EL BLOB VA PRIMERO, LA FILA DESPUES
    ///   Si el blob falla, no se escribe nada. Si la fila falla, queda un blob
    ///   huérfano que se puede recolectar. Al revés quedaría una fila
    ///   apuntando a nada: alguien abre la foto meses después y no hay
    ///   imagen, sin ninguna señal de que se perdió.
    ///
    /// EL UUID LO PONE EL TELEFONO AL SACAR LA FOTO
    ///   No al enviarla. Una foto tomada sin señal se reintenta varias veces;
    ///   sin esto, la tarea quedaría con la misma foto cuatro veces y nadie
    ///   sabría cuál mirar.
    /// </summary>
    [RoutePrefix("evidencias")]
    public class EvidenciasController : ApiBase
    {
        /// <summary>
        /// El tope. Una foto de teléfono ronda 1–4 MB; 12 deja aire de sobra y
        /// corta el envío accidental de un video, que este camino no sabe
        /// manejar y llenaría el contenedor sin que nadie lo note.
        /// </summary>
        private const int MaxBytes = 12 * 1024 * 1024;

        /* UN VIDEO NO CABE EN LO QUE CABE UNA FOTO

           Doce megas alcanzan de sobra para una foto de terreno y para una nota
           de voz de varios minutos, pero no para un video: treinta segundos de
           camara de telefono pasan facil de veinte megas, y rechazarlo despues
           de haberlo subido por la red de una planta es el peor momento para
           decirlo.

           Cuarenta y ocho megas en base64 son unos sesenta y cuatro, y
           Web.config admite doscientos (maxRequestLength=204800 KB), asi que el
           tope de la infraestructura no se toca. */
        private const int MaxBytesVideo = 48 * 1024 * 1024;

        /// <summary>
        /// El tope segun lo que se sube. Un video puede pesar cuatro veces mas
        /// que una foto.
        /// </summary>
        private static int TopeDe(string mime)
        {
            return (mime ?? "").ToLowerInvariant().StartsWith("video/")
                ? MaxBytesVideo
                : MaxBytes;
        }

        /// <summary>
        /// Cada destino se cubre con el permiso de lo que se está haciendo.
        /// Un permiso propio de «subir fotos» sería una llave paralela: quien
        /// no puede ejecutar la tarea tampoco tiene por qué colgarle
        /// evidencia, y quien sí puede no debería necesitar un permiso extra.
        /// </summary>
        private static readonly Dictionary<string, string> PermisoDe =
            new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                { "TAREA",     "EJECUTAR TAREA" },
                { "ORDEN",     "EJECUTAR ORDEN TRABAJO" },
                { "PASO",      "EJECUTAR ORDEN TRABAJO" },
                { "RESPUESTA", "EJECUTAR CHECKLIST" },
                { "HALLAZGO",  "EJECUTAR CHECKLIST" },
                { "FALLA",     "EJECUTAR ORDEN TRABAJO" },
                { "ACTIVO",    "VER ACTIVOS" },

                /* La anotacion de bitacora tambien lleva evidencia, y es donde
                   mas hace falta: se escribe delante de la fuga, no despues.
                   `avi_bitacora` existia desde el principio; lo que faltaba
                   era esta linea y la rama de los dos SP (BD/198). */
                { "BITACORA",  "REGISTRAR BITACORA" }
            };

        /// <summary>
        /// POST /evidencias — sube la foto y la cuelga de algo.
        /// </summary>
        /// <response code="201">Registrada, o la que ya estaba si era un reenvío.</response>
        /// <response code="400">Destino desconocido, contenido vacío o no base64.</response>
        /// <response code="503">El almacenamiento no está disponible.</response>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Subir(EvidenciaAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirCliente();
                ExigirCuerpo(dto);

                string permiso;
                if (dto.destino == null || !PermisoDe.TryGetValue(dto.destino, out permiso))
                    return BadRequest("Ese destino de evidencia no existe.");

                ExigirPermiso(permiso);

                // «Archivo» y no «foto»: por acá entran tambien notas de voz
                // y videos, y un mensaje que habla de fotos manda a buscar el
                // problema donde no está.
                if (string.IsNullOrEmpty(dto.contenido_base64))
                    return BadRequest("El archivo está vacío.");

                byte[] contenido;
                try
                {
                    contenido = Convert.FromBase64String(dto.contenido_base64);
                }
                catch (FormatException)
                {
                    // Se distingue de la foto vacía a propósito: son dos
                    // problemas distintos y el mismo mensaje manda a buscar en
                    // el lugar equivocado.
                    return BadRequest("El contenido no es base64 válido.");
                }

                if (contenido.Length == 0)
                    return BadRequest("El archivo está vacío.");

                int tope = TopeDe(dto.mime);

                if (contenido.Length > tope)
                    return BadRequest("El archivo pesa demasiado. El máximo son " +
                                      (tope / (1024 * 1024)) + " MB.");

                BlobService blob = new BlobService();

                if (!blob.Disponible)
                    return Content(HttpStatusCode.ServiceUnavailable,
                        new ErrorApi { codigo = 503, mensaje = blob.Motivo, esDeNegocio = false });

                // El nombre almacenado es el uuid: dos personas fotografiando
                // el mismo filtro en el mismo minuto no pueden pisarse, y el
                // nombre que trae el teléfono («IMG_0042.jpg») se repite todos
                // los días.
                string extension = Extension(dto.mime);
                string almacenado = dto.uuid.ToString("N") + "." + extension;

                /* LA RUTA LLEVA EL CLIENTE, COMO LA DE LA WEB

                   Antes era «sigma/bitacora/archivo.m4a»: sin cliente, todas
                   las empresas mezcladas en la misma carpeta. La intranet
                   guarda bajo la carpeta de la empresa desde siempre, asi que
                   ademas eran dos estructuras distintas en el mismo
                   contenedor.

                   No es orden, es aislamiento: con el cliente arriba, un SAS
                   acotado a un prefijo deja fuera a las demas empresas con una
                   sola regla. Sin el no hay prefijo que acotar.

                   Lo ya subido no se mueve: su ruta vive en Archivo.arc_ruta y
                   se sigue encontrando donde esta. */
                string ruta = RutaArchivo.Armar(
                    "sigma",
                    SesionApi.ClienteId(),
                    NombreDelCliente(),
                    dto.destino.ToLowerInvariant(),
                    almacenado,
                    DateTime.Now);

                ResultadoBlob subido = blob.Subir(ruta, contenido, dto.mime);

                int id = Datos.Ejecutar("API_INS_EVIDENCIA",
                    new Dictionary<string, object>
                    {
                        { "@UUID", dto.uuid },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@DESTINO", dto.destino },
                        { "@DESTINO_ID", dto.destino_id },
                        { "@CATEGORIA", dto.categoria },
                        { "@NOMBRE_ORIGINAL", dto.nombre ?? almacenado },
                        { "@NOMBRE_ALMACENADO", almacenado },
                        { "@RUTA", subido.ruta },
                        { "@MIME", dto.mime },
                        { "@EXTENSION", extension },
                        { "@BYTE", subido.tamano },
                        { "@HASH", subido.hash },
                        { "@ANCHO", dto.ancho },
                        { "@ALTO", dto.alto },
                        { "@LATITUD", dto.latitud },
                        { "@LONGITUD", dto.longitud },
                        { "@CAPTURA_UTC", dto.captura_utc },
                        { "@DISPOSITIVO", dto.dispositivo },
                        { "@TITULO", dto.titulo },
                        { "@DESCRIPCION", dto.descripcion }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>
        /// GET /evidencias?destino=TAREA&amp;destino_id=8 — las fotos de algo.
        ///
        /// Devuelve la **ruta**, no los bytes. El teléfono pide cada imagen
        /// después por `/archivo/ver` y la cachea; mandarlas dentro de la
        /// ficha haría que abrir una tarea con seis fotos costara seis megas
        /// en terreno.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(string destino = null, int destino_id = 0)
        {
            return Ejecutar(() =>
            {
                ExigirCliente();

                string permiso;
                if (destino == null || !PermisoDe.TryGetValue(destino, out permiso))
                    return BadRequest("Ese destino de evidencia no existe.");

                ExigirPermiso(permiso);

                List<EvidenciaDto> fotos = Datos.Listar<EvidenciaDto>(
                    "API_SEL_EVIDENCIA",
                    new Dictionary<string, object>
                    {
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@DESTINO", destino },
                        { "@DESTINO_ID", destino_id }
                    });

                return Ok(fotos);
            });
        }

        /// <summary>
        /// La extensión sale del mime y no del nombre que manda el teléfono:
        /// un nombre lo escribe quien llama y puede traer cualquier cosa,
        /// incluido un `.aspx`.
        /// </summary>
        /// <summary>
        /// El nombre de la empresa del token, para la carpeta legible.
        ///
        /// Se consulta y se cachea corto: se usa en cada subida y es un dato
        /// que no cambia en el dia. Si no se puede leer, la carpeta queda solo
        /// con el id —«0001»—, que es feo pero sigue aislando, que es lo que
        /// de verdad importa.
        /// </summary>
        private static string NombreDelCliente()
        {
            int cliente = SesionApi.ClienteId();
            if (cliente <= 0) return "";

            try
            {
                return CacheCorta.Obtener(
                    CacheCorta.Clave("clientenombre", 0, cliente, ""),
                    () =>
                    {
                        List<ClienteElegibleDto> r = Datos.Listar<ClienteElegibleDto>(
                            "API_SEL_APP_CLIENTE",
                            new Dictionary<string, object>
                            {
                                { "@USUARIO", SesionApi.UsuarioId() }
                            });

                        if (r == null) return "";

                        for (int i = 0; i < r.Count; i++)
                            if (r[i].cli_id == cliente) return r[i].cli_nombre ?? "";

                        return "";
                    });
            }
            catch (Exception)
            {
                return "";
            }
        }

        private static string Extension(string mime)
        {
            switch ((mime ?? "").ToLowerInvariant())
            {
                case "image/png": return "png";
                case "image/webp": return "webp";
                case "image/heic": return "heic";

                /* AUDIO Y VIDEO

                   La extension importa: el navegador y el reproductor del
                   telefono eligen el decodificador por ella cuando el servidor
                   de blobs no manda un Content-Type util, y un .jpg que en
                   realidad es un .m4a no se abre en ninguna parte.

                   m4a y mp4 son lo que graban Android y iOS por omision; los
                   demas entran porque un archivo elegido de la galeria puede
                   venir de cualquier sitio. */
                case "audio/mp4":
                case "audio/m4a":
                case "audio/x-m4a": return "m4a";
                case "audio/aac": return "aac";
                case "audio/mpeg": return "mp3";
                case "audio/ogg": return "ogg";
                case "audio/wav":
                case "audio/x-wav": return "wav";

                case "video/mp4": return "mp4";
                case "video/quicktime": return "mov";
                case "video/3gpp": return "3gp";
                case "video/webm": return "webm";

                default: return "jpg";
            }
        }
    }
}
