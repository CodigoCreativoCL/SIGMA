using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using SitioBase.Model;

namespace SitioBase
{
    
    public class Token
    {
        private const string CACHE_PERMISOS = "_sigma_permisos";

        /// <summary>
        /// Las unicas cuatro paginas fuera del modelo de permisos, todas de
        /// infraestructura: el destino del propio rechazo, el login, la
        /// pantalla de espera y el aviso de privacidad publico. Cualquier
        /// pagina de negocio va en Menus, no aca.
        /// </summary>
        private static readonly HashSet<string> EXENTAS =
            new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "~/default.aspx",
                "~/login.aspx",
                "~/view/comun/procesamiento.aspx",
                "~/privacidad/privacidad.aspx"
            };

        private static Dictionary<int, string> _codigoPorId;
        private static Dictionary<string, string> _codigoPorPagina;
        private static Dictionary<string, Dictionary<string, string>> _funcionesPorPagina;
        private static readonly object _candado = new object();


        public static bool TokenSeguridad()
        {
            return !string.IsNullOrEmpty(Session.UsuarioId());
        }


        /* ================================================================
           PERMISOS DEL USUARIO
           ================================================================ */

        public static HashSet<string> Permisos()
        {
            HttpContext ctx = HttpContext.Current;

            if (ctx == null || ctx.Session == null)
                return new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            HashSet<string> permisos = ctx.Session[CACHE_PERMISOS] as HashSet<string>;
            if (permisos != null)
                return permisos;

            permisos = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            if (ctx.Session["usu_id"] != null)
            {
                int usuario;
                if (int.TryParse(ctx.Session["usu_id"].ToString(), out usuario))
                {
                    SqlCommand cmd = new SqlCommand();
                    cmd.CommandText = "SEL_USUARIO_PERMISOS";
                    cmd.Parameters.AddWithValue("@USUARIO", usuario);

                    // El cliente en contexto acota los permisos por perfil de
                    // cliente y las reglas puntuales. Mientras el selector de
                    // cliente no exista, va NULL y solo pesan los globales.
                    if (ctx.Session["cli_id"] != null)
                        cmd.Parameters.AddWithValue("@CLIENTE", ctx.Session["cli_id"]);

                    if (ctx.Session["cin_id"] != null)
                        cmd.Parameters.AddWithValue("@INSTALACION", ctx.Session["cin_id"]);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                            permisos.Add(dr["prm_codigo"].ToString());
                    }
                }
            }

            ctx.Session[CACHE_PERMISOS] = permisos;
            return permisos;
        }

        public static bool Puede(string codigo)
        {
            if (string.IsNullOrEmpty(codigo)) return false;
            if (!TokenSeguridad()) return false;

            return Permisos().Contains(codigo);
        }

        /// <summary>Vuelve a leer los permisos del usuario en la proxima consulta.</summary>
        public static void Refrescar()
        {
            if (HttpContext.Current != null && HttpContext.Current.Session != null)
                HttpContext.Current.Session.Remove(CACHE_PERMISOS);
        }


        /* ================================================================
           MAPA DE URLS
           ================================================================ */

        private static void CargarMapa()
        {
            lock (_candado)
            {
                if (_codigoPorPagina != null) return;

                Dictionary<int, string> porId = new Dictionary<int, string>();
                Dictionary<string, string> porPagina =
                    new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                Dictionary<string, Dictionary<string, string>> funciones =
                    new Dictionary<string, Dictionary<string, string>>(StringComparer.OrdinalIgnoreCase);

                SqlCommand cmd = new SqlCommand();
                cmd.CommandText = "SEL_MENUS_PERMISOS_MAPA";

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        string link = dr["mnu_link"].ToString();
                        string codigo = dr["prm_codigo"].ToString();
                        porPagina[link] = codigo;
                        porId[Convert.ToInt32(dr["mnu_id"])] = codigo;
                    }

                    if (dr.NextResult())
                    {
                        while (dr.Read())
                        {
                            string link = dr["mnu_link"].ToString();

                            if (!funciones.ContainsKey(link))
                                funciones[link] = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

                            funciones[link][dr["mfu_nombre"].ToString()] = dr["prm_codigo"].ToString();
                        }
                    }
                }

                _codigoPorId = porId;
                _funcionesPorPagina = funciones;
                _codigoPorPagina = porPagina;   // al final: marca el mapa como cargado
            }
        }

        /// <summary>El mantenedor de menus llama aca despues de guardar.</summary>
        public static void RefrescarMapa()
        {
            lock (_candado)
            {
                _codigoPorId = null;
                _codigoPorPagina = null;
                _funcionesPorPagina = null;
            }
        }

        /// <summary>La pagina que se esta sirviendo, tal como se guarda en mnu_link.</summary>
        public static string PaginaActual()
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx == null || ctx.Request == null) return "";

            return ctx.Request.AppRelativeCurrentExecutionFilePath;
        }


        /* ================================================================
           LO QUE USAN EL MASTER Y LOS CONTROLES
           ================================================================ */

        /// <summary>
        /// Chequea la pagina actual contra su permiso. Lo llama Default.master,
        /// asi que ninguna pagina tiene que hacer nada.
        /// </summary>
        public static void ExigirPagina()
        {
            if (!TokenSeguridad()) return;

            string pagina = PaginaActual();
            if (EXENTAS.Contains(pagina)) return;

            if (!PuedePagina(pagina))
                HttpContext.Current.Response.Redirect("~/Default.aspx");
        }

        /// <summary>True si el usuario puede abrir esa pagina. Sin fila en Menus, no.</summary>
        public static bool PuedePagina(string pagina)
        {
            if (string.IsNullOrEmpty(pagina)) return false;
            if (EXENTAS.Contains(pagina)) return true;

            CargarMapa();

            string codigo;
            if (!_codigoPorPagina.TryGetValue(pagina, out codigo))
                return false;

            return Puede(codigo);
        }

        /// <summary>
        /// True si el usuario puede usar esa funcion EN LA PAGINA ACTUAL.
        /// El nombre es el de Menu_Funcion.mfu_nombre: "Ver todo",
        /// "Ver todo paises", "Crear y editar".
        /// </summary>
        public static bool PuedeFuncion(string nombreFuncion)
        {
            if (string.IsNullOrEmpty(nombreFuncion)) return false;

            CargarMapa();

            Dictionary<string, string> deLaPagina;
            if (!_funcionesPorPagina.TryGetValue(PaginaActual(), out deLaPagina))
                return false;

            string codigo;
            if (!deLaPagina.TryGetValue(nombreFuncion, out codigo))
                return false;

            return Puede(codigo);
        }

        /// <summary>
        /// True si el usuario puede ver ese menu. Un nodo sin permiso es un
        /// contenedor: se resuelve por sus hijos, asi que devuelve true.
        /// </summary>
        public static bool PuedeMenu(int idMenu)
        {
            CargarMapa();

            string codigo;
            if (!_codigoPorId.TryGetValue(idMenu, out codigo))
                return true;

            return Puede(codigo);
        }


        /* ================================================================
           COMPATIBILIDAD
           ================================================================ */

        public static bool SecurityManagerPermisoMenu(MenuPerfil menuPerfil)
        {
            if (menuPerfil == null) return false;
            return PuedeMenu(menuPerfil.mpe_menu);
        }
    }
}
