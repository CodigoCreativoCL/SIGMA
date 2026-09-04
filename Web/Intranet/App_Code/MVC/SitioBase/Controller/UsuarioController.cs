using SitioBase;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using SitioBase.Model;

namespace SitioBase.Controller
{
    public class UsuarioController
    {
        public Respuesta GetUsuarioLogin(Usuario usuario)
        {
            Respuesta respuesta = new Respuesta();
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_LOGIN";
                cmd.Parameters.AddWithValue("@LOGIN", usuario.usu_login);
                cmd.Parameters.AddWithValue("@PASSWORD", usuario.usu_password);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {
                        usuario = new Usuario();
                        usuario.usu_id = int.Parse(dr["ID"].ToString());
                        usuario.Code = dr["CODE"].ToString();
                        usuario.Mensaje = dr["MENSAJE"].ToString();
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();

                if (usuario.Code == "200" && usuario.usu_id > 0)
                    respuesta = GetUsuarioSession(usuario);
                else
                {
                    respuesta.error = true;
                    respuesta.detalle = usuario.Mensaje;

                }


            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                usuario = null;
            }

            return respuesta;
        }

        public Respuesta GetUsuarioSession(Usuario usuario)
        {
            Respuesta respuesta = new Respuesta();

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_USUARIO";
                cmd.Parameters.AddWithValue("@ID", usuario.usu_id);
                cmd.Parameters.AddWithValue("@DEVUELVE_FOTO", true);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {

                        System.Web.Security.FormsAuthentication.SetAuthCookie(usuario.usu_login, false);

                        //llena las variables de session 
                        HttpContext.Current.Session["usu_id"] = dr["USU_ID"].ToString();
                        HttpContext.Current.Session["usu_login"] = dr["USU_LOGIN"].ToString();
                        HttpContext.Current.Session["usu_password"] = dr["USU_PASSWORD"].ToString();
                        HttpContext.Current.Session["usu_nombre"] = dr["USU_NOMBRE"].ToString();
                        HttpContext.Current.Session["usu_apellido_paterno"] = dr["USU_APELLIDO_PATERNO"].ToString();
                        HttpContext.Current.Session["usu_apellido_materno"] = dr["USU_APELLIDO_MATERNO"].ToString();
                        HttpContext.Current.Session["usu_correo"] = dr["USU_CORREO"].ToString();
                        HttpContext.Current.Session["usu_fono"] = dr["USU_TELEFONO"].ToString();
                        HttpContext.Current.Session["usu_habilitado"] = dr["USU_HABILITADO"].ToString();
                        HttpContext.Current.Session["usu_perfil"] = dr["ID_PERFILES"].ToString();
                        HttpContext.Current.Session["usu_id_paises"] = dr["ID_PAISES"].ToString();
                        HttpContext.Current.Session["per_tipo"] = dr["PER_TIPO"].ToString();
                        HttpContext.Current.Session["perfiles"] = dr["PERFILES"].ToString();
                        if (dr["USU_FOTO"].ToString() != "")
                        {
                            byte[] byteFoto = (byte[])dr["USU_FOTO"];
                            HttpContext.Current.Session["usu_foto"] = Convert.ToBase64String(byteFoto, 0, byteFoto.Length);
                        }

                        /* La foto en Blob (bloque 100). Se guarda el ID, no
                           la imagen: la cabecera arma una URL y el navegador
                           la cachea, en vez de arrastrar el binario en cada
                           pagina metido dentro del HTML. */
                        if (dr["USU_ARCHIVO_FOTO"] != DBNull.Value)
                            HttpContext.Current.Session["usu_archivo_foto"] = dr["USU_ARCHIVO_FOTO"].ToString();

                        respuesta.codigo = int.Parse(dr["USU_ID"].ToString());
                        respuesta.detalle = dr["USU_NOMBRE"].ToString() + " " + dr["USU_APELLIDO_PATERNO"].ToString() + " " + dr["USU_APELLIDO_MATERNO"].ToString();
                        respuesta.error = false;
                    }

                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();

                respuesta.error = true;
                respuesta.detalle = ex.Message;
            }

            return respuesta;
        }

        public List<Usuario> GetUsuarios(Usuario usuario = null)
        {
            List<Usuario> usuarios = new List<Usuario>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_USUARIO";
                    if (usuario.usu_id > 0) cmd.Parameters.AddWithValue("@ID", usuario.usu_id);
                    if (usuario.ids != "") cmd.Parameters.AddWithValue("@IDS", usuario.ids);
                    if (usuario.id_perfiles != "") cmd.Parameters.AddWithValue("@PERFIL", usuario.id_perfiles);
                    if (usuario.perfiles != "") cmd.Parameters.AddWithValue("@TIPO_PERFIL", usuario.perfiles);
                    if (usuario.id_paises != "") cmd.Parameters.AddWithValue("@PAIS", usuario.id_paises);
                    if (usuario.usu_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", usuario.usu_habilitado);
                    if (usuario.filtro != "") cmd.Parameters.AddWithValue("@FILTRO", usuario.filtro);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Usuario item = new Usuario();

                            item.usu_id = int.Parse(dr["USU_ID"].ToString());
                            item.usu_login = dr["USU_LOGIN"].ToString();
                            item.usu_password = dr["USU_PASSWORD"].ToString();
                            item.usu_nombres = dr["USU_NOMBRE"].ToString();
                            item.usu_apellido_paterno = dr["USU_APELLIDO_PATERNO"].ToString();
                            item.usu_apellido_materno = dr["USU_APELLIDO_MATERNO"].ToString();
                            item.usu_identificador = dr["USU_IDENTIFICADOR"].ToString();
                            item.usu_correo = dr["USU_CORREO"].ToString();
                            item.usu_telefono = dr["USU_TELEFONO"].ToString();
                            item.usu_habilitado = bool.Parse(dr["USU_HABILITADO"].ToString());

                            item.perfiles = dr["PERFILES"].ToString();
                            item.id_perfiles = dr["ID_PERFILES"].ToString();

                            item.paises = dr["PAISES"].ToString();
                            item.id_paises = dr["ID_PAISES"].ToString();

                            item.nombre_completo = item.usu_nombres + " " + item.usu_apellido_paterno + " " + item.usu_apellido_materno;

                            usuarios.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();

                    usuarios = null;
                }
            }

            return usuarios;
        }

        public Usuario GetUsuario(Usuario usuario)
        {

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_USUARIO";
                    if (usuario != null) cmd.Parameters.AddWithValue("@ID", usuario.usu_id);
                    if (usuario.devuelve_foto) cmd.Parameters.AddWithValue("@DEVUELVE_FOTO", usuario.devuelve_foto);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read())
                        {
                            usuario = new Usuario();

                            usuario.usu_id = int.Parse(dr["USU_ID"].ToString());
                            usuario.usu_login = dr["USU_LOGIN"].ToString();
                            usuario.usu_password = dr["USU_PASSWORD"].ToString();
                            usuario.usu_nombres = dr["USU_NOMBRE"].ToString();
                            usuario.usu_apellido_paterno = dr["USU_APELLIDO_PATERNO"].ToString();
                            usuario.usu_apellido_materno = dr["USU_APELLIDO_MATERNO"].ToString();
                            usuario.usu_identificador = dr["USU_IDENTIFICADOR"].ToString();
                            usuario.usu_correo = dr["USU_CORREO"].ToString();
                            usuario.usu_telefono = dr["USU_TELEFONO"].ToString();
                            usuario.usu_habilitado = bool.Parse(dr["USU_HABILITADO"].ToString());

                            usuario.perfiles = dr["PERFILES"].ToString();
                            usuario.id_perfiles = dr["ID_PERFILES"].ToString();

                            usuario.paises = dr["PAISES"].ToString();
                            usuario.id_paises = dr["ID_PAISES"].ToString();

                            usuario.clientes = dr["CLIENTES"].ToString();
                            usuario.id_clientes = dr["ID_CLIENTES"].ToString();

                            usuario.instalaciones = dr["INSTALACIONES"].ToString();
                            usuario.id_instalaciones = dr["ID_INSTALACIONES"].ToString();

                            usuario.nombre_completo = usuario.usu_nombres + " " + usuario.usu_apellido_paterno + " " + usuario.usu_apellido_materno;


                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();

                    usuario = null;
                }
            }

            return usuario;
        }

        public List<UsuarioClienteInstalacion> GetClienteInstalaciones(int idUsuario)
        {
            List<UsuarioClienteInstalacion> lista = new List<UsuarioClienteInstalacion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_USUARIO_CLIENTE_INSTALACION";
                    cmd.Parameters.AddWithValue("@ID_USUARIO", idUsuario);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            lista.Add(new UsuarioClienteInstalacion
                            {
                                cli_id = int.Parse(dr["CLI_ID"].ToString()),
                                cli_nombre = dr["CLI_NOMBRE"].ToString(),
                                cin_id = dr["CIN_ID"] != DBNull.Value ? int.Parse(dr["CIN_ID"].ToString()) : (int?)null,
                                cin_nombre = dr["CIN_ID"] != DBNull.Value ? dr["CIN_NOMBRE"].ToString() : null
                            });
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
            }

            return lista;
        }

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

                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@IDENTIFICADOR", usuario.usu_identificador);
                    cmdExecute.Parameters.AddWithValue("@LOGIN", usuario.usu_login);
                    cmdExecute.Parameters.AddWithValue("@PASSWORD", usuario.usu_password);
                    cmdExecute.Parameters.AddWithValue("@NOMBRES", usuario.usu_nombres);
                    cmdExecute.Parameters.AddWithValue("@APELLIDO_PATERNO", usuario.usu_apellido_paterno);
                    cmdExecute.Parameters.AddWithValue("@APELLIDO_MATERNO", usuario.usu_apellido_materno);
                    cmdExecute.Parameters.AddWithValue("@FONO1", usuario.usu_telefono);
                    cmdExecute.Parameters.AddWithValue("@CORREO", usuario.usu_correo);
                    if (usuario.usu_foto != null) cmdExecute.Parameters.AddWithValue("@FOTO", usuario.usu_foto);
                    if (!string.IsNullOrEmpty(usuario.usu_foto_extension)) cmdExecute.Parameters.AddWithValue("@EXTENSION", usuario.usu_foto_extension);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", usuario.usu_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    if (cmdExecute.Parameters["@ID"].Value.ToString() != "")
                        id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Usuario creado con éxito.";
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
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta UpdateUsuario(Usuario usuario)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = new SqlCommand();
                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_USUARIO");

                    cmdExecute.Parameters.AddWithValue("@ID", usuario.usu_id);
                    cmdExecute.Parameters.AddWithValue("@IDENTIFICADOR", usuario.usu_identificador);
                    cmdExecute.Parameters.AddWithValue("@LOGIN", usuario.usu_login);
                    cmdExecute.Parameters.AddWithValue("@PASSWORD", usuario.usu_password);
                    cmdExecute.Parameters.AddWithValue("@NOMBRES", usuario.usu_nombres);
                    cmdExecute.Parameters.AddWithValue("@APELLIDO_PATERNO", usuario.usu_apellido_paterno);
                    cmdExecute.Parameters.AddWithValue("@APELLIDO_MATERNO", usuario.usu_apellido_materno);
                    cmdExecute.Parameters.AddWithValue("@FONO1", usuario.usu_telefono);
                    cmdExecute.Parameters.AddWithValue("@CORREO", usuario.usu_correo);
                    if (usuario.usu_foto != null) cmdExecute.Parameters.AddWithValue("@FOTO", usuario.usu_foto);
                    if (!string.IsNullOrEmpty(usuario.usu_foto_extension)) cmdExecute.Parameters.AddWithValue("@EXTENSION", usuario.usu_foto_extension);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", usuario.usu_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = 0;
                    respuesta.detalle = "Usuario actualizado con éxito.";
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
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta DeleteUsuario(Usuario usuario)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = new SqlCommand();
                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_USUARIO");
                    cmdExecute.Parameters.AddWithValue("@ID", usuario.usu_id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.Parameters.AddWithValue("@PAIS", Session.UsuarioIdPaises());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = 0;
                    respuesta.detalle = "Usuario eliminado con éxito.";
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
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

        #region UsuarioPaises
        //Devuelve los paises a los cuales el usuario esta asociado
        public List<UsuarioPaises> GetUsuarioPaises(Usuario item)
        {
            List<UsuarioPaises> paises = new List<UsuarioPaises>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_USUARIO_PAISES";
                    cmd.Parameters.AddWithValue("@USUARIO", item.usu_id);
                    cmd.Parameters.AddWithValue("@ASOCIADO", 1);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            UsuarioPaises pais = new UsuarioPaises();

                            pais.upa_id = int.Parse(dr["UPA_ID"].ToString());
                            pais.nombre = dr["PAI_NOMBRE"].ToString();


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

        //Devuelve los paises a los cuales el usuario NO esta asociado
        public List<Paises> GetUsuarioPaisesNoAsociados(Usuario item)
        {
            List<Paises> paises = new List<Paises>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_USUARIO_PAISES";
                    cmd.Parameters.AddWithValue("@USUARIO", item.usu_id);
                    cmd.Parameters.AddWithValue("@ASOCIADO", 0);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Paises pais = new Paises();

                            pais.pai_id = int.Parse(dr["PAI_ID"].ToString());
                            pais.pai_nombres = dr["PAI_NOMBRE"].ToString();

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

        //Elimino el pais asociado al usuario
        public Respuesta DeleteUsuarioPaises(List<UsuarioPaises> listado)
        {
            Respuesta respuesta = new Respuesta();

            DataTable dt2 = new DataTable();
            dt2.Columns.Add("upa_id", typeof(int));
            dt2.Columns.Add("mensaje", typeof(int));

            //Nuevo row
            DataRow filaNueva = null;

            if (Token.TokenSeguridad())
            {
                try
                {
                    int countError = 0;
                    int cantidaCargada = 0;
                    foreach (UsuarioPaises item in listado)
                    {
                        SqlCommand cmdExecute = new SqlCommand();
                        try
                        {
                            cmdExecute = Conexion.GetCommand("DEL_USUARIO_PAISES");
                            cmdExecute.Parameters.AddWithValue("@ID", item.upa_id);
                            cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                            cmdExecute.Parameters.AddWithValue("@PAIS", Session.UsuarioIdPaises());
                            cmdExecute.ExecuteNonQuery();
                            cmdExecute.Connection.Close();

                            cantidaCargada++;
                        }
                        catch (Exception ex)
                        {
                            cmdExecute.Connection.Close();

                            filaNueva = dt2.NewRow();
                            filaNueva["upa_id"] = item.upa_id;
                            filaNueva["mensaje"] = ex.Message;

                            dt2.Rows.Add(filaNueva);

                            countError++;
                        }

                    }

                    respuesta.detalle = "Paises(es) desasociado(s) con éxito";
                    respuesta.cantidaError = countError;
                    respuesta.cantidaCargada = cantidaCargada;
                    respuesta.table = dt2;
                }
                catch (Exception ex)
                {
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

       
        //Asocio un pais al usuario
        public Respuesta InsertUsuarioPais(List<UsuarioPaises> listado)
        {
            Respuesta respuesta = new Respuesta();

            DataTable dt2 = new DataTable();
            dt2.Columns.Add("upa_id_usuario", typeof(int));
            dt2.Columns.Add("upa_id_pais", typeof(int));
            dt2.Columns.Add("mensaje", typeof(int));

            //Nuevo row
            DataRow filaNueva = null;


            if (Token.TokenSeguridad())
            {
                try
                {
                    int countError = 0;
                    int cantidaCargada = 0;

                    foreach (UsuarioPaises item in listado)
                    {
                        SqlCommand cmdExecute = new SqlCommand();
                        try
                        {

                            cmdExecute = Conexion.GetCommand("INS_USUARIO_PAISES");
                            cmdExecute.Parameters.AddWithValue("@USUARIO", item.upa_id_usuario);
                            cmdExecute.Parameters.AddWithValue("@PAISES", item.upa_id_pais);
                            cmdExecute.Parameters.AddWithValue("@USUARIO_CREA", Session.UsuarioId());

                            cmdExecute.ExecuteNonQuery();
                            cmdExecute.Connection.Close();

                            cantidaCargada++;
                        }
                        catch (Exception ex)
                        {
                            cmdExecute.Connection.Close();

                            filaNueva = dt2.NewRow();
                            filaNueva["upa_id_usuario"] = item.upa_id_usuario;
                            filaNueva["upa_id_pais"] = item.upa_id_pais;
                            filaNueva["mensaje"] = ex.Message;

                            dt2.Rows.Add(filaNueva);

                            countError++;
                        }

                    }

                    respuesta.detalle = "Paises(es) asociado(s) con éxito";
                }
                catch (Exception ex)
                {
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

        #endregion

        #region UsuarioPerfiles
        public List<UsuarioPerfil> GetUsuarioPerfil(UsuarioPerfil item)
        {
            List<UsuarioPerfil> listado = new List<UsuarioPerfil>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_USUARIO_PERFILES";
                    cmd.Parameters.AddWithValue("@USUARIO", item.upe_usuario);
                    cmd.Parameters.AddWithValue("@ASOCIADO", 1);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            item = new UsuarioPerfil();

                            item.upe_perfil = int.Parse(dr["PER_ID"].ToString());
                            item.upe_id = int.Parse(dr["UPE_ID"].ToString());
                            item.perfil_nombre = dr["PER_NOMBRE"].ToString();
                            item.perfil_habilitado = bool.Parse(dr["PER_HABILITADO"].ToString());

                            listado.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();

                    listado = null;
                }
            }

            return listado;
        }

        public List<UsuarioPerfil> GetUsuarioPerfilesNoAsociados(UsuarioPerfil item)
        {
            List<UsuarioPerfil> listado = new List<UsuarioPerfil>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_USUARIO_PERFILES";
                    cmd.Parameters.AddWithValue("@USUARIO", item.upe_usuario);
                    cmd.Parameters.AddWithValue("@TIPO", item.perfil_tipo);
                    cmd.Parameters.AddWithValue("@ASOCIADO", 0);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            item = new UsuarioPerfil();

                            item.upe_perfil = int.Parse(dr["PER_ID"].ToString());
                            item.perfil_nombre = dr["PER_NOMBRE"].ToString();
                            item.perfil_habilitado = bool.Parse(dr["PER_HABILITADO"].ToString());

                            listado.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();

                    listado = null;
                }
            }

            return listado;
        }

        public Respuesta InsertUsuarioPerfil(List<UsuarioPerfil> listado)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute;

                try
                {
                    foreach (UsuarioPerfil item in listado)
                    {
                        cmdExecute = new SqlCommand();
                        cmdExecute = Conexion.GetCommand("INS_USUARIO_PERFIL");
                        cmdExecute.Parameters.AddWithValue("@USUARIO", item.upe_usuario);
                        cmdExecute.Parameters.AddWithValue("@PERFIL", item.upe_perfil);

                        cmdExecute.ExecuteNonQuery();
                        cmdExecute.Connection.Close();
                    }

                    respuesta.detalle = "Perfil(es) asociado(s) con éxito";
                }
                catch (Exception ex)
                {
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta DeleteUsuarioPerfil(List<UsuarioPerfil> listado)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute;

                try
                {
                    foreach (UsuarioPerfil item in listado)
                    {
                        cmdExecute = new SqlCommand();
                        cmdExecute = Conexion.GetCommand("DEL_USUARIO_PERFIL");
                        cmdExecute.Parameters.AddWithValue("@ID", item.upe_id);
                        cmdExecute.ExecuteNonQuery();
                        cmdExecute.Connection.Close();
                    }

                    respuesta.detalle = "Perfil(es) desasociado(s) con éxito";
                }
                catch (Exception ex)
                {
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }
        #endregion

        /// <summary>
        /// Sube la foto a Blob y la deja apuntada en el usuario (bloque 100).
        ///
        /// La imagen se reduce ANTES de subir: un avatar de 4 MB sacado con
        /// el telefono se muestra en 100x100 px, asi que subirlo entero es
        /// pagar el almacenamiento y el ancho de banda de algo que nadie va
        /// a ver en ese tamano.
        ///
        /// Actualiza la sesion para que el cambio se vea sin volver a entrar.
        /// </summary>
        public int GuardarFoto(int idUsuario, string nombreArchivo, byte[] contenido, string mime)
        {
            if (contenido == null || contenido.Length == 0)
                throw new Exception("El archivo esta vacio.");

            byte[] chica = global::SitioBase.SitioBase.ReducirImagen(contenido, 400, 400);

            Archivo archivo = new Archivo();
            archivo.arc_cliente = Session.ClienteId();
            archivo.arc_archivo_categoria = 15;   // FOTO USUARIO
            archivo.arc_nombre_original = nombreArchivo;
            archivo.arc_mime = mime;
            archivo.contenido = chica != null && chica.Length > 0 ? chica : contenido;

            ArchivoController ctrlArchivo = new ArchivoController();
            Respuesta subida = ctrlArchivo.InsertArchivo(archivo, "foto");

            if (subida.error)
                throw new Exception("No se pudo guardar la foto: " + subida.detalle);

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("UPD_USUARIO_FOTO");
                cmd.Parameters.AddWithValue("@USUARIO_DESTINO", idUsuario);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ARCHIVO", subida.codigo);
                cmd.Parameters.AddWithValue("@QUITAR", false);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                throw;
            }

            /* La cabecera pinta desde la sesion: sin esto el cambio no se ve
               hasta volver a entrar. */
            if (HttpContext.Current != null &&
                Session.UsuarioId() == idUsuario.ToString())
                HttpContext.Current.Session["usu_archivo_foto"] = subida.codigo.ToString();

            return subida.codigo;
        }
    }
}