using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Plan de mantenimiento preventivo (HU-080).
    ///
    /// El plan es la cabecera: que se le hace a que familia de equipos y
    /// quien lo planifica. Lo que se hace y cada cuanto -los hitos- y a que
    /// maquinas concretas -los activos- NO cuelgan de aqui sino de la VERSION
    /// del plan (Plan_Mantenimiento_Version, HU-084). Un plan recien creado
    /// nace con su version 1 en borrador; la crea el SP de alta.
    /// </summary>
    [Serializable]
    public class PlanMantenimiento
    {
        public int pma_id { get; set; }
        public int pma_cliente { get; set; }
        public int? pma_cliente_instalacion { get; set; }
        public string pma_codigo { get; set; }
        public string pma_nombre { get; set; }
        public string pma_descripcion { get; set; }
        public int? pma_usuario_planificador { get; set; }
        public int? pma_activo_tipo { get; set; }
        public int? pma_activo_modelo { get; set; }
        public int pma_usuario_creacion { get; set; }
        public DateTime? pma_fecha_creacion { get; set; }
        public int? pma_usuario_actualizacion { get; set; }
        public DateTime? pma_fecha_actualizacion { get; set; }
        public bool pma_habilitado { get; set; }

        // Resueltas por SEL_PLAN_MANTENIMIENTO
        public string planta_nombre { get; set; }
        public string tipo_nombre { get; set; }
        public string modelo_nombre { get; set; }
        public string planificador_nombre { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        /// <summary>La version que manda: la publicada si hay, si no la ultima.</summary>
        public int? version_id { get; set; }
        public int? version_numero { get; set; }
        public string version_estado_codigo { get; set; }
        public string version_estado_nombre { get; set; }
        public int hitos { get; set; }
        public int activos { get; set; }

        // Filtros del listado
        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public int? filtro_instalacion { get; set; }

        /* Los combos opcionales: vacio al editar significa "quitalo", no
           "no lo toques". Sin estas banderas el SP conserva el valor viejo
           con ISNULL y el cambio se pierde en silencio. */
        public bool quita_instalacion { get; set; }
        public bool quita_planificador { get; set; }
        public bool quita_tipo { get; set; }
        public bool quita_modelo { get; set; }
    }
}
