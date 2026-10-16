using System;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Net;
using System.Text;
using System.Web.Script.Serialization;

namespace SitioBase
{
    /// <summary>
    /// Webpay Plus de Transbank por su API REST (v1.2), sin SDK (16-10-2026).
    ///
    /// AMBIENTE
    ///   appSettings WebpayAmbiente = INTEGRACION (modo de prueba, host
    ///   webpay3gint.transbank.cl) o PRODUCCION (webpay3g.transbank.cl), con
    ///   WebpayCodigoComercio y WebpayApiKey. Las credenciales NO van en el
    ///   código ni en el repo: en local, secretos.local.config; en producción,
    ///   el secreto INTRANET_APPSETTINGS_JSON del pipeline. Las de integración
    ///   son públicas (transbankdevelopers.cl), pero igual van por configuración.
    ///
    /// EL FLUJO
    ///   Crear  → token + url; el navegador hace POST de token_ws a esa url.
    ///   Transbank devuelve por GET a la URL de retorno con token_ws (o con
    ///   TBK_TOKEN si la persona anuló).
    ///   Confirmar (PUT) → resultado definitivo. Solo response_code = 0 y
    ///   status = AUTHORIZED es un pago aprobado.
    /// </summary>
    public static class Webpay
    {
        public class Transaccion { public string Token; public string Url; }

        public static string Ambiente()
        {
            string a = (ConfigurationManager.AppSettings["WebpayAmbiente"] ?? "").Trim().ToUpperInvariant();
            return a == "PRODUCCION" ? "PRODUCCION" : "INTEGRACION";
        }

        public static bool EsPrueba() { return Ambiente() != "PRODUCCION"; }

        public static bool Configurado()
        {
            return !string.IsNullOrWhiteSpace(ConfigurationManager.AppSettings["WebpayCodigoComercio"])
                && !string.IsNullOrWhiteSpace(ConfigurationManager.AppSettings["WebpayApiKey"]);
        }

        private static string Host()
        {
            return EsPrueba() ? "https://webpay3gint.transbank.cl" : "https://webpay3g.transbank.cl";
        }

        private const string RUTA = "/rswebpaytransaction/api/webpay/v1.2/transactions";

        public static Transaccion Crear(string buyOrder, string sessionId, decimal monto, string urlRetorno)
        {
            Dictionary<string, object> r = Llamar("POST", RUTA, new Dictionary<string, object>
            {
                { "buy_order", buyOrder }, { "session_id", sessionId }, { "amount", (long)Math.Round(monto) }, { "return_url", urlRetorno }
            });
            return new Transaccion { Token = Convert.ToString(r["token"]), Url = Convert.ToString(r["url"]) };
        }

        /// <summary>Confirma la transacción (commit). Devuelve la respuesta completa de Transbank.</summary>
        public static Dictionary<string, object> Confirmar(string token)
        {
            return Llamar("PUT", RUTA + "/" + Uri.EscapeDataString(token), null);
        }

        /// <summary>Estado de una transacción sin confirmarla (para el retorno anulado o una duda).</summary>
        public static Dictionary<string, object> Estado(string token)
        {
            return Llamar("GET", RUTA + "/" + Uri.EscapeDataString(token), null);
        }

        public static bool Aprobada(Dictionary<string, object> r)
        {
            object codigo, estado;
            return r != null && r.TryGetValue("response_code", out codigo) && codigo != null && Convert.ToInt32(codigo) == 0
                && r.TryGetValue("status", out estado) && string.Equals(Convert.ToString(estado), "AUTHORIZED", StringComparison.OrdinalIgnoreCase);
        }

        private static Dictionary<string, object> Llamar(string metodo, string ruta, Dictionary<string, object> cuerpo)
        {
            if (!Configurado()) throw new Exception("El pago en línea no está configurado (WebpayCodigoComercio y WebpayApiKey).");
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;   // Transbank exige TLS 1.2
            JavaScriptSerializer js = new JavaScriptSerializer();
            HttpWebRequest q = (HttpWebRequest)WebRequest.Create(Host() + ruta);
            q.Method = metodo;
            q.Timeout = 30000;
            q.Accept = "application/json";
            q.Headers["Tbk-Api-Key-Id"] = ConfigurationManager.AppSettings["WebpayCodigoComercio"].Trim();
            q.Headers["Tbk-Api-Key-Secret"] = ConfigurationManager.AppSettings["WebpayApiKey"].Trim();
            if (metodo != "GET")
            {
                byte[] datos = Encoding.UTF8.GetBytes(cuerpo != null ? js.Serialize(cuerpo) : "");
                q.ContentType = "application/json";
                q.ContentLength = datos.Length;
                if (datos.Length > 0) using (Stream s = q.GetRequestStream()) s.Write(datos, 0, datos.Length);
            }
            string texto;
            try
            {
                using (HttpWebResponse r = (HttpWebResponse)q.GetResponse())
                using (StreamReader sr = new StreamReader(r.GetResponseStream(), Encoding.UTF8)) texto = sr.ReadToEnd();
            }
            catch (WebException ex)
            {
                string detalle = "";
                if (ex.Response != null) using (StreamReader sr = new StreamReader(ex.Response.GetResponseStream(), Encoding.UTF8)) detalle = sr.ReadToEnd();
                Correo.Registrar("Webpay." + metodo + " " + ruta, ex.Message + " " + detalle);
                throw new Exception("Transbank no respondió como se esperaba. Intenta de nuevo en unos minutos.");
            }
            Dictionary<string, object> res = string.IsNullOrWhiteSpace(texto) ? new Dictionary<string, object>() : js.Deserialize<Dictionary<string, object>>(texto);
            res["_json"] = texto;
            return res;
        }
    }
}
