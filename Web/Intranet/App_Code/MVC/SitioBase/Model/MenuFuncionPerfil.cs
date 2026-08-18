using System;

namespace SitioBase.Model
{
    [Serializable]
    public class MenuFuncionPerfil
    {
        public int mfp_id { get; set; }
        public int mfp_perfil { get; set; }
        public int mfp_menu_funcion { get; set; }
        public bool mfp_habilitado { get; set; }
    }
}