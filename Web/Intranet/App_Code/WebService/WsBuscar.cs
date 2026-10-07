using SitioBase;
using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Web;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// «Ir a…» (Ctrl K): busca activos, ordenes de trabajo y repuestos. Las pantallas las filtra el
/// navegador sobre el propio menu (ya viene filtrado por permisos). Tope de 12 resultados y solo
/// de los tipos que la persona puede abrir.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsBuscar : System.Web.Services.WebService
{
    private const string URL_ACTIVO = "~/View/Activos/Ficha/ActivoFicha.aspx";
    private const string URL_OTS = "~/View/Mantenimiento/Ordenes/OrdenTrabajos.aspx";
    private const string URL_OT = "~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx";
    private const string URL_REP = "~/View/Inventario/Repuestos/RepuestoCentro.aspx";
    private const string URL_REP_F = "~/View/Inventario/Repuestos/Repuesto.aspx";

    private static string Cifrar(string s) { return HttpUtility.UrlEncode(Tools.Crypto.Encrypt(s)); }
    private static string Abs(string v) { return VirtualPathUtility.ToAbsolute(v); }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Buscar(string q)
    {
        return WsSoporte.Ejecutar(() =>
        {
            bool a = Token.PuedePagina(URL_ACTIVO), o = Token.PuedePagina(URL_OTS), r = Token.PuedePagina(URL_REP);
            List<object> items = new List<object>();
            if (string.IsNullOrWhiteSpace(q) || q.Trim().Length < 2 || (!a && !o && !r)) return new { items = items };

            foreach (Dictionary<string, object> f in SoporteDatos.Filas("SEL_BUSCAR_GLOBAL", "@CLIENTE", SitioBase.Session.ClienteId(), "@Q", q.Trim(),
                                                                         "@ACTIVOS", a, "@ORDENES", o, "@REPUESTOS", r, "@LIMITE", 12))
            {
                string tipo = Convert.ToString(f["TIPO"]), id = Convert.ToString(f["ID"]);
                string url = tipo == "Activo" ? Abs(URL_ACTIVO) + "?query=" + Cifrar("Id=" + id)
                           : tipo == "Repuesto" ? Abs(URL_REP_F) + "?query=" + Cifrar("Id=" + id)
                           : Abs(URL_OT) + "?query=" + Cifrar("Id=" + id);
                items.Add(new { tipo = tipo, id = id, t = Convert.ToString(f["TITULO"]), s = Convert.ToString(f["SUBTITULO"]), url = url, modal = tipo == "Repuesto" });
            }
            return new { items = items };
        });
    }
}
