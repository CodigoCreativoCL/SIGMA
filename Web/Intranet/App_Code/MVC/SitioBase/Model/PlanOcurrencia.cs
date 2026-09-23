using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Una ocurrencia de un plan de mantenimiento (HU-086). Es una cita concreta
    /// del plan sobre un equipo en una fecha. Reprogramar no pisa la fecha: la
    /// ocurrencia pasa a REPROGRAMADA (7) con su motivo y nace una nueva en
    /// PENDIENTE (1) en la fecha nueva, ligada por el origen. Las calculadas
    /// (nombres, fecha a la que se movió, quién) las devuelve
    /// SEL_PLAN_OCURRENCIA_REPROGRAMAR.
    /// </summary>
    [Serializable]
    public class PlanOcurrencia
    {
        public int pmo_id { get; set; }
        public int pmo_cliente { get; set; }
        public int pmo_estado { get; set; }
        public string estado_nombre { get; set; }
        public DateTime? pmo_fecha_programada { get; set; }
        public DateTime? pmo_fecha_original { get; set; }
        public int? pmo_ocurrencia_origen { get; set; }
        public string pmo_observacion { get; set; }
        public int? pmo_orden_trabajo { get; set; }

        public int pmo_activo { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string hito_codigo { get; set; }
        public string hito_nombre { get; set; }
        public string plan_codigo { get; set; }
        public string plan_nombre { get; set; }

        public DateTime? pmo_fecha_actualizacion { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        /// <summary>Si ya fue reprogramada, a qué fecha se movió (la de su hija).</summary>
        public DateTime? pmo_fecha_nueva { get; set; }
        public int? pmo_ocurrencia_nueva { get; set; }

        /// <summary>Solo se reprograma lo que todavía no ocurrió: PENDIENTE (1) o DISPONIBLE (2).</summary>
        public bool EsReprogramable { get { return pmo_estado == 1 || pmo_estado == 2; } }
        public bool YaReprogramada { get { return pmo_estado == 7; } }
    }
}
