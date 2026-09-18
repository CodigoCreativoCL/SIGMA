using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;

namespace API.Utils
{
    /// <summary>
    /// El cliente de Azure Machine Learning de la API. Solo LEE: el área de
    /// trabajo, los modelos registrados, los experimentos y sus corridas.
    ///
    /// LO QUE CUESTA: NADA
    ///   Todo lo que se llama acá es el plano de control (management.azure.com)
    ///   y el servidor de seguimiento de MLflow del área de trabajo. Ninguno
    ///   de los dos se factura; lo que se factura en Azure ML es el CÓMPUTO
    ///   —instancias, clústeres, endpoints— y este módulo no crea ninguno.
    ///   El entrenamiento corre en el equipo de quien entrena
    ///   (`ML/entrenar_falla.py`) y la puntuación dentro de esta API
    ///   (`PuntuadorFalla`); Azure ML es el registro y la trazabilidad.
    ///
    /// COMO SE AUTENTICA
    ///   Con una entidad de servicio (app registration) que tiene el rol
    ///   «AzureML Data Scientist» sobre el área de trabajo: client
    ///   credentials contra login.microsoftonline.com. Las cuatro claves
    ///   viven en Web.config (AzureML.*); mientras digan PENDIENTE este
    ///   módulo responde `Configurado = false` y la pantalla lo dice tal
    ///   cual, sin intentar nada.
    /// </summary>
    public static class AzureMl
    {
        private const string API_VERSION = "2024-04-01";
        private const string MARCADOR = "PENDIENTE";

        private static string Leer(string clave)
        {
            string v = ConfigurationManager.AppSettings[clave];
            return string.IsNullOrEmpty(v) ? "" : v.Trim();
        }

        public static string TenantId       { get { return Leer("AzureML.TenantId"); } }
        public static string ClientId       { get { return Leer("AzureML.ClientId"); } }
        private static string ClientSecret  { get { return Leer("AzureML.ClientSecret"); } }
        public static string SubscriptionId { get { return Leer("AzureML.SubscriptionId"); } }
        public static string ResourceGroup  { get { return Leer("AzureML.ResourceGroup"); } }
        public static string Workspace      { get { return Leer("AzureML.Workspace"); } }
        public static string Region         { get { return Leer("AzureML.Region"); } }

        /// <summary>True cuando las siete claves están y ninguna dice PENDIENTE.</summary>
        public static bool Configurado
        {
            get
            {
                string[] v = { TenantId, ClientId, ClientSecret, SubscriptionId, ResourceGroup, Workspace, Region };
                foreach (string s in v)
                {
                    if (string.IsNullOrEmpty(s)) return false;
                    if (s.IndexOf(MARCADOR, StringComparison.OrdinalIgnoreCase) >= 0) return false;
                }
                return true;
            }
        }

        /// <summary>Qué falta, para decirlo en la pantalla.</summary>
        public static List<string> Faltantes()
        {
            List<string> f = new List<string>();
            string[] n = { "AzureML.TenantId", "AzureML.ClientId", "AzureML.ClientSecret", "AzureML.SubscriptionId", "AzureML.ResourceGroup", "AzureML.Workspace", "AzureML.Region" };
            foreach (string k in n)
            {
                string s = Leer(k);
                if (string.IsNullOrEmpty(s) || s.IndexOf(MARCADOR, StringComparison.OrdinalIgnoreCase) >= 0) f.Add(k);
            }
            return f;
        }

        /// <summary>El URI de seguimiento de MLflow que usa el entrenador (sin secretos).</summary>
        public static string MlflowUri
        {
            get
            {
                if (string.IsNullOrEmpty(Region) || string.IsNullOrEmpty(SubscriptionId)) return "";
                return "azureml://" + Region + ".api.azureml.ms/mlflow/v1.0/subscriptions/" + SubscriptionId +
                       "/resourceGroups/" + ResourceGroup + "/providers/Microsoft.MachineLearningServices/workspaces/" + Workspace;
            }
        }

        private static string BaseArm
        {
            get
            {
                return "https://management.azure.com/subscriptions/" + SubscriptionId + "/resourceGroups/" + ResourceGroup +
                       "/providers/Microsoft.MachineLearningServices/workspaces/" + Workspace;
            }
        }

        private static string BaseMlflow
        {
            get
            {
                return "https://" + Region + ".api.azureml.ms/mlflow/v2.0/subscriptions/" + SubscriptionId + "/resourceGroups/" + ResourceGroup +
                       "/providers/Microsoft.MachineLearningServices/workspaces/" + Workspace + "/api/2.0/mlflow";
            }
        }

        private static readonly HttpClient _http = Crear();

        private static HttpClient Crear()
        {
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
            HttpClient h = new HttpClient();
            h.Timeout = TimeSpan.FromSeconds(30);
            return h;
        }

        /* ====================================================================
           EL TOKEN
           ==================================================================== */

        private class TokenCache { public string valor; }

        private static string Token()
        {
            if (!Configurado)
                throw new InvalidOperationException("Azure ML no está configurado: faltan " + string.Join(", ", Faltantes()) + " en el Web.config de la API.");

            TokenCache t = CacheCorta.Obtener("azureml_token", () =>
            {
                Dictionary<string, string> form = new Dictionary<string, string>
                {
                    { "grant_type", "client_credentials" },
                    { "client_id", ClientId },
                    { "client_secret", ClientSecret },
                    { "scope", "https://management.azure.com/.default" }
                };
                HttpResponseMessage r = _http.PostAsync("https://login.microsoftonline.com/" + TenantId + "/oauth2/v2.0/token",
                                                        new FormUrlEncodedContent(form)).Result;
                string cuerpo = r.Content.ReadAsStringAsync().Result;
                if (!r.IsSuccessStatusCode)
                    throw new InvalidOperationException("Azure no entregó token (" + (int)r.StatusCode + "): " + Resumir(cuerpo));
                JObject j = JObject.Parse(cuerpo);
                return new TokenCache { valor = (string)j["access_token"] };
            }, 2700);

            return t.valor;
        }

        private static JToken Get(string url)
        {
            HttpRequestMessage req = new HttpRequestMessage(HttpMethod.Get, url);
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", Token());
            HttpResponseMessage r = _http.SendAsync(req).Result;
            string cuerpo = r.Content.ReadAsStringAsync().Result;
            if (!r.IsSuccessStatusCode)
                throw new InvalidOperationException("Azure ML respondió " + (int)r.StatusCode + " a " + Acortar(url) + ": " + Resumir(cuerpo));
            return string.IsNullOrEmpty(cuerpo) ? new JObject() : JToken.Parse(cuerpo);
        }

        private static JToken Post(string url, object cuerpoJson)
        {
            HttpRequestMessage req = new HttpRequestMessage(HttpMethod.Post, url);
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", Token());
            req.Content = new StringContent(Newtonsoft.Json.JsonConvert.SerializeObject(cuerpoJson), Encoding.UTF8, "application/json");
            HttpResponseMessage r = _http.SendAsync(req).Result;
            string cuerpo = r.Content.ReadAsStringAsync().Result;
            if (!r.IsSuccessStatusCode)
                throw new InvalidOperationException("Azure ML respondió " + (int)r.StatusCode + " a " + Acortar(url) + ": " + Resumir(cuerpo));
            return string.IsNullOrEmpty(cuerpo) ? new JObject() : JToken.Parse(cuerpo);
        }

        /* ====================================================================
           LO QUE SE CONSULTA
           ==================================================================== */

        /// <summary>El área de trabajo: nombre, región, estado, URI de MLflow.</summary>
        public static Dictionary<string, object> AreaTrabajo()
        {
            JToken j = Get(BaseArm + "?api-version=" + API_VERSION);
            JToken p = j["properties"] ?? new JObject();
            return new Dictionary<string, object>
            {
                { "nombre", (string)j["name"] },
                { "region", (string)j["location"] },
                { "estado", (string)p["provisioningState"] },
                { "mlflow", (string)p["mlFlowTrackingUri"] },
                { "almacenamiento", Ultimo((string)p["storageAccount"]) },
                { "descripcion", (string)p["description"] }
            };
        }

        /// <summary>Los modelos registrados, con su última versión.</summary>
        public static List<Dictionary<string, object>> Modelos()
        {
            List<Dictionary<string, object>> lista = new List<Dictionary<string, object>>();
            JToken j = Get(BaseArm + "/models?api-version=" + API_VERSION);
            foreach (JToken m in j["value"] ?? new JArray())
            {
                JToken p = m["properties"] ?? new JObject();
                lista.Add(new Dictionary<string, object>
                {
                    { "nombre", (string)m["name"] },
                    { "ultimaVersion", (string)p["latestVersion"] },
                    { "descripcion", (string)p["description"] },
                    { "modificado", (string)(m["systemData"] ?? new JObject())["lastModifiedAt"] }
                });
            }
            return lista;
        }

        /// <summary>Las versiones de un modelo registrado.</summary>
        public static List<Dictionary<string, object>> Versiones(string modelo)
        {
            List<Dictionary<string, object>> lista = new List<Dictionary<string, object>>();
            JToken j = Get(BaseArm + "/models/" + Uri.EscapeDataString(modelo) + "/versions?api-version=" + API_VERSION);
            foreach (JToken v in j["value"] ?? new JArray())
            {
                JToken p = v["properties"] ?? new JObject();
                lista.Add(new Dictionary<string, object>
                {
                    { "version", (string)v["name"] },
                    { "tipo", (string)p["modelType"] },
                    { "ruta", (string)p["modelUri"] },
                    { "corrida", (string)p["jobName"] },
                    { "etiquetas", p["tags"] != null ? p["tags"].ToString(Newtonsoft.Json.Formatting.None) : null },
                    { "creado", (string)(v["systemData"] ?? new JObject())["createdAt"] }
                });
            }
            return lista;
        }

        /// <summary>Los experimentos de MLflow del área de trabajo.</summary>
        public static List<Dictionary<string, object>> Experimentos()
        {
            List<Dictionary<string, object>> lista = new List<Dictionary<string, object>>();
            JToken j = Post(BaseMlflow + "/experiments/search", new { max_results = 50 });
            foreach (JToken e in j["experiments"] ?? new JArray())
            {
                lista.Add(new Dictionary<string, object>
                {
                    { "id", (string)e["experiment_id"] },
                    { "nombre", (string)e["name"] },
                    { "estado", (string)e["lifecycle_stage"] },
                    { "actualizado", Fecha(e["last_update_time"]) }
                });
            }
            return lista;
        }

        /// <summary>Las corridas de un experimento, con métricas y parámetros.</summary>
        public static List<Dictionary<string, object>> Corridas(string experimentoId)
        {
            List<Dictionary<string, object>> lista = new List<Dictionary<string, object>>();
            JToken j = Post(BaseMlflow + "/runs/search", new { experiment_ids = new[] { experimentoId }, max_results = 50, order_by = new[] { "attributes.start_time DESC" } });
            foreach (JToken r in j["runs"] ?? new JArray())
            {
                JToken info = r["info"] ?? new JObject();
                JToken data = r["data"] ?? new JObject();
                Dictionary<string, object> metricas = new Dictionary<string, object>();
                foreach (JToken m in data["metrics"] ?? new JArray()) metricas[(string)m["key"]] = (double?)m["value"];
                Dictionary<string, object> parametros = new Dictionary<string, object>();
                foreach (JToken p in data["params"] ?? new JArray()) parametros[(string)p["key"]] = (string)p["value"];

                lista.Add(new Dictionary<string, object>
                {
                    { "id", (string)info["run_id"] },
                    { "nombre", (string)info["run_name"] },
                    { "estado", (string)info["status"] },
                    { "inicio", Fecha(info["start_time"]) },
                    { "fin", Fecha(info["end_time"]) },
                    { "metricas", metricas },
                    { "parametros", parametros }
                });
            }
            return lista;
        }

        /* ====================================================================
           AYUDAS
           ==================================================================== */

        private static string Fecha(JToken ms)
        {
            if (ms == null || ms.Type == JTokenType.Null) return null;
            long v;
            if (!long.TryParse(ms.ToString(), out v)) return null;
            return DateTimeOffset.FromUnixTimeMilliseconds(v).UtcDateTime.ToString("yyyy-MM-dd HH:mm:ss") + " UTC";
        }

        private static string Ultimo(string recurso)
        {
            if (string.IsNullOrEmpty(recurso)) return null;
            int i = recurso.LastIndexOf('/');
            return i >= 0 ? recurso.Substring(i + 1) : recurso;
        }

        private static string Acortar(string url)
        {
            int i = url.IndexOf("/workspaces/", StringComparison.OrdinalIgnoreCase);
            return i >= 0 ? "..." + url.Substring(i) : url;
        }

        /// <summary>El error de Azure viene en JSON y largo; se deja lo que sirve.</summary>
        private static string Resumir(string cuerpo)
        {
            if (string.IsNullOrEmpty(cuerpo)) return "(sin cuerpo)";
            try
            {
                JObject j = JObject.Parse(cuerpo);
                JToken e = j["error"];
                if (e != null && e["message"] != null) return (string)e["message"];
                if (j["error_description"] != null) return (string)j["error_description"];
                if (j["message"] != null) return (string)j["message"];
            }
            catch (Exception) { }
            return cuerpo.Length > 300 ? cuerpo.Substring(0, 300) + "…" : cuerpo;
        }
    }
}
