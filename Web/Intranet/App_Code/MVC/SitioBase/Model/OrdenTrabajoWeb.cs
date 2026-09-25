using System;

namespace SitioBase.Model
{
    /// <summary>La orden de trabajo vista desde la web (Sprint 5: HU-110/112/120/122).</summary>
    public class OrdenTrabajo
    {
        public int otr_id { get; set; }
        public Guid otr_uuid { get; set; }
        public int otr_cliente { get; set; }
        public int otr_cliente_instalacion { get; set; }
        public int otr_correlativo { get; set; }
        public int? otr_instalacion_area { get; set; }
        public int? otr_activo { get; set; }
        public int? otr_activo_componente { get; set; }
        public int otr_orden_trabajo_tipo { get; set; }
        public int otr_orden_trabajo_estrategia { get; set; }
        public int otr_orden_trabajo_origen { get; set; }
        public int otr_orden_trabajo_estado { get; set; }
        public int otr_orden_trabajo_prioridad { get; set; }
        public int otr_usuario_generador { get; set; }
        public string otr_titulo { get; set; }
        public string otr_descripcion { get; set; }
        public string otr_notas { get; set; }
        public string otr_resultado { get; set; }
        public DateTime? otr_fecha_evento_utc { get; set; }
        public DateTime? otr_fecha_programada_utc { get; set; }
        public DateTime? otr_fecha_inicio_real_utc { get; set; }
        public DateTime? otr_fecha_fin_real_utc { get; set; }
        public int? otr_duracion_estimada_minuto { get; set; }
        public int? otr_duracion_real_minuto { get; set; }
        public int? otr_minuto_parada_activo { get; set; }
        public bool otr_requiere_permiso { get; set; }
        public int? otr_plan_mantenimiento_ocurrencia { get; set; }
        public int? otr_tarea_ocurrencia { get; set; }
        public int? otr_checklist_hallazgo { get; set; }
        public int? otr_prediccion { get; set; }
        public int? otr_falla { get; set; }
        public bool otr_registro_posterior { get; set; }
        public DateTime? otr_fecha_ocurrencia { get; set; }
        public int? otr_cierre_motivo { get; set; }
        public int? otr_usuario_cierre { get; set; }
        public DateTime? otr_fecha_cierre { get; set; }
        public DateTime? otr_fecha_creacion { get; set; }
        public DateTime? otr_fecha_actualizacion { get; set; }
        public bool otr_habilitado { get; set; }

        public string planta_nombre { get; set; }
        public string area_nombre { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string componente_nombre { get; set; }
        public string tipo_codigo { get; set; }
        public string tipo_nombre { get; set; }
        public string estrategia_codigo { get; set; }
        public string estrategia_nombre { get; set; }
        public string origen_codigo { get; set; }
        public string origen_nombre { get; set; }
        public string estado_codigo { get; set; }
        public string estado_nombre { get; set; }
        public string prioridad_codigo { get; set; }
        public string prioridad_nombre { get; set; }
        public string cierre_motivo_nombre { get; set; }
        public string generador_nombre { get; set; }
        public string cierre_usuario_nombre { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }
        public string responsable_nombre { get; set; }
        public string responsable_proveedor { get; set; }
        public int asignados { get; set; }
        public int pasos { get; set; }
        public int pasos_pendientes { get; set; }
        public int repuestos { get; set; }
        public int servicios { get; set; }
        public int indisponibilidades { get; set; }
        public int permisos_pendientes { get; set; }
        public int? dias_espera_cierre { get; set; }
        public string falla_titulo { get; set; }
        public string plan_codigo { get; set; }
        public int total { get; set; }

        public int? filtro_instalacion { get; set; }
        public int? filtro_estado { get; set; }
        public int? filtro_tipo { get; set; }
        public int? filtro_origen { get; set; }
        public int? filtro_activo { get; set; }
        public int? filtro_falla { get; set; }
        public DateTime? filtro_desde { get; set; }
        public DateTime? filtro_hasta { get; set; }
        public string filtro { get; set; }
        public bool quita_fecha { get; set; }
        public bool quita_duracion { get; set; }
    }

    public class OrdenTrabajoAsignacion
    {
        public int ota_id { get; set; }
        public int ota_orden_trabajo { get; set; }
        public int? ota_usuario { get; set; }
        public int? ota_proveedor { get; set; }
        public int? ota_grupo_trabajo { get; set; }
        public bool ota_es_responsable { get; set; }
        public int? ota_rol_ejecucion { get; set; }
        public DateTime? ota_fecha_asignacion_utc { get; set; }
        public DateTime? ota_fecha_aceptacion_utc { get; set; }
        public string ota_observacion { get; set; }
        public string usuario_nombre { get; set; }
        public string proveedor_nombre { get; set; }
        public string grupo_nombre { get; set; }
        public string rol_codigo { get; set; }
        public string rol_nombre { get; set; }
        public string asignado_por_nombre { get; set; }
        public string especialidades { get; set; }
        /// <summary>Lo que devolvio el SP al asignar (HU-112 #4): especialidad faltante; se permite igual.</summary>
        public string advertencia { get; set; }
    }

    public class Falla
    {
        public int fal_id { get; set; }
        public Guid fal_uuid { get; set; }
        public int fal_activo { get; set; }
        public int? fal_activo_componente { get; set; }
        public int? fal_falla_sintoma { get; set; }
        public int fal_criticidad_nivel { get; set; }
        public string fal_titulo { get; set; }
        public string fal_descripcion { get; set; }
        public string fal_consecuencia { get; set; }
        public int? fal_activo_estado_posterior { get; set; }
        public bool fal_detuvo_produccion { get; set; }
        public DateTime? fal_fecha_deteccion_utc { get; set; }
        public DateTime? fal_fecha_solucion_utc { get; set; }
        public int? fal_usuario_reporta { get; set; }
        public DateTime? fal_fecha_creacion { get; set; }
        public DateTime? fal_fecha_actualizacion { get; set; }
        public bool fal_habilitado { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string planta_nombre { get; set; }
        public string componente_nombre { get; set; }
        public string sintoma_nombre { get; set; }
        public string criticidad_codigo { get; set; }
        public string criticidad_nombre { get; set; }
        public string estado_posterior_nombre { get; set; }
        public string reporta_nombre { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }
        public int diagnosticos { get; set; }
        public int acciones { get; set; }
        public int acciones_provisorias { get; set; }
        public int ordenes { get; set; }
        public int? ultima_ot_correlativo { get; set; }
        public int indisponibilidades { get; set; }
        public int provisorias_del_equipo { get; set; }

        public int? filtro_activo { get; set; }
        public int? filtro_instalacion { get; set; }
        public bool? filtro_abiertas { get; set; }
        public string filtro { get; set; }
        public bool quita_solucion { get; set; }
    }

    public class FallaDiagnostico
    {
        public int fdi_id { get; set; }
        public int fdi_falla { get; set; }
        public int? fdi_falla_modo { get; set; }
        public int? fdi_falla_causa { get; set; }
        public int? fdi_diagnostico_metodo { get; set; }
        public string fdi_descripcion { get; set; }
        public bool fdi_es_definitivo { get; set; }
        public decimal? fdi_confianza { get; set; }
        public DateTime? fdi_fecha_diagnostico_utc { get; set; }
        public string modo_nombre { get; set; }
        public string causa_nombre { get; set; }
        public string metodo_nombre { get; set; }
        public string diagnostica_nombre { get; set; }
    }

    public class FallaAccion
    {
        public int fac_id { get; set; }
        public int fac_falla { get; set; }
        public int? fac_falla_diagnostico { get; set; }
        public int? fac_orden_trabajo { get; set; }
        public string fac_descripcion { get; set; }
        public bool fac_es_definitiva { get; set; }
        public DateTime? fac_fecha_accion_utc { get; set; }
        public int? ot_correlativo { get; set; }
        public string ejecuta_nombre { get; set; }
    }

    public class ActivoIndisponibilidad
    {
        public int ain_id { get; set; }
        public int ain_activo { get; set; }
        public int? ain_orden_trabajo { get; set; }
        public int? ain_falla { get; set; }
        public DateTime ain_fecha_inicio_utc { get; set; }
        public DateTime? ain_fecha_fin_utc { get; set; }
        public int? ain_minuto { get; set; }
        public bool ain_planificada { get; set; }
        public bool ain_detuvo_produccion { get; set; }
        public int? ain_indisponibilidad_motivo { get; set; }
        public string ain_motivo { get; set; }
        public bool ain_habilitado { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string planta_nombre { get; set; }
        public string motivo_nombre { get; set; }
        public int? ot_correlativo { get; set; }
        public string falla_titulo { get; set; }
        public int minutos_acumulados { get; set; }
        public string usuario_creacion_nombre { get; set; }

        public int? filtro_activo { get; set; }
        public int? filtro_orden { get; set; }
        public int? filtro_falla { get; set; }
        public int? filtro_instalacion { get; set; }
    }
}
