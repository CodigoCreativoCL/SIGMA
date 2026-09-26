using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Una fila del calendario de mantenimiento (HU-085): a un equipo le
    /// toca un hito en una fecha. Solo lectura desde la web; quien la crea
    /// es el generador (HU-076) y quien la cierra es la orden de trabajo.
    /// </summary>
    [Serializable]
    public class PlanOcurrencia
    {
        public int pmo_id { get; set; }
        public Guid pmo_uuid { get; set; }
        public DateTime fecha_programada { get; set; }
        public DateTime? fecha_limite { get; set; }
        public DateTime? fecha_disponible { get; set; }
        public DateTime? fecha_original { get; set; }
        public string mes { get; set; }

        public int plan_id { get; set; }
        public string plan_codigo { get; set; }
        public string plan_nombre { get; set; }
        public int? version_numero { get; set; }

        public int hito_id { get; set; }
        public string hito_codigo { get; set; }
        public string hito_nombre { get; set; }
        public bool es_overhaul { get; set; }
        public bool requiere_parada { get; set; }
        public int? duracion_estimada_minuto { get; set; }

        public int activo_id { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string planta_nombre { get; set; }
        public string componente_nombre { get; set; }
        public decimal? valor_medidor_objetivo { get; set; }

        public int estado_id { get; set; }
        public string estado_codigo { get; set; }
        public string estado_nombre { get; set; }
        /// <summary>CERRADA · VENCIDA · ATRASADA · DISPONIBLE · FUTURA. La deriva el SP contra hoy.</summary>
        public string situacion { get; set; }
        public int dias_restantes { get; set; }

        /* De la bandeja (HU-087). La misma ocurrencia contesta otra pregunta
           -"que tengo encima ahora"- y para eso hacen falta tres datos mas:
           donde esta el equipo, cuanto falta para que se venza, y si el hito
           trae actividades o la orden va a salir con un solo paso. */
        public int? instalacion_id { get; set; }
        public int? dias_para_limite { get; set; }
        public int actividades { get; set; }
        public bool fue_reprogramada { get; set; }

        public int? orden_trabajo_id { get; set; }
        public int? orden_trabajo_correlativo { get; set; }
        public string orden_trabajo_titulo { get; set; }
        public string observacion { get; set; }

        /// <summary>Cuantas filas hay en total con este filtro, sin paginar.</summary>
        public int total { get; set; }

        // ---- filtros ----
        public int? filtro_plan { get; set; }
        public int? filtro_activo { get; set; }
        public int? filtro_instalacion { get; set; }
        public int? filtro_estado { get; set; }

        /* SITUACION es derivada -no existe en ninguna tabla- y por eso se
           filtra en el SP de la bandeja y no en el del calendario. */
        public string filtro_situacion { get; set; }
        public bool? solo_abiertas { get; set; }
        public bool? solo_parada { get; set; }
        public DateTime? filtro_desde { get; set; }
        public DateTime? filtro_hasta { get; set; }
        public string filtro { get; set; }
        public int? pagina { get; set; }
        public int? tamano { get; set; }

        /* ------------------------------------------------------------------
           Lo que agrega la ficha de reprogramacion (HU-086).

           SEL_PLAN_OCURRENCIA_REPROGRAMAR lee la misma fila que el calendario
           pero con los nombres de la tabla -pmo_*- y trae dos datos que el
           calendario no necesita: a que fecha se movio y cual es la ocurrencia
           nueva. Conviven porque cada pantalla llena lo que lee; borrar unos u
           otros deja media aplicacion sin compilar.
           ------------------------------------------------------------------ */
        public int pmo_cliente { get; set; }
        public int pmo_estado { get; set; }
        public DateTime? pmo_fecha_programada { get; set; }
        public DateTime? pmo_fecha_original { get; set; }
        public int? pmo_ocurrencia_origen { get; set; }
        public string pmo_observacion { get; set; }
        public int? pmo_orden_trabajo { get; set; }
        public int pmo_activo { get; set; }
        public DateTime? pmo_fecha_actualizacion { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        /// <summary>Si ya fue reprogramada, a que fecha se movio (la de su hija).</summary>
        public DateTime? pmo_fecha_nueva { get; set; }
        public int? pmo_ocurrencia_nueva { get; set; }

        /// <summary>Solo se reprograma lo que todavia no ocurrio: PENDIENTE (1) o DISPONIBLE (2).</summary>
        public bool EsReprogramable { get { return pmo_estado == 1 || pmo_estado == 2; } }
        public bool YaReprogramada { get { return pmo_estado == 7; } }
    }

    /// <summary>
    /// Los contadores de la bandeja (HU-087).
    ///
    /// Cuentan TODO lo que cumple el filtro, no la pagina que se esta
    /// mirando: por eso no se arman contando filas en la pantalla. Vienen en
    /// el segundo result set del mismo SP, para no repetir la consulta.
    ///
    /// La situacion elegida NO se aplica a estos numeros: son la botonera
    /// con la que se cambia de situacion, y si se filtraran a si mismos, al
    /// entrar en "vencidas" el resto marcaria cero y no habria como salir.
    /// </summary>
    [Serializable]
    public class BandejaResumen
    {
        public int vencidas { get; set; }
        public int atrasadas { get; set; }
        public int disponibles { get; set; }
        public int futuras { get; set; }
        public int cerradas { get; set; }
        public int con_parada { get; set; }
        public int total { get; set; }

        /// <summary>Lo que requiere atencion hoy: vencido, atrasado o ya disponible.</summary>
        public int pendientes { get { return vencidas + atrasadas + disponibles; } }
    }
}
