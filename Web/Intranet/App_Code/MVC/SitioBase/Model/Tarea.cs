using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Tarea recurrente (HU-102): trabajo breve que se repite. Que es; el
    /// «cada cuanto y quien» va en TareaProgramacion.
    /// </summary>
    public class Tarea
    {
        public int tar_id { get; set; }
        public int tar_cliente { get; set; }
        public int? tar_cliente_instalacion { get; set; }
        public int? tar_instalacion_area { get; set; }
        public int? tar_tarea_categoria { get; set; }
        public int? tar_activo { get; set; }
        public string tar_codigo { get; set; }
        public string tar_titulo { get; set; }
        public string tar_descripcion { get; set; }
        public int tar_tarea_prioridad { get; set; }
        public int? tar_duracion_estimada_minuto { get; set; }
        public bool tar_requiere_evidencia { get; set; }
        public int tar_usuario_creacion { get; set; }
        public DateTime? tar_fecha_creacion { get; set; }
        public int? tar_usuario_actualizacion { get; set; }
        public DateTime? tar_fecha_actualizacion { get; set; }
        public bool tar_habilitado { get; set; }

        public string planta_nombre { get; set; }
        public string area_nombre { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string categoria_nombre { get; set; }
        public string prioridad_codigo { get; set; }
        public string prioridad_nombre { get; set; }
        public int prioridad_orden { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }
        public int programaciones { get; set; }
        public int ocurrencias { get; set; }
        public int pendientes { get; set; }

        // filtros
        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public int? filtro_instalacion { get; set; }
        public int? filtro_activo { get; set; }
        public int? filtro_prioridad { get; set; }

        // banderas de «quitalo» para los opcionales (UPD)
        public bool quita_instalacion { get; set; }
        public bool quita_area { get; set; }
        public bool quita_activo { get; set; }
        public bool quita_categoria { get; set; }
        public bool quita_duracion { get; set; }
        public bool quita_descripcion { get; set; }
    }

    /// <summary>Cada cuanto y quien: una tarea con una programacion.</summary>
    public class TareaProgramacion
    {
        public int tpr_id { get; set; }
        public int tpr_tarea { get; set; }
        public int tpr_programacion { get; set; }
        public int? tpr_usuario_responsable { get; set; }
        public int? tpr_grupo_trabajo { get; set; }
        public int tpr_usuario_creacion { get; set; }
        public DateTime? tpr_fecha_creacion { get; set; }
        public int? tpr_usuario_actualizacion { get; set; }
        public DateTime? tpr_fecha_actualizacion { get; set; }
        public bool tpr_habilitado { get; set; }

        public int tarea_cliente { get; set; }
        public string tarea_codigo { get; set; }
        public string tarea_titulo { get; set; }
        public string programacion_nombre { get; set; }
        public string programacion_tipo_nombre { get; set; }
        public DateTime? programacion_fecha_inicio { get; set; }
        public DateTime? programacion_fecha_fin { get; set; }
        public bool programacion_habilitado { get; set; }
        public string responsable_nombre { get; set; }
        public string grupo_nombre { get; set; }
        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }
        public int ocurrencias { get; set; }

        public int? filtro_cliente { get; set; }
        public int? filtro_tarea { get; set; }
        public bool? filtro_habilitado { get; set; }

        public bool quita_responsable { get; set; }
        public bool quita_grupo { get; set; }
    }

    /// <summary>Un comentario del hilo de una ocurrencia (HU-104). Append-only.</summary>
    public class TareaComentario
    {
        public int tco_id { get; set; }
        public int tco_tarea_ocurrencia { get; set; }
        public int? tco_comentario_padre { get; set; }
        public string tco_texto { get; set; }
        public int? tco_dictado_voz { get; set; }
        public int tco_usuario_creacion { get; set; }
        public DateTime? tco_fecha_creacion { get; set; }

        public string usuario_nombre { get; set; }
        public int tarea_id { get; set; }
        public string tarea_codigo { get; set; }
        public string tarea_titulo { get; set; }
        public DateTime? ocurrencia_fecha { get; set; }
        public string ocurrencia_estado_codigo { get; set; }
        public string ocurrencia_estado_nombre { get; set; }
        public int respuestas { get; set; }

        public int? filtro_cliente { get; set; }
        public int? filtro_tarea { get; set; }
        public int? filtro_ocurrencia { get; set; }
    }
}
