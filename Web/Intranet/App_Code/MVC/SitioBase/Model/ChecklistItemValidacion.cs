using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Umbrales y acciones de un ítem de pauta (HU-091): por ítem, qué valores
    /// son normales (mínimo/advertencia/crítico/máximo, largo y expresión) y qué
    /// ocurre fuera de rango (exigir comentario, exigir evidencia, generar alerta,
    /// generar hallazgo) con un mensaje. Hay UNA validación por ítem. La
    /// clasificación en terreno la hace FNC_CHECKLIST_SEVERIDAD con estos valores.
    /// Las columnas calculadas las devuelve SEL_CHECKLIST_ITEM_VALIDACION por JOIN.
    /// </summary>
    [Serializable]
    public class ChecklistItemValidacion
    {
        public int civ_id { get; set; }
        public int item_id { get; set; }                 // civ_checklist_plantilla_item

        public decimal? valor_minimo { get; set; }
        public decimal? valor_maximo { get; set; }
        public decimal? valor_advertencia { get; set; }
        public decimal? valor_critico { get; set; }
        public int? largo_minimo { get; set; }
        public int? largo_maximo { get; set; }
        public string expresion_regular { get; set; }
        public int? unidad_medida { get; set; }
        public bool requiere_comentario { get; set; }
        public bool requiere_evidencia { get; set; }
        public bool genera_alerta { get; set; }
        public bool genera_hallazgo { get; set; }
        public string mensaje { get; set; }
        public bool habilitado { get; set; }

        // Calculadas por SEL_CHECKLIST_ITEM_VALIDACION
        public string item_codigo { get; set; }
        public string item_texto { get; set; }
        public string tipo_codigo { get; set; }
        public string tipo_nombre { get; set; }
        public string seccion_nombre { get; set; }
        public int plantilla_id { get; set; }
        public string plantilla_nombre { get; set; }
        public int version_numero { get; set; }
        public bool tiene_validacion { get; set; }   // solo para el combo de la ficha

        // Filtros del listado
        public int? filtro_plantilla { get; set; }
        public int? filtro_version { get; set; }
        public string filtro { get; set; }
    }
}
