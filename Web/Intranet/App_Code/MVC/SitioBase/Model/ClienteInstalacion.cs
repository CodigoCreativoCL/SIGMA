using System;
using System.Collections.Generic;

namespace SitioBase.Model
{
    [Serializable]
    public class ClienteInstalacion
    {
        public int cin_id { get; set; }
        public int cin_cliente{ get; set; }
        public string cin_nombre { get; set; }
        public string cin_descripcion { get; set; }
        public string cin_direccion { get; set; }
        public bool cin_habilitado { get; set; }
        public int cin_usuario_creacion { get; set; }
        public DateTime cin_fecha_creacion { get; set; }
        public int cin_usuario_actualizacion { get; set; }
        public DateTime cin_fecha_actualizacion{ get; set; }

        // HU-011. Columnas agregadas en el bloque 25 de base de datos.
        public string cin_codigo { get; set; }
        public int? cin_zona_horaria { get; set; }
        public decimal? cin_latitud { get; set; }
        public decimal? cin_longitud { get; set; }

        // Columnas que resuelve SEL_CLIENTE_INSTALACION
        public string cli_nombre { get; set; }
        public string zho_nombre { get; set; }

        /// <summary>
        /// Zona horaria con la que se calculan las programaciones de esta
        /// planta: la propia si tiene, y si no la del cliente. La resuelve
        /// el SP para que nadie tenga que repetir la regla.
        /// </summary>
        public int? zona_horaria_efectiva { get; set; }

        public string filtro { get; set; }
        public int usuario { get; set; }
        public string filtro_paises { get; set; }
        public string filtro_cliente { get; set; }
        public string filtro_habilitado { get; set; }

        public bool notificacion_correo { get; set; }
        public bool notificacion_sms { get; set; }
        public bool notificacion_whatapp { get; set; }
        public bool notificacion_app { get; set; }
        public string filtro_guardia { get; set; }

    }
}