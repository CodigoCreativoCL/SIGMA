using System;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Web.Script.Serialization;

namespace SitioBase
{
    /// <summary>
    /// Lo que devuelve una subida: los datos que hay que guardar en la
    /// tabla Archivo. Nada más — el binario ya quedó del otro lado.
    /// </summary>
    [Serializable]
    public class ResultadoSubida
    {
        public string ruta { get; set; }               // contenedor/carpeta/nombre
        public string nombre_almacenado { get; set; }
        public string hash { get; set; }               // SHA-256 en hexadecimal
        public long tamano { get; set; }
        public string mime { get; set; }
        public string extension { get; set; }
    }

    /// <summary>
    /// El almacenamiento de binarios de SIGMA.
    ///
    /// POR QUÉ ES UNA INTERFAZ Y NO UNA CLASE
    ///   Los binarios van a Blob Storage, pero quien habla con Azure NO es
    ///   este sitio: es una API .NET aparte, que además atiende a la app
    ///   móvil. Que la web y la app suban por caminos distintos garantizaría
    ///   que un día un archivo quede en un contenedor que la otra no mira.
    ///
    ///   Mientras esa API no exista, el sitio tiene que compilar, abrir y
    ///   decir la verdad sobre lo que puede y no puede hacer. Por eso hay
    ///   una interfaz con Disponible: quien vaya a ofrecer una subida
    ///   pregunta primero, y si no se puede lo dice en pantalla en vez de
    ///   fallar al guardar.
    /// </summary>
    public interface IAlmacenamiento
    {
        /// <summary>
        /// Falso mientras el proveedor no esté configurado. Quien vaya a
        /// ofrecer una subida DEBE preguntar antes.
        /// </summary>
        bool Disponible { get; }

        /// <summary>Por qué no está disponible, para mostrárselo a quien corresponda.</summary>
        string Motivo { get; }

        ResultadoSubida Subir(int cliente, string carpeta, string nombreOriginal, byte[] contenido, string mime);

        byte[] Descargar(string ruta);

        void Eliminar(string ruta);
    }


    /// <summary>
    /// Fábrica. Devuelve la implementación configurada.
    /// </summary>
    public static class Almacenamiento
    {
        public static IAlmacenamiento Actual()
        {
            // Hoy hay una sola. Cuando existan varias (por ejemplo, una
            // local para desarrollo), este es el punto donde se elige, y
            // ningún controller se entera.
            return new AlmacenamientoApi();
        }

        /// <summary>
        /// SHA-256 en hexadecimal. Se calcula acá y no del otro lado para
        /// poder detectar el mismo contenido subido dos veces sin tener que
        /// bajarlo de vuelta.
        /// </summary>
        public static string Hash(byte[] contenido)
        {
            if (contenido == null || contenido.Length == 0) return null;

            using (SHA256 sha = SHA256.Create())
            {
                byte[] hash = sha.ComputeHash(contenido);
                StringBuilder sb = new StringBuilder(hash.Length * 2);
                for (int i = 0; i < hash.Length; i++) sb.Append(hash[i].ToString("x2"));
                return sb.ToString();
            }
        }

        /// <summary>
        /// Nombre con el que se guarda: un GUID más la extensión original.
        ///
        /// No se conserva el nombre que traía el archivo. Dos personas
        /// suben "comprobante.pdf" el mismo día y una pisaría a la otra; y
        /// un nombre elegido por quien sube es una ruta elegida por quien
        /// sube. El nombre original se guarda igual, en la columna
        /// arc_nombre_original, que es donde sirve: para mostrárselo a
        /// quien lo busca.
        /// </summary>
        public static string NombreAlmacenado(string nombreOriginal)
        {
            string extension = "";

            if (!string.IsNullOrEmpty(nombreOriginal))
            {
                extension = Path.GetExtension(nombreOriginal);
                if (extension != null && extension.Length > 20) extension = "";
            }

            return Guid.NewGuid().ToString("N") + extension;
        }
    }


    /// <summary>
    /// Cliente de la API de servicios Azure.
    ///
    /// ESTADO: PREPARADO, NO CONECTADO.
    ///   La API todavía no existe. El código de las tres operaciones está
    ///   escrito completo -es lo que hay que enchufar cuando esté- pero
    ///   Disponible devuelve falso mientras Web.config siga con el valor de
    ///   marcador, y Subir se niega en vez de intentar.
    ///
    ///   No se escribe a disco local como sustituto provisorio. Un
    ///   provisorio que funciona es un provisorio que se queda: quedaría un
    ///   comprobante de pago en el disco de un servidor que nadie respalda
    ///   y que la app móvil no puede leer. Es mejor que la pantalla diga
    ///   "todavía no se puede adjuntar" y que eso duela hasta que la API
    ///   esté.
    ///
    /// CONTRATO ESPERADO (ajustar cuando la API se defina)
    ///   POST   {url}/archivo    multipart o JSON con base64
    ///                           -> { "ruta": "...", "hash": "...", "tamano": 0 }
    ///   GET    {url}/archivo?ruta=...   -> el binario
    ///   DELETE {url}/archivo?ruta=...
    ///
    ///   Autenticación por cabecera X-Api-Key. Si la API termina usando
    ///   otra cosa, lo único que cambia es Preparar().
    /// </summary>
    public class AlmacenamientoApi : IAlmacenamiento
    {
        private const string MARCADOR = "PENDIENTE";

        private string Url()
        {
            return ConfigurationManager.AppSettings["AlmacenamientoApiUrl"];
        }

        private string Clave()
        {
            return ConfigurationManager.AppSettings["AlmacenamientoApiKey"];
        }

        private string Contenedor()
        {
            string valor = ConfigurationManager.AppSettings["AlmacenamientoContenedor"];
            return string.IsNullOrEmpty(valor) ? "sigma" : valor;
        }

        public bool Disponible
        {
            get
            {
                string url = Url();

                if (string.IsNullOrEmpty(url)) return false;
                if (url.IndexOf(MARCADOR, StringComparison.OrdinalIgnoreCase) >= 0) return false;

                return true;
            }
        }

        public string Motivo
        {
            get
            {
                if (Disponible) return "";

                return "El almacenamiento de archivos todavía no está configurado. " +
                       "La API de servicios Azure aún no existe y en Web.config " +
                       "AlmacenamientoApiUrl sigue con su valor de marcador.";
            }
        }

        public ResultadoSubida Subir(int cliente, string carpeta, string nombreOriginal, byte[] contenido, string mime)
        {
            if (contenido == null || contenido.Length == 0)
                throw new Exception("El archivo está vacío.");

            if (!Disponible)
                throw new Exception(Motivo);

            string nombreAlmacenado = Almacenamiento.NombreAlmacenado(nombreOriginal);

            /* La ruta la propone la web y la confirma la API. Se arma con el
               cliente adentro para que un contenedor mal configurado no
               termine mezclando comprobantes de dos empresas en la misma
               carpeta. */
            string ruta = Contenedor() + "/" + cliente.ToString() + "/" +
                          (string.IsNullOrEmpty(carpeta) ? "otros" : carpeta) + "/" +
                          nombreAlmacenado;

            Dictionary<string, object> cuerpo = new Dictionary<string, object>();
            cuerpo["ruta"] = ruta;
            cuerpo["nombre_original"] = nombreOriginal;
            cuerpo["mime"] = mime;
            cuerpo["contenido_base64"] = Convert.ToBase64String(contenido);

            JavaScriptSerializer js = new JavaScriptSerializer();
            js.MaxJsonLength = 64 * 1024 * 1024;

            string respuesta;

            using (WebClient wc = Preparar())
            {
                wc.Headers[HttpRequestHeader.ContentType] = "application/json";
                respuesta = wc.UploadString(Url().TrimEnd('/') + "/archivo", "POST", js.Serialize(cuerpo));
            }

            Dictionary<string, object> raiz = js.Deserialize<Dictionary<string, object>>(respuesta);

            if (raiz == null || !raiz.ContainsKey("ruta"))
                throw new Exception("El almacenamiento no devolvió la ruta del archivo.");

            ResultadoSubida resultado = new ResultadoSubida();

            resultado.ruta = Convert.ToString(raiz["ruta"]);
            resultado.nombre_almacenado = nombreAlmacenado;
            resultado.tamano = contenido.LongLength;
            resultado.mime = mime;
            resultado.extension = Path.GetExtension(nombreOriginal);

            /* El hash se calcula acá aunque la API también lo devuelva: es
               el del contenido que efectivamente se envió. */
            resultado.hash = Almacenamiento.Hash(contenido);

            return resultado;
        }

        public byte[] Descargar(string ruta)
        {
            if (!Disponible) throw new Exception(Motivo);
            if (string.IsNullOrEmpty(ruta)) throw new Exception("Falta la ruta del archivo.");

            using (WebClient wc = Preparar())
            {
                return wc.DownloadData(Url().TrimEnd('/') + "/archivo?ruta=" + Uri.EscapeDataString(ruta));
            }
        }

        public void Eliminar(string ruta)
        {
            if (!Disponible) throw new Exception(Motivo);
            if (string.IsNullOrEmpty(ruta)) throw new Exception("Falta la ruta del archivo.");

            using (WebClient wc = Preparar())
            {
                wc.UploadString(Url().TrimEnd('/') + "/archivo?ruta=" + Uri.EscapeDataString(ruta), "DELETE", "");
            }
        }

        private WebClient Preparar()
        {
            WebClient wc = new WebClient();

            wc.Encoding = Encoding.UTF8;

            string clave = Clave();
            if (!string.IsNullOrEmpty(clave)) wc.Headers["X-Api-Key"] = clave;

            return wc;
        }
    }
}
