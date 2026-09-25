using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un servicio contratado a un proveedor, con el total de su moneda y
    /// las órdenes en que el proveedor participó (HU-065, bloques 108 y 236).
    ///
    /// LOS TOTALES VIENEN EN CADA FILA
    ///   El SP los calcula por ventana (proveedor + moneda) sobre las filas
    ///   que pasaron el filtro de fechas, así que todas las filas de la misma
    ///   moneda traen el mismo `total_moneda`. La pantalla lo pinta una vez
    ///   por moneda: 730.000 CLP y 12,5 UF, nunca sumados.
    ///
    /// SIN MONEDA ES UN GRUPO MAS
    ///   `ots_moneda` es nullable. Un servicio sin moneda declarada cae en
    ///   `moneda_grupo` = 0, rotulado "SIN MONEDA", y no se mezcla con los
    ///   pesos: sumarlo sería inventar la moneda que nadie escribió.
    /// </summary>
    [Serializable]
    public class ProveedorHistorial
    {
        public int ots_id { get; set; }
        public int ots_orden_trabajo { get; set; }
        public int ots_proveedor { get; set; }
        public int ots_servicio_tipo { get; set; }
        public string ots_descripcion { get; set; }
        public decimal? ots_cantidad { get; set; }
        public decimal? ots_monto_unitario { get; set; }
        public decimal ots_monto { get; set; }
        public int? ots_moneda { get; set; }
        public string ots_documento_referencia { get; set; }
        public DateTime? ots_fecha_servicio_utc { get; set; }
        public DateTime? ots_fecha_documento { get; set; }

        public string prv_rut { get; set; }
        public string prv_razon_social { get; set; }
        public string proveedor_fantasia { get; set; }
        public string servicio_tipo_nombre { get; set; }
        public int otr_correlativo { get; set; }
        public string orden_titulo { get; set; }
        public string orden_estado { get; set; }

        public string moneda_codigo { get; set; }
        public string moneda_nombre { get; set; }
        public int moneda_grupo { get; set; }

        /// <summary>La primera fecha que exista: servicio, documento o creación.</summary>
        public DateTime fecha_efectiva { get; set; }

        public decimal total_moneda { get; set; }
        public int servicios_moneda { get; set; }
        public int ordenes_proveedor { get; set; }

        // ---- filtros de la pantalla ----
        public int filtro_proveedor { get; set; }
        public int filtro_servicio_tipo { get; set; }
        public DateTime? filtro_desde { get; set; }
        public DateTime? filtro_hasta { get; set; }
        public string filtro { get; set; }
    }
}
