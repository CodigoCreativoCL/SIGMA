using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// El cliente con el que se trabaja durante la sesion (HU-002).
    ///
    /// Una persona puede prestar servicios a varias empresas. Elegir con
    /// cual trabaja no es una preferencia: define QUE DATOS ve, porque casi
    /// todas las consultas del sistema se filtran por el cliente en sesion.
    /// </summary>
    public class ClienteSesionController
    {
        /// <summary>
        /// Clientes a los que la persona pertenece y que estan habilitados.
        /// </summary>
        public List<Cliente> GetClientesElegibles(int idUsuario)
        {
            List<Cliente> lista = new List<Cliente>();

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_CLIENTE_USUARIO_ELEGIBLE";
                cmd.Parameters.AddWithValue("@USUARIO", idUsuario);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        Cliente item = new Cliente();

                        item.cli_id = int.Parse(dr["CLI_ID"].ToString());
                        item.cli_nombre = dr["CLI_ETIQUETA"].ToString();
                        item.cli_razon_social = dr["CLI_RAZON_SOCIAL"].ToString();
                        item.cli_identificador = dr["CLI_IDENTIFICADOR"].ToString();

                        lista.Add(item);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                lista = null;
            }

            return lista;
        }

        /// <summary>
        /// Resuelve a donde va la persona despues de entrar.
        ///
        ///   0 clientes  -> cuenta de plataforma: sigue a la pantalla de
        ///                  inicio sin cliente. Es quien da de alta al
        ///                  primero, asi que exigirle uno seria un circulo.
        ///   1 cliente   -> se elige solo y NO se muestra el selector
        ///                  (HU-002 escenario 1).
        ///   varios      -> hay que elegir antes de continuar (escenario 2).
        ///
        /// Devuelve la URL a la que hay que ir.
        /// </summary>
        public string ResolverClienteInicial(int idUsuario)
        {
            List<Cliente> clientes = GetClientesElegibles(idUsuario);

            if (clientes == null || clientes.Count == 0)
                return "~/Default.aspx";

            if (clientes.Count == 1)
            {
                Session.SetCliente(clientes[0].cli_id, clientes[0].cli_nombre);
                return "~/Default.aspx";
            }

            return "~/SeleccionarCliente.aspx";
        }

        /// <summary>
        /// Cambia el cliente de trabajo.
        ///
        /// Se vuelve a comprobar que la persona pertenezca al cliente y no
        /// se confia en lo que llego del navegador: el id viaja en un combo
        /// y un combo se puede manipular. Sin esta comprobacion, cualquiera
        /// podria escribir el id de otra empresa y ver sus datos.
        /// </summary>
        public Respuesta CambiarCliente(int idUsuario, int idCliente)
        {
            Respuesta respuesta = new Respuesta();

            List<Cliente> clientes = GetClientesElegibles(idUsuario);

            if (clientes == null)
            {
                respuesta.error = true;
                respuesta.detalle = "No fue posible leer sus clientes.";
                return respuesta;
            }

            Cliente elegido = clientes.FirstOrDefault(x => x.cli_id == idCliente);

            if (elegido == null)
            {
                // Mismo mensaje que si el cliente no existiera: no se le
                // confirma a nadie que ese id corresponde a una empresa real.
                respuesta.error = true;
                respuesta.detalle = "El cliente seleccionado no está disponible.";
                return respuesta;
            }

            Session.SetCliente(elegido.cli_id, elegido.cli_nombre);

            respuesta.error = false;
            respuesta.codigo = elegido.cli_id;
            respuesta.detalle = elegido.cli_nombre;

            return respuesta;
        }
    }
}
