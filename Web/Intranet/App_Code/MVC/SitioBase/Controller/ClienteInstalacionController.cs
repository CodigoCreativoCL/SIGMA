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
                    if (clienteInstalacion.usuario > 0) cmd.Parameters.AddWithValue("@USUARIO", clienteInstalacion.usuario);
                    if (!string.IsNullOrEmpty(clienteInstalacion.filtro_paises)) cmd.Parameters.AddWithValue("@PAISES", clienteInstalacion.filtro_paises);
                    if (clienteInstalacion.cin_usuario_creacion > 0) cmd.Parameters.AddWithValue("@USUARIO_CLIENTE", clienteInstalacion.cin_usuario_creacion);
                    if (!string.IsNullOrEmpty(clienteInstalacion.filtro_habilitado)) cmd.Parameters.AddWithValue("@HABILITADO", clienteInstalacion.filtro_habilitado);
                    if (clienteInstalacion.cin_id > 0) cmd.Parameters.AddWithValue("@ID", clienteInstalacion.cin_id);

                    // @CLIENTE se agrega UNA sola vez. Antes se agregaba desde
                    // filtro_cliente y otra vez desde cin_cliente: informar los
                    // dos hacia reventar la llamada con "parametro duplicado".
                    if (!string.IsNullOrEmpty(clienteInstalacion.filtro_cliente))
                        cmd.Parameters.AddWithValue("@CLIENTE", clienteInstalacion.filtro_cliente);
                    else if (clienteInstalacion.cin_cliente > 0)
                        cmd.Parameters.AddWithValue("@CLIENTE", clienteInstalacion.cin_cliente);


                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                        clienteInstalacion = new ClienteInstalacion();

                            /* TODAS las columnas anulables de Cliente_Instalacion
                               se leen comprobando DBNull primero.

                               En esta tabla son anulables cin_cliente,
                               cin_habilitado y las cuatro de auditoria. La
                               version anterior hacia int.Parse() directo
                               sobre ellas, y un int.Parse("") lanza
                               FormatException: bastaba una planta cargada
                               sin fecha de actualizacion -que es el estado
                               normal de una recien creada- para voltear la
                               pantalla completa.

                               Como el try/catch de este metodo esta
                               comentado, esa excepcion salia como pagina de
                               error amarilla en vez de una lista vacia. */
                            clienteInstalacion.cin_id = int.Parse(dr["CIN_ID"].ToString());
                            clienteInstalacion.cin_nombre = dr["CIN_NOMBRE"].ToString();
                            clienteInstalacion.cin_descripcion = dr["CIN_DESCRIPCION"].ToString();
                            clienteInstalacion.cin_direccion = dr["CIN_DIRECCION"].ToString();
                            clienteInstalacion.cin_codigo = dr["CIN_CODIGO"].ToString();
                            clienteInstalacion.cli_nombre = dr["CLI_NOMBRE"].ToString();
                            clienteInstalacion.zho_nombre = dr["ZHO_NOMBRE"].ToString();

                            if (dr["CIN_CLIENTE"] != DBNull.Value)
                                clienteInstalacion.cin_cliente = int.Parse(dr["CIN_CLIENTE"].ToString());

                            if (dr["CIN_HABILITADO"] != DBNull.Value)
                                clienteInstalacion.cin_habilitado = bool.Parse(dr["CIN_HABILITADO"].ToString());

                            if (dr["CIN_USUARIO_CREACION"] != DBNull.Value)
                                clienteInstalacion.cin_usuario_creacion = int.Parse(dr["CIN_USUARIO_CREACION"].ToString());

                            if (dr["CIN_FECHA_CREACION"] != DBNull.Value)
                                clienteInstalacion.cin_fecha_creacion = DateTime.Parse(dr["CIN_FECHA_CREACION"].ToString());

                            if (dr["CIN_USUARIO_ACTUALIZACION"] != DBNull.Value)
                                clienteInstalacion.cin_usuario_actualizacion = int.Parse(dr["CIN_USUARIO_ACTUALIZACION"].ToString());

                            // Antes esta linea leia CIN_FECHA_CREACION: la
                            // fecha de actualizacion mostrada era siempre la
                            // de creacion.
                            if (dr["CIN_FECHA_ACTUALIZACION"] != DBNull.Value)
                                clienteInstalacion.cin_fecha_actualizacion = DateTime.Parse(dr["CIN_FECHA_ACTUALIZACION"].ToString());

                            if (dr["CIN_ZONA_HORARIA"] != DBNull.Value)
                                clienteInstalacion.cin_zona_horaria = int.Parse(dr["CIN_ZONA_HORARIA"].ToString());
                            if (dr["CIN_LATITUD"] != DBNull.Value)
                                clienteInstalacion.cin_latitud = decimal.Parse(dr["CIN_LATITUD"].ToString());
                            if (dr["CIN_LONGITUD"] != DBNull.Value)
                                clienteInstalacion.cin_longitud = decimal.Parse(dr["CIN_LONGITUD"].ToString());
                            if (dr["ZONA_HORARIA_EFECTIVA"] != DBNull.Value)
                                clienteInstalacion.zona_horaria_efectiva = int.Parse(dr["ZONA_HORARIA_EFECTIVA"].ToString());

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

                            /* TODAS las columnas anulables de Cliente_Instalacion
                               se leen comprobando DBNull primero.

                               En esta tabla son anulables cin_cliente,
                               cin_habilitado y las cuatro de auditoria. La
                               version anterior hacia int.Parse() directo
                               sobre ellas, y un int.Parse("") lanza
                               FormatException: bastaba una planta cargada
                               sin fecha de actualizacion -que es el estado
                               normal de una recien creada- para voltear la
                               pantalla completa.

                               Como el try/catch de este metodo esta
                               comentado, esa excepcion salia como pagina de
                               error amarilla en vez de una lista vacia. */
                            clienteInstalacion.cin_id = int.Parse(dr["CIN_ID"].ToString());
                            clienteInstalacion.cin_nombre = dr["CIN_NOMBRE"].ToString();
                            clienteInstalacion.cin_descripcion = dr["CIN_DESCRIPCION"].ToString();
                            clienteInstalacion.cin_direccion = dr["CIN_DIRECCION"].ToString();
                            clienteInstalacion.cin_codigo = dr["CIN_CODIGO"].ToString();
                            clienteInstalacion.cli_nombre = dr["CLI_NOMBRE"].ToString();
                            clienteInstalacion.zho_nombre = dr["ZHO_NOMBRE"].ToString();

                            if (dr["CIN_CLIENTE"] != DBNull.Value)
                                clienteInstalacion.cin_cliente = int.Parse(dr["CIN_CLIENTE"].ToString());

                            if (dr["CIN_HABILITADO"] != DBNull.Value)
                                clienteInstalacion.cin_habilitado = bool.Parse(dr["CIN_HABILITADO"].ToString());

                            if (dr["CIN_USUARIO_CREACION"] != DBNull.Value)
                                clienteInstalacion.cin_usuario_creacion = int.Parse(dr["CIN_USUARIO_CREACION"].ToString());

                            if (dr["CIN_FECHA_CREACION"] != DBNull.Value)
                                clienteInstalacion.cin_fecha_creacion = DateTime.Parse(dr["CIN_FECHA_CREACION"].ToString());

                            if (dr["CIN_USUARIO_ACTUALIZACION"] != DBNull.Value)
                                clienteInstalacion.cin_usuario_actualizacion = int.Parse(dr["CIN_USUARIO_ACTUALIZACION"].ToString());

                            // Antes esta linea leia CIN_FECHA_CREACION: la
                            // fecha de actualizacion mostrada era siempre la
                            // de creacion.
                            if (dr["CIN_FECHA_ACTUALIZACION"] != DBNull.Value)
                                clienteInstalacion.cin_fecha_actualizacion = DateTime.Parse(dr["CIN_FECHA_ACTUALIZACION"].ToString());

                            if (dr["CIN_ZONA_HORARIA"] != DBNull.Value)
                                clienteInstalacion.cin_zona_horaria = int.Parse(dr["CIN_ZONA_HORARIA"].ToString());
                            if (dr["CIN_LATITUD"] != DBNull.Value)
                                clienteInstalacion.cin_latitud = decimal.Parse(dr["CIN_LATITUD"].ToString());
                            if (dr["CIN_LONGITUD"] != DBNull.Value)
                                clienteInstalacion.cin_longitud = decimal.Parse(dr["CIN_LONGITUD"].ToString());
                            if (dr["ZONA_HORARIA_EFECTIVA"] != DBNull.Value)
                                clienteInstalacion.zona_horaria_efectiva = int.Parse(dr["ZONA_HORARIA_EFECTIVA"].ToString());

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
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)clienteInstalacion.cin_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@DIRECCION", (object)clienteInstalacion.cin_direccion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", (object)clienteInstalacion.cin_codigo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ZONA_HORARIA", (object)clienteInstalacion.cin_zona_horaria ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@LATITUD", (object)clienteInstalacion.cin_latitud ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@LONGITUD", (object)clienteInstalacion.cin_longitud ?? DBNull.Value);
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
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)clienteInstalacion.cin_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@DIRECCION", (object)clienteInstalacion.cin_direccion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", (object)clienteInstalacion.cin_codigo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ZONA_HORARIA", (object)clienteInstalacion.cin_zona_horaria ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@LATITUD", (object)clienteInstalacion.cin_latitud ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@LONGITUD", (object)clienteInstalacion.cin_longitud ?? DBNull.Value);
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