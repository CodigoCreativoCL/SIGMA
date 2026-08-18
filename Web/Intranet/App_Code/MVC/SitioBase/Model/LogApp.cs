using System;

namespace Agendamiento.Model
{
    public class LogApp
    {
        // Datos del registro
        public int    lot_id                 { get; set; }
        public string lot_endpoint           { get; set; }
        public string lot_metodo             { get; set; }
        public string lot_request            { get; set; }
        public string lot_response           { get; set; }
        public bool   lot_error              { get; set; }
        public string lot_mensaje_error      { get; set; }
        public string lot_stack_trace        { get; set; } 
        public int?   lot_id_cliente_usuario { get; set; }
        public string lot_nombre_usuario     { get; set; }
        public string lot_usuario            { get; set; }
        public string lot_ip                 { get; set; }
        public int?   lot_duracion_ms        { get; set; }
        public string lot_fecha_creacion     { get; set; }

        // Filtros
        public int    filtro_id                 { get; set; }
        public string filtro                    { get; set; }
        public string filtro_endpoint           { get; set; }
        public string filtro_error              { get; set; }  // "0", "1" o ""
        public int    filtro_id_cliente_usuario { get; set; }
        public string filtro_desde              { get; set; }  // yyyy-MM-dd
        public string filtro_hasta              { get; set; }  // yyyy-MM-dd
    }
}
