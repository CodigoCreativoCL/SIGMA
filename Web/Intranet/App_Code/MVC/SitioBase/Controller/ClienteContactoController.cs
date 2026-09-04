using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Los contactos del cliente.
    ///
    /// EL CLIENTE SALE DE LA SESIÓN, NO DEL MODELO
    ///   Igual que en el resto del sitio: si viniera del formulario, quien
    ///   arme el POST a mano podría escribir contactos en la ficha de otra
    ///   empresa. Los SP vuelven a comprobarlo de todos modos.
    /// </summary>
    public class ClienteContactoController
    {
        public List<ClienteContacto> GetContactos(int? id = null, bool soloHabilitados = true)
        {
            List<ClienteContacto> lista = new List<ClienteContacto>();

            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("SEL_CLIENTE_CONTACTO");
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ID", id == null ? (object)DBNull.Value : id.Value);
                cmd.Parameters.AddWithValue("@HABILITADO",
                    soloHabilitados ? (object)true : DBNull.Value);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        ClienteContacto c = new ClienteContacto();

                        c.ccn_id = int.Parse(dr["ccn_id"].ToString());
                        c.ccn_cliente = int.Parse(dr["ccn_cliente"].ToString());
                        c.ccn_nombre = dr["ccn_nombre"].ToString();
                        c.ccn_cargo = dr["ccn_cargo"].ToString();
                        c.ccn_email = dr["ccn_email"].ToString();
                        c.ccn_telefono = dr["ccn_telefono"].ToString();
                        c.ccn_principal = Convert.ToBoolean(dr["ccn_principal"]);
                        c.ccn_habilitado = Convert.ToBoolean(dr["ccn_habilitado"]);

                        c.ccn_usuario_creacion = int.Parse(dr["ccn_usuario_creacion"].ToString());

                        if (dr["ccn_fecha_creacion"] != DBNull.Value)
                            c.ccn_fecha_creacion = DateTime.Parse(dr["ccn_fecha_creacion"].ToString());

                        if (dr["ccn_usuario_actualizacion"] != DBNull.Value)
                            c.ccn_usuario_actualizacion = int.Parse(dr["ccn_usuario_actualizacion"].ToString());

                        if (dr["ccn_fecha_actualizacion"] != DBNull.Value)
                            c.ccn_fecha_actualizacion = DateTime.Parse(dr["ccn_fecha_actualizacion"].ToString());

                        c.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                        c.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();

                        lista.Add(c);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }

            return lista;
        }

        public Respuesta InsertContacto(ClienteContacto entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (!Token.TokenSeguridad())
            {
                /* Una guarda que falla tiene que DECIRLO. Devolver la
                   respuesta en blanco —error=false, que es el valor por
                   omisión de un bool— hace que la pantalla lo lea como éxito
                   y no guarde nada: la peor forma de fallar es la que se ve
                   igual que funcionar. */
                respuesta.error = true;
                respuesta.codigo = -1;
                respuesta.detalle = "La sesión no es válida o expiró.";
                return respuesta;
            }

            SqlCommand cmd = null;

            try
            {
                int id = 0;

                cmd = Conexion.GetCommand("INS_CLIENTE_CONTACTO");
                cmd.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@NOMBRE", entidad.ccn_nombre);
                cmd.Parameters.AddWithValue("@CARGO", (object)entidad.ccn_cargo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@EMAIL", (object)entidad.ccn_email ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@TELEFONO", (object)entidad.ccn_telefono ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@PRINCIPAL", entidad.ccn_principal);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                respuesta.codigo = (int)cmd.Parameters["@ID"].Value;
                respuesta.detalle = "Contacto creado con éxito.";
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta UpdateContacto(ClienteContacto entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (!Token.TokenSeguridad())
            {
                respuesta.error = true;
                respuesta.codigo = -1;
                respuesta.detalle = "La sesión no es válida o expiró.";
                return respuesta;
            }

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("UPD_CLIENTE_CONTACTO");
                cmd.Parameters.AddWithValue("@ID", entidad.ccn_id);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@NOMBRE", (object)entidad.ccn_nombre ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@CARGO", (object)entidad.ccn_cargo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@EMAIL", (object)entidad.ccn_email ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@TELEFONO", (object)entidad.ccn_telefono ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@PRINCIPAL", entidad.ccn_principal);
                cmd.Parameters.AddWithValue("@HABILITADO", entidad.ccn_habilitado);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                respuesta.codigo = entidad.ccn_id;
                respuesta.detalle = "Contacto actualizado con éxito.";
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta DeleteContacto(int id)
        {
            Respuesta respuesta = new Respuesta();

            if (!Token.TokenSeguridad())
            {
                respuesta.error = true;
                respuesta.codigo = -1;
                respuesta.detalle = "La sesión no es válida o expiró.";
                return respuesta;
            }

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("DEL_CLIENTE_CONTACTO");
                cmd.Parameters.AddWithValue("@ID", id);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                respuesta.codigo = id;
                respuesta.detalle = "Contacto eliminado con éxito.";
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }
    }
}
