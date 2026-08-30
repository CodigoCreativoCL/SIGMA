using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using Sigma.Model;
using SitioBase;

namespace Sigma.Controller
{
    /// <summary>
    /// CONTROLLER de la entidad CLIENTE.
    ///
    /// REGLAS DEL PATRON (ver PATRON_MVC.md seccion 3):
    ///  1. Namespace Sigma.Controller. Una clase por entidad.
    ///  2. TODA operacion arranca con if (Token.TokenSeguridad()).
    ///  3. NUNCA SQL embebido. Siempre Stored Procedures:
    ///        SEL_CLIENTE  INS_CLIENTE  UPD_CLIENTE  DEL_CLIENTE
    ///  4. Acceso a datos SIEMPRE via SitioBase.Conexion.
    ///  5. Los metodos de escritura devuelven SitioBase.Respuesta.
    ///  6. try/catch en todos los metodos, cerrando la conexion en AMBOS caminos.
    ///  7. Los parametros de filtro se agregan SOLO si vienen informados.
    ///
    /// ARCHIVO GENERADO por 03-Generador.
    /// </summary>
    public class ClienteController
    {
        #region LECTURA

        /// <summary>
        /// LISTADO. Se usa como DataSource del RadGrid2.
        /// Recibe un Model que actua SOLO como bolsa de filtros.
        /// </summary>
        public List<Cliente> GetClientes(Cliente cliente = null)
        {
            List<Cliente> clientes = new List<Cliente>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_CLIENTE";

                    // Cada filtro se agrega SOLO si viene informado. Lo que no se
                    // agrega llega al SP como NULL y ese IF del WHERE no se concatena.
                    if (cliente != null)
                    {
                        if (cliente.cli_id > 0)
                            cmd.Parameters.AddWithValue("@ID", cliente.cli_id);

                        if (!string.IsNullOrEmpty(cliente.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", cliente.filtro);

                        if (cliente.filtro_habilitado.HasValue)
                            cmd.Parameters.AddWithValue("@HABILITADO", cliente.filtro_habilitado.Value);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Cliente item = new Cliente();

                            item.cli_id = int.Parse(dr["CLI_ID"].ToString());
                            item.cli_nombre = dr["CLI_NOMBRE"].ToString();
                            item.cli_habilitado = bool.Parse(dr["CLI_HABILITADO"].ToString());

                            clientes.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    // En los Get devolvemos null para que la vista distinga
                    // "error" de "lista vacia".
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    clientes = null;
                }
            }

            return clientes;
        }

        /// <summary>
        /// REGISTRO UNICO. Se usa al abrir el formulario de edicion.
        /// Reutiliza el mismo SP SEL_CLIENTE pasandole @ID.
        /// </summary>
        public Cliente GetCliente(Cliente cliente)
        {
            Cliente item = new Cliente();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_CLIENTE";
                    cmd.Parameters.AddWithValue("@ID", cliente.cli_id);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            item.cli_id = int.Parse(dr["CLI_ID"].ToString());
                            item.cli_nombre = dr["CLI_NOMBRE"].ToString();
                            item.cli_habilitado = bool.Parse(dr["CLI_HABILITADO"].ToString());
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    item = null;
                }
            }

            return item;
        }

        #endregion

        #region ESCRITURA

        /// <summary>
        /// ALTA. El SP INS_CLIENTE devuelve el id generado por el parametro @ID OUTPUT.
        /// </summary>
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

                    // @ID SIEMPRE primero y como OUTPUT: el SP hace SET @ID = SCOPE_IDENTITY().
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = ParameterDirection.Output;

                    cmdExecute.Parameters.AddWithValue("@NOMBRE", (object)cliente.cli_nombre ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", cliente.cli_habilitado);

                    // La auditoria NUNCA la manda la pantalla: se toma de la sesion.
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Cliente creado con exito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.codigo = -1;
                    // ex.Message trae el texto del RAISERROR del SP.
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// MODIFICACION. Mismo patron que el alta pero con @ID de entrada.
        /// </summary>
        public Respuesta UpdateCliente(Cliente cliente)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_CLIENTE");

                    cmdExecute.Parameters.AddWithValue("@ID", cliente.cli_id);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", (object)cliente.cli_nombre ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", cliente.cli_habilitado);

                    // La auditoria NUNCA la manda la pantalla: se toma de la sesion.
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = cliente.cli_id;
                    respuesta.detalle = "Cliente actualizado con exito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// BAJA. CLIENTE es una tabla MAESTRO: el patron pide baja LOGICA
        /// (UPD_CLIENTE con @HABILITADO = 0), no DELETE fisico.
        /// DEL_CLIENTE existe solo para casos excepcionales.
        /// </summary>
        public Respuesta DeleteCliente(Cliente cliente)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_CLIENTE");
                    cmdExecute.Parameters.AddWithValue("@ID", cliente.cli_id);

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = cliente.cli_id;
                    respuesta.detalle = "Cliente eliminado con exito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// BAJA LOGICA: la que realmente usa el boton "Deshabilitar" del grid.
        /// Reutiliza UPD_CLIENTE en vez de crear un SP nuevo.
        /// </summary>
        public Respuesta DeshabilitarCliente(Cliente cliente)
        {
            cliente.cli_habilitado = false;
            Respuesta respuesta = UpdateCliente(cliente);

            if (!respuesta.error)
                respuesta.detalle = "Cliente deshabilitado con exito.";

            return respuesta;
        }

        #endregion
    }
}
