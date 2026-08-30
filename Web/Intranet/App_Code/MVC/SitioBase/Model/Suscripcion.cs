using System;

namespace SitioBase.Model
{
    /// <summary>
    /// La suscripción de un cliente (ANEXO F §5). Una por cliente, para
    /// siempre: no se crea una nueva al renovar, se le emite otro período.
    ///
    /// DOS ESTADOS QUE NO SON EL MISMO
    ///   sus_suscripcion_estado / sue_nombre es el estado GUARDADO: lo que
    ///   alguien decidió (activa, suspendida, cancelada).
    ///
    ///   estado / dias_restantes / puede_operar vienen de
    ///   FNC_SUSCRIPCION_VIGENTE y son CALCULADOS al momento de consultar.
    ///   VENCIDA y EN GRACIA viven acá y en ninguna columna, porque
    ///   dependen solo del paso del tiempo (§6.1). Guardarlos obligaría a
    ///   que un job corriera todas las noches para que fueran ciertos.
    ///
    ///   Para decidir si alguien entra, se mira puede_operar. Para saber
    ///   qué se decidió sobre el cliente, sue_nombre.
    ///
    /// LA CLAVE
    ///   sus_key_prefijo es lo único visible de la clave de suscripción; el
    ///   resto solo existe como hash. key_texto es de ida: se llena al
    ///   crear para poder mostrarla una vez y nunca se lee de vuelta.
    /// </summary>
    [Serializable]
    public class Suscripcion
    {
        public int sus_id { get; set; }
        public int sus_cliente { get; set; }
        public string cli_nombre { get; set; }
        public string sus_key_prefijo { get; set; }
        public int sus_suscripcion_estado { get; set; }
        public string sue_nombre { get; set; }
        public int? sus_plan_comercial { get; set; }
        public string plc_codigo { get; set; }
        public string plc_nombre { get; set; }
        public DateTime? sus_fecha_inicio { get; set; }
        public DateTime? sus_fecha_fin { get; set; }
        public int sus_dias_gracia { get; set; }
        public string sus_contacto_nombre { get; set; }
        public string sus_contacto_email { get; set; }
        public string sus_contacto_telefono { get; set; }
        public string sus_observacion { get; set; }
        public bool sus_habilitado { get; set; }

        // Calculadas por FNC_SUSCRIPCION_VIGENTE
        public string estado { get; set; }
        public int? dias_restantes { get; set; }
        public bool puede_operar { get; set; }

        /// <summary>
        /// La clave en claro. Solo viaja hacia la base al crear, y vuelve
        /// una única vez para mostrarla. Nunca se persiste acá.
        /// </summary>
        public string key_texto { get; set; }

        public int? filtro_cliente { get; set; }
    }
}
