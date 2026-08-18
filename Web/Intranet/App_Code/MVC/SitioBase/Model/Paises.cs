using System;

namespace SitioBase.Model
{
    [Serializable]
    public class Paises
    {
        public int pai_id { get; set; }
        public string pai_nombres { get; set; }
        public string pai_suma_resta { get; set; }
        public int pai_hora { get; set; }
        public bool pai_habilitado { get; set; }
        public int pai_usuario_creacion { get; set; }
        public DateTime pai_fecha_creacion { get; set; }
        public int pai_usuario_actualizacion { get; set; }
        public DateTime pai_fecha_actualizacion { get; set; }

        public string filtro { get; set; }
        public string filtro_cliente { get; set; }
        public string filtro_instalacion { get; set; }
        public string filtro_habilitado { get; set; }
        public string filtro_pais { get; set; }
        public int id_usuario { get; set; }
    }
}