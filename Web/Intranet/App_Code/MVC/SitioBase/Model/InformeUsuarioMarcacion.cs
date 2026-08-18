using System;
using System.Collections.Generic;

namespace SitioBase.Model
{
    [Serializable]
    public class InformeUsuarioMarcacion
    {
        public int mar_id { get; set; }
        public string usuario_nombre { get; set; }
        public string mar_tipo { get; set; }
        public DateTime mar_fecha { get; set; }
        public DateTime? mar_fecha_remota { get; set; }
        public string cli_nombre { get; set; }
        public string ins_nombre { get; set; }

        public int id_cliente { get; set; }
        public int id_Instalacion { get; set; }
        public string filtro { get; set; }
        public DateTime? Desde { get; set; }
        public DateTime? Hasta { get; set; }
        public int id_Monitor { get; set; }
        public string filtro_paises { get; set; }
        public string clienteNombre { get; set; }
        public int usuario { get; set; }
        public string filtro_cliente { get; set; }
        public string filtro_instalacion { get; set; }
        public string filtro_estado { get; set; }

        public string arc_nombre_archivo { get; set; }
        public string arc_extension { get; set; }
        public byte[] abi_archivo_binario { get; set; }
        public DateTime? mar_fecha_creacion { get; set; }
        public DateTime fecha_desde { get; set; }
        public DateTime fecha_hasta { get; set; }
        public string tipo_nombre { get; set; }
        public string fecha { get; set; }
        public string hora { get; set; }

        public DateTime mar_fecha_hora_minuto_segundos { get; set; }
        public decimal mar_latitud { get; set; }
        public decimal mar_longitud { get; set; }

    }
}