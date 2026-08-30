using System;
using System.Web;
using System.Web.Caching;

namespace API.Utils
{
    /// <summary>
    /// Caché de vida corta para respuestas que no cambian entre peticiones
    /// seguidas.
    ///
    /// DONDE SE USA Y POR QUE
    ///   En dos listados que la app pide una y otra vez sin que su
    ///   contenido cambie:
    ///
    ///     GET /api/usuario-permisos   los permisos del usuario, que la app
    ///                                 consulta antes de pintar cada
    ///                                 pantalla.
    ///     GET /api/catalogos          los 81 catálogos del sistema, que
    ///                                 cambian cuando alguien agrega un
    ///                                 valor, o sea casi nunca.
    ///
    ///   Sin esto, abrir cinco pantallas seguidas son cinco viajes a la
    ///   base para recibir exactamente lo mismo, sobre la red de una planta.
    ///
    /// POR QUE 60 SEGUNDOS Y NO MAS
    ///   Porque lo que se cachea son PERMISOS. Un permiso revocado tiene
    ///   que dejar de valer pronto, y "pronto" no puede depender de que la
    ///   persona cierre sesión. Un minuto es suficiente para ahorrar la
    ///   ráfaga de peticiones de una navegación y lo bastante corto para
    ///   que una revocación no quede colgando.
    ///
    ///   Es la misma lección del sitio web: ahí los permisos estaban en
    ///   Session sin caducidad y quien perdía uno lo conservaba hasta
    ///   volver a entrar.
    ///
    /// LA CLAVE INCLUYE AL USUARIO Y AL CLIENTE
    ///   Siempre. Una caché de permisos con la clave mal armada le entrega
    ///   los permisos de una persona a otra, y ese es exactamente el tipo
    ///   de error que nadie nota hasta que alguien ve lo que no debía.
    /// </summary>
    public static class CacheCorta
    {
        public const int SEGUNDOS = 60;

        private const string PREFIJO = "_sigma_api_";

        /// <summary>
        /// Devuelve lo cacheado; si no está, ejecuta la consulta, la guarda
        /// y la devuelve.
        ///
        /// Nunca cachea null: un fallo momentáneo de la base que devuelva
        /// nulo quedaría fijado un minuto, convirtiendo un tropiezo en una
        /// caída sostenida.
        /// </summary>
        public static T Obtener<T>(string clave, Func<T> consulta, int segundos = SEGUNDOS) where T : class
        {
            HttpContext ctx = HttpContext.Current;

            // Sin contexto (pruebas, tareas de fondo) se consulta directo.
            if (ctx == null || ctx.Cache == null) return consulta();

            string llave = PREFIJO + clave;

            T guardado = ctx.Cache[llave] as T;
            if (guardado != null) return guardado;

            T fresco = consulta();

            if (fresco != null)
                ctx.Cache.Insert(llave, fresco, null,
                                 DateTime.UtcNow.AddSeconds(segundos),
                                 Cache.NoSlidingExpiration);

            return fresco;
        }

        /// <summary>
        /// Arma la clave. El usuario y el cliente van SIEMPRE: son los dos
        /// ejes que cambian la respuesta de cualquier consulta de esta API.
        /// </summary>
        public static string Clave(string recurso, int usuario, int cliente, string extra = null)
        {
            string clave = recurso + ":u" + usuario + ":c" + cliente;

            if (!string.IsNullOrEmpty(extra)) clave += ":" + extra;

            return clave;
        }

        /// <summary>
        /// Bota lo cacheado de un usuario. La llama quien cambia permisos,
        /// para no esperar el minuto.
        /// </summary>
        public static void Botar(string recurso, int usuario, int cliente, string extra = null)
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx == null || ctx.Cache == null) return;

            ctx.Cache.Remove(PREFIJO + Clave(recurso, usuario, cliente, extra));
        }
    }
}
