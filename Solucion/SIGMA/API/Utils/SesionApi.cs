using System;
using System.Linq;
using System.Security.Claims;
using System.Threading;

namespace API.Utils
{
    /// <summary>
    /// Quién está llamando: el usuario y el cliente que vienen en el token.
    ///
    /// POR QUE NO SE ACEPTAN POR PARAMETRO
    ///   Sería más cómodo recibir ?usuario=7 y pasarlo al SP. También
    ///   permitiría que cualquiera con un token válido operara como
    ///   cualquier otro con cambiar un número en la URL, y que la
    ///   auditoría de cada tabla —usu_usuario_creacion y compañía—
    ///   registrara a quien el propio atacante dijera ser.
    ///
    ///   El usuario sale del token firmado y de ningún otro lado.
    ///
    /// EL CLIENTE EN CONTEXTO
    ///   SIGMA es multicliente y casi toda consulta se acota por cliente.
    ///   Viene en el token porque se elige al iniciar sesión (HU-002) y
    ///   cambiarlo exige emitir otro token: así no hay forma de pedir datos
    ///   de un cliente al que no se entró.
    /// </summary>
    public static class SesionApi
    {
        public static int UsuarioId()
        {
            return LeerEntero("sigma_usuario");
        }

        public static int ClienteId()
        {
            return LeerEntero("sigma_cliente");
        }

        public static string Login()
        {
            ClaimsPrincipal p = Thread.CurrentPrincipal as ClaimsPrincipal;
            if (p == null || p.Identity == null) return "";

            Claim c = p.FindFirst(ClaimTypes.Name);
            return (c != null) ? c.Value : "";
        }

        /// <summary>
        /// True si el token identifica a una persona y no a la cuenta de
        /// servicio. Los endpoints que escriben lo exigen: sin usuario no
        /// hay a quién auditar.
        /// </summary>
        public static bool HayUsuario()
        {
            return UsuarioId() > 0;
        }

        private static int LeerEntero(string claim)
        {
            ClaimsPrincipal p = Thread.CurrentPrincipal as ClaimsPrincipal;
            if (p == null) return 0;

            Claim c = p.FindFirst(claim);
            if (c == null) return 0;

            int valor;
            return int.TryParse(c.Value, out valor) ? valor : 0;
        }
    }
}
