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
    /// CONTROLLER de la entidad USUARIO.
    ///
    /// REGLAS DEL PATRON (ver 00-Patrones-Originales/PATRON_MVC.md, seccion 3):
    ///  1. Namespace <Proyecto>.Controller. Una clase por entidad: <Entidad>Controller.
    ///  2. TODA operacion arranca con if (Token.TokenSeguridad()) -> si la sesion
    ///     expiro o el token es invalido, el metodo no toca la BD.
    ///  3. NUNCA SQL embebido. Siempre Stored Procedures:
    ///        SEL_<TABLA>  INS_<TABLA>  UPD_<TABLA>  DEL_<TABLA>
    ///  4. Acceso a datos SIEMPRE via SitioBase.Conexion:
    ///        Conexion.GetDataReader(cmd)   -> lectura
    ///        Conexion.GetCommand("SP")     -> escritura
    ///     Nunca abrimos un SqlConnection a mano.
    ///  5. Los metodos de escritura devuelven SitioBase.Respuesta { codigo, detalle, error }.
    ///  6. try/catch en todos los metodos: se cierra y libera la conexion en AMBOS caminos.
    ///  7. Mensajes de exito en espanol, terminados en "con exito.".
    ///  8. Los parametros de filtro se agregan SOLO si vienen informados
    ///     (if (...)), para que el SP los reciba como NULL y no filtre.
    /// </summary>
    public class UsuarioController
    {
        #region LECTURA

        /// <summary>
        /// LISTADO. Se usa como DataSource del RadGrid2.
        /// Convencion de nombre: Get<Entidad>s (plural).
        /// Recibe un Model que actua SOLO como bolsa de filtros.
        /// </summary>
        public List<Usuario> GetUsuarios(Usuario usuario = null)
        {
            List<Usuario> usuarios = new List<Usuario>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_USUARIO";

                    // Cada filtro se agrega SOLO si viene informado.
                    // Lo que no se agrega llega al SP como NULL y ese IF del WHERE no se concatena.
                    if (usuario != null)
                    {
                        if (usuario.usu_id > 0)
                            cmd.Parameters.AddWithValue("@ID", usuario.usu_id);

                        if (!string.IsNullOrEmpty(usuario.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", usuario.filtro);

                        if (usuario.filtro_habilitado.HasValue)
                            cmd.Parameters.AddWithValue("@HABILITADO", usuario.filtro_habilitado.Value);

                        if (usuario.filtro_perfil.HasValue && usuario.filtro_perfil.Value > 0)
                            cmd.Parameters.AddWithValue("@PERFIL", usuario.filtro_perfil.Value);

                        if (usuario.filtro_pais.HasValue && usuario.filtro_pais.Value > 0)
                            cmd.Parameters.AddWithValue("@PAIS", usuario.filtro_pais.Value);

                        // Seguridad por pais: el CSV de paises permitidos del usuario logueado.
                        if (!string.IsNullOrEmpty(usuario.filtro_paises))
                            cmd.Parameters.AddWithValue("@PAISES", usuario.filtro_paises);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Usuario item = new Usuario();

                            // El DataReader devuelve las columnas con el nombre EN MAYUSCULAS
                            // tal como las declara el SELECT del SP.
                            item.usu_id = int.Parse(dr["USU_ID"].ToString());
                            item.usu_rut = dr["USU_RUT"].ToString();
                            item.usu_nombres = dr["USU_NOMBRES"].ToString();
                            item.usu_apellidos = dr["USU_APELLIDOS"].ToString();
                            item.usu_email = dr["USU_EMAIL"].ToString();
                            item.usu_telefono = dr["USU_TELEFONO"].ToString();
                            item.usu_perfil = int.Parse(dr["USU_PERFIL"].ToString());
                            item.usu_pais = int.Parse(dr["USU_PAIS"].ToString());
                            item.usu_habilitado = bool.Parse(dr["USU_HABILITADO"].ToString());

                            // Campos del JOIN: se muestran en el grid.
                            item.per_nombre = dr["PER_NOMBRE"].ToString();
                            item.pai_nombre = dr["PAI_NOMBRE"].ToString();

                            usuarios.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    // Se cierra igual la conexion. En los Get devolvemos null
                    // para que la vista distinga "error" de "lista vacia".
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    usuarios = null;
                }
            }

            return usuarios;
        }

        /// <summary>
        /// REGISTRO UNICO. Se usa al abrir el formulario de edicion.
        /// Reutiliza el mismo SP SEL_USUARIO pasandole @ID: no se crea un SP aparte.
        /// </summary>
        public Usuario GetUsuario(Usuario usuario)
        {
            Usuario item = new Usuario();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_USUARIO";
                    cmd.Parameters.AddWithValue("@ID", usuario.usu_id);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            item.usu_id = int.Parse(dr["USU_ID"].ToString());
                            item.usu_rut = dr["USU_RUT"].ToString();
                            item.usu_nombres = dr["USU_NOMBRES"].ToString();
                            item.usu_apellidos = dr["USU_APELLIDOS"].ToString();
                            item.usu_email = dr["USU_EMAIL"].ToString();
                            item.usu_telefono = dr["USU_TELEFONO"].ToString();
                            item.usu_perfil = int.Parse(dr["USU_PERFIL"].ToString());
                            item.usu_pais = int.Parse(dr["USU_PAIS"].ToString());
                            item.usu_habilitado = bool.Parse(dr["USU_HABILITADO"].ToString());
                            item.per_nombre = dr["PER_NOMBRE"].ToString();
                            item.pai_nombre = dr["PAI_NOMBRE"].ToString();
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
        /// ALTA. El SP INS_USUARIO devuelve el id generado por el parametro @ID OUTPUT.
        /// </summary>
        public Respuesta InsertUsuario(Usuario usuario)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    int id = 0;
                    cmdExecute = Conexion.GetCommand("INS_USUARIO");

                    // @ID SIEMPRE primero y como OUTPUT: el SP hace SET @ID = SCOPE_IDENTITY().
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = ParameterDirection.Output;

                    cmdExecute.Parameters.AddWithValue("@RUT", usuario.usu_rut);
                    cmdExecute.Parameters.AddWithValue("@NOMBRES", usuario.usu_nombres);
                    cmdExecute.Parameters.AddWithValue("@APELLIDOS", usuario.usu_apellidos);
                    cmdExecute.Parameters.AddWithValue("@EMAIL", usuario.usu_email);
                    cmdExecute.Parameters.AddWithValue("@TELEFONO", usuario.usu_telefono);
                    cmdExecute.Parameters.AddWithValue("@PASSWORD", usuario.usu_password);
                    cmdExecute.Parameters.AddWithValue("@PERFIL", usuario.usu_perfil);
                    cmdExecute.Parameters.AddWithValue("@PAIS", usuario.usu_pais);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", usuario.usu_habilitado);

                    // La auditoria NUNCA la manda la pantalla: se toma de la sesion.
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Usuario creado con exito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.codigo = -1;
                    // ex.Message trae el texto del RAISERROR del SP: por eso el SP
                    // escribe mensajes entendibles para el usuario final.
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// MODIFICACION. Mismo patron que el alta pero con @ID de entrada.
        /// </summary>
        public Respuesta UpdateUsuario(Usuario usuario)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_USUARIO");

                    cmdExecute.Parameters.AddWithValue("@ID", usuario.usu_id);
                    cmdExecute.Parameters.AddWithValue("@RUT", usuario.usu_rut);
                    cmdExecute.Parameters.AddWithValue("@NOMBRES", usuario.usu_nombres);
                    cmdExecute.Parameters.AddWithValue("@APELLIDOS", usuario.usu_apellidos);
                    cmdExecute.Parameters.AddWithValue("@EMAIL", usuario.usu_email);
                    cmdExecute.Parameters.AddWithValue("@TELEFONO", usuario.usu_telefono);
                    cmdExecute.Parameters.AddWithValue("@PERFIL", usuario.usu_perfil);
                    cmdExecute.Parameters.AddWithValue("@PAIS", usuario.usu_pais);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", usuario.usu_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    // La password solo se manda si el usuario la cambio.
                    // El SP la actualiza con ISNULL(@PASSWORD, USU_PASSWORD).
                    if (!string.IsNullOrEmpty(usuario.usu_password))
                        cmdExecute.Parameters.AddWithValue("@PASSWORD", usuario.usu_password);

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = usuario.usu_id;
                    respuesta.detalle = "Usuario actualizado con exito.";
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
        /// BAJA. USUARIO es una tabla MAESTRO: el patron pide baja LOGICA
        /// (UPD_USUARIO con @HABILITADO = 0), no DELETE fisico.
        /// El DEL_USUARIO existe solo para casos excepcionales / datos de prueba.
        /// </summary>
        public Respuesta DeleteUsuario(Usuario usuario)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_USUARIO");
                    cmdExecute.Parameters.AddWithValue("@ID", usuario.usu_id);

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = usuario.usu_id;
                    respuesta.detalle = "Usuario eliminado con exito.";
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
        /// Reutiliza UPD_USUARIO en vez de crear un SP nuevo.
        /// </summary>
        public Respuesta DeshabilitarUsuario(Usuario usuario)
        {
            usuario.usu_habilitado = false;
            Respuesta respuesta = UpdateUsuario(usuario);

            if (!respuesta.error)
                respuesta.detalle = "Usuario deshabilitado con exito.";

            return respuesta;
        }

        #endregion
    }
}
