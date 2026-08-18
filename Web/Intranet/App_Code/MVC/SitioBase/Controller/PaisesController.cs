using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    public class PaisesController
    {
        private SqlCommand cmdExecute = null;

        public List<Paises> GetPaises(Paises filtro = null)
        {
            List<Paises> paises = new List<Paises>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PAISES";
                    if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    if (!string.IsNullOrEmpty(filtro.filtro_cliente)) cmd.Parameters.AddWithValue("@FILTRO_CLIENTE", filtro.filtro_cliente);
                    if (!string.IsNullOrEmpty(filtro.filtro_instalacion)) cmd.Parameters.AddWithValue("@FILTRO_INSTALACION", filtro.filtro_instalacion);
                    if (!string.IsNullOrEmpty(filtro.filtro_habilitado)) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                    if (filtro.pai_usuario_creacion > 0) cmd.Parameters.AddWithValue("@USUARIO", filtro.pai_usuario_creacion);
                    if (filtro.filtro_pais != "") cmd.Parameters.AddWithValue("@PAISES", filtro.filtro_pais);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Paises pais = new Paises();

                            pais.pai_id = int.Parse(dr["PAI_ID"].ToString());
                            pais.pai_nombres = dr["PAI_NOMBRE"].ToString();                            
                            pais.pai_habilitado = bool.Parse(dr["PAI_HABILITADO"].ToString());
                            pais.pai_usuario_creacion = int.Parse(dr["PAI_USUARIO_CREACION"].ToString());
                            pais.pai_fecha_creacion = DateTime.Parse(dr["PAI_FECHA_CREACION"].ToString());
                            pais.pai_usuario_actualizacion = int.Parse(dr["PAI_USUARIO_ACTUALIZACION"].ToString());
                            pais.pai_fecha_actualizacion = DateTime.Parse(dr["PAI_FECHA_ACTUALIZACION"].ToString());

                            paises.Add(pais);
                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();

                    paises = null;
                }
            }
            return paises;
        }

        public Paises GetPais(Paises pais)
        {
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PAISES";
                    cmd.Parameters.AddWithValue("@ID", pais.pai_id);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read())
                        {
                            pais = new Paises();

                            pais.pai_id = int.Parse(dr["PAI_ID"].ToString());
                            pais.pai_nombres = dr["PAI_NOMBRE"].ToString();
                            pais.pai_hora = int.Parse(dr["PAI_HORA"].ToString());
                            pais.pai_suma_resta = dr["PAI_SUMA_RESTA"].ToString();
                            pais.pai_habilitado = bool.Parse(dr["PAI_HABILITADO"].ToString());
                            pais.pai_usuario_creacion = int.Parse(dr["PAI_USUARIO_CREACION"].ToString());
                            pais.pai_fecha_creacion = DateTime.Parse(dr["PAI_FECHA_CREACION"].ToString());
                            pais.pai_usuario_actualizacion = int.Parse(dr["PAI_USUARIO_ACTUALIZACION"].ToString());
                            pais.pai_fecha_actualizacion = DateTime.Parse(dr["PAI_FECHA_ACTUALIZACION"].ToString());   
                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();

                    pais = null;
                }
            }
            return pais;
        }

        public Respuesta InsertPais(Paises pais)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_PAISES");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", pais.pai_nombres);
                    cmdExecute.Parameters.AddWithValue("@SUMA_RESTA", pais.pai_suma_resta);
                    cmdExecute.Parameters.AddWithValue("@HORA", pais.pai_hora);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", pais.pai_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "País creado con éxito.";
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

        public Respuesta UpdatePais(Paises pais)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                try
                {
                    SqlCommand cmdExecute = Conexion.GetCommand("UPD_PAISES");
                    cmdExecute.Parameters.AddWithValue("@ID", pais.pai_id);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", pais.pai_nombres);
                    cmdExecute.Parameters.AddWithValue("@SUMA_RESTA", pais.pai_suma_resta);
                    cmdExecute.Parameters.AddWithValue("@HORA", pais.pai_hora);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", pais.pai_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = 0;
                    respuesta.detalle = "País actualizado con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;

                }
            }
            return respuesta;
        }

        public Respuesta DeletePais(Paises pais)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                try
                {
                    SqlCommand cmdExecute = Conexion.GetCommand("DEL_PAISES");
                    cmdExecute.Parameters.AddWithValue("@ID", pais.pai_id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.Parameters.AddWithValue("@PAIS", Session.UsuarioIdPaises());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = 0;
                    respuesta.detalle = "País eliminado con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;

                }
            }
            return respuesta;
        }
    }
}