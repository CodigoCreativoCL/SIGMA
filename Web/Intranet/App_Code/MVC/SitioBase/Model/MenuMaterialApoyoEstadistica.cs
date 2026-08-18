using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SitioBase.Model
{
    [Serializable]
    public class MenuMaterialApoyoEstadistica
    {
        public int mae_id { get; set; }
        public int mae_menu_apoyo { get; set; }
        public int mae_tipo { get; set; }
        public int mae_usuario { get; set; }
        public DateTime mae_fecha { get; set; }
        public string tipo { get; set; }
        public string NombreUsuario { get; set; }
        public string filtro { get; set; } 
    }
}