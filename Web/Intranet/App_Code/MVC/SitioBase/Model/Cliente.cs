using System;

namespace SitioBase.Model
{
    [Serializable]
    public class Cliente
    {


        public int cli_id { get; set; }
        public string cli_nombre { get; set; }
        public int cli_pais { get; set; }
        public string cli_razon_social { get; set; }
        public string cli_identificador { get; set; }
        public bool cli_habilitado { get; set; }
        public int cli_usuario_creacion { get; set; }
        public DateTime cli_fecha_creacion { get; set; }
        public int cli_usuario_actualizacion { get; set; }
        public DateTime cli_fecha_actualizacion { get; set; }
        
        public string pai_nombre { get; set; }
        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public string filtro_paises { get; set; }
        public string filtro_instalacion { get; set; }
        public string filtro_usuarios { get; set; }
        public int tipo_perfil { get; set; }
        public string filtro_pais { get; set; }
        public byte[] cli_logo { get; set; }

    }
}