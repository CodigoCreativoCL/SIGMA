using System;

namespace SitioBase.Model
{
    /* =====================================================================
       Modelos del modulo del bodeguero (Sprint 3, bloques 60 y 61).

       Los nombres son los de la columna, como en el resto del proyecto:
       bod_id y no Id. Las columnas que calcula el SP van sin prefijo y en
       minusculas, para que se vea de un vistazo cuales vienen de la tabla y
       cuales las arma la consulta.
       ===================================================================== */

    /// <summary>
    /// Unidad de medida, en lectura. Su mantenedor es HU-040 (Sprint 2).
    /// </summary>
    [Serializable]
    public class UnidadMedida
    {
        public int ume_id { get; set; }
        public int ume_magnitud { get; set; }
        public int? ume_unidad_base { get; set; }
        public string ume_codigo { get; set; }
        public string ume_nombre { get; set; }
        public string ume_simbolo { get; set; }
        public decimal ume_factor { get; set; }
        public decimal ume_offset { get; set; }
        public System.DateTime? ume_fecha_creacion { get; set; }
        public System.DateTime? ume_fecha_actualizacion { get; set; }
        public bool ume_habilitado { get; set; }

        // Calculadas por SEL_UNIDAD_MEDIDA
        public string magnitud_nombre { get; set; }
        public string unidad_base_nombre { get; set; }
        /// <summary>"Kilogramo (kg)". La arma el SP, no la pantalla.</summary>
        public string etiqueta { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        // Filtros / combos (HU-040)
        public string filtro { get; set; }
        public int filtro_magnitud { get; set; }
        public bool? filtro_habilitado { get; set; }
        public bool quita_base { get; set; }
    }


    /// <summary>Magnitud física (tiempo, longitud, temperatura…) para el combo de HU-040.</summary>
    [Serializable]
    public class Magnitud
    {
        public int mag_id { get; set; }
        public string mag_codigo { get; set; }
        public string mag_nombre { get; set; }
        public bool mag_habilitado { get; set; }
    }


    /// <summary>Bodega de una planta (HU-052).</summary>
    [Serializable]
    public class Bodega
    {
        public int bod_id { get; set; }
        public int bod_cliente { get; set; }
        public int bod_cliente_instalacion { get; set; }
        public string bod_codigo { get; set; }
        public string bod_nombre { get; set; }
        public string bod_descripcion { get; set; }
        public bool bod_habilitado { get; set; }

        // Calculadas por SEL_BODEGA
        public string planta_nombre { get; set; }
        public int ubicaciones { get; set; }
        public int repuestos_con_saldo { get; set; }

        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public int filtro_instalacion { get; set; }

        /* Trazabilidad. Los SEL_ la devuelven desde el bloque 68; antes las
           columnas existian, se escribian, y no habia forma de verlas. */
        public DateTime? bod_fecha_creacion { get; set; }
        public DateTime? bod_fecha_actualizacion { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

    }


    /// <summary>Ubicacion dentro de una bodega: "Pasillo A - Estante 3" (HU-052 CA2).</summary>
    [Serializable]
    public class BodegaUbicacion
    {
        public int bub_id { get; set; }
        public int bub_bodega { get; set; }
        public string bub_codigo { get; set; }
        public string bub_nombre { get; set; }
        public bool bub_habilitado { get; set; }

        public string bodega_codigo { get; set; }
        public string bodega_nombre { get; set; }

        /* Trazabilidad. Los SEL_ la devuelven desde el bloque 68; antes las
           columnas existian, se escribian, y no habia forma de verlas. */
        public DateTime? bub_fecha_creacion { get; set; }
        public DateTime? bub_fecha_actualizacion { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }


        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
    }


    /// <summary>Repuesto del maestro (HU-050).</summary>
    [Serializable]
    public class Repuesto
    {
        public int rep_id { get; set; }
        public int rep_cliente { get; set; }
        public int rep_unidad_medida { get; set; }
        public string rep_codigo { get; set; }
        public string rep_nombre { get; set; }
        public string rep_fabricante { get; set; }
        public string rep_modelo { get; set; }
        public string rep_descripcion { get; set; }
        public bool rep_es_reparable { get; set; }
        public bool rep_es_consumible { get; set; }
        public bool rep_controla_lote { get; set; }
        public decimal? rep_costo_referencia { get; set; }
        public int? rep_moneda { get; set; }

        /* Vida util ESPERADA, la que dice el fabricante. Tres medidas y no
           una: un rodamiento dura HORAS de marcha, un filtro de aire dura
           DIAS gire o no gire el equipo, y un contacto de partida dura
           CICLOS sin que le importe el tiempo. Pueden convivir -un aceite
           vence a las 2.000 horas O a los 365 dias, lo que pase primero-.

           La vida util REAL es otra cosa y vive en
           Componente_Repuesto_Instalacion: con que horometro se instalo la
           pieza y con cual se retiro (HU-058). */
        public decimal? rep_vida_util_hora { get; set; }
        public int? rep_vida_util_dia { get; set; }
        public decimal? rep_vida_util_ciclo { get; set; }

        /// <summary>
        /// Le dice al SP que un campo vacio significa BORRAR y no "no lo
        /// toques". Sin esta bandera, ISNULL hace imposible limpiar una
        /// vida util que se cargo mal: se vuelve a ver despues de guardar.
        /// </summary>
        public bool limpia_vida_util { get; set; }

        public bool rep_habilitado { get; set; }

        // Calculadas por SEL_REPUESTO
        public string unidad_nombre { get; set; }
        public string unidad_simbolo { get; set; }
        public string moneda_codigo { get; set; }
        public decimal existencia_total { get; set; }
        public int bodegas_con_saldo { get; set; }

        /* Trazabilidad. Los SEL_ la devuelven desde el bloque 68; antes las
           columnas existian, se escribian, y no habia forma de verlas. */
        public DateTime? rep_fecha_creacion { get; set; }
        public DateTime? rep_fecha_actualizacion { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }


        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
    }


    /// <summary>Umbrales de un repuesto en una bodega (HU-053).</summary>
    [Serializable]
    public class RepuestoBodegaStock
    {
        public int rbs_id { get; set; }
        public int rbs_cliente { get; set; }
        public int rbs_repuesto { get; set; }
        public int rbs_bodega { get; set; }
        public decimal rbs_stock_minimo { get; set; }
        public decimal? rbs_stock_maximo { get; set; }
        public decimal? rbs_punto_reposicion { get; set; }
        public string rbs_observacion { get; set; }
        public bool rbs_habilitado { get; set; }

        public string repuesto_codigo { get; set; }
        public string repuesto_nombre { get; set; }
        public string bodega_codigo { get; set; }
        public string bodega_nombre { get; set; }
        public decimal existencia { get; set; }
        public bool bajo_minimo { get; set; }
        public bool sobre_maximo { get; set; }

        /* Trazabilidad. Los SEL_ la devuelven desde el bloque 68; antes las
           columnas existian, se escribian, y no habia forma de verlas. */
        public DateTime? rbs_fecha_creacion { get; set; }
        public DateTime? rbs_fecha_actualizacion { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

    }


    /// <summary>Existencia de un repuesto en una bodega (HU-056).</summary>
    [Serializable]
    public class InventarioSaldo
    {
        public int isa_id { get; set; }
        public int isa_repuesto { get; set; }
        public int isa_bodega { get; set; }
        public decimal isa_cantidad { get; set; }
        public decimal isa_cantidad_reservada { get; set; }
        public decimal cantidad_disponible { get; set; }
        public decimal? isa_costo_promedio { get; set; }
        public DateTime? isa_fecha_ultimo_movimiento { get; set; }

        public string repuesto_codigo { get; set; }
        public string repuesto_nombre { get; set; }
        public bool rep_controla_lote { get; set; }
        public string unidad_simbolo { get; set; }
        public string bodega_codigo { get; set; }
        public string bodega_nombre { get; set; }
        public string planta_nombre { get; set; }
        public decimal? rbs_stock_minimo { get; set; }
        public decimal? rbs_stock_maximo { get; set; }
        public decimal? rbs_punto_reposicion { get; set; }
        public bool bajo_minimo { get; set; }
        public bool sobre_maximo { get; set; }
        public string ubicacion_codigo { get; set; }

        public string filtro { get; set; }
        public int filtro_instalacion { get; set; }
        public bool filtro_solo_alerta { get; set; }
    }


    /// <summary>
    /// Quien registro movimientos, para el combo de filtro (bloque 69).
    /// </summary>
    [Serializable]
    public class InventarioMovimientoUsuario
    {
        public int usu_id { get; set; }
        public string usuario_nombre { get; set; }
        public int movimientos { get; set; }
        public DateTime? ultimo { get; set; }

        /// <summary>
        /// "Juan Painen (15)". La cuenta al lado del nombre dice de un
        /// vistazo quien maneja la bodega y quien toco el inventario una vez.
        /// </summary>
        public string etiqueta
        {
            get { return usuario_nombre + " (" + movimientos + ")"; }
        }
    }


    /// <summary>Tipo de movimiento, para los combos de filtro (bloque 67).</summary>
    [Serializable]
    public class InventarioMovimientoTipo
    {
        public int imt_id { get; set; }
        public string imt_codigo { get; set; }
        public string imt_nombre { get; set; }
        public int signo { get; set; }
        public string familia { get; set; }
    }


    /// <summary>Un movimiento de inventario (HU-054, HU-055, HU-057).</summary>
    [Serializable]
    public class InventarioMovimiento
    {
        public int imo_id { get; set; }
        public Guid imo_uuid { get; set; }
        public int imo_cliente { get; set; }
        public int imo_repuesto { get; set; }
        public int imo_bodega { get; set; }
        public int? imo_bodega_ubicacion { get; set; }
        public int? imo_repuesto_lote { get; set; }
        public int imo_inventario_movimiento_tipo { get; set; }
        public decimal imo_cantidad { get; set; }
        public decimal? imo_costo_unitario { get; set; }
        public int? imo_moneda { get; set; }
        public DateTime imo_fecha_movimiento_utc { get; set; }
        public int? imo_orden_trabajo { get; set; }
        public int? imo_bodega_destino { get; set; }
        public string imo_observacion { get; set; }

        // Calculadas por SEL_INVENTARIO_MOVIMIENTO
        public string tipo_codigo { get; set; }
        public string tipo_nombre { get; set; }
        public int signo { get; set; }

        /// <summary>INGRESO · CONSUMO · AJUSTE · TRASLADO (HU-057 CA2).</summary>
        public string familia { get; set; }

        public string repuesto_codigo { get; set; }
        public string repuesto_nombre { get; set; }
        public string unidad_simbolo { get; set; }
        public string bodega_codigo { get; set; }
        public string bodega_nombre { get; set; }
        public string bodega_destino_nombre { get; set; }
        public string ubicacion_codigo { get; set; }
        public string lote_codigo { get; set; }
        public string usuario_nombre { get; set; }

        // Solo para la cantidad con signo, que es como se lee en la grilla.
        public decimal cantidad_con_signo { get { return imo_cantidad * signo; } }

        public string filtro { get; set; }
        public int filtro_tipo { get; set; }
        public int filtro_usuario { get; set; }
        public DateTime? filtro_desde { get; set; }
        public DateTime? filtro_hasta { get; set; }
    }


    /// <summary>Lote de un repuesto que los controla (HU-054 CA2).</summary>
    [Serializable]
    public class RepuestoLote
    {
        public int rlo_id { get; set; }
        public int rlo_cliente { get; set; }
        public int rlo_repuesto { get; set; }
        public string rlo_codigo { get; set; }
        public DateTime? rlo_fecha_ingreso { get; set; }
        public DateTime? rlo_fecha_vencimiento { get; set; }
        public int? rlo_proveedor { get; set; }
        public decimal? rlo_costo_unitario { get; set; }
        public string rlo_observacion { get; set; }
        public bool rlo_habilitado { get; set; }

        public string repuesto_codigo { get; set; }
        public bool vencido { get; set; }

        /* Trazabilidad. Los SEL_ la devuelven desde el bloque 68; antes las
           columnas existian, se escribian, y no habia forma de verlas. */
        public DateTime? rlo_fecha_creacion { get; set; }
        public DateTime? rlo_fecha_actualizacion { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }


        public bool filtro_vigentes { get; set; }

        /// <summary>
        /// Lo que se muestra en el combo del ingreso: el codigo y, si vence,
        /// cuando. Un lote sin fecha a la vista obliga a abrir otra pantalla
        /// para saber si sirve.
        /// </summary>
        public string etiqueta
        {
            get
            {
                if (rlo_fecha_vencimiento == null) return rlo_codigo;

                return rlo_codigo + "  ·  vence " +
                       rlo_fecha_vencimiento.Value.ToString("dd-MM-yyyy") +
                       (vencido ? "  (VENCIDO)" : "");
            }
        }
    }
}
