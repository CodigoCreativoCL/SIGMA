using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Programación recurrente de una pauta de inspección (HU-094): enlaza la
    /// versión PUBLICADA de una pauta con una recurrencia (Programacion) sobre un
    /// objetivo (activo o área) y, opcionalmente, un grupo y un responsable. La
    /// regla activo-o-área vive en el SP. Las calculadas las devuelve
    /// SEL_CHECKLIST_PROGRAMACION por JOIN.
    /// </summary>
    [Serializable]
    public class ChecklistProgramacion
    {
        public int cpr_id { get; set; }
        public int cpr_cliente { get; set; }
        public int cpr_version { get; set; }                 // cpr_checklist_plantilla_version
        public int cpr_checklist_plantilla { get; set; }     // la pauta (se resuelve su versión publicada)
        public int version_numero { get; set; }
        public int cpr_programacion { get; set; }
        public int? cpr_activo { get; set; }
        public int? cpr_instalacion_area { get; set; }
        public int? cpr_grupo_trabajo { get; set; }
        public int? cpr_usuario_responsable { get; set; }
        public string cpr_nombre { get; set; }
        public bool cpr_habilitado { get; set; }
        public DateTime? cpr_fecha_creacion { get; set; }
        public DateTime? cpr_fecha_actualizacion { get; set; }

        // Calculadas por SEL_CHECKLIST_PROGRAMACION
        public string pauta_codigo { get; set; }
        public string pauta_nombre { get; set; }
        public string programacion_nombre { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string area_nombre { get; set; }
        public string grupo_nombre { get; set; }
        public string responsable_nombre { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        // Filtros
        public string filtro { get; set; }
        public int filtro_cliente { get; set; }
        public int filtro_checklist_plantilla { get; set; }
        public int filtro_activo { get; set; }
        public bool? filtro_habilitado { get; set; }
    }
}
