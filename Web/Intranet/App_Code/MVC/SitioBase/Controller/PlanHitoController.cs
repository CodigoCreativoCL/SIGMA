using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Hitos de un plan de mantenimiento (HU-081).
    ///
    /// El cliente viaja en @CLIENTE y el SP lo cruza a traves del plan: el
    /// hito no lleva cliente propio, y llevarlo seria repetir un dato que ya
    /// esta dos tablas mas arriba.
    /// </summary>
    public class PlanHitoController
    {
        public List<PlanHito> GetPlanHitos(PlanHito filtro = null)
        {
            List<PlanHito> lista = new List<PlanHito>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PLAN_HITO";

                    if (filtro != null)
                    {
                        if (filtro.pmh_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.pmh_id);
                        if (filtro.filtro_cliente != null && filtro.filtro_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.filtro_cliente);
                        if (filtro.filtro_plan != null && filtro.filtro_plan > 0) cmd.Parameters.AddWithValue("@PLAN", filtro.filtro_plan);
                        if (filtro.filtro_version != null && filtro.filtro_version > 0) cmd.Parameters.AddWithValue("@VERSION", filtro.filtro_version);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            PlanHito item = new PlanHito();

                            item.pmh_id = int.Parse(dr["PMH_ID"].ToString());
                            item.pmh_plan_mantenimiento_version = int.Parse(dr["PMH_PLAN_MANTENIMIENTO_VERSION"].ToString());
                            item.pmh_programacion = int.Parse(dr["PMH_PROGRAMACION"].ToString());
                            item.pmh_codigo = dr["PMH_CODIGO"].ToString();
                            item.pmh_nombre = dr["PMH_NOMBRE"].ToString();
                            item.pmh_orden = int.Parse(dr["PMH_ORDEN"].ToString());
                            if (dr["PMH_VALOR_MEDIDOR"] != DBNull.Value)
                                item.pmh_valor_medidor = decimal.Parse(dr["PMH_VALOR_MEDIDOR"].ToString());
                            if (dr["PMH_UNIDAD_MEDIDA"] != DBNull.Value)
                                item.pmh_unidad_medida = int.Parse(dr["PMH_UNIDAD_MEDIDA"].ToString());
                            item.pmh_es_overhaul = bool.Parse(dr["PMH_ES_OVERHAUL"].ToString());
                            item.pmh_requiere_parada = bool.Parse(dr["PMH_REQUIERE_PARADA"].ToString());
                            if (dr["PMH_DURACION_ESTIMADA_MINUTO"] != DBNull.Value)
                                item.pmh_duracion_estimada_minuto = int.Parse(dr["PMH_DURACION_ESTIMADA_MINUTO"].ToString());
                            if (dr["PMH_ORDEN_TRABAJO_TIPO"] != DBNull.Value)
                                item.pmh_orden_trabajo_tipo = int.Parse(dr["PMH_ORDEN_TRABAJO_TIPO"].ToString());
                            if (dr["PMH_ORDEN_TRABAJO_PRIORIDAD"] != DBNull.Value)
                                item.pmh_orden_trabajo_prioridad = int.Parse(dr["PMH_ORDEN_TRABAJO_PRIORIDAD"].ToString());
                            item.pmh_descripcion = dr["PMH_DESCRIPCION"].ToString();
                            item.pmh_habilitado = bool.Parse(dr["PMH_HABILITADO"].ToString());

                            item.pmh_usuario_creacion = int.Parse(dr["PMH_USUARIO_CREACION"].ToString());
                            if (dr["PMH_FECHA_CREACION"] != DBNull.Value)
                                item.pmh_fecha_creacion = DateTime.Parse(dr["PMH_FECHA_CREACION"].ToString());
                            if (dr["PMH_USUARIO_ACTUALIZACION"] != DBNull.Value)
                                item.pmh_usuario_actualizacion = int.Parse(dr["PMH_USUARIO_ACTUALIZACION"].ToString());
                            if (dr["PMH_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.pmh_fecha_actualizacion = DateTime.Parse(dr["PMH_FECHA_ACTUALIZACION"].ToString());

                            item.plan_id = int.Parse(dr["PLAN_ID"].ToString());
                            item.plan_cliente = int.Parse(dr["PLAN_CLIENTE"].ToString());
                            item.plan_codigo = dr["PLAN_CODIGO"].ToString();
                            item.plan_nombre = dr["PLAN_NOMBRE"].ToString();
                            if (dr["VERSION_NUMERO"] != DBNull.Value)
                                item.version_numero = int.Parse(dr["VERSION_NUMERO"].ToString());
                            item.version_estado_codigo = dr["VERSION_ESTADO_CODIGO"].ToString();
                            item.version_estado_nombre = dr["VERSION_ESTADO_NOMBRE"].ToString();
                            item.programacion_nombre = dr["PROGRAMACION_NOMBRE"].ToString();
                            item.programacion_tipo_nombre = dr["PROGRAMACION_TIPO_NOMBRE"].ToString();
                            item.unidad_simbolo = dr["UNIDAD_SIMBOLO"].ToString();
                            item.ot_tipo_nombre = dr["OT_TIPO_NOMBRE"].ToString();
                            item.ot_prioridad_nombre = dr["OT_PRIORIDAD_NOMBRE"].ToString();
                            item.actividades = int.Parse(dr["ACTIVIDADES"].ToString());
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
                    cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }

        public PlanHito GetPlanHito(PlanHito entidad)
        {
            List<PlanHito> lista = GetPlanHitos(new PlanHito { pmh_id = entidad.pmh_id });
            return (lista != null && lista.Count > 0) ? lista[0] : new PlanHito();
        }

        public Respuesta InsertPlanHito(PlanHito entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_PLAN_HITO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@PLAN", entidad.plan_id);
                    cmdExecute.Parameters.AddWithValue("@PROGRAMACION", entidad.pmh_programacion);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.pmh_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.pmh_nombre);
                    cmdExecute.Parameters.AddWithValue("@ORDEN", entidad.pmh_orden > 0 ? (object)entidad.pmh_orden : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@VALOR_MEDIDOR", (object)entidad.pmh_valor_medidor ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@UNIDAD_MEDIDA", (object)entidad.pmh_unidad_medida ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ES_OVERHAUL", entidad.pmh_es_overhaul);
                    cmdExecute.Parameters.AddWithValue("@REQUIERE_PARADA", entidad.pmh_requiere_parada);
                    cmdExecute.Parameters.AddWithValue("@DURACION_ESTIMADA_MINUTO", (object)entidad.pmh_duracion_estimada_minuto ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ORDEN_TRABAJO_TIPO", (object)entidad.pmh_orden_trabajo_tipo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ORDEN_TRABAJO_PRIORIDAD", (object)entidad.pmh_orden_trabajo_prioridad ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.pmh_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Hito creado con éxito.";
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

        public Respuesta UpdatePlanHito(PlanHito entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_PLAN_HITO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.pmh_id);
                    cmdExecute.Parameters.AddWithValue("@PROGRAMACION", entidad.pmh_programacion > 0 ? (object)entidad.pmh_programacion : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.pmh_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.pmh_nombre);
                    cmdExecute.Parameters.AddWithValue("@ORDEN", entidad.pmh_orden > 0 ? (object)entidad.pmh_orden : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@VALOR_MEDIDOR", (object)entidad.pmh_valor_medidor ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@UNIDAD_MEDIDA", (object)entidad.pmh_unidad_medida ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ES_OVERHAUL", entidad.pmh_es_overhaul);
                    cmdExecute.Parameters.AddWithValue("@REQUIERE_PARADA", entidad.pmh_requiere_parada);
                    cmdExecute.Parameters.AddWithValue("@DURACION_ESTIMADA_MINUTO", (object)entidad.pmh_duracion_estimada_minuto ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ORDEN_TRABAJO_TIPO", (object)entidad.pmh_orden_trabajo_tipo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ORDEN_TRABAJO_PRIORIDAD", (object)entidad.pmh_orden_trabajo_prioridad ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.pmh_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.pmh_habilitado);
                    cmdExecute.Parameters.AddWithValue("@QUITA_MEDIDOR", entidad.quita_medidor);
                    cmdExecute.Parameters.AddWithValue("@QUITA_OT_TIPO", entidad.quita_ot_tipo);
                    cmdExecute.Parameters.AddWithValue("@QUITA_OT_PRIORIDAD", entidad.quita_ot_prioridad);
                    cmdExecute.Parameters.AddWithValue("@QUITA_DURACION", entidad.quita_duracion);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.pmh_id;
                    respuesta.detalle = "Hito actualizado con éxito.";
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

        public Respuesta DeletePlanHito(PlanHito entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_PLAN_HITO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.pmh_id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.pmh_id;
                    respuesta.detalle = "Hito eliminado con éxito.";
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
