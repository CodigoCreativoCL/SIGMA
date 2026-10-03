using SitioBase;
using System;
using System.Data;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Conteo ciclico de inventario (bloque 326).
    ///
    /// SOLO DEJA CONSTANCIA
    ///   Este controller registra que se conto, cuanto decia el sistema y
    ///   cuanto habia. Las diferencias NO las ajusta aqui: las ajusta quien lo
    ///   llama con InventarioController.RegistrarMovimiento (tipos 4 y 5), el
    ///   mismo camino de cualquier ajuste, con su permiso y su kardex.
    ///
    /// TODO SE ACOTA POR CLIENTE
    ///   @CLIENTE sale de la sesion; los SP rechazan un conteo de otro cliente
    ///   o una ubicacion que no es de la bodega del conteo.
    /// </summary>
    public class InventarioConteoController
    {
        public Respuesta Iniciar(int bodega, string alcance)
        {
            Respuesta r = new Respuesta();
            if (!Token.TokenSeguridad()) { r.error = true; r.detalle = "La sesión expiró."; return r; }

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("INS_INVENTARIO_CONTEO");
                cmd.Parameters.AddWithValue("@ID", 0).Direction = ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@BODEGA", bodega);
                cmd.Parameters.AddWithValue("@ALCANCE", (object)alcance ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    if (dr.Read()) r.codigo = Convert.ToInt32(dr["ID"]);
                cmd.Connection.Close();
                r.detalle = "Conteo iniciado.";
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                r.error = true; r.codigo = -1; r.detalle = ex.Message;
            }
            return r;
        }

        /// <summary>Registra (o recuenta) una caja del conteo.</summary>
        public Respuesta RegistrarCaja(int conteo, int repuesto, int ubicacion, decimal sistema, decimal contado, string movimientos, string resultado)
        {
            Respuesta r = new Respuesta();
            if (!Token.TokenSeguridad()) { r.error = true; r.detalle = "La sesión expiró."; return r; }

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("UPS_INVENTARIO_CONTEO_DETALLE");
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@CONTEO", conteo);
                cmd.Parameters.AddWithValue("@REPUESTO", repuesto);
                cmd.Parameters.AddWithValue("@UBICACION", ubicacion);
                cmd.Parameters.AddWithValue("@SISTEMA", sistema);
                cmd.Parameters.AddWithValue("@CONTADO", contado);
                cmd.Parameters.AddWithValue("@MOVIMIENTOS", string.IsNullOrEmpty(movimientos) ? (object)DBNull.Value : movimientos);
                cmd.Parameters.AddWithValue("@RESULTADO", string.IsNullOrEmpty(resultado) ? (object)DBNull.Value : resultado);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                using (SqlDataReader dr = Conexion.GetDataReader(cmd)) dr.Read();
                cmd.Connection.Close();
                r.codigo = conteo;
                r.detalle = "Caja contada.";
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                r.error = true; r.codigo = -1; r.detalle = ex.Message;
            }
            return r;
        }

        /// <summary>Cierra el conteo. Devuelve la fila del resumen (o null si fallo).</summary>
        public DataRow Cerrar(int conteo, out string error)
        {
            error = null;
            if (!Token.TokenSeguridad()) { error = "La sesión expiró."; return null; }

            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = "UPD_INVENTARIO_CONTEO_CERRAR";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ID", conteo);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                DataTable dt = Conexion.GetDataTable(cmd);
                return dt.Rows.Count > 0 ? dt.Rows[0] : null;
            }
            catch (Exception ex)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                error = ex.Message;
                return null;
            }
        }

        /// <summary>El ultimo conteo de cada ubicacion de la planta.</summary>
        public DataTable GetUltimos(int instalacion)
        {
            if (!Token.TokenSeguridad()) return new DataTable();

            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = "SEL_INVENTARIO_CONTEO_ULTIMO";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@INSTALACION", instalacion > 0 ? (object)instalacion : DBNull.Value);
                return Conexion.GetDataTable(cmd);
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                return new DataTable();
            }
        }
    }
}
