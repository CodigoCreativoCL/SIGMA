using System;

namespace SitioBase
{
    /// <summary>
    /// Base de las pantallas del módulo Soporte (View/Soporte/*).
    ///
    /// Todas se dibujan en el navegador con Js/sigma-soporte.js, que el master
    /// ya carga en cada página: la .aspx solo deja el contenedor con la vista
    /// y, si viene, el registro. El permiso de la pantalla lo exige el master
    /// contra Menus, como en todo el sitio.
    ///
    /// EL ID LLEGA DE DOS MANERAS
    ///   ?id=123 desde la propia pantalla, o ?query=… cifrado («Id=123») desde
    ///   la campana de notificaciones, que arma así todas sus fichas.
    /// </summary>
    public class SoportePagina : System.Web.UI.Page
    {
        public int RegistroId
        {
            get
            {
                int id;
                if (int.TryParse(Request.QueryString["id"], out id) && id > 0) return id;
                try { return Querystring.Entero(Request.QueryString["query"], "Id"); }
                catch (Exception) { return 0; }
            }
        }
    }
}
