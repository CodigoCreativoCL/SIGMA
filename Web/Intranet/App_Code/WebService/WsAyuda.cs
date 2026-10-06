using SitioBase;
using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// El centro de ayuda: cápsulas, videos, manuales, guías y la ayuda
/// contextual «? Ayuda» de cada pantalla.
///
/// Quien ve que lo decide FNC_AYUDA_VISIBLE en la base (publicado y dentro
/// de la audiencia, o administrador de la ayuda).
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsAyuda : System.Web.Services.WebService
{
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Contenidos()
    {
        return WsSoporte.Ejecutar(() =>
        {
            var c = SoporteDatos.Conjuntos("SEL_AYUDA_CONTENIDOS", "@USUARIO", U(), "@CLIENTE", Cliente());
            Dictionary<string, object> p = SoporteDatos.Del(c, 2).Count > 0 ? SoporteDatos.Del(c, 2)[0] : new Dictionary<string, object>();
            return new { contenidos = SoporteDatos.Del(c, 0), categorias = SoporteDatos.Del(c, 1), permisos = p };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Contenido(int id, string origen)
    {
        return WsSoporte.Ejecutar(() =>
        {
            var c = SoporteDatos.Conjuntos("SEL_AYUDA_CONTENIDO", "@ID", id, "@USUARIO", U(), "@CLIENTE", Cliente(),
                                           "@ORIGEN", string.IsNullOrEmpty(origen) ? null : origen);
            Dictionary<string, object> k = SoporteDatos.Del(c, 0).Count > 0 ? SoporteDatos.Del(c, 0)[0] : null;
            if (k != null)
            {
                int arc = k["ayc_archivo"] == null ? 0 : Convert.ToInt32(k["ayc_archivo"]);
                k["ARCHIVO_URL"] = arc > 0 ? UrlArchivo.Ver(arc) : null;
                k["ARCHIVO_BAJAR"] = arc > 0 ? UrlArchivo.Descargar(arc) : null;
            }
            List<Dictionary<string, object>> vinculos = SoporteDatos.Del(c, 3);
            foreach (Dictionary<string, object> v in vinculos)
                v["URL"] = v["LINK"] == null ? null : System.Web.VirtualPathUtility.ToAbsolute(Convert.ToString(v["LINK"]));
            return new
            {
                contenido = k,
                pasos = SoporteDatos.Del(c, 1),
                recs = SoporteDatos.Del(c, 2),
                vinculos = vinculos,
                versiones = SoporteDatos.Del(c, 4),
                relacionados = SoporteDatos.Del(c, 5),
                uso = SoporteDatos.Del(c, 6).Count > 0 ? SoporteDatos.Del(c, 6)[0] : null,
                mia = SoporteDatos.Del(c, 7).Count > 0 ? SoporteDatos.Del(c, 7)[0] : null
            };
        });
    }

    /// <summary>descarga · reproduccion · completo</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Interaccion(int id, string tipo, string origen)
    {
        return WsSoporte.Ejecutar(() =>
        {
            SoporteDatos.Conjuntos("INS_AYUDA_INTERACCION", "@ID", id, "@USUARIO", U(), "@CLIENTE", Cliente(), "@TIPO", tipo, "@ORIGEN", origen);
            return new { ok = true };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Valorar(int id, bool util, int estrellas)
    {
        return WsSoporte.Ejecutar(() =>
        {
            SoporteDatos.Fila("UPS_AYUDA_VALORACION", "@ID", id, "@USUARIO", U(), "@CLIENTE", Cliente(), "@UTIL", util,
                              "@ESTRELLAS", estrellas > 0 ? (object)estrellas : null);
            return new { ok = true };
        });
    }

    /// <summary>Se registra para «Búsquedas sin resultados».</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Busqueda(string texto, int resultados)
    {
        return WsSoporte.Ejecutar(() =>
        {
            SoporteDatos.Conjuntos("INS_AYUDA_BUSQUEDA", "@TEXTO", texto, "@RESULTADOS", resultados, "@USUARIO", U(), "@CLIENTE", Cliente());
            return new { ok = true };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Contextual(string modulo, string submodulo, string pantalla, string seccion)
    {
        return WsSoporte.Ejecutar(() => new
        {
            items = string.IsNullOrWhiteSpace(modulo) ? new List<Dictionary<string, object>>()
                  : SoporteDatos.Filas("SEL_AYUDA_CONTEXTUAL", "@USUARIO", U(), "@CLIENTE", Cliente(), "@MODULO", modulo,
                                       "@SUBMODULO", Nulo(submodulo), "@PANTALLA", Nulo(pantalla), "@SECCION", Nulo(seccion))
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Pantallas()
    {
        return WsSoporte.Ejecutar(() =>
        {
            var c = SoporteDatos.Conjuntos("SEL_AYUDA_PANTALLAS");
            return new { pantallas = SoporteDatos.Del(c, 0), secciones = SoporteDatos.Del(c, 1) };
        });
    }

    /* ---------------- Administrar (el SP exige AYUDA ADMINISTRAR) ---------------- */

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Guardar(string datos)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Dictionary<string, object> f = SoporteDatos.Fila("UPS_AYUDA_CONTENIDO", "@USUARIO", U(), "@DATOS", datos);
            return new { id = f["ayc_id"], estado = f["ayc_estado"], version = f["ayc_version"] };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string NuevaVersion(int id, string version, string nota, int archivo)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Dictionary<string, object> f = SoporteDatos.Fila("INS_AYUDA_VERSION", "@ID", id, "@USUARIO", U(), "@VERSION", Nulo(version),
                                                              "@NOTA", nota, "@ARCHIVO", archivo > 0 ? (object)archivo : null);
            return new { version = f["ayc_version"] };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Restaurar(int version)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Dictionary<string, object> f = SoporteDatos.Fila("UPD_AYUDA_RESTAURAR", "@VERSION_ID", version, "@USUARIO", U());
            return new { version = f["ayc_version"] };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Estado(int id, string estado)
    {
        return WsSoporte.Ejecutar(() =>
        {
            SoporteDatos.Fila("UPD_AYUDA_CONTENIDO_ESTADO", "@ID", id, "@USUARIO", U(), "@ESTADO", estado);
            return new { ok = true };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Categoria(int id, string nombre, string modulo, string icono, string tono)
    {
        return WsSoporte.Ejecutar(() =>
        {
            Dictionary<string, object> f = SoporteDatos.Fila("UPS_AYUDA_CATEGORIA", "@ID", id > 0 ? (object)id : null, "@USUARIO", U(),
                                                              "@NOMBRE", nombre, "@MODULO", modulo, "@ICONO", Nulo(icono), "@TONO", Nulo(tono));
            return new { id = f["aca_id"] };
        });
    }

    /// <summary>Sube el archivo de una cápsula, video o documento (hasta 60 MB).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Subir(string nombre, string mime, string base64, string destino)
    {
        return WsSoporte.Ejecutar(() =>
        {
            if (!Token.Puede("AYUDA ADMINISTRAR") && !Token.Puede("CAMPANAS ADMINISTRAR"))
                throw new Exception("No tienes permiso para subir contenido de ayuda.");
            int id = SoporteDatos.SubirArchivo(Cliente(), destino == "campanas" ? "global/campanas" : "global/ayuda", nombre, mime, base64, 60);
            return new { id = id, url = UrlArchivo.Ver(id) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Analitica(int dias)
    {
        return WsSoporte.Ejecutar(() =>
        {
            var c = SoporteDatos.Conjuntos("SEL_AYUDA_ANALITICA", "@USUARIO", U(), "@DIAS", dias);
            return new
            {
                kpi = SoporteDatos.Del(c, 0).Count > 0 ? SoporteDatos.Del(c, 0)[0] : null,
                dias = SoporteDatos.Del(c, 1),
                evitados = SoporteDatos.Del(c, 2),
                sinResultados = SoporteDatos.Del(c, 3)
            };
        });
    }

    private static int U() { return SoporteDatos.Usuario(); }
    private static int Cliente() { return SitioBase.Session.ClienteId(); }
    private static object Nulo(string s) { return string.IsNullOrWhiteSpace(s) ? null : s.Trim(); }
}
