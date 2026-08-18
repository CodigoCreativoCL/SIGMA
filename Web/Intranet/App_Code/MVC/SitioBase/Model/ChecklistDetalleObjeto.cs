using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SitioBase.Model
{
    [Serializable]
    public class ChecklistDetalleObjeto
    {
        public int cdc_id { get; set; }
        public int cdc_id_checklist_detalle { get; set; }
        public int cdc_orden { get; set; }
        public string cdc_nombre { get; set; }
        public int cdc_usuario_creacion { get; set; }
        public DateTime cdc_fecha_creacion { get; set; }
        public int cdc_usuario_act { get; set; }
        public DateTime cdc_fecha_act { get; set; }
        public string filtro { get; set; }

    }
}
