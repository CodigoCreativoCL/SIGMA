using System;

namespace SitioBase.Model
{
    [Serializable]
    public class MenuAccesoDirecto
    {
        public int mnu_id { get; set; }
        public string mnu_nombre { get; set; }
        public string mnu_icon { get; set; }
        public string mnu_link { get; set; }
        public string mnu_seccion { get; set; }
    }
}
