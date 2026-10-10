using System;
using System.Collections.Generic;
using System.Web;

namespace SitioBase.Controller
{
    /// <summary>
    /// 423 · Qué incluye el plan comercial del cliente (Funcionalidad / Plan_Comercial_Funcionalidad).
    /// Se usa para lo que se vende por plan y no solo por permiso: SIGMA AI Chat y SIGMA Twin.
    ///
    /// Se lee una vez cada 5 minutos por sesión y cliente (SEL_CLIENTE_FUNCIONALIDADES). Un cliente
    /// sin suscripción (ambiente de prueba) no se bloquea: el SP devuelve todo incluido.
    /// Mismo patrón que SoportePlan (la ticketera de Soporte).
    /// </summary>
    public static class PlanFuncion
    {
        public const string AI_CHAT = "SIGMA AI CHAT";
        public const string TWIN = "SIGMA TWIN";

        /* Las pantallas que solo existen si el plan incluye su funcionalidad. */
        private static readonly Dictionary<string, string> PANTALLAS = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "~/View/Inventario/Bodegas/BodegaMapa3D.aspx", TWIN },
            { "~/View/SigmaAI/Centro.aspx", AI_CHAT },
            { "~/View/SigmaAI/Experimentos.aspx", AI_CHAT }
        };

        private static Dictionary<string, bool> Mapa()
        {
            HttpContext ctx = HttpContext.Current;
            int cliente = Session.ClienteId();
            string clave = "SG_PLANFUN_" + cliente;
            if (ctx != null && ctx.Session != null)
            {
                object[] g = ctx.Session[clave] as object[];
                if (g != null && (DateTime)g[0] > DateTime.UtcNow) return (Dictionary<string, bool>)g[1];
            }
            Dictionary<string, bool> m = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);
            try
            {
                foreach (Dictionary<string, object> f in SoporteDatos.Filas("SEL_CLIENTE_FUNCIONALIDADES", "@CLIENTE", cliente))
                    m[Convert.ToString(f["CODIGO"])] = f["INCLUIDA"] != null && Convert.ToBoolean(f["INCLUIDA"]);
            }
            catch (Exception) { return null; }   // sin el SP (base sin el 423) no se bloquea nada
            if (ctx != null && ctx.Session != null) ctx.Session[clave] = new object[] { DateTime.UtcNow.AddMinutes(5), m };
            return m;
        }

        /// <summary>True si el plan del cliente incluye la funcionalidad (o si no se pudo saber).</summary>
        public static bool Incluye(string codigo)
        {
            Dictionary<string, bool> m = Mapa();
            bool v;
            return m == null || !m.TryGetValue(codigo, out v) || v;
        }

        public static bool PermiteMenu(string link)
        {
            string cod;
            return string.IsNullOrEmpty(link) || !PANTALLAS.TryGetValue(link, out cod) || Incluye(cod);
        }

        /// <summary>Para el Page_Load de las pantallas que dependen del plan: si no lo incluye, vuelve al inicio.</summary>
        public static void ExigirPantalla(string codigo)
        {
            if (!Incluye(codigo)) HttpContext.Current.Response.Redirect("~/Default.aspx");
        }

        /// <summary>428 · Para el navegador (window.SIGMA_PLAN): qué incluye el plan y si el usuario puede abrir cada vista.</summary>
        public static string Json()
        {
            bool ai = Incluye(AI_CHAT) && Token.PuedePagina("~/View/SigmaAI/Centro.aspx"), tw = Incluye(TWIN) && Token.PuedePagina("~/View/Inventario/Bodegas/BodegaMapa3D.aspx");
            Func<string, string> u = x => VirtualPathUtility.ToAbsolute(x);
            return "{\"ai\":" + (Incluye(AI_CHAT) ? "true" : "false") + ",\"twin\":" + (Incluye(TWIN) ? "true" : "false") +
                   ",\"verAi\":" + (ai ? "true" : "false") + ",\"verTwin\":" + (tw ? "true" : "false") +
                   ",\"urlAi\":\"" + u("~/View/SigmaAI/Centro.aspx") + "\",\"urlTwin\":\"" + u("~/View/Inventario/Bodegas/BodegaMapa3D.aspx") + "\",\"img\":\"" + u("~/Imagen/") + "\"}";
        }

        public static void Olvidar()
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx != null && ctx.Session != null) ctx.Session.Remove("SG_PLANFUN_" + Session.ClienteId());
        }
    }
}
