using System;
using System.Collections.Generic;
using System.Linq;

namespace SitioBase.Controller
{
    /// <summary>
    /// Imágenes de referencia (HU-143, BD/454): la foto de cómo debe quedar un trabajo,
    /// pegada a una actividad del plan o a un ítem de pauta.
    ///
    /// UN SOLO LUGAR PARA LAS TRES PANTALLAS
    ///   El Centro de Planificación (actividad), la Biblioteca (ítem de pauta) y
    ///   Operación (la inspección que se ejecuta) leen y escriben por aquí, así que
    ///   las tres validan igual y arman las URL igual. El permiso lo exige cada web
    ///   service antes de llamar (es distinto en cada pantalla); el cliente lo vuelve
    ///   a exigir el SP.
    ///
    /// EL ÍTEM VIAJA POR CÓDIGO
    ///   El cajón de la pauta conoce el código del ítem, no su id: el id cambia con
    ///   cada versión publicada. El SP resuelve el ítem en la versión que muestra el
    ///   cajón (el borrador si existe, si no la publicada).
    /// </summary>
    public static class ArchivoReferencias
    {
        private const int MAX_MB = 8;

        /// <summary>Las referencias que pide el filtro (pares nombre/valor del SP), con su URL para ver y bajar.</summary>
        public static List<Dictionary<string, object>> Listar(params object[] filtro)
        {
            List<object> p = new List<object> { "@CLIENTE", Session.ClienteId() };
            p.AddRange(filtro);
            List<Dictionary<string, object>> l = SoporteDatos.Filas("SEL_ARCHIVO_REFERENCIA", p.ToArray());
            foreach (Dictionary<string, object> r in l)
            {
                int arc = Convert.ToInt32(r["ARCHIVO"]);
                r["URL"] = UrlArchivo.Ver(arc);
                r["DESCARGA"] = UrlArchivo.Descargar(arc);
            }
            return l;
        }

        /// <summary>Por actividad del plan: lo que necesita la ficha del plan.</summary>
        public static ILookup<int, Dictionary<string, object>> PorActividad(IEnumerable<int> actividades)
        {
            string ids = Ids(actividades);
            List<Dictionary<string, object>> l = ids.Length == 0 ? new List<Dictionary<string, object>>() : Listar("@ACTIVIDADES", ids);
            return l.ToLookup(r => Convert.ToInt32(r["ACTIVIDAD"]));
        }

        /// <summary>Por ítem (id): lo que necesita la inspección que se ejecuta.</summary>
        public static ILookup<int, Dictionary<string, object>> PorItem(IEnumerable<int> items)
        {
            string ids = Ids(items);
            List<Dictionary<string, object>> l = ids.Length == 0 ? new List<Dictionary<string, object>>() : Listar("@ITEMS", ids);
            return l.ToLookup(r => Convert.ToInt32(r["ITEM"]));
        }

        /// <summary>Por código de ítem, en la versión que muestra el cajón de la pauta.</summary>
        public static ILookup<string, Dictionary<string, object>> PorPlantilla(int plantilla)
        {
            return Listar("@PLANTILLA", plantilla).ToLookup(r => Convert.ToString(r["ITEM_CODIGO"]));
        }

        /// <summary>
        /// Sube la imagen (data URL desde el navegador) y la pega a la actividad o al ítem.
        /// Se aliviana como toda imagen del sitio (SoporteDatos.SubirArchivo, categoría REFERENCIA).
        /// </summary>
        public static int Agregar(string nombre, string datos, string titulo, int? actividad, int? plantilla, string itemCodigo)
        {
            if (string.IsNullOrEmpty(datos)) throw new Exception("Elige la imagen de referencia.");
            int coma = datos.IndexOf(',');
            string cab = coma > 0 ? datos.Substring(0, coma) : "";
            string mime = cab.StartsWith("data:") ? cab.Substring(5).Split(';')[0] : "";
            if (!mime.StartsWith("image/", StringComparison.OrdinalIgnoreCase) || mime.Contains("svg"))
                throw new Exception("La referencia debe ser una foto (JPG, PNG o WEBP).");
            int cli = Session.ClienteId();
            int archivo = SoporteDatos.SubirArchivo(cli, "referencias", string.IsNullOrWhiteSpace(nombre) ? "referencia.jpg" : nombre, mime,
                coma >= 0 ? datos.Substring(coma + 1) : datos, MAX_MB);
            Dictionary<string, object> f = SoporteDatos.Fila("INS_ARCHIVO_REFERENCIA", "@CLIENTE", cli, "@ARCHIVO", archivo,
                "@ACTIVIDAD", actividad, "@PLANTILLA", plantilla, "@ITEM_CODIGO", string.IsNullOrWhiteSpace(itemCodigo) ? null : itemCodigo,
                "@TITULO", string.IsNullOrWhiteSpace(titulo) ? null : titulo.Trim(), "@USUARIO", SoporteDatos.Usuario());
            object id;
            return f.TryGetValue("ID", out id) && id != null ? Convert.ToInt32(id) : 0;
        }

        /// <summary>Cambia el texto «qué debe verse» (vacío lo quita).</summary>
        public static void Titulo(int id, string titulo)
        {
            SoporteDatos.Filas("UPD_ARCHIVO_REFERENCIA", "@ID", id, "@CLIENTE", Session.ClienteId(),
                "@TITULO", string.IsNullOrWhiteSpace(titulo) ? null : titulo.Trim(), "@USUARIO", SoporteDatos.Usuario());
        }

        /// <summary>Baja lógica: el archivo puede seguir en otra versión del plan o de la pauta.</summary>
        public static void Quitar(int id)
        {
            SoporteDatos.Filas("DEL_ARCHIVO_REFERENCIA", "@ID", id, "@CLIENTE", Session.ClienteId(), "@USUARIO", SoporteDatos.Usuario());
        }

        private static string Ids(IEnumerable<int> ids)
        {
            return string.Join(",", (ids ?? Enumerable.Empty<int>()).Where(x => x > 0).Distinct());
        }
    }
}
