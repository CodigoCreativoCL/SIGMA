using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un evento de la línea de tiempo de un activo (HU-037): un cambio de
    /// estado, un cambio de posición o una medición, unificados por
    /// SEL_ACTIVO_FICHA.
    /// </summary>
    [Serializable]
    public class ActivoFichaEvento
    {
        public DateTime? fecha { get; set; }
        public string tipo_evento { get; set; }
        public string titulo { get; set; }
        public string detalle { get; set; }
        public string usuario_nombre { get; set; }
    }
}
