using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Net;
using System.Net.Http;

namespace API.Utils
{
    /// <summary>
    /// SIGMA VISION · el cliente de Azure Custom Vision.
    ///
    /// POR QUE CUSTOM VISION Y NO UN MODELO PROPIO
    ///   Clasificar fotos de terreno (corrosión, fuga, desgaste, normal…)
    ///   exige una red convolucional; entrenarla en el equipo de quien
    ///   entrena es posible pero lento y puntuarla dentro de esta API
    ///   exigiría ONNX Runtime. Custom Vision entrena en la nube en el nivel
    ///   F0 —gratis: 2 proyectos, 5.000 imágenes, 1 h de entrenamiento y
    ///   10.000 predicciones al mes—, se usa con CLAVES (no necesita Entra
    ///   ID) y exporta el modelo a ONNX, así que el registro en Azure ML y
    ///   el hash siguen igual que en los otros dos modelos.
    ///
    /// LO QUE HACE ESTA CLASE
    ///   Solo predecir: manda los bytes de una imagen a la iteración
    ///   publicada y devuelve las etiquetas con su probabilidad. El
    ///   entrenamiento (subir imágenes etiquetadas, entrenar, publicar,
    ///   exportar) lo hace `ML/entrenar_vision.py` con la clave de
    ///   entrenamiento, fuera de la API.
    ///
    ///   Claves en Web.config (CustomVision.*); mientras digan PENDIENTE,
    ///   `Configurado` es false y la pantalla lo dice tal cual.
    /// </summary>
    public static class CustomVision
    {
        private const string MARCADOR = "PENDIENTE";

        private static string Leer(string clave)
        {
            string v = ConfigurationManager.AppSettings[clave];
            return string.IsNullOrEmpty(v) ? "" : v.Trim();
        }

        /// <summary>https://<recurso>.cognitiveservices.azure.com (el de predicción).</summary>
        public static string Endpoint       { get { return Leer("CustomVision.PredictionEndpoint").TrimEnd('/'); } }
        private static string PredictionKey { get { return Leer("CustomVision.PredictionKey"); } }
        public static string ProjectId      { get { return Leer("CustomVision.ProjectId"); } }
        public static string Iteracion      { get { return Leer("CustomVision.IterationName"); } }

        public static bool Configurado
        {
            get
            {
                string[] v = { Endpoint, PredictionKey, ProjectId, Iteracion };
                foreach (string s in v)
                {
                    if (string.IsNullOrEmpty(s)) return false;
                    if (s.IndexOf(MARCADOR, StringComparison.OrdinalIgnoreCase) >= 0) return false;
                }
                return true;
            }
        }

        public static List<string> Faltantes()
        {
            List<string> f = new List<string>();
            foreach (string k in new[] { "CustomVision.PredictionEndpoint", "CustomVision.PredictionKey", "CustomVision.ProjectId", "CustomVision.IterationName" })
            {
                string s = Leer(k);
                if (string.IsNullOrEmpty(s) || s.IndexOf(MARCADOR, StringComparison.OrdinalIgnoreCase) >= 0) f.Add(k);
            }
            return f;
        }

        public class Etiqueta
        {
            public string nombre { get; set; }
            public double probabilidad { get; set; }
        }

        private static readonly HttpClient _http = Crear();

        private static HttpClient Crear()
        {
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
            HttpClient h = new HttpClient();
            h.Timeout = TimeSpan.FromSeconds(60);
            return h;
        }

        /// <summary>
        /// Clasifica una imagen con la iteración publicada. Devuelve las
        /// etiquetas ordenadas de mayor a menor probabilidad.
        /// </summary>
        public static List<Etiqueta> Clasificar(byte[] imagen)
        {
            if (!Configurado)
                throw new InvalidOperationException("Custom Vision no está configurado: faltan " + string.Join(", ", Faltantes()) + " en el Web.config de la API.");
            if (imagen == null || imagen.Length == 0)
                throw new ArgumentException("La imagen viene vacía.");

            string url = Endpoint + "/customvision/v3.0/Prediction/" + ProjectId + "/classify/iterations/" + Uri.EscapeDataString(Iteracion) + "/image";

            HttpRequestMessage req = new HttpRequestMessage(HttpMethod.Post, url);
            req.Headers.Add("Prediction-Key", PredictionKey);
            req.Content = new ByteArrayContent(imagen);
            req.Content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("application/octet-stream");

            HttpResponseMessage r = _http.SendAsync(req).Result;
            string cuerpo = r.Content.ReadAsStringAsync().Result;
            if (!r.IsSuccessStatusCode)
                throw new InvalidOperationException("Custom Vision respondió " + (int)r.StatusCode + ": " + Resumir(cuerpo));

            List<Etiqueta> lista = new List<Etiqueta>();
            JObject j = JObject.Parse(cuerpo);
            foreach (JToken p in j["predictions"] ?? new JArray())
                lista.Add(new Etiqueta { nombre = (string)p["tagName"], probabilidad = (double?)p["probability"] ?? 0 });

            lista.Sort((a, b) => b.probabilidad.CompareTo(a.probabilidad));
            return lista;
        }

        private static string Resumir(string cuerpo)
        {
            if (string.IsNullOrEmpty(cuerpo)) return "(sin cuerpo)";
            try
            {
                JObject j = JObject.Parse(cuerpo);
                if (j["message"] != null) return (string)j["message"];
                if (j["error"] != null && j["error"]["message"] != null) return (string)j["error"]["message"];
            }
            catch (Exception) { }
            return cuerpo.Length > 300 ? cuerpo.Substring(0, 300) + "…" : cuerpo;
        }
    }
}
