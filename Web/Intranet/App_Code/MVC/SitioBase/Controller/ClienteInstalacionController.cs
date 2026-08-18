using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using SitioBase.Model;
using SitioBase;


namespace SitioBase.Controller
{
    public class ClienteInstalacionController
    {
        private SqlCommand cmdExecute = null;

        //Listo todas las nacionalidades (grilla)
        public List<ClienteInstalacion> GetClienteInstalaciones(ClienteInstalacion clienteInstalacion)
        {
            List<ClienteInstalacion> clienteInstalaciones = new List<ClienteInstalacion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                //try
                //{
                    cmd.CommandText = "SEL_CLIENTE_INSTALACION";

                    if (!string.IsNullOrEmpty(clienteInstalacion.filtro)) cmd.Parameters.AddWithValue("@FILTRO", clienteInstalacion.filtro);
                    if (!string.IsNullOrEmpty(clienteInstalacion.filtro_cliente)) cmd.Parameters.AddWithValue("@CLIENTE", clienteInstalacion.filtro_cliente);
                    if (clienteInstalacion.usuario > 0) cmd.Parameters.AddWithValue("@USUARIO", clienteInstalacion.usuario);
                    if (!string.IsNullOrEmpty(clienteInstalacion.filtro_paises)) cmd.Parameters.AddWithValue("@PAISES", clienteInstalacion.filtro_paises);
                    if (clienteInstalacion.cin_usuario_creacion > 0) cmd.Parameters.AddWithValue("@USUARIO_CLIENTE", clienteInstalacion.cin_usuario_creacion);
                    if (clienteInstalacion.cin_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", clienteInstalacion.cin_cliente);


                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                        clienteInstalacion = new ClienteInstalacion();

                            clienteInstalacion.cin_id = int.Parse(dr["CIN_ID"].ToString());
                            clienteInstalacion.cin_nombre = dr["CIN_NOMBRE"].ToString();
                            clienteInstalacion.cin_descripcion = dr["CIN_DESCRIPCION"].ToString();
                            clienteInstalacion.cin_direccion = dr["CIN_DIRECCION"].ToString();
                            clienteInstalacion.cin_habilitado = bool.Parse(dr["CIN_HABILITADO"].ToString());
                            clienteInstalacion.cin_usuario_creacion = int.Parse(dr["CIN_USUARIO_CREACION"].ToString());
                            clienteInstalacion.cin_fecha_creacion = DateTime.Parse(dr["CIN_FECHA_CREACION"].ToString());
                            clienteInstalacion.cin_usuario_actualizacion = int.Parse(dr["CIN_USUARIO_ACTUALIZACION"].ToString());
                            clienteInstalacion.cin_fecha_actualizacion = DateTime.Parse(dr["CIN_FECHA_CREACION"].ToString());

                            clienteInstalaciones.Add(clienteInstalacion);
                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                //}
                //catch (Exception ex)
                //{
                //    cmd.Connection.Close();
                //    cmd.Dispose();

                //    clienteInstalacion = null;
                //}
            }
            return clienteInstalaciones;
        }

        //Listo datos de una nacionalidad
        public ClienteInstalacion GetClienteInstalacion(ClienteInstalacion clienteInstalacion)
        {
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CLIENTE_INSTALACION";
                    cmd.Parameters.AddWithValue("@ID", clienteInstalacion.cin_id);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read())
                        {
                            clienteInstalacion = new ClienteInstalacion();

                            clienteInstalacion.cin_id = int.Parse(dr["CIN_ID"].ToString());
                            clienteInstalacion.cin_nombre = dr["CIN_NOMBRE"].ToString();
                            clienteInstalacion.cin_descripcion = dr["CIN_DESCRIPCION"].ToString();
                            clienteInstalacion.cin_direccion = dr["CIN_DIRECCION"].ToString();
                            clienteInstalacion.cin_habilitado = bool.Parse(dr["CIN_HABILITADO"].ToString());
                            clienteInstalacion.cin_usuario_creacion = int.Parse(dr["CIN_USUARIO_CREACION"].ToString());
                            clienteInstalacion.cin_fecha_creacion = DateTime.Parse(dr["CIN_FECHA_CREACION"].ToString());
                            clienteInstalacion.cin_usuario_actualizacion = int.Parse(dr["CIN_USUARIO_ACTUALIZACION"].ToString());
                            clienteInstalacion.cin_fecha_actualizacion = DateTime.Parse(dr["CIN_FECHA_CREACION"].ToString());

                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();

                    clienteInstalacion = null;
                }
            }
            return clienteInstalacion;
        }

        //Inserto registro
        public Respuesta InsertClienteInstalacion(ClienteInstalacion clienteInstalacion)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_CLIENTE_INSTALACION");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", clienteInstalacion.cin_cliente);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", clienteInstalacion.cin_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", clienteInstalacion.cin_descripcion);
                    cmdExecute.Parameters.AddWithValue("@DIRECCION", clienteInstalacion.cin_direccion);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", clienteInstalacion.cin_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Instalación creada con éxito.";
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
        public Respuesta UpdateClienteInstalacion(ClienteInstalacion clienteInstalacion)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                try
                {
                    SqlCommand cmdExecute = Conexion.GetCommand("UPD_CLIENTE_INSTALACION");
                    cmdExecute.Parameters.AddWithValue("@ID", clienteInstalacion.cin_id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", clienteInstalacion.cin_cliente);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", clienteInstalacion.cin_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", clienteInstalacion.cin_descripcion);
                    cmdExecute.Parameters.AddWithValue("@DIRECCION", clienteInstalacion.cin_direccion);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", clienteInstalacion.cin_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = 0;
                    respuesta.detalle = "Instalación actualizada con éxito.";
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
        public Respuesta DeleteClienteInstalacion(ClienteInstalacion clienteInstalacion)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                try
                {
                    SqlCommand cmdExecute = Conexion.GetCommand("DEL_CLIENTE_INSTALACION");
                    cmdExecute.Parameters.AddWithValue("@ID", clienteInstalacion.cin_id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = 0;
                    respuesta.detalle = "Instalación eliminada con éxito.";
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