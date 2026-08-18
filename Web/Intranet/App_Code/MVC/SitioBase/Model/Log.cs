using System;

namespace SitioBase.Model
{
    [Serializable]
    public class Log
    {
        public int log_id { get; set; }
        public string usuario_nombre { get; set; }
            
        public DateTime log_fecha_ejecucion { get; set; }
        public string loe_nombre { get; set; }
        public string lot_tabla { get; set; }
        public int lot_id { get; set; }
        public int log_tabla_id { get; set; }
        public string log_columna { get; set; }
        public string log_valor_actual { get; set; }
        public string log_valor_nuevo { get; set; }
        public string accion { get; set; }
        public string tablas { get; set; }
        public string usuarios { get; set; }
        public string filtro { get; set; }
    }
}