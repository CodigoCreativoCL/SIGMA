using System;

namespace SitioBase.Model
{
    [Serializable]
    public class MenuPerfil
    {
        public int mpe_id { get; set; }
        public int mpe_perfil { get; set; }
        public int mpe_menu { get; set; }
        public bool mpe_habilitado { get; set; }
    }
}