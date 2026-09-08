using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un paso de un procedimiento (HU-062): el detalle "paso a paso" de la
    /// receta. Cuelga de un Procedimiento (ppa_procedimiento) y no tiene cliente
    /// propio —el cliente y "es global" salen del procedimiento padre—. El
    /// (procedimiento, orden) es único. Un paso puede ser punto de control,
    /// exigir evidencia y/o exigir una medición (con su variable). Las
    /// calculadas las devuelve SEL_PROCEDIMIENTO_PASO por JOIN.
    /// </summary>
    [Serializable]
    public class ProcedimientoPaso
    {
        public int ppa_id { get; set; }
        public int ppa_procedimiento { get; set; }
        public int ppa_orden { get; set; }
        public string ppa_nombre { get; set; }
        public string ppa_instruccion { get; set; }
        public bool ppa_es_punto_control { get; set; }
        public bool ppa_requiere_evidencia { get; set; }
        public bool ppa_requiere_medicion { get; set; }
        public int? ppa_variable_medicion { get; set; }
        public int? ppa_duracion_estimada_minuto { get; set; }
        public bool ppa_habilitado { get; set; }
        public DateTime? ppa_fecha_creacion { get; set; }
        public DateTime? ppa_fecha_actualizacion { get; set; }

        // Calculadas por SEL_PROCEDIMIENTO_PASO
        public bool es_global { get; set; }
        public string procedimiento_codigo { get; set; }
        public string procedimiento_nombre { get; set; }
        public int procedimiento_version { get; set; }
        public string variable_nombre { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        // Para quitar la variable en la edición (bandera del UPD).
        public bool quita_variable { get; set; }

        // Filtros
        public string filtro { get; set; }
        public int filtro_cliente { get; set; }
        public int filtro_procedimiento { get; set; }
        public bool? filtro_habilitado { get; set; }
    }
}
