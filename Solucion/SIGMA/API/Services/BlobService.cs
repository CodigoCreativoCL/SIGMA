using System;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Net;
using System.Security.Cryptography;
using System.Text;

namespace API.Services
{
    /// <summary>
    /// Lo que devuelve una subida.
    /// </summary>
    public class ResultadoBlob
    {
        public string ruta { get; set; }
        public string hash { get; set; }
        public long tamano { get; set; }
        public string mime { get; set; }
    }


    /// <summary>
    /// Lo que hay en el blob y como esta descrito.
    /// </summary>
    public class ContenidoBlob
    {
        public byte[] contenido { get; set; }
        public string mime { get; set; }
        public long tamano { get; set; }
        public string nombre { get; set; }
        public DateTime? modificado { get; set; }
        public bool existe { get; set; }
    }


    /// <summary>
    /// Guardar, leer, ver, actualizar y borrar archivos en Azure Blob Storage.
    ///
    /// POR QUE REST Y NO EL SDK DE AZURE
    ///
    ///   `Azure.Storage.Blobs` exigiría meter el paquete y sus ocho
    ///   dependencias transitivas en un proyecto .NET Framework 4.8 que hoy
    ///   no tiene ninguna, y todo lo que aporta —reintentos, streaming en
    ///   bloques, paralelismo— es para escenarios que este módulo no tiene:
    ///   acá se suben permisos de trabajo y comprobantes de pago, archivos
    ///   de unos pocos MB, de a uno.
    ///
    ///   Con un SAS la API REST de Blob **no necesita firmar nada**: el token
    ///   ES la credencial y viaja en la query. Son tres verbos HTTP contra
    ///   una URL. Traer un SDK para eso es agregar superficie que mantener a
    ///   cambio de nada.
    ///
    /// LA RUTA ES "contenedor/resto/del/camino"
    ///
    ///   La arma la web —`contenedor/cliente/carpeta/nombre`— y acá se parte
    ///   en dos por el primer '/': el primer segmento es el contenedor y el
    ///   resto es el nombre del blob. Blob Storage no tiene carpetas: los '/'
    ///   del nombre son parte del nombre, y el portal los dibuja como si
    ///   fueran carpetas.
    ///
    /// EL SAS NO VA EN EL CODIGO
    ///
    ///   Sale de Web.config. Es una credencial: escrita acá viajaría en cada
    ///   copia del repositorio y no habría forma de rotarla sin recompilar.
    /// </summary>
    public class BlobService
    {
        /// <summary>
        /// Las versiones de la API REST de Blob se piden por cabecera. Se fija
        /// una explícita: sin ella el servicio elige una por omisión que puede
        /// cambiar, y el día que cambie el comportamiento cambia sin que nadie
        /// haya tocado nada acá.
        /// </summary>
        private const string VERSION_REST = "2021-08-06";

        private const string MARCADOR = "PENDIENTE";

        private string Endpoint()
        {
            string valor = ConfigurationManager.AppSettings["AzureBlobEndpoint"];
            return string.IsNullOrEmpty(valor) ? "" : valor.TrimEnd('/');
        }

        /// <summary>
        /// El token, siempre sin el '?' que trae al copiarlo del portal.
        /// </summary>
        private string Sas()
        {
            string valor = ConfigurationManager.AppSettings["AzureBlobSas"];

            if (string.IsNullOrEmpty(valor)) return "";

            return valor.TrimStart('?');
        }

        public string ContenedorPorOmision()
        {
            string valor = ConfigurationManager.AppSettings["AzureBlobContenedor"];
            return string.IsNullOrEmpty(valor) ? "sigma" : valor;
        }

        /// <summary>
        /// Falso mientras no esté configurado. Quien vaya a ofrecer una
        /// subida DEBE preguntar antes: es la misma regla que aplica la web.
        /// </summary>
        public bool Disponible
        {
            get
            {
                string url = Endpoint();
                string sas = Sas();

                if (string.IsNullOrEmpty(url) || string.IsNullOrEmpty(sas)) return false;

                if (url.IndexOf(MARCADOR, StringComparison.OrdinalIgnoreCase) >= 0) return false;
                if (sas.IndexOf(MARCADOR, StringComparison.OrdinalIgnoreCase) >= 0) return false;

                return true;
            }
        }

        public string Motivo
        {
            get
            {
                if (Disponible) return "";

                return "El almacenamiento no está configurado: revise AzureBlobEndpoint " +
                       "y AzureBlobSas en el Web.config de la API.";
            }
        }


        /* ====================================================================
           LAS TRES OPERACIONES
           ==================================================================== */

        /// <summary>
        /// Sube el contenido y devuelve la ruta con la que se lo va a volver
        /// a pedir.
        ///
        /// El contenedor se crea si no existe. Es una llamada de más la
        /// primera vez y evita que la subida falle con un 404 que no dice
        /// cuál de las dos cosas faltaba.
        /// </summary>
        public ResultadoBlob Subir(string ruta, byte[] contenido, string mime)
        {
            Exigir();

            if (contenido == null || contenido.Length == 0)
                throw new Exception("El archivo está vacío.");

            string contenedor, blob;
            Partir(ruta, out contenedor, out blob);

            AsegurarContenedor(contenedor);

            using (WebClient wc = Preparar())
            {
                wc.Headers["x-ms-blob-type"] = "BlockBlob";

                if (!string.IsNullOrEmpty(mime))
                    wc.Headers[HttpRequestHeader.ContentType] = mime;

                /* El nombre original va como metadato y no en el nombre del
                   blob: el nombre almacenado es un GUID a propósito —dos
                   personas suben "permiso.pdf" el mismo día— pero perder el
                   original dejaría un contenedor de GUID ilegibles si algún
                   día hay que mirarlo desde el portal. */
                wc.UploadData(Url(contenedor, blob), "PUT", contenido);
            }

            ResultadoBlob resultado = new ResultadoBlob();

            resultado.ruta = contenedor + "/" + blob;
            resultado.tamano = contenido.LongLength;
            resultado.mime = mime;
            resultado.hash = Hash(contenido);

            return resultado;
        }

        public byte[] Descargar(string ruta)
        {
            Exigir();

            string contenedor, blob;
            Partir(ruta, out contenedor, out blob);

            using (WebClient wc = Preparar())
            {
                return wc.DownloadData(Url(contenedor, blob));
            }
        }

        /// <summary>
        /// Lee el blob CON su descripcion: el contenido, el mime con el que
        /// se guardo, el tamano y cuando se modifico.
        ///
        /// Es lo que hace falta para VERLO. `Descargar` devuelve solo los
        /// bytes, y sin el mime lo unico que se puede hacer con ellos es
        /// ofrecerlos como descarga: el navegador no sabe si es un PDF o una
        /// foto.
        /// </summary>
        public ContenidoBlob Leer(string ruta)
        {
            Exigir();

            string contenedor, blob;
            Partir(ruta, out contenedor, out blob);

            ContenidoBlob salida = new ContenidoBlob();

            using (WebClient wc = Preparar())
            {
                salida.contenido = wc.DownloadData(Url(contenedor, blob));

                /* Las cabeceras de la respuesta solo existen DESPUES de
                   descargar: leerlas antes devuelve la coleccion vacia. */
                salida.mime = wc.ResponseHeaders["Content-Type"];

                string modificado = wc.ResponseHeaders["Last-Modified"];

                DateTime fecha;

                if (!string.IsNullOrEmpty(modificado) &&
                    DateTime.TryParse(modificado, out fecha)) salida.modificado = fecha;
            }

            salida.tamano = salida.contenido == null ? 0 : salida.contenido.LongLength;
            salida.nombre = NombreDe(blob);
            salida.existe = true;

            return salida;
        }

        /// <summary>
        /// Si el blob esta, cuanto pesa y de que tipo es, SIN traer el
        /// contenido.
        ///
        /// Va con HEAD: preguntar "existe?" descargando el archivo entero
        /// para despues tirarlo es pagar el ancho de banda de un PDF para
        /// responder que si.
        /// </summary>
        public ContenidoBlob Propiedades(string ruta)
        {
            Exigir();

            string contenedor, blob;
            Partir(ruta, out contenedor, out blob);

            ContenidoBlob salida = new ContenidoBlob();
            salida.nombre = NombreDe(blob);

            try
            {
                HttpWebRequest peticion = (HttpWebRequest)WebRequest.Create(Url(contenedor, blob));

                peticion.Method = "HEAD";
                peticion.Headers["x-ms-version"] = VERSION_REST;

                using (HttpWebResponse respuesta = (HttpWebResponse)peticion.GetResponse())
                {
                    salida.existe = true;
                    salida.mime = respuesta.ContentType;
                    salida.tamano = respuesta.ContentLength;
                    salida.modificado = respuesta.LastModified;
                }
            }
            catch (WebException ex)
            {
                if (Codigo(ex) == HttpStatusCode.NotFound)
                {
                    salida.existe = false;
                    return salida;
                }

                throw;
            }

            return salida;
        }

        /// <summary>
        /// Reemplaza el contenido de un blob que YA existe, conservando su
        /// ruta.
        ///
        /// POR QUE COMPRUEBA QUE EXISTA
        ///
        ///   En Blob Storage un PUT sobre una ruta que no existe la CREA: no
        ///   hay diferencia entre subir y actualizar. Sin esta comprobacion,
        ///   "actualizar" una ruta mal escrita dejaria un archivo huerfano en
        ///   una ubicacion que ninguna fila de la base referencia, y quien lo
        ///   pidio creeria que actualizo el suyo.
        ///
        /// LA RUTA NO CAMBIA, Y ES A PROPOSITO
        ///
        ///   `Archivo.arc_ruta` en la base apunta aca. Si actualizar generara
        ///   una ruta nueva habria que actualizar tambien la fila, y entre
        ///   una cosa y otra hay una ventana en la que la base apunta a un
        ///   blob que ya no esta.
        ///
        ///   El costo es que se pierde la version anterior. Si algun dia hace
        ///   falta conservarla, lo que corresponde es activar el versionado
        ///   del contenedor en Azure, no inventar rutas nuevas aca.
        /// </summary>
        public ResultadoBlob Actualizar(string ruta, byte[] contenido, string mime)
        {
            Exigir();

            if (contenido == null || contenido.Length == 0)
                throw new Exception("El archivo esta vacio.");

            ContenidoBlob antes = Propiedades(ruta);

            if (!antes.existe)
                throw new Exception("No hay ningun archivo en esa ruta: no se puede actualizar. " +
                                    "Para uno nuevo, use la subida.");

            string contenedor, blob;
            Partir(ruta, out contenedor, out blob);

            using (WebClient wc = Preparar())
            {
                wc.Headers["x-ms-blob-type"] = "BlockBlob";

                /* Sin mime nuevo se conserva el que tenia: actualizar el
                   contenido de un PDF no deberia convertirlo en
                   application/octet-stream y dejar de poder verse. */
                string tipo = string.IsNullOrEmpty(mime) ? antes.mime : mime;

                if (!string.IsNullOrEmpty(tipo))
                    wc.Headers[HttpRequestHeader.ContentType] = tipo;

                wc.UploadData(Url(contenedor, blob), "PUT", contenido);
            }

            ResultadoBlob resultado = new ResultadoBlob();

            resultado.ruta = contenedor + "/" + blob;
            resultado.tamano = contenido.LongLength;
            resultado.mime = string.IsNullOrEmpty(mime) ? antes.mime : mime;
            resultado.hash = Hash(contenido);

            return resultado;
        }

        /// <summary>
        /// Borra el blob.
        ///
        /// Un blob que ya no está NO es un error: el resultado que se quería
        /// —que no exista— ya se cumplió, y hacer fallar el borrado deja a
        /// quien llama sin forma de limpiar una referencia rota.
        /// </summary>
        public void Eliminar(string ruta)
        {
            Exigir();

            string contenedor, blob;
            Partir(ruta, out contenedor, out blob);

            try
            {
                using (WebClient wc = Preparar())
                {
                    wc.UploadData(Url(contenedor, blob), "DELETE", new byte[0]);
                }
            }
            catch (WebException ex)
            {
                if (Codigo(ex) == HttpStatusCode.NotFound) return;
                throw;
            }
        }


        /* ====================================================================
           LO DE ADENTRO
           ==================================================================== */

        private void Exigir()
        {
            if (!Disponible) throw new Exception(Motivo);
        }

        /// <summary>
        /// "sigma/1/permisos-trabajo/abc.pdf" -> contenedor "sigma",
        /// blob "1/permisos-trabajo/abc.pdf".
        ///
        /// Sin contenedor delante se usa el de Web.config, para que una ruta
        /// escrita a mano no termine creando un contenedor con nombre de
        /// cliente.
        /// </summary>
        private void Partir(string ruta, out string contenedor, out string blob)
        {
            if (string.IsNullOrEmpty(ruta))
                throw new Exception("Falta la ruta del archivo.");

            ruta = ruta.Replace('\\', '/').TrimStart('/');

            /* Un ".." en la ruta permitiría salir del contenedor. La ruta la
               arma la web, pero este endpoint recibe de la red: se comprueba
               igual. */
            if (ruta.IndexOf("..", StringComparison.Ordinal) >= 0)
                throw new Exception("La ruta del archivo no es válida.");

            int corte = ruta.IndexOf('/');

            if (corte <= 0)
            {
                contenedor = ContenedorPorOmision();
                blob = ruta;
            }
            else
            {
                contenedor = ruta.Substring(0, corte);
                blob = ruta.Substring(corte + 1);
            }

            if (string.IsNullOrEmpty(blob))
                throw new Exception("La ruta del archivo no incluye el nombre.");
        }

        /// <summary>El ultimo segmento de la ruta, que es el nombre.</summary>
        private static string NombreDe(string blob)
        {
            if (string.IsNullOrEmpty(blob)) return "archivo";

            int corte = blob.LastIndexOf('/');

            return corte < 0 ? blob : blob.Substring(corte + 1);
        }

        private string Url(string contenedor, string blob)
        {
            /* Cada segmento se escapa por separado: EscapeDataString sobre la
               ruta entera convertiría los '/' en %2F y el blob quedaría con
               un nombre que no es el que se pidió. */
            string[] partes = blob.Split('/');

            for (int i = 0; i < partes.Length; i++)
                partes[i] = Uri.EscapeDataString(partes[i]);

            return Endpoint() + "/" + Uri.EscapeDataString(contenedor) + "/" +
                   string.Join("/", partes) + "?" + Sas();
        }

        /// <summary>
        /// Crea el contenedor si no existe. Un 409 significa que ya estaba,
        /// que es el caso normal a partir del segundo archivo.
        /// </summary>
        private void AsegurarContenedor(string contenedor)
        {
            try
            {
                using (WebClient wc = Preparar())
                {
                    string url = Endpoint() + "/" + Uri.EscapeDataString(contenedor) +
                                 "?restype=container&" + Sas();

                    wc.UploadData(url, "PUT", new byte[0]);
                }
            }
            catch (WebException ex)
            {
                HttpStatusCode codigo = Codigo(ex);

                if (codigo == HttpStatusCode.Conflict) return;

                /* Un SAS acotado a un contenedor no puede crear contenedores y
                   devuelve 403. No es un fallo si el contenedor ya existe: se
                   sigue, y si de verdad falta, la subida dará su propio error. */
                if (codigo == HttpStatusCode.Forbidden) return;

                throw;
            }
        }

        private WebClient Preparar()
        {
            /* TLS 1.2: .NET Framework 4.8 hereda el valor del sistema y en un
               servidor viejo puede seguir en TLS 1.0, con el que Azure Storage
               ya no habla. El síntoma es "Se ha forzado el cierre de la
               conexión", que no menciona TLS por ningún lado. */
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;

            WebClient wc = new WebClient();
            wc.Headers["x-ms-version"] = VERSION_REST;

            return wc;
        }

        private HttpStatusCode Codigo(WebException ex)
        {
            HttpWebResponse respuesta = ex.Response as HttpWebResponse;

            return respuesta == null ? 0 : respuesta.StatusCode;
        }

        /// <summary>
        /// SHA-256 del contenido, para poder detectar después que un archivo
        /// se corrompió o se cambió.
        /// </summary>
        public static string Hash(byte[] contenido)
        {
            if (contenido == null || contenido.Length == 0) return "";

            using (SHA256 sha = SHA256.Create())
            {
                byte[] resumen = sha.ComputeHash(contenido);

                StringBuilder sb = new StringBuilder(resumen.Length * 2);

                for (int i = 0; i < resumen.Length; i++)
                    sb.Append(resumen[i].ToString("x2"));

                return sb.ToString();
            }
        }
    }
}
