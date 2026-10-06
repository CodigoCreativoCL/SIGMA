using System;
using System.Collections.Generic;
using System.Configuration;
using System.Security.Cryptography;
using System.Text;
using System.Web;

namespace SitioBase
{
    /// <summary>
    /// La sesión dura hasta que la persona la cierra.
    ///
    /// POR QUÉ SE CAÍA
    ///   La sesión vive en memoria del servidor: en local se pierde tras 30
    ///   minutos sin uso, y en el hosting (InProc) cada vez que la aplicación
    ///   se recicla, que en un plan compartido pasa seguido y sin aviso. La
    ///   persona seguía trabajando y el siguiente clic la mandaba al login.
    ///
    /// CÓMO SE ARREGLA
    ///   Al entrar y al elegir cliente se deja una cookie con el usuario y el
    ///   cliente, FIRMADA (HMAC-SHA256): no se puede fabricar ni editar. Cuando
    ///   el servidor arranca una sesión nueva (Global.Session_Start) y la
    ///   cookie es válida, se vuelve a armar la sesión como en el login.
    ///
    ///   No es "recordar la contraseña": la cookie deja de valer al cerrar
    ///   sesión, si la cuenta se deshabilita, si cambia la contraseña (lleva
    ///   una huella de ella) o si la persona deja de pertenecer al cliente.
    ///
    ///   Tools.Crypto.Encrypt NO sirve para esto: es solo Base64.
    /// </summary>
    public static class SesionPersistente
    {
        private const string COOKIE = "SIGMA_SESION";
        private const int DIAS = 30;    // se renueva en cada uso: caduca solo si no se entra en un mes

        public static void Emitir()
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx == null || ctx.Session == null || ctx.Session["usu_id"] == null) return;

            string usu = Convert.ToString(ctx.Session["usu_id"]);
            string cli = ctx.Session["cli_id"] == null ? "0" : Convert.ToString(ctx.Session["cli_id"]);
            string datos = usu + "|" + cli + "|" + DateTime.UtcNow.AddDays(DIAS).Ticks + "|" + Huella(Convert.ToString(ctx.Session["usu_password"]));

            HttpCookie c = new HttpCookie(COOKIE, datos + "|" + Firma(datos));
            c.HttpOnly = true;
            c.Secure = ctx.Request.IsSecureConnection;
            c.Expires = DateTime.UtcNow.AddDays(DIAS);
            c.Path = string.IsNullOrEmpty(ctx.Request.ApplicationPath) ? "/" : ctx.Request.ApplicationPath;
            ctx.Response.Cookies.Set(c);
        }

        public static void Borrar()
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx == null) return;
            HttpCookie c = new HttpCookie(COOKIE, "");
            c.Expires = DateTime.UtcNow.AddDays(-1);
            c.HttpOnly = true;
            c.Path = string.IsNullOrEmpty(ctx.Request.ApplicationPath) ? "/" : ctx.Request.ApplicationPath;
            ctx.Response.Cookies.Set(c);
        }

        /// <summary>Rearma la sesión desde la cookie. Lo llama Global.Session_Start.</summary>
        public static void Restaurar()
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx == null || ctx.Session == null || ctx.Session["usu_id"] != null) return;

            HttpCookie c = ctx.Request.Cookies[COOKIE];
            if (c == null || string.IsNullOrEmpty(c.Value)) return;

            try
            {
                string[] p = c.Value.Split('|');
                if (p.Length != 5) { Borrar(); return; }

                string datos = p[0] + "|" + p[1] + "|" + p[2] + "|" + p[3];
                if (!IgualSeguro(Firma(datos), p[4])) { Borrar(); return; }
                if (new DateTime(long.Parse(p[2]), DateTimeKind.Utc) < DateTime.UtcNow) { Borrar(); return; }

                int usuario = int.Parse(p[0]);
                int cliente = int.Parse(p[1]);

                var r = new Controller.UsuarioController().GetUsuarioSession(new Model.Usuario { usu_id = usuario });
                bool habilitado = !r.error && string.Equals(Convert.ToString(ctx.Session["usu_habilitado"]), "True", StringComparison.OrdinalIgnoreCase);

                if (!habilitado || Huella(Convert.ToString(ctx.Session["usu_password"])) != p[3])
                {
                    ctx.Session.Clear();
                    Borrar();
                    return;
                }

                if (cliente > 0)
                {
                    List<Dictionary<string, object>> f = Controller.SoporteDatos.Filas("SEL_SESION_RESTAURAR", "@USUARIO", usuario, "@CLIENTE", cliente);
                    if (f.Count > 0) Session.SetCliente(cliente, Convert.ToString(f[0]["cli_nombre"]));
                }

                Emitir();   // renueva el plazo
            }
            catch (Exception)
            {
                /* Una cookie que no se entiende no puede romper la entrada:
                   se descarta y la persona ve el login, como antes. */
                if (ctx.Session != null) ctx.Session.Clear();
                Borrar();
            }
        }

        private static string Clave()
        {
            string k = ConfigurationManager.AppSettings["SesionClave"];
            if (string.IsNullOrEmpty(k)) k = "SIGMA-SESION|" + ConfigurationManager.AppSettings["Crypto"];
            return k;
        }

        private static string Firma(string datos)
        {
            using (HMACSHA256 h = new HMACSHA256(Encoding.UTF8.GetBytes(Clave())))
                return Convert.ToBase64String(h.ComputeHash(Encoding.UTF8.GetBytes(datos))).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        }

        private static string Huella(string password)
        {
            using (SHA256 s = SHA256.Create())
            {
                byte[] b = s.ComputeHash(Encoding.UTF8.GetBytes("sigma|" + (password ?? "")));
                return BitConverter.ToString(b, 0, 8).Replace("-", "");
            }
        }

        private static bool IgualSeguro(string a, string b)
        {
            if (a == null || b == null || a.Length != b.Length) return false;
            int d = 0;
            for (int i = 0; i < a.Length; i++) d |= a[i] ^ b[i];
            return d == 0;
        }
    }
}
