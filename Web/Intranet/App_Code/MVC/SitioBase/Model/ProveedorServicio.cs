using System;
using System.Collections.Generic;

namespace SitioBase.Model
{
    /// <summary>
    /// Un servicio que el proveedor prestó, con la orden de trabajo donde
    /// quedó registrado.
    ///
    /// La ficha decía "1 servicio asociado". Es un número, y un número no
    /// sirve para lo que la gente hace con esa pantalla: saber qué hizo,
    /// cuándo, cuánto costó y con qué respaldo.
    /// </summary>
    public class ProveedorServicio
    {
        public int ots_id { get; set; }
        public int ots_orden_trabajo { get; set; }

        public string OT_NUMERO { get; set; }
        public string OT_TITULO { get; set; }
        public string OT_ESTADO { get; set; }

        public string TIPO_NOMBRE { get; set; }
        public string ots_descripcion { get; set; }

        public decimal? ots_cantidad { get; set; }
        public decimal? ots_monto_unitario { get; set; }
        public decimal? ots_monto { get; set; }
        public string MONEDA_NOMBRE { get; set; }

        public string ots_documento_referencia { get; set; }
        public DateTime? ots_fecha_servicio_utc { get; set; }
        public DateTime? ots_fecha_documento { get; set; }

        /// <summary>Cuántos archivos se pueden abrir.</summary>
        public int ADJUNTOS { get; set; }

        /// <summary>
        /// Cuántos existen pero NO se ofrecen: pendientes de revisar o
        /// detectados como infectados.
        ///
        /// Se cuentan aparte para poder decir por qué no aparecen. Esconderlos
        /// sin explicación deja a alguien buscando un informe que sí existe.
        /// </summary>
        public int ADJUNTOS_RETENIDOS { get; set; }

        /// <summary>
        /// Los archivos de la ORDEN DE TRABAJO donde se registró el servicio.
        ///
        /// No son "del servicio": `Archivo_Vinculo` engancha a la orden, no a
        /// la línea. Si la OT tiene dos servicios del mismo proveedor, los dos
        /// muestran los mismos archivos, y la pantalla lo dice así.
        /// </summary>
        public List<ProveedorAdjunto> Adjuntos { get; set; }

        public ProveedorServicio() { Adjuntos = new List<ProveedorAdjunto>(); }

        /// <summary>El monto con su moneda, o vacío si no se registró.</summary>
        public string MontoTexto
        {
            get
            {
                if (ots_monto == null) return "";

                return ots_monto.Value.ToString("N0") +
                       (string.IsNullOrEmpty(MONEDA_NOMBRE) ? "" : "  " + MONEDA_NOMBRE);
            }
        }
    }

    /// <summary>Un archivo de la orden de trabajo.</summary>
    public class ProveedorAdjunto
    {
        public int arc_id { get; set; }
        public int avi_orden_trabajo { get; set; }
        public string arc_nombre_original { get; set; }
        public string arc_extension { get; set; }
        public string arc_mime { get; set; }
        public long arc_byte { get; set; }
        public DateTime? arc_fecha_creacion { get; set; }
        public string CATEGORIA { get; set; }
        public string ANTIVIRUS { get; set; }
        public string avi_titulo { get; set; }

        /// <summary>"1,4 MB". Los bytes crudos no le dicen nada a nadie.</summary>
        public string TamanoTexto
        {
            get
            {
                if (arc_byte <= 0) return "";

                double v = arc_byte;

                if (v < 1024) return v.ToString("0") + " B";

                v = v / 1024;
                if (v < 1024) return v.ToString("0") + " KB";

                v = v / 1024;
                return v.ToString("0.#") + " MB";
            }
        }

        /// <summary>
        /// El icono según el tipo. Un PDF y una foto se buscan distinto en una
        /// lista, y la extensión sola obliga a leerla en cada fila.
        /// </summary>
        public string Icono
        {
            get
            {
                string e = (arc_extension ?? "").ToLower().TrimStart('.');
                string m = (arc_mime ?? "").ToLower();

                if (m.StartsWith("image/") || e == "jpg" || e == "jpeg" || e == "png" || e == "gif")
                    return "mdi-file-image-outline";

                if (e == "pdf") return "mdi-file-pdf-box";
                if (e == "xls" || e == "xlsx" || e == "csv") return "mdi-file-excel-outline";
                if (e == "doc" || e == "docx") return "mdi-file-word-outline";
                if (m.StartsWith("video/")) return "mdi-file-video-outline";

                return "mdi-file-outline";
            }
        }

        /// <summary>Si se puede mostrar en el visor o solo descargar.</summary>
        public bool SeVeEnPantalla
        {
            get
            {
                string m = (arc_mime ?? "").ToLower();
                return m.StartsWith("image/") || m == "application/pdf";
            }
        }
    }
}
