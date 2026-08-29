using System;

namespace SitioBase.Model
{
    [Serializable]
    public class Menus
    {
        public int mnu_id { get; set; }
        public string mnu_nombre { get; set; }
        public string mnu_descripcion { get; set; }
        public int mnu_nivel { get; set; }
        public int mnu_padre { get; set; }
        public int mnu_orden { get; set; }
        public string mnu_link { get; set; }
        public bool mnu_visible { get; set; }
        public string mnu_icon { get; set; }

        /// <summary>Permiso que exige esta pagina. NULL en los contenedores.</summary>
        public int mnu_permiso { get; set; }

        // Solo lectura, vienen de SEL_MENUS_MANTENEDOR para la grilla.
        public string prm_codigo { get; set; }
        public string padre_nombre { get; set; }
        public string mnu_tipo { get; set; }

        public string filtro { get; set; }
        //public bool mnu_aplica_permisos { get; set; }
        //public bool mnu_crear { get; set; }
        //public bool mnu_editar { get; set; }
        //public bool mnu_eliminar { get; set; }
        //public bool mnu_ver_todo { get; set; }

        //public Perfil perfil { get; set; }

        //// correción seguridad
        //public int mnu_tipo { get; set; }
        //public bool mnu_tools { get; set; }
        //public string mnu_css { get; set; }
    }
}