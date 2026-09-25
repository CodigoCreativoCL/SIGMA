using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Una versión de una pauta de checklist (HU-093). Estados: BORRADOR (1),
    /// PUBLICADO (2), RETIRADO (3). Al publicar, el borrador pasa a PUBLICADO,
    /// la publicada anterior a RETIRADO, y se congela su contenido para la
    /// reconstrucción histórica. Las calculadas las devuelve SEL_CHECKLIST_VERSION.
    /// </summary>
    [Serializable]
    public class ChecklistVersion
    {
        public int cpv_id { get; set; }
        public int cpv_checklist_plantilla { get; set; }
        public int cpv_numero { get; set; }
        public int cpv_estado { get; set; }
        public string estado_nombre { get; set; }
        public DateTime? cpv_fecha_publicacion { get; set; }
        public DateTime? cpv_fecha_retiro { get; set; }
        public string cpv_observacion { get; set; }
        public string plantilla_codigo { get; set; }
        public string plantilla_nombre { get; set; }
        public int items { get; set; }
        public int secciones { get; set; }
        public string usuario_publicacion_nombre { get; set; }
    }
}
