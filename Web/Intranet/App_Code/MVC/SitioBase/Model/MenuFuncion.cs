using System;

namespace SitioBase.Model
{
    [Serializable]
    public class MenuFuncion
    {
        public int mfu_id { get; set; }
        public string mfu_nombre { get; set; }
        public int mfu_menu { get; set; }

        /// <summary>Permiso que representa esta funcion dentro de la pagina.</summary>
        public int mfu_permiso { get; set; }

        // Solo lectura, para la grilla.
        public string prm_codigo { get; set; }
        public string prm_nombre { get; set; }
        public string prm_modulo { get; set; }
        public string mnu_nombre { get; set; }
    }
}