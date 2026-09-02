using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un modelo de activo (HU-031): "WEG W22 132S", "Grundfos NB 65-200"… No
    /// tiene código; se identifica por fabricante + nombre dentro de un tipo de
    /// activo. amo_cliente NULL = modelo GLOBAL de la plataforma (se ve pero no
    /// se edita desde la pantalla del cliente). Las calculadas las devuelve
    /// SEL_ACTIVO_MODELO por JOIN.
    /// </summary>
    [Serializable]
    public class ActivoModelo
    {
        public int amo_id { get; set; }
        public int? amo_cliente { get; set; }
        public int amo_activo_tipo { get; set; }
        public string amo_fabricante { get; set; }
        public string amo_nombre { get; set; }
        public string amo_descripcion { get; set; }
        public DateTime? amo_fecha_creacion { get; set; }
        public DateTime? amo_fecha_actualizacion { get; set; }
        public bool amo_habilitado { get; set; }

        // Calculadas por SEL_ACTIVO_MODELO
        public bool es_global { get; set; }
        public string tipo_nombre { get; set; }
        public string etiqueta { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        // Filtros
        public string filtro { get; set; }
        public int filtro_cliente { get; set; }
        public int filtro_activo_tipo { get; set; }
        public bool? filtro_habilitado { get; set; }
    }
}
