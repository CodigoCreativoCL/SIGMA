using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using SitioBase.Model;

namespace SitioBase.Controller
{
    public class LogController
    {
        public List<Log> GetLogs(Log log = null)
        {
            List<Log> logs = new List<Log>();
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_LOG_SISTEMA";
                if (!string.IsNullOrEmpty(log.accion)) cmd.Parameters.AddWithValue("@ACCION", log.accion);
                if (!string.IsNullOrEmpty(log.tablas)) cmd.Parameters.AddWithValue("@TABLA", log.tablas);
                if (!string.IsNullOrEmpty(log.usuarios)) cmd.Parameters.AddWithValue("@USUARIO", log.usuarios);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        log = new Log();

                        log.log_id = int.Parse(dr["log_id"].ToString());
                        log.usuario_nombre = dr["usuario_nombre"].ToString();
                        log.loe_nombre = dr["loe_nombre"].ToString();
                        log.log_columna = dr["log_columna"].ToString();
                        log.log_valor_nuevo  = dr["log_valor_nuevo"].ToString();
                        log.log_valor_actual = dr["log_valor_actual"].ToString();
                        log.lot_tabla = dr["lot_tabla"].ToString();
                        log.log_tabla_id = int.Parse(dr["log_tabla_id"].ToString());
                        log.log_fecha_ejecucion = DateTime.Parse(dr["log_fecha_ejecucion"].ToString());

                        logs.Add(log);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
                return logs;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                return logs;
            }
        }

        public List<Log> GetLogTabla(Log log = null)
        {
            List<Log> logs = new List<Log>();
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_LOG_TABLA";

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        log = new Log();

                        log.lot_id = int.Parse(dr["lot_id"].ToString());
                        log.lot_tabla = dr["lot_tabla"].ToString();
                        logs.Add(log);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
                return logs;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                return logs;
            }
        }
    }
}