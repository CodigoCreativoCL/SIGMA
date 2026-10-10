using SitioBase;
using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// Operación (rediseño de Mantenimiento en cinco lugares, parte d): el centro de control del día.
/// Lee SEL_OPERACION_HOY (BD/400): indicadores, agenda de hoy, atención requerida, estado por área y tendencia.
/// Cada método valida sesión y permiso; el cliente sale de la sesión, nunca del navegador.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsOperacion : System.Web.Services.WebService
{
    private static readonly string[] P_VER = { "VER PLANES MANTENIMIENTO", "VER ORDENES TRABAJO", "VER HALLAZGOS", "VER ALERTAS MANTENIMIENTO" };

    /// <summary>El tablero de Hoy, con los filtros de Operación (todos opcionales).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Hoy(int planta, int area, int responsable, int criticidad)
    {
        return Ejecutar(() =>
        {
            Exigir();
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_OPERACION_HOY", "@CLIENTE", Cli(),
                "@INSTALACION", planta > 0 ? (object)planta : null, "@AREA", area > 0 ? (object)area : null,
                "@RESPONSABLE", responsable > 0 ? (object)responsable : null, "@CRITICIDAD", criticidad > 0 ? (object)criticidad : null);
            List<Dictionary<string, object>> k = SoporteDatos.Del(c, 0);
            List<Dictionary<string, object>> agenda = SoporteDatos.Del(c, 1), sinOt = SoporteDatos.Del(c, 3), otv = SoporteDatos.Del(c, 4);
            foreach (Dictionary<string, object> f in agenda)
            {
                string tipo = Convert.ToString(f["TIPO"]);
                if (tipo == "PLAN") f["Q"] = Q(Convert.ToInt32(f["ID"]));
                if (f["OT_ID"] != null && f["OT_ID"] != DBNull.Value) f["QOT"] = Q(Convert.ToInt32(f["OT_ID"]));
            }
            foreach (Dictionary<string, object> f in sinOt) f["Q"] = Q(Convert.ToInt32(f["ID"]));
            foreach (Dictionary<string, object> f in otv) f["QOT"] = Q(Convert.ToInt32(f["OT_ID"]));
            return new
            {
                kpi = k.Count > 0 ? k[0] : null,
                agenda = agenda,
                atrasadas = SoporteDatos.Del(c, 2),
                sinOt = sinOt,
                otVencidas = otv,
                avisos = SoporteDatos.Del(c, 5),
                riesgo = SoporteDatos.Del(c, 6),
                activos = SoporteDatos.Del(c, 7),
                tendencia = SoporteDatos.Del(c, 8),
                ia = SoporteDatos.Del(c, 9),
                puedeOt = Token.Puede("CREAR ORDEN TRABAJO"),
                urlOt = System.Web.VirtualPathUtility.ToAbsolute("~/View/Mantenimiento/Ordenes/Ordenes.aspx")
            };
        });
    }

    /// <summary>Áreas de la planta y personas, para los filtros.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Filtros(int planta)
    {
        return Ejecutar(() =>
        {
            Exigir();
            List<Dictionary<string, object>> areas = SoporteDatos.Filas("SEL_OPERACION_AREAS", "@CLIENTE", Cli(), "@INSTALACION", planta > 0 ? (object)planta : null);
            List<Dictionary<string, object>> personas = SoporteDatos.Filas("SEL_PLAN_CENTRO_PERSONAS", "@CLIENTE", Cli());
            foreach (Dictionary<string, object> p in personas) { int foto = p["FOTO_ID"] == null || p["FOTO_ID"] is DBNull ? 0 : Convert.ToInt32(p["FOTO_ID"]); p["FOTO"] = foto > 0 ? SitioBase.UrlArchivo.Ver(foto) : ""; }
            return new { areas = areas, personas = personas.Select(p => new { ID = p["ID"], NOMBRE = p["NOMBRE"], PERFIL = p["PERFIL"], ESPECIALIDAD = p["ESPECIALIDAD"], FOTO = p["FOTO"] }).ToList() };
        });
    }

    /// <summary>La lista única de ejecuciones (planes, inspecciones y tareas) con los filtros de Operación.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Ejecuciones(int planta, int area, int responsable, int criticidad, string desde, string hasta)
    {
        return Ejecutar(() =>
        {
            Exigir();
            DateTime d, h;
            object dd = DateTime.TryParseExact(desde ?? "", "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out d) ? (object)d : null;
            object hh = DateTime.TryParseExact(hasta ?? "", "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out h) ? (object)h : null;
            List<Dictionary<string, object>> l = SoporteDatos.Filas("SEL_OPERACION_EJECUCIONES", "@CLIENTE", Cli(),
                "@INSTALACION", planta > 0 ? (object)planta : null, "@AREA", area > 0 ? (object)area : null,
                "@RESPONSABLE", responsable > 0 ? (object)responsable : null, "@CRITICIDAD", criticidad > 0 ? (object)criticidad : null, "@DESDE", dd, "@HASTA", hh);
            // 414 · choques de horario (BD/413): la ejecución que choca lleva su detalle.
            Dictionary<string, string> choq = new Dictionary<string, string>();
            foreach (Dictionary<string, object> x in SoporteDatos.Del(SoporteDatos.Conjuntos("SEL_AGENDA_CHOQUES_RESUMEN", "@CLIENTE", Cli()), 0))
                choq[Convert.ToString(x["TIPO"]) + "-" + Convert.ToString(x["OCURRENCIA"])] = Convert.ToString(x["DETALLE"]);
            Dictionary<string, string> tipoAgenda = new Dictionary<string, string> { { "PLAN", "PLAN" }, { "INSPECCION", "INS" }, { "TAREA", "TAR" } };
            foreach (Dictionary<string, object> f in l)
            {
                f["KEY"] = Convert.ToString(f["TIPO"]) + "-" + Convert.ToString(f["ID"]);
                string ta, ch;
                if (tipoAgenda.TryGetValue(Convert.ToString(f["TIPO"]), out ta) && choq.TryGetValue(ta + "-" + Convert.ToString(f["ID"]), out ch)) f["CHOQUE"] = ch;
                if (Convert.ToString(f["TIPO"]) == "PLAN") f["Q"] = Q(Convert.ToInt32(f["ID"]));
                if (f["OT_ID"] != null && f["OT_ID"] != DBNull.Value) f["QOT"] = Q(Convert.ToInt32(f["OT_ID"]));
            }
            return new { filas = l };
        });
    }

    /// <summary>Marca una tarea como hecha, o la deja pendiente (el «Deshacer»).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string TareaHecha(int id, bool hecha)
    {
        return Ejecutar(() =>
        {
            Exigir();
            SoporteDatos.Filas("UPD_OPERACION_TAREA_HECHA", "@CLIENTE", Cli(), "@ID", id, "@HECHA", hecha, "@USUARIO", SoporteDatos.Usuario());
            return new { ok = true };
        });
    }

    /// <summary>El cumplimiento del mes elegido (planes, inspecciones y tareas).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Cumplimiento(int planta, int area, int responsable, int criticidad, string mes)
    {
        return Ejecutar(() =>
        {
            Exigir();
            DateTime m;
            object mm = DateTime.TryParseExact(mes ?? "", "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out m) ? (object)m : null;
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_OPERACION_CUMPLIMIENTO", "@CLIENTE", Cli(),
                "@INSTALACION", planta > 0 ? (object)planta : null, "@AREA", area > 0 ? (object)area : null,
                "@RESPONSABLE", responsable > 0 ? (object)responsable : null, "@CRITICIDAD", criticidad > 0 ? (object)criticidad : null, "@MES", mm);
            List<Dictionary<string, object>> k = SoporteDatos.Del(c, 0);
            return new { kpi = k.Count > 0 ? k[0] : null, serie = SoporteDatos.Del(c, 1), tipos = SoporteDatos.Del(c, 2), fuentes = SoporteDatos.Del(c, 3), activos = SoporteDatos.Del(c, 4), responsables = SoporteDatos.Del(c, 5) };
        });
    }

    /// <summary>Lo que la sala de control dibuja entre dos fechas (trabajos y áreas).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Monitoreo(int planta, int area, int responsable, int criticidad, string desde, string hasta)
    {
        return Ejecutar(() =>
        {
            Exigir();
            DateTime d, h;
            if (!DateTime.TryParseExact(desde ?? "", "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out d) ||
                !DateTime.TryParseExact(hasta ?? "", "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out h) || h < d || (h - d).TotalDays > 60)
                throw new Exception("El rango de fechas no es válido.");
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_OPERACION_MONITOREO", "@CLIENTE", Cli(),
                "@INSTALACION", planta > 0 ? (object)planta : null, "@AREA", area > 0 ? (object)area : null,
                "@RESPONSABLE", responsable > 0 ? (object)responsable : null, "@CRITICIDAD", criticidad > 0 ? (object)criticidad : null, "@DESDE", d, "@HASTA", h);
            List<Dictionary<string, object>> filas = SoporteDatos.Del(c, 0);
            foreach (Dictionary<string, object> f in filas)
            {
                f["KEY"] = Convert.ToString(f["TIPO"]) + "-" + Convert.ToString(f["ID"]);
                if (f["OT_ID"] != null && f["OT_ID"] != DBNull.Value) f["QOT"] = Q(Convert.ToInt32(f["OT_ID"]));
            }
            return new { filas = filas, areas = SoporteDatos.Del(c, 1) };
        });
    }

    /// <summary>418 · Una inspección para el cajón de Operación: cabecera, ítems de la pauta y, si ya se hizo, sus hallazgos.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Inspeccion(int ocurrencia)
    {
        return Ejecutar(() =>
        {
            Exigir();
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_OPERACION_INSPECCION", "@CLIENTE", Cli(), "@OCURRENCIA", ocurrencia);
            List<Dictionary<string, object>> cab = SoporteDatos.Del(c, 0);
            if (cab.Count == 0) throw new Exception("Esta inspección ya no está programada.");
            // 425: lo que se registró (app o web): respuestas, fotos y datos de la ejecución.
            List<Dictionary<string, object>> fotos = SoporteDatos.Del(c, 4);
            foreach (Dictionary<string, object> f in fotos) f["URL"] = SitioBase.UrlArchivo.Ver(Convert.ToInt32(f["ARCHIVO"]));
            List<Dictionary<string, object>> ej = SoporteDatos.Del(c, 5);
            return new { cab = cab[0], items = SoporteDatos.Del(c, 1), hallazgos = SoporteDatos.Del(c, 2), respuestas = SoporteDatos.Del(c, 3), fotos = fotos, ejecucion = ej.Count > 0 ? ej[0] : null, puede = Token.Puede(P_EJECUTAR) };
        });
    }

    /// <summary>418 · Registra una inspección desde la web con los mismos SP de la app: abre la ejecución,
    /// guarda cada respuesta (lo que no cumple o sale de rango abre su hallazgo, que llega a Avisos) y la cierra.
    /// datos = { ocurrencia, observacion, respuestas: [{ item, tipo: ok|num|txt|foto, v }] } (ok: si|no|na).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string RegistrarInspeccion(string datos)
    {
        return Ejecutar(() =>
        {
            if (!Token.Puede(P_EJECUTAR)) throw new Exception("No tienes permiso para registrar inspecciones.");
            Dictionary<string, object> d = new System.Web.Script.Serialization.JavaScriptSerializer().Deserialize<Dictionary<string, object>>(datos ?? "{}");
            int cli = Cli(), usu = SoporteDatos.Usuario(), ocu = Convert.ToInt32(d.ContainsKey("ocurrencia") ? d["ocurrencia"] : 0);
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_OPERACION_INSPECCION", "@CLIENTE", cli, "@OCURRENCIA", ocu);
            List<Dictionary<string, object>> cab = SoporteDatos.Del(c, 0);
            if (cab.Count == 0) throw new Exception("Esta inspección ya no está programada.");
            if (!Convert.ToBoolean(cab[0]["PUEDE"])) throw new Exception("Esta inspección ya se registró o todavía no está disponible.");
            HashSet<int> items = new HashSet<int>(SoporteDatos.Del(c, 1).Select(x => Convert.ToInt32(x["ID"])));

            List<Dictionary<string, object>> ej = SoporteDatos.Filas("API_INS_CHECKLIST_EJECUCION", "@UUID", Guid.NewGuid(), "@USUARIO", usu, "@CLIENTE", cli, "@OCURRENCIA", ocu, "@DISPOSITIVO", "Web · Operación");
            if (ej.Count == 0 || ej[0]["cej_id"] == null || ej[0]["cej_id"] == DBNull.Value) throw new Exception("No se pudo abrir la inspección.");
            int cej = Convert.ToInt32(ej[0]["cej_id"]);

            System.Collections.ArrayList rs = d.ContainsKey("respuestas") ? d["respuestas"] as System.Collections.ArrayList : null;
            foreach (object o in rs ?? new System.Collections.ArrayList())
            {
                Dictionary<string, object> r = o as Dictionary<string, object>; if (r == null) continue;
                int item = Convert.ToInt32(r.ContainsKey("item") ? r["item"] : 0); if (!items.Contains(item)) continue;
                string tipo = Convert.ToString(r.ContainsKey("tipo") ? r["tipo"] : ""), v = Convert.ToString(r.ContainsKey("v") ? r["v"] : "").Trim();
                object texto = null, numero = null, booleano = null; bool na = false; string com = null;
                if (tipo == "ok") { if (v == "si") booleano = true; else if (v == "no") booleano = false; else na = true; }
                else if (tipo == "num")
                {
                    decimal n;
                    if (v.Length == 0) na = true;
                    else if (decimal.TryParse(v.Replace(',', '.'), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out n)) numero = n;
                    else throw new Exception("Una medición no es un número válido.");
                }
                else if (tipo == "foto") { na = true; com = "Registrada desde la web: la foto se adjunta desde la app."; }
                else { if (v.Length == 0) na = true; else texto = v; }
                SoporteDatos.Filas("API_UPS_CHECKLIST_RESPUESTA", "@CEJ_ID", cej, "@USUARIO", usu, "@CLIENTE", cli, "@ITEM", item,
                    "@VALOR_TEXTO", texto, "@VALOR_NUMERO", numero, "@VALOR_BOOLEANO", booleano, "@NO_APLICA", na, "@COMENTARIO", com);
            }
            string obs = Convert.ToString(d.ContainsKey("observacion") ? d["observacion"] : "").Trim();
            SoporteDatos.Filas("API_UPD_CHECKLIST_CERRAR", "@CEJ_ID", cej, "@USUARIO", usu, "@CLIENTE", cli, "@OBSERVACION", obs.Length > 0 ? (object)obs : null);
            List<Dictionary<string, object>> hz = SoporteDatos.Del(SoporteDatos.Conjuntos("SEL_OPERACION_INSPECCION", "@CLIENTE", cli, "@OCURRENCIA", ocu), 2);
            return new { ok = true, hallazgos = hz.Count };
        });
    }

    private const string P_EJECUTAR = "EJECUTAR CHECKLIST";

    /// <summary>425 · Una ocurrencia de tarea con lo que se registró en terreno: quién, cuándo, duración, resultado y fotos.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Tarea(int ocurrencia)
    {
        return Ejecutar(() =>
        {
            Exigir();
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_OPERACION_TAREA", "@CLIENTE", Cli(), "@OCURRENCIA", ocurrencia);
            List<Dictionary<string, object>> cab = SoporteDatos.Del(c, 0);
            if (cab.Count == 0) throw new Exception("Esta tarea ya no está programada.");
            List<Dictionary<string, object>> fotos = SoporteDatos.Del(c, 2);
            foreach (Dictionary<string, object> f in fotos) f["URL"] = SitioBase.UrlArchivo.Ver(Convert.ToInt32(f["ARCHIVO"]));
            object ot = cab[0]["OT_ID"];
            if (ot != null) cab[0]["QOT"] = Q(Convert.ToInt32(ot));
            return new { cab = cab[0], ejecuciones = SoporteDatos.Del(c, 1), fotos = fotos };
        });
    }

    private static void Exigir()
    {
        if (!P_VER.Any(p => Token.Puede(p))) throw new Exception("No tienes permiso para ver Operación.");
    }

    private static string Ejecutar(Func<object> accion)
    {
        try
        {
            if (!Token.TokenSeguridad())
                return WsSoporte.Json(new { error = true, sesion = true, detalle = "La sesión expiró. Vuelve a entrar." });
            return WsSoporte.Json(accion());
        }
        catch (Exception ex)
        {
            return WsSoporte.Json(new { error = true, detalle = WsCentroPlanificacion.Limpio(ex.Message) });
        }
    }

    private static int Cli() { return SitioBase.Session.ClienteId(); }
    private static string Q(int id) { return System.Web.HttpUtility.UrlEncode(Tools.Crypto.Encrypt("Id=" + id)); }
}
