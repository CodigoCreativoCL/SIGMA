using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Planes de mantenimiento del cliente (HU-080).
    ///
    /// EL CLIENTE SALE DE LA SESION
    ///   Las pantallas mandan Session.ClienteId() en el filtro y el SP filtra
    ///   por el. Un plan de otra empresa no aparece aunque se conozca su id,
    ///   porque el listado nunca se pide sin cliente.
    /// </summary>
    public class PlanMantenimientoController
    {
        public List<PlanMantenimiento> GetPlanesMantenimiento(PlanMantenimiento filtro = null)
        {
            List<PlanMantenimiento> lista = new List<PlanMantenimiento>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PLAN_MANTENIMIENTO";

                    if (filtro != null)
                    {
                        if (filtro.pma_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.pma_id);
                        if (filtro.pma_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.pma_cliente);
                        if (filtro.filtro_instalacion != null && filtro.filtro_instalacion > 0)
                            cmd.Parameters.AddWithValue("@INSTALACION", filtro.filtro_instalacion);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            PlanMantenimiento item = new PlanMantenimiento();

                            item.pma_id = int.Parse(dr["PMA_ID"].ToString());
                            item.pma_cliente = int.Parse(dr["PMA_CLIENTE"].ToString());
                            if (dr["PMA_CLIENTE_INSTALACION"] != DBNull.Value)
                                item.pma_cliente_instalacion = int.Parse(dr["PMA_CLIENTE_INSTALACION"].ToString());
                            item.pma_codigo = dr["PMA_CODIGO"].ToString();
                            item.pma_nombre = dr["PMA_NOMBRE"].ToString();
                            item.pma_descripcion = dr["PMA_DESCRIPCION"].ToString();
                            if (dr["PMA_USUARIO_PLANIFICADOR"] != DBNull.Value)
                                item.pma_usuario_planificador = int.Parse(dr["PMA_USUARIO_PLANIFICADOR"].ToString());
                            if (dr["PMA_ACTIVO_TIPO"] != DBNull.Value)
                                item.pma_activo_tipo = int.Parse(dr["PMA_ACTIVO_TIPO"].ToString());
                            if (dr["PMA_ACTIVO_MODELO"] != DBNull.Value)
                                item.pma_activo_modelo = int.Parse(dr["PMA_ACTIVO_MODELO"].ToString());
                            item.pma_habilitado = bool.Parse(dr["PMA_HABILITADO"].ToString());

                            item.pma_usuario_creacion = int.Parse(dr["PMA_USUARIO_CREACION"].ToString());
                            if (dr["PMA_FECHA_CREACION"] != DBNull.Value)
                                item.pma_fecha_creacion = DateTime.Parse(dr["PMA_FECHA_CREACION"].ToString());
                            if (dr["PMA_USUARIO_ACTUALIZACION"] != DBNull.Value)
                                item.pma_usuario_actualizacion = int.Parse(dr["PMA_USUARIO_ACTUALIZACION"].ToString());
                            if (dr["PMA_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.pma_fecha_actualizacion = DateTime.Parse(dr["PMA_FECHA_ACTUALIZACION"].ToString());

                            item.planta_nombre = dr["PLANTA_NOMBRE"].ToString();
                            item.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                            item.modelo_nombre = dr["MODELO_NOMBRE"].ToString();
                            item.planificador_nombre = dr["PLANIFICADOR_NOMBRE"].ToString();
                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            item.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();

                            if (dr["VERSION_ID"] != DBNull.Value)
                                item.version_id = int.Parse(dr["VERSION_ID"].ToString());
                            if (dr["VERSION_NUMERO"] != DBNull.Value)
                                item.version_numero = int.Parse(dr["VERSION_NUMERO"].ToString());
                            item.version_estado_codigo = dr["VERSION_ESTADO_CODIGO"].ToString();
                            item.version_estado_nombre = dr["VERSION_ESTADO_NOMBRE"].ToString();
                            item.hitos = int.Parse(dr["HITOS"].ToString());
                            item.activos = int.Parse(dr["ACTIVOS"].ToString());

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

        public PlanMantenimiento GetPlanMantenimiento(PlanMantenimiento entidad)
        {
            List<PlanMantenimiento> lista = GetPlanesMantenimiento(new PlanMantenimiento { pma_id = entidad.pma_id });
            return (lista != null && lista.Count > 0) ? lista[0] : new PlanMantenimiento();
        }

        public Respuesta InsertPlanMantenimiento(PlanMantenimiento entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_PLAN_MANTENIMIENTO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", entidad.pma_cliente);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE_INSTALACION", (object)entidad.pma_cliente_instalacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.pma_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.pma_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.pma_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO_PLANIFICADOR", (object)entidad.pma_usuario_planificador ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_TIPO", (object)entidad.pma_activo_tipo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_MODELO", (object)entidad.pma_activo_modelo ?? DBNull.Value);
                    // Nunca del Model: quien crea es quien esta en sesion.
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Plan de mantenimiento creado con éxito.";
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
                /* SIN SESION NO SE FINGE EXITO: `new Respuesta()` nace con
                   error = false, y sin este bloque la pantalla leeria
                   "guardado con exito" con ninguna fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta UpdatePlanMantenimiento(PlanMantenimiento entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_PLAN_MANTENIMIENTO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.pma_id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE_INSTALACION", (object)entidad.pma_cliente_instalacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.pma_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.pma_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.pma_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO_PLANIFICADOR", (object)entidad.pma_usuario_planificador ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_TIPO", (object)entidad.pma_activo_tipo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_MODELO", (object)entidad.pma_activo_modelo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.pma_habilitado);
                    cmdExecute.Parameters.AddWithValue("@QUITA_INSTALACION", entidad.quita_instalacion);
                    cmdExecute.Parameters.AddWithValue("@QUITA_PLANIFICADOR", entidad.quita_planificador);
                    cmdExecute.Parameters.AddWithValue("@QUITA_TIPO", entidad.quita_tipo);
                    cmdExecute.Parameters.AddWithValue("@QUITA_MODELO", entidad.quita_modelo);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.pma_id;
                    respuesta.detalle = "Plan de mantenimiento actualizado con éxito.";
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

        /// <summary>
        /// Baja logica. El SP rechaza si el plan ya genero mantenciones o
        /// tiene una version publicada: eso es historia, no un borrador.
        /// </summary>
        public Respuesta DeletePlanMantenimiento(PlanMantenimiento entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_PLAN_MANTENIMIENTO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.pma_id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.pma_id;
                    respuesta.detalle = "Plan de mantenimiento eliminado con éxito.";
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
