using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Activo: la máquina física del cliente (HU-035).
    ///
    /// Las propiedades espejan las columnas de la tabla Activo. Las
    /// calculadas (nombres de cada FK, nombres de usuario de auditoría) las
    /// devuelve SEL_ACTIVO con sus JOIN, y sirven para mostrar sin obligar a
    /// la pantalla a resolver cada id contra otra consulta.
    /// </summary>
    [Serializable]
    public class Activo
    {
        public int act_id { get; set; }
        public int act_cliente { get; set; }
        public int act_cliente_instalacion { get; set; }
        public int? act_instalacion_area { get; set; }
        public int act_activo_tipo { get; set; }
        public int? act_activo_modelo { get; set; }
        public int act_activo_estado { get; set; }
        public int? act_activo_padre { get; set; }
        public int? act_centro_costo { get; set; }
        public int act_criticidad_nivel { get; set; }
        public string act_codigo { get; set; }
        public string act_nombre { get; set; }
        public string act_numero_serie { get; set; }
        public string act_fabricante { get; set; }
        public int? act_anio_fabricacion { get; set; }
        public DateTime? act_fecha_puesta_marcha { get; set; }
        public DateTime? act_fecha_baja { get; set; }
        public string act_descripcion { get; set; }
        public int? act_registro_origen { get; set; }
        public int act_usuario_creacion { get; set; }
        public DateTime? act_fecha_creacion { get; set; }
        public int act_usuario_actualizacion { get; set; }
        public DateTime? act_fecha_actualizacion { get; set; }
        public bool act_habilitado { get; set; }

        // Calculadas por SEL_ACTIVO
        public string planta_nombre { get; set; }
        public string area_nombre { get; set; }
        public string tipo_nombre { get; set; }
        public string estado_nombre { get; set; }
        public string criticidad_nombre { get; set; }
        public string centro_costo_nombre { get; set; }
        public string padre_codigo { get; set; }
        public string padre_nombre { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        // Filtros del listado / combos
        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public int filtro_cliente_instalacion { get; set; }
        public int filtro_activo_tipo { get; set; }
        public int filtro_activo_estado { get; set; }
    }


    /// <summary>Tipo de activo (motor, bomba…). Global de SIGMA o del cliente.</summary>
    [Serializable]
    public class ActivoTipo
    {
        public int ati_id { get; set; }
        public int? ati_cliente { get; set; }
        public int? ati_activo_tipo_padre { get; set; }
        public string ati_codigo { get; set; }
        public string ati_nombre { get; set; }
        public string ati_descripcion { get; set; }
        public bool ati_habilitado { get; set; }

        public int filtro_cliente { get; set; }
        public bool? filtro_habilitado { get; set; }
    }


    /// <summary>Estado operacional de un activo. Catálogo global de ids fijos.</summary>
    [Serializable]
    public class ActivoEstado
    {
        public int aes_id { get; set; }
        public string aes_codigo { get; set; }
        public string aes_nombre { get; set; }
        public string aes_icono { get; set; }
        public int? aes_orden { get; set; }
        public bool aes_habilitado { get; set; }

        public bool? filtro_habilitado { get; set; }
    }


    /// <summary>Nivel de criticidad de un activo. Catálogo global de ids fijos.</summary>
    [Serializable]
    public class CriticidadNivel
    {
        public int crn_id { get; set; }
        public string crn_codigo { get; set; }
        public string crn_nombre { get; set; }
        public string crn_icono { get; set; }
        public int? crn_orden { get; set; }
        public bool crn_habilitado { get; set; }

        public bool? filtro_habilitado { get; set; }
    }
}
