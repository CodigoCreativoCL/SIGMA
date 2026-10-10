using SitioBase;
using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// Avisos (rediseño de Mantenimiento en cinco lugares, parte b): la bandeja única de lo
/// detectado que todavía no es trabajo. Une fallas, hallazgos de inspección, hallazgos al
/// ejecutar una OT, predicciones de SIGMA AI y alertas de medidor (VW_AVISOS, BD/397).
///
/// CADA MÉTODO VALIDA SESIÓN Y PERMISO; el cliente sale de la sesión, nunca del navegador.
/// El aviso se identifica por (origen, ref): el origen es el de Orden_Trabajo_Origen
/// (7 falla, 4 hallazgo de inspección, 9 hallazgo en OT, 5 SIGMA AI, 6 alerta de medidor).
/// Los mensajes son los del SP, sin el número y sin la caja alta.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsAvisos : System.Web.Services.WebService
{
    private const string P_OT = "CREAR ORDEN TRABAJO";
    private const string P_FALLA = "REGISTRAR FALLA";
    private static readonly string[] P_VER = { "VER ORDENES TRABAJO", "VER HALLAZGOS", "VER ALERTAS MANTENIMIENTO", "VER PREDICCIONES" };

    /// <summary>La bandeja, los atajos de motivo y lo que la persona puede hacer.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Cargar(int planta)
    {
        return Ejecutar(() =>
        {
            ExigirVer();
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_AVISOS", "@CLIENTE", Cli(), "@INSTALACION", planta > 0 ? (object)planta : null);
            List<Dictionary<string, object>> avisos = SoporteDatos.Del(c, 0);
            foreach (Dictionary<string, object> a in avisos)
            {
                object ot = Valor(a, "OT_ID");
                if (ot != null) a["OT_URL"] = UrlOt(Convert.ToInt32(ot));
            }
            return new { avisos = avisos, motivos = SoporteDatos.Del(c, 1), permisos = Permisos() };
        });
    }

    /// <summary>Las OT abiertas del activo y de su área y planta: el anti-duplicado y el «Vincular».</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string OtAbiertas(int activo)
    {
        return Ejecutar(() =>
        {
            ExigirVer();
            return new { ots = SoporteDatos.Filas("SEL_AVISO_OT_ABIERTAS", "@CLIENTE", Cli(), "@ACTIVO", activo) };
        });
    }

    /// <summary>Activos (con su área) y componentes para «Reportar falla».</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Catalogo(int planta)
    {
        return Ejecutar(() =>
        {
            Exigir(P_FALLA);
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_AVISO_CATALOGO", "@CLIENTE", Cli(), "@INSTALACION", planta > 0 ? (object)planta : null);
            return new { activos = SoporteDatos.Del(c, 0), componentes = SoporteDatos.Del(c, 1) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Generar(int origen, int refId)
    {
        return Ejecutar(() =>
        {
            Exigir(P_OT);
            Dictionary<string, object> r = SoporteDatos.Fila("UPS_AVISO_GENERAR_OT", "@CLIENTE", Cli(), "@ORIGEN", origen, "@REF", refId, "@USUARIO", U());
            return new { ot = Valor(r, "OTR_CORRELATIVO"), otId = Valor(r, "OTR_ID"), url = UrlOt(Convert.ToInt32(Valor(r, "OTR_ID"))), ya = EsVerdad(r, "YA_EXISTIA") };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Vincular(int origen, int refId, int ot)
    {
        return Ejecutar(() =>
        {
            Exigir(P_OT);
            Dictionary<string, object> r = SoporteDatos.Fila("UPS_AVISO_VINCULAR", "@CLIENTE", Cli(), "@ORIGEN", origen, "@REF", refId, "@OT", ot, "@USUARIO", U());
            return new { ot = Valor(r, "OTR_CORRELATIVO"), otId = Valor(r, "OTR_ID"), url = UrlOt(Convert.ToInt32(Valor(r, "OTR_ID"))) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Descartar(int origen, int refId, string motivo)
    {
        return Ejecutar(() =>
        {
            Exigir(P_OT);
            SoporteDatos.Filas("UPD_AVISO_DESCARTAR", "@CLIENTE", Cli(), "@ORIGEN", origen, "@REF", refId, "@MOTIVO", motivo ?? "", "@USUARIO", U());
            return new { ok = true };
        });
    }

    /// <summary>Deshace un descarte (el «Deshacer» del aviso emergente).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Reabrir(int origen, int refId)
    {
        return Ejecutar(() =>
        {
            Exigir(P_OT);
            SoporteDatos.Filas("UPD_AVISO_REABRIR", "@CLIENTE", Cli(), "@ORIGEN", origen, "@REF", refId, "@USUARIO", U());
            return new { ok = true };
        });
    }

    /// <summary>Reporta una falla; si se pide, genera de inmediato su OT correctiva.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string ReportarFalla(int activo, int componente, string titulo, string detalle, int criticidad, int estadoPosterior, bool detuvo, bool generar)
    {
        return Ejecutar(() =>
        {
            Exigir(P_FALLA);
            if (generar) Exigir(P_OT);
            Dictionary<string, object> r = SoporteDatos.Fila("UPS_AVISO_REPORTAR_FALLA", "@CLIENTE", Cli(), "@ACTIVO", activo,
                "@COMPONENTE", componente > 0 ? (object)componente : null, "@TITULO", titulo ?? "", "@DETALLE", string.IsNullOrWhiteSpace(detalle) ? null : detalle,
                "@CRITICIDAD", criticidad, "@ESTADO_POSTERIOR", estadoPosterior > 0 ? (object)estadoPosterior : null,
                "@DETUVO", detuvo, "@GENERAR", generar, "@USUARIO", U());
            object otId = Valor(r, "OTR_ID");
            return new { falla = Valor(r, "FAL_ID"), ot = Valor(r, "OTR_CORRELATIVO"), otId = otId, url = otId == null ? null : UrlOt(Convert.ToInt32(otId)) };
        });
    }

    // ---------------------------------------------------------------------

    private static object Permisos()
    {
        return new { generar = Token.Puede(P_OT), reportar = Token.Puede(P_FALLA) };
    }

    private static void ExigirVer()
    {
        if (!P_VER.Any(p => Token.Puede(p))) throw new Exception("No tienes permiso para ver los avisos.");
    }

    private static void Exigir(string permiso)
    {
        if (!Token.Puede(permiso)) throw new Exception("No tienes permiso para esta acción.");
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

    /// <summary>La ficha de la OT, con el id cifrado como en el resto del sitio.</summary>
    private static string UrlOt(int id)
    {
        return VirtualPathUtility.ToAbsolute("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx") + "?query=" + HttpUtility.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));
    }

    private static int Cli() { return SitioBase.Session.ClienteId(); }
    private static int U() { return SoporteDatos.Usuario(); }

    private static object Valor(Dictionary<string, object> d, string k)
    {
        if (d == null) return null;
        foreach (KeyValuePair<string, object> kv in d)
            if (string.Equals(kv.Key, k, StringComparison.OrdinalIgnoreCase)) return kv.Value;
        return null;
    }

    private static bool EsVerdad(Dictionary<string, object> d, string k)
    {
        object v = Valor(d, k);
        if (v == null) return false;
        if (v is bool) return (bool)v;
        string t = Convert.ToString(v).Trim().ToLowerInvariant();
        return t == "1" || t == "true";
    }
}
