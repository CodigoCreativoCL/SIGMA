using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SitioBase.Model
{
    [Serializable]
    public class ChecklistDetalle
    {
        public int chd_id { get; set; }
        public int chd_id_checklist { get; set; }
        public string chd_pregunta { get; set; }
        public int chd_objeto { get; set; }
        public int chd_orden { get; set; }
        public int chd_usuario_creacion { get; set; }
        public DateTime chd_fecha_creacion { get; set; }
        public int chd_usuario_act { get; set; }
        public DateTime chd_fecha_act { get; set; }

        public bool chd_valor_predeterminado {  get; set; }

        public string chd_valor {  get; set; }

        public bool chd_habilitado{ get; set; }

        public bool chd_notificacion { get; set; }

        public string filtro { get; set; }
        public string nombreCheckList { get; set; }
        public string nombreObjeto { get; set; }
        public string nombreTipoDato { get; set; }

    }
}
