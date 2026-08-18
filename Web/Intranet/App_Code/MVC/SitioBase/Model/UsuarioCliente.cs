using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SitioBase.Model
{
    [Serializable]
    public class UsuarioCliente
    {
        public int ucl_id { get; set; }
        public int ucl_id_usurio { get; set; }
        public int ucl_id_cliente { get; set; }
        public int ucl_usuario_creacion { get; set; }
        public DateTime ucl_fecha_creacion { get; set; }
        public int ucl_usuario_act { get; set; }
        public DateTime ucl_fecha_act { get; set; }
    }
}