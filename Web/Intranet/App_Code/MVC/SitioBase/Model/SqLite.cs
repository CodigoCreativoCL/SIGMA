using System;

namespace SitioBase.Model
{
    [Serializable]
    public class SqLite
    {
        public int sql_id { get; set; }
        public int sql_usuario { get; set; }
        public DateTime sql_fecha_creacion { get; set; }
        public byte[] base_sqlite { get; set; }

        public string usuario_nombre { get; set; }
    }

}