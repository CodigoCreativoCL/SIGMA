using SitioBase;
using System;
using System.Data;
using System.Data.SqlClient;
using System.Web.Script.Serialization;

namespace SitioBase.Controller
{
    /// <summary>
    /// Lo que la bodega sabe de un repuesto (bloques 326 a 330), para el
    /// Centro de repuestos y la ficha del repuesto: metodo de salida, medidas
    /// y peso, donde esta cada caja y en que posicion, consumo, conteos y
    /// solicitudes de reposicion.
    ///
    /// Las escrituras pasan por los mismos SP que usa el mapa 3D: un solo
    /// lugar donde vive cada regla.
    /// </summary>
    public class RepuestoAlmacenamientoController
    {
        private static DataTable Leer(string sp, int repuesto, int? dias = null)
        {
            if (!Token.TokenSeguridad()) return new DataTable();
            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = sp;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@REPUESTO", repuesto);
                if (dias.HasValue) cmd.Parameters.AddWithValue("@DIAS", dias.Value);
                return Conexion.GetDataTable(cmd);
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                return new DataTable();
            }
        }

        /// <summary>Metodo propio (o vacio) y medidas: SEL_REPUESTO_FICHA_MAPA.</summary>
        public DataRow Ficha(int repuesto) { DataTable t = Leer("SEL_REPUESTO_FICHA_MAPA", repuesto); return t.Rows.Count > 0 ? t.Rows[0] : null; }
        public DataTable Almacenamiento(int repuesto) { return Leer("SEL_REPUESTO_ALMACENAMIENTO", repuesto); }
        public DataTable Consumo(int repuesto, int dias) { return Leer("SEL_REPUESTO_CONSUMO", repuesto, dias); }
        public DataTable Conteos(int repuesto) { return Leer("SEL_REPUESTO_CONTEOS", repuesto); }
        public DataTable Reposiciones(int repuesto) { return Leer("SEL_REPUESTO_REPOSICIONES", repuesto); }

        private static Respuesta Escribir(Action<SqlCommand> armar, string sp, string ok)
        {
            Respuesta r = new Respuesta();
            if (!Token.TokenSeguridad()) { r.error = true; r.detalle = "La sesión expiró."; return r; }
            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = sp;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                armar(cmd);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                DataTable dt = Conexion.GetDataTable(cmd);
                if (dt.Rows.Count > 0 && dt.Columns.Contains("ID") && dt.Rows[0]["ID"] != DBNull.Value) r.codigo = Convert.ToInt32(dt.Rows[0]["ID"]);
                r.detalle = dt.Rows.Count > 0 && dt.Columns.Contains("MENSAJE") ? Convert.ToString(dt.Rows[0]["MENSAJE"]) : ok;
            }
            catch (Exception ex)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                r.error = true; r.codigo = -1; r.detalle = ex.Message;
            }
            return r;
        }

        /// <summary>Vacio quita la excepcion: el repuesto sigue el metodo de cada bodega.</summary>
        public Respuesta GuardarMetodo(int repuesto, string metodo)
        {
            return Escribir(c =>
            {
                c.Parameters.AddWithValue("@REPUESTO", repuesto);
                c.Parameters.AddWithValue("@METODO", string.IsNullOrEmpty(metodo) ? (object)DBNull.Value : metodo);
            }, "UPD_REPUESTO_METODO_SALIDA", "Método de salida actualizado.");
        }

        public Respuesta GuardarMedidas(int repuesto, decimal? largo, decimal? ancho, decimal? alto, decimal? peso)
        {
            Func<decimal?, object> v = n => n.HasValue ? (object)n.Value : DBNull.Value;
            return Escribir(c =>
            {
                c.Parameters.AddWithValue("@REPUESTO", repuesto);
                c.Parameters.AddWithValue("@LARGO", v(largo));
                c.Parameters.AddWithValue("@ANCHO", v(ancho));
                c.Parameters.AddWithValue("@ALTO", v(alto));
                c.Parameters.AddWithValue("@PESO", v(peso));
            }, "UPD_REPUESTO_DIMENSIONES", "Medidas actualizadas.");
        }

        /// <summary>Una solicitud de reposicion de un solo repuesto (INS_SOLICITUD_REPOSICION).</summary>
        public Respuesta CrearReposicion(int bodega, int repuesto, decimal cantidad, decimal? stock, decimal? minimo, decimal? maximo, string observacion)
        {
            string detalle = new JavaScriptSerializer().Serialize(new[] { new { repuesto, cantidad, stock, minimo, maximo } });
            Respuesta r = new Respuesta();
            if (!Token.TokenSeguridad()) { r.error = true; r.detalle = "La sesión expiró."; return r; }
            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = "INS_SOLICITUD_REPOSICION";
                cmd.Parameters.AddWithValue("@ID", 0).Direction = ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@BODEGA", bodega);
                cmd.Parameters.AddWithValue("@OBSERVACION", string.IsNullOrEmpty(observacion) ? (object)DBNull.Value : observacion);
                cmd.Parameters.AddWithValue("@DETALLE", detalle);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                DataTable dt = Conexion.GetDataTable(cmd);
                if (dt.Rows.Count > 0) { r.codigo = Convert.ToInt32(dt.Rows[0]["ID"]); r.detalle = Convert.ToString(dt.Rows[0]["MENSAJE"]); }
            }
            catch (Exception ex)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                r.error = true; r.codigo = -1; r.detalle = ex.Message;
            }
            return r;
        }
    }
}
