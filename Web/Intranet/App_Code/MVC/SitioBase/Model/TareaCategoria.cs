using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Categoría de tarea del cliente (HU-100). Un catálogo simple
    /// (código + nombre + color + orden) para clasificar las tareas. El código
    /// es único dentro del cliente.
    /// </summary>
    [Serializable]
    public class TareaCategoria
    {
        public int tca_id { get; set; }
        public int tca_cliente { get; set; }
        public string tca_codigo { get; set; }
        public string tca_nombre { get; set; }
        public string tca_color { get; set; }
        public int? tca_orden { get; set; }
        public DateTime? tca_fecha_creacion { get; set; }
        public DateTime? tca_fecha_actualizacion { get; set; }
        public bool tca_habilitado { get; set; }

        // Filtros del listado.
        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
    }
}
