using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un tramo de estado de un activo (HU-038): desde cuándo estuvo en ese
    /// estado, hasta cuándo, con qué motivo y quién lo cambió.
    /// </summary>
    [Serializable]
    public class ActivoEstadoHistorial
    {
        public int aeh_id { get; set; }
        public int aeh_cliente { get; set; }
        public int aeh_activo { get; set; }
        public int aeh_activo_estado { get; set; }
        public DateTime? aeh_fecha_inicio_utc { get; set; }
        public DateTime? aeh_fecha_fin_utc { get; set; }
        public string aeh_motivo { get; set; }

        // Calculadas por SEL_ACTIVO_ESTADO_HISTORIAL
        public string estado_nombre { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public bool vigente { get; set; }
        public string usuario_nombre { get; set; }

        // Para disparar el proceso ACTIVO_CAMBIAR_ESTADO
        public int nuevo_estado { get; set; }
    }
}
