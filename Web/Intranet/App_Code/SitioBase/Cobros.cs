using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Web;

namespace SitioBase
{
    /// <summary>
    /// Cobros de las suscripciones y pago en línea (16-10-2026, bloque 462).
    ///
    ///   Al firmar      EmitirInicial (implementación + primera mensualidad) y la
    ///                  página de firma ofrece «Pagar ahora» con EnlacePago.
    ///   Cada día       el job COBROS_EMITIR emite el período siguiente y manda
    ///                  CorreoCobro; COBROS_RECORDATORIOS manda los avisos.
    ///   Al pagar       Pagar.aspx → IniciarPago → Webpay → ProcesarRetorno, que
    ///                  registra y verifica el pago con su comprobante y avisa.
    ///
    /// Todos los correos van al contacto del cliente con copia al ejecutivo a
    /// cargo. Ningún correo que falle deshace un cobro o un pago.
    /// </summary>
    public static class Cobros
    {
        public const int USUARIO_SISTEMA = 1;

        // ------------------------------------------------------------ emisión
        public static void EmitirInicial(int suscripcion)
        {
            Ejecutar("INS_COBRO_SUSCRIPCION", "@SUSCRIPCION", suscripcion, "@IMPLANTACION", true, "@USUARIO", USUARIO_SISTEMA);
            Ejecutar("INS_COBRO_SUSCRIPCION", "@SUSCRIPCION", suscripcion, "@IMPLANTACION", false, "@FECHA_INICIO", Hora.Hoy, "@USUARIO", USUARIO_SISTEMA);
        }

        public static int SuscripcionDeCliente(int cliente)
        {
            Dictionary<string, object> f = SoporteDatos.Fila("SEL_SUSCRIPCION", "@CLIENTE", cliente);
            object v; return f.TryGetValue("SUS_ID", out v) && v != null ? Convert.ToInt32(v) : 0;
        }

        /// <summary>Un enlace nuevo para pagar todo lo pendiente de la suscripción.</summary>
        public static string EnlacePago(int suscripcion)
        {
            string token = Comercial.Token();
            int dias; if (!int.TryParse(Comercial.Parametro("COBROS_ENLACE_DIAS", "30"), out dias)) dias = 30;
            Ejecutar("INS_PAGO_ENLACE", "@SUSCRIPCION", suscripcion, "@TOKEN_HASH", Comercial.HashToken(token), "@EXPIRA", Hora.Ahora.AddDays(dias));
            return Correo.UrlSitio() + "/Pagar.aspx?t=" + HttpUtility.UrlEncode(token);
        }

        // ------------------------------------------------------------ lectura
        public class Estado
        {
            public Dictionary<string, object> Cabecera;
            public List<Dictionary<string, object>> Pendientes;
            public decimal Total { get { return Pendientes.Sum(p => Convert.ToDecimal(p["SALDO"])); } }
            /// <summary>UF (se paga en CLP) o USD (transferencia internacional). Sale del cliente.</summary>
            public string Moneda { get { return Comercial.Txt(Cabecera, "MONEDA") == "USD" ? "USD" : "UF"; } }
            public bool EsUsd { get { return Moneda == "USD"; } }
            /// <summary>Transferencias ya informadas que esperan verificación (cantidad y monto).</summary>
            public int PorVerificarN; public decimal PorVerificarMonto;
        }

        public static Estado Leer(int suscripcion)
        {
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_COBRO_SUSCRIPCION", "@SUSCRIPCION", suscripcion);
            Dictionary<string, object> pv = SoporteDatos.Del(c, 2).FirstOrDefault();
            return new Estado { Cabecera = SoporteDatos.Del(c, 0).FirstOrDefault() ?? new Dictionary<string, object>(), Pendientes = SoporteDatos.Del(c, 1),
                                PorVerificarN = pv != null ? Convert.ToInt32(pv["N"]) : 0, PorVerificarMonto = pv != null ? Convert.ToDecimal(pv["MONTO"]) : 0 };
        }

        public static int SuscripcionDeEnlace(string t, out bool vencido)
        {
            vencido = false;
            if (string.IsNullOrWhiteSpace(t) || t.Length < 30) return 0;
            Dictionary<string, object> f = SoporteDatos.Fila("SEL_PAGO_ENLACE", "@TOKEN_HASH", Comercial.HashToken(t));
            if (!f.ContainsKey("SUSCRIPCION")) return 0;
            vencido = Convert.ToInt32(f["VENCIDO"]) == 1;
            return Convert.ToInt32(f["SUSCRIPCION"]);
        }

        public static string Periodo(Dictionary<string, object> p)
        {
            if (Convert.ToBoolean(p["IMPLANTACION"])) return "Implementación";
            DateTime d; return DateTime.TryParse(Convert.ToString(p["DESDE"]), out d) ? "Mensualidad " + d.ToString("MMMM yyyy", Comercial.CL) : "Mensualidad";
        }

        public static string Clp(object v) { return "$" + Convert.ToDecimal(v ?? 0).ToString("N0", Comercial.CL); }

        /// <summary>Monto de cobro en su moneda: «$1.839.201» en pesos o «USD 1.950,00» en dólares. Nunca se suman.</summary>
        public static string Monto(object v, bool usd) { return usd ? string.Format(Comercial.CL, "USD {0:N2}", Convert.ToDecimal(v ?? 0)) : Clp(v); }

        /// <summary>Lo que el cliente ve como «base» de un período: «45,00 UF» o «USD 1.950,00».</summary>
        public static string Base(object v, bool usd) { return usd ? string.Format(Comercial.CL, "USD {0:N2}", Convert.ToDecimal(v ?? 0)) : Comercial.UF2(v); }

        /// <summary>Datos para transferir según la moneda; salen de Configuración (Config_Comercial), no del código.</summary>
        public static List<KeyValuePair<string, string>> DatosTransferencia(bool usd)
        {
            List<KeyValuePair<string, string>> r = new List<KeyValuePair<string, string>>();
            foreach (Dictionary<string, object> f in SoporteDatos.Filas("SEL_CONFIG_COMERCIAL", "@GRUPO", usd ? "BANCO_INTERNACIONAL" : "BANCO_NACIONAL"))
                if (!string.IsNullOrWhiteSpace(Comercial.Txt(f, "VALOR"))) r.Add(new KeyValuePair<string, string>(Comercial.Txt(f, "ETIQUETA"), Comercial.Txt(f, "VALOR")));
            return r;
        }

        /// <summary>Referencia para la glosa de la transferencia: SUS-0014-NOV26.</summary>
        public static string Referencia(Estado e)
        {
            DateTime d;
            string mes = e.Pendientes.Count > 0 && DateTime.TryParse(Convert.ToString(e.Pendientes[0]["DESDE"]), out d) ? d.ToString("MMMyy", Comercial.CL).Replace(".", "").ToUpperInvariant() : "";
            return "SUS-" + Convert.ToInt32(e.Cabecera["SUSCRIPCION"]).ToString("0000") + (mes != "" ? "-" + mes : "");
        }

        // ------------------------------------------------------------ correos
        /// <summary>
        /// Correo de cobro o recordatorio (tipo COBRO, PREVIO, VENCE, MORA) con el
        /// detalle de lo pendiente y el botón para pagar. Registra el aviso en
        /// Cobro_Recordatorio para no repetirlo.
        /// </summary>
        public static bool CorreoCobro(int suscripcion, string tipo)
        {
            Estado e = Leer(suscripcion);
            if (e.Pendientes.Count == 0 || !e.Cabecera.ContainsKey("CORREO")) return false;
            Dictionary<string, object> h = e.Cabecera;
            string enlace = EnlacePago(suscripcion);
            string empresa = Comercial.Txt(h, "EMPRESA"), contacto = Comercial.Primero(Comercial.Txt(h, "CONTACTO"));
            DateTime vence; DateTime.TryParse(Convert.ToString(e.Pendientes[0]["DESDE"]), out vence);
            bool usd = e.EsUsd, prueba = !usd && Webpay.EsPrueba();
            string[] titulos =
            {
                tipo == "PREVIO" ? "Tu cobro de SIGMA vence en 3 días" :
                tipo == "VENCE" ? "Tu cobro de SIGMA vence hoy" :
                tipo == "MORA" ? "Tienes un cobro de SIGMA pendiente" : "Tu cobro de SIGMA está listo"
            };
            List<string> det = new List<string>();
            foreach (Dictionary<string, object> p in e.Pendientes) { det.Add(Periodo(p)); det.Add(usd ? Monto(p["SALDO"], true) : Clp(p["SALDO"]) + " · " + Comercial.UF2(p["UF"])); }
            det.Add("Total a pagar"); det.Add(Monto(e.Total, usd));
            List<KeyValuePair<string, string>> banco = DatosTransferencia(usd);
            string transferir = string.Join(" · ", banco.Select(b => b.Key + ": " + b.Value));
            string html = Correo.Plantilla(new Correo.Pieza
            {
                Pre = (prueba ? "MODO DE PRUEBA · " : "") + "Cobro SIGMA · " + empresa,
                Titulo = titulos[0],
                Texto = (contacto != "" ? Correo.Html(contacto) + ", " : "") + (tipo == "MORA"
                        ? "el cobro de tu suscripción SIGMA está vencido. Págalo para que tu equipo siga usando SIGMA sin interrupciones."
                        : "este es el cobro de tu suscripción SIGMA" + (vence != DateTime.MinValue ? ", que vence el " + vence.ToString("dd/MM/yyyy", Comercial.CL) : "") + (usd ? ". Se paga por transferencia internacional." : ". Puedes pagarlo en línea con Webpay.")),
                Detalles = det.ToArray(),
                Boton = usd ? "Ver datos e informar el pago" : "Pagar con Webpay", Enlace = enlace,
                Cierre = (usd ? "Transfiere en dólares a la cuenta indicada en el enlace, con la referencia que ahí aparece, y informa el pago subiendo el comprobante. Los gastos bancarios de la transferencia internacional corren por cuenta de tu empresa."
                              : "Pagas con tarjeta de crédito o débito en el sitio seguro de Transbank y el pago se registra solo.") +
                         (!usd && transferir != "" ? "<br><br>¿Prefieres transferir? " + Correo.Html(transferir) : "") +
                         (prueba ? "<br><br><b>Modo de prueba:</b> no se cobra dinero real; usa la tarjeta de prueba de Transbank (4051 8856 0044 6623, CVV 123, RUT 11.111.111-1, clave 123)." : ""),
                Pie = (usd ? "Montos en dólares estadounidenses, sin conversión. " : "Montos en pesos según la UF del día de emisión. ") + "Ejecutivo a cargo: " + (Comercial.Txt(h, "EJECUTIVO") == "" ? "Código Creativo" : Comercial.Txt(h, "EJECUTIVO")) + "."
            });
            bool ok = Correo.Enviar(new[] { Comercial.Txt(h, "CORREO") }, Copia(h),
                (prueba ? "[Prueba] " : "") + titulos[0] + " · " + empresa, html);
            foreach (Dictionary<string, object> p in e.Pendientes)
                try { Ejecutar("INS_COBRO_RECORDATORIO", "@PERIODO", Convert.ToInt32(p["ID"]), "@TIPO", tipo, "@ENVIADO", ok); } catch (Exception) { }
            return ok;
        }

        private static IEnumerable<string> Copia(Dictionary<string, object> h)
        {
            string e = Comercial.Txt(h, "EJECUTIVO_CORREO");
            return string.IsNullOrEmpty(e) ? null : new[] { e };
        }

        // ------------------------------------------------------------ pago en línea
        /// <summary>Crea la transacción por TODO lo pendiente y devuelve adónde enviar al navegador.</summary>
        public static Webpay.Transaccion IniciarPago(string t, string urlRetorno)
        {
            bool vencido; int sus = SuscripcionDeEnlace(t, out vencido);
            if (sus == 0) throw new Exception("El enlace de pago no es válido.");
            if (vencido) throw new Exception("El enlace de pago venció. Pide uno nuevo a tu ejecutivo.");
            Estado e = Leer(sus);
            if (e.EsUsd) throw new Exception("Tu cobro es en dólares: se paga por transferencia internacional. El pago con tarjeta en USD llegará pronto.");
            if (e.Pendientes.Count == 0 || e.Total <= 0) throw new Exception("No tienes cobros pendientes. ¡Gracias!");
            string orden = "SG" + sus + "-" + Hora.Ahora.ToString("yyMMddHHmmss");      // ≤ 26 caracteres
            string sesion = "S" + sus + "-" + Guid.NewGuid().ToString("N").Substring(0, 12);
            Dictionary<string, object> o = SpSalida("INS_PAGO_WEBPAY", "@ID", "@SUSCRIPCION", sus, "@BUY_ORDER", orden, "@SESSION_ID", sesion,
                "@MONTO", Math.Round(e.Total), "@PERIODOS", string.Join(",", e.Pendientes.Select(p => Convert.ToString(p["ID"]))), "@AMBIENTE", Webpay.Ambiente());
            Webpay.Transaccion tx = Webpay.Crear(orden, sesion, Math.Round(e.Total), urlRetorno);
            Ejecutar("UPD_PAGO_WEBPAY_TOKEN", "@ID", Convert.ToInt32(o["@ID"]), "@TOKEN", tx.Token);
            return tx;
        }

        public class Resultado { public string Estado; public Dictionary<string, object> Pago; public string Mensaje; public bool Correo; }

        /// <summary>
        /// El retorno de Transbank. token_ws = la persona terminó el pago (aprobado o
        /// rechazado); TBK_TOKEN = lo anuló. Recargar la página no registra el
        /// pago dos veces: UPD_PAGO_WEBPAY_RESULTADO solo cierra una CREADA.
        /// </summary>
        public static Resultado ProcesarRetorno(string tokenWs, string tbkToken, string tbkOrden)
        {
            if (string.IsNullOrEmpty(tokenWs))
            {
                Dictionary<string, object> a = !string.IsNullOrEmpty(tbkToken) ? SoporteDatos.Fila("SEL_PAGO_WEBPAY", "@TOKEN", tbkToken)
                                             : !string.IsNullOrEmpty(tbkOrden) ? SoporteDatos.Fila("SEL_PAGO_WEBPAY", "@BUY_ORDER", tbkOrden) : new Dictionary<string, object>();
                if (a.ContainsKey("ID")) SoporteDatos.Fila("UPD_PAGO_WEBPAY_RESULTADO", "@ID", Convert.ToInt32(a["ID"]), "@ESTADO", "ANULADA");
                return new Resultado { Estado = "ANULADA", Pago = a, Mensaje = "Anulaste el pago. No se hizo ningún cargo." };
            }
            Dictionary<string, object> pago = SoporteDatos.Fila("SEL_PAGO_WEBPAY", "@TOKEN", tokenWs);
            if (!pago.ContainsKey("ID")) return new Resultado { Estado = "ERROR", Mensaje = "No encontramos ese pago." };
            if (Comercial.Txt(pago, "ESTADO") != "CREADA")
            {
                // Autorizado pero sin registrar (se cortó la vez anterior): se completa ahora.
                bool mail = false;
                if (Comercial.Txt(pago, "ESTADO") == "AUTORIZADA" && !Convert.ToBoolean(pago["REGISTRADO"])) mail = RegistrarPagos(pago);
                return new Resultado { Estado = Comercial.Txt(pago, "ESTADO"), Pago = pago, Correo = mail, Mensaje = "Este pago ya se procesó." };
            }

            Dictionary<string, object> r;
            try { r = Webpay.Confirmar(tokenWs); }
            catch (Exception ex)
            {
                SoporteDatos.Fila("UPD_PAGO_WEBPAY_RESULTADO", "@ID", Convert.ToInt32(pago["ID"]), "@ESTADO", "ERROR", "@RESPUESTA", ex.Message);
                return new Resultado { Estado = "ERROR", Pago = pago, Mensaje = ex.Message };
            }
            bool ok = Webpay.Aprobada(r);
            object tarjeta = null;
            object cd; if (r.TryGetValue("card_detail", out cd) && cd is Dictionary<string, object>) ((Dictionary<string, object>)cd).TryGetValue("card_number", out tarjeta);
            Dictionary<string, object> c = SoporteDatos.Fila("UPD_PAGO_WEBPAY_RESULTADO", "@ID", Convert.ToInt32(pago["ID"]), "@ESTADO", ok ? "AUTORIZADA" : "RECHAZADA",
                "@AUTORIZACION", Valor(r, "authorization_code"), "@TARJETA", tarjeta != null ? Convert.ToString(tarjeta) : null,
                "@TIPO_PAGO", Valor(r, "payment_type_code"), "@CUOTAS", r.ContainsKey("installments_number") && r["installments_number"] != null ? (object)Convert.ToInt32(r["installments_number"]) : null,
                "@RESPUESTA", Convert.ToString(r["_json"]));
            pago = SoporteDatos.Fila("SEL_PAGO_WEBPAY", "@TOKEN", tokenWs);
            if (!ok) return new Resultado { Estado = "RECHAZADA", Pago = pago, Mensaje = "Transbank rechazó el pago. No se hizo ningún cargo." };

            bool correo = false;
            if (Convert.ToInt32(c["CAMBIO"]) == 1 || !Convert.ToBoolean(pago["REGISTRADO"])) correo = RegistrarPagos(pago);
            return new Resultado { Estado = "AUTORIZADA", Pago = pago, Correo = correo, Mensaje = "Pago recibido." };
        }

        private static object Valor(Dictionary<string, object> r, string k) { object v; return r.TryGetValue(k, out v) && v != null ? Convert.ToString(v) : null; }

        /// <summary>
        /// El pago aprobado entra a SIGMA por el mismo camino que uno informado y
        /// verificado: un Suscripcion_Pago por período, con el comprobante adjunto,
        /// verificado al tiro. Eso deja el período pagado y extiende la suscripción.
        /// </summary>
        private static bool RegistrarPagos(Dictionary<string, object> pago)
        {
            int sus = Convert.ToInt32(pago["SUSCRIPCION"]);
            Estado e = Leer(sus);
            HashSet<string> ids = new HashSet<string>(Convert.ToString(pago["PERIODOS"]).Split(','));
            int cliente = SoporteDatos.Fila("SEL_SUSCRIPCION", "@ID", sus).ContainsKey("SUS_CLIENTE") ? Convert.ToInt32(SoporteDatos.Fila("SEL_SUSCRIPCION", "@ID", sus)["SUS_CLIENTE"]) : 0;
            byte[] pdf = Comprobante(e.Cabecera, pago, e.Pendientes.Where(p => ids.Contains(Convert.ToString(p["ID"]))).ToList());
            int archivo = SubirComprobante(cliente, Comercial.Txt(e.Cabecera, "EMPRESA"), "Comprobante_Webpay_" + Comercial.Txt(pago, "BUY_ORDER") + ".pdf", pdf);
            foreach (Dictionary<string, object> p in e.Pendientes.Where(x => ids.Contains(Convert.ToString(x["ID"]))))
            {
                decimal saldo = Convert.ToDecimal(p["SALDO"]);
                Dictionary<string, object> o = SpSalida("INS_SUSCRIPCION_PAGO", "@ID", "@PERIODO", Convert.ToInt32(p["ID"]), "@MONTO_DECLARADO", saldo,
                    "@FECHA_TRANSFERENCIA", Hora.Hoy, "@BANCO", "Webpay Plus" + (Webpay.EsPrueba() ? " (prueba)" : ""),
                    "@NUMERO_OPERACION", Comercial.Txt(pago, "AUTORIZACION") + " · " + Comercial.Txt(pago, "BUY_ORDER") + " · P" + Convert.ToString(p["ID"]), "@ARCHIVO", archivo, "@USUARIO", USUARIO_SISTEMA, "@MEDIO", "WEBPAY");
                Ejecutar("UPD_SUSCRIPCION_PAGO_VERIFICAR", "@ID", Convert.ToInt32(o["@ID"]), "@VERIFICADO", true, "@MONTO_VERIFICADO", saldo, "@USUARIO", USUARIO_SISTEMA);
            }
            if (e.Cabecera.ContainsKey("LEAD") && e.Cabecera["LEAD"] != null)
                try
                {
                    Ejecutar("INS_LEAD_ACTIVIDAD", "@LEAD", Convert.ToInt32(e.Cabecera["LEAD"]), "@TIPO", "SISTEMA", "@ICONO", "check",
                        "@TITULO", "Pago recibido por Webpay" + (Webpay.EsPrueba() ? " (prueba)" : ""),
                        "@DETALLE", Clp(pago["MONTO"]) + " · autorización " + Comercial.Txt(pago, "AUTORIZACION") + " · tarjeta ****" + Comercial.Txt(pago, "TARJETA"));
                }
                catch (Exception) { }
            Ejecutar("UPD_PAGO_WEBPAY_REGISTRADO", "@ID", Convert.ToInt32(pago["ID"]));
            return CorreoComprobante(e.Cabecera, pago, pdf);
        }

        /// <summary>Para el job de cobros: termina de registrar los pagos autorizados que quedaron a medias.</summary>
        public static int RegistrarPendientes()
        {
            int n = 0;
            foreach (Dictionary<string, object> f in SoporteDatos.Filas("SEL_PAGO_WEBPAY_SIN_REGISTRAR"))
            {
                Dictionary<string, object> pago = SoporteDatos.Fila("SEL_PAGO_WEBPAY", "@TOKEN", Convert.ToString(f["TOKEN"]));
                if (pago.ContainsKey("ID")) { RegistrarPagos(pago); n++; }
            }
            return n;
        }

        private static byte[] Comprobante(Dictionary<string, object> h, Dictionary<string, object> pago, List<Dictionary<string, object>> periodos)
        {
            string filas = string.Join("", periodos.Select(p => "<tr><td class='k'>" + Correo.Html(Periodo(p)) + "</td><td class='v'>" + Clp(p["SALDO"]) + "</td></tr>"));
            string html = "<html><head><meta charset='utf-8'><style>body{font-family:'Segoe UI',Arial,sans-serif;color:#17223B;font-size:12.5px}" +
                "h1{font-size:20px;margin:0 0 4px}table{width:100%;border-collapse:collapse;margin:10px 0}td{padding:7px 10px;border-bottom:1px solid #EEF1F6}" +
                "td.k{color:#68738A}td.v{text-align:right;font-weight:700}.tot td{border-top:2px solid #17223B;font-weight:800}.mut{color:#68738A;font-size:11px}" +
                ".cab{border-bottom:3px solid #6732F4;padding-bottom:10px;margin-bottom:14px}.marca{font-size:18px;font-weight:800;letter-spacing:.06em}" +
                ".agua{position:absolute;top:330px;left:40px;font-size:84px;font-weight:800;color:rgba(182,92,0,.12);transform:rotate(-24deg);letter-spacing:.08em;white-space:nowrap}</style></head><body>" +
                (Webpay.EsPrueba() ? "<div class='agua'>MODO DE PRUEBA</div>" : "") +
                "<div class='cab'><div class='marca'>SIGMA <span class='mut'>· Código Creativo</span></div><h1>Comprobante de pago" + (Webpay.EsPrueba() ? " (MODO DE PRUEBA)" : "") + "</h1>" +
                "<div class='mut'>" + Correo.Html(Comercial.Txt(h, "EMPRESA")) + " · " + Hora.Ahora.ToString("dd/MM/yyyy HH:mm", Comercial.CL) + "</div></div>" +
                "<table>" + filas + "<tr class='tot'><td>Total pagado</td><td class='v'>" + Clp(pago["MONTO"]) + "</td></tr></table>" +
                "<table><tr><td class='k'>Medio de pago</td><td class='v'>Webpay Plus · tarjeta ****" + Correo.Html(Comercial.Txt(pago, "TARJETA")) + "</td></tr>" +
                "<tr><td class='k'>Código de autorización</td><td class='v'>" + Correo.Html(Comercial.Txt(pago, "AUTORIZACION")) + "</td></tr>" +
                "<tr><td class='k'>Orden de compra</td><td class='v'>" + Correo.Html(Comercial.Txt(pago, "BUY_ORDER")) + "</td></tr></table>" +
                (Webpay.EsPrueba() ? "<p class='mut'>Pago hecho en el ambiente de integración de Transbank: no se cobró dinero real.</p>" : "") +
                "<p class='mut'>Código Creativo SpA · comercial@codigocreativo.tech</p></body></html>";
            return ConvertHtml.PdfConverterBinario(html);
        }

        private static bool CorreoComprobante(Dictionary<string, object> h, Dictionary<string, object> pago, byte[] pdf)
        {
            string archivo = "Comprobante_SIGMA_" + Comercial.Txt(pago, "BUY_ORDER") + ".pdf";
            string html = Correo.Plantilla(new Correo.Pieza
            {
                Pre = (Webpay.EsPrueba() ? "MODO DE PRUEBA · " : "") + "Pago recibido",
                Titulo = "Recibimos tu pago, " + Comercial.Primero(Comercial.Txt(h, "CONTACTO")),
                Texto = "Gracias. El pago de la suscripción SIGMA de " + Correo.Html(Comercial.Txt(h, "EMPRESA")) + " quedó registrado y tu acceso sigue activo.",
                Detalles = new[] { "Monto", Clp(pago["MONTO"]), "Medio", "Webpay Plus · tarjeta ****" + Comercial.Txt(pago, "TARJETA"),
                                   "Autorización", Comercial.Txt(pago, "AUTORIZACION"), "Fecha", Hora.Ahora.ToString("dd/MM/yyyy HH:mm", Comercial.CL) },
                Adjunto = archivo, AdjuntoKb = (int)Math.Ceiling(pdf.Length / 1024.0),
                Boton = "Ir a SIGMA", Enlace = Correo.UrlSitio() + "/Login.aspx",
                Cierre = Webpay.EsPrueba() ? "<b>Modo de prueba:</b> no se cobró dinero real." : "Guarda este correo: incluye tu comprobante.",
                Pie = "Ejecutivo a cargo: " + (Comercial.Txt(h, "EJECUTIVO") == "" ? "Código Creativo" : Comercial.Txt(h, "EJECUTIVO")) + "."
            });
            return Correo.Enviar(new[] { Comercial.Txt(h, "CORREO") }, Copia(h), (Webpay.EsPrueba() ? "[Prueba] " : "") + "Pago recibido · SIGMA", html,
                new Correo.Adjunto(archivo, "application/pdf", pdf));
        }

        /// <summary>El comprobante al almacenamiento del sitio, como cualquier archivo, a nombre del sistema.</summary>
        private static int SubirComprobante(int cliente, string empresa, string nombre, byte[] pdf) { return SubirComprobante(cliente, empresa, nombre, pdf, "application/pdf"); }

        private static int SubirComprobante(int cliente, string empresa, string nombre, byte[] pdf, string mime)
        {
            /* El almacenamiento nombra la carpeta consultando el cliente con un
               controlador que exige sesión (y sin ella redirige al login). Aquí
               no hay sesión: se le deja el nombre en el caché de la petición que
               ese mismo método revisa primero (Almacenamiento.NombreCliente). */
            if (HttpContext.Current != null) HttpContext.Current.Items["sigma-cliente-nombre-" + cliente] = empresa ?? "";
            IAlmacenamiento alm = Almacenamiento.Actual();
            if (!alm.Disponible) throw new Exception(alm.Motivo);
            ResultadoSubida s = alm.Subir(cliente, "pagos", nombre, pdf, mime);
            Dictionary<string, object> o = SpSalida("INS_ARCHIVO", "@ID", "@CLIENTE", cliente, "@CATEGORIA", 9, "@NOMBRE_ORIGINAL", nombre,
                "@NOMBRE_ALMACENADO", s.nombre_almacenado, "@RUTA", s.ruta, "@MIME", s.mime, "@EXTENSION", s.extension, "@BYTE", s.tamano,
                "@HASH", s.hash, "@USUARIO", USUARIO_SISTEMA);
            return Convert.ToInt32(o["@ID"]);
        }

        // ------------------------------------------------------------ verificación de una transferencia
        /// <summary>
        /// Al verificar una transferencia: comprobante PDF (sin «Valor UF» si es en USD) y correo al contacto
        /// de cobro con copia al ejecutivo. Un correo que falla no deshace la verificación.
        /// </summary>
        public static bool CorreoPagoVerificado(int pagoId)
        {
            Dictionary<string, object> pg = SoporteDatos.Filas("SEL_SUSCRIPCION_PAGO", "@ID", pagoId).FirstOrDefault();
            if (pg == null) return false;
            Dictionary<string, object> per = SoporteDatos.Filas("SEL_SUSCRIPCION_PERIODO", "@ID", Convert.ToInt32(pg["SPA_PERIODO"])).FirstOrDefault();
            if (per == null) return false;
            Estado e = Leer(Convert.ToInt32(per["SPE_SUSCRIPCION"]));
            if (!e.Cabecera.ContainsKey("CORREO")) return false;
            bool usd = Convert.ToString(pg["SPA_MONEDA"]) == "USD";
            string medio = usd ? "Transferencia internacional" : "Transferencia nacional";
            string ver = Monto(pg["SPA_MONTO_VERIFICADO_CLP"] ?? pg["SPA_MONTO_DECLARADO_CLP"], usd);
            string concepto = Convert.ToBoolean(per["SPE_ES_IMPLANTACION"]) ? "Implementación" : "Mensualidad " + Convert.ToDateTime(per["SPE_FECHA_INICIO"]).ToString("MMMM yyyy", Comercial.CL);
            string prueba = Webpay.EsPrueba() && Convert.ToString(pg["SPA_MEDIO"]) == "WEBPAY" ? " (MODO DE PRUEBA)" : "";
            string filas = "<tr><td class='k'>" + Correo.Html(concepto) + "</td><td class='v'>" + Correo.Html(ver) + "</td></tr>" +
                (usd ? "" : "<tr><td class='k'>Precio del plan</td><td class='v'>" + Correo.Html(Comercial.UF2(per["SPE_VALOR_UF_PLAN"])) + "</td></tr>" +
                            (per["SPE_VALOR_UF_DIA"] != null ? "<tr><td class='k'>Valor de la UF al emitir</td><td class='v'>" + Correo.Html(Clp(per["SPE_VALOR_UF_DIA"])) + "</td></tr>" : ""));
            string html = "<html><head><meta charset='utf-8'><style>body{font-family:'Segoe UI',Arial,sans-serif;color:#17223B;font-size:12.5px}" +
                "h1{font-size:20px;margin:0 0 4px}table{width:100%;border-collapse:collapse;margin:10px 0}td{padding:7px 10px;border-bottom:1px solid #EEF1F6}" +
                "td.k{color:#68738A}td.v{text-align:right;font-weight:700}.tot td{border-top:2px solid #17223B;font-weight:800}.mut{color:#68738A;font-size:11px}" +
                ".cab{border-bottom:3px solid #6732F4;padding-bottom:10px;margin-bottom:14px}.marca{font-size:18px;font-weight:800;letter-spacing:.06em}</style></head><body>" +
                "<div class='cab'><div class='marca'>SIGMA <span class='mut'>· Código Creativo</span></div><h1>Comprobante de pago" + prueba + "</h1>" +
                "<div class='mut'>" + Correo.Html(Comercial.Txt(e.Cabecera, "EMPRESA")) + " · " + Hora.Ahora.ToString("dd/MM/yyyy HH:mm", Comercial.CL) + "</div></div>" +
                "<table>" + filas + "<tr class='tot'><td>Total verificado</td><td class='v'>" + Correo.Html(ver) + "</td></tr></table>" +
                "<table><tr><td class='k'>Medio de pago</td><td class='v'>" + medio + "</td></tr>" +
                "<tr><td class='k'>Banco</td><td class='v'>" + Correo.Html(Convert.ToString(pg["SPA_BANCO"])) + "</td></tr>" +
                "<tr><td class='k'>N.° de operación</td><td class='v'>" + Correo.Html(Convert.ToString(pg["SPA_NUMERO_OPERACION"])) + "</td></tr>" +
                "<tr><td class='k'>Transferida el</td><td class='v'>" + Convert.ToDateTime(pg["SPA_FECHA_TRANSFERENCIA"]).ToString("dd/MM/yyyy", Comercial.CL) + "</td></tr></table>" +
                "<p class='mut'>Este comprobante no reemplaza a la factura electrónica, que se emite por separado. Código Creativo SpA · comercial@codigocreativo.tech</p></body></html>";
            byte[] pdf = ConvertHtml.PdfConverterBinario(html);
            string archivo = "Comprobante_SIGMA_" + Convert.ToString(pg["SPA_ID"]) + ".pdf";
            string cuerpo = Correo.Plantilla(new Correo.Pieza
            {
                Pre = "Pago verificado", Titulo = "Verificamos tu pago, " + Comercial.Primero(Comercial.Txt(e.Cabecera, "CONTACTO")),
                Texto = "Gracias. Verificamos la transferencia de " + Correo.Html(Comercial.Txt(e.Cabecera, "EMPRESA")) + " contra nuestra cartola y tu acceso a SIGMA quedó al día.",
                Detalles = new[] { "Monto verificado", ver, "Medio", medio, "N.° de operación", Convert.ToString(pg["SPA_NUMERO_OPERACION"]) },
                Adjunto = archivo, AdjuntoKb = (int)Math.Ceiling(pdf.Length / 1024.0),
                Boton = "Ir a SIGMA", Enlace = Correo.UrlSitio() + "/Login.aspx", Cierre = "Guarda este correo: incluye tu comprobante.",
                Pie = "Ejecutivo a cargo: " + (Comercial.Txt(e.Cabecera, "EJECUTIVO") == "" ? "Código Creativo" : Comercial.Txt(e.Cabecera, "EJECUTIVO")) + "."
            });
            return Correo.Enviar(new[] { Comercial.Txt(e.Cabecera, "CORREO") }, Copia(e.Cabecera), "Pago verificado · SIGMA", cuerpo, new Correo.Adjunto(archivo, "application/pdf", pdf));
        }

        public static bool CorreoPagoRechazado(int pagoId, string motivo)
        {
            Dictionary<string, object> pg = SoporteDatos.Filas("SEL_SUSCRIPCION_PAGO", "@ID", pagoId).FirstOrDefault();
            if (pg == null) return false;
            Dictionary<string, object> per = SoporteDatos.Filas("SEL_SUSCRIPCION_PERIODO", "@ID", Convert.ToInt32(pg["SPA_PERIODO"])).FirstOrDefault();
            if (per == null) return false;
            Estado e = Leer(Convert.ToInt32(per["SPE_SUSCRIPCION"]));
            if (!e.Cabecera.ContainsKey("CORREO")) return false;
            bool usd = Convert.ToString(pg["SPA_MONEDA"]) == "USD";
            string html = Correo.Plantilla(new Correo.Pieza
            {
                Pre = "No pudimos verificar tu pago", Titulo = "No pudimos verificar tu pago",
                Texto = Correo.Html(Comercial.Primero(Comercial.Txt(e.Cabecera, "CONTACTO"))) + ", revisamos la transferencia de " + Correo.Html(Comercial.Txt(e.Cabecera, "EMPRESA")) + " y no pudimos darla por pagada.",
                Detalles = new[] { "Monto informado", Monto(pg["SPA_MONTO_DECLARADO_CLP"], usd), "N.° de operación", Convert.ToString(pg["SPA_NUMERO_OPERACION"]), "Motivo", motivo },
                Boton = "Revisar y volver a informar", Enlace = EnlacePago(Convert.ToInt32(per["SPE_SUSCRIPCION"])),
                Cierre = "Puedes corregir los datos o subir otro comprobante desde el enlace. Si crees que es un error, responde este correo.",
                Pie = "Ejecutivo a cargo: " + (Comercial.Txt(e.Cabecera, "EJECUTIVO") == "" ? "Código Creativo" : Comercial.Txt(e.Cabecera, "EJECUTIVO")) + "."
            });
            return Correo.Enviar(new[] { Comercial.Txt(e.Cabecera, "CORREO") }, Copia(e.Cabecera), "No pudimos verificar tu pago · SIGMA", html);
        }

        // ------------------------------------------------------------ transferencia informada por el cliente
        /// <summary>
        /// El cliente informa una transferencia desde Pagar.aspx (sin sesión: lo protege el enlace). El
        /// monto se reparte sobre los períodos pendientes en orden, un Suscripcion_Pago por período con el
        /// mismo comprobante; queda DECLARADO y alguien lo verifica contra la cartola. Avisa al ejecutivo.
        /// </summary>
        public static int InformarTransferencia(string t, decimal monto, DateTime fecha, string banco, string operacion, string nombre, string mime, byte[] archivo)
        {
            bool vencido; int sus = SuscripcionDeEnlace(t, out vencido);
            if (sus == 0) throw new Exception("El enlace de pago no es válido.");
            if (vencido) throw new Exception("El enlace de pago venció. Pide uno nuevo a tu ejecutivo.");
            if (monto <= 0) throw new Exception("El monto transferido debe ser mayor que cero.");
            if (fecha.Date > Hora.Hoy.Date) throw new Exception("La fecha de la transferencia no puede ser futura.");
            if (archivo == null || archivo.Length == 0) throw new Exception("Adjunta el comprobante de la transferencia.");
            if (archivo.Length > 8 * 1024 * 1024) throw new Exception("El comprobante pesa más de 8 MB.");
            Estado e = Leer(sus);
            if (e.Pendientes.Count == 0) throw new Exception("No tienes cobros pendientes. ¡Gracias!");
            string medio = e.EsUsd ? "TRANSFERENCIA_INTERNACIONAL" : "TRANSFERENCIA_NACIONAL";
            int cliente = Convert.ToInt32(e.Cabecera["CLIENTE"]);
            int arc = SubirComprobante(cliente, Comercial.Txt(e.Cabecera, "EMPRESA"), System.IO.Path.GetFileName(string.IsNullOrEmpty(nombre) ? "comprobante" : nombre), archivo,
                                       string.IsNullOrEmpty(mime) ? "application/octet-stream" : mime);
            decimal resto = monto; int n = 0;
            try
            {
                foreach (Dictionary<string, object> p in e.Pendientes)
                {
                    if (resto <= 0) break;
                    decimal parte = Math.Min(resto, Convert.ToDecimal(p["SALDO"]));
                    // Lo que sobra (si transfirió de más) queda en el último período, para que se vea la diferencia al verificar.
                    bool ultimo = p == e.Pendientes[e.Pendientes.Count - 1];
                    if (ultimo) parte = resto;
                    string op = string.IsNullOrWhiteSpace(operacion) ? null : (n == 0 ? operacion.Trim() : operacion.Trim() + " · P" + Convert.ToString(p["ID"]));
                    SpSalida("INS_SUSCRIPCION_PAGO", "@ID", "@PERIODO", Convert.ToInt32(p["ID"]), "@MONTO_DECLARADO", parte, "@FECHA_TRANSFERENCIA", fecha.Date,
                        "@BANCO", string.IsNullOrWhiteSpace(banco) ? null : banco.Trim(), "@NUMERO_OPERACION", op, "@ARCHIVO", arc, "@USUARIO", USUARIO_SISTEMA, "@MEDIO", medio);
                    resto -= parte; n++;
                }
            }
            catch (Exception)
            {
                try { Ejecutar("DEL_ARCHIVO", "@ID", arc, "@USUARIO", USUARIO_SISTEMA); } catch (Exception) { }
                throw;
            }
            if (e.Cabecera.ContainsKey("LEAD") && e.Cabecera["LEAD"] != null)
                try
                {
                    Ejecutar("INS_LEAD_ACTIVIDAD", "@LEAD", Convert.ToInt32(e.Cabecera["LEAD"]), "@TIPO", "SISTEMA", "@ICONO", "wallet",
                        "@TITULO", "Transferencia informada por el cliente", "@DETALLE", Monto(monto, e.EsUsd) + (string.IsNullOrWhiteSpace(banco) ? "" : " · " + banco.Trim()) + " · por verificar");
                }
                catch (Exception) { }
            CorreoPorVerificar(e, monto, fecha, banco);
            return n;
        }

        /// <summary>Aviso interno al ejecutivo: hay una transferencia esperando verificación.</summary>
        private static void CorreoPorVerificar(Estado e, decimal monto, DateTime fecha, string banco)
        {
            try
            {
                string para = Comercial.Txt(e.Cabecera, "EJECUTIVO_CORREO");
                if (para == "") para = Comercial.Parametro("COMERCIAL_CORREO_AVISO", "comercial@codigocreativo.tech");
                string html = Correo.Plantilla(new Correo.Pieza
                {
                    Pre = "Cobros · " + Comercial.Txt(e.Cabecera, "EMPRESA"), Titulo = "Transferencia por verificar",
                    Texto = Correo.Html(Comercial.Txt(e.Cabecera, "EMPRESA")) + " informó una transferencia. Revisa el comprobante y verifícala contra la cartola.",
                    Detalles = new[] { "Monto", Monto(monto, e.EsUsd), "Transferida el", fecha.ToString("dd/MM/yyyy", Comercial.CL), "Banco", string.IsNullOrWhiteSpace(banco) ? "—" : banco.Trim() },
                    Boton = "Verificar en el Centro Comercial", Enlace = Correo.UrlSitio() + "/View/Comercial/CentroComercial.aspx?tab=suscripciones",
                    Pie = "Aviso interno del Centro Comercial de SIGMA."
                });
                Correo.Enviar(new[] { para }, null, "Transferencia por verificar · " + Comercial.Txt(e.Cabecera, "EMPRESA"), html);
            }
            catch (Exception) { }
        }

        // ------------------------------------------------------------ SQL
        public static void Ejecutar(string sp, params object[] ps) { SpSalida(sp, null, ps); }

        public static Dictionary<string, object> SpSalida(string sp, string salida, params object[] ps)
        {
            SqlCommand cmd = Conexion.GetCommand(sp);
            Dictionary<string, object> r = new Dictionary<string, object>();
            try
            {
                if (salida != null) cmd.Parameters.Add(salida, SqlDbType.Int).Direction = ParameterDirection.Output;
                for (int i = 0; i + 1 < ps.Length; i += 2)
                {
                    object v = ps[i + 1];
                    if (v is byte[]) cmd.Parameters.Add((string)ps[i], SqlDbType.VarBinary, -1).Value = v;
                    else cmd.Parameters.AddWithValue((string)ps[i], v ?? DBNull.Value);
                }
                cmd.ExecuteNonQuery();
                if (salida != null) r[salida] = cmd.Parameters[salida].Value;
            }
            finally { if (cmd.Connection != null) cmd.Connection.Close(); }
            return r;
        }
    }
}
