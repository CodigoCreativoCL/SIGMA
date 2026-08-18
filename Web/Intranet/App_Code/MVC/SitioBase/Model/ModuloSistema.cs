using System;

namespace SitioBase.Model
{
    [Serializable]
    public class ModuloSistema
    {
        public int    mds_id               { get; set; }
        public string mds_nombre           { get; set; }
        public bool   mds_habilitado       { get; set; }
        public DateTime? mds_fecha_creacion { get; set; }
        public DateTime? mds_fecha_act      { get; set; }

        // Filtros
        public int?   filtro_id         { get; set; }
        public string filtro_nombre     { get; set; }
        public string filtro_habilitado { get; set; }
    }
}
