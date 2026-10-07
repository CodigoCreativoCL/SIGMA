using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Web;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// SIGMA AI · Centro de monitoreo (View/SigmaAI/Centro.aspx).
///
/// Todo sale de los SP «SEL_AI_*» (BD/379), que a su vez leen lo que ya guardan /sigma-ai/predecir
/// (SIGMA FAILURE 30D y SIGMA RUL) y /sigma-ai/vision/clasificar (SIGMA VISION). Aqui no se
/// escribe ninguna cifra: si un modelo no tiene datos, el bloque llega vacio y la vista dice por que.
/// Las acciones (puntuar, confirmar una foto) pasan por la API /sigma-ai/*; las propias del centro
/// (descartar con motivo, pedir reposicion, bitacora) por sus SP.
///
/// EL COPILOTO NO ES UN MODELO DE LENGUAJE
///   Responde con reglas sobre los mismos SP (predicciones, vida util, fotos, modelos, OT e
///   inventario), cita siempre sus fuentes y, cuando no tiene el dato, lo dice.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsAiCentro : System.Web.Services.WebService
{
    private const string P_VER = "VER PREDICCIONES";
    private const string P_OT = "GENERAR OT PREDICCION";
    private static readonly CultureInfo CL = new CultureInfo("es-CL");

    private static int U() { return SoporteDatos.Usuario(); }
    private static int Cli() { return SitioBase.Session.ClienteId(); }
    private static string Abs(string v) { return VirtualPathUtility.ToAbsolute(v); }
    private static string Cifrar(string s) { return HttpUtility.UrlEncode(Tools.Crypto.Encrypt(s)); }

    private static void Exigir(string permiso)
    {
        if (!Token.Puede(permiso)) throw new Exception("No tienes permiso para esta acción.");
    }

    private static T V<T>(Dictionary<string, object> f, string k, T def)
    {
        object o; if (f == null || !f.TryGetValue(k, out o) || o == null) return def;
        try { return (T)Convert.ChangeType(o, Nullable.GetUnderlyingType(typeof(T)) ?? typeof(T), CultureInfo.InvariantCulture); } catch (Exception) { return def; }
    }

    /// <summary>Todo lo que la vista necesita para dibujarse.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Estado(int planta)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Exigir(P_VER);
            int cli = Cli(); string pls = AiPlantas.Filtro(planta);
            var pl = SoporteDatos.Conjuntos("SEL_AI_PLANTA", "@CLIENTE", cli, "@PLANTAS", pls);
            var co = SoporteDatos.Conjuntos("SEL_AI_COLA", "@CLIENTE", cli, "@PLANTAS", pls);
            var vi = SoporteDatos.Conjuntos("SEL_AI_VISION", "@CLIENTE", cli);
            var mo = SoporteDatos.Conjuntos("SEL_AI_MODELOS", "@CLIENTE", cli);
            return new
            {
                cliente = SitioBase.Session.ClienteNombre(), usuario = (SitioBase.Session.UsuarioNombre() ?? "").Split(' ')[0],
                areas = SoporteDatos.Del(pl, 0), activos = ConFotos(SoporteDatos.Del(pl, 1), cli),
                resumen = One(SoporteDatos.Del(pl, 2)), salud = SoporteDatos.Del(pl, 3), senales = One(SoporteDatos.Del(pl, 4)), histograma = SoporteDatos.Del(pl, 5),
                cola = SoporteDatos.Del(co, 0), tendencias = Tendencias(SoporteDatos.Del(co, 1)),
                rul = SoporteDatos.Filas("SEL_AI_RUL", "@CLIENTE", cli, "@PLANTAS", pls),
                fotos = Fotos(vi), pendientes = V(One(SoporteDatos.Del(vi, 2)), "PENDIENTES", 0),
                modelos = SoporteDatos.Del(mo, 0), versiones = SoporteDatos.Del(mo, 1),
                mes = One(new List<Dictionary<string, object>>(SoporteDatos.Filas("SEL_AI_MES", "@CLIENTE", cli, "@PLANTAS", pls))),
                eventos = SoporteDatos.Filas("SEL_AI_EVENTOS", "@CLIENTE", cli, "@DESDE", null, "@PLANTAS", pls),
                puedeOt = Token.Puede(P_OT), puedeModelos = Token.Puede("ENTRENAR MODELOS"),
                plantas = AiPlantas.Lista(), planta = planta,
                urls = new { twin = Abs("~/View/Inventario/Bodegas/BodegaMapa3D.aspx"), ordenes = Abs("~/View/Mantenimiento/Ordenes/OrdenTrabajos.aspx") },
                ahora = SitioBase.Hora.Ahora.ToString("yyyy-MM-ddTHH:mm:ss")
            };
        });
    }

    /// <summary>El sondeo: bitacora desde la ultima marca, la cola y los totales.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Pulso(string desde, int planta)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Exigir(P_VER);
            int cli = Cli(); string pls = AiPlantas.Filtro(planta);
            DateTime d; object dd = DateTime.TryParse(desde, null, DateTimeStyles.None, out d) ? (object)d : null;
            var pl = SoporteDatos.Conjuntos("SEL_AI_PLANTA", "@CLIENTE", cli, "@PLANTAS", pls);
            var co = SoporteDatos.Conjuntos("SEL_AI_COLA", "@CLIENTE", cli, "@PLANTAS", pls);
            return new
            {
                eventos = SoporteDatos.Filas("SEL_AI_EVENTOS", "@CLIENTE", cli, "@DESDE", dd, "@PLANTAS", pls),
                activos = ConFotos(SoporteDatos.Del(pl, 1), cli), resumen = One(SoporteDatos.Del(pl, 2)), salud = SoporteDatos.Del(pl, 3), senales = One(SoporteDatos.Del(pl, 4)), histograma = SoporteDatos.Del(pl, 5),
                cola = SoporteDatos.Del(co, 0), tendencias = Tendencias(SoporteDatos.Del(co, 1)),
                ahora = SitioBase.Hora.Ahora.ToString("yyyy-MM-ddTHH:mm:ss")
            };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Detalle(int id)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Exigir(P_VER);
            var c = SoporteDatos.Conjuntos("SEL_AI_DETALLE", "@CLIENTE", Cli(), "@ID", id);
            return new { rec = One(SoporteDatos.Del(c, 0)), razones = SoporteDatos.Del(c, 1), curva = SoporteDatos.Del(c, 2), medidor = SoporteDatos.Del(c, 3) };
        });
    }

    /// <summary>«Puntuar ahora»: la API puntua los activos (FAILURE 30D) y los repuestos instalados (RUL) y lo anota en la bitacora.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Puntuar()
    {
        return WsSoporte.Ejecutar(() =>
        {
            Exigir(P_VER);
            if (!Services.Disponible) throw new Exception("La API de SIGMA AI no está disponible: " + Services.Motivo);
            StringBuilder msg = new StringBuilder();
            int activos = 0, repuestos = 0;
            try { var r = Services.PostJson("/sigma-ai/predecir?modelo=FALLA", new Dictionary<string, object>()); activos = Convert.ToInt32(r["equipos"], CultureInfo.InvariantCulture); }
            catch (Exception ex) { msg.Append("FAILURE 30D: " + ex.Message + " "); }
            try { var r = Services.PostJson("/sigma-ai/predecir?modelo=RUL", new Dictionary<string, object>()); repuestos = Convert.ToInt32(r["equipos"], CultureInfo.InvariantCulture); }
            catch (Exception ex) { msg.Append("RUL: " + ex.Message); }
            if (activos == 0 && repuestos == 0 && msg.Length > 0) throw new Exception(msg.ToString().Trim());
            Evento('f', "Puntuación manual completa: **" + activos + (activos == 1 ? " activo" : " activos") + "** y **" + repuestos + (repuestos == 1 ? " repuesto" : " repuestos") + "**", null);
            return new { activos = activos, repuestos = repuestos, aviso = msg.ToString().Trim() };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CrearOt(int prediccion)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Exigir(P_OT);
            var fila = SoporteDatos.Filas("SEL_AI_COLA", "@CLIENTE", Cli()).FirstOrDefault(x => V(x, "ID", 0) == prediccion);
            if (fila == null || V(fila, "ALERTA_ID", 0) == 0) throw new Exception("Esta predicción aún no tiene una alerta asociada: no se puede generar la orden.");
            Respuesta r = new AlertaController().GenerarOrdenTrabajo(V(fila, "ALERTA_ID", 0));
            if (r.error) throw new Exception(r.detalle);
            Evento('o', "Orden de trabajo creada desde SIGMA AI · **" + V(fila, "ACTIVO", "") + "**", V(fila, "ACTIVO_ID", 0));
            return new { ot = r.codigo, detalle = r.detalle };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Descartar(int id, string motivo, string detalle)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Exigir(P_VER);
            SoporteDatos.Conjuntos("UPD_AI_PREDICCION_DESCARTAR", "@CLIENTE", Cli(), "@USUARIO", U(), "@ID", id, "@MOTIVO", motivo ?? "", "@DETALLE", detalle);
            return new { ok = true };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Reabrir(int id)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Exigir(P_VER);
            var f = SoporteDatos.Fila("UPD_AI_PREDICCION_REABRIR", "@CLIENTE", Cli(), "@USUARIO", U(), "@ID", id);
            return new { ok = V(f, "FILAS", 0) > 0 };
        });
    }

    /// <summary>Confirmar o corregir la etiqueta de una deteccion: siempre lo hace una persona (API /sigma-ai/vision/confirmar).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string ConfirmarFoto(int deteccion, string etiqueta, string anterior, string activo)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Exigir(P_VER);
            if (string.IsNullOrWhiteSpace(etiqueta)) throw new Exception("Falta la etiqueta.");
            Services.PostJson("/sigma-ai/vision/confirmar", new Dictionary<string, object> { { "deteccion", deteccion }, { "etiqueta", etiqueta.Trim() } });
            string quien = (SitioBase.Session.UsuarioNombre() ?? "").Split(' ')[0];
            bool corrige = !string.IsNullOrEmpty(anterior) && !string.Equals(anterior, etiqueta, StringComparison.OrdinalIgnoreCase);
            Evento('v', corrige ? "**" + quien + "** corrigió la etiqueta de " + anterior.ToLower() + " a **" + etiqueta.ToLower() + "** · " + activo
                                : "**" + quien + "** confirmó " + etiqueta.ToLower() + " · " + activo, null);
            return new { ok = true };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string PedirRepuesto(int repuesto, int prediccion)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Exigir(P_VER);
            var f = SoporteDatos.Fila("INS_SOLICITUD_COMPRA", "@CLIENTE", Cli(), "@USUARIO", U(), "@REPUESTO", repuesto, "@CANTIDAD", null, "@MOTIVO", "Vida útil restante menor al umbral de aviso (SIGMA RUL)", "@PREDICCION", prediccion > 0 ? (object)prediccion : null);
            return new { numero = V(f, "NUMERO", 0), cantidad = V(f, "CANTIDAD", 0.0) };
        });
    }

    /* ---------------------------------------------------------------------- utilidades */

    private static void Evento(char tipo, string mensaje, int? activo)
    {
        try { SoporteDatos.Conjuntos("INS_AI_EVENTO", "@CLIENTE", Cli(), "@USUARIO", U(), "@TIPO", tipo.ToString(), "@MENSAJE", mensaje, "@ACTIVO", activo.HasValue && activo.Value > 0 ? (object)activo.Value : null); }
        catch (Exception) { }
    }

    /// <summary>La imagen principal de cada activo (la misma de su ficha), para el tooltip de la planta.</summary>
    private static List<Dictionary<string, object>> ConFotos(List<Dictionary<string, object>> activos, int cli)
    {
        Dictionary<string, int> imgs;
        try { imgs = new ActivoImagenController().GetImagenesLista(cli) ?? new Dictionary<string, int>(); } catch (Exception) { imgs = new Dictionary<string, int>(); }
        foreach (Dictionary<string, object> a in activos)
        {
            int arc; string k = "A" + Convert.ToString(a["ID"]);
            a["FOTO"] = imgs.TryGetValue(k, out arc) && arc > 0 ? UrlArchivo.Ver(arc) : null;
        }
        return activos;
    }

    private static Dictionary<string, object> One(List<Dictionary<string, object>> l) { return l != null && l.Count > 0 ? l[0] : new Dictionary<string, object>(); }

    private static Dictionary<string, List<object>> Tendencias(List<Dictionary<string, object>> filas)
    {
        Dictionary<string, List<object>> d = new Dictionary<string, List<object>>();
        foreach (Dictionary<string, object> f in filas)
        {
            string k = Convert.ToString(f["ACTIVO_ID"]);
            if (!d.ContainsKey(k)) d[k] = new List<object>();
            d[k].Add(new { f = f["FECHA"], p = f["PROB"] });
        }
        return d;
    }

    /// <summary>Cada foto con sus detecciones y la direccion de la imagen.</summary>
    private List<object> Fotos(List<List<Dictionary<string, object>>> vi)
    {
        List<Dictionary<string, object>> dets = SoporteDatos.Del(vi, 1);
        List<object> fotos = new List<object>();
        foreach (Dictionary<string, object> r in SoporteDatos.Del(vi, 0))
        {
            int id = V(r, "ID", 0), arc = V(r, "ARCHIVO", 0);
            fotos.Add(new
            {
                id = id, url = arc > 0 ? UrlArchivo.Ver(arc) : "", nombre = V(r, "NOMBRE", ""), subio = V(r, "SUBIO", ""), fecha = r["FECHA"], revisado = V(r, "REVISADO", false), version = V(r, "VERSION", 0),
                dets = dets.Where(x => V(x, "REVISION", 0) == id).ToList()
            });
        }
        return fotos;
    }

    /* ---------------------------------------------------------------------- copiloto */

    private static string Norm(string s)
    {
        string d = (s ?? "").Normalize(NormalizationForm.FormD);
        StringBuilder b = new StringBuilder();
        foreach (char c in d) if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark) b.Append(char.ToLowerInvariant(c));
        return b.ToString();
    }

    private static string Plazo(Dictionary<string, object> p)
    {
        int d = V(p, "DIAS", -1);
        if (d < 0) return "sin plazo estimado";
        int lo = V(p, "DIAS_MIN", -1), hi = V(p, "DIAS_MAX", -1);
        return lo >= 0 && hi > lo && lo <= d && d <= hi ? lo + "–" + hi + " días" : "~" + d + (d == 1 ? " día" : " días");
    }

    private static object Fuente(string k, string txt) { return new { k = k, t = txt }; }

    /// <summary>
    /// Responde con datos de SIGMA y los cita. Devuelve {texto, fuentes, acciones}; el texto marca con **
    /// lo importante. Si no sabe algo, lo dice.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Copiloto(string pregunta, int activo, int planta)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Exigir(P_VER);
            int cli = Cli(); string pls = AiPlantas.Filtro(planta);
            string n = Norm(pregunta);
            var cola = SoporteDatos.Filas("SEL_AI_COLA", "@CLIENTE", cli, "@PLANTAS", pls).Where(x => V(x, "ESTADO", "") != "d").ToList();
            Func<Dictionary<string, object>, string> hora = p => { DateTime t; return DateTime.TryParse(V(p, "CALCULADA", ""), null, DateTimeStyles.None, out t) ? t.ToString("HH:mm") : ""; };
            Func<Dictionary<string, object>, string> nombre = p => V(p, "COMPONENTE", "") != "" ? V(p, "ACTIVO", "") + " · " + V(p, "COMPONENTE", "") : V(p, "ACTIVO", "");
            List<object> acciones = new List<object>();
            List<object> fuentes = new List<object>();
            string texto;

            if (n.Contains("foto") || n.Contains("vision") || n.Contains("confirm"))
            {
                var vi = SoporteDatos.Conjuntos("SEL_AI_VISION", "@CLIENTE", cli);
                int pend = V(One(SoporteDatos.Del(vi, 2)), "PENDIENTES", 0);
                texto = pend > 0 ? "Hay **" + pend + (pend == 1 ? " foto" : " fotos") + "** esperando que una persona confirme la etiqueta. Cada confirmación entra al próximo entrenamiento de SIGMA VISION."
                                 : "No hay fotos por confirmar ahora mismo.";
                fuentes.Add(Fuente("v", "SIGMA VISION"));
                if (pend > 0) acciones.Add(new { tipo = "goto", rotulo = "Ir a las fotos", valor = "vis" });
            }
            else if (n.Contains("repuesto") || n.Contains("stock") || n.Contains("vida") || n.Contains("rul") || n.Contains("bodega"))
            {
                var rul = SoporteDatos.Filas("SEL_AI_RUL", "@CLIENTE", cli, "@PLANTAS", pls);
                var riesgo = rul.Where(x => V(x, "DIAS", 9999) < 30 && V(x, "STOCK", 0.0) < Math.Max(1.0, V(x, "MINIMO", 0.0))).ToList();
                if (rul.Count == 0) texto = "SIGMA RUL aún no tiene repuestos puntuados: **no tengo datos de vida útil** para responder eso.";
                else if (riesgo.Count == 0) texto = "Ninguno de los **" + rul.Count + "** repuestos instalados va a faltar antes de terminar su vida útil: los que quedan por debajo de 30 días tienen stock.";
                else
                {
                    texto = "Estos repuestos se acaban antes de que haya stock: " + string.Join(", ", riesgo.Take(3).Select(x => "**" + V(x, "REPUESTO", "") + "** (" + V(x, "DIAS", 0) + " días, stock " + V(x, "STOCK", 0.0).ToString("0.##", CL) + ")")) + ".";
                    var primero = riesgo[0];
                    if (!V(primero, "PEDIDO", false)) acciones.Add(new { tipo = "pedir", rotulo = "Pedir " + V(primero, "REPUESTO", ""), valor = V(primero, "REPUESTO_ID", 0) + "|" + V(primero, "ID", 0) });
                    acciones.Add(new { tipo = "goto", rotulo = "Ver vida útil", valor = "rul" });
                }
                fuentes.Add(Fuente("r", "SIGMA RUL"));
            }
            else if (n.Contains("modelo") || n.Contains("precis") || n.Contains("acierto") || n.Contains("confia"))
            {
                bool equipo = Token.Puede("ENTRENAR MODELOS");
                var mo = SoporteDatos.Del(SoporteDatos.Conjuntos("SEL_AI_MODELOS", "@CLIENTE", cli), 0);
                var mes = SoporteDatos.Filas("SEL_AI_MES", "@CLIENTE", cli, "@PLANTAS", pls);
                var pub = mo.Where(m => V(m, "VERSION", 0) > 0).ToList();
                if (!equipo) { var m0 = One(mes); texto = "Este mes: **" + V(m0, "ANTICIPADAS", 0) + "** fallas anticipadas, **" + V(m0, "FALSAS", 0) + "** falsas alarmas y **" + V(m0, "NO_ANTICIPADAS", 0) + "** fallas no anticipadas."; }
                else if (pub.Count == 0) texto = "Ningún modelo tiene una versión publicada: **no hay métricas** que mostrar todavía.";
                else
                {
                    texto = "Hay **" + pub.Count + " modelos publicados**: " + string.Join(", ", pub.Select(m => V(m, "MODELO", "") + " v" + V(m, "VERSION", 0)));
                    var f = pub.FirstOrDefault(m => V(m, "AUC", 0.0) > 0);
                    if (f != null) texto += ". " + V(f, "MODELO", "") + " tiene AUC " + V(f, "AUC", 0.0).ToString("0.00", CL);
                    var m1 = One(mes);
                    texto += ". Este mes: **" + V(m1, "ANTICIPADAS", 0) + "** fallas anticipadas, **" + V(m1, "FALSAS", 0) + "** falsas alarmas y **" + V(m1, "NO_ANTICIPADAS", 0) + "** fallas no anticipadas.";
                }
                fuentes.Add(Fuente("f", equipo ? "Versiones publicadas" : "Predicciones y órdenes correctivas"));
                acciones.Add(new { tipo = "goto", rotulo = equipo ? "Ver los modelos" : "Ver resultados", valor = "mod" });
            }
            else if (n.Contains("primero") || n.Contains("prioridad") || n.Contains("hoy") || n.Contains("empiezo"))
            {
                var top = cola.Where(x => V(x, "ESTADO", "") != "o").OrderBy(x => V(x, "DIAS", 9999)).ThenByDescending(x => V(x, "PROB", 0.0)).Take(3).ToList();
                if (top.Count == 0) texto = "No hay predicciones abiertas: **nada urgente** que revisar según SIGMA FAILURE 30D.";
                else
                {
                    texto = "Por urgencia: " + string.Join("; ", top.Select((x, i) => (i == 0 ? "primero " : "luego ") + "**" + nombre(x) + "** (" + V(x, "PROB", 0.0).ToString("0", CL) + " %, " + Plazo(x) + ")")) + ".";
                    acciones.Add(new { tipo = "sel", rotulo = "Ver " + V(top[0], "ACTIVO", ""), valor = V(top[0], "ID", 0).ToString() });
                    fuentes.Add(Fuente("f", "FAILURE 30D · v" + V(top[0], "VERSION", 0) + " · " + hora(top[0])));
                }
            }
            else if (n.Contains("turno") || n.Contains("resumen") || n.Contains("dia"))
            {
                var res = One(SoporteDatos.Del(SoporteDatos.Conjuntos("SEL_AI_PLANTA", "@CLIENTE", cli, "@PLANTAS", pls), 2));
                texto = "Hay **" + cola.Count + "** predicciones abiertas (**" + V(res, "CRITICAS", 0) + "** críticas y **" + V(res, "ALTAS", 0) + "** altas) sobre " + V(res, "TOTAL", 0) + " activos. Salud de la planta: **" + V(res, "SALUD", 0.0).ToString("0", CL) + "**.";
                fuentes.Add(Fuente("f", "FAILURE 30D"));
            }
            else
            {
                var p = cola.FirstOrDefault(x => V(x, "ACTIVO_ID", 0) == activo) ?? (n.Contains("por que") || n.Contains("porque") || n.Contains("explica") ? cola.FirstOrDefault() : null);
                if (p == null)
                {
                    texto = "No tengo datos de SIGMA para responder eso. Puedo decirte **por qué** un activo tiene una predicción, **qué revisar primero**, qué **repuestos** están en riesgo, qué **fotos** esperan confirmación o cómo van los **modelos**.";
                }
                else
                {
                    var det = SoporteDatos.Conjuntos("SEL_AI_DETALLE", "@CLIENTE", cli, "@ID", V(p, "ID", 0));
                    var razones = SoporteDatos.Del(det, 1).Take(3).Select(x => V(x, "TEXTO", "")).Where(x => x != "").ToList();
                    texto = "**" + nombre(p) + "** tiene " + V(p, "PROB", 0.0).ToString("0", CL) + " % de probabilidad de falla en " + Plazo(p) + "." + (razones.Count > 0 ? " Lo que más pesa: " + string.Join(", ", razones.Select(r => r.ToLower())) + "." : " El modelo no guardó las razones de esta puntuación.");
                    fuentes.Add(Fuente("f", "FAILURE 30D · v" + V(p, "VERSION", 0) + " · " + hora(p)));
                    if (V(p, "ESTADO", "") != "o" && V(p, "ALERTA_ID", 0) > 0 && Token.Puede(P_OT)) acciones.Add(new { tipo = "ot", rotulo = "Crear OT", valor = V(p, "ID", 0).ToString() });
                }
            }
            return new { texto = texto, fuentes = fuentes, acciones = acciones };
        });
    }
}
