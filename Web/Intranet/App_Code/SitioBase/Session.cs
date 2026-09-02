using System.Web;
using System.Web.SessionState;

namespace SitioBase
{
    public class Session
    {
        private static HttpSessionState Session1
        {
            get { return HttpContext.Current.Session; }
        }

        public static string UsuarioId()
        {
            if (Session1 != null && Session1["usu_id"] != null)
            {
                return HttpContext.Current.Session["usu_id"].ToString();
            }
            else
            {
                HttpContext.Current.Response.Redirect("~/Login.aspx");
                return "";
            }
        }

        public static string UsuarioLogin()
        {
            if (Session1 != null && Session1["usu_login"] != null)
            {
                return HttpContext.Current.Session["usu_login"].ToString();
            }
            else
            {
                return "";
            }
        }

        public static string UsuarioNombre()
        {
            if (Session1 != null && Session1["usu_Nombre"] != null)
            {
                return HttpContext.Current.Session["usu_Nombre"].ToString();
            }
            else
            {
                return "";
            }
        }

        public static string UsuarioApellidoPaterno()
        {
            if (Session1 != null && Session1["usu_apellido_paterno"] != null)
            {
                return HttpContext.Current.Session["usu_apellido_paterno"].ToString();
            }
            else
            {
                return "";
            }
        }

        public static string UsuarioApellidoMaterno()
        {
            if (Session1 != null && Session1["usu_apellido_materno"] != null)
            {
                return HttpContext.Current.Session["usu_apellido_materno"].ToString();
            }
            else
            {
                return "";
            }
        }

        public static string UsuarioNombreCompleto()
        {
            if (Session1 != null && Session1["usu_Nombre"] != null && Session1["usu_apellido_paterno"] != null && Session1["usu_apellido_materno"] != null)
            {
                return HttpContext.Current.Session["usu_Nombre"].ToString() + " " + HttpContext.Current.Session["usu_apellido_paterno"].ToString() + " " + HttpContext.Current.Session["usu_apellido_materno"].ToString();
            }
            else
            {
                return "";
            }
        }

        public static string UsuarioPerfil()
        {
            if (Session1 != null && Session1["usu_perfil"] != null)
            {
                return HttpContext.Current.Session["usu_perfil"].ToString();
            }
            else
            {
                HttpContext.Current.Response.Redirect("~/Login.aspx");
                return "";
            }
        }

        public static string UsuarioIdPaises()
        {
            if (Session1 != null && Session1["usu_id_paises"] != null)
            {
                return HttpContext.Current.Session["usu_id_paises"].ToString();
            }
            else
            {
                HttpContext.Current.Response.Redirect("~/Login.aspx");
                return "";
            }
        }

        public static string RemoteHost()
        {
            if (HttpContext.Current != null)
            {
                return HttpContext.Current.Request.UserHostAddress;
            }
            else
            {
                return "";
            }
        }

        public static string UsuarioCorreo()
        {
            if (Session1 != null && Session1["usu_correo"] != null)
            {
                return HttpContext.Current.Session["usu_correo"].ToString();
            }
            else
            {
                return "";
            }
        }

        public static string UsuarioPassword()
        {
            if (Session1 != null && Session1["usu_password"] != null)
            {
                return HttpContext.Current.Session["usu_password"].ToString();
            }
            else
            {
                return "";
            }
        }

        public static string UsuarioFono()
        {
            if (Session1 != null && Session1["usu_fono"] != null)
            {
                return HttpContext.Current.Session["usu_fono"].ToString();
            }
            else
            {
                return "";
            }
        }


        public static string UsuarioCambioPassword()
        {
            if (Session1 != null && Session1["usu_cambio_password"] != null)
            {
                return HttpContext.Current.Session["usu_cambio_password"].ToString();
            }
            else
            {
                return "false";
            }
        }

        /// <summary>
        /// El id del Archivo con la foto del usuario, o 0.
        ///
        /// Lo pone el login. Es un id y no la imagen: la cabecera arma con el
        /// una URL que el navegador cachea.
        /// </summary>
        public static int UsuarioArchivoFoto()
        {
            if (Session1 == null || HttpContext.Current.Session["usu_archivo_foto"] == null) return 0;

            int id;
            return int.TryParse(HttpContext.Current.Session["usu_archivo_foto"].ToString(), out id) ? id : 0;
        }

        public static string UsuarioFoto()
        {
            if (Session1 != null && Session1["usu_foto"] != null)
            {
                return HttpContext.Current.Session["usu_foto"].ToString();
            }
            else
            {
                return null;
            }
        }

        public static string UsuarioTipoPerfil()
        {
            if (Session1 != null && Session1["per_tipo"] != null)
            {
                return HttpContext.Current.Session["per_tipo"].ToString();
            }
            else
            {
                return null;
            }
        }
        public static string UsuarioPerfiles()
        {
            if (Session1 != null && Session1["perfiles"] != null)
            {
                return HttpContext.Current.Session["perfiles"].ToString();
            }
            else
            {
                return null;
            }
        }

        #region Cliente en sesion (HU-002)

        /// <summary>
        /// Cliente con el que la persona esta trabajando ahora.
        ///
        /// SIGMA es multicliente y casi todo lo que se consulta -plantas,
        /// areas, centros de costo, grupos, especialidades- se filtra por
        /// aqui. Devuelve 0 cuando todavia no se ha elegido uno, que es el
        /// caso de quien pertenece a varios y aun no paso por el selector,
        /// y tambien el del administrador de plataforma, que no pertenece a
        /// ninguno.
        /// </summary>
        public static int ClienteId()
        {
            if (Session1 != null && Session1["cli_id"] != null)
            {
                int id;
                if (int.TryParse(HttpContext.Current.Session["cli_id"].ToString(), out id))
                    return id;
            }

            return 0;
        }

        public static string ClienteNombre()
        {
            if (Session1 != null && Session1["cli_nombre"] != null)
            {
                return HttpContext.Current.Session["cli_nombre"].ToString();
            }
            else
            {
                return "";
            }
        }

        /// <summary>
        /// Fija el cliente de trabajo.
        ///
        /// Limpia ademas los permisos cacheados: son distintos en cada
        /// cliente -la misma persona puede ser supervisora en uno y tecnico
        /// en otro- y si no se botaran, al cambiar de cliente seguiria
        /// viendo los menus del anterior. Es el "ningun dato del cliente
        /// anterior permanece en pantalla" del escenario 3 de HU-002.
        /// </summary>
        public static void SetCliente(int idCliente, string nombreCliente)
        {
            if (Session1 == null) return;

            HttpContext.Current.Session["cli_id"] = idCliente;
            HttpContext.Current.Session["cli_nombre"] = nombreCliente;

            Token.Refrescar();

            // El estado de suscripción cacheado es del cliente anterior:
            // conservarlo dejaría entrar a uno vencido con la vigencia del
            // otro, o bloquearía a uno al día.
            SuscripcionAcceso.Refrescar();
        }

        #endregion

    }
}
