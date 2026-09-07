using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Variable de medición (temperatura, vibración, presión…). Catálogo del
    /// cliente MÁS las globales del sistema. La usan los pasos que exigen una
    /// medición (HU-062). Vista mínima: lo que necesita un combo.
    /// </summary>
    [Serializable]
    public class VariableMedicion
    {
        public int vme_id { get; set; }
        public string vme_codigo { get; set; }
        public string vme_nombre { get; set; }
        public string etiqueta { get; set; }   // "Temperatura (°C)"
        public bool es_global { get; set; }

        public int filtro_cliente { get; set; }
        public bool? filtro_habilitado { get; set; }
    }
}
