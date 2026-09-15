using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Una plantilla de checklist / pauta de inspección (HU-090): "Ronda diaria
    /// sala blowers". Es el concepto reutilizable; lo que se congela al publicar
    /// vive en Checklist_Plantilla_Version. El código es único POR CLIENTE
    /// (UX_CPL_CLIENTE_CODIGO). Las calculadas las devuelve SEL_CHECKLIST_PLANTILLA
    /// por JOIN.
    /// </summary>
    [Serializable]
    public class ChecklistPlantilla
    {
        public int cpl_id { get; set; }
        public int cpl_cliente { get; set; }
        public int? cpl_cliente_instalacion { get; set; }
        public int? cpl_checklist_asignacion_tipo { get; set; }
        public int? cpl_activo_tipo { get; set; }
        public string cpl_codigo { get; set; }
        public string cpl_nombre { get; set; }
        public string cpl_descripcion { get; set; }
        public DateTime? cpl_fecha_creacion { get; set; }
        public DateTime? cpl_fecha_actualizacion { get; set; }
        public bool cpl_habilitado { get; set; }

        // Calculadas por SEL_CHECKLIST_PLANTILLA
        public string planta_nombre { get; set; }
        public string asignacion_tipo_nombre { get; set; }
        public string activo_tipo_nombre { get; set; }
        public int versiones { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        // Filtros
        public string filtro { get; set; }
        public int filtro_cliente { get; set; }
        public int filtro_cliente_instalacion { get; set; }
        public int filtro_activo_tipo { get; set; }
        public bool? filtro_habilitado { get; set; }
    }
}
