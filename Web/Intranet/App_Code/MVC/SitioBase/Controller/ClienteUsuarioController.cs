using SitioBase;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Linq;
using System.Text;
using System.Web;
using OfficeOpenXml;
using SitioBase.Model;


namespace SitioBase.Controller
{
    public class ClienteUsuarioController
    {
        private SqlCommand cmdExecute = null;

        public List<ClienteUsuario> GetClienteUsuarios(ClienteUsuario usuario)
        {
            List<ClienteUsuario> usuarios = new List<ClienteUsuario>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CLIENTE_USUARIO";
                    cmd.Parameters.AddWithValue("@CLIENTE", usuario.ucl_id_cliente);
                    if (usuario.tipo_perfil > 0) cmd.Parameters.AddWithValue("@TIPO_PERFIL", usuario.tipo_perfil);

                    int tipo_perfil = usuario.tipo_perfil;
                    if (usuario.id_perfiles != "") cmd.Parameters.AddWithValue("@PERFILES", usuario.id_perfiles);
                    if (usuario.usu_id > 0) cmd.Parameters.AddWithValue("@ID", usuario.usu_id);
                    if (usuario.cin_id_instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", usuario.cin_id_instalacion);
                    if (usuario.filtro != "") cmd.Parameters.AddWithValue("@FILTRO", usuario.filtro);
                    if (usuario.usu_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", usuario.usu_habilitado);


                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            usuario = new ClienteUsuario();

                            usuario.usu_id = int.Parse(dr["USU_ID"].ToString());
                            usuario.nombre_completo = dr["USU_NOMBRE"].ToString() + " " + dr["USU_APELLIDO_PATERNO"].ToString() + " " + dr["USU_APELLIDO_MATERNO"].ToString();
                            usuario.usu_login = dr["usu_login"].ToString();

                            //if (tipo_perfil == 1 )
                            //{
                                if (!string.IsNullOrEmpty(dr["PERFILES"].ToString())) usuario.perfiles = dr["PERFILES"].ToString();
                                if (!string.IsNullOrEmpty(dr["ID_PERFILES"].ToString())) usuario.id_perfiles = dr["ID_PERFILES"].ToString();

                            //}

                            //if (tipo_perfil == 2)
                            //{
                            //    if (!string.IsNullOrEmpty(dr["PERFILES_USUARIO"].ToString())) usuario.perfiles_usuario = dr["PERFILES_USUARIO"].ToString();
                            //    if (!string.IsNullOrEmpty(dr["ID_PERFILES_USUARIO"].ToString())) usuario.id_perfiles_usuario = dr["ID_PERFILES_USUARIO"].ToString();

                            //}


                            usuario.usu_identificador = dr["USU_IDENTIFICADOR"].ToString();
                            usuario.usu_correo = dr["USU_CORREO"].ToString();
                            usuario.usu_telefono = dr["USU_TELEFONO"].ToString();
                            usuario.usu_habilitado = bool.Parse(dr["USU_HABILITADO"].ToString());
                            usuarios.Add(usuario);
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

        public ClienteUsuario GetClienteUsuario(ClienteUsuario usuario)
        {

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CLIENTE_USUARIO";
                    if (usuario.usu_id > 0) cmd.Parameters.AddWithValue("@ID", usuario.usu_id);
                    if (usuario.ucl_id_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", usuario.ucl_id_cliente);
                    if (usuario.tipo_perfil > 0) cmd.Parameters.AddWithValue("@TIPO_PERFIL", usuario.tipo_perfil);
                    int tipo_perfil = usuario.tipo_perfil;
                    if (usuario.devuelve_foto) cmd.Parameters.AddWithValue("@DEVUELVE_FOTO", usuario.devuelve_foto);
                    if (usuario.usu_identificador != "") cmd.Parameters.AddWithValue("@IDENTIFICADOR", usuario.usu_identificador);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read())
                        {
                            usuario = new ClienteUsuario();

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

                            if (!string.IsNullOrEmpty(dr["PERFILES"].ToString())) usuario.perfiles = dr["PERFILES"].ToString();
                            if (!string.IsNullOrEmpty(dr["ID_PERFILES"].ToString())) usuario.id_perfiles = dr["ID_PERFILES"].ToString();

                            usuario.paises = dr["PAISES"].ToString();
                            usuario.id_paises = dr["ID_PAISES"].ToString();
                            usuario.id_cliente = dr["ID_CLIENTES"].ToString();

                            usuario.nombre_completo = usuario.usu_nombres + " " + usuario.usu_apellido_paterno + " " + usuario.usu_apellido_materno;

                            //if (dr["UFT_BINARIO"].ToString() != "")
                            //usuario.usu_foto = (byte[])dr["UFT_BINARIO"];

                            //usuario.usu_foto_extension = dr["UFT_EXTENSION"].ToString();


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

        public Respuesta InsertClienteUsuario(ClienteUsuario usuario)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_CLIENTE_USUARIO");

                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@IDENTIFICADOR", usuario.usu_identificador);
                    cmdExecute.Parameters.AddWithValue("@LOGIN", usuario.usu_login);
                    cmdExecute.Parameters.AddWithValue("@PASSWORD", usuario.usu_password);
                    cmdExecute.Parameters.AddWithValue("@NOMBRES", usuario.usu_nombres);
                    cmdExecute.Parameters.AddWithValue("@APELLIDO_PATERNO", usuario.usu_apellido_paterno);
                    cmdExecute.Parameters.AddWithValue("@APELLIDO_MATERNO", usuario.usu_apellido_materno);
                    cmdExecute.Parameters.AddWithValue("@FONO1", usuario.usu_telefono);
                    cmdExecute.Parameters.AddWithValue("@CORREO", usuario.usu_correo);
                    cmdExecute.Parameters.AddWithValue("@PERFILES", usuario.perfiles);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", usuario.ucl_id_cliente);
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

            return respuesta;
        }

        public Respuesta UpdateClienteUsuario(ClienteUsuario usuario)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = new SqlCommand();
                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_CLIENTE_USUARIO");

                    cmdExecute.Parameters.AddWithValue("@ID", usuario.usu_id);
                    cmdExecute.Parameters.AddWithValue("@IDENTIFICADOR", usuario.usu_identificador);
                    cmdExecute.Parameters.AddWithValue("@LOGIN", usuario.usu_login);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", usuario.ucl_id_cliente);
                    cmdExecute.Parameters.AddWithValue("@PASSWORD", usuario.usu_password);
                    cmdExecute.Parameters.AddWithValue("@NOMBRES", usuario.usu_nombres);
                    cmdExecute.Parameters.AddWithValue("@APELLIDO_PATERNO", usuario.usu_apellido_paterno);
                    cmdExecute.Parameters.AddWithValue("@APELLIDO_MATERNO", usuario.usu_apellido_materno);
                    cmdExecute.Parameters.AddWithValue("@PERFILES", usuario.perfiles);
                    cmdExecute.Parameters.AddWithValue("@FONO1", usuario.usu_telefono);
                    cmdExecute.Parameters.AddWithValue("@CORREO", usuario.usu_correo);
                    cmdExecute.Parameters.AddWithValue("@CLINTE_NUEVO", usuario.cliente_nuevo);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = usuario.usu_id;
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

            return respuesta;
        }

        //Deshabilitamos los usuarios
        public Respuesta DeshabilitarClienteUsuario(List<ClienteUsuario> listado)
        {
            Respuesta respuesta = new Respuesta();

            DataTable dt2 = new DataTable();
            dt2.Columns.Add("usu_id", typeof(string));
            dt2.Columns.Add("mensaje", typeof(string));

            //Nuevo row
            DataRow filaNueva = null;

            if (Token.TokenSeguridad())
            {
                try
                {
                    int countError = 0;
                    int cantidaCargada = 0;
                    foreach (ClienteUsuario item in listado)
                    {
                        SqlCommand cmdExecute = new SqlCommand();
                        try
                        {
                            cmdExecute = Conexion.GetCommand("DEL_CLIENTE_USUARIO");
                            cmdExecute.Parameters.AddWithValue("@ID", item.usu_id);
                            cmdExecute.Parameters.AddWithValue("@CLIENTE", item.ucl_id_cliente);
                            cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                            cmdExecute.ExecuteNonQuery();
                            cmdExecute.Connection.Close();


                            respuesta.detalle = "Usuario(s) habilitado(s) o deshabilitado(s) con éxito";
                            cantidaCargada++;
                        }
                        catch (Exception ex)
                        {
                            cmdExecute.Connection.Close();

                            filaNueva = dt2.NewRow();
                            filaNueva["usu_id"] = item.usu_id;
                            filaNueva["mensaje"] = ex.Message;
                            respuesta.error = true;
                            respuesta.detalle = ex.Message + " - ID Usuario: " + item.usu_id;

                            dt2.Rows.Add(filaNueva);

                            countError++;
                        }

                    }
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

            return respuesta;
        }

        public List<ClienteUsuario> GetClienteUsuariosAsociarInstalacion(ClienteUsuario usuario)
        {
            List<ClienteUsuario> usuarios = new List<ClienteUsuario>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CLIENTE_USUARIO_ASOCIAR";
                    if (usuario.ucl_id_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", usuario.ucl_id_cliente);
                    cmd.Parameters.AddWithValue("@TIPO_PERFIL", usuario.tipo_perfil);
                    if (usuario.id_perfiles != "") cmd.Parameters.AddWithValue("@PERFILES", usuario.id_perfiles);
                    if (usuario.cin_id_instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", usuario.cin_id_instalacion);
                    if (usuario.filtro != "") cmd.Parameters.AddWithValue("@FILTRO", usuario.filtro);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ClienteUsuario item = new ClienteUsuario();

                            item.usu_id = int.Parse(dr["USU_ID"].ToString());
                            item.usu_identificador = dr["USU_IDENTIFICADOR"].ToString();
                            item.usu_correo = dr["USU_CORREO"].ToString();
                            item.usu_telefono = dr["USU_TELEFONO"].ToString();
                            item.nombre_completo = dr["USU_NOMBRE"].ToString() + " " + dr["USU_APELLIDO_PATERNO"].ToString() + " " + dr["USU_APELLIDO_MATERNO"].ToString();
                            item.perfiles = dr["PERFILES"].ToString();


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

        public List<ClienteUsuario> GetClienteUsuariosAsociarInstalacion2(ClienteUsuario usuario)
        {
            List<ClienteUsuario> usuarios = new List<ClienteUsuario>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CLIENTE_USUARIO_ASOCIAR_INSTALACION";
                    if (usuario.ucl_id_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", usuario.ucl_id_cliente);
                    cmd.Parameters.AddWithValue("@TIPO_PERFIL", usuario.tipo_perfil);
                    if (usuario.id_perfiles != "") cmd.Parameters.AddWithValue("@PERFILES", usuario.id_perfiles);
                    if (usuario.cin_id_instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", usuario.cin_id_instalacion);
                    if (usuario.filtro != "") cmd.Parameters.AddWithValue("@FILTRO", usuario.filtro);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ClienteUsuario item = new ClienteUsuario();

                            item.usu_id = int.Parse(dr["USU_ID"].ToString());
                            item.usu_identificador = dr["USU_IDENTIFICADOR"].ToString();
                            item.usu_correo = dr["USU_CORREO"].ToString();
                            item.usu_telefono = dr["USU_TELEFONO"].ToString();
                            item.nombre_completo = dr["USU_NOMBRE"].ToString() + " " + dr["USU_APELLIDO_PATERNO"].ToString() + " " + dr["USU_APELLIDO_MATERNO"].ToString();
                            item.perfiles = dr["PERFILES"].ToString();


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

        public Respuesta AsociarClienteUsuario(ClienteUsuario usuario)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = new SqlCommand();
                try
                {
                    cmdExecute = Conexion.GetCommand("INS_CLIENTE_USUARIO_ASOCIAR");

                    cmdExecute.Parameters.AddWithValue("@ID_USUARIO", usuario.usu_id);
                    if (usuario.cin_id_instalacion > 0) cmdExecute.Parameters.AddWithValue("@ID_INSTALACION", usuario.cin_id_instalacion);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", usuario.ucl_id_cliente);
                    cmdExecute.Parameters.AddWithValue("@PERFIL", usuario.id_perfiles);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = 0;
                    respuesta.detalle = "Usuario asociado a la instalación con éxito.";
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

        public Respuesta ReasignarUsuarioCliente(ClienteUsuario usuario)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = new SqlCommand();
                try
                {
                    cmdExecute = Conexion.GetCommand("INS_REASIGNAR_CLIENTE_USUARIO_ASOCIAR");

                    cmdExecute.Parameters.AddWithValue("@ID_USUARIO", usuario.usu_id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", usuario.ucl_id_cliente);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = 0;
                    respuesta.detalle = "Usuario asociado al cliente con éxito.";
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


        public Respuesta DeleteUsuarioAsociacion(ClienteUsuario usuario)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = new SqlCommand();
                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_USUARIO_ASOCIACION");
                    cmdExecute.Parameters.AddWithValue("@ID_USUARIO", usuario.usu_id);
                    if (usuario.cin_id_instalacion > 0) cmdExecute.Parameters.AddWithValue("@ID_INSTALACION", usuario.cin_id_instalacion);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", usuario.ucl_id_cliente);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = 0;
                    respuesta.detalle = "Usuario desvinculado con éxito.";
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



        //Carga Masiva
        public void PlantillaCargaUsuarios(ClienteUsuario usuario)
        {
            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = "RPT_CLIENTE_USUARIO_CARGA_MASIVA";
            cmd.Parameters.AddWithValue("@EXCEL", true);
            cmd.Parameters.AddWithValue("@CLIENTE", usuario.ucl_id_cliente);
            cmd.Parameters.AddWithValue("@PERFILES", usuario.perfiles);

            string filename = "CARGA MASIVA USUARIO " + DateTime.Now.ToShortDateString();
            var binario = Tools.Excel.exportExcelXLSX_Bytes(Conexion.GetDataTable(cmd), true);

            #region FORMATEO DOCUMENTO

            using (ExcelPackage excel = new ExcelPackage())
            {
                using (MemoryStream stream = new MemoryStream(binario))
                {
                    excel.Load(stream);
                }

                ExcelWorksheet hoja = excel.Workbook.Worksheets.First();

                //Dejo que el ancho de las columnas sea automatico
                hoja.Columns.AutoFit();
                //Le doy fomato a toda la columna A con texto para la fecha
                hoja.Cells["A:A"].Style.Numberformat.Format = "@";

                binario = excel.GetAsByteArray();
            }

            #endregion

            HttpContext.Current.Response.Clear();
            HttpContext.Current.Response.ContentType = "application/vnd.ms-excel";
            HttpContext.Current.Response.HeaderEncoding = Encoding.Default;
            HttpContext.Current.Response.ContentEncoding = Encoding.Default;
            HttpContext.Current.Response.AddHeader("content-disposition", "attachment; filename=" + filename + ".xlsx");

            HttpContext.Current.Response.BinaryWrite(binario);
            HttpContext.Current.Response.End();
        }


        public Respuesta InsertUsuariosMasivo(ClienteUsuario usuario)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                try
                {
                    DataTable dtEntrada = new DataTable();
                    DataTable dtResultado = new DataTable();
                    dtResultado.Columns.Add("DESCRIPCION", typeof(string));
                    dtResultado.Columns.Add("FECHA_ASIGNACION", typeof(string));
                    dtResultado.Columns.Add("ESTADO", typeof(string));
                    DataRow RowResultado = null;

                    dtEntrada = Tools.Excel.excelXLSX_ToDataTable(usuario.abi_archivo, 1, 1, 11);
                    //Valida que exista las columnas 
                    if (dtEntrada.Columns.Contains("IDENTIFICADOR") &&
                            dtEntrada.Columns.Contains("LOGIN") &&
                            dtEntrada.Columns.Contains("CONTRASEÑA") &&
                            dtEntrada.Columns.Contains("ID_PERFILES") &&
                            dtEntrada.Columns.Contains("NOMBRE") &&
                            dtEntrada.Columns.Contains("APELLIDO PATERNO") &&
                            dtEntrada.Columns.Contains("APELLIDO MATERNO") &&
                            dtEntrada.Columns.Contains("TELEFONO") &&
                            dtEntrada.Columns.Contains("CORREO") &&
                            dtEntrada.Columns.Contains("HABILITADO"))
                    {
                        int countCargados = 0;
                        int countNoCargados = 0;
                        int filaNumero = 10; // Variable para llevar el número de fila


                        // Recorre las filas
                        foreach (DataRow dataRow in dtEntrada.Rows)
                        {
                            try
                            {
                                ClienteUsuario usuarioConsultado = new ClienteUsuario();
                                Respuesta respuestaConsulta = new Respuesta();
                                usuarioConsultado.usu_identificador = dataRow["IDENTIFICADOR"].ToString();
                                usuarioConsultado.devuelve_foto = false;
                                usuarioConsultado = GetClienteUsuario(usuarioConsultado);

                                usuarioConsultado.cliente_nuevo = true;
                                if (usuarioConsultado.usu_id > 0)
                                {
                                    string[] id_cliente = usuarioConsultado.id_cliente.Split(',');
                                    if (id_cliente.Contains(usuario.ucl_id_cliente.ToString()))
                                    {
                                        usuarioConsultado.cliente_nuevo = true;
                                    }
                                    else
                                    {
                                        usuarioConsultado.cliente_nuevo = false;
                                    }
                                }

                                usuarioConsultado.usu_login = dataRow["LOGIN"].ToString();
                                usuarioConsultado.usu_password = dataRow["CONTRASEÑA"].ToString();
                                usuarioConsultado.usu_nombres = dataRow["NOMBRE"].ToString();
                                usuarioConsultado.usu_apellido_paterno = dataRow["APELLIDO PATERNO"].ToString();
                                usuarioConsultado.usu_apellido_materno = dataRow["APELLIDO MATERNO"].ToString();
                                usuarioConsultado.usu_telefono = dataRow["TELEFONO"].ToString();
                                usuarioConsultado.usu_correo = dataRow["CORREO"].ToString();

                                usuarioConsultado.ucl_id_cliente = usuario.ucl_id_cliente;
                                string idPerfil = dataRow["ID_PERFILES"].ToString();
                                string[] perfilesPermitidos = { "3", "4", "5" , "6", "7"};

                                // Dividir el idPerfil por ";"
                                string[] perfiles = idPerfil.Split(',');

                                // Verificar si todos los perfiles están en la lista permitida
                                bool esValido = perfiles.All(p => perfilesPermitidos.Contains(p));

                                if (!esValido)
                                {
                                    respuesta.error = true;
                                    RowResultado = dtResultado.NewRow();
                                    RowResultado["DESCRIPCION"] = dataRow["IDENTIFICADOR"];
                                    RowResultado["ESTADO"] = "El id " + idPerfil + " del perfil, no corresponde a uno de la lista";
                                    dtResultado.Rows.Add(RowResultado);
                                    countNoCargados++;
                                    continue;
                                }

                                else
                                {
                                    usuarioConsultado.perfiles = dataRow["ID_PERFILES"].ToString();
                                }
                                if (dataRow["HABILITADO"].ToString() == "1")
                                    usuarioConsultado.usu_habilitado = true;
                                else
                                    usuarioConsultado.usu_habilitado = false;

                                if (usuarioConsultado.usu_id > 0)
                                    respuestaConsulta = UpdateClienteUsuario(usuarioConsultado);
                                else
                                    respuestaConsulta = InsertClienteUsuario(usuarioConsultado);

                                if (respuestaConsulta.error == true)
                                {
                                    respuesta.error = true;
                                    RowResultado = dtResultado.NewRow();
                                    RowResultado["DESCRIPCION"] = dataRow["IDENTIFICADOR"];
                                    RowResultado["ESTADO"] = respuestaConsulta.detalle;
                                    dtResultado.Rows.Add(RowResultado);
                                    countNoCargados++;
                                    continue;
                                }

                                countCargados++;
                                filaNumero++; // Incrementa el número de fila
                            }
                            catch (Exception ex)
                            {
                                cmdExecute.Connection.Close();
                                respuesta.error = true;
                                RowResultado = dtResultado.NewRow();
                                RowResultado["DESCRIPCION"] = dataRow["IDENTIFICADOR"];
                                RowResultado["ESTADO"] = ex.Message;
                                dtResultado.Rows.Add(RowResultado);

                                countNoCargados++;
                            }
                        }

                        respuesta.codigo = 0;
                        respuesta.detalle = "Usuarios procesados.";
                        respuesta.table = dtResultado;
                        respuesta.cantidaCargada = countCargados;
                        respuesta.cantidaError = countNoCargados;
                    }
                    else
                    {
                        respuesta.codigo = -1;
                        respuesta.detalle = "El formato del archivo es incorrecto";
                        respuesta.error = true;
                    }

                    dtEntrada.Dispose();
                    dtEntrada.Clear();
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



