using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SitioBase.Model
{
    [Serializable]
    public class Checklist
    {
        public int chk_id { get; set; }
        public int chk_cliente { get; set; }
        public string chk_nombre { get; set; }
        public string chk_descripcion { get; set; }
        public int chk_usuario_creacion { get; set; }
        public DateTime chk_fecha_creacion { get; set; }
        public int chk_usuario_act { get; set; }
        public DateTime chk_fecha_act { get; set; }

        public bool chk_habilitado { get; set; }

        public bool? filtro_habilitado { get; set; }

        public string filtro { get; set; }

        public string filtro_cliente { get; set; }

    }
}
