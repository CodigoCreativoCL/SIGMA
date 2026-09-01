using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Medidor de un activo: horómetro, odómetro, contador de ciclos… (HU-042).
    ///
    /// El código es único DENTRO DEL ACTIVO, no del cliente: dos activos
    /// distintos pueden tener cada uno su "HOROMETRO". Las propiedades
    /// calculadas (código/nombre del activo, unidad con símbolo, nombres de
    /// usuario) las devuelve SEL_ACTIVO_MEDIDOR con sus JOIN.
    /// </summary>
    [Serializable]
    public class ActivoMedidor
    {
        public int ame_id { get; set; }
        public int ame_cliente { get; set; }
        public int ame_activo { get; set; }
        public int? ame_activo_componente { get; set; }
        public int ame_unidad_medida { get; set; }
        public string ame_codigo { get; set; }
        public string ame_nombre { get; set; }
        public decimal ame_valor_actual { get; set; }
        public DateTime? ame_fecha_valor_actual_utc { get; set; }
        public decimal? ame_valor_reinicio { get; set; }
        public bool ame_permite_reinicio { get; set; }
        public int ame_usuario_creacion { get; set; }
        public DateTime? ame_fecha_creacion { get; set; }
        public int ame_usuario_actualizacion { get; set; }
        public DateTime? ame_fecha_actualizacion { get; set; }
        public bool ame_habilitado { get; set; }

        // Calculadas por SEL_ACTIVO_MEDIDOR
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string unidad_nombre { get; set; }
        public string unidad_simbolo { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        // Filtros del listado / combos
        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public int filtro_activo { get; set; }
    }
}
