using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SitioBase.Model
{
    [Serializable]
    public class ChecklistTipoObjeto
    {
        public int cho_id { get; set; }
        public string cho_nombre { get; set; }
        public int cho_tipo_dato { get; set; }
    }
}
