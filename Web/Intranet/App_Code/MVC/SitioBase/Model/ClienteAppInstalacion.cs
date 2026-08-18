using System;


namespace SitioBase.Model
{
    [Serializable]
    public class ClienteAppInstalacion
    {
        public int cai_id { get; set; }
        public int id_cliente { get; set; }
        public int cai_id_instalacion { get; set; }
        public int cai_id_app { get; set; }
        public bool? cai_habilitado { get; set; }
        public int cai_usuario_creacion { get; set; }
        public DateTime cai_fecha_creacion { get; set; }
        public int cai_usuario_actualizacion { get; set; }
        public DateTime cai_fecha_actualizacion { get; set; }
        public int app_id { get; set; }
        public string app_nombre { get; set; }
        public int app_tipo { get; set; }
        public int cap_id { get; set; }

    }
}