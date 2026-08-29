using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Catalogo de permisos. Es el ancla de todo el modelo de autorizacion:
    /// los menus y las funciones apuntan aca por prm_id, y el codigo del
    /// sitio nunca menciona un id, solo el prm_codigo.
    /// </summary>
    [Serializable]
    public class Permiso
    {
        public int prm_id { get; set; }
        public string prm_codigo { get; set; }
        public string prm_nombre { get; set; }
        public string prm_modulo { get; set; }
        public int prm_permiso_ambito { get; set; }
        public string prm_descripcion { get; set; }
        public bool prm_habilitado { get; set; }
        public bool prm_asignable_usuario { get; set; }

        public string filtro_modulo { get; set; }
    }
}
