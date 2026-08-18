using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    public class NacionalidadController
    {
        private SqlCommand cmdExecute = null;

        //Listo todas las nacionalidades (grilla)
        public List<Nacionalidad> GetNacionalidades(Nacionalidad nacionalidades)
        {
            List<Nacionalidad> nacionalidad = new List<Nacionalidad>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_NACIONALIDAD";

                    if (!string.IsNullOrEmpty(nacionalidades.filtro)) cmd.Parameters.AddWithValue("@FILTRO", nacionalidades.filtro);
                    if (!string.IsNullOrEmpty(nacionalidades.filtro_habilitado)) cmd.Parameters.AddWithValue("@HABILITADO", nacionalidades.filtro_habilitado);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Nacionalidad item = new Nacionalidad();

                            item.nac_id = int.Parse(dr["NAC_ID"].ToString());
                            item.nac_nombres = dr["NAC_NOMBRE"].ToString();
                            item.nac_habilitado = bool.Parse(dr["NAC_HABILITADO"].ToString());
                            item.nac_usuario_creacion = int.Parse(dr["NAC_USUARIO_CREACION"].ToString());
                            item.nac_fecha_creacion = DateTime.Parse(dr["NAC_FECHA_CREACION"].ToString());
                            item.nac_usuario_actualizacion = int.Parse(dr["NAC_USUARIO_ACTUALIZACION"].ToString());
                            item.nac_fecha_actualizacion = DateTime.Parse(dr["NAC_FECHA_CREACION"].ToString());

                            nacionalidad.Add(item);
                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();

                    nacionalidad = null;
                }
            }
            return nacionalidad;
        }

        //Listo datos de una nacionalidad
        public Nacionalidad GetNacionalidad(Nacionalidad nacionalidad)
        {
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_NACIONALIDAD";
                    cmd.Parameters.AddWithValue("@ID", nacionalidad.nac_id);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read())
                        {
                            nacionalidad = new Nacionalidad();

                            nacionalidad.nac_id = int.Parse(dr["NAC_ID"].ToString());
                            nacionalidad.nac_nombres = dr["NAC_NOMBRE"].ToString();
                            nacionalidad.nac_habilitado = bool.Parse(dr["NAC_HABILITADO"].ToString());
                            nacionalidad.nac_usuario_creacion = int.Parse(dr["NAC_USUARIO_CREACION"].ToString());
                            nacionalidad.nac_fecha_creacion = DateTime.Parse(dr["NAC_FECHA_CREACION"].ToString());
                            nacionalidad.nac_usuario_actualizacion = int.Parse(dr["NAC_USUARIO_ACTUALIZACION"].ToString());
                            nacionalidad.nac_fecha_actualizacion = DateTime.Parse(dr["NAC_FECHA_CREACION"].ToString());

                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();

                    nacionalidad = null;
                }
            }
            return nacionalidad;
        }

        //Inserto registro
        public Respuesta InsertNacionalidad(Nacionalidad nacionalidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_NACIONALIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", nacionalidad.nac_nombres);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", nacionalidad.nac_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Nacionalidad creada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }
            return respuesta;
        }

        //Actualizo registro
        public Respuesta UpdateNacionalidad(Nacionalidad nacionalidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                try
                {
                    SqlCommand cmdExecute = Conexion.GetCommand("UPD_NACIONALIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", nacionalidad.nac_id);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", nacionalidad.nac_nombres);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", nacionalidad.nac_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = 0;
                    respuesta.detalle = "Nacionalidad actualizada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    cmdExecute.Connection.Close();
                    cmdExecute.Dispose();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }
            return respuesta;
        }

        //Elimino registro(s)
        public Respuesta DeleteNacionalidad(Nacionalidad nacionalidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                try
                {
                    SqlCommand cmdExecute = Conexion.GetCommand("DEL_NACIONALIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", nacionalidad.nac_id);

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = 0;
                    respuesta.detalle = "Nacionalidad eliminada con éxito.";
                    respuesta.error = false;

                }
                catch (Exception ex)
                {
                    cmdExecute.Connection.Close();
                    cmdExecute.Dispose();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }
            return respuesta;
        }
    }
}