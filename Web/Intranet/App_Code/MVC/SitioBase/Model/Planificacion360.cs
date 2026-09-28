using System;

namespace SitioBase.Model
{
    [Serializable]
    public class PlanificacionCobertura
    {
        public int activo_id { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public int? tipo_id { get; set; }
        public string tipo_nombre { get; set; }
        public string planta_nombre { get; set; }
        public int? area_id { get; set; }
        public string area_nombre { get; set; }
        public int? criticidad_id { get; set; }
        public string criticidad_codigo { get; set; }
        public string criticidad_nombre { get; set; }
        public int planes { get; set; }
        public string planes_nombres { get; set; }
    }

    /// <summary>Los cuatro números de la cabecera de Cobertura.</summary>
    [Serializable]
    public class PlanificacionCoberturaResumen
    {
        public int habilitados { get; set; }
        public int cubiertos { get; set; }
        public int sin_plan { get; set; }
        public int varios { get; set; }
    }

    [Serializable]
    public class PlanificacionProgramacionUso
    {
        public int programacion_id { get; set; }
        public string origen { get; set; }
        public int id { get; set; }
        public string codigo { get; set; }
        public string nombre { get; set; }
    }

    [Serializable]
    public class PlanificacionCumplimientoEquipo
    {
        public int activo_id { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string planta_nombre { get; set; }
        public int programadas { get; set; }
        public int cumplidas { get; set; }
        public int a_tiempo { get; set; }
        public int a_tiempo_vigente { get; set; }
        public int vencidas { get; set; }
        public int atrasadas { get; set; }
        public int omitidas { get; set; }
        public int reprogramadas { get; set; }
        public decimal cumplimiento { get; set; }
    }

    [Serializable]
    public class PlanificacionActividad
    {
        public int orden_id { get; set; }
        public int orden_correlativo { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string hito_nombre { get; set; }
        public DateTime fecha { get; set; }
        public string estado_codigo { get; set; }
        public string estado_nombre { get; set; }
    }

    /// <summary>Lo que exige un hito: personas, repuestos y permiso de trabajo.</summary>
    [Serializable]
    public class PlanificacionHitoRequisito
    {
        public int hito_id { get; set; }
        public int personas { get; set; }
        public int repuestos { get; set; }
        public string repuesto_principal { get; set; }
        public bool permiso { get; set; }
    }

    /// <summary>Un plan con una versión en borrador abierta.</summary>
    [Serializable]
    public class PlanificacionBorrador
    {
        public int plan_id { get; set; }
        public string codigo { get; set; }
        public string nombre { get; set; }
        public string familia { get; set; }
        public int version_numero { get; set; }
        public int cambios { get; set; }
        public DateTime ultima_edicion { get; set; }
        public string responsable { get; set; }
    }
}
