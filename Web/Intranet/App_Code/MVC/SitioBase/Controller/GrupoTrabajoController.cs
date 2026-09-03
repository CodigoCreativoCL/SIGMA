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
    /// Grupos de trabajo y sus integrantes (HU-016).
    ///
    /// Los integrantes viven en el mismo controller porque no tienen vida
    /// propia: un integrante sin grupo no existe, y las reglas que importan
    /// -un solo lider vigente, sin tramos solapados- son del grupo entero.
    /// </summary>
    public class GrupoTrabajoController
    {
        #region Grupo

        public List<GrupoTrabajo> GetGruposTrabajo(GrupoTrabajo filtro = null)
        {
            List<GrupoTrabajo> lista = new List<GrupoTrabajo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_GRUPO_TRABAJO";

                    if (filtro != null)
                    {
                        if (filtro.gtr_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.gtr_id);
                        if (filtro.gtr_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.gtr_cliente);
                        if (filtro.gtr_cliente_instalacion != null && filtro.gtr_cliente_instalacion > 0)
                            cmd.Parameters.AddWithValue("@CLIENTE_INSTALACION", filtro.gtr_cliente_instalacion);
                        if (filtro.gtr_especialidad != null && filtro.gtr_especialidad > 0)
                            cmd.Parameters.AddWithValue("@ESPECIALIDAD", filtro.gtr_especialidad);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            GrupoTrabajo item = new GrupoTrabajo();

                            item.gtr_id = int.Parse(dr["GTR_ID"].ToString());
                            item.gtr_cliente = int.Parse(dr["GTR_CLIENTE"].ToString());
                            if (dr["GTR_CLIENTE_INSTALACION"] != DBNull.Value)
                                item.gtr_cliente_instalacion = int.Parse(dr["GTR_CLIENTE_INSTALACION"].ToString());
                            item.gtr_codigo = dr["GTR_CODIGO"].ToString();
                            item.gtr_nombre = dr["GTR_NOMBRE"].ToString();
                            if (dr["GTR_ESPECIALIDAD"] != DBNull.Value)
                                item.gtr_especialidad = int.Parse(dr["GTR_ESPECIALIDAD"].ToString());
                            item.gtr_descripcion = dr["GTR_DESCRIPCION"].ToString();
                            item.gtr_habilitado = bool.Parse(dr["GTR_HABILITADO"].ToString());
                            item.cin_nombre = dr["CIN_NOMBRE"].ToString();
                            item.esp_nombre = dr["ESP_NOMBRE"].ToString();
                            item.integrantes = int.Parse(dr["INTEGRANTES"].ToString());
                            item.lider = dr["LIDER"].ToString();

                            if (dr["GTR_FECHA_CREACION"] != DBNull.Value)
                                item.gtr_fecha_creacion = DateTime.Parse(dr["GTR_FECHA_CREACION"].ToString());
                            if (dr["GTR_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.gtr_fecha_actualizacion = DateTime.Parse(dr["GTR_FECHA_ACTUALIZACION"].ToString());

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

        public GrupoTrabajo GetGrupoTrabajo(GrupoTrabajo entidad)
        {
            List<GrupoTrabajo> lista = GetGruposTrabajo(new GrupoTrabajo { gtr_id = entidad.gtr_id });
            return (lista != null && lista.Count > 0) ? lista[0] : new GrupoTrabajo();
        }

        public List<GrupoEspecialidadResumen> GetResumenEspecialidades(int grupo)
        {
            List<GrupoEspecialidadResumen> lista = new List<GrupoEspecialidadResumen>();
            if (!Token.TokenSeguridad() || grupo <= 0) return lista;

            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = "SEL_GRUPO_TRABAJO_ESPECIALIDAD_RESUMEN";
                cmd.Parameters.AddWithValue("@GRUPO", grupo);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        lista.Add(new GrupoEspecialidadResumen
                        {
                            esp_id = int.Parse(dr["ESP_ID"].ToString()),
                            esp_nombre = dr["ESP_NOMBRE"].ToString(),
                            cantidad = int.Parse(dr["CANTIDAD"].ToString()),
                            es_predominante = bool.Parse(dr["ES_PREDOMINANTE"].ToString()),
                            es_empate = bool.Parse(dr["ES_EMPATE"].ToString())
                        });
                    }
                }
            }
            finally
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return lista;
        }

        public Respuesta InsertGrupoTrabajo(GrupoTrabajo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_GRUPO_TRABAJO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", entidad.gtr_cliente);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE_INSTALACION", (object)entidad.gtr_cliente_instalacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.gtr_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.gtr_nombre);
                    cmdExecute.Parameters.AddWithValue("@ESPECIALIDAD", (object)entidad.gtr_especialidad ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.gtr_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Grupo de trabajo creado con éxito.";
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

        public Respuesta UpdateGrupoTrabajo(GrupoTrabajo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_GRUPO_TRABAJO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.gtr_id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE_INSTALACION", (object)entidad.gtr_cliente_instalacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.gtr_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.gtr_nombre);
                    cmdExecute.Parameters.AddWithValue("@ESPECIALIDAD", (object)entidad.gtr_especialidad ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.gtr_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.gtr_habilitado);
                    cmdExecute.Parameters.AddWithValue("@QUITA_PLANTA", entidad.quita_planta);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.gtr_id;
                    respuesta.detalle = "Grupo de trabajo actualizado con éxito.";
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

        #endregion

        #region Integrantes

        public List<GrupoTrabajoUsuario> GetIntegrantes(GrupoTrabajoUsuario filtro = null)
        {
            List<GrupoTrabajoUsuario> lista = new List<GrupoTrabajoUsuario>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_GRUPO_TRABAJO_USUARIO";

                    if (filtro != null)
                    {
                        if (filtro.gtu_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.gtu_id);
                        if (filtro.gtu_grupo_trabajo > 0) cmd.Parameters.AddWithValue("@GRUPO_TRABAJO", filtro.gtu_grupo_trabajo);
                        if (filtro.gtu_usuario > 0) cmd.Parameters.AddWithValue("@USUARIO_DESTINO", filtro.gtu_usuario);
                        if (filtro.filtro_solo_vigentes) cmd.Parameters.AddWithValue("@SOLO_VIGENTES", true);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            GrupoTrabajoUsuario item = new GrupoTrabajoUsuario();

                            item.gtu_id = int.Parse(dr["GTU_ID"].ToString());
                            item.gtu_grupo_trabajo = int.Parse(dr["GTU_GRUPO_TRABAJO"].ToString());
                            item.gtu_usuario = int.Parse(dr["GTU_USUARIO"].ToString());
                            item.gtu_es_lider = bool.Parse(dr["GTU_ES_LIDER"].ToString());
                            item.usu_nombre = dr["USU_NOMBRE"].ToString();
                            item.usu_correo = dr["USU_CORREO"].ToString();
                            item.usu_identificador = dr["USU_IDENTIFICADOR"].ToString();
                            item.usu_archivo_foto = int.Parse(dr["USU_ARCHIVO_FOTO"].ToString());
                            item.especialidades = dr["ESPECIALIDADES"].ToString();
                            item.gtr_nombre = dr["GTR_NOMBRE"].ToString();
                            item.estado = dr["ESTADO"].ToString();

                            if (dr["GTU_FECHA_INICIO"] != DBNull.Value)
                                item.gtu_fecha_inicio = DateTime.Parse(dr["GTU_FECHA_INICIO"].ToString());
                            if (dr["GTU_FECHA_FIN"] != DBNull.Value)
                                item.gtu_fecha_fin = DateTime.Parse(dr["GTU_FECHA_FIN"].ToString());

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

        public Respuesta InsertIntegrante(GrupoTrabajoUsuario entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_GRUPO_TRABAJO_USUARIO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@GRUPO_TRABAJO", entidad.gtu_grupo_trabajo);
                    cmdExecute.Parameters.AddWithValue("@USUARIO_DESTINO", entidad.gtu_usuario);
                    cmdExecute.Parameters.AddWithValue("@ES_LIDER", entidad.gtu_es_lider);
                    cmdExecute.Parameters.AddWithValue("@FECHA_INICIO", (object)entidad.gtu_fecha_inicio ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@FECHA_FIN", (object)entidad.gtu_fecha_fin ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Integrante agregado con éxito.";
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

        public Respuesta UpdateIntegrante(GrupoTrabajoUsuario entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_GRUPO_TRABAJO_USUARIO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.gtu_id);
                    cmdExecute.Parameters.AddWithValue("@ES_LIDER", entidad.gtu_es_lider);
                    cmdExecute.Parameters.AddWithValue("@FECHA_INICIO", (object)entidad.gtu_fecha_inicio ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@FECHA_FIN", (object)entidad.gtu_fecha_fin ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@QUITA_FIN", entidad.quita_fin);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.gtu_id;
                    respuesta.detalle = "Integrante actualizado con éxito.";
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

        public Respuesta DeleteIntegrante(GrupoTrabajoUsuario entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_GRUPO_TRABAJO_USUARIO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.gtu_id);
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.gtu_id;
                    respuesta.detalle = "Integrante eliminado con éxito.";
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

        #endregion
    }
}
