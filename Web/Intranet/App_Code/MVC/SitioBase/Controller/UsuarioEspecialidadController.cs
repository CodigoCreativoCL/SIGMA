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
    /// Especialidades y certificaciones de las personas (HU-017).
    ///
    /// Incluye el mantenedor de la propia especialidad porque es un catalogo
    /// ampliable del cliente y las dos cosas se administran juntas.
    /// </summary>
    public class UsuarioEspecialidadController
    {
        #region Catalogo de especialidades

        public List<Especialidad> GetEspecialidades(Especialidad filtro = null)
        {
            List<Especialidad> lista = new List<Especialidad>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ESPECIALIDAD";

                    if (filtro != null)
                    {
                        if (filtro.esp_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.esp_id);
                        if (filtro.esp_cliente != null && filtro.esp_cliente > 0)
                            cmd.Parameters.AddWithValue("@CLIENTE", filtro.esp_cliente);
                        if (filtro.filtro_solo_cliente) cmd.Parameters.AddWithValue("@SOLO_CLIENTE", true);
                        if (filtro.filtro_solo_sistema) cmd.Parameters.AddWithValue("@SOLO_SISTEMA", true);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Especialidad item = new Especialidad();

                            item.esp_id = int.Parse(dr["ESP_ID"].ToString());
                            if (dr["ESP_CLIENTE"] != DBNull.Value)
                                item.esp_cliente = int.Parse(dr["ESP_CLIENTE"].ToString());
                            item.esp_codigo = dr["ESP_CODIGO"].ToString();
                            item.esp_nombre = dr["ESP_NOMBRE"].ToString();
                            item.esp_habilitado = bool.Parse(dr["ESP_HABILITADO"].ToString());
                            item.origen = dr["ORIGEN"].ToString();

                            if (dr["ESP_ORDEN"] != DBNull.Value)
                                item.esp_orden = int.Parse(dr["ESP_ORDEN"].ToString());
                            if (dr["ESP_FECHA_CREACION"] != DBNull.Value)
                                item.esp_fecha_creacion = DateTime.Parse(dr["ESP_FECHA_CREACION"].ToString());

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
            }

            return lista;
        }

        public Respuesta InsertEspecialidad(Especialidad entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_ESPECIALIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", (object)entidad.esp_cliente ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.esp_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.esp_nombre);
                    cmdExecute.Parameters.AddWithValue("@ORDEN", (object)entidad.esp_orden ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Especialidad creada con éxito.";
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

        public Respuesta UpdateEspecialidad(Especialidad entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_ESPECIALIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.esp_id);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.esp_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.esp_nombre);
                    cmdExecute.Parameters.AddWithValue("@ORDEN", (object)entidad.esp_orden ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.esp_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.esp_id;
                    respuesta.detalle = "Especialidad actualizada con éxito.";
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

        #endregion

        #region Especialidades de una persona

        public List<UsuarioEspecialidad> GetUsuarioEspecialidades(UsuarioEspecialidad filtro = null)
        {
            List<UsuarioEspecialidad> lista = new List<UsuarioEspecialidad>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_USUARIO_ESPECIALIDAD";

                    if (filtro != null)
                    {
                        if (filtro.ues_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.ues_id);
                        if (filtro.ues_usuario > 0) cmd.Parameters.AddWithValue("@USUARIO_DESTINO", filtro.ues_usuario);
                        if (filtro.ues_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.ues_cliente);
                        if (filtro.ues_especialidad > 0) cmd.Parameters.AddWithValue("@ESPECIALIDAD", filtro.ues_especialidad);
                        if (filtro.filtro_solo_vencidas) cmd.Parameters.AddWithValue("@SOLO_VENCIDAS", true);
                        if (filtro.filtro_solo_por_vencer) cmd.Parameters.AddWithValue("@SOLO_POR_VENCER", true);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            UsuarioEspecialidad item = new UsuarioEspecialidad();

                            item.ues_id = int.Parse(dr["UES_ID"].ToString());
                            item.ues_usuario = int.Parse(dr["UES_USUARIO"].ToString());
                            item.ues_cliente = int.Parse(dr["UES_CLIENTE"].ToString());
                            item.ues_especialidad = int.Parse(dr["UES_ESPECIALIDAD"].ToString());
                            if (dr["UES_ESPECIALIDAD_NIVEL"] != DBNull.Value)
                                item.ues_especialidad_nivel = int.Parse(dr["UES_ESPECIALIDAD_NIVEL"].ToString());
                            item.ues_certificacion = dr["UES_CERTIFICACION"].ToString();
                            item.ues_habilitado = bool.Parse(dr["UES_HABILITADO"].ToString());
                            item.esp_codigo = dr["ESP_CODIGO"].ToString();
                            item.esp_nombre = dr["ESP_NOMBRE"].ToString();
                            item.enl_nombre = dr["ENL_NOMBRE"].ToString();
                            item.usu_nombre = dr["USU_NOMBRE"].ToString();
                            item.usu_correo = dr["USU_CORREO"].ToString();
                            item.estado = dr["ESTADO"].ToString();

                            if (dr["UES_FECHA_VENCIMIENTO"] != DBNull.Value)
                                item.ues_fecha_vencimiento = DateTime.Parse(dr["UES_FECHA_VENCIMIENTO"].ToString());
                            if (dr["DIAS_PARA_VENCER"] != DBNull.Value)
                                item.dias_para_vencer = int.Parse(dr["DIAS_PARA_VENCER"].ToString());
                            if (dr["UES_FECHA_CREACION"] != DBNull.Value)
                                item.ues_fecha_creacion = DateTime.Parse(dr["UES_FECHA_CREACION"].ToString());

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
            }

            return lista;
        }

        public UsuarioEspecialidad GetUsuarioEspecialidad(UsuarioEspecialidad entidad)
        {
            List<UsuarioEspecialidad> lista = GetUsuarioEspecialidades(new UsuarioEspecialidad { ues_id = entidad.ues_id });
            return (lista != null && lista.Count > 0) ? lista[0] : new UsuarioEspecialidad();
        }

        public Respuesta InsertUsuarioEspecialidad(UsuarioEspecialidad entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_USUARIO_ESPECIALIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@USUARIO_DESTINO", entidad.ues_usuario);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", entidad.ues_cliente);
                    cmdExecute.Parameters.AddWithValue("@ESPECIALIDAD", entidad.ues_especialidad);
                    cmdExecute.Parameters.AddWithValue("@ESPECIALIDAD_NIVEL", (object)entidad.ues_especialidad_nivel ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CERTIFICACION", (object)entidad.ues_certificacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@FECHA_VENCIMIENTO", (object)entidad.ues_fecha_vencimiento ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Especialidad registrada con éxito.";
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

        public Respuesta UpdateUsuarioEspecialidad(UsuarioEspecialidad entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_USUARIO_ESPECIALIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.ues_id);
                    cmdExecute.Parameters.AddWithValue("@ESPECIALIDAD_NIVEL", (object)entidad.ues_especialidad_nivel ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CERTIFICACION", (object)entidad.ues_certificacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@FECHA_VENCIMIENTO", (object)entidad.ues_fecha_vencimiento ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.ues_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.ues_id;
                    respuesta.detalle = "Especialidad actualizada con éxito.";
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

        public Respuesta DeleteUsuarioEspecialidad(UsuarioEspecialidad entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_USUARIO_ESPECIALIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.ues_id);
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.ues_id;
                    respuesta.detalle = "Especialidad eliminada con éxito.";
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

        #endregion
    }
}
