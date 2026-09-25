using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Una instalación de un repuesto en un componente, con lo que duró
    /// (HU-058, bloques 108 y 236).
    ///
    /// ES LECTURA, NO MANTENEDOR
    ///   Nadie "crea" una vida útil: la fila de Componente_Repuesto_Instalacion
    ///   nace cuando un técnico instala o retira la pieza en una orden de
    ///   trabajo. Esto es cómo se lee, y por eso no lleva INS_/UPD_/DEL_.
    ///
    /// DOS MEDIDAS, Y LA DE HORAS PUEDE NO EXISTIR
    ///   Los días siempre se pueden contar (la fecha de instalación es
    ///   obligatoria). Las horas dependen de que alguien haya anotado el
    ///   horómetro al poner y al sacar la pieza; si falta cualquiera de las
    ///   dos lecturas, `vida_util_horas` es null y `tiene_horas` es false. No
    ///   es cero: cero sería "duró nada".
    ///
    /// EL PROMEDIO VIENE EN CADA FILA
    ///   El SP lo calcula por ventana sobre las instalaciones CERRADAS del
    ///   mismo repuesto, así que todas las filas de un repuesto traen el
    ///   mismo promedio/mínimo/máximo. La pantalla lo pinta una vez por
    ///   repuesto.
    /// </summary>
    [Serializable]
    public class RepuestoVidaUtil
    {
        public int cri_id { get; set; }
        public int cri_repuesto { get; set; }
        public int cri_activo_componente { get; set; }
        public int? cri_activo_medidor { get; set; }
        public decimal cri_cantidad { get; set; }
        public DateTime cri_fecha_instalacion_utc { get; set; }
        public DateTime? cri_fecha_retiro_utc { get; set; }
        public decimal? cri_lectura_inicial { get; set; }
        public decimal? cri_lectura_final { get; set; }
        public bool cri_fallo { get; set; }
        public string cri_observacion { get; set; }

        /// <summary>Las mismas fechas, en hora de Santiago, para mostrar.</summary>
        public DateTime fecha_instalacion { get; set; }
        public DateTime? fecha_retiro { get; set; }

        public string rep_codigo { get; set; }
        public string rep_nombre { get; set; }

        /// <summary>La vida útil ESPERADA del repuesto (bloque 63), para compararla.</summary>
        public decimal? esperada_horas { get; set; }
        public int? esperada_dias { get; set; }

        public string componente_codigo { get; set; }
        public string componente_nombre { get; set; }
        public int activo_id { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string medidor_nombre { get; set; }
        public string medidor_unidad { get; set; }
        public string motivo_retiro { get; set; }
        public string estado_final { get; set; }
        public string tecnico_nombre { get; set; }
        public int? ot_instalacion { get; set; }
        public int? ot_retiro { get; set; }

        public decimal? vida_util_horas { get; set; }
        public int vida_util_dias { get; set; }
        public bool tiene_horas { get; set; }
        public bool instalada { get; set; }

        public decimal? promedio_horas { get; set; }
        public decimal? minimo_horas { get; set; }
        public decimal? maximo_horas { get; set; }
        public int? promedio_dias { get; set; }
        public int? minimo_dias { get; set; }
        public int? maximo_dias { get; set; }
        public int instalaciones_cerradas { get; set; }
        public int instalaciones_total { get; set; }

        // ---- filtros de la pantalla ----
        public int filtro_repuesto { get; set; }
        public int filtro_activo { get; set; }
        public bool? filtro_solo_retirados { get; set; }
        public string filtro { get; set; }
    }
}
