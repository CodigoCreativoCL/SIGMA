using SitioBase;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase.Model;

namespace SitioBase.Controller
{
    public class ModuloSistemaController
    {
        public List<ModuloSistema> GetModulos(ModuloSistema filtro = null)
        {
            List<ModuloSistema> listado = new List<ModuloSistema>();
            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = "SEL_MODULOS_SISTEMA";

                if (filtro != null)
                {
                    if (filtro.filtro_id.HasValue)
                        cmd.Parameters.AddWithValue("@ID", filtro.filtro_id.Value);
                    if (!string.IsNullOrEmpty(filtro.filtro_nombre))
                        cmd.Parameters.AddWithValue("@NOMBRE", filtro.filtro_nombre);
                    if (!string.IsNullOrEmpty(filtro.filtro_habilitado))
                        cmd.Parameters.AddWithValue("@HABILITADO", Convert.ToByte(filtro.filtro_habilitado));
                }

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        ModuloSistema item = new ModuloSistema();
                        item.mds_id         = int.Parse(dr["mds_id"].ToString());
                        item.mds_nombre     = dr["mds_nombre"].ToString();
                        item.mds_habilitado = Convert.ToBoolean(dr["mds_habilitado"]);
                        item.mds_fecha_creacion = dr["mds_fecha_creacion"] != DBNull.Value ? (DateTime?)Convert.ToDateTime(dr["mds_fecha_creacion"]) : null;
                        item.mds_fecha_act      = dr["mds_fecha_act"]      != DBNull.Value ? (DateTime?)Convert.ToDateTime(dr["mds_fecha_act"])      : null;
                        listado.Add(item);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
                return listado;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                return listado;
            }
        }

        public ModuloSistema GetModulo(int id)
        {
            var filtro = new ModuloSistema { filtro_id = id };
            var list   = GetModulos(filtro);
            return list != null && list.Count > 0 ? list[0] : null;
        }

        public Respuesta InsModulo(ModuloSistema item)
        {
            SqlCommand cmdExecute = new SqlCommand();
            Respuesta respuesta = new Respuesta();

            try
            {
                cmdExecute = Conexion.GetCommand("INS_MODULOS_SISTEMA");
                cmdExecute.Parameters.AddWithValue("@NOMBRE",  item.mds_nombre);
                cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                using (SqlDataReader dr = cmdExecute.ExecuteReader())
                {
                    if (dr.Read())
                        respuesta.codigo = int.Parse(dr["mds_id"].ToString());
                }

                cmdExecute.Connection.Close();
                respuesta.detalle = "Módulo creado con éxito.";
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

            return respuesta;
        }

        public Respuesta UpdModulo(ModuloSistema item)
        {
            SqlCommand cmdExecute = new SqlCommand();
            Respuesta respuesta = new Respuesta();

            try
            {
                cmdExecute = Conexion.GetCommand("UPD_MODULOS_SISTEMA");
                cmdExecute.Parameters.AddWithValue("@ID",         item.mds_id);
                cmdExecute.Parameters.AddWithValue("@NOMBRE",     item.mds_nombre);
                cmdExecute.Parameters.AddWithValue("@HABILITADO", item.mds_habilitado);
                cmdExecute.Parameters.AddWithValue("@USUARIO",    Session.UsuarioId());

                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                respuesta.codigo  = item.mds_id;
                respuesta.detalle = "Módulo actualizado con éxito.";
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

            return respuesta;
        }

        public Respuesta DelModulo(int id)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = new SqlCommand();
                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_MODULOS_SISTEMA");
                    cmdExecute.Parameters.AddWithValue("@ID",      id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.Parameters.AddWithValue("@PAIS", Session.UsuarioIdPaises());


                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.detalle = "Módulo eliminado con éxito.";
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
    }
}
