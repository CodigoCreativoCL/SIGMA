using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Posicion funcional: el lugar fijo dentro de un area por el que pasan
    /// los equipos (HU-033). El QR pegado en la sala codifica la posicion,
    /// no la maquina, para que siga sirviendo cuando el equipo cambia.
    /// </summary>
    [Serializable]
    public class ActivoPosicion
    {
        public int apo_id { get; set; }
        public int apo_cliente { get; set; }
        public int apo_cliente_instalacion { get; set; }
        public int apo_instalacion_area { get; set; }
        public int? apo_activo_tipo { get; set; }
        public string apo_codigo { get; set; }
        public string apo_nombre { get; set; }
        public bool apo_critica { get; set; }
        public string apo_descripcion { get; set; }
        public int apo_usuario_creacion { get; set; }
        public DateTime? apo_fecha_creacion { get; set; }
        public int? apo_usuario_actualizacion { get; set; }
        public DateTime? apo_fecha_actualizacion { get; set; }
        public bool apo_habilitado { get; set; }

        // Columnas calculadas por SEL_ACTIVO_POSICION
        public string planta_nombre { get; set; }
        public string area_codigo { get; set; }
        public string area_nombre { get; set; }
        public string tipo_nombre { get; set; }
        /// <summary>El equipo que la ocupa hoy; null si esta libre.</summary>
        public int? activo_id { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public DateTime? ocupada_desde_utc { get; set; }
        /// <summary>La misma fecha en hora de Santiago, para mostrar.</summary>
        public DateTime? ocupada_desde { get; set; }
        public int periodos { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public bool? filtro_libre { get; set; }
        public int filtro_cliente_instalacion { get; set; }
        public int filtro_instalacion_area { get; set; }
        public int filtro_activo_tipo { get; set; }
        public bool quita_tipo { get; set; }
    }

    /// <summary>
    /// Un periodo de ocupacion: que equipo estuvo en la posicion, desde
    /// cuando y hasta cuando (HU-033 #2). El vigente no tiene fin.
    /// </summary>
    [Serializable]
    public class ActivoPosicionHistorial
    {
        public int aph_id { get; set; }
        public int aph_activo_posicion { get; set; }
        public int aph_activo { get; set; }
        public DateTime aph_fecha_inicio_utc { get; set; }
        public DateTime? aph_fecha_fin_utc { get; set; }
        /// <summary>Inicio y fin en hora de Santiago, para mostrar.</summary>
        public DateTime aph_fecha_inicio { get; set; }
        public DateTime? aph_fecha_fin { get; set; }
        public int? aph_activo_posicion_motivo { get; set; }
        public int? aph_orden_trabajo { get; set; }
        public string aph_observacion { get; set; }
        public int aph_usuario_creacion { get; set; }
        public DateTime? aph_fecha_creacion { get; set; }

        public string posicion_codigo { get; set; }
        public string posicion_nombre { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string motivo_nombre { get; set; }
        public int? ot_correlativo { get; set; }
        public string usuario_nombre { get; set; }
        public bool vigente { get; set; }
        public int dias { get; set; }
    }

    [Serializable]
    public class ActivoPosicionMotivo
    {
        public int apm_id { get; set; }
        public string apm_codigo { get; set; }
        public string apm_nombre { get; set; }
        public int apm_orden { get; set; }
        public bool apm_habilitado { get; set; }
    }
}
