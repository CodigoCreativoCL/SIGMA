using System;
using System.Threading.Tasks;
using System.Web;

namespace SitioBase
{
    /// <summary>
    /// Consultas en paralelo dentro de una misma petición.
    ///
    /// POR QUÉ
    ///
    ///   La base está en un hosting remoto: cada consulta es una ida y vuelta
    ///   de ~250 ms, aunque traiga tres filas. Una pantalla que pide diez cosas
    ///   independientes en fila tarda 2,5 s solo en esperar. Pedidas a la vez
    ///   tardan lo que la más lenta.
    ///
    /// EL HTTPCONTEXT VIAJA CON CADA HILO
    ///
    ///   Los controllers leen la sesión (cliente, usuario) por
    ///   HttpContext.Current, que en un hilo nuevo es null. Cada tarea recibe
    ///   el de la petición y lo suelta al terminar.
    ///
    /// LO QUE NO SE HACE EN PARALELO
    ///
    ///   Escribir en Session o en HttpContext.Items: no son seguros entre
    ///   hilos. Por eso los permisos (Token.Permisos, que se guardan en Items)
    ///   se leen en el hilo de la página. Las tareas solo leen.
    ///
    /// Lo estrenó la ficha de componente (05-10-2026, de ~3,9 s a ~1,3 s).
    /// </summary>
    public static class Paralelo
    {
        /// <summary>Lanza f en otro hilo con el HttpContext de la petición actual.</summary>
        public static Task<T> Pedir<T>(Func<T> f)
        {
            HttpContext ctx = HttpContext.Current;

            return Task.Run(() =>
            {
                HttpContext.Current = ctx;
                try { return f(); }
                finally { HttpContext.Current = null; }
            });
        }

        /// <summary>
        /// Igual, pero si la consulta falla devuelve `siFalla` en vez de
        /// romper la pantalla entera: para lo que es un adorno (una foto, un
        /// conteo de una pestaña).
        /// </summary>
        public static Task<T> Pedir<T>(Func<T> f, T siFalla)
        {
            return Pedir(() => { try { return f(); } catch (Exception) { return siFalla; } });
        }
    }
}
