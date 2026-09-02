using System;
using System.Collections.Generic;
using System.Configuration;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;
using System.Web;
using System.Web.Script.Serialization;

namespace SitioBase
{
    /// <summary>
    /// EL UNICO SITIO DESDE EL QUE LA WEB LLAMA A LA API DE SERVICIOS.
    ///
    /// QUE ES ESTO
    ///
    ///   Hay cosas que la web no hace por su cuenta: hablar con Azure Blob
    ///   Storage, y mañana lo que venga —correo, notificaciones push, colas—.
    ///   Todas viven en la API .NET de `SIGMA/Solucion/SIGMA/API`, por una
    ///   razón que se decidió el 29-08: **un solo camino**. La web y la app
    ///   móvil tienen que escribir en el mismo sitio con las mismas reglas;
    ///   dos caminos distintos garantizan que algún día un archivo quede
    ///   donde la otra mitad no mira.
    ///
    ///   Este archivo es la puerta. Todo lo que la web le pida a la API pasa
    ///   por acá: la URL base, la clave de servicio, el manejo de errores y
    ///   el formato de la respuesta se resuelven UNA vez. Un `WebClient`
    ///   suelto en una pantalla es el que el día que cambie la autenticación
    ///   nadie va a encontrar.
    ///
    /// LAS CREDENCIALES NO ESTAN ACA
    ///
    ///   Salen de Web.config. Y el SAS de Azure no está ni siquiera ahí: la
    ///   web nunca lo ve. Solo la API lo tiene, así que rotarlo es tocar una
    ///   configuración y no dos.
    /// </summary>
    public static class Services
    {
        private const string MARCADOR = "PENDIENTE";

        /// <summary>La URL base de la API de servicios.</summary>
        public static string Url()
        {
            string valor = ConfigurationManager.AppSettings["ServiciosApiUrl"];

            return string.IsNullOrEmpty(valor) ? "" : valor.TrimEnd('/');
        }

        private static string Clave()
        {
            return ConfigurationManager.AppSettings["ServiciosApiKey"];
        }

        /// <summary>
        /// Si la API está configurada. Quien vaya a ofrecer una acción que
        /// dependa de ella DEBE preguntar antes: un botón que siempre falla
        /// enseña a desconfiar de los botones.
        /// </summary>
        public static bool Disponible
        {
            get
            {
                string url = Url();
                string clave = Clave();

                if (string.IsNullOrEmpty(url) || string.IsNullOrEmpty(clave)) return false;
                if (url.IndexOf(MARCADOR, StringComparison.OrdinalIgnoreCase) >= 0) return false;
                if (clave.IndexOf(MARCADOR, StringComparison.OrdinalIgnoreCase) >= 0) return false;

                return true;
            }
        }

        public static string Motivo
        {
            get
            {
                if (Disponible) return "";

                return "La API de servicios todavía no está configurada: revise " +
                       "ServiciosApiUrl y ServiciosApiKey en el Web.config.";
            }
        }


        /* ====================================================================
           LAS LLAMADAS
           ==================================================================== */

        /// <summary>
        /// POST con cuerpo JSON, respuesta JSON.
        /// </summary>
        public static Dictionary<string, object> PostJson(string ruta, object cuerpo)
        {
            Exigir();

            JavaScriptSerializer js = Serializador();

            string respuesta;

            using (WebClient wc = Preparar())
            {
                wc.Headers[HttpRequestHeader.ContentType] = "application/json";

                try
                {
                    respuesta = wc.UploadString(Url() + Normalizar(ruta), "POST", js.Serialize(cuerpo));
                }
                catch (WebException ex)
                {
                    throw Traducir(ex);
                }
            }

            return js.Deserialize<Dictionary<string, object>>(respuesta);
        }

        /// <summary>
        /// PUT con cuerpo JSON. Reemplaza; no crea.
        /// </summary>
        public static Dictionary<string, object> PutJson(string ruta, object cuerpo)
        {
            Exigir();

            JavaScriptSerializer js = Serializador();

            string respuesta;

            using (WebClient wc = Preparar())
            {
                wc.Headers[HttpRequestHeader.ContentType] = "application/json";

                try
                {
                    respuesta = wc.UploadString(Url() + Normalizar(ruta), "PUT", js.Serialize(cuerpo));
                }
                catch (WebException ex)
                {
                    throw Traducir(ex);
                }
            }

            return js.Deserialize<Dictionary<string, object>>(respuesta);
        }

        /// <summary>GET que devuelve JSON.</summary>
        public static Dictionary<string, object> GetJson(string ruta)
        {
            Exigir();

            string respuesta;

            using (WebClient wc = Preparar())
            {
                try
                {
                    respuesta = wc.DownloadString(Url() + Normalizar(ruta));
                }
                catch (WebException ex)
                {
                    throw Traducir(ex);
                }
            }

            return Serializador().Deserialize<Dictionary<string, object>>(respuesta);
        }

        /// <summary>GET que devuelve un binario.</summary>
        public static byte[] GetBinario(string ruta)
        {
            Exigir();

            using (WebClient wc = Preparar())
            {
                try
                {
                    return wc.DownloadData(Url() + Normalizar(ruta));
                }
                catch (WebException ex)
                {
                    throw Traducir(ex);
                }
            }
        }

        /// <summary>DELETE.</summary>
        public static void Delete(string ruta)
        {
            Exigir();

            using (WebClient wc = Preparar())
            {
                try
                {
                    wc.UploadString(Url() + Normalizar(ruta), "DELETE", "");
                }
                catch (WebException ex)
                {
                    throw Traducir(ex);
                }
            }
        }


        /* ====================================================================
           LO DE ADENTRO
           ==================================================================== */

        private static void Exigir()
        {
            if (!Disponible) throw new Exception(Motivo);
        }

        private static string Normalizar(string ruta)
        {
            if (string.IsNullOrEmpty(ruta)) return "";

            return ruta.StartsWith("/") ? ruta : "/" + ruta;
        }

        private static JavaScriptSerializer Serializador()
        {
            JavaScriptSerializer js = new JavaScriptSerializer();

            /* Un archivo en base64 crece un tercio: el límite de 4 MB por
               omisión rechaza un PDF de 3 MB con "Error during serialization",
               que no menciona el tamaño por ningún lado. */
            js.MaxJsonLength = 64 * 1024 * 1024;

            return js;
        }

        private static WebClient Preparar()
        {
            /* TLS 1.2: .NET Framework 4.8 hereda el valor del sistema y en un
               servidor viejo puede seguir en TLS 1.0. El síntoma es "Se ha
               forzado el cierre de la conexión", que no menciona TLS. */
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;

            WebClient wc = new WebClient();

            wc.Encoding = Encoding.UTF8;
            wc.Headers["X-Api-Key"] = Clave();

            return wc;
        }

        /// <summary>
        /// El error de la API dice algo útil; el de WebException dice "(500)
        /// Error interno del servidor". Se lee el cuerpo para poder mostrar
        /// el primero.
        /// </summary>
        private static Exception Traducir(WebException ex)
        {
            HttpWebResponse http = ex.Response as HttpWebResponse;

            if (http == null) return new Exception("No se pudo contactar la API de servicios. " + ex.Message);

            string cuerpo = "";

            try
            {
                using (StreamReader sr = new StreamReader(http.GetResponseStream(), Encoding.UTF8))
                    cuerpo = sr.ReadToEnd();
            }
            catch (Exception) { }

            string mensaje = "";

            if (!string.IsNullOrEmpty(cuerpo))
            {
                try
                {
                    Dictionary<string, object> raiz =
                        Serializador().Deserialize<Dictionary<string, object>>(cuerpo);

                    if (raiz != null && raiz.ContainsKey("mensaje"))
                        mensaje = Convert.ToString(raiz["mensaje"]);
                    else if (raiz != null && raiz.ContainsKey("Message"))
                        mensaje = Convert.ToString(raiz["Message"]);
                }
                catch (Exception)
                {
                    // No era JSON: sirve el texto tal cual.
                    mensaje = cuerpo.Length > 400 ? cuerpo.Substring(0, 400) : cuerpo;
                }
            }

            if (string.IsNullOrEmpty(mensaje))
                mensaje = "La API de servicios respondió " + (int)http.StatusCode + ".";

            if (http.StatusCode == HttpStatusCode.Unauthorized)
                mensaje = "La API de servicios rechazó la clave (X-Api-Key). " +
                          "Revise que ServiciosApiKey sea la misma en los dos Web.config.";

            return new Exception(mensaje);
        }
    }


    /// <summary>
    /// DONDE QUEDA GUARDADO CADA ARCHIVO.
    ///
    /// LA ESTRUCTURA
    ///
    ///     sigma / 0001-hamburgo / permisos-trabajo / 2026 / 09 / a1b2…pdf
    ///     └cont┘ └── cliente ──┘ └──── módulo ────┘ └─ cuándo ─┘ └nombre┘
    ///
    /// POR QUE EL ID Y EL NOMBRE JUNTOS
    ///
    ///   Solo el id —"sigma/1/…"— no dice de quién es nada cuando alguien
    ///   abre el portal de Azure a buscar un archivo. Solo el nombre no
    ///   sirve: dos clientes pueden llamarse parecido, y un nombre cambia
    ///   —una empresa se renombra— mientras que el id no cambia nunca.
    ///
    ///   Los dos juntos, con el id delante y relleno a cuatro dígitos, dan
    ///   una carpeta que se lee y que además **ordena**: 0002 va antes que
    ///   0010, cosa que "2" y "10" no hacen en un listado alfabético.
    ///
    /// POR QUE EL MODULO DESPUES DEL CLIENTE Y NO AL REVES
    ///
    ///   Porque el aislamiento entre empresas es lo que no se puede
    ///   equivocar. Con el cliente arriba, un SAS acotado a un prefijo deja
    ///   fuera a las demás empresas de una sola regla; con el módulo arriba
    ///   habría que escribir una por módulo y la que se olvide filtra datos.
    ///
    /// POR QUE AÑO Y MES
    ///
    ///   Un contenedor plano con veinte mil comprobantes es imposible de
    ///   mirar. Partido por mes, cada carpeta queda en un tamaño que el
    ///   portal puede listar, y buscar "los permisos de septiembre" es
    ///   navegar y no filtrar.
    /// </summary>
    public static class RutaArchivo
    {
        /// <summary>
        /// Arma la ruta completa. `modulo` es la carpeta del módulo
        /// —"permisos-trabajo", "comprobantes-pago"— y viene de quien llama,
        /// que es el que sabe a qué corresponde el archivo.
        /// </summary>
        public static string Armar(string contenedor, int cliente, string clienteNombre,
                                   string modulo, string nombreAlmacenado, DateTime cuando)
        {
            if (string.IsNullOrEmpty(contenedor)) contenedor = "sigma";

            return contenedor + "/" +
                   CarpetaCliente(cliente, clienteNombre) + "/" +
                   Limpiar(string.IsNullOrEmpty(modulo) ? "otros" : modulo) + "/" +
                   cuando.ToString("yyyy") + "/" +
                   cuando.ToString("MM") + "/" +
                   nombreAlmacenado;
        }

        /// <summary>"0001-hamburgo".</summary>
        public static string CarpetaCliente(int cliente, string nombre)
        {
            string slug = Limpiar(nombre);

            /* Sin nombre queda solo el id: es preferible una carpeta fea a
               una que diga "-" o "sin-nombre", que se lee como si el cliente
               tuviera un problema. */
            return cliente.ToString("0000") + (string.IsNullOrEmpty(slug) ? "" : "-" + slug);
        }

        /// <summary>
        /// Un texto en algo que se pueda poner en una ruta: minúsculas, sin
        /// tildes, sin espacios ni signos.
        ///
        /// Blob Storage aceptaría casi cualquier cosa en el nombre, pero una
        /// ruta con tildes y espacios hay que escaparla en cada URL y basta
        /// que alguien olvide hacerlo una vez para que el archivo deje de
        /// encontrarse.
        /// </summary>
        public static string Limpiar(string texto)
        {
            if (string.IsNullOrEmpty(texto)) return "";

            string normal = texto.Trim().ToLowerInvariant().Normalize(NormalizationForm.FormD);

            StringBuilder sb = new StringBuilder(normal.Length);
            bool guion = false;

            foreach (char c in normal)
            {
                // Se descartan las marcas diacríticas: "ó" queda en "o".
                if (CharUnicodeInfo.GetUnicodeCategory(c) == UnicodeCategory.NonSpacingMark) continue;

                if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9'))
                {
                    sb.Append(c);
                    guion = false;
                }
                else if (!guion && sb.Length > 0)
                {
                    sb.Append('-');
                    guion = true;
                }
            }

            string salida = sb.ToString().Trim('-');

            /* Un nombre de empresa largo haría una carpeta ilegible y, sumado
               al resto de la ruta, acerca el límite de 1024 caracteres del
               nombre de blob. */
            if (salida.Length > 40) salida = salida.Substring(0, 40).Trim('-');

            return salida;
        }
    }


    /// <summary>
    /// La direccion con la que una pagina muestra un archivo.
    ///
    /// POR QUE UNA URL Y NO EL BINARIO INCRUSTADO
    ///
    ///   El logo del cliente y la foto del usuario se servian como
    ///   `data:image/jpeg;base64,...` dentro del HTML. Eso significa que la
    ///   imagen entera viaja en CADA carga de pagina —el avatar aparece en
    ///   la cabecera de todas— y que ningun navegador la puede cachear,
    ///   porque no es un recurso: es texto dentro del documento.
    ///
    ///   Con una URL el navegador la pide una vez y la guarda. Y de paso el
    ///   HTML deja de pesar lo que pese la foto.
    ///
    ///   El id viaja CIFRADO: con la ruta a la vista cualquiera podria pedir
    ///   otra cambiando el texto. VerArchivo.aspx la resuelve contra la base
    ///   y comprueba que el archivo sea del cliente en sesion.
    /// </summary>
    public static class UrlArchivo
    {
        /// <summary>Para mostrarla en un &lt;img&gt;.</summary>
        public static string Ver(int idArchivo)
        {
            return Armar(idArchivo, "VER");
        }

        /// <summary>Para bajarla.</summary>
        public static string Descargar(int idArchivo)
        {
            return Armar(idArchivo, "BAJAR");
        }

        private static string Armar(int idArchivo, string modo)
        {
            if (idArchivo <= 0) return "";

            string q = HttpUtility.UrlEncode(Tools.Crypto.Encrypt("Id=" + idArchivo + "&Modo=" + modo));

            /* VirtualPathUtility y no ResolveUrl: esto lo llama tanto una
               pagina como un master, y ResolveUrl es un metodo de Control. */
            return VirtualPathUtility.ToAbsolute("~/View/Comun/Archivos/VerArchivo.aspx") +
                   "?query=" + q;
        }
    }


    /// <summary>
    /// Un archivo tal como lo describe el almacenamiento.
    /// </summary>
    [Serializable]
    public class ArchivoVisto
    {
        public string ruta { get; set; }
        public string nombre { get; set; }
        public string mime { get; set; }
        public long tamano { get; set; }
        public DateTime? modificado { get; set; }
        public bool existe { get; set; }

        /// <summary>
        /// Si la API lo va a servir para verse en el navegador. Falso para
        /// todo lo que no sea PDF o imagen de mapa de bits: ver el comentario
        /// de la lista blanca en ArchivoController de la API.
        /// </summary>
        public bool puede_verse { get; set; }

        /// <summary>Solo viene con Ver(); Propiedades() no lo trae.</summary>
        public byte[] contenido { get; set; }

        /// <summary>El peso en algo que se pueda leer.</summary>
        public string peso
        {
            get
            {
                if (tamano <= 0) return "";
                if (tamano < 1024) return tamano + " B";
                if (tamano < 1048576) return (tamano / 1024.0).ToString("N0") + " KB";

                return (tamano / 1048576.0).ToString("N1") + " MB";
            }
        }
    }


    /// <summary>
    /// Archivos: subir, ver, actualizar, descargar y borrar contra la API de
    /// servicios.
    ///
    /// La web nunca habla con Azure. Le manda el binario a la API y la API
    /// escribe en el blob con su SAS, que la web no conoce.
    /// </summary>
    public static class ServicioArchivos
    {
        public static string Contenedor()
        {
            string valor = ConfigurationManager.AppSettings["AlmacenamientoContenedor"];

            return string.IsNullOrEmpty(valor) ? "sigma" : valor;
        }

        /// <summary>
        /// Sube y devuelve la ruta con la que se lo va a volver a pedir.
        ///
        /// `modulo` dice a qué corresponde el archivo —"permisos-trabajo",
        /// "comprobantes-pago"— y arma la carpeta.
        /// </summary>
        public static ResultadoSubida Subir(int cliente, string clienteNombre, string modulo,
                                            string nombreOriginal, byte[] contenido, string mime)
        {
            if (contenido == null || contenido.Length == 0)
                throw new Exception("El archivo está vacío.");

            string nombreAlmacenado = Almacenamiento.NombreAlmacenado(nombreOriginal);

            string ruta = RutaArchivo.Armar(Contenedor(), cliente, clienteNombre,
                                            modulo, nombreAlmacenado, DateTime.Now);

            Dictionary<string, object> cuerpo = new Dictionary<string, object>();

            cuerpo["ruta"] = ruta;
            cuerpo["nombre_original"] = nombreOriginal;
            cuerpo["mime"] = mime;
            cuerpo["contenido_base64"] = Convert.ToBase64String(contenido);

            Dictionary<string, object> raiz = Services.PostJson("/archivo", cuerpo);

            if (raiz == null || !raiz.ContainsKey("ruta"))
                throw new Exception("El almacenamiento no devolvió la ruta del archivo.");

            ResultadoSubida resultado = new ResultadoSubida();

            resultado.ruta = Convert.ToString(raiz["ruta"]);
            resultado.nombre_almacenado = nombreAlmacenado;
            resultado.tamano = contenido.LongLength;
            resultado.mime = mime;
            resultado.extension = Path.GetExtension(nombreOriginal);

            /* El hash se calcula acá aunque la API también lo devuelva: es el
               del contenido que efectivamente se envió, no el de lo que dice
               haber recibido el otro lado. Si difieren, algo se corrompió en
               el camino y hay que poder notarlo. */
            resultado.hash = Almacenamiento.Hash(contenido);

            return resultado;
        }

        public static byte[] Descargar(string ruta)
        {
            if (string.IsNullOrEmpty(ruta)) throw new Exception("Falta la ruta del archivo.");

            return Services.GetBinario("/archivo?ruta=" + Uri.EscapeDataString(ruta));
        }

        /// <summary>
        /// El archivo para MOSTRARLO, con su mime.
        ///
        /// La diferencia con `Descargar` es el mime: sin él lo único que se
        /// puede hacer con los bytes es ofrecerlos como descarga, porque el
        /// navegador no sabe si es un PDF o una foto.
        ///
        /// `puede_verse` dice si la API lo va a servir inline. La API tiene
        /// una lista blanca —PDF e imágenes de mapa de bits— y todo lo demás
        /// sale como descarga: servir HTML o SVG subido por un usuario desde
        /// nuestro dominio sería ejecutar su javascript con nuestro origen.
        /// </summary>
        public static ArchivoVisto Ver(string ruta)
        {
            if (string.IsNullOrEmpty(ruta)) throw new Exception("Falta la ruta del archivo.");

            ArchivoVisto visto = new ArchivoVisto();

            visto.ruta = ruta;
            visto.contenido = Services.GetBinario("/archivo/ver?ruta=" + Uri.EscapeDataString(ruta));

            /* El mime lo sabe la API. Se pide aparte y no se adivina por la
               extensión: la extensión la eligió quien subió el archivo. */
            Propiedades(visto, ruta);

            return visto;
        }

        /// <summary>
        /// Si el archivo está, cuánto pesa y de qué tipo es, SIN traerlo.
        ///
        /// Sirve para dibujar la ficha —"permiso.pdf · 240 KB"— sin descargar
        /// el archivo entero solo para saber su tamaño.
        /// </summary>
        public static ArchivoVisto Propiedades(string ruta)
        {
            ArchivoVisto visto = new ArchivoVisto();
            visto.ruta = ruta;

            Propiedades(visto, ruta);

            return visto;
        }

        private static void Propiedades(ArchivoVisto visto, string ruta)
        {
            if (string.IsNullOrEmpty(ruta)) throw new Exception("Falta la ruta del archivo.");

            Dictionary<string, object> raiz =
                Services.GetJson("/archivo/propiedades?ruta=" + Uri.EscapeDataString(ruta));

            if (raiz == null) return;

            if (raiz.ContainsKey("existe")) visto.existe = Convert.ToBoolean(raiz["existe"]);
            if (raiz.ContainsKey("nombre")) visto.nombre = Convert.ToString(raiz["nombre"]);
            if (raiz.ContainsKey("mime")) visto.mime = Convert.ToString(raiz["mime"]);
            if (raiz.ContainsKey("tamano")) visto.tamano = Convert.ToInt64(raiz["tamano"]);
            if (raiz.ContainsKey("se_puede_ver")) visto.puede_verse = Convert.ToBoolean(raiz["se_puede_ver"]);

            if (raiz.ContainsKey("modificado") && raiz["modificado"] != null)
            {
                DateTime fecha;

                if (DateTime.TryParse(Convert.ToString(raiz["modificado"]), out fecha))
                    visto.modificado = fecha;
            }
        }

        /// <summary>
        /// Reemplaza el contenido de un archivo que ya existe, CONSERVANDO su
        /// ruta.
        ///
        /// La ruta no cambia a propósito: `Archivo.arc_ruta` en la base apunta
        /// ahí. Si actualizar generara una ruta nueva habría que actualizar
        /// también la fila, y entre una cosa y la otra hay una ventana en la
        /// que la base apunta a un blob que ya no está.
        ///
        /// Devuelve el hash y el tamaño nuevos, que es lo que hay que
        /// escribir en `Archivo`.
        /// </summary>
        public static ResultadoSubida Actualizar(string ruta, string nombreOriginal,
                                                 byte[] contenido, string mime)
        {
            if (string.IsNullOrEmpty(ruta)) throw new Exception("Falta la ruta del archivo.");

            if (contenido == null || contenido.Length == 0)
                throw new Exception("El archivo está vacío.");

            Dictionary<string, object> cuerpo = new Dictionary<string, object>();

            cuerpo["ruta"] = ruta;
            cuerpo["nombre_original"] = nombreOriginal;
            cuerpo["mime"] = mime;
            cuerpo["contenido_base64"] = Convert.ToBase64String(contenido);

            Dictionary<string, object> raiz = Services.PutJson("/archivo", cuerpo);

            if (raiz == null || !raiz.ContainsKey("ruta"))
                throw new Exception("El almacenamiento no confirmó la actualización.");

            ResultadoSubida resultado = new ResultadoSubida();

            resultado.ruta = Convert.ToString(raiz["ruta"]);
            resultado.tamano = contenido.LongLength;
            resultado.mime = mime;
            resultado.extension = Path.GetExtension(nombreOriginal);
            resultado.hash = Almacenamiento.Hash(contenido);

            /* El nombre almacenado NO cambia: es el último segmento de la
               ruta, que sigue siendo la misma. */
            string r = resultado.ruta ?? "";
            int corte = r.LastIndexOf('/');
            resultado.nombre_almacenado = corte < 0 ? r : r.Substring(corte + 1);

            return resultado;
        }

        public static void Eliminar(string ruta)
        {
            if (string.IsNullOrEmpty(ruta)) throw new Exception("Falta la ruta del archivo.");

            Services.Delete("/archivo?ruta=" + Uri.EscapeDataString(ruta));
        }
    }
}
