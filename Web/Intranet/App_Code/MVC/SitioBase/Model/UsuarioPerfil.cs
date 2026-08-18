using System;

namespace SitioBase.Model
{
    [Serializable]
    public class UsuarioPerfil
    {
        public int upe_id { get; set; }
        public int upe_usuario { get; set; }
        public int upe_perfil { get; set; }
        public string perfil_nombre { get; set; }
        public bool perfil_habilitado { get; set; }
        public int perfil_tipo { get; set; }
    }
}