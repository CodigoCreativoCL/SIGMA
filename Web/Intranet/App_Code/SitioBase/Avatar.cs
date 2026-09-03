using System;
using System.Text;
using System.Web;

namespace SitioBase
{
    /// <summary>
    /// Cómo se dibuja una persona en SIGMA.
    ///
    /// POR QUÉ ESTO EXISTE
    ///
    ///   Los avatares nacieron dentro de `Programaciones.aspx.cs` como métodos
    ///   privados. Funcionaban bien, pero cada pantalla nueva que mostrara
    ///   usuarios —permisos, movimientos, existencias, grupos— tenía que
    ///   copiarlos. Copiar significa que la paleta se desincroniza, que en una
    ///   pantalla el mismo usuario sale azul y en otra verde, y que quien mira
    ///   deja de poder reconocer a alguien por su color.
    ///
    ///   Acá el color de una persona es el mismo en todo el producto porque
    ///   sale del mismo lugar.
    ///
    /// LA FOTO SI LA HAY, LAS INICIALES SI NO
    ///
    ///   No hay un tercer caso. Un cuadrado gris con una silueta genérica no
    ///   distingue a nadie: en una pila de tres, tres siluetas iguales dan
    ///   menos información que tres pares de iniciales de colores distintos.
    /// </summary>
    public static class Avatar
    {
        /* Doce tonos, todos legibles con texto blanco encima. El orden no es
           casual: los vecinos en la lista son bien distintos entre sí, porque
           los ids consecutivos —que es como suelen venir los integrantes de un
           mismo grupo— toman colores consecutivos. */
        private static readonly string[] PALETA = {
            "#6C5CFF", "#0EA5E9", "#10B981", "#F59E0B",
            "#EF4444", "#8B5CF6", "#EC4899", "#14B8A6",
            "#F97316", "#3B82F6", "#84CC16", "#A855F7"
        };

        /// <summary>
        /// El color sale del ID, nunca del nombre.
        ///
        /// Sumar los códigos de las letras es un hash malo: con los siete
        /// usuarios reales del cliente daba solo cuatro colores, o sea tres
        /// pares de personas indistinguibles. El id es único por construcción.
        /// </summary>
        public static string Color(int id)
        {
            if (id < 0) return "#9ca3af";
            return PALETA[id % PALETA.Length];
        }

        /// <summary>
        /// Dos letras: la del nombre y la del primer apellido.
        /// </summary>
        public static string Iniciales(string nombre)
        {
            string[] partes = (nombre ?? "").Trim()
                              .Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);

            if (partes.Length == 0) return "?";
            if (partes.Length == 1) return partes[0].Substring(0, 1).ToUpper();

            return (partes[0].Substring(0, 1) + partes[1].Substring(0, 1)).ToUpper();
        }

        private static string H(string valor)
        {
            return HttpUtility.HtmlEncode(valor ?? "");
        }

        /// <summary>
        /// Una sola persona: su foto, o sus iniciales sobre su color.
        /// </summary>
        /// <param name="id">Id del usuario. Decide el color.</param>
        /// <param name="nombre">Nombre completo. Decide las iniciales y el tooltip.</param>
        /// <param name="archivoFoto">Id del archivo con la foto; 0 o menos si no tiene.</param>
        public static string Persona(int id, string nombre, int archivoFoto)
        {
            string titulo = H(nombre);

            if (archivoFoto > 0)
            {
                /* La foto va como <img> y no como fondo: así el navegador la
                   cachea entre pantallas, y el HTML de una grilla con veinte
                   filas no carga con veinte imágenes embebidas. */
                return "<span class=\"sg-avatar is-foto\" title=\"" + titulo + "\">" +
                       "<img src=\"" + H(UrlArchivo.Ver(archivoFoto)) + "\" alt=\"" + titulo + "\" />" +
                       "</span>";
            }

            return "<span class=\"sg-avatar\" style=\"background-color:" + Color(id) +
                   ";\" title=\"" + titulo + "\">" + H(Iniciales(nombre)) + "</span>";
        }

        /// <summary>Persona sin foto conocida.</summary>
        public static string Persona(int id, string nombre)
        {
            return Persona(id, nombre, 0);
        }

        /// <summary>
        /// Una cuadrilla. Lleva icono en vez de iniciales: un grupo no es
        /// alguien, y darle iniciales lo haría pasar por una persona más.
        /// </summary>
        public static string Grupo(string nombre)
        {
            return "<span class=\"sg-avatar is-grupo\" title=\"" + H(nombre) + "\">" +
                   "<i class=\"mdi mdi-account-group\"></i></span>";
        }

        /// <summary>
        /// Varias personas superpuestas, y el resto como "+N".
        ///
        /// El tope existe porque una pila de ocho caras es más ancha que
        /// cualquier columna de una grilla. Las que no entran no se pierden:
        /// el "+N" lleva la lista completa en su tooltip.
        /// </summary>
        /// <param name="nombres">Nombres separados por ", ".</param>
        /// <param name="ids">Ids separados por ",", en el MISMO orden que los nombres.</param>
        /// <param name="tope">Cuántas caras se dibujan antes del "+N".</param>
        public static string Pila(string nombres, string ids, int tope)
        {
            if (string.IsNullOrEmpty(nombres)) return "";

            string[] lista = nombres.Split(new string[] { ", " }, StringSplitOptions.None);
            string[] claves = (ids ?? "").Split(',');

            if (tope < 1) tope = 1;

            int caras = lista.Length > tope ? tope : lista.Length;

            StringBuilder b = new StringBuilder();
            b.Append("<span class=\"sg-avatares\">");

            for (int k = 0; k < caras; k++)
            {
                int id;

                /* Nombres e ids llegan ordenados igual desde el SP, así que la
                   posición empareja. Si un id no se puede leer, la cara sale
                   gris en vez de reventar la página entera. */
                if (k >= claves.Length || !int.TryParse(claves[k].Trim(), out id)) id = -1;

                b.Append(Persona(id, lista[k]));
            }

            if (lista.Length > caras)
                b.Append("<span class=\"sg-avatar is-mas\" title=\"" + H(nombres) + "\">+" +
                         (lista.Length - caras) + "</span>");

            b.Append("</span>");

            return b.ToString();
        }

        /// <summary>
        /// El bloque completo de una celda de grilla: las caras arriba y los
        /// nombres debajo.
        ///
        /// SOLO CARAS NO ALCANZA
        ///   Obligaba a pasar el mouse por cada fila para saber de quién se
        ///   trataba. Van los dos: la cara, que se reconoce de un golpe, y el
        ///   nombre, que se lee.
        /// </summary>
        /// <param name="pie">Línea chica de abajo: el perfil, el rol, la fecha.</param>
        public static string Celda(string nombres, string ids, string pie, int tope)
        {
            if (string.IsNullOrEmpty(nombres)) return SinAsignar();

            string[] lista = nombres.Split(new string[] { ", " }, StringSplitOptions.None);

            /* Un nombre completo si es uno; el primero y cuántos más si son
               varios. Tres nombres completos en una columna angosta se cortan
               a la mitad de una palabra, que es peor que no ponerlos. */
            string texto = lista.Length == 1
                ? lista[0]
                : lista[0] + " y " + (lista.Length - 1) + " más";

            StringBuilder b = new StringBuilder();

            b.Append("<span class=\"sg-resp\">");
            b.Append(Pila(nombres, ids, tope));
            b.Append("<span class=\"sg-resp-txt\">");
            b.Append("<span class=\"sg-resp-nombres\" title=\"" + H(nombres) + "\">" +
                     H(texto) + "</span>");

            if (!string.IsNullOrEmpty(pie))
                b.Append("<span class=\"sg-resp-pie\">" + H(pie) + "</span>");

            b.Append("</span></span>");

            return b.ToString();
        }

        /// <summary>Una sola persona con su nombre al lado.</summary>
        public static string CeldaUno(int id, string nombre, int archivoFoto, string pie)
        {
            if (string.IsNullOrEmpty(nombre)) return SinAsignar();

            StringBuilder b = new StringBuilder();

            b.Append("<span class=\"sg-resp\">");
            b.Append("<span class=\"sg-avatares\">" + Persona(id, nombre, archivoFoto) + "</span>");
            b.Append("<span class=\"sg-resp-txt\">");
            b.Append("<span class=\"sg-resp-nombres\" title=\"" + H(nombre) + "\">" + H(nombre) + "</span>");

            if (!string.IsNullOrEmpty(pie))
                b.Append("<span class=\"sg-resp-pie\">" + H(pie) + "</span>");

            b.Append("</span></span>");

            return b.ToString();
        }

        /// <summary>
        /// La cuadrilla, con su nombre al lado.
        /// </summary>
        public static string CeldaGrupo(string nombre)
        {
            if (string.IsNullOrEmpty(nombre)) return SinAsignar();

            return "<span class=\"sg-resp\">" + Grupo(nombre) +
                   "<span class=\"sg-resp-txt\"><span class=\"sg-resp-nombres\">" + H(nombre) +
                   "</span><span class=\"sg-resp-pie\">Grupo de trabajo</span></span></span>";
        }

        /// <summary>
        /// Nadie a cargo.
        ///
        /// NO VA EN ROJO
        ///   Estuvo en rojo, y en una lista donde cuatro de cada cinco filas no
        ///   tienen responsable eso pinta la pantalla entera de alarma: deja de
        ///   ser una señal y pasa a ser ruido. Como pastilla tenue con su
        ///   icono se distingue igual, sin gritar.
        /// </summary>
        public static string SinAsignar()
        {
            return SinAsignar("Sin asignar");
        }

        /// <summary>
        /// La misma pastilla, con otro texto. Hay pantallas donde lo que falta
        /// es "responsable" y otras donde es "asignación": la palabra la pone
        /// quien conoce el contexto.
        /// </summary>
        public static string SinAsignar(string texto)
        {
            return "<span class=\"sg-sinasignar\">" +
                   "<i class=\"mdi mdi-account-off-outline\"></i>" + H(texto) + "</span>";
        }
    }
}
