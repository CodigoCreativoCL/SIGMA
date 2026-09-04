using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Procedimientos reutilizables del cliente (HU-061). El SEL trae los del
    /// cliente MAS los globales; INS/UPD/DEL solo tocan los del cliente (el SP
    /// rechaza los globales). El código lo escribe el usuario —no es automático—
    /// porque es parte de la llave junto con la versión.
    /// </summary>
    public class ProcedimientoController
    {
        public List<Procedimiento> GetProcedimientos(Procedimiento filtro = null)
        {
            List<Procedimiento> lista = new List<Procedimiento>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PROCEDIMIENTO";

                    int cliente = (filtro != null && filtro.filtro_cliente > 0) ? filtro.filtro_cliente : Session.ClienteId();
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente);

                    if (filtro != null)
                    {
                        if (filtro.prc_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.prc_id);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (filtro.filtro_activo_tipo > 0) cmd.Parameters.AddWithValue("@ACTIVO_TIPO", filtro.filtro_activo_tipo);
                        if (filtro.filtro_solo_ultima) cmd.Parameters.AddWithValue("@SOLO_ULTIMA", true);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Procedimiento i = new Procedimiento();
                            i.prc_id = int.Parse(dr["prc_id"].ToString());
                            if (dr["prc_cliente"] != DBNull.Value) i.prc_cliente = int.Parse(dr["prc_cliente"].ToString());
                            i.prc_codigo = dr["prc_codigo"].ToString();
                            i.prc_nombre = dr["prc_nombre"].ToString();
                            i.prc_version = int.Parse(dr["prc_version"].ToString());
                            if (dr["prc_activo_tipo"] != DBNull.Value) i.prc_activo_tipo = int.Parse(dr["prc_activo_tipo"].ToString());
                            i.prc_descripcion = dr["prc_descripcion"].ToString();
                            if (dr["prc_duracion_estimada_minuto"] != DBNull.Value) i.prc_duracion_estimada_minuto = int.Parse(dr["prc_duracion_estimada_minuto"].ToString());
                            i.prc_requiere_permiso = bool.Parse(dr["prc_requiere_permiso"].ToString());
                            if (dr["prc_permiso_trabajo_tipo"] != DBNull.Value) i.prc_permiso_trabajo_tipo = int.Parse(dr["prc_permiso_trabajo_tipo"].ToString());
                            i.prc_habilitado = bool.Parse(dr["prc_habilitado"].ToString());
                            if (dr["prc_fecha_creacion"] != DBNull.Value) i.prc_fecha_creacion = DateTime.Parse(dr["prc_fecha_creacion"].ToString());
                            if (dr["prc_fecha_actualizacion"] != DBNull.Value) i.prc_fecha_actualizacion = DateTime.Parse(dr["prc_fecha_actualizacion"].ToString());
                            i.es_global = int.Parse(dr["ES_GLOBAL"].ToString()) == 1;
                            i.es_ultima = bool.Parse(dr["ES_ULTIMA"].ToString());
                            i.pasos = int.Parse(dr["PASOS"].ToString());
                            i.activo_tipo_nombre = dr["ACTIVO_TIPO_NOMBRE"].ToString();
                            i.permiso_tipo_nombre = dr["PERMISO_TIPO_NOMBRE"].ToString();
                            i.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            i.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();
                            lista.Add(i);
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

        public Procedimiento GetProcedimiento(int id)
        {
            List<Procedimiento> l = GetProcedimientos(new Procedimiento { prc_id = id });
            return (l != null && l.Count > 0) ? l[0] : new Procedimiento();
        }

        public Respuesta InsertProcedimiento(Procedimiento e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    int id = 0;
                    cmd = Conexion.GetCommand("INS_PROCEDIMIENTO");
                    cmd.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@CLIENTE", e.prc_cliente ?? Session.ClienteId());
                    cmd.Parameters.AddWithValue("@CODIGO", e.prc_codigo);
                    cmd.Parameters.AddWithValue("@NOMBRE", e.prc_nombre);
                    cmd.Parameters.AddWithValue("@VERSION", e.prc_version > 0 ? e.prc_version : 1);
                    cmd.Parameters.AddWithValue("@ACTIVO_TIPO", (object)e.prc_activo_tipo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@DESCRIPCION", (object)e.prc_descripcion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@DURACION", (object)e.prc_duracion_estimada_minuto ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@REQUIERE_PERMISO", e.prc_requiere_permiso);
                    cmd.Parameters.AddWithValue("@PERMISO_TIPO", (object)e.prc_permiso_trabajo_tipo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    id = (int)cmd.Parameters["@ID"].Value;
                    r.codigo = id; r.detalle = "Procedimiento creado con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                r.codigo = -1;
                r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                r.error = true;
            }
            return r;
        }

        public Respuesta UpdateProcedimiento(Procedimiento e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("UPD_PROCEDIMIENTO");
                    cmd.Parameters.AddWithValue("@ID", e.prc_id);
                    cmd.Parameters.AddWithValue("@CLIENTE", e.prc_cliente ?? Session.ClienteId());
                    cmd.Parameters.AddWithValue("@NOMBRE", e.prc_nombre);
                    cmd.Parameters.AddWithValue("@ACTIVO_TIPO", (object)e.prc_activo_tipo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@DESCRIPCION", (object)e.prc_descripcion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@DURACION", (object)e.prc_duracion_estimada_minuto ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@REQUIERE_PERMISO", e.prc_requiere_permiso);
                    cmd.Parameters.AddWithValue("@PERMISO_TIPO", (object)e.prc_permiso_trabajo_tipo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@HABILITADO", e.prc_habilitado);
                    cmd.Parameters.AddWithValue("@QUITA_TIPO", e.quita_tipo);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = e.prc_id; r.detalle = "Procedimiento actualizado con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                r.codigo = -1;
                r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                r.error = true;
            }
            return r;
        }

        public Respuesta DeleteProcedimiento(Procedimiento e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("DEL_PROCEDIMIENTO");
                    cmd.Parameters.AddWithValue("@ID", e.prc_id);
                    cmd.Parameters.AddWithValue("@CLIENTE", e.prc_cliente ?? Session.ClienteId());
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = e.prc_id; r.detalle = "Procedimiento dado de baja con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                r.codigo = -1;
                r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                r.error = true;
            }
            return r;
        }
    }
}
