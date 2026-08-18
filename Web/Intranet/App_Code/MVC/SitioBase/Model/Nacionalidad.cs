using System;

namespace SitioBase.Model
{
    [Serializable]
    public class Nacionalidad
    {
        public int nac_id { get; set; }
        public string nac_nombres { get; set; }
        public bool nac_habilitado { get; set; }
        public int nac_usuario_creacion { get; set; }
        public DateTime nac_fecha_creacion { get; set; }
        public int nac_usuario_actualizacion { get; set; }
        public DateTime nac_fecha_actualizacion { get; set; }

        public string filtro { get; set; }
        public string filtro_habilitado { get; set; }
    }
}