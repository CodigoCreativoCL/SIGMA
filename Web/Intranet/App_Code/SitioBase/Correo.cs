using System;
using System.Collections.Generic;
using System.Configuration;
using System.Net.Mail;
using System.Linq;
using System.Net.Mime;
using System.Text;
using SitioBase.Controller;

namespace SitioBase
{
    /// <summary>
    /// Envío de correo del sitio (Centro Comercial, 15-10-2026). Sale de lo
    /// que hacía CuentaController.EnviarCorreoRecuperacion, más adjuntos.
    ///
    /// NUNCA REVIENTA
    ///   Un correo que no sale no puede deshacer lo que ya pasó (el lead quedó
    ///   creado, el contrato quedó firmado). Devuelve false, deja el error en
    ///   Sis_Excepcion y quien llama decide qué decirle a la persona.
    ///
    /// EL SERVIDOR SMTP SE CONFIGURA EN Web.config (system.net/mailSettings)
    ///   y el remitente en appSettings CorreoRemitente / CorreoRemitenteNombre.
    /// </summary>
    public static class Correo
    {
        public class Adjunto
        {
            public string Nombre;
            public string Mime;
            public byte[] Contenido;
            public Adjunto(string nombre, string mime, byte[] contenido) { Nombre = nombre; Mime = mime; Contenido = contenido; }
        }

        /// <summary>
        /// El servidor SMTP. Si appSettings trae SmtpHost (y SmtpPuerto,
        /// SmtpUsuario, SmtpClave, SmtpSsl), manda eso; si no, mailSettings.
        /// Así la clave nunca va en el repo: en producción llega por el secreto
        /// INTRANET_APPSETTINGS_JSON del pipeline y en local por
        /// secretos.local.config (ignorado por git, ver Web.config appSettings).
        /// </summary>
        private static SmtpClient Cliente()
        {
            string host = ConfigurationManager.AppSettings["SmtpHost"];
            if (string.IsNullOrWhiteSpace(host)) return new SmtpClient();
            int puerto;
            if (!int.TryParse(ConfigurationManager.AppSettings["SmtpPuerto"], out puerto)) puerto = 587;
            SmtpClient c = new SmtpClient(host.Trim(), puerto);
            c.DeliveryMethod = SmtpDeliveryMethod.Network;
            c.EnableSsl = !string.Equals(ConfigurationManager.AppSettings["SmtpSsl"], "false", StringComparison.OrdinalIgnoreCase);
            FijarCertificado(ConfigurationManager.AppSettings["SmtpCertHuella"]);
            string u = ConfigurationManager.AppSettings["SmtpUsuario"];
            if (!string.IsNullOrEmpty(u))
            {
                c.UseDefaultCredentials = false;
                c.Credentials = new System.Net.NetworkCredential(u, ConfigurationManager.AppSettings["SmtpClave"]);
            }
            return c;
        }

        /// <summary>
        /// TEMPORAL (autorizado por Bryan, 16-10-2026, mientras se activa un
        /// certificado válido en Plesk). El buzón de HostChile presenta el
        /// certificado por defecto de Plesk, autofirmado y vencido. No se acepta
        /// cualquier certificado: la validación normal sigue igual y, además,
        /// se acepta SOLO el de huella SHA-1 = SmtpCertHuella. Sin esa clave en
        /// la configuración, este código no hace nada. Al instalar el
        /// certificado válido, borrar SmtpCertHuella.
        /// </summary>
        private static string _huella;
        private static void FijarCertificado(string huella)
        {
            huella = (huella ?? "").Replace(" ", "").Replace(":", "").Trim().ToUpperInvariant();
            if (huella.Length != 40 || huella == _huella) return;
            _huella = huella;
            System.Net.ServicePointManager.ServerCertificateValidationCallback = (sender, cert, cadena, errores) =>
                errores == System.Net.Security.SslPolicyErrors.None ||
                (cert != null && string.Equals(cert.GetCertHashString(), _huella, StringComparison.OrdinalIgnoreCase));
        }

        public static string UrlSitio()
        {
            string u = ConfigurationManager.AppSettings["UrlSitio"];
            return string.IsNullOrEmpty(u) ? "" : u.TrimEnd('/');
        }

        /// <summary>El motivo del último envío fallido en este hilo (lo guarda la cola para reintentar y mostrar por qué).</summary>
        [ThreadStatic] public static string UltimoError;
        [ThreadStatic] static bool _sinMonitor;

        /// <summary>
        /// Deja un correo en la cola (Correo_Cola) y lo intenta enviar de inmediato. Si el SMTP falla queda
        /// pendiente y el job CORREOS_COLA lo reintenta. Devuelve el id de la cola (0 si no había destinatario).
        /// </summary>
        public static int Encolar(string origen, IEnumerable<string> para, IEnumerable<string> copia, string asunto, string html, bool enviarYa = true)
        {
            string p = string.Join(",", (para ?? new string[0]).Where(x => !string.IsNullOrWhiteSpace(x)).Select(x => x.Trim()));
            if (p == "") return 0;
            string c = string.Join(",", (copia ?? new string[0]).Where(x => !string.IsNullOrWhiteSpace(x)).Select(x => x.Trim()));
            Dictionary<string, object> o = Cobros.SpSalida("INS_CORREO_COLA", "@ID", "@ORIGEN", origen, "@PARA", p, "@COPIA", c == "" ? null : c, "@ASUNTO", asunto, "@HTML", html);
            int id = Convert.ToInt32(o["@ID"]);
            if (enviarYa) { try { ProcesarCola(1, id); } catch (Exception ex) { Registrar("Correo.Encolar envío inmediato id=" + id, ex.Message); } }
            return id;
        }

        /// <summary>Envía lo que toca de la cola (o solo un id). Cada resultado queda anotado; los fallos se reintentan solos.</summary>
        public static int ProcesarCola(int tope, int? soloId)
        {
            int enviados = 0;
            foreach (Dictionary<string, object> f in SoporteDatos.Filas("SEL_CORREO_COLA_PENDIENTES", "@TOPE", tope, "@ID", soloId))
            {
                int id = Convert.ToInt32(f["ID"]);
                string[] para = Convert.ToString(f["PARA"]).Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
                string copiaTxt = f["COPIA"] == null ? "" : Convert.ToString(f["COPIA"]);
                string[] copia = copiaTxt.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
                UltimoError = null;
                bool ok = Enviar(para, copia.Length > 0 ? copia : null, Convert.ToString(f["ASUNTO"]), Convert.ToString(f["HTML"]));
                try { Cobros.Ejecutar("UPD_CORREO_COLA_RESULTADO", "@ID", id, "@OK", ok, "@ERROR", ok ? null : (UltimoError ?? "No se pudo enviar.")); }
                catch (Exception ex) { Registrar("Correo.ProcesarCola resultado id=" + id, ex.Message); }
                if (ok) enviados++;
            }
            return enviados;
        }

        public static bool Enviar(string para, string asunto, string html, params Adjunto[] adjuntos)
        {
            return Enviar(new[] { para }, null, asunto, html, adjuntos);
        }

        public static bool Enviar(IEnumerable<string> para, IEnumerable<string> copia, string asunto, string html, params Adjunto[] adjuntos)
        {
            string destino = string.Join(",", para ?? new string[0]);
            try
            {
                /* El remitente se cambia en la base (Sys_Parametros CORREO_REMITENTE
                   y CORREO_REMITENTE_NOMBRE, bloque 458) sin volver a publicar;
                   si están vacíos, manda el Web.config. */
                string remitente = Comercial.Parametro("CORREO_REMITENTE", ConfigurationManager.AppSettings["CorreoRemitente"]);
                string nombre = Comercial.Parametro("CORREO_REMITENTE_NOMBRE", ConfigurationManager.AppSettings["CorreoRemitenteNombre"]);
                if (string.IsNullOrEmpty(remitente)) remitente = "no-responder@sigma.cl";
                if (string.IsNullOrEmpty(nombre)) nombre = "SIGMA";

                using (MailMessage m = new MailMessage())
                {
                    m.From = new MailAddress(remitente, nombre);
                    foreach (string p in para ?? new string[0]) if (!string.IsNullOrWhiteSpace(p)) m.To.Add(p.Trim());
                    if (copia != null) foreach (string c in copia) if (!string.IsNullOrWhiteSpace(c)) m.CC.Add(c.Trim());
                    if (m.To.Count == 0) return false;
                    /* MODO DE PRUEBA DE CORREO: con appSettings CorreoRedirigirA todo el correo del sitio llega
                       a esa casilla (con los destinatarios reales en el asunto) y a nadie más. Es lo que se
                       usa en desarrollo, que comparte la base con el equipo y con clientes reales. */
                    string desvio = (ConfigurationManager.AppSettings["CorreoRedirigirA"] ?? "").Trim();
                    if (desvio != "")
                    {
                        string originales = string.Join(", ", m.To.Select(x => x.Address).Concat(m.CC.Select(x => x.Address)));
                        m.To.Clear(); m.CC.Clear(); m.To.Add(desvio);
                        asunto = "[→ " + originales + "] " + asunto;
                    }
                    /* MONITOREO: con appSettings CorreoMonitorearA esa casilla recibe copia oculta de TODO lo que
                       sale, y los destinatarios reales reciben el correo normalmente. Si la copia oculta es
                       rechazada, el mensaje se reintenta sin ella (ver el catch). */
                    string monitor = (ConfigurationManager.AppSettings["CorreoMonitorearA"] ?? "").Trim();
                    if (monitor != "" && !m.To.Concat(m.CC).Any(x => string.Equals(x.Address, monitor, StringComparison.OrdinalIgnoreCase)) && !_sinMonitor)
                        m.Bcc.Add(monitor);
                    m.Subject = asunto;
                    m.SubjectEncoding = Encoding.UTF8;
                    m.Body = html;
                    m.BodyEncoding = Encoding.UTF8;
                    m.IsBodyHtml = true;
                    foreach (Adjunto a in adjuntos ?? new Adjunto[0])
                    {
                        if (a == null || a.Contenido == null) continue;
                        Attachment at = new Attachment(new System.IO.MemoryStream(a.Contenido), a.Nombre, a.Mime);
                        if (a.Mime != null && a.Mime.StartsWith("text/calendar", StringComparison.OrdinalIgnoreCase))
                            at.ContentDisposition.DispositionType = DispositionTypeNames.Attachment;
                        m.Attachments.Add(at);
                    }
                    using (SmtpClient smtp = Cliente()) { smtp.Timeout = 15000; smtp.Send(m); }   // 15 s: un SMTP caído no deja colgada la firma
                }
                return true;
            }
            catch (Exception ex)
            {
                UltimoError = ex.Message;
                Registrar("Correo.Enviar para=" + destino + " asunto=" + asunto, ex.Message);
                /* Si el rechazo vino de la COPIA (por ejemplo, el buzón del ejecutivo no existe en este
                   servidor), el mensaje no se pierde: se reintenta una vez solo para el destinatario. */
                if (copia != null && System.Linq.Enumerable.Any(copia, c => !string.IsNullOrWhiteSpace(c)))
                    return Enviar(para, null, asunto, html, adjuntos);
                if (!_sinMonitor && (ConfigurationManager.AppSettings["CorreoMonitorearA"] ?? "").Trim() != "")
                {
                    _sinMonitor = true;
                    try { return Enviar(para, null, asunto, html, adjuntos); } finally { _sinMonitor = false; }
                }
                return false;
            }
        }

        /// <summary>
        /// Un correo del Centro Comercial, con las piezas del diseño L
        /// (artefacto/L-Correos.dc.html), en el orden en que se pintan.
        /// </summary>
        public class Pieza
        {
            public string Pre;          // antetítulo morado en mayúsculas
            public string Titulo;
            public string Texto;        // párrafo principal (HTML ya escapado)
            public string[] Detalles;   // pares dato · valor (tabla gris)
            public string Usuario;      // caja de credenciales
            public string Clave;
            public string Adjunto;      // caja del PDF adjunto
            public int AdjuntoKb;
            public string Boton;
            public string Enlace;
            public string Cierre;       // párrafo gris después del botón (HTML)
            public string Pie;          // segunda línea del pie gris
        }

        private const string F = "font-family:Sora,'Segoe UI',Arial,sans-serif;";

        /// <summary>
        /// El HTML del correo, copia del diseño L: 600 px, cabecera con logo,
        /// antetítulo, título, párrafo, tabla de datos, credenciales o adjunto,
        /// un solo botón morado, cierre y pie gris. Tablas y estilos en línea,
        /// que es lo único que respetan todos los clientes de correo.
        /// </summary>
        public static string Plantilla(Pieza m)
        {
            StringBuilder s = new StringBuilder();
            s.Append("<div style=\"margin:0;padding:24px 0;background:#E9ECF2;" + F + "color:#17223B\">");
            s.Append("<table role=\"presentation\" width=\"600\" align=\"center\" cellpadding=\"0\" cellspacing=\"0\" style=\"width:600px;max-width:100%;background:#FFFFFF;border-radius:4px;border-collapse:separate;box-shadow:0 1px 3px rgba(23,34,59,.1)\">");
            s.Append("<tr><td style=\"padding:22px 32px;border-bottom:1px solid #E2E7F0\"><table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\"><tr>");
            s.Append("<td style=\"" + F + "font-size:20px;font-weight:800;letter-spacing:.08em;color:#17223B\">SIGMA</td>");
            s.Append("<td align=\"right\" style=\"" + F + "font-size:11px;color:#68738A\">Código Creativo</td></tr></table></td></tr>");
            s.Append("<tr><td style=\"padding:30px 32px 26px;" + F + "\">");
            if (!string.IsNullOrEmpty(m.Pre))
                s.Append("<div style=\"font-size:11px;font-weight:800;letter-spacing:.08em;text-transform:uppercase;color:#5426D9;margin:0 0 8px\">" + Html(m.Pre) + "</div>");
            s.Append("<h1 style=\"margin:0 0 16px;font-size:22px;line-height:1.3;font-weight:700;color:#17223B\">" + Html(m.Titulo) + "</h1>");
            if (!string.IsNullOrEmpty(m.Texto))
                s.Append("<p style=\"margin:0 0 16px;font-size:14px;line-height:1.65;color:#4A556D\">" + m.Texto + "</p>");
            if (m.Detalles != null && m.Detalles.Length > 1)
            {
                s.Append("<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"border-collapse:separate;font-size:13px;background:#F4F6FA;border-radius:10px;margin:0 0 16px\">");
                for (int i = 0; i + 1 < m.Detalles.Length; i += 2)
                    if (!string.IsNullOrEmpty(m.Detalles[i + 1]))
                        s.Append("<tr><td style=\"padding:9px 14px;color:#68738A;width:130px;" + F + "\">" + Html(m.Detalles[i]) +
                                 "</td><td style=\"padding:9px 14px;font-weight:700;color:#17223B;" + F + "\">" + Html(m.Detalles[i + 1]) + "</td></tr>");
                s.Append("</table>");
            }
            if (!string.IsNullOrEmpty(m.Clave))
            {
                s.Append("<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"border-collapse:separate;border:1px solid #E2E7F0;border-radius:10px;font-size:13px;margin:0 0 16px\">");
                s.Append("<tr><td style=\"padding:14px 16px 4px;color:#68738A;width:120px;" + F + "\">Usuario</td><td style=\"padding:14px 16px 4px;font-weight:700;" + F + "\">" + Html(m.Usuario) + "</td></tr>");
                s.Append("<tr><td style=\"padding:4px 16px;color:#68738A;" + F + "\">Clave temporal</td><td style=\"padding:4px 16px;font-weight:700;font-family:Consolas,Menlo,monospace;letter-spacing:.04em\">" + Html(m.Clave) + "</td></tr>");
                s.Append("<tr><td colspan=\"2\" style=\"padding:4px 16px 14px;font-size:12px;color:#68738A;" + F + "\">Al entrar te pediremos crear tu propia contraseña.</td></tr></table>");
            }
            if (!string.IsNullOrEmpty(m.Adjunto))
                s.Append("<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"border-collapse:separate;border:1px solid #E2E7F0;border-radius:10px;font-size:13px;margin:0 0 16px\"><tr>" +
                         "<td style=\"padding:10px 14px;" + F + "\"><span style=\"color:#C7352B;font-weight:800\">PDF</span>&nbsp;&nbsp;<b>" + Html(m.Adjunto) + "</b>" +
                         (m.AdjuntoKb > 0 ? "&nbsp;&nbsp;<span style=\"color:#68738A\">" + m.AdjuntoKb + " KB</span>" : "") + "</td></tr></table>");
            if (!string.IsNullOrEmpty(m.Boton) && !string.IsNullOrEmpty(m.Enlace))
                s.Append("<table role=\"presentation\" cellpadding=\"0\" cellspacing=\"0\" style=\"margin:0 0 16px\"><tr><td style=\"border-radius:10px;background:#6732F4\">" +
                         "<a href=\"" + Html(m.Enlace) + "\" style=\"display:inline-block;padding:13px 22px;border-radius:10px;background:#6732F4;color:#FFFFFF;font-size:14px;font-weight:700;text-decoration:none;" + F + "\">" +
                         Html(m.Boton) + "</a></td></tr></table>");
            if (!string.IsNullOrEmpty(m.Cierre))
                s.Append("<p style=\"margin:0;font-size:13px;line-height:1.6;color:#68738A\">" + m.Cierre + "</p>");
            s.Append("</td></tr>");
            s.Append("<tr><td style=\"padding:16px 32px 22px;background:#F4F6FA;font-size:11px;line-height:1.6;color:#68738A;" + F + "\">Código Creativo SpA · Santiago, Chile" +
                     (string.IsNullOrEmpty(m.Pie) ? "" : "<br>" + Html(m.Pie)) + "</td></tr>");
            s.Append("</table></div>");
            return s.ToString();
        }

        public static string Html(string s) { return System.Web.HttpUtility.HtmlEncode(s ?? ""); }

        public static void Registrar(string variables, string mensaje)
        {
            try
            {
                using (System.Data.SqlClient.SqlCommand cmd = Conexion.GetCommand("INS_EXCEPCION"))
                {
                    cmd.Parameters.AddWithValue("@CODIGO", 0).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@VARIABLES", variables ?? "");
                    cmd.Parameters.AddWithValue("@MSG", mensaje ?? "");
                    try { cmd.ExecuteNonQuery(); }
                    finally { if (cmd.Connection != null) cmd.Connection.Close(); }
                }
            }
            catch
            {
                // INS_EXCEPCION termina en RAISERROR: la fila ya quedó escrita.
            }
        }
    }
}
