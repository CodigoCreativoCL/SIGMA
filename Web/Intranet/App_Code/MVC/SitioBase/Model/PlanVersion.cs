using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Una versión de un plan de mantenimiento (HU-084). Estados: BORRADOR (1),
    /// PUBLICADO (2), RETIRADO (3). Al publicar, el borrador pasa a PUBLICADO,
    /// la publicada anterior a RETIRADO, y su contenido (hitos y equipos) queda
    /// congelado. Las calculadas (código/nombre del plan, conteos, nombres de
    /// usuario) las devuelve SEL_PLAN_VERSION.
    /// </summary>
    [Serializable]
    public class PlanVersion
    {
        public int pmv_id { get; set; }
        public int pmv_plan_mantenimiento { get; set; }
        public int pmv_numero { get; set; }
        public int pmv_estado { get; set; }
        public string estado_codigo { get; set; }
        public string estado_nombre { get; set; }
        public DateTime? pmv_fecha_publicacion { get; set; }
        public DateTime? pmv_fecha_retiro { get; set; }
        public string pmv_observacion { get; set; }
        public DateTime? pmv_fecha_creacion { get; set; }

        public int plan_cliente { get; set; }
        public string plan_codigo { get; set; }
        public string plan_nombre { get; set; }

        public int hitos { get; set; }
        public int activos { get; set; }
        public int ocurrencias { get; set; }

        public string usuario_publicacion_nombre { get; set; }
        public string usuario_creacion_nombre { get; set; }
    }
}
