using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Actividades de un hito de plan (HU-082).
    ///
    /// El cliente viaja en @CLIENTE y el SP lo cruza por el plan: la
    /// actividad esta tres tablas mas abajo y no lleva cliente propio. Por
    /// eso las pantallas siempre lo mandan, aunque el SP lo acepte nulo para
    /// la lectura por id, donde el propio id ya acota.
    /// </summary>
    public class PlanActividadController
    {
        public List<PlanActividad> GetPlanActividades(PlanActividad filtro = null)
        {
            List<PlanActividad> lista = new List<PlanActividad>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PLAN_ACTIVIDAD";

                    if (filtro != null)
                    {
                        if (filtro.paa_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.paa_id);
                        if (filtro.filtro_cliente != null && filtro.filtro_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.filtro_cliente);
                        if (filtro.filtro_plan != null && filtro.filtro_plan > 0) cmd.Parameters.AddWithValue("@PLAN", filtro.filtro_plan);
                        if (filtro.filtro_version != null && filtro.filtro_version > 0) cmd.Parameters.AddWithValue("@VERSION", filtro.filtro_version);
                        if (filtro.filtro_hito != null && filtro.filtro_hito > 0) cmd.Parameters.AddWithValue("@HITO", filtro.filtro_hito);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            PlanActividad item = new PlanActividad();

                            item.paa_id = int.Parse(dr["PAA_ID"].ToString());
                            item.paa_plan_mantenimiento_hito = int.Parse(dr["PAA_PLAN_MANTENIMIENTO_HITO"].ToString());
                            if (dr["PAA_PROCEDIMIENTO"] != DBNull.Value)
                                item.paa_procedimiento = int.Parse(dr["PAA_PROCEDIMIENTO"].ToString());
                            item.paa_codigo = dr["PAA_CODIGO"].ToString();
                            item.paa_nombre = dr["PAA_NOMBRE"].ToString();
                            item.paa_descripcion = dr["PAA_DESCRIPCION"].ToString();
                            item.paa_orden = int.Parse(dr["PAA_ORDEN"].ToString());
                            if (dr["PAA_DURACION_ESTIMADA_MINUTO"] != DBNull.Value)
                                item.paa_duracion_estimada_minuto = int.Parse(dr["PAA_DURACION_ESTIMADA_MINUTO"].ToString());
                            item.paa_obligatoria = bool.Parse(dr["PAA_OBLIGATORIA"].ToString());
                            item.paa_requiere_parada = bool.Parse(dr["PAA_REQUIERE_PARADA"].ToString());
                            item.paa_requiere_permiso = bool.Parse(dr["PAA_REQUIERE_PERMISO"].ToString());
                            if (dr["PAA_PERMISO_TRABAJO_TIPO"] != DBNull.Value)
                                item.paa_permiso_trabajo_tipo = int.Parse(dr["PAA_PERMISO_TRABAJO_TIPO"].ToString());
                            item.paa_habilitado = bool.Parse(dr["PAA_HABILITADO"].ToString());

                            item.paa_usuario_creacion = int.Parse(dr["PAA_USUARIO_CREACION"].ToString());
                            if (dr["PAA_FECHA_CREACION"] != DBNull.Value)
                                item.paa_fecha_creacion = DateTime.Parse(dr["PAA_FECHA_CREACION"].ToString());
                            if (dr["PAA_USUARIO_ACTUALIZACION"] != DBNull.Value)
                                item.paa_usuario_actualizacion = int.Parse(dr["PAA_USUARIO_ACTUALIZACION"].ToString());
                            if (dr["PAA_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.paa_fecha_actualizacion = DateTime.Parse(dr["PAA_FECHA_ACTUALIZACION"].ToString());

                            item.hito_codigo = dr["HITO_CODIGO"].ToString();
                            item.hito_nombre = dr["HITO_NOMBRE"].ToString();
                            item.hito_orden = int.Parse(dr["HITO_ORDEN"].ToString());
                            item.version_id = int.Parse(dr["VERSION_ID"].ToString());
                            if (dr["VERSION_NUMERO"] != DBNull.Value)
                                item.version_numero = int.Parse(dr["VERSION_NUMERO"].ToString());
                            item.version_estado_codigo = dr["VERSION_ESTADO_CODIGO"].ToString();
                            item.version_estado_nombre = dr["VERSION_ESTADO_NOMBRE"].ToString();
                            item.plan_id = int.Parse(dr["PLAN_ID"].ToString());
                            item.plan_cliente = int.Parse(dr["PLAN_CLIENTE"].ToString());
                            item.plan_codigo = dr["PLAN_CODIGO"].ToString();
                            item.plan_nombre = dr["PLAN_NOMBRE"].ToString();
                            item.procedimiento_codigo = dr["PROCEDIMIENTO_CODIGO"].ToString();
                            item.procedimiento_nombre = dr["PROCEDIMIENTO_NOMBRE"].ToString();
                            item.procedimiento_pasos = int.Parse(dr["PROCEDIMIENTO_PASOS"].ToString());
                            item.permiso_tipo_nombre = dr["PERMISO_TIPO_NOMBRE"].ToString();
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

        public PlanActividad GetPlanActividad(PlanActividad entidad)
        {
            List<PlanActividad> lista = GetPlanActividades(new PlanActividad { paa_id = entidad.paa_id });
            return (lista != null && lista.Count > 0) ? lista[0] : new PlanActividad();
        }

        public Respuesta InsertPlanActividad(PlanActividad entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_PLAN_ACTIVIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@HITO", entidad.paa_plan_mantenimiento_hito);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.paa_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.paa_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.paa_descripcion ?? DBNull.Value);
                    /* Orden vacio: el SP la pone al final del hito. Mandar 0
                       seria pedir el primer lugar, que no es lo mismo. */
                    cmdExecute.Parameters.AddWithValue("@ORDEN", entidad.paa_orden > 0 ? (object)entidad.paa_orden : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@PROCEDIMIENTO", (object)entidad.paa_procedimiento ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@DURACION_ESTIMADA_MINUTO", (object)entidad.paa_duracion_estimada_minuto ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@OBLIGATORIA", entidad.paa_obligatoria);
                    cmdExecute.Parameters.AddWithValue("@REQUIERE_PARADA", entidad.paa_requiere_parada);
                    cmdExecute.Parameters.AddWithValue("@REQUIERE_PERMISO", entidad.paa_requiere_permiso);
                    cmdExecute.Parameters.AddWithValue("@PERMISO_TRABAJO_TIPO", (object)entidad.paa_permiso_trabajo_tipo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Actividad creada con éxito.";
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

        public Respuesta UpdatePlanActividad(PlanActividad entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_PLAN_ACTIVIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.paa_id);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.paa_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.paa_nombre);
                    /* Cadena vacia y no NULL: el SP entiende '' como
                       «borrala». NULL seria «no me la mandaron» y dejaria la
                       descripcion anterior, que no es lo que vio el usuario. */
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.paa_descripcion ?? "");
                    cmdExecute.Parameters.AddWithValue("@ORDEN", entidad.paa_orden > 0 ? (object)entidad.paa_orden : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@PROCEDIMIENTO", (object)entidad.paa_procedimiento ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@DURACION_ESTIMADA_MINUTO", (object)entidad.paa_duracion_estimada_minuto ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@OBLIGATORIA", entidad.paa_obligatoria);
                    cmdExecute.Parameters.AddWithValue("@REQUIERE_PARADA", entidad.paa_requiere_parada);
                    cmdExecute.Parameters.AddWithValue("@REQUIERE_PERMISO", entidad.paa_requiere_permiso);
                    cmdExecute.Parameters.AddWithValue("@PERMISO_TRABAJO_TIPO", (object)entidad.paa_permiso_trabajo_tipo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.paa_habilitado);
                    cmdExecute.Parameters.AddWithValue("@QUITA_PROCEDIMIENTO", entidad.quita_procedimiento);
                    cmdExecute.Parameters.AddWithValue("@QUITA_PERMISO_TIPO", entidad.quita_permiso_tipo);
                    cmdExecute.Parameters.AddWithValue("@QUITA_DURACION", entidad.quita_duracion);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.paa_id;
                    respuesta.detalle = "Actividad actualizada con éxito.";
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

        public Respuesta DeletePlanActividad(PlanActividad entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_PLAN_ACTIVIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.paa_id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.paa_id;
                    respuesta.detalle = "Actividad eliminada con éxito.";
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


        /* ================================================================
           LOS REPUESTOS PLANIFICADOS DE LA ACTIVIDAD (HU-082 #3)

           Sin Update a proposito: la tabla es una lista de materiales -no
           lleva habilitado ni fecha de actualizacion-, asi que cambiar la
           cantidad es quitar la linea y volver a agregarla. Es tambien lo
           que el usuario espera de una lista.
           ================================================================ */

        public List<PlanActividadRepuesto> GetRepuestos(PlanActividadRepuesto filtro = null)
        {
            List<PlanActividadRepuesto> lista = new List<PlanActividadRepuesto>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PLAN_ACTIVIDAD_REPUESTO";

                    if (filtro != null)
                    {
                        if (filtro.pra_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.pra_id);
                        if (filtro.filtro_cliente != null && filtro.filtro_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.filtro_cliente);
                        if (filtro.filtro_actividad != null && filtro.filtro_actividad > 0) cmd.Parameters.AddWithValue("@ACTIVIDAD", filtro.filtro_actividad);
                        if (filtro.filtro_hito != null && filtro.filtro_hito > 0) cmd.Parameters.AddWithValue("@HITO", filtro.filtro_hito);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            PlanActividadRepuesto item = new PlanActividadRepuesto();

                            item.pra_id = int.Parse(dr["PRA_ID"].ToString());
                            item.pra_plan_mantenimiento_actividad = int.Parse(dr["PRA_PLAN_MANTENIMIENTO_ACTIVIDAD"].ToString());
                            item.pra_repuesto = int.Parse(dr["PRA_REPUESTO"].ToString());
                            item.pra_cantidad = decimal.Parse(dr["PRA_CANTIDAD"].ToString());
                            if (dr["PRA_UNIDAD_MEDIDA"] != DBNull.Value)
                                item.pra_unidad_medida = int.Parse(dr["PRA_UNIDAD_MEDIDA"].ToString());
                            item.pra_obligatorio = bool.Parse(dr["PRA_OBLIGATORIO"].ToString());
                            item.pra_observacion = dr["PRA_OBSERVACION"].ToString();
                            item.pra_usuario_creacion = int.Parse(dr["PRA_USUARIO_CREACION"].ToString());
                            if (dr["PRA_FECHA_CREACION"] != DBNull.Value)
                                item.pra_fecha_creacion = DateTime.Parse(dr["PRA_FECHA_CREACION"].ToString());

                            item.repuesto_codigo = dr["REPUESTO_CODIGO"].ToString();
                            item.repuesto_nombre = dr["REPUESTO_NOMBRE"].ToString();
                            item.repuesto_fabricante = dr["REPUESTO_FABRICANTE"].ToString();
                            item.repuesto_modelo = dr["REPUESTO_MODELO"].ToString();
                            item.unidad_simbolo = dr["UNIDAD_SIMBOLO"].ToString();
                            item.unidad_nombre = dr["UNIDAD_NOMBRE"].ToString();
                            item.actividad_codigo = dr["ACTIVIDAD_CODIGO"].ToString();
                            item.actividad_nombre = dr["ACTIVIDAD_NOMBRE"].ToString();
                            item.hito_id = int.Parse(dr["HITO_ID"].ToString());
                            item.plan_cliente = int.Parse(dr["PLAN_CLIENTE"].ToString());
                            item.existencia = decimal.Parse(dr["EXISTENCIA"].ToString());
                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();

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

        public Respuesta InsertRepuesto(PlanActividadRepuesto entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_PLAN_ACTIVIDAD_REPUESTO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@ACTIVIDAD", entidad.pra_plan_mantenimiento_actividad);
                    cmdExecute.Parameters.AddWithValue("@REPUESTO", entidad.pra_repuesto);
                    cmdExecute.Parameters.AddWithValue("@CANTIDAD", entidad.pra_cantidad);
                    cmdExecute.Parameters.AddWithValue("@OBLIGATORIO", entidad.pra_obligatorio);
                    cmdExecute.Parameters.AddWithValue("@OBSERVACION", (object)entidad.pra_observacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Repuesto planificado agregado con éxito.";
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

        public Respuesta DeleteRepuesto(PlanActividadRepuesto entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_PLAN_ACTIVIDAD_REPUESTO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.pra_id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.pra_id;
                    respuesta.detalle = "Repuesto quitado de la actividad.";
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
