using SitioBase;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase.Model;

namespace SitioBase.Controller
{
    public class PerfilController
    {
        public List<Perfil> ListoPerfiles(Perfil perfil = null)
        {
            List<Perfil> perfiles = new List<Perfil>();
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_PERFILES";
                if (!string.IsNullOrEmpty(perfil.filtro_habilitado)) cmd.Parameters.AddWithValue("@HABILITADO", perfil.filtro_habilitado);
                if (!string.IsNullOrEmpty(perfil.tipo)) cmd.Parameters.AddWithValue("@TIPO", perfil.tipo);
                if (!string.IsNullOrEmpty(perfil.Perfiles)) cmd.Parameters.AddWithValue("@PERFILES", perfil.Perfiles);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        perfil = new Perfil();

                        perfil.per_id = int.Parse(dr["PER_ID"].ToString());
                        perfil.per_nombre = dr["PER_NOMBRE"].ToString();
                        perfil.per_descripcion = dr["PER_DESCRIPCION"].ToString();
                        perfil.per_habilitado = bool.Parse(dr["PER_HABILITADO"].ToString());
                        perfil.tipo = dr["TIPO"].ToString();

                        perfiles.Add(perfil);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();

                return perfiles;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();

                return null;
            }
        }

        public Perfil GetPerfiles(Perfil perfil)
        {
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_PERFILES";
                cmd.Parameters.AddWithValue("@ID", perfil.per_id);
                


                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {
                        perfil = new Perfil();

                        perfil.per_id = int.Parse(dr["PER_ID"].ToString());
                        // per_tipo es anulable: sin guarda, un perfil con el
                        // tipo vacio voltea la ficha en vez de abrirse.
                        if (dr["PER_TIPO"] != DBNull.Value)
                            perfil.per_tipo = int.Parse(dr["PER_TIPO"].ToString());
                        perfil.per_nombre = dr["PER_NOMBRE"].ToString();
                        perfil.per_descripcion = dr["PER_DESCRIPCION"].ToString();
                        perfil.per_habilitado = bool.Parse(dr["PER_HABILITADO"].ToString());
                       
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();

                return perfil;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();

                return null;
            }
        }

        public Respuesta InsertItem(Perfil perfil)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                int id = 0;
                SqlCommand cmdExecute = Conexion.GetCommand("INS_PERFIL");

                cmdExecute.Parameters.AddWithValue("@NOMBRE", perfil.per_nombre);
                cmdExecute.Parameters.AddWithValue("@TIPO", perfil.per_tipo);
                cmdExecute.Parameters.AddWithValue("@DESCRIPCION", perfil.per_descripcion);
                cmdExecute.Parameters.AddWithValue("@HABILITADO", perfil.per_habilitado);
                cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                respuesta.detalle = "Registro insertado con exito.";
                respuesta.error = false;

            }
            catch (Exception ex)
            {
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta UpdateItem(Perfil perfil)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                SqlCommand cmdExecute = Conexion.GetCommand("UPD_PERFIL");

                cmdExecute.Parameters.AddWithValue("@ID", perfil.per_id);
                cmdExecute.Parameters.AddWithValue("@NOMBRE", perfil.per_nombre);
                cmdExecute.Parameters.AddWithValue("@TIPO", perfil.per_tipo);
                cmdExecute.Parameters.AddWithValue("@DESCRIPCION", perfil.per_descripcion);
                cmdExecute.Parameters.AddWithValue("@HABILITADO", perfil.per_habilitado);
                cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                respuesta.detalle = "Registro actualizado con éxito.";
                respuesta.error = false;

            }
            catch (Exception ex)
            {
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta DeletePerfil(Perfil item)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                try
                {
                    SqlCommand cmdExecute = Conexion.GetCommand("DEL_PERFILES");

                    cmdExecute.Parameters.AddWithValue("@ID", item.per_id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.Parameters.AddWithValue("@PAIS", Session.UsuarioIdPaises());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.detalle = "Registro eliminado con éxito.";
                }
                catch (Exception ex)
                {
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

    }
}