using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Cuadrilla o turno (HU-016).
    ///
    /// gtr_cliente_instalacion en NULL significa grupo transversal: sirve
    /// en todas las plantas del cliente.
    /// </summary>
    [Serializable]
    public class GrupoTrabajo
    {
        public int gtr_id { get; set; }
        public int gtr_cliente { get; set; }
        public int? gtr_cliente_instalacion { get; set; }
        public string gtr_codigo { get; set; }
        public string gtr_nombre { get; set; }
        public int? gtr_especialidad { get; set; }
        public string gtr_descripcion { get; set; }
        public int gtr_usuario_creacion { get; set; }
        public DateTime? gtr_fecha_creacion { get; set; }
        public int gtr_usuario_actualizacion { get; set; }
        public DateTime? gtr_fecha_actualizacion { get; set; }
        public bool gtr_habilitado { get; set; }

        // Columnas que resuelve SEL_GRUPO_TRABAJO
        public string cin_nombre { get; set; }
        public string esp_nombre { get; set; }
        public int integrantes { get; set; }
        public string lider { get; set; }

        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public bool quita_planta { get; set; }
    }
}
