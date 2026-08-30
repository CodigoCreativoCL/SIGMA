using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Integrante de un grupo de trabajo, con su tramo de vigencia (HU-016).
    ///
    /// La pertenencia se modela por PERIODO y no con una bandera: el
    /// escenario 3 pide que alguien deje de pertenecer al grupo al vencer
    /// una fecha, y el escenario 2 que solo haya un lider vigente a la vez.
    /// Las dos reglas necesitan las fechas, no un booleano.
    /// </summary>
    [Serializable]
    public class GrupoTrabajoUsuario
    {
        public int gtu_id { get; set; }
        public int gtu_grupo_trabajo { get; set; }
        public int gtu_usuario { get; set; }
        public bool gtu_es_lider { get; set; }
        public DateTime? gtu_fecha_inicio { get; set; }
        public DateTime? gtu_fecha_fin { get; set; }
        public int gtu_usuario_creacion { get; set; }
        public DateTime? gtu_fecha_creacion { get; set; }

        // Columnas del JOIN
        public string usu_nombre { get; set; }
        public string usu_correo { get; set; }
        public string usu_identificador { get; set; }
        public string gtr_nombre { get; set; }
        public string estado { get; set; }

        public string filtro { get; set; }
        public bool filtro_solo_vigentes { get; set; }
        public bool quita_fin { get; set; }
    }
}
