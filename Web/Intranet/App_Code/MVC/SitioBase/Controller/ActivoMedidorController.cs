using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Medidores de los activos del cliente (HU-042).
    ///
    /// El usuario que audita sale SIEMPRE de la sesión (Session.UsuarioId).
    /// El cliente lo pone la pantalla desde Session.ClienteId. El activo no
    /// se cambia al editar: un medidor pertenece a su máquina.
    /// </summary>
    public class ActivoMedidorController
    {
        public List<ActivoMedidor> GetActivoMedidores(ActivoMedidor filtro = null)
        {
            List<ActivoMedidor> lista = new List<ActivoMedidor>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ACTIVO_MEDIDOR";

                    if (filtro != null)
                    {
                        if (filtro.ame_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.ame_id);
                        if (filtro.ame_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.ame_cliente);
                        if (filtro.filtro_activo > 0) cmd.Parameters.AddWithValue("@ACTIVO", filtro.filtro_activo);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoMedidor item = new ActivoMedidor();

                            item.ame_id = int.Parse(dr["AME_ID"].ToString());
                            item.ame_cliente = int.Parse(dr["AME_CLIENTE"].ToString());
                            item.ame_activo = int.Parse(dr["AME_ACTIVO"].ToString());
                            if (dr["AME_ACTIVO_COMPONENTE"] != DBNull.Value)
                                item.ame_activo_componente = int.Parse(dr["AME_ACTIVO_COMPONENTE"].ToString());
                            item.ame_unidad_medida = int.Parse(dr["AME_UNIDAD_MEDIDA"].ToString());
                            item.ame_codigo = dr["AME_CODIGO"].ToString();
                            item.ame_nombre = dr["AME_NOMBRE"].ToString();
                            item.ame_valor_actual = decimal.Parse(dr["AME_VALOR_ACTUAL"].ToString());
                            if (dr["AME_FECHA_VALOR_ACTUAL_UTC"] != DBNull.Value)
                                item.ame_fecha_valor_actual_utc = DateTime.Parse(dr["AME_FECHA_VALOR_ACTUAL_UTC"].ToString());
                            if (dr["AME_VALOR_REINICIO"] != DBNull.Value)
                                item.ame_valor_reinicio = decimal.Parse(dr["AME_VALOR_REINICIO"].ToString());
                            item.ame_permite_reinicio = bool.Parse(dr["AME_PERMITE_REINICIO"].ToString());
                            item.ame_habilitado = bool.Parse(dr["AME_HABILITADO"].ToString());

                            if (dr["AME_FECHA_CREACION"] != DBNull.Value)
                                item.ame_fecha_creacion = DateTime.Parse(dr["AME_FECHA_CREACION"].ToString());
                            if (dr["AME_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.ame_fecha_actualizacion = DateTime.Parse(dr["AME_FECHA_ACTUALIZACION"].ToString());

                            item.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                            item.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            item.unidad_nombre = dr["UNIDAD_NOMBRE"].ToString();
                            item.unidad_simbolo = dr["UNIDAD_SIMBOLO"].ToString();
                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            item.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();

                            lista.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }

        public ActivoMedidor GetActivoMedidor(int id)
        {
            List<ActivoMedidor> lista = GetActivoMedidores(new ActivoMedidor { ame_id = id });
            return (lista != null && lista.Count > 0) ? lista[0] : new ActivoMedidor();
        }

        public Respuesta InsertActivoMedidor(ActivoMedidor entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_ACTIVO_MEDIDOR");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", entidad.ame_cliente);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO", entidad.ame_activo);
                    cmdExecute.Parameters.AddWithValue("@UNIDAD_MEDIDA", entidad.ame_unidad_medida);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.ame_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.ame_nombre);
                    cmdExecute.Parameters.AddWithValue("@VALOR_ACTUAL", entidad.ame_valor_actual);
                    cmdExecute.Parameters.AddWithValue("@VALOR_REINICIO", (object)entidad.ame_valor_reinicio ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@PERMITE_REINICIO", entidad.ame_permite_reinicio);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Medidor creado con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null) cmdExecute.Connection.Close();
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

        public Respuesta UpdateActivoMedidor(ActivoMedidor entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_ACTIVO_MEDIDOR");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.ame_id);
                    cmdExecute.Parameters.AddWithValue("@UNIDAD_MEDIDA", entidad.ame_unidad_medida);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.ame_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.ame_nombre);
                    cmdExecute.Parameters.AddWithValue("@VALOR_ACTUAL", entidad.ame_valor_actual);
                    cmdExecute.Parameters.AddWithValue("@VALOR_REINICIO", (object)entidad.ame_valor_reinicio ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@PERMITE_REINICIO", entidad.ame_permite_reinicio);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.ame_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.ame_id;
                    respuesta.detalle = "Medidor actualizado con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null) cmdExecute.Connection.Close();
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

        public Respuesta DeleteActivoMedidor(ActivoMedidor entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_ACTIVO_MEDIDOR");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.ame_id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.ame_id;
                    respuesta.detalle = "Medidor dado de baja con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null) cmdExecute.Connection.Close();
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
    }
}
