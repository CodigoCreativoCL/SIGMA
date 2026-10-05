using System;

namespace SitioBase.Model
{
    [Serializable]
    public class Perfil
    {
        public int per_id { get; set; }
        public string per_nombre { get; set; }
        public string per_descripcion { get; set; }
        public int per_empresa { get; set; }
        public int per_area { get; set; }
        public bool per_habilitado { get; set; }
        public string tipo { get; set; }
        public int per_tipo { get; set; }

        public string Perfiles { get; set; }
        
        public string filtro_habilitado { get; set; }
        /// <summary>
        /// Empresa cuyos perfiles se ofrecen (bloque 341): los propios del
        /// cliente más los del sistema. 0 = todos (mantenedor de plataforma).
        /// </summary>
        public int cliente { get; set; }
    }
}