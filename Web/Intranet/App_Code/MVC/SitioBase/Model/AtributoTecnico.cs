using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un atributo técnico de un tipo de activo (HU-032): "Potencia" (decimal,
    /// kW), "Voltaje" (entero, V)… El código es automático (ATR-&lt;id&gt;).
    /// ate_cliente NULL = atributo GLOBAL de la plataforma (se ve, no se edita
    /// desde el cliente); ate_activo_tipo NULL = aplica a todos los tipos. Las
    /// calculadas las devuelve SEL_ATRIBUTO_TECNICO por JOIN.
    /// </summary>
    [Serializable]
    public class AtributoTecnico
    {
        public int ate_id { get; set; }
        public int? ate_cliente { get; set; }
        public int? ate_activo_tipo { get; set; }
        public int ate_tipo_dato { get; set; }
        public int? ate_unidad_medida { get; set; }
        public string ate_codigo { get; set; }
        public string ate_nombre { get; set; }
        public int? ate_orden { get; set; }
        public DateTime? ate_fecha_creacion { get; set; }
        public DateTime? ate_fecha_actualizacion { get; set; }
        public bool ate_habilitado { get; set; }

        // Calculadas por SEL_ATRIBUTO_TECNICO
        public bool es_global { get; set; }
        public string tipo_nombre { get; set; }
        public string tipo_dato_nombre { get; set; }
        public string unidad_nombre { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        // Filtros
        public string filtro { get; set; }
        public int filtro_cliente { get; set; }
        public int filtro_activo_tipo { get; set; }
        public bool? filtro_habilitado { get; set; }
    }


    /// <summary>Tipo de dato de un atributo (Texto, Entero, Decimal…). Catálogo global.</summary>
    [Serializable]
    public class TipoDato
    {
        public int tda_id { get; set; }
        public string tda_codigo { get; set; }
        public string tda_nombre { get; set; }
        public bool tda_habilitado { get; set; }

        public bool? filtro_habilitado { get; set; }
    }
}
