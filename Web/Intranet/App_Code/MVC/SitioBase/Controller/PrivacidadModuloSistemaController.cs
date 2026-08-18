using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using SitioBase.Model;
using SitioBase;

namespace SitioBase.Controller
{
    public class PrivacidadModuloSistemaController
    {
        // GET LIST 

        public List<PrivacidadModuloSistema> GetPrivacidades(PrivacidadModuloSistema filtro = null)
        {
            List<PrivacidadModuloSistema> listado = new List<PrivacidadModuloSistema>();
            SqlCommand cmd = new SqlCommand();

            if (Token.TokenSeguridad())
            {
                try
                {
                    cmd.CommandText = "SEL_PRIVACIDAD_MODULOS_SISTEMA";

                    if (filtro != null)
                    {
                        if (filtro.filtro_id.HasValue)
                            cmd.Parameters.AddWithValue("@ID", filtro.filtro_id.Value);
                        if (filtro.filtro_id_modulo.HasValue)
                            cmd.Parameters.AddWithValue("@ID_MODULO", filtro.filtro_id_modulo.Value);
                        if (!string.IsNullOrEmpty(filtro.filtro_nombre_modulo))
                            cmd.Parameters.AddWithValue("@NOMBRE_MODULO", filtro.filtro_nombre_modulo);
                        if (!string.IsNullOrEmpty(filtro.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                            listado.Add(MapRow(dr));
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                    listado = null;
                }
            }

            return listado;
        }

        // GET SINGLE 

        public PrivacidadModuloSistema GetPrivacidad(PrivacidadModuloSistema filtro)
        {
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_PRIVACIDAD_MODULOS_SISTEMA";

                if (filtro.filtro_id.HasValue)
                    cmd.Parameters.AddWithValue("@ID", filtro.filtro_id.Value);
                if (filtro.filtro_id_modulo.HasValue)
                    cmd.Parameters.AddWithValue("@ID_MODULO", filtro.filtro_id_modulo.Value);
                if (!string.IsNullOrEmpty(filtro.filtro_nombre_modulo))
                    cmd.Parameters.AddWithValue("@NOMBRE_MODULO", filtro.filtro_nombre_modulo);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    filtro = dr.Read() ? MapRow(dr) : null;
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                filtro = null;
            }

            return filtro;
        }

        public PrivacidadModuloSistema GetPrivacidadPublica(string nombreModulo)
        {
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_PRIVACIDAD_MODULOS_SISTEMA";
                cmd.Parameters.AddWithValue("@NOMBRE_MODULO", nombreModulo);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                        return MapRow(dr);
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                cmd.Connection.Close();
                cmd.Dispose();
            }

            return null;
        }

        public List<PrivacidadModuloSistema> GetPrivacidadesPublicas()
        {
            List<PrivacidadModuloSistema> listado = new List<PrivacidadModuloSistema>();
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_PRIVACIDAD_MODULOS_SISTEMA";

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                        listado.Add(MapRow(dr));
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                cmd.Connection.Close();
                cmd.Dispose();
            }

            return listado;
        }

        // INSERT 

        public Respuesta InsPrivacidad(PrivacidadModuloSistema item)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;
                    cmdExecute = Conexion.GetCommand("INS_PRIVACIDAD_MODULOS_SISTEMA");
                    cmdExecute.Parameters.AddWithValue("@ID",          id).Direction = ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@ID_MODULO",   item.pms_id_modulo);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", item.pms_descripcion ?? "");
                    cmdExecute.Parameters.AddWithValue("@USUARIO",     Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo  = id;
                    respuesta.detalle = "Política de privacidad creada con éxito.";
                    respuesta.error   = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null) cmdExecute.Connection.Close();
                    respuesta.codigo  = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error   = true;
                }
            }

            return respuesta;
        }

        // UPDATE 

        public Respuesta UpdPrivacidad(PrivacidadModuloSistema item)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = new SqlCommand();

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_PRIVACIDAD_MODULOS_SISTEMA");
                    cmdExecute.Parameters.AddWithValue("@ID",          item.pms_id);
                    cmdExecute.Parameters.AddWithValue("@ID_MODULO",   item.pms_id_modulo);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", item.pms_descripcion ?? "");
                    cmdExecute.Parameters.AddWithValue("@USUARIO",     Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo  = item.pms_id;
                    respuesta.detalle = "Política de privacidad actualizada con éxito.";
                    respuesta.error   = false;
                }
                catch (Exception ex)
                {
                    cmdExecute.Connection.Close();
                    cmdExecute.Dispose();
                    respuesta.codigo  = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error   = true;
                }
            }

            return respuesta;
        }

        // DELETE 

        public Respuesta DelPrivacidad(int id)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = new SqlCommand();

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_PRIVACIDAD_MODULOS_SISTEMA");
                    cmdExecute.Parameters.AddWithValue("@ID", id);

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.detalle = "Política de privacidad eliminada con éxito.";
                    respuesta.error   = false;
                }
                catch (Exception ex)
                {
                    cmdExecute.Connection.Close();
                    cmdExecute.Dispose();
                    respuesta.codigo  = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error   = true;
                }
            }

            return respuesta;
        }

        // MAP ROW

        private static PrivacidadModuloSistema MapRow(SqlDataReader dr)
        {
            return new PrivacidadModuloSistema
            {
                pms_id                  = int.Parse(dr["pms_id"].ToString()),
                pms_id_modulo           = int.Parse(dr["pms_id_modulo"].ToString()),
                mds_nombre              = dr["mds_nombre"].ToString(),
                pms_descripcion         = dr["pms_descripcion"].ToString(),
                pms_usuario_creacion    = dr["pms_usuario_creacion"] != DBNull.Value ? int.Parse(dr["pms_usuario_creacion"].ToString()) : 0,
                pms_fecha_creacion      = dr["pms_fecha_creacion"]   != DBNull.Value ? Convert.ToDateTime(dr["pms_fecha_creacion"])    : DateTime.MinValue,
                pms_usuario_act         = dr["pms_usuario_act"]      != DBNull.Value ? int.Parse(dr["pms_usuario_act"].ToString())     : 0,
                pms_fecha_act           = dr["pms_fecha_act"]        != DBNull.Value ? Convert.ToDateTime(dr["pms_fecha_act"])         : DateTime.MinValue,
                usuario_creacion_nombre = dr["usuario_creacion_nombre"].ToString(),
                usuario_act_nombre      = dr["usuario_act_nombre"].ToString()
            };
        }
    }
}
