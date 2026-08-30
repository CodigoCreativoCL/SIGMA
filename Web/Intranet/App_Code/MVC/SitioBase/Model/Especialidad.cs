using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Especialidad tecnica (HU-017).
    ///
    /// esp_cliente en NULL es una especialidad del sistema, visible para
    /// todos los clientes; con cliente informado es propia de ese cliente.
    /// Es el mismo mecanismo de los catalogos ampliables de HU-021.
    /// </summary>
    [Serializable]
    public class Especialidad
    {
        public int esp_id { get; set; }
        public int? esp_cliente { get; set; }
        public string esp_codigo { get; set; }
        public string esp_nombre { get; set; }
        public int? esp_orden { get; set; }
        public int esp_usuario_creacion { get; set; }
        public DateTime? esp_fecha_creacion { get; set; }
        public int esp_usuario_actualizacion { get; set; }
        public DateTime? esp_fecha_actualizacion { get; set; }
        public bool esp_habilitado { get; set; }

        public string origen { get; set; }

        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public bool filtro_solo_cliente { get; set; }
        public bool filtro_solo_sistema { get; set; }
    }
}
