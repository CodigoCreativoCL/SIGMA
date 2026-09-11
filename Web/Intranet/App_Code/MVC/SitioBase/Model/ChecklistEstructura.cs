using System;
using System.Collections.Generic;

namespace SitioBase.Model
{
    /// <summary>Una sección de la pauta (área: Silos, Blowers…) con sus campos.</summary>
    [Serializable]
    public class ChecklistSeccion
    {
        public int cps_id { get; set; }
        public string sid { get; set; }         // id de cliente (para agrupar los campos en el POST)
        public string cps_nombre { get; set; }
        public int cps_orden { get; set; }
        public List<ChecklistItem> items { get; set; }

        public ChecklistSeccion() { items = new List<ChecklistItem>(); }
    }

    /// <summary>Un campo/ítem de la pauta: qué se chequea, de qué tipo y con qué rango.</summary>
    [Serializable]
    public class ChecklistItem
    {
        public int cpi_id { get; set; }
        public string seccion_sid { get; set; }  // a qué sección pertenece (por sid de cliente)
        public string cpi_texto { get; set; }
        public int cpi_tipo { get; set; }
        public string tipo_nombre { get; set; }
        public int cpi_orden { get; set; }
        public bool cpi_obligatorio { get; set; }
        public int? cpi_unidad { get; set; }
        public string unidad_simbolo { get; set; }
        public string rango_min { get; set; }    // texto, tal como va al input
        public string rango_max { get; set; }
    }

    /// <summary>Tipo de campo (Sí/No, Número, Texto…). Catálogo Checklist_Item_Tipo.</summary>
    [Serializable]
    public class ChecklistItemTipo
    {
        public int cit_id { get; set; }
        public string cit_codigo { get; set; }
        public string cit_nombre { get; set; }
    }
}
