using System;
using System.Text;

namespace SitioBase
{
    /// <summary>
    /// Codigo de barras Code 128 (juego B) de un token de etiqueta: REP-17,
    /// UBI-4, BOD-1. Lo leen todas las pistolas lineales y la camara del
    /// telefono, y el juego B cubre letras, numeros y el guion.
    ///
    /// Sin biblioteca: QRCoder solo hace QR, y Code 128 es una tabla de 107
    /// patrones y una suma de control. La MISMA tabla vive en
    /// Js/sigma-bodega3d.js (el mapa dibuja las barras en las cajas); si una
    /// cambia, cambia la otra.
    /// </summary>
    public static class Code128
    {
        /* Anchos barra-espacio de cada simbolo (0..105) y el stop (106). */
        private static readonly string[] Patrones =
        {
            "212222","222122","222221","121223","121322","131222","122213","122312","132212","221213",
            "221312","231212","112232","122132","122231","113222","123122","123221","223211","221132",
            "221231","213212","223112","312131","311222","321122","321221","312212","322112","322211",
            "212123","212321","232121","111323","131123","131321","112313","132113","132311","211313",
            "231113","231311","112133","112331","132131","113123","113321","133121","313121","211331",
            "231131","213113","213311","213131","311123","311321","331121","312113","312311","332111",
            "314111","221411","431111","111224","111422","121124","121421","141122","141221","112214",
            "112412","122114","122411","142112","142211","241211","221114","413111","241112","134111",
            "111242","121142","121241","114212","124112","124211","411212","421112","421211","212141",
            "214121","412121","111143","111341","131141","114113","114311","411113","411311","113141",
            "114131","311141","411131","211412","211214","211232","2331112"
        };

        private const int START_B = 104, STOP = 106;

        /// <summary>
        /// Los modulos de izquierda a derecha, '1' barra y '0' espacio, sin la
        /// zona de silencio (la pone quien dibuja: 10 modulos por lado).
        /// Vacio si el texto trae algo fuera del juego B.
        /// </summary>
        public static string Modulos(string contenido)
        {
            if (string.IsNullOrEmpty(contenido)) return "";
            StringBuilder sb = new StringBuilder();
            int suma = START_B;
            Agregar(sb, START_B);
            for (int i = 0; i < contenido.Length; i++)
            {
                int v = contenido[i] - 32;
                if (v < 0 || v > 95) return "";
                suma += v * (i + 1);
                Agregar(sb, v);
            }
            Agregar(sb, suma % 103);
            Agregar(sb, STOP);
            return sb.ToString();
        }

        private static void Agregar(StringBuilder sb, int simbolo)
        {
            string p = Patrones[simbolo];
            for (int k = 0; k < p.Length; k++) sb.Append(k % 2 == 0 ? '1' : '0', p[k] - '0');
        }

        /// <summary>
        /// El codigo como SVG en data URI: vectorial, asi que la impresora lo
        /// saca nitido a cualquier tamano de etiqueta. Cada modulo mide 1 de
        /// ancho en el viewBox; el alto lo decide el CSS.
        /// </summary>
        public static string SvgDataUri(string contenido)
        {
            string m = Modulos(contenido);
            if (m.Length == 0) return "";
            const int silencio = 10;
            int ancho = m.Length + 2 * silencio;
            StringBuilder s = new StringBuilder();
            s.Append("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 ").Append(ancho)
             .Append(" 40\" preserveAspectRatio=\"none\" shape-rendering=\"crispEdges\"><rect width=\"")
             .Append(ancho).Append("\" height=\"40\" fill=\"#fff\"/><path fill=\"#000\" d=\"");
            for (int i = 0; i < m.Length; )
            {
                if (m[i] == '0') { i++; continue; }
                int j = i;
                while (j < m.Length && m[j] == '1') j++;
                s.Append('M').Append(i + silencio).Append(" 0h").Append(j - i).Append("v40h-").Append(j - i).Append('z');
                i = j;
            }
            s.Append("\"/></svg>");
            return "data:image/svg+xml;base64," + Convert.ToBase64String(Encoding.UTF8.GetBytes(s.ToString()));
        }
    }
}
