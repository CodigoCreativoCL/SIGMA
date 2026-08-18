using System;

namespace SitioBase.Model
{
    [Serializable]
    public class PrivacidadModuloSistema
    {
        public int      pms_id                  { get; set; }
        public int      pms_id_modulo           { get; set; }
        public string   mds_nombre              { get; set; }
        public string   pms_descripcion         { get; set; }
        public int      pms_usuario_creacion    { get; set; }
        public DateTime pms_fecha_creacion      { get; set; }
        public int      pms_usuario_act         { get; set; }
        public DateTime pms_fecha_act           { get; set; }
        public string   usuario_creacion_nombre { get; set; }
        public string   usuario_act_nombre      { get; set; }

        // Filtros
        public int?   filtro_id            { get; set; }
        public int?   filtro_id_modulo     { get; set; }
        public string filtro_nombre_modulo { get; set; }
        public string filtro              { get; set; }
    }
}
