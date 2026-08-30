using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un plan comercial con UNO de sus precios (ANEXO F §3).
    ///
    /// Ojo con la granularidad: SEL_PLAN_COMERCIAL no devuelve un plan por
    /// fila, devuelve una fila POR PLAN Y PERIODICIDAD. El plan BÁSICO
    /// aparece tres veces -mensual, trimestral y anual- porque el precio es
    /// lo que cambia. Un combo de planes tiene que agrupar; una tabla de
    /// precios no.
    ///
    /// monto_clp_referencial es lo que costaría HOY. No es lo que se va a
    /// cobrar: eso se congela recién al emitir el período (§4.3), y por eso
    /// el nombre lleva "referencial" y no "monto".
    /// </summary>
    [Serializable]
    public class PlanComercial
    {
        public int plc_id { get; set; }
        public string plc_codigo { get; set; }
        public string plc_nombre { get; set; }
        public string plc_descripcion { get; set; }
        public int plc_dias_gracia { get; set; }
        public bool plc_publico { get; set; }
        public int plc_orden { get; set; }
        public bool plc_habilitado { get; set; }

        // La periodicidad de esta fila
        public int pcb_id { get; set; }
        public string pcb_codigo { get; set; }
        public string pcb_nombre { get; set; }

        // El precio vigente para esa periodicidad
        public int pcp_id { get; set; }
        public decimal pcp_valor_uf { get; set; }
        public decimal? pcp_descuento_porcentaje { get; set; }
        public decimal monto_clp_referencial { get; set; }
        public decimal? valor_uf_dia { get; set; }

        public int? filtro_periodicidad { get; set; }
        public DateTime? filtro_fecha { get; set; }
        public bool filtro_solo_publicos { get; set; }
        public bool? filtro_habilitado { get; set; }
    }
}
