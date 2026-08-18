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

    }
}
