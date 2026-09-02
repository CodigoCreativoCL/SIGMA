using System;

namespace SitioBase.Model
{
    /// <summary>
    /// En que equipos aplica un repuesto (HU-051, bloque 92).
    ///
    /// UNA FILA, UN ALCANCE
    ///   Las tres columnas de alcance —tipo, modelo, componente— son
    ///   anulables y solo UNA viene informada. Una fila con dos no se puede
    ///   leer: "aplica a las bombas Y al modelo GM10S" admite dos lecturas
    ///   distintas —las bombas mas ese modelo, o las bombas que sean ese
    ///   modelo— y dan resultados diferentes. Si aplica a varios, son varias
    ///   filas.
    ///
    /// NO TIENE CLIENTE PROPIO
    ///   La pertenencia sale del repuesto: rco_repuesto -> Repuesto.rep_cliente.
    ///   Por eso el Controller nunca consulta esta tabla sin pasar por ahi.
    /// </summary>
    [Serializable]
    public class RepuestoCompatibilidad
    {
        public int rco_id { get; set; }
        public int rco_repuesto { get; set; }
        public int? rco_activo_tipo { get; set; }
        public int? rco_activo_modelo { get; set; }
        public int? rco_activo_componente { get; set; }
        public string rco_observacion { get; set; }

        public int rco_usuario_creacion { get; set; }
        public DateTime? rco_fecha_creacion { get; set; }
        public int? rco_usuario_actualizacion { get; set; }
        public DateTime? rco_fecha_actualizacion { get; set; }

        // Columnas que arma el SEL_
        public string repuesto_codigo { get; set; }
        public string repuesto_nombre { get; set; }
        public string unidad { get; set; }

        /// <summary>"TIPO", "MODELO" o "COMPONENTE": cual de los tres viene.</summary>
        public string alcance { get; set; }

        /// <summary>Como se llama ese tipo, modelo o componente.</summary>
        public string alcance_nombre { get; set; }

        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        // Filtros que el Controller convierte en parametros del SEL_
        public string filtro { get; set; }
        public int filtro_repuesto { get; set; }
        public int filtro_tipo { get; set; }
        public int filtro_modelo { get; set; }
        public int filtro_componente { get; set; }

        /// <summary>
        /// Como se rotula el alcance en pantalla. El nombre solo no basta:
        /// "Bomba centrifuga" puede ser un tipo o un modelo, y la diferencia
        /// importa —un tipo cubre todas las bombas, un modelo solo una—.
        /// </summary>
        public string alcance_etiqueta
        {
            get
            {
                if (alcance == "COMPONENTE") return "Componente";
                if (alcance == "MODELO") return "Modelo";
                return "Tipo de activo";
            }
        }

        /// <summary>
        /// El icono de cada alcance, de mas general a mas especifico.
        /// </summary>
        public string alcance_icono
        {
            get
            {
                if (alcance == "COMPONENTE") return "mdi mdi-cog-outline";
                if (alcance == "MODELO") return "mdi mdi-tag-outline";
                return "mdi mdi-shape-outline";
            }
        }
    }
}
