using API.MVC.Model;
using System;
using System.Collections.Generic;

namespace API.Utils
{
    /// <summary>
    /// Los permisos del que llama, resueltos una vez y compartidos.
    ///
    /// POR QUE NACE ESTA CLASE
    ///   Hasta el bloque 58 la API no validaba NINGUN permiso. Cada
    ///   endpoint llamaba a ExigirUsuario() —"el token es valido"— y de ahi
    ///   pasaba directo al SP. Eso significa que el token de un tecnico
    ///   servia para llamar cualquier endpoint publicado, incluido el que
    ///   da de alta clientes.
    ///
    ///   La web nunca tuvo ese agujero porque Token.Puede() se consulta
    ///   antes de cada accion. Esto es el equivalente del lado de la API, y
    ///   usa exactamente la misma fuente: SEL_USUARIO_PERMISOS, que ya
    ///   resuelve perfil + concesion + revocacion + vigencia + planta.
    ///
    /// LA CACHE DURA UN MINUTO, NO MAS
    ///   Son permisos. Uno revocado tiene que dejar de valer pronto, y
    ///   "pronto" no puede depender de que la persona cierre sesion. Un
    ///   minuto es suficiente para que una pantalla que pinta y despues
    ///   escribe no pegue dos veces a la base, y poco para que una
    ///   revocacion quede colgada.
    /// </summary>
    public static class Permisos
    {
        /// <summary>
        /// Los codigos vigentes del usuario del token, dentro del cliente
        /// del token. Nunca recibe el usuario por parametro: ver SesionApi.
        /// </summary>
        public static List<string> Mios()
        {
            int usuario = SesionApi.UsuarioId();
            int cliente = SesionApi.ClienteId();

            if (usuario <= 0) return new List<string>();

            string clave = CacheCorta.Clave("permisos", usuario, cliente);

            List<PermisoDto> filas = CacheCorta.Obtener(clave, () =>
                Datos.Listar<PermisoDto>("SEL_USUARIO_PERMISOS",
                    new Dictionary<string, object>
                    {
                        { "@USUARIO", usuario },
                        { "@CLIENTE", cliente > 0 ? (object)cliente : null },
                        { "@INSTALACION", null }
                    }));

            List<string> codigos = new List<string>();

            if (filas != null)
            {
                foreach (PermisoDto d in filas)
                {
                    if (!string.IsNullOrEmpty(d.prm_codigo))
                        codigos.Add(d.prm_codigo.Trim().ToUpperInvariant());
                }
            }

            return codigos;
        }

        /// <summary>
        /// True si el usuario del token tiene ese codigo.
        ///
        /// Sin usuario devuelve false, no true: un token de servicio no es
        /// un token con todos los permisos.
        /// </summary>
        public static bool Tiene(string codigo)
        {
            if (string.IsNullOrEmpty(codigo)) return false;

            string buscar = codigo.Trim().ToUpperInvariant();

            foreach (string c in Mios())
            {
                if (c == buscar) return true;
            }

            return false;
        }
    }


    /// <summary>
    /// Se lanza cuando el usuario esta identificado pero no puede hacer lo
    /// que pidio. Es 403, no 401: el token esta bien, quien lo trae no.
    ///
    /// Va aparte de ArgumentException porque ApiBase.Ejecutar traduce esa a
    /// 400, y un permiso faltante que responde 400 le dice a la app "lo que
    /// mandaste esta mal" cuando el problema es otro.
    /// </summary>
    public class PermisoDenegadoException : Exception
    {
        public PermisoDenegadoException(string mensaje) : base(mensaje) { }
    }
}
