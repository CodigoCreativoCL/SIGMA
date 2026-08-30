using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase.Model;
using SitioBase;


namespace SitioBase.Controller
{
    public class ClienteAppInstalacionController
    {
        private SqlCommand cmdExecute = null;

        public List<ClienteAppInstalacion> GetClienteAppIntalaciones(ClienteAppInstalacion clienteAppInstalacion)
        {
            List<ClienteAppInstalacion> clienteAppInstalacions = new List<ClienteAppInstalacion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CLIENTE_APP_INSTALACION";
                    cmd.Parameters.AddWithValue("@ID_INSTALACION", clienteAppInstalacion.cai_id_instalacion);

                    /* El cliente decide QUE se ofrece: el SP solo lista las
                       funcionalidades que su plan incluye. Sin este parametro
                       el SP lo deduce de la planta, pero mandarlo evita una
                       consulta y deja explicito de quien es el plan. */
                    if (clienteAppInstalacion.id_cliente > 0)
                        cmd.Parameters.AddWithValue("@CLIENTE", clienteAppInstalacion.id_cliente);


                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ClienteAppInstalacion item = new ClienteAppInstalacion();

                            item.app_id = int.Parse(dr["APP_ID"].ToString());
                            item.app_nombre = (dr["APP_NOMBRE"].ToString());
                            item.app_tipo = dr["APP_TIPO"].ToString();
                            item.app_origen = dr["APP_ORIGEN"].ToString();
                            if (dr["CAP_HABILITADO"].ToString() != "") item.cai_habilitado = bool.Parse(dr["CAP_HABILITADO"].ToString());
                            clienteAppInstalacions.Add(item);
                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();

                    clienteAppInstalacions = null;
                }
            }
            return clienteAppInstalacions;
        }

        public Respuesta InsertClienteAppInstalacion(ClienteAppInstalacion clienteAppInstalacion)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_CLIENTE_APP_INSTALACION");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", clienteAppInstalacion.id_cliente);
                    cmdExecute.Parameters.AddWithValue("@INSTALACION", clienteAppInstalacion.cai_id_instalacion);
                    cmdExecute.Parameters.AddWithValue("@ID_APP", clienteAppInstalacion.cai_id_app);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", clienteAppInstalacion.cai_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Cliente app instalación activado/desactivado con éxito.";
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

    }
}