using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un período de cobro emitido (ANEXO F §4.3).
    ///
    /// LOS TRES NÚMEROS CONGELADOS
    ///   spe_valor_uf_plan  cuántas UF costaba el plan
    ///   spe_valor_uf_dia   cuántos pesos valía una UF ese día
    ///   spe_monto_clp      el producto, que es lo que se cobra
    ///
    ///   No hay FK a Valor_Uf a propósito. Abrir este período dentro de dos
    ///   años tiene que mostrar lo que se cobró, no un recálculo con la UF
    ///   de entonces.
    ///
    /// Emitir un período ES facturar. Por eso la pantalla lo pone detrás de
    /// su propio permiso y no detrás del de editar la suscripción.
    /// </summary>
    [Serializable]
    public class SuscripcionPeriodo
    {
        public int spe_id { get; set; }
        public int spe_suscripcion { get; set; }
        public int sus_cliente { get; set; }
        public string cli_nombre { get; set; }
        public int? spe_plan_comercial { get; set; }
        public string plc_nombre { get; set; }
        public int spe_periodicidad_cobro { get; set; }
        public string pcb_nombre { get; set; }
        public DateTime spe_fecha_inicio { get; set; }
        public DateTime spe_fecha_fin { get; set; }
        public decimal spe_valor_uf_plan { get; set; }
        public decimal spe_valor_uf_dia { get; set; }
        public DateTime? spe_fecha_valor_uf { get; set; }
        public decimal spe_monto_clp { get; set; }
        public decimal spe_monto_pagado_clp { get; set; }
        public decimal saldo_clp { get; set; }
        public int spe_estado { get; set; }
        public string spd_nombre { get; set; }
        public bool spe_es_implantacion { get; set; }
        public string spe_observacion { get; set; }
        public bool spe_habilitado { get; set; }

        /// <summary>
        /// Fuerza el valor en UF del período en vez de tomar el precio
        /// vigente del plan. Es lo que permite cobrar una implantación
        /// acordada: sin monto explícito se emite en cero, porque no hay
        /// precio de implantación definido en el modelo comercial.
        /// </summary>
        public decimal? valor_uf_manual { get; set; }

        public int? filtro_suscripcion { get; set; }
        public int? filtro_cliente { get; set; }
        public int? filtro_estado { get; set; }
        public bool filtro_solo_impagos { get; set; }
    }
}
