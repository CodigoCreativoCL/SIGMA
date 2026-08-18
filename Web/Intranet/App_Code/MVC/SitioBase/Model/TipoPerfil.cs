using System;

namespace SitioBase.Model
{
    [Serializable]
    public class TipoPerfil
    {
        public int tpp_id { get; set; }
        public string tpp_nombre { get; set; }
        public bool tpp_habilitado { get; set; }
    }
}