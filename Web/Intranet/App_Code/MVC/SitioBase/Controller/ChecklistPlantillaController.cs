using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Plantillas de checklist / pautas de inspección (HU-090). El acceso a
    /// datos pasa siempre por los SP (SEL/INS/UPD/DEL_CHECKLIST_PLANTILLA). El
    /// listado filtra por Session.ClienteId() (barrera multicliente); el código
    /// lo escribe el usuario y es único por cliente.
    /// </summary>
    public class ChecklistPlantillaController
    {
        public List<ChecklistPlantilla> GetChecklistPlantillas(ChecklistPlantilla filtro = null)
        {
            List<ChecklistPlantilla> lista = new List<ChecklistPlantilla>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_CHECKLIST_PLANTILLA";

                    int cliente = (filtro != null && filtro.filtro_cliente > 0) ? filtro.filtro_cliente : Session.ClienteId();
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente);

                    if (filtro != null)
                    {
                        if (filtro.cpl_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.cpl_id);
                        if (filtro.filtro_cliente_instalacion > 0) cmd.Parameters.AddWithValue("@CLIENTE_INSTALACION", filtro.filtro_cliente_instalacion);
                        if (filtro.filtro_activo_tipo > 0) cmd.Parameters.AddWithValue("@ACTIVO_TIPO", filtro.filtro_activo_tipo);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ChecklistPlantilla i = new ChecklistPlantilla();
                            i.cpl_id = int.Parse(dr["CPL_ID"].ToString());
                            i.cpl_cliente = int.Parse(dr["CPL_CLIENTE"].ToString());
                            if (dr["CPL_CLIENTE_INSTALACION"] != DBNull.Value) i.cpl_cliente_instalacion = int.Parse(dr["CPL_CLIENTE_INSTALACION"].ToString());
                            if (dr["CPL_CHECKLIST_ASIGNACION_TIPO"] != DBNull.Value) i.cpl_checklist_asignacion_tipo = int.Parse(dr["CPL_CHECKLIST_ASIGNACION_TIPO"].ToString());
                            if (dr["CPL_ACTIVO_TIPO"] != DBNull.Value) i.cpl_activo_tipo = int.Parse(dr["CPL_ACTIVO_TIPO"].ToString());
                            i.cpl_codigo = dr["CPL_CODIGO"].ToString();
                            i.cpl_nombre = dr["CPL_NOMBRE"].ToString();
                            i.cpl_descripcion = dr["CPL_DESCRIPCION"].ToString();
                            if (dr["CPL_FECHA_CREACION"] != DBNull.Value) i.cpl_fecha_creacion = DateTime.Parse(dr["CPL_FECHA_CREACION"].ToString());
                            if (dr["CPL_FECHA_ACTUALIZACION"] != DBNull.Value) i.cpl_fecha_actualizacion = DateTime.Parse(dr["CPL_FECHA_ACTUALIZACION"].ToString());
                            i.cpl_habilitado = bool.Parse(dr["CPL_HABILITADO"].ToString());
                            i.planta_nombre = dr["PLANTA_NOMBRE"].ToString();
                            i.asignacion_tipo_nombre = dr["ASIGNACION_TIPO_NOMBRE"].ToString();
                            i.activo_tipo_nombre = dr["ACTIVO_TIPO_NOMBRE"].ToString();
                            i.versiones = int.Parse(dr["VERSIONES"].ToString());
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

        public ChecklistPlantilla GetChecklistPlantilla(int id)
        {
            List<ChecklistPlantilla> l = GetChecklistPlantillas(new ChecklistPlantilla { cpl_id = id });
            return (l != null && l.Count > 0) ? l[0] : new ChecklistPlantilla();
        }

        public Respuesta InsertChecklistPlantilla(ChecklistPlantilla e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    int id = 0;
                    cmd = Conexion.GetCommand("INS_CHECKLIST_PLANTILLA");
                    cmd.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@CLIENTE_INSTALACION", (object)e.cpl_cliente_instalacion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@CHECKLIST_ASIGNACION_TIPO", (object)e.cpl_checklist_asignacion_tipo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@ACTIVO_TIPO", (object)e.cpl_activo_tipo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@CODIGO", e.cpl_codigo);
                    cmd.Parameters.AddWithValue("@NOMBRE", e.cpl_nombre);
                    cmd.Parameters.AddWithValue("@DESCRIPCION", (object)e.cpl_descripcion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    id = (int)cmd.Parameters["@ID"].Value;
                    r.codigo = id; r.detalle = "Plantilla creada con éxito."; r.error = false;
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

        public Respuesta UpdateChecklistPlantilla(ChecklistPlantilla e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("UPD_CHECKLIST_PLANTILLA");
                    cmd.Parameters.AddWithValue("@ID", e.cpl_id);
                    cmd.Parameters.AddWithValue("@CLIENTE_INSTALACION", (object)e.cpl_cliente_instalacion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@CHECKLIST_ASIGNACION_TIPO", (object)e.cpl_checklist_asignacion_tipo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@ACTIVO_TIPO", (object)e.cpl_activo_tipo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@NOMBRE", e.cpl_nombre);
                    cmd.Parameters.AddWithValue("@DESCRIPCION", (object)e.cpl_descripcion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@HABILITADO", e.cpl_habilitado);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = e.cpl_id; r.detalle = "Plantilla actualizada con éxito."; r.error = false;
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

        public Respuesta DeleteChecklistPlantilla(ChecklistPlantilla e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("DEL_CHECKLIST_PLANTILLA");
                    cmd.Parameters.AddWithValue("@ID", e.cpl_id);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = e.cpl_id; r.detalle = "Plantilla dada de baja con éxito."; r.error = false;
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
