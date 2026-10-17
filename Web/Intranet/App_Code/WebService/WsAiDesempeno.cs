using SitioBase;
using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// SIGMA AI · Desempeño (EP-17, BD/475): evaluar las predicciones cuyo horizonte venció (HU-177) y ver cómo rinde cada
/// versión del modelo por mes (HU-178). Ver exige VER PREDICCIONES; registrar un resultado, GENERAR OT PREDICCION
/// (la facultad de actuar sobre una predicción). La regla de clasificación vive en el SP, no en la pantalla.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsAiDesempeno : System.Web.Services.WebService
{
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string PorEvaluar()
    {
        return Ejecutar(() =>
        {
            ExigirVer();
            return new { filas = SoporteDatos.Filas("SEL_AI_POR_EVALUAR", "@CLIENTE", Cli()), puede = Token.Puede("GENERAR OT PREDICCION") };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Desempeno()
    {
        return Ejecutar(() =>
        {
            ExigirVer();
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_AI_DESEMPENO", "@CLIENTE", Cli());
            return new { meses = SoporteDatos.Del(c, 0), evaluaciones = SoporteDatos.Del(c, 1) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Evaluar(int prediccion, bool ocurrio, string fecha, bool intervencion, int falla, string observacion)
    {
        return Ejecutar(() =>
        {
            ExigirVer();
            if (!Token.Puede("GENERAR OT PREDICCION")) throw new Exception("No tienes permiso para evaluar predicciones.");
            DateTime d;
            object f = DateTime.TryParseExact(fecha ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? (object)d : null;
            Dictionary<string, object> r = SoporteDatos.Fila("INS_AI_PREDICCION_RESULTADO", "@CLIENTE", Cli(), "@PREDICCION", prediccion, "@OCURRIO", ocurrio, "@FECHA_EVENTO", f,
                "@MANTENIMIENTO_PREVIO", intervencion, "@FALLA", falla > 0 ? (object)falla : null, "@OBSERVACION", string.IsNullOrWhiteSpace(observacion) ? null : observacion.Trim(), "@USUARIO", SoporteDatos.Usuario());
            return new { ok = true, clasificacion = r.ContainsKey("CLASIFICACION") ? r["CLASIFICACION"] : null, error = r.ContainsKey("ERROR_DIAS") ? r["ERROR_DIAS"] : null };
        });
    }

    private static void ExigirVer()
    {
        if (!Token.Puede("VER PREDICCIONES")) throw new Exception("No tienes permiso para ver las predicciones.");
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
}
