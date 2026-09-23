using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Programaciones recurrentes de pautas de inspección (HU-094). El alta
    /// resuelve la versión PUBLICADA de la pauta y exige un objetivo (activo o
    /// área) — reglas en el SP, para que web y API coincidan. Siempre acotado al
    /// cliente en sesión.
    /// </summary>
    public class ChecklistProgramacionController
    {
        public List<ChecklistProgramacion> GetProgramaciones(ChecklistProgramacion filtro = null)
        {
            List<ChecklistProgramacion> lista = new List<ChecklistProgramacion>();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_CHECKLIST_PROGRAMACION";
                    int cliente = (filtro != null && filtro.filtro_cliente > 0) ? filtro.filtro_cliente : Session.ClienteId();
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente);
                    if (filtro != null)
                    {
                        if (filtro.cpr_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.cpr_id);
                        if (filtro.filtro_checklist_plantilla > 0) cmd.Parameters.AddWithValue("@CHECKLIST_PLANTILLA", filtro.filtro_checklist_plantilla);
                        if (filtro.filtro_activo > 0) cmd.Parameters.AddWithValue("@ACTIVO", filtro.filtro_activo);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ChecklistProgramacion i = new ChecklistProgramacion();
                            i.cpr_id = int.Parse(dr["CPR_ID"].ToString());
                            i.cpr_cliente = int.Parse(dr["CPR_CLIENTE"].ToString());
                            i.cpr_version = int.Parse(dr["CPR_VERSION"].ToString());
                            i.cpr_checklist_plantilla = int.Parse(dr["CPR_CHECKLIST_PLANTILLA"].ToString());
                            i.version_numero = int.Parse(dr["VERSION_NUMERO"].ToString());
                            i.cpr_programacion = int.Parse(dr["CPR_PROGRAMACION"].ToString());
                            if (dr["CPR_ACTIVO"] != DBNull.Value) i.cpr_activo = int.Parse(dr["CPR_ACTIVO"].ToString());
                            if (dr["CPR_INSTALACION_AREA"] != DBNull.Value) i.cpr_instalacion_area = int.Parse(dr["CPR_INSTALACION_AREA"].ToString());
                            if (dr["CPR_GRUPO_TRABAJO"] != DBNull.Value) i.cpr_grupo_trabajo = int.Parse(dr["CPR_GRUPO_TRABAJO"].ToString());
                            if (dr["CPR_USUARIO_RESPONSABLE"] != DBNull.Value) i.cpr_usuario_responsable = int.Parse(dr["CPR_USUARIO_RESPONSABLE"].ToString());
                            i.cpr_nombre = dr["CPR_NOMBRE"].ToString();
                            i.cpr_habilitado = bool.Parse(dr["CPR_HABILITADO"].ToString());
                            if (dr["CPR_FECHA_CREACION"] != DBNull.Value) i.cpr_fecha_creacion = DateTime.Parse(dr["CPR_FECHA_CREACION"].ToString());
                            if (dr["CPR_FECHA_ACTUALIZACION"] != DBNull.Value) i.cpr_fecha_actualizacion = DateTime.Parse(dr["CPR_FECHA_ACTUALIZACION"].ToString());
                            i.pauta_codigo = dr["PAUTA_CODIGO"].ToString();
                            i.pauta_nombre = dr["PAUTA_NOMBRE"].ToString();
                            i.programacion_nombre = dr["PROGRAMACION_NOMBRE"].ToString();
                            i.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                            i.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            i.area_nombre = dr["AREA_NOMBRE"].ToString();
                            i.grupo_nombre = dr["GRUPO_NOMBRE"].ToString();
                            i.responsable_nombre = dr["RESPONSABLE_NOMBRE"].ToString();
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

        public ChecklistProgramacion GetProgramacion(int id)
        {
            List<ChecklistProgramacion> l = GetProgramaciones(new ChecklistProgramacion { cpr_id = id });
            return (l != null && l.Count > 0) ? l[0] : new ChecklistProgramacion();
        }

        public Respuesta InsertProgramacion(ChecklistProgramacion e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    int id = 0;
                    cmd = Conexion.GetCommand("INS_CHECKLIST_PROGRAMACION");
                    cmd.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@CHECKLIST_PLANTILLA", e.cpr_checklist_plantilla);
                    cmd.Parameters.AddWithValue("@PROGRAMACION", e.cpr_programacion);
                    cmd.Parameters.AddWithValue("@ACTIVO", (object)e.cpr_activo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@INSTALACION_AREA", (object)e.cpr_instalacion_area ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@GRUPO_TRABAJO", (object)e.cpr_grupo_trabajo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@USUARIO_RESPONSABLE", (object)e.cpr_usuario_responsable ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@NOMBRE", e.cpr_nombre);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    id = (int)cmd.Parameters["@ID"].Value;
                    r.codigo = id; r.detalle = "Programación creada con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else { r.codigo = -1; r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion."; r.error = true; }
            return r;
        }

        public Respuesta UpdateProgramacion(ChecklistProgramacion e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("UPD_CHECKLIST_PROGRAMACION");
                    cmd.Parameters.AddWithValue("@ID", e.cpr_id);
                    cmd.Parameters.AddWithValue("@CHECKLIST_PLANTILLA", (object)(e.cpr_checklist_plantilla > 0 ? (object)e.cpr_checklist_plantilla : DBNull.Value));
                    cmd.Parameters.AddWithValue("@PROGRAMACION", (object)(e.cpr_programacion > 0 ? (object)e.cpr_programacion : DBNull.Value));
                    cmd.Parameters.AddWithValue("@ACTIVO", (object)e.cpr_activo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@INSTALACION_AREA", (object)e.cpr_instalacion_area ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@GRUPO_TRABAJO", (object)e.cpr_grupo_trabajo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@USUARIO_RESPONSABLE", (object)e.cpr_usuario_responsable ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@NOMBRE", e.cpr_nombre);
                    cmd.Parameters.AddWithValue("@HABILITADO", e.cpr_habilitado);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = e.cpr_id; r.detalle = "Programación actualizada con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else { r.codigo = -1; r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion."; r.error = true; }
            return r;
        }

        /// <summary>Baja lógica (habilitado = 0) reutilizando el UPD.</summary>
        public Respuesta DeleteProgramacion(ChecklistProgramacion e)
        {
            ChecklistProgramacion actual = GetProgramacion(e.cpr_id);
            if (actual == null || actual.cpr_id <= 0)
                return new Respuesta { codigo = -1, detalle = "La programación no existe.", error = true };
            actual.cpr_habilitado = false;
            actual.cpr_checklist_plantilla = 0;   // no cambia la pauta
            actual.cpr_programacion = 0;           // no cambia la recurrencia
            Respuesta r = UpdateProgramacion(actual);
            if (!r.error) r.detalle = "Programación dada de baja con éxito.";
            return r;
        }
    }
}
