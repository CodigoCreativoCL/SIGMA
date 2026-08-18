using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using SitioBase.Model;
using SitioBase;
using SitioBase.Controller;


namespace SitioBase.Controller
{
    public class ClienteController
    {
        public List<Cliente> GetClientes(Cliente cliente = null)
        {
            List<Cliente> clientes = new List<Cliente>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CLIENTE";
                    if (cliente.cli_id > 0) cmd.Parameters.AddWithValue("@ID", cliente.cli_id);
                    if (!string.IsNullOrEmpty(cliente.filtro)) cmd.Parameters.AddWithValue("@FILTRO", cliente.filtro);
                    if (!string.IsNullOrEmpty(cliente.filtro_instalacion)) cmd.Parameters.AddWithValue("@FILTRO_INSTALACION", cliente.filtro_instalacion);
                    if (cliente.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", cliente.filtro_habilitado);
                    if (cliente.cli_usuario_creacion > 0) cmd.Parameters.AddWithValue("@USUARIO", cliente.cli_usuario_creacion);
                    if (cliente.filtro_paises != "") cmd.Parameters.AddWithValue("@PAISES", cliente.filtro_paises);
                    if (!string.IsNullOrEmpty(cliente.filtro_usuarios)) cmd.Parameters.AddWithValue("@FILTRO_USUARIOS", cliente.filtro_usuarios);
                    if (cliente.tipo_perfil > 0) cmd.Parameters.AddWithValue("@TIPO_PERFIL", cliente.tipo_perfil);
                    if (!string.IsNullOrEmpty(cliente.filtro_pais)) cmd.Parameters.AddWithValue("@FILTRO_PAIS", cliente.filtro_pais);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Cliente item = new Cliente();

                            item.cli_id = int.Parse(dr["CLI_ID"].ToString());
                            item.cli_nombre = dr["CLI_NOMBRE"].ToString();
                            item.cli_pais = int.Parse(dr["CLI_PAIS"].ToString());
                            item.cli_razon_social = dr["CLI_RAZON_SOCIAL"].ToString();
                            item.cli_identificador = dr["CLI_IDENTIFICADOR"].ToString();
                            item.cli_habilitado = bool.Parse(dr["CLI_HABILITADO"].ToString());
                            item.cli_usuario_creacion = int.Parse(dr["CLI_USUARIO_CREACION"].ToString());
                            item.cli_fecha_creacion = DateTime.Parse(dr["CLI_FECHA_CREACION"].ToString());
                            item.cli_usuario_actualizacion = int.Parse(dr["CLI_USUARIO_ACTUALIZACION"].ToString());
                            item.cli_fecha_actualizacion = DateTime.Parse(dr["CLI_FECHA_ACTUALIZACION"].ToString());
                            item.pai_nombre = dr["PAI_NOMBRE"].ToString();

                            clientes.Add(item);
                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();

                    clientes = null;
                }
            }
            return clientes;
        }

        public Cliente GetCliente(Cliente cliente)
        {
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CLIENTE";
                    cmd.Parameters.AddWithValue("@ID", cliente.cli_id);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read())
                        {
                            cliente = new Cliente();

                            cliente.cli_id = int.Parse(dr["CLI_ID"].ToString());
                            cliente.cli_nombre = dr["CLI_NOMBRE"].ToString();
                            cliente.cli_pais = int.Parse(dr["CLI_PAIS"].ToString());
                            cliente.cli_razon_social = dr["CLI_RAZON_SOCIAL"].ToString();
                            cliente.cli_identificador = dr["CLI_IDENTIFICADOR"].ToString();
                            cliente.cli_habilitado = bool.Parse(dr["CLI_HABILITADO"].ToString());
                            cliente.cli_usuario_creacion = int.Parse(dr["CLI_USUARIO_CREACION"].ToString());
                            cliente.cli_fecha_creacion = DateTime.Parse(dr["CLI_FECHA_CREACION"].ToString());
                            cliente.cli_usuario_actualizacion = int.Parse(dr["CLI_USUARIO_ACTUALIZACION"].ToString());
                            cliente.cli_fecha_actualizacion = DateTime.Parse(dr["CLI_FECHA_ACTUALIZACION"].ToString());
                            if (dr["CLI_LOGO"].ToString() != "") cliente.cli_logo = (byte[])dr["CLI_LOGO"];
                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();

                    cliente = null;
                }
            }
            return cliente;
        }

        public Respuesta InsertCliente(Cliente cliente)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_CLIENTE");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", cliente.cli_nombre);
                    cmdExecute.Parameters.AddWithValue("@PAIS", cliente.cli_pais);
                    cmdExecute.Parameters.AddWithValue("@RAZON_SOCIAL", cliente.cli_razon_social);
                    cmdExecute.Parameters.AddWithValue("@IDENTIFICADOR", cliente.cli_identificador);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", cliente.cli_habilitado);
                    cmdExecute.Parameters.AddWithValue("@LOGO", cliente.cli_logo);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Cliente creado con éxito.";
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

        public Respuesta UpdateCliente(Cliente cliente)
        {
            Respuesta respuesta = new Respuesta();
            SqlCommand cmdExecute = new SqlCommand();

            if (Token.TokenSeguridad())
            {
                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_CLIENTE");
                    cmdExecute.Parameters.AddWithValue("@ID", cliente.cli_id);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", cliente.cli_nombre);
                    cmdExecute.Parameters.AddWithValue("@PAIS", cliente.cli_pais);
                    cmdExecute.Parameters.AddWithValue("@RAZON_SOCIAL", cliente.cli_razon_social);
                    cmdExecute.Parameters.AddWithValue("@IDENTIFICADOR", cliente.cli_identificador);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", cliente.cli_habilitado);
                    cmdExecute.Parameters.AddWithValue("@LOGO", cliente.cli_logo);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = 0;
                    respuesta.detalle = "Cliente actualizado con éxito.";
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

        public Respuesta DeleteCliente(Cliente cliente)
        {
            Respuesta respuesta = new Respuesta();
            SqlCommand cmdExecute = new SqlCommand();

            if (Token.TokenSeguridad())
            {
                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_CLIENTE");
                    cmdExecute.Parameters.AddWithValue("@ID", cliente.cli_id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();
                    cmdExecute.Dispose();

                    respuesta.detalle = "Cliente eliminado con éxito.";

                }
                catch (Exception ex)
                {
                    cmdExecute.Connection.Close();
                    cmdExecute.Dispose();

                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }
            return respuesta;
        }        

    }
}