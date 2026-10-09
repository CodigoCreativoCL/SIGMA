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
            return new { areas = areas, personas = personas.Select(p => new { ID = p["ID"], NOMBRE = p["NOMBRE"] }).ToList() };
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
