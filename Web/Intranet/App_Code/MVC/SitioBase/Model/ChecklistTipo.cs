using System;

namespace SitioBase.Model
{
    [Serializable]
    public class ChecklistTipo
    {
        public int ckt_id { get; set; }
        public string ckt_nombre { get; set; }

        // filtros usados por el Controller
        public string filtro { get; set; }
    }
}
