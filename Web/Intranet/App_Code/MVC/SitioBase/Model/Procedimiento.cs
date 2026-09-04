using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un procedimiento reutilizable (HU-061): la "receta" de un trabajo, que
    /// se escribe una vez y se reutiliza en planes y órdenes. El código NO es
    /// automático: la llave es (cliente, código, VERSIÓN), así que varias filas
    /// comparten código —una por versión— para no falsear lo ya ejecutado.
    /// prc_cliente NULL = procedimiento global del sistema (se ve, no se edita).
    /// Las calculadas las devuelve SEL_PROCEDIMIENTO por JOIN.
    /// </summary>
    [Serializable]
    public class Procedimiento
    {
        public int prc_id { get; set; }
        public int? prc_cliente { get; set; }
        public string prc_codigo { get; set; }
        public string prc_nombre { get; set; }
        public int prc_version { get; set; }
        public int? prc_activo_tipo { get; set; }
        public string prc_descripcion { get; set; }
        public int? prc_duracion_estimada_minuto { get; set; }
        public bool prc_requiere_permiso { get; set; }
        public int? prc_permiso_trabajo_tipo { get; set; }
        public DateTime? prc_fecha_creacion { get; set; }
        public DateTime? prc_fecha_actualizacion { get; set; }
        public bool prc_habilitado { get; set; }

        // Calculadas por SEL_PROCEDIMIENTO
        public bool es_global { get; set; }
        public bool es_ultima { get; set; }
        public int pasos { get; set; }
        public string activo_tipo_nombre { get; set; }
        public string permiso_tipo_nombre { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        // Para desasociar el tipo de activo en la edición (bandera del UPD).
        public bool quita_tipo { get; set; }

        // Filtros
        public string filtro { get; set; }
        public int filtro_cliente { get; set; }
        public int filtro_activo_tipo { get; set; }
        public bool? filtro_habilitado { get; set; }
        public bool filtro_solo_ultima { get; set; }
    }
}
