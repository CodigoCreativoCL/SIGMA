using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Dependencia entre ítems de una pauta (HU-092): un ítem (el dependiente) se
    /// muestra / oculta / requiere / bloquea según cómo se respondió OTRO ítem (la
    /// condición) con un operador y un valor. Ambos ítems son de la misma pauta y
    /// un ítem no puede depender de sí mismo. El mostrar/ocultar en terreno lo hace
    /// la app. Las columnas calculadas las devuelve SEL_CHECKLIST_ITEM_DEPENDENCIA.
    /// </summary>
    [Serializable]
    public class ChecklistItemDependencia
    {
        public int cid_id { get; set; }
        public int item_id { get; set; }          // cid_checklist_plantilla_item (dependiente)
        public int condicion_id { get; set; }     // cid_item_condicion
        public int operador_id { get; set; }      // cid_operador_comparacion
        public string valor { get; set; }         // cid_valor_comparacion
        public int? opcion_id { get; set; }       // cid_checklist_item_opcion
        public int accion_id { get; set; }        // cid_dependencia_accion
        public bool habilitado { get; set; }

        // Calculadas por SEL_CHECKLIST_ITEM_DEPENDENCIA
        public string item_texto { get; set; }
        public string condicion_texto { get; set; }
        public string operador_nombre { get; set; }
        public string opcion_texto { get; set; }
        public string accion_codigo { get; set; }
        public string accion_nombre { get; set; }
        public int plantilla_id { get; set; }
        public string plantilla_nombre { get; set; }

        // Filtros del listado
        public int? filtro_plantilla { get; set; }
        public string filtro { get; set; }
    }
}
