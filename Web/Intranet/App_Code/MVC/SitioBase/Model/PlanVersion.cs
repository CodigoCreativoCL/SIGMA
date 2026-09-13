using System;

namespace SitioBase.Model
{
    /// <summary>Una version de un plan (HU-084): borrador, publicada o retirada.</summary>
    public class PlanVersion
    {
        public int pmv_id { get; set; }
        public int pmv_plan_mantenimiento { get; set; }
        public int pmv_numero { get; set; }
        public int pmv_plan_version_estado { get; set; }
        public string estado_codigo { get; set; }
        public string estado_nombre { get; set; }
        public DateTime? pmv_fecha_publicacion { get; set; }
        public string usuario_publicacion_nombre { get; set; }
        public DateTime? pmv_fecha_retiro { get; set; }
        public string pmv_observacion { get; set; }
        public DateTime? pmv_fecha_creacion { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public bool pmv_habilitado { get; set; }
        public int plan_cliente { get; set; }
        public string plan_codigo { get; set; }
        public string plan_nombre { get; set; }
        public int hitos { get; set; }
        public int activos { get; set; }
        public int ocurrencias { get; set; }

        public int? filtro_cliente { get; set; }
        public int? filtro_plan { get; set; }
    }
}
