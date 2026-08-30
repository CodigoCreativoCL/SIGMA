using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un pago DECLARADO sobre un período (ANEXO F §5.3 y §5.4).
    ///
    /// Declarar no es pagar. La fila nace en estado DECLARADO y solo se
    /// vuelve real cuando alguien la coteja contra la cartola: ahí recién
    /// se recalcula lo pagado del período y, si quedó cubierto, se extiende
    /// la vigencia de la suscripción. Todo eso lo hace
    /// UPD_SUSCRIPCION_PAGO_VERIFICAR en una sola transacción, porque a
    /// medias dejaría la cuenta descuadrada.
    ///
    /// spa_archivo es obligatorio: un abono sin comprobante no se puede
    /// verificar contra nada, y verificar es lo que convierte una
    /// declaración en un pago.
    /// </summary>
    [Serializable]
    public class SuscripcionPago
    {
        public int spa_id { get; set; }
        public int spa_periodo { get; set; }
        public int sus_cliente { get; set; }
        public string cli_nombre { get; set; }
        public decimal spa_monto_declarado_clp { get; set; }
        public decimal? spa_monto_verificado_clp { get; set; }
        public DateTime spa_fecha_transferencia { get; set; }
        public string spa_banco { get; set; }
        public string spa_numero_operacion { get; set; }
        public int spa_archivo { get; set; }
        public int spa_estado { get; set; }
        public string spo_nombre { get; set; }
        public string spo_codigo { get; set; }
        public string spa_motivo_rechazo { get; set; }
        public DateTime? spa_fecha_verificacion_utc { get; set; }
        public string verificado_por { get; set; }

        // Del período al que pertenece, para no tener que ir a buscarlo
        public decimal spe_monto_clp { get; set; }
        public DateTime? spe_fecha_inicio { get; set; }
        public DateTime? spe_fecha_fin { get; set; }

        // Verificación
        public bool verificado { get; set; }
        public decimal? monto_verificado { get; set; }
        public string motivo_rechazo { get; set; }

        public int? filtro_periodo { get; set; }
        public int? filtro_cliente { get; set; }
        public bool filtro_solo_pendientes { get; set; }
    }
}
