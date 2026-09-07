using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Pasos de un procedimiento (HU-062). El SEL trae los pasos de los
    /// procedimientos del cliente MÁS los de los globales; INS/UPD/DEL solo
    /// tocan pasos de procedimientos DEL CLIENTE (el SP rechaza los globales).
    /// El orden dentro del procedimiento es único.
    /// </summary>
    public class ProcedimientoPasoController
    {
        public List<ProcedimientoPaso> GetPasos(ProcedimientoPaso filtro = null)
        {
            List<ProcedimientoPaso> lista = new List<ProcedimientoPaso>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_PROCEDIMIENTO_PASO";

                    int cliente = (filtro != null && filtro.filtro_cliente > 0) ? filtro.filtro_cliente : Session.ClienteId();
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente);

                    if (filtro != null)
                    {
                        if (filtro.ppa_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.ppa_id);
                        if (filtro.filtro_procedimiento > 0) cmd.Parameters.AddWithValue("@PROCEDIMIENTO", filtro.filtro_procedimiento);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ProcedimientoPaso i = new ProcedimientoPaso();
                            i.ppa_id = int.Parse(dr["ppa_id"].ToString());
                            i.ppa_procedimiento = int.Parse(dr["ppa_procedimiento"].ToString());
                            i.ppa_orden = int.Parse(dr["ppa_orden"].ToString());
                            i.ppa_nombre = dr["ppa_nombre"].ToString();
                            i.ppa_instruccion = dr["ppa_instruccion"].ToString();
                            i.ppa_es_punto_control = bool.Parse(dr["ppa_es_punto_control"].ToString());
                            i.ppa_requiere_evidencia = bool.Parse(dr["ppa_requiere_evidencia"].ToString());
                            i.ppa_requiere_medicion = bool.Parse(dr["ppa_requiere_medicion"].ToString());
                            if (dr["ppa_variable_medicion"] != DBNull.Value) i.ppa_variable_medicion = int.Parse(dr["ppa_variable_medicion"].ToString());
                            if (dr["ppa_duracion_estimada_minuto"] != DBNull.Value) i.ppa_duracion_estimada_minuto = int.Parse(dr["ppa_duracion_estimada_minuto"].ToString());
                            i.ppa_habilitado = bool.Parse(dr["ppa_habilitado"].ToString());
                            if (dr["ppa_fecha_creacion"] != DBNull.Value) i.ppa_fecha_creacion = DateTime.Parse(dr["ppa_fecha_creacion"].ToString());
                            if (dr["ppa_fecha_actualizacion"] != DBNull.Value) i.ppa_fecha_actualizacion = DateTime.Parse(dr["ppa_fecha_actualizacion"].ToString());
                            i.es_global = int.Parse(dr["ES_GLOBAL"].ToString()) == 1;
                            i.procedimiento_codigo = dr["PROCEDIMIENTO_CODIGO"].ToString();
                            i.procedimiento_nombre = dr["PROCEDIMIENTO_NOMBRE"].ToString();
                            i.procedimiento_version = int.Parse(dr["PROCEDIMIENTO_VERSION"].ToString());
                            i.variable_nombre = dr["VARIABLE_NOMBRE"].ToString();
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

        public ProcedimientoPaso GetPaso(int id)
        {
            List<ProcedimientoPaso> l = GetPasos(new ProcedimientoPaso { ppa_id = id });
            return (l != null && l.Count > 0) ? l[0] : new ProcedimientoPaso();
        }

        public Respuesta InsertPaso(ProcedimientoPaso e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    int id = 0;
                    cmd = Conexion.GetCommand("INS_PROCEDIMIENTO_PASO");
                    cmd.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@PROCEDIMIENTO", e.ppa_procedimiento);
                    cmd.Parameters.AddWithValue("@ORDEN", e.ppa_orden > 0 ? (object)e.ppa_orden : DBNull.Value);
                    cmd.Parameters.AddWithValue("@NOMBRE", e.ppa_nombre);
                    cmd.Parameters.AddWithValue("@INSTRUCCION", (object)e.ppa_instruccion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@ES_PUNTO_CONTROL", e.ppa_es_punto_control);
                    cmd.Parameters.AddWithValue("@REQUIERE_EVIDENCIA", e.ppa_requiere_evidencia);
                    cmd.Parameters.AddWithValue("@REQUIERE_MEDICION", e.ppa_requiere_medicion);
                    cmd.Parameters.AddWithValue("@VARIABLE", (object)e.ppa_variable_medicion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@DURACION", (object)e.ppa_duracion_estimada_minuto ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    id = (int)cmd.Parameters["@ID"].Value;
                    r.codigo = id; r.detalle = "Paso creado con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else
            {
                r.codigo = -1;
                r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                r.error = true;
            }
            return r;
        }

        public Respuesta UpdatePaso(ProcedimientoPaso e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("UPD_PROCEDIMIENTO_PASO");
                    cmd.Parameters.AddWithValue("@ID", e.ppa_id);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@ORDEN", e.ppa_orden > 0 ? (object)e.ppa_orden : DBNull.Value);
                    cmd.Parameters.AddWithValue("@NOMBRE", e.ppa_nombre);
                    cmd.Parameters.AddWithValue("@INSTRUCCION", (object)e.ppa_instruccion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@ES_PUNTO_CONTROL", e.ppa_es_punto_control);
                    cmd.Parameters.AddWithValue("@REQUIERE_EVIDENCIA", e.ppa_requiere_evidencia);
                    cmd.Parameters.AddWithValue("@REQUIERE_MEDICION", e.ppa_requiere_medicion);
                    cmd.Parameters.AddWithValue("@VARIABLE", (object)e.ppa_variable_medicion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@QUITA_VARIABLE", e.quita_variable);
                    cmd.Parameters.AddWithValue("@DURACION", (object)e.ppa_duracion_estimada_minuto ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@HABILITADO", e.ppa_habilitado);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = e.ppa_id; r.detalle = "Paso actualizado con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else
            {
                r.codigo = -1;
                r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                r.error = true;
            }
            return r;
        }

        public Respuesta DeletePaso(ProcedimientoPaso e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("DEL_PROCEDIMIENTO_PASO");
                    cmd.Parameters.AddWithValue("@ID", e.ppa_id);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = e.ppa_id; r.detalle = "Paso dado de baja con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else
            {
                r.codigo = -1;
                r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                r.error = true;
            }
            return r;
        }
    }
}
