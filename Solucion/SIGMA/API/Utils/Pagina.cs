using System;
using System.Collections.Generic;

namespace API.Utils
{
    /// <summary>
    /// Los parámetros de paginación que acepta todo listado de la API.
    ///
    /// POR QUE HAY UN TOPE Y NO SE PUEDE PEDIR "TODO"
    ///   El consumidor principal de esta API es la app móvil, muchas veces
    ///   sobre la red de una planta. Un listado sin tope funciona perfecto
    ///   en desarrollo con diez filas y deja el teléfono colgado el día que
    ///   el cliente tiene cuarenta mil activos. El tope se aplica acá, no
    ///   se confía en que quien llama pida una cantidad razonable.
    /// </summary>
    public class Pagina
    {
        public const int TAMANO_DEFECTO = 50;
        public const int TAMANO_MAXIMO = 200;

        private int _pagina = 1;
        private int _tamano = TAMANO_DEFECTO;

        /// <summary>Base 1: la primera página es la 1, no la 0.</summary>
        public int pagina
        {
            get { return _pagina; }
            set { _pagina = (value < 1) ? 1 : value; }
        }

        public int tamano
        {
            get { return _tamano; }
            set
            {
                if (value < 1) _tamano = TAMANO_DEFECTO;
                else if (value > TAMANO_MAXIMO) _tamano = TAMANO_MAXIMO;
                else _tamano = value;
            }
        }

        /// <summary>Texto de búsqueda libre. Lo interpreta cada SP con su @FILTRO.</summary>
        public string filtro { get; set; }

        public int Saltar()
        {
            return (_pagina - 1) * _tamano;
        }
    }


    /// <summary>
    /// Una página de resultados.
    ///
    /// Devuelve el total junto con los datos para que quien llama pueda
    /// pintar "página 2 de 7" sin una segunda petición de conteo.
    ///
    /// POR QUE SE PAGINA EN MEMORIA Y NO EN EL SP
    ///   Los SEL_ del proyecto no reciben OFFSET/FETCH: son los mismos que
    ///   consume la web y cambiarles la firma obligaría a tocar los
    ///   controllers de Intranet, que ya están probados. Se trae el
    ///   conjunto y se recorta acá.
    ///
    ///   Es una decisión con fecha de vencimiento y hay que decirlo: con
    ///   los volúmenes del Sprint 1 —decenas de plantas, cientos de
    ///   usuarios— es correcto y barato. Cuando entren activos y órdenes de
    ///   trabajo, esos SEL_ necesitan paginar en SQL. Anotado en el MD.
    /// </summary>
    public class Paginado<T>
    {
        public int pagina { get; set; }
        public int tamano { get; set; }
        public int total { get; set; }
        public int paginas { get; set; }
        public List<T> datos { get; set; }

        public static Paginado<T> Armar(List<T> todo, Pagina p)
        {
            Paginado<T> r = new Paginado<T>();

            if (todo == null) todo = new List<T>();

            r.pagina = p.pagina;
            r.tamano = p.tamano;
            r.total = todo.Count;
            r.paginas = (r.total + p.tamano - 1) / p.tamano;

            int desde = p.Saltar();

            // Pedir la página 40 de un listado de 3 no es un error: es una
            // página vacía. Devolver 404 obligaría a quien pagina a tratar
            // el final de la lista como una falla.
            if (desde >= r.total)
            {
                r.datos = new List<T>();
                return r;
            }

            int cuantos = Math.Min(p.tamano, r.total - desde);
            r.datos = todo.GetRange(desde, cuantos);

            return r;
        }
    }
}
