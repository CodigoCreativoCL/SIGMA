using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Posiciones funcionales del cliente y su historial de ocupacion
    /// (HU-033). Las reglas viven en los SP del bloque 231: aqui solo se
    /// arma la llamada y se lee la respuesta.
    /// </summary>
    public class ActivoPosicionController
    {
        public List<ActivoPosicion> GetPosiciones(ActivoPosicion filtro = null)
        {
            List<ActivoPosicion> lista = new List<ActivoPosicion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ACTIVO_POSICION";

                    if (filtro != null)
                    {
                        if (filtro.apo_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.apo_id);
                        if (filtro.apo_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.apo_cliente);
                        if (filtro.filtro_cliente_instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", filtro.filtro_cliente_instalacion);
                        if (filtro.filtro_instalacion_area > 0) cmd.Parameters.AddWithValue("@AREA", filtro.filtro_instalacion_area);
                        if (filtro.filtro_activo_tipo > 0) cmd.Parameters.AddWithValue("@ACTIVO_TIPO", filtro.filtro_activo_tipo);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (filtro.filtro_libre != null) cmd.Parameters.AddWithValue("@LIBRE", filtro.filtro_libre);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoPosicion item = new ActivoPosicion();

                            item.apo_id = int.Parse(dr["APO_ID"].ToString());
                            item.apo_cliente = int.Parse(dr["APO_CLIENTE"].ToString());
                            item.apo_cliente_instalacion = int.Parse(dr["APO_CLIENTE_INSTALACION"].ToString());
                            item.apo_instalacion_area = int.Parse(dr["APO_INSTALACION_AREA"].ToString());
                            if (dr["APO_ACTIVO_TIPO"] != DBNull.Value)
                                item.apo_activo_tipo = int.Parse(dr["APO_ACTIVO_TIPO"].ToString());
                            item.apo_codigo = dr["APO_CODIGO"].ToString();
                            item.apo_nombre = dr["APO_NOMBRE"].ToString();
                            item.apo_critica = bool.Parse(dr["APO_CRITICA"].ToString());
                            item.apo_descripcion = dr["APO_DESCRIPCION"].ToString();
                            item.apo_habilitado = bool.Parse(dr["APO_HABILITADO"].ToString());
                            if (dr["APO_FECHA_CREACION"] != DBNull.Value)
                                item.apo_fecha_creacion = DateTime.Parse(dr["APO_FECHA_CREACION"].ToString());
                            if (dr["APO_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.apo_fecha_actualizacion = DateTime.Parse(dr["APO_FECHA_ACTUALIZACION"].ToString());

                            item.planta_nombre = dr["PLANTA_NOMBRE"].ToString();
                            item.area_codigo = dr["AREA_CODIGO"].ToString();
                            item.area_nombre = dr["AREA_NOMBRE"].ToString();
                            item.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                            if (dr["ACTIVO_ID"] != DBNull.Value)
                                item.activo_id = int.Parse(dr["ACTIVO_ID"].ToString());
                            item.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                            item.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            if (dr["OCUPADA_DESDE_UTC"] != DBNull.Value)
                                item.ocupada_desde_utc = DateTime.Parse(dr["OCUPADA_DESDE_UTC"].ToString());
                            if (dr["OCUPADA_DESDE"] != DBNull.Value)
                                item.ocupada_desde = DateTime.Parse(dr["OCUPADA_DESDE"].ToString());
                            item.periodos = int.Parse(dr["PERIODOS"].ToString());
                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            item.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();

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

        public ActivoPosicion GetPosicion(ActivoPosicion entidad)
        {
            List<ActivoPosicion> lista = GetPosiciones(new ActivoPosicion { apo_id = entidad.apo_id });
            return (lista != null && lista.Count > 0) ? lista[0] : new ActivoPosicion();
        }

        public Respuesta InsertPosicion(ActivoPosicion entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_ACTIVO_POSICION");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", entidad.apo_cliente);
                    cmdExecute.Parameters.AddWithValue("@INSTALACION", entidad.apo_cliente_instalacion);
                    cmdExecute.Parameters.AddWithValue("@AREA", entidad.apo_instalacion_area);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_TIPO", (object)entidad.apo_activo_tipo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.apo_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.apo_nombre);
                    cmdExecute.Parameters.AddWithValue("@CRITICA", entidad.apo_critica);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.apo_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Posición creada con éxito.";
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
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta UpdatePosicion(ActivoPosicion entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_ACTIVO_POSICION");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.apo_id);
                    if (entidad.apo_instalacion_area > 0)
                        cmdExecute.Parameters.AddWithValue("@AREA", entidad.apo_instalacion_area);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_TIPO", (object)entidad.apo_activo_tipo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@QUITA_TIPO", entidad.quita_tipo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.apo_nombre);
                    cmdExecute.Parameters.AddWithValue("@CRITICA", entidad.apo_critica);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.apo_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.apo_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.apo_id;
                    respuesta.detalle = "Posición actualizada con éxito.";
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
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta DeletePosicion(ActivoPosicion entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_ACTIVO_POSICION");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.apo_id);
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.apo_id;
                    respuesta.detalle = "Posición eliminada con éxito.";
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
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

        /// <summary>Los periodos de ocupacion de una posicion (o de un equipo).</summary>
        public List<ActivoPosicionHistorial> GetHistorial(int posicion, int activo = 0)
        {
            List<ActivoPosicionHistorial> lista = new List<ActivoPosicionHistorial>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ACTIVO_POSICION_HISTORIAL";
                    if (posicion > 0) cmd.Parameters.AddWithValue("@POSICION", posicion);
                    if (activo > 0) cmd.Parameters.AddWithValue("@ACTIVO", activo);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoPosicionHistorial item = new ActivoPosicionHistorial();

                            item.aph_id = int.Parse(dr["APH_ID"].ToString());
                            item.aph_activo_posicion = int.Parse(dr["APH_ACTIVO_POSICION"].ToString());
                            item.aph_activo = int.Parse(dr["APH_ACTIVO"].ToString());
                            item.aph_fecha_inicio_utc = DateTime.Parse(dr["APH_FECHA_INICIO_UTC"].ToString());
                            if (dr["APH_FECHA_FIN_UTC"] != DBNull.Value)
                                item.aph_fecha_fin_utc = DateTime.Parse(dr["APH_FECHA_FIN_UTC"].ToString());
                            item.aph_fecha_inicio = DateTime.Parse(dr["APH_FECHA_INICIO"].ToString());
                            if (dr["APH_FECHA_FIN"] != DBNull.Value)
                                item.aph_fecha_fin = DateTime.Parse(dr["APH_FECHA_FIN"].ToString());
                            if (dr["APH_ACTIVO_POSICION_MOTIVO"] != DBNull.Value)
                                item.aph_activo_posicion_motivo = int.Parse(dr["APH_ACTIVO_POSICION_MOTIVO"].ToString());
                            if (dr["APH_ORDEN_TRABAJO"] != DBNull.Value)
                                item.aph_orden_trabajo = int.Parse(dr["APH_ORDEN_TRABAJO"].ToString());
                            item.aph_observacion = dr["APH_OBSERVACION"].ToString();
                            item.posicion_codigo = dr["POSICION_CODIGO"].ToString();
                            item.posicion_nombre = dr["POSICION_NOMBRE"].ToString();
                            item.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                            item.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            item.motivo_nombre = dr["MOTIVO_NOMBRE"].ToString();
                            if (dr["OT_CORRELATIVO"] != DBNull.Value)
                                item.ot_correlativo = int.Parse(dr["OT_CORRELATIVO"].ToString());
                            item.usuario_nombre = dr["USUARIO_NOMBRE"].ToString();
                            item.vigente = dr["VIGENTE"].ToString() == "1";
                            item.dias = int.Parse(dr["DIAS"].ToString());

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

        public List<ActivoPosicionMotivo> GetMotivos()
        {
            List<ActivoPosicionMotivo> lista = new List<ActivoPosicionMotivo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ACTIVO_POSICION_MOTIVO";
                    cmd.Parameters.AddWithValue("@HABILITADO", true);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            lista.Add(new ActivoPosicionMotivo
                            {
                                apm_id = int.Parse(dr["APM_ID"].ToString()),
                                apm_codigo = dr["APM_CODIGO"].ToString(),
                                apm_nombre = dr["APM_NOMBRE"].ToString(),
                                apm_orden = int.Parse(dr["APM_ORDEN"].ToString()),
                                apm_habilitado = bool.Parse(dr["APM_HABILITADO"].ToString())
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
                    lista = null;
                }
            }

            return lista;
        }

        /// <summary>
        /// Pone un equipo en la posicion. Si habia otro, su periodo se cierra;
        /// si el equipo venia de otra posicion, tambien. Todo en el SP.
        /// </summary>
        public Respuesta Ocupar(int posicion, int activo, int? motivo, string observacion)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_ACTIVO_POSICION_OCUPAR");
                    cmdExecute.Parameters.AddWithValue("@POSICION", posicion);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO", activo);
                    cmdExecute.Parameters.AddWithValue("@MOTIVO", (object)motivo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@OBSERVACION", string.IsNullOrEmpty(observacion) ? (object)DBNull.Value : observacion);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = posicion;
                    respuesta.detalle = "Equipo asignado a la posición.";
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
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta Liberar(int posicion, int? motivo, string observacion)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_ACTIVO_POSICION_LIBERAR");
                    cmdExecute.Parameters.AddWithValue("@POSICION", posicion);
                    cmdExecute.Parameters.AddWithValue("@MOTIVO", (object)motivo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@OBSERVACION", string.IsNullOrEmpty(observacion) ? (object)DBNull.Value : observacion);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = posicion;
                    respuesta.detalle = "La posición quedó libre.";
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
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }
    }
}
