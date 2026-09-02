using API.Services;
using API.Utils;
using System;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>Lo que la web manda para subir un archivo.</summary>
    public class ArchivoSubidaDto
    {
        public string ruta { get; set; }
        public string nombre_original { get; set; }
        public string mime { get; set; }
        public string contenido_base64 { get; set; }
    }


    /// <summary>
    /// Guardar y recuperar archivos en Azure Blob Storage.
    ///
    /// POR QUE PASA POR ACA Y NO SUBE LA WEB DIRECTO
    ///
    ///   Decisión del 29-08: **un solo camino hacia el almacenamiento**. La
    ///   web y la app móvil tienen que escribir en el mismo sitio con las
    ///   mismas reglas; dos caminos distintos garantizan que algún día un
    ///   archivo quede en un contenedor que la otra mitad no mira.
    ///
    ///   Y el SAS vive **solo acá**. Si la web hablara con Azure, la
    ///   credencial estaría también en el servidor web, y rotarla obligaría a
    ///   tocar dos configuraciones en vez de una.
    ///
    /// AUTENTICACION POR X-Api-Key, NO POR JWT
    ///
    ///   El resto de la API atiende a una PERSONA con su token de sesión.
    ///   Este endpoint atiende a un SERVIDOR: la web guarda el comprobante
    ///   que subió un usuario, y ese usuario ya se autenticó contra la web.
    ///   Exigirle además un JWT de la API obligaría a la web a mantener una
    ///   sesión de servicio, que es un mecanismo más para que se caiga.
    ///
    ///   La clave se compara en tiempo constante: comparar con == permite
    ///   deducirla carácter a carácter midiendo cuánto tarda en responder.
    ///
    /// EL CONTRATO LO FIJO LA WEB, NO ESTE CONTROLLER
    ///
    ///   `AlmacenamientoApi` (Web/Intranet/App_Code/SitioBase/Almacenamiento.cs)
    ///   ya estaba escrito esperando estas tres rutas exactas. Se respeta al
    ///   pie de la letra para no tener que tocar el cliente:
    ///
    ///     POST   /archivo          { ruta, nombre_original, mime, contenido_base64 }
    ///                              -> { ruta, hash, tamano }
    ///     GET    /archivo?ruta=…   -> el binario
    ///     DELETE /archivo?ruta=…
    /// </summary>
    [RoutePrefix("archivo")]
    public class ArchivoController : ApiController
    {
        /// <summary>
        /// POST /archivo — sube el contenido y devuelve dónde quedó.
        /// </summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Subir(ArchivoSubidaDto dto)
        {
            try
            {
                ExigirClave();

                if (dto == null)
                    return BadRequest("Falta el cuerpo de la petición.");

                if (string.IsNullOrEmpty(dto.contenido_base64))
                    return BadRequest("El archivo está vacío.");

                byte[] contenido;

                try
                {
                    contenido = Convert.FromBase64String(dto.contenido_base64);
                }
                catch (FormatException)
                {
                    /* Se distingue del archivo vacío a propósito: son dos
                       problemas distintos —uno es del usuario, el otro es de
                       quien armó la petición— y el mismo mensaje para los dos
                       manda a buscar en el lugar equivocado. */
                    return BadRequest("El contenido no es base64 válido.");
                }

                BlobService blob = new BlobService();

                if (!blob.Disponible)
                    return Content(HttpStatusCode.ServiceUnavailable,
                                   new ErrorApi { codigo = 503, mensaje = blob.Motivo, esDeNegocio = false });

                ResultadoBlob resultado = blob.Subir(dto.ruta, contenido, dto.mime);

                return Ok(new
                {
                    ruta = resultado.ruta,
                    hash = resultado.hash,
                    tamano = resultado.tamano
                });
            }
            catch (ClaveInvalidaException)
            {
                return Content(HttpStatusCode.Unauthorized,
                               new ErrorApi { codigo = 401, mensaje = "Clave de servicio inválida.", esDeNegocio = false });
            }
            catch (Exception ex)
            {
                return Content(HttpStatusCode.InternalServerError,
                               new ErrorApi { codigo = 500, mensaje = ex.Message, esDeNegocio = false });
            }
        }

        /// <summary>
        /// GET /archivo?ruta=… — devuelve el binario.
        ///
        /// Sale como octet-stream y no con su mime real: este endpoint no
        /// sirve para mostrar el archivo en el navegador, sirve para que la
        /// web lo reenvíe. Devolver text/html de un archivo subido por un
        /// usuario sería servir HTML ajeno desde nuestro dominio.
        /// </summary>
        [HttpGet]
        [Route("")]
        public HttpResponseMessage Descargar(string ruta = null)
        {
            try
            {
                ExigirClave();

                BlobService blob = new BlobService();

                if (!blob.Disponible)
                    return Texto(HttpStatusCode.ServiceUnavailable, blob.Motivo);

                byte[] contenido = blob.Descargar(ruta);

                HttpResponseMessage respuesta = new HttpResponseMessage(HttpStatusCode.OK);

                respuesta.Content = new ByteArrayContent(contenido);
                respuesta.Content.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");
                respuesta.Content.Headers.ContentDisposition =
                    new ContentDispositionHeaderValue("attachment")
                    {
                        FileName = Path.GetFileName(ruta ?? "archivo")
                    };

                return respuesta;
            }
            catch (ClaveInvalidaException)
            {
                return Texto(HttpStatusCode.Unauthorized, "Clave de servicio inválida.");
            }
            catch (WebException ex)
            {
                HttpWebResponse http = ex.Response as HttpWebResponse;

                if (http != null && http.StatusCode == HttpStatusCode.NotFound)
                    return Texto(HttpStatusCode.NotFound, "El archivo no está en el almacenamiento.");

                return Texto(HttpStatusCode.InternalServerError, ex.Message);
            }
            catch (Exception ex)
            {
                return Texto(HttpStatusCode.InternalServerError, ex.Message);
            }
        }

        /// <summary>
        /// GET /archivo/ver?ruta=… — el archivo para VERLO en el navegador.
        ///
        /// LA DIFERENCIA CON /archivo
        ///
        ///   `/archivo` devuelve octet-stream con `attachment`: sirve para
        ///   que la web reenvíe el binario, y el navegador siempre lo baja.
        ///   `/archivo/ver` devuelve el mime REAL con `inline`: el navegador
        ///   muestra el PDF o la foto sin descargarla, que es lo que alguien
        ///   quiere al revisar un permiso de trabajo.
        ///
        /// POR QUE HAY UNA LISTA BLANCA Y NO SE DEVUELVE EL MIME TAL CUAL
        ///
        ///   Estos archivos los sube un usuario. Servir `text/html` o
        ///   `image/svg+xml` con `inline` desde nuestro dominio es ejecutar
        ///   HTML y javascript ajeno con nuestro origen: quien suba un .html
        ///   con un script puede leer lo que el navegador guarde para este
        ///   sitio. Es XSS almacenado, y el vector es exactamente "poder ver
        ///   el archivo".
        ///
        ///   Solo se muestran inline los tipos que el navegador dibuja sin
        ///   ejecutar nada: PDF e imágenes de mapa de bits. Todo lo demás
        ///   sale como descarga. No se pierde nada —el archivo se puede ver
        ///   igual, bajándolo— y se cierra el agujero.
        /// </summary>
        [HttpGet]
        [Route("ver")]
        public HttpResponseMessage Ver(string ruta = null)
        {
            try
            {
                ExigirClave();

                BlobService blob = new BlobService();

                if (!blob.Disponible)
                    return Texto(HttpStatusCode.ServiceUnavailable, blob.Motivo);

                ContenidoBlob leido = blob.Leer(ruta);

                HttpResponseMessage respuesta = new HttpResponseMessage(HttpStatusCode.OK);

                respuesta.Content = new ByteArrayContent(leido.contenido);

                bool seguroInline = EsSeguroInline(leido.mime);

                respuesta.Content.Headers.ContentType =
                    new MediaTypeHeaderValue(seguroInline ? leido.mime : "application/octet-stream");

                respuesta.Content.Headers.ContentDisposition =
                    new ContentDispositionHeaderValue(seguroInline ? "inline" : "attachment")
                    {
                        FileName = leido.nombre
                    };

                /* Aunque el tipo esté en la lista blanca: si el navegador
                   decidiera por su cuenta que un .jpg es HTML, esquivaría la
                   lista. Esta cabecera le prohíbe adivinar. */
                respuesta.Content.Headers.TryAddWithoutValidation("X-Content-Type-Options", "nosniff");

                return respuesta;
            }
            catch (ClaveInvalidaException)
            {
                return Texto(HttpStatusCode.Unauthorized, "Clave de servicio inválida.");
            }
            catch (WebException ex)
            {
                HttpWebResponse http = ex.Response as HttpWebResponse;

                if (http != null && http.StatusCode == HttpStatusCode.NotFound)
                    return Texto(HttpStatusCode.NotFound, "El archivo no está en el almacenamiento.");

                return Texto(HttpStatusCode.InternalServerError, ex.Message);
            }
            catch (Exception ex)
            {
                return Texto(HttpStatusCode.InternalServerError, ex.Message);
            }
        }

        /// <summary>
        /// GET /archivo/propiedades?ruta=… — si está, cuánto pesa y de qué
        /// tipo es, sin traer el contenido.
        ///
        /// Va con HEAD contra Azure: preguntar "¿existe?" descargando un PDF
        /// entero para después tirarlo es pagar el ancho de banda para
        /// responder que sí.
        /// </summary>
        [HttpGet]
        [Route("propiedades")]
        public IHttpActionResult Propiedades(string ruta = null)
        {
            try
            {
                ExigirClave();

                BlobService blob = new BlobService();

                if (!blob.Disponible)
                    return Content(HttpStatusCode.ServiceUnavailable,
                                   new ErrorApi { codigo = 503, mensaje = blob.Motivo, esDeNegocio = false });

                ContenidoBlob p = blob.Propiedades(ruta);

                return Ok(new
                {
                    existe = p.existe,
                    ruta = ruta,
                    nombre = p.nombre,
                    mime = p.mime,
                    tamano = p.tamano,
                    modificado = p.modificado,
                    se_puede_ver = EsSeguroInline(p.mime)
                });
            }
            catch (ClaveInvalidaException)
            {
                return Content(HttpStatusCode.Unauthorized,
                               new ErrorApi { codigo = 401, mensaje = "Clave de servicio inválida.", esDeNegocio = false });
            }
            catch (Exception ex)
            {
                return Content(HttpStatusCode.InternalServerError,
                               new ErrorApi { codigo = 500, mensaje = ex.Message, esDeNegocio = false });
            }
        }

        /// <summary>
        /// PUT /archivo — reemplaza el contenido de un archivo que ya existe,
        /// conservando su ruta.
        ///
        /// Es PUT y no POST a propósito: `POST /archivo` CREA en una ruta
        /// nueva, `PUT /archivo` REEMPLAZA una que ya está. Que sean dos
        /// verbos distintos evita que un cliente que reintenta una subida
        /// termine pisando un archivo que no era.
        ///
        /// Si la ruta no existe se responde 404 en vez de crearla: ver el
        /// comentario de `BlobService.Actualizar`.
        /// </summary>
        [HttpPut]
        [Route("")]
        public IHttpActionResult Actualizar(ArchivoSubidaDto dto)
        {
            try
            {
                ExigirClave();

                if (dto == null)
                    return BadRequest("Falta el cuerpo de la petición.");

                if (string.IsNullOrEmpty(dto.ruta))
                    return BadRequest("Falta la ruta del archivo a actualizar.");

                if (string.IsNullOrEmpty(dto.contenido_base64))
                    return BadRequest("El archivo está vacío.");

                byte[] contenido;

                try
                {
                    contenido = Convert.FromBase64String(dto.contenido_base64);
                }
                catch (FormatException)
                {
                    return BadRequest("El contenido no es base64 válido.");
                }

                BlobService blob = new BlobService();

                if (!blob.Disponible)
                    return Content(HttpStatusCode.ServiceUnavailable,
                                   new ErrorApi { codigo = 503, mensaje = blob.Motivo, esDeNegocio = false });

                if (!blob.Propiedades(dto.ruta).existe)
                    return Content(HttpStatusCode.NotFound,
                                   new ErrorApi
                                   {
                                       codigo = 404,
                                       mensaje = "No hay ningún archivo en esa ruta: no se puede actualizar. " +
                                                 "Para uno nuevo, use POST /archivo.",
                                       esDeNegocio = true
                                   });

                ResultadoBlob resultado = blob.Actualizar(dto.ruta, contenido, dto.mime);

                return Ok(new
                {
                    ruta = resultado.ruta,
                    hash = resultado.hash,
                    tamano = resultado.tamano
                });
            }
            catch (ClaveInvalidaException)
            {
                return Content(HttpStatusCode.Unauthorized,
                               new ErrorApi { codigo = 401, mensaje = "Clave de servicio inválida.", esDeNegocio = false });
            }
            catch (Exception ex)
            {
                return Content(HttpStatusCode.InternalServerError,
                               new ErrorApi { codigo = 500, mensaje = ex.Message, esDeNegocio = false });
            }
        }

        /// <summary>
        /// DELETE /archivo?ruta=…
        ///
        /// Borra el blob, no la fila de `Archivo`: quien llama decide qué
        /// hacer con el registro. Un endpoint que hiciera las dos cosas
        /// tendría que conocer todas las tablas que apuntan a un archivo.
        /// </summary>
        [HttpDelete]
        [Route("")]
        public IHttpActionResult Eliminar(string ruta = null)
        {
            try
            {
                ExigirClave();

                BlobService blob = new BlobService();

                if (!blob.Disponible)
                    return Content(HttpStatusCode.ServiceUnavailable,
                                   new ErrorApi { codigo = 503, mensaje = blob.Motivo, esDeNegocio = false });

                blob.Eliminar(ruta);

                return Ok(new { eliminado = true, ruta = ruta });
            }
            catch (ClaveInvalidaException)
            {
                return Content(HttpStatusCode.Unauthorized,
                               new ErrorApi { codigo = 401, mensaje = "Clave de servicio inválida.", esDeNegocio = false });
            }
            catch (Exception ex)
            {
                return Content(HttpStatusCode.InternalServerError,
                               new ErrorApi { codigo = 500, mensaje = ex.Message, esDeNegocio = false });
            }
        }

        /// <summary>
        /// GET /archivo/estado — si el almacenamiento responde.
        ///
        /// Existe para poder comprobar la configuración sin subir nada. Sin
        /// esto, la única forma de saber si el SAS quedó bien es intentar un
        /// archivo de verdad y mirar qué error sale.
        /// </summary>
        [HttpGet]
        [Route("estado")]
        public IHttpActionResult Estado()
        {
            try
            {
                ExigirClave();

                BlobService blob = new BlobService();

                return Ok(new
                {
                    disponible = blob.Disponible,
                    motivo = blob.Motivo,
                    contenedor = blob.ContenedorPorOmision()
                });
            }
            catch (ClaveInvalidaException)
            {
                return Content(HttpStatusCode.Unauthorized,
                               new ErrorApi { codigo = 401, mensaje = "Clave de servicio inválida.", esDeNegocio = false });
            }
        }


        /* ====================================================================
           LA CLAVE DE SERVICIO
           ==================================================================== */

        /// <summary>
        /// Los tipos que el navegador dibuja SIN ejecutar nada.
        ///
        /// No están `text/html` ni `image/svg+xml`: los dos ejecutan
        /// javascript. Servirlos inline desde nuestro dominio es XSS
        /// almacenado, y el archivo lo subió un usuario.
        /// </summary>
        private static readonly string[] MIMES_INLINE = new string[]
        {
            "application/pdf",
            "image/jpeg", "image/png", "image/gif", "image/webp", "image/bmp",
            "text/plain"
        };

        private static bool EsSeguroInline(string mime)
        {
            if (string.IsNullOrEmpty(mime)) return false;

            /* El mime puede venir con parámetros: "text/plain; charset=utf-8". */
            int corte = mime.IndexOf(';');
            string limpio = (corte < 0 ? mime : mime.Substring(0, corte)).Trim().ToLowerInvariant();

            for (int i = 0; i < MIMES_INLINE.Length; i++)
                if (MIMES_INLINE[i] == limpio) return true;

            return false;
        }

        public class ClaveInvalidaException : Exception { }

        private void ExigirClave()
        {
            string esperada = ConfigurationManager.AppSettings["ServiciosApiKey"];

            /* Sin clave configurada NO se abre el endpoint: se cierra. Un
               servicio que se vuelve público porque falta una línea de
               configuración es la forma más silenciosa de quedar expuesto. */
            if (string.IsNullOrEmpty(esperada) ||
                esperada.IndexOf("PENDIENTE", StringComparison.OrdinalIgnoreCase) >= 0)
                throw new ClaveInvalidaException();

            string recibida = null;

            System.Collections.Generic.IEnumerable<string> valores;

            if (Request.Headers.TryGetValues("X-Api-Key", out valores))
                recibida = valores.FirstOrDefault();

            if (!IgualEnTiempoConstante(esperada, recibida))
                throw new ClaveInvalidaException();
        }

        /// <summary>
        /// Compara sin cortar en la primera diferencia.
        ///
        /// Un == normal devuelve apenas encuentra un carácter distinto, y esa
        /// diferencia de tiempo —medible con suficientes intentos— permite
        /// deducir la clave carácter a carácter.
        /// </summary>
        private static bool IgualEnTiempoConstante(string esperada, string recibida)
        {
            if (recibida == null) return false;

            byte[] a = System.Text.Encoding.UTF8.GetBytes(esperada);
            byte[] b = System.Text.Encoding.UTF8.GetBytes(recibida);

            int diferencia = a.Length ^ b.Length;

            for (int i = 0; i < a.Length && i < b.Length; i++)
                diferencia |= a[i] ^ b[i];

            return diferencia == 0;
        }

        private HttpResponseMessage Texto(HttpStatusCode codigo, string mensaje)
        {
            HttpResponseMessage respuesta = new HttpResponseMessage(codigo);
            respuesta.Content = new StringContent(mensaje ?? "", System.Text.Encoding.UTF8, "text/plain");

            return respuesta;
        }
    }
}
