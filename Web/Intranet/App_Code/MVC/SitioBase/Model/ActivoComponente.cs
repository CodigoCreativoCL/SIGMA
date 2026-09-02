using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un componente de un activo (HU-036): rodamiento, sello, eje… El código
    /// es único DENTRO DEL ACTIVO. Las calculadas las devuelve
    /// SEL_ACTIVO_COMPONENTE por JOIN.
    /// </summary>
    [Serializable]
    public class ActivoComponente
    {
        public int aco_id { get; set; }
        public int aco_cliente { get; set; }
        public int aco_activo { get; set; }
        public int? aco_componente_padre { get; set; }
        public int aco_componente_tipo { get; set; }
        public int? aco_componente_posicion { get; set; }
        public int aco_criticidad_nivel { get; set; }
        public int aco_activo_componente_estado { get; set; }
        public string aco_codigo { get; set; }
        public string aco_nombre { get; set; }
        public DateTime? aco_fecha_instalacion { get; set; }
        public string aco_descripcion { get; set; }
        public DateTime? aco_fecha_creacion { get; set; }
        public DateTime? aco_fecha_actualizacion { get; set; }
        public bool aco_habilitado { get; set; }

        // Calculadas por SEL_ACTIVO_COMPONENTE
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string tipo_nombre { get; set; }
        public string estado_nombre { get; set; }
        public string criticidad_nombre { get; set; }
        public string posicion_nombre { get; set; }
        public string padre_nombre { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        // Filtros
        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public int filtro_activo { get; set; }
    }


    /// <summary>Tipo de componente (rodamiento, sello…). Global o del cliente.</summary>
    [Serializable]
    public class ComponenteTipo
    {
        public int cto_id { get; set; }
        public int? cto_cliente { get; set; }
        public string cto_codigo { get; set; }
        public string cto_nombre { get; set; }
        public bool cto_habilitado { get; set; }

        public int filtro_cliente { get; set; }
        public bool? filtro_habilitado { get; set; }
    }


    /// <summary>Estado de un componente. Catálogo global.</summary>
    [Serializable]
    public class ActivoComponenteEstado
    {
        public int ace_id { get; set; }
        public string ace_codigo { get; set; }
        public string ace_nombre { get; set; }
        public bool ace_habilitado { get; set; }

        public bool? filtro_habilitado { get; set; }
    }


    /// <summary>Posición de un componente. Global o del cliente.</summary>
    [Serializable]
    public class ComponentePosicion
    {
        public int cpn_id { get; set; }
        public int? cpn_cliente { get; set; }
        public string cpn_codigo { get; set; }
        public string cpn_nombre { get; set; }
        public bool cpn_habilitado { get; set; }

        public int filtro_cliente { get; set; }
        public bool? filtro_habilitado { get; set; }
    }
}
