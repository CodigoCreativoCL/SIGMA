using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Centro de costo del cliente, en arbol (HU-013).
    /// </summary>
    [Serializable]
    public class CentroCosto
    {
        public int cco_id { get; set; }
        public int cco_cliente { get; set; }
        public int? cco_centro_costo_padre { get; set; }
        public string cco_codigo { get; set; }
        public string cco_nombre { get; set; }
        public int cco_usuario_creacion { get; set; }
        public DateTime? cco_fecha_creacion { get; set; }
        public int cco_usuario_actualizacion { get; set; }
        public DateTime? cco_fecha_actualizacion { get; set; }
        public bool cco_habilitado { get; set; }

        // Columnas calculadas por SEL_CENTRO_COSTO
        public string padre_nombre { get; set; }
        public int nivel { get; set; }
        public string ruta { get; set; }

        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public bool filtro_solo_raiz { get; set; }
        public bool quita_padre { get; set; }
    }
}
