using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Vinculo plan-equipo (HU-083): a que activos se aplica una version del
    /// plan, y opcionalmente sobre que componente y con que medidor.
    ///
    /// Es un vinculo, no un registro con historia: no tiene habilitado ni
    /// auditoria de actualizacion, y su baja es fisica.
    /// </summary>
    [Serializable]
    public class PlanActivo
    {
        public int pac_id { get; set; }
        public int pac_plan_mantenimiento_version { get; set; }
        public int pac_activo { get; set; }
        public int? pac_activo_componente { get; set; }
        public int? pac_activo_medidor { get; set; }
        public int pac_usuario_creacion { get; set; }
        public DateTime? pac_fecha_creacion { get; set; }

        // Resueltas por SEL_PLAN_ACTIVO
        public int plan_id { get; set; }
        public int plan_cliente { get; set; }
        public string plan_codigo { get; set; }
        public string plan_nombre { get; set; }
        public int? version_numero { get; set; }
        public string version_estado_codigo { get; set; }
        public string version_estado_nombre { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string planta_nombre { get; set; }
        public string area_nombre { get; set; }
        public string tipo_nombre { get; set; }
        public string estado_activo_nombre { get; set; }
        public string componente_codigo { get; set; }
        public string componente_nombre { get; set; }
        public string medidor_codigo { get; set; }
        public string medidor_nombre { get; set; }
        public string usuario_creacion_nombre { get; set; }

        public bool version_editable
        {
            get { return string.Equals(version_estado_codigo, "BORRADOR", StringComparison.OrdinalIgnoreCase); }
        }

        // Filtros
        public int? filtro_cliente { get; set; }
        public int? filtro_plan { get; set; }
        public int? filtro_version { get; set; }
        public int? filtro_activo { get; set; }
        public string filtro { get; set; }

        public bool quita_componente { get; set; }
        public bool quita_medidor { get; set; }
    }
}
