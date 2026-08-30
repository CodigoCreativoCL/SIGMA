using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Una funcionalidad dentro de un plan: qué incluye y hasta cuánto
    /// (ANEXO F).
    ///
    /// DOS NATURALEZAS, MARCADAS POR pcf_tipo
    ///   1 INCLUSION  se tiene o no. Son 21 de las 25.
    ///   2 LIMITE     se tiene con un tope. Son 4: plantas, usuarios,
    ///                activos y almacenamiento.
    ///
    ///   Un tope nulo con la funcionalidad incluida significa SIN TOPE, que
    ///   es como está cargado el plan FULL. No es lo mismo que negarla.
    ///
    /// SIN FILA, NEGADA
    ///   FNC_CLIENTE_TIENE_FUNCIONALIDAD devuelve 0 por defecto. La ausencia
    ///   es negación, no "sin definir": por eso SEL_PLAN_FUNCIONALIDAD
    ///   devuelve las 25 aunque no tengan fila, y esas llegan con
    ///   origen = SIN DEFINIR.
    ///
    /// LA EXCEPCIÓN POR CLIENTE
    ///   pcf_cliente en nulo es la regla del plan, para todos. Con un
    ///   cliente es una excepción solo para él, y la excepción gana. Sirve
    ///   para el cliente que negoció dos plantas extra sin cambiar de plan;
    ///   sin esto habría que crearle un plan a medida a cada uno.
    /// </summary>
    [Serializable]
    public class PlanFuncionalidad
    {
        public int fun_id { get; set; }
        public string fun_codigo { get; set; }
        public string fun_nombre { get; set; }
        public int fun_orden { get; set; }

        public int pcf_tipo { get; set; }
        public string fnt_codigo { get; set; }

        /// <summary>Cero cuando la funcionalidad no tiene fila en el plan.</summary>
        public int pcf_id { get; set; }

        public bool pcf_incluida { get; set; }
        public decimal? pcf_limite { get; set; }
        public int? pcf_cliente { get; set; }

        /// <summary>
        /// La concesión que caduca sola. "Le damos predictivo hasta fin de
        /// mes" se escribe con una fecha, no con un recordatorio en la
        /// agenda de alguien.
        /// </summary>
        public DateTime? pcf_vigencia_hasta { get; set; }

        public string pcf_observacion { get; set; }

        /// <summary>PLAN · EXCEPCIÓN · SIN DEFINIR.</summary>
        public string origen { get; set; }

        public bool caducada { get; set; }

        public bool EsLimite { get { return pcf_tipo == 2; } }
    }
}
