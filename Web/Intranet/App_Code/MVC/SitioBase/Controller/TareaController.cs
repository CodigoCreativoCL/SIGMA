using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Tareas recurrentes (HU-102) y su hilo de comentarios (HU-104).
    /// El cliente va siempre desde la sesion; quien crea, tambien.
    /// </summary>
    public class TareaController
    {
        #region Tarea

        public List<Tarea> GetTareas(Tarea filtro = null)
        {
            List<Tarea> lista = new List<Tarea>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_TAREA";

                    if (filtro != null)
                    {
                        if (filtro.tar_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.tar_id);
                        if (filtro.tar_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.tar_cliente);
                        if (filtro.filtro_instalacion != null && filtro.filtro_instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", filtro.filtro_instalacion);
                        if (filtro.filtro_activo != null && filtro.filtro_activo > 0) cmd.Parameters.AddWithValue("@ACTIVO", filtro.filtro_activo);
                        if (filtro.filtro_prioridad != null && filtro.filtro_prioridad > 0) cmd.Parameters.AddWithValue("@PRIORIDAD", filtro.filtro_prioridad);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Tarea t = new Tarea();
                            t.tar_id = int.Parse(dr["TAR_ID"].ToString());
                            t.tar_cliente = int.Parse(dr["TAR_CLIENTE"].ToString());
                            if (dr["TAR_CLIENTE_INSTALACION"] != DBNull.Value) t.tar_cliente_instalacion = int.Parse(dr["TAR_CLIENTE_INSTALACION"].ToString());
                            if (dr["TAR_INSTALACION_AREA"] != DBNull.Value) t.tar_instalacion_area = int.Parse(dr["TAR_INSTALACION_AREA"].ToString());
                            if (dr["TAR_TAREA_CATEGORIA"] != DBNull.Value) t.tar_tarea_categoria = int.Parse(dr["TAR_TAREA_CATEGORIA"].ToString());
                            if (dr["TAR_ACTIVO"] != DBNull.Value) t.tar_activo = int.Parse(dr["TAR_ACTIVO"].ToString());
                            t.tar_codigo = dr["TAR_CODIGO"].ToString();
                            t.tar_titulo = dr["TAR_TITULO"].ToString();
                            t.tar_descripcion = dr["TAR_DESCRIPCION"].ToString();
                            t.tar_tarea_prioridad = int.Parse(dr["TAR_TAREA_PRIORIDAD"].ToString());
                            if (dr["TAR_DURACION_ESTIMADA_MINUTO"] != DBNull.Value) t.tar_duracion_estimada_minuto = int.Parse(dr["TAR_DURACION_ESTIMADA_MINUTO"].ToString());
                            t.tar_requiere_evidencia = (bool)dr["TAR_REQUIERE_EVIDENCIA"];
                            t.tar_usuario_creacion = int.Parse(dr["TAR_USUARIO_CREACION"].ToString());
                            if (dr["TAR_FECHA_CREACION"] != DBNull.Value) t.tar_fecha_creacion = (DateTime)dr["TAR_FECHA_CREACION"];
                            if (dr["TAR_USUARIO_ACTUALIZACION"] != DBNull.Value) t.tar_usuario_actualizacion = int.Parse(dr["TAR_USUARIO_ACTUALIZACION"].ToString());
                            if (dr["TAR_FECHA_ACTUALIZACION"] != DBNull.Value) t.tar_fecha_actualizacion = (DateTime)dr["TAR_FECHA_ACTUALIZACION"];
                            t.tar_habilitado = (bool)dr["TAR_HABILITADO"];

                            t.planta_nombre = dr["PLANTA_NOMBRE"].ToString();
                            t.area_nombre = dr["AREA_NOMBRE"].ToString();
                            t.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                            t.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            t.categoria_nombre = dr["CATEGORIA_NOMBRE"].ToString();
                            t.prioridad_codigo = dr["PRIORIDAD_CODIGO"].ToString();
                            t.prioridad_nombre = dr["PRIORIDAD_NOMBRE"].ToString();
                            t.prioridad_orden = int.Parse(dr["PRIORIDAD_ORDEN"].ToString());
                            t.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            t.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();
                            t.programaciones = int.Parse(dr["PROGRAMACIONES"].ToString());
                            t.ocurrencias = int.Parse(dr["OCURRENCIAS"].ToString());
                            t.pendientes = int.Parse(dr["PENDIENTES"].ToString());
                            lista.Add(t);
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

        public Tarea GetTarea(Tarea entidad)
        {
            List<Tarea> lista = GetTareas(new Tarea { tar_id = entidad.tar_id });
            return (lista != null && lista.Count > 0) ? lista[0] : new Tarea();
        }

        public Respuesta InsertTarea(Tarea e)
        {
            return Ejecutar("INS_TAREA", "Tarea creada con éxito.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@CODIGO", e.tar_codigo);
                cmd.Parameters.AddWithValue("@TITULO", e.tar_titulo);
                cmd.Parameters.AddWithValue("@DESCRIPCION", (object)e.tar_descripcion ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@TAREA_PRIORIDAD", e.tar_tarea_prioridad);
                cmd.Parameters.AddWithValue("@CLIENTE_INSTALACION", (object)e.tar_cliente_instalacion ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@INSTALACION_AREA", (object)e.tar_instalacion_area ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@ACTIVO", (object)e.tar_activo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@TAREA_CATEGORIA", (object)e.tar_tarea_categoria ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@DURACION_ESTIMADA_MINUTO", (object)e.tar_duracion_estimada_minuto ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@REQUIERE_EVIDENCIA", e.tar_requiere_evidencia);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
            }, true);
        }

        public Respuesta UpdateTarea(Tarea e)
        {
            return Ejecutar("UPD_TAREA", "Tarea actualizada con éxito.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", e.tar_id);
                cmd.Parameters.AddWithValue("@TITULO", e.tar_titulo);
                cmd.Parameters.AddWithValue("@DESCRIPCION", (object)e.tar_descripcion ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@TAREA_PRIORIDAD", e.tar_tarea_prioridad);
                cmd.Parameters.AddWithValue("@CLIENTE_INSTALACION", (object)e.tar_cliente_instalacion ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@INSTALACION_AREA", (object)e.tar_instalacion_area ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@ACTIVO", (object)e.tar_activo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@TAREA_CATEGORIA", (object)e.tar_tarea_categoria ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@DURACION_ESTIMADA_MINUTO", (object)e.tar_duracion_estimada_minuto ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@REQUIERE_EVIDENCIA", e.tar_requiere_evidencia);
                cmd.Parameters.AddWithValue("@HABILITADO", e.tar_habilitado);
                cmd.Parameters.AddWithValue("@QUITA_INSTALACION", e.quita_instalacion);
                cmd.Parameters.AddWithValue("@QUITA_AREA", e.quita_area);
                cmd.Parameters.AddWithValue("@QUITA_ACTIVO", e.quita_activo);
                cmd.Parameters.AddWithValue("@QUITA_CATEGORIA", e.quita_categoria);
                cmd.Parameters.AddWithValue("@QUITA_DURACION", e.quita_duracion);
                cmd.Parameters.AddWithValue("@QUITA_DESCRIPCION", e.quita_descripcion);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
            }, false, e.tar_id);
        }

        public Respuesta DeleteTarea(Tarea e)
        {
            return Ejecutar("DEL_TAREA", "Tarea eliminada con éxito.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", e.tar_id);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
            }, false, e.tar_id);
        }

        #endregion

        #region Tarea_Programacion

        public List<TareaProgramacion> GetTareaProgramaciones(TareaProgramacion filtro = null)
        {
            List<TareaProgramacion> lista = new List<TareaProgramacion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_TAREA_PROGRAMACION";

                    if (filtro != null)
                    {
                        if (filtro.tpr_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.tpr_id);
                        if (filtro.filtro_cliente != null && filtro.filtro_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.filtro_cliente);
                        if (filtro.filtro_tarea != null && filtro.filtro_tarea > 0) cmd.Parameters.AddWithValue("@TAREA", filtro.filtro_tarea);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            TareaProgramacion p = new TareaProgramacion();
                            p.tpr_id = int.Parse(dr["TPR_ID"].ToString());
                            p.tpr_tarea = int.Parse(dr["TPR_TAREA"].ToString());
                            p.tpr_programacion = int.Parse(dr["TPR_PROGRAMACION"].ToString());
                            if (dr["TPR_USUARIO_RESPONSABLE"] != DBNull.Value) p.tpr_usuario_responsable = int.Parse(dr["TPR_USUARIO_RESPONSABLE"].ToString());
                            if (dr["TPR_GRUPO_TRABAJO"] != DBNull.Value) p.tpr_grupo_trabajo = int.Parse(dr["TPR_GRUPO_TRABAJO"].ToString());
                            p.tpr_usuario_creacion = int.Parse(dr["TPR_USUARIO_CREACION"].ToString());
                            if (dr["TPR_FECHA_CREACION"] != DBNull.Value) p.tpr_fecha_creacion = (DateTime)dr["TPR_FECHA_CREACION"];
                            if (dr["TPR_USUARIO_ACTUALIZACION"] != DBNull.Value) p.tpr_usuario_actualizacion = int.Parse(dr["TPR_USUARIO_ACTUALIZACION"].ToString());
                            if (dr["TPR_FECHA_ACTUALIZACION"] != DBNull.Value) p.tpr_fecha_actualizacion = (DateTime)dr["TPR_FECHA_ACTUALIZACION"];
                            p.tpr_habilitado = (bool)dr["TPR_HABILITADO"];
                            p.tarea_cliente = int.Parse(dr["TAREA_CLIENTE"].ToString());
                            p.tarea_codigo = dr["TAREA_CODIGO"].ToString();
                            p.tarea_titulo = dr["TAREA_TITULO"].ToString();
                            p.programacion_nombre = dr["PROGRAMACION_NOMBRE"].ToString();
                            p.programacion_tipo_nombre = dr["PROGRAMACION_TIPO_NOMBRE"].ToString();
                            if (dr["PROGRAMACION_FECHA_INICIO"] != DBNull.Value) p.programacion_fecha_inicio = (DateTime)dr["PROGRAMACION_FECHA_INICIO"];
                            if (dr["PROGRAMACION_FECHA_FIN"] != DBNull.Value) p.programacion_fecha_fin = (DateTime)dr["PROGRAMACION_FECHA_FIN"];
                            p.programacion_habilitado = (bool)dr["PROGRAMACION_HABILITADO"];
                            p.responsable_nombre = dr["RESPONSABLE_NOMBRE"].ToString();
                            p.grupo_nombre = dr["GRUPO_NOMBRE"].ToString();
                            p.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            p.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();
                            p.ocurrencias = int.Parse(dr["OCURRENCIAS"].ToString());
                            lista.Add(p);
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

        public TareaProgramacion GetTareaProgramacion(int id)
        {
            List<TareaProgramacion> l = GetTareaProgramaciones(new TareaProgramacion { tpr_id = id });
            return (l != null && l.Count > 0) ? l[0] : new TareaProgramacion();
        }

        public Respuesta InsertTareaProgramacion(TareaProgramacion e)
        {
            return Ejecutar("INS_TAREA_PROGRAMACION", "Tarea programada con éxito.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@TAREA", e.tpr_tarea);
                cmd.Parameters.AddWithValue("@PROGRAMACION", e.tpr_programacion);
                cmd.Parameters.AddWithValue("@USUARIO_RESPONSABLE", (object)e.tpr_usuario_responsable ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@GRUPO_TRABAJO", (object)e.tpr_grupo_trabajo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
            }, true);
        }

        public Respuesta UpdateTareaProgramacion(TareaProgramacion e)
        {
            return Ejecutar("UPD_TAREA_PROGRAMACION", "Programación de la tarea actualizada con éxito.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", e.tpr_id);
                cmd.Parameters.AddWithValue("@USUARIO_RESPONSABLE", (object)e.tpr_usuario_responsable ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@GRUPO_TRABAJO", (object)e.tpr_grupo_trabajo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@HABILITADO", e.tpr_habilitado);
                cmd.Parameters.AddWithValue("@QUITA_RESPONSABLE", e.quita_responsable);
                cmd.Parameters.AddWithValue("@QUITA_GRUPO", e.quita_grupo);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
            }, false, e.tpr_id);
        }

        public Respuesta DeleteTareaProgramacion(TareaProgramacion e)
        {
            return Ejecutar("DEL_TAREA_PROGRAMACION", "Programación quitada de la tarea.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", e.tpr_id);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
            }, false, e.tpr_id);
        }

        /// <summary>HU-076 para tareas: las ocurrencias que faltan de la tarea (o de todas) en el horizonte.</summary>
        public Respuesta GenerarOcurrencias(int? tarea, int horizonteDias)
        {
            return PlanOcurrenciaController.Generar("GEN_TAREA_OCURRENCIAS", "@TAREA", tarea, horizonteDias,
                dr => dr["TAREA_CODIGO"] + " · " + dr["PROGRAMACION_NOMBRE"] + ": " + dr["GENERADAS"]);
        }

        #endregion

        #region Tarea_Comentario

        public List<TareaComentario> GetTareaComentarios(TareaComentario filtro = null)
        {
            List<TareaComentario> lista = new List<TareaComentario>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_TAREA_COMENTARIO";

                    if (filtro != null)
                    {
                        if (filtro.tco_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.tco_id);
                        if (filtro.filtro_cliente != null && filtro.filtro_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.filtro_cliente);
                        if (filtro.filtro_tarea != null && filtro.filtro_tarea > 0) cmd.Parameters.AddWithValue("@TAREA", filtro.filtro_tarea);
                        if (filtro.filtro_ocurrencia != null && filtro.filtro_ocurrencia > 0) cmd.Parameters.AddWithValue("@OCURRENCIA", filtro.filtro_ocurrencia);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            TareaComentario c = new TareaComentario();
                            c.tco_id = int.Parse(dr["TCO_ID"].ToString());
                            c.tco_tarea_ocurrencia = int.Parse(dr["TCO_TAREA_OCURRENCIA"].ToString());
                            if (dr["TCO_COMENTARIO_PADRE"] != DBNull.Value) c.tco_comentario_padre = int.Parse(dr["TCO_COMENTARIO_PADRE"].ToString());
                            c.tco_texto = dr["TCO_TEXTO"].ToString();
                            if (dr["TCO_DICTADO_VOZ"] != DBNull.Value) c.tco_dictado_voz = int.Parse(dr["TCO_DICTADO_VOZ"].ToString());
                            c.tco_usuario_creacion = int.Parse(dr["TCO_USUARIO_CREACION"].ToString());
                            if (dr["TCO_FECHA_CREACION"] != DBNull.Value) c.tco_fecha_creacion = (DateTime)dr["TCO_FECHA_CREACION"];
                            c.usuario_nombre = dr["USUARIO_NOMBRE"].ToString();
                            c.tarea_id = int.Parse(dr["TAREA_ID"].ToString());
                            c.tarea_codigo = dr["TAREA_CODIGO"].ToString();
                            c.tarea_titulo = dr["TAREA_TITULO"].ToString();
                            if (dr["OCURRENCIA_FECHA"] != DBNull.Value) c.ocurrencia_fecha = (DateTime)dr["OCURRENCIA_FECHA"];
                            c.ocurrencia_estado_codigo = dr["OCURRENCIA_ESTADO_CODIGO"].ToString();
                            c.ocurrencia_estado_nombre = dr["OCURRENCIA_ESTADO_NOMBRE"].ToString();
                            c.respuestas = int.Parse(dr["RESPUESTAS"].ToString());
                            lista.Add(c);
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

        public Respuesta InsertTareaComentario(TareaComentario e)
        {
            return Ejecutar("INS_TAREA_COMENTARIO", "Comentario publicado.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@OCURRENCIA", e.tco_tarea_ocurrencia);
                cmd.Parameters.AddWithValue("@TEXTO", e.tco_texto ?? "");
                cmd.Parameters.AddWithValue("@PADRE", (object)e.tco_comentario_padre ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
            }, true);
        }

        #endregion

        /// <summary>
        /// Un solo camino para todos los INS/UPD/DEL: la sesion se valida
        /// antes, el SP decide, y sin sesion NO se finge exito.
        /// </summary>
        private static Respuesta Ejecutar(string sp, string exito, Action<SqlCommand> parametros, bool conSalida, int id = 0)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand(sp);
                    parametros(cmd);
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    respuesta.codigo = conSalida ? (int)cmd.Parameters["@ID"].Value : id;
                    respuesta.detalle = exito;
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
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
