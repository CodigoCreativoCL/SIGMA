using Agendamiento.Model;
using SitioBase;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace Agendamiento.Controller
{
    public class LogAppController
    {
        // ── Lista ─────────────────────────────────────────────────────────────

        public List<LogApp> GetLogs(LogApp filtro)
        {
            List<LogApp> lista = new List<LogApp>();
            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();
            try 
            {
                cmd.CommandText = "SEL_LOG_APP";

                if (filtro.filtro_id > 0)
                    cmd.Parameters.AddWithValue("@ID", filtro.filtro_id);
                if (!string.IsNullOrWhiteSpace(filtro.filtro))
                    cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                if (!string.IsNullOrWhiteSpace(filtro.filtro_endpoint))
                    cmd.Parameters.AddWithValue("@ENDPOINT", filtro.filtro_endpoint);
                if (filtro.filtro_id_cliente_usuario > 0)
                    cmd.Parameters.AddWithValue("@ID_CLIENTE_USUARIO", filtro.filtro_id_cliente_usuario);
                if (!string.IsNullOrWhiteSpace(filtro.filtro_error))
                    cmd.Parameters.AddWithValue("@ERROR", Convert.ToByte(filtro.filtro_error));
                if (!string.IsNullOrWhiteSpace(filtro.filtro_desde))
                    cmd.Parameters.AddWithValue("@DESDE", filtro.filtro_desde);
                if (!string.IsNullOrWhiteSpace(filtro.filtro_hasta))
                    cmd.Parameters.AddWithValue("@HASTA", filtro.filtro_hasta);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                        lista.Add(MapRow(dr));
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return lista;
        }

        // ── Detalle por ID ────────────────────────────────────────────────────

        public LogApp GetLog(int id)
        {
            if (!Token.TokenSeguridad()) return null;

            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = "SEL_LOG_APP";
                cmd.Parameters.AddWithValue("@ID", id);

                LogApp item = null;
                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                        item = MapRow(dr);
                }

                cmd.Connection.Close();
                cmd.Dispose();
                return item;
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
                return null;
            }
        }

        // ── Mapper ────────────────────────────────────────────────────────────

        private static LogApp MapRow(SqlDataReader dr)
        {
            return new LogApp
            {
                lot_id                 = Convert.ToInt32(dr["lot_id"]),
                lot_endpoint           = dr["lot_endpoint"].ToString(),
                lot_metodo             = dr["lot_metodo"].ToString(),
                lot_request            = dr["lot_request"]            == DBNull.Value ? null : dr["lot_request"].ToString(),
                lot_response           = dr["lot_response"]           == DBNull.Value ? null : dr["lot_response"].ToString(),
                lot_error              = Convert.ToBoolean(dr["lot_error"]),
                lot_mensaje_error      = dr["lot_mensaje_error"]      == DBNull.Value ? null : dr["lot_mensaje_error"].ToString(),
                lot_stack_trace        = dr["lot_stack_trace"]        == DBNull.Value ? null : dr["lot_stack_trace"].ToString(),
                lot_id_cliente_usuario = dr["lot_id_cliente_usuario"] == DBNull.Value ? (int?)null : Convert.ToInt32(dr["lot_id_cliente_usuario"]),
                lot_nombre_usuario     = dr["nombre_usuario"]         == DBNull.Value ? null : dr["nombre_usuario"].ToString(),
                lot_usuario            = dr["lot_usuario"]            == DBNull.Value ? null : dr["lot_usuario"].ToString(),
                lot_ip                 = dr["lot_ip"]                 == DBNull.Value ? null : dr["lot_ip"].ToString(),
                lot_duracion_ms        = dr["lot_duracion_ms"]        == DBNull.Value ? (int?)null : Convert.ToInt32(dr["lot_duracion_ms"]),
                lot_fecha_creacion     = dr["lot_fecha_creacion"].ToString()
            };
        }
    }
}
