using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// El árbol de navegación de la app (HU-006).
    ///
    /// LA APP NO CABLEA SU MENU
    ///   En la web, una pantalla sin fila en Menus no se abre: la seguridad
    ///   de SIGMA es por datos, no por código. Si la app trajera sus
    ///   opciones escritas en Dart, habría dos modelos de permisos que
    ///   mantener y el día que se revoque uno la web lo escondería y el
    ///   teléfono no.
    ///
    ///   Por eso la navegación se pide acá. Un permiso revocado desaparece
    ///   del menú en la siguiente llamada, sin publicar versión en la
    ///   tienda y sin que nadie cierre sesión.
    ///
    /// ESTO NO ES LO QUE AUTORIZA
    ///   Es la mitad "en la interfaz" de la historia. La otra mitad son los
    ///   ExigirPermiso de cada endpoint: esconder una opción no impide
    ///   llamar al endpoint que había detrás.
    ///
    /// POR QUE HOY DEVUELVE DOS OPCIONES
    ///   Porque hoy la app tiene dos pantallas. Las de órdenes, repuestos,
    ///   checklists y permisos de trabajo son filas nuevas en Menus, y
    ///   nacen en el sprint donde se construye la pantalla. Sembrarlas
    ///   antes daría un menú que navega a la nada.
    /// </summary>
    [RoutePrefix("menus")]
    public class MenusController : ApiBase
    {
        /// <summary>
        /// GET /menus — el árbol de la app para quien llama.   HU-006
        ///
        /// No recibe ?usuario= ni ?cliente=: los dos salen del token. Un
        /// endpoint que devuelve el menú de quien se le pida es un mapa de
        /// la seguridad del sistema servido a cualquiera con una sesión.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Arbol()
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();

                int usuario = SesionApi.UsuarioId();
                int cliente = SesionApi.ClienteId();

                /* Misma caché corta que los permisos, y por la misma razón:
                   el árbol se resuelve CON los permisos, así que cachearlo
                   más tiempo que ellos dejaría una opción visible después de
                   revocada. */
                string clave = CacheCorta.Clave("menu-app", usuario, cliente);

                List<MenuAppFila> filas = CacheCorta.Obtener(clave, () =>
                    Datos.Listar<MenuAppFila>("SEL_MENU_APP",
                        new Dictionary<string, object>
                        {
                            { "@USUARIO", usuario },
                            { "@CLIENTE", cliente > 0 ? (object)cliente : null }
                        }));

                return Ok(Armar(filas));
            });
        }


        /// <summary>
        /// Convierte la lista plana del SP en el árbol que consume Flutter.
        ///
        /// El SP ya devolvió solo lo visible y ya subió los grupos que
        /// tienen hijos, así que acá no se decide nada de seguridad: se
        /// anida. Cualquier filtro adicional en este método sería una
        /// segunda regla de visibilidad conviviendo con la del SP.
        /// </summary>
        private static List<MenuAppNodo> Armar(List<MenuAppFila> filas)
        {
            List<MenuAppNodo> raiz = new List<MenuAppNodo>();

            if (filas == null || filas.Count == 0) return raiz;

            Dictionary<int, MenuAppNodo> porId = new Dictionary<int, MenuAppNodo>();

            foreach (MenuAppFila f in filas)
            {
                MenuAppNodo n = new MenuAppNodo
                {
                    id = f.mnu_id,
                    nombre = f.mnu_nombre,
                    descripcion = f.mnu_descripcion,
                    orden = f.mnu_orden,
                    // "#" es como el modelo heredado marca un grupo. Fuera
                    // del servidor eso no significa nada: viaja como null.
                    ruta = (f.mnu_link == "#") ? null : f.mnu_link,
                    icono = f.mnu_icon,
                    hijos = new List<MenuAppNodo>()
                };

                porId[f.mnu_id] = n;
            }

            foreach (MenuAppFila f in filas)
            {
                MenuAppNodo n = porId[f.mnu_id];
                int padre = f.mnu_padre.HasValue ? f.mnu_padre.Value : 0;

                /* Si el padre no vino en el resultado, el nodo se cuelga de
                   la raíz en vez de desaparecer. Perder una opción por una
                   fila mal encadenada es peor que mostrarla un nivel más
                   arriba, y además se nota, que es lo que hace que se
                   arregle. */
                if (padre > 0 && porId.ContainsKey(padre))
                    porId[padre].hijos.Add(n);
                else
                    raiz.Add(n);
            }

            return raiz;
        }
    }
}
