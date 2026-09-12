using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Hito de un plan de mantenimiento (HU-081): que se le hace al equipo y
    /// cada cuanto. El «cada cuanto» es la programacion a la que apunta.
    ///
    /// Cuelga de la VERSION del plan, no del plan. Desde la ficha se elige el
    /// plan y el SP resuelve su version en borrador: pedirle al usuario que
    /// entienda esa tabla intermedia seria pedirle que entienda algo que
    /// existe por trazabilidad, no por el.
    /// </summary>
    [Serializable]
    public class PlanHito
    {
        public int pmh_id { get; set; }
        public int pmh_plan_mantenimiento_version { get; set; }
        public int pmh_programacion { get; set; }
        public string pmh_codigo { get; set; }
        public string pmh_nombre { get; set; }
        public int pmh_orden { get; set; }
        public decimal? pmh_valor_medidor { get; set; }
        public int? pmh_unidad_medida { get; set; }
        public bool pmh_es_overhaul { get; set; }
        public bool pmh_requiere_parada { get; set; }
        public int? pmh_duracion_estimada_minuto { get; set; }
        public int? pmh_orden_trabajo_tipo { get; set; }
        public int? pmh_orden_trabajo_prioridad { get; set; }
        public string pmh_descripcion { get; set; }
        public int pmh_usuario_creacion { get; set; }
        public DateTime? pmh_fecha_creacion { get; set; }
        public int? pmh_usuario_actualizacion { get; set; }
        public DateTime? pmh_fecha_actualizacion { get; set; }
        public bool pmh_habilitado { get; set; }

        // Resueltas por SEL_PLAN_HITO
        public int plan_id { get; set; }
        public int plan_cliente { get; set; }
        public string plan_codigo { get; set; }
        public string plan_nombre { get; set; }
        public int? version_numero { get; set; }
        public string version_estado_codigo { get; set; }
        public string version_estado_nombre { get; set; }
        public string programacion_nombre { get; set; }
        public string programacion_tipo_nombre { get; set; }
        public string unidad_simbolo { get; set; }
        public string ot_tipo_nombre { get; set; }
        public string ot_prioridad_nombre { get; set; }
        public int actividades { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        /// <summary>Solo se edita sobre un borrador; la ficha se bloquea si no.</summary>
        public bool version_editable
        {
            get { return string.Equals(version_estado_codigo, "BORRADOR", StringComparison.OrdinalIgnoreCase); }
        }

        // Filtros
        public int? filtro_cliente { get; set; }
        public int? filtro_plan { get; set; }
        public int? filtro_version { get; set; }
        public bool? filtro_habilitado { get; set; }
        public string filtro { get; set; }

        // Banderas de «quitalo» para los opcionales
        public bool quita_medidor { get; set; }
        public bool quita_ot_tipo { get; set; }
        public bool quita_ot_prioridad { get; set; }
        public bool quita_duracion { get; set; }
    }
}
