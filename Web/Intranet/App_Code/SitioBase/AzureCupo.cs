using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;
using System.Web;
using System.Web.Caching;
using System.Web.Script.Serialization;
using System.Xml;

namespace SitioBase
{
    /// <summary>
    /// Cuánto queda del cupo gratuito de Azure SQL (100.000 segundos de vCore al mes).
    ///
    /// La cifra la da Azure Monitor (métrica free_amount_remaining de la base). Para leerla
    /// hace falta una credencial de Entra ID con el rol «Monitoring Reader»: vive en
    /// ~/azure.config, que escribe Dev\conectar_azure.ps1 y que NO se versiona. Sin ese
    /// archivo el indicador simplemente no aparece.
    ///
    /// Se cachea 10 minutos: la métrica se publica cada pocos minutos y no tiene sentido
    /// pedirle un token a Entra ID en cada pantalla.
    /// </summary>
    public static class AzureCupo
    {
        private const string CLAVE_CACHE = "SIGMA_AZURE_CUPO";

        public static object Leer()
        {
            object c = HttpRuntime.Cache[CLAVE_CACHE];
            if (c != null) return c;
            object r = Consultar();
            HttpRuntime.Cache.Insert(CLAVE_CACHE, r, null, DateTime.UtcNow.AddMinutes(10), Cache.NoSlidingExpiration);
            return r;
        }

        private static object Consultar()
        {
            string ruta = HttpContext.Current.Server.MapPath("~/azure.config");
            if (!File.Exists(ruta)) return new { activo = false };
            try
            {
                XmlDocument d = new XmlDocument();
                d.Load(ruta);
                XmlElement a = d.DocumentElement;
                string tenant = a.GetAttribute("tenant"), client = a.GetAttribute("client"), secret = a.GetAttribute("secret"), recurso = a.GetAttribute("recurso");
                decimal limite;
                if (!decimal.TryParse(a.GetAttribute("limite"), NumberStyles.Any, CultureInfo.InvariantCulture, out limite) || limite <= 0) limite = 100000;

                ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
                string token = Token(tenant, client, secret);

                DateTime ahora = DateTime.UtcNow, ini = new DateTime(ahora.Year, ahora.Month, 1, 0, 0, 0, DateTimeKind.Utc);
                string url = "https://management.azure.com" + recurso + "/providers/Microsoft.Insights/metrics?api-version=2018-01-01" +
                    "&metricnames=free_amount_remaining,free_amount_consumed&aggregation=Minimum,Maximum&interval=PT1H" +
                    "&timespan=" + Uri.EscapeDataString(ini.ToString("yyyy-MM-ddTHH:mm:ssZ") + "/" + ahora.ToString("yyyy-MM-ddTHH:mm:ssZ"));
                HttpWebRequest q = (HttpWebRequest)WebRequest.Create(url);
                q.Headers.Add("Authorization", "Bearer " + token);
                q.Timeout = 15000;
                Dictionary<string, object> j;
                using (WebResponse w = q.GetResponse())
                using (StreamReader sr = new StreamReader(w.GetResponseStream()))
                    j = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(sr.ReadToEnd());

                decimal? restante = Ultimo(j, "free_amount_remaining", "minimum"), consumido = Ultimo(j, "free_amount_consumed", "maximum");
                if (restante == null) return new { activo = true, ok = false, mensaje = "Azure todavía no publica el cupo de este mes (la base estuvo en pausa)." };

                // Ritmo: lo consumido dividido por los días transcurridos del mes, proyectado a fin de mes.
                double dias = Math.Max(1, (ahora - ini).TotalDays);
                decimal usado = consumido ?? (limite - restante.Value);
                decimal porDia = usado / (decimal)dias;
                int diasMes = DateTime.DaysInMonth(ahora.Year, ahora.Month);
                string alcanza = porDia > 0 && restante.Value / porDia < (decimal)(diasMes - ahora.Day + 1)
                    ? ahora.AddDays((double)(restante.Value / porDia)).ToString("dd-MM") : "";
                return new
                {
                    activo = true, ok = true,
                    restante = restante.Value, consumido = usado, limite = limite,
                    pct = Math.Round(restante.Value * 100m / limite, 0),
                    porDia = Math.Round(porDia, 0),
                    alcanzaHasta = alcanza,
                    renueva = ini.AddMonths(1).ToString("dd-MM"),
                    leido = Hora.Ahora.ToString("HH:mm")
                };
            }
            catch (Exception ex)
            {
                return new { activo = true, ok = false, mensaje = "No se pudo leer el cupo de Azure: " + ex.Message };
            }
        }

        private static string Token(string tenant, string client, string secret)
        {
            HttpWebRequest t = (HttpWebRequest)WebRequest.Create("https://login.microsoftonline.com/" + Uri.EscapeDataString(tenant) + "/oauth2/v2.0/token");
            t.Method = "POST";
            t.ContentType = "application/x-www-form-urlencoded";
            t.Timeout = 15000;
            byte[] cuerpo = Encoding.UTF8.GetBytes("grant_type=client_credentials&client_id=" + Uri.EscapeDataString(client) +
                "&client_secret=" + Uri.EscapeDataString(secret) + "&scope=" + Uri.EscapeDataString("https://management.azure.com/.default"));
            using (Stream s = t.GetRequestStream()) s.Write(cuerpo, 0, cuerpo.Length);
            using (WebResponse w = t.GetResponse())
            using (StreamReader sr = new StreamReader(w.GetResponseStream()))
            {
                Dictionary<string, object> j = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(sr.ReadToEnd());
                return Convert.ToString(j["access_token"]);
            }
        }

        /// <summary>El último valor con dato de la métrica (los cubos de una base en pausa vienen vacíos).</summary>
        private static decimal? Ultimo(Dictionary<string, object> j, string metrica, string agregacion)
        {
            foreach (object v in Lista(j, "value"))
            {
                Dictionary<string, object> m = v as Dictionary<string, object>;
                if (m == null) continue;
                Dictionary<string, object> nombre = m["name"] as Dictionary<string, object>;
                if (nombre == null || Convert.ToString(nombre["value"]) != metrica) continue;
                foreach (object ts in Lista(m, "timeseries"))
                {
                    List<object> datos = Lista(ts as Dictionary<string, object>, "data");
                    for (int i = datos.Count - 1; i >= 0; i--)
                    {
                        Dictionary<string, object> p = datos[i] as Dictionary<string, object>;
                        if (p != null && p.ContainsKey(agregacion) && p[agregacion] != null)
                            return Convert.ToDecimal(p[agregacion], CultureInfo.InvariantCulture);
                    }
                }
            }
            return null;
        }

        private static List<object> Lista(Dictionary<string, object> d, string k)
        {
            List<object> l = new List<object>();
            if (d == null || !d.ContainsKey(k) || d[k] == null) return l;
            System.Collections.IEnumerable e = d[k] as System.Collections.IEnumerable;
            if (e != null) foreach (object x in e) l.Add(x);
            return l;
        }
    }
}
