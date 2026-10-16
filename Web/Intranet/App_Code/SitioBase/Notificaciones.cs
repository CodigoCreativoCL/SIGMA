using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Linq;

namespace SitioBase
{
    /// <summary>
    /// Correos de aviso de SIGMA (16-10-2026): mesa de ayuda, alertas, demos y bienvenida.
    ///
    /// EL CORREO ES OTRO TRANSPORTE DEL MISMO AVISO
    ///   Los avisos ya existen como Alerta (con su destinatario: por permiso del tipo o una persona
    ///   puntual, como las respuestas de la mesa de ayuda). Aquí solo se leen las que todavía no se
    ///   mandaron por correo (SEL_ALERTA_CORREO_PENDIENTE), se redactan con el mismo diseño de todos los
    ///   correos de SIGMA (Correo.Plantilla) y se dejan en la cola (Correo_Cola), que los envía y los
    ///   reintenta. Lo que no tiene alerta (un problema recién reportado, una demo por vencer) se
    ///   redacta y se encola directamente.
    ///
    /// NINGÚN CORREO DESHACE NADA
    ///   Todo es «mejor esfuerzo»: si algo falla se registra y la acción que lo originó sigue.
    /// </summary>
    public static class Notificaciones
    {
        private static string Url(string ruta) { return Correo.UrlSitio() + ruta; }
        private static string T(Dictionary<string, object> f, string k) { return Comercial.Txt(f, k); }
        private static string Prim(string nombre) { return Comercial.Primero(nombre); }

        // ------------------------------------------------------------ alertas (incluye las respuestas de la mesa de ayuda)
        public static int Alertas()
        {
            List<Dictionary<string, object>> filas = SoporteDatos.Filas("SEL_ALERTA_CORREO_PENDIENTE");
            int enviados = 0;
            foreach (IGrouping<int, Dictionary<string, object>> g in filas.GroupBy(f => Convert.ToInt32(f["USUARIO"])))
            {
                Dictionary<string, object> p = g.First();
                string correo = T(p, "CORREO"), nombre = Prim(T(p, "NOMBRE"));
                List<Dictionary<string, object>> soporte = g.Where(f => f["TICKET"] != null).ToList();
                List<Dictionary<string, object>> otras = g.Where(f => f["TICKET"] == null).ToList();
                try
                {
                    // Mesa de ayuda: un correo por aviso, porque cada uno es una conversación distinta.
                    foreach (Dictionary<string, object> a in soporte)
                    {
                        Correo.Encolar("ALERTA_SOPORTE", new[] { correo }, null, "[Mesa de ayuda] " + T(a, "TITULO"), HtmlSoporte(a, nombre));
                        Cobros.Ejecutar("INS_ALERTA_CORREO", "@ALERTA", Convert.ToInt32(a["ALERTA"]), "@USUARIO", Convert.ToInt32(a["USUARIO"]));
                        enviados++;
                    }
                    // Detectores (stock, permisos, mediciones…): un solo resumen por persona.
                    if (otras.Count > 0)
                    {
                        Correo.Encolar("ALERTA_RESUMEN", new[] { correo }, null,
                            otras.Count == 1 ? "[Alerta] " + T(otras[0], "TITULO") : "SIGMA · " + otras.Count + " alertas nuevas", HtmlResumen(otras, nombre));
                        foreach (Dictionary<string, object> a in otras)
                            Cobros.Ejecutar("INS_ALERTA_CORREO", "@ALERTA", Convert.ToInt32(a["ALERTA"]), "@USUARIO", Convert.ToInt32(a["USUARIO"]));
                        enviados++;
                    }
                }
                catch (Exception ex) { Correo.Registrar("Notificaciones.Alertas usuario=" + g.Key, ex.Message); }
            }
            return enviados;
        }

        private static string HtmlSoporte(Dictionary<string, object> a, string nombre)
        {
            string tipo = T(a, "TIPO_CODIGO");
            string cierre =
                tipo == "SOPORTE RESUELTO" ? "Cuéntanos si quedó resuelto desde el mismo problema. Si no respondes en unos días, lo cerramos solo; si vuelve a ocurrir, puedes reabrirlo." :
                tipo == "SOPORTE INFORMACION" ? "El plazo del problema queda en pausa mientras esperamos tu respuesta." :
                tipo == "SOPORTE VENCIDO" ? "Este aviso sale una sola vez por problema." :
                "Puedes responder directamente desde el problema; no hace falta contestar este correo.";
            return Correo.Plantilla(new Correo.Pieza
            {
                Pre = "Mesa de ayuda",
                Titulo = T(a, "TITULO"),
                Texto = (nombre != "" ? Correo.Html(nombre) + ", " : "") + Correo.Html(T(a, "DESCRIPCION")),
                Detalles = new[] { "Tipo", T(a, "TIPO"), "Empresa", T(a, "CLIENTE"), "Fecha", Comercial.FechaHora(T(a, "DETECTADA")) },
                Boton = "Abrir el problema", Enlace = Url("/View/Soporte/Problema.aspx?id=" + Convert.ToInt32(a["TICKET"])),
                Cierre = cierre, Pie = "Recibes este correo porque participas en este problema de la mesa de ayuda de SIGMA."
            });
        }

        private static string HtmlResumen(List<Dictionary<string, object>> alertas, string nombre)
        {
            List<string> det = new List<string>();
            foreach (Dictionary<string, object> a in alertas.Take(8)) { det.Add(T(a, "TIPO") + " · " + T(a, "CLIENTE")); det.Add(T(a, "TITULO")); }
            return Correo.Plantilla(new Correo.Pieza
            {
                Pre = "Alertas de SIGMA",
                Titulo = alertas.Count == 1 ? T(alertas[0], "TITULO") : "Tienes " + alertas.Count + " alertas nuevas",
                Texto = (nombre != "" ? Correo.Html(nombre) + ", " : "") + "SIGMA detectó " + (alertas.Count == 1 ? "algo que requiere tu atención" : "cosas que requieren tu atención") +
                        " en lo que tienes a cargo." + (alertas.Count > 8 ? " Mostramos las 8 más recientes." : ""),
                Detalles = det.ToArray(),
                Boton = "Ver las alertas", Enlace = Url("/View/Comun/Notificaciones/Notificaciones.aspx"),
                Cierre = "Solo te avisamos por correo de las alertas de severidad alta o crítica.", Pie = "Recibes este correo por los permisos de tu perfil en SIGMA."
            });
        }

        // ------------------------------------------------------------ mesa de ayuda
        /// <summary>Un problema recién reportado: acuse a quien lo reportó y aviso al equipo.</summary>
        public static void SoporteNuevo(int ticket)
        {
            try
            {
                List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_SOPORTE_CORREO", "@TICKET", ticket);
                Dictionary<string, object> t = SoporteDatos.Del(c, 0).FirstOrDefault();
                if (t == null) return;
                string link = Url("/View/Soporte/Problema.aspx?id=" + ticket);
                string folio = T(t, "FOLIO");
                if (T(t, "REPORTA_CORREO") != "")
                    Correo.Encolar("SOPORTE_NUEVO", new[] { T(t, "REPORTA_CORREO") }, null, "[Mesa de ayuda] Recibimos tu reporte " + folio,
                        Correo.Plantilla(new Correo.Pieza
                        {
                            Pre = "Mesa de ayuda · " + folio, Titulo = "Recibimos tu reporte",
                            Texto = Correo.Html(Prim(T(t, "REPORTA"))) + ", gracias por avisarnos. El equipo de la mesa de ayuda ya lo tiene y te responderá por aquí y en SIGMA.",
                            Detalles = new[] { "Folio", folio, "Asunto", T(t, "TITULO"), "Prioridad", T(t, "PRIORIDAD"), "Plazo de respuesta", T(t, "HORAS_SLA") + " h" },
                            Boton = "Ver mi reporte", Enlace = link,
                            Cierre = "Si se te ocurre algo más que ayude (una captura, los pasos exactos), agrégalo desde el reporte.",
                            Pie = "Recibes este correo porque reportaste un problema en SIGMA."
                        }));
                List<string> equipo = SoporteDatos.Del(c, 1).Where(x => Convert.ToInt32(x["ID"]) != Convert.ToInt32(t["REPORTA_ID"])).Select(x => T(x, "CORREO")).Where(x => x != "").ToList();
                if (equipo.Count > 0)
                    Correo.Encolar("SOPORTE_EQUIPO", equipo, null, "[Mesa de ayuda] Nuevo problema " + folio + " · " + T(t, "PRIORIDAD"),
                        Correo.Plantilla(new Correo.Pieza
                        {
                            Pre = "Mesa de ayuda · " + folio, Titulo = "Nuevo problema: " + T(t, "TITULO"),
                            Texto = Correo.Html(T(t, "REPORTA")) + " (" + Correo.Html(T(t, "CLIENTE")) + ") reportó un problema.",
                            Detalles = new[] { "Prioridad", T(t, "PRIORIDAD"), "Plazo", T(t, "HORAS_SLA") + " h", "Descripción", T(t, "DESCRIPCION") },
                            Boton = "Atender el problema", Enlace = link, Pie = "Aviso al equipo de la mesa de ayuda de SIGMA."
                        }));
            }
            catch (Exception ex) { Correo.Registrar("Notificaciones.SoporteNuevo ticket=" + ticket, ex.Message); }
        }

        /// <summary>
        /// Quien reportó escribió y el problema todavía no tiene responsable: no hay a quién avisar por la
        /// alerta puntual, así que se avisa a todo el equipo (para que nadie lo deje esperando).
        /// </summary>
        public static void SoporteRespuestaSinResponsable(int ticket, int autor, string texto)
        {
            try
            {
                List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_SOPORTE_CORREO", "@TICKET", ticket);
                Dictionary<string, object> t = SoporteDatos.Del(c, 0).FirstOrDefault();
                if (t == null || Convert.ToInt32(t["REPORTA_ID"]) != autor || t["RESPONSABLE_ID"] != null) return;
                List<string> equipo = SoporteDatos.Del(c, 1).Where(x => Convert.ToInt32(x["ID"]) != autor).Select(x => T(x, "CORREO")).Where(x => x != "").ToList();
                if (equipo.Count == 0) return;
                Correo.Encolar("SOPORTE_EQUIPO", equipo, null, "[Mesa de ayuda] " + T(t, "REPORTA") + " respondió " + T(t, "FOLIO"),
                    Correo.Plantilla(new Correo.Pieza
                    {
                        Pre = "Mesa de ayuda · " + T(t, "FOLIO"), Titulo = T(t, "REPORTA") + " respondió",
                        Texto = Correo.Html(texto ?? ""), Detalles = new[] { "Problema", T(t, "TITULO"), "Estado", T(t, "ESTADO"), "Responsable", "Sin asignar" },
                        Boton = "Abrir el problema", Enlace = Url("/View/Soporte/Problema.aspx?id=" + ticket), Pie = "Aviso al equipo de la mesa de ayuda de SIGMA."
                    }));
            }
            catch (Exception ex) { Correo.Registrar("Notificaciones.SoporteRespuestaSinResponsable ticket=" + ticket, ex.Message); }
        }

        // ------------------------------------------------------------ demos por vencer (job DEMOS_AVISO)
        public static int DemosPorVencer()
        {
            int n = 0;
            foreach (Dictionary<string, object> d in SoporteDatos.Filas("SEL_DEMOS_POR_AVISAR"))
            {
                int dias = Convert.ToInt32(d["DIAS"]);
                string cuando = dias == 0 ? "vence hoy" : dias == 1 ? "vence mañana" : "vence en 2 días";
                try
                {
                    Correo.Encolar("DEMO_AVISO", new[] { T(d, "EJECUTIVO_CORREO") }, null, "La demo de " + T(d, "EMPRESA") + " " + cuando,
                        Correo.Plantilla(new Correo.Pieza
                        {
                            Pre = "Centro Comercial · " + T(d, "CODIGO"), Titulo = "La demo de " + T(d, "EMPRESA") + " " + cuando,
                            Texto = Correo.Html(Prim(T(d, "EJECUTIVO"))) + ", es buen momento para escribirle a " + Correo.Html(T(d, "CONTACTO")) + ": extiende la demo o envía la propuesta.",
                            Detalles = new[] { "Empresa", T(d, "EMPRESA"), "Contacto", T(d, "CONTACTO"), "Vence el", Comercial.Fecha(T(d, "EXPIRA")) },
                            Boton = "Abrir el lead", Enlace = Url("/View/Comercial/CentroComercial.aspx?lead=" + Convert.ToInt32(d["LEAD"])),
                            Pie = "Aviso automático del Centro Comercial de SIGMA."
                        }));
                    Cobros.Ejecutar("INS_LEAD_ACTIVIDAD", "@LEAD", Convert.ToInt32(d["LEAD"]), "@TIPO", "SISTEMA", "@ICONO", "mail",
                        "@TITULO", "Aviso al ejecutivo: la demo vence pronto", "@DETALLE", "Se le avisó por correo a " + T(d, "EJECUTIVO") + " (" + cuando + ").");
                    n++;
                }
                catch (Exception ex) { Correo.Registrar("Notificaciones.DemosPorVencer lead=" + d["LEAD"], ex.Message); }
            }
            return n;
        }

        // ------------------------------------------------------------ cuentas
        /// <summary>Cuenta nueva: quien la recibe sabe con qué usuario entra y cómo definir su clave.</summary>
        public static void Bienvenida(string correo, string nombre, string login, string empresa)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(correo)) return;
                Correo.Encolar("BIENVENIDA", new[] { correo }, null, "Tu cuenta en SIGMA está lista",
                    Correo.Plantilla(new Correo.Pieza
                    {
                        Pre = "Bienvenida", Titulo = "Tu cuenta en SIGMA está lista",
                        Texto = Correo.Html(Prim(nombre)) + ", creamos tu cuenta" + (string.IsNullOrEmpty(empresa) ? "" : " para <b>" + Correo.Html(empresa) + "</b>") + ". Tu usuario es el que ves abajo; define tu clave con «Olvidé mi contraseña» al entrar por primera vez.",
                        Detalles = new[] { "Usuario", login },
                        Boton = "Entrar a SIGMA", Enlace = Url("/Login.aspx"),
                        Cierre = "Si no esperabas este correo, puedes ignorarlo: nadie podrá entrar sin definir una clave.",
                        Pie = "Mensaje automático de SIGMA."
                    }));
            }
            catch (Exception ex) { Correo.Registrar("Notificaciones.Bienvenida correo=" + correo, ex.Message); }
        }

        /// <summary>Enlace para restablecer la contraseña, con el diseño de siempre.</summary>
        public static string HtmlRecuperacion(string enlace)
        {
            return Correo.Plantilla(new Correo.Pieza
            {
                Pre = "Seguridad de tu cuenta", Titulo = "Restablece tu contraseña",
                Texto = "Recibimos una solicitud para restablecer la contraseña de tu cuenta de SIGMA.",
                Boton = "Restablecer mi contraseña", Enlace = enlace,
                Cierre = "El enlace vence en 60 minutos y sirve una sola vez. Si tú no lo pediste, ignora este correo: tu contraseña no cambia.",
                Pie = "Mensaje automático de SIGMA."
            });
        }
    }
}
