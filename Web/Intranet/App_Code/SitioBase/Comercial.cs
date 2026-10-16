using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Web;

namespace SitioBase
{
    /// <summary>
    /// Centro Comercial (15-10-2026): lo que comparten WsComercial.asmx y la
    /// página pública de firma (Firma.aspx). Tokens, documentos, correos,
    /// invitaciones .ics y validación de RUT.
    ///
    /// LOS DOCUMENTOS SALEN DE HTML
    ///   La propuesta y el contrato se arman como HTML y se convierten con
    ///   ConvertHtml (Winnovative, ya licenciado en el sitio). El contrato
    ///   firmado es el PDF ORIGINAL, intacto, más una hoja de constancia: así
    ///   el SHA-256 del documento que la persona leyó sigue siendo verificable.
    ///
    /// LOS TOKENS NO SE GUARDAN
    ///   Viajan en el enlace (32 bytes aleatorios, base64url) y en la base
    ///   queda solo su SHA-256. Quien lea la base no puede firmar por nadie.
    /// </summary>
    public static class Comercial
    {
        public static readonly CultureInfo CL = new CultureInfo("es-CL");

        public static readonly string[][] MODULOS =
        {
            new[] { "MANTENIMIENTO", "Mantenimiento" }, new[] { "OT", "Órdenes de trabajo" }, new[] { "PLANIFICACION", "Planificación" },
            new[] { "INSPECCION", "Inspección" }, new[] { "INVENTARIO", "Inventario" }, new[] { "SIGMA_AI", "SIGMA AI" },
            new[] { "SIGMA_TWIN", "SIGMA Twin" }
        };

        public static string NombreModulo(string codigo)
        {
            string[] m = MODULOS.FirstOrDefault(x => x[0] == (codigo ?? "").Trim());
            return m != null ? m[1] : codigo;
        }

        public static string NombresModulos(string lista)
        {
            return string.Join(", ", (lista ?? "").Split(',').Where(x => x.Trim().Length > 0).Select(NombreModulo));
        }

        // ------------------------------------------------------------ parámetros
        public static string Parametro(string codigo, string porDefecto)
        {
            try
            {
                Dictionary<string, object> f = SoporteDatos.Fila("SEL_SYS_PARAMETROS_CODIGO", "@CODIGO", codigo);
                object v; if (f.TryGetValue("VALOR", out v) && v != null && v.ToString().Trim().Length > 0) return v.ToString().Trim();
            }
            catch (Exception) { }
            return porDefecto;
        }

        // ------------------------------------------------------------ azar y hash
        public static string Token()
        {
            byte[] b = new byte[32];
            using (RandomNumberGenerator r = RandomNumberGenerator.Create()) r.GetBytes(b);
            return Convert.ToBase64String(b).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        }

        public static byte[] HashToken(string token)
        {
            using (SHA256 s = SHA256.Create()) return s.ComputeHash(Encoding.UTF8.GetBytes(token ?? ""));
        }

        public static string Sha256(byte[] datos)
        {
            using (SHA256 s = SHA256.Create()) return BitConverter.ToString(s.ComputeHash(datos ?? new byte[0])).Replace("-", "").ToLowerInvariant();
        }

        public static string Sha256(string texto) { return Sha256(Encoding.UTF8.GetBytes(texto ?? "")); }

        /// <summary>Clave temporal legible: sin 0/O ni 1/l, con mayúscula, minúscula, número y símbolo.</summary>
        public static string ClaveTemporal()
        {
            const string may = "ABCDEFGHJKLMNPQRSTUVWXYZ", min = "abcdefghijkmnpqrstuvwxyz", num = "23456789", sim = "#$%&*+?";
            string todo = may + min + num;
            byte[] b = new byte[12];
            using (RandomNumberGenerator r = RandomNumberGenerator.Create()) r.GetBytes(b);
            StringBuilder s = new StringBuilder();
            s.Append(may[b[0] % may.Length]).Append(min[b[1] % min.Length]).Append(num[b[2] % num.Length]).Append(sim[b[3] % sim.Length]);
            for (int i = 4; i < 12; i++) s.Append(todo[b[i] % todo.Length]);
            // Mezcla para que el símbolo no quede siempre en la misma posición.
            char[] c = s.ToString().ToCharArray();
            byte[] m = new byte[c.Length];
            using (RandomNumberGenerator r = RandomNumberGenerator.Create()) r.GetBytes(m);
            for (int i = c.Length - 1; i > 0; i--) { int j = m[i] % (i + 1); char t = c[i]; c[i] = c[j]; c[j] = t; }
            return new string(c);
        }

        /// <summary>Clave de suscripción (la API la usa para identificar al cliente).</summary>
        public static string ClaveSuscripcion() { return Token(); }

        /// <summary>Sala de Jitsi Meet difícil de adivinar: SIGMA-&lt;empresa&gt;-&lt;6 al azar&gt;.</summary>
        public static string SalaJitsi(string empresa)
        {
            string limpio = new string((empresa ?? "Cliente").Normalize(NormalizationForm.FormD)
                .Where(ch => CharUnicodeInfo.GetUnicodeCategory(ch) != UnicodeCategory.NonSpacingMark).ToArray());
            limpio = new string(limpio.Where(char.IsLetterOrDigit).ToArray());
            if (limpio.Length > 24) limpio = limpio.Substring(0, 24);
            if (limpio.Length == 0) limpio = "Cliente";
            const string abc = "abcdefghijkmnpqrstuvwxyz23456789";
            byte[] b = new byte[6];
            using (RandomNumberGenerator r = RandomNumberGenerator.Create()) r.GetBytes(b);
            return "https://meet.jit.si/SIGMA-" + limpio + "-" + new string(b.Select(x => abc[x % abc.Length]).ToArray());
        }

        // ------------------------------------------------------------ RUT
        public static bool RutValido(string rut)
        {
            if (string.IsNullOrWhiteSpace(rut)) return false;
            string r = rut.Replace(".", "").Replace(" ", "").ToUpperInvariant();
            int guion = r.LastIndexOf('-');
            string cuerpo = guion > 0 ? r.Substring(0, guion) : r.Substring(0, r.Length - 1);
            string dv = guion > 0 ? r.Substring(guion + 1) : r.Substring(r.Length - 1);
            int n; if (dv.Length != 1 || !int.TryParse(cuerpo, out n) || n < 100000) return false;
            int suma = 0, mul = 2;
            for (int i = cuerpo.Length - 1; i >= 0; i--) { suma += (cuerpo[i] - '0') * mul; mul = mul == 7 ? 2 : mul + 1; }
            int res = 11 - (suma % 11);
            string esperado = res == 11 ? "0" : res == 10 ? "K" : res.ToString();
            return esperado == dv;
        }

        public static string RutNormal(string rut)
        {
            string r = (rut ?? "").Replace(".", "").Replace(" ", "").ToUpperInvariant();
            if (r.Length > 1 && r.IndexOf('-') < 0) r = r.Substring(0, r.Length - 1) + "-" + r.Substring(r.Length - 1);
            return r;
        }

        // ------------------------------------------------------------ formato
        public static string UF(object v) { return string.Format(CL, "{0:N1} UF", Convert.ToDecimal(v ?? 0)); }
        public static string UF2(object v) { return string.Format(CL, "{0:N2} UF", Convert.ToDecimal(v ?? 0)); }
        /// <summary>Monto en la moneda del lead o del cliente: «45,00 UF» o «USD 1.950,00» (nunca se mezclan).</summary>
        public static string Mon(object v, string moneda) { return moneda == "USD" ? string.Format(CL, "USD {0:N2}", Convert.ToDecimal(v ?? 0)) : UF2(v); }
        public static string Mon1(object v, string moneda) { return moneda == "USD" ? string.Format(CL, "USD {0:N2}", Convert.ToDecimal(v ?? 0)) : UF(v); }
        public static string Moneda(Dictionary<string, object> f) { return Txt(f, "MONEDA") == "USD" ? "USD" : "UF"; }
        /// <summary>El identificador tributario del lead según su país (RUT, RUC, NIT...); el RUT sigue valiendo para los antiguos.</summary>
        public static string IdLead(Dictionary<string, object> lead) { string i = Txt(lead, "IDENTIFICADOR"); return i != "" ? i : Txt(lead, "RUT"); }
        public static string EtiquetaId(Dictionary<string, object> lead) { string e = Txt(lead, "IDENTIFICADOR_NOMBRE"); return e != "" ? e : "RUT"; }
        public static decimal Dec(object v) { return v == null ? 0 : Convert.ToDecimal(v); }
        public static int Ent(object v) { return v == null ? 0 : Convert.ToInt32(v); }
        public static string Txt(Dictionary<string, object> f, string k) { object v; return f != null && f.TryGetValue(k, out v) && v != null ? v.ToString() : ""; }
        public static string Fecha(string iso)
        {
            DateTime d; return DateTime.TryParse(iso, CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? d.ToString("dd/MM/yyyy", CL) : iso;
        }
        public static string FechaHora(string iso)
        {
            DateTime d; return DateTime.TryParse(iso, CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? d.ToString("dd/MM/yyyy HH:mm", CL) : iso;
        }
        public static string Primero(string nombre) { return (nombre ?? "").Trim().Split(' ').FirstOrDefault() ?? ""; }

        /// <summary>Mensualidad con descuento, redondeada igual que el SP y el navegador.</summary>
        public static decimal MensualNeta(decimal mensual, decimal descuento) { return Math.Round(mensual * (100 - descuento) / 100, 2, MidpointRounding.AwayFromZero); }
        public static decimal Total(decimal impl, decimal mensual, decimal descuento, int meses) { return Math.Round(impl + MensualNeta(mensual, descuento) * meses, 2, MidpointRounding.AwayFromZero); }

        // ------------------------------------------------------------ documentos
        private const string CSS_DOC =
            "body{font-family:'Segoe UI',Arial,sans-serif;color:#17223B;font-size:12.5px;line-height:1.55;margin:0}" +
            "h1{font-size:22px;margin:0 0 4px}h2{font-size:14px;margin:22px 0 8px;padding-bottom:4px;border-bottom:1px solid #E2E7F0;color:#17223B}" +
            ".cab{display:table;width:100%;border-bottom:3px solid #6732F4;padding-bottom:12px;margin-bottom:18px}" +
            ".cab .l{display:table-cell;vertical-align:bottom}.cab .r{display:table-cell;text-align:right;vertical-align:bottom;color:#68738A;font-size:11px}" +
            ".marca{font-size:20px;font-weight:800;letter-spacing:.06em;color:#17223B}.marca small{font-size:11px;color:#68738A;letter-spacing:0;font-weight:600}" +
            "table.t{width:100%;border-collapse:collapse;margin:6px 0}table.t td{padding:6px 10px;border-bottom:1px solid #EEF1F6;vertical-align:top}" +
            "table.t td.k{color:#68738A;width:38%}table.t td.v{font-weight:700;text-align:right}table.t tr.tot td{border-top:2px solid #17223B;font-weight:800;font-size:13.5px}" +
            ".chip{display:inline-block;padding:2px 9px;margin:2px 4px 2px 0;border-radius:99px;background:#F2EFFF;color:#5426D9;font-weight:700;font-size:11px}" +
            "p{margin:0 0 8px}ol{margin:0 0 8px 18px;padding:0}li{margin-bottom:6px}.mut{color:#68738A}.pie{margin-top:26px;font-size:10.5px;color:#68738A}";

        private static string Cabecera(string titulo, string sub, string derecha)
        {
            return "<div class='cab'><div class='l'><div class='marca'>SIGMA <small>· Código Creativo</small></div><h1>" + Correo.Html(titulo) +
                   "</h1><div class='mut'>" + Correo.Html(sub) + "</div></div><div class='r'>" + derecha + "</div></div>";
        }

        private static string Capacidades(Dictionary<string, object> p)
        {
            List<string> c = new List<string>();
            Action<string, string> add = (k, n) => { object v; if (p.TryGetValue(k, out v) && v != null) c.Add(Convert.ToInt32(v).ToString("N0", CL) + " " + n); };
            add("LIM_USUARIOS", "usuarios"); add("LIM_ACTIVOS", "activos"); add("LIM_PLANTAS", "plantas"); add("LIM_BODEGAS", "bodegas"); add("LIM_GB", "GB de almacenamiento");
            return c.Count == 0 ? "Sin topes (según plan)" : string.Join(" · ", c);
        }

        private static string TablaPrecios(Dictionary<string, object> p)
        {
            decimal impl = Dec(p["IMPLEMENTACION_UF"]), mens = Dec(p["MENSUAL_UF"]), desc = Dec(p["DESCUENTO_PCT"]);
            int meses = Ent(p["VIGENCIA_MESES"]);
            decimal neta = MensualNeta(mens, desc), total = Total(impl, mens, desc, meses);
            string mo = Moneda(p);
            return "<table class='t'>" +
                "<tr><td class='k'>Implementación (pago único)</td><td class='v'>" + Mon(impl, mo) + "</td></tr>" +
                "<tr><td class='k'>Mensualidad de lista</td><td class='v'>" + Mon(mens, mo) + "</td></tr>" +
                (desc > 0 ? "<tr><td class='k'>Descuento</td><td class='v'>" + desc.ToString("0.##", CL) + " %</td></tr>" : "") +
                "<tr><td class='k'>Mensualidad con descuento</td><td class='v'>" + Mon(neta, mo) + "</td></tr>" +
                "<tr><td class='k'>Vigencia</td><td class='v'>" + meses + " meses</td></tr>" +
                "<tr class='tot'><td>Total del período (implementación + " + meses + " mensualidades)</td><td class='v'>" + Mon(total, mo) + "</td></tr></table>" +
                (mo == "USD" ? "<p class='mut'>Valores en dólares estadounidenses (USD). Se pagan por transferencia internacional; los gastos bancarios corren por cuenta del cliente.</p>"
                              : "<p class='mut'>Valores en UF más IVA. Se facturan en pesos según el valor de la UF del día de emisión.</p>");
        }

        public static byte[] PdfPropuesta(Dictionary<string, object> lead, Dictionary<string, object> p, string ejecutivo)
        {
            string modulos = string.Join("", (Txt(p, "MODULOS")).Split(',').Where(x => x.Trim().Length > 0).Select(m => "<span class='chip'>" + Correo.Html(NombreModulo(m)) + "</span>"));
            string html = "<html><head><meta charset='utf-8'><style>" + CSS_DOC + "</style></head><body>" +
                Cabecera("Propuesta comercial", Txt(lead, "EMPRESA") + " · " + Txt(p, "NOMBRE_PLAN"),
                         "Propuesta v" + Txt(p, "VERSION") + "<br>" + Hora.Hoy.ToString("dd/MM/yyyy", CL) + "<br>" + Correo.Html(Txt(lead, "CODIGO"))) +
                "<h2>Cliente</h2><table class='t'>" +
                "<tr><td class='k'>Empresa</td><td class='v'>" + Correo.Html(Txt(lead, "EMPRESA")) + "</td></tr>" +
                (IdLead(lead) != "" ? "<tr><td class='k'>" + Correo.Html(EtiquetaId(lead)) + "</td><td class='v'>" + Correo.Html(IdLead(lead)) + "</td></tr>" : "") +
                "<tr><td class='k'>Contacto</td><td class='v'>" + Correo.Html(Txt(lead, "CONTACTO")) + (Txt(lead, "CARGO") != "" ? " · " + Correo.Html(Txt(lead, "CARGO")) : "") + "</td></tr>" +
                "<tr><td class='k'>Correo</td><td class='v'>" + Correo.Html(Txt(lead, "CORREO")) + "</td></tr></table>" +
                "<h2>Plan " + (Txt(p, "TIPO") == "PERSONALIZADA" ? "personalizado" : "estándar") + ": " + Correo.Html(Txt(p, "NOMBRE_PLAN")) + "</h2>" +
                "<p>" + modulos + "</p><p><b>Capacidades:</b> " + Correo.Html(Capacidades(p)) + "</p>" +
                "<h2>Inversión</h2>" + TablaPrecios(p) +
                "<h2>Condiciones comerciales</h2>" +
                (Txt(p, "CONDICIONES") != "" ? "<p>" + Correo.Html(Txt(p, "CONDICIONES")).Replace("\n", "<br>") + "</p>" : "") +
                "<ol><li>La propuesta es válida por 30 días desde su emisión.</li>" +
                "<li>La implementación incluye la configuración inicial, la carga asistida de los datos maestros y la capacitación del equipo.</li>" +
                "<li>La suscripción se renueva al término de la vigencia salvo aviso con 30 días de anticipación.</li>" +
                "<li>Al aceptar, Código Creativo envía el contrato para firma electrónica en línea.</li></ol>" +
                "<div class='pie'>Preparada por " + Correo.Html(ejecutivo) + " · Código Creativo SpA · comercial@codigocreativo.tech</div></body></html>";
            return ConvertHtml.PdfConverterBinario(html);
        }

        public static byte[] PdfContrato(Dictionary<string, object> lead, Dictionary<string, object> p, int version)
        {
            string modulos = NombresModulos(Txt(p, "MODULOS"));
            string html = "<html><head><meta charset='utf-8'><style>" + CSS_DOC + "</style></head><body>" +
                Cabecera("Contrato de suscripción SIGMA", Txt(lead, "EMPRESA"),
                         "Versión " + version + "<br>" + Hora.Hoy.ToString("dd/MM/yyyy", CL) + "<br>" + Correo.Html(Txt(lead, "CODIGO"))) +
                "<h2>Partes</h2><p><b>Código Creativo SpA</b> («el Proveedor») y <b>" + Correo.Html(Txt(lead, "EMPRESA")) + "</b>, " + Correo.Html(EtiquetaId(lead)) + " " +
                Correo.Html(IdLead(lead)) + " («el Cliente»), acuerdan la suscripción al servicio SIGMA en los términos siguientes.</p>" +
                "<h2>1. Objeto</h2><p>El Proveedor otorga al Cliente acceso al Sistema Integrado de Gestión de Mantenimiento Industrial SIGMA, " +
                "en modalidad de software como servicio, con el plan <b>" + Correo.Html(Txt(p, "NOMBRE_PLAN")) + "</b> y los módulos: " + Correo.Html(modulos) + ".</p>" +
                "<h2>2. Capacidades contratadas</h2><p>" + Correo.Html(Capacidades(p)) + ". Lo que exceda las capacidades queda en solo lectura hasta ampliar el plan.</p>" +
                "<h2>3. Precio y forma de pago</h2>" + TablaPrecios(p) +
                "<h2>4. Vigencia</h2><p>El contrato rige desde su firma por " + Ent(p["VIGENCIA_MESES"]) + " meses y se renueva por períodos iguales salvo aviso escrito con 30 días de anticipación.</p>" +
                "<h2>5. Datos y confidencialidad</h2><p>Los datos que el Cliente carga en SIGMA son del Cliente. El Proveedor los trata solo para prestar el servicio, " +
                "no los cede a terceros y los entrega en formato exportable al término del contrato.</p>" +
                "<h2>6. Disponibilidad y soporte</h2><p>El Proveedor mantiene el servicio disponible y atiende las solicitudes por la mesa de ayuda de SIGMA según el plan contratado.</p>" +
                "<h2>7. Firma electrónica</h2><p>Las partes aceptan que este contrato se firme con firma electrónica simple (Ley N.º 19.799). " +
                "La firma registra el nombre e identificador tributario de quien firma, la fecha y hora, la dirección IP, el navegador y la huella SHA-256 de este documento.</p>" +
                "<div class='pie'>Documento generado por SIGMA. La huella SHA-256 de este PDF identifica la versión exacta que se firma.</div></body></html>";
            return ConvertHtml.PdfConverterBinario(html);
        }

        /// <summary>El PDF firmado: el original intacto + la hoja de constancia.</summary>
        public static byte[] PdfFirmado(byte[] original, string shaOriginal, Dictionary<string, object> c, string nombre, string rut,
                                        DateTime fecha, string ip, string ua, string firmaHash)
        {
            string html = "<html><head><meta charset='utf-8'><style>" + CSS_DOC + "</style></head><body>" +
                Cabecera("Constancia de firma electrónica", Txt(c, "EMPRESA") + " · contrato versión " + Txt(c, "VERSION"), fecha.ToString("dd/MM/yyyy HH:mm", CL)) +
                "<table class='t'>" +
                "<tr><td class='k'>Firmó</td><td class='v'>" + Correo.Html(nombre) + "</td></tr>" +
                "<tr><td class='k'>" + Correo.Html(Txt(c, "IDENT_ETIQUETA") != "" ? Txt(c, "IDENT_ETIQUETA") : "RUT") + " de quien firma</td><td class='v'>" + Correo.Html(rut) + "</td></tr>" +
                "<tr><td class='k'>En representación de</td><td class='v'>" + Correo.Html(Txt(c, "EMPRESA")) + " (" + Correo.Html(Txt(c, "RUT_EMPRESA")) + ")</td></tr>" +
                "<tr><td class='k'>Fecha y hora (Chile)</td><td class='v'>" + fecha.ToString("dd/MM/yyyy HH:mm:ss", CL) + "</td></tr>" +
                "<tr><td class='k'>Dirección IP</td><td class='v'>" + Correo.Html(ip) + "</td></tr>" +
                "<tr><td class='k'>Navegador</td><td class='v' style='font-weight:400;font-size:10.5px'>" + Correo.Html(ua) + "</td></tr>" +
                "<tr><td class='k'>SHA-256 del contrato firmado</td><td class='v' style='font-family:Consolas,monospace;font-size:10px'>" + shaOriginal + "</td></tr>" +
                "<tr><td class='k'>SHA-256 del evento de firma</td><td class='v' style='font-family:Consolas,monospace;font-size:10px'>" + firmaHash + "</td></tr></table>" +
                "<p>Quien firma declaró haber leído y aceptado el contrato que precede a esta hoja. La huella SHA-256 permite comprobar que el documento no cambió desde la firma.</p>" +
                "<div class='pie'>Firma electrónica simple (Ley N.º 19.799) registrada por SIGMA · Código Creativo SpA.</div></body></html>";
            byte[] hoja = ConvertHtml.PdfConverterBinario(html);
            byte[] unido = ConvertHtml.MergeDocuments(original, hoja);
            return unido ?? original;
        }

        // ------------------------------------------------------------ calendario
        /// <summary>Invitación iCalendar (RFC 5545) armada a mano: sin librerías ni costo.</summary>
        public static byte[] Ics(int reunion, DateTime inicioChile, int minutos, string titulo, string descripcion, string lugar, string url,
                                 string organizadorNombre, string organizadorCorreo, IEnumerable<KeyValuePair<string, string>> asistentes)
        {
            DateTime ini = Hora.AUtc(inicioChile), fin = ini.AddMinutes(minutos);
            Func<string, string> esc = x => (x ?? "").Replace("\\", "\\\\").Replace(";", "\\;").Replace(",", "\\,").Replace("\r", "").Replace("\n", "\\n");
            StringBuilder s = new StringBuilder();
            s.Append("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Codigo Creativo//SIGMA Centro Comercial//ES\r\nCALSCALE:GREGORIAN\r\nMETHOD:REQUEST\r\n");
            s.Append("BEGIN:VEVENT\r\n");
            s.Append("UID:sigma-reunion-").Append(reunion).Append("@codigocreativo.tech\r\n");
            s.Append("DTSTAMP:").Append(DateTime.UtcNow.ToString("yyyyMMdd'T'HHmmss'Z'")).Append("\r\n");
            s.Append("DTSTART:").Append(ini.ToString("yyyyMMdd'T'HHmmss'Z'")).Append("\r\n");
            s.Append("DTEND:").Append(fin.ToString("yyyyMMdd'T'HHmmss'Z'")).Append("\r\n");
            s.Append("SUMMARY:").Append(esc(titulo)).Append("\r\n");
            s.Append("DESCRIPTION:").Append(esc(descripcion)).Append("\r\n");
            if (!string.IsNullOrEmpty(lugar)) s.Append("LOCATION:").Append(esc(lugar)).Append("\r\n");
            if (!string.IsNullOrEmpty(url)) s.Append("URL:").Append(url).Append("\r\n");
            s.Append("ORGANIZER;CN=").Append(esc(organizadorNombre)).Append(":mailto:").Append(organizadorCorreo).Append("\r\n");
            foreach (KeyValuePair<string, string> a in asistentes ?? new KeyValuePair<string, string>[0])
                s.Append("ATTENDEE;CN=").Append(esc(string.IsNullOrEmpty(a.Key) ? a.Value : a.Key)).Append(";ROLE=REQ-PARTICIPANT;RSVP=TRUE:mailto:").Append(a.Value).Append("\r\n");
            s.Append("STATUS:CONFIRMED\r\nSEQUENCE:0\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n");
            return Encoding.UTF8.GetBytes(s.ToString());
        }
    }
}
