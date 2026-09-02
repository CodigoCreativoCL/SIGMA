using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un modelo de activo: "WEG W22 132S" (bloque 93).
    ///
    /// CON CLIENTE NULL ES GLOBAL
    ///   Un modelo del sistema sirve para todas las empresas: no tiene
    ///   sentido cargar "WEG W22 132S" una vez por cliente. Los combos
    ///   muestran los globales y los propios juntos, y `es_global` permite
    ///   distinguirlos —el usuario no puede editar los globales—.
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
        public bool amo_habilitado { get; set; }

        public bool es_global { get; set; }
        public string tipo_nombre { get; set; }

        /// <summary>
        /// "WEG W22 132S". El fabricante va delante porque "W22 132S" solo
        /// no le dice nada a nadie.
        /// </summary>
        public string etiqueta { get; set; }

        public int filtro_activo_tipo { get; set; }
        public bool? filtro_habilitado { get; set; }
        public string filtro { get; set; }
    }


    /// <summary>
    /// Un componente concreto de una maquina concreta (bloque 93).
    ///
    /// NO HAY COMPONENTES GLOBALES: siempre pertenecen a un cliente, porque
    /// son una pieza de un activo suyo.
    /// </summary>
    [Serializable]
    public class ActivoComponente
    {
        public int aco_id { get; set; }
        public int aco_cliente { get; set; }
        public int aco_activo { get; set; }
        public string aco_codigo { get; set; }
        public string aco_nombre { get; set; }
        public string aco_descripcion { get; set; }
        public bool aco_habilitado { get; set; }

        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string tipo_nombre { get; set; }

        /// <summary>
        /// "MOT-001 · Rodamiento lado acople". El activo va delante porque el
        /// nombre del componente se repite en veinte maquinas y sin la
        /// maquina no se puede elegir cual.
        /// </summary>
        public string etiqueta { get; set; }

        public int filtro_activo { get; set; }
        public bool? filtro_habilitado { get; set; }
        public string filtro { get; set; }
    }
}
