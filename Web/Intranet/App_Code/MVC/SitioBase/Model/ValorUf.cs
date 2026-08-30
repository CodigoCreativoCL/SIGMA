using System;

namespace SitioBase.Model
{
    /// <summary>
    /// El valor de la UF de un día (ANEXO F §4.2). Tabla append-only, una
    /// fila por fecha.
    ///
    /// es_arrastre marca los días en que la fuente no respondió y se copió
    /// el último valor conocido. No es un error -es lo que evita que una
    /// caída externa bloquee una renovación- pero son los días que hay que
    /// revisar y corregir cuando la fuente vuelva.
    /// </summary>
    [Serializable]
    public class ValorUf
    {
        public int vuf_id { get; set; }
        public DateTime vuf_fecha { get; set; }
        public decimal vuf_valor { get; set; }
        public DateTime? vuf_fecha_obtencion_utc { get; set; }
        public string vuf_respuesta_cruda { get; set; }

        public string ufo_codigo { get; set; }
        public string ufo_nombre { get; set; }
        public bool es_arrastre { get; set; }
    }
}
