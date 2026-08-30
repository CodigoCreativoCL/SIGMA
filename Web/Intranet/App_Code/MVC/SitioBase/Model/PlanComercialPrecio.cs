using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un precio de un plan para una periodicidad (ANEXO F §3.3).
    ///
    /// EL PRECIO ES VERSIONADO, NO EDITABLE
    ///   Cada fila cubre un tramo de fechas. Cambiar el precio no modifica
    ///   esta fila: cierra su vigencia y abre otra. Así, una cotización de
    ///   la semana pasada sigue diciendo lo mismo y un período emitido en
    ///   marzo se puede explicar con el precio que regía en marzo.
    ///
    /// estado tiene tres valores y no un sí/no, porque un precio cargado
    /// para el próximo mes no es lo mismo que uno que ya caducó, y en una
    /// lista ordenada por fecha los dos se ven igual de "no vigente":
    ///
    ///   PROGRAMADO  empieza después de hoy
    ///   VIGENTE     es el que se cobra
    ///   HISTÓRICO   ya terminó
    ///   RETIRADO    se dio de baja
    /// </summary>
    [Serializable]
    public class PlanComercialPrecio
    {
        public int pcp_id { get; set; }
        public int pcp_plan_comercial { get; set; }
        public string plc_codigo { get; set; }
        public string plc_nombre { get; set; }
        public int pcp_periodicidad_cobro { get; set; }
        public string pcb_codigo { get; set; }
        public string pcb_nombre { get; set; }
        public decimal pcp_valor_uf { get; set; }
        public decimal? pcp_descuento_porcentaje { get; set; }
        public DateTime pcp_vigencia_desde { get; set; }
        public DateTime? pcp_vigencia_hasta { get; set; }
        public bool pcp_habilitado { get; set; }
        public decimal monto_clp_referencial { get; set; }
        public string estado { get; set; }

        /// <summary>
        /// Desde cuándo rige el precio nuevo. Vacío = hoy. Se acepta futuro
        /// -una lista acordada para el próximo mes entra sola- pero nunca
        /// pasado: reescribir hacia atrás es lo que el versionado impide.
        /// </summary>
        public DateTime? vigencia_desde { get; set; }

        public int? filtro_plan { get; set; }
        public int? filtro_periodicidad { get; set; }
        public bool filtro_solo_vigentes { get; set; }
    }
}
