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
                            if (dr["CLI_PAIS"] != DBNull.Value)
                                item.cli_pais = int.Parse(dr["CLI_PAIS"].ToString());
                            item.cli_razon_social = dr["CLI_RAZON_SOCIAL"].ToString();
                            item.cli_identificador = dr["CLI_IDENTIFICADOR"].ToString();
                            if (dr["CLI_HABILITADO"] != DBNull.Value)
                                item.cli_habilitado = bool.Parse(dr["CLI_HABILITADO"].ToString());
                            /* Mismo motivo que en GetCliente: las columnas de
                               auditoria de Cliente son anulables y un
                               int.Parse("") lanza FormatException. */
                            if (dr["CLI_USUARIO_CREACION"] != DBNull.Value)
                                item.cli_usuario_creacion = int.Parse(dr["CLI_USUARIO_CREACION"].ToString());
                            if (dr["CLI_FECHA_CREACION"] != DBNull.Value)
                                item.cli_fecha_creacion = DateTime.Parse(dr["CLI_FECHA_CREACION"].ToString());
                            if (dr["CLI_USUARIO_ACTUALIZACION"] != DBNull.Value)
                                item.cli_usuario_actualizacion = int.Parse(dr["CLI_USUARIO_ACTUALIZACION"].ToString());
                            if (dr["CLI_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.cli_fecha_actualizacion = DateTime.Parse(dr["CLI_FECHA_ACTUALIZACION"].ToString());

                            // HU-010
                            item.cli_nombre_fantasia = dr["CLI_NOMBRE_FANTASIA"].ToString();
                            item.zho_nombre = dr["ZHO_NOMBRE"].ToString();
                            item.idi_nombre = dr["IDI_NOMBRE"].ToString();
                            item.mon_nombre = dr["MON_NOMBRE"].ToString();

                            if (dr["CLI_ZONA_HORARIA"] != DBNull.Value)
                                item.cli_zona_horaria = int.Parse(dr["CLI_ZONA_HORARIA"].ToString());
                            if (dr["CLI_IDIOMA"] != DBNull.Value)
                                item.cli_idioma = int.Parse(dr["CLI_IDIOMA"].ToString());
                            if (dr["CLI_MONEDA"] != DBNull.Value)
                                item.cli_moneda = int.Parse(dr["CLI_MONEDA"].ToString());
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

        /// <summary>
        /// Sube el logo a Blob y lo deja apuntado en el cliente (bloque 100).
        ///
        /// UN SP CHICO Y NO UPD_CLIENTE
        ///   Poner un logo no es "editar el cliente": es una operacion con un
        ///   solo dato. Meterla en UPD_CLIENTE habria obligado a tocar
        ///   tambien INS_ y SEL_, y las tres equivalentes de Usuario.
        ///
        /// Devuelve el id de Archivo. Lanza si la subida falla: guardar
        /// diciendo que salio bien cuando el logo no quedo es lo peor que
        /// puede pasar aca.
        /// </summary>
        public int GuardarLogo(int idCliente, string nombreArchivo, byte[] contenido, string mime)
        {
            if (contenido == null || contenido.Length == 0)
                throw new Exception("El archivo esta vacio.");

            Archivo archivo = new Archivo();
            archivo.arc_cliente = idCliente;
            archivo.arc_archivo_categoria = 14;   // LOGO CLIENTE
            archivo.arc_nombre_original = nombreArchivo;
            archivo.arc_mime = mime;
            archivo.contenido = contenido;

            ArchivoController ctrlArchivo = new ArchivoController();
            Respuesta subida = ctrlArchivo.InsertArchivo(archivo, "logo");

            if (subida.error)
                throw new Exception("No se pudo guardar el logo: " + subida.detalle);

            Apuntar("UPD_CLIENTE_LOGO", idCliente, subida.codigo, false);

            return subida.codigo;
        }

        /// <summary>Saca el logo. El blob queda: puede estar referenciado.</summary>
        public void QuitarLogo(int idCliente)
        {
            Apuntar("UPD_CLIENTE_LOGO", idCliente, 0, true);
        }

        private void Apuntar(string sp, int idCliente, int idArchivo, bool quitar)
        {
            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand(sp);
                cmd.Parameters.AddWithValue("@CLIENTE", idCliente);
                cmd.Parameters.AddWithValue("@ARCHIVO", idArchivo > 0 ? (object)idArchivo : DBNull.Value);
                cmd.Parameters.AddWithValue("@QUITAR", quitar);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                throw;
            }
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
                            if (dr["CLI_PAIS"] != DBNull.Value)
                                cliente.cli_pais = int.Parse(dr["CLI_PAIS"].ToString());
                            cliente.cli_razon_social = dr["CLI_RAZON_SOCIAL"].ToString();
                            cliente.cli_identificador = dr["CLI_IDENTIFICADOR"].ToString();
                            if (dr["CLI_HABILITADO"] != DBNull.Value)
                                cliente.cli_habilitado = bool.Parse(dr["CLI_HABILITADO"].ToString());
                            /* Las columnas de auditoria de Cliente son
                               anulables: un int.Parse("") sobre ellas lanza
                               FormatException y voltea la pantalla. Se
                               comprueba DBNull antes de parsear. */
                            if (dr["CLI_USUARIO_CREACION"] != DBNull.Value)
                                cliente.cli_usuario_creacion = int.Parse(dr["CLI_USUARIO_CREACION"].ToString());
                            if (dr["CLI_FECHA_CREACION"] != DBNull.Value)
                                cliente.cli_fecha_creacion = DateTime.Parse(dr["CLI_FECHA_CREACION"].ToString());
                            if (dr["CLI_USUARIO_ACTUALIZACION"] != DBNull.Value)
                                cliente.cli_usuario_actualizacion = int.Parse(dr["CLI_USUARIO_ACTUALIZACION"].ToString());
                            if (dr["CLI_FECHA_ACTUALIZACION"] != DBNull.Value)
                                cliente.cli_fecha_actualizacion = DateTime.Parse(dr["CLI_FECHA_ACTUALIZACION"].ToString());

                            // HU-010
                            cliente.cli_nombre_fantasia = dr["CLI_NOMBRE_FANTASIA"].ToString();
                            cliente.zho_nombre = dr["ZHO_NOMBRE"].ToString();
                            cliente.idi_nombre = dr["IDI_NOMBRE"].ToString();
                            cliente.mon_nombre = dr["MON_NOMBRE"].ToString();

                            if (dr["CLI_ZONA_HORARIA"] != DBNull.Value)
                                cliente.cli_zona_horaria = int.Parse(dr["CLI_ZONA_HORARIA"].ToString());
                            if (dr["CLI_IDIOMA"] != DBNull.Value)
                                cliente.cli_idioma = int.Parse(dr["CLI_IDIOMA"].ToString());
                            if (dr["CLI_MONEDA"] != DBNull.Value)
                                cliente.cli_moneda = int.Parse(dr["CLI_MONEDA"].ToString());
                            if (dr["CLI_LOGO"].ToString() != "") cliente.cli_logo = (byte[])dr["CLI_LOGO"];

                            /* El logo ahora vive en Blob (bloque 100).
                               cli_logo se sigue leyendo mientras la columna
                               exista, pero esta vacia para todos. */
                            if (dr["CLI_ARCHIVO_LOGO"] != DBNull.Value)
                                cliente.cli_archivo_logo = int.Parse(dr["CLI_ARCHIVO_LOGO"].ToString());
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

        /// <summary>
        /// La ficha corporativa: los datos, los catálogos ya resueltos, los
        /// conteos y quién la creó.
        ///
        /// Todo en una consulta. Antes la pantalla mostraba `cli_pais` —un
        /// número— y para escribir "Chile" había que ir a buscar cuatro
        /// catálogos por separado desde acá.
        /// </summary>
        public ClienteFicha GetFicha(int idCliente)
        {
            ClienteFicha f = null;

            if (!Token.TokenSeguridad()) return null;

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("SEL_CLIENTE_FICHA");
                cmd.Parameters.AddWithValue("@CLIENTE", idCliente);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {
                        f = new ClienteFicha();

                        f.cli_id = int.Parse(dr["cli_id"].ToString());
                        f.cli_nombre = dr["cli_nombre"].ToString();
                        f.cli_razon_social = dr["cli_razon_social"].ToString();
                        f.cli_nombre_fantasia = dr["cli_nombre_fantasia"].ToString();
                        f.cli_identificador = dr["cli_identificador"].ToString();

                        /* cli_habilitado es NULLable en la tabla. Un cliente
                           sin el dato NO se asume habilitado: el estado es
                           justo lo que decide si su gente puede entrar. */
                        f.cli_habilitado = dr["cli_habilitado"] != DBNull.Value &&
                                           Convert.ToBoolean(dr["cli_habilitado"]);

                        if (dr["cli_archivo_logo"] != DBNull.Value)
                            f.cli_archivo_logo = int.Parse(dr["cli_archivo_logo"].ToString());

                        if (dr["cli_pais"] != DBNull.Value)
                            f.cli_pais = int.Parse(dr["cli_pais"].ToString());

                        f.PAIS_NOMBRE = dr["PAIS_NOMBRE"].ToString();
                        f.IDENTIFICADOR_ROTULO = dr["IDENTIFICADOR_ROTULO"].ToString();

                        if (dr["cli_zona_horaria"] != DBNull.Value)
                            f.cli_zona_horaria = int.Parse(dr["cli_zona_horaria"].ToString());

                        f.ZONA_HORARIA_NOMBRE = dr["ZONA_HORARIA_NOMBRE"].ToString();

                        if (dr["cli_idioma"] != DBNull.Value)
                            f.cli_idioma = int.Parse(dr["cli_idioma"].ToString());

                        f.IDIOMA_NOMBRE = dr["IDIOMA_NOMBRE"].ToString();

                        if (dr["cli_moneda"] != DBNull.Value)
                            f.cli_moneda = int.Parse(dr["cli_moneda"].ToString());

                        f.MONEDA_NOMBRE = dr["MONEDA_NOMBRE"].ToString();

                        f.USUARIOS = int.Parse(dr["USUARIOS"].ToString());
                        f.INSTALACIONES = int.Parse(dr["INSTALACIONES"].ToString());

                        f.CONFIGURACION_COMPLETA = Convert.ToBoolean(dr["CONFIGURACION_COMPLETA"]);
                        f.CONFIGURACION_FALTA = dr["CONFIGURACION_FALTA"].ToString();

                        if (dr["cli_usuario_creacion"] != DBNull.Value)
                            f.cli_usuario_creacion = int.Parse(dr["cli_usuario_creacion"].ToString());

                        if (dr["cli_fecha_creacion"] != DBNull.Value)
                            f.cli_fecha_creacion = DateTime.Parse(dr["cli_fecha_creacion"].ToString());

                        f.USUARIO_CREACION_NOMBRE = dr["USUARIO_CREACION_NOMBRE"].ToString();

                        if (dr["cli_usuario_actualizacion"] != DBNull.Value)
                            f.cli_usuario_actualizacion = int.Parse(dr["cli_usuario_actualizacion"].ToString());

                        if (dr["cli_fecha_actualizacion"] != DBNull.Value)
                            f.cli_fecha_actualizacion = DateTime.Parse(dr["cli_fecha_actualizacion"].ToString());

                        f.USUARIO_ACTUALIZACION_NOMBRE = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                f = null;
            }

            return f;
        }

        public Respuesta InsertCliente(Cliente cliente)
        {
            Respuesta respuesta = new Respuesta();

            /* SIN SESIÓN VÁLIDA SE DICE, NO SE CALLA.

               `Respuesta` nace con error = false, que es el valor por
               omisión de un bool. Cuando esta guarda daba false, el
               método devolvía esa respuesta intacta —sin error, sin
               detalle, con código 0— y la pantalla la leía como éxito:
               mostraba un aviso vacío y no había guardado nada.

               Es la peor forma de fallar: la que se ve igual que
               funcionar. */
            if (!Token.TokenSeguridad())
            {
                respuesta.error = true;
                respuesta.codigo = -1;
                respuesta.detalle = "La sesión no es válida o expiró. Vuelva a iniciar sesión.";
                return respuesta;
            }

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
                    cmdExecute.Parameters.AddWithValue("@NOMBRE_FANTASIA", (object)cliente.cli_nombre_fantasia ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ZONA_HORARIA", (object)cliente.cli_zona_horaria ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@IDIOMA", (object)cliente.cli_idioma ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@MONEDA", (object)cliente.cli_moneda ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", cliente.cli_habilitado);
                    /* AddWithValue CON DBNull INFIERE nvarchar.

                       `cli_logo` es varbinary(max). Cuando el cliente no trae
                       logo —que es lo normal desde que el archivo va a Blob y
                       esta columna quedó sin uso— el parámetro salía tipado
                       como nvarchar y SQL Server rechazaba la sentencia
                       entera con "Implicit conversion from data type nvarchar
                       to varbinary(max) is not allowed".

                       El tipo se declara, no se adivina. */
                    SqlParameter pLogo = cmdExecute.Parameters.Add("@LOGO", System.Data.SqlDbType.VarBinary, -1);
                    pLogo.Value = (object)cliente.cli_logo ?? DBNull.Value;
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
                    cmdExecute.Parameters.AddWithValue("@NOMBRE_FANTASIA", (object)cliente.cli_nombre_fantasia ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ZONA_HORARIA", (object)cliente.cli_zona_horaria ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@IDIOMA", (object)cliente.cli_idioma ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@MONEDA", (object)cliente.cli_moneda ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", cliente.cli_habilitado);
                    /* AddWithValue CON DBNull INFIERE nvarchar.

                       `cli_logo` es varbinary(max). Cuando el cliente no trae
                       logo —que es lo normal desde que el archivo va a Blob y
                       esta columna quedó sin uso— el parámetro salía tipado
                       como nvarchar y SQL Server rechazaba la sentencia
                       entera con "Implicit conversion from data type nvarchar
                       to varbinary(max) is not allowed".

                       El tipo se declara, no se adivina. */
                    SqlParameter pLogo = cmdExecute.Parameters.Add("@LOGO", System.Data.SqlDbType.VarBinary, -1);
                    pLogo.Value = (object)cliente.cli_logo ?? DBNull.Value;

                    // Sin esto, guardar la ficha sin volver a subir la imagen
                    // borraba el logotipo que ya tenia el cliente.
                    cmdExecute.Parameters.AddWithValue("@CAMBIA_LOGO", cliente.cambia_logo);
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

                    /* Desde el bloque 52 DEL_CLIENTE es una baja LOGICA:
                       deshabilita al cliente y a sus afiliaciones, y no
                       borra nada. Decir "eliminado" haria creer que la
                       informacion se fue, y lo primero que hace alguien
                       cuando cree eso es volver a cargarla. */
                    respuesta.detalle = "Cliente dado de baja. Su información se conserva y puede volver a habilitarse.";

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