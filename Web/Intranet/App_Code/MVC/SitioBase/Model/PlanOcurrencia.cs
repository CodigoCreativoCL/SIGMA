using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Una fila del calendario de mantenimiento (HU-085): a un equipo le
    /// toca un hito en una fecha. Solo lectura desde la web; quien la crea
    /// es el generador (HU-076) y quien la cierra es la orden de trabajo.
    /// </summary>
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
        public DateTime? filtro_desde { get; set; }
        public DateTime? filtro_hasta { get; set; }
        public string filtro { get; set; }
        public int? pagina { get; set; }
        public int? tamano { get; set; }
    }
}
