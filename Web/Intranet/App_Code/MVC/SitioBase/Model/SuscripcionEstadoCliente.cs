using System;

namespace SitioBase.Model
{
    /// <summary>
    /// El estado de la suscripción de un cliente, tal como lo resuelve
    /// `SEL_SUSCRIPCION_ESTADO_CLIENTE` (ANEXO F §6.1).
    ///
    /// `VENCIDA` y `EN GRACIA` **no se guardan en ninguna parte**: se
    /// calculan cada vez a partir de la fecha. Un estado que cambia solo
    /// porque pasó el tiempo no puede depender de que un job haya corrido
    /// anoche; si dependiera, el día que no corra habría clientes vencidos
    /// operando o clientes al día bloqueados.
    /// </summary>
    [Serializable]
    public class SuscripcionEstadoCliente
    {
        public int cliente { get; set; }
        public int suscripcion { get; set; }
        public int? plan_comercial { get; set; }

        /// <summary>
        /// VIGENTE · EN GRACIA · VENCIDA · SUSPENDIDA · CANCELADA ·
        /// SIN SUSCRIPCION
        /// </summary>
        public string estado { get; set; }

        public DateTime? fecha_fin { get; set; }
        public int? dias_restantes { get; set; }

        /// <summary>Si puede seguir trabajando con normalidad.</summary>
        public bool puede_operar { get; set; }

        /// <summary>
        /// Si corresponde mostrar el aviso. Lo decide el SP y no la página,
        /// porque cuántos días antes se avisa es un parámetro del negocio
        /// (`SUSCRIPCION_DIAS_AVISO`), no una constante del código.
        /// </summary>
        public bool avisar { get; set; }

        /// <summary>
        /// Un cliente que todavía se está configurando, antes de cerrar el
        /// trato comercial. No se le restringe nada: no hay plan que hacer
        /// cumplir.
        /// </summary>
        public bool SinSuscripcion
        {
            get { return estado == "SIN SUSCRIPCION"; }
        }
    }
}
