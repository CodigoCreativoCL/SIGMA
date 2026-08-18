using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SitioBase.Model
{
    [Serializable]
    public class UsuarioPaises
    {
        public int upa_id { get; set; }
        public int upa_id_usuario { get; set; }
        public int upa_id_pais { get; set; }
        public int upa_usuario_creacion { get; set; }
        public DateTime upa_fecha_creacion { get; set; }
        public int upa_usuario_act { get; set; }
        public DateTime upa_fecha_act { get; set; }
        public string nombre { get; set; }

    }
}