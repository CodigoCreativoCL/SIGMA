using System;

namespace SitioBase.Model
{
    [Serializable]
    public class MenuMaterialApoyo
    {
        public int mma_id { get; set; }
        public int mma_menu { get; set; }
        public string mma_contenedor { get; set; }
        public string mma_nombre { get; set; }
        public string mma_ruta { get; set; }
        public int mma_orden { get; set; }
        public bool mma_habilitado { get; set; }
        public int mma_usuario_creacion { get; set; }
        public DateTime mma_fecha_creacion { get; set; }
        public int mma_usuario_act { get; set; }
        public DateTime mma_fecha_act { get; set; }
        public int meGusta { get; set; }
        public int noMeGusta { get; set; }
        public int visto { get; set; }

        public string filtro_habilitado { get; set; }
    }
}