using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// El inicio de SIGMA (Default.aspx): accesos directos por persona, cifras en vivo,
/// indicadores, ordenes recientes, tareas de hoy, lo que requiere atencion y el widget
/// SIGMA AI. Todo sale de los SP «SEL_INICIO_*» (BD/377): aqui no se escribe ninguna cifra.
///
/// Cada bloque que depende de ordenes de trabajo o de predicciones llega vacio si todavia
/// no hay datos, y la pantalla dibuja su estado vacio.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsInicio : System.Web.Services.WebService
{
    private static int U() { return SoporteDatos.Usuario(); }
    private static int Cliente() { return SitioBase.Session.ClienteId(); }

    private const string URL_OT = "~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx";
    private const string URL_OTS = "~/View/Mantenimiento/Ordenes/OrdenTrabajos.aspx";
    private const string URL_PLAN = "~/View/Mantenimiento/Planificacion.aspx";
    private const string URL_PLANES = "~/View/Mantenimiento/Planificacion.aspx";
    private const string URL_NOTIF = "~/View/Comun/Notificaciones/Notificaciones.aspx";

    /// <summary>Los modulos que se pueden fijar como acceso directo: clave, nombre, pagina, si va en oscuro.</summary>
    private static readonly string[][] MODULOS = new string[][] {
        new[] { "twin",    "SIGMA Twin",           "~/View/Inventario/Bodegas/BodegaMapa3D.aspx",              "1" },
        new[] { "ai",      "SIGMA AI",             "~/View/SigmaAI/Experimentos.aspx",                         "1" },
        new[] { "ot",      "Órdenes de trabajo",   URL_OTS,                                                    "0" },
        new[] { "plan",    "Planificación",        URL_PLAN,                                                   "0" },
        new[] { "activos", "Control de activos",   "~/View/Activos/Ficha/ActivoFicha.aspx",                    "0" },
        new[] { "rep",     "Centro de repuestos",  "~/View/Inventario/Repuestos/RepuestoCentro.aspx",          "0" },
        new[] { "perm",    "Permisos de trabajo",  "~/View/Terceros/PermisosTrabajo/PermisoTrabajos.aspx",     "0" },
        new[] { "sop",     "Soporte",              "~/View/Soporte/Inicio.aspx",                               "0" },
        new[] { "alert",   "Alertas",              URL_NOTIF,                                                  "0" },
        new[] { "med",     "Medidores",            "~/View/Activos/Medidores/ActivoMedidores.aspx",            "0" },
        new[] { "ter",     "Terceros",             "~/View/Terceros/Proveedores/Proveedores.aspx",             "0" }
    };
    private static readonly string[] POR_DEFECTO = { "twin", "ai", "ot", "plan", "activos", "rep", "perm", "sop" };

    private static int N(Dictionary<string, object> r, string k) { object v; return r.TryGetValue(k, out v) && v != null ? Convert.ToInt32(v) : 0; }

    private string Url(string virt) { return VirtualPathUtility.ToAbsolute(virt); }

    /// <summary>Todo lo que necesita el inicio para dibujarse, en una sola llamada.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Resumen(int planta)
    {
        return WsSoporte.Ejecutar(() =>
        {
            int cli = Cliente(), usu = U();
            Dictionary<string, object> r = SoporteDatos.Fila("SEL_INICIO_RESUMEN", "@CLIENTE", cli, "@USUARIO", usu);
            /* el widget SIGMA AI se puede filtrar por planta: sus cifras pisan a las de toda la empresa */
            foreach (KeyValuePair<string, object> kv in SoporteDatos.Fila("SEL_INICIO_AI", "@CLIENTE", cli, "@PLANTAS", AiPlantas.Filtro(planta))) r[kv.Key] = kv.Value;
            List<Dictionary<string, object>> guardados = SoporteDatos.Filas("SEL_INICIO_ACCESOS", "@CLIENTE", cli, "@USUARIO", usu);

            List<Dictionary<string, object>> ind = null;
            List<List<Dictionary<string, object>>> indSets = SoporteDatos.Conjuntos("SEL_INICIO_INDICADORES", "@CLIENTE", cli, "@USUARIO", usu);
            Dictionary<string, object> indicadores = indSets.Count > 0 && indSets[0].Count > 0 ? indSets[0][0] : new Dictionary<string, object>();
            ind = SoporteDatos.Del(indSets, 1);

            List<Dictionary<string, object>> ordenes = SoporteDatos.Filas("SEL_INICIO_ORDENES", "@CLIENTE", cli, "@USUARIO", usu);
            foreach (Dictionary<string, object> o in ordenes)
                o["URL"] = Url(URL_OT) + "?query=" + Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + Convert.ToString(o["ID"])));
            List<Dictionary<string, object>> hoy = SoporteDatos.Filas("SEL_INICIO_HOY", "@CLIENTE", cli, "@USUARIO", usu);

            Atencion a = ArmarAtencion();

            /* Las tarjetas de acceso: texto de estado en vivo y si la persona puede abrirlas. */
            List<object> catalogo = new List<object>();
            foreach (string[] m in MODULOS)
            {
                // 428: SIGMA Twin y SIGMA AI solo si el plan comercial los incluye.
                if (m[0] == "twin" && !SitioBase.Controller.PlanFuncion.Incluye(SitioBase.Controller.PlanFuncion.TWIN)) continue;
                if (m[0] == "ai" && !SitioBase.Controller.PlanFuncion.Incluye(SitioBase.Controller.PlanFuncion.AI_CHAT)) continue;
                string s = "", s0 = "", dot = "";
                switch (m[0])
                {
                    case "twin": s = N(r, "BODEGAS") > 0 ? "Gemelo digital · " + N(r, "BODEGAS") + (N(r, "BODEGAS") == 1 ? " bodega" : " bodegas") : "Gemelo digital"; break;
                    case "ai":
                        if (N(r, "PRED_NUEVAS") > 0) { s = N(r, "PRED_NUEVAS") + (N(r, "PRED_NUEVAS") == 1 ? " predicción nueva" : " predicciones nuevas"); dot = "#FF4D9D"; }
                        else if (N(r, "PRED_ACTIVAS") > 0) s = N(r, "PRED_ACTIVAS") + (N(r, "PRED_ACTIVAS") == 1 ? " predicción activa" : " predicciones activas");
                        else s = "Aprendiendo · día " + Math.Min(Math.Max(N(r, "DIAS_LECTURAS"), 0), 30) + " de 30";
                        break;
                    case "ot":
                        if (N(r, "OT_TOTAL") == 0) s = "Sin órdenes aún";
                        else { s = N(r, "OT_ABIERTAS") + (N(r, "OT_ABIERTAS") == 1 ? " abierta" : " abiertas") + " · " + N(r, "OT_VENCIDAS") + (N(r, "OT_VENCIDAS") == 1 ? " vencida" : " vencidas"); if (N(r, "OT_VENCIDAS") > 0) dot = "#C7352B"; }
                        break;
                    case "plan":
                        if (N(r, "PLANES") == 0) s = "Sin plan preventivo";
                        else s = "Semana " + N(r, "SEMANA_ISO") + " · " + N(r, "PLAN_SEMANA") + (N(r, "PLAN_SEMANA") == 1 ? " tarea" : " tareas");
                        break;
                    case "activos": s = N(r, "ACTIVOS") + (N(r, "ACTIVOS") == 1 ? " activo" : " activos") + " · Centro 360°"; break;
                    case "rep": if (a.Stock > 0) { s = a.Stock + " fuera de umbral"; dot = "#B65C00"; } else s = "Existencias y mapa"; break;
                    case "perm": if (a.Permisos > 0) { s = a.Permisos + (a.Permisos == 1 ? " por vencer" : " por vencer"); dot = "#B65C00"; } else s = "Registro de permisos"; break;
                    case "sop": s = N(r, "TICKETS") > 0 ? N(r, "TICKETS") + (N(r, "TICKETS") == 1 ? " ticket abierto" : " tickets abiertos") : "Centro de soporte"; break;
                    case "alert": if (a.Requieren > 0) { s = a.Requieren + (a.Requieren == 1 ? " requiere acción" : " requieren acción"); dot = "#C7352B"; } else s = "Estás al día"; break;
                    case "med": s = a.Medidores > 0 ? a.Medidores + " sin lectura" : "Lecturas y contadores"; if (a.Medidores > 0) dot = "#B65C00"; break;
                    case "ter": s = "Proveedores y contratistas"; break;
                }
                catalogo.Add(new { k = m[0], n = m[1], url = Url(m[2]), dark = m[3] == "1", s = s, dot = dot, ok = Token.PuedePagina(m[2]) });
            }

            List<string> pins;
            if (guardados.Count > 0) pins = guardados.Select(g => Convert.ToString(g["MODULO"])).Where(x => x != "-").ToList();
            else pins = POR_DEFECTO.ToList();

            return new
            {
                catalogo = catalogo,
                pins = pins,
                personalizado = guardados.Count > 0,
                cifras = r,
                plantas = AiPlantas.Lista(),
                planta = planta,
                indicadores = indicadores,
                semanas = ind,
                ordenes = ordenes,
                hoy = hoy,
                atencion = a.Filas,
                atencionTotal = a.Filas.Count,
                urls = new
                {
                    nuevaOt = Token.PuedePagina(URL_OT) ? Url(URL_OT) : "",
                    ordenes = Url(URL_OTS),
                    plan = Url(URL_PLAN),
                    planes = Url(URL_PLANES),
                    notificaciones = Url(URL_NOTIF),
                    ai = Url("~/View/SigmaAI/Experimentos.aspx"),
                    ordenDetalle = Url(URL_OT)
                },
                ordenQuery = Server.UrlEncode(Tools.Crypto.Encrypt("Id=0")),
                cliente = SitioBase.Session.ClienteNombre()
            };
        });
    }

    /// <summary>Los numeros de los contadores del sidebar (se refrescan cada minuto).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Contadores()
    {
        return WsSoporte.Ejecutar(() => new { cont = SoporteDatos.Fila("SEL_MENU_CONTADORES", "@CLIENTE", Cliente(), "@USUARIO", U()) });
    }

    /// <summary>Guarda los accesos directos de la persona (lista de claves). Solo se aceptan modulos que existen.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarAccesos(string modulos)
    {
        return WsSoporte.Ejecutar(() =>
        {
            HashSet<string> validos = new HashSet<string>(MODULOS.Select(m => m[0]));
            List<string> lista = (modulos ?? "").Split(',').Select(x => x.Trim()).Where(x => validos.Contains(x)).Distinct().ToList();
            SoporteDatos.Conjuntos("UPD_INICIO_ACCESOS", "@CLIENTE", Cliente(), "@USUARIO", U(), "@MODULOS", lista.Count == 0 ? "-" : string.Join(",", lista));
            return new { ok = true };
        });
    }

    /// <summary>Las predicciones activas. Con «desde» (hora de la plataforma, ISO) solo las calculadas despues: es el sondeo del widget.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Predicciones(string desde, int planta)
    {
        return WsSoporte.Ejecutar(() =>
        {
            DateTime d;
            object desdeDb = DateTime.TryParse(desde, null, System.Globalization.DateTimeStyles.None, out d) ? (object)d : null;
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_INICIO_PREDICCIONES", "@CLIENTE", Cliente(), "@USUARIO", U(), "@DESDE", desdeDb, "@PLANTAS", AiPlantas.Filtro(planta));
            Dictionary<string, List<string>> razones = new Dictionary<string, List<string>>();
            foreach (Dictionary<string, object> f in SoporteDatos.Del(c, 1))
            {
                string k = Convert.ToString(f["PREDICCION"]);
                if (!razones.ContainsKey(k)) razones[k] = new List<string>();
                razones[k].Add(Convert.ToString(f["TEXTO"]));
            }
            Dictionary<string, List<object>> curvas = new Dictionary<string, List<object>>();
            foreach (Dictionary<string, object> f in SoporteDatos.Del(c, 2))
            {
                string k = Convert.ToString(f["ACTIVO_ID"]);
                if (!curvas.ContainsKey(k)) curvas[k] = new List<object>();
                curvas[k].Add(new { f = f["FECHA"], p = f["PROB"] });
            }
            foreach (Dictionary<string, object> f in SoporteDatos.Del(c, 0))
                if (f["ALERTA_ID"] != null)
                {
                    f["Q"] = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + Convert.ToString(f["ALERTA_ID"])));
                    f["URL"] = Url("~/View/Comun/Notificaciones/AlertaDetalle.aspx");
                }
            List<Dictionary<string, object>> st = SoporteDatos.Del(c, 3);
            return new
            {
                pred = SoporteDatos.Del(c, 0),
                razones = razones,
                curvas = curvas,
                modelo = st.Count > 0 ? st[0] : new Dictionary<string, object>(),
                ahora = SitioBase.Hora.Ahora.ToString("yyyy-MM-ddTHH:mm:ss")
            };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Descartar(int id)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Dictionary<string, object> f = SoporteDatos.Fila("UPD_INICIO_PREDICCION_DESCARTAR", "@CLIENTE", Cliente(), "@USUARIO", U(), "@ID", id, "@MOTIVO", "Descartada desde el inicio");
            return new { ok = f.ContainsKey("FILAS") && Convert.ToInt32(f["FILAS"]) > 0 };
        });
    }

    /* ------------------------------------------------------------------ requieren tu atencion */

    private class Atencion
    {
        public List<object> Filas = new List<object>();
        public int Stock, Permisos, Medidores, Requieren;
    }

    /// <summary>
    /// Las notificaciones mas importantes, agrupadas por tipo + lugar como en el panel de la campana
    /// («6 repuestos bajo el mínimo · Bodega Piso 2»), y los conteos que usan las tarjetas.
    /// </summary>
    private Atencion ArmarAtencion()
    {
        Atencion a = new Atencion();
        List<Alerta> lista;
        try { lista = new AlertaController().GetAlertas(false, 200) ?? new List<Alerta>(); }
        catch (Exception) { lista = new List<Alerta>(); }

        Dictionary<string, List<Alerta>> grupos = new Dictionary<string, List<Alerta>>();
        List<List<Alerta>> orden = new List<List<Alerta>>();
        foreach (Alerta x in lista)
        {
            string lugar = !string.IsNullOrEmpty(x.BODEGA_NOMBRE) ? x.BODEGA_NOMBRE : (x.INSTALACION_NOMBRE ?? "");
            string clave = x.alt_codigo + "|" + lugar;
            List<Alerta> g;
            if (!x.ES_PREDICCION && grupos.TryGetValue(clave, out g)) { g.Add(x); continue; }
            g = new List<Alerta> { x };
            orden.Add(g);
            if (!x.ES_PREDICCION) grupos[clave] = g;

            if (x.Activa)
            {
                if (x.alt_codigo == "STOCK MINIMO" || x.alt_codigo == "STOCK MAXIMO") a.Stock++;
                else if (x.alt_codigo == "PERMISO VENCIDO" || x.alt_codigo == "CERTIFICACION POR VENCER") a.Permisos++;
                else if (x.alt_codigo == "MEDIDOR SIN LECTURA") a.Medidores++;
            }
        }
        /* las alertas que cayeron en un grupo tambien cuentan para los totales */
        foreach (List<Alerta> g in orden)
            for (int i = 1; i < g.Count; i++)
            {
                Alerta x = g[i];
                if (!x.Activa) continue;
                if (x.alt_codigo == "STOCK MINIMO" || x.alt_codigo == "STOCK MAXIMO") a.Stock++;
                else if (x.alt_codigo == "PERMISO VENCIDO" || x.alt_codigo == "CERTIFICACION POR VENCER") a.Permisos++;
                else if (x.alt_codigo == "MEDIDOR SIN LECTURA") a.Medidores++;
            }

        Func<List<Alerta>, int> peso = g => g.Any(x => x.Activa && x.sev_codigo == "CRITICA") ? 0 : g.Any(x => x.Activa && x.sev_codigo == "ALTA") ? 1 : g.Any(x => !x.LEIDA) ? 2 : 3;
        foreach (List<Alerta> g in orden) if (peso(g) <= 1) a.Requieren++;

        foreach (List<Alerta> g in orden.OrderBy(peso).ThenByDescending(g => g.Max(x => x.ale_fecha_deteccion_utc)).Take(4))
        {
            Alerta p = g[0];
            int n = g.Count;
            string sev = peso(g) == 0 ? "c" : peso(g) == 1 ? "a" : "";
            string icono = p.alt_codigo.StartsWith("STOCK") ? "box" : p.alt_codigo.Contains("PERMISO") || p.alt_codigo.Contains("CERTIFICACION") ? "shield"
                         : p.alt_codigo.Contains("MEDI") || p.alt_codigo.Contains("LECTURA") ? "gauge" : p.ES_PREDICCION ? "ai" : p.alt_codigo.Contains("OCURRENCIA") || p.alt_codigo.Contains("COMPARTIDO") || p.alt_codigo.Contains("HALLAZGO") ? "clip" : "bell";
            string lugar = !string.IsNullOrEmpty(p.BODEGA_NOMBRE) ? p.BODEGA_NOMBRE : (p.INSTALACION_NOMBRE ?? "");
            string titulo = n == 1 ? p.ale_titulo
                          : p.alt_codigo == "STOCK MINIMO" ? n + " repuestos bajo el mínimo"
                          : p.alt_codigo == "STOCK MAXIMO" ? n + " repuestos sobre el máximo"
                          : n + " avisos de " + (p.alt_nombre ?? "").ToLowerInvariant();
            string detalle = n == 1 ? (!string.IsNullOrEmpty(p.ACTIVO_NOMBRE) ? p.ACTIVO_NOMBRE : (!string.IsNullOrEmpty(p.REPUESTO_CODIGO) ? p.REPUESTO_CODIGO + (string.IsNullOrEmpty(p.REPUESTO_NOMBRE) ? "" : " · " + p.REPUESTO_NOMBRE) : "")) : "";
            if (lugar != "") detalle = detalle == "" ? lugar : detalle + " · " + lugar;
            Alerta peor = p;
            if (n > 1) { Alerta cand = g.Where(x => x.ale_valor_observado != null && x.ale_valor_umbral != null && x.ale_valor_umbral > 0).OrderBy(x => (double)x.ale_valor_observado.Value / (double)x.ale_valor_umbral.Value).FirstOrDefault(); if (cand != null && p.alt_codigo == "STOCK MINIMO") detalle += " · el más bajo: " + (cand.REPUESTO_CODIGO ?? cand.ale_titulo); }
            a.Filas.Add(new
            {
                sev = sev, icono = icono, titulo = titulo, detalle = detalle, grupo = n > 1,
                id = p.ale_id,
                q = n == 1 ? Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + p.ale_id)) : "",
                url = n == 1 ? Url("~/View/Comun/Notificaciones/AlertaDetalle.aspx") : Url(URL_NOTIF)
            });
        }
        return a;
    }
}
