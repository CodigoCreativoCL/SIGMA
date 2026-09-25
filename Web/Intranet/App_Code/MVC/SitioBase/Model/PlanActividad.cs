using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Actividad de un hito de plan (HU-082): el paso concreto que hay que
    /// hacer cuando al hito le toca. El hito dice CADA CUANTO; la actividad
    /// dice QUE.
    ///
    /// NO LLEVA CLIENTE
    ///   Cuelga del hito, que cuelga de la version, que cuelga del plan, que
    ///   es el que tiene cliente. El SP lo cruza por ahi. Repetirlo aca
    ///   seria guardar cuatro veces el mismo dato y quedarse sin saber cual
    ///   de las cuatro es la verdadera el dia que difieran.
    ///
    /// SOLO SE ESCRIBE SOBRE UN BORRADOR
    ///   Una version publicada ya genero ordenes de trabajo con estos pasos
    ///   copiados dentro. Cambiarla haria que la orden de ayer y el plan de
    ///   hoy cuenten historias distintas, asi que el SP lo rechaza y la
    ///   pantalla lo dice antes de dejar escribir.
    /// </summary>
    [Serializable]
    public class PlanActividad
    {
        public int paa_id { get; set; }
        public int paa_plan_mantenimiento_hito { get; set; }
        public int? paa_procedimiento { get; set; }
        public string paa_codigo { get; set; }
        public string paa_nombre { get; set; }
        public string paa_descripcion { get; set; }
        public int paa_orden { get; set; }
        public int? paa_duracion_estimada_minuto { get; set; }
        public bool paa_obligatoria { get; set; }
        public bool paa_requiere_parada { get; set; }
        public bool paa_requiere_permiso { get; set; }
        public int? paa_permiso_trabajo_tipo { get; set; }
        public int paa_usuario_creacion { get; set; }
        public DateTime? paa_fecha_creacion { get; set; }
        public int? paa_usuario_actualizacion { get; set; }
        public DateTime? paa_fecha_actualizacion { get; set; }
        public bool paa_habilitado { get; set; }

        // Resueltas por SEL_PLAN_ACTIVIDAD
        public string hito_codigo { get; set; }
        public string hito_nombre { get; set; }
        public int hito_orden { get; set; }
        public int version_id { get; set; }
        public int? version_numero { get; set; }
        public string version_estado_codigo { get; set; }
        public string version_estado_nombre { get; set; }
        public int plan_id { get; set; }
        public int plan_cliente { get; set; }
        public string plan_codigo { get; set; }
        public string plan_nombre { get; set; }
        public string procedimiento_codigo { get; set; }
        public string procedimiento_nombre { get; set; }
        public int procedimiento_pasos { get; set; }
        public string permiso_tipo_nombre { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        /// <summary>Solo se edita sobre un borrador; la ficha se bloquea si no.</summary>
        public bool version_editable
        {
            get { return string.Equals(version_estado_codigo, "BORRADOR", StringComparison.OrdinalIgnoreCase); }
        }

        // Filtros
        public int? filtro_cliente { get; set; }
        public int? filtro_plan { get; set; }
        public int? filtro_version { get; set; }
        public int? filtro_hito { get; set; }
        public bool? filtro_habilitado { get; set; }
        public string filtro { get; set; }

        // Banderas de <<quitalo>> para los opcionales. Sin ellas, UPD no
        // puede distinguir <<no lo mandes>> de <<dejalo en nulo>>, porque en
        // los dos casos el parametro llega NULL.
        public bool quita_procedimiento { get; set; }
        public bool quita_permiso_tipo { get; set; }
        public bool quita_duracion { get; set; }
    }


    /// <summary>
    /// Un repuesto planificado de una actividad (HU-082 #3).
    ///
    /// ES UNA LISTA, NO UNA ENTIDAD
    ///   La tabla no tiene habilitado ni fecha de actualizacion: se agrega y
    ///   se quita. Cambiar la cantidad es quitar y volver a agregar, igual
    ///   que en cualquier lista de materiales. Por eso no hay Update.
    ///
    /// LO QUE HACE QUE IMPORTE
    ///   INS_ORDEN_TRABAJO_OCURRENCIA lee esta tabla al generar la orden y
    ///   escribe Orden_Trabajo_Repuesto con la cantidad planificada. Sin
    ///   filas aca, la orden sale sin materiales y el tecnico se entera en el
    ///   pañol.
    /// </summary>
    [Serializable]
    public class PlanActividadRepuesto
    {
        public int pra_id { get; set; }
        public int pra_plan_mantenimiento_actividad { get; set; }
        public int pra_repuesto { get; set; }
        public decimal pra_cantidad { get; set; }
        public int? pra_unidad_medida { get; set; }
        public bool pra_obligatorio { get; set; }
        public string pra_observacion { get; set; }
        public int pra_usuario_creacion { get; set; }
        public DateTime? pra_fecha_creacion { get; set; }

        // Resueltas por SEL_PLAN_ACTIVIDAD_REPUESTO
        public string repuesto_codigo { get; set; }
        public string repuesto_nombre { get; set; }
        public string repuesto_fabricante { get; set; }
        public string repuesto_modelo { get; set; }
        public string unidad_simbolo { get; set; }
        public string unidad_nombre { get; set; }
        public string actividad_codigo { get; set; }
        public string actividad_nombre { get; set; }
        public int hito_id { get; set; }
        public int plan_cliente { get; set; }
        public decimal existencia { get; set; }
        public string usuario_creacion_nombre { get; set; }

        // Filtros
        public int? filtro_cliente { get; set; }
        public int? filtro_actividad { get; set; }
        public int? filtro_hito { get; set; }
    }
}
