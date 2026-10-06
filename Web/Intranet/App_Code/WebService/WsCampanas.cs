using SitioBase;
using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// Campañas: el centro, el asistente con su constructor de audiencia y la
/// entrega a cada usuario (banner, modal, card y la campana de siempre).
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsCampanas : System.Web.Services.WebService
{
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Campanas()
    {
        return WsSoporte.Ejecutar(() =>
        {
            List<Dictionary<string, object>> l = SoporteDatos.Filas("SEL_CAMPANAS", "@USUARIO", U());
            foreach (Dictionary<string, object> c in l) Imagen(c);
            return new { campanas = l };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Seguimiento(int id)
    {
        return WsSoporte.Ejecutar(() =>
        {
            var c = SoporteDatos.Conjuntos("SEL_CAMPANA_SEGUIMIENTO", "@ID", id, "@USUARIO", U());
            return new { dias = SoporteDatos.Del(c, 0), totales = SoporteDatos.Del(c, 1).Count > 0 ? SoporteDatos.Del(c, 1)[0] : null };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Guardar(string datos)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Dictionary<string, object> f = SoporteDatos.Fila("UPS_CAMPANA", "@USUARIO", U(), "@DATOS", datos);
            return new { id = f["cam_id"], estado = f["cam_estado"], alcance = f["cam_alcance"], desde = f["cam_desde"] };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Estado(int id, string estado)
    {
        return WsSoporte.Ejecutar(() =>
        {
            SoporteDatos.Fila("UPD_CAMPANA_ESTADO", "@ID", id, "@USUARIO", U(), "@ESTADO", estado);
            return new { ok = true };
        });
    }

    /// <summary>El total del constructor, que se recalcula al cambiar cada condición.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Audiencia(string condiciones, string union, string dimension)
    {
        return WsSoporte.Ejecutar(() =>
        {
            var c = SoporteDatos.Conjuntos("SEL_CAMPANA_AUDIENCIA", "@USUARIO", U(), "@CONDICIONES", string.IsNullOrEmpty(condiciones) ? "[]" : condiciones,
                                           "@UNION", union == "OR" ? "OR" : "AND", "@DIMENSION", dimension);
            return new
            {
                conteo = SoporteDatos.Del(c, 0).Count > 0 ? SoporteDatos.Del(c, 0)[0] : null,
                caras = SoporteDatos.Del(c, 1),
                reparto = SoporteDatos.Del(c, 2)
            };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Valores()
    {
        return WsSoporte.Ejecutar(() =>
        {
            var c = SoporteDatos.Conjuntos("SEL_CAMPANA_AUDIENCIA_VALORES", "@USUARIO", U());
            return new { valores = SoporteDatos.Del(c, 0), segmentos = SoporteDatos.Del(c, 1) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarSegmento(string nombre, string union, string condiciones)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Dictionary<string, object> f = SoporteDatos.Fila("INS_CAMPANA_SEGMENTO", "@USUARIO", U(), "@NOMBRE", nombre, "@UNION", union, "@CONDICIONES", condiciones);
            return new { id = f["csg_id"] };
        });
    }

    /* ---------------- Entrega al usuario ---------------- */

    /// <summary>Lo que le toca ver ahora a la persona en esta pantalla.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Pendientes(string modulo)
    {
        return WsSoporte.Ejecutar(() =>
        {
            int cliente = SitioBase.Session.ClienteId();
            if (cliente <= 0) return new { campanas = new List<Dictionary<string, object>>() };
            List<Dictionary<string, object>> l = SoporteDatos.Filas("SEL_CAMPANA_PENDIENTES", "@USUARIO", U(), "@CLIENTE", cliente,
                                                                    "@MODULO", string.IsNullOrWhiteSpace(modulo) ? null : modulo);
            foreach (Dictionary<string, object> c in l) Imagen(c);
            return new { campanas = l };
        });
    }

    /// <summary>vista · interaccion · descarte · confirmacion</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Entrega(int campana, string accion)
    {
        return WsSoporte.Ejecutar(() =>
        {
            SoporteDatos.Conjuntos("UPD_CAMPANA_ENTREGA", "@CAMPANA", campana, "@USUARIO", U(), "@CLIENTE", SitioBase.Session.ClienteId(), "@ACCION", accion);
            return new { ok = true };
        });
    }

    private static void Imagen(Dictionary<string, object> c)
    {
        int arc = c.ContainsKey("cam_archivo") && c["cam_archivo"] != null ? Convert.ToInt32(c["cam_archivo"]) : 0;
        c["IMAGEN_URL"] = arc > 0 ? UrlArchivo.Ver(arc) : null;
    }

    private static int U() { return SoporteDatos.Usuario(); }
}
