using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Tipo de asignación de un checklist (a quién se asigna): técnico
    /// específico, varios técnicos, cualquiera de la planta, grupo. Catálogo
    /// global. Lo usa el combo de la ficha de plantilla (HU-090).
    /// </summary>
    [Serializable]
    public class ChecklistAsignacionTipo
    {
        public int cat_id { get; set; }
        public string cat_codigo { get; set; }
        public string cat_nombre { get; set; }
        public bool cat_habilitado { get; set; }

        public bool? filtro_habilitado { get; set; }
    }
}
